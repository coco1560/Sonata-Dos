// ============================================================================
// tools/asm.mjs — Symphony ISA 汇编器(依据用户提供的 spec.isa)
//
// 语法: const NAME = value ; label: ; 指令 ; 注释以 ; 开头
// 真实指令全部按 spec.isa 的 32 位编码实现。
// 伪指令展开(与 spec.isa 一致):
//   push %a   -> sub sp,sp,4 ; store_32 [sp],%a            (2 条, 8B)
//   pop  %a   -> load_32 %a,[sp] ; add sp,sp,4              (2 条, 8B)
//   call %L   -> counter flags ; add flags,flags,20 ;
//                sub sp,sp,4 ; store_32 [sp],flags ; jmp %L (5 条, 20B)
//   ret       -> load_32 flags,[sp] ; add sp,sp,4 ; jmp flags (3 条, 12B)
// 数据伪指令(仅供本汇编器, 游戏的汇编器不需要支持):
//   data8 "text"   data16 N   data32 N|label   space N
// 每条数据伪指令补齐到 4 字节边界。
//
// 标号引用: 引用了本程序内标号的 32 位字 -> 重定位表项(该字的字节偏移)。
// 未定义标号 -> 查 externs(boot 导出符号表), 编码为绝对地址, 不重定位。
// ============================================================================

const REGS = {
  zr: 0, r1: 1, r2: 2, r3: 3, r4: 4, r5: 5, r6: 6, r7: 7,
  r8: 8, r9: 9, r10: 10, r11: 11, r12: 12, r13: 13, sp: 14, flags: 15,
};

const ALU_OPS = { nand: 0, or: 1, and: 2, nor: 3, add: 4, sub: 5, xor: 6, lsl: 7, lsr: 8, asr: 9 };
const JCC_OPS = { je: 0x51, jne: 0x59, jb: 0x52, jae: 0x5a, jbe: 0x53, ja: 0x5b, jl: 0x54, jge: 0x5c, jle: 0x55, jg: 0x5d };
// load_8..pstore 的 k 值: 0x60+k(寄存器寻址) / 0x70+k(立即数寻址)
const RAM_OPS = { load_8: 0, load_16: 1, load_32: 2, pload: 3, store_8: 4, store_16: 5, store_32: 6, pstore: 7 };

class AsmError extends Error {}

const isReg = (tok) => REGS[tok] !== undefined;
const isNum = (tok) => /^-?\d+$/.test(tok) || /^0[xX][0-9a-fA-F]+$/.test(tok);
const isIdent = (tok) => /^[A-Za-z_]\w*$/.test(tok);

function parseNum(tok) {
  if (/^-?\d+$/.test(tok)) return Number(tok);
  if (/^0[xX][0-9a-fA-F]+$/.test(tok)) return parseInt(tok, 16);
  throw new AsmError('expected number, got "' + tok + '"');
}

function unescapeStr(s) {
  let out = "";
  for (let i = 0; i < s.length; i++) {
    if (s[i] === "\\" && i + 1 < s.length) {
      const n = s[++i];
      if (n === "0") out += "\0";
      else if (n === "n") out += "\n";
      else if (n === "t") out += "\t";
      else if (n === '"') out += '"';
      else if (n === "\\") out += "\\";
      else out += n;
    } else out += s[i];
  }
  return out;
}

function stripComment(line) {
  const i = line.indexOf(";");
  return i >= 0 ? line.slice(0, i) : line;
}

/**
 * assemble(src, { externs })
 * -> { bytes: Uint8Array, size, relocs: number[](字节偏移), symbols: {name: addr}, entry }
 */
export function assemble(src, opts = {}) {
  const externs = opts.externs || {};
  const consts = {};
  const stmts = [];

  for (const raw of src.split(/\r?\n/)) {
    const ln = stripComment(raw).trim();
    if (!ln) continue;
    let m;
    if ((m = ln.match(/^const\s+([A-Za-z_]\w*)\s*=\s*(.+)$/))) {
      consts[m[1]] = parseNum(m[2].trim());
      continue;
    }
    if ((m = ln.match(/^([A-Za-z_]\w*):$/))) { stmts.push({ kind: "label", name: m[1] }); continue; }
    if ((m = ln.match(/^data8\s+"(.*)"$/))) { stmts.push({ kind: "data8", text: unescapeStr(m[1]) }); continue; }
    if ((m = ln.match(/^data16\s+(.+)$/))) { stmts.push({ kind: "data16", v: parseNum(m[1]) }); continue; }
    if ((m = ln.match(/^data32\s+(.+)$/))) { stmts.push({ kind: "data32", tok: m[1].trim() }); continue; }
    if ((m = ln.match(/^space\s+(.+)$/))) { stmts.push({ kind: "space", n: parseNum(m[1]) }); continue; }
    const sp = ln.indexOf(" ");
    if (sp < 0) stmts.push({ kind: "insn", op: ln, args: [] });
    else {
      stmts.push({
        kind: "insn",
        op: ln.slice(0, sp),
        args: ln.slice(sp).split(",").map((s) => s.trim()).filter(Boolean),
      });
    }
  }

  // ---- 伪指令展开 ----
  const expanded = [];
  for (const st of stmts) {
    if (st.kind === "insn" && st.op === "push") {
      expanded.push(
        { kind: "insn", op: "sub", args: ["sp", "sp", "4"] },
        { kind: "insn", op: "store_32", args: ["[sp]", st.args[0]] },
      );
    } else if (st.kind === "insn" && st.op === "pop") {
      expanded.push(
        { kind: "insn", op: "load_32", args: [st.args[0], "[sp]"] },
        { kind: "insn", op: "add", args: ["sp", "sp", "4"] },
      );
    } else if (st.kind === "insn" && st.op === "call") {
      expanded.push(
        { kind: "insn", op: "counter", args: ["flags"] },
        { kind: "insn", op: "add", args: ["flags", "flags", "20"] },
        { kind: "insn", op: "sub", args: ["sp", "sp", "4"] },
        { kind: "insn", op: "store_32", args: ["[sp]", "flags"] },
        { kind: "insn", op: "jmp", args: [st.args[0]] },
      );
    } else if (st.kind === "insn" && st.op === "ret") {
      expanded.push(
        { kind: "insn", op: "load_32", args: ["flags", "[sp]"] },
        { kind: "insn", op: "add", args: ["sp", "sp", "4"] },
        { kind: "insn", op: "jmp", args: ["flags"] },
      );
    } else expanded.push(st);
  }

  // ---- 第一遍: 地址 ----
  const symbols = {};
  let addr = 0;
  const sizeOf = (st) => {
    switch (st.kind) {
      case "insn": return 4;
      case "data8": return (st.text.length + 1 + 3) & ~3;
      case "data16": return 4;
      case "data32": return 4;
      case "space": return (st.n + 3) & ~3;
      default: return 0;
    }
  };
  for (const st of expanded) {
    if (st.kind === "label") symbols[st.name] = addr;
    else addr += sizeOf(st);
    if (addr > 0xffff) throw new AsmError("program too large for 16-bit labels: " + addr);
  }

  // ---- 第二遍: 发射 ----
  const bytes = new Uint8Array(addr);
  const relocs = [];
  let cur = 0;

  const emitWord = (w, isLabel) => {
    // 大端字节序(外存按大端读 32 位字, 主内存同样)
    bytes[cur] = (w >>> 24) & 0xff;
    bytes[cur + 1] = (w >>> 16) & 0xff;
    bytes[cur + 2] = (w >>> 8) & 0xff;
    bytes[cur + 3] = w & 0xff;
    if (isLabel) relocs.push(cur);
    cur += 4;
  };

  const resolveImm = (tok) => {
    if (isReg(tok)) throw new AsmError("expected immediate, got register " + tok);
    if (isNum(tok)) return { v: parseNum(tok), label: false };
    if (isIdent(tok)) {
      if (consts[tok] !== undefined) return { v: consts[tok], label: false };
      if (symbols[tok] !== undefined) return { v: symbols[tok], label: true };
      if (externs[tok] !== undefined) return { v: externs[tok], label: false };
      throw new AsmError("undefined symbol: " + tok);
    }
    throw new AsmError("bad operand: " + tok);
  };

  const reg = (tok) => {
    if (!isReg(tok)) throw new AsmError('expected register, got "' + tok + '"');
    return REGS[tok];
  };

  const check16 = (v) => {
    if (v < 0 || v > 0xffff) throw new AsmError("immediate out of 16-bit range: " + v);
  };

  const memTok = (tok) => {
    const m = tok.match(/^\[(.+)\]$/);
    if (!m) throw new AsmError('expected [addr], got "' + tok + '"');
    return m[1];
  };

  for (const st of expanded) {
    if (st.kind === "label") continue;

    if (st.kind === "insn") {
      const { op } = st;
      const a = st.args;
      if (op === "nop") { emitWord(0); continue; }
      if (op === "in") { emitWord(0x01000000 | (reg(a[0]) << 20)); continue; }
      if (op === "out") {
        if (isReg(a[0])) emitWord(0x02000000 | (reg(a[0]) << 8));
        else { const i = resolveImm(a[0]); check16(i.v); emitWord(0x12000000 | i.v, i.label); }
        continue;
      }
      if (op === "keyboard") { emitWord(0x03000000 | (reg(a[0]) << 20)); continue; }
      if (op === "screen") {
        if (isReg(a[1])) emitWord(0x04000000 | (reg(a[0]) << 16) | (reg(a[1]) << 8));
        else { const i = resolveImm(a[1]); check16(i.v); emitWord(0x14000000 | (reg(a[0]) << 16) | i.v, i.label); }
        continue;
      }
      if (op === "time_0" || op === "time_1" || op === "counter") {
        const base = op === "time_0" ? 0x05 : op === "time_1" ? 0x06 : 0x07;
        emitWord(base << 24 | (reg(a[0]) << 20));
        continue;
      }
      if (ALU_OPS[op] !== undefined) {
        const k = ALU_OPS[op];
        if (isReg(a[2])) emitWord(((0x20 + k) << 24) | (reg(a[0]) << 20) | (reg(a[1]) << 16) | (reg(a[2]) << 8));
        else { const i = resolveImm(a[2]); check16(i.v); emitWord(((0x30 + k) << 24) | (reg(a[0]) << 20) | (reg(a[1]) << 16) | i.v, i.label); }
        continue;
      }
      if (op === "cmp") {
        if (isReg(a[1])) emitWord((0x2a << 24) | (0xf << 20) | (reg(a[0]) << 16) | (reg(a[1]) << 8));
        else { const i = resolveImm(a[1]); check16(i.v); emitWord((0x3a << 24) | (0xf << 20) | (reg(a[0]) << 16) | i.v, i.label); }
        continue;
      }
      if (op === "mov" || op === "neg" || op === "not") {
        const k = op === "mov" ? 1 : op === "neg" ? 5 : 3; // or/sub/nor with zr
        if (isReg(a[1])) emitWord(((0x20 + k) << 24) | (reg(a[0]) << 20) | (reg(a[1]) << 8));
        else { const i = resolveImm(a[1]); check16(i.v); emitWord(((0x30 + k) << 24) | (reg(a[0]) << 20) | i.v, i.label); }
        continue;
      }
      if (op === "jmp") {
        if (isReg(a[0])) emitWord((0x48 << 24) | (0xf << 16) | (reg(a[0]) << 8));
        else { const i = resolveImm(a[0]); check16(i.v); emitWord((0x58 << 24) | (0xf << 16) | i.v, i.label); }
        continue;
      }
      if (JCC_OPS[op] !== undefined) {
        const i = resolveImm(a[0]);
        check16(i.v);
        emitWord((JCC_OPS[op] << 24) | (0xf << 16) | i.v, i.label);
        continue;
      }
      if (RAM_OPS[op] !== undefined) {
        const k = RAM_OPS[op];
        const isStore = k >= 4;
        if (isStore) {
          const at = memTok(a[0]);
          if (isReg(at)) emitWord(((0x60 + k) << 24) | (reg(a[1]) << 16) | (reg(at) << 8));
          else { const i = resolveImm(at); check16(i.v); emitWord(((0x70 + k) << 24) | (reg(a[1]) << 16) | i.v, i.label); }
        } else {
          const at = memTok(a[1]);
          if (isReg(at)) emitWord(((0x60 + k) << 24) | (reg(a[0]) << 20) | (reg(at) << 8));
          else { const i = resolveImm(at); check16(i.v); emitWord(((0x70 + k) << 24) | (reg(a[0]) << 20) | i.v, i.label); }
        }
        continue;
      }
      throw new AsmError("unknown instruction: " + op);
    }

    if (st.kind === "data8") {
      for (const ch of st.text) bytes[cur++] = ch.charCodeAt(0) & 0xff;
      bytes[cur++] = 0; // NUL 结尾
      while (cur & 3) bytes[cur++] = 0;
      continue;
    }
    if (st.kind === "data16") {
      bytes[cur++] = (st.v >>> 8) & 0xff;
      bytes[cur++] = st.v & 0xff;
      bytes[cur++] = 0;
      bytes[cur++] = 0;
      continue;
    }
    if (st.kind === "data32") {
      const i = resolveImm(st.tok);
      check16(i.v);
      emitWord(i.v >>> 0, i.label);
      continue;
    }
    if (st.kind === "space") {
      const end = (cur + st.n + 3) & ~3;
      while (cur < end) bytes[cur++] = 0;
      continue;
    }
  }

  return {
    bytes,
    size: bytes.length,
    relocs,
    symbols,
    entry: symbols.main ?? null,
  };
}

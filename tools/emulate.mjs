import fs from "node:fs";
// ============================================================================
// tools/emulate.mjs — Symphony ISA 模拟器(按 spec.isa 实现全部指令)
// 用于在 PC 端验证 boot -> DOS -> .mvt 的完整启动链路。
//
// 内存模型:
//   主内存: 0x0000..0xFFFF (Uint8Array, load/store 访问)
//   外存:   磁盘镜像映射在 0x400000 (pload/pstore 访问)
// 屏幕:   option 1 = 帧缓冲地址(默认 0x3000), ASCII32 模式 96x40, 4B/格
// 键盘:   keyboard 指令从队列取 9 位值, 队列空返回 0
// 标志:   cmp 写 flags = a-b; 条件跳转按 flags 符号/零判断
// ============================================================================

export const DISK_BASE = 0;
const SCR_W = 96, SCR_H = 40;

export class Emu {
  constructor(opts = {}) {
    this.regs = new Array(16).fill(0); // zr r1..r13 sp flags
    this.pc = 0;
    this.main = new Uint8Array(0x10000);
    this.ext = new Uint8Array(0x100000);
    this.keys = [];
    this.opts = new Map();
    this.steps = 0;
    this.halted = false;
    this.stdout = [];
    this.time0 = opts.time0 ?? 0x12345678;
  }

  loadBoot(bytes) { this.main.set(bytes, 0); }
  loadDisk(bytes) { this.ext.set(bytes, 0); }

  // 把文本按键送入队列: 每字符 = 按下(0x100|c) + 释放(c)
  type(text) {
    for (const ch of text) {
      const c = ch.charCodeAt(0);
      this.keys.push(0x100 | c, c);
    }
  }
  // 原始键码(游戏实测: Esc=1, 退格=13)
  typeRaw(codes) {
    for (const c of codes) this.keys.push(0x100 | c, c);
  }

  // 大端序(游戏实测: 外存 32 位字大端, 主内存一致)
  rd8(a) { return this.main[a]; }
  rd16(a) { return ((this.main[a] << 8) | this.main[a + 1]) >>> 0; }
  rd32(a) { return ((this.main[a] << 24) | (this.main[a + 1] << 16) | (this.main[a + 2] << 8) | this.main[a + 3]) >>> 0; }
  wr8(a, v) { this.main[a] = v & 0xff; }
  wr16(a, v) { this.main[a] = (v >>> 8) & 0xff; this.main[a + 1] = v & 0xff; }
  wr32(a, v) {
    this.main[a] = (v >>> 24) & 0xff; this.main[a + 1] = (v >>> 16) & 0xff;
    this.main[a + 2] = (v >>> 8) & 0xff; this.main[a + 3] = v & 0xff;
  }
  prd32(a) {
    const e = a - DISK_BASE;
    if (e < 0 || e + 4 > this.ext.length) return 0;
    return ((this.ext[e] << 24) | (this.ext[e + 1] << 16) | (this.ext[e + 2] << 8) | this.ext[e + 3]) >>> 0;
  }
  pwr32(a, v) {
    const e = a - DISK_BASE;
    if (e < 0 || e + 4 > this.ext.length) return;
    this.ext[e] = (v >>> 24) & 0xff;
    this.ext[e + 1] = (v >>> 16) & 0xff;
    this.ext[e + 2] = (v >>> 8) & 0xff;
    this.ext[e + 3] = v & 0xff;
  }

  alu(k, a, b) {
    switch (k) {
      case 0: return ~(a & b);
      case 1: return a | b;
      case 2: return a & b;
      case 3: return ~(a | b);
      case 4: return a + b;
      case 5: return a - b;
      case 6: return a ^ b;
      case 7: return a << (b & 31);
      case 8: return a >>> (b & 31);
      case 9: return (a | 0) >> (b & 31);
      default: return 0;
    }
  }

  step() {
    const pc = this.pc;
    const w = this.rd32(pc);
    const op = w >>> 24; // 操作码在小端 32 位字的最高字节
    const dest = (w >>> 20) & 0xf;
    const s1 = (w >>> 16) & 0xf;
    const s2 = (w >>> 8) & 0xf;
    const imm = w & 0xffff;
    const wasJump = op === 0x48 || op === 0x58 || (op >= 0x51 && op <= 0x5d);
    this.pc = pc + 4;
    this.steps++;
    const R = this.regs;
    const set = (i, v) => { if (i !== 0) R[i] = v >>> 0; };

    if (op >= 0x20 && op <= 0x29) { set(dest, this.alu(op - 0x20, R[s1], R[s2])); }
    else if (op >= 0x30 && op <= 0x39) { set(dest, this.alu(op - 0x30, R[s1], imm)); }
    else if (op === 0x2a) { R[15] = (R[s1] - R[s2]) >>> 0; }
    else if (op === 0x3a) { R[15] = (R[s1] - imm) >>> 0; }
    else if (op === 0x48) { this.pc = R[s2] >>> 0; }
    else if (op === 0x58) { this.pc = imm; }
    else if (op === 0x51) { if (R[15] === 0) this.pc = imm; }
    else if (op === 0x59) { if (R[15] !== 0) this.pc = imm; }
    else if (op === 0x52) { if ((R[15] | 0) < 0) this.pc = imm; }
    else if (op === 0x5a) { if ((R[15] | 0) >= 0) this.pc = imm; }
    else if (op === 0x53) { if ((R[15] | 0) <= 0) this.pc = imm; }
    else if (op === 0x5b) { if ((R[15] | 0) > 0) this.pc = imm; }
    else if (op === 0x54) { if ((R[15] | 0) < 0) this.pc = imm; }
    else if (op === 0x5c) { if ((R[15] | 0) >= 0) this.pc = imm; }
    else if (op === 0x55) { if ((R[15] | 0) <= 0) this.pc = imm; }
    else if (op === 0x5d) { if ((R[15] | 0) > 0) this.pc = imm; }
    else if (op === 0x00) { /* nop */ }
    else if (op === 0x01) { set(dest, 0); }
    else if (op === 0x02) { this.stdout.push(R[s2] & 0xff); }
    else if (op === 0x12) { this.stdout.push(imm & 0xff); }
    else if (op === 0x03) { set(dest, this.keys.length ? this.keys.shift() : 0); }
    else if (op === 0x04) { this.opts.set(s1, R[s2]); }
    else if (op === 0x14) { this.opts.set(s1, imm); }
    else if (op === 0x05) { set(dest, this.time0 + this.steps * 126); } // 实测游戏 time_0 ≈ 1.263 亿/秒(按 ~1M 指令/秒折算 126 单位/指令)
    else if (op === 0x06) { set(dest, 0); }
    else if (op === 0x07) { set(dest, pc); }
    else if (op === 0x60) { set(dest, this.rd8(R[s2])); }
    else if (op === 0x61) { set(dest, this.rd16(R[s2])); }
    else if (op === 0x62) { set(dest, this.rd32(R[s2])); }
    else if (op === 0x63) { set(dest, this.prd32(R[s2])); }
    else if (op === 0x64) { this.wr8(R[s2], R[s1]); }
    else if (op === 0x65) { this.wr16(R[s2], R[s1]); }
    else if (op === 0x66) { this.wr32(R[s2], R[s1]); }
    else if (op === 0x67) { this.pwr32(R[s2], R[s1]); }
    else if (op === 0x70) { set(dest, this.rd8(imm)); }
    else if (op === 0x71) { set(dest, this.rd16(imm)); }
    else if (op === 0x72) { set(dest, this.rd32(imm)); }
    else if (op === 0x73) { set(dest, this.prd32(imm)); }
    else if (op === 0x74) { this.wr8(imm, R[s1]); }
    else if (op === 0x75) { this.wr16(imm, R[s1]); }
    else if (op === 0x76) { this.wr32(imm, R[s1]); }
    else if (op === 0x77) { this.pwr32(imm, R[s1]); }
    else throw new Error("unknown opcode 0x" + op.toString(16) + " at pc=0x" + pc.toString(16));

    if (wasJump && this.pc === pc) this.halted = true;
  }

  run(n) {
    for (let i = 0; i < n && !this.halted; i++) this.step();
    return this.halted;
  }

  // 提取屏幕文本(96x40, 去掉行尾空格与空行)
  // 与游戏一致: fg=0 的格子黑字黑底不可见, 按空格处理
  screenText() {
    const fb = this.opts.get(1) ?? 0x3000;
    const lines = [];
    for (let r = 0; r < SCR_H; r++) {
      let s = "";
      for (let c = 0; c < SCR_W; c++) {
        const cell = fb + (r * SCR_W + c) * 4;
        const ch = this.main[cell];
        const fg = this.main[cell + 1];
        s += (fg !== 0 && ch >= 32 && ch < 127) ? String.fromCharCode(ch) : " ";
      }
      lines.push(s.replace(/ +$/, ""));
    }
    return lines.join("\n");
  }
}

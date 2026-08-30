// ============================================================================
// tools/build.mjs — Sonata DOS 完整版转换器
//
// 1. 汇编 sonata_boot.asm -> boot 导出符号表
// 2. 汇编 dos.asm(完整内核) -> 磁盘镜像 "DOS"
// 3. 转换 progs/*.asm(旧格式) -> .mvt 程序:
//      - 剥离 @name/@alias/@data 指令与 D_* 常量
//      - D_* 常量 -> 数据区标号(space), 运行时 init 代码原样保留
//      - jmp shell_resume -> jmp exit_proc(程序退出回 shell)
//      - 注入共享常量头(内核数据地址/跳转表/FS/字符集)
//      - 内核函数名 -> 跳转表地址 const(call 0x23A0 等)
// 4. 打包磁盘镜像 sonata_disk.bin
//
// 用户操作: 把 sonata_boot.asm 贴进游戏汇编器; 导入 sonata_disk.bin。
// ============================================================================

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { assemble } from "./asm.mjs";
import { buildDiskImage } from "./disk.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// ---- 程序共享常量头(注入到每个转换后的程序) ----
const PROG_CONSTS = `; ---- 共享常量(转换器注入) ----
const CROW = 0x2000
const CCOL = 0x2004
const CURFG = 0x2008
const ARGC = 0x200C
const DIRFLAGS = 0x2010
const CURDIR = 0x2014
const DIRLINES = 0x2018
const LINEBUF = 0x2020
const ARGV = 0x20A0
const ARGV1 = 0x20A4
const ARGV2 = 0x20A8
const DIRTMP = 0x20C0
const DIRTMP4 = 0x20C4
const NAMETMP = 0x20D0
const WRITEBUF = 0x20E0
const ENVBASE = 0x21E0
const DATEVAR = 0x2240
const CASEFLAG = 0x226C
const STACKTOP = 0x7000
const S_UNKNOWN = 0x22E0
const S_SYNTAX = 0x22F2
const S_NF = 0x2300
const S_EXIST = 0x2310
const S_FULL = 0x231E
const S_DELOK = 0x232A
const S_SAVED = 0x2334
const S_CREATED = 0x233C
const S_NOTDIR = 0x2346
const S_NOTFILE = 0x2358
const S_PATHNF = 0x2366
const S_PROMPTNAME = 0x2378
const S_PATHNAME = 0x2380
const S_DEFAULTDATE = 0x2388
const S_NOCOPY = 0x2392
const DISK_TABLE = 32
const DISK_COUNTOF = 8
const DISK_FREEOFF = 16
const DISK_CODEEND = 20
const DISK_BASEOFF = 28
const FS_N = 64
const FS_ENTRY = 40
const FS_NAME_WORDS = 3
const FS_ENTRY_WORDS = 10
const FS_TYPEOF = 12
const FS_SIZEOF = 16
const FS_PAROF = 36
const T_FILE = 1
const T_MVT = 2
const T_DIR = 3
const T_SCO = 4
const T_SCODIR = 5
const RTEXE_BASE = 0xFD00
const SCR_W = 96
const SCR_H = 40
const SCR_LAST = 39
const SCR_LASTCOL = 95
const KEY_DOWN = 0x0100
const KEY_MASK = 0x00FF
const RAW_ESC = 14
const RAW_BS = 13
const RAW_ENTER = 10
const CLR_WHITE = 0xFF
const CLR_GREEN = 0x1C
const CLR_RED = 0xE0
const CH_CAPS = 0x18
const CH_ENTER = 0x0D
const CH_ENTER2 = 0x0A
const CH_ESC = 0x1B
const CH_BS = 0x08
const CH_SPACE = 0x20
const CH_TILDE = 0x7E
const CH_DOT = 0x2E
const CH_SLASH = 0x2F
const CH_BSLASH = 0x5C
const CH_EQ = 0x3D
const CH_HASH = 0x23
const CH_MINUS = 0x2D
const CH_A = 0x61
const CH_Z = 0x7A
const CH_0 = 0x30
const CH_9 = 0x39
const CH_FA = 0x41
const CH_FF = 0x46
const CH_CASE = 0x20
const CH_HEXOFF = 0x37
const HEX_NIB = 0xF
const CHAR_NL = 0x0A
const LINE_MAX = 0x7F
const NAME_MAX = 15
const FILE_MAX = 0xFF
const TOKEN_MAX = 8
const DUMP_N = 16
const NOTFOUND = 0xFFFF
const WORD = 4
const ENV_N = 4
const Q_COUNT = 10
; 内核函数(经 0x23A0 跳转表)
const find_in_dir = 0x23A0
const free_entry = 0x23A4
const entry_set_name = 0x23A8
const dir_has_child = 0x23AC
const env_find = 0x23B0
const env_set = 0x23B4
const perr = 0x23B8
const reboot_entry = 0x23BC
`;

// ---- 内核(dos.asm)用常量头(无内核函数 const, 因为它是标号) ----
const KERNEL_CONSTS = `; ---- 共享常量(转换器注入) ----
const CROW = 0x2000
const CCOL = 0x2004
const CURFG = 0x2008
const ARGC = 0x200C
const DIRFLAGS = 0x2010
const CURDIR = 0x2014
const DIRLINES = 0x2018
const LINEBUF = 0x2020
const ARGV = 0x20A0
const ARGV1 = 0x20A4
const ARGV2 = 0x20A8
const DIRTMP = 0x20C0
const DIRTMP4 = 0x20C4
const NAMETMP = 0x20D0
const WRITEBUF = 0x20E0
const ENVBASE = 0x21E0
const DATEVAR = 0x2240
const CASEFLAG = 0x226C
const LAST_PROG = 0x2260
const SHELL_ENTRY = 0x2264
const STACKTOP = 0x7000
const S_UNKNOWN = 0x22E0
const S_SYNTAX = 0x22F2
const S_NF = 0x2300
const S_EXIST = 0x2310
const S_FULL = 0x231E
const S_DELOK = 0x232A
const S_SAVED = 0x2334
const S_CREATED = 0x233C
const S_NOTDIR = 0x2346
const S_NOTFILE = 0x2358
const S_PATHNF = 0x2366
const S_PROMPTNAME = 0x2378
const S_PATHNAME = 0x2380
const S_DEFAULTDATE = 0x2388
const S_NOCOPY = 0x2392
const JT_FIND_IN_DIR = 0x23A0
const JT_FREE_ENTRY = 0x23A4
const JT_ENTRY_SET = 0x23A8
const JT_DIR_CHILD = 0x23AC
const JT_ENV_FIND = 0x23B0
const JT_ENV_SET = 0x23B4
const JT_PERR = 0x23B8
const JT_REBOOT = 0x23BC
const DISK_TABLE = 32
const DISK_COUNTOF = 8
const DISK_FREEOFF = 16
const DISK_CODEEND = 20
const DISK_BASEOFF = 28
const FS_N = 64
const FS_ENTRY = 40
const FS_NAME_WORDS = 3
const FS_ENTRY_WORDS = 10
const FS_TYPEOF = 12
const FS_SIZEOF = 16
const FS_PAROF = 36
const T_FILE = 1
const T_MVT = 2
const T_DIR = 3
const T_SCO = 4
const T_SCODIR = 5
const RTEXE_BASE = 0xFD00
const SCR_W = 96
const SCR_H = 40
const SCR_LAST = 39
const SCR_LASTCOL = 95
const SCR_SCROLL = 3744
const KEY_DOWN = 0x0100
const KEY_MASK = 0x00FF
const RAW_ESC = 14
const RAW_BS = 13
const RAW_ENTER = 10
const CLR_WHITE = 0xFF
const CLR_GREEN = 0x1C
const CLR_RED = 0xE0
const CH_CAPS = 0x18
const CH_ENTER = 0x0D
const CH_ENTER2 = 0x0A
const CH_ESC = 0x1B
const CH_BS = 0x08
const CH_SPACE = 0x20
const CH_TILDE = 0x7E
const CH_DOT = 0x2E
const CH_SLASH = 0x2F
const CH_BSLASH = 0x5C
const CH_EQ = 0x3D
const CH_HASH = 0x23
const CH_MINUS = 0x2D
const CH_A = 0x61
const CH_Z = 0x7A
const CH_0 = 0x30
const CH_9 = 0x39
const CH_FA = 0x41
const CH_FF = 0x46
const CH_CASE = 0x20
const CH_HEXOFF = 0x37
const HEX_NIB = 0xF
const CHAR_NL = 0x0A
const LINE_MAX = 0x7F
const NAME_MAX = 15
const FILE_MAX = 0xFF
const TOKEN_MAX = 8
const DUMP_N = 16
const NOTFOUND = 0xFFFF
const WORD = 4
const ENV_N = 4
const Q_COUNT = 10
`;

// ---- 1. boot ----
const bootSrc = fs.readFileSync(path.join(ROOT, "sonata_boot.asm"), "utf8");
const boot = assemble(bootSrc, {});
if (boot.entry === null) throw new Error("sonata_boot.asm 缺少 main:");
console.log("boot: " + boot.size + "B (0x" + boot.size.toString(16) + "), 标号 " + Object.keys(boot.symbols).length);
const externs = boot.symbols;

// ---- 2. DOS 内核 ----
const dosSrc = fs.readFileSync(path.join(ROOT, "dos.asm"), "utf8");
const dos = assemble(KERNEL_CONSTS + "\n" + dosSrc, { externs });
if (dos.entry === null) throw new Error("dos.asm 缺少 main:");
console.log("DOS  " + dos.size + "B  entry=0x" + dos.entry.toString(16) + "  relocs=" + dos.relocs.length);

// ---- 4. 转换旧程序 ----
function convertProg(name, src) {
  // 提取 @data
  let dataSize = 0;
  let m = src.match(/^;\s*@data:\s*(\d+)/m);
  if (m) dataSize = parseInt(m[1], 10);
  // 收集 D_* 常量
  const dConsts = [];
  src = src.replace(/^const[ \t]+(D_\w+)[ \t]*=[ \t]*(0x[0-9a-fA-F]+|\d+)[ \t]*;?[^\n]*$/gm, (all, n, v) => {
    const val = v.toLowerCase().startsWith("0x") ? parseInt(v, 16) : parseInt(v, 10);
    dConsts.push([n, val]);
    return "";
  });
  // 剥离指令注释行(@name/@alias/@data 与其它)
  src = src.replace(/^;\s*@\w+:.*$/gm, "");
  // 结束跳转: shell_resume -> exit_proc; jmp perr -> call perr + jmp exit_proc
  src = src.replace(/jmp\s+shell_resume/g, "jmp exit_proc");
  // 生成数据区
  if (dConsts.length > 0) {
    dConsts.sort((a, b) => a[1] - b[1]);
    const parts = [];
    let prev = 0;
    for (const [n, off] of dConsts) {
      if (off > prev) parts.push("space " + (off - prev));
      parts.push(n + ":");
      prev = off;
    }
    if (dataSize > prev) parts.push("space " + (dataSize - prev));
    src = src.trimEnd() + "\n\n; ---- 程序数据区(转换器生成) ----\n" + parts.join("\n") + "\n";
  }
  return PROG_CONSTS + "\n" + src;
}

// ---- 3. 磁盘目录树(表项顺序 = 表索引; parent = 目录索引) ----
// 根: DOS.SCO + SYSTEM/ + BIN/ + HOME/
//   SYSTEM/  = progs/*.asm  -> *.SCO(系统文件)
//   BIN/     = mvt/*.asm    -> *.MVT(系统必需程序)
//   HOME/    = 启动默认目录(用户文件落这里)
//     PROGRAMS/ = programs/*.asm -> *.MVT(非必需示例程序)
const T_MVT = 2, T_SCO = 4, T_SCODIR = 5;
const entries = [];
entries.push({ name: "DOS.SCO", type: T_SCO, parent: 0, bytes: dos.bytes, relocs: dos.relocs, entry: dos.entry });

// SYSTEM
const sysIdx = entries.length;
entries.push({ name: "SYSTEM", type: T_SCODIR, parent: 0 });
const SKIP = new Set(["shell.asm", "help.asm", "reboot.asm", "exit.asm"]);
for (const f of fs.readdirSync(path.join(ROOT, "progs")).sort()) {
  if (!f.endsWith(".asm") || SKIP.has(f)) continue;
  const src = fs.readFileSync(path.join(ROOT, "progs", f), "utf8");
  const conv = convertProg(f, src);
  const pr = assemble(conv, { externs });
  if (pr.entry === null) throw new Error(f + " 缺少 main:");
  entries.push({ name: f.slice(0, -4).toUpperCase() + ".SCO", type: T_SCO, parent: sysIdx, bytes: pr.bytes, relocs: pr.relocs, entry: pr.entry });
  console.log("SYSTEM/" + f.padEnd(12) + String(pr.size).padStart(5) + "B  relocs=" + pr.relocs.length);
}

// BIN
const binIdx = entries.length;
entries.push({ name: "BIN", type: T_SCODIR, parent: 0 });
for (const f of fs.readdirSync(path.join(ROOT, "mvt")).sort()) {
  if (!f.endsWith(".asm")) continue;
  const src = fs.readFileSync(path.join(ROOT, "mvt", f), "utf8");
  const pr = assemble(PROG_CONSTS + "\n" + src, { externs });
  if (pr.entry === null) throw new Error(f + " 缺少 main:");
  entries.push({ name: f.slice(0, -4).toUpperCase() + ".MVT", type: T_SCO, parent: binIdx, bytes: pr.bytes, relocs: pr.relocs, entry: pr.entry });
  console.log("BIN/" + f.padEnd(12) + String(pr.size).padStart(5) + "B  relocs=" + pr.relocs.length);
}

// HOME / PROGRAMS
const homeIdx = entries.length;
entries.push({ name: "HOME", type: T_SCODIR, parent: 0 });
const progDirIdx = entries.length;
entries.push({ name: "PROGRAMS", type: T_SCODIR, parent: homeIdx });
const progDir = path.join(ROOT, "programs");
if (fs.existsSync(progDir)) {
  for (const f of fs.readdirSync(progDir).sort()) {
    if (!f.endsWith(".asm")) continue;
    const src = fs.readFileSync(path.join(progDir, f), "utf8");
    const pr = assemble(PROG_CONSTS + "\n" + src, { externs });
    if (pr.entry === null) throw new Error(f + " 缺少 main:");
    entries.push({ name: f.slice(0, -4).toUpperCase() + ".MVT", type: T_MVT, parent: progDirIdx, bytes: pr.bytes, relocs: pr.relocs, entry: pr.entry });
    console.log("PROGRAMS/" + f.padEnd(10) + String(pr.size).padStart(5) + "B  relocs=" + pr.relocs.length);
  }
}
console.log("表项总数: " + entries.length + " (容量 64)");

// ---- 4. 磁盘镜像 ----
const disk = buildDiskImage(entries);
const outPath = path.join(ROOT, "sonata_disk.bin");
fs.writeFileSync(outPath, disk);
console.log("");
console.log("磁盘镜像: " + disk.length + "B (0x" + disk.length.toString(16) + ") -> " + outPath);
if (disk.length !== 0x7fff) throw new Error("磁盘镜像应为 0x7FFF(填充代码区), 实际 " + disk.length);
console.log("下一步: 游戏内贴入 sonata_boot.asm, 导入 sonata_disk.bin, 运行.");

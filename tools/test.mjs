// ============================================================================
// tools/test.mjs — 完整版 DOS 回归测试(v3: 结构化目录 + .SCO/.MVT + 外存 FS)
// 用法: node tools/test.mjs
// ============================================================================
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const base = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const { Emu } = await import(pathToFileURL(path.join(base, "tools", "emulate.mjs")).href);
const { assemble } = await import(pathToFileURL(path.join(base, "tools", "asm.mjs")).href);

const boot = assemble(fs.readFileSync(path.join(base, "sonata_boot.asm"), "utf8"));
const disk = fs.readFileSync(path.join(base, "sonata_disk.bin"));
const emu = new Emu();
emu.loadBoot(boot.bytes);
emu.loadDisk(disk);

let pass = 0, fail = 0;
const fails = [];
function check(name, cond, detail) {
  if (cond) { pass++; console.log(`PASS  ${name}`); }
  else { fail++; fails.push(name); console.log(`FAIL  ${name}${detail ? "  [" + detail + "]" : ""}`); }
}
function contains(s) { return emu.screenText().includes(s); }
function notContains(s) { return !emu.screenText().includes(s); }
function lastLine() { const ls = emu.screenText().split("\n").filter((l) => l !== ""); return ls[ls.length - 1] ?? ""; }
function waitFor(s, maxIter = 25) {
  for (let i = 0; i < maxIter; i++) {
    if (emu.halted) return false;
    if (emu.screenText().includes(s)) return true;
    emu.run(200000);
  }
  return emu.screenText().includes(s);
}
function cmd(s) { emu.type(s + "\n"); emu.run(4000000); }
function dirCmd() {
  emu.type("DIR\n");
  const paused = waitFor("Press any key", 25);
  if (paused) emu.type(" ");
  emu.run(4000000);
}
function edit(s, content, extraWait = "") {
  emu.type(s + "\n");
  if (extraWait) waitFor(extraWait, 30);
  else emu.run(1500000);
  emu.type(content);
  emu.typeRaw([1]); // Esc 保存
  emu.run(4000000);
}

console.log("boot bytes:", boot.bytes.length, " disk bytes:", disk.length);

// ---------- 启动 ----------
emu.run(4000000);
check("启动: boot 信息被 DOS 清除(cls)", notContains("Sonata Boot"));
check("启动: DOS 横幅", contains("Sonata DOS v1.0"));
check("启动: 随机格言", [
    "Talk is cheap", "Stay hungry", "Simplicity", "Any sufficiently",
    "Programs must", "Premature optimization", "The best way",
    "Code is like", "Make it work", "First, solve",
  ].some((q) => contains(q)));
check("启动: 默认目录提示符 ~/HOME", contains("[Sonata] ~/HOME #"));
check("启动: 未死机", !emu.halted);

// ---------- HOME 默认目录 + 路径执行规则 ----------
dirCmd();
// PROGRAMS 里的程序不能裸名运行(只有 SYSTEM/BIN 全局)
cmd("CLS");
cmd("HELLO");
check("裸名 HELLO 在 HOME 不可运行", contains("Unknown command."));
// 相对路径运行
cmd("CLS");
cmd("PROGRAMS/HELLO.MVT");
check("相对路径 PROGRAMS/HELLO.MVT 运行", contains("Hello world!"));
// 绝对路径(从根)运行
cmd("CLS");
cmd("/HOME/PROGRAMS/HELLO.MVT");
check("绝对路径 /HOME/PROGRAMS/HELLO.MVT 运行", contains("Hello world!"));
// 最后组件省略后缀自动补 .MVT
cmd("CLS");
cmd("PROGRAMS/FIB");
check("路径 + 省略后缀 PROGRAMS/FIB 运行", contains("00000022"));
// 目录本身不可执行
cmd("CLS");
cmd("PROGRAMS");
check("目录作为裸名命令: Unknown command.", contains("Unknown command."));
// 不存在的路径
cmd("CLS");
cmd("NOPE/X");
check("不存在路径: Path not found.", contains("Path not found."));
dirCmd();
check("DIR HOME: 含 PROGRAMS <DIR>", contains("PROGRAMS") && contains("<DIR>"));
cmd("CD PROGRAMS");
check("CD PROGRAMS: 路径 ~/HOME/PROGRAMS", contains("[Sonata] ~/HOME/PROGRAMS #"));
dirCmd();
check("DIR PROGRAMS: HELLO.MVT", contains("HELLO.MVT"));
check("DIR PROGRAMS: HELLO.MVT 标为 MVT", contains("0040 MVT"));
check("DIR PROGRAMS: FIB.MVT", contains("FIB.MVT"));
check("DIR PROGRAMS: FIB.MVT 标为 MVT", contains("0058 MVT"));
cmd("CLS");
cmd("HELLO");
check("HELLO: .mvt 程序运行", contains("Hello world!"));
cmd("CLS");
cmd("FIB");
check("FIB: 第 10 项 0x22", contains("00000022"));
cmd("CLS");
cmd("TYPE FIB.MVT");
check("TYPE .MVT: 十六进制转储", contains("31 B0 00 00"));
cmd("CD ..");
check("CD ..: 回到 HOME", contains("[Sonata] ~/HOME #"));

// ---------- 根目录结构 ----------
cmd("CD \\");
check("CD \\: 回根", contains("[Sonata] ~ #"));
cmd("CD HOME");
cmd("TYPE PROGRAMS");
check("TYPE 目录: Not a file.", contains("Not a file."));
cmd("CD \\");
dirCmd();
check("DIR 根: DOS.SCO", contains("DOS.SCO") && contains("SCO"));
check("DIR 根: SYSTEM <DIR>", contains("SYSTEM") && contains("<DIR>"));
check("DIR 根: BIN <DIR>", contains("BIN") && contains("<DIR>"));
check("DIR 根: HOME <DIR>", contains("HOME") && contains("<DIR>"));
cmd("CD SYSTEM");
check("CD SYSTEM: 路径 ~/SYSTEM", contains("[Sonata] ~/SYSTEM #"));
dirCmd();
check("DIR SYSTEM: CLS.SCO", contains("CLS.SCO"));
check("DIR SYSTEM: VER.SCO", contains("VER.SCO"));
cmd("VER");
check("VER: 版本号", contains("Sonata DOS v1.0"));
cmd("CD \\");
cmd("CD BIN");
check("CD BIN: 路径 ~/BIN", contains("[Sonata] ~/BIN #"));
dirCmd();
check("DIR BIN: CD.MVT", contains("CD.MVT"));
check("DIR BIN: WRITE.MVT", contains("WRITE.MVT"));
cmd("CD \\");
cmd("CD HOME");
check("CD HOME: 回到默认目录", contains("[Sonata] ~/HOME #"));

// ---------- 外存文件 CRUD(HOME 内) ----------
cmd("CREATE A.TXT");
check("CREATE: Created.", contains("Created."));
cmd("WRITE B.TXT");
emu.type("hello world");
emu.typeRaw([1]);
emu.run(4000000);
check("WRITE: Saved.", contains("Saved."));
cmd("CLS");
cmd("TYPE B.TXT");
check("TYPE: hello world", contains("hello world"));
cmd("XDUMP 0");
check("XDUMP 0: 魔数 SNT1", contains("53 4E 54 31"));

// ---------- 大小写: 保留输入 + 文件名不区分大小写 + Tab 大小写锁定 ----------
cmd("CLS");
cmd("ECHO hello");
check("ECHO: 小写原样输出", emu.screenText().split("\n").filter((l) => l !== "").includes("hello"));
edit("WRITE M.TXT", "MiXeD CaSe");
check("WRITE 混合大小写: Saved.", contains("Saved."));
cmd("CLS");
cmd("TYPE M.TXT");
check("TYPE: 混合大小写原样", emu.screenText().split("\n").filter((l) => l !== "").includes("MiXeD CaSe"));
edit("WRITE foo.txt", "lowercase name");
cmd("TYPE FOO.TXT");
check("文件名不区分大小写: TYPE FOO.TXT", contains("lowercase name"));
cmd("TYPE foo.txt");
check("文件名不区分大小写: TYPE foo.txt", contains("lowercase name"));
dirCmd();
check("DIR: 文件名统一大写显示 FOO.TXT", contains("FOO.TXT"));
// Tab 大小写锁定: 开锁后字母翻转
emu.type("WRITE T.TXT\n");
emu.run(1000000);
emu.typeRaw([24]); // CapsLock 开锁
emu.type("abc");
emu.typeRaw([1]); // Esc 保存
emu.run(4000000);
check("Tab 锁定后 WRITE: Saved.", contains("Saved."));
cmd("CLS");
cmd("TYPE T.TXT");
check("Tab 锁定后 TYPE: ABC(翻转)", emu.screenText().split("\n").filter((l) => l !== "").includes("ABC"));
emu.typeRaw([24]); // CapsLock 关锁
emu.run(500000);

// ---------- REBOOT 重启到 boot(清内存) ----------
// 先开大小写锁: 重启应把它清掉
emu.typeRaw([24]); // CapsLock 开锁
emu.run(500000);
emu.type("REBOOT\n");
{
  let sawBoot = false;
  for (let i = 0; i < 60 && !sawBoot; i++) { emu.run(10000); sawBoot = emu.screenText().includes("Sonata Boot"); }
  check("REBOOT: 先出现 boot 横幅(重启到 boot)", sawBoot);
}
emu.run(3000000);
check("REBOOT: 重新打印横幅", contains("Sonata DOS v1.0"));
check("REBOOT: 回到默认目录 ~/HOME", contains("[Sonata] ~/HOME #"));
check("REBOOT: boot 横幅已被 DOS 清除", notContains("Sonata Boot"));
// 大小写锁已被内存清零: 输入小写保持小写
emu.type("echo hi\n");
emu.run(3000000);
check("REBOOT: 大小写锁已复位(小写原样回显)", contains("echo hi"));
cmd("CLS");
cmd("TYPE B.TXT");
check("REBOOT 后 TYPE B.TXT: 内容仍在", contains("hello world"));
dirCmd();
check("REBOOT 后 DIR 仍有 B.TXT", contains("B.TXT"));

// ---------- 改名/复制/删除 ----------
cmd("REN B.TXT C.TXT");
check("REN: Renamed.", contains("Renamed."));
cmd("TYPE B.TXT");
check("TYPE 旧名: File not found.", contains("File not found."));
cmd("TYPE C.TXT");
check("TYPE 新名: 内容正确", contains("hello world"));
cmd("COPY C.TXT D.TXT");
check("COPY: Copied.", contains("Copied."));
cmd("TYPE D.TXT");
check("TYPE 副本: 内容正确", contains("hello world"));
cmd("DEL C.TXT");
check("DEL: Deleted.", contains("Deleted."));
cmd("TYPE C.TXT");
check("TYPE 已删: File not found.", contains("File not found."));

// ---------- 用户目录(HOME/TEST) ----------
cmd("MD TEST");
check("MD: Directory created.", contains("Directory created."));
cmd("CD TEST");
check("CD TEST: 路径 ~/HOME/TEST", contains("[Sonata] ~/HOME/TEST #"));
edit("WRITE F.TXT", "inside dir");
cmd("TYPE F.TXT");
check("子目录内 TYPE: inside dir", contains("inside dir"));
cmd("CD ..");
cmd("RD TEST");
check("RD 非空: Directory not empty.", contains("Directory not empty."));
cmd("CD TEST");
cmd("DEL F.TXT");
cmd("CD ..");
cmd("RD TEST");
check("RD 空目录: Directory removed.", contains("Directory removed."));
cmd("CD TEST");
check("CD 已删目录: Path not found.", contains("Path not found."));

// ---------- 运行时新建 MVT 并执行(MKMVT -> .MVT) ----------
{
  const progSrc = `main:
  mov r1, 0x4F
  call print_char
  mov r1, 0x4B
  call print_char
  call print_nl
  jmp exit_proc
`;
  const prog = assemble(progSrc, { externs: boot.symbols });
  if (prog.relocs.length !== 0) throw new Error("测试程序不应有重定位: " + prog.relocs.length);
  const hex = Array.from(prog.bytes).map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join(" ");
  edit("MKMVT BEEP", hex, "Esc=save");
  check("MKMVT: Saved.", contains("Saved."));
  cmd("CLS");
  cmd("BEEP.MVT");
  check("MKMVT 运行: 输出 OK", contains("OK"));
  dirCmd();
  check("DIR: BEEP.MVT 标为 MVT", contains("BEEP.MVT") && contains("MVT"));
  cmd("COPY BEEP.MVT BEEP2.MVT");
  check("COPY MVT: Copied.", contains("Copied."));
  cmd("CLS");
  cmd("BEEP2.MVT");
  check("复制后的 MVT 可运行", contains("OK"));
  cmd("DEL BEEP2.MVT");
  check("DEL MVT: Deleted.", contains("Deleted."));
}

// ---------- 环境变量/其它命令 ----------
cmd("PROMPT $");
check("PROMPT $: 提示符为 $", lastLine() === "$");
cmd("PROMPT");
check("PROMPT 清空: 恢复默认", contains("[Sonata] ~/HOME #"));
cmd("ECHO hello");
check("ECHO: 回显", contains("hello"));
cmd("SET FOO=bar");
cmd("SET");
check("SET: FOO=bar", contains("FOO=bar"));
cmd("TIME");
check("TIME: 64 位时间戳", contains("System time: ") && contains("_"));
cmd("DATE");
check("DATE: 时间戳换算日期(epoch 1970)", contains("Date: 1970-01-01") && contains("Stamp: ") && contains("Time: "));
cmd("CLS");
check("CLS: 清屏后无横幅", notContains("Sonata DOS"));
cmd("DUMP 0");
{
  const w = Array.from(boot.bytes.slice(0, 4)).map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join(" ");
  check(`DUMP 0: ${w}`, contains(w));
}
cmd("DUMP 0 20");
{
  const w = Array.from(boot.bytes.slice(16, 20)).map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join(" ");
  check(`DUMP 0 20(长度参数, 第 2 行): ${w}`, contains(w));
}
cmd("XDUMP 0 20");
check("XDUMP 0 20(长度参数): 版本号", contains("00 00 00 02"));
cmd("HELP");
check("HELP: 命令表头", contains("Commands (type HELP <name> for details):"));
check("HELP: 包含 MKMVT 行", contains("MKMVT"));
cmd("HELP MKMVT");
check("HELP MKMVT: 说明", contains(".MVT program"));

// ---------- 未知命令 ----------
cmd("BOGUS");
check("未知命令: Unknown command.", contains("Unknown command."));

// ---------- 贪吃蛇: 键盘修复 + 绘制 + Esc 退出 ----------
cmd("CD PROGRAMS");
check("CD PROGRAMS: 提示符 ~/HOME/PROGRAMS", contains("[Sonata] ~/HOME/PROGRAMS #"));
emu.type("SNAKE\n");
{
  // 分块运行, 检查蛇是否已绘制(初始画面在启动时一次性画出)
  let drawn = false;
  for (let i = 0; i < 8 && !drawn; i++) {
    emu.run(60000);
    for (let y = 0; y < 32 && !drawn; y++) {
      for (let x = 0; x < 64; x++) {
        // 蛇头/身体的背景色字节非 0(食物只写前景色)
        if (emu.main[0x3000 + (y * 96 + x) * 4 + 2] !== 0) { drawn = true; break; }
      }
    }
  }
  check("SNAKE: 游戏区出现蛇(彩色格子)", drawn);
  // 越过第一拍(FPS=1: TICK=126,277,413 单位, 模拟器 126 单位/步 ≈ 100.2 万步)后蛇应前移一格
  emu.run(1100000);
  check("SNAKE: 固定节拍推进(蛇头 x=" + emu.main[0x2500] + ", 应从 24 前移)", emu.main[0x2500] === 25);
  {
    // 增量重绘正确性: 游戏区内蛇格(背景非 0)数必须等于蛇长(允许采样到擦尾瞬间 len-1)
    const bgCells = [];
    for (let y = 0; y < 32; y++) {
      for (let x = 0; x < 64; x++) {
        if (emu.main[0x3000 + (y * 96 + x) * 4 + 2] !== 0) bgCells.push([x, y]);
      }
    }
    const len = emu.main[0x2404]; // SNAKE_LEN
    check("SNAKE: 增量重绘无残影(蛇格数 = 长度, 得到 " + bgCells.length + " 格/长 " + len + ")",
      bgCells.length <= len && bgCells.length >= len - 1);
  }
  emu.typeRaw([1]); // Esc 键码 1(按下+释放; 弹起被忽略, 按下退出)
  let back = false;
  for (let i = 0; i < 40 && !back && !emu.halted; i++) {
    emu.run(60000);
    back = emu.screenText().includes("[Sonata]");
  }
  check("SNAKE: Esc 退出回 DOS 提示符", back && !emu.halted);
}

// ---------- FORMAT 清空用户文件(保留内置目录) ----------
cmd("FORMAT");
check("FORMAT: Disk formatted.", contains("Disk formatted."));
check("FORMAT: 回到默认目录 ~/HOME", contains("[Sonata] ~/HOME #"));
dirCmd();
check("FORMAT 后: 用户文件消失", notContains("A.TXT") && notContains("D.TXT") && notContains("BEEP.MVT"));
check("FORMAT 后: PROGRAMS 目录保留", contains("PROGRAMS") && contains("<DIR>"));
cmd("TYPE D.TXT");
check("FORMAT 后 TYPE: File not found.", contains("File not found."));
cmd("CREATE E.TXT");
check("FORMAT 后可再建文件", contains("Created."));
cmd("BEEP.MVT");
check("FORMAT 后运行 MVT: Unknown command.", contains("Unknown command."));
cmd("CD \\");
dirCmd();
check("FORMAT 后根目录仍在", contains("SYSTEM") && contains("BIN") && contains("HOME"));

// ---------- 重启与停机 ----------
emu.type("REBOOT\n");
{
  let sawBoot2 = false;
  for (let i = 0; i < 60 && !sawBoot2; i++) { emu.run(10000); sawBoot2 = emu.screenText().includes("Sonata Boot"); }
  check("最终 REBOOT: 先出现 boot 横幅", sawBoot2);
}
emu.run(3000000);
check("最终 REBOOT: 横幅", contains("Sonata DOS v1.0"));
check("最终 REBOOT: 默认目录 ~/HOME", contains("[Sonata] ~/HOME #"));
check("最终 REBOOT: 未死机", !emu.halted);
emu.type("EXIT\n");
emu.run(3000000);
check("EXIT: System halted.", contains("System halted."));
check("EXIT: 机器停机", emu.halted);

// ---------- 删除 DOS.SCO 后重启: 报错并死机(独立实例, 不污染主会话) ----------
{
  const emu2 = new Emu();
  emu2.loadBoot(boot.bytes);
  emu2.loadDisk(disk);
  emu2.run(4000000);
  emu2.type("CD \\\n");
  emu2.run(4000000);
  emu2.type("DEL DOS.SCO\n");
  emu2.run(4000000);
  check("删 DOS.SCO: Deleted.", emu2.screenText().includes("Deleted."));
  emu2.type("REBOOT\n");
  emu2.run(4000000);
  check("删 DOS.SCO 后 REBOOT: 报 No DOS.", emu2.screenText().includes("No DOS."));
  check("删 DOS.SCO 后 REBOOT: 死机", emu2.halted);
}

console.log(`\n结果: ${pass} passed, ${fail} failed`);
if (fail) { console.log("失败项:", fails.join(" | ")); process.exitCode = 1; }

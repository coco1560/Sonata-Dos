// ============================================================================
// tools/cmdtest.mjs — 逐命令审计: 每条命令独立会话, 覆盖正常 + 异常路径
// 用法: node tools/cmdtest.mjs
// ============================================================================
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const base = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const { Emu } = await import(pathToFileURL(path.join(base, "tools", "emulate.mjs")).href);
const { assemble } = await import(pathToFileURL(path.join(base, "tools", "asm.mjs")).href);

const boot = assemble(fs.readFileSync(path.join(base, "sonata_boot.asm"), "utf8"));
const disk = fs.readFileSync(path.join(base, "sonata_disk.bin"));

let pass = 0, fail = 0;
const fails = [];
function chk(name, cond, detail) {
  if (cond) { pass++; console.log("PASS  " + name); }
  else { fail++; fails.push(name); console.log("FAIL  " + name + (detail ? "  [" + detail + "]" : "")); }
}
function booted() {
  const e = new Emu();
  e.loadBoot(boot.bytes);
  e.loadDisk(disk);
  e.run(4000000);
  return e;
}
function cmd(e, s, steps = 4000000) { e.type(s + "\n"); e.run(steps); }
function scr(e) { return e.screenText(); }
function has(e, s) { return scr(e).includes(s); }
function lastLine(e) { const ls = scr(e).split("\n").filter((l) => l !== ""); return ls[ls.length - 1] ?? ""; }
function waitFor(e, s, maxIter = 25) {
  for (let i = 0; i < maxIter; i++) {
    if (e.halted) return false;
    if (scr(e).includes(s)) return true;
    e.run(200000);
  }
  return scr(e).includes(s);
}
// WRITE/MKMVT 式编辑器: 输命令 -> 输内容 -> Esc 保存
function editCmd(e, command, content) {
  e.type(command + "\n"); e.run(1500000);
  e.type(content);
  e.typeRaw([14]); // Esc 保存
  e.run(3000000);
}
const hex4 = (buf, off) => Array.from(buf.slice(off, off + 4)).map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join(" ");

console.log("=== Sonata DOS 逐命令审计 ===");

// ---------- 1. CLS ----------
{
  const e = booted();
  cmd(e, "CLS");
  chk("CLS: 清屏后无横幅", !scr(e).includes("Sonata DOS"));
  chk("CLS: 提示符重绘", has(e, "[Sonata] ~/HOME #"));
}

// ---------- 2. DATE ----------
{
  const e = booted();
  cmd(e, "DATE");
  chk("DATE: Stamp/Date/Time 输出", has(e, "Stamp: ") && has(e, "Date: 1970-01-01") && has(e, "Time: "));
  cmd(e, "DATE 20250101");
  chk("DATE 8位参数: Date set.", has(e, "Date set."));
  cmd(e, "DATE 12");
  chk("DATE 非法参数: Invalid date.", has(e, "Invalid date."));
}

// ---------- 3. TIME ----------
{
  const e = booted();
  cmd(e, "TIME");
  chk("TIME: 完整 64 位时间戳", has(e, "System time: ") && /[0-9A-F]{8}_[0-9A-F]{8}/.test(scr(e)));
  cmd(e, "TIME 5");
  chk("TIME 带参数: Cannot set time on this hardware.", has(e, "Cannot set time"));
}

// ---------- 4. VER ----------
{
  const e = booted();
  cmd(e, "VER");
  chk("VER: 版本号", has(e, "Sonata DOS v3.0"));
}

// ---------- 5. ECHO ----------
{
  const e = booted();
  cmd(e, "ECHO hello");
  chk("ECHO: 输出 hello", has(e, "hello"));
  cmd(e, "ECHO a b c");
  chk("ECHO 多参数: a b c", has(e, "a b c"));
  cmd(e, "ECHO");
  chk("ECHO 无参: 只换行", lastLine(e) === "[Sonata] ~/HOME #");
}

// ---------- 6. PATH ----------
{
  const e = booted();
  cmd(e, "PATH");
  chk("PATH 未设: PATH=", has(e, "PATH="));
  cmd(e, "PATH MYBIN");
  cmd(e, "PATH");
  chk("PATH 设置后: MYBIN", has(e, "MYBIN"));
}

// ---------- 7. PROMPT ----------
{
  const e = booted();
  cmd(e, "PROMPT $");
  chk("PROMPT $: 提示符 $", lastLine(e) === "$");
  cmd(e, "PROMPT hi");
  chk("PROMPT hi: 提示符 hi", lastLine(e) === "hi");
  cmd(e, "PROMPT");
  chk("PROMPT 清空: 恢复默认", has(e, "[Sonata] ~/HOME #"));
}

// ---------- 8. SET ----------
{
  const e = booted();
  cmd(e, "SET FOO=bar");
  chk("SET NAME=值: Set.", has(e, "Set."));
  cmd(e, "SET");
  chk("SET 列表: FOO=bar", has(e, "FOO=bar"));
  cmd(e, "SET FOO");
  chk("SET 查询: FOO=bar", has(e, "FOO=bar"));
  cmd(e, "SET FOO baz");
  chk("SET NAME 值: Set.", has(e, "Set."));
  cmd(e, "SET FOO");
  chk("SET 空格形式生效: FOO=baz", has(e, "FOO=baz"));
  cmd(e, "SET NOVAR");
  chk("SET 未定义: Variable not set.", has(e, "Variable not set."));
}

// ---------- 9. DUMP ----------
{
  const e = booted();
  cmd(e, "DUMP 0");
  chk("DUMP 0: 首 4 字节 " + hex4(boot.bytes, 0), has(e, hex4(boot.bytes, 0)));
  cmd(e, "DUMP 0 20");
  chk("DUMP 0 20(十六进制长度=32): 第 2 行 " + hex4(boot.bytes, 16), has(e, hex4(boot.bytes, 16)));
  cmd(e, "DUMP");
  chk("DUMP 无参: Syntax error.", has(e, "Syntax error."));
}

// ---------- 10. XDUMP ----------
{
  const e = booted();
  cmd(e, "XDUMP 0");
  chk("XDUMP 0: 魔数 53 4E 54 31", has(e, "53 4E 54 31"));
  cmd(e, "XDUMP 0 20");
  chk("XDUMP 0 20: 版本 00 00 00 02", has(e, "00 00 00 02"));
  cmd(e, "XDUMP");
  chk("XDUMP 无参: Syntax error.", has(e, "Syntax error."));
}

// ---------- 11. CD ----------
{
  const e = booted();
  cmd(e, "CD");
  chk("CD 无参: 显示 HOME", has(e, "HOME"));
  cmd(e, "CD PROGRAMS");
  chk("CD 目录: 提示符 ~/HOME/PROGRAMS", has(e, "[Sonata] ~/HOME/PROGRAMS #"));
  cmd(e, "CD ..");
  chk("CD ..: 回 HOME", has(e, "[Sonata] ~/HOME #"));
  cmd(e, "CD \\");
  chk("CD \\: 回根", has(e, "[Sonata] ~ #"));
  cmd(e, "CD NOPE");
  chk("CD 不存在: Path not found.", has(e, "Path not found."));
  cmd(e, "CD HOME");
  cmd(e, "CD PROGRAMS");
  cmd(e, "CD HELLO.MVT");
  chk("CD 文件: Not a directory.", has(e, "Not a directory."));
  cmd(e, "CD ..");
  cmd(e, "cd programs");
  chk("CD 小写参数: 进入 PROGRAMS", has(e, "[Sonata] ~/HOME/PROGRAMS #"));
}

// ---------- 12. MD / RD ----------
{
  const e = booted();
  cmd(e, "MD T1");
  chk("MD: Directory created.", has(e, "Directory created."));
  cmd(e, "MD T1");
  chk("MD 已存在: File exists.", has(e, "File exists."));
  cmd(e, "MD");
  chk("MD 无参: Syntax error.", has(e, "Syntax error."));
  cmd(e, "RD T1");
  chk("RD 空目录: Directory removed.", has(e, "Directory removed."));
  cmd(e, "RD T1");
  chk("RD 不存在: Path not found.", has(e, "Path not found."));
  cmd(e, "RD PROGRAMS");
  chk("RD 非空: Directory not empty.", has(e, "Directory not empty."));
  cmd(e, "CREATE F.TXT");
  cmd(e, "RD F.TXT");
  chk("RD 文件: Not a directory.", has(e, "Not a directory."));
}

// ---------- 13. CREATE / DEL ----------
{
  const e = booted();
  cmd(e, "CREATE A.TXT");
  chk("CREATE: Created.", has(e, "Created."));
  cmd(e, "CREATE A.TXT");
  chk("CREATE 已存在: File exists.", has(e, "File exists."));
  cmd(e, "CREATE");
  chk("CREATE 无参: Syntax error.", has(e, "Syntax error."));
  cmd(e, "DEL A.TXT");
  chk("DEL: Deleted.", has(e, "Deleted."));
  cmd(e, "DEL A.TXT");
  chk("DEL 不存在: File not found.", has(e, "File not found."));
  cmd(e, "DEL PROGRAMS");
  chk("DEL 目录: Not a file.", has(e, "Not a file."));
  cmd(e, "DEL");
  chk("DEL 无参: Syntax error.", has(e, "Syntax error."));
}

// ---------- 14. REN ----------
{
  const e = booted();
  cmd(e, "CREATE A.TXT");
  cmd(e, "REN A.TXT B.TXT");
  chk("REN: Renamed.", has(e, "Renamed."));
  cmd(e, "TYPE A.TXT");
  chk("REN 后旧名消失: File not found.", has(e, "File not found."));
  cmd(e, "CREATE C.TXT");
  cmd(e, "REN B.TXT C.TXT");
  chk("REN 目标已存在: File exists.", has(e, "File exists."));
  cmd(e, "REN NOPE X");
  chk("REN 源不存在: File not found.", has(e, "File not found."));
  cmd(e, "REN A");
  chk("REN 缺参: Syntax error.", has(e, "Syntax error."));
}

// ---------- 15. COPY ----------
{
  const e = booted();
  editCmd(e, "WRITE SRC.TXT", "hello world");
  cmd(e, "COPY SRC.TXT DST.TXT");
  chk("COPY: Copied.", has(e, "Copied."));
  cmd(e, "TYPE DST.TXT");
  chk("COPY 内容一致: hello world", has(e, "hello world"));
  cmd(e, "COPY SRC.TXT DST.TXT");
  chk("COPY 目标已存在: File exists.", has(e, "File exists."));
  cmd(e, "COPY NOPE X");
  chk("COPY 源不存在: File not found.", has(e, "File not found."));
  cmd(e, "COPY PROGRAMS X");
  chk("COPY 目录: Cannot copy.", has(e, "Cannot copy."));
  cmd(e, "COPY A");
  chk("COPY 缺参: Syntax error.", has(e, "Syntax error."));
}

// ---------- 16. TYPE ----------
{
  const e = booted();
  editCmd(e, "WRITE A.TXT", "hello world");
  cmd(e, "TYPE A.TXT");
  chk("TYPE 文本: hello world", has(e, "hello world"));
  cmd(e, "TYPE NOPE");
  chk("TYPE 不存在: File not found.", has(e, "File not found."));
  cmd(e, "TYPE PROGRAMS");
  chk("TYPE 目录: Not a file.", has(e, "Not a file."));
  cmd(e, "TYPE");
  chk("TYPE 无参: Syntax error.", has(e, "Syntax error."));
  cmd(e, "CD PROGRAMS");
  cmd(e, "TYPE HELLO.MVT");
  chk("TYPE MVT: 十六进制转储", /[0-9A-F]{2} [0-9A-F]{2} [0-9A-F]{2}/.test(scr(e)));
}

// ---------- 17. WRITE ----------
{
  const e = booted();
  editCmd(e, "WRITE A.TXT", "hello world");
  chk("WRITE 保存: Saved.", has(e, "Saved."));
  cmd(e, "CLS");
  cmd(e, "TYPE A.TXT");
  chk("WRITE 内容落盘: hello world", has(e, "hello world"));
  // 跨行退格: "ab\n" 后退格删除换行, 再输入 cd -> 文件应为 "abcd"
  e.type("WRITE A.TXT\n"); e.run(1500000);
  e.type("ab\n"); e.run(800000);
  e.typeRaw([13]); e.run(800000);      // Backspace 删除换行
  e.type("cd"); e.run(800000);
  e.typeRaw([14]); e.run(3000000);      // Esc 保存
  cmd(e, "CLS");
  cmd(e, "TYPE A.TXT");
  chk("WRITE 跨行退格: 换行被删, 内容为 abcd", has(e, "abcd"));
  editCmd(e, "WRITE A.TXT", "second");
  cmd(e, "CLS");
  cmd(e, "TYPE A.TXT");
  chk("WRITE 覆盖: second(旧内容消失)", has(e, "second") && !has(e, "hello world"));
  cmd(e, "WRITE PROGRAMS");
  chk("WRITE 非数据文件: File exists.", has(e, "File exists."));
  cmd(e, "WRITE");
  chk("WRITE 无参: Syntax error.", has(e, "Syntax error."));
}

// ---------- 18. MKMVT ----------
{
  const e = booted();
  const progSrc = `main:
  mov r1, 0x4F
  call print_char
  mov r1, 0x4B
  call print_char
  call print_nl
  jmp exit_proc
`;
  const prog = assemble(progSrc, { externs: boot.symbols });
  const hex = Array.from(prog.bytes).map((b) => b.toString(16).padStart(2, "0").toUpperCase()).join(" ");
  editCmd(e, "MKMVT BEEP", hex);
  chk("MKMVT 保存: Saved.", has(e, "Saved."));
  cmd(e, "BEEP.MVT");
  chk("MKMVT 运行: 输出 OK", has(e, "OK"));
  cmd(e, "MKMVT");
  chk("MKMVT 无参: Syntax error.", has(e, "Syntax error."));
  cmd(e, "MKMVT BEEP");
  chk("MKMVT 已存在: File exists.", has(e, "File exists."));
}

// ---------- 19. DIR ----------
{
  const e = booted();
  cmd(e, "DIR");
  chk("DIR HOME: PROGRAMS <DIR>", has(e, "PROGRAMS") && has(e, "<DIR>"));
  cmd(e, "MD EMPTY");
  cmd(e, "CD EMPTY");
  cmd(e, "DIR");
  chk("DIR 空目录: No files.", has(e, "No files."));
  cmd(e, "CD ..");
  for (let i = 0; i < 25; i++) cmd(e, "CREATE F" + i);
  e.type("DIR\n"); e.run(1000000);
  chk("DIR 分页: Press any key", has(e, "Press any key"));
  e.type(" "); e.run(4000000);
  chk("DIR 分页继续: F24", has(e, "F24"));
}

// ---------- 20. HELP ----------
{
  const e = booted();
  cmd(e, "HELP");
  chk("HELP: 命令表头", has(e, "Commands (type HELP <name> for details):"));
  chk("HELP: 含 MKMVT 行", has(e, "MKMVT"));
  cmd(e, "HELP CD");
  chk("HELP CD: 说明", has(e, "Change directory"));
  cmd(e, "help cd");
  chk("HELP 小写: 说明", has(e, "Change directory"));
  cmd(e, "HELP BOGUS");
  chk("HELP 未知: No help for BOGUS", has(e, "No help for BOGUS"));
}

// ---------- 21. FORMAT ----------
{
  const e = booted();
  cmd(e, "CREATE A.TXT");
  cmd(e, "MD D1");
  cmd(e, "CD PROGRAMS");
  cmd(e, "FORMAT");
  chk("FORMAT: Disk formatted.", has(e, "Disk formatted."));
  chk("FORMAT: 回 HOME", has(e, "[Sonata] ~/HOME #"));
  cmd(e, "CD PROGRAMS");
  chk("FORMAT 后内置目录保留", has(e, "[Sonata] ~/HOME/PROGRAMS #"));
  cmd(e, "CD ..");
  cmd(e, "CLS");
  cmd(e, "DIR");
  chk("FORMAT 后用户文件消失", !has(e, "A.TXT") && !has(e, "D1"));
}

// ---------- 22. REBOOT ----------
{
  const e = booted();
  e.type("REBOOT\n");
  let saw = false;
  for (let i = 0; i < 200 && !saw; i++) { e.run(10000); saw = scr(e).includes("Sonata Boot"); }
  chk("REBOOT: 先出 boot 横幅", saw);
  e.run(3000000);
  chk("REBOOT: 回 DOS 提示符", has(e, "Sonata DOS v3.0") && has(e, "[Sonata] ~/HOME #"));
}

// ---------- 23. EXIT ----------
{
  const e = booted();
  cmd(e, "EXIT");
  chk("EXIT: System halted.", has(e, "System halted."));
  chk("EXIT: 机器停机", e.halted);
}

// ---------- 24. 未知命令 ----------
{
  const e = booted();
  cmd(e, "BOGUS");
  chk("未知命令: Unknown command.", has(e, "Unknown command."));
}

// ---------- 25. 程序执行(路径/裸名) ----------
{
  const e = booted();
  cmd(e, "PROGRAMS/HELLO.MVT");
  chk("路径执行: Hello world!", has(e, "Hello world!"));
  cmd(e, "CLS");
  cmd(e, "CD PROGRAMS");
  e.type("SNAKE\n");
  e.run(1200000);
  const hx = e.main[0x2500];
  chk("SNAKE 启动(蛇头初始化)", hx === 24 || hx === 25);
  e.typeRaw([14]);
  let back = false;
  for (let i = 0; i < 40 && !back && !e.halted; i++) { e.run(60000); back = scr(e).includes("[Sonata]"); }
  chk("SNAKE Esc 退出", back && !e.halted);
}

console.log(`\n结果: ${pass} passed, ${fail} failed`);
if (fail) { console.log("失败项:", fails.join(" | ")); process.exitCode = 1; }

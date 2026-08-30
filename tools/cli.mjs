#!/usr/bin/env node
// ============================================================================
// tools/cli.mjs — 交互式 CLI 模拟器: 在终端里实时运行 Symphony(游戏外模拟游戏)
//
// 用法:
//   node tools/cli.mjs [选项]
//   选项:
//     --speed N    模拟速度, 步/秒(默认 1000000; 贪吃蛇 TICK=1e9/1000 = 100 万步 -> 1 格/秒)
//     --fps N      渲染帧率(默认 60)
//     --boot FILE  汇编的 boot 源(默认 sonata_boot.asm)
//     --disk FILE  磁盘镜像(默认 sonata_disk.bin)
//     --smoke [N]  无头自检: 先(可选)注入 --type 文本, 再跑 N 步(默认 4000000),
//                  打印屏幕文本/停机状态后退出
//     --type TEXT  在 --type-at 步时把文本作为按键注入(交互模式也可用)
//     --type-at N  注入按键的步数(默认 1000000)
//     --frames N   无头渲染自检: 跑 N 帧后退出(输出 ANSI 帧, 校验渲染路径)
//     --keylog     状态栏显示最近按键事件
//
// 交互按键:
//   Ctrl+C 退出   Ctrl+P 暂停/继续   Ctrl+T 3 倍速开关   Ctrl+K 发送 CapsLock(0x18)
//   键码: Esc=1, Enter=10, Backspace=13, Tab=9; 其它键按 ASCII 发按下+弹起
// ============================================================================
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { Emu } from "./emulate.mjs";
import { assemble } from "./asm.mjs";

const BASE = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1")), "..");
const argv = process.argv.slice(2);
function argVal(name, def) {
  const i = argv.indexOf(name);
  const v = i >= 0 ? argv[i + 1] : undefined;
  return v !== undefined && !v.startsWith("--") ? v : def;
}
const SPEED = Math.max(1000, parseInt(argVal("--speed", "1000000"), 10) || 1000000);
const FPS = Math.max(1, parseInt(argVal("--fps", "60"), 10) || 60);
const BOOT_PATH = path.resolve(argVal("--boot", path.join(BASE, "sonata_boot.asm")));
const DISK_PATH = path.resolve(argVal("--disk", path.join(BASE, "sonata_disk.bin")));
const SMOKE = argv.includes("--smoke") ? parseInt(argVal("--smoke", "4000000"), 10) || 4000000 : 0;
const FRAMES = argv.includes("--frames") ? parseInt(argVal("--frames", "1"), 10) || 1 : 0;
const TYPE_TEXT = argVal("--type", "");
const TYPE_AT = parseInt(argVal("--type-at", "1000000"), 10) || 1000000;
const KEYLOG = argv.includes("--keylog");

// ---------- 汇编 boot + 装载 ----------
const boot = assemble(fs.readFileSync(BOOT_PATH, "utf8"), {});
if (boot.entry === null) { console.error("boot 缺少 main:"); process.exit(1); }
const emu = new Emu();
emu.loadBoot(boot.bytes);
emu.loadDisk(fs.readFileSync(DISK_PATH));

// ---------- 调色板: 游戏 8 位色 = RRGGGBBB ----------
// (实测锚点: 0x1C 绿, 0xE0 红, 0xFC 黄, 0xFF 白; fg=0 为不可见)
function rgbOf(c) {
  return [
    Math.round(((c >> 5) & 7) * 255 / 7),
    Math.round(((c >> 2) & 7) * 255 / 7),
    Math.round((c & 3) * 255 / 3),
  ];
}

// ---------- 渲染(差异重绘 96x40 + 第 41 行状态栏) ----------
const W = 96, H = 40;
const FB0 = 0x3000;
const prev = new Uint8Array(W * H * 4).fill(0xff);
let paused = false, turbo = false;
let lastKeys = [];

function cellAnsi(ch, fg, bg) {
  let s = "";
  if (fg !== 0) {
    const [r, g, b] = rgbOf(fg);
    s += "\x1b[38;2;" + r + ";" + g + ";" + b + "m";
  }
  if (bg !== 0) {
    const [r, g, b] = rgbOf(bg);
    s += "\x1b[48;2;" + r + ";" + g + ";" + b + "m";
  }
  if (s === "") s = "\x1b[0m";
  s += (fg !== 0 && ch >= 32 && ch < 127) ? String.fromCharCode(ch) : " ";
  return s;
}

function render() {
  const fb = emu.opts.get(1) ?? FB0;
  let out = "";
  for (let r = 0; r < H; r++) {
    for (let c = 0; c < W; c++) {
      const off = (r * W + c) * 4;
      const cell = fb + off;
      if (
        prev[off] === emu.main[cell] && prev[off + 1] === emu.main[cell + 1] &&
        prev[off + 2] === emu.main[cell + 2] && prev[off + 3] === emu.main[cell + 3]
      ) continue;
      prev[off] = emu.main[cell];
      prev[off + 1] = emu.main[cell + 1];
      prev[off + 2] = emu.main[cell + 2];
      prev[off + 3] = emu.main[cell + 3];
      out += "\x1b[" + (r + 1) + ";" + (c + 1) + "H" +
        cellAnsi(prev[off], prev[off + 1], prev[off + 2]);
    }
  }
  const eff = Math.floor(SPEED / FPS) * FPS * (turbo ? 3 : 1);
  let status = "\x1b[41;1H\x1b[K\x1b[0m" +
    "Sonata CLI | 步骤 " + emu.steps + " | 速度 " + eff + " 步/秒" +
    (turbo ? "(3x)" : "") + (paused ? " [已暂停]" : "") +
    (emu.halted ? " [机器已停机]" : "") +
    " | Ctrl+C 退出 Ctrl+P 暂停 Ctrl+T 加速 Ctrl+K CapsLock";
  if (KEYLOG && lastKeys.length) status += " | 键: " + lastKeys.join(",");
  out += status;
  process.stdout.write(out);
}

// ---------- 按键输入 ----------
const KEY = { ENTER: 10, BACK: 13, ESC: 1, TAB: 9, CAPS: 0x18 };
let escBuf = null, escTimer = null, quitting = false;

function pushKey(c) {
  emu.keys.push(0x100 | c, c); // 按下(bit8=0) + 弹起(bit8=1)
  lastKeys.push("0x" + c.toString(16).padStart(2, "0"));
  if (lastKeys.length > 3) lastKeys.shift();
}

function quit() {
  if (quitting) return;
  quitting = true;
  clearTimeout(escTimer);
  process.stdout.write("\x1b[0m\x1b[?25h\x1b[?1049l\r\n", () => process.exit(0));
  if (process.stdin.isTTY) { try { process.stdin.setRawMode(false); } catch { /* ignore */ } }
}

function handleByte(b) {
  if (escBuf !== null) {
    escBuf.push(b);
    if (escBuf[1] !== 0x5b) {
      // 不是 "ESC [" 序列(如连按 Esc 或 Esc+字符): 补发 Esc 再处理本字节
      escBuf = null;
      clearTimeout(escTimer);
      escTimer = null;
      pushKey(KEY.ESC);
      handleByte(b);
    } else {
      clearTimeout(escTimer);
      escTimer = null;
      if (b >= 0x40 && b <= 0x7e) escBuf = null; // 完整序列(方向键等): 忽略
    }
    return;
  }
  if (b === 0x1b) {
    escBuf = [0x1b];
    escTimer = setTimeout(() => { pushKey(KEY.ESC); escBuf = null; escTimer = null; }, 40);
    return;
  }
  switch (b) {
    case 0x03: quit(); return;                      // Ctrl+C
    case 0x10: paused = !paused; return;            // Ctrl+P 暂停
    case 0x14: turbo = !turbo; return;              // Ctrl+T 加速
    case 0x0b:                                     // Ctrl+K -> CapsLock(0x18)
      emu.keys.push(0x100 | KEY.CAPS, KEY.CAPS);
      lastKeys.push("CAPS");
      return;
    case 0x0d: pushKey(KEY.ENTER); return;          // Enter
    case 0x08: case 0x7f: pushKey(KEY.BACK); return; // Backspace
    case 0x09: pushKey(KEY.TAB); return;            // Tab
    default:
      if (b >= 0x20 && b <= 0x7e) pushKey(b);       // 可打印 ASCII
  }
}

// ---------- 无头自检 --smoke ----------
if (SMOKE > 0) {
  if (TYPE_TEXT) { emu.run(TYPE_AT); emu.type(TYPE_TEXT); }
  emu.run(SMOKE);
  console.log(emu.screenText());
  console.log("[smoke] steps=" + emu.steps + " halted=" + emu.halted +
    " pc=0x" + emu.pc.toString(16) + " stdout=" +
    JSON.stringify(Buffer.from(emu.stdout).toString("utf8")));
  process.exit(0);
}

// ---------- 交互模式 ----------
if (FRAMES > 0) {
  // 无头渲染自检: 跑 N 帧(每帧 stepsPerFrame 步)后退出
  let done = 0;
  const stepsPerFrame = Math.max(1, Math.floor(SPEED / FPS));
  let typed = false;
  const tick = () => {
    if (!typed && TYPE_TEXT && emu.steps >= TYPE_AT) { emu.type(TYPE_TEXT); typed = true; }
    if (!emu.halted) emu.run(stepsPerFrame);
    render();
    if (++done >= FRAMES) quit();
    else setTimeout(tick, 1);
  };
  tick();
} else if (process.stdin.isTTY) {
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.on("data", (chunk) => {
    if (quitting) return;
    for (const b of chunk) handleByte(b);
  });
  process.stdout.write("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H");
  const stepsPerFrame = Math.max(1, Math.floor(SPEED / FPS));
  let typed = false;
  let nextFrame = Date.now();
  const frame = () => {
    if (quitting) return;
    if (!typed && TYPE_TEXT && emu.steps >= TYPE_AT) { emu.type(TYPE_TEXT); typed = true; }
    if (!paused && !emu.halted) emu.run(turbo ? stepsPerFrame * 3 : stepsPerFrame);
    render();
    nextFrame += 1000 / FPS;
    setTimeout(frame, Math.max(0, nextFrame - Date.now()));
  };
  frame();
} else {
  console.error("[cli] 标准输入不是终端。交互模式需要真实终端; 无头自检请用:");
  console.error("      node tools/cli.mjs --smoke [步数] [--type \"命令\\n\"]");
  console.error("      或 node tools/cli.mjs --frames N 校验渲染路径");
  process.exit(1);
}

process.on("SIGINT", quit);

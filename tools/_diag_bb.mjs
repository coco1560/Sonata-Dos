import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
const base = process.cwd();
const { Emu } = await import(pathToFileURL(path.join(base, "tools", "emulate.mjs")).href);
const { assemble } = await import(pathToFileURL(path.join(base, "tools", "asm.mjs")).href);
const boot = assemble(fs.readFileSync(path.join(base, "sonata_boot.asm"), "utf8"));
const emu = new Emu();
emu.loadBoot(boot.bytes);
emu.loadDisk(fs.readFileSync(path.join(base, "sonata_disk.bin")));
emu.run(4000000);
emu.type("CD PROGRAMS\n");
emu.run(4000000);
emu.type("SNAKE\n");
for (let i = 0; i < 6; i++) {
  emu.run(300000);
  console.log("chunk", i, "steps", emu.steps, "pc=0x" + emu.pc.toString(16), "headX", emu.main[0x2500]);
}
const cell = (base, y, x) => Array.from(emu.main.slice(base + (y * 96 + x) * 4, base + (y * 96 + x) * 4 + 4)).map(b => b.toString(16).padStart(2, "0")).join("");
console.log("BB(16,24):", cell(0xB000, 16, 24), "| FB(16,24):", cell(0x3000, 16, 24));
// 反汇编 pc 附近
for (let a = emu.pc - 8; a < emu.pc + 12; a += 4) {
  const w = emu.rd32(a);
  console.log("0x" + a.toString(16) + ": op=0x" + (w >>> 24).toString(16), "d=" + ((w >>> 20) & 15), "s1=" + ((w >>> 16) & 15), "s2=" + ((w >>> 8) & 15), "imm=0x" + (w & 0xffff).toString(16));
}

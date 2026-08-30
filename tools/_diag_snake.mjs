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
const rd32 = (a) => ((emu.main[a] << 24) | (emu.main[a+1] << 16) | (emu.main[a+2] << 8) | emu.main[a+3]) >>> 0;
const TIME0 = 0x12345678;
let lastHead = -1;
for (let i = 0; i < 60; i++) {
  emu.run(60000);
  const hx = emu.main[0x2500];
  const next = rd32(0x240C);
  const now = (TIME0 + emu.steps) >>> 0;
  if (hx !== lastHead || i % 5 === 0) {
    console.log("chunk", i, "steps", emu.steps, "headX", hx, "NEXT_TICK=0x" + next.toString(16), "now=0x" + now.toString(16), "halted", emu.halted);
    lastHead = hx;
  }
  if (emu.halted) break;
}

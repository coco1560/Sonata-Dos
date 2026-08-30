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
// run until NEXT_TICK becomes non-zero, then step single instructions in that window
let launched = false, count = 0;
for (let i = 0; i < 9000000 && !launched; i++) {
  emu.step();
  if (rd32(0x240C) !== 0 && emu.main[0x2500] !== 0) {
    // rewind-ish: we're already past; just step 60 more and print everything
    launched = true;
    for (let j = 0; j < 60; j++) {
      const pc = emu.pc;
      const w = emu.rd32(pc);
      const op = w >>> 24;
      const R = emu.regs;
      const inWait = (pc >= 0x90c0 && pc <= 0x9160);
      if (inWait || j < 8) {
        console.log("pc=0x" + pc.toString(16), "op=0x" + op.toString(16),
          "r1=", R[1], "r2=", R[2], "flags=" + (R[15] | 0), "NT=0x" + rd32(0x240C).toString(16));
      }
      emu.step();
    }
  }
}
console.log("done steps", emu.steps);

// ============================================================================
// tools/disk.mjs — Sonata 磁盘镜像打包器(v3: 可写容量表 + 目录树)
//
// 磁盘镜像格式(所有数值字段大端 u32, 镜像填充到 0x7FFF):
//   +0   魔数 4B "SNT1"                +4  版本 4B (=2)
//   +8   文件数 4B(活动表项)           +12 容量 4B (=64)
//   +16  freeOff 4B(代码区空闲指针)    +20 codeEnd 4B (=0x7FFF)
//   +24  tableBase 4B (=32, 固定)
//   +28  baseOff 4B(构建完成后的 freeOff, FORMAT 复位用)
//   +32  文件表 64 x 40B:
//          [名字 12B(NUL 补齐)][类型 4B][大小 4B][入口偏移 4B][代码偏移 4B]
//          [重定位数 4B][重定位表偏移 4B][父目录 4B]
//        类型: 0=空闲 1=DATA 2=MVT(运行时) 3=DIR(用户目录)
//              4=SCO(内置程序) 5=SCODIR(内置目录, 受 FORMAT 保护)
//   代码区: 各文件机器码(4 字节对齐); 重定位区: 各文件重定位表(每项 4B 偏移)
//   运行时新建文件从 freeOff 起分配, 写到代码区尾部, 故镜像必须填充整个区域
//
// 游戏实测: 外存按字节编址且 32 位字为大端序, 故数值字段 BE 写入;
// 代码区是纯字节流, 原样写入即可。
// ============================================================================

export const DISK_V2 = {
  MAGIC: "SNT1",
  VERSION: 2,
  CAPACITY: 64,
  ENTRY: 40,
  TBL_BASE: 32,
  CODE_END: 0x7fff,
  T_FILE: 1,
  T_MVT: 2,
  T_DIR: 3,
  T_SCO: 4,
  T_SCODIR: 5,
};

/**
 * entries: [{ name, type, parent, bytes?(Uint8Array), relocs?(number[]), entry? }]
 * 目录项(无 bytes)只占表项; 文件项顺序即表索引, parent 为目录索引。
 */
export function buildDiskImage(entries) {
  const C = DISK_V2;
  if (entries.length > C.CAPACITY) throw new Error("too many entries: " + entries.length);
  const tableEnd = C.TBL_BASE + C.CAPACITY * C.ENTRY;
  const L = [];
  let off = tableEnd;
  for (const e of entries) {
    if (e.name.length > 12) throw new Error("file name too long: " + e.name + " (max 12)");
    if (e.parent === undefined || e.parent < 0 || e.parent >= entries.length) throw new Error("bad parent for " + e.name + ": " + e.parent);
    if (e.bytes) {
      off = (off + 3) & ~3;
      L.push({ ...e, codeOff: off });
      off += e.bytes.length;
    } else {
      L.push({ ...e, bytes: null, relocs: [], entry: 0, codeOff: 0 });
    }
  }
  for (const p of L) {
    if (!p.bytes) continue;
    off = (off + 3) & ~3;
    p.relocOff = off;
    off += p.relocs.length * 4;
  }
  if (off > C.CODE_END) throw new Error("disk image too large: 0x" + off.toString(16) + " > 0x" + C.CODE_END.toString(16));
  const buf = Buffer.alloc(C.CODE_END); // 填充到 codeEnd(全 0)

  buf.write(C.MAGIC, 0, "ascii");
  buf.writeUInt32BE(C.VERSION, 4);
  buf.writeUInt32BE(L.length, 8);
  buf.writeUInt32BE(C.CAPACITY, 12);
  buf.writeUInt32BE(off, 16); // freeOff = 构建数据末端
  buf.writeUInt32BE(C.CODE_END, 20);
  buf.writeUInt32BE(C.TBL_BASE, 24);
  buf.writeUInt32BE(off, 28); // baseOff = 构建数据末端(FORMAT 复位)

  L.forEach((e, i) => {
    const p = C.TBL_BASE + i * C.ENTRY;
    const nm = Buffer.alloc(12);
    nm.write(e.name, 0, "ascii");
    nm.copy(buf, p);
    buf.writeUInt32BE(e.type, p + 12);
    if (e.bytes) {
      buf.writeUInt32BE(e.bytes.length, p + 16);
      buf.writeUInt32BE(e.entry ?? 0, p + 20);
      buf.writeUInt32BE(e.codeOff, p + 24);
      buf.writeUInt32BE(e.relocs.length, p + 28);
      buf.writeUInt32BE(e.relocOff, p + 32);
      buf.writeUInt32BE(e.parent, p + 36);
      Buffer.from(e.bytes).copy(buf, e.codeOff);
      e.relocs.forEach((r, j) => buf.writeUInt32BE(r, e.relocOff + j * 4));
    } else {
      buf.writeUInt32BE(0, p + 16);
      buf.writeUInt32BE(0, p + 20);
      buf.writeUInt32BE(0, p + 24);
      buf.writeUInt32BE(0, p + 28);
      buf.writeUInt32BE(0, p + 32);
      buf.writeUInt32BE(e.parent, p + 36);
    }
  });

  return buf;
}

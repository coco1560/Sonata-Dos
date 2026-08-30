; ============================================================================
; SONATA DIAG — 外存诊断程序(临时用, 查明磁盘镜像在游戏外存中的位置与字节序)
; 使用方法: 把本文件全文贴进游戏汇编器(替换 boot), 导入 sonata_disk.bin, 运行。
; 屏幕会显示三行:
;   第 1 行: 4 个十六进制数, 依次 = pload[0] pload[1] pload[2] pload[4]
;   第 2 行: 'X' 开头, 外存 0..0xFFFF 范围内扫描到 "SNT1" 魔数的位置
;            每项 "索引:值", 最多 3 项, 最后 OK = 扫描结束
;   第 3 行: 'M' 开头, 主内存同样扫描的结果(排除外存不在 0 的可能)
; 把三行内容原样告诉我即可。
; ============================================================================
;
main:
  mov sp, 0x7000
  ; 屏幕: ASCII32 模式, 帧缓冲 12288
  mov r1, 0
  mov r2, 1
  screen r1, r2
  mov r1, 1
  mov r2, 0x3000
  screen r1, r2
  mov r1, 1
  mov r2, 0x3000
  screen r1, r2
  ; ---- 第 1 行: pload[0/1/2/4] ----
  mov r10, 0
  pload r5, [r10]
  mov r6, 0
  call hex8
  mov r10, 1
  pload r5, [r10]
  mov r6, 10
  call hex8
  mov r10, 2
  pload r5, [r10]
  mov r6, 20
  call hex8
  mov r10, 4
  pload r5, [r10]
  mov r6, 30
  call hex8
  ; ---- 第 2 行: 外存扫描(96 格后) ----
  mov r6, 96
  mov r1, 0x58           ; 'X'
  call putc
  add r6, r6, 1
  mov r10, 0
  mov r12, 0
  mov r13, 0x3154
  lsl r13, r13, 16
  mov r4, 0x4E53
  or r13, r13, r4         ; r13 = 0x31544E53 (小端)
  mov r3, 0x534E
  lsl r3, r3, 16
  mov r4, 0x5431
  or r3, r3, r4           ; r3 = 0x534E5431 (大端)
ext_loop:
  pload r11, [r10]
  cmp r11, r13
  je ext_hit
  cmp r11, r3
  je ext_hit
  jmp ext_next
ext_hit:
  cmp r12, 3
  jae ext_next
  mov r5, r10
  call hex8
  mov r1, 0x3A           ; ':'
  call putc
  add r6, r6, 1
  mov r5, r11
  call hex8
  mov r1, 0x20           ; ' '
  call putc
  add r6, r6, 1
  add r12, r12, 1
ext_next:
  cmp r10, 0xFFFF
  je ext_done
  add r10, r10, 1
  jmp ext_loop
ext_done:
  mov r1, 0x4F           ; 'O'
  call putc
  add r6, r6, 1
  mov r1, 0x4B           ; 'K'
  call putc
  ; ---- 第 3 行: 主内存扫描(192 格后) ----
  mov r6, 192
  mov r1, 0x4D           ; 'M'
  call putc
  add r6, r6, 1
  mov r10, 0
  mov r12, 0
ram_loop:
  load_32 r11, [r10]
  cmp r11, r13
  je ram_hit
  cmp r11, r3
  je ram_hit
  jmp ram_next
ram_hit:
  cmp r12, 3
  jae ram_next
  mov r5, r10
  call hex8
  mov r1, 0x3A
  call putc
  add r6, r6, 1
  mov r5, r11
  call hex8
  mov r1, 0x20
  call putc
  add r6, r6, 1
  add r12, r12, 1
ram_next:
  cmp r10, 0xFFFF
  je ram_done
  add r10, r10, 1
  jmp ram_loop
ram_done:
  mov r1, 0x4F
  call putc
  add r6, r6, 1
  mov r1, 0x4B
  call putc
halt:
  jmp halt
;
; ============================================================================
; putc: r6 = 格序号(0..), r1 = 字符; 使用 r2; 其余寄存器不动
; ============================================================================
putc:
  lsl r2, r6, 2
  add r2, r2, 0x3000
  store_8 [r2], r1
  add r2, r2, 1
  mov r1, 0xFF
  store_8 [r2], r1
  add r2, r2, 1
  mov r1, 0
  store_8 [r2], r1
  add r2, r2, 1
  store_8 [r2], r1
  ret
;
; ============================================================================
; hex8: r5 = 值, r6 = 起始格; 打印 8 位十六进制, r6 前进 8
; 使用 r1 r2 r7 r8 r9; 其余(r3 r4 r5 r10-r13)不动
; ============================================================================
hex8:
  mov r7, 28
  mov r9, 8
hex8_loop:
  mov r8, r5
  lsr r8, r8, r7
  and r8, r8, 0xF
  add r8, r8, 0x30
  cmp r8, 0x3A
  jb hex8_put
  add r8, r8, 7
hex8_put:
  mov r1, r8
  call putc
  add r6, r6, 1
  sub r7, r7, 4
  sub r9, r9, 1
  cmp r9, 0
  je hex8_done
  jmp hex8_loop
hex8_done:
  ret

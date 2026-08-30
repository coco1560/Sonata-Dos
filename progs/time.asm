; ==================================================
; 程序: time(Sonata DOS 磁盘程序)
; @name: time
; @data: 50
; 入口 main(转换器改名为 time_main); 结束 jmp shell_resume
; ==================================================

; 数据区(D_* 偏移, 转换器加 DATA_BASE)
const D_time_S_TICKPRE = 0x0
const D_time_S_TIMEBAD = 0x10

main:
  call time_init
  jmp do_time

do_time:
  load_32 r8, [ARGC]
  cmp r8, 2
  jae do_time_bad
  mov r1, D_time_S_TICKPRE
  call print_str
  time_0 r1
  call print_hex
  call print_nl
  jmp shell_resume

do_time_bad:
  mov r1, D_time_S_TIMEBAD
  jmp perr


; ---------------- 数据初始化 ----------------
time_init:
  ; ---- D_time_S_TICKPRE ----
  mov r3, D_time_S_TICKPRE
  ; ---- D_time_S_TIMEBAD ----
  mov r2, 0x5379
  lsl r2, r2, 16
  mov r11, 0x7374
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x656D
  lsl r2, r2, 16
  mov r11, 0x2074
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6963
  lsl r2, r2, 16
  mov r11, 0x6B73
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x3A20
  lsl r2, r2, 16
  store_32 [r3], r2
  add r3, r3, 4
  mov r3, D_time_S_TIMEBAD
  mov r2, 0x4361
  lsl r2, r2, 16
  mov r11, 0x6E6E
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6F74
  lsl r2, r2, 16
  mov r11, 0x2073
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6574
  lsl r2, r2, 16
  mov r11, 0x2074
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x696D
  lsl r2, r2, 16
  mov r11, 0x6520
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6F6E
  lsl r2, r2, 16
  mov r11, 0x2074
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6869
  lsl r2, r2, 16
  mov r11, 0x7320
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6861
  lsl r2, r2, 16
  mov r11, 0x7264
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x7761
  lsl r2, r2, 16
  mov r11, 0x7265
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x002E
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ret


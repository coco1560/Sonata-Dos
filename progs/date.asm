; ==================================================
; 程序: date(Sonata DOS 磁盘程序)
; @name: date
; @data: 60
; 入口 main(转换器改名为 date_main); 结束 jmp shell_resume
; ==================================================

; 数据区(D_* 偏移, 转换器加 DATA_BASE)
const D_date_S_DATEPRE = 0x0
const D_date_S_DATEBAD = 0x10
const D_date_S_DATESET = 0x32

main:
  call date_init
  jmp do_date

do_date:
  load_32 r8, [ARGC]
  cmp r8, 2
  jae do_date_set
  mov r1, D_date_S_DATEPRE
  call print_str
  mov r8, DATEVAR
  mov r9, 8

do_date_show:
  load_8 r1, [r8]
  call print_char
  add r8, r8, 1
  sub r9, r9, 1
  cmp r9, 0
  je do_date_nl
  cmp r9, 4
  je do_date_hyphen
  cmp r9, 2
  je jneskip27
  jmp do_date_show
jneskip27:

do_date_hyphen:
  mov r1, CH_MINUS
  call print_char
  jmp do_date_show

do_date_nl:
  call print_nl
  jmp shell_resume

do_date_set:
  load_32 r1, [ARGV1]
  mov r8, r1
  mov r9, 8

do_date_val:
  load_8 r2, [r8]
  cmp r2, CH_0
  jb do_date_bad
  cmp r2, CH_9
  jbe jaskip67
  jmp do_date_bad
jaskip67:
  add r8, r8, 1
  sub r9, r9, 1
  cmp r9, 0
  je jneskip28
  jmp do_date_val
jneskip28:
  load_8 r2, [r8]
  cmp r2, 0
  je jneskip29
  jmp do_date_bad
jneskip29:
  mov r8, DATEVAR
  mov r9, r1
  mov r10, 8

do_date_cp:
  load_8 r2, [r9]
  store_8 [r8], r2
  add r8, r8, 1
  add r9, r9, 1
  sub r10, r10, 1
  cmp r10, 0
  je jneskip30
  jmp do_date_cp
jneskip30:
  mov r1, D_date_S_DATESET
  call print_str
  call print_nl
  jmp shell_resume

do_date_bad:
  mov r1, D_date_S_DATEBAD
  jmp perr


; ---------------- 数据初始化 ----------------
date_init:
  ; ---- D_date_S_DATEPRE ----
  mov r3, D_date_S_DATEPRE
  ; ---- D_date_S_DATEBAD ----
  mov r2, 0x4375
  lsl r2, r2, 16
  mov r11, 0x7272
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x656E
  lsl r2, r2, 16
  mov r11, 0x7420
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6461
  lsl r2, r2, 16
  mov r11, 0x7465
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x3A20
  lsl r2, r2, 16
  store_32 [r3], r2
  add r3, r3, 4
  mov r3, D_date_S_DATEBAD
  ; ---- D_date_S_DATESET ----
  mov r2, 0x496E
  lsl r2, r2, 16
  mov r11, 0x7661
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6C69
  lsl r2, r2, 16
  mov r11, 0x6420
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6461
  lsl r2, r2, 16
  mov r11, 0x7465
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x2E20
  lsl r2, r2, 16
  mov r11, 0x5573
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6520
  lsl r2, r2, 16
  mov r11, 0x4441
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x5445
  lsl r2, r2, 16
  mov r11, 0x2059
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x5959
  lsl r2, r2, 16
  mov r11, 0x594D
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x4D44
  lsl r2, r2, 16
  mov r11, 0x442E
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r3, D_date_S_DATESET
  mov r2, 0x4461
  lsl r2, r2, 16
  mov r11, 0x7465
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x2073
  lsl r2, r2, 16
  mov r11, 0x6574
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


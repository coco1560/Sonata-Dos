; ==================================================
; 程序: set(Sonata DOS 磁盘程序)
; @name: set
; @data: 42
; 入口 main(转换器改名为 set_main); 结束 jmp shell_resume
; ==================================================

; 数据区(D_* 偏移, 转换器加 DATA_BASE)
const D_set_S_NOVAR = 0x0
const D_set_S_SETOK = 0x12
const D_set_S_ENVFULL = 0x18

main:
  call set_init
  jmp do_set

do_set:
  load_32 r8, [ARGC]
  cmp r8, 1
  je do_set_list
  load_32 r11, [ARGV1]
  mov r12, r11

do_set_scan:
  load_8 r2, [r12]
  cmp r2, 0
  je do_set_nospace
  cmp r2, CH_EQ
  je do_set_split
  add r12, r12, 1
  jmp do_set_scan

do_set_split:
  store_8 [r12], zr
  add r12, r12, 1
  mov r1, r11
  mov r2, r12
  call env_set
  cmp r4, NOTFOUND
  je do_set_full
  mov r1, D_set_S_SETOK
  call print_str
  call print_nl
  jmp shell_resume

do_set_nospace:
  cmp r8, 2
  je do_set_show
  mov r1, r11
  load_32 r2, [ARGV2]
  call env_set
  cmp r4, NOTFOUND
  je do_set_full
  mov r1, D_set_S_SETOK
  call print_str
  call print_nl
  jmp shell_resume

do_set_show:
  mov r1, r11
  call env_find
  cmp r4, NOTFOUND
  je do_set_novar
  lsl r3, r4, 4
  lsl r5, r4, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  mov r12, r3 ; 槽指针(print_char 会破坏 r3)
  mov r1, r12
  call print_str
  mov r1, CH_EQ
  call print_char
  mov r1, r12
  add r1, r1, 8
  call print_str
  call print_nl
  jmp shell_resume

do_set_list:
  mov r12, 0

do_set_list_loop:
  cmp r12, ENV_N
  jae do_set_list_done
  lsl r3, r12, 4
  lsl r5, r12, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  mov r13, r3 ; 槽指针(print_char 会破坏 r3)
  load_32 r2, [r13]
  lsr r2, r2, 24
  and r2, r2, 0xFF
  cmp r2, 0
  je do_set_list_next
  mov r1, r13
  call print_str
  mov r1, CH_EQ
  call print_char
  mov r1, r13
  add r1, r1, 8
  call print_str
  call print_nl

do_set_list_next:
  add r12, r12, 1
  jmp do_set_list_loop

do_set_list_done:
  jmp shell_resume

do_set_novar:
  mov r1, D_set_S_NOVAR
  jmp perr

do_set_full:
  mov r1, D_set_S_ENVFULL
  jmp perr


; ---------------- 数据初始化 ----------------
set_init:
  ; ---- D_set_S_NOVAR ----
  mov r3, D_set_S_NOVAR
  ; ---- D_set_S_SETOK ----
  mov r2, 0x5661
  lsl r2, r2, 16
  mov r11, 0x7269
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6162
  lsl r2, r2, 16
  mov r11, 0x6C65
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x206E
  lsl r2, r2, 16
  mov r11, 0x6F74
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
  mov r3, D_set_S_SETOK
  ; ---- D_set_S_ENVFULL ----
  mov r2, 0x5365
  lsl r2, r2, 16
  mov r11, 0x742E
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r3, D_set_S_ENVFULL
  mov r2, 0x456E
  lsl r2, r2, 16
  mov r11, 0x7669
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x726F
  lsl r2, r2, 16
  mov r11, 0x6E6D
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x656E
  lsl r2, r2, 16
  mov r11, 0x7420
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6675
  lsl r2, r2, 16
  mov r11, 0x6C6C
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


; ==================================================
; 程序: ver(Sonata DOS 磁盘程序)
; @name: ver
; @data: 16
; 入口 main(转换器改名为 ver_main); 结束 jmp shell_resume
; ==================================================

; 数据区(D_* 偏移, 转换器加 DATA_BASE)
const D_ver_S_VERSION = 0x0

main:
  call ver_init
  jmp do_ver

do_ver:
  mov r1, D_ver_S_VERSION
  call print_str
  call print_nl
  jmp shell_resume

; ---------------- 数据初始化 ----------------
ver_init:
  ; ---- D_ver_S_VERSION ----
  mov r3, D_ver_S_VERSION
  mov r2, 0x536F
  lsl r2, r2, 16
  mov r11, 0x6E61
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x7461
  lsl r2, r2, 16
  mov r11, 0x2044
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x4F53
  lsl r2, r2, 16
  mov r11, 0x2076
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x332E
  lsl r2, r2, 16
  mov r11, 0x3000
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  ret


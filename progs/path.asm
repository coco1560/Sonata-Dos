; ==================================================
; 程序: path(Sonata DOS 磁盘程序)
; @name: path
; @data: 0
; 入口 main(转换器改名为 path_main); 结束 jmp shell_resume
; ==================================================

main:
  call path_init
  jmp do_path

do_path:
  load_32 r8, [ARGC]
  cmp r8, 2
  jae do_path_set
  mov r1, S_PATHNAME
  call env_find
  cmp r4, NOTFOUND
  je do_path_blank
  lsl r3, r4, 4
  lsl r5, r4, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  add r3, r3, 8
  load_8 r2, [r3]
  cmp r2, 0
  je do_path_blank
  mov r1, r3
  call print_str
  call print_nl
  jmp shell_resume

do_path_blank:
  mov r1, S_PATHNAME
  call print_str
  mov r1, CH_EQ
  call print_char
  call print_nl
  jmp shell_resume

do_path_set:
  load_32 r2, [ARGV1]
  mov r12, r2
  mov r1, S_PATHNAME
  mov r2, r12
  call env_set
  jmp shell_resume

; ---------------- 数据初始化 ----------------
path_init:
  ret


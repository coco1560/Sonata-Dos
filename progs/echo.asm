; ==================================================
; 程序: echo(Sonata DOS 磁盘程序)
; @name: echo
; @data: 0
; 入口 main(转换器改名为 echo_main); 结束 jmp shell_resume
; ==================================================

main:
  call echo_init
  jmp do_echo

do_echo:
  mov r9, ARGV1
  mov r10, 1

do_echo_loop:
  load_32 r8, [ARGC]
  cmp r10, r8
  jae do_echo_done
  load_32 r1, [r9]
  call print_str
  mov r1, CH_SPACE
  call print_char
  add r9, r9, WORD
  add r10, r10, 1
  jmp do_echo_loop

do_echo_done:
  call print_nl
  jmp shell_resume

; ---------------- 数据初始化 ----------------
echo_init:
  ret


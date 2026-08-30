; ==================================================
; 程序: prompt(Sonata DOS 磁盘程序)
; @name: prompt
; @data: 0
; 入口 main(转换器改名为 prompt_main); 结束 jmp shell_resume
; ==================================================

main:
  call prompt_init
  jmp do_prompt

do_prompt:
  load_32 r8, [ARGC]
  cmp r8, 2
  jae do_prompt_set
  mov r1, S_PROMPTNAME
  call env_find
  cmp r4, NOTFOUND
  je jneskipP6
  lsl r3, r4, 4
  lsl r5, r4, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  add r3, r3, 8
  mov r2, 0
  store_8 [r3], r2

jneskipP6:
  jmp shell_resume

do_prompt_set:
  load_32 r2, [ARGV1]
  mov r12, r2
  mov r1, S_PROMPTNAME
  mov r2, r12
  call env_set
  jmp shell_resume

; ---------------- 数据初始化 ----------------
prompt_init:
  ret


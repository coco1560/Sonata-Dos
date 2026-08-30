; ============================================================================
; HELLO.MVT — 第三方二进制程序示例
; 由 DOS 按文件名加载执行; 结束用 jmp exit_proc 返回 DOS 命令循环
; ============================================================================
main:
  mov r1, s_msg
  call print_str
  call print_nl
  jmp exit_proc
;
s_msg:
data8 "Hello world!"

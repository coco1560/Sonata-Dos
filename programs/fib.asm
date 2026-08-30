; ============================================================================
; FIB.MVT — 打印前 10 个斐波那契数(十六进制)
; 使用 boot 的 print_hex; 寄存器状态放在 r11-r13(print 系列不破坏)
; ============================================================================
main:
  mov r11, 0
  mov r12, 1
  mov r13, 10
fib_loop:
  cmp r13, 0
  je fib_done
  mov r1, r11
  call print_hex
  call print_nl
  add r7, r11, r12
  mov r11, r12
  mov r12, r7
  sub r13, r13, 1
  jmp fib_loop
fib_done:
  jmp exit_proc

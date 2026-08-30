; ============================================================================
; EXIT.MVT — 打印停机信息后 halt
; ============================================================================
main:
  mov r1, s_msg
  call print_str
  call print_nl
  jmp boot_halt
s_msg:
data8 "System halted."

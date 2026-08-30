; ============================================================================
; KEYTEST — 键盘键码测试(独立程序, 直接贴进游戏汇编器运行, 与 DOS 无关)
; 每次按键打印: 9 位原始值(3 位十六进制) + 低 8 位键码(2 位十六进制)
; 例: 大写 A -> 1xx 41 / 小写 a -> 1xx 61(第一位=弹起标志, 后 8 位=ASCII)
; 按 CapsLock: 若屏幕出现新数值, 记下低 8 位即它的键码; 若无输出, 说明
; 游戏键盘不给 CapsLock 发事件。
; ============================================================================
const SCRBASE = 0x3000

main:
  mov sp, 0x7000
  mov r1, 0
  mov r2, 1
  screen r1, r2
  mov r1, 1
  mov r2, SCRBASE
  screen r1, r2
  mov r8, 0
keytest_loop:
  keyboard r1
  cmp r1, 0
  je keytest_loop
  mov r12, r1
  mov r1, r12
  mov r2, 3
  call print_hex_n
  mov r1, 0x20
  call print_char
  and r1, r12, 0xFF
  mov r2, 2
  call print_hex_n
  mov r1, 0x20
  call print_char
  jmp keytest_loop

; ---- 打印字符(r8 = 光标格偏移; 每格 4B: 字符/白/黑/0) ----
print_char:
  lsl r3, r8, 2
  add r3, r3, SCRBASE
  store_8 [r3], r1
  add r3, r3, 1
  mov r1, 0xFF
  store_8 [r3], r1
  add r3, r3, 1
  mov r1, 0
  store_8 [r3], r1
  add r8, r8, 1
  ret

; ---- r1 = 值, r2 = 位数(1..8) ----
print_hex_n:
  mov r10, r1
  mov r11, r2
  sub r9, r2, 1
  lsl r9, r9, 2
phn_loop:
  mov r2, r10
  lsr r2, r2, r9
  and r2, r2, 0xF
  mov r1, 0x30
  add r1, r1, r2
  cmp r1, 0x39
  jbe phn_ok
  add r1, r1, 7
phn_ok:
  call print_char
  sub r9, r9, 4
  sub r11, r11, 1
  cmp r11, 0
  je phn_done
  jmp phn_loop
phn_done:
  ret

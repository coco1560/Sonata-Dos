; ============================================================================
; XDUMP.MVT — 转储外存 16 字节(十六进制)
; 用法: XDUMP <hex 地址>   例: XDUMP 0(头部魔数 53 4E 54 31)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb xdump_usage
  cmp r8, 3
  jb xdump_default
  load_32 r1, [ARGV2]
  call parse_hex
  mov r11, r4
  cmp r11, 0x100
  jbe xdump_addr
  mov r11, 0x100
  jmp xdump_addr
xdump_default:
  mov r11, DUMP_N
xdump_addr:
  load_32 r1, [ARGV1]
  call parse_hex
  mov r12, r4
  mov r13, 16
xdump_loop:
  cmp r11, 0
  je xdump_done
  mov r1, r12
  and r2, r1, 3
  sub r1, r1, r2
  pload r3, [r1]
  mov r10, 3
  sub r10, r10, r2
  lsl r10, r10, 3
  lsr r3, r3, r10
  mov r1, r3
  mov r2, 2
  call print_hex_n
  mov r1, CH_SPACE
  call print_char
  add r12, r12, 1
  sub r11, r11, 1
  sub r13, r13, 1
  cmp r13, 0
  je xdump_nl
  cmp r11, 0
  je xdump_done
  jmp xdump_loop
xdump_nl:
  cmp r11, 0
  je xdump_done
  call print_nl
  mov r13, 16
  jmp xdump_loop
xdump_done:
  call print_nl
  jmp exit_proc
xdump_usage:
  mov r1, S_SYNTAX
  call perr
  jmp exit_proc

; r1 = 字符串 -> r4 = 值
parse_hex:
  mov r8, r1
  mov r4, 0
parse_hex_loop:
  load_8 r2, [r8]
  cmp r2, 0
  je parse_hex_done
  cmp r2, CH_0
  jb parse_hex_done
  cmp r2, CH_9
  jbe parse_hex_num
  cmp r2, CH_FA
  jb parse_hex_done
  cmp r2, CH_FF
  jbe parse_hex_up
  cmp r2, CH_A
  jb parse_hex_done
  cmp r2, CH_Z
  ja parse_hex_done
  sub r2, r2, 0x57
  jmp parse_hex_add
parse_hex_up:
  sub r2, r2, CH_HEXOFF
  jmp parse_hex_add
parse_hex_num:
  sub r2, r2, CH_0
parse_hex_add:
  lsl r4, r4, 4
  or r4, r4, r2
  add r8, r8, 1
  jmp parse_hex_loop
parse_hex_done:
  ret


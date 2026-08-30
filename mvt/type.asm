; ============================================================================
; TYPE.MVT — 打印数据文件内容(读外存代码区; 换行按字符输出)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb type_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je type_nf
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_FILE
  je type_text
  cmp r2, T_MVT
  je type_hex
  cmp r2, T_SCO
  je type_hex
  mov r1, S_NOTFILE
  jmp type_err
type_text:
  add r7, r7, WORD
  pload r11, [r7]
  add r7, r7, 8
  pload r12, [r7]
type_loop:
  cmp r11, 0
  je type_done
  mov r1, r12
  and r2, r1, 3
  sub r1, r1, r2
  pload r3, [r1]
  mov r10, 3
  sub r10, r10, r2
  lsl r10, r10, 3
  lsr r3, r3, r10
  mov r1, r3
  cmp r1, CHAR_NL
  jne type_pc
  call print_nl
  jmp type_cont
type_pc:
  call print_char
type_cont:
  add r12, r12, 1
  sub r11, r11, 1
  jmp type_loop
type_hex:
  add r7, r7, WORD
  pload r11, [r7]
  add r7, r7, 8
  pload r12, [r7]
  mov r13, 16
type_hex_loop:
  cmp r11, 0
  je type_done
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
  je type_hex_nl
  jmp type_hex_loop
type_hex_nl:
  cmp r11, 0
  je type_done
  call print_nl
  mov r13, 16
  jmp type_hex_loop
type_done:
  call print_nl
  jmp exit_proc
type_nf:
  mov r1, S_NF
type_err:
  call perr
  jmp exit_proc
type_usage:
  mov r1, S_SYNTAX
  jmp type_err

; ============================================================================
; WRITE.MVT — 交互式编辑数据文件(内容写入外存代码区, 重启后仍在)
; 用法: WRITE <name>  -> 键入文本, Enter 换行, Backspace 退格, Esc 保存
; 名字已存在时: 数据文件覆盖, 其它类型报错
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb write_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je write_new
  mov r13, r4
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_FILE
  je write_have
  mov r1, S_EXIST
  jmp write_err
write_have:
  add r7, r7, 12
  pload r10, [r7]
  jmp write_ed
write_new:
  call free_entry
  cmp r4, NOTFOUND
  je write_full
  mov r13, r4
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  load_32 r1, [ARGV1]
  call entry_set_name
  add r7, r7, FS_TYPEOF
  mov r2, T_FILE
  pstore [r7], r2
  add r7, r7, WORD
  mov r2, 0
  pstore [r7], r2
  add r7, r7, WORD
  pstore [r7], r2
  add r7, r7, WORD
  pstore [r7], r2
  add r7, r7, WORD
  pstore [r7], r2
  add r7, r7, WORD
  pstore [r7], r2
  add r7, r7, WORD
  load_32 r2, [CURDIR]
  pstore [r7], r2
  store_32 [DIRTMP], r13
  mov r1, 256
  call disk_alloc
  cmp r4, NOTFOUND
  je write_full
  mov r10, r4
  load_32 r13, [DIRTMP]
  lsl r7, r13, 5
  lsl r3, r13, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  add r7, r7, 12
  pstore [r7], r10
  add r2, r13, 1
  pload r1, [DISK_COUNTOF]
  cmp r2, r1
  jbe write_ed
  pstore [DISK_COUNTOF], r2
write_ed:
  mov r11, 0
write_key:
  call key_poll
  call key_translate
  cmp r4, 0
  je write_key
  cmp r4, CH_ESC
  je write_commit
  cmp r4, CH_CAPS
  je write_tab
  cmp r4, CH_BS
  je write_bs
  cmp r4, CH_ENTER
  je write_enter
  cmp r4, CH_ENTER2
  je write_enter
  cmp r4, CH_SPACE
  jb write_key
  cmp r4, CH_TILDE
  ja write_key
  cmp r11, FILE_MAX
  jae write_key
  call case_fix
  call wbyte
  add r10, r10, 1
  add r11, r11, 1
  mov r1, r4
  call print_char
  jmp write_key
write_tab:
  load_32 r2, [CASEFLAG]
  xor r2, r2, 1
  store_32 [CASEFLAG], r2
  jmp write_key
write_enter:
  cmp r11, FILE_MAX
  jae write_key
  mov r4, CHAR_NL
  call wbyte
  add r10, r10, 1
  add r11, r11, 1
  call print_nl
  jmp write_key
write_bs:
  cmp r11, 0
  je write_key
  sub r10, r10, 1
  sub r11, r11, 1
  mov r1, CH_BS
  call print_char
  jmp write_key
write_commit:
  lsl r7, r13, 5
  lsl r3, r13, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  add r7, r7, WORD
  pstore [r7], r11
  mov r1, S_SAVED
  call print_str
  call print_nl
  jmp exit_proc
write_usage:
  mov r1, S_SYNTAX
  jmp write_err
write_full:
  mov r1, S_FULL
write_err:
  call perr
  jmp exit_proc

; r4 = 字节, r10 = 外存地址; 读改写大端字写一个字节(保留 r4/r9-r13)
wbyte:
  mov r2, r10
  mov r1, r2
  and r3, r1, 3
  sub r1, r1, r3
  pload r5, [r1]
  mov r7, 3
  sub r7, r7, r3
  lsl r7, r7, 3
  lsl r6, r4, r7
  mov r8, 0xFF
  lsl r8, r8, r7
  not r8, r8
  and r5, r5, r8
  or r5, r5, r6
  pstore [r1], r5
  ret

; ============================================================================
; MKMVT.MVT — 运行时新建可执行文件(机器码十六进制录入, 存外存后可直接运行)
; 用法: MKMVT <name> -> 键入机器码十六进制字节(空格分隔), Esc 保存
; 运行: 直接输入 <name> 执行(MVT 加载到固定地址 0xFD00, 无重定位:
;       call/ret 与 boot 导出调用天然位置无关; 程序内部跳转请按 0xFD00 手算)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb mkexe_usage
  ; 构建最终名字: 原名(<=8 字符)若未以 .MVT 结尾则自动追加
  load_32 r1, [ARGV1]
  mov r11, r1
  mov r1, WRITEBUF
  mov r2, r11
  mov r3, 8
  call strcpy_n
  mov r1, WRITEBUF
  call upper
  mov r8, WRITEBUF
mkexe_scan:
  load_8 r2, [r8]
  cmp r2, 0
  je mkexe_end
  add r8, r8, 1
  jmp mkexe_scan
mkexe_end:
  sub r9, r8, 4
  cmp r9, WRITEBUF
  jb mkexe_app
  load_8 r2, [r9]
  cmp r2, CH_DOT
  jne mkexe_app
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x4D
  jne mkexe_app
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x56
  jne mkexe_app
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x54
  jne mkexe_app
  jmp mkexe_got
mkexe_app:
  mov r2, CH_DOT
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x4D
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x56
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x54
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0
  store_8 [r8], r2
mkexe_got:
  mov r1, WRITEBUF
  call find_in_dir
  cmp r4, NOTFOUND
  je mkexe_new
  mov r1, S_EXIST
  jmp mkexe_err
mkexe_new:
  call free_entry
  cmp r4, NOTFOUND
  je mkexe_full
  mov r13, r4
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r1, WRITEBUF
  call entry_set_name
  add r7, r7, FS_TYPEOF
  mov r2, T_MVT
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
  je mkexe_full
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
  jbe mkexe_ed
  pstore [DISK_COUNTOF], r2
mkexe_ed:
  mov r1, s_note
  call print_str
  call print_nl
  mov r11, 0
  mov r12, 0
mkexe_key:
  call key_poll
  mov r8, r4               ; 保存原始键码
  call key_translate
  cmp r4, 0
  je mkexe_key
  cmp r4, CH_ESC
  je mkexe_commit
  cmp r8, 14               ; 原始 Esc(游戏实测键码)双保险
  je mkexe_commit
  cmp r8, 0x1B             ; 原始 Esc(27)双保险
  je mkexe_commit
  cmp r4, CH_CAPS
  je mkexe_tab
  cmp r4, CH_SPACE
  je mkexe_key
  cmp r4, CH_ENTER
  je mkexe_key
  cmp r4, CH_ENTER2
  je mkexe_key
  cmp r4, CH_0
  jb mkexe_key
  cmp r4, CH_9
  jbe mkexe_digit
  cmp r4, CH_FA
  jb mkexe_tryl
  cmp r4, CH_FF
  jbe mkexe_upper
mkexe_tryl:
  cmp r4, CH_A
  jb mkexe_key
  cmp r4, CH_Z
  ja mkexe_key
  sub r4, r4, 0x57
  jmp mkexe_nib
mkexe_upper:
  sub r4, r4, CH_HEXOFF
  jmp mkexe_nib
mkexe_digit:
  sub r4, r4, CH_0
mkexe_nib:
  mov r1, r4
  add r1, r1, CH_0
  cmp r1, CH_9
  jbe mkexe_echo
  add r1, r1, 7
mkexe_echo:
  call print_char
  cmp r12, 0
  jne mkexe_low
  mov r9, r4
  mov r12, 1
  jmp mkexe_key
mkexe_low:
  cmp r11, FILE_MAX
  jae mkexe_key
  lsl r9, r9, 4
  or r4, r4, r9
  call wbyte
  add r10, r10, 1
  add r11, r11, 1
  mov r12, 0
  jmp mkexe_key
mkexe_tab:
  load_32 r2, [CASEFLAG]
  xor r2, r2, 1
  store_32 [CASEFLAG], r2
  jmp mkexe_key
mkexe_commit:
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
mkexe_usage:
  mov r1, S_SYNTAX
  jmp mkexe_err
mkexe_full:
  mov r1, S_FULL
mkexe_err:
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
;
s_note:
data8 "Saved as NAME.MVT. Hex (e.g. 31 01 00 4F), Esc=save. Loads at 0xFD00."

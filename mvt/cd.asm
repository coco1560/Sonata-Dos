; ============================================================================
; CD.MVT — 切换目录(目录树存于外存磁盘表)
; CD           显示当前目录(根 = \)
; CD \         回根
; CD ..        上级目录
; CD name      进入子目录
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb cd_show
  load_32 r1, [ARGV1]
  load_8 r2, [r1]
  cmp r2, CH_BSLASH
  jne cd_not_root
  add r3, r1, 1
  load_8 r2, [r3]
  cmp r2, 0
  jne cd_not_root
  mov r2, 0
  store_32 [CURDIR], r2
  jmp exit_proc
cd_not_root:
  load_32 r1, [ARGV1]
  load_8 r2, [r1]
  cmp r2, CH_DOT
  jne cd_name
  add r3, r1, 1
  load_8 r2, [r3]
  cmp r2, CH_DOT
  jne cd_name
  add r3, r3, 1
  load_8 r2, [r3]
  cmp r2, 0
  jne cd_name
  load_32 r2, [CURDIR]
  lsl r7, r2, 5
  lsl r3, r2, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_PAROF
  pload r2, [r7]
  store_32 [CURDIR], r2
  jmp exit_proc
cd_name:
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je cd_nf
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_DIR
  je cd_ok
  cmp r2, T_SCODIR
  je cd_ok
  mov r1, S_NOTDIR
  jmp cd_err
cd_ok:
  store_32 [CURDIR], r4
  jmp exit_proc
cd_nf:
  mov r1, S_PATHNF
cd_err:
  call perr
  jmp exit_proc
cd_show:
  load_32 r2, [CURDIR]
  cmp r2, 0
  jne cd_show_name
  mov r1, CH_BSLASH
  call print_char
  call print_nl
  jmp exit_proc
cd_show_name:
  lsl r7, r2, 5
  lsl r3, r2, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
cd_show_cp:
  pload r1, [r7]
  store_32 [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je cd_show_p
  jmp cd_show_cp
cd_show_p:
  store_8 [r8], zr
  mov r1, NAMETMP
  call print_str
  call print_nl
  jmp exit_proc

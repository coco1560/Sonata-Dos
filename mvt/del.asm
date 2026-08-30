; ============================================================================
; DEL.MVT — 删除文件(DATA/MVT; 目录请用 RD; 外存磁盘表即时生效)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb del_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je del_nf
  mov r12, r4
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_DIR
  je del_notfile
  cmp r2, T_SCODIR
  je del_notfile
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r9, FS_ENTRY_WORDS
  mov r2, 0
del_zero:
  pstore [r7], r2
  add r7, r7, WORD
  sub r9, r9, 1
  cmp r9, 0
  je del_ok
  jmp del_zero
del_ok:
  mov r1, S_DELOK
  call print_str
  call print_nl
  jmp exit_proc
del_notfile:
  mov r1, S_NOTFILE
  jmp del_err
del_nf:
  mov r1, S_NF
del_err:
  call perr
  jmp exit_proc
del_usage:
  mov r1, S_SYNTAX
  jmp del_err

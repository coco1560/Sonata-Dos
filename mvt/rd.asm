; ============================================================================
; RD.MVT — 删除目录(空目录才可删; 目录树存于外存磁盘表)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb rd_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je rd_nf
  mov r12, r4
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_DIR
  je rd_isdir
  cmp r2, T_SCODIR
  je rd_isdir
  mov r1, S_NOTDIR
  jmp rd_err
rd_isdir:
  mov r1, r12
  call dir_has_child
  cmp r4, 0
  je rd_do
  mov r1, s_notempty
  jmp rd_err
rd_do:
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r9, FS_ENTRY_WORDS
  mov r2, 0
rd_zero:
  pstore [r7], r2
  add r7, r7, WORD
  sub r9, r9, 1
  cmp r9, 0
  je rd_ok
  jmp rd_zero
rd_ok:
  mov r1, s_ok
  call print_str
  call print_nl
  jmp exit_proc
rd_nf:
  mov r1, S_PATHNF
rd_err:
  call perr
  jmp exit_proc
rd_usage:
  mov r1, S_SYNTAX
  jmp rd_err
;
s_notempty:
data8 "Directory not empty."
s_ok:
data8 "Directory removed."

; ============================================================================
; MD.MVT — 在磁盘表新建目录项(类型 DIR, 存于外存)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb md_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je md_new
  mov r1, S_EXIST
  jmp md_err
md_new:
  call free_entry
  cmp r4, NOTFOUND
  je md_full
  mov r12, r4
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  load_32 r1, [ARGV1]
  call entry_set_name
  add r7, r7, FS_TYPEOF
  mov r2, T_DIR
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
  add r2, r12, 1
  pload r1, [DISK_COUNTOF]
  cmp r2, r1
  jbe md_done
  pstore [DISK_COUNTOF], r2
md_done:
  mov r1, s_ok
  call print_str
  call print_nl
  jmp exit_proc
md_usage:
  mov r1, S_SYNTAX
  jmp md_err
md_full:
  mov r1, S_FULL
md_err:
  call perr
  jmp exit_proc
;
s_ok:
data8 "Directory created."

; ============================================================================
; CREATE.MVT — 新建空数据文件(磁盘表项 + 0 字节)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb create_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je create_new
  mov r1, S_EXIST
  jmp create_err
create_new:
  call free_entry
  cmp r4, NOTFOUND
  je create_full
  mov r12, r4
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
  add r2, r12, 1
  pload r1, [DISK_COUNTOF]
  cmp r2, r1
  jbe create_done
  pstore [DISK_COUNTOF], r2
create_done:
  mov r1, S_CREATED
  call print_str
  call print_nl
  jmp exit_proc
create_usage:
  mov r1, S_SYNTAX
  jmp create_err
create_full:
  mov r1, S_FULL
create_err:
  call perr
  jmp exit_proc

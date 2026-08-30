; ============================================================================
; COPY.MVT — 复制 DATA/MVT 文件到新名字(字节级复制, 存于外存)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 3
  jb copy_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je copy_srcnf
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r13, [r7]
  add r7, r7, WORD
  pload r6, [r7]
  store_32 [DIRTMP], r6
  add r7, r7, 8
  pload r10, [r7]
  cmp r13, T_FILE
  je copy_okt
  cmp r13, T_MVT
  je copy_okt
  mov r1, s_nocopy
  jmp copy_err
copy_okt:
  load_32 r1, [ARGV2]
  call find_in_dir
  cmp r4, NOTFOUND
  je copy_new
  mov r1, S_EXIST
  jmp copy_err
copy_new:
  call free_entry
  cmp r4, NOTFOUND
  je copy_full
  mov r12, r4
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  load_32 r1, [ARGV2]
  call entry_set_name
  add r7, r7, FS_TYPEOF
  pstore [r7], r13
  add r7, r7, WORD
  load_32 r2, [DIRTMP]
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
  load_32 r2, [CURDIR]
  pstore [r7], r2
  ; 分配目标空间(disk_alloc 破坏 r11-r13, 先存 idx)
  store_32 [DIRLINES], r12
  mov r1, r6
  call disk_alloc
  cmp r4, NOTFOUND
  je copy_full
  mov r13, r4
  load_32 r12, [DIRLINES]
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  add r7, r7, 12
  pstore [r7], r13
  add r2, r12, 1
  pload r1, [DISK_COUNTOF]
  cmp r2, r1
  jbe copy_cp
  pstore [DISK_COUNTOF], r2
copy_cp:
  load_32 r9, [DIRTMP]
  add r9, r9, 3
  lsr r9, r9, 2
  mov r7, r10
  mov r8, r13
copy_loop:
  cmp r9, 0
  je copy_done
  pload r1, [r7]
  pstore [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  jmp copy_loop
copy_done:
  mov r1, s_ok
  call print_str
  call print_nl
  jmp exit_proc
copy_srcnf:
  mov r1, S_NF
  jmp copy_err
copy_full:
  mov r1, S_FULL
copy_err:
  call perr
  jmp exit_proc
copy_usage:
  mov r1, S_SYNTAX
  jmp copy_err
;
s_nocopy:
data8 "Cannot copy."
s_ok:
data8 "Copied."

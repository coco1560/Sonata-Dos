; ============================================================================
; FORMAT.MVT — 清空用户文件/目录(保留 SCO 内置程序), 复位外存空闲指针
; ============================================================================
main:
  mov r13, 0
  mov r12, 0
format_loop:
  cmp r13, FS_N
  jae format_done
  lsl r7, r13, 5
  lsl r3, r13, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  pload r3, [r7]
  cmp r3, 0
  je format_next
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_SCO
  je format_sys
  cmp r2, T_SCODIR
  je format_sys
  lsl r7, r13, 5
  lsl r3, r13, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r9, FS_ENTRY_WORDS
  mov r2, 0
format_zero:
  pstore [r7], r2
  add r7, r7, WORD
  sub r9, r9, 1
  cmp r9, 0
  je format_next
  jmp format_zero
format_sys:
  add r12, r12, 1
format_next:
  add r13, r13, 1
  jmp format_loop
format_done:
  pstore [DISK_COUNTOF], r12
  pload r2, [DISK_BASEOFF]
  pstore [DISK_FREEOFF], r2
  mov r2, 0
  store_32 [CURDIR], r2
  mov r1, s_home
  call find_in_dir
  cmp r4, NOTFOUND
  je format_ok
  store_32 [CURDIR], r4
format_ok:
  mov r1, s_ok
  call print_str
  call print_nl
  jmp exit_proc
;
s_ok:
data8 "Disk formatted."
s_home:
data8 "HOME"

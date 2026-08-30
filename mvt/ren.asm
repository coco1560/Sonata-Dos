; ============================================================================
; REN.MVT — 重命名(改名后立即生效, 存于外存磁盘表)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 3
  jb ren_usage
  load_32 r1, [ARGV1]
  call find_in_dir
  cmp r4, NOTFOUND
  je ren_nf
  mov r13, r4
  load_32 r1, [ARGV2]
  call find_in_dir
  cmp r4, NOTFOUND
  je ren_do
  mov r1, S_EXIST
  jmp ren_err
ren_do:
  lsl r7, r13, 5
  lsl r3, r13, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  load_32 r1, [ARGV2]
  call entry_set_name
  mov r1, s_ok
  call print_str
  call print_nl
  jmp exit_proc
ren_nf:
  mov r1, S_NF
ren_err:
  call perr
  jmp exit_proc
ren_usage:
  mov r1, S_SYNTAX
  jmp ren_err
;
s_ok:
data8 "Renamed."

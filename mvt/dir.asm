; ============================================================================
; DIR.MVT — 列出当前目录磁盘表项(名字 + 大小 + 类型标签, 每 20 行分页)
; 标签: <DIR> 目录 / MVT 运行时程序 / SCO 内置程序
; ============================================================================
main:
  mov r2, 0
  store_32 [DIRLINES], r2
  mov r11, 0
  mov r12, 0
dir_loop:
  cmp r12, FS_N
  jae dir_end
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  pload r3, [r7]
  cmp r3, 0
  je dir_next
  add r7, r7, FS_PAROF
  pload r1, [r7]
  load_32 r2, [CURDIR]
  cmp r1, r2
  je dir_show
  jmp dir_next
dir_show:
  add r11, r11, 1
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
dir_cp:
  pload r1, [r7]
  store_32 [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je dir_cpd
  jmp dir_cp
dir_cpd:
  store_8 [r8], zr
  mov r1, NAMETMP
  call print_str
  ; 大小(4 位十六进制)——print_* 破坏 r1-r10, 类型/大小先存 DIRTMP/DIRTMP4
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  store_32 [DIRTMP], r2
  add r7, r7, WORD
  pload r2, [r7]
  store_32 [DIRTMP4], r2
  mov r1, CH_SPACE
  call print_char
  load_32 r1, [DIRTMP4]
  mov r2, 4
  call print_hex_n
  mov r1, CH_SPACE
  call print_char
  load_32 r10, [DIRTMP]
  cmp r10, T_DIR
  je dir_tagdir
  cmp r10, T_SCODIR
  jne dir_notdir
dir_tagdir:
  mov r1, s_dirtag
  call print_str
  jmp dir_line
dir_notdir:
  cmp r10, T_MVT
  jne dir_notexe
  mov r1, s_exetag
  call print_str
  jmp dir_line
dir_notexe:
  cmp r10, T_SCO
  jne dir_line
  mov r1, s_systag
  call print_str
dir_line:
  call print_nl
  load_32 r2, [DIRLINES]
  add r2, r2, 1
  store_32 [DIRLINES], r2
  cmp r2, 20
  jne dir_next
  mov r2, 0
  store_32 [DIRLINES], r2
  mov r1, s_press
  call print_str
  call key_poll
  call print_nl
dir_next:
  add r12, r12, 1
  jmp dir_loop
dir_end:
  cmp r11, 0
  jne dir_ret
  mov r1, s_none
  call print_str
  call print_nl
dir_ret:
  jmp exit_proc
;
s_dirtag:
data8 "<DIR>"
s_exetag:
data8 "MVT"
s_systag:
data8 "SCO"
s_press:
data8 "Press any key to continue..."
s_none:
data8 "No files."

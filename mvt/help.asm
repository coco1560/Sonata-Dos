; ============================================================================
; HELP.MVT — 完整版帮助(静态命令表, 25 条)
; ============================================================================
main:
  load_32 r8, [ARGC]
  cmp r8, 2
  jae do_help_one
  mov r1, s_intro
  call print_str
  call print_nl
  mov r12, help_tab
  mov r13, 25
do_help_all:
  load_32 r1, [r12]
  call print_pad10
  add r12, r12, WORD
  load_32 r1, [r12]
  call print_str
  call print_nl
  add r12, r12, WORD
  sub r13, r13, 1
  cmp r13, 0
  je do_help_done
  jmp do_help_all
do_help_done:
  jmp exit_proc
do_help_one:
  load_32 r1, [ARGV1]
  call upper
  mov r11, r1
  mov r12, help_tab
  mov r13, 25
do_help_loop:
  mov r1, r11
  load_32 r2, [r12]
  call strcmp
  cmp r4, 1
  je do_help_found
  add r12, r12, 8
  sub r13, r13, 1
  cmp r13, 0
  je do_help_nf
  jmp do_help_loop
do_help_nf:
  mov r1, s_nf
  call print_str
  mov r1, r11
  call print_str
  call print_nl
  jmp exit_proc
do_help_found:
  add r12, r12, WORD
  load_32 r1, [r12]
  call print_str
  call print_nl
  jmp exit_proc

; r1 = 字符串; 打印并补空格到 10 列
print_pad10:
  mov r10, r1
  call strlen
  mov r9, 10
  sub r9, r9, r4
  mov r1, r10
  call print_str
  mov r1, r9
  call print_spaces
  ret
;
s_intro:
data8 "Commands (type HELP <name> for details):"
s_nf:
data8 "No help for "
s_cd:
data8 "CD"
s_cls:
data8 "CLS"
s_copy:
data8 "COPY"
s_create:
data8 "CREATE"
s_date:
data8 "DATE"
s_del:
data8 "DEL"
s_dir:
data8 "DIR"
s_dump:
data8 "DUMP"
s_echo:
data8 "ECHO"
s_format:
data8 "FORMAT"
s_md:
data8 "MD"
s_mkexe:
data8 "MKMVT"
s_path:
data8 "PATH"
s_prompt:
data8 "PROMPT"
s_rd:
data8 "RD"
s_ren:
data8 "REN"
s_set:
data8 "SET"
s_time:
data8 "TIME"
s_type:
data8 "TYPE"
s_ver:
data8 "VER"
s_write:
data8 "WRITE"
s_xdump:
data8 "XDUMP"
s_help:
data8 "HELP"
s_reboot:
data8 "REBOOT"
s_exit:
data8 "EXIT"
d_cd:
data8 "Change directory (\\ .. name)"
d_cls:
data8 "Clear screen"
d_copy:
data8 "Copy file <src> <dst>"
d_create:
data8 "Create empty data file"
d_date:
data8 "Show or set date"
d_del:
data8 "Delete file"
d_dir:
data8 "List files in directory"
d_dump:
data8 "Hex dump main memory <addr> [len]"
d_echo:
data8 "Print arguments"
d_format:
data8 "Reset user files on disk"
d_md:
data8 "Make directory"
d_mkexe:
data8 "Create .MVT program from hex"
d_path:
data8 "Show or set PATH"
d_prompt:
data8 "Show or set prompt"
d_rd:
data8 "Remove empty directory"
d_ren:
data8 "Rename file"
d_set:
data8 "Show or set environment"
d_time:
data8 "Show system ticks"
d_type:
data8 "Print file (text/hex)"
d_ver:
data8 "Show version"
d_write:
data8 "Edit text file (Esc=save)"
d_xdump:
data8 "Hex dump ext memory <addr> [len]"
d_help:
data8 "Show this help"
d_reboot:
data8 "Restart DOS"
d_exit:
data8 "Halt the machine"
help_tab:
data32 s_cd
data32 d_cd
data32 s_cls
data32 d_cls
data32 s_copy
data32 d_copy
data32 s_create
data32 d_create
data32 s_date
data32 d_date
data32 s_del
data32 d_del
data32 s_dir
data32 d_dir
data32 s_dump
data32 d_dump
data32 s_echo
data32 d_echo
data32 s_format
data32 d_format
data32 s_md
data32 d_md
data32 s_mkexe
data32 d_mkexe
data32 s_path
data32 d_path
data32 s_prompt
data32 d_prompt
data32 s_rd
data32 d_rd
data32 s_ren
data32 d_ren
data32 s_set
data32 d_set
data32 s_time
data32 d_time
data32 s_type
data32 d_type
data32 s_ver
data32 d_ver
data32 s_write
data32 d_write
data32 s_xdump
data32 d_xdump
data32 s_help
data32 d_help
data32 s_reboot
data32 d_reboot
data32 s_exit
data32 d_exit

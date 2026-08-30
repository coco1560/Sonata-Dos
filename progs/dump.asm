; ==================================================
; 程序: dump(Sonata DOS 磁盘程序)
; @name: dump
; @data: 0
; 入口 main(转换器改名为 dump_main); 结束 jmp shell_resume
; ==================================================

main:
  call dump_init
  jmp do_dump

do_dump:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb do_dump_usage
  cmp r8, 3
  jb do_dump_default
  load_32 r1, [ARGV2]
  call parse_hex
  mov r11, r4
  cmp r11, 0x100
  jbe do_dump_addr
  mov r11, 0x100
  jmp do_dump_addr
do_dump_default:
  mov r11, DUMP_N
do_dump_addr:
  load_32 r1, [ARGV1]
  call parse_hex
  mov r12, r4
  mov r13, 16
do_dump_loop:
  cmp r11, 0
  je jneskip61
  load_8 r1, [r12]
  mov r2, 2
  call print_hex_n
  mov r1, CH_SPACE
  call print_char
  add r12, r12, 1
  sub r11, r11, 1
  sub r13, r13, 1
  cmp r13, 0
  je do_dump_nl
  jmp do_dump_loop
do_dump_nl:
  cmp r11, 0
  je jneskip61
  call print_nl
  mov r13, 16
  jmp do_dump_loop
jneskip61:
  call print_nl
  jmp shell_resume

do_dump_usage:
  mov r1, S_SYNTAX
  jmp perr


parse_hex:
  mov r8, r1
  mov r4, 0

parse_hex_loop:
  load_8 r2, [r8]
  cmp r2, 0
  je parse_hex_done
  cmp r2, CH_0
  jb parse_hex_done
  cmp r2, CH_9
  jbe parse_hex_num
  cmp r2, CH_FA
  jb parse_hex_done
  cmp r2, CH_FF
  jbe jaskip69
  jmp parse_hex_done
jaskip69:
  sub r2, r2, CH_HEXOFF
  jmp parse_hex_add

parse_hex_num:
  sub r2, r2, CH_0

parse_hex_add:
  lsl r4, r4, 4
  or r4, r4, r2
  add r8, r8, 1
  jmp parse_hex_loop

parse_hex_done:
  ret


; ---------------------------------------------------------------- 命令分派
; r1 = argv[0](已转大写); 查命令表, 命中则跳入处理器

; ---------------- 数据初始化 ----------------
dump_init:
  ret


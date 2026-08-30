; SONATA DOS MINI(诊断版, 极小)
const CROW = 0x2800   ;
const CCOL = 0x2804   ;
const ARGC = 0x2808   ;
const LINEBUF = 0x2810   ;
const ARGV = 0x2890   ;
const ARGV1 = 0x2894   ;
const NAMETMP = 0x28B0   ;
const DIRTMP = 0x28C0   ;
const WRITEBUF = 0x28D0   ;
const KEYMAP = 0x2C00   ;
const SCRBASE = 0x3000   ;
const STACKTOP = 0x8000   ;
const SCR_W = 96   ;
const SCR_H = 40   ;
const SCR_SIZE = 3840   ;
const SCR_SCROLL = 3744   ;
const SCR_LAST = 39   ;
const SCR_LASTCOL = 95   ;
const CLR_WHITE = 0xFF   ;
const CLR_GREEN = 0x1C   ;
const CLR_RED = 0xE0   ;
const KEY_DOWN = 0x0100   ;
const KEY_MASK = 0x00FF   ;
const RAW_ESC = 1   ; Esc 键原始码(实测非27)
const RAW_BS = 13   ; 退格键原始码(实测 CR)
const RAW_ENTER = 10   ; 回车键原始码(实测 LF)
const RAW_SPACE = 8   ;
const RAW_DOT = 50   ;
const RAW_SLASH = 51   ;
const CH_ENTER = 0x0D   ;
const CH_ESC = 0x1B   ;
const CH_BS = 0x08   ;
const CH_SPACE = 0x20   ;
const CH_TILDE = 0x7E   ;
const CH_HASH = 0x23   ;
const CHAR_NL = 0x0A   ;
const CH_0 = 0x30   ;
const CH_9 = 0x39   ;
const CH_A = 0x61   ;
const CH_Z = 0x7A   ;
const CH_FA = 0x41   ;
const CH_FF = 0x46   ;
const CH_HEXOFF = 0x37   ;
const CH_CASE = 0x20   ;
const HEX_NIB = 0xF   ;
const LINE_MAX = 0x7F   ;
const NAME_MAX = 15   ;
const FILE_MAX = 0xFF   ;
const TOKEN_MAX = 8   ;
const NOTFOUND = 0xFFFF   ;
const WORD = 4   ;
const CMD_N = 12   ;
const FS_BASE = 0x6C00   ;
const FS_N = 8   ;
const FS_ENTRY = 32   ;
const FS_NAME_WORDS = 4   ;
const FS_ENTRY_WORDS = 8   ;
const FS_TYPEOF = 16   ;
const FS_SIZEOF = 20   ;
const FS_FAT = 256   ;
const FS_WORDS = 64   ;
const T_FILE = 1   ;
const CMDTAB = 0x29D0   ;

const C_HELP = 0x2A30
const C_VER = 0x2A36
const C_CLS = 0x2A3A
const C_ECHO = 0x2A3E
const C_TIME = 0x2A44
const C_DIR = 0x2A4A
const C_CREATE = 0x2A4E
const C_WRITE = 0x2A56
const C_TYPE = 0x2A5C
const C_DEL = 0x2A62
const C_FORMAT = 0x2A66
const C_EXIT = 0x2A6E
const S_TITLE = 0x2A74
const S_PROMPT = 0x2A84
const S_HEXTAB = 0x2A90
const S_KEYROW = 0x2AA2
const S_UNKNOWN = 0x2ABE
const S_SYNTAX = 0x2AD0
const S_NF = 0x2ADE
const S_EXIST = 0x2AEE
const S_FULL = 0x2AFC
const S_FMT = 0x2B08
const S_DELOK = 0x2B18
const S_SAVED = 0x2B22
const S_CREATED = 0x2B2A
const S_NOFILES = 0x2B34
const S_HELP = 0x2B3E
const S_VER = 0x2B7C
const S_TICKS = 0x2B90

main:
  mov sp, STACKTOP
  mov r1, 0
  mov r2, 1
  screen r1, r2
  mov r1, 1
  mov r2, SCRBASE
  screen r1, r2
  call init_strings
  call init_cmdtab
  call cls
  mov r1, CLR_WHITE
  store_32 [0x280C], r1
  mov r1, S_TITLE
  call print_str
  call print_nl
  jmp main_loop

main_loop:
  call sync_screen
  mov r1, CLR_GREEN
  mov r2, S_PROMPT
  mov r8, r1
  mov r1, CLR_GREEN
  call print_color_str
  mov r1, CH_SPACE
  call print_char ; 路径后空格(绿)
  mov r1, CH_HASH
  call print_char ; # (绿)
  mov r1, CLR_WHITE
  mov r8, r1
  store_32 [0x280C], r1 ; 输入颜色 = 白
  mov r1, CH_SPACE
  call print_char ; # 与命令之间的空格
  mov r1, LINEBUF
  call getline
  call print_nl
  mov r1, LINEBUF
  call parse
  load_32 r8, [ARGC]
  cmp r8, 0
  je main_loop
  load_32 r1, [ARGV]
  call upper
  jmp dispatch

sync_screen:
  mov r1, 0
  mov r2, 1
  screen r1, r2
  mov r1, 1
  mov r2, SCRBASE
  screen r1, r2
  ret

; 彩色打印: r8 = 颜色, r2 = 字符串
print_color_str:
  mov r1, r8
  mov r9, r2
  store_32 [0x280C], r1 ; CURFG 用 0x000C
  mov r1, r9
  call print_str
  ret

print_char:
  load_32 r2, [CROW]
  load_32 r3, [CCOL]
  cmp r1, CHAR_NL
  je print_char_nl
  cmp r1, CH_BS
  je print_char_bs
  lsl r5, r2, 6
  lsl r6, r2, 5
  add r5, r5, r6
  add r5, r5, r3
  lsl r5, r5, 2
  add r5, r5, SCRBASE
  store_8 [r5], r1
  add r5, r5, 1
  load_32 r6, [0x280C]
  store_8 [r5], r6
  add r5, r5, 1
  mov r6, 0
  store_8 [r5], r6
  add r3, r3, 1
  cmp r3, SCR_W
  je jneskip1
  jmp print_char_save
jneskip1:
  mov r3, 0
  add r2, r2, 1
  cmp r2, SCR_H
  je jneskip2
  jmp print_char_save
jneskip2:
  call scroll
  ret
print_char_save:
  store_32 [CROW], r2
  store_32 [CCOL], r3
  ret
print_char_nl:
  mov r3, 0
  add r2, r2, 1
  cmp r2, SCR_H
  je jneskip3
  jmp print_char_save
jneskip3:
  call scroll
  ret
print_char_bs:
  cmp r3, 0
  je jneskip4
  jmp print_char_bs1
jneskip4:
  cmp r2, 0
  je print_char_bsx
  sub r2, r2, 1
  mov r3, SCR_LASTCOL
  jmp print_char_bs2
print_char_bs1:
  sub r3, r3, 1
print_char_bs2:
  store_32 [CROW], r2
  store_32 [CCOL], r3
  lsl r5, r2, 6
  lsl r6, r2, 5
  add r5, r5, r6
  add r5, r5, r3
  lsl r5, r5, 2
  add r5, r5, SCRBASE
  mov r6, CH_SPACE
  store_8 [r5], r6
print_char_bsx:
  ret

cls:
cls_loop:
  mov r8, SCRBASE
  mov r9, SCR_SIZE
cls_body:
  mov r1, CH_SPACE
  store_8 [r8], r1
  add r8, r8, 1
  mov r1, CLR_WHITE
  store_8 [r8], r1
  add r8, r8, 1
  mov r1, 0
  store_8 [r8], r1
  add r8, r8, 1
  store_8 [r8], r1
  add r8, r8, 1
  sub r9, r9, 1
  cmp r9, 0
  je jneskip5
  jmp cls_body
jneskip5:
  mov r2, 0
  store_32 [CROW], r2
  store_32 [CCOL], r2
  ret

scroll:
  mov r5, SCRBASE
  mov r6, SCRBASE
  mov r7, SCR_W
  lsl r7, r7, 2
  add r6, r6, r7
  mov r7, SCR_SCROLL
scroll_loop:
  load_8 r1, [r6]
  store_8 [r5], r1
  add r5, r5, 1
  add r6, r6, 1
  load_8 r1, [r6]
  store_8 [r5], r1
  add r5, r5, 1
  add r6, r6, 1
  load_8 r1, [r6]
  store_8 [r5], r1
  add r5, r5, 1
  add r6, r6, 1
  load_8 r1, [r6]
  store_8 [r5], r1
  add r5, r5, 1
  add r6, r6, 1
  sub r7, r7, 1
  cmp r7, 0
  je jneskip6
  jmp scroll_loop
jneskip6:
  mov r7, SCR_W
scroll_clr:
  mov r1, CH_SPACE
  store_8 [r5], r1
  add r5, r5, 1
  mov r1, CLR_WHITE
  store_8 [r5], r1
  add r5, r5, 1
  mov r1, 0
  store_8 [r5], r1
  add r5, r5, 1
  store_8 [r5], r1
  add r5, r5, 1
  sub r7, r7, 1
  cmp r7, 0
  je jneskip7
  jmp scroll_clr
jneskip7:
  mov r2, SCR_LAST
  mov r3, 0
  store_32 [CROW], r2
  store_32 [CCOL], r3
  ret

print_nl:
  mov r1, CHAR_NL
  call print_char
  ret

print_str:
  mov r8, r1
print_str_loop:
  load_8 r1, [r8]
  cmp r1, 0
  je print_str_done
  call print_char
  add r8, r8, 1
  jmp print_str_loop
print_str_done:
  ret

print_hex_n:
  mov r8, r1
  mov r10, r2
  sub r9, r2, 1
  lsl r9, r9, 2
print_hex_n_loop:
  mov r2, r8
  lsr r2, r2, r9
  and r2, r2, HEX_NIB
  mov r3, S_HEXTAB
  add r3, r3, r2
  load_8 r1, [r3]
  call print_char
  sub r9, r9, 4
  sub r10, r10, 1
  cmp r10, 0
  je jneskip8
  jmp print_hex_n_loop
jneskip8:
  ret

print_hex:
  mov r2, 8
  call print_hex_n
  ret

; 键盘返回 9 位值: 第8位 = 弹起标志, 低8位 = ASCII 码
key_poll:
key_poll_loop:
  keyboard r1
  and r2, r1, KEY_DOWN ; 弹起标志(第8位)
  cmp r2, 0
  je jneskipkp
  jmp key_poll_loop
jneskipkp: ; 弹起, 忽略
  and r4, r1, KEY_MASK ; ASCII 码(低8位)
  cmp r4, 0
  je key_poll_loop ; 无按键
  ret

; 键盘原始码: 回车=10(LF), 退格=13(CR); 归一化为标准 ASCII 控制码
key_translate:
  cmp r4, RAW_ENTER
  je keyt_enter
  cmp r4, RAW_BS
  je keyt_bs
  cmp r4, RAW_ESC
  je keyt_esc
  ret
keyt_enter:
  mov r4, CH_ENTER
  ret
keyt_bs:
  mov r4, CH_BS
  ret
keyt_esc:
  mov r4, CH_ESC
  ret

init_keymap:
  mov r8, KEYMAP
  mov r9, 128
init_keymap_zero:
  store_8 [r8], zr
  add r8, r8, 1
  sub r9, r9, 1
  cmp r9, 0
  je jneskip9
  jmp init_keymap_zero
jneskip9:
  mov r8, KEYMAP
  add r8, r8, 11
  mov r9, 9
  mov r2, 0x31
init_keymap_num:
  store_8 [r8], r2
  add r8, r8, 1
  add r2, r2, 1
  sub r9, r9, 1
  cmp r9, 0
  je jneskip10
  jmp init_keymap_num
jneskip10:
  mov r8, KEYMAP
  add r8, r8, 20
  mov r2, 0x30
  store_8 [r8], r2
  mov r8, KEYMAP
  add r8, r8, 21
  mov r9, S_KEYROW
  mov r10, 26
init_keymap_alpha:
  load_8 r2, [r9]
  store_8 [r8], r2
  add r8, r8, 1
  add r9, r9, 1
  sub r10, r10, 1
  cmp r10, 0
  je jneskip11
  jmp init_keymap_alpha
jneskip11:
  mov r8, KEYMAP
  add r8, r8, RAW_ESC
  mov r2, CH_ESC
  store_8 [r8], r2
  mov r8, KEYMAP
  add r8, r8, RAW_BS
  mov r2, CH_BS
  store_8 [r8], r2
  mov r8, KEYMAP
  add r8, r8, RAW_ENTER
  mov r2, CH_ENTER
  store_8 [r8], r2
  mov r8, KEYMAP
  add r8, r8, RAW_SPACE
  mov r2, CH_SPACE
  store_8 [r8], r2
  mov r8, KEYMAP
  add r8, r8, RAW_DOT
  mov r2, 0x2E
  store_8 [r8], r2
  ret

getline:
  mov r8, r1
  mov r10, r1
  mov r9, 0
getline_loop:
  call key_poll
  call key_translate
  cmp r4, 0
  je getline_loop
  cmp r4, CH_ENTER
  je getline_done
  cmp r4, CH_ESC
  je getline_clear
  cmp r4, CH_BS
  je getline_bs
  cmp r4, CH_SPACE
  jb getline_loop
  cmp r4, CH_TILDE
  jbe jaskip27
  jmp getline_loop
jaskip27:
  cmp r9, LINE_MAX
  jae getline_loop
  mov r1, r4
  call print_char
  store_8 [r8], r4
  add r8, r8, 1
  add r9, r9, 1
  jmp getline_loop
getline_bs:
  cmp r9, 0
  je getline_loop
  sub r8, r8, 1
  sub r9, r9, 1
  mov r1, CH_BS
  call print_char
  jmp getline_loop
getline_clear:
  cmp r9, 0
  je getline_clear2
  mov r1, CH_BS
  call print_char
  sub r9, r9, 1
  jmp getline_clear
getline_clear2:
  mov r8, r10
  jmp getline_loop
getline_done:
  store_8 [r8], zr
  mov r4, r9
  ret

parse:
  mov r8, ARGV
  mov r9, r1
  mov r10, 0
  mov r3, 0
parse_loop:
  load_8 r2, [r9]
  cmp r2, 0
  je parse_done
  cmp r2, CH_SPACE
  je parse_space
  cmp r3, 0
  je jneskip12
  jmp parse_next
jneskip12:
  cmp r10, TOKEN_MAX
  jae parse_skip
  store_32 [r8], r9
  add r8, r8, WORD
  add r10, r10, 1
  mov r3, 1
  jmp parse_next
parse_space:
  cmp r3, 0
  je parse_next
  store_8 [r9], zr
  mov r3, 0
parse_next:
  add r9, r9, 1
  jmp parse_loop
parse_skip:
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0
  je parse_done
  jmp parse_skip
parse_done:
  store_32 [ARGC], r10
  mov r4, r10
  ret

upper:
  mov r8, r1
upper_loop:
  load_8 r2, [r8]
  cmp r2, 0
  je upper_done
  cmp r2, CH_A
  jb upper_next
  cmp r2, CH_Z
  jbe jaskip28
  jmp upper_next
jaskip28:
  sub r2, r2, CH_CASE
  store_8 [r8], r2
upper_next:
  add r8, r8, 1
  jmp upper_loop
upper_done:
  ret

strcmp:
  mov r8, r1
  mov r9, r2
strcmp_loop:
  load_8 r1, [r8]
  load_8 r2, [r9]
  cmp r1, r2
  je jneskip13
  jmp strcmp_ne
jneskip13:
  cmp r1, 0
  je strcmp_eq
  add r8, r8, 1
  add r9, r9, 1
  jmp strcmp_loop
strcmp_eq:
  mov r4, 1
  ret
strcmp_ne:
  mov r4, 0
  ret

strcpy_n:
  mov r8, r1
  mov r9, r2
strcpy_n_loop:
  cmp r3, 0
  je strcpy_n_done
  load_8 r1, [r9]
  cmp r1, 0
  je strcpy_n_term
  store_8 [r8], r1
  add r8, r8, 1
  add r9, r9, 1
  sub r3, r3, 1
  jmp strcpy_n_loop
strcpy_n_term:
  store_8 [r8], zr
strcpy_n_done:
  ret

find_file:
  mov r11, r1
  mov r12, 0
find_file_loop:
  lsl r7, r12, 5
  add r7, r7, FS_BASE
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
find_file_copy:
  pload r1, [r7]
  store_32 [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskip14
  jmp find_file_copy
jneskip14:
  store_8 [r8], zr
  mov r1, r11
  mov r2, NAMETMP
  call strcmp
  cmp r4, 1
  je find_file_found
  add r12, r12, 1
  cmp r12, FS_N
  je jneskip15
  jmp find_file_loop
jneskip15:
  mov r4, NOTFOUND
  ret
find_file_found:
  mov r4, r12
  ret

free_entry:
  mov r7, FS_BASE
  mov r8, 0
free_entry_loop:
  pload r1, [r7]
  cmp r1, 0
  je free_entry_got
  add r7, r7, FS_ENTRY
  add r8, r8, 1
  cmp r8, FS_N
  je jneskip16
  jmp free_entry_loop
jneskip16:
  mov r4, NOTFOUND
  ret
free_entry_got:
  mov r4, r8
  ret

entry_set_name:
  mov r11, r7
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
  mov r2, 0
entry_set_name_z:
  store_32 [r8], r2
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskip17
  jmp entry_set_name_z
jneskip17:
  mov r2, r1
  mov r1, NAMETMP
  mov r3, NAME_MAX
  call strcpy_n
  mov r7, r11
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
entry_set_name_c:
  load_32 r1, [r8]
  pstore [r7], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskip18
  jmp entry_set_name_c
jneskip18:
  ret

perr:
  mov r8, r1
  mov r1, CLR_RED
  store_32 [0x280C], r1
  mov r1, r8
  call print_str
  mov r1, CLR_WHITE
  store_32 [0x280C], r1
  call print_nl
  jmp main_loop

do_help:
  mov r1, S_HELP
  call print_str
  call print_nl
  mov r12, CMDTAB
  mov r13, CMD_N
do_help_loop:
  load_32 r1, [r12]
  call print_str
  call print_nl
  add r12, r12, 8
  sub r13, r13, 1
  cmp r13, 0
  je jneskip28
  jmp do_help_loop
jneskip28:
  jmp main_loop

do_ver:
  mov r1, S_VER
  call print_str
  call print_nl
  jmp main_loop

do_cls:
  call cls
  jmp main_loop

do_echo:
  mov r9, ARGV1
  mov r10, 1
do_echo_loop:
  load_32 r8, [ARGC]
  cmp r10, r8
  jae do_echo_done
  load_32 r1, [r9]
  call print_str
  mov r1, CH_SPACE
  call print_char
  add r9, r9, WORD
  add r10, r10, 1
  jmp do_echo_loop
do_echo_done:
  call print_nl
  jmp main_loop

do_time:
  mov r1, S_TICKS
  call print_str
  time_0 r1
  call print_hex
  call print_nl
  jmp main_loop

do_dir:
  mov r11, 0
  mov r12, 0
do_dir_loop:
  cmp r12, FS_N
  jae do_dir_end
  lsl r7, r12, 5
  add r7, r7, FS_BASE
  pload r1, [r7]
  cmp r1, 0
  je do_dir_next
  add r11, r11, 1
  mov r7, r12
  lsl r7, r7, 5
  add r7, r7, FS_BASE
  mov r8, DIRTMP
  mov r9, FS_NAME_WORDS
do_dir_copy:
  pload r1, [r7]
  store_32 [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskip19
  jmp do_dir_copy
jneskip19:
  store_8 [r8], zr
  mov r1, DIRTMP
  call print_str
  mov r1, CH_SPACE
  call print_char
  lsl r7, r12, 5
  add r7, r7, FS_BASE
  add r7, r7, FS_SIZEOF
  pload r1, [r7]
  mov r2, 4
  call print_hex_n
  call print_nl
do_dir_next:
  add r12, r12, 1
  jmp do_dir_loop
do_dir_end:
  cmp r11, 0
  je jneskip20
  jmp do_dir_ret
jneskip20:
  mov r1, S_NOFILES
  call print_str
  call print_nl
do_dir_ret:
  jmp main_loop

do_create:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb do_create_usage
  load_32 r1, [ARGV1]
  call find_file
  cmp r4, NOTFOUND
  je jneskip21
  jmp do_create_exist
jneskip21:
  call free_entry
  cmp r4, NOTFOUND
  je do_create_full
  lsl r7, r4, 5
  add r7, r7, FS_BASE
  load_32 r1, [ARGV1]
  call entry_set_name
  mov r2, T_FILE
  pstore [r7], r2
  add r7, r7, WORD
  mov r2, 0
  pstore [r7], r2
  add r7, r7, WORD
  lsl r2, r4, 8
  add r2, r2, FS_BASE
  add r2, r2, FS_FAT
  pstore [r7], r2
  mov r1, S_CREATED
  call print_str
  call print_nl
  jmp main_loop
do_create_exist:
  mov r1, S_EXIST
  jmp perr
do_create_usage:
  mov r1, S_SYNTAX
  jmp perr
do_create_full:
  mov r1, S_FULL
  jmp perr

do_write:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb do_write_usage
  load_32 r1, [ARGV1]
  call find_file
  cmp r4, NOTFOUND
  je jneskip22
  jmp do_write_have
jneskip22:
  call free_entry
  cmp r4, NOTFOUND
  je do_write_full
  lsl r7, r4, 5
  add r7, r7, FS_BASE
  load_32 r1, [ARGV1]
  call entry_set_name
  mov r2, T_FILE
  pstore [r7], r2
  add r7, r7, WORD
  mov r2, 0
  pstore [r7], r2
  add r7, r7, WORD
  lsl r2, r4, 8
  add r2, r2, FS_BASE
  add r2, r2, FS_FAT
  pstore [r7], r2
do_write_have:
  mov r13, r4
  mov r10, WRITEBUF
  mov r11, 0
do_write_key:
  call key_poll
  call key_translate
  cmp r4, 0
  je do_write_key
  cmp r4, CH_ESC
  je do_write_commit
  cmp r4, CH_BS
  je do_write_bs
  cmp r4, CH_ENTER
  je do_write_enter
  cmp r4, CH_SPACE
  jb do_write_key
  cmp r4, CH_TILDE
  jbe jaskip29
  jmp do_write_key
jaskip29:
  cmp r11, FILE_MAX
  jae do_write_key
  mov r1, r4
  call print_char
  store_8 [r10], r4
  add r10, r10, 1
  add r11, r11, 1
  jmp do_write_key
do_write_enter:
  cmp r11, FILE_MAX
  jae do_write_key
  mov r1, CHAR_NL
  call print_char
  mov r2, CHAR_NL
  store_8 [r10], r2
  add r10, r10, 1
  add r11, r11, 1
  jmp do_write_key
do_write_bs:
  cmp r11, 0
  je do_write_key
  sub r10, r10, 1
  sub r11, r11, 1
  mov r1, CH_BS
  call print_char
  jmp do_write_key
do_write_commit:
  mov r8, r10
  mov r2, 0
  store_8 [r8], r2
  add r8, r8, 1
  store_8 [r8], r2
  add r8, r8, 1
  store_8 [r8], r2
  add r8, r8, 1
  store_8 [r8], r2
  lsl r7, r13, 5
  add r7, r7, FS_BASE
  add r7, r7, FS_SIZEOF
  pstore [r7], r11
  add r7, r7, WORD
  pload r12, [r7]
  add r9, r11, 3
  lsr r9, r9, 2
  mov r8, WRITEBUF
do_write_cw:
  cmp r9, 0
  je do_write_fin
  load_8 r1, [r8]
  lsl r1, r1, 24
  mov r7, r8
  add r7, r7, 1
  load_8 r2, [r7]
  lsl r2, r2, 16
  or r1, r1, r2
  add r7, r7, 1
  load_8 r2, [r7]
  lsl r2, r2, 8
  or r1, r1, r2
  add r7, r7, 1
  load_8 r2, [r7]
  or r1, r1, r2
  pstore [r12], r1
  add r8, r8, WORD
  add r12, r12, WORD
  sub r9, r9, 1
  jmp do_write_cw
do_write_fin:
  call print_nl
  mov r1, S_SAVED
  call print_str
  call print_nl
  jmp main_loop
do_write_usage:
  mov r1, S_SYNTAX
  jmp perr
do_write_full:
  mov r1, S_FULL
  jmp perr

do_type:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb do_type_usage
  load_32 r1, [ARGV1]
  call find_file
  cmp r4, NOTFOUND
  je do_type_nf
  lsl r7, r4, 5
  add r7, r7, FS_BASE
  add r7, r7, FS_SIZEOF
  pload r11, [r7]
  add r7, r7, WORD
  pload r12, [r7]
do_type_words:
  cmp r11, 4
  jb do_type_tail
  pload r10, [r12]
  lsr r1, r10, 24
  call print_char
  lsr r1, r10, 16
  call print_char
  lsr r1, r10, 8
  call print_char
  mov r1, r10
  call print_char
  add r12, r12, WORD
  sub r11, r11, 4
  jmp do_type_words
do_type_tail:
  cmp r11, 0
  je do_type_done
  pload r10, [r12]
do_type_tail_loop:
  lsr r1, r10, 24
  call print_char
  lsl r10, r10, 8
  sub r11, r11, 1
  cmp r11, 0
  je jneskip23
  jmp do_type_tail_loop
jneskip23:
do_type_done:
  call print_nl
  jmp main_loop
do_type_nf:
  mov r1, S_NF
  jmp perr
do_type_usage:
  mov r1, S_SYNTAX
  jmp perr

do_del:
  load_32 r8, [ARGC]
  cmp r8, 2
  jb do_del_usage
  load_32 r1, [ARGV1]
  call find_file
  cmp r4, NOTFOUND
  je do_del_nf
  lsl r7, r4, 5
  add r7, r7, FS_BASE
  mov r9, FS_ENTRY_WORDS
  mov r2, 0
do_del_zero:
  pstore [r7], r2
  add r7, r7, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskip24
  jmp do_del_zero
jneskip24:
  mov r1, S_DELOK
  call print_str
  call print_nl
  jmp main_loop
do_del_nf:
  mov r1, S_NF
  jmp perr
do_del_usage:
  mov r1, S_SYNTAX
  jmp perr

do_format:
  mov r7, FS_BASE
  mov r9, FS_WORDS
  mov r2, 0
do_format_loop:
  pstore [r7], r2
  add r7, r7, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskip25
  jmp do_format_loop
jneskip25:
  mov r1, S_FMT
  call print_str
  call print_nl
  jmp main_loop

do_exit:
  mov r1, CLR_RED
  store_32 [0x280C], r1
  mov r1, S_FULL
  call print_str
  mov r1, CLR_WHITE
  store_32 [0x280C], r1
  call print_nl
exit_halt:
  jmp exit_halt

dispatch:
  mov r11, r1
  mov r12, CMDTAB
  mov r13, CMD_N
dispatch_loop:
  load_32 r2, [r12]
  mov r1, r11
  call strcmp
  cmp r4, 1
  je dispatch_found
  add r12, r12, 8
  sub r13, r13, 1
  cmp r13, 0
  je jneskip26
  jmp dispatch_loop
jneskip26:
  mov r1, S_UNKNOWN
  jmp perr
dispatch_found:
  add r12, r12, WORD
  load_32 r1, [r12]
  jmp r1

init_cmdtab:
  mov r3, CMDTAB
  mov r2, C_HELP
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_help
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_VER
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_ver
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_CLS
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_cls
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_ECHO
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_echo
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_TIME
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_time
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_DIR
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_dir
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_CREATE
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_create
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_WRITE
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_write
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_TYPE
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_type
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_DEL
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_del
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_FORMAT
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_format
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, C_EXIT
  store_32 [r3], r2
  add r3, r3, WORD
  mov r2, do_exit
  store_32 [r3], r2
  add r3, r3, WORD
  ret

; ---------------------------------------------------------------- 常量字符串初始化
; 逐字节 store_8 写入(不依赖 16 位存储)
init_strings:
  ; ---- C_HELP ----
  mov r3, C_HELP
  mov r2, 0x4548
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x504c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_VER ----
  mov r3, C_VER
  mov r2, 0x4556
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0052
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_CLS ----
  mov r3, C_CLS
  mov r2, 0x4c43
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0053
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_ECHO ----
  mov r3, C_ECHO
  mov r2, 0x4345
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4f48
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_TIME ----
  mov r3, C_TIME
  mov r2, 0x4954
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x454d
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_DIR ----
  mov r3, C_DIR
  mov r2, 0x4944
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0052
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_CREATE ----
  mov r3, C_CREATE
  mov r2, 0x5243
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4145
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4554
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_WRITE ----
  mov r3, C_WRITE
  mov r2, 0x5257
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5449
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0045
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_TYPE ----
  mov r3, C_TYPE
  mov r2, 0x5954
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4550
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_DEL ----
  mov r3, C_DEL
  mov r2, 0x4544
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x004c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_FORMAT ----
  mov r3, C_FORMAT
  mov r2, 0x4f46
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4d52
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5441
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- C_EXIT ----
  mov r3, C_EXIT
  mov r2, 0x5845
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5449
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_TITLE ----
  mov r3, S_TITLE
  mov r2, 0x4f53
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x414e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4154
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4420
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x534f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4d20
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4e49
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0049
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_PROMPT ----
  mov r3, S_PROMPT
  mov r2, 0x535b
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6e6f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7461
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5d61
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7E20
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_HEXTAB ----
  mov r3, S_HEXTAB
  mov r2, 0x3130
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x3332
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x3534
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x3736
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x3938
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4241
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4443
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4645
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_KEYROW ----
  mov r3, S_KEYROW
  mov r2, 0x5751
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5245
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5954
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4955
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x504f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5341
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4644
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4847
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4b4a
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5a4c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4358
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4256
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4d4e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_UNKNOWN ----
  mov r3, S_UNKNOWN
  mov r2, 0x6e55
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6e6b
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x776f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x206e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6f63
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6d6d
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6e61
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2e64
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_SYNTAX ----
  mov r3, S_SYNTAX
  mov r2, 0x7953
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x746e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7861
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6520
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7272
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x726f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x002e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_NF ----
  mov r3, S_NF
  mov r2, 0x6946
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x656c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6e20
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x746f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6620
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x756f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x646e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x002e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_EXIST ----
  mov r3, S_EXIST
  mov r2, 0x6946
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x656c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6520
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6978
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7473
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2e73
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_FULL ----
  mov r3, S_FULL
  mov r2, 0x6944
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6b73
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6620
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6c75
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2e6c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_FMT ----
  mov r3, S_FMT
  mov r2, 0x6944
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6b73
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6620
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x726f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x616d
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7474
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6465
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x002e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_DELOK ----
  mov r3, S_DELOK
  mov r2, 0x6544
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x656c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6574
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2e64
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_SAVED ----
  mov r3, S_SAVED
  mov r2, 0x6153
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6576
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2e64
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_CREATED ----
  mov r3, S_CREATED
  mov r2, 0x7243
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6165
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6574
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2e64
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_NOFILES ----
  mov r3, S_NOFILES
  mov r2, 0x6f4e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6620
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6c69
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7365
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x002e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_HELP ----
  mov r3, S_HELP
  mov r2, 0x4548
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x504c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5620
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5245
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4320
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x534c
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4520
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4843
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x204f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4954
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x454d
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4420
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5249
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4320
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4552
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5441
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2045
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5257
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5449
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2045
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5954
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4550
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4420
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4c45
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4620
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x524f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x414d
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2054
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5845
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x5449
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0000
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_VER ----
  mov r3, S_VER
  mov r2, 0x4f53
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x414e
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4154
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4420
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x534f
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4d20
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4e49
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2049
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2e31
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0030
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; ---- S_TICKS ----
  mov r3, S_TICKS
  mov r2, 0x6954
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6b63
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x3a73
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x0020
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ; S_HELP 覆写为 "commands:"
  mov r3, S_HELP
  mov r2, 0x6f63
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6d6d
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6e61
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7364
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x003a
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  ret

FS_BASE:

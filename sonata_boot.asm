; ============================================================================
; SONATA BOOT v2.0 — BIOS: 内存管理 + 程序加载器 + 系统调用
; 本文件是唯一由游戏汇编器直接汇编并放入程序内存的主程序。
;
; 启动流程:
;   boot 初始化 -> 从外存加载 DOS 到主内存 -> 跳入 DOS 执行
;   -> DOS 启动后, 用户执行第三方二进制程序(*.mvt), 由同一加载器加载执行
;
; 内存布局(冯·诺依曼: store/load 写入主内存的内容可以直接执行):
;   0x0000..0x1FFF  boot 代码(上限 8KB)
;   0x2000..0x2FFF  boot 数据 + DOS 内核共享数据(变量/缓冲/字符串/跳转表)
;   0x3000..0x6BFF  屏幕帧缓冲(96x40x4 = 15360B)
;   0x6C00..0x6FFF  栈(向下生长, 栈顶 0x7000)
;   0x7400..0xFCFF  加载区堆(DOS 内核与 .mvt 程序)
;   0xFD00..0xFDFF  运行时 MVT 固定加载区(MKMVT 产物, 无重定位)
;
; 外存 = 磁盘镜像 = 文件系统(二合一, 导入游戏后经 pload/pstore 读写):
;   0x0000..0x7FFF  sonata_disk.bin(大端 32 位字; 镜像填充整个区域,
;                   运行时 WRITE/MKMVT/MD 等命令直接 pstore 修改,
;                   REBOOT 后仍然有效 —— 见下方 v2 格式)
;
; DOS 内核(.mvt)启动时把 FS/env 等函数地址写入 0x23A0 的跳转表,
; 各 .mvt 程序经跳转表调用内核函数(未定义标号=外部, 转换器解析为绝对地址)。
;
; 磁盘镜像 v2(转换器生成, 数值字段大端; 头部 32B + 64 表项 x40B):
;   +0   魔数 4B "SNT1"             +4  版本 4B (=2)
;   +8   文件数 4B                  +12 容量 4B (=64)
;   +16  freeOff 4B(代码区空闲指针) +20 codeEnd 4B (=0x7FFF)
;   +24  tableBase 4B (=32)         +28 baseOff 4B(FORMAT 复位用)
;   +32  文件表 64 x 40B:
;          [名字 12B(NUL 补齐)][类型 4B][大小 4B][入口偏移 4B][代码偏移 4B]
;          [重定位数 4B][重定位表偏移 4B][父目录 4B]
;        类型: 0=空闲 1=DATA 2=MVT(运行时) 3=DIR(用户目录)
;               4=SCO(内置程序) 5=SCODIR(内置目录)
;   代码区 0xA20..0x7FFF: 机器码(4 字节对齐) + 重定位表(代码内字节偏移 x 4B)
;   运行时新建文件从 freeOff 起分配, 写入镜像末尾(会话内有效, 不写回文件)
;
; 重定位: 程序在地址 0 汇编; 加载器把代码按字节拷到分配到的加载
;   地址 D, 再把重定位表每个偏移处 32 位字 += D。
;
; boot 导出函数(固定绝对地址, DOS 与 .mvt 程序直接调用):
;   print_char print_str print_nl print_hex print_hex_n cls set_fg
;   print_fill print_spaces strlen key_poll key_translate getline
;   parse upper strcmp strcpy_n mem_alloc mem_free
;   disk_find disk_meta exec set_shell exit_proc disk_base boot_halt
; ============================================================================
;
; ---------- 内存 ----------
const STACKTOP   = 0x7000   ; 栈顶(向下生长到 0x6C00; 0x6C00 以下 = 屏幕)
const LOAD_BASE  = 0x7400   ; 加载区起点(跳转立即数 16 位 -> 必须 < 0x10000)
const LOAD_SIZE  = 0x8900   ; 加载区大小 = RTEXE_BASE - LOAD_BASE(堆到 0xFD00 为止)
const DISK_BASE  = 0        ; 磁盘镜像在外存的起始地址(游戏实测: 外存 0)
;
; ---------- boot 数据 / DOS 内核共享数据 ----------
const CROW       = 0x2000   ; 光标行
const CCOL       = 0x2004   ; 光标列
const CURFG      = 0x2008   ; 当前前景色
const ARGC       = 0x200C   ; 命令行参数个数
const DIRFLAGS   = 0x2010   ; DIR 选项标志(bit0=W bit1=P)
const CURDIR     = 0x2014   ; 当前目录入口号
const DIRLINES   = 0x2018   ; DIR /P 行计数
const LINEBUF    = 0x2020   ; 命令行缓冲(128B)
const ARGV       = 0x20A0   ; argv 指针表(8x4B)
const ARGV1      = 0x20A4   ; argv[1]
const ARGV2      = 0x20A8   ; argv[2]
const DIRTMP     = 0x20C0   ; 目录项名临时区(16B)
const NAMETMP    = 0x20D0   ; 文件名临时区(16B)
const WRITEBUF   = 0x20E0   ; 写文件缓冲(256B)
const ENVBASE    = 0x21E0   ; 环境变量区(4x24B: 名字8B+值16B)
const DATEVAR    = 0x2240   ; 日期 YYYYMMDD(8B)
const META_SIZE  = 0x2248   ; exec 元数据暂存(5 字)
const META_ENTRY = 0x224C
const META_CODE  = 0x2250
const META_NREL  = 0x2254
const META_ROFF  = 0x2258
const META_TYPE  = 0x2268   ; exec 元数据: 文件类型
const CASEFLAG   = 0x226C   ; 大小写锁定: 1 = 字母翻转大小写(CapsLock 0x18 切换)
const DISKSAV    = 0x225C   ; DISK_BASE 暂存
const LAST_PROG  = 0x2260   ; 最近加载程序块地址(exit_proc 释放)
const SHELL_ENTRY = 0x2264  ; DOS 命令循环入口(set_shell 登记)
;
; ---------- boot 字符串 ----------
const S_BOOT     = 0x2270   ; "Sonata Boot v2.0"
const S_LOAD     = 0x2284   ; "Loading DOS..."
const S_DISKERR  = 0x2294   ; "Disk error."
const S_MEMERR   = 0x22A0   ; "Memory full."
const S_K_DOS    = 0x22B0   ; "DOS.SCO"
const S_HEXTAB   = 0x22C0   ; "0123456789ABCDEF"
const S_NODOS    = 0x22D1   ; "No DOS."
;
; ---------- DOS 内核字符串(固定地址, 内核启动时写入, 程序经 const 引用) ----------
const S_UNKNOWN  = 0x22E0   ; "Unknown command."
const S_SYNTAX   = 0x22F2   ; "Syntax error."
const S_NF       = 0x2300   ; "File not found."
const S_EXIST    = 0x2310   ; "File exists."
const S_FULL     = 0x231E   ; "Disk full."
const S_DELOK    = 0x232A   ; "Deleted."
const S_SAVED    = 0x2334   ; "Saved."
const S_CREATED  = 0x233C   ; "Created."
const S_NOTDIR   = 0x2346   ; "Not a directory."
const S_NOTFILE  = 0x2358   ; "Not a file."
const S_PATHNF   = 0x2366   ; "Path not found."
const S_PROMPTNAME = 0x2378 ; "PROMPT"
const S_PATHNAME = 0x2380   ; "PATH"
const S_DEFAULTDATE = 0x2388 ; "20240101"
;
; ---------- DOS 内核跳转表(内核写入 jmp 指令; .mvt 程序经此调用内核函数) ----------
const JT_FIND_IN_DIR = 0x23A0
const JT_FREE_ENTRY  = 0x23A4
const JT_ENTRY_SET   = 0x23A8
const JT_DIR_CHILD   = 0x23AC
const JT_ENV_FIND    = 0x23B0
const JT_ENV_SET     = 0x23B4
const JT_PERR        = 0x23B8
const JT_REBOOT      = 0x23BC
;
; ---------- 屏幕 ----------
const SCRBASE    = 0x3000   ; 屏幕帧缓冲起点(屏幕固定从 12288 读取)
const SCR_W      = 96
const SCR_H      = 40
const SCR_SIZE   = 3840     ; 96*40 格
const SCR_LAST   = 39
const SCR_LASTCOL = 95
const SCR_SCROLL = 3744     ; 滚动拷贝格数 39*96
const OPT_MODE   = 0
const OPT_OFF    = 1
const MODE_ASCII32 = 1
;
; ---------- 颜色 ----------
const CLR_WHITE  = 0xFF
const CLR_GREEN  = 0x1C
const CLR_RED    = 0xE0
;
; ---------- 键盘(实测) ----------
const KEY_DOWN   = 0x0100
const KEY_MASK   = 0x00FF
const RAW_ESC    = 14   ; Esc 键原始码(游戏实测; 非 27/1)
const RAW_BS     = 13
const RAW_ENTER  = 10
;
; ---------- ASCII ----------
const CH_CAPS    = 0x18   ; CapsLock(游戏实测键码)
const CH_ENTER   = 0x0D
const CH_ENTER2  = 0x0A
const CH_ESC     = 0x1B
const CH_BS      = 0x08
const CH_SPACE   = 0x20
const CH_TILDE   = 0x7E
const CH_DOT     = 0x2E
const CH_SLASH   = 0x2F
const CH_BSLASH  = 0x5C
const CH_EQ      = 0x3D
const CH_HASH    = 0x23
const CH_MINUS   = 0x2D
const CH_A       = 0x61
const CH_Z       = 0x7A
const CH_0       = 0x30
const CH_9       = 0x39
const CH_FA      = 0x41
const CH_FF      = 0x46
const CH_CASE    = 0x20
const CH_HEXOFF  = 0x37
const HEX_NIB    = 0xF
const CHAR_NL    = 0x0A
const LINE_MAX   = 0x7F
const NAME_MAX   = 15
const FILE_MAX   = 0xFF
const TOKEN_MAX  = 8
const DUMP_N     = 16
const NOTFOUND   = 0xFFFF
const WORD       = 4
const ENV_N      = 4
const Q_COUNT    = 10
;
; ---------- 磁盘 ----------
const D_MAGIC_HI = 0x534E    ; "SNT1" 高 16 位(大端: pload[0] = 0x534E5431)
const D_MAGIC_LO = 0x5431    ; "SNT1" 低 16 位
const D_NAMESZ   = 12
const D_ENTSZ    = 40
const D_TBL_BASE = 32      ; 文件表起点(头部 32B, 表项 40B, 容量 64)
const D_CAP      = 64
const D_TYPE_OF  = 12      ; 表项字段偏移
const D_SIZE_OF  = 16
const D_ENTRY_OF = 20
const D_CODE_OF  = 24
const D_NREL_OF  = 28
const D_ROFF_OF  = 32
const D_PAR_OF   = 36
const D_FREEOFF  = 16      ; 头部: 代码区空闲指针
const D_CODEEND  = 20      ; 头部: 代码区末端(=0x7FFF)
const D_BASEOFF  = 28      ; 头部: 构建后空闲指针(FORMAT 复位)
const T_FILE     = 1       ; 文件类型: 数据
const T_MVT      = 2       ; 运行时 MVT(无重定位, 固定地址加载)
const T_DIR      = 3       ; 目录
const T_SCO      = 4       ; 内置系统程序
const RTEXE_BASE = 0xFD00  ; 运行时 MVT 固定加载地址(堆 0x7400..0xFD00 之上)
;
; ============================================================================
; 启动入口
; ============================================================================
main:
  mov sp, STACKTOP
  mov r1, OPT_MODE
  mov r2, MODE_ASCII32
  screen r1, r2
  mov r1, OPT_OFF
  mov r2, SCRBASE
  screen r1, r2
  mov r1, OPT_OFF
  mov r2, SCRBASE
  screen r1, r2
  call init_strings
  call cls
  mov r1, CLR_WHITE
  call set_fg
  mov r1, S_BOOT
  call print_str
  call print_nl
  call disk_base
  mov r5, r4
  pload r1, [r5]
  mov r2, D_MAGIC_HI
  lsl r2, r2, 16
  mov r3, D_MAGIC_LO
  or r2, r2, r3
  cmp r1, r2
  je boot_disk_ok
  mov r1, S_DISKERR
  call print_str
  jmp boot_halt
boot_disk_ok:
  mov r1, S_LOAD
  call print_str
  call print_nl
  call init_heap
  mov r2, 0
  store_32 [SHELL_ENTRY], r2
  store_32 [LAST_PROG], r2
  mov r1, S_K_DOS
  call exec
  cmp r4, NOTFOUND
  je boot_nodos
  cmp r4, 0
  je boot_nodos
  mov sp, STACKTOP
  jmp r4
boot_nodos:
  mov r1, S_NODOS
  call print_str
  jmp boot_halt
boot_halt:
  jmp boot_halt
; ============================================================================
; 硬复位: 清零全部数据内存(0x2000..0xFFFF, 含屏幕/栈/堆/加载区,
; 保留 0x0000..0x1FFF 的 boot 自身)与寄存器, 然后重启到 boot main
; (REBOOT 命令经内核 reboot_entry 跳到这里; 外存不受影响)
; ============================================================================
hard_reset:
  mov r8, 0x2000
  mov r9, 0x3800
hard_reset_loop:
  store_32 [r8], zr
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je hard_reset_go
  jmp hard_reset_loop
hard_reset_go:
  mov r1, 0
  mov r2, 0
  mov r3, 0
  mov r4, 0
  mov r5, 0
  mov r6, 0
  mov r7, 0
  mov r8, 0
  mov r9, 0
  mov r10, 0
  mov r11, 0
  mov r12, 0
  mov r13, 0
  mov sp, STACKTOP
  jmp main


; ============================================================================
; 磁盘基址: r4 = DISK_BASE(外存起始地址 0)
; ============================================================================
disk_base:
  mov r4, DISK_BASE
  ret

; ============================================================================
; 内存管理: 加载区 [LOAD_BASE, LOAD_BASE+LOAD_SIZE) 首次适配分配器
; 块头 8B: 字1 = (大小<<1)|占用位, 字2 = 下一块
; ============================================================================
init_heap:
  mov r2, LOAD_SIZE
  lsl r2, r2, 1
  mov r8, LOAD_BASE
  store_32 [r8], r2
  add r8, r8, WORD
  mov r2, 0
  store_32 [r8], r2
  ret

; r1 = 字节数 -> r4 = 地址(8 字节头后) 或 0
mem_alloc:
  mov r11, r1
  mov r12, LOAD_BASE
mem_alloc_loop:
  load_32 r2, [r12]
  cmp r2, 0
  je mem_alloc_fail
  and r3, r2, 1
  cmp r3, 0
  je mem_alloc_try
  jmp mem_alloc_next
mem_alloc_try:
  lsr r5, r2, 1
  add r6, r11, 8
  cmp r5, r6
  jb mem_alloc_next
  sub r7, r5, r6
  cmp r7, 16
  jb mem_alloc_whole
  add r9, r12, WORD
  load_32 r10, [r9]
  lsl r6, r6, 1
  add r6, r6, 1
  store_32 [r12], r6
  add r8, r12, r5
  sub r8, r8, r7
  store_32 [r9], r8
  lsl r7, r7, 1
  store_32 [r8], r7
  add r8, r8, WORD
  store_32 [r8], r10
  mov r4, r12
  add r4, r4, 8
  ret
mem_alloc_whole:
  add r2, r2, 1
  store_32 [r12], r2
  mov r4, r12
  add r4, r4, 8
  ret
mem_alloc_next:
  add r12, r12, WORD
  load_32 r9, [r12]
  cmp r9, 0
  je mem_alloc_fail
  mov r12, r9
  jmp mem_alloc_loop
mem_alloc_fail:
  mov r4, 0
  ret

; r1 = 地址 -> 释放
mem_free:
  sub r12, r1, 8
  load_32 r2, [r12]
  lsr r2, r2, 1
  lsl r2, r2, 1
  store_32 [r12], r2
  ret

; ============================================================================
; 磁盘驱动(外存经 pload 按 32 位大端字读取, 字节经移位提取)
; ============================================================================
; r1 = 文件名(RAM 字符串) -> r4 = 文件表索引 或 NOTFOUND; 命中时 r5 = 表项地址
disk_find:
  mov r11, r1
  call disk_base
  add r12, r4, D_TBL_BASE   ; 表起点
  mov r13, 0
disk_find_loop:
  cmp r13, D_CAP
  jae disk_find_nf
  pload r1, [r12]           ; 名字首字: 0 = 空闲项
  cmp r1, 0
  je disk_find_next
  mov r7, NAMETMP
  mov r8, 0
disk_find_cp:
  cmp r8, D_NAMESZ
  jae disk_find_cmp
  mov r10, r8
  and r2, r10, 3
  sub r10, r10, r2
  add r10, r10, r12
  pload r1, [r10]
  mov r9, 3
  sub r9, r9, r2
  lsl r9, r9, 3
  lsr r1, r1, r9
  store_8 [r7], r1
  add r7, r7, 1
  add r8, r8, 1
  jmp disk_find_cp
disk_find_cmp:
  mov r1, r11
  mov r2, NAMETMP
  call strcmp
  cmp r4, 1
  je disk_find_got
disk_find_next:
  add r12, r12, D_ENTSZ
  add r13, r13, 1
  jmp disk_find_loop
disk_find_nf:
  mov r4, NOTFOUND
  ret
disk_find_got:
  mov r4, r13
  mov r5, r12
  ret

; r5 = 表项地址 -> r12 = 类型, r6 = 大小, r13 = 入口偏移, r11 = 代码偏移,
;                 r7 = 重定位数, r8 = 重定位表偏移, r9 = 父目录
disk_meta:
  add r10, r5, D_TYPE_OF
  pload r12, [r10]
  add r10, r10, WORD
  pload r6, [r10]
  add r10, r10, WORD
  pload r13, [r10]
  add r10, r10, WORD
  pload r11, [r10]
  add r10, r10, WORD
  pload r7, [r10]
  add r10, r10, WORD
  pload r8, [r10]
  add r10, r10, WORD
  pload r9, [r10]
  ret

; ============================================================================
; 外存代码区分配: r1 = 字节数 -> r4 = 外存偏移 或 NOTFOUND(空间不足)
; 从头部 freeOff(+16) 分配, 对齐 4 字节, 上限 codeEnd(+20)
; ============================================================================
disk_alloc:
  add r11, r1, 3
  and r11, r11, 0xFFFC
  call disk_base
  add r12, r4, D_FREEOFF
  pload r1, [r12]
  add r13, r1, r11
  add r12, r12, WORD
  pload r2, [r12]
  cmp r13, r2
  ja disk_alloc_full
  sub r12, r12, WORD
  pstore [r12], r13
  mov r4, r1
  ret
disk_alloc_full:
  mov r4, NOTFOUND
  ret

; ============================================================================
; 程序加载器: 从外存拷机器码到主内存 + 重定位, 返回入口地址
; r1 = 文件名 -> r4 = D + 入口偏移; 未找到 r4 = NOTFOUND; 内存不足 r4 = 0
; ============================================================================
exec:
  mov r13, r1
  call disk_base
  store_32 [DISKSAV], r4
  mov r1, r13
  call disk_find
  cmp r4, NOTFOUND
  je exec_nf
  mov r13, r5
  call disk_meta
  store_32 [META_SIZE], r6
  store_32 [META_ENTRY], r13
  store_32 [META_CODE], r11
  store_32 [META_NREL], r7
  store_32 [META_ROFF], r8
  store_32 [META_TYPE], r12
  ; 运行时 MVT(类型 2 且无重定位)-> 固定地址加载, 不占堆
  cmp r12, T_MVT
  jne exec_heap
  load_32 r1, [META_NREL]
  cmp r1, 0
  jne exec_heap
  mov r2, 0
  store_32 [LAST_PROG], r2
  mov r12, RTEXE_BASE
  mov r8, r12
  jmp exec_copygo
exec_heap:
  mov r1, r6
  call mem_alloc
  cmp r4, 0
  je exec_mem
  store_32 [LAST_PROG], r4
  mov r12, r4
  mov r8, r4
exec_copygo:
  load_32 r5, [DISKSAV]
  load_32 r1, [META_CODE]
  add r5, r5, r1
  load_32 r6, [META_SIZE]
  mov r9, r6
  lsr r9, r9, 2
  cmp r9, 0
  je exec_copy_tail
exec_copy_w:
  pload r1, [r5]
  store_32 [r8], r1
  add r5, r5, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je exec_copy_tail
  jmp exec_copy_w
exec_copy_tail:
  and r10, r6, 3
  cmp r10, 0
  je exec_reloc
exec_copy_b:
  mov r1, r5
  and r2, r1, 3
  sub r1, r1, r2
  pload r3, [r1]
  mov r9, 3
  sub r9, r9, r2
  lsl r9, r9, 3
  lsr r3, r3, r9
  store_8 [r8], r3
  add r5, r5, 1
  add r8, r8, 1
  sub r10, r10, 1
  cmp r10, 0
  je exec_reloc
  jmp exec_copy_b
exec_reloc:
  load_32 r1, [META_NREL]
  cmp r1, 0
  je exec_done
  load_32 r5, [DISKSAV]
  load_32 r1, [META_ROFF]
  add r5, r5, r1
  load_32 r9, [META_NREL]
exec_reloc_loop:
  cmp r9, 0
  je exec_done
  pload r1, [r5]
  add r1, r1, r12
  load_32 r2, [r1]
  add r2, r2, r12
  store_32 [r1], r2
  add r5, r5, WORD
  sub r9, r9, 1
  jmp exec_reloc_loop
exec_done:
  mov r4, r12
  load_32 r1, [META_ENTRY]
  add r4, r4, r1
  ret
exec_nf:
  mov r4, NOTFOUND
  ret
exec_mem:
  mov r1, S_MEMERR
  call print_str
  call print_nl
  mov r4, 0
  ret

; ============================================================================
; DOS 登记命令循环入口(r1 = 入口地址); 程序退出时 exit_proc 跳回该地址
; ============================================================================
set_shell:
  store_32 [SHELL_ENTRY], r1
  ret

; 程序退出: 释放 LAST_PROG 块, 复位栈, 跳回 DOS 命令循环
exit_proc:
  load_32 r1, [LAST_PROG]
  cmp r1, 0
  je exit_proc_none
  call mem_free
exit_proc_none:
  mov sp, STACKTOP
  load_32 r1, [SHELL_ENTRY]
  jmp r1

; ============================================================================
; 屏幕输出(含滚动与退格)
; ============================================================================
set_fg:
  store_32 [CURFG], r1
  ret

cls:
  mov r8, SCRBASE
  mov r9, SCR_SIZE
  mov r1, CH_SPACE
  lsl r1, r1, 24
  mov r2, CLR_WHITE
  lsl r2, r2, 16
  or r1, r1, r2
cls_body:
  store_32 [r8], r1
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskip1
  jmp cls_body
jneskip1:
  mov r2, 0
  store_32 [CROW], r2
  store_32 [CCOL], r2
  ret

; 整屏上滚一行: 第 1 行拷到第 0 行, ..., 清空最后一行, 光标置底行首
scroll:
  mov r5, SCRBASE
  mov r6, SCRBASE
  mov r7, SCR_W
  lsl r7, r7, 2
  add r6, r6, r7
  mov r7, SCR_SCROLL
scroll_loop:
  load_32 r1, [r6]
  store_32 [r5], r1
  add r5, r5, WORD
  add r6, r6, WORD
  sub r7, r7, 1
  cmp r7, 0
  je jneskip2
  jmp scroll_loop
jneskip2:
  mov r7, SCR_W
  mov r1, CH_SPACE
  lsl r1, r1, 24
  mov r2, CLR_WHITE
  lsl r2, r2, 16
  or r1, r1, r2
scroll_clr:
  store_32 [r5], r1
  add r5, r5, WORD
  sub r7, r7, 1
  cmp r7, 0
  je jneskip3
  jmp scroll_clr
jneskip3:
  mov r2, SCR_LAST
  mov r3, 0
  store_32 [CROW], r2
  store_32 [CCOL], r3
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
  load_32 r6, [CURFG]
  store_8 [r5], r6
  add r5, r5, 1
  mov r6, 0
  store_8 [r5], r6
  add r3, r3, 1
  cmp r3, SCR_W
  je jneskip4
  jmp print_char_save
jneskip4:
  mov r3, 0
  add r2, r2, 1
  cmp r2, SCR_H
  je jneskip5
  jmp print_char_save
jneskip5:
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
  je jneskip6
  jmp print_char_save
jneskip6:
  call scroll
  ret
print_char_bs:
  cmp r3, 0
  je jneskip7
  jmp print_char_bs1
jneskip7:
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

print_nl:
  mov r1, CHAR_NL
  call print_char
  ret

; r1 = RAM 字符串地址
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

; r1 = 值, r2 = 位数(1..8), 打印十六进制
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

; r1 = 次数, r2 = 字符
print_fill:
  mov r8, r1
  mov r9, r2
print_fill_loop:
  cmp r8, 0
  je print_fill_done
  mov r1, r9
  call print_char
  sub r8, r8, 1
  jmp print_fill_loop
print_fill_done:
  ret

; r1 = 空格数
print_spaces:
  mov r9, r1
print_spaces_loop:
  cmp r9, 0
  je print_spaces_done
  mov r1, CH_SPACE
  call print_char
  sub r9, r9, 1
  jmp print_spaces_loop
print_spaces_done:
  ret

; r1 = 字符串 -> r4 = 长度
strlen:
  mov r8, r1
  mov r4, 0
strlen_loop:
  load_8 r2, [r8]
  cmp r2, 0
  je strlen_done
  add r8, r8, 1
  add r4, r4, 1
  jmp strlen_loop
strlen_done:
  ret

; ============================================================================
; 键盘
; ============================================================================
key_poll:
key_poll_loop:
  keyboard r1
  and r2, r1, KEY_DOWN
  cmp r2, 0
  je jneskip9
  jmp key_poll_loop
jneskip9:
  and r4, r1, KEY_MASK
  cmp r4, 0
  je key_poll_loop
  ret

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

; r1 = 缓冲地址 -> r4 = 长度; 支持退格/回车/Esc清行
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
  cmp r4, CH_ENTER2
  je getline_done
  cmp r4, CH_ESC
  je getline_clear
  cmp r4, CH_BS
  je getline_bs
  cmp r4, CH_CAPS
  je getline_tab
  cmp r4, CH_SPACE
  jb getline_loop
  cmp r4, CH_TILDE
  jbe jaskip1
  jmp getline_loop
jaskip1:
  cmp r9, LINE_MAX
  jae getline_loop
  call case_fix
  mov r1, r4
  call print_char
  store_8 [r8], r4
  add r8, r8, 1
  add r9, r9, 1
  jmp getline_loop
getline_tab:
  load_32 r2, [CASEFLAG]
  xor r2, r2, 1
  store_32 [CASEFLAG], r2
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

; ============================================================================
; 命令行解析
; ============================================================================
; r1 = 行缓冲; 就地分词, argv 指针存 ARGV, argc 存 [ARGC], 返回 r4 = argc
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
  je jneskip10
  jmp parse_next
jneskip10:
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

; r1 = 字符串地址, 原地转大写
upper:
  mov r8, r1
upper_loop:
  load_8 r2, [r8]
  cmp r2, 0
  je upper_done
  cmp r2, CH_A
  jb upper_next
  cmp r2, CH_Z
  jbe jaskip2
  jmp upper_next
jaskip2:
  sub r2, r2, CH_CASE
  store_8 [r8], r2
upper_next:
  add r8, r8, 1
  jmp upper_loop
upper_done:
  ret

; ============================================================================
; 大小写锁定: CASEFLAG=1 时字母翻转大小写(r4 入出)
; ============================================================================
case_fix:
  load_32 r2, [CASEFLAG]
  cmp r2, 0
  je case_fix_ret
  cmp r4, CH_FA
  jb case_fix_ret
  cmp r4, CH_FF
  jbe case_fix_up
  cmp r4, CH_A
  jb case_fix_ret
  cmp r4, CH_Z
  ja case_fix_ret
  sub r4, r4, CH_CASE
  jmp case_fix_ret
case_fix_up:
  add r4, r4, CH_CASE
case_fix_ret:
  ret

; ============================================================================
; 字符串工具
; ============================================================================
strcmp:
  mov r8, r1
  mov r9, r2
strcmp_loop:
  load_8 r1, [r8]
  load_8 r2, [r9]
  cmp r1, r2
  je jneskip11
  jmp strcmp_ne
jneskip11:
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

; r1 = 目标, r2 = 源, r3 = 最大拷贝字节数(含结尾0)
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

; ============================================================================
; 字符串初始化
; ============================================================================
init_strings:
  mov r3, S_BOOT
  mov r2, 0x6F53
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x616E
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6174
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4220
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6F6F
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2074
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x3276
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x302E
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
  mov r3, S_LOAD
  mov r2, 0x6F4C
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6461
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6E69
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2067
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4F44
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2E53
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2E2E
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
  mov r3, S_DISKERR
  mov r2, 0x6944
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6B73
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
  mov r2, 0x726F
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x002E
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r3, S_MEMERR
  mov r2, 0x654D
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x6F6D
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x7972
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
  mov r2, 0x6C75
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2E6C
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
  mov r3, S_K_DOS
  mov r2, 0x4F44
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x2E53
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x4353
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x004F
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
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
  mov r3, S_NODOS
  mov r2, 0x6F4E
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
  mov r2, 0x534F
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  mov r2, 0x002E
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ret

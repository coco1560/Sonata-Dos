; ============================================================================
; SONATA DOS 完整版内核 v3.0(.mvt, 由 boot 从磁盘加载执行)
; 本文件由转换器汇编; 未定义标号 = boot 导出函数(绝对地址, 不重定位)。
;
; 职责: 文件系统 / 环境变量 / 命令 shell / 程序加载
; .mvt 程序经 0x23A0 跳转表调用本内核函数(启动时写入 jmp 指令)。
; ============================================================================

main:
  mov r1, shell_loop
  call set_shell
  call write_jumptab
  call init_vars
  call init_strings
  call cls
  call show_banner

shell_loop:
  ; 提示符: PROMPT 环境变量(绿), 默认 "[Sonata] ~路径 # "
  mov r1, CLR_GREEN
  call set_fg
  mov r1, S_PROMPTNAME
  call env_find
  cmp r4, NOTFOUND
  je shell_pdef
  lsl r3, r4, 4
  lsl r5, r4, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  add r3, r3, 8
  load_8 r2, [r3]
  cmp r2, 0
  je shell_pdef
  mov r1, r3
  call print_str
  jmp shell_go
shell_pdef:
  mov r1, s_defprompt
  call print_str
  call print_path
  mov r1, CH_SPACE
  call print_char
  mov r1, CH_HASH
  call print_char
shell_go:
  mov r1, CLR_WHITE
  call set_fg
  mov r1, CH_SPACE
  call print_char
  mov r1, LINEBUF
  call getline
  call print_nl
  mov r1, LINEBUF
  call parse
  load_32 r8, [ARGC]
  cmp r8, 0
  je shell_loop
  load_32 r1, [ARGV]
  call upper
  call fs_exec
  cmp r4, 1
  je shell_loop
  mov r1, S_UNKNOWN
  call perr
  jmp shell_loop

; ============================================================================
; 程序加载执行: r1 = 大写命令名(含别名映射)
; 命中则执行不返回; 未找到 r4 = NOTFOUND
; ============================================================================
fs_exec:
  mov r11, r1
  mov r2, s_al_chdir
  call strcmp
  cmp r4, 1
  je fs_cd
  mov r1, r11
  mov r2, s_al_mkdir
  call strcmp
  cmp r4, 1
  je fs_md
  mov r1, r11
  mov r2, s_al_rmdir
  call strcmp
  cmp r4, 1
  je fs_rd
  mov r1, r11
  mov r2, s_al_erase
  call strcmp
  cmp r4, 1
  je fs_del
  mov r1, r11
  mov r2, s_al_rename
  call strcmp
  cmp r4, 1
  je fs_ren
  mov r1, r11            ; strcmp 破坏 r1, 恢复命令名
  jmp fs_go
fs_cd:
  mov r1, s_cd
  jmp fs_go
fs_md:
  mov r1, s_md
  jmp fs_go
fs_rd:
  mov r1, s_rd
  jmp fs_go
fs_del:
  mov r1, s_del
  jmp fs_go
fs_ren:
  mov r1, s_ren
fs_go:
  mov r11, r1
  ; 检查是否含 '/' -> 路径模式(用原始指针, 不截断)
  mov r8, r11
fs_slash:
  load_8 r2, [r8]
  cmp r2, 0
  je fs_bare
  cmp r2, CH_SLASH
  je fs_path
  add r8, r8, 1
  jmp fs_slash

; ---- 路径模式: 组件经 '/' 分隔, 前导 '/' = 从根开始, 否则从 CURDIR ----
; 支持 ".." 与 "."; 最后组件按 原名 / +.MVT / +.SCO 尝试
fs_path:
  mov r13, 0
  mov r5, r11
  load_8 r2, [r5]
  cmp r2, CH_SLASH
  jne fs_path_rel
  add r5, r5, 1
  jmp fs_path_comp
fs_path_rel:
  load_32 r13, [CURDIR]
fs_path_comp:
  mov r9, DIRTMP
  mov r10, 0
fs_path_cp:
  load_8 r2, [r5]
  cmp r2, 0
  je fs_path_last
  cmp r2, CH_SLASH
  je fs_path_sep
  cmp r10, 11
  jae fs_path_cp_next
  store_8 [r9], r2
  add r9, r9, 1
  add r10, r10, 1
fs_path_cp_next:
  add r5, r5, 1
  jmp fs_path_cp
fs_path_sep:
  store_8 [r9], zr
  add r5, r5, 1
  mov r9, DIRTMP
  load_8 r2, [r9]
  cmp r2, CH_DOT
  jne fs_path_dir
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, CH_DOT
  jne fs_path_comp
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0
  jne fs_path_dir
  cmp r13, 0
  je fs_path_comp
  lsl r7, r13, 5
  lsl r3, r13, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_PAROF
  pload r13, [r7]
  jmp fs_path_comp
fs_path_dir:
  mov r1, DIRTMP
  mov r2, r13
  call find_in_parent
  cmp r4, NOTFOUND
  je fs_path_nf
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_DIR
  je fs_path_okd
  cmp r2, T_SCODIR
  je fs_path_okd
  jmp fs_path_nf
fs_path_okd:
  mov r13, r4
  jmp fs_path_comp
fs_path_last:
  store_8 [r9], zr
  cmp r10, 0
  je fs_path_nf
  ; 组件名已在 DIRTMP; 候选 1: 原名
  mov r1, WRITEBUF
  mov r2, DIRTMP
  mov r3, 12
  call strcpy_n
  call fs_try_last
  ; 候选 2: +".MVT"
  mov r1, WRITEBUF
  mov r2, DIRTMP
  mov r3, 8
  call strcpy_n
  mov r8, WRITEBUF
fs_pl_scan:
  load_8 r2, [r8]
  cmp r2, 0
  je fs_pl_mvt
  add r8, r8, 1
  jmp fs_pl_scan
fs_pl_mvt:
  mov r2, CH_DOT
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x4D
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x56
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x54
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0
  store_8 [r8], r2
  call fs_try_last
  ; 候选 3: +".SCO"
  mov r8, WRITEBUF
fs_pl_scan2:
  load_8 r2, [r8]
  cmp r2, 0
  je fs_pl_sco
  add r8, r8, 1
  jmp fs_pl_scan2
fs_pl_sco:
  sub r8, r8, 4
  mov r2, CH_DOT
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x53
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x43
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x4F
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0
  store_8 [r8], r2
  call fs_try_last
  jmp fs_path_nf
fs_path_nf:
  mov r1, S_PATHNF
  call perr
  mov r4, 1
  ret

; r13 = 父目录, WRITEBUF = 候选名; 找到可执行文件则 exec 不返回; 否则返回
fs_try_last:
  mov r1, WRITEBUF
  mov r2, r13
  call find_in_parent
  cmp r4, NOTFOUND
  je fs_tl_ret
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_SCO
  je fs_tl_go
  cmp r2, T_MVT
  je fs_tl_go
  jmp fs_tl_ret
fs_tl_go:
  mov r1, WRITEBUF
  call exec
  cmp r4, NOTFOUND
  je fs_tl_ret
  cmp r4, 0
  je fs_tl_ret
  jmp r4
fs_tl_ret:
  ret

; ---- 裸名模式: SYSTEM -> BIN -> 当前目录; 带后缀直接找, 否则补 .SCO/.MVT ----
fs_bare:
  mov r1, DIRTMP
  mov r2, r11
  mov r3, 12
  call strcpy_n
  mov r1, DIRTMP
  call upper
  mov r1, DIRTMP
  call strlen
  cmp r4, 4
  jb fs_bare_ext
  mov r9, DIRTMP
  add r9, r9, r4
  sub r9, r9, 4
  load_8 r2, [r9]
  cmp r2, CH_DOT
  jne fs_bare_ext
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x4D
  je fs_bare_sfx_m
  cmp r2, 0x53
  jne fs_bare_ext
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x43
  jne fs_bare_ext
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x4F
  je fs_bare_direct
  jmp fs_bare_ext
fs_bare_sfx_m:
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x56
  jne fs_bare_ext
  add r9, r9, 1
  load_8 r2, [r9]
  cmp r2, 0x54
  je fs_bare_direct
  jmp fs_bare_ext
fs_bare_direct:
  mov r1, WRITEBUF
  mov r2, DIRTMP
  mov r3, 12
  call strcpy_n
  call fs_try_all
  jmp fs_nf
fs_bare_ext:
  ; NAME.SCO
  mov r1, WRITEBUF
  mov r2, DIRTMP
  mov r3, 8
  call strcpy_n
  mov r8, WRITEBUF
fs_be_scan:
  load_8 r2, [r8]
  cmp r2, 0
  je fs_be_sco
  add r8, r8, 1
  jmp fs_be_scan
fs_be_sco:
  mov r2, CH_DOT
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x53
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x43
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x4F
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0
  store_8 [r8], r2
  call fs_try_all
  ; NAME.MVT
  mov r8, WRITEBUF
fs_be_scan2:
  load_8 r2, [r8]
  cmp r2, 0
  je fs_be_mvt
  add r8, r8, 1
  jmp fs_be_scan2
fs_be_mvt:
  sub r8, r8, 4
  mov r2, CH_DOT
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x4D
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x56
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0x54
  store_8 [r8], r2
  add r8, r8, 1
  mov r2, 0
  store_8 [r8], r2
  call fs_try_all
  jmp fs_nf
fs_nf:
  mov r4, 0
  ret

; WRITEBUF = 候选名; 依次 SYSTEM/BIN/CURDIR 查找并执行(成功不返回)
fs_try_all:
  call fs_sysdir
  cmp r13, NOTFOUND
  je fs_ta_bin
  call fs_try_dir
fs_ta_bin:
  call fs_bindir
  cmp r13, NOTFOUND
  je fs_ta_cur
  call fs_try_dir
fs_ta_cur:
  load_32 r13, [CURDIR]
  call fs_try_dir
fs_ta_ret:
  ret

; r13 = 父目录, WRITEBUF = 候选名; 仅 SCO/MVT 可执行
fs_try_dir:
  mov r1, WRITEBUF
  mov r2, r13
  call find_in_parent
  cmp r4, NOTFOUND
  je fs_td_ret
  lsl r7, r4, 5
  lsl r3, r4, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_TYPEOF
  pload r2, [r7]
  cmp r2, T_SCO
  je fs_td_go
  cmp r2, T_MVT
  je fs_td_go
  jmp fs_td_ret
fs_td_go:
  mov r1, WRITEBUF
  call exec
  cmp r4, NOTFOUND
  je fs_td_ret
  cmp r4, 0
  je fs_td_ret
  jmp r4
fs_td_ret:
  ret

; -> r13 = SYSTEM / BIN 目录索引(根下查找)或 NOTFOUND
fs_sysdir:
  mov r1, s_sysname
  mov r2, 0
  call find_in_parent
  mov r13, r4
  ret
fs_bindir:
  mov r1, s_binname
  mov r2, 0
  call find_in_parent
  mov r13, r4
  ret

; ============================================================================
; r1 = 名字, r2 = 父目录 -> r4 = 入口号 或 NOTFOUND(类型不限)
; ============================================================================
find_in_parent:
  store_32 [DIRLINES], r2
  mov r11, r1
  mov r12, 0
find_in_parent_loop:
  cmp r12, FS_N
  jae find_in_parent_nf
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  pload r3, [r7]
  cmp r3, 0
  je find_in_parent_next
  add r7, r7, FS_PAROF
  pload r1, [r7]
  load_32 r2, [DIRLINES]
  cmp r1, r2
  je jneskipKP1
  jmp find_in_parent_next
jneskipKP1:
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
find_in_parent_copy:
  pload r1, [r7]
  store_32 [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskipKP2
  jmp find_in_parent_copy
jneskipKP2:
  store_8 [r8], zr
  mov r1, r11
  mov r2, NAMETMP
  call strcmp
  cmp r4, 1
  je find_in_parent_found
find_in_parent_next:
  add r12, r12, 1
  jmp find_in_parent_loop
find_in_parent_nf:
  mov r4, NOTFOUND
  ret
find_in_parent_found:
  mov r4, r12
  ret

; ============================================================================
; 跳转表: 把内核函数地址写成 jmp 指令放入 0x23A0 起的固定槽
; (程序经 const 直接 call 这些槽)
; ============================================================================
write_jumptab:
  mov r1, find_in_dir
  mov r2, JT_FIND_IN_DIR
  call jt_put
  mov r1, free_entry
  mov r2, JT_FREE_ENTRY
  call jt_put
  mov r1, entry_set_name
  mov r2, JT_ENTRY_SET
  call jt_put
  mov r1, dir_has_child
  mov r2, JT_DIR_CHILD
  call jt_put
  mov r1, env_find
  mov r2, JT_ENV_FIND
  call jt_put
  mov r1, env_set
  mov r2, JT_ENV_SET
  call jt_put
  mov r1, perr
  mov r2, JT_PERR
  call jt_put
  mov r1, reboot_entry
  mov r2, JT_REBOOT
  call jt_put
  ret
jt_put:
  mov r3, 0x580F
  lsl r3, r3, 16
  or r1, r3, r1
  store_32 [r2], r1
  ret

; ============================================================================
; 重启: 释放当前程序块, 复位栈, 重入内核 main
; ============================================================================
; 重启到 boot: 清内存/寄存器后完整重走 BIOS 流程(boot 导出, 不返回)
reboot_entry:
  jmp hard_reset

; ============================================================================
; 环境变量
; ============================================================================
; r1 = 名字 -> r4 = 槽(0..3) 或 NOTFOUND
env_find:
  mov r11, r1
  mov r1, r11
  call upper
  mov r12, 0
env_find_loop:
  lsl r3, r12, 4
  lsl r5, r12, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  mov r1, r11
  mov r2, r3
  call strcmp
  cmp r4, 1
  je env_find_got
  add r12, r12, 1
  cmp r12, ENV_N
  je jneskipK1
  jmp env_find_loop
jneskipK1:
  mov r4, NOTFOUND
  ret
env_find_got:
  mov r4, r12
  ret

; r1 = 名字, r2 = 值 -> r4 = 槽 或 NOTFOUND(表满)
env_set:
  mov r10, r1
  mov r13, r2
  mov r1, r10
  call upper
  call env_find
  cmp r4, NOTFOUND
  je jneskipK2
  jmp env_set_have
jneskipK2:
  mov r12, 0
env_set_free:
  lsl r3, r12, 4
  lsl r5, r12, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  load_8 r2, [r3]
  cmp r2, 0
  je env_set_free2
  add r12, r12, 1
  cmp r12, ENV_N
  je jneskipK3
  jmp env_set_free
jneskipK3:
  mov r4, NOTFOUND
  ret
env_set_free2:
  mov r4, r12
env_set_have:
  mov r7, r4
  lsl r3, r7, 4
  lsl r5, r7, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  mov r8, r3
  mov r12, 6
  mov r2, 0
env_set_z:
  store_32 [r8], r2
  add r8, r8, WORD
  sub r12, r12, 1
  cmp r12, 0
  je jneskipK4
  jmp env_set_z
jneskipK4:
  lsl r3, r7, 4
  lsl r5, r7, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  mov r1, r3
  mov r2, r10
  mov r3, 7
  call strcpy_n
  lsl r3, r7, 4
  lsl r5, r7, 3
  add r3, r3, r5
  add r3, r3, ENVBASE
  add r3, r3, 8
  mov r1, r3
  mov r2, r13
  mov r3, 15
  call strcpy_n
  mov r4, r7
  ret

; ============================================================================
; 文件系统 = 外存磁盘表(头部 32B + 64 表项 x40B; 代码区 ..0x7FFF)
; 表项: +0 名字 12B, +12 类型, +16 大小, +20 入口, +24 代码偏移,
;       +28 重定位数, +32 重定位表偏移, +36 父目录
; 增删改查全部落在外存(经 pload/pstore), REBOOT 后仍然存在。
; ============================================================================

; r1 = 名字 -> r4 = 当前目录下入口号 或 NOTFOUND
find_in_dir:
  mov r11, r1
  mov r1, WRITEBUF
  mov r2, r11
  mov r3, 12
  call strcpy_n
  mov r1, WRITEBUF
  call upper
  mov r11, WRITEBUF
  mov r12, 0
find_in_dir_loop:
  cmp r12, FS_N
  jae find_in_dir_nf
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  pload r3, [r7]           ; 名字首字: 0 = 空闲项
  cmp r3, 0
  je find_in_dir_next
  add r7, r7, FS_PAROF
  pload r1, [r7]           ; 父目录
  load_32 r2, [CURDIR]
  cmp r1, r2
  je jneskipK6
  jmp find_in_dir_next
jneskipK6:
  lsl r7, r12, 5
  lsl r3, r12, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
find_in_dir_copy:
  pload r1, [r7]
  store_32 [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskipK7
  jmp find_in_dir_copy
jneskipK7:
  store_8 [r8], zr
  mov r1, r11
  mov r2, NAMETMP
  call strcmp
  cmp r4, 1
  je find_in_dir_found
find_in_dir_next:
  add r12, r12, 1
  jmp find_in_dir_loop
find_in_dir_nf:
  mov r4, NOTFOUND
  ret
find_in_dir_found:
  mov r4, r12
  ret

; -> r4 = 空闲入口号 或 NOTFOUND
free_entry:
  mov r8, 0
free_entry_loop:
  cmp r8, FS_N
  jae jneskipK9
  lsl r7, r8, 5
  lsl r3, r8, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  pload r1, [r7]
  cmp r1, 0
  je free_entry_got
  add r8, r8, 1
  jmp free_entry_loop
jneskipK9:
  mov r4, NOTFOUND
  ret
free_entry_got:
  mov r4, r8
  ret

; r7 = 入口基址, r1 = 名字; 写入名字字段(最多 11 字符 + NUL = 12B)
; 返回时 r7 恢复为入口基址(程序随后自行 add FS_TYPEOF 定位类型字段)
entry_set_name:
  mov r11, r7
  mov r5, r7
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
  mov r2, 0
entry_set_name_z:
  store_32 [r8], r2
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskipK10
  jmp entry_set_name_z
jneskipK10:
  mov r2, r1
  mov r1, NAMETMP
  mov r3, 11
  call strcpy_n
  mov r1, NAMETMP
  call upper
  mov r7, r5
  mov r8, NAMETMP
  mov r9, FS_NAME_WORDS
entry_set_name_c:
  load_32 r1, [r8]
  pstore [r7], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je jneskipK11
  jmp entry_set_name_c
jneskipK11:
  mov r7, r5
  ret

; r1 = 入口号 -> r4 = 1(有子项)/0
dir_has_child:
  mov r8, r1
  mov r9, 0
dir_has_child_loop:
  cmp r9, FS_N
  jae dir_has_child_no
  lsl r7, r9, 5
  lsl r3, r9, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  pload r3, [r7]
  cmp r3, 0
  je dir_has_child_next
  add r7, r7, FS_PAROF
  pload r2, [r7]
  cmp r2, r8
  je dir_has_child_yes
dir_has_child_next:
  add r9, r9, 1
  jmp dir_has_child_loop
dir_has_child_no:
  mov r4, 0
  ret
dir_has_child_yes:
  mov r4, 1
  ret

; ============================================================================
; 错误输出(红), 返回调用者(程序随后 jmp exit_proc 回 shell)
; ============================================================================
perr:
  mov r8, r1
  mov r1, CLR_RED
  call set_fg
  mov r1, r8
  call print_str
  mov r1, CLR_WHITE
  call set_fg
  call print_nl
  ret

; ============================================================================
; 初始化
; ============================================================================
init_vars:
  mov r2, 0
  store_32 [CURDIR], r2
  store_32 [DIRLINES], r2
  mov r1, ks_home
  call find_in_dir
  cmp r4, NOTFOUND
  je init_vars_fg
  store_32 [CURDIR], r4
init_vars_fg:
  mov r2, CLR_WHITE
  store_32 [CURFG], r2
  mov r8, DATEVAR
  mov r9, ks_defdate
  mov r10, 8
init_vars_d:
  load_8 r2, [r9]
  store_8 [r8], r2
  add r8, r8, 1
  add r9, r9, 1
  sub r10, r10, 1
  cmp r10, 0
  je init_vars_dd
  jmp init_vars_d
init_vars_dd:
  mov r8, ENVBASE
  mov r9, 24
  mov r2, 0
init_vars_e:
  store_32 [r8], r2
  add r8, r8, WORD
  sub r9, r9, 1
  cmp r9, 0
  je init_vars_done
  jmp init_vars_e
init_vars_done:
  ret

; 内核固定地址字符串(程序经 const 引用)
init_strings:
  mov r1, S_UNKNOWN
  mov r2, ks_unknown
  mov r3, 17
  call strcpy_n
  mov r1, S_SYNTAX
  mov r2, ks_syntax
  mov r3, 14
  call strcpy_n
  mov r1, S_NF
  mov r2, ks_nf
  mov r3, 16
  call strcpy_n
  mov r1, S_EXIST
  mov r2, ks_exist
  mov r3, 13
  call strcpy_n
  mov r1, S_FULL
  mov r2, ks_full
  mov r3, 11
  call strcpy_n
  mov r1, S_DELOK
  mov r2, ks_delok
  mov r3, 9
  call strcpy_n
  mov r1, S_SAVED
  mov r2, ks_saved
  mov r3, 7
  call strcpy_n
  mov r1, S_CREATED
  mov r2, ks_created
  mov r3, 9
  call strcpy_n
  mov r1, S_NOTDIR
  mov r2, ks_notdir
  mov r3, 17
  call strcpy_n
  mov r1, S_NOTFILE
  mov r2, ks_notfile
  mov r3, 12
  call strcpy_n
  mov r1, S_PATHNF
  mov r2, ks_pathnf
  mov r3, 16
  call strcpy_n
  mov r1, S_NOCOPY
  mov r2, ks_nocopy
  mov r3, 13
  call strcpy_n
  mov r1, S_PROMPTNAME
  mov r2, ks_promptname
  mov r3, 7
  call strcpy_n
  mov r1, S_PATHNAME
  mov r2, ks_pathname
  mov r3, 5
  call strcpy_n
  ret

; ============================================================================
; 横幅: 标题 + 随机名言 + 作者
; ============================================================================
show_banner:
  mov r1, s_title
  call print_str
  call print_nl
  mov r1, SCR_W
  mov r2, CH_EQ
  call print_fill
  time_0 r1
  and r1, r1, HEX_NIB
  cmp r1, Q_COUNT
  jb banner_q
  sub r1, r1, Q_COUNT
banner_q:
  lsl r2, r1, 3
  add r2, r2, qt
  mov r12, r2
  load_32 r1, [r2]
  call print_str
  call print_nl
  add r12, r12, WORD
  load_32 r1, [r12]
  mov r12, r1
  call strlen
  mov r5, r4
  add r5, r5, 3
  mov r1, SCR_W
  sub r1, r1, r5
  call print_spaces
  mov r1, s_dash
  call print_str
  mov r1, r12
  call print_str
  mov r1, SCR_W
  mov r2, CH_EQ
  call print_fill
  ret

; ============================================================================
; 当前目录路径: ~/dir1/dir2(CURDIR 沿父链收集到 WRITEBUF, 反向输出)
; ============================================================================
print_path:
  mov r11, WRITEBUF
  mov r12, 0
  load_32 r9, [CURDIR]
print_path_collect:
  cmp r9, 0
  je print_path_emit
  store_32 [r11], r9
  add r11, r11, WORD
  add r12, r12, 1
  lsl r7, r9, 5
  lsl r3, r9, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  add r7, r7, FS_PAROF
  pload r9, [r7]
  jmp print_path_collect
print_path_emit:
  cmp r12, 0
  je print_path_ret
  sub r11, r11, WORD
  load_32 r9, [r11]
  mov r1, CH_SLASH
  call print_char
  lsl r7, r9, 5
  lsl r3, r9, 3
  add r7, r7, r3
  add r7, r7, DISK_TABLE
  mov r8, NAMETMP
  mov r10, FS_NAME_WORDS
print_path_copy:
  pload r1, [r7]
  store_32 [r8], r1
  add r7, r7, WORD
  add r8, r8, WORD
  sub r10, r10, 1
  cmp r10, 0
  je jneskipK13
  jmp print_path_copy
jneskipK13:
  mov r8, NAMETMP
  mov r10, 16
print_path_pstr:
  load_8 r1, [r8]
  cmp r1, 0
  je jneskipK14
  call print_char
  add r8, r8, 1
  sub r10, r10, 1
  cmp r10, 0
  je jneskipK14
  jmp print_path_pstr
jneskipK14:
  sub r12, r12, 1
  cmp r12, 0
  je print_path_ret
  jmp print_path_emit
print_path_ret:
  ret

; ============================================================================
; 内核字符串(可重定位)
; ============================================================================
s_title:
data8 "Sonata DOS v3.0"
s_defprompt:
data8 "[Sonata] ~"
s_dash:
data8 "-- "
s_cd:
data8 "CD"
s_md:
data8 "MD"
s_rd:
data8 "RD"
s_del:
data8 "DEL"
s_ren:
data8 "REN"
s_al_chdir:
data8 "CHDIR"
s_al_mkdir:
data8 "MKDIR"
s_al_rmdir:
data8 "RMDIR"
s_al_erase:
data8 "ERASE"
s_al_rename:
data8 "RENAME"
ks_unknown:
data8 "Unknown command."
ks_syntax:
data8 "Syntax error."
ks_nf:
data8 "File not found."
ks_exist:
data8 "File exists."
ks_full:
data8 "Disk full."
ks_delok:
data8 "Deleted."
ks_saved:
data8 "Saved."
ks_created:
data8 "Created."
ks_notdir:
data8 "Not a directory."
ks_notfile:
data8 "Not a file."
ks_pathnf:
data8 "Path not found."
ks_nocopy:
data8 "Cannot copy."
ks_promptname:
data8 "PROMPT"
ks_pathname:
data8 "PATH"
ks_defdate:
data8 "20240101"
ks_home:
data8 "HOME"
s_sysname:
data8 "SYSTEM"
s_binname:
data8 "BIN"
; ---- 名言表(10 条, 标题+作者指针) ----
qt:
data32 q_t0
data32 q_a0
data32 q_t1
data32 q_a1
data32 q_t2
data32 q_a2
data32 q_t3
data32 q_a3
data32 q_t4
data32 q_a4
data32 q_t5
data32 q_a5
data32 q_t6
data32 q_a6
data32 q_t7
data32 q_a7
data32 q_t8
data32 q_a8
data32 q_t9
data32 q_a9

q_t0:
data8 "Talk is cheap. Show me the code."
q_a0:
data8 "Linus Torvalds"
q_t1:
data8 "Stay hungry, stay foolish."
q_a1:
data8 "Steve Jobs"
q_t2:
data8 "Simplicity is the ultimate sophistication."
q_a2:
data8 "Leonardo da Vinci"
q_t3:
data8 "Any sufficiently advanced technology is indistinguishable from magic."
q_a3:
data8 "Arthur C. Clarke"
q_t4:
data8 "Programs must be written for people to read, and only incidentally for machines to execute."
q_a4:
data8 "Harold Abelson"
q_t5:
data8 "Premature optimization is the root of all evil."
q_a5:
data8 "Donald Knuth"
q_t6:
data8 "The best way to predict the future is to invent it."
q_a6:
data8 "Alan Kay"
q_t7:
data8 "Code is like humor. When you have to explain it, it is bad."
q_a7:
data8 "Cory House"
q_t8:
data8 "Make it work, make it right, make it fast."
q_a8:
data8 "Kent Beck"
q_t9:
data8 "First, solve the problem. Then, write the code."
q_a9:
data8 "John Johnson"


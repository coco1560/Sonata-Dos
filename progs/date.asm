; ==================================================
; 程序: date(Sonata DOS 磁盘程序)
; @name: date
; @data: 96
; 无参数: 读完整 64 位时间戳(先 time_0 再 time_1, 同一时刻的高低两半)
;         换算并显示:
;           Stamp: 高32 低32       (原始十六进制)
;           Date:  YYYY-MM-DD     (epoch = 1970-01-01)
;           Time:  HH:MM:SS
;         游戏时间戳 = Unix 纳秒(1970-01-01 起, 1e9/秒; 由 stamp 反推校准)
; 有参数: DATE YYYYMMDD 设置日期(旧行为, 写入 DATEVAR)
; 结束 jmp shell_resume
; ==================================================

const RATE_HI = 0x3B9A
const RATE_LO = 0xCA00       ; RATE = 1,000,000,000(游戏 time_0/time_1 = Unix 纳秒)
const TZ_OFFSET = 28800      ; 时区偏移秒(UTC+8 = 北京时间; 其它时区改这里)

; 数据区(D_* 偏移, 转换器生成标签)
const D_date_S_DATEPRE  = 0x0
const D_date_S_TIMEPRE  = 0x10
const D_date_S_STAMPPRE = 0x20
const D_date_S_DATEBAD  = 0x30
const D_date_S_DATESET  = 0x40
const D_date_TMP        = 0x50   ; 4 个 32 位临时: days/h/m/s

main:
  call date_init
  load_32 r8, [ARGC]
  cmp r8, 2
  jae do_date_set
  jmp do_date_show

do_date_show:
  time_0 r11               ; 先读低 32 位(游戏在此锁存同一时刻)
  time_1 r12               ; 再读高 32 位(同一个时间戳)

  ; ---- Stamp: 高32 低32 ----
  mov r1, D_date_S_STAMPPRE
  call print_str
  mov r1, r12
  call print_hex
  mov r1, CH_SPACE
  call print_char
  mov r1, r11
  call print_hex
  call print_nl

  ; ---- 秒 = (r12:r11) / RATE ----
  mov r5, RATE_HI
  lsl r5, r5, 16
  mov r7, RATE_LO
  or r5, r5, r7
  call div64               ; r3 = 秒
  add r3, r3, TZ_OFFSET     ; 加时区偏移(UTC+8)
  ; ---- days / h / m / s ----
  mov r9, r3
  mov r5, 0x1
  lsl r5, r5, 16
  mov r7, 0x5180
  or r5, r5, r7            ; r5 = 86400
  call div32               ; r3 = days, r4 = rem
  mov r8, D_date_TMP
  store_32 [r8], r3
  mov r9, r4
  mov r5, 3600
  call div32               ; r3 = h, r4 = rem
  add r8, r8, 4
  store_32 [r8], r3
  mov r9, r4
  mov r5, 60
  call div32               ; r3 = m, r4 = s
  add r8, r8, 4
  store_32 [r8], r3
  add r8, r8, 4
  store_32 [r8], r4

  ; ---- 天数 -> y/m/d(r11/r12/r13) ----
  mov r8, D_date_TMP
  load_32 r9, [r8]
  call civil

  ; ---- 打印 Date: YYYY-MM-DD ----
  mov r1, D_date_S_DATEPRE
  call print_str
  mov r1, r11
  mov r2, 4
  call print_dec
  mov r1, CH_MINUS
  call print_char
  mov r1, r12
  mov r2, 2
  call print_dec
  mov r1, CH_MINUS
  call print_char
  mov r1, r13
  mov r2, 2
  call print_dec
  call print_nl

  ; ---- 打印 Time: HH:MM:SS ----
  mov r1, D_date_S_TIMEPRE
  call print_str
  mov r8, D_date_TMP
  add r8, r8, 4
  load_32 r1, [r8]
  mov r2, 2
  call print_dec
  mov r1, 0x3A
  call print_char
  add r8, r8, 4
  load_32 r1, [r8]
  mov r2, 2
  call print_dec
  mov r1, 0x3A
  call print_char
  add r8, r8, 4
  load_32 r1, [r8]
  mov r2, 2
  call print_dec
  call print_nl
  jmp shell_resume

; ================= 设置日期(DATE YYYYMMDD) =================
do_date_set:
  load_32 r1, [ARGV1]
  mov r8, r1
  mov r9, 8

do_date_val:
  load_8 r2, [r8]
  cmp r2, CH_0
  jb do_date_bad
  cmp r2, CH_9
  jbe do_date_v1
  jmp do_date_bad
do_date_v1:
  add r8, r8, 1
  sub r9, r9, 1
  cmp r9, 0
  je do_date_v2
  jmp do_date_val
do_date_v2:
  load_8 r2, [r8]
  cmp r2, 0
  je do_date_v3
  jmp do_date_bad
do_date_v3:
  mov r8, DATEVAR
  mov r9, r1
  mov r10, 8

do_date_cp:
  load_8 r2, [r9]
  store_8 [r8], r2
  add r8, r8, 1
  add r9, r9, 1
  sub r10, r10, 1
  cmp r10, 0
  je do_date_v4
  jmp do_date_cp
do_date_v4:
  mov r1, D_date_S_DATESET
  call print_str
  call print_nl
  jmp shell_resume

do_date_bad:
  mov r1, D_date_S_DATEBAD
  jmp perr

; ================= 数据初始化(构建字符串) =================
date_init:
  ; ---- D_date_S_DATEPRE: "Date: " ----
  mov r3, D_date_S_DATEPRE
  mov r2, 0x4461
  lsl r2, r2, 16
  mov r11, 0x7465
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x3A20
  lsl r2, r2, 16
  store_32 [r3], r2
  ; ---- D_date_S_TIMEPRE: "Time: " ----
  mov r3, D_date_S_TIMEPRE
  mov r2, 0x5469
  lsl r2, r2, 16
  mov r11, 0x6D65
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x3A20
  lsl r2, r2, 16
  store_32 [r3], r2
  ; ---- D_date_S_STAMPPRE: "Stamp: " ----
  mov r3, D_date_S_STAMPPRE
  mov r2, 0x5374
  lsl r2, r2, 16
  mov r11, 0x616D
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x703A
  lsl r2, r2, 16
  mov r11, 0x2000
  or r2, r2, r11
  store_32 [r3], r2
  ; ---- D_date_S_DATEBAD: "Invalid date." ----
  mov r3, D_date_S_DATEBAD
  mov r2, 0x496E
  lsl r2, r2, 16
  mov r11, 0x7661
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6C69
  lsl r2, r2, 16
  mov r11, 0x6420
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x6461
  lsl r2, r2, 16
  mov r11, 0x7465
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x2E00
  lsl r2, r2, 16
  store_32 [r3], r2
  ; ---- D_date_S_DATESET: "Date set." ----
  mov r3, D_date_S_DATESET
  mov r2, 0x4461
  lsl r2, r2, 16
  mov r11, 0x7465
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x2073
  lsl r2, r2, 16
  mov r11, 0x6574
  or r2, r2, r11
  store_32 [r3], r2
  add r3, r3, 4
  mov r2, 0x002E
  store_8 [r3], r2
  add r3, r3, 1
  lsr r2, r2, 8
  store_8 [r3], r2
  add r3, r3, 1
  ret

; ================= 64位除以32位 =================
; (r12:r11) / r5 -> 商 r3, 余数 r4(假设商 < 2^32; 除数为正且 < 2^31)
; 破坏 r3/r4/r6/r7/r8/r11/r12
div64:
  mov r3, 0
  mov r4, 0
  mov r6, 64
div64_loop:
  lsl r3, r3, 1
  lsr r7, r11, 31
  lsl r11, r11, 1
  lsr r8, r12, 31
  lsl r12, r12, 1
  or r12, r12, r7
  lsr r7, r4, 31
  lsl r4, r4, 1
  or r4, r4, r8
  cmp r4, r5
  jb div64_skip
  sub r4, r4, r5
  or r3, r3, 1
div64_skip:
  sub r6, r6, 1
  cmp r6, 0
  jne div64_loop
  ret

; ================= 32位除以32位 =================
; r9 / r5 -> 商 r3, 余数 r4(除数 < 2^31)
; 破坏 r3/r4/r6/r7/r9
div32:
  mov r4, 0
  mov r3, 0
  mov r6, 32
div32_loop:
  lsl r3, r3, 1
  lsl r4, r4, 1
  lsr r7, r9, 31
  or r4, r4, r7
  lsl r9, r9, 1
  cmp r4, r5
  jb div32_skip
  sub r4, r4, r5
  or r3, r3, 1
div32_skip:
  sub r6, r6, 1
  cmp r6, 0
  jne div32_loop
  ret

; ================= 天数 -> 年/月/日(Howard Hinnant) =================
; 输入 r9 = days(自 1970-01-01); 输出 r11 = 年, r12 = 月(1-12), r13 = 日
civil:
  mov r8, 0xA
  lsl r8, r8, 16
  add r9, r9, r8
  mov r8, 0xFA6C
  add r9, r9, r8           ; r9 += 719468(0xAFA6C)
  mov r5, 0x2
  lsl r5, r5, 16
  mov r7, 0x3AB1
  or r5, r5, r7            ; r5 = 146097
  call div32               ; r3 = era, r4 = doe
  mov r11, r3              ; era
  mov r10, r4              ; doe 备份
  ; yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365
  mov r9, r4
  mov r5, 1460
  call div32               ; r3 = doe/1460
  mov r8, r3
  mov r9, r10
  mov r5, 36524
  call div32               ; r3 = doe/36524
  sub r8, r8, r3
  mov r9, r10
  mov r5, 0x2
  lsl r5, r5, 16
  mov r7, 0x3AB0
  or r5, r5, r7            ; r5 = 146096
  call div32               ; r3 = doe/146096
  add r8, r8, r3
  mov r9, r10
  sub r9, r9, r8
  mov r5, 365
  call div32               ; r3 = yoe
  mov r12, r3              ; yoe
  ; y = yoe + era*400(400 = 256+128+16)
  mov r8, r11
  lsl r9, r8, 8
  lsl r7, r8, 7
  add r9, r9, r7
  lsl r7, r8, 4
  add r9, r9, r7
  add r11, r12, r9
  ; doy = doe - (365*yoe + yoe/4 - yoe/100); 365 = 256+64+32+8+4+1
  mov r8, r12
  lsl r9, r8, 8
  lsl r7, r8, 6
  add r9, r9, r7
  lsl r7, r8, 5
  add r9, r9, r7
  lsl r7, r8, 3
  add r9, r9, r7
  lsl r7, r8, 2
  add r9, r9, r7
  add r9, r9, r8
  lsr r7, r8, 2
  add r9, r9, r7
  mov r7, 0
civil_y100:
  cmp r8, 100
  jb civil_y100_done
  sub r8, r8, 100
  add r7, r7, 1
  jmp civil_y100
civil_y100_done:
  sub r9, r9, r7
  mov r8, r10
  sub r8, r8, r9           ; doy
  ; mp = (5*doy + 2) / 153
  lsl r9, r8, 2
  add r9, r9, r8
  add r9, r9, 2
  mov r5, 153
  call div32               ; r3 = mp
  mov r12, r3
  ; d = doy - (153*mp + 2)/5 + 1; 153 = 128+16+8+1
  mov r9, r3
  lsl r7, r9, 7
  lsl r6, r9, 4
  add r7, r7, r6
  lsl r6, r9, 3
  add r7, r7, r6
  add r7, r7, r9
  add r7, r7, 2
  mov r9, r7
  mov r5, 5
  call div32               ; r3 = (153mp+2)/5
  mov r13, r8
  sub r13, r13, r3
  add r13, r13, 1          ; d
  ; m = mp + (mp < 10 ? 3 : -9); 1/2 月时年 +1
  cmp r12, 10
  jae civil_m_ge10
  add r12, r12, 3
  jmp civil_ret
civil_m_ge10:
  sub r12, r12, 9
  add r11, r11, 1
civil_ret:
  ret

; ================= 十进制打印(零填充) =================
; r1 = 值(<10000), r2 = 位数(2..4); 不动 r8/r11/r12/r13(调用方可能用 r8 作指针)
print_dec:
  mov r10, r1
  mov r9, r2
  mov r1, 0xFFFF
  push r1                  ; 哨兵
pd_digits:
  mov r3, 0
pd_div:
  cmp r10, 10
  jb pd_div_done
  sub r10, r10, 10
  add r3, r3, 1
  jmp pd_div
pd_div_done:
  push r10
  mov r10, r3
  sub r9, r9, 1
  cmp r9, 0
  jne pd_digits
pd_print:
  pop r1
  cmp r1, 0xFFFF
  je pd_done
  mov r2, 0x30
  add r1, r1, r2
  call print_char
  jmp pd_print
pd_done:
  ret

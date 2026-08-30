; ============================================================================
; TIMECAL — time_0 速率标定(独立程序, 像 keytest 一样直接贴进游戏汇编器运行)
; 用途: 测出游戏里 time_0 每秒增长多少刻度, 给贪吃蛇精确设定 FPS。
; 操作:
;   1) 运行后按任意键 -> 记录此刻 time_0
;   2) 默数 10 秒 -> 再按任意键 -> 记录第二次 time_0
;   3) 屏幕(十六进制):
;        第 1 行 t0=  第一次 time_0
;        第 2 行 t1=  第二次 time_0
;        第 3 行 dt=  两次差值(10 秒内的刻度增量)  <- 把这个数报出来
;        第 4 行 id=  约 78.6 万条指令的 time_0 增量(参考)
;   4) 换算: 每秒刻度 = dt / 10; TICK(4 格/秒) = 每秒刻度 / 4
; ============================================================================
const SCRBASE = 0x3000

main:
    mov sp, 0x7000
    mov r1, 0
    mov r2, 1
    screen r1, r2
    mov r1, 1
    mov r2, SCRBASE
    screen r1, r2

    call clear_screen

    ; ---- 第一次按键 -> t0(r12) ----
    call wait_press
    time_0 r12

    mov r8, 0
    mov r1, 0x74
    call print_char
    mov r1, 0x30
    call print_char
    mov r1, 0x3D
    call print_char
    mov r1, r12
    call print_hex8

    ; ---- 默数 10 秒, 再按任意键 -> t1(r13) ----
    call wait_press
    time_0 r13

    mov r8, 96
    mov r1, 0x74
    call print_char
    mov r1, 0x31
    call print_char
    mov r1, 0x3D
    call print_char
    mov r1, r13
    call print_hex8

    ; ---- dt = t1 - t0 ----
    mov r8, 192
    mov r1, 0x64
    call print_char
    mov r1, 0x74
    call print_char
    mov r1, 0x3D
    call print_char
    mov r1, r13
    sub r1, r1, r12
    call print_hex8

    ; ---- 指令速率参考: 16 x 16384 次 x 3 条 ≈ 78.6 万条指令 ----
    time_0 r12
    mov r10, 16
tc_outer:
    mov r9, 16384
tc_inner:
    sub r9, r9, 1
    cmp r9, 0
    jne tc_inner
    sub r10, r10, 1
    cmp r10, 0
    jne tc_outer
    time_0 r11

    mov r8, 288
    mov r1, 0x69
    call print_char
    mov r1, 0x64
    call print_char
    mov r1, 0x3D
    call print_char
    mov r1, r11
    sub r1, r1, r12
    call print_hex8

tc_done:
    jmp tc_done

; ---- 等待一次按键按下(忽略弹起), 并等按键完全放开 ----
wait_press:
    keyboard r1
    cmp r1, 0
    je wait_press
    mov r2, r1
    and r2, r2, 0x100
    cmp r2, 0
    jne wait_press          ; 弹起事件, 继续等
wait_press_up:
    keyboard r1
    cmp r1, 0
    jne wait_press_up       ; 等按键状态归零
    ret

; ---- 清屏(96x40, 每格 4 字节) ----
clear_screen:
    mov r6, 0
tc_cls_y:
    cmp r6, 40
    jae tc_cls_done
    mov r7, 0
tc_cls_x:
    cmp r7, 96
    jae tc_cls_ny
    lsl r4, r6, 6
    lsl r5, r6, 5
    add r4, r4, r5
    add r4, r4, r7
    lsl r4, r4, 2
    add r4, r4, SCRBASE
    mov r3, 0
    store_8 [r4], r3
    add r5, r4, 1
    store_8 [r5], r3
    add r5, r4, 2
    store_8 [r5], r3
    add r5, r4, 3
    store_8 [r5], r3
    add r7, r7, 1
    jmp tc_cls_x
tc_cls_ny:
    add r6, r6, 1
    jmp tc_cls_y
tc_cls_done:
    ret

; ---- 打印字符(r8 = 光标格偏移) ----
print_char:
    lsl r3, r8, 2
    add r3, r3, SCRBASE
    store_8 [r3], r1
    add r3, r3, 1
    mov r1, 0xFF
    store_8 [r3], r1
    add r3, r3, 1
    mov r1, 0
    store_8 [r3], r1
    add r8, r8, 1
    ret

; ---- 打印 8 位十六进制(r1 = 值; r8 = 光标) ----
print_hex8:
    mov r2, 8
    call print_hex_n
    ret

; ---- r1 = 值, r2 = 位数(1..8); 破坏 r9/r10/r11 ----
print_hex_n:
    mov r10, r1
    mov r11, r2
    sub r9, r2, 1
    lsl r9, r9, 2
phn_loop:
    mov r2, r10
    lsr r2, r2, r9
    and r2, r2, 0xF
    mov r1, 0x30
    add r1, r1, r2
    cmp r1, 0x39
    jbe phn_ok
    add r1, r1, 7
phn_ok:
    call print_char
    sub r9, r9, 4
    sub r11, r11, 1
    cmp r11, 0
    je phn_done
    jmp phn_loop
phn_done:
    ret

; =====================================================================
; SNAKE.MVT — 贪吃蛇(DOS 移植版)
; 控制: W/A/S/D 方向(大小写均可), Esc(键码 14)退出回 DOS
; AUTO_MODE = 1 -> 自动; 0 -> 手动(默认)
; 修复: 1) 只响应按下事件(原代码把弹起当按键)
;       2) 字母大小写规范化(原代码只认小写)
;       3) 闪屏: 增量重绘 + 双缓冲 —— 全部画到后备缓冲 BB(0xB000),
;          每帧画完后线性整块拷到可见屏幕(3072 字); 屏幕只在这段拷贝中更新,
;          中间态 = 几乎相同的新旧帧, 游戏渲染器采样不到"空洞/重影"等错误帧
;       4) 速度: 自校准指令等待 —— 启动时空转 32 万次测 time_0 速率, 反算
;          每帧等待次数, 使每帧 ≈ 0.125 秒真实时间(8 格/秒), 任何时钟频率下
;          表现一致; 等待本身是指令计数, 时钟波动不会造成冲刺
;       5) 穿墙回绕(不再撞墙死亡); 撞到自己时显示 GAME OVER 并等任意键回 DOS
; 移植: FB 0x4000->0x3000(屏幕固定地址); 数据区 0x1000->0x2400(避开 boot);
;       栈 0x8000->STACKTOP 0x7000(避开加载区); Esc/撞墙 -> cls + exit_proc
; =====================================================================
const AUTO_MODE = 0

; 常量
const FB        = 0x3000   ; ASCII32 帧缓冲(DOS 屏幕固定 12288)
; 后备缓冲 bb = 程序末尾的 space 8192(随程序一起加载, 永在蛇自身内存块内, 不受堆碎片影响)
const SEED      = 0x2400
const FOOD_X    = 0x2402
const FOOD_Y    = 0x2403
const SNAKE_LEN = 0x2404
const DIR       = 0x2405
const MODE      = 0x2406
const NEW_X     = 0x2407
const NEW_Y     = 0x2408
const WAIT_CNT  = 0x240C   ; 自校准结果: 每帧等待循环次数(32 位)
const SNAKE_X   = 0x2500
const SNAKE_Y   = 0x2600
const BODY_COLORS = 0x2700

const BOARD_W   = 64
const BOARD_H   = 32

const DIR_UP    = 0
const DIR_RIGHT = 1
const DIR_DOWN  = 2
const DIR_LEFT  = 3

const KEY_W = 0x57
const KEY_A = 0x41
const KEY_S = 0x53
const KEY_D = 0x44
const KEY_ESC = 14         ; Esc 键码(游戏实测)

; 自校准指令等待: 启动时空转 320000 次测 time_0 增量(≈0.96 秒@1MHz),
; 反算每帧等待次数 = (125,000,000ns × 320000) / 增量  -> 任何时钟频率下
; 每帧都 ≈ 0.125 秒真实时间 = 8 格/秒。等待本身是指令计数,
; 模拟时钟波动不会造成冲刺(只会让校准有 ±1% 左右的漂移)。
const CAL_LOOPS_HI = 0x4
const CAL_LOOPS_LO = 0xE200 ; CAL_LOOPS = 320000 = 0x4E200(位 18/15/14/13/9)
const TARGET_HI = 0x0773     ; TARGET>>16(125,000,000ns = 0.125 秒 >> 16 = 1907, 即 8 格/秒)
const CLR_RED = 0xE0          ; GAME OVER 提示色

; =====================================================================
; 主程序
; =====================================================================
main:
    mov sp, STACKTOP

    mov r1, 0
    mov r2, 1
    screen r1, r2

    mov r1, 1
    mov r2, FB
    screen r1, r2

    call clear_screen
    call clear_bb

    time_0 r1
    store_16 [SEED], r1

    mov r1, AUTO_MODE
    store_8 [MODE], r1

    mov r1, 3
    store_8 [SNAKE_LEN], r1
    mov r1, DIR_RIGHT
    store_8 [DIR], r1

    mov r1, 24
    mov r2, SNAKE_X
    store_8 [r2], r1
    mov r1, 16
    mov r2, SNAKE_Y
    store_8 [r2], r1

    mov r1, 23
    mov r2, SNAKE_X
    add r2, r2, 1
    store_8 [r2], r1
    mov r1, 16
    mov r2, SNAKE_Y
    add r2, r2, 1
    store_8 [r2], r1

    mov r1, 22
    mov r2, SNAKE_X
    add r2, r2, 2
    store_8 [r2], r1
    mov r1, 16
    mov r2, SNAKE_Y
    add r2, r2, 2
    store_8 [r2], r1

    call update_gradient
    call spawn_food         ; 选点后直接画食物(后备缓冲)
    call draw_snake         ; 初始蛇(后备缓冲)
    call copy_board         ; 首次上屏
    call calibrate          ; 自校准每帧等待计数(约 1 秒空转)

game_loop:
    call wait_next           ; 等到下一拍(每帧间隔恒为 TICK, 与绘制开销无关)
    call update_direction
    call move_snake          ; move_snake 内部做增量重绘(擦尾 + 重绘蛇身)
    jmp game_loop

; =====================================================================
; 计算字符单元地址
; 输入 r1=x, r2=y; 输出 r4=地址
; =====================================================================
cell_addr:
    lsl r4, r2, 6
    add r4, r4, r1
    add r4, r4, bb
    ret

; 可见帧缓冲格子地址(仅启动清屏用)
cell_addr_fb:
    lsl r4, r2, 6
    lsl r5, r2, 5
    add r4, r4, r5
    add r4, r4, r1
    lsl r4, r4, 2
    add r4, r4, FB
    ret

; =====================================================================
; 清屏(整个 96x40)
; =====================================================================
clear_screen:
    mov r6, 0
clear_screen_y:
    cmp r6, SCR_H
    jae clear_screen_done
    mov r7, 0
clear_screen_x:
    cmp r7, SCR_W
    jae clear_screen_next_y

    mov r1, r7
    mov r2, r6
    call cell_addr_fb

    mov r3, 0x20
    store_8 [r4], r3
    add r5, r4, 1
    mov r3, 0
    store_8 [r5], r3
    add r5, r4, 2
    mov r3, 0
    store_8 [r5], r3
    add r5, r4, 3
    mov r3, 0
    store_8 [r5], r3

    add r7, r7, 1
    jmp clear_screen_x
clear_screen_next_y:
    add r6, r6, 1
    jmp clear_screen_y
clear_screen_done:
    ret

; =====================================================================
; 绘制食物(store_32 一次写入整个格子: [字符][前景][背景][备用])
; =====================================================================
draw_food:
    load_8 r1, [FOOD_X]
    load_8 r2, [FOOD_Y]
    call cell_addr

    mov r3, 0xFF            ; 食物魔法值(拷贝时还原为 *+红前景)
    store_8 [r4], r3
    ret

; =====================================================================
; 绘制蛇(头部黄色, 身体查表渐变; store_32 一次写入整个格子)
; =====================================================================
draw_snake:
    load_8 r7, [SNAKE_LEN]
    mov r8, 0
draw_snake_loop:
    cmp r8, r7
    jae draw_snake_done

    mov r1, SNAKE_X
    add r1, r1, r8
    load_8 r1, [r1]
    mov r2, SNAKE_Y
    add r2, r2, r8
    load_8 r2, [r2]
    call cell_addr

    cmp r8, 0
    je draw_head

    mov r5, BODY_COLORS
    add r5, r5, r8
    sub r5, r5, 1
    load_8 r6, [r5]
    jmp draw_seg

draw_head:
    mov r6, 0xFC

draw_seg:
    store_8 [r4], r6        ; 只存背景色字节(蛇身颜色 ≤ 0xE3, 与 0/0xFF 不冲突)

    add r8, r8, 1
    jmp draw_snake_loop
draw_snake_done:
    ret

; =====================================================================
; 擦除 (r1=x, r2=y) 处的格子(store_32 写空格)
; =====================================================================
erase_cell:
    call cell_addr
    mov r3, 0
    store_8 [r4], r3
    ret

; =====================================================================
; 清空后备缓冲(整 96x40, 启动一次)
; =====================================================================
clear_bb:
    mov r6, 0
clear_bb_loop:
    cmp r6, 512
    jae clear_bb_done
    lsl r7, r6, 2
    add r7, r7, bb
    mov r3, 0
    store_32 [r7], r3
    add r6, r6, 1
    jmp clear_bb_loop
clear_bb_done:
    ret

; =====================================================================
; 后备缓冲(64 宽) -> 可见屏幕(96 宽)板面区域, 逐格映射拷贝
; 可见屏幕只在这段拷贝中更新, 中间态是几乎相同的新旧帧, 不闪
; =====================================================================
copy_board:
    mov r8, 0               ; y
copy_board_y:
    cmp r8, 32
    jae copy_board_done
    mov r9, 0               ; x
copy_board_x:
    cmp r9, 64
    jae copy_board_ny
    lsl r6, r8, 6
    add r6, r6, r9
    add r6, r6, bb          ; src = bb + y*64 + x(每格 1 字节)
    load_8 r1, [r6]
    cmp r1, 0
    je copy_blank
    cmp r1, 0xFF
    je copy_food
    ; 蛇格: 空格 + 背景色
    mov r3, 0x20
    lsl r3, r3, 24
    lsl r5, r1, 8
    or r3, r3, r5
    jmp copy_store
copy_blank:
    mov r3, 0x20
    lsl r3, r3, 24
    jmp copy_store
copy_food:
    mov r3, 42
    lsl r3, r3, 24          ; '*'
    mov r5, 0xE0
    lsl r5, r5, 16          ; 红前景
    or r3, r3, r5
copy_store:
    lsl r7, r8, 6
    lsl r5, r8, 5
    add r7, r7, r5
    add r7, r7, r9
    lsl r7, r7, 2
    add r7, r7, FB          ; dst = FB + (y*96+x)*4
    store_32 [r7], r3
    add r9, r9, 1
    jmp copy_board_x
copy_board_ny:
    add r8, r8, 1
    jmp copy_board_y
copy_board_done:
    ret

; =====================================================================
; 每帧等待(指令计数): 空转 WAIT_CNT 次(启动时按当前时钟自校准)
; 任何时钟频率下每帧 ≈ 0.25 秒; 模拟时钟波动不会造成冲刺。
; =====================================================================
wait_next:
    load_32 r6, [WAIT_CNT]
wait_next_loop:
    sub r6, r6, 1
    cmp r6, 0
    jne wait_next_loop
    ret

; =====================================================================
; 自校准: 空转 CAL_LOOPS 次, 测 time_0 增量 delta,
; 每帧等待次数 = (TARGET × CAL_LOOPS) >> 16 / (delta >> 16)
; 校准结果写入 WAIT_CNT(32 位)。
; =====================================================================
calibrate:
    time_0 r11
    mov r6, CAL_LOOPS_HI
    lsl r6, r6, 16
    mov r7, CAL_LOOPS_LO
    or r6, r6, r7            ; r6 = 320000
cal_loop:
    sub r6, r6, 1
    cmp r6, 0
    jne cal_loop
    time_0 r13
    sub r13, r13, r11        ; delta = time_0 增量
    cmp r13, 0
    jne cal_div
    mov r13, 0x3938
    lsl r13, r13, 16
    mov r7, 0x7000
    or r13, r13, r7          ; 兜底(异常时钟): 960000000 = 按 1MHz 计
cal_div:
    ; P = TARGET_HI × 320000 = 3814 × (2^18+2^15+2^14+2^13+2^9)
    mov r8, 0
    mov r3, TARGET_HI
    mov r2, r3
    lsl r2, r2, 18
    add r8, r8, r2
    mov r2, r3
    lsl r2, r2, 15
    add r8, r8, r2
    mov r2, r3
    lsl r2, r2, 14
    add r8, r8, r2
    mov r2, r3
    lsl r2, r2, 13
    add r8, r8, r2
    mov r2, r3
    lsl r2, r2, 9
    add r8, r8, r2           ; r8 = P ≈ 1.22e9
    lsr r13, r13, 16
    mov r9, r8
    mov r5, r13
    call div32               ; r3 = 每帧等待次数
    mov r8, WAIT_CNT
    store_32 [r8], r3
    ret

; ---- 32位除法: r9 / r5 -> 商 r3, 余 r4(除数 < 2^31) ----
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

; =====================================================================
; 方向更新: 先查 Esc, 手动读键 / 自动寻路
; =====================================================================
update_direction:
    load_8 r2, [MODE]
    cmp r2, 1
    je auto_direction

manual_direction:
    keyboard r1
    cmp r1, 0
    je update_direction_done

    ; 只响应按下事件(bit8=0), 弹起(bit8=1)忽略
    mov r2, r1
    and r2, r2, 0x80
    cmp r2, 0
    jne update_direction_done

    and r1, r1, 0x7F

    cmp r1, KEY_ESC
    je exit_game

    ; 大小写规范化(a-z -> A-Z)
    cmp r1, CH_A
    jb manual_cmp
    cmp r1, CH_Z
    ja manual_cmp
    sub r1, r1, 0x20
manual_cmp:
    cmp r1, KEY_W
    je manual_up
    cmp r1, KEY_A
    je manual_left
    cmp r1, KEY_S
    je manual_down
    cmp r1, KEY_D
    je manual_right
    jmp update_direction_done

manual_up:
    load_8 r3, [DIR]
    cmp r3, DIR_DOWN
    je update_direction_done
    mov r3, DIR_UP
    store_8 [DIR], r3
    jmp update_direction_done

manual_down:
    load_8 r3, [DIR]
    cmp r3, DIR_UP
    je update_direction_done
    mov r3, DIR_DOWN
    store_8 [DIR], r3
    jmp update_direction_done

manual_left:
    load_8 r3, [DIR]
    cmp r3, DIR_RIGHT
    je update_direction_done
    mov r3, DIR_LEFT
    store_8 [DIR], r3
    jmp update_direction_done

manual_right:
    load_8 r3, [DIR]
    cmp r3, DIR_LEFT
    je update_direction_done
    mov r3, DIR_RIGHT
    store_8 [DIR], r3

update_direction_done:
    ret

auto_direction:
    load_8 r1, [SNAKE_X]
    load_8 r2, [SNAKE_Y]
    load_8 r3, [FOOD_X]
    load_8 r4, [FOOD_Y]
    load_8 r5, [DIR]

    cmp r1, r3
    jae auto_try_left
    cmp r5, DIR_LEFT
    je auto_try_left
    mov r5, DIR_RIGHT
    store_8 [DIR], r5
    ret

auto_try_left:
    cmp r1, r3
    jbe auto_try_down
    cmp r5, DIR_RIGHT
    je auto_try_down
    mov r5, DIR_LEFT
    store_8 [DIR], r5
    ret

auto_try_down:
    cmp r2, r4
    jae auto_try_up
    cmp r5, DIR_UP
    je auto_try_up
    mov r5, DIR_DOWN
    store_8 [DIR], r5
    ret

auto_try_up:
    cmp r2, r4
    jbe auto_done
    cmp r5, DIR_DOWN
    je auto_done
    mov r5, DIR_UP
    store_8 [DIR], r5
    ret

auto_done:
    ret

; =====================================================================
; 移动蛇
; =====================================================================
move_snake:
    load_8 r1, [DIR]
    load_8 r2, [SNAKE_X]
    load_8 r3, [SNAKE_Y]

    cmp r1, DIR_UP
    je move_up
    cmp r1, DIR_RIGHT
    je move_right
    cmp r1, DIR_DOWN
    je move_down

    ; left
    sub r4, r2, 1
    mov r5, r3
    jmp move_check

move_up:
    mov r4, r2
    sub r5, r3, 1
    jmp move_check

move_right:
    add r4, r2, 1
    mov r5, r3
    jmp move_check

move_down:
    mov r4, r2
    add r5, r3, 1

move_check:
    ; 穿墙回绕: (x+W) % W, (y+H) % H(最多越界一步, 循环减即可; -1 加 W 后自然回绕)
    add r4, r4, BOARD_W
move_wrap_x:
    cmp r4, BOARD_W
    jb move_wrap_x_done
    sub r4, r4, BOARD_W
    jmp move_wrap_x
move_wrap_x_done:
    add r5, r5, BOARD_H
move_wrap_y:
    cmp r5, BOARD_H
    jb move_wrap_y_done
    sub r5, r5, BOARD_H
    jmp move_wrap_y
move_wrap_y_done:
    store_8 [NEW_X], r4
    store_8 [NEW_Y], r5

    call check_self
    cmp r1, 0
    jne game_over

    load_8 r4, [NEW_X]
    load_8 r5, [NEW_Y]

    load_8 r1, [FOOD_X]
    cmp r1, r4
    jne no_grow

    load_8 r1, [FOOD_Y]
    cmp r1, r5
    jne no_grow

    load_8 r1, [SNAKE_LEN]
    add r1, r1, 1
    store_8 [SNAKE_LEN], r1

    call shift_snake
    call set_head
    call update_gradient
    call draw_snake          ; 渐变更新, 全身重绘(后备缓冲)
    call spawn_food          ; 选点并绘制新食物(蛇头已盖住旧食物格)
    call copy_board          ; 一次性上屏
    ret

no_grow:
    ; 无闪烁顺序: 先记住旧蛇尾位置, 先画完整新帧, 最后才擦尾
    ; (中间态 = 蛇尾多显示一格, 而不是身上出现空洞; 游戏渲染器采样不到空白)
    load_8 r1, [SNAKE_LEN]
    sub r6, r1, 1            ; 尾索引 = len-1
    mov r7, SNAKE_X
    add r7, r7, r6
    load_8 r9, [r7]          ; 旧尾 x
    mov r7, SNAKE_Y
    add r7, r7, r6
    load_8 r10, [r7]         ; 旧尾 y

    call shift_snake
    call set_head
    call draw_snake          ; 新帧完整画出(旧尾暂留, 无空洞)

    mov r1, r9
    mov r2, r10
    call erase_cell          ; 最后一步擦掉旧尾(后备缓冲)
    call copy_board          ; 一次性上屏(可见屏幕无中间态)
    ret

; =====================================================================
; 检查新蛇头是否撞到自己
; =====================================================================
check_self:
    load_8 r1, [NEW_X]
    load_8 r2, [NEW_Y]
    load_8 r3, [SNAKE_LEN]
    mov r4, 1

check_self_loop:
    cmp r4, r3
    jae check_self_ok

    mov r5, SNAKE_X
    add r5, r5, r4
    load_8 r5, [r5]
    cmp r5, r1
    jne check_self_next

    mov r5, SNAKE_Y
    add r5, r5, r4
    load_8 r5, [r5]
    cmp r5, r2
    je check_self_collide

check_self_next:
    add r4, r4, 1
    jmp check_self_loop

check_self_ok:
    mov r1, 0
    ret

check_self_collide:
    mov r1, 1
    ret

; =====================================================================
; 移动身体(从尾到头依次前移)
; =====================================================================
shift_snake:
    load_8 r1, [SNAKE_LEN]
    mov r2, r1
    sub r2, r2, 1

shift_loop:
    cmp r2, 0
    jbe shift_done

    mov r3, SNAKE_X
    add r3, r3, r2
    mov r4, r3
    sub r4, r4, 1
    load_8 r5, [r4]
    store_8 [r3], r5

    mov r3, SNAKE_Y
    add r3, r3, r2
    mov r4, r3
    sub r4, r4, 1
    load_8 r5, [r4]
    store_8 [r3], r5

    sub r2, r2, 1
    jmp shift_loop

shift_done:
    ret

; =====================================================================
; 写入新蛇头
; =====================================================================
set_head:
    load_8 r1, [NEW_X]
    store_8 [SNAKE_X], r1
    load_8 r1, [NEW_Y]
    store_8 [SNAKE_Y], r1
    ret

; =====================================================================
; 随机数(time_0 混合 LCG)
; =====================================================================
random:
    time_0 r3
    load_16 r1, [SEED]
    xor r1, r1, r3
    mov r2, r1
    lsl r3, r1, 2
    add r1, r1, r3
    add r1, r1, 3
    store_16 [SEED], r1
    ret

; =====================================================================
; 随机生成食物
; =====================================================================
spawn_food:
    call random
    mov r2, r1
    and r2, r2, 0x3F
    store_8 [FOOD_X], r2

    call random
    mov r3, r1
    and r3, r3, 0x1F
    store_8 [FOOD_Y], r3

    call food_collides_snake
    cmp r1, 0
    jne spawn_food
    call draw_food
    ret

; =====================================================================
; 检查食物是否和蛇重叠
; =====================================================================
food_collides_snake:
    load_8 r1, [FOOD_X]
    load_8 r2, [FOOD_Y]
    load_8 r3, [SNAKE_LEN]
    mov r4, 0

food_coll_loop:
    cmp r4, r3
    jae food_no_collide

    mov r5, SNAKE_X
    add r5, r5, r4
    load_8 r5, [r5]
    cmp r5, r1
    jne food_coll_next

    mov r5, SNAKE_Y
    add r5, r5, r4
    load_8 r5, [r5]
    cmp r5, r2
    je food_collide

food_coll_next:
    add r4, r4, 1
    jmp food_coll_loop

food_collide:
    mov r1, 1
    ret

food_no_collide:
    mov r1, 0
    ret

; =====================================================================
; 更新身体渐变颜色表(从头部后第一节到尾部线性插值)
; =====================================================================
update_gradient:
    load_8 r1, [SNAKE_LEN]
    sub r2, r1, 1
    cmp r2, 1
    je update_single

    sub r3, r2, 1
    mov r6, 0

update_grad_loop:
    cmp r6, r2
    jae update_grad_done

    mov r7, r6
    lsl r8, r7, 3
    sub r8, r8, r7
    mov r4, r8
    mov r5, r3
    call div_u16
    mov r10, 7
    sub r10, r10, r9

    mov r7, r6
    lsl r8, r7, 1
    add r8, r8, r7
    mov r4, r8
    mov r5, r3
    call div_u16
    mov r11, r9

    lsl r12, r10, 5
    or r12, r12, r11

    mov r7, BODY_COLORS
    add r7, r7, r6
    store_8 [r7], r12

    add r6, r6, 1
    jmp update_grad_loop

update_single:
    mov r1, 0x03
    mov r2, BODY_COLORS
    store_8 [r2], r1
    ret

update_grad_done:
    ret

; =====================================================================
; 无符号除法: r4 / r5 -> r9
; =====================================================================
div_u16:
    mov r9, 0
div_u16_loop:
    cmp r4, r5
    jb div_u16_done
    sub r4, r4, r5
    add r9, r9, 1
    jmp div_u16_loop
div_u16_done:
    ret

; =====================================================================
; 退出: 清屏回到 DOS(游戏结束与 Esc 共用)
; =====================================================================
exit_game:
    call cls
    jmp exit_proc

game_over:
    call cls
    mov r1, CLR_RED
    call set_fg
    mov r1, s_gameover
    call print_str
    call print_nl
    mov r1, s_presskey
    call print_str
    ; 先排空按键缓冲(避免残留方向键立刻触发), 再等新按键
game_over_drain:
    keyboard r1
    cmp r1, 0
    jne game_over_drain
game_over_wait:
    keyboard r1
    cmp r1, 0
    je game_over_wait
    call cls
    jmp exit_proc

; ---- GAME OVER 字符串 ----
s_gameover:
data8 "GAME OVER!"
s_presskey:
data8 "Press any key..."

; ---- 后备缓冲(64x32 格, 每格 1 字节 = 2048B; 0=空, 0xFF=食物, 其余=蛇身背景色) ----
bb:
space 2048

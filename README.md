# Sonata DOS — 为 Symphony ISA 实现的完整 DOS 系统

面向 Turing Complete 类游戏 **Symphony**(自定义 ISA, 指令编码见 `spec.isa`)的
完整 DOS 系统, 采用 **boot -> 外存加载 DOS -> 加载第三方 .mvt 程序** 的真实架构。

**v3 特性: 结构化磁盘目录树 + 扩展名规范 + 外存文件系统 + 运行时 MKMVT。**
**命名规范: 系统文件 = `.SCO`(score), 可执行程序 = `.MVT`(movement)。**

## 磁盘目录树(导入游戏的 sonata_disk.bin)

```
~/
├─ DOS.SCO                    内核
├─ SYSTEM/                    系统文件(源码 progs/*.asm)
│    CLS.SCO  DATE.SCO  DUMP.SCO  ECHO.SCO  PATH.SCO
│    PROMPT.SCO  SET.SCO  TIME.SCO  VER.SCO
├─ BIN/                       系统必需程序(源码 mvt/*.asm)
│    CD.MVT  COPY.MVT  CREATE.MVT  DEL.MVT  DIR.MVT  EXIT.MVT
│    FORMAT.MVT  HELP.MVT  MD.MVT  MKMVT.MVT  RD.MVT  REBOOT.MVT
│    REN.MVT  TYPE.MVT  WRITE.MVT  XDUMP.MVT
└─ HOME/                      启动默认目录(提示符 [Sonata] ~/HOME #)
     └─ PROGRAMS/             非必需示例程序(源码 programs/*.asm, 类型 MVT)
          HELLO.MVT  FIB.MVT  SNAKE.MVT
          (MVT = 用户程序类型, 会被 FORMAT 清掉; 重新导入镜像可恢复)
```

- 启动后当前目录 = **HOME**, 用户文件(MD/WRITE/MKMVT 等)默认落在 HOME
- **REBOOT = 硬重启**: 跳回 boot 的 `hard_reset` —— 清零全部数据内存
  (0x2000..0xFFFF, 含屏幕/栈/堆/加载区/大小写锁/环境变量)与寄存器, 然后
  完整重走 BIOS 流程(横幅 -> 磁盘校验 -> 加载 DOS); 外存不受影响, 用户文件保留
- **程序查找规则**: 裸名依次在 `SYSTEM`(`名字.SCO`)、`BIN`(`名字.MVT`)、
  **当前目录** 中查找 —— 只有 SYSTEM 与 BIN 的程序随时可访问,
  `HOME/PROGRAMS` 等目录里的程序需 `CD` 到该目录后裸名运行, 或
  用路径运行:
  - 相对路径: `PROGRAMS/HELLO.MVT`(相对当前目录)
  - 绝对路径: `/HOME/PROGRAMS/HELLO.MVT`(从根开始)
  - 支持 `..`(上级)与 `.`; 最后组件可省略后缀(自动补 .MVT/.SCO)
- 命令输入可省略后缀: 依次尝试 `名字.SCO`、`名字.MVT`(也可输全名)
- `DIR` 显示 名字 + 大小 + 标签(`<DIR>`/`MVT`/`SCO`); 20 行分页
- `CD ..`/`CD \\`/`CD 目录名` 在树中导航; `FORMAT` 只清用户文件,
  内置目录与程序(SCO/SCODIR)保留, 完成后回到 HOME

## 架构总览

```
游戏内:
  sonata_boot.asm ──粘贴进游戏汇编器──> 主内存 0x0000(唯一由游戏汇编的主程序)
  sonata_disk.bin ──导入游戏──> 外存地址 0(磁盘镜像, 经 pload/pstore 读写)

启动流程:
  boot 初始化(屏幕/键盘/堆) -> 校验磁盘魔数 "SNT1"
  -> exec("DOS.SCO") 拷入内核并重定位 -> jmp DOS 入口
  -> DOS 初始化(跳转表/环境变量/默认目录 HOME) -> cls 清除 boot 信息 -> 横幅格言
  -> set_shell(命令循环) -> 程序 jmp exit_proc -> boot 释放内存 -> 回命令循环
```

## 大小写

- **输入原样保留**: 命令行与文本编辑不强制转换大小写(`ECHO hello` 输出 hello)
- **名字统一大写匹配**: 命令/文件名/环境变量名不区分大小写 ——
  `WRITE foo.txt` 后 `TYPE FOO.TXT` 与 `TYPE foo.txt` 均可, DIR 显示统一大写
- **CapsLock 大小写锁定(键码 0x18)**: 在命令行或 WRITE/MKMVT 编辑器中按 CapsLock, 之后输入的字母
  翻转大小写(大写键出小写、小写键出大写), 再按 Tab 恢复; 用于游戏键盘只发
  送单一大小写时输入另一大小写。想换成其它键: 先用 `keytest.asm` 测出该键的低 8 位键码,
  再把 `sonata_boot.asm` 里的 `const CH_CAPS = 0x18` 改成该值并重新构建
  (boot 与镜像成对重新导入)

## 贪吃蛇(SNAKE.MVT)

```
CD PROGRAMS          ; 或直接用路径: PROGRAMS/SNAKE.MVT
SNAKE
```

- 方向: **W/A/S/D**(大小写均可); **Esc** 退出回 DOS 提示符;
  撞墙**穿墙回绕**(从对面出来, 不会因此结束); 撞到自己时显示红色 GAME OVER,
  按任意键回 DOS
- 修复原版键盘问题: 原版把"弹起"事件(bit8=1)当成按键、且只认小写键码,
  导致手动模式无法控制 —— 现只响应"按下"事件(bit8=0)并把 a-z 规范化为大写
- 无闪屏(双缓冲): 全部画到程序内嵌的后备缓冲(64x32 格, 每格 1 字节: 0=空/0xFF=食物/
  其余=蛇身背景色), 每帧画完后**一次性整块拷贝**到可见屏幕 —— 可见屏幕只在这段拷贝中
  更新, 中间态是几乎相同的新旧帧, 游戏渲染器无论何时采样都看不到"空洞/重影"等错误帧
  (对游戏时钟频率波动免疫)
- 固定速度(自校准指令计数): 启动时空转 32 万次测 time_0 速率, 反算每帧等待次数,
  使每帧 ≈ 0.125 秒真实时间 = **8 格/秒, 任何时钟频率下表现一致**;
  等待本身是指令计数, 模拟时钟波动不会造成冲刺(漂移约 ±1%);
  速度在 TARGET_HI(帧目标时间 >>16)调
- 帧缓冲固定 0x3000(与 DOS 共用屏幕); 数据区 0x2400..0x27FF;
  栈顶 0x7000(避开加载区); 模拟器时间按纳秒推进(1000 单位/指令), CLI 约 25 万步/帧 = 4 格/秒

## 运行时新建 .MVT 并运行(MKMVT)

```
MKMVT BEEP            ; 自动补全为 BEEP.MVT(已带 .MVT 则不变)
31 10 00 4F ...       ; 键入机器码十六进制字节(空格分隔, 大小写均可)
<Esc>                 ; 保存之后输入 BEEP.MVT 即可运行
```

- 运行时 MVT 加载到**固定地址 0xFD00**(堆 0x7400..0xFD00 之上, 无重定位);
  `call/ret` 与 boot 导出调用天然位置无关, 程序内部跳转需按 0xFD00 手算
- 打印 "OK" 的完整示例(依赖当前 boot 导出地址, 由 build.mjs 生成):
  `31 10 00 4F 07 F0 00 00 34 FF 00 14 35 EE 00 04 66 0F 0E 00 58 0F 07 14 31 10 00 4B 07 F0 00 00 34 FF 00 14 35 EE 00 04 66 0F 0E 00 58 0F 07 14 07 F0 00 00 34 FF 00 14 35 EE 00 04 66 0F 0E 00 58 0F 08 44 58 0F 05 B8`

## 磁盘镜像格式(sonata_disk.bin, 32767B = 0x7FFF, 版本 2)

```
+0   魔数 4B "SNT1"                +4  版本 4B (=2)
+8   文件数 4B                      +12 容量 4B (=64)
+16  freeOff 4B(代码区空闲指针)    +20 codeEnd 4B (=0x7FFF)
+24  tableBase 4B (=32)            +28 baseOff 4B(FORMAT 复位用)
+32  文件表 64 x 40B:
       [名字 12B][类型 4B][大小 4B][入口偏移 4B][代码偏移 4B]
       [重定位数 4B][重定位表偏移 4B][父目录 4B]
     类型: 0=空闲 1=DATA 2=MVT(运行时) 3=DIR(用户目录)
           4=SCO(内置程序) 5=SCODIR(内置目录, FORMAT 不删)
   代码区 0xA20..0x7FFF: 机器码 + 重定位表; 运行时新文件从 freeOff 追加
```

全部数值字段大端写入; 镜像填充到 0x7FFF, 保证运行时 pstore 落在导入文件区域内。

## 内存布局

| 区间 | 用途 |
|---|---|
| 0x0000..0x1FFF | boot 代码(约 4.3KB) |
| 0x2000..0x2FFF | boot/内核共享数据(光标/参数/CURDIR/环境/日期/字符串/跳转表) |
| 0x3000..0x6BFF | 屏幕帧缓冲(96x40, ASCII32, 4B/格) |
| 0x6C00..0x6FFF | 栈(向下生长, 栈顶 0x7000) |
| 0x7400..0xFCFF | 加载区堆: DOS 与 .mvt 程序 |
| 0xFD00..0xFDFF | 运行时 MVT 固定加载区(MKMVT 产物, 最大 255B) |
| 外存 0..0x7FFF | 磁盘镜像 = 目录树 + 代码区 |

## 目录结构(源码工程)

- `sonata_boot.asm` — **主文件**: 内存管理 + 磁盘驱动(disk_find/disk_meta/
  disk_alloc/exec) + 系统调用(贴进游戏)
- `dos.asm` — DOS 内核: shell/扩展名分发/跳转表/环境变量/横幅格言/FS 内核函数
- `progs/*.asm` — 系统文件源码 -> 磁盘 `SYSTEM/*.SCO`
- `mvt/*.asm` — 系统必需程序源码 -> 磁盘 `BIN/*.MVT`
- `programs/*.asm` — 非必需示例程序源码 -> 磁盘 `HOME/PROGRAMS/*.MVT`
- `tools/build.mjs` — 构建器(汇编 boot/dos/progs/mvt/programs, 生成磁盘镜像)
- `tools/asm.mjs` `tools/disk.mjs` `tools/emulate.mjs` — 汇编器/打包器/模拟器
- `tools/test.mjs` — 端到端回归测试(109 项, 全部通过)
- `tools/cmdtest.mjs` — 逐命令审计(每条命令独立会话, 正常+异常路径, 95 项)
- `tools/cli.mjs` — 交互式 CLI 模拟器(终端里实时跑 DOS, 真彩渲染 + 实时键盘)
- `sonata_disk.bin` — 构建产物(导入游戏)
- `sonata_mini.asm` — 独立迷你 DOS(诊断用, 不受本架构影响)
- `sonata_diag.asm` — 外存诊断程序(游戏内排查用)
- `keytest.asm` — 键盘键码测试(独立, 打印每个按键的 9 位原始值与低 8 位键码)
- `timecal.asm` — time_0 速率标定(独立, 测 10 秒内的刻度增量, 给贪吃蛇定 FPS)

## 使用步骤

1. `node tools/build.mjs` 生成 `sonata_disk.bin`(32767B)
2. 游戏内: 把 `sonata_boot.asm` 全文粘贴进游戏汇编器
3. 游戏内: 导入 `sonata_disk.bin`
4. 运行。看到绿色提示符 `[Sonata] ~/HOME #` 即成功; `HELP` 看命令表

> **boot 与磁盘镜像必须配套**: 改动 boot 后必须重新生成磁盘镜像并**两个文件一起
> 重新导入**。运行时文件写入外存只在本次会话有效, 不会写回镜像文件本身。

## 终端交互模拟(CLI)

不用进游戏, 在 PC 终端里实时跑 DOS(Windows Terminal / VS Code 终端均可, 宽 96 列以上):

```
node tools/cli.mjs
```

- 自动汇编 `sonata_boot.asm` 并装载 `sonata_disk.bin`, 60fps 差异重绘 96x40 屏幕
  (真彩 ANSI; 游戏调色板 = RRGGGBBB, 实测 0x1C 绿 / 0xE0 红 / 0xFC 黄 / 0xFF 白)
- 键盘实时送入模拟器(按下+弹起事件); **Ctrl+C** 退出, **Ctrl+P** 暂停, **Ctrl+T** 三倍速,
  **Ctrl+K** 发送 CapsLock(0x18); 方向键等转义序列自动忽略
- 选项: `--speed N` 步/秒(默认 1000000, 贪吃蛇 1 格/秒), `--fps N`(默认 60), `--boot/--disk` 自定义文件,
  `--keylog` 状态栏显示最近键码
- 无头自检: `node tools/cli.mjs --smoke [步数]` 跑完打印屏幕文本退出;
  配 `--type "命令\n" --type-at 步数` 可在指定步数注入按键
  (例: `--type "CD PROGRAMS\nSNAKE\n" --type-at 600000 --smoke 2000000` 自动进贪吃蛇)

## 注意事项

- `call` 会把返回地址写进 flags 寄存器, 因此 **cmp 后不能隔着 call 用条件跳转**
- 16 位立即数限制: 大地址用 `mov hi + lsl` 合成
- 键盘: Enter=10, Backspace=13, Esc=14(游戏实测); 屏幕从 12288 固定读取
- 外存按字节编址, 32 位字大端序; 屏幕格 fg=0 不可见, 打印前需 set_fg(CLR_WHITE)
- 滚动/清屏/程序加载为 32 位字操作(滚动约 3.1 万条指令/次, 清屏约 2.3 万条);
  其余内存访问使用 8 位字节指令(此前全 32 位化尝试已回退)
- 磁盘容量 64 表项; 单个文件最大 255B; 删除不回收代码区(FORMAT 整体复位)

## 自测

`node tools/test.mjs` 在 PC 端模拟器上跑完整会话(boot -> DOS -> 目录导航/
外存 CRUD/REBOOT 硬重启与持久性/MKMVT 录入并运行/XDUMP/FORMAT/大小写/路径执行),
108 项断言全部通过。

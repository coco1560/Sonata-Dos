; ==================================================
; 程序: cls(Sonata DOS 磁盘程序)
; @name: cls
; @data: 0
; 入口 main(转换器改名为 cls_main); 结束 jmp shell_resume
; ==================================================

main:
  call cls_init
  jmp do_cls

do_cls:
  call cls
  jmp shell_resume

; ---------------- 数据初始化 ----------------
cls_init:
  ret


; ============================================================
; NTC Platform - Dick Smith System 80 / EACA Video Genie (Z80)   *** DRAFT ***
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A TRS-80 Model I CLONE (EACA copied the Model I ROM, changing only a small
; part for hardware differences). So it IS ntc_plat_trs80 with three changes,
; and is built with  ;@base trs80 : the console (#3C00, 64x16), the keyboard
; matrix (#3800) and the DOS return (#402D, NEWDOS/80 on the Model I) are all
; the Model I's, inherited unchanged.
;
; WHAT DIFFERS from the Model III base (overridden below):
;   * Clock: Z80 @ ~1.77 MHz (Model I speed).  (CpuClock is in System.cls.)
;   * Startup: the Model I / System 80 has NO E4 NMI mask and NO E0 maskable
;     mask - those are Model III ports. The Model I's disk interrupt is MASKABLE,
;     routed through the expansion interface's latch at #37E0, and plain  di
;     keeps the thread safe. So the romhead is just di + jp ntc_start.  ;!!S80
;   * Frame: the Model III's E0/EC 30Hz clock poll would spin forever here (no
;     such port), so Frame is a no-op until the Model I 40Hz heartbeat (#37E0) is
;     wired.  ;!!S80
; Everything else (putc / newline / cls / backspace / locate / key scan / exit /
; memtop / data) is the trs80 base, unchanged.
; ============================================================
;@base     trs80
;@name     Dick Smith System 80 / Video Genie (direct video)
; (org, text, stack, cols, rows, scrinit, irq all inherited from trs80)
; ============================================================

;## ntc_plat_romhead ntc_plat_data
; Entry at ;@org (the /CMD transfer address). Model I / System 80: di is enough -
; there is no E4/E0 to clear (the disk IRQ is maskable, via #37E0).  ;!!S80
ntc_s80_start:
			di
			jp ntc_start

;## ntc_plat_frame ntc_data
; No clock poll: the Model I heartbeat (#37E0, ~40Hz) differs from the Model
; III's E0/EC and isn't wired. Return at once (no pacing).  ;!!S80
ntc_plat_frame:
			jp (ix)

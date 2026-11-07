; ============================================================
; NTC Platform - Amstrad PcW16 (Rosanne application)   *** DRAFT / UNTESTED ***
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; STATUS: scaffold. Structure is modelled on the working CP/M platform
;   (ntc_plat_cpm.asm). Every Rosanne (OS/BIOS) call below is from the
;   DOCUMENTED interface (ROSAN283.DOC facts, as cited by PcW16-BASIC's
;   runtime), NOT from a run on hardware. Nothing here has been executed in
;   XAnne. Lines marked  ;!!XANNE  are register/value conventions that MUST be
;   confirmed in XAnne before this is trusted. Do not ship as working.
;
; THE MACHINE (ROSAN283.DOC 'Memory Layout'):
;   * 16MHz Z80, 1MB RAM in 64 x 16K blocks, Rosanne (GUI OS) in flash.
;   * The Z80's 64K is four 16K quarters:
;       Q0 #0000-#3FFF  PINNED to block #80 (Rosanne common). The stack
;                       descends from #3FFE (~2K); app private #2000-#2FFF.
;                       NOT remappable - you stand on it to make OS calls.
;       Q1 #4000-#7FFF  the app's resident block (bios_setmem1/getmem1).
;       Q2 #8000-#BFFF  freely mappable (bios_setmem2/getmem2).
;       Q3 #C000-#FFFF  freely mappable (bios_setmem3/getmem3).
;     "you can do what you want with the 2nd, 3rd and 4th quarters."
;   * Execution starts at #4100 with CHL = 24-bit launch address.
;   * One OS entry: call 003Bh, the function number in a register (A, per
;     ROSAN283 'how to make an OS call').  ;!!XANNE confirm which register.
;
; NTC FIT (why this is a good target - see the design notes):
;   * SP is the thread. The real Z80 stack is only needed for the brief
;     call 003Bh excursion, so Q0's ~2K stack is ample (unlike a native
;     compiler, whose whole call depth must fit there).
;   * Classes are banks: a far-called class's block is mapped into the window
;     quarter (bios_setmem2/3), run, mapped back - this is the ntc_ovl_kwin /
;     kwback page-switch the compiler already emits.
;
; TWO FLAVOURS (the 48K above Q0 split resident|window):
;   pcw16     16K pages: resident 32K #4000-#BFFF, bank window Q3 at #C000.
;   pcw16b    32K pages: resident 16K #4000-#7FFF, bank window Q2+Q3 #8000.
;   (This file is the 16K-page flavour; pcw16b is ;@base pcw16 with its own
;    ;@org note and window equ. Default to 16K pages - NTC's many small
;    classes pack better at 16K granularity.)
; ============================================================
;@name     Amstrad PcW16 (Rosanne app)
;@org      #4100
;@text     byte
;@scrinit  0
;@irq      0
;@stack    ntc_pcwstack
;@cols     90
;@rows     32
; Rosanne OS/BIOS function numbers are defined in the ntc_plat_data section
; below (they must live in a ;## section, or the generator drops them).
; ============================================================

;## ntc_plat_data
; Rosanne OS/BIOS function numbers (ROSAN283.DOC; the subset NTC needs).
; BIOS calls (call 003Bh, A = number):                     ;!!XANNE confirm reg
ROS_KEYSTATE    equ #89     ; bios_keystate: A=keyno in, up/down status out
ROS_GETTIME     equ #B0     ; bios_gettime: B hrs, C min, D sec, E ticks
ROS_SETMEM1     equ #BF     ; map a block into Q1 (#4000)      ;!!XANNE number
ROS_GETMEM1     equ #CB     ; the block now in Q1
ROS_SETMEM2     equ #C2     ; map a block into Q2 (#8000)
ROS_GETMEM2     equ #CE     ; the block now in Q2
ROS_SETMEM3     equ #C5     ; map a block into Q3 (#C000)      ;!!XANNE number
ROS_GETMEM3     equ #D1     ; the block now in Q3              ;!!XANNE number
; OS calls (call 003Bh, A = number; the text/graphics/dialog interface):
ROS_SCR_DIRECT  equ #00     ; os_scr_direct: direct character to the screen ;!!XANNE no+regs
ROS_GET_MOUSE   equ #00     ; os_get_mouse_xy                               ;!!XANNE
ROS_MOUSE_ON    equ #00     ; os_mouse_on                                   ;!!XANNE
ROS_MOUSE_OFF   equ #00     ; os_mouse_off                                  ;!!XANNE
ntc_curx:		db 0			; column (0 based) - counted for Tab
ntc_cury:		db 0			; row (0 based)
ntc_scols:		db 90			; columns
ntc_osa:		db 0			; ntc_os: A on return
ntc_smode:		db 0			; screen mode
ntc_pcwstack	equ ntc_end + 256	; the program's real stack lives above the program image
								; in Q1/resident RAM; SP is swapped to it only for OS calls

;## ntc_plat_os ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_os - A = Rosanne function number, other regs = its arguments.
; SP is the thread; switch to the real stack, make the one OS entry
; (call 003Bh), switch back. A (also in ntc_osa) and the call's output
; regs come back. IX is kept. This is the CP/M ntc_bdos pattern, retargeted
; from "call 5" to "call 003Bh".                              ;!!XANNE confirm 003Bh + arg regs
; ------------------------------------------------------------
ntc_os:
			ld (ntc_hostix), ix
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			; interrupts: Rosanne may expect them on across a call ;!!XANNE
			call #003B
			ld sp, (ntc_ip)
			ld (ntc_osa), a
			ld ix, (ntc_hostix)
			jp (ix)

;## ntc_plat_screen ntc_plat_os ntc_plat_data ntc_data
; ntc_plat_putc - A = character to the screen (os_scr_direct), count the column
ntc_plat_putc:
			ld (ntc_pclink), ix
			; A already = char; os_scr_direct takes the char in ? and fn in A ;!!XANNE arg reg
			ld c, a					; park the char            ;!!XANNE which reg os_scr_direct reads
			ld a, ROS_SCR_DIRECT
			ld ix, ntc_pc_back
			jp ntc_os
ntc_pc_back:
			ld ix, (ntc_pclink)
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			cp b
			jr c, ntc_pc_col
			xor a					; wrapped
ntc_pc_col:
			ld (ntc_curx), a
			jp (ix)

; ntc_plat_newline - CR LF (two os_scr_direct)   ;!!XANNE does Rosanne want 13,10 or a line call?
ntc_plat_newline:
			ld (ntc_pclink), ix
			ld c, 13
			ld a, ROS_SCR_DIRECT
			ld ix, ntc_nl_lf
			jp ntc_os
ntc_nl_lf:
			ld c, 10
			ld a, ROS_SCR_DIRECT
			ld ix, ntc_nl_done
			jp ntc_os
ntc_nl_done:
			xor a
			ld (ntc_curx), a
			ld ix, (ntc_pclink)
			jp (ix)
ntc_pclink:		dw 0

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_os ntc_plat_data ntc_data
; ntc_plat_backspace - BS space BS on the current line  ;!!XANNE Rosanne BS behaviour
ntc_plat_backspace:
			ld a, (ntc_curx)
			or a
			jr z, ntc_bs_none
			dec a
			ld (ntc_curx), a
			ld (ntc_pclink), ix
			ld c, 8
			ld a, ROS_SCR_DIRECT
			ld ix, ntc_bs_sp
			jp ntc_os
ntc_bs_sp:
			ld c, ' '
			ld a, ROS_SCR_DIRECT
			ld ix, ntc_bs_bk
			jp ntc_os
ntc_bs_bk:
			ld c, 8
			ld a, ROS_SCR_DIRECT
			ld ix, (ntc_pclink)
			jp ntc_os
ntc_bs_none:
			jp (ix)

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_os ntc_plat_data ntc_data
; ntc_plat_cls - a Rosanne app's window is managed; a text stream just newlines
; ;!!XANNE there is likely an os_ call to clear the window - use it if so
ntc_plat_cls:
			ld a, (ntc_curx)
			or a
			jp nz, ntc_plat_newline
			jp (ix)

; ntc_plat_locate - nothing without a positioned console   ;!!XANNE os cursor move?
ntc_plat_locate:
			jp (ix)

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_mode - nothing (Rosanne owns the display mode)
ntc_plat_mode:
			jp (ix)

;## ntc_plat_key ntc_plat_os ntc_data
; ntc_plat_scankey - A = key or 0.  bios_keystate reports up/down of ONE key, so
; a full scan walks the key numbers until one is down, maps it to ASCII, returns.
; This is a placeholder: a single polled read.             ;!!XANNE keyno range + ASCII map
ntc_plat_scankey:
			ld a, ROS_KEYSTATE
			; in: the key number to test in ? ; out: up/down in ?  ;!!XANNE
			jp ntc_os

; ntc_plat_getkey - wait for a key
ntc_plat_getkey:
			ld (ntc_gklink), ix
ntc_gk_poll:
			ld a, ROS_KEYSTATE
			ld ix, ntc_gk_back
			jp ntc_os
ntc_gk_back:
			or a
			jr z, ntc_gk_poll
			ld ix, (ntc_gklink)
			jp (ix)
ntc_gklink:		dw 0

;## ntc_plat_frame
ntc_plat_frame:
			jp (ix)

;## ntc_plat_ticks ntc_plat_os
; ntc_plat_ticks - HL = a tick counter from bios_gettime (seconds*ratio + ticks)
; ;!!XANNE decide the unit; PcW16-BASIC used a sixteenths-of-a-second derivation
ntc_plat_ticks:
			ld a, ROS_GETTIME
			ld (ntc_tklink), ix
			ld ix, ntc_tk_back
			jp ntc_os
ntc_tk_back:
			; B hrs C min D sec E ticks -> HL  ;!!XANNE assemble a tick count
			ld h, d
			ld l, e
			ld ix, (ntc_tklink)
			jp (ix)
ntc_tklink:		dw 0

;## ntc_plat_exit ntc_plat_os ntc_plat_data
; ntc_plat_exit - hand the app back to Rosanne (the app's clean exit)
; ;!!XANNE the correct os_ call / return path for an app ending
ntc_plat_exit:
			ld a, #00				; os_app_exit ? ;!!XANNE
			jp ntc_os

;## ntc_plat_memtop ntc_plat_data
; ntc_plat_memtop - HL = the first byte the Memory Small heap must not use.
; In the 16K-page flavour the resident core is #4000-#BFFF and the window is
; Q3 (#C000); the heap lives below the window. Return the window base.
; ;!!XANNE set to the real top of resident data once the layout is fixed.
ntc_plat_memtop:
			ld hl, #C000
			ret

;## ntc_plat_cmdline ntc_data
; A Rosanne app is launched by file, not a command tail; CommandLine is empty
; until/unless Rosanne passes arguments.                    ;!!XANNE app args?
ntc_cmdbuf:		ds 2
ntc_cmdsave:
			xor a
			ld (ntc_cmdbuf), a
			ret
ntc_cmdget:
			dec hl
			ld c, (hl)
			inc hl
			xor a
			ld (hl), a
			ret

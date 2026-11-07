; ============================================================
; NTC Platform - TI-83 Plus / TI-84 Plus (Z80, TI-OS / bcall)   *** DRAFT ***
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; STATUS: scaffold, modelled on the working CP/M platform (ntc_plat_cpm.asm)
;   and the MSX BIOS console. It ASSEMBLES with sjasmplus (the Z80 backend),
;   but has NOT run on a calculator or in an emulator here. The program header
;   convention (.org / the AsmPrgm token) is GROUNDED from the canonical
;   Cemetech "Z80 Basics" and 83pa28d ("ASM in 28 days") tutorials. The bcall
;   ADDRESSES below are the standard TI-83+ SDK values from ti83plus.inc, but
;   that include file can't be fetched in this build box, so every equate is
;   marked  ;!!TI  and MUST be confirmed against your own ti83plus.inc before
;   you trust the binary on hardware.
;
; THE MACHINE:
;   * 6 MHz Z80 (83+ / 84+; the 84+ clocks faster). Mono LCD 96x64.
;   * TI-OS owns interrupts, the LCD and the keypad. You reach it through
;     "bcall": the macro  rst 28h \ dw <routine>  (grounded, Cemetech). The OS
;     pages the called routine in from flash around that rst.
;   * A nostub asm program is run by  Asm(prgmNAME)  from the homescreen. It
;     loads and runs at $9D95 (userMem). The two bytes at $9D93-$9D94 are the
;     AsmPrgm token $BB,$6D (grounded) - NOT code; they are part of the .8xp
;     FILE wrapper, not the raw image. So this platform assembles a RAW binary
;     at ;@org #9D95, and a .8xp packager (the TI variable header + the token +
;     checksum) is a post-step, the way the Neo Geo needs a cart packager. A
;     helper for that belongs in tools/ (binpac8x-style) - ;!!TI not written.
;
; NTC FIT:
;   * SP is the thread. bcall (rst 28h) pushes a return address, so SP must be
;     a REAL stack for the brief call - exactly CP/M's "call 5" case. Each OS
;     op goes through ntc_ti_call, which swaps SP to ntc_csp (the ;@stack real
;     stack), does the bcall, swaps back. The thread never sees the push.
;   * Text uses the OS large-font homescreen (curRow 0-7, curCol 0-15 -> a
;     16 x 8 grid ;!!TI) via _PutC / _PutS; the OS tracks and wraps the cursor,
;     NTC mirrors curCol into ntc_curx for Tab.
; ============================================================
;@name     TI-83 Plus / 84 Plus (TI-OS)
;@org      #9D95
;@text     byte
;@scrinit  0
;@irq      0
;@stack    ntc_ti_stack
;@cols     16
;@rows     8
; bcall addresses live in the ntc_plat_data section below (equates in a header
; comment are dropped by the generator - only ;## sections are emitted).
; ============================================================

;## ntc_plat_data
; ------------------------------------------------------------
; TI-OS bcall equates - standard ti83plus.inc values.  ;!!TI confirm every one
; against your ti83plus.inc (the include can't be downloaded in this box).
; ------------------------------------------------------------
_PutC            equ #4504   ; A = char at cursor, advance curCol            ;!!TI
_PutS            equ #450A   ; HL = zero-terminated string                   ;!!TI
_NewLine         equ #452E   ; CR+LF, scroll if needed                       ;!!TI
_ClrLCDFull      equ #4540   ; clear the whole LCD                           ;!!TI
_HomeUp          equ #4558   ; curRow = curCol = 0                           ;!!TI
_GetCSC          equ #4018   ; A = scan code (0 = none), non-blocking        ;!!TI
_GetKey          equ #4972   ; A = key code, blocking (2nd/alpha handled)    ;!!TI
_JForceCmdNoChar equ #4027   ; clean return to the homescreen (exit)         ;!!TI
curRow           equ #844B   ; OS text cursor row  (0-7)                     ;!!TI
curCol           equ #844C   ; OS text cursor col  (0-15)                    ;!!TI

ntc_curx:		db 0			; column mirror (0 based) - counted for Tab
ntc_cury:		db 0			; row mirror (0 based)
ntc_scols:		db 16			; columns (large-font grid)                 ;!!TI
ntc_ti_stack	equ ntc_end + 256	; the real stack: the 256 bytes above the program image.
									; SP is swapped to it only for a bcall (which is shallow).

;## ntc_ti_call ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_ti_call - IY = a real-stack routine (it may bcall). SP is the thread;
; swap it to the real stack (ntc_csp), call the routine, swap back, keep IX.
; This is the MSX ntc_vcall pattern retargeted to TI-OS. Registers pass
; straight through to/from the routine (A = char for putc, A = key out, ...).
; ------------------------------------------------------------
ntc_ti_call:
			ld (ntc_tiix), ix
			ld (ntc_tisp), sp
			ld sp, (ntc_csp)
			call ntc_ti_call_jp
			ld sp, (ntc_tisp)
			ld ix, (ntc_tiix)
			jp (ix)
ntc_ti_call_jp:
			jp (iy)
ntc_tiix:		dw 0			; IX over the call
ntc_tisp:		dw 0			; the thread's SP over the call

;## ntc_plat_screen ntc_ti_call ntc_plat_data ntc_data
; ntc_plat_putc - A = character to the screen (_PutC), mirror curCol into ntc_curx
ntc_plat_putc:
			ld iy, ntc_tir_putc
			jp ntc_ti_call
ntc_tir_putc:
			rst #28
			dw _PutC				; A = char; OS advances/wraps curCol
			ld a, (curCol)
			ld (ntc_curx), a
			ret

; ntc_plat_newline - _NewLine, then curx mirror = 0
ntc_plat_newline:
			ld iy, ntc_tir_newline
			jp ntc_ti_call
ntc_tir_newline:
			rst #28
			dw _NewLine
			xor a
			ld (ntc_curx), a
			ret

;## ntc_plat_backspace @unit ntc_plat_screen ntc_ti_call ntc_plat_data ntc_data
; ntc_plat_backspace - back up a column, blank it, back up again (large font)
ntc_plat_backspace:
			ld iy, ntc_tir_bs
			jp ntc_ti_call
ntc_tir_bs:
			ld a, (curCol)
			or a
			ret z					; already at column 0: nothing
			dec a
			ld (curCol), a			; step back
			ld a, ' '
			rst #28
			dw _PutC				; blank the cell (advances curCol again)
			ld a, (curCol)
			or a
			ret z
			dec a
			ld (curCol), a			; step back over the blank
			ld (ntc_curx), a
			ret

;## ntc_plat_cls @unit ntc_plat_screen ntc_ti_call ntc_plat_data ntc_data
; ntc_plat_cls - clear the LCD and home the cursor
ntc_plat_cls:
			ld iy, ntc_tir_cls
			jp ntc_ti_call
ntc_tir_cls:
			rst #28
			dw _ClrLCDFull
			rst #28
			dw _HomeUp
			xor a
			ld (ntc_curx), a
			ret

;## ntc_plat_mode @unit ntc_plat_screen ntc_data
; ntc_plat_mode - the OS owns the LCD mode; nothing to set (large font fixed)
ntc_plat_mode:
			jp (ix)

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - H = column, L = row, 1 based. curRow/curCol are OS RAM:
; writeable without a real stack, so no bcall / no SP swap needed.
ntc_plat_locate:
			ld a, h
			dec a
			ld (curCol), a
			ld (ntc_curx), a
			ld a, l
			dec a
			ld (curRow), a
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_key ntc_ti_call ntc_data
; ntc_plat_scankey - A = key or 0 (non-blocking, _GetCSC).
; ;!!TI _GetCSC returns a TI SCAN CODE (skEnter, sk0..., skGraph), NOT ASCII.
; A scancode->ASCII map (below, stubbed) is needed before Inkey reads sanely.
ntc_plat_scankey:
			ld iy, ntc_tir_scan
			jp ntc_ti_call
ntc_tir_scan:
			rst #28
			dw _GetCSC				; A = scan code or 0
			; ;!!TI map A (scan code) -> ASCII here; raw code passed through for now
			ret

; ntc_plat_getkey - wait for a key (poll _GetCSC so interrupts aren't required)
ntc_plat_getkey:
			ld iy, ntc_tir_getk
			jp ntc_ti_call
ntc_tir_getk:
			rst #28
			dw _GetCSC
			or a
			jr z, ntc_tir_getk
			; ;!!TI map A (scan code) -> ASCII here too
			ret

;## ntc_plat_frame ntc_data
; ntc_plat_frame - the 83+ has no cheap vsync NTC can poll; return at once.
; ;!!TI a timed delay or an LCD-busy poll would pace animation.
ntc_plat_frame:
			jp (ix)

;## ntc_plat_ticks ntc_data
; ntc_plat_ticks - HL = a tick count. The 83+ has no RTC; the 84+ has a crystal
; timer (ports $45-$4B). ;!!TI wire the 84+ timer; 0 for now (CLOCK cap is off).
ntc_plat_ticks:
			ld hl, 0
			jp (ix)

;## ntc_plat_exit ntc_ti_call ntc_plat_data ntc_data
; ntc_plat_exit - clean return to the homescreen. SP is the mangled thread, so
; a plain ret can't go back; _JForceCmdNoChar resets the OS to the homescreen
; regardless of the stack. Swap to the real stack first.
ntc_plat_exit:
			ld sp, (ntc_csp)
			rst #28
			dw _JForceCmdNoChar		; does not return
			ret						; (unreached)                            ;!!TI

;## ntc_plat_memtop ntc_plat_data
; ntc_plat_memtop - HL = the first byte the Memory heap must not use (it grows
; down from here, as CP/M's heap grows down from #FFFF). ;!!TI #FB00 is a
; conservative ceiling below TI-OS high system RAM; confirm free RAM on the
; target OS version (saveSScreen / appBackUpScreen are also usable scratch).
ntc_plat_memtop:
			ld hl, #FB00
			ret

;## ntc_plat_cmdline ntc_data
; An  Asm(prgmNAME)  launch passes no command tail; CommandLine is empty.
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

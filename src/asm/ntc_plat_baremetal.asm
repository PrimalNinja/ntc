; ============================================================
; NTC Platform - Bare Metal (a Z80 and nothing else assumed)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A program for a machine NTC BASIC doesn't know: a board of your
; own, a new target you are bringing up, a ROM. It is built from
; its org (#0000 unless Option Org says otherwise) and nothing is
; set up or assumed - no screen, no keyboard, no clock, no files,
; no firmware, no interrupt handler. Every platform routine below
; is an empty one that does nothing (a character printed goes
; nowhere, a key read is 0 - GetKey waits for ever until it is
; filled in): fill in the ones your machine has. The same with the
; platform classes (lib/baremetal: StdIO, System, FileSystem,
; Memory, List): their methods are there for a program to compile
; against, and do nothing until they are written - copy one into
; the project and it replaces the platform's.
;
; The stack: ld sp, 0 at the start, so the first push lands at
; #FFFE (the top of the 64K); Option Stack puts it elsewhere.
; Interrupts: nothing is installed at #0038 (which is inside the
; program when the org is #0000), so build with Option Turbo, or
; put a handler there yourself and keep normal mode.
; The console counts columns (for Tab) as a stream: ntc_curx only.
; ============================================================
;@name     Bare Metal (nothing assumed: fill the platform in)
;@org      #0000
;@text     byte
;@scrinit  0
;@irq      0
;@stack    0
;@cols     80
;@rows     25
; ============================================================

;## ntc_plat_data
ntc_curx:		db 0			; column (0 based) - counted for Tab
ntc_cury:		db 0			; row (0 based)
ntc_scols:		db 80			; columns
ntc_srows:		db 25			; rows

;## ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_putc - A = the character (32-126) to show: fill in (a UART, a screen ...).
; All of these are entered with jp, the return address in IX, and end with jp (ix): no
; call, no push - SP is the program's thread
ntc_plat_putc:
			ld hl, ntc_curx			; (the column counted, for Tab)
			inc (hl)
			jp (ix)

; ntc_plat_newline - the next line: fill in
ntc_plat_newline:
			xor a
			ld (ntc_curx), a
			jp (ix)

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_backspace - back one cell and blank it: fill in
ntc_plat_backspace:
			ld a, (ntc_curx)
			or a
			jr z, ntc_bs_none
			dec a
			ld (ntc_curx), a
ntc_bs_none:
			jp (ix)

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_cls - clear the screen, cursor home: fill in
ntc_plat_cls:
			xor a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_mode - A = the mode (0-2: 20 / 40 / 80 columns on a CPC): fill in, or leave
ntc_plat_mode:
			jp (ix)

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - H = column, L = row (1 based): fill in
ntc_plat_locate:
			ld a, h
			or a
			jr z, ntc_lc_x0
			dec a
ntc_lc_x0:
			ld (ntc_curx), a
			ld a, l
			or a
			jr z, ntc_lc_y0
			dec a
ntc_lc_y0:
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_key ntc_data
; ntc_plat_scankey - A = the key pressed now, 0 none: fill in
ntc_plat_scankey:
			xor a
			jp (ix)

; ntc_plat_getkey - wait for a key, A = the key: fill in (as it is it waits for ever)
ntc_plat_getkey:
ntc_gk_wait:
			jr ntc_gk_wait			; (poll the hardware here; no call - SP is the thread)
			jp (ix)

;## ntc_plat_frame
; ntc_plat_frame - wait for the next frame (Frame): fill in
ntc_plat_frame:
			jp (ix)

;## ntc_plat_ticks
; ntc_plat_ticks - HL = the tick count (Ticks; a timer interrupt's counter): fill in
ntc_plat_ticks:
			ld hl, 0
			jp (ix)

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - before the program returns to whatever started it (End): fill in
; (a bare machine has nowhere to return to: a halt, or a jump to your monitor)
ntc_plat_exit:
			jp (ix)

;## ntc_plat_memtop
; ntc_plat_memtop - HL = the first byte the Memory class's heap must not use (the top of
; RAM, under the stack). Called on the real stack (call / ret), only by the Memory class
ntc_plat_memtop:
			ld hl, #FF00
			ret

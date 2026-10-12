; ============================================================
; NTC Platform - test harness: console through I/O ports
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; For test/ntcrun.py: the emulator prints what goes out and
; feeds typed keys in, so tests read exact text instead of
; reading the CPC screen back. 40 x 25 text, like CPC mode 1.
;
;   out #fe  char          out #f9  new line     out #f5  backspace
;   out #fc  clear screen  out #fb  locate (column, then row, 1 based)
;   out #fa  mode (0, 1, 2: 20 / 40 / 80 columns, clears)
;   in  #fd  wait for a key    in #f8  key or 0
;   in  #f7  ticks low byte    in #f6  ticks high byte (read low first)
; ============================================================
;@name     Test harness (port I/O console)
;@org      #4000
;@text     byte
;@scrinit  0
;@irq      0
;@cols     40
;@rows     25
; ============================================================

;## ntc_plat_data
ntc_curx:		db 0			; cursor column (0 based)
ntc_cury:		db 0			; cursor row (0 based)
ntc_scols:		db 40			; columns in this mode
ntc_srows:		db 25			; rows
ntc_wrapped:	db 0			; 1 = the last character wrapped to the next line

;## ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_putc - A = character: out, move on, new line after the last column
ntc_plat_putc:
			out (#fe), a
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			ld (ntc_curx), a
			cp b
			jr z, ntc_pc_wrap
			xor a
			ld (ntc_wrapped), a
			jp (ix)
ntc_pc_wrap:
			ld a, 1				; wrapped: a new line straight after does nothing
			ld (ntc_wrapped), a
			jr ntc_nl_do

; ntc_plat_newline - column 0, next row (the harness scrolls); nothing straight after a wrap
ntc_plat_newline:
			ld a, (ntc_wrapped)
			or a
			jr z, ntc_nl_do
			xor a
			ld (ntc_wrapped), a
			jp (ix)
ntc_nl_do:
			out (#f9), a
			xor a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			inc a
			cp 25
			jr c, ntc_nl_row
			ld a, 24
ntc_nl_row:
			ld (ntc_cury), a
			jp (ix)

; ntc_plat_backspace - back one and blank that cell
ntc_plat_backspace:
			xor a
			ld (ntc_wrapped), a
			ld a, (ntc_curx)
			or a
			jr nz, ntc_bs_col
			ld a, (ntc_cury)
			or a
			jr z, ntc_bs_none
			dec a
			ld (ntc_cury), a
			ld a, (ntc_scols)
ntc_bs_col:
			dec a
			ld (ntc_curx), a
			out (#f5), a
ntc_bs_none:
			jp (ix)

; ntc_plat_cls - clear, cursor home
ntc_plat_cls:
			out (#fc), a
			xor a
			ld (ntc_wrapped), a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp (ix)

; ntc_plat_mode - A = mode 0-2 (3 = 2): columns, clear
ntc_plat_mode:
			cp 3
			jr c, ntc_md_ok
			ld a, 2
ntc_md_ok:
			out (#fa), a
			ld b, 20
			or a
			jr z, ntc_md_set
			ld b, 40
			dec a
			jr z, ntc_md_set
			ld b, 80
ntc_md_set:
			ld a, b
			ld (ntc_scols), a
			jr ntc_plat_cls

; ntc_plat_locate - H = column, L = row, 1 based, kept on screen
ntc_plat_locate:
			xor a
			ld (ntc_wrapped), a
			ld a, h
			or a
			jr z, ntc_lc_x0
			dec a
ntc_lc_x0:
			ld c, a
			ld a, (ntc_scols)
			dec a
			cp c
			jr c, ntc_lc_xmax
			ld a, c
ntc_lc_xmax:
			ld (ntc_curx), a
			ld a, l
			or a
			jr z, ntc_lc_y0
			dec a
ntc_lc_y0:
			cp 25
			jr c, ntc_lc_ymax
			ld a, 24
ntc_lc_ymax:
			ld (ntc_cury), a
			ld a, (ntc_curx)
			inc a
			out (#fb), a
			ld a, (ntc_cury)
			inc a
			out (#fb), a
			jp (ix)

;## ntc_plat_key ntc_data
; ntc_plat_scankey - A = key pressed or 0
ntc_plat_scankey:
			in a, (#f8)
			jp (ix)

; ntc_plat_getkey - wait for a key, A = key
ntc_plat_getkey:
			in a, (#fd)
			jp (ix)

;## ntc_plat_frame
ntc_plat_frame:
			jp (ix)

;## ntc_plat_ticks
; ntc_plat_ticks - HL = ticks (the harness counts 300 a second of Z80 time)
ntc_plat_ticks:
			in a, (#f7)
			ld l, a
			in a, (#f6)
			ld h, a
			jp (ix)

;## ntc_plat_exit ntc_plat_data
ntc_plat_exit:
			jp (ix)

;## ntc_plat_memtop
; ntc_plat_memtop - HL = the first byte the Memory class's Small heap must not
; use (the harness's stack, below it, comes off too). Called on the real
; stack (call / ret), only by the Memory class.
ntc_plat_memtop:
			ld hl, #C000
			ret

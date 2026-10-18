; ============================================================
; NTC Platform - Amstrad CPC, direct hardware, no firmware
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; No call, no push: SP stays in the thread. Every routine is
; entered with jp, return address in IX, and ends with jp (ix).
;
; Screen  default CRTC layout, screen at #C000, 25 rows of
;         80 bytes, char line n of a row at +n*#800.
;         Text in pen 1 on pen 0. Mode 0 = 20 cols, 1 = 40, 2 = 80.
; Keys    keyboard matrix through PPI port C (#F6) and PSG reg 14
;         (read on #F4). New presses only, no auto repeat.
; ROMs    mode set turns both ROMs off (scroll reads #C000).
;         ntc_plat_exit turns the upper ROM back on (for a CALL from
;         BASIC). The firmware's own idea of the mode is not updated.
; ============================================================

;## ntc_plat_data
ntc_curx:		db 0			; cursor column (0 based)
ntc_cury:		db 0			; cursor row (0 based)
ntc_smode:		db 1			; screen mode
ntc_sinit:		db 0			; 1 once the screen is set up
ntc_sbpc:		db 2			; bytes per char  \
ntc_scols:		db 40			; columns          | from ntc_modetab
ntc_smask:		db #F0			; pen 1 pixel mask |
ntc_sshift:		db 4			; glyph bits/byte /
ntc_noadv:		db 0			; 1 = draw without moving the cursor
ntc_pgrow:		db 0			; draw / scroll counter
ntc_pgaddr:		dw 0			; draw / scroll address
ntc_klink:		dw 0			; return for ntc_plat_getkey
ntc_kidx:		db 0			; key index found by the scan
ntc_kcur:		ds 10			; matrix this scan (0 = pressed)
ntc_kprev:		db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ntc_modetab:	db 4, 20, #C0, 2		; mode 0
				db 2, 40, #F0, 4		; mode 1
				db 1, 80, #FF, 8		; mode 2

;## ntc_plat_screen ntc_plat_data ntc_font
; ------------------------------------------------------------
; ntc_plat_putglyph - DE = 8 byte glyph, draw at the cursor, move on
; ------------------------------------------------------------
ntc_plat_putglyph:
			ld a, (ntc_cury)
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			ld b, h
			ld c, l
			add hl, hl
			add hl, hl
			add hl, bc			; HL = row * 80
			ld a, (ntc_sbpc)
			ld b, a
			ld a, (ntc_curx)
			ld c, a
			xor a
ntc_pg_mul:
			add a, c
			djnz ntc_pg_mul		; A = column * bytes per char
			ld c, a
			ld b, #C0
			add hl, bc			; HL = #C000 + row*80 + col*bpc
			ld a, 8
ntc_pg_row:
			ld (ntc_pgrow), a
			ld (ntc_pgaddr), hl
			ld a, (de)
			inc de
			ld c, a
			ld a, (ntc_sbpc)
			ld b, a
ntc_pg_byte:
			ld a, (ntc_smask)
			and c
			ld (hl), a
			inc hl
			ld a, (ntc_sshift)
			sla c
			sla c
			cp 4
			jr c, ntc_pg_shifted
			sla c
			sla c
ntc_pg_shifted:
			djnz ntc_pg_byte
			ld hl, (ntc_pgaddr)
			ld bc, #800
			add hl, bc
			ld a, (ntc_pgrow)
			dec a
			jr nz, ntc_pg_row
			ld a, (ntc_noadv)
			or a
			jr nz, ntc_pg_noadv
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			ld (ntc_curx), a
			cp b
			jr z, ntc_plat_newline
			jp (ix)
ntc_pg_noadv:
			xor a
			ld (ntc_noadv), a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_newline - column 0, next row, scroll at the bottom
; ------------------------------------------------------------
ntc_plat_newline:
			xor a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			inc a
			cp 25
			jr nc, ntc_plat_scroll
			ld (ntc_cury), a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_scroll - move rows 1-24 up one, clear row 24
; ------------------------------------------------------------
ntc_plat_scroll:
			ld a, 24
			ld (ntc_cury), a
			ld hl, #C000
			ld a, 8
ntc_sc_line:
			ld (ntc_pgrow), a
			ld (ntc_pgaddr), hl
			ld d, h
			ld e, l
			ld bc, 80
			add hl, bc
			ld bc, 24 * 80
			ldir
			ld h, d
			ld l, e
			ld (hl), 0
			inc de
			ld bc, 79
			ldir
			ld hl, (ntc_pgaddr)
			ld bc, #800
			add hl, bc
			ld a, (ntc_pgrow)
			dec a
			jr nz, ntc_sc_line
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_backspace - cursor back one and blank that cell
; ------------------------------------------------------------
ntc_plat_backspace:
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
			ld a, 1
			ld (ntc_noadv), a
			ld de, ntc_font		; space
			jp ntc_plat_putglyph
ntc_bs_none:
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_cls - clear screen memory, cursor home
; ------------------------------------------------------------
ntc_plat_cls:
			ld hl, #C000
			ld de, #C001
			ld bc, #3FFF
			ld (hl), 0
			ldir
			xor a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_mode - A = mode (0-2, 3 = 2). Gate array mode with both
; ROMs off, set text layout, clear screen
; ------------------------------------------------------------
ntc_plat_mode:
			cp 3
			jr c, ntc_md_ok
			ld a, 2
ntc_md_ok:
			ld (ntc_smode), a
			ld c, a
			or #8C
			ld b, #7F
			out (c), a
			ld a, 1
			ld (ntc_sinit), a
			ld a, c
			add a, a
			add a, a
			ld c, a
			ld b, 0
			ld hl, ntc_modetab
			add hl, bc
			ld de, ntc_sbpc
			ld bc, 4
			ldir
			jp ntc_plat_cls

; ------------------------------------------------------------
; ntc_plat_locate - H = column, L = row, 1 based, kept on screen
; ------------------------------------------------------------
ntc_plat_locate:
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
			jp (ix)

;## ntc_plat_key ntc_plat_data
; ------------------------------------------------------------
; ntc_plat_scankey - A = ASCII of a key pressed since the last scan,
; 0 if none
; ------------------------------------------------------------
ntc_plat_scankey:
			ld bc, #F40E		; PSG register 14
			out (c), c
			ld bc, #F6C0		; PSG: select register
			out (c), c
			ld bc, #F600		; PSG: inactive
			out (c), c
			ld bc, #F792		; PPI port A input
			out (c), c
			ld hl, ntc_kcur
			ld a, #40			; PSG read + line 0
ntc_ks_line:
			ld b, #F6
			out (c), a
			ld b, #F4
			in d, (c)
			ld (hl), d
			inc hl
			inc a
			cp #4A
			jr nz, ntc_ks_line
			ld bc, #F782		; PPI port A output
			out (c), c
			ld bc, #F600
			out (c), c
			ld a, #FF
			ld (ntc_kidx), a
			ld hl, ntc_kcur
			ld de, ntc_kprev
			ld iy, ntc_kign
			ld bc, #0A00		; B = 10 lines, C = key index
ntc_ks_find:
			ld a, (ntc_kidx)
			inc a
			jr nz, ntc_ks_next
			ld a, (hl)
			cpl
			ex de, hl
			and (hl)			; pressed now, released last scan
			ex de, hl
			and (iy+0)			; not shift / control / caps
			jr z, ntc_ks_next
ntc_ks_bit:
			rrca
			jr c, ntc_ks_got
			inc c
			jr ntc_ks_bit
ntc_ks_got:
			ld a, c
			ld (ntc_kidx), a
ntc_ks_next:
			ld a, c
			and #F8
			add a, 8
			ld c, a
			inc hl
			inc de
			inc iy
			djnz ntc_ks_find
			ld hl, ntc_kcur
			ld de, ntc_kprev
			ld bc, 10
			ldir
			ld a, (ntc_kidx)
			cp #FF
			jr z, ntc_ks_none
			ld e, a
			ld d, 0
			ld hl, ntc_keymap
			ld a, (ntc_kcur + 2)
			bit 5, a			; shift
			jr nz, ntc_ks_map
			ld hl, ntc_keymaps
ntc_ks_map:
			add hl, de
			ld a, (hl)
			jp (ix)
ntc_ks_none:
			xor a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_getkey - wait for a key press, A = ASCII
; ------------------------------------------------------------
ntc_plat_getkey:
			ld (ntc_klink), ix
ntc_gk_scan:
			ld ix, ntc_gk_back
			jp ntc_plat_scankey
ntc_gk_back:
			or a
			jr nz, ntc_gk_done
			ld bc, 1000			; about 6ms between scans (debounce)
ntc_gk_delay:
			dec bc
			ld a, b
			or c
			jr nz, ntc_gk_delay
			jr ntc_gk_scan
ntc_gk_done:
			ld ix, (ntc_klink)
			jp (ix)

; keys that never count as a press on their own (shift, control, caps)
ntc_kign:		db #FF, #FF, #5F, #FF, #FF, #FF, #FF, #FF, #BF, #FF

; matrix line 0-9, bit 0-7 -> ASCII (0 = ignored)
ntc_keymap:
			db 0, 0, 0, "9", "6", "3", 13, "."			; up right down f9 f6 f3 enter f.
			db 0, 0, "7", "8", "5", "1", "2", "0"		; left copy f7 f8 f5 f1 f2 f0
			db 0, "[", 13, "]", "4", 0, 92, 0			; clr [ return ] f4 shift \ control
			db "^", "-", "@", "p", ";", ":", "/", "."
			db "0", "9", "o", "i", "l", "k", "m", ","
			db "8", "7", "u", "y", "h", "j", "n", " "
			db "6", "5", "r", "t", "g", "f", "b", "v"
			db "4", "3", "e", "w", "s", "d", "c", "x"
			db "1", "2", 27, "q", 9, "a", 0, "z"		; 1 2 esc q tab a caps z
			db 0, 0, 0, 0, 0, 0, 0, 127				; joystick, del
ntc_keymaps:
			db 0, 0, 0, "9", "6", "3", 13, "."
			db 0, 0, "7", "8", "5", "1", "2", "0"
			db 0, "{", 13, "}", "4", 0, "`", 0
			db "^", "=", "|", "P", "+", "*", "?", ">"
			db "_", ")", "O", "I", "L", "K", "M", "<"
			db "(", 39, "U", "Y", "H", "J", "N", " "
			db "&", "%", "R", "T", "G", "F", "B", "V"
			db "$", "#", "E", "W", "S", "D", "C", "X"
			db "!", 34, 27, "Q", 9, "A", 0, "Z"
			db 0, 0, 0, 0, 0, 0, 0, 127

;## ntc_plat_frame
; ------------------------------------------------------------
; ntc_plat_frame - wait for the start of vsync (PPI port B bit 0)
; ------------------------------------------------------------
ntc_plat_frame:
			ld b, #F5
ntc_fr_in:
			in a, (c)
			rra
			jr c, ntc_fr_in
ntc_fr_wait:
			in a, (c)
			rra
			jr nc, ntc_fr_wait
			jp (ix)

;## ntc_plat_exit ntc_plat_data
; ------------------------------------------------------------
; ntc_plat_exit - before returning to the caller: upper ROM back on
; (lower off) if the screen was set up
; ------------------------------------------------------------
ntc_plat_exit:
			ld a, (ntc_sinit)
			or a
			jr z, ntc_ex_done
			ld a, (ntc_smode)
			or #84
			ld b, #7F
			out (c), a
ntc_ex_done:
			jp (ix)

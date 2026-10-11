; ============================================================
; NTC Platform - CP/M 2.2 / 3 (any Z80 CP/M machine)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A .COM program at #0100. Console through BDOS function 6
; (direct console I/O: no ^C / ^S checks, no echo). The
; program has its own real stack (CP/M's CCP stack is small)
; and ends with a warm boot (jp 0).
;
; BDOS needs a real stack: SP is the thread, so each call goes
; through ntc_bdos, which switches SP to ntc_csp, lets
; interrupts in (many BIOSes scan keys on interrupts), calls
; address 5 and switches back. The thread never sees call/push.
;
; Without Option Terminal the console is a stream: no cursor
; positioning, Cls prints a new line, Locate does nothing.
; Option Terminal VT52 (Amstrad CP/M on the CPC and PCW, many
; others) or ANSI (most emulators and modern terminals) gives Cls
; and Locate with the terminal's codes (NTC_TERM, set by the
; compiler: 0 none, 1 VT52, 2 ANSI). Mode does nothing. 80
; columns are counted for Tab; the terminal does its own wrapping.
; ============================================================
;@name     CP/M 2.2 / 3 (BDOS console)
;@org      #0100
;@text     byte
;@scrinit  0
;@irq      0
;@stack    ntc_cpmstack
;@cols     80
;@rows     24
; ============================================================

;## ntc_plat_data
ntc_curx:		db 0			; column (0 based) - counted for Tab
ntc_cury:		db 0			; not used (a stream has no rows)
ntc_scols:		db 80			; columns
ntc_bdosa:		db 0			; ntc_bdos: A on return
				ds 256			; the program's real stack
ntc_cpmstack:

;## ntc_plat_bdos ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_bdos - C = BDOS function, DE = argument. A (also in ntc_bdosa)
; and HL come back. IX is kept. Interrupts are on during the call.
; ------------------------------------------------------------
ntc_bdos:
			ld (ntc_hostix), ix
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			call 5
			di
			ld sp, (ntc_ip)
			ld (ntc_bdosa), a
			ld ix, (ntc_hostix)
			jp (ix)

;## ntc_plat_screen ntc_plat_bdos ntc_plat_data ntc_data
; ntc_plat_putc - A = character: BDOS 6, count the column
ntc_plat_putc:
			ld e, a
			ld c, 6
			ld (ntc_pclink), ix
			ld ix, ntc_pc_back
			jp ntc_bdos
ntc_pc_back:
			ld ix, (ntc_pclink)
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			cp b
			jr c, ntc_pc_col
			xor a					; the terminal wrapped
ntc_pc_col:
			ld (ntc_curx), a
			jp (ix)

; ntc_plat_newline - CR LF
ntc_plat_newline:
			ld (ntc_pclink), ix
			ld e, 13
			ld c, 6
			ld ix, ntc_nl_lf
			jp ntc_bdos
ntc_nl_lf:
			ld e, 10
			ld c, 6
			ld ix, ntc_nl_done
			jp ntc_bdos
ntc_nl_done:
			xor a
			ld (ntc_curx), a
			ld ix, (ntc_pclink)
			jp (ix)

; ntc_plat_backspace - BS, space, BS (only on the current line)
ntc_plat_backspace:
			ld a, (ntc_curx)
			or a
			jr z, ntc_bs_none
			dec a
			ld (ntc_curx), a
			ld (ntc_pclink), ix
			ld e, 8
			ld c, 6
			ld ix, ntc_bs_sp
			jp ntc_bdos
ntc_bs_sp:
			ld e, ' '
			ld c, 6
			ld ix, ntc_bs_back
			jp ntc_bdos
ntc_bs_back:
			ld e, 8
			ld c, 6
			ld ix, (ntc_pclink)
			jp ntc_bdos
ntc_bs_none:
			jp (ix)

	IF NTC_TERM = 0
; ntc_plat_cls - a stream can't be cleared: a new line (unless at the start)
ntc_plat_cls:
			ld a, (ntc_curx)
			or a
			jr nz, ntc_plat_newline
			jp (ix)

; ntc_plat_locate - nothing on a stream
ntc_plat_locate:
			jp (ix)
	ELSE
; ntc_plat_cls - clear and home with the terminal's codes
ntc_plat_cls:
			xor a
			ld (ntc_curx), a
			ld hl, ntc_term_cls
			jp ntc_cpm_puts

; ntc_plat_locate - H = column, L = row, 1 based (kept on an 80 x 24 screen)
ntc_plat_locate:
			ld a, h
			or a
			jr nz, ntc_lc_x
			inc a
ntc_lc_x:
			cp 81
			jr c, ntc_lc_xok
			ld a, 80
ntc_lc_xok:
			ld h, a
			dec a
			ld (ntc_curx), a
			ld a, l
			or a
			jr nz, ntc_lc_y
			inc a
ntc_lc_y:
			cp 25
			jr c, ntc_lc_yok
			ld a, 24
ntc_lc_yok:
			ld l, a
			ld de, ntc_term_buf
		IF NTC_TERM = 1
			; VT52: ESC Y row+31 column+31
			ld a, 27
			ld (de), a
			inc de
			ld a, 'Y'
			ld (de), a
			inc de
			ld a, l
			add a, 31
			ld (de), a
			inc de
			ld a, h
			add a, 31
			ld (de), a
			inc de
		ELSE
			; ANSI: ESC [ row ; column H
			ld a, 27
			ld (de), a
			inc de
			ld a, '['
			ld (de), a
			inc de
			ld a, l
			ld b, '0' - 1
ntc_lc_r10:
			inc b
			sub 10
			jr nc, ntc_lc_r10
			add a, 10 + '0'
			ld c, a
			ld a, b
			cp '0'
			jr z, ntc_lc_r1
			ld (de), a
			inc de
ntc_lc_r1:
			ld a, c
			ld (de), a
			inc de
			ld a, ';'
			ld (de), a
			inc de
			ld a, h
			ld b, '0' - 1
ntc_lc_c10:
			inc b
			sub 10
			jr nc, ntc_lc_c10
			add a, 10 + '0'
			ld c, a
			ld a, b
			cp '0'
			jr z, ntc_lc_c1
			ld (de), a
			inc de
ntc_lc_c1:
			ld a, c
			ld (de), a
			inc de
			ld a, 'H'
			ld (de), a
			inc de
		ENDIF
			xor a
			ld (de), a
			ld hl, ntc_term_buf
			jp ntc_cpm_puts

; ntc_cpm_puts - HL = 0 terminated codes, each through BDOS 6
ntc_cpm_puts:
			ld (ntc_cplink), ix
ntc_cps_loop:
			ld a, (hl)
			or a
			jr z, ntc_cps_done
			inc hl
			ld (ntc_cpsp), hl
			ld e, a
			ld c, 6
			ld ix, ntc_cps_next
			jp ntc_bdos
ntc_cps_next:
			ld hl, (ntc_cpsp)
			jr ntc_cps_loop
ntc_cps_done:
			ld ix, (ntc_cplink)
			jp (ix)
ntc_cplink:		dw 0
ntc_cpsp:		dw 0
ntc_term_buf:	ds 10
		IF NTC_TERM = 1
ntc_term_cls:	db 27, "E", 27, "H", 0		; VT52: clear, home
		ELSE
ntc_term_cls:	db 27, "[2J", 27, "[H", 0	; ANSI: clear, home
		ENDIF
	ENDIF

; ntc_plat_mode - nothing on a terminal
ntc_plat_mode:
			jp (ix)
ntc_pclink:		dw 0

;## ntc_plat_key ntc_plat_bdos ntc_data
; ntc_plat_scankey - A = key or 0 (BDOS 6, E = #FF)
ntc_plat_scankey:
			ld e, #FF
			ld c, 6
			jp ntc_bdos

; ntc_plat_getkey - wait for a key (BDOS 6 until there is one)
ntc_plat_getkey:
			ld (ntc_gklink), ix
ntc_gk_poll:
			ld e, #FF
			ld c, 6
			ld ix, ntc_gk_back
			jp ntc_bdos
ntc_gk_back:
			or a
			jr z, ntc_gk_poll
			ld ix, (ntc_gklink)
			jp (ix)
ntc_gklink:		dw 0

;## ntc_plat_frame
ntc_plat_frame:
			jp (ix)

;## ntc_plat_ticks
; ntc_plat_ticks - CP/M has no clock it shares: 0
ntc_plat_ticks:
			ld hl, 0
			jp (ix)

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - warm boot back to CP/M
ntc_plat_exit:
			jp 0

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
; Font    the CPC's own: the first mode set copies chars 32-126 from the
;         lower ROM (#3900) into ntc_font.
; ROMs    mode set turns both ROMs off (scroll reads #C000). In the keyword
;         library ROM (Library: ROM, NTC_ROMLIB = 1) the upper ROM - that ROM -
;         stays on, and goes off only while the screen is read (scroll, Graphics).
;         ntc_plat_exit turns the upper ROM back on (for a CALL from
;         BASIC). The firmware's own idea of the mode is not updated.
; IRQ     normal mode only: interrupts run between keywords. With the
;         lower ROM off the Z80 takes RST #38 from RAM, so ntc_plat_irqon
;         puts a small handler there (the firmware's would turn the ROMs
;         back on). ntc_plat_exit puts the old 3 bytes back.
; ============================================================
;@name     Amstrad CPC - direct hardware, no firmware
;@org      #0040
;@text     glyph
;@scrinit  1
;@irq      1
;@cols     40
;@rows     25
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
ntc_pgstk:		ds 32			; putglyph: the stack an interrupt uses between characters
ntc_pgstk_top:
ntc_noadv:		db 0			; 1 = draw without moving the cursor
ntc_wrapped:	db 0			; 1 = the last character wrapped to the next line
ntc_pgrow:		db 0			; draw / scroll counter
ntc_pgaddr:		dw 0			; draw / scroll address
ntc_klink:		dw 0			; return for ntc_plat_getkey
ntc_kidx:		db 0			; key index found by the scan
ntc_kcur:		ds 10			; matrix this scan (0 = pressed)
ntc_kprev:		db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ntc_irqset:		db 0			; 1 = our interrupt handler is at #38
ntc_irqold:		ds 3			; the 3 bytes it replaced
ntc_irqhl:		dw 0			; handler scratch
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none
	IF NTC_ROMLIB
ntc_uroff:		db 0			; (ROM) 1 = the upper ROM is off while the screen is read
	ENDIF
ntc_modetab:	db 4, 20, #C0, 2		; mode 0
				db 2, 40, #F0, 4		; mode 1
				db 1, 80, #FF, 8		; mode 2

; (ntc_plat_scroll, ntc_plat_cls: their own section - the ROM runs them from RAM)
;## ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
; ------------------------------------------------------------
; ntc_plat_putc - A = character 32-126 (others print as ?), draw it
; ------------------------------------------------------------
ntc_plat_putc:
			sub 32
			jr c, ntc_pc_bad
			cp 95
			jr c, ntc_pc_ok
ntc_pc_bad:
			ld a, '?' - 32
ntc_pc_ok:
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_font
			add hl, de
			ex de, hl
			; fall into ntc_plat_putglyph

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
			ld a, (ntc_sbpc)		; mode 1 (2 bytes a row) and 2 (1 byte): their own loops
			cp 2
			jr z, ntc_pg_m1
			dec a
			jr z, ntc_pg_m2
			ld b, 8					; mode 0: 4 bytes a row, 2 pixels each (pen 1: bits 7, 6)
ntc_pg_m0lp:
			ld a, (de)
			inc de
			ld c, a
			and #C0
			ld (hl), a
			inc hl
			ld a, c
			rlca
			rlca
			ld c, a
			and #C0
			ld (hl), a
			inc hl
			ld a, c
			rlca
			rlca
			ld c, a
			and #C0
			ld (hl), a
			inc hl
			ld a, c
			rlca
			rlca
			and #C0
			ld (hl), a
			dec hl
			dec hl
			dec hl
			ld a, h
			add a, 8
			ld h, a
			djnz ntc_pg_m0lp
			jr ntc_pg_drawn
ntc_pg_m1:
			ld b, 8
ntc_pg_m1lp:
			ld a, (de)				; pen 1: pixels 0-3 in the high nibble, 4-7 next
			inc de
			ld c, a
			and #F0
			ld (hl), a
			inc hl
			ld a, c
			rlca
			rlca
			rlca
			rlca
			and #F0
			ld (hl), a
			dec hl
			ld a, h
			add a, 8
			ld h, a
			djnz ntc_pg_m1lp
			jr ntc_pg_drawn
ntc_pg_m2:
			ld b, 8
ntc_pg_m2lp:
			ld a, (de)
			inc de
			ld (hl), a
			ld a, h
			add a, 8
			ld h, a
			djnz ntc_pg_m2lp
ntc_pg_drawn:
			ld a, (ntc_nmode)		; normal mode: a waiting interrupt gets in after each
			or a					; character (drawing text is long), on a stack of its own
			jr z, ntc_pg_adv		; (SP may be the thread or the real stack here)
			ld (ntc_pgaddr), sp
			ld sp, ntc_pgstk_top
			ei
			nop
			di
			ld sp, (ntc_pgaddr)
ntc_pg_adv:
			ld a, (ntc_noadv)
			or a
			jr nz, ntc_pg_noadv
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			ld (ntc_curx), a
			cp b
			jr z, ntc_pg_wrap
			xor a
			ld (ntc_wrapped), a
			jp (ix)
ntc_pg_wrap:
			ld a, 1				; wrapped: a new line straight after does nothing
			ld (ntc_wrapped), a
			jr ntc_nl_do
ntc_pg_noadv:
			xor a
			ld (ntc_noadv), a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_newline - column 0, next row, scroll at the bottom. Straight
; after a wrap at the last column it does nothing (as the firmware does)
; ------------------------------------------------------------
ntc_plat_newline:
			ld a, (ntc_wrapped)
			or a
			jr z, ntc_nl_do
			xor a
			ld (ntc_wrapped), a
			jp (ix)
ntc_nl_do:
			xor a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			inc a
			cp 25
			jp nc, ntc_plat_scroll
			ld (ntc_cury), a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_backspace - cursor back one and blank that cell
; ------------------------------------------------------------
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
			ld a, 1
			ld (ntc_noadv), a
			ld de, ntc_font		; space
			jp ntc_plat_putglyph
ntc_bs_none:
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
			ld a, (ntc_sinit)
			or a
			jr nz, ntc_md_set
			; the first time: copy the CPC's own font (lower ROM, chars 32-126 at
			; #3900) into ntc_font. The copy runs from #C000 (screen RAM, cleared
			; just after), because the program itself can sit under the lower ROM
		IF NTC_ROMLIB
			jp ntc_fontcopy		; (ROM: it runs here - the lower ROM goes on, this one stays on)
		ELSE
			ld hl, ntc_fontcopy
			ld de, #C000
			ld bc, ntc_fontcopy_end - ntc_fontcopy
			ldir
			jp #C000
		ENDIF
ntc_md_set:
			ld a, (ntc_smode)
			ld c, a
		IF NTC_ROMLIB
			or #84				; (ROM: the upper ROM on)
		ELSE
			or #8C
		ENDIF
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

; copied to #C000 and run there (no jumps inside: it runs at any address)
ntc_fontcopy:
		IF NTC_ROMLIB
			ld bc, #7F80		; lower ROM on, upper ROM (this one) on
		ELSE
			ld bc, #7F88		; lower ROM on, upper ROM off
		ENDIF
			out (c), c
			ld hl, #3900		; the firmware's character matrices, from char 32
			ld de, ntc_font
			ld bc, 95 * 8
			ldir
		IF NTC_ROMLIB
			ld bc, #7F84		; lower ROM off again
		ELSE
			ld bc, #7F8C		; both ROMs off again
		ENDIF
			out (c), c
			jp ntc_md_set
ntc_fontcopy_end:

; ------------------------------------------------------------
; ntc_plat_locate - H = column, L = row, 1 based, kept on screen
; ------------------------------------------------------------
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
			jp (ix)

;## ntc_plat_scroll ntc_plat_data ntc_data @shared @romram
; ------------------------------------------------------------
; ntc_plat_scroll - move rows 1-24 up one, clear row 24
; ------------------------------------------------------------
ntc_plat_scroll:
			ld a, 24
			ld (ntc_cury), a
			ld a, (ntc_nmode)		; normal mode: interrupts in during the long copy
			or a
			jr z, ntc_sc_open
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_sc_open:
		IF NTC_ROMLIB
			ld a, 1				; (ROM: the upper ROM off while the screen is read;
			ld (ntc_uroff), a	; the interrupt handler turns it on for its calls)
			ld a, (ntc_smode)
			or #8C
			ld b, #7F
			out (c), a
		ENDIF
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
			di
		IF NTC_ROMLIB
			ld a, (ntc_smode)	; (ROM: the upper ROM on again)
			or #84
			ld b, #7F
			out (c), a
			xor a
			ld (ntc_uroff), a
		ENDIF
			ld a, (ntc_nmode)
			or a
			jr z, ntc_sc_close
			ld sp, (ntc_ip)
ntc_sc_close:
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_cls - clear screen memory, cursor home
; ------------------------------------------------------------
ntc_plat_cls:
			ld a, (ntc_nmode)		; normal mode: interrupts in during the long copy
			or a
			jr z, ntc_cl_open
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_cl_open:
		IF NTC_ROMLIB
			ld a, 1				; (ROM: the upper ROM off - the fill reads the screen back)
			ld (ntc_uroff), a
			ld a, (ntc_smode)
			or #8C
			ld b, #7F
			out (c), a
		ENDIF
			ld hl, #C000
			ld de, #C001
			ld bc, #3FFF
			ld (hl), 0
			ldir
			di
		IF NTC_ROMLIB
			ld a, (ntc_smode)	; (ROM: the upper ROM on again)
			or #84
			ld b, #7F
			out (c), a
			xor a
			ld (ntc_uroff), a
		ENDIF
			ld a, (ntc_nmode)
			or a
			jr z, ntc_cl_close
			ld sp, (ntc_ip)
ntc_cl_close:
			xor a
			ld (ntc_wrapped), a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_key ntc_plat_data ntc_data @shared
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
			ld a, (ntc_nmode)		; normal mode: interrupts in while waiting
			or a
			jr z, ntc_gk_wait
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_gk_wait:
			ld bc, 1000			; about 6ms between scans (debounce)
ntc_gk_delay:
			dec bc
			ld a, b
			or c
			jr nz, ntc_gk_delay
			di
			ld a, (ntc_nmode)
			or a
			jr z, ntc_gk_scan
			ld sp, (ntc_ip)
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

;## ntc_plat_frame ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_frame - wait for the start of vsync (PPI port B bit 0)
; normal mode: interrupts in while waiting
; ------------------------------------------------------------
ntc_plat_frame:
			ld a, (ntc_nmode)
			or a
			jr z, ntc_fr_go
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_fr_go:
			ld b, #F5
ntc_fr_in:
			in a, (c)
			rra
			jr c, ntc_fr_in
ntc_fr_wait:
			in a, (c)
			rra
			jr nc, ntc_fr_wait
			di
			ld a, (ntc_nmode)
			or a
			jr z, ntc_fr_done
			ld sp, (ntc_ip)
ntc_fr_done:
			jp (ix)

;## ntc_plat_ticks ntc_data
; ------------------------------------------------------------
; ntc_plat_ticks - HL = interrupt count (300 a second, normal mode)
; ------------------------------------------------------------
ntc_plat_ticks:
			ld hl, (ntc_ticks)
			jp (ix)

;## ntc_plat_irq ntc_plat_data ntc_data ntc_plat_irqh @shared
; ------------------------------------------------------------
; ntc_plat_irqon - put the interrupt handler at #38 (IM 1)
; ------------------------------------------------------------
ntc_plat_irqon:
			ld hl, (#0038)
			ld (ntc_irqold), hl
			ld a, (#003A)
			ld (ntc_irqold + 2), a
			ld a, #C3			; jp ntc_irq
			ld (#0038), a
			ld hl, ntc_irq
			ld (#0039), hl
			ld a, 1
			ld (ntc_irqset), a
			jp (ix)


;## ntc_plat_irqh ntc_plat_data ntc_data @shared @romram
; the handler: runs on the real stack, between keywords. Counts ticks
; (300 a second). AF goes to AF', HL to RAM; interrupt classes' counting
; (ntc_irqv) is a call, keeping the other registers.
ntc_irq:
			ex af, af'
			ld (ntc_irqhl), hl
			ld hl, (ntc_ticks)
			inc hl
			ld (ntc_ticks), hl
			ld a, (ntc_hookon)	; an Interrupt hook: run it at the next safe point
			or a
			jr z, ntc_irq_nohook
			ld (ntc_hookpend), a
ntc_irq_nohook:
			ld hl, (ntc_irqv)		; interrupt classes (Option Class Interrupt): count them
			ld a, h
			or l
		IF NTC_ROMLIB
			call nz, ntc_irq_rom	; (the handler runs on the real stack)
		ELSE
			call nz, ntc_irq_jp		; (the handler runs on the real stack)
		ENDIF
			ld hl, (ntc_irqhl)
			ex af, af'
			ei
			ret
ntc_irq_jp:
			jp (hl)
		IF NTC_ROMLIB
; (ROM) the counting is in the main ROM of the set: the upper ROM on and the
; main ROM selected for the call (the screen code may have the upper ROM off,
; a far routine may have another ROM of the set in), then both as they were
ntc_irq_rom:
			push bc
			ld a, (ntc_smode)
			or #84
			ld b, #7F
			out (c), a
			ld bc, (ntc_rx_s0)		; B = #DF, C = the main ROM's slot
			out (c), c
			call ntc_irq_jp
			ld bc, (ntc_rx_cur)		; the ROM that was in
			out (c), c
			ld a, (ntc_uroff)
			or a
			jr z, ntc_irq_ron
			ld a, (ntc_smode)
			or #8C
			ld b, #7F
			out (c), a
ntc_irq_ron:
			pop bc
			ret
		ENDIF

;## ntc_plat_exit ntc_plat_data
; ------------------------------------------------------------
; ntc_plat_exit - before returning to the caller: interrupt handler
; out, upper ROM back on (lower off) if the screen was set up
; ------------------------------------------------------------
ntc_plat_exit:
			ld bc, #7FC0		; RAM setting back to plain (a Memory page may be in #4000)
			out (c), c
			ld a, (ntc_irqset)
			or a
			jr z, ntc_ex_rom
			ld hl, (ntc_irqold)
			ld (#0038), hl
			ld a, (ntc_irqold + 2)
			ld (#003A), a
			xor a
			ld (ntc_irqset), a
ntc_ex_rom:
			ld a, (ntc_sinit)
			or a
			jr z, ntc_ex_done
			ld a, (ntc_smode)
			or #84
			ld b, #7F
			out (c), a
ntc_ex_done:
			jp (ix)

;## ntc_plat_memtop
; ntc_plat_memtop - HL = the first byte the Memory class's Small heap must not
; use: #A600 (the firmware's and AMSDOS's RAM is above). Called on the real
; stack (call / ret), only by the Memory class.
ntc_plat_memtop:
		IF NTC_ROMLIB
			ld hl, NTC_ROMDATA	; (ROM: its RAM starts there)
		ELSE
			ld hl, #A600
		ENDIF
			ret

;## ntc_plat_romsel ntc_plat_data @shared @ramonly
; rd_sel - A = a slot: that ROM in at #C000 (the upper ROM on, straight to the
; gate array and #DFxx). rd_unsel - back as NTC runs (Library: ROM: the
; keyword ROM in; else both ROMs off). From RAM only (@ramonly). Keep DE,
; HL (rd_unsel also AF)
rd_old:			dw 0
rd_sel:
			push hl
			push de
			ld e, a
			ld a, (ntc_smode)
			or #84				; the upper ROM on
			ld b, #7F
			out (c), a
		IF NTC_ROMLIB
			ld bc, (ntc_rx_cur)
			ld (rd_old), bc
			ld c, e
			ld b, #DF
			ld (ntc_rx_cur), bc	; (the interrupt handler puts this one back)
		ELSE
			ld c, e
			ld b, #DF
		ENDIF
			out (c), c
			pop de
			pop hl
			ret
rd_unsel:
			push af
			push bc
		IF NTC_ROMLIB
			ld bc, (rd_old)
			ld (ntc_rx_cur), bc
			out (c), c			; the keyword ROM
		ELSE
			ld a, (ntc_smode)
			or #8C				; both ROMs off
			ld b, #7F
			out (c), a
		ENDIF
			pop bc
			pop af
			ret

;## ntc_plat_rmr ntc_plat_data
; ntc_plat_rmr - A = the gate array's ROM / mode byte now (#8x: screen mode,
; lower and upper ROM on / off), so Memory's CallBank can turn both ROMs off
; and put them back. Keeps BC, DE, HL.
ntc_plat_rmr:
			ld a, (ntc_smode)
		IF NTC_ROMLIB
			or #84				; (ROM: the upper ROM on)
		ELSE
			or #8C
		ENDIF
			ret

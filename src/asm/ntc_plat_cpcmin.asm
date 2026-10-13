; ============================================================
; NTC Platform - Amstrad CPC, minimal firmware: NTC's own screen and keys,
; the firmware kept alive for discs (AMSDOS), tape and other ROMs
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
; Firmware: the screen, keys and interrupts are NTC's, as on the cpc
;         platform; the firmware's RAM (#A700-#BFFF) is left alone and every
;         firmware call (FileSystem, System.Command) hands the machine back
;         for its length - see the File system part at the end.
; ============================================================
;@name     Amstrad CPC - minimal firmware (own screen and keys, firmware for discs and ROMs)
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

; ============================================================
; Firmware calls (FileSystem, System.Command) - AMSDOS and other ROMs
; through the firmware, on a platform that otherwise doesn't use it. Each call hands
; the machine back for its length (fs_fwon / fs_fwoff): the firmware's
; interrupt entry at #38 and interrupts on (AMSDOS times the motor with
; firmware events), then NTC's handler, mode and ROM setting and the
; screen start again. Needs: the firmware's RAM intact (#A700-#BFFF:
; the program must end below #A600, checked when assembling), AMSDOS
; running (Option RomEnable 7 after RUN"). While a file call runs the
; screen may show the firmware's mode, and its messages (disc missing,
; Retry / Cancel) appear on NTC's screen.
; The rest is the cpcfw platform's file code (CAS IN / OUT DIRECT, |TAPE,
; |DISC, volumes as AMSDOS commands).
; ============================================================
FS_NOTFOUND	equ -2
FS_TOOBIG	equ -8
FS_FAILED	equ -9
FS_BADNAME	equ -4

;## ntc_plat_fs ntc_plat_data ntc_plat_irq ntc_data ntc_buf2k @shared
fs_a1:			dw 0
fs_a2:			dw 0
fs_a3:			dw 0
fs_res:			dw 0
fs_sp:			dw 0
fs_esp:			dw 0
fs_six:			dw 0
fs_siy:			dw 0
fs_len:			dw 0
fs_nostore:		db 0
fs_hmode:		db 0			; 0 no file open, 1 reading, 2 writing (Open)
fs_init:		db 0			; 1 = checked: is AMSDOS running?
fs_dos:			db 0			; 1 = a DOS is there (|DISC found)
fs_devd:		db 0			; the device in use: 0 tape, 1 disc
fs_n_tape:		db "TAPE", 0
fs_n_disc:		db "DISC", 0
fs_n_all:		db "TAPE,DISC", 0
fs_c_tape:		db "TAP", "E" + #80
fs_c_disc:		db "DIS", "C" + #80
fs_vol:			ds 9			; the volume in use ("" = not known)
fs_vols:		ds 145			; the volumes that worked, "A,C,M" (up to 16 of up to 8 letters)
fs_tmpn:		ds 9			; a volume name, capitals
fs_rsxn:		ds 17			; a command name (last letter + #80), up to 16 letters
fs_buf			equ ntc_buf		; the 2K buffer CAS IN OPEN / CAS OUT OPEN want (shared with Memory.Copy)
			ASSERT ntc_free <= #A600, "FileSystem on cpcmin: the program and its arrays must end below #A600 (AMSDOS's RAM)"

fs_go0:
			ld a, 1
			ld (fs_nostore), a
			jr fs_gostart
fs_go:
			xor a
			ld (fs_nostore), a
fs_gostart:
			ld (fs_sp), sp
			ld sp, (ntc_csp)
			ld (fs_six), ix
			ld (fs_siy), iy
			push hl				; the routine
			call fs_fwon			; the firmware's interrupts back, on
			pop hl
			ld (fs_esp), sp
			call fs_jphl
fs_back:
			push hl				; the routine's result
			call fs_fwoff			; NTC's again: interrupts off, handler, mode, ROMs, screen start
			pop hl
			ld ix, (fs_six)
			ld iy, (fs_siy)
			ld a, (fs_nostore)
			or a
			jr nz, fs_gone
			ex de, hl
			ld hl, (fs_res)
			ld (hl), e
			inc hl
			ld (hl), d
fs_gone:
			ld sp, (fs_sp)
			ret
fs_jphl:
			jp (hl)

; fs_fwon - for a firmware call: the firmware's interrupt entry back at #38 (if NTC's
; handler is there), interrupts on. AMSDOS times the drive motor with firmware events.
fs_fwon:
			ld a, (ntc_irqset)
			or a
			jr z, fs_fn_ei
			ld hl, (ntc_irqold)
			ld (#0038), hl
			ld a, (ntc_irqold + 2)
			ld (#003A), a
fs_fn_ei:
			ei
			ret

; fs_fwoff - after it: interrupts off, NTC's handler back, NTC's mode with both ROMs off
; (the firmware puts its own mode / ROM setting in the gate array), the screen start
; back at #C000 (a firmware message may have scrolled the screen)
fs_fwoff:
			di
			ld a, (ntc_irqset)
			or a
			jr z, fs_ff_scr
			ld a, #C3
			ld (#0038), a
			ld hl, ntc_irq
			ld (#0039), hl
fs_ff_scr:
			ld a, (ntc_sinit)
			or a
			ret z				; the screen isn't NTC's yet
			ld a, (ntc_smode)
		IF NTC_ROMLIB
			or #84				; (ROM: the upper ROM on)
		ELSE
			or #8C
		ENDIF
			ld b, #7F
			out (c), a
			ld bc, #BC0C
			out (c), c
			ld bc, #BD30
			out (c), c
			ld bc, #BC0D
			out (c), c
			ld bc, #BD00
			out (c), c
			ret
fs_err:
			ld sp, (fs_esp)
			jr fs_back

; fs_start - the first file call: is AMSDOS running? (no ROMs are started here:
; Option RomEnable does that in the start code)
fs_start:
			ld a, (fs_init)
			or a
			ret nz
			inc a
			ld (fs_init), a
			ld a, (#BC77)
			cp #DF				; a far call: AMSDOS has the cassette calls
			jr nz, fs_st_find	; not running (RUN" dropped it), or |TAPE: tape
			ld a, 1
			ld (fs_devd), a
		IF NTC_ROMENABLE
			ld hl, fs_n_a1		; started by the program: AMSDOS starts on drive A
			call fs_addvol
			ld hl, fs_n_a1
			ld de, fs_vol
			ld bc, 2
			ldir
		ENDIF
fs_st_find:
			ld hl, fs_c_disc
			call #BCD4			; KL FIND COMMAND: is |DISC there?
			ld a, 1
			jr c, fs_st_dos
			xor a
fs_st_dos:
			ld (fs_dos), a
			ret
fs_n_a1:		db "A", 0

; fs_rsx - HL = an AMSDOS command's name (last letter + #80): run it, no arguments.
; Not there goes to fs_err (NotFound)
fs_rsx:
			call #BCD4			; KL FIND COMMAND: HL = address, C = ROM
			jr nc, fs_rx_none
			xor a				; no arguments
			ld ix, fs_rx_none	; (the argument list: none)
			call #001B			; KL FAR PCALL
			ret
fs_rx_none:
			ld hl, FS_NOTFOUND
			jp fs_err

; fs_strout - HL = text (0 ended) into the String result at (fs_res), cut at its size
fs_strout:
			ex de, hl
			ld hl, (fs_res)
			dec hl
			ld b, (hl)			; the capacity
			inc hl
			ex de, hl
fs_so_lp:
			ld a, (hl)
			or a
			jr z, fs_so_end
			ld c, a
			ld a, b
			or a
			jr z, fs_so_end
			ld a, c
			ld (de), a
			inc hl
			inc de
			dec b
			jr fs_so_lp
fs_so_end:
			xor a
			ld (de), a
			ret

; fs_same - HL = the program's text, DE = a name in capitals: Z when the same (any case)
fs_same:
			ld a, (hl)
			call fs_up
			ld c, a
			ld a, (de)
			cp c
			ret nz
			or a
			ret z
			inc hl
			inc de
			jr fs_same

; fs_volname - HL = text: a volume name (up to 8 letters, a ':' after it is allowed) into
; fs_tmpn (capitals) and fs_rsxn (last letter + #80). NZ: not a name
fs_volname:
			ld de, fs_tmpn
			ld b, 0
fs_vn_lp:
			ld a, (hl)
			or a
			jr z, fs_vn_end
			cp ':'
			jr z, fs_vn_colon
			call fs_up
			ld (de), a
			inc hl
			inc de
			inc b
			ld a, b
			cp 9
			jr c, fs_vn_lp
			or a				; too long: NZ (A = 9)
			ret
fs_vn_colon:
			inc hl
			ld a, (hl)
			or a
			ret nz				; something after the ':'
fs_vn_end:
			xor a
			ld (de), a
			ld a, b
			or a
			jr z, fs_vn_bad
			ld hl, fs_tmpn
			ld de, fs_rsxn
			ld c, b
			ld b, 0
			ldir
			dec de
			ld a, (de)
			or #80
			ld (de), a
			xor a				; Z: a name
			ret
fs_vn_bad:
			inc a				; NZ
			ret

; fs_addvol - HL = a volume name (capitals, 0 ended): into fs_vols if not there and room
fs_addvol:
			ld (fs_len), hl		; (the name)
			ld de, fs_vols
fs_av_entry:
			ld a, (de)
			or a
			jr z, fs_av_add		; the end of the list: not there
			ld hl, (fs_len)
fs_av_cmp:
			ld a, (de)
			cp ','
			jr z, fs_av_sep
			or a
			jr z, fs_av_sep
			cp (hl)
			jr nz, fs_av_skip
			inc hl
			inc de
			jr fs_av_cmp
fs_av_sep:
			ld a, (hl)			; the entry ended: the same if the name ended too
			or a
			ret z
fs_av_skip:
			ld a, (de)			; on to the next entry
			or a
			jr z, fs_av_add
			inc de
			cp ','
			jr nz, fs_av_skip
			jr fs_av_entry
fs_av_add:
			ld hl, (fs_len)		; DE = the 0 at the end: room for "," + name + 0?
			push hl
			ld b, 0
fs_av_len:
			ld a, (hl)
			or a
			jr z, fs_av_room
			inc hl
			inc b
			jr fs_av_len
fs_av_room:
			pop hl
			push hl
			ld hl, fs_vols + 145 - 2
			or a
			sbc hl, de
			ld a, h
			or a
			jr nz, fs_av_ok		; plenty
			ld a, l
			cp b
			jr nc, fs_av_ok
			pop hl
			ret					; full: not added
fs_av_ok:
			pop hl
			ld a, e
			cp low fs_vols
			jr nz, fs_av_comma
			ld a, d
			cp high fs_vols
			jr z, fs_av_copy
fs_av_comma:
			ld a, ','
			ld (de), a
			inc de
fs_av_copy:
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			or a
			jr nz, fs_av_copy
			ret

; fs_namevol - after a Load / Save that worked: a volume in its name ("C:NAME") joins the list
fs_namevol:
			ld hl, (fs_a1)
			ld b, 9
fs_nv_lp:
			ld a, (hl)
			or a
			ret z
			cp ':'
			jr z, fs_nv_found
			inc hl
			djnz fs_nv_lp
			ret
fs_nv_found:
			ld a, 9
			sub b
			ret z				; ":NAME": no volume
			ld hl, (fs_a1)
			ld de, fs_tmpn
			ld c, a
			ld b, 0
fs_nv_cp:
			ld a, (hl)
			call fs_up
			ld (de), a
			inc hl
			inc de
			dec c
			jr nz, fs_nv_cp
			xor a
			ld (de), a
			ld hl, fs_tmpn
			jp fs_addvol

; Devices(): "TAPE,DISC" with a DOS, "TAPE" without
fs_devices:
			call fs_start
			ld hl, fs_n_all
			ld a, (fs_dos)
			or a
			jp nz, fs_strout
			ld hl, fs_n_tape
			jp fs_strout

; CurrentDevice(): "TAPE" or "DISC"
fs_curdev:
			call fs_start
			ld hl, fs_n_tape
			ld a, (fs_devd)
			or a
			jp z, fs_strout
			ld hl, fs_n_disc
			jp fs_strout

; SelectDevice(name): "TAPE" or "DISC" (any case). OK, NotFound
fs_select:
			call fs_start
			ld hl, (fs_a1)
			ld de, fs_n_tape
			call fs_same
			jr z, fs_se_tape
			ld hl, (fs_a1)
			ld de, fs_n_disc
			call fs_same
			jr nz, fs_se_bad
			ld a, (fs_dos)
			or a
			jr z, fs_se_bad		; no DOS: no disc
			ld hl, fs_c_disc
			call fs_rsx
			ld a, 1
			jr fs_se_done
fs_se_tape:
			ld a, (fs_dos)
			or a
			jr z, fs_se_t2		; no DOS: tape anyway
			ld hl, fs_c_tape
			call fs_rsx
fs_se_t2:
			xor a
fs_se_done:
			ld (fs_devd), a
			ld hl, 0
			ret
fs_se_bad:
			ld hl, FS_NOTFOUND
			ret

; Volumes(): the volumes that worked so far ("A,C")
fs_volumes:
			call fs_start
			ld hl, fs_vols
			jp fs_strout

; CurrentVolume(): the volume last selected ("" = not known)
fs_curvol:
			call fs_start
			ld hl, fs_vol
			jp fs_strout

; SelectVolume(name): runs the DOS's command of that name (|A, |B, |C, |M ... whatever
; the DOS has). OK, NotFound (no such command). It joins Volumes()
fs_selvol:
			call fs_start
			ld hl, (fs_a1)
			call fs_volname
			jr nz, fs_se_bad
			ld hl, fs_rsxn
			call fs_rsx
			ld hl, fs_tmpn
			ld de, fs_vol
			ld bc, 9
			ldir
			ld hl, fs_tmpn
			call fs_addvol
			ld hl, 0
			ret

; Command(name): run a ROM's command (an RSX: |NAME) with no arguments - AMSDOS, M4,
; a utility ROM ... OK, NotFound (no ROM has it). Up to 16 letters
fs_command:
			call fs_start
			ld hl, (fs_a1)
			ld de, fs_rsxn
			ld b, 0
fs_cm_lp:
			ld a, (hl)
			or a
			jr z, fs_cm_end
			call fs_up
			ld (de), a
			inc hl
			inc de
			inc b
			ld a, b
			cp 17
			jr c, fs_cm_lp
fs_cm_bad:
			ld hl, FS_NOTFOUND
			ret
fs_cm_end:
			ld a, b
			or a
			jr z, fs_cm_bad
			dec de
			ld a, (de)
			or #80
			ld (de), a
			ld hl, fs_rsxn
			call fs_rsx
			ld hl, 0
			ret

fs_up:
			cp 'a'
			ret c
			cp 'z' + 1
			ret nc
			sub 32
			ret

; fs_name - B = length of the name at (fs_a1), HL = the name; an empty or too long name goes to fs_err
fs_name:
			ld hl, (fs_a1)
			ld b, 0
fs_nm_lp:
			ld a, (hl)
			or a
			jr z, fs_nm_end
			inc hl
			inc b
			ld a, b
			cp 17
			jr c, fs_nm_lp
fs_nm_bad:
			ld hl, FS_BADNAME
			jp fs_err
fs_nm_end:
			ld a, b
			or a
			jr z, fs_nm_bad
			ld hl, (fs_a1)
			ret

; Load(name, addr, maxlen): bytes loaded (the file's length), or a status.
; A file longer than maxlen is not loaded: FS_TOOBIG
fs_load:
			call fs_start
			ld a, (fs_hmode)	; the buffer is the open file's
			or a
			ld hl, FS_FAILED
			jp nz, fs_err
			call fs_name
			ld de, fs_buf
			call #BC77			; CAS IN OPEN: BC = length, carry = ok
			jr c, fs_ld_open
			ld hl, FS_NOTFOUND
			jp fs_err
fs_ld_open:
			ld (fs_len), bc
			ld hl, (fs_a3)
			or a
			sbc hl, bc
			jr nc, fs_ld_fits
			call #BC7D			; CAS IN ABANDON
			ld hl, FS_TOOBIG
			jp fs_err
fs_ld_fits:
			ld hl, (fs_a2)
			call #BC83			; CAS IN DIRECT
			jr c, fs_ld_read
			call #BC7D
			ld hl, FS_FAILED
			jp fs_err
fs_ld_read:
			call #BC7A			; CAS IN CLOSE
			ld hl, (fs_len)
			push hl
			call fs_namevol
			pop hl
			ret

; Save(name, addr, len): a binary file (type 2, BASIC can LOAD it back). 0 or a status
fs_save:
			call fs_start
			ld a, (fs_hmode)	; the buffer is the open file's
			or a
			ld hl, FS_FAILED
			jp nz, fs_err
			call fs_name
			ld de, fs_buf
			call #BC8C			; CAS OUT OPEN
			jr c, fs_sv_open
			ld hl, FS_FAILED
			jp fs_err
fs_sv_open:
			ld hl, (fs_a2)
			ld de, (fs_a3)
			ld bc, 0			; entry address: none
			ld a, 2				; binary
			call #BC98			; CAS OUT DIRECT
			jr c, fs_sv_done
			call #BC92			; CAS OUT ABANDON
			ld hl, FS_FAILED
			jp fs_err
fs_sv_done:
			call #BC8F			; CAS OUT CLOSE
			ld hl, FS_FAILED
			ret nc
			call fs_namevol
			ld hl, 0
			ret

;## ntc_plat_fsseq ntc_plat_fs @shared @ramonly
; ---- one open file (handle 1), through CAS IN CHAR / CAS OUT CHAR: read a
; file (any type) byte by byte, or write a new text file (type ASCII, as
; BASIC's OPENOUT / PRINT #9 make it). The 2K buffer is the one Load / Save
; use, so Load and Save are refused while a file is open. Not in the keyword
; ROM (room): a Library: ROM program has its own copy.
FS_NOHANDLE	equ -5
FS_BADHANDLE	equ -6
FS_EOFST	equ -7
FS_BADMODE	equ -11
FS_NOTSUP	equ -1
fs_ptr:			dw 0
fs_cnt:			db 0
fs_cap:			db 0

; Open(name, mode): 1, or a status. ForUpdate: NotSupported
fs_open:
			call fs_start
			ld a, (fs_hmode)
			or a
			ld hl, FS_NOHANDLE
			ret nz
			ld hl, (fs_a2)
			ld a, h
			or a
			jr nz, fs_op_bad
			ld a, l
			cp 3
			ld hl, FS_NOTSUP
			ret z
			jr nc, fs_op_bad
			cp 1
			jr c, fs_op_bad
			jr nz, fs_op_out
			call fs_name
			ld de, fs_buf
			call #BC77			; CAS IN OPEN
			ld hl, FS_NOTFOUND
			ret nc
			ld a, 1
			jr fs_op_ok
fs_op_out:
			call fs_name
			ld de, fs_buf
			call #BC8C			; CAS OUT OPEN
			ld hl, FS_FAILED
			ret nc
			ld a, 2
fs_op_ok:
			ld (fs_hmode), a
			ld hl, 1
			ret
fs_op_bad:
			ld hl, FS_BADMODE
			ret

; fs_hchk - (fs_a1) must be handle 1 open for A (1 read, 2 write), else
; fs_err BadHandle
fs_hchk:
			ld hl, (fs_a1)
			dec hl
			ld b, a
			ld a, h
			or l
			jr nz, fs_hc_bad
			ld a, (fs_hmode)
			cp b
			ret z
fs_hc_bad:
			ld hl, FS_BADHANDLE
			jp fs_err

; Close(h): OK, or a status (Failed: the last of a written file didn't go)
fs_closeh:
			ld hl, (fs_a1)
			dec hl
			ld a, h
			or l
			jr nz, fs_hc_bad
			ld a, (fs_hmode)
			or a
			jr z, fs_hc_bad
			ld b, a
			xor a
			ld (fs_hmode), a
			ld a, b
			cp 1
			jr nz, fs_cl_out
			call #BC7A			; CAS IN CLOSE
			jr fs_cl_ok
fs_cl_out:
			call #BC8F			; CAS OUT CLOSE
			ld hl, FS_FAILED
			ret nc
fs_cl_ok:
			call fs_namevol
			ld hl, 0
			ret

; ReadByte(h): 0-255, or EndOfFile
fs_readb:
			ld a, 1
			call fs_hchk
			call #BC80			; CAS IN CHAR
			ld hl, FS_EOFST
			ret nc
			ld l, a
			ld h, 0
			ret

; WriteByte(h, b): OK, or Failed
fs_writeb:
			ld a, 2
			call fs_hchk
			ld a, (fs_a2)
			call #BC95			; CAS OUT CHAR
			ld hl, FS_FAILED
			ret nc
			ld hl, 0
			ret

; Read(h, addr, count): bytes read (fewer at the end)
fs_read:
			ld a, 1
			call fs_hchk
			ld hl, (fs_a2)
			ld de, (fs_a3)
			ld bc, 0
fs_rd_lp:
			ld a, d
			or e
			jr z, fs_rd_end
			bit 7, d
			jr nz, fs_rd_end
			push hl
			push de
			push bc
			call #BC80			; CAS IN CHAR
			pop bc
			pop de
			pop hl
			jr nc, fs_rd_end
			ld (hl), a
			inc hl
			inc bc
			dec de
			jr fs_rd_lp
fs_rd_end:
			ld h, b
			ld l, c
			ret

; Write(h, addr, count): count, or Failed
fs_write:
			ld a, 2
			call fs_hchk
			ld hl, (fs_a2)
			ld de, (fs_a3)
fs_wr_lp:
			ld a, d
			or e
			jr z, fs_wr_end
			bit 7, d
			jr nz, fs_wr_end
			ld a, (hl)
			push hl
			push de
			call #BC95			; CAS OUT CHAR
			pop de
			pop hl
			jr nc, fs_wr_fail
			inc hl
			dec de
			jr fs_wr_lp
fs_wr_end:
			ld hl, (fs_a3)
			ret
fs_wr_fail:
			ld hl, FS_FAILED
			ret

; Eof(h): True (-1) when there is nothing more to read (or h is not a file being read)
fs_eof:
			ld hl, (fs_a1)
			dec hl
			ld a, h
			or l
			jr nz, fs_ef_yes
			ld a, (fs_hmode)
			cp 1
			jr nz, fs_ef_yes
			call #BC89			; CAS TEST EOF: carry = more to read
			ld hl, 0
			ret c
fs_ef_yes:
			ld hl, -1
			ret

; ReadLine(h): the next line (up to LF; CR dropped), "" at the end
fs_readln:
			ld hl, (fs_res)
			ld (hl), 0
			dec hl
			ld a, (hl)
			ld (fs_cap), a			; the result's capacity
			inc hl
			ld (fs_ptr), hl
			xor a
			ld (fs_cnt), a
			ld a, 1
			call fs_hchk
fs_rl_lp:
			call #BC80			; CAS IN CHAR
			jr nc, fs_rl_end
			cp 10
			jr z, fs_rl_end
			cp 13
			jr z, fs_rl_lp
			ld c, a
			ld a, (fs_cap)
			ld hl, fs_cnt
			cp (hl)
			jr z, fs_rl_lp			; full: the rest of the line is dropped
			inc (hl)
			ld hl, (fs_ptr)
			ld (hl), c
			inc hl
			ld (fs_ptr), hl
			jr fs_rl_lp
fs_rl_end:
			ld hl, (fs_ptr)
			ld (hl), 0
			ret

; WriteLine(h, s): the text and CR LF. OK, or Failed
fs_writeln:
			ld a, 2
			call fs_hchk
			ld hl, (fs_a2)
fs_wl_lp:
			ld a, (hl)
			or a
			jr z, fs_wl_end
			push hl
			call #BC95			; CAS OUT CHAR
			pop hl
			jp nc, fs_wr_fail
			inc hl
			jr fs_wl_lp
fs_wl_end:
			ld a, 13
			call #BC95
			jp nc, fs_wr_fail
			ld a, 10
			call #BC95
			jp nc, fs_wr_fail
			ld hl, 0
			ret

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

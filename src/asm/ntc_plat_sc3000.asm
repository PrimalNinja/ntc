; ============================================================
; NTC Platform - Sega SC-3000 (and an SG-1000 with the SK-1100
; keyboard): a cartridge ROM
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; No call, no push in the thread: every routine is entered with jp,
; return address in IX, and ends with jp (ix). The routines that need a
; stack get the real one through ntc_vcall (asm/ntc_lib_vdp.asm).
;
; The program is a cartridge: ROM from #0000 (8K, 16K, 32K or 48K - the
; file NAME.SC), RAM #C000-#C7FF (2K, the SC-3000's own). The code, the
; threads and the strings stay in the ROM; the variables go to RAM
; (romLayout in the compiler). The RAM:
;   #C000 - #C004   the interrupt vector and the frame count (below)
;   #C010 - ...     the variables, then the arrays, the Memory heap
;   ... - #C7FF     the stack (128 bytes and up)
;
; Screen  the TMS9918A / TMS9929A at #BE (data) / #BF (control):
;         mode 1 = 40 x 24 (Text 1), mode 0 = 32 x 24 (Graphics 1), mode 2
;         = 40 x 24 as well. The font is ntc_font6 (lib_vdp), white on
;         dark blue.
; Keys    the keyboard matrix through the PPI (#DC port A, #DD port B, #DE
;         port C: the row, #DF control): rows 0-6 of 12 keys, row 7 the
;         joypads. New presses only, no auto repeat.
; IRQ     the VDP's frame interrupt (IM 1, #0038): the frame count (Ticks:
;         50 a second on a PAL SC-3000, 60 on an NTSC one), then the jump
;         at #C000 - the interrupt classes / Interrupt hook handler once
;         normal mode has them. Interrupts get in only in normal mode's
;         safe points and while waiting (a key, Frame), as on the CPC.
; NMI     the RESET key: the program starts again.
; End     the program stops (di, halt): RESET starts it again.
; ============================================================
;@name     Sega SC-3000 - cartridge
;@org      #0000
;@text     byte
;@scrinit  1
;@irq      1
;@cols     40
;@rows     24
;@rom      #0000 #C000
;@ram      #C010
;@ramtop   #C800
;@romfile  SC
;@romsizes 16 32 48
;@irqrate  50
;@islc     1
;@vdp      1
; ============================================================

;## ntc_plat_romhead
; ------------------------------------------------------------
; The cartridge's start (the compiler puts this section at #0000): the
; restart vectors, the RAM vector, the stack, then ntc_start. End comes
; back to ntc_sc_end (pushed: ntc_csp's return)
; ------------------------------------------------------------
NTC_SCIRQ		equ #C000		; jp ntc_sc_iret, or jp ntc_irq (normal mode's handler)
NTC_SCTICKS		equ #C003		; frames since the start (Ticks)
			di
			im 1
			ld sp, #C800
			jr ntc_sc_boot
			ds #0038 - $, #FF
; #0038: the VDP's frame interrupt - count it, read the status (that takes
; the interrupt), then the RAM vector
			push af
			push hl
			ld hl, (NTC_SCTICKS)
			inc hl
			ld (NTC_SCTICKS), hl
			pop hl
			in a, (#BF)
			jp NTC_SCIRQ
ntc_sc_iret:
			pop af
			ei
			reti
			ds #0066 - $, #FF
; #0066: NMI - the RESET key: start again
			jp 0
ntc_sc_boot:
			in a, (#BF)				; the VDP: its control latch reset, its interrupt flag clear
			ld a, #A0				; R#1: 16K, display off, frame interrupt on
			out (#BF), a
			ld a, #81
			out (#BF), a
			ld a, #92				; the PPI: A and B in (the keys), C out (the row)
			out (#DF), a
			ld a, #C3
			ld (NTC_SCIRQ), a
			ld hl, ntc_sc_iret
			ld (NTC_SCIRQ + 1), hl
			ld hl, 0
			ld (NTC_SCTICKS), hl
			ld hl, ntc_sc_end
			push hl					; End comes back here
			jp ntc_start
ntc_sc_end:
			di
			halt					; stopped: RESET starts the program again

;## ntc_plat_data @shared
ntc_curx:		db 0			; cursor column (0 based)
ntc_cury:		db 0			; cursor row (0 based)
ntc_scols:		db 40			; columns in this mode
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none
ntc_kcur:		ds 14			; the key matrix this scan: rows 0-6, port A then B (0 = down)
ntc_kprev:		db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF

;## ntc_plat_vdev ntc_vtms ntc_font6 @shared
; the console's device: the TMS9918 at #BE, the font from lib_vdp
ntc_vdev:		dw ntc_vt_put, ntc_vt_scroll, ntc_vt_cls, ntc_vt_mode, ntc_sc_vinit	; @const
ntc_sc_vinit:
			ld hl, #00BE
			ld (ntc_vport), hl
			xor a
			ld (ntc_vtype), a
			ld hl, ntc_font6
			ld (ntc_vfont), hl
			ret

;## ntc_plat_screen ntc_vcon ntc_plat_data ntc_data @shared
; ntc_plat_putc - A = character 32-126; ntc_plat_newline
ntc_plat_putc:
			jp ntc_vc_putc
ntc_plat_newline:
			jp ntc_vc_newline

;## ntc_plat_backspace @unit ntc_plat_screen @shared
ntc_plat_backspace:
			jp ntc_vc_backspace

;## ntc_plat_cls @unit ntc_plat_screen @shared
ntc_plat_cls:
			jp ntc_vc_cls

;## ntc_plat_mode @unit ntc_plat_screen @shared
; ntc_plat_mode - A = mode: 0 = 32 x 24, 1 and 2 = 40 x 24
ntc_plat_mode:
			jp ntc_vc_mode

;## ntc_plat_locate @unit ntc_plat_screen @shared
; ntc_plat_locate - H = column, L = row, 1 based
ntc_plat_locate:
			jp ntc_vc_locate

;## ntc_plat_key ntc_vcall ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_scankey - A = the key pressed since the last look (ASCII), 0 none
; ntc_plat_getkey - wait for a key press, A = the key (a frame between
; looks, interrupts in)
; ------------------------------------------------------------
ntc_plat_scankey:
			ld iy, ntc_sc_scan
			jp ntc_vcall
ntc_plat_getkey:
			ld iy, ntc_sc_getk
			jp ntc_vcall

ntc_sc_getk:
			call ntc_sc_scan
			or a
			ret nz
			ei
			halt
			di
			jr ntc_sc_getk

; the matrix into ntc_kcur, the first key down now and up last time -> A
ntc_sc_scan:
			ld hl, ntc_kcur
			ld b, 0
ntc_sc_row:
			ld a, b
			out (#DE), a
			in a, (#DC)
			ld (hl), a
			inc hl
			in a, (#DD)
			or #F0
			ld (hl), a
			inc hl
			inc b
			ld a, b
			cp 7
			jr nz, ntc_sc_row
			ld hl, ntc_kcur
			ld de, ntc_kprev
			ld iy, ntc_kign
			ld bc, 14 * 256			; B = 14 bytes, C = their first key's number
ntc_sc_find:
			ld a, (hl)
			cpl
			ex de, hl
			and (hl)
			ex de, hl
			and (iy + 0)
			jr nz, ntc_sc_bit
			inc hl
			inc de
			inc iy
			ld a, c
			add a, 8
			ld c, a
			djnz ntc_sc_find
			call ntc_sc_keep
			xor a
			ret
ntc_sc_bit:
			rrca
			jr c, ntc_sc_got
			inc c
			jr ntc_sc_bit
ntc_sc_got:
			push bc
			call ntc_sc_keep
			pop bc
			ld hl, ntc_keymap
			ld a, (ntc_kcur + 13)	; SHIFT: row 6, port B bit 3
			bit 3, a
			jr nz, ntc_sc_map
			ld hl, ntc_keymaps
ntc_sc_map:
			ld e, c
			ld d, 0
			add hl, de
			ld a, (hl)
			ret
ntc_sc_keep:
			ld hl, ntc_kcur
			ld de, ntc_kprev
			ld bc, 14
			ldir
			ret

; keys that are not a press on their own: ENG, FUNC, GRAPH, CTRL, SHIFT
ntc_kign:		db #EF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F7, #FF, #F1	; @const

; key number (row * 16 + port A bit, + 8 + port B bit) -> ASCII. Cursor keys,
; HOME, ENG, the pi key: 0. INS / DEL = 127 (delete), BREAK = 27
ntc_keymap:		db "1", "q", "a", "z", 0, ",", "k", "i",  "8", 0, 0, 0, 0, 0, 0, 0	; @const
				db "2", "w", "s", "x", " ", ".", "l", "o",  "9", 0, 0, 0, 0, 0, 0, 0
				db "3", "e", "d", "c", 0, "/", ";", "p",  "0", 0, 0, 0, 0, 0, 0, 0
				db "4", "r", "f", "v", 127, 0, ":", "@",  "-", 0, 0, 0, 0, 0, 0, 0
				db "5", "t", "g", "b", 0, 0, "]", "[",  "^", 0, 0, 0, 0, 0, 0, 0
				db "6", "y", "h", "n", 0, 0, 13, 0,  92, 0, 0, 0, 0, 0, 0, 0
				db "7", "u", "j", "m", 0, 0, 0, 0,  27, 0, 0, 0, 0, 0, 0, 0
ntc_keymaps:	db "!", "Q", "A", "Z", 0, "<", "K", "I",  "(", 0, 0, 0, 0, 0, 0, 0	; @const
				db 34, "W", "S", "X", " ", ">", "L", "O",  ")", 0, 0, 0, 0, 0, 0, 0
				db "#", "E", "D", "C", 0, "?", "+", "P",  "0", 0, 0, 0, 0, 0, 0, 0
				db "$", "R", "F", "V", 127, 0, "*", "`",  "=", 0, 0, 0, 0, 0, 0, 0
				db "%", "T", "G", "B", 0, 0, "}", "{",  "^", 0, 0, 0, 0, 0, 0, 0
				db "&", "Y", "H", "N", 0, 0, 13, 0,  "|", 0, 0, 0, 0, 0, 0, 0
				db 39, "U", "J", "M", 0, 0, 0, 0,  27, 0, 0, 0, 0, 0, 0, 0

;## ntc_plat_frame ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_frame - wait for the next frame (its interrupt), on the real stack
; ------------------------------------------------------------
ntc_plat_frame:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			halt
			di
			ld sp, (ntc_ip)
			jp (ix)

;## ntc_plat_ticks @shared
; ntc_plat_ticks - HL = frames counted (interrupts in: normal mode, waits)
ntc_plat_ticks:
			ld hl, (NTC_SCTICKS)
			jp (ix)

;## ntc_plat_irq ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_irqon - normal mode's handler on the RAM vector: after the
; frame count, an Interrupt hook is marked to run at the next safe point
; and the interrupt classes are counted (C = 1: every interrupt is a frame's)
; ------------------------------------------------------------
ntc_plat_irqon:
			ld hl, ntc_irq
			ld (NTC_SCIRQ + 1), hl
			jp (ix)
ntc_irq:
			push hl
			ld a, (ntc_hookon)
			or a
			jr z, ntc_irq_nohook
			ld (ntc_hookpend), a
ntc_irq_nohook:
			ld hl, (ntc_irqv)
			ld a, h
			or l
			jr z, ntc_irq_done
			push bc
			ld c, 1
			call ntc_irq_jp
			pop bc
ntc_irq_done:
			pop hl
			jp ntc_sc_iret
ntc_irq_jp:
			jp (hl)

;## ntc_plat_exit ntc_plat_data @shared
; ntc_plat_exit - End: the frame count goes on, the rest of the handler off
ntc_plat_exit:
			ld hl, ntc_sc_iret
			ld (NTC_SCIRQ + 1), hl
			jp (ix)

;## ntc_plat_memtop @shared
; ntc_plat_memtop - HL = the first byte the Memory class's heap must not
; use: 128 bytes under the top of RAM are the stack's. Called with call / ret
ntc_plat_memtop:
			ld hl, #C780
			ret

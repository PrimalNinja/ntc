;## ntc_vcall @shared @unit @ramonly
; ============================================================
; NTC Keyword Library - video chips as the text console
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; For the platforms whose screen is a video chip on I/O ports: the
; TMS9918 family (TMS9918A / TMS9929A, V9938, V9958: msx, msxcard,
; sc3000, cpccard) and the V9990 (msx9990, cpc9990). A platform links
; ntc_vcon for its ntc_plat_screen routines and gives its device in
; its section ntc_plat_vdev:
;
;   ntc_vdev:	dw put, scroll, cls, mode, init
;     put     A = character 32-126 at (ntc_curx, ntc_cury)
;     scroll  the text up one row, the bottom row blank
;     cls     the whole text area blank
;     mode    A = mode 0-2: sets ntc_scols and ntc_srows
;     init    the first mode only: the ports, the chip, the font (the
;             platform's own routine: ntc_vport / ntc_v9port ...)
;
; The device routines run on the real stack (call / ret, push): ntc_vcall
; takes SP out of the thread for them, as the firmware platforms do for
; a firmware call. Ports are BC: on the CPC an MSX card's port nn is
; &FFnn (the AMSDAP adapter, the Powergraph), so B is #FF there; the MSX
; and the SC-3000 look at C only. The chips get at least 29 T between
; VRAM accesses (a TMS9918 in the middle of the screen needs that).
; ============================================================

; ------------------------------------------------------------
; ntc_vcall - IY = a routine to run on the real stack (call / ret); A,
; BC, DE, HL go in as they are. IX = where to go after (jp (ix)).
; Interrupts stay as they are (off in a keyword).
; ------------------------------------------------------------
ntc_vcall:
			ld (ntc_vix), ix
			ld (ntc_vsp), sp
			ld sp, (ntc_csp)
			call ntc_vcall_jp
			ld sp, (ntc_vsp)
			ld ix, (ntc_vix)
			jp (ix)
ntc_vcall_jp:
			jp (iy)
ntc_vix:		dw 0			; IX over the call
ntc_vsp:		dw 0			; the thread's SP over the call

;## ntc_vcon ntc_vcall ntc_plat_vdev ntc_plat_data ntc_data @shared @ramonly @if:ntc_vdp
; ------------------------------------------------------------
; The console on a device (ntc_vdev): ntc_vc_putc, ntc_vc_newline,
; ntc_vc_backspace, ntc_vc_cls, ntc_vc_mode (A), ntc_vc_locate (H =
; column, L = row, 1 based) - the platform contract's routines (jp, IX).
; A new line straight after the last column's character (which went to
; the next line by itself) does nothing. The bottom row scrolls.
; ------------------------------------------------------------
ntc_vc_putc:
			ld iy, ntc_vr_putc
			jp ntc_vcall
ntc_vc_newline:
			ld iy, ntc_vr_newline
			jp ntc_vcall
ntc_vc_backspace:
			ld iy, ntc_vr_bs
			jp ntc_vcall
ntc_vc_cls:
			ld iy, ntc_vr_cls
			jp ntc_vcall
ntc_vc_mode:
			ld iy, ntc_vr_mode
			jp ntc_vcall
ntc_vc_locate:
			ld iy, ntc_vr_locate
			jp ntc_vcall

ntc_srows:		db 24			; text rows
ntc_vwrap:		db 0			; 1 = the last character went on to the next line
ntc_vinit:		db 0			; 1 = the device is set up (its first mode)

; the first use sets mode 1 (keeps A)
ntc_vr_ready:
			push af
			ld a, (ntc_vinit)
			or a
			jr nz, ntc_vr_rdy
			ld a, 1
			call ntc_vr_mode
ntc_vr_rdy:
			pop af
			ret

ntc_vr_putc:
			call ntc_vr_ready
			cp 32
			jr c, ntc_vr_pbad
			cp 127
			jr c, ntc_vr_pok
ntc_vr_pbad:
			ld a, '?'
ntc_vr_pok:
			call ntc_vr_dput
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			ld (ntc_curx), a
			cp b
			jr z, ntc_vr_wrap
			xor a
			ld (ntc_vwrap), a
			ret
ntc_vr_wrap:
			ld a, 1
			ld (ntc_vwrap), a
			jr ntc_vr_nldo

ntc_vr_newline:
			call ntc_vr_ready
			ld a, (ntc_vwrap)
			or a
			jr z, ntc_vr_nldo
			xor a
			ld (ntc_vwrap), a
			ret
ntc_vr_nldo:
			xor a
			ld (ntc_curx), a
			ld a, (ntc_srows)
			ld b, a
			ld a, (ntc_cury)
			inc a
			cp b
			jr c, ntc_vr_nlrow
			call ntc_vr_dscroll
			ld a, (ntc_srows)
			dec a
ntc_vr_nlrow:
			ld (ntc_cury), a
			ret

; back one cell and blank it (to the end of the row above from column 0)
ntc_vr_bs:
			call ntc_vr_ready
			xor a
			ld (ntc_vwrap), a
			ld a, (ntc_curx)
			or a
			jr nz, ntc_vr_bscol
			ld a, (ntc_cury)
			or a
			ret z
			dec a
			ld (ntc_cury), a
			ld a, (ntc_scols)
ntc_vr_bscol:
			dec a
			ld (ntc_curx), a
			ld a, ' '
			jp ntc_vr_dput

ntc_vr_cls:
			call ntc_vr_ready
			xor a
			ld (ntc_vwrap), a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp ntc_vr_dcls

; A = mode 0-2 (3 and up = 2): the device sets the columns and rows; clears
ntc_vr_mode:
			cp 3
			jr c, ntc_vr_mdok
			ld a, 2
ntc_vr_mdok:
			push af
			ld a, (ntc_vinit)
			or a
			jr nz, ntc_vr_mdset
			inc a
			ld (ntc_vinit), a
			call ntc_vr_dinit
ntc_vr_mdset:
			pop af
			call ntc_vr_dmode
			jr ntc_vr_cls

; H = column, L = row, 1 based (0 = 1), kept on the screen
ntc_vr_locate:
			call ntc_vr_ready
			xor a
			ld (ntc_vwrap), a
			ld a, h
			or a
			jr z, ntc_vr_lcx0
			dec a
ntc_vr_lcx0:
			ld c, a
			ld a, (ntc_scols)
			dec a
			cp c
			jr c, ntc_vr_lcxm
			ld a, c
ntc_vr_lcxm:
			ld (ntc_curx), a
			ld a, l
			or a
			jr z, ntc_vr_lcy0
			dec a
ntc_vr_lcy0:
			ld c, a
			ld a, (ntc_srows)
			dec a
			cp c
			jr c, ntc_vr_lcym
			ld a, c
ntc_vr_lcym:
			ld (ntc_cury), a
			ret

; the device's routines (A kept)
ntc_vr_dput:
			ld hl, (ntc_vdev)
			jp (hl)
ntc_vr_dscroll:
			ld hl, (ntc_vdev + 2)
			jp (hl)
ntc_vr_dcls:
			ld hl, (ntc_vdev + 4)
			jp (hl)
ntc_vr_dmode:
			ld hl, (ntc_vdev + 6)
			jp (hl)
ntc_vr_dinit:
			ld hl, (ntc_vdev + 8)
			jp (hl)

;## ntc_vmul @shared @unit @ramonly
; ntc_vmul - HL = A * DE (A 0-255; keeps BC)
ntc_vmul:
			push bc
			ld hl, 0
			ld b, 8
ntc_vmul_lp:
			add hl, hl
			rla
			jr nc, ntc_vmul_nx
			add hl, de
ntc_vmul_nx:
			djnz ntc_vmul_lp
			pop bc
			ret

;## ntc_vtms ntc_vmul @shared @unit @ramonly @if:ntc_vdp
; ------------------------------------------------------------
; The TMS9918 family as a text console: mode 0 = 32 x 24 (Graphics 1,
; 8 pixel characters), 1 = 40 x 24 (Text 1, 6 pixels), 2 = 80 x 24 (Text
; 2: V9938 / V9958 only - 40 on a TMS9918). The font is ntc_vfont's: 95
; characters from 32, 8 bytes each, the left 6 pixels shown in the text
; modes. Ink and paper: ntc_vfg (TMS colour numbers, ink << 4 | paper).
; The platform's init sets ntc_vport (the data port, the control port is
; the next), ntc_vtype, ntc_vr9, ntc_vfont and ntc_vie (a card's chip
; must not interrupt: nothing would take its interrupt).
; VRAM: mode 0 names #1800, patterns #0000, colours #2000, sprites off
; (#1B00); modes 1 and 2 names #0000, patterns #0800 (1) / #1000 (2),
; mode 2's blink table #0A00 (cleared).
; ------------------------------------------------------------
ntc_vport:		dw #0098		; the data port (+ 1 = the control port); B = #FF on the CPC
ntc_vtype:		db 0			; 0 = TMS9918 / TMS9929, 1 = V9938 / V9958
ntc_vr9:		db #02			; V9938 / V9958 R#9: 192 lines, PAL (the MSX's own setting goes here)
ntc_vfont:		dw 0			; character 32's 8 bytes
ntc_vfg:		db #F4			; ink << 4 | paper: white on dark blue
ntc_vie:		db #20			; R#1's frame interrupt bit: #20 for the machine's own chip (its clock), 0 for a card
ntc_vmode:		db 1			; the mode set (0-2)
ntc_vnt:		dw 0			; the name table
ntc_vbuf:		ds 80			; scroll: a row

; R#0-R#6 for modes 0, 1, 2 (R#1: 16K, display on; ntc_vie adds the frame interrupt)
ntc_vt_regs:	db #00, #C0, #06, #80, #00, #36, #07	; @const
				db #00, #D0, #00, #00, #01, #00, #00
				db #04, #D0, #03, #2F, #02, #00, #00

; A to the control port (keeps BC, DE, HL)
ntc_vt_ctl:
			push bc
			ld bc, (ntc_vport)
			inc c
			out (c), a
			pop bc
			ret

; A to the data port (keeps BC, DE, HL)
ntc_vt_dat:
			push bc
			ld bc, (ntc_vport)
			out (c), a
			pop bc
			ret

; E = register, A = value
ntc_vt_reg:
			call ntc_vt_ctl
			ld a, e
			or #80
			jr ntc_vt_ctl

; HL = the VRAM address to write from (below 16K)
ntc_vt_wadr:
			ld a, l
			call ntc_vt_ctl
			ld a, h
			and #3F
			or #40
			jr ntc_vt_ctl

; HL = the VRAM address to read from
ntc_vt_radr:
			ld a, l
			call ntc_vt_ctl
			ld a, h
			and #3F
			jr ntc_vt_ctl

; HL = VRAM address, DE = bytes (1 or more), A = the byte
ntc_vt_fill:
			push af
			call ntc_vt_wadr
			pop af
			ld bc, (ntc_vport)
ntc_vt_flp:
			out (c), a
			ld l, a
			dec de
			ld a, d
			or e
			ld a, l
			jr nz, ntc_vt_flp
			ret

; HL = from (RAM / ROM), DE = VRAM address, BC = bytes (1 or more)
ntc_vt_write:
			push bc
			ex de, hl
			call ntc_vt_wadr
			ex de, hl
			pop de
			ld bc, (ntc_vport)
ntc_vt_wlp:
			ld a, (hl)
			out (c), a
			inc hl
			dec de
			ld a, d
			or e
			jr nz, ntc_vt_wlp
			ret

; HL = the address of (ntc_curx, ntc_cury) in the name table
ntc_vt_cell:
			ld a, (ntc_cury)
			ld e, a
			ld d, 0
			ld a, (ntc_scols)
			call ntc_vmul
			ld a, (ntc_curx)
			ld e, a
			add hl, de
			ld de, (ntc_vnt)
			add hl, de
			ret

; ntc_vt_mode - A = mode 0-2
ntc_vt_mode:
			ld c, a
			cp 2
			jr nz, ntc_vt_m1
			ld a, (ntc_vtype)
			or a
			jr nz, ntc_vt_m1
			ld c, 1					; a TMS9918: 40 columns
ntc_vt_m1:
			ld a, c
			ld (ntc_vmode), a
			ld l, a					; registers: R#0-R#6 of the mode, R#7 the colours
			add a, a
			add a, a
			add a, a
			sub l
			ld e, a
			ld d, 0
			ld hl, ntc_vt_regs
			add hl, de
			ld e, 0
ntc_vt_mreg:
			ld a, e
			cp 1
			ld a, (ntc_vie)			; R#1: the frame interrupt as the platform has it
			jr z, ntc_vt_mr1
			xor a
ntc_vt_mr1:
			or (hl)
			call ntc_vt_reg
			inc hl
			inc e
			ld a, e
			cp 7
			jr nz, ntc_vt_mreg
			ld a, (ntc_vfg)
			call ntc_vt_reg
			ld a, (ntc_vtype)
			or a
			jr z, ntc_vt_mtms
			ld hl, ntc_vt_r99		; V9938 / V9958: R#8 on, the rest 0
ntc_vt_m99:
			ld e, (hl)
			inc hl
			ld a, (hl)
			inc hl
			call ntc_vt_reg
			ld a, e
			cp 23
			jr nz, ntc_vt_m99
			ld e, 9
			ld a, (ntc_vr9)
			call ntc_vt_reg
ntc_vt_mtms:
			ld a, 24
			ld (ntc_srows), a
			ld a, (ntc_vmode)
			or a
			jr z, ntc_vt_mg1
			dec a
			jr z, ntc_vt_mt1
			ld a, 80				; Text 2: 80 columns, the blink table cleared
			ld hl, #1000
			push hl
			push af
			ld hl, #0A00
			ld de, 270
			xor a
			call ntc_vt_fill
			pop af
			pop hl
			jr ntc_vt_mfont
ntc_vt_mt1:
			ld a, 40
			ld hl, #0800
ntc_vt_mfont:
			ld de, 0
			ld (ntc_vnt), de
ntc_vt_mf2:
			ld (ntc_scols), a
			ld de, 32 * 8			; the font: characters 32-126
			add hl, de
			ex de, hl
			ld hl, (ntc_vfont)
			ld bc, 95 * 8
			jp ntc_vt_write
ntc_vt_mg1:
			ld hl, #2000			; Graphics 1: the colours, sprites off
			ld de, 32
			ld a, (ntc_vfg)
			call ntc_vt_fill
			ld hl, #1B00
			ld de, 1
			ld a, #D0
			call ntc_vt_fill
			ld hl, #1800
			ld (ntc_vnt), hl
			ld a, 32
			ld hl, #0000
			jr ntc_vt_mf2
ntc_vt_r99:		db 8, #0A, 10, 0, 11, 0, 12, 0, 13, 0, 14, 0, 23, 0	; @const

; ntc_vt_put - A = character at (ntc_curx, ntc_cury)
ntc_vt_put:
			push af
			call ntc_vt_cell
			call ntc_vt_wadr
			pop af
			jp ntc_vt_dat

; ntc_vt_cls - the text area blank
ntc_vt_cls:
			ld a, (ntc_srows)
			ld de, (ntc_scols)
			ld d, 0
			call ntc_vmul
			ex de, hl
			ld hl, (ntc_vnt)
			ld a, ' '
			jp ntc_vt_fill

; ntc_vt_scroll - each row from the one below (read back from VRAM), the last one blank
ntc_vt_scroll:
			ld hl, (ntc_vnt)
			ld a, (ntc_srows)
			dec a
			ld b, a
ntc_vt_slp:
			push bc
			push hl
			ld a, (ntc_scols)
			ld e, a
			ld d, 0
			add hl, de
			call ntc_vt_radr
			ld hl, ntc_vbuf
			ld bc, (ntc_vport)
			ld a, (ntc_scols)
			ld e, a
ntc_vt_srd:
			in a, (c)
			ld (hl), a
			inc hl
			dec e
			jr nz, ntc_vt_srd
			pop hl
			push hl
			call ntc_vt_wadr
			ld hl, ntc_vbuf
			ld bc, (ntc_vport)
			ld a, (ntc_scols)
			ld e, a
ntc_vt_swr:
			ld a, (hl)
			out (c), a
			inc hl
			dec e
			jr nz, ntc_vt_swr
			pop hl
			ld a, (ntc_scols)
			ld e, a
			ld d, 0
			add hl, de
			pop bc
			djnz ntc_vt_slp
			ld a, (ntc_scols)
			ld e, a
			ld d, 0
			ld a, ' '
			jp ntc_vt_fill

;## ntc_v9 ntc_vmul @shared @unit @ramonly @if:ntc_vdp
; ------------------------------------------------------------
; The V9990 as a text console, drawn on a bit map: mode 0 / 1 = B1 (256 x
; 212, 4 bits a pixel) with 40 x 24 characters of 6 x 8, mode 2 = B3 (512
; x 212) with 80 x 24. The characters are ntc_v9font's left 6 pixels (the
; same font as the TMS9918's text modes). Ink and paper: ntc_v9fg (ink <<
; 4 | paper) in a palette set like the MSX2's 16 colours. Scrolling and
; clearing are the chip's own block commands (LMMM, LMMV). The platform's
; init sets ntc_v9port (P#0; P#n = + n) and ntc_v9font.
; ------------------------------------------------------------
NTC_V9Y0		equ 10			; the text's top line (24 rows of 8 in the middle of 212)
ntc_v9port:		dw #0060		; P#0 (VRAM data); B = #FF on the CPC
ntc_v9font:		dw 0			; character 32's 8 bytes
ntc_v9fg:		db #F4			; ink << 4 | paper
ntc_v9r7:		db 0			; R#7 (bit 3 PAL)
ntc_v9w:		dw 128			; bytes a line
ntc_v9x0:		db 4			; the left margin in bytes
ntc_v9lut:		ds 4			; a byte of two pixels for glyph bits 00, 01, 10, 11
ntc_v9cmd:		ds 21			; a block command: R#32-R#52

; the MSX2's palette, 5 bits each (red, green, blue)
ntc_v9pals:		db 0, 0, 0,  0, 0, 0,  4, 27, 4,  13, 31, 13	; @const
				db 4, 4, 31,  9, 13, 31,  22, 4, 4,  9, 27, 31
				db 31, 4, 4,  31, 13, 13,  27, 27, 4,  27, 27, 18
				db 4, 18, 4,  27, 9, 22,  22, 22, 22,  31, 31, 31

; C = port number (0-15) -> BC = that port (keeps A, DE, HL)
ntc_v9p:
			push af
			ld a, (ntc_v9port)
			add a, c
			ld c, a
			ld a, (ntc_v9port + 1)
			ld b, a
			pop af
			ret

; E = register, A = value
ntc_v9reg:
			push af
			ld c, 4
			call ntc_v9p
			out (c), e				; P#4: the register
			dec c
			pop af
			out (c), a				; P#3: its value
			ret

; HL = VRAM address to write from (bits 18-16: 0)
ntc_v9wadr:
			ld c, 4
			call ntc_v9p
			xor a
			out (c), a				; R#0 on
			dec c
			out (c), l
			out (c), h
			out (c), a
			ret

; wait for a block command to end (P#5 bit 0)
ntc_v9wait:
			ld c, 5
			call ntc_v9p
ntc_v9wt:
			in a, (c)
			rra
			jr c, ntc_v9wt
			ret

; ntc_v9cmd to R#32-R#52: the command runs; waits for its end
ntc_v9go:
			ld c, 4
			call ntc_v9p
			ld a, 32
			out (c), a
			dec c
			ld hl, ntc_v9cmd
			ld e, 21
ntc_v9g1:
			ld a, (hl)
			out (c), a
			inc hl
			dec e
			jr nz, ntc_v9g1
			jr ntc_v9wait

; LMMV: a box of paper - HL = top line, DE = lines
ntc_v9fill:
			push de
			push hl
			ld hl, ntc_v9cmd
			ld de, ntc_v9cmd + 1
			ld bc, 20
			ld (hl), 0
			ldir
			pop hl
			ld (ntc_v9cmd + 6), hl	; DY
			pop de
			ld (ntc_v9cmd + 10), de	; NY
			ld hl, (ntc_v9w)		; NX = bytes a line * 2
			add hl, hl
			ld (ntc_v9cmd + 8), hl
			ld a, #0C				; LOP: WC = SC
			ld (ntc_v9cmd + 13), a
			ld a, #FF				; write mask
			ld (ntc_v9cmd + 14), a
			ld (ntc_v9cmd + 15), a
			ld a, (ntc_v9fg)		; FC: the paper in all 4 nibbles
			and #0F
			ld b, a
			rlca
			rlca
			rlca
			rlca
			or b
			ld (ntc_v9cmd + 16), a
			ld (ntc_v9cmd + 17), a
			ld a, #20				; LMMV
			ld (ntc_v9cmd + 20), a
			jr ntc_v9go

; ntc_v9mode - A = mode (2 = 80 columns, else 40)
ntc_v9mode:
			push af
			ld c, 7					; P#7: reset, master clock XTAL1
			call ntc_v9p
			ld a, 2
			out (c), a
			xor a
			out (c), a
			pop af
			cp 2
			ld hl, 256
			ld bc, 8 * 256 + 80		; B = left margin bytes, C = columns
			ld a, #95				; R#6: B3, 512 wide, 4 bits a pixel
			jr z, ntc_v9m1
			ld hl, 128
			ld bc, 4 * 256 + 40
			ld a, #81				; R#6: B1, 256 wide, 4 bits a pixel
ntc_v9m1:
			ld (ntc_v9w), hl
			push af
			ld a, b
			ld (ntc_v9x0), a
			ld a, c
			ld (ntc_scols), a
			ld a, 24
			ld (ntc_srows), a
			pop af
			ld e, 6
			call ntc_v9reg
			ld e, 7
			ld a, (ntc_v9r7)
			call ntc_v9reg
			ld hl, ntc_v9_rs		; R#8 display on, cursors off, the others 0
ntc_v9m2:
			ld e, (hl)
			inc hl
			ld a, (hl)
			inc hl
			call ntc_v9reg
			ld a, e
			cp 24
			jr nz, ntc_v9m2
			ld e, 15				; the backdrop: the paper
			ld a, (ntc_v9fg)
			and #0F
			call ntc_v9reg
			ld e, 14				; the palette from 0
			xor a
			call ntc_v9reg
			ld c, 1
			call ntc_v9p
			ld hl, ntc_v9pals
			ld e, 48
ntc_v9m3:
			ld a, (hl)
			out (c), a
			inc hl
			dec e
			jr nz, ntc_v9m3
			ld a, (ntc_v9fg)		; two pixels for glyph bits 00, 01, 10, 11
			and #0F
			ld e, a
			ld a, (ntc_v9fg)
			and #F0
			ld d, a					; D = ink << 4, E = paper
			ld hl, ntc_v9lut
			ld a, e
			rlca
			rlca
			rlca
			rlca
			ld b, a					; B = paper << 4
			or e
			ld (hl), a				; 00: paper paper
			inc hl
			ld a, d
			rrca
			rrca
			rrca
			rrca
			ld c, a					; C = ink
			or b
			ld (hl), a				; 01: paper ink
			inc hl
			ld a, d
			or e
			ld (hl), a				; 10: ink paper
			inc hl
			ld a, d
			or c
			ld (hl), a				; 11: ink ink
			ret
ntc_v9_rs:		db 8, #C2, 9, 0, 13, 0, 16, 0, 17, 0, 18, 0, 19, 0, 20, 0, 21, 0, 22, 0, 23, 0, 24, 0	; @const

; ntc_v9cls - the whole screen paper
ntc_v9cls:
			ld hl, 0
			ld de, 212
			jp ntc_v9fill

; ntc_v9scroll - LMMM: rows 1-23 up a row, then the last row paper
ntc_v9scroll:
			ld hl, ntc_v9cmd
			ld de, ntc_v9cmd + 1
			ld bc, 20
			ld (hl), 0
			ldir
			ld hl, NTC_V9Y0 + 8
			ld (ntc_v9cmd + 2), hl	; SY
			ld hl, NTC_V9Y0
			ld (ntc_v9cmd + 6), hl	; DY
			ld hl, (ntc_v9w)
			add hl, hl
			ld (ntc_v9cmd + 8), hl	; NX: the whole width
			ld hl, 23 * 8
			ld (ntc_v9cmd + 10), hl	; NY
			ld a, #0C
			ld (ntc_v9cmd + 13), a
			ld a, #FF
			ld (ntc_v9cmd + 14), a
			ld (ntc_v9cmd + 15), a
			ld a, #40				; LMMM
			ld (ntc_v9cmd + 20), a
			call ntc_v9go
			ld hl, NTC_V9Y0 + 23 * 8
			ld de, 8
			jp ntc_v9fill

; ntc_v9put - A = character at (ntc_curx, ntc_cury): 8 lines of 3 bytes
ntc_v9put:
			sub 32
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, (ntc_v9font)
			add hl, de
			push hl					; the glyph
			ld a, (ntc_cury)		; line = top + row * 8
			add a, a
			add a, a
			add a, a
			add a, NTC_V9Y0
			ld e, a
			ld d, 0
			ld a, (ntc_v9w)			; * bytes a line (128 or 256)
			or a
			ld h, e
			ld l, d					; (256: HL = line * 256)
			jr z, ntc_v9p1
			ld l, d
			srl h
			rr l					; (128: HL = line * 128)
ntc_v9p1:
			ld a, (ntc_curx)		; + margin + column * 3
			ld e, a
			add a, a
			add a, e
			ld e, a
			ld a, (ntc_v9x0)
			add a, e
			ld e, a
			ld d, 0
			add hl, de
			pop de					; DE = the glyph, HL = the VRAM address
			ld a, 8
ntc_v9plp:
			push af
			push hl
			call ntc_v9wadr
			ld c, 0
			call ntc_v9p
			ld a, (de)
			inc de
			ld h, a
			ld l, 3
ntc_v9pb:
			ld a, h					; the next two pixels: bits 7-6
			rlca
			rlca
			ld h, a
			and 3
			push hl
			ld hl, ntc_v9lut
			add a, l
			ld l, a
			ld a, 0
			adc a, h
			ld h, a
			ld a, (hl)
			pop hl
			out (c), a
			dec l
			jr nz, ntc_v9pb
			pop hl
			push de
			ld de, (ntc_v9w)
			add hl, de
			pop de
			pop af
			dec a
			jr nz, ntc_v9plp
			ret

;## ntc_vdpc ntc_vcall ntc_vmul @shared @unit @ramonly
; ------------------------------------------------------------
; The VDP class (lib/<platform>/VDP.cls): a TMS9918 / V9938 / V9958 on
; any port - the MSX's own, a card at #88 (MSX), &FF88 (the CPC's AMSDAP
; adapter), the SC-3000's #BE. A method puts its arguments in ntc_vca
; (words, in order) and runs an entry on the real stack (ntc_vcall) with
; HL = the platform's port, D = its chip (0 TMS9918, 1 V9938 / V9958, #FF:
; ask the MSX BIOS, #002D) and E = R#1's frame interrupt bit (#20 where the
; chip's interrupt is the machine's clock: msx, sc3000) for the first call;
; VDP.Port changes the port.
; Results come back in HL. The V9938's commands (Box, Line, Copy, PSet,
; Point in the bit map modes) wait for the chip each time.
; ------------------------------------------------------------
ntc_vcp:		dw 0			; the data port (0 = not set yet: the platform's)
ntc_vct:		db 0			; 0 = TMS9918, 1 = V9938 / V9958
ntc_vci:		db 0			; R#1's frame interrupt bit (#20: the chip is the machine's clock)
ntc_vcm:		db 0			; the Screen set (2, 5, 6, 7, 8; 0 = none)
ntc_vca:		ds 12			; the method's arguments

; HL = the platform's port, D = its chip, E = its R#1 interrupt bit: the class's port into
; BC (the first time: these)
ntc_vc_port:
			push hl
			ld hl, (ntc_vcp)
			ld a, h
			or l
			pop hl
			jr nz, ntc_vcp_set
			ld (ntc_vcp), hl
			ld a, e
			ld (ntc_vci), a
			ld a, d
			inc a
			jr nz, ntc_vcp_t
			ld a, (#002D)			; (MSX: the BIOS's version, 0 = MSX1 = TMS9918)
			or a
			jr z, ntc_vcp_t0
			ld a, 1
			jr ntc_vcp_t0
ntc_vcp_t:
			ld a, d
ntc_vcp_t0:
			ld (ntc_vct), a
ntc_vcp_set:
			ld bc, (ntc_vcp)
			ret

; A to the control port, E = the register for ntc_vc_reg (keeps BC = the data port)
ntc_vc_ctl:
			inc c
			out (c), a
			dec c
			ret
ntc_vc_reg:
			call ntc_vc_ctl
			ld a, e
			or #80
			jr ntc_vc_ctl

; HL = VRAM address (64K: R#14 on a V9938), A = #40 to write, 0 to read
ntc_vc_adr:
			push af
			ld a, (ntc_vct)
			or a
			jr z, ntc_vc_a16
			ld a, h					; R#14: A16-A14
			rlca
			rlca
			and 3
			ld e, 14
			call ntc_vc_reg
ntc_vc_a16:
			ld a, l
			call ntc_vc_ctl
			pop af
			ld e, a
			ld a, h
			and #3F
			or e
			jr ntc_vc_ctl

; the command engine: wait until the last command is done (S#2 bit 0)
ntc_vc_wait:
			ld a, (ntc_vct)
			or a
			ret z
			ld a, 2
			ld e, 15
			call ntc_vc_reg
			inc c
ntc_vc_wt:
			in a, (c)
			rra
			jr c, ntc_vc_wt
			dec c
			xor a
			ld e, 15
			jr ntc_vc_reg

; HL = 15 bytes for R#32-R#46 (SX, SY, DX, DY, NX, NY, CLR, ARG, CMD): the command runs
ntc_vc_cmd:
			push hl
			call ntc_vc_wait
			ld a, 32				; R#17: R#32 on, counting up
			ld e, 17
			call ntc_vc_reg
			pop hl
			inc c
			inc c
			inc c
			ld e, 15
ntc_vc_cm1:
			ld a, (hl)
			out (c), a				; port + 3: the register R#17 points at
			inc hl
			dec e
			jr nz, ntc_vc_cm1
			dec c
			dec c
			dec c
			ret
ntc_vcb:		ds 15			; a command's registers

; clear ntc_vcb, DX = (ntc_vca), DY = (ntc_vca + 2)
ntc_vc_cdxy:
			ld hl, ntc_vcb
			ld de, ntc_vcb + 1
			push bc
			ld bc, 14
			ld (hl), 0
			ldir
			pop bc
			ld hl, (ntc_vca)
			ld (ntc_vcb + 4), hl
			ld hl, (ntc_vca + 2)
			ld (ntc_vcb + 6), hl
			ret

; ---- the entries (the method's port in HL, chip in D)
; Port(p): ntc_vca = the data port
ntc_vcx_port:
			call ntc_vc_port		; (the chip and its interrupt bit: the platform's)
			ld hl, (ntc_vca)
			ld (ntc_vcp), hl
			ret
; Chip(t): 0 TMS9918, 1 V9938 / V9958
ntc_vcx_chip:
			call ntc_vc_port
			ld a, (ntc_vca)
			ld (ntc_vct), a
			ret
; Reg(r, v)
ntc_vcx_reg:
			call ntc_vc_port
			ld a, (ntc_vca)
			ld e, a
			ld a, (ntc_vca + 2)
			jp ntc_vc_reg
; Status(n) -> HL: S#n (V9938; S#0 on a TMS9918)
ntc_vcx_stat:
			call ntc_vc_port
			ld a, (ntc_vct)
			or a
			jr z, ntc_vcs0
			ld a, (ntc_vca)
			ld e, 15
			call ntc_vc_reg
ntc_vcs0:
			inc c
			in l, (c)
			dec c
			ld h, 0
			ld a, (ntc_vct)
			or a
			ret z
			xor a
			ld e, 15
			jp ntc_vc_reg
; VPoke(addr, v)
ntc_vcx_poke:
			call ntc_vc_port
			ld hl, (ntc_vca)
			ld a, #40
			call ntc_vc_adr
			ld a, (ntc_vca + 2)
			out (c), a
			ret
; VPeek(addr) -> HL
ntc_vcx_peek:
			call ntc_vc_port
			ld hl, (ntc_vca)
			xor a
			call ntc_vc_adr
			ex (sp), hl				; (time for the chip's read ahead)
			ex (sp), hl
			in l, (c)
			ld h, 0
			ret
; Fill(addr, count, v)
ntc_vcx_fill:
			call ntc_vc_port
			ld hl, (ntc_vca)
			ld a, #40
			call ntc_vc_adr
			ld de, (ntc_vca + 2)
			ld a, d
			or e
			ret z
			ld a, (ntc_vca + 4)
ntc_vcf1:
			out (c), a
			ld l, a
			dec de
			ld a, d
			or e
			ld a, l
			jr nz, ntc_vcf1
			ret
; Write(addr, from, count): RAM to VRAM
ntc_vcx_write:
			call ntc_vc_port
			ld hl, (ntc_vca)
			ld a, #40
			call ntc_vc_adr
			ld hl, (ntc_vca + 2)
			ld de, (ntc_vca + 4)
			ld a, d
			or e
			ret z
ntc_vcw1:
			ld a, (hl)
			out (c), a
			inc hl
			dec de
			ld a, d
			or e
			jr nz, ntc_vcw1
			ret
; Read(addr, to, count): VRAM to RAM
ntc_vcx_read:
			call ntc_vc_port
			ld hl, (ntc_vca)
			xor a
			call ntc_vc_adr
			ld hl, (ntc_vca + 2)
			ld de, (ntc_vca + 4)
			ld a, d
			or e
			ret z
ntc_vcr1:
			in a, (c)
			ld (hl), a
			inc hl
			dec de
			ld a, d
			or e
			jr nz, ntc_vcr1
			ret
; Palette(n, r, g, b): 0-7 each (V9938)
ntc_vcx_pal:
			call ntc_vc_port
			ld a, (ntc_vct)
			or a
			ret z
			ld a, (ntc_vca)
			and 15
			ld e, 16
			call ntc_vc_reg
			inc c
			inc c
			ld a, (ntc_vca + 2)		; red << 4 | blue, then green
			and 7
			rlca
			rlca
			rlca
			rlca
			ld e, a
			ld a, (ntc_vca + 6)
			and 7
			or e
			out (c), a
			ld a, (ntc_vca + 4)
			and 7
			out (c), a
			dec c
			dec c
			ret
; Screen(m): 2 (256 x 192, TMS9918 too), 5 (256 x 212, 16 colours), 6 (512 x 212, 4),
; 7 (512 x 212, 16), 8 (256 x 212, 256): set, cleared, sprites off. Other m: nothing
ntc_vcx_screen:
			call ntc_vc_port
			ld a, (ntc_vca)
			ld hl, ntc_vc_s2
			cp 2
			jr z, ntc_vcsc
			ld e, a
			ld a, (ntc_vct)
			or a
			ret z					; (a TMS9918: Screen 2 only)
			ld a, e
			ld hl, ntc_vc_s5
			cp 5
			jr z, ntc_vcsc
			ld hl, ntc_vc_s6
			cp 6
			jr z, ntc_vcsc
			ld hl, ntc_vc_s7
			cp 7
			jr z, ntc_vcsc
			ld hl, ntc_vc_s8
			cp 8
			ret nz
ntc_vcsc:
			ld (ntc_vcm), a
ntc_vcsc1:
			ld e, (hl)				; register, value pairs to #FF
			inc e
			jr z, ntc_vcsc2
			dec e
			inc hl
			ld a, e
			cp 1
			ld a, (ntc_vci)			; R#1: the frame interrupt as it was
			jr z, ntc_vcsc1b
			xor a
ntc_vcsc1b:
			or (hl)
			inc hl
			push hl
			call ntc_vc_reg
			pop hl
			jr ntc_vcsc1
ntc_vcsc2:
			ld a, (ntc_vcm)
			cp 2
			jr nz, ntc_vcsc5
			ld hl, #0000			; Screen 2: patterns and colours 0, the names 0-255 three times
			ld de, #1800
			xor a
			call ntc_vc_vfill
			ld hl, #2000
			ld de, #1800
			xor a
			call ntc_vc_vfill
			ld hl, #1B00
			ld de, 1
			ld a, #D0
			call ntc_vc_vfill
			ld hl, #1800
			ld a, #40
			call ntc_vc_adr
			ld de, 768
			xor a
ntc_vcsc3:
			out (c), a
			inc a
			ld l, a
			dec de
			ld a, d
			or e
			ld a, l
			jr nz, ntc_vcsc3
			ret
ntc_vcsc5:
			cp 7
			ld hl, #7600			; sprites off: the attribute table's first Y = 216
			jr c, ntc_vcsc6
			ld hl, #FA00
ntc_vcsc6:
			ld de, 1
			ld a, 216
			call ntc_vc_vfill
			ld hl, 0				; the whole screen colour 0
			ld (ntc_vca), hl
			ld (ntc_vca + 2), hl
			ld (ntc_vca + 8), hl
			ld a, (ntc_vcm)			; 512 dots wide in 6 and 7, else 256
			ld hl, 256
			cp 6
			jr c, ntc_vcsc7
			cp 8
			jr nc, ntc_vcsc7
			add hl, hl
ntc_vcsc7:
			ld (ntc_vca + 4), hl
			ld hl, 212
			ld (ntc_vca + 6), hl
			jp ntc_vcx_box2
; HL = VRAM address, DE = bytes (1 or more), A = the byte
ntc_vc_vfill:
			push af
			ld a, #40
			call ntc_vc_adr
			pop af
ntc_vcvf:
			out (c), a
			ld l, a
			dec de
			ld a, d
			or e
			ld a, l
			jr nz, ntc_vcvf
			ret
; (register, value) to #FF: R#0, R#1 (display on, frame interrupt kept off), the tables, R#8, R#9
ntc_vc_s2:		db 0, #02, 1, #C0, 2, #06, 3, #FF, 4, #03, 5, #36, 6, #07, 7, #01, #FF	; @const
ntc_vc_s5:		db 0, #06, 1, #40, 2, #1F, 5, #EF, 11, #00, 6, #0F, 8, #0A, 9, #80, 7, #00, #FF	; @const
ntc_vc_s6:		db 0, #08, 1, #40, 2, #1F, 5, #EF, 11, #00, 6, #0F, 8, #0A, 9, #80, 7, #00, #FF	; @const
ntc_vc_s7:		db 0, #0A, 1, #40, 2, #1F, 5, #F7, 11, #01, 6, #1E, 8, #0A, 9, #80, 7, #00, #FF	; @const
ntc_vc_s8:		db 0, #0E, 1, #40, 2, #1F, 5, #F7, 11, #01, 6, #1E, 8, #0A, 9, #80, 7, #00, #FF	; @const

; PSet(x, y, c): a V9938's PSET command; Screen 2 (a TMS9918 too): the pattern bit and
; its 8 dots' ink
ntc_vcx_pset:
			call ntc_vc_port
			ld a, (ntc_vcm)
			cp 2
			jr z, ntc_vcp2
			call ntc_vc_cdxy
			ld a, (ntc_vca + 4)
			ld (ntc_vcb + 12), a	; CLR
			ld a, #50				; PSET
			ld (ntc_vcb + 14), a
			ld hl, ntc_vcb
			jp ntc_vc_cmd
ntc_vcp2:
			ld a, (ntc_vca + 2)		; address = (y / 8) * 256 + (x and 248) + (y and 7)
			cp 192
			ret nc
			ld l, a
			and 7
			ld e, a
			ld a, l
			rrca
			rrca
			rrca
			and #1F
			ld h, a
			ld l, 0
			ld a, (ntc_vca)
			and #F8
			or e
			ld e, a
			ld d, 0
			add hl, de
			push hl
			xor a
			call ntc_vc_adr
			ex (sp), hl
			ex (sp), hl
			in d, (c)				; the pattern byte
			ld a, (ntc_vca)
			and 7
			ld e, a
			ld a, #80
			inc e
ntc_vcp2b:
			dec e
			jr z, ntc_vcp2c
			rrca
			jr ntc_vcp2b
ntc_vcp2c:
			or d
			pop hl
			push hl
			push af
			ld a, #40
			call ntc_vc_adr
			pop af
			out (c), a
			pop hl
			ld de, #2000			; the colour byte: ink c, paper 0
			add hl, de
			ld a, #40
			call ntc_vc_adr
			ld a, (ntc_vca + 4)
			rlca
			rlca
			rlca
			rlca
			and #F0
			out (c), a
			ret
; Point(x, y) -> HL: the colour (V9938's POINT)
ntc_vcx_point:
			call ntc_vc_port
			ld hl, 0
			ld a, (ntc_vct)
			or a
			ret z
			call ntc_vc_cdxy
			ld hl, (ntc_vcb + 4)	; SX, SY
			ld (ntc_vcb), hl
			ld hl, (ntc_vcb + 6)
			ld (ntc_vcb + 2), hl
			ld a, #40				; POINT
			ld (ntc_vcb + 14), a
			ld hl, ntc_vcb
			call ntc_vc_cmd
			call ntc_vc_wait
			ld a, 7					; S#7: the colour
			ld e, 15
			call ntc_vc_reg
			inc c
			in l, (c)
			dec c
			ld h, 0
			xor a
			ld e, 15
			jp ntc_vc_reg
; Box(x, y, w, h, c): filled (LMMV)
ntc_vcx_box:
			call ntc_vc_port
			ld a, (ntc_vct)
			or a
			ret z
ntc_vcx_box2:
			call ntc_vc_cdxy
			ld hl, (ntc_vca + 4)
			ld (ntc_vcb + 8), hl	; NX
			ld hl, (ntc_vca + 6)
			ld (ntc_vcb + 10), hl	; NY
			ld a, (ntc_vca + 8)
			ld (ntc_vcb + 12), a
			ld a, #80				; LMMV
			ld (ntc_vcb + 14), a
			ld hl, ntc_vcb
			jp ntc_vc_cmd
; Line(x1, y1, x2, y2, c)
ntc_vcx_line:
			call ntc_vc_port
			ld a, (ntc_vct)
			or a
			ret z
			call ntc_vc_cdxy
			ld a, (ntc_vca + 8)
			ld (ntc_vcb + 12), a
			ld hl, (ntc_vca + 4)	; dx = x2 - x1
			ld de, (ntc_vca)
			or a
			sbc hl, de
			ld a, 0
			jr nc, ntc_vcl1
			ld a, 4					; DIX: left
			ex de, hl
			ld hl, 0
			or a
			sbc hl, de
			ld a, 4
ntc_vcl1:
			ld (ntc_vcb + 8), hl	; (NX = |dx| for now)
			ld (ntc_vcb + 13), a
			ld hl, (ntc_vca + 6)	; dy = y2 - y1
			ld de, (ntc_vca + 2)
			or a
			sbc hl, de
			jr nc, ntc_vcl2
			ld a, (ntc_vcb + 13)
			or 8					; DIY: up
			ld (ntc_vcb + 13), a
			ex de, hl
			ld hl, 0
			or a
			sbc hl, de
ntc_vcl2:
			ld (ntc_vcb + 10), hl	; NY = |dy|
			ld de, (ntc_vcb + 8)
			or a
			sbc hl, de
			jr c, ntc_vcl3			; |dy| < |dx|: long side X
			ld hl, (ntc_vcb + 10)	; long side Y: swap, MAJ
			ld (ntc_vcb + 8), hl
			ld (ntc_vcb + 10), de
			ld a, (ntc_vcb + 13)
			or 1
			ld (ntc_vcb + 13), a
ntc_vcl3:
			ld a, #70				; LINE
			ld (ntc_vcb + 14), a
			ld hl, ntc_vcb
			jp ntc_vc_cmd
; Copy(sx, sy, dx, dy, w, h): LMMM
ntc_vcx_copy:
			call ntc_vc_port
			ld a, (ntc_vct)
			or a
			ret z
			ld hl, ntc_vca
			ld de, ntc_vcb
			push bc
			ld bc, 12
			ldir
			pop bc
			xor a
			ld (ntc_vcb + 12), a
			ld (ntc_vcb + 13), a
			ld a, #90				; LMMM
			ld (ntc_vcb + 14), a
			ld hl, ntc_vcb
			jp ntc_vc_cmd
; Wait: until the chip's command is done
ntc_vcx_wait:
			call ntc_vc_port
			jp ntc_vc_wait

;## ntc_v9c ntc_vcall @shared @unit @ramonly
; ------------------------------------------------------------
; The V9990 class (lib/<platform>/V9990.cls): a V9990 on any port base -
; #60 on the MSX (GFX9000, Video9000, Powergraph), &FF60 on the CPC
; (AMSDAP, the CPC Powergraph). A method puts its arguments in ntc_v9a and
; runs an entry on the real stack (ntc_vcall) with HL = the platform's
; port base for the first call; V9990.Port changes it. Results in HL.
; Screen 1 = B1 256 x 212, 16 colours; 2 = B3 512 x 212, 16 colours; 3 =
; B1 256 x 212, 256 colours (8 bits a pixel, through the palette's first
; 64); the 16 colour ones have the MSX2's palette (as the console).
; ------------------------------------------------------------
ntc_v9cp:		dw 0			; the port base (0 = not set yet: the platform's)
ntc_v9cb:		db 4			; bits a pixel (4 or 8)
ntc_v9cg:		db 0			; VPoke / VPeek: address bits 18-16
ntc_v9w2:		dw 256			; the Screen's width in dots
ntc_v9a:		ds 12			; the method's arguments
ntc_v9b:		ds 21			; a command's registers (R#32-R#52)

; HL = the platform's port base: the class's base into ntc_v9cp (the first time: HL)
ntc_v9c_port:
			push hl
			ld hl, (ntc_v9cp)
			ld a, h
			or l
			pop hl
			ret nz
			ld (ntc_v9cp), hl
			ret

; C = port 0-15 -> BC (keeps A, DE, HL)
ntc_v9c_p:
			push af
			ld a, (ntc_v9cp)
			add a, c
			ld c, a
			ld a, (ntc_v9cp + 1)
			ld b, a
			pop af
			ret

; E = register, A = value
ntc_v9c_reg:
			push af
			ld c, 4
			call ntc_v9c_p
			out (c), e
			dec c
			pop af
			out (c), a
			ret

; HL = address bits 15-0 (bits 18-16: ntc_v9cg), A = 0 to write, 3 to read: P#0 after
ntc_v9c_adr:
			ld c, 4
			call ntc_v9c_p
			out (c), a
			dec c
			out (c), l
			out (c), h
			ld a, (ntc_v9cg)
			out (c), a
			ld c, 0
			jr ntc_v9c_p

ntc_v9c_wait:
			ld c, 5
			call ntc_v9c_p
ntc_v9c_wt:
			in a, (c)
			rra
			jr c, ntc_v9c_wt
			ret

; ntc_v9b to R#32-R#52, then the command runs
ntc_v9c_go:
			call ntc_v9c_wait
			ld c, 4
			call ntc_v9c_p
			ld a, 32
			out (c), a
			dec c
			ld hl, ntc_v9b
			ld e, 21
ntc_v9c_g1:
			ld a, (hl)
			out (c), a
			inc hl
			dec e
			jr nz, ntc_v9c_g1
			ret

; clear ntc_v9b; DX, DY from ntc_v9a; write mask all, LOP WC = SC, FC from the word at HL
; (the colour, repeated for the pixel size)
ntc_v9c_set:
			push hl
			ld hl, ntc_v9b
			ld de, ntc_v9b + 1
			ld bc, 20
			ld (hl), 0
			ldir
			ld hl, (ntc_v9a)
			ld (ntc_v9b + 4), hl
			ld hl, (ntc_v9a + 2)
			ld (ntc_v9b + 6), hl
			ld a, #0C
			ld (ntc_v9b + 13), a
			ld a, #FF
			ld (ntc_v9b + 14), a
			ld (ntc_v9b + 15), a
			pop hl
			ld a, (hl)
			ld e, a
			ld a, (ntc_v9cb)
			cp 8
			ld a, e
			jr z, ntc_v9c_s8
			and 15
			ld e, a
			rlca
			rlca
			rlca
			rlca
			or e
ntc_v9c_s8:
			ld (ntc_v9b + 16), a
			ld (ntc_v9b + 17), a
			ret

; ---- the entries (the method's port base in HL)
ntc_v9x_port:
			ld hl, (ntc_v9a)
			ld (ntc_v9cp), hl
			ret
; Reg(r, v)
ntc_v9x_reg:
			call ntc_v9c_port
			ld a, (ntc_v9a)
			ld e, a
			ld a, (ntc_v9a + 2)
			jp ntc_v9c_reg
; Status() -> HL: P#5
ntc_v9x_stat:
			call ntc_v9c_port
			ld c, 5
			call ntc_v9c_p
			in l, (c)
			ld h, 0
			ret
; Page(n): VPoke / VPeek's address bits 18-16
ntc_v9x_page:
			ld a, (ntc_v9a)
			and 7
			ld (ntc_v9cg), a
			ret
; VPoke(addr, v)
ntc_v9x_poke:
			call ntc_v9c_port
			ld hl, (ntc_v9a)
			xor a
			call ntc_v9c_adr
			ld a, (ntc_v9a + 2)
			out (c), a
			ret
; VPeek(addr) -> HL
ntc_v9x_peek:
			call ntc_v9c_port
			ld hl, (ntc_v9a)
			ld a, 3
			call ntc_v9c_adr
			in l, (c)
			ld h, 0
			ret
; Palette(n, r, g, b): 0-31 each
ntc_v9x_pal:
			call ntc_v9c_port
			ld a, (ntc_v9a)
			rlca
			rlca
			and #FC
			ld e, 14
			call ntc_v9c_reg
			ld c, 1
			call ntc_v9c_p
			ld a, (ntc_v9a + 2)
			out (c), a
			ld a, (ntc_v9a + 4)
			out (c), a
			ld a, (ntc_v9a + 6)
			out (c), a
			ret
; Screen(m): 1, 2, 3 (above) - set, cleared, cursors off. Other m: nothing
ntc_v9x_screen:
			call ntc_v9c_port
			ld a, (ntc_v9a)
			ld de, #8104			; R#6 B1 256 wide 4 bits, 4 bits a pixel
			cp 1
			jr z, ntc_v9s1
			ld de, #9504			; B3 512 wide
			cp 2
			jr z, ntc_v9s1
			ld de, #8208			; B1 256 wide 8 bits
			cp 3
			ret nz
ntc_v9s1:
			ld hl, 256
			cp 2
			jr nz, ntc_v9s1b
			add hl, hl
ntc_v9s1b:
			ld (ntc_v9w2), hl
			ld a, e
			ld (ntc_v9cb), a
			push de
			ld c, 7
			call ntc_v9c_p
			ld a, 2					; reset, XTAL1
			out (c), a
			xor a
			out (c), a
			pop de
			ld a, d
			ld e, 6
			call ntc_v9c_reg
			ld hl, ntc_v9c_rs
ntc_v9s2:
			ld e, (hl)
			inc e
			jr z, ntc_v9s3
			dec e
			inc hl
			ld a, (hl)
			inc hl
			push hl
			call ntc_v9c_reg
			pop hl
			jr ntc_v9s2
ntc_v9s3:
			ld e, 14				; the palette: the MSX2's 16
			xor a
			call ntc_v9c_reg
			ld c, 1
			call ntc_v9c_p
			ld hl, ntc_v9c_pals
			ld e, 48
ntc_v9s4:
			ld a, (hl)
			out (c), a
			inc hl
			dec e
			jr nz, ntc_v9s4
			ld hl, 0				; cleared: colour 0
			ld (ntc_v9a), hl
			ld (ntc_v9a + 2), hl
			ld (ntc_v9a + 8), hl
			ld hl, (ntc_v9w2)
			ld (ntc_v9a + 4), hl
			ld hl, 212
			ld (ntc_v9a + 6), hl
			jr ntc_v9x_box2
ntc_v9c_rs:		db 7, 0, 8, #C2, 9, 0, 13, 0, 15, 0, 16, 0, 17, 0, 18, 0, 19, 0, 20, 0, 21, 0, 22, 0, 23, 0, 24, 0, #FF	; @const
ntc_v9c_pals:	db 0, 0, 0,  0, 0, 0,  4, 27, 4,  13, 31, 13	; @const
				db 4, 4, 31,  9, 13, 31,  22, 4, 4,  9, 27, 31
				db 31, 4, 4,  31, 13, 13,  27, 27, 4,  27, 27, 18
				db 4, 18, 4,  27, 9, 22,  22, 22, 22,  31, 31, 31
; Box(x, y, w, h, c): filled (LMMV)
ntc_v9x_box:
			call ntc_v9c_port
ntc_v9x_box2:
			ld hl, ntc_v9a + 8
			call ntc_v9c_set
			ld hl, (ntc_v9a + 4)
			ld (ntc_v9b + 8), hl
			ld hl, (ntc_v9a + 6)
			ld (ntc_v9b + 10), hl
			ld a, #20				; LMMV
			ld (ntc_v9b + 20), a
			jp ntc_v9c_go
; PSet(x, y, c)
ntc_v9x_pset:
			call ntc_v9c_port
			ld hl, ntc_v9a + 4
			call ntc_v9c_set
			ld a, #E0				; PSET
			ld (ntc_v9b + 20), a
			jp ntc_v9c_go
; Line(x1, y1, x2, y2, c)
ntc_v9x_line:
			call ntc_v9c_port
			ld hl, ntc_v9a + 8
			call ntc_v9c_set
			ld hl, (ntc_v9a + 4)	; dx
			ld de, (ntc_v9a)
			or a
			sbc hl, de
			ld a, 0
			jr nc, ntc_v9l1
			ld a, 4					; DIX: left
			ex de, hl
			ld hl, 0
			or a
			sbc hl, de
			ld a, 4
ntc_v9l1:
			ld (ntc_v9b + 8), hl
			ld (ntc_v9b + 12), a
			ld hl, (ntc_v9a + 6)	; dy
			ld de, (ntc_v9a + 2)
			or a
			sbc hl, de
			jr nc, ntc_v9l2
			ld a, (ntc_v9b + 12)
			or 8					; DIY: up
			ld (ntc_v9b + 12), a
			ex de, hl
			ld hl, 0
			or a
			sbc hl, de
ntc_v9l2:
			ld (ntc_v9b + 10), hl
			ld de, (ntc_v9b + 8)
			or a
			sbc hl, de
			jr c, ntc_v9l3			; |dy| < |dx|: long side X
			ld hl, (ntc_v9b + 10)
			ld (ntc_v9b + 8), hl
			ld (ntc_v9b + 10), de
			ld a, (ntc_v9b + 12)
			or 1					; MAJ: long side Y
			ld (ntc_v9b + 12), a
ntc_v9l3:
			ld a, #B0				; LINE
			ld (ntc_v9b + 20), a
			jp ntc_v9c_go
; Copy(sx, sy, dx, dy, w, h): LMMM
ntc_v9x_copy:
			call ntc_v9c_port
			ld hl, ntc_v9a + 8		; (a colour for the setup only)
			call ntc_v9c_set
			ld hl, ntc_v9a
			ld de, ntc_v9b
			ld bc, 12
			ldir
			ld a, #40				; LMMM
			ld (ntc_v9b + 20), a
			jp ntc_v9c_go
; Wait: until the chip's command is done
ntc_v9x_wait:
			call ntc_v9c_port
			jp ntc_v9c_wait

;## ntc_font6 @const @unit @ramonly @if:ntc_vdp
; ------------------------------------------------------------
; ntc_font6 - characters 32-126, 8 bytes each, drawn in the left 6
; pixels (the TMS9918's text modes show 6): the X11 "misc-fixed" 5x8
; font (public domain), a pixel in from the left
; ------------------------------------------------------------
ntc_font6:
			db #00, #00, #00, #00, #00, #00, #00, #00	; 32  
			db #00, #10, #10, #10, #10, #00, #10, #00	; 33 !
			db #00, #28, #28, #28, #00, #00, #00, #00	; 34 "
			db #28, #28, #7C, #28, #7C, #28, #28, #00	; 35 #
			db #10, #38, #50, #38, #14, #38, #10, #00	; 36 $
			db #00, #20, #28, #10, #28, #08, #00, #00	; 37 %
			db #20, #50, #50, #20, #50, #50, #28, #00	; 38 &
			db #00, #10, #10, #10, #00, #00, #00, #00	; 39 '
			db #00, #10, #20, #20, #20, #20, #10, #00	; 40 (
			db #00, #20, #10, #10, #10, #10, #20, #00	; 41 )
			db #00, #00, #48, #30, #78, #30, #48, #00	; 42 *
			db #00, #00, #10, #10, #7C, #10, #10, #00	; 43 +
			db #00, #00, #00, #00, #00, #18, #10, #20	; 44 ,
			db #00, #00, #00, #00, #78, #00, #00, #00	; 45 -
			db #00, #00, #00, #00, #00, #10, #38, #10	; 46 .
			db #00, #08, #08, #10, #20, #40, #40, #00	; 47 /
			db #00, #10, #28, #28, #28, #28, #10, #00	; 48 0
			db #00, #10, #30, #10, #10, #10, #38, #00	; 49 1
			db #00, #30, #48, #08, #30, #40, #78, #00	; 50 2
			db #00, #78, #10, #30, #08, #48, #30, #00	; 51 3
			db #00, #10, #30, #50, #78, #10, #10, #00	; 52 4
			db #00, #78, #40, #70, #08, #48, #30, #00	; 53 5
			db #00, #30, #40, #70, #48, #48, #30, #00	; 54 6
			db #00, #78, #08, #10, #10, #20, #20, #00	; 55 7
			db #00, #30, #48, #30, #48, #48, #30, #00	; 56 8
			db #00, #30, #48, #48, #38, #08, #30, #00	; 57 9
			db #00, #00, #30, #30, #00, #30, #30, #00	; 58 :
			db #00, #00, #18, #18, #00, #18, #10, #20	; 59 semicolon
			db #00, #08, #10, #20, #20, #10, #08, #00	; 60 <
			db #00, #00, #00, #78, #00, #78, #00, #00	; 61 =
			db #00, #20, #10, #08, #08, #10, #20, #00	; 62 >
			db #00, #10, #28, #08, #10, #00, #10, #00	; 63 ?
			db #18, #24, #4C, #54, #54, #48, #20, #18	; 64 @
			db #00, #30, #48, #48, #78, #48, #48, #00	; 65 A
			db #00, #70, #48, #70, #48, #48, #70, #00	; 66 B
			db #00, #30, #48, #40, #40, #48, #30, #00	; 67 C
			db #00, #70, #48, #48, #48, #48, #70, #00	; 68 D
			db #00, #78, #40, #70, #40, #40, #78, #00	; 69 E
			db #00, #78, #40, #70, #40, #40, #40, #00	; 70 F
			db #00, #30, #48, #40, #58, #48, #30, #00	; 71 G
			db #00, #48, #48, #78, #48, #48, #48, #00	; 72 H
			db #00, #38, #10, #10, #10, #10, #38, #00	; 73 I
			db #00, #38, #10, #10, #10, #50, #20, #00	; 74 J
			db #00, #48, #50, #60, #50, #50, #48, #00	; 75 K
			db #00, #40, #40, #40, #40, #40, #78, #00	; 76 L
			db #00, #48, #78, #78, #48, #48, #48, #00	; 77 M
			db #00, #48, #68, #78, #58, #58, #48, #00	; 78 N
			db #00, #30, #48, #48, #48, #48, #30, #00	; 79 O
			db #00, #70, #48, #48, #70, #40, #40, #00	; 80 P
			db #00, #30, #48, #48, #68, #58, #30, #08	; 81 Q
			db #00, #70, #48, #48, #70, #48, #48, #00	; 82 R
			db #00, #30, #48, #20, #10, #48, #30, #00	; 83 S
			db #00, #38, #10, #10, #10, #10, #10, #00	; 84 T
			db #00, #48, #48, #48, #48, #48, #30, #00	; 85 U
			db #00, #48, #48, #48, #48, #30, #30, #00	; 86 V
			db #00, #48, #48, #48, #78, #78, #48, #00	; 87 W
			db #00, #48, #48, #30, #30, #48, #48, #00	; 88 X
			db #00, #44, #44, #28, #10, #10, #10, #00	; 89 Y
			db #00, #78, #08, #10, #20, #40, #78, #00	; 90 Z
			db #00, #38, #20, #20, #20, #20, #38, #00	; 91 [
			db #00, #40, #40, #20, #10, #08, #08, #00	; 92 \
			db #00, #38, #08, #08, #08, #08, #38, #00	; 93 ]
			db #00, #10, #28, #00, #00, #00, #00, #00	; 94 ^
			db #00, #00, #00, #00, #00, #00, #00, #78	; 95 _
			db #00, #20, #10, #00, #00, #00, #00, #00	; 96 `
			db #00, #00, #00, #38, #48, #48, #38, #00	; 97 a
			db #00, #40, #40, #70, #48, #48, #70, #00	; 98 b
			db #00, #00, #00, #18, #20, #20, #18, #00	; 99 c
			db #00, #08, #08, #38, #48, #48, #38, #00	; 100 d
			db #00, #00, #00, #30, #58, #60, #30, #00	; 101 e
			db #00, #10, #28, #20, #70, #20, #20, #00	; 102 f
			db #00, #00, #00, #30, #48, #38, #08, #30	; 103 g
			db #00, #40, #40, #70, #48, #48, #48, #00	; 104 h
			db #00, #10, #00, #30, #10, #10, #38, #00	; 105 i
			db #00, #08, #00, #08, #08, #08, #28, #10	; 106 j
			db #00, #40, #40, #48, #70, #48, #48, #00	; 107 k
			db #00, #30, #10, #10, #10, #10, #38, #00	; 108 l
			db #00, #00, #00, #68, #54, #54, #54, #00	; 109 m
			db #00, #00, #00, #70, #48, #48, #48, #00	; 110 n
			db #00, #00, #00, #30, #48, #48, #30, #00	; 111 o
			db #00, #00, #00, #70, #48, #70, #40, #40	; 112 p
			db #00, #00, #00, #38, #48, #38, #08, #08	; 113 q
			db #00, #00, #00, #50, #68, #40, #40, #00	; 114 r
			db #00, #00, #00, #18, #30, #08, #30, #00	; 115 s
			db #00, #20, #20, #70, #20, #28, #10, #00	; 116 t
			db #00, #00, #00, #48, #48, #48, #38, #00	; 117 u
			db #00, #00, #00, #28, #28, #28, #10, #00	; 118 v
			db #00, #00, #00, #44, #54, #54, #28, #00	; 119 w
			db #00, #00, #00, #48, #30, #30, #48, #00	; 120 x
			db #00, #00, #00, #48, #48, #38, #48, #30	; 121 y
			db #00, #00, #00, #78, #10, #20, #78, #00	; 122 z
			db #18, #20, #10, #60, #10, #20, #18, #00	; 123 {
			db #00, #10, #10, #10, #10, #10, #10, #00	; 124 |
			db #60, #10, #20, #18, #20, #10, #60, #00	; 125 }
			db #00, #28, #50, #00, #00, #00, #00, #00	; 126 ~

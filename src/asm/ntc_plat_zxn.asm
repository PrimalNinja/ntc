; ============================================================
; NTC Platform - ZX Spectrum Next, direct hardware (native)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; No call, no push: SP stays in the thread. Every routine is
; entered with jp, return address in IX, and ends with jp (ix).
;
; Memory  laid out as the CPC's (the cpc platform's): the Next's 8K MMU slots hold
;         RAM pages 16-21 at #0000-#BFFF (the program from #0040, its arrays,
;         the stack from #C000 down) and the screen - 16K bank 5, pages 10 and
;         11, what the ULA and the tilemap show - at #C000-#FFFF.
;           #0000-#003F  RST / IM 1 (#0038: the interrupt handler's jump)
;           #0040-       the program, its arrays, the Memory class's heap
;           #BE00-#BFFF  the stack (ntc_plat_memtop: #BE00)
;           #C000-#DAFF  the ULA screen (Graphics, later)
;           #E000-#E9FF  the text: the tilemap, 80 x 32 (40 x 32: the first 1280)
;           #EC00-#F3FF  its characters: 256 x 8 bytes (1 bit a pixel)
; Start   NAME.NEX (SAVENEX at the end of the program): NextZXOS loads banks 8, 9,
;         10 (the program) and 5 (a start stub at #7E00) and runs the stub with
;         banks 5, 2, 0 in #4000-#FFFF. The stub turns the NMI buttons off
;         (NextReg 6 bits 3, 4: Multiface M1, DivMMC DRIVE), DivMMC's automatic
;         paging off (NextReg 10 bit 4 - it would page its ROM in at #0000,
;         #0038, #0066 ...) and DivMMC's memory out, sets 28MHz and IM 1, maps
;         the slots (slot 3, where it runs, last: from its copy at #FE00) and
;         jumps to ntc_start. NextRegs through ports #243B / #253B (no Z80N
;         opcodes: any assembler, any harness).
; Screen  the tilemap in text mode: one byte a character (the character's code is
;         its tile), 40 x 32 (Mode 0, 1) or 80 x 32 (Mode 2), on top of the ULA
;         (Layer 2 and the sprites off). Yellow on blue, as the CPC starts. The
;         font: font8x8_basic (public domain), copied to ntc_font and the tiles
;         by the first Mode.
; Keys    the 8 x 5 keyboard (ports #xxFE): Caps Shift capitals, Symbol Shift
;         the symbols on the keys (+ the 128's: ~ | \ { } [ ]). Caps + 0 is DEL
;         (127), Caps + Space Break (27). New presses only, no auto repeat.
; IRQ     IM 1 at #0038 in RAM, normal mode only, as the cpc platform: the line
;         interrupt, moved on 52 raster lines each time - 6 a frame of 312
;         lines, 300 a second, as the CPC's (the ULA's frame interrupt off).
; End     ntc_plat_exit: a soft reset (NextReg 2) - back to NextZXOS.
; ============================================================
;@name     ZX Spectrum Next - direct hardware (native)
;@org      #0040
;@text     glyph
;@scrinit  1
;@irq      1
;@stack    #C000
;@cols     40
;@rows     32
; ============================================================

;## ntc_plat_data
ntc_curx:		db 0			; cursor column (0 based)
ntc_cury:		db 0			; cursor row (0 based)
ntc_smode:		db 1			; screen mode (0, 1: 40 columns, 2: 80)
ntc_sinit:		db 0			; 1 once the tilemap is set up
ntc_scols:		db 40			; columns
ntc_wrapped:	db 0			; 1 = the last character wrapped to the next line
ntc_klink:		dw 0			; return for ntc_plat_getkey
ntc_kidx:		db 0			; key index found by the scan
ntc_kcur:		ds 8			; the 8 half rows this scan (0 = pressed)
ntc_kprev:		db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ntc_irqset:		db 0			; 1 = our interrupt handler is at #38
ntc_irqold:		ds 3			; the 3 bytes it replaced
ntc_irqhl:		dw 0			; handler scratch
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none
ntc_zxvs:		db 0			; 1: this interrupt is a frame's first (line 0: to ntc_isl_tick in C)
ntc_zxline:		dw 0			; the raster line the line interrupt is set to
ntc_zxsel:		db 0			; the NextReg selected (#243B) by code interrupts can get into: the
								; handler selects it again after its own (store it, then select)
ntc_zxl2:		db 0			; 1 = Layer 2 is on (Graphics); Mode turns it off
ZXN_MAP			equ #E000		; the tilemap (bank 5 + #2000: NextReg #6E = #20)
ZXN_TILES		equ #EC00		; its characters (bank 5 + #2C00: NextReg #6F = #2C)
ZXN_ROWS		equ 32
ZXN_PAPER		equ #02			; RRRGGGBB: blue
ZXN_INK			equ #FC			; yellow

;## ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
; ------------------------------------------------------------
; ntc_plat_putc - A = character 32-126 (others print as ?), draw it
; ------------------------------------------------------------
ntc_plat_putc:
			cp 32
			jr c, ntc_pc_bad
			cp 127
			jr c, ntc_zx_put
ntc_pc_bad:
			ld a, '?'
			jr ntc_zx_put

; ------------------------------------------------------------
; ntc_plat_putglyph - DE = an 8 byte glyph in ntc_font (ZOSCII text): that
; character at the cursor, the cursor on (a glyph not in ntc_font: ?)
; ------------------------------------------------------------
ntc_plat_putglyph:
			ld hl, -ntc_font
			add hl, de				; HL = the glyph's offset: 0 .. 95 * 8 - 1
			ld a, h
			cp (95 * 8) / 256
			jr c, ntc_pg_in
			jr nz, ntc_pc_bad
			ld a, l
			cp (95 * 8) & 255
			jr nc, ntc_pc_bad
ntc_pg_in:
			srl h
			rr l
			srl h
			rr l
			srl h
			rr l
			ld a, l
			add a, 32
			; fall into ntc_zx_put

; A = a character code: into the tilemap at the cursor (its tile), the cursor on
ntc_zx_put:
			ld c, a
			ld a, (ntc_cury)		; HL = ZXN_MAP + row * columns + column
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld d, h
			ld e, l
			add hl, hl
			add hl, hl
			add hl, de				; row * 40
			ld a, (ntc_scols)
			cp 80
			jr nz, $+3
			add hl, hl				; row * 80
			ld a, (ntc_curx)
			ld e, a
			ld d, ZXN_MAP / 256		; (ZXN_MAP's low byte is 0)
			add hl, de
			ld (hl), c
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
			cp ZXN_ROWS
			jp nc, ntc_plat_scroll
			ld (ntc_cury), a
			jp (ix)


;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
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
			ld a, (ntc_cury)		; HL = ZXN_MAP + row * columns + column
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld d, h
			ld e, l
			add hl, hl
			add hl, hl
			add hl, de				; row * 40
			ld a, (ntc_scols)
			cp 80
			jr nz, $+3
			add hl, hl				; row * 80
			ld a, (ntc_curx)
			ld e, a
			ld d, ZXN_MAP / 256		; (ZXN_MAP's low byte is 0)
			add hl, de
			ld (hl), ' '
ntc_bs_none:
			jp (ix)

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
; ------------------------------------------------------------
; ntc_plat_mode - A = mode: 0, 1 = 40 x 32, 2 (3) = 80 x 32. The first time the
; tilemap is set up (font, palette, its registers); then its width, clear screen
; ------------------------------------------------------------
ntc_plat_mode:
			cp 3
			jr c, ntc_md_ok
			ld a, 2
ntc_md_ok:
			ld (ntc_smode), a
			ld a, (ntc_sinit)
			or a
			jp nz, ntc_md_set
			inc a
			ld (ntc_sinit), a
			ld hl, ntc_zxfont		; the font to ntc_font (ZOSCII's glyphs point there)
			ld de, ntc_font
			ld bc, 95 * 8
			ldir
			ld hl, ZXN_TILES		; the tiles: 0-31 and 127-255 blank, 32-126 the font
			ld de, ZXN_TILES + 1
			ld bc, 256 * 8 - 1
			ld (hl), 0
			ldir
			ld hl, ntc_zxfont
			ld de, ZXN_TILES + 32 * 8
			ld bc, 95 * 8
			ldir
			ld bc, #243B
			ld a, #43
			out (c), a
			inc b
			ld a, #30
			out (c), a
			dec b					; palette: the tilemap's first, index 0 paper, 1 ink
			ld bc, #243B
			ld a, #40
			out (c), a
			inc b
			ld a, 0
			out (c), a
			dec b
			ld a, #41
			out (c), a
			inc b
			ld a, ZXN_PAPER
			out (c), a
			ld a, ZXN_INK
			out (c), a				; (the index moves on by itself)
			ld bc, #243B
			ld a, #6C
			out (c), a
			inc b
			ld a, 0
			out (c), a
			dec b					; every tile's attribute: palette offset 0
			ld bc, #243B
			ld a, #6E
			out (c), a
			inc b
			ld a, #20
			out (c), a
			dec b					; the map at bank 5 + #2000
			ld bc, #243B
			ld a, #6F
			out (c), a
			inc b
			ld a, #2C
			out (c), a
			dec b					; the tiles at bank 5 + #2C00
			ld bc, #243B
			ld bc, #243B
			ld a, #2F
			out (c), a
			inc b
			ld a, 0
			out (c), a
			dec b					; no scroll
			ld bc, #243B
			ld a, #30
			out (c), a
			inc b
			ld a, 0
			out (c), a
			dec b
			ld bc, #243B
			ld a, #31
			out (c), a
			inc b
			ld a, 0
			out (c), a
			dec b
			ld bc, #243B
			ld a, #1C
			out (c), a
			inc b
			ld a, 8
			out (c), a
			dec b					; the tilemap's clip window: the whole of it
			ld a, #1B
			out (c), a
			inc b
			xor a
			out (c), a
			ld a, 159
			out (c), a
			xor a
			out (c), a
			dec a
			out (c), a
ntc_md_set:
			ld hl, ntc_md_regs		; the text screen alone: Layer 2 off (Graphics turns it on), the
			ld bc, #243B			; ULA on, the tilemap opaque, bank 5's first page at #C000
			ld e, 9
ntc_md_rg:
			ld a, (hl)
			inc hl
			out (c), a
			inc b
			ld a, (hl)
			inc hl
			out (c), a
			dec b
			dec e
			jr nz, ntc_md_rg
			xor a
			ld (ntc_zxl2), a
			ld a, (ntc_smode)
			cp 2
			ld a, 40
			ld e, #A9				; tilemap on, 40 x 32, no attributes, text mode, over the ULA
			jr nz, ntc_md_40
			ld a, 80
			ld e, #E9				; the same, 80 x 32
ntc_md_40:
			ld (ntc_scols), a
			ld bc, #243B
			ld a, #6B
			out (c), a
			inc b
			ld a, e
			out (c), a
			jp ntc_plat_cls

; NextReg, value: Layer 2 off, the ULA from bank 5, no Timex mode (#69); sprites off, the
; layers' order as at reset (#15); the ULA on, no ULA+ (#68); the tilemap's index 15
; transparent - its paper (0) not (#4C); page 10 at #C000 (#56: Graphics draws there); the
; tilemap's paper its colour again (Graphics makes it see-through)
ntc_md_regs:	db #69, 0, #15, 0, #68, 0, #4C, #0F, #56, 10, #57, 11, #43, #30, #40, 0, #41, ZXN_PAPER

; the font: font8x8_basic by Daniel Hepper (public domain) - chars 32-126, 8 bytes each,
; bit 7 the leftmost pixel
ntc_zxfont:
			db #00, #00, #00, #00, #00, #00, #00, #00	; 32
			db #18, #3C, #3C, #18, #18, #00, #18, #00	; 33 !
			db #6C, #6C, #00, #00, #00, #00, #00, #00	; 34 "
			db #6C, #6C, #FE, #6C, #FE, #6C, #6C, #00	; 35 #
			db #30, #7C, #C0, #78, #0C, #F8, #30, #00	; 36 $
			db #00, #C6, #CC, #18, #30, #66, #C6, #00	; 37 %
			db #38, #6C, #38, #76, #DC, #CC, #76, #00	; 38 &
			db #60, #60, #C0, #00, #00, #00, #00, #00	; 39 '
			db #18, #30, #60, #60, #60, #30, #18, #00	; 40 (
			db #60, #30, #18, #18, #18, #30, #60, #00	; 41 )
			db #00, #66, #3C, #FF, #3C, #66, #00, #00	; 42 *
			db #00, #30, #30, #FC, #30, #30, #00, #00	; 43 +
			db #00, #00, #00, #00, #00, #30, #30, #60	; 44 ,
			db #00, #00, #00, #FC, #00, #00, #00, #00	; 45 -
			db #00, #00, #00, #00, #00, #30, #30, #00	; 46 .
			db #06, #0C, #18, #30, #60, #C0, #80, #00	; 47 /
			db #7C, #C6, #CE, #DE, #F6, #E6, #7C, #00	; 48 0
			db #30, #70, #30, #30, #30, #30, #FC, #00	; 49 1
			db #78, #CC, #0C, #38, #60, #CC, #FC, #00	; 50 2
			db #78, #CC, #0C, #38, #0C, #CC, #78, #00	; 51 3
			db #1C, #3C, #6C, #CC, #FE, #0C, #1E, #00	; 52 4
			db #FC, #C0, #F8, #0C, #0C, #CC, #78, #00	; 53 5
			db #38, #60, #C0, #F8, #CC, #CC, #78, #00	; 54 6
			db #FC, #CC, #0C, #18, #30, #30, #30, #00	; 55 7
			db #78, #CC, #CC, #78, #CC, #CC, #78, #00	; 56 8
			db #78, #CC, #CC, #7C, #0C, #18, #70, #00	; 57 9
			db #00, #30, #30, #00, #00, #30, #30, #00	; 58 :
			db #00, #30, #30, #00, #00, #30, #30, #60	; 59 ;
			db #18, #30, #60, #C0, #60, #30, #18, #00	; 60 <
			db #00, #00, #FC, #00, #00, #FC, #00, #00	; 61 =
			db #60, #30, #18, #0C, #18, #30, #60, #00	; 62 >
			db #78, #CC, #0C, #18, #30, #00, #30, #00	; 63 ?
			db #7C, #C6, #DE, #DE, #DE, #C0, #78, #00	; 64 @
			db #30, #78, #CC, #CC, #FC, #CC, #CC, #00	; 65 A
			db #FC, #66, #66, #7C, #66, #66, #FC, #00	; 66 B
			db #3C, #66, #C0, #C0, #C0, #66, #3C, #00	; 67 C
			db #F8, #6C, #66, #66, #66, #6C, #F8, #00	; 68 D
			db #FE, #62, #68, #78, #68, #62, #FE, #00	; 69 E
			db #FE, #62, #68, #78, #68, #60, #F0, #00	; 70 F
			db #3C, #66, #C0, #C0, #CE, #66, #3E, #00	; 71 G
			db #CC, #CC, #CC, #FC, #CC, #CC, #CC, #00	; 72 H
			db #78, #30, #30, #30, #30, #30, #78, #00	; 73 I
			db #1E, #0C, #0C, #0C, #CC, #CC, #78, #00	; 74 J
			db #E6, #66, #6C, #78, #6C, #66, #E6, #00	; 75 K
			db #F0, #60, #60, #60, #62, #66, #FE, #00	; 76 L
			db #C6, #EE, #FE, #FE, #D6, #C6, #C6, #00	; 77 M
			db #C6, #E6, #F6, #DE, #CE, #C6, #C6, #00	; 78 N
			db #38, #6C, #C6, #C6, #C6, #6C, #38, #00	; 79 O
			db #FC, #66, #66, #7C, #60, #60, #F0, #00	; 80 P
			db #78, #CC, #CC, #CC, #DC, #78, #1C, #00	; 81 Q
			db #FC, #66, #66, #7C, #6C, #66, #E6, #00	; 82 R
			db #78, #CC, #E0, #70, #1C, #CC, #78, #00	; 83 S
			db #FC, #B4, #30, #30, #30, #30, #78, #00	; 84 T
			db #CC, #CC, #CC, #CC, #CC, #CC, #FC, #00	; 85 U
			db #CC, #CC, #CC, #CC, #CC, #78, #30, #00	; 86 V
			db #C6, #C6, #C6, #D6, #FE, #EE, #C6, #00	; 87 W
			db #C6, #C6, #6C, #38, #38, #6C, #C6, #00	; 88 X
			db #CC, #CC, #CC, #78, #30, #30, #78, #00	; 89 Y
			db #FE, #C6, #8C, #18, #32, #66, #FE, #00	; 90 Z
			db #78, #60, #60, #60, #60, #60, #78, #00	; 91 [
			db #C0, #60, #30, #18, #0C, #06, #02, #00	; 92 \
			db #78, #18, #18, #18, #18, #18, #78, #00	; 93 ]
			db #10, #38, #6C, #C6, #00, #00, #00, #00	; 94 ^
			db #00, #00, #00, #00, #00, #00, #00, #FF	; 95 _
			db #30, #30, #18, #00, #00, #00, #00, #00	; 96 `
			db #00, #00, #78, #0C, #7C, #CC, #76, #00	; 97 a
			db #E0, #60, #60, #7C, #66, #66, #DC, #00	; 98 b
			db #00, #00, #78, #CC, #C0, #CC, #78, #00	; 99 c
			db #1C, #0C, #0C, #7C, #CC, #CC, #76, #00	; 100 d
			db #00, #00, #78, #CC, #FC, #C0, #78, #00	; 101 e
			db #38, #6C, #60, #F0, #60, #60, #F0, #00	; 102 f
			db #00, #00, #76, #CC, #CC, #7C, #0C, #F8	; 103 g
			db #E0, #60, #6C, #76, #66, #66, #E6, #00	; 104 h
			db #30, #00, #70, #30, #30, #30, #78, #00	; 105 i
			db #0C, #00, #0C, #0C, #0C, #CC, #CC, #78	; 106 j
			db #E0, #60, #66, #6C, #78, #6C, #E6, #00	; 107 k
			db #70, #30, #30, #30, #30, #30, #78, #00	; 108 l
			db #00, #00, #CC, #FE, #FE, #D6, #C6, #00	; 109 m
			db #00, #00, #F8, #CC, #CC, #CC, #CC, #00	; 110 n
			db #00, #00, #78, #CC, #CC, #CC, #78, #00	; 111 o
			db #00, #00, #DC, #66, #66, #7C, #60, #F0	; 112 p
			db #00, #00, #76, #CC, #CC, #7C, #0C, #1E	; 113 q
			db #00, #00, #DC, #76, #66, #60, #F0, #00	; 114 r
			db #00, #00, #7C, #C0, #78, #0C, #F8, #00	; 115 s
			db #10, #30, #7C, #30, #30, #34, #18, #00	; 116 t
			db #00, #00, #CC, #CC, #CC, #CC, #76, #00	; 117 u
			db #00, #00, #CC, #CC, #CC, #78, #30, #00	; 118 v
			db #00, #00, #C6, #D6, #FE, #FE, #6C, #00	; 119 w
			db #00, #00, #C6, #6C, #38, #6C, #C6, #00	; 120 x
			db #00, #00, #CC, #CC, #CC, #7C, #0C, #F8	; 121 y
			db #00, #00, #FC, #98, #30, #64, #FC, #00	; 122 z
			db #1C, #30, #30, #E0, #30, #30, #1C, #00	; 123 {
			db #18, #18, #18, #00, #18, #18, #18, #00	; 124 |
			db #E0, #30, #30, #1C, #30, #30, #E0, #00	; 125 }
			db #76, #DC, #00, #00, #00, #00, #00, #00	; 126 ~

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
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
			cp ZXN_ROWS
			jr c, ntc_lc_ymax
			ld a, ZXN_ROWS - 1
ntc_lc_ymax:
			ld (ntc_cury), a
			jp (ix)
;## ntc_plat_scroll ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_scroll - move rows 1-31 up one, clear row 31
; ------------------------------------------------------------
ntc_plat_scroll:
			ld a, ZXN_ROWS - 1
			ld (ntc_cury), a
			ld a, (ntc_scols)
			ld c, a
			ld b, 0					; BC = a row
			ld hl, ZXN_MAP
			add hl, bc
			ld de, ZXN_MAP
			cp 80
			ld bc, (ZXN_ROWS - 1) * 40
			jr nz, ntc_sc_40
			ld bc, (ZXN_ROWS - 1) * 80
ntc_sc_40:
			ldir					; DE = the last row
			ld h, d
			ld l, e
			ld (hl), ' '
			inc de
			ld c, a
			dec c
			ld b, 0
			ldir
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_cls - the whole tilemap spaces, cursor home
; ------------------------------------------------------------
ntc_plat_cls:
			ld hl, ZXN_MAP
			ld de, ZXN_MAP + 1
			ld bc, ZXN_ROWS * 80 - 1
			ld (hl), ' '
			ldir
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
			ld hl, ntc_kcur
			ld b, #FE				; half row 0 (address line A8 low) ... 7 (A15)
ntc_ks_line:
			ld c, #FE
			in a, (c)
			or #E0					; (bits 5-7: no keys)
			ld (hl), a
			inc hl
			rlc b
			jr c, ntc_ks_line		; (B's 0 bit moves up: done after A15)
			ld a, #FF
			ld (ntc_kidx), a
			ld hl, ntc_kcur
			ld de, ntc_kprev
			ld iy, ntc_kign
			ld bc, #0800			; B = 8 half rows, C = key index (half row * 8 + bit)
ntc_ks_find:
			ld a, (ntc_kidx)
			inc a
			jr nz, ntc_ks_next
			ld a, (hl)
			cpl
			ex de, hl
			and (hl)				; pressed now, released last scan
			ex de, hl
			and (iy+0)				; not Caps Shift / Symbol Shift
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
			ld bc, 8
			ldir
			ld a, (ntc_kidx)
			cp #FF
			jr z, ntc_ks_none
			ld e, a
			ld d, 0
			ld hl, ntc_keymapy		; Symbol Shift (half row 7 bit 1) first
			ld a, (ntc_kcur + 7)
			bit 1, a
			jr z, ntc_ks_map
			ld hl, ntc_keymapc		; then Caps Shift (half row 0 bit 0)
			ld a, (ntc_kcur)
			bit 0, a
			jr z, ntc_ks_map
			ld hl, ntc_keymap
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
			ld bc, 7000				; about 6ms between scans at 28MHz (debounce)
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

; keys that never count as a press on their own (Caps Shift, Symbol Shift)
ntc_kign:		db #FE, #FF, #FF, #FF, #FF, #FF, #FF, #FD

; half row 0-7, bit 0-4 -> ASCII (0 = nothing); 8 a half row, 5-7 unused
; 0 Caps Z X C V   1 A S D F G   2 Q W E R T   3 1 2 3 4 5
; 4 0 9 8 7 6      5 P O I U Y  6 Enter L K J H   7 Space Symbol M N B
ntc_keymap:
			db 0, "z", "x", "c", "v", 0, 0, 0
			db "a", "s", "d", "f", "g", 0, 0, 0
			db "q", "w", "e", "r", "t", 0, 0, 0
			db "1", "2", "3", "4", "5", 0, 0, 0
			db "0", "9", "8", "7", "6", 0, 0, 0
			db "p", "o", "i", "u", "y", 0, 0, 0
			db 13, "l", "k", "j", "h", 0, 0, 0
			db " ", 0, "m", "n", "b", 0, 0, 0
ntc_keymapc:								; Caps Shift: capitals; + 0 DEL, + Space Break
			db 0, "Z", "X", "C", "V", 0, 0, 0
			db "A", "S", "D", "F", "G", 0, 0, 0
			db "Q", "W", "E", "R", "T", 0, 0, 0
			db 0, 0, 0, 0, 0, 0, 0, 0			; (Edit, Caps Lock, True / Inverse Video, cursor left)
			db 127, 0, 0, 0, 0, 0, 0, 0			; (Graphics, cursor right / up / down)
			db "P", "O", "I", "U", "Y", 0, 0, 0
			db 13, "L", "K", "J", "H", 0, 0, 0
			db 27, 0, "M", "N", "B", 0, 0, 0
ntc_keymapy:								; Symbol Shift: the symbols on the keys (+ the 128's ~ | \ { } [ ])
			db 0, ":", 0, "?", "/", 0, 0, 0		; (X: pound)
			db "~", "|", 92, "{", "}", 0, 0, 0
			db 0, 0, 0, "<", ">", 0, 0, 0		; (Q, W, E: <= <> >=)
			db "!", "@", "#", "$", "%", 0, 0, 0
			db "_", ")", "(", 39, "&", 0, 0, 0
			db 34, ";", 0, "]", "[", 0, 0, 0		; (I: copyright)
			db 13, "=", "+", "-", "^", 0, 0, 0
			db " ", 0, ".", ",", "*", 0, 0, 0

;## ntc_plat_frame ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_frame - wait for the end of the display (raster line 192: the
; bottom border starts). Normal mode: interrupts in while waiting
; ------------------------------------------------------------
ntc_plat_frame:
			ld (ntc_klink), ix		; (ntc_klink: the return - IX runs ntc_fr_line)
			ld a, (ntc_nmode)
			or a
			jr z, ntc_fr_go
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_fr_go:
			ld bc, #243B
ntc_fr_out:						; first out of lines 192 and on (the border, the sync)
			ld ix, ntc_fr_out2
			jr ntc_fr_line
ntc_fr_out2:
			jr nz, ntc_fr_out
ntc_fr_in:						; then wait for line 192
			ld ix, ntc_fr_in2
			jr ntc_fr_line
ntc_fr_in2:
			jr z, ntc_fr_in
			jr ntc_fr_at
; the raster line (NextReg #1E: its bit 8, #1F: bits 0-7), its two halves read
; again until bit 8 is the same both times (line 255 to 256 between them reads
; as 0): NZ = line 192 or more. Back to IX; keeps BC (#243B)
ntc_fr_line:
			ld a, #1E
			ld (ntc_zxsel), a		; (interrupts are in: the handler selects it again)
			out (c), a
			inc b
			in d, (c)
			dec b
			ld a, #1F
			ld (ntc_zxsel), a
			out (c), a
			inc b
			in e, (c)
			dec b
			ld a, #1E
			ld (ntc_zxsel), a
			out (c), a
			inc b
			in a, (c)
			dec b
			cp d
			jr nz, ntc_fr_line
			rra
			jr c, ntc_fr_lnz		; 256 and on
			ld a, e
			cp 192
			ccf
			sbc a, a				; #FF: 192-255, 0: below
			jp (ix)
ntc_fr_lnz:
			or 1
			jp (ix)
ntc_fr_at:
			di
			ld a, (ntc_nmode)
			or a
			jr z, ntc_fr_done
			ld sp, (ntc_ip)
ntc_fr_done:
			ld ix, (ntc_klink)
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
; ntc_plat_irqon - put the interrupt handler at #38 (IM 1: the stub set it) and
; start the line interrupt at raster line 0, the ULA's frame interrupt off
; (NextReg #22: bit 2 the ULA's off, bit 1 the line interrupt on, bit 0 the
; line's bit 8; #23 its bits 0-7). The handler moves it on 52 lines each time
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
			ld hl, 0
			ld (ntc_zxline), hl
			ld bc, #243B
			ld a, #23
			out (c), a
			inc b
			xor a
			out (c), a
			dec b
			ld a, #22
			out (c), a
			inc b
			ld a, 6
			out (c), a
			ld a, 1
			ld (ntc_irqset), a
			jp (ix)


;## ntc_plat_irqh ntc_plat_data ntc_data @shared
; the handler: runs on the real stack, between keywords. The line interrupt,
; every 52 raster lines - 6 a frame of 312 lines, 300 a second, as the CPC's:
; counts a tick and sets the next one (52 lines on; the one at line 0 is a
; frame's first: ntc_zxvs 1 for the interrupt classes' counting). AF goes to
; AF', HL to RAM, the other registers are kept.
ntc_irq:
			ex af, af'
			ld (ntc_irqhl), hl
			ld hl, (ntc_ticks)
			inc hl
			ld (ntc_ticks), hl
			push bc
			push de
			ld hl, (ntc_zxline)		; the line this one came at
			ld a, h
			or l
			ld a, 0
			jr nz, ntc_irq_nf
			inc a
ntc_irq_nf:
			ld (ntc_zxvs), a		; 1: line 0, a frame's first
			ld de, 52
			add hl, de
			ld de, -312
			add hl, de
			jr c, ntc_irq_wr		; past the last line (312 and on): line 0 again
			sbc hl, de				; (carry clear: back to the line)
ntc_irq_wr:
			ld (ntc_zxline), hl
			ld bc, #243B
			ld a, #23
			out (c), a
			inc b
			out (c), l
			dec b
			ld a, #22
			out (c), a
			inc b
			ld a, h
			or 6					; the ULA's interrupt off, the line interrupt on
			out (c), a
			dec b
			ld a, (ntc_zxsel)		; the NextReg the code it came in on had selected
			out (c), a
			pop de
			pop bc
			ld a, (ntc_hookon)	; an Interrupt hook: run it at the next safe point
			or a
			jr z, ntc_irq_nohook
			ld (ntc_hookpend), a
ntc_irq_nohook:
			ld hl, (ntc_irqv)		; interrupt classes (Option Class Interrupt): count them
			ld a, h
			or l
			jr z, ntc_irq_nocl
			push bc
			ld a, (ntc_zxvs)
			ld c, a					; C = 1: a frame's first (ntc_isl_tick reads it on zxn)
			call ntc_irq_jp			; (the handler runs on the real stack)
			pop bc
ntc_irq_nocl:
			ld hl, (ntc_irqhl)
			ex af, af'
			ei
			ret
ntc_irq_jp:
			jp (hl)

;## ntc_plat_exit ntc_plat_data
; ------------------------------------------------------------
; ntc_plat_exit - the end: interrupts off, a soft reset (NextReg 2 bit 0) -
; back to NextZXOS (a NEX file has no caller to return to)
; ------------------------------------------------------------
ntc_plat_exit:
			di
			ld bc, #243B
			ld a, #02
			out (c), a
			inc b
			ld a, 1
			out (c), a
ntc_ex_wait:
			jr ntc_ex_wait

;## ntc_plat_memtop
; ntc_plat_memtop - HL = the first byte the Memory class's Small heap must not
; use: #BE00 (the stack is above, to #C000). Called on the real stack
; (call / ret), only by the Memory class.
ntc_plat_memtop:
			ld hl, #BE00
			ret

;## ntc_gfx ntc_data ntc_plat_data @shared
; ------------------------------------------------------------
; ntc_gfx - the Graphics class on the Next (in place of the library's CPC one,
; with its labels): Layer 2 at 320 x 256, 256 colours, two buffers - banks
; 12-16 and 17-21 (5 x 16K each; column by column: a byte for each pixel at
; x * 256 + y). Lines XOR the pen (as on the CPC: drawing one again takes it
; off), in 320 x 200 (the CPC's mode 1), shown 28 rows down (centred in the
; 256). The page being drawn on goes in slot 6 (#C000-#DFFF). The text stays
; on the tilemap, over Layer 2, its paper see-through while Layer 2 is on.
; Called on the real stack (call / ret); uses IX, IY.
; ------------------------------------------------------------
ZXN_L2A			equ 12			; Layer 2's two buffers: their first 16K banks
ZXN_L2B			equ 17
ZXN_L2Y			equ 28			; the CPC's 200 rows, 28 rows down in Layer 2's 256
gfx_x0:			dw 0
gfx_y0:			dw 0
gfx_x1:			dw 0
gfx_y1:			dw 0
gfx_pen:		db 1
gfx_clip:		db 1			; 1: a line with an end off the screen isn't drawn; 0: no checks
gfx_base:		db ZXN_L2A		; the buffer drawn on (its first bank)
gfx_dbl:		db 0			; 1 = double buffering
gfx_shown:		db ZXN_L2A		; the buffer shown (NextReg #12)
gfx_sp:			dw 0			; the thread position while a Graphics method works
gfx_cpg:		db 0			; the page in slot 6
gfx_dx:			dw 0
gfx_dy:			dw 0

; gfx_begin / gfx_end - around drawing (the CPC: main RAM in the window): nothing here
gfx_begin:
gfx_end:
			ret

; gfx_width - HL = the width in pixels
gfx_width:
			ld hl, 320
			ret

; gfx_nr - NextReg A = E (through ntc_zxsel: interrupts may be in). Uses BC
gfx_nr:
			ld (ntc_zxsel), a
			ld bc, #243B
			out (c), a
			inc b
			out (c), e
			ret

; gfx_map - A = a page: into slot 6 (#C000-#DFFF). Keeps DE, HL, IX, IY
gfx_map:
			ld (gfx_cpg), a
			push de
			ld e, a
			ld a, #56
			call gfx_nr
			pop de
			ret

; gfx_on - Layer 2 on (once, after Mode): 320 x 256, buffer A shown and drawn on (cleared),
; its clip window the whole of it, the order sprites - ULA and tilemap - Layer 2, the ULA
; off, the tilemap's paper see-through
gfx_on:
			push hl
			push de
			ld hl, gfx_onregs
			ld d, 11
gfx_on1:
			ld a, (hl)
			inc hl
			ld e, (hl)
			inc hl
			call gfx_nr
			dec d
			jr nz, gfx_on1
			ld a, #18				; Layer 2's clip window: x 0-255 (in 320 x 256: doubled, 0-511),
			ld (ntc_zxsel), a		; y 0-255
			ld bc, #243B
			out (c), a
			inc b
			xor a
			out (c), a
			dec a
			out (c), a
			inc a
			out (c), a
			dec a
			out (c), a
			ld a, ZXN_L2A
			ld (gfx_base), a
			ld (gfx_shown), a
			call gfx_clear
			ld a, 1
			ld (ntc_zxl2), a
			pop de
			pop hl
			ret
gfx_onregs:		db #70, #10, #12, ZXN_L2A, #1C, 1, #15, 8, #68, #80, #4C, 0, #69, #80
			db #14, #E3, #43, #30, #40, 0, #41, #E3	; the tilemap's paper (index 0) the global transparent
								; colour: in text mode that is what makes it see-through, not #4C

; gfx_chk - HL >= DE (unsigned): carry (off the screen)
gfx_chk:
			or a
			sbc hl, de
			ccf
			ret

; gfx_line - (gfx_x0, gfx_y0) to (gfx_x1, gfx_y1), 320 x 200, XOR the pen
gfx_line:
			ld a, (ntc_zxl2)
			or a
			call z, gfx_on
			ld a, (gfx_clip)
			or a
			jr z, gfx_l_go
			ld de, 320
			ld hl, (gfx_x0)
			call gfx_chk
			ret c
			ld hl, (gfx_x1)
			call gfx_chk
			ret c
			ld de, 200
			ld hl, (gfx_y0)
			call gfx_chk
			ret c
			ld hl, (gfx_y1)
			call gfx_chk
			ret c
gfx_l_go:
			ld hl, (gfx_x1)			; left to right
			ld de, (gfx_x0)
			or a
			sbc hl, de
			jr nc, gfx_l_lr
			ld hl, (gfx_x0)
			ld de, (gfx_x1)
			ld (gfx_x0), de
			ld (gfx_x1), hl
			ld hl, (gfx_y0)
			ld de, (gfx_y1)
			ld (gfx_y0), de
			ld (gfx_y1), hl
			ld hl, (gfx_x1)
			ld de, (gfx_x0)
			or a
			sbc hl, de
gfx_l_lr:
			ld (gfx_dx), hl			; dx = x1 - x0 (0 - 319)
			ld a, #2C				; inc l: down
			ld hl, (gfx_y1)
			ld de, (gfx_y0)
			or a
			sbc hl, de
			jr nc, gfx_l_dy
			ex de, hl				; dy < 0: negated, up
			ld hl, 0
			or a
			sbc hl, de
			ld a, #2D				; dec l
gfx_l_dy:
			ld (gfx_dy), hl
			ld (gfx_xys), a			; the y step in both loops
			ld (gfx_yys), a
			ld a, (gfx_pen)
			ld (gfx_xpn + 1), a
			ld (gfx_ypn + 1), a
			ld hl, (gfx_x0)			; the first pixel's page: the buffer's + x / 32
			ld a, l
			and 31
			add a, #C0
			ld d, a					; D = #C0 + x mod 32 (the column in the page)
			srl h
			rr l
			srl h
			rr l
			srl h
			rr l
			srl h
			rr l
			srl h
			rr l
			ld a, (gfx_base)
			add a, a
			add a, l
			call gfx_map
			ld a, (gfx_y0)
			add a, ZXN_L2Y
			ld e, a
			ex de, hl				; HL = the pixel
			ld de, (gfx_dx)
			ld bc, (gfx_dy)
			ex de, hl
			or a
			sbc hl, bc				; dx - dy
			ex de, hl
			jr c, gfx_ymaj
			; x major: dx + 1 pixels; err = dx / 2, - dy each, + dx (and a y step) below 0
			ld a, (gfx_dy)
			ld (gfx_xdy + 1), a
			ld a, (gfx_dy + 1)
			ld (gfx_xdy2 + 1), a
			ld a, (gfx_dx)
			ld (gfx_xdx + 1), a
			ld a, (gfx_dx + 1)
			ld (gfx_xdx2 + 1), a
			ld bc, (gfx_dx)
			inc bc					; BC = the pixels
			ld de, (gfx_dx)
			srl d
			rr e					; DE = err
gfx_xl:
			ld a, (hl)
gfx_xpn:	xor 1
			ld (hl), a
			dec bc
			ld a, b
			or c
			ret z
			inc h					; x + 1
			ld a, h
			cp #E0
			call z, gfx_nxp
			ld a, e
gfx_xdy:	sub 0
			ld e, a
			ld a, d
gfx_xdy2:	sbc a, 0
			ld d, a
			jp p, gfx_xl
			ld a, e
gfx_xdx:	add a, 0
			ld e, a
			ld a, d
gfx_xdx2:	adc a, 0
			ld d, a
gfx_xys:	inc l					; (inc l / dec l)
			jr gfx_xl
gfx_ymaj:
			; y major: dy + 1 pixels; err = dy / 2, - dx each, + dy (and an x step) below 0
			ld a, (gfx_dx)
			ld (gfx_ydx + 1), a
			ld a, (gfx_dx + 1)
			ld (gfx_ydx2 + 1), a
			ld a, (gfx_dy)
			ld (gfx_ydy + 1), a
			ld a, (gfx_dy + 1)
			ld (gfx_ydy2 + 1), a
			ld bc, (gfx_dy)
			inc bc
			ld de, (gfx_dy)
			srl d
			rr e
gfx_yl:
			ld a, (hl)
gfx_ypn:	xor 1
			ld (hl), a
			dec bc
			ld a, b
			or c
			ret z
gfx_yys:	inc l					; (inc l / dec l)
			ld a, e
gfx_ydx:	sub 0
			ld e, a
			ld a, d
gfx_ydx2:	sbc a, 0
			ld d, a
			jp p, gfx_yl
			ld a, e
gfx_ydy:	add a, 0
			ld e, a
			ld a, d
gfx_ydy2:	adc a, 0
			ld d, a
			inc h					; x + 1
			ld a, h
			cp #E0
			call z, gfx_nxp
			jr gfx_yl
; past this page's 32 columns: the next page, column 0
gfx_nxp:
			ld h, #C0
			push bc
			ld a, (gfx_cpg)
			inc a
			call gfx_map
			pop bc
			ret

; gfx_clear (zxn_gclr: the name a program's #asm uses - IFDEF NTC_ZXN - so a CPC Library: ROM
; build, which sees every name, doesn't look for it) - the buffer drawn on cleared (its 10 pages,
; through slot 6). Interrupts kept out while SP runs through it (back on after when they were on)
zxn_gclr:
gfx_clear:
			ld a, i					; P/V = interrupts on
			push af
			di
			ld a, (gfx_base)
			add a, a
			ld d, 10
gfx_cl1:
			push af
			call gfx_map
			ld (gfx_dx), sp
			ld sp, #E000
			ld hl, 0
			ld b, 0					; 256 x 32 bytes = 8K
gfx_cl2:
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			push hl
			djnz gfx_cl2
			ld sp, (gfx_dx)
			pop af
			inc a
			dec d
			jr nz, gfx_cl1
			pop af
			ret po
			ei
			ret

; gfx_rline - HL = the raster line (#1E bit 8, #1F bits 0-7: read again until bit 8 holds)
gfx_rline:
			ld bc, #243B
			ld a, #1E
			ld (ntc_zxsel), a
			out (c), a
			inc b
			in h, (c)
			dec b
			ld a, #1F
			ld (ntc_zxsel), a
			out (c), a
			inc b
			in l, (c)
			dec b
			ld a, #1E
			ld (ntc_zxsel), a
			out (c), a
			inc b
			in a, (c)
			cp h
			jr nz, gfx_rline
			ld a, h
			and 1
			ld h, a
			ret

; gfx_flip - double buffering: wait for Layer 2's flyback (raster lines 224-279: below its
; 256 rows), show the buffer just drawn (NextReg #12), draw on the other one
gfx_flip:
			ld a, (gfx_dbl)
			or a
			ret z
gfx_fw:
			call gfx_rline
			ld de, 224
			or a
			sbc hl, de
			jr c, gfx_fw
			ld de, 280 - 224
			or a
			sbc hl, de
			jr nc, gfx_fw
			ld a, (gfx_base)
			ld (gfx_shown), a
			ld e, a
			ld a, #12
			call gfx_nr
			ld a, (gfx_shown)
			cp ZXN_L2A
			ld a, ZXN_L2B
			jr z, gfx_fl1
			ld a, ZXN_L2A
gfx_fl1:
			ld (gfx_base), a
			ret

; gfx_double - A = 1: double buffering on (the other buffer cleared, drawn on); 0: off -
; drawing on the buffer shown
gfx_double:
			ld (gfx_dbl), a
			ld a, (ntc_zxl2)
			or a
			call z, gfx_on
			ld a, (gfx_dbl)
			or a
			jr z, gfx_dboff
			ld a, (gfx_shown)
			cp ZXN_L2A
			ld a, ZXN_L2B
			jr z, gfx_db1
			ld a, ZXN_L2A
gfx_db1:
			ld (gfx_base), a
			jp gfx_clear
gfx_dboff:
			ld a, (gfx_shown)
			ld (gfx_base), a
			ret

; gfx_copyrows - the CPC copies its text rows to the other screen: here the text is on the
; tilemap, over both buffers - nothing to copy
gfx_copyrows:
			ret

;## ntc_zxwin ntc_plat_data @shared
; ------------------------------------------------------------
; zxn_sel - HL = a 16K bank (a data block: Option NexData's ntc_nexdata) into
; #4000-#7FFF (slots 2, 3), as the CPC's RAM pages go into its window; 0: the
; program's own pages back (bank 9: pages 18, 19). Nothing done when it is in
; already. Called on the real stack (call / ret); keeps BC, DE, HL
; ------------------------------------------------------------
zxn_sel:
			push bc
			push de
			ld a, l
			or a
			jr nz, zs_bank
			ld a, 9
zs_bank:
			ld e, a
			ld a, (zxn_selb)
			cp e
			jr z, zs_done
			ld a, e
			ld (zxn_selb), a
			add a, a
			ld e, a					; its first page: bank * 2
			ld bc, #243B
			ld a, #52
			ld (ntc_zxsel), a		; (interrupts may be in: the handler selects it again)
			out (c), a
			inc b
			out (c), e
			dec b
			inc e
			ld a, #53
			ld (ntc_zxsel), a
			out (c), a
			inc b
			out (c), e
zs_done:
			pop de
			pop bc
			ret
zxn_selb:		db 9			; the bank in the window

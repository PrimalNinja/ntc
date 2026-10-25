; ============================================================
; NTC Platform - MEGA65 (45GS02), direct hardware
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A PRG file loaded at $2001 (BASIC 65: RUN, or DLOAD and RUN): a BASIC line
; (BANK 0 : SYS start) and the program. The start code takes the machine
; over: the CPU at 40 MHz, no ROM mapped, I/O at $D000, the VIC-IV set up
; from scratch, interrupts off (the CPU's I flag set, the CIAs' and the
; VIC's interrupts off, RESTORE's NMI blocked), the stack pointer 16 bits.
;
; The thread is the stack pointer (SP, 16 bits: CLE). RTS fetches the next
; keyword: a thread word is the keyword's address - 1. An interrupt would
; push into the thread, so there are none; the frame counter ($D7FA) gives
; Frame and Ticks.
;
; Memory (bank 0, the CPU's 64K):
;   $0000-$00FF  base page: the library's registers ($02-$4F), the
;                platform's ($50-$6F), free for #asm ($70-$FF)
;   $0400-$07EF  the real stack (ntc_csp: the library's jsr calls)
;   $07F0-$07FF  console info: columns, rows, $A5 once the program has ended
;   $0800-$0FCF  the console's screen memory (80 x 25 characters, ASCII)
;   $1000-$1FFF  free
;   $2001-$CFFF  the program: the BASIC line, code, threads, variables, then
;                its arrays (cleared at start)
;   $D000-$DFFF  I/O (VIC-IV, SIDs, CIAs, DMA, maths)
;   $E000-$E7FF  the font (characters 0-255, 8 bytes each: NTC's 32-127)
;   $E800-$FFF9  free RAM ($FFFA-$FFFF: the NMI / reset / IRQ vectors)
; Colour RAM is $FF80000 (the console's colours, one byte a character).
; Banks 1-5 ($10000-$5FFFF) are free (NTC_M65LOG test builds: the console's
; text is kept from $10000, its length at $1FFFC).
;
; Keys: the hardware's ASCII queue ($D610). Inkey / Input: RETURN = 13,
; DEL = 8, ESC = 27, cursor up / down / left / right = &HF0 &HF1 &HF2 &HF3
; (as the CPC's), letters as typed (lower case unless shifted).
; ============================================================
;@name     MEGA65 (45GS02)
;@cpu      45gs02
;@org      $2001
;@text     byte
;@scrinit  0
;@irq      0
;@cols     80
;@rows     25
; ============================================================

;## ntc_m65_stub ntc_m65_boot
; the PRG's start (the compiler puts it first, at $2001): a BASIC line
; "10 BANK 0 : SYS 8209" then a jump to the start code
			dw ntc_m65_bnext, 10
			db $FE, $02, "0:", $9E, "8209", 0		; BANK 0 : SYS 8209
ntc_m65_bnext:
			dw 0
			jmp ntc_m65_boot				; 8209 = $2011

;## ntc_m65_boot ntc_plat_data ntc_data ntc_plat_screen ntc_m65_fontdata ntc_plat_exit
; ------------------------------------------------------------
; the start: the machine taken over, the screen, then ntc_start (the thread)
; ------------------------------------------------------------
ntc_m65_boot:
			sei
			cld
			lda #$47					; the VIC-IV's registers (I/O "knock")
			sta $D02F
			lda #$53
			sta $D02F
			lda #0						; no MAP: the CPU sees bank 0 (and $D000 I/O)
			tax
			tay
			taz
			map
			eom
			lda #0
			tab							; base page 0
			sta $D030					; no C65 ROM banked in
			lda #$35					; RAM at $A000 and $E000, I/O at $D000
			sta $01
			ldx #<$07EF					; the real stack, 16 bits
			txs
			ldy #>$07EF
			tys
			cle
			lda #0						; CIA 1's ports in (the joysticks)
			sta $DC02
			sta $DC03
			ldx #0						; keys still in the queue (the RETURN of RUN ...) dropped
ntc_m65_b_kq:
			lda $D610
			beq ntc_m65_b_kq1
			sta $D610
			dex
			bne ntc_m65_b_kq
ntc_m65_b_kq1:
			lda #$7F					; the CIAs' interrupts off
			sta $DC0D
			sta $DD0D
			lda $DC0D
			lda $DD0D
			lda #0						; the VIC's off
			sta $D01A
			lda #$FF
			sta $D019
			lda #<ntc_m65_nmi			; vectors (RAM: no KERNAL mapped)
			sta $FFFA
			lda #>ntc_m65_nmi
			sta $FFFB
			lda #<ntc_m65_boot
			sta $FFFC
			lda #>ntc_m65_boot
			sta $FFFD
			lda #<ntc_m65_brk
			sta $FFFE
			lda #>ntc_m65_brk
			sta $FFFF
			; RESTORE: one NMI from CIA 2's timer A that is never acknowledged holds
			; the NMI line low, so no further NMI (RESTORE's included) gets in
			lda #0
			sta $DD0E
			lda #8
			sta $DD04
			lda #0
			sta $DD05
			lda #$81
			sta $DD0D
			lda #$19					; one shot, load, start
			sta $DD0E
			ldx #0
ntc_m65_nwt:
			dex
			bne ntc_m65_nwt
			lda #$40					; 40 MHz: FAST ($D031) and VFAST ($D054)
			tsb $D054
			lda #0
			sta ntc_m65_lfc
			sta ntc_ticks
			sta ntc_ticks+1
			sta $07F2					; not ended
			sta $D020					; black border
			sta $D021
			sta ntc_m65_brkpc
			sta ntc_m65_brkpc+1
			lda $D7FA
			sta ntc_m65_lfc
			; the font: font8x8 (characters 32-127) at $E000, the rest blank (the VIC
			; shows its character ROM for a font at $1000 / $1800 / $9000 / $9800)
			ldx #0
			txa
ntc_m65_fcl:
			sta $E000,x
			sta $E100,x
			sta $E200,x
			sta $E300,x
			sta $E400,x
			sta $E500,x
			sta $E600,x
			sta $E700,x
			inx
			bne ntc_m65_fcl
			ldx #0
ntc_m65_fcp:
			lda ntc_m65_fontdata,x
			sta $E100,x
			lda ntc_m65_fontdata+256,x
			sta $E200,x
			lda ntc_m65_fontdata+512,x
			sta $E300,x
			inx
			bne ntc_m65_fcp
			; NTC_M65LOG test builds: the log's length
			ifd NTC_M65LOG
			lda #0
			sta ntc_m65_logn
			sta ntc_m65_logn+1
			jsr ntc_m65_logend
			endif
			lda #2						; 80 columns
			jsr ntc_plat_mode
			jmp ntc_start

; NMI (from CIA 2, once): not acknowledged, so the line stays low
ntc_m65_nmi:
			rti

; BRK (an IRQ never comes: the I flag is set): stop with a message
ntc_m65_brk:
			sei
			tsx
			stx ntc_m65_brkpc
			tsy
			sty ntc_m65_brkpc+1
			ldx #<$07EF
			txs
			ldy #>$07EF
			tys
			ldx #0
ntc_m65_bkl:
			lda ntc_m65_bktx,x
			beq ntc_m65_bkd
			stx ntc_m65_bkx
			jsr ntc_plat_putc
			ldx ntc_m65_bkx
			inx
			bne ntc_m65_bkl
ntc_m65_bkd:
			jsr ntc_plat_newline
			jmp ntc_plat_exit_stop
ntc_m65_bktx:	db "BRK - the program stopped", 0

;## ntc_plat_data
VIC_SCRA	equ $0800		; graphics: the screen memory showing buffer A (and the console's)
VIC_SCRB	equ $1000		; showing buffer B
VIC_TXT		equ $1800		; graphics: the text layer's characters (40 x 25)
VIC_TCOL	equ $1C00		; its colours
VIC_DIRTY	equ $E800		; its cells to draw again: bit 0 into buffer A, bit 1 into B
ntc_vic_on:		db 0			; $80 = the graphics screen is on (Print goes to its text layer)
ntc_vic_pen:	db 1			; graphics: the text's colour (palette index)
ntc_curx:		db 0			; the cursor (0 based)
ntc_cury:		db 0
ntc_scols:		db 80			; the screen's size
ntc_srows:		db 25
ntc_ticks:		dw 0			; frames since the start (the frame counter, followed)
ntc_m65_lfc:	db 0			; $D7FA last time it was looked at
ntc_m65_brkpc:	dw 0			; BRK: the stack pointer then
ntc_m65_bkx:	db 0
ntc_m65_colour:	db 1			; the console's colour (white)
ntc_m65_logn:	dw 0			; NTC_M65LOG: the log's length

;## ntc_plat_screen ntc_plat_data ntc_data ntc_m65_far
; ------------------------------------------------------------
; the console: screen memory $0800 (ASCII), colours in colour RAM. JSR on
; the real stack; A, X, Y and the platform's base page ($50-$6F) are used.
; ------------------------------------------------------------
; ntc_plat_putc - A = character (32-126; others are shown as they are)
ntc_plat_putc:
			sta ntc_m65_ch
			ifd NTC_M65LOG
			jsr ntc_m65_log
			endif
			bit ntc_vic_on
			bpl ntc_m65_pc_txt
			jsr ntc_m65_txtcell			; graphics: into the text layer
			ldy #0
			lda ntc_m65_ch
			sta ($50),y
			lda ntc_vic_pen
			sta ($52),y
			lda #3
			sta ($54),y
			jmp ntc_m65_pc_adv
ntc_m65_pc_txt:
			jsr ntc_m65_rowaddr			; $50 = the row's address
			ldy ntc_curx
			lda ntc_m65_ch
			sta ($50),y
ntc_m65_pc_adv:
			inc ntc_curx
			lda ntc_curx
			cmp ntc_scols
			bcc ntc_m65_pc_e
			lda #0						; past the end: the next line
			sta ntc_curx
			jmp ntc_m65_down
ntc_m65_pc_e:
			rts

; ntc_plat_newline
ntc_plat_newline:
			ifd NTC_M65LOG
			lda #10
			jsr ntc_m65_log
			endif
			lda #0
			sta ntc_curx
; the cursor down a line, the screen up at the bottom
ntc_m65_down:
			lda ntc_cury
			clc
			adc #1
			cmp ntc_srows
			bcs ntc_m65_dn_end
			sta ntc_cury
			rts
ntc_m65_dn_end:
			bit ntc_vic_on				; graphics: no scrolling (the last row again)
			bpl ntc_m65_scroll
			rts
ntc_m65_scroll:
			; rows 1 .. n-1 up a row (screen memory, then a blank last row)
			lda #<$0800
			sta $50
			lda #>$0800
			sta $51
			lda ntc_scols
			clc
			adc #<$0800
			sta $52
			lda #>$0800
			adc #0
			sta $53
			ldx ntc_srows
			dex
ntc_m65_scr_r:
			ldy #0
ntc_m65_scr_c:
			lda ($52),y
			sta ($50),y
			iny
			cpy ntc_scols
			bne ntc_m65_scr_c
			lda $52
			sta $50
			lda $53
			sta $51
			lda $52
			clc
			adc ntc_scols
			sta $52
			bcc ntc_m65_scr_n
			inc $53
ntc_m65_scr_n:
			dex
			bne ntc_m65_scr_r
			ldy #0
			lda #' '
ntc_m65_scr_b:
			sta ($50),y
			iny
			cpy ntc_scols
			bne ntc_m65_scr_b
			rts

; $50/$51 = the address of the cursor's row in screen memory
ntc_m65_rowaddr:
			lda #<$0800
			sta $50
			lda #>$0800
			sta $51
			ldx ntc_cury
			beq ntc_m65_ra_e
ntc_m65_ra_l:
			lda $50
			clc
			adc ntc_scols
			sta $50
			bcc ntc_m65_ra_n
			inc $51
ntc_m65_ra_n:
			dex
			bne ntc_m65_ra_l
ntc_m65_ra_e:
			rts

; $50 = the text layer's cell at the cursor, $52 its colour, $54 its dirty flags
ntc_m65_txtcell:
			lda ntc_cury				; * 40 = * 32 + * 8
			sta $50
			lda #0
			sta $51
			asl $50
			rol $51
			asl $50
			rol $51
			asl $50
			rol $51
			lda $50
			sta $52
			lda $51
			sta $53						; * 8
			asl $50
			rol $51
			asl $50
			rol $51						; * 32
			clc
			lda $50
			adc $52
			sta $50
			lda $51
			adc $53
			sta $51
			clc
			lda $50
			adc ntc_curx
			sta $50
			sta $52
			sta $54
			lda $51
			adc #0
			sta $51						; the cell's number (the three tables are page aligned)
			clc
			adc #>VIC_TCOL
			sta $53
			lda $51
			clc
			adc #>VIC_DIRTY
			sta $55
			lda $51
			clc
			adc #>VIC_TXT
			sta $51
			rts

; ntc_plat_backspace - back a character and blank it
ntc_plat_backspace:
			lda ntc_curx
			beq ntc_m65_bs_up
			dec ntc_curx
			jmp ntc_m65_bs_blank
ntc_m65_bs_up:
			lda ntc_cury
			beq ntc_m65_bs_e
			dec ntc_cury
			ldx ntc_scols
			dex
			stx ntc_curx
ntc_m65_bs_blank:
			bit ntc_vic_on
			bpl ntc_m65_bs_t
			jsr ntc_m65_txtcell
			ldy #0
			lda #' '
			sta ($50),y
			lda #3
			sta ($54),y
			rts
ntc_m65_bs_t:
			jsr ntc_m65_rowaddr
			ldy ntc_curx
			lda #' '
			sta ($50),y
ntc_m65_bs_e:
			rts

; ntc_plat_cls - blank screen, colours set, cursor home
ntc_plat_cls:
			bit ntc_vic_on
			bpl ntc_m65_cls_t
			ldx #0						; graphics: the text layer blank (a cell that had a
ntc_m65_cls_g:							; character is drawn again: as a space)
			lda VIC_TXT,x
			cmp #' '
			beq ntc_m65_cls_g1
			lda #3
			sta VIC_DIRTY,x
			lda #' '
			sta VIC_TXT,x
ntc_m65_cls_g1:
			lda VIC_TXT+$100,x
			cmp #' '
			beq ntc_m65_cls_g2
			lda #3
			sta VIC_DIRTY+$100,x
			lda #' '
			sta VIC_TXT+$100,x
ntc_m65_cls_g2:
			lda VIC_TXT+$200,x
			cmp #' '
			beq ntc_m65_cls_g3
			lda #3
			sta VIC_DIRTY+$200,x
			lda #' '
			sta VIC_TXT+$200,x
ntc_m65_cls_g3:
			lda VIC_TXT+$300,x
			cmp #' '
			beq ntc_m65_cls_g4
			lda #3
			sta VIC_DIRTY+$300,x
			lda #' '
			sta VIC_TXT+$300,x
ntc_m65_cls_g4:
			inx
			bne ntc_m65_cls_g
			lda #0
			sta ntc_curx
			sta ntc_cury
			rts
ntc_m65_cls_t:
			lda #<$0800
			sta $50
			lda #>$0800
			sta $51
			ldx #8						; 8 x 256 = 2048 bytes (80 x 25 = 2000)
			ldy #0
			lda #' '
ntc_m65_cls_l:
			sta ($50),y
			iny
			bne ntc_m65_cls_l
			inc $51
			dex
			bne ntc_m65_cls_l
			; colour RAM ($FF80000): 2000 bytes of the console's colour
			lda #$00
			sta $54
			lda #$00
			sta $55
			lda #$F8
			sta $56
			lda #$0F
			sta $57
			ldx #8
			ldz #0
			lda ntc_m65_colour
ntc_m65_cls_c:
			sta [$54],z
			inz
			bne ntc_m65_cls_c
			inc $55
			dex
			bne ntc_m65_cls_c
			ldz #0
			lda #0
			sta ntc_curx
			sta ntc_cury
			rts

; ntc_plat_mode - A = mode: 2 = 80 columns, else 40; clears the screen
ntc_plat_mode:
			ldx #0						; (the graphics screen off: Mode is the console's)
			stx ntc_vic_on
			ldx #80
			cmp #2
			beq ntc_m65_md80
			ldx #40
ntc_m65_md80:
			stx ntc_scols
			stx $07F0
			lda #25
			sta ntc_srows
			sta $07F1
			lda #$47					; (in case a program changed the I/O mode)
			sta $D02F
			lda #$53
			sta $D02F
			lda #$80					; PAL (50 frames a second)
			trb $D06F
			lda #$80					; hot registers on while the legacy ones are set
			tsb $D05D
			lda #$1B					; text, display on, 25 rows
			sta $D011
			lda #$C8					; 40 / 80 columns (80: scroll 1 - the VIC-III puts 80
			cpx #80						; column text 2 pixels left of the border)
			bne ntc_m65_md16
			lda #$C9
ntc_m65_md16:
			sta $D016
			lda #$14
			sta $D018
			lda #$40					; FAST, 80 columns when asked
			cpx #80
			bne ntc_m65_md40
			ora #$80
ntc_m65_md40:
			sta $D031
			lda #$40					; VFAST, 8 bit characters (CHR16 / FCLR off)
			sta $D054
			lda #$80					; hot registers off: the precise pointers stay
			trb $D05D
			lda #<$0800					; screen memory
			sta $D060
			lda #>$0800
			sta $D061
			lda #0
			sta $D062
			lda $D063
			and #$F0
			sta $D063
			lda #<$E000					; the font
			sta $D068
			lda #>$E000
			sta $D069
			lda #0
			sta $D06A
			lda #0						; colours from the start of colour RAM
			sta $D064
			sta $D065
			jmp ntc_plat_cls

; ntc_plat_locate - X = column, Y = row (1 based; off the screen: not moved)
ntc_plat_locate:
			dex
			cpx ntc_scols
			bcs ntc_m65_loc_e
			dey
			cpy ntc_srows
			bcs ntc_m65_loc_e
			stx ntc_curx
			sty ntc_cury
ntc_m65_loc_e:
			rts

			ifd NTC_M65LOG
; the log (test builds): A appended at $10000 + its length (bank 1), the length at $1FFFC
ntc_m65_log:
			pha
			lda ntc_m65_logn
			sta $58
			lda ntc_m65_logn+1
			sta $59
			lda #1
			sta $5A
			lda #0
			sta $5B
			pla
			ldz #0
			sta [$58],z
			inc ntc_m65_logn
			bne ntc_m65_logend
			inc ntc_m65_logn+1
ntc_m65_logend:
			lda #<$FFFC
			sta $58
			lda #>$FFFC
			sta $59
			lda #1
			sta $5A
			lda #0
			sta $5B
			ldz #0
			lda ntc_m65_logn
			sta [$58],z
			inz
			lda ntc_m65_logn+1
			sta [$58],z
			inz
			lda #0
			sta [$58],z
			ldz #0
			rts
			endif

;## ntc_m65_far
; (the 32 bit pointers in the base page: $54-$57 colour RAM, $58-$5B the log)
ntc_m65_ch:		db 0

;## ntc_plat_key ntc_plat_data ntc_plat_ticks
; ------------------------------------------------------------
; the keyboard: the hardware's ASCII queue ($D610)
; ------------------------------------------------------------
; ntc_plat_scankey - A = a key typed (taken from the queue) or 0, no wait
ntc_plat_scankey:
			jsr ntc_plat_ticks			; (keeps Ticks going in a key loop)
			lda $D610
			beq ntc_m65_sk_e
			sta $D610					; (any write takes it off the queue)
			cmp #20						; DEL
			bne ntc_m65_sk1
			lda #8
			rts
ntc_m65_sk1:
			cmp #145					; cursor up
			bne ntc_m65_sk2
			lda #$F0
			rts
ntc_m65_sk2:
			cmp #17						; down
			bne ntc_m65_sk3
			lda #$F1
			rts
ntc_m65_sk3:
			cmp #157					; left
			bne ntc_m65_sk4
			lda #$F2
			rts
ntc_m65_sk4:
			cmp #29						; right
			bne ntc_m65_sk_e
			lda #$F3
ntc_m65_sk_e:
			rts

; ntc_plat_getkey - A = the next key (waits)
ntc_plat_getkey:
			jsr ntc_plat_scankey
			cmp #0
			beq ntc_plat_getkey
			rts

;## ntc_plat_ticks ntc_plat_data
; ntc_plat_ticks - the frame counter followed into ntc_ticks: A = low, X = high
ntc_plat_ticks:
			lda $D7FA
			tax
			sec
			sbc ntc_m65_lfc
			stx ntc_m65_lfc
			clc
			adc ntc_ticks
			sta ntc_ticks
			bcc ntc_m65_tk_e
			inc ntc_ticks+1
ntc_m65_tk_e:
			lda ntc_ticks
			ldx ntc_ticks+1
			rts

;## ntc_plat_frame ntc_plat_ticks
; ntc_plat_frame - wait for the next frame (the frame counter moving on)
ntc_plat_frame:
			jsr ntc_plat_ticks
			lda $D7FA
ntc_m65_fr_w:
			cmp $D7FA
			beq ntc_m65_fr_w
			jmp ntc_plat_ticks

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - End: the console stays, the end marked for the test tools
ntc_plat_exit:
			lda #$A5
			sta $07F2
			rts
ntc_plat_exit_stop:
			jsr ntc_plat_exit
ntc_m65_halt:
			jmp ntc_m65_halt

;## ntc_vic ntc_plat_data ntc_plat_screen ntc_plat_frame ntc_m65_far
; ------------------------------------------------------------
; The graphics screen (the Vic class): 320 x 200, 256 colours, two buffers.
; Each buffer is 1000 full colour characters (64 bytes each, a pixel a byte):
; buffer A at $40000 (characters $1000-$13E7, shown by screen memory $0800),
; buffer B at $50000 ($1400-$17E7, screen memory $1000). Character (column c,
; row r) is c * 25 + r, so a column of 8 pixels runs down the screen without a
; break: pixel (x, y) is at (x >> 3) * 1600 + y * 8 + (x & 7).
; Vic.Update draws the next picture into the buffer not shown - the playfield
; (columns 0 .. ntc_vic_fw - 1) cleared, the stars, the sprites (79 first, so
; sprite 0 is in front), the text layer - then waits for the frame and shows it.
; The panel (columns ntc_vic_fw .. 39) is not cleared: its text is drawn when it
; changes (into each buffer once), opaque, and Vic.Stamp / Vic.Box draw into both.
; Images: w, h (pixels, h even, 32 at most), then w columns of h / 2 bytes: two
; pixels a byte (the low nibble the upper), 0 = clear, 1-15 = colour + the
; sprite's palette * 16 + 16.
; Sprites (8 bytes each): x (16 bits, signed), y, image, attributes (bit 0 flip
; x, bit 1 flip y, bits 4-5 the palette), shown (0 / 1), 0.
; Uses $50-$6F (the platform's base page).
; ------------------------------------------------------------
VIC_NSPR	equ 80
ntc_vic_fw:		db 32			; the playfield's width in columns (8 pixels)
ntc_vic_fpx:	dw 256			; ... in pixels
ntc_vic_back:	db 1			; the buffer being drawn: 0 A, 1 B
ntc_vic_bg:		db 0			; the playfield's colour
ntc_vic_paper:	db 0			; the panel text's background
ntc_vic_imgs:	dw 0			; the image table: an address for each image
ntc_vic_starn:	db 0			; stars
ntc_vic_spn:	db 0			; (the sprite loop's count)
ntc_vic_noflip:	db 0			; 1: Vic.Draw (drawn into the back buffer, not shown)
ntc_vic_stary:	db 0			; their scroll (added to each star's y)
ntc_vic_sat:	ds VIC_NSPR*8
ntc_vic_sx:		ds 64			; the stars: x, y, colour
ntc_vic_sy:		ds 64
ntc_vic_sc:		ds 64
; the columns' offsets: c * 1600
ntc_vic_cbl:	db <0, <1600, <3200, <4800, <6400, <8000, <9600, <11200, <12800, <14400
				db <16000, <17600, <19200, <20800, <22400, <24000, <25600, <27200, <28800, <30400
				db <32000, <33600, <35200, <36800, <38400, <40000, <41600, <43200, <44800, <46400
				db <48000, <49600, <51200, <52800, <54400, <56000, <57600, <59200, <60800, <62400, <64000
ntc_vic_cbh:	db >0, >1600, >3200, >4800, >6400, >8000, >9600, >11200, >12800, >14400
				db >16000, >17600, >19200, >20800, >22400, >24000, >25600, >27200, >28800, >30400
				db >32000, >33600, >35200, >36800, >38400, >40000, >41600, >43200, >44800, >46400
				db >48000, >49600, >51200, >52800, >54400, >56000, >57600, >59200, >60800, >62400, >64000
; a DMA fill job (F018B, enhanced): count, the byte, the destination
ntc_vic_dmal:
			db $0B						; F018B
			db $81, $00					; destination MB 0
			db $00						; end of options
			db $03						; fill
ntc_vic_dmac:	dw 0				; count
ntc_vic_dmav:	db 0, 0				; the byte (the source's low byte)
			db 0						; source bank
ntc_vic_dmad:	dw 0				; destination
ntc_vic_dmab:	db 4				; destination bank
			db 0						; command (high)
			dw 0						; modulo

; ntc_vic_fill - DMA fill: $5C/$5D = the start (in the bank), $5E/$5F = bytes, A = the
; byte, X = the bank
ntc_vic_fill:
			sta ntc_vic_dmav
			stx ntc_vic_dmab
			lda $5C
			sta ntc_vic_dmad
			lda $5D
			sta ntc_vic_dmad+1
			lda $5E
			sta ntc_vic_dmac
			lda $5F
			sta ntc_vic_dmac+1
			ora $5E
			beq ntc_vic_fl_e
			lda #0
			sta $D702					; the job's bank and MB
			sta $D704
			lda #>ntc_vic_dmal
			sta $D701
			lda #<ntc_vic_dmal
			sta $D705					; go (enhanced)
ntc_vic_fl_e:
			rts

; ntc_vic_screen - A = 1: the graphics screen on (both buffers cleared, the text layer
; blank), 0: off (the console, 80 columns)
ntc_vic_screen:
			cmp #0
			bne ntc_vic_son
			lda #2
			jmp ntc_plat_mode
ntc_vic_son:
			lda #$47
			sta $D02F
			lda #$53
			sta $D02F
			; the screen memories: cell (c, r) at (r * 40 + c) * 2 = $1000 / $1400 + c * 25 + r
			lda #<VIC_SCRA
			sta $50
			lda #>VIC_SCRA
			sta $51
			lda #<VIC_SCRB
			sta $52
			lda #>VIC_SCRB
			sta $53
			lda #0
			sta $56						; row
ntc_vic_sm_r:
			lda $56						; the row's first character: $1000 + r
			sta $58
			lda #$10
			sta $59
			ldx #40
			ldy #0
ntc_vic_sm_c:
			lda $58
			sta ($50),y
			sta ($52),y
			iny
			lda $59
			sta ($50),y
			clc
			adc #4						; buffer B: + $400
			sta ($52),y
			iny
			clc
			lda $58
			adc #25
			sta $58
			bcc ntc_vic_sm_n
			inc $59
ntc_vic_sm_n:
			dex
			bne ntc_vic_sm_c
			clc							; the next row: + 80 bytes
			lda $50
			adc #80
			sta $50
			bcc ntc_vic_sm_1
			inc $51
ntc_vic_sm_1:
			clc
			lda $52
			adc #80
			sta $52
			bcc ntc_vic_sm_2
			inc $53
ntc_vic_sm_2:
			inc $56
			lda $56
			cmp #25
			bne ntc_vic_sm_r
			; colour RAM: 2000 bytes of 0
			lda #$00
			sta $54
			sta $55
			lda #$F8
			sta $56
			lda #$0F
			sta $57
			ldx #8
			ldz #0
			lda #0
ntc_vic_cr:
			sta [$54],z
			inz
			bne ntc_vic_cr
			inc $55
			dex
			bne ntc_vic_cr
			ldz #0
			; both buffers cleared
			lda #0
			sta $5C
			sta $5D
			lda #<64000
			sta $5E
			lda #>64000
			sta $5F
			lda ntc_vic_bg
			ldx #4
			jsr ntc_vic_fill
			lda ntc_vic_bg
			ldx #5
			jsr ntc_vic_fill
			; no sprites, no stars, the text layer blank
			ldx #0
			txa
ntc_vic_sc0:
			sta ntc_vic_sat,x
			sta ntc_vic_sat+$100,x
			inx
			bne ntc_vic_sc0
ntc_vic_sc1:
			sta ntc_vic_sat+$200,x
			inx
			cpx #<(VIC_NSPR*8-$200)
			bne ntc_vic_sc1
			sta ntc_vic_starn
			lda #$80
			sta ntc_vic_on
			lda #40
			sta ntc_scols
			sta $07F0
			lda #25
			sta ntc_srows
			sta $07F1
			ldx #0						; the text layer: spaces, nothing to draw
ntc_vic_tl:
			lda #' '
			sta VIC_TXT,x
			sta VIC_TXT+$100,x
			sta VIC_TXT+$200,x
			sta VIC_TXT+$300,x
			lda #0
			sta VIC_DIRTY,x
			sta VIC_DIRTY+$100,x
			sta VIC_DIRTY+$200,x
			sta VIC_DIRTY+$300,x
			inx
			bne ntc_vic_tl
			stx ntc_curx
			stx ntc_cury
			; the VIC-IV: 40 columns, 16 bit characters, full colour above 255
			lda #$80					; PAL
			trb $D06F
			lda #$80
			tsb $D05D
			lda #$1B
			sta $D011
			lda #$C8
			sta $D016
			lda #$14
			sta $D018
			lda #$40					; FAST, 40 columns
			sta $D031
			lda #$45					; VFAST, CHR16, FCLRHI
			sta $D054
			lda #$80
			trb $D05D
			lda #80						; 80 bytes a row (40 x 2)
			sta $D058
			lda #0
			sta $D059
			lda #40
			sta $D05E
			lda #<VIC_SCRA				; showing A, drawing B
			sta $D060
			lda #>VIC_SCRA
			sta $D061
			lda #0
			sta $D062
			lda $D063
			and #$C0
			sta $D063
			lda #0
			sta $D064
			sta $D065
			lda #1
			sta ntc_vic_back
			rts

; ntc_vic_color - X = the colour (0-255), $5E/$5F = &HRGB (4 bits each)
ntc_vic_color:
			lda $5F						; red: 0R -> RR (the register: the nybbles swapped,
			and #$0F					; the same for RR)
			sta $5D
			asl
			asl
			asl
			asl
			ora $5D
			sta $D100,x
			lda $5E						; green: G0
			and #$F0
			sta $5D
			lsr
			lsr
			lsr
			lsr
			ora $5D
			sta $D200,x
			lda $5E						; blue: 0B
			and #$0F
			sta $5D
			asl
			asl
			asl
			asl
			ora $5D
			sta $D300,x
			rts

; ntc_vic_update - the next picture into the buffer not shown, then shown at the frame
ntc_vic_update:
			lda ntc_vic_back
			clc
			adc #4
			sta $6C						; the bank being drawn
			sta $52
			lda #0
			sta $53
			; the playfield cleared
			sta $5C
			sta $5D
			ldx ntc_vic_fw
			lda ntc_vic_cbl,x
			sta $5E
			lda ntc_vic_cbh,x
			sta $5F
			lda ntc_vic_bg
			ldx $6C
			jsr ntc_vic_fill
			jsr ntc_vic_stars
			jsr ntc_vic_sprites
			jsr ntc_vic_text
			lda ntc_vic_noflip
			beq ntc_vic_u_show
			rts							; (Vic.Draw: drawn, not shown)
ntc_vic_u_show:
			; shown at the next frame
			jsr ntc_plat_frame
			lda ntc_vic_back
			bne ntc_vic_u_b
			lda #<VIC_SCRA
			sta $D060
			lda #>VIC_SCRA
			sta $D061
			lda #1
			sta ntc_vic_back
			rts
ntc_vic_u_b:
			lda #<VIC_SCRB
			sta $D060
			lda #>VIC_SCRB
			sta $D061
			lda #0
			sta ntc_vic_back
			rts

; the stars: pixels at (x, y + scroll) within the playfield
ntc_vic_stars:
			ldx ntc_vic_starn
			beq ntc_vic_st_e
			dex
ntc_vic_st_l:
			lda ntc_vic_sy,x
			clc
			adc ntc_vic_stary
			cmp #200
			bcs ntc_vic_st_n
			sta $50						; y * 8
			lda #0
			sta $51
			asl $50
			rol $51
			asl $50
			rol $51
			asl $50
			rol $51
			lda ntc_vic_sx,x
			sta $5C
			lda ntc_vic_fpx+1			; x < the playfield's width
			bne ntc_vic_st_ok
			lda $5C
			cmp ntc_vic_fpx
			bcs ntc_vic_st_n
ntc_vic_st_ok:
			lda $5C
			and #7
			clc
			adc $50
			sta $50
			bcc ntc_vic_st_1
			inc $51
ntc_vic_st_1:
			lda $5C
			lsr
			lsr
			lsr
			tay
			clc
			lda $50
			adc ntc_vic_cbl,y
			sta $50
			lda $51
			adc ntc_vic_cbh,y
			sta $51
			ldz #0
			lda ntc_vic_sc,x
			sta [$50],z
ntc_vic_st_n:
			dex
			bpl ntc_vic_st_l
ntc_vic_st_e:
			rts

; the sprites, 79 down to 0
ntc_vic_sprites:
			lda #<(ntc_vic_sat+(VIC_NSPR-1)*8)
			sta $6A
			lda #>(ntc_vic_sat+(VIC_NSPR-1)*8)
			sta $6B
			lda #VIC_NSPR
			sta ntc_vic_spn
ntc_vic_sp_l:
			ldy #6
			lda ($6A),y
			beq ntc_vic_sp_n
			ldy #0
			lda ($6A),y
			sta $62
			iny
			lda ($6A),y
			sta $63
			iny
			lda ($6A),y
			sta $64
			iny
			lda ($6A),y
			sta $65
			iny
			lda ($6A),y					; the image
			asl
			tax
			iny
			lda ($6A),y					; attributes
			sta $69
			and #$30
			clc
			adc #16
			sta $68						; the colour added to each pixel
			txa							; the image's address from the table
			clc
			adc ntc_vic_imgs
			sta $5E
			lda ntc_vic_imgs+1
			adc #0
			sta $5F
			ldy #0
			lda ($5E),y
			sta $60
			iny
			lda ($5E),y
			sta $61
			jsr ntc_vic_draw
ntc_vic_sp_n:
			sec
			lda $6A
			sbc #8
			sta $6A
			bcs ntc_vic_sp_1
			dec $6B
ntc_vic_sp_1:
			dec ntc_vic_spn
			bne ntc_vic_sp_l
			rts

; ntc_vic_draw - the image at $60 to $62 (x), $64 (y): $68 = colour added, $69 = flips,
; $6C = the bank. Clipped to the playfield (x) and the screen (y)
ntc_vic_draw:
			ldy #0
			lda ($60),y
			sta $66						; w
			iny
			lda ($60),y
			sta $67						; h
			lsr
			sta $6E						; bytes a column
			clc							; the pixels
			lda $60
			adc #2
			sta $5C
			lda $61
			adc #0
			sta $5D
			; off the screen? y >= 200 or y + h <= 0, x >= field or x + w <= 0
			lda $65
			bmi ntc_vic_dr_yneg
			bne ntc_vic_dr_e
			lda $64
			cmp #200
			bcs ntc_vic_dr_e
			clc
			adc $67
			bcs ntc_vic_dr_y0			; past 255: past the bottom
			cmp #201
			lda #0
			bcc ntc_vic_dr_y1
ntc_vic_dr_y0:
			lda #1						; reaches past the bottom: clip
ntc_vic_dr_y1:
			sta $6F
			jmp ntc_vic_dr_x
ntc_vic_dr_yneg:
			clc
			lda $64
			adc $67
			tax
			lda $65
			adc #0
			bmi ntc_vic_dr_e
			bne ntc_vic_dr_yc
			cpx #0
			beq ntc_vic_dr_e
ntc_vic_dr_yc:
			lda #1
			sta $6F
ntc_vic_dr_x:
			lda $63						; x >= field (x signed)
			bmi ntc_vic_dr_xneg
			cmp ntc_vic_fpx+1
			bcc ntc_vic_dr_cols
			bne ntc_vic_dr_e
			lda $62
			cmp ntc_vic_fpx
			bcs ntc_vic_dr_e
			jmp ntc_vic_dr_cols
ntc_vic_dr_xneg:
			clc							; x + w <= 0
			lda $62
			adc $66
			lda $63
			adc #0
			bmi ntc_vic_dr_e
ntc_vic_dr_cols:
			; all of it on the screen (no clipping): the fast way
			lda $6F
			bne ntc_vic_dr_slow
			lda $63
			bmi ntc_vic_dr_slow
			clc							; x + w <= field
			lda $62
			adc $66
			tax
			lda $63
			adc #0
			cmp ntc_vic_fpx+1
			bcc ntc_vic_fast
			bne ntc_vic_dr_slow
			cpx ntc_vic_fpx
			bcc ntc_vic_fast
			beq ntc_vic_fast
ntc_vic_dr_slow:
			lda #0
			sta $6D						; the column (counts up)
ntc_vic_dr_c:
			; sx = x + c (flip x: x + w - 1 - c)
			lda $69
			and #1
			bne ntc_vic_dr_fx
			clc
			lda $62
			adc $6D
			sta $56
			lda $63
			adc #0
			sta $57
			jmp ntc_vic_dr_sx
ntc_vic_dr_fx:
			lda $66
			sec
			sbc #1
			sec
			sbc $6D
			clc
			adc $62
			sta $56
			lda $63
			adc #0
			sta $57
ntc_vic_dr_sx:
			lda $57						; 0 <= sx < field (16 bits)
			bmi ntc_vic_dr_cn
			cmp ntc_vic_fpx+1
			bcc ntc_vic_dr_in
			bne ntc_vic_dr_cn
			lda $56
			cmp ntc_vic_fpx
			bcs ntc_vic_dr_cn
ntc_vic_dr_in:
			jsr ntc_vic_col
ntc_vic_dr_cn:
			clc							; the next column's pixels
			lda $5C
			adc $6E
			sta $5C
			bcc ntc_vic_dr_c2
			inc $5D
ntc_vic_dr_c2:
			inc $6D
			lda $6D
			cmp $66
			bne ntc_vic_dr_c
ntc_vic_dr_e:
			rts

; ---- the fast way: the whole image on the screen. The first column's address, then
; a column at a time (+1 in a character, +1593 to the next: 1600 - 7), the pixels'
; loop with its colour, its byte count and its step written into it
ntc_vic_fast:
			lda $68						; the colour
			sta ntc_vic_fl_c1+1
			sta ntc_vic_fl_c2+1
			sta ntc_vic_fy_c1+1
			sta ntc_vic_fy_c2+1
			lda $6E						; bytes a column
			sta ntc_vic_fl_n+1
			sta ntc_vic_fy_n+1
			lda $67						; flip y: Z from the bottom row
			sec
			sbc #1
			asl
			asl
			asl
			sta ntc_vic_fy_z+1
			; the first column drawn: x (flip x: x + w - 1)
			lda $62
			sta $56
			lda $63
			sta $57
			lda $69
			and #1
			beq ntc_vic_f1
			clc
			lda $56
			adc $66
			sta $56
			bcc ntc_vic_f0
			inc $57
ntc_vic_f0:
			lda $56
			bne ntc_vic_f0b
			dec $57
ntc_vic_f0b:
			dec $56
ntc_vic_f1:
			lda $56
			and #7
			sta $5B						; where in its character (0-7)
			lda $57
			lsr
			lda $56
			ror
			lsr
			lsr
			tay
			lda $5B
			clc
			adc ntc_vic_cbl,y
			sta $50
			lda ntc_vic_cbh,y
			adc #0
			sta $51
			lda $64						; + y * 8
			sta $58
			lda #0
			sta $59
			asl $58
			rol $59
			asl $58
			rol $59
			asl $58
			rol $59
			clc
			lda $50
			adc $58
			sta $50
			lda $51
			adc $59
			sta $51
			lda $6C
			sta $52
			lda #0
			sta $53
			lda $66
			sta $6D						; columns left
ntc_vic_f_col:
			lda $69
			and #2
			bne ntc_vic_f_fy
			; down the column
			ldz #0
			ldy #0
ntc_vic_fl_l:
			lda ($5C),y
			tax
			and #$0F
			beq ntc_vic_fl_1
ntc_vic_fl_c1:
			ora #0
			sta [$50],z
ntc_vic_fl_1:
			tza
			clc
			adc #8
			taz
			txa
			lsr
			lsr
			lsr
			lsr
			beq ntc_vic_fl_2
ntc_vic_fl_c2:
			ora #0
			sta [$50],z
ntc_vic_fl_2:
			tza
			clc
			adc #8
			taz
			iny
ntc_vic_fl_n:
			cpy #0
			bne ntc_vic_fl_l
			jmp ntc_vic_f_next
ntc_vic_f_fy:
			; up the column (flip y)
ntc_vic_fy_z:
			ldz #0
			ldy #0
ntc_vic_fy_l:
			lda ($5C),y
			tax
			and #$0F
			beq ntc_vic_fy_1
ntc_vic_fy_c1:
			ora #0
			sta [$50],z
ntc_vic_fy_1:
			tza
			sec
			sbc #8
			taz
			txa
			lsr
			lsr
			lsr
			lsr
			beq ntc_vic_fy_2
ntc_vic_fy_c2:
			ora #0
			sta [$50],z
ntc_vic_fy_2:
			tza
			sec
			sbc #8
			taz
			iny
ntc_vic_fy_n:
			cpy #0
			bne ntc_vic_fy_l
ntc_vic_f_next:
			ldz #0
			dec $6D
			beq ntc_vic_f_done
			clc							; the next column's pixels
			lda $5C
			adc $6E
			sta $5C
			bcc ntc_vic_f_n1
			inc $5D
ntc_vic_f_n1:
			lda $69
			and #1
			bne ntc_vic_f_left
			; to the right
			lda $5B
			cmp #7
			beq ntc_vic_f_rc
			inc $5B
			inw $50
			jmp ntc_vic_f_col
ntc_vic_f_rc:
			lda #0
			sta $5B
			clc
			lda $50
			adc #<1593
			sta $50
			lda $51
			adc #>1593
			sta $51
			jmp ntc_vic_f_col
ntc_vic_f_left:
			lda $5B
			beq ntc_vic_f_lc
			dec $5B
			dew $50
			jmp ntc_vic_f_col
ntc_vic_f_lc:
			lda #7
			sta $5B
			sec
			lda $50
			sbc #<1593
			sta $50
			lda $51
			sbc #>1593
			sta $51
			jmp ntc_vic_f_col
ntc_vic_f_done:
			rts

; one column: the pixels at $5C ($6E bytes), screen x = $56 (0-255) / $57 (high: x 256-319
; for a 320 field), y = $64 / $65, $6F = 1 when it needs clipping
ntc_vic_col:
			; the column's address in the bank: (x >> 3) * 1600 + (x & 7)
			lda $57
			lsr
			lda $56
			ror
			lsr
			lsr
			tay
			lda $56
			and #7
			clc
			adc ntc_vic_cbl,y
			sta $50
			lda ntc_vic_cbh,y
			adc #0
			sta $51
			lda $6C
			sta $52
			lda #0
			sta $53
			lda $6F
			bne ntc_vic_col_clip
			; + y * 8
			lda $64
			sta $58
			lda #0
			sta $59
			asl $58
			rol $59
			asl $58
			rol $59
			asl $58
			rol $59
			clc
			lda $50
			adc $58
			sta $50
			lda $51
			adc $59
			sta $51
			; Z: the row * 8 (flip y: from the bottom)
			lda $69
			and #2
			bne ntc_vic_col_fy
			ldz #0
			lda #8
			sta $5A
			jmp ntc_vic_col_go
ntc_vic_col_fy:
			lda $67
			sec
			sbc #1
			asl
			asl
			asl
			taz
			lda #$F8
			sta $5A
ntc_vic_col_go:
			ldy #0
ntc_vic_col_l:
			lda ($5C),y
			and #$0F
			beq ntc_vic_col_1
			ora $68
			sta [$50],z
ntc_vic_col_1:
			tza
			clc
			adc $5A
			taz
			lda ($5C),y
			lsr
			lsr
			lsr
			lsr
			beq ntc_vic_col_2
			ora $68
			sta [$50],z
ntc_vic_col_2:
			tza
			clc
			adc $5A
			taz
			iny
			cpy $6E
			bne ntc_vic_col_l
			ldz #0
			rts
; clipped: each pixel's row checked, its address worked out ($58 = column base, $5A = row)
ntc_vic_col_clip:
			lda $50
			sta $58
			lda $51
			sta $59
			lda #0
			sta $5B						; the pixel (0 .. h - 1)
ntc_vic_cc_l:
			lda $5B						; the source byte and nybble
			lsr
			tay
			lda ($5C),y
			bcc ntc_vic_cc_lo
			lsr
			lsr
			lsr
			lsr
ntc_vic_cc_lo:
			and #$0F
			beq ntc_vic_cc_n
			ora $68
			sta $5E						; the colour
			; the row: y + p (flip y: y + h - 1 - p), 16 bits
			lda $69
			and #2
			bne ntc_vic_cc_fy
			clc
			lda $64
			adc $5B
			sta $5A
			lda $65
			adc #0
			jmp ntc_vic_cc_r
ntc_vic_cc_fy:
			lda $67
			sec
			sbc #1
			sec
			sbc $5B
			clc
			adc $64
			sta $5A
			lda $65
			adc #0
ntc_vic_cc_r:
			bne ntc_vic_cc_n			; above the top or far below
			lda $5A
			cmp #200
			bcs ntc_vic_cc_n
			sta $50						; row * 8 + the column's base
			lda #0
			sta $51
			asl $50
			rol $51
			asl $50
			rol $51
			asl $50
			rol $51
			clc
			lda $50
			adc $58
			sta $50
			lda $51
			adc $59
			sta $51
			ldz #0
			lda $5E
			sta [$50],z
ntc_vic_cc_n:
			inc $5B
			lda $5B
			cmp $67
			bne ntc_vic_cc_l
			rts

; the text layer: the playfield's characters (every frame, see through) and the panel's
; that changed (opaque)
ntc_vic_text:
			lda #<VIC_TXT
			sta $54
			lda #>VIC_TXT
			sta $55
			lda #<VIC_DIRTY
			sta $60
			lda #>VIC_DIRTY
			sta $61
			lda ntc_vic_back			; the dirty bit for this buffer: 1 A, 2 B
			clc
			adc #1
			sta $62
			lda #0
			sta $57						; row
ntc_vic_tx_r:
			ldy #0
			lda ntc_vic_fw
			beq ntc_vic_tx_pn
ntc_vic_tx_pf:
			lda ($54),y
			cmp #33
			bcs ntc_vic_tx_pfd
ntc_vic_tx_pfn:
			iny
			cpy ntc_vic_fw
			bne ntc_vic_tx_pf
ntc_vic_tx_pn:
			cpy #40
			beq ntc_vic_tx_rd
			lda ($60),y
			and $62
			bne ntc_vic_tx_pnd
ntc_vic_tx_pnn:
			iny
			jmp ntc_vic_tx_pn
ntc_vic_tx_pfd:
			sta $5E						; a character on the playfield: see through
			sty $56
			lda #0
			sta $5F
			jsr ntc_vic_glyph
			ldy $56
			jmp ntc_vic_tx_pfn
ntc_vic_tx_pnd:
			lda ($60),y					; a panel cell to draw: its bit off, opaque
			eor $62
			sta ($60),y
			lda ($54),y
			sta $5E
			sty $56
			lda #1
			sta $5F
			jsr ntc_vic_glyph
			ldy $56
			jmp ntc_vic_tx_pnn
ntc_vic_tx_rd:
			clc
			lda $54
			adc #40
			sta $54
			sta $60
			bcc ntc_vic_tx_r2
			inc $55
			inc $61
ntc_vic_tx_r2:
			inc $57
			lda $57
			cmp #25
			bne ntc_vic_tx_r
			rts

; a character: $5E at column $56, row $57, its colour from VIC_TCOL ($54 + $400 + column),
; $5F = 1 opaque (the paper behind)
ntc_vic_glyph:
			ldy $56
			lda $55						; its colour
			clc
			adc #>(VIC_TCOL-VIC_TXT)
			sta $5B
			lda $54
			sta $5A
			lda ($5A),y
			sta $5D
			; the cell: column * 1600 + row * 64 (64 bytes, 8 a row)
			lda $57
			sta $50
			lda #0
			sta $51
			ldx #6
ntc_vic_gl_m:
			asl $50
			rol $51
			dex
			bne ntc_vic_gl_m
			clc
			lda $50
			adc ntc_vic_cbl,y
			sta $50
			lda $51
			adc ntc_vic_cbh,y
			sta $51
			lda $6C
			sta $52
			lda #0
			sta $53
			; the font: $E000 + character * 8
			lda $5E
			sta $5A
			lda #0
			sta $5B
			asl $5A
			rol $5B
			asl $5A
			rol $5B
			asl $5A
			rol $5B
			clc
			lda $5B
			adc #$E0
			sta $5B
			ldz #0
			ldy #0
ntc_vic_gl_r:
			lda ($5A),y
			sta $59
			ldx #8
ntc_vic_gl_b:
			asl $59
			bcc ntc_vic_gl_0
			lda $5D
			sta [$50],z
			jmp ntc_vic_gl_nx
ntc_vic_gl_0:
			lda $5F
			beq ntc_vic_gl_nx
			lda ntc_vic_paper
			sta [$50],z
ntc_vic_gl_nx:
			inz
			dex
			bne ntc_vic_gl_b
			iny
			cpy #8
			bne ntc_vic_gl_r
			ldz #0
			rts

; ntc_vic_stamp - the image at $60 into both buffers at $62 (x), $64 (y): $68 colour added,
; $69 flips (for the panel: it is not cleared). The whole screen (320 wide)
ntc_vic_stamp:
			lda ntc_vic_fpx
			pha
			lda ntc_vic_fpx+1
			pha
			lda #<320
			sta ntc_vic_fpx
			lda #>320
			sta ntc_vic_fpx+1
			lda #4
			sta $6C
			jsr ntc_vic_draw
			lda #5
			sta $6C
			jsr ntc_vic_draw
			pla
			sta ntc_vic_fpx+1
			pla
			sta ntc_vic_fpx
			rts

; ntc_vic_box - a filled box in both buffers: $62 x, $64 y, $66 w, $67 h (pixels: x, w
; multiples of 8 are fastest), $68 the colour
ntc_vic_box:
			lda #4
			sta $6C
			jsr ntc_vic_box1
			lda #5
			sta $6C
ntc_vic_box1:
			lda #0
			sta $6D						; the pixel column
ntc_vic_bx_c:
			clc
			lda $62
			adc $6D
			sta $56
			lda $63
			adc #0
			sta $57
			; the column's address + y * 8
			lsr
			lda $56
			ror
			lsr
			lsr
			tay
			lda $56
			and #7
			clc
			adc ntc_vic_cbl,y
			sta $50
			lda ntc_vic_cbh,y
			adc #0
			sta $51
			lda $64
			sta $58
			lda #0
			sta $59
			asl $58
			rol $59
			asl $58
			rol $59
			asl $58
			rol $59
			clc
			lda $50
			adc $58
			sta $50
			lda $51
			adc $59
			sta $51
			lda $6C
			sta $52
			lda #0
			sta $53
			ldx $67
			ldz #0
			lda $68
ntc_vic_bx_r:
			sta [$50],z
			tay
			tza
			clc
			adc #8
			taz
			bcc ntc_vic_bx_r1
			inc $51						; (past 32 rows: the next 256 bytes)
ntc_vic_bx_r1:
			tya
			dex
			bne ntc_vic_bx_r
			ldz #0
			inc $6D
			lda $6D
			cmp $66
			bne ntc_vic_bx_c
			rts


;## ntc_sid ntc_plat_data
; ------------------------------------------------------------
; The Sid class's engine: 4 channels (3 tones on SID 1's voices, a noise on SID
; 2's voice 1) as sound effects that move on a frame at a time (ntc_sid_update,
; from Sid.Update): a period (the Mega Drive PSG's: 3579545 / 32 / period Hz)
; that slides and a volume that fades (the voice's sustain level). A channel:
; active, -, period, slide, volume, -, frames, left (12 bytes). Uses $50-$5F.
; ------------------------------------------------------------
ntc_sidch:		ds 4*12
ntc_sid_regs:	db $00, $07, $0E, $20		; each channel's voice: $D400 + this
ntc_sid_init:	db 0						; the SIDs set up (volume, pulse widths)

; the SIDs' volume up and the voices' pulse width a half (once)
ntc_sid_setup:
			lda ntc_sid_init
			bne ntc_sid_su_e
			inc ntc_sid_init
			lda #$0F
			sta $D418
			sta $D438
			ldx #3
ntc_sid_su_l:
			ldy ntc_sid_regs,x
			lda #0
			sta $D402,y
			sta $D405,y					; attack, decay: 0
			lda #8
			sta $D403,y					; pulse width $800: a square
			dex
			bpl ntc_sid_su_l
ntc_sid_su_e:
			rts

; ntc_sid_on - A = the channel, X = its state (12 * channel): started (gated again)
ntc_sid_on:
			sta $5F
			stx $5E
			jsr ntc_sid_setup
			ldx $5F
			ldy ntc_sid_regs,x
			lda #0						; gate off, then on (attack again)
			sta $D404,y
			ldx $5E
			jsr ntc_sid_out
			ldx $5F
			ldy ntc_sid_regs,x
			lda #$41					; pulse, gate
			cpx #3
			bne ntc_sid_on1
			lda #$81					; noise, gate
ntc_sid_on1:
			sta $D404,y
			rts

; ntc_sid_off - A = the channel: silent, not active
ntc_sid_off:
			tax
			ldy ntc_sid_regs,x
			lda #0
			sta $D404,y					; gate off (release 0)
			sta $D406,y					; sustain 0
			txa
			asl
			asl
			sta $5D
			asl
			clc
			adc $5D
			tax
			lda #0
			sta ntc_sidch,x
			rts

; ntc_sid_out - $5F = the channel, X = its state: the frequency and the volume to the SID
ntc_sid_out:
			stx $5E
			ldy $5F
			cpy #3
			beq ntc_sid_o_noise
			; frequency = 1904665 / period
			lda ntc_sidch+2,x
			sta $5A
			lda ntc_sidch+3,x
			sta $5B
			lda #$19
			sta $5C
			lda #$10
			sta $5D
			lda #$1D
			sta $56
			jsr ntc_sid_div				; $5C/$5D/$56 / $5A/$5B
			lda $56						; past 16 bits: the top
			beq ntc_sid_o_f
			lda #$FF
			sta $5C
			sta $5D
ntc_sid_o_f:
			ldx $5F
			ldy ntc_sid_regs,x
			lda $5C
			sta $D400,y
			lda $5D
			sta $D401,y
			jmp ntc_sid_o_vol
ntc_sid_o_noise:
			lda ntc_sidch+2,x			; the kind: 0 high, 1 middle, 2 low, 3 channel 2's
			and #3
			tay
			lda ntc_sid_nhi,y
			bne ntc_sid_o_n1
			lda $D40F					; (channel 2's frequency)
			sta $D421
			lda $D40E
			sta $D420
			jmp ntc_sid_o_vol
ntc_sid_o_n1:
			sta $D421
			lda #0
			sta $D420
ntc_sid_o_vol:
			; the volume now: volume * left / frames (frames 0: the volume)
			ldx $5E
			lda ntc_sidch+6,x
			sta $57						; the volume
			lda ntc_sidch+8,x
			ora ntc_sidch+9,x
			beq ntc_sid_o_v
			lda ntc_sidch+8,x			; divisor: frames
			sta $5A
			lda ntc_sidch+9,x
			sta $5B
			; volume * left (15 * 65535 at most: 24 bits)
			lda ntc_sidch+10,x
			sta $50
			lda ntc_sidch+11,x
			sta $51
			lda #0
			sta $5C
			sta $5D
			sta $56
			ldy $57
			beq ntc_sid_o_v
ntc_sid_o_m:
			clc
			lda $5C
			adc $50
			sta $5C
			lda $5D
			adc $51
			sta $5D
			lda $56
			adc #0
			sta $56
			dey
			bne ntc_sid_o_m
			jsr ntc_sid_div
			lda $5C
			sta $57
ntc_sid_o_v:
			lda $57						; the sustain level
			and #$0F
			asl
			asl
			asl
			asl
			ldx $5F
			ldy ntc_sid_regs,x
			sta $D406,y
			ldx $5E
			rts
ntc_sid_nhi:	db $30, $18, $0C, 0

; $5C/$5D/$56 (24 bits) / $5A/$5B: the quotient in $5C/$5D/$56, the remainder in $58/$59
ntc_sid_div:
			lda #0
			sta $58
			sta $59
			ldx #24
ntc_sid_dv_l:
			asl $5C
			rol $5D
			rol $56
			rol $58
			rol $59
			lda $58
			sec
			sbc $5A
			tay
			lda $59
			sbc $5B
			bcc ntc_sid_dv_n
			sta $59
			sty $58
			inc $5C
ntc_sid_dv_n:
			dex
			bne ntc_sid_dv_l
			rts

; ntc_sid_update - every active channel a frame on
ntc_sid_update:
			lda #0
			sta $5F						; the channel
ntc_sid_u_l:
			lda $5F
			asl
			asl
			sta $5D
			asl
			clc
			adc $5D
			tax
			lda ntc_sidch,x
			beq ntc_sid_u_n
			lda ntc_sidch+8,x			; frames: 0 = held until stopped
			ora ntc_sidch+9,x
			beq ntc_sid_u_sl
			lda ntc_sidch+10,x			; left - 1
			bne ntc_sid_u_d
			dec ntc_sidch+11,x
ntc_sid_u_d:
			dec ntc_sidch+10,x
			lda ntc_sidch+10,x
			ora ntc_sidch+11,x
			beq ntc_sid_u_off
			lda ntc_sidch+11,x			; (gone below 0: off too)
			bpl ntc_sid_u_sl
ntc_sid_u_off:
			lda $5F
			jsr ntc_sid_off
			jmp ntc_sid_u_n
ntc_sid_u_sl:
			clc							; period += slide, kept 1 .. 1023 (a tone)
			lda ntc_sidch+2,x
			adc ntc_sidch+4,x
			sta ntc_sidch+2,x
			lda ntc_sidch+3,x
			adc ntc_sidch+5,x
			sta ntc_sidch+3,x
			lda $5F
			cmp #3
			beq ntc_sid_u_out
			lda ntc_sidch+3,x
			bmi ntc_sid_u_lo
			bne ntc_sid_u_hi
			lda ntc_sidch+2,x
			bne ntc_sid_u_out
ntc_sid_u_lo:
			lda #1
			sta ntc_sidch+2,x
			lda #0
			sta ntc_sidch+3,x
			jmp ntc_sid_u_out
ntc_sid_u_hi:
			cmp #4
			bcc ntc_sid_u_out
			lda #<1023
			sta ntc_sidch+2,x
			lda #>1023
			sta ntc_sidch+3,x
ntc_sid_u_out:
			jsr ntc_sid_out
ntc_sid_u_n:
			inc $5F
			lda $5F
			cmp #4
			bne ntc_sid_u_l
			rts


;## ntc_m65_fontdata
; font8x8_basic (public domain, Daniel Hepper): characters 32-127, 8 bytes each
ntc_m65_fontdata:
			db $00, $00, $00, $00, $00, $00, $00, $00		; 32 space
			db $18, $3C, $3C, $18, $18, $00, $18, $00		; 33 !
			db $6C, $6C, $00, $00, $00, $00, $00, $00		; 34 "
			db $6C, $6C, $FE, $6C, $FE, $6C, $6C, $00		; 35 #
			db $30, $7C, $C0, $78, $0C, $F8, $30, $00		; 36 $
			db $00, $C6, $CC, $18, $30, $66, $C6, $00		; 37 %
			db $38, $6C, $38, $76, $DC, $CC, $76, $00		; 38 &
			db $60, $60, $C0, $00, $00, $00, $00, $00		; 39 '
			db $18, $30, $60, $60, $60, $30, $18, $00		; 40 (
			db $60, $30, $18, $18, $18, $30, $60, $00		; 41 )
			db $00, $66, $3C, $FF, $3C, $66, $00, $00		; 42 *
			db $00, $30, $30, $FC, $30, $30, $00, $00		; 43 +
			db $00, $00, $00, $00, $00, $30, $30, $60		; 44 ,
			db $00, $00, $00, $FC, $00, $00, $00, $00		; 45 -
			db $00, $00, $00, $00, $00, $30, $30, $00		; 46 .
			db $06, $0C, $18, $30, $60, $C0, $80, $00		; 47 /
			db $7C, $C6, $CE, $DE, $F6, $E6, $7C, $00		; 48 0
			db $30, $70, $30, $30, $30, $30, $FC, $00		; 49 1
			db $78, $CC, $0C, $38, $60, $CC, $FC, $00		; 50 2
			db $78, $CC, $0C, $38, $0C, $CC, $78, $00		; 51 3
			db $1C, $3C, $6C, $CC, $FE, $0C, $1E, $00		; 52 4
			db $FC, $C0, $F8, $0C, $0C, $CC, $78, $00		; 53 5
			db $38, $60, $C0, $F8, $CC, $CC, $78, $00		; 54 6
			db $FC, $CC, $0C, $18, $30, $30, $30, $00		; 55 7
			db $78, $CC, $CC, $78, $CC, $CC, $78, $00		; 56 8
			db $78, $CC, $CC, $7C, $0C, $18, $70, $00		; 57 9
			db $00, $30, $30, $00, $00, $30, $30, $00		; 58 :
			db $00, $30, $30, $00, $00, $30, $30, $60		; 59 ;
			db $18, $30, $60, $C0, $60, $30, $18, $00		; 60 <
			db $00, $00, $FC, $00, $00, $FC, $00, $00		; 61 =
			db $60, $30, $18, $0C, $18, $30, $60, $00		; 62 >
			db $78, $CC, $0C, $18, $30, $00, $30, $00		; 63 ?
			db $7C, $C6, $DE, $DE, $DE, $C0, $78, $00		; 64 @
			db $30, $78, $CC, $CC, $FC, $CC, $CC, $00		; 65 A
			db $FC, $66, $66, $7C, $66, $66, $FC, $00		; 66 B
			db $3C, $66, $C0, $C0, $C0, $66, $3C, $00		; 67 C
			db $F8, $6C, $66, $66, $66, $6C, $F8, $00		; 68 D
			db $FE, $62, $68, $78, $68, $62, $FE, $00		; 69 E
			db $FE, $62, $68, $78, $68, $60, $F0, $00		; 70 F
			db $3C, $66, $C0, $C0, $CE, $66, $3E, $00		; 71 G
			db $CC, $CC, $CC, $FC, $CC, $CC, $CC, $00		; 72 H
			db $78, $30, $30, $30, $30, $30, $78, $00		; 73 I
			db $1E, $0C, $0C, $0C, $CC, $CC, $78, $00		; 74 J
			db $E6, $66, $6C, $78, $6C, $66, $E6, $00		; 75 K
			db $F0, $60, $60, $60, $62, $66, $FE, $00		; 76 L
			db $C6, $EE, $FE, $FE, $D6, $C6, $C6, $00		; 77 M
			db $C6, $E6, $F6, $DE, $CE, $C6, $C6, $00		; 78 N
			db $38, $6C, $C6, $C6, $C6, $6C, $38, $00		; 79 O
			db $FC, $66, $66, $7C, $60, $60, $F0, $00		; 80 P
			db $78, $CC, $CC, $CC, $DC, $78, $1C, $00		; 81 Q
			db $FC, $66, $66, $7C, $6C, $66, $E6, $00		; 82 R
			db $78, $CC, $E0, $70, $1C, $CC, $78, $00		; 83 S
			db $FC, $B4, $30, $30, $30, $30, $78, $00		; 84 T
			db $CC, $CC, $CC, $CC, $CC, $CC, $FC, $00		; 85 U
			db $CC, $CC, $CC, $CC, $CC, $78, $30, $00		; 86 V
			db $C6, $C6, $C6, $D6, $FE, $EE, $C6, $00		; 87 W
			db $C6, $C6, $6C, $38, $38, $6C, $C6, $00		; 88 X
			db $CC, $CC, $CC, $78, $30, $30, $78, $00		; 89 Y
			db $FE, $C6, $8C, $18, $32, $66, $FE, $00		; 90 Z
			db $78, $60, $60, $60, $60, $60, $78, $00		; 91 [
			db $C0, $60, $30, $18, $0C, $06, $02, $00		; 92 \
			db $78, $18, $18, $18, $18, $18, $78, $00		; 93 ]
			db $10, $38, $6C, $C6, $00, $00, $00, $00		; 94 ^
			db $00, $00, $00, $00, $00, $00, $00, $FF		; 95 _
			db $30, $30, $18, $00, $00, $00, $00, $00		; 96 `
			db $00, $00, $78, $0C, $7C, $CC, $76, $00		; 97 a
			db $E0, $60, $60, $7C, $66, $66, $DC, $00		; 98 b
			db $00, $00, $78, $CC, $C0, $CC, $78, $00		; 99 c
			db $1C, $0C, $0C, $7C, $CC, $CC, $76, $00		; 100 d
			db $00, $00, $78, $CC, $FC, $C0, $78, $00		; 101 e
			db $38, $6C, $60, $F0, $60, $60, $F0, $00		; 102 f
			db $00, $00, $76, $CC, $CC, $7C, $0C, $F8		; 103 g
			db $E0, $60, $6C, $76, $66, $66, $E6, $00		; 104 h
			db $30, $00, $70, $30, $30, $30, $78, $00		; 105 i
			db $0C, $00, $0C, $0C, $0C, $CC, $CC, $78		; 106 j
			db $E0, $60, $66, $6C, $78, $6C, $E6, $00		; 107 k
			db $70, $30, $30, $30, $30, $30, $78, $00		; 108 l
			db $00, $00, $CC, $FE, $FE, $D6, $C6, $00		; 109 m
			db $00, $00, $F8, $CC, $CC, $CC, $CC, $00		; 110 n
			db $00, $00, $78, $CC, $CC, $CC, $78, $00		; 111 o
			db $00, $00, $DC, $66, $66, $7C, $60, $F0		; 112 p
			db $00, $00, $76, $CC, $CC, $7C, $0C, $1E		; 113 q
			db $00, $00, $DC, $76, $66, $60, $F0, $00		; 114 r
			db $00, $00, $7C, $C0, $78, $0C, $F8, $00		; 115 s
			db $10, $30, $7C, $30, $30, $34, $18, $00		; 116 t
			db $00, $00, $CC, $CC, $CC, $CC, $76, $00		; 117 u
			db $00, $00, $CC, $CC, $CC, $78, $30, $00		; 118 v
			db $00, $00, $C6, $D6, $FE, $FE, $6C, $00		; 119 w
			db $00, $00, $C6, $6C, $38, $6C, $C6, $00		; 120 x
			db $00, $00, $CC, $CC, $CC, $7C, $0C, $F8		; 121 y
			db $00, $00, $FC, $98, $30, $64, $FC, $00		; 122 z
			db $1C, $30, $30, $E0, $30, $30, $1C, $00		; 123 {
			db $18, $18, $18, $00, $18, $18, $18, $00		; 124 |
			db $E0, $30, $30, $1C, $30, $30, $E0, $00		; 125 }
			db $76, $DC, $00, $00, $00, $00, $00, $00		; 126 ~
			db 0, 0, 0, 0, 0, 0, 0, 0		; 127

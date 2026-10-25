; ============================================================
; NTC Platform - Sega Mega Drive / Genesis (68000), direct hardware
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A cartridge ROM: the 68000's vectors at 0, the header at $100, the start
; code at $200. The program runs in USER mode with A7 (the user stack
; pointer) as the thread; the VDP's frame interrupt (level 6) runs in
; supervisor mode on its own stack, so it never touches the thread and
; interrupts stay on all the time.
;
; Memory:
;   $000000-        the ROM: vectors, header, start, threads, keywords,
;                   then the RAM block's first image (copied at start)
;   $FF0000-$FF6FFF free (NTC_MDLOG test builds: the console transcript)
;   $FF7000-$FF77FF the real stack (ntc_csp: the library's jsr calls)
;   $FF7800-$FF7FFF the supervisor stack (interrupts, exceptions)
;   $FF8000-$FFFFFF the program's variables, the library's, then its arrays
;
; The VDP (set up at start): H40 (320 x 224), plane A at $C000, plane B at
; $E000 (64 x 32 cells each), window at $A000 (off), sprites at $D800,
; horizontal scroll at $FC00. The console is plane A: character c is tile
; c (the font is tiles 32-126 at $0400, pixels in colour 1 of palette 0).
; Tiles 128 on ($1000) are free for the program.
;
; The pads are read once a frame in the interrupt (3 and 6 button):
;   ntc_pad1 / ntc_pad2: bit 0 Up, 1 Down, 2 Left, 3 Right, 4 B, 5 C, 6 A,
;   7 Start, 8 X, 9 Y, 10 Z, 11 Mode (1 = held)
; Inkey / Input use pad 1: Start = 13, A B C = "A" "B" "C", X Y Z = "X" "Y"
; "Z", Mode = 27, Up Down Left Right = &HF0 &HF1 &HF2 &HF3 (as the CPC's
; cursor keys).
; ============================================================
;@name     Sega Mega Drive / Genesis (68000)
;@cpu      68000
;@org      0
;@text     byte
;@scrinit  0
;@irq      0
;@cols     40
;@rows     28
; ============================================================

;## ntc_md_vectors ntc_md_boot
; the 68000's vectors and the cartridge header (the compiler puts this first, at 0)
			dc.l $00FF8000				; the supervisor stack
			dc.l ntc_md_entry
			dc.l ntc_md_ex2, ntc_md_ex3, ntc_md_ex4, ntc_md_ex5
			dc.l ntc_md_ex6, ntc_md_ex7, ntc_md_ex8, ntc_md_ex9
			dc.l ntc_md_ex10, ntc_md_ex11
			dcb.l 12, ntc_md_exx		; 12-23
			dc.l ntc_md_exx				; 24 spurious
			dc.l ntc_md_rte				; 25 level 1
			dc.l ntc_md_rte				; 26 level 2 (external)
			dc.l ntc_md_rte				; 27 level 3
			dc.l ntc_md_hint			; 28 level 4 (line)
			dc.l ntc_md_rte				; 29 level 5
			dc.l ntc_md_vint			; 30 level 6 (frame)
			dc.l ntc_md_rte				; 31 level 7
			dcb.l 16, ntc_md_exx		; 32-47 TRAP #0-15
			dcb.l 16, ntc_md_exx		; 48-63
; the header ($100): mdbuild.py puts in the name, the ROM's end and the checksum
			dc.b "SEGA MEGA DRIVE "
			dc.b "(C)NTC  2026.OCT"
			dc.b "NTC BASIC                                       "
			dc.b "NTC BASIC                                       "
			dc.b "GM 00000000-00"
			dc.w 0						; checksum
			dc.b "J6              "		; I/O: 3 and 6 button pads
			dc.l $00000000, $003FFFFF	; ROM start, end
			dc.l $00FF0000, $00FFFFFF	; RAM start, end
			dc.b "            "			; no SRAM
			dc.b "            "
			dc.b "                                        "
			dc.b "JUE             "		; every region

;## ntc_md_boot ntc_plat_data ntc_data ntc_md_vdp ntc_md_fontdata ntc_plat_screen
; ------------------------------------------------------------
; the start ($200): TMSS, the Z80 held, RAM cleared and the RAM block copied
; from the ROM, the VDP, the font, the pads, the PSG quiet; then user mode
; on the real stack and into ntc_start
; ------------------------------------------------------------
VDP_DATA	equ $C00000
VDP_CTRL	equ $C00004
PSG_PORT	equ $C00011
NTC_USTACK	equ $00FF7800			; the real stack's top
ntc_md_entry:
			move.w #$2700, sr
			move.b $A10001, d0
			andi.b #$0F, d0
			beq ntc_mb_notmss
			move.l #'SEGA', $A14000		; TMSS
ntc_mb_notmss:
			move.w #$0100, $A11100		; the Z80's bus ours
			move.w #$0000, $A11200		; and the Z80 held in reset
			lea $FF0000, a0				; RAM cleared (below the supervisor stack's last words: no)
			move.w #($8000/4)-1, d0
ntc_mb_clr:
			clr.l (a0)+
			dbra d0, ntc_mb_clr
			lea $FF8000, a0
			move.w #($8000/4)-1, d0
ntc_mb_clr2:
			clr.l (a0)+
			dbra d0, ntc_mb_clr2
			lea ntc_romend, a0			; the RAM block's first image, from the ROM
			lea ntc_ram, a1
			move.l #ntc_ramend-ntc_ram, d0
			beq ntc_mb_nodata
ntc_mb_cp:
			move.b (a0)+, (a1)+
			subq.l #1, d0
			bne ntc_mb_cp
ntc_mb_nodata:
			move.w VDP_CTRL, d0			; (the VDP's control state reset)
			lea ntc_md_vregs, a0
			moveq #ntc_md_vregs_n-1, d0
ntc_mb_reg:
			move.w (a0)+, VDP_CTRL
			dbra d0, ntc_mb_reg
			move.l #$40000000, VDP_CTRL	; VRAM 0: all clear
			move.w #$8000-1, d0
ntc_mb_vram:
			move.w #0, VDP_DATA
			dbra d0, ntc_mb_vram
			move.l #$C0000000, VDP_CTRL	; CRAM
			moveq #64-1, d0
ntc_mb_cram:
			move.w #0, VDP_DATA
			dbra d0, ntc_mb_cram
			move.l #$40000010, VDP_CTRL	; VSRAM
			moveq #40-1, d0
ntc_mb_vsram:
			move.w #0, VDP_DATA
			dbra d0, ntc_mb_vsram
			move.l #$C0020000, VDP_CTRL	; palette 0 colour 1: the text, white
			move.w #$0EEE, VDP_DATA
			; the font: tiles 32-126 at $0400, 1 bit a pixel -> colour 1
			move.l #$44000000, VDP_CTRL
			lea ntc_md_font, a0
			move.w #95*8-1, d1
ntc_mb_font:
			move.b (a0)+, d2
			moveq #0, d3
			moveq #8-1, d4
ntc_mb_fbit:
			lsl.l #4, d3
			add.b d2, d2
			bcc ntc_mb_f0
			addq.b #1, d3
ntc_mb_f0:
			dbra d4, ntc_mb_fbit
			move.l d3, VDP_DATA
			dbra d1, ntc_mb_font
			move.w #$8174, VDP_CTRL		; the display on, the frame interrupt on
			; the pads: TH an output, high
			move.b #$40, $A10009
			move.b #$40, $A1000B
			move.b #$40, $A10003
			move.b #$40, $A10005
			; the PSG quiet
			move.b #$9F, PSG_PORT
			move.b #$BF, PSG_PORT
			move.b #$DF, PSG_PORT
			move.b #$FF, PSG_PORT
			move.b #40, ntc_scols
			move.b #28, ntc_srows
			move.l #NTC_USTACK, a0
			move.l a0, usp
			move.w #$0000, sr			; user mode, the interrupts on: A7 is now the user stack
			jmp ntc_start

ntc_md_vregs:
			dc.w $8004					; 0: no line interrupt
			dc.w $8134					; 1: display off for now, frame interrupt, DMA, 28 rows
			dc.w $8230					; 2: plane A at $C000
			dc.w $8328					; 3: the window at $A000
			dc.w $8407					; 4: plane B at $E000
			dc.w $856C					; 5: sprites at $D800
			dc.w $8600
			dc.w $8700					; 7: the backdrop: palette 0 colour 0
			dc.w $8800
			dc.w $8900
			dc.w $8AFF					; 10: line interrupt every 256 lines
			dc.w $8B00					; 11: whole screen scrolling
			dc.w $8C81					; 12: H40, no interlace
			dc.w $8D3F					; 13: horizontal scroll at $FC00
			dc.w $8E00
			dc.w $8F02					; 15: VDP address step 2
			dc.w $9001					; 16: planes 64 x 32 cells
			dc.w $9100					; 17, 18: no window
			dc.w $9200
ntc_md_vregs_n	equ (*-ntc_md_vregs)/2

; ------------------------------------------------------------
; interrupts and exceptions (supervisor mode, the supervisor stack)
; ------------------------------------------------------------
; the frame: count it, read the pads (3 or 6 button, once a frame - a 6
; button pad's counter needs the gap between reads), run the frame hook
ntc_md_vint:
			movem.l d0-d4/a0-a1, -(sp)
			addq.w #1, ntc_ticks
			addq.w #1, ntc_vbl
			lea $A10003, a0
			bsr ntc_md_pad
			move.w d0, ntc_pad1
			lea $A10005, a0
			bsr ntc_md_pad
			move.w d0, ntc_pad2
			move.l ntc_vhook, d0
			beq ntc_vi_nohook
			movea.l d0, a0
			jsr (a0)					; (keeps every register but d0-d4 / a0-a1)
ntc_vi_nohook:
			movem.l (sp)+, d0-d4/a0-a1
ntc_md_rte:
			rte
ntc_md_hint:
			rte

; a0 = the port's data register: d0 = its buttons (1 = held)
ntc_md_pad:
			move.b #$40, (a0)
			nop
			nop
			move.b (a0), d1				; ?1CBRLDU
			move.b #$00, (a0)
			nop
			nop
			move.b (a0), d2				; ?0SA00DU
			move.b #$40, (a0)
			nop
			nop
			move.b #$00, (a0)
			nop
			nop
			move.b (a0), d3				; ?0SA0000 on a 6 button pad
			move.b #$40, (a0)
			nop
			nop
			move.b (a0), d4				; ?1CBMXYZ on a 6 button pad
			move.b #$00, (a0)
			nop
			nop
			move.b #$40, (a0)
			not.b d1
			not.b d2
			moveq #0, d0
			move.b d1, d0
			andi.b #$3F, d0				; Up Down Left Right B C
			lsl.b #2, d2
			andi.b #$C0, d2				; A, Start
			or.b d2, d0
			andi.b #$0F, d3
			bne ntc_mp_3b
			not.b d4
			andi.w #$0F, d4				; Z Y X Mode
			moveq #0, d1
			btst #2, d4
			beq ntc_mp_nx
			bset #8, d1					; X
ntc_mp_nx:
			btst #1, d4
			beq ntc_mp_ny
			bset #9, d1					; Y
ntc_mp_ny:
			btst #0, d4
			beq ntc_mp_nz
			bset #10, d1				; Z
ntc_mp_nz:
			btst #3, d4
			beq ntc_mp_nm
			bset #11, d1				; Mode
ntc_mp_nm:
			or.w d1, d0
ntc_mp_3b:
			rts

; an exception: its number and the PC on the console, then stop
ntc_md_ex2:	moveq #2, d7
			bra ntc_md_exg
ntc_md_ex3:	moveq #3, d7
ntc_md_exg:
			move.l 10(sp), d6			; bus / address error: the PC is further in
			bra ntc_md_exshow
ntc_md_ex4:	moveq #4, d7
			bra ntc_md_exn
ntc_md_ex5:	moveq #5, d7
			bra ntc_md_exn
ntc_md_ex6:	moveq #6, d7
			bra ntc_md_exn
ntc_md_ex7:	moveq #7, d7
			bra ntc_md_exn
ntc_md_ex8:	moveq #8, d7
			bra ntc_md_exn
ntc_md_ex9:	moveq #9, d7
			bra ntc_md_exn
ntc_md_ex10: moveq #10, d7
			bra ntc_md_exn
ntc_md_ex11: moveq #11, d7
			bra ntc_md_exn
ntc_md_exx:	moveq #0, d7
ntc_md_exn:
			move.l 2(sp), d6
ntc_md_exshow:
			move.w #$2700, sr
			move.l usp, a5				; the thread position
			jsr ntc_plat_newline
			lea ntc_md_extxt, a2
			bsr ntc_md_exstr
			move.l d7, d5
			moveq #2, d4
			bsr ntc_md_exhex
			lea ntc_md_expc, a2
			bsr ntc_md_exstr
			move.l d6, d5
			moveq #6, d4
			bsr ntc_md_exhex
			lea ntc_md_exsp, a2
			bsr ntc_md_exstr
			move.l a5, d5
			moveq #6, d4
			bsr ntc_md_exhex
ntc_md_exstop:
			bra ntc_md_exstop
ntc_md_exstr:
			moveq #0, d0
			move.b (a2)+, d0
			beq ntc_md_exse
			jsr ntc_plat_putc
			bra ntc_md_exstr
ntc_md_exse:
			rts
ntc_md_exhex:					; d5 = value, d4 = digits
			move.w d4, d3
			subq.w #1, d3
			lsl.w #2, d4
			ror.l d4, d5
ntc_md_exh1:
			rol.l #4, d5
			move.w d5, d0
			andi.w #$F, d0
			addi.b #'0', d0
			cmpi.b #'9'+1, d0
			bcs ntc_md_exh2
			addq.b #7, d0
ntc_md_exh2:
			jsr ntc_plat_putc
			dbra d3, ntc_md_exh1
			rts
ntc_md_extxt:	dc.b "68000 EXCEPTION ", 0
ntc_md_expc:	dc.b " PC ", 0
ntc_md_exsp:	dc.b " SP ", 0
			even

;## ntc_md_vdp
; VDP helpers on the real stack (jsr): keep d2-d7 / a2-a6
; ntc_md_vaddr: d0.w = VRAM address -> VDP_CTRL set to write there
ntc_md_vaddr:
			move.l d1, -(sp)
			moveq #0, d1
			move.w d0, d1
			andi.w #$3FFF, d1
			ori.w #$4000, d1
			swap d1
			move.w d0, d1
			rol.w #2, d1
			andi.w #3, d1
			move.l d1, VDP_CTRL
			move.l (sp)+, d1
			rts

;## ntc_md_loadfont ntc_md_vdp ntc_md_fontdata
; ntc_md_loadfont - the font into tiles d0 + 32 .. d0 + 126: pixels colour d1, the rest colour
; d2 (0 = clear). Real stack, keeps d2-d7 / a2-a6
ntc_md_loadfont:
			movem.l d2-d5/a0, -(sp)
			addi.w #32, d0
			lsl.w #5, d0
			bsr ntc_md_vaddr
			lea ntc_md_font, a0
			move.w #95*8-1, d5
ntc_lf_row:
			move.b (a0)+, d3
			moveq #0, d4
			swap d5
			move.w #8-1, d5
ntc_lf_bit:
			lsl.l #4, d4
			add.b d3, d3
			bcc ntc_lf_bg
			or.b d1, d4
			bra ntc_lf_nx
ntc_lf_bg:
			or.b d2, d4
ntc_lf_nx:
			dbra d5, ntc_lf_bit
			swap d5
			move.l d4, VDP_DATA
			dbra d5, ntc_lf_row
			movem.l (sp)+, d2-d5/a0
			rts

;## ntc_plat_data
;@ram
ntc_curx:		dc.b 0				; cursor column (0 based)
ntc_cury:		dc.b 0				; cursor row (0 based)
ntc_scols:		dc.b 40				; columns
ntc_srows:		dc.b 28				; rows
ntc_wrapped:	dc.b 0				; 1 = the last character wrapped to the next line
ntc_tattr:		dc.b $80			; the text cells' attribute (high byte): priority, palette 0
ntc_tbase:		dc.w 0				; added to a character for its tile (Vdp.TextFont: another font)
ntc_ticks:		dc.w 0				; frames since the start
ntc_vbl:		dc.w 0				; frames (ntc_plat_frame waits for it to move)
ntc_pad1:		dc.w 0				; pad 1's buttons now (bit 0 Up ... 7 Start, 8 X ... 11 Mode)
ntc_pad2:		dc.w 0
ntc_padseen:	dc.w 0				; pad 1 as Inkey last saw it (new presses only)
ntc_vhook:		dc.l 0				; a routine the frame interrupt runs (supervisor mode), 0 none
ntc_shadow:		ds.b 40*28			; the console's text
			even
;@rom

;## ntc_plat_screen ntc_plat_data ntc_data ntc_md_vdp ntc_md_logs
; ntc_plat_putc - d0.b = character: on plane A at the cursor, move on, a new
; line after the last column. Real stack, keeps d2-d7 / a2-a6
ntc_plat_putc:
			movem.l d0-d2/a0, -(sp)
		ifd NTC_MDLOG
			bsr ntc_md_log
		endif
			moveq #0, d1
			move.b ntc_cury, d1
			mulu.w #40, d1
			moveq #0, d2
			move.b ntc_curx, d2
			add.w d2, d1
			lea ntc_shadow, a0
			move.b d0, 0(a0, d1.w)
			bsr ntc_md_cell			; d0 = char, the cursor's cell
			addq.b #1, ntc_curx
			move.b ntc_curx, d0
			cmp.b ntc_scols, d0
			bcs ntc_pc_nowrap
			move.b #1, ntc_wrapped
			movem.l (sp)+, d0-d2/a0
			bra ntc_nl_do
ntc_pc_nowrap:
			clr.b ntc_wrapped
			movem.l (sp)+, d0-d2/a0
			rts

; the cell at the cursor gets character d0 (VRAM: plane A, 64 cells a row)
ntc_md_cell:
			movem.l d0-d1, -(sp)
			moveq #0, d1
			move.b ntc_cury, d1
			lsl.w #6, d1
			moveq #0, d0
			move.b ntc_curx, d0
			add.w d0, d1
			add.w d1, d1
			addi.w #$C000, d1
			move.w d1, d0
			bsr ntc_md_vaddr
			movem.l (sp)+, d0-d1
			move.l d1, -(sp)
			moveq #0, d1
			move.b ntc_tattr, d1
			lsl.w #8, d1
			move.b d0, d1
			add.w ntc_tbase, d1
			move.w d1, VDP_DATA
			move.l (sp)+, d1
			rts

; ntc_plat_newline - column 0, next row (scrolls at the bottom); nothing straight after a wrap
ntc_plat_newline:
		ifd NTC_MDLOG
			move.l d0, -(sp)
			moveq #10, d0
			bsr ntc_md_log
			move.l (sp)+, d0
		endif
			tst.b ntc_wrapped
			beq ntc_nl_do
			clr.b ntc_wrapped
			rts
ntc_nl_do:
			clr.b ntc_curx
			addq.b #1, ntc_cury
			move.b ntc_cury, d0
			cmp.b ntc_srows, d0
			bcs ntc_nl_e
			subq.b #1, ntc_cury
			bra ntc_md_scroll
ntc_nl_e:
			rts

; the text up a row: the shadow moved up, the last row cleared, plane A redrawn
ntc_md_scroll:
			movem.l d0-d3/a0-a1, -(sp)
			lea ntc_shadow, a0
			lea 40(a0), a1
			move.w #40*27-1, d0
ntc_sc_mv:
			move.b (a1)+, (a0)+
			dbra d0, ntc_sc_mv
			moveq #40-1, d0
ntc_sc_cl:
			move.b #' ', (a0)+
			dbra d0, ntc_sc_cl
			bsr ntc_md_redraw
			movem.l (sp)+, d0-d3/a0-a1
			rts

; plane A from the shadow (28 rows of 40)
ntc_md_redraw:
			movem.l d0-d3/a0, -(sp)
			lea ntc_shadow, a0
			moveq #0, d2				; row
			moveq #0, d3
			move.b ntc_tattr, d3
			lsl.w #8, d3
ntc_rd_row:
			move.w d2, d0
			lsl.w #7, d0
			addi.w #$C000, d0
			bsr ntc_md_vaddr
			moveq #40-1, d1
ntc_rd_col:
			moveq #0, d0
			move.b (a0)+, d0
			bne ntc_rd_ch
			moveq #' ', d0
ntc_rd_ch:
			or.w d3, d0
			add.w ntc_tbase, d0
			move.w d0, VDP_DATA
			dbra d1, ntc_rd_col
			addq.w #1, d2
			cmpi.w #28, d2
			bcs ntc_rd_row
			movem.l (sp)+, d0-d3/a0
			rts

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_backspace - back a column and clear it (not past the line's start)
ntc_plat_backspace:
			tst.b ntc_curx
			beq ntc_bs_e
			subq.b #1, ntc_curx
			move.l d0, -(sp)
			moveq #' ', d0
			bsr ntc_md_cell
			move.l (sp)+, d0
ntc_bs_e:
			rts

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_cls - clear the console, the cursor home
ntc_plat_cls:
			movem.l d0/a0, -(sp)
			lea ntc_shadow, a0
			move.w #40*28-1, d0
ntc_cls_lp:
			move.b #' ', (a0)+
			dbra d0, ntc_cls_lp
			clr.b ntc_curx
			clr.b ntc_cury
			clr.b ntc_wrapped
			bsr ntc_md_redraw
			movem.l (sp)+, d0/a0
			rts

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data ntc_plat_cls
; ntc_plat_mode - d0 = mode: one text mode here (40 x 28), so it clears the screen
ntc_plat_mode:
			bra ntc_plat_cls

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - d0 = column, d1 = row (1 based, kept on the screen)
ntc_plat_locate:
			subq.w #1, d0
			bpl ntc_lo_x0
			moveq #0, d0
ntc_lo_x0:
			cmpi.w #39, d0
			bls ntc_lo_x1
			moveq #39, d0
ntc_lo_x1:
			subq.w #1, d1
			bpl ntc_lo_y0
			moveq #0, d1
ntc_lo_y0:
			cmpi.w #27, d1
			bls ntc_lo_y1
			moveq #27, d1
ntc_lo_y1:
			move.b d0, ntc_curx
			move.b d1, ntc_cury
			clr.b ntc_wrapped
			rts

;## ntc_md_logs
		ifd NTC_MDLOG
; test builds (vasm -DNTC_MDLOG): what the console was given, at $FF0000 on (the
; harness reads it): characters, 10 for a new line. $FF6FFC: where the next goes
ntc_md_log:
			move.l a0, -(sp)
			movea.l $FF6FFC, a0
			cmpa.l #$FF0000, a0
			bcc ntc_lg_ok
			lea $FF0000, a0
ntc_lg_ok:
			cmpa.l #$FF6FF0, a0
			bcc ntc_lg_full
			move.b d0, (a0)+
			move.l a0, $FF6FFC
ntc_lg_full:
			movea.l (sp)+, a0
			rts
		endif

;## ntc_plat_key ntc_data ntc_plat_data ntc_plat_frame
; ntc_plat_scankey - d0 = the code of a button newly pressed on pad 1, or 0
ntc_plat_scankey:
			movem.l d1-d2/a0, -(sp)
			move.w ntc_pad1, d1
			move.w ntc_padseen, d2
			move.w d1, ntc_padseen
			not.w d2
			and.w d2, d1				; the new ones
			moveq #0, d0
			lea ntc_md_keys, a0
			moveq #0, d2
ntc_sk_lp:
			btst d2, d1
			bne ntc_sk_got
			addq.w #1, d2
			cmpi.w #12, d2
			bcs ntc_sk_lp
			bra ntc_sk_e
ntc_sk_got:
			move.b 0(a0, d2.w), d0
ntc_sk_e:
			movem.l (sp)+, d1-d2/a0
			rts
ntc_md_keys:	dc.b $F0, $F1, $F2, $F3, 'B', 'C', 'A', 13, 'X', 'Y', 'Z', 27
			even

; ntc_plat_getkey - wait for a button: d0 = its code
ntc_plat_getkey:
			bsr ntc_plat_scankey
			tst.b d0
			bne ntc_gk_e
			bsr ntc_plat_frame
			bra ntc_plat_getkey
ntc_gk_e:
			rts

;## ntc_plat_frame ntc_plat_data
; ntc_plat_frame - wait for the next frame interrupt (the start of the vertical blank)
ntc_plat_frame:
			move.l d0, -(sp)
			move.w ntc_vbl, d0
ntc_fr_lp:
			cmp.w ntc_vbl, d0
			beq ntc_fr_lp
			move.l (sp)+, d0
			rts

;## ntc_plat_ticks ntc_plat_data
; ntc_plat_ticks - d0.w = frames since the start (60 a second, 50 on a PAL machine)
ntc_plat_ticks:
			move.w ntc_ticks, d0
			rts

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - before the program stops: nothing to give back on a Mega Drive
ntc_plat_exit:
			rts

;## ntc_md_spr ntc_md_vdp ntc_data
; ------------------------------------------------------------
; the hardware sprites: a copy of the VDP's sprite table in RAM (80 x 8 bytes:
; y + 128 (0 = hidden), size, the cell value, x + 128); ntc_md_sprupd writes it
; to the VDP ($D800) with the links 0 -> 1 -> ... -> 79. On the thread: keywords.
; ------------------------------------------------------------
;@ram
ntc_sat:		ds.b 80*8
;@rom
; ntc_md_sprupd - the sprite table to the VDP (call it after Frame). Real stack
ntc_md_sprupd:
			movem.l d0-d2/a0, -(sp)
			move.w #$D800, d0
			bsr ntc_md_vaddr
			lea ntc_sat, a0
			moveq #1, d1				; the link
ntc_su_lp:
			move.w (a0)+, VDP_DATA		; y
			move.w (a0)+, d2			; size
			lsl.w #8, d2
			cmpi.w #80, d1
			bcc ntc_su_last
			move.b d1, d2
ntc_su_last:
			move.w d2, VDP_DATA			; size, link (the last links to 0)
			move.l (a0)+, VDP_DATA		; the cell value, x
			addq.w #1, d1
			cmpi.w #81, d1
			bcs ntc_su_lp
			movem.l (sp)+, d0-d2/a0
			rts

;## ntc_md_psg ntc_data
; ------------------------------------------------------------
; the PSG's 4 channels (3 tones, the noise) as sound effects that move on a frame
; at a time (ntc_md_psgupd, from Psg.Update): a period that slides and a volume
; that fades. A channel: active, period, slide, volume, frames, left (12 bytes)
; ------------------------------------------------------------
;@ram
ntc_psgch:		ds.b 4*12
;@rom
; ntc_md_psgout - a0 = the channel's state, d3 = its number: its period and volume to the PSG
ntc_md_psgout:
			move.w 2(a0), d0			; the period
			cmpi.w #3, d3
			beq ntc_po_noise
			move.w d3, d1
			lsl.b #5, d1
			ori.b #$80, d1
			move.w d0, d2
			andi.b #$0F, d2
			or.b d2, d1
			move.b d1, PSG_PORT
			lsr.w #4, d0
			andi.b #$3F, d0
			move.b d0, PSG_PORT
			bra ntc_po_vol
ntc_po_noise:
			andi.b #7, d0
			ori.b #$E0, d0
			move.b d0, PSG_PORT
ntc_po_vol:
			; the volume now: volume * left / frames (frames 0: the volume)
			move.w 6(a0), d0
			move.w 8(a0), d1
			beq ntc_po_v
			mulu.w 10(a0), d0
			divu.w d1, d0
ntc_po_v:
			moveq #15, d1
			sub.w d0, d1				; the attenuation
			bcc ntc_po_v2
			moveq #0, d1
ntc_po_v2:
			move.w d3, d0
			lsl.b #5, d0
			ori.b #$90, d0
			andi.b #$0F, d1
			or.b d1, d0
			move.b d0, PSG_PORT
			rts

; ntc_md_psgoff - d3 = the channel: silent, not active
ntc_md_psgoff:
			move.w d3, d0
			mulu.w #12, d0
			lea ntc_psgch, a0
			clr.w 0(a0, d0.w)
			move.w d3, d0
			lsl.b #5, d0
			ori.b #$9F, d0
			move.b d0, PSG_PORT
			rts

; ntc_md_psgupd - every active channel a frame on
ntc_md_psgupd:
			movem.l d0-d3/a0, -(sp)
			moveq #0, d3
			lea ntc_psgch, a0
ntc_pu_lp:
			tst.w (a0)
			beq ntc_pu_next
			move.w 8(a0), d0			; frames: 0 = held until stopped
			beq ntc_pu_slide
			subq.w #1, 10(a0)
			bgt ntc_pu_slide
			move.l a0, -(sp)
			bsr ntc_md_psgoff
			movea.l (sp)+, a0
			bra ntc_pu_next
ntc_pu_slide:
			move.w 4(a0), d0
			add.w d0, 2(a0)
			move.w 2(a0), d0
			cmpi.w #3, d3
			beq ntc_pu_out
			cmpi.w #1, d0
			bge ntc_pu_lo
			move.w #1, 2(a0)
ntc_pu_lo:
			cmpi.w #1023, d0
			ble ntc_pu_out
			move.w #1023, 2(a0)
ntc_pu_out:
			bsr ntc_md_psgout
ntc_pu_next:
			lea 12(a0), a0
			addq.w #1, d3
			cmpi.w #4, d3
			bcs ntc_pu_lp
			movem.l (sp)+, d0-d3/a0
			rts

;## ntc_md_fontdata
ntc_md_font:
			dc.b $00, $00, $00, $00, $00, $00, $00, $00		; 32
			dc.b $18, $3C, $3C, $18, $18, $00, $18, $00		; 33
			dc.b $6C, $6C, $00, $00, $00, $00, $00, $00		; 34
			dc.b $6C, $6C, $FE, $6C, $FE, $6C, $6C, $00		; 35
			dc.b $30, $7C, $C0, $78, $0C, $F8, $30, $00		; 36
			dc.b $00, $C6, $CC, $18, $30, $66, $C6, $00		; 37
			dc.b $38, $6C, $38, $76, $DC, $CC, $76, $00		; 38
			dc.b $60, $60, $C0, $00, $00, $00, $00, $00		; 39
			dc.b $18, $30, $60, $60, $60, $30, $18, $00		; 40
			dc.b $60, $30, $18, $18, $18, $30, $60, $00		; 41
			dc.b $00, $66, $3C, $FF, $3C, $66, $00, $00		; 42
			dc.b $00, $30, $30, $FC, $30, $30, $00, $00		; 43
			dc.b $00, $00, $00, $00, $00, $30, $30, $60		; 44
			dc.b $00, $00, $00, $FC, $00, $00, $00, $00		; 45
			dc.b $00, $00, $00, $00, $00, $30, $30, $00		; 46
			dc.b $06, $0C, $18, $30, $60, $C0, $80, $00		; 47
			dc.b $7C, $C6, $CE, $DE, $F6, $E6, $7C, $00		; 48
			dc.b $30, $70, $30, $30, $30, $30, $FC, $00		; 49
			dc.b $78, $CC, $0C, $38, $60, $CC, $FC, $00		; 50
			dc.b $78, $CC, $0C, $38, $0C, $CC, $78, $00		; 51
			dc.b $1C, $3C, $6C, $CC, $FE, $0C, $1E, $00		; 52
			dc.b $FC, $C0, $F8, $0C, $0C, $CC, $78, $00		; 53
			dc.b $38, $60, $C0, $F8, $CC, $CC, $78, $00		; 54
			dc.b $FC, $CC, $0C, $18, $30, $30, $30, $00		; 55
			dc.b $78, $CC, $CC, $78, $CC, $CC, $78, $00		; 56
			dc.b $78, $CC, $CC, $7C, $0C, $18, $70, $00		; 57
			dc.b $00, $30, $30, $00, $00, $30, $30, $00		; 58
			dc.b $00, $30, $30, $00, $00, $30, $30, $60		; 59
			dc.b $18, $30, $60, $C0, $60, $30, $18, $00		; 60
			dc.b $00, $00, $FC, $00, $00, $FC, $00, $00		; 61
			dc.b $60, $30, $18, $0C, $18, $30, $60, $00		; 62
			dc.b $78, $CC, $0C, $18, $30, $00, $30, $00		; 63
			dc.b $7C, $C6, $DE, $DE, $DE, $C0, $78, $00		; 64
			dc.b $30, $78, $CC, $CC, $FC, $CC, $CC, $00		; 65
			dc.b $FC, $66, $66, $7C, $66, $66, $FC, $00		; 66
			dc.b $3C, $66, $C0, $C0, $C0, $66, $3C, $00		; 67
			dc.b $F8, $6C, $66, $66, $66, $6C, $F8, $00		; 68
			dc.b $FE, $62, $68, $78, $68, $62, $FE, $00		; 69
			dc.b $FE, $62, $68, $78, $68, $60, $F0, $00		; 70
			dc.b $3C, $66, $C0, $C0, $CE, $66, $3E, $00		; 71
			dc.b $CC, $CC, $CC, $FC, $CC, $CC, $CC, $00		; 72
			dc.b $78, $30, $30, $30, $30, $30, $78, $00		; 73
			dc.b $1E, $0C, $0C, $0C, $CC, $CC, $78, $00		; 74
			dc.b $E6, $66, $6C, $78, $6C, $66, $E6, $00		; 75
			dc.b $F0, $60, $60, $60, $62, $66, $FE, $00		; 76
			dc.b $C6, $EE, $FE, $FE, $D6, $C6, $C6, $00		; 77
			dc.b $C6, $E6, $F6, $DE, $CE, $C6, $C6, $00		; 78
			dc.b $38, $6C, $C6, $C6, $C6, $6C, $38, $00		; 79
			dc.b $FC, $66, $66, $7C, $60, $60, $F0, $00		; 80
			dc.b $78, $CC, $CC, $CC, $DC, $78, $1C, $00		; 81
			dc.b $FC, $66, $66, $7C, $6C, $66, $E6, $00		; 82
			dc.b $78, $CC, $E0, $70, $1C, $CC, $78, $00		; 83
			dc.b $FC, $B4, $30, $30, $30, $30, $78, $00		; 84
			dc.b $CC, $CC, $CC, $CC, $CC, $CC, $FC, $00		; 85
			dc.b $CC, $CC, $CC, $CC, $CC, $78, $30, $00		; 86
			dc.b $C6, $C6, $C6, $D6, $FE, $EE, $C6, $00		; 87
			dc.b $C6, $C6, $6C, $38, $38, $6C, $C6, $00		; 88
			dc.b $CC, $CC, $CC, $78, $30, $30, $78, $00		; 89
			dc.b $FE, $C6, $8C, $18, $32, $66, $FE, $00		; 90
			dc.b $78, $60, $60, $60, $60, $60, $78, $00		; 91
			dc.b $C0, $60, $30, $18, $0C, $06, $02, $00		; 92
			dc.b $78, $18, $18, $18, $18, $18, $78, $00		; 93
			dc.b $10, $38, $6C, $C6, $00, $00, $00, $00		; 94
			dc.b $00, $00, $00, $00, $00, $00, $00, $FF		; 95
			dc.b $30, $30, $18, $00, $00, $00, $00, $00		; 96
			dc.b $00, $00, $78, $0C, $7C, $CC, $76, $00		; 97
			dc.b $E0, $60, $60, $7C, $66, $66, $DC, $00		; 98
			dc.b $00, $00, $78, $CC, $C0, $CC, $78, $00		; 99
			dc.b $1C, $0C, $0C, $7C, $CC, $CC, $76, $00		; 100
			dc.b $00, $00, $78, $CC, $FC, $C0, $78, $00		; 101
			dc.b $38, $6C, $60, $F0, $60, $60, $F0, $00		; 102
			dc.b $00, $00, $76, $CC, $CC, $7C, $0C, $F8		; 103
			dc.b $E0, $60, $6C, $76, $66, $66, $E6, $00		; 104
			dc.b $30, $00, $70, $30, $30, $30, $78, $00		; 105
			dc.b $0C, $00, $0C, $0C, $0C, $CC, $CC, $78		; 106
			dc.b $E0, $60, $66, $6C, $78, $6C, $E6, $00		; 107
			dc.b $70, $30, $30, $30, $30, $30, $78, $00		; 108
			dc.b $00, $00, $CC, $FE, $FE, $D6, $C6, $00		; 109
			dc.b $00, $00, $F8, $CC, $CC, $CC, $CC, $00		; 110
			dc.b $00, $00, $78, $CC, $CC, $CC, $78, $00		; 111
			dc.b $00, $00, $DC, $66, $66, $7C, $60, $F0		; 112
			dc.b $00, $00, $76, $CC, $CC, $7C, $0C, $1E		; 113
			dc.b $00, $00, $DC, $76, $66, $60, $F0, $00		; 114
			dc.b $00, $00, $7C, $C0, $78, $0C, $F8, $00		; 115
			dc.b $10, $30, $7C, $30, $30, $34, $18, $00		; 116
			dc.b $00, $00, $CC, $CC, $CC, $CC, $76, $00		; 117
			dc.b $00, $00, $CC, $CC, $CC, $78, $30, $00		; 118
			dc.b $00, $00, $C6, $D6, $FE, $FE, $6C, $00		; 119
			dc.b $00, $00, $C6, $6C, $38, $6C, $C6, $00		; 120
			dc.b $00, $00, $CC, $CC, $CC, $7C, $0C, $F8		; 121
			dc.b $00, $00, $FC, $98, $30, $64, $FC, $00		; 122
			dc.b $1C, $30, $30, $E0, $30, $30, $1C, $00		; 123
			dc.b $18, $18, $18, $00, $18, $18, $18, $00		; 124
			dc.b $E0, $30, $30, $1C, $30, $30, $E0, $00		; 125
			dc.b $76, $DC, $00, $00, $00, $00, $00, $00		; 126
			even

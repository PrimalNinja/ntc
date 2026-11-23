; ============================================================
; NTC Platform - SNK Neo Geo (68000, cartridge: AES / MVS)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A cartridge's P ROM: the 68000's vectors at 0 (the cartridge's: the BIOS
; switches them in), the Neo Geo header at $100, then the program. The BIOS
; starts the machine and calls the cartridge's USER routine ($122); NTC's
; takes request 0 (start-up) and 1 (the eye-catcher) back to the BIOS, and
; runs the program on request 2 (the game) or 3 (an MVS's title): in USER
; mode with A7 (the user stack pointer) as the thread. The VBlank interrupt
; (level 1) runs in supervisor mode on the BIOS's stack, so it never touches
; the thread and interrupts stay on all the time. (Until BIOS_SYSTEM_MODE
; bit 7 says the game is running, VBlank goes to the BIOS's own handler.)
;
; Memory (the 68000's 64K of work RAM from $100000, the same 64K again every 64K to $1FFFFF;
; the BIOS keeps $10F300 on). NTC's 16 bit addresses (an Integer's PEEK / POKE, VarPtr, the
; library's own) are this RAM's: sign extended, then $110000 added (;@a16), a mirror of it:
;   $0000-$7FFF: $110000-$117FFF, $8000-$FFFF: $108000-$10FFFF
;   $100000-$10BFFF the program's variables, the library's, then its arrays
;   $10C000-$10DFFF free (NTC_NGLOG test builds: the console transcript)
;   $10E000-$10E7FF the real stack (ntc_csp: the library's jsr calls)
;   $10E800-$10F2FF free (the supervisor stack is the BIOS's, below $10F300)
;
; The console is the fix layer: 40 x 28 cells (the fix map's rows 2-29: the
; ones a TV shows), character c is fix tile c + ntc_tbase in palette ntc_tattr
; >> 4 (the cartridge's S ROM: test/ngbuild.js puts the font at tiles 32-126,
; pixels colour 1; palette 0 colour 1 is white). Sprites start hidden (every
; sprite 0 tall). Palette entry $0FFF (the backdrop) is black.
;
; The pads are read once a frame in the interrupt:
;   ntc_pad1 / ntc_pad2: bit 0 Up, 1 Down, 2 Left, 3 Right, 4 A, 5 B, 6 C,
;   7 D, 8 Start, 9 Select (1 = held)
; Inkey / Input use pad 1: Start = 13, A B C D = "A" "B" "C" "D", Select = 27,
; Up Down Left Right = &HF0 &HF1 &HF2 &HF3 (as the CPC's cursor keys).
;
; Sound: the Z80 runs the cartridge's M1 ROM (NTC's driver: asm/neogeo_sound_z80.asm).
; ntc_ng_snd sends it a byte through REG_SOUND and waits for its answer (each
; byte it takes, it counts, and answers with the count).
; ============================================================
;@name     SNK Neo Geo (68000)
;@cpu      68000
;@org      0
;@ramorg   $100000
;@ramend   $10C000
;@a16     $110000
;@text     byte
;@scrinit  0
;@irq      0
;@cols     40
;@rows     28
; ============================================================

;## ntc_md_vectors ntc_ng_boot
; the cartridge's vectors (the BIOS's routines for the exceptions, as every cartridge has them)
; and the Neo Geo header (the compiler puts this first, at 0)
			dc.l $0010F300				; the supervisor stack
			dc.l $00C00402				; reset: the BIOS
			dc.l $00C00408, $00C0040E, $00C00414, $00C0041A	; bus, address, illegal, zero divide
			dc.l $00C0041A, $00C0041A, $00C0041A, $00C00420	; CHK, TRAPV, privilege, trace
			dc.l $00C00426, $00C00426					; line 1010, 1111
			dcb.l 3, $FFFFFFFF			; 12-14
			dc.l $00C0042C				; 15 uninitialised interrupt
			dcb.l 8, $FFFFFFFF			; 16-23
			dc.l $00C00432				; 24 spurious
			dc.l ntc_ng_vbl				; 25 level 1: VBlank
			dc.l ntc_ng_timer			; 26 level 2: the timer
			dc.l ntc_ng_rte				; 27 level 3
			dcb.l 4, ntc_ng_rte			; 28-31
			dcb.l 32, $FFFFFFFF			; 32-63
; the header ($100): test/ngbuild.js puts in the NGH number and the name
			dc.b "NEO-GEO", 0
			dc.w $0C1C					; $108 the NGH number (3100: not $999, which the emulators take for V-Liner)
			dc.l $00100000				; $10A the program's size
			dc.l $0010E800				; $10E an MVS's backup RAM (none used)
			dc.w 0						; $112 its size
			dc.b 1						; $114 the eye-catcher: the game's (USER request 1, which goes straight back)
			dc.b 0						; $115 its first tile
			dc.l ntc_ng_dip, ntc_ng_dip, ntc_ng_dip	; $116 the soft DIPs: Japan, the US, Europe
			dc.w $4EF9					; $122 USER: jmp abs.l (written out: 6 bytes each, at
			dc.l ntc_ng_user			;      the header's fixed places)
			dc.w $4EF9					; $128 PLAYER_START
			dc.l ntc_ng_rts
			dc.w $4EF9					; $12E DEMO_END
			dc.l ntc_ng_rts
			dc.w $4EF9					; $134 COIN_SOUND
			dc.l ntc_ng_rts
			dcb.b 70, $FF				; $13A
			dc.w 0						; $180
			dc.l ntc_ng_scode			; $182 the security code
ntc_ng_scode:
			dc.w $7600, $4A6D, $0A14, $6600, $003C, $206D, $0A04, $3E2D
			dc.w $0A08, $13C0, $0030, $0001, $3210, $0C01, $00FF, $671A
			dc.w $3028, $0002, $B02D, $0ACE, $6610, $3028, $0004, $B02D
			dc.w $0ACF, $6606, $B22D, $0AD0, $6708, $5088, $51CF, $FFD4
			dc.w $3607, $4E75, $206D, $0A04, $3E2D, $0A08, $3210, $E049
			dc.w $0C01, $00FF, $671A, $3010, $B02D, $0ACE, $6612, $3028
			dc.w $0002, $E048, $B02D, $0ACF, $6606, $B22D, $0AD0, $6708
			dc.w $5888, $51CF, $FFD8, $3607, $4E75
ntc_ng_dip:	dc.b "NTC BASIC       "		; the name the BIOS shows (16)
			dc.b $FF, $FF, $FF, $FF		; no time DIPs
			dc.b $FF, $FF				; no number DIPs
			dcb.b 10, 0					; no choice DIPs
			even

;## ntc_ng_boot ntc_plat_data ntc_data ntc_plat_screen ntc_ng_snd
; ------------------------------------------------------------
; USER (the BIOS calls it, supervisor mode): request 0 / 1 back to the BIOS;
; 2 / 3: RAM cleared and the RAM block copied from the ROM, the screen, the
; sound driver's count; then user mode on the real stack and into ntc_start
; ------------------------------------------------------------
REG_P1CNT		equ $300000
REG_WATCHDOG	equ $300001
REG_SOUND		equ $320000
REG_P2CNT		equ $340000
REG_STATUSB		equ $380000
REG_SWPROM		equ $3A0013
REG_CRTFIX		equ $3A001B
REG_PALBANK0	equ $3A001F
REG_VRAMADDR	equ $3C0000
REG_VRAMRW		equ $3C0002
REG_VRAMMOD		equ $3C0004
REG_LSPCMODE	equ $3C0006
REG_IRQACK		equ $3C000C
NG_PALRAM		equ $400000
BIOS_SYSTEM_MODE	equ $10FD80
BIOS_USER_REQUEST	equ $10FDAE
NG_FIXMAP		equ $7000
NTC_USTACK		equ $0010E800			; the real stack's top
ntc_ng_user:
			move.b d0, REG_WATCHDOG
			move.b BIOS_USER_REQUEST, d0
			cmpi.b #2, d0
			bcc ntc_ng_game
			jmp $00C00444				; SYSTEM_RETURN
ntc_ng_rts:
			rts
ntc_ng_game:
			move.w #$2700, sr
			move.w #7, REG_IRQACK
			move.b d0, REG_WATCHDOG
			lea $00100000, a0			; RAM cleared, up to the real stack's top
			move.w #($E800/4)-1, d0
ntc_nb_clr:
			clr.l (a0)+
			dbra d0, ntc_nb_clr
			move.b d0, REG_WATCHDOG
			lea ntc_romend, a0			; the RAM block's first image, from the ROM
			lea ntc_ram, a1
			move.l #ntc_ramend-ntc_ram, d0
			beq ntc_nb_nodata
ntc_nb_cp:
			move.b (a0)+, (a1)+
			subq.l #1, d0
			bne ntc_nb_cp
ntc_nb_nodata:
			move.b d0, REG_WATCHDOG
			move.b #1, REG_CRTFIX		; the cartridge's fix tiles
			move.b d0, REG_PALBANK0
			move.w #0, REG_LSPCMODE		; no auto-animation timer
			move.w #1, REG_VRAMMOD
			move.w #$8000, REG_VRAMADDR	; every sprite full size
			move.w #$200-1, d0
ntc_nb_scb2:
			move.w #$0FFF, REG_VRAMRW
			dbra d0, ntc_nb_scb2
			move.w #$8200, REG_VRAMADDR	; and hidden (0 tall)
			move.w #$200-1, d0
ntc_nb_scb3:
			move.w #0, REG_VRAMRW
			dbra d0, ntc_nb_scb3
			move.w #$8400, REG_VRAMADDR	; x 0
			move.w #$200-1, d0
ntc_nb_scb4:
			move.w #0, REG_VRAMRW
			dbra d0, ntc_nb_scb4
			move.b d0, REG_WATCHDOG
			lea NG_PALRAM, a0			; the palettes: black; palette 0 colour 1 white
			move.w #$2000/4-1, d0
ntc_nb_pal:
			move.l #$80008000, (a0)+
			dbra d0, ntc_nb_pal
			move.w #$7FFF, NG_PALRAM+2
			move.b d0, REG_WATCHDOG
			move.b #40, ntc_scols
			move.b #28, ntc_srows
			move.b #$00, ntc_tattr
			jsr ntc_plat_cls
			move.b REG_SOUND, ntc_ngseq	; the sound driver's count so far
			move.l #NTC_USTACK, a0
			move.l a0, usp
			move.w #$0000, sr			; user mode, the interrupts on: A7 is now the user stack
			jmp ntc_start

; ------------------------------------------------------------
; interrupts (supervisor mode)
; ------------------------------------------------------------
; VBlank: until the game runs it is the BIOS's; then acknowledged, the
; watchdog kicked, counted, the pads read, the frame hook run
ntc_ng_vbl:
			btst #7, BIOS_SYSTEM_MODE
			bne ntc_nv_game
			jmp $00C00438				; SYSTEM_INT1
ntc_nv_game:
			move.w #4, REG_IRQACK
			move.b d0, REG_WATCHDOG
			movem.l d0-d4/a0-a1, -(sp)
			addq.w #1, ntc_ticks
			addq.w #1, ntc_vbl
			move.b REG_STATUSB, d2
			not.b d2
			move.b REG_P1CNT, d0
			not.b d0
			andi.w #$FF, d0
			btst #0, d2
			beq ntc_nv_s1
			bset #8, d0					; Start
ntc_nv_s1:
			btst #1, d2
			beq ntc_nv_e1
			bset #9, d0					; Select
ntc_nv_e1:
			move.w d0, ntc_pad1
			move.b REG_P2CNT, d0
			not.b d0
			andi.w #$FF, d0
			btst #2, d2
			beq ntc_nv_s2
			bset #8, d0
ntc_nv_s2:
			btst #3, d2
			beq ntc_nv_e2
			bset #9, d0
ntc_nv_e2:
			move.w d0, ntc_pad2
			move.l ntc_vhook, d0
			beq ntc_nv_nohook
			movea.l d0, a0
			jsr (a0)					; (keeps every register but d0-d4 / a0-a1)
ntc_nv_nohook:
			movem.l (sp)+, d0-d4/a0-a1
ntc_ng_rte:
			rte
ntc_ng_timer:
			move.w #2, REG_IRQACK
			rte

;## ntc_ng_snd ntc_plat_data
; ntc_ng_snd - d0.b = a byte for the Z80's sound driver: sent, and its answer waited for (the
; driver answers each byte with its count of them; a dead or busy Z80 is given up on after a
; while). Real stack, keeps every register
ntc_ng_snd:
			movem.l d0-d1, -(sp)
			move.b d0, REG_SOUND
			move.b ntc_ngseq, d0
			addq.b #1, d0
			move.w #4000, d1
ntc_ns_wait:
			cmp.b REG_SOUND, d0
			beq ntc_ns_ok
			dbra d1, ntc_ns_wait
			move.b REG_SOUND, d0		; no answer: take what it says now
ntc_ns_ok:
			move.b d0, ntc_ngseq
			movem.l (sp)+, d0-d1
			rts

;## ntc_plat_data
;@ram
ntc_curx:		dc.b 0				; cursor column (0 based)
ntc_cury:		dc.b 0				; cursor row (0 based)
ntc_scols:		dc.b 40				; columns
ntc_srows:		dc.b 28				; rows
ntc_wrapped:	dc.b 0				; 1 = the last character wrapped to the next line
ntc_tattr:		dc.b $00			; the text cells' palette (high 4 bits)
ntc_ngseq:		dc.b 0				; the sound driver's count of the bytes it has taken
				dc.b 0
ntc_tbase:		dc.w 0				; added to a character for its fix tile (another font)
ntc_ticks:		dc.w 0				; frames since the start
ntc_vbl:		dc.w 0				; frames (ntc_plat_frame waits for it to move)
ntc_pad1:		dc.w 0				; pad 1's buttons now (bit 0 Up ... 7 D, 8 Start, 9 Select)
ntc_pad2:		dc.w 0
ntc_padseen:	dc.w 0				; pad 1 as Inkey last saw it (new presses only)
ntc_vhook:		dc.l 0				; a routine the VBlank interrupt runs (supervisor mode), 0 none
ntc_shadow:		ds.b 40*28			; the console's text
			even
;@rom

;## ntc_plat_screen ntc_plat_data ntc_data ntc_ng_logs
; ntc_plat_putc - d0.b = character: in the fix layer at the cursor, move on, a
; new line after the last column. Real stack, keeps d2-d7 / a2-a6
ntc_plat_putc:
			movem.l d0-d2/a0, -(sp)
		ifd NTC_NGLOG
			bsr ntc_ng_log
		endif
			moveq #0, d1
			move.b ntc_cury, d1
			mulu.w #40, d1
			moveq #0, d2
			move.b ntc_curx, d2
			add.w d2, d1
			lea ntc_shadow, a0
			move.b d0, 0(a0, d1.w)
			bsr ntc_ng_cell			; d0 = char, the cursor's cell
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

; the cell at the cursor gets character d0 (the fix map: 32 cells a column, the text from row 2)
ntc_ng_cell:
			movem.l d0-d1, -(sp)
			moveq #0, d1
			move.b ntc_curx, d1
			lsl.w #5, d1
			moveq #2, d0
			add.b ntc_cury, d0
			add.w d0, d1
			addi.w #NG_FIXMAP, d1
			move.w d1, REG_VRAMADDR
			movem.l (sp)+, d0-d1
			move.l d1, -(sp)
			moveq #0, d1
			move.b ntc_tattr, d1
			lsl.w #8, d1
			move.b d0, d1
			add.w ntc_tbase, d1
			move.w d1, REG_VRAMRW
			move.l (sp)+, d1
			rts

; ntc_plat_newline - column 0, next row (scrolls at the bottom); nothing straight after a wrap
ntc_plat_newline:
		ifd NTC_NGLOG
			move.l d0, -(sp)
			moveq #10, d0
			bsr ntc_ng_log
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
			bra ntc_ng_scroll
ntc_nl_e:
			rts

; the text up a row: the shadow moved up, the last row cleared, the fix layer redrawn
ntc_ng_scroll:
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
			bsr ntc_ng_redraw
			movem.l (sp)+, d0-d3/a0-a1
			rts

; the fix layer from the shadow (28 rows of 40): a column at a time (the fix map runs down)
ntc_ng_redraw:
			movem.l d0-d3/a0, -(sp)
			move.w #32, REG_VRAMMOD
			moveq #0, d2				; row
			moveq #0, d3
			move.b ntc_tattr, d3
			lsl.w #8, d3
ntc_rd_row:
			move.w d2, d0
			addi.w #NG_FIXMAP+2, d0
			move.w d0, REG_VRAMADDR
			lea ntc_shadow, a0
			move.w d2, d0
			mulu.w #40, d0
			adda.w d0, a0
			moveq #40-1, d1
ntc_rd_col:
			moveq #0, d0
			move.b (a0)+, d0
			bne ntc_rd_ch
			moveq #' ', d0
ntc_rd_ch:
			or.w d3, d0
			add.w ntc_tbase, d0
			move.w d0, REG_VRAMRW
			dbra d1, ntc_rd_col
			addq.w #1, d2
			cmpi.w #28, d2
			bcs ntc_rd_row
			move.w #1, REG_VRAMMOD
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
			bsr ntc_ng_cell
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
			bsr ntc_ng_redraw
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

;## ntc_ng_logs
		ifd NTC_NGLOG
; test builds (vasm -DNTC_NGLOG): what the console was given, at $10C000 on (the
; harness reads it): characters, 10 for a new line. $10DFFC: where the next goes
ntc_ng_log:
			move.l a0, -(sp)
			movea.l $0010DFFC, a0
			cmpa.l #$0010C000, a0
			bcc ntc_lg_ok
			lea $0010C000, a0
ntc_lg_ok:
			cmpa.l #$0010DFF0, a0
			bcc ntc_lg_full
			move.b d0, (a0)+
			move.l a0, $0010DFFC
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
			lea ntc_ng_keys, a0
			moveq #0, d2
ntc_sk_lp:
			btst d2, d1
			bne ntc_sk_got
			addq.w #1, d2
			cmpi.w #10, d2
			bcs ntc_sk_lp
			bra ntc_sk_e
ntc_sk_got:
			move.b 0(a0, d2.w), d0
ntc_sk_e:
			movem.l (sp)+, d1-d2/a0
			rts
ntc_ng_keys:	dc.b $F0, $F1, $F2, $F3, 'A', 'B', 'C', 'D', 13, 27
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
; ntc_plat_frame - wait for the next VBlank interrupt
ntc_plat_frame:
			move.l d0, -(sp)
			move.w ntc_vbl, d0
ntc_fr_lp:
			cmp.w ntc_vbl, d0
			beq ntc_fr_lp
			move.l (sp)+, d0
			rts

;## ntc_plat_ticks ntc_plat_data
; ntc_plat_ticks - d0.w = frames since the start (59.19 a second)
ntc_plat_ticks:
			move.w ntc_ticks, d0
			rts

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - before the program stops: nothing to give back (the watchdog is kicked by the
; VBlank interrupt, so a stopped program sits still rather than resetting)
ntc_plat_exit:
			rts

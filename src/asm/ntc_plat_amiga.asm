; ============================================================
; NTC Platform - Commodore Amiga 500 (68000), a disc that boots itself
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The program is a floppy image (.ADF: 80 tracks, 2 sides, 11 sectors of 512
; bytes). Kickstart reads the disc's boot block and runs it; the boot block
; reads the program with the ROM's disc driver, then takes the machine: the
; operating system is switched off for good and never used again. From there
; the program has the whole Amiga and works the hardware itself (the custom
; chips, the CIAs, the disc drives).
;
; The program runs in USER mode with A7 (the user stack pointer) as the
; thread; the interrupts run in supervisor mode on the supervisor stack, so
; they never touch the thread and stay on all the time (as on the X68000).
;
; Memory (chip RAM; 512K, 1 MB or 2 MB of it - found at the start):
;   $000000-$0003FF the 68000's vectors
;   $000400-$007FFF the program's variables, the library's, then its arrays
;                   (their addresses are 16 bits: VarPtr, Peek, descriptors)
;   $008000-$00BFFF the real stack (ntc_csp: the library's jsr calls), top down
;   $00C000-$00FFFF the supervisor stack (the interrupts), top down
;   $010000-        the program: start, threads, keywords, strings
;   after it        the chip pool, to the top of chip RAM: the console's screen
;                   (20K) first, then the Memory class's blocks
;   other RAM       (a trapdoor's "slow" 512K at $C00000, "fast" RAM in the side
;                   slot: up to 8 MB) is found at the start too: the Memory class's
;                   other pool
;   NTC_AMILOG test builds: the console's transcript from $070000
;
; The disc: sectors 0-1 the boot block, then the variables' first image and the
; program (this file, as vasm writes it); after that the files the Loader class
; reads (test/amigabuild.js lays them out and writes their list).
;
; The screen: one bitplane, 640 x 256 (PAL; 640 x 200 on an NTSC machine): 80 x 32
; characters (80 x 25), NTC's own font, white on blue. Keys: the keyboard through
; CIA-A (US layout); Inkey / Input give the key's character; the cursor keys are
; &HF0 &HF1 &HF2 &HF3 (up, down, left, right, as the CPC's), Return 13, ESC 27,
; backspace 8, Del 127.
;
; RUN: on the PUAE emulator with its built-in Kickstart replacement (AROS)
; (test/amigarun.py). Not on Commodore's Kickstart, not on a real Amiga.
; ============================================================
;@name     Commodore Amiga 500 (68000, boot disc)
;@cpu      68000
;@org      $0000
;@ramorg   $0400
;@ramend   $8000
;@text     byte
;@scrinit  0
;@irq      0
;@cols     80
;@rows     32
; ============================================================

;## ntc_md_vectors ntc_ami_boot
; (the 68000 backend's name for "what comes first": here the boot block, the disc's first two
; sectors. It is assembled at 0 but runs wherever Kickstart put it: every address in it is
; relative. The disc is the assembler's file: vasm -Fbin -coalesced writes the parts in address
; order, so it holds this block ($0000), the variables' first image ($0400), then the program's
; code ($10000). test/amigabuild.js fills in the block's checksum.)
;
; Kickstart calls it with a6 = exec's base and a1 = the disc driver's request, the system alive.
; It notes what memory the machine has, reads the rest of the program into memory the system
; lends it, switches the system off (supervisor mode, no interrupts, no DMA), moves the program
; to where it runs and jumps to it.
NTC_AMICODE	equ $10000				; where the program runs
NTC_USTACK	equ $C000				; the real stack's top (user mode)
NTC_AMISSP	equ $10000				; the supervisor stack's top
NTC_AMIIMG	equ (ntc_romend-NTC_AMICODE)+(ntc_ramend-ntc_ram)	; the bytes after the boot block
NTC_AMISEC	equ (NTC_AMIIMG+511)&$FFFFFE00						; ... in whole sectors
			dc.b "DOS", 0
			dc.l 0						; the checksum (amigabuild.js)
			dc.l 880					; the root block (not used: there is no file system)
ntc_ami_bb:
			movea.l a1, a5				; the disc driver's request
			move.l $3E(a6), d7			; exec: MaxLocMem - the top of chip RAM
			moveq #0, d6
			move.b 530(a6), d6			; exec: VBlankFrequency - 50 (PAL) or 60 (NTSC)
			; the other memory: the first two blocks in exec's list that are not chip RAM
			suba.l a3, a3				; block 1: a3 = its start, d3 = its end
			suba.l a4, a4				; block 2: a4, d4
			moveq #0, d3
			moveq #0, d4
			movea.l 322(a6), a0			; exec: MemList's first node
ntc_bb_walk:
			tst.l (a0)
			beq ntc_bb_walked			; (the list's tail)
			btst #1, 15(a0)				; mh_Attributes: MEMF_CHIP
			beq ntc_bb_other
			cmp.l 24(a0), d7			; chip RAM: its top is the highest any block of it reaches
			bcc ntc_bb_next
			move.l 24(a0), d7
			bra ntc_bb_next
ntc_bb_other:
			; real memory is where an Amiga 500 can have it: $200000-$9FFFFF (the side slot's fast
			; RAM) or $C00000-$DBFFFF (the trapdoor's slow RAM). (A ROM's own block is not.)
			move.l a0, d0
			move.l 24(a0), d1			; mh_Upper
			cmp.l d0, d1
			bls ntc_bb_next
			cmpi.l #$200000, d0
			bcs ntc_bb_next
			cmpi.l #$A00000, d0
			bcc ntc_bb_slow
			cmpi.l #$A00000, d1
			bhi ntc_bb_next
			bra ntc_bb_take
ntc_bb_slow:
			cmpi.l #$C00000, d0
			bcs ntc_bb_next
			cmpi.l #$DC0000, d1
			bhi ntc_bb_next
ntc_bb_take:
			move.l a3, d0
			bne ntc_bb_second
			movea.l a0, a3
			move.l 24(a0), d3			; mh_Upper
			bra ntc_bb_next
ntc_bb_second:
			move.l a4, d0
			bne ntc_bb_next
			movea.l a0, a4
			move.l 24(a0), d4
ntc_bb_next:
			movea.l (a0), a0
			bra ntc_bb_walk
ntc_bb_walked:
			; memory for the program as it comes off the disc (64 spare bytes each side: the mover)
			move.l #NTC_AMISEC+128, d0
			moveq #1, d1				; MEMF_PUBLIC
			jsr -198(a6)				; exec AllocMem
			tst.l d0
			beq ntc_bb_fail
			movea.l d0, a2
			lea 64(a2), a2				; a2 = where the program is read to
			movea.l a5, a1
			move.w #2, 28(a1)			; io_Command = CMD_READ
			move.l #NTC_AMISEC, 36(a1)	; io_Length
			move.l a2, 40(a1)			; io_Data
			move.l #1024, 44(a1)		; io_Offset: after the boot block
			jsr -456(a6)				; exec DoIO
			tst.l d0
			bne ntc_bb_fail
			movea.l a5, a1
			move.w #9, 28(a1)			; TD_MOTOR
			clr.l 36(a1)				; off
			jsr -456(a6)
			; the system's last moment: supervisor mode, everything off
			lea ntc_bb_super(pc), a5
			jsr -30(a6)					; exec Supervisor: a5's code in supervisor mode
ntc_bb_fail:
			move.w #$0F00, $DFF180		; (red: no memory, or the disc would not read)
			bra ntc_bb_fail
ntc_bb_super:
			move.w #$2700, sr
			lea $DFF000, a0
			move.w #$7FFF, $9A(a0)		; INTENA: none
			move.w #$7FFF, $9C(a0)		; INTREQ: none waiting
			move.w #$7FFF, $96(a0)		; DMACON: none
			; the mover goes where the move can't reach it: after the program when it moves down,
			; before it when it moves up
			lea NTC_AMICODE-(ntc_ramend-ntc_ram), a1	; where the image belongs
			lea -64(a2), a0
			cmpa.l a2, a1
			bhi ntc_bb_place
			lea NTC_AMISEC(a2), a0
ntc_bb_place:
			movea.l a0, a6
			lea ntc_bb_mover(pc), a5
			moveq #(ntc_bb_moverend-ntc_bb_mover)/2-1, d0
ntc_bb_cpm:
			move.w (a5)+, (a0)+
			dbra d0, ntc_bb_cpm
			movea.l a2, a0
			move.l #NTC_AMIIMG, d0
			jmp (a6)
; the mover: a0 = from, a1 = to, d0 = bytes; then the program's start (d3-d4, d6-d7, a3-a4: the
; memory found, kept for it)
ntc_bb_mover:
			cmpa.l a0, a1
			bhi ntc_bb_mdown
ntc_bb_mup:
			move.b (a0)+, (a1)+
			subq.l #1, d0
			bne ntc_bb_mup
			jmp ntc_ami_entry
ntc_bb_mdown:
			adda.l d0, a0
			adda.l d0, a1
ntc_bb_mdl:
			move.b -(a0), -(a1)
			subq.l #1, d0
			bne ntc_bb_mdl
			jmp ntc_ami_entry
			even
ntc_bb_moverend:
			dcb.b $03F0-*, 0			; the rest of the block
; the disc's label (amigabuild.js fills it in): the Loader class reads it to know a disc
ntc_ami_label:
			dc.b "NTCD"
			dc.w 1						; the disc's number in its set (1 the boot disc)
			dc.w 0						; the set's mark (the same on every disc of a game)
			dc.w 0						; the file list's first sector (the boot disc only)
			dc.w 0						; ... and its entries
			dc.l 0
			org NTC_AMICODE

;## ntc_ami_boot ntc_plat_data ntc_data ntc_plat_screen ntc_ami_font ntc_ami_keys ntc_ami_mem
ntc_ami_entry:
			lea NTC_AMISSP, sp
			lea NTC_AMICODE-(ntc_ramend-ntc_ram), a0	; the variables' first image (moved in below the code), to where they live
			lea ntc_ram, a1
			move.l #ntc_ramend-ntc_ram, d0
			beq ntc_ab_nodata
ntc_ab_cp:
			move.b (a0)+, (a1)+
			subq.l #1, d0
			bne ntc_ab_cp
ntc_ab_nodata:
			move.l d7, ntc_ami_chip
			move.b d6, ntc_ami_hz
			move.l a3, ntc_ami_o1
			move.l d3, ntc_ami_o1e
			move.l a4, ntc_ami_o2
			move.l d4, ntc_ami_o2e
			; the vectors: every exception stops with a red screen; the interrupts used; trap #1
			lea $8.w, a0
			moveq #61, d0
ntc_ab_vec:
			move.l #ntc_ami_crash, (a0)+
			dbra d0, ntc_ab_vec
			move.l #ntc_ami_int1, $64.w
			move.l #ntc_ami_int2, $68.w
			move.l #ntc_ami_int3, $6C.w
			move.l #ntc_ami_int4, $70.w
			move.l #ntc_ami_int5, $74.w
			move.l #ntc_ami_int6, $78.w
			move.l #ntc_ami_super, $84.w
			; the CIAs: no interrupts, the timers stopped, the drives' motors off and none chosen
			move.b #$7F, $BFED01		; CIA-A ICR: all off
			move.b #$7F, $BFDD00		; CIA-B ICR
			move.b $BFED01, d0			; (any waiting: read away)
			move.b $BFDD00, d0
			clr.b $BFEE01				; CIA-A CRA: timer A stopped, the keyboard's line an input
			clr.b $BFEF01
			clr.b $BFDE00
			clr.b $BFDF00
			move.b #$03, $BFE201		; CIA-A DDRA: the LED and the overlay outputs
			move.b #$02, $BFE001		; the ROM's overlay off; the sound filter off (the power LED dim)
			move.b #$FF, $BFD300		; CIA-B DDRB: the drives' lines all outputs
			move.b #$FF, $BFD100		; nothing chosen, the motor line off
			move.b #$87, $BFD100		; each drive takes the motor line as it is chosen: off
			move.b #$FF, $BFD100
			move.w #$7FFF, $DFF09E		; ADKCON: all off
			move.w #$FF00, $DFF034		; POTGO: the second buttons' lines pulled up
		ifd NTC_AMILOG
			move.l #$070000, $06FFFC	; test builds: the transcript starts empty
		endif
			bsr ntc_ami_meminit
			bsr ntc_ami_scrinit
			move.b #$88, $BFED01		; CIA-A: the keyboard's interrupt on
			move.w #$C028, $DFF09A		; INTENA: the keyboard (PORTS) and the frame (VERTB)
			move.l #NTC_USTACK, a0
			move.l a0, usp
			move.w #$0000, sr			; user mode, the interrupts on: A7 is now the user stack
			jmp ntc_start

; The supervisor call (as the X68000's). The Amiga lets user mode at all its hardware, so this is
; only for the 68000's own privileged instructions. From #asm:
;           lea my_routine, a0
;           trap #1
; my_routine runs in supervisor mode on the supervisor stack and ends with rts.
ntc_ami_super:
			jsr (a0)
			rte

; an exception (a bus or address error, an instruction that is not one, a divide by 0 ...):
; the screen red, stopped
ntc_ami_crash:
			move.w #$2700, sr
			move.w #$7FFF, $DFF096
ntc_ac_lp:
			move.w #$0F00, $DFF180
			bra ntc_ac_lp

; the interrupts not used: taken back (INTREQ), nothing done. (Written twice: a fast processor
; can leave the handler before the first write shows.)
ntc_ami_int1:
			move.w #$0007, $DFF09C
			move.w #$0007, $DFF09C
			rte
ntc_ami_int4:
			move.w #$0780, $DFF09C
			move.w #$0780, $DFF09C
			rte
ntc_ami_int5:
			move.w #$1800, $DFF09C
			move.w #$1800, $DFF09C
			rte
ntc_ami_int6:
			move.l d0, -(sp)
			move.b $BFDD00, d0
			move.w #$2000, $DFF09C
			move.w #$2000, $DFF09C
			move.l (sp)+, d0
			rte

; level 3, the frame (the vertical blank): count it. The copper's and the blitter's interrupts
; share the level: taken back too.
ntc_ami_int3:
			move.l d0, -(sp)
			move.w $DFF01E, d0			; INTREQR
			btst #5, d0
			beq ntc_i3_e
			addq.w #1, ntc_ticks
			addq.w #1, ntc_vbl
ntc_i3_e:
			move.w #$0070, $DFF09C
			move.w #$0070, $DFF09C
			move.l (sp)+, d0
			rte

;## ntc_plat_data
;@ram
ntc_curx:		dc.b 0				; cursor column (0 based)
ntc_cury:		dc.b 0				; cursor row (0 based)
ntc_scols:		dc.b 80				; columns
ntc_srows:		dc.b 32				; rows (25 on an NTSC machine)
ntc_wrapped:	dc.b 0				; 1 = the last character wrapped to the next line
ntc_ami_hz:		dc.b 50				; frames a second: 50 (PAL) or 60 (NTSC)
			even
ntc_ticks:		dc.w 0				; frames since the start
ntc_vbl:		dc.w 0				; frames (ntc_plat_frame waits for it to move)
ntc_ami_chip:	dc.l 0				; the top of chip RAM ($80000: 512K, $100000: 1 MB, $200000: 2 MB)
ntc_ami_o1:		dc.l 0				; the other memory's first block: its start (0: none)
ntc_ami_o1e:	dc.l 0				; ... its end
ntc_ami_o2:		dc.l 0				; a second block
ntc_ami_o2e:	dc.l 0
ntc_ami_scr:	dc.l 0				; the console's bitplane (chip RAM)
;@rom

;## ntc_ami_mem ntc_plat_data
; The Amiga's free memory, handed out in blocks (the Memory class). Two pools: chip RAM from the
; program's end to its top (what the custom chips can show and play), and the other RAM (slow,
; fast), which only the 68000 sees and which is quicker where it is real fast RAM.
;@ram
ntc_ami_cbrk:	dc.l 0				; the chip pool: the next free byte
ntc_ami_ctop:	dc.l 0				; ... its end
ntc_ami_o1brk:	dc.l 0				; the other pool's first block: the next free byte
ntc_ami_o2brk:	dc.l 0				; ... its second
;@rom
ntc_ami_meminit:
			move.l #ntc_romend+3, d0
			andi.l #$FFFFFFFC, d0
			move.l d0, ntc_ami_cbrk
			move.l ntc_ami_chip, d0
		ifd NTC_AMILOG
			cmpi.l #$06FFF0, d0
			bls ntc_mi_top
			move.l #$06FFF0, d0			; test builds: the transcript sits above
ntc_mi_top:
		endif
			move.l d0, ntc_ami_ctop
			move.l ntc_ami_o1, d0
			beq ntc_mi_o2
			addi.l #32+3, d0			; (the system's header for the block was at its start: stepped over)
			andi.l #$FFFFFFFC, d0
ntc_mi_o2:
			move.l d0, ntc_ami_o1brk
			move.l ntc_ami_o2, d0
			beq ntc_mi_e
			addi.l #32+3, d0
			andi.l #$FFFFFFFC, d0
ntc_mi_e:
			move.l d0, ntc_ami_o2brk
			rts

; ntc_ami_alloc - d0 = bytes, d1 = 0 chip RAM / 1 the other RAM: d0 = the block (a 4 byte
; edge), or 0 when that pool has not that much left. Keeps d2-d7 / a0-a6
ntc_ami_alloc:
			addq.l #3, d0
			andi.l #$FFFFFFFC, d0
			tst.w d1
			bne ntc_al_other
			move.l ntc_ami_ctop, d1
			sub.l ntc_ami_cbrk, d1
			cmp.l d0, d1
			bcs ntc_al_none
			move.l ntc_ami_cbrk, d1
			add.l d0, ntc_ami_cbrk
			move.l d1, d0
			rts
ntc_al_other:
			tst.l ntc_ami_o1brk
			beq ntc_al_o2
			move.l ntc_ami_o1e, d1
			sub.l ntc_ami_o1brk, d1
			cmp.l d0, d1
			bcs ntc_al_o2
			move.l ntc_ami_o1brk, d1
			add.l d0, ntc_ami_o1brk
			move.l d1, d0
			rts
ntc_al_o2:
			tst.l ntc_ami_o2brk
			beq ntc_al_none
			move.l ntc_ami_o2e, d1
			sub.l ntc_ami_o2brk, d1
			cmp.l d0, d1
			bcs ntc_al_none
			move.l ntc_ami_o2brk, d1
			add.l d0, ntc_ami_o2brk
			move.l d1, d0
			rts
ntc_al_none:
			moveq #0, d0
			rts

; ntc_ami_left - d1 = 0 chip / 1 other: d0 = the bytes left (other: its bigger block's)
ntc_ami_left:
			tst.w d1
			bne ntc_lf_other
			move.l ntc_ami_ctop, d0
			sub.l ntc_ami_cbrk, d0
			rts
ntc_lf_other:
			moveq #0, d0
			tst.l ntc_ami_o1brk
			beq ntc_lf_o2
			move.l ntc_ami_o1e, d0
			sub.l ntc_ami_o1brk, d0
ntc_lf_o2:
			tst.l ntc_ami_o2brk
			beq ntc_lf_e
			move.l ntc_ami_o2e, d1
			sub.l ntc_ami_o2brk, d1
			cmp.l d0, d1
			bls ntc_lf_e
			move.l d1, d0
ntc_lf_e:
			rts

;## ntc_plat_screen ntc_plat_data ntc_data ntc_ami_logs ntc_ami_font ntc_ami_mem
; The console: one bitplane, 640 wide (80 bytes a line), a character 8 x 8. The copper list
; (the display's set-up, done again by the chips each frame) is in the variables: chip RAM.
;@ram
ntc_ami_cop:
			dc.w $0100, $9200			; BPLCON0: hires, one bitplane, colour
			dc.w $0102, $0000			; BPLCON1: no scroll
			dc.w $0104, $0000			; BPLCON2
			dc.w $0108, $0000			; BPL1MOD
			dc.w $008E, $2C81			; DIWSTRT
ntc_ami_copstop:
			dc.w $0090, $2CC1			; DIWSTOP: 256 lines (PAL)
			dc.w $0092, $003C			; DDFSTRT (hires)
			dc.w $0094, $00D4			; DDFSTOP
ntc_ami_copbpl:
			dc.w $00E0, $0000			; BPL1PTH
			dc.w $00E2, $0000			; BPL1PTL
			dc.w $0180, $005A			; COLOR00: the paper
			dc.w $0182, $0FFF			; COLOR01: the ink
			dc.w $FFFF, $FFFE			; the end
;@rom
ntc_ami_scrinit:
			move.l #20480, d0			; 640 x 256 / 8
			moveq #0, d1
			bsr ntc_ami_alloc
			move.l d0, ntc_ami_scr
			cmpi.b #60, ntc_ami_hz
			bne ntc_si_pal
			move.b #25, ntc_srows		; NTSC: 200 lines
			move.w #$F4C1, ntc_ami_copstop+2
ntc_si_pal:
			bsr ntc_plat_cls
			bsr ntc_ami_scrshow
			rts

; the console's display on (again): its copper list, its bitplane. (A game's own display takes
; these over; this gives them back.)
ntc_ami_scrshow:
			move.l ntc_ami_scr, d0
			move.w d0, ntc_ami_copbpl+6
			swap d0
			move.w d0, ntc_ami_copbpl+2
			move.l #ntc_ami_cop, $DFF080	; COP1LC
			move.w d0, $DFF088				; COPJMP1: from its start
			move.w #$0020, $DFF096			; DMACON: the sprites off
			move.w #$8380, $DFF096			; ... the bitplanes and the copper on
			rts

; a0 = the address in the bitplane of the cursor's cell's top line. Keeps all else
ntc_ami_cell:
			move.l d0, -(sp)
			moveq #0, d0
			move.b ntc_cury, d0
			mulu #640, d0
			movea.l ntc_ami_scr, a0
			adda.l d0, a0
			moveq #0, d0
			move.b ntc_curx, d0
			adda.l d0, a0
			move.l (sp)+, d0
			rts

; ntc_plat_putc - d0.b = character: at the cursor, move on, a new line after the last
; column. Real stack, keeps d2-d7 / a2-a6
ntc_plat_putc:
			movem.l d0-d1/a0-a1, -(sp)
		ifd NTC_AMILOG
			bsr ntc_ami_log
		endif
			andi.w #$FF, d0
			subi.w #32, d0
			bcs ntc_pc_blank
			cmpi.w #95, d0
			bcs ntc_pc_ok
ntc_pc_blank:
			moveq #0, d0
ntc_pc_ok:
			lsl.w #3, d0
			lea ntc_ami_fontdata, a1
			adda.w d0, a1
			bsr ntc_ami_cell
			moveq #7, d1
ntc_pc_ln:
			move.b (a1)+, (a0)
			lea 80(a0), a0
			dbra d1, ntc_pc_ln
			movem.l (sp)+, d0-d1/a0-a1
			addq.b #1, ntc_curx
			move.l d0, -(sp)
			move.b ntc_curx, d0
			cmp.b ntc_scols, d0
			bcs ntc_pc_nowrap
			move.b #1, ntc_wrapped
			move.l (sp)+, d0
			bra ntc_nl_do
ntc_pc_nowrap:
			clr.b ntc_wrapped
			move.l (sp)+, d0
			rts

; ntc_plat_newline - column 0, next row (scrolls at the bottom); nothing straight after a wrap
ntc_plat_newline:
		ifd NTC_AMILOG
			move.l d0, -(sp)
			moveq #10, d0
			bsr ntc_ami_log
			move.l (sp)+, d0
		endif
			tst.b ntc_wrapped
			beq ntc_nl_do
			clr.b ntc_wrapped
			rts
ntc_nl_do:
			move.l d0, -(sp)
			clr.b ntc_curx
			addq.b #1, ntc_cury
			move.b ntc_cury, d0
			cmp.b ntc_srows, d0
			bcs ntc_nl_e
			subq.b #1, ntc_cury			; the bottom: every row up one, the last cleared
			movem.l d1/a0-a1, -(sp)
			movea.l ntc_ami_scr, a0
			lea 640(a0), a1
			moveq #0, d0
			move.b ntc_srows, d0
			subq.w #1, d0
			mulu #160, d0				; the longs in all the rows but one
			subq.w #1, d0
ntc_nl_up:
			move.l (a1)+, (a0)+
			dbra d0, ntc_nl_up
			moveq #159, d0
ntc_nl_cl:
			clr.l (a0)+
			dbra d0, ntc_nl_cl
			movem.l (sp)+, d1/a0-a1
ntc_nl_e:
			move.l (sp)+, d0
			rts

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_backspace - back a column and clear it (not past the line's start)
ntc_plat_backspace:
			tst.b ntc_curx
			beq ntc_bs_e
			subq.b #1, ntc_curx
			movem.l d0/a0, -(sp)
			bsr ntc_ami_cell
			moveq #7, d0
ntc_bs_ln:
			clr.b (a0)
			lea 80(a0), a0
			dbra d0, ntc_bs_ln
			movem.l (sp)+, d0/a0
ntc_bs_e:
			rts

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_cls - clear the console, the cursor home
ntc_plat_cls:
			movem.l d0/a0, -(sp)
			movea.l ntc_ami_scr, a0
			move.w #20480/4-1, d0
ntc_cl_lp:
			clr.l (a0)+
			dbra d0, ntc_cl_lp
			clr.b ntc_curx
			clr.b ntc_cury
			clr.b ntc_wrapped
			movem.l (sp)+, d0/a0
			rts

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data ntc_plat_cls
; ntc_plat_mode - d0 = mode: one text mode here (80 columns), so it clears the screen and
; shows the console again (after a game's own display)
ntc_plat_mode:
			bsr ntc_plat_cls
			move.l d0, -(sp)
			bsr ntc_ami_scrshow
			move.l (sp)+, d0
			rts

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - d0 = column, d1 = row (1 based, kept on the screen)
ntc_plat_locate:
			subq.w #1, d0
			bpl ntc_lo_x0
			moveq #0, d0
ntc_lo_x0:
			cmpi.w #79, d0
			bls ntc_lo_x1
			moveq #79, d0
ntc_lo_x1:
			subq.w #1, d1
			bpl ntc_lo_y0
			moveq #0, d1
ntc_lo_y0:
			move.l d2, -(sp)
			moveq #0, d2
			move.b ntc_srows, d2
			subq.w #1, d2
			cmp.w d2, d1
			bls ntc_lo_y1
			move.w d2, d1
ntc_lo_y1:
			move.l (sp)+, d2
			move.b d0, ntc_curx
			move.b d1, ntc_cury
			clr.b ntc_wrapped
			rts

;## ntc_ami_logs
		ifd NTC_AMILOG
; test builds (vasm -DNTC_AMILOG): what the console was given, at $070000 on (the
; harness reads it): characters, 10 for a new line. $06FFFC: where the next goes
ntc_ami_log:
			move.l a0, -(sp)
			movea.l $06FFFC, a0
			cmpa.l #$07F000, a0
			bcc ntc_lg_full
			move.b d0, (a0)+
			move.l a0, $06FFFC
ntc_lg_full:
			movea.l (sp)+, a0
			rts
		endif

;## ntc_ami_font
; NTC's font: characters 32-126, 8 bytes each, 1 bit a pixel (the Mega Drive platform's)
ntc_ami_fontdata:
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

;## ntc_ami_keys ntc_plat_data
; The keyboard. It sends each key going down or up as a byte through CIA-A's serial port
; (interrupt level 2); the Amiga answers by holding the line for a moment. ntc_ami_held has a
; byte for each of its 128 keys (the Keys class), typed characters wait in a small queue.
;@ram
ntc_ami_held:	ds.b 128			; a key's byte: not 0 while it is down
ntc_ami_kq:		ds.b 16				; the characters typed, not yet read
ntc_ami_kqr:	dc.b 0				; ... the next to read
ntc_ami_kqw:	dc.b 0				; ... the next free
ntc_ami_caps:	dc.b 0				; Caps Lock on
			even
;@rom
ntc_ami_int2:
			movem.l d0-d2/a0, -(sp)
			move.b $BFED01, d0			; CIA-A ICR: what happened (read: taken back)
			btst #3, d0					; the serial port: a key byte
			beq ntc_i2_e
			move.b $BFEC01, d0			; SDR
			ori.b #$40, $BFEE01			; the line held: "taken"
			not.b d0
			ror.b #1, d0				; d0 = the key (0-127), bit 7 set when it went up
			moveq #0, d1
			move.b d0, d1
			andi.w #$7F, d1
			lea ntc_ami_held, a0
			tst.b d0
			bmi ntc_i2_up
			st 0(a0, d1.w)
			cmpi.w #$62, d1				; Caps Lock: down = on
			bne ntc_i2_chr
			st ntc_ami_caps
			bra ntc_i2_hs
ntc_i2_up:
			clr.b 0(a0, d1.w)
			cmpi.w #$62, d1
			bne ntc_i2_hs
			clr.b ntc_ami_caps
			bra ntc_i2_hs
ntc_i2_chr:
			cmpi.w #$60, d1
			bcc ntc_i2_hs				; the shifts and the rest: no character
			lea ntc_ami_kplain, a0
			move.b ntc_ami_held+$60, d2
			or.b ntc_ami_held+$61, d2	; either Shift
			beq ntc_i2_tab
			lea ntc_ami_kshift, a0
ntc_i2_tab:
			move.b 0(a0, d1.w), d0
			beq ntc_i2_hs
			tst.b ntc_ami_caps			; Caps Lock: the letters the other way
			beq ntc_i2_put
			cmpi.b #'a', d0
			bcs ntc_i2_cu
			cmpi.b #'z', d0
			bhi ntc_i2_put
			subi.b #32, d0
			bra ntc_i2_put
ntc_i2_cu:
			cmpi.b #'A', d0
			bcs ntc_i2_put
			cmpi.b #'Z', d0
			bhi ntc_i2_put
			addi.b #32, d0
ntc_i2_put:
			moveq #0, d1
			move.b ntc_ami_kqw, d1
			move.b d1, d2
			addq.b #1, d2
			andi.b #15, d2
			cmp.b ntc_ami_kqr, d2
			beq ntc_i2_hs				; the queue is full: lost
			lea ntc_ami_kq, a0
			move.b d0, 0(a0, d1.w)
			move.b d2, ntc_ami_kqw
ntc_i2_hs:
			; the line is held for three scan lines (about 190 millionths of a second), then let go
			moveq #3, d1
ntc_i2_w1:
			move.b $DFF006, d0
ntc_i2_w2:
			cmp.b $DFF006, d0
			beq ntc_i2_w2
			dbra d1, ntc_i2_w1
			andi.b #$BF, $BFEE01
ntc_i2_e:
			move.w #$0008, $DFF09C
			move.w #$0008, $DFF09C
			movem.l (sp)+, d0-d2/a0
			rte

; the keys' characters (keys $00-$5F): plain, then with Shift. 0: none. $F0-$F3 the cursor keys
ntc_ami_kplain:
			dc.b "`1234567890-=\", 0, "0"
			dc.b "qwertyuiop[]", 0, "123"
			dc.b "asdfghjkl;'", 0, 0, "456"
			dc.b 0, "zxcvbnm,./", 0, ".789"
			dc.b 32, 8, 9, 13, 13, 27, 127, 0, 0, 0, "-", 0, $F0, $F1, $F3, $F2
			dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "()/*+", 0
ntc_ami_kshift:
			dc.b "~!@#$%^&*()_+|", 0, "0"
			dc.b "QWERTYUIOP{}", 0, "123"
			dc.b "ASDFGHJKL:", 34, 0, 0, "456"
			dc.b 0, "ZXCVBNM<>?", 0, ".789"
			dc.b 32, 8, 9, 13, 13, 27, 127, 0, 0, 0, "-", 0, $F0, $F1, $F3, $F2
			dc.b 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, "()/*+", 0
			even

;## ntc_plat_key ntc_data ntc_plat_data ntc_plat_frame ntc_ami_keys ntc_plat_screen
; ntc_plat_scankey - d0 = a key waiting (its character; the cursor keys $F0-$F3), or 0
ntc_plat_scankey:
			moveq #0, d0
			move.l d1, -(sp)
			move.b ntc_ami_kqr, d1
			cmp.b ntc_ami_kqw, d1
			beq ntc_sk_e
			move.l a0, -(sp)
			lea ntc_ami_kq, a0
			andi.w #15, d1
			move.b 0(a0, d1.w), d0
			addq.b #1, d1
			andi.b #15, d1
			move.b d1, ntc_ami_kqr
			movea.l (sp)+, a0
ntc_sk_e:
			move.l (sp)+, d1
			rts

; ntc_plat_getkey - wait for a key: d0 = its code. The cursor's cell is shown inverted while
; it waits.
ntc_plat_getkey:
			bsr ntc_ami_flip
ntc_gk_lp:
			bsr ntc_plat_scankey
			tst.b d0
			bne ntc_gk_e
			bsr ntc_plat_frame
			bra ntc_gk_lp
ntc_gk_e:
			bsr ntc_ami_flip
			rts
ntc_ami_flip:
			movem.l d0/a0, -(sp)
			bsr ntc_ami_cell
			moveq #7, d0
ntc_fl_ln:
			not.b (a0)
			lea 80(a0), a0
			dbra d0, ntc_fl_ln
			movem.l (sp)+, d0/a0
			rts

;## ntc_plat_frame ntc_plat_data
; ntc_plat_frame - wait for the next frame interrupt (the vertical blank)
ntc_plat_frame:
			move.l d0, -(sp)
			move.w ntc_vbl, d0
ntc_fr_lp:
			cmp.w ntc_vbl, d0
			beq ntc_fr_lp
			move.l (sp)+, d0
			rts

;## ntc_plat_ticks ntc_plat_data
; ntc_plat_ticks - d0.w = frames since the start (50 a second; 60 on an NTSC machine)
ntc_plat_ticks:
			move.w ntc_ticks, d0
			rts

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - before the program stops: a boot disc has nowhere to go back to
ntc_plat_exit:
			rts

;## ntc_ami_disk ntc_plat_data ntc_ami_mem ntc_plat_frame
; The disc drives, worked directly (no system): DF0-DF3. A track is read whole by the disc DMA
; as the drive gives it (MFM: 12800 bytes from a sync mark), its 11 sectors are found, checked
; and decoded into a track buffer, and what was asked for is copied from that.
;   CIA-B port B ($BFD100): bit 7 /MOTOR, 6-3 /SEL3-/SEL0, 2 /SIDE, 1 DIR, 0 /STEP
;   CIA-A port A ($BFE001): bit 5 /READY, 4 /TRACK0, 3 /PROTECTED, 2 /CHANGE
NTC_AMIRAW	equ 12800				; the bytes read for a track (a turn is 12500)
;@ram
ntc_ami_dcyl:	dc.b $FF, $FF, $FF, $FF	; each drive's cylinder ($FF: not known)
ntc_ami_dlab:	dc.b $FF, $FF, $FF, $FF	; each drive's disc: its number in the set, 0 not one of it, $FF not looked at
ntc_ami_dhas:	dc.b 1, $FF, $FF, $FF	; each drive: 1 there, 0 not, $FF not looked for
ntc_ami_dsel:	dc.b $FF			; port B's byte while a drive is chosen
ntc_ami_ddrv:	dc.b 0				; the drive being used
ntc_ami_dtrk:	dc.b 0				; the track wanted (cylinder * 2 + side)
ntc_ami_dhave:	dc.b $FF			; the track in the buffer ($FF: none) ...
ntc_ami_dhdrv:	dc.b $FF			; ... and its drive
			even
ntc_ami_draw:	dc.l 0				; the raw track (chip RAM), then the decoded track (5632 bytes)
ntc_ami_dmark:	dc.w 0				; the set's mark (the boot disc's label)
;@rom

; d0 = scan lines to wait (64 millionths of a second each). Keeps all
ntc_ami_dwait:
			movem.l d0-d1, -(sp)
ntc_dw_l:
			move.b $DFF006, d1
ntc_dw_w:
			cmp.b $DFF006, d1
			beq ntc_dw_w
			subq.w #1, d0
			bne ntc_dw_l
			movem.l (sp)+, d0-d1
			rts

; the drive (ntc_ami_ddrv) chosen with its motor on, at side 0. d0 = 0, or 1 when there is no
; disc in it. A disc changed since the last time: its track and its label are forgotten.
ntc_ami_don:
			movem.l d1-d2/a0, -(sp)
			tst.l ntc_ami_draw
			bne ntc_do_buf
			move.l #NTC_AMIRAW+64+5632, d0
			moveq #0, d1
			bsr ntc_ami_alloc			; (chip RAM: the disc DMA writes there)
			move.l d0, ntc_ami_draw
			bne ntc_do_buf
			moveq #1, d0
			bra ntc_do_e
ntc_do_buf:
			moveq #0, d1
			move.b ntc_ami_ddrv, d1
			moveq #$7F, d0				; motor on (bit 7 low), none chosen
			move.b #$FF, $BFD100
			move.b d0, $BFD100
			addq.w #3, d1
			bclr d1, d0
			move.b d0, ntc_ami_dsel
			move.b d0, $BFD100			; chosen: the drive takes the motor line
			; up to speed: /READY low, or half a second
			moveq #25, d2
ntc_do_rdy:
			btst #5, $BFE001
			beq ntc_do_up
			bsr ntc_plat_frame
			dbra d2, ntc_do_rdy
ntc_do_up:
			btst #2, $BFE001			; /CHANGE: low = the disc was out
			bne ntc_do_ok
			moveq #0, d1
			move.b ntc_ami_ddrv, d1
			lea ntc_ami_dlab, a0
			move.b #$FF, 0(a0, d1.w)	; its label: to be looked at again
			lea ntc_ami_dcyl, a0
			move.b #$FF, 0(a0, d1.w)
			cmp.b ntc_ami_dhdrv, d1
			bne ntc_do_step
			move.b #$FF, ntc_ami_dhave
ntc_do_step:
			bsr ntc_ami_dhome			; a step makes the drive look for a disc again
			btst #2, $BFE001
			bne ntc_do_ok
			moveq #1, d0				; still low: no disc in the drive
			bra ntc_do_e
ntc_do_ok:
			moveq #0, d0
ntc_do_e:
			movem.l (sp)+, d1-d2/a0
			rts

; every drive's motor off, none chosen
ntc_ami_doff:
			move.b #$FF, $BFD100
			move.b #$87, $BFD100
			move.b #$FF, $BFD100
			rts

; one step: d0 = 0 towards the middle (a higher cylinder), 2 outwards
ntc_ami_dstep:
			move.l d1, -(sp)
			move.b ntc_ami_dsel, d1
			andi.b #$FD, d1
			or.b d0, d1
			move.b d1, $BFD100			; the direction first
			bclr #0, d1
			move.b d1, $BFD100			; /STEP low ...
			bset #0, d1
			move.b d1, $BFD100			; ... and high: the step
			move.b d1, ntc_ami_dsel
			moveq #50, d0				; 3 thousandths of a second before the next
			bsr ntc_ami_dwait
			move.l (sp)+, d1
			rts

; the head to cylinder 0 (the drive says when it is there)
ntc_ami_dhome:
			movem.l d0-d2/a0, -(sp)
			moveq #0, d0
			bsr ntc_ami_dstep			; (one in first: a drive already at 0 needs a step to say so truly)
			moveq #90, d2
ntc_dh_l:
			btst #4, $BFE001			; /TRACK0
			beq ntc_dh_at
			moveq #2, d0
			bsr ntc_ami_dstep
			dbra d2, ntc_dh_l
ntc_dh_at:
			moveq #0, d1
			move.b ntc_ami_ddrv, d1
			lea ntc_ami_dcyl, a0
			clr.b 0(a0, d1.w)
			move.w #240, d0				; the head settles: 15 thousandths
			bsr ntc_ami_dwait
			movem.l (sp)+, d0-d2/a0
			rts

; the head to the wanted track's cylinder, its side chosen
ntc_ami_dseek:
			movem.l d0-d3/a0, -(sp)
			moveq #0, d1
			move.b ntc_ami_ddrv, d1
			lea ntc_ami_dcyl, a0
			adda.w d1, a0
			cmpi.b #$FF, (a0)
			bne ntc_ds_known
			bsr ntc_ami_dhome
ntc_ds_known:
			moveq #0, d2
			move.b ntc_ami_dtrk, d2
			lsr.w #1, d2				; the cylinder wanted
			moveq #0, d3
			move.b (a0), d3
			cmp.w d2, d3
			beq ntc_ds_side
ntc_ds_l:
			cmp.w d2, d3
			beq ntc_ds_there
			bcs ntc_ds_in
			moveq #2, d0
			bsr ntc_ami_dstep
			subq.w #1, d3
			bra ntc_ds_l
ntc_ds_in:
			moveq #0, d0
			bsr ntc_ami_dstep
			addq.w #1, d3
			bra ntc_ds_l
ntc_ds_there:
			move.b d3, (a0)
			move.w #240, d0
			bsr ntc_ami_dwait
ntc_ds_side:
			move.b ntc_ami_dsel, d0
			bset #2, d0					; /SIDE high: the lower head (side 0)
			btst #0, ntc_ami_dtrk
			beq ntc_ds_s0
			bclr #2, d0					; low: the upper head (side 1)
ntc_ds_s0:
			move.b d0, ntc_ami_dsel
			move.b d0, $BFD100
			moveq #2, d0
			bsr ntc_ami_dwait			; (the head's switch: a tenth of a thousandth)
			movem.l (sp)+, d0-d3/a0
			rts

; ntc_ami_dtrack - the track ntc_ami_dtrk of the chosen drive into the track buffer (nothing
; to do when it is there already). d0 = 0, or 2 when it would not read (four tries)
ntc_ami_dtrack:
			movem.l d1-d7/a0-a5, -(sp)
			move.b ntc_ami_dtrk, d0
			cmp.b ntc_ami_dhave, d0
			bne ntc_dt_read
			move.b ntc_ami_ddrv, d0
			cmp.b ntc_ami_dhdrv, d0
			beq ntc_dt_ok
ntc_dt_read:
			move.b #$FF, ntc_ami_dhave
			moveq #3, d7				; tries
ntc_dt_try:
			bsr ntc_ami_dseek
			lea $DFF000, a5
			move.w #$4000, $24(a5)		; DSKLEN: off
			move.w #$7F00, $9E(a5)		; ADKCON: the disc's bits off ...
			move.w #$9500, $9E(a5)		; ... MFM, wait for the sync word, fast
			move.w #$4489, $7E(a5)		; DSKSYNC: the mark every sector starts with
			move.l ntc_ami_draw, $20(a5)	; DSKPT
			move.w #$0002, $9C(a5)		; (no "block done" waiting)
			move.w #$8210, $96(a5)		; DMACON: the disc's DMA on
			move.w #$8000+NTC_AMIRAW/2, $24(a5)
			move.w #$8000+NTC_AMIRAW/2, $24(a5)	; DSKLEN: read (written twice starts it)
			move.w ntc_vbl, d1
ntc_dt_wait:
			btst #1, $1F(a5)			; INTREQR: the block is done
			bne ntc_dt_got
			move.w ntc_vbl, d0
			sub.w d1, d0
			cmpi.w #100, d0				; two seconds: nothing came
			bcs ntc_dt_wait
			move.w #$4000, $24(a5)
			bra ntc_dt_again
ntc_dt_got:
			move.w #$4000, $24(a5)
			move.w #$0002, $9C(a5)
			; the sectors: after each sync mark a header (format, track, sector, to the gap), a
			; label, two checksums, then 512 bytes as their odd bits and their even bits
			movea.l ntc_ami_draw, a0
			lea NTC_AMIRAW(a0), a1		; the raw track's end; the decoded track follows from a1 + 64
			move.l #$55555555, d5
			moveq #0, d6				; the sectors found
			bra ntc_dt_marks
ntc_dt_scan:
			cmpa.l a1, a0
			bcc ntc_dt_scanned
			cmpi.w #$4489, (a0)+
			bne ntc_dt_scan
ntc_dt_marks:
			cmpa.l a1, a0
			bcc ntc_dt_scanned
			cmpi.w #$4489, (a0)
			bne ntc_dt_head
			addq.l #2, a0
			bra ntc_dt_marks
ntc_dt_head:
			lea 1080(a0), a2
			cmpa.l a1, a2
			bhi ntc_dt_scanned			; (not all of it was read: it was found whole earlier in the turn)
			move.l (a0), d0
			move.l 4(a0), d1
			and.l d5, d0
			and.l d5, d1
			add.l d0, d0
			or.l d1, d0					; d0 = $FF, the track, the sector, sectors to the gap
			rol.l #8, d0
			cmpi.b #$FF, d0
			bne ntc_dt_scan
			rol.l #8, d0
			cmp.b ntc_ami_dtrk, d0
			bne ntc_dt_scan
			rol.l #8, d0
			moveq #0, d2
			move.b d0, d2				; the sector
			cmpi.w #11, d2
			bcc ntc_dt_scan
			move.l 48(a0), d3			; the data's checksum
			move.l 52(a0), d1
			and.l d5, d3
			and.l d5, d1
			add.l d3, d3
			or.l d1, d3
			lea 56(a0), a3
			moveq #0, d4
			move.w #255, d0
ntc_dt_sum:
			move.l (a3)+, d1
			eor.l d1, d4
			dbra d0, ntc_dt_sum
			and.l d5, d4
			cmp.l d3, d4
			bne ntc_dt_scan				; a bad sector: perhaps the next try
			lea 56(a0), a3				; the odd bits
			lea 512(a3), a4				; the even bits
			move.w d2, d0
			mulu #512, d0
			lea 64(a1), a2
			adda.l d0, a2
			moveq #127, d0
ntc_dt_dec:
			move.l (a3)+, d1
			move.l (a4)+, d3
			and.l d5, d1
			and.l d5, d3
			add.l d1, d1
			or.l d3, d1
			move.l d1, (a2)+
			dbra d0, ntc_dt_dec
			bset d2, d6
			lea 1080(a0), a0
			bra ntc_dt_scan
ntc_dt_scanned:
			cmpi.w #$07FF, d6			; all eleven
			beq ntc_dt_done
ntc_dt_again:
			cmpi.w #2, d7				; the second try failed too: the head back to cylinder 0 first
			bne ntc_dt_retry
			moveq #0, d1
			move.b ntc_ami_ddrv, d1
			lea ntc_ami_dcyl, a0
			move.b #$FF, 0(a0, d1.w)
ntc_dt_retry:
			dbra d7, ntc_dt_try
			move.w #$0010, $DFF096
			moveq #2, d0
			bra ntc_dt_e
ntc_dt_done:
			move.w #$0010, $DFF096		; the disc's DMA off
			move.b ntc_ami_dtrk, ntc_ami_dhave
			move.b ntc_ami_ddrv, ntc_ami_dhdrv
ntc_dt_ok:
			moveq #0, d0
ntc_dt_e:
			movem.l (sp)+, d1-d7/a0-a5
			rts

; ntc_ami_dread - d0 = the drive (0-3), d1 = the first sector (0-1759), d2 = bytes, a0 = where
; to: read. The motor is left on (ntc_ami_doff). d0 = 0, 1 no disc, 2 would not read. Real
; stack; keeps d3-d7 / a1-a6
ntc_ami_dread:
			movem.l d3-d5/a1-a2, -(sp)
			move.b d0, ntc_ami_ddrv
			move.l d1, d3				; the sector
			move.l d2, d4				; the bytes left
			movea.l a0, a2
			bsr ntc_ami_don
			tst.w d0
			bne ntc_dr_e
ntc_dr_l:
			tst.l d4
			beq ntc_dr_ok
			move.l d3, d0
			divu #11, d0				; the track; the remainder (high word) the sector in it
			move.b d0, ntc_ami_dtrk
			swap d0
			moveq #0, d5
			move.w d0, d5
			bsr ntc_ami_dtrack
			tst.w d0
			bne ntc_dr_e
			movea.l ntc_ami_draw, a1
			lea NTC_AMIRAW+64(a1), a1
			move.l d5, d0
			mulu #512, d0
			adda.l d0, a1				; from here in the decoded track ...
			moveq #11, d1
			sub.w d5, d1
			mulu #512, d1				; ... this many bytes of it
			cmp.l d4, d1
			bls ntc_dr_n
			move.l d4, d1
ntc_dr_n:
			sub.l d1, d4
			move.l d1, d0
			addi.l #511, d0
			lsr.l #8, d0
			lsr.l #1, d0
			add.l d0, d3				; the sectors done
ntc_dr_cp:
			move.b (a1)+, (a2)+
			subq.l #1, d1
			bne ntc_dr_cp
			bra ntc_dr_l
ntc_dr_ok:
			moveq #0, d0
ntc_dr_e:
			movem.l (sp)+, d3-d5/a1-a2
			rts

; ntc_ami_dprobe - d0 = a drive (0-3): d0 = 1 when it is there. DF0 always is; another says
; what it is when asked (its motor line on then off, then 32 bits on /READY): all 1s is no drive.
ntc_ami_dprobe:
			movem.l d1-d4/a0, -(sp)
			moveq #0, d1
			move.b d0, d1
			lea ntc_ami_dhas, a0
			adda.w d1, a0
			cmpi.b #$FF, (a0)
			bne ntc_dp_e
			addq.w #3, d1				; its /SEL bit
			moveq #$7F, d2
			move.b #$FF, $BFD100
			move.b d2, $BFD100			; motor line on ...
			bclr d1, d2
			move.b d2, $BFD100			; ... taken
			move.b #$7F, $BFD100
			move.b #$FF, $BFD100		; motor line off ...
			moveq #-1, d2
			bclr d1, d2
			move.b d2, $BFD100			; ... taken
			move.b #$FF, $BFD100
			moveq #0, d3				; the bits
			moveq #31, d4
ntc_dp_bit:
			move.b d2, $BFD100
			add.l d3, d3
			btst #5, $BFE001
			beq ntc_dp_0
			addq.l #1, d3
ntc_dp_0:
			move.b #$FF, $BFD100
			dbra d4, ntc_dp_bit
			moveq #1, d2
			addq.l #1, d3				; all 1s (-1): nothing answered
			bne ntc_dp_set
			moveq #0, d2
ntc_dp_set:
			move.b d2, (a0)
ntc_dp_e:
			moveq #0, d0
			move.b (a0), d0
			movem.l (sp)+, d1-d4/a0
			rts

; ntc_ami_dlabel - d0 = a drive: d0 = the number of the disc in it (1 the boot disc, 2 ...), 0
; when it has no disc or one that is not of this set. Looked at once for each disc put in.
ntc_ami_dlabel:
			movem.l d1-d3/a0-a1, -(sp)
			moveq #0, d3
			move.b d0, d3
			bsr ntc_ami_dprobe
			tst.w d0
			beq ntc_dl_none
			move.b d3, ntc_ami_ddrv
			bsr ntc_ami_don				; (a changed disc: its label forgotten here)
			tst.w d0
			bne ntc_dl_none
			lea ntc_ami_dlab, a1
			adda.w d3, a1
			cmpi.b #$FF, (a1)
			bne ntc_dl_have
			clr.b ntc_ami_dtrk			; the label is in the disc's second sector
			bsr ntc_ami_dtrack
			tst.w d0
			bne ntc_dl_none
			movea.l ntc_ami_draw, a0
			lea NTC_AMIRAW+64+512+496(a0), a0
			clr.b (a1)
			cmpi.l #"NTCD", (a0)
			bne ntc_dl_have
			move.w 6(a0), d0
			tst.w ntc_ami_dmark
			bne ntc_dl_mark
			move.w d0, ntc_ami_dmark	; the first disc looked at is the boot disc: its mark is the set's
ntc_dl_mark:
			cmp.w ntc_ami_dmark, d0
			bne ntc_dl_have
			move.b 5(a0), (a1)
ntc_dl_have:
			moveq #0, d0
			move.b (a1), d0
			bra ntc_dl_e
ntc_dl_none:
			moveq #0, d0
ntc_dl_e:
			movem.l (sp)+, d1-d3/a0-a1
			rts

;## ntc_ami_files ntc_ami_disk ntc_ami_mem ntc_plat_data
; The disc's files (the Loader class): test/amigabuild.js --file puts them after the program
; and writes their list - an entry is 24 bytes: the name (16, 0 filled, capitals), its disc, its
; first sector, its bytes. The list is read from the boot disc the first time it is wanted.
;@ram
ntc_ami_flist:	dc.l 0				; the list (0: not read yet)
ntc_ami_fcount:	dc.w 0				; its entries
ntc_ami_fwant:	dc.w 0				; the disc the last call wanted and did not find
;@rom
; d0 = 0, or not 0 when the boot disc is not in DF0 or would not read
ntc_ami_finit:
			tst.l ntc_ami_flist
			bne ntc_fi_ok
			movem.l d1-d4/a0, -(sp)
			moveq #0, d0
			bsr ntc_ami_dlabel			; (reads the boot disc's first track)
			cmpi.w #1, d0
			bne ntc_fi_bad
			movea.l ntc_ami_draw, a0
			lea NTC_AMIRAW+64+512+496(a0), a0
			move.w 8(a0), d3			; the list's sector
			move.w 10(a0), d4			; its entries
			move.w d4, ntc_ami_fcount
			moveq #4, d0				; (no files: a list all the same, so this is not done again)
			tst.w d4
			beq ntc_fi_alloc
			move.w d4, d0
			mulu #24, d0
ntc_fi_alloc:
			moveq #0, d1
			bsr ntc_ami_alloc
			tst.l d0
			beq ntc_fi_bad
			movea.l d0, a0
			move.l d0, ntc_ami_flist
			tst.w d4
			beq ntc_fi_done
			moveq #0, d1
			move.w d3, d1
			move.w d4, d2
			mulu #24, d2
			moveq #0, d0
			bsr ntc_ami_dread
			tst.w d0
			beq ntc_fi_done
			clr.l ntc_ami_flist
ntc_fi_bad:
			bsr ntc_ami_doff
			movem.l (sp)+, d1-d4/a0
			moveq #1, d0
			rts
ntc_fi_done:
			movem.l (sp)+, d1-d4/a0
ntc_fi_ok:
			moveq #0, d0
			rts

; ntc_ami_ffind - a0 = a name (0 ended; any case): a1 = its entry, d0 = 0; or d0 = -2 not in the
; list, -9 the list would not read
ntc_ami_ffind:
			movem.l d1-d3/a2-a3, -(sp)
			bsr ntc_ami_finit
			tst.w d0
			beq ntc_ff_list
			moveq #-9, d0
			bra ntc_ff_e
ntc_ff_list:
			movea.l ntc_ami_flist, a1
			move.w ntc_ami_fcount, d3
			bra ntc_ff_next
ntc_ff_l:
			movea.l a0, a2
			movea.l a1, a3
			moveq #15, d2
ntc_ff_c:
			move.b (a2)+, d0
			cmpi.b #'a', d0
			bcs ntc_ff_u
			cmpi.b #'z', d0
			bhi ntc_ff_u
			subi.b #32, d0
ntc_ff_u:
			move.b (a3)+, d1
			cmp.b d0, d1
			bne ntc_ff_no
			tst.b d0
			beq ntc_ff_yes
			dbra d2, ntc_ff_c
			tst.b (a2)					; 16 the same: the name must end there too
			bne ntc_ff_no
ntc_ff_yes:
			moveq #0, d0
			bra ntc_ff_e
ntc_ff_no:
			lea 24(a1), a1
ntc_ff_next:
			dbra d3, ntc_ff_l
			moveq #-2, d0
ntc_ff_e:
			movem.l (sp)+, d1-d3/a2-a3
			rts

; ntc_ami_fdrive - d0 = a disc's number: d0 = the drive it is in (0-3), or -1 (not in any)
ntc_ami_fdrive:
			movem.l d1-d2, -(sp)
			move.w d0, d2
			moveq #0, d1
ntc_fd_l:
			move.w d1, d0
			bsr ntc_ami_dlabel
			cmp.w d2, d0
			beq ntc_fd_in
			addq.w #1, d1
			cmpi.w #4, d1
			bcs ntc_fd_l
			moveq #-1, d1
ntc_fd_in:
			move.l d1, d0
			movem.l (sp)+, d1-d2
			rts

; ntc_ami_fload - a0 = a name, a1 = where to, d1 = the most bytes: d0 = the bytes loaded, or
; -2 not in the list, -8 bigger than that (nothing loaded), -9 would not read, -10 its disc is
; not in a drive (ntc_ami_fwant: which). The motors are off after it.
ntc_ami_fload:
			movem.l d1-d4/a0-a2, -(sp)
			movea.l a1, a2
			move.l d1, d3
			bsr ntc_ami_ffind
			tst.l d0
			bne ntc_fl_e
			moveq #-8, d0
			move.l 20(a1), d4			; its bytes
			cmp.l d3, d4
			bhi ntc_fl_e
			move.w 16(a1), d0			; its disc
			move.w d0, ntc_ami_fwant
			bsr ntc_ami_fdrive
			tst.l d0
			bpl ntc_fl_in
			moveq #-10, d0
			bra ntc_fl_e
ntc_fl_in:
			clr.w ntc_ami_fwant
			moveq #0, d1
			move.w 18(a1), d1			; its first sector
			move.l d4, d2
			movea.l a2, a0
			bsr ntc_ami_dread
			tst.w d0
			beq ntc_fl_ok
			moveq #-9, d0
			bra ntc_fl_e
ntc_fl_ok:
			move.l d4, d0
ntc_fl_e:
			bsr ntc_ami_doff
			movem.l (sp)+, d1-d4/a0-a2
			rts

; ============================================================
; NTC Platform - Sharp X68000 (68000), a disc that boots itself
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The program is a 2HD floppy image (.XDF: 77 tracks, 2 sides, 8 sectors of
; 1024 bytes). The machine's ROM (the IPL) reads the first sector to $2000
; and jumps to it; that sector reads the rest of the program to $10000 with
; the ROM's disc call and starts it. No Human68k is needed.
;
; The program runs in USER mode with A7 (the user stack pointer) as the
; thread; the frame interrupt runs in supervisor mode on the supervisor
; stack, so it never touches the thread and interrupts stay on all the time
; (as on the Mega Drive).
;
; Memory:
;   $000000-$001FFF the 68000's vectors, the ROM's (IOCS) work area and stack
;   $002000-$0023FF the boot sector
;   $002400-$007FFF the program's variables, the library's, then its arrays
;                   (their addresses are 16 bits: VarPtr, Peek, descriptors)
;   $008000-$00FFFF the real stack (ntc_csp: the library's jsr calls), top down
;   $010000-        the program: start, threads, keywords, strings
;   NTC_X68LOG test builds: the console's transcript from $0F0000
;
; The screen and keyboard go through the ROM's calls (IOCS: trap #15 with
; the call's number in d0), which work from user mode: the text screen is 96
; x 32 characters (768 x 512), the ROM's own font. The X68000 keeps its
; hardware registers and video memory for supervisor mode, so anything that
; touches them directly must go through an IOCS call or switch mode first.
;
; Keys: Inkey / Input give the key's character; the cursor keys are &HF0
; &HF1 &HF2 &HF3 (up, down, left, right, as the CPC's), Return 13, ESC 27.
;
; RUN: on the px68k emulator with Sharp's IPL ROM (test/x68run.py). Not on a
; real X68000.
; ============================================================
;@name     Sharp X68000 (68000, boot disc)
;@cpu      68000
;@org      $2000
;@ramorg   $2400
;@ramend   $8000
;@text     byte
;@scrinit  0
;@irq      0
;@cols     96
;@rows     32
; ============================================================

;## ntc_md_vectors ntc_x68_boot
; (the 68000 backend's name for "what comes first": here the boot sector, at $2000. The
; ROM wants its first byte to be $60, a branch.) The disc is the assembler's file: vasm
; -Fbin -coalesced writes the parts in address order, so it holds this sector ($2000), the
; variables' first image ($2400), then the program's code ($10000). The sector reads all
; that follows it to just below NTC_X68CODE, so the code lands where it runs; the start
; code then copies the variables' image down to $2400
NTC_X68CODE	equ $10000			; where the program is loaded and runs
NTC_USTACK	equ $10000			; the real stack's top (user mode)
			bra.s ntc_x68_ipl
			dc.b "NTC BASIC X68000"
			even
ntc_x68_ipl:
			move.w #$9070, d1			; drive 0, 2HD
			move.l #$03000002, d2		; 1024 byte sectors: track 0, side 0, sector 2
			move.l #(ntc_romend-NTC_X68CODE)+(ntc_ramend-ntc_ram), d3
			lea NTC_X68CODE-(ntc_ramend-ntc_ram), a1	; (the variables' image comes first on the disc: the code lands at NTC_X68CODE)
			moveq #$46, d0				; IOCS _B_READ (it carries on over tracks and sides)
			trap #15
			jmp ntc_x68_entry
			dcb.b $2400-*, 0			; the rest of the sector
			org NTC_X68CODE

;## ntc_x68_boot ntc_plat_data ntc_data ntc_plat_screen
ntc_x68_entry:
			lea NTC_X68CODE-(ntc_ramend-ntc_ram), a0	; the variables' first image (read in below the code), to where they live
			lea ntc_ram, a1
			move.l #ntc_ramend-ntc_ram, d0
			beq ntc_xb_nodata
ntc_xb_cp:
			move.b (a0)+, (a1)+
			subq.l #1, d0
			bne ntc_xb_cp
ntc_xb_nodata:
		ifd NTC_X68LOG
			move.l #$0F0000, $0EFFFC	; test builds: the transcript starts empty
		endif
			moveq #2, d1
			moveq #$2A, d0				; IOCS _B_CLR_ST: the whole text screen
			trap #15
			moveq #0, d1
			moveq #0, d2
			moveq #$23, d0				; IOCS _B_LOCATE: home
			trap #15
			lea ntc_x68_vbl, a1
			move.w #$0001, d1			; at every vertical blank
			moveq #$6C, d0				; IOCS _VDISPST
			trap #15
			move.l #ntc_x68_super, $84.w	; trap #1: the supervisor call (20261119-1)
			move.l #NTC_USTACK, a0
			move.l a0, usp
			move.w #$0000, sr			; user mode, the interrupts on: A7 is now the user stack
			jmp ntc_start

; The supervisor call. The X68000 keeps its video, sound and I/O registers for supervisor mode and
; the program runs in user mode (its thread is A7). From #asm:
;           lea my_routine, a0
;           trap #1
; my_routine runs in supervisor mode on the supervisor stack and ends with rts. It may use every
; register (they come back as it leaves them, but a0). Interrupts stay on.
ntc_x68_super:
			jsr (a0)
			rte

; the frame interrupt (supervisor mode, its own stack): count it
ntc_x68_vbl:
			addq.w #1, ntc_ticks
			addq.w #1, ntc_vbl
			rte

;## ntc_plat_data
;@ram
ntc_curx:		dc.b 0				; cursor column (0 based)
ntc_cury:		dc.b 0				; cursor row (0 based)
ntc_scols:		dc.b 96				; columns
ntc_srows:		dc.b 32				; rows
ntc_wrapped:	dc.b 0				; 1 = the last character wrapped to the next line
			even
ntc_ticks:		dc.w 0				; frames since the start
ntc_vbl:		dc.w 0				; frames (ntc_plat_frame waits for it to move)
;@rom

;## ntc_plat_screen ntc_plat_data ntc_data ntc_x68_logs
; ntc_plat_putc - d0.b = character: at the cursor, move on, a new line after the last
; column. Real stack, keeps d2-d7 / a2-a6
ntc_plat_putc:
			movem.l d0-d1, -(sp)
		ifd NTC_X68LOG
			bsr ntc_x68_log
		endif
			moveq #0, d1
			move.b d0, d1
			moveq #$20, d0				; IOCS _B_PUTC
			trap #15
			addq.b #1, ntc_curx
			move.b ntc_curx, d0
			cmp.b ntc_scols, d0
			bcs ntc_pc_nowrap
			move.b #1, ntc_wrapped
			movem.l (sp)+, d0-d1
			bra ntc_nl_do
ntc_pc_nowrap:
			clr.b ntc_wrapped
			movem.l (sp)+, d0-d1
			rts

; ntc_plat_newline - column 0, next row (scrolls at the bottom); nothing straight after a wrap
ntc_plat_newline:
		ifd NTC_X68LOG
			move.l d0, -(sp)
			moveq #10, d0
			bsr ntc_x68_log
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
			bcs ntc_nl_set
			subq.b #1, ntc_cury			; the bottom: the ROM scrolls the text up a row for a line feed there
			bsr ntc_x68_setcur
			move.l d1, -(sp)
			moveq #10, d1
			moveq #$20, d0
			trap #15
			move.l (sp)+, d1
ntc_nl_set:
			bsr ntc_x68_setcur
			move.l (sp)+, d0
			rts

; the ROM's cursor to (ntc_curx, ntc_cury)
ntc_x68_setcur:
			movem.l d0-d2, -(sp)
			moveq #0, d1
			move.b ntc_curx, d1
			moveq #0, d2
			move.b ntc_cury, d2
			moveq #$23, d0				; IOCS _B_LOCATE
			trap #15
			movem.l (sp)+, d0-d2
			rts

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_backspace - back a column and clear it (not past the line's start)
ntc_plat_backspace:
			tst.b ntc_curx
			beq ntc_bs_e
			subq.b #1, ntc_curx
			movem.l d0-d1, -(sp)
			bsr ntc_x68_setcur
			moveq #' ', d1
			moveq #$20, d0
			trap #15
			bsr ntc_x68_setcur
			movem.l (sp)+, d0-d1
ntc_bs_e:
			rts

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_cls - clear the console, the cursor home
ntc_plat_cls:
			movem.l d0-d1, -(sp)
			moveq #2, d1
			moveq #$2A, d0				; IOCS _B_CLR_ST
			trap #15
			clr.b ntc_curx
			clr.b ntc_cury
			clr.b ntc_wrapped
			bsr ntc_x68_setcur
			movem.l (sp)+, d0-d1
			rts

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data ntc_plat_cls
; ntc_plat_mode - d0 = mode: one text mode here (96 x 32), so it clears the screen
ntc_plat_mode:
			bra ntc_plat_cls

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - d0 = column, d1 = row (1 based, kept on the screen)
ntc_plat_locate:
			subq.w #1, d0
			bpl ntc_lo_x0
			moveq #0, d0
ntc_lo_x0:
			cmpi.w #95, d0
			bls ntc_lo_x1
			moveq #95, d0
ntc_lo_x1:
			subq.w #1, d1
			bpl ntc_lo_y0
			moveq #0, d1
ntc_lo_y0:
			cmpi.w #31, d1
			bls ntc_lo_y1
			moveq #31, d1
ntc_lo_y1:
			move.b d0, ntc_curx
			move.b d1, ntc_cury
			clr.b ntc_wrapped
			bra ntc_x68_setcur

;## ntc_x68_logs
		ifd NTC_X68LOG
; test builds (vasm -DNTC_X68LOG): what the console was given, at $0F0000 on (the
; harness reads it): characters, 10 for a new line. $0EFFFC: where the next goes
ntc_x68_log:
			move.l a0, -(sp)
			movea.l $0EFFFC, a0
			cmpa.l #$0FF000, a0
			bcc ntc_lg_full
			move.b d0, (a0)+
			move.l a0, $0EFFFC
ntc_lg_full:
			movea.l (sp)+, a0
			rts
		endif

;## ntc_plat_key ntc_data ntc_plat_data ntc_plat_frame
; ntc_plat_scankey - d0 = a key waiting (its character; the cursor keys $F0-$F3), or 0
ntc_plat_scankey:
			moveq #$01, d0				; IOCS _B_KEYSNS: 0 = none waiting
			trap #15
			tst.l d0
			beq ntc_sk_none
			moveq #$00, d0				; IOCS _B_KEYINP: the scan code in the high byte, the character low
			trap #15
			move.l d1, -(sp)
			move.w d0, d1
			lsr.w #8, d1				; the scan code
			andi.l #$FF, d0
			bne ntc_sk_e				; it has a character
			cmpi.b #$3C, d1
			bne ntc_sk_n1
			move.w #$F0, d0				; up
ntc_sk_n1:
			cmpi.b #$3E, d1
			bne ntc_sk_n2
			move.w #$F1, d0				; down
ntc_sk_n2:
			cmpi.b #$3B, d1
			bne ntc_sk_n3
			move.w #$F2, d0				; left
ntc_sk_n3:
			cmpi.b #$3D, d1
			bne ntc_sk_e
			move.w #$F3, d0				; right
ntc_sk_e:
			move.l (sp)+, d1
			rts
ntc_sk_none:
			moveq #0, d0
			rts

; ntc_plat_getkey - wait for a key: d0 = its code
ntc_plat_getkey:
			bsr ntc_plat_scankey
			tst.b d0
			bne ntc_gk_e
			bsr ntc_plat_frame
			bra ntc_plat_getkey
ntc_gk_e:
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
; ntc_plat_ticks - d0.w = frames since the start (55 a second on the 768 x 512 screen)
ntc_plat_ticks:
			move.w ntc_ticks, d0
			rts

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - before the program stops: a boot disc has nowhere to go back to
ntc_plat_exit:
			rts

; ============================================================
; NTC Platform - Commodore 64 with an REU (6502), direct hardware
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A PRG file loaded at $0801 (LOAD "GAME",8 and RUN): a BASIC line (SYS 2061)
; and the program. The program's thread - the compiled BASIC - does not stay
; in the C64's memory: the start code puts it into the REU (from the end of
; the PRG - or, a c64build.js --split build, from a file of its own, NAME.T,
; unless the REU has it already: an REU image loaded first), and it then runs
; through three 64 byte windows in page 1 ($0100-$01BF), 64 byte pieces of it
; coming in as they are wanted (see asm/ntc_lib_m65.asm, "THE WINDOWS"). The
; C64's own memory keeps the keyword
; library, the call stubs, the variables, the strings and the arrays.
; No REU: a message, and back to BASIC.
;
; The start code then takes the machine over: all RAM and the I/O ($01 = $35,
; no BASIC, no KERNAL), the CIAs' interrupts off, the VIC's raster interrupt
; on (once a frame: Ticks, Frame, the frame hook), its own screen and font.
;
; Memory:
;   $0002-$004F  the library's registers        $0050-$006F  the platform's
;   $0070-$008D  the windows', the multiply's   $008E-$008F  free for a program's #asm
;   $0090-$00FF  the KERNAL's own (left alone: the Disk class calls the KERNAL).
;                $FB-$FE are free, as on any C64
;   $0100-$01BF  the three windows: 64 bytes of thread each
;   $01C0-$01FF  the real stack (the library's jsr calls, interrupts)
;   $0200-$03FF  the KERNAL's own (left alone); $02F0-$02F3 notes for the test tools
;   $0400-$07FF  free
;   $0801-$CFFF  the program (the BASIC line, code, variables, strings, the
;                library), then its arrays. The thread is loaded after the
;                program, over where the arrays will be, and goes to the REU.
;   $D000-$DFFF  I/O (VIC, SID, colour RAM $D800, CIAs, the REU at $DF00)
;   $E000-$E3E7  the screen (40 x 25 characters, ASCII)
;   $E400-$E7FF  free
;   $E800-$EFFF  the font (characters 0-255, 8 bytes each: NTC's 32-127)
;   $F000-$FFF9  free ($FFFA-$FFFF: the NMI / reset / IRQ vectors).
;                NTC_C64LOG test builds keep the console's text in $F000-$F7FF
; The REU: the thread is in bank 0 from $0100, and NTC's own notes are in bank
; 0's $FF00-$FFFF (the Task class's start threads, a --split build's mark).
; Every other bank is the program's (the Reu class).
; With Option Lot the REU is the kernel's 32K (bank 0 $0000-$7FFF: the
; kernel's thread from $0100, the notes at $7F00) and then lots of 96K: lot n
; starts at $8000 + (n - 1) * $18000. A code lot is 64K of its classes' thread
; and 32K of workspace (their stubs, strings and variables), which is in the
; C64's memory at NTC_WS_ORG while the lot runs; any other lot is 96K of data.
;
; Keys: the keyboard matrix (CIA 1), read when asked - no interrupt. RETURN =
; 13, DEL = 8, RUN/STOP = 27, the cursor keys = &HF0 up, &HF1 down, &HF2 left,
; &HF3 right (as the CPC's), letters lower case unless shifted.
; ============================================================
;@name     Commodore 64 + REU (6502)
;@cpu      6502
;@org      $0801
;@text     byte
;@scrinit  0
;@irq      0
;@cols     40
;@rows     25
; ============================================================

;## ntc_c64_stub ntc_c64_boot
; the PRG's start (the compiler puts it first, at $0801): a BASIC line
; "10 SYS 2061" then a jump to the start code
			dw ntc_c64_bnext, 10
			db $9E, "2061", 0				; SYS 2061
ntc_c64_bnext:
			dw 0
			jmp ntc_c64_boot				; 2061 = $080D

;## ntc_c64_boot ntc_plat_data ntc_data ntc_plat_screen ntc_c64_fontdata ntc_plat_exit ntc_plat_key ntc_c64_irq ntc_reu ntc_c64_split
; ------------------------------------------------------------
; the start: is there an REU, the thread into it, the machine taken over,
; the screen, then ntc_start (the thread)
; ------------------------------------------------------------
ntc_c64_boot:
			lda #$A5					; an REU's address registers read back
			sta $DF04
			lda #$5A
			sta $DF05
			lda $DF04
			cmp #$A5
			bne ntc_c64_noreu
			lda $DF05
			cmp #$5A
			beq ntc_c64_b_reu
ntc_c64_noreu:
			ldx #0
ntc_c64_nr_l:
			lda ntc_c64_nrtx,x
			beq ntc_c64_nr_e
			jsr $FFD2					; (the KERNAL is still there)
			inx
			bne ntc_c64_nr_l
ntc_c64_nr_e:
			rts							; back to BASIC
ntc_c64_nrtx:	db 13, "THIS PROGRAM NEEDS AN REU", 13, 0
ntc_c64_smtx:	db 13, "THIS PROGRAM NEEDS A BIGGER REU", 13, 0
; one byte between ntc_c64_ch and the REU at bank X, $00FF (A = $90 out, $91 in)
ntc_c64_rb:
			pha
			lda #<ntc_c64_ch
			sta $DF02
			lda #>ntc_c64_ch
			sta $DF03
			lda #$FF
			sta $DF04
			lda #0
			sta $DF05
			stx $DF06
			sta $DF08
			sta $DF0A
			lda #1
			sta $DF07
			pla
			sta $DF01
			rts
ntc_c64_b_reu:
			; lots (Option Lot): is the REU as big as they need? Its last bank must not be
			; bank 0 seen again. (The byte tried is put back; bank 0's is unused.)
			lda #NTC_REUTOP
			beq ntc_c64_b_big
			ldx #NTC_REUTOP
			lda #$91
			jsr ntc_c64_rb
			lda ntc_c64_ch
			pha
			lda #$A5
			sta ntc_c64_ch
			ldx #0
			lda #$90
			jsr ntc_c64_rb
			lda #$5A
			sta ntc_c64_ch
			ldx #NTC_REUTOP
			lda #$90
			jsr ntc_c64_rb
			ldx #0
			lda #$91
			jsr ntc_c64_rb
			lda ntc_c64_ch
			tay
			pla
			sta ntc_c64_ch
			ldx #NTC_REUTOP
			lda #$90
			jsr ntc_c64_rb
			cpy #$A5
			beq ntc_c64_b_big
			ldx #0
ntc_c64_sm_l:
			lda ntc_c64_smtx,x
			beq ntc_c64_sm_e
			jsr $FFD2
			inx
			bne ntc_c64_sm_l
ntc_c64_sm_e:
			rts
ntc_c64_b_big:
			ifd NTC_C64SPLIT
			jsr ntc_c64_tload			; the thread is a file of its own (the KERNAL reads it)
			bcc ntc_c64_b_thr
			rts							; not found: back to BASIC
ntc_c64_b_thr:
			endif
			sei
			cld
			lda #$2F
			sta $00
			lda #$35					; RAM at $A000 and $E000, I/O at $D000
			sta $01
			ldx #$FF					; the real stack
			txs
			lda #$7F					; the CIAs' interrupts off
			sta $DC0D
			sta $DD0D
			lda $DC0D
			lda $DD0D
			lda #0
			sta $D01A
			lda #$FF
			sta $D019
			lda #0
			sta ntc_wbank
			sta $DF06
			sta $DF09					; no REU interrupts
			sta $DF0A					; both addresses count
			ifnd NTC_C64SPLIT
			; the threads (and the lots' workspaces) into the REU: every blob in ntc_blobs
			lda #<ntc_blobs
			sta $FB
			lda #>ntc_blobs
			sta $FC
			ldx ntc_blob_n
ntc_c64_bl_l:
			ldy #0
			lda ($FB),y
			sta $DF02
			iny
			lda ($FB),y
			sta $DF03
			iny
			lda ($FB),y
			sta $DF07
			sta $50
			iny
			lda ($FB),y
			sta $DF08
			ora $50
			beq ntc_c64_bl_n			; (nothing in it)
			iny
			lda ($FB),y
			sta $DF04
			iny
			lda ($FB),y
			sta $DF05
			iny
			lda ($FB),y
			sta $DF06
			lda #$90					; C64 -> REU, now
			sta $DF01
ntc_c64_bl_n:
			clc
			lda $FB
			adc #7
			sta $FB
			bcc ntc_c64_bl_c
			inc $FC
ntc_c64_bl_c:
			dex
			bne ntc_c64_bl_l
			endif
			; the windows: nothing in any, and the REU's registers for them (page 1,
			; 64 bytes: every fetch reloads them)
			jsr ntc_reu_winreg
			lda #0
			sta ntc_wb
			sta ntc_wb+1
			sta ntc_wth
			sta ntc_wth+1
			sta ntc_wth+2
			sta ntc_wdirty
			sta ntc_wor
			sta ntc_wcur
			sta ntc_wz
			sta ntc_task
			sta ntc_wlot
			sta ntc_wslot
			sta ntc_wtb
			sta ntc_wtb+1
			sta ntc_wtb+2
			lda #1
			sta ntc_wprev
			; vectors (RAM: no KERNAL mapped)
			lda #<ntc_c64_nmi
			sta $FFFA
			lda #>ntc_c64_nmi
			sta $FFFB
			lda #<ntc_c64_boot
			sta $FFFC
			lda #>ntc_c64_boot
			sta $FFFD
			lda #<ntc_c64_irq
			sta $FFFE
			lda #>ntc_c64_irq
			sta $FFFF
			lda #0
			sta ntc_ticks
			sta ntc_ticks+1
			sta ntc_c64_hook
			sta ntc_c64_hook+1
			sta $02F0					; the test tools' notes: the log's length, not ended
			sta $02F1
			sta $02F2
			lda #$5A					; started
			sta $02F3
			lda #0
			sta $D020					; black border and paper
			sta $D021
			sta $D015					; no sprites
			; the font: font8x8 (characters 32-127) at $E800, the rest blank
			lda #<$E800
			sta $50
			lda #>$E800
			sta $51
			ldx #8
			ldy #0
			tya
ntc_c64_fcl:
			sta ($50),y
			iny
			bne ntc_c64_fcl
			inc $51
			dex
			bne ntc_c64_fcl
			ldx #0
ntc_c64_fcp:
			lda ntc_c64_fontdata,x
			sta $E900,x
			lda ntc_c64_fontdata+256,x
			sta $EA00,x
			lda ntc_c64_fontdata+512,x
			sta $EB00,x
			inx
			bne ntc_c64_fcp
			; the VIC: bank 3 ($C000-$FFFF), the screen at $E000, the font at $E800
			lda $DD02
			ora #3
			sta $DD02
			lda $DD00
			and #$FC
			sta $DD00
			lda #$8A
			sta $D018
			lda #$C8
			sta $D016
			lda #1
			sta ntc_c64_pen
			jsr ntc_plat_cls
			lda #$1B					; text, 25 rows, the screen on
			sta $D011
			; the keyboard: CIA 1 port A out, port B in; a key still down (RETURN) is not a press
			lda #$FF
			sta $DC02
			lda #0
			sta $DC03
			jsr ntc_c64_kscan
			sta ntc_c64_kprev
			sta ntc_c64_klast
			; the raster interrupt: line 251, once a frame
			lda #251
			sta $D012
			lda $D011
			and #$7F
			sta $D011
			lda #1
			sta $D01A
			lda #$FF
			sta $D019
			jmp ntc_start				; (the first fetch lets interrupts in)

;## ntc_c64_split ntc_c64_file
; ------------------------------------------------------------
; a --split build: the threads (and the lots' workspaces) from their own
; files - NAME.0, NAME.1 ..., one for each blob in ntc_blobs - into the REU,
; before the machine is taken over (the KERNAL is there). c64build.js writes
; the first file's name and the build's 8 byte mark here, after "NTC!NAM>".
; An REU that has the mark already at NTC's notes (an REU image loaded first,
; or the same program run again) has them: nothing is loaded.
; Carry set: the file was not found (a message is on the screen).
; ------------------------------------------------------------
			ifd NTC_C64SPLIT
				db "NTC!NAM>"
ntc_c64_tnlen:	db 0
ntc_c64_tnam:	ds 16
ntc_c64_tid:	ds 8
ntc_c64_tload:
			lda #0
			sta $DF06
			sta $DF09
			sta $DF0A
			lda #$C0					; the mark in the REU -> $0340
			sta $DF04
			lda #NTC_NOTEH
			sta $DF05
			lda #$40
			sta $DF02
			lda #$03
			sta $DF03
			lda #8
			sta $DF07
			lda #0
			sta $DF08
			lda #$91
			sta $DF01
			ldx #7
ntc_c64_tl1:
			lda $0340,x
			cmp ntc_c64_tid,x
			bne ntc_c64_tl2
			dex
			bpl ntc_c64_tl1
			clc							; the thread is there
			rts
ntc_c64_tl2:
			ldx #0
ntc_c64_tl3:
			lda ntc_c64_tmsg,x
			beq ntc_c64_tl4
			jsr $FFD2
			inx
			bne ntc_c64_tl3
ntc_c64_tl4:
			; every blob in ntc_blobs is a file: NAME.0, NAME.1 ... (the name's last
			; character is the blob's number: 0-9, then A on)
			lda #<ntc_blobs
			sta ntc_c64_tbp
			lda #>ntc_blobs
			sta ntc_c64_tbp+1
			lda #0
			sta ntc_c64_tbn
ntc_c64_tl_b:
			lda ntc_c64_tbn
			cmp #10
			bcc ntc_c64_tl_d
			adc #6						; (carry set: 10 -> "A")
ntc_c64_tl_d:
			adc #$30
			ldx ntc_c64_tnlen
			sta ntc_c64_tnam-1,x
			lda #<ntc_c64_tnam
			sta $FB
			lda #>ntc_c64_tnam
			sta $FC
			lda ntc_c64_tnlen
			sta ntc_c64_fnlen
			lda ntc_c64_tbp
			sta $FD
			lda ntc_c64_tbp+1
			sta $FE
			ldy #4
			lda ($FD),y
			sta ntc_c64_faddr
			iny
			lda ($FD),y
			sta ntc_c64_faddr+1
			iny
			lda ($FD),y
			sta ntc_c64_fbank
			jsr ntc_c64_fread
			lda ntc_c64_fblk
			ora ntc_c64_fblk+1
			beq ntc_c64_tl_nf
			clc
			lda ntc_c64_tbp
			adc #7
			sta ntc_c64_tbp
			bcc ntc_c64_tl_c
			inc ntc_c64_tbp+1
ntc_c64_tl_c:
			inc ntc_c64_tbn
			lda ntc_c64_tbn
			cmp ntc_blob_n
			bne ntc_c64_tl_b
			beq ntc_c64_tl6
ntc_c64_tl_nf:
			ldx #0
ntc_c64_tl5:
			lda ntc_c64_tnf,x
			beq ntc_c64_tl_e
			jsr $FFD2
			inx
			bne ntc_c64_tl5
ntc_c64_tl_e:
			sec
			rts
ntc_c64_tbp:	dw 0
ntc_c64_tbn:	db 0
ntc_c64_tl6:
			lda #0						; the mark into the REU: it has this build's thread now
			sta $DF06
			sta $DF0A
			sta $DF08
			lda #$C0
			sta $DF04
			lda #NTC_NOTEH
			sta $DF05
			lda #<ntc_c64_tid
			sta $DF02
			lda #>ntc_c64_tid
			sta $DF03
			lda #8
			sta $DF07
			lda #$90
			sta $DF01
			clc
			rts
ntc_c64_tmsg:	db 13, "LOADING THE PROGRAM INTO THE REU", 13, 0
ntc_c64_tnf:	db "?ONE OF ITS FILES WAS NOT FOUND", 13, 0
			endif

;## ntc_c64_file ntc_plat_data
; ------------------------------------------------------------
; a file from the disc into the REU, through the KERNAL (which must be there:
; $01 = $36 or $37, its own zero page and vectors as it left them).
; ($FB) = the name, ntc_c64_fnlen its length; ntc_c64_fbank / ntc_c64_faddr =
; where in the REU (it carries on into the next bank). The whole file is
; read, 128 bytes at a time through $0340-$03BF (the cassette buffer).
; ntc_c64_fblk = how many 128 byte blocks came (0: no such file, or no
; drive), ntc_c64_flast = the bytes in the last one (1-128).
; The device is the one the program was loaded from ($BA; 8 if none).
; ------------------------------------------------------------
ntc_c64_fnlen:	db 0
ntc_c64_fbank:	db 0
ntc_c64_faddr:	dw 0
ntc_c64_fblk:	dw 0
ntc_c64_flast:	db 0
ntc_c64_fst:	db 0
ntc_c64_fread:
			lda #0
			sta ntc_c64_fblk
			sta ntc_c64_fblk+1
			sta ntc_c64_flast
			sta $DF09
			; the serial bus at rest first (the drive may still be ending the last file):
			; its clock and data lines both high, or about a fifth of a second gone
			ldx #0
			ldy #0
ntc_c64_fr_i:
			lda $DD00
			and #$C0
			cmp #$C0
			beq ntc_c64_fr_j
			dex
			bne ntc_c64_fr_i
			dey
			bne ntc_c64_fr_i
ntc_c64_fr_j:
			lda #0
			jsr $FF90					; SETMSG: none of the KERNAL's own messages
			lda ntc_c64_fnlen
			ldx $FB
			ldy $FC
			jsr $FFBD					; SETNAM
			ldx $BA
			bne ntc_c64_fr_d
			ldx #8
ntc_c64_fr_d:
			lda #2
			ldy #2
			jsr $FFBA					; SETLFS 2, device, 2
			jsr $FFC0					; OPEN
			bcs ntc_c64_fr_x
			ldx #2
			jsr $FFC6					; CHKIN
			bcs ntc_c64_fr_x
ntc_c64_fr_b:
			ldy #0						; a block: up to 128 bytes
ntc_c64_fr_c:
			sty ntc_c64_flast
			jsr $FFB7					; READST
			and #$BF
			bne ntc_c64_fr_end			; an error (no such file: the drive sends nothing)
			jsr $FFCF					; CHRIN
			ldy ntc_c64_flast
			sta $0340,y
			iny
			sty ntc_c64_flast
			jsr $FFB7
			sta ntc_c64_fst
			ldy ntc_c64_flast
			lda ntc_c64_fst
			bne ntc_c64_fr_end			; the last byte (or an error after it)
			cpy #128
			bne ntc_c64_fr_c
			jsr ntc_c64_fr_put
			jmp ntc_c64_fr_b
ntc_c64_fr_end:
			lda ntc_c64_fst
			and #$BF
			bne ntc_c64_fr_x			; an error: what came in this block is not kept
			ldy ntc_c64_flast
			beq ntc_c64_fr_x
			jsr ntc_c64_fr_put
ntc_c64_fr_x:
			jsr $FFCC					; CLRCHN
			lda #2
			jsr $FFC3					; CLOSE
			rts
; the block (Y bytes at $0340) into the REU, the place moved on
ntc_c64_fr_put:
			sty $DF07
			lda #0
			sta $DF08
			sta $DF0A
			lda #$40
			sta $DF02
			lda #$03
			sta $DF03
			lda ntc_c64_faddr
			sta $DF04
			lda ntc_c64_faddr+1
			sta $DF05
			lda ntc_c64_fbank
			sta $DF06
			lda #$90
			sta $DF01
			clc
			lda ntc_c64_faddr
			adc #128
			sta ntc_c64_faddr
			bcc ntc_c64_fr_p1
			inc ntc_c64_faddr+1
			bne ntc_c64_fr_p1
			inc ntc_c64_fbank
ntc_c64_fr_p1:
			inc ntc_c64_fblk
			bne ntc_c64_fr_p2
			inc ntc_c64_fblk+1
ntc_c64_fr_p2:
			rts
; the same once the program has the machine (the Disk class): the KERNAL in
; for the length of it, the frame's interrupt off (Ticks stand still), and
; afterwards nothing is in any window (the KERNAL's stack went over them)
ntc_c64_fread_k:
			sei
			lda #0
			sta $D01A
			lda #$36					; the KERNAL and the I/O
			sta $01
			jsr ntc_c64_fread
			sei
			lda #$35
			sta $01
			jsr ntc_reu_winreg
			lda #1
			sta ntc_wdirty
			lda #$FF
			sta $D019
			lda #1
			sta $D01A
			cli
			rts

;## ntc_c64_irq ntc_plat_data ntc_data
; ------------------------------------------------------------
; the frame's interrupt: Ticks counted, the windows marked when SP was in one
; (the interrupt's pushes went over thread words), the frame hook called.
; ntc_c64_hook: 0, or a routine to call every frame (jsr, ends with rts;
; it may use A, X, Y and about 16 bytes of stack) - System.FrameHook
; ------------------------------------------------------------
ntc_c64_irq:
			pha
			txa
			pha
			tsx							; (SP is 5 less than it was)
			cpx #$DE					; it was $E3-$FE: on the real stack, with room for all
			bcc ntc_c64_iqd				; this - no window touched. Anything else: SP was in a
			cpx #$FA					; window ($FF is the first window's start: the pushes
			bcc ntc_c64_iq0				; wrapped round into it)
ntc_c64_iqd:
			lda #1
			sta ntc_wdirty
ntc_c64_iq0:
			lda $D019
			sta $D019
			inc ntc_ticks
			bne ntc_c64_iq1
			inc ntc_ticks+1
ntc_c64_iq1:
			lda ntc_c64_hook+1
			beq ntc_c64_iq_e
			tya
			pha
			cld
			jsr ntc_c64_iq_h
			pla
			tay
ntc_c64_iq_e:
			pla
			tax
			pla
			rti
ntc_c64_iq_h:
			jmp (ntc_c64_hook)
; NMI (RESTORE): nothing, but it pushed too
ntc_c64_nmi:
			pha
			lda #1
			sta ntc_wdirty
			pla
			rti

;## ntc_plat_data
ntc_curx:		db 0			; the cursor (0 based)
ntc_cury:		db 0
ntc_scols:		db 40			; the screen's size
ntc_srows:		db 25
ntc_ticks:		dw 0			; frames since the start (the raster interrupt counts)
ntc_c64_hook:	dw 0			; the frame hook (0: none)
ntc_c64_pen:	db 1			; the console's colour (white)
ntc_c64_ch:		db 0
ntc_c64_kprev:	db $FF			; the key seen at the last look ($FF: none)
ntc_c64_klast:	db $FF			; the key last given
ntc_c64_kshift:	db 0			; not 0: a SHIFT is down
ntc_c64_rowlo:	db $00, $28, $50, $78, $A0, $C8, $F0, $18, $40, $68, $90, $B8, $E0
				db $08, $30, $58, $80, $A8, $D0, $F8, $20, $48, $70, $98, $C0
ntc_c64_rowhi:	db $E0, $E0, $E0, $E0, $E0, $E0, $E0, $E1, $E1, $E1, $E1, $E1, $E1
				db $E2, $E2, $E2, $E2, $E2, $E2, $E2, $E3, $E3, $E3, $E3, $E3

;## ntc_plat_screen ntc_plat_data ntc_data
; ------------------------------------------------------------
; the console: screen memory $E000 (ASCII), colours in colour RAM ($D800).
; JSR on the real stack; A, X, Y and the platform's base page ($50-$6F) are used.
; ------------------------------------------------------------
; ntc_plat_putc - A = character (32-126; others are shown as they are)
ntc_plat_putc:
			sta ntc_c64_ch
			ifd NTC_C64LOG
			jsr ntc_c64_log
			endif
			jsr ntc_c64_rowaddr			; $50 = the row's address, $52 = its colours'
			ldy ntc_curx
			lda ntc_c64_ch
			sta ($50),y
			lda ntc_c64_pen
			sta ($52),y
			inc ntc_curx
			lda ntc_curx
			cmp ntc_scols
			bcc ntc_c64_pc_e
			lda #0						; past the end: the next line
			sta ntc_curx
			jmp ntc_c64_down
ntc_c64_pc_e:
			rts

; ntc_plat_newline
ntc_plat_newline:
			ifd NTC_C64LOG
			lda #10
			jsr ntc_c64_log
			endif
			lda #0
			sta ntc_curx
; the cursor down a line, the screen up at the bottom
ntc_c64_down:
			ldx ntc_cury
			inx
			cpx ntc_srows
			bcs ntc_c64_scroll
			stx ntc_cury
			rts
ntc_c64_scroll:
			; rows 1 .. 24 up a row (characters and colours), then a blank last row
			ldx #0
ntc_c64_scr_r:
			lda ntc_c64_rowlo,x
			sta $50
			sta $54
			lda ntc_c64_rowhi,x
			sta $51
			sec
			sbc #8
			sta $55
			lda ntc_c64_rowlo+1,x
			sta $52
			sta $56
			lda ntc_c64_rowhi+1,x
			sta $53
			sec
			sbc #8
			sta $57
			ldy #39
ntc_c64_scr_c:
			lda ($52),y
			sta ($50),y
			lda ($56),y
			sta ($54),y
			dey
			bpl ntc_c64_scr_c
			inx
			cpx #24
			bne ntc_c64_scr_r
			ldy #39
			lda #' '
ntc_c64_scr_b:
			sta ($52),y
			dey
			bpl ntc_c64_scr_b
			rts

; $50 = the cursor row's address in screen memory, $52 = in colour RAM
ntc_c64_rowaddr:
			ldx ntc_cury
			lda ntc_c64_rowlo,x
			sta $50
			sta $52
			lda ntc_c64_rowhi,x
			sta $51
			sec
			sbc #8						; $E000 -> $D800
			sta $53
			rts

; ntc_plat_backspace - back a character and blank it
ntc_plat_backspace:
			lda ntc_curx
			beq ntc_c64_bs_up
			dec ntc_curx
			jmp ntc_c64_bs_blank
ntc_c64_bs_up:
			lda ntc_cury
			beq ntc_c64_bs_e
			dec ntc_cury
			ldx ntc_scols
			dex
			stx ntc_curx
ntc_c64_bs_blank:
			jsr ntc_c64_rowaddr
			ldy ntc_curx
			lda #' '
			sta ($50),y
ntc_c64_bs_e:
			rts

; ntc_plat_cls - blank screen, the pen's colour everywhere, cursor home
ntc_plat_cls:
			lda #<$E000
			sta $50
			sta $52
			lda #>$E000
			sta $51
			lda #>$D800
			sta $53
			ldx #4
			ldy #0
ntc_c64_cls_l:
			lda #' '
			sta ($50),y
			lda ntc_c64_pen
			sta ($52),y
			iny
			bne ntc_c64_cls_l
			inc $51
			inc $53
			dex
			beq ntc_c64_cls_e
			cpx #1
			bne ntc_c64_cls_l
ntc_c64_cls_p:							; the last 232 of the 1000
			lda #' '
			sta ($50),y
			lda ntc_c64_pen
			sta ($52),y
			iny
			cpy #232
			bne ntc_c64_cls_p
ntc_c64_cls_e:
			lda #0
			sta ntc_curx
			sta ntc_cury
			rts

; ntc_plat_mode - A = the mode: the C64 has one (40 x 25). The screen is cleared
ntc_plat_mode:
			jmp ntc_plat_cls

; ntc_plat_locate - X = column, Y = row (1 based)
ntc_plat_locate:
			dex
			cpx ntc_scols
			bcs ntc_c64_loc_e
			dey
			cpy ntc_srows
			bcs ntc_c64_loc_e
			stx ntc_curx
			sty ntc_cury
ntc_c64_loc_e:
			rts

			ifd NTC_C64LOG
; the log (test builds): A into the ring $F000-$F7FF, the count of all written at $02F0
ntc_c64_log:
			pha
			lda $02F0
			sta $58
			lda $02F1
			and #$07
			ora #$F0
			sta $59
			pla
			ldy #0
			sta ($58),y
			inc $02F0
			bne ntc_c64_log_e
			inc $02F1
ntc_c64_log_e:
			rts
			endif

;## ntc_reu ntc_plat_data ntc_data
; ------------------------------------------------------------
; the REU for data (the Reu class). ntc_reu_do: a transfer and the windows'
; registers back. $50 = the C64 address, $52 = the REU address, $54 = its
; bank, $55 = the length (not 0), $57 = the address control ($00, or $80:
; the C64 address stays - a fill), A = the command ($90 C64 -> REU,
; $91 REU -> C64, $92 swap, $93 compare). JSR on the real stack.
; ------------------------------------------------------------
ntc_reu_do:
			pha
			sei
			lda $50
			sta $DF02
			lda $51
			sta $DF03
			lda $52
			sta $DF04
			lda $53
			sta $DF05
			lda $54
			sta $DF06
			lda $55
			sta $DF07
			lda $56
			sta $DF08
			lda $57
			sta $DF0A
			pla
			sta $DF01
; the windows' registers again
ntc_reu_win:
			jsr ntc_reu_winreg
			cli
			rts
; page 1, 64 bytes, the thread's bank (a fetch sets the rest)
ntc_reu_winreg:
			lda #$01
			sta $DF03
			lda #$40
			sta $DF07
			lda #0
			sta $DF08
			sta $DF0A
			lda ntc_wbank
			sta $DF06
			rts
; on the thread: the arguments <bank>, <REU address>, <C64 address>, <bytes> taken
; (each a variable's address), then the transfer A. ntc_reu_m3 for 3 (the C64
; address and $57 set already: jmp ntc_reu_m3 with the command in $58)
ntc_reu_m4:
			sta $58
			lda #0
			sta $57
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $54
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $52
			iny
			lda (z_p0),y
			sta $53
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $50
			iny
			lda (z_p0),y
			sta $51
			jmp ntc_reu_len
ntc_reu_m3:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $54
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $52
			iny
			lda (z_p0),y
			sta $53
ntc_reu_len:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $55
			iny
			lda (z_p0),y
			sta $56
ntc_reu_go:
			lda $55
			ora $56
			beq ntc_reu_go_e
			NTC_RS
			lda $58
			jsr ntc_reu_do
			NTC_TS
ntc_reu_go_e:
			rts
ntc_reu_byte:	dw 0			; a byte or a word on its way
; on the thread: a block of rows, A = the command. The arguments <bank>, <REU address>,
; <REU step>, <C64 address>, <C64 step>, <width>, <rows>: rows transfers of width bytes, each
; address moved on by its step after every one. About 125 cycles a row and a cycle a byte
ntc_reu_rect:
			sta $58
			lda #0
			sta $57
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $54
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $52
			iny
			lda (z_p0),y
			sta $53
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $50
			iny
			lda (z_p0),y
			sta $51
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_b+1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta $55
			iny
			lda (z_p0),y
			sta $56
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_c
			beq ntc_reu_rc_e
			lda $55
			ora $56
			beq ntc_reu_rc_e
			NTC_RS
			; the bank, the width and "both addresses count" once: every row's transfer
			; reloads them (the command's reload bit), so a row is its two addresses and go
			lda $54
			sta $DF06
			lda $55
			sta $DF07
			lda $56
			sta $DF08
			lda #0
			sta $DF0A
			lda $58
			ora #$20
			sta $58
ntc_reu_rc_l:
			lda $50
			sta $DF02
			lda $51
			sta $DF03
			lda $52
			sta $DF04
			lda $53
			sta $DF05
			lda $58
			sta $DF01
			clc
			lda $52
			adc z_a
			sta $52
			lda $53
			adc z_a+1
			sta $53
			clc
			lda $50
			adc z_b
			sta $50
			lda $51
			adc z_b+1
			sta $51
			dec z_c
			bne ntc_reu_rc_l
			jsr ntc_reu_winreg
			NTC_TS
ntc_reu_rc_e:
			rts

;## ntc_tasks ntc_plat_data ntc_data ntc_reu ntc_jmp
; ------------------------------------------------------------
; the Task class: up to 32 tasks, each a place in the thread. Task 0 is the
; program itself. A task is its thread position and nothing else: changing
; task is saving one position and going to another (ntc_goxy), so a task
; whose piece is still in a window costs no fetch at all.
; A new task starts from a 4 byte thread of its own in the REU - the Sub's
; call stub, then ntc_tk_end - in NTC's notes page of lot 0, at $40 + 4 * its
; number. With lots a task is also the lot it was running in and the lot
; whose workspace it had: both are put back when its turn comes.
; All of this runs on the thread (no jsr but through NTC_RS).
; ------------------------------------------------------------
ntc_tk_st:		db 1			; 0 free, 1 ready, 2 asleep
				ds 31
ntc_tk_lo:		ds 32			; where each one is
ntc_tk_hi:		ds 32
ntc_tk_wl:		ds 32			; asleep: the tick to wake at
ntc_tk_wh:		ds 32
ntc_tk_cl:		ds 32			; the lot its thread is in
ntc_tk_ws:		ds 32			; the lot whose workspace it had
ntc_tk_slot:	dw 0, ntc_tk_end-1

; the running task's position kept, then the next one that can run
ntc_tk_yield:
			NTC_POS
			txa
			ldx ntc_task
			sta ntc_tk_lo,x
			tya
			sta ntc_tk_hi,x
			lda ntc_wlot
			sta ntc_tk_cl,x
			lda ntc_wslot
			sta ntc_tk_ws,x
; the next task after the running one that is ready (or asleep and due). With
; every task asleep this waits here
ntc_tk_next:
			ldx ntc_task
ntc_tk_n1:
			inx
			cpx #32
			bcc ntc_tk_n2
			ldx #0
ntc_tk_n2:
			lda ntc_tk_st,x
			beq ntc_tk_n1
			cmp #2
			bne ntc_tk_run
			sei							; asleep: is it time?
			sec
			lda ntc_ticks
			sbc ntc_tk_wl,x
			lda ntc_ticks+1
			sbc ntc_tk_wh,x
			cli
			bmi ntc_tk_n1
			lda #1
			sta ntc_tk_st,x
ntc_tk_run:
			stx ntc_task
			ifne NTC_LOTS
			lda ntc_tk_ws,x
			cmp ntc_wslot
			beq ntc_tk_r1
			NTC_RS						; its lot's workspace back (ntc_goxy sets SP itself)
			ldx ntc_task
			lda ntc_tk_ws,x
			jsr ntc_ws_set
			ldx ntc_task
ntc_tk_r1:
			lda ntc_tk_cl,x
			cmp ntc_wlot
			beq ntc_tk_r2
			sta ntc_wlot
			lda #0
			sta ntc_wb+1
ntc_tk_r2:
			endif
			ldy ntc_tk_hi,x
			lda ntc_tk_lo,x
			tax
			jmp ntc_goxy
; the end of a task's Sub (a thread word: the Sub came back to its start thread)
ntc_tk_end:
			ldx ntc_task
			lda #0
			sta ntc_tk_st,x
			jmp ntc_tk_next
; z_p1 = a Sub's call stub: a new task for it. A = its number, or $FF (32 running)
ntc_tk_start:
			ldx #1
ntc_tk_s1:
			lda ntc_tk_st,x
			beq ntc_tk_s2
			inx
			cpx #32
			bne ntc_tk_s1
			lda #$FF
			rts
ntc_tk_s2:
			stx $5E
			sec							; its start thread: the stub (a code word: - 1), ntc_tk_end
			lda z_p1
			sbc #1
			sta ntc_tk_slot
			lda z_p1+1
			sbc #0
			sta ntc_tk_slot+1
			lda #<ntc_tk_slot
			sta $50
			lda #>ntc_tk_slot
			sta $51
			txa
			asl
			asl
			clc
			adc #$40
			sta $52
			sta ntc_tk_lo,x
			lda #NTC_NOTEH
			sta $53
			sta ntc_tk_hi,x
			lda #4
			sta $55
			lda #0
			sta $56
			sta $57
			sta $54
			sta ntc_tk_cl,x				; (it starts in the kernel, with no lot's workspace)
			sta ntc_tk_ws,x
			lda #$90
			jsr ntc_reu_do
			ldx #2						; a window holding the start threads is out of date
ntc_tk_s3:
			lda ntc_wth,x
			cmp #NTC_NOTEH
			bne ntc_tk_s4
			lda ntc_wtb,x
			bne ntc_tk_s4
			sta ntc_wth,x
ntc_tk_s4:
			dex
			bpl ntc_tk_s3
			ldx $5E
			lda #1
			sta ntc_tk_st,x
			txa
			rts

;## ntc_lots ntc_reu ntc_jmp ntc_data ntc_plat_data
; ------------------------------------------------------------
; Option Lot: going into a lot and back, and its workspace.
; A lot's Sub called from outside the lot is reached through p_name_e in the
; kernel (lda #entry, jmp ntc_lot_enter): the caller's position, lot and
; workspace are kept in the entry's own 4 bytes (ntc_ent_sv), the lot's
; workspace is brought in, and the lot's thread runs from p_name_t - the
; Sub's call, then ntc_lot_ret with the entry's number - which puts it all
; back. An entry is not re-entrant, like a Sub's own return.
; ------------------------------------------------------------
ntc_le_k:		db 0
ntc_ws_new:		db 0
ntc_lot_enter:
			sta ntc_le_k
			NTC_POS
			stx z_t0
			sty z_t1
			lda ntc_le_k
			asl
			asl
			tax
			lda z_t0
			sta ntc_ent_sv,x
			lda z_t1
			sta ntc_ent_sv+1,x
			lda ntc_wlot
			sta ntc_ent_sv+2,x
			lda ntc_wslot
			sta ntc_ent_sv+3,x
			NTC_RS
			ldx ntc_le_k
			lda ntc_ent_lot,x
			jsr ntc_ws_set
			ldx ntc_le_k
			lda ntc_ent_lot,x
			sta ntc_wlot
			lda #0
			sta ntc_wb+1
			ldy ntc_ent_hi,x
			lda ntc_ent_lo,x
			tax
			jmp ntc_goxy
; a thread word, followed by the entry's number: the lot's Sub is done
ntc_lot_ret:
			pla
			asl
			asl
			sta ntc_le_k
			pla
			NTC_RS
			ldx ntc_le_k
			lda ntc_ent_sv+3,x
			jsr ntc_ws_set
			ldx ntc_le_k
			lda ntc_ent_sv+2,x
			sta ntc_wlot
			lda #0
			sta ntc_wb+1
			ldy ntc_ent_sv+1,x
			lda ntc_ent_sv,x
			tax
			jmp ntc_goxy
; A = a lot (0: none): its workspace into the C64's memory at NTC_WS_ORG, the
; one that was there - its variables, the part that changes - back to the REU.
; A lot's workspace is in the REU 64K past the lot's start. JSR, real stack
ntc_ws_set:
			cmp ntc_wslot
			beq ntc_ws_e
			sta ntc_ws_new
			lda ntc_wslot
			beq ntc_ws_in
			asl
			tax
			lda ntc_lot_vsz,x
			sta $55
			lda ntc_lot_vsz+1,x
			sta $56
			ora $55
			beq ntc_ws_in
			clc
			lda #<NTC_WS_ORG
			adc ntc_lot_vof,x
			sta $50
			lda #>NTC_WS_ORG
			adc ntc_lot_vof+1,x
			sta $51
			ldy ntc_wslot
			lda ntc_lot_vof,x
			sta $52
			clc
			lda ntc_lot_vof+1,x
			adc ntc_lot_bh,y
			sta $53
			lda ntc_lot_bb,y
			adc #1
			sta $54
			lda #0
			sta $57
			lda #$90
			jsr ntc_reu_do
ntc_ws_in:
			lda ntc_ws_new
			sta ntc_wslot
			beq ntc_ws_e
			asl
			tax
			lda ntc_lot_wsz,x
			sta $55
			lda ntc_lot_wsz+1,x
			sta $56
			ora $55
			beq ntc_ws_e
			lda #<NTC_WS_ORG
			sta $50
			lda #>NTC_WS_ORG
			sta $51
			ldy ntc_wslot
			lda #0
			sta $52
			sta $57
			lda ntc_lot_bh,y
			sta $53
			clc
			lda ntc_lot_bb,y
			adc #1
			sta $54
			lda #$91
			jsr ntc_reu_do
ntc_ws_e:
			rts

;## ntc_c64_bits
; a bit for each of 0-7 (the Vic class: a sprite's bit in the VIC's registers)
ntc_c64_bit:	db 1, 2, 4, 8, 16, 32, 64, 128

;## ntc_plat_key ntc_plat_data
; ------------------------------------------------------------
; the keyboard: the matrix through CIA 1 (port A selects, port B reads)
; ------------------------------------------------------------
; A = the key down now (column * 8 + row, 0-63: the first found that is not
; SHIFT) or $FF; ntc_c64_kshift set. Uses X, Y, $5A-$5C
ntc_c64_kscan:
			lda #0
			sta ntc_c64_kshift
			lda #$FF
			sta $5C						; the key found
			lda #$FE
			sta $5A						; the column's select (one bit low)
			ldx #0						; column * 8
ntc_c64_ks_c:
			lda $5A
			sta $DC00
ntc_c64_ks_s:
			lda $DC01					; (read twice the same: settled)
			cmp $DC01
			bne ntc_c64_ks_s
			eor #$FF
			beq ntc_c64_ks_n
			sta $5B
			ldy #0
ntc_c64_ks_r:
			lsr $5B
			bcc ntc_c64_ks_r1
			stx $5D
			tya
			clc
			adc $5D						; the key's number
			cmp #15						; left SHIFT
			beq ntc_c64_ks_sh
			cmp #52						; right SHIFT
			beq ntc_c64_ks_sh
			bit $5C
			bpl ntc_c64_ks_r1			; (one found already)
			sta $5C
			jmp ntc_c64_ks_r1
ntc_c64_ks_sh:
			sta ntc_c64_kshift
ntc_c64_ks_r1:
			iny
			cpy #8
			bne ntc_c64_ks_r
ntc_c64_ks_n:
			txa
			clc
			adc #8
			tax
			sec
			rol $5A
			cpx #64
			bne ntc_c64_ks_c
			lda #$FF					; (port A idle: the joystick in port 2 reads clean)
			sta $DC00
			lda $5C
			rts

; ntc_plat_scankey - A = a key just pressed, or 0. No wait, no repeat. A press
; counts when two looks running see the same key
ntc_plat_scankey:
			jsr ntc_c64_kscan
			cmp ntc_c64_kprev
			beq ntc_c64_sk_same
			sta ntc_c64_kprev
			lda #0
			rts
ntc_c64_sk_same:
			cmp ntc_c64_klast
			bne ntc_c64_sk_new
			lda #0
			rts
ntc_c64_sk_new:
			sta ntc_c64_klast
			cmp #$FF
			bne ntc_c64_sk_ch
			lda #0
			rts
ntc_c64_sk_ch:
			tax
			lda ntc_c64_kshift
			bne ntc_c64_sk_sh
			lda ntc_c64_keys,x
			rts
ntc_c64_sk_sh:
			lda ntc_c64_keyss,x
			rts

; ntc_plat_getkey - A = the next key (waits)
ntc_plat_getkey:
			jsr ntc_plat_scankey
			cmp #0
			beq ntc_plat_getkey
			rts

; the matrix as ASCII: column * 8 + row. 0 = no character (the F keys, HOME, CTRL, C=)
ntc_c64_keys:
			db 8, 13, $F3, 0, 0, 0, 0, $F1					; DEL RETURN right F7 F1 F3 F5 down
			db "3", "w", "a", "4", "z", "s", "e", 0			; (left SHIFT)
			db "5", "r", "d", "6", "c", "f", "t", "x"
			db "7", "y", "g", "8", "b", "h", "u", "v"
			db "9", "i", "j", "0", "m", "k", "o", "n"
			db "+", "p", "l", "-", ".", ":", "@", ","
			db 92, "*", ";", 0, 0, "=", "^", "/"			; pound = \  HOME  (right SHIFT)  =  up arrow = ^  /
			db "1", "_", 0, "2", " ", 0, "q", 27			; 1  left arrow = _  CTRL  2  SPACE  C=  Q  RUN/STOP
ntc_c64_keyss:
			db 8, 13, $F2, 0, 0, 0, 0, $F0					; (shifted: left, up)
			db "#", "W", "A", "$", "Z", "S", "E", 0
			db "%", "R", "D", "&", "C", "F", "T", "X"
			db "'", "Y", "G", "(", "B", "H", "U", "V"
			db ")", "I", "J", "0", "M", "K", "O", "N"
			db "{", "P", "L", "}", ">", "[", "`", "<"
			db "|", "*", "]", 0, 0, "=", "~", "?"
			db "!", "_", 0, 34, " ", 0, "Q", 27

;## ntc_plat_ticks ntc_plat_data
; ntc_plat_ticks - frames since the start: A = low, X = high
ntc_plat_ticks:
			lda ntc_ticks
			ldx ntc_ticks+1
			cmp ntc_ticks				; (the interrupt came between the two: again)
			bne ntc_plat_ticks
			rts

;## ntc_plat_frame ntc_plat_ticks
; ntc_plat_frame - wait for the next frame (the raster interrupt)
ntc_plat_frame:
			lda ntc_ticks
ntc_c64_fr_w:
			cmp ntc_ticks
			beq ntc_c64_fr_w
			rts

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - End: the console stays, the end marked for the test tools
ntc_plat_exit:
			lda #$A5
			sta $02F2
			rts
ntc_plat_exit_stop:
			jsr ntc_plat_exit
			cli							; (the frame hook - music - carries on)
ntc_c64_halt:
			jmp ntc_c64_halt

;## ntc_c64_fontdata
; font8x8_basic (public domain, Daniel Hepper): characters 32-127, 8 bytes each
ntc_c64_fontdata:
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

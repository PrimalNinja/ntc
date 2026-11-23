; ============================================================
; NTC Platform - SNK Neo Geo CD (68000, CD-ROM: front loader, top loader, CDZ)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The cartridge platform's (ntc_plat_neogeo.asm) as a CD game: the CD BIOS loads
; the files IPL.TXT names into their memories (test/ncdbuild.js makes the disc):
; this program (the .PRG, at 0 in the 2 MB of program RAM: its vectors and the
; Neo Geo header at $100 as a cartridge's), the fix tiles (.FIX), the sprites'
; tiles (.SPR), the Z80's program (.Z80: NTC's driver) and the ADPCM samples
; (.PCM). Then it calls USER ($122) as the cartridge's BIOS does: request 0 / 1
; back to the BIOS, 2 / 3 the program, in USER mode with A7 the thread.
; The VBlank interrupt (vectors 25 and 26 both: level 1 or level 2, whichever the
; machine gives it; acknowledged as all three) calls the BIOS's SYSTEM_IO each
; frame: the CD BIOS plays the CD audio tracks from there.
;
; Memory: the program RAM is 2 MB, $000000-$1FFFFF, with NO 64K mirror: $110000 is
; RAM of its own. NTC's 16 bit addresses are sign extended and $100000 added (;@a16),
; so they reach $0F8000-$107FFF, and the variables live there:
;   $000000-$0F7FFF the program (its vectors, the header, the code, the RAM block's image)
;   $0F8000-$107FFF the program's variables, the library's, then its arrays (64K)
;   $108000-$10BFFF free
;   $10C000-$10DFFF free (NTC_NGLOG test builds: the console transcript)
;   $10E000-$10E7FF the real stack (ntc_csp: the library's jsr calls)
;   $10E800-$10F2FF free (the supervisor stack is the BIOS's, below $10F300)
;   $10F300-$10FFFF the BIOS's
;   $110000-$1FFFFF free
;
; The console, the pads and the sound driver are the cartridge's: this file is only what is the CD's
; own (;@base neogeo: the rest of ntc_plat_neogeo.asm, and its classes, lib/neogeo/).
; CD audio: the driver's $40 t / $41 messages put a request in the Z80's RAM at $FEF8
; (the header's CDDA flag, $107, is 0: that place), which the BIOS takes in SYSTEM_IO:
; track t (BCD) played and, at its end, played again; or stopped.
; ============================================================
;@name     SNK Neo Geo CD (68000)
;@base     neogeo
;@cpu      68000
;@org      0
;@ramorg   $0F8000
;@ramend   $108000
;@a16     $100000
;@text     byte
;@scrinit  0
;@irq      0
;@cols     40
;@rows     28
; ============================================================

;## ntc_md_vectors ntc_ng_boot
; the program's vectors (the BIOS's routines for the exceptions and the CD's interrupts) and
; the Neo Geo header (the compiler puts this first, at 0; the BIOS loads the .PRG there)
			dc.l $0010F300				; the supervisor stack
			dc.l $00C00402				; reset: the BIOS
			dc.l $00C00408, $00C0040E, $00C00414, $00C0041A	; bus, address, illegal, zero divide
			dc.l $00C0041A, $00C0041A, $00C0041A, $00C00420	; CHK, TRAPV, privilege, trace
			dc.l $00C00426, $00C00426					; line 1010, 1111
			dcb.l 3, $FFFFFFFF			; 12-14
			dc.l $00C0042C				; 15 uninitialised interrupt
			dcb.l 5, $FFFFFFFF			; 16-20
			dc.l $00C004F2				; 21 the CD: data ready
			dc.l $00C004EC				; 22 the CD: its drive's messages
			dc.l $00C004E6				; 23 the CD
			dc.l $00C004E0				; 24 spurious
			dc.l ntc_ng_vbl				; 25 level 1: VBlank (or the timer: never on)
			dc.l ntc_ng_vbl				; 26 level 2: VBlank (or the timer)
			dc.l ntc_ng_rte				; 27 level 3
			dcb.l 4, ntc_ng_rte			; 28-31
			dcb.l 32, $FFFFFFFF			; 32-63
; the header ($100): test/ngbuild.js puts in the NGH number and the name
			dc.b "NEO-GEO", 0			; ($107, the 0: the CDDA flag - the CD audio requests at the Z80's $FEF8)
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
			dcb.b 70, $FF				; $13A ($FFFF: the CDDA requests' place the default one)
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
; 2 / 3: the variables' RAM cleared and the RAM block copied from its image, the
; screen, the sound driver's count; then user mode on the real stack and into ntc_start
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
			lea $000F8000, a0			; RAM cleared, the variables' up to the real stack's top
			move.w #(($10E800-$F8000)/4)-1, d0
ntc_nb_clr:
			clr.l (a0)+
			dbra d0, ntc_nb_clr
			move.b d0, REG_WATCHDOG
			lea ntc_romend, a0			; the RAM block's first image, from the program's end
			lea ntc_ram, a1
			move.l #ntc_ramend-ntc_ram, d0
			beq ntc_nb_nodata
ntc_nb_cp:
			move.b (a0)+, (a1)+
			subq.l #1, d0
			bne ntc_nb_cp
ntc_nb_nodata:
			move.b d0, REG_WATCHDOG
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
; watchdog kicked, the BIOS's SYSTEM_IO (the CD audio), counted, the pads
; read, the frame hook run
ntc_ng_vbl:
			btst #7, BIOS_SYSTEM_MODE
			bne ntc_nv_game
			jmp $00C00438				; SYSTEM_INT1
ntc_nv_game:
			move.w #7, REG_IRQACK
			move.b d0, REG_WATCHDOG
			movem.l d0-d7/a0-a6, -(sp)
			jsr $00C0044A				; SYSTEM_IO
			movem.l (sp)+, d0-d7/a0-a6
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

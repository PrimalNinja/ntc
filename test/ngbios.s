; ngbios.s - a small stand-in Neo Geo AES system ROM for testing NTC's neogeo platform in an
; emulator (Geolith wants aes.zip: neo-epo.bin and 000-lo.lo). It is NOT SNK's BIOS: it does only
; what a cartridge built by NTC needs from one, the same way SNK's does it:
;   - the 68000's vectors at $C00000 and the BIOS's jump table from $C00402 (the addresses every
;     cartridge's vectors and header point at);
;   - at reset: the hardware quiet (the watchdog kicked, RAM, palettes and VRAM cleared), the
;     cartridge's fix tiles and vectors switched in;
;   - the cartridge's USER routine ($000122) called with BIOS_USER_REQUEST ($10FDAE) 0 (start-up
;     init), then 2 (the game) with BIOS_SYSTEM_MODE ($10FD80) bit 7 set (the game is running);
;   - SYSTEM_INT1 ($C00438): the BIOS's own VBlank (the cartridge's handler jumps there while
;     BIOS_SYSTEM_MODE bit 7 is clear): acknowledged, the watchdog kicked;
;   - SYSTEM_RETURN ($C00444): back to whoever called USER; SYSTEM_IO ($C0044A): nothing.
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
;   vasmm68k_mot -quiet -spaces -Fbin -o ngbios.bin ngbios.s   (test/ngbuild.js does this, and
;   byte-swaps it into neo-epo.bin, the way the emulators want a Neo Geo ROM)

REG_WATCHDOG	equ $300001
REG_IRQACK		equ $3C000C
REG_VRAMADDR	equ $3C0000
REG_VRAMRW		equ $3C0002
REG_VRAMMOD		equ $3C0004
REG_LSPCMODE	equ $3C0006
REG_SWPROM		equ $3A0013
REG_CRTFIX		equ $3A001B
REG_PALBANK0	equ $3A001F
BIOS_SYSTEM_MODE	equ $10FD80
BIOS_USER_REQUEST	equ $10FDAE

			org $C00000
			dc.l $0010F300				; the supervisor stack
			dc.l bi_entry				; reset
			dcb.l 23, bi_error			; 2-24
			dc.l bi_vbl					; 25 level 1: VBlank
			dc.l bi_rte					; 26 level 2: the timer
			dc.l bi_rte					; 27 level 3: the reset interrupt
			dcb.l 4, bi_rte				; 28-31
			dcb.l 32, bi_error			; 32-63

			dcb.b $C00402-*, $FF		; the jump table (jmp abs.l each: 6 bytes, written out so the assembler can't shorten them)
			dc.w $4EF9
			dc.l bi_entry				; $C00402 BIOS_INIT_HARDWARE
			dc.w $4EF9
			dc.l bi_error				; $C00408 bus error
			dc.w $4EF9
			dc.l bi_error				; $C0040E address error
			dc.w $4EF9
			dc.l bi_error				; $C00414 illegal instruction
			dc.w $4EF9
			dc.l bi_error				; $C0041A division by zero, CHK, TRAPV, privilege
			dc.w $4EF9
			dc.l bi_error				; $C00420 trace
			dc.w $4EF9
			dc.l bi_error				; $C00426 line 1010 / 1111
			dc.w $4EF9
			dc.l bi_error				; $C0042C uninitialised interrupt
			dc.w $4EF9
			dc.l bi_error				; $C00432 spurious interrupt
			dc.w $4EF9
			dc.l bi_vbl					; $C00438 SYSTEM_INT1
			dc.w $4EF9
			dc.l bi_rte					; $C0043E SYSTEM_INT2
			dc.w $4EF9
			dc.l bi_return				; $C00444 SYSTEM_RETURN
			dc.w $4EF9
			dc.l bi_io					; $C0044A SYSTEM_IO

bi_entry:
			move.w #$2700, sr
			lea $0010F300, sp
			move.b d0, REG_WATCHDOG
			move.w #7, REG_IRQACK
			move.w #0, REG_LSPCMODE
			move.b d0, REG_PALBANK0
			lea $00100000, a0			; RAM
			move.w #$F300/4-1, d0
bi_ram:
			clr.l (a0)+
			dbra d0, bi_ram
			move.b d0, REG_WATCHDOG
			lea $00400000, a0			; the palettes (bank 0)
			move.w #$2000/4-1, d0
bi_pal:
			clr.l (a0)+
			dbra d0, bi_pal
			move.w #0, REG_VRAMADDR		; VRAM
			move.w #1, REG_VRAMMOD
			move.w #$8000-1, d0
bi_vram:
			move.w #0, REG_VRAMRW
			dbra d0, bi_vram
			move.b d0, REG_WATCHDOG
			move.w #$8000, REG_VRAMADDR	; the sprites' second and third tables
			move.w #$600-1, d0
bi_scb:
			move.w #0, REG_VRAMRW
			dbra d0, bi_scb
			move.w #$7000, REG_VRAMADDR	; the fix layer: spaces
			move.w #$500-1, d0
bi_fix:
			move.w #$0020, REG_VRAMRW
			dbra d0, bi_fix
			move.b d0, REG_WATCHDOG
			move.b #1, REG_CRTFIX		; the cartridge's fix tiles
			move.b #1, REG_SWPROM		; the cartridge's vectors
			clr.b BIOS_SYSTEM_MODE
			clr.b BIOS_USER_REQUEST		; 0: start-up init
			jsr $000122
			move.w #$2700, sr
			lea $0010F300, sp
			move.b #$80, BIOS_SYSTEM_MODE	; the game is running
			move.b #2, BIOS_USER_REQUEST	; 2: the game
			jsr $000122
bi_stop:
			move.b d0, REG_WATCHDOG
			bra bi_stop

bi_vbl:
			move.w #4, REG_IRQACK
			move.b d0, REG_WATCHDOG
bi_rte:
			rte
bi_return:
			rts							; (the cartridge jumps here with USER's return address on the stack)
bi_io:
			rts
bi_error:
			move.w #$2700, sr
bi_err1:
			move.b d0, REG_WATCHDOG
			bra bi_err1

			dcb.b $C20000-*, $FF		; (128K)

; ============================================================
; NTC Platform - ColecoVision cartridge, as Bare Metal with the ROM keys filled in
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; src/asm/ntc_plat_baremetal.asm with the keys a cartridge ROM needs (;@rom,
; ;@ram ...) and a ntc_plat_romhead (the ColecoVision header and start).
;
; Memory:  ROM #8000-#FFFF (32K cartridge; the BIOS is #0000-#1FFF)
;          RAM #6000-#63FF (1K, mirrored to #7FFF)
;            #6000 -      the variables, then the arrays and the heap
;            - #63FF      the stack (128 bytes and up)
; Video:   TMS9918A, data #BE, control #BF. The program owns it: no BIOS calls.
;          Print counts the column only - the program draws (src/test/coleco/ball's
;          Coleco.cls).
; NMI:     the VDP's frame interrupt is the Z80's NMI on a ColecoVision, and it pushes on
;          SP. NTC's SP is the thread (in the ROM), so the program keeps it OFF: VDP R#1
;          bit 5 = 0 (ntc_cv_start does this, and a program must not set it). The frame is
;          polled instead: status bit 7 (Frame, Coleco.Frame).
; IRQ:     none (the Z80's INT is not connected on a ColecoVision). Build with Option Turbo.
; Tools:   tools/coleco - build.js (a .col ROM), run.mjs (a model of the hardware: the checks).
; ============================================================
;@name     ColecoVision - cartridge (bare metal)
;@org      #8000
;@text     byte
;@scrinit  0
;@irq      0
;@cols     32
;@rows     24
;@rom      #8000 #FFFF
;@ram      #6000
;@ramtop   #6400
;@romfile  COL
;@romsizes 8 16 24 32
; ============================================================

;## ntc_plat_romhead
; ------------------------------------------------------------
; The ColecoVision cartridge header (the compiler puts this section at #8000):
;   #8000  #55, #AA = no title screen, no delay (#AA, #55 = the title screen and the
;          10 second wait, with the title text at #8024)
;   #8002  four RAM pointers the BIOS's sprite and controller routines use (0: not used)
;   #800A  the start address
;   #800C  the RST #08 ... #38 vectors, then the NMI vector at #8021
; ------------------------------------------------------------
			db #55, #AA
			dw 0					; sprite name table (BIOS sprite routines): not used
			dw 0					; sprite order table: not used
			dw 0					; work buffer: not used
			dw 0					; controller map: not used
			dw ntc_cv_start
			jp ntc_cv_ret			; #800C RST #08
			jp ntc_cv_ret			; #800F RST #10
			jp ntc_cv_ret			; #8012 RST #18
			jp ntc_cv_ret			; #8015 RST #20
			jp ntc_cv_ret			; #8018 RST #28
			jp ntc_cv_ret			; #801B RST #30
			jp ntc_cv_ret			; #801E RST #38 (INT - not connected)
			jp ntc_cv_nmi			; #8021 NMI (the BIOS jumps here; the VDP's is off)
ntc_cv_ret:
			ret
ntc_cv_nmi:
			retn
ntc_cv_start:
			di
			ld sp, #6400			; the stack at the top of the 1K of RAM
			in a, (#BF)				; the VDP: its control latch reset, its frame flag clear
			ld a, #80				; R#1: 16K, display off, frame interrupt (NMI) OFF
			out (#BF), a
			ld a, #81
			out (#BF), a
			ld hl, ntc_cv_end
			push hl					; End comes back here
			jp ntc_start
ntc_cv_end:
			di
			halt					; stopped

;## ntc_plat_data
ntc_curx:		db 0			; column (0 based) - counted for Tab
ntc_cury:		db 0			; row (0 based)
ntc_scols:		db 32			; columns
ntc_srows:		db 24			; rows

;## ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_putc - A = the character (32-126) to show: nothing yet (the program draws with the
; Coleco class), the column is counted
ntc_plat_putc:
			ld hl, ntc_curx
			inc (hl)
			jp (ix)

ntc_plat_newline:
			xor a
			ld (ntc_curx), a
			jp (ix)

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_backspace:
			ld a, (ntc_curx)
			or a
			jr z, ntc_bs_none
			dec a
			ld (ntc_curx), a
ntc_bs_none:
			jp (ix)

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_cls:
			xor a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_mode:
			jp (ix)

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_locate:
			ld a, h
			or a
			jr z, ntc_lc_x0
			dec a
ntc_lc_x0:
			ld (ntc_curx), a
			ld a, l
			or a
			jr z, ntc_lc_y0
			dec a
ntc_lc_y0:
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_key ntc_data
; no keyboard: a key is 0, GetKey never returns (the program reads the joystick: Coleco.Joy)
ntc_plat_scankey:
			xor a
			jp (ix)

ntc_plat_getkey:
ntc_gk_wait:
			jr ntc_gk_wait
			jp (ix)

;## ntc_plat_frame
; ntc_plat_frame - wait for the next frame: the VDP's frame flag (status bit 7), polled
ntc_plat_frame:
ntc_fr_wait:
			in a, (#BF)
			rlca
			jr nc, ntc_fr_wait
			jp (ix)

;## ntc_plat_ticks
ntc_plat_ticks:
			ld hl, 0
			jp (ix)

;## ntc_plat_exit ntc_plat_data
ntc_plat_exit:
			jp (ix)

;## ntc_plat_memtop
; the first byte the Memory class's heap must not use: 128 bytes under the top of RAM are the stack's
ntc_plat_memtop:
			ld hl, #6380
			ret

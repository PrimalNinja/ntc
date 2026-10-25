; ============================================================
; NTC Platform - MSX (MSX1, MSX2, MSX2+, turbo R): a cartridge ROM
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; No call, no push in the thread: every routine is entered with jp,
; return address in IX, and ends with jp (ix). The routines that need a
; stack (BIOS calls, the video chip) get the real one through ntc_vcall
; (asm/ntc_lib_vdp.asm).
;
; The program is a cartridge: ROM at #4000-#BFFF (16K or 32K - the file
; NAME.ROM, "AB" header). The BIOS calls its INIT at the start; it puts
; this cartridge's slot in page 2 too (a 32K ROM) and runs the program.
; The code, the threads and the strings stay in the ROM; the variables go
; to RAM (romLayout in the compiler). The RAM:
;   #C000 - #C006   page 2's slot and H.TIMI as they were (End puts them back)
;   #C010 - ...     the variables, then the arrays, the Memory heap
;   ... - the BIOS's stack (the program runs on it; 512 bytes kept free)
; End goes back to the BIOS (on to MSX-BASIC, or the next cartridge).
; The BIOS stays in page 0: its interrupt handler (keys, JIFFY) runs.
;
; Screen  the MSX's own video chip (its ports from the BIOS, #0006: #98
;         on every MSX): mode 1 = 40 x 24 (Text 1), mode 0 = 32 x 24
;         (Graphics 1), mode 2 = 80 x 24 (Text 2) on an MSX2 and up (40 on
;         an MSX1). The BIOS's font, white on dark blue.
; Keys    the BIOS's keyboard buffer (CHSNS, CHGET): the machine's own
;         layout, auto repeat, the codes the BIOS gives (cursor keys 28-31,
;         BS 8, ESC 27). Interrupts get in during the call.
; IRQ     the BIOS's (IM 1, the VDP's frame interrupt). Ticks = JIFFY (50
;         a second on a PAL MSX, 60 on an NTSC one). Normal mode's handler
;         (interrupt classes, Interrupt hook) is on H.TIMI. Interrupts get
;         in only in normal mode's safe points and while waiting (a key,
;         Frame), as on the CPC.
; ============================================================
;@name     MSX - cartridge, the MSX's own video chip
;@org      #4000
;@text     byte
;@scrinit  1
;@irq      1
;@cols     40
;@rows     24
;@rom      #4000 #C000
;@ram      #C010
;@ramtop   #E000
;@romfile  ROM
;@romsizes 16 32
;@irqrate  50
;@islc     1
;@vdp      1
; ============================================================

;## ntc_plat_romhead
; ------------------------------------------------------------
; The cartridge's header (the compiler puts this section at #4000) and
; its INIT: page 2's slot kept, this cartridge's slot put there, then
; ntc_start on the BIOS's stack (End returns to the BIOS)
; ------------------------------------------------------------
NTC_MSXP2		equ #C000		; page 2's slot as it was (put back at End)
NTC_MSXHK		equ #C001		; H.TIMI's 5 bytes as they were
NTC_MSXIQ		equ #C006		; 1 = H.TIMI is normal mode's handler
			db "AB"
			dw ntc_msx_init			; INIT
			dw 0, 0, 0				; STATEMENT, DEVICE, TEXT
			ds 6, 0
ntc_msx_init:
			di
			call #0138				; RSLREG: A = the primary slots of pages 0-3
			ld b, a
			rrca
			rrca
			and 3
			ld c, a					; C = this cartridge's slot (page 1's)
			ld e, a
			ld d, 0
			ld hl, #FCC1			; EXPTBL: bit 7 = an expanded slot
			add hl, de
			ld a, (hl)
			and #80
			jr z, ntc_mi_p1
			or c
			ld c, a
			ld de, 4				; SLTTBL: its secondary slots
			add hl, de
			ld a, (hl)
			and #0C
			or c
			ld c, a
ntc_mi_p1:
			ld a, b					; page 2's slot now (RAM)
			rrca
			rrca
			rrca
			rrca
			and 3
			ld e, a
			ld d, 0
			ld hl, #FCC1
			add hl, de
			ld a, (hl)
			and #80
			jr z, ntc_mi_p2
			or e
			ld e, a
			ld a, l
			add a, 4
			ld l, a
			ld a, (hl)
			rrca
			rrca
			and #0C
			or e
			ld e, a
ntc_mi_p2:
			ld a, e
			ld (NTC_MSXP2), a
			xor a
			ld (NTC_MSXIQ), a
			ld (#FCA9), a			; CSRSW: no cursor while CHGET waits
			inc a
			ld (#F3F6), a			; SCNCNT: the keyboard read at the next interrupt (C-BIOS starts it at 0: 255 frames)
			ld a, c
			ld h, #80
			call #0024				; ENASLT: page 2 = this cartridge (its second 16K)
			di
			call ntc_start			; End comes back here (ntc_csp's return)
			di
			ld a, (NTC_MSXP2)		; page 2 as it was (this runs in page 1)
			ld h, #80
			call #0024				; ENASLT
			ei
			ret						; back to the BIOS

;## ntc_plat_data @shared
ntc_curx:		db 0			; cursor column (0 based)
ntc_cury:		db 0			; cursor row (0 based)
ntc_scols:		db 40			; columns in this mode
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none

;## ntc_plat_vdev ntc_vtms @shared
; the console's device: the MSX's own video chip, the BIOS's font
ntc_vdev:		dw ntc_vt_put, ntc_vt_scroll, ntc_vt_cls, ntc_vt_mode, ntc_msx_vinit	; @const
ntc_msx_vinit:
			ld a, (#0006)			; the VDP's data port (read: the same as write on every MSX)
			ld l, a
			ld h, 0
			ld (ntc_vport), hl
			ld a, (#002D)			; MSX version: 0 = MSX1 (TMS9918), 1 and up = V9938 / V9958
			or a
			jr z, ntc_mv_tms
			ld a, 1
ntc_mv_tms:
			ld (ntc_vtype), a
			ld a, (#FFE8)			; RG9SAV: the BIOS's R#9 - its PAL / NTSC bit only (192 lines)
			and #02
			ld (ntc_vr9), a
			ld hl, (#0004)			; CGTABL: the BIOS's font, from character 0
			ld de, 32 * 8
			add hl, de
			ld (ntc_vfont), hl
			ret

;## ntc_plat_screen ntc_vcon ntc_plat_data ntc_data @shared
; ntc_plat_putc - A = character 32-126; ntc_plat_newline
ntc_plat_putc:
			jp ntc_vc_putc
ntc_plat_newline:
			jp ntc_vc_newline

;## ntc_plat_backspace @unit ntc_plat_screen @shared
ntc_plat_backspace:
			jp ntc_vc_backspace

;## ntc_plat_cls @unit ntc_plat_screen @shared
ntc_plat_cls:
			jp ntc_vc_cls

;## ntc_plat_mode @unit ntc_plat_screen @shared
; ntc_plat_mode - A = mode: 0 = 32 x 24, 1 = 40 x 24, 2 = 80 x 24 (MSX2 and up)
ntc_plat_mode:
			jp ntc_vc_mode

;## ntc_plat_locate @unit ntc_plat_screen @shared
; ntc_plat_locate - H = column, L = row, 1 based
ntc_plat_locate:
			jp ntc_vc_locate

;## ntc_plat_key ntc_vcall ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_scankey - A = a key from the BIOS's buffer, 0 none (interrupts
; in for the call: the BIOS reads the keyboard in its interrupt)
; ntc_plat_getkey - wait for a key, A = the key
; ------------------------------------------------------------
ntc_plat_scankey:
			ld iy, ntc_msx_scan
			jp ntc_vcall
ntc_plat_getkey:
			ld iy, ntc_msx_getk
			jp ntc_vcall
ntc_msx_scan:
			ei
			call #009C				; CHSNS: Z = no key
			jr z, ntc_ms_none
			call #009F				; CHGET
			di
			ret
ntc_ms_none:
			di
			xor a
			ret
ntc_msx_getk:
			ei
			call #009F				; CHGET: waits
			di
			ret

;## ntc_plat_frame ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_frame - wait for the next frame (its interrupt), on the real stack
; ------------------------------------------------------------
ntc_plat_frame:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			halt
			di
			ld sp, (ntc_ip)
			jp (ix)

;## ntc_plat_ticks @shared
; ntc_plat_ticks - HL = JIFFY (the BIOS counts the frames)
ntc_plat_ticks:
			ld hl, (#FC9E)
			jp (ix)

;## ntc_plat_irq ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_irqon - normal mode's handler on H.TIMI (#FD9F: the BIOS calls it
; at every frame interrupt, its registers saved): an Interrupt hook is marked
; to run at the next safe point, the interrupt classes are counted (C = 1:
; every interrupt is a frame's)
; ------------------------------------------------------------
ntc_plat_irqon:
			ld hl, #FD9F
			ld de, NTC_MSXHK
			ld bc, 5
			ldir
			ld a, #C3				; jp ntc_irq, ret, ret
			ld (#FD9F), a
			ld hl, ntc_irq
			ld (#FDA0), hl
			ld a, #C9
			ld (#FDA2), a
			ld (#FDA3), a
			ld a, 1
			ld (NTC_MSXIQ), a
			jp (ix)
ntc_irq:
			ld a, (ntc_hookon)
			or a
			jr z, ntc_irq_nohook
			ld (ntc_hookpend), a
ntc_irq_nohook:
			ld hl, (ntc_irqv)
			ld a, h
			or l
			ret z
			ld c, 1
			jp (hl)

;## ntc_plat_exit @shared
; ------------------------------------------------------------
; ntc_plat_exit - End: H.TIMI back as it was (page 2's slot: the INIT,
; after the program's return - that code is in page 1)
; ------------------------------------------------------------
ntc_plat_exit:
			ld a, (NTC_MSXIQ)
			or a
			jr z, ntc_mx_done
			ld hl, NTC_MSXHK
			ld de, #FD9F
			ld bc, 5
			ldir
			xor a
			ld (NTC_MSXIQ), a
ntc_mx_done:
			jp (ix)

;## ntc_plat_memtop ntc_data @shared
; ntc_plat_memtop - HL = the first byte the Memory class's heap must not
; use: 512 bytes under the stack are the stack's. Called with call / ret
ntc_plat_memtop:
			ld hl, (ntc_csp)
			dec h
			dec h
			ret

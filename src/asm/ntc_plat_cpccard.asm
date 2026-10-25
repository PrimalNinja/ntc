; ============================================================
; NTC Platform - Amstrad CPC with an MSX V9938 card (AMSDAP)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The cpc platform (asm/ntc_plat_cpc.asm: no firmware, its keys, its
; interrupts, its Memory and Graphics) with the console on an MSX V9938
; card through the AMSDAP MSX cartridge adapter: an MSX I/O port nn is
; the CPC's &FFnn, so the card's #88-#8B are &FF88-&FF8B (the V9938's
; own monitor output). Mode 2 = 80 x 24, mode 1 = 40 x 24, mode 0 = 32 x
; 24; ntc_font6's characters, white on dark blue. The CPC's own screen is
; left as it was (the Graphics class still draws there); the first Mode
; turns the CPC's ROMs off, as cpc's does. #If NTC_CPCCARD (and NTC_CPC).
; ============================================================
;@base     cpc
;@name     Amstrad CPC - an MSX V9938 card (AMSDAP, &FF88)
;@text     byte
;@scrinit  1
;@rows     24
;@vdp      1
; ============================================================

;## ntc_plat_vdev ntc_vtms ntc_font6 ntc_plat_data @shared
; the console's device: the V9938 at &FF88, ntc_font6
ntc_vdev:		dw ntc_vt_put, ntc_vt_scroll, ntc_vt_cls, ntc_vt_mode, ntc_cc_vinit	; @const
ntc_cc_vinit:
			ld bc, #7F8D			; the CPC: mode 1, both ROMs off (the program can be under them)
			out (c), c
			ld a, 1
			ld (ntc_smode), a
			ld (ntc_sinit), a		; (ntc_plat_exit: the upper ROM back on)
			ld hl, #FF88
			ld (ntc_vport), hl
			ld a, 1
			ld (ntc_vtype), a
			xor a
			ld (ntc_vie), a			; no frame interrupt from the card
			ld a, #02				; R#9: PAL, 192 lines
			ld (ntc_vr9), a
			ld hl, ntc_font6
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
; ntc_plat_mode - A = mode: 0 = 32 x 24, 1 = 40 x 24, 2 = 80 x 24
ntc_plat_mode:
			jp ntc_vc_mode

;## ntc_plat_locate @unit ntc_plat_screen @shared
; ntc_plat_locate - H = column, L = row, 1 based
ntc_plat_locate:
			jp ntc_vc_locate

;## ntc_plat_scroll @shared
; (cpc's screen scroll and clear are not used: the console is on the card - this empty
; section stands in for cpc's, so ntc_plat_cls is this platform's own)

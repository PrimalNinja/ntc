; ============================================================
; NTC Platform - Amstrad CPC with a V9990 (AMSDAP and an MSX card, or the Powergraph)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The cpc platform (asm/ntc_plat_cpc.asm: no firmware, its keys, its
; interrupts, its Memory and Graphics) with the console on a V9990: an
; MSX V9990 cartridge (GFX9000, Video9000) through the AMSDAP adapter, or
; the CPC Powergraph - both at &FF60-&FF6F (an MSX I/O port nn is the
; CPC's &FFnn). A bit map (B1, 256 x 212 for mode 0 / 1: 40 x 24; B3,
; 512 x 212 for mode 2: 80 x 24) with ntc_font6's characters on the
; V9990's own monitor output. The CPC's own screen is left as it was (the
; Graphics class still draws there); the first Mode turns the CPC's ROMs
; off, as cpc's does. The V9990 class draws on the same chip.
; #If NTC_CPC9990 (and NTC_CPC).
; ============================================================
;@base     cpc
;@name     Amstrad CPC - a V9990 (AMSDAP or Powergraph, &FF60)
;@text     byte
;@scrinit  1
;@rows     24
;@vdp      1
; ============================================================

;## ntc_plat_vdev ntc_v9 ntc_font6 ntc_plat_data @shared
; the console's device: the V9990 at &FF60, ntc_font6
ntc_vdev:		dw ntc_v9put, ntc_v9scroll, ntc_v9cls, ntc_v9mode, ntc_cc_vinit	; @const
ntc_cc_vinit:
			ld bc, #7F8D			; the CPC: mode 1, both ROMs off (the program can be under them)
			out (c), c
			ld a, 1
			ld (ntc_smode), a
			ld (ntc_sinit), a		; (ntc_plat_exit: the upper ROM back on)
			ld hl, #FF60
			ld (ntc_v9port), hl
			ld hl, ntc_font6
			ld (ntc_v9font), hl
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

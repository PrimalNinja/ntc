; ============================================================
; NTC Platform - MSX with a V9938 card at port #88: a cartridge ROM
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The msx platform (asm/ntc_plat_msx.asm: the cartridge, the BIOS's keys
; and interrupts) with the console on a second video chip: a V9938 card
; on ports #88-#8B - the MSX2 upgrade and 80 column cartridges (Sharp
; HB-4000, Gradiente CT-80E, Neos MA-20V ...), an MSX1's way to 80
; columns. Mode 2 = 80 x 24, mode 1 = 40 x 24, mode 0 = 32 x 24. The
; MSX's own video chip is left as the BIOS set it (its frame interrupt
; is still the clock). The BIOS's font. #If NTC_MSXCARD (and NTC_MSX).
; ============================================================
;@base     msx
;@name     MSX - cartridge, a V9938 card at #88 (80 columns)
; ============================================================

;## ntc_plat_vdev ntc_vtms @shared
; the console's device: the V9938 at #88, the BIOS's font
ntc_vdev:		dw ntc_vt_put, ntc_vt_scroll, ntc_vt_cls, ntc_vt_mode, ntc_msx_vinit	; @const
ntc_msx_vinit:
			ld hl, #0088
			ld (ntc_vport), hl
			ld a, 1
			ld (ntc_vtype), a
			xor a
			ld (ntc_vie), a			; no frame interrupt from the card
			ld a, (#FFE8)			; RG9SAV: the MSX's PAL / NTSC (the card's monitor: the same)
			and #02
			ld (ntc_vr9), a
			ld hl, (#0004)			; CGTABL: the BIOS's font, from character 0
			ld de, 32 * 8
			add hl, de
			ld (ntc_vfont), hl
			ret

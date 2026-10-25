; ============================================================
; NTC Platform - MSX with a V9990 (GFX9000, Video9000, Powergraph,
; TRH9000): a cartridge ROM
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The msx platform (asm/ntc_plat_msx.asm: the cartridge, the BIOS's keys
; and interrupts) with the console on the V9990 at ports #60-#6F: a bit
; map (B1, 256 x 212 for mode 0 / 1: 40 x 24; B3, 512 x 212 for mode 2:
; 80 x 24) with the BIOS's font, 6 x 8. The MSX's own video chip is left
; as the BIOS set it (its frame interrupt is still the clock). The V9990
; class draws on the same chip. #If NTC_MSX9990 (and NTC_MSX).
; ============================================================
;@base     msx
;@name     MSX - cartridge, a V9990 at #60 (GFX9000)
; ============================================================

;## ntc_plat_vdev ntc_v9 @shared
; the console's device: the V9990 at #60, the BIOS's font
ntc_vdev:		dw ntc_v9put, ntc_v9scroll, ntc_v9cls, ntc_v9mode, ntc_msx_vinit	; @const
ntc_msx_vinit:
			ld hl, #0060
			ld (ntc_v9port), hl
			ld hl, (#0004)			; CGTABL: the BIOS's font, from character 0
			ld de, 32 * 8
			add hl, de
			ld (ntc_v9font), hl
			ret

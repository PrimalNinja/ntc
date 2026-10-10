; ============================================================
; NTC Platform - test harness (port I/O, used by ntc_test.py)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
;   out #fe = char out        in #fd = wait key
;   in  #f8 = key or 0        out #fc = cls
;   out #fb = locate (x then y)   out #fa = mode
; ============================================================

;## ntc_plat_putc
ntc_plat_putc:
			out (#fe), a
			ret

;## ntc_plat_getc
ntc_plat_getc:
			in a, (#fd)
			ret

;## ntc_plat_inkey
ntc_plat_inkey:
			in a, (#f8)
			ret

;## ntc_plat_cls
ntc_plat_cls:
			out (#fc), a
			ret

;## ntc_plat_locate
ntc_plat_locate:
			ld a, h
			out (#fb), a
			ld a, l
			out (#fb), a
			ret

;## ntc_plat_mode
ntc_plat_mode:
			out (#fa), a
			ret

;## ntc_plat_frame
ntc_plat_frame:
			ret

;## ntc_plat_callhl
ntc_plat_callhl:
			jp (hl)

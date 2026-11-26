; ============================================================
; ntc_lib_ep.asm - Enterprise 128 platform banking (ep128)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ------------------------------------------------------------
; The Enterprise versions of the banking primitives the CPC-modelled Memory
; manager (ntc_mem, in ntc_lib_cpc.asm) switches platform on, as the MSX's
; are in ntc_lib_msx.asm and the Next's in ntc_lib_nxt.asm:
;   ep_mem_probe   - the segments taken from EXOS (mem_probe's Enterprise branch)
;   ep_mem_jbc     - 64K bank -> its page 0's RAM setting (mem_jbc's)
;   ep_mem_se_out  - a RAM setting into the window #4000-#7FFF (mem_se_out's)
;   ep_mem_seg     - a RAM setting -> its segment
; The whole section is IFDEF NTC_EP128: nothing on any other platform.
;
; The machine's RAM is 16K segments, any of them in any of the Z80's four
; pages (Dave's ports #B0-#B3): the window is page 1, port #B1. The platform's
; start code (ntc_plat_boot, asm/ntc_plat_ep128.asm) took every free segment
; from EXOS and listed them at #BD00 (the count at #BCFF; the program's own and
; the screen's left out): those are the pages, 4 a 64K "bank" in the list's
; order (a bank's 4 needn't be next to each other: they are looked up). Every
; segment is a page - the last bank may have fewer than 4, the pages it hasn't
; are marked taken (ep_usable; mem_start, as the Next's). Main RAM's own page 1
; (the setting #7FC0) is the segment the program has there (kept at #BCFE).
;
; The RAM setting (BC) is shaped as the CPC's gate-array one, as on the MSX,
; so that the CPC's setting arithmetic (a bank's "C2" setting = its page 0's
; and #F8 or 2; its page n in the window = and #F8 or 4 + n) works unchanged:
; B = 1 + bank / 32 (1 or 2 - never 0, never #7F), C = (bank and 31) * 8 + 4 +
; its page (0-3), or + 2 for the whole bank. 64 banks: 256 segments, 4 MB.
; ============================================================

;## ntc_ep_bank ntc_mem @far @if:ntc_mem_cpcexpansion
	IFDEF NTC_EP128
EPB_SEG1	equ #BCFE				; the platform's start code leaves these for this section, at fixed places (the
EPB_NSEG	equ #BCFF				; library names no platform label): the program's page 1 segment, the number of
EPB_SEGS	equ #BD00				; free segments, and their list
ep_usable:		db 0					; the pages there are after page 1 (segments in the list, Option Memory's limit kept)

; ep_mem_probe - the segments the start code listed, 4 a bank (up to MEM_BANKS;
; a last bank of fewer than 4 counts). Sets mem_banks, mem_found and ep_usable.
; Called from mem_probe on the real stack
ep_mem_probe:
			ld a, (EPB_NSEG)
	IF MEM_BANKS < 63				; (Option Memory Heap Pages n: no more than its pages)
			cp MEM_BANKS * 4 + 1
			jr c, ep_pr_n
			ld a, MEM_BANKS * 4
ep_pr_n:
	ENDIF
			ld (ep_usable), a
			add a, 3				; banks = (segments + 3) / 4 (252 segments at most: no carry)
			srl a
			srl a
			ld (mem_banks), a
			or a
			ret z
			ld hl, mem_found		; the banks found: 0, 1, 2 ...
			ld b, a
			ld e, 0
ep_pr_fl:
			ld (hl), e
			inc hl
			inc e
			djnz ep_pr_fl
			ret

; ep_mem_jbc - E = a 64K bank (0-63) -> BC = its page 0's RAM setting (B = 1 + E / 32,
; C = (E and 31) * 8 + 4: the four 16K parts step C, as the CPC's #C4 - #C7 do).
; Keeps DE, HL.
ep_mem_jbc:
			ld a, e
			add a, a
			add a, a
			add a, a
			add a, 4
			ld c, a
			ld a, e
			rlca
			rlca
			rlca
			and 1
			inc a
			ld b, a
			ret

; ep_mem_seg - BC = a RAM setting -> A = its segment: B = #7F (main RAM's own,
; #7FC0) = the program's own page 1; else EPB_SEGS((B - 1) * 128 + (C and #F8) / 2 +
; page), the page C's low 3 bits less 4 (the whole bank's "2" and 0-3: its page 0).
; Keeps BC, DE, HL.
ep_mem_seg:
			ld a, b
			cp #7F
			jr nz, ep_ms_pg
			ld a, (EPB_SEG1)
			ret
ep_ms_pg:
			push hl
			ld a, c
			and 7
			sub 4
			jr nc, ep_ms_ok
			xor a					; 0-3: page 0
ep_ms_ok:
			ld l, a
			ld a, c
			and #F8
			srl a					; (bank and 31) * 4
			add a, l
			ld l, a
			ld a, b
			dec a
			rrca					; bank / 32: bit 7
			and #80
			or l
			ld l, a
			ld h, high EPB_SEGS
			ld a, (hl)
			pop hl
			ret

; ep_mem_se_out - BC = the RAM setting: its segment into the window (page 1, port #B1).
; Reached by jp from mem_se_out; exits through mem_se_end. ntc_rampt first, then the port
ep_mem_se_out:
			ld (ntc_rampt), bc
			call ep_mem_seg
			out (#B1), a
			jp mem_se_end
	ENDIF

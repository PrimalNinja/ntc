; ============================================================
; ntc_lib_nxt.asm - ZX Spectrum Next platform banking
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ------------------------------------------------------------
; The Next versions of the three banking primitives the CPC-modelled
; Memory manager (ntc_mem, in ntc_lib_cpc.asm) switches platform on:
;   nxt_mem_probe   - the RAM probe (mem_probe's ELSE branch)
;   nxt_mem_jbc     - 64K bank -> its first 16K Next bank (mem_jbc's zxn branch)
;   nxt_mem_se_out  - a RAM setting into the #4000 window (mem_se_out's zxn branch)
; Linked as a dependency of ntc_mem; the whole section is IFDEF NTC_ZXN, so on a
; CPC build it contributes nothing. NextReg is driven through ports #243B / #253B
; (no Z80N opcodes). A 64K "bank" = 4 x 16K Next banks; a 16K bank = two 8K MMU
; pages (slots 2, 3 = NextReg #52, #53) in the #4000-#7FFF window.
; ============================================================

;## ntc_nxt_bank ntc_mem @far @if:ntc_mem_cpcexpansion
	IFDEF NTC_ZXN
; nxt_mem_probe - 16K banks from ZXN_FIRSTBANK up are free RAM. Map each into the
; window, mark it, re-read; the contiguous run that still holds its marker is
; usable. Sets mem_banks (64K banks = usable 16K banks / 4). Called from mem_probe;
; leaves interrupts off (the boot re-enables, as the CPC path does).
nxt_mem_probe:
			di
			ld c, ZXN_FIRSTBANK
zxn_pr_w:
			call zxn_pr_map			; 16K bank C into #4000-#7FFF
			ld a, c
			ld (MEM_WIN), a			; marker = the bank number
			inc c
			ld a, c
			cp ZXN_FIRSTBANK + ZXN_MAXBANK
			jr nz, zxn_pr_w
			ld b, 0					; usable 16K banks
			ld c, ZXN_FIRSTBANK
zxn_pr_r:
			call zxn_pr_map
			ld a, (MEM_WIN)
			cp c					; still its own marker (real, not absent / aliased)?
			jr nz, zxn_pr_done
			inc b
			inc c
			ld a, c
			cp ZXN_FIRSTBANK + ZXN_MAXBANK
			jr nz, zxn_pr_r
zxn_pr_done:
			ld c, 9					; the program's own window bank back
			call zxn_pr_map
			ld a, b					; 64K banks = usable 16K banks / 4
			srl a
			srl a
			ld (mem_banks), a
			or a
			jr z, zxn_pr_nf
			ld hl, mem_found		; the banks found, 0, 1, 2 ... (contiguous on the Next)
			ld b, a
			ld e, 0
zxn_pr_fl:
			ld (hl), e
			inc hl
			inc e
			djnz zxn_pr_fl
zxn_pr_nf:
			ret
; zxn_pr_map - C = a 16K bank into #4000-#7FFF (MMU slots 2, 3 = NextReg #52, #53). Keeps C.
zxn_pr_map:
			push bc
			ld a, c
			add a, a				; first 8K page = bank * 2
			ld d, a
			ld bc, #243B
			ld a, #52
			out (c), a
			inc b
			out (c), d
			dec b
			ld a, #53
			out (c), a
			inc b
			inc d
			out (c), d
			pop bc
			ret

; nxt_mem_jbc - E = a 64K bank (0-63) -> BC = its first 16K Next bank (B = 0, the
; four 16K parts step C). Called from mem_jbc (jp, so its ret returns to mem_jbc's
; caller). Keeps DE, HL.
nxt_mem_jbc:
			ld a, e
			add a, a
			add a, a				; E * 4
			add a, ZXN_FIRSTBANK
			ld c, a					; C = the Next 16K bank
			ld b, 0
			ret

; nxt_mem_se_out - BC = the RAM setting (B = port, C = value): the Next 16K bank
; into the window (slots 2, 3). B = #7F (page 1 / plain RAM) = the program's own
; window bank 9. Reached by jp from mem_se_out; exits through mem_se_end.
; ntc_zxsel is kept so an interrupt handler can re-assert the window.
nxt_mem_se_out:
			ld (ntc_rampt), bc
			ld a, b
			cp #7F						; B = #7F: page 1 / plain RAM = the program's own window bank 9
			jr nz, nxt_se_zc
			ld c, 9
nxt_se_zc:
			ld a, c
			add a, a					; first 8K page = Next 16K bank * 2
			ld d, a
			ld bc, #243B
			ld a, #52
			ld (ntc_zxsel), a
			out (c), a
			inc b
			out (c), d
			dec b
			ld a, #53
			ld (ntc_zxsel), a
			out (c), a
			inc b
			inc d
			out (c), d
			jp mem_se_end
	ENDIF

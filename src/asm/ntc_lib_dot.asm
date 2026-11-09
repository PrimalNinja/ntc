; ============================================================
; ntc_lib_dot.asm - ZX Spectrum Next dot command (zxndotl) banking
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ------------------------------------------------------------
; The Large Model dot command's versions of the banking primitives the
; CPC-modelled Memory manager (ntc_mem, in ntc_lib_cpc.asm) switches
; platform on, as the Next's NEX ones are in ntc_lib_nxt.asm and the MSX's
; in ntc_lib_msx.asm:
;   dot_mem_probe   - 8K pages from NextZXOS's allocator, 8 a 64K bank
;   dot_mem_jbc     - 64K bank -> its page 0's RAM setting
;   dot_mem_se_out  - a RAM setting into the window #4000-#7FFF (slots 2, 3)
;   dot_mem_bank    - a RAM setting -> its first 8K page's index in dotl_pages
;   dot_win         - the window switch for a program's own asm, as out (c), c
; The whole section is IFDEF NTC_ZXNDOTL: nothing on any other platform.
;
; The pages come from IDE_BANK (through M_P3DOS, on BASIC's side: dotl_page in
; the platform's entry code, which keeps them in dotl_pages and gives every one
; back at the end). The first 6 are the platform's (the window's two, the
; program's four); the Memory class's follow, 8 a 64K bank (4 x 16K, a 16K bank
; = two 8K pages, one after the other in dotl_pages - any page numbers, the
; allocator's choice). The window is slots 2 and 3 (NextRegs #52, #53). Main
; RAM's own page 1 (the setting #7FC0) is the window's own two pages.
;
; The RAM setting (BC) is shaped as the CPC's gate-array one, so that the CPC's
; setting arithmetic (a bank's "C2" setting = its page 0's and #F8 or 2; its
; page n in the window = and #F8 or 4 + n) works unchanged: B = DOT_SETB (1 -
; never 0, never #7F), C = the bank's ordinal * 8 + 4 + its page (0-3), or + 2
; for the whole bank.
; ============================================================
;## ntc_dot_bank ntc_mem @far @if:ntc_mem_cpcexpansion
	IFDEF NTC_ZXNDOTL
DOT_SETB	equ 1					; B of a dot command's RAM setting (see the top)
	IF MEM_BANKS > 16
DOT_MAXBK	equ 16					; banks at most: dotl_pages holds 16 (1MB)
	ELSE
DOT_MAXBK	equ MEM_BANKS
	ENDIF
; dot_mem_probe - up to DOT_MAXBK banks of 8 pages from the allocator; a part bank's
; pages stay allocated (given back at the end with the rest: the allocator has no
; order to free them in). Sets mem_banks and mem_found. Called from mem_probe on the
; real stack
dot_mem_probe:
			xor a
			ld (dot_nbk), a
dot_pr_bank:
			ld a, (dot_nbk)
			cp DOT_MAXBK
			jr nc, dot_pr_done
			ld b, 8
dot_pr_pg:
			push bc
			call dotl_page			; one more into dotl_pages
			pop bc
			jr nc, dot_pr_done		; none left: this bank is not whole
			djnz dot_pr_pg
			ld a, (dot_nbk)
			inc a
			ld (dot_nbk), a
			jr dot_pr_bank
dot_pr_done:
			ld a, (dot_nbk)
			ld (mem_banks), a
			or a
			ret z
			ld hl, mem_found		; the banks found: 0, 1, 2 ...
			ld b, a
			ld e, 0
dot_pr_fl:
			ld (hl), e
			inc hl
			inc e
			djnz dot_pr_fl
			ret
dot_nbk:		db 0					; banks got

; dot_mem_jbc - E = a 64K bank (0-63) -> BC = its page 0's RAM setting (B = DOT_SETB,
; C = E * 8 + 4: the four 16K parts step C, as the CPC's #C4 - #C7 do). Keeps DE, HL.
dot_mem_jbc:
			ld a, e
			add a, a
			add a, a
			add a, a
			add a, 4
			ld c, a
			ld b, DOT_SETB
			ret

; dot_mem_bank - BC = a RAM setting -> HL = its two pages' place in dotl_pages: B = #7F
; (main RAM's own, #7FC0) = the window's own (dotl_pages + 0); else C = ordinal * 8 +
; 4 + page -> dotl_pages + 6 + (ordinal * 4 + page) * 2 (the whole bank's "2" and 0-3:
; its page 0). Keeps BC, DE.
dot_mem_bank:
			ld hl, dotl_pages
			ld a, b
			cp #7F
			ret z
			push de
			ld a, c
			and 7
			sub 4
			jr nc, dot_mb_ok
			xor a					; 0-3: page 0
dot_mb_ok:
			ld e, a
			ld a, c
			and #F8
			srl a					; ordinal * 4
			add a, e
			add a, a				; two pages a 16K bank
			add a, 6				; after the platform's 6
			ld e, a
			ld d, 0
			add hl, de
			pop de
			ret

; dot_mem_se_out - (mem_se_out's branch) BC = a RAM setting: its two pages into slots
; 2, 3 -> mem_se_end (which pops BC, DE, HL)
dot_mem_se_out:
			call dot_win
			jp mem_se_end

; dot_win - BC = a RAM setting -> its two pages into the window #4000-#7FFF (NextRegs
; #52, #53): what out (c), c does with a setting on the CPC - for a program's own asm
; that switches the window itself, outside the Memory class. Keeps every register, as
; the out does (AF too). On the real stack only (call: never from the thread)
dot_win:
			push af
			push bc
			push de
			push hl
			call dot_mem_bank		; HL -> the two pages
			ld d, (hl)
			inc hl
			ld e, (hl)
			ld bc, #243B
			ld a, #52
			out (c), a
			inc b
			out (c), d				; slot 2
			dec b
			ld a, #53
			out (c), a
			inc b
			out (c), e				; slot 3
			pop hl
			pop de
			pop bc
			pop af
			ret
	ENDIF

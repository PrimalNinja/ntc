; ============================================================
; NTC Keyword Library
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
;
; NTC RULES
;   SP = instruction pointer (the thread). No call. No push.
;   Keywords pop args from the thread with pop, end with ret.
;   No firmware. Shared routines (I/O, platform) are entered with
;   jp and the return address in IX, and end with jp (ix).
;   ntc_next is a plain ret, so ld ix, ntc_next continues the thread.
;   ntc_csp is the caller's SP, only used by kw_stop to go back.
;
; ARGUMENT ORDER
;   Pop gets args left to right as written after the keyword.
;   dw kw_add, var1, var2, result
;
; OPERAND KINDS IN NAMES
;   v = variable address, l = literal value, z = zero
;   e.g. kw_subvl = var - literal, kw_sublv = literal - var
;
; COMPARES
;   Result is the Z flag. Z = true, NZ = false.
;   kw_goto_iffalse / kw_goto_iftrue branch on it.
;   kw_scp* = signed (used by the BASIC compiler)
;   kw_cp*  = unsigned (lt/le/gt/ge), eq/ne are sign-free
;
; BREAKPOINTS
;   dw bp_name in the thread, bp_name: ret  - break on bp_name
;   in a monitor, SP then points at the next thread word.
;
; SECTIONS
;   ";## name dep dep ..." starts a section. The compiler links
;   only the sections a program uses, plus their deps.
;   A platform file supplies ntc_plat_* sections.
; ============================================================

;## ntc_data
; ------------------------------------------------------------
; Scratch space
; ------------------------------------------------------------
ntc_next:		ret				; IX target that continues the thread
ntc_csp:		dw 0			; caller SP, for kw_stop
ntc_mode:		db 0			; div mode 0=quotient 1=remainder
ntc_sgnq:		db 0			; quotient sign (bit 7)
ntc_sgnr:		db 0			; remainder sign (bit 7)
ntc_lead:		db 0			; printint: digit seen
ntc_icnt:		db 0			; gets: chars typed
ntc_sptr:		dw 0			; printbuf: text pointer
ntc_iptr:		dw 0			; gets: buffer pointer
ntc_ilink:		dw 0			; gets: where to go when done
ntc_ivar:		dw 0			; inputint / inkey: dest var
ntc_aptr:		dw 0			; atoi: text pointer
ntc_numbuf:		ds 8			; printint: digits
ntc_inbuf:		ds 41			; inputint: typed text

;## ntc_gstack
; ------------------------------------------------------------
; GOSUB return stack (grows down, 64 levels)
; ------------------------------------------------------------
ntc_gsp:		dw ntc_gstack_top
ntc_gstack:		ds 128
ntc_gstack_top:

; ============================================================
; Flow
; ============================================================

;## kw_stop ntc_data ntc_plat_exit
kw_stop:
			ld ix, ntc_stop_back
			jp ntc_plat_exit
ntc_stop_back:
			ld sp, (ntc_csp)
			ei
			ret

;## kw_goto
;kw_goto, <label>
kw_goto:
			pop hl
			ld sp, hl
			ret

;## kw_goto_iffalse
;kw_goto_iffalse, <label>  - branch if NZ (false)
kw_goto_iffalse:
			pop hl
			ret z
			ld sp, hl
			ret

;## kw_goto_iftrue
;kw_goto_iftrue, <label>  - branch if Z (true)
kw_goto_iftrue:
			pop hl
			ret nz
			ld sp, hl
			ret

;## kw_goto_ifzero
;kw_goto_ifzero, <var>, <label>  - branch if var = 0
kw_goto_ifzero:
			pop hl
			ld a, (hl)
			inc hl
			or (hl)
			pop hl
			ret nz
			ld sp, hl
			ret

;## kw_goto_ifnzero
;kw_goto_ifnzero, <var>, <label>  - branch if var <> 0
kw_goto_ifnzero:
			pop hl
			ld a, (hl)
			inc hl
			or (hl)
			pop hl
			ret z
			ld sp, hl
			ret

;## kw_gosub ntc_gstack
;kw_gosub, <label>  - return lands on the word after the label
kw_gosub:
			pop bc
			ld hl, 0
			add hl, sp
			ex de, hl
			ld hl, (ntc_gsp)
			dec hl
			ld (hl), d
			dec hl
			ld (hl), e
			ld (ntc_gsp), hl
			ld h, b
			ld l, c
			ld sp, hl
			ret

;## kw_return ntc_gstack
;kw_return
kw_return:
			ld hl, (ntc_gsp)
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld (ntc_gsp), hl
			ex de, hl
			ld sp, hl
			ret

;## ntc_for_jump
; tails for the FOR / NEXT keywords. DE = var value, HL = limit,
; SP = thread at the label word. Signed compare by flipping bit 15.
; ntc_for_gt: jump to the label if var > limit, else skip it
ntc_for_gt:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			or a
			sbc hl, de			; limit - var, carry = var > limit
			pop hl
			ret nc
			ld sp, hl
			ret
; ntc_for_lt: jump to the label if var < limit, else skip it
ntc_for_lt:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			ex de, hl
			or a
			sbc hl, de			; var - limit, carry = var < limit
			pop hl
			ret nc
			ld sp, hl
			ret
; ntc_for_le: jump to the label if var <= limit (loop again)
ntc_for_le:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			or a
			sbc hl, de			; limit - var, no carry = var <= limit
			pop hl
			ret c
			ld sp, hl
			ret
; ntc_for_ge: jump to the label if var >= limit (loop again)
ntc_for_ge:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			ex de, hl
			or a
			sbc hl, de			; var - limit, no carry = var >= limit
			pop hl
			ret c
			ld sp, hl
			ret

;## kw_forupl ntc_for_jump
;kw_forupl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting up: skip the loop if var > limit
kw_forupl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_for_gt

;## kw_forupv ntc_for_jump
;kw_forupv, <var>, <limit var>, <endlabel>
kw_forupv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_for_gt

;## kw_fordnl ntc_for_jump
;kw_fordnl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting down: skip the loop if var < limit
kw_fordnl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_for_lt

;## kw_fordnv ntc_for_jump
;kw_fordnv, <var>, <limit var>, <endlabel>
kw_fordnv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_for_lt

;## kw_next1l ntc_for_jump
;kw_next1l, <var>, <literal limit>, <toplabel>
;  NEXT for STEP 1: inc var, back to the top while var <= limit
kw_next1l:
			pop hl
			inc (hl)
			ld e, (hl)
			inc hl
			jr nz, ntc_n1l_nc
			inc (hl)
ntc_n1l_nc:
			ld d, (hl)
			pop hl
			jp ntc_for_le

;## kw_next1v ntc_for_jump
;kw_next1v, <var>, <limit var>, <toplabel>
kw_next1v:
			pop hl
			inc (hl)
			ld e, (hl)
			inc hl
			jr nz, ntc_n1v_nc
			inc (hl)
ntc_n1v_nc:
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_for_le

;## ntc_nextadd
; var += literal step. Pops var and step. Leaves DE = new value.
ntc_nextadd:
			pop bc				; var
			pop hl				; step
			ld a, (bc)
			ld e, a
			inc bc
			ld a, (bc)
			ld d, a
			add hl, de
			ex de, hl			; DE = new value
			ld a, d
			ld (bc), a
			dec bc
			ld a, e
			ld (bc), a
			jp (ix)

;## kw_nextupl ntc_nextadd ntc_for_jump
;kw_nextupl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a positive STEP: add, back to the top while var <= limit
kw_nextupl:
			ld ix, ntc_nul_back
			jp ntc_nextadd
ntc_nul_back:
			pop hl
			jp ntc_for_le

;## kw_nextupv ntc_nextadd ntc_for_jump
;kw_nextupv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextupv:
			ld ix, ntc_nuv_back
			jp ntc_nextadd
ntc_nuv_back:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_for_le

;## kw_nextdnl ntc_nextadd ntc_for_jump
;kw_nextdnl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a negative STEP: add, back to the top while var >= limit
kw_nextdnl:
			ld ix, ntc_ndl_back
			jp ntc_nextadd
ntc_ndl_back:
			pop hl
			jp ntc_for_ge

;## kw_nextdnv ntc_nextadd ntc_for_jump
;kw_nextdnv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextdnv:
			ld ix, ntc_ndv_back
			jp ntc_nextadd
ntc_ndv_back:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_for_ge

;## kw_forentry
;kw_forentry, <var>, <stepvar>, <limvar>, <endlabel>
;  skip the loop if var is already past lim for the step sign
kw_forentry:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld b, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			bit 7, b
			jr nz, ntc_fe_neg
			or a
			sbc hl, de
			pop hl
			ret nc
			ld sp, hl
			ret
ntc_fe_neg:
			ex de, hl
			or a
			sbc hl, de
			pop hl
			ret nc
			ld sp, hl
			ret

;## kw_fornext
;kw_fornext, <var>, <stepvar>, <limvar>, <toplabel>
;  var += step, loop back while var has not passed lim
kw_fornext:
			pop ix
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld l, (ix+0)
			ld h, (ix+1)
			add hl, de
			ld (ix+0), l
			ld (ix+1), h
			ld b, d
			ex de, hl
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			bit 7, b
			jr nz, ntc_fn_neg
			or a
			sbc hl, de
			pop hl
			ret c
			ld sp, hl
			ret
ntc_fn_neg:
			ex de, hl
			or a
			sbc hl, de
			pop hl
			ret c
			ld sp, hl
			ret

; ============================================================
; Assignment
; ============================================================

;## kw_ltov
;kw_ltov, <literal>, <destvar>
kw_ltov:
			pop de
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_vtov
;kw_vtov, <sourcevar>, <destvar>
kw_vtov:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_ztov
;kw_ztov, <destvar>
kw_ztov:
			xor a
			pop hl
			ld (hl), a
			inc hl
			ld (hl), a
			ret

;## kw_ftov
;kw_ftov, <destvar>  - Z flag to var: true = -1, false = 0
kw_ftov:
			pop hl
			jr z, ntc_ftov_t
			ld (hl), 0
			inc hl
			ld (hl), 0
			ret
ntc_ftov_t:
			ld (hl), #ff
			inc hl
			ld (hl), #ff
			ret

; ============================================================
; Arithmetic
; ============================================================

;## kw_inc
;kw_inc, <var>
kw_inc:
			pop hl
			inc (hl)
			ret nz
			inc hl
			inc (hl)
			ret

;## kw_dec
;kw_dec, <var>
kw_dec:
			pop hl
			ld a, (hl)
			dec (hl)
			or a
			ret nz
			inc hl
			dec (hl)
			ret

;## kw_add
;kw_add, <var1>, <var2>, <destvar>
kw_add:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, de
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_addl
;kw_addl, <var>, <literal>, <destvar>
kw_addl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			add hl, de
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_subvv
;kw_subvv, <var1>, <var2>, <destvar>  - var1 - var2
kw_subvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ex de, hl
			or a
			sbc hl, de
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_sublv
;kw_sublv, <literal>, <var>, <destvar>  - literal - var
kw_sublv:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ex de, hl
			or a
			sbc hl, de
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_2x
;kw_2x, <var>, <destvar>
kw_2x:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_4x
;kw_4x, <var>, <destvar>
kw_4x:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, hl
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## ntc_mul
; BC * DE -> pop destvar, store. Low 16 bits (same signed/unsigned)
ntc_mul:
			ld hl, 0
			ld a, 16
ntc_mul_loop:
			add hl, hl
			sla e
			rl d
			jr nc, ntc_mul_skip
			add hl, bc
ntc_mul_skip:
			dec a
			jr nz, ntc_mul_loop
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_mulvv ntc_mul
;kw_mulvv, <var1>, <var2>, <destvar>
kw_mulvv:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			jp ntc_mul

;## kw_mulvl ntc_mul
;kw_mulvl, <var>, <literal>, <destvar>
kw_mulvl:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop de
			jp ntc_mul

;## ntc_div ntc_data
; HL / DE signed, truncating. (ntc_mode) 0 = quotient, 1 = remainder.
; Remainder takes the dividend's sign. Divide by zero gives
; quotient 0, remainder = dividend. Pops destvar and stores.
ntc_div:
			ld a, d
			or e
			jr nz, ntc_div_nz
			ld a, (ntc_mode)
			or a
			jr nz, ntc_div_store
			ld hl, 0
			jr ntc_div_store
ntc_div_nz:
			ld a, h
			ld (ntc_sgnr), a
			xor d
			ld (ntc_sgnq), a
			bit 7, h
			jr z, ntc_div_hpos
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
ntc_div_hpos:
			bit 7, d
			jr z, ntc_div_dpos
			xor a
			sub e
			ld e, a
			sbc a, a
			sub d
			ld d, a
ntc_div_dpos:
			ld a, h
			ld c, l
			ld hl, 0
			ld b, 16
ntc_div_loop:
			sla c
			rla
			adc hl, hl
			sbc hl, de
			jr nc, ntc_div_one
			add hl, de
			djnz ntc_div_loop
			jr ntc_div_done
ntc_div_one:
			inc c
			djnz ntc_div_loop
ntc_div_done:
			ld b, a
			ld a, (ntc_mode)
			or a
			jr z, ntc_div_q
			ld a, (ntc_sgnr)
			jr ntc_div_sign
ntc_div_q:
			ld h, b
			ld l, c
			ld a, (ntc_sgnq)
ntc_div_sign:
			rla
			jr nc, ntc_div_store
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
ntc_div_store:
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_divvv ntc_div
;kw_divvv, <var1>, <var2>, <destvar>  - var1 / var2
kw_divvv:
			xor a
			ld (ntc_mode), a
ntc_divvv:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld h, b
			ld l, c
			jp ntc_div

;## kw_divvl ntc_div
;kw_divvl, <var>, <literal>, <destvar>
kw_divvl:
			xor a
			ld (ntc_mode), a
ntc_divvl:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			pop de
			jp ntc_div

;## kw_divlv ntc_div
;kw_divlv, <literal>, <var>, <destvar>
kw_divlv:
			xor a
			ld (ntc_mode), a
ntc_divlv:
			pop bc
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld h, b
			ld l, c
			jp ntc_div

;## kw_modvv kw_divvv
;kw_modvv, <var1>, <var2>, <destvar>  - var1 MOD var2
kw_modvv:
			ld a, 1
			ld (ntc_mode), a
			jp ntc_divvv

;## kw_modvl kw_divvl
;kw_modvl, <var>, <literal>, <destvar>
kw_modvl:
			ld a, 1
			ld (ntc_mode), a
			jp ntc_divvl

;## kw_modlv kw_divlv
;kw_modlv, <literal>, <var>, <destvar>
kw_modlv:
			ld a, 1
			ld (ntc_mode), a
			jp ntc_divlv

;## kw_negv
;kw_negv, <var>, <destvar>
kw_negv:
			pop hl
			xor a
			sub (hl)
			ld e, a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_absv
;kw_absv, <var>, <destvar>
kw_absv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			bit 7, d
			jr z, ntc_abs_store
			xor a
			sub e
			ld e, a
			sbc a, a
			sub d
			ld d, a
ntc_abs_store:
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_sgnv
;kw_sgnv, <var>, <destvar>  - -1, 0 or 1
kw_sgnv:
			pop hl
			ld a, (hl)
			inc hl
			ld d, (hl)
			or d
			ld e, a
			jr z, ntc_sgn_store
			ld de, 1
			bit 7, (hl)
			jr z, ntc_sgn_store
			ld de, -1
ntc_sgn_store:
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

; ============================================================
; Bitwise / logic (true = -1, so these work as logical too)
; ============================================================

;## kw_andvv
;kw_andvv, <var1>, <var2>, <destvar>
kw_andvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			and e
			ld e, a
			inc hl
			ld a, (hl)
			and d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_andvl
;kw_andvl, <var>, <literal>, <destvar>
kw_andvl:
			pop hl
			pop de
			ld a, (hl)
			and e
			ld e, a
			inc hl
			ld a, (hl)
			and d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_orvv
;kw_orvv, <var1>, <var2>, <destvar>
kw_orvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			or e
			ld e, a
			inc hl
			ld a, (hl)
			or d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_orvl
;kw_orvl, <var>, <literal>, <destvar>
kw_orvl:
			pop hl
			pop de
			ld a, (hl)
			or e
			ld e, a
			inc hl
			ld a, (hl)
			or d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_xorvv
;kw_xorvv, <var1>, <var2>, <destvar>
kw_xorvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			xor e
			ld e, a
			inc hl
			ld a, (hl)
			xor d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_xorvl
;kw_xorvl, <var>, <literal>, <destvar>
kw_xorvl:
			pop hl
			pop de
			ld a, (hl)
			xor e
			ld e, a
			inc hl
			ld a, (hl)
			xor d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_notv
;kw_notv, <var>, <destvar>
kw_notv:
			pop hl
			ld a, (hl)
			cpl
			ld e, a
			inc hl
			ld a, (hl)
			cpl
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

; ============================================================
; Compares - result in Z flag (Z = true)
; Tails take DE = a, HL = b and test a <rel> b.
; ============================================================

;## ntc_cmp
ntc_cmp_slt:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_ult:
			ex de, hl
			or a
			sbc hl, de
			sbc a, a
			inc a
			ret
ntc_cmp_sge:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_uge:
			ex de, hl
			or a
			sbc hl, de
			sbc a, a
			ret
ntc_cmp_sgt:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_ugt:
			or a
			sbc hl, de
			sbc a, a
			inc a
			ret
ntc_cmp_sle:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_ule:
			or a
			sbc hl, de
			sbc a, a
			ret
ntc_cmp_eq:
			or a
			sbc hl, de
			ret
ntc_cmp_ne:
			or a
			sbc hl, de
			jr z, ntc_cmp_ne_f
			xor a
			ret
ntc_cmp_ne_f:
			or 1
			ret

;## kw_scpltvv ntc_cmp
;kw_scpltvv, <var1>, <var2>  - signed var1 < var2
kw_scpltvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_slt

;## kw_scpltvl ntc_cmp
;kw_scpltvl, <var>, <literal>
kw_scpltvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_slt

;## kw_scplevv ntc_cmp
kw_scplevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_sle

;## kw_scplevl ntc_cmp
kw_scplevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_sle

;## kw_scpgtvv ntc_cmp
kw_scpgtvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_sgt

;## kw_scpgtvl ntc_cmp
kw_scpgtvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_sgt

;## kw_scpgevv ntc_cmp
kw_scpgevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_sge

;## kw_scpgevl ntc_cmp
kw_scpgevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_sge

;## kw_cpltvv ntc_cmp
;kw_cpltvv, <var1>, <var2>  - unsigned var1 < var2
kw_cpltvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_ult

;## kw_cpltvl ntc_cmp
kw_cpltvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_ult

;## kw_cplevv ntc_cmp
kw_cplevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_ule

;## kw_cplevl ntc_cmp
kw_cplevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_ule

;## kw_cpgtvv ntc_cmp
kw_cpgtvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_ugt

;## kw_cpgtvl ntc_cmp
kw_cpgtvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_ugt

;## kw_cpgevv ntc_cmp
kw_cpgevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_uge

;## kw_cpgevl ntc_cmp
kw_cpgevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_uge

;## kw_cpeqvv ntc_cmp
;kw_cpeqvv, <var1>, <var2>
kw_cpeqvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_eq

;## kw_cpeqvl ntc_cmp
kw_cpeqvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_eq

;## kw_cpnevv ntc_cmp
kw_cpnevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_ne

;## kw_cpnevl ntc_cmp
kw_cpnevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_ne

; ============================================================
; Memory (PEEK / POKE / DEEK / DOKE)
; ============================================================

;## kw_lptrtov8
;kw_lptrtov8, <literaladdr>, <destvar>  - PEEK(literal)
kw_lptrtov8:
			pop hl
			ld a, (hl)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

;## kw_vptrtov8
;kw_vptrtov8, <addrvar>, <destvar>  - PEEK(var)
kw_vptrtov8:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld a, (de)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

;## kw_lptrtov
;kw_lptrtov, <literaladdr>, <destvar>  - DEEK(literal)
kw_lptrtov:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_vptrtov
;kw_vptrtov, <addrvar>, <destvar>  - DEEK(var)
kw_vptrtov:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ex de, hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_ltovptr8
;kw_ltovptr8, <literal>, <addrvar>  - POKE var, literal
kw_ltovptr8:
			pop bc
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ex de, hl
			ld (hl), c
			ret

;## kw_vtovptr8
;kw_vtovptr8, <sourcevar>, <addrvar>  - POKE var, var
kw_vtovptr8:
			pop hl
			ld c, (hl)
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ex de, hl
			ld (hl), c
			ret

;## kw_ltolptr8
;kw_ltolptr8, <literal>, <literaladdr>  - POKE literal, literal
kw_ltolptr8:
			pop bc
			pop hl
			ld (hl), c
			ret

;## kw_vtolptr8
;kw_vtolptr8, <sourcevar>, <literaladdr>  - POKE literal, var
kw_vtolptr8:
			pop hl
			ld c, (hl)
			pop hl
			ld (hl), c
			ret

;## kw_ltovptr
;kw_ltovptr, <literal>, <addrvar>  - DOKE var, literal
kw_ltovptr:
			pop bc
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ex de, hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

;## kw_vtovptr
;kw_vtovptr, <sourcevar>, <addrvar>  - DOKE var, var
kw_vtovptr:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ex de, hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

;## kw_ltolptr
;kw_ltolptr, <literal>, <literaladdr>  - DOKE literal, literal
kw_ltolptr:
			pop bc
			pop hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

;## kw_vtolptr
;kw_vtolptr, <sourcevar>, <literaladdr>  - DOKE literal, var
kw_vtolptr:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

; ============================================================
; Arrays (16 bit elements, no bounds check)
; ============================================================

;## kw_aget
;kw_aget, <arraybase>, <indexvar>, <destvar>
kw_aget:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, de
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_aset
;kw_aset, <arraybase>, <indexvar>, <sourcevar>
kw_aset:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, de
			ex de, hl
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			ex de, hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

;## kw_asetl
;kw_asetl, <arraybase>, <indexvar>, <literal>
kw_asetl:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, de
			pop bc
			ld (hl), c
			inc hl
			ld (hl), b
			ret

; ============================================================
; Random (16 bit xorshift 7,9,8 - period 65535)
; ============================================================

;## ntc_rnd_seed
ntc_rnd_seed:	dw 1

;## kw_rndv ntc_rnd_seed ntc_div
;kw_rndv, <nvar>, <destvar>  - 0 .. n-1 (0 if n <= 0)
kw_rndv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			jp ntc_rnd

;## kw_rndl ntc_rnd_seed ntc_div
;kw_rndl, <literal>, <destvar>
kw_rndl:
			pop de
ntc_rnd:
			ld hl, (ntc_rnd_seed)
			ld a, h
			rra
			ld a, l
			rra
			xor h
			ld h, a
			ld a, l
			rra
			ld a, h
			rra
			xor l
			ld l, a
			xor h
			ld h, a
			ld (ntc_rnd_seed), hl
			bit 7, d
			jr nz, ntc_rnd_zero
			ld a, d
			or e
			jr z, ntc_rnd_zero
			ld a, 1
			ld (ntc_mode), a
			res 7, h
			jp ntc_div
ntc_rnd_zero:
			ld hl, 0
			jp ntc_div_store

;## kw_seedv ntc_rnd_seed
;kw_seedv, <var>  - RANDOMIZE var (0 becomes 1)
kw_seedv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ex de, hl
			jr ntc_seed

;## kw_seedl ntc_rnd_seed
;kw_seedl, <literal>
kw_seedl:
			pop hl
ntc_seed:
			ld a, h
			or l
			jr nz, ntc_seed_ok
			inc l
ntc_seed_ok:
			ld (ntc_rnd_seed), hl
			ret

; ============================================================
; Strings (40 chars max, 0 terminated, buffer = 41 bytes)
; ============================================================

;## kw_strcpy
;kw_strcpy, <destaddr>, <srcaddr>
kw_strcpy:
			pop de
			pop hl
			ld b, 40
ntc_strcpy_loop:
			ld a, (hl)
			ld (de), a
			or a
			ret z
			inc hl
			inc de
			djnz ntc_strcpy_loop
			xor a
			ld (de), a
			ret

;## kw_strcat
;kw_strcat, <destaddr>, <srcaddr>
kw_strcat:
			pop de
			ld b, 40
ntc_strcat_end:
			ld a, (de)
			or a
			jr z, ntc_strcat_copy
			inc de
			djnz ntc_strcat_end
			pop hl
			ret
ntc_strcat_copy:
			pop hl
ntc_strcat_loop:
			ld a, (hl)
			ld (de), a
			or a
			ret z
			inc hl
			inc de
			djnz ntc_strcat_loop
			xor a
			ld (de), a
			ret

;## kw_strlen
;kw_strlen, <straddr>, <destvar>
kw_strlen:
			pop hl
			ld bc, 0
ntc_strlen_loop:
			ld a, (hl)
			or a
			jr z, ntc_strlen_done
			inc hl
			inc c
			jr ntc_strlen_loop
ntc_strlen_done:
			pop hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

;## kw_strcmpeq
;kw_strcmpeq, <addr1>, <addr2>  - Z if equal
kw_strcmpeq:
			pop de
			pop hl
ntc_streq_loop:
			ld a, (de)
			cp (hl)
			ret nz
			or a
			ret z
			inc hl
			inc de
			jr ntc_streq_loop

;## kw_strcmpne
;kw_strcmpne, <addr1>, <addr2>  - Z if not equal
kw_strcmpne:
			pop de
			pop hl
ntc_strne_loop:
			ld a, (de)
			cp (hl)
			jr nz, ntc_strne_t
			or a
			jr z, ntc_strne_f
			inc hl
			inc de
			jr ntc_strne_loop
ntc_strne_t:
			xor a
			ret
ntc_strne_f:
			inc a
			ret

; ============================================================
; I/O - no firmware, no call, no push. SP stays in the thread.
; Shared routines are entered with jp and the return address in
; IX, and end with jp (ix). Keywords that are done use
; ld ix, ntc_next (a ret) so the routine continues the thread.
; ============================================================

;## ntc_printbuf ntc_data ntc_font ntc_plat_screen
; print the 0 terminated ASCII text at (ntc_sptr), then ret (thread)
ntc_printbuf:
			ld hl, (ntc_sptr)
			ld a, (hl)
			or a
			ret z
			inc hl
			ld (ntc_sptr), hl
			sub 32
			jr c, ntc_pb_bad
			cp 95
			jr c, ntc_pb_ok
ntc_pb_bad:
			ld a, '?' - 32
ntc_pb_ok:
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_font
			add hl, de
			ex de, hl
			ld ix, ntc_printbuf
			jp ntc_plat_putglyph

;## kw_printzoscii ntc_data ntc_font ntc_plat_screen
;kw_printzoscii / dw glyph, glyph, ..., 0  - ZOSCII text inline in the thread
;  each word points at an 8 byte glyph bitmap. 1 = newline, 0 = end.
kw_printzoscii:
			pop de
			ld a, d
			or a
			jr z, ntc_pz_ctl
			ld ix, kw_printzoscii
			jp ntc_plat_putglyph
ntc_pz_ctl:
			or e
			ret z
			ld ix, kw_printzoscii
			jp ntc_plat_newline

;## kw_printstrvar ntc_printbuf
;kw_printstrvar, <straddr>
kw_printstrvar:
			pop hl
			ld (ntc_sptr), hl
			jp ntc_printbuf

;## kw_printint ntc_printbuf
;kw_printint, <var>  - signed decimal
kw_printint:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld de, ntc_numbuf
			bit 7, h
			jr z, ntc_pi_pos
			ld a, '-'
			ld (de), a
			inc de
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
ntc_pi_pos:
			xor a
			ld (ntc_lead), a
			ld iy, ntc_pow10
ntc_pi_pow:
			ld c, (iy+0)
			ld b, (iy+1)
			ld a, b
			or c
			jr z, ntc_pi_last
			ld a, '0' - 1
ntc_pi_sub:
			inc a
			and a
			sbc hl, bc
			jr nc, ntc_pi_sub
			add hl, bc
			cp '0'
			jr nz, ntc_pi_out
			ld b, a
			ld a, (ntc_lead)
			or a
			ld a, b
			jr z, ntc_pi_skip
ntc_pi_out:
			ld (de), a
			inc de
			ld a, 1
			ld (ntc_lead), a
ntc_pi_skip:
			inc iy
			inc iy
			jr ntc_pi_pow
ntc_pi_last:
			ld a, l
			add a, '0'
			ld (de), a
			inc de
			xor a
			ld (de), a
			ld hl, ntc_numbuf
			ld (ntc_sptr), hl
			jp ntc_printbuf
ntc_pow10:		dw 10000, 1000, 100, 10, 0

;## kw_printnl ntc_data ntc_plat_screen
;kw_printnl
kw_printnl:
			ld ix, ntc_next
			jp ntc_plat_newline

;## ntc_gets ntc_data ntc_font ntc_plat_screen ntc_plat_key
; line input with echo and DEL. HL = buffer (41 bytes), DE = where to
; jp when done (after the newline). 40 chars max, 0 terminated.
ntc_gets:
			ld (ntc_iptr), hl
			ld (ntc_ilink), de
			xor a
			ld (ntc_icnt), a
ntc_gs_wait:
			ld ix, ntc_gs_key
			jp ntc_plat_getkey
ntc_gs_key:
			cp 13
			jr z, ntc_gs_done
			cp 127
			jr z, ntc_gs_del
			cp 32
			jr c, ntc_gs_wait
			ld c, a
			ld a, (ntc_icnt)
			cp 40
			jr nc, ntc_gs_wait
			inc a
			ld (ntc_icnt), a
			ld hl, (ntc_iptr)
			ld (hl), c
			inc hl
			ld (ntc_iptr), hl
			ld a, c
			sub 32
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_font
			add hl, de
			ex de, hl
			ld ix, ntc_gs_wait
			jp ntc_plat_putglyph
ntc_gs_del:
			ld a, (ntc_icnt)
			or a
			jr z, ntc_gs_wait
			dec a
			ld (ntc_icnt), a
			ld hl, (ntc_iptr)
			dec hl
			ld (ntc_iptr), hl
			ld ix, ntc_gs_wait
			jp ntc_plat_backspace
ntc_gs_done:
			ld hl, (ntc_iptr)
			ld (hl), 0
			ld ix, (ntc_ilink)
			jp ntc_plat_newline

;## kw_inputstr ntc_gets
;kw_inputstr, <straddr>
kw_inputstr:
			pop hl
			ld de, ntc_next
			jp ntc_gets

;## kw_inputint ntc_gets
;kw_inputint, <var>  - signed decimal, stops at the first non digit
kw_inputint:
			pop hl
			ld (ntc_ivar), hl
			ld hl, ntc_inbuf
			ld de, ntc_atoi
			jp ntc_gets
ntc_atoi:
			ld hl, ntc_inbuf
ntc_atoi_sp:
			ld a, (hl)
			cp ' '
			jr nz, ntc_atoi_sign
			inc hl
			jr ntc_atoi_sp
ntc_atoi_sign:
			ld c, 0
			cp '-'
			jr nz, ntc_atoi_go
			inc c
			inc hl
ntc_atoi_go:
			ld de, 0
ntc_atoi_loop:
			ld a, (hl)
			sub '0'
			jr c, ntc_atoi_done
			cp 10
			jr nc, ntc_atoi_done
			ld (ntc_aptr), hl
			ex de, hl
			ld d, h
			ld e, l
			add hl, hl
			add hl, hl
			add hl, de
			add hl, hl
			ld e, a
			ld d, 0
			add hl, de
			ex de, hl
			ld hl, (ntc_aptr)
			inc hl
			jr ntc_atoi_loop
ntc_atoi_done:
			ld a, c
			or a
			jr z, ntc_atoi_store
			xor a
			sub e
			ld e, a
			sbc a, a
			sub d
			ld d, a
ntc_atoi_store:
			ld hl, (ntc_ivar)
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_inkey ntc_data ntc_plat_key
;kw_inkey, <destvar>  - new key press or 0, no wait
kw_inkey:
			pop hl
			ld (ntc_ivar), hl
			ld ix, ntc_inkey_got
			jp ntc_plat_scankey
ntc_inkey_got:
			ld hl, (ntc_ivar)
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

;## kw_scrinit ntc_data ntc_plat_screen
;kw_scrinit  - first word of any program that prints or reads keys:
;  mode 1, ROMs off, clear screen
kw_scrinit:
			ld a, 1
			ld ix, ntc_next
			jp ntc_plat_mode

;## kw_cls ntc_data ntc_plat_screen
;kw_cls
kw_cls:
			ld ix, ntc_next
			jp ntc_plat_cls

;## kw_locatell ntc_data ntc_plat_screen
;kw_locatell, <x>, <y>  - 1 based
kw_locatell:
			pop bc
			pop de
			ld h, c
			ld l, e
			ld ix, ntc_next
			jp ntc_plat_locate

;## kw_locatevv ntc_data ntc_plat_screen
;kw_locatevv, <xvar>, <yvar>
kw_locatevv:
			pop hl
			ld c, (hl)
			pop hl
			ld l, (hl)
			ld h, c
			ld ix, ntc_next
			jp ntc_plat_locate

;## kw_model ntc_data ntc_plat_screen
;kw_model, <literal>  - 0, 1 or 2, clears the screen
kw_model:
			pop hl
			ld a, l
			ld ix, ntc_next
			jp ntc_plat_mode

;## kw_modev ntc_data ntc_plat_screen
;kw_modev, <var>
kw_modev:
			pop hl
			ld a, (hl)
			ld ix, ntc_next
			jp ntc_plat_mode

;## kw_frame ntc_data ntc_plat_frame
;kw_frame  - wait for the start of the next frame flyback
kw_frame:
			ld ix, ntc_next
			jp ntc_plat_frame

;## kw_callv
;kw_callv, <addrvar>  - run machine code at the address in var.
;  It is a keyword: SP is the thread, no call/push, end with ret.
;  (CALL with a literal address compiles to dw <address>)
kw_callv:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp (hl)

;## ntc_font
; 8x8 font, chars 32-126, 8 bytes each, bit 7 = leftmost pixel
; from font8x8_basic by Daniel Hepper (public domain, IBM VGA based)
; glyph for char c = ntc_font + (c - 32) * 8
ntc_font:
			db #00, #00, #00, #00, #00, #00, #00, #00		; 32  
			db #18, #3C, #3C, #18, #18, #00, #18, #00		; 33 !
			db #6C, #6C, #00, #00, #00, #00, #00, #00		; 34 "
			db #6C, #6C, #FE, #6C, #FE, #6C, #6C, #00		; 35 #
			db #30, #7C, #C0, #78, #0C, #F8, #30, #00		; 36 $
			db #00, #C6, #CC, #18, #30, #66, #C6, #00		; 37 %
			db #38, #6C, #38, #76, #DC, #CC, #76, #00		; 38 &
			db #60, #60, #C0, #00, #00, #00, #00, #00		; 39 '
			db #18, #30, #60, #60, #60, #30, #18, #00		; 40 (
			db #60, #30, #18, #18, #18, #30, #60, #00		; 41 )
			db #00, #66, #3C, #FF, #3C, #66, #00, #00		; 42 *
			db #00, #30, #30, #FC, #30, #30, #00, #00		; 43 +
			db #00, #00, #00, #00, #00, #30, #30, #60		; 44 ,
			db #00, #00, #00, #FC, #00, #00, #00, #00		; 45 -
			db #00, #00, #00, #00, #00, #30, #30, #00		; 46 .
			db #06, #0C, #18, #30, #60, #C0, #80, #00		; 47 /
			db #7C, #C6, #CE, #DE, #F6, #E6, #7C, #00		; 48 0
			db #30, #70, #30, #30, #30, #30, #FC, #00		; 49 1
			db #78, #CC, #0C, #38, #60, #CC, #FC, #00		; 50 2
			db #78, #CC, #0C, #38, #0C, #CC, #78, #00		; 51 3
			db #1C, #3C, #6C, #CC, #FE, #0C, #1E, #00		; 52 4
			db #FC, #C0, #F8, #0C, #0C, #CC, #78, #00		; 53 5
			db #38, #60, #C0, #F8, #CC, #CC, #78, #00		; 54 6
			db #FC, #CC, #0C, #18, #30, #30, #30, #00		; 55 7
			db #78, #CC, #CC, #78, #CC, #CC, #78, #00		; 56 8
			db #78, #CC, #CC, #7C, #0C, #18, #70, #00		; 57 9
			db #00, #30, #30, #00, #00, #30, #30, #00		; 58 :
			db #00, #30, #30, #00, #00, #30, #30, #60		; 59 ;
			db #18, #30, #60, #C0, #60, #30, #18, #00		; 60 <
			db #00, #00, #FC, #00, #00, #FC, #00, #00		; 61 =
			db #60, #30, #18, #0C, #18, #30, #60, #00		; 62 >
			db #78, #CC, #0C, #18, #30, #00, #30, #00		; 63 ?
			db #7C, #C6, #DE, #DE, #DE, #C0, #78, #00		; 64 @
			db #30, #78, #CC, #CC, #FC, #CC, #CC, #00		; 65 A
			db #FC, #66, #66, #7C, #66, #66, #FC, #00		; 66 B
			db #3C, #66, #C0, #C0, #C0, #66, #3C, #00		; 67 C
			db #F8, #6C, #66, #66, #66, #6C, #F8, #00		; 68 D
			db #FE, #62, #68, #78, #68, #62, #FE, #00		; 69 E
			db #FE, #62, #68, #78, #68, #60, #F0, #00		; 70 F
			db #3C, #66, #C0, #C0, #CE, #66, #3E, #00		; 71 G
			db #CC, #CC, #CC, #FC, #CC, #CC, #CC, #00		; 72 H
			db #78, #30, #30, #30, #30, #30, #78, #00		; 73 I
			db #1E, #0C, #0C, #0C, #CC, #CC, #78, #00		; 74 J
			db #E6, #66, #6C, #78, #6C, #66, #E6, #00		; 75 K
			db #F0, #60, #60, #60, #62, #66, #FE, #00		; 76 L
			db #C6, #EE, #FE, #FE, #D6, #C6, #C6, #00		; 77 M
			db #C6, #E6, #F6, #DE, #CE, #C6, #C6, #00		; 78 N
			db #38, #6C, #C6, #C6, #C6, #6C, #38, #00		; 79 O
			db #FC, #66, #66, #7C, #60, #60, #F0, #00		; 80 P
			db #78, #CC, #CC, #CC, #DC, #78, #1C, #00		; 81 Q
			db #FC, #66, #66, #7C, #6C, #66, #E6, #00		; 82 R
			db #78, #CC, #E0, #70, #1C, #CC, #78, #00		; 83 S
			db #FC, #B4, #30, #30, #30, #30, #78, #00		; 84 T
			db #CC, #CC, #CC, #CC, #CC, #CC, #FC, #00		; 85 U
			db #CC, #CC, #CC, #CC, #CC, #78, #30, #00		; 86 V
			db #C6, #C6, #C6, #D6, #FE, #EE, #C6, #00		; 87 W
			db #C6, #C6, #6C, #38, #38, #6C, #C6, #00		; 88 X
			db #CC, #CC, #CC, #78, #30, #30, #78, #00		; 89 Y
			db #FE, #C6, #8C, #18, #32, #66, #FE, #00		; 90 Z
			db #78, #60, #60, #60, #60, #60, #78, #00		; 91 [
			db #C0, #60, #30, #18, #0C, #06, #02, #00		; 92 backslash
			db #78, #18, #18, #18, #18, #18, #78, #00		; 93 ]
			db #10, #38, #6C, #C6, #00, #00, #00, #00		; 94 ^
			db #00, #00, #00, #00, #00, #00, #00, #FF		; 95 _
			db #30, #30, #18, #00, #00, #00, #00, #00		; 96 `
			db #00, #00, #78, #0C, #7C, #CC, #76, #00		; 97 a
			db #E0, #60, #60, #7C, #66, #66, #DC, #00		; 98 b
			db #00, #00, #78, #CC, #C0, #CC, #78, #00		; 99 c
			db #1C, #0C, #0C, #7C, #CC, #CC, #76, #00		; 100 d
			db #00, #00, #78, #CC, #FC, #C0, #78, #00		; 101 e
			db #38, #6C, #60, #F0, #60, #60, #F0, #00		; 102 f
			db #00, #00, #76, #CC, #CC, #7C, #0C, #F8		; 103 g
			db #E0, #60, #6C, #76, #66, #66, #E6, #00		; 104 h
			db #30, #00, #70, #30, #30, #30, #78, #00		; 105 i
			db #0C, #00, #0C, #0C, #0C, #CC, #CC, #78		; 106 j
			db #E0, #60, #66, #6C, #78, #6C, #E6, #00		; 107 k
			db #70, #30, #30, #30, #30, #30, #78, #00		; 108 l
			db #00, #00, #CC, #FE, #FE, #D6, #C6, #00		; 109 m
			db #00, #00, #F8, #CC, #CC, #CC, #CC, #00		; 110 n
			db #00, #00, #78, #CC, #CC, #CC, #78, #00		; 111 o
			db #00, #00, #DC, #66, #66, #7C, #60, #F0		; 112 p
			db #00, #00, #76, #CC, #CC, #7C, #0C, #1E		; 113 q
			db #00, #00, #DC, #76, #66, #60, #F0, #00		; 114 r
			db #00, #00, #7C, #C0, #78, #0C, #F8, #00		; 115 s
			db #10, #30, #7C, #30, #30, #34, #18, #00		; 116 t
			db #00, #00, #CC, #CC, #CC, #CC, #76, #00		; 117 u
			db #00, #00, #CC, #CC, #CC, #78, #30, #00		; 118 v
			db #00, #00, #C6, #D6, #FE, #FE, #6C, #00		; 119 w
			db #00, #00, #C6, #6C, #38, #6C, #C6, #00		; 120 x
			db #00, #00, #CC, #CC, #CC, #7C, #0C, #F8		; 121 y
			db #00, #00, #FC, #98, #30, #64, #FC, #00		; 122 z
			db #1C, #30, #30, #E0, #30, #30, #1C, #00		; 123 {
			db #18, #18, #18, #00, #18, #18, #18, #00		; 124 |
			db #E0, #30, #30, #1C, #30, #30, #E0, #00		; 125 }
			db #76, #DC, #00, #00, #00, #00, #00, #00		; 126 ~

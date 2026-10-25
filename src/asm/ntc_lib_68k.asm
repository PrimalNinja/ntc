; ============================================================
; NTC Keyword Library - 68000 (vasm, Motorola syntax)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
;
; NTC RULES ON THE 68000
;   A7 = instruction pointer (the thread). No bsr / jsr, no -(sp) on the thread.
;   A thread is a list of longs: dc.l keyword, argument, argument ...
;   Keywords take their arguments off the thread left to right with
;   (sp)+ (an address: movea.l (sp)+, an; a literal: move.l (sp)+, dn and the
;   low word is the Integer) and end with rts, which fetches the next keyword.
;   Shared routines are entered with bra / jmp and the return address in A6,
;   and end with jmp (a6); ntc_next is a plain rts, so lea ntc_next, a6
;   makes such a routine carry on with the thread.
;   Code that needs bsr / jsr runs on the real stack: NTC_RS saves the
;   thread position in ntc_ip and loads the real stack (ntc_csp), NTC_TS puts
;   the thread back. Arguments are taken off the thread before NTC_RS.
;
; ONE MODE
;   The program runs in user mode: A7 is the user stack pointer (USP). An
;   interrupt switches the 68000 to supervisor mode and pushes its frame on
;   the supervisor stack (SSP), never on the thread, so interrupts are on
;   the whole time and every keyword is the turbo one. There is no normal
;   mode copy of anything (Turbo On / Off do nothing on the 68000).
;
; DATA
;   Integer = a 16 bit word, Long = a 32 bit long (both big endian, as the
;   68000 has them). Variables are in RAM at $FF8000-$FFFFFF, so their
;   addresses fit 16 bits sign extended (VarPtr, Peek, array descriptors).
;   Lines between ;@ram and ;@rom in a section are its RAM variables: the
;   compiler moves them into the RAM block (copied from the ROM at start).
;
; COMPARES
;   Result is the Z flag. Z = true, NZ = false. A compare keyword's rts keeps
;   it, and movea (taking a branch's label) does not touch the flags.
;
; SECTIONS
;   ";## name dep dep ..." starts a section, as in the Z80 library. The
;   platform file supplies the ntc_plat_* routines, called on the real stack
;   (jsr, end with rts), keeping d2-d7 / a2-a6:
;     ntc_plat_putc (d0.b = char 32-126), ntc_plat_newline, ntc_plat_backspace,
;     ntc_plat_cls, ntc_plat_mode (d0), ntc_plat_locate (d0 = column, d1 =
;     row, 1 based), ntc_plat_scankey (d0 = key or 0), ntc_plat_getkey (d0,
;     waits), ntc_plat_frame, ntc_plat_ticks (d0.w), ntc_plat_exit
; ============================================================

;## ntc_data @shared
; ------------------------------------------------------------
; The core every program has: the thread / real stack switch
; ------------------------------------------------------------
; (NTC_RS / NTC_TS, the macros that switch to the real stack and back, are written
; by the compiler at the top of the program, before anything uses them)
ntc_next:	rts						; A6 target that continues the thread
;@ram
ntc_csp:	dc.l 0					; the real stack (set at start)
ntc_ip:		dc.l 0					; the thread position while on the real stack
ntc_ivar:	dc.l 0					; input / inkey / ticks: dest var
ntc_sptr:	dc.l 0					; printbuf: text pointer
ntc_numbuf:	ds.b 16					; printint / long print: digits
;@rom

;## ntc_d_inbuf @data
;@ram
			dc.b 40					; ntc_inbuf's capacity (as every string variable has)
ntc_inbuf:	ds.b 41					; inputint: typed text
			even
;@rom

;## ntc_gstack
; ------------------------------------------------------------
; GOSUB return stack (grows down, 64 levels of thread positions)
; ------------------------------------------------------------
;@ram
ntc_gsp:	dc.l ntc_gstack_top
ntc_gstack:	ds.l 64
ntc_gstack_top:
;@rom

; ============================================================
; Flow
; ============================================================

;## kw_stop ntc_data ntc_plat_exit @shared
kw_stop:
			NTC_RS
			jsr ntc_plat_exit
ntc_stop_loop:
			bra ntc_stop_loop		; a Mega Drive has nowhere to go back to

;## kw_waitkey ntc_data ntc_plat_key
; kw_waitkey - wait for a key (Option PressAnyKeyOnEnd, before kw_stop)
kw_waitkey:
			NTC_RS
			jsr ntc_plat_getkey
			NTC_TS
			rts

;## kw_turbo_on ntc_data @shared
kw_turbo_on:
			rts

;## kw_turbo_off ntc_data @shared
kw_turbo_off:
			rts

;## kw_irq @shared
kw_irq:
			rts

;## kw_goto
;kw_goto, <label>
kw_goto:
			movea.l (sp), sp
			rts

;## kw_goto_iffalse
;kw_goto_iffalse, <label>  - branch if NZ (false)
kw_goto_iffalse:
			bne kw_gif_go
			addq.l #4, sp
			rts
kw_gif_go:
			movea.l (sp), sp
			rts

;## kw_goto_iftrue
;kw_goto_iftrue, <label>  - branch if Z (true)
kw_goto_iftrue:
			beq kw_git_go
			addq.l #4, sp
			rts
kw_git_go:
			movea.l (sp), sp
			rts

;## kw_goto_ifzero
;kw_goto_ifzero, <var>, <label>  - branch if var = 0
kw_goto_ifzero:
			movea.l (sp)+, a0
			tst.w (a0)
			beq kw_giz_go
			addq.l #4, sp
			rts
kw_giz_go:
			movea.l (sp), sp
			rts

;## kw_goto_ifnzero
;kw_goto_ifnzero, <var>, <label>  - branch if var <> 0
kw_goto_ifnzero:
			movea.l (sp)+, a0
			tst.w (a0)
			bne kw_ginz_go
			addq.l #4, sp
			rts
kw_ginz_go:
			movea.l (sp), sp
			rts

;## kw_gosub ntc_gstack
;kw_gosub, <label>  - return lands on the long after the label
kw_gosub:
			movea.l (sp)+, a0
			movea.l ntc_gsp, a1
			move.l sp, -(a1)
			move.l a1, ntc_gsp
			movea.l a0, sp
			rts

;## kw_return ntc_gstack
;kw_return
kw_return:
			movea.l ntc_gsp, a1
			move.l (a1)+, d0
			move.l a1, ntc_gsp
			movea.l d0, sp
			rts

;## ntc_for_jump
; tails for the FOR / NEXT keywords: SP = thread at the label long
ntc_for_take:
			movea.l (sp), sp
			rts
ntc_for_skip:
			addq.l #4, sp
			rts

;## kw_forupl ntc_for_jump
;kw_forupl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting up: skip the loop if var > limit
kw_forupl:
			movea.l (sp)+, a0
			move.l (sp)+, d1
			cmp.w (a0), d1
			blt ntc_for_take		; limit < var
			addq.l #4, sp
			rts

;## kw_forupv ntc_for_jump
;kw_forupv, <var>, <limit var>, <endlabel>
kw_forupv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d1
			cmp.w (a0), d1
			blt ntc_for_take
			addq.l #4, sp
			rts

;## kw_fordnl ntc_for_jump
;kw_fordnl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting down: skip the loop if var < limit
kw_fordnl:
			movea.l (sp)+, a0
			move.l (sp)+, d1
			cmp.w (a0), d1
			bgt ntc_for_take		; limit > var
			addq.l #4, sp
			rts

;## kw_fordnv ntc_for_jump
;kw_fordnv, <var>, <limit var>, <endlabel>
kw_fordnv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d1
			cmp.w (a0), d1
			bgt ntc_for_take
			addq.l #4, sp
			rts

;## kw_next1l ntc_for_jump
;kw_next1l, <var>, <literal limit>, <toplabel>
;  NEXT for STEP 1: inc var, back to the top while var <= limit (past 32767: ends)
kw_next1l:
			movea.l (sp)+, a0
			move.l (sp)+, d1
			addq.w #1, (a0)
			bvs ntc_for_skip
			cmp.w (a0), d1
			bge ntc_for_take		; limit >= var
			addq.l #4, sp
			rts

;## kw_next1v ntc_for_jump
;kw_next1v, <var>, <limit var>, <toplabel>
kw_next1v:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			addq.w #1, (a0)
			bvs ntc_for_skip
			move.w (a1), d1
			cmp.w (a0), d1
			bge ntc_for_take
			addq.l #4, sp
			rts

;## kw_nextupl ntc_for_jump
;kw_nextupl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a positive STEP: add, back to the top while var <= limit
kw_nextupl:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			move.l (sp)+, d1
			add.w d0, (a0)
			bvs ntc_for_skip
			cmp.w (a0), d1
			bge ntc_for_take
			addq.l #4, sp
			rts

;## kw_nextupv ntc_for_jump
;kw_nextupv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextupv:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			movea.l (sp)+, a1
			add.w d0, (a0)
			bvs ntc_for_skip
			move.w (a1), d1
			cmp.w (a0), d1
			bge ntc_for_take
			addq.l #4, sp
			rts

;## kw_nextdnl ntc_for_jump
;kw_nextdnl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a negative STEP: add, back to the top while var >= limit
kw_nextdnl:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			move.l (sp)+, d1
			add.w d0, (a0)
			bvs ntc_for_skip
			cmp.w (a0), d1
			ble ntc_for_take
			addq.l #4, sp
			rts

;## kw_nextdnv ntc_for_jump
;kw_nextdnv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextdnv:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			movea.l (sp)+, a1
			add.w d0, (a0)
			bvs ntc_for_skip
			move.w (a1), d1
			cmp.w (a0), d1
			ble ntc_for_take
			addq.l #4, sp
			rts

;## kw_forentry ntc_for_jump
;kw_forentry, <var>, <stepvar>, <limvar>, <endlabel>
;  skip the loop if var is already past lim for the step sign
kw_forentry:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			move.w (a2), d1			; lim
			tst.w (a1)
			bmi kw_fe_neg
			cmp.w (a0), d1
			blt ntc_for_take		; lim < var
			addq.l #4, sp
			rts
kw_fe_neg:
			cmp.w (a0), d1
			bgt ntc_for_take		; lim > var
			addq.l #4, sp
			rts

;## kw_fornext ntc_for_jump
;kw_fornext, <var>, <stepvar>, <limvar>, <toplabel>
;  var += step, loop back while var has not passed lim
kw_fornext:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			move.w (a1), d0
			add.w d0, (a0)
			bvs ntc_for_skip
			move.w (a2), d1
			tst.w d0
			bmi kw_fn_neg
			cmp.w (a0), d1
			bge ntc_for_take		; lim >= var
			addq.l #4, sp
			rts
kw_fn_neg:
			cmp.w (a0), d1
			ble ntc_for_take		; lim <= var
			addq.l #4, sp
			rts

; ============================================================
; Assignment
; ============================================================

;## kw_ltov
;kw_ltov, <literal>, <destvar>
kw_ltov:
			move.l (sp)+, d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_vtov
;kw_vtov, <sourcevar>, <destvar>
kw_vtov:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), (a1)
			rts

;## kw_ztov
;kw_ztov, <destvar>
kw_ztov:
			movea.l (sp)+, a0
			clr.w (a0)
			rts

;## kw_ftov
;kw_ftov, <destvar>  - Z flag to var: true = -1, false = 0
kw_ftov:
			seq d0
			ext.w d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

; ============================================================
; Arithmetic (16 bit, wrapping)
; ============================================================

;## kw_inc
kw_inc:
			movea.l (sp)+, a0
			addq.w #1, (a0)
			rts

;## kw_dec
kw_dec:
			movea.l (sp)+, a0
			subq.w #1, (a0)
			rts

;## kw_add
;kw_add, <var1>, <var2>, <destvar>
kw_add:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			add.w (a1), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_addl
;kw_addl, <var>, <literal>, <destvar>
kw_addl:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			add.w (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_subvv
;kw_subvv, <var1>, <var2>, <destvar>  - var1 - var2
kw_subvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			sub.w (a1), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_sublv
;kw_sublv, <literal>, <var>, <destvar>  - literal - var
kw_sublv:
			move.l (sp)+, d0
			movea.l (sp)+, a1
			sub.w (a1), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_2x
kw_2x:
			movea.l (sp)+, a0
			move.w (a0), d0
			add.w d0, d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_4x
kw_4x:
			movea.l (sp)+, a0
			move.w (a0), d0
			add.w d0, d0
			add.w d0, d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_mulvv
;kw_mulvv, <var1>, <var2>, <destvar>  - low 16 bits
kw_mulvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			muls.w (a1), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_mulvl
;kw_mulvl, <var>, <literal>, <destvar>
kw_mulvl:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			muls.w (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## ntc_div
; d0.w / d1.w signed, truncating: d0.w = quotient, d1.w = remainder (the
; dividend's sign). Divide by zero: quotient 0, remainder = dividend.
; -32768 / -1: quotient -32768, remainder 0 (as the Z80 library). jmp (a6)
ntc_div:
			tst.w d1
			beq ntc_div_z
			ext.l d0
			move.l d0, d2
			divs.w d1, d0
			bvs ntc_div_ov
			move.l d0, d1
			swap d1
			jmp (a6)
ntc_div_z:
			move.w d0, d1
			moveq #0, d0
			jmp (a6)
ntc_div_ov:
			move.w #$8000, d0
			moveq #0, d1
			jmp (a6)

;## kw_divvv ntc_div
;kw_divvv, <var1>, <var2>, <destvar>  - var1 \ var2
kw_divvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			lea kw_div_q, a6
			bra ntc_div
kw_div_q:
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_divvl ntc_div kw_divvv
;kw_divvl, <var>, <literal>, <destvar>
kw_divvl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			lea kw_div_q, a6
			bra ntc_div

;## kw_divlv ntc_div kw_divvv
;kw_divlv, <literal>, <var>, <destvar>
kw_divlv:
			move.l (sp)+, d0
			movea.l (sp)+, a1
			move.w (a1), d1
			lea kw_div_q, a6
			bra ntc_div

;## kw_modvv ntc_div
;kw_modvv, <var1>, <var2>, <destvar>  - var1 MOD var2
kw_modvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			lea kw_mod_r, a6
			bra ntc_div
kw_mod_r:
			movea.l (sp)+, a0
			move.w d1, (a0)
			rts

;## kw_modvl ntc_div kw_modvv
kw_modvl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			lea kw_mod_r, a6
			bra ntc_div

;## kw_modlv ntc_div kw_modvv
kw_modlv:
			move.l (sp)+, d0
			movea.l (sp)+, a1
			move.w (a1), d1
			lea kw_mod_r, a6
			bra ntc_div

;## kw_negv
kw_negv:
			movea.l (sp)+, a0
			move.w (a0), d0
			neg.w d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_absv
kw_absv:
			movea.l (sp)+, a0
			move.w (a0), d0
			bpl kw_abs_st
			neg.w d0
kw_abs_st:
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_sgnv
;kw_sgnv, <var>, <destvar>  - -1, 0 or 1
kw_sgnv:
			movea.l (sp)+, a0
			moveq #0, d0
			move.w (a0), d1
			beq kw_sgn_st
			moveq #1, d0
			tst.w d1
			bpl kw_sgn_st
			moveq #-1, d0
kw_sgn_st:
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

; ============================================================
; Bitwise / logic (true = -1, so these work as logical too)
; ============================================================

;## kw_andvv
kw_andvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			and.w (a1), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_andvl
kw_andvl:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			and.w (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_orvv
kw_orvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			or.w (a1), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_orvl
kw_orvl:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			or.w (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_xorvv
kw_xorvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			eor.w d1, d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_xorvl
kw_xorvl:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			move.w (a0), d1
			eor.w d1, d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_notv
kw_notv:
			movea.l (sp)+, a0
			move.w (a0), d0
			not.w d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

; ============================================================
; Compares - result in the Z flag (Z = true). An Scc gives #FF for true:
; adding 1 makes it 0 (Z), false 0 + 1 = 1 (NZ)
; ============================================================

;## ntc_cmp
; tails: d0 = a, d1 = b, test a <rel> b
ntc_cmp_slt:
			cmp.w d1, d0
			slt d0
			addq.b #1, d0
			rts
ntc_cmp_sle:
			cmp.w d1, d0
			sle d0
			addq.b #1, d0
			rts
ntc_cmp_sgt:
			cmp.w d1, d0
			sgt d0
			addq.b #1, d0
			rts
ntc_cmp_sge:
			cmp.w d1, d0
			sge d0
			addq.b #1, d0
			rts
ntc_cmp_ult:
			cmp.w d1, d0
			scs d0
			addq.b #1, d0
			rts
ntc_cmp_ule:
			cmp.w d1, d0
			sls d0
			addq.b #1, d0
			rts
ntc_cmp_ugt:
			cmp.w d1, d0
			shi d0
			addq.b #1, d0
			rts
ntc_cmp_uge:
			cmp.w d1, d0
			scc d0
			addq.b #1, d0
			rts
ntc_cmp_eq:
			cmp.w d1, d0
			rts
ntc_cmp_ne:
			cmp.w d1, d0
			sne d0
			addq.b #1, d0
			rts

;## kw_scpltvv ntc_cmp
kw_scpltvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_slt

;## kw_scpltvl ntc_cmp
kw_scpltvl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_slt

;## kw_scplevv ntc_cmp
kw_scplevv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_sle

;## kw_scplevl ntc_cmp
kw_scplevl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_sle

;## kw_scpgtvv ntc_cmp
kw_scpgtvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_sgt

;## kw_scpgtvl ntc_cmp
kw_scpgtvl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_sgt

;## kw_scpgevv ntc_cmp
kw_scpgevv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_sge

;## kw_scpgevl ntc_cmp
kw_scpgevl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_sge

;## kw_cpltvv ntc_cmp
kw_cpltvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_ult

;## kw_cpltvl ntc_cmp
kw_cpltvl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_ult

;## kw_cplevv ntc_cmp
kw_cplevv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_ule

;## kw_cplevl ntc_cmp
kw_cplevl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_ule

;## kw_cpgtvv ntc_cmp
kw_cpgtvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_ugt

;## kw_cpgtvl ntc_cmp
kw_cpgtvl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_ugt

;## kw_cpgevv ntc_cmp
kw_cpgevv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_uge

;## kw_cpgevl ntc_cmp
kw_cpgevl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_uge

;## kw_cpeqvv
kw_cpeqvv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			cmp.w (a1), d0
			rts

;## kw_cpeqvl
kw_cpeqvl:
			movea.l (sp)+, a0
			move.l (sp)+, d1
			cmp.w (a0), d1
			rts

;## kw_cpnevv ntc_cmp
kw_cpnevv:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a0), d0
			move.w (a1), d1
			bra ntc_cmp_ne

;## kw_cpnevl ntc_cmp
kw_cpnevl:
			movea.l (sp)+, a0
			move.w (a0), d0
			move.l (sp)+, d1
			bra ntc_cmp_ne

; ============================================================
; Memory (PEEK / POKE / DEEK / DOKE). An Integer address is sign extended:
; 0-32767 = the ROM's first 32K, -32768..-1 = RAM $FF8000-$FFFFFF
; (where the variables are). DEEK / DOKE need an even address.
; ============================================================

;## kw_lptrtov8
;kw_lptrtov8, <literaladdr>, <destvar>  - PEEK(literal)
kw_lptrtov8:
			move.l (sp)+, d0
			movea.w d0, a0
			moveq #0, d0
			move.b (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_vptrtov8
;kw_vptrtov8, <addrvar>, <destvar>  - PEEK(var)
kw_vptrtov8:
			movea.l (sp)+, a0
			movea.w (a0), a0
			moveq #0, d0
			move.b (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_lptrtov
;kw_lptrtov, <literaladdr>, <destvar>  - DEEK(literal)
kw_lptrtov:
			move.l (sp)+, d0
			movea.w d0, a0
			movea.l (sp)+, a1
			move.w (a0), (a1)
			rts

;## kw_vptrtov
;kw_vptrtov, <addrvar>, <destvar>  - DEEK(var)
kw_vptrtov:
			movea.l (sp)+, a0
			movea.w (a0), a0
			movea.l (sp)+, a1
			move.w (a0), (a1)
			rts

;## kw_ltovptr8
;kw_ltovptr8, <literal>, <addrvar>  - POKE var, literal
kw_ltovptr8:
			move.l (sp)+, d0
			movea.l (sp)+, a0
			movea.w (a0), a0
			move.b d0, (a0)
			rts

;## kw_vtovptr8
;kw_vtovptr8, <sourcevar>, <addrvar>  - POKE var, var
kw_vtovptr8:
			movea.l (sp)+, a1
			move.w (a1), d0
			movea.l (sp)+, a0
			movea.w (a0), a0
			move.b d0, (a0)
			rts

;## kw_ltolptr8
;kw_ltolptr8, <literal>, <literaladdr>  - POKE literal, literal
kw_ltolptr8:
			move.l (sp)+, d0
			move.l (sp)+, d1
			movea.w d1, a0
			move.b d0, (a0)
			rts

;## kw_vtolptr8
;kw_vtolptr8, <sourcevar>, <literaladdr>  - POKE literal, var
kw_vtolptr8:
			movea.l (sp)+, a1
			move.w (a1), d0
			move.l (sp)+, d1
			movea.w d1, a0
			move.b d0, (a0)
			rts

;## kw_ltovptr
;kw_ltovptr, <literal>, <addrvar>  - DOKE var, literal
kw_ltovptr:
			move.l (sp)+, d0
			movea.l (sp)+, a0
			movea.w (a0), a0
			move.w d0, (a0)
			rts

;## kw_vtovptr
;kw_vtovptr, <sourcevar>, <addrvar>  - DOKE var, var
kw_vtovptr:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			movea.w (a0), a0
			move.w (a1), (a0)
			rts

;## kw_ltolptr
;kw_ltolptr, <literal>, <literaladdr>  - DOKE literal, literal
kw_ltolptr:
			move.l (sp)+, d0
			move.l (sp)+, d1
			movea.w d1, a0
			move.w d0, (a0)
			rts

;## kw_vtolptr
;kw_vtolptr, <sourcevar>, <literaladdr>  - DOKE literal, var
kw_vtolptr:
			movea.l (sp)+, a1
			move.l (sp)+, d1
			movea.w d1, a0
			move.w (a1), (a0)
			rts

; ============================================================
; Arrays (16 bit elements, no bounds check)
; ============================================================

;## kw_aget
;kw_aget, <arraybase>, <indexvar>, <destvar>
kw_aget:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			ext.l d0
			add.l d0, d0
			movea.l (sp)+, a1
			move.w 0(a0, d0.l), (a1)
			rts

;## kw_aset
;kw_aset, <arraybase>, <indexvar>, <sourcevar>
kw_aset:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			ext.l d0
			add.l d0, d0
			movea.l (sp)+, a1
			move.w (a1), 0(a0, d0.l)
			rts

;## kw_asetl
;kw_asetl, <arraybase>, <indexvar>, <literal>
kw_asetl:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			ext.l d0
			add.l d0, d0
			move.l (sp)+, d1
			move.w d1, 0(a0, d0.l)
			rts

;## kw_aget8
;kw_aget8, <arraybase>, <indexvar>, <destvar>  - Byte array element (0 .. 255)
kw_aget8:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			ext.l d0
			moveq #0, d1
			move.b 0(a0, d0.l), d1
			movea.l (sp)+, a1
			move.w d1, (a1)
			rts

;## kw_aset8
;kw_aset8, <arraybase>, <indexvar>, <sourcevar>  - set a Byte array element (low byte)
kw_aset8:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			ext.l d0
			movea.l (sp)+, a1
			move.b 1(a1), 0(a0, d0.l)
			rts

;## kw_erase
;kw_erase, <base>, <bytes>  - Erase of a fixed size array: zero it
kw_erase:
			movea.l (sp)+, a0
			move.l (sp)+, d0
ntc_zerofill:					; a0 = start, d0.w = bytes (unsigned)
			andi.l #$FFFF, d0
			beq ntc_zf_end
			subq.l #1, d0
ntc_zf_lp:
			clr.b (a0)+
			dbra d0, ntc_zf_lp
ntc_zf_end:
			rts

;## kw_redim kw_erase
;kw_redim, <descriptor>, <base>, <lower>, <size>, <count>, <clear>  - ReDim: fill the
;  descriptor (1 dimension); clear <> 0: zero the elements. Descriptor (12 bytes):
;  base (16 bits: RAM), lower 1, lower 2, count 1, count 2, element size
kw_redim:
			movea.l (sp)+, a1
			move.l (sp)+, d3			; base
			move.l (sp)+, d4			; lower
			move.l (sp)+, d5			; size
			move.l (sp)+, d6			; count
			move.l (sp)+, d7			; clear
			move.w d3, (a1)
			move.w d4, 2(a1)
			clr.w 4(a1)
			move.w d6, 6(a1)
			move.w #1, 8(a1)
			move.w d5, 10(a1)
			tst.w d7
			beq kw_rd_end
			movea.l d3, a0
			mulu.w d5, d6
			move.l d6, d0
kw_rd_lp:
			clr.b (a0)+
			subq.l #1, d0
			bhi kw_rd_lp
kw_rd_end:
			rts

; ============================================================
; Random (16 bit xorshift 7,9,8 - the Z80 library's sequence)
; ============================================================

;## ntc_rnd_seed
;@ram
ntc_rnd_seed:	dc.w 1
;@rom

;## kw_rndv ntc_rnd_seed ntc_div kw_rndl
;kw_rndv, <nvar>, <destvar>  - 0 .. n-1 (0 if n <= 0)
kw_rndv:
			movea.l (sp)+, a0
			move.w (a0), d1
			bra ntc_rnd

;## kw_rndl ntc_rnd_seed ntc_div
;kw_rndl, <literal>, <destvar>
kw_rndl:
			move.l (sp)+, d1
ntc_rnd:
			move.w ntc_rnd_seed, d0		; h = high byte, l = low byte
			move.w d0, d2
			lsr.w #8, d2				; d2 = h
			moveq #0, d3
			move.b d0, d3				; d3 = l
			; h' = ((h & 1) << 7 | l >> 1) xor h
			move.b d2, d4
			andi.b #1, d4
			ror.b #1, d4
			move.b d3, d5
			lsr.b #1, d5
			or.b d5, d4
			eor.b d2, d4				; d4 = h'
			; l' = ((l & 1) << 7 | h' >> 1) xor l
			move.b d3, d5
			andi.b #1, d5
			ror.b #1, d5
			move.b d4, d6
			lsr.b #1, d6
			or.b d6, d5
			eor.b d3, d5				; d5 = l'
			eor.b d5, d4				; h'' = l' xor h'
			moveq #0, d0
			move.b d4, d0
			lsl.w #8, d0
			move.b d5, d0
			move.w d0, ntc_rnd_seed
			tst.w d1
			ble ntc_rnd_zero
			andi.w #$7FFF, d0
			lea kw_mod_rr, a6
			bra ntc_div
kw_mod_rr:
			movea.l (sp)+, a0
			move.w d1, (a0)
			rts
ntc_rnd_zero:
			movea.l (sp)+, a0
			clr.w (a0)
			rts

;## kw_seedv ntc_rnd_seed
;kw_seedv, <var>  - RANDOMIZE var (0 becomes 1)
kw_seedv:
			movea.l (sp)+, a0
			move.w (a0), d0
			bne kw_sd_ok
			moveq #1, d0
kw_sd_ok:
			move.w d0, ntc_rnd_seed
			rts

;## kw_seedl ntc_rnd_seed
;kw_seedl, <literal>
kw_seedl:
			move.l (sp)+, d0
			tst.w d0
			bne kw_sdl_ok
			moveq #1, d0
kw_sdl_ok:
			move.w d0, ntc_rnd_seed
			rts

; ============================================================
; Strings: 0 terminated. A string variable or temp has its capacity
; (1 .. 255 chars) in the byte before it: [cap][text...][0]. Array
; elements have no capacity byte (the caller gives the element size).
; ============================================================

;## kw_strcpy
;kw_strcpy, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcpy:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			moveq #0, d1
			move.b -1(a1), d1
ntc_strcpy_lp:					; a0 -> a1, at most d1 chars (d1.w > 0), then the 0
			subq.w #1, d1
			bmi ntc_strcpy_cut
ntc_strcpy_l2:
			move.b (a0)+, (a1)+
			dbeq d1, ntc_strcpy_l2
			beq ntc_strcpy_e
ntc_strcpy_cut:
			clr.b (a1)
ntc_strcpy_e:
			rts

;## kw_strcpyn kw_strcpy
;kw_strcpyn, <destaddr>, <srcaddr>, <capacity>  - into an array element (no capacity byte)
kw_strcpyn:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.l (sp)+, d1
			andi.w #$FF, d1
			bra ntc_strcpy_lp

;## kw_strcat
;kw_strcat, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcat:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			moveq #0, d1
			move.b -1(a1), d1
kw_sc_end:
			tst.b (a1)
			beq kw_sc_copy
			addq.l #1, a1
			subq.w #1, d1
			bgt kw_sc_end
			rts
kw_sc_copy:
			tst.w d1
			beq kw_sc_none
			subq.w #1, d1
kw_sc_lp:
			move.b (a0)+, (a1)+
			dbeq d1, kw_sc_lp
			beq kw_sc_none
			clr.b (a1)
kw_sc_none:
			rts

;## kw_strlen
;kw_strlen, <straddr>, <destvar>
kw_strlen:
			movea.l (sp)+, a0
			moveq #-1, d0
kw_sl_lp:
			addq.w #1, d0
			tst.b (a0)+
			bne kw_sl_lp
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_strcmpeq
;kw_strcmpeq, <addr1>, <addr2>  - Z if equal
kw_strcmpeq:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
kw_seq_lp:
			move.b (a0)+, d0
			cmp.b (a1)+, d0
			bne kw_seq_no
			tst.b d0
			bne kw_seq_lp
kw_seq_no:
			rts

;## kw_strcmpne
;kw_strcmpne, <addr1>, <addr2>  - Z if not equal
kw_strcmpne:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
kw_sne_lp:
			move.b (a0)+, d0
			cmp.b (a1)+, d0
			bne kw_sne_t
			tst.b d0
			bne kw_sne_lp
			moveq #1, d0				; equal: NZ
			rts
kw_sne_t:
			moveq #0, d0				; not equal: Z
			rts

; ============================================================
; I/O. The platform's console routines run on the real stack.
; ============================================================

;## ntc_printbuf ntc_data ntc_plat_screen
; print the 0 terminated text at a0, then rts (thread). On the thread.
ntc_printbuf:
			NTC_RS
			movea.l a0, a2
ntc_pb_lp:
			moveq #0, d0
			move.b (a2)+, d0
			beq ntc_pb_end
			jsr ntc_plat_putc
			bra ntc_pb_lp
ntc_pb_end:
			NTC_TS
			rts

;## kw_printstrvar ntc_printbuf
;kw_printstrvar, <straddr>
kw_printstrvar:
			movea.l (sp)+, a0
			bra ntc_printbuf

;## ntc_itoa ntc_data
; d0.w = signed value, a1 = buffer: the digits and a 0 (a1 ends on the 0).
; jmp (a6). Uses d0-d2, a0
ntc_itoa:
			ext.l d0
			bpl ntc_ia_pos
			move.b #'-', (a1)+
			neg.l d0
ntc_ia_pos:
			lea ntc_ia_tmp+8, a0
			clr.b -(a0)
ntc_ia_lp:
			divu.w #10, d0
			swap d0
			addi.b #'0', d0
			move.b d0, -(a0)
			clr.w d0
			swap d0
			tst.w d0
			bne ntc_ia_lp
ntc_ia_cp:
			move.b (a0)+, (a1)+
			bne ntc_ia_cp
			subq.l #1, a1
			jmp (a6)
;@ram
ntc_ia_tmp:	ds.b 8
;@rom

;## kw_printint ntc_printbuf ntc_itoa
;kw_printint, <var>  - signed decimal
kw_printint:
			movea.l (sp)+, a0
			move.w (a0), d0
			lea ntc_numbuf, a1
			lea kw_pi_done, a6
			bra ntc_itoa
kw_pi_done:
			lea ntc_numbuf, a0
			bra ntc_printbuf

;## kw_printintvb ntc_printbuf ntc_itoa
;kw_printintvb, <var>  - Option VBPrint: a space (or the -), the digits, a space
kw_printintvb:
			movea.l (sp)+, a0
			move.w (a0), d0
			lea ntc_numbuf, a1
			tst.w d0
			bmi kw_piv_neg
			move.b #' ', (a1)+
kw_piv_neg:
			lea kw_piv_done, a6
			bra ntc_itoa
kw_piv_done:
			move.b #' ', (a1)+
			clr.b (a1)
			lea ntc_numbuf, a0
			bra ntc_printbuf

;## kw_printtab ntc_data ntc_plat_screen
;kw_printtab, <nvar>  - Tab(n) in Print: spaces up to column n (1 based),
;  a new line first when the cursor is already past it. n off the line: nothing
kw_printtab:
			movea.l (sp)+, a0
			move.w (a0), d2
			subq.w #1, d2
ntc_pt_go:						; d2 = the column (0 based)
			moveq #0, d0
			move.b ntc_scols, d0
			cmp.w d0, d2
			bcc ntc_pt_end			; (also below 0: unsigned)
			NTC_RS
			moveq #0, d0
			move.b ntc_curx, d0
			cmp.w d0, d2
			bcc ntc_pt_lp
			jsr ntc_plat_newline
ntc_pt_lp:
			moveq #0, d0
			move.b ntc_curx, d0
			cmp.w d0, d2
			bls ntc_pt_done
			moveq #' ', d0
			jsr ntc_plat_putc
			bra ntc_pt_lp
ntc_pt_done:
			NTC_TS
ntc_pt_end:
			rts

;## kw_printzone kw_printtab
;kw_printzone  - Option VBPrint: a comma in Print moves to the next 14 column zone
kw_printzone:
			moveq #0, d0
			move.b ntc_curx, d0
			moveq #14, d2
kw_pz_find:
			cmp.w d0, d2
			bhi kw_pz_got
			addi.w #14, d2
			bra kw_pz_find
kw_pz_got:
			moveq #0, d0
			move.b ntc_scols, d0
			cmp.w d0, d2
			bcs ntc_pt_go
			NTC_RS
			jsr ntc_plat_newline
			NTC_TS
			rts

;## kw_printnl0 ntc_data ntc_plat_screen
;kw_printnl0  - new line unless the cursor is at the start of a line
kw_printnl0:
			tst.b ntc_curx
			beq kw_pn0_end
			NTC_RS
			jsr ntc_plat_newline
			NTC_TS
kw_pn0_end:
			rts

;## kw_printnl ntc_data ntc_plat_screen
kw_printnl:
			NTC_RS
			jsr ntc_plat_newline
			NTC_TS
			rts

;## kw_callp
;kw_callp, <addressvar>, <arg>, ...  - CallAddr: jump to the procedure call stub whose
;  number (AddressOf on the 68000: its place in the program's ntc_aptab) is in the var
kw_callp:
			movea.l (sp)+, a0
			move.w (a0), d0
			lsl.w #2, d0
			lea ntc_aptab, a0
			movea.l 0(a0, d0.w), a0
			jmp (a0)

;## kw_callv
;kw_callv, <addrvar>  - run machine code at the address in the var (a keyword: ends rts)
kw_callv:
			movea.l (sp)+, a0
			movea.w (a0), a0
			jmp (a0)

;## kw_inp
;kw_inp, <portvar>, <dest>  - Inp(n): the byte at $A10000 + n (the I/O area: 1 the
;  version, 3 / 5 / 7 the ports' data, 9 / B / D their control)
kw_inp:
			movea.l (sp)+, a0
			move.w (a0), d0
			ext.l d0
			addi.l #$A10000, d0
			movea.l d0, a0
			moveq #0, d0
			move.b (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_out
;kw_out, <portvar>, <valuevar>  - Out n, v: the byte at $A10000 + n
kw_out:
			movea.l (sp)+, a0
			move.w (a0), d0
			ext.l d0
			addi.l #$A10000, d0
			movea.l (sp)+, a1
			movea.l d0, a0
			move.b 1(a1), (a0)
			rts

;## ntc_gets ntc_data ntc_plat_screen ntc_plat_key
; line input with echo and backspace, on the real stack (jsr). a2 = buffer (its
; capacity in the byte before it). 0 terminated, then a new line.
ntc_gets:
			moveq #0, d3
			move.b -1(a2), d3			; capacity
			moveq #0, d4				; typed
ntc_gs_wait:
			jsr ntc_plat_getkey
			cmpi.b #13, d0
			beq ntc_gs_done
			cmpi.b #127, d0
			beq ntc_gs_del
			cmpi.b #8, d0
			beq ntc_gs_del
			cmpi.b #32, d0
			bcs ntc_gs_wait
			cmp.w d3, d4
			bcc ntc_gs_wait
			move.b d0, 0(a2, d4.w)
			addq.w #1, d4
			jsr ntc_plat_putc
			bra ntc_gs_wait
ntc_gs_del:
			tst.w d4
			beq ntc_gs_wait
			subq.w #1, d4
			jsr ntc_plat_backspace
			bra ntc_gs_wait
ntc_gs_done:
			clr.b 0(a2, d4.w)
			jmp ntc_plat_newline

;## kw_inputstr ntc_gets
;kw_inputstr, <straddr>
kw_inputstr:
			movea.l (sp)+, a2
			NTC_RS
			jsr ntc_gets
			NTC_TS
			rts

;## kw_inputint ntc_gets ntc_atoi ntc_d_inbuf
;kw_inputint, <var>  - signed decimal, stops at the first non digit
kw_inputint:
			move.l (sp)+, ntc_ivar
			lea ntc_inbuf, a2
			NTC_RS
			jsr ntc_gets
			NTC_TS
			lea ntc_inbuf, a0
			bra ntc_atoi

;## ntc_atoi ntc_data
; text at a0 to a number into the var at (ntc_ivar). Spaces first, then - , then
; digits (or &H hex). Then rts (the thread).
ntc_atoi:
			moveq #0, d0				; value
			moveq #0, d2				; minus
ntc_at_sp:
			move.b (a0), d1
			cmpi.b #' ', d1
			bne ntc_at_sg
			addq.l #1, a0
			bra ntc_at_sp
ntc_at_sg:
			cmpi.b #'-', d1
			bne ntc_at_amp
			moveq #1, d2
			addq.l #1, a0
			move.b (a0), d1
ntc_at_amp:
			cmpi.b #'&', d1
			bne ntc_at_dec
			addq.l #1, a0
			move.b (a0)+, d1
			ori.b #$20, d1
			cmpi.b #'h', d1
			bne ntc_at_done
ntc_at_hex:
			moveq #0, d1
			move.b (a0)+, d1
			subi.b #'0', d1
			bcs ntc_at_done
			cmpi.b #10, d1
			bcs ntc_at_hd
			ori.b #$20, d1
			subi.b #'a'-'0', d1
			bcs ntc_at_done
			cmpi.b #6, d1
			bcc ntc_at_done
			addi.b #10, d1
ntc_at_hd:
			lsl.w #4, d0
			or.w d1, d0
			bra ntc_at_hex
ntc_at_dec:
			moveq #0, d1
			move.b (a0)+, d1
			subi.b #'0', d1
			bcs ntc_at_done
			cmpi.b #10, d1
			bcc ntc_at_done
			mulu.w #10, d0
			add.w d1, d0
			bra ntc_at_dec
ntc_at_done:
			tst.w d2
			beq ntc_at_st
			neg.w d0
ntc_at_st:
			movea.l ntc_ivar, a0
			move.w d0, (a0)
			rts

;## kw_inkey ntc_data ntc_plat_key
;kw_inkey, <destvar>  - new key press or 0, no wait
kw_inkey:
			movea.l (sp)+, a2
			NTC_RS
			jsr ntc_plat_scankey
			NTC_TS
			andi.w #$FF, d0
			move.w d0, (a2)
			rts

;## kw_inkeys ntc_data ntc_plat_key
;kw_inkeys, <dest>  - Inkey$: the new key press as a string, "" if none
kw_inkeys:
			movea.l (sp)+, a2
			NTC_RS
			jsr ntc_plat_scankey
			NTC_TS
			move.b d0, (a2)+
			beq kw_iks_e
			clr.b (a2)
kw_iks_e:
			rts

;## kw_scrinit ntc_data ntc_plat_screen
kw_scrinit:
			rts

;## kw_cls ntc_data ntc_plat_screen
kw_cls:
			NTC_RS
			jsr ntc_plat_cls
			NTC_TS
			rts

;## kw_locatell ntc_data ntc_plat_screen
;kw_locatell, <x>, <y>  - 1 based
kw_locatell:
			move.l (sp)+, d0
			move.l (sp)+, d1
			NTC_RS
			jsr ntc_plat_locate
			NTC_TS
			rts

;## kw_locatevv ntc_data ntc_plat_screen
;kw_locatevv, <xvar>, <yvar>
kw_locatevv:
			movea.l (sp)+, a0
			move.w (a0), d0
			movea.l (sp)+, a0
			move.w (a0), d1
			NTC_RS
			jsr ntc_plat_locate
			NTC_TS
			rts

;## kw_model ntc_data ntc_plat_screen
;kw_model, <literal>  - clears the screen
kw_model:
			move.l (sp)+, d0
			NTC_RS
			jsr ntc_plat_mode
			NTC_TS
			rts

;## kw_modev ntc_data ntc_plat_screen
kw_modev:
			movea.l (sp)+, a0
			move.w (a0), d0
			NTC_RS
			jsr ntc_plat_mode
			NTC_TS
			rts

;## kw_frame ntc_data ntc_plat_frame
;kw_frame  - wait for the start of the next frame (vertical blank)
kw_frame:
			NTC_RS
			jsr ntc_plat_frame
			NTC_TS
			rts

;## kw_ticks ntc_data ntc_plat_ticks
;kw_ticks, <destvar>  - the tick count (frames, 60 or 50 a second)
kw_ticks:
			movea.l (sp)+, a2
			NTC_RS
			jsr ntc_plat_ticks
			NTC_TS
			move.w d0, (a2)
			rts

; ============================================================
; String functions. Numbers are passed as the address of a word.
; Results go to a string buffer. Dest may be the same as the source.
; ============================================================

;## ntc_getn
; a0 = address of a word: d0.w = its value limited to 0..255. jmp (a6). Keeps others.
ntc_getn:
			move.w (a0), d0
			bmi ntc_gn_zero
			cmpi.w #255, d0
			bls ntc_gn_ok
			move.w #255, d0
ntc_gn_ok:
			jmp (a6)
ntc_gn_zero:
			moveq #0, d0
			jmp (a6)

;## kw_strleft ntc_getn
;kw_strleft, <dest>, <src>, <nvar>  - Left$(src, n)
kw_strleft:
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			movea.l (sp)+, a0
			lea kw_sl_n, a6
			bra ntc_getn
kw_sl_n:
			movea.l a2, a0
; copy up to d0.w chars from a0 to a1, then the 0. rts (the thread)
ntc_strncpy:
			subq.w #1, d0
			bmi ntc_sn_end
ntc_sn_lp:
			move.b (a0)+, (a1)+
			dbeq d0, ntc_sn_lp
			beq ntc_sn_z
ntc_sn_end:
			clr.b (a1)
ntc_sn_z:
			rts

;## kw_strright ntc_getn kw_strleft
;kw_strright, <dest>, <src>, <nvar>  - Right$(src, n)
kw_strright:
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			movea.l (sp)+, a0
			lea kw_sr_n, a6
			bra ntc_getn
kw_sr_n:
			movea.l a2, a0
			moveq #-1, d1
kw_sr_len:
			addq.w #1, d1
			tst.b (a0)+
			bne kw_sr_len
			sub.w d0, d1				; len - n
			bpl kw_sr_skip
			moveq #0, d1
kw_sr_skip:
			lea 0(a2, d1.w), a0
			move.w #255, d0
			bra ntc_strncpy

;## kw_pow
;kw_pow, <basevar>, <expvar>, <destvar>  - base ^ exp (Integer, low 16 bits; exp < 0 gives 0)
kw_pow:
			movea.l (sp)+, a0
			move.w (a0), d1				; base
			movea.l (sp)+, a0
			move.w (a0), d2				; exp
			moveq #1, d0
			tst.w d2
			bpl kw_pw_lp
			moveq #0, d0
			bra kw_pw_st
kw_pw_lp:
			tst.w d2
			beq kw_pw_st
			muls.w d1, d0
			subq.w #1, d2
			bra kw_pw_lp
kw_pw_st:
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_sqr
;kw_sqr, <var>, <destvar>  - Sqr: whole number square root (negative gives 0)
kw_sqr:
			movea.l (sp)+, a0
			move.w (a0), d0
			moveq #0, d1
			tst.w d0
			bmi kw_sq_done
			moveq #1, d2
kw_sq_lp:
			sub.w d2, d0
			bcs kw_sq_done
			addq.w #1, d1
			addq.w #2, d2
			bra kw_sq_lp
kw_sq_done:
			movea.l (sp)+, a0
			move.w d1, (a0)
			rts

;## kw_strrev
;kw_strrev, <dest>, <src>  - StrReverse
kw_strrev:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			cmpa.l a0, a1
			beq kw_rv_go
			movea.l a1, a2
kw_rv_cl:
			move.b (a0)+, (a2)+
			bne kw_rv_cl
kw_rv_go:
			movea.l a1, a0
kw_rv_end:
			tst.b (a0)+
			bne kw_rv_end
			subq.l #2, a0
kw_rv_sw:
			cmpa.l a0, a1
			bcc kw_rv_done
			move.b (a1), d0
			move.b (a0), (a1)+
			move.b d0, (a0)
			subq.l #1, a0
			bra kw_rv_sw
kw_rv_done:
			rts

;## kw_stroct
;kw_stroct, <dest>, <var>  - Oct$ (16 bit unsigned, no leading zeros)
kw_stroct:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			moveq #0, d0
			move.w (a0), d0
			moveq #15, d1				; the digits' shifts: 15 (1 bit), 12, 9, 6, 3, 0
			moveq #0, d3				; digit seen
kw_oc_lp:
			move.l d0, d2
			lsr.l d1, d2
			andi.w #7, d2
			bne kw_oc_out
			tst.w d3
			bne kw_oc_out
			tst.w d1
			bne kw_oc_skip
kw_oc_out:
			moveq #1, d3
			addi.b #'0', d2
			move.b d2, (a1)+
kw_oc_skip:
			subq.w #3, d1
			bpl kw_oc_lp
			clr.b (a1)
			rts

;## kw_strinstrrev
;kw_strinstrrev, <text>, <find>, <startvar>, <destvar>  - InStrRev (start -1 = from the end)
kw_strinstrrev:
			movea.l (sp)+, a2			; text
			movea.l (sp)+, a3			; find
			movea.l (sp)+, a0
			move.w (a0), d4				; start
			movea.l a2, a0
			moveq #-1, d1
kw_ir_l1:
			addq.w #1, d1
			tst.b (a0)+
			bne kw_ir_l1				; d1 = len(text)
			movea.l a3, a0
			moveq #-1, d2
kw_ir_l2:
			addq.w #1, d2
			tst.b (a0)+
			bne kw_ir_l2				; d2 = len(find)
			move.w d1, d0
			sub.w d2, d0
			addq.w #1, d0				; last place it can start (1 based)
			tst.w d4
			ble kw_ir_lp
			cmp.w d0, d4
			bcc kw_ir_lp
			move.w d4, d0
kw_ir_lp:
			tst.w d0
			ble kw_ir_none
			lea -1(a2, d0.w), a0
			movea.l a3, a1
kw_ir_cmp:
			move.b (a1)+, d3
			beq kw_ir_found
			cmp.b (a0)+, d3
			beq kw_ir_cmp
			subq.w #1, d0
			bra kw_ir_lp
kw_ir_none:
			moveq #0, d0
kw_ir_found:
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_strreplace
;kw_strreplace, <dest>, <text>, <find>, <with>  - Replace (NTC_STRMAX characters at most)
kw_strreplace:
			movea.l (sp)+, a4			; dest
			movea.l (sp)+, a2			; text
			movea.l (sp)+, a3			; find
			movea.l (sp)+, a5			; with
			lea ntc_rpbuf, a1
			move.w #NTC_STRMAX, d4		; room
			tst.b (a3)
			beq kw_rp_rest
kw_rp_lp:
			tst.b (a2)
			beq kw_rp_done
			movea.l a2, a0
			movea.l a3, a6
kw_rp_m:
			move.b (a6)+, d0
			beq kw_rp_hit
			cmp.b (a0)+, d0
			beq kw_rp_m
			; miss: one char across
			tst.w d4
			beq kw_rp_done
			move.b (a2)+, (a1)+
			subq.w #1, d4
			bra kw_rp_lp
kw_rp_hit:
			movea.l a0, a2
			movea.l a5, a0
kw_rp_w:
			move.b (a0)+, d0
			beq kw_rp_lp
			tst.w d4
			beq kw_rp_done
			move.b d0, (a1)+
			subq.w #1, d4
			bra kw_rp_w
kw_rp_rest:
			move.b (a2)+, d0
			beq kw_rp_done
			tst.w d4
			beq kw_rp_done
			move.b d0, (a1)+
			subq.w #1, d4
			bra kw_rp_rest
kw_rp_done:
			clr.b (a1)
			lea ntc_rpbuf, a0
kw_rp_out:
			move.b (a0)+, (a4)+
			bne kw_rp_out
			rts
;@ram
ntc_rpbuf:	ds.b NTC_STRMAX+1
			even
;@rom

;## kw_strlike
;kw_strlike, <text>, <pattern>  - Z if text Like pattern: * any run, ? one char,
;  # one digit, [abc] / [a-z] one of, [!abc] none of. Case matters
kw_strlike:
			movea.l (sp)+, a1			; text
			movea.l (sp)+, a0			; pattern
			suba.l a2, a2				; the last * (pattern after it), 0 none
			suba.l a3, a3				; where the text was then
kw_lk_lp:
			tst.b (a1)
			beq kw_lk_end
			move.b (a0), d0
			cmpi.b #'*', d0
			bne kw_lk_one
			addq.l #1, a0
			movea.l a0, a2
			movea.l a1, a3
			bra kw_lk_lp
kw_lk_one:
			move.b (a1), d1				; the text char
			tst.b d0
			beq kw_lk_back
			cmpi.b #'?', d0
			beq kw_lk_ok1
			cmpi.b #'#', d0
			bne kw_lk_br
			cmpi.b #'0', d1
			bcs kw_lk_back
			cmpi.b #'9'+1, d1
			bcc kw_lk_back
kw_lk_ok1:
			addq.l #1, a0
			addq.l #1, a1
			bra kw_lk_lp
kw_lk_br:
			cmpi.b #'[', d0
			bne kw_lk_lit
			addq.l #1, a0
			moveq #0, d4				; ! = 1
			cmpi.b #'!', (a0)
			bne kw_lk_c0
			moveq #1, d4
			addq.l #1, a0
kw_lk_c0:
			moveq #0, d5				; hit
kw_lk_cl:
			move.b (a0), d2
			beq kw_lk_back
			cmpi.b #']', d2
			beq kw_lk_clend
			move.b d2, d3				; lo, hi
			addq.l #1, a0
			cmpi.b #'-', (a0)
			bne kw_lk_cmp
			addq.l #1, a0
			move.b (a0), d6
			cmpi.b #']', d6
			beq kw_lk_dash
			tst.b d6
			beq kw_lk_back
			move.b d6, d3
			addq.l #1, a0
			bra kw_lk_cmp
kw_lk_dash:
			subq.l #1, a0
kw_lk_cmp:
			cmp.b d2, d1
			bcs kw_lk_cl
			cmp.b d3, d1
			bhi kw_lk_cl
			moveq #1, d5
			bra kw_lk_cl
kw_lk_clend:
			addq.l #1, a0
			cmp.b d4, d5
			beq kw_lk_back
			addq.l #1, a1
			bra kw_lk_lp
kw_lk_lit:
			cmp.b d0, d1
			bne kw_lk_back
			addq.l #1, a0
			addq.l #1, a1
			bra kw_lk_lp
kw_lk_back:
			cmpa.w #0, a2
			beq kw_lk_no
			addq.l #1, a3
			movea.l a3, a1
			movea.l a2, a0
			bra kw_lk_lp
kw_lk_end:
			move.b (a0), d0
			cmpi.b #'*', d0
			bne kw_lk_e2
			addq.l #1, a0
			bra kw_lk_end
kw_lk_e2:
			tst.b d0
			rts
kw_lk_no:
			moveq #1, d0
			rts

;## kw_strlset
;kw_strlset, <dest>, <src>  - LSet dest = src: src left in dest's length, spaces after
kw_strlset:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			movea.l a1, a2
			moveq #0, d1
kw_ls_len:
			tst.b (a2)+
			beq kw_ls_go
			addq.w #1, d1
			bra kw_ls_len
kw_ls_go:
			tst.w d1
			beq kw_ls_e
			subq.w #1, d1
kw_ls_cp:
			move.b (a0), d0
			beq kw_ls_pad
			addq.l #1, a0
			move.b d0, (a1)+
			dbra d1, kw_ls_cp
kw_ls_e:
			rts
kw_ls_pad:
			move.b #' ', (a1)+
			dbra d1, kw_ls_pad
			rts

;## kw_strrset
;kw_strrset, <dest>, <src>  - RSet dest = src: src right in dest's length, spaces before
kw_strrset:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			movea.l a1, a2
			moveq #0, d1
kw_rs_len:
			tst.b (a2)+
			beq kw_rs_l2
			addq.w #1, d1
			bra kw_rs_len
kw_rs_l2:
			movea.l a0, a2
			moveq #0, d2
kw_rs_len2:
			tst.b (a2)+
			beq kw_rs_go
			addq.w #1, d2
			bra kw_rs_len2
kw_rs_go:
			tst.w d1
			beq kw_rs_e
			cmp.w d1, d2
			bcs kw_rs_pad
			subq.w #1, d1
kw_rs_cp:
			move.b (a0)+, (a1)+
			dbra d1, kw_rs_cp
kw_rs_e:
			rts
kw_rs_pad:
			move.w d1, d3
			sub.w d2, d3
			subq.w #1, d3
kw_rs_p:
			move.b #' ', (a1)+
			dbra d3, kw_rs_p
			tst.w d2
			beq kw_rs_e
			move.w d2, d1
			subq.w #1, d1
			bra kw_rs_cp

;## kw_strfix
;kw_strfix, <var>, <n>  - String * n after a change: pad with spaces / cut to n
kw_strfix:
			movea.l (sp)+, a0
			move.l (sp)+, d1
			andi.w #$FF, d1
			beq kw_sf_end
			subq.w #1, d1
kw_sf_len:
			tst.b (a0)
			beq kw_sf_pad
			addq.l #1, a0
			dbra d1, kw_sf_len
			clr.b (a0)
			rts
kw_sf_pad:
			move.b #' ', (a0)+
			dbra d1, kw_sf_pad
kw_sf_end:
			clr.b (a0)
			rts

;## ntc_fmt ntc_data
; Format$ with a number pattern. ntc_fmbuf holds "-123"; the thread has
; <mindigits>, <group>, <prefix>, <suffix>. a1 = the dest. rts (thread)
ntc_fm_common:
			move.l (sp)+, d4			; mindigits
			move.l (sp)+, d5			; group
			movea.l (sp)+, a2			; prefix
			movea.l (sp)+, a3			; suffix
			lea ntc_fmbuf, a0
			cmpi.b #'-', (a0)
			bne ntc_fm_pos
			move.b (a0)+, (a1)+
ntc_fm_pos:
ntc_fm_pre:
			move.b (a2)+, d0
			beq ntc_fm_cnt
			move.b d0, (a1)+
			bra ntc_fm_pre
ntc_fm_cnt:
			movea.l a0, a2				; the digits
			moveq #0, d1
ntc_fm_c1:
			tst.b (a2)+
			beq ntc_fm_c2
			addq.w #1, d1
			bra ntc_fm_c1
ntc_fm_c2:
			moveq #0, d2				; zeros in front
			andi.w #$FF, d4
			cmp.w d1, d4
			bls ntc_fm_c3
			move.w d4, d2
			sub.w d1, d2
ntc_fm_c3:
			move.w d1, d6
			add.w d2, d6				; digits to write
			move.w d6, d7
ntc_fm_mod:
			cmpi.w #4, d7
			bcs ntc_fm_out
			subq.w #3, d7
			bra ntc_fm_mod			; d7 = digits before the first comma
ntc_fm_out:
			tst.w d6
			beq ntc_fm_suf
			tst.w d2
			beq ntc_fm_d
			subq.w #1, d2
			move.b #'0', (a1)+
			bra ntc_fm_nx
ntc_fm_d:
			move.b (a0)+, (a1)+
ntc_fm_nx:
			subq.w #1, d6
			subq.w #1, d7
			bne ntc_fm_out
			moveq #3, d7
			tst.w d6
			beq ntc_fm_suf
			tst.w d5
			beq ntc_fm_out
			move.b #',', (a1)+
			bra ntc_fm_out
ntc_fm_suf:
			move.b (a3)+, (a1)+
			bne ntc_fm_suf
			rts
;@ram
ntc_fmbuf:	ds.b 16
;@rom

;## kw_strfmt ntc_fmt ntc_itoa
;kw_strfmt, <dest>, <var>, <mindigits>, <group>, <prefix>, <suffix>  - Format$(n, "0,000")
kw_strfmt:
			movea.l (sp)+, a4			; dest
			movea.l (sp)+, a0
			move.w (a0), d0
			lea ntc_fmbuf, a1
			lea kw_sfm_b, a6
			bra ntc_itoa
kw_sfm_b:
			movea.l a4, a1
			bra ntc_fm_common

;## kw_l_strfmt ntc_fmt ntc_ltoa
;kw_l_strfmt, <dest>, <long>, <mindigits>, <group>, <prefix>, <suffix>  - Format$ of a Long
kw_l_strfmt:
			movea.l (sp)+, a4
			movea.l (sp)+, a0
			move.l (a0), d0
			lea ntc_fmbuf, a1
			lea kw_lsfm_b, a6
			bra ntc_ltoa
kw_lsfm_b:
			movea.l a4, a1
			bra ntc_fm_common

;## kw_strjoin
;kw_strjoin, <dest>, <descriptor>, <sep>  - Join(stringarray, sep), NTC_STRMAX characters at most
kw_strjoin:
			movea.l (sp)+, a4			; dest
			movea.l (sp)+, a0			; descriptor
			movea.w (a0), a2			; base (RAM)
			move.w 6(a0), d3			; count
			move.w 10(a0), d5			; element size
			movea.l (sp)+, a3			; sep
			lea ntc_jnbuf, a1
			move.w #NTC_STRMAX, d4
			tst.w d3
			beq kw_jn_done
kw_jn_el:
			movea.l a2, a0
kw_jn_c1:
			move.b (a0)+, d0
			beq kw_jn_eend
			tst.w d4
			beq kw_jn_done
			move.b d0, (a1)+
			subq.w #1, d4
			bra kw_jn_c1
kw_jn_eend:
			adda.w d5, a2
			subq.w #1, d3
			beq kw_jn_done
			movea.l a3, a0
kw_jn_c2:
			move.b (a0)+, d0
			beq kw_jn_el
			tst.w d4
			beq kw_jn_done
			move.b d0, (a1)+
			subq.w #1, d4
			bra kw_jn_c2
kw_jn_done:
			clr.b (a1)
			lea ntc_jnbuf, a0
kw_jn_out:
			move.b (a0)+, (a4)+
			bne kw_jn_out
			rts
;@ram
ntc_jnbuf:	ds.b NTC_STRMAX+1
			even
;@rom

;## kw_strsplit
;kw_strsplit, <descriptor>, <base>, <capacity>, <text>, <sep>, <element size>  - a() = Split(text, sep)
kw_strsplit:
			movea.l (sp)+, a4			; descriptor
			move.l (sp)+, d6			; base
			move.l (sp)+, d3			; capacity (elements)
			movea.l (sp)+, a2			; text
			movea.l (sp)+, a3			; sep
			move.l (sp)+, d5			; element size
			movea.l d6, a5				; the element being filled
			moveq #0, d7				; count
			tst.b (a2)
			beq kw_sp_fin
kw_sp_elem:
			cmp.w d3, d7
			bcc kw_sp_fin
			addq.w #1, d7
			movea.l a5, a1
			move.w d5, d4
			subq.w #1, d4				; room in the element
kw_sp_ch:
			tst.b (a2)
			beq kw_sp_last
			tst.b (a3)
			beq kw_sp_nosep
			movea.l a2, a0
			movea.l a3, a6
kw_sp_m:
			move.b (a6)+, d0
			beq kw_sp_hit
			cmp.b (a0)+, d0
			beq kw_sp_m
kw_sp_nosep:
			move.b (a2)+, d0
			tst.w d4
			beq kw_sp_ch
			move.b d0, (a1)+
			subq.w #1, d4
			bra kw_sp_ch
kw_sp_hit:
			movea.l a0, a2
			clr.b (a1)
			adda.w d5, a5
			bra kw_sp_elem
kw_sp_last:
			clr.b (a1)
kw_sp_fin:
			move.w d6, (a4)
			clr.w 2(a4)
			clr.w 4(a4)
			move.w d7, 6(a4)
			move.w #1, 8(a4)
			move.w d5, 10(a4)
			rts

;## kw_strmidset
;kw_strmidset, <textvar>, <startvar>, <lenvar>, <src>  - Mid$(s, start, len) = src
kw_strmidset:
			movea.l (sp)+, a1			; text
			movea.l (sp)+, a0
			move.w (a0), d0				; start
			movea.l (sp)+, a0
			move.w (a0), d1				; len
			movea.l (sp)+, a2			; src
			tst.w d0
			ble kw_ms_e
			cmpi.w #255, d0
			bhi kw_ms_e
			subq.w #1, d0
			beq kw_ms_at
kw_ms_adv:
			tst.b (a1)
			beq kw_ms_e
			addq.l #1, a1
			subq.w #1, d0
			bne kw_ms_adv
kw_ms_at:
			cmpi.w #255, d1
			bls kw_ms_len
			move.w #255, d1
kw_ms_len:
			tst.w d1
			beq kw_ms_e
			subq.w #1, d1
kw_ms_cp:
			tst.b (a1)
			beq kw_ms_e
			move.b (a2)+, d0
			beq kw_ms_e
			move.b d0, (a1)+
			dbra d1, kw_ms_cp
kw_ms_e:
			rts

;## kw_strmid ntc_getn kw_strleft
;kw_strmid, <dest>, <src>, <startvar>, <lenvar>  - Mid$(src, start, len)
kw_strmid:
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			movea.l (sp)+, a0
			lea kw_sm_s, a6
			bra ntc_getn
kw_sm_s:
			tst.w d0
			beq kw_sm_s1
			subq.w #1, d0
kw_sm_s1:
			tst.w d0
			beq kw_sm_len
			tst.b (a2)
			beq kw_sm_len
			addq.l #1, a2
			subq.w #1, d0
			bra kw_sm_s1
kw_sm_len:
			movea.l (sp)+, a0
			lea kw_sm_n, a6
			bra ntc_getn
kw_sm_n:
			movea.l a2, a0
			bra ntc_strncpy

;## kw_strchr
;kw_strchr, <dest>, <nvar>  - Chr$(n)
kw_strchr:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.b 1(a0), (a1)+
			clr.b (a1)
			rts

;## kw_strcstr ntc_itoa
;kw_strcstr, <dest>, <nvar>  - number to text (CStr, "x" & n)
kw_strcstr:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.w (a0), d0
			lea ntc_next, a6
			bra ntc_itoa

;## kw_strstr ntc_itoa
;kw_strstr, <dest>, <nvar>  - Str$(n): a space before 0 and positives
kw_strstr:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.w (a0), d0
			bmi kw_st_go
			move.b #' ', (a1)+
kw_st_go:
			lea ntc_next, a6
			bra ntc_itoa

;## kw_strhex
;kw_strhex, <dest>, <nvar>  - Hex$(n), no leading zeros
kw_strhex:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.w (a0), d0
			moveq #3, d1				; 4 digits
			moveq #0, d3				; seen
kw_hx_lp:
			rol.w #4, d0
			move.w d0, d2
			andi.w #$F, d2
			bne kw_hx_out
			tst.w d3
			bne kw_hx_out
			tst.w d1
			bne kw_hx_next
kw_hx_out:
			moveq #1, d3
			addi.b #'0', d2
			cmpi.b #'9'+1, d2
			bcs kw_hx_put
			addq.b #7, d2
kw_hx_put:
			move.b d2, (a1)+
kw_hx_next:
			dbra d1, kw_hx_lp
			clr.b (a1)
			rts

;## kw_strspace ntc_getn
;kw_strspace, <dest>, <nvar>  - Space$(n)
kw_strspace:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			lea kw_sps_n, a6
			bra ntc_getn
kw_sps_n:
			moveq #' ', d1
; d0.w = count (NTC_STRMAX at most), d1.b = char, a1 = dest. rts
ntc_strfill:
			cmpi.w #NTC_STRMAX, d0
			bls ntc_sf_ok
			move.w #NTC_STRMAX, d0
ntc_sf_ok:
			subq.w #1, d0
			bmi ntc_sf_end
ntc_sf_lp:
			move.b d1, (a1)+
			dbra d0, ntc_sf_lp
ntc_sf_end:
			clr.b (a1)
			rts

;## kw_strstring kw_strspace
;kw_strstring, <dest>, <nvar>, <charvar>  - String$(n, char code)
kw_strstring:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			lea kw_ss_n, a6
			bra ntc_getn
kw_ss_n:
			movea.l (sp)+, a0
			move.b 1(a0), d1
			bra ntc_strfill

;## kw_strucase
;kw_strucase, <dest>, <src>  - UCase$
kw_strucase:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
kw_uc_lp:
			move.b (a0)+, d0
			cmpi.b #'a', d0
			bcs kw_uc_put
			cmpi.b #'z', d0
			bhi kw_uc_put
			subi.b #32, d0
kw_uc_put:
			move.b d0, (a1)+
			bne kw_uc_lp
			rts

;## kw_strlcase
;kw_strlcase, <dest>, <src>  - LCase$
kw_strlcase:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
kw_lc_lp:
			move.b (a0)+, d0
			cmpi.b #'A', d0
			bcs kw_lc_put
			cmpi.b #'Z', d0
			bhi kw_lc_put
			addi.b #32, d0
kw_lc_put:
			move.b d0, (a1)+
			bne kw_lc_lp
			rts

;## kw_strltrim kw_strleft
;kw_strltrim, <dest>, <src>  - LTrim$
kw_strltrim:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
kw_lt_skip:
			cmpi.b #' ', (a0)
			bne kw_lt_copy
			addq.l #1, a0
			bra kw_lt_skip
kw_lt_copy:
			move.w #255, d0
			bra ntc_strncpy

;## kw_strrtrim
;kw_strrtrim, <dest>, <src>  - RTrim$
kw_strrtrim:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
ntc_rt_go:
			movea.l a1, a2				; the start
ntc_rt_copy:
			move.b (a0)+, (a1)+
			bne ntc_rt_copy
			subq.l #1, a1				; on the 0
ntc_rt_lp:
			cmpa.l a2, a1
			beq ntc_rt_e
			cmpi.b #' ', -1(a1)
			bne ntc_rt_e
			subq.l #1, a1
			clr.b (a1)
			bra ntc_rt_lp
ntc_rt_e:
			rts

;## kw_strtrim kw_strrtrim
;kw_strtrim, <dest>, <src>  - Trim$
kw_strtrim:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
kw_tr_skip:
			cmpi.b #' ', (a0)
			bne ntc_rt_go
			addq.l #1, a0
			bra kw_tr_skip

;## kw_strasc
;kw_strasc, <src>, <destvar>  - Asc(src), 0 if empty
kw_strasc:
			movea.l (sp)+, a0
			moveq #0, d0
			move.b (a0), d0
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## kw_strval ntc_atoi
;kw_strval, <src>, <destvar>  - Val(src): decimal or &H hex
kw_strval:
			movea.l (sp)+, a0
			move.l (sp)+, ntc_ivar
			bra ntc_atoi

;## kw_strinstr ntc_getn
;kw_strinstr, <startvar>, <s1>, <s2>, <destvar>  - InStr(start, s1, s2)
kw_strinstr:
			movea.l (sp)+, a0
			lea kw_in_s, a6
			bra ntc_getn
kw_in_s:
			tst.w d0
			bne kw_in_s1
			moveq #1, d0
kw_in_s1:
			movea.l (sp)+, a2			; s1
			movea.l (sp)+, a3			; s2
			move.w d0, d1
kw_in_adv:
			subq.w #1, d1
			beq kw_in_try
			tst.b (a2)+
			bne kw_in_adv
			bra kw_in_nf
kw_in_try:
			movea.l a2, a0
			movea.l a3, a1
kw_in_cmp:
			move.b (a1)+, d2
			beq kw_in_found
			cmp.b (a0)+, d2
			beq kw_in_cmp
			tst.b (a2)+
			beq kw_in_nf
			addq.w #1, d0
			bra kw_in_try
kw_in_nf:
			moveq #0, d0
kw_in_found:
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## ntc_strcmp
; a0 = a, a1 = b: compare, jmp (a6) with Z = equal, C = a < b (unsigned bytes)
ntc_strcmp:
			move.b (a0)+, d0
			cmp.b (a1)+, d0
			bne ntc_scm_e
			tst.b d0
			bne ntc_strcmp
ntc_scm_e:
			jmp (a6)

;## kw_strcmplt ntc_strcmp
;kw_strcmplt, <a>, <b>  - Z if a < b
kw_strcmplt:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			lea kw_sclt, a6
			bra ntc_strcmp
kw_sclt:
			scs d0
			addq.b #1, d0
			rts

;## kw_strcmple ntc_strcmp
kw_strcmple:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			lea kw_scle, a6
			bra ntc_strcmp
kw_scle:
			sls d0
			addq.b #1, d0
			rts

;## kw_strcmpgt ntc_strcmp
kw_strcmpgt:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			lea kw_scgt, a6
			bra ntc_strcmp
kw_scgt:
			shi d0
			addq.b #1, d0
			rts

;## kw_strcmpge ntc_strcmp
kw_strcmpge:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			lea kw_scge, a6
			bra ntc_strcmp
kw_scge:
			scc d0
			addq.b #1, d0
			rts

; ============================================================
; String arrays (element size = capacity + 1 bytes, no capacity byte)
; ============================================================

;## kw_sget
;kw_sget, <arraybase>, <indexvar>, <dest>, <element size>  - dest = array(index)
kw_sget:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			movea.l (sp)+, a1			; dest
			move.l (sp)+, d1			; size
			mulu.w d1, d0
			adda.l d0, a0
			subq.w #1, d1
kw_sg_lp:
			move.b (a0)+, (a1)+
			dbra d1, kw_sg_lp
			rts

;## kw_sset kw_strcpy
;kw_sset, <arraybase>, <indexvar>, <src>, <element size>  - array(index) = src, cut at the element
kw_sset:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.w (a0), d0
			movea.l (sp)+, a0			; src
			move.l (sp)+, d1			; size
			andi.l #$FFFF, d1
			mulu.w d1, d0
			adda.l d0, a1
			subq.w #1, d1				; capacity
			bra ntc_strcpy_lp

; ============================================================
; Array parameters and dynamic arrays. A procedure gets the address of a
; 12 byte descriptor: dc.w base (RAM, 16 bits), lower bound 1, lower bound 2,
; count 1, count 2, element size.
; ============================================================

;## ntc_paddr
; a0 = descriptor, a1 = index var: a0 = element address, d1 = element size. jmp (a6)
ntc_paddr:
			move.w (a1), d0
			sub.w 2(a0), d0				; element number
ntc_pa_tail:					; d0.w = element number, a0 = descriptor
			move.w 10(a0), d1
			movea.w (a0), a0
			muls.w d1, d0
			adda.l d0, a0
			jmp (a6)

;## ntc_paddr2 ntc_paddr
; a0 = descriptor, a1 / a2 = the 2 index vars: a0 = element address, d1 = size. jmp (a6)
ntc_paddr2:
			move.w (a1), d0
			sub.w 2(a0), d0
			muls.w 8(a0), d0			; (i - lo1) * count 2
			move.w (a2), d1
			sub.w 4(a0), d1
			add.w d1, d0
			bra ntc_pa_tail

;## kw_pget ntc_paddr
;kw_pget, <descriptor>, <indexvar>, <dest>  - dest = parameter array(index)
kw_pget:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			lea kw_pg_a, a6
			bra ntc_paddr
kw_pg_a:
			movea.l (sp)+, a1
			cmpi.w #1, d1				; a Byte element: into the Integer's low byte
			bne kw_pg_n1
			clr.b (a1)+
kw_pg_n1:
			subq.w #1, d1
kw_pg_lp:
			move.b (a0)+, (a1)+
			dbra d1, kw_pg_lp
			rts

;## kw_pset ntc_paddr
;kw_pset, <descriptor>, <indexvar>, <src>  - parameter array(index) = src
kw_pset:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			lea kw_ps_a, a6
			bra ntc_paddr
kw_ps_a:
			movea.l (sp)+, a1
			cmpi.w #1, d1				; a Byte element: from the Integer's low byte
			bne kw_ps_n1
			addq.l #1, a1
kw_ps_n1:
			subq.w #1, d1
kw_ps_lp:
			move.b (a1)+, (a0)+
			dbra d1, kw_ps_lp
			rts

;## kw_psets ntc_paddr kw_strcpy
;kw_psets, <descriptor>, <indexvar>, <src>  - String parameter array(index) = src
kw_psets:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			lea kw_pss_a, a6
			bra ntc_paddr
kw_pss_a:
			movea.l a0, a1
			movea.l (sp)+, a0
			subq.w #1, d1
			bra ntc_strcpy_lp

;## kw_psets2 ntc_paddr2 kw_psets
;kw_psets2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src (String)
kw_psets2:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			lea kw_pss_a, a6
			bra ntc_paddr2

;## kw_pget2 ntc_paddr2 kw_pget
;kw_pget2, <descriptor>, <index1var>, <index2var>, <dest>  - dest = array(i, j)
kw_pget2:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			lea kw_pg_a, a6
			bra ntc_paddr2

;## kw_pset2 ntc_paddr2 kw_pset
;kw_pset2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src
kw_pset2:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			movea.l (sp)+, a2
			lea kw_ps_a, a6
			bra ntc_paddr2

;## kw_lbound
;kw_lbound, <descriptor + 2 * (dimension - 1)>, <dest>  - LBound
kw_lbound:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w 2(a0), (a1)
			rts

;## kw_ubound
;kw_ubound, <descriptor + 2 * (dimension - 1)>, <dest>  - UBound = lower bound + count - 1
kw_ubound:
			movea.l (sp)+, a0
			move.w 2(a0), d0
			add.w 6(a0), d0
			subq.w #1, d0
			movea.l (sp)+, a1
			move.w d0, (a1)
			rts

; ============================================================
; Long (32 bit signed): a 68000 long. Every argument is an address
; (a literal is a dc.l in the ROM).
; ============================================================

;## kw_l_mov
kw_l_mov:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), (a1)
			rts

;## kw_l_itol
;kw_l_itol, <intvar>, <dest>  - Integer to Long (sign extended)
kw_l_itol:
			movea.l (sp)+, a0
			move.w (a0), d0
			ext.l d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_ltoi
;kw_l_ltoi, <long>, <intdest>  - Long to Integer (low 16 bits)
kw_l_ltoi:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w 2(a0), (a1)
			rts

;## kw_l_add
kw_l_add:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			add.l (a1), d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_sub
kw_l_sub:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			sub.l (a1), d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_and
kw_l_and:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			and.l (a1), d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_or
kw_l_or:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			or.l (a1), d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_xor
kw_l_xor:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			eor.l d1, d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_not
kw_l_not:
			movea.l (sp)+, a0
			move.l (a0), d0
			not.l d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_neg
kw_l_neg:
			movea.l (sp)+, a0
			move.l (a0), d0
			neg.l d0
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_abs
kw_l_abs:
			movea.l (sp)+, a0
			move.l (a0), d0
			bpl kw_la_st
			neg.l d0
kw_la_st:
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_sgn
;kw_l_sgn, <a>, <intdest>  - -1, 0 or 1
kw_l_sgn:
			movea.l (sp)+, a0
			moveq #0, d0
			move.l (a0), d1
			beq kw_lsg_st
			moveq #1, d0
			tst.l d1
			bpl kw_lsg_st
			moveq #-1, d0
kw_lsg_st:
			movea.l (sp)+, a0
			move.w d0, (a0)
			rts

;## ntc_lcmp
; tails: d0 = a (long), d1 = b: Z if a <rel> b
ntc_lcmp_lt:
			cmp.l d1, d0
			slt d0
			addq.b #1, d0
			rts
ntc_lcmp_le:
			cmp.l d1, d0
			sle d0
			addq.b #1, d0
			rts
ntc_lcmp_gt:
			cmp.l d1, d0
			sgt d0
			addq.b #1, d0
			rts
ntc_lcmp_ge:
			cmp.l d1, d0
			sge d0
			addq.b #1, d0
			rts
ntc_lcmp_ne:
			cmp.l d1, d0
			sne d0
			addq.b #1, d0
			rts

;## kw_l_cplt ntc_lcmp
kw_l_cplt:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			bra ntc_lcmp_lt

;## kw_l_cple ntc_lcmp
kw_l_cple:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			bra ntc_lcmp_le

;## kw_l_cpgt ntc_lcmp
kw_l_cpgt:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			bra ntc_lcmp_gt

;## kw_l_cpge ntc_lcmp
kw_l_cpge:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			bra ntc_lcmp_ge

;## kw_l_cpeq
kw_l_cpeq:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			cmp.l (a1), d0
			rts

;## kw_l_cpne ntc_lcmp
kw_l_cpne:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			bra ntc_lcmp_ne

;## ntc_lmul
; d0.l * d1.l -> d0.l (low 32 bits). jmp (a6). Uses d2, d3
ntc_lmul:
			move.l d0, d2
			move.l d1, d3
			swap d2
			swap d3
			mulu.w d1, d2				; a_hi * b_lo
			mulu.w d0, d3				; a_lo * b_hi
			add.w d3, d2
			swap d2
			clr.w d2
			mulu.w d1, d0				; a_lo * b_lo
			add.l d2, d0
			jmp (a6)

;## ntc_ldiv
; d0.l / d1.l signed, truncating: d0 = quotient, d1 = remainder (the dividend's
; sign). Divide by 0: quotient 0, remainder = dividend. jmp (a6). Uses d2-d5
ntc_ldiv:
			tst.l d1
			bne ntc_ld_nz
			move.l d0, d1
			moveq #0, d0
			jmp (a6)
ntc_ld_nz:
			move.l d0, d4				; the dividend's sign
			move.l d0, d5
			eor.l d1, d5				; the quotient's sign
			tst.l d0
			bpl ntc_ld_ap
			neg.l d0
ntc_ld_ap:
			tst.l d1
			bpl ntc_ld_bp
			neg.l d1
ntc_ld_bp:
			moveq #0, d2				; remainder
			moveq #31, d3
ntc_ld_lp:
			add.l d0, d0
			addx.l d2, d2
			cmp.l d1, d2
			bcs ntc_ld_no
			sub.l d1, d2
			addq.l #1, d0
ntc_ld_no:
			dbra d3, ntc_ld_lp
			tst.l d5
			bpl ntc_ld_qp
			neg.l d0
ntc_ld_qp:
			move.l d2, d1
			tst.l d4
			bpl ntc_ld_rp
			neg.l d1
ntc_ld_rp:
			jmp (a6)

;## kw_l_mul ntc_lmul
kw_l_mul:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			lea kw_lmu_b, a6
			bra ntc_lmul
kw_lmu_b:
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## kw_l_div ntc_ldiv kw_l_mul
kw_l_div:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			lea kw_lmu_b, a6
			bra ntc_ldiv

;## kw_l_mod ntc_ldiv
kw_l_mod:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.l (a0), d0
			move.l (a1), d1
			lea kw_lmd_b, a6
			bra ntc_ldiv
kw_lmd_b:
			movea.l (sp)+, a0
			move.l d1, (a0)
			rts

;## kw_l_pow ntc_lmul
;kw_l_pow, <base>, <exp>, <dest>  - Long ^ (low 32 bits; exp < 0 gives 0)
kw_l_pow:
			movea.l (sp)+, a0
			move.l (a0), d6				; base
			movea.l (sp)+, a0
			move.l (a0), d7				; exp
			moveq #1, d0
			tst.l d7
			bpl kw_lpw_lp
			moveq #0, d0
			bra kw_lpw_st
kw_lpw_lp:
			tst.l d7
			beq kw_lpw_st
			move.l d6, d1
			lea kw_lpw_b, a6
			bra ntc_lmul
kw_lpw_b:
			subq.l #1, d7
			bra kw_lpw_lp
kw_lpw_st:
			movea.l (sp)+, a0
			move.l d0, (a0)
			rts

;## ntc_ltoa ntc_data
; the Long d0 to text at a1, a 0 at the end (a1 on it). jmp (a6). Uses d0-d3, a0
ntc_ltoa:
			tst.l d0
			bpl ntc_lta_pos
			move.b #'-', (a1)+
			neg.l d0
ntc_lta_pos:
			lea ntc_lta_tmp+12, a0
			clr.b -(a0)
ntc_lta_lp:
			; d0 unsigned / 10: high word first
			move.l d0, d2
			clr.w d2
			swap d2
			divu.w #10, d2				; d2 = rem:quot of the high word
			move.w d2, d3				; the quotient's high word
			move.w d0, d2				; rem (high) : low word
			divu.w #10, d2
			swap d3
			move.w d2, d3				; d3 = the quotient
			swap d2
			addi.b #'0', d2
			move.b d2, -(a0)
			move.l d3, d0
			bne ntc_lta_lp
ntc_lta_cp:
			move.b (a0)+, (a1)+
			bne ntc_lta_cp
			subq.l #1, a1
			jmp (a6)
;@ram
ntc_lta_tmp:	ds.b 12
;@rom

;## kw_l_print ntc_ltoa ntc_printbuf
kw_l_print:
			movea.l (sp)+, a0
			move.l (a0), d0
			lea ntc_numbuf, a1
			lea kw_lpr_b, a6
			bra ntc_ltoa
kw_lpr_b:
			lea ntc_numbuf, a0
			bra ntc_printbuf

;## kw_l_printvb ntc_ltoa ntc_printbuf
kw_l_printvb:
			movea.l (sp)+, a0
			move.l (a0), d0
			lea ntc_numbuf, a1
			tst.l d0
			bmi kw_lpv_neg
			move.b #' ', (a1)+
kw_lpv_neg:
			lea kw_lpv_b, a6
			bra ntc_ltoa
kw_lpv_b:
			move.b #' ', (a1)+
			clr.b (a1)
			lea ntc_numbuf, a0
			bra ntc_printbuf

;## kw_l_cstr ntc_ltoa
kw_l_cstr:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.l (a0), d0
			lea ntc_next, a6
			bra ntc_ltoa

;## kw_l_str ntc_ltoa
kw_l_str:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.l (a0), d0
			bmi kw_lst_go
			move.b #' ', (a1)+
kw_lst_go:
			lea ntc_next, a6
			bra ntc_ltoa

;## kw_l_hex
;kw_l_hex, <dest>, <long>  - Hex$(Long): upper case, no leading zeros
kw_l_hex:
			movea.l (sp)+, a1
			movea.l (sp)+, a0
			move.l (a0), d0
			moveq #7, d1
			moveq #0, d3
kw_lhx_lp:
			rol.l #4, d0
			move.w d0, d2
			andi.w #$F, d2
			bne kw_lhx_out
			tst.w d3
			bne kw_lhx_out
			tst.w d1
			bne kw_lhx_next
kw_lhx_out:
			moveq #1, d3
			addi.b #'0', d2
			cmpi.b #'9'+1, d2
			bcs kw_lhx_put
			addq.b #7, d2
kw_lhx_put:
			move.b d2, (a1)+
kw_lhx_next:
			dbra d1, kw_lhx_lp
			clr.b (a1)
			rts

;## kw_l_val
;kw_l_val, <src>, <destlong>  - Val() to a Long (decimal)
kw_l_val:
			movea.l (sp)+, a0
			movea.l (sp)+, a2
ntc_lv_go:
			moveq #0, d0
			moveq #0, d2
ntc_lv_sp:
			cmpi.b #' ', (a0)
			bne ntc_lv_sg
			addq.l #1, a0
			bra ntc_lv_sp
ntc_lv_sg:
			cmpi.b #'-', (a0)
			bne ntc_lv_dig
			moveq #1, d2
			addq.l #1, a0
ntc_lv_dig:
			moveq #0, d1
			move.b (a0)+, d1
			subi.b #'0', d1
			bcs ntc_lv_done
			cmpi.b #10, d1
			bcc ntc_lv_done
			move.l d0, d3
			add.l d0, d0
			add.l d0, d0
			add.l d3, d0
			add.l d0, d0				; * 10
			add.l d1, d0
			bra ntc_lv_dig
ntc_lv_done:
			tst.w d2
			beq ntc_lv_st
			neg.l d0
ntc_lv_st:
			move.l d0, (a2)
			rts

;## kw_l_input ntc_gets kw_l_val ntc_d_inbuf
;kw_l_input, <destlong>  - Input to a Long
kw_l_input:
			move.l (sp)+, ntc_ivar
			lea ntc_inbuf, a2
			NTC_RS
			jsr ntc_gets
			NTC_TS
			lea ntc_inbuf, a0
			movea.l ntc_ivar, a2
			bra ntc_lv_go

;## kw_l_aget
;kw_l_aget, <arraybase>, <indexvar>, <dest>  - Long array element
kw_l_aget:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			ext.l d0
			lsl.l #2, d0
			movea.l (sp)+, a1
			move.l 0(a0, d0.l), (a1)
			rts

;## kw_l_aset
;kw_l_aset, <arraybase>, <indexvar>, <src>  - set a Long array element
kw_l_aset:
			movea.l (sp)+, a0
			movea.l (sp)+, a1
			move.w (a1), d0
			ext.l d0
			lsl.l #2, d0
			movea.l (sp)+, a1
			move.l (a1), 0(a0, d0.l)
			rts

;## kw_bssinit ntc_data ntc_plat_screen
;kw_bssinit, <start>, <size>  - the start of the main thread: the program's arrays live after
;  the RAM variables (not in the ROM). Check they fit under the end of RAM, then clear them.
;  Too big: a message, the program stops.
kw_bssinit:
			movea.l (sp)+, a0
			move.l (sp)+, d0
			andi.l #$FFFF, d0
			move.l a0, d1
			add.l d0, d1
			cmpi.l #$01000000, d1
			bhi kw_bs_big
			tst.l d0
			beq kw_bs_e
kw_bs_lp:
			clr.b (a0)+
			subq.l #1, d0
			bne kw_bs_lp
kw_bs_e:
			rts
kw_bs_big:
			NTC_RS
			lea kw_bs_txt, a2
kw_bs_pl:
			moveq #0, d0
			move.b (a2)+, d0
			beq kw_bs_stop
			jsr ntc_plat_putc
			bra kw_bs_pl
kw_bs_stop:
			jsr ntc_plat_newline
			jmp kw_stop
kw_bs_txt:	dc.b "Not enough memory for the arrays", 0
			even

;## ntc_capfind ntc_data
; ntc_capfind - the body of a class's Capability(name) keyword. a0 = the name asked for
;   (0 ended), a1 = the result's address, a2 = the class's table: name (capitals, 0
;   ended, then even), dc.w value, ..., dc.b 0. Matched without regard to case. Found:
;   the value, Z set (true). Not found: 0, NZ. Ends the keyword (rts).
ntc_capfind:
ntc_cf_entry:
			tst.b (a2)
			beq ntc_cf_none
			movea.l a0, a3
			movea.l a2, a4
ntc_cf_cmp:
			move.b (a3)+, d0
			cmpi.b #'a', d0
			bcs ntc_cf_up
			cmpi.b #'z', d0
			bhi ntc_cf_up
			subi.b #32, d0
ntc_cf_up:
			move.b (a4)+, d1
			cmp.b d1, d0
			bne ntc_cf_next
			tst.b d0
			bne ntc_cf_cmp
			move.l a4, d0				; matched: the value after the name (even)
			addq.l #1, d0
			andi.b #$FE, d0
			movea.l d0, a4
			move.w (a4), (a1)
			cmp.w d0, d0				; Z
			rts
ntc_cf_next:
			tst.b -1(a4)				; to the end of this name
			beq ntc_cf_skip
ntc_cf_to0:
			tst.b (a4)+
			bne ntc_cf_to0
ntc_cf_skip:
			move.l a4, d0
			addq.l #1, d0
			andi.b #$FE, d0
			movea.l d0, a2
			addq.l #2, a2				; past the value
			bra ntc_cf_entry
ntc_cf_none:
			clr.w (a1)
			moveq #1, d0				; NZ
			rts

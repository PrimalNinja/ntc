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
; TWO MODES (turbo and normal)
;   Turbo  = the rules above: SP is the thread, interrupts off.
;   Normal = the same, but interrupts get in at safe points: every
;   branch (GOTO, loop end, GOSUB / RETURN, procedure call / end),
;   and kw_irq, which the compiler puts in every 32 keywords of a
;   run with no branch. SP is the thread in both modes.
;   A branch keyword (a section that loads SP, or jumps into one)
;   gets a second copy for normal mode, named with _n on the end,
;   made from the same source text:
;     ret        -> jp ntc_xn
;     ret cc     -> jp cc, ntc_xn
;     ntc_next   -> ntc_xn
;     labels of those sections get _n
;   ntc_xn saves SP (the thread position) in ntc_ip, goes back to the
;   real stack (ntc_csp), lets an interrupt in, then carries on with
;   SP back in the thread and interrupts off. Flags are kept, so a
;   compare can be followed by a branch.
;   All other keywords are one copy, used by both modes.
;   "@shared" after the deps keeps a section as it is in both modes
;   (its SP load or ret is real, not a branch).
;   Turbo On  (normal mode) = kw_turbo_on:  ret - carries on in turbo.
;   Turbo Off (turbo mode)  = kw_turbo_off: jp ntc_xn - now normal.
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
;   A platform file supplies ntc_plat_* sections:
;     ntc_plat_data     ntc_curx, ntc_cury, ntc_scols (and its own data)
;     ntc_plat_screen   ntc_plat_putc (A = char 32-126), ntc_plat_newline,
;                       ntc_plat_backspace, ntc_plat_cls, ntc_plat_mode (A),
;                       ntc_plat_locate (H = column, L = row, 1 based);
;                       glyph platforms also ntc_plat_putglyph (DE = glyph)
;     ntc_plat_key      ntc_plat_scankey (A = key or 0), ntc_plat_getkey (wait)
;     ntc_plat_frame    ntc_plat_frame
;     ntc_plat_ticks    ntc_plat_ticks (HL = tick count)
;     ntc_plat_exit     ntc_plat_exit (before returning to the caller)
;     ntc_plat_irq      ntc_plat_irqon (only platforms with their own handler)
;   All are entered with jp, return address in IX, end with jp (ix).
; ============================================================

;## ntc_data @shared ntc_d_nmode
; ------------------------------------------------------------
; Scratch space: the core every program has (with ntc_d_nmode). The rest of
; the run time's variables are @data sections, each linked only when a
; linked section's code names one of its labels (no header lists them).
; They stay in this order: the keyword ROM's registry keeps each variable's
; address (a Library: ROM program has them as fixed addresses)
; ------------------------------------------------------------
ntc_next:		ret				; IX target that continues the thread
ntc_csp:		dw 0			; caller SP, for kw_stop (and the normal mode stack)
ntc_ip:			dw 0			; normal mode: thread position while out of the thread

;## ntc_d_ticks @data
ntc_ticks:		dw 0			; interrupt count (normal mode, platform handler)

;## ntc_d_gnlo @data
ntc_gnlo:		db 0			; ntc_getn: low byte

;## ntc_d_nmode @data
ntc_nmode:		db 0			; 1 = running in normal mode (waits let interrupts in)

;## ntc_d_div @data
ntc_mode:		db 0			; div mode 0=quotient 1=remainder
ntc_sgnq:		db 0			; quotient sign (bit 7)
ntc_sgnr:		db 0			; remainder sign (bit 7)

;## ntc_d_lead @data
ntc_lead:		db 0			; printint: digit seen

;## ntc_d_icnt @data
ntc_icnt:		db 0			; gets: chars typed
ntc_icap:		db 0			; gets: the buffer's capacity

;## ntc_d_sptr @data
ntc_sptr:		dw 0			; printbuf: text pointer

;## ntc_d_iptr @data
ntc_iptr:		dw 0			; gets: buffer pointer
ntc_ilink:		dw 0			; gets: where to go when done

;## ntc_d_ivar @data
ntc_ivar:		dw 0			; inputint / inkey: dest var

;## ntc_d_aptr @data
ntc_aptr:		dw 0			; atoi: text pointer

;## ntc_d_hook @data
ntc_hookon:		db 0			; 1 = the Interrupt hook may run (set, and not running now)
ntc_hookset:	db 0			; 1 = an Interrupt hook is set
ntc_hookpend:	db 0			; 1 = an interrupt came, the hook runs at the next safe point
ntc_hook:		dw 0			; the hook Sub's call stub

;## ntc_d_hostix @data
ntc_hostix:		dw 0			; host platforms: IX kept over a firmware / BDOS call

;## ntc_d_rampt @data
ntc_rampt:		dw #7FC0		; the gate array's RAM setting now (B = port, C = value): the
								; Memory class keeps it, Graphics puts it back after drawing

;## ntc_d_numbuf @data
ntc_numbuf:		ds 14			; printint / long print: digits (+ spaces for Option VBPrint)

;## ntc_d_inbuf @data
				db 40			; ntc_inbuf's capacity (as every string variable has)
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

;## kw_stop ntc_data ntc_plat_exit @shared
kw_stop:
			ld ix, ntc_stop_back
			jp ntc_plat_exit
ntc_stop_back:
			ld sp, (ntc_csp)
			ei
			ret

;## kw_waitkey ntc_data ntc_plat_key
; kw_waitkey - wait for a key (Option PressAnyKeyOnEnd, before kw_stop)
kw_waitkey:
			ld ix, ntc_next
			jp ntc_plat_getkey

;## ntc_xn ntc_data @shared
; normal mode "next": every normal mode keyword ends here (its ret
; became jp ntc_xn). Thread position to ntc_ip, real stack, one
; instruction with interrupts on, then back into the thread.
ntc_xn:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			nop					; an interrupt can be taken here
			di
			ld sp, (ntc_ip)
			ret

;## ntc_xnh ntc_data ntc_islots @shared
; ntc_xn for a program with an Interrupt hook (Interrupt MySub) or interrupt
; classes (Option Class Interrupt): the same window, then a pending hook
; runs as a call of the hook Sub from this point (its return goes back into
; the thread), else a due class's Tick (not one still running). Flags are
; kept when nothing runs. Linked instead of ntc_xn.
ntc_xn:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			nop					; an interrupt can be taken here
			di
			push af
			ld a, (ntc_hookpend)
			or a
			jr nz, ntc_xn_hookp
			ld a, (ntc_isldue)
			or a
			jr nz, ntc_xn_isl
ntc_xn_none:
			pop af
			ld sp, (ntc_ip)
			ret
ntc_xn_isl:
			ld hl, ntc_isl + 4		; the first slot due and not running
			ld a, (ntc_isln)
			ld b, a
			ld c, 0					; due but still running: stays due
ntc_xi_lp:
			ld a, (hl)
			or a
			jr nz, ntc_xi_skip
			inc hl
			ld a, (hl)
			dec hl
			or a
			jr nz, ntc_xi_run
ntc_xi_skip:
			inc hl
			ld a, (hl)
			dec hl
			or c
			ld c, a
			ld de, 8
			add hl, de
			djnz ntc_xi_lp
			ld a, c
			ld (ntc_isldue), a
			jr ntc_xn_none
ntc_xi_run:
			ld (hl), 1				; running (its return stub clears it)
			inc hl
			ld (hl), 0				; not due
			inc hl
			ld e, (hl)				; Tick's call stub
			inc hl
			ld d, (hl)
			pop af
			ld sp, (ntc_ip)
			ex de, hl
			jp (hl)
ntc_xn_hookp:
			pop af
ntc_xn_hook:
			xor a
			ld (ntc_hookpend), a
			ld (ntc_hookon), a	; not again until the hook returns
			ld sp, (ntc_ip)
			ld hl, (ntc_hook)
			jp (hl)

;## kw_hookon ntc_data @shared
;kw_hookon, <call stub>  - Interrupt MySub: run MySub after interrupts (normal mode)
kw_hookon:
			pop hl
			ld (ntc_hook), hl
			ld a, 1
			ld (ntc_hookset), a
			ld (ntc_hookon), a
			ret

;## kw_hookoff ntc_data @shared
;kw_hookoff  - Interrupt Off
kw_hookoff:
			xor a
			ld (ntc_hookset), a
			ld (ntc_hookon), a
			ld (ntc_hookpend), a
			ret

;## kw_turbo_on ntc_data @shared
;kw_turbo_on  - Turbo On, used in normal mode: SP is already the thread
;  and interrupts are off inside a keyword, so just carry on.
kw_turbo_on:
			xor a
			ld (ntc_nmode), a
			ret

;## kw_irq ntc_xn @shared
;kw_irq  - normal mode: a safe point the compiler puts in long runs
;  of keywords without a branch, so interrupts are not held off
kw_irq:
			jp ntc_xn

;## kw_turbo_off ntc_xn ntc_data @shared
;kw_turbo_off  - Turbo Off, used in turbo mode: continue in normal mode
kw_turbo_off:
			ld a, 1
			ld (ntc_nmode), a
			jp ntc_xn

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
; ntc_for_le: jump to the label if var <= limit (loop again). A not 0: the
; step took var past 32767 (or -32768): the loop ends (ntc_for_ge too)
ntc_for_le:
			or a
			jr nz, ntc_for_end
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
			or a
			jr nz, ntc_for_end
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
ntc_for_end:
			pop hl
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
			ld a, d					; A = #FF when it went past 32767 (#8000)
			xor #80
			or e
			sub 1
			sbc a, a
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
			ld c, (hl)
			inc hl
			ld h, (hl)
			ld l, c
			ld a, d					; A = #FF when it went past 32767 (#8000)
			xor #80
			or e
			sub 1
			sbc a, a
			jp ntc_for_le

;## ntc_nextadd
; var += literal step. Pops var and step. Leaves DE = new value, A = #FF when
; it went past 32767 or -32768 (the loop ends), else 0.
ntc_nextadd:
			pop hl				; var
			pop bc				; step
			ld e, (hl)
			inc hl
			ld d, (hl)
			ex de, hl
			or a
			adc hl, bc			; P/V = past the end of the Integers
			ex de, hl			; DE = new value
			ld (hl), d
			dec hl
			ld (hl), e
			ld a, 0
			jp po, ntc_na_ok
			dec a
ntc_na_ok:
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
			ld c, (hl)
			inc hl
			ld h, (hl)
			ld l, c
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
			ld c, (hl)
			inc hl
			ld h, (hl)
			ld l, c
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
			or a
			adc hl, de			; P/V = past 32767 or -32768: the loop ends
			ld (ix+0), l
			ld (ix+1), h
			jp pe, ntc_fn_end
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
ntc_fn_end:
			pop hl
			pop hl
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

;## kw_aget8
;kw_aget8, <arraybase>, <indexvar>, <destvar>  - Byte array element (0 .. 255)
kw_aget8:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, de
			ld a, (hl)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

;## kw_aset8
;kw_aset8, <arraybase>, <indexvar>, <sourcevar>  - set a Byte array element (low byte)
kw_aset8:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, de
			ex de, hl
			pop hl
			ld a, (hl)
			ld (de), a
			ret

;## kw_redim kw_erase
;kw_redim, <descriptor>, <base>, <lower>, <size>, <count>, <clear>  - ReDim: fill the
;  descriptor (1 dimension); clear <> 0: zero the elements
kw_redim:
			pop hl
			pop de
			ld (ntc_rdbase), de
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			pop de
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld (hl), 0
			inc hl
			ld (hl), 0
			inc hl
			pop bc
			pop de
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld (hl), 1
			inc hl
			ld (hl), 0
			inc hl
			ld (hl), c
			inc hl
			ld (hl), b
			pop hl
			ld a, h
			or l
			ret z
			ld b, c
			ld hl, 0
ntc_rd_mul:
			add hl, de
			djnz ntc_rd_mul
			ld b, h
			ld c, l
			ld hl, (ntc_rdbase)
			jp ntc_zerofill
ntc_rdbase:		dw 0

;## kw_erase
;kw_erase, <base>, <bytes>  - Erase of a fixed size array: zero it
kw_erase:
			pop hl
			pop bc
; HL = start, BC = bytes: zero them, then the next keyword
ntc_zerofill:
			ld a, b
			or c
			ret z
			ld (hl), 0
			dec bc
			ld a, b
			or c
			ret z
			ld d, h
			ld e, l
			inc de
			ldir
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
; Strings: 0 terminated. A string variable or temp has its capacity
; (1 .. 255 chars) in the byte before it: [cap][text...][0]. Array
; elements have no capacity byte (the caller gives the element size).
; Functions that build a string write into a temp, so they cut at
; NTC_STRMAX (the longest string in the program, set by the compiler);
; kw_strcpy / kw_strcat / input cut at the destination's capacity.
; ============================================================

;## kw_strcpy
;kw_strcpy, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcpy:
			pop de
			pop hl
			dec de
			ld a, (de)
			ld b, a
			inc de
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

;## kw_strcpyn kw_strcpy
;kw_strcpyn, <destaddr>, <srcaddr>, <capacity>  - into an array element (no capacity byte)
kw_strcpyn:
			pop de
			pop hl
			pop bc
			ld b, c
			jr ntc_strcpy_loop

;## kw_strcat
;kw_strcat, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcat:
			pop de
			dec de
			ld a, (de)
			ld b, a
			inc de
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

;## ntc_printbuf ntc_data ntc_plat_screen
; print the 0 terminated ASCII text at (ntc_sptr), then ret (thread)
ntc_printbuf:
			ld hl, (ntc_sptr)
			ld a, (hl)
			or a
			ret z
			inc hl
			ld (ntc_sptr), hl
			ld ix, ntc_printbuf
			jp ntc_plat_putc

;## kw_printzoscii ntc_data ntc_font ntc_plat_screen
;kw_printzoscii / dw glyph, glyph, ..., 0  - ZOSCII text inline in the thread
;  each word points at an 8 byte glyph bitmap. 1 = newline, 0 = end (only those two:
;  a program at #0040 can have glyphs below #0100)
kw_printzoscii:
			pop de
			ld a, d
			or a
			jr nz, ntc_pz_glyph
			ld a, e
			cp 2
			jr c, ntc_pz_ctl
ntc_pz_glyph:
			ld ix, kw_printzoscii
			jp ntc_plat_putglyph
ntc_pz_ctl:
			or a
			ret z
			ld ix, kw_printzoscii
			jp ntc_plat_newline

;## kw_printstrvar ntc_printbuf
;kw_printstrvar, <straddr>
kw_printstrvar:
			pop hl
			ld (ntc_sptr), hl
			jp ntc_printbuf

;## ntc_itoa ntc_data
; HL = signed value, DE = buffer: writes the digits and a 0 (DE ends on
; the 0). jp (ix) back. Uses A, BC, IY.
ntc_itoa:
			bit 7, h
			jr z, ntc_ia_pos
			ld a, '-'
			ld (de), a
			inc de
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
ntc_ia_pos:
			xor a
			ld (ntc_lead), a
			ld iy, ntc_pow10
ntc_ia_pow:
			ld c, (iy+0)
			ld b, (iy+1)
			ld a, b
			or c
			jr z, ntc_ia_last
			ld a, '0' - 1
ntc_ia_sub:
			inc a
			and a
			sbc hl, bc
			jr nc, ntc_ia_sub
			add hl, bc
			cp '0'
			jr nz, ntc_ia_out
			ld b, a
			ld a, (ntc_lead)
			or a
			ld a, b
			jr z, ntc_ia_skip
ntc_ia_out:
			ld (de), a
			inc de
			ld a, 1
			ld (ntc_lead), a
ntc_ia_skip:
			inc iy
			inc iy
			jr ntc_ia_pow
ntc_ia_last:
			ld a, l
			add a, '0'
			ld (de), a
			inc de
			xor a
			ld (de), a
			jp (ix)
ntc_pow10:		dw 10000, 1000, 100, 10, 0

;## kw_printint ntc_printbuf ntc_itoa
;kw_printint, <var>  - signed decimal
kw_printint:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld de, ntc_numbuf
			ld ix, ntc_pi_done
			jp ntc_itoa
ntc_pi_done:
			ld hl, ntc_numbuf
			ld (ntc_sptr), hl
			jp ntc_printbuf

;## kw_printintvb ntc_printbuf ntc_itoa
;kw_printintvb, <var>  - Option VBPrint: a space (or the -), the digits, a space
kw_printintvb:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld de, ntc_numbuf
			bit 7, h
			jr nz, ntc_piv_neg
			ld a, ' '
			ld (de), a
			inc de
ntc_piv_neg:
			ld ix, ntc_piv_done
			jp ntc_itoa
ntc_piv_done:
			ld a, ' '
			ld (de), a
			inc de
			xor a
			ld (de), a
			ld hl, ntc_numbuf
			ld (ntc_sptr), hl
			jp ntc_printbuf

;## kw_printzone kw_printtab
;kw_printzone  - Option VBPrint: a comma in Print moves to the next 14 column zone
kw_printzone:
			ld a, (ntc_curx)
			ld c, a
			ld a, 14
ntc_pz_find:
			cp c
			jr z, ntc_pz_more
			jr nc, ntc_pz_got
ntc_pz_more:
			add a, 14
			jr ntc_pz_find
ntc_pz_got:
			ld hl, ntc_scols
			cp (hl)
			jr c, ntc_pz_go
			ld ix, ntc_next
			jp ntc_plat_newline
ntc_pz_go:
			ld (ntc_tabcol), a
			jp ntc_pt_loop

;## kw_printnl0 ntc_data ntc_plat_screen
;kw_printnl0  - new line unless the cursor is at the start of a line
kw_printnl0:
			ld a, (ntc_curx)
			or a
			ret z
			ld ix, ntc_next
			jp ntc_plat_newline

;## kw_callp
;kw_callp, <addressvar>, <arg>, ...  - CallAddr: jump to the procedure call stub whose
;  address (AddressOf) is in the var. SP is then at the arguments, as the stub expects
kw_callp:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp (hl)

;## kw_inp
;kw_inp, <portvar>, <dest>  - Inp(port): in a, (c) with BC = port, 0 .. 255
kw_inp:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			in a, (c)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

;## kw_out
;kw_out, <portvar>, <valuevar>  - Out port, value: out (c), a with BC = port
kw_out:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld a, (hl)
			out (c), a
			ret

;## kw_printnl ntc_data ntc_plat_screen
;kw_printnl
kw_printnl:
			ld ix, ntc_next
			jp ntc_plat_newline

;## kw_printtab ntc_data ntc_plat_screen
;kw_printtab, <nvar>  - Tab(n) in Print: spaces up to column n (1 based),
;  a new line first when the cursor is already past it. n off the line: nothing
kw_printtab:
			pop hl
			ld a, (hl)
			dec a
			ld hl, ntc_scols
			cp (hl)
			ret nc
			ld (ntc_tabcol), a
			ld hl, ntc_curx
			cp (hl)
			jr nc, ntc_pt_loop
			ld ix, ntc_pt_loop
			jp ntc_plat_newline
ntc_pt_loop:
			ld a, (ntc_tabcol)
			ld hl, ntc_curx
			cp (hl)
			ret z
			ret c
			ld a, ' '
			ld ix, ntc_pt_loop
			jp ntc_plat_putc
ntc_tabcol:		db 0

;## ntc_gets ntc_data ntc_plat_screen ntc_plat_key
; line input with echo and DEL (or backspace). HL = buffer (its capacity in the byte
; before it), DE = where to
; jp when done (after the newline). 40 chars max, 0 terminated.
ntc_gets:
			ld (ntc_iptr), hl
			ld (ntc_ilink), de
			dec hl
			ld a, (hl)			; the buffer's capacity
			ld (ntc_icap), a
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
			cp 8
			jr z, ntc_gs_del
			cp 32
			jr c, ntc_gs_wait
			ld c, a
			ld a, (ntc_icap)
			ld b, a
			ld a, (ntc_icnt)
			cp b
			jr nc, ntc_gs_wait
			inc a
			ld (ntc_icnt), a
			ld hl, (ntc_iptr)
			ld (hl), c
			inc hl
			ld (ntc_iptr), hl
			ld a, c
			ld ix, ntc_gs_wait
			jp ntc_plat_putc
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

;## kw_inputint ntc_gets ntc_atoi
;kw_inputint, <var>  - signed decimal, stops at the first non digit
kw_inputint:
			pop hl
			ld (ntc_ivar), hl
			ld hl, ntc_inbuf
			ld de, ntc_atoi
			jp ntc_gets

;## ntc_atoi ntc_data
; text to number into the var at (ntc_ivar). ntc_atoi reads ntc_inbuf,
; ntc_atoi_hl reads HL. Spaces first, then - , then digits (or &H hex).
ntc_atoi:
			ld hl, ntc_inbuf
ntc_atoi_hl:
			ld a, (hl)
			cp ' '
			jr nz, ntc_atoi_sign
			inc hl
			jr ntc_atoi_hl
ntc_atoi_sign:
			ld c, 0
			cp '-'
			jr nz, ntc_atoi_amp
			inc c
			inc hl
			ld a, (hl)
ntc_atoi_amp:
			ld de, 0
			cp '&'
			jr nz, ntc_atoi_loop
			inc hl
			ld a, (hl)
			or #20
			cp 'h'
			jr nz, ntc_atoi_done
			inc hl
ntc_atoi_hex:
			ld a, (hl)
			sub '0'
			jr c, ntc_atoi_done
			cp 10
			jr c, ntc_atoi_hd
			or #20
			sub 'a' - '0'
			jr c, ntc_atoi_done
			cp 6
			jr nc, ntc_atoi_done
			add a, 10
ntc_atoi_hd:
			ex de, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			or l
			ld l, a
			ex de, hl
			inc hl
			jr ntc_atoi_hex
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

;## kw_inkeys ntc_data ntc_plat_key
;kw_inkeys, <dest>  - Inkey$: the new key press as a string, "" if none
kw_inkeys:
			pop hl
			ld (ntc_ivar), hl
			ld ix, ntc_inks_got
			jp ntc_plat_scankey
ntc_inks_got:
			ld hl, (ntc_ivar)
			ld (hl), a
			or a
			ret z
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

;## kw_ticks ntc_data ntc_plat_ticks
;kw_ticks, <destvar>  - tick count from the platform (CPC: interrupts, 300 a second,
;  only moving in normal mode)
kw_ticks:
			pop hl
			ld (ntc_ivar), hl
			ld ix, ntc_tk_got
			jp ntc_plat_ticks
ntc_tk_got:
			ex de, hl
			ld hl, (ntc_ivar)
			ld (hl), e
			inc hl
			ld (hl), d
			ret

; ============================================================
; String functions. Numbers are passed as the address of a word
; (a literal goes in as lit_n, a dw in the data). Results go to a
; string buffer (41 bytes). Dest may be the same as the source.
; ============================================================

;## ntc_getn ntc_data
; BC = address of a word: A = its value limited to 0..255
; (below 0 = 0, above 255 = 255). jp (ix) back. Keeps DE, HL.
ntc_getn:
			ld a, (bc)
			ld (ntc_gnlo), a
			inc bc
			ld a, (bc)
			or a
			jp m, ntc_gn_zero
			jr nz, ntc_gn_max
			ld a, (ntc_gnlo)
			jp (ix)
ntc_gn_zero:
			xor a
			jp (ix)
ntc_gn_max:
			ld a, 255
			jp (ix)

;## kw_strleft ntc_getn
;kw_strleft, <dest>, <src>, <nvar>  - Left$(src, n)
kw_strleft:
			pop de
			pop hl
			pop bc
			ld ix, ntc_sl_n
			jp ntc_getn
ntc_sl_n:
			ld b, a
; copy up to B chars from HL to DE, then the 0
ntc_strncpy:
			inc b
ntc_sn_loop:
			dec b
			jr z, ntc_sn_end
			ld a, (hl)
			or a
			jr z, ntc_sn_end
			ld (de), a
			inc hl
			inc de
			jr ntc_sn_loop
ntc_sn_end:
			xor a
			ld (de), a
			ret

;## kw_strright ntc_getn kw_strleft
;kw_strright, <dest>, <src>, <nvar>  - Right$(src, n)
kw_strright:
			pop de
			pop hl
			pop bc
			ld ix, ntc_sr_n
			jp ntc_getn
ntc_sr_n:
			ld c, a
			ld (ntc_sptr), hl
			ld b, 0
ntc_sr_len:
			ld a, (hl)
			or a
			jr z, ntc_sr_got
			inc hl
			inc b
			jr ntc_sr_len
ntc_sr_got:
			ld a, b
			sub c
			jr nc, ntc_sr_skip
			xor a
ntc_sr_skip:
			ld hl, (ntc_sptr)
			ld c, a
			ld b, 0
			add hl, bc
			ld b, 255
			jp ntc_strncpy

;## kw_pow
;kw_pow, <basevar>, <expvar>, <destvar>  - base ^ exp (Integer, low 16 bits; exp < 0 gives 0)
kw_pow:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld hl, 1
			bit 7, d
			jr z, ntc_pw_go
			ld hl, 0
			jr ntc_pw_st
ntc_pw_go:
			ld a, d
			or e
			jr z, ntc_pw_st
			ld (ntc_pwe), de
			ex de, hl
			ld hl, 0
			ld a, 16
ntc_pw_mul:
			add hl, hl
			sla e
			rl d
			jr nc, ntc_pw_sk
			add hl, bc
ntc_pw_sk:
			dec a
			jr nz, ntc_pw_mul
			ld de, (ntc_pwe)
			dec de
			jr ntc_pw_go
ntc_pw_st:
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret
ntc_pwe:		dw 0

;## kw_sqr
;kw_sqr, <var>, <destvar>  - Sqr: whole number square root (negative gives 0)
kw_sqr:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld de, 0
			bit 7, h
			jr nz, ntc_sq_done
			ld bc, 1
ntc_sq_loop:
			or a
			sbc hl, bc
			jr c, ntc_sq_done
			inc de
			inc bc
			inc bc
			jr ntc_sq_loop
ntc_sq_done:
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## kw_strrev
;kw_strrev, <dest>, <src>  - StrReverse
kw_strrev:
			pop de
			pop hl
			ld a, h
			cp d
			jr nz, ntc_rv_copy
			ld a, l
			cp e
			jr z, ntc_rv_go
ntc_rv_copy:
			ld (ntc_rvd), de
ntc_rv_cl:
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			or a
			jr nz, ntc_rv_cl
			ld de, (ntc_rvd)
ntc_rv_go:
			ld h, d
			ld l, e
ntc_rv_end:
			ld a, (hl)
			or a
			jr z, ntc_rv_last
			inc hl
			jr ntc_rv_end
ntc_rv_last:
			dec hl
ntc_rv_swap:
			ld a, e
			sub l
			ld a, d
			sbc a, h
			ret nc
			ld a, (de)
			ld c, (hl)
			ld (hl), a
			ld a, c
			ld (de), a
			inc de
			dec hl
			jr ntc_rv_swap
ntc_rvd:		dw 0

;## kw_stroct
;kw_stroct, <dest>, <var>  - Oct$ (16 bit unsigned, no leading zeros)
kw_stroct:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld c, 0
			xor a
			add hl, hl
			rla
			ld b, 6
			jr ntc_oc_put
ntc_oc_next:
			xor a
			add hl, hl
			rla
			add hl, hl
			rla
			add hl, hl
			rla
ntc_oc_put:
			or a
			jr nz, ntc_oc_out
			inc c
			dec c
			jr nz, ntc_oc_out
			ld a, b
			cp 1
			ld a, 0
			jr nz, ntc_oc_skip
ntc_oc_out:
			ld c, 1
			add a, '0'
			ld (de), a
			inc de
ntc_oc_skip:
			djnz ntc_oc_next
			xor a
			ld (de), a
			ret

;## kw_strinstrrev
;kw_strinstrrev, <text>, <find>, <startvar>, <destvar>  - InStrRev (start -1 = from the end)
kw_strinstrrev:
			pop hl
			ld (ntc_irs), hl
			pop hl
			ld (ntc_irf), hl
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld (ntc_irst), hl
			ld hl, (ntc_irs)
			ld bc, 0
ntc_ir_l1:
			ld a, (hl)
			or a
			jr z, ntc_ir_l1e
			inc hl
			inc bc
			jr ntc_ir_l1
ntc_ir_l1e:
			ld (ntc_irls), bc
			ld hl, (ntc_irf)
			ld bc, 0
ntc_ir_l2:
			ld a, (hl)
			or a
			jr z, ntc_ir_l2e
			inc hl
			inc bc
			jr ntc_ir_l2
ntc_ir_l2e:
			ld hl, (ntc_irls)
			or a
			sbc hl, bc
			inc hl
			ld de, (ntc_irst)
			bit 7, d
			jr nz, ntc_ir_loop
			ld a, d
			or e
			jr z, ntc_ir_loop
			ld a, e
			sub l
			ld a, d
			sbc a, h
			jr nc, ntc_ir_loop
			ld h, d
			ld l, e
ntc_ir_loop:
			bit 7, h
			jr nz, ntc_ir_none
			ld a, h
			or l
			jr z, ntc_ir_none
			ld (ntc_irp), hl
			ld de, (ntc_irs)
			add hl, de
			dec hl
			ex de, hl
			ld hl, (ntc_irf)
ntc_ir_cmp:
			ld a, (hl)
			or a
			jr z, ntc_ir_found
			ex de, hl
			cp (hl)
			ex de, hl
			jr nz, ntc_ir_no
			inc hl
			inc de
			jr ntc_ir_cmp
ntc_ir_no:
			ld hl, (ntc_irp)
			dec hl
			jr ntc_ir_loop
ntc_ir_found:
			ld hl, (ntc_irp)
			jr ntc_ir_st
ntc_ir_none:
			ld hl, 0
ntc_ir_st:
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret
ntc_irs:		dw 0
ntc_irf:		dw 0
ntc_irst:		dw 0
ntc_irls:		dw 0
ntc_irp:		dw 0

;## kw_strreplace
;kw_strreplace, <dest>, <text>, <find>, <with>  - Replace (NTC_STRMAX characters at most)
kw_strreplace:
			pop hl
			ld (ntc_rpd), hl
			pop hl
			ld (ntc_rps), hl
			pop hl
			ld (ntc_rpf), hl
			pop hl
			ld (ntc_rpr), hl
			ld de, ntc_rpbuf
			ld b, NTC_STRMAX
			ld hl, (ntc_rpf)
			ld a, (hl)
			or a
			jr z, ntc_rp_rest
ntc_rp_loop:
			ld hl, (ntc_rps)
			ld a, (hl)
			or a
			jr z, ntc_rp_done
			ld (ntc_rpp), hl
			ld ix, (ntc_rpf)
ntc_rp_m:
			ld a, (ix+0)
			or a
			jr z, ntc_rp_hit
			cp (hl)
			jr nz, ntc_rp_miss
			inc hl
			inc ix
			jr ntc_rp_m
ntc_rp_hit:
			ld (ntc_rps), hl
			ld hl, (ntc_rpr)
ntc_rp_with:
			ld a, (hl)
			or a
			jr z, ntc_rp_loop
			inc b
			dec b
			jr z, ntc_rp_done
			ld (de), a
			inc de
			inc hl
			dec b
			jr ntc_rp_with
ntc_rp_miss:
			ld hl, (ntc_rpp)
			ld a, (hl)
			inc hl
			ld (ntc_rps), hl
			inc b
			dec b
			jr z, ntc_rp_done
			ld (de), a
			inc de
			dec b
			jr ntc_rp_loop
ntc_rp_rest:
			ld hl, (ntc_rps)
ntc_rp_cpy:
			ld a, (hl)
			or a
			jr z, ntc_rp_done
			inc b
			dec b
			jr z, ntc_rp_done
			ld (de), a
			inc de
			inc hl
			dec b
			jr ntc_rp_cpy
ntc_rp_done:
			xor a
			ld (de), a
			ld hl, ntc_rpbuf
			ld de, (ntc_rpd)
ntc_rp_out:
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			or a
			jr nz, ntc_rp_out
			ret
ntc_rpd:		dw 0
ntc_rps:		dw 0
ntc_rpf:		dw 0
ntc_rpr:		dw 0
ntc_rpp:		dw 0
ntc_rpbuf:		ds NTC_STRMAX + 1

;## kw_strlike
;kw_strlike, <text>, <pattern>  - Z if text Like pattern: * any run, ? one char,
;  # one digit, [abc] / [a-z] one of, [!abc] none of. Case matters (Option Compare Binary)
kw_strlike:
			pop de
			pop hl
			ld bc, 0
			ld (ntc_lksp), bc
ntc_lk_loop:
			ld a, (de)
			or a
			jp z, ntc_lk_end
			ld a, (hl)
			cp '*'
			jp nz, ntc_lk_one
			inc hl
			ld (ntc_lksp), hl
			ld (ntc_lkss), de
			jp ntc_lk_loop
ntc_lk_one:
			ld a, (de)
			ld (ntc_lkch), a
			ld a, (hl)
			or a
			jp z, ntc_lk_back
			cp '?'
			jp z, ntc_lk_ok1
			cp '#'
			jp nz, ntc_lk_br
			ld a, (ntc_lkch)
			cp '0'
			jp c, ntc_lk_back
			cp '9' + 1
			jp nc, ntc_lk_back
ntc_lk_ok1:
			inc hl
			inc de
			jp ntc_lk_loop
ntc_lk_br:
			cp '['
			jp nz, ntc_lk_lit
			inc hl
			ld c, 0
			ld a, (hl)
			cp '!'
			jp nz, ntc_lk_c0
			ld c, 1
			inc hl
ntc_lk_c0:
			ld b, 0
ntc_lk_cl:
			ld a, (hl)
			or a
			jp z, ntc_lk_back
			cp ']'
			jp z, ntc_lk_clend
			ld (ntc_lklo), a
			ld (ntc_lkhi), a
			inc hl
			ld a, (hl)
			cp '-'
			jp nz, ntc_lk_cmp
			inc hl
			ld a, (hl)
			cp ']'
			jp z, ntc_lk_dash
			or a
			jp z, ntc_lk_back
			ld (ntc_lkhi), a
			inc hl
			jp ntc_lk_cmp
ntc_lk_dash:
			dec hl
ntc_lk_cmp:
			ld ix, ntc_lklo
			ld a, (ntc_lkch)
			cp (ix+0)
			jp c, ntc_lk_cl
			cp (ix+1)
			jp z, ntc_lk_hit
			jp nc, ntc_lk_cl
ntc_lk_hit:
			ld b, 1
			jp ntc_lk_cl
ntc_lk_clend:
			inc hl
			ld a, b
			xor c
			jp z, ntc_lk_back
			inc de
			jp ntc_lk_loop
ntc_lk_lit:
			ld a, (ntc_lkch)
			cp (hl)
			jp nz, ntc_lk_back
			inc hl
			inc de
			jp ntc_lk_loop
ntc_lk_back:
			ld hl, (ntc_lksp)
			ld a, h
			or l
			jp z, ntc_lk_no
			ld de, (ntc_lkss)
			inc de
			ld (ntc_lkss), de
			jp ntc_lk_loop
ntc_lk_end:
			ld a, (hl)
			cp '*'
			jp nz, ntc_lk_e2
			inc hl
			jp ntc_lk_end
ntc_lk_e2:
			or a
			ret
ntc_lk_no:
			or 1
			ret
ntc_lksp:		dw 0
ntc_lkss:		dw 0
ntc_lkch:		db 0
ntc_lklo:		db 0
ntc_lkhi:		db 0

;## kw_strlset
;kw_strlset, <dest>, <src>  - LSet dest = src: src left in dest's length, spaces after
kw_strlset:
			pop de
			pop hl
			ld (ntc_lss), hl
			ld (ntc_lsd), de
			ex de, hl
			ld b, 0
ntc_ls_len:
			ld a, (hl)
			or a
			jr z, ntc_ls_go
			inc hl
			inc b
			jr ntc_ls_len
ntc_ls_go:
			ld a, b
			or a
			ret z
			ld de, (ntc_lsd)
			ld hl, (ntc_lss)
ntc_ls_cp:
			ld a, (hl)
			or a
			jr z, ntc_ls_pad
			ld (de), a
			inc hl
			inc de
			djnz ntc_ls_cp
			ret
ntc_ls_pad:
			ld a, ' '
ntc_ls_p2:
			ld (de), a
			inc de
			djnz ntc_ls_p2
			ret
ntc_lss:		dw 0
ntc_lsd:		dw 0

;## kw_strrset kw_strlset
;kw_strrset, <dest>, <src>  - RSet dest = src: src right in dest's length, spaces before
kw_strrset:
			pop de
			pop hl
			ld (ntc_lss), hl
			ld (ntc_lsd), de
			ex de, hl
			ld b, 0
ntc_rs_len:
			ld a, (hl)
			or a
			jr z, ntc_rs_l2
			inc hl
			inc b
			jr ntc_rs_len
ntc_rs_l2:
			ld hl, (ntc_lss)
			ld c, 0
ntc_rs_len2:
			ld a, (hl)
			or a
			jr z, ntc_rs_go
			inc hl
			inc c
			jr ntc_rs_len2
ntc_rs_go:
			ld a, b
			or a
			ret z
			ld de, (ntc_lsd)
			ld a, c
			cp b
			jr c, ntc_rs_pad
			ld hl, (ntc_lss)
ntc_rs_cp:
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			djnz ntc_rs_cp
			ret
ntc_rs_pad:
			ld a, b
			sub c
			ld b, a
			ld a, ' '
ntc_rs_p:
			ld (de), a
			inc de
			djnz ntc_rs_p
			ld a, c
			or a
			ret z
			ld b, c
			ld hl, (ntc_lss)
			jr ntc_rs_cp

;## kw_strfix
;kw_strfix, <var>, <n>  - String * n after a change: pad with spaces / cut to n
kw_strfix:
			pop hl
			pop bc
			ld b, c
			ld a, b
			or a
			jr z, ntc_sf2_end
ntc_sf2_len:
			ld a, (hl)
			or a
			jr z, ntc_sf2_pad
			inc hl
			djnz ntc_sf2_len
			ld (hl), 0
			ret
ntc_sf2_pad:
			ld a, ' '
ntc_sf2_p:
			ld (hl), a
			inc hl
			djnz ntc_sf2_p
ntc_sf2_end:
			ld (hl), 0
			ret

;## ntc_fmt ntc_data
; Format$ with a number pattern. ntc_fmbuf holds "-123" (ntc_itoa / ntc_ltoa);
; the thread has <mindigits>, <group>, <prefix>, <suffix>. Writes to (ntc_fmd).
ntc_fm_common:
			pop bc
			ld a, c
			ld (ntc_fmmin), a
			pop bc
			ld a, c
			ld (ntc_fmgrp), a
			pop hl
			ld (ntc_fmpre), hl
			pop hl
			ld (ntc_fmsuf), hl
			ld de, (ntc_fmd)
			ld hl, ntc_fmbuf
			ld a, (hl)
			cp '-'
			jr nz, ntc_fm_pos
			ld (de), a
			inc de
			inc hl
ntc_fm_pos:
			ld (ntc_fmdig), hl
			ld hl, (ntc_fmpre)
ntc_fm_pre:
			ld a, (hl)
			or a
			jr z, ntc_fm_cnt
			ld (de), a
			inc de
			inc hl
			jr ntc_fm_pre
ntc_fm_cnt:
			ld hl, (ntc_fmdig)
			ld b, 0
ntc_fm_c1:
			ld a, (hl)
			or a
			jr z, ntc_fm_c2
			inc hl
			inc b
			jr ntc_fm_c1
ntc_fm_c2:
			ld c, 0
			ld a, (ntc_fmmin)
			sub b
			jr c, ntc_fm_c3
			ld c, a
ntc_fm_c3:
			ld a, b
			add a, c
			ld (ntc_fmk), a
ntc_fm_mod:
			cp 4
			jr c, ntc_fm_m2
			sub 3
			jr ntc_fm_mod
ntc_fm_m2:
			ld (ntc_fmm), a
			ld hl, (ntc_fmdig)
ntc_fm_out:
			ld a, (ntc_fmk)
			or a
			jr z, ntc_fm_suf
			ld a, c
			or a
			jr z, ntc_fm_d
			dec c
			ld a, '0'
			jr ntc_fm_put
ntc_fm_d:
			ld a, (hl)
			inc hl
ntc_fm_put:
			ld (de), a
			inc de
			ld a, (ntc_fmk)
			dec a
			ld (ntc_fmk), a
			ld a, (ntc_fmm)
			dec a
			ld (ntc_fmm), a
			jr nz, ntc_fm_out
			ld a, 3
			ld (ntc_fmm), a
			ld a, (ntc_fmk)
			or a
			jr z, ntc_fm_suf
			ld a, (ntc_fmgrp)
			or a
			jr z, ntc_fm_out
			ld a, ','
			ld (de), a
			inc de
			jr ntc_fm_out
ntc_fm_suf:
			ld hl, (ntc_fmsuf)
ntc_fm_s1:
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			or a
			jr nz, ntc_fm_s1
			ret
ntc_fmd:		dw 0
ntc_fmdig:		dw 0
ntc_fmpre:		dw 0
ntc_fmsuf:		dw 0
ntc_fmmin:		db 0
ntc_fmgrp:		db 0
ntc_fmk:		db 0
ntc_fmm:		db 0
ntc_fmbuf:		ds 14

;## kw_strfmt ntc_fmt ntc_itoa
;kw_strfmt, <dest>, <var>, <mindigits>, <group>, <prefix>, <suffix>  - Format$(n, "0,000")
kw_strfmt:
			pop hl
			ld (ntc_fmd), hl
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld de, ntc_fmbuf
			ld ix, ntc_fm_common
			jp ntc_itoa

;## kw_l_strfmt ntc_fmt ntc_ltoa
;kw_l_strfmt, <dest>, <long>, <mindigits>, <group>, <prefix>, <suffix>  - Format$ of a Long
kw_l_strfmt:
			pop hl
			ld (ntc_fmd), hl
			pop hl
			ld de, ntc_fmbuf
			ld ix, ntc_fm_common
			jp ntc_ltoa

;## kw_strjoin
;kw_strjoin, <dest>, <descriptor>, <sep>  - Join(stringarray, sep), NTC_STRMAX characters at most
kw_strjoin:
			pop hl
			ld (ntc_jnd), hl
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (ntc_jnp), de
			inc hl
			inc hl
			inc hl
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (ntc_jnc), de
			inc hl
			inc hl
			inc hl
			ld e, (hl)			; the element size (descriptor +10)
			inc hl
			ld d, (hl)
			ld (ntc_jnz), de
			pop hl
			ld (ntc_jns), hl
			ld de, ntc_jnbuf
			ld a, NTC_STRMAX
			ld (ntc_jnr), a
			ld hl, (ntc_jnc)
			ld a, h
			or l
			jr z, ntc_jn_done
ntc_jn_el:
			ld hl, (ntc_jnp)
ntc_jn_c1:
			ld a, (hl)
			or a
			jr z, ntc_jn_eend
			ld c, a
			ld a, (ntc_jnr)
			or a
			jr z, ntc_jn_done
			dec a
			ld (ntc_jnr), a
			ld a, c
			ld (de), a
			inc de
			inc hl
			jr ntc_jn_c1
ntc_jn_eend:
			ld hl, (ntc_jnp)
			ld bc, (ntc_jnz)
			add hl, bc
			ld (ntc_jnp), hl
			ld hl, (ntc_jnc)
			dec hl
			ld (ntc_jnc), hl
			ld a, h
			or l
			jr z, ntc_jn_done
			ld hl, (ntc_jns)
ntc_jn_c2:
			ld a, (hl)
			or a
			jr z, ntc_jn_el
			ld c, a
			ld a, (ntc_jnr)
			or a
			jr z, ntc_jn_done
			dec a
			ld (ntc_jnr), a
			ld a, c
			ld (de), a
			inc de
			inc hl
			jr ntc_jn_c2
ntc_jn_done:
			xor a
			ld (de), a
			ld hl, ntc_jnbuf
			ld de, (ntc_jnd)
ntc_jn_out:
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			or a
			jr nz, ntc_jn_out
			ret
ntc_jnd:		dw 0
ntc_jnp:		dw 0
ntc_jnc:		dw 0
ntc_jns:		dw 0
ntc_jnr:		db 0
ntc_jnz:		dw 0
ntc_jnbuf:		ds NTC_STRMAX + 1

;## kw_strsplit
;kw_strsplit, <descriptor>, <base>, <capacity>, <text>, <sep>, <element size>  - a() = Split(text, sep):
;  fills the elements (element size - 1 chars each) and the descriptor (lower bound 0, count)
kw_strsplit:
			pop hl
			ld (ntc_spd), hl
			pop hl
			ld (ntc_spb), hl
			ld (ntc_spe), hl
			pop hl
			ld (ntc_spcap), hl
			pop hl
			ld (ntc_sps), hl
			pop hl
			ld (ntc_spsep), hl
			pop hl
			ld (ntc_spz), hl
			ld hl, 0
			ld (ntc_spn), hl
			ld hl, (ntc_sps)
			ld a, (hl)
			or a
			jp z, ntc_sp_fin
ntc_sp_elem:
			ld hl, (ntc_spn)
			ld de, (ntc_spcap)
			or a
			sbc hl, de
			jp nc, ntc_sp_fin
			ld hl, (ntc_spn)
			inc hl
			ld (ntc_spn), hl
			ld de, (ntc_spe)
			ld a, (ntc_spz)
			dec a
			ld b, a
ntc_sp_ch:
			ld hl, (ntc_sps)
			ld a, (hl)
			or a
			jp z, ntc_sp_last
			ld ix, (ntc_spsep)
			ld a, (ix+0)
			or a
			jp z, ntc_sp_nosep
ntc_sp_m:
			ld a, (ix+0)
			or a
			jp z, ntc_sp_hit
			cp (hl)
			jp nz, ntc_sp_nosep
			inc hl
			inc ix
			jp ntc_sp_m
ntc_sp_hit:
			ld (ntc_sps), hl
			xor a
			ld (de), a
			ld hl, (ntc_spe)
			ld bc, (ntc_spz)
			add hl, bc
			ld (ntc_spe), hl
			jp ntc_sp_elem
ntc_sp_nosep:
			ld hl, (ntc_sps)
			ld a, (hl)
			inc hl
			ld (ntc_sps), hl
			inc b
			dec b
			jp z, ntc_sp_ch
			ld (de), a
			inc de
			dec b
			jp ntc_sp_ch
ntc_sp_last:
			xor a
			ld (de), a
ntc_sp_fin:
			ld hl, (ntc_spd)
			ld de, (ntc_spb)
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			xor a
			ld (hl), a
			inc hl
			ld (hl), a
			inc hl
			ld (hl), a
			inc hl
			ld (hl), a
			inc hl
			ld de, (ntc_spn)
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld (hl), 1
			inc hl
			ld (hl), 0
			inc hl
			ld de, (ntc_spz)
			ld (hl), e
			inc hl
			ld (hl), d
			ret
ntc_spz:		dw 0
ntc_spd:		dw 0
ntc_spb:		dw 0
ntc_spe:		dw 0
ntc_spcap:		dw 0
ntc_sps:		dw 0
ntc_spsep:		dw 0
ntc_spn:		dw 0

;## kw_strmidset
;kw_strmidset, <textvar>, <startvar>, <lenvar>, <src>  - Mid$(s, start, len) = src
;  (replaces in place, the length of s does not change)
kw_strmidset:
			pop hl
			ld (ntc_mss), hl
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld (ntc_msr), hl
			ld a, d
			or a
			ret nz
			ld a, e
			or a
			ret z
			ld hl, (ntc_mss)
			dec e
			jr z, ntc_ms_at
ntc_ms_adv:
			ld a, (hl)
			or a
			ret z
			inc hl
			dec e
			jr nz, ntc_ms_adv
ntc_ms_at:
			ld de, (ntc_msr)
			ld a, b
			or a
			jr z, ntc_ms_len
			ld c, 255
ntc_ms_len:
			ld a, c
			or a
			ret z
			ld b, a
ntc_ms_cp:
			ld a, (hl)
			or a
			ret z
			ld a, (de)
			or a
			ret z
			ld (hl), a
			inc hl
			inc de
			djnz ntc_ms_cp
			ret
ntc_mss:		dw 0
ntc_msr:		dw 0

;## kw_strmid ntc_getn kw_strleft
;kw_strmid, <dest>, <src>, <startvar>, <lenvar>  - Mid$(src, start, len)
kw_strmid:
			pop de
			pop hl
			pop bc
			ld ix, ntc_sm_s
			jp ntc_getn
ntc_sm_s:
			or a
			jr z, ntc_sm_s1
			dec a
ntc_sm_s1:
			ld b, a
			inc b
ntc_sm_skip:
			dec b
			jr z, ntc_sm_len
			ld a, (hl)
			or a
			jr z, ntc_sm_len
			inc hl
			jr ntc_sm_skip
ntc_sm_len:
			pop bc
			ld ix, ntc_sm_n
			jp ntc_getn
ntc_sm_n:
			ld b, a
			jp ntc_strncpy

;## kw_strchr
;kw_strchr, <dest>, <nvar>  - Chr$(n)
kw_strchr:
			pop de
			pop hl
			ld a, (hl)
			ld (de), a
			inc de
			xor a
			ld (de), a
			ret

;## kw_strcstr ntc_itoa
;kw_strcstr, <dest>, <nvar>  - number to text (CStr, "x" & n)
kw_strcstr:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld ix, ntc_next
			jp ntc_itoa

;## kw_strstr ntc_itoa
;kw_strstr, <dest>, <nvar>  - Str$(n): a space before 0 and positives
kw_strstr:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			bit 7, h
			jr nz, ntc_st_go
			ld a, ' '
			ld (de), a
			inc de
ntc_st_go:
			ld ix, ntc_next
			jp ntc_itoa

;## kw_strhex
;kw_strhex, <dest>, <nvar>  - Hex$(n), no leading zeros
kw_strhex:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld b, 4
			ld c, 0
ntc_hx_loop:
			xor a
			add hl, hl
			rla
			add hl, hl
			rla
			add hl, hl
			rla
			add hl, hl
			rla
			bit 0, c
			jr nz, ntc_hx_out
			or a
			jr nz, ntc_hx_first
			ld a, b
			dec a
			jr nz, ntc_hx_next
			xor a
ntc_hx_first:
			set 0, c
ntc_hx_out:
			add a, '0'
			cp '9' + 1
			jr c, ntc_hx_put
			add a, 7
ntc_hx_put:
			ld (de), a
			inc de
ntc_hx_next:
			djnz ntc_hx_loop
			xor a
			ld (de), a
			ret

;## kw_strspace ntc_getn
;kw_strspace, <dest>, <nvar>  - Space$(n)
kw_strspace:
			pop de
			pop bc
			ld ix, ntc_sp_n
			jp ntc_getn
ntc_sp_n:
			ld c, ' '
; A = count (NTC_STRMAX at most), C = char, DE = dest
ntc_strfill:
	IF NTC_STRMAX < 255
			cp NTC_STRMAX + 1
			jr c, ntc_sf_ok
			ld a, NTC_STRMAX
ntc_sf_ok:
	ENDIF
			ld b, a
			inc b
ntc_sf_loop:
			dec b
			jr z, ntc_sf_end
			ld a, c
			ld (de), a
			inc de
			jr ntc_sf_loop
ntc_sf_end:
			xor a
			ld (de), a
			ret

;## kw_strstring kw_strspace
;kw_strstring, <dest>, <nvar>, <charvar>  - String$(n, char code)
kw_strstring:
			pop de
			pop bc
			ld ix, ntc_ss_n
			jp ntc_getn
ntc_ss_n:
			pop hl
			ld c, (hl)
			jp ntc_strfill

;## kw_strucase
;kw_strucase, <dest>, <src>  - UCase$
kw_strucase:
			pop de
			pop hl
ntc_uc_loop:
			ld a, (hl)
			cp 'a'
			jr c, ntc_uc_put
			cp 'z' + 1
			jr nc, ntc_uc_put
			sub 32
ntc_uc_put:
			ld (de), a
			or a
			ret z
			inc hl
			inc de
			jr ntc_uc_loop

;## kw_strlcase
;kw_strlcase, <dest>, <src>  - LCase$
kw_strlcase:
			pop de
			pop hl
ntc_lc_loop:
			ld a, (hl)
			cp 'A'
			jr c, ntc_lc_put
			cp 'Z' + 1
			jr nc, ntc_lc_put
			add a, 32
ntc_lc_put:
			ld (de), a
			or a
			ret z
			inc hl
			inc de
			jr ntc_lc_loop

;## kw_strltrim kw_strleft
;kw_strltrim, <dest>, <src>  - LTrim$
kw_strltrim:
			pop de
			pop hl
ntc_lt_skip:
			ld a, (hl)
			cp ' '
			jr nz, ntc_lt_copy
			inc hl
			jr ntc_lt_skip
ntc_lt_copy:
			ld b, 255
			jp ntc_strncpy

;## kw_strrtrim ntc_data
;kw_strrtrim, <dest>, <src>  - RTrim$
kw_strrtrim:
			pop de
			pop hl
			ld (ntc_sptr), de
ntc_rt_copy:
			ld a, (hl)
			ld (de), a
			or a
			jr z, ntc_rt_back
			inc hl
			inc de
			jr ntc_rt_copy
ntc_rt_back:
			ld hl, (ntc_sptr)
			ex de, hl
ntc_rt_loop:
			or a
			sbc hl, de
			add hl, de
			ret z
			dec hl
			ld a, (hl)
			cp ' '
			ret nz
			ld (hl), 0
			jr ntc_rt_loop

;## kw_strtrim kw_strrtrim
;kw_strtrim, <dest>, <src>  - Trim$
kw_strtrim:
			pop de
			pop hl
ntc_tr_skip:
			ld a, (hl)
			cp ' '
			jr nz, ntc_tr_go
			inc hl
			jr ntc_tr_skip
ntc_tr_go:
			ld (ntc_sptr), de
			jp ntc_rt_copy

;## kw_strasc
;kw_strasc, <src>, <destvar>  - Asc(src), 0 if empty
kw_strasc:
			pop hl
			ld a, (hl)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

;## kw_strval ntc_atoi
;kw_strval, <src>, <destvar>  - Val(src): decimal or &H hex
kw_strval:
			pop hl
			pop de
			ld (ntc_ivar), de
			jp ntc_atoi_hl

;## kw_strinstr ntc_getn ntc_data
;kw_strinstr, <startvar>, <s1>, <s2>, <destvar>  - InStr(start, s1, s2)
kw_strinstr:
			pop bc
			ld ix, ntc_in_s
			jp ntc_getn
ntc_in_s:
			or a
			jr nz, ntc_in_s1
			inc a
ntc_in_s1:
			ld c, a
			pop hl
			ld b, a
ntc_in_adv:
			dec b
			jr z, ntc_in_try0
			ld a, (hl)
			or a
			jr z, ntc_in_nfpop
			inc hl
			jr ntc_in_adv
ntc_in_try0:
			pop de
			ld (ntc_sptr), de
ntc_in_try:
			ld (ntc_iptr), hl
			ld de, (ntc_sptr)
ntc_in_cmp:
			ld a, (de)
			or a
			jr z, ntc_in_found
			cp (hl)
			jr nz, ntc_in_next
			inc hl
			inc de
			jr ntc_in_cmp
ntc_in_next:
			ld hl, (ntc_iptr)
			ld a, (hl)
			or a
			jr z, ntc_in_nf
			inc hl
			inc c
			jr ntc_in_try
ntc_in_nfpop:
			pop de
ntc_in_nf:
			ld c, 0
ntc_in_found:
			pop hl
			ld (hl), c
			inc hl
			ld (hl), 0
			ret

;## ntc_strcmp
; DE = a, HL = b. jp (ix) back with Z = equal, C = a < b
ntc_strcmp:
			ld a, (de)
			cp (hl)
			jr nz, ntc_scm_done
			or a
			jr z, ntc_scm_done
			inc hl
			inc de
			jr ntc_strcmp
ntc_scm_done:
			jp (ix)

;## kw_strcmplt ntc_strcmp
;kw_strcmplt, <a>, <b>  - Z if a < b
kw_strcmplt:
			pop de
			pop hl
			ld ix, ntc_sclt
			jp ntc_strcmp
ntc_sclt:
			jr c, ntc_sclt_y
			or 1
			ret
ntc_sclt_y:
			xor a
			ret

;## kw_strcmple ntc_strcmp
;kw_strcmple, <a>, <b>  - Z if a <= b
kw_strcmple:
			pop de
			pop hl
			ld ix, ntc_scle
			jp ntc_strcmp
ntc_scle:
			jr c, ntc_scle_y
			jr z, ntc_scle_y
			or 1
			ret
ntc_scle_y:
			xor a
			ret

;## kw_strcmpgt ntc_strcmp
;kw_strcmpgt, <a>, <b>  - Z if a > b
kw_strcmpgt:
			pop de
			pop hl
			ld ix, ntc_scgt
			jp ntc_strcmp
ntc_scgt:
			jr c, ntc_scgt_n
			jr z, ntc_scgt_n
			xor a
			ret
ntc_scgt_n:
			or 1
			ret

;## kw_strcmpge ntc_strcmp
;kw_strcmpge, <a>, <b>  - Z if a >= b
kw_strcmpge:
			pop de
			pop hl
			ld ix, ntc_scge
			jp ntc_strcmp
ntc_scge:
			jr c, ntc_scge_n
			xor a
			ret
ntc_scge_n:
			or 1
			ret

; ============================================================
; String arrays (element size = capacity + 1 bytes, no capacity byte,
; no bounds check)
; ============================================================

;## ntc_saddr ntc_data
; DE = base, HL = index var address, (ntc_sasz) = element size:
; HL = base + index * size. jp (ix)
ntc_saddr:
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld a, (ntc_sasz + 1)		; element size 256 (String Max 255): index * 256
			or a
			jr z, ntc_sa_mul
			ld h, l
			ld l, 0
			add hl, de
			jp (ix)
ntc_sa_mul:
			ld b, h
			ld c, l
			ld hl, 0
			ld a, (ntc_sasz)
ntc_sa_bit:
			srl a
			jr nc, ntc_sa_no
			add hl, bc
ntc_sa_no:
			sla c
			rl b
			or a
			jr nz, ntc_sa_bit
			add hl, de
			jp (ix)
ntc_sasz:		dw 0

;## kw_sget ntc_saddr
;kw_sget, <arraybase>, <indexvar>, <dest>, <element size>  - dest = array(index)
kw_sget:
			pop de
			pop hl
			pop bc
			ld (ntc_sgd), bc
			pop bc
			ld (ntc_sasz), bc
			ld ix, ntc_sg_a
			jp ntc_saddr
ntc_sg_a:
			ld de, (ntc_sgd)
			ld bc, (ntc_sasz)
			ldir
			ret
ntc_sgd:		dw 0

;## kw_sset ntc_saddr kw_strcpy
;kw_sset, <arraybase>, <indexvar>, <src>, <element size>  - array(index) = src, cut at the element
kw_sset:
			pop de
			pop hl
			pop bc
			ld (ntc_sgs), bc
			pop bc
			ld (ntc_sasz), bc
			ld ix, ntc_ssa
			jp ntc_saddr
ntc_ssa:
			ex de, hl
			ld hl, (ntc_sgs)
			ld a, (ntc_sasz)
			dec a
			ld b, a
			jp ntc_strcpy_loop
ntc_sgs:		dw 0

; ============================================================
; Array parameters and dynamic arrays. A procedure gets the address of a
; 12 byte descriptor: dw base, lower bound 1, lower bound 2, count 1,
; count 2, element size. The call stub copies it into the parameter's own
; descriptor; ReDim fills a dynamic array's descriptor.
; ============================================================

;## ntc_paddr
; HL = descriptor, DE = index var: HL = element address, BC = element
; size. jp (ix). Descriptor (12 bytes): base, lower bound 1, lower bound 2,
; count 1, count 2, element size (a 1 dimension array has count 2 = 1)
ntc_paddr:
			ld a, (de)
			ld (ntc_pidx), a
			inc de
			ld a, (de)
			ld (ntc_pidx+1), a
			ld (ntc_pdesc), hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld (ntc_pbase), de
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld hl, (ntc_pidx)
			or a
			sbc hl, de
			ld (ntc_pidx), hl
; (ntc_pidx) = element number, (ntc_pbase) = base, (ntc_pdesc) = descriptor
ntc_pa_tail:
			ld hl, (ntc_pdesc)
			ld bc, 10
			add hl, bc
			ld c, (hl)
			inc hl
			ld b, (hl)
			ld de, (ntc_pidx)
			ld hl, (ntc_pbase)
			ld a, c
ntc_pa_mul:
			add hl, de
			dec a
			jr nz, ntc_pa_mul
			jp (ix)
ntc_pidx:		dw 0
ntc_pbase:		dw 0
ntc_pdesc:		dw 0

;## ntc_paddr2 ntc_paddr
; HL = descriptor, (ntc_piv) / (ntc_pjv) = the 2 index vars: HL = element
; address, BC = element size. jp (ix)
ntc_paddr2:
			ld (ntc_pdesc), hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld (ntc_pbase), de
			ld c, (hl)
			inc hl
			ld b, (hl)
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld (ntc_plo2), de
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld hl, (ntc_piv)
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			or a
			sbc hl, bc
			ld b, h
			ld c, l
			ld hl, 0
			ld a, 16
ntc_pa2_mul:
			add hl, hl
			sla c
			rl b
			jr nc, ntc_pa2_skip
			add hl, de
ntc_pa2_skip:
			dec a
			jr nz, ntc_pa2_mul
			ex de, hl
			ld hl, (ntc_pjv)
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld bc, (ntc_plo2)
			or a
			sbc hl, bc
			add hl, de
			ld (ntc_pidx), hl
			jp ntc_pa_tail
ntc_piv:		dw 0
ntc_pjv:		dw 0
ntc_plo2:		dw 0

;## kw_pget ntc_paddr
;kw_pget, <descriptor>, <indexvar>, <dest>  - dest = parameter array(index)
kw_pget:
			pop hl
			pop de
			ld ix, ntc_pg_a
			jp ntc_paddr
ntc_pg_a:
			pop de
			ldir
			ret

;## kw_pset ntc_paddr
;kw_pset, <descriptor>, <indexvar>, <src>  - parameter array(index) = src
kw_pset:
			pop hl
			pop de
			ld ix, ntc_ps_a
			jp ntc_paddr
ntc_ps_a:
			ex de, hl
			pop hl
			ldir
			ret

;## kw_psets ntc_paddr kw_strcpy
;kw_psets, <descriptor>, <indexvar>, <src>  - String parameter array(index) = src, cut at the element
kw_psets:
			pop hl
			pop de
			ld ix, ntc_pss_a
			jp ntc_paddr
ntc_pss_a:
			ex de, hl
			pop hl
			ld a, c
			dec a
			ld b, a
			jp ntc_strcpy_loop

;## kw_psets2 ntc_paddr2 kw_psets
;kw_psets2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src (String)
kw_psets2:
			pop hl
			pop de
			ld (ntc_piv), de
			pop de
			ld (ntc_pjv), de
			ld ix, ntc_pss_a
			jp ntc_paddr2

;## kw_pget2 ntc_paddr2 kw_pget
;kw_pget2, <descriptor>, <index1var>, <index2var>, <dest>  - dest = array(i, j)
kw_pget2:
			pop hl
			pop de
			ld (ntc_piv), de
			pop de
			ld (ntc_pjv), de
			ld ix, ntc_pg_a
			jp ntc_paddr2

;## kw_pset2 ntc_paddr2 kw_pset
;kw_pset2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src
kw_pset2:
			pop hl
			pop de
			ld (ntc_piv), de
			pop de
			ld (ntc_pjv), de
			ld ix, ntc_ps_a
			jp ntc_paddr2

;## kw_lbound
;kw_lbound, <descriptor + 2 * (dimension - 1)>, <dest>  - LBound
kw_lbound:
			pop hl
			inc hl
			inc hl
			pop de
			ldi
			ldi
			ret

;## kw_ubound
;kw_ubound, <descriptor + 2 * (dimension - 1)>, <dest>  - UBound = lower bound + count - 1
kw_ubound:
			pop hl
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			inc hl
			inc hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, de
			dec hl
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

; ============================================================
; Long (32 bit signed). A Long is 4 bytes, low byte first. Every
; argument is an address (a literal is a dw lo, hi in the data).
; Work space ntc_la / ntc_lb / ntc_lr / ntc_lt.
; ============================================================

;## ntc_ldata
ntc_la:			ds 4
ntc_lb:			ds 4
ntc_lr:			ds 4
ntc_lt:			ds 4
ntc_lsgn:		db 0
ntc_lcnt:		db 0
ntc_ldst:		dw 0
ntc_lix:		dw 0

;## kw_l_mov
;kw_l_mov, <src>, <dest>  - dest = src (4 bytes)
kw_l_mov:
			pop hl
			pop de
			ldi
			ldi
			ldi
			ldi
			ret

;## kw_l_itol
;kw_l_itol, <intvar>, <dest>  - Integer to Long (sign extended)
kw_l_itol:
			pop hl
			pop de
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			ld a, (hl)
			ld (de), a
			inc de
			rla
			sbc a, a
			ld (de), a
			inc de
			ld (de), a
			ret

;## kw_l_ltoi
;kw_l_ltoi, <long>, <intdest>  - Long to Integer (low 16 bits)
kw_l_ltoi:
			pop hl
			pop de
			ldi
			ldi
			ret

;## kw_l_add
;kw_l_add, <a>, <b>, <dest>  - a + b
kw_l_add:
			pop hl
			pop de
			pop ix
			ld a, (de)
			add a, (hl)
			ld (ix+0), a
			inc hl
			inc de
			ld a, (de)
			adc a, (hl)
			ld (ix+1), a
			inc hl
			inc de
			ld a, (de)
			adc a, (hl)
			ld (ix+2), a
			inc hl
			inc de
			ld a, (de)
			adc a, (hl)
			ld (ix+3), a
			ret

;## kw_l_sub
;kw_l_sub, <a>, <b>, <dest>  - a - b
kw_l_sub:
			pop de
			pop hl
			pop ix
			ld a, (de)
			sub (hl)
			ld (ix+0), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ix+1), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ix+2), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ix+3), a
			ret

;## kw_l_and
;kw_l_and, <a>, <b>, <dest>
kw_l_and:
			pop hl
			pop de
			pop ix
			ld a, (de)
			and (hl)
			ld (ix+0), a
			inc hl
			inc de
			ld a, (de)
			and (hl)
			ld (ix+1), a
			inc hl
			inc de
			ld a, (de)
			and (hl)
			ld (ix+2), a
			inc hl
			inc de
			ld a, (de)
			and (hl)
			ld (ix+3), a
			ret

;## kw_l_or
;kw_l_or, <a>, <b>, <dest>
kw_l_or:
			pop hl
			pop de
			pop ix
			ld a, (de)
			or (hl)
			ld (ix+0), a
			inc hl
			inc de
			ld a, (de)
			or (hl)
			ld (ix+1), a
			inc hl
			inc de
			ld a, (de)
			or (hl)
			ld (ix+2), a
			inc hl
			inc de
			ld a, (de)
			or (hl)
			ld (ix+3), a
			ret

;## kw_l_xor
;kw_l_xor, <a>, <b>, <dest>
kw_l_xor:
			pop hl
			pop de
			pop ix
			ld a, (de)
			xor (hl)
			ld (ix+0), a
			inc hl
			inc de
			ld a, (de)
			xor (hl)
			ld (ix+1), a
			inc hl
			inc de
			ld a, (de)
			xor (hl)
			ld (ix+2), a
			inc hl
			inc de
			ld a, (de)
			xor (hl)
			ld (ix+3), a
			ret

;## kw_l_not
;kw_l_not, <a>, <dest>
kw_l_not:
			pop hl
			pop de
			ld a, (hl)
			cpl
			ld (de), a
			inc hl
			inc de
			ld a, (hl)
			cpl
			ld (de), a
			inc hl
			inc de
			ld a, (hl)
			cpl
			ld (de), a
			inc hl
			inc de
			ld a, (hl)
			cpl
			ld (de), a
			ret

;## kw_l_neg
;kw_l_neg, <a>, <dest>  - 0 - a
kw_l_neg:
			pop hl
			pop ix
			xor a
			sub (hl)
			ld (ix+0), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (ix+1), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (ix+2), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (ix+3), a
			ret

;## kw_l_abs kw_l_mov kw_l_neg
;kw_l_abs, <a>, <dest>
kw_l_abs:
			pop hl
			inc hl
			inc hl
			inc hl
			bit 7, (hl)
			dec hl
			dec hl
			dec hl
			jr z, ntc_labs_pos
			pop ix
			xor a
			sub (hl)
			ld (ix+0), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (ix+1), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (ix+2), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (ix+3), a
			ret
ntc_labs_pos:
			pop de
			ldi
			ldi
			ldi
			ldi
			ret

;## kw_l_sgn
;kw_l_sgn, <a>, <intdest>  - -1, 0 or 1
kw_l_sgn:
			pop hl
			ld a, (hl)
			inc hl
			or (hl)
			inc hl
			or (hl)
			inc hl
			or (hl)
			ld de, 0
			jr z, ntc_lsg_st
			inc de
			bit 7, (hl)
			jr z, ntc_lsg_st
			ld de, -1
ntc_lsg_st:
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## ntc_lcmp ntc_ldata
; DE = a, HL = b: work out a - b. ntc_lsgn = #80 if a < b (signed),
; ntc_lcnt = 0 if a = b. jp (ix) back.
ntc_lcmp:
			ld a, (de)
			sub (hl)
			ld (ntc_lr), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ntc_lr+1), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ntc_lr+2), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ntc_lr+3), a
			ld b, 0
			jp po, ntc_lcm_nov
			ld b, #80
ntc_lcm_nov:
			xor b
			and #80
			ld (ntc_lsgn), a
			ld hl, ntc_lr
			ld a, (hl)
			inc hl
			or (hl)
			inc hl
			or (hl)
			inc hl
			or (hl)
			ld (ntc_lcnt), a
			jp (ix)

;## kw_l_cplt ntc_lcmp
;kw_l_cplt, <a>, <b>  - Z if a < b
kw_l_cplt:
			pop de
			pop hl
			ld ix, ntc_lclt
			jp ntc_lcmp
ntc_lclt:
			ld a, (ntc_lsgn)
			xor #80
			ret

;## kw_l_cpge ntc_lcmp
;kw_l_cpge, <a>, <b>  - Z if a >= b
kw_l_cpge:
			pop de
			pop hl
			ld ix, ntc_lcge
			jp ntc_lcmp
ntc_lcge:
			ld a, (ntc_lsgn)
			or a
			ret

;## kw_l_cpeq ntc_lcmp
;kw_l_cpeq, <a>, <b>  - Z if a = b
kw_l_cpeq:
			pop de
			pop hl
			ld ix, ntc_lceq
			jp ntc_lcmp
ntc_lceq:
			ld a, (ntc_lcnt)
			or a
			ret

;## kw_l_cpne ntc_lcmp
;kw_l_cpne, <a>, <b>  - Z if a <> b
kw_l_cpne:
			pop de
			pop hl
			ld ix, ntc_lcne
			jp ntc_lcmp
ntc_lcne:
			ld a, (ntc_lcnt)
			or a
			jr z, ntc_lcne_f
			xor a
			ret
ntc_lcne_f:
			or 1
			ret

;## kw_l_cple ntc_lcmp
;kw_l_cple, <a>, <b>  - Z if a <= b
kw_l_cple:
			pop de
			pop hl
			ld ix, ntc_lcle
			jp ntc_lcmp
ntc_lcle:
			ld a, (ntc_lcnt)
			or a
			ret z
			ld a, (ntc_lsgn)
			xor #80
			ret

;## kw_l_cpgt ntc_lcmp
;kw_l_cpgt, <a>, <b>  - Z if a > b
kw_l_cpgt:
			pop de
			pop hl
			ld ix, ntc_lcgt
			jp ntc_lcmp
ntc_lcgt:
			ld a, (ntc_lcnt)
			or a
			jr z, ntc_lcgt_f
			ld a, (ntc_lsgn)
			or a
			ret
ntc_lcgt_f:
			or 1
			ret

;## ntc_lmul ntc_ldata
; ntc_la * ntc_lb -> ntc_lr (low 32 bits, same signed / unsigned). jp (ix)
ntc_lmul:
			ld hl, 0
			ld (ntc_lr), hl
			ld (ntc_lr+2), hl
			ld b, 32
ntc_lm_loop:
			ld hl, ntc_lb+3
			srl (hl)
			dec hl
			rr (hl)
			dec hl
			rr (hl)
			dec hl
			rr (hl)
			jr nc, ntc_lm_skip
			ld de, ntc_la
			ld hl, ntc_lr
			ld a, (de)
			add a, (hl)
			ld (hl), a
			inc de
			inc hl
			ld a, (de)
			adc a, (hl)
			ld (hl), a
			inc de
			inc hl
			ld a, (de)
			adc a, (hl)
			ld (hl), a
			inc de
			inc hl
			ld a, (de)
			adc a, (hl)
			ld (hl), a
ntc_lm_skip:
			ld hl, ntc_la
			sla (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			djnz ntc_lm_loop
			jp (ix)

;## ntc_lnegm
; HL = address of a Long: negate it in place. jp (ix)
ntc_lnegm:
			xor a
			sub (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
			jp (ix)

;## ntc_ldiv ntc_ldata ntc_lnegm
; ntc_la / ntc_lb signed, truncating: quotient in ntc_la, remainder (with
; the dividend's sign) in ntc_lr. Divide by 0: quotient 0, remainder =
; dividend. jp (ix) back.
ntc_ldiv:
			ld (ntc_lix), ix
			ld hl, (ntc_lb)
			ld a, h
			or l
			ld hl, (ntc_lb+2)
			or h
			or l
			jr nz, ntc_ld_nz
			ld hl, (ntc_la)
			ld (ntc_lr), hl
			ld hl, (ntc_la+2)
			ld (ntc_lr+2), hl
			ld hl, 0
			ld (ntc_la), hl
			ld (ntc_la+2), hl
			jp ntc_ld_out
ntc_ld_nz:
			ld a, (ntc_la+3)
			ld (ntc_lsgn), a
			ld b, a
			ld a, (ntc_lb+3)
			xor b
			ld (ntc_lcnt), a
			ld a, (ntc_la+3)
			or a
			jp p, ntc_ld_apos
			ld hl, ntc_la
			ld ix, ntc_ld_apos
			jp ntc_lnegm
ntc_ld_apos:
			ld a, (ntc_lb+3)
			or a
			jp p, ntc_ld_bpos
			ld hl, ntc_lb
			ld ix, ntc_ld_bpos
			jp ntc_lnegm
ntc_ld_bpos:
			ld hl, 0
			ld (ntc_lr), hl
			ld (ntc_lr+2), hl
			ld b, 32
ntc_ld_loop:
			ld hl, ntc_la
			sla (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			ld hl, ntc_lr
			rl (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			ld de, ntc_lr
			ld hl, ntc_lb
			ld a, (de)
			sub (hl)
			ld (ntc_lt), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ntc_lt+1), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ntc_lt+2), a
			inc hl
			inc de
			ld a, (de)
			sbc a, (hl)
			ld (ntc_lt+3), a
			jr c, ntc_ld_no
			ld hl, (ntc_lt)
			ld (ntc_lr), hl
			ld hl, (ntc_lt+2)
			ld (ntc_lr+2), hl
			ld hl, ntc_la
			set 0, (hl)
ntc_ld_no:
			djnz ntc_ld_loop
			ld a, (ntc_lcnt)
			or a
			jp p, ntc_ld_qpos
			ld hl, ntc_la
			ld ix, ntc_ld_qpos
			jp ntc_lnegm
ntc_ld_qpos:
			ld a, (ntc_lsgn)
			or a
			jp p, ntc_ld_out
			ld hl, ntc_lr
			ld ix, ntc_ld_out
			jp ntc_lnegm
ntc_ld_out:
			ld ix, (ntc_lix)
			jp (ix)

;## kw_l_mul ntc_lmul ntc_ldata
;kw_l_mul, <a>, <b>, <dest>  - a * b
kw_l_mul:
			pop hl
			ld de, ntc_la
			ldi
			ldi
			ldi
			ldi
			pop hl
			ld de, ntc_lb
			ldi
			ldi
			ldi
			ldi
			pop hl
			ld (ntc_ldst), hl
			ld ix, ntc_lmu_back
			jp ntc_lmul
ntc_lmu_back:
			ld hl, ntc_lr
; copy the 4 bytes at HL to (ntc_ldst), then next keyword
ntc_lstore:
			ld de, (ntc_ldst)
			ldi
			ldi
			ldi
			ldi
			ret

;## kw_l_div ntc_ldiv kw_l_mul
;kw_l_div, <a>, <b>, <dest>  - a \ b
kw_l_div:
			ld ix, ntc_ldv_back
ntc_ldv_go:
			pop hl
			ld de, ntc_la
			ldi
			ldi
			ldi
			ldi
			pop hl
			ld de, ntc_lb
			ldi
			ldi
			ldi
			ldi
			pop hl
			ld (ntc_ldst), hl
			jp ntc_ldiv
ntc_ldv_back:
			ld hl, ntc_la
			jp ntc_lstore

;## kw_l_mod kw_l_div
;kw_l_mod, <a>, <b>, <dest>  - a Mod b
kw_l_mod:
			ld ix, ntc_lmd_back
			jp ntc_ldv_go
ntc_lmd_back:
			ld hl, ntc_lr
			jp ntc_lstore

;## kw_l_pow ntc_lmul ntc_ldata kw_l_mul
;kw_l_pow, <base>, <exp>, <dest>  - Long ^ (low 32 bits; exp < 0 gives 0)
kw_l_pow:
			pop hl
			ld de, ntc_lt
			ldi
			ldi
			ldi
			ldi
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			inc hl
			ld a, (hl)
			pop hl
			ld (ntc_ldst), hl
			ld hl, 1
			ld (ntc_lr), hl
			ld hl, 0
			ld (ntc_lr+2), hl
			bit 7, a
			jr z, ntc_lpw_loop
			ld (ntc_lr), hl
			jr ntc_lpw_done
ntc_lpw_loop:
			ld a, d
			or e
			jr z, ntc_lpw_done
			ld (ntc_lpwe), de
			ld hl, ntc_lr
			ld de, ntc_la
			ld bc, 4
			ldir
			ld hl, ntc_lt
			ld de, ntc_lb
			ld bc, 4
			ldir
			ld ix, ntc_lpw_back
			jp ntc_lmul
ntc_lpw_back:
			ld de, (ntc_lpwe)
			dec de
			jr ntc_lpw_loop
ntc_lpw_done:
			ld hl, ntc_lr
			jp ntc_lstore
ntc_lpwe:		dw 0

;## ntc_ltoa ntc_ldata ntc_data
; Long at (HL) to text at DE, 0 at the end. jp (ix) back. Uses IY.
ntc_ltoa:
			ld (ntc_ldst), de
			ld de, ntc_la
			ldi
			ldi
			ldi
			ldi
			ld de, (ntc_ldst)
			ld a, (ntc_la+3)
			or a
			jp p, ntc_lta_pos
			ld a, '-'
			ld (de), a
			inc de
			ld hl, ntc_la
			xor a
			sub (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
ntc_lta_pos:
			xor a
			ld (ntc_lead), a
			ld iy, ntc_lpow10
ntc_lta_pow:
			ld a, (iy+0)
			or (iy+1)
			or (iy+2)
			or (iy+3)
			jr z, ntc_lta_last
			ld c, '0'
ntc_lta_sub:
			ld hl, ntc_la
			ld a, (hl)
			sub (iy+0)
			ld (ntc_lt), a
			inc hl
			ld a, (hl)
			sbc a, (iy+1)
			ld (ntc_lt+1), a
			inc hl
			ld a, (hl)
			sbc a, (iy+2)
			ld (ntc_lt+2), a
			inc hl
			ld a, (hl)
			sbc a, (iy+3)
			ld (ntc_lt+3), a
			jr c, ntc_lta_dig
			ld hl, (ntc_lt)
			ld (ntc_la), hl
			ld hl, (ntc_lt+2)
			ld (ntc_la+2), hl
			inc c
			jr ntc_lta_sub
ntc_lta_dig:
			ld a, c
			cp '0'
			jr nz, ntc_lta_out
			ld a, (ntc_lead)
			or a
			jr z, ntc_lta_skip
			ld a, c
ntc_lta_out:
			ld (de), a
			inc de
			ld a, 1
			ld (ntc_lead), a
ntc_lta_skip:
			ld bc, 4
			add iy, bc
			jr ntc_lta_pow
ntc_lta_last:
			ld a, (ntc_la)
			add a, '0'
			ld (de), a
			inc de
			xor a
			ld (de), a
			jp (ix)
ntc_lpow10:		dd 1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 0

;## kw_l_print ntc_ltoa ntc_printbuf
;kw_l_print, <long>  - print a Long
kw_l_print:
			pop hl
			ld de, ntc_numbuf
			ld ix, ntc_lpr_back
			jp ntc_ltoa
ntc_lpr_back:
			ld hl, ntc_numbuf
			ld (ntc_sptr), hl
			jp ntc_printbuf

;## kw_l_printvb ntc_ltoa ntc_printbuf
;kw_l_printvb, <long>  - Option VBPrint: a space (or the -), the digits, a space
kw_l_printvb:
			pop hl
			ld de, ntc_numbuf
			inc hl
			inc hl
			inc hl
			bit 7, (hl)
			dec hl
			dec hl
			dec hl
			jr nz, ntc_lpv_neg
			ld a, ' '
			ld (de), a
			inc de
ntc_lpv_neg:
			ld ix, ntc_lpv_done
			jp ntc_ltoa
ntc_lpv_done:
			ld a, ' '
			ld (de), a
			inc de
			xor a
			ld (de), a
			ld hl, ntc_numbuf
			ld (ntc_sptr), hl
			jp ntc_printbuf

;## kw_l_cstr ntc_ltoa
;kw_l_cstr, <dest>, <long>  - Long to text
kw_l_cstr:
			pop de
			pop hl
			ld ix, ntc_next
			jp ntc_ltoa

;## kw_l_str ntc_ltoa
;kw_l_str, <dest>, <long>  - Str$(Long): a space before 0 and positives
kw_l_str:
			pop de
			pop hl
			inc hl
			inc hl
			inc hl
			bit 7, (hl)
			dec hl
			dec hl
			dec hl
			jr nz, ntc_lst_go
			ld a, ' '
			ld (de), a
			inc de
ntc_lst_go:
			ld ix, ntc_next
			jp ntc_ltoa

;## kw_l_hex
;kw_l_hex, <dest>, <long>  - Hex$(Long): upper case, no leading zeros
kw_l_hex:
			pop de
			pop hl
			inc hl
			inc hl
			inc hl
			ld b, 8
			ld c, 0
ntc_lhx_loop:
			ld a, (hl)
			bit 0, b
			jr nz, ntc_lhx_lo
			rrca
			rrca
			rrca
			rrca
ntc_lhx_lo:
			and #0F
			jr nz, ntc_lhx_put
			inc c
			dec c
			jr nz, ntc_lhx_put
			ld a, b
			cp 1
			ld a, 0
			jr nz, ntc_lhx_next
ntc_lhx_put:
			ld c, 1
			cp 10
			jr c, ntc_lhx_dig
			add a, 7
ntc_lhx_dig:
			add a, '0'
			ld (de), a
			inc de
ntc_lhx_next:
			bit 0, b
			jr z, ntc_lhx_same
			dec hl
ntc_lhx_same:
			djnz ntc_lhx_loop
			xor a
			ld (de), a
			ret

;## kw_l_val ntc_ldata ntc_data
;kw_l_val, <src>, <destlong>  - Val() to a Long (decimal)
kw_l_val:
			pop hl
			pop de
			ld (ntc_ldst), de
ntc_lv_go:
			ld de, 0
			ld (ntc_la), de
			ld (ntc_la+2), de
ntc_lv_sp:
			ld a, (hl)
			cp ' '
			jr nz, ntc_lv_sg
			inc hl
			jr ntc_lv_sp
ntc_lv_sg:
			xor a
			ld (ntc_lsgn), a
			ld a, (hl)
			cp '-'
			jr nz, ntc_lv_dig
			ld a, 1
			ld (ntc_lsgn), a
			inc hl
ntc_lv_dig:
			ld a, (hl)
			sub '0'
			jr c, ntc_lv_done
			cp 10
			jr nc, ntc_lv_done
			ld (ntc_lcnt), a
			ld (ntc_aptr), hl
			ld hl, ntc_la
			sla (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			ld hl, (ntc_la)
			ld (ntc_lt), hl
			ld hl, (ntc_la+2)
			ld (ntc_lt+2), hl
			ld hl, ntc_la
			sla (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			ld hl, ntc_la
			sla (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			inc hl
			rl (hl)
			ld de, ntc_lt
			ld hl, ntc_la
			ld a, (de)
			add a, (hl)
			ld (hl), a
			inc de
			inc hl
			ld a, (de)
			adc a, (hl)
			ld (hl), a
			inc de
			inc hl
			ld a, (de)
			adc a, (hl)
			ld (hl), a
			inc de
			inc hl
			ld a, (de)
			adc a, (hl)
			ld (hl), a
			ld hl, ntc_la
			ld a, (ntc_lcnt)
			add a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			adc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			adc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			adc a, (hl)
			ld (hl), a
			ld hl, (ntc_aptr)
			inc hl
			jr ntc_lv_dig
ntc_lv_done:
			ld a, (ntc_lsgn)
			or a
			jr z, ntc_lv_st
			ld hl, ntc_la
			xor a
			sub (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
			inc hl
			ld a, 0
			sbc a, (hl)
			ld (hl), a
ntc_lv_st:
			ld hl, ntc_la
			ld de, (ntc_ldst)
			ldi
			ldi
			ldi
			ldi
			ret

;## kw_l_input ntc_gets kw_l_val
;kw_l_input, <destlong>  - Input to a Long
kw_l_input:
			pop hl
			ld (ntc_ldst), hl
			ld hl, ntc_inbuf
			ld de, ntc_lin_back
			jp ntc_gets
ntc_lin_back:
			ld hl, ntc_inbuf
			jp ntc_lv_go

;## kw_l_aget
;kw_l_aget, <arraybase>, <indexvar>, <dest>  - Long array element
kw_l_aget:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, hl
			add hl, de
			pop de
			ldi
			ldi
			ldi
			ldi
			ret

;## kw_l_aset
;kw_l_aset, <arraybase>, <indexvar>, <src>  - set a Long array element
kw_l_aset:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, hl
			add hl, de
			ex de, hl
			pop hl
			ldi
			ldi
			ldi
			ldi
			ret

;## ntc_font
; 8x8 font buffer, chars 32-126, 8 bytes each, bit 7 = leftmost pixel.
; The platform fills it at start: the CPC copies its own font from the
; lower ROM (#3900), so text looks like the CPC's.
; glyph for char c = ntc_font + (c - 32) * 8
ntc_font:		ds 95 * 8

; ============================================================
; Platform class capabilities
; ============================================================

;## ntc_capfind ntc_data
; ntc_capfind - the body of a class's Capability(name) keyword.
;   HL = the name asked for (0 ended), DE = the result's address,
;   BC = the class's table: name (capitals, 0 ended), dw value, ..., db 0.
; The name is matched without regard to case. Found: the value, Z set (true).
; Not found: 0, NZ. Runs on the thread: no call, no push.
ntc_capfind:
			ld (ntc_capres), de
			ld (ntc_capname), hl
ntc_cf_entry:
			ld a, (bc)
			or a
			jr z, ntc_cf_none
			ld hl, (ntc_capname)
ntc_cf_cmp:
			ld a, (hl)
			cp 'a'
			jr c, ntc_cf_up
			cp 'z' + 1
			jr nc, ntc_cf_up
			sub 32
ntc_cf_up:
			ld e, a
			ld a, (bc)
			cp e
			jr nz, ntc_cf_skip
			or a
			jr z, ntc_cf_found
			inc hl
			inc bc
			jr ntc_cf_cmp
ntc_cf_skip:
			ld a, (bc)			; the rest of this name, its 0 and its value
			inc bc
			or a
			jr nz, ntc_cf_skip
			inc bc
			inc bc
			jr ntc_cf_entry
ntc_cf_found:
			inc bc
			ld a, (bc)
			ld e, a
			inc bc
			ld a, (bc)
			ld d, a
			ld hl, (ntc_capres)
			ld (hl), e
			inc hl
			ld (hl), d
			xor a				; Z: found
			ret
ntc_cf_none:
			ld hl, (ntc_capres)
			ld (hl), a
			inc hl
			ld (hl), a
			inc a				; NZ: not found
			ret
ntc_capres:		dw 0
ntc_capname:	dw 0

;## ntc_buf2k
; ntc_buf - a 2K buffer shared by the classes that need one: FileSystem's
; CAS IN / OUT OPEN buffer (CPC firmware) and Memory.Copy's page to page copy
ntc_buf:		ds 2048

;## ntc_memcore ntc_data ntc_mem ntc_memcore2 ntc_plat_memtop @shared
; ------------------------------------------------------------
; ntc_memcore - the Memory class, the part every scheme shares. The scheme
; (Option Memory, else the platform's default) is the section ntc_mem -
; only the one chosen is in the library (@if:): CPCExpansion (16K pages
; through the #4000 window, up to 4MB) or Small (main RAM only, no paging).
; Each class method jumps to mem_go with HL = the routine: mem_go runs it
; on the real stack (call / push are fine there), interrupts on in normal
; mode (off in turbo), and stores its HL result at mem_res (mem_go4: a Long, high
; word in mem_hi; mem_go0: no store - the routine writes the result
; itself, or there is none). A routine that fails jumps to mem_err with
; HL = the status; mem_err puts back the page that was in the window
; and unwinds to mem_go.
; Far pointer = a Long: address, page (page 0 = plain memory).
; Heap: blocks from mem_hlo to mem_hhi (a D page, or Small's main RAM),
; each with a 2 byte header: length including the header (bits 0-14),
; bit 15 = in use. Free blocks are at most #4000 (joins stop there).
; The scheme supplies: mem_start (the first call), mem_sel (HL = page
; into the window), mem_chk (HL = a page number, else BadPage).
; ------------------------------------------------------------
MEM_WIN		equ #4000
MEM_BADPAGE	equ -2

mem_a1:			dw 0
mem_a2:			dw 0
mem_a3:			dw 0
mem_res:		dw 0
mem_hi:			dw 0
mem_sp:			dw 0
mem_esp:		dw 0
mem_six:		dw 0
mem_siy:		dw 0
mem_need:		dw 0
mem_max:		dw 0
mem_srca:		dw 0
mem_dsta:		dw 0
mem_srcp:		dw 0
mem_dstp:		dw 0
mem_left:		dw 0
mem_chunk:		dw 0
mem_cur:		dw 1			; the page in the window
mem_keep:		dw 1			; the page to put back
mem_hlo:		dw MEM_WIN		; the heap region mem_fit / mem_big work in
mem_hhi:		dw #8000
mem_store:		db 0
mem_init:		db 0			; 1 = the first call has been

; mem_go / mem_go4 / mem_go0 - HL = the routine (see above)
mem_go0:
			xor a
			jr mem_gostart
mem_go4:
			ld a, 4
			jr mem_gostart
mem_go:
			ld a, 2
mem_gostart:
			ld (mem_store), a
			ld (mem_sp), sp
			ld sp, (ntc_csp)
			ld (mem_six), ix
			ld (mem_siy), iy
			ld de, 0
			ld (mem_hi), de
			push hl
			call mem_start
			pop hl
			ld de, (mem_cur)
			ld (mem_keep), de
			ld a, (ntc_nmode)		; normal mode: interrupts in during the call (Ticks keep
			or a					; counting through a long Sort or Copy); turbo: off
			jr z, mem_gocall
			ei
mem_gocall:
			ld (mem_esp), sp
			call mem_jphl
mem_back:
			di
			ld ix, (mem_six)
			ld iy, (mem_siy)
			ld a, (mem_store)
			or a
			jr z, mem_gone
			ex de, hl
			ld hl, (mem_res)
			ld (hl), e
			inc hl
			ld (hl), d
			cp 4
			jr nz, mem_gone
			ld de, (mem_hi)
			inc hl
			ld (hl), e
			inc hl
			ld (hl), d
mem_gone:
			ld sp, (mem_sp)
			ret
mem_jphl:
			jp (hl)
mem_err:
			ld sp, (mem_esp)
			push hl
			ld hl, (mem_keep)
			call mem_sel
			pop hl
			ld de, 0
			ld (mem_hi), de
			jr mem_back

mem_chk_bad:
			ld hl, MEM_BADPAGE
			jp mem_err

;## ntc_memcore2 ntc_memcore @shared @far
; ntc_memcore2 - the rest of the shared part: far pointers, the heap, bytes
; and words. Runs on the real stack (through mem_go), so a keyword ROM set
; can place it in another ROM of the set (@far).

; mem_far - HL = a far pointer's address (Long: address, page): DE = the
; address, HL = the page (0 = plain memory). Page not 0: it must be a page
; this machine has and the address in the window, else mem_err BadPage.
mem_far:
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			or h
			ret z
			call mem_chk
			ld a, d
			and #C0
			cp #40
			jr nz, mem_chk_bad
			ret

; PageOf(ptr): a far pointer's page
mem_pageof:
			ld hl, (mem_a1)
			inc hl
			inc hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ret

; Address(ptr): its page into the window (page 0: nothing); the address
mem_address:
			ld hl, (mem_a1)
			call mem_far
			ld a, h
			or l
			call nz, mem_sel
			ex de, hl
			ret

; HeapStart(), HeapEnd(): the heap region (CPCExpansion: the window, a D page at a time)
mem_heapstart:
			ld hl, (mem_hlo)
			ret
mem_heapend:
			ld hl, (mem_hhi)
			ret
; ProgramStart(), ProgramEnd() (the first byte after the program and its
; arrays), Top() (the platform's top of free RAM), StackTop() (the real stack)
mem_progstart:
			ld hl, ntc_start
			ret
mem_progend:
			ld hl, ntc_free
			ret
mem_top:
			jp ntc_plat_memtop
mem_stacktop:
			ld hl, (ntc_csp)
			ret

; mem_atend - Z when HL = mem_hhi (the heap region's end). Keeps BC, DE, HL.
mem_atend:
			ld a, (mem_hhi)
			cp l
			ret nz
			ld a, (mem_hhi + 1)
			cp h
			ret
; mem_cap - HL = two joined blocks' length: NC = too long (over #4000), C = fine
mem_cap:
			ld a, h
			cp #40
			ret c
			scf
			ccf
			ret nz
			ld a, l
			cp 1					; #4000 exactly: C
			ret

; mem_fit - in the heap region (mem_hlo .. mem_hhi: a D page, or Small's main RAM): the first free block of mem_need
; bytes or more (free neighbours joined on the way), split when 4 or more
; bytes are left over, marked in use. Z: HL = its data. NZ: none.
mem_fit:
			ld hl, (mem_hlo)
mem_f_lp:
			call mem_atend
			jr z, mem_f_none
			ld e, (hl)
			inc hl
			ld d, (hl)
			dec hl
			bit 7, d
			jr z, mem_f_free
			res 7, d
mem_f_next:
			add hl, de
			jr mem_f_lp
mem_f_free:
			push hl
			add hl, de				; the block after
			call mem_atend
			jr z, mem_f_last
			ld c, (hl)
			inc hl
			ld b, (hl)
			bit 7, b
			jr nz, mem_f_last
			ld h, d					; free too: join them, up to #4000
			ld l, e
			add hl, bc
			call mem_cap
			jr nc, mem_f_last
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			dec hl
			jr mem_f_free
mem_f_last:
			pop hl
			push hl
			ex de, hl				; HL = its length, DE = the block
			ld bc, (mem_need)
			or a
			sbc hl, bc				; what is left over
			jr c, mem_f_small
			ld a, h
			or a
			jr nz, mem_f_cut
			ld a, l
			cp 4
			jr nc, mem_f_cut
			add hl, bc				; all of it
			ld b, h
			ld c, l
			pop hl
			jr mem_f_take
mem_f_cut:
			ex de, hl				; DE = left over, HL = the block
			pop hl
			push hl
			add hl, bc				; the free block after it
			ld (hl), e
			inc hl
			ld (hl), d
			pop hl
mem_f_take:
			ld (hl), c
			inc hl
			ld a, b
			or #80
			ld (hl), a
			inc hl
			xor a
			ret
mem_f_small:
			add hl, bc				; HL = its length again
			ex de, hl
			pop hl
			jr mem_f_next
mem_f_none:
			or 1					; NZ
			ret

; mem_big - in the heap region: join free neighbours, mem_max =
; the biggest free block's length if bigger
mem_big:
			ld hl, (mem_hlo)
mem_b_lp:
			call mem_atend
			ret z
			ld e, (hl)
			inc hl
			ld d, (hl)
			dec hl
			bit 7, d
			jr z, mem_b_free
			res 7, d
mem_b_next:
			add hl, de
			jr mem_b_lp
mem_b_free:
			push hl
			add hl, de
			call mem_atend
			jr z, mem_b_end
			ld c, (hl)
			inc hl
			ld b, (hl)
			bit 7, b
			jr nz, mem_b_end
			ld h, d
			ld l, e
			add hl, bc
			call mem_cap
			jr nc, mem_b_end
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			dec hl
			jr mem_b_free
mem_b_end:
			pop hl
			push hl
			ld hl, (mem_max)
			or a
			sbc hl, de
			pop hl
			jr nc, mem_b_next
			ld (mem_max), de
			jr mem_b_next

; ---- single bytes and words through far pointers (the window is put back)

; mem_at - mem_a1 = a far pointer's address: its page in, HL = the address
mem_at:
			ld hl, (mem_a1)
			call mem_far
			ld a, h
			or l
			call nz, mem_sel
			ex de, hl
			ret

mem_readbyte:
			call mem_at
			ld l, (hl)
			ld h, 0
			jr mem_putback
mem_readword:
			call mem_at
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jr mem_putback
mem_writebyte:
			call mem_at
			ld a, (mem_a2)
			ld (hl), a
			jr mem_putback
mem_writeword:
			call mem_at
			ld de, (mem_a2)
			ld (hl), e
			inc hl
			ld (hl), d
mem_putback:
			push hl
			ld hl, (mem_keep)
			call mem_sel
			pop hl
			ret

;## ntc_mem ntc_memcore ntc_membank @shared @far @if:ntc_mem_cpcexpansion
; ------------------------------------------------------------
; ntc_mem (CPCExpansion) - 16K RAM pages in the #4000-#7FFF window (CPC gate
; array RAM setting: C0 = plain, C4-C7 + bank * 8 = page 0-3 of a 64K bank;
; the port's high byte #7F .. #78 picks the 512K block), up to a 4MB
; expansion: 64 banks, 257 pages (NTC_MEMBANKS: Option Memory's limit).
;   Page 1  = main RAM #4000-#7FFF (setting #C0)
;   Page 2+ = 4 pages for each bank the probe finds, the standard 512K
;             (port #7F) first, then the blocks on #7E .. #78
;   Page numbers are 16 bit (a far pointer's high word); 0 = plain memory.
;   No pages at all when the program (ntc_start .. ntc_free) or the
;   real stack is in the window: switching would hide them.
; Tables, made by the first call (mem_start) from ntc_free up, sized to
; what the probe finds (3 bytes a page); fewer pages when there isn't room
; below #4000 (or below the real stack):
;   the port table - 2 bytes a page: the BC that selects it (out (c), c),
;                    so selecting a page is a look-up, nothing worked out
;   the RAT        - 1 byte a page, its type: - free, C, D, I, U, B (the 4
;                    pages of a whole bank, AllocBank)
; No lists: a free page or bank is found by scanning the RAT (CPIR), a page
; is freed by writing - back. C / I / U pages come from the low block first
; (main + the #7F block), D pages from the high one (#78-#7E); each falls
; back to the other. On 576K or less every page is low.
; The page in the window is kept in mem_cur, written before the port,
; so an interrupt handler can always put the right page back.
; A new D page is one free block of #4000.
; ------------------------------------------------------------
MEM_BANKS	equ NTC_MEMBANKS	; 0 - 64
MEM_LB		equ 6			; the whole-bank kind (mem_kinds)

mem_count:		dw 0			; pages (0 = no paging)
mem_tport:		dw 0			; the port table (2 bytes a page: its BC)
mem_ttype:		dw 0			; the RAT (1 byte a page: its type)
mem_tend:		dw 0			; the first byte after them
mem_fp:			dw 0			; (making the port table: the next bank found)
mem_banks:		db 0			; 64K banks found
mem_tl:			db 0
mem_sw:			db 0			; mem_scan: 0 low, 1 high, 2 any
mem_kinds:		db "--CDIUB"		; the type character of each kind (0, 1 free)
mem_found:		ds MEM_BANKS + 1	; probe: the banks found (0-63), in order
mem_save:		ds MEM_BANKS + 1	; probe: the bytes the markers replace
mem_bksp:		dw 0			; CallBank: the real stack while bank code runs
mem_bkrmr:		db 0			; and the ROM / mode byte to put back

; mem_start - the first call: can this program page, what is fitted, the tables
mem_start:
			ld a, (mem_init)
			or a
			ret nz
			inc a
			ld (mem_init), a
			ld hl, ntc_free
			ld (mem_tend), hl
	IF NTC_WINHOLE
			jr mem_st_prog			; the program is built round the window (Option Reserve)
	ENDIF
	IF NTC_ROMLIB					; the keyword ROM: free RAM from #8000 on = built round it
			ld a, h
			cp #80
			jr nc, mem_st_prog
	ENDIF
			ld de, MEM_WIN + 1		; the program must be out of the window:
			or a					; it ends by #4000 ...
			sbc hl, de
			jr c, mem_st_prog
			ld hl, ntc_start		; ... or starts at #8000 or above
			ld de, #8000
			or a
			sbc hl, de
			ret c
mem_st_prog:
			ld hl, (ntc_csp)		; and the real stack too: at or below #4000,
			ld de, MEM_WIN + 1		; or 64 bytes or more above #8000
			or a
			sbc hl, de
			jr c, mem_probe
			ld hl, (ntc_csp)
			ld de, #8040
			or a
			sbc hl, de
			ret c
; the probe: interrupts off, nothing written until every byte is saved.
; Markers go in bank 63 down to bank 0, then main RAM, so a bank the
; hardware doesn't decode (a 6128 has one bank, a 512K expansion ignores
; the port's block bits) reads back a lower bank's marker, and a 64K
; machine (C4-C7 do nothing) reads main RAM's.
mem_probe:
		IF MEM_BANKS > 0
			ld a, i					; P/V = interrupts were on
			di
			push af
			ld bc, #7FC0
			out (c), c
			ld a, (MEM_WIN)
			ld (mem_save + MEM_BANKS), a
			ld hl, mem_save
			ld e, 0
mem_pr_save:
			call mem_jbc
			out (c), c
			ld a, (MEM_WIN)
			ld (hl), a
			inc hl
			inc e
			ld a, e
			cp MEM_BANKS
			jr nz, mem_pr_save
			ld e, MEM_BANKS
mem_pr_mark:
			dec e
			call mem_jbc
			out (c), c
			ld a, e
			add a, #40
			ld (MEM_WIN), a
			ld a, e
			or a
			jr nz, mem_pr_mark
			ld bc, #7FC0
			out (c), c
			ld a, #A5
			ld (MEM_WIN), a
			ld hl, mem_found
			ld d, 0
			ld e, 0
mem_pr_read:
			call mem_jbc
			out (c), c
			ld a, e
			add a, #40
			push hl
			ld hl, MEM_WIN
			cp (hl)
			pop hl
			jr nz, mem_pr_none
			ld (hl), e				; this bank is there
			inc hl
			inc d
mem_pr_none:
			inc e
			ld a, e
			cp MEM_BANKS
			jr nz, mem_pr_read
			ld hl, mem_save + MEM_BANKS	; put the bytes back, bank 63 down to 0
			ld e, MEM_BANKS
mem_pr_back:
			dec e
			dec hl
			call mem_jbc
			out (c), c
			ld a, (hl)
			ld (MEM_WIN), a
			ld a, e
			or a
			jr nz, mem_pr_back
			ld bc, #7FC0
			out (c), c
			ld a, (mem_save + MEM_BANKS)
			ld (MEM_WIN), a
			ld a, d
			ld (mem_banks), a
			pop af
			jp po, mem_pr_di
			ei
mem_pr_di:
		ENDIF
			ld a, (mem_banks)		; pages = 1 + 4 a bank
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			inc hl
			ld (mem_count), hl
	IF NTC_WINHOLE
			call ntc_plat_memtop		; built round the window: the tables go above it
			jr mem_tb_lim			; (ntc_memtab), up to the platform's top
	ENDIF
	IF NTC_ROMLIB					; the keyword ROM: a program built round the window (it has no
			ld hl, ntc_free			; NTC_WINHOLE here) has its free RAM above it - up to the top
			ld a, h
			cp #80
			jr c, mem_tb_low
			call ntc_plat_memtop
			jr mem_tb_lim
mem_tb_low:
	ENDIF
			ld de, (ntc_csp)		; the tables must end by #4000, or 128 bytes
			ld hl, MEM_WIN			; under the real stack when it is lower
			or a
			sbc hl, de
			ld hl, MEM_WIN
			jr c, mem_tb_lim
			ld hl, -128
			add hl, de
mem_tb_lim:
			ld (mem_tend), hl		; the limit, for now
mem_tb_fit:
			ld hl, (mem_count)
			ld a, h
			or l
			jr z, mem_tb_none
			ld d, h
			ld e, l
			add hl, hl
			add hl, de				; 3 bytes a page
	IF NTC_WINHOLE
			ld de, ntc_memtab
	ELSE
			ld de, ntc_free
	ENDIF
			add hl, de
			ex de, hl				; DE = their end
			ld hl, (mem_tend)
			or a
			sbc hl, de
			jr nc, mem_tb_ok
			ld hl, (mem_count)		; no room: one page fewer
			dec hl
			ld (mem_count), hl
			jr mem_tb_fit
mem_tb_none:
	IF NTC_WINHOLE
			ld hl, ntc_memtab
	ELSE
			ld hl, ntc_free
	ENDIF
			ld (mem_tend), hl
			ret
mem_tb_ok:
			ld (mem_tend), de
	IF NTC_WINHOLE
			ld hl, ntc_memtab
	ELSE
			ld hl, ntc_free
	ENDIF
			ld (mem_tport), hl
			ld de, (mem_count)
			add hl, de
			add hl, de
			ld (mem_ttype), hl
			ld bc, (mem_count)		; the RAT: every page free
			ld (hl), '-'
			dec bc
			ld a, b
			or c
			jr z, mem_tb_ports
			ld d, h
			ld e, l
			inc de
			ldir
mem_tb_ports:						; the port table: page 1 main RAM, then 4 a bank found
			ld hl, (mem_tport)
			ld (hl), #C0
			inc hl
			ld (hl), #7F
			inc hl
			ld de, (mem_count)
			dec de					; DE = pages left
			ld bc, mem_found
			ld (mem_fp), bc
mem_tb_bk:
			ld a, d
			or e
			ret z
			push de
			ld bc, (mem_fp)
			ld a, (bc)
			inc bc
			ld (mem_fp), bc
			ld e, a
			call mem_jbc			; BC = its page 0's port (keeps DE, HL)
			pop de
			ld a, 4
mem_tb_pg:
			ld (hl), c
			inc hl
			ld (hl), b
			inc hl
			inc c
			dec de
			push af
			ld a, d
			or e
			jr z, mem_tb_pend		; (fewer pages than found: the rest left out)
			pop af
			dec a
			jr nz, mem_tb_pg
			jr mem_tb_bk
mem_tb_pend:
			pop af
			ret

; mem_jbc - E = bank 0-63: BC = the port for its page 0 (B = #7F - E / 8,
; C = #C4 + (E and 7) * 8). Keeps DE, HL.
mem_jbc:
			ld a, e
			rrca
			rrca
			rrca
			and 7
			ld b, a
			ld a, #7F
			sub b
			ld b, a
			ld a, e
			and 7
			add a, a
			add a, a
			add a, a
			add a, #C4
			ld c, a
			ret

; mem_sel - HL = page (valid): into the window. mem_cur first, then the
; port; nothing done when it is in already. Keeps BC, DE, HL.
mem_sel:
			push hl
			push de
			push bc
			ld de, (mem_cur)
			ld a, e
			cp l
			jr nz, mem_se_do
			ld a, d
			cp h
			jr z, mem_se_end
mem_se_do:
			ld (mem_cur), hl
			ld a, h
			or l
			ld bc, #7FC0			; (0: plain RAM)
			jr z, mem_se_out
			add hl, hl				; its port from the port table
			ld de, (mem_tport)
			add hl, de
			dec hl
			ld b, (hl)
			dec hl
			ld c, (hl)
mem_se_out:
			ld (ntc_rampt), bc
			out (c), c
mem_se_end:
			pop bc
			pop de
			pop hl
			ret

; mem_chk - HL = a page number: 1 .. mem_count, else mem_err BadPage.
; Keeps BC, DE, HL.
mem_chk:
			ld a, h
			or l
			jp z, mem_chk_bad
			push de
			push hl
			ex de, hl
			ld hl, (mem_count)
			or a
			sbc hl, de
			pop hl
			pop de
			ret nc
			jp mem_chk_bad
; ---- the tables (BC = a page)

; mem_tpb - HL = its type byte (in the RAT). Keeps A, BC, DE.
mem_tpb:
			ld hl, (mem_ttype)
			add hl, bc
			dec hl
			ret
; mem_push - A = a kind (mem_kinds: 2-6): the page is of that kind now. Keeps A, BC, DE.
mem_push:
			push af
			push de
			ld e, a
			ld d, 0
			ld hl, mem_kinds
			add hl, de
			ld a, (hl)
			call mem_tpb
			ld (hl), a
			pop de
			pop af
			ret
; mem_remove - (A = a kind) nothing to take it off: the RAT has no lists. NZ. Keeps BC, DE.
mem_remove:
			ld a, 1
			or a
			ret
; mem_lowhigh - A = the block the page is in: 0 low (main, or the #7F
; block) or 1 high. Keeps BC, DE.
mem_lowhigh:
			push de
			ld h, b
			ld l, c
			add hl, hl
			ld de, (mem_tport)
			add hl, de
			dec hl					; its port's high byte
			ld a, (hl)
			pop de
			cp #7F
			ld a, 0
			ret z
			inc a
			ret
; mem_tofree - the page free again. Keeps BC, DE.
mem_tofree:
			call mem_tpb
			ld (hl), '-'
			ret
; mem_scan - A = 0 low, 1 high, 2 either: BC = the first free page in it, NZ;
; Z = none
mem_scan:
			ld (mem_sw), a
			ld hl, (mem_ttype)
			ld bc, (mem_count)
mem_sc_lp:
			ld a, b
			or c
			ret z
			ld a, '-'
			cpir
			jr nz, mem_sc_none
			push bc
			push hl
			ld de, (mem_ttype)
			or a
			sbc hl, de				; the page: its entry is at HL - 1
			ld b, h
			ld c, l
			ld a, (mem_sw)
			cp 2
			jr z, mem_sc_hit
			call mem_lowhigh
			ld hl, mem_sw
			cp (hl)
			jr z, mem_sc_hit
			pop hl
			pop bc
			jr mem_sc_lp
mem_sc_hit:
			pop af
			pop af
			ld a, 1
			or a
			ret
mem_sc_none:
			xor a
			ret
; mem_dnext - BC = a page (0: before the first): BC = the next D page, NZ;
; Z = none
mem_dnext:
			ld hl, (mem_count)
			or a
			sbc hl, bc
			ret z
			push hl
			ld hl, (mem_ttype)
			add hl, bc
			pop bc
			ld a, 'D'
			cpir
			jr nz, mem_sc_none
			ld de, (mem_ttype)
			or a
			sbc hl, de
			ld b, h
			ld c, l
			ld a, 1
			or a
			ret
; mem_listof - A = the page's kind (2-6), or its free block (0, 1). Keeps BC, DE.
mem_listof:
			call mem_tpb
			ld a, (hl)
			push bc
			ld hl, mem_kinds + 2
			ld b, 5
			ld c, 2
mem_lo_lp:
			cp (hl)
			jr z, mem_lo_got
			inc hl
			inc c
			djnz mem_lo_lp
			pop bc
			jp mem_lowhigh
mem_lo_got:
			ld a, c
			pop bc
			ret
; mem_kindlist - A = a type character: A = its kind (2-5), NZ; Z = not one.
mem_kindlist:
			ld hl, mem_kinds + 2
			ld b, 4
			ld c, 2
mem_kl_lp:
			cp (hl)
			jr z, mem_kl_got
			inc hl
			inc c
			djnz mem_kl_lp
			xor a
			ret
mem_kl_got:
			ld a, c
			or a
			ret
; mem_take - A = a kind (2-5): a free page of that kind now - D from the
; high block first, the others from the low one - a D page made one free
; block. BC = the page, NZ; Z = none left.
mem_take:
			ld (mem_tl), a
			cp 3
			ld a, 1
			jr z, mem_tk_s
			xor a
mem_tk_s:
			call mem_scan
			jr nz, mem_tk_got
			ld a, 2
			call mem_scan
			ret z
mem_tk_got:
			ld a, (mem_tl)
			call mem_push
			cp 3
			jr nz, mem_tk_done
			ld h, b
			ld l, c
			call mem_sel
			ld hl, #4000
			ld (MEM_WIN), hl
			ld hl, (mem_keep)
			call mem_sel
mem_tk_done:
			ld a, 1
			or a
			ret

; ---- what's there

; Pages(): pages (0 = no paging, 1 = 64K, 5 = 128K ... 33 = 512K ... 257 = 4MB)
mem_pages:
			ld hl, (mem_count)
			ret

; FreePages(): the free pages (- in the RAT)
mem_freepages:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			ld b, h
			ld c, l
			ld hl, (mem_ttype)
			ld de, 0
mem_fp_lp:
			ld a, '-'
			cpir
			jr nz, mem_fp_end
			inc de
			ld a, b
			or c
			jr nz, mem_fp_lp
mem_fp_end:
			ex de, hl
			ret

; RamSize(): K of RAM the probe found (64 + 64 a bank), 0 = not probed
mem_ramsize:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			ld a, (mem_banks)
			ld l, a
			ld h, 0
			inc hl
			add hl, hl				; x 64
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			ret

; Model(): 0 none, 1 small (1 page), 2 medium (up to 5), 3 large (up to
; 33, a 512K expansion), 4 huge (more)
mem_model:
			ld de, (mem_count)
			ld hl, 0
			ld a, d
			or a
			jr nz, mem_md_huge
			ld a, e
			or a
			ret z
			inc l
			cp 2
			ret c
			inc l
			cp 6
			ret c
			inc l
			cp 34
			ret c
mem_md_huge:
			ld l, 4
			ret

; TableEnd(): the first byte after Memory's tables (they start at the program's end)
mem_tableend:
			ld hl, (mem_tend)
			ret

; PageType(page): its type character
mem_pagetype:
			ld hl, (mem_a1)
			call mem_chk
			ld b, h
			ld c, l
			call mem_tpb
			ld l, (hl)
			ld h, 0
			ret

; Map(first, count): one character per page from first, into the string
; result (as many as fit; pages past the last are left out)
mem_map:
			ld hl, (mem_res)
			dec hl
			ld a, (hl)				; the string's capacity
			inc hl
			ld (mem_srca), hl
			ld (mem_chunk), a
			ld bc, (mem_a1)
			ld hl, (mem_a2)
			ld (mem_left), hl
mem_mp_lp:
			ld hl, (mem_left)
			bit 7, h
			jr nz, mem_mp_end
			ld a, h
			or l
			jr z, mem_mp_end
			ld a, b
			or c
			jr z, mem_mp_end
			ld hl, (mem_count)
			or a
			sbc hl, bc
			jr c, mem_mp_end
			ld a, (mem_chunk)
			or a
			jr z, mem_mp_end
			dec a
			ld (mem_chunk), a
			call mem_tpb
			ld a, (hl)
			ld hl, (mem_srca)
			ld (hl), a
			inc hl
			ld (mem_srca), hl
			inc bc
			ld hl, (mem_left)
			dec hl
			ld (mem_left), hl
			jr mem_mp_lp
mem_mp_end:
			ld hl, (mem_srca)
			ld (hl), 0
			ret

; ---- whole pages

; AllocPage(kind): a free page, now of that kind (C, D, I, U); 0 = none left
mem_allocpage:
			ld hl, (mem_count)
			ld a, h
			or l
			jr z, mem_ap_none
			ld hl, (mem_a1)
			ld a, h
			or a
			jr nz, mem_ap_none
			ld a, l
			call mem_kindlist
			jr z, mem_ap_none
			call mem_take
			jr z, mem_ap_none
			ld h, b
			ld l, c
			ret
mem_ap_none:
			ld hl, 0
			ret

; FreePage(page): back to free (a D page's blocks go with it). OK, or
; BadPage (not a page, or free already)
mem_freepage:
			ld hl, (mem_a1)
			call mem_chk
			ld b, h
			ld c, l
			call mem_listof
			cp 2
			jp c, mem_chk_bad
			call mem_remove
			call mem_tofree
			ld hl, 0
			ret

; SelectPage(page): into the window; #4000
mem_selpage:
			ld hl, (mem_a1)
			call mem_chk
			call mem_sel
			ld hl, MEM_WIN
			ret

; CurrentPage(): the page in the window (0 = no paging)
mem_curpage:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			ld hl, (mem_cur)
			ret

; ---- whole 64K banks (page numbers 4 * bank - 2 .. 4 * bank + 1)

; Banks(): whole banks the tables cover (0 = none)
mem_bankcount:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			dec hl
			srl h
			rr l
			srl h
			rr l
			ret

; mem_bkfirst - (mem_a1) = a bank, 1 .. Banks(): BC = its first page, else
; mem_err BadPage
mem_bkfirst:
			call mem_bankcount
			ld de, (mem_a1)
			ld a, d
			or e
			jp z, mem_chk_bad
			or a
			sbc hl, de
			jp c, mem_chk_bad
			ex de, hl
			dec hl
			add hl, hl
			add hl, hl
			inc hl
			inc hl
			ld b, h
			ld c, l
			ret

; AllocBank(): a bank whose 4 pages are all free, now type B; 0 = none
mem_allocbank:
			call mem_bankcount
			ld a, l
			or a
			jr z, mem_ab_none
			ld (mem_tl), a			; banks left to try
			ld bc, 2
mem_ab_lp:
			push bc
			ld d, 4
mem_ab_chk:
			call mem_listof
			cp 2
			jr nc, mem_ab_used
			inc bc
			dec d
			jr nz, mem_ab_chk
			pop bc					; all 4 free: onto the bank list
			push bc
			ld d, 4
mem_ab_take:
			call mem_listof
			call mem_remove
			ld a, MEM_LB
			call mem_push
			inc bc
			dec d
			jr nz, mem_ab_take
			pop hl					; bank = (first page + 2) / 4
			inc hl
			inc hl
			srl h
			rr l
			srl h
			rr l
			ret
mem_ab_used:
			pop bc
			ld hl, 4
			add hl, bc
			ld b, h
			ld c, l
			ld a, (mem_tl)
			dec a
			ld (mem_tl), a
			jr nz, mem_ab_lp
mem_ab_none:
			ld hl, 0
			ret

; FreeBank(bank): its 4 pages back to free. OK, or BadPage (not a bank,
; or not taken with AllocBank)
mem_bkstub:
			ld hl, ntc_bk_stub
			ret

mem_freebank:
			call mem_bkfirst
			push bc
			ld d, 4
mem_fb_chk:
			call mem_listof
			cp MEM_LB
			jp nz, mem_chk_bad
			inc bc
			dec d
			jr nz, mem_fb_chk
			pop bc
			ld d, 4
mem_fb_lp:
			ld a, MEM_LB
			call mem_remove
			call mem_tofree
			inc bc
			dec d
			jr nz, mem_fb_lp
			ld hl, 0
			ret

; CallBank(bank, address, value): runs the bank's code at address with the
; whole 64K being that bank (RAM setting C2), HL = value; its HL comes back.
; The bank must be taken (AllocBank). The switch code (ntc_bk_stub, about
; 20 bytes) is copied into the bank at its own address first, so those
; bytes of the bank are overwritten. Interrupts are off and both ROMs are
; off while the bank code runs; it starts with the stack at the bank's top
; (#FFFF down) and ends with ret. It must keep the alternate registers.
mem_callbank:
			call mem_bkfirst
			call mem_listof
			cp MEM_LB
			jp nz, mem_chk_bad
			ld hl, ntc_bk_stub		; copy the switch code into the bank
mem_cb_cp:
			push bc
			ld a, h					; its page in the bank: address / #4000
			rlca
			rlca
			and 3
			add a, c
			ld c, a
			jr nc, mem_cb_nc
			inc b
mem_cb_nc:
			push hl
			ld h, b
			ld l, c
			call mem_sel
			pop hl
			ld b, (hl)
			ld a, h
			and #3F
			or #40
			ld d, a
			ld e, l
			ld a, b
			ld (de), a
			pop bc
			inc hl
			ld a, l
			cp low ntc_bk_end
			jr nz, mem_cb_cp
			ld a, h
			cp high ntc_bk_end
			jr nz, mem_cb_cp
			ld hl, (mem_keep)
			call mem_sel
			call mem_bkfirst		; BC = C2 for the bank: its page 0's port
			ld h, b					; ((#C4 + bank bits) and #F8, or 2)
			ld l, c
			add hl, hl
			ld de, (mem_tport)
			add hl, de
			dec hl
			ld b, (hl)
			dec hl
			ld a, (hl)
			and #F8
			or 2
			ld c, a
			ld de, (mem_a2)
			ld hl, (mem_a3)
			jp ntc_bk_go

; ---- heap in D pages

; Alloc(size): a far pointer to size bytes in a D page, 0 = no room.
; Tries the page in the window, then the other D pages, then takes a free
; page. The window is left as it was.
mem_alloc:
			ld hl, (mem_count)
			ld a, h
			or l
			jr z, mem_al_fail
			ld hl, (mem_a1)
			ld a, h
			or l
			jr nz, mem_al_size
			inc hl
mem_al_size:
			ld de, #3FFF			; up to #3FFE: a page less its header
			or a
			push hl
			sbc hl, de
			pop hl
			jr nc, mem_al_fail
			inc hl
			inc hl
			ld (mem_need), hl
			ld bc, (mem_keep)
			call mem_tpb
			ld a, (hl)
			cp 'D'
			jr nz, mem_al_scan
			ld h, b
			ld l, c
			call mem_try
			jr z, mem_al_got
mem_al_scan:
			ld bc, 0
mem_al_lp:
			call mem_dnext
			jr z, mem_al_new
			ld hl, (mem_keep)
			or a
			sbc hl, bc
			jr z, mem_al_lp
			push bc
			ld h, b
			ld l, c
			call mem_try
			pop bc
			jr z, mem_al_got
			jr mem_al_lp
mem_al_new:
			ld a, 3
			call mem_take
			jr z, mem_al_back
			ld h, b
			ld l, c
			call mem_try
mem_al_got:
			ld de, (mem_cur)		; HL = the data, its page is in
			ld (mem_hi), de
			push hl
			ld hl, (mem_keep)
			call mem_sel
			pop hl
			ret
mem_al_back:
			ld hl, (mem_keep)
			call mem_sel
mem_al_fail:
			ld hl, 0
			ld (mem_hi), hl
			ret

; mem_try - HL = a D page: select it, then mem_fit
mem_try:
			call mem_sel
			jp mem_fit

; Free(ptr): a block Alloc gave back. A page with nothing left in use
; goes back to free. OK, or BadPage (not a block in use in a D page)
mem_free:
			ld hl, (mem_a1)
			call mem_far
			ld a, h
			or l
			jp z, mem_chk_bad
			ld b, h
			ld c, l
			call mem_tpb
			ld a, (hl)
			cp 'D'
			jp nz, mem_chk_bad
			ld h, b
			ld l, c
			call mem_sel
			ex de, hl
			dec hl
			bit 7, (hl)
			jr z, mem_err_page
			res 7, (hl)
			ld hl, #4000			; is the whole page free now?
			ld (mem_need), hl
			push bc
			call mem_fit			; only a page with every block free fits
			pop bc
			jr nz, mem_fr_done
			ld a, 3
			call mem_remove
			call mem_tofree
mem_fr_done:
			ld hl, (mem_keep)
			call mem_sel
			ld hl, 0
			ret
mem_err_page:
			ld hl, (mem_keep)
			call mem_sel
			jp mem_chk_bad

; Largest(): the biggest block Alloc could give now
mem_largest:
			ld hl, 0
			ld (mem_max), hl
			call mem_freepages		; a free page: a whole page
			ld a, h
			or l
			ld hl, #3FFE
			ret nz
			ld bc, 0
mem_lg_lp:
			call mem_dnext
			jr z, mem_lg_end
			ld h, b
			ld l, c
			call mem_sel
			push bc
			call mem_big
			pop bc
			jr mem_lg_lp
mem_lg_end:
			ld hl, (mem_keep)
			call mem_sel
			ld hl, (mem_max)
			ld a, h
			or l
			ret z
			dec hl
			dec hl
			ret

;## ntc_membank ntc_plat_rmr @shared @romram
; ------------------------------------------------------------
; ntc_membank - Memory's CallBank switch (CPCExpansion). Runs from RAM
; (a keyword ROM can't be seen once both ROMs are off). BC = the C2
; setting and port for the bank, DE = the address in the bank, HL = value.
; ntc_bk_stub .. ntc_bk_end is also copied into the bank at the same
; address: each out is followed by the next byte from the other 64K.
; ------------------------------------------------------------
ntc_bk_go:
			ld a, i					; P/V = interrupts were on
			di
			push af
			ld (mem_bksp), sp
			call ntc_plat_rmr
			ld (mem_bkrmr), a
			or #0C					; both ROMs off
			push bc
			ld b, #7F
			out (c), a
			pop bc
ntc_bk_stub:
			out (c), c				; the bank is all 64K now
			ld sp, 0
			ld bc, ntc_bk_ret
			push bc
			push de
			ret						; to the bank's code, HL = value
ntc_bk_ret:
			ld bc, #7FC0
			out (c), c				; main RAM again
ntc_bk_end:
			ld sp, (mem_bksp)
			ld a, (mem_bkrmr)
			ld b, #7F
			out (c), a				; the ROMs as they were
			ld bc, (ntc_rampt)
			out (c), c				; and the window's page
			pop af
			jp po, ntc_bk_di
			ei
ntc_bk_di:
			ret

;## ntc_mem ntc_memcore ntc_plat_memtop @shared @far @if:ntc_mem_small
; ------------------------------------------------------------
; ntc_mem (Small) - no paging: Alloc / Free over the free main RAM, from the
; program's end up to the first of: the platform's top (ntc_plat_memtop),
; 256 bytes under the real stack (when that is above the program), an
; Option Reserve range (ntc_rsvtab). Far pointers are plain addresses
; (page 0). Pages() = 0; the page methods give 0 or BadPage.
; ------------------------------------------------------------
mem_start:
			ld a, (mem_init)
			or a
			ret nz
			inc a
			ld (mem_init), a
			call ntc_plat_memtop	; HL = the platform's top
			ld (mem_hhi), hl
			ld hl, (ntc_csp)		; the real stack, when it is above the program
			ld de, ntc_free + 256
			or a
			sbc hl, de
			jr c, mem_ss_rsv
			ld hl, (ntc_csp)
			ld de, -256
			add hl, de
			call mem_lower
mem_ss_rsv:
			ld hl, ntc_rsvtab		; Option Reserve ranges above the program
mem_ss_rl:
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld a, d
			or e
			jr z, mem_ss_go
			push hl
			ld h, d
			ld l, e
			push hl
			ld de, ntc_free
			or a
			sbc hl, de
			pop hl
			call nc, mem_lower
			pop hl
			jr mem_ss_rl
mem_ss_go:
			ld hl, ntc_free
			ld (mem_hlo), hl
			ex de, hl
			ld hl, (mem_hhi)		; room for at least one small block, an even size
			or a
			sbc hl, de
			jr c, mem_ss_none
			ld bc, 8
			push hl
			sbc hl, bc
			pop hl
			jr c, mem_ss_none
			res 0, l
			add hl, de
			ld (mem_hhi), hl
mem_ss_init:						; DE = a block: free blocks of up to #4000
			ld hl, (mem_hhi)
			or a
			sbc hl, de
			ret z
			ld bc, #4000
			push hl
			or a
			sbc hl, bc
			pop hl
			jr c, mem_ss_len
			ld h, b
			ld l, c
mem_ss_len:
			ex de, hl
			ld (hl), e
			inc hl
			ld (hl), d
			dec hl
			add hl, de
			ex de, hl
			jr mem_ss_init
mem_ss_none:
			ld hl, ntc_free
			ld (mem_hhi), hl
			ret
; HL = a limit: mem_hhi = it when lower
mem_lower:
			push de
			ld de, (mem_hhi)
			push hl
			or a
			sbc hl, de
			pop hl
			jr nc, mem_lw_end
			ld (mem_hhi), hl
mem_lw_end:
			pop de
			ret

; no pages: nothing to switch, every page number is BadPage
mem_sel:
			ret
mem_chk:
			jp mem_chk_bad

mem_pages:
mem_freepages:
mem_ramsize:
mem_model:
mem_curpage:
mem_allocpage:
mem_bankcount:
mem_allocbank:
mem_bkstub:
			ld hl, 0
			ret
mem_pagetype:
mem_freepage:
mem_selpage:
mem_freebank:
mem_callbank:
			jp mem_chk_bad
mem_tableend:
			ld hl, ntc_free
			ret
mem_map:
			ld hl, (mem_res)
			ld (hl), 0
			ret

; Alloc(size): a plain address (page 0) of size bytes, 0 = no room
mem_alloc:
			ld hl, (mem_a1)
			ld a, h
			or l
			jr nz, mem_sa_size
			inc hl
mem_sa_size:
			ld de, #3FFF
			or a
			push hl
			sbc hl, de
			pop hl
			jr nc, mem_sa_fail
			inc hl
			inc hl
			ld (mem_need), hl
			call mem_fit
			ret z
mem_sa_fail:
			ld hl, 0
			ret

; Free(ptr): a block back. OK, or BadPage (not a block in use in the heap)
mem_free:
			ld hl, (mem_a1)
			call mem_far			; a page number: BadPage
			ex de, hl
			ld de, (mem_hlo)
			inc de
			inc de
			or a
			sbc hl, de
			jp c, mem_chk_bad
			add hl, de
			ld de, (mem_hhi)
			or a
			sbc hl, de
			jp nc, mem_chk_bad
			add hl, de
			dec hl
			bit 7, (hl)
			jp z, mem_chk_bad
			res 7, (hl)
			ld hl, 0
			ret

; Largest(): the biggest block Alloc could give now
mem_largest:
			ld hl, 0
			ld (mem_max), hl
			call mem_big
			ld hl, (mem_max)
			ld a, h
			or l
			ret z
			dec hl
			dec hl
			ret

;## ntc_keys ntc_data @shared
; ------------------------------------------------------------
; ntc_keys - the Keys class (CPC): the keyboard matrix read straight from the
; hardware (PSG register 14 through the PPI), all 10 lines each time, so it
; works with or without the firmware, in turbo and normal mode. Entered
; with jp from a method, with the method's result pointer still on the
; thread: the result goes there and ret carries on. No stack used.
;   ntc_kdown - HL = a key number 0-79 (the CPC's, as INKEY(n)): -1 held, 0 not
;   ntc_kjoy  - HL = joystick 0 / 1: bits up 1, down 2, left 4, right 8,
;               fire 2 16, fire 1 32 (as JOY(n))
; ------------------------------------------------------------
ntc_kmat:		ds 10			; the matrix (0 = pressed)
ntc_karg:		db 0
ntc_kwhat:		db 0

ntc_kdown:
			ld a, h
			or a
			jr nz, ntc_kd_no
			ld a, l
			cp 80
			jr nc, ntc_kd_no
			ld (ntc_karg), a
			xor a
			jr ntc_kscan
ntc_kjoy:
			ld a, l
			and 1
			ld (ntc_karg), a
			ld a, 1
ntc_kscan:
			ld (ntc_kwhat), a
			ld bc, #F40E		; PSG register 14
			out (c), c
			ld bc, #F6C0		; PSG: select register
			out (c), c
			ld bc, #F600		; PSG: inactive
			out (c), c
			ld bc, #F792		; PPI port A input
			out (c), c
			ld hl, ntc_kmat
			ld a, #40			; PSG read + line 0
ntc_ksc_line:
			ld b, #F6
			out (c), a
			ld b, #F4
			in d, (c)
			ld (hl), d
			inc hl
			inc a
			cp #4A
			jr nz, ntc_ksc_line
			ld bc, #F782		; PPI port A output
			out (c), c
			ld bc, #F600
			out (c), c
			ld a, (ntc_kwhat)
			or a
			jr nz, ntc_kj_got
			ld a, (ntc_karg)	; line = n / 8, bit = n and 7
			ld c, a
			rrca
			rrca
			rrca
			and 31
			ld e, a
			ld d, 0
			ld hl, ntc_kmat
			add hl, de
			ld a, c
			and 7
			ld b, a
			inc b
			ld a, (hl)
ntc_kd_rot:
			rrca
			djnz ntc_kd_rot
			ld de, 0
			jr c, ntc_k_set		; 1 = not pressed
			dec de
			jr ntc_k_set
ntc_kd_no:
			ld de, 0
			jr ntc_k_set
ntc_kj_got:
			ld a, (ntc_karg)	; joystick 0 = line 9, 1 = line 6
			ld hl, ntc_kmat + 9
			or a
			jr z, ntc_kj_line
			ld hl, ntc_kmat + 6
ntc_kj_line:
			ld a, (hl)
			cpl
			and #3F
			ld e, a
			ld d, 0
ntc_k_set:
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

;## ntc_romdisc ntc_data ntc_plat_romsel @shared @ramonly
; ------------------------------------------------------------
; ntc_romdisc - ROMDISC: read-only files kept in ROMs, the FileSystem's
; volume R (cpc, cpcmin, cpcfw). A disc is a set of ROMs NTCDISC.ROM,
; NTCDISC2.ROM ... (made by ntcRomDisc in ntc_compiler.js) in any slots
; 0-31: background ROMs whose names are followed by the block
;   "NTC", 2, "ROMDISC", 0, dw stamp, db place, db ROMs, dw directory (ROM 0)
; ROM 0 has the directory at #C040: entries of RD_ENTRY bytes, read until
; one whose flags have bit 7 set (the end):
;   +0 name (8, spaces after), +8 extension (3), +11 flags (bit 0
;   compressed - none are yet), +12 its ROM (place in the set), +13 its
;   address (dw), +15 its length (3 bytes)
; A file's bytes run on from its address; past #FFFF they go on at RD_DATA
; of the next ROM. Reading selects the disc's ROM (ntc_plat_romsel: rd_sel /
; rd_unsel), so this runs from RAM: it is not in the keyword ROM (@ramonly).
; Routines run on the real stack (rd_go on cpc, the FileSystem's fs_go on
; cpcmin / cpcfw); arguments in rd_a1 .. rd_a3, a string / Long result at
; (rd_res); HL = the result or a status. One file open: handle 2.
; ------------------------------------------------------------
RD_DATA		equ #C040		; directory (ROM 0) and file data start
RD_ENTRY	equ 18
RD_HANDLE	equ 2
RD_NOTSUP	equ -1
RD_NOTFOUND	equ -2
RD_BADNAME	equ -4
RD_NOHANDLE	equ -5
RD_BADHANDLE	equ -6
RD_EOF		equ -7
RD_TOOBIG	equ -8
rd_a1:			dw 0
rd_a2:			dw 0
rd_a3:			dw 0
rd_res:			dw 0
rd_sp:			dw 0
rd_six:			dw 0
rd_siy:			dw 0
rd_nostore:		db 0
rd_state:		db 0			; 0 = not looked for yet, 1 = there, 2 = none
rd_want:		db 0
rd_n:			db 0			; ROMs in the disc
rd_stamp:		dw 0
rd_dir:			dw 0			; the directory (ROM 0)
rd_slots:		ds 8			; each ROM's slot
rd_name:		ds 11			; a name as the directory has it
rd_ent:			ds RD_ENTRY		; the entry found
rd_isopen:		db 0			; 1 = a file open (handle 2)
rd_rom:			db 0			; reading: the ROM, the address, the bytes left
rd_addr:		dw 0
rd_left:		ds 3
rd_cnt:			dw 0
rd_dst:			dw 0
rd_cap:			db 0
rd_sig:			db "NTC", 2, "ROMDISC", 0
rd_sige:

; rd_go / rd_go0 - (cpc) HL = the routine: run on the real stack, its HL
; stored at (rd_res) (rd_go0: not stored - the routine writes its result)
rd_go0:
			ld a, 1
			jr rd_gostart
rd_go:
			xor a
rd_gostart:
			ld (rd_nostore), a
			ld (rd_sp), sp
			ld sp, (ntc_csp)
			ld (rd_six), ix
			ld (rd_siy), iy
			ld a, (ntc_nmode)
			or a
			jr z, rd_g_call
			ei
rd_g_call:
			call rd_jphl
			di
			ld ix, (rd_six)
			ld iy, (rd_siy)
			ld a, (rd_nostore)
			or a
			jr nz, rd_g_end
			ex de, hl
			ld hl, (rd_res)
			ld (hl), e
			inc hl
			ld (hl), d
rd_g_end:
			ld sp, (rd_sp)
			ret
rd_jphl:
			jp (hl)

; rd_mount - is a disc there? (looked for once). Z = yes
rd_mount:
			ld a, (rd_state)
			cp 1
			ret z
			or a
			jr nz, rd_mt_no
			xor a
			ld (rd_want), a
			call rd_scan
			jr c, rd_mt_none
			ld (rd_slots), a
			ld a, 1
rd_mt_more:
			ld (rd_want), a
			ld hl, rd_n
			cp (hl)
			jr nc, rd_mt_ok
			call rd_scan
			jr c, rd_mt_none		; a part missing: no disc
			ld b, a
			ld a, (rd_want)
			ld e, a
			ld d, 0
			ld hl, rd_slots
			add hl, de
			ld (hl), b
			inc a
			jr rd_mt_more
rd_mt_ok:
			ld a, 1
			ld (rd_state), a
			cp a					; Z
			ret
rd_mt_none:
			ld a, 2
			ld (rd_state), a
rd_mt_no:
			or 1					; NZ
			ret

; rd_scan - the disc ROM rd_want (0: any stamp; the others: ROM 0's stamp).
; NC: A = its slot (ROM 0: rd_n, rd_stamp, rd_dir set). C: not there
rd_scan:
			ld c, 0
rd_sc_next:
			push bc
			ld a, c
			call rd_sel
			call rd_sc_try
			call rd_unsel
			pop bc
			jr nc, rd_sc_got
			inc c
			ld a, c
			cp 32
			jr c, rd_sc_next
			scf
			ret
rd_sc_got:
			ld a, c
			ret
rd_sc_try:							; (the ROM is in) NC = it is the one
			ld a, (#C000)
			cp 1					; a background ROM
			jr nz, rd_sc_not
			ld hl, (#C004)			; its names
			ld a, h
			cp #C0
			jr c, rd_sc_not
rd_sc_name:
			ld a, (hl)
			inc hl
			or a
			jr nz, rd_sc_name
			ld de, rd_sig
			ld b, rd_sige - rd_sig
rd_sc_cmp:
			ld a, (de)
			cp (hl)
			jr nz, rd_sc_not
			inc de
			inc hl
			djnz rd_sc_cmp
			ld e, (hl)
			inc hl
			ld d, (hl)				; DE = its stamp
			inc hl
			ld a, (rd_want)
			cp (hl)
			jr nz, rd_sc_not
			inc hl
			or a
			jr nz, rd_sc_stamp
			ld (rd_stamp), de		; ROM 0: the disc's stamp, ROMs, directory
			ld a, (hl)
			ld (rd_n), a
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (rd_dir), de
			or a
			ret
rd_sc_stamp:
			ld hl, (rd_stamp)
			or a
			sbc hl, de
			ret z					; (NC)
rd_sc_not:
			scf
			ret

; rd_mkname - HL = a name ("NAME.EXT", "R:NAME.EXT"): rd_name. NC, or C = not
; a name (empty, more than 8.3)
rd_mkname:
			push hl
			ld hl, rd_name
			ld b, 11
rd_mk_sp:
			ld (hl), ' '
			inc hl
			djnz rd_mk_sp
			pop hl
			inc hl
			ld a, (hl)
			dec hl
			cp ':'
			jr nz, rd_mk_go
			inc hl					; past "R:"
			inc hl
rd_mk_go:
			ld de, rd_name
			ld b, 9					; up to 8 letters, then . or the end
			ld a, (hl)
			or a
			jr z, rd_mk_bad
rd_mk_lp:
			ld a, (hl)
			or a
			ret z					; (NC)
			inc hl
			cp '.'
			jr z, rd_mk_ext
			dec b
			jr z, rd_mk_bad
			call rd_up
			ld (de), a
			inc de
			jr rd_mk_lp
rd_mk_ext:
			ld de, rd_name + 8
			ld b, 4
rd_mk_elp:
			ld a, (hl)
			or a
			ret z
			inc hl
			dec b
			jr z, rd_mk_bad
			cp '.'
			jr z, rd_mk_bad
			call rd_up
			ld (de), a
			inc de
			jr rd_mk_elp
rd_mk_bad:
			scf
			ret
rd_up:
			cp 'a'
			ret c
			cp 'z' + 1
			ret nc
			sub 32
			ret

; rd_find - rd_a1 = a name: its entry into rd_ent. NC, or C with HL = the status
rd_find:
			call rd_mount
			ld hl, RD_NOTFOUND
			scf
			ret nz
			ld hl, (rd_a1)
			call rd_mkname
			ld hl, RD_BADNAME
			ret c
			ld a, (rd_slots)
			call rd_sel
			ld hl, (rd_dir)
rd_fd_lp:
			push hl
			ld de, 11
			add hl, de
			bit 7, (hl)				; the end
			pop hl
			jr nz, rd_fd_none
			push hl
			ld de, rd_name
			ld b, 11
rd_fd_cmp:
			ld a, (de)
			cp (hl)
			jr nz, rd_fd_nx
			inc de
			inc hl
			djnz rd_fd_cmp
			pop hl
			ld de, rd_ent
			ld bc, RD_ENTRY
			ldir
			call rd_unsel
			or a					; NC
			ret
rd_fd_nx:
			pop hl
			ld de, RD_ENTRY
			add hl, de
			jr rd_fd_lp
rd_fd_none:
			call rd_unsel
			ld hl, RD_NOTFOUND
			scf
			ret

; rd_start - reading from the start of rd_ent's file (rd_rom, rd_addr, rd_left)
rd_start:
			ld hl, rd_ent + 12
			ld de, rd_rom
			ld bc, 6
			ldir
			ret

; rd_copy - BC bytes (no more than are left) to DE: on from rd_rom / rd_addr
rd_copy:
			ld (rd_cnt), bc
			ld (rd_dst), de
rd_cp_lp:
			ld hl, (rd_cnt)
			ld a, h
			or l
			ret z
			ld hl, (rd_addr)		; this ROM's part: up to #FFFF
			ex de, hl
			ld hl, 0
			or a
			sbc hl, de				; HL = #10000 - address
			ld de, (rd_cnt)
			or a
			sbc hl, de
			jr nc, rd_cp_all
			add hl, de				; (only what this ROM has)
			ld b, h
			ld c, l
			jr rd_cp_do
rd_cp_all:
			ld b, d
			ld c, e
rd_cp_do:
			push bc
			call rd_romslot
			call rd_sel
			pop bc
			push bc
			ld hl, (rd_addr)
			ld de, (rd_dst)
			ldir
			ld (rd_dst), de
			call rd_unsel
			pop bc
			ld hl, (rd_cnt)
			or a
			sbc hl, bc
			ld (rd_cnt), hl
			call rd_adv
			jr rd_cp_lp

; rd_adv - BC bytes read: on in the file (the next ROM past #FFFF), fewer left
rd_adv:
			ld hl, (rd_addr)
			add hl, bc
			jr nc, rd_av_same
			ld a, h
			or l
			jr nz, rd_av_same
			ld hl, rd_rom
			inc (hl)
			ld hl, RD_DATA
rd_av_same:
			ld (rd_addr), hl
			ld hl, (rd_left)
			or a
			sbc hl, bc
			ld (rd_left), hl
			ret nc
			ld hl, rd_left + 2
			dec (hl)
			ret

; rd_romslot - A = the slot of rd_rom
rd_romslot:
			ld a, (rd_rom)
			ld e, a
			ld d, 0
			ld hl, rd_slots
			add hl, de
			ld a, (hl)
			ret

; rd_getb - the next byte of the open file: A, NC; C = the end
rd_getb:
			ld hl, (rd_left)
			ld a, h
			or l
			ld hl, rd_left + 2
			or (hl)
			scf
			ret z
			call rd_romslot
			call rd_sel
			ld hl, (rd_addr)
			ld a, (hl)
			push af
			call rd_unsel
			ld bc, 1
			call rd_adv
			pop af
			or a					; NC
			ret

; rd_hchk - rd_a1 must be handle 2, open: else (from the routine) BadHandle
rd_hchk:
			ld hl, (rd_a1)
			ld de, -RD_HANDLE
			add hl, de
			ld a, h
			or l
			jr nz, rd_hc_bad
			ld a, (rd_isopen)
			or a
			ret nz
rd_hc_bad:
			pop hl					; (out of the routine)
			ld hl, RD_BADHANDLE
			ret

; Load(name, addr, maxlen): its length, or a status (TooBig: nothing loaded)
rd_load:
			call rd_find
			ret c
			ld a, (rd_ent + 17)		; more than 65535, or more than maxlen
			or a
			ld hl, RD_TOOBIG
			ret nz
			ld de, (rd_ent + 15)
			ld hl, (rd_a3)
			or a
			sbc hl, de
			ld hl, RD_TOOBIG
			ret c
			call rd_start
			ld bc, (rd_ent + 15)
			ld de, (rd_a2)
			call rd_copy
			ld hl, (rd_ent + 15)
			ret

; Open(name, mode): handle 2, or a status (only ForRead: the disc is read only)
rd_open:
			ld a, (rd_isopen)
			or a
			ld hl, RD_NOHANDLE
			ret nz
			ld hl, (rd_a2)
			ld a, l
			cp 4				; ForReadRaw: the same (a ROMDISC file is read to its length)
			jr nz, rd_op_m
			ld l, 1
rd_op_m:
			dec hl
			ld a, h
			or l
			ld hl, RD_NOTSUP
			ret nz
			call rd_find
			ret c
			call rd_start
			ld a, 1
			ld (rd_isopen), a
			ld hl, RD_HANDLE
			ret

; Close(h): OK or BadHandle
rd_close:
			call rd_hchk
			xor a
			ld (rd_isopen), a
			ld hl, 0
			ret

; ReadByte(h): 0-255, EndOfFile, BadHandle
rd_readb:
			call rd_hchk
			call rd_getb
			ld hl, RD_EOF
			ret c
			ld l, a
			ld h, 0
			ret

; Read(h, addr, count): bytes read (fewer at the end)
rd_read:
			call rd_hchk
			ld hl, (rd_a3)
			bit 7, h
			jr z, rd_rd_pos
			ld hl, 0
rd_rd_pos:
			ld a, (rd_left + 2)		; no more than are left
			or a
			jr nz, rd_rd_go
			ld de, (rd_left)
			push hl
			or a
			sbc hl, de
			pop hl
			jr c, rd_rd_go
			ex de, hl
rd_rd_go:
			push hl
			ld b, h
			ld c, l
			ld de, (rd_a2)
			call rd_copy
			pop hl
			ret

; Eof(h): True when nothing is left (or h is not the open file)
rd_eof:
			ld hl, (rd_a1)
			ld de, -RD_HANDLE
			add hl, de
			ld a, h
			or l
			jr nz, rd_ef_yes
			ld a, (rd_isopen)
			or a
			jr z, rd_ef_yes
			ld hl, (rd_left)
			ld a, h
			or l
			ld hl, rd_left + 2
			or (hl)
			ld hl, 0
			ret nz
rd_ef_yes:
			ld hl, -1
			ret

; ReadLine(h): the next line (up to LF; CR dropped) into the string at (rd_res)
rd_readln:
			ld hl, (rd_res)
			ld (hl), 0
			dec hl
			ld a, (hl)
			ld (rd_cap), a
			inc hl
			ld (rd_dst), hl
			call rd_hchk
rd_rl_lp:
			call rd_getb
			jr c, rd_rl_end
			cp 10
			jr z, rd_rl_end
			cp 13
			jr z, rd_rl_lp
			ld c, a
			ld a, (rd_cap)
			or a
			jr z, rd_rl_lp			; full: the rest of the line is dropped
			dec a
			ld (rd_cap), a
			ld hl, (rd_dst)
			ld (hl), c
			inc hl
			ld (rd_dst), hl
			jr rd_rl_lp
rd_rl_end:
			ld hl, (rd_dst)
			ld (hl), 0
			ret

; Exists(name): True / False
rd_exists:
			call rd_find
			ld hl, 0
			ret c
			dec hl
			ret

; Size(name): its length, a Long written at (rd_res) (or a status)
rd_size:
			call rd_find
			ld de, (rd_res)
			jr c, rd_sz_status
			ld hl, rd_ent + 15
			ld bc, 3
			ldir
			xor a
			ld (de), a
			ret
rd_sz_status:
			ex de, hl
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld (hl), #FF
			inc hl
			ld (hl), #FF
			ret

; DirEntry(n): the n-th file's name ("NAME.EXT", 1 = the first) into the
; string at (rd_res); "" past the last (or no disc)
rd_dirent:
			ld hl, (rd_res)
			ld (hl), 0
			dec hl
			ld a, (hl)
			ld (rd_cap), a
			call rd_mount
			ret nz
			ld de, (rd_a1)
			ld a, d
			or a
			ret nz
			ld a, e
			or a
			ret z
			ld b, a
			ld a, (rd_slots)
			push bc
			call rd_sel				; (rd_sel uses BC)
			pop bc
			ld hl, (rd_dir)
rd_de_lp:
			push hl
			ld de, 11
			add hl, de
			bit 7, (hl)
			pop hl
			jr nz, rd_de_done		; past the last
			dec b
			jr z, rd_de_got
			ld de, RD_ENTRY
			add hl, de
			jr rd_de_lp
rd_de_got:
			ld de, rd_name			; (a copy: the ROM goes out before the string is written)
			ld bc, 11
			ldir
			call rd_unsel
			ld hl, rd_name
			ld de, (rd_res)
			ld b, 8
			call rd_de_part
			ld a, (rd_name + 8)
			cp ' '
			jr z, rd_de_end
			ld a, '.'
			call rd_de_put
			ld hl, rd_name + 8
			ld b, 3
			call rd_de_part
rd_de_end:
			xor a
			ld (de), a
			ret
rd_de_done:
			jp rd_unsel
rd_de_part:							; B letters at HL (up to a space) to DE
			ld a, (hl)
			cp ' '
			ret z
			call rd_de_put
			inc hl
			djnz rd_de_part
			ret
rd_de_put:							; A to DE if the string has room
			push af
			ld a, (rd_cap)
			or a
			jr z, rd_dp_full
			dec a
			ld (rd_cap), a
			pop af
			ld (de), a
			inc de
			ret
rd_dp_full:
			pop af
			ret

; SelectVolume("R"): OK when a disc is there, else NotFound
rd_selvol:
			call rd_mount
			ld hl, RD_NOTFOUND
			ret nz
			ld hl, 0
			ret

; rd_ns - NotSupported (a method the disc can't do)
rd_ns:
			ld hl, RD_NOTSUP
			ret

;## ntc_memcopy ntc_mem ntc_buf2k @shared @far
; Copy(src, dst, length): far pointer to far pointer, up to 2K at a time
; through ntc_buf (so page to page works with one window). A page's end
; (#8000) carries on at #4000 of the next page. The window is put back.
; OK, or BadPage.
mem_copy:
			ld hl, (mem_a1)
			call mem_far
			ld (mem_srca), de
			ld (mem_srcp), hl
			ld hl, (mem_a2)
			call mem_far
			ld (mem_dsta), de
			ld (mem_dstp), hl
			ld hl, (mem_a3)
			ld (mem_left), hl
mem_cp_lp:
			ld hl, (mem_left)
			ld a, h
			or l
			jr z, mem_cp_done
			ld de, 2048
			call mem_min
			ld de, (mem_srcp)
			ld a, d
			or e
			ld de, (mem_srca)
			call nz, mem_room
			ld de, (mem_dstp)
			ld a, d
			or e
			ld de, (mem_dsta)
			call nz, mem_room
			ld (mem_chunk), hl
			ld hl, (mem_srcp)
			ld a, h
			or l
			call nz, mem_cp_sel
			ld hl, (mem_srca)
			ld de, ntc_buf
			ld bc, (mem_chunk)
			ldir
			ld (mem_srca), hl
			ld hl, (mem_dstp)
			ld a, h
			or l
			call nz, mem_cp_sel
			ld hl, ntc_buf
			ld de, (mem_dsta)
			ld bc, (mem_chunk)
			ldir
			ld (mem_dsta), de
			ld hl, mem_srcp
			ld de, (mem_srca)
			call mem_cp_wrap
			ld (mem_srca), de
			ld hl, mem_dstp
			ld de, (mem_dsta)
			call mem_cp_wrap
			ld (mem_dsta), de
			ld hl, (mem_left)
			ld de, (mem_chunk)
			or a
			sbc hl, de
			ld (mem_left), hl
			jp mem_cp_lp
mem_cp_done:
			ld hl, (mem_keep)
			call mem_sel
			ld hl, 0
			ret
mem_cp_sel:
			call mem_chk			; a page past the last one: BadPage
			jp mem_sel
; HL = the smaller of HL and DE
mem_min:
			push hl
			or a
			sbc hl, de
			pop hl
			ret c
			ex de, hl
			ret
; DE = an address in the window: HL = no more than #8000 - DE
mem_room:
			push hl
			ld hl, #8000
			or a
			sbc hl, de
			ex de, hl
			pop hl
			jr mem_min
; HL = a page word, DE = the address: #8000 in a page -> #4000 of the next
mem_cp_wrap:
			ld a, (hl)
			inc hl
			or (hl)
			dec hl
			ret z
			ld a, d
			cp #80
			ret nz
			inc (hl)
			jr nz, mem_cw_hi
			inc hl
			inc (hl)
mem_cw_hi:
			ld d, #40
			ret

;## ntc_ovlcom ntc_data ntc_mem ntc_plat_screen ntc_plat_key kw_stop @shared
; ------------------------------------------------------------
; ntc_ovlcom - what both overlay schemes share (ntc_ovl has the rest): the
; variables, the message when a class can't be loaded, a class's local
; memory (LocalAlloc / LocalFree), the members' result.
; ------------------------------------------------------------
OVL_NOPAGE	equ -12
OVL_STALE	equ -14			; a page file from another build of the program (its stamp differs)

ovl_blk:		dw 0			; the class block in use
ovl_pg:			dw 0			; where the caller's page goes
ovl_ix:			dw 0
ovl_cix:		dw 0
ovl_pix:		dw 0
ovl_new:		dw 0
ovl_res:		dw 0
ovl_p:			dw 0
ovl_ksp:		dw 0
ovl_kres:		dw 0
ovl_kcur:		dw 0
ovl_mt:			dw ntc_ovl_ld2	; fs_go returns into this
ovl_lblk:		dw 0			; LocalAlloc / LocalFree: the class block
ovl_ct:			dw 0			; ntc_ovl_enterc: the copy table's home row
ntc_ovl_lc:		db 0			; 1 = a call from code in the class's own page (its local entry): no switch
ntc_ovl_body:	dw 0			; a class in more than one page: the body of the copy to run
ovl_tdie:		db "Overlay not loaded: ", 0
ovl_tpage:		db "No RAM page free", 0
ovl_tfile:		db "The file didn't load", 0
ovl_tstale:		db "The file is from another build", 0
ovl_tkey:		db "Press a key", 0
ovl_tbra:		db " (", 0
ovl_tket:		db ")", 0
ovl_why:		dw 0

; it can't be loaded: the name and why, wait for a key (a program started
; with RUN" resets when it ends), then the program stops
ntc_ovl_die:
			ld (ovl_why), hl
			ld ix, ntc_ovl_die1
			jp ntc_plat_newline
ntc_ovl_die1:
			ld hl, ovl_tdie
			ld ix, ntc_ovl_die2
			jp ntc_ovl_puts
ntc_ovl_die2:
			ld hl, (ovl_blk)		; the page's name, then its file in brackets (a page
			ld de, 6				; named by its file: the file)
			add hl, de
ntc_ovl_dn1:
			ld a, (hl)				; past the file name to the page name
			inc hl
			or a
			jr nz, ntc_ovl_dn1
			ld a, (hl)
			or a
			jr z, ntc_ovl_dfile
			ld ix, ntc_ovl_dn2
			jp ntc_ovl_puts
ntc_ovl_dn2:
			ld hl, ovl_tbra
			ld ix, ntc_ovl_dn3
			jp ntc_ovl_puts
ntc_ovl_dn3:
			ld hl, (ovl_blk)
			ld de, 6
			add hl, de
			ld ix, ntc_ovl_dn4
			jp ntc_ovl_puts
ntc_ovl_dn4:
			ld hl, ovl_tket
			ld ix, ntc_ovl_die3
			jp ntc_ovl_puts
ntc_ovl_dfile:
			ld hl, (ovl_blk)
			ld de, 6
			add hl, de
			ld ix, ntc_ovl_die3
			jp ntc_ovl_puts
ntc_ovl_die3:
			ld ix, ntc_ovl_die3b
			jp ntc_plat_newline
ntc_ovl_die3b:
			ld hl, (ovl_why)
			ld de, -OVL_NOPAGE
			add hl, de
			ld a, h
			or l
			ld hl, ovl_tpage
			jr z, ntc_ovl_die4
			ld hl, (ovl_why)
			ld de, -OVL_STALE
			add hl, de
			ld a, h
			or l
			ld hl, ovl_tstale
			jr z, ntc_ovl_die4
			ld hl, ovl_tfile
ntc_ovl_die4:
			ld ix, ntc_ovl_die5
			jp ntc_ovl_puts
ntc_ovl_die5:
			ld ix, ntc_ovl_die6
			jp ntc_plat_newline
ntc_ovl_die6:
			ld hl, ovl_tkey
			ld ix, ntc_ovl_die7
			jp ntc_ovl_puts
ntc_ovl_die7:
			ld ix, kw_stop
			jp ntc_plat_getkey
; HL = text (0 ended): printed, then jp (ix)
ntc_ovl_puts:
			ld (ovl_pix), ix
ntc_ovl_pl:
			ld a, (hl)
			or a
			jr z, ntc_ovl_pe
			inc hl
			ld (ovl_p), hl
			ld ix, ntc_ovl_pn
			jp ntc_plat_putc
ntc_ovl_pn:
			ld hl, (ovl_p)
			jr ntc_ovl_pl
ntc_ovl_pe:
			ld ix, (ovl_pix)
			jp (ix)

; ntc_ovl_fresh - (call) HL = a class block + 2, the class just loaded at
; #4000: its page variables cleared, its local memory one free block.
ntc_ovl_fresh:
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			push de
			ld a, b
			or c
			jr z, ntc_ovl_noclr
			push bc
			ld h, d
			ld l, e
			ld (hl), 0
			dec bc
			ld a, b
			or c
			jr z, ntc_ovl_clr1
			inc de
			ldir
ntc_ovl_clr1:
			pop bc
ntc_ovl_noclr:
			pop hl
			add hl, bc				; its local memory: one free block (LocalAlloc)
			call ntc_ovl_lend
			or a
			sbc hl, de				; the size (even)
			ld a, h
			or a
			jr nz, ntc_ovl_lhd
			ld a, l
			cp 4
			jr c, ntc_ovl_lnone
ntc_ovl_lhd:
			ex de, hl
			ld (hl), e
			inc hl
			ld (hl), d
ntc_ovl_lnone:
			ret

; the members' end: HL = the result into ovl_kres, back on the thread
ntc_ovl_kret:
			ex de, hl
			ld hl, (ovl_kres)
			ld (hl), e
			inc hl
			ld (hl), d
			ld sp, (ovl_ksp)
			ret

ntc_ovl_kput:
			ex de, hl
			ld hl, (ovl_kres)
			ld (hl), e
			inc hl
			ld (hl), d
			ret

; ntc_ovl_lend - HL = a class's local memory start: DE = it, HL = its end
; (start + the room to #8000, made even)
ntc_ovl_lend:
			ex de, hl
			ld hl, #8000
			or a
			sbc hl, de
			res 0, l
			add hl, de
			ret
; LocalAlloc(size) (mem_go): size bytes of the class's local memory - the
; rest of its page; only from the class's own code. An address, 0 = no room
ntc_ovl_lalloc:
			ld hl, (mem_a1)
			ld a, h
			or l
			jr nz, ntc_ovl_la1
			inc hl
ntc_ovl_la1:
			ld de, #3FFF
			or a
			push hl
			sbc hl, de
			pop hl
			jr nc, ntc_ovl_la0
			inc hl
			inc hl
			ld (mem_need), hl
			call ntc_ovl_lreg
			jr z, ntc_ovl_la0
			ld bc, (mem_hlo)		; the heap code, on this region
			push bc
			ld bc, (mem_hhi)
			push bc
			ld (mem_hlo), hl
			ld (mem_hhi), de
			call mem_fit
			jr z, ntc_ovl_la2
			ld hl, 0
ntc_ovl_la2:
			pop de
			ld (mem_hhi), de
			pop de
			ld (mem_hlo), de
			ret
ntc_ovl_la0:
			ld hl, 0
			ret

; LocalFree(address) (mem_go): a block back. OK, or BadPage
ntc_ovl_lfree:
			call ntc_ovl_lreg
			jp z, mem_chk_bad
			ld bc, (mem_a1)			; start + 2 <= address < end
			inc hl
			inc hl
			push hl
			ld h, b
			ld l, c
			pop bc
			or a
			sbc hl, bc
			jp c, mem_chk_bad
			add hl, bc
			or a
			sbc hl, de
			jp nc, mem_chk_bad
			add hl, de
			dec hl
			bit 7, (hl)
			jp z, mem_chk_bad
			res 7, (hl)
			ld hl, 0
			ret


;## ntc_ovl ntc_ovlcom ntc_mem ntc_plat_fs @shared @if:ntc_mem_cpcexpansion
; ------------------------------------------------------------
; ntc_ovl - overlay classes (Option Class Overlay "FILE"): the class's
; threads are built at #4000 into FILE.PAG in the same compile; its data
; stays in main memory. Each class has a block in main memory:
;   ovl_blk_<class>: dw page (0 = not loaded), db "FILE.PAG", 0
; A call stub (p_name_c) saves the caller's SP, then jumps to
; ntc_ovl_enter, which keeps the page that was in the window (the
; stub's _pg word) and switches the class's page in - loading the file
; into a free C page first if it isn't loaded. The return stub (p_name_r)
; switches the caller's page back. Loading runs fs_load (the FileSystem
; code: CAS IN, AMSDOS) through fs_go, with ovl_mt as the "thread" fs_go
; returns into. The class's own Load / Unload / Loaded / Page members
; are asm keywords (ntc_ovl_k*).
; ------------------------------------------------------------
; ntc_ovl_enter - from a call stub (jp, IX = where to go on): HL = the class
; block, DE = the stub's word for the caller's page. Comes back on the real
; stack with the class's page in the window; a class that can't be loaded
; stops the program with a message.
ntc_ovl_enter:
			ld (ovl_blk), hl
			ld (ovl_pg), de
			ld (ovl_ix), ix
			ld sp, (ntc_csp)
			call mem_start
			ld hl, (mem_cur)
			ex de, hl
			ld hl, (ovl_pg)
			ld (hl), e
			inc hl
			ld (hl), d
			ld hl, (ovl_blk)
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld a, d
			or e
			jr z, ntc_ovl_en_ld
			ex de, hl
			call mem_sel
			ld ix, (ovl_ix)
			jp (ix)
ntc_ovl_en_ld:
			ld hl, (ovl_blk)
			ld ix, ntc_ovl_en_back
			jp ntc_ovl_core
ntc_ovl_en_back:
			ld a, h
			or l
			jp nz, ntc_ovl_die
			ld ix, (ovl_ix)
			jp (ix)
; ntc_ovl_enterc - from a call stub of a class in more than one page (jp, SP =
; the caller's thread, IX = where to go on): HL = the procedure's copy table (db
; n, then n x dw block, body - the home copy first), DE = the stub's word for the
; caller's page. Picks the copy whose page is in the window now (no switch), else
; the home copy; ntc_ovl_body = its body; then on as ntc_ovl_enter. No stack used
; (SP is the caller's thread).
ntc_ovl_enterc:
			ld (ovl_pg), de
			ld (ovl_ix), ix
			ld b, (hl)
			inc hl
			ld (ovl_ct), hl
ntc_ovl_ec1:
			ld e, (hl)				; DE = a copy's block, HL = its body's word
			inc hl
			ld d, (hl)
			inc hl
			inc de					; its page (0 = not loaded) = the page in the window?
			ld a, (de)
			dec de
			ld c, a
			ld a, (mem_cur + 1)
			cp c
			jr nz, ntc_ovl_ec2
			ld a, (de)
			ld c, a
			ld a, (mem_cur)
			cp c
			jr nz, ntc_ovl_ec2
			inc de
			ld a, (de)
			dec de
			or c
			jr nz, ntc_ovl_ec3
ntc_ovl_ec2:
			inc hl
			inc hl
			djnz ntc_ovl_ec1
			ld hl, (ovl_ct)			; none in the window: the home copy
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
ntc_ovl_ec3:
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld (ntc_ovl_body), hl
			ex de, hl
			ld de, (ovl_pg)
			ld ix, (ovl_ix)
			jp ntc_ovl_enter
; ntc_ovl_core - (jp, IX = where to go on) HL = a class block: its file into a
; free C page. Comes back on the real stack with HL = 0 and that page in the
; window, or HL = a FileSystem status / OVL_NOPAGE (no page is kept).
ntc_ovl_core:
			ld (ovl_blk), hl
			ld (ovl_cix), ix
			ld sp, (ntc_csp)
			call mem_start
			ld a, 2					; a free page onto the C list
			call mem_take
			ld hl, OVL_NOPAGE
			jr z, ntc_ovl_cback
			ld (ovl_new), bc
			ld h, b
			ld l, c
			call mem_sel
			ld hl, (ovl_blk)		; FileSystem's Load: name, #4000, at most #4000
			ld de, 6
			add hl, de
			ld (fs_a1), hl
			ld hl, MEM_WIN
			ld (fs_a2), hl
			ld (fs_a3), hl
			ld hl, ovl_res
			ld (fs_res), hl
			ld sp, ovl_mt
			ld hl, fs_load
			jp fs_go
ntc_ovl_ld2:
			ld sp, (ntc_csp)
			ld hl, (ovl_res)		; the length, or a status
			bit 7, h
			jr nz, ntc_ovl_cfail
			ld hl, (#4000)			; its first word: the build stamp, as the program's?
			ld de, NTC_STAMP
			or a
			sbc hl, de
			ld hl, OVL_STALE
			jr nz, ntc_ovl_cfail
			ld de, (ovl_new)
			ld hl, (ovl_blk)
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			call ntc_ovl_fresh
			ld hl, 0
ntc_ovl_cback:
			ld ix, (ovl_cix)
			jp (ix)
ntc_ovl_cfail:
			push hl
			ld bc, (ovl_new)		; the page goes back to free
			ld a, 2
			call mem_remove
			call mem_tofree
			pop hl
			jr ntc_ovl_cback

; the class members (asm keywords, on the thread): HL = the class block,
; ovl_kres = the result's address

; Load(): the class's file into a free C page (nothing if it is loaded).
; OK, a FileSystem status, or -12 (no page free). The window is put back.
ntc_ovl_kload:
			ld (ovl_ksp), sp
			ld (ovl_blk), hl
			ld sp, (ntc_csp)
			call mem_start
			ld hl, (mem_cur)
			ld (ovl_kcur), hl
			ld hl, (ovl_blk)
			ld a, (hl)
			inc hl
			or (hl)
			ld hl, 0
			jp nz, ntc_ovl_kret
			ld hl, (ovl_blk)
			ld ix, ntc_ovl_kl2
			jp ntc_ovl_core
ntc_ovl_kl2:
			push hl
			ld hl, (ovl_kcur)
			call mem_sel
			pop hl
			jp ntc_ovl_kret
; Unload(): the page back to free (the next call loads the file again). OK
ntc_ovl_kunload:
			ld (ovl_ksp), sp
			ld sp, (ntc_csp)
			ld c, (hl)
			inc hl
			ld b, (hl)
			ld a, b
			or c
			jr z, ntc_ovl_kzero
			xor a
			ld (hl), a
			dec hl
			ld (hl), a
			ld a, 2
			call mem_remove
			call mem_tofree
ntc_ovl_kzero:
			ld hl, 0
			jp ntc_ovl_kret

; Loaded(): True when its page is in RAM
ntc_ovl_kloaded:
			ld a, (hl)
			inc hl
			or (hl)
			ld hl, 0
			jp z, ntc_ovl_kput
			dec hl
			jp ntc_ovl_kput
; Page(): the page it is loaded in, 0 = not loaded
ntc_ovl_kpage:
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_ovl_kput

; ntc_ovl_lreg - ovl_lblk's class: its page must be the one in the window
; (its own code is running). NZ: HL = its local memory start, DE = the end.
; Z: it isn't.
ntc_ovl_lreg:
			ld hl, (ovl_lblk)
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld a, d
			or e
			ret z
			ld hl, (mem_cur)
			or a
			sbc hl, de
			jr nz, ntc_ovl_lno
			ld hl, (ovl_lblk)
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			ex de, hl
			add hl, bc
			push hl
			call ntc_ovl_lend
			ex de, hl
			pop hl
			ld a, 1
			or a
			ret
ntc_ovl_lno:
			xor a
			ret

;## ntc_ovl ntc_ovlcom ntc_mem ntc_plat_fs @shared @if:ntc_mem_small
; ------------------------------------------------------------
; ntc_ovl (Small) - overlay classes with no RAM pages: one overlay area,
; #4000-#7FFF, holds one class at a time. A call to a class that isn't in
; it loads the class's file there (over the one that was). The call stub's
; _pg word keeps the class the caller runs in when the caller's own code is
; in the area (its thread is in #4000-#7FFF), else 0; the return stub
; (ntc_ovl_ret) loads that class again if another one took its place. In
; the class block, the page word is 1 while the class is in the area.
; ------------------------------------------------------------
OVL_BUSY	equ -13

ovl_cur:		dw 0			; the class block in the area, 0 = none

; ntc_ovl_enter - from a call stub (jp, SP = the caller's thread, IX = where
; to go on): HL = the class block, DE = the stub's word for the class to
; put back. Comes back on the real stack with the class in the area.
ntc_ovl_enter:
			ld (ovl_blk), hl
			ld (ovl_pg), de
			ld (ovl_ix), ix
			ld hl, 0
			add hl, sp
			ld sp, (ntc_csp)
			ld a, h					; the caller's thread in the area: its class
			and #C0
			cp #40
			ld hl, 0
			jr nz, ntc_ovl_en1
			ld hl, (ovl_cur)
ntc_ovl_en1:
			ex de, hl
			ld hl, (ovl_pg)
			ld (hl), e
			inc hl
			ld (hl), d
			ld hl, (ovl_blk)
ntc_ovl_engo:
			ld de, (ovl_cur)
			or a
			sbc hl, de
			jr z, ntc_ovl_en_in
			add hl, de
			ld ix, ntc_ovl_en_back
			jp ntc_ovl_core
ntc_ovl_en_back:
			ld a, h
			or l
			jp nz, ntc_ovl_die
ntc_ovl_en_in:
			ld ix, (ovl_ix)
			jp (ix)

; ntc_ovl_enterc - from a call stub of a class in more than one page (jp, SP =
; the caller's thread, IX = where to go on): HL = the procedure's copy table (db
; n, then n x dw block, body - the home copy first), DE = the stub's word for the
; caller's page. Picks the copy in the overlay area now (no load), else
; the home copy; ntc_ovl_body = its body; then on as ntc_ovl_enter. No stack used
; (SP is the caller's thread).
ntc_ovl_enterc:
			ld (ovl_pg), de
			ld (ovl_ix), ix
			ld b, (hl)
			inc hl
			ld (ovl_ct), hl
ntc_ovl_ec1:
			ld e, (hl)				; DE = a copy's block, HL = its body's word
			inc hl
			ld d, (hl)
			inc hl
			ld a, (ovl_cur)			; the one in the overlay area?
			cp e
			jr nz, ntc_ovl_ec2
			ld a, (ovl_cur + 1)
			cp d
			jr z, ntc_ovl_ec3
ntc_ovl_ec2:
			inc hl
			inc hl
			djnz ntc_ovl_ec1
			ld hl, (ovl_ct)			; none in the window: the home copy
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
ntc_ovl_ec3:
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld (ntc_ovl_body), hl
			ex de, hl
			ld de, (ovl_pg)
			ld ix, (ovl_ix)
			jp ntc_ovl_enter
; ntc_ovl_ret - from a return stub (jp, IX = where to go on): HL = the
; class its caller runs in (0: the caller isn't in the area). Comes back on
; the real stack with that class in the area again.
ntc_ovl_ret:
			ld sp, (ntc_csp)
			ld a, h
			or l
			jr z, ntc_ovl_rt0
			ld (ovl_ix), ix
			ld (ovl_blk), hl
			jr ntc_ovl_engo
ntc_ovl_rt0:
			jp (ix)

; ntc_ovl_core - (jp, IX = where to go on) HL = a class block: its file into
; the area. Comes back on the real stack with HL = 0, or a FileSystem status
; (the area is then empty).
ntc_ovl_core:
			ld (ovl_blk), hl
			ld (ovl_cix), ix
			ld sp, (ntc_csp)
			ld hl, (ovl_cur)		; the class in the area goes
			ld a, h
			or l
			jr z, ntc_ovl_c1
			xor a
			ld (hl), a
			inc hl
			ld (hl), a
			ld h, a
			ld l, a
			ld (ovl_cur), hl
ntc_ovl_c1:
			ld hl, (ovl_blk)		; FileSystem's Load: name, #4000, at most #4000
			ld de, 6
			add hl, de
			ld (fs_a1), hl
			ld hl, #4000
			ld (fs_a2), hl
			ld (fs_a3), hl
			ld hl, ovl_res
			ld (fs_res), hl
			ld sp, ovl_mt
			ld hl, fs_load
			jp fs_go
ntc_ovl_ld2:
			ld sp, (ntc_csp)
			ld hl, (ovl_res)		; the length, or a status
			bit 7, h
			jr nz, ntc_ovl_cback
			ld hl, (#4000)			; its first word: the build stamp, as the program's?
			ld de, NTC_STAMP
			or a
			sbc hl, de
			ld hl, OVL_STALE
			jr nz, ntc_ovl_cback		; (the area stays empty)
			ld hl, (ovl_blk)
			ld (ovl_cur), hl
			ld (hl), 1
			inc hl
			ld (hl), 0
			inc hl
			call ntc_ovl_fresh
			ld hl, 0
ntc_ovl_cback:
			ld ix, (ovl_cix)
			jp (ix)

; the class members (asm keywords, on the thread): HL = the class block,
; ovl_kres = the result's address. Code running in the area can't load or
; unload a class: that would overwrite it (OVL_BUSY, -13).

; Load(): the class's file into the area now (nothing if it is there). OK,
; a FileSystem status, or -13
ntc_ovl_kload:
			ld (ovl_ksp), sp
			ld (ovl_blk), hl
			ld de, (ovl_cur)
			or a
			sbc hl, de
			ld sp, (ntc_csp)
			jp z, ntc_ovl_kret		; HL = 0
			call ntc_ovl_kbusy
			jp z, ntc_ovl_kret
			ld hl, (ovl_blk)
			ld ix, ntc_ovl_kret
			jp ntc_ovl_core
; Z and HL = OVL_BUSY when the member was called from code in the area
ntc_ovl_kbusy:
			ld a, (ovl_ksp + 1)
			and #C0
			cp #40
			ld hl, OVL_BUSY
			ret

; Unload(): the area is empty (the next call loads the file again). OK, or -13
ntc_ovl_kunload:
			ld (ovl_ksp), sp
			ld sp, (ntc_csp)
			ld a, (hl)
			inc hl
			or (hl)
			jr z, ntc_ovl_kzero
			push hl
			call ntc_ovl_kbusy
			pop de
			jp z, ntc_ovl_kret
			xor a
			ld (de), a
			dec de
			ld (de), a
			ld h, a
			ld l, a
			ld (ovl_cur), hl
ntc_ovl_kzero:
			ld hl, 0
			jp ntc_ovl_kret

; Loaded(): True when it is in the area
ntc_ovl_kloaded:
			ld a, (hl)
			inc hl
			or (hl)
			ld hl, 0
			jp z, ntc_ovl_kput
			dec hl
			jp ntc_ovl_kput

; Page(): 0 (no RAM pages)
ntc_ovl_kpage:
			ld hl, 0
			jp ntc_ovl_kput

; ntc_ovl_lreg - ovl_lblk's class: it must be in the area (its own code is
; running). NZ: HL = its local memory start, DE = the end. Z: it isn't.
ntc_ovl_lreg:
			ld hl, (ovl_lblk)
			ld a, (hl)
			inc hl
			or (hl)
			ret z
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			ex de, hl
			add hl, bc
			push hl
			call ntc_ovl_lend
			ex de, hl
			pop hl
			ld a, 1
			or a
			ret

;## ntc_gfx ntc_data ntc_plat_data @shared @ramonly
; ------------------------------------------------------------
; ntc_gfx - drawing on the CPC screen (Graphics class, Vector3D): lines in
; mode 0, 1 or 2 (ntc_smode), in a pen, XOR (drawing a line again takes it
; off). Two screens for double buffering: #C000 and main RAM's own
; #4000-#7FFF (page 1 - the CRTC always shows main RAM, whatever RAM page the
; Z80 has in the window). Called on the real stack (call / ret); uses IX, IY.
; One loop for every mode: C is a marker of the pixel's bits (mode 0 #AA /
; #55, mode 1 #88 >> n, mode 2 #80 >> n); RRC C moves it one pixel right and
; its carry says "next byte"; the pixel is C and the pen's pattern (IYL).
; ------------------------------------------------------------
gfx_x0:			dw 0
gfx_y0:			dw 0
gfx_x1:			dw 0
gfx_y1:			dw 0
gfx_pen:		db 1
gfx_clip:		db 1			; 1: a line with an end off the screen isn't drawn; 0: no checks
gfx_base:		db #C0			; the screen drawn on (high byte)
gfx_dbl:		db 0			; 1 = double buffering
gfx_shown:		db #30			; CRTC R12 of the screen shown
gfx_sp:			dw 0			; the thread position while a Graphics method works

; gfx_begin / gfx_end - around drawing: main RAM in the window when the
; screen drawn on is #4000, the RAM setting put back after
gfx_begin:
	IF NTC_CPMGFX
			ret						; CP/M: each line does its own (gfx_cpmdraw)
	ENDIF
			ld a, (gfx_base)
			cp #40
			ret nz
			push bc
			ld bc, #7FC0
			out (c), c
			pop bc
			ret
gfx_end:
	IF NTC_CPMGFX
			ret
	ENDIF
			ld a, (gfx_base)
			cp #40
			ret nz
			ld bc, (ntc_rampt)
			out (c), c
			ret

; gfx_width - HL = the screen's width in pixels in this mode
gfx_width:
			ld a, (ntc_smode)
			ld hl, 160
			or a
			ret z
			add hl, hl
			dec a
			ret z
			add hl, hl
			ret

; gfx_line - (gfx_x0, gfx_y0) to (gfx_x1, gfx_y1), pixels of this mode
gfx_line:
			ld a, (gfx_clip)
			or a
			jr z, gfx_l_go
			call gfx_width
			ex de, hl
			ld hl, (gfx_x0)
			call gfx_chk
			ret c
			ld hl, (gfx_x1)
			call gfx_chk
			ret c
			ld de, 200
			ld hl, (gfx_y0)
			call gfx_chk
			ret c
			ld hl, (gfx_y1)
			call gfx_chk
			ret c
gfx_l_go:
			ld hl, (gfx_x1)			; left to right
			ld de, (gfx_x0)
			or a
			sbc hl, de
			jr nc, gfx_l_lr
			ld hl, (gfx_x0)
			ld de, (gfx_x1)
			ld (gfx_x0), de
			ld (gfx_x1), hl
			ld hl, (gfx_y0)
			ld de, (gfx_y1)
			ld (gfx_y0), de
			ld (gfx_y1), hl
			ld hl, (gfx_x1)
			ld de, (gfx_x0)
			or a
			sbc hl, de
gfx_l_lr:
			ld (gfx_dx), hl
			ld hl, (gfx_y1)
			ld de, (gfx_y0)
			or a
			sbc hl, de
			ld a, 0
			jr nc, gfx_l_dy
			call gfx_neg
			ld a, 1
gfx_l_dy:
			ld (gfx_sy), a
			ld (gfx_dy), hl
			call gfx_pat			; IYL = the pen's pattern in this mode
			ld a, (gfx_y0)			; HL = the address of (x0, y0)
			ld c, a
			and #F8
			ld l, a
			ld h, 0
			add hl, hl
			ld d, h
			ld e, l
			add hl, hl
			add hl, hl
			add hl, de				; (y / 8) * 80
			ld a, c
			and 7
			add a, a
			add a, a
			add a, a
			ld c, a
			ld a, (gfx_base)
			add a, c
			add a, h
			ld h, a
			ld de, (gfx_x0)			; + x / pixels a byte, C = the marker
			ld a, (ntc_smode)
			or a
			jr nz, gfx_l_m12
			ld c, #AA
			srl d
			rr e
			jr nc, gfx_l_adr
			ld c, #55
			jr gfx_l_adr
gfx_l_m12:
			dec a
			ld a, e
			jr nz, gfx_l_m2
			and 3
			ld b, a
			ld c, #88
			srl d
			rr e
			srl d
			rr e
			jr gfx_l_sh
gfx_l_m2:
			and 7
			ld b, a
			ld c, #80
			srl d
			rr e
			srl d
			rr e
			srl d
			rr e
gfx_l_sh:
			ld a, b
			or a
			jr z, gfx_l_adr
gfx_l_shl:
			rrc c
			djnz gfx_l_shl
gfx_l_adr:
			add hl, de
	IF NTC_CPMGFX
			jp gfx_cpmdraw
	ELSE
			call gfx_begin
			call gfx_l_draw
			jp gfx_end
	ENDIF
; >gfxhi - CP/M: the compiler copies from here to <gfxhi into common memory
; (GFH_AT, #C000), labels gfx_ renamed gfh_: the copy CP/M Plus draws with
gfx_dx:			dw 0
gfx_dy:			dw 0
gfx_out:		db 0
gfx_sy:			db 0			; 0 down, 1 up
	IF NTC_CPMGFX
; gfx_go (run as gfh_go, in common memory) - CP/M Plus: draw the line with
; RAM configuration C1 (the screen, block 1, at #4000), on a stack in common
; memory (C1 takes away the program's own #0000-#BFFF), then C2 back
gfx_go:
			ld (gfx_hsp), sp
			ld sp, gfx_hstk
			ld a, i					; P/V = interrupts on: off while C1 is in
			di
			push af
			ld a, c
			ld bc, #7FC1
			out (c), c
			ld c, a
			call gfx_l_draw
			ld bc, #7FC2
			out (c), c
			pop af
			ld sp, (gfx_hsp)
			ret po
			ei
			ret
gfx_hsp:		dw 0
				ds 24
gfx_hstk:
	ENDIF
gfx_l_draw:
			ld a, c					; the first pixel
			and iyl
			xor (hl)
			ld (hl), a
			push hl
			ld hl, (gfx_dx)
			ld de, (gfx_dy)
			or a
			sbc hl, de
			pop hl
			jp c, gfx_ymaj
			ld de, (gfx_dy)			; x major: count dx, error dx / 2, IX = dy
			push de
			pop ix
			ld de, (gfx_dx)
			call gfx_cnt
			ret z
			ld de, (gfx_dx)
			srl d
			rr e
			ld a, (gfx_sy)
			or a
			jp nz, gfx_xu
gfx_xd:
			rrc c					; x + 1
			jr nc, gfx_xd1
			inc hl
gfx_xd1:
			ld a, e					; error - dy
			sub ixl
			ld e, a
			ld a, d
			sbc a, ixh
			ld d, a
			jp p, gfx_xd2
			push hl					; error + dx, y + 1
			ld hl, (gfx_dx)
			add hl, de
			ex de, hl
			pop hl
			ld a, h
			add a, 8
			ld h, a
			and #38
			jr nz, gfx_xd2
			push de
			ld de, #C050
			add hl, de
			pop de
gfx_xd2:
			ld a, c
			and iyl
			xor (hl)
			ld (hl), a
			djnz gfx_xd
			ld a, (gfx_out)
			dec a
			ld (gfx_out), a
			jr nz, gfx_xd
			ret
gfx_xu:
			rrc c
			jr nc, gfx_xu1
			inc hl
gfx_xu1:
			ld a, e
			sub ixl
			ld e, a
			ld a, d
			sbc a, ixh
			ld d, a
			jp p, gfx_xu2
			push hl					; error + dx, y - 1
			ld hl, (gfx_dx)
			add hl, de
			ex de, hl
			pop hl
			ld a, h
			sub 8
			ld h, a
			and #38
			cp #38
			jr nz, gfx_xu2
			push de
			ld de, #3FB0
			add hl, de
			pop de
gfx_xu2:
			ld a, c
			and iyl
			xor (hl)
			ld (hl), a
			djnz gfx_xu
			ld a, (gfx_out)
			dec a
			ld (gfx_out), a
			jr nz, gfx_xu
			ret
gfx_ymaj:
			ld de, (gfx_dx)			; y major: count dy, error dy / 2, IX = dx
			push de
			pop ix
			ld de, (gfx_dy)
			call gfx_cnt
			ret z
			ld de, (gfx_dy)
			srl d
			rr e
			ld a, (gfx_sy)
			or a
			jp nz, gfx_yu
gfx_yd:
			ld a, h					; y + 1
			add a, 8
			ld h, a
			and #38
			jr nz, gfx_yd1
			push de
			ld de, #C050
			add hl, de
			pop de
gfx_yd1:
			ld a, e					; error - dx
			sub ixl
			ld e, a
			ld a, d
			sbc a, ixh
			ld d, a
			jp p, gfx_yd2
			push hl					; error + dy, x + 1
			ld hl, (gfx_dy)
			add hl, de
			ex de, hl
			pop hl
			rrc c
			jr nc, gfx_yd2
			inc hl
gfx_yd2:
			ld a, c
			and iyl
			xor (hl)
			ld (hl), a
			djnz gfx_yd
			ld a, (gfx_out)
			dec a
			ld (gfx_out), a
			jr nz, gfx_yd
			ret
gfx_yu:
			ld a, h					; y - 1
			sub 8
			ld h, a
			and #38
			cp #38
			jr nz, gfx_yu1
			push de
			ld de, #3FB0
			add hl, de
			pop de
gfx_yu1:
			ld a, e
			sub ixl
			ld e, a
			ld a, d
			sbc a, ixh
			ld d, a
			jp p, gfx_yu2
			push hl
			ld hl, (gfx_dy)
			add hl, de
			ex de, hl
			pop hl
			rrc c
			jr nc, gfx_yu2
			inc hl
gfx_yu2:
			ld a, c
			and iyl
			xor (hl)
			ld (hl), a
			djnz gfx_yu
			ld a, (gfx_out)
			dec a
			ld (gfx_out), a
			jr nz, gfx_yu
			ret
; DE = a count: B = its low byte (0 = 256), gfx_out = rounds of B; Z when 0
gfx_cnt:
			ld a, d
			or e
			ret z
			ld b, e
			ld a, e
			or a
			jr z, gfx_cn1
			inc d
gfx_cn1:
			ld a, d
			ld (gfx_out), a
			or 1
			ret
; <gfxhi
	IF NTC_CPMGFX
; gfx_cpmdraw - CP/M on an Amstrad CPC, mode 2 (the console's). CP/M 2.2: the
; screen is #C000 of the program's own 64K: drawn there. CP/M Plus: the program
; runs in RAM configuration C2 (blocks 4-7) and the screen is block 1, at #4000
; only in C1 (blocks 0, 1, 2, 7), where nothing of the program but #C000-#FFFF
; (block 7, common) is left: the first line copies the loop to GFH_AT, and
; each line copies its numbers there and draws with the copy (gfh_go)
gfx_cpmdraw:
			ld a, (gfx_cpm)
			or a
			call z, gfx_cpmver
			cp #30
			jp c, gfx_l_draw		; 2.2
			ld a, h					; Plus: the address worked out for #C000 (gfx_base): #4000 in C1
			sub #80
			ld h, a
			push bc
			push hl
			ld hl, gfx_dx
			ld de, gfh_dx
			ld bc, 6
			ldir
			pop hl
			pop bc
			jp gfh_go
; gfx_cpmver - A = gfx_cpm = the CP/M version (BDOS 12: #22, #31); Plus: the
; copy put in common memory, the heap kept below GFH_AT
gfx_cpmver:
			push bc
			push de
			push hl
			push ix
			push iy
			ld a, i					; P/V = interrupts on (BDOS may turn them on)
			push af
			ld c, 12
			call 5
			di
			pop af
			jp po, gfx_cv1
			ei
gfx_cv1:
			pop iy
			pop ix
			ld a, l
			cp #30
			jr c, gfx_cv2
			ld hl, gfh_src
			ld de, GFH_AT
			ld bc, gfh_end - gfh_start
			ldir
			ld hl, GFH_AT
			ld (ntc_cpmtop), hl
			ld a, #31
gfx_cv2:
			ld (gfx_cpm), a
			pop hl
			pop de
			pop bc
			ret
gfx_cpm:		db 0			; the CP/M version, 0 = not looked at yet
	ENDIF
; HL = a coordinate, DE = the limit: carry when HL is not 0 .. DE - 1
gfx_chk:
			bit 7, h
			scf
			ret nz
			or a
			sbc hl, de
			ccf
			ret
gfx_neg:
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
			ret
; gfx_pat - IYL = the pen's bits for this mode (both / all pixels of a byte)
gfx_pat:
			ld a, (gfx_pen)
			ld b, a
			ld a, (ntc_smode)
			or a
			jr z, gfx_pt0
			dec a
			jr z, gfx_pt1
			ld a, b					; mode 2: pen 1 = every bit
			and 1
			jr z, gfx_ptset
			ld a, #FF
			jr gfx_ptset
gfx_pt1:
			xor a					; mode 1: pen bit 0 in the high nibble, bit 1 low
			bit 0, b
			jr z, gfx_pt1b
			or #F0
gfx_pt1b:
			bit 1, b
			jr z, gfx_ptset
			or #0F
			jr gfx_ptset
gfx_pt0:
			xor a					; mode 0: bit 0 -> 7, 1 -> 3, 2 -> 5, 3 -> 1 (and one
			bit 0, b				; to the right for the second pixel)
			jr z, gfx_p01
			or #C0
gfx_p01:
			bit 1, b
			jr z, gfx_p02
			or #0C
gfx_p02:
			bit 2, b
			jr z, gfx_p03
			or #30
gfx_p03:
			bit 3, b
			jr z, gfx_ptset
			or #03
gfx_ptset:
			ld iyl, a
			ret

; gfx_flip - double buffering: wait for the frame flyback, show the screen
; just drawn, draw on the other one from now on
gfx_flip:
			ld a, (gfx_dbl)
			or a
			ret z
			ld b, #F5				; wait for the vertical sync to start
gfx_fw1:
			in a, (c)
			rra
			jr c, gfx_fw1
gfx_fw2:
			in a, (c)
			rra
			jr nc, gfx_fw2
			ld a, (gfx_base)		; show it: CRTC R12 #30 (#C000) / #10 (#4000)
			cp #C0
			ld a, #30
			ld e, #40
			jr z, gfx_fl1
			ld a, #10
			ld e, #C0
gfx_fl1:
			ld (gfx_shown), a
			ld bc, #BC0C
			out (c), c
			inc b
			out (c), a
			ld a, e
			ld (gfx_base), a
			ret

; gfx_double - A = 1: double buffering on (the screen at #C000 copied to
; #4000, which is drawn on first), 0: off (#C000 shown and drawn on)
gfx_double:
	IF NTC_CPMGFX
			ret						; CP/M: one screen
	ENDIF
			or a
			jr z, gfx_dboff
			ld (gfx_dbl), a
			ld a, #C0				; show #C000 now
			call gfx_dshow
			ld bc, #7FC0
			out (c), c
			ld hl, #C000
			ld de, #4000
			ld bc, #4000
			ldir
			ld bc, (ntc_rampt)
			out (c), c
			ld a, #40
			ld (gfx_base), a
			ret
gfx_dboff:
			ld (gfx_dbl), a
			ld a, #C0
			ld (gfx_base), a
gfx_dshow:
			ld a, #30
			ld (gfx_shown), a
			ld bc, #BC0C
			out (c), c
			inc b
			out (c), a
			ret

; gfx_copyrows - A = text rows from the top: copied from #C000 to #4000 (so
; text printed while double buffering shows on both screens)
gfx_copyrows:
	IF NTC_CPMGFX
			ret						; CP/M: one screen
	ENDIF
			or a
			ret z
			ld e, a
			ld bc, #7FC0
			out (c), c
			ld d, 8					; 8 lines a row
			ld hl, #C000
gfx_cr1:
			push hl
			push de
			ld b, 0
			ld c, e					; rows * 80 bytes
			ld a, 80
			ld h, b
			ld l, b
gfx_cr2:
			add hl, bc
			dec a
			jr nz, gfx_cr2
			ld b, h
			ld c, l
			pop de
			pop hl
			push hl
			push de
			push hl
			ld a, h
			sub #80
			ld d, a
			ld e, l
			pop hl
			ldir
			pop de
			pop hl
			ld a, h
			add a, 8
			ld h, a
			dec d
			jr nz, gfx_cr1
			ld bc, (ntc_rampt)
			out (c), c
			ret

;## ntc_islots ntc_data @shared
; ------------------------------------------------------------
; ntc_islots - interrupt classes (Option Class Interrupt rate | Frame | Share n):
; up to 16 classes whose Tick Sub runs at the next safe point after it is due
; (normal mode). Slot n, 8 bytes at ntc_isl + n * 8:
;   +0 count (dw)  +2 reload (dw: interrupts between runs, 0 = every frame,
;   #8000 + weight = a shared class)  +4 running (db: Tick started, its return
;   stub clears it)  +5 due (db)  +6 Tick's call stub (dw)
; Fixed classes (a rate, Frame) are counted every interrupt. Shared classes take
; turns in the interrupts no fixed class fell due in: the current one is marked
; due on each such interrupt until it has had its weight of turns, then the
; next shared one. The start code fills the slots and puts ntc_isl_tick in
; ntc_irqv, which the platform's interrupt handler calls. The counts start a
; slot apart so classes of the same rate take turns.
; ------------------------------------------------------------
ntc_isln:		db 0			; slots in use
ntc_isldue:		db 0			; 1 = a slot may be due
ntc_islvs:		db 0			; vertical sync at the last interrupt
ntc_islfr:		db 0			; 1 = this interrupt is the frame's (sync just started)
ntc_islph:		db 0			; interrupts since the frame's (0-5)
ntc_islfx:		db 0			; 1 = a fixed class fell due in this interrupt
ntc_islsc:		db 0			; the shared class having its turns (slot number)
ntc_islsw:		db 0			; turns it has left
ntc_islshn:		db 0			; shared classes (0 = none)
ntc_isl:		ds 128			; 16 slots

; ntc_isl_tick - from the interrupt handler (call, real stack): count each
; slot, mark the ones due. Keeps BC, DE, IX, IY.
ntc_isl_tick:
			push bc
			push de
			ld b, #F5				; PPI port B bit 0: vertical sync
			in a, (c)
			and 1
			ld e, a
			ld a, (ntc_islvs)
			cpl
			and e
			ld d, a					; 1 = the sync started since the last interrupt
			ld a, e
			ld (ntc_islvs), a
			ld a, (ntc_islph)		; a frame is 6 interrupts: count them, so a frame is
			inc a					; still seen when this interrupt came in after the
			cp 6					; sync had ended (taken late: a long keyword); the
			jr c, ntc_it_ph			; sync puts the count back to 0
			xor a
ntc_it_ph:
			bit 0, d
			jr z, ntc_it_ph2
			xor a
ntc_it_ph2:
			ld (ntc_islph), a
			or a
			ld a, 0
			jr nz, ntc_it_fr
			inc a
ntc_it_fr:
			ld (ntc_islfr), a
			xor a
			ld (ntc_islfx), a
			ld a, (ntc_isln)
			or a
			jp z, ntc_it_end
			ld b, a
			ld hl, ntc_isl
ntc_it_lp:
			push hl
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			bit 7, d				; a shared class: the turns below mark it
			jr nz, ntc_it_nx
			ld a, d
			or e
			jr nz, ntc_it_rate
			ld a, (ntc_islfr)		; every frame: when the sync starts
			or a
			jr z, ntc_it_nx
			jr ntc_it_due
ntc_it_rate:
			ld e, (hl)
			inc hl
			ld d, (hl)
			dec de
			ld (hl), d
			dec hl
			ld (hl), e
			ld a, d
			or e
			jr nz, ntc_it_nx
			push hl					; due: count again from the reload
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			dec hl
ntc_it_due:
			push hl
			ld de, 5
			add hl, de
			ld (hl), 1
			pop hl
			ld a, 1
			ld (ntc_isldue), a
			ld (ntc_islfx), a
ntc_it_nx:
			ld de, 8
			add hl, de
			djnz ntc_it_lp
			; shared classes: an interrupt no fixed class used is a turn
			ld a, (ntc_islfx)
			or a
			jp nz, ntc_it_end
			ld a, (ntc_islshn)
			or a
			jp z, ntc_it_end
			ld a, (ntc_islsw)
			or a
			jr nz, ntc_it_take
			ld a, (ntc_islsc)		; its turns are used: the next shared class
ntc_it_find:
			inc a
			ld hl, ntc_isln
			cp (hl)
			jr c, ntc_it_fi2
			xor a
ntc_it_fi2:
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_isl + 2
			add hl, de
			ld e, (hl)				; E = the weight
			inc hl
			bit 7, (hl)
			jr z, ntc_it_find		; not shared (there is one: ntc_islshn)
			ld (ntc_islsc), a
			ld a, e
ntc_it_take:
			dec a
			ld (ntc_islsw), a
			ld a, (ntc_islsc)
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_isl + 5
			add hl, de
			ld (hl), 1				; due
			ld a, 1
			ld (ntc_isldue), a
ntc_it_end:
			pop de
			pop bc
			ret

;## kw_bssinit ntc_data ntc_plat_memtop ntc_plat_screen kw_stop @shared
;kw_bssinit, <start>, <size>  - the start of the main thread: the program's arrays live after
;  it (from ntc_end, not in its file). Check they fit under the platform's top (and 256 bytes
;  under the real stack when that is above them), then clear them. Too big: a message, the
;  program stops.
kw_bssinit:
			pop hl
			ld (ntc_bsa), hl
			pop bc
			ld (ntc_bsz), bc
			ld (ntc_bsp), sp
			ld sp, (ntc_csp)
			add hl, bc				; HL = their end
			ex de, hl
			call ntc_plat_memtop	; HL = the platform's top
			or a
			sbc hl, de
			jr c, ntc_bs_big
			ld hl, (ntc_csp)		; the real stack, when above them
			ld bc, (ntc_bsa)
			or a
			sbc hl, bc
			jr c, ntc_bs_ok
			ld hl, (ntc_csp)
			ld bc, -256
			add hl, bc
			or a
			sbc hl, de
			jr c, ntc_bs_big
ntc_bs_ok:
			ld bc, (ntc_bsz)
			ld a, b
			or c
			jr z, ntc_bs_done
			ld hl, (ntc_bsa)
			ld (hl), 0
			dec bc
			ld a, b
			or c
			jr z, ntc_bs_done
			ld d, h
			ld e, l
			inc de
			ldir
ntc_bs_done:
			ld sp, (ntc_bsp)
			ret
ntc_bs_big:
			ld hl, ntc_bstxt
ntc_bs_pl:
			ld a, (hl)
			or a
			jr z, ntc_bs_stop
			inc hl
			ld (ntc_bsa), hl
			ld ix, ntc_bs_pn
			jp ntc_plat_putc
ntc_bs_pn:
			ld hl, (ntc_bsa)
			jr ntc_bs_pl
ntc_bs_stop:
			ld ix, kw_stop
			jp ntc_plat_newline
ntc_bsa:		dw 0
ntc_bsz:		dw 0
ntc_bsp:		dw 0
ntc_bstxt:		db "Not enough memory for the arrays", 0

;## ntc_list ntc_memcore @shared @far
; ------------------------------------------------------------
; ntc_list - the List class: linked lists in the Memory class's heap (D
; pages with CPCExpansion, main RAM with Small), handles and nodes are far
; pointers (Longs: address, page). Nodes come from pools: a list takes a
; block of up to 16000 bytes at a time and cuts it into nodes on its free
; chain, so getting / giving back a node is a pointer swap.
;   header (20 bytes): +0 first, +4 last, +8 count, +10 data bytes a node,
;                      +12 free chain, +16 pools
;   pool:  +0 the next pool, then nodes
;   node:  +0 next, +4 previous, +8 the data
; Runs through mem_go like the Memory class (real stack); the window is
; put back at the end.
; ------------------------------------------------------------
LST_FIRST	equ 0
LST_LAST	equ 4
LST_COUNT	equ 8
LST_SIZE	equ 10
LST_FREE	equ 12
LST_POOLS	equ 16
LST_HDR		equ 20
LST_NEXT	equ 0
LST_PREV	equ 4
LST_DATA	equ 8

lst_h:			ds 4			; the list's header
lst_n:			ds 4			; nodes, far pointers (address, page)
lst_m:			ds 4
lst_k:			ds 4
lst_p:			ds 4
lst_q:			ds 4
lst_s1:			ds 4
lst_s2:			ds 4
lst_size:		dw 0
lst_v:			dw 0
lst_cnt:		dw 0
lst_key:		dw 0

; lst_at - HL = a far pointer variable: its page in, HL = its address
lst_at:
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			or h
			call nz, mem_sel
			ex de, hl
			ret
; lst_rd - HL = far variable, DE = offset: HL = the word there
lst_rd:
			push de
			call lst_at
			pop de
			add hl, de
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ret
; lst_wr - HL = far variable, DE = offset, BC = the word to write there
lst_wr:
			push bc
			push de
			call lst_at
			pop de
			add hl, de
			pop bc
			ld (hl), c
			inc hl
			ld (hl), b
			ret
; lst_rd4 - HL = far variable, DE = offset, BC = a variable: the far pointer there into it
lst_rd4:
			push bc
			push de
			call lst_at
			pop de
			add hl, de
			pop de
			ld bc, 4
			ldir
			ret
; lst_wr4 - HL = far variable, DE = offset, BC = a variable: it goes into the field
lst_wr4:
			push bc
			push de
			call lst_at
			pop de
			add hl, de
			ex de, hl
			pop hl
			ld bc, 4
			ldir
			ret
; lst_null - HL = far variable: Z when it is 0
lst_null:
			ld a, (hl)
			inc hl
			or (hl)
			inc hl
			or (hl)
			inc hl
			or (hl)
			ret
; lst_cp4 - HL = from, DE = to (variables)
lst_cp4:
			ld bc, 4
			ldir
			ret
; lst_zero - HL = a variable: 0
lst_zero:
			xor a
			ld (hl), a
			inc hl
			ld (hl), a
			inc hl
			ld (hl), a
			inc hl
			ld (hl), a
			ret
; lst_arg - HL = a Long argument's address, DE = a variable: copied, checked
; (not 0, a page this machine has, an address in the window) else BadPage
lst_arg:
			push hl
			push de
			call lst_cp4
			pop hl
			call lst_null
			jp z, mem_chk_bad
			pop hl
			jp mem_far
; lst_back - the window as it was; lst_retn / lst_ret0 - the result (Long)
lst_back:
			ld hl, (mem_keep)
			jp mem_sel
lst_retn:
			call lst_back
			ld hl, (lst_n + 2)
			ld (mem_hi), hl
			ld hl, (lst_n)
			ret
lst_ret0:
			call lst_back
			ld hl, 0
			ld (mem_hi), hl
			ret
; lst_count - A = 1 / -1: the header's count + A
lst_count:
			push af
			ld hl, lst_h
			ld de, LST_COUNT
			call lst_rd
			pop af
			ld b, h
			ld c, l
			inc bc
			dec a
			jr z, lst_ct_up
			dec bc
			dec bc
lst_ct_up:
			ld hl, lst_h
			ld de, LST_COUNT
			jp lst_wr

; lst_newnode - a node from lst_h's free chain (a new pool when it is empty),
; cleared, in lst_n. NZ; Z = no room
lst_newnode:
			ld hl, lst_h
			ld de, LST_FREE
			ld bc, lst_n
			call lst_rd4
			ld hl, lst_n
			call lst_null
			jp nz, lst_nn_take
			ld hl, lst_h			; a new pool: as many nodes as fit in 16000 bytes
			ld de, LST_SIZE
			call lst_rd
			ld de, LST_DATA
			add hl, de
			ld (lst_v), hl			; node size
			ex de, hl
			ld hl, 15996
			ld bc, 0
lst_nn_div:
			or a
			sbc hl, de
			jr c, lst_nn_n
			inc bc
			jr lst_nn_div
lst_nn_n:
			ld (lst_cnt), bc
			ld hl, 4
			ld de, (lst_v)
lst_nn_mul:
			add hl, de
			dec bc
			ld a, b
			or c
			jr nz, lst_nn_mul
			ld (mem_a1), hl
			call mem_alloc
			ld a, h
			or l
			ret z
			ld (lst_m), hl			; the pool
			ld hl, (mem_hi)
			ld (lst_m + 2), hl
			ld hl, lst_h			; pool.next = the pools so far, pools = it
			ld de, LST_POOLS
			ld bc, lst_k
			call lst_rd4
			ld hl, lst_m
			ld de, 0
			ld bc, lst_k
			call lst_wr4
			ld hl, lst_h
			ld de, LST_POOLS
			ld bc, lst_m
			call lst_wr4
			ld hl, lst_m			; its nodes, each pointing at the next
			call lst_at
			ld de, 4
			add hl, de
			push hl
			ld bc, (lst_cnt)
lst_nn_link:
			dec bc
			ld a, b
			or c
			jr z, lst_nn_last
			push bc
			ld d, h
			ld e, l
			ld bc, (lst_v)
			ex de, hl
			add hl, bc
			ex de, hl				; DE = the next node
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld a, (lst_m + 2)
			ld (hl), a
			inc hl
			ld a, (lst_m + 3)
			ld (hl), a
			ex de, hl
			pop bc
			jr lst_nn_link
lst_nn_last:
			call lst_zero
			pop hl
			ld (lst_n), hl
			ld hl, (lst_m + 2)
			ld (lst_n + 2), hl
lst_nn_take:
			ld hl, lst_n			; the free chain goes on from its next
			ld de, LST_NEXT
			ld bc, lst_k
			call lst_rd4
			ld hl, lst_h
			ld de, LST_FREE
			ld bc, lst_k
			call lst_wr4
			ld hl, lst_h			; cleared: next, previous, data
			ld de, LST_SIZE
			call lst_rd
			ld de, LST_DATA - 1
			add hl, de
			push hl
			ld hl, lst_n
			call lst_at
			pop bc
			ld (hl), 0
			ld d, h
			ld e, l
			inc de
			ldir
			ld a, 1
			or a
			ret

; Create(size): a new empty list of nodes with size data bytes; 0 = no room
lst_create:
			ld hl, (mem_a1)
			ld (lst_size), hl
			ld de, 15988 + 1
			or a
			sbc hl, de
			jp nc, lst_ret0
			ld hl, LST_HDR
			ld (mem_a1), hl
			call mem_alloc
			ld a, h
			or l
			jp z, lst_ret0
			ld (lst_n), hl
			ld hl, (mem_hi)
			ld (lst_n + 2), hl
			ld hl, lst_n
			call lst_at
			ld b, LST_HDR
lst_cr_clr:
			ld (hl), 0
			inc hl
			djnz lst_cr_clr
			ld hl, lst_n
			ld de, LST_SIZE
			ld bc, (lst_size)
			call lst_wr
			jp lst_retn

; Append(h) / Prepend(h): a new node at the end / the start; 0 = no room
lst_append:
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			call lst_newnode
			jp z, lst_ret0
			ld hl, lst_h			; node.prev = last
			ld de, LST_LAST
			ld bc, lst_m
			call lst_rd4
			ld hl, lst_n
			ld de, LST_PREV
			ld bc, lst_m
			call lst_wr4
			ld hl, lst_m
			call lst_null
			ld hl, lst_h
			ld de, LST_FIRST
			jr z, lst_ap_link		; empty: it is the first too
			ld hl, lst_m
			ld de, LST_NEXT
lst_ap_link:
			ld bc, lst_n
			call lst_wr4
			ld hl, lst_h
			ld de, LST_LAST
			ld bc, lst_n
			call lst_wr4
lst_added:
			ld a, 1
			call lst_count
			jp lst_retn

lst_prepend:
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			call lst_newnode
			jp z, lst_ret0
			ld hl, lst_h			; node.next = first
			ld de, LST_FIRST
			ld bc, lst_m
			call lst_rd4
			ld hl, lst_n
			ld de, LST_NEXT
			ld bc, lst_m
			call lst_wr4
			ld hl, lst_m
			call lst_null
			ld hl, lst_h
			ld de, LST_LAST
			jr z, lst_pp_link		; empty: it is the last too
			ld hl, lst_m
			ld de, LST_PREV
lst_pp_link:
			ld bc, lst_n
			call lst_wr4
			ld hl, lst_h
			ld de, LST_FIRST
			ld bc, lst_n
			call lst_wr4
			jp lst_added

; InsertAfter(h, node): a new node after that one (node 0: at the start)
lst_insert:
			ld hl, (mem_a2)
			call lst_null
			jp z, lst_prepend
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			ld hl, (mem_a2)
			ld de, lst_m
			call lst_arg
			call lst_newnode
			jp z, lst_ret0
			ld hl, lst_m			; k = m.next
			ld de, LST_NEXT
			ld bc, lst_k
			call lst_rd4
			ld hl, lst_n			; n.prev = m, n.next = k, m.next = n
			ld de, LST_PREV
			ld bc, lst_m
			call lst_wr4
			ld hl, lst_n
			ld de, LST_NEXT
			ld bc, lst_k
			call lst_wr4
			ld hl, lst_m
			ld de, LST_NEXT
			ld bc, lst_n
			call lst_wr4
			ld hl, lst_k			; k.prev = n, or last = n
			call lst_null
			ld hl, lst_h
			ld de, LST_LAST
			jr z, lst_in_link
			ld hl, lst_k
			ld de, LST_PREV
lst_in_link:
			ld bc, lst_n
			call lst_wr4
			jp lst_added

; Delete(h, node): out of the list, back on its free chain. OK
lst_delete:
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			ld hl, (mem_a2)
			ld de, lst_n
			call lst_arg
			ld hl, lst_n
			ld de, LST_NEXT
			ld bc, lst_k
			call lst_rd4
			ld hl, lst_n
			ld de, LST_PREV
			ld bc, lst_m
			call lst_rd4
			call lst_unlink
			ld a, -1
			call lst_count
			ld hl, lst_h			; node.next = the free chain, free = node
			ld de, LST_FREE
			ld bc, lst_k
			call lst_rd4
			ld hl, lst_n
			ld de, LST_NEXT
			ld bc, lst_k
			call lst_wr4
			ld hl, lst_h
			ld de, LST_FREE
			ld bc, lst_n
			call lst_wr4
			call lst_back
			ld hl, 0
			ret
; lst_unlink - lst_m (previous) and lst_k (next) of a node: joined; the header's first / last
lst_unlink:
			ld hl, lst_m
			call lst_null
			ld hl, lst_h
			ld de, LST_FIRST
			jr z, lst_ul_1
			ld hl, lst_m
			ld de, LST_NEXT
lst_ul_1:
			ld bc, lst_k
			call lst_wr4
			ld hl, lst_k
			call lst_null
			ld hl, lst_h
			ld de, LST_LAST
			jr z, lst_ul_2
			ld hl, lst_k
			ld de, LST_PREV
lst_ul_2:
			ld bc, lst_m
			jp lst_wr4

; First(h), Last(h): a node or 0. NextOf(node), PrevOf(node): a node or 0
lst_first:
			ld de, LST_FIRST
			jr lst_field
lst_last:
			ld de, LST_LAST
lst_field:
			push de
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			pop de
			ld hl, lst_h
			ld bc, lst_n
			call lst_rd4
			jp lst_retn
lst_nextof:
			ld de, LST_NEXT
			jr lst_field
lst_prevof:
			ld de, LST_PREV
			jr lst_field

; Count(h): nodes in the list
lst_countof:
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			ld hl, lst_h
			ld de, LST_COUNT
			call lst_rd
lst_rethl:
			push hl
			call lst_back
			pop hl
			ret

; GetWord(node, offset), GetByte(node, offset): from its data
lst_getword:
			call lst_data
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp lst_rethl
lst_getbyte:
			call lst_data
			ld l, (hl)
			ld h, 0
			jp lst_rethl
; SetWord node, offset, value / SetByte node, offset, value
lst_setword:
			call lst_data
			ld de, (mem_a3)
			ld (hl), e
			inc hl
			ld (hl), d
			jp lst_back
lst_setbyte:
			call lst_data
			ld a, (mem_a3)
			ld (hl), a
			jp lst_back
; lst_data - mem_a1 = a node's address (Long), mem_a2 = offset: its page in, HL = the byte
lst_data:
			ld hl, (mem_a1)
			ld de, lst_n
			call lst_arg
			ld hl, lst_n
			call lst_at
			ld de, LST_DATA
			add hl, de
			ld de, (mem_a2)
			add hl, de
			ret
; Data(node): a far pointer to its data (for Memory.Copy, ReadWord ...)
lst_dataof:
			ld hl, (mem_a1)
			ld de, lst_n
			call lst_arg
			ld hl, (lst_n)
			ld de, LST_DATA
			add hl, de
			ld (lst_n), hl
			jp lst_retn

; Search(h, offset, value): the first node whose word at offset is value, or 0
lst_search:
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			ld hl, lst_h
			ld de, LST_FIRST
			ld bc, lst_n
			call lst_rd4
lst_se_lp:
			ld hl, lst_n
			call lst_null
			jp z, lst_ret0
			ld hl, (mem_a2)
			ld de, LST_DATA
			add hl, de
			ex de, hl
			ld hl, lst_n
			call lst_rd
			ld de, (mem_a3)
			or a
			sbc hl, de
			jp z, lst_retn
			ld hl, lst_n
			ld de, LST_NEXT
			ld bc, lst_n
			call lst_rd4
			jr lst_se_lp

; Destroy(h): its pools and header back to the heap. OK
lst_destroy:
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			ld hl, lst_h
			ld de, LST_POOLS
			ld bc, lst_n
			call lst_rd4
lst_ds_lp:
			ld hl, lst_n
			call lst_null
			jr z, lst_ds_hdr
			ld hl, lst_n
			ld de, 0
			ld bc, lst_k
			call lst_rd4
			ld hl, lst_n
			ld (mem_a1), hl
			call mem_free
			ld hl, lst_k
			ld de, lst_n
			call lst_cp4
			jr lst_ds_lp
lst_ds_hdr:
			ld hl, lst_h
			ld (mem_a1), hl
			call mem_free
			call lst_back
			ld hl, 0
			ret

;## ntc_listsort ntc_list ntc_buf2k @shared @far
; Sort(h, offset): in order of the (signed) word at offset in each node's
; data, equal ones keeping their order. A radix sort: two passes over the
; list (the key's low byte, then its high byte with the sign bit flipped),
; each node going onto the end of one of 256 buckets, the buckets joined
; in order after each pass; then the previous links. The bucket heads and
; tails (far pointers) fill the 2K buffer (ntc_buf).
LST_HEADS	equ ntc_buf
LST_TAILS	equ ntc_buf + 1024

lst_ko:			dw 0			; the key's offset in a node
lst_byte:		db 0			; 0: the low byte, 1: the high byte
lst_bp:			dw 0
lst_cpg:		dw 0			; the page in the window (0: not known)

; lst_rs_sel - DE = a page (0: main memory, nothing to do): in the window.
; Keeps HL.
lst_rs_sel:
			ld a, d
			or e
			ret z
			ld a, (lst_cpg)
			cp e
			jr nz, lst_rs_sdo
			ld a, (lst_cpg + 1)
			cp d
			ret z
lst_rs_sdo:
			ld (lst_cpg), de
			push hl
			ex de, hl
			call mem_sel
			pop hl
			ret

lst_sort:
			ld hl, (mem_a1)
			ld de, lst_h
			call lst_arg
			ld hl, (mem_a2)
			ld de, LST_DATA
			add hl, de
			ld (lst_ko), hl
			xor a
			ld (lst_byte), a
			call lst_rs_pass
			ld a, 1
			ld (lst_byte), a
			call lst_rs_pass
			ld hl, lst_s2			; the previous links, and the last node
			call lst_zero
			ld hl, lst_h
			ld de, LST_FIRST
			ld bc, lst_n
			call lst_rd4
			ld hl, 0
			ld (lst_cpg), hl
lst_rs_fix:
			ld hl, (lst_n)
			ld a, h
			or l
			jr z, lst_rs_fixed
			ld de, (lst_n + 2)
			call lst_rs_sel
			ld e, (hl)				; k = its next
			inc hl
			ld d, (hl)
			inc hl
			ld (lst_k), de
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld (lst_k + 2), de
			ld de, (lst_s2)			; its previous = s2
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld de, (lst_s2 + 2)
			ld (hl), e
			inc hl
			ld (hl), d
			ld hl, (lst_n)			; s2 = the node, on to the next
			ld (lst_s2), hl
			ld hl, (lst_n + 2)
			ld (lst_s2 + 2), hl
			ld hl, (lst_k)
			ld (lst_n), hl
			ld hl, (lst_k + 2)
			ld (lst_n + 2), hl
			jr lst_rs_fix
lst_rs_fixed:
			ld hl, lst_h
			ld de, LST_LAST
			ld bc, lst_s2
			call lst_wr4
			call lst_back
			ld hl, 0
			ret

; one pass: every node onto its bucket's end, then the buckets joined
lst_rs_pass:
			ld hl, ntc_buf
			ld (hl), 0
			ld de, ntc_buf + 1
			ld bc, 2047
			ldir
			ld hl, lst_h
			ld de, LST_FIRST
			ld bc, lst_n
			call lst_rd4
			ld hl, 0
			ld (lst_cpg), hl
lst_rs_lp:
			ld hl, (lst_n)
			ld a, h
			or l
			jp z, lst_rs_cat
			ld de, (lst_n + 2)
			call lst_rs_sel
			ld e, (hl)				; k = its next
			inc hl
			ld d, (hl)
			inc hl
			ld (lst_k), de
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (lst_k + 2), de
			ld hl, (lst_n)			; A = its key byte
			ld de, (lst_ko)
			add hl, de
			ld a, (lst_byte)
			or a
			ld a, (hl)
			jr z, lst_rs_idx
			inc hl
			ld a, (hl)
			xor #80
lst_rs_idx:
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			ld de, LST_TAILS
			add hl, de				; HL = its bucket's tail
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld a, d
			or e
			jr z, lst_rs_empty
			inc hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			dec hl
			dec hl
			dec hl
			push hl
			ex de, hl				; the tail's next = the node
			ld d, b
			ld e, c
			call lst_rs_sel
			ld de, (lst_n)
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld de, (lst_n + 2)
			ld (hl), e
			inc hl
			ld (hl), d
			pop hl
			jr lst_rs_tail
lst_rs_empty:
			dec hl					; an empty bucket: its head = the node
			push hl
			ld de, -1024
			add hl, de
			ld de, (lst_n)
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld de, (lst_n + 2)
			ld (hl), e
			inc hl
			ld (hl), d
			pop hl
lst_rs_tail:
			ld de, (lst_n)			; its tail = the node
			ld (hl), e
			inc hl
			ld (hl), d
			inc hl
			ld de, (lst_n + 2)
			ld (hl), e
			inc hl
			ld (hl), d
			ld hl, (lst_k)			; on to the next
			ld (lst_n), hl
			ld hl, (lst_k + 2)
			ld (lst_n + 2), hl
			jp lst_rs_lp
lst_rs_cat:
			ld hl, lst_s1			; the buckets in order: s1 = first, s2 = the last tail
			call lst_zero
			ld hl, lst_s2
			call lst_zero
			ld hl, LST_HEADS
			ld (lst_bp), hl
lst_rs_clp:
			ld hl, (lst_bp)
			call lst_null
			jr z, lst_rs_cnx
			ld hl, lst_s2
			call lst_null
			jr nz, lst_rs_clink
			ld hl, (lst_bp)
			ld de, lst_s1
			call lst_cp4
			jr lst_rs_ct
lst_rs_clink:
			ld hl, lst_s2
			ld de, LST_NEXT
			ld bc, (lst_bp)
			call lst_wr4
lst_rs_ct:
			ld hl, (lst_bp)
			ld de, 1024
			add hl, de
			ld de, lst_s2
			call lst_cp4
lst_rs_cnx:
			ld hl, (lst_bp)
			ld de, 4
			add hl, de
			ld (lst_bp), hl
			ld de, LST_HEADS + 1024
			or a
			sbc hl, de
			jr nz, lst_rs_clp
			ld hl, lst_s2			; the last tail's next = 0
			call lst_null
			jr z, lst_rs_cend
			ld hl, lst_k
			call lst_zero
			ld hl, lst_s2
			ld de, LST_NEXT
			ld bc, lst_k
			call lst_wr4
lst_rs_cend:
			ld hl, lst_h
			ld de, LST_FIRST
			ld bc, lst_s1
			jp lst_wr4

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

;## kw_rndv ntc_rnd_seed ntc_div kw_rndl
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

;## kw_seedv ntc_rnd_seed kw_seedl
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

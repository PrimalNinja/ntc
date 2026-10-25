; ============================================================
; NTC Keyword Library - 45GS02 (MEGA65; vasm, oldstyle syntax: vasm6502_oldstyle -mega65)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
;
; NTC RULES ON THE 45GS02
;   SP = instruction pointer (the thread). The stack pointer is 16 bits
;   (CLE), so the thread can be anywhere in the CPU's 64K. RTS fetches the
;   next keyword: it pops a word and goes to word + 1, so a thread word is
;   the keyword's address - 1 (the compiler writes "dw kw_add-1, ...").
;   SP always points at the byte before the next thread word.
;   Keywords take their arguments off the thread left to right with PLA
;   (low byte, then high byte: NTC_POP zp does both) and end with RTS.
;   No JSR / PHA / PHP on the thread: a push would write into it.
;   Code that needs JSR runs on the real stack: NTC_RS saves the thread
;   position in ntc_ip and loads the real stack (ntc_csp), NTC_TS puts the
;   thread back (the macros are written by the compiler at the top of the
;   program). Arguments are taken off the thread before NTC_RS.
;   A label (a thread position) loaded into SP is label - 1: the branch
;   keywords take a label off the thread and subtract 1 (ntc_go).
;
; ONE MODE
;   Interrupts would push into the thread, so the CPU's I flag is set the
;   whole time (the platform turns every interrupt source off). Every
;   keyword is the turbo one; Turbo On / Off do nothing.
;
; DATA
;   Integer = 16 bits, Long = 32 bits, little endian (as the Z80 library).
;   A literal argument is the value itself (16 bits) in the thread; a Long
;   literal is the address of its 4 bytes. Addresses are 16 bits: the CPU's
;   64K (bank 0, I/O at $D000).
;
; REGISTERS (base page, $02-$4F): see ntc_data. A keyword may use any of
;   them; ntc_plat_* routines (JSR on the real stack) use A, X, Y and the
;   platform's $50-$6F only, so the library's survive them.
;
; COMPARES
;   Result is the Z flag. Z = true, NZ = false. A compare keyword ends with
;   LDA #0 (true) or LDA #1 (false) just before its RTS.
;
; SECTIONS
;   ";## name dep dep ..." starts a section, as in the Z80 library. The
;   platform file supplies the ntc_plat_* routines, called with JSR on the
;   real stack (end with RTS):
;     ntc_plat_putc (A = char 32-126), ntc_plat_newline, ntc_plat_backspace,
;     ntc_plat_cls, ntc_plat_mode (A), ntc_plat_locate (X = column, Y = row,
;     1 based), ntc_plat_scankey (A = key or 0), ntc_plat_getkey (A, waits),
;     ntc_plat_frame, ntc_plat_ticks (A = low, X = high), ntc_plat_exit
;   and ntc_curx, ntc_cury, ntc_scols (bytes).
; ============================================================

;## ntc_data @shared
; ------------------------------------------------------------
; The core every program has: the registers, the thread / real stack switch
; ------------------------------------------------------------
ntc_ip		equ $02			; the thread position while on the real stack
ntc_csp		equ $04			; the real stack (set at start)
z_p0		equ $06			; pointers
z_p1		equ $08
z_p2		equ $0A
z_p3		equ $0C
z_p4		equ $0E
z_p5		equ $10
z_a			equ $12			; 16 bit values
z_b			equ $14
z_c			equ $16
z_d			equ $18
z_e			equ $1A
z_f			equ $1C
z_g			equ $1E
z_l0		equ $20			; 32 bit values
z_l1		equ $24
z_l2		equ $28
z_l3		equ $2C
z_t0		equ $30			; bytes
z_t1		equ $31
z_t2		equ $32
z_t3		equ $33
z_t4		equ $34
z_t5		equ $35
z_t6		equ $36
z_t7		equ $37
z_q0		equ $40			; 32 bit (far) pointers
z_q1		equ $44
ntc_next:	rts						; continues the thread
ntc_ivar:	dw 0					; input / val: dest var
ntc_numbuf:	ds 16					; printint / long print: digits

;## ntc_d_inbuf @data
			db 40					; ntc_inbuf's capacity (as every string variable has)
ntc_inbuf:	ds 41					; inputint: typed text

;## ntc_jmp
; ------------------------------------------------------------
; branch tails: ntc_go takes a label off the thread and carries on there
; (SP = label - 1); ntc_goxy with the label in Y:X; ntc_skip2 steps over
; a label (not taken)
; ------------------------------------------------------------
ntc_go:
			pla
			tax
			pla
			tay
ntc_goxy:
			txa
			bne ntc_go_nb
			dey
ntc_go_nb:
			dex
			txs
			tys
			rts
ntc_skip2:
			pla
			pla
			rts

;## ntc_gstack
; ------------------------------------------------------------
; GOSUB return stack: 64 thread positions (SP values)
; ------------------------------------------------------------
ntc_gsi:	db 0
ntc_gslo:	ds 64
ntc_gshi:	ds 64

; ============================================================
; Flow
; ============================================================

;## kw_stop ntc_data ntc_plat_exit @shared
kw_stop:
			NTC_RS
			jmp ntc_plat_exit_stop		; a MEGA65 taken over has nowhere to go back to

;## kw_waitkey ntc_data ntc_plat_key ntc_plat_exit
; kw_waitkey - wait for a key (Option PressAnyKeyOnEnd, before kw_stop): the end is
; marked first (ntc_plat_exit), so the test tools see the program has finished
kw_waitkey:
			NTC_RS
			jsr ntc_plat_exit
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

;## kw_goto ntc_jmp
;kw_goto, <label>
kw_goto:
			jmp ntc_go

;## kw_goto_iffalse ntc_jmp
;kw_goto_iffalse, <label>  - branch if NZ (false)
kw_goto_iffalse:
			bne kw_gif_go
			pla
			pla
			rts
kw_gif_go:
			jmp ntc_go

;## kw_goto_iftrue ntc_jmp
;kw_goto_iftrue, <label>  - branch if Z (true)
kw_goto_iftrue:
			beq kw_git_go
			pla
			pla
			rts
kw_git_go:
			jmp ntc_go

;## kw_goto_ifzero ntc_jmp
;kw_goto_ifzero, <var>, <label>  - branch if var = 0
kw_goto_ifzero:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			iny
			ora (z_p0),y
			bne kw_giz_no
			jmp ntc_go
kw_giz_no:
			pla
			pla
			rts

;## kw_goto_ifnzero ntc_jmp
;kw_goto_ifnzero, <var>, <label>  - branch if var <> 0
kw_goto_ifnzero:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			iny
			ora (z_p0),y
			beq kw_ginz_no
			jmp ntc_go
kw_ginz_no:
			pla
			pla
			rts

;## kw_gosub ntc_gstack ntc_jmp
;kw_gosub, <label>  - return lands on the word after the label
kw_gosub:
			pla
			sta z_t0
			pla
			sta z_t1
			tsx
			stx z_t2
			tsy
			sty z_t3
			ldx ntc_gsi
			lda z_t2
			sta ntc_gslo,x
			lda z_t3
			sta ntc_gshi,x
			inx
			stx ntc_gsi
			ldx z_t0
			ldy z_t1
			jmp ntc_goxy

;## kw_return ntc_gstack
;kw_return
kw_return:
			ldx ntc_gsi
			dex
			stx ntc_gsi
			lda ntc_gshi,x
			tay
			lda ntc_gslo,x
			tax
			txs
			tys
			rts

;## ntc_for_jump ntc_jmp
; ------------------------------------------------------------
; tails for the FOR / NEXT keywords: z_a = the variable's value, z_b = the
; limit; the label is next on the thread. Signed.
; ------------------------------------------------------------
ntc_for_blt:					; take the label if limit < var
			lda z_b
			cmp z_a
			lda z_b+1
			sbc z_a+1
			bvc ntc_for_b1
			eor #$80
ntc_for_b1:
			bmi ntc_for_take
			jmp ntc_skip2
ntc_for_bgt:					; take if limit > var
			lda z_a
			cmp z_b
			lda z_a+1
			sbc z_b+1
			bvc ntc_for_b2
			eor #$80
ntc_for_b2:
			bmi ntc_for_take
			jmp ntc_skip2
ntc_for_bge:					; take if limit >= var
			lda z_b
			cmp z_a
			lda z_b+1
			sbc z_a+1
			bvc ntc_for_b3
			eor #$80
ntc_for_b3:
			bpl ntc_for_take
			jmp ntc_skip2
ntc_for_ble:					; take if limit <= var
			lda z_a
			cmp z_b
			lda z_a+1
			sbc z_b+1
			bvc ntc_for_b4
			eor #$80
ntc_for_b4:
			bpl ntc_for_take
			jmp ntc_skip2
ntc_for_take:
			jmp ntc_go

;## kw_forupl ntc_for_jump
;kw_forupl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting up: skip the loop if var > limit
kw_forupl:
			NTC_POP z_p0
			NTC_POP z_b
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			jmp ntc_for_blt

;## kw_forupv ntc_for_jump
;kw_forupv, <var>, <limit var>, <endlabel>
kw_forupv:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta z_a
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_a+1
			lda (z_p1),y
			sta z_b+1
			jmp ntc_for_blt

;## kw_fordnl ntc_for_jump
;kw_fordnl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting down: skip the loop if var < limit
kw_fordnl:
			NTC_POP z_p0
			NTC_POP z_b
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			jmp ntc_for_bgt

;## kw_fordnv ntc_for_jump
;kw_fordnv, <var>, <limit var>, <endlabel>
kw_fordnv:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta z_a
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_a+1
			lda (z_p1),y
			sta z_b+1
			jmp ntc_for_bgt

;## kw_next1l ntc_for_jump
;kw_next1l, <var>, <literal limit>, <toplabel>
;  NEXT for STEP 1: inc var, back to the top while var <= limit (past 32767: ends)
kw_next1l:
			NTC_POP z_p0
			NTC_POP z_b
ntc_next1:
			ldy #0
			lda (z_p0),y
			clc
			adc #1
			sta (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			adc #0
			sta (z_p0),y
			sta z_a+1
			bvs kw_n1_end
			jmp ntc_for_bge
kw_n1_end:
			jmp ntc_skip2

;## kw_next1v ntc_for_jump kw_next1l
;kw_next1v, <var>, <limit var>, <toplabel>
kw_next1v:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p1),y
			sta z_b+1
			jmp ntc_next1

;## kw_nextupl ntc_for_jump
;kw_nextupl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a positive STEP: add, back to the top while var <= limit
kw_nextupl:
			NTC_POP z_p0
			NTC_POP z_c
			NTC_POP z_b
ntc_nextup:
			ldy #0
			lda (z_p0),y
			clc
			adc z_c
			sta (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			adc z_c+1
			sta (z_p0),y
			sta z_a+1
			bvs kw_nu_end
			jmp ntc_for_bge
kw_nu_end:
			jmp ntc_skip2

;## kw_nextupv ntc_for_jump kw_nextupl
;kw_nextupv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextupv:
			NTC_POP z_p0
			NTC_POP z_c
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p1),y
			sta z_b+1
			jmp ntc_nextup

;## kw_nextdnl ntc_for_jump
;kw_nextdnl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a negative STEP: add, back to the top while var >= limit
kw_nextdnl:
			NTC_POP z_p0
			NTC_POP z_c
			NTC_POP z_b
ntc_nextdn:
			ldy #0
			lda (z_p0),y
			clc
			adc z_c
			sta (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			adc z_c+1
			sta (z_p0),y
			sta z_a+1
			bvs kw_nd_end
			jmp ntc_for_ble
kw_nd_end:
			jmp ntc_skip2

;## kw_nextdnv ntc_for_jump kw_nextdnl
;kw_nextdnv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextdnv:
			NTC_POP z_p0
			NTC_POP z_c
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p1),y
			sta z_b+1
			jmp ntc_nextdn

;## kw_forentry ntc_for_jump
;kw_forentry, <var>, <stepvar>, <limvar>, <endlabel>
;  skip the loop if var is already past lim for the step sign
kw_forentry:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			sta z_a
			lda (z_p2),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_a+1
			lda (z_p2),y
			sta z_b+1
			lda (z_p1),y				; the step's sign
			bmi kw_fe_neg
			jmp ntc_for_blt
kw_fe_neg:
			jmp ntc_for_bgt

;## kw_fornext ntc_for_jump
;kw_fornext, <var>, <stepvar>, <limvar>, <toplabel>
;  var += step, loop back while var has not passed lim
kw_fornext:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda (z_p1),y
			sta z_c
			lda (z_p2),y
			sta z_b
			iny
			lda (z_p1),y
			sta z_c+1
			lda (z_p2),y
			sta z_b+1
			ldy #0
			lda (z_p0),y
			clc
			adc z_c
			sta (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			adc z_c+1
			sta (z_p0),y
			sta z_a+1
			bvs kw_fn_end
			lda z_c+1
			bmi kw_fn_neg
			jmp ntc_for_bge
kw_fn_neg:
			jmp ntc_for_ble
kw_fn_end:
			jmp ntc_skip2

; ============================================================
; Assignment
; ============================================================

;## kw_ltov
;kw_ltov, <literal>, <destvar>
kw_ltov:
			pla
			tax
			pla
			sta z_t0
			NTC_POP z_p0
			txa
			ldy #0
			sta (z_p0),y
			iny
			lda z_t0
			sta (z_p0),y
			rts

;## kw_vtov
;kw_vtov, <sourcevar>, <destvar>
kw_vtov:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			iny
			lda (z_p0),y
			sta (z_p1),y
			rts

;## kw_ztov
;kw_ztov, <destvar>
kw_ztov:
			NTC_POP z_p0
			lda #0
			tay
			sta (z_p0),y
			iny
			sta (z_p0),y
			rts

;## kw_ftov
;kw_ftov, <destvar>  - Z flag to var: true = -1, false = 0
kw_ftov:
			beq kw_ft_t
			ldx #0
			beq kw_ft_go
kw_ft_t:
			ldx #$FF
kw_ft_go:
			NTC_POP z_p0
			txa
			ldy #0
			sta (z_p0),y
			iny
			sta (z_p0),y
			rts

; ============================================================
; Arithmetic (16 bit, wrapping)
; ============================================================

;## kw_inc
kw_inc:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			clc
			adc #1
			sta (z_p0),y
			iny
			lda (z_p0),y
			adc #0
			sta (z_p0),y
			rts

;## kw_dec
kw_dec:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sec
			sbc #1
			sta (z_p0),y
			iny
			lda (z_p0),y
			sbc #0
			sta (z_p0),y
			rts

;## kw_add
;kw_add, <var1>, <var2>, <destvar>
kw_add:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			clc
			adc (z_p1),y
			tax
			iny
			lda (z_p0),y
			adc (z_p1),y
			sta (z_p2),y
			dey
			txa
			sta (z_p2),y
			rts

;## kw_addl
;kw_addl, <var>, <literal>, <destvar>
kw_addl:
			NTC_POP z_p0
			NTC_POP z_a
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			clc
			adc z_a
			tax
			iny
			lda (z_p0),y
			adc z_a+1
			sta (z_p2),y
			dey
			txa
			sta (z_p2),y
			rts

;## kw_subvv
;kw_subvv, <var1>, <var2>, <destvar>  - var1 - var2
kw_subvv:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			sec
			sbc (z_p1),y
			tax
			iny
			lda (z_p0),y
			sbc (z_p1),y
			sta (z_p2),y
			dey
			txa
			sta (z_p2),y
			rts

;## kw_sublv
;kw_sublv, <literal>, <var>, <destvar>  - literal - var
kw_sublv:
			NTC_POP z_a
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda z_a
			sec
			sbc (z_p1),y
			tax
			iny
			lda z_a+1
			sbc (z_p1),y
			sta (z_p2),y
			dey
			txa
			sta (z_p2),y
			rts

;## kw_2x
kw_2x:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			asl
			tax
			iny
			lda (z_p0),y
			rol
			sta (z_p2),y
			dey
			txa
			sta (z_p2),y
			rts

;## kw_4x
kw_4x:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			asl z_a
			rol
			asl z_a
			rol
			sta (z_p2),y
			dey
			lda z_a
			sta (z_p2),y
			rts

;## ntc_mul16
; z_a * z_b -> z_a (low 16 bits) with the hardware multiplier ($D770: A, $D774: B,
; $D778: the product). Uses A only. JSR or JMP / back by hand
ntc_mul16:
			lda z_a
			sta $D770
			lda z_a+1
			sta $D771
			lda #0
			sta $D772
			sta $D773
			sta $D776
			sta $D777
			lda z_b
			sta $D774
			lda z_b+1
			sta $D775
			lda $D778
			sta z_a
			lda $D779
			sta z_a+1
			rts

;## kw_mulvv ntc_mul16
;kw_mulvv, <var1>, <var2>, <destvar>  - low 16 bits
kw_mulvv:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta z_a
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_a+1
			lda (z_p1),y
			sta z_b+1
ntc_mul_st:
			NTC_POP z_p2
			lda z_a
			sta $D770
			lda z_a+1
			sta $D771
			lda #0
			sta $D772
			sta $D773
			sta $D776
			sta $D777
			lda z_b
			sta $D774
			lda z_b+1
			sta $D775
			ldy #0
			lda $D778
			sta (z_p2),y
			iny
			lda $D779
			sta (z_p2),y
			rts

;## kw_mulvl ntc_mul16 kw_mulvv
;kw_mulvl, <var>, <literal>, <destvar>
kw_mulvl:
			NTC_POP z_p0
			NTC_POP z_b
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			jmp ntc_mul_st

;## ntc_div
; z_a / z_b signed, truncating: z_a = quotient, z_b = remainder (the
; dividend's sign). Divide by zero: quotient 0, remainder = dividend.
; -32768 / -1: quotient -32768, remainder 0. JSR (the real stack). Uses z_c, z_t0, z_t1
ntc_div:
			lda z_b
			ora z_b+1
			bne ntc_div_nz
			lda z_a
			sta z_b
			lda z_a+1
			sta z_b+1
			lda #0
			sta z_a
			sta z_a+1
			rts
ntc_div_nz:
			lda z_a+1
			sta z_t0					; the dividend's sign
			eor z_b+1
			sta z_t1					; the quotient's
			bit z_a+1
			bpl ntc_div_ap
			sec
			lda #0
			sbc z_a
			sta z_a
			lda #0
			sbc z_a+1
			sta z_a+1
ntc_div_ap:
			bit z_b+1
			bpl ntc_div_bp
			sec
			lda #0
			sbc z_b
			sta z_b
			lda #0
			sbc z_b+1
			sta z_b+1
ntc_div_bp:
			jsr ntc_udiv16
			bit z_t1
			bpl ntc_div_qp
			sec
			lda #0
			sbc z_a
			sta z_a
			lda #0
			sbc z_a+1
			sta z_a+1
ntc_div_qp:
			lda z_c
			sta z_b
			lda z_c+1
			sta z_b+1
			bit z_t0
			bpl ntc_div_rp
			sec
			lda #0
			sbc z_b
			sta z_b
			lda #0
			sbc z_b+1
			sta z_b+1
ntc_div_rp:
			rts
; z_a / z_b unsigned: z_a = quotient, z_c = remainder. Uses A, X, Y
ntc_udiv16:
			lda #0
			sta z_c
			sta z_c+1
			ldx #16
ntc_ud_lp:
			asl z_a
			rol z_a+1
			rol z_c
			rol z_c+1
			lda z_c
			sec
			sbc z_b
			tay
			lda z_c+1
			sbc z_b+1
			bcc ntc_ud_no
			sta z_c+1
			sty z_c
			inc z_a
ntc_ud_no:
			dex
			bne ntc_ud_lp
			rts

;## ntc_divk ntc_div
; the division keywords' tail: z_a / z_b, then the quotient (z_t7 = 0) or the
; remainder (z_t7 = 1) into the var whose address is next on the thread
ntc_divk:
			NTC_RS
			jsr ntc_div
			NTC_TS
			NTC_POP z_p2
			ldy #0
			ldx z_t7
			bne ntc_divk_r
			lda z_a
			sta (z_p2),y
			iny
			lda z_a+1
			sta (z_p2),y
			rts
ntc_divk_r:
			lda z_b
			sta (z_p2),y
			iny
			lda z_b+1
			sta (z_p2),y
			rts
; the two operands: vv (two vars: z_p0, z_p1), vl, lv
ntc_divk_vv:
			ldy #0
			lda (z_p0),y
			sta z_a
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_a+1
			lda (z_p1),y
			sta z_b+1
			jmp ntc_divk

;## kw_divvv ntc_divk
;kw_divvv, <var1>, <var2>, <destvar>  - var1 \ var2
kw_divvv:
			NTC_POP z_p0
			NTC_POP z_p1
			lda #0
			sta z_t7
			jmp ntc_divk_vv

;## kw_divvl ntc_divk
;kw_divvl, <var>, <literal>, <destvar>
kw_divvl:
			NTC_POP z_p0
			NTC_POP z_b
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			lda #0
			sta z_t7
			jmp ntc_divk

;## kw_divlv ntc_divk
;kw_divlv, <literal>, <var>, <destvar>
kw_divlv:
			NTC_POP z_a
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p1),y
			sta z_b+1
			lda #0
			sta z_t7
			jmp ntc_divk

;## kw_modvv ntc_divk
;kw_modvv, <var1>, <var2>, <destvar>  - var1 MOD var2
kw_modvv:
			NTC_POP z_p0
			NTC_POP z_p1
			lda #1
			sta z_t7
			jmp ntc_divk_vv

;## kw_modvl ntc_divk
kw_modvl:
			NTC_POP z_p0
			NTC_POP z_b
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			lda #1
			sta z_t7
			jmp ntc_divk

;## kw_modlv ntc_divk
kw_modlv:
			NTC_POP z_a
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p1),y
			sta z_b+1
			lda #1
			sta z_t7
			jmp ntc_divk

;## kw_negv
kw_negv:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #0
			lda #0
			sec
			sbc (z_p0),y
			tax
			iny
			lda #0
			sbc (z_p0),y
			sta (z_p2),y
			dey
			txa
			sta (z_p2),y
			rts

;## kw_absv
kw_absv:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #1
			lda (z_p0),y
			bmi kw_abs_neg
			sta (z_p2),y
			dey
			lda (z_p0),y
			sta (z_p2),y
			rts
kw_abs_neg:
			ldy #0
			lda #0
			sec
			sbc (z_p0),y
			tax
			iny
			lda #0
			sbc (z_p0),y
			sta (z_p2),y
			dey
			txa
			sta (z_p2),y
			rts

;## kw_sgnv
;kw_sgnv, <var>, <destvar>  - -1, 0 or 1
kw_sgnv:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			iny
			ora (z_p0),y
			beq kw_sgn_z				; 0 (A = 0)
			lda (z_p0),y
			bmi kw_sgn_m
			lda #1
			ldx #0
			beq kw_sgn_st
kw_sgn_m:
			lda #$FF
			tax
			bne kw_sgn_st
kw_sgn_z:
			tax
kw_sgn_st:
			ldy #0
			sta (z_p2),y
			iny
			txa
			sta (z_p2),y
			rts

; ============================================================
; Bitwise / logic (true = -1, so these work as logical too)
; ============================================================

;## kw_andvv
kw_andvv:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			and (z_p1),y
			sta (z_p2),y
			iny
			lda (z_p0),y
			and (z_p1),y
			sta (z_p2),y
			rts

;## kw_andvl
kw_andvl:
			NTC_POP z_p0
			NTC_POP z_a
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			and z_a
			sta (z_p2),y
			iny
			lda (z_p0),y
			and z_a+1
			sta (z_p2),y
			rts

;## kw_orvv
kw_orvv:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			ora (z_p1),y
			sta (z_p2),y
			iny
			lda (z_p0),y
			ora (z_p1),y
			sta (z_p2),y
			rts

;## kw_orvl
kw_orvl:
			NTC_POP z_p0
			NTC_POP z_a
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			ora z_a
			sta (z_p2),y
			iny
			lda (z_p0),y
			ora z_a+1
			sta (z_p2),y
			rts

;## kw_xorvv
kw_xorvv:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			eor (z_p1),y
			sta (z_p2),y
			iny
			lda (z_p0),y
			eor (z_p1),y
			sta (z_p2),y
			rts

;## kw_xorvl
kw_xorvl:
			NTC_POP z_p0
			NTC_POP z_a
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			eor z_a
			sta (z_p2),y
			iny
			lda (z_p0),y
			eor z_a+1
			sta (z_p2),y
			rts

;## kw_notv
kw_notv:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #0
			lda (z_p0),y
			eor #$FF
			sta (z_p2),y
			iny
			lda (z_p0),y
			eor #$FF
			sta (z_p2),y
			rts

; ============================================================
; Compares - result in the Z flag (Z = true): the tails end with
; lda #0 (true) or lda #1 (false), then rts
; ============================================================

;## ntc_cmp
; tails: z_a = a, z_b = b, test a <rel> b
ntc_cmp_slt:
			lda z_a
			cmp z_b
			lda z_a+1
			sbc z_b+1
			bvc ntc_cmp_s1
			eor #$80
ntc_cmp_s1:
			bmi ntc_cmp_t
ntc_cmp_f:
			lda #1
			rts
ntc_cmp_t:
			lda #0
			rts
ntc_cmp_sge:
			lda z_a
			cmp z_b
			lda z_a+1
			sbc z_b+1
			bvc ntc_cmp_s2
			eor #$80
ntc_cmp_s2:
			bpl ntc_cmp_t
			lda #1
			rts
ntc_cmp_sgt:					; b < a
			lda z_b
			cmp z_a
			lda z_b+1
			sbc z_a+1
			bvc ntc_cmp_s3
			eor #$80
ntc_cmp_s3:
			bmi ntc_cmp_t
			lda #1
			rts
ntc_cmp_sle:					; b >= a
			lda z_b
			cmp z_a
			lda z_b+1
			sbc z_a+1
			bvc ntc_cmp_s4
			eor #$80
ntc_cmp_s4:
			bpl ntc_cmp_t
			lda #1
			rts
ntc_cmp_ult:
			lda z_a
			cmp z_b
			lda z_a+1
			sbc z_b+1
			bcc ntc_cmp_t
			lda #1
			rts
ntc_cmp_uge:
			lda z_a
			cmp z_b
			lda z_a+1
			sbc z_b+1
			bcs ntc_cmp_t
			lda #1
			rts
ntc_cmp_ugt:					; b < a
			lda z_b
			cmp z_a
			lda z_b+1
			sbc z_a+1
			bcc ntc_cmp_t
			lda #1
			rts
ntc_cmp_ule:					; b >= a
			lda z_b
			cmp z_a
			lda z_b+1
			sbc z_a+1
			bcs ntc_cmp_t
			lda #1
			rts
ntc_cmp_eq:
			lda z_a
			cmp z_b
			bne ntc_cmp_f
			lda z_a+1
			cmp z_b+1
			bne ntc_cmp_f
			lda #0
			rts
ntc_cmp_ne:
			lda z_a
			cmp z_b
			bne ntc_cmp_t
			lda z_a+1
			cmp z_b+1
			bne ntc_cmp_t
			lda #1
			rts
; the operands: vv (two vars), vl (a var, a literal) into z_a, z_b; then jmp (z_g)
ntc_cmp_vv:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta z_a
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_a+1
			lda (z_p1),y
			sta z_b+1
			jmp (z_g)
ntc_cmp_vl:
			NTC_POP z_p0
			NTC_POP z_b
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			jmp (z_g)

;## kw_scpltvv ntc_cmp
kw_scpltvv:
			lda #<ntc_cmp_slt
			sta z_g
			lda #>ntc_cmp_slt
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_scpltvl ntc_cmp
kw_scpltvl:
			lda #<ntc_cmp_slt
			sta z_g
			lda #>ntc_cmp_slt
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_scplevv ntc_cmp
kw_scplevv:
			lda #<ntc_cmp_sle
			sta z_g
			lda #>ntc_cmp_sle
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_scplevl ntc_cmp
kw_scplevl:
			lda #<ntc_cmp_sle
			sta z_g
			lda #>ntc_cmp_sle
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_scpgtvv ntc_cmp
kw_scpgtvv:
			lda #<ntc_cmp_sgt
			sta z_g
			lda #>ntc_cmp_sgt
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_scpgtvl ntc_cmp
kw_scpgtvl:
			lda #<ntc_cmp_sgt
			sta z_g
			lda #>ntc_cmp_sgt
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_scpgevv ntc_cmp
kw_scpgevv:
			lda #<ntc_cmp_sge
			sta z_g
			lda #>ntc_cmp_sge
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_scpgevl ntc_cmp
kw_scpgevl:
			lda #<ntc_cmp_sge
			sta z_g
			lda #>ntc_cmp_sge
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_cpltvv ntc_cmp
kw_cpltvv:
			lda #<ntc_cmp_ult
			sta z_g
			lda #>ntc_cmp_ult
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_cpltvl ntc_cmp
kw_cpltvl:
			lda #<ntc_cmp_ult
			sta z_g
			lda #>ntc_cmp_ult
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_cplevv ntc_cmp
kw_cplevv:
			lda #<ntc_cmp_ule
			sta z_g
			lda #>ntc_cmp_ule
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_cplevl ntc_cmp
kw_cplevl:
			lda #<ntc_cmp_ule
			sta z_g
			lda #>ntc_cmp_ule
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_cpgtvv ntc_cmp
kw_cpgtvv:
			lda #<ntc_cmp_ugt
			sta z_g
			lda #>ntc_cmp_ugt
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_cpgtvl ntc_cmp
kw_cpgtvl:
			lda #<ntc_cmp_ugt
			sta z_g
			lda #>ntc_cmp_ugt
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_cpgevv ntc_cmp
kw_cpgevv:
			lda #<ntc_cmp_uge
			sta z_g
			lda #>ntc_cmp_uge
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_cpgevl ntc_cmp
kw_cpgevl:
			lda #<ntc_cmp_uge
			sta z_g
			lda #>ntc_cmp_uge
			sta z_g+1
			jmp ntc_cmp_vl

;## kw_cpeqvv
kw_cpeqvv:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			cmp (z_p1),y
			bne kw_ceq_f
			iny
			lda (z_p0),y
			cmp (z_p1),y
			bne kw_ceq_f
			lda #0
			rts
kw_ceq_f:
			lda #1
			rts

;## kw_cpeqvl
kw_cpeqvl:
			NTC_POP z_p0
			NTC_POP z_b
			ldy #0
			lda (z_p0),y
			cmp z_b
			bne kw_ceql_f
			iny
			lda (z_p0),y
			cmp z_b+1
			bne kw_ceql_f
			lda #0
			rts
kw_ceql_f:
			lda #1
			rts

;## kw_cpnevv ntc_cmp
kw_cpnevv:
			lda #<ntc_cmp_ne
			sta z_g
			lda #>ntc_cmp_ne
			sta z_g+1
			jmp ntc_cmp_vv

;## kw_cpnevl ntc_cmp
kw_cpnevl:
			lda #<ntc_cmp_ne
			sta z_g
			lda #>ntc_cmp_ne
			sta z_g+1
			jmp ntc_cmp_vl

; ============================================================
; Memory (PEEK / POKE / DEEK / DOKE): 16 bit addresses, the CPU's 64K
; (bank 0, I/O at $D000)
; ============================================================

;## kw_lptrtov8
;kw_lptrtov8, <literaladdr>, <destvar>  - PEEK(literal)
kw_lptrtov8:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
			lda (z_p1),y
			sta (z_p0),y
			iny
			lda #0
			sta (z_p0),y
			rts

;## kw_vptrtov8
;kw_vptrtov8, <addrvar>, <destvar>  - PEEK(var)
kw_vptrtov8:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			NTC_POP z_p0
			ldy #0
			lda (z_p1),y
			sta (z_p0),y
			iny
			lda #0
			sta (z_p0),y
			rts

;## kw_lptrtov
;kw_lptrtov, <literaladdr>, <destvar>  - DEEK(literal)
kw_lptrtov:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
			lda (z_p1),y
			sta (z_p0),y
			iny
			lda (z_p1),y
			sta (z_p0),y
			rts

;## kw_vptrtov
;kw_vptrtov, <addrvar>, <destvar>  - DEEK(var)
kw_vptrtov:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			NTC_POP z_p0
			ldy #0
			lda (z_p1),y
			sta (z_p0),y
			iny
			lda (z_p1),y
			sta (z_p0),y
			rts

;## kw_ltovptr8
;kw_ltovptr8, <literal>, <addrvar>  - POKE var, literal
kw_ltovptr8:
			NTC_POP z_a
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			ldy #0
			lda z_a
			sta (z_p1),y
			rts

;## kw_vtovptr8
;kw_vtovptr8, <sourcevar>, <addrvar>  - POKE var, var
kw_vtovptr8:
			NTC_POP z_p2
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			ldy #0
			lda (z_p2),y
			sta (z_p1),y
			rts

;## kw_ltolptr8
;kw_ltolptr8, <literal>, <literaladdr>  - POKE literal, literal
kw_ltolptr8:
			NTC_POP z_a
			NTC_POP z_p1
			ldy #0
			lda z_a
			sta (z_p1),y
			rts

;## kw_vtolptr8
;kw_vtolptr8, <sourcevar>, <literaladdr>  - POKE literal, var
kw_vtolptr8:
			NTC_POP z_p2
			NTC_POP z_p1
			ldy #0
			lda (z_p2),y
			sta (z_p1),y
			rts

;## kw_ltovptr
;kw_ltovptr, <literal>, <addrvar>  - DOKE var, literal
kw_ltovptr:
			NTC_POP z_a
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			ldy #0
			lda z_a
			sta (z_p1),y
			iny
			lda z_a+1
			sta (z_p1),y
			rts

;## kw_vtovptr
;kw_vtovptr, <sourcevar>, <addrvar>  - DOKE var, var
kw_vtovptr:
			NTC_POP z_p2
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			ldy #0
			lda (z_p2),y
			sta (z_p1),y
			iny
			lda (z_p2),y
			sta (z_p1),y
			rts

;## kw_ltolptr
;kw_ltolptr, <literal>, <literaladdr>  - DOKE literal, literal
kw_ltolptr:
			NTC_POP z_a
			NTC_POP z_p1
			ldy #0
			lda z_a
			sta (z_p1),y
			iny
			lda z_a+1
			sta (z_p1),y
			rts

;## kw_vtolptr
;kw_vtolptr, <sourcevar>, <literaladdr>  - DOKE literal, var
kw_vtolptr:
			NTC_POP z_p2
			NTC_POP z_p1
			ldy #0
			lda (z_p2),y
			sta (z_p1),y
			iny
			lda (z_p2),y
			sta (z_p1),y
			rts

; ============================================================
; Arrays (16 bit elements, no bounds check)
; ============================================================

;## ntc_aidx
; z_p0 = array base, z_p1 = the index var: z_p0 = base + index * 2 (ntc_aidx2),
; base + index (ntc_aidx1), base + index * 4 (ntc_aidx4); then jmp (z_g)
ntc_aidx4:
			ldy #0
			lda (z_p1),y
			sta z_t0
			iny
			lda (z_p1),y
			asl z_t0
			rol
			asl z_t0
			rol
			sta z_t1
			jmp ntc_aidx_add
ntc_aidx2:
			ldy #0
			lda (z_p1),y
			asl
			sta z_t0
			iny
			lda (z_p1),y
			rol
			sta z_t1
			jmp ntc_aidx_add
ntc_aidx1:
			ldy #0
			lda (z_p1),y
			sta z_t0
			iny
			lda (z_p1),y
			sta z_t1
ntc_aidx_add:
			clc
			lda z_p0
			adc z_t0
			sta z_p0
			lda z_p0+1
			adc z_t1
			sta z_p0+1
			jmp (z_g)

;## kw_aget ntc_aidx
;kw_aget, <arraybase>, <indexvar>, <destvar>
kw_aget:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			asl
			sta z_t0
			iny
			lda (z_p1),y
			rol
			sta z_t1
			clc
			lda z_p0
			adc z_t0
			sta z_p0
			lda z_p0+1
			adc z_t1
			sta z_p0+1
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			iny
			lda (z_p0),y
			sta (z_p1),y
			rts

;## kw_aset
;kw_aset, <arraybase>, <indexvar>, <sourcevar>
kw_aset:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			asl
			sta z_t0
			iny
			lda (z_p1),y
			rol
			sta z_t1
			clc
			lda z_p0
			adc z_t0
			sta z_p0
			lda z_p0+1
			adc z_t1
			sta z_p0+1
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta (z_p0),y
			iny
			lda (z_p1),y
			sta (z_p0),y
			rts

;## kw_asetl
;kw_asetl, <arraybase>, <indexvar>, <literal>
kw_asetl:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			asl
			sta z_t0
			iny
			lda (z_p1),y
			rol
			sta z_t1
			clc
			lda z_p0
			adc z_t0
			sta z_p0
			lda z_p0+1
			adc z_t1
			sta z_p0+1
			NTC_POP z_a
			ldy #0
			lda z_a
			sta (z_p0),y
			iny
			lda z_a+1
			sta (z_p0),y
			rts

;## kw_aget8
;kw_aget8, <arraybase>, <indexvar>, <destvar>  - Byte array element (0 .. 255)
kw_aget8:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			clc
			lda z_p0
			adc (z_p1),y
			sta z_p0
			iny
			lda z_p0+1
			adc (z_p1),y
			sta z_p0+1
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			rts

;## kw_aset8
;kw_aset8, <arraybase>, <indexvar>, <sourcevar>  - set a Byte array element (low byte)
kw_aset8:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			clc
			lda z_p0
			adc (z_p1),y
			sta z_p0
			iny
			lda z_p0+1
			adc (z_p1),y
			sta z_p0+1
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta (z_p0),y
			rts

;## kw_erase
;kw_erase, <base>, <bytes>  - Erase of a fixed size array: zero it
kw_erase:
			NTC_POP z_p0
			NTC_POP z_a
; z_p0 = start, z_a = bytes (unsigned): zero them, then rts (the thread)
ntc_zerofill:
			lda #0
			ldx z_a+1
			beq ntc_zf_part
			ldy #0
ntc_zf_page:
			sta (z_p0),y
			iny
			bne ntc_zf_page
			inc z_p0+1
			dex
			bne ntc_zf_page
ntc_zf_part:
			ldy z_a
			beq ntc_zf_end
			ldy #0
ntc_zf_lp:
			sta (z_p0),y
			iny
			cpy z_a
			bne ntc_zf_lp
ntc_zf_end:
			rts

;## kw_redim kw_erase
;kw_redim, <descriptor>, <base>, <lower>, <size>, <count>, <clear>  - ReDim: fill the
;  descriptor (1 dimension); clear <> 0: zero the elements. Descriptor (12 bytes):
;  base, lower 1, lower 2, count 1, count 2, element size
kw_redim:
			NTC_POP z_p1				; descriptor
			NTC_POP z_p0				; base
			NTC_POP z_a					; lower
			NTC_POP z_b					; size
			NTC_POP z_c					; count
			NTC_POP z_d					; clear
			ldy #0
			lda z_p0
			sta (z_p1),y
			iny
			lda z_p0+1
			sta (z_p1),y
			iny
			lda z_a
			sta (z_p1),y
			iny
			lda z_a+1
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			iny
			sta (z_p1),y
			iny
			lda z_c
			sta (z_p1),y
			iny
			lda z_c+1
			sta (z_p1),y
			iny
			lda #1
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			iny
			lda z_b
			sta (z_p1),y
			iny
			lda z_b+1
			sta (z_p1),y
			lda z_d
			ora z_d+1
			beq kw_rd_end
			lda z_b						; bytes = size * count (the multiplier)
			sta $D770
			lda z_b+1
			sta $D771
			lda #0
			sta $D772
			sta $D773
			sta $D776
			sta $D777
			lda z_c
			sta $D774
			lda z_c+1
			sta $D775
			lda $D778
			sta z_a
			lda $D779
			sta z_a+1
			jmp ntc_zerofill
kw_rd_end:
			rts

; ============================================================
; Random (16 bit xorshift 7,9,8 - the Z80 library's sequence)
; ============================================================

;## ntc_rnd_seed
ntc_rnd_seed:	dw 1

;## ntc_rnd ntc_rnd_seed ntc_div
; the next number (z_b = n): 0 .. n-1 into the var next on the thread (0 if n <= 0)
ntc_rnd:
			lda ntc_rnd_seed+1			; h' = ((h & 1) << 7 | l >> 1) xor h
			lsr
			lda ntc_rnd_seed
			ror
			eor ntc_rnd_seed+1
			sta z_t1					; h'
			lda ntc_rnd_seed			; l' = ((l & 1) << 7 | h' >> 1) xor l
			lsr
			lda z_t1
			ror
			eor ntc_rnd_seed
			sta ntc_rnd_seed			; l'
			eor z_t1					; h'' = l' xor h'
			sta ntc_rnd_seed+1
			lda z_b+1
			bmi ntc_rnd_zero
			ora z_b
			beq ntc_rnd_zero
			lda ntc_rnd_seed
			sta z_a
			lda ntc_rnd_seed+1
			and #$7F
			sta z_a+1
			NTC_RS
			jsr ntc_div
			NTC_TS
			NTC_POP z_p0
			ldy #0
			lda z_b
			sta (z_p0),y
			iny
			lda z_b+1
			sta (z_p0),y
			rts
ntc_rnd_zero:
			NTC_POP z_p0
			lda #0
			tay
			sta (z_p0),y
			iny
			sta (z_p0),y
			rts

;## kw_rndv ntc_rnd
;kw_rndv, <nvar>, <destvar>  - 0 .. n-1 (0 if n <= 0)
kw_rndv:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_b+1
			jmp ntc_rnd

;## kw_rndl ntc_rnd
;kw_rndl, <literal>, <destvar>
kw_rndl:
			NTC_POP z_b
			jmp ntc_rnd

;## kw_seedv ntc_rnd_seed
;kw_seedv, <var>  - RANDOMIZE var (0 becomes 1)
kw_seedv:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta ntc_rnd_seed
			iny
			lda (z_p0),y
			sta ntc_rnd_seed+1
			ora ntc_rnd_seed
			bne kw_sd_ok
			inc ntc_rnd_seed
kw_sd_ok:
			rts

;## kw_seedl ntc_rnd_seed
;kw_seedl, <literal>
kw_seedl:
			pla
			sta ntc_rnd_seed
			pla
			sta ntc_rnd_seed+1
			ora ntc_rnd_seed
			bne kw_sdl_ok
			inc ntc_rnd_seed
kw_sdl_ok:
			rts

; ============================================================
; Strings: 0 terminated. A string variable or temp has its capacity
; (1 .. 255 chars) in the byte before it: [cap][text...][0]. Array
; elements have no capacity byte (the caller gives the element size).
; ============================================================

;## ntc_scopy
; z_p0 = source, z_p1 = dest, X = the most characters (0 .. 255): copy, then the 0.
; Ends with rts (callable with JSR, or as a keyword's tail on the thread)
ntc_scopy:
			ldy #0
			cpx #0
			beq ntc_scp_cut
ntc_scp_lp:
			lda (z_p0),y
			sta (z_p1),y
			beq ntc_scp_e
			iny
			dex
			bne ntc_scp_lp
ntc_scp_cut:
			lda #0
			sta (z_p1),y
ntc_scp_e:
			rts
; X = the capacity byte before z_p1 (uses A)
ntc_scap:
			dew z_p1
			ldy #0
			lda (z_p1),y
			tax
			inw z_p1
			rts

;## kw_strcpy ntc_scopy
;kw_strcpy, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcpy:
			NTC_POP z_p1
			NTC_POP z_p0
			dew z_p1
			ldy #0
			lda (z_p1),y
			tax
			inw z_p1
			jmp ntc_scopy

;## kw_strcpyn ntc_scopy
;kw_strcpyn, <destaddr>, <srcaddr>, <capacity>  - into an array element (no capacity byte)
kw_strcpyn:
			NTC_POP z_p1
			NTC_POP z_p0
			pla
			tax
			pla
			jmp ntc_scopy

;## kw_strcat
;kw_strcat, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcat:
			NTC_POP z_p1
			NTC_POP z_p0
			dew z_p1
			ldy #0
			lda (z_p1),y
			sta z_t0					; capacity
			inw z_p1
			ldy #0
kw_sc_end:
			cpy z_t0
			bcs kw_sc_full
			lda (z_p1),y
			beq kw_sc_copy
			iny
			bne kw_sc_end
kw_sc_full:
			rts
kw_sc_copy:
			tya							; dest += its length
			clc
			adc z_p1
			sta z_p1
			bcc kw_sc_nc
			inc z_p1+1
kw_sc_nc:
			sty z_t1
			lda z_t0
			sec
			sbc z_t1
			tax							; room left
			ldy #0
			cpx #0
			beq kw_sc_e
kw_sc_lp:
			lda (z_p0),y
			sta (z_p1),y
			beq kw_sc_e
			iny
			dex
			bne kw_sc_lp
			lda #0
			sta (z_p1),y
kw_sc_e:
			rts

;## kw_strlen
;kw_strlen, <straddr>, <destvar>
kw_strlen:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
kw_sl_lp:
			lda (z_p0),y
			beq kw_sl_e
			iny
			bne kw_sl_lp
kw_sl_e:
			tya
			ldy #0
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			rts

;## kw_strcmpeq
;kw_strcmpeq, <addr1>, <addr2>  - Z if equal
kw_strcmpeq:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
kw_seq_lp:
			lda (z_p0),y
			cmp (z_p1),y
			bne kw_seq_no
			cmp #0
			beq kw_seq_yes
			iny
			bne kw_seq_lp
kw_seq_yes:
			lda #0
			rts
kw_seq_no:
			lda #1
			rts

;## kw_strcmpne
;kw_strcmpne, <addr1>, <addr2>  - Z if not equal
kw_strcmpne:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
kw_sne_lp:
			lda (z_p0),y
			cmp (z_p1),y
			bne kw_sne_t
			cmp #0
			beq kw_sne_f
			iny
			bne kw_sne_lp
kw_sne_f:
			lda #1						; equal: NZ
			rts
kw_sne_t:
			lda #0						; not equal: Z
			rts

; ============================================================
; I/O. The platform's console routines run on the real stack.
; ============================================================

;## ntc_puts ntc_data ntc_plat_screen
; print the 0 terminated text at z_p0 (JSR on the real stack). Uses z_p0
ntc_puts:
			ldy #0
			lda (z_p0),y
			beq ntc_puts_e
			jsr ntc_plat_putc
			inw z_p0
			jmp ntc_puts
ntc_puts_e:
			rts

;## ntc_printbuf ntc_puts
; print the text at z_p0, then rts (the thread). On the thread.
ntc_printbuf:
			NTC_RS
			jsr ntc_puts
			NTC_TS
			rts

;## kw_printstrvar ntc_printbuf
;kw_printstrvar, <straddr>
kw_printstrvar:
			NTC_POP z_p0
			jmp ntc_printbuf

;## ntc_itoa ntc_data
; z_a = signed value, z_p1 = buffer: the digits and a 0 (z_p1 ends on the 0).
; JSR (the real stack). Uses z_a, z_b, z_c, z_t0
ntc_itoa:
			lda z_a+1
			bpl ntc_ia_pos
			lda #'-'
			ldy #0
			sta (z_p1),y
			inw z_p1
			sec
			lda #0
			sbc z_a
			sta z_a
			lda #0
			sbc z_a+1
			sta z_a+1
ntc_ia_pos:
; z_a unsigned to digits at z_p1
ntc_utoa:
			ldx #0						; digits on the 8 bit stack area: in ntc_ia_tmp
ntc_ia_lp:
			stx z_t0
			lda #10
			sta z_b
			lda #0
			sta z_b+1
			jsr ntc_udiv10
			ldx z_t0
			lda z_c
			ora #'0'
			sta ntc_ia_tmp,x
			inx
			lda z_a
			ora z_a+1
			bne ntc_ia_lp
			ldy #0
ntc_ia_cp:
			dex
			lda ntc_ia_tmp,x
			sta (z_p1),y
			iny
			cpx #0
			bne ntc_ia_cp
			lda #0
			sta (z_p1),y
			tya
			clc
			adc z_p1
			sta z_p1
			bcc ntc_ia_e
			inc z_p1+1
ntc_ia_e:
			rts
; z_a / 10 unsigned: z_a = quotient, z_c = remainder
ntc_udiv10:
			lda #0
			sta z_c
			ldx #16
ntc_u10_lp:
			asl z_a
			rol z_a+1
			rol z_c
			lda z_c
			cmp #10
			bcc ntc_u10_no
			sbc #10
			sta z_c
			inc z_a
ntc_u10_no:
			dex
			bne ntc_u10_lp
			lda #0
			sta z_c+1
			rts
ntc_ia_tmp:	ds 8

;## kw_printint ntc_printbuf ntc_itoa
;kw_printint, <var>  - signed decimal
kw_printint:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			lda #<ntc_numbuf
			sta z_p1
			lda #>ntc_numbuf
			sta z_p1+1
			NTC_RS
			jsr ntc_itoa
			lda #<ntc_numbuf
			sta z_p0
			lda #>ntc_numbuf
			sta z_p0+1
			jsr ntc_puts
			NTC_TS
			rts

;## kw_printintvb ntc_printbuf ntc_itoa
;kw_printintvb, <var>  - Option VBPrint: a space (or the -), the digits, a space
kw_printintvb:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			lda #<ntc_numbuf
			sta z_p1
			lda #>ntc_numbuf
			sta z_p1+1
			lda z_a+1
			bmi kw_piv_neg
			lda #' '
			ldy #0
			sta (z_p1),y
			inw z_p1
kw_piv_neg:
			NTC_RS
			jsr ntc_itoa
			ldy #0
			lda #' '
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			lda #<ntc_numbuf
			sta z_p0
			lda #>ntc_numbuf
			sta z_p0+1
			jsr ntc_puts
			NTC_TS
			rts

;## kw_printtab ntc_data ntc_plat_screen
;kw_printtab, <nvar>  - Tab(n) in Print: spaces up to column n (1 based),
;  a new line first when the cursor is already past it. n off the line: nothing
kw_printtab:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sec
			sbc #1
			sta z_t0
			iny
			lda (z_p0),y
			sbc #0
			bne ntc_pt_end				; off the line (also below 1)
ntc_pt_go:						; z_t0 = the column (0 based)
			lda z_t0
			cmp ntc_scols
			bcs ntc_pt_end
			NTC_RS
			lda z_t0
			cmp ntc_curx
			bcs ntc_pt_lp
			jsr ntc_plat_newline
ntc_pt_lp:
			lda ntc_curx
			cmp z_t0
			bcs ntc_pt_done
			lda #' '
			jsr ntc_plat_putc
			jmp ntc_pt_lp
ntc_pt_done:
			NTC_TS
ntc_pt_end:
			rts

;## kw_printzone kw_printtab
;kw_printzone  - Option VBPrint: a comma in Print moves to the next 14 column zone
kw_printzone:
			lda #14
kw_pz_find:
			cmp ntc_curx
			beq kw_pz_more
			bcs kw_pz_got
kw_pz_more:
			clc
			adc #14
			bcc kw_pz_find
			lda #255
kw_pz_got:
			sta z_t0
			cmp ntc_scols
			bcc ntc_pt_go
			NTC_RS
			jsr ntc_plat_newline
			NTC_TS
			rts

;## kw_printnl0 ntc_data ntc_plat_screen
;kw_printnl0  - new line unless the cursor is at the start of a line
kw_printnl0:
			lda ntc_curx
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
;  address (AddressOf) is in the var. SP is then at the arguments, as the stub expects
kw_callp:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			jmp (z_p1)

;## kw_callv
;kw_callv, <addrvar>  - run machine code at the address in the var (a keyword: ends rts)
kw_callv:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			sta z_p1+1
			jmp (z_p1)

;## kw_inp
;kw_inp, <portvar>, <dest>  - Inp(n): the I/O register $D000 + n (n 0 .. 4095)
kw_inp:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			and #$0F
			ora #$D0
			sta z_p1+1
			NTC_POP z_p0
			ldy #0
			lda (z_p1),y
			sta (z_p0),y
			iny
			lda #0
			sta (z_p0),y
			rts

;## kw_out
;kw_out, <portvar>, <valuevar>  - Out n, v: the I/O register $D000 + n
kw_out:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_p1
			iny
			lda (z_p0),y
			and #$0F
			ora #$D0
			sta z_p1+1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			rts

;## ntc_gets ntc_data ntc_plat_screen ntc_plat_key
; line input with echo and backspace, on the real stack (JSR). z_p2 = buffer (its
; capacity in the byte before it). 0 terminated, then a new line.
ntc_gets:
			dew z_p2
			ldy #0
			lda (z_p2),y
			sta z_t4					; capacity
			inw z_p2
			lda #0
			sta z_t5					; typed
ntc_gs_wait:
			jsr ntc_plat_getkey
			cmp #13
			beq ntc_gs_done
			cmp #127
			beq ntc_gs_del
			cmp #8
			beq ntc_gs_del
			cmp #32
			bcc ntc_gs_wait
			cmp #127
			bcs ntc_gs_wait
			ldy z_t5
			cpy z_t4
			bcs ntc_gs_wait
			sta (z_p2),y
			inc z_t5
			jsr ntc_plat_putc
			jmp ntc_gs_wait
ntc_gs_del:
			lda z_t5
			beq ntc_gs_wait
			dec z_t5
			jsr ntc_plat_backspace
			jmp ntc_gs_wait
ntc_gs_done:
			ldy z_t5
			lda #0
			sta (z_p2),y
			jmp ntc_plat_newline

;## kw_inputstr ntc_gets
;kw_inputstr, <straddr>
kw_inputstr:
			NTC_POP z_p2
			NTC_RS
			jsr ntc_gets
			NTC_TS
			rts

;## kw_inputint ntc_gets ntc_atoi ntc_d_inbuf
;kw_inputint, <var>  - signed decimal, stops at the first non digit
kw_inputint:
			NTC_POP z_p3
			lda #<ntc_inbuf
			sta z_p2
			lda #>ntc_inbuf
			sta z_p2+1
			NTC_RS
			jsr ntc_gets
			lda #<ntc_inbuf
			sta z_p0
			lda #>ntc_inbuf
			sta z_p0+1
			jsr ntc_atoi
			NTC_TS
			rts

;## ntc_atoi ntc_data
; text at z_p0 to a number into the var at z_p3 (JSR). Spaces first, then - ,
; then digits (or &H hex). Uses z_a, z_b, z_t0, z_t1
ntc_atoi:
			lda #0
			sta z_a
			sta z_a+1
			sta z_t1					; minus
			ldy #0
ntc_at_sp:
			lda (z_p0),y
			cmp #' '
			bne ntc_at_sg
			iny
			bne ntc_at_sp
ntc_at_sg:
			cmp #'-'
			bne ntc_at_amp
			inc z_t1
			iny
			lda (z_p0),y
ntc_at_amp:
			cmp #'&'
			bne ntc_at_dec
			iny
			lda (z_p0),y
			iny
			ora #$20
			cmp #'h'
			bne ntc_at_done
ntc_at_hex:
			lda (z_p0),y
			iny
			sec
			sbc #'0'
			bcc ntc_at_done
			cmp #10
			bcc ntc_at_hd
			ora #$20					; (letters: lower case, then 'a'-'0' off)
			sec
			sbc #$31					; 'a' - '0' with the $20
			bcc ntc_at_done
			cmp #6
			bcs ntc_at_done
			adc #10
ntc_at_hd:
			sta z_t0
			asl z_a
			rol z_a+1
			asl z_a
			rol z_a+1
			asl z_a
			rol z_a+1
			asl z_a
			rol z_a+1
			lda z_a
			ora z_t0
			sta z_a
			jmp ntc_at_hex
ntc_at_dec:
			lda (z_p0),y
			iny
			sec
			sbc #'0'
			bcc ntc_at_done
			cmp #10
			bcs ntc_at_done
			sta z_t0
			lda z_a						; * 10: (a * 4 + a) * 2
			sta z_b
			lda z_a+1
			sta z_b+1
			asl z_a
			rol z_a+1
			asl z_a
			rol z_a+1
			clc
			lda z_a
			adc z_b
			sta z_a
			lda z_a+1
			adc z_b+1
			sta z_a+1
			asl z_a
			rol z_a+1
			clc
			lda z_a
			adc z_t0
			sta z_a
			bcc ntc_at_dec
			inc z_a+1
			jmp ntc_at_dec
ntc_at_done:
			lda z_t1
			beq ntc_at_st
			sec
			lda #0
			sbc z_a
			sta z_a
			lda #0
			sbc z_a+1
			sta z_a+1
ntc_at_st:
			ldy #0
			lda z_a
			sta (z_p3),y
			iny
			lda z_a+1
			sta (z_p3),y
			rts

;## kw_inkey ntc_data ntc_plat_key
;kw_inkey, <destvar>  - new key press or 0, no wait
kw_inkey:
			NTC_POP z_p2
			NTC_RS
			jsr ntc_plat_scankey
			sta z_t0
			NTC_TS
			ldy #0
			lda z_t0
			sta (z_p2),y
			iny
			lda #0
			sta (z_p2),y
			rts

;## kw_inkeys ntc_data ntc_plat_key
;kw_inkeys, <dest>  - Inkey$: the new key press as a string, "" if none
kw_inkeys:
			NTC_POP z_p2
			NTC_RS
			jsr ntc_plat_scankey
			sta z_t0
			NTC_TS
			ldy #0
			lda z_t0
			sta (z_p2),y
			beq kw_iks_e
			iny
			lda #0
			sta (z_p2),y
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
			NTC_POP z_a
			NTC_POP z_b
			NTC_RS
			ldx z_a
			ldy z_b
			lda z_a+1					; (past 255: off the screen)
			ora z_b+1
			bne kw_ll_e
			jsr ntc_plat_locate
kw_ll_e:
			NTC_TS
			rts

;## kw_locatevv ntc_data ntc_plat_screen
;kw_locatevv, <xvar>, <yvar>
kw_locatevv:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta z_a
			lda (z_p1),y
			sta z_b
			iny
			lda (z_p0),y
			ora (z_p1),y
			sta z_t0
			NTC_RS
			lda z_t0
			bne kw_lv_e
			ldx z_a
			ldy z_b
			jsr ntc_plat_locate
kw_lv_e:
			NTC_TS
			rts

;## kw_model ntc_data ntc_plat_screen
;kw_model, <literal>  - clears the screen
kw_model:
			NTC_POP z_a
			NTC_RS
			lda z_a
			jsr ntc_plat_mode
			NTC_TS
			rts

;## kw_modev ntc_data ntc_plat_screen
kw_modev:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			NTC_RS
			lda z_a
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
;kw_ticks, <destvar>  - the tick count (frames, 50 or 60 a second)
kw_ticks:
			NTC_POP z_p2
			NTC_RS
			jsr ntc_plat_ticks
			sta z_t0
			stx z_t1
			NTC_TS
			ldy #0
			lda z_t0
			sta (z_p2),y
			iny
			lda z_t1
			sta (z_p2),y
			rts

; ============================================================
; String functions. Numbers are passed as the address of a word.
; Results go to a string buffer. Dest may be the same as the source.
; Most run on the real stack (NTC_RS ... jsr ... NTC_TS).
; ============================================================

;## ntc_getn
; z_p5 = address of a word: A = its value limited to 0 .. 255. Uses Y
ntc_getn:
			ldy #1
			lda (z_p5),y
			bmi ntc_gn_zero
			bne ntc_gn_max
			dey
			lda (z_p5),y
			rts
ntc_gn_max:
			lda #255
			rts
ntc_gn_zero:
			lda #0
			rts

;## ntc_sncpy
; copy up to X chars from z_p0 to z_p1, then the 0 (JSR). Overlapping forward is fine
ntc_sncpy:
			ldy #0
			cpx #0
			beq ntc_sn_end
ntc_sn_lp:
			lda (z_p0),y
			sta (z_p1),y
			beq ntc_sn_z
			iny
			dex
			bne ntc_sn_lp
ntc_sn_end:
			lda #0
			sta (z_p1),y
ntc_sn_z:
			rts
; Y = the length of the text at z_p0 (A = 0)
ntc_slen0:
			ldy #0
ntc_sl0_lp:
			lda (z_p0),y
			beq ntc_sl0_e
			iny
			bne ntc_sl0_lp
ntc_sl0_e:
			rts

;## kw_strleft ntc_getn ntc_sncpy
;kw_strleft, <dest>, <src>, <nvar>  - Left$(src, n)
kw_strleft:
			NTC_POP z_p1
			NTC_POP z_p0
			NTC_POP z_p5
			NTC_RS
			jsr ntc_getn
			NTC_TS
			tax
			jmp ntc_sncpy

;## kw_strright ntc_getn ntc_sncpy
;kw_strright, <dest>, <src>, <nvar>  - Right$(src, n)
kw_strright:
			NTC_POP z_p1
			NTC_POP z_p0
			NTC_POP z_p5
			NTC_RS
			jsr ntc_getn
			sta z_t0					; n
			jsr ntc_slen0				; Y = len
			tya
			sec
			sbc z_t0					; len - n
			bcs kw_sr_skip
			lda #0
kw_sr_skip:
			clc
			adc z_p0
			sta z_p0
			bcc kw_sr_nc
			inc z_p0+1
kw_sr_nc:
			ldx #255
			jsr ntc_sncpy
			NTC_TS
			rts

;## kw_pow ntc_mul16
;kw_pow, <basevar>, <expvar>, <destvar>  - base ^ exp (Integer, low 16 bits; exp < 0 gives 0)
kw_pow:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta z_c
			lda (z_p1),y
			sta z_d
			iny
			lda (z_p0),y
			sta z_c+1
			lda (z_p1),y
			sta z_d+1					; exp
			lda #1
			sta z_a
			lda #0
			sta z_a+1
			lda z_d+1
			bpl kw_pw_lp
			lda #0
			sta z_a
			beq kw_pw_st
kw_pw_lp:
			lda z_d
			ora z_d+1
			beq kw_pw_st
			lda z_c
			sta z_b
			lda z_c+1
			sta z_b+1
			lda z_a						; z_a *= base (the multiplier)
			sta $D770
			lda z_a+1
			sta $D771
			lda #0
			sta $D772
			sta $D773
			sta $D776
			sta $D777
			lda z_b
			sta $D774
			lda z_b+1
			sta $D775
			lda $D778
			sta z_a
			lda $D779
			sta z_a+1
			lda z_d
			bne kw_pw_d
			dec z_d+1
kw_pw_d:
			dec z_d
			jmp kw_pw_lp
kw_pw_st:
			NTC_POP z_p2
			ldy #0
			lda z_a
			sta (z_p2),y
			iny
			lda z_a+1
			sta (z_p2),y
			rts

;## kw_sqr
;kw_sqr, <var>, <destvar>  - Sqr: whole number square root (negative gives 0)
kw_sqr:
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			lda #0
			sta z_b						; root
			sta z_b+1
			lda z_a+1
			bmi kw_sq_done
			lda #1
			sta z_c						; odd number
			lda #0
			sta z_c+1
kw_sq_lp:
			lda z_a
			sec
			sbc z_c
			tax
			lda z_a+1
			sbc z_c+1
			bcc kw_sq_done
			sta z_a+1
			stx z_a
			inw z_b
			lda z_c
			clc
			adc #2
			sta z_c
			bcc kw_sq_lp
			inc z_c+1
			jmp kw_sq_lp
kw_sq_done:
			NTC_POP z_p2
			ldy #0
			lda z_b
			sta (z_p2),y
			iny
			lda z_b+1
			sta (z_p2),y
			rts

;## kw_strrev
;kw_strrev, <dest>, <src>  - StrReverse
kw_strrev:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0						; copy across first (unless the same)
			lda z_p0
			cmp z_p1
			bne kw_rv_cp
			lda z_p0+1
			cmp z_p1+1
			beq kw_rv_go
kw_rv_cp:
			lda (z_p0),y
			sta (z_p1),y
			beq kw_rv_go
			iny
			bne kw_rv_cp
kw_rv_go:
			ldy #0
kw_rv_len:
			lda (z_p1),y
			beq kw_rv_l2
			iny
			bne kw_rv_len
kw_rv_l2:
			cpy #2
			bcc kw_rv_e
			dey
			sty z_t1					; the last
			lda #0
			sta z_t0					; the first
kw_rv_sw:
			lda z_t0
			cmp z_t1
			bcs kw_rv_e
			ldy z_t0
			lda (z_p1),y
			tax
			ldy z_t1
			lda (z_p1),y
			ldy z_t0
			sta (z_p1),y
			txa
			ldy z_t1
			sta (z_p1),y
			inc z_t0
			dec z_t1
			jmp kw_rv_sw
kw_rv_e:
			rts

;## kw_stroct
;kw_stroct, <dest>, <var>  - Oct$ (16 bit unsigned, no leading zeros)
kw_stroct:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			lda #0
			sta z_t0					; out index
			sta z_t1					; a digit seen
			; the first digit: the top bit
			lda #0
			asl z_a
			rol z_a+1
			rol
			ldx #5						; then 5 digits of 3 bits
			jmp kw_oc_out1
kw_oc_lp:
			lda #0
			asl z_a
			rol z_a+1
			rol
			asl z_a
			rol z_a+1
			rol
			asl z_a
			rol z_a+1
			rol
kw_oc_out1:
			cmp #0
			bne kw_oc_put
			ldy z_t1
			bne kw_oc_put
			cpx #0
			bne kw_oc_skip
kw_oc_put:
			ora #'0'
			ldy z_t0
			sta (z_p1),y
			inc z_t0
			lda #1
			sta z_t1
kw_oc_skip:
			dex
			bpl kw_oc_lp
			ldy z_t0
			lda #0
			sta (z_p1),y
			rts

;## kw_strinstrrev ntc_sncpy
;kw_strinstrrev, <text>, <find>, <startvar>, <destvar>  - InStrRev (start -1 = from the end)
kw_strinstrrev:
			NTC_POP z_p0				; text
			NTC_POP z_p2				; find
			NTC_POP z_p3
			ldy #0
			lda (z_p3),y
			sta z_c						; start
			iny
			lda (z_p3),y
			sta z_c+1
			ldy #0
kw_ir_l1:
			lda (z_p0),y
			beq kw_ir_l1e
			iny
			bne kw_ir_l1
kw_ir_l1e:
			sty z_t2					; len(text)
			ldy #0
kw_ir_l2:
			lda (z_p2),y
			beq kw_ir_l2e
			iny
			bne kw_ir_l2
kw_ir_l2e:
			sty z_t3					; len(find)
			lda z_t2
			sec
			sbc z_t3
			bcc kw_ir_none
			clc
			adc #1						; the last place it can start (1 based)
			sta z_t4
			lda z_c+1					; start <= 0: from the end
			bmi kw_ir_lp
			bne kw_ir_lp				; (past 255: from the end)
			lda z_c
			beq kw_ir_lp
			cmp z_t4
			bcs kw_ir_lp
			sta z_t4
kw_ir_lp:
			lda z_t4
			beq kw_ir_none
			; compare find with text at z_t4 - 1
			sec
			sbc #1
			sta z_t5
			ldx #0
kw_ir_cmp:
			txa
			tay
			lda (z_p2),y
			beq kw_ir_found
			sta z_t6
			txa
			clc
			adc z_t5
			tay
			lda (z_p0),y
			cmp z_t6
			bne kw_ir_next
			inx
			bne kw_ir_cmp
kw_ir_next:
			dec z_t4
			jmp kw_ir_lp
kw_ir_none:
			lda #0
			sta z_t4
kw_ir_found:
			NTC_POP z_p1
			ldy #0
			lda z_t4
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			rts

;## kw_strreplace
;kw_strreplace, <dest>, <text>, <find>, <with>  - Replace (NTC_STRMAX characters at most)
kw_strreplace:
			NTC_POP z_p4				; dest
			NTC_POP z_p0				; text
			NTC_POP z_p2				; find
			NTC_POP z_p3				; with
			NTC_RS
			jsr ntc_replace
			NTC_TS
			rts
ntc_replace:
			lda #<ntc_rpbuf
			sta z_p1
			lda #>ntc_rpbuf
			sta z_p1+1
			lda #<NTC_STRMAX
			sta z_t0					; room
			ldy #0
			lda (z_p2),y
			beq ntc_rp_rest
ntc_rp_lp:
			ldy #0
			lda (z_p0),y
			beq ntc_rp_done
			; does find match here?
ntc_rp_m:
			lda (z_p2),y
			beq ntc_rp_hit
			cmp (z_p0),y
			bne ntc_rp_miss
			iny
			bne ntc_rp_m
ntc_rp_miss:
			lda z_t0
			beq ntc_rp_done
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			inw z_p0
			inw z_p1
			dec z_t0
			jmp ntc_rp_lp
ntc_rp_hit:
			tya							; past the match
			clc
			adc z_p0
			sta z_p0
			bcc ntc_rp_h1
			inc z_p0+1
ntc_rp_h1:
			ldy #0
ntc_rp_w:
			lda (z_p3),y
			beq ntc_rp_wd
			ldx z_t0
			beq ntc_rp_done
			sty z_t1
			ldy #0
			sta (z_p1),y
			inw z_p1
			dec z_t0
			ldy z_t1
			iny
			bne ntc_rp_w
ntc_rp_wd:
			jmp ntc_rp_lp
ntc_rp_rest:
			ldy #0
			lda (z_p0),y
			beq ntc_rp_done
			ldx z_t0
			beq ntc_rp_done
			sta (z_p1),y
			inw z_p0
			inw z_p1
			dec z_t0
			jmp ntc_rp_rest
ntc_rp_done:
			ldy #0
			tya
			sta (z_p1),y
ntc_rp_out:
			lda ntc_rpbuf,y
			sta (z_p4),y
			beq ntc_rp_e
			iny
			bne ntc_rp_out
ntc_rp_e:
			rts
ntc_rpbuf:	ds NTC_STRMAX+1

;## kw_strlike
;kw_strlike, <text>, <pattern>  - Z if text Like pattern: * any run, ? one char,
;  # one digit, [abc] / [a-z] one of, [!abc] none of. Case matters
kw_strlike:
			NTC_POP z_p1				; text
			NTC_POP z_p0				; pattern
			NTC_RS
			jsr ntc_like
			sta z_t0
			NTC_TS
			lda z_t0
			rts
; A = 0 (match) or 1. z_p0 pattern, z_p1 text; z_p2 / z_p3 = the last * (pattern
; after it, the text then), z_t7 = 1 when there was one
ntc_like:
			lda #0
			sta z_t7
ntc_lk_lp:
			ldy #0
			lda (z_p1),y
			beq ntc_lk_end
			lda (z_p0),y
			cmp #'*'
			bne ntc_lk_one
			inw z_p0
			lda z_p0
			sta z_p2
			lda z_p0+1
			sta z_p2+1
			lda z_p1
			sta z_p3
			lda z_p1+1
			sta z_p3+1
			lda #1
			sta z_t7
			jmp ntc_lk_lp
ntc_lk_one:
			sta z_t0					; the pattern char
			lda (z_p1),y
			sta z_t1					; the text char
			lda z_t0
			beq ntc_lk_back
			cmp #'?'
			beq ntc_lk_ok1
			cmp #'#'
			bne ntc_lk_br
			lda z_t1
			cmp #'0'
			bcc ntc_lk_back
			cmp #'9'+1
			bcs ntc_lk_back
ntc_lk_ok1:
			inw z_p0
			inw z_p1
			jmp ntc_lk_lp
ntc_lk_br:
			cmp #'['
			bne ntc_lk_lit
			inw z_p0
			lda #0
			sta z_t2					; ! = 1
			sta z_t3					; hit
			lda (z_p0),y
			cmp #'!'
			bne ntc_lk_cl
			inc z_t2
			inw z_p0
ntc_lk_cl:
			ldy #0
			lda (z_p0),y
			beq ntc_lk_back
			cmp #']'
			beq ntc_lk_clend
			sta z_t4					; lo
			sta z_t5					; hi
			inw z_p0
			lda (z_p0),y
			cmp #'-'
			bne ntc_lk_cmp
			iny
			lda (z_p0),y
			cmp #']'
			beq ntc_lk_cmp				; a - at the end: itself
			cmp #0
			beq ntc_lk_back
			sta z_t5
			inw z_p0
			inw z_p0
ntc_lk_cmp:
			lda z_t1
			cmp z_t4
			bcc ntc_lk_cl
			lda z_t5
			cmp z_t1
			bcc ntc_lk_cl
			lda #1
			sta z_t3
			jmp ntc_lk_cl
ntc_lk_clend:
			inw z_p0
			lda z_t3
			cmp z_t2
			beq ntc_lk_back
			inw z_p1
			jmp ntc_lk_lp
ntc_lk_lit:
			cmp z_t1
			bne ntc_lk_back
			inw z_p0
			inw z_p1
			jmp ntc_lk_lp
ntc_lk_back:
			lda z_t7
			beq ntc_lk_no
			inw z_p3
			lda z_p3
			sta z_p1
			lda z_p3+1
			sta z_p1+1
			lda z_p2
			sta z_p0
			lda z_p2+1
			sta z_p0+1
			jmp ntc_lk_lp
ntc_lk_end:
			lda (z_p0),y
			cmp #'*'
			bne ntc_lk_e2
			inw z_p0
			jmp ntc_lk_end
ntc_lk_e2:
			cmp #0
			beq ntc_lk_yes
ntc_lk_no:
			lda #1
			rts
ntc_lk_yes:
			lda #0
			rts

;## kw_strlset
;kw_strlset, <dest>, <src>  - LSet dest = src: src left in dest's length, spaces after
kw_strlset:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
kw_ls_len:
			lda (z_p1),y
			beq kw_ls_go
			iny
			bne kw_ls_len
kw_ls_go:
			sty z_t0					; dest's length
			ldy #0
			ldx #0						; 1 = the source has ended
kw_ls_lp:
			cpy z_t0
			bcs kw_ls_e
			cpx #0
			bne kw_ls_pad
			lda (z_p0),y
			bne kw_ls_put
			ldx #1
kw_ls_pad:
			lda #' '
kw_ls_put:
			sta (z_p1),y
			iny
			bne kw_ls_lp
kw_ls_e:
			rts

;## kw_strrset
;kw_strrset, <dest>, <src>  - RSet dest = src: src right in dest's length, spaces before
kw_strrset:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
kw_rs_len:
			lda (z_p1),y
			beq kw_rs_l2
			iny
			bne kw_rs_len
kw_rs_l2:
			sty z_t0					; dest's length
			ldy #0
kw_rs_len2:
			lda (z_p0),y
			beq kw_rs_go
			iny
			bne kw_rs_len2
kw_rs_go:
			sty z_t1					; src's
			lda z_t0
			beq kw_rs_e
			lda z_t1
			cmp z_t0
			bcc kw_rs_pad
			; src as long or longer: its first chars
			ldy #0
kw_rs_cp:
			lda (z_p0),y
			sta (z_p1),y
			iny
			cpy z_t0
			bne kw_rs_cp
kw_rs_e:
			rts
kw_rs_pad:
			lda z_t0
			sec
			sbc z_t1
			sta z_t2					; spaces
			ldy #0
			lda #' '
kw_rs_p:
			sta (z_p1),y
			iny
			cpy z_t2
			bne kw_rs_p
			tya							; then the source's chars after them
			clc
			adc z_p1
			sta z_p1
			bcc kw_rs_nc
			inc z_p1+1
kw_rs_nc:
			ldy #0
kw_rs_c2:
			cpy z_t1
			beq kw_rs_e2
			lda (z_p0),y
			sta (z_p1),y
			iny
			bne kw_rs_c2
kw_rs_e2:
			rts

;## kw_strfix
;kw_strfix, <var>, <n>  - String * n after a change: pad with spaces / cut to n
kw_strfix:
			NTC_POP z_p0
			pla
			sta z_t0					; n (low byte)
			pla
			ldy #0
			ldx #0						; 1 = the text has ended
kw_sf_lp:
			cpy z_t0
			bcs kw_sf_end
			cpx #0
			bne kw_sf_pad
			lda (z_p0),y
			bne kw_sf_nx
			ldx #1
kw_sf_pad:
			lda #' '
			sta (z_p0),y
kw_sf_nx:
			iny
			bne kw_sf_lp
kw_sf_end:
			lda #0
			sta (z_p0),y
			rts

;## ntc_fmt ntc_data
; Format$ with a number pattern (JSR). ntc_fmbuf holds "-123"; z_e = mindigits,
; z_f = group, z_p2 = prefix, z_p3 = suffix, z_p1 = the dest
ntc_fm_common:
			ldx #0						; index into ntc_fmbuf
			lda ntc_fmbuf
			cmp #'-'
			bne ntc_fm_pre
			ldy #0
			sta (z_p1),y
			inw z_p1
			inx
ntc_fm_pre:
			ldy #0
			lda (z_p2),y
			beq ntc_fm_cnt
			sta (z_p1),y
			inw z_p1
			inw z_p2
			jmp ntc_fm_pre
ntc_fm_cnt:
			stx z_t0					; where the digits start
			ldy #0
ntc_fm_c1:
			lda ntc_fmbuf,x
			beq ntc_fm_c2
			inx
			iny
			bne ntc_fm_c1
ntc_fm_c2:
			sty z_t1					; digits
			lda #0
			sta z_t2					; zeros in front
			lda z_e
			cmp z_t1
			bcc ntc_fm_c3
			beq ntc_fm_c3
			sec
			sbc z_t1
			sta z_t2
ntc_fm_c3:
			lda z_t1
			clc
			adc z_t2
			sta z_t3					; digits to write
			sta z_t4
ntc_fm_mod:
			lda z_t4
			cmp #4
			bcc ntc_fm_out
			sbc #3
			sta z_t4					; digits before the first comma
			jmp ntc_fm_mod
ntc_fm_out:
			ldx z_t0
ntc_fm_o1:
			lda z_t3
			beq ntc_fm_suf
			lda z_t2
			beq ntc_fm_d
			dec z_t2
			lda #'0'
			bne ntc_fm_put
ntc_fm_d:
			lda ntc_fmbuf,x
			inx
ntc_fm_put:
			ldy #0
			sta (z_p1),y
			inw z_p1
			dec z_t3
			dec z_t4
			bne ntc_fm_o1
			lda #3
			sta z_t4
			lda z_t3
			beq ntc_fm_suf
			lda z_f
			ora z_f+1
			beq ntc_fm_o1
			lda #','
			ldy #0
			sta (z_p1),y
			inw z_p1
			jmp ntc_fm_o1
ntc_fm_suf:
			ldy #0
ntc_fm_s1:
			lda (z_p3),y
			sta (z_p1),y
			beq ntc_fm_e
			iny
			bne ntc_fm_s1
ntc_fm_e:
			rts
ntc_fmbuf:	ds 16
; the four format arguments off the thread (on the thread: jmp, back with jmp (z_g))
ntc_fm_args:
			NTC_POP z_e
			NTC_POP z_f
			NTC_POP z_p2
			NTC_POP z_p3
			jmp (z_g)

;## kw_strfmt ntc_fmt ntc_itoa
;kw_strfmt, <dest>, <var>, <mindigits>, <group>, <prefix>, <suffix>  - Format$(n, "0,000")
kw_strfmt:
			NTC_POP z_p4				; dest
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			lda #<kw_sfm_b
			sta z_g
			lda #>kw_sfm_b
			sta z_g+1
			jmp ntc_fm_args
kw_sfm_b:
			NTC_RS
			lda #<ntc_fmbuf
			sta z_p1
			lda #>ntc_fmbuf
			sta z_p1+1
			jsr ntc_itoa
			lda z_p4
			sta z_p1
			lda z_p4+1
			sta z_p1+1
			jsr ntc_fm_common
			NTC_TS
			rts

;## kw_l_strfmt ntc_fmt ntc_ltoa
;kw_l_strfmt, <dest>, <long>, <mindigits>, <group>, <prefix>, <suffix>  - Format$ of a Long
kw_l_strfmt:
			NTC_POP z_p4
			NTC_POP z_p0
			ldy #3
kw_lsf_ld:
			lda (z_p0),y
			sta z_l0,y
			dey
			bpl kw_lsf_ld
			lda #<kw_lsfm_b
			sta z_g
			lda #>kw_lsfm_b
			sta z_g+1
			jmp ntc_fm_args
kw_lsfm_b:
			NTC_RS
			lda #<ntc_fmbuf
			sta z_p1
			lda #>ntc_fmbuf
			sta z_p1+1
			jsr ntc_ltoa
			lda z_p4
			sta z_p1
			lda z_p4+1
			sta z_p1+1
			jsr ntc_fm_common
			NTC_TS
			rts

;## kw_strjoin
;kw_strjoin, <dest>, <descriptor>, <sep>  - Join(stringarray, sep), NTC_STRMAX characters at most
kw_strjoin:
			NTC_POP z_p4				; dest
			NTC_POP z_p0				; descriptor
			NTC_POP z_p3				; sep
			ldy #0
			lda (z_p0),y
			sta z_p2					; base
			iny
			lda (z_p0),y
			sta z_p2+1
			ldy #6
			lda (z_p0),y
			sta z_c						; count
			iny
			lda (z_p0),y
			sta z_c+1
			ldy #10
			lda (z_p0),y
			sta z_d						; element size
			iny
			lda (z_p0),y
			sta z_d+1
			NTC_RS
			jsr ntc_join
			NTC_TS
			rts
ntc_join:
			lda #<ntc_jnbuf
			sta z_p1
			lda #>ntc_jnbuf
			sta z_p1+1
			lda #<NTC_STRMAX
			sta z_t0					; room
			lda z_c
			ora z_c+1
			beq ntc_jn_done
ntc_jn_el:
			ldy #0
ntc_jn_c1:
			lda (z_p2),y
			beq ntc_jn_eend
			ldx z_t0
			beq ntc_jn_done
			sty z_t1
			ldy #0
			sta (z_p1),y
			inw z_p1
			dec z_t0
			ldy z_t1
			iny
			bne ntc_jn_c1
ntc_jn_eend:
			clc
			lda z_p2
			adc z_d
			sta z_p2
			lda z_p2+1
			adc z_d+1
			sta z_p2+1
			lda z_c
			bne ntc_jn_dc
			dec z_c+1
ntc_jn_dc:
			dec z_c
			lda z_c
			ora z_c+1
			beq ntc_jn_done
			ldy #0
ntc_jn_c2:
			lda (z_p3),y
			beq ntc_jn_el
			ldx z_t0
			beq ntc_jn_done
			sty z_t1
			ldy #0
			sta (z_p1),y
			inw z_p1
			dec z_t0
			ldy z_t1
			iny
			bne ntc_jn_c2
ntc_jn_done:
			ldy #0
			tya
			sta (z_p1),y
ntc_jn_out:
			lda ntc_jnbuf,y
			sta (z_p4),y
			beq ntc_jn_e
			iny
			bne ntc_jn_out
ntc_jn_e:
			rts
ntc_jnbuf:	ds NTC_STRMAX+1

;## kw_strsplit
;kw_strsplit, <descriptor>, <base>, <capacity>, <text>, <sep>, <element size>  - a() = Split(text, sep)
kw_strsplit:
			NTC_POP z_p4				; descriptor
			NTC_POP z_f					; base
			NTC_POP z_c					; capacity (elements)
			NTC_POP z_p0				; text
			NTC_POP z_p3				; sep
			NTC_POP z_d					; element size
			NTC_RS
			jsr ntc_split
			NTC_TS
			rts
ntc_split:
			lda z_f
			sta z_p5					; the element being filled
			lda z_f+1
			sta z_p5+1
			lda #0
			sta z_e						; count
			sta z_e+1
			ldy #0
			lda (z_p0),y
			beq ntc_sp_fin
ntc_sp_elem:
			lda z_e						; count >= capacity: stop
			cmp z_c
			lda z_e+1
			sbc z_c+1
			bcs ntc_sp_fin
			inw z_e
			lda z_p5
			sta z_p1
			lda z_p5+1
			sta z_p1+1
			lda z_d
			sec
			sbc #1
			sta z_t0					; room in the element
ntc_sp_ch:
			ldy #0
			lda (z_p0),y
			beq ntc_sp_last
			lda (z_p3),y
			beq ntc_sp_nosep
ntc_sp_m:
			lda (z_p3),y
			beq ntc_sp_hit
			cmp (z_p0),y
			bne ntc_sp_nosep
			iny
			bne ntc_sp_m
ntc_sp_nosep:
			ldy #0
			lda (z_p0),y
			inw z_p0
			ldx z_t0
			beq ntc_sp_ch
			sta (z_p1),y
			inw z_p1
			dec z_t0
			jmp ntc_sp_ch
ntc_sp_hit:
			tya
			clc
			adc z_p0
			sta z_p0
			bcc ntc_sp_h1
			inc z_p0+1
ntc_sp_h1:
			ldy #0
			tya
			sta (z_p1),y
			clc
			lda z_p5
			adc z_d
			sta z_p5
			lda z_p5+1
			adc z_d+1
			sta z_p5+1
			jmp ntc_sp_elem
ntc_sp_last:
			ldy #0
			tya
			sta (z_p1),y
ntc_sp_fin:
			ldy #0
			lda z_f
			sta (z_p4),y
			iny
			lda z_f+1
			sta (z_p4),y
			iny
			lda #0
			sta (z_p4),y
			iny
			sta (z_p4),y
			iny
			sta (z_p4),y
			iny
			sta (z_p4),y
			iny
			lda z_e
			sta (z_p4),y
			iny
			lda z_e+1
			sta (z_p4),y
			iny
			lda #1
			sta (z_p4),y
			iny
			lda #0
			sta (z_p4),y
			iny
			lda z_d
			sta (z_p4),y
			iny
			lda z_d+1
			sta (z_p4),y
			rts

;## kw_strmidset
;kw_strmidset, <textvar>, <startvar>, <lenvar>, <src>  - Mid$(s, start, len) = src
kw_strmidset:
			NTC_POP z_p1				; text
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a						; start
			iny
			lda (z_p0),y
			sta z_a+1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_b						; len
			iny
			lda (z_p0),y
			sta z_b+1
			NTC_POP z_p2				; src
			lda z_a+1
			bne kw_ms_e					; start < 1 or > 255
			lda z_a
			beq kw_ms_e
			sec
			sbc #1
			sta z_t0					; offset
			ldy #0
kw_ms_adv:
			cpy z_t0
			beq kw_ms_at
			lda (z_p1),y
			beq kw_ms_e
			iny
			bne kw_ms_adv
kw_ms_at:
			lda z_b+1					; past 255 (or below 0): 255
			beq kw_ms_l1
			lda #255
			sta z_b
kw_ms_l1:
			ldx z_b
			beq kw_ms_e
			lda #0
			sta z_t1					; src index
kw_ms_cp:
			lda (z_p1),y
			beq kw_ms_e
			sty z_t2
			ldy z_t1
			lda (z_p2),y
			beq kw_ms_e
			inc z_t1
			ldy z_t2
			sta (z_p1),y
			iny
			dex
			bne kw_ms_cp
kw_ms_e:
			rts

;## kw_strmid ntc_getn ntc_sncpy
;kw_strmid, <dest>, <src>, <startvar>, <lenvar>  - Mid$(src, start, len)
kw_strmid:
			NTC_POP z_p1
			NTC_POP z_p0
			NTC_POP z_p5
			NTC_RS
			jsr ntc_getn
			NTC_TS
			tax
			beq kw_sm_s1
			dex							; start - 1 chars to skip
kw_sm_s1:
			ldy #0
kw_sm_sk:
			cpx #0
			beq kw_sm_len
			lda (z_p0),y
			beq kw_sm_len
			inw z_p0
			dex
			jmp kw_sm_sk
kw_sm_len:
			NTC_POP z_p5
			NTC_RS
			jsr ntc_getn
			tax
			jsr ntc_sncpy
			NTC_TS
			rts

;## kw_strchr
;kw_strchr, <dest>, <nvar>  - Chr$(n)
kw_strchr:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			rts

;## kw_strcstr ntc_itoa
;kw_strcstr, <dest>, <nvar>  - number to text (CStr, "x" & n)
kw_strcstr:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			NTC_RS
			jsr ntc_itoa
			NTC_TS
			rts

;## kw_strstr ntc_itoa
;kw_strstr, <dest>, <nvar>  - Str$(n): a space before 0 and positives
kw_strstr:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_a
			iny
			lda (z_p0),y
			sta z_a+1
			bmi kw_st_go
			lda #' '
			ldy #0
			sta (z_p1),y
			inw z_p1
kw_st_go:
			NTC_RS
			jsr ntc_itoa
			NTC_TS
			rts

;## ntc_hexdig
; A = 0 .. 15: its hex digit ('0'-'9', 'A'-'F')
ntc_hexdig:
			cmp #10
			bcc ntc_hd_n
			adc #6						; (carry set: + 7)
ntc_hd_n:
			adc #'0'
			rts

;## kw_strhex ntc_hexdig
;kw_strhex, <dest>, <nvar>  - Hex$(n), no leading zeros
kw_strhex:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			sta z_l0
			iny
			lda (z_p0),y
			sta z_l0+1
			lda #0
			sta z_l0+2
			sta z_l0+3
			NTC_RS
			ldx #3						; 4 digits (after NTC_RS: it uses X)
			jsr ntc_hexout
			NTC_TS
			rts
; z_l0: X + 1 hex digits (from the top: digit X first) to z_p1, no leading zeros, then the 0
ntc_hexout:
			lda #0
			sta z_t1					; a digit seen
			sta z_t2					; out index
ntc_hx_lp:
			stx z_t3
			txa							; digit X: byte X / 2, the high nibble when X is odd
			lsr
			tay
			lda z_l0,y
			bcc ntc_hx_lo
			lsr
			lsr
			lsr
			lsr
ntc_hx_lo:
			and #$0F
			bne ntc_hx_out
			ldy z_t1
			bne ntc_hx_out
			ldy z_t3
			bne ntc_hx_next
ntc_hx_out:
			jsr ntc_hexdig
			ldy z_t2
			sta (z_p1),y
			inc z_t2
			lda #1
			sta z_t1
ntc_hx_next:
			ldx z_t3
			dex
			bpl ntc_hx_lp
			ldy z_t2
			lda #0
			sta (z_p1),y
			rts

;## kw_strspace ntc_getn
;kw_strspace, <dest>, <nvar>  - Space$(n)
kw_strspace:
			NTC_POP z_p1
			NTC_POP z_p5
			NTC_RS
			jsr ntc_getn
			NTC_TS
			tax
			lda #' '
; X = count (NTC_STRMAX at most), A = char, z_p1 = dest. rts
ntc_strfill:
			cpx #<NTC_STRMAX
			bcc ntc_sf_ok
			beq ntc_sf_ok
			ldx #<NTC_STRMAX
ntc_sf_ok:
			ldy #0
			cpx #0
			beq ntc_sf_end
ntc_sf_lp:
			sta (z_p1),y
			iny
			dex
			bne ntc_sf_lp
ntc_sf_end:
			lda #0
			sta (z_p1),y
			rts

;## kw_strstring kw_strspace
;kw_strstring, <dest>, <nvar>, <charvar>  - String$(n, char code)
kw_strstring:
			NTC_POP z_p1
			NTC_POP z_p5
			NTC_RS
			jsr ntc_getn
			NTC_TS
			tax
			NTC_POP z_p0
			ldy #0
			lda (z_p0),y
			jmp ntc_strfill

;## kw_strucase
;kw_strucase, <dest>, <src>  - UCase$
kw_strucase:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
kw_uc_lp:
			lda (z_p0),y
			cmp #'a'
			bcc kw_uc_put
			cmp #'z'+1
			bcs kw_uc_put
			sbc #31						; (carry clear: - 32)
kw_uc_put:
			sta (z_p1),y
			tax							; (the flags: a compare came last)
			beq kw_uc_e
			iny
			bne kw_uc_lp
kw_uc_e:
			rts

;## kw_strlcase
;kw_strlcase, <dest>, <src>  - LCase$
kw_strlcase:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #0
kw_lc_lp:
			lda (z_p0),y
			cmp #'A'
			bcc kw_lc_put
			cmp #'Z'+1
			bcs kw_lc_put
			adc #32						; (carry clear)
kw_lc_put:
			sta (z_p1),y
			tax							; (the flags: a compare came last)
			beq kw_lc_e
			iny
			bne kw_lc_lp
kw_lc_e:
			rts

;## kw_strltrim ntc_sncpy
;kw_strltrim, <dest>, <src>  - LTrim$
kw_strltrim:
			NTC_POP z_p1
			NTC_POP z_p0
kw_lt_skip:
			ldy #0
			lda (z_p0),y
			cmp #' '
			bne kw_lt_copy
			inw z_p0
			jmp kw_lt_skip
kw_lt_copy:
			ldx #255
			jmp ntc_sncpy

;## kw_strrtrim
;kw_strrtrim, <dest>, <src>  - RTrim$
kw_strrtrim:
			NTC_POP z_p1
			NTC_POP z_p0
ntc_rt_go:
			ldy #0
ntc_rt_copy:
			lda (z_p0),y
			sta (z_p1),y
			beq ntc_rt_lp
			iny
			bne ntc_rt_copy
ntc_rt_lp:
			cpy #0						; Y on the 0
			beq ntc_rt_e
			dey
			lda (z_p1),y
			cmp #' '
			bne ntc_rt_e
			lda #0
			sta (z_p1),y
			jmp ntc_rt_lp
ntc_rt_e:
			rts

;## kw_strtrim kw_strrtrim
;kw_strtrim, <dest>, <src>  - Trim$
kw_strtrim:
			NTC_POP z_p1
			NTC_POP z_p0
kw_tr_skip:
			ldy #0
			lda (z_p0),y
			cmp #' '
			bne ntc_rt_go
			inw z_p0
			jmp kw_tr_skip

;## kw_strasc
;kw_strasc, <src>, <destvar>  - Asc(src), 0 if empty
kw_strasc:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			rts

;## kw_strval ntc_atoi
;kw_strval, <src>, <destvar>  - Val(src): decimal or &H hex
kw_strval:
			NTC_POP z_p0
			NTC_POP z_p3
			NTC_RS
			jsr ntc_atoi
			NTC_TS
			rts

;## kw_strinstr ntc_getn
;kw_strinstr, <startvar>, <s1>, <s2>, <destvar>  - InStr(start, s1, s2)
kw_strinstr:
			NTC_POP z_p5
			NTC_POP z_p0				; s1
			NTC_POP z_p2				; s2
			NTC_RS
			jsr ntc_getn
			bne kw_in_s1
			lda #1
kw_in_s1:
			sta z_t4					; the result if found here (1 based)
			tax
kw_in_adv:
			dex
			beq kw_in_try
			ldy #0
			lda (z_p0),y
			beq kw_in_nf
			inw z_p0
			jmp kw_in_adv
kw_in_try:
			ldy #0
kw_in_cmp:
			lda (z_p2),y
			beq kw_in_found
			cmp (z_p0),y
			bne kw_in_miss
			iny
			bne kw_in_cmp
kw_in_miss:
			ldy #0
			lda (z_p0),y
			beq kw_in_nf
			inw z_p0
			inc z_t4
			jmp kw_in_try
kw_in_nf:
			lda #0
			sta z_t4
kw_in_found:
			NTC_TS
			NTC_POP z_p1
			ldy #0
			lda z_t4
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			rts

;## ntc_strcmp
; z_p0 = a, z_p1 = b: compare (JSR): Z = equal, C clear = a < b (unsigned bytes)
ntc_strcmp:
			ldy #0
ntc_scm_lp:
			lda (z_p0),y
			cmp (z_p1),y
			bne ntc_scm_e
			cmp #0
			beq ntc_scm_eq
			iny
			bne ntc_scm_lp
ntc_scm_eq:
			sec							; (equal: Z set, C set)
ntc_scm_e:
			rts
; the two strings off the thread, compared: z_t0 = 0 equal, 1 a < b, 2 a > b
ntc_strcmp3:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
ntc_sc3_lp:
			lda (z_p0),y
			cmp (z_p1),y
			bne ntc_sc3_ne
			cmp #0
			beq ntc_sc3_eq
			iny
			bne ntc_sc3_lp
ntc_sc3_eq:
			lda #0
			sta z_t0
			jmp (z_g)
ntc_sc3_ne:
			lda #1
			bcc ntc_sc3_lt
			lda #2
ntc_sc3_lt:
			sta z_t0
			jmp (z_g)

;## kw_strcmplt ntc_strcmp
;kw_strcmplt, <a>, <b>  - Z if a < b
kw_strcmplt:
			lda #<kw_sclt
			sta z_g
			lda #>kw_sclt
			sta z_g+1
			jmp ntc_strcmp3
kw_sclt:
			lda z_t0
			cmp #1
			beq kw_sclt_t
			lda #1
			rts
kw_sclt_t:
			lda #0
			rts

;## kw_strcmple ntc_strcmp
kw_strcmple:
			lda #<kw_scle
			sta z_g
			lda #>kw_scle
			sta z_g+1
			jmp ntc_strcmp3
kw_scle:
			lda z_t0
			cmp #2
			beq kw_scle_f
			lda #0
			rts
kw_scle_f:
			lda #1
			rts

;## kw_strcmpgt ntc_strcmp
kw_strcmpgt:
			lda #<kw_scgt
			sta z_g
			lda #>kw_scgt
			sta z_g+1
			jmp ntc_strcmp3
kw_scgt:
			lda z_t0
			cmp #2
			beq kw_scgt_t
			lda #1
			rts
kw_scgt_t:
			lda #0
			rts

;## kw_strcmpge ntc_strcmp
kw_strcmpge:
			lda #<kw_scge
			sta z_g
			lda #>kw_scge
			sta z_g+1
			jmp ntc_strcmp3
kw_scge:
			lda z_t0
			cmp #1
			beq kw_scge_f
			lda #0
			rts
kw_scge_f:
			lda #1
			rts

; ============================================================
; String arrays (element size = capacity + 1 bytes, no capacity byte)
; ============================================================

;## ntc_sidx
; z_p0 = array base, z_p1 = the index var, z_b = element size: z_p0 = the element
; (the multiplier). Uses A
ntc_sidx:
			ldy #0
			lda (z_p1),y
			sta $D770
			iny
			lda (z_p1),y
			sta $D771
			lda #0
			sta $D772
			sta $D773
			sta $D776
			sta $D777
			lda z_b
			sta $D774
			lda z_b+1
			sta $D775
			clc
			lda z_p0
			adc $D778
			sta z_p0
			lda z_p0+1
			adc $D779
			sta z_p0+1
			rts

;## kw_sget ntc_sidx
;kw_sget, <arraybase>, <indexvar>, <dest>, <element size>  - dest = array(index)
kw_sget:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2				; dest
			NTC_POP z_b					; size
			NTC_RS
			jsr ntc_sidx
			NTC_TS
			ldy #0
			ldx z_b
			beq kw_sg_e
kw_sg_lp:
			lda (z_p0),y
			sta (z_p2),y
			iny
			dex
			bne kw_sg_lp
kw_sg_e:
			rts

;## kw_sset ntc_sidx ntc_scopy
;kw_sset, <arraybase>, <indexvar>, <src>, <element size>  - array(index) = src, cut at the element
kw_sset:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2				; src
			NTC_POP z_b					; size
			NTC_RS
			jsr ntc_sidx
			NTC_TS
			lda z_p0
			sta z_p1
			lda z_p0+1
			sta z_p1+1
			lda z_p2
			sta z_p0
			lda z_p2+1
			sta z_p0+1
			ldx z_b
			dex							; capacity
			jmp ntc_scopy

; ============================================================
; Array parameters and dynamic arrays. A procedure gets the address of a
; 12 byte descriptor: dw base, lower bound 1, lower bound 2, count 1,
; count 2, element size.
; ============================================================

;## ntc_paddr
; z_p0 = descriptor, z_p1 = index var (JSR): z_p0 = the element address,
; z_b = element size. Uses A, Y, z_a
ntc_paddr:
			ldy #0
			lda (z_p1),y
			ldy #2
			sec
			sbc (z_p0),y
			sta z_a
			ldy #1
			lda (z_p1),y
			ldy #3
			sbc (z_p0),y
			sta z_a+1					; element number
ntc_pa_tail:					; z_a = element number, z_p0 = descriptor
			ldy #10
			lda (z_p0),y
			sta z_b
			iny
			lda (z_p0),y
			sta z_b+1
			lda z_a
			sta $D770
			lda z_a+1
			sta $D771
			lda #0
			sta $D772
			sta $D773
			sta $D776
			sta $D777
			lda z_b
			sta $D774
			lda z_b+1
			sta $D775
			ldy #0
			lda (z_p0),y
			clc
			adc $D778
			tax
			iny
			lda (z_p0),y
			adc $D779
			sta z_p0+1
			stx z_p0
			rts

;## ntc_paddr2 ntc_paddr
; z_p0 = descriptor, z_p1 / z_p2 = the 2 index vars (JSR): z_p0 = element address,
; z_b = size
ntc_paddr2:
			ldy #0
			lda (z_p1),y
			ldy #2
			sec
			sbc (z_p0),y
			sta $D770
			ldy #1
			lda (z_p1),y
			ldy #3
			sbc (z_p0),y
			sta $D771					; (i - lo1)
			lda #0
			sta $D772
			sta $D773
			sta $D776
			sta $D777
			ldy #8
			lda (z_p0),y
			sta $D774
			iny
			lda (z_p0),y
			sta $D775					; * count 2
			ldy #0
			lda (z_p2),y
			ldy #4
			sec
			sbc (z_p0),y
			sta z_a
			ldy #1
			lda (z_p2),y
			ldy #5
			sbc (z_p0),y
			sta z_a+1					; + (j - lo2)
			clc
			lda z_a
			adc $D778
			sta z_a
			lda z_a+1
			adc $D779
			sta z_a+1
			jmp ntc_pa_tail

;## ntc_pgset ntc_paddr
; after ntc_paddr: copy z_b bytes between the element (z_p0) and the var (z_p3):
; ntc_pg_get element -> var (a Byte element: into the Integer's low byte, high 0),
; ntc_pg_set var -> element. On the thread (rts)
ntc_pg_get:
			ldy #0
			lda z_b
			cmp #1
			bne ntc_pg_g2
			lda (z_p0),y
			sta (z_p3),y
			iny
			lda #0
			sta (z_p3),y
			rts
ntc_pg_g2:
			ldx z_b
			beq ntc_pg_ge
ntc_pg_gl:
			lda (z_p0),y
			sta (z_p3),y
			iny
			dex
			bne ntc_pg_gl
ntc_pg_ge:
			rts
ntc_pg_set:
			ldy #0
			ldx z_b
			beq ntc_pg_se
ntc_pg_sl:
			lda (z_p3),y
			sta (z_p0),y
			iny
			dex
			bne ntc_pg_sl
ntc_pg_se:
			rts

;## kw_pget ntc_paddr ntc_pgset
;kw_pget, <descriptor>, <indexvar>, <dest>  - dest = parameter array(index)
kw_pget:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p3
			NTC_RS
			jsr ntc_paddr
			NTC_TS
			jmp ntc_pg_get

;## kw_pset ntc_paddr ntc_pgset
;kw_pset, <descriptor>, <indexvar>, <src>  - parameter array(index) = src
kw_pset:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p3
			NTC_RS
			jsr ntc_paddr
			NTC_TS
			jmp ntc_pg_set

;## kw_psets ntc_paddr ntc_scopy
;kw_psets, <descriptor>, <indexvar>, <src>  - String parameter array(index) = src
kw_psets:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p3
			NTC_RS
			jsr ntc_paddr
			NTC_TS
ntc_psets_t:
			lda z_p0
			sta z_p1
			lda z_p0+1
			sta z_p1+1
			lda z_p3
			sta z_p0
			lda z_p3+1
			sta z_p0+1
			ldx z_b
			dex
			jmp ntc_scopy

;## kw_psets2 ntc_paddr2 kw_psets
;kw_psets2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src (String)
kw_psets2:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			NTC_POP z_p3
			NTC_RS
			jsr ntc_paddr2
			NTC_TS
			jmp ntc_psets_t

;## kw_pget2 ntc_paddr2 ntc_pgset
;kw_pget2, <descriptor>, <index1var>, <index2var>, <dest>  - dest = array(i, j)
kw_pget2:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			NTC_POP z_p3
			NTC_RS
			jsr ntc_paddr2
			NTC_TS
			jmp ntc_pg_get

;## kw_pset2 ntc_paddr2 ntc_pgset
;kw_pset2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src
kw_pset2:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			NTC_POP z_p3
			NTC_RS
			jsr ntc_paddr2
			NTC_TS
			jmp ntc_pg_set

;## kw_lbound
;kw_lbound, <descriptor + 2 * (dimension - 1)>, <dest>  - LBound
kw_lbound:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #2
			lda (z_p0),y
			ldy #0
			sta (z_p1),y
			ldy #3
			lda (z_p0),y
			ldy #1
			sta (z_p1),y
			rts

;## kw_ubound
;kw_ubound, <descriptor + 2 * (dimension - 1)>, <dest>  - UBound = lower bound + count - 1
kw_ubound:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #2
			lda (z_p0),y
			ldy #6
			clc
			adc (z_p0),y
			sta z_a
			ldy #3
			lda (z_p0),y
			ldy #7
			adc (z_p0),y
			sta z_a+1
			lda z_a
			sec
			sbc #1
			ldy #0
			sta (z_p1),y
			lda z_a+1
			sbc #0
			iny
			sta (z_p1),y
			rts

; ============================================================
; Long (32 bit signed, little endian). Every argument is an address
; (a literal is 4 bytes in the program).
; ============================================================

;## kw_l_mov
kw_l_mov:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #3
kw_lmv_lp:
			lda (z_p0),y
			sta (z_p1),y
			dey
			bpl kw_lmv_lp
			rts

;## kw_l_itol
;kw_l_itol, <intvar>, <dest>  - Integer to Long (sign extended)
kw_l_itol:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			iny
			lda (z_p0),y
			sta (z_p1),y
			ldx #0
			asl
			bcc kw_lit_p
			ldx #$FF
kw_lit_p:
			txa
			iny
			sta (z_p1),y
			iny
			sta (z_p1),y
			rts

;## kw_l_ltoi
;kw_l_ltoi, <long>, <intdest>  - Long to Integer (low 16 bits)
kw_l_ltoi:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p0),y
			sta (z_p1),y
			iny
			lda (z_p0),y
			sta (z_p1),y
			rts

;## kw_l_add
kw_l_add:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			ldx #4
			clc
kw_lad_lp:
			lda (z_p0),y
			adc (z_p1),y
			sta (z_p2),y
			iny
			dex
			bne kw_lad_lp
			rts

;## kw_l_sub
kw_l_sub:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #0
			ldx #4
			sec
kw_lsb_lp:
			lda (z_p0),y
			sbc (z_p1),y
			sta (z_p2),y
			iny
			dex
			bne kw_lsb_lp
			rts

;## kw_l_and
kw_l_and:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #3
kw_lan_lp:
			lda (z_p0),y
			and (z_p1),y
			sta (z_p2),y
			dey
			bpl kw_lan_lp
			rts

;## kw_l_or
kw_l_or:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #3
kw_lor_lp:
			lda (z_p0),y
			ora (z_p1),y
			sta (z_p2),y
			dey
			bpl kw_lor_lp
			rts

;## kw_l_xor
kw_l_xor:
			NTC_POP z_p0
			NTC_POP z_p1
			NTC_POP z_p2
			ldy #3
kw_lxr_lp:
			lda (z_p0),y
			eor (z_p1),y
			sta (z_p2),y
			dey
			bpl kw_lxr_lp
			rts

;## kw_l_not
kw_l_not:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #3
kw_lnt_lp:
			lda (z_p0),y
			eor #$FF
			sta (z_p2),y
			dey
			bpl kw_lnt_lp
			rts

;## kw_l_neg
kw_l_neg:
			NTC_POP z_p0
			NTC_POP z_p2
ntc_lneg_go:
			ldy #0
			ldx #4
			sec
kw_lng_lp:
			lda #0
			sbc (z_p0),y
			sta (z_p2),y
			iny
			dex
			bne kw_lng_lp
			rts

;## kw_l_abs kw_l_neg
kw_l_abs:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #3
			lda (z_p0),y
			bmi ntc_lneg_go
kw_lab_lp:
			lda (z_p0),y
			sta (z_p2),y
			dey
			bpl kw_lab_lp
			rts

;## kw_l_sgn
;kw_l_sgn, <a>, <intdest>  - -1, 0 or 1
kw_l_sgn:
			NTC_POP z_p0
			NTC_POP z_p2
			ldy #3
			lda (z_p0),y
			bmi kw_lsg_m
			ldy #0
			ora (z_p0),y
			iny
			ora (z_p0),y
			iny
			ora (z_p0),y
			beq kw_lsg_z
			lda #1
			ldx #0
			beq kw_lsg_st
kw_lsg_m:
			lda #$FF
			tax
			bne kw_lsg_st
kw_lsg_z:
			tax
kw_lsg_st:
			ldy #0
			sta (z_p2),y
			iny
			txa
			sta (z_p2),y
			rts

;## ntc_lcmp
; the two Longs off the thread into z_l0 (a), z_l1 (b); then a - b: z_t0 = 0 when
; equal, A = the result's high byte with the sign fixed (bit 7 = a < b signed)
ntc_lcmp_ld:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			ldx #4
			sec
			lda #0
			sta z_t0
ntc_lcl_lp:
			lda (z_p0),y
			sbc (z_p1),y
			sta z_l2,y
			iny
			dex
			bne ntc_lcl_lp
			bvc ntc_lcl_v
			eor #$80
ntc_lcl_v:
			sta z_t1					; bit 7 = a < b
			lda z_l2
			ora z_l2+1
			ora z_l2+2
			ora z_l2+3
			sta z_t0					; 0 = equal
			jmp (z_g)
ntc_lcmp_lt:
			lda z_t1
			bmi ntc_lcmp_t
ntc_lcmp_f:
			lda #1
			rts
ntc_lcmp_t:
			lda #0
			rts
ntc_lcmp_ge:
			lda z_t1
			bpl ntc_lcmp_t
			lda #1
			rts
ntc_lcmp_le:
			lda z_t1
			bmi ntc_lcmp_t
			lda z_t0
			beq ntc_lcmp_t
			lda #1
			rts
ntc_lcmp_gt:
			lda z_t1
			bmi ntc_lcmp_f
			lda z_t0
			beq ntc_lcmp_f
			lda #0
			rts
ntc_lcmp_eq:
			lda z_t0
			beq ntc_lcmp_t
			lda #1
			rts
ntc_lcmp_ne:
			lda z_t0
			bne ntc_lcmp_t
			lda #1
			rts

;## kw_l_cplt ntc_lcmp
kw_l_cplt:
			lda #<ntc_lcmp_lt
			sta z_g
			lda #>ntc_lcmp_lt
			sta z_g+1
			jmp ntc_lcmp_ld

;## kw_l_cple ntc_lcmp
kw_l_cple:
			lda #<ntc_lcmp_le
			sta z_g
			lda #>ntc_lcmp_le
			sta z_g+1
			jmp ntc_lcmp_ld

;## kw_l_cpgt ntc_lcmp
kw_l_cpgt:
			lda #<ntc_lcmp_gt
			sta z_g
			lda #>ntc_lcmp_gt
			sta z_g+1
			jmp ntc_lcmp_ld

;## kw_l_cpge ntc_lcmp
kw_l_cpge:
			lda #<ntc_lcmp_ge
			sta z_g
			lda #>ntc_lcmp_ge
			sta z_g+1
			jmp ntc_lcmp_ld

;## kw_l_cpeq ntc_lcmp
kw_l_cpeq:
			lda #<ntc_lcmp_eq
			sta z_g
			lda #>ntc_lcmp_eq
			sta z_g+1
			jmp ntc_lcmp_ld

;## kw_l_cpne ntc_lcmp
kw_l_cpne:
			lda #<ntc_lcmp_ne
			sta z_g
			lda #>ntc_lcmp_ne
			sta z_g+1
			jmp ntc_lcmp_ld

;## ntc_lmul
; z_l0 * z_l1 -> z_l0 (low 32 bits: the hardware multiplier). JSR or inline
ntc_lmul:
			ldx #3
ntc_lml_lp:
			lda z_l0,x
			sta $D770,x
			lda z_l1,x
			sta $D774,x
			dex
			bpl ntc_lml_lp
			ldx #3
ntc_lml_out:
			lda $D778,x
			sta z_l0,x
			dex
			bpl ntc_lml_out
			rts

;## ntc_ldiv
; z_l0 / z_l1 signed, truncating (JSR): z_l0 = quotient, z_l1 = remainder (the
; dividend's sign). Divide by 0: quotient 0, remainder = dividend. Uses z_l2, z_t0, z_t1
ntc_ldiv:
			lda z_l1
			ora z_l1+1
			ora z_l1+2
			ora z_l1+3
			bne ntc_ld_nz
			ldx #3
ntc_ld_z:
			lda z_l0,x
			sta z_l1,x
			lda #0
			sta z_l0,x
			dex
			bpl ntc_ld_z
			rts
ntc_ld_nz:
			lda z_l0+3
			sta z_t0					; the dividend's sign
			eor z_l1+3
			sta z_t1					; the quotient's
			lda z_l0+3
			bpl ntc_ld_ap
			ldx #z_l0
			jsr ntc_lnegz
ntc_ld_ap:
			lda z_l1+3
			bpl ntc_ld_bp
			ldx #z_l1
			jsr ntc_lnegz
ntc_ld_bp:
			jsr ntc_ludiv
			lda z_t1
			bpl ntc_ld_qp
			ldx #z_l0
			jsr ntc_lnegz
ntc_ld_qp:
			ldx #3
ntc_ld_r:
			lda z_l2,x
			sta z_l1,x
			dex
			bpl ntc_ld_r
			lda z_t0
			bpl ntc_ld_rp
			ldx #z_l1
			jsr ntc_lnegz
ntc_ld_rp:
			rts
; the Long in the base page at X: negated
ntc_lnegz:
			sec
			lda #0
			sbc 0,x
			sta 0,x
			lda #0
			sbc 1,x
			sta 1,x
			lda #0
			sbc 2,x
			sta 2,x
			lda #0
			sbc 3,x
			sta 3,x
			rts
; z_l0 / z_l1 unsigned: z_l0 = quotient, z_l2 = remainder. Uses A, X, Y
ntc_ludiv:
			lda #0
			sta z_l2
			sta z_l2+1
			sta z_l2+2
			sta z_l2+3
			ldx #32
ntc_lud_lp:
			asl z_l0
			rol z_l0+1
			rol z_l0+2
			rol z_l0+3
			rol z_l2
			rol z_l2+1
			rol z_l2+2
			rol z_l2+3
			sec
			lda z_l2
			sbc z_l1
			sta z_t2
			lda z_l2+1
			sbc z_l1+1
			sta z_t3
			lda z_l2+2
			sbc z_l1+2
			sta z_t4
			lda z_l2+3
			sbc z_l1+3
			bcc ntc_lud_no
			sta z_l2+3
			lda z_t4
			sta z_l2+2
			lda z_t3
			sta z_l2+1
			lda z_t2
			sta z_l2
			inc z_l0
ntc_lud_no:
			dex
			bne ntc_lud_lp
			rts

;## ntc_l2args
; two Longs off the thread into z_l0 and z_l1 (on the thread: jmp, back with jmp (z_g))
ntc_l2args:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #3
ntc_l2a_lp:
			lda (z_p0),y
			sta z_l0,y
			lda (z_p1),y
			sta z_l1,y
			dey
			bpl ntc_l2a_lp
			jmp (z_g)
; z_l0 (ntc_lst0) or z_l1 (ntc_lst1) into the Long whose address is next on the thread
ntc_lst0:
			NTC_POP z_p2
			ldy #3
ntc_ls0_lp:
			lda z_l0,y
			sta (z_p2),y
			dey
			bpl ntc_ls0_lp
			rts
ntc_lst1:
			NTC_POP z_p2
			ldy #3
ntc_ls1_lp:
			lda z_l1,y
			sta (z_p2),y
			dey
			bpl ntc_ls1_lp
			rts

;## kw_l_mul ntc_lmul ntc_l2args
kw_l_mul:
			lda #<kw_lmu_b
			sta z_g
			lda #>kw_lmu_b
			sta z_g+1
			jmp ntc_l2args
kw_lmu_b:
			NTC_RS
			jsr ntc_lmul
			NTC_TS
			jmp ntc_lst0

;## kw_l_div ntc_ldiv ntc_l2args
kw_l_div:
			lda #<kw_ldv_b
			sta z_g
			lda #>kw_ldv_b
			sta z_g+1
			jmp ntc_l2args
kw_ldv_b:
			NTC_RS
			jsr ntc_ldiv
			NTC_TS
			jmp ntc_lst0

;## kw_l_mod ntc_ldiv ntc_l2args
kw_l_mod:
			lda #<kw_lmd_b
			sta z_g
			lda #>kw_lmd_b
			sta z_g+1
			jmp ntc_l2args
kw_lmd_b:
			NTC_RS
			jsr ntc_ldiv
			NTC_TS
			jmp ntc_lst1

;## kw_l_pow ntc_lmul ntc_l2args
;kw_l_pow, <base>, <exp>, <dest>  - Long ^ (low 32 bits; exp < 0 gives 0)
kw_l_pow:
			lda #<kw_lpw_b
			sta z_g
			lda #>kw_lpw_b
			sta z_g+1
			jmp ntc_l2args
kw_lpw_b:
			NTC_RS
			jsr ntc_lpow
			NTC_TS
			jmp ntc_lst0
ntc_lpow:
			ldx #3
ntc_lpw_cp:
			lda z_l0,x					; z_l3 = base, z_l2 = exp, z_l0 = 1
			sta z_l3,x
			lda z_l1,x
			sta z_l2,x
			lda #0
			sta z_l0,x
			dex
			bpl ntc_lpw_cp
			lda z_l2+3
			bmi ntc_lpw_e				; exp < 0: 0
			inc z_l0
ntc_lpw_lp:
			lda z_l2
			ora z_l2+1
			ora z_l2+2
			ora z_l2+3
			beq ntc_lpw_e
			ldx #3
ntc_lpw_b:
			lda z_l3,x
			sta z_l1,x
			dex
			bpl ntc_lpw_b
			jsr ntc_lmul
			lda z_l2					; exp - 1
			sec
			sbc #1
			sta z_l2
			lda z_l2+1
			sbc #0
			sta z_l2+1
			lda z_l2+2
			sbc #0
			sta z_l2+2
			lda z_l2+3
			sbc #0
			sta z_l2+3
			jmp ntc_lpw_lp
ntc_lpw_e:
			rts

;## ntc_ltoa ntc_data
; the Long z_l0 to text at z_p1, a 0 at the end (z_p1 on it). JSR. Uses z_l0-z_l2
ntc_ltoa:
			lda z_l0+3
			bpl ntc_lta_pos
			lda #'-'
			ldy #0
			sta (z_p1),y
			inw z_p1
			ldx #z_l0
			jsr ntc_lnegz_t
ntc_lta_pos:
			ldx #0
ntc_lta_lp:
			stx z_t6
			; z_l0 / 10: remainder in A
			lda #0
			sta z_t5
			ldy #32
ntc_lta_dv:
			asl z_l0
			rol z_l0+1
			rol z_l0+2
			rol z_l0+3
			rol z_t5
			lda z_t5
			cmp #10
			bcc ntc_lta_n
			sbc #10
			sta z_t5
			inc z_l0
ntc_lta_n:
			dey
			bne ntc_lta_dv
			ldx z_t6
			lda z_t5
			ora #'0'
			sta ntc_lta_tmp,x
			inx
			lda z_l0
			ora z_l0+1
			ora z_l0+2
			ora z_l0+3
			bne ntc_lta_lp
			ldy #0
ntc_lta_cp:
			dex
			lda ntc_lta_tmp,x
			sta (z_p1),y
			iny
			cpx #0
			bne ntc_lta_cp
			lda #0
			sta (z_p1),y
			tya
			clc
			adc z_p1
			sta z_p1
			bcc ntc_lta_e
			inc z_p1+1
ntc_lta_e:
			rts
ntc_lnegz_t:
			sec
			lda #0
			sbc 0,x
			sta 0,x
			lda #0
			sbc 1,x
			sta 1,x
			lda #0
			sbc 2,x
			sta 2,x
			lda #0
			sbc 3,x
			sta 3,x
			rts
ntc_lta_tmp:	ds 12

;## ntc_lload
; the Long whose address is next on the thread into z_l0 (jmp, back with jmp (z_g))
ntc_lload:
			NTC_POP z_p0
			ldy #3
ntc_lld_lp:
			lda (z_p0),y
			sta z_l0,y
			dey
			bpl ntc_lld_lp
			jmp (z_g)

;## kw_l_print ntc_ltoa ntc_printbuf
kw_l_print:
			NTC_POP z_p0
			ldy #3
kw_lpr_ld:
			lda (z_p0),y
			sta z_l0,y
			dey
			bpl kw_lpr_ld
			lda #<ntc_numbuf
			sta z_p1
			lda #>ntc_numbuf
			sta z_p1+1
			NTC_RS
			jsr ntc_ltoa
			lda #<ntc_numbuf
			sta z_p0
			lda #>ntc_numbuf
			sta z_p0+1
			jsr ntc_puts
			NTC_TS
			rts

;## kw_l_printvb ntc_ltoa ntc_printbuf
kw_l_printvb:
			NTC_POP z_p0
			ldy #3
kw_lpv_ld:
			lda (z_p0),y
			sta z_l0,y
			dey
			bpl kw_lpv_ld
			lda #<ntc_numbuf
			sta z_p1
			lda #>ntc_numbuf
			sta z_p1+1
			lda z_l0+3
			bmi kw_lpv_neg
			lda #' '
			ldy #0
			sta (z_p1),y
			inw z_p1
kw_lpv_neg:
			NTC_RS
			jsr ntc_ltoa
			ldy #0
			lda #' '
			sta (z_p1),y
			iny
			lda #0
			sta (z_p1),y
			lda #<ntc_numbuf
			sta z_p0
			lda #>ntc_numbuf
			sta z_p0+1
			jsr ntc_puts
			NTC_TS
			rts

;## kw_l_cstr ntc_ltoa
kw_l_cstr:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #3
kw_lcs_ld:
			lda (z_p0),y
			sta z_l0,y
			dey
			bpl kw_lcs_ld
			NTC_RS
			jsr ntc_ltoa
			NTC_TS
			rts

;## kw_l_str ntc_ltoa
kw_l_str:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #3
kw_lst_ld:
			lda (z_p0),y
			sta z_l0,y
			dey
			bpl kw_lst_ld
			lda z_l0+3
			bmi kw_lst_go
			lda #' '
			ldy #0
			sta (z_p1),y
			inw z_p1
kw_lst_go:
			NTC_RS
			jsr ntc_ltoa
			NTC_TS
			rts

;## kw_l_hex kw_strhex
;kw_l_hex, <dest>, <long>  - Hex$(Long): upper case, no leading zeros
kw_l_hex:
			NTC_POP z_p1
			NTC_POP z_p0
			ldy #3
kw_lhx_ld:
			lda (z_p0),y
			sta z_l0,y
			dey
			bpl kw_lhx_ld
			NTC_RS
			ldx #7
			jsr ntc_hexout
			NTC_TS
			rts

;## kw_l_val
;kw_l_val, <src>, <destlong>  - Val() to a Long (decimal)
kw_l_val:
			NTC_POP z_p0
			NTC_POP z_p3
			NTC_RS
			jsr ntc_lval
			NTC_TS
			rts
; the text at z_p0 to a Long into z_p3 (JSR)
ntc_lval:
			lda #0
			sta z_l0
			sta z_l0+1
			sta z_l0+2
			sta z_l0+3
			sta z_t1					; minus
			ldy #0
ntc_lv_sp:
			lda (z_p0),y
			cmp #' '
			bne ntc_lv_sg
			iny
			bne ntc_lv_sp
ntc_lv_sg:
			cmp #'-'
			bne ntc_lv_dig
			inc z_t1
			iny
ntc_lv_dig:
			lda (z_p0),y
			iny
			sec
			sbc #'0'
			bcc ntc_lv_done
			cmp #10
			bcs ntc_lv_done
			sta z_t0
			ldx #3						; z_l1 = z_l0
ntc_lv_c:
			lda z_l0,x
			sta z_l1,x
			dex
			bpl ntc_lv_c
			asl z_l0					; * 4
			rol z_l0+1
			rol z_l0+2
			rol z_l0+3
			asl z_l0
			rol z_l0+1
			rol z_l0+2
			rol z_l0+3
			clc							; + itself: * 5
			lda z_l0
			adc z_l1
			sta z_l0
			lda z_l0+1
			adc z_l1+1
			sta z_l0+1
			lda z_l0+2
			adc z_l1+2
			sta z_l0+2
			lda z_l0+3
			adc z_l1+3
			sta z_l0+3
			asl z_l0					; * 2: * 10
			rol z_l0+1
			rol z_l0+2
			rol z_l0+3
			clc
			lda z_l0
			adc z_t0
			sta z_l0
			bcc ntc_lv_dig
			inc z_l0+1
			bne ntc_lv_dig
			inc z_l0+2
			bne ntc_lv_dig
			inc z_l0+3
			jmp ntc_lv_dig
ntc_lv_done:
			lda z_t1
			beq ntc_lv_st
			ldx #z_l0
			sec
			lda #0
			sbc 0,x
			sta 0,x
			lda #0
			sbc 1,x
			sta 1,x
			lda #0
			sbc 2,x
			sta 2,x
			lda #0
			sbc 3,x
			sta 3,x
ntc_lv_st:
			ldy #3
ntc_lv_o:
			lda z_l0,y
			sta (z_p3),y
			dey
			bpl ntc_lv_o
			rts

;## kw_l_input ntc_gets kw_l_val ntc_d_inbuf
;kw_l_input, <destlong>  - Input to a Long
kw_l_input:
			NTC_POP z_p3
			lda #<ntc_inbuf
			sta z_p2
			lda #>ntc_inbuf
			sta z_p2+1
			NTC_RS
			jsr ntc_gets
			lda #<ntc_inbuf
			sta z_p0
			lda #>ntc_inbuf
			sta z_p0+1
			jsr ntc_lval
			NTC_TS
			rts

;## kw_l_aget
;kw_l_aget, <arraybase>, <indexvar>, <dest>  - Long array element
kw_l_aget:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta z_t0
			iny
			lda (z_p1),y
			asl z_t0
			rol
			asl z_t0
			rol
			sta z_t1
			clc
			lda z_p0
			adc z_t0
			sta z_p0
			lda z_p0+1
			adc z_t1
			sta z_p0+1
			NTC_POP z_p1
			ldy #3
kw_lag_lp:
			lda (z_p0),y
			sta (z_p1),y
			dey
			bpl kw_lag_lp
			rts

;## kw_l_aset
;kw_l_aset, <arraybase>, <indexvar>, <src>  - set a Long array element
kw_l_aset:
			NTC_POP z_p0
			NTC_POP z_p1
			ldy #0
			lda (z_p1),y
			sta z_t0
			iny
			lda (z_p1),y
			asl z_t0
			rol
			asl z_t0
			rol
			sta z_t1
			clc
			lda z_p0
			adc z_t0
			sta z_p0
			lda z_p0+1
			adc z_t1
			sta z_p0+1
			NTC_POP z_p1
			ldy #3
kw_las_lp:
			lda (z_p1),y
			sta (z_p0),y
			dey
			bpl kw_las_lp
			rts

;## kw_bssinit ntc_data ntc_plat_screen ntc_plat_exit
;kw_bssinit, <start>, <size>  - the start of the main thread: the program's arrays live after
;  the program (not in its file). Check they end below the I/O area ($D000), then clear them.
;  Too big: a message, the program stops.
kw_bssinit:
			NTC_POP z_p0
			NTC_POP z_a
			clc
			lda z_p0
			adc z_a
			sta z_t0
			lda z_p0+1
			adc z_a+1
			bcs kw_bs_big
			cmp #$D0
			bcc kw_bs_ok
			bne kw_bs_big
			lda z_t0
			bne kw_bs_big
kw_bs_ok:
			jmp ntc_zerofill_b
kw_bs_big:
			NTC_RS
			lda #<kw_bs_txt
			sta z_p0
			lda #>kw_bs_txt
			sta z_p0+1
kw_bs_pl:
			ldy #0
			lda (z_p0),y
			beq kw_bs_stop
			jsr ntc_plat_putc
			inw z_p0
			jmp kw_bs_pl
kw_bs_stop:
			jsr ntc_plat_newline
			jmp ntc_plat_exit_stop
kw_bs_txt:	db "Not enough memory for the arrays", 0
; z_p0 = start, z_a = bytes: zero them, then rts (the thread)
ntc_zerofill_b:
			lda #0
			ldx z_a+1
			beq ntc_zfb_part
			ldy #0
ntc_zfb_page:
			sta (z_p0),y
			iny
			bne ntc_zfb_page
			inc z_p0+1
			dex
			bne ntc_zfb_page
ntc_zfb_part:
			ldy z_a
			beq ntc_zfb_end
			ldy #0
ntc_zfb_lp:
			sta (z_p0),y
			iny
			cpy z_a
			bne ntc_zfb_lp
ntc_zfb_end:
			rts

;## ntc_capfind ntc_data
; ntc_capfind - the body of a class's Capability(name) keyword (on the thread).
;   z_p0 = the name asked for (0 ended), z_p1 = the result's address, z_p2 = the
;   class's table: name (capitals, 0 ended), dw value, ..., db 0. Matched without
;   regard to case. Found: the value, Z set (true). Not found: 0, NZ. Ends the keyword (rts).
ntc_capfind:
ntc_cf_entry:
			ldy #0
			lda (z_p2),y
			beq ntc_cf_none
ntc_cf_cmp:
			lda (z_p0),y
			cmp #'a'
			bcc ntc_cf_up
			cmp #'z'+1
			bcs ntc_cf_up
			sbc #31						; (carry clear: - 32)
ntc_cf_up:
			cmp (z_p2),y
			bne ntc_cf_skip
			cmp #0
			beq ntc_cf_found
			iny
			bne ntc_cf_cmp
ntc_cf_skip:
			lda (z_p2),y				; to the end of this name
			beq ntc_cf_past
			iny
			bne ntc_cf_skip
ntc_cf_past:
			iny							; past the 0 and the value
			iny
			iny
			tya
			clc
			adc z_p2
			sta z_p2
			bcc ntc_cf_entry
			inc z_p2+1
			jmp ntc_cf_entry
ntc_cf_found:
			iny
			lda (z_p2),y
			tax
			iny
			lda (z_p2),y
			ldy #1
			sta (z_p1),y
			dey
			txa
			sta (z_p1),y
			lda #0						; Z: found
			rts
ntc_cf_none:
			ldy #0
			tya
			sta (z_p1),y
			iny
			sta (z_p1),y
			lda #1						; NZ: not found
			rts

; ============================================================
; NTC Keyword Library - 80386 (nasm), 32 bit protected mode
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; THREAD
;   ESP is the thread pointer, as SP is on the Z80 and A7 on the 68000: a
;   keyword ends with ret (the next keyword's address is the next thread
;   word) and takes its operands with pop. Thread words are 32 bits (dd).
;   The program runs in RING 3: an interrupt or exception switches the CPU
;   to ring 0 and pushes its frame on the ring 0 stack (the TSS's), never on
;   the thread, so interrupts are on the whole time and there is one mode
;   (Turbo On / Off do nothing). The compiler's 68000 path is used for this
;   CPU too (js/ntc_compiler.js: blnX86, x86Text).
;
;   A keyword that needs call / push goes to the real stack first: NTC_RS
;   (the thread position kept in ntc_ip, ESP = ntc_csp), then NTC_TS back.
;
; DATA
;   Integer = 16 bits, Long = 32 bits, little endian. Variables are in the
;   RAM block (the platform's ;@ramorg, below 64K), so their addresses fit
;   16 bits, zero extended (VarPtr, Peek, array descriptors).
;   Lines between ;@ram and ;@rom in a section are its RAM variables: the
;   compiler moves them into the RAM block.
;
; COMPARES
;   Result is the Z flag. Z = true, NZ = false. pop, mov, lea and ret keep
;   the flags, so a compare keyword's result reaches the next keyword.
;
; REGISTERS
;   All of eax ebx ecx edx esi edi ebp are free in a keyword (nothing is kept
;   from one keyword to the next). The compiler's stubs use esi, edi, eax,
;   ecx and ebp.
;
; SECTIONS
;   ";## name dep dep ..." starts a section, as in the other libraries. The
;   platform file supplies the ntc_plat_* routines, called on the real stack
;   (call, end with ret), keeping every register but eax:
;     ntc_plat_putc (al = char 32-126), ntc_plat_newline, ntc_plat_backspace,
;     ntc_plat_cls, ntc_plat_mode (eax), ntc_plat_locate (eax = column, ecx =
;     row, 1 based), ntc_plat_scankey (eax = key or 0), ntc_plat_getkey (eax,
;     waits), ntc_plat_frame, ntc_plat_ticks (ax), ntc_plat_exit
; ============================================================

;## ntc_data @shared
; ------------------------------------------------------------
; The core every program has
; ------------------------------------------------------------
; (NTC_RS / NTC_TS, the macros that switch to the real stack and back, are written
; by the compiler at the top of the program, before anything uses them)
ntc_next:	ret
;@ram
ntc_csp:	dd 0					; the real stack (set at start)
ntc_ip:		dd 0					; the thread position while on the real stack
ntc_ivar:	dd 0					; input / inkey / ticks: dest var
ntc_sptr:	dd 0					; printbuf: text pointer
ntc_numbuf:	times 16 db 0			; printint / long print: digits
;@rom

;## ntc_d_inbuf @data
;@ram
			db 40					; ntc_inbuf's capacity (as every string variable has)
ntc_inbuf:	times 41 db 0			; inputint: typed text
			align 2, db 0
;@rom

;## ntc_gstack
; ------------------------------------------------------------
; GOSUB return stack (grows down, 64 levels of thread positions)
; ------------------------------------------------------------
;@ram
ntc_gsp:	dd ntc_gstack_top
ntc_gstack:	times 64 dd 0
ntc_gstack_top:
;@rom

; ============================================================
; Flow
; ============================================================

;## kw_stop ntc_data ntc_plat_exit @shared
kw_stop:
			NTC_RS
			call ntc_plat_exit
ntc_stop_loop:
			jmp ntc_stop_loop

;## kw_waitkey ntc_data ntc_plat_key
; kw_waitkey - wait for a key (Option PressAnyKeyOnEnd, before kw_stop)
kw_waitkey:
			NTC_RS
			call ntc_plat_getkey
			NTC_TS
			ret

;## kw_turbo_on ntc_data @shared
kw_turbo_on:
			ret

;## kw_turbo_off ntc_data @shared
kw_turbo_off:
			ret

;## kw_irq @shared
kw_irq:
			ret

;## kw_goto
;kw_goto, <label>
kw_goto:
			mov esp, [esp]
			ret

;## kw_goto_iffalse
;kw_goto_iffalse, <label>  - branch if NZ (false)
kw_goto_iffalse:
			jnz kw_gif_go
			lea esp, [esp+4]
			ret
kw_gif_go:
			mov esp, [esp]
			ret

;## kw_goto_iftrue
;kw_goto_iftrue, <label>  - branch if Z (true)
kw_goto_iftrue:
			jz kw_git_go
			lea esp, [esp+4]
			ret
kw_git_go:
			mov esp, [esp]
			ret

;## kw_goto_ifzero
;kw_goto_ifzero, <var>, <label>  - branch if var = 0
kw_goto_ifzero:
			pop esi
			cmp word [esi], 0
			jz kw_giz_go
			lea esp, [esp+4]
			ret
kw_giz_go:
			mov esp, [esp]
			ret

;## kw_goto_ifnzero
;kw_goto_ifnzero, <var>, <label>  - branch if var <> 0
kw_goto_ifnzero:
			pop esi
			cmp word [esi], 0
			jnz kw_ginz_go
			lea esp, [esp+4]
			ret
kw_ginz_go:
			mov esp, [esp]
			ret

;## kw_gosub ntc_gstack
;kw_gosub, <label>  - return lands on the word after the label
kw_gosub:
			pop esi
			mov edi, [ntc_gsp]
			lea edi, [edi-4]
			mov [edi], esp
			mov [ntc_gsp], edi
			mov esp, esi
			ret

;## kw_return ntc_gstack
;kw_return
kw_return:
			mov edi, [ntc_gsp]
			mov eax, [edi]
			lea edi, [edi+4]
			mov [ntc_gsp], edi
			mov esp, eax
			ret

;## ntc_for_jump
; tails for the FOR / NEXT keywords: ESP = thread at the label word
ntc_for_take:
			mov esp, [esp]
			ret
ntc_for_skip:
			lea esp, [esp+4]
			ret

;## kw_forupl ntc_for_jump
;kw_forupl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting up: skip the loop if var > limit
kw_forupl:
			pop esi
			pop ecx
			cmp cx, [esi]
			jl ntc_for_take			; limit < var
			lea esp, [esp+4]
			ret

;## kw_forupv ntc_for_jump
;kw_forupv, <var>, <limit var>, <endlabel>
kw_forupv:
			pop esi
			pop edi
			mov cx, [edi]
			cmp cx, [esi]
			jl ntc_for_take
			lea esp, [esp+4]
			ret

;## kw_fordnl ntc_for_jump
;kw_fordnl, <var>, <literal limit>, <endlabel>
;  FOR entry, counting down: skip the loop if var < limit
kw_fordnl:
			pop esi
			pop ecx
			cmp cx, [esi]
			jg ntc_for_take			; limit > var
			lea esp, [esp+4]
			ret

;## kw_fordnv ntc_for_jump
;kw_fordnv, <var>, <limit var>, <endlabel>
kw_fordnv:
			pop esi
			pop edi
			mov cx, [edi]
			cmp cx, [esi]
			jg ntc_for_take
			lea esp, [esp+4]
			ret

;## kw_next1l ntc_for_jump
;kw_next1l, <var>, <literal limit>, <toplabel>
;  NEXT for STEP 1: inc var, back to the top while var <= limit (past 32767: ends)
kw_next1l:
			pop esi
			pop ecx
			add word [esi], 1
			jo ntc_for_skip
			cmp cx, [esi]
			jge ntc_for_take		; limit >= var
			lea esp, [esp+4]
			ret

;## kw_next1v ntc_for_jump
;kw_next1v, <var>, <limit var>, <toplabel>
kw_next1v:
			pop esi
			pop edi
			add word [esi], 1
			jo ntc_for_skip
			mov cx, [edi]
			cmp cx, [esi]
			jge ntc_for_take
			lea esp, [esp+4]
			ret

; ============================================================
; Assignment and arithmetic (Integer)
; ============================================================

;## kw_ltov
;kw_ltov, <literal>, <destvar>
kw_ltov:
			pop eax
			pop esi
			mov [esi], ax
			ret

;## kw_mulvv
;kw_mulvv, <var1>, <var2>, <destvar>  - low 16 bits
kw_mulvv:
			pop esi
			pop edi
			mov ax, [esi]
			imul ax, [edi]
			pop esi
			mov [esi], ax
			ret

; ============================================================
; Console output
; ============================================================

;## ntc_printbuf ntc_data ntc_plat_screen
; print the 0 terminated text at esi, then ret (thread). On the thread.
ntc_printbuf:
			NTC_RS
ntc_pb_lp:
			xor eax, eax
			lodsb
			test al, al
			jz ntc_pb_end
			call ntc_plat_putc
			jmp ntc_pb_lp
ntc_pb_end:
			NTC_TS
			ret

;## kw_printstrvar ntc_printbuf
;kw_printstrvar, <straddr>
kw_printstrvar:
			pop esi
			jmp ntc_printbuf

;## ntc_itoa ntc_data
; ntc_itoa - eax (signed, 32 bits) as decimal text at edi, 0 ended. Real stack or thread:
; no call inside. Keeps nothing; edi = the 0 at the end
ntc_itoa:
			test eax, eax
			jns ntc_ia_pos
			mov byte [edi], '-'
			inc edi
			neg eax
ntc_ia_pos:
			mov ebx, 10
			xor ecx, ecx			; digits counted, kept in ntc_ia_tmp backwards
			lea esi, [ntc_ia_tmp+11]
ntc_ia_div:
			xor edx, edx
			div ebx
			add dl, '0'
			dec esi
			mov [esi], dl
			inc ecx
			test eax, eax
			jnz ntc_ia_div
			rep movsb
			mov byte [edi], 0
			jmp ebp					; back to the keyword (its address in ebp: the thread has no call)
;@ram
ntc_ia_tmp:	times 12 db 0
;@rom

;## kw_printint ntc_printbuf ntc_itoa
;kw_printint, <var>  - signed decimal
kw_printint:
			pop esi
			movsx eax, word [esi]
			mov edi, ntc_numbuf
			mov ebp, kw_pi_done
			jmp ntc_itoa
kw_pi_done:
			mov esi, ntc_numbuf
			jmp ntc_printbuf

;## kw_printnl ntc_data ntc_plat_screen
kw_printnl:
			NTC_RS
			call ntc_plat_newline
			NTC_TS
			ret

;## kw_bssinit ntc_data ntc_plat_screen
;kw_bssinit, <start>, <size>  - the start of the main thread: the program's arrays live after
;  the RAM variables. Check they fit under the end of RAM, then clear them.
;  Too big: a message, the program stops.
kw_bssinit:
			pop edi
			pop ecx
			and ecx, 0xFFFF
			mov eax, edi
			add eax, ecx
			cmp eax, NTC_RAMEND
			ja kw_bs_big
			xor eax, eax
			rep stosb
			ret
kw_bs_big:
			NTC_RS
			mov esi, kw_bs_txt
kw_bs_pl:
			xor eax, eax
			lodsb
			test al, al
			jz kw_bs_stop
			call ntc_plat_putc
			jmp kw_bs_pl
kw_bs_stop:
			jmp kw_bs_stop
kw_bs_txt:	db "Out of memory: arrays", 0

;## ntc_capfind ntc_data
; ntc_capfind - the body of a class's Capability(name) keyword. esi = the name asked for
;   (0 ended), edi = the result's address, ebx = the class's table: name (capitals, 0
;   ended, then align 2), dw value, ..., db 0. Matched without regard to case. Found:
;   the value, Z set (true). Not found: 0, NZ. Ends the keyword (ret).
ntc_capfind:
ntc_cf_entry:
			cmp byte [ebx], 0
			jz ntc_cf_none
			mov ecx, esi
			mov edx, ebx
ntc_cf_cmp:
			mov al, [ecx]
			inc ecx
			cmp al, 'a'
			jb ntc_cf_up
			cmp al, 'z'
			ja ntc_cf_up
			sub al, 32
ntc_cf_up:
			mov ah, [edx]
			inc edx
			cmp al, ah
			jne ntc_cf_next
			test al, al
			jnz ntc_cf_cmp
			inc edx					; matched: the value after the name (on an even address)
			and edx, -2
			mov ax, [edx]
			mov [edi], ax
			cmp eax, eax			; Z
			ret
ntc_cf_next:
			cmp byte [edx-1], 0		; to the end of this name
			jz ntc_cf_skip
ntc_cf_to0:
			mov al, [edx]
			inc edx
			test al, al
			jnz ntc_cf_to0
ntc_cf_skip:
			inc edx
			and edx, -2
			lea ebx, [edx+2]		; past the value
			jmp ntc_cf_entry
ntc_cf_none:
			mov word [edi], 0
			or eax, 1				; NZ
			ret

;## kw_printnl0 ntc_data ntc_plat_screen
;kw_printnl0  - new line unless the cursor is at the start of a line
kw_printnl0:
			cmp byte [ntc_curx], 0
			jz kw_pn0_end
			NTC_RS
			call ntc_plat_newline
			NTC_TS
kw_pn0_end:
			ret

;## kw_ztov
;kw_ztov, <destvar>
kw_ztov:
			pop esi
			mov word [esi], 0
			ret

;## kw_inc
kw_inc:
			pop esi
			inc word [esi]
			ret

;## kw_dec
kw_dec:
			pop esi
			dec word [esi]
			ret

;## kw_vtov
;kw_vtov, <sourcevar>, <destvar>
kw_vtov:
			pop esi
			pop edi
			mov ax, [esi]
			mov [edi], ax
			ret

;## kw_cpeqvv
kw_cpeqvv:
			pop esi
			pop edi
			mov ax, [esi]
			cmp ax, [edi]
			ret

;## kw_cpeqvl
kw_cpeqvl:
			pop esi
			pop ecx
			cmp cx, [esi]
			ret

;## ntc_cmp
; tails: ax = a, cx = b, test a <rel> b. Z = true
ntc_cmp_slt:
			cmp ax, cx
			setl al
			cmp al, 1
			ret
ntc_cmp_sle:
			cmp ax, cx
			setle al
			cmp al, 1
			ret
ntc_cmp_sgt:
			cmp ax, cx
			setg al
			cmp al, 1
			ret
ntc_cmp_sge:
			cmp ax, cx
			setge al
			cmp al, 1
			ret
ntc_cmp_ult:
			cmp ax, cx
			setb al
			cmp al, 1
			ret
ntc_cmp_ule:
			cmp ax, cx
			setbe al
			cmp al, 1
			ret
ntc_cmp_ugt:
			cmp ax, cx
			seta al
			cmp al, 1
			ret
ntc_cmp_uge:
			cmp ax, cx
			setae al
			cmp al, 1
			ret
ntc_cmp_eq:
			cmp ax, cx
			ret
ntc_cmp_ne:
			cmp ax, cx
			setne al
			cmp al, 1
			ret

;## kw_cpnevl ntc_cmp
kw_cpnevl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_ne

;## kw_cpnevv ntc_cmp
kw_cpnevv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_ne

;## kw_add
;kw_add, <var1>, <var2>, <destvar>
kw_add:
			pop esi
			pop edi
			mov ax, [esi]
			add ax, [edi]
			pop esi
			mov [esi], ax
			ret

;## kw_addl
;kw_addl, <var>, <literal>, <destvar>
kw_addl:
			pop esi
			pop eax
			add ax, [esi]
			pop esi
			mov [esi], ax
			ret

;## kw_mulvl
;kw_mulvl, <var>, <literal>, <destvar>
kw_mulvl:
			pop esi
			pop eax
			imul ax, [esi]
			pop esi
			mov [esi], ax
			ret

;## kw_subvv
;kw_subvv, <var1>, <var2>, <destvar>  - var1 - var2
kw_subvv:
			pop esi
			pop edi
			mov ax, [esi]
			sub ax, [edi]
			pop esi
			mov [esi], ax
			ret

;## kw_sublv
;kw_sublv, <literal>, <var>, <destvar>  - literal - var
kw_sublv:
			pop eax
			pop edi
			sub ax, [edi]
			pop esi
			mov [esi], ax
			ret

;## kw_negv
kw_negv:
			pop esi
			mov ax, [esi]
			neg ax
			pop esi
			mov [esi], ax
			ret

;## kw_2x
kw_2x:
			pop esi
			mov ax, [esi]
			add ax, ax
			pop esi
			mov [esi], ax
			ret

;## kw_4x
kw_4x:
			pop esi
			mov ax, [esi]
			shl ax, 2
			pop esi
			mov [esi], ax
			ret

;## kw_scpgtvl ntc_cmp
kw_scpgtvl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_sgt

;## kw_scpltvl ntc_cmp
kw_scpltvl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_slt

;## kw_scpltvv ntc_cmp
kw_scpltvv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_slt

;## kw_scplevv ntc_cmp
kw_scplevv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_sle

;## kw_scplevl ntc_cmp
kw_scplevl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_sle

;## kw_scpgtvv ntc_cmp
kw_scpgtvv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_sgt

;## kw_scpgevl ntc_cmp
kw_scpgevl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_sge

;## kw_scpgevv ntc_cmp
kw_scpgevv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_sge

;## kw_andvv
kw_andvv:
			pop esi
			pop edi
			mov ax, [esi]
			and ax, [edi]
			pop esi
			mov [esi], ax
			ret

;## kw_orvv
kw_orvv:
			pop esi
			pop edi
			mov ax, [esi]
			or ax, [edi]
			pop esi
			mov [esi], ax
			ret

;## kw_xorvv
kw_xorvv:
			pop esi
			pop edi
			mov ax, [esi]
			xor ax, [edi]
			pop esi
			mov [esi], ax
			ret

;## kw_notv
kw_notv:
			pop esi
			mov ax, [esi]
			not ax
			pop esi
			mov [esi], ax
			ret

;## ntc_div
; ax / cx signed, truncating: ax = quotient, dx = remainder (the dividend's
; sign). Divide by zero: quotient 0, remainder = dividend. -32768 / -1:
; quotient -32768, remainder 0 (as the Z80 library). jmp ebp
ntc_div:
			test cx, cx
			jz ntc_div_z
			cmp cx, -1
			jne ntc_div_go
			cmp ax, 0x8000
			je ntc_div_ov
ntc_div_go:
			cwd
			idiv cx
			jmp ebp
ntc_div_z:
			mov dx, ax
			xor eax, eax
			jmp ebp
ntc_div_ov:
			xor edx, edx
			jmp ebp

;## kw_modvv ntc_div
;kw_modvv, <var1>, <var2>, <destvar>  - var1 MOD var2
kw_modvv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			mov ebp, kw_mod_r
			jmp ntc_div
kw_mod_r:
			pop esi
			mov [esi], dx
			ret

;## kw_modvl ntc_div kw_modvv
kw_modvl:
			pop esi
			mov ax, [esi]
			pop ecx
			mov ebp, kw_mod_r
			jmp ntc_div

;## kw_divvv ntc_div
;kw_divvv, <var1>, <var2>, <destvar>  - var1 \ var2
kw_divvv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			mov ebp, kw_div_q
			jmp ntc_div
kw_div_q:
			pop esi
			mov [esi], ax
			ret

;## kw_divvl ntc_div kw_divvv
;kw_divvl, <var>, <literal>, <destvar>
kw_divvl:
			pop esi
			mov ax, [esi]
			pop ecx
			mov ebp, kw_div_q
			jmp ntc_div

;## kw_ftov
;kw_ftov, <destvar>  - Z flag to var: true = -1, false = 0
kw_ftov:
			setz al
			neg al
			movsx ax, al
			pop esi
			mov [esi], ax
			ret

;## kw_cls ntc_data ntc_plat_screen
kw_cls:
			NTC_RS
			call ntc_plat_cls
			NTC_TS
			ret

;## kw_ticks ntc_data ntc_plat_ticks
;kw_ticks, <destvar>  - the tick count (frames)
kw_ticks:
			pop ebx
			NTC_RS
			call ntc_plat_ticks
			NTC_TS
			mov [ebx], ax
			ret

;## kw_nextupl ntc_for_jump
;kw_nextupl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a positive STEP: add, back to the top while var <= limit
kw_nextupl:
			pop esi
			pop eax
			pop ecx
			add [esi], ax
			jo ntc_for_skip
			cmp cx, [esi]
			jge ntc_for_take
			lea esp, [esp+4]
			ret

;## kw_nextdnl ntc_for_jump
;kw_nextdnl, <var>, <literal step>, <literal limit>, <toplabel>
;  NEXT for a negative STEP: add, back to the top while var >= limit
kw_nextdnl:
			pop esi
			pop eax
			pop ecx
			add [esi], ax
			jo ntc_for_skip
			cmp cx, [esi]
			jle ntc_for_take
			lea esp, [esp+4]
			ret

;## kw_fornext ntc_for_jump
;kw_fornext, <var>, <stepvar>, <limvar>, <toplabel>
;  var += step, loop back while var has not passed lim
kw_fornext:
			pop esi
			pop edi
			pop ebx
			mov ax, [edi]
			add [esi], ax
			jo ntc_for_skip
			mov cx, [ebx]
			test ax, ax
			js kw_fn_neg
			cmp cx, [esi]
			jge ntc_for_take		; lim >= var
			lea esp, [esp+4]
			ret
kw_fn_neg:
			cmp cx, [esi]
			jle ntc_for_take		; lim <= var
			lea esp, [esp+4]
			ret

;## kw_forentry ntc_for_jump
;kw_forentry, <var>, <stepvar>, <limvar>, <endlabel>
;  skip the loop if var is already past lim for the step sign
kw_forentry:
			pop esi
			pop edi
			pop ebx
			mov cx, [ebx]			; lim
			cmp word [edi], 0
			jl kw_fe_neg
			cmp cx, [esi]
			jl ntc_for_take			; lim < var
			lea esp, [esp+4]
			ret
kw_fe_neg:
			cmp cx, [esi]
			jg ntc_for_take			; lim > var
			lea esp, [esp+4]
			ret

;## kw_printtab ntc_data ntc_plat_screen
;kw_printtab, <nvar>  - Tab(n) in Print: spaces up to column n (1 based),
;  a new line first when the cursor is already past it. n off the line: nothing
kw_printtab:
			pop esi
			movzx ebx, word [esi]
			dec bx
ntc_pt_go:						; bx = the column (0 based)
			movzx eax, byte [ntc_scols]
			cmp bx, ax
			jae ntc_pt_end			; (also below 0: unsigned)
			NTC_RS
			movzx eax, byte [ntc_curx]
			cmp bx, ax
			jae ntc_pt_lp
			call ntc_plat_newline
ntc_pt_lp:
			movzx eax, byte [ntc_curx]
			cmp bx, ax
			jbe ntc_pt_done
			mov al, ' '
			call ntc_plat_putc
			jmp ntc_pt_lp
ntc_pt_done:
			NTC_TS
ntc_pt_end:
			ret

; ------------------------------------------------------------
; Strings (0 ended; a string variable has its capacity in the byte before it)
; ------------------------------------------------------------

;## kw_strcpy
;kw_strcpy, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcpy:
			pop edi
			pop esi
			movzx ecx, byte [edi-1]
ntc_strcpy_lp:						; esi -> edi, at most ecx chars, then the 0
			test ecx, ecx
			jz ntc_strcpy_cut
ntc_strcpy_l2:
			lodsb
			stosb
			test al, al
			jz ntc_strcpy_e
			dec ecx
			jnz ntc_strcpy_l2
ntc_strcpy_cut:
			mov byte [edi], 0
ntc_strcpy_e:
			ret

;## kw_strcpyn kw_strcpy
;kw_strcpyn, <destaddr>, <srcaddr>, <capacity>  - into an array element (no capacity byte)
kw_strcpyn:
			pop edi
			pop esi
			pop ecx
			and ecx, 0xFF
			jmp ntc_strcpy_lp

;## kw_strcat kw_strcpy
;kw_strcat, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcat:
			pop edi
			pop esi
			movzx ecx, byte [edi-1]
kw_sc_end:
			cmp byte [edi], 0
			je ntc_strcpy_lp
			inc edi
			dec ecx
			jg kw_sc_end
			ret

;## kw_strcmpeq
;kw_strcmpeq, <addr1>, <addr2>  - Z if equal
kw_strcmpeq:
			pop esi
			pop edi
kw_seq_lp:
			mov al, [esi]
			cmp al, [edi]
			jne kw_seq_no
			inc esi
			inc edi
			test al, al
			jnz kw_seq_lp
kw_seq_no:
			ret

;## ntc_strcmp
; esi = a, edi = b: compare, jmp ebp with Z = equal, C = a < b (unsigned bytes)
ntc_strcmp:
			mov al, [esi]
			cmp al, [edi]
			jne ntc_scm_e
			inc esi
			inc edi
			test al, al
			jnz ntc_strcmp
ntc_scm_e:
			jmp ebp

;## kw_strcmplt ntc_strcmp
;kw_strcmplt, <a>, <b>  - Z if a < b
kw_strcmplt:
			pop esi
			pop edi
			mov ebp, kw_sclt
			jmp ntc_strcmp
kw_sclt:
			setb al
			cmp al, 1
			ret

;## kw_strcmpgt ntc_strcmp
kw_strcmpgt:
			pop esi
			pop edi
			mov ebp, kw_scgt
			jmp ntc_strcmp
kw_scgt:
			seta al
			cmp al, 1
			ret

;## kw_strcmple ntc_strcmp
kw_strcmple:
			pop esi
			pop edi
			mov ebp, kw_scle
			jmp ntc_strcmp
kw_scle:
			setbe al
			cmp al, 1
			ret

;## kw_strcmpge ntc_strcmp
kw_strcmpge:
			pop esi
			pop edi
			mov ebp, kw_scge
			jmp ntc_strcmp
kw_scge:
			setae al
			cmp al, 1
			ret

;## kw_strcmpne ntc_strcmp
kw_strcmpne:
			pop esi
			pop edi
			mov ebp, kw_scne
			jmp ntc_strcmp
kw_scne:
			setne al
			cmp al, 1
			ret

;## kw_strucase
;kw_strucase, <dest>, <src>  - UCase$
kw_strucase:
			pop edi
			pop esi
kw_uc_lp:
			lodsb
			cmp al, 'a'
			jb kw_uc_put
			cmp al, 'z'
			ja kw_uc_put
			sub al, 32
kw_uc_put:
			stosb
			test al, al
			jnz kw_uc_lp
			ret

;## kw_strlcase
;kw_strlcase, <dest>, <src>  - LCase$
kw_strlcase:
			pop edi
			pop esi
kw_lc_lp:
			lodsb
			cmp al, 'A'
			jb kw_lc_put
			cmp al, 'Z'
			ja kw_lc_put
			add al, 32
kw_lc_put:
			stosb
			test al, al
			jnz kw_lc_lp
			ret

;## kw_strlen
;kw_strlen, <straddr>, <destvar>
kw_strlen:
			pop esi
			xor eax, eax
kw_sl_lp:
			cmp byte [esi+eax], 0
			je kw_sl_e
			inc eax
			jmp kw_sl_lp
kw_sl_e:
			pop edi
			mov [edi], ax
			ret

;## kw_strcstr ntc_itoa
;kw_strcstr, <dest>, <nvar>  - number to text (CStr, "x" & n)
kw_strcstr:
			pop edi
			pop esi
			movsx eax, word [esi]
			mov ebp, ntc_next
			jmp ntc_itoa

;## ntc_getn
; esi = address of a word: eax = its value limited to 0..255. jmp ebp. Keeps others.
ntc_getn:
			movsx eax, word [esi]
			test eax, eax
			js ntc_gn_zero
			cmp eax, 255
			jbe ntc_gn_ok
			mov eax, 255
ntc_gn_ok:
			jmp ebp
ntc_gn_zero:
			xor eax, eax
			jmp ebp

;## kw_strleft ntc_getn
;kw_strleft, <dest>, <src>, <nvar>  - Left$(src, n)
kw_strleft:
			pop edi
			pop edx
			pop esi
			mov ebp, kw_sl_n
			jmp ntc_getn
kw_sl_n:
			mov esi, edx
; copy up to eax chars from esi to edi, then the 0. ret (the thread)
ntc_strncpy:
			mov ecx, eax
			test ecx, ecx
			jz ntc_sn_end
ntc_sn_lp:
			lodsb
			stosb
			test al, al
			jz ntc_sn_z
			dec ecx
			jnz ntc_sn_lp
ntc_sn_end:
			mov byte [edi], 0
ntc_sn_z:
			ret

;## kw_strmid ntc_getn kw_strleft
;kw_strmid, <dest>, <src>, <startvar>, <lenvar>  - Mid$(src, start, len)
kw_strmid:
			pop edi
			pop edx
			pop esi
			mov ebp, kw_sm_s
			jmp ntc_getn
kw_sm_s:
			test eax, eax
			jz kw_sm_s1
			dec eax
kw_sm_s1:
			test eax, eax
			jz kw_sm_len
			cmp byte [edx], 0
			je kw_sm_len
			inc edx
			dec eax
			jmp kw_sm_s1
kw_sm_len:
			pop esi
			mov ebp, kw_sm_n
			jmp ntc_getn
kw_sm_n:
			mov esi, edx
			jmp ntc_strncpy

;## kw_strright ntc_getn kw_strleft
;kw_strright, <dest>, <src>, <nvar>  - Right$(src, n)
kw_strright:
			pop edi
			pop edx
			pop esi
			mov ebp, kw_sr_n
			jmp ntc_getn
kw_sr_n:
			xor ecx, ecx
kw_sr_len:
			cmp byte [edx+ecx], 0
			je kw_sr_got
			inc ecx
			jmp kw_sr_len
kw_sr_got:
			sub ecx, eax				; len - n
			jns kw_sr_skip
			xor ecx, ecx
kw_sr_skip:
			lea esi, [edx+ecx]
			mov eax, 255
			jmp ntc_strncpy

;## kw_strltrim kw_strleft
;kw_strltrim, <dest>, <src>  - LTrim$
kw_strltrim:
			pop edi
			pop esi
kw_lt_skip:
			cmp byte [esi], ' '
			jne kw_lt_copy
			inc esi
			jmp kw_lt_skip
kw_lt_copy:
			mov eax, 255
			jmp ntc_strncpy

;## kw_strrtrim
;kw_strrtrim, <dest>, <src>  - RTrim$
kw_strrtrim:
			pop edi
			pop esi
ntc_rt_go:
			mov edx, edi				; the start
ntc_rt_copy:
			lodsb
			stosb
			test al, al
			jnz ntc_rt_copy
			dec edi						; on the 0
ntc_rt_lp:
			cmp edi, edx
			je ntc_rt_e
			cmp byte [edi-1], ' '
			jne ntc_rt_e
			dec edi
			mov byte [edi], 0
			jmp ntc_rt_lp
ntc_rt_e:
			ret

;## kw_strtrim kw_strrtrim
;kw_strtrim, <dest>, <src>  - Trim$
kw_strtrim:
			pop edi
			pop esi
kw_tr_skip:
			cmp byte [esi], ' '
			jne ntc_rt_go
			inc esi
			jmp kw_tr_skip

;## kw_strspace ntc_getn
;kw_strspace, <dest>, <nvar>  - Space$(n)
kw_strspace:
			pop edi
			pop esi
			mov ebp, kw_sps_n
			jmp ntc_getn
kw_sps_n:
			mov cl, ' '
; eax = count (NTC_STRMAX at most), cl = char, edi = dest. ret
ntc_strfill:
			cmp eax, NTC_STRMAX
			jbe ntc_sf_ok
			mov eax, NTC_STRMAX
ntc_sf_ok:
			xchg eax, ecx
			rep stosb
			mov byte [edi], 0
			ret

;## kw_strstring kw_strspace ntc_getn
;kw_strstring, <dest>, <nvar>, <charvar>  - String$(n, char code)
kw_strstring:
			pop edi
			pop esi
			mov ebp, kw_ss_n
			jmp ntc_getn
kw_ss_n:
			pop esi
			mov cl, [esi]
			jmp ntc_strfill

;## kw_strrev
;kw_strrev, <dest>, <src>  - StrReverse
kw_strrev:
			pop edi
			pop esi
			cmp edi, esi
			je kw_rv_go
			mov edx, edi
kw_rv_cl:
			lodsb
			mov [edx], al
			inc edx
			test al, al
			jnz kw_rv_cl
kw_rv_go:
			mov esi, edi
kw_rv_end:
			lodsb
			test al, al
			jnz kw_rv_end
			sub esi, 2
kw_rv_sw:
			cmp edi, esi
			jae kw_rv_done
			mov al, [edi]
			mov ah, [esi]
			mov [edi], ah
			mov [esi], al
			inc edi
			dec esi
			jmp kw_rv_sw
kw_rv_done:
			ret

;## kw_strreplace
;kw_strreplace, <dest>, <text>, <find>, <with>  - Replace (NTC_STRMAX characters at most)
kw_strreplace:
			pop dword [ntc_rpdst]
			pop edx						; text
			pop ebx						; find
			pop ebp						; with
			mov edi, ntc_rpbuf
			mov ecx, NTC_STRMAX			; room
			cmp byte [ebx], 0
			je kw_rp_rest
kw_rp_lp:
			cmp byte [edx], 0
			je kw_rp_done
			xor esi, esi
kw_rp_m:
			mov al, [ebx+esi]
			test al, al
			jz kw_rp_hit
			cmp al, [edx+esi]
			jne kw_rp_miss
			inc esi
			jmp kw_rp_m
kw_rp_miss:						; one char across
			jecxz kw_rp_done
			mov al, [edx]
			inc edx
			stosb
			dec ecx
			jmp kw_rp_lp
kw_rp_hit:
			add edx, esi
			mov esi, ebp
kw_rp_w:
			lodsb
			test al, al
			jz kw_rp_lp
			jecxz kw_rp_done
			stosb
			dec ecx
			jmp kw_rp_w
kw_rp_rest:
			mov al, [edx]
			inc edx
			test al, al
			jz kw_rp_done
			jecxz kw_rp_done
			stosb
			dec ecx
			jmp kw_rp_rest
kw_rp_done:
			mov byte [edi], 0
			mov esi, ntc_rpbuf
			mov edi, [ntc_rpdst]
kw_rp_out:
			lodsb
			stosb
			test al, al
			jnz kw_rp_out
			ret
;@ram
ntc_rpdst:	dd 0
ntc_rpbuf:	times NTC_STRMAX+1 db 0
			align 2, db 0
;@rom

;## kw_stroct
;kw_stroct, <dest>, <var>  - Oct$ (16 bit unsigned, no leading zeros)
kw_stroct:
			pop edi
			pop esi
			movzx eax, word [esi]
			mov ecx, 15					; the digits' shifts: 15 (1 bit), 12, 9, 6, 3, 0
			xor ebx, ebx				; digit seen
kw_oc_lp:
			mov edx, eax
			shr edx, cl
			and edx, 7
			jnz kw_oc_out
			test ebx, ebx
			jnz kw_oc_out
			test ecx, ecx
			jnz kw_oc_skip
kw_oc_out:
			mov ebx, 1
			add dl, '0'
			mov [edi], dl
			inc edi
kw_oc_skip:
			sub ecx, 3
			jns kw_oc_lp
			mov byte [edi], 0
			ret

;## kw_strhex
;kw_strhex, <dest>, <nvar>  - Hex$(n), no leading zeros
kw_strhex:
			pop edi
			pop esi
			mov ax, [esi]
			mov ecx, 4					; 4 digits
			xor ebx, ebx				; seen
kw_hx_lp:
			rol ax, 4
			mov dl, al
			and dl, 15
			jnz kw_hx_out
			test ebx, ebx
			jnz kw_hx_out
			cmp ecx, 1
			jne kw_hx_next
kw_hx_out:
			mov ebx, 1
			add dl, '0'
			cmp dl, '9'+1
			jb kw_hx_put
			add dl, 7
kw_hx_put:
			mov [edi], dl
			inc edi
kw_hx_next:
			dec ecx
			jnz kw_hx_lp
			mov byte [edi], 0
			ret

;## kw_strasc
;kw_strasc, <src>, <destvar>  - Asc(src), 0 if empty
kw_strasc:
			pop esi
			movzx eax, byte [esi]
			pop esi
			mov [esi], ax
			ret

;## kw_strmidset
;kw_strmidset, <textvar>, <startvar>, <lenvar>, <src>  - Mid$(s, start, len) = src
kw_strmidset:
			pop edi						; text
			pop esi
			movsx eax, word [esi]		; start
			pop esi
			movzx ecx, word [esi]		; len
			pop esi						; src
			test eax, eax
			jle kw_ms_e
			cmp eax, 255
			ja kw_ms_e
			dec eax
			jz kw_ms_at
kw_ms_adv:
			cmp byte [edi], 0
			je kw_ms_e
			inc edi
			dec eax
			jnz kw_ms_adv
kw_ms_at:
			cmp ecx, 255
			jbe kw_ms_len
			mov ecx, 255
kw_ms_len:
			jecxz kw_ms_e
kw_ms_cp:
			cmp byte [edi], 0
			je kw_ms_e
			lodsb
			test al, al
			jz kw_ms_e
			stosb
			dec ecx
			jnz kw_ms_cp
kw_ms_e:
			ret

;## kw_strinstr ntc_getn
;kw_strinstr, <startvar>, <s1>, <s2>, <destvar>  - InStr(start, s1, s2)
kw_strinstr:
			pop esi
			mov ebp, kw_in_s
			jmp ntc_getn
kw_in_s:
			test eax, eax
			jnz kw_in_s1
			mov eax, 1
kw_in_s1:
			pop edx						; s1
			pop ebx						; s2
			mov ecx, eax
kw_in_adv:
			dec ecx
			jz kw_in_try
			cmp byte [edx], 0
			lea edx, [edx+1]
			jne kw_in_adv
			jmp kw_in_nf
kw_in_try:
			mov esi, edx
			mov edi, ebx
kw_in_cmp:
			mov cl, [edi]
			inc edi
			test cl, cl
			jz kw_in_found
			cmp cl, [esi]
			lea esi, [esi+1]
			je kw_in_cmp
			cmp byte [edx], 0
			lea edx, [edx+1]
			je kw_in_nf
			inc eax
			jmp kw_in_try
kw_in_nf:
			xor eax, eax
kw_in_found:
			pop esi
			mov [esi], ax
			ret

;## kw_strinstrrev
;kw_strinstrrev, <text>, <find>, <startvar>, <destvar>  - InStrRev (start -1 = from the end)
kw_strinstrrev:
			pop edx						; text
			pop ebx						; find
			pop esi
			movsx ebp, word [esi]		; start
			xor ecx, ecx
kw_ir_l1:
			cmp byte [edx+ecx], 0
			je kw_ir_g1
			inc ecx
			jmp kw_ir_l1				; ecx = len(text)
kw_ir_g1:
			xor eax, eax
kw_ir_l2:
			cmp byte [ebx+eax], 0
			je kw_ir_g2
			inc eax
			jmp kw_ir_l2				; eax = len(find)
kw_ir_g2:
			sub ecx, eax
			inc ecx						; last place it can start (1 based)
			test ebp, ebp
			jle kw_ir_lp
			cmp ebp, ecx
			jge kw_ir_lp
			mov ecx, ebp
kw_ir_lp:
			test ecx, ecx
			jle kw_ir_none
			lea esi, [edx+ecx-1]
			mov edi, ebx
kw_ir_cmp:
			mov al, [edi]
			inc edi
			test al, al
			jz kw_ir_found
			cmp al, [esi]
			lea esi, [esi+1]
			je kw_ir_cmp
			dec ecx
			jmp kw_ir_lp
kw_ir_none:
			xor ecx, ecx
kw_ir_found:
			pop esi
			mov [esi], cx
			ret

;## ntc_atoi ntc_data
; text at esi to a number into the var at (ntc_ivar). Spaces first, then - , then
; digits (or &H hex). Then ret (the thread).
ntc_atoi:
			xor eax, eax				; value
			xor edx, edx				; minus
			xor ecx, ecx
ntc_at_sp:
			mov cl, [esi]
			cmp cl, ' '
			jne ntc_at_sg
			inc esi
			jmp ntc_at_sp
ntc_at_sg:
			cmp cl, '-'
			jne ntc_at_amp
			mov edx, 1
			inc esi
			mov cl, [esi]
ntc_at_amp:
			cmp cl, '&'
			jne ntc_at_dec
			inc esi
			mov cl, [esi]
			inc esi
			or cl, 0x20
			cmp cl, 'h'
			jne ntc_at_done
ntc_at_hex:
			mov cl, [esi]
			inc esi
			sub cl, '0'
			jb ntc_at_done
			cmp cl, 10
			jb ntc_at_hd
			or cl, 0x20
			sub cl, 'a'-'0'
			jb ntc_at_done
			cmp cl, 6
			jae ntc_at_done
			add cl, 10
ntc_at_hd:
			shl ax, 4
			or ax, cx
			jmp ntc_at_hex
ntc_at_dec:
			mov cl, [esi]
			inc esi
			sub cl, '0'
			jb ntc_at_done
			cmp cl, 10
			jae ntc_at_done
			imul ax, ax, 10
			add ax, cx
			jmp ntc_at_dec
ntc_at_done:
			test edx, edx
			jz ntc_at_st
			neg ax
ntc_at_st:
			mov esi, [ntc_ivar]
			mov [esi], ax
			ret

;## kw_strval ntc_atoi
;kw_strval, <src>, <destvar>  - Val(src): decimal or &H hex
kw_strval:
			pop esi
			pop dword [ntc_ivar]
			jmp ntc_atoi

; ------------------------------------------------------------
; Arrays
; ------------------------------------------------------------

;## kw_aset
;kw_aset, <arraybase>, <indexvar>, <sourcevar>
kw_aset:
			pop edi
			pop esi
			movsx eax, word [esi]
			pop esi
			mov cx, [esi]
			mov [edi+eax*2], cx
			ret

;## kw_asetl
;kw_asetl, <arraybase>, <indexvar>, <literal>
kw_asetl:
			pop edi
			pop esi
			movsx eax, word [esi]
			pop ecx
			mov [edi+eax*2], cx
			ret

;## kw_aget
;kw_aget, <arraybase>, <indexvar>, <destvar>
kw_aget:
			pop esi
			pop edi
			movsx eax, word [edi]
			pop edi
			mov cx, [esi+eax*2]
			mov [edi], cx
			ret

;## kw_aset8
;kw_aset8, <arraybase>, <indexvar>, <sourcevar>  - set a Byte array element (low byte)
kw_aset8:
			pop edi
			pop esi
			movsx eax, word [esi]
			pop esi
			mov cl, [esi]
			mov [edi+eax], cl
			ret

;## kw_aget8
;kw_aget8, <arraybase>, <indexvar>, <destvar>  - Byte array element (0 .. 255)
kw_aget8:
			pop esi
			pop edi
			movsx eax, word [edi]
			pop edi
			movzx ecx, byte [esi+eax]
			mov [edi], cx
			ret

;## kw_l_aset
;kw_l_aset, <arraybase>, <indexvar>, <src>  - set a Long array element
kw_l_aset:
			pop edi
			pop esi
			movsx eax, word [esi]
			pop esi
			mov ecx, [esi]
			mov [edi+eax*4], ecx
			ret

;## kw_l_aget
;kw_l_aget, <arraybase>, <indexvar>, <dest>  - Long array element
kw_l_aget:
			pop esi
			pop edi
			movsx eax, word [edi]
			pop edi
			mov ecx, [esi+eax*4]
			mov [edi], ecx
			ret

;## kw_ubound
;kw_ubound, <descriptor + 2 * (dimension - 1)>, <dest>  - UBound = lower bound + count - 1
kw_ubound:
			pop esi
			mov ax, [esi+2]
			add ax, [esi+6]
			dec ax
			pop edi
			mov [edi], ax
			ret

;## kw_lbound
;kw_lbound, <descriptor + 2 * (dimension - 1)>, <dest>  - LBound
kw_lbound:
			pop esi
			pop edi
			mov ax, [esi+2]
			mov [edi], ax
			ret

;## kw_erase
;kw_erase, <base>, <bytes>  - Erase of a fixed size array: zero it
kw_erase:
			pop edi
			pop ecx
ntc_zerofill:						; edi = start, cx = bytes (unsigned)
			and ecx, 0xFFFF
			xor eax, eax
			rep stosb
			ret

;## kw_redim
;kw_redim, <descriptor>, <base>, <lower>, <size>, <count>, <clear>  - ReDim: fill the
;  descriptor (1 dimension); clear <> 0: zero the elements. Descriptor (12 bytes):
;  base (16 bits: RAM), lower 1, lower 2, count 1, count 2, element size
kw_redim:
			pop esi
			pop edi						; base
			pop eax						; lower
			pop edx						; size
			pop ecx						; count
			pop ebx						; clear
			mov [esi], di
			mov [esi+2], ax
			mov word [esi+4], 0
			mov [esi+6], cx
			mov word [esi+8], 1
			mov [esi+10], dx
			test bx, bx
			jz kw_rd_end
			and ecx, 0xFFFF
			and edx, 0xFFFF
			imul ecx, edx
			xor eax, eax
			rep stosb
kw_rd_end:
			ret

;## kw_sset kw_strcpy
;kw_sset, <arraybase>, <indexvar>, <src>, <element size>  - array(index) = src, cut at the element
kw_sset:
			pop edi
			pop esi
			movzx eax, word [esi]
			pop esi						; src
			pop ecx						; size
			and ecx, 0xFFFF
			imul eax, ecx
			add edi, eax
			dec ecx						; capacity
			jmp ntc_strcpy_lp

;## kw_sget
;kw_sget, <arraybase>, <indexvar>, <dest>, <element size>  - dest = array(index)
kw_sget:
			pop esi
			pop edi
			movzx eax, word [edi]
			pop edi						; dest
			pop ecx						; size
			and ecx, 0xFFFF
			imul eax, ecx
			add esi, eax
			rep movsb
			ret

; ------------------------------------------------------------
; Array parameters and dynamic arrays. A procedure gets the address of a
; 12 byte descriptor: dw base (RAM, 16 bits), lower bound 1, lower bound 2,
; count 1, count 2, element size.
; ------------------------------------------------------------

;## ntc_paddr
; esi = descriptor, edi = index var: esi = element address, ecx = element size. jmp ebp
ntc_paddr:
			mov ax, [edi]
			sub ax, [esi+2]				; element number
ntc_pa_tail:						; ax = element number, esi = descriptor
			movsx eax, ax
			movzx ecx, word [esi+10]
			movzx esi, word [esi]
			imul eax, ecx
			add esi, eax
			jmp ebp

;## kw_psets ntc_paddr kw_strcpy
;kw_psets, <descriptor>, <indexvar>, <src>  - String parameter array(index) = src
kw_psets:
			pop esi
			pop edi
			mov ebp, kw_pss_a
			jmp ntc_paddr
kw_pss_a:
			mov edi, esi
			pop esi
			dec ecx
			jmp ntc_strcpy_lp

;## kw_pset ntc_paddr
;kw_pset, <descriptor>, <indexvar>, <src>  - parameter array(index) = src
;  (a Byte element: the Integer's low byte, which is its first)
kw_pset:
			pop esi
			pop edi
			mov ebp, kw_ps_a
			jmp ntc_paddr
kw_ps_a:
			mov edi, esi
			pop esi
			rep movsb
			ret

;## kw_pget ntc_paddr
;kw_pget, <descriptor>, <indexvar>, <dest>  - dest = parameter array(index)
kw_pget:
			pop esi
			pop edi
			mov ebp, kw_pg_a
			jmp ntc_paddr
kw_pg_a:
			pop edi
			cmp ecx, 1					; a Byte element: into the Integer's low byte
			jne kw_pg_n1
			mov byte [edi+1], 0
kw_pg_n1:
			rep movsb
			ret

;## ntc_paddr2 ntc_paddr
; esi = descriptor, edi / edx = the 2 index vars: esi = element address, ecx = size. jmp ebp
ntc_paddr2:
			mov ax, [edi]
			sub ax, [esi+2]
			imul ax, [esi+8]			; (i - lo1) * count 2
			mov cx, [edx]
			sub cx, [esi+4]
			add ax, cx
			jmp ntc_pa_tail

;## kw_pset2 ntc_paddr2 kw_pset
;kw_pset2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src
kw_pset2:
			pop esi
			pop edi
			pop edx
			mov ebp, kw_ps_a
			jmp ntc_paddr2

;## kw_pget2 ntc_paddr2 kw_pget
;kw_pget2, <descriptor>, <index1var>, <index2var>, <dest>  - dest = array(i, j)
kw_pget2:
			pop esi
			pop edi
			pop edx
			mov ebp, kw_pg_a
			jmp ntc_paddr2

;## kw_callp
;kw_callp, <addressvar>, <arg>, ...  - CallAddr: jump to the procedure call stub whose
;  number (AddressOf: its place in the program's ntc_aptab) is in the var
kw_callp:
			pop esi
			movzx eax, word [esi]
			jmp [ntc_aptab+eax*4]

;## kw_ltolptr8
;kw_ltolptr8, <literal>, <literaladdr>  - POKE literal, literal
kw_ltolptr8:
			pop eax
			pop edi
			and edi, 0xFFFF
			mov [edi], al
			ret

;## kw_lptrtov8
;kw_lptrtov8, <literaladdr>, <destvar>  - PEEK(literal)
kw_lptrtov8:
			pop esi
			and esi, 0xFFFF
			movzx eax, byte [esi]
			pop edi
			mov [edi], ax
			ret

;## ntc_gets ntc_data ntc_plat_screen ntc_plat_key
; line input with echo and backspace, on the real stack (call). edx = buffer (its
; capacity in the byte before it). 0 terminated, then a new line.
ntc_gets:
			movzx ebx, byte [edx-1]		; capacity
			xor ecx, ecx				; typed
ntc_gs_wait:
			call ntc_plat_getkey
			cmp al, 13
			je ntc_gs_done
			cmp al, 127
			je ntc_gs_del
			cmp al, 8
			je ntc_gs_del
			cmp al, 32
			jb ntc_gs_wait
			cmp ecx, ebx
			jae ntc_gs_wait
			mov [edx+ecx], al
			inc ecx
			call ntc_plat_putc
			jmp ntc_gs_wait
ntc_gs_del:
			test ecx, ecx
			jz ntc_gs_wait
			dec ecx
			call ntc_plat_backspace
			jmp ntc_gs_wait
ntc_gs_done:
			mov byte [edx+ecx], 0
			jmp ntc_plat_newline

;## kw_inputstr ntc_gets
;kw_inputstr, <straddr>
kw_inputstr:
			pop edx
			NTC_RS
			call ntc_gets
			NTC_TS
			ret

;## kw_inkeys ntc_data ntc_plat_key
;kw_inkeys, <dest>  - Inkey$: the new key press as a string, "" if none
kw_inkeys:
			pop edx
			NTC_RS
			call ntc_plat_scankey
			NTC_TS
			mov [edx], al
			test al, al
			jz kw_iks_e
			mov byte [edx+1], 0
kw_iks_e:
			ret

;## kw_sqr
;kw_sqr, <var>, <destvar>  - Sqr: whole number square root (negative gives 0)
kw_sqr:
			pop esi
			movsx eax, word [esi]
			xor ecx, ecx
			test eax, eax
			js kw_sq_done
			mov edx, 1
kw_sq_lp:
			sub eax, edx
			jb kw_sq_done
			inc ecx
			add edx, 2
			jmp kw_sq_lp
kw_sq_done:
			pop edi
			mov [edi], cx
			ret

;## kw_pow
;kw_pow, <basevar>, <expvar>, <destvar>  - base ^ exp (Integer, low 16 bits; exp < 0 gives 0)
kw_pow:
			pop esi
			mov cx, [esi]				; base
			pop esi
			mov dx, [esi]				; exp
			mov eax, 1
			test dx, dx
			jns kw_pw_lp
			xor eax, eax
			jmp kw_pw_st
kw_pw_lp:
			test dx, dx
			jz kw_pw_st
			imul ax, cx
			dec dx
			jmp kw_pw_lp
kw_pw_st:
			pop edi
			mov [edi], ax
			ret

; ------------------------------------------------------------
; Long (32 bit signed, little endian). Every argument is an address
; (a literal is a dd in the program).
; ------------------------------------------------------------

;## kw_l_mov
kw_l_mov:
			pop esi
			pop edi
			mov eax, [esi]
			mov [edi], eax
			ret

;## kw_l_print ntc_itoa ntc_printbuf
kw_l_print:
			pop esi
			mov eax, [esi]
			mov edi, ntc_numbuf
			mov ebp, kw_lpr_b
			jmp ntc_itoa
kw_lpr_b:
			mov esi, ntc_numbuf
			jmp ntc_printbuf

;## kw_l_ltoi
;kw_l_ltoi, <long>, <intdest>  - Long to Integer (low 16 bits)
kw_l_ltoi:
			pop esi
			pop edi
			mov ax, [esi]
			mov [edi], ax
			ret

;## kw_l_itol
;kw_l_itol, <intvar>, <dest>  - Integer to Long (sign extended)
kw_l_itol:
			pop esi
			movsx eax, word [esi]
			pop edi
			mov [edi], eax
			ret

;## ntc_ldiv
; eax / ecx signed, truncating: eax = quotient, edx = remainder (the dividend's
; sign). Divide by 0: quotient 0, remainder = dividend. -2147483648 / -1: the
; quotient is -2147483648, remainder 0. jmp ebp
ntc_ldiv:
			test ecx, ecx
			jz ntc_ld_z
			cmp ecx, -1
			jne ntc_ld_go
			cmp eax, 0x80000000
			je ntc_ld_ov
ntc_ld_go:
			cdq
			idiv ecx
			jmp ebp
ntc_ld_z:
			mov edx, eax
			xor eax, eax
			jmp ebp
ntc_ld_ov:
			xor edx, edx
			jmp ebp

;## kw_l_mul
kw_l_mul:
			pop esi
			pop edi
			mov eax, [esi]
			imul eax, [edi]
kw_lmu_b:
			pop edi
			mov [edi], eax
			ret

;## kw_l_div ntc_ldiv kw_l_mul
kw_l_div:
			pop esi
			pop edi
			mov eax, [esi]
			mov ecx, [edi]
			mov ebp, kw_lmu_b
			jmp ntc_ldiv

;## kw_l_mod ntc_ldiv
kw_l_mod:
			pop esi
			pop edi
			mov eax, [esi]
			mov ecx, [edi]
			mov ebp, kw_lmd_b
			jmp ntc_ldiv
kw_lmd_b:
			pop edi
			mov [edi], edx
			ret

;## kw_l_cpeq
kw_l_cpeq:
			pop esi
			pop edi
			mov eax, [esi]
			cmp eax, [edi]
			ret

;## kw_l_cplt
kw_l_cplt:
			pop esi
			pop edi
			mov eax, [esi]
			cmp eax, [edi]
			setl al
			cmp al, 1
			ret

;## kw_l_cple
kw_l_cple:
			pop esi
			pop edi
			mov eax, [esi]
			cmp eax, [edi]
			setle al
			cmp al, 1
			ret

;## kw_l_cpgt
kw_l_cpgt:
			pop esi
			pop edi
			mov eax, [esi]
			cmp eax, [edi]
			setg al
			cmp al, 1
			ret

;## kw_l_cpge
kw_l_cpge:
			pop esi
			pop edi
			mov eax, [esi]
			cmp eax, [edi]
			setge al
			cmp al, 1
			ret

;## kw_l_cpne
kw_l_cpne:
			pop esi
			pop edi
			mov eax, [esi]
			cmp eax, [edi]
			setne al
			cmp al, 1
			ret

;## kw_l_add
kw_l_add:
			pop esi
			pop edi
			mov eax, [esi]
			add eax, [edi]
			pop edi
			mov [edi], eax
			ret

;## kw_l_sub
kw_l_sub:
			pop esi
			pop edi
			mov eax, [esi]
			sub eax, [edi]
			pop edi
			mov [edi], eax
			ret

;## kw_l_and
kw_l_and:
			pop esi
			pop edi
			mov eax, [esi]
			and eax, [edi]
			pop edi
			mov [edi], eax
			ret

;## kw_l_or
kw_l_or:
			pop esi
			pop edi
			mov eax, [esi]
			or eax, [edi]
			pop edi
			mov [edi], eax
			ret

;## kw_l_xor
kw_l_xor:
			pop esi
			pop edi
			mov eax, [esi]
			xor eax, [edi]
			pop edi
			mov [edi], eax
			ret

;## kw_l_not
kw_l_not:
			pop esi
			mov eax, [esi]
			not eax
			pop edi
			mov [edi], eax
			ret

;## kw_l_neg
kw_l_neg:
			pop esi
			mov eax, [esi]
			neg eax
			pop edi
			mov [edi], eax
			ret

;## kw_l_abs
kw_l_abs:
			pop esi
			mov eax, [esi]
			test eax, eax
			jns kw_la_st
			neg eax
kw_la_st:
			pop edi
			mov [edi], eax
			ret

;## kw_l_sgn
;kw_l_sgn, <a>, <intdest>  - -1, 0 or 1
kw_l_sgn:
			pop esi
			mov ecx, [esi]
			xor eax, eax
			test ecx, ecx
			jz kw_lsg_st
			mov eax, 1
			jns kw_lsg_st
			mov eax, -1
kw_lsg_st:
			pop edi
			mov [edi], ax
			ret

;## kw_l_pow
;kw_l_pow, <base>, <exp>, <dest>  - Long ^ (low 32 bits; exp < 0 gives 0)
kw_l_pow:
			pop esi
			mov ecx, [esi]				; base
			pop esi
			mov edx, [esi]				; exp
			mov eax, 1
			test edx, edx
			jns kw_lpw_lp
			xor eax, eax
			jmp kw_lpw_st
kw_lpw_lp:
			test edx, edx
			jz kw_lpw_st
			imul eax, ecx
			dec edx
			jmp kw_lpw_lp
kw_lpw_st:
			pop edi
			mov [edi], eax
			ret

;## kw_l_val
;kw_l_val, <src>, <destlong>  - Val() to a Long (decimal)
kw_l_val:
			pop esi
			pop edi
ntc_lv_go:
			xor eax, eax
			xor edx, edx
			xor ecx, ecx
ntc_lv_sp:
			cmp byte [esi], ' '
			jne ntc_lv_sg
			inc esi
			jmp ntc_lv_sp
ntc_lv_sg:
			cmp byte [esi], '-'
			jne ntc_lv_dig
			mov edx, 1
			inc esi
ntc_lv_dig:
			mov cl, [esi]
			inc esi
			sub cl, '0'
			jb ntc_lv_done
			cmp cl, 10
			jae ntc_lv_done
			imul eax, eax, 10
			add eax, ecx
			jmp ntc_lv_dig
ntc_lv_done:
			test edx, edx
			jz ntc_lv_st
			neg eax
ntc_lv_st:
			mov [edi], eax
			ret

;## kw_l_str ntc_itoa
kw_l_str:
			pop edi
			pop esi
			mov eax, [esi]
			test eax, eax
			js kw_lst_go
			mov byte [edi], ' '
			inc edi
kw_lst_go:
			mov ebp, ntc_next
			jmp ntc_itoa

;## kw_l_cstr ntc_itoa
kw_l_cstr:
			pop edi
			pop esi
			mov eax, [esi]
			mov ebp, ntc_next
			jmp ntc_itoa

;## kw_l_hex
;kw_l_hex, <dest>, <long>  - Hex$(Long): upper case, no leading zeros
kw_l_hex:
			pop edi
			pop esi
			mov eax, [esi]
			mov ecx, 8
			xor ebx, ebx
kw_lhx_lp:
			rol eax, 4
			mov dl, al
			and dl, 15
			jnz kw_lhx_out
			test ebx, ebx
			jnz kw_lhx_out
			cmp ecx, 1
			jne kw_lhx_next
kw_lhx_out:
			mov ebx, 1
			add dl, '0'
			cmp dl, '9'+1
			jb kw_lhx_put
			add dl, 7
kw_lhx_put:
			mov [edi], dl
			inc edi
kw_lhx_next:
			dec ecx
			jnz kw_lhx_lp
			mov byte [edi], 0
			ret

; ------------------------------------------------------------
; More integer keywords
; ------------------------------------------------------------

;## kw_absv
kw_absv:
			pop esi
			mov ax, [esi]
			test ax, ax
			jns kw_abs_st
			neg ax
kw_abs_st:
			pop edi
			mov [edi], ax
			ret

;## kw_sgnv
;kw_sgnv, <var>, <destvar>  - -1, 0 or 1
kw_sgnv:
			pop esi
			mov cx, [esi]
			xor eax, eax
			test cx, cx
			jz kw_sgn_st
			mov eax, 1
			jns kw_sgn_st
			mov eax, -1
kw_sgn_st:
			pop edi
			mov [edi], ax
			ret

;## kw_andvl
kw_andvl:
			pop esi
			pop eax
			and ax, [esi]
			pop edi
			mov [edi], ax
			ret

;## kw_orvl
kw_orvl:
			pop esi
			pop eax
			or ax, [esi]
			pop edi
			mov [edi], ax
			ret

;## kw_xorvl
kw_xorvl:
			pop esi
			pop eax
			xor ax, [esi]
			pop edi
			mov [edi], ax
			ret

;## kw_cpgevl ntc_cmp
kw_cpgevl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_uge

;## kw_cpgevv ntc_cmp
kw_cpgevv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_uge

;## kw_cpgtvl ntc_cmp
kw_cpgtvl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_ugt

;## kw_cpgtvv ntc_cmp
kw_cpgtvv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_ugt

;## kw_cplevl ntc_cmp
kw_cplevl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_ule

;## kw_cplevv ntc_cmp
kw_cplevv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_ule

;## kw_cpltvl ntc_cmp
kw_cpltvl:
			pop esi
			mov ax, [esi]
			pop ecx
			jmp ntc_cmp_ult

;## kw_cpltvv ntc_cmp
kw_cpltvv:
			pop esi
			pop edi
			mov ax, [esi]
			mov cx, [edi]
			jmp ntc_cmp_ult

;## kw_divlv ntc_div kw_divvv
;kw_divlv, <literal>, <var>, <destvar>
kw_divlv:
			pop eax
			pop edi
			mov cx, [edi]
			mov ebp, kw_div_q
			jmp ntc_div

;## kw_modlv ntc_div kw_modvv
kw_modlv:
			pop eax
			pop edi
			mov cx, [edi]
			mov ebp, kw_mod_r
			jmp ntc_div

;## kw_nextupv ntc_for_jump
;kw_nextupv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextupv:
			pop esi
			pop eax
			pop edi
			add [esi], ax
			jo ntc_for_skip
			mov cx, [edi]
			cmp cx, [esi]
			jge ntc_for_take
			lea esp, [esp+4]
			ret

;## kw_nextdnv ntc_for_jump
;kw_nextdnv, <var>, <literal step>, <limit var>, <toplabel>
kw_nextdnv:
			pop esi
			pop eax
			pop edi
			add [esi], ax
			jo ntc_for_skip
			mov cx, [edi]
			cmp cx, [esi]
			jle ntc_for_take
			lea esp, [esp+4]
			ret

;## kw_callv
;kw_callv, <addrvar>  - run machine code at the address in the var (a keyword: ends ret)
kw_callv:
			pop esi
			movzx eax, word [esi]
			jmp eax

;## kw_frame ntc_data ntc_plat_frame
;kw_frame  - wait for the start of the next frame (vertical blank)
kw_frame:
			NTC_RS
			call ntc_plat_frame
			NTC_TS
			ret

;## kw_inkey ntc_data ntc_plat_key
;kw_inkey, <destvar>  - new key press or 0, no wait
kw_inkey:
			pop ebx
			NTC_RS
			call ntc_plat_scankey
			NTC_TS
			and eax, 0xFF
			mov [ebx], ax
			ret

;## kw_inp
;kw_inp, <portvar>, <dest>  - Inp(n): the byte at I/O port n
kw_inp:
			pop esi
			movzx edx, word [esi]
			xor eax, eax
			in al, dx
			pop edi
			mov [edi], ax
			ret

;## kw_out
;kw_out, <portvar>, <valuevar>  - Out n, v: the byte to I/O port n
kw_out:
			pop esi
			movzx edx, word [esi]
			pop esi
			mov al, [esi]
			out dx, al
			ret

;## kw_inputint ntc_gets ntc_atoi ntc_d_inbuf
;kw_inputint, <var>  - signed decimal, stops at the first non digit
kw_inputint:
			pop dword [ntc_ivar]
			mov edx, ntc_inbuf
			NTC_RS
			call ntc_gets
			NTC_TS
			mov esi, ntc_inbuf
			jmp ntc_atoi

;## kw_l_input ntc_gets kw_l_val ntc_d_inbuf
;kw_l_input, <destlong>  - Input to a Long
kw_l_input:
			pop dword [ntc_ivar]
			mov edx, ntc_inbuf
			NTC_RS
			call ntc_gets
			NTC_TS
			mov esi, ntc_inbuf
			mov edi, [ntc_ivar]
			jmp ntc_lv_go

;## kw_l_printvb ntc_itoa ntc_printbuf
kw_l_printvb:
			pop esi
			mov eax, [esi]
kw_lpv_go:
			mov edi, ntc_numbuf
			test eax, eax
			js kw_lpv_neg
			mov byte [edi], ' '
			inc edi
kw_lpv_neg:
			mov ebp, kw_lpv_b
			jmp ntc_itoa
kw_lpv_b:
			mov word [edi], ' '			; a space, then the 0
			mov esi, ntc_numbuf
			jmp ntc_printbuf

;## kw_printintvb ntc_printbuf ntc_itoa kw_l_printvb
;kw_printintvb, <var>  - Option VBPrint: a space (or the -), the digits, a space
kw_printintvb:
			pop esi
			movsx eax, word [esi]
			jmp kw_lpv_go

;## kw_printzone kw_printtab
;kw_printzone  - Option VBPrint: a comma in Print moves to the next 14 column zone
kw_printzone:
			movzx eax, byte [ntc_curx]
			mov ebx, 14
kw_pz_find:
			cmp ebx, eax
			ja kw_pz_got
			add ebx, 14
			jmp kw_pz_find
kw_pz_got:
			movzx eax, byte [ntc_scols]
			cmp ebx, eax
			jb ntc_pt_go
			NTC_RS
			call ntc_plat_newline
			NTC_TS
			ret

;## kw_locatell ntc_data ntc_plat_screen
;kw_locatell, <x>, <y>  - 1 based
kw_locatell:
			pop eax
			pop ecx
			NTC_RS
			call ntc_plat_locate
			NTC_TS
			ret

;## kw_locatevv ntc_data ntc_plat_screen
;kw_locatevv, <xvar>, <yvar>
kw_locatevv:
			pop esi
			movsx eax, word [esi]
			pop esi
			movsx ecx, word [esi]
			NTC_RS
			call ntc_plat_locate
			NTC_TS
			ret

;## kw_model ntc_data ntc_plat_screen
;kw_model, <literal>  - clears the screen
kw_model:
			pop eax
			NTC_RS
			call ntc_plat_mode
			NTC_TS
			ret

;## kw_modev ntc_data ntc_plat_screen
kw_modev:
			pop esi
			movsx eax, word [esi]
			NTC_RS
			call ntc_plat_mode
			NTC_TS
			ret

;## kw_scrinit ntc_data ntc_plat_screen
kw_scrinit:
			ret

;## kw_psets2 ntc_paddr2 kw_psets
;kw_psets2, <descriptor>, <index1var>, <index2var>, <src>  - array(i, j) = src (String)
kw_psets2:
			pop esi
			pop edi
			pop edx
			mov ebp, kw_pss_a
			jmp ntc_paddr2

; ------------------------------------------------------------
; Peek / Poke / Deek / Doke: a 16 bit address ($0000-$FFFF, the first 64K)
; ------------------------------------------------------------

;## kw_lptrtov
;kw_lptrtov, <literaladdr>, <destvar>  - DEEK(literal)
kw_lptrtov:
			pop esi
			and esi, 0xFFFF
			pop edi
			mov ax, [esi]
			mov [edi], ax
			ret

;## kw_ltolptr
;kw_ltolptr, <literal>, <literaladdr>  - DOKE literal, literal
kw_ltolptr:
			pop eax
			pop edi
			and edi, 0xFFFF
			mov [edi], ax
			ret

;## kw_ltovptr
;kw_ltovptr, <literal>, <addrvar>  - DOKE var, literal
kw_ltovptr:
			pop eax
			pop esi
			movzx edi, word [esi]
			mov [edi], ax
			ret

;## kw_ltovptr8
;kw_ltovptr8, <literal>, <addrvar>  - POKE var, literal
kw_ltovptr8:
			pop eax
			pop esi
			movzx edi, word [esi]
			mov [edi], al
			ret

;## kw_vptrtov
;kw_vptrtov, <addrvar>, <destvar>  - DEEK(var)
kw_vptrtov:
			pop esi
			movzx esi, word [esi]
			pop edi
			mov ax, [esi]
			mov [edi], ax
			ret

;## kw_vptrtov8
;kw_vptrtov8, <addrvar>, <destvar>  - PEEK(var)
kw_vptrtov8:
			pop esi
			movzx esi, word [esi]
			movzx eax, byte [esi]
			pop edi
			mov [edi], ax
			ret

;## kw_vtolptr
;kw_vtolptr, <sourcevar>, <literaladdr>  - DOKE literal, var
kw_vtolptr:
			pop esi
			pop edi
			and edi, 0xFFFF
			mov ax, [esi]
			mov [edi], ax
			ret

;## kw_vtolptr8
;kw_vtolptr8, <sourcevar>, <literaladdr>  - POKE literal, var
kw_vtolptr8:
			pop esi
			pop edi
			and edi, 0xFFFF
			mov al, [esi]
			mov [edi], al
			ret

;## kw_vtovptr
;kw_vtovptr, <sourcevar>, <addrvar>  - DOKE var, var
kw_vtovptr:
			pop esi
			pop edi
			movzx edi, word [edi]
			mov ax, [esi]
			mov [edi], ax
			ret

;## kw_vtovptr8
;kw_vtovptr8, <sourcevar>, <addrvar>  - POKE var, var
kw_vtovptr8:
			pop esi
			pop edi
			movzx edi, word [edi]
			mov al, [esi]
			mov [edi], al
			ret

; ------------------------------------------------------------
; Random (16 bit xorshift 7,9,8 - the Z80 library's sequence)
; ------------------------------------------------------------

;## ntc_rnd_seed
;@ram
ntc_rnd_seed:	dw 1
;@rom

;## kw_rndl ntc_rnd_seed ntc_div
;kw_rndl, <literal>, <destvar>
kw_rndl:
			pop ecx
ntc_rnd:
			mov ax, [ntc_rnd_seed]		; ah = h, al = l
			mov dl, ah					; h' = ((h & 1) << 7 | l >> 1) xor h
			and dl, 1
			ror dl, 1
			mov dh, al
			shr dh, 1
			or dl, dh
			xor dl, ah
			mov dh, al					; l' = ((l & 1) << 7 | h' >> 1) xor l
			and dh, 1
			ror dh, 1
			mov bl, dl
			shr bl, 1
			or dh, bl
			xor dh, al
			xor dl, dh					; h'' = l' xor h'
			mov ah, dl
			mov al, dh
			mov [ntc_rnd_seed], ax
			test cx, cx
			jle ntc_rnd_zero
			and ax, 0x7FFF
			mov ebp, kw_mod_rr
			jmp ntc_div
kw_mod_rr:
			pop edi
			mov [edi], dx
			ret
ntc_rnd_zero:
			pop edi
			mov word [edi], 0
			ret

;## kw_rndv ntc_rnd_seed ntc_div kw_rndl
;kw_rndv, <nvar>, <destvar>  - 0 .. n-1 (0 if n <= 0)
kw_rndv:
			pop esi
			mov cx, [esi]
			jmp ntc_rnd

;## kw_seedl ntc_rnd_seed
;kw_seedl, <literal>
kw_seedl:
			pop eax
kw_sd_go:
			test ax, ax
			jnz kw_sd_ok
			mov eax, 1
kw_sd_ok:
			mov [ntc_rnd_seed], ax
			ret

;## kw_seedv ntc_rnd_seed kw_seedl
;kw_seedv, <var>  - RANDOMIZE var (0 becomes 1)
kw_seedv:
			pop esi
			mov ax, [esi]
			jmp kw_sd_go

; ------------------------------------------------------------
; More string keywords
; ------------------------------------------------------------

;## kw_strchr
;kw_strchr, <dest>, <nvar>  - Chr$(n)
kw_strchr:
			pop edi
			pop esi
			mov al, [esi]
			mov [edi], al
			mov byte [edi+1], 0
			ret

;## kw_strstr ntc_itoa
;kw_strstr, <dest>, <nvar>  - Str$(n): a space before 0 and positives
kw_strstr:
			pop edi
			pop esi
			movsx eax, word [esi]
			test eax, eax
			js kw_st_go
			mov byte [edi], ' '
			inc edi
kw_st_go:
			mov ebp, ntc_next
			jmp ntc_itoa

;## kw_strfix
;kw_strfix, <var>, <n>  - String * n after a change: pad with spaces / cut to n
kw_strfix:
			pop edi
			pop ecx
			and ecx, 0xFF
			jz kw_sf_end
kw_sf_len:
			cmp byte [edi], 0
			je kw_sf_pad
			inc edi
			dec ecx
			jnz kw_sf_len
			mov byte [edi], 0
			ret
kw_sf_pad:
			mov al, ' '
			rep stosb
kw_sf_end:
			mov byte [edi], 0
			ret

;## ntc_fmt ntc_data
; Format$ with a number pattern. ntc_fmbuf holds "-123"; the thread has
; <mindigits>, <group>, <prefix>, <suffix>. edi = the dest. ret (thread)
ntc_fm_common:
			pop edx						; mindigits
			pop ebx						; group
			pop ecx						; prefix
			mov esi, ntc_fmbuf
			cmp byte [esi], '-'
			jne ntc_fm_pre
			movsb
ntc_fm_pre:
			mov al, [ecx]
			inc ecx
			test al, al
			jz ntc_fm_cnt
			stosb
			jmp ntc_fm_pre
ntc_fm_cnt:
			xor eax, eax				; the digits counted
ntc_fm_c1:
			cmp byte [esi+eax], 0
			je ntc_fm_c2
			inc eax
			jmp ntc_fm_c1
ntc_fm_c2:
			xor ecx, ecx				; zeros in front
			and edx, 0xFF
			cmp edx, eax
			jbe ntc_fm_c3
			mov ecx, edx
			sub ecx, eax
ntc_fm_c3:
			mov edx, eax
			add edx, ecx				; digits to write
			mov ebp, edx
ntc_fm_mod:
			cmp ebp, 4
			jb ntc_fm_out
			sub ebp, 3
			jmp ntc_fm_mod				; ebp = digits before the first comma
ntc_fm_out:
			test edx, edx
			jz ntc_fm_suf
			jecxz ntc_fm_d
			dec ecx
			mov al, '0'
			stosb
			jmp ntc_fm_nx
ntc_fm_d:
			movsb
ntc_fm_nx:
			dec edx
			dec ebp
			jnz ntc_fm_out
			mov ebp, 3
			test edx, edx
			jz ntc_fm_suf
			test ebx, ebx
			jz ntc_fm_out
			mov al, ','
			stosb
			jmp ntc_fm_out
ntc_fm_suf:
			pop esi						; suffix
ntc_fm_s2:
			lodsb
			stosb
			test al, al
			jnz ntc_fm_s2
			ret
;@ram
ntc_fmdst:	dd 0
ntc_fmbuf:	times 16 db 0
;@rom

;## kw_strfmt ntc_fmt ntc_itoa
;kw_strfmt, <dest>, <var>, <mindigits>, <group>, <prefix>, <suffix>  - Format$(n, "0,000")
kw_strfmt:
			pop dword [ntc_fmdst]
			pop esi
			movsx eax, word [esi]
kw_sfm_go:
			mov edi, ntc_fmbuf
			mov ebp, kw_sfm_b
			jmp ntc_itoa
kw_sfm_b:
			mov edi, [ntc_fmdst]
			jmp ntc_fm_common

;## kw_l_strfmt ntc_fmt ntc_itoa kw_strfmt
;kw_l_strfmt, <dest>, <long>, <mindigits>, <group>, <prefix>, <suffix>  - Format$ of a Long
kw_l_strfmt:
			pop dword [ntc_fmdst]
			pop esi
			mov eax, [esi]
			jmp kw_sfm_go

;## kw_strjoin
;kw_strjoin, <dest>, <descriptor>, <sep>  - Join(stringarray, sep), NTC_STRMAX characters at most
kw_strjoin:
			pop dword [ntc_jndst]
			pop esi						; descriptor
			movzx edx, word [esi]		; base (RAM)
			movzx ebx, word [esi+6]		; count
			movzx ebp, word [esi+10]	; element size
			pop dword [ntc_jnsep]
			mov edi, ntc_jnbuf
			mov ecx, NTC_STRMAX
			test ebx, ebx
			jz kw_jn_done
kw_jn_el:
			mov esi, edx
kw_jn_c1:
			lodsb
			test al, al
			jz kw_jn_eend
			jecxz kw_jn_done
			stosb
			dec ecx
			jmp kw_jn_c1
kw_jn_eend:
			add edx, ebp
			dec ebx
			jz kw_jn_done
			mov esi, [ntc_jnsep]
kw_jn_c2:
			lodsb
			test al, al
			jz kw_jn_el
			jecxz kw_jn_done
			stosb
			dec ecx
			jmp kw_jn_c2
kw_jn_done:
			mov byte [edi], 0
			mov esi, ntc_jnbuf
			mov edi, [ntc_jndst]
kw_jn_out:
			lodsb
			stosb
			test al, al
			jnz kw_jn_out
			ret
;@ram
ntc_jndst:	dd 0
ntc_jnsep:	dd 0
ntc_jnbuf:	times NTC_STRMAX+1 db 0
			align 2, db 0
;@rom

;## kw_strlike
;kw_strlike, <text>, <pattern>  - Z if text Like pattern: * any run, ? one char,
;  # one digit, [abc] / [a-z] one of, [!abc] none of. Case matters
kw_strlike:
			pop edi						; text
			pop esi						; pattern
			xor edx, edx				; the last * (pattern after it), 0 none
			xor ebx, ebx				; where the text was then
kw_lk_lp:
			cmp byte [edi], 0
			je kw_lk_end
			mov al, [esi]
			cmp al, '*'
			jne kw_lk_one
			inc esi
			mov edx, esi
			mov ebx, edi
			jmp kw_lk_lp
kw_lk_one:
			test al, al
			jz kw_lk_back
			cmp al, '?'
			je kw_lk_ok1
			cmp al, '#'
			jne kw_lk_br
			cmp byte [edi], '0'
			jb kw_lk_back
			cmp byte [edi], '9'
			ja kw_lk_back
kw_lk_ok1:
			inc esi
			inc edi
			jmp kw_lk_lp
kw_lk_br:
			cmp al, '['
			jne kw_lk_lit
			inc esi
			xor ecx, ecx				; cl: ! = 1, ch: hit
			cmp byte [esi], '!'
			jne kw_lk_cl
			mov cl, 1
			inc esi
kw_lk_cl:
			mov al, [esi]				; al = low, ah = high
			test al, al
			jz kw_lk_back
			cmp al, ']'
			je kw_lk_clend
			mov ah, al
			inc esi
			cmp byte [esi], '-'
			jne kw_lk_cmp
			inc esi
			cmp byte [esi], ']'
			je kw_lk_dash
			cmp byte [esi], 0
			je kw_lk_back
			mov ah, [esi]
			inc esi
			jmp kw_lk_cmp
kw_lk_dash:
			dec esi
kw_lk_cmp:
			cmp [edi], al
			jb kw_lk_cl
			cmp [edi], ah
			ja kw_lk_cl
			mov ch, 1
			jmp kw_lk_cl
kw_lk_clend:
			inc esi
			cmp ch, cl
			je kw_lk_back
			inc edi
			jmp kw_lk_lp
kw_lk_lit:
			cmp [edi], al
			jne kw_lk_back
			inc esi
			inc edi
			jmp kw_lk_lp
kw_lk_back:
			test edx, edx
			jz kw_lk_no
			inc ebx
			mov edi, ebx
			mov esi, edx
			jmp kw_lk_lp
kw_lk_end:
			mov al, [esi]
			cmp al, '*'
			jne kw_lk_e2
			inc esi
			jmp kw_lk_end
kw_lk_e2:
			test al, al
			ret
kw_lk_no:
			xor eax, eax
			inc eax						; NZ
			ret

;## kw_strlset
;kw_strlset, <dest>, <src>  - LSet dest = src: src left in dest's length, spaces after
kw_strlset:
			pop edi
			pop esi
			xor ecx, ecx
kw_ls_len:
			cmp byte [edi+ecx], 0
			je kw_ls_go
			inc ecx
			jmp kw_ls_len
kw_ls_go:
			jecxz kw_ls_e
kw_ls_cp:
			mov al, [esi]
			test al, al
			jz kw_ls_pad
			inc esi
			stosb
			dec ecx
			jnz kw_ls_cp
kw_ls_e:
			ret
kw_ls_pad:
			mov al, ' '
			rep stosb
			ret

;## kw_strrset
;kw_strrset, <dest>, <src>  - RSet dest = src: src right in dest's length, spaces before
kw_strrset:
			pop edi
			pop esi
			xor ecx, ecx
kw_rs_len:
			cmp byte [edi+ecx], 0
			je kw_rs_l2
			inc ecx
			jmp kw_rs_len
kw_rs_l2:
			xor edx, edx
kw_rs_len2:
			cmp byte [esi+edx], 0
			je kw_rs_go
			inc edx
			jmp kw_rs_len2
kw_rs_go:
			jecxz kw_rs_e
			cmp edx, ecx
			jb kw_rs_pad
			rep movsb
kw_rs_e:
			ret
kw_rs_pad:
			sub ecx, edx
			mov al, ' '
			rep stosb
			mov ecx, edx
			rep movsb
			ret

;## kw_strsplit
;kw_strsplit, <descriptor>, <base>, <capacity>, <text>, <sep>, <element size>  - a() = Split(text, sep)
kw_strsplit:
			pop dword [ntc_sp_desc]
			pop eax
			mov [ntc_sp_base], eax
			mov [ntc_sp_el], eax		; the element being filled
			pop dword [ntc_sp_cap]		; capacity (elements)
			pop edx						; text
			pop ebx						; sep
			pop eax
			and eax, 0xFFFF
			mov [ntc_sp_size], eax
			xor ebp, ebp				; count
			cmp byte [edx], 0
			je kw_sp_fin
kw_sp_elem:
			cmp bp, [ntc_sp_cap]
			jae kw_sp_fin
			inc ebp
			mov edi, [ntc_sp_el]
			mov ecx, [ntc_sp_size]
			dec ecx						; room in the element
kw_sp_ch:
			cmp byte [edx], 0
			je kw_sp_last
			cmp byte [ebx], 0
			je kw_sp_nosep
			xor esi, esi
kw_sp_m:
			mov al, [ebx+esi]
			test al, al
			jz kw_sp_hit
			cmp al, [edx+esi]
			jne kw_sp_nosep
			inc esi
			jmp kw_sp_m
kw_sp_nosep:
			mov al, [edx]
			inc edx
			jecxz kw_sp_ch
			stosb
			dec ecx
			jmp kw_sp_ch
kw_sp_hit:
			add edx, esi
			mov byte [edi], 0
			mov eax, [ntc_sp_size]
			add [ntc_sp_el], eax
			jmp kw_sp_elem
kw_sp_last:
			mov byte [edi], 0
kw_sp_fin:
			mov esi, [ntc_sp_desc]
			mov eax, [ntc_sp_base]
			mov [esi], ax
			mov dword [esi+2], 0
			mov [esi+6], bp
			mov word [esi+8], 1
			mov eax, [ntc_sp_size]
			mov [esi+10], ax
			ret
;@ram
ntc_sp_desc:	dd 0
ntc_sp_base:	dd 0
ntc_sp_el:		dd 0
ntc_sp_cap:		dd 0
ntc_sp_size:	dd 0
;@rom

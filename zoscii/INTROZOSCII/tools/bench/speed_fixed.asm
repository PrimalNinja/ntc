; ============================================================
; ZOSCII Speed Test - NTC Version
; SP is instruction pointer
; Program is sequence of dw keyword addresses
; Each keyword ends with ret
; org at #2000
; (c) 2025 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
;
; NTC RULES
;   SP = instruction pointer. No call. No push.
;   Keywords pop args from thread via pop, end with ret.
;
; ARGUMENT ORDER
;   Pop gets args left-to-right as written after keyword.
;   dw kw_add, var1, var2, result
;     first pop  = var1 address
;     second pop = var2 address
;     third pop  = result address
;
; MEMORY LAYOUT (matches CP/M encoder)
;   rom_data    ROM_SIZE bytes  8KB ROM (needed for decode)
;   lookup      1024 bytes  256 entries x 4 (count + offset)
;   addr_list  16384 bytes  ROM_SIZE entries x 2 (ROM indices)
;   fill_tbl     512 bytes  256 x 2 (temp, only used during Phase 3)
;   enc_buffer   128 bytes  64 encoded addresses
;   dec_buffer    64 bytes  64 decoded bytes
;
; Decode needs 8KB (rom_data only)
; Encode needs 17KB (lookup + addr_list)
;
; ============================================================

            org #2000
			;write direct "zoscii.bin",#2000

; ============================================================
; Test selection (change which one is uncommented)
; ============================================================

ITERATIONS		 equ 5
CMDPREPARE	 	 equ #be80
CMDENCODE		 equ #be81
CMDDECODE		 equ #be82
STACK_PRESERVE	 equ #be83
TIMEADDR	 	 equ #b77c

; ============================================================
; Constants
; ============================================================

ROM_SIZE       equ 1024
MSG_SIZE       equ 64
ENC_SIZE       equ 256
RNGMAX		   equ 256

; ============================================================
; Startup
; ============================================================

startup:
            di
            ld (STACK_PRESERVE), sp
            ld sp, main_thread
            ret

; ============================================================
; Scratch space for keywords
; ============================================================

mul_result_sp:  dw 0
mul_mcand:      dw 0
mul_mplier:     dw 0
rom_seed:      dw 0
msg_seed:      dw 0
combined_seed: dw 0
timer_addr:		dw 0

; ============================================================
; Constants (used as keyword args)
; ============================================================

rng_max:      dw RNGMAX

; ============================================================
; Variables
; ============================================================

encode_count:   dw 0
decode_count:   dw 0

tmp0:           dw 0
tmp1:           dw 0
tmp2:           dw 0
tmp3:           dw 0
tmp4:           dw 0
tmp5:           dw 0
tmp6:           dw 0
tmp7:           dw 0
tmp8:           dw 0
tmp9:           dw 0

cmd_prepare:	dw 0
cmd_encode: 	dw 0
cmd_decode:		dw 0

byte_counter:   dw 0
byte_val:       dw 0
cnt_val:        dw 0
off_val:        dw 0
fill_val:       dw 0
rng_result:		dw 0
rng_salt:       dw 0
rng_state:      dw 0
running_offset: dw 0
rom_index:      dw 0

enc_idx:        dw 0
enc_char:       dw 0
enc_off:        dw 0
enc_cnt:        dw 0
enc_pos:        dw 0
enc_index:      dw 0
enc_adr:        dw 0

dec_idx:        dw 0
dec_adr:        dw 0
dec_byte:       dw 0

; ============================================================
; Pointer variables
; ============================================================

lookup_ptr:         dw lookup
rom_data_ptr:       dw rom_data
addr_list_ptr:      dw addr_list
fill_tbl_ptr:       dw fill_tbl
test_msg_ptr:       dw test_msg
enc_buffer_ptr:     dw enc_buffer
dec_buffer_ptr:     dw dec_buffer

; ============================================================
; Data
; ============================================================

test_msg:       db "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
				;db "This is a test message for ZOSCII encode decode speed testing. AAAAAAAAAA."
                ;ds MSG_SIZE-74, 0

; ============================================================
; Buffers
;   enc_buffer 128B   64 encoded addresses
;   dec_buffer  64B   64 decoded bytes
; ============================================================

				db "STARTENC>>>"
enc_buffer:     ds ENC_SIZE
				db "<<<"
				db "STARTMSG>>>"
dec_buffer:     ds MSG_SIZE
				db "<<<"

; ============================================================
; Main Thread - one flat continuous NTC thread
; ============================================================

main_thread:

			dw kw_lptrtov8, CMDPREPARE, cmd_prepare
			dw kw_lptrtov8, CMDENCODE, cmd_encode
			dw kw_lptrtov8, CMDDECODE, cmd_decode

			dw kw_ltov, TIMEADDR, timer_addr
			dw kw_saltrng, timer_addr, rng_salt

; ============================================================
; Phase 0 - Fill ROM with pseudorandom bytes
; (equivalent to BASIC .. FOR i=0 TO ROM_SIZE-1 .. POKE raw+i,INT(RND*256) .. NEXT)
; ============================================================

			; skip if not command prepare
            dw kw_goto_ifzero, cmd_prepare, prepare_skip
			dw bp_beforeprepare
			
            dw kw_ztov, rom_index
phase0_loop:
            dw kw_cpltvl, rom_index, ROM_SIZE
            dw kw_goto_iffalse, phase0_done
            dw kw_random, rng_state, rng_max, tmp1
            dw kw_add, rom_data_ptr, rom_index, tmp2
            dw kw_vtovptr8, tmp1, tmp2
            dw kw_inc, rom_index
            dw kw_goto, phase0_loop
phase0_done:
			dw bp_afterprepare0
			
            ;dw kw_ztov, rom_index
xphase0_loop:
            ;dw kw_cpltvl, rom_index, ROM_SIZE
            ;dw kw_goto_iffalse, phase0_done
            ;dw kw_add, rom_data_ptr, rom_index, tmp2
            ;dw kw_vtovptr8, rom_index, tmp2
            ;dw kw_inc, rom_index
            ;dw kw_goto, phase0_loop
xphase0_done:			
			;dw bp_afterprepare0

; ============================================================
; Phase 1 - Zero lookup then count byte occurrences
; (equivalent to CP/M count_bytes)
; lookup[byte*4] = count, lookup[byte*4+2] = offset (set in Phase 2)
; ============================================================

			dw kw_ztov, byte_counter
			
phase1_zero_loop:
            dw kw_cpltvl, byte_counter, 256
            dw kw_goto_iffalse, phase1_zero_done
            dw kw_4x, byte_counter, tmp1
            dw kw_add, lookup_ptr, tmp1, tmp2
            dw kw_addl, tmp2, 2, tmp3
            dw kw_ltovptr, 0, tmp2
            dw kw_ltovptr, 0, tmp3
            dw kw_inc, byte_counter
            dw kw_goto, phase1_zero_loop
phase1_zero_done:
            dw kw_ztov, rom_index
phase1_count_loop:
            dw kw_cpltvl, rom_index, ROM_SIZE
            dw kw_goto_iffalse, phase1_count_done
            dw kw_add, rom_data_ptr, rom_index, tmp1
            dw kw_vptrtov8, tmp1, byte_val
            dw kw_4x, byte_val, tmp2
            dw kw_add, lookup_ptr, tmp2, tmp3
            dw kw_vptrtov, tmp3, cnt_val
            dw kw_inc, cnt_val
            dw kw_vtovptr, cnt_val, tmp3
            dw kw_inc, rom_index
            dw kw_goto, phase1_count_loop
phase1_count_done:
			dw bp_afterprepare1

; ============================================================
; Phase 2 - Compute offsets into addr_list
; (equivalent to CP/M allocate_blocks)
; Walk 0..255, write running offset to lookup[byte*4+2]
; Also zero fill_tbl[byte*2] for Phase 3
; ============================================================

			dw kw_ztov, running_offset
            dw kw_ztov, byte_counter
phase2_loop:
            dw kw_cpltvl, byte_counter, 256
            dw kw_goto_iffalse, phase2_done
            dw kw_4x, byte_counter, tmp1
            dw kw_add, lookup_ptr, tmp1, tmp2
            ; read count
            dw kw_vptrtov, tmp2, cnt_val
            ; write running offset to lookup[byte*4+2]
            dw kw_addl, tmp2, 2, tmp3
            dw kw_vtovptr, running_offset, tmp3
            ; zero fill_tbl[byte*2]
            dw kw_2x, byte_counter, tmp4
            dw kw_add, fill_tbl_ptr, tmp4, tmp5
            dw kw_ltovptr, 0, tmp5
            ; running_offset += count
            dw kw_add, running_offset, cnt_val, running_offset
            dw kw_inc, byte_counter
            dw kw_goto, phase2_loop
phase2_done:
			dw bp_afterprepare2

; ============================================================
; Phase 3 - Populate addr_list with ROM indices
; (equivalent to CP/M populate_address_lists)
; Scan ROM. For each byte at position i
;   offset = lookup[byte*4+2]
;   fill = fill_tbl[byte*2]
;   addr_list[(offset + fill) * 2] = i
;   fill_tbl[byte*2] = fill + 1
; ============================================================

			dw kw_ztov, rom_index
phase3_loop:
            dw kw_cpltvl, rom_index, ROM_SIZE
            dw kw_goto_iffalse, phase3_done
            ; read byte from ROM
            dw kw_add, rom_data_ptr, rom_index, tmp1
            dw kw_vptrtov8, tmp1, byte_val
            ; get offset from lookup[byte_val*4+2]
            dw kw_4x, byte_val, tmp2
            dw kw_add, lookup_ptr, tmp2, tmp3
            dw kw_addl, tmp3, 2, tmp4
            dw kw_vptrtov, tmp4, off_val
            ; get fill counter from fill_tbl[byte_val*2]
            dw kw_2x, byte_val, tmp5
            dw kw_add, fill_tbl_ptr, tmp5, tmp6
            dw kw_vptrtov, tmp6, fill_val
            ; addr_list[(offset + fill) * 2] = rom_index
            dw kw_add, off_val, fill_val, tmp7
            dw kw_2x, tmp7, tmp8
            dw kw_add, addr_list_ptr, tmp8, tmp9
            dw kw_vtovptr, rom_index, tmp9
            ; fill++
            dw kw_inc, fill_val
            dw kw_vtovptr, fill_val, tmp6
            dw kw_inc, rom_index
            dw kw_goto, phase3_loop
phase3_done:
			dw bp_afterprepare3

; Phase 4 - Hash ROM into rom_seed
			;dw kw_ztov, rom_seed
			;dw kw_ztov, rom_index
phase4_loop:
			;dw kw_cpltvl, rom_index, ROM_SIZE
			;dw kw_goto_iffalse, phase4_done
			;dw kw_add, rom_data_ptr, rom_index, tmp1
			;dw kw_vptrtov8, tmp1, tmp2
			;dw kw_xorvv, rom_seed, tmp2, rom_seed  ; XOR byte into seed
			;dw kw_inc, rom_index
			;dw kw_goto, phase4_loop
phase4_done:
			;dw bp_afterprepare4

			dw bp_afterprepare
prepare_skip:

; ============================================================
; Encode test (ITERATIONS iterations)
; (equivalent to CP/M encode_input_streaming inner loop)
; For each byte in test message
;   count = lookup[byte*4]
;   offset = lookup[byte*4+2]
;   random_idx = random(count)
;   enc_buffer[i*2] = addr_list[(offset + random_idx) * 2]
; ============================================================

			; skip if not command encode
			dw kw_goto_ifzero, cmd_encode, encode_skip
			dw bp_beforeencode

			dw kw_ztov, encode_count
encode_loop_start:
            dw kw_cpltvl, encode_count, ITERATIONS
            dw kw_goto_iffalse, encode_loop_done
            dw kw_ztov, enc_idx
enc_loop:

; Create message hash
			;dw bp_beforereseed
			;dw kw_ztov, msg_seed
			;dw kw_ztov, tmp9
msg_hash_loop:
			;dw kw_cpltvl, tmp9, MSG_SIZE
			;dw kw_goto_iffalse, msg_hash_done
			;dw kw_add, test_msg_ptr, tmp9, tmp1
			;dw kw_vptrtov8, tmp1, tmp2
			;dw kw_xorvv, msg_seed, tmp2, msg_seed
			;dw kw_inc, tmp9
			;dw kw_goto, msg_hash_loop
msg_hash_done:
			;dw bp_afterreseed

; XOR ROM seed with message seed into RNG state
			;dw kw_xorvv, rom_seed, msg_seed, rng_salt   ; <--- CHANGED (this set the salt to 0 on every pass)

            dw kw_cpltvl, enc_idx, MSG_SIZE
            dw kw_goto_iffalse, enc_done
            ; read source byte
            dw kw_add, test_msg_ptr, enc_idx, tmp1
            dw kw_vptrtov8, tmp1, enc_char
            ; lookup base = lookup[enc_char*4]
            dw kw_4x, enc_char, tmp2
            dw kw_add, lookup_ptr, tmp2, tmp3
            ; count
            dw kw_vptrtov, tmp3, enc_cnt
            dw kw_goto_ifzero, enc_cnt, enc_skip
            ; offset
            dw kw_addl, tmp3, 2, tmp4
            dw kw_vptrtov, tmp4, enc_off
            ; random index in [0, count)
            dw kw_random, rng_state, enc_cnt, enc_pos
            ; addr_list[(offset + random) * 2]
            dw kw_add, enc_off, enc_pos, enc_index
            dw kw_2x, enc_index, tmp5
            dw kw_add, addr_list_ptr, tmp5, tmp6
            dw kw_vptrtov, tmp6, enc_adr
            ; store to enc_buffer[enc_idx * 2]
            dw kw_2x, enc_idx, tmp7
            dw kw_add, enc_buffer_ptr, tmp7, tmp8
            dw kw_vtovptr, enc_adr, tmp8
enc_skip:
            dw kw_inc, enc_idx
            dw kw_goto, enc_loop
enc_done:
            dw kw_inc, encode_count
            dw kw_goto, encode_loop_start
encode_loop_done:

			dw bp_afterencode
encode_skip:

; ============================================================
; Decode test (ITERATIONS iterations)
; (equivalent to CP/M decode_input_streaming)
; decoded_byte = rom_data[address]
; ============================================================

			; skip if not command decode
			dw kw_goto_ifzero, cmd_decode, decode_skip
			dw bp_beforedecode

			dw kw_ztov, decode_count
decode_loop_start:
            dw kw_cpltvl, decode_count, ITERATIONS
            dw kw_goto_iffalse, decode_loop_done
            dw kw_ztov, dec_idx
dec_loop:
            dw kw_cpltvl, dec_idx, MSG_SIZE
            dw kw_goto_iffalse, dec_done
            ; read address from enc_buffer[dec_idx * 2]
            dw kw_2x, dec_idx, tmp1
            dw kw_add, enc_buffer_ptr, tmp1, tmp2
            dw kw_vptrtov, tmp2, dec_adr
            ; decoded byte = rom_data[dec_adr]
            dw kw_add, rom_data_ptr, dec_adr, tmp3
            dw kw_vptrtov8, tmp3, dec_byte
            ; store to dec_buffer[dec_idx]
            dw kw_add, dec_buffer_ptr, dec_idx, tmp4
            dw kw_vtovptr8, dec_byte, tmp4
            dw kw_inc, dec_idx
            dw kw_goto, dec_loop
dec_done:
            dw kw_inc, decode_count
            dw kw_goto, decode_loop_start
decode_loop_done:

			dw bp_afterdecode
decode_skip:

            dw kw_stop

; ============================================================
; Breakpoints
; ============================================================

bp_beforeprepare:	ret
bp_afterprepare0:	ret
bp_afterprepare1:	ret
bp_afterprepare2:	ret
bp_afterprepare3:	ret
bp_afterprepare4:	ret
bp_afterprepare:	ret

bp_beforeencode:	ret
bp_beforereseed:	ret
bp_afterreseed:		ret
bp_afterencode:		ret

bp_beforedecode:	ret
bp_afterdecode:		ret

; ============================================================
; NTC Primitives - flow
; ============================================================

kw_stop:
            ld sp, (STACK_PRESERVE)
            ei
            ret

kw_goto:
            pop hl
            ld sp, hl
            ret

kw_goto_iffalse:
            pop hl
            jr nz, iffalse_goto
			ret

iffalse_goto:
            ld sp, hl
            ret

kw_goto_iftrue:
            pop hl
            jr z, iftrue_goto
			ret

iftrue_goto:
            ld sp, hl
            ret

kw_goto_ifzero:
            pop hl
            pop de
            ld a, (hl)
            inc hl
            or (hl)
            jr z, goif_goto
			ret
goif_goto:
			ex de, hl
            ld sp, hl
            ret

; ============================================================
; NTC Primitives - maths
; ============================================================

kw_dec:
            pop hl
            ld e, (hl)
			inc hl
			ld d, (hl)
			
			dec de

            dec hl
            ld (hl), e
			inc hl
			ld (hl), d
            ret

kw_inc:
            pop hl
            ld e, (hl)
			inc hl
			ld d, (hl)
			
			inc de

            dec hl
            ld (hl), e
			inc hl
			ld (hl), d
            ret

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

;kw_2x, <vartodouble>, <destvar>
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

;kw_4x, <vartodouble>, <destvar>
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

kw_multvl16:
            pop hl          ; HL = address of var1
            ld e, (hl)
            inc hl
            ld d, (hl)      ; DE = var1 value
            pop bc          ; BC = literal multiplier
							; DE * BC -> DE (simple loop for small numbers)
            ld hl, 0
            ld a, c
            or b
            jr z, mul_done
mul_loop:
            add hl, de
            dec bc
            ld a, b
            or c
            jr nz, mul_loop
mul_done:
            ex de, hl
            pop hl          ; HL = result variable address
            ld (hl), e
            inc hl
            ld (hl), d
            ret

; ============================================================
; NTC Primitives - logic
; ============================================================

kw_cpgtvl:
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
			ex de, hl
			
            pop hl
			
            or a
            sbc hl, de
			
            jr c, cpgtvl_false
			xor a
            ret
			
cpgtvl_false:
            ld a, 1
			and a
            ret

kw_cpgtvv:
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
			ex de, hl
			
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
			
            or a
            sbc hl, de
			
            jr c, cpgtvv_false
			xor a
            ret
			
cpgtvv_false:
            ld a, 1
			and a
            ret

kw_cpltvl:
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
			ex de, hl
			
            pop hl
			
            or a
			ex de, hl
            sbc hl, de
			
            jr c, cpltvl_true
            ld a, 1
			and a
            ret
			
cpltvl_true:
			xor a
            ret

kw_cpltvv:
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
			ex de, hl
			
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
			
            or a
			ex de, hl
            sbc hl, de
			
            jr c, cpltvv_true
            ld a, 1
			and a
            ret
			
cpltvv_true:
			xor a
            ret

; ============================================================
; NTC Primitives - assignments / memory movement
; ============================================================

;kw_lptrtov8, <sourceliteralptr>, <destvar>
;aka peek from literal address
kw_lptrtov8:
            pop hl
            ld a, (hl)
			
            pop hl
            ld (hl), a
            inc hl
			xor a
            ld (hl), a
            ret

;kw_vptrtov8, <sourcevarptr>, <destvar>
;aka peek from variable address
kw_vptrtov8:
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)

            ld a, (de)

            pop hl
            ld (hl), a
            inc hl
            xor a
            ld (hl), a
            ret

;kw_lptrtov, <sourceliteralptr>, <destvar>
;aka deek from literal address
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

;kw_vptrtov, <sourcevarptr>, <destvar>
;aka deek from variable address
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

;kw_ltovptr8, <literal>, <destvarptr>
;aka poke literal to variable address
kw_ltovptr8:
            pop bc

            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
			ex de, hl
            ld (hl), c
            ret
			
;kw_ltoptr, <literal>, <destvarptr>
;aka doke literal to variable address
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
			
;kw_ltoptr8, <sourcevar>, <destvarptr>
;aka poke variable to variable address
kw_vtovptr8:
            pop hl
            ld a, (hl)

            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
			ex de, hl
            ld (hl), a
            ret
			
;kw_ltoptr, <sourcevar>, <destvarptr>
;aka doke variable to variable address
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
			
;kw_ltov, <literal>, <destvar>
;aka assign a literal
kw_ltov:
            pop de
			
			pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret

;kw_vtov, <sourcevar>, <destvar>
;aka assign a variable
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

;kw_ztov, <destvar>
;aka assign zero value
kw_ztov:
			xor a

			pop hl
            ld (hl), a
            inc hl
            ld (hl), a
            ret

; ============================================================
; NTC Primitives - randomisation
; ============================================================

kw_random:
            ; <--- CHANGED: was counter XOR salt, then r mod max by repeated subtraction (up to 65535/max
            ; loops, and a counter XOR a constant just walks the values in order).
            ; Now: 16-bit xorshift (7,9,8: period 65535) and a bit mask with retry (no modulo, no bias).
            pop ix          ; IX = state variable
            pop bc          ; BC = max variable
            pop hl          ; HL = result variable
            ld (rng_result), hl
            ld a, (bc)
            ld e, a
            inc bc
            ld a, (bc)
            ld d, a         ; DE = max
            ld a, d
            or e
            jp z, rng_zero
            ld (rng_lim), de
            ; mask = smallest 2^n-1 >= max-1
            ld h, d
            ld l, e
            dec hl
            ld b, h
            ld c, l
            srl b
            rr c
            ld a, h
            or b
            ld h, a
            ld a, l
            or c
            ld l, a
            ld b, h
            ld c, l
            srl b
            rr c
            srl b
            rr c
            ld a, h
            or b
            ld h, a
            ld a, l
            or c
            ld l, a
            ld b, h
            ld c, l
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            srl b
            rr c
            ld a, h
            or b
            ld h, a
            ld a, l
            or c
            ld l, a
            ld a, h         ; x |= x >> 8
            or l
            ld l, a         ; (low byte: l | h; high byte stays h)
            ld b, h
            ld c, l         ; BC = mask
            ; state, never zero
            ld e, (ix+0)
            ld d, (ix+1)
            ld a, d
            or e
            jr nz, rng_next
            ld de, (rng_salt)
            ld a, d
            or e
            jr nz, rng_next
            ld de, #ACE1
rng_next:
            ; x ^= x << 7
            ld a, e
            and 1
            rrca
            ld l, a
            ld a, e
            srl a
            ld h, a
            ld a, d
            and 1
            rrca
            or h
            ld h, a
            ld a, d
            xor h
            ld d, a
            ld a, e
            xor l
            ld e, a
            ; x ^= x >> 9
            ld a, d
            srl a
            xor e
            ld e, a
            ; x ^= x << 8
            ld a, d
            xor e
            ld d, a
            ld (ix+0), e
            ld (ix+1), d
            ; candidate = x & mask, retry if >= max
            ld a, d
            and b
            ld h, a
            ld a, e
            and c
            ld l, a
            ld de, (rng_lim)
            or a
            sbc hl, de
            jr nc, rng_again
            add hl, de
            ex de, hl
            ld hl, (rng_result)
            ld (hl), e
            inc hl
            ld (hl), d
            ret
rng_again:
            ld e, (ix+0)
            ld d, (ix+1)
            jr rng_next

rng_lim:    dw 0

rng_zero:
            ld hl, (rng_result)
            ld (hl), 0
            inc hl
            ld (hl), 0
            ret

kw_saltrng:
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret

kw_xorvv:
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)      ; DE = var1
            
            pop hl
            ld a, (hl)
            xor e
            ld e, a
            inc hl
            ld a, (hl)
            xor d
            ld d, a         ; DE = var1 XOR var2
            
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
			
; ============================================================
; ROM Buffers
;   rom_data    8KB   the ROM (decode needs this)
;   lookup      1KB   256 x 4 (count + offset)
;   addr_list  16KB   ROM_SIZE x 2 (ROM indices)
;   fill_tbl  512B    256 x 2 (temp during Phase 3)
; ============================================================

				db "STARTLOOKUP>>>"
lookup:         ds 1024
				db "<<<"
				db "STARTFILLTBL>>>"
fill_tbl:       ds 512
				db "<<<"
				db "STARTROMDATA>>>"
rom_data:       ds ROM_SIZE
				db "<<<"
				db "STARTADDRLIST>>>"
addr_list:      ds ROM_SIZE*2
				db "<<<"
				
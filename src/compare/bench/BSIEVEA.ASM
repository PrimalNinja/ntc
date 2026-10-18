; ============================================================
; Sieve of Eratosthenes, primes below 8000 - plain hand-written Z80, for reference
; (pointer stepping, counter in a register; no unrolling or other tricks). CP/M .COM:
;   sjasmplus --raw=BSIEVEA.COM BSIEVEA.ASM
; ============================================================
	org #100
	ld sp,stk
	ld hl,msg_go
	push hl
	call puts
	pop hl
	ld hl,flags+2		; flags(2..8000) = 1
	ld (hl),1
	ld de,flags+3
	ld bc,7998
	ldir
	ld ix,0			; count
	ld bc,2			; i
	ld de,flags+8001	; end of the flags
outer:	ld hl,flags
	add hl,bc
	ld a,(hl)
	or a
	jr z,next
	inc ix
	add hl,bc		; flags + 2i
inner:	or a
	sbc hl,de
	jr nc,next
	add hl,de
	ld (hl),0
	add hl,bc
	jr inner
next:	inc bc
	ld hl,8000
	or a
	sbc hl,bc
	jr nc,outer
	push ix
	call printn
	pop hl
	jp 0
msg_go:	db "go",0
	include "io_z.inc"
flags:	ds 8001
	ds 128
stk:

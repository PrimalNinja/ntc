; tiny CP/M console I/O for the Small C test: puts(s), printn(n)
puts:
	pop bc
	pop hl
	push hl
	push bc
puts_lp:
	ld a,(hl)
	or a
	jr z,puts_nl
	push hl
	ld e,a
	ld c,2
	call 5
	pop hl
	inc hl
	jr puts_lp
puts_nl:
	ld e,13
	ld c,2
	call 5
	ld e,10
	ld c,2
	call 5
	ret
printn:
	pop bc
	pop hl
	push hl
	push bc
	ld de,10000
	call pn_dig
	ld de,1000
	call pn_dig
	ld de,100
	call pn_dig
	ld de,10
	call pn_dig
	ld a,l
	add a,'0'
	ld e,a
	ld c,2
	call 5
	jr puts_nl
pn_dig:
	ld a,'0'-1
pn_sub:
	inc a
	or a
	sbc hl,de
	jr nc,pn_sub
	add hl,de
	push hl
	ld e,a
	ld c,2
	call 5
	pop hl
	ret
getkey:
	ld e,#FF
	ld c,6
	call 5
	or a
	jr z,getkey
	ld l,a
	ld h,0
	ret

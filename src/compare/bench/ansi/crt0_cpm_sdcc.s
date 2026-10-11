	.module crt0
	.globl	_main
	.area	_HEADER (ABS)
	.org	0x100
	ld	hl,(6)		; top of the TPA
	ld	sp,hl
	call	gsinit
	call	_main
	jp	0
	.area	_HOME
	.area	_CODE
	.area	_INITIALIZER
	.area	_GSINIT
	.area	_GSFINAL
	.area	_DATA
	.area	_INITIALIZED
	.area	_BSEG
	.area	_BSS
	.area	_HEAP
	.area	_CODE
	.globl	_putchar
_putchar:			; CP/M console out, \n as CR LF (sdcccall(1): HL in, DE out)
	ld	a,l
	cp	#10
	jr	nz,00001$
	push	hl
	ld	e,#13
	ld	c,#2
	call	5
	pop	hl
00001$:	push	hl
	ld	e,l
	ld	c,#2
	call	5
	pop	de
	ret
	.area	_GSINIT
gsinit::
	ld	bc,#l__INITIALIZER
	ld	a,b
	or	a,c
	jr	z,gsinit_next
	ld	de,#s__INITIALIZED
	ld	hl,#s__INITIALIZER
	ldir
gsinit_next:
	.area	_GSFINAL
	ret

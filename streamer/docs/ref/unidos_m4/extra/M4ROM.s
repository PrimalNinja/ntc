			
			; M4 Board cpc z80 rom
			; Written by Duke, 2016/2017/2018
			; www.spinpoint.org
			
			.org  #C000
			.include "ff.i"	
			.include "firmware.i"
			.include "m4cmds.i"

rom_response					.equ	 #E800
m4_workspace 					.equ rom_response+ #A00
snamem 						.equ rom_response+ #B00
rom_config					.equ rom_response+ #C00

sock_status					.equ	 #FE00
rom_table						.equ	 #FF00
UDIR_RAM_Address 				.equ  #BEA3

DATAPORT						.equ  #FE00
ACKPORT						.equ  #FC00

			db	 #01
			db	2, 0, 0
	
			dw	rsx_commands

			; RSX jump block
			
			jp 	init_rom		;			 #C006
			jp	set_SDdrive	; |SD 		 #C009
			jp	disc			; |DISC		 #C00C
			jp	change_dir	; |CD		 #C00F
			jp	copy_file		; |COPYF		 #C012
			jp	tape			; |TAPE		 #C015
			jp	httpget		; |HTTPGET	 #C018
			jp	httpgetmem	; |HTTPMEM	 #C01B
			jp	drvA			; |A			 #C01E
			jp	drvB			; |B			 #C021
			jp	drive		; |DRIVE		 #C024
			jp	user			; |USER		 #C027
			jp 	directory		; |DIR		 #C02A
			jp	erase_file	; |ERA		 #C02D
			jp	rename_file	; |REN		 #C030
			jp	set_message	;  #81		 #C033
			jp	setup_disc	;  #82		 #C036
			jp	select_format	;  #83		 #C039
			jp	read_sector	;  #84		 #C03C
			jp	write_sector	;  #85		 #C03F
			jp	format_track	;  #86		 #C042
			jp	move_track	;  #87		 #C045
			jp	get_dr_status	;  #88		 #C048
			jp	set_retry_cnt	;  #89		 #C04B
			jp	m4off		; |M4ROMOFF	 #C04E
			jp	makedir		; |MKDIR		 #C051
			jp	setnetwork	; |NETSET		 #C054
			jp	netstat		; |NETSTAT	 #C057
			jp	gettime		; |TIME		 #C05A
			jp	upgrade		; |UPGRADE	 #C05D
			jp	version		; |VERSION	 #C060
			jp	rom_upload	; |ROMUP		 #C063
			jp	rom_set		; |ROMSET		 #C066
			jp	rom_update	; |ROMUPD		 #C069
			jp 	ls			; |ls		 #C06C
			jp	UDIR			; |UDIR		 #C06F
			jp	init_plus		;			 #C072
			jp	GETPATH		; |UDIR		 #C075
			jp	LongName		; |UDIR		 #C078
  			jp	wifi_power
  			jp	fcp
  			jp	m4help
  			jp	snaload
  			jp	ctrboot
  			jp	ctrupload
  			jp	dsk_extract
  			jp	romsoff
rsx_commands:
			.ascis "M4 BOARD"	
			.ascis "SD"
			.ascis "DISC"
			.ascis "CD"
			.ascis "COPYF"
			.ascis "TAPE"
			.ascis "HTTPGET"
			.ascis "HTTPMEM"
			.ascis "A"
			.ascis "B"
			.ascis "DRIVE"
			.ascis "USER"
			.ascis "DIR"
			.ascis "ERA"
			.ascis "REN"
			db  #81	; Set message
			db  #82	; Drive speed
			db  #83	; Disc type
			db  #84	; Read sector
			db  #85	; Write sector
			db  #86	; Format track
			db  #87	; Seek track
			db  #88	; Test drive
			db  #89	; Set retry count
			.ascis "M4ROMOFF"
			.ascis "MKDIR"
			.ascis "NETSET"
			.ascis "NETSTAT"
			.ascis "TIME"
			.ascis "UPGRADE"
			.ascis "VERSION"
			.ascis "ROMUP"
			.ascis "ROMSET"
			.ascis "ROMUPD"
			.ascis "LS"
			.ascis "UDIR"
			db	 #8A	; plus init
			.ascis "GETPATH"
			.ascis "LONGNAME"
			.ascis "WIFI"
			.ascis "FCP"
			.ascis "M4HELP"
			.ascis "SNA"
			.ascis "CTR"
			.ascis "CTRUP"
			.ascis "DSKX"
			.ascis "ROMSOFF"
			db 0


; work space map
; 000-073 : Amsdos openin header (if amsdos not present, otherwise use amsdos cas_in_header)
; 074-143 : Amsdos openout header	(if amsdos not present, otherwise use amsdos cas_out_header)
; 144-272	: actual work buffer

cas_out_isdirect	.equ	-5
cas_buf_l			.equ -4
cas_buf_h			.equ -3
cas_idx_l			.equ -2
cas_idx_h			.equ -1
cas_filetype		.equ 18
cas_size_l 		.equ	19	; data len
cas_size_h 		.equ	20

cas_in_next_byte	.equ  #23
cas_in_eof		.equ	 #24


init_rom:		push de
			push hl
			pop	iy
			; detect if amsdos present?
			ld	a,( #BC77)
			cp	 #DF			
			jr	z, use_amsdos
			
			ld	bc,-276			; 144+128
			add	iy,bc
			
			
			jr	init_cnt
use_amsdos:
			ld	bc,-128			; 128
			add	iy,bc
init_cnt:		push	iy				; workspace start
			
			ld	de, fio_jvec
init_cont:			
			ld	(iy),19+3			; config size+3 (to increase)
			ld	(iy+1),C_CONFIG
			ld	(iy+2),C_CONFIG>>8
			ld	(iy+3),0				; config offset (0..251)
			ld	(iy+6),e				; 02 patch jump vector l
			ld	(iy+7),d				; 03 patch jump vector h
			call kl_curr_selection		; get M4 rom number
			ld	(iy+8),a				; 04 current rom
			ld	(iy+9),0				; 05 init count.
			ld	a, #80
			cp	c					; was  #80 substracted, then we are using amsdos buffer
			jr	z,amsdos_buffers
			push	iy
			pop	hl
			
			ld	bc,5
			add	hl,bc			; point to amsdos in header
			
			ld	(iy+4),l			; 00 amsdos in header l
			ld	(iy+5),h			; 01 amsdos in header  h
			ld	bc,74
			add	hl,bc			
			ld	(iy+10),l			; 06 amsdos out header l
			ld	(iy+11),h			; 07 amsdos out header h
			ld	bc,74-5
			add	hl,bc		
			ld	(iy+20),0
			ld	(iy+21),0
			
			; set BE7D for compatiblity with loaders that read and use the pointer to ie. restore drive num.
			
			ld	a,l
			ld	( #BE7D),a
			ld	a,h
			ld	( #BE7E),a
				
			jr	no_amsdos_buffers
amsdos_buffers:
			ld	hl,( #BE7D)
			ld	bc, #55
			add	hl,bc			; point to amsdos in header
			
			ld	(iy+4),l			; 00 amsdos in header l
			ld	(iy+5),h			; 01 amsdos in header  h
			ld	bc,74
			add	hl,bc			
			ld	(iy+10),l			; 06 amsdos out header l
			ld	(iy+11),h			; 07 amsdos out header h
			
			ld	hl,( #BE7D)
			dec	hl
			dec	hl
			ld	a,(hl)			; amsdos rom number
			ld	c,a
			ld	(iy+21),c
			call	 #B915			; probe rom
			ld	(iy+20),h			; amsdos version
			push	iy
			pop	hl
			inc	hl
no_amsdos_buffers:
			ld	(iy+12),l			; 08 regular workspace for rom l
			ld	(iy+13),h			; 09 regular workspace for rom h
			push	iy
			pop	hl
			ld	de,14
			add	hl,de
			ex	de,hl
			ld	hl,txt_output
			ldi
			ldi
			ldi
			ld	hl, #bc6e
			ldi
			ldi
			ldi
			ld	c,0		; check basic rom ver
			call	 #B915	
			ld	(iy+22),h
			call	send_command_iy
			; save amsdos or tape functions
			; BCA7-BC77 = 48
			
			ld	(iy),48+3		; config size+3 
			ld	(iy+1),C_CONFIG
			ld	(iy+2),C_CONFIG>>8
			ld	(iy+3),22			; config offset
			push	iy
			pop	de
			inc	de
			inc	de
			inc	de
			inc	de
			ld	hl, #BC77
			ld	bc,48
			ldir
			call	send_command_iy
		
			call	set_SDdrive
			
			; detect if AZERTY or QWERTY keyboard
			ld hl, #B502
			ld a,( #BB5B)
			cp 0
			jr nz, basic11
			ld hl, #B3B8			
basic11:
			ld 	de,1						; dest offset
			ld	bc,DATAPORT					; data out port
			out (c),c
			ld	a, C_ROMWRITE					;
			out	(c),a						; command lo
			ld	a, C_ROMWRITE>>8				;
			out	(c),a						; command	hi
			out	(c),e						; rom dest addr
			out	(c),d						; rom dest addr
			
			out	(c),e						; size 1
			out	(c),d						; size 0001
			dec	d
			out	(c),d						; (0 = M4 ROM, 255 = nmi rom)
			ld	a,(hl)
			out	(c),a						; keyb val
			ld	b,ACKPORT>>8	; kick command
			out	(c),c
			
			pop	hl
			pop	de
			and	a
			scf
			ret
			
init_plus:	;ld	hl,0
			;jp	mc_start_program
			call kl_l_rom_enable
			ld 	hl,0
			jp 	 #77

init_msg:
			db " M4 Board v2.0.6"
			db 10, 13, 10, 13, 0
				
			; ------------------------- strncmp
			; -- parameters:
			; -- HL = string 1
			; -- DE = string 2
			; -- b = len
			; -- return:
			; -- A = 0 == match

strncmp:		ld	a,(de)
			xor	(hl)
			ret	nz
			inc	hl
			inc	de
			djnz	strncmp
			ret
			

			; ------------------------- strlen
			; -- parameters:
			; -- HL = zero terminated string
			; -- return:
			; -- A = length

strlen:
			push	bc
			push	hl
			ld	b,0
strlen_loop:
			ld	a,(hl)
			cp	0
			jr	z, term
			inc	hl
			inc	b
			jr	strlen_loop
term:
			ld	a,b
			pop	hl
			pop	bc
			ret
temp:
			scf
			sbc	a,a
			ret
			
			; ------------------------- strcpy
			; -- parameters:
			; -- HL = string
			; -- DE = dest.
			; -- B = string len
			; -- return:
			; -- A = length

strcpy:
			push	bc
			push	hl
			push	de
	
strcpy_loop:
			ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			djnz	strcpy_loop
			xor	a
			ld	(de),a
			pop	de
			pop	hl
			pop	bc
			ld	a,b
			inc	a
			ret

			; same but remove spaces
strcpynz:
			push	bc
			push	hl
			push	de
			ld	c,0
strcpy_loopnz:
			ld	a,(hl)
			cp	32
			jr	z,skip_space
			ld	(de),a
			inc	de
			inc	c
skip_space:			
			inc	hl
			djnz	strcpy_loopnz
			xor	a
			ld	(de),a
			pop	de
			pop	hl
			ld	a,c
			pop	bc
			inc	a
			ret

upper_case:
			cp	'a'
			ret	c
			cp	'z'+1
			ret	nc
			and	 #DF
			ret
			; ------------------------- strcpy83
			; -- parameters:
			; -- HL = string
			; -- DE = dest.
			; -- B = string len
			; -- return:
			; -- A = length

strcpy83:
			push	bc
			push	hl
			push	de
	
			; loop through first 8 characters, if we encounter '.' pad with spaces.
			
			ld	c,b	; in length
			ld	b,8
			
copy8:
			ld	a,c
			cp	0
			jr	z,space_pad
			ld	a,(hl)
			cp	 #2E		; are we at extension yet?
			jr	z,space_pad
			dec	c			; decrease inlength
			inc	hl
			call	upper_case
			jr	cont_strcpy83
space_pad:
			ld	a,32
cont_strcpy83:
			ld	(de),a
			inc	de
			djnz	copy8
			
			ld	b,3
			ld	a,(hl)
			cp	 #2E	; are we at extension yet?
			jr	z, has_ext
			ld	c,1			; no (valid) extension
has_ext:
			inc	hl			
			dec	c
			
copy3:		ld	a,c
			cp	0
			jr	z,space_pad2
			ld	a,(hl)
			inc	hl
			dec	c
			call	upper_case
			jr	cont_strcpy83_2
space_pad2:
			ld	a,32
cont_strcpy83_2:
			ld	(de),a
			inc	de
			djnz	copy3
			ld	a,0
			ld	(de),a
			pop	de
			pop	hl
			pop	bc
			ret
; ------------------------- fio jump vector
; AMSDOS  #CD30
fio_jvec:		di
			ex	af,af'
			exx
			ld	a,c
			pop	de				; return address
			pop	bc				; workspace?
			pop	hl 				;  #85 10000101 (disable upperrom)
			ex	(sp),hl			; get jump entry from stack
			push	bc				;
			push de				;
			ld	c,a				; 
			ld	b, #7f			
			ld	de,cas_hook_table- #bc77-3; offset from bc77
			add	hl,de			; add offset to jump table
			push hl				; save it on stack
			exx					; restore
			ex	af,af'
			ei
			ret
		
cas_hook_table:	
			jp _cas_in_open	; BC77
			jp _cas_in_close	; BC7A
			jp _cas_in_abandon	; BC7D
			jp _cas_in_char	; BC80
			jp _cas_in_direct	; BC83
			jp _cas_return		; BC86
			jp _cas_test_eof	; BC89
			jp _cas_out_open	; BC8C
			jp _cas_out_close	; BC8F
			jp _cas_out_abandon ; BC92
			jp _cas_out_char	; BC95
			jp _cas_out_direct	; BC98
			jp _cas_catalog	; BC9B

			; ------------------------- cas_in_open  replacement	BC77 
			; -- parameters
			; -- HL = filename
			; -- DE = 0 or 2Kbuffer
			; -- B = filename len
			; -- returns
			; -- carry true if valid
			; -- HL ptr to AMSDOS header
			; -- DE load address
			; -- BC filesize (-header)
			; -- A file type
			
_cas_in_open:	push	iy
			push	hl
			push	de
			push	bc
			ld	a,b
			cp	0
			jr	z, failopen
			
			ld	a,FA_READ			; read mode
			call	fopen
			cp	 #FF
			jr	nz, open_ok
			ld	a,b
			cp	 #92	; file not found? set Z flag.
			jr	nz,other_open_error
failopen:				
			pop	bc	; len
			pop	de
			pop	hl	; filename
			
			push	hl
			push	de
			push	bc
			push	af
			ld	iy,(rom_workspace)
			push	iy
			pop	de		; dest
			call strcpy83	; hl = filename, de =workspace, b = len
			ld	hl,11
			add	hl,de	
			ld	e,l
			ld	d,h
			push	de
			dec	hl
			ldd
			ldd
			ldd
			ld	a, #2E
			ld	(de),a
			pop	de
			inc	de
			; de = workspace
			ld	hl,text_not_found
			ld	bc,13
			ldir
			push	iy
			pop	hl
			call	disp_msg
			pop	af
other_open_error:
			pop	bc
			pop	de
			pop	hl
			pop	iy
			scf
			ccf
			ret
open_ok:

			; read first 128 bytes and check if its using AMSDOS header
			
			ld	de,(amsdos_inheader)
			
			ld	a,(amsdos_ver)
			cp	0
			jr	z, no_amsdos_rom
			
			; read to "buffer area"
			
			ld	hl, #E4- #55
			add	hl,de
			ex	de,hl
			ld	hl,128			; size of header
			ld	a,1					; fd
			call	fread
			
			; copy to real location
			
			ld	hl,(amsdos_inheader)
			ex	de,hl
			ld	bc,69
			push	de
			ldir
			pop	de
			jr	check_head
no_amsdos_rom:			
			ld	hl,69				; size of header
			ld	a,1					; fd
			call	fread
check_head:			
				
			; DE still amsdos header ptr
			push	de
			; check checksum
			ld	b,66
			ld	hl,0
checksum_loop:
			push	bc
			ld	a,(de)
			ld	c,a
			ld	b,0
			inc	de
			add	hl,bc
			pop	bc
			djnz	checksum_loop
			ld	iy,(amsdos_inheader)
			ld	e,cas_size_l(iy)
			ld	c,cas_size_h(iy)
			ld	d,0
			ld	b,0
			
			ld	cas_size_l(iy),0			;	
			ld	cas_size_h(iy),0			;	size
			; clear internal vars
			
			
			ld	cas_in_eof(iy),0
			ld	cas_in_next_byte(iy),0			; next char for test eof
		
			; compare with header checksum
			ld	a,l
			cp	(iy+67)
			jr	nz, checksum_mismatch
			ld	a,h
			cp	(iy+68)
			jr	z, checksum_ok
			
			; deal with headerless file
checksum_mismatch:
			; build "fake" header
			ld	hl,0
			ld	a,1
			call	fseek
			
			; clear header
			
			pop	hl			; header
			ld	b,69
clear_loop:
			ld	(hl),0
			inc	hl
			djnz	clear_loop			
			
			; copy filename into "fake" header
			pop	bc	; b = filename len
			pop	de	; 2k buffer or 0
			ld	(iy+21),e
			ld	(iy+22),d
			ld	cas_buf_l(iy),e
			ld	cas_buf_h(iy),d
			ld	cas_idx_l(iy),e
			ld	cas_idx_h(iy),d
			pop	hl	; filename
			push	iy
			pop	de
			inc	de
			call	strcpy83
			ld	(iy+18), #16; set as ascii?
			ld	(iy+23), #FF	; first block  #FF
			ld	(iy+66), #80
			;ld	de,0;	x170			; load adr
			;ld	e,(iy+19)
			;ld	d,(iy+20)
			;ld	iy,(rom_workspace)
			;ld	(iy+1),C_FSIZE		
			;ld	(iy+2),C_FSIZE>>8
			;ld	(iy+3),1			
			;ld	(iy),3
			;call send_command_iy
			ld	bc,0  ;(rom_response+3)	; size
			;ld	iy,(amsdos_inheader)
			ld	e,cas_buf_l(iy)
			ld	d,cas_buf_h(iy)
			push	iy
			pop	hl
			
				;or	a	; z = 0
			scf		; c = 1
			sbc	a,a
			ld	a, #16	; x2
			pop	iy
			ret
	
checksum_ok:	or	a
			sbc	hl,bc
			or	a
			sbc	hl,de
			ld	(iy+67),l
			ld	(iy+68),h
			
			ld	hl,128	; ignore rest of header (unused)
			ld	a,1
			call	fseek
			; get protection flag
;			ld	l,0
;			ld	a,(iy+18)
;			and	1
;			cp	0
;			jr	z,no_prot
;			inc	l
;no_prot:
;			ld	a,(basic_ver)	; version
;			cp	0		; is basic 1.0
;			ld	a,l
;			jr	nz,notpbasic10
;			ld	( #AE45),a
;			jr	pflag_set
;notpbasic10:	
;			ld	( #AE2C),a
;pflag_set:	
			
			pop	hl
			pop	de	; b =filename len
			pop	de	; 2k buffer or 0
			ld	cas_buf_l(iy),e
			ld	cas_buf_h(iy),d
			ld	cas_idx_l(iy),e
			ld	cas_idx_h(iy),d
		
			pop	de	; filename

			
			
			; DE = load address
			ld	e,(iy+21)
			ld	d,(iy+22)
			; BC = file size
			ld	c,(iy+24)
			ld	b,(iy+25)
			; A= file type
			
			scf	; set carry flag
			sbc	a,a	; clear z	
			ld	a,(iy+18)
			
			pop	iy

			ret
open_fail:
			pop	de
			pop	iy

			call	_cas_in_close
			or	a	
			
			ret

; ------------------------- cas_in_close replacement BC7A

_cas_in_close:
			; detect
			
			ld	a,1
			call	fclose
			cp	0
			scf
			jr	nz,close_fail
			sbc	a,a
			ret
close_fail:
			ccf	
			ret
; ------------------------- cas_in_abandon replacement BC7D

_cas_in_abandon:
			ld	a,1
			call	fclose
			scf
			sbc	a,a
			ret
	
; ------------------------- cas_in_char replacment BC80 
_cas_in_char:
			push	hl
			push	bc
			push de
			push	iy
			ld	iy,(amsdos_inheader)
		
			; size > 0
			
			ld	e,cas_size_l(iy)			;	size
			ld	d,cas_size_h(iy)			;	
			xor	a
			cp	e
			jr	nz, no_buffer_fill
			cp	d
			jr	nz, no_buffer_fill
			
			; EOF flag set ?
			ld	b, #F			; set hard EOF
			ld	a,cas_in_eof(iy)			; EOF yet?
			cp	0
			jp	nz, char_in_eof
			
			; re-fill buffer
	
			ld	bc,DATAPORT				; data out port
			out (c),c
			ld	a,C_READ2
			out	(c),a						; command lo
			ld	a,C_READ2>>8
			out	(c),a						; command	hi
			ld	a,1
			out	(c),a						; output char
			xor	a
			out	(c),a	
			ld	a,8
			out	(c),a	
			ld	bc,ACKPORT
			out (c),c							; tell M4 that command has been send
		
			; check rom response
				
			ld	a,(rom_response+3)
			cp	20				; eof ?
			jr	nz, not_eof_yet
			; Set EOF flag
			
			ld	a,1
			ld	cas_in_eof(iy),a			; this is end of file
			; check if read size == 0
			ld	hl,(rom_response+4)	; read size
			xor	a
			cp	h
			jr	nz, not_eof_yet
			cp	l
			jr	nz, not_eof_yet
			ld	b, #F			; set hard end
			jr	char_in_eof
not_eof_yet:			
			
			ld	hl,(rom_response+4)	; read size
			ld	cas_size_l(iy),l			; size
			ld	cas_size_h(iy),h			;	
			;ld	hl,(rom_response+6)
			ld	c,l
			ld	b,h
			ld	hl,rom_response+8
			
			ld	e, cas_buf_l(iy)
			ld	d, cas_buf_h(iy)
			ld	cas_idx_l(iy),e			; index
			ld	cas_idx_h(iy),d			; index
			
			xor	a
			cp	e
			jr	nz, buf_is_set
			cp	d
			jr	z, no_buffer_fill
buf_is_set:			
			ldir
			
			
no_buffer_fill:
		
			;ld	hl,rom_response+8
			
			ld	l,cas_idx_l(iy)			;	index
			ld	h,cas_idx_h(iy)			; 
			rst	 #20
			ld	b,a
			inc	hl
			ld	cas_idx_l(iy),l			;	index
			ld	cas_idx_h(iy),h			; 
			rst	 #20
			ld	l, cas_size_l(iy)			; size
			ld	h, cas_size_h(iy)
			dec	hl
			ld	cas_size_l(iy),l			; size
			ld	cas_size_h(iy),h			;	
		
			ld	cas_in_next_byte(iy),a
			
			ld	a,26
			cp	b
			jr	z, char_in_eof
			or	a	; z = 0
			scf		; c = 1
			ld	a,b
			pop	iy
			pop	de
			pop	bc
			pop	hl
			ret


char_in_eof:	or	a	; z = 0
			scf
			ccf		; c = 0
			ld	a,b	; get either  #F or  #1A
			pop	iy
			pop	de
			pop	bc
			pop	hl
			ret
		
	
			; ------------------------- cas_in_direct replacement BC83
			; -- parameters
			; -- HL = load address
			; -- returns
			; -- HL = exec addr

_cas_in_direct:
			push iy
			ld	iy,(amsdos_inheader)
			push	bc
	
			
			; DE = address
			ex	de,hl
			
			; HL = size
			xor a
			ld	l,(iy+24)
			ld	h,(iy+25)
			cp	h
			jr	nz, head_not_zero
			cp	l
			jr	nz, head_not_zero
			
			; get dsk record size instead
			
			ld	(iy+1),C_FSIZE		
			ld	(iy+2),C_FSIZE>>8
			ld	(iy+3),1			; fd
			ld	(iy),3
		
			call send_command_iy
		
			ld	hl,(rom_response+3)
			
head_not_zero:
			; A = fd
			
			ld	a,1
			
			call	fread
			cp	0
			jr	nz,in_direct_error
			; get exec addr
			ld	l,(iy+26)
			ld	h,(iy+27)
			pop	bc
			pop	iy
			scf
			sbc	a,a
			ret
in_direct_error:
			pop	bc
			pop	iy
			or	a	; clear carry
			ret
; ------------------------- cas_return replacement BC86	
_cas_return:
			push	hl
			push	de
			push	bc
			push	af
			ld	hl,ftell_cmd
			call	send_command
			ld	hl,(rom_response+3)
			dec	hl
			ld	a,1
			call	fseek
			pop	af
			pop	bc
			pop	de
			pop	hl
			ret
; ------------------------- cas_test_eof replacement BC89	
_cas_test_eof:	push	hl
			push	de
			push	iy
		
			ld	iy,(amsdos_inheader)
			ld	a,cas_in_next_byte(iy)			; last char+1
			cp	 #1A
			jr	z,is_eof

			ld	l,cas_size_l(iy)
			ld	h,cas_size_h(iy)
				
			; size > 0 ?
			
			xor	a
			cp	cas_size_l(iy)
			jr	nz, not_eof
			cp	cas_size_h(iy)
			jr	nz, not_eof
			
			; EOF flag set ?
			ld	a,cas_in_eof(iy)			; EOF yet?
			cp	0
			jr	z, not_eof
			ld	a, #F
is_eof:		pop	iy
			pop	de
			pop	hl
			or	a	; z = 0
			scf		
			ccf		; c = 0
			ret	
			
not_eof:		
			pop	iy
			pop	de
			pop	hl
			ld	a, #20
			or	a	; z = 0
			scf		; c = 1
			ret			
			
; ------------------------- cas_out_close replacement BC8F
_cas_out_close:
			push	iy
			ld	iy,(amsdos_outheader)
			ld	a, cas_out_isdirect(iy)
			cp	1
			jr	z, no_header

			; refresh header
			
			ld	hl,0
			ld	a,2
			call fseek
			
			; calc checksum
			ld	b,66
			ld	hl,0
			; 	de point to amsdos header
			ld	de,(amsdos_outheader)
calc_checksum_loop2:
			push	bc
			ld	a,(de)
			ld	c,a
			ld	b,0
			inc	de
			add	hl,bc
			pop	bc
			djnz	calc_checksum_loop2
			; save checksum
			ld	(iy+67), l
			ld	(iy+68), h
			
			push	iy
			pop	de			; amsdos header
			ld	hl,128	; size
			jr	do_cas_out_close
no_header:	
			; write out remaining buffer (if any)
			ld	l, cas_idx_l(iy)
			ld	h, cas_idx_h(iy)
			ld	e, cas_buf_l(iy)			
			ld	d, cas_buf_h(iy)		
			or	a
			push	de
			sbc	hl,de		; size
			pop	de			; addr
do_cas_out_close:
			ld	a,2			; fd
			call	fwrite
			ld	a,2
			call	fclose
			cp	0
			scf
			jr	nz,close_out_fail
			sbc	a,a
			pop	iy
			ret
close_out_fail:
			ccf	
			pop	iy
			ret

; ------------------------- cas_out_abandon replacement BC92
_cas_out_abandon:
			ld	a,2
			call	fclose
			scf
			sbc	a,a
			ret
; ------------------------- cas_out_open  replacement	BC8C
; -- parameters
; -- HL = filename
; -- DE = 2Kbuffer
; -- B = filename len
; -- returns
; -- HL holds the address of the buffer containing the file header data that will be written to each block.
; -- carry true if valid
; -- zero false

_cas_out_open:
			push	iy
			ld	a,FA_WRITE | FA_CREATE_ALWAYS	; write mode
			call	fopen
			cp	 #FF
			jr	nz, open_w_ok
			pop	iy
			or	a			; clear carry
			ret
open_w_ok:	push	bc
			ld	iy,(amsdos_outheader)
			
			ld	cas_out_isdirect(iy),1
			ld	cas_size_l(iy),0			;	
			ld	cas_size_h(iy),8			; size
			ld	cas_buf_l(iy),e			; 2k buffer
			ld	cas_buf_h(iy),d			;
			ld	cas_idx_l(iy),e			; 
			ld	cas_idx_h(iy),d			; index
			ld	cas_filetype(iy), #16		; filetype ascii
			
			; create	header
			push	iy
			pop	de
			ld	b, 69
clr_head:
			ld	(iy),0
			inc	iy
			djnz	clr_head
			
			inc	de	; amsdos header +1
			pop	bc	; filename length
			; hl = filename
			call	strcpy83
			ex	de,hl
			dec	hl	; HL points to AMSDOS header
			pop	iy
			ld	a, #ff
			scf		; c = 1
			sbc	a,a
		
			ret
; ------------------------- cas_out_char  replacement	BC95
; -- parameters
; -- A = char
_cas_out_char:	push	iy
			push	hl
			push	de
			push	bc
			push	af
			ld	iy,(amsdos_outheader)
			ld	a, cas_filetype(iy)
			cp	2
			jr	nz, no_tricky_header
			
			ld	b,66
			ld	hl,0
			; 	de point to amsdos header
			push	iy
			pop	de
calc_checksum_loop_4:
			push	bc
			ld	a,(de)
			ld	c,a
			ld	b,0
			inc	de
			add	hl,bc
			pop	bc
			djnz	calc_checksum_loop_4

			; save checksum
			ld	(iy+67), l
			ld	(iy+68), h
			
			push	iy
			pop	de
			ld	hl,128	; size
			ld	a,2			; fd
			call	fwrite
			ld cas_filetype(iy),  #16
			
no_tricky_header:			
			ld	c, cas_buf_l(iy)
			ld	b, cas_buf_h(iy)
			ld	l, cas_idx_l(iy)
			ld	h, cas_idx_h(iy)
			or	a
			sbc	hl,bc			; index - buf = size
			ld	a, cas_size_l(iy)
			cp	l
			jr	nz,no_writeback
			ld	a, cas_size_h(iy)
			cp	h
			jr	nz,no_writeback
			ld	e, cas_buf_l(iy)			
			ld	d, cas_buf_h(iy)	
			ld	cas_idx_l(iy),e
			ld	cas_idx_h(iy),d
			ld	cas_size_l(iy),0
			ld	cas_size_h(iy),8
			;ld	hl, #800		; size
			ld	a,2			; fd
			call	fwrite
			

no_writeback:	ld	l, cas_idx_l(iy)			
			ld	h, cas_idx_h(iy)		
			pop	af
			ld	(hl),a
			inc	hl
			ld	cas_idx_l(iy), l
			ld	cas_idx_h(iy), h
		
			pop	bc
			pop	de
			pop	hl
			pop	iy
			or	a					; z = 0
			scf						; c = 1
			ret


			; ------------------------- cas_out_direct  replacement	BC98
			; -- parameters
			; -- HL = address of data
			; -- DE = size of data
			; -- BC = execution address
			; --  A = filetype
_cas_out_direct:
			push	iy
			ld	iy,(amsdos_outheader)
			ld	cas_out_isdirect(iy),2
			; fill in header details
			; HL load address
			ld	(iy+21),l
			ld	(iy+22),h
			; DE = size
			ld	(iy+24),e
			ld	(iy+64),e
			ld	(iy+25),d
			ld	(iy+65),d
			; BC = exec addr
			ld	(iy+26),c
			ld	(iy+27),b
			; A = type
			ld	(iy+18),a
			; calc checksum
			ld	b,66
			ld	hl,0
			; 	de point to amsdos header
			push	iy
			pop	de
calc_checksum_loop:
			push	bc
			ld	a,(de)
			ld	c,a
			ld	b,0
			inc	de
			add	hl,bc
			pop	bc
			djnz	calc_checksum_loop
			; save checksum
			ld	(iy+67), l
			ld	(iy+68), h
			
			push	iy
			pop	de			; amsdos header
			ld	hl,128	; size
			ld	a,2			; fd
			call	fwrite
			cp	0
			jr	nz, out_direct_error
			
			; address
			ld	e,(iy+21)
			ld	d,(iy+22)
			; size
			ld	l, (iy+24)
			ld	h, (iy+25)
			; fd
			ld	a,2			; fd
			call	fwrite
			cp	0
			jr	nz, out_direct_error
			pop	iy
			scf
			sbc	a,a
			ret
out_direct_error:
			pop	iy
			or	a
			ret
			
; ------------------------- patch file I/O 
set_SDdrive:
			; is amsdos present?
			ld	a,(amsdos_ver)
			cp	0
			jr	z, skip_drive_restore
			
			; save amsdos drive info
			xor	a
			ld	hl,( #BE7D)
			cp	h
			jr	z, skip_drive_restore
			
			ld	(iy),3+3		; config size+3 
			ld	(iy+1),C_CONFIG
			ld	(iy+2),C_CONFIG>>8
			ld	(iy+3),80			; config offset
			ld	a,(hl)
			ld	(iy+4),a			; default drive
			inc	hl
			ld	a,(hl)
			ld	(iy+5),a			; default user
			inc	hl
			ld	a,(hl)
			ld	(iy+6),a			; active drive
			call	send_command_iy
		
skip_drive_restore:		
			ld	hl,jump_vec
			ld	de, #bca4	;	// overwrite cas check...
			push	de
			ldi
			ldi
			ldi
			ld	hl,cas_in_open
			ld	(hl), #df
			inc	hl
			pop	de
			ld	(hl),e
			inc	hl
			ld	(hl),d
			ld	hl,cas_in_open
			ld	de,cas_in_close
			ld	bc,36
			ldir 
			ret
set_SDdrive_in:
			ld	hl,jump_vec
			ld	de, #bca4	;	// overwrite cas check...
			push	de
			ldi
			ldi
			ldi
			ld	hl,cas_in_open
			ld	(hl), #df
			inc	hl
			pop	de
			ld	(hl),e
			inc	hl
			ld	(hl),d
			ld	hl,cas_in_open
			ld	de,cas_in_close
			ld	bc,6*3
			ldir 
			ld	de,cas_catalog
			ld	bc,3
			ldir
			ret			
set_SDdrive_out:
			ld	hl,jump_vec
			ld	de, #bca4	;	// overwrite cas check...
			push	de
			ldi
			ldi
			ldi
			ld	hl,cas_out_open
			ld	(hl), #df
			inc	hl
			pop	de
			ld	(hl),e
			inc	hl
			ld	(hl),d
			ld	hl,cas_out_open
			ld	de,cas_out_close
			ld	bc,4*3
			ldir 
			ret			
autoexec_patch:
			ld	hl,jump_vec2
			ld	de, #bc6e
			ldi
			ldi
			ld	hl,rom_num
			ldi
			ld	hl,txt_output
			ld	(hl), #df
			inc	hl
			ld	(hl), #6e
			inc	hl
			ld	(hl), #bc
			ret
undo_patch2:
			ld	hl,old_bb5a
			ld	de,txt_output
			ldi
			ldi
			ldi
			ld	hl,old_bc6e
			ld	de, #bc6e
			ldi
			ldi
			ldi
			ret
			
			; ------------------------- fopen
			; -- parameters: 
			; -- HL = filename
			; -- B = filename length
			; -- A = mode
			; -- return:
			; -- A = file fd (255 if error!)
			; -- B = error code
fopen:
			push	bc
			push	de
			push	hl
			push	iy
			ld	iy,(rom_workspace)
			ld	(iy+1),C_OPEN
			ld	(iy+2),C_OPEN>>8
			ld	(iy+3),a			; mode
			ld	a,h
			cp	 #C0			; is filename stored in screen?
			jr	c,filename_not_screen
			; lets copy it to our work ram
			push	bc
			ld	c,b			; filename len
			ld	b,0
			push	hl			; save filename src addr
			push	bc			; filename len
	
			push	iy
			pop	hl			; dest
			ld	bc, #30
			add	hl,bc
			ex	de,hl		; de is dest addr
			pop	bc			; restore len
			pop	hl			; restore src addr
			push	de
			call	kl_ldir		; copy into 'readable' workram
			pop	hl			; new src for filename
			pop	bc			; b = filename len
filename_not_screen:
			push	iy
			pop	de
			inc	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	a, 3			; cmd (2) + mode (1) + filename
			ld	(iy),a			; packet length
			call send_command_iy
			
			ld	a,(rom_response+4)	; check if open was OK?
			cp	0
			jr	nz, fd_not_ok
			ld	a,(rom_response+3)	; file descriptor 
			pop	iy
			pop	hl
			pop	de
			pop	bc
			ret
fd_not_ok:	
			; translate the error
			cp	255
			jr	z, skip_err_lookup
			ld	e,a
			ld	d,0
			ld	hl,ff_error_map
			add	hl,de
			ld	a,(hl)
skip_err_lookup:
			pop	iy
			pop	hl
			pop	de
			pop	bc
			ld	b,a
			ld	a,255
			or	a			; clear carry
			ret

			; ------------------------- fwrite
			; -- parameters: 
			; -- A = fd
			; -- HL = size
			; -- DE = addr
			; -- return:
			; -- A = 0 if OK
fwrite:
			push	iy
			push	hl
			push	de
			push	bc
			ld	iy,(rom_workspace)
			ld	c,a				; fd
			
write_loop:
			ld	a,d
			cp	 #C0			; is it screen, then we need to copy with rom disabled
			jr	c,not_screen
			; get chunk size (<= #80)
	
			ld	a,h
			cp	0
			jr	nz,scr_full_chunk
			ld	a,l
			cp	 #80
			jr	c,scr_fwrite_cont
scr_full_chunk:
			ld	a, #80
scr_fwrite_cont:
			cp	0
			jr	z,write_done		; size is 0?
	
			; A = size
			; HL = data
			; DE = COMMAND
			; C = fd
			push	hl				; total size
			ex	de,hl
			; HL = addr
			push	hl
			push	iy
			pop	de
			push bc
			ld	c,a
			ld	b,0
			call	kl_ldir
			pop	bc
			push	iy
			pop	hl
			
			ld	de,C_WRITE		; write cmd
			
			call send_command2
			
			pop	hl
			pop	de
			push	bc
			ld	b,0
			ld	c,a				; size
			add	hl,bc			; increase address
			ex	de,hl			; DE = addr
			or	a				; clear carry
			sbc	hl,bc			; and substract chunksize
			pop	bc
			jr	write_loop
			
not_screen:

			; get chunk size (<= #FC)
	
			ld	a,h
			cp	0
			jr	nz,wfull_chunk
			ld	a,l
			cp	 #FC
			jr	c,fwrite_cont
wfull_chunk:
			ld	a, #FC
fwrite_cont:
			cp	0
			jr	z,write_done		; size is 0?
	
			; A = size
			; HL = data
			; DE = COMMAND
			; C = fd
			push	hl				; total size
			ex	de,hl
			; HL = addr
			
			ld	de,C_WRITE		; write cmd
			
			call send_command2
			; todo, add error check!
			pop	de
			push	bc
			ld	b,0
			ld	c,a				; size
			add	hl,bc			; increase address
			ex	de,hl			; DE = addr
			or	a				; clear carry
			sbc	hl,bc			; and substract chunksize
			pop	bc
			jr	write_loop
write_done:
			pop	bc
			pop	de
			pop	hl
			pop	iy
			ret

			; ------------------------- fread
			; -- parameters: 
			; -- A = fd
			; -- HL = size
			; -- DE = addr
			; -- return:
			; -- A = 0 if OK
fread:
			push	hl
			push	de
			push	bc
			push	iy
			ld	iy,(rom_workspace)
			ld	(iy+1),C_READ
			ld	(iy+2),C_READ>>8
			ld	(iy+3),a				; fd
			ld	(iy),5				; packet size, cmd (2), fd (1), size (2)

read_loop:
			; get chunk size (<= #800)
			
			push	hl
			ld	bc,- #800
			add	hl,bc				; and substract chunksize
			jp	c, full_chunk
			pop 	hl
			ld	(iy+4),l				; chunk size low
			ld	(iy+5),h				; chunk size high
			jr	fread_cont
	
full_chunk:
			pop	hl
			ld	(iy+4), #0			; chunk size low
			ld	(iy+5), #8			; chunk size high
fread_cont:
			ld	a,0
			cp	(iy+4)
			jr	nz,not_done			; size is 0?
			cp	(iy+5)
			jr	nz,not_done			; size is 0?
			pop	iy
			pop	bc
			pop	de
			pop	hl
			xor	a
			ret
not_done:
			push	hl
			call	send_command_iy	; send read command packet
			ld	c,(iy+4)			; chunk size low
			ld	b,(iy+5)			; chunk size high
			ld	hl,rom_response+3	; src buffer
			
			ld	a,(hl)			; check result
			cp	0
			jr	nz,read_error
			inc	hl
			push	bc				; store chunk size
			ldir					; copy data in place
			pop	bc				; restore chunk size
			pop	hl				; restore remaining size
			or	a				; clear carry
			sbc	hl,bc			; and substract chunksize
			jr	read_loop
read_error:
			pop	hl
			pop	iy
			pop	bc
			pop	de
			pop	hl
			ret

; ------------------------- fseek
; -- parameters:
; -- A = fd 
; -- HL = offset
fseek:
			push	iy
			push	bc
			push	hl
			push	de
			
			ld	iy,(rom_workspace)
			ld	(iy),7			; size.. cmd(2) + offset (4)
			ld	(iy+1),C_SEEK		; cmd seek
			ld	(iy+2),C_SEEK>>8	; cmd seek
			ld	(iy+3),a			; fd
			ld	4(iy),l			; offset lo
			ld	5(iy),h			; offset hi
			ld	(iy+6),0			; 0
			ld	(iy+7),0			; 0
			call	send_command_iy
			
			pop	de
			pop	hl
			pop	bc
			pop	iy
			ret

; ------------------------- fclose
; -- parameters: 
; -- A = file fd
; -- return
; -- A = 0, good. A =  #FF bad.
fclose:
			push	bc
			push	hl
			push	iy
			ld	iy,(rom_workspace)
			ld	(iy+1),C_CLOSE		; close cmd
			ld	(iy+2),C_CLOSE>>8	; close cmd
			ld	(iy+3),a			; fd
			ld	(iy),3	; size - cmd(2) + fd(1)
			call send_command_iy
			ld	a,(rom_response+3)
			cp	255
			jp	nz,fclose_ok
			
			ld	a,(init_count)
			cp	2	
			jp	z,past_autoexec
			inc	a
			ld	(iy),4
			ld	(iy+1),C_CONFIG
			ld	(iy+2),C_CONFIG>>8
			ld	(iy+3),5			; config offset (0..251)
			ld	(iy+4),a	
			call	send_command_iy
			ld	a,(init_count)
			cp	2
			jp	nz, past_autoexec
			xor	a
			ld (UDIR_RAM_Address),a
			
			
			; run autoexec.bas if present

			ld	hl,init_msg
			call	disp_msg
			
			call	autoexec_patch
			
past_autoexec:	ld	a,255		
fclose_ok:	;xor	a
			pop	iy
			pop	hl
			pop	bc
			ret

load_autoexec:	
			di
			ex	af,af'
			exx
			ld	a,c
			pop	de
			pop	bc				
			pop	hl
			ex	(sp),hl
			push	bc	
			push de
			ld	c,a
			ld	b, #7f			
			ld	hl,autoexec1
			push hl
			exx
			ex	af,af'
			ei
			ret
autoexec1:			
			push	af
			push	bc
			push	de
			push	hl
			push	iy
			call	undo_patch2
			ld	iy,(rom_workspace)
			ld	hl, runfile_ptr
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			push	de
			; reset filename ptr back to autoexec.bas, in case it was overwritten, for next softreset!
			ld	hl, autoexec_fn
			ld	(iy),3+2
			ld	(iy+1),C_CONFIG
			ld	(iy+2),C_CONFIG>>8
			ld	(iy+3),20			; config offset (0..251)
			ld	(iy+4),l
			ld	(iy+5),h
				
			call	send_command_iy
			pop	hl
			call	strlen
			
			; check if SNA file
			push	hl
			push	af
			cp	5		; does it even have room for SNA extension?
			jr	c, not_sna_file
			
			ld	e,a
			ld	d,0
			add	hl,de	
			dec	hl
			ld	a,(hl)
			and	 #DF
			xor	'A'
			jr	nz,not_sna_file
			dec	hl
			ld	a,(hl)
			and	 #DF
			cp	'N'
			jr	nz,not_sna_file
			dec	hl
			ld	a,(hl)
			and	 #DF
			cp	'S'
			jr	nz,not_sna_file
			dec	hl
			ld	a,(hl)
			cp	'.'
			jr	nz,not_sna_file
			pop	af
			pop	hl            
			jp	snaload_str_hl
not_sna_file:
			pop	af
			pop	hl
			add	3
			push	af
			ld	de, autoexec_fn
			ld	c,FA_READ	;  #80 | 
			ld	a,e
			cp	l
			jr	nz,not_autofn
			ld	a,d
			cp	h
			jr	nz,not_autofn
			ld	c, FA_READ| #80;
not_autofn:	pop	af
			
			ld	de, C_OPEN
			call	send_command2	
			ld	hl,rom_response+3
			ld	b,(hl)		; fd
			inc	hl
			ld	a,(hl)		; res
			cp	0
			jp	nz, past_autoexec2
			
			; check if file size > 0 
			
			ld	(iy+1),C_FSIZE		
			ld	(iy+2),C_FSIZE>>8
			ld	(iy+3),b			; fd
			ld	(iy),3
			push	bc
			call send_command_iy
			pop	bc
			ld	hl,(rom_response+3)
			xor	a
			cp	h
			jr	nz,autoexec_not0
			cp	l
			jr	nz,autoexec_not0
			ld	(iy+1),C_CLOSE		; close cmd
			ld	(iy+2),C_CLOSE>>8	; close cmd
			ld	(iy+3),b			; fd
			ld	(iy),3	; size - cmd(2) + fd(1)
			call send_command_iy
			jp	past_autoexec2
			
autoexec_not0:			
			; get header
			ld	a,b
			ld	de,(amsdos_inheader)
			ld	hl, 69
			push	af
			call	fread
			pop	af
			ld	hl,128	; ignore rest of header (unused)
			push	af
			call	fseek
			pop	af
			
			; load addr 
			ld	iy,(amsdos_inheader)
			ld	e,(iy+21)
			ld	d,(iy+22)
			; HL = file size
			ld	l,(iy+24)
			ld	h,(iy+25)
	
			ld	iy,(rom_workspace)
			push	hl
			push	af
			call	fread
			pop	af
			ld	(iy+1),C_CLOSE		; close cmd
			ld	(iy+2),C_CLOSE>>8	; close cmd
			ld	(iy+3),a			; fd
			ld	(iy),3	; size - cmd(2) + fd(1)
			call send_command_iy
			
			; check if binary file
			ld	iy,(amsdos_inheader)
			ld	a,(iy+18)
			cp	2
			jr	z,exec_binary
			
			;ld	c,0
			;call	 #B915	; probe rom
			ld	a,(basic_ver)	; version
			pop	hl
			ld	bc, #170
			add	hl,bc
	
			
			cp	0		; is basic 1.0
			jr	z,basic10
			; basic 1.1
			ld ( #AE66),hl
			ld ( #AE68),hl
			ld ( #AE6A),hl
			ld ( #AE6C),hl
			jr	go_far
basic10:
			ld ( #AE83),hl
			ld ( #AE85),hl
			ld ( #AE87),hl
			ld ( #AE89),hl	
		
go_far:		cp	0
			jr	z,is464
			cp	1
			jr	z,is664
			db	 #DF
			dw far_addr6128
past_autoexec2:
			pop	iy
			pop	hl
			pop	de
			pop	bc
			pop	af
			jp	txt_output
			
is664:		db	 #DF
			dw far_addr664

is464:		db	 #DF
			dw far_addr464

far_addr464:	dw	 #E9BD
			db	0
far_addr664:	
			dw	 #EA7D
			db	0
far_addr6128:	
			dw	 #EA78
			db	0
exec_binary:	
			; get entry point
			ld	l,(iy+26)
			ld	h,(iy+27)
			ld	iy,(rom_workspace)
			
			ld	(iy+0),x37			; scf
			ld	(iy+1), #2			; ld hl, xxxx
			ld	(iy+2),l
			ld	(iy+3),h
			ld	(iy+4), #C9			; ret
			
			ld	hl,(rom_workspace)
			ld	de,sna_jumper
			ld	bc,5
			call	 rom_write	
			
			ld	sp, #C000
			ld	hl,sna_jumper
			jp	mc_boot_program

			;pop	de
			;pop	iy
			;pop	de	; was hl
			;pop	de
			;pop	bc
			;pop	af
			;jp	(hl)
			
			; ------------------------- _cas_catalog replacement BC9B
			; input
			; DE = workbuf
			; return
			; DE = workbuf
_cas_catalog:
			push	bc
			push	de
			push	hl
			push	iy
		
			
			ld	iy,(rom_workspace)
			ld	(iy+1),C_DIRSETARGS
			ld	(iy+2),C_DIRSETARGS>>8
			
			; store workbuf and index (max 2k)
			ld	(iy+120),e
			ld	(iy+121),d
			ld	(iy+122),0
			ld	(iy+123),0
			
			call	dir_no_args
			pop	iy
			pop	hl
			pop	de
			pop	bc
			ret
			scf
			sbc	a,a
			ret	
directory:	ld	iy,(rom_workspace)
			push	hl
			push	bc
			push	af
			
			; is it for amsdos?
			ld	b,11
			ld	a,( #BC78)
			cp	 #A4
			jp	nz,pass_to_amsdos
			
			pop	af
			pop	bc
			pop	hl	
			
			; set no workbuf
			ld	(iy+120),0
			ld	(iy+121),0
			
			
			ld	(iy+1),C_DIRSETARGS
			ld	(iy+2),C_DIRSETARGS>>8
			cp	1
			jp	nz, dir_no_args
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
			call	send_command_iy
			jr	directory_cont
dir_no_args:	
			ld	(iy), 3
			ld	(iy+3),0
			call	send_command_iy
directory_cont:			
			call	txt_get_window			; TXT GET WINDOW
			ld	a,d
			inc	a
			ld	c,0
div1:
			inc	c
			sub	20
			jp	pe, div_ovfl
			cp	0
			
			jr	nz, div1
div_ovfl:			
			; c = number of columns
			push	bc
			ld	hl,text_drive
			call	disp_msg
			; display current path
			ld	(iy+0),2
			ld	(iy+1),C_GETPATH
			ld	(iy+2),C_GETPATH>>8
			call	send_command_iy
			ld	hl,rom_response+3
			call	disp_msg
			call	crlf
			call	crlf
			
			pop	bc
			ld	b,0
dir_loop1:

			push	bc
			ld	hl,sdir_cmd
			call	send_command
			ld	hl,rom_response
			ld	a,(hl)
			cp	2
			jr	nz, sdir_cont1
			ld	hl,sfree_cmd
			call	send_command
			
			pop	bc
			ld	a,b
			cp	c
			jr	z,was_last_column1
			; add extra cr/lf, if last dir entry wasn't printed in last column
			call	crlf
was_last_column1:	
			ld	hl,rom_response+3
			call	disp_msg
			scf
			sbc	a,a
			ret	
sdir_cont1:	inc	hl
			inc	hl
			inc	hl
			call	direntry_workbuf
			push	hl
			push	de
			ld	de,9		; 01234567.9AB
			add	hl,de
			ld	a,(hl)
			ld	c,a			;RO attribute
			inc	hl
			ld	a,(hl)
			pop	de
			pop	hl
			and	 #80		; check for system attribute
			jr	z, not_sys	; skip displaying it.
			pop	bc
			jr	dir_loop1
not_sys:			
			ld	b,12		; 17
disp_name_loop:
			ld	a,(hl)
			and	 #7F
			inc	hl
			call	txt_output
			djnz	disp_name_loop
			ld	b,5
			ld	a,c
			and	 #80
			jr	z, not_ro_attr
			ld	a,'*'
			call txt_output
			inc	hl	; skip space
			dec	b
not_ro_attr:	ld	a,(hl)
			and	 #7F
			inc	hl
			call	txt_output
			djnz not_ro_attr		
			
			pop	bc
			inc	b
			ld	a,b
			cp	c
			jr	nz,next_column1
			call	crlf
		
			jr	dir_loop1
next_column1:
			ld	a,32
			call	txt_output
			call	txt_output
			call	txt_output
			; check for ESC
			call	check_esc_key
			cp	 #FC	; pressed twice ? ok leave...
			jp	nz,dir_loop1
			ld	hl,text_break
			call	disp_msg
			; exit
			scf
			sbc	a,a
			ret	
			
check_esc_key:	di
			push	bc
			call	km_read_char
			jr	nc, esc_exit			
			cp	 #FC
			jr	nz, esc_exit
			; wait for release
esc_loop:		call	km_read_char
			jr	c, esc_loop
			
			
wait_key:		call	km_read_char
			jr	nc,wait_key
esc_exit:
			pop	bc
			ei
			ret
direntry_workbuf:
			push	hl
			push	de
			push	bc
			xor	a
			ld	e, (iy+120)
			ld	d, (iy+121)
			cp	d
			jr	nz, dir_buf_is_set
			cp	e
			jr	z,no_dir_buf
dir_buf_is_set:
			ld	c, (iy+122); get index
			ld	b, (iy+123)
			
			ld	a, #FC
			cp	c		; end of buf? (14*146= #7FC)
			jr	nz, dir_buf_not_full
			ld	a, #7
			cp	b
			jr	z,no_dir_buf
dir_buf_not_full:
			; de = workbuf
			; hl = dir entry
			ex	de,hl	
			add	hl,bc	; workbuf + current entry 
			ld	a, #FF	; mark 
			ld	(hl),a
			inc	hl
			ex	de,hl	
			ld	bc,8	; copy first 8 bytes
			ldir			; 1+8
			inc	hl		; skip the dot
			ld	bc,3	; 1+8+3 = 12
			ldir			; copy the extension
			ld	bc,6	; skip ascii file size + terminator
			add	hl,bc
			ldi			; copy file size in binary
			ldi			; 1+8+3+2 = 14
			xor	a
			ld	(de),a	; set next entry to 0 if this was last
			
			ld	hl,14	; increase index
			ld	c, (iy+122); get index
			ld	b, (iy+123)
			add	hl,bc
			ld	(iy+122),l	; get index
			ld	(iy+123),h
			
			
no_dir_buf:	pop	bc
			pop	de
			pop	hl
			ret
			
			; ------------------------- LS command
			; displays directory with long filenames
			; mode 0 15 chars
			; mode 1 35 chars
			; mode 2 75 chars
			; +3 chars for folders
ls:
			ld	iy,(rom_workspace)
			ld	(iy+1),C_DIRSETARGS
			ld	(iy+2),C_DIRSETARGS>>8
			cp	1
			jp	nz, ls_no_args
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
			call	send_command_iy
			jr	ls_cont
ls_no_args:	
			ld	(iy), 3
			ld	(iy+3),0
			call	send_command_iy
ls_cont:			
			ld	hl,text_drive
			call	disp_msg
			; display current path
			ld	(iy+0),2
			ld	(iy+1),C_GETPATH
			ld	(iy+2),C_GETPATH>>8
			call	send_command_iy
			ld	hl,rom_response+3
			call	disp_msg
			call	crlf
			call	crlf
			
			call	txt_get_window		; get max width
			ld	a,d
			sub	4
			ld	d,a
						
ls_loop:		ld	a,3
			ld	bc,DATAPORT
			out	(c),a			; size cmd + maxfilenamelen
			ld	a,C_READDIR
			out	(c),a
			ld	a,C_READDIR>>8
			out	(c),a

			out	(c),d		; maxfilenamelen
			ld	b,ACKPORT>>8
			out	(c),c
			
			ld	hl,rom_response
			ld	a,(hl)
			cp	2
			jr	z, ls_done
			; display entry
			ld	hl,rom_response+3
			call	disp_msg
			ld	a,(rom_response+3)
			cp	'>'
			jr	nz,isfile
			call	crlf
			jr	ls_cont1
isfile:		ld	a,d
			push	hl
			inc	a
			call	txt_set_column
			pop	hl
			; display size
			inc	hl
			
			call	disp_msg
ls_cont1:		
			call	check_esc_key
			cp	 #FC	; pressed twice ? ok leave...
			jr	nz,ls_loop
			ld	hl,text_break
			call	disp_msg
			; exit
			scf
			sbc	a,a
			ret	
			
			
ls_done:			
			ld	hl,sfree_cmd
			call	send_command
			call	crlf			
			ld	hl,rom_response+3
			call	disp_msg
			scf
			sbc	a,a
			ret	
; ------------------------- HTTP GET - download file from http to current path
httpget:
			ld	iy,(rom_workspace)
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			ld	(iy+1),C_HTTPGET
			ld	(iy+2),C_HTTPGET>>8
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
			call	send_command_iy
			ld	hl,rom_response+3
			call	disp_msg
			scf
			sbc	a,a
			ret

; ------------------------- setup wifi
setnetwork:
			cp	1
			jp	nz, bad_args
			ld	iy,(rom_workspace)
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			ld	(iy+1),C_SETNETWORK
			ld	(iy+2),C_SETNETWORK>>8
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
			call	send_command_iy
			scf
			sbc	a,a
			ret
			
; ------------------------- get network status
netstat:
			ld	iy,(rom_workspace)
			ld	(iy),2
			ld	(iy+1),C_NETSTAT
			ld	(iy+2),C_NETSTAT>>8
			call	send_command_iy
			
			ld	hl,rom_response
			ld	a,(rom_response)
			ld	e,a
			ld	d,0
			add	hl,de
			ld	a,(hl)
			cp	5
			jr	z,is_connected
			
			ld	hl,rom_response+3
			call	disp_msg
			jp	skip_signal
is_connected:			
			ld	(iy),2
			ld	(iy+1),C_NETRSSI
			ld	(iy+2),C_NETRSSI>>8
			call	send_command_iy
			ld	a,(rom_response+3)
			cp	31
			jr	z,skip_signal
			
			ld	hl,text_signal
			call	disp_msg
			ld	a,(rom_response+3)
			call	disp_hex
			call	crlf
			ld	(iy),2
			ld	(iy+1),C_GETNETWORK
			ld	(iy+2),C_GETNETWORK>>8
			call	send_command_iy
			ld	hl,text_ip
			call	disp_msg
			ld	hl,rom_response+3+112
			call	disp_ip		
			ld	hl,text_nm
			call	disp_msg
			ld	hl,rom_response+3+116
			call	disp_ip		
			ld	hl,text_gw
			call	disp_msg
			ld	hl,rom_response+3+120
			call	disp_ip		
			ld	hl,text_dns1
			call	disp_msg
			ld	hl,rom_response+3+124
			call	disp_ip
			ld	hl,text_dns2
			call	disp_msg
			ld	hl,rom_response+3+128
			call	disp_ip
			ld	hl,text_mac
			call	disp_msg
			ld	hl,rom_response+3+190
			call	disp_mac
			
skip_signal:
			scf
			sbc	a,a
			ret
disp_mac:		ld	b,5
disp_mac_loop:
			push	hl
			push bc
			ld	a,(hl)
			call	disp_hex
			pop	bc
			pop	hl
			inc	hl
			ld	a,":"
			call	txt_output
			djnz	disp_mac_loop
			ld	a,(hl)
			call	disp_hex
			jp	crlf
			
disp_ip:		ld	b,3
disp_ip_loop:
			push	hl
			push	bc
			call	dispdec
			pop	bc
			pop	hl
			inc	hl
			ld	a, #2e
			call	txt_output
			djnz	disp_ip_loop
			; last digit
			call	dispdec
			jp	crlf
			
			
; ------------------------- get time and date
gettime:
			ld	iy,(rom_workspace)
			ld	(iy),2
			ld	(iy+1),C_TIME
			ld	(iy+2),C_TIME>>8
			call	send_command_iy
			
			ld	hl,rom_response+3
			call	disp_msg
			scf
			sbc	a,a
			ret
; ------------------------- get version
version:
			ld	iy,(rom_workspace)
			ld	(iy),2
			ld	(iy+1),C_VERSION
			ld	(iy+2),C_VERSION>>8
			call	send_command_iy
			
			ld	hl,rom_response+3
			call	disp_msg
			scf
			sbc	a,a
			ret
; ------------------------- get upgrades if available
upgrade:
			ld	iy,(rom_workspace)
			ld	(iy),2
			ld	(iy+1),C_UPGRADE
			ld	(iy+2),C_UPGRADE>>8
			call	send_command_iy
			
			ld	hl,rom_response+3
			call	disp_msg
			scf
			sbc	a,a
			ret
; ------------------------- get upgrades if available
httpgetmem:
			cp	3			; 2 arguments?
			jp	nz, bad_args
			ld	iy,(rom_workspace)
			; command
			ld	(iy+1),C_HTTPGETMEM
			ld	(iy+2),C_HTTPGETMEM>>8
			
			; get size
			ld	c,(ix)
			ld	b,(ix+1)
			ld	(iy+3),c
			ld	(iy+4),b
			
			; get address
			ld	e,(ix+2)
			ld	d,(ix+3)
			push	de				; store destination address
			ld	l,(ix+4)
			ld	h,(ix+5)
			ld	b,(hl)			; string len
			inc	hl
			ld	e,(hl)			; string ptr lo
			inc	hl
			ld	d,(hl)			; string ptr hi
			; de string ptr
			push	iy
			pop	hl
			push	bc
			ld	bc,5
			add	hl,bc
			; hl dest
			ex	de,hl
			pop	bc
			call	strcpy
			add	2+2+2
			ld	(iy),a
			call	send_command_iy
			ld	hl, rom_response+3
			ld	c,(hl)
			inc	hl
			ld	b,(hl)
			inc	hl
			; prepare next packet
			ld	(iy+0),6
			ld	(iy+1),C_COPYBUF
			ld	(iy+2),C_COPYBUF>>8
			ld	(iy+3),0			; offset
			ld	(iy+4),0			; offset
			push	bc
			; hl = total size
			pop	hl
			; de = dest addr
			pop	de
			
http_recv_loop:
			ld	a,0
			cp	h
			jr	nz,cont_http_recv
			cp	l
			jr	nz,cont_http_recv
			; nothing left, exit
			scf
			sbc	a,a
			ret

cont_http_recv:
			push	hl
			push	hl
			ld	bc,- #200
			add	hl,bc			; and substract chunksize
			jp	c, recv_full_chunk
			pop 	hl
			ld	(iy+5),l			; chunk size low
			ld	(iy+6),h			; chunk size high
			jr	cont_http_recv2
	
recv_full_chunk:
			pop	hl
			ld	(iy+5), #0			; chunk size low
			ld	(iy+6), #2			; chunk size high
cont_http_recv2:
			call	send_command_iy
			ld	hl,rom_response+3
									; de contains dest
			ld	c,(iy+5)				; chunk size
			ld	b,(iy+6)
			push	bc
			ldir					; de will increase
			pop	bc
			pop	hl				; total size 
			or	a				; clear carry
			sbc	hl,bc			; and substract chunksize
			push	hl
			ld	l,(iy+3)			; get copy from offset
			ld	h,(iy+4)
			add	hl,bc			; increase it.
			ld	(iy+3),l
			ld	(iy+4),h
			pop	hl
			jr	http_recv_loop

; ------------------------- ERA - erase file replacement
erase_file:
			push	hl
			push	bc
			push	af
			
			; is it for amsdos?
			ld	b,12
			ld	a,( #BC78)
			cp	 #A4
			jp	nz,pass_to_amsdos
			
			pop	af
			pop	bc
			pop	hl	
			
			cp	0
			jp	z,bad_args
			
			ld	iy,(rom_workspace)
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			
			push	iy
			ld	(iy+1),C_ERASEFILE
			ld	(iy+2),C_ERASEFILE>>8
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
			call	send_command_iy
			ld	hl,rom_response+3
			ld	a,(hl)
			cp	0
			jr	z,erase_ok
			; show error message
			ld	hl,rom_response+4
			call	disp_msg
erase_ok:	scf
			sbc	a,a
			ret


; ------------------------- REN - rename file replacement
rename_file:
			push	hl
			push	bc
			push	af
			
			; is it for amsdos?
			ld	b,13
			ld	a,( #BC78)
			cp	 #A4
			jp	nz,pass_to_amsdos
			
			pop	af
			pop	bc
			pop	hl	
			cp	2			; 2 arguments?
			jr	nz, bad_args
			ld	iy,(rom_workspace)
			ld	(iy+1),C_RENAME
			ld	(iy+2),C_RENAME>>8
			
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			
			ex	de,hl
			ld	c,a
			ld	b,0
			push	bc				; save size
			add	hl,bc			; add len to dest
			push	hl				; save dest
			
			; get 2nd string
			ld	l,(ix+2)
			ld	h,(ix+3)
			ld	b,(hl)			; string len
			inc	hl
			ld	e,(hl)			; string ptr lo
			inc	hl
			ld	d,(hl)			; string ptr hi
			ex	de,hl
			pop	de
			call	strcpy
			pop	bc				; restore size
			add	c				; add the two string lens together
			add	2				; add 2 for command hi/lo
			ld	(iy),a
			call	send_command_iy
			ld	hl,rom_response+3
			ld	a,(hl)
			cp	0
			jr	z,ren_ok
			; show error message
			ld	hl,rom_response+4
			call	disp_msg
ren_ok:		scf
			sbc	a,a
			ret
bad_args:
			ld	hl,miss_arg
			call	disp_msg
			scf
			sbc	a,a
			ret
; ------------------------- copy file 
copy_file:
			cp	2			; 2 arguments?
			jr	nz, bad_args
			ld	iy,(rom_workspace)
			ld	(iy+1),C_COPYFILE
			ld	(iy+2),C_COPYFILE>>8
			
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			
			ex	de,hl
			ld	c,a
			ld	b,0
			push	bc			; save size
			add	hl,bc	; add len to dest
			push	hl			; save dest
			
			; get 2nd string
			ld	l,(ix+2)
			ld	h,(ix+3)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			pop	de
			call	strcpy
			pop	bc			; restore size
			add	c			; add the two string lens together
			add	2			; add 2 for command hi/lo
			ld	(iy),a
			call	send_command_iy
			ld	hl,rom_response+3
			ld	a,(hl)
			inc	hl
			cp	0
			call	nz, disp_msg
			scf
			sbc	a,a
			ret

; ------------------------- MKDIR - make directory
makedir:
			cp	0
			jp	z,bad_args
			
			ld	iy,(rom_workspace)
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			
			push	iy
			ld	(iy+1),C_MAKEDIR
			ld	(iy+2),C_MAKEDIR>>8
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
			call	send_command_iy
			ld	hl,rom_response+3
			ld	a,(hl)
			cp	0
			jr	z,makedir_ok
			; show error message
			ld	hl,rom_response+4
			call	disp_msg
makedir_ok:	
			scf
			sbc	a,a
			ret
			
; ------------------------- CD - Change directory on SD card
change_dir:
			ld	iy,(rom_workspace)
			cp	0
			jr	nz,cd_has_args
			call	txt_get_window			; TXT GET WINDOW ( D = max column )
			ld	(iy),0		; offset 0 = init
			inc	d
			ld	(iy+1),d		; offset  = max column
			ld	(iy+2),0		; offset  = filename len
							; offset 3 = filename	
			call	get_path
			ld	a,(iy+2)
			add	2
			ld	(iy),a		; size
			ld	(iy+1),C_CD
			ld	(iy+2),C_CD>>8
			jr	send_cd_cmd
			
cd_has_args:			
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			
			push	iy
			ld	(iy+1),C_CD
			ld	(iy+2),C_CD>>8
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
send_cd_cmd:
			call	send_command_iy
			ld	hl,rom_response+3
			ld	a,(hl)
			cp	 #FF
			ret	nz
			ld	hl,text_unkdir
			call	disp_msg
			scf
			sbc	a,a
			ret

send_command:
			ld	bc,DATAPORT				; FE data out port
			ld	d,(hl)						; size
			inc	d
sendloop:		inc	b
			outi
			dec	d
			jr	nz, sendloop
			
			; tell M4 that command has been send
		
			ld	bc,ACKPORT
			out (c),c
			ret
			
send_command_iy:
			push	iy
			pop	hl
			ld	bc,DATAPORT	; #FE00			; FE data out port
			ld	a,(hl)						; size
			inc	a
sendloop_iy:
			inc	b
			outi
			dec	a
			jr	nz, sendloop_iy
			
			; tell M4 that command has been send
		
			ld	bc,ACKPORT
			out (c),c
			ret

			; DE = COMMAND			
			; A = size 
			; HL = DATA
			; C = fd
send_command2:
			push	af
			push	hl
			push	de
			push	bc
			add	3
			ld	bc,DATAPORT					; data out port
			out	(c),a						; size
			out	(c),e						; command lo
			out	(c),d						; command	hi
			pop	de
			push	de
			out	(c),e						; fd
			sub	3
			; send actual data
			
sendloop2:
			ld	d,(hl)
			out	(c),d
			inc	hl
			dec	a
			jr	nz, sendloop2
			
			; tell M4 that command has been send
			ld	bc,ACKPORT
			out (c),c
			pop	bc
			pop	de
			pop	hl
			pop	af
			ret




m4off:		push	iy
			push	hl
			ld	iy,(rom_workspace)
			ld	(iy),  #2
			ld	(iy+1), C_M4OFF
			ld	(iy+2), C_M4OFF>>8
			call	send_command_iy	; will never return, m4 will force a reset with the M4 rom disabled
			pop	hl
			pop	iy
			scf
			sbc	a,a
			
			ret
romsoff:		ld	(iy+3), #FF	; no exception
			ld	(iy+4),1		; do reset
			cp	2			; 2 arguments?
			jr	nz, no_exception
			ld	a,(ix+2)		; set both arguments
			ld	(iy+3),a
			ld	a,(ix+0)
			ld	(iy+4),a
no_exception:			
			push	iy
			push	hl
			ld	iy,(rom_workspace)
			ld	(iy),  #4
			ld	(iy+1), C_ROMSOFF
			ld	(iy+2), C_ROMSOFF>>8
			call	send_command_iy	; will never return, m4 will force a reset with all roms disabled
			pop	hl
			pop	iy
			scf
			sbc	a,a
			ret		
; ------------------------- Cartridge boot.
ctrboot:		push	iy
			push	hl
			
			ld	iy,(rom_workspace)
			ld	(iy),  #2
			ld	(iy+1), C_CTRBOOT
			ld	(iy+2), C_CTRBOOT>>8
			call	send_command_iy
			pop	hl
			pop	iy
			
			ret


; ------------------------- Cartridge upload - upload cartridge image to flash.
ctrupload:
			ld	iy,(rom_workspace)
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			ld	(iy+1),C_CTRUPLOAD	
			ld	(iy+2),C_CTRUPLOAD>>8
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	2
			ld	(iy),a
			call	send_command_iy
			ld	hl,rom_response+3
			call	disp_msg
			scf
			sbc	a,a
			ret			
; ------------------------- DSKX - Extract DSK files (dskname, dest path)
dsk_extract:
			cp	2			; 2 arguments?
			jp	nz, bad_args
			ld	iy,(rom_workspace)
			ld	(iy+1),C_DSKEXT
			ld	(iy+2),C_DSKEXT>>8
			
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			push	iy
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			
			ex	de,hl
			ld	c,a
			ld	b,0
			push	bc				; save size
			add	hl,bc			; add len to dest
			push	hl				; save dest
			
			; get 2nd string
			ld	l,(ix+2)
			ld	h,(ix+3)
			ld	b,(hl)			; string len
			inc	hl
			ld	e,(hl)			; string ptr lo
			inc	hl
			ld	d,(hl)			; string ptr hi
			ex	de,hl
			pop	de
			call	strcpy
			pop	bc				; restore size
			add	c				; add the two string lens together
			add	2				; add 2 for command hi/lo
			ld	(iy),a
ext_loop:
			call	send_command_iy
			ld	hl,rom_response+4
			call	disp_msg
			ld	hl,rom_response+3
			ld	a,(hl)
			cp	0
			jr	z,ext_loop
ext_ok:		scf
			sbc	a,a
			ret			
					
;cpm:
;			call kl_curr_selection
;			ld	c,a
;			ld	hl,cpm_boot
;			jp	mc_start_program
;cpm_boot:
;			ld	sp,  #C000
;			ld	c,  #41
;			ld	de, 0
;			ld	hl,  #100
;			call	read_sector
;			ld	sp,  #AD33
;			ld	bc, bios jump block ?
;			jp	(hl)
			
			
; -------------- BIOS disc I/O

; ------------------------- bios read sector replacement (cmd  #84)
; -- parameters
; -- HL = dest address of data 
; -- E  = drive number
; -- D  = track number
; -- C  = sector number
read_sector:
			push	hl
			push	bc
			push	af
			
			; is it for amsdos?
			ld	b,17
			ld	a,( #BC78)
			cp	 #A4
			jp	nz,pass_to_amsdos
			
			pop	af
			pop	bc
			pop	hl	
			
			push	iy
			push	hl
			ld	iy,(rom_workspace)
			ld	(iy),  #5
			ld	(iy+1), C_READSECTOR
			ld	(iy+2), C_READSECTOR>>8
			ld	(iy+3), d			; track
			ld	(iy+4), c			; sector
			ld	(iy+5), e			; drive
			push	hl
			call	send_command_iy
			pop	de
			ld	hl,rom_response+4	; src buffer
			ld	bc,512
			ldir
			pop	iy
			pop	hl
			scf
			sbc	a,a
			ret			
; ------------------------- bios write sector replacement (cmd  #85)
; -- parameters
; -- HL = src address of data 
; -- E  = drive number
; -- D  = track number
; -- C  = sector number
write_sector:
			push	hl
			push	bc
			push	af
			
			; is it for amsdos?
			ld	b,18
			ld	a,( #BC78)
			cp	 #A4
			jp	nz,pass_to_amsdos
			
			pop	af
			pop	bc
			pop	hl	
			
			push	hl
			push	bc
			ld	bc,DATAPORT
			out	(c),c
			ld	a,C_WRITESECTOR
			out	(c),a						
			ld	a, C_WRITESECTOR>>8
			out	(c),a						
			out	(c),d			; track
			pop	de
			out	(c),e			; sector
			out	(c),d			; drive
			ld	de,512
sec_data_loop:
			ld	a,(hl)			; rst &20 or add >= &c000 check later....
			out	(c),a
			inc	hl
			dec	de
			xor	a
			cp	d
			jr	nz,sec_data_loop
			cp	e
			jr	nz,sec_data_loop
			ld	bc,ACKPORT
			out (c),c
			pop	hl
			scf
			sbc	a,a
			ret						
			
disp_msg:		ld 	a, (hl)
			or	a
			ret	z
			call txt_output
			inc	hl
			jr	disp_msg

disp_msg2:	ld 	a, (hl)
			or	a
			ret	z
			and	 #7F		; no funny chars
			ld 	(hl), a		; update aswell
			call txt_output
			inc	hl
			jr	disp_msg2
			
			
			; cursor copy function for basic 1.0, may remove later if space needed. Now you can replace lowerrom and use basic 1.1
			
get_path:		call	txt_get_cursor	; get cursor pos
			push	hl	; real cursor pos
			pop	bc
			ld	a,25
			cp	c
			jr	nc,not_last_line
			ld	c,25	; no scrolling, please
not_last_line:
			call	txt_place_cursor
inputloop:	
			push	hl
			call	mc_wait_flyback
			call	km_read_char
			pop	hl
			push	hl
			cp	 #F4
			call	z,cursor_up
			cp	 #F5
			call	z,cursor_down
			cp	 #F6
			call	z,cursor_left
			cp	 #F7
			call	z,cursor_right
			cp	 #E0
			jr	nz, not_copykey
			call	copy_char
			pop	de
			ld	d,h
			ld	e,l
			jr	inputloop

not_copykey:	
			cp	 #7F
			jr	nz,not_delkey
			call	del_char
			pop	de
			ld	d,h
			ld	e,l
			jr	inputloop
not_delkey:	
			cp	13
			jr	z,enterkey
			cp	32
			jr	c,not_valid_char
			cp	 #7e
			jr	nc,not_valid_char
			call	key_press
not_valid_char:
			pop	de
			ld	a,d
			cp	h
			call	nz, update_cursor	; txt set cursor
			ld	a,e
			cp	l
			call	nz, update_cursor
			jr	inputloop

enterkey:	
			; add zero terminator
			ld	e,(iy+2)	; filename len (pos)
			ld	d,0
			push	iy		
			add	iy,de
			ld	(iy+3),0	; terminator
			pop	iy
			inc	e
			ld	(iy+2),e	; filename len++
			; remove copy cursor
			pop	de
			push	hl
			call	txt_remove_cursor
			pop	hl
			ld	a,h
			cp	b
			jr	nz,not_same_pos
			ld	a,l
			cp	c
			jr	z,same_pos
not_same_pos:	ld	h,b
			ld	l,c
			call	txt_set_cursor
			call	txt_remove_cursor	;remove real cursor

same_pos:
			ld	a,10
			call	txt_output
			ld	a,13
			call	txt_output
			ret

cursor_up:	push	af
			ld	a,l
			cp	1
			jr	z,top_line
			dec	l
top_line:		pop	af
			ret

cursor_down:	push	af
			ld	a,l
			cp	25
			jr	nc,bottom_line
			inc	l
bottom_line:	pop	af
			ret
cursor_left:	push	af
			ld	a,h
			cp	1
			jr	z,cur1
			dec	h
cur1:		pop	af
			ret
cursor_right:	push	af
			ld	a,(iy+1)	; max column
			cp	h	
			jr	z,max_col
			inc	h
max_col:		pop	af
			ret
update_cursor:
			push	hl
			ld	a,(iy)		; do not remove real cursor if same pos as copy cursor (first run)
			cp	1
			call	z, txt_remove_cursor
			ld	(iy),1
	
			call	txt_set_cursor	; set cursor
			call	txt_place_cursor
			pop	hl
			ret

copy_char:	push	af
			push	hl	; copy cursor position
	
			call	txt_remove_cursor	; remove copy cursor
			call	txt_rd_char	; read char current cursor pos
			push	af
	
			ld	a,(iy+2)	; filename len (pos)
			cp	 #FC
			jr	nc, fndir_max
			
			ld	e,a
			inc	a
			ld	(iy+2),a	; filename len++
			ld	d,0
			pop	af		
			push	iy		
			add	iy,de
			ld	(iy+3),a
			pop	iy
			push	af
fndir_max:	
			; set real cursor pos
			ld	h,b
			ld	l,c
			call	txt_set_cursor
			call	txt_remove_cursor	; remove cursor
			pop	af
			push	bc
			call	txt_wr_char	; print 'copy' char
			pop	bc
			; set new real cursor position
			inc	b
			ld	h,b
			ld	l,c
			call	txt_set_cursor	
			call	txt_place_cursor	; place cursor
	
			pop	hl
			; set back to copy cursor pos
			inc	h	; new pos
			push	hl
			call	txt_set_cursor	; 
			call	txt_place_cursor	; place cursor
			pop	hl
			
			pop	af
			ret
key_press:	
			push	hl
			push	af
			; set real cursor pos
			ld	h,b
			ld	l,c
			call	txt_set_cursor
			call	txt_remove_cursor	; remove cursor
			
	
			
			ld	a,(iy+2)	; filename len (pos)
			cp	 #FC
			jr	nc, fndir_max1
			ld	e,a
			inc	a
			ld	(iy+2),a	; filename len++
			ld	d,0
			pop	af		; character	
			push	iy		
			add	iy,de
			ld	(iy+3),a
			pop	iy
			push	af

fndir_max1:	pop	af

			call	txt_output	; print char
			; set new real cursor position
			inc	b
			ld	h,b
			ld	l,c
			call	txt_set_cursor	
			call	txt_place_cursor	; place cursor
	
			pop	hl
			; set back to copy cursor pos
			push	hl
			call	txt_set_cursor
			pop	hl
			ret


del_char:		push	af
			push	hl
			; set real cursor pos
			ld	h,b
			ld	l,c
			call	txt_set_cursor
			call	txt_remove_cursor	; remove cursor
			ld	a,b
			cp	1
			jr	z,at_start_pos
			dec	b
			ld	h,b
			ld	l,c
			call	txt_set_cursor	; update real cursor pos
			
			ld	a,(iy+2)	; filename len (pos)
			cp	0
			jr	z, at_start_pos
			dec	a
			ld	(iy+2),a
			
at_start_pos:
			ld	a,32
			call	txt_output	; overwrite the char with a space
			; set cursor back
			ld	h,b
			ld	l,c
			call	txt_set_cursor	; update real cursor pos
			call	txt_place_cursor
			pop	hl
			; set back to copy cursor pos
			push	hl
			call	txt_set_cursor	
			pop	hl
	
			pop	af
			ret

mul16:		ld	hl,0
			ld	a,16
mul16Loop:	add	hl,hl
			rl	e
			rl	d
			jp	nc,nomul16
			add	hl,bc
			jp	nc,nomul16
			inc	de
nomul16:
			dec	a
			jp	nz,mul16Loop
			ret

rom_upload:
			cp	2			; 2 arguments?
			jp	nz, bad_args
			ld	iy,(rom_workspace)
				
			; get filename
			
			ld	l,(ix+2)
			ld	h,(ix+3)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			
			; open rom file
			
			ld	a,FA_READ
			call	fopen	; hl = filename, b = len, a = mode
			ld	(iy+127),a	; -1(iy)
			cp	 #FF
			jp	z, romupload_fail
			
			; check if file has amsdos header
			
			ld	hl,128			; size of header
			call	fread
			ld	b,66
			ld	hl,0
			ld	de,rom_response+4
rom_checksum_loop:
			push	bc
			ld	a,(de)
			ld	c,a
			ld	b,0
			inc	de
			add	hl,bc
			pop	bc
			djnz	rom_checksum_loop
			; compare with header checksum
			ld	a,(rom_response+4+67)
			cp	l
			jr	nz,rom_checksum_mismatch
			ld	a,(rom_response+4+68)
			cp	h
			jr	z,rom_checksum_ok
rom_checksum_mismatch:
			; no amsdos header, seek back to offset 0
			ld	a, (iy+127)	; -1(iy)
			ld	hl,0
			call fseek		
			; otherwise skip the header (128 bytes)
			xor	a
			jr	rom_store_start_offset
			
rom_checksum_ok:
			ld	a,128
rom_store_start_offset:			
			ld	-3(iy),a		; store skip offset
			; open m4/romslots.bin... cannot use regular fopen, as it does not allow filename in rom (think its screen ram)
			
			ld	hl, romslots_fn
			ld	c, #80 | FA_READ|FA_WRITE
			ld	a,17
			
			ld	de, C_OPEN
			call	send_command2	; will do cmd(2, DE), size(1, A), mode (1, C) followed by data in HL with A size.
			ld	hl,rom_response+3
			ld	b,(hl)		; fd
			inc	hl
			ld	a,(hl)		; res
			
			cp	0
			jp	nz, romupload_fail_close2
			
			ld	(iy+126),b			; -2(iy)
			; calculate seek offset

			ld	bc, #4000	; rom size
			ld	e,(ix)		; rom slot
			ld	d,0
			call	mul16		; performs DEHL = BC*DE
			
			; perform fseek (32 bit) offset into m4/romslots.bin
			
			ld	(iy),7			; size.. cmd(2) + fd (1) + offset (4)
			ld	(iy+1),C_SEEK		; cmd seek
			ld	(iy+2),C_SEEK>>8	; cmd seek
			ld	a,(iy+126)			;-2(iy)			; file handle
			ld	(iy+3),a			; 
			ld	4(iy),l			; offset
			ld	5(iy),h			; offset
			ld	6(iy),e			; offset
			ld	7(iy),d			; offset
			
			call	send_command_iy
			
			ld	a,(rom_response+3)	; check if seek was OK?
			or	a
			jp	nz, romupload_fail_close1

			
			; get rom file size
			ld	(iy),3			; size, cmd(2) + fd (1)
			ld	(iy+1),C_FSIZE		; cmd size
			ld	(iy+2),C_FSIZE>>8	; cmd size
			ld	a,(iy+127)			; -1(iy)			; file handle
			ld	(iy+3),a
			call	send_command_iy
			
			ld	a,(rom_response+3)
			ld	l,a
			ld	a,(rom_response+4)
			ld	h,a
			ld	c,(iy-3)			; offset into file (past header or not)
			ld	b,0
			or	a
			sbc	hl,bc
			
			; should really check if rom size >  #4000....
			
			; write loop
rom_write_loop:
			
			
			; check if remaining size less than  #FC
				
			ld	a,h
			cp	0
			jr	nz,romw_full_chunk
			ld	a,l
			cp	 #FC
			jr	c,romw_cont
romw_full_chunk:
			ld	a, #FC
romw_cont:
			
			ld	e,a
			
			ld	b,0
			ld	c,a
			or	a
			sbc	hl,bc	; substract chunk size from remaining size
			push	hl
			
			; read chunk size from input file (rom file)
			
			
			ld	(iy+1),C_READ
			ld	(iy+2),C_READ>>8
			ld	a, (iy+127)		; -1(iy)
			ld	(iy+3),a			; fd
			ld	(iy+4),e			; chunk size
			ld	(iy+5), #0		; chunk size
			ld	(iy),5			; packet size, cmd (2), fd (1), size (2)
			call	send_command_iy
			
			ld	a,(rom_response+3)
			or	a
			jr	nz,romupload_fail_close1
			
			; write chunk size to outputfile (romslots.bin)
			ld	a,e
			ld	de, C_WRITE
			ld	hl, rom_response+4	; data read earlier
			ld	c, (iy+126)		;-2(iy)
			call	send_command2	; will do cmd(2, DE), size(1, A), fd (1, C) followed by data in HL with A size.
			pop	hl
			
			; check if there is more data left
			ld	a,h
			or	a
			jr	nz, rom_write_loop
			ld	a,l
			or	a
			jr	nz, rom_write_loop
			
			; rom written to m4/romslots.bin
			
			ld	a,(iy+127)		; -1(iy)			; file handle "rom file"
			call	fclose
			ld	a,(iy+126)		;-2(iy)			; file handle "m4/romslots.bin"
			call	fclose
			
			; now update m4/romconfig.bin
			
			ld	hl, romconfig_fn
			ld	c, #80 | FA_READ|FA_WRITE
			ld	a,18
			ld	de, C_OPEN
			call	send_command2	; will do cmd(2, DE), size(1, A), mode (1, C) followed by data in HL with A size.
			ld	hl,rom_response+3
			ld	b,(hl)		; fd
			inc	hl
			ld	a,(hl)		; res
			
			cp	 #FF
			jp	z, romupload_fail
		
			ld	(iy+127),b		;-1(iy)
		
			ld	bc,33		; rom name (32) + updateflag (1)
			ld	e,(ix)		; rom slot
			ld	d,0
			call	mul16		; performs DEHL = BC*DE
			ld	de,32		; skip header (8*4)
			add	hl,de		; size is less than 16 bit, no worries..
			
			ld	a, (iy+127)	; -1(iy)
			call fseek		; we are now pointing at the updateflag for current rom slot
				
			; set update flag to 2 and name to "rom".
			
			ld	de, C_WRITE
			ld	hl, rom_update_slot	; data read earlier
			ld	c, (iy+127)	; -1(iy)
			ld	a, 5
			call	send_command2	; will do cmd(2, DE), size(1, A), fd (1, C) followed by data in HL with A size.
			
			ld	a, (iy+127)	;-1(iy)
			call	fclose
			
			scf
			sbc	a,a
			ret			
			
		
romupload_fail_close0:
			pop	hl			
romupload_fail_close1:
			ld	a,(iy+126)			;-2(iy)			; file handle "m4/romslots.bin"
			call	fclose
romupload_fail_close2:			
			ld	a,(iy+127)			;-1(iy)			; file handle "rom file"
			call	fclose
romupload_fail:
			; disp some error message
			ld	hl,fail_msg
			call	disp_msg
			or	a
			ret	
rom_update_slot:
			db  2
			db "ROM"
			db	0

rom_set:
			cp	2			; 2 arguments?
			jp	nz, bad_args
			ld	iy,(rom_workspace)
				
			; get rom status
			
			; get rom slot
			
			ld	hl, romconfig_fn
			ld	c, #80 | FA_READ|FA_WRITE
			ld	a,18
			ld	de, C_OPEN
			call	send_command2	; will do cmd(2, DE), size(1, A), mode (1, C) followed by data in HL with A size.
			ld	hl,rom_response+3
			ld	b,(hl)		; fd
			inc	hl
			ld	a,(hl)		; res
			
			cp	 #FF
			jp	z, romset_fail
		
			ld	(iy+127),b		;-1(iy)
		
			ld	bc,33		; rom name (32) + updateflag (1)
			ld	e,(ix+2)		; rom slot
			ld	d,0
			call	mul16		; performs DEHL = BC*DE
			ld	de,32		; skip header (8*4)
			add	hl,de		; size is less than 16 bit, no worries..
			
			ld	a, (iy+127)	; -1(iy)
			call fseek		; we are now pointing at the updateflag for current rom slot
				
			; set update flag to 0 or 1
			
			ld	de, C_WRITE
			ld	hl, data_0	
			ld	c, (ix+0)		; status
			ld	b, 0
			add	hl,bc
			ld	c, (iy+127)	;-1(iy)
			ld	a, 1
			call	send_command2	; will do cmd(2, DE), size(1, A), fd (1, C) followed by data in HL with A size.
			
			ld	a, (iy+127)	; -1(iy)
			call	fclose
			
			scf
			sbc	a,a
			ret			
romset_fail:
			or	a
			ret
rom_update:
			ld	iy,(rom_workspace)
			ld	(iy+1),C_ROMSUPDATE
			ld	(iy+2),C_ROMSUPDATE>>8
			ld	(iy),2			; packet size, cmd (2)
			call	send_command_iy
			scf
			sbc	a,a
			ret	
wifi_power:	ld	iy,(rom_workspace)
			ld	a, (ix+0)		; status
			ld	(iy+1),C_WIFIPOW
			ld	(iy+2),C_WIFIPOW>>8
			ld	(iy+3),a
			ld	(iy),3			; packet size, cmd (2), 0=off, 1 = on
			call	send_command_iy
			ret

catalog_buffer	.equ	 #8000
inbuffer		.equ	 #8800
outbuffer		.equ	 #9000
fileheadin	.equ	 #9800
fileheadout	.equ	 #9802
filesize		.equ	 #9804
filename		.equ	 #9906
filename2		.equ	 #9986
header		.equ	 #9A06
drive_vectors	.equ	 #9A86	; to  #9AB6


fcp:		
			cp	2			; 2 arguments?	
			jr	z,got_args
			ld	hl,txt_copy_err
			jp	disp_msg
got_args:			
			; get 1st string (dest filename)
			ld	l,(ix)
			ld	h,(ix+1)
			ld	c,(hl)	; string len
			ld	b,0
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			ld	de,filename2
			ldir
			xor	a
			ld	(de),a
			; get 2nd string (src filename)
		
			ld	l,(ix+2)
			ld	h,(ix+3)
			ld	c,(hl)
			ld	b,0
			inc	hl
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			ex	de,hl
			ld	de,filename
			ldir
			xor	a
			ld	(de),a
			push	iy
			
			ld	hl,(amsdos_inheader)
			ld	de,- #51
			add	hl,de
			ld	a,(hl)	; amsdos drive
			push	hl
			push	af
			ld	hl, #BC77
			ld	de,drive_vectors
			ld	bc,48
			ldir
			
			call	do_copy
			ld	hl,drive_vectors
			ld	de, #BC77
			ld	bc,48
			ldir
			pop	af
			pop	hl
			ld	(hl),a
			pop	iy
			xor	a
			ret
do_copy:
			ld	hl,filename2
			call	get_drive
			sla	a
			sla 	a
			ld	c,a
			
			; check if there is a destination filename
			push	hl
			call	strlen
			cp	2
			jr	nz, got_dest_fn
			inc	hl
			ld	a,(hl)
			cp	':'		;  is it just a drive letter?
			jr	nz, got_dest_fn
			inc	hl
			ex	de,hl	
			
			ld	hl,filename
			inc	hl
			ld	a,(hl)
			dec	hl
			cp	':'
			jr	nz, copy_fn
			inc	hl
			inc	hl
copy_fn:
			call	strlen
			push	bc
			inc	a
			ld	c,a
			ld	b,0
			ldir				; filename1 past ?: to filename2 past ?:
			pop	bc			; c contains 'dest drive'
got_dest_fn:	pop	de			; filename2
			ld	hl,filename
			call	get_drive
			or	c
			call	set_drives
			; check if wildcard in src file name
			ld	hl,filename
			inc	hl
			ld	a,(hl)
			dec	hl
			cp	':'
			jr	nz,no_drv_letter
			ld	a,(hl)
			and	 #DF
			cp	'A'
			call	z,set_drvA
			
			cp	'B'
			call	z,set_drvB
			inc	hl
			inc	hl
no_drv_letter:	
			ld	a,(hl)
			cp	'*'
			jp	nz,no_wildcard
			push	hl			; filename1
			;ld	a,1
			;call	bios_set_message
			ld	de,catalog_buffer
			push	de			; cas buffer
			call	cas_catalog
			pop	hl			; cas buffer
			pop	de			; filename1
			;jp	c, copy_error
			
copy_files:	push	hl		; catalog buffer
			ld	a,(hl)
			cp	 #FF
			jr	z, valid_file
			pop	hl
			ret	
valid_file:			
			inc	hl
			ld	bc,8
			push	de		; filename1
			ldir
			ld	a, #2e
			ld	(de),a
			inc	de
			ld	bc,3
			ldir
			xor	a
			ld	(de),a
			pop	de		; filename 1
			ld	hl,filename2
			inc	hl
			ld	a,(hl)
			dec	hl
			cp	':'
			jr	nz,no_drvl
			inc	hl
			inc	hl
no_drvl:		ex	de,hl
			ld	bc,14
			push	hl
			ldir			; copy filename1+?: to filename2+?:
			ld	hl,filename
			ld	de,filename2
			call	copy_file2
			pop	de		; filename1+?:
			pop	hl		; ptr cas_catalog buffer
			ld	bc,14
			add	hl,bc
			jp	copy_files
no_wildcard:
			ld	hl,filename
			ld	de,filename2
			call	copy_file2
			ret

;	input 
;	HL = filename
; 	output
;	A = drive 0/1/2
;    HL = filename (after T if stated)


get_drive:	push	bc
			ld	c,0			; drive 'sd'
			inc	hl
			ld	a,(hl)
			dec	hl
			cp	':'
			jr	nz, get_drive_exit
			ld	a,(hl)
			and	 #DF 
			cp	'B'
			jr	nz, not_b
			ld	c,2			; drive b
			jr	get_drive_exit
not_b:		cp	'A'
			jr	nz, not_a
			ld	c,1			; drive a
			jr	get_drive_exit
not_a:		cp	'C'
			jr	nz, not_c		; drive C (SD)
			ld	c,0
			jr 	get_drive_exit
not_c:		cp	'T'			; drive T (TAPE)
			jr	nz, get_drive_exit
			ld	c,3
get_drive_exit:	
		
			ld	a,c
			pop	bc
			ret
			; input A :
			; 0000 = SD->SD
			; 0001 A->SD
			; 0010 B->SD
			; 0011 TAPE->SD 
			; 0100  SD->A
			; 0101  A->A
			; 0110  B->A
			; 0111 TAPE->A  (not supported)
			; 1000  SD->B
			; 1001  A->B
			; 1010  B->B
			; 1011  TAPE->B  (not supported)
			; 1100  SD->TAPE  
			; 1101  A->TAPE  (not supported)
			; 1110  B->TAPE  (not supported)
			; 1111  TAPE->TAPE  (not supported)
set_drives:	cp	0
			jp	z, set_SDdrive
			cp	1
			jr	nz, not_ASD
			call	set_amsdos_functions
			call	set_drvA
			jp	set_SDdrive_out
not_ASD:		
			cp	2
			jr	nz,not_BSD
			call	set_amsdos_functions
			call	set_drvB
			jp	set_SDdrive_out

not_BSD:		cp	3
			jr	nz,not_TSD
			call	tape
			jp	set_SDdrive_out
not_TSD:		cp	4
			jr	nz, not_SDA
			call	set_amsdos_functions
			call	set_drvA
			jp	set_SDdrive_in
not_SDA:		cp	5
			jr	nz, not_AA
			call	set_amsdos_functions
			jp	drvA
not_AA:		cp	6
			jp	nz, not_BA
			call	set_amsdos_functions
			jp	drvB
not_BA:		cp	7
			jr	nz, not_TA
			call	set_amsdos_functions
			call	set_drvA
			jp	tape		; _in
not_TA:		cp	8
			jr	nz, notSDB
			call	set_amsdos_functions
			call	set_drvB
			jp	set_SDdrive_in
notSDB:		cp	9
			jr	nz, not_AB
			call	set_amsdos_functions
			jp	drvA
not_AB:		cp	10
			jr	nz, not_BB
			call	set_amsdos_functions
			jp	drvB
not_BB:		cp	11
			jr	nz, not_TB
			call	set_amsdos_functions
			call	set_drvB
			jp	tape		;_in
not_TB:		cp	12			
			jr	nz, not_SDT
			call	set_SDdrive_in
			jp	tape		; _out
not_SDT:		cp	13
			jr	nz, notAT
			call	set_amsdos_functions
			call	set_drvA
			jp	tape		; _out
notAT:		cp	14
			jr	nz,notBT
			call	set_amsdos_functions
			call	set_drvB
			jp	tape		;_out
notBT:		cp	15
			jp	z,tape
			ret
			
			; hl = src filename
			; de = dest filename
copy_file2:	push	hl
			ld	hl,txt_copying
			call	disp_msg
			ld	hl,filename
			call	disp_msg2
			ld	hl,txt_to
			call	disp_msg
			ld	hl,filename2
			call	disp_msg2
			call	crlf
			pop	hl
			push	de
			call	strlen
			ld	b,a
			ld	de,inbuffer
			
			call cas_in_open
			jr	c,cas_in_ok
			pop	de
			jp	copy_error
cas_in_ok:			
			push	bc
			
			push	hl
			ld	de,header		
			ld	bc,69
			ldir	
			; copy remains from "buffer area"
			ld	hl,(amsdos_inheader)
			ld	bc, #E4- #55+69
			add	hl,bc
			ld	bc,128-69
			ldir		
			pop	hl
			push	hl
			push	af
			ld	de,18
			and	 #FE
			add	hl,de
			ld	(hl),a		; remove P flag if present, to avoid "decryption"
			pop	af
			pop	hl
			ld	de,-5
			add	hl,de
			ld	(fileheadin),hl
			
			pop	hl
			ld	hl,(header+24)
			ld	(filesize),hl
			pop	hl			; dest filename
			
			push	af			; filetype
			call	strlen
			ld	b,a
			ld	de,outbuffer
			call	cas_out_open
			jr	c,openout_ok
			pop	af
			jp	copy_error		
openout_ok:
			ld	de,-5
			add	hl,de
			ld (fileheadout),hl
			
			pop	af
		
			cp	 #16
			jr	nz, has_header
headerless:			
			call	cas_in_char
			jp	c, copy_more
			cp	 #f
			jp	z,copy_done
copy_more:	call	cas_out_char
			jr	headerless
has_header:	call	cas_in_char		; fill 2k buffer
			
			ld	hl,header
			ld	a,(hl)
			call cas_out_char
			ld	de,outbuffer
			ld	bc,128
			ldir
			ld	hl,inbuffer
			ld	bc,2048-128
			ldir
		
			; check if remains of file is less than 2k - 128
			ld	hl,(filesize)
			ld	de,128

			add	hl,de
			ld	bc, #F800			; - #800
			push	hl
			add	hl,bc				; and substract chunksize
			pop	de
			jr	c, cfull_chunk
			ld	c,e
			ld	b,d
			;dec	bc					; get rid of extra char
			jr	cont1
			
cfull_chunk:	ld	bc, #800
			jr	cont1

cont1:		ld	(filesize),hl
						
			; increase ptr to write out 2k buffer (or filesize) at once
			
			ld	iy,(fileheadout)
			ld	(iy),1
			
			ld	l,(iy+1)		; get buffer
			ld	h,(iy+2)
			add	hl,bc
			ld	(iy+3),l		; current pos is end of buffer
			ld	(iy+4),h
			ld	(iy+24),c		; size is 2k too
			ld	(iy+25),b
			; write 2k block
			call cas_out_char
			ld	a,8
			cp	b			; was it 2k
			jp	nz, _copy_done
			
			; copy remaining bytes of input buffer to output buffer
copy_loop:		
			ld	hl,inbuffer+2048-128
			ld	de,outbuffer
			ld	bc,128
			ldir
			ld	iy,(fileheadin)
			
			ld	hl,(filesize)
			ld	bc, #F800			; - #800
			push	hl
			add	hl,bc			; and substract chunksize
			pop	de
			jr	c, cfull_chunk1
			ld	c,e
			ld	b,d
			jr	cont2
			
cfull_chunk1:	ld	bc, #800

		
			; re-fill input buffer
		
cont2:		ld	(filesize),hl
			
			ld	l,(iy+1)
			ld	h,(iy+2)
			
			add	hl,bc
			ld	(iy+3),l		; adjust current pos to end of buffer
			ld	(iy+4),h
			ld	(iy+24),0	; clear buffer remains
			ld	(iy+25),0
			call	cas_in_char		; fill 2k buffer
			jr	c,read_in_ok
			cp	 #1A
			jr	z,read_in_ok
			;jp	copy_error
read_in_ok:
			push	bc
			ld	hl,inbuffer
			ld	de,outbuffer+128
			ld	bc,2048-128
			ldir
			pop	bc
			
			; write 2k buf
			ld	iy,(fileheadout)
			ld	(iy),1
			
			ld	l,(iy+1)		; get buffer
			ld	h,(iy+2)
			add	hl,bc
			ld	(iy+3),l		; current pos is end of buffer
			ld	(iy+4),h
			ld	(iy+24),c		; size is 2k too
			ld	(iy+25),b
			
			call cas_out_char
			;jr	nc, copy_error
			ld	a,8
			cp	b			; was it 2k
			jr	z,copy_loop
_copy_done:			
			ld	l,(iy+3)		; get buffer
			ld	h,(iy+4)
			dec	hl			; get rid of extra char
			ld	(iy+3),l		
			ld	(iy+4),h	
			
copy_done:		 		
			call cas_in_close
			call cas_out_close
			ret
copy_error:	ld	hl,txt_copy_err
			call	disp_msg
			jp	copy_done

disp_hex:		ld	b,a
			srl	a
			srl	a
			srl	a
			srl	a
			add	a, #90
			daa
			adc	a, #40
			daa
			call	txt_output
			ld	a,b
			and	 #0f
			add	a, #90
			daa
			adc	a, #40
			daa
			jp	txt_output

;---------------------------------------
; Helper functions


; -- added Prodatron
			
hsend:        		;A=source bank, HL=source address, D-1,E=length, IYL=network daemon bank, IX=return address, BC=7F00
    			out	(c),a			;switch to application bank
    			ld	b, #fe
hsend_loop:
			inc	b
			outi				;copy data from application memory to m4 dataport
			dec	e
			jr	nz,hsend_loop
			dec	d
			jr	nz,hsend_loop
			ld	b, #7f
			db  #fd
			ld	a,l
			out	(c),a			;switch back to network daemon bank
			jp	(ix)			;return to network daemon

hreceive:     	;A=destination bank, DE=destination address, IYH,C=length, HL=M4 buffer, IYL=network daemon bank, IX=return address, B=7F 
			out	(c),a			;switch to application bank
			db	 #fd
			ld	b,h
			ldir				;copy data from m4 buffer to application memory
			ld	b, #7f
			db	 #fd
			ld	a,l
			out	(c),a			;switch back to network daemon bank
			jp	(ix)		;return to network daemon 			


; --- added SOS


UDIR:		ld a,(UDIR_RAM_Address)
			cp 0
			ret z
			; reset dir count
			ld	iy,(rom_workspace)
			ld	(iy+1),C_DIRSETARGS
			ld	(iy+2),C_DIRSETARGS>>8
			ld	(iy), 3
			ld	(iy+3),0
			call	send_command_iy
NextGetEntry:
			ld	iy,(rom_workspace)
			ld	(iy),2
			ld	(iy+1),C_READDIR
			ld	(iy+2),C_READDIR>>8
			call	send_command_iy
		
			ld	hl,rom_response
			ld	a,(hl)
			cp	2
			jp	z,finished

	
			inc hl
			inc hl
			inc hl
			ld a,(hl)
			cp  #3E ;">"
			jr nz,FileFound
			inc hl
			ld bc,16
			jr CopyFileDir
;--------------------------------------
FileFound:
			ld bc,12
CopyFileDir:	
	; RAM:
	; 464     	   664/6128
	; aca4-ada5    ac8a-ad8b        *** ASCII-Puffer *** (INPUT, LIST)
			ld de, #AC8B
			ldir
			push af
			ld a,0
			ld (de),a
			pop af
			cp  #3E ;">"
			jp z,directoryfound
			push hl
			pop ix
			ld hl,0	
			ld a,(ix+1)
			cp 32 ; " "
			jr z,Space_Det1
			sub 48 ;sub "0"
			ld b,0
			ld c,a
			ld de,100
			call mul16 ; This routine performs the operation DEHL=BC*DE
Space_Det1:	
			push hl
			ld a,(ix+2)
			cp 32 ; " "
			jr z,Space_Det2
			sub 48 ;sub "0"
			ld b,0
			ld c,a
			ld de,10
			call mul16 ; This routine performs the operation DEHL=BC*DE

Space_Det2:	
			pop de
			add hl,de
			
			ld a,(ix+3)
			cp 32 ; " "
			jr z,Space_Det3
			sub 48 ;sub "0"
			ld b,0
			ld c,a
			add hl,bc
			ex de,hl
Space_Det3:	
	
; Convert KB-Value to Bytes (10* Shift right) or *1024
		ld bc,1024
			call mul16 ; performs DEHL = BC*DE
			ex de,hl
			ld ix, #AC8A +  #100 - 4   ; Firmware 1.1
			ld a,h
			ld (ix+3),a
			ld a,l
			ld (ix+2),a
			ld a,d
			ld (ix+1),a
			ld a,e
			ld (ix),a


			ld b,0
			jr goon
directoryfound:
			ld ix, #AC8A +  #100 - 4   ; Firmware 1.1
			ld (ix+3),0
			ld (ix+2),0	
			ld (ix+1),0
			ld (ix),0
			ld b,1
	
goon:
			; * HL = Location of null terminated file/folder name string
			; *  B = File flag (1 = directory, 0 = file)
			; At the same time, if you need it, you can get the size in bytes of the file. This is located in:
			; * FILESIZE_CACHE_LSW          EQU BASIC_INPUT_AREA + start_100 - 4
			; * FILESIZE_CACHE_MSW          EQU BASIC_INPUT_AREA + start_100 - 2 
			; The only bad thing is BASIC_INPUT_AREA is in start_AC8A in firmware 1.1, but it's in ACA4 in firmware 1.0 (CPC 464 with original rom).
			ld hl, #AC8B
			call UDIR_RAM_Address
			jp NextGetEntry
	
finished:
			; ClearMemory
			ld de, #AC8B
			push de
			pop hl
			inc de
			ld a,0
			ld (hl),a
			ld bc,12
			ldir
	
			scf
			sbc	a,a
			ret

GETPATH:
			; IN: Normal behavour of RSX, OR A=255->DE=Buffferadress for Path
			push af
			cp  #FF
			jr z,GetPath2
			ld de, #AC8B   ; ACMEDOS-Bug, uses &AC8B for BASIC 1.0
GetPath2:	
			push de		
	
			ld	iy,(rom_workspace)
			ld	(iy+0),2
			ld	(iy+1),C_GETPATH
			ld	(iy+2),C_GETPATH>>8
			call	send_command_iy
			
			ld	hl,rom_response+3			
			ld a,(rom_response)
			sub 3 
	
			
			; RAM:
			; 464     	   664/6128
			; ac80-ac91    ac66-ac77        EVERY/AFTER ,2 GOSUB
			; ac92-aca3    ac78-ac89        EVERY/AFTER ,3 GOSUB
			; aca4-ada5    ac8a-ad8b        *** ASCII-Puffer *** (INPUT, LIST)
			
			pop de
	
			;	ld de, #AC8B   ; ACMEDOS-Bug, uses &AC8B for BASIC 1.0
			ld b,0
			ld c,a
	
			; ignore first "/"
			inc hl
			dec bc
			push de
			ld a,c
			cp 0
			jr z,GetPath3
			ldir
GetPath3:
			
			
			ld a,00
			ld (de),a
			
			pop hl
			pop af
			cp  #FF
			jr z,finished_GETPATH ; not called from Basic, so don't print path

PrintPath:
			ld a,(hl)
			cp 0
			jr z,finished_GETPATH
			inc hl
			call txt_output
			jr PrintPath
finished_GETPATH:

			scf
			sbc	a,a
			ret
GetPathEnd:

; ----------LONGNAME
LongName:
			; IN: Normal behavour of RSX, OR A=255->DE=Buffferadress for Path
			cp	0
			jp	z,bad_args
			push af
			push de
			ld	iy,(rom_workspace)
			; get string
			ld	l,(ix)
			ld	h,1(IX)
			ld	b,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl
			
			push	iy
			ld	(iy+1),C_FSTAT
			ld	(iy+2),C_FSTAT>>8
			pop	de
			inc	de
			inc	de
			inc	de
			call	strcpy
			add	a,2
			ld	(iy),a
			call	send_command_iy
			
			ld	hl,rom_response+3
			ld	a,(hl)
			cp	0
			jr	z,LongName_ok
			; show error message
			pop de
			pop af
			cp  #ff
			jr z,LongNameExit
			ld	hl,rom_response+4
			call	disp_msg
LongNameExit:   			
   			scf
			sbc	a,a
			ret
;a4e8
;af95 nein
	
LongName_ok:
			pop de
			pop af
			ld hl,rom_response+23+3
			cp  #FF
			jr nz,PrintFileDirLongname
LongName_CopyName:	
			ld a,(hl)
			ld (de),a
			cp 0
			jr z,LongNameExit
			inc hl
			inc de
			jr LongName_CopyName
			
	
PrintFileDirLongname:
			ld a,(hl)
			cp 0
			jr z,LongNameExit
			inc hl
			call txt_output
			jr PrintFileDirLongname

; --- EOF added by SOS
dispdec:		ld	e,0
			ld	a,(hl)
			ld	l,a
			ld	h,0
			ld	bc,-100
			call	Num1
			cp	'0'
			jr	nz,notlead0
			ld	e,1
notlead0:		call	nz,txt_output
			ld	c,-10
			call	Num1
			cp	'0'
			jr	z, lead0_2
			call	txt_output
lead0_2_cont:	ld	c,b
			call	Num1
			jp	txt_output
			
Num1:		ld	a,'0'-1
Num2:		inc	a
			add	hl,bc
			jr	c,Num2
			sbc	hl,bc
			ret
lead0_2:
			ld	d,a
			xor	a
			cp	e
			ld	a,d
			call	z,txt_output
			jr	lead0_2_cont
						
			

crlf:		ld	a,10
			call	txt_output
			ld	a,13
			jp	txt_output	

			; get amsdos table
			
			; -- hardcoded for AMSDOS v0.5 / v0.7 or PARADOS for now
			
			; b = func num
get_amsdos_ptr:
			ld	a,(amsdos_ver)
			ld	hl,amsdos_table05
			cp	5
			jr	z,isv05
			cp	7
			jr	nz,no_amsdos
			ld	hl,amsdos_table07
isv05:		
funcloop:		inc	hl
			inc	hl
			djnz	funcloop
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
			ld	a,h
			ret
no_amsdos:	xor	a
			ret
; |DISC command

			
disc:		push	hl
			push	bc
			push	af
			
			ld	a,(amsdos_ver)
			cp	0
			jr	z, no_drive_restore
			
			; restore amsdos drive info
			
			push	de
			ld	hl,amsdos_default_drive
			ld	de,( #BE7D)
			ldi
			ldi
			ldi
			pop	de
no_drive_restore:			
			ld	b,1			; function 

pass_to_amsdos:
			call	get_amsdos_ptr
			cp	0
			jp	nz,jumper
			; check if amsdos present at all, if not |disc is same as |sd
			ld	a,(amsdos_ver)
			cp	0
			jr	nz, m4pass
			call	set_SDdrive
			
m4pass:		pop	af
			pop	bc
			pop	hl
			ret

			; |TAPE

tape:		push	hl
			push	bc
			push	af
			
			; SD mode?
			ld	a,( #BC78)
			cp	 #A4
			jr	nz,amsdos_mode
			
			; only copy vectors if not present amsdos, otherwise let amsdos copy the vectors
			ld	a,(amsdos_ver)
			cp	0
			jr	nz, amsdos_mode
			ld	hl,tape_functions			
			ld	de, #bc77
			ld	bc,48
			ldir
			jp	m4pass
amsdos_mode:			
			ld	b,4
			jp	pass_to_amsdos


			; |A
			
drvA:		push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass
			
			ld	b,7
			jp	pass_to_amsdos

			; |B
			
drvB:		push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass
			
			ld	b,8
			jp	pass_to_amsdos

drive:		push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass
			
			ld	b,9
			jp	pass_to_amsdos

user:		push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass	; todo
			
			ld	b,10
			jp	pass_to_amsdos
						

set_message:	push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass
			
			ld	b,14
			jp	pass_to_amsdos

setup_disc:	push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass	; todo
			
			ld	b,15
			jp	pass_to_amsdos

select_format:	push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass	; todo
			
			ld	b,16
			jp	pass_to_amsdos
										
format_track:	push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass	; todo
			
			ld	b,19
			jp	pass_to_amsdos

move_track:	push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass	; todo
			
			ld	b,20
			jp	pass_to_amsdos		

get_dr_status:	push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	b,21
			ld	a,( #BC78)
			cp	 #A4
			;jp	z,m4pass	; todo
			jp	nz, pass_to_amsdos
			pop	af
			pop	bc
			pop	hl
			ld	a, #20
			scf
			ret
			
			
			
set_retry_cnt:	push	hl
			push	bc
			push	af
			
			; if SD mode ignore
			ld	a,( #BC78)
			cp	 #A4
			jp	z,m4pass	; todo
			
			ld	b,22
			jp	pass_to_amsdos
												
jumper:		di
			ld	a,(basic_ver)	; version
			cp	0
			jr	nz, not_basic10
			ld	a,(amsdos_rom_num)
			ld	( #B1A8),a
			jr	jumper_cont
not_basic10:
			ld	a,(amsdos_rom_num)
			ld	( #B8D6),a
jumper_cont:			
			ld	(iy), #ED	; out (c),a
			ld	(iy+1), #79
			ld	(iy+2), #F1	; pop af
			ld	(iy+3), #C1	; pop bc
			ld	(iy+4), #E1	; pop hl
			ld	(iy+5), #FB	; ei
			ld	(iy+6), #c3	; jump
			ld	(iy+7),l		; addr
			ld	(iy+8),h		; addr
			push	iy
			pop	hl
			ld	iy,( #BE7D)	; Amsdos workspace
			ld	bc, #DF00
			jp	(hl)			; jump to ram
set_amsdos_functions:
			push	hl
			push	de
			push	bc
			ld	hl,tape_functions			
			ld	de, #bc77
			ld	bc,48
			ldir
			pop	bc
			pop	de
			pop	hl
			ret
set_drvA:		push	af
			push	hl
			push	bc
			ld	hl,( #BE7D)
			ld	(hl),0
			pop	bc
			pop	hl
			pop	af
			ret			
set_drvB:		push	af
			push	hl
			push	bc
			ld	hl,( #BE7D)
			ld	(hl),1
			pop	bc
			pop	hl
			pop	af
			ret						

m4help:		cp	1
			jr	nz, dispromlist
			ld	hl,helprom
			ld	de,(rom_workspace)
			ld	bc,helprom_end-helprom
			push	de
			ldir
			ld	a,(ix+0)		; status
			ret				; return to stack DE
			
dispromlist:	ld	hl,help
			ld	de,(rom_workspace)
			ld	bc,help_end-help
			push	de
			ldir
			ret
	

		
help:		xor	a
			ld	c,a
			push	af
			call	kl_rom_select
			pop	af
			push	bc
			ld	c,a
			call	scr_get_mode
			ld	de, #3030	; '0' , '0'
			
			ld	b,20
			cp	0
			jr	z,disphelp
			ld	b,40
			cp	1
			jr	z,disphelp
			ld	b,80
disphelp:			
			ld	a,c
			ld	c,0
			
helploop:		push	af
			push	bc
			ld	c,a
			call	kl_rom_select
			pop	bc
			ld	hl,( #C004)
			ld	a,d
			cp	48
			jr	nz,notlead0as
			ld	a,32
notlead0as:
			call	txt_output
			ld	a,e
			call	txt_output
			ld	a,32
			call	txt_output
disprname:		
			ld	a,(hl)		; get rom name
			inc	hl
			push	af
			and	 #7F
			cp	32
			call	nc, txt_output

			pop	af
			bit	7,a
			jr	z, disprname
			ld	a,20
			add	c
			cp	b
			jr	c, nextcolumn0
			ld	c,0
			ld	a,10
			call	txt_output
			ld	a,13
			call	txt_output
			jr	norom
nextcolumn0:		
			push	hl
			ld	c,a
			call	txt_set_column
			pop	hl
norom:		ld	a,e
			cp	57
			jr	nc,next_digit
			inc	e
			jr	lower9
next_digit:	ld	e,'0'
			inc	d
lower9:
			pop	af
			inc	a
			cp	32
			jr	nz,helploop
			pop	bc
			ld	a,b
			call	kl_rom_select
			jp	kl_rom_restore
help_end:
			
			; |m4help,romnum

helprom:		ld	c,a
			call	kl_rom_select
			push	bc
			; display ROM name first
			ld	hl,( #C004)
rname:		ld	a,(hl)
			inc	hl
			push	af
			and	 #7F
			call	txt_output
			pop	af
			bit	7,a
			jr	z, rname
			ld	a,10
			call	txt_output
			ld	a,13
			call	txt_output
			call	scr_get_mode			; get screen mode.
			ld	b,20
			cp	0
			jr	z,m4helploop
			ld	b,40
			cp	1
			jr	z,m4helploop
			ld	b,80

			ld	d,0
m4helploop:	ld	a,(hl)
			cp	0
			jr	z, last_rsx
			inc	hl
			
			push	af
			and	 #7F
			cp	32
			call	nc, txt_output

			pop	af
			bit	7,a
			jr	z, m4helploop
			and	 #7F
			cp	32
			jr	c,m4helploop

			ld	a,20
			add	d
			cp	b
			jr	c, nextcolumn
			ld	d,0
			ld	a,10
			call	txt_output
			ld	a,13
			call	txt_output
			jr	m4helploop
nextcolumn:	push	hl
			ld	d,a
			call	txt_set_column
			pop	hl
			jr	m4helploop
last_rsx:
			ld	a,10
			call	txt_output
			ld	a,13
			call	txt_output
			pop	bc
			ld	a,b
			call	kl_rom_select
			jp	kl_rom_restore
helprom_end:
			; ------------------------- SNA - Run snapshot file
			
snaload:		cp	1
			jp	nz, sna_error
			; get string
			ld	l,(ix)
			ld	h,(ix+1)
			ld	a,(hl)	; string len
			inc	hl
			ld	e,(hl)	; string ptr lo
			inc	hl
			ld	d,(hl)	; string ptr hi
			ex	de,hl

snaload_str_hl:
			add	3
			ld	c,FA_READ| #80
			ld	de, C_OPEN
			call	send_command2
			ld	hl,rom_response+3
			ld	b,(hl)		; fd
			inc	hl
			ld	a,(hl)		; res
			cp	0
			jp	nz, sna_error
			ld	a,b
			
			; read sna header
			
			ld	iy,(rom_workspace)
			ld	(iy),5				; packet size, cmd (2), fd (1), size (2)
			ld	(iy+1),C_READ
			ld	(iy+2),C_READ>>8
			ld	(iy+3),a				; fd
			
			ld	(iy+4),0				; chunk size low
			ld	(iy+5), #1			; chunk size high
			call	send_command_iy	; send read command packet
			ld	hl,rom_response+3	; src buffer
			ld	a,(hl)			; check result
			cp	0
			jp	nz, sna_error
			inc	hl
		
			
		
			; check if valid string
			
			push	hl
			ld	de,txt_sna_id
			ld	b,8
			call	strncmp
			pop	hl
			jr	z, valid_sna
			ld	hl,txt_sna_err
			jp	disp_msg
				
valid_sna:	

		
			di
			
			;  and copy to snamem,  #100 bytes
			
			
			ld	bc,DATAPORT				; data out port
			out (c),c
			ld	de,C_ROMCP
			out	(c),e						; command lo
			out	(c),d						; command	hi
			ld	de,snamem
			out	(c),e						; rom dest addr lo
			out	(c),d						; rom dest addr hi
			xor	a
			out	(c),a						; src rom bank (0 = m4)
			
			out	(c),l						; rom src addr lo
			out	(c),h						; rom src addr hi
			xor	a							; dest rom bank (0 = m4)
			out	(c),a
			
			ld	de, #100
			out	(c),e						; size lo
			out	(c),d						; size hi
			ld	bc,ACKPORT
			out (c),c							; tell M4 that command has been send
		
			; check if compressed
			ld 	a,(snamem+ #6B)
			cp	0
			jr	nz, not_comp_sna
			
			; decompress sna to m4/tmp.bin
			
			ld	iy,(rom_workspace)
			ld	(iy),3				; packet size, cmd (2), fd (1), size (2)
			ld	(iy+1),C_SNAFLAT
			ld	(iy+2),C_SNAFLAT>>8
			;ld	a,(iy+3)				; fd
			
			call	send_command_iy	; send read command packet
			
			ld	hl, rom_response+3				; KB of decompressed sna
			ld	bc,DATAPORT					; data out port
			out (c),c
			ld	de,C_ROMCP
			out	(c),e						; command lo
			out	(c),d						; command	hi
			ld	de,snamem+ #6B
			out	(c),e						; rom dest addr lo
			out	(c),d						; rom dest addr hi
			xor	a
			out	(c),a						; src rom bank (0 = m4)
			
			out	(c),l						; rom src addr lo
			out	(c),h						; rom src addr hi
			xor	a							; dest rom bank (0 = m4)
			out	(c),a
			
			ld	de, #1
			out	(c),e						; size lo
			out	(c),d						; size hi
			ld	bc,ACKPORT
			out (c),c							; tell M4 that command has been send
			
			
not_comp_sna:			
			
			; prepare a read packet & close packet 
			
			ld	a,(iy+3)				; restore fd
			
			ld	(iy),5				; packet size, cmd (2), fd (1), size (2)
			ld	(iy+1),C_READ
			ld	(iy+2),C_READ>>8
			;ld	(iy+3),a				; fd
			ld	(iy+4),0				; chunk size low
			ld	(iy+5), #8			; chunk size high
			
			ld	(iy+6),3				; size - cmd(2) + fd(1)
			ld	(iy+7),C_CLOSE			; close cmd
			ld	(iy+8),C_CLOSE>>		; close cmd
			ld	(iy+9),a				; fd
			
			
			ld	hl,(rom_workspace)
			ld	de,m4_workspace
			ld	bc,10
			call	 rom_write			; copy it into our rom, so we dont need RAM to read the .sna file
	
			; build exit & jump memory
			
			ld	(iy), #ED			; out (c),c
			ld	(iy+1), #49
			ld	(iy+2), #F1			; pop af
			ld	hl,(snamem+ #21)		; get SP
			ld	(iy+3), #1			; ld sp,xxxx
			ld	(iy+4),l
			ld	(iy+5),h
			ld	hl,(snamem+ #13)		; get bc
			ld	(iy+6), #01			; ld bc,xxxx
			ld	(iy+7),l
			ld	(iy+8),h
			ld	(iy+9), #FB			; ei
			ld	a,(snamem+ #1B)
			and	1
			jr	nz,int_en
			ld	(iy+9), #F3			; di
int_en:
			ld	hl,(snamem+ #23)		; get PC
			ld	(iy+10), #C3			; jp xxxx
			ld	(iy+11),l
			ld	(iy+12),h
			ld	hl,(snamem+ #11)		; get AF
			ld	(iy+13),l
			ld	(iy+14),h
			
			ld	hl,(rom_workspace)
			ld	de,sna_jumper
			ld	bc,15
			call	 rom_write	
			
			; read first 64 KB data
			
		
			ld	a,65536/2048
			ld	de,0
sna_read64k:	exx
			ld	hl, m4_workspace
			ld	bc,DATAPORT				; FE data out port
			ld	d,(hl)						; size
			inc	d
sna1sendloop:	inc	b
			outi
			dec	d
			jr	nz, sna1sendloop
			
			ld	bc,ACKPORT
			out (c),c
			exx
			ld	hl, rom_response+4
			ld	bc,  #800
			ldir
			dec	a
			jr	nz, sna_read64k
			
			
			ld	a,(snamem+ #6b)
			cp	64
			jr	z, sna_loaded
			
			; read bank 1-4
			
			ex	af,af'
			ld	a, #C4
			
sna_bank_loop:			
			ld	bc, #7F00
			out	(c),a
			
			ex	af,af'
			ld	a,16384/2048
			ld	de, #4000
sna_read16k:	exx
			ld	hl, m4_workspace
			ld	bc,DATAPORT				; FE data out port
			ld	d,(hl)						; size
			inc	d
sna2sendloop:	inc	b
			outi
			dec	d
			jr	nz, sna2sendloop
			
			ld	bc,ACKPORT
			out (c),c
			exx
			ld	hl, rom_response+4
			ld	bc,  #800
			ldir
			dec	a
			jr	nz, sna_read16k
			ex	af,af'
			inc	a
			cp	 #C8
			jr	nz, sna_bank_loop
			
sna_loaded:	; close the .sna file
			ld	hl, m4_workspace+6
			ld	bc,DATAPORT
			ld	d,(hl)
			inc	d
snaclose_loop:	inc	b
			outi
			dec	d
			jr	nz, snaclose_loop
			ld	bc,ACKPORT
			out (c),c
			
			; -----------------------------------------
			
			; Gate Array setup, CRTC setup & AY SETUP
			; Written by Grim/Arkos, taken from SNARKOS v1.3
			
			; Setup pen colors 0 to 15 and border color
			ld	hl,snamem+ #2F+16
			ld	bc, #7F10
SNA_SetupGA:	out (c),c
			ld	a,(hl)
			dec	hl
			set	6,a
			out	(c),a
			dec	c
			jp	p,SNA_SetupGA
			
			; Select last active pen
			ld	a,(hl)
			out	(c),a  



			; CRTC setup
			ld	hl,snamem+ #43+17
			ld	bc, #BD00+17
SNA_SetupCRTC:
			dec	b
			out	(c),c
			ld	b, #BE
			outd
			dec	c
			jp	p,SNA_SetupCRTC
			; Select active CRTC register
			; HL = Offset &42
			; B  = &BD
			outd
			
			; ram config
				
			ld	a,(snamem+ #41)
			or	 #C0
			ld	bc, #7f00
			out	(c),a
	
			; Setup AY3 registers

			ld	hl,snamem+ #5B+15
			ld	a,15
SNA_SetupAY3:
			ld	bc, #F4C0
			out	(c),a
			ld	b,  #F6
			out (c),c
			db	 #ED,  #71
			dec	b
			outd
			ld	bc, #F680
			out (c),c
			db	 #ED,  #71
			dec	a
			jp	p,SNA_SetupAY3
			; Select last active AY3 register
			ld	bc, #F5C0
			outd
			ld	b, #F6
			out	(c),c
			db	 #ED,  #71
			
			; -----------------------------------------
			
			; set interrupt mode
			
			ld	a,(snamem+ #25)
			cp	0
			jr	nz, not_im0
			im	0
not_im0:		cp	1
			jr	nz, not_im1
			im	1
not_im1:		cp	2
			jr	nz, not_im2
			im	2
not_im2:			
			; put jumper in ram aswell, for the switch
			
			ld	hl,sna_jumper
			ld	e,l
			ld	d,h
			ld	bc, #10
			ldir
			
			; pop registers
			
			exx
			ex	af, af'
			ld	sp,snamem+ #26
			pop	af
			pop	bc
			pop	de
			pop	hl
			ex	af, af'
			exx
			
			ld	sp,snamem+ #15
			pop	de
			pop	hl
			ld	a,(snamem+ #1A)	
			ld	i,a
			
			ld	sp,snamem+ #1d
			pop	ix
			pop	iy

			
			ld	a,(snamem+ #40)
			or	 #80
			ld	c,a
			ld	b, #7F
			
			ld	sp,sna_jumper+ #D
			jp	sna_jumper
sna_error:
			ld	hl,txt_copy_err
			jp	disp_msg
			
			; hl = src ram addr
			; de = rom dest addr
			; bc = size
			
rom_write:	push	af
			push bc
			push	de
			
			xor	a
			ld	bc,DATAPORT					; data out port
			out (c),c
			ld	de,C_ROMWRITE
			out	(c),e						; command lo
			out	(c),d						; command	hi
			pop	de
			out	(c),e						; rom dest addr
			out	(c),d						; rom dest addr
			pop	de
			out	(c),e						; size
			out	(c),d						; size
			out	(c),e						; bank (0 = M4 ROM) 
rom_wrt_loop:	inc	b
			outi
			dec	de
			cp	e
			jr	nz, rom_wrt_loop
			cp	d
			jr	nz, rom_wrt_loop
			
			ld	bc,ACKPORT
			out (c),c							; transfer!
			pop	af
			ret
			
			; helper function for sna write (disable lowerrom)
			; hl = address
			; d = number of 1KB chunks
			; e = file handle (REAL MODE)
			; iy = return address
			; stack space 4 (2 for DE, 2 for ret)
memwrite:		
			ld	bc, #7F86		; disable lowerrom
			out	(c),c
			ld	bc,DATAPORT
			out	(c),c			; ignore first byte
			ld	a,C_WRITE2& #FF	
			out	(c),a
			ld	a,C_WRITE2>>8	
			out	(c),a			
			out	(c),e			; fd
			db  #DD, #6B			; ld IXl, e
			db  #DD, #62			; ld IXh, d
			ld	de, #400
			out	(c),e			; size 00
			out	(c),d			; size  #0400
			xor a
memwrtloop:	inc	b
			outi
			dec	de
			cp	e
			jr	nz, memwrtloop
			cp	d
			jr	nz, memwrtloop
			
			
			ld	b,ACKPORT>>8	; kick command
			out	(c),c
			
			db  #DD, #5D			; ld e, IXl
			db  #DD, #54			; ld d, IXh
			
			dec	d
			jr	nz, memwrite
			ld	bc, #7F80		; enable lowerrom
			out	(c),c
			jp (iy)
					

data_0:		db	0,1		
romslots_fn:
			db "/m4/romslots.bin"
			db	0
romconfig_fn:
			db "/m4/romconfig.bin"
			db	0
autoexec_fn:	db "/AUTOEXEC.BAS"
			db	0
			
sdir_cmd:
			db	2			; size
			dw	C_READDIR
sfree_cmd:
			db	2			; size
			dw	C_FREE

seek_cmd:
			db	2			; size
			dw	C_SEEK

eof_cmd:
			db	2
			dw	C_EOF

ftell_cmd:
			db	3
			dw	C_FTELL
			db	1		; read fd


fail_msg:
			db "File not found or other error."
			db 10, 13, 0
	
miss_arg:
			db "Missing arguments."
			db 10, 13, 0
txt_copying:	db	"Copy: "
			db	0
txt_to:		db	" -> "
			db	0
txt_copy_err:	db	"Error occurred."
			db	10,13,0

text_unkdir:
			db "Unknown directory."
			db 10, 13, 0
text_ip:		db "IP: "
			db 0
text_nm:		db "Netmask: "
			db 0
text_gw:		db "Gateway: "
			db 0
text_dns1:	db "DNS1: "
			db 0
text_dns2:	db "DNS2: "
			db 0
text_mac:		db "MAC: "
			db 0
						
text_drive:
			db 10, 13
			db "Drive A:"
			db 0	; 10, 13, 10, 13, 0

text_signal:	db "Signal:  #"
			db	0
text_not_found:
			db " not found"
			db	10,13,0
text_break:	db	10,13
			db "*Break*"
			db	10,13,0
txt_sna_err:	db "Not valid SNA file!"
			db	10,13,0
txt_sna_id:	db "MV - SNA"

ff_error_map:
			db  #0	;FR_OK				0
			db  #FF	;FR_DISK_ERR			1
			db  #FF	;FR_INT_ERR			2
			db  #FF	;FR_NOT_READY			3
			db  #92	;FR_NO_FILE			4
			db  #92	;FR_NO_PATH			5
			db  #92	;FR_INVALID_NAME		6
			db  #FF	;FR_DENIED			7
			db  #91	;FR_EXIST				8	128+17 File already exists
			db  #FF	;FR_INVALID_OBJECT		9
			db  #FF	;FR_WRITE_PROTECTED		10
			db  #FF	;FR_INVALID_DRIVE		11
			db  #FF	;FR_NOT_ENABLED			12
			db  #FF	;FR_NO_FILESYSTEM		13
			db  #FF	;FR_MKFS_ABORTED		14
			db  #FF	;FR_TIMEOUT			15
			db  #FF	;FR_LOCKED				16
			db  #FF	;FR_NOT_ENOUGH_CORE		17
			db  #FF	;FR_TOO_MANY_OPEN_FILES	18
			db  #FF	;FR_INVALID_PARAMETER	19
			db  #E	; already open			20

amsdos_table05:
			dw	 #C1B2		; CPM
			dw	 #CCD1		; DISC
			dw	 #CCD5		; DISC.IN
			dw	 #CCE4		; DISC.OUT
			dw	 #CCFD		; TAPE
			dw	 #CD01		; TAPE.IN
			dw	 #CD18		; TAPE.OUT
			dw	 #CDDA		; A
			dw	 #CDDD		; B
			dw	 #CDE4		; DRIVE 
			dw	 #CDFE		; USER
			dw	 #D42E		; DIR
			dw	 #D48A		; ERA
			dw 	 #D4C4		; REN
			dw	 #CA72		; 81 SetMessage
			dw	 #C60D		; 82 SetupDisc
			dw	 #C581		; 83 SelectFormat
			dw	 #C666		; 84 ReadSector
			dw	 #C64E		; 85 WriteSector
			dw	 #C652		; 86 FormatTrack
			dw	 #C763		; 87 MoveTrack
			dw	 #C630		; 88 GetDrStatus
			dw	 #C603		; 89 SetRetryCount
amsdos_table07:
			dw	 #C1A9		; CPM
			dw	 #CD35		; DISC
			dw	0			; DISC.IN
			dw	0			; DISC.OUT
			dw	 #CD61		; TAPE
			dw	0			; TAPE.IN
			dw	0			; TAPE.OUT
			dw	 #CED1		; A
			dw	 #CED4		; B
			dw	 #CEDB		; DRIVE 
			dw	 #CEF5		; USER
			dw	 #D525		; DIR
			dw	 #D581		; ERA
			dw 	 #D5BB		; REN
			dw	 #CAD8		; 81 SetMessage
			dw	 #C706		; 82 SetupDisc
			dw	 #C581		; 83 SelectFormat
			dw	 #C666		; 84 ReadSector
			dw	 #C64E		; 85 WriteSector
			dw	 #C652		; 86 FormatTrack
			dw	 #C792		; 87 MoveTrack
			dw	 #C630		; 88 GetDrStatus
			dw	 #C603		; 89 SetRetryCount			
			
jump_vec2:	dw	load_autoexec	; 10
			
helper_functions:
				dw	hsend
				dw	hreceive
				dw	fopen
				dw	fread
				dw	fwrite
				dw	fclose
				dw	fseek
				;dw	fsize
				

				
.org rom_response- #100
run_filename:
				ds	256 			; (256-1) max file+path depth
					
.org rom_response
				ds	 #C00
.org	rom_config
amsdos_inheader:	dw	0	; 0
jump_vec:			dw	0	; 2
rom_num:			db	0	; 4
init_count:		db	0	; 5
amsdos_outheader:	dw	0	; 6
rom_workspace:		dw	0	; 8
old_bb5a:			ds	3	; 10
old_bc6e:			ds	3	; 13
amsdos_ver:		db	0	; 16
amsdos_rom_num:	db	0	; 17
basic_ver:		db	0		; 18
				db	0		; 19

runfile_ptr:		dw	autoexec_fn ; 20
tape_functions:	ds	48		; 22
amsdos_default_drive:
				db	0		; 80
amsdos_default_user:
				db	0		; 81
amsdos_active_drive:				
				db	0		; 82

.org	sock_status
sock_info:	ds	80	; 5 socket status structures (0 is used for gethostbyname*, 1-4 returned by socket function) of 16 bytes
; structure layout
;	status		1	- current status 0=idle, 1=connect in progress, 2=send in progress, 3=remote closed connectoion, 4=wait incoming (accept), 240-255 = error code
;	lastcmd		1	- last command updating sock status 0=none, 1=send, 2=dnslookup, 3=connect, 4=accept, 5=recv, 6=error handler
;	received		2	- data received in internal buffer (ready to get with C_NETRECV)
;	ip_addr		4	- ip addr of connected client in passive mode
;	port			2	- port of the same..
;	reserved		6	- not used yet (alignment!).
; *for socket 0, gethostbyname, status will be set to 5 when in progress and back to 0, when done.

.org	rom_table
			dw	 #206	; rom version		 #FF00
			dw	rom_response		;  #FF02
			dw	rom_config		;  #FF04
			dw	sock_info			;  #FF06
			dw	helper_functions	;  #FF08
			dw	run_filename		;  #FF0A
			dw	tape_functions		;  #FF0C
			dw  snamem			;  #FF0E
         		dw  memwrite			;  #FF10
; SNA rom/ram switching, similar to SNArkos
.org	 #FFF0
sna_jumper:
.org	 #FFFF
			db	 #FF	
.AREA _DATA

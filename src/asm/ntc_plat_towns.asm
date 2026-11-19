; ============================================================
; NTC Platform - Fujitsu FM Towns (80386), a disc that boots itself
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The program is a 2HD floppy image (77 tracks, 2 sides, 8 sectors of 1024
; bytes). The machine's ROM reads the first sector to B000:0000 and, when it
; starts with "IPL4", far calls B000:0004 in real mode. That sector is NTC's:
; it reads the rest of the program to $10000 with the ROM's disc call
; (FFFB:0014), sets up 32 bit protected mode (flat segments, no paging) and
; starts the program in ring 3. No Towns OS or DOS extender is needed.
;
; The program runs in RING 3 with ESP as the thread; an interrupt or
; exception goes to ring 0 on the ring 0 stack (the TSS's), so it never
; touches the thread. Ring 3 has the I/O ports (IOPL 3) and all of memory
; (flat, no paging), so the hardware can be used directly.
;
; Memory:
;   $000000-$0003FF real mode's vectors (not used once the program runs)
;   $000400-$0006FF the ring 0 stack (interrupts, exceptions), top down
;   $000700-$00076F the TSS
;   $000800-$000FFF the IDT (256 gates)
;   $001000-$00FFFF the program's variables, the library's, then its arrays
;                   (their addresses are 16 bits: VarPtr, Peek, descriptors)
;   $010000-        the program: start, threads, keywords, strings
;   -$0AFFFF        the real stack (ntc_csp: the library's calls), top down
;   $0B0000-$0B03FF the boot sector (it holds the GDT: left where it is)
;   (the end of the program to $9F000, and the end of the high data to the top of RAM: free;
;    the Memory class (lib/towns/Memory.cls) hands them out)
;   $100000-        the high data: the program's section .ntchigh, if any (the
;                   boot sector reads it to $A0000 a track at a time and copies it
;                   up in protected mode)
;   NTC_TWLOG test builds: the console's transcript from $0A0000
;
; The console is drawn on the planar screen the ROM boots with (640 x 400,
; 80 bytes a row at $C0000; the 8 x 16 font ROM at $CB000): 80 x 25.
;
; RUN: on the Tsugaru emulator with the free compatible ROMs. Not on a real
; FM Towns.
; ============================================================
;@name     Fujitsu FM Towns (80386, boot disc)
;@cpu      x86
;@org      0x10000
;@ramorg   0x1000
;@ramend   0x10000
;@text     byte
;@scrinit  0
;@irq      0
;@cols     80
;@rows     25
; ============================================================

;## ntc_md_vectors ntc_tw_boot
; (the 68000 path's name for "what comes first": here the boot sector and the sections'
; names. nasm -f bin writes the sections in this order: the boot sector, the code, then
; the variables' first image)
NTC_TWCODE	equ 0x10000			; where the program is loaded and runs
NTC_USTACK	equ 0x0B0000		; the real stack's top (ring 3)
NTC_K0STACK	equ 0x0700			; the ring 0 stack's top
NTC_TSS		equ 0x0700
NTC_IDT		equ 0x0800
NTC_VRAM	equ 0xC0000			; the planar screen: 80 bytes a row, 400 rows
NTC_FONT	equ 0xCB000			; the 8 x 16 font: 16 bytes a character

			section .ntcboot start=0 vstart=0
			bits 16
			db "IPL4"
; B000:0004, real mode
			cli
			cld
			mov ax, cs
			mov ds, ax
			mov ss, ax
			mov sp, 0xFFF0
			mov eax, section..ntchend.start	; sectors to read: the program, then its high data
			sub eax, section..ntchigh.start
			add eax, 1023
			shr eax, 10
			add ax, NTC_TWLOWS
			mov si, ax
			xor cx, cx					; cylinder
			mov dx, 0x0002				; dh = side 0, dl = sector 2
ntc_ipl_rd:
			mov bx, 9
			sub bl, dl					; the sectors left on this track
			cmp bx, si
			jbe ntc_ipl_n
			mov bx, si
ntc_ipl_n:
			mov ax, [ntc_ipl_low]		; the program's sectors: not past its end in one read
			test ax, ax
			jz ntc_ipl_n2
			cmp bx, ax
			jbe ntc_ipl_n2
			mov bx, ax
ntc_ipl_n2:
			push si
			push cx
			push dx
			push bx
			push ds
			mov ax, [ntc_ipl_seg]
			mov ds, ax
			xor di, di
			mov ax, 0x0520				; read, floppy drive 0
			call 0xFFFB:0x0014			; the ROM's disc call: cx = cylinder, dh = side, dl = sector, bx = sectors, ds:di = where
			pop ds
			pop bx
			pop dx
			pop cx
			pop si
			jc ntc_ipl_rd				; (an error: again)
			cmp word [ntc_ipl_low], 0
			jz ntc_ipl_up				; the high data: from $A0000 up to its place
			mov ax, bx
			shl ax, 6					; 1024 bytes = $40 paragraphs a sector
			add [ntc_ipl_seg], ax
			sub [ntc_ipl_low], bx
			jnz ntc_ipl_next
			mov word [ntc_ipl_seg], 0xA000	; the program read: the high data comes through $A0000
			jmp ntc_ipl_next
ntc_ipl_up:
			cli
			pushad
			push ds
			push es
			movzx ecx, bx
			shl ecx, 8					; dwords
			mov edi, [ntc_ipl_dst]
			mov eax, ecx
			shl eax, 2
			add [ntc_ipl_dst], eax
			lgdt [ntc_ipl_gdtr]
			mov eax, cr0				; protected mode for the copy (the code segment stays as it is)
			or al, 1
			mov cr0, eax
			jmp short ntc_ipl_pm1
ntc_ipl_pm1:
			mov ax, 0x10
			mov ds, ax
			mov es, ax
			mov esi, 0xA0000
			cld
			a32 rep movsd
			mov eax, cr0
			and al, 0xFE
			mov cr0, eax
			jmp short ntc_ipl_pm2
ntc_ipl_pm2:
			pop es
			pop ds
			popad
ntc_ipl_next:
			sub si, bx
			jz ntc_ipl_pm
			add dl, bl
			cmp dl, 9
			jb ntc_ipl_rd
			mov dl, 1
			xor dh, 1
			jnz ntc_ipl_rd
			inc cx
			jmp ntc_ipl_rd
ntc_ipl_pm:
			lgdt [ntc_ipl_gdtr]
			mov eax, cr0
			or al, 1
			mov cr0, eax
			jmp dword 0x08:ntc_tw_entry
ntc_ipl_seg:	dw NTC_TWCODE >> 4
ntc_ipl_low:	dw NTC_TWLOWS
ntc_ipl_dst:	dd NTC_TWHIGH
ntc_ipl_gdtr:	dw 0x2F
			dd 0xB0000 + ntc_ipl_gdt
ntc_ipl_gdt:	db 0, 0, 0, 0, 0, 0, 0, 0
			db 0xFF, 0xFF, 0, 0, 0, 0x9A, 0xCF, 0		; $08: ring 0 code, flat
			db 0xFF, 0xFF, 0, 0, 0, 0x92, 0xCF, 0		; $10: ring 0 data, flat
			db 0xFF, 0xFF, 0, 0, 0, 0xFA, 0xCF, 0		; $18: ring 3 code, flat
			db 0xFF, 0xFF, 0, 0, 0, 0xF2, 0xCF, 0		; $20: ring 3 data, flat
			db 0x67, 0, NTC_TSS & 255, NTC_TSS >> 8, 0, 0x89, 0, 0	; $28: the TSS
			times 1008-($-$$) db 0
			; the disc's facts, for test/townsbuild.js to check (the boot sector's last 16 bytes)
			db "NTCT"
			dd NTC_TWLOWS								; the program's sectors (after this one)
			dd section..ntchigh.start					; the high data's place in the file (it is loaded to NTC_TWHIGH),
			dd section..ntchend.start					; and its end there

			section .ntccode vstart=0x10000 follows=.ntcboot align=4
			section .ntcram vstart=0x1000 follows=.ntccode align=1	; (as the compiler's, ;@ramorg)
			section .ntchigh vstart=NTC_TWHIGH follows=.ntcram align=1024
			section .ntchend follows=.ntchigh align=1
			section .ntccode
			bits 32
ntc_tw_code0:
NTC_TWBYTES	equ ((ntc_romend - ntc_tw_code0 + 3) / 4) * 4 + (ntc_ramend - ntc_ram)
NTC_TWLOWS	equ (NTC_TWBYTES + 1023) / 1024
; the high data: a program's section .ntchigh (#asm: incbin), loaded to $100000 on (a 2 MB
; machine has up to $1FFFFF): it starts on the disc's next sector after the program
NTC_TWHIGH	equ 0x100000
; NTC_HIGHFILE label, "FILE": a file in the high data, label = its address there. In #asm:
;     NTC_HIGHFILE gd_data, "GAME.DAT"        then   mov dword [edi], gd_data
%macro NTC_HIGHFILE 2
			section .ntchigh
			align 4, db 0
%1:
			incbin %2
			align 4, db 0
			section .ntccode
%endmacro

;## ntc_tw_boot ntc_plat_data ntc_data ntc_plat_screen
; ring 0, 32 bits: the variables' image to where they live, the TSS and the IDT, then ring 3
ntc_tw_entry:
			mov ax, 0x10
			mov ds, ax
			mov es, ax
			mov ss, ax
			mov fs, ax
			mov gs, ax
			mov esp, NTC_K0STACK
			mov esi, ntc_romend			; the variables' first image follows the code (on a 4 byte edge)
			add esi, 3
			and esi, -4
			mov edi, ntc_ram
			mov ecx, ntc_ramend - ntc_ram
			rep movsb
%ifdef NTC_TWLOG
			mov dword [0x09FFFC], 0x0A0000	; test builds: the transcript starts empty
			mov dword [0x09FFF0], 0
%endif
			mov edi, NTC_TSS			; the TSS: only the ring 0 stack matters
			mov ecx, 104
			xor eax, eax
			rep stosb
			mov dword [NTC_TSS + 4], NTC_K0STACK
			mov dword [NTC_TSS + 8], 0x10
			mov word [NTC_TSS + 102], 104	; no I/O map (IOPL 3 gives the ports)
			mov ax, 0x28
			ltr ax
			mov edi, NTC_IDT			; the IDT: every gate to the catch-all for now
			mov ecx, 256
			mov eax, ntc_tw_exc
ntc_tb_idt:
			mov [edi], ax
			mov word [edi + 2], 0x08
			mov word [edi + 4], 0x8E00	; a ring 0 interrupt gate, 32 bits
			mov ebx, eax
			shr ebx, 16
			mov [edi + 6], bx
			add edi, 8
			loop ntc_tb_idt
			mov edi, NTC_IDT + 0x4B * 8	; the frame interrupt's gate (line 11 = vector $4B)
			mov eax, ntc_tw_vsync
			mov [edi], ax
			shr eax, 16
			mov [edi + 6], ax
			lidt [ntc_tw_idtr]
			; the 2 interrupt controllers (8259: ports $00/$02 and $10/$12, the second on the
			; first's line 7): set up again from nothing, vectors $40-$47 and $48-$4F, then
			; every line masked but the frame (line 11 = the second's line 3) and the link
			mov al, 0x19
			out 0x00, al
			mov al, 0x40
			out 0x02, al
			mov al, 0x80
			out 0x02, al
			mov al, 0x1D
			out 0x02, al
			mov al, 0x19
			out 0x10, al
			mov al, 0x48
			out 0x12, al
			mov al, 0x07
			out 0x12, al
			mov al, 0x09
			out 0x12, al
			mov al, 0x7F
			out 0x02, al
			mov al, 0xF7
			out 0x12, al
			mov edx, 0x604				; the keyboard: no interrupt (it is read at its ports)
			xor eax, eax
			out dx, al
			mov edx, 0x5CA				; a frame interrupt left waiting: dropped
			out dx, al
			mov byte [NTC_VRAM + 0xFF81], 0x0F	; the planar screen: write every plane, read plane 0
			mov byte [NTC_VRAM + 0xFF99], 1		; the font ROM at $CB000
			mov edi, NTC_VRAM			; the screen clear
			mov ecx, 80 * 400
			xor eax, eax
			rep stosb
			mov ax, 0x23
			mov ds, ax
			mov es, ax
			mov fs, ax
			mov gs, ax
			push dword 0x23				; ring 3: its stack, flags (interrupts on, IOPL 3), its code
			push dword NTC_USTACK
			push dword 0x3202
			push dword 0x1B
			push dword ntc_start
			iretd
ntc_tw_idtr:	dw 256 * 8 - 1
			dd NTC_IDT

; the frame interrupt (the vertical blank, ring 0 on the ring 0 stack): count it
ntc_tw_vsync:
			push eax
			push edx
			push ds
			mov ax, 0x10
			mov ds, ax
			mov edx, 0x5CA				; any write here drops the request
			out dx, al
			inc word [ntc_ticks]
			inc word [ntc_vbl]
			mov al, 0x63				; end of interrupt: the second controller's line 3,
			out 0x10, al
			mov al, 0x67				; then the first's line 7
			out 0x00, al
			pop ds
			pop edx
			pop eax
			iretd

; an exception or an interrupt nobody takes (ring 0): what it was pushed, kept for the
; harness at $09FFF0, and the machine stops
ntc_tw_exc:
			mov eax, [esp]
			mov [0x09FFF4], eax
			mov eax, [esp + 4]
			mov [0x09FFF8], eax
			mov dword [0x09FFF0], 0xDEADDEAD
ntc_tw_halt:
			jmp ntc_tw_halt

;## ntc_plat_data
;@ram
ntc_curx:		db 0				; cursor column (0 based)
ntc_cury:		db 0				; cursor row (0 based)
ntc_scols:		db 80				; columns
ntc_srows:		db 25				; rows
ntc_wrapped:	db 0				; 1 = the last character wrapped to the next line
			align 2, db 0
ntc_ticks:		dw 0				; frames since the start
ntc_vbl:		dw 0				; frames (ntc_plat_frame waits for it to move)
ntc_tw_kflag:	db 0				; the keyboard: the event's flags byte
ntc_tw_kqr:		db 0				; the characters' queue: where the next is read,
ntc_tw_kqw:		db 0				; and written
ntc_tw_kq:		times 16 db 0
ntc_tw_held:	times 128 db 0		; a byte a key number: 1 while the key is held
ntc_tw_brk:		dd 0				; the Memory class: the next free byte under $9F000 (0: not set up),
ntc_tw_hbrk:	dd 0				; and above the high data
			align 2, db 0
;@rom

;## ntc_plat_screen ntc_plat_data ntc_data ntc_tw_logs
; ntc_plat_putc - al = character: drawn at the cursor, move on, a new line after the last
; column. Real stack, keeps every register
ntc_plat_putc:
			pushad
%ifdef NTC_TWLOG
			call ntc_tw_log
%endif
			movzx esi, al
			shl esi, 4
			add esi, NTC_FONT
			call ntc_tw_cell			; edi = the cursor's place on the screen
			mov ecx, 16
ntc_pc_row:
			mov al, [esi]
			mov [edi], al
			inc esi
			add edi, 80
			loop ntc_pc_row
			inc byte [ntc_curx]
			mov al, [ntc_curx]
			cmp al, [ntc_scols]
			jb ntc_pc_nowrap
			mov byte [ntc_wrapped], 1
			popad
			jmp ntc_nl_do
ntc_pc_nowrap:
			mov byte [ntc_wrapped], 0
			popad
			ret

; edi = where the cursor's cell is on the screen (keeps the rest)
ntc_tw_cell:
			push eax
			movzx edi, byte [ntc_cury]
			imul edi, 80 * 16
			movzx eax, byte [ntc_curx]
			lea edi, [edi + eax + NTC_VRAM]
			pop eax
			ret

; ntc_plat_newline - column 0, next row (scrolls at the bottom); nothing straight after a wrap
ntc_plat_newline:
%ifdef NTC_TWLOG
			push eax
			mov al, 10
			call ntc_tw_log
			pop eax
%endif
			cmp byte [ntc_wrapped], 0
			jz ntc_nl_do
			mov byte [ntc_wrapped], 0
			ret
ntc_nl_do:
			pushad
			mov byte [ntc_curx], 0
			inc byte [ntc_cury]
			mov al, [ntc_cury]
			cmp al, [ntc_srows]
			jb ntc_nl_e
			dec byte [ntc_cury]
			mov esi, NTC_VRAM + 80 * 16		; the text up a row
			mov edi, NTC_VRAM
			mov ecx, 80 * 16 * 24
			rep movsb
			mov ecx, 80 * 16				; the last row clear
			xor eax, eax
			rep stosb
ntc_nl_e:
			popad
			ret

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_backspace - back a column and clear it (not past the line's start)
ntc_plat_backspace:
			cmp byte [ntc_curx], 0
			jz ntc_bs_e
			dec byte [ntc_curx]
			pushad
			call ntc_tw_cell
			mov ecx, 16
ntc_bs_row:
			mov byte [edi], 0
			add edi, 80
			loop ntc_bs_row
			popad
ntc_bs_e:
			ret

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_cls - clear the console, the cursor home
ntc_plat_cls:
			pushad
			mov edi, NTC_VRAM
			mov ecx, 80 * 400
			xor eax, eax
			rep stosb
			mov byte [ntc_curx], 0
			mov byte [ntc_cury], 0
			mov byte [ntc_wrapped], 0
			popad
			ret

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data ntc_plat_cls
; ntc_plat_mode - eax = mode: one text mode here (80 x 25), so it clears the screen
ntc_plat_mode:
			jmp ntc_plat_cls

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - eax = column, ecx = row (1 based, kept on the screen)
ntc_plat_locate:
			push eax
			push ecx
			sub eax, 1
			jns ntc_lo_x0
			xor eax, eax
ntc_lo_x0:
			cmp eax, 79
			jbe ntc_lo_x1
			mov eax, 79
ntc_lo_x1:
			sub ecx, 1
			jns ntc_lo_y0
			xor ecx, ecx
ntc_lo_y0:
			cmp ecx, 24
			jbe ntc_lo_y1
			mov ecx, 24
ntc_lo_y1:
			mov [ntc_curx], al
			mov [ntc_cury], cl
			mov byte [ntc_wrapped], 0
			pop ecx
			pop eax
			ret

;## ntc_tw_logs
%ifdef NTC_TWLOG
; test builds (nasm -DNTC_TWLOG): what the console was given, at $0A0000 on (the
; harness reads it): characters, 10 for a new line. $09FFFC: where the next goes
ntc_tw_log:
			push edi
			mov edi, [0x09FFFC]
			cmp edi, 0x0AE000
			jae ntc_lg_full
			mov [edi], al
			inc edi
			mov [0x09FFFC], edi
ntc_lg_full:
			pop edi
			ret
%endif

;## ntc_plat_key ntc_data ntc_plat_data ntc_plat_frame
; The keyboard is read at its ports (no interrupt): $602 bit 0 = a byte is waiting, $600 = the
; byte. A key event is 2 bytes: flags ($80 always, $10 = released, $04 = Shift held, $08 =
; Ctrl held), then the key's number ($00-$7F).
; ntc_tw_keypoll - every event waiting taken in: ntc_tw_held (a byte a key number: 1 while it is
; held - the Keys class) and, for a press with a character, the character into a queue of 16
; (Inkey, Input). Keeps every register. (20261119-1: before, only Inkey read the port, so a
; game reading the keys held had to read it too and each took the other's bytes.)
ntc_tw_keypoll:
			push eax
			push ebx
			push edx
ntc_kp_lp:
			mov edx, 0x602
			in al, dx
			test al, 1
			jz ntc_kp_e
			mov edx, 0x600
			in al, dx
			test al, 0x80
			jz ntc_kp_code
			mov [ntc_tw_kflag], al		; the first byte: the flags
			jmp ntc_kp_lp
ntc_kp_code:
			movzx eax, al
			and eax, 0x7F
			mov bl, [ntc_tw_kflag]
			test bl, 0x10
			jz ntc_kp_press
			mov byte [ntc_tw_held + eax], 0
			jmp ntc_kp_lp
ntc_kp_press:
			mov byte [ntc_tw_held + eax], 1
			cmp eax, 0x60
			jae ntc_kp_lp
			test bl, 0x04
			jz ntc_kp_tab
			add eax, 0x60				; Shift: the second table
ntc_kp_tab:
			mov al, [ntc_tw_keys + eax]
			test al, al
			jz ntc_kp_lp				; a key with no character (Shift, Ctrl, ...)
			movzx ebx, byte [ntc_tw_kqw]
			mov [ntc_tw_kq + ebx], al
			inc ebx
			and ebx, 15
			cmp bl, [ntc_tw_kqr]
			je ntc_kp_lp				; the queue is full: the character is dropped
			mov [ntc_tw_kqw], bl
			jmp ntc_kp_lp
ntc_kp_e:
			pop edx
			pop ebx
			pop eax
			ret

; ntc_plat_scankey - eax = a key press waiting (its character; the cursor keys $F0 up, $F1
; down, $F2 left, $F3 right), or 0. Keeps every other register
ntc_plat_scankey:
			call ntc_tw_keypoll
			xor eax, eax
			push ebx
			movzx ebx, byte [ntc_tw_kqr]
			cmp bl, [ntc_tw_kqw]
			je ntc_sk_e
			mov al, [ntc_tw_kq + ebx]
			inc ebx
			and ebx, 15
			mov [ntc_tw_kqr], bl
ntc_sk_e:
			pop ebx
			ret

; ntc_plat_getkey - wait for a key: eax = its code
ntc_plat_getkey:
			call ntc_plat_scankey
			test eax, eax
			jnz ntc_gk_e
			call ntc_plat_frame
			jmp ntc_plat_getkey
ntc_gk_e:
			ret

; key number -> character: plain, then with Shift (the Towns JIS keyboard's layout)
ntc_tw_keys:
			db 0x00, 0x1B, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30, 0x2D, 0x5E, 0x5C, 0x08
			db 0x09, 0x71, 0x77, 0x65, 0x72, 0x74, 0x79, 0x75, 0x69, 0x6F, 0x70, 0x40, 0x5B, 0x0D, 0x61, 0x73
			db 0x64, 0x66, 0x67, 0x68, 0x6A, 0x6B, 0x6C, 0x3B, 0x3A, 0x5D, 0x7A, 0x78, 0x63, 0x76, 0x62, 0x6E
			db 0x6D, 0x2C, 0x2E, 0x2F, 0x5F, 0x20, 0x2A, 0x2F, 0x2B, 0x2D, 0x37, 0x38, 0x39, 0x3D, 0x34, 0x35
			db 0x36, 0x00, 0x31, 0x32, 0x33, 0x0D, 0x30, 0x2E, 0x00, 0x00, 0x00, 0x7F, 0x00, 0xF0, 0x00, 0xF2
			db 0xF1, 0xF3, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
			db 0x00, 0x1B, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x30, 0x3D, 0x7E, 0x7C, 0x08
			db 0x09, 0x51, 0x57, 0x45, 0x52, 0x54, 0x59, 0x55, 0x49, 0x4F, 0x50, 0x60, 0x7B, 0x0D, 0x41, 0x53
			db 0x44, 0x46, 0x47, 0x48, 0x4A, 0x4B, 0x4C, 0x2B, 0x2A, 0x7D, 0x5A, 0x58, 0x43, 0x56, 0x42, 0x4E
			db 0x4D, 0x3C, 0x3E, 0x3F, 0x5F, 0x20, 0x2A, 0x2F, 0x2B, 0x2D, 0x37, 0x38, 0x39, 0x3D, 0x34, 0x35
			db 0x36, 0x00, 0x31, 0x32, 0x33, 0x0D, 0x30, 0x2E, 0x00, 0x00, 0x00, 0x7F, 0x00, 0xF0, 0x00, 0xF2
			db 0xF1, 0xF3, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

;## ntc_tw_mem ntc_plat_data
; The Memory class (lib/towns/Memory.cls). Two pools the program does not use:
;   low:  from the end of the program (the next 4K edge) to $9F000 (the exception record and a
;         test build's transcript are above it; the real stack comes down from $B0000)
;   high: from the end of the high data (the next 4K edge; $100000 with none) to the top of the
;         machine's RAM (port $5E8: its megabytes)
; ntc_tw_alloc - eax = bytes, ebx = 0 low / 1 high: eax = the block's address (a 4 byte edge),
; or 0 when there is not that much left. Keeps the other registers
ntc_tw_alloc:
			push ecx
			push edx
			push esi
			call ntc_tw_memset
			add eax, 3
			and eax, ~3
			lea esi, [ntc_tw_brk + ebx * 4]
			mov ecx, [esi]				; the block
			mov edx, 0x9F000
			test ebx, ebx
			jz ntc_al_top
			mov edx, [ntc_tw_htop]
ntc_al_top:
			sub edx, ecx				; what is left
			jb ntc_al_none
			cmp eax, edx
			ja ntc_al_none
			add eax, ecx
			mov [esi], eax
			mov eax, ecx
			jmp ntc_al_e
ntc_al_none:
			xor eax, eax
ntc_al_e:
			pop esi
			pop edx
			pop ecx
			ret
; ntc_tw_left - ebx = 0 low / 1 high: eax = the bytes left in that pool
ntc_tw_left:
			call ntc_tw_memset
			mov eax, 0x9F000
			test ebx, ebx
			jz ntc_lf_top
			mov eax, [ntc_tw_htop]
ntc_lf_top:
			sub eax, [ntc_tw_brk + ebx * 4]
			jae ntc_lf_e
			xor eax, eax
ntc_lf_e:
			ret
; the pools' starts and the high pool's top, the first time
ntc_tw_memset:
			cmp dword [ntc_tw_brk], 0
			jne ntc_ms_e
			push eax
			push edx
			mov eax, ntc_romend + 3 + 0xFFF
			and eax, ~3
			add eax, ntc_ramend - ntc_ram
			and eax, ~0xFFF
			mov [ntc_tw_brk], eax
			mov eax, section..ntchend.start		; (a section's start is its place in the file)
			sub eax, section..ntchigh.start
			add eax, NTC_TWHIGH + 0xFFF
			and eax, ~0xFFF
			mov [ntc_tw_hbrk], eax
			mov edx, 0x5E8				; the machine's RAM in megabytes
			in al, dx
			and eax, 0x7F
			cmp eax, 1
			ja ntc_ms_mb
			mov eax, 1
ntc_ms_mb:
			shl eax, 20
			mov [ntc_tw_htop], eax
			pop edx
			pop eax
ntc_ms_e:
			ret
;@ram
ntc_tw_htop:	dd 0
;@rom

;## ntc_plat_frame ntc_plat_data
; ntc_plat_frame - wait for the next frame interrupt (the vertical blank). Keeps every register
ntc_plat_frame:
			push eax
			mov ax, [ntc_vbl]
ntc_fr_lp:
			cmp ax, [ntc_vbl]
			je ntc_fr_lp
			pop eax
			ret

;## ntc_plat_ticks ntc_plat_data
; ntc_plat_ticks - ax = frames since the start
ntc_plat_ticks:
			mov ax, [ntc_ticks]
			ret

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - before the program stops: a boot disc has nowhere to go back to
ntc_plat_exit:
%ifdef NTC_TWLOG
			mov dword [0x09FFF0], 0x0E0D0E0D	; test builds: the program has ended
%endif
			ret

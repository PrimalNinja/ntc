; ============================================================
; NTC Platform - Amstrad CPC through the firmware
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; Text and keys go through the firmware jumpblock, so the
; program keeps the firmware's windows, font, key translation
; and interrupt handler, and lives alongside AMSDOS and RSXs
; (built at #0040, so BASIC's program area is not kept). Built at #0040: load and run it with RUN"name (AMSDOS).
;
; Firmware calls need a real stack: SP is the thread, so each
; call goes through ntc_fwcall, which switches SP to the
; caller's stack (ntc_csp), lets interrupts in (the firmware
; scans the keyboard on interrupts), calls, and switches back.
; The thread itself never sees call or push.
;
; In turbo mode interrupts only get in during firmware calls,
; so keys pressed while the program computes are caught at the
; next Inkey / Input (the firmware buffers them), and Ticks
; (the firmware's 1/300 s clock) still counts.
; ============================================================
;@name     Amstrad CPC - firmware text and keys
;@org      #0040
;@text     byte
;@scrinit  0
;@irq      0
;@cols     40
;@rows     25
; ============================================================

;## ntc_plat_data
ntc_curx:		db 0			; cursor column (0 based) - kept here for Tab
ntc_cury:		db 0			; cursor row (0 based)
ntc_scols:		db 40			; columns in this mode
ntc_fwa:		db 0			; ntc_fwcall: A on return
ntc_fwwrap:		db 0			; 1 = the last character made the firmware wrap

;## ntc_plat_fw ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_fwcall - IY = firmware address; A, BC, DE, HL go in and come
; back as the firmware leaves them (A also in ntc_fwa, carry kept).
; IX is kept. Interrupts are on during the call.
; ------------------------------------------------------------
ntc_fwcall:
			ld (ntc_hostix), ix
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			call ntc_fwjp
			di
			ld sp, (ntc_ip)
			ld (ntc_fwa), a
			ld ix, (ntc_hostix)
			jp (ix)
ntc_fwjp:
			jp (iy)

;## ntc_plat_screen ntc_plat_fw ntc_plat_data ntc_data
; ntc_plat_putc - A = character: TXT OUTPUT. The firmware wraps by itself after
; the last column, so only the column is counted here; a new line straight after
; that wrap is left out (it would leave an empty line)
ntc_plat_putc:
			ld iy, #BB5A			; TXT OUTPUT
			ld (ntc_pclink), ix
			ld ix, ntc_pc_back
			jp ntc_fwcall
ntc_pc_back:
			ld ix, (ntc_pclink)
			xor a
			ld (ntc_fwwrap), a
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			ld (ntc_curx), a
			cp b
			jr nz, ntc_pc_done
			xor a				; the firmware wrapped to the next line
			ld (ntc_curx), a
			inc a
			ld (ntc_fwwrap), a
ntc_pc_done:
			jp (ix)

; ntc_plat_newline - CR LF (the firmware scrolls); nothing straight after a wrap
ntc_plat_newline:
			ld a, (ntc_fwwrap)
			or a
			jr z, ntc_nl_go
			xor a
			ld (ntc_fwwrap), a
			jp (ix)
ntc_nl_go:
			ld (ntc_pclink), ix
			ld a, 13
			ld iy, #BB5A
			ld ix, ntc_nl_lf
			jp ntc_fwcall
ntc_nl_lf:
			ld a, 10
			ld iy, #BB5A
			ld ix, ntc_nl_done
			jp ntc_fwcall
ntc_nl_done:
			xor a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			inc a
			cp 25
			jr c, ntc_nl_row
			ld a, 24
ntc_nl_row:
			ld (ntc_cury), a
			ld ix, (ntc_pclink)
			jp (ix)

; ntc_plat_backspace - back one, blank it, back again
ntc_plat_backspace:
			xor a
			ld (ntc_fwwrap), a
			ld a, (ntc_curx)
			or a
			jr nz, ntc_bs_col
			ld a, (ntc_cury)
			or a
			jr z, ntc_bs_none
			dec a
			ld (ntc_cury), a
			ld a, (ntc_scols)
ntc_bs_col:
			dec a
			ld (ntc_curx), a
			ld (ntc_pclink), ix
			ld a, 8
			ld iy, #BB5A
			ld ix, ntc_bs_sp
			jp ntc_fwcall
ntc_bs_sp:
			ld a, ' '
			ld iy, #BB5A
			ld ix, ntc_bs_back
			jp ntc_fwcall
ntc_bs_back:
			ld a, 8
			ld iy, #BB5A
			ld ix, (ntc_pclink)
			jp ntc_fwcall
ntc_bs_none:
			jp (ix)

; ntc_plat_cls - TXT CLEAR WINDOW, cursor home
ntc_plat_cls:
			xor a
			ld (ntc_fwwrap), a
			ld (ntc_curx), a
			ld (ntc_cury), a
			ld iy, #BB6C			; TXT CLEAR WINDOW
			jp ntc_fwcall

; ntc_plat_mode - A = mode 0-2 (3 = 2): SCR SET MODE (clears)
ntc_plat_mode:
			cp 3
			jr c, ntc_md_ok
			ld a, 2
ntc_md_ok:
			ld b, 20
			or a
			jr z, ntc_md_set
			ld b, 40
			cp 1
			jr z, ntc_md_set
			ld b, 80
ntc_md_set:
			ld c, a
			ld a, b
			ld (ntc_scols), a
			xor a
			ld (ntc_fwwrap), a
			ld (ntc_curx), a
			ld (ntc_cury), a
			ld a, c
			ld iy, #BC0E			; SCR SET MODE
			jp ntc_fwcall

; ntc_plat_locate - H = column, L = row, 1 based: TXT SET CURSOR
ntc_plat_locate:
			ld a, h
			or a
			jr nz, ntc_lc_x
			inc h
ntc_lc_x:
			ld a, l
			or a
			jr nz, ntc_lc_y
			inc l
ntc_lc_y:
			xor a
			ld (ntc_fwwrap), a
			ld a, h
			dec a
			ld (ntc_curx), a
			ld a, l
			dec a
			ld (ntc_cury), a
			ld iy, #BB75			; TXT SET CURSOR
			jp ntc_fwcall
ntc_pclink:		dw 0

;## ntc_plat_key ntc_plat_fw ntc_data
; ntc_plat_scankey - A = key from the firmware's buffer, or 0
ntc_plat_scankey:
			ld (ntc_kslink), ix
			ld iy, #BB09			; KM READ CHAR
			ld ix, ntc_ks_back
			jp ntc_fwcall
ntc_ks_back:
			ld ix, (ntc_kslink)
			jr c, ntc_ks_got
			xor a
			jp (ix)
ntc_ks_got:
			ld a, (ntc_fwa)
			jp (ix)

; ntc_plat_getkey - wait for a key: KM WAIT CHAR
ntc_plat_getkey:
			ld iy, #BB06			; KM WAIT CHAR
			jp ntc_fwcall
ntc_kslink:		dw 0

;## ntc_plat_frame ntc_plat_fw
; ntc_plat_frame - MC WAIT FLYBACK
ntc_plat_frame:
			ld iy, #BD19
			jp ntc_fwcall

;## ntc_plat_ticks ntc_plat_fw
; ntc_plat_ticks - HL = the firmware's 1/300 s clock (KL TIME PLEASE, low word)
ntc_plat_ticks:
			ld iy, #BD0D
			jp ntc_fwcall

;## ntc_plat_exit ntc_plat_data
ntc_plat_exit:
			jp (ix)

; ============================================================
; File system (FileSystem class) - Load / Save through the firmware's
; cassette calls (CAS IN / CAS OUT DIRECT). With AMSDOS present they
; go to the disc (the drive that is selected), else to tape, exactly
; as BASIC's LOAD / SAVE do - with the firmware's own messages
; ("Press PLAY then any key", disc errors and Retry / Cancel).
; ============================================================
; The methods are keywords: arguments into fs_a1 .. fs_a3, the
; result's address into fs_res, then fs_go with HL = the routine.
; fs_go runs it on the real stack with interrupts on and stores its
; HL result; a routine that fails jumps to fs_err with HL = status.

FS_NOTFOUND	equ -2
FS_TOOBIG	equ -8
FS_FAILED	equ -9
FS_BADNAME	equ -4

;## ntc_plat_fs ntc_data @shared
fs_a1:			dw 0
fs_a2:			dw 0
fs_a3:			dw 0
fs_res:			dw 0
fs_sp:			dw 0
fs_esp:			dw 0
fs_six:			dw 0
fs_siy:			dw 0
fs_len:			dw 0
fs_buf:			ds 2048			; the 2K buffer CAS IN OPEN / CAS OUT OPEN want

fs_go:
			ld (fs_sp), sp
			ld sp, (ntc_csp)
			ld (fs_six), ix
			ld (fs_siy), iy
			ei
			ld (fs_esp), sp
			call fs_jphl
fs_back:
			di
			ld ix, (fs_six)
			ld iy, (fs_siy)
			ex de, hl
			ld hl, (fs_res)
			ld (hl), e
			inc hl
			ld (hl), d
			ld sp, (fs_sp)
			ret
fs_jphl:
			jp (hl)
fs_err:
			ld sp, (fs_esp)
			jr fs_back

; fs_name - B = length of the name at (fs_a1), HL = the name; an empty or too long name goes to fs_err
fs_name:
			ld hl, (fs_a1)
			ld b, 0
fs_nm_lp:
			ld a, (hl)
			or a
			jr z, fs_nm_end
			inc hl
			inc b
			ld a, b
			cp 17
			jr c, fs_nm_lp
fs_nm_bad:
			ld hl, FS_BADNAME
			jp fs_err
fs_nm_end:
			ld a, b
			or a
			jr z, fs_nm_bad
			ld hl, (fs_a1)
			ret

; Load(name, addr, maxlen): bytes loaded (the file's length), or a status.
; A file longer than maxlen is not loaded: FS_TOOBIG
fs_load:
			call fs_name
			ld de, fs_buf
			call #BC77			; CAS IN OPEN: BC = length, carry = ok
			jr c, fs_ld_open
			ld hl, FS_NOTFOUND
			jp fs_err
fs_ld_open:
			ld (fs_len), bc
			ld hl, (fs_a3)
			or a
			sbc hl, bc
			jr nc, fs_ld_fits
			call #BC7D			; CAS IN ABANDON
			ld hl, FS_TOOBIG
			jp fs_err
fs_ld_fits:
			ld hl, (fs_a2)
			call #BC83			; CAS IN DIRECT
			jr c, fs_ld_read
			call #BC7D
			ld hl, FS_FAILED
			jp fs_err
fs_ld_read:
			call #BC7A			; CAS IN CLOSE
			ld hl, (fs_len)
			ret

; Save(name, addr, len): a binary file (type 2, BASIC can LOAD it back). 0 or a status
fs_save:
			call fs_name
			ld de, fs_buf
			call #BC8C			; CAS OUT OPEN
			jr c, fs_sv_open
			ld hl, FS_FAILED
			jp fs_err
fs_sv_open:
			ld hl, (fs_a2)
			ld de, (fs_a3)
			ld bc, 0			; entry address: none
			ld a, 2				; binary
			call #BC98			; CAS OUT DIRECT
			jr c, fs_sv_done
			call #BC92			; CAS OUT ABANDON
			ld hl, FS_FAILED
			jp fs_err
fs_sv_done:
			call #BC8F			; CAS OUT CLOSE
			ld hl, 0
			ret c
			ld hl, FS_FAILED
			ret

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
;
; @irq 2: the fast ticker event (ntc_plat_irq) is only set when the
; program uses the Interrupt statement or interrupt classes.
; ============================================================
;@name     Amstrad CPC - firmware text and keys
;@org      #0040
;@text     byte
;@scrinit  0
;@irq      2
;@cols     40
;@rows     25
; ============================================================

;## ntc_plat_data
ntc_curx:		db 0			; cursor column (0 based) - kept here for Tab
ntc_cury:		db 0			; cursor row (0 based)
ntc_scols:		db 40			; columns in this mode
ntc_smode:		db 1			; screen mode (for the Graphics class)
ntc_fwa:		db 0			; ntc_fwcall: A on return
ntc_fwwrap:		db 0			; 1 = the last character made the firmware wrap
ntc_irqset:		db 0			; 1 = the firmware's fast ticker calls ntc_fwevt
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none
ntc_irqix:		dw 0
NTC_FWBLK	equ #A5F0		; the fast ticker's event block (central 32K, below the firmware)
ntc_fwtop:		dw #A600		; the top of free RAM (#A5F0 with the fast ticker's block)

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
			ld (ntc_smode), a
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

;## ntc_plat_exit ntc_plat_data ntc_plat_fw
ntc_plat_exit:
			ld bc, #7FC0		; RAM setting back to plain (a Memory page may be in #4000)
			out (c), c
			ld a, (ntc_irqset)	; the fast ticker out of the firmware's list
			or a
			jr z, ntc_ex_done
			xor a
			ld (ntc_irqset), a
			ld (ntc_irqix), ix
			ld hl, NTC_FWBLK
			ld iy, #BCE6		; KL DEL FAST TICKER
			ld ix, ntc_ex_back
			jp ntc_fwcall
ntc_ex_back:
			ld ix, (ntc_irqix)
ntc_ex_done:
			jp (ix)

;## ntc_plat_irq ntc_plat_data ntc_plat_fw ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_irqon - normal mode's interrupt work under the firmware: the
; firmware keeps its own interrupt handler (keys, sound, AMSDOS), and a fast
; ticker event (KL NEW FAST TICKER, 300 a second) calls ntc_fwevt, which
; marks an Interrupt hook / interrupt classes as due - they run at the next
; safe point, as on cpc. The event block must be in the central 32K (the
; firmware reads it with the lower ROM on): #A5F0, just under the firmware's
; RAM, so the top of free RAM becomes #A5F0.
; The class is asynchronous, NOT express: the firmware (6128 ROM, KL EVENT
; at #01E2) calls an express event straight from the interrupt with the lower
; ROM on and never looks at the far address, so a routine below #4000 (this
; program starts at #0040) would run ROM code there. A plain asynchronous
; event is run at the end of the interrupt through KL FAR ICALL, which uses
; the far address: ROM select #FF = both ROMs off.
; ------------------------------------------------------------
ntc_plat_irqon:
			ld (ntc_irqix), ix
			ld hl, NTC_FWBLK
			ld (ntc_fwtop), hl
			ld b, #80				; asynchronous, far address (not express: see above)
			ld c, #FF				; ROM select: upper and lower ROM off
			ld de, ntc_fwevt
			ld iy, #BCE0			; KL NEW FAST TICKER
			ld ix, ntc_iq_on
			jp ntc_fwcall
ntc_iq_on:
			ld a, 1
			ld (ntc_irqset), a
			ld ix, (ntc_irqix)
			jp (ix)
; the event routine: at the end of an interrupt (interrupts may be on; the
; firmware never runs it twice at once); AF, BC, DE, HL free
ntc_fwevt:
			ld a, (ntc_hookon)		; an Interrupt hook: run it at the next safe point
			or a
			jr z, ntc_fe_nohook
			ld (ntc_hookpend), a
ntc_fe_nohook:
			ld hl, (ntc_irqv)		; interrupt classes: count them
			ld a, h
			or l
			ret z
			jp (hl)
			ASSERT ntc_free <= NTC_FWBLK, "Interrupt / interrupt classes on cpcfw: the program and its arrays must end below #A5F0 (the firmware event block)"

; ============================================================
; File system (FileSystem class) - Load / Save through the firmware's
; cassette calls (CAS IN / CAS OUT DIRECT). With AMSDOS present they
; go to the disc (the drive that is selected), else to tape, exactly
; as BASIC's LOAD / SAVE do - with the firmware's own messages
; ("Press PLAY then any key", disc errors and Retry / Cancel).
;
; RUN"NAME of a binary resets the firmware (MC BOOT PROGRAM), which
; drops the background ROMs - AMSDOS too - so the cassette calls go
; back to tape. Loaded from BASIC and CALLed (MEMORY &1FFF : LOAD"NAME"
; : CALL &2000, built at org #2000), AMSDOS keeps running. Option
; RomEnable starts the ROMs again in the start code. The first file
; call checks: CAS IN OPEN (#BC77) a far call (RST 3, #DF) = AMSDOS has
; the cassette calls. AMSDOS's RAM is about #A700-#ABFF: the program
; must end below #A600 (checked when assembling). Devices: AMSDOS's own
; commands |TAPE, |DISC, |A, |B (KL FIND COMMAND, then KL FAR PCALL).
; ============================================================
; The methods are keywords: arguments into fs_a1 .. fs_a3, the
; result's address into fs_res, then fs_go with HL = the routine.
; fs_go runs it on the real stack with interrupts on and stores its
; HL result; a routine that fails jumps to fs_err with HL = status.

;## ntc_plat_fs ntc_data ntc_buf2k @shared
FS_NOTFOUND	equ -2
FS_TOOBIG	equ -8
FS_FAILED	equ -9
FS_BADNAME	equ -4
fs_a1:			dw 0
fs_a2:			dw 0
fs_a3:			dw 0
fs_res:			dw 0
fs_sp:			dw 0
fs_esp:			dw 0
fs_six:			dw 0
fs_siy:			dw 0
fs_len:			dw 0
fs_nostore:		db 0
fs_hmode:		db 0			; 0 no file open, 1 reading, 2 writing (Open)
fs_init:		db 0			; 1 = checked: is AMSDOS running?
fs_dos:			db 0			; 1 = a DOS is there (|DISC found)
fs_devd:		db 0			; the device in use: 0 tape, 1 disc
fs_n_tape:		db "TAPE", 0
fs_n_disc:		db "DISC", 0
fs_n_all:		db "TAPE,DISC", 0
fs_c_tape:		db "TAP", "E" + #80
fs_c_disc:		db "DIS", "C" + #80
fs_vol:			ds 9			; the volume in use ("" = not known)
fs_vols:		ds 145			; the volumes that worked, "A,C,M" (up to 16 of up to 8 letters)
fs_tmpn:		ds 9			; a volume name, capitals
fs_rsxn:		ds 17			; a command name (last letter + #80), up to 16 letters
fs_buf			equ ntc_buf		; the 2K buffer CAS IN OPEN / CAS OUT OPEN want (shared with Memory.Copy)
			ASSERT ntc_free <= #A600, "FileSystem on cpcfw: the program and its arrays must end below #A600 (AMSDOS's RAM)"

fs_go0:
			ld a, 1
			ld (fs_nostore), a
			jr fs_gostart
fs_go:
			xor a
			ld (fs_nostore), a
fs_gostart:
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
			ld a, (fs_nostore)
			or a
			jr nz, fs_gone
			ex de, hl
			ld hl, (fs_res)
			ld (hl), e
			inc hl
			ld (hl), d
fs_gone:
			ld sp, (fs_sp)
			ret
fs_jphl:
			jp (hl)
fs_err:
			ld sp, (fs_esp)
			jr fs_back

; fs_start - the first file call: is AMSDOS running? (no ROMs are started here:
; Option RomEnable does that in the start code)
fs_start:
			ld a, (fs_init)
			or a
			ret nz
			inc a
			ld (fs_init), a
			ld a, (#BC77)
			cp #DF				; a far call: AMSDOS has the cassette calls
			jr nz, fs_st_find	; not running (RUN" dropped it), or |TAPE: tape
			ld a, 1
			ld (fs_devd), a
		IF NTC_ROMENABLE
			ld hl, fs_n_a1		; started by the program: AMSDOS starts on drive A
			call fs_addvol
			ld hl, fs_n_a1
			ld de, fs_vol
			ld bc, 2
			ldir
		ENDIF
fs_st_find:
			ld hl, fs_c_disc
			call #BCD4			; KL FIND COMMAND: is |DISC there?
			ld a, 1
			jr c, fs_st_dos
			xor a
fs_st_dos:
			ld (fs_dos), a
			ret
fs_n_a1:		db "A", 0

; fs_rsx - HL = an AMSDOS command's name (last letter + #80): run it, no arguments.
; Not there goes to fs_err (NotFound)
fs_rsx:
			call #BCD4			; KL FIND COMMAND: HL = address, C = ROM
			jr nc, fs_rx_none
			xor a				; no arguments
			ld ix, fs_rx_none	; (the argument list: none)
			call #001B			; KL FAR PCALL
			ret
fs_rx_none:
			ld hl, FS_NOTFOUND
			jp fs_err

; fs_strout - HL = text (0 ended) into the String result at (fs_res), cut at its size
fs_strout:
			ex de, hl
			ld hl, (fs_res)
			dec hl
			ld b, (hl)			; the capacity
			inc hl
			ex de, hl
fs_so_lp:
			ld a, (hl)
			or a
			jr z, fs_so_end
			ld c, a
			ld a, b
			or a
			jr z, fs_so_end
			ld a, c
			ld (de), a
			inc hl
			inc de
			dec b
			jr fs_so_lp
fs_so_end:
			xor a
			ld (de), a
			ret

; fs_same - HL = the program's text, DE = a name in capitals: Z when the same (any case)
fs_same:
			ld a, (hl)
			call fs_up
			ld c, a
			ld a, (de)
			cp c
			ret nz
			or a
			ret z
			inc hl
			inc de
			jr fs_same

; fs_volname - HL = text: a volume name (up to 8 letters, a ':' after it is allowed) into
; fs_tmpn (capitals) and fs_rsxn (last letter + #80). NZ: not a name
fs_volname:
			ld de, fs_tmpn
			ld b, 0
fs_vn_lp:
			ld a, (hl)
			or a
			jr z, fs_vn_end
			cp ':'
			jr z, fs_vn_colon
			call fs_up
			ld (de), a
			inc hl
			inc de
			inc b
			ld a, b
			cp 9
			jr c, fs_vn_lp
			or a				; too long: NZ (A = 9)
			ret
fs_vn_colon:
			inc hl
			ld a, (hl)
			or a
			ret nz				; something after the ':'
fs_vn_end:
			xor a
			ld (de), a
			ld a, b
			or a
			jr z, fs_vn_bad
			ld hl, fs_tmpn
			ld de, fs_rsxn
			ld c, b
			ld b, 0
			ldir
			dec de
			ld a, (de)
			or #80
			ld (de), a
			xor a				; Z: a name
			ret
fs_vn_bad:
			inc a				; NZ
			ret

; fs_addvol - HL = a volume name (capitals, 0 ended): into fs_vols if not there and room
fs_addvol:
			ld (fs_len), hl		; (the name)
			ld de, fs_vols
fs_av_entry:
			ld a, (de)
			or a
			jr z, fs_av_add		; the end of the list: not there
			ld hl, (fs_len)
fs_av_cmp:
			ld a, (de)
			cp ','
			jr z, fs_av_sep
			or a
			jr z, fs_av_sep
			cp (hl)
			jr nz, fs_av_skip
			inc hl
			inc de
			jr fs_av_cmp
fs_av_sep:
			ld a, (hl)			; the entry ended: the same if the name ended too
			or a
			ret z
fs_av_skip:
			ld a, (de)			; on to the next entry
			or a
			jr z, fs_av_add
			inc de
			cp ','
			jr nz, fs_av_skip
			jr fs_av_entry
fs_av_add:
			ld hl, (fs_len)		; DE = the 0 at the end: room for "," + name + 0?
			push hl
			ld b, 0
fs_av_len:
			ld a, (hl)
			or a
			jr z, fs_av_room
			inc hl
			inc b
			jr fs_av_len
fs_av_room:
			pop hl
			push hl
			ld hl, fs_vols + 145 - 2
			or a
			sbc hl, de
			ld a, h
			or a
			jr nz, fs_av_ok		; plenty
			ld a, l
			cp b
			jr nc, fs_av_ok
			pop hl
			ret					; full: not added
fs_av_ok:
			pop hl
			ld a, e
			cp low fs_vols
			jr nz, fs_av_comma
			ld a, d
			cp high fs_vols
			jr z, fs_av_copy
fs_av_comma:
			ld a, ','
			ld (de), a
			inc de
fs_av_copy:
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			or a
			jr nz, fs_av_copy
			ret

; fs_namevol - after a Load / Save that worked: a volume in its name ("C:NAME") joins the list
fs_namevol:
			ld hl, (fs_a1)
			ld b, 9
fs_nv_lp:
			ld a, (hl)
			or a
			ret z
			cp ':'
			jr z, fs_nv_found
			inc hl
			djnz fs_nv_lp
			ret
fs_nv_found:
			ld a, 9
			sub b
			ret z				; ":NAME": no volume
			ld hl, (fs_a1)
			ld de, fs_tmpn
			ld c, a
			ld b, 0
fs_nv_cp:
			ld a, (hl)
			call fs_up
			ld (de), a
			inc hl
			inc de
			dec c
			jr nz, fs_nv_cp
			xor a
			ld (de), a
			ld hl, fs_tmpn
			jp fs_addvol

; Devices(): "TAPE,DISC" with a DOS, "TAPE" without
fs_devices:
			call fs_start
			ld hl, fs_n_all
			ld a, (fs_dos)
			or a
			jp nz, fs_strout
			ld hl, fs_n_tape
			jp fs_strout

; CurrentDevice(): "TAPE" or "DISC"
fs_curdev:
			call fs_start
			ld hl, fs_n_tape
			ld a, (fs_devd)
			or a
			jp z, fs_strout
			ld hl, fs_n_disc
			jp fs_strout

; SelectDevice(name): "TAPE" or "DISC" (any case). OK, NotFound
fs_select:
			call fs_start
			ld hl, (fs_a1)
			ld de, fs_n_tape
			call fs_same
			jr z, fs_se_tape
			ld hl, (fs_a1)
			ld de, fs_n_disc
			call fs_same
			jr nz, fs_se_bad
			ld a, (fs_dos)
			or a
			jr z, fs_se_bad		; no DOS: no disc
			ld hl, fs_c_disc
			call fs_rsx
			ld a, 1
			jr fs_se_done
fs_se_tape:
			ld a, (fs_dos)
			or a
			jr z, fs_se_t2		; no DOS: tape anyway
			ld hl, fs_c_tape
			call fs_rsx
fs_se_t2:
			xor a
fs_se_done:
			ld (fs_devd), a
			ld hl, 0
			ret
fs_se_bad:
			ld hl, FS_NOTFOUND
			ret

; Volumes(): the volumes that worked so far ("A,C")
fs_volumes:
			call fs_start
			ld hl, fs_vols
			jp fs_strout

; CurrentVolume(): the volume last selected ("" = not known)
fs_curvol:
			call fs_start
			ld hl, fs_vol
			jp fs_strout

; SelectVolume(name): runs the DOS's command of that name (|A, |B, |C, |M ... whatever
; the DOS has). OK, NotFound (no such command). It joins Volumes()
fs_selvol:
			call fs_start
			ld hl, (fs_a1)
			call fs_volname
			jr nz, fs_se_bad
			ld hl, fs_rsxn
			call fs_rsx
			ld hl, fs_tmpn
			ld de, fs_vol
			ld bc, 9
			ldir
			ld hl, fs_tmpn
			call fs_addvol
			ld hl, 0
			ret

; Command(name): run a ROM's command (an RSX: |NAME) with no arguments - AMSDOS, M4,
; a utility ROM ... OK, NotFound (no ROM has it). Up to 16 letters
fs_command:
			call fs_start
			ld hl, (fs_a1)
			ld de, fs_rsxn
			ld b, 0
fs_cm_lp:
			ld a, (hl)
			or a
			jr z, fs_cm_end
			call fs_up
			ld (de), a
			inc hl
			inc de
			inc b
			ld a, b
			cp 17
			jr c, fs_cm_lp
fs_cm_bad:
			ld hl, FS_NOTFOUND
			ret
fs_cm_end:
			ld a, b
			or a
			jr z, fs_cm_bad
			dec de
			ld a, (de)
			or #80
			ld (de), a
			ld hl, fs_rsxn
			call fs_rsx
			ld hl, 0
			ret

fs_up:
			cp 'a'
			ret c
			cp 'z' + 1
			ret nc
			sub 32
			ret

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
			call fs_start
			ld a, (fs_hmode)	; the buffer is the open file's
			or a
			ld hl, FS_FAILED
			jp nz, fs_err
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
			push hl
			call fs_namevol
			pop hl
			ret

; Save(name, addr, len): a binary file (type 2, BASIC can LOAD it back). 0 or a status
fs_save:
			call fs_start
			ld a, (fs_hmode)	; the buffer is the open file's
			or a
			ld hl, FS_FAILED
			jp nz, fs_err
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
			ld hl, FS_FAILED
			ret nc
			call fs_namevol
			ld hl, 0
			ret

;## ntc_plat_fsseq ntc_plat_fs @shared
; ---- one open file (handle 1), through CAS IN CHAR / CAS OUT CHAR: read a
; file (any type) byte by byte, or write a new text file (type ASCII, as
; BASIC's OPENOUT / PRINT #9 make it). The 2K buffer is the one Load / Save
; use, so Load and Save are refused while a file is open.
FS_NOHANDLE	equ -5
FS_BADHANDLE	equ -6
FS_EOFST	equ -7
FS_BADMODE	equ -11
FS_NOTSUP	equ -1
fs_ptr:			dw 0
fs_cnt:			db 0
fs_cap:			db 0

; Open(name, mode): 1, or a status. ForUpdate: NotSupported
fs_open:
			call fs_start
			ld a, (fs_hmode)
			or a
			ld hl, FS_NOHANDLE
			ret nz
			ld hl, (fs_a2)
			ld a, h
			or a
			jr nz, fs_op_bad
			ld a, l
			cp 4
			jr z, fs_op_in			; ForReadRaw
			cp 3
			ld hl, FS_NOTSUP
			ret z
			jr nc, fs_op_bad
			cp 1
			jr c, fs_op_bad
			jr nz, fs_op_out
fs_op_in:
			ld (fs_raw), a			; 4: raw (a #1A is data), 1: not
			ld hl, fs_pend
			ld (hl), 0
			call fs_name
			ld de, fs_buf
			call #BC77			; CAS IN OPEN
			ld hl, FS_NOTFOUND
			ret nc
			ld (fs_ftype), a
			ld a, 1
			jr fs_op_ok
fs_op_out:
			call fs_name
			ld de, fs_buf
			call #BC8C			; CAS OUT OPEN
			ld hl, FS_FAILED
			ret nc
			ld a, 2
fs_op_ok:
			ld (fs_hmode), a
			ld hl, 1
			ret
fs_op_bad:
			ld hl, FS_BADMODE
			ret

; fs_hchk - (fs_a1) must be handle 1 open for A (1 read, 2 write), else
; fs_err BadHandle
fs_hchk:
			ld hl, (fs_a1)
			dec hl
			ld b, a
			ld a, h
			or l
			jr nz, fs_hc_bad
			ld a, (fs_hmode)
			cp b
			ret z
fs_hc_bad:
			ld hl, FS_BADHANDLE
			jp fs_err

; Close(h): OK, or a status (Failed: the last of a written file didn't go)
fs_closeh:
			ld hl, (fs_a1)
			dec hl
			ld a, h
			or l
			jr nz, fs_hc_bad
			ld a, (fs_hmode)
			or a
			jr z, fs_hc_bad
			ld b, a
			xor a
			ld (fs_hmode), a
			ld a, b
			cp 1
			jr nz, fs_cl_out
			call #BC7A			; CAS IN CLOSE
			jr fs_cl_ok
fs_cl_out:
			call #BC8F			; CAS OUT CLOSE
			ld hl, FS_FAILED
			ret nc
fs_cl_ok:
			call fs_namevol
			ld hl, 0
			ret

; ReadByte(h): 0-255, or EndOfFile
fs_readb:
			ld a, 1
			call fs_hchk
			call fs_inchar
			ld hl, FS_EOFST
			ret nc
			ld l, a
			ld h, 0
			ret

; WriteByte(h, b): OK, or Failed
fs_writeb:
			ld a, 2
			call fs_hchk
			ld a, (fs_a2)
			call #BC95			; CAS OUT CHAR
			ld hl, FS_FAILED
			ret nc
			ld hl, 0
			ret

; fs_inchar - CAS IN CHAR for ReadByte / Read: in a binary file AMSDOS still reports a #1A
; byte as the soft end of file (no carry, A = #1A) and goes on after it: that is the byte
; #1A. The same in any file opened ForReadRaw (a file with no header: AMSDOS calls it ASCII
; text, but the real end is the hard one, #0F, after the last record). Carry = a byte in A;
; no carry = the end (or an error)
fs_inchar:
			ld a, (fs_pend)
			or a
			jr z, fs_ic_rd
			xor a
			ld (fs_pend), a
			ld a, (fs_pendc)		; the byte Eof read ahead
			scf
			ret
fs_ic_rd:
			call #BC80			; CAS IN CHAR
			ret c
			cp #1A
			jr nz, fs_ic_end
			ld a, (fs_raw)
			cp 4
			ld a, #1A
			scf
			ret z				; raw: the byte #1A
			ld a, (fs_ftype)
			and #0E
			cp 2
			ld a, #1A
			scf
			ret z				; binary: the byte #1A
fs_ic_end:
			or a
			ret
fs_raw:			db 0			; Open for reading: 4 = ForReadRaw
fs_pend:		db 0			; 1: Eof read a byte ahead, in fs_pendc
fs_pendc:		db 0
fs_ftype:		db 0			; Open for reading: the file's type (CAS IN OPEN's A: 2 binary, #16 ASCII)

; Read(h, addr, count): bytes read (fewer at the end)
fs_read:
			ld a, 1
			call fs_hchk
			ld hl, (fs_a2)
			ld de, (fs_a3)
			ld bc, 0
fs_rd_lp:
			ld a, d
			or e
			jr z, fs_rd_end
			bit 7, d
			jr nz, fs_rd_end
			push hl
			push de
			push bc
			call fs_inchar
			pop bc
			pop de
			pop hl
			jr nc, fs_rd_end
			ld (hl), a
			inc hl
			inc bc
			dec de
			jr fs_rd_lp
fs_rd_end:
			ld h, b
			ld l, c
			ret

; Write(h, addr, count): count, or Failed
fs_write:
			ld a, 2
			call fs_hchk
			ld hl, (fs_a2)
			ld de, (fs_a3)
fs_wr_lp:
			ld a, d
			or e
			jr z, fs_wr_end
			bit 7, d
			jr nz, fs_wr_end
			ld a, (hl)
			push hl
			push de
			call #BC95			; CAS OUT CHAR
			pop de
			pop hl
			jr nc, fs_wr_fail
			inc hl
			dec de
			jr fs_wr_lp
fs_wr_end:
			ld hl, (fs_a3)
			ret
fs_wr_fail:
			ld hl, FS_FAILED
			ret

; Eof(h): True (-1) when there is nothing more to read (or h is not a file being read)
fs_eof:
			ld hl, (fs_a1)
			dec hl
			ld a, h
			or l
			jr nz, fs_ef_yes
			ld a, (fs_hmode)
			cp 1
			jr nz, fs_ef_yes
			call fs_inchar			; a byte read ahead (CAS TEST EOF at a #1A - a soft end
			ld hl, -1			; of file - loses bytes: the #1A and more)
			ret nc
			ld (fs_pendc), a
			ld a, 1
			ld (fs_pend), a
			ld hl, 0
			ret
fs_ef_yes:
			ld hl, -1
			ret

; ReadLine(h): the next line (up to LF; CR dropped), "" at the end
fs_readln:
			ld hl, (fs_res)
			ld (hl), 0
			dec hl
			ld a, (hl)
			ld (fs_cap), a			; the result's capacity
			inc hl
			ld (fs_ptr), hl
			xor a
			ld (fs_cnt), a
			ld a, 1
			call fs_hchk
fs_rl_lp:
			call fs_inchar
			jr nc, fs_rl_end
			cp 10
			jr z, fs_rl_end
			cp 13
			jr z, fs_rl_lp
			ld c, a
			ld a, (fs_cap)
			ld hl, fs_cnt
			cp (hl)
			jr z, fs_rl_lp			; full: the rest of the line is dropped
			inc (hl)
			ld hl, (fs_ptr)
			ld (hl), c
			inc hl
			ld (fs_ptr), hl
			jr fs_rl_lp
fs_rl_end:
			ld hl, (fs_ptr)
			ld (hl), 0
			ret

; WriteLine(h, s): the text and CR LF. OK, or Failed
fs_writeln:
			ld a, 2
			call fs_hchk
			ld hl, (fs_a2)
fs_wl_lp:
			ld a, (hl)
			or a
			jr z, fs_wl_end
			push hl
			call #BC95			; CAS OUT CHAR
			pop hl
			jp nc, fs_wr_fail
			inc hl
			jr fs_wl_lp
fs_wl_end:
			ld a, 13
			call #BC95
			jp nc, fs_wr_fail
			ld a, 10
			call #BC95
			jp nc, fs_wr_fail
			ld hl, 0
			ret

;## ntc_plat_memtop ntc_plat_data
; ntc_plat_memtop - HL = the first byte the Memory class's Small heap must not
; use: #A600 (the firmware's and AMSDOS's RAM is above), #A5F0 when the fast
; ticker's event block is there (Interrupt, interrupt classes). Called on the
; real stack (call / ret).
ntc_plat_memtop:
			ld hl, (ntc_fwtop)
			ret

;## ntc_plat_romsel @shared @ramonly
; rd_sel - A = a slot: that ROM in at #C000 (KL ROM SELECT: the upper ROM on,
; the firmware knows). rd_unsel - what was in before back (KL ROM DESELECT).
; From RAM only (@ramonly: never in the keyword ROM). Keep DE, HL (rd_unsel
; also AF)
rd_old:			dw 0
rd_sel:
			push hl
			push de
			ld c, a
			call #B90F			; KL ROM SELECT: B / C = the state and ROM before
			ld (rd_old), bc
			pop de
			pop hl
			ret
rd_unsel:
			push af
			push hl
			push de
			ld bc, (rd_old)
			call #B918			; KL ROM DESELECT
			pop de
			pop hl
			pop af
			ret

;## ntc_plat_rdroute ntc_plat_fs ntc_romdisc @shared @ramonly
; rd_route ... - a FileSystem method's way to the ROMDISC (volume R): HL =
; the fs_ routine, DE = the rd_ one, fs_a1 ... fs_res set. The rd_ routine
; is picked (fs_a1 .. fs_res copied to rd_a1 .. rd_res) when
;   rd_route / rd_route0:   the name at (fs_a1) is "R:..." - or has no volume
;                           and the volume in use is R
;   rd_routeh / rd_routeh0: fs_a1 is handle 2 (the ROMDISC's open file)
;   rd_routev:              the name is "R" (or "R:")
; then fs_go (the ..0 ones: fs_go0). Runs on the thread: no call, no push.
rd_rtf:			db 0
rd_rtd:			dw 0
rd_routev:
			ld a, 4
			jr rd_rt
rd_routeh0:
			ld a, 3
			jr rd_rt
rd_routeh:
			ld a, 2
			jr rd_rt
rd_route0:
			ld a, 1
			jr rd_rt
rd_route:
			xor a
rd_rt:
			ld (rd_rtf), a
			ld (rd_rtd), de
			bit 1, a
			jr nz, rd_rt_h
			bit 2, a
			jr nz, rd_rt_v
			ex de, hl				; DE = the fs_ routine
			ld hl, (fs_a1)
			inc hl
			ld a, (hl)
			dec hl
			cp ':'
			jr nz, rd_rt_cur
			ld a, (hl)
			or #20
			cp 'r'
			jr z, rd_rt_rd
			jr rd_rt_fs
rd_rt_cur:							; no volume in the name: the one in use
			ld a, (fs_vol)
			cp 'R'
			jr nz, rd_rt_fs
			ld a, (fs_vol + 1)
			or a
			jr z, rd_rt_rd
rd_rt_fs:
			ex de, hl				; HL = the fs_ routine
			jr rd_rt_go
rd_rt_h:
			ex de, hl
			ld hl, (fs_a1)
			ld a, h
			or a
			jr nz, rd_rt_fs
			ld a, l
			cp 2
			jr z, rd_rt_rd
			jr rd_rt_fs
rd_rt_v:
			ex de, hl
			ld hl, (fs_a1)
			ld a, (hl)
			or #20
			cp 'r'
			jr nz, rd_rt_fs
			inc hl
			ld a, (hl)
			or a
			jr z, rd_rt_rd
			cp ':'
			jr nz, rd_rt_fs
			inc hl
			ld a, (hl)
			or a
			jr nz, rd_rt_fs
rd_rt_rd:
			ld hl, (fs_a1)
			ld (rd_a1), hl
			ld hl, (fs_a2)
			ld (rd_a2), hl
			ld hl, (fs_a3)
			ld (rd_a3), hl
			ld hl, (fs_res)
			ld (rd_res), hl
			ld hl, (rd_rtd)
rd_rt_go:
			ld a, (rd_rtf)
			rra
			jp c, fs_go0
			jp fs_go

; rd_fsvol - SelectVolume "R": the disc there, then R is the volume in use
; (names without one go to the disc) and joins Volumes()
rd_fsvol:
			call rd_selvol
			ld a, h
			or l
			ret nz
			ld hl, rd_vr
			ld de, fs_vol
			ld bc, 2
			ldir
			ld hl, rd_vr
			call fs_addvol
			ld hl, 0
			ret
rd_vr:			db "R", 0

; rd_nsl - NotSupported as a Long at (fs_res) (Size on a volume that can't)
rd_nsl:
			ld hl, (fs_res)
			ld a, #FF
			ld (hl), a
			inc hl
			ld (hl), a
			inc hl
			ld (hl), a
			inc hl
			ld (hl), a
			ret

;## ntc_plat_rmr ntc_plat_data
; ntc_plat_rmr - A = the gate array's ROM / mode byte now: the firmware keeps
; it in C' (B' = #7F), so Memory's CallBank can turn both ROMs off and put
; them back. Keeps BC, DE, HL.
ntc_plat_rmr:
			exx
			ld a, c
			exx
			ret

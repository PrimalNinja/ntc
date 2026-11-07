; ============================================================
; NTC Platform - TRS-80 Model III (Z80, direct video)   *** DRAFT ***
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; STATUS: compiles AND assembles (sjasmplus, Z80). Not yet run on a Model III /
; Model 4 (III mode) or an emulator. Grounded from Julian's "TRS-80 hardware,
; for NTC BASIC" notes (trs-80.com ports/RAM pages, MAME trs80m3.cpp). Points he
; marked (check) there are marked ;!!TRS here.
;
; THE MACHINE (Model III):
;   * Z80 @ 2.03 MHz. One flat block - no 16K window, no RAM pages (like the
;     SC-3000 / ColecoVision, but with much more RAM):
;       #0000-#37FF  ROM (incl. #0066 NMI, #0038 RST38)
;       #3800-#3BFF  keyboard matrix (memory-mapped, read only)
;       #3C00-#3FFF  video RAM, 64 x 16 characters (#00-#7F ASCII)
;       #4000 up     RAM (low RAM holds ROM/DOS vectors); user load ~#5200
;   * SP is the thread, so ANY interrupt or NMI that pushes while SP is the
;     thread wrecks it. Startup therefore: di; E4=0 (no disk NMI); E0=0 (no
;     maskable interrupts). Turbo-only for now, like the ColecoVision (normal-
;     mode clock handling not wired - see Frame).
;   * A push is only safe once SP is swapped to the real stack (ntc_csp). So the
;     console hooks, which write straight to #3C00, use NO call/push (pure memory
;     writes); only the key scan swaps SP (it shares one call/ret scan body).
;
; DISK (future FileSystem) - Julian's safe pattern, kept here as the reference:
;       ld (ntc_ip), sp         ; save the thread
;       ld sp, (ntc_csp)        ; a real stack
;       ld a, #80
;       out (#E4), a            ; NMI on INTRQ: the disk can interrupt now
;       ... the disk command, wait for it ...
;       xor a
;       out (#E4), a            ; NMI off again
;       ld sp, (ntc_ip)         ; back on the thread
;   While the NMI is on, its pushes land on the real stack. Better still, poll
;   the WD1793 busy bit at #F0 and never enable the NMI (only the DOS's own disk
;   routines need it).
; ============================================================
;@name     TRS-80 Model III (direct video)
;@org      #5200
;@text     byte
;@scrinit  0
;@irq      0
;@stack    ntc_trs_stack
;@cols     64
;@rows     16
; ============================================================

;## ntc_plat_romhead ntc_plat_data
; The compiler puts this section FIRST, at ;@org (#5200) - it is the program's
; entry (the /CMD transfer address). Kill every interrupt source before the
; thread starts: a push from an NMI or INT while SP is the thread wrecks it.
ntc_trs_start:
			di
			xor a
			out (NMIMASK), a        ; E4 = 0: no disk NMI (INTRQ / DRQ off)
			out (INTMASK), a        ; E0 = 0: no maskable interrupts (turbo)
			jp ntc_start

;## ntc_plat_data ntc_data
VIDEO       equ #3C00               ; video RAM base
VIDCOLS     equ 64
VIDROWS     equ 16
VIDLAST     equ VIDEO + VIDCOLS*(VIDROWS-1)   ; #3FC0, start of the bottom row
INTMASK     equ #E0                 ; maskable interrupt mask (write) / status (read)
INTCLR      equ #EC                 ; read clears the 30Hz clock interrupt
NMIMASK     equ #E4                 ; NMI mask: bit7 INTRQ, bit6 DRQ; 0 = off  ;!!TRS
DOSRET      equ #402D               ; DOS return entry (TRSDOS 1.3 III; TRSDOS 2.3 / NEWDOS I) ;!!TRS

ntc_curx:   db 0                    ; column (0..63), counted for Tab
ntc_cury:   db 0                    ; row (0..15)
ntc_scols:  db 64
ntc_frames: dw 0                    ; frames counted by ntc_plat_frame (ntc_plat_ticks)
ntc_trs_stack equ ntc_end + 256     ; the real stack: the 256 bytes above the program image

;## ntc_plat_screen ntc_plat_data ntc_data
; routines here are entered via jp with IX = where to go next; they end jp (ix).
; No real stack: direct memory writes only, so no call / no push on the thread.

; ntc_plat_putc - A = character; write it at the cursor, advance (wrap -> newline)
ntc_plat_putc:
			ld c, a                     ; keep the char
			; HL = VIDEO + cury*64 + curx  (inline, no call)
			ld a, (ntc_cury)
			ld h, 0
			ld l, a
			add hl, hl                  ; *2
			add hl, hl                  ; *4
			add hl, hl                  ; *8
			add hl, hl                  ; *16
			add hl, hl                  ; *32
			add hl, hl                  ; *64
			ld a, (ntc_curx)
			ld e, a
			ld d, 0
			add hl, de
			ld de, VIDEO
			add hl, de
			ld (hl), c                  ; draw the character
			ld a, (ntc_curx)
			inc a
			cp VIDCOLS
			jr c, ntc_pc_col
			jp ntc_plat_newline         ; past column 63 -> newline
ntc_pc_col:
			ld (ntc_curx), a
			jp (ix)

; ntc_plat_newline - column 0, next row; scroll when past the bottom row
ntc_plat_newline:
			xor a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			inc a
			cp VIDROWS
			jr c, ntc_nl_row
			; scroll rows 1..15 up to 0..14, blank the bottom row (ldir, no push)
			ld hl, VIDEO + VIDCOLS
			ld de, VIDEO
			ld bc, VIDCOLS*(VIDROWS-1)  ; 960
			ldir
			ld hl, VIDLAST
			ld (hl), ' '
			ld de, VIDLAST + 1
			ld bc, VIDCOLS - 1
			ldir
			ld a, VIDROWS-1
ntc_nl_row:
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_backspace - back up a column and blank it
ntc_plat_backspace:
			ld a, (ntc_curx)
			or a
			jr z, ntc_bs_done
			dec a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			ld h, 0
			ld l, a
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl                  ; *64
			ld a, (ntc_curx)
			ld e, a
			ld d, 0
			add hl, de
			ld de, VIDEO
			add hl, de
			ld (hl), ' '
ntc_bs_done:
			jp (ix)

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_cls - fill the screen with spaces, home the cursor
ntc_plat_cls:
			ld hl, VIDEO
			ld de, VIDEO + 1
			ld bc, VIDCOLS*VIDROWS - 1  ; 1023
			ld (hl), ' '
			ldir
			xor a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - H = column, L = row, 1 based
ntc_plat_locate:
			ld a, h
			dec a
			ld (ntc_curx), a
			ld a, l
			dec a
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_mode - the Model III has one text mode; nothing to set
ntc_plat_mode:
			jp (ix)

;## ntc_plat_key ntc_plat_data ntc_data
; ntc_plat_scankey - A = ASCII of a held key, 0 if none.  ntc_plat_getkey - wait.
; Both swap SP to the real stack so the one scan body (ntc_trs_scan, call/ret)
; can be called safely, then swap back. ntc_trs_scan reads the matrix rows
; directly (#3800+2^row). Core subset: A-Z, 0-9, ENTER (13), SPACE (32).
; ;!!TRS SHIFT (#3880 bit0/bit1), the symbol keys (#3820 bits 2-7) and the CPC-
; style key numbers the Keys class wants are not mapped yet.
ntc_plat_scankey:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			call ntc_trs_scan
			ld sp, (ntc_ip)
			jp (ix)
ntc_plat_getkey:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
ntc_gk_wait:
			call ntc_trs_scan
			or a
			jr z, ntc_gk_wait
			ld sp, (ntc_ip)
			jp (ix)

; ntc_trs_scan - A = ASCII of a held key, 0 if none (call/ret, real stack)
ntc_trs_scan:
			ld hl, ntc_trs_ktab
ntc_sc_row:
			ld e, (hl)
			inc hl
			ld d, (hl)                  ; DE = row address (0 ends the table)
			inc hl
			ld a, d
			or e
			jr z, ntc_sc_r6             ; table end -> ENTER / SPACE row
			ld c, (hl)                  ; C = base char (bit 0)
			inc hl
			ld b, (hl)                  ; B = allowed-bit mask
			inc hl
			ld a, (de)
			and b
			jr z, ntc_sc_row            ; nothing held in this row
			ld b, c                     ; B = base char; find the lowest set bit
ntc_sc_bit:
			rra
			jr c, ntc_sc_hit
			inc b
			jr ntc_sc_bit
ntc_sc_hit:
			ld a, b
			ret
ntc_sc_r6:
			ld a, (#3840)               ; ENTER CLEAR BREAK arrows SPACE
			bit 0, a
			jr z, ntc_sc_sp
			ld a, 13                    ; ENTER
			ret
ntc_sc_sp:
			ld a, (#3840)
			bit 7, a
			jr z, ntc_sc_none
			ld a, 32                    ; SPACE
			ret
ntc_sc_none:
			xor a
			ret

; row-address / base-char / allowed-mask table (bit 0 = base char, bit n = base+n)
ntc_trs_ktab:
			dw #3801
			db '@', #FF                 ; @ A B C D E F G
			dw #3802
			db 'H', #FF                 ; H I J K L M N O
			dw #3804
			db 'P', #FF                 ; P Q R S T U V W
			dw #3808
			db 'X', #07                 ; X Y Z
			dw #3810
			db '0', #FF                 ; 0 1 2 3 4 5 6 7
			dw #3820
			db '8', #03                 ; 8 9 (bits 2-7 are : ; , - . /  ;!!TRS)
			dw 0

;## ntc_plat_frame ntc_plat_data ntc_data
; ntc_plat_frame - wait one 30Hz clock tick, count it. Polls the clock's status
; (E0 bit 2), clearing it by reading EC - no interrupt, no push (turbo pacing).
; ;!!TRS confirm E0 bit 2 / EC-clear behaviour with the mask written 0.
ntc_plat_frame:
			in a, (INTCLR)              ; clear any pending clock tick
ntc_fr_wait:
			in a, (INTMASK)             ; read status
			bit 2, a                    ; bit 2 = 30Hz real-time clock
			jr z, ntc_fr_wait
			ld hl, (ntc_frames)
			inc hl
			ld (ntc_frames), hl
			jp (ix)

;## ntc_plat_ticks ntc_plat_data ntc_data
; ntc_plat_ticks - HL = frames counted so far (advances only while Frame is
; called; TicksPerSecond = 30). ;!!TRS a true free-running count needs the clock
; interrupt wired to a handler (normal mode), not done yet.
ntc_plat_ticks:
			ld hl, (ntc_frames)
			jp (ix)

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - End: hand back to the DOS at its return entry (#402D).
ntc_plat_exit:
			jp DOSRET

;## ntc_plat_memtop ntc_plat_data
; ntc_plat_memtop - HL = first byte the Memory heap must not use (grows down from
; here). ;!!TRS #F000 is conservative; the DOS's MEMEND (TRSDOS 1.3 #4411) is the
; real ceiling - read it once the DOS is known.
ntc_plat_memtop:
			ld hl, #F000
			ret

;## ntc_plat_cmdline ntc_data
; A /CMD launch passes no command tail; CommandLine is empty.
ntc_cmdbuf:		ds 2
ntc_cmdsave:
			xor a
			ld (ntc_cmdbuf), a
			ret
ntc_cmdget:
			dec hl
			ld c, (hl)
			inc hl
			xor a
			ld (hl), a
			ret

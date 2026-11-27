; ============================================================
; NTC Platform - Enterprise 128, direct hardware
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The program is an EXOS program file (module type 5: a 16 byte header, then
; the program, loaded at #0100 and started there). The header is assembled
; with the program (ntc_plat_head), so sjasmplus --raw=GAME.COM writes the
; file itself. EXOS loads it and hands over its free memory; after that the
; program has the machine: its own screen, keyboard and interrupt, EXOS never
; called again. EXOS itself (its system segment, #FF) is left as it was.
;
; No call, no push: SP stays in the thread. Every routine is
; entered with jp, return address in IX, and ends with jp (ix).
;
; Memory  the Z80's four 16K pages, each any of the machine's 256 segments
;         (Dave's ports #B0-#B3):
;           page 0  #0000-#3FFF  the program (the segment EXOS loaded it into)
;           page 1  #4000-#7FFF  the program / its arrays - and the Memory
;                                class's window (Option Memory Heap Pages)
;           page 2  #8000-#BFFF  the program / its arrays (to #BCEF), the
;                                segment list #BD00-#BDFF (two notes for the
;                                Memory class under it), the real stack
;                                #BE00-#BFFF
;           page 3  #C000-#FFFF  the screen's segment (a video one, #FC-#FF)
;         At the start (ntc_plat_boot) every free segment is taken from EXOS
;         (function 24) - the ones a long program was loaded into are found
;         and put in their pages - and listed at EP_SEGS: the Memory class's pages are
;         those, all of them (a 4 MB machine: about 250). The segment EXOS
;         shares with its own data is handed back. Fewer than three free
;         segments, or no free video segment: a red border, the machine
;         stopped (an Enterprise 64 with no added RAM).
; Screen  Nick, 2 colours, 25 rows of 8 lines, the bitmap at #C000 (one byte
;         a character: 8 pixels). Mode 1 = 40 columns (LPIXEL, 40 bytes a
;         line), 2 = 80 columns (PIXEL, 80 bytes a line); 0 = 1, 3 = 2. The
;         line parameter table is at #FF00 in the same segment: the picture,
;         the borders and the frame's sync, 312 lines, 50 a second.
; Keys    the keyboard matrix: row 0-9 to port #B5, the columns read back
;         (0 = pressed). New presses only, no auto repeat.
; Font    NTC's own (the same glyphs as the Next's), copied to ntc_font.
; IRQ     normal mode only: Nick's frame interrupt through Dave (INT1, port
;         #B4), 50 a second, IM 1 - the handler goes to #0038 in the
;         program's own page 0.
; End     ntc_plat_exit: the machine starts again (EXOS's cold start).
; Test    NTC_EPLOG defined (sjasmplus -DNTC_EPLOG=1, test/epbuild.js --log):
;         what the console prints is also kept in a segment of its own -
;         "NTCLOG" at its start, the next free address at +8, 1 at +10 at
;         End (the machine then stops instead of starting again), the text
;         from +16 - for test/eprun.py.
; ============================================================
;@name     Enterprise 128 - direct hardware (an EXOS program file)
;@org      #0100
;@text     glyph
;@scrinit  1
;@irq      1
;@stack    #C000
;@head     ntc_plat_head
;@boot     ntc_plat_boot
;@cols     40
;@rows     25
;@irqrate  50
;@islc     1
;@reserved #BCF0,#0310 #C000,#4000	; the start code's notes #BCF0-#BCFF, the segment list #BD00-#BDFF, the stack #BE00-#BFFF, the screen's segment #C000-#FFFF
; ============================================================

;## ntc_plat_head
; EXOS's module header, the 16 bytes before the program (;@head: put before the org): 0, the
; type - 5, a program loaded at #0100 and started there - the program's length, 12 zeros.
; So the bytes sjasmplus --raw writes are the program file as it is, GAME.COM
			org #00F0
			db 0, 5
			dw ntc_end - #0100
			ds 12

;## ntc_plat_data
ntc_curx:		db 0			; cursor column (0 based)
ntc_cury:		db 0			; cursor row (0 based)
ntc_smode:		db 1			; screen mode (1: 40 columns, 2: 80)
ntc_sinit:		db 0			; 1 once the screen is set up
ntc_scols:		db 40			; columns = bytes a line
ntc_pgstk:		ds 32			; putglyph: the stack an interrupt uses between characters
ntc_pgstk_top:
ntc_noadv:		db 0			; 1 = draw without moving the cursor
ntc_wrapped:	db 0			; 1 = the last character wrapped to the next line
ntc_pgaddr:		dw 0			; draw / scroll address
ntc_klink:		dw 0			; return for ntc_plat_getkey
ntc_kidx:		db 0			; key index found by the scan
ntc_kcur:		ds 10			; matrix this scan (0 = pressed)
ntc_kprev:		db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ntc_irqset:		db 0			; 1 = our interrupt handler is at #38
ntc_irqhl:		dw 0			; handler scratch
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none
ep_fcnt:		db 0			; frames counted by the handler (ntc_plat_frame waits on it)

;## ntc_plat_boot
; ------------------------------------------------------------
; ntc_plat_boot - the start (;@boot: this section is the program's first
; bytes, straight after the di at #0100, and runs on into the rest of the
; start code). The memory from EXOS, then the machine taken over: the
; screen's segment in page 3, our line parameter table, Dave's interrupts
; off. Its variables are in it: page 0 is all that is sure to be in sight.
;
; How EXOS 2.1 leaves a program it has loaded: page 0 = its first segment;
; page 1 = the LAST segment it loaded into (a program over 16K), so for a
; program over 32K that is the third part, and the second part's segment
; is in no page; page 2 = EXOS's own segment, page 3 its ROM; the stack is
; EXOS's own (a call to EXOS made on it never comes back). So: a stack of
; our own first (#0100 down: the free bytes under the program), and Dave's
; interrupts off (EXOS's interrupt must not come once the pages change, and
; a call to EXOS can come back with interrupts on); the second
; part of a long program is found by asking EXOS to free every segment
; number - the one it agrees to is the only other one the program has (it
; is taken again with the rest).
; ------------------------------------------------------------
EP_SEGS		equ #BD00		; the free segments taken from EXOS, one byte each (ep_nseg of them)
EP_LPT		equ #FF00		; the line parameter table, in the screen's segment
EP_LOG		equ #C000		; (test) the log segment while it is in page 3
ntc_plat_boot:
			ld sp, #0100
			ld a, #AA					; Dave: every interrupt source off, its latches cleared - now, before
			out (#B4), a				; any call to EXOS (a call can come back with interrupts on, and an
										; EXOS interrupt once the pages are ours goes wrong)
			in a, (#B0)
			ld (ep_seg0), a
			in a, (#B1)
			ld (ep_seg1), a				; (a program over 16K: the last segment loaded)
			ld a, 1						; a page of the program may take EXOS's shared segment (a 64K
			ld (ep_keep), a				; machine has no other): see ep_bt_alloc
			ld a, high (ntc_end - 1)
			cp #40
			jr nc, ep_bt_two
			call ep_bt_alloc			; up to 16K: pages 1 and 2 are free segments
			jp nz, ep_bt_fail
			ld (ep_seg1), a
ep_bt_new2:
			call ep_bt_alloc
			jp nz, ep_bt_fail
			ld (ep_seg2), a
			jr ep_bt_have
ep_bt_two:
			cp #80						; up to 32K: page 1 is right as it is, page 2 a free segment
			jr c, ep_bt_new2
			ld a, (ep_seg1)				; over 32K: what is in page 1 is the third part - page 2's
			ld (ep_seg2), a
			ld b, 0
ep_bt_find:
			ld a, (ep_seg0)
			cp b
			jr z, ep_bt_fnext
			ld a, (ep_seg2)
			cp b
			jr z, ep_bt_fnext
			push bc
			ld c, b
			rst #30						; free segment C: only one of the program's own is freed
			db 25
			pop bc
			or a
			jr z, ep_bt_found
ep_bt_fnext:
			inc b
			jr nz, ep_bt_find
			jp ep_bt_fail
ep_bt_found:
			ld a, b
			ld (ep_seg1), a
ep_bt_have:
			di							; (EXOS may have let interrupts in)
			ld a, (ep_seg1)
			out (#B1), a
			ld a, (ep_seg2)
			out (#B2), a
			xor a
			ld (ep_nseg), a
			ld (ep_keep), a				; the pages: the shared segment is handed back
			ld a, (ep_share)			; the program is in the shared segment: EXOS's own data in it is
			or a						; ours to write over now, so EXOS is not called again
			jr nz, ep_bt_got
ep_bt_more:
			call ep_bt_alloc			; every free segment, to the list - but the program's own
			jr nz, ep_bt_got
			ld hl, ep_seg0
			cp (hl)
			jr z, ep_bt_more
			inc hl
			cp (hl)
			jr z, ep_bt_more
			inc hl
			cp (hl)
			jr z, ep_bt_more
			ld c, a
			ld a, (ep_nseg)
			ld l, a
			ld h, high EP_SEGS
			ld (hl), c
			inc a
			ld (ep_nseg), a
			cp 252
			jr nz, ep_bt_more
ep_bt_got:
			di
			ld a, (ep_nseg)				; the screen's segment: the highest one, a video one (#FC-#FF)
			or a
			jr z, ep_bt_sys				; none free (a 64K machine): EXOS's own segment
			ld b, a
			ld hl, EP_SEGS
			ld de, EP_SEGS
			ld c, 0
ep_bt_max:
			ld a, (hl)
			cp c
			jr c, ep_bt_low
			ld c, a
			ld e, l
ep_bt_low:
			inc hl
			djnz ep_bt_max
			ld a, c
			cp #FC
			jr c, ep_bt_sys
			ld (ep_vseg), a
			call ep_bt_drop				; out of the list (the last one takes its place)
			jr ep_bt_vok
ep_bt_sys:
			ld a, #FF					; no free video segment: the screen goes in EXOS's system segment
			ld (ep_vseg), a				; (#FF, always RAM the video chip shows). EXOS is not called
ep_bt_vok:								; again, and End is its cold start, which sets it up afresh
	IFDEF NTC_EPLOG
			ld a, (ep_nseg)				; (test) the log's segment: the last one in the list
			or a
			jp z, ep_bt_fail
			ld e, a
			dec e
			ld d, high EP_SEGS
			ld a, (de)
			ld (ep_logseg), a
			call ep_bt_drop
			ld a, (ep_logseg)
			out (#B3), a
			ld hl, ep_bt_sig
			ld de, EP_LOG
			ld bc, 16
			ldir
	ENDIF
			ld a, (ep_vseg)
			out (#B3), a
			ld hl, #C000				; the whole segment cleared
			ld de, #C001
			ld bc, #3FFF
			ld (hl), 0
			ldir
			ld hl, ep_lpt				; the line parameter table
			ld de, EP_LPT
			ld bc, ep_lpt_end - ep_lpt
			ldir
			ld a, (ep_vseg)				; the picture's address as Nick has it: its 64K is the
			and 3						; segments #FC-#FF, so (segment and 3) * #4000
			rrca
			rrca
			ld (EP_LPT + 5), a
			xor a
			out (#81), a				; border: black
			ld a, low ((EP_LPT and #3FFF) >> 4)	; Nick's table pointer: the address / 16, 12 bits
			out (#82), a
			ld a, (ep_vseg)
			and 3
			add a, a
			add a, a
			or high ((EP_LPT and #3FFF) >> 4)
			out (#83), a				; (bits 7, 6: 00, 01, 11 - the new pointer loaded, then running)
			or #40
			out (#83), a
			or #80
			out (#83), a
			ld a, (ep_seg1)				; for the Memory class (ntc_lib_ep.asm reads these two, at fixed
			ld (EP_SEGS - 2), a			; places: the library names no platform label)
			ld a, (ep_nseg)
			ld (EP_SEGS - 1), a
			jp ep_bt_done

; a free segment from EXOS: Z, A = it; NZ = no more (EXOS's shared segment - the one it
; keeps its own data in - is handed back)
ep_bt_alloc:
			rst #30
			db 24
			or a
			jr nz, ep_bt_anone
			ld a, c
			ret
ep_bt_anone:
			cp #7F						; (.SHARE: the shared segment was given - back it goes,
			jr nz, ep_bt_aerr			; unless it is for a page of the program: kept then)
			ld a, (ep_keep)
			or a
			jr z, ep_bt_agive
			ld (ep_share), a
			ld a, c
			cp a
			ret
ep_bt_agive:
			rst #30
			db 25
ep_bt_aerr:
			or 1
			ret
; the list's entry at DE out: the last one takes its place
ep_bt_drop:
			ld a, (ep_nseg)
			dec a
			ld (ep_nseg), a
			ld l, a
			ld h, high EP_SEGS
			ld a, (hl)
			ld (de), a
			ret
; not enough memory: a red border, stopped
ep_bt_fail:
			di
			ld a, #49
			out (#81), a
ep_bt_stop:
			halt
			jr ep_bt_stop
ep_seg0:		db 0			; the program's segments: page 0,
ep_seg1:		db 0			; page 1 (the Memory class's "main RAM" page),
ep_seg2:		db 0			; page 2
ep_vseg:		db 0			; the screen's segment (page 3)
ep_keep:		db 0			; 1 while a page of the program is asked for
ep_share:		db 0			; 1: the program took EXOS's shared segment
ep_nseg:		db 0			; segments in EP_SEGS: the Memory class's pages
	IFDEF NTC_EPLOG
ep_logseg:		db 0			; (test) the log's segment
ep_bt_sig:		db "NTCLOG", 0, 0
				dw EP_LOG + 16
				db 0, 0, 0, 0, 0, 0
	ENDIF
; the line parameter table: 16 bytes a block - 256 - lines, the mode byte, the left and
; right margins, the picture's address (LD1), LD2, 8 colours. 312 lines:
ep_lpt:
			db 256 - 200, #1E, 11, 51, 0, 0, 0, 0, #00, #FF, 0, 0, 0, 0, 0, 0	; the picture: 2 colours, LPIXEL (#12: PIXEL, 80 columns)
			db 256 - 47, #12, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0		; the bottom border
			db 256 - 3, #10, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0			; the frame's sync: 3 lines blank,
			db 256 - 4, #10, 6, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0			; 4 of sync,
			db 256 - 1, #90, 63, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0		; 1 with the interrupt (VINT),
			db 256 - 4, #12, 6, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0			; 4 blank
			db 256 - 53, #13, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0		; the top border; back to the first block
ep_lpt_end:
ep_bt_done:

; (ntc_plat_scroll, ntc_plat_cls: their own section)
;## ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
; ------------------------------------------------------------
; ntc_plat_putc - A = character 32-126 (others print as ?), draw it
; ------------------------------------------------------------
ntc_plat_putc:
			sub 32
			jr c, ntc_pc_bad
			cp 95
			jr c, ntc_pc_ok
ntc_pc_bad:
			ld a, '?' - 32
ntc_pc_ok:
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_font
			add hl, de
			ex de, hl
			; fall into ntc_plat_putglyph

; ------------------------------------------------------------
; ntc_plat_putglyph - DE = 8 byte glyph, draw at the cursor, move on
; ------------------------------------------------------------
ntc_plat_putglyph:
	IFDEF NTC_EPLOG
			ld a, (ntc_noadv)		; (test) the character to the log: the glyph's place in ntc_font
			or a					; (not the blank a backspace draws)
			jr nz, ntc_pg_logged
			ld hl, -ntc_font
			add hl, de
			srl h
			rr l
			srl h
			rr l
			srl h
			rr l
			ld a, l
			add a, 32
			ld c, a
			ld (ntc_pgaddr), ix
			ld ix, ntc_pg_logged0
			jp ep_log
ntc_pg_logged0:
			ld ix, (ntc_pgaddr)
ntc_pg_logged:
	ENDIF
			ld a, (ntc_cury)
			ld l, a
			ld h, 0
			ld b, h
			ld c, l
			add hl, hl
			add hl, hl
			add hl, bc			; row * 5
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl			; row * 320: 8 lines of 40 bytes
			ld a, (ntc_scols)
			ld c, a
			cp 80
			jr nz, ntc_pg_40
			add hl, hl			; 80 bytes a line
ntc_pg_40:
			ld a, (ntc_curx)
			add a, l
			ld l, a
			ld a, h
			adc a, #C0
			ld h, a				; HL = #C000 + row * 8 lines + column, BC = bytes a line
			ld a, 8
ntc_pg_lp:
			ex af, af'
			ld a, (de)
			inc de
			ld (hl), a
			add hl, bc
			ex af, af'
			dec a
			jr nz, ntc_pg_lp
			ld a, (ntc_nmode)		; normal mode: a waiting interrupt gets in after each
			or a					; character (drawing text is long), on a stack of its own
			jr z, ntc_pg_adv		; (SP may be the thread or the real stack here)
			ld (ntc_pgaddr), sp
			ld sp, ntc_pgstk_top
			ei
			nop
			di
			ld sp, (ntc_pgaddr)
ntc_pg_adv:
			ld a, (ntc_noadv)
			or a
			jr nz, ntc_pg_noadv
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			ld (ntc_curx), a
			cp b
			jr z, ntc_pg_wrap
			xor a
			ld (ntc_wrapped), a
			jp (ix)
ntc_pg_wrap:
			ld a, 1				; wrapped: a new line straight after does nothing
			ld (ntc_wrapped), a
			jr ntc_nl_do
ntc_pg_noadv:
			xor a
			ld (ntc_noadv), a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_newline - column 0, next row, scroll at the bottom. Straight
; after a wrap at the last column it does nothing
; ------------------------------------------------------------
ntc_plat_newline:
	IFDEF NTC_EPLOG
			ld (ntc_pgaddr), ix
			ld c, 10
			ld ix, ntc_nl_logged
			jp ep_log
ntc_nl_logged:
			ld ix, (ntc_pgaddr)
	ENDIF
			ld a, (ntc_wrapped)
			or a
			jr z, ntc_nl_do
			xor a
			ld (ntc_wrapped), a
			jp (ix)
ntc_nl_do:
			xor a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			inc a
			cp 25
			jp nc, ntc_plat_scroll
			ld (ntc_cury), a
			jp (ix)

	IFDEF NTC_EPLOG
; (test) ep_log - C = a character: to the log segment (page 3 for a moment: the picture
; goes on, Nick reads its own segments). Interrupts are off here. Keeps C, DE; ends jp (ix)
ep_log:
			ld a, (ep_logseg)
			out (#B3), a
			ld hl, (EP_LOG + 8)
			ld a, h
			or a
			jr z, ep_log_full
			ld (hl), c
			inc hl
			ld (EP_LOG + 8), hl
ep_log_full:
			ld a, (ep_vseg)
			out (#B3), a
			jp (ix)
	ENDIF

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
; ------------------------------------------------------------
; ntc_plat_backspace - cursor back one and blank that cell
; ------------------------------------------------------------
ntc_plat_backspace:
	IFDEF NTC_EPLOG
			ld (ntc_pgaddr), ix
			ld c, 8
			ld ix, ntc_bs_logged
			jp ep_log
ntc_bs_logged:
			ld ix, (ntc_pgaddr)
	ENDIF
			xor a
			ld (ntc_wrapped), a
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
			ld a, 1
			ld (ntc_noadv), a
			ld de, ntc_font		; space
			jp ntc_plat_putglyph
ntc_bs_none:
			jp (ix)

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
; ------------------------------------------------------------
; ntc_plat_mode - A = mode: 0, 1 = 40 columns, 2, 3 = 80. The picture's
; block of the line parameter table gets the mode, the screen is cleared
; ------------------------------------------------------------
ntc_plat_mode:
			cp 2
			ld a, 1
			jr c, ntc_md_ok
			inc a
ntc_md_ok:
			ld (ntc_smode), a
			ld a, (ntc_sinit)
			or a
			jr nz, ntc_md_set
			ld hl, ntc_epfont		; the first time: the font to ntc_font
			ld de, ntc_font
			ld bc, 95 * 8
			ldir
			ld a, 1
			ld (ntc_sinit), a
ntc_md_set:
			ld a, (ntc_smode)
			cp 2
			ld bc, 40 * 256 + #1E	; 40 columns: LPIXEL, a byte is 8 wide pixels
			jr nz, ntc_md_lpt
			ld bc, 80 * 256 + #12	; 80 columns: PIXEL
ntc_md_lpt:
			ld a, b
			ld (ntc_scols), a
			ld a, c
			ld (EP_LPT + 1), a
			jp ntc_plat_cls

; NTC's font, characters 32-126 (the Amstrad CPC's shapes, as on the Next) - 8 bytes
; each, bit 7 the leftmost pixel
ntc_epfont:
			db #00, #00, #00, #00, #00, #00, #00, #00	; 32 
			db #18, #18, #18, #18, #18, #00, #18, #00	; 33 !
			db #6C, #6C, #6C, #00, #00, #00, #00, #00	; 34 "
			db #6C, #6C, #FE, #6C, #FE, #6C, #6C, #00	; 35 #
			db #18, #3E, #58, #3C, #1A, #7C, #18, #00	; 36 $
			db #00, #C6, #CC, #18, #30, #66, #C6, #00	; 37 %
			db #38, #6C, #38, #76, #DC, #CC, #76, #00	; 38 &
			db #18, #18, #30, #00, #00, #00, #00, #00	; 39 '
			db #0C, #18, #30, #30, #30, #18, #0C, #00	; 40 (
			db #30, #18, #0C, #0C, #0C, #18, #30, #00	; 41 )
			db #00, #66, #3C, #FF, #3C, #66, #00, #00	; 42 *
			db #00, #18, #18, #7E, #18, #18, #00, #00	; 43 +
			db #00, #00, #00, #00, #00, #18, #18, #30	; 44 ,
			db #00, #00, #00, #7E, #00, #00, #00, #00	; 45 -
			db #00, #00, #00, #00, #00, #18, #18, #00	; 46 .
			db #06, #0C, #18, #30, #60, #C0, #80, #00	; 47 /
			db #7C, #C6, #CE, #D6, #E6, #C6, #7C, #00	; 48 0
			db #18, #38, #18, #18, #18, #18, #7E, #00	; 49 1
			db #3C, #66, #06, #3C, #60, #66, #7E, #00	; 50 2
			db #3C, #66, #06, #1C, #06, #66, #3C, #00	; 51 3
			db #1C, #3C, #6C, #CC, #FE, #0C, #1E, #00	; 52 4
			db #7E, #62, #60, #7C, #06, #66, #3C, #00	; 53 5
			db #3C, #66, #60, #7C, #66, #66, #3C, #00	; 54 6
			db #7E, #66, #06, #0C, #18, #18, #18, #00	; 55 7
			db #3C, #66, #66, #3C, #66, #66, #3C, #00	; 56 8
			db #3C, #66, #66, #3E, #06, #66, #3C, #00	; 57 9
			db #00, #00, #18, #18, #00, #18, #18, #00	; 58 :
			db #00, #00, #18, #18, #00, #18, #18, #30	; 59 ;
			db #0C, #18, #30, #60, #30, #18, #0C, #00	; 60 <
			db #00, #00, #7E, #00, #00, #7E, #00, #00	; 61 =
			db #60, #30, #18, #0C, #18, #30, #60, #00	; 62 >
			db #3C, #66, #66, #0C, #18, #00, #18, #00	; 63 ?
			db #7C, #C6, #DE, #DE, #DE, #C0, #7C, #00	; 64 @
			db #18, #3C, #66, #66, #7E, #66, #66, #00	; 65 A
			db #FC, #66, #66, #7C, #66, #66, #FC, #00	; 66 B
			db #3C, #66, #C0, #C0, #C0, #66, #3C, #00	; 67 C
			db #F8, #6C, #66, #66, #66, #6C, #F8, #00	; 68 D
			db #FE, #62, #68, #78, #68, #62, #FE, #00	; 69 E
			db #FE, #62, #68, #78, #68, #60, #F0, #00	; 70 F
			db #3C, #66, #C0, #C0, #CE, #66, #3E, #00	; 71 G
			db #66, #66, #66, #7E, #66, #66, #66, #00	; 72 H
			db #7E, #18, #18, #18, #18, #18, #7E, #00	; 73 I
			db #1E, #0C, #0C, #0C, #CC, #CC, #78, #00	; 74 J
			db #E6, #66, #6C, #78, #6C, #66, #E6, #00	; 75 K
			db #F0, #60, #60, #60, #62, #66, #FE, #00	; 76 L
			db #C6, #EE, #FE, #FE, #D6, #C6, #C6, #00	; 77 M
			db #C6, #E6, #F6, #DE, #CE, #C6, #C6, #00	; 78 N
			db #38, #6C, #C6, #C6, #C6, #6C, #38, #00	; 79 O
			db #FC, #66, #66, #7C, #60, #60, #F0, #00	; 80 P
			db #38, #6C, #C6, #C6, #DA, #CC, #76, #00	; 81 Q
			db #FC, #66, #66, #7C, #6C, #66, #E6, #00	; 82 R
			db #3C, #66, #60, #3C, #06, #66, #3C, #00	; 83 S
			db #7E, #5A, #18, #18, #18, #18, #3C, #00	; 84 T
			db #66, #66, #66, #66, #66, #66, #3C, #00	; 85 U
			db #66, #66, #66, #66, #66, #3C, #18, #00	; 86 V
			db #C6, #C6, #C6, #D6, #FE, #EE, #C6, #00	; 87 W
			db #C6, #6C, #38, #38, #6C, #C6, #C6, #00	; 88 X
			db #66, #66, #66, #3C, #18, #18, #3C, #00	; 89 Y
			db #FE, #C6, #8C, #18, #32, #66, #FE, #00	; 90 Z
			db #3C, #30, #30, #30, #30, #30, #3C, #00	; 91 [
			db #C0, #60, #30, #18, #0C, #06, #02, #00	; 92 \
			db #3C, #0C, #0C, #0C, #0C, #0C, #3C, #00	; 93 ]
			db #18, #3C, #7E, #18, #18, #18, #18, #00	; 94 ^
			db #00, #00, #00, #00, #00, #00, #00, #FF	; 95 _
			db #30, #18, #0C, #00, #00, #00, #00, #00	; 96 `
			db #00, #00, #78, #0C, #7C, #CC, #76, #00	; 97 a
			db #E0, #60, #7C, #66, #66, #66, #DC, #00	; 98 b
			db #00, #00, #3C, #66, #60, #66, #3C, #00	; 99 c
			db #1C, #0C, #7C, #CC, #CC, #CC, #76, #00	; 100 d
			db #00, #00, #3C, #66, #7E, #60, #3C, #00	; 101 e
			db #1C, #36, #30, #78, #30, #30, #78, #00	; 102 f
			db #00, #00, #3E, #66, #66, #3E, #06, #7C	; 103 g
			db #E0, #60, #6C, #76, #66, #66, #E6, #00	; 104 h
			db #18, #00, #38, #18, #18, #18, #3C, #00	; 105 i
			db #06, #00, #0E, #06, #06, #66, #66, #3C	; 106 j
			db #E0, #60, #66, #6C, #78, #6C, #E6, #00	; 107 k
			db #38, #18, #18, #18, #18, #18, #3C, #00	; 108 l
			db #00, #00, #6C, #FE, #D6, #D6, #C6, #00	; 109 m
			db #00, #00, #DC, #66, #66, #66, #66, #00	; 110 n
			db #00, #00, #3C, #66, #66, #66, #3C, #00	; 111 o
			db #00, #00, #DC, #66, #66, #7C, #60, #F0	; 112 p
			db #00, #00, #76, #CC, #CC, #7C, #0C, #1E	; 113 q
			db #00, #00, #DC, #76, #60, #60, #F0, #00	; 114 r
			db #00, #00, #3C, #60, #3C, #06, #7C, #00	; 115 s
			db #30, #30, #7C, #30, #30, #36, #1C, #00	; 116 t
			db #00, #00, #66, #66, #66, #66, #3E, #00	; 117 u
			db #00, #00, #66, #66, #66, #3C, #18, #00	; 118 v
			db #00, #00, #C6, #D6, #D6, #FE, #6C, #00	; 119 w
			db #00, #00, #C6, #6C, #38, #6C, #C6, #00	; 120 x
			db #00, #00, #66, #66, #66, #3E, #06, #7C	; 121 y
			db #00, #00, #7E, #4C, #18, #32, #7E, #00	; 122 z
			db #0E, #18, #18, #70, #18, #18, #0E, #00	; 123 {
			db #18, #18, #18, #18, #18, #18, #18, #00	; 124 |
			db #70, #18, #18, #0E, #18, #18, #70, #00	; 125 }
			db #76, #DC, #00, #00, #00, #00, #00, #00	; 126 ~

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_font ntc_data ntc_plat_scroll @shared
; ------------------------------------------------------------
; ntc_plat_locate - H = column, L = row, 1 based, kept on screen
; ------------------------------------------------------------
ntc_plat_locate:
			xor a
			ld (ntc_wrapped), a
			ld a, h
			or a
			jr z, ntc_lc_x0
			dec a
ntc_lc_x0:
			ld c, a
			ld a, (ntc_scols)
			dec a
			cp c
			jr c, ntc_lc_xmax
			ld a, c
ntc_lc_xmax:
			ld (ntc_curx), a
			ld a, l
			or a
			jr z, ntc_lc_y0
			dec a
ntc_lc_y0:
			cp 25
			jr c, ntc_lc_ymax
			ld a, 24
ntc_lc_ymax:
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_scroll ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_scroll - move rows 1-24 up one, clear row 24
; ------------------------------------------------------------
ntc_plat_scroll:
			ld a, 24
			ld (ntc_cury), a
			ld a, (ntc_nmode)		; normal mode: interrupts in during the long copy
			or a
			jr z, ntc_sc_open
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_sc_open:
			ld hl, #C000 + 320		; 40 columns: a row is 320 bytes
			ld bc, 24 * 320
			ld a, (ntc_scols)
			cp 80
			jr nz, ntc_sc_copy
			ld hl, #C000 + 640
			ld bc, 24 * 640
ntc_sc_copy:
			ld de, #C000
			ldir
			ld h, d					; the last row: cleared (DE = its start)
			ld l, e
			ld (hl), 0
			inc de
			ld bc, 319
			cp 80
			jr nz, ntc_sc_clr
			ld bc, 639
ntc_sc_clr:
			ldir
			di
			ld a, (ntc_nmode)
			or a
			jr z, ntc_sc_close
			ld sp, (ntc_ip)
ntc_sc_close:
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_cls - clear the picture (16000 bytes: the line parameter table
; is above it), cursor home
; ------------------------------------------------------------
ntc_plat_cls:
			ld a, (ntc_nmode)		; normal mode: interrupts in during the long copy
			or a
			jr z, ntc_cl_open
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_cl_open:
			ld hl, #C000
			ld de, #C001
			ld bc, 16000 - 1
			ld (hl), 0
			ldir
			di
			ld a, (ntc_nmode)
			or a
			jr z, ntc_cl_close
			ld sp, (ntc_ip)
ntc_cl_close:
			xor a
			ld (ntc_wrapped), a
			ld (ntc_curx), a
			ld (ntc_cury), a
			jp (ix)

;## ntc_plat_key ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_scankey - A = ASCII of a key pressed since the last scan,
; 0 if none
; ------------------------------------------------------------
ntc_plat_scankey:
			ld hl, ntc_kcur
			xor a
ntc_ks_line:
			out (#B5), a			; the row
			ld c, a
			in a, (#B5)				; its columns (0 = pressed)
			ld (hl), a
			inc hl
			ld a, c
			inc a
			cp 10
			jr nz, ntc_ks_line
			ld a, #FF
			ld (ntc_kidx), a
			ld hl, ntc_kcur
			ld de, ntc_kprev
			ld iy, ntc_kign
			ld bc, #0A00		; B = 10 rows, C = key index
ntc_ks_find:
			ld a, (ntc_kidx)
			inc a
			jr nz, ntc_ks_next
			ld a, (hl)
			cpl
			ex de, hl
			and (hl)			; pressed now, released last scan
			ex de, hl
			and (iy+0)			; not shift / control / alt / lock
			jr z, ntc_ks_next
ntc_ks_bit:
			rrca
			jr c, ntc_ks_got
			inc c
			jr ntc_ks_bit
ntc_ks_got:
			ld a, c
			ld (ntc_kidx), a
ntc_ks_next:
			ld a, c
			and #F8
			add a, 8
			ld c, a
			inc hl
			inc de
			inc iy
			djnz ntc_ks_find
			ld hl, ntc_kcur
			ld de, ntc_kprev
			ld bc, 10
			ldir
			ld a, (ntc_kidx)
			cp #FF
			jr z, ntc_ks_none
			ld e, a
			ld d, 0
			ld hl, ntc_keymaps
			ld a, (ntc_kcur)
			bit 7, a			; left shift
			jr z, ntc_ks_map
			ld a, (ntc_kcur + 8)
			bit 5, a			; right shift
			jr z, ntc_ks_map
			ld hl, ntc_keymap
ntc_ks_map:
			add hl, de
			ld a, (hl)
			jp (ix)
ntc_ks_none:
			xor a
			jp (ix)

; ------------------------------------------------------------
; ntc_plat_getkey - wait for a key press, A = ASCII
; ------------------------------------------------------------
ntc_plat_getkey:
			ld (ntc_klink), ix
ntc_gk_scan:
			ld ix, ntc_gk_back
			jp ntc_plat_scankey
ntc_gk_back:
			or a
			jr nz, ntc_gk_done
			ld a, (ntc_nmode)		; normal mode: interrupts in while waiting
			or a
			jr z, ntc_gk_wait
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
ntc_gk_wait:
			ld bc, 1000			; about 6ms between scans (debounce)
ntc_gk_delay:
			dec bc
			ld a, b
			or c
			jr nz, ntc_gk_delay
			di
			ld a, (ntc_nmode)
			or a
			jr z, ntc_gk_scan
			ld sp, (ntc_ip)
			jr ntc_gk_scan
ntc_gk_done:
			ld ix, (ntc_klink)
			jp (ix)

; keys that never count as a press on their own (the shifts, CTRL, ALT, LOCK)
ntc_kign:		db #7F, #7D, #FF, #FF, #FF, #FF, #FF, #7F, #DF, #FF

; matrix row 0-9, bit 0-7 -> ASCII (0 = ignored)
ntc_keymap:
			db "n", 92, "b", "c", "v", "x", "z", 0			; n \ b c v x z shift
			db "h", 0, "g", "d", "f", "s", "a", 0			; h lock g d f s a ctrl
			db "u", "q", "y", "r", "t", "e", "w", 9			; u q y r t e w tab
			db "7", "1", "6", "4", "5", "3", "2", 27		; 7 1 6 4 5 3 2 esc
			db 0, 0, 0, 0, 0, 0, 0, 0						; f4 f8 f3 f6 f5 f7 f2 f1
			db "8", 0, "9", "-", "0", "^", 127, 0			; 8 - 9 minus 0 ^ erase
			db "j", 0, "k", ";", "l", ":", "]", 0			; j - k ; l : ]
			db 0, 0, 0, 0, 0, 0, 13, 0						; stop down right up hold left enter alt
			db "m", 127, ",", "/", ".", 0, " ", 0			; m del , / . shift space ins
			db "i", 0, "o", "@", "p", "[", 0, 0				; i - o @ p [
ntc_keymaps:
			db "N", "|", "B", "C", "V", "X", "Z", 0
			db "H", 0, "G", "D", "F", "S", "A", 0
			db "U", "Q", "Y", "R", "T", "E", "W", 9
			db 39, "!", "&", "$", "%", "#", 34, 27
			db 0, 0, 0, 0, 0, 0, 0, 0
			db "(", 0, ")", "=", "_", "~", 127, 0
			db "J", 0, "K", "+", "L", "*", "}", 0
			db 0, 0, 0, 0, 0, 0, 13, 0
			db "M", 127, "<", "?", ">", 0, " ", 0
			db "I", 0, "O", "`", "P", "{", 0, 0

;## ntc_plat_keys ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_keys - the Keys class: the matrix read at every call. Entered
; with jp from a method, the method's result pointer still on the thread:
; the result goes there and ret carries on. No stack used.
;   ep_kdown - HL = a key number 0-79 (row * 8 + bit): -1 held, 0 not
;   ep_kjoy  - HL = 0 the built in joystick (the cursor keys and Space),
;              1 / 2 the control ports: bits up 1, down 2, left 4, right 8,
;              fire 32
; ------------------------------------------------------------
ep_kdown:
			ld de, 0
			ld a, h
			or a
			jr nz, ep_k_set
			ld a, l
			cp 80
			jr nc, ep_k_set
			rrca
			rrca
			rrca
			and 31
			out (#B5), a			; its row
			ld a, l
			and 7
			ld b, a
			inc b
			in a, (#B5)
ep_kd_rot:
			rrca
			djnz ep_kd_rot
			jr c, ep_k_set			; 1 = not pressed
			dec de
			jr ep_k_set
ep_kjoy:
			ld a, l
			ld de, 0
			or a
			jr z, ep_kj_own
			cp 3
			jr nc, ep_k_set
			dec a					; a control port: rows 0-4 (port 1) or 5-9 (port 2), bit 0 of
			ld c, a					; port #B6 - fire, up, down, left, right
			add a, a
			add a, a
			add a, c
			ld c, a					; C = the port's first row
			ld hl, ep_kj_bits
			ld b, 5
ep_kj_row:
			ld a, c
			out (#B5), a
			in a, (#B6)
			rrca
			jr c, ep_kj_not
			ld a, (hl)
			or e
			ld e, a
ep_kj_not:
			inc hl
			inc c
			djnz ep_kj_row
			jr ep_k_set
ep_kj_own:
			ld a, 7					; row 7: down bit 1, right 2, up 3, left 5
			out (#B5), a
			in a, (#B5)
			cpl
			ld c, a
			bit 3, c
			jr z, ep_kj_o1
			set 0, e
ep_kj_o1:
			bit 1, c
			jr z, ep_kj_o2
			set 1, e
ep_kj_o2:
			bit 5, c
			jr z, ep_kj_o3
			set 2, e
ep_kj_o3:
			bit 2, c
			jr z, ep_kj_o4
			set 3, e
ep_kj_o4:
			ld a, 8					; row 8 bit 6: Space
			out (#B5), a
			in a, (#B5)
			bit 6, a
			jr nz, ep_k_set
			set 5, e
ep_k_set:
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret
ep_kj_bits:		db 32, 1, 2, 4, 8

;## ntc_plat_frame ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_frame - wait for the next frame. With the interrupt handler in
; (normal mode): until it has counted one. Without: Nick's frame line
; (VINT) read from Dave, port #B4 bit 4 - up for one line, then down
; ------------------------------------------------------------
ntc_plat_frame:
			ld a, (ntc_irqset)
			or a
			jr z, ntc_fr_poll
			ld a, (ntc_nmode)
			or a
			jr z, ntc_fr_poll
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ld hl, ep_fcnt
			ld a, (hl)
			ei
ntc_fr_cnt:
			cp (hl)
			jr z, ntc_fr_cnt
			di
			ld sp, (ntc_ip)
			jp (ix)
ntc_fr_poll:
			in a, (#B4)
			and #10
			jr z, ntc_fr_poll
ntc_fr_down:
			in a, (#B4)
			and #10
			jr nz, ntc_fr_down
			jp (ix)

;## ntc_plat_ticks ntc_data
; ------------------------------------------------------------
; ntc_plat_ticks - HL = interrupt count (50 a second, normal mode)
; ------------------------------------------------------------
ntc_plat_ticks:
			ld hl, (ntc_ticks)
			jp (ix)

;## ntc_plat_irq ntc_plat_data ntc_data ntc_plat_irqh @shared
; ------------------------------------------------------------
; ntc_plat_irqon - the interrupt handler to #38 (IM 1), Nick's frame
; interrupt on in Dave (INT1: port #B4 bit 4; bit 5 clears its latch)
; ------------------------------------------------------------
ntc_plat_irqon:
			ld a, #C3			; jp ntc_irq
			ld (#0038), a
			ld hl, ntc_irq
			ld (#0039), hl
			im 1
			ld a, 1
			ld (ntc_irqset), a
			ld a, #30
			out (#B4), a
			jp (ix)

;## ntc_plat_irqh ntc_plat_data ntc_data @shared
; the handler: runs on the real stack, between keywords. Counts ticks
; (50 a second). AF goes to AF', HL to RAM; interrupt classes' counting
; (ntc_irqv) is a call with 1 in C (every interrupt is a frame's), keeping
; the other registers.
ntc_irq:
			ex af, af'
			ld (ntc_irqhl), hl
			ld a, #30			; the latch cleared, the frame interrupt still on
			out (#B4), a
			ld hl, ep_fcnt
			inc (hl)
			ld hl, (ntc_ticks)
			inc hl
			ld (ntc_ticks), hl
			ld a, (ntc_hookon)	; an Interrupt hook: run it at the next safe point
			or a
			jr z, ntc_irq_nohook
			ld (ntc_hookpend), a
ntc_irq_nohook:
			ld hl, (ntc_irqv)		; interrupt classes (Option Class Interrupt): count them
			ld a, h
			or l
			jr z, ntc_irq_done
			push bc
			ld c, 1
			call ntc_irq_jp
			pop bc
ntc_irq_done:
			ld hl, (ntc_irqhl)
			ex af, af'
			ei
			ret
ntc_irq_jp:
			jp (hl)

;## ntc_plat_exit ntc_plat_data
; ------------------------------------------------------------
; ntc_plat_exit - End: the machine starts again. EXOS's ROM (segment 0)
; goes into page 0 and runs from its start - from 6 bytes put in the
; screen's segment, as page 0 is where this may be running
; ------------------------------------------------------------
ntc_plat_exit:
			di
	IFDEF NTC_EPLOG
			ld a, (ep_logseg)	; (test) the log is marked ended, the machine stops
			out (#B3), a
			ld a, 1
			ld (EP_LOG + 10), a
			ld a, (ep_vseg)
			out (#B3), a
ntc_ex_stop:
			halt
			jr ntc_ex_stop
	ELSE
			ld a, #AA
			out (#B4), a
			ld hl, ntc_ex_code
			ld de, #C000
			ld bc, 6
			ldir
			jp #C000
ntc_ex_code:
			xor a
			out (#B0), a
			jp 0
	ENDIF

;## ntc_plat_memtop
; ntc_plat_memtop - HL = the first byte the program's arrays and the Memory class's heap in
; main memory must not use: #BCF0 (the start code's notes, the segment list, then the stack).
; Called on the real stack (call / ret).
ntc_plat_memtop:
			ld hl, #BCF0
			ret

;## ntc_plat_rmr ntc_plat_data
; ntc_plat_rmr - no CPC gate array: the Memory class's CallBank asks for its ROM / mode
; byte; 0 (CallBank's own switch is the CPC's: not for Enterprise programs). Keeps BC, DE, HL
ntc_plat_rmr:
			xor a
			ret

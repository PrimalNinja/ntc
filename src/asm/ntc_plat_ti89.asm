; ============================================================
; NTC Platform - TI-89 / 92+ / Voyage 200 (68000, AMS)   *** SKELETON ***
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; STATUS: structural skeleton only. Rides the 68000 backend (as md / neogeo:
; A7 = thread in user mode, interrupts hit the supervisor stack, so they stay
; on). It COMPILES (NTC emits 68k asm); it is NOT assembled or run - there is
; no 68000 assembler (vasm) and no TI-68k emulator (TiEmu/TILEM) in the build
; box, same ceiling as the Neo Geo.
;
; *** HONESTY NOTE ***  Unlike the Z80 TI-83+ platform (whose header/bcall
; convention is grounded from the Cemetech / 83pa28d tutorials) and the Neo Geo
; (whose registers are grounded from the neogeo dev wiki), the TI-68k AMS
; specifics below are NOT grounded - the AMS references weren't reachable from
; this box. Every hardware value is a GUESS marked ;!!TI89?. Do not read any of
; them as confirmed. What IS real here is the NTC structure: the SP-as-thread
; fit, the hook set, the character-cell text blit, the newline/scroll logic.
;
; THE MACHINE (needs confirming):
;   * 68000 ~10-12 MHz. AMS owns the vectors; a program is a relocated nostub
;     image the kernel/AMS loads and jumps into (NOT a bare image with a vector
;     table at 0). So ntc_md_vectors here is just the entry glue; the real .89z
;     / .9xz / .v2z packaging (AMS program header + relocation table) is a
;     post-step, as the Z80 TI needs a .8xp packer and the Neo Geo a cart
;     packer. ;!!TI89? none of that is written.
;   * Mono LCD: 160x100 (89) or 240x128 (92+/V200), a bitmap in RAM. This file
;     defaults to the 240x128 geometry (30x16 chars at 8x8). The 89 differs.
;   * Text here is drawn DIRECTLY into the LCD bitmap with an 8x8 font (no AMS
;     ROM_CALL - the ROM_CALL table couldn't be grounded). A full font must be
;     linked at ntc_ti89_font.
; ============================================================
;@name     TI-89 / 92+ / V200 (68000, AMS)
;@cpu      68000
;@org      0
;@text     byte
;@scrinit  0
;@irq      0
;@cols     30
;@rows     16
; All hardware addresses live in the ntc_plat_data section below (values in a
; header comment are dropped by the generator).
; ============================================================

;## ntc_md_vectors ntc_ti89_boot
; (the 68k backend requires this section be named ntc_md_vectors - the generic
;  "68k start" slot. On AMS there is no program-owned vector table; this is just
;  the entry. ;!!TI89? the real AMS nostub header/reloc goes here - stubbed.)
			bra ntc_ti89_boot

;## ntc_ti89_boot ntc_plat_data ntc_data ntc_plat_screen
ntc_ti89_boot:
			; AMS entered us in user mode with a valid stack; clear the screen
			; and hand control to the thread (the compiler's start code follows,
			; sets A7 to the thread and runs).
			jsr ntc_ti89_clear
			rts

;## ntc_plat_data ntc_data
; ------------------------------------------------------------
; UNVERIFIED hardware values - every one is a guess.  ;!!TI89? confirm all.
; ------------------------------------------------------------
LCD_MEM     equ $4C00           ; LCD bitmap base in RAM          ;!!TI89? guess
ROWBYTES    equ 30              ; bytes per pixel row (240/8; the 89 is 20) ;!!TI89?
SCRROWS     equ 128             ; pixel rows (the 89 is 100)       ;!!TI89?

ntc_curx:   dc.w 0              ; text column (0..cols-1)
ntc_cury:   dc.w 0              ; text row (0..rows-1)
ntc_frames: dc.w 0              ; frame counter (ntc_plat_ticks)

;## ntc_plat_screen ntc_plat_data ntc_data
; platform routines: entered with jsr, end with rts (real stack), keeping
; d2-d7 / a2-a6 (the 68k backend's convention).

; ntc_ti89_celladdr - a0 = LCD byte address of the top row of cell (curx,cury).
; addr = LCD_MEM + cury*8*ROWBYTES + curx   (8px-wide font = 1 byte per column)
ntc_ti89_celladdr:
			move.w ntc_cury, d1
			lsl.w #3, d1               ; row * 8 pixel rows
			mulu #ROWBYTES, d1
			add.w ntc_curx, d1
			lea LCD_MEM, a0
			adda.w d1, a0
			rts

; ntc_plat_putc - d0.b = character 32..127: blit its 8x8 glyph, advance
ntc_plat_putc:
			and.w #$00FF, d0
			sub.w #32, d0
			bge.s ntc_pc_ok
			moveq #0, d0               ; below space -> space
ntc_pc_ok:
			lsl.w #3, d0               ; glyph = font + char*8
			lea ntc_ti89_font, a1
			adda.w d0, a1
			jsr ntc_ti89_celladdr
			moveq #7, d2               ; 8 rows
ntc_pc_row:
			move.b (a1)+, (a0)
			adda.w #ROWBYTES, a0
			dbra d2, ntc_pc_row
			addq.w #1, ntc_curx
			cmp.w #30, ntc_curx        ; cols ;!!TI89? (89 = 20)
			blt.s ntc_pc_done
			jsr ntc_plat_newline
ntc_pc_done:
			rts

; ntc_plat_newline - column 0, next row; scroll not done yet ;!!TI89? scroll
ntc_plat_newline:
			clr.w ntc_curx
			addq.w #1, ntc_cury
			cmp.w #16, ntc_cury        ; rows ;!!TI89? (89 = 12)
			blt.s ntc_nl_done
			move.w #15, ntc_cury
ntc_nl_done:
			rts

; ntc_ti89_clear - blank the whole LCD bitmap
ntc_ti89_clear:
			lea LCD_MEM, a0
			move.w #ROWBYTES*SCRROWS-1, d1
ntc_cl_lp:
			clr.b (a0)+
			dbra d1, ntc_cl_lp
			clr.w ntc_curx
			clr.w ntc_cury
			rts

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_backspace:
			tst.w ntc_curx
			beq.s ntc_bs_done
			subq.w #1, ntc_curx
			jsr ntc_ti89_celladdr
			moveq #7, d2
ntc_bs_lp:
			clr.b (a0)
			adda.w #ROWBYTES, a0
			dbra d2, ntc_bs_lp
ntc_bs_done:
			rts

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_cls:
			jmp ntc_ti89_clear

;## ntc_plat_locate @unit ntc_plat_screen ntc_plat_data ntc_data
; ntc_plat_locate - d0.w = column (1 based), d1.w = row (1 based)
ntc_plat_locate:
			subq.w #1, d0
			bge.s ntc_lc_x
			moveq #0, d0
ntc_lc_x:
			move.w d0, ntc_curx
			subq.w #1, d1
			bge.s ntc_lc_y
			moveq #0, d1
ntc_lc_y:
			move.w d1, ntc_cury
			rts

;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_mode:
			rts

;## ntc_plat_key ntc_plat_data ntc_data
; ntc_plat_scankey - d0.b = a key or 0.  ;!!TI89? the 68k calc key matrix is a
; memory-mapped port read (row strobe / column read); the exact addresses were
; NOT grounded, so this is a stub returning "no key". Wire the port + a code
; map before Inkey works. (An AMS build would ROM_CALL ngetchx instead.)
ntc_plat_scankey:
			moveq #0, d0               ; ;!!TI89? no key matrix read yet
			rts

; ntc_plat_getkey - wait for a key (spins on the stub above until wired)
ntc_plat_getkey:
			jsr ntc_plat_scankey
			tst.b d0
			beq.s ntc_plat_getkey
			rts

;## ntc_plat_frame ntc_plat_data ntc_data
; ntc_plat_frame - bump the counter. ;!!TI89? a real build waits the LCD frame
; (AMS keeps a timer; or poll the LCD controller).
ntc_plat_frame:
			addq.w #1, ntc_frames
			rts

;## ntc_plat_ticks ntc_plat_data ntc_data
; ntc_plat_ticks - d0.w = frame counter. ;!!TI89? AMS has a real timer to read.
ntc_plat_ticks:
			move.w ntc_frames, d0
			rts

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - return to AMS. ;!!TI89? a nostub program returns with rts to
; the kernel; this restores nothing special yet.
ntc_plat_exit:
			rts

;## ntc_ti89_font ntc_plat_data
; 8x8 font, chars 32..127, 8 bytes each (bit 7 = leftmost pixel). ;!!TI89? only
; space and '?' are filled as a placeholder - LINK A FULL 96-CHAR 8x8 FONT here
; (the public-domain font8x8_basic NTC already uses on the CPC stand-in fits).
ntc_ti89_font:
			; 32 space
			dc.b 0,0,0,0,0,0,0,0
			; the remaining 95 glyphs - placeholder '?' block so the blit is real
ntc_ti89_font_fill:
			dc.b $00,$3C,$66,$0C,$18,$00,$18,$00    ; a '?' shape, reused ;!!TI89?
			ds.b 8*94, 0                            ; 33..127 blank ;!!TI89? real font

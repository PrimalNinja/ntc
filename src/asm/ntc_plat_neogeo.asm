; ============================================================
; NTC Platform - SNK Neo Geo (68000, cartridge)   *** DRAFT / UNASSEMBLED ***
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; STATUS: scaffold. Rides the 68000 backend (as md). The 68k runs the game
; (A7 = thread in user mode; interrupts hit the supervisor stack, never the
; thread - same as md, so interrupts stay on). Sound is a SEPARATE Z80 driver
; (asm/neogeo_sound_z80.asm), reached only through REG_SOUND.
;
; THIS CANNOT BE ASSEMBLED OR RUN HERE - there is no 68000 assembler (vasm)
; and no Neo Geo emulator in the build box. It compiles (NTC emits 68k asm);
; it is NOT verified. Confirmed register addresses are from the Neo Geo dev
; wiki; everything marked ;!!NG (fix-layer VRAM base, palette RAM, the cart
; header/BIOS vectors, text font upload) must be checked in MAME before trust.
;
; CONFIRMED 68k registers (neogeodev wiki, "Memory mapped registers"):
REG_P1CNT   equ $300000     ; read P1: active-low D C B A Right Left Down Up
REG_DIPSW   equ $300001     ; read DIPs / WRITE kicks the watchdog
REG_SOUND   equ $320000     ; write = command to the Z80 sound CPU; read = its reply
REG_P2CNT   equ $340000     ; read P2 (same layout)
REG_STATUS_B equ $380000    ; read: b0 Start1 b1 Sel1 b2 Start2 b3 Sel2 (active low)
REG_VRAMADDR equ $3C0000    ; LSPC: set VRAM word address
REG_VRAMRW  equ $3C0002     ; LSPC: read/write VRAM data (MOD applied after a write)
REG_VRAMMOD equ $3C0004     ; LSPC: the auto-increment applied after each access
REG_PALBANK0 equ $3A000F    ; select palette bank 0
; NOT confirmed by the wiki page - set from the hardware refs, verify in MAME:
NG_FIXMAP   equ $7000       ; ;!!NG fix-layer tilemap base in VRAM (40x32, column-major)
NG_PALRAM   equ $400000     ; ;!!NG palette RAM base (68k side)
; ============================================================
;@name     SNK Neo Geo (68000)
;@cpu      68000
;@org      0
;@text     byte
;@scrinit  0
;@irq      0
;@cols     40
;@rows     32
; ============================================================

;## ntc_md_vectors ntc_ng_boot
; (the 68k backend requires this section be named ntc_md_vectors - it's the
;  generic "68k vectors + header + start" slot, named after the first 68k target)
; The 68000 vector table at 0, then the Neo Geo cart header / BIOS jump table.
; ;!!NG the real Neo Geo P-ROM header (the "NEO-GEO" marker, the USER and
; interrupt jump entries, the security/soft-DIP area) goes here - stubbed.
			dc.l $00100000          ; initial SSP (top of 68k work RAM) ;!!NG
			dc.l ntc_ng_boot        ; reset PC
			ds.l 62, 0              ; the rest of the 68000 vectors (IRQ, traps) ;!!NG wire VBlank
; ---- the cart header would follow here (ds to $100, the NEO-GEO marker ...) ;!!NG

;## ntc_ng_boot ntc_plat_data ntc_data ntc_plat_screen
ntc_ng_boot:
			move.w #$2700, sr          ; interrupts off during setup
			move.b d0, REG_DIPSW       ; kick the watchdog (any write)     ;!!NG value
			; clear the fix layer, set up the palette and a text font in fix tiles
			jsr ntc_ng_fixclear        ; (below)
			; hand control to the thread - the compiler's start code follows;
			; it sets A7 to the thread and runs. Interrupts get re-enabled there.
			; (ntc_plat_data / screen are pulled in as deps.)
			rts

;## ntc_plat_data ntc_data
ntc_curx:   dc.w 0                     ; fix-layer cursor column (0..39)
ntc_cury:   dc.w 0                     ; row (0..31)
ntc_frames: dc.w 0                     ; frame counter (ntc_plat_ticks)

;## ntc_plat_screen ntc_plat_data ntc_data
; the platform routines are entered with jsr and end with rts (real stack),
; keeping d2-d7 / a2-a6 (the 68k backend's convention).

; ntc_ng_fixaddr - d1.w = the VRAM word address of (ntc_curx, ntc_cury) in the
; fix map. The fix map is column-major: addr = NG_FIXMAP + col*32 + row.  ;!!NG layout
ntc_ng_fixaddr:
			move.w ntc_curx, d1
			lsl.w #5, d1               ; col * 32
			add.w ntc_cury, d1
			add.w #NG_FIXMAP, d1
			rts

; ntc_plat_putc - d0.b = character 32..126: write it as a fix tile, advance
ntc_plat_putc:
			jsr ntc_ng_fixaddr
			move.w d1, REG_VRAMADDR
			move.w #1, REG_VRAMMOD     ; (irrelevant for a single write)
			and.w #$00FF, d0
			; fix tile word = palette<<12 | char code ;!!NG tile numbering / font must be uploaded
			move.w d0, REG_VRAMRW
			addq.w #1, ntc_curx
			cmp.w #40, ntc_curx
			blt.s ntc_pc_done
			jsr ntc_plat_newline
ntc_pc_done:
			rts

; ntc_plat_newline - CR LF: column 0, next row (scroll not done yet) ;!!NG scroll
ntc_plat_newline:
			clr.w ntc_curx
			addq.w #1, ntc_cury
			cmp.w #32, ntc_cury
			blt.s ntc_nl_done
			move.w #31, ntc_cury
ntc_nl_done:
			rts

; ntc_ng_fixclear - blank the whole fix layer (space tile)   ;!!NG space tile index
ntc_ng_fixclear:
			move.w #NG_FIXMAP, REG_VRAMADDR
			move.w #1, REG_VRAMMOD
			move.w #40*32-1, d1
ntc_fc_lp:
			move.w #$0020, REG_VRAMRW
			dbra d1, ntc_fc_lp
			clr.w ntc_curx
			clr.w ntc_cury
			rts

;## ntc_plat_backspace @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_backspace:
			tst.w ntc_curx
			beq.s ntc_bs_done
			subq.w #1, ntc_curx
			jsr ntc_ng_fixaddr
			move.w d1, REG_VRAMADDR
			move.w #$0020, REG_VRAMRW
ntc_bs_done:
			rts

;## ntc_plat_cls @unit ntc_plat_screen ntc_plat_data ntc_data
ntc_plat_cls:
			jmp ntc_ng_fixclear

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
; ntc_plat_scankey - d0.b = a key or 0. Reads P1 (active low). Maps the stick
; to the CPC cursor codes and A/B/C to "A"/"B"/"C"; Start = 13.  ;!!NG bit map
ntc_plat_scankey:
			moveq #0, d0
			move.b REG_P1CNT, d1
			not.b d1                    ; active low -> 1 = pressed
			btst #4, d1                 ; A
			beq.s ntc_sk_b
			moveq #'A', d0
			rts
ntc_sk_b:
			btst #5, d1                 ; B
			beq.s ntc_sk_start
			moveq #'B', d0
			rts
ntc_sk_start:
			move.b REG_STATUS_B, d1
			not.b d1
			btst #0, d1                 ; Start P1
			beq.s ntc_sk_none
			moveq #13, d0
ntc_sk_none:
			rts

; ntc_plat_getkey - wait for a key
ntc_plat_getkey:
			jsr ntc_plat_scankey
			tst.b d0
			beq.s ntc_plat_getkey
			rts

;## ntc_plat_frame ntc_plat_data ntc_data
; ntc_plat_frame - called once per NTC frame; bump the counter. A real build
; waits for VBlank here (the level-? interrupt) ;!!NG wire VBlank
ntc_plat_frame:
			addq.w #1, ntc_frames
			move.b d0, REG_DIPSW        ; kick the watchdog each frame   ;!!NG
			rts

;## ntc_plat_ticks ntc_plat_data ntc_data
; ntc_plat_ticks - d0.w (Integer) = the frame counter (TicksPerSecond ~ 60)
ntc_plat_ticks:
			move.w ntc_frames, d0
			rts

;## ntc_plat_sound ntc_data
; ntc_ng_sound - d0.b = a command byte to the Z80 sound driver (System.PlaySound
; calls this). The write triggers the Z80's NMI; the driver acks on $320000.
ntc_ng_sound:
			move.b d0, REG_SOUND
			rts

;## ntc_plat_exit ntc_plat_data
; ntc_plat_exit - a cart can't "exit"; spin (a real build returns to the BIOS
; menu / soft-resets) ;!!NG
ntc_plat_exit:
			bra.s ntc_plat_exit

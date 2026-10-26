; ============================================================
; NTC Platform - MSX-DOS 2 / Nextor: a .COM on an MSX2 (or later)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; An MSX-DOS program is a CP/M one - the BDOS at 5, a TPA from #0100 -
; so this platform is the cpm one (its text below ";@base cpm": the same
; run time, the BDOS console and FCB files) with the MSX's own on top:
;   - the frame interrupt: the BIOS's (MSX-DOS's #0038 calls it), JIFFY
;     (#FC9E) is Ticks - 50 a second on a PAL MSX, 60 NTSC; normal mode's
;     handler on H.TIMI (#FD9F). The BIOS is in page 0 while it runs, so
;     the handler is a stub copied to page 3 (NTC_MSXIRQ, #C000 up: the
;     real stack is below it) - never the program's own page 0 code.
;   - the memory mapper: Option Memory CPCExpansion is the MSX's mapper
;     here (ntc_lib_msx.asm) - its 16K segments, from MSX-DOS 2's mapper
;     support (ALL_SEG ...), shaped as the CPC's RAM settings so that
;     what is built on the CPC's banking (CyborgOS) works unchanged; the
;     window #4000-#7FFF is page 1 (PUT_P1: MSX-DOS 2 knows what is in).
;   - the real stack: from #C000 down (the TPA reaches past it, to the
;     BDOS: page 3 is the program's own whatever else is paged).
;   - #If NTC_MSXDOS Then ... (and NTC_CPM: it is CP/M underneath).
; Needs MSX-DOS 2 or Nextor for the mapper (MSX-DOS 1 has no mapper
; support: Memory.Pages() = 0 there, everything else works).
; ============================================================
;@name     MSX-DOS 2 / Nextor (a .COM: the mapper, the frame interrupt)
;@base     cpm
;@org      #0100
;@text     byte
;@scrinit  0
;@irq      1
;@stack    #C000
;@cols     80
;@rows     24
;@irqrate  50
;@islc     1
; ============================================================

;## ntc_msx_data @shared
NTC_MSXIRQ	equ #C000		; the interrupt stub (page 3: what the BIOS can call)
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none
ntc_msxhk:		ds 5			; H.TIMI's 5 bytes as they were
ntc_msxiq:		db 0			; 1 = H.TIMI is normal mode's

;## ntc_plat_frame ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_frame - wait for the next frame (its interrupt), on the real stack
; ------------------------------------------------------------
ntc_plat_frame:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			halt
			di
			ld sp, (ntc_ip)
			jp (ix)

;## ntc_plat_ticks @shared
; ntc_plat_ticks - HL = JIFFY (the BIOS counts the frames)
ntc_plat_ticks:
			ld hl, (#FC9E)
			jp (ix)

;## ntc_plat_irq ntc_msx_data ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_irqon - normal mode's handler on H.TIMI (#FD9F: the BIOS calls it
; at every frame interrupt, its registers saved): an Interrupt hook is marked
; to run at the next safe point, the interrupt classes are counted (C = 1:
; every interrupt is a frame's). The BIOS is in page 0 then (MSX-DOS's #0038
; calls it there), so the handler runs from a copy in page 3 (NTC_MSXIRQ);
; the program's own code below #4000 isn't there while it runs.
; ------------------------------------------------------------
ntc_plat_irqon:
			ld hl, ntc_msx_irq
			ld de, NTC_MSXIRQ
			ld bc, ntc_msx_irqe - ntc_msx_irq
			ldir
			ld hl, ntc_hookon			; its addresses (the hook's flags, the classes' counter)
			ld (NTC_MSXIRQ + ntc_mi_on - ntc_msx_irq + 1), hl
			ld hl, ntc_hookpend
			ld (NTC_MSXIRQ + ntc_mi_pend - ntc_msx_irq + 1), hl
			ld hl, ntc_irqv
			ld (NTC_MSXIRQ + ntc_mi_v - ntc_msx_irq + 1), hl
			ld hl, #FD9F
			ld de, ntc_msxhk
			ld bc, 5
			ldir
			ld a, #C3				; jp NTC_MSXIRQ, ret, ret
			ld (#FD9F), a
			ld hl, NTC_MSXIRQ
			ld (#FDA0), hl
			ld a, #C9
			ld (#FDA2), a
			ld (#FDA3), a
			ld a, 1
			ld (ntc_msxiq), a
			jp (ix)
; the stub (copied to NTC_MSXIRQ): its three addresses patched in by irqon. The
; interrupt classes' counter (ntc_isl_tick) must not be in page 0 either: it is
; the library's, past the program's start - a program bigger than 16K has it
; above #4000 (CyborgOS); a small one keeps its interrupt classes off (none)
ntc_msx_irq:
ntc_mi_on:
			ld a, (0)				; ntc_hookon
			or a
			jr z, ntc_mi_nohook
ntc_mi_pend:
			ld (0), a				; ntc_hookpend
ntc_mi_nohook:
ntc_mi_v:
			ld hl, (0)				; ntc_irqv
			ld a, h
			or l
			ret z
			ld c, 1
			jp (hl)
ntc_msx_irqe:

;## ntc_plat_exit ntc_msx_data ntc_plat_data @shared
; ------------------------------------------------------------
; ntc_plat_exit - End: H.TIMI back as it was, then back to MSX-DOS
; ------------------------------------------------------------
ntc_plat_exit:
			di
			ld a, (ntc_msxiq)
			cp 1
			jr nz, ntc_mx_done
			ld hl, ntc_msxhk
			ld de, #FD9F
			ld bc, 5
			ldir
			xor a
			ld (ntc_msxiq), a
ntc_mx_done:
			ei
			jp 0

;## ntc_plat_memtop ntc_plat_data
; ntc_plat_memtop - HL = the first byte the Memory class's Small heap must not
; use: the real stack's 512 bytes under #C000. Called with call / ret
ntc_plat_memtop:
			ld hl, #C000 - 512
			ret

;## ntc_plat_rmr ntc_plat_data
; ntc_plat_rmr - no CPC gate array: the Memory class's CallBank asks for its ROM / mode
; byte; 0 (CallBank's own switch is the CPC's: not for MSX programs). Keeps BC, DE, HL
ntc_plat_rmr:
			xor a
			ret

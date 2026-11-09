; ============================================================
; NTC Platform - ZX Spectrum Next, a dot command: the Large Model
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; The Small Model (zxndot: asm/ntc_plat_zxndot.asm, which this is built on)
; with the machine taken over while the command runs: the program has 32K
; of its own at #8000-#FFFF and the Memory class's banks, and BASIC's memory
; is put back, byte for byte, when it ends.
;
; Memory  NextZXOS's pages, allocated at entry (IDE_BANK through M_P3DOS:
;         the published allocator, so nothing of BASIC's or Layer 2's is
;         touched) and given back at the end:
;           #0000-#1FFF  DivMMC's ROM (esxDOS), as entered: rst 8, rst #10, rst #18
;           #2000-#3FFF  this dot command's 8K: the entry, the BASIC-side
;                        machinery, the command line (the first 8K of the file)
;           #4000-#7FFF  the Memory class's window: two pages of ours (its page
;                        1, "main RAM's own") or the page selected
;           #8000-#FFFF  the program (org #8000), its arrays, the heap, the real
;                        stack from #FFFF down: four pages of ours, read from
;                        this file after its first 8K (M_GETHANDLE, F_READ)
;         Slots 2-7 hold these while the program runs; a ROM or esxDOS call
;         (print, keys, the allocator) runs with BASIC's six pages back in them
;         (dot_os), from this 8K, which is in both maps. Interrupts stay off
;         in the program's map (BASIC's handler would run over ours): ;@ints 0.
;         Option Memory CPCExpansion (the default here): 64K banks of 8 pages
;         from the same allocator at the Memory class's first call, up to 16
;         (1MB), switched into the window as on the CPC (ntc_lib_dot.asm).
; File    NAME.DOT = the 8K (padded) + the program: one file, >8K, as NextZXOS
;         allows (only the first 8K is loaded; the rest is read by the entry).
; End     the pages freed, slots 2-7 BASIC's again, SP back, carry clear, ret.
;         No memory: the esxDOS error return with its message, before anything ran.
; Console, keys, Frame, Ticks, the command line: as the Small Model.
; ============================================================
;@base     zxndot
;@name     ZX Spectrum Next - a dot command, Large Model (32K at #8000 + banks, BASIC's screen)
;@org      #2000
;@dotorg   #8000
;@stack    0
;@ramtop   #FF80
; ============================================================

;## ntc_plat_exit
; ntc_plat_exit - back to BASIC: the pages given back, its memory in slots 2-7, its
; stack, carry clear (0 OK), interrupts on - dotl_exit, in the entry's 8K
ntc_plat_exit:
			jp dotl_exit			; (in the entry's 8K: the program's own pages are unmapped on the way)

;## ntc_plat_memtop
; ntc_plat_memtop - HL = the first byte the Memory class's Small heap must not use:
; #FF80, under the real stack (128 bytes from #FFFF down). Called on the real stack
; (call / ret), only by the Memory class
ntc_plat_memtop:
			ld hl, #FF80
			ret

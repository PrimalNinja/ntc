; ============================================================
; NTC Platform - CyborgOS (a program in a slot of the Z80 hypervisor)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; What a program sees in a CyborgOS slot is CP/M 2.2 - the BDOS at
; 5, the BIOS jump table, a TPA from #0100 - so this platform is the
; cpm one (its text is the cpm platform's, below ";@base cpm": the
; same run time, the same console and file calls) with what CyborgOS
; adds on top:
;   - the output is a .CYB: the program with its AMSDOS header (the
;     header gives its length; CyborgOS runs it on the Amstrad CPC
;     and on the ZX Spectrum Next alike). A .COM is CP/M's own
;     form, and runs too - the cpm platform makes those.
;   - the console is CyborgOS's: 80 columns, VT52 codes for Cls and
;     Locate (Option Terminal VT52 is the default here).
;   - CybSys is a platform class: the hypervisor's services (BDOS
;     131 / 30: the slot, the clock, claims, ports, drive paths).
;   - #If NTC_CYBORGOS Then ... (and NTC_CPM: it is CP/M underneath).
; The hypervisor itself is built for the machine it runs on (cpcfw,
; zxn); this platform is for what runs inside it.
; ============================================================
;@name     CyborgOS (a slot: CP/M 2.2 and the hypervisor's services)
;@base     cpm
;@org      #0100
;@text     byte
;@scrinit  0
;@irq      0
;@stack    ntc_cpmstack
;@cols     80
;@rows     25
;@terminal vt52
; ============================================================

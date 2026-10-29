; ============================================================
; NTC Platform - CyborgOS - The Headless Horseman (a program in a slot of
; a headless CyborgOS: a vCPC)
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
; A headless CyborgOS (cyborg-os-vcpc: the kernel and its slots on a
; Z80 with no screen and no keyboard of its own - in a container, on a
; CPC-CPLink's Pi - its consoles and keys carried over a link) runs the
; same programs a CyborgOS slot does. For now this platform is the
; cyborgos one exactly (";@base cyborgos", which is ";@base cpm": the
; same run time, console, files, CybSys, the .CYB out, VT52); it is its
; own name so that what the headless machine adds later has a place:
;   - #If NTC_CYBORGOSHH Then ... (and NTC_CYBORGOS, NTC_CPM: what is
;     written for those holds here)
;   - the output is a .CYB, as cyborgos's: it runs on a CPC, a Next, an
;     MSX and a vCPC alike while the two are the same
; ============================================================
;@name     CyborgOS - The Headless Horseman (a slot of a headless CyborgOS: as CyborgOS for now)
;@base     cyborgos
; ============================================================

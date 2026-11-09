; decode_asm.asm - a plain Z80 ZOSCII decode loop (no threading): 64 two byte addresses read through a 1 KB ROM, 100 times
; the timing harness (bench.py) reads the bp_ labels. (c) 2026 Cyborg Unicorn Pty Ltd
            org #2000
            ld hl, enc          ; make 64 addresses (any value 0-1023: the decode doesn't care)
            ld b, 64
            ld de, 12345
mk:         ld a, e
            add a, a
            add a, a
            add a, e
            inc a
            ld e, a
            ld (hl), e
            inc hl
            ld a, d
            add a, e
            and 3
            ld (hl), a
            inc hl
            djnz mk
bp_beforeprepare:
bp_afterprepare:
bp_beforeencode:
bp_afterencode:
bp_beforedecode:
            ld a, 100
runs:       ex af, af'
            ld hl, enc
            ld de, dec
dloop:      ld c, (hl)
            inc hl
            ld a, (hl)
            inc hl
            add a, rom / 256    ; the ROM sits on a 256 byte page: high byte of the address + page
            ld b, a
            ld a, (bc)
            ld (de), a
            inc de
            ld a, e
            cp (dec + 64) & 255
            jr nz, dloop
            ex af, af'
            dec a
            jr nz, runs
bp_afterdecode:
            ret
            align 256
rom:        ds 1024, 65
enc:        ds 128
dec:        ds 64

; bbct - BBC BASIC (Z80)'s way with files (its CMOS.Z80), CyborgOS checked (regress.sh): OPENOUT
; - delete (19), make (22) at FCB, the FCB copied to the channel's own, a random read (33) there
; (a new file: end of file); two records written with 40 (write random, zero fill) through the
; copy, closed (16) through it; OPENIN - open (15) at FCB, copied, read (33) through the copy.
; Each call's A (H must be 0: BBC BASIC's "CP/M Error") printed: "C=" then 19 22 33 40 40 16 15 33
            org #0100
            ld de, m_c
            call str
            ld c, 19
            ld de, fcb
            call bd
            ld c, 22
            ld de, fcb
            call bd
            ld hl, fcb                  ; (OPEN3: the FCB copied, the pointer cleared)
            ld de, chan
            ld bc, 36
            ldir
            ld de, rec
            ld c, 26
            call 5
            ld c, 33
            ld de, chan
            call bd
            ld hl, txt1
            ld de, rec
            ld bc, 128
            ldir
            ld c, 40
            ld de, chan
            call bd
            ld hl, chan + 33
            inc (hl)
            ld hl, txt2
            ld de, rec
            ld bc, 128
            ldir
            ld c, 40
            ld de, chan
            call bd
            ld c, 16
            ld de, chan
            call bd
            ld hl, fcb0                 ; OPENIN: the FCB set up again
            ld de, fcb
            ld bc, 36
            ldir
            ld c, 15
            ld de, fcb
            call bd
            ld hl, fcb
            ld de, chan2
            ld bc, 36
            ldir
            ld hl, chan2 + 33
            inc (hl)                    ; record 1
            ld c, 33
            ld de, chan2
            call bd
            call crlf
            ld de, m_r
            call str
            ld hl, rec
            ld b, 5
rd:         ld a, (hl)
            call chr
            inc hl
            djnz rd
            call crlf
            jp 0
bd:         call 5                      ; A and H: "aa/hh "
            push hl
            call hex2
            ld a, '/'
            call chr
            pop hl
            ld a, h
            call hex2
            ld a, ' '
            jp chr
str:        ld c, 9
            jp 5
chr:        push hl
            push bc
            ld e, a
            ld c, 2
            call 5
            pop bc
            pop hl
            ret
crlf:       ld a, 13
            call chr
            ld a, 10
            jp chr
hex2:       push af
            rrca
            rrca
            rrca
            rrca
            call hex1
            pop af
hex1:       and 15
            add a, '0'
            cp '9' + 1
            jr c, chr
            add a, 7
            jr chr
m_c:        db "C=$"
m_r:        db "R=$"
txt1:       db "FIRST"
            ds 123, 0
txt2:       db "SECND"
            ds 123, 0
fcb0:       db 0, "T       BBC"
            ds 24, 0
fcb:        db 0, "T       BBC"
            ds 24, 0
chan:       ds 38, 0
chan2:      ds 38, 0
rec:        ds 128, 0

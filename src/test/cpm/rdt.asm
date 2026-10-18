; rdt - random access on the slot's drive (regress.sh: a CyborgOS RAM disc): make TEST.DAT,
; write records 0-39 (each filled with its number), close; open, read record 25 at random,
; write record 5 at random ('X's), read 5 again, read on sequentially (cr after 33 = 5: 5),
; 35 the size, 36 the place, search *.DAT, delete it, search again
            org #0100
            ld c, 19                    ; (an old one gone)
            ld de, fcb
            call 5
            ld c, 22
            ld de, fcb
            call 5
            call ok_a
            xor a
            ld (fcb + 32), a
            ld b, 40
            ld c, 0
w_lp:
            push bc
            ld a, c
            ld hl, #0080
            ld b, 128
f_lp:
            ld (hl), a
            inc hl
            djnz f_lp
            ld c, 21
            ld de, fcb
            call 5
            or a
            jr z, w_ok
            ld de, m_werr
            call str
w_ok:
            pop bc
            inc c
            djnz w_lp
            ld c, 16
            ld de, fcb
            call 5
            ld de, m_w
            call str
            ld c, 15                    ; open again
            ld de, fcb
            call 5
            call ok_a
            ld hl, 25                   ; read 25
            ld (fcb + 33), hl
            xor a
            ld (fcb + 35), a
            ld c, 33
            ld de, fcb
            call 5
            push af
            ld de, m_r25
            call str
            pop af
            call hex2
            ld a, ' '
            call chr
            ld a, (#0080)
            call hex2
            ld a, (#00FF)
            call hex2
            call crlf
            ld hl, #0080                ; write 5: X
            ld b, 128
x_lp:
            ld (hl), 'X'
            inc hl
            djnz x_lp
            ld hl, 5
            ld (fcb + 33), hl
            ld c, 34
            ld de, fcb
            call 5
            ld hl, #0080
            ld (hl), 0
            ld c, 33                    ; read 5 back
            ld de, fcb
            call 5
            ld de, m_r5
            call str
            ld a, (#0080)
            call chr
            ld a, (#00FF)
            call chr
            ld c, 20                    ; sequential: 5 again (CP/M), then 6
            ld de, fcb
            call 5
            ld a, ' '
            call chr
            ld a, (#0080)
            call chr
            ld c, 20
            ld de, fcb
            call 5
            ld a, (#0080)
            call hex2
            call crlf
            ld c, 35                    ; the size
            ld de, fcb
            call 5
            ld de, m_sz
            call str
            ld a, (fcb + 34)
            call hex2
            ld a, (fcb + 33)
            call hex2
            ld c, 36                    ; the place (after 6: 7)
            ld de, fcb
            call 5
            ld de, m_pl
            call str
            ld a, (fcb + 33)
            call hex2
            call crlf
            ld c, 16
            ld de, fcb
            call 5
            ld c, 17                    ; search *.DAT
            ld de, fsr
            call 5
            push af
            ld de, m_s
            call str
            pop af
            call hex2
            ld a, ' '
            call chr
            ld hl, #0081
            ld b, 11
n_lp:
            ld a, (hl)
            call chr
            inc hl
            djnz n_lp
            ld a, ' '
            call chr
            ld a, (#0080 + 15)
            call hex2
            ld c, 18
            ld de, fsr
            call 5
            call hex2
            call crlf
            ld c, 19                    ; delete, search again
            ld de, fcb
            call 5
            push af
            ld de, m_d
            call str
            pop af
            call hex2
            ld c, 17
            ld de, fsr
            call 5
            call hex2
            call crlf
            ld de, m_end
            call str
            ld c, 0
            jp 5
ok_a:       or a
            ret z
            push af
            ld de, m_err
            call str
            pop af
            call hex2
            jp crlf
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
m_err:      db "err $"
m_werr:     db "write err", 13, 10, "$"
m_w:        db "written 40", 13, 10, "$"
m_r25:      db "r25=$"
m_r5:       db "r5=$"
m_sz:       db "size=$"
m_pl:       db " place=$"
m_s:        db "s=$"
m_d:        db "del=$"
m_end:      db "rdt done", 13, 10, "$"
fcb:        db 0, "TEST    DAT"
            ds 24
fsr:        db 0, "????????DAT"
            ds 24

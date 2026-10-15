; cpmt - CyborgOS's CP/M calls checked (regress.sh): the default FCBs from the command tail,
; TAB, the BIOS's CONOUT through (#0001), BDOS 12, 24, 35 (size), 36 (set random record),
; 17 / 18 (search), 10 (a line), 1 (a key); then jp 0 (WBOOT ends it)
            org #0100
            ld de, m_f1
            call str
            ld a, (#005C)
            add a, '0'
            call chr
            ld hl, #005D
            call name11
            ld de, m_f2
            call str
            ld a, (#006C)
            add a, '0'
            call chr
            ld hl, #006D
            call name11
            call crlf
            ld de, m_tab                ; "T>" TAB "<" : 6 spaces between
            call str
            ld hl, (#0001)              ; the BIOS: WBOOT + 9 = CONOUT
            ld de, 9
            add hl, de
            ld (bcall + 1), hl
            ld c, 'X'
            call bcall
            ld c, 'Y'
            call bcall
            call crlf
            ld c, 12                    ; version
            call 5
            push hl
            ld de, m_ver
            call str
            pop hl
            ld a, l
            call hex2
            ld c, 24                    ; login vector
            call 5
            push hl
            ld de, m_log
            call str
            pop hl
            ld a, l
            call hex2
            call crlf
            ld c, 35                    ; the size of FCB 1's file
            ld de, #005C
            call 5
            push af
            ld de, m_size
            call str
            pop af
            call hex2
            ld a, ' '
            call chr
            ld a, (#005C + 33)
            call hex2
            call crlf
            ld c, 15                    ; open it, read one record, 36: 1
            ld de, #005C
            call 5
            ld c, 20
            ld de, #005C
            call 5
            ld c, 36
            ld de, #005C
            call 5
            ld de, m_ran
            call str
            ld a, (#005C + 33)
            call hex2
            call crlf
            ld c, 16
            ld de, #005C
            call 5
            ld c, 17                    ; search: ????????.TXT
            ld de, fsr
srch:
            call 5
            cp #FF
            jr z, srch_e
            ld de, m_fnd
            call str
            ld hl, #0081
            call name11
            ld a, ' '
            call chr
            ld a, (#0080 + 15)
            call hex2
            call crlf
            ld c, 18
            jr srch
srch_e:
            ld de, m_name               ; 10: a line
            call str
            ld de, lbuf
            ld c, 10
            call 5
            ld de, m_got
            call str
            ld a, (lbuf + 1)
            ld b, a
            ld hl, lbuf + 2
            or a
            jr z, got_e
got_l:
            ld a, (hl)
            call chr
            inc hl
            djnz got_l
got_e:
            ld a, '<'
            call chr
            call crlf
            ld de, m_key                ; 1: a key (echoed)
            call str
            ld c, 1
            call 5
            ld (key), a
            ld de, m_kis
            call str
            ld a, (key)
            call hex2
            call crlf
            ld de, m_end
            call str
            jp 0
bcall:      jp 0
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
name11:     ld b, 11
n11:        ld a, (hl)
            call chr
            inc hl
            djnz n11
            ret
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
m_f1:       db "F1=$"
m_f2:       db " F2=$"
m_tab:      db "T>", 9, "<$"
m_ver:      db "V=$"
m_log:      db " L=$"
m_size:     db "S=$"
m_ran:      db "R=$"
m_fnd:      db "D=$"
m_name:     db "name? $"
m_got:      db 13, 10, "got>$"
m_key:      db "key? $"
m_kis:      db " k=$"
m_end:      db "cpmt done", 13, 10, "$"
fsr:        db 0, "????????TXT"
            ds 24
key:        db 0
lbuf:       db 20, 0
            ds 22

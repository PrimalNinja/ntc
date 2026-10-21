' Zx - the ZX81's screen straight into the display file (ntc_dfile: a HALT, then 24 rows
' of 32 character codes and a HALT). For games: one keyword a call, no cursor.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Codes are the ZX81's: 0 space, 1-10 block graphics, 11-27 symbols, 28-37 digits, 38-63
' letters, + 128 inverse. Bit 6 must stay clear (the display file is executed), so every
' code written here has it cleared. Columns 0-31, rows 0-23; nothing is clipped - keep them
' on the screen. Each method's body is one #asm block (a keyword: the arguments arrive as
' addresses on the thread), so the cell address is worked out in each - SP is the thread,
' no call, no push; the labels of a block are its own.
Option Explicit

' block graphics (the quarters that are black)
Public Const TL = 1              ' top left
Public Const TR = 2              ' top right
Public Const TOP = 3             ' the top half
Public Const BL = 4              ' bottom left
Public Const LEFT = 5            ' the left half
Public Const TRBL = 6            ' top right and bottom left
Public Const NOTBR = 7           ' all but the bottom right
Public Const GREY = 8
Public Const FULL = 128          ' inverse space: a full block
Public Const NOTTL = 129         ' all but the top left
Public Const NOTTR = 130         ' all but the top right
Public Const BOTTOM = 131        ' the bottom half
Public Const NOTBL = 132         ' all but the bottom left
Public Const RIGHT = 133         ' the right half
Public Const TLBR = 134          ' top left and bottom right
Public Const BR = 135            ' bottom right
Public Const INV = 128           ' + a code: its inverse

' Put x, y, code: one cell
Public Sub Put(ByVal x As Integer, ByVal y As Integer, ByVal code As Integer)
#asm
            pop hl
            ld c, (hl)              ; x
            pop hl
            ld a, (hl)              ; y
            pop de                  ; code's address
            ld l, a                 ; the cell: ntc_dfile + 1 + y * 33 + x
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld b, a
            ld c, b
            ld b, 0
            add hl, bc
            ld bc, ntc_dfile + 1
            add hl, bc
            ld a, (de)
            and #BF
            ld (hl), a
#endasm
End Sub

' Get(x, y): the code in a cell
Public Function Get(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld c, a
            add hl, bc
            ld bc, ntc_dfile + 1
            add hl, bc
            ld e, (hl)
            pop hl
            ld (hl), e
            inc hl
            ld (hl), 0
#endasm
End Function

' Put2 x, y, c1, c2: two cells side by side (the invaders are two wide)
Public Sub Put2(ByVal x As Integer, ByVal y As Integer, ByVal c1 As Integer, ByVal c2 As Integer)
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld c, a
            add hl, bc
            ld bc, ntc_dfile + 1
            add hl, bc
            pop de                  ; c1's address
            ld a, (de)
            and #BF
            ld (hl), a
            inc hl
            pop de                  ; c2's
            ld a, (de)
            and #BF
            ld (hl), a
#endasm
End Sub

' Fill x, y, n, code: n cells along a row (n 0: none)
Public Sub Fill(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer, ByVal code As Integer)
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld c, a
            add hl, bc
            ld bc, ntc_dfile + 1
            add hl, bc
            pop de                  ; n's address
            ld a, (de)
            ld b, a
            pop de                  ; code's
            ld a, (de)
            and #BF
            inc b
            dec b
            ret z
zxf_lp:
            ld (hl), a
            inc hl
            djnz zxf_lp
#endasm
End Sub

' Row y, code: a whole row
Public Sub Row(ByVal y As Integer, ByVal code As Integer)
#asm
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de
            ld de, ntc_dfile + 1
            add hl, de
            pop de                  ; code's address
            ld a, (de)
            and #BF
            ld b, 32
zxr_lp:
            ld (hl), a
            inc hl
            djnz zxr_lp
#endasm
End Sub

' Text x, y, s: ASCII text (a-z as A-Z, what the ZX81 hasn't got as ?; bytes under 32 and
' from 128 as ZX81 codes)
Public Sub Text(ByVal x As Integer, ByVal y As Integer, ByVal s As String)
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld c, a
            add hl, bc
            ld bc, ntc_dfile + 1
            add hl, bc
            pop de                  ; the text
zxt_lp:
            ld a, (de)
            or a
            ret z
            inc de
            cp 32
            jr c, zxt_raw
            cp 128
            jr nc, zxt_raw
            sub 32
            ld (zxt_hl), hl
            ld (zxt_de), de
            ld l, a
            ld h, 0
            ld de, ntc_ascmap
            add hl, de
            ld a, (hl)
            ld de, (zxt_de)
            ld hl, (zxt_hl)
zxt_raw:
            and #BF
            ld (hl), a
            inc hl
            jr zxt_lp
zxt_hl:     dw 0
zxt_de:     dw 0
#endasm
End Sub

' TextInv x, y, s: the same, inverse video
Public Sub TextInv(ByVal x As Integer, ByVal y As Integer, ByVal s As String)
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld c, a
            add hl, bc
            ld bc, ntc_dfile + 1
            add hl, bc
            pop de                  ; the text
zxi_lp:
            ld a, (de)
            or a
            ret z
            inc de
            cp 32
            jr c, zxi_raw
            cp 128
            jr nc, zxi_raw
            sub 32
            ld (zxi_hl), hl
            ld (zxi_de), de
            ld l, a
            ld h, 0
            ld de, ntc_ascmap
            add hl, de
            ld a, (hl)
            ld de, (zxi_de)
            ld hl, (zxi_hl)
zxi_raw:
            and #BF
            or #80
            ld (hl), a
            inc hl
            jr zxi_lp
zxi_hl:     dw 0
zxi_de:     dw 0
#endasm
End Sub

' Number x, y, n, digits: n (0-32767) right aligned in that many digits (1-5), leading zeros
Public Sub Number(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer, ByVal digits As Integer)
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld b, h
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, bc
            ld c, a
            add hl, bc
            ld bc, ntc_dfile + 1
            add hl, bc              ; HL = the first cell
            pop de                  ; n's address
            pop bc                  ; digits' address
            ld a, (bc)
            ld (zxn_cnt), a
            ld c, a
            ld b, 0
            add hl, bc
            dec hl                  ; HL = the last cell
            ex de, hl               ; HL = n's address, DE = the last cell
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld h, b
            ld l, c                 ; HL = n
zxn_dig:
            xor a                   ; HL / 10: HL = the quotient, A = the remainder
            ld b, 16
zxn_div:
            add hl, hl
            rla
            cp 10
            jr c, zxn_nos
            sub 10
            inc l
zxn_nos:
            djnz zxn_div
            add a, 28               ; the digit's code
            ld (de), a
            dec de
            ld a, (zxn_cnt)
            dec a
            ld (zxn_cnt), a
            jr nz, zxn_dig
            ret
zxn_cnt:    db 0
#endasm
End Sub

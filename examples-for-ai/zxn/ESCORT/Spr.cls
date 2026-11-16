' Spr - the Next's 128 hardware sprites, straight on the ports (#303B slot, #57 attributes).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' 4 bit patterns (GfxData.Load puts them in the sprite RAM), 16 x 16 pixels, scaled 1x - 8x.
' Put / Hide write a table in RAM; Show sends the table to the hardware in one go (do it just
' after Frame, so nothing moves half way down the screen).
' Coordinates are the tilemap's: 0, 0 is the top left of the whole 320 x 256 picture (the
' border included); the 256 x 192 paper is 32 - 287 across, 32 - 223 down. A sprite at x -16 .. or
' y -16 .. wraps (512): keep it hidden instead.
Option Explicit

' flags for Put: add them
Public Const MirrorX = 8
Public Const MirrorY = 4
Public Const Rotate = 2
Public Const Scale2X = &H800
Public Const Scale2Y = &H200
Public Const Scale2 = &HA00
Public Const Scale4X = &H1000
Public Const Scale4Y = &H400
Public Const Scale4 = &H1400
' a palette offset: Pal * n (n 0 - 15: spr_pal.png's row n)
Public Const Pal = 16

Private tab(639) As Byte          ' 128 x 5 attribute bytes
Private used As Integer           ' the highest slot Put + 1 (Show sends that many)

' Init: every sprite hidden, sprites on (over the border too), transparent colour 15
Public Sub Init()
  Dim i As Integer
  For i = 0 To 639
    tab(i) = 0
  Next
  For i = 3 To 639 Step 5
    tab(i) = &H40                ' hidden, but still 5 bytes (the upload stays in step)
  Next
  used = 128
  Show
  used = 0
  Nx.Reg &H4B, &HF               ' 4 bit sprites: colour 15 is transparent
  Nx.Reg &H15, (Nx.RegGet(&H15) And &H1C) Or 3   ' sprites on, over the border; the order kept
End Sub

' Put n, x, y, pattern, flags: sprite n (0-127) at x, y showing pattern (0-127), with flags
' (MirrorX + Scale2 + Pal * 2 ...)
Public Sub Put(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal pattern As Integer, ByVal flags As Integer)
#asm
            pop hl
            ld a, (hl)
            and 127
            ld c, a
            inc a
            ld hl, {used}
            cp (hl)
            jr c, sp_low
            ld (hl), a
sp_low:
            ld l, c                 ; DE = tab + n * 5
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, {tab}
            add hl, de
            ex de, hl
            pop hl                  ; x
            ld a, (hl)
            ld (de), a              ; attribute 0: x bits 0-7
            inc hl
            ld a, (hl)
            and 1
            ld c, a                 ; x bit 8
            inc de
            pop hl                  ; y
            ld a, (hl)
            ld (de), a              ; attribute 1: y bits 0-7
            inc hl
            ld a, (hl)
            and 1
            ld b, a                 ; y bit 8
            inc de
            pop hl                  ; pattern
            ld a, (hl)
            ex af, af'
            pop hl                  ; flags
            ld a, (hl)
            and #FE
            or c
            ld (de), a              ; attribute 2: palette offset, mirrors, rotate, x bit 8
            inc de
            inc hl
            ld c, (hl)              ; scale bits
            ex af, af'
            ld l, a
            srl a
            or #C0
            ld (de), a              ; attribute 3: visible, 5 bytes, pattern bits 6-1
            inc de
            ld a, l
            and 1
            rrca
            rrca
            or #80
            or b
            ld b, a
            ld a, c
            and #1E
            or b
            ld (de), a              ; attribute 4: 4 bit, pattern bit 0, scale, y bit 8
#endasm
End Sub

' Hide n: sprite n not shown
Public Sub Hide(ByVal n As Integer)
#asm
            pop hl
            ld a, (hl)
            and 127
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, {tab} + 3
            add hl, de
            ld (hl), #40            ; not visible, 5 bytes kept (else the upload slips a byte)
#endasm
End Sub

' HideRange first, count: those sprites not shown
Public Sub HideRange(ByVal first As Integer, ByVal count As Integer)
#asm
            pop hl
            ld a, (hl)
            and 127
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, {tab} + 3
            add hl, de
            ex de, hl
            pop hl
            ld a, (hl)
            or a
            jr z, hr_done
            ld b, a
            ex de, hl
            ld de, 5
hr_lp:
            ld (hl), #40
            add hl, de
            djnz hr_lp
hr_done:
#endasm
End Sub

' Show: the table to the hardware (the slots up to the highest one Put)
Public Sub Show()
#asm
            ld a, ({used})
            or a
            jr z, sh_done
            ld bc, #303B
            xor a
            out (c), a
            ld a, ({used})
            ld e, a                 ; E sprites, 5 bytes each
            ld hl, {tab}
            ld c, #57
sh_lp:
            ld b, 5
            otir
            dec e
            jr nz, sh_lp
sh_done:
#endasm
End Sub

' Visible(n): True when sprite n is shown
Public Function Visible(ByVal n As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            and 127
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, {tab} + 3
            add hl, de
            ld a, (hl)
            ld de, 0
            and #80
            jr z, vi_no
            dec de
vi_no:
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

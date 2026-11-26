' Vic - the C64's VIC-II: the 8 sprites, colours, your own characters. NTC platform class:
' Commodore 64 with an REU (6502)
'
' The screen stays the console's (40 x 25 text, Print and Locate): sprites go over it.
'
' Sprites: 0-7. A sprite shows a shape; shapes are 64 bytes each (24 x 21 pixels, 3 bytes a
' row, 63 bytes used) in the VIC's own memory, numbered 0-78: Vic.ShapeAddr(s) is where shape
' s is. Put a shape there with Poke - or bring it from the REU in 64 cycles:
'
'     Reu.Fetch 1, 0, Vic.ShapeAddr(0), 64     ' a shape kept in the REU, bank 1, address 0
'     Vic.Shape 0, 0                           ' sprite 0 shows shape 0
'     Vic.Colour 0, 7
'     Vic.Sprite 0, 160, 100                   ' there, and on
'
' With the shapes in the REU a program has as many as it likes - thousands - and brings in the
' ones on show: a new frame of animation for all 8 sprites is 512 cycles, 8 raster lines.
' (Shapes 16 on are in $F000-$FFBF: a test build's log is there too, see docs/c64reu.md.)
'
' Positions are the VIC's own: x 24-343 and y 50-249 are the visible screen's top left corner
' for a sprite's own top left; x runs 0-511.

Public Const Sprites = 8
Public Const Shapes = 79
Public Const ShapeBytes = 64

' ShapeAddr(s): where shape s (0-78) is in memory
Public Function ShapeAddr(ByVal s As Integer) As Integer
    If s < 16 Then
        ShapeAddr = &HE400 + s * 64
    Else
        ShapeAddr = &HF000 + (s - 16) * 64
    End If
End Function

' Shape n, s: sprite n shows shape s
Public Sub Shape(ByVal n As Integer, ByVal s As Integer)
    If s < 16 Then
        Poke &HE3F8 + (n And 7), 144 + s
    Else
        Poke &HE3F8 + (n And 7), 176 + s
    End If
End Sub

' Sprite n, x, y: sprite n at x, y - and on
Public Sub Sprite(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer)
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            NTC_POP z_p2
            ldy #0
            lda (z_p0),y
            and #7
            tax
            asl
            sta z_t0
            lda (z_p2),y
            ldy z_t0
            sta $D001,y
            ldy #0
            lda (z_p1),y
            ldy z_t0
            sta $D000,y
            ldy #1
            lda (z_p1),y
            lsr
            lda ntc_c64_bit,x
            bcs high
            eor #$FF
            and $D010
            jmp setx
high:
            ora $D010
setx:
            sta $D010
            lda ntc_c64_bit,x
            ora $D015
            sta $D015
#endasm
End Sub

' Hide n: sprite n off
Public Sub Hide(ByVal n As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            and #7
            tax
            lda ntc_c64_bit,x
            eor #$FF
            and $D015
            sta $D015
#endasm
End Sub

' HideAll: every sprite off
Public Sub HideAll()
    Poke &HD015, 0
End Sub

' Colour n, c: sprite n's colour (0-15)
Public Sub Colour(ByVal n As Integer, ByVal c As Integer)
    Poke &HD027 + (n And 7), c
End Sub

' Multi n, onoff: sprite n in multicolour (12 x 21 double width pixels, 3 colours: its own
' and the two all sprites share - Vic.MultiColours)
Public Sub Multi(ByVal n As Integer, ByVal onoff As Integer)
    If onoff Then
        Poke &HD01C, Peek(&HD01C) Or Bit(n)
    Else
        Poke &HD01C, Peek(&HD01C) And (255 - Bit(n))
    End If
End Sub

Public Sub MultiColours(ByVal c1 As Integer, ByVal c2 As Integer)
    Poke &HD025, c1
    Poke &HD026, c2
End Sub

' Expand n, wide, tall: sprite n twice as wide and / or twice as tall
Public Sub Expand(ByVal n As Integer, ByVal wide As Integer, ByVal tall As Integer)
    If wide Then
        Poke &HD01D, Peek(&HD01D) Or Bit(n)
    Else
        Poke &HD01D, Peek(&HD01D) And (255 - Bit(n))
    End If
    If tall Then
        Poke &HD017, Peek(&HD017) Or Bit(n)
    Else
        Poke &HD017, Peek(&HD017) And (255 - Bit(n))
    End If
End Sub

' Behind n, onoff: sprite n behind the text (else in front of it)
Public Sub Behind(ByVal n As Integer, ByVal onoff As Integer)
    If onoff Then
        Poke &HD01B, Peek(&HD01B) Or Bit(n)
    Else
        Poke &HD01B, Peek(&HD01B) And (255 - Bit(n))
    End If
End Sub

' Hit(): the sprites that have touched another sprite since the last time this was asked (a
' bit each: sprite n is Vic.Bit(n))
Public Function Hit() As Integer
    Hit = Peek(&HD01E)
End Function

' HitText(): the sprites that have touched text since the last time this was asked
Public Function HitText() As Integer
    HitText = Peek(&HD01F)
End Function

' Bit(n): sprite n's bit (1, 2, 4 ... 128)
Public Function Bit(ByVal n As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            and #7
            tax
            lda ntc_c64_bit,x
            sta (z_p1),y
            iny
            lda #0
            sta (z_p1),y
#endasm
End Function

' Border c, Paper c: the border's and the screen's colour (0-15)
Public Sub Border(ByVal c As Integer)
    Poke &HD020, c
End Sub

Public Sub Paper(ByVal c As Integer)
    Poke &HD021, c
End Sub

' CharAddr(c): where character c's 8 bytes are (0-255; the console's font is 32-126, so
' 128-255 and 0-31 are free for a program's own: Poke them, then Print Chr$(c))
Public Function CharAddr(ByVal c As Integer) As Integer
    CharAddr = &HE800 + (c And 255) * 8
End Function

' Scroll x, y: the whole text screen moved left by x pixels and up by y (0-7 each), for smooth
' scrolling. The screen shows 38 columns and 24 rows while this is on, so the column and row
' coming in are out of sight. Every 8 pixels bring the next 40 x 25 characters in (from a map in
' the REU: Reu.FetchRect) and start again from 0.
Public Sub Scroll(ByVal x As Integer, ByVal y As Integer)
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            and #7
            eor #7
            sta z_t0
            lda $D016
            and #$10                ; (multicolour text stays as it is)
            ora z_t0
            sta $D016
            lda (z_p1),y
            and #7
            eor #7
            ora #$10                ; the screen on, 24 rows
            sta $D011
#endasm
End Sub

' ScrollOff: 40 columns and 25 rows again, nothing moved
Public Sub ScrollOff()
    Poke &HD016, (Peek(&HD016) And 16) + 8
    Poke &HD011, &H1B
End Sub

' MultiText onoff, c1, c2: multicolour text. A character printed in a colour 8-15 is then 4 x 8
' double width pixels in four colours - the paper, c1, c2 and the character's own colour less 8
' (so 0-7). Characters in colours 0-7 stay as they are.
Public Sub MultiText(ByVal onoff As Integer, ByVal c1 As Integer, ByVal c2 As Integer)
    If onoff Then
        Poke &HD016, Peek(&HD016) Or 16
    Else
        Poke &HD016, Peek(&HD016) And 239
    End If
    Poke &HD022, c1
    Poke &HD023, c2
End Sub

' Raster(): the raster line the screen is at now (0-311)
Public Function Raster() As Integer
#asm
            NTC_POP z_p0
again:
            lda $D011
            tax
            lda $D012
            sta z_t0
            txa
            eor $D011
            bmi again               ; (the 9th bit changed between the two reads)
            ldy #0
            lda z_t0
            sta (z_p0),y
            iny
            txa
            asl
            lda #0
            rol
            sta (z_p0),y
#endasm
End Function

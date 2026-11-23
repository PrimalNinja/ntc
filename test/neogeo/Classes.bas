' Classes.bas - the Neo Geo's library classes (Vdp, Keys, Pad, Pcm, Psg, Fm, Sound): each call
' made once; what can be read back is printed (test/ngregress.sh checks the transcript, the
' picture and the sound). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Dim sat As Long, i As Integer, j As Integer, t As Integer

Vdp.Init
Print "rgb "; Hex$(Vdp.Rgb(31, 0, 0)); " "; Hex$(Vdp.Rgb(0, 31, 0)); " "; Hex$(Vdp.Rgb(1, 2, 31))
' palette 16 (the sprite table's block 0) and 20: the tool's (1 red, 2 green, 3 blue)
Vdp.Colors Dat.Pal(), 16 * 16, 16
Vdp.Colors Dat.Pal(), 20 * 16, 16
Vdp.Backdrop Vdp.Rgb(0, 0, 8)
' the backdrop: C ROM tiles 4 on, its 224 palettes; band 1 scrolled 8
Vdp.Back 4, Dat.Pal() + 32
Vdp.Bands 0, 8, 0, 0
' the sprite table: entry 0 at the picture's 100, 80 (pattern 1 = C ROM tile 1)
Vdp.Map 0, 16, 0
sat = Vdp.Sat()
If sat <> 0 Then Print "sat ok" Else Print "sat BAD"
Vdp.Sprite 0, 100, 80 + 32, 1, 3
Vdp.Update
' a sprite written straight: 230, two tiles tall, with 231 joined to its right, half size
Vdp.Strip 230, 1, 20, 2
Vdp.Strip 231, 2, 20, 2
Vdp.Place 230, 200, 100, 2
Vdp.Join 231
Vdp.Place 232, 10, 10, 1
Vdp.Strip 232, 3, 20, 1
Vdp.Hide 232
Vdp.Shrink 230, 15, 255
' the fix layer
Vdp.TextPalette 1
Vdp.Color 16 + 1, Vdp.Rgb(31, 31, 0)
Vdp.Cell 38, 26, &H1000 + 256
Vdp.Fill 30, 20, 4, 2, &H1000 + Asc("#")
Print "words in palette 1"
Vdp.TextPalette 0
' the pads
Frame
Print "joy "; Keys.Joystick(0); " pad "; Pad.Read(1); " key "; Keys.Down(Keys.KeyQ)
For i = 1 To 30
    Frame
Next i
Print "joy "; Keys.Joystick(0); " pad "; Pad.Read(1)
Print "have "; Pcm.Have(0)
Print "end"

' C64 + REU: a film. 64 whole screens - characters and colours, 2000 bytes each, 128K in all -
' are made once and kept in the REU. Then they are played back, a new whole screen every frame,
' 50 a second: each is two fetches, 2000 cycles, a tenth of a frame. A 6502 loop needs most of
' a frame just to copy one.
' The screens are cut from two big pictures (80 x 50: one of characters, one of colours), each
' following its own path - made in the REU too, by Reu.FetchRect and Reu.Stash.
' Any key: slower / faster. (An REU of 256K or more.)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const FRAMES = 64
Const BUF = &H0400              ' 1000 bytes of free memory to put a screen together in
Dim f As Integer, x As Integer, y As Integer, d As Integer, k As Integer, wait As Integer
Dim ax(79) As Integer
Dim row(79) As Byte
Dim ramp(7) As Byte

Cls
If Reu.Banks() < 4 Then
  Print "this needs an REU of 256K or more"
  End
End If
Print "drawing two pictures..."
ramp(0) = 6 : ramp(1) = 14 : ramp(2) = 3 : ramp(3) = 1
ramp(4) = 7 : ramp(5) = 10 : ramp(6) = 2 : ramp(7) = 11
' bank 1, address 0: 80 x 50 characters (rings of four shades, characters 160-163)
' bank 1, address 4000: 80 x 50 colours (bands)
For x = 0 To 79 : ax(x) = Abs(x - 40) : Next
For y = 0 To 49
  d = Abs(y - 25) * 2
  For x = 0 To 79
    row(x) = 160 + (((ax(x) + d) \ 3) And 3)
  Next
  Reu.Stash 1, y * 80, VarPtr(row(0)), 80
  For x = 0 To 79
    row(x) = ramp(((x + y + y) \ 6) And 7)
  Next
  Reu.Stash 1, 4000 + y * 80, VarPtr(row(0)), 80
  Locate 1, 2 : Print y + 1; "/ 50";
Next

Print
Print "cutting 64 screens from them..."
' frame f: its characters to bank 2, its colours to bank 3, at f * 1000
For f = 0 To FRAMES - 1
  x = 20 + (Sin8(f * 4) * 19) \ 127
  y = 12 + (Sin8(f * 4 + 64) * 12) \ 127
  Reu.FetchRect 1, y * 80 + x, 80, BUF, 40, 40, 25
  Reu.Stash 2, f * 1000, BUF, 1000
  x = 20 + (Sin8(f * 8 + 32) * 19) \ 127
  y = 12 + (Sin8(f * 4) * 12) \ 127
  Reu.FetchRect 1, 4000 + y * 80 + x, 80, BUF, 40, 40, 25
  Reu.Stash 3, f * 1000, BUF, 1000
Next

' the four shades: characters of our own
For k = 0 To 7
  Poke Vic.CharAddr(160) + k, 255
  Poke Vic.CharAddr(161) + k, 170 - (k And 1) * 85
  Poke Vic.CharAddr(162) + k, 34 * (1 + (k And 1) * 3)
  Poke Vic.CharAddr(163) + k, 0
Next

f = 0 : wait = 1
Do
  Frame
  Reu.Fetch 2, f * 1000, &HE000, 1000
  Reu.Fetch 3, f * 1000, &HD800, 1000
  f = (f + 1) And (FRAMES - 1)
  For k = 2 To wait : Frame : Next
  If Inkey <> 0 Then wait = (wait Mod 4) + 1
Loop

' a sine, -127 to 127, for an angle of 0-255 (each half a parabola)
Function Sin8(ByVal a As Integer) As Integer
  Dim q As Integer, v As Integer
  a = a And 255
  q = a And 127
  v = (q * (128 - q)) \ 32
  If v > 127 Then v = 127
  If a > 127 Then v = -v
  Sin8 = v
End Function

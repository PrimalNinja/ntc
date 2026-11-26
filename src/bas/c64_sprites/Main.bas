' C64 + REU: sprite shapes kept in the REU. 64 shapes - a striped ball that turns, 8 steps, in
' 8 sizes - are drawn once into the REU. Each frame every sprite gets the shape it needs
' straight from the REU: a fetch of 64 bytes, 64 cycles. With shapes in the REU a program can
' have thousands; the VIC's own memory has room for 79.
' The 8 sprites are 8 tasks, each with its own path and speed. A sound when one bounces.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const SHAPEBANK = 1
Dim px(8) As Integer, py(8) As Integer, vx(8) As Integer, vy(8) As Integer
Dim ph(8) As Integer, sz(8) As Integer
Dim i As Integer, n As Integer, id As Integer
Dim sh(63) As Byte
Dim lm(7) As Byte, rm(7) As Byte, st(7) As Byte

' shape number size * 8 + turn, drawn into sh() a row at a time and put in the REU.
' A row of a ball is one run of pixels, a to b: whole bytes of 255 with the two ends masked,
' then the stripes cut out of it
Sub MakeShape(ByVal size As Integer, ByVal turn As Integer)
  Dim y As Integer, r As Integer, w As Integer, a As Integer, b As Integer, k As Integer, m As Integer
  r = 3 + size
  For y = 0 To 20
    k = y * 3
    sh(k) = 0 : sh(k + 1) = 0 : sh(k + 2) = 0
    w = r * r - (y - 10) * (y - 10)
    If w >= 0 Then
      w = Sqr(w)
      a = 12 - w : b = 12 + w
      For m = a \ 8 To b \ 8 : sh(k + m) = 255 : Next
      sh(k + a \ 8) = sh(k + a \ 8) And lm(a And 7)
      sh(k + b \ 8) = sh(k + b \ 8) And rm(b And 7)
      m = st((y + turn) And 7)
      sh(k) = sh(k) And m : sh(k + 1) = sh(k + 1) And m : sh(k + 2) = sh(k + 2) And m
    End If
  Next
  Reu.Stash SHAPEBANK, (size * 8 + turn) * 64, VarPtr(sh(0)), 64
End Sub

' one sprite: a task. Its numbers are in the arrays, under its own number
Sub Ball()
  Dim me As Integer
  Do
    me = Task.Id()
    px(me) = px(me) + vx(me)
    py(me) = py(me) + vy(me)
    If px(me) < 24 Or px(me) > 320 Then
      vx(me) = -vx(me) : px(me) = px(me) + vx(me)
      Sid.Tone 0, 200 + me * 60
    End If
    If py(me) < 50 Or py(me) > 229 Then
      vy(me) = -vy(me) : py(me) = py(me) + vy(me)
      Sid.Tone 1, 400 + me * 80
    End If
    ph(me) = (ph(me) + 1) And 31
    Reu.Fetch SHAPEBANK, (sz(me) * 8 + ph(me) \ 4) * 64, Vic.ShapeAddr(me - 1), 64
    Vic.Sprite me - 1, px(me), py(me)
    Task.Yield
  Loop
End Sub

Cls
Print "drawing 64 shapes into the REU"
For i = 0 To 7
  lm(i) = 255 \ Vic.Bit(i)              ' pixels i to 7 of a byte
  rm(i) = 255 - (127 \ Vic.Bit(i))      ' pixels 0 to i
  st(i) = 255
Next
st(0) = &H33 : st(1) = &H66 : st(2) = &HCC : st(3) = &H99
st(4) = &H33 : st(5) = &H66 : st(6) = &HCC : st(7) = &H99
For n = 0 To 7
  For i = 0 To 7
    MakeShape n, i
  Next
  Print n + 1; " ";
Next
Cls
Print "8 sprites, 64 shapes in the REU"
Print "each sprite is a task"
Sid.Volume 12
Sid.Voice 0, Sid.Triangle, 0, 8, 0, 0
Sid.Voice 1, Sid.Pulse, 0, 6, 0, 0
For i = 1 To 8
  id = Task.Start(AddressOf Ball)
  px(id) = 40 + i * 30 : py(id) = 60 + i * 18
  vx(id) = 1 + (i And 3) : vy(id) = 1 + ((i \ 2) And 1)
  If i And 1 Then vx(id) = -vx(id)
  sz(id) = i - 1
  Vic.Shape id - 1, id - 1
  Vic.Colour id - 1, 1 + i
Next
Do
  Frame
  Task.Yield
  Locate 1, 25
  Print "frame "; Ticks;
Loop

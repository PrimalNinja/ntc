' CHIP8 - a CHIP-8 interpreter in NTC BASIC. The classic virtual machine: 4K memory (the program
' at #200), 16 byte registers V0-VF, the index register I, a 16-level call stack, two 60Hz timers,
' a 64 x 32 XOR display and a 16-key hex keypad. About 35 opcodes.
'
' The display is text for now on every target (graphics to come once the CPC / CyborgOS screen is
' settled): the 64 x 32 bitmap is kept in memory and printed as # / space by DumpScreen, so VF
' (collision) is read from the kept display and the interpreter is proved without a screen. The
' graphics path (each pixel a 4 x 4 XOR block in mode 1) is written and kept behind #If GFX.
'
' The keypad (CPC keys -> CHIP-8 hex keys), the usual layout:
'   1 2 3 4      1 2 3 C
'   Q W E R  ->  4 5 6 D
'   A S D F      7 8 9 E
'   Z X C V      A 0 B F
'
' This build runs a small embedded demo ROM (DATA at the end): it draws the font digits 1 2 3,
' then exercises ADD-with-carry and BCD, and stops in a jump-to-itself. On the CPC a CHIP8.CH8 on
' the disc, if present, is loaded over the demo so a real game can be run.
Option Explicit

' Graphics is deferred - the display is text on every target for now (the same text path the zxn
' build uses). The GFX code is kept behind #If GFX for when the CPC / CyborgOS screen is settled.
#Const GFX = 0

Const OX = 32                         ' the display's top-left on the CPC screen (256 x 128 centred)
Const OY = 36
Const SCALE = 4
Const MAXCYC = 2000                   ' the console run: instructions before it gives up (no screen)

Dim mem(4095) As Byte                 ' 4K memory, the program from #200
Dim V(15) As Byte                     ' V0 - VF
Dim ireg As Integer                   ' the index register I (0 - 4095)
Dim pc As Integer                     ' the program counter
Dim sp As Integer                     ' the stack pointer
Dim stk(15) As Integer                ' the call stack
Dim dt As Integer, st As Integer      ' the delay and sound timers (0 - 255)
Dim disp(2047) As Byte                ' the 64 x 32 display, a byte a pixel (0 / 1)
Dim kp(15) As Byte                    ' the keypad, a byte a key (0 / 1)
Dim keymap(15) As Integer             ' CHIP-8 key -> CPC key number
Dim halted As Integer                 ' set when a jump-to-itself is seen (the program idles)
Dim cyc As Integer
Dim i As Integer, tframe As Integer

SetFont
SetKeymap
Reset
LoadRom

#If GFX Then
  Mode 1
  Graphics.Pen 1
  tframe = Ticks
  Do
    For i = 0 To 8
      Step
    Next
    If Ticks - tframe >= System.TicksPerSecond \ 60 Then
      If dt > 0 Then dt = dt - 1
      If st > 0 Then st = st - 1
      tframe = Ticks
    End If
    PollKeys
    If Keys.Down(Keys.KeyEsc) Then Exit Do
  Loop
  Mode 2
#Else
  Mode 2
  Do While halted = 0 And cyc < MAXCYC
    Step
    cyc = cyc + 1
  Loop
  DumpScreen
  Print "cycles "; cyc; "  V0="; V(0); " V1="; V(1); " V2="; V(2); " V3="; V(3); " V4="; V(4); " V5="; V(5); " VF="; V(15)
#End If
End

' Step - fetch the two bytes at pc, decode and run one instruction
Sub Step()
  Dim hi As Integer, lo As Integer, op As Integer, x As Integer, y As Integer, n As Integer, kk As Integer, nnn As Integer
  Dim here As Integer, t As Integer, j As Integer
  here = pc
  hi = mem(pc) : lo = mem(pc + 1)
  pc = (pc + 2) And &HFFF
  op = hi \ 16
  x = hi And 15
  y = lo \ 16
  n = lo And 15
  kk = lo
  nnn = (hi And 15) * 256 + lo
  Select Case op
    Case 0
      If lo = &HE0 Then
        ClearDisp
      ElseIf lo = &HEE Then
        sp = sp - 1 : If sp < 0 Then sp = 0
        pc = stk(sp)
      End If
    Case 1
      pc = nnn
      If nnn = here Then halted = 1
    Case 2
      stk(sp) = pc : sp = (sp + 1) And 15 : pc = nnn
    Case 3
      If V(x) = kk Then pc = (pc + 2) And &HFFF
    Case 4
      If V(x) <> kk Then pc = (pc + 2) And &HFFF
    Case 5
      If V(x) = V(y) Then pc = (pc + 2) And &HFFF
    Case 6
      V(x) = kk
    Case 7
      V(x) = (V(x) + kk) And 255
    Case 8
      Alu x, y, n
    Case 9
      If V(x) <> V(y) Then pc = (pc + 2) And &HFFF
    Case 10
      ireg = nnn
    Case 11
      pc = (nnn + V(0)) And &HFFF
    Case 12
      V(x) = Rnd(256) And kk
    Case 13
      Draw x, y, n
    Case 14
      If lo = &H9E Then
        If kp(V(x)) <> 0 Then pc = (pc + 2) And &HFFF
      ElseIf lo = &HA1 Then
        If kp(V(x)) = 0 Then pc = (pc + 2) And &HFFF
      End If
    Case 15
      Misc x, lo
  End Select
End Sub

' Alu - the 8XY_ register maths (VF is the carry / borrow / shifted bit)
Sub Alu(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer)
  Dim t As Integer
  Select Case n
    Case 0
      V(x) = V(y)
    Case 1
      V(x) = V(x) Or V(y)
    Case 2
      V(x) = V(x) And V(y)
    Case 3
      V(x) = V(x) Xor V(y)
    Case 4
      t = V(x) + V(y)
      V(x) = t And 255
      If t > 255 Then V(15) = 1 Else V(15) = 0
    Case 5
      t = V(x) - V(y)
      If V(x) >= V(y) Then V(15) = 1 Else V(15) = 0
      V(x) = t And 255
    Case 6
      V(15) = V(x) And 1
      V(x) = V(x) \ 2
    Case 7
      t = V(y) - V(x)
      If V(y) >= V(x) Then V(15) = 1 Else V(15) = 0
      V(x) = t And 255
    Case 14
      V(15) = (V(x) \ 128) And 1
      V(x) = (V(x) * 2) And 255
  End Select
End Sub

' Misc - the FX__ instructions (timers, I, font, BCD, store / load of registers)
Sub Misc(ByVal x As Integer, ByVal lo As Integer)
  Dim j As Integer
  Select Case lo
    Case &H07
      V(x) = dt
    Case &H0A
      WaitKey x
    Case &H15
      dt = V(x)
    Case &H18
      st = V(x)
    Case &H1E
      ireg = (ireg + V(x)) And &HFFF
    Case &H29
      ireg = V(x) * 5
    Case &H33
      mem(ireg) = V(x) \ 100
      mem((ireg + 1) And &HFFF) = (V(x) \ 10) Mod 10
      mem((ireg + 2) And &HFFF) = V(x) Mod 10
    Case &H55
      For j = 0 To x
        mem((ireg + j) And &HFFF) = V(j)
      Next
    Case &H65
      For j = 0 To x
        V(j) = mem((ireg + j) And &HFFF)
      Next
  End Select
End Sub

' Draw - DXYN: the n-byte sprite at memory I, XOR'd onto the display at (V(x), V(y)); VF is set if
' a lit pixel was turned off (a collision). Pixels off the right / bottom edge are clipped.
Sub Draw(ByVal xr As Integer, ByVal yr As Integer, ByVal nn As Integer)
  Dim px As Integer, py As Integer, row As Integer, b As Integer, bit As Integer, xx As Integer, yy As Integer, idx As Integer
  px = V(xr) And 63
  py = V(yr) And 31
  V(15) = 0
  For row = 0 To nn - 1
    yy = py + row
    If yy < 32 Then
      b = mem((ireg + row) And &HFFF)
      For bit = 0 To 7
        If (b \ (2 ^ (7 - bit))) And 1 Then
          xx = px + bit
          If xx < 64 Then
            idx = yy * 64 + xx
            If disp(idx) = 1 Then V(15) = 1
            disp(idx) = disp(idx) Xor 1
            BlockXor xx, yy
          End If
        End If
      Next
    End If
  Next
End Sub

' BlockXor - one CHIP-8 pixel as a 4 x 4 XOR block on the CPC (nothing on the console targets)
Sub BlockXor(ByVal px As Integer, ByVal py As Integer)
#If GFX Then
  Dim sx As Integer, sy As Integer, r As Integer
  sx = OX + px * SCALE
  sy = OY + py * SCALE
  For r = 0 To SCALE - 1
    Graphics.Line sx, sy + r, sx + SCALE - 1, sy + r
  Next
#End If
End Sub

' ClearDisp - 00E0: the display cleared (memory and, on the CPC, the screen)
Sub ClearDisp()
  Dim k As Integer
  For k = 0 To 2047
    disp(k) = 0
  Next
#If GFX Then
  Cls
#End If
End Sub

' PollKeys - the keypad read from the CPC keyboard (nothing on the console targets)
Sub PollKeys()
#If GFX Then
  Dim k As Integer
  For k = 0 To 15
    If Keys.Down(keymap(k)) Then kp(k) = 1 Else kp(k) = 0
  Next
#End If
End Sub

' WaitKey - FX0A: wait for a key, its value into V(x). On the console targets it returns 0.
Sub WaitKey(ByVal xr As Integer)
#If GFX Then
  Dim k As Integer, got As Integer
  got = -1
  Do
    PollKeys
    For k = 0 To 15
      If kp(k) <> 0 Then got = k
    Next
    If Keys.Down(Keys.KeyEsc) Then got = 0
  Loop Until got >= 0
  V(xr) = got
#Else
  V(xr) = 0
#End If
End Sub

' Reset - the machine to its start state (the program counter at #200)
Sub Reset()
  Dim k As Integer
  For k = 0 To 15
    V(k) = 0
    kp(k) = 0
    stk(k) = 0
  Next
  ireg = 0 : sp = 0 : dt = 0 : st = 0 : halted = 0 : cyc = 0
  pc = &H200
  For k = 0 To 2047
    disp(k) = 0
  Next
  Randomize Ticks
End Sub

' DumpScreen - the display printed (the console targets): # a lit pixel, trailing blanks dropped,
' empty rows at the bottom left off
Sub DumpScreen()
  Dim px As Integer, py As Integer, lastrow As Integer, s As String Max 64, idx As Integer
  lastrow = -1
  For py = 0 To 31
    For px = 0 To 63
      If disp(py * 64 + px) = 1 Then lastrow = py
    Next
  Next
  If lastrow < 0 Then Print "(display empty)" : Exit Sub
  For py = 0 To lastrow
    s = ""
    For px = 0 To 63
      If disp(py * 64 + px) = 1 Then s = s + "#" Else s = s + " "
    Next
    Do While Len(s) > 0 And Right$(s, 1) = " "
      s = Left$(s, Len(s) - 1)
    Loop
    Print s
  Next
End Sub

' HexB - a two-character hex string (e.g. "F0") as a byte 0-255
Function HexB(ByVal s As String) As Integer
  Dim a As Integer, b As Integer
  a = Asc(Mid$(s, 1, 1)) : If a >= 65 Then a = a - 55 Else a = a - 48
  b = Asc(Mid$(s, 2, 1)) : If b >= 65 Then b = b - 55 Else b = b - 48
  HexB = a * 16 + b
End Function

' SetFont - the 16 hex digit sprites (5 bytes each) into memory at 0, where FX29 points I
Sub SetFont()
  Dim k As Integer, s As String Max 160
  s = "F0909090F02060202070F010F080F0F010F010F09090F01010F080F010F0F080F090F0F010204040"
  s = s + "F090F090F0F090F010F0F090F09090E090E090E0F0808080F0E0909090E0F080F080F0F080F08080"
  For k = 0 To 79
    mem(k) = HexB(Mid$(s, k * 2 + 1, 2))
  Next
End Sub

' SetKeymap - the CHIP-8 hex keys to the CPC key numbers (the 1234 / QWER / ASDF / ZXCV block),
' as two hex digits each: 3F 40 41 39 43 3B 3A 45 3C 3D 47 3E 38 32 35 37
Sub SetKeymap()
  Dim k As Integer, s As String Max 32
  s = "3F404139433B3A453C3D473E38323537"
  For k = 0 To 15
    keymap(k) = HexB(Mid$(s, k * 2 + 1, 2))
  Next
End Sub

' LoadDemo - the embedded demo ROM into memory at #200: draw the font digits 1 2 3, then
' ADD-with-carry (VF) and BCD of 16, then a jump to itself. 44 bytes.
Sub LoadDemo()
  Dim k As Integer, s As String Max 100
  s = "600061006A01FA29D01570056A02FA29D01570056A03FA29D015630F6401834465FF8544A300F333F265122A"
  For k = 0 To Len(s) \ 2 - 1
    mem(&H200 + k) = HexB(Mid$(s, k * 2 + 1, 2))
  Next
End Sub

' LoadRom - the ROM to run. The command line names it (CyborgOS: "chip8 PACMAN.CH8"); with no
' name a CHIP8.CH8 on the drive is tried, and failing that the embedded demo runs. The file loads
' at #200, where the program counter starts.
Sub LoadRom()
  Dim nm As String Max 40, h As Integer, n As Integer, named As Integer
  nm = Trim$(System.CommandLine())
  named = 1
  If nm = "" Then
    nm = "CHIP8.CH8" : named = 0
  End If
  h = FileSystem.Open(nm, FileSystem.ForReadRaw)
  If h >= 0 Then
    n = FileSystem.Read(h, VarPtr(mem(&H200)), 4096 - &H200)
    h = FileSystem.Close(h)
    If n > 0 Then Exit Sub
  End If
  If named = 1 Then Print "chip8: cannot load "; nm
  LoadDemo
End Sub

' L2TEST - is Frame in step with the screen, and does NextReg #12 swap Layer 2's buffers?
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Buffer A (bank 16) is filled blue, buffer B (bank 19) red, then every frame: Frame, then swap.
'   Steady purple-ish flicker (red / blue every frame): both work.
'   Solid red, or solid blue: the swap (NextReg #12) isn't taking effect.
'   Red and blue bands, rolling or jumping: Frame isn't waiting for the end of the frame.
' The text shows the raster line read straight after each of 8 Frames (it should be 192 or
' just after), #12 read back after the swap, and #1E's whole byte (only bit 0 should be used).
' Press 1-4 for the CPU speed (3.5, 7, 14, 28MHz).
Option Explicit
Option Turbo

Dim r(7) As Integer, k As Integer, i As Integer, b12 As Integer, b1e As Integer, n As Integer

Cls
L2.Init &HE0                           ' both buffers red
For i = 0 To 191
  L2.Line 0, i, 255, i, &H03           ' the buffer drawn on (A, bank 16) blue
Next
Nx.Layers Nx.OrderLUS                  ' Layer 2 on top, cut to below the text (lines 48-191)
Nx.Reg &H1C, 1
Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 48 : Nx.Reg &H18, 191
Nx.Reg &H07, 3                         ' 28MHz to start
Do
  For k = 0 To 7
    Frame
    r(k) = Nx.Raster()
    L2.Flip
  Next
  b12 = Nx.RegGet(&H12)
  b1e = Nx.RegGet(&H1E)
  n = n + 1
  If (n And 7) = 0 Then
    Locate 0, 0
    Print "L2TEST  speed: "; Trim$(Str$(Nx.RegGet(&H07) And 3)); " (0=3.5 3=28)   "
    Print "lines after Frame:"
    For k = 0 To 7
      Print " "; Trim$(Str$(r(k)));
    Next
    Print "     "
    Print "#12 now: "; Trim$(Str$(b12)); "  #1E byte: "; Trim$(Str$(b1e)); "    "
    Print "1-4: 3.5 / 7 / 14 / 28MHz"
  End If
  If Keys.Down(Keys.Key1) Then Nx.Reg &H07, 0
  If Keys.Down(Keys.Key2) Then Nx.Reg &H07, 1
  If Keys.Down(Keys.Key3) Then Nx.Reg &H07, 2
  If Keys.Down(Keys.Key4) Then Nx.Reg &H07, 3
Loop

' Sfx - sound effects on the Next's AY chip (the first of its three), straight on the ports:
' #FFFD picks a register, #BFFD writes it. Three channels, each playing one effect at a time:
' a tone or noise whose pitch slides and whose volume fades to nothing over its length.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' Call Update once a frame (50 a second).
'   Sfx.Play 0, 200, 8, 15, 12, 0     ' channel A: tone period 200, rising pitch... 12 frames
Option Explicit

Private per(2) As Integer         ' the tone period now (12 bits; noise: 0-31)
Private slide(2) As Integer       ' added to it each frame
Private vol(2) As Integer         ' the volume it starts at (0-15)
Private total(2) As Integer       ' its length in frames
Private left(2) As Integer        ' frames to go (0 = silent)
Private nse(2) As Integer         ' 1 = noise, 0 = tone
Private mix As Integer

Private Sub W(ByVal r As Integer, ByVal v As Integer)
#asm
            pop hl
            ld a, (hl)
            ld bc, #FFFD
            out (c), a
            pop hl
            ld a, (hl)
            ld b, #BF
            out (c), a
#endasm
End Sub

' Init: AY 1 picked (the Next has three: Turbosound), every channel quiet
Public Sub Init()
  Dim i As Integer
  Out &HFFFD, &HFF                 ' AY 1 (Turbosound: #FF, #FE, #FD pick the chips)
  For i = 0 To 13
    W i, 0
  Next
  W 7, &H3F
  For i = 0 To 2
    left(i) = 0
  Next
End Sub

' Play ch, period, slidePerFrame, volume, frames, noise: start an effect on channel ch (0-2)
Public Sub Play(ByVal ch As Integer, ByVal period As Integer, ByVal sl As Integer, ByVal volume As Integer, ByVal frames As Integer, ByVal noise As Integer)
  If ch < 0 Or ch > 2 Then Exit Sub
  per(ch) = period : slide(ch) = sl : vol(ch) = volume : total(ch) = frames : left(ch) = frames : nse(ch) = noise
End Sub

' Busy(ch): True while channel ch plays
Public Function Busy(ByVal ch As Integer) As Integer
  Busy = (left(ch) > 0)
End Function

' Update: once a frame - the pitches slide, the volumes fade, the AY written
Public Sub Update()
  Dim i As Integer, v As Integer, p As Integer
  mix = &H3F
  For i = 0 To 2
    If left(i) > 0 Then
      v = (vol(i) * left(i) + total(i) - 1) \ total(i)
      p = per(i)
      If nse(i) Then
        W 6, p And 31
        mix = mix And Not (8 * (2 ^ i))
      Else
        W i * 2, p And 255
        W i * 2 + 1, (p \ 256) And 15
        mix = mix And Not (2 ^ i)
      End If
      W 8 + i, v
      per(i) = per(i) + slide(i)
      If per(i) < 1 Then per(i) = 1
      left(i) = left(i) - 1
    Else
      W 8 + i, 0
    End If
  Next
  W 7, mix
End Sub

' Quiet: every channel stopped
Public Sub Quiet()
  Dim i As Integer
  For i = 0 To 2
    left(i) = 0
    W 8 + i, 0
  Next
End Sub

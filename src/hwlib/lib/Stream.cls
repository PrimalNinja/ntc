' Stream - music streamed by the Pi (CyborgOS for the Pi: the audio service over a CPC-CPLink at
' &FD80 / &FD81): the same calls as the Next's Stream.cls (src/lib/zxn), so a program carries
' over - Open(name) the file (a STORE tag on the Pi: a .MUS of 8-bit unsigned samples at 12324 Hz
' as the Next's, or an .MP3 / .WAV), Fill once a frame (here: the Pi's events read, nothing to
' feed), Close, Playing. The Pi plays; the CPC does nothing between frames. NTC platforms: cpc,
' cpcfw, cpcmin (a plain CPC program, direct port I/O; the frames of cyborg-os/pi/proto.js)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Public Const OK = 0
Public Const NotFound = 1          ' the file isn't on the Pi (or no Pi)
Private chan As Integer, nid As Integer, sum As Integer, playing As Integer
Private buf(31) As Byte
Private hType As Integer, hChan As Integer, hId As Integer, hLen As Integer, hLen0 As Integer

' ---- the link (as Pi.cls's)
Private Sub ByteOut(ByVal b As Integer)
#asm
            ld bc, #FD81
so_w:       in a, (c)
            bit 1, a
            jr z, so_w
            dec c
            ld a, ({b})
            out (c), a
#endasm
End Sub
Private Function ByteIn() As Integer
#asm
            ld bc, #FD81
si_w:       in a, (c)
            bit 0, a
            jr z, si_w
            dec c
            in a, (c)
            ld l, a
            ld h, 0
            ld ({result}), hl
#endasm
End Function
Private Function ByteWaiting() As Integer
#asm
            ld bc, #FD81
            in a, (c)
            and 1
            ld l, a
            ld h, 0
            ld ({result}), hl
#endasm
End Function
Private Sub FrameStart(ByVal c As Integer, ByVal t As Integer, ByVal id As Integer, ByVal n As Integer)
  ByteOut &HA5
  sum = 0
  FrameByte c : FrameByte t : FrameByte id : FrameByte n And 255 : FrameByte n \ 256
End Sub
Private Sub FrameByte(ByVal b As Integer)
  ByteOut b
  sum = (sum + b) And 255
End Sub
Private Sub FrameEnd()
  ByteOut sum
End Sub
Private Sub FrameText(ByVal s As String Max 80)
  Dim i As Integer
  For i = 1 To Len(s)
    FrameByte Asc(Mid$(s, i, 1))
  Next
End Sub
Private Sub ReadHeader()
  Do While ByteIn() <> &HA5
  Loop
  hChan = ByteIn() : hType = ByteIn() And &H7F : hId = ByteIn()
  hLen = ByteIn() : hLen = hLen + ByteIn() * 256
  hLen0 = hLen
End Sub
Private Sub Done()
  Dim k As Integer
  k = ByteIn()
  If hChan <> 0 Then
    FrameStart hChan, 7, 0, 2 : FrameByte hLen0 And 255 : FrameByte hLen0 \ 256 : FrameEnd
  End If
End Sub
Private Sub SkipFrame()
  Dim k As Integer
  Do While hLen > 0
    hLen = hLen - 1 : k = ByteIn()
  Loop
  Done
End Sub
' Ask: a request, its answer's text into buf; True when it starts "OK"
Private Function Ask(ByVal c As Integer, ByVal s As String Max 80) As Integer
  Dim i As Integer, k As Integer
  nid = nid + 1 : If nid > 250 Then nid = 1
  FrameStart c, 2, nid, Len(s) : FrameText s : FrameEnd
  Do
    ReadHeader
    If hType = 3 And hId = nid Then Exit Do
    SkipFrame
  Loop
  i = 0
  Do While hLen > 0
    k = ByteIn() : hLen = hLen - 1
    If i < 31 Then buf(i) = k : i = i + 1
  Loop
  buf(i) = 0
  Done
  Ask = (buf(0) = Asc("O"))
End Function
Private Function BufNum(ByVal at As Integer) As Integer
  Dim v As Integer
  v = 0
  Do While buf(at) >= 48 And buf(at) <= 57
    v = v * 10 + buf(at) - 48 : at = at + 1
  Loop
  BufNum = v
End Function
' ---- the calls
' Open name: the file on the Pi (a STORE tag) played, looping as the Next's does: 0, or NotFound
Public Function Open(ByVal name As String) As Integer
  Dim r As Integer
  If chan = 0 Then
    FrameStart 0, 1, 0, 36 : FrameText "COS1 machine=cpc name=STREAM max=256" : FrameEnd
    ReadHeader : SkipFrame
    nid = 0
    If Ask(0, "OPEN audio") Then chan = BufNum(3)
  End If
  r = NotFound
  If chan <> 0 Then
    If Ask(chan, "LIST " + name) Then
      If Ask(chan, "PLAY " + name) Then r = OK : playing = 1
    End If
  End If
  Open = r
End Function
' Fill: once a frame - the Pi's events taken (ENDED: the list plays it again: the loop)
Public Sub Fill()
  Dim k As Integer
  Do While ByteWaiting()
    ReadHeader
    If hType = 5 Then
      k = ByteIn() : hLen = hLen - 1
      If k = Asc("E") Then playing = 0
      SkipFrame
      If playing = 0 Then
        If Ask(chan, "PLAY") Then playing = 1
      End If
    Else
      SkipFrame
    End If
  Loop
End Sub
Public Sub Close()
  Dim r As Integer
  If chan <> 0 Then r = Ask(chan, "STOP")
  playing = 0
End Sub
Public Function Playing() As Integer
  Playing = playing
End Function

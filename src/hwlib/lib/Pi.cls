' Pi - hwlib's library for the Pi's VDP (CyborgOS for the Pi: cosd's vdp service, over a
' CPC-CPLink / CPLink2 at &FD80 / &FD81): the same core calls as the chip libraries - Init,
' Pattern n, addr, Put n, x, y, pattern, Hide n, Anim n, first, count, delay, Move n, dx, dy,
' Bounds x0, y0, x1, y1, Frame, X(n), Y(n) - the table lives on the Pi, which moves, bounces and
' animates the sprites itself; Frame is one COMMIT and a wait for the Pi's frame. The profile is
' v9990 unless Profile$ is set before Init (v9938, zxn, md, pi720, pi1080, pi2160): patterns are
' the profile's own format (v9990: 16 x 16 4-bit, 128 bytes, as V9990.cls's). The picture is on
' the Pi's HDMI; the CPC's screen stays the CPC's. Palette n, r, g, b (0-255 each). Direct port
' I/O: a plain CPC program; the frames of cyborg-os/pi/proto.js. NTC platforms: cpc, cpcfw, cpcmin
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Const Slots = 125
Const LINKD = &HFD80
Const LINKS = &HFD81
Public Profile As String Max 8
Private chan As Integer, nid As Integer, sum As Integer
Private sx(Slots) As Integer, sy(Slots) As Integer          ' the last position the Pi told (X, Y)
Private buf(31) As Byte

' ---- the link: a byte out when there is room, a byte in when there is one
Private Sub ByteOut(ByVal b As Integer)
#asm
            ld bc, #FD81
bo_w:       in a, (c)
            bit 1, a
            jr z, bo_w
            dec c
            ld a, ({b})
            out (c), a
#endasm
End Sub
Private Function ByteIn() As Integer
#asm
            ld bc, #FD81
bi_w:       in a, (c)
            bit 0, a
            jr z, bi_w
            dec c
            in a, (c)
            ld l, a
            ld h, 0
            ld ({result}), hl
#endasm
End Function
' a frame: chan, type, id, then the payload a byte at a time through FrameByte, then FrameEnd
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
' a frame's header read (hunting for A5): its type in A, its length in n, the payload left to read
Private hType As Integer, hChan As Integer, hId As Integer, hLen As Integer, hLen0 As Integer
Private Sub ReadHeader()
  Do While ByteIn() <> &HA5
  Loop
  hChan = ByteIn() : hType = ByteIn() And &H7F : hId = ByteIn()
  hLen = ByteIn() : hLen = hLen + ByteIn() * 256
  hLen0 = hLen
End Sub
' Done: a frame fully read - its check taken, its bytes given back as credit (the Pi sends on a
' channel only what it was told there is room for; without this its answers queue behind events)
Private Sub Done()
  Dim k As Integer
  k = ByteIn()                                      ' the check
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
' a request on chan 0 or the channel, its answer's text into buf (up to 31 bytes); True when "OK"
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
' ---- the core
Public Sub Init()
  Dim i As Integer
  If Profile = "" Then Profile = "v9990"
  For i = 0 To Slots - 1
    sx(i) = 0 : sy(i) = 0
  Next
  nid = 0
  FrameStart 0, 1, 0, 35 : FrameText "COS1 machine=cpc name=HWLIB max=256" : FrameEnd
  ReadHeader : SkipFrame                            ' the Pi's HELLO
  nid = 0
  If Ask(0, "OPEN vdp profile=" + Profile + " vsync=1") Then chan = BufNum(3) Else chan = 0
  FrameStart chan, 4, 0, 1 : FrameByte 1 : FrameEnd ' the stream's version
  Bounds 0, 0, 239, 195
End Sub
' Pattern n, a: the pattern bytes at a (the profile's format: v9990 128 bytes) as pattern n
Public Sub Pattern(ByVal n As Integer, ByVal a As Integer)
  Dim i As Integer, s As String Max 16
  s = "PATTERNS " + Str$(n)
  nid = nid + 1
  FrameStart chan, 2, nid, Len(s) + 1 + 128 : FrameText s : FrameByte 0
  For i = 0 To 127
    FrameByte Peek(a + i)
  Next
  FrameEnd
  Do
    ReadHeader
    If hType = 3 And hId = nid Then Exit Do
    SkipFrame
  Loop
  SkipFrame
End Sub
Public Sub Palette(ByVal n As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
  Dim s As String Max 16
  s = "PALETTE " + Str$(n)
  nid = nid + 1
  FrameStart chan, 2, nid, Len(s) + 4
  FrameText s
  FrameByte 0
  FrameByte r
  FrameByte g
  FrameByte b
  FrameEnd
  Do
    ReadHeader
    If hType = 3 And hId = nid Then Exit Do
    SkipFrame
  Loop
  SkipFrame
End Sub
Private Sub Cmd(ByVal op As Integer, ByVal n As Integer)
  FrameStart chan, 4, 0, n : FrameByte op
End Sub
Private Sub W16(ByVal v As Integer)
  FrameByte v And 255 : FrameByte (v \ 256) And 255
End Sub
Public Sub Put(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal p As Integer)
  Cmd 1, 10 : W16 n : W16 p : W16 x : W16 y : FrameByte 1 : FrameEnd
  Cmd 6, 4 : W16 n : FrameByte 5 : FrameEnd         ' BOUNDS: bounce within the box
  sx(n) = x : sy(n) = y
End Sub
Public Sub Hide(ByVal n As Integer)
  Cmd 4, 4 : W16 n : FrameByte 0 : FrameEnd
End Sub
Public Sub Anim(ByVal n As Integer, ByVal first As Integer, ByVal count As Integer, ByVal delay As Integer)
  Cmd 9, 7 : W16 n : W16 first : FrameByte count : FrameByte delay : FrameEnd
End Sub
' Seq s, addr, count: sequence s (0-255) from count words at addr: pattern numbers, 0 stop (the frame
' shown stays, DONE n comes back), -k go to step k (1 based: behind for a loop, ahead to redirect) -
' one pattern set, many animations (walk left, walk right, die ...)
Public Sub Seq(ByVal s As Integer, ByVal a As Integer, ByVal count As Integer)
  Dim i As Integer
  Cmd 14, 3 + count * 2 : FrameByte s : FrameByte count
  For i = 0 To count - 1
    FrameByte Peek(a + i * 2) : FrameByte Peek(a + i * 2 + 1)
  Next
  FrameEnd
End Sub
' Play n, s, delay: sprite n runs sequence s, a step every delay frames (Anim's range animation off)
Public Sub Play(ByVal n As Integer, ByVal s As Integer, ByVal delay As Integer)
  Cmd 15, 5 : W16 n : FrameByte s : FrameByte delay : FrameEnd
End Sub
Public Sub Move(ByVal n As Integer, ByVal dx As Integer, ByVal dy As Integer)
  Cmd 5, 7 : W16 n : W16 dx * 16 : W16 dy * 16 : FrameEnd   ' 12.4
End Sub
Public Sub Bounds(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  Cmd 12, 9 : W16 x0 : W16 y0 : W16 x1 : W16 y1 : FrameEnd
End Sub
' X(n), Y(n): where sprite n is now - asked of the Pi (STATE n), a round trip
Public Function X(ByVal n As Integer) As Integer
  Where n
  X = sx(n)
End Function
Public Function Y(ByVal n As Integer) As Integer
  Where n
  Y = sy(n)
End Function
Private Sub Where(ByVal n As Integer)
  Dim at As Integer
  If Ask(chan, "STATE " + Str$(n)) Then
    at = 3
    Do While buf(at) <> 32 And buf(at) <> 0
      at = at + 1
    Loop
    at = at + 1 : sx(n) = BufNum(at)
    Do While buf(at) <> 32 And buf(at) <> 0
      at = at + 1
    Loop
    at = at + 1 : sy(n) = BufNum(at)
  End If
End Sub
' Frame: the batch committed, then the Pi's next V event waited for (events before it dropped)
Public Sub Frame()
  Dim k As Integer
  Cmd &H7F, 1 : FrameEnd
  Do
    ReadHeader
    If hType = 5 Then
      k = ByteIn() : hLen = hLen - 1
      SkipFrame
      If k = Asc("V") Then Exit Do
    Else
      SkipFrame
    End If
  Loop
End Sub

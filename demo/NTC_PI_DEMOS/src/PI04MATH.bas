' PI04MATH - NTC PI DEMOS 4: the maths coprocessor. EVAL (floating point), BIG (whole numbers of
' any size) and XFORM (3D points through a matrix, projected to the screen by the Pi).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim w(40) As Integer, r(9) As Integer
Dim ch As Integer, i As Integer, ok As Integer

Sub Ev(ByVal q As String Max 40, ByVal want As String Max 40)
  Dim ok As Integer
  ok = Link.Ask(ch, q)
  Link.Check q & " = " & Mid$(want, 4), ok And Left$(Link.Reply, Len(want)) = want
End Sub

Mode 2
Link.Title "PI04 MATH - the Pi as a maths coprocessor"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("math")
Link.Check "OPEN math", ch > 0
If ch = 0 Then Link.Summary : End
Ev "EVAL 2+3*4", "OK 14"
Ev "EVAL (2+3)*4", "OK 20"
Ev "EVAL sqrt(2)", "OK 1.41421356"
Ev "EVAL sin(pi/2)", "OK 1"
Ev "EVAL &HFF+1", "OK 256"
Ev "EVAL 2^10", "OK 1024"
Ev "EVAL 10/4", "OK 2.5"
Ev "BIG 2^100", "OK 1267650600228229401496703205376"
Ev "BIG 99999999999*99999999999", "OK 9999999999800000000001"
ok = Link.Ask(ch, "EVAL 2+")
Link.Check "a broken sum is refused", Not ok
Print "    "; Link.Reply

' XFORM: 12 words the matrix (3 rows of 4, 8.8 fixed point: 256 is 1.0), the screen's centre x, y,
' the focal length, then the points x, y, z. Back: each point's screen x, y.
For i = 0 To 11
  w(i) = 0
Next
w(0) = 256 : w(5) = 256 : w(10) = 256
w(12) = 160 : w(13) = 100 : w(14) = 256
w(15) = 0 : w(16) = 0 : w(17) = 256            ' straight ahead: the centre
w(18) = 100 : w(19) = 50 : w(20) = 256         ' right and up: 260, 50
w(21) = -64 : w(22) = -32 : w(23) = 128        ' left, down, nearer: 32, 164
w(24) = 10 : w(25) = 10 : w(26) = -5           ' behind the eye: -32768
Link.Check "XFORM 4 points", Link.AskBoth(ch, "XFORM", VarPtr(w), 54, VarPtr(r), 16)
Link.Check "  16 bytes back", Link.BodyLen = 16
For i = 0 To 3
  Print "    point "; i; ": "; r(i * 2); ", "; r(i * 2 + 1)
Next
Link.Check "  the centre is 160, 100", r(0) = 160 And r(1) = 100
Link.Check "  right and up is 260, 50", r(2) = 260 And r(3) = 50
Link.Check "  left, down, nearer is 32, 164", r(4) = 32 And r(5) = 164
Link.Check "  behind the eye is -32768", r(6) = -32768 And r(7) = -32768
Link.Shut ch
Link.Summary

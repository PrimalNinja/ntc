' PI07TERM - NTC PI DEMOS 7: a shell on the Pi with the CPC as its terminal. DATA frames both
' ways: a command typed for it, what comes back shown; then exit, and the Pi's EXIT event.
' Refused by a cosd started with --no-run (said, not counted as a failure).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim b(255) As Byte
Dim ch As Integer, i As Integer, k As Integer, t As Integer
Dim at As Integer, seen As Integer, got As Integer, gone As Integer
Dim want As String Max 8

' Feed: the bytes that came, shown; "CPC-42" looked for across the frames
Sub Feed()
  Dim i As Integer, c As Integer
  For i = 0 To Link.Kept - 1
    c = b(i)
    If c >= 32 And c < 127 Then Print Chr$(c);
    If c = 10 Then Print
    If c = Asc(Mid$(want, at + 1, 1)) Then
      at = at + 1
      If at = Len(want) Then seen = True : at = 0
    Else
      at = 0
    End If
  Next
  got = got + Link.Kept
End Sub
Sub Listen(ByVal n As Integer)
  Dim t As Integer, k As Integer
  t = Ticks
  Do
    k = Link.Poll(VarPtr(b), 256)
    If k = 4 Then Feed
    If k = 5 Then Print : Print "    event: "; Link.Reply : If Left$(Link.Reply, 4) = "EXIT" Then gone = True
    If k = 6 Then gone = True
  Loop Until Link.Lost Or gone Or (Ticks - t > n)
End Sub

Mode 2
Link.Title "PI07 TERM - a shell on the Pi, the CPC its terminal"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("term cols=80 rows=24 type=dumb")
If ch = 0 Then
  Print "OPEN term was refused: "; Link.Reply
  Print "(a Pi whose cosd runs with --no-run keeps its shell off the link: nothing to test)"
  Link.Summary : End
End If
Link.Check "OPEN term", True
want = "CPC-42" : at = 0 : seen = False : got = 0 : gone = False
Listen 450
Link.SendText ch, "echo CPC-$((6*7))" & Chr$(10)
Listen 900
Print
Link.Check "the shell wrote something", got > 0
Link.Check "the command's answer CPC-42 came back", seen
Link.SendText ch, "exit" & Chr$(10)
Listen 900
Print
Link.Check "the shell ended (EXIT, the channel closed)", gone
Link.Summary

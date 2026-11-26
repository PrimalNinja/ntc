' PI08VDU - NTC PI DEMOS 8: the Pi's HDMI as a full HD virtual display. Lines of commands as
' DATA; the page (http://pi:8084/ in a browser, or the Pi's own screen) draws them. The CPC can
' not see the picture: LOOK AT THE PI'S SCREEN. A click or a key on the page comes back as an
' event and is shown here (10 seconds are waited for one).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim b(255) As Byte
Dim ch As Integer, k As Integer, t As Integer, bad As Integer, ev As Integer

Sub L(ByVal s As String Max 78)
  Link.SendText ch, s & Chr$(10)
End Sub

Mode 2
Link.Title "PI08 VDU - the Pi's HDMI as a virtual display (mode=hd)"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("vdu mode=hd title=PIDEMO")
Link.Check "OPEN vdu mode=hd", ch > 0
If ch = 0 Then Link.Summary : End
L "CLS 0 0 64"
L "COLOR 255 255 0"
L "FONT 96 sans"
L "TEXT 160 220 NTC PI DEMOS"
L "COLOR 255 255 255"
L "FONT 48 mono"
L "TEXT 160 300 Hello from the Amstrad CPC"
L "COLOR 255 0 0"
L "FILL 160 400 400 200"
L "COLOR 0 255 0"
L "RECT 600 400 400 200"
L "COLOR 0 255 255"
L "LINE 160 700 1760 700 8"
L "COLOR 255 0 255"
L "CIRCLE 1400 500 120 fill"
L "TITLE PIDEMO - PI08VDU"
Link.Check "the drawing sent (16 lines of commands)", Not Link.Lost
Print
Print "ON THE PI'S SCREEN there should now be, on dark blue:"
Print "  NTC PI DEMOS in big yellow letters, Hello from the Amstrad CPC in white,"
Print "  a red filled box, a green outlined box, a magenta disc, a cyan line under them."
Print
Print "Click the page or press a key on it (10 seconds) ..."
t = Ticks : bad = 0 : ev = 0
Do
  k = Link.Poll(VarPtr(b), 256)
  If k = 5 Then
    Print "    event: "; Link.Reply
    ev = ev + 1
    If Left$(Link.Reply, 3) = "ERR" Then bad = bad + 1
  End If
Loop Until Link.Lost Or (Ticks - t > 3000)
Print "    "; ev; " events"
Link.Check "no error came from the display", bad = 0
Link.Check "CHANS lists the channel", Link.AskTo(0, "CHANS", VarPtr(b), 255)
Print "    "; Link.Reply; " ";
For k = 0 To Link.Kept - 1
  If b(k) >= 32 Then Print Chr$(b(k)); Else Print " / ";
Next
Print
Link.Shut ch
Link.Summary

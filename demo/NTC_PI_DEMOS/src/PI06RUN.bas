' PI06RUN - NTC PI DEMOS 6: a command run on the Pi, its output back. The output comes in parts
' as the command writes it; the last part is OK exit=n. cosd started with --no-run refuses this:
' the program says so and does not count it as a failure.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim b(1023) As Byte
Dim ch As Integer, i As Integer, ok As Integer

Sub Show()
  Dim i As Integer
  For i = 0 To Link.Kept - 1
    If b(i) >= 32 Or b(i) = 10 Or b(i) = 13 Then Print Chr$(b(i));
  Next
End Sub

Mode 2
Link.Title "PI06 RUN - a command run on the Pi"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("run")
If ch = 0 Then
  Print "OPEN run was refused: "; Link.Reply
  Print "(a Pi whose cosd runs with --no-run keeps its shell off the link: nothing to test)"
  Link.Summary : End
End If
Link.Check "OPEN run", True
Link.Patience = 3000
Link.Check "RUN echo CPC-$((6*7))", Link.AskTo(ch, "RUN echo CPC-$((6*7))", VarPtr(b), 1023)
Show
Link.Check "  it printed CPC-42", Link.Kept >= 6 And b(0) = 67 And b(4) = 52 And b(5) = 50
Link.Check "  it ended with OK exit=0", Link.Reply = "OK exit=0"
Link.Check "RUN uname -a", Link.AskTo(ch, "RUN uname -a", VarPtr(b), 1023)
Show
Link.Check "RUN ls -l /", Link.AskTo(ch, "RUN ls -l /", VarPtr(b), 1023)
Show
Print "    ("; Link.BodyLen; " bytes in "; Link.Parts; " frames)"
ok = Link.Ask(ch, "RUN exit 3")
Link.Check "RUN exit 3 gives exit=3", Link.Reply = "OK exit=3"
ok = Link.AskTo(ch, "RUN nosuchcommandhere", VarPtr(b), 1023)
Link.Check "a command that is not there gives exit=127", Link.Reply = "OK exit=127"
Show
ok = Link.Ask(ch, "FROB")
Link.Check "an unknown request is refused", Not ok
Link.Shut ch
Link.Summary

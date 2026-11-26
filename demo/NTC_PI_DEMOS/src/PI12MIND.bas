' PI12MIND - NTC PI DEMOS 12: the generative model run on the Pi (GEN.MDL, the same ternary GRU
' NTC's Net class runs on the Z80, about 1000 times sooner). MODELS lists the .MDL files in the
' Pi's ~/.cosd/models; the first is loaded and asked for 60 characters. With no model there, or
' the Pi's ntck addon not built (cd pi/ntck && sh build.sh), the program says so and stops:
' that is not counted as a failure of the link.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim b(255) As Byte
Dim ch As Integer, i As Integer, ok As Integer
Dim name As String Max 20

Mode 2
Link.Title "PI12 MIND - the generative model on the Pi"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("mind")
Link.Check "OPEN mind", ch > 0
If ch = 0 Then Link.Summary : End
ok = Link.Ask(ch, "MODELS")
Print "    "; Link.Reply
If Not ok Then
  Print "The model service is there but cannot run on this Pi (see the line above)."
  Link.Summary : End
End If
Link.Check "MODELS", True
name = ""
i = 4
Do While i <= Len(Link.Reply)
  If Mid$(Link.Reply, i, 1) = " " Then Exit Do
  name = name & Mid$(Link.Reply, i, 1) : i = i + 1
Loop
If name = "" Then
  Print "No model on the Pi: put GEN.MDL (CyborgOS's apps/gen) in ~/.cosd/models and run again."
  Link.Summary : End
End If
Link.Patience = 3000
Link.Check "LOAD " & name, Link.Ask(ch, "LOAD " & name)
Print "    "; Link.Reply; "  (V E H L K)"
Link.Check "INFO", Link.Ask(ch, "INFO")
Print "    "; Link.Reply
Link.Check "RUN 60 hello", Link.AskTo(ch, "RUN 60 hello ", VarPtr(b), 255)
Link.Check "  60 characters came", Link.BodyLen = 60
Print "    ";
For i = 0 To Link.Kept - 1
  If b(i) >= 32 And b(i) < 127 Then Print Chr$(b(i));
Next
Print
Link.Check "RESET", Link.Ask(ch, "RESET")
Link.Check "RUN 60 hello again gives the same text (the state was reset)", Link.AskTo(ch, "RUN 60 hello ", VarPtr(b) + 64, 64)
ok = True
For i = 0 To 59
  If b(i) <> b(64 + i) Then ok = False
Next
Link.Check "  the same 60 characters", ok
Link.Shut ch
Link.Summary

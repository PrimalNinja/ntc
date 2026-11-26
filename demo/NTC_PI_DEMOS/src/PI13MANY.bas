' PI13MANY - NTC PI DEMOS 13: several channels over the one link, at once. Store, maths and
' float are opened together and asked turn about, 20 rounds; then a channel is closed in the
' middle and the others carry on; then all the Pi's channels are listed.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim a(63) As Byte, b(255) As Byte, q(11) As Byte
Dim s As Integer, m As Integer, f As Integer, i As Integer, j As Integer, ok As Integer, good As Integer, t As Integer

Mode 2
Link.Title "PI13 MANY - several channels at once"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
s = Link.Open("store") : m = Link.Open("math") : f = Link.Open("float")
Link.Check "three channels open, each its own number", s > 0 And m > 0 And f > 0 And s <> m And m <> f And s <> f
Print "    store "; s; ", math "; m; ", float "; f
If s = 0 Or m = 0 Or f = 0 Then Link.Summary : End
For i = 0 To 11
  q(i) = 0
Next
q(2) = &H80 : q(3) = &H3F : q(6) = &H80 : q(7) = &H3F       ' 1.0 and 1.0
good = 0 : t = Ticks
For i = 1 To 20
  For j = 0 To 63
    a(j) = (i + j) And 255
  Next
  ok = Link.AskWith(s, "PUT PIDEMO/ROUND", VarPtr(a), 64)
  ok = ok And Link.Ask(m, "EVAL " & i & "*" & i) And Link.Num(4) = i * i
  ok = ok And Link.AskBoth(f, "OP 1", VarPtr(q), 12, VarPtr(b), 8) And b(3) = &H40
  ok = ok And Link.AskTo(s, "GET PIDEMO/ROUND", VarPtr(b), 64) And b(0) = (i And 255) And b(63) = ((i + 63) And 255)
  If ok Then good = good + 1
Next
t = Ticks - t
Link.Check "20 rounds of store, maths, float, store - all right", good = 20
Print "    80 requests in "; t; " ticks (300 a second)"
Link.Shut m
ok = Link.Ask(m, "EVAL 1+1")
Link.Check "the maths channel closed: it takes no more", Not ok
Link.Check "the store still answers", Link.Ask(s, "SIZE PIDEMO/ROUND") And Link.Num(4) = 64
Link.Check "the float still answers", Link.AskBoth(f, "OP 1", VarPtr(q), 12, VarPtr(b), 8)
m = Link.Open("math")
Link.Check "maths opened again", m > 0
Link.Check "  and it answers", Link.Ask(m, "EVAL 6*7") And Link.Reply = "OK 42"
Link.Check "CHANS", Link.AskTo(0, "CHANS", VarPtr(b), 255)
Print "    "; Link.Reply; " ";
For i = 0 To Link.Kept - 1
  If b(i) >= 32 Then Print Chr$(b(i)); Else Print " / ";
Next
Print
Link.Check "DEL the round's tag", Link.Ask(s, "DEL PIDEMO/ROUND")
Link.Shut s : Link.Shut m : Link.Shut f
Print "    frames skipped while waiting for answers: "; Link.Skipped
Link.Summary

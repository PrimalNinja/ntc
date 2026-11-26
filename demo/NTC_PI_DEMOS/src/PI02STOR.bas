' PI02STOR - NTC PI DEMOS 2: the store. A piece of tagged data put on the Pi, got back and
' compared; then SIZE, a part of it, APPEND, LIST, DEL and the refusals.
' The tags are PIDEMO/PIECE and PIDEMO/HELLO.TXT in this machine's own folder (name=PIDEMO).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim a(255) As Byte, b(255) As Byte
Dim ch As Integer, i As Integer, ok As Integer
Dim s As String Max 40

Function Same(ByVal n As Integer, ByVal from As Integer) As Integer
  Dim i As Integer
  Same = True
  For i = 0 To n - 1
    If b(i) <> a(from + i) Then Same = False
  Next
End Function

Mode 2
Link.Title "PI02 STORE - tagged data kept on the Pi"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("store")
Link.Check "OPEN store", ch > 0
If ch = 0 Then Link.Summary : End
Print "    channel "; ch

For i = 0 To 255
  a(i) = (i * 7 + 3) And 255
Next
Link.Check "PUT PIDEMO/PIECE (64 bytes)", Link.AskWith(ch, "PUT PIDEMO/PIECE", VarPtr(a), 64)
Link.Check "  the Pi says OK 64", Link.Reply = "OK 64"
Link.Check "SIZE", Link.Ask(ch, "SIZE PIDEMO/PIECE")
Print "    "; Link.Reply
Link.Check "  64 bytes", Link.Num(4) = 64
Link.Check "GET it back", Link.AskTo(ch, "GET PIDEMO/PIECE", VarPtr(b), 256)
Link.Check "  64 bytes came", Link.BodyLen = 64 And Link.Kept = 64
Link.Check "  the same bytes", Same(64, 0)
Link.Check "GET bytes 10 to 14 (GET tag 10 5)", Link.AskTo(ch, "GET PIDEMO/PIECE 10 5", VarPtr(b), 256)
Link.Check "  5 bytes, the right ones", Link.BodyLen = 5 And Same(5, 10)
Link.Check "APPEND 16 more", Link.AskWith(ch, "APPEND PIDEMO/PIECE", VarPtr(a) + 64, 16)
Link.Check "  now 80", Link.Reply = "OK 80"
Link.Check "GET all 80", Link.AskTo(ch, "GET PIDEMO/PIECE", VarPtr(b), 256)
Link.Check "  80 bytes, the same", Link.BodyLen = 80 And Same(80, 0)

s = "Hello from the CPC."
Link.Check "PUT PIDEMO/HELLO.TXT (text)", Link.AskWith(ch, "PUT PIDEMO/HELLO.TXT", VarPtr(s), Len(s))
Link.Check "LIST PIDEMO/", Link.AskTo(ch, "LIST PIDEMO/", VarPtr(b), 255)
Link.Check "  two tags", Link.Num(4) = 2
For i = 0 To Link.Kept - 1
  Print Chr$(b(i));
Next
Print

Link.Check "an empty PUT (0 bytes)", Link.Ask(ch, "PUT PIDEMO/EMPTY")
Link.Check "  SIZE says 0", Link.Ask(ch, "SIZE PIDEMO/EMPTY") And Link.Num(4) = 0
Link.Check "DEL the three", Link.Ask(ch, "DEL PIDEMO/PIECE") And Link.Ask(ch, "DEL PIDEMO/HELLO.TXT") And Link.Ask(ch, "DEL PIDEMO/EMPTY")
ok = Link.Ask(ch, "GET PIDEMO/PIECE")
Link.Check "GET after DEL is refused (ERR notag)", (Not ok) And Left$(Link.Reply, 9) = "ERR notag"
ok = Link.Ask(ch, "DEL PIDEMO/PIECE")
Link.Check "DEL again is refused", Not ok
ok = Link.AskWith(ch, "PUT ../OUTSIDE", VarPtr(a), 4)
Link.Check "a tag that climbs out (../) is refused", Not ok
Print "    "; Link.Reply
ok = Link.Ask(ch, "FROB")
Link.Check "an unknown request is refused", Not ok
Link.Shut ch
Link.Check "CLOSE", Link.Reply = "OK"
ok = Link.Ask(ch, "SIZE PIDEMO/PIECE")
Link.Check "the closed channel takes no more requests (ERR nochan)", (Not ok) And Left$(Link.Reply, 10) = "ERR nochan"
Link.Summary

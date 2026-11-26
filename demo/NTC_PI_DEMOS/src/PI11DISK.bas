' PI11DISK - NTC PI DEMOS 11: Pi volumes - a folder on the Pi as a disc with real random access.
' A volume PIDEMO is made, mounted as drive P, a file written record by record (128 bytes each,
' out of order, with a gap), read back, sized, found, renamed, erased; then the volume dropped.
' Nothing else on the Pi is touched. (cosd keeps volumes in /home/cyborgos: it must be able to
' write there.)
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim a(255) As Byte, b(255) As Byte
Dim ch As Integer, i As Integer, h As Integer, ok As Integer, bad As Integer

Sub Show()
  Dim i As Integer
  For i = 0 To Link.Kept - 1
    If b(i) >= 32 Then Print Chr$(b(i)); Else If b(i) = 10 Then Print
  Next
  Print
End Sub

Mode 2
Link.Title "PI11 DISK - Pi volumes (random access records)"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("disk")
Link.Check "OPEN disk", ch > 0
If ch = 0 Then Link.Summary : End
' left over from a run that stopped half way: out of the way first (the answers do not matter)
ok = Link.Ask(ch, "UNMOUNT PIDEMO") : ok = Link.Ask(ch, "DROP PIDEMO YES")

Link.Check "VOLUMES", Link.AskTo(ch, "VOLUMES", VarPtr(b), 255)
Print "    "; Link.Reply : Show
ok = Link.Ask(ch, "NEW PIDEMO")
Link.Check "NEW PIDEMO", ok
If Not ok Then Print "    "; Link.Reply : Link.Summary : End
ok = Link.Ask(ch, "MOUNT PIDEMO P")
Link.Check "MOUNT PIDEMO P", ok
If Not ok Then Print "    "; Link.Reply
ok = Link.Ask(ch, "OPEN P:TEST.DAT new")
Link.Check "OPEN P:TEST.DAT new", ok
Print "    "; Link.Reply
h = Link.Num(4)
For i = 0 To 255
  a(i) = (i * 5 + 1) And 255
Next
Link.Check "WRITE records 0 and 1 (256 bytes)", Link.AskWith(ch, "WRITE " & h & " 0", VarPtr(a), 256)
Link.Check "SIZE says 2 records, 256 bytes", Link.Ask(ch, "SIZE " & h) And Link.Reply = "OK 2 256"
Link.Check "READ record 1", Link.AskTo(ch, "READ " & h & " 1", VarPtr(b), 256)
bad = 0
For i = 0 To 127
  If b(i) <> a(128 + i) Then bad = bad + 1
Next
Link.Check "  128 bytes, the second half of what was written", Link.BodyLen = 128 And bad = 0
Link.Check "READ records 0 and 1 in one request (READ h 0 2)", Link.AskTo(ch, "READ " & h & " 0 2", VarPtr(b), 256)
bad = 0
For i = 0 To 255
  If b(i) <> a(i) Then bad = bad + 1
Next
Link.Check "  256 bytes, the same", Link.BodyLen = 256 And bad = 0
Link.Check "WRITE record 4, leaving a gap (records 2 and 3)", Link.AskWith(ch, "WRITE " & h & " 4", VarPtr(a), 128)
Link.Check "SIZE says 5 records, 640 bytes", Link.Ask(ch, "SIZE " & h) And Link.Reply = "OK 5 640"
Link.Check "READ record 3 (in the gap)", Link.AskTo(ch, "READ " & h & " 3", VarPtr(b), 256)
bad = 0
For i = 0 To 127
  If b(i) <> 0 Then bad = bad + 1
Next
Link.Check "  128 zeros", Link.BodyLen = 128 And bad = 0
Link.Check "READ record 9 (past the end) gives none", Link.AskTo(ch, "READ " & h & " 9", VarPtr(b), 256) And Link.Reply = "OK 0"
Link.Check "CLOSE the file", Link.Ask(ch, "CLOSE " & h)
Link.Check "FIND P:*.*", Link.AskTo(ch, "FIND P:*.*", VarPtr(b), 255)
Print "    "; Link.Reply : Show
Link.Check "  one file", Link.Num(4) = 1
Link.Check "REN P:NEW.DAT P:TEST.DAT", Link.Ask(ch, "REN P:NEW.DAT P:TEST.DAT")
Link.Check "MKDIR P:SUB", Link.Ask(ch, "MKDIR P:SUB")
Link.Check "FIND shows NEW.DAT and SUB", Link.AskTo(ch, "FIND P:*.*", VarPtr(b), 255) And Link.Num(4) = 2
Show
Link.Check "FREE P", Link.Ask(ch, "FREE P")
Print "    "; Link.Reply; " (kilobytes free on the Pi)"
ok = Link.Ask(ch, "OPEN P:../OUT.DAT new")
Link.Check "a path that leaves the volume is refused", Not ok
Print "    "; Link.Reply
Link.Check "RMDIR P:SUB", Link.Ask(ch, "RMDIR P:SUB")
Link.Check "ERA P:NEW.DAT (1 file gone)", Link.Ask(ch, "ERA P:NEW.DAT") And Link.Num(4) = 1
Link.Check "UNMOUNT P", Link.Ask(ch, "UNMOUNT P")
Link.Check "DROP PIDEMO YES", Link.Ask(ch, "DROP PIDEMO YES")
Link.Shut ch
Link.Summary

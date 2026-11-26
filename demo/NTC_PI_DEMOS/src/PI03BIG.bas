' PI03BIG - NTC PI DEMOS 3: data bigger than a frame. 6000 bytes sent to the store in parts,
' got back and compared, timed both ways. On a CPC-CPLink the answer comes in parts through the
' FIFO; on a CPLink2 it comes through the Pi ROM (ROM 32 at &C000) - the program says which.
' Then 20000 bytes (a PUT and an APPEND of 10000), which on a CPLink2 is ROM 32 and ROM 33.
' Byte i of the data is always (i * 13 + i \ 256) And 255, so one buffer does for both ways.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Const BIG = 20000
Dim b(19999) As Byte
Dim ch As Integer, i As Integer, bad As Integer

Sub Fill(ByVal n As Integer, ByVal from As Integer)
  Dim i As Integer, v As Integer
  For i = 0 To n - 1
    v = from + i
    b(i) = (v * 13 + v \ 256) And 255
  Next
End Sub
Function Wrong(ByVal n As Integer, ByVal from As Integer) As Integer
  Dim i As Integer, v As Integer, k As Integer
  k = 0
  For i = 0 To n - 1
    v = from + i
    If b(i) <> ((v * 13 + v \ 256) And 255) Then k = k + 1
  Next
  Wrong = k
End Function
Sub Back(ByVal n As Integer)
  Dim i As Integer, t As Integer, bad As Integer
  For i = 0 To n - 1 Step 61
    b(i) = b(i) Xor 255
  Next
  t = Ticks
  Link.Check "GET it back", Link.AskTo(ch, "GET PIDEMO/BIG", VarPtr(b), BIG)
  t = Ticks - t
  If Link.Bulk Then
    Print "    it came through the Pi ROM (a CPLink2): "; t; " ticks"
  Else
    Print "    it came through the FIFO in "; Link.Parts; " frames: "; t; " ticks"
  End If
  Link.Check "  all of it came", Link.BodyLen = n And Link.Kept = n
  bad = Wrong(n, 0)
  Link.Check "  the same bytes", bad = 0
  If bad > 0 Then Print "    "; bad; " bytes differ"
End Sub

Mode 2
Link.Title "PI03 BIG - data in parts, and the CPLink2's Pi ROM"
If Link.IsCPLink2() Then Print "Card: CPLink2" Else Print "Card: CPC-CPLink"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("store")
Link.Check "OPEN store", ch > 0
If ch = 0 Then Link.Summary : End

Print "6000 bytes:"
Fill 6000, 0
i = Ticks
Link.Check "PUT PIDEMO/BIG in parts", Link.AskWith(ch, "PUT PIDEMO/BIG", VarPtr(b), 6000)
i = Ticks - i
Link.Check "  the Pi has 6000", Link.Num(4) = 6000
Print "    sent in "; i; " ticks (300 a second)"
Back 6000

If Not Link.Lost Then
  Print "20000 bytes:"
  Fill 10000, 0
  Link.Check "PUT the first 10000", Link.AskWith(ch, "PUT PIDEMO/BIG", VarPtr(b), 10000)
  Fill 10000, 10000
  Link.Check "APPEND the next 10000", Link.AskWith(ch, "APPEND PIDEMO/BIG", VarPtr(b), 10000)
  Link.Check "  the Pi has 20000", Link.Num(4) = 20000
  Back BIG
End If
If Not Link.Lost Then
  Link.Check "GET 300 bytes from 5000 (small: always in the frame)", Link.AskTo(ch, "GET PIDEMO/BIG 5000 300", VarPtr(b), 300)
  Link.Check "  300 bytes, the right ones, not through the ROM", Link.BodyLen = 300 And Wrong(300, 5000) = 0 And Not Link.Bulk
  Link.Check "DEL", Link.Ask(ch, "DEL PIDEMO/BIG")
End If
Link.Shut ch
Link.Summary

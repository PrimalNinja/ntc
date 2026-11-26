' PI05FLT - NTC PI DEMOS 5: the float coprocessor (the service behind NTC's Float class).
' OP: one operation on IEEE singles; ARR: a whole array in one request. The numbers are sent as
' their four bytes, little end first.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim q(47) As Byte, a(15) As Byte
Dim ch As Integer, i As Integer

Sub P4(ByVal at As Integer, ByVal b0 As Integer, ByVal b1 As Integer, ByVal b2 As Integer, ByVal b3 As Integer)
  q(at) = b0 : q(at + 1) = b1 : q(at + 2) = b2 : q(at + 3) = b3
End Sub
Function Is4(ByVal at As Integer, ByVal b0 As Integer, ByVal b1 As Integer, ByVal b2 As Integer, ByVal b3 As Integer) As Integer
  Is4 = (a(at) = b0 And a(at + 1) = b1 And a(at + 2) = b2 And a(at + 3) = b3)
End Function
Sub Show(ByVal n As Integer)
  Dim i As Integer
  Print "    bytes back:";
  For i = 0 To n - 1
    Print " "; Hex$(a(i));
  Next
  Print
End Sub

Mode 2
Link.Title "PI05 FLOAT - the coprocessor behind NTC's Float class"
If Not Link.Hello("PIDEMO") Then Print Link.Reply : Link.Summary : End
ch = Link.Open("float")
Link.Check "OPEN float", ch > 0
If ch = 0 Then Link.Summary : End
For i = 0 To 47
  q(i) = 0
Next
P4 0, 0, 0, &HC0, &H3F          ' A = 1.5
P4 4, 0, 0, &H10, &H40          ' B = 2.25
Link.Check "OP 1: 1.5 + 2.25", Link.AskBoth(ch, "OP 1", VarPtr(q), 12, VarPtr(a), 16)
Show Link.Kept
Link.Check "  3.75 (00 00 70 40), no overflow", Link.BodyLen = 5 And Is4(0, 0, 0, &H70, &H40) And a(4) = 0
Link.Check "OP 2: 1.5 - 2.25", Link.AskBoth(ch, "OP 2", VarPtr(q), 12, VarPtr(a), 16)
Link.Check "  -0.75 (00 00 40 BF)", Is4(0, 0, 0, &H40, &HBF)
Link.Check "OP 3: 1.5 * 2.25", Link.AskBoth(ch, "OP 3", VarPtr(q), 12, VarPtr(a), 16)
Link.Check "  3.375 (00 00 58 40)", Is4(0, 0, 0, &H58, &H40)
P4 0, 0, 0, &H10, &H40          ' A = 2.25
P4 4, 0, 0, &HC0, &H3F          ' B = 1.5
Link.Check "OP 4: 2.25 / 1.5", Link.AskBoth(ch, "OP 4", VarPtr(q), 12, VarPtr(a), 16)
Link.Check "  1.5 (00 00 C0 3F)", Is4(0, 0, 0, &HC0, &H3F)
P4 0, &HE8, 3, 0, 0             ' A = the Long 1000
Link.Check "OP 5: the Long 1000 to a single", Link.AskBoth(ch, "OP 5", VarPtr(q), 12, VarPtr(a), 16)
Link.Check "  1000.0 (00 00 7A 44)", Is4(0, 0, 0, &H7A, &H44)
P4 0, 0, 0, &H7A, &H44          ' A = 1000.0
Link.Check "OP 6: 1000.0 to a Long", Link.AskBoth(ch, "OP 6", VarPtr(q), 12, VarPtr(a), 16)
Link.Check "  1000 (E8 03 00 00)", Is4(0, &HE8, 3, 0, 0)
P4 0, 0, 0, &H80, &H3F          ' A = 1.0
P4 4, 0, 0, 0, 0                ' B = 0
Link.Check "OP 4: 1.0 / 0", Link.AskBoth(ch, "OP 4", VarPtr(q), 12, VarPtr(a), 16)
Show Link.Kept
Link.Check "  the overflow flag is set", a(4) <> 0

' ARR eop es bk n: element by element. Body: the scale (4), k (4), A (n elements), B (n elements)
For i = 0 To 47
  q(i) = 0
Next
P4 8, 0, 0, &H80, &H3F : P4 12, 0, 0, 0, &H40 : P4 16, 0, 0, &H40, &H40      ' A = 1.0, 2.0, 3.0
P4 20, 0, 0, 0, &H3F : P4 24, 0, 0, 0, &H3F : P4 28, 0, 0, 0, &H3F            ' B = 0.5, 0.5, 0.5
Link.Check "ARR 1 4 0 3: three sums in one request", Link.AskBoth(ch, "ARR 1 4 0 3", VarPtr(q), 32, VarPtr(a), 16)
Show Link.Kept
Link.Check "  1.5, 2.5, 3.5", Link.BodyLen = 13 And Is4(0, 0, 0, &HC0, &H3F) And Is4(4, 0, 0, &H20, &H40) And Is4(8, 0, 0, &H60, &H40)
Link.Shut ch
Link.Summary

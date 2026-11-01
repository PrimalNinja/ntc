' fixed 2026-11-01: CLng of a byte array parameter's element inside an expression read the wrong byte
' (3434 for 1234, 34CD for ABCD; CyborgOS's SlotFrame.GetW worked round it). Prints 1234 ABCD (tools/ntccheck/compare.js
' compiles it with every compiler change; regress.sh runs it)
Dim b(3) As Byte
b(0) = &H34 : b(1) = &H12 : b(2) = &HCD : b(3) = &HAB
Print Hex$(GetW(b, 0)); " "; Hex$(GetW(b, 2))
Function GetW(a() As Byte, ByVal i As Integer) As Long
  GetW = CLng(a(i)) + CLng(a(i + 1)) * 256&
End Function

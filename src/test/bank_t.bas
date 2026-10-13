' Memory banks: AllocBank, BankPage, CallBank, FreeBank (CPCExpansion, 128K and more)
Dim b As Integer, b2 As Integer, n As Integer, r As Integer, p As Long, a As Integer
n = Memory.Banks()
Print "banks "; n
b = Memory.AllocBank()
Print "bank "; b
If b = 0 Then
  Print "none"
  End
End If
Print Memory.Map(1, 9)
' bank code at &1000: ld de,(&C000) : add hl,de : add hl,de : ld bc,(&C002) : add hl,bc : ret
' so value + 2 * word(&C000) + word(&C002)
p = CLng(Memory.BankPage(b, 0)) * 65536 + &H5000
Memory.WriteByte p, &HED
Memory.WriteByte p + 1, &H5B
Memory.WriteByte p + 2, 0
Memory.WriteByte p + 3, &HC0
Memory.WriteByte p + 4, &H19
Memory.WriteByte p + 5, &H19
Memory.WriteByte p + 6, &HED
Memory.WriteByte p + 7, &H4B
Memory.WriteByte p + 8, 2
Memory.WriteByte p + 9, &HC0
Memory.WriteByte p + 10, 9
Memory.WriteByte p + 11, &HC9
p = CLng(Memory.BankPage(b, 3)) * 65536 + &H4000
Memory.WriteWord p, 1000
Memory.WriteWord p + 2, 7
r = Memory.CallBank(b, &H1000, 5)
Print "call "; r
r = Memory.CallBank(b, &H1000, 100)
Print "again "; r
a = Memory.BankStub()
p = CLng(Memory.BankPage(b, (a And &H7FFF) \ 16384 - 2 * (a < 0))) * 65536 + &H4000 + (a And &H3FFF)
Print "stub "; Hex$(Memory.ReadByte(p)); " "; Hex$(Memory.ReadByte(p + 1))
b2 = Memory.AllocBank()
Print "second "; b2
r = Memory.FreeBank(b)
Print "free "; r
r = Memory.FreeBank(b)
Print "free again "; r
r = Memory.CallBank(b, &H1000, 5)
Print "call freed "; r
r = Memory.CallBank(99, &H1000, 5)
Print "call 99 "; r
Print Memory.Map(1, 9)
If b2 <> 0 Then r = Memory.FreeBank(b2)
Print "done"

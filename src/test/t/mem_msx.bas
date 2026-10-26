Option Memory CPCExpansion 33
' Memory class checks (regress.sh): run on cpc with --ram=64 / 128 / 576 / 4160
Option Explicit
Option Reserve &H4000, &H4000
Dim n As Integer, i As Integer, r As Integer, pg As Integer, a As Integer
Dim p As Long, q As Long, big(9) As Long

n = Memory.Pages()
Print "pages"; n; " model"; Memory.Model(); " ram"; Memory.RamSize(); " free"; Memory.FreePages()
Print "bad"; Memory.PageType(0); Memory.PageType(n + 1); Memory.SelectPage(n + 1); Memory.FreePage(0)
Print "cur"; Memory.CurrentPage()

' a page by hand: select, poke, select another, peek both
pg = Memory.AllocPage(Memory.TypeUser)
Print "user page"; pg; " type "; Chr$(Memory.PageType(pg))
a = Memory.SelectPage(pg)
Poke a, 77 : Poke a + &H3FFF, 88
Print "cur"; Memory.CurrentPage(); " "; Peek(&H4000); Peek(&H7FFF)
If n > 1 Then
  r = Memory.SelectPage(2)
  Print "page 2 at #4000:"; Peek(&H4000) <> 77
  r = Memory.SelectPage(pg)
  Print "back:"; Peek(&H4000); Peek(&H7FFF)
End If
r = Memory.SelectPage(1)

' far pointers to the user page, across its end into the next page (Copy carries on)
p = CLng(pg) * 65536 + &H7FFE
Memory.WriteWord p, 4660
Print "word"; Memory.ReadWord(p); " byte"; Memory.ReadByte(p); " cur"; Memory.CurrentPage()

' heap
Print "kind '-':"; Memory.AllocPage(Memory.TypeFree)
p = Memory.Alloc(16383)
Print "too big"; p = 0
p = Memory.Alloc(100)
Print "alloc"; p <> 0; " largest"; Memory.Largest()
If p <> 0 Then
  For i = 0 To 99 : Memory.WriteByte p + i, i : Next
  q = Memory.Alloc(100)
  r = Memory.Copy(p, q, 100)
  a = 0
  For i = 0 To 99 : a = a + Memory.ReadByte(q + i) : Next
  Print "copy"; r; " sum"; a
  Print "free"; Memory.Free(p); " again"; Memory.Free(p); " q"; Memory.Free(q)
  Print "map "; Memory.Map(1, 33)
  ' fill: 16000-byte blocks until no room
  i = 0
  Do
    big(i) = Memory.Alloc(16000)
    If big(i) = 0 Then Exit Do
    i = i + 1
  Loop Until i = 10
  Print "big blocks"; i; " free pages"; Memory.FreePages(); " largest"; Memory.Largest()
  Do While i > 0
    i = i - 1
    r = Memory.Free(big(i))
  Loop
  Print "map "; Memory.Map(1, 33)
  ' a copy across a page end: page 0 (plain) to the end of one page and on into the next
  If n >= 3 Then
    For i = 0 To 99 : Poke &H3000 + i, 200 - i : Next
    pg = Memory.AllocPage(Memory.TypeUser)
    r = Memory.AllocPage(Memory.TypeUser)
    q = CLng(pg) * 65536 + &H7FCE
    r = Memory.Copy(&H3000, q, 100)
    Print "wrap copy"; r; Memory.ReadByte(q); Memory.ReadByte(CLng(pg + 1) * 65536 + &H4000); Memory.ReadByte(CLng(pg + 1) * 65536 + &H4031)
    r = Memory.Copy(q, CLng(n + 1) * 65536 + &H4000, 2)
    Print "copy to bad page"; r; " cur"; Memory.CurrentPage()
  End If
End If
' lists: a free page can't be freed again; heap pages come from above the standard 512K
pg = Memory.AllocPage(Memory.TypeIrq)
Print "irq page"; pg; " free"; Memory.FreePage(pg); " again"; Memory.FreePage(pg); " kind X"; Memory.AllocPage(88)
p = Memory.Alloc(10)
If p <> 0 Then Print "heap page"; Memory.PageOf(p); " "; Chr$(Memory.PageType(Memory.PageOf(p))) : r = Memory.Free(p)
Print "tables"; Memory.TableEnd() - VarPtr(n) > 0; " free"; Memory.FreePages()
Print "done"

' Memory class, Option Memory Small checks (regress.sh): cpc, cpcfw, cpm, test
Option Memory Small
Dim p As Long, q As Long, r As Integer, i As Integer, a As Integer, big(9) As Long
Print "pages"; Memory.Pages(); " model"; Memory.Model(); " window"; Memory.WindowStart; Memory.WindowSize
Print "heap above program "; Memory.HeapStart() = Memory.TableEnd(); " has room "; Memory.HeapEnd() <> Memory.HeapStart()
Print "page calls"; Memory.AllocPage(Memory.TypeUser); Memory.SelectPage(1); Memory.FreePage(1); Memory.PageType(1); " map["; Memory.Map(1, 5); "]"
p = Memory.Alloc(100)
Print "alloc page"; Memory.PageOf(p); " in heap "; Memory.Address(p) > Memory.HeapStart()
For i = 0 To 99 : Memory.WriteByte p + i, i : Next
q = Memory.Alloc(100)
r = Memory.Copy(p, q, 100)
a = 0
For i = 0 To 99 : a = a + Memory.ReadByte(q + i) : Next
Print "copy"; r; " sum"; a; " peek"; Peek(Memory.Address(q) + 99)
Print "bad page ptr"; Memory.ReadByte(CLng(1) * 65536 + &H4000); " too big"; Memory.Alloc(16383) = 0
Print "free"; Memory.Free(p); " again"; Memory.Free(p); " q"; Memory.Free(q); " outside"; Memory.Free(&H10)
i = 0
Do
  big(i) = Memory.Alloc(8000)
  If big(i) = 0 Then Exit Do
  i = i + 1
Loop Until i = 10
Print "8000 blocks>1 "; i > 1; " largest after"; Memory.Largest() < 8000
Do While i > 0
  i = i - 1
  r = Memory.Free(big(i))
Loop
Print "largest back "; Memory.Largest() > 15000
Print "done"

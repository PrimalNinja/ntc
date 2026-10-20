' List class checks (regress.sh): cpc (pages), cpcmin, cpm / test (Small)
Option Explicit
#If NTC_CPC Then
Option Reserve &H4000, &H4000
#End If
#If NTC_CPCMIN Then
Option Reserve &H4000, &H4000
#End If
Dim h As Long, n As Long, m As Long, i As Integer, s As Long, k As Integer, prev As Integer, ok As Integer
Dim free0 As Integer

free0 = Memory.FreePages()
h = List.Create(4)
Print "created"; h <> 0; " count"; List.Count(h); " first"; List.First(h) = 0
For i = 1 To 3000
  n = List.Append(h)
  If n = 0 Then Exit For
  List.SetWord n, 0, (i * 37) Mod 1000
  List.SetWord n, 2, i
Next
Print "appended"; List.Count(h); " pages used"; free0 - Memory.FreePages()
s = 0 : n = List.First(h)
Do While n <> 0
  s = s + List.GetWord(n, 2)
  n = List.NextOf(n)
Loop
Print "sum"; s
n = List.Search(h, 2, 1500)
Print "search"; List.GetWord(n, 0); " none"; List.Search(h, 2, -5) = 0
' delete every node with an even number, then prepend / insert
n = List.First(h)
Do While n <> 0
  m = List.NextOf(n)
  If (List.GetWord(n, 2) And 1) = 0 Then k = List.Delete(h, n)
  n = m
Loop
Print "after delete"; List.Count(h); " last"; List.GetWord(List.Last(h), 2)
n = List.Prepend(h) : List.SetWord n, 0, -7
n = List.InsertAfter(h, List.First(h)) : List.SetWord n, 0, 2000
Print "first"; List.GetWord(List.First(h), 0); " second"; List.GetWord(List.NextOf(List.First(h)), 0); " count"; List.Count(h)
k = List.Sort(h, 0)
ok = -1 : prev = -32768 : i = 0
n = List.First(h)
Do While n <> 0
  If List.GetWord(n, 0) < prev Then ok = 0
  prev = List.GetWord(n, 0)
  i = i + 1
  n = List.NextOf(n)
Loop
Print "sorted"; ok; " walked"; i; " min"; List.GetWord(List.First(h), 0); " max"; List.GetWord(List.Last(h), 0)
n = List.Last(h) : i = 0
Do While n <> 0
  i = i + 1
  n = List.PrevOf(n)
Loop
Print "backwards"; i; " bytes"; List.GetByte(List.First(h), 0); " data"; Memory.ReadWord(List.Data(List.Last(h)))
Print "bad"; List.Count(0); " destroy"; List.Destroy(h); " pages back"; Memory.FreePages() = free0
Print "done"

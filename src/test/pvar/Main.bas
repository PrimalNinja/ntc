' Paged variables and local memory in an overlay class, with a List in D pages (regress.sh):
' cpcmin / cpcfw
Option RomEnable 7
Option Reserve &H4000, &H4000
Dim h As Long, n As Long, i As Integer, r As Integer
' a list of 200 records (4 bytes: id, value) in the heap's D pages
h = List.Create(4)
For i = 1 To 200
  n = List.Append(h)
  List.SetWord n, 0, i
  List.SetWord n, 2, i * 3
Next
Print "list"; List.Count(h)
Print "fill"; Shop.Fill(50); " total"; Shop.Total(); " title "; Shop.Title()
Print "visits"; Shop.Visits; " local"; Shop.LocalSize() > 1000
Print "copy"; Shop.FromList(List.Search(h, 0, 77))
Print "loaded"; Shop.Loaded(); " unload"; Shop.Unload()
' loaded again: page variables start fresh, the class's normal variables kept theirs
Print "again total"; Shop.Total(); " title "; Shop.Title(); " visits"; Shop.Visits
Print "outside"; Shop.LocalAlloc(10); Shop.LocalFree(&H5000)
r = List.Destroy(h)
Print "done"

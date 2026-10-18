Option Class Overlay "SHOP"
Public Visits As Integer             ' in the program: kept when the page goes
Private Paged stock(99) As Integer   ' in the page: fresh each time it is loaded
Private Paged count As Integer
Private Paged name As String

Public Function Fill(ByVal n As Integer) As Integer
  Dim i As Integer
  Visits = Visits + 1
  For i = 0 To n - 1
    stock(i) = i + 1
  Next
  count = n
  name = "Corner shop"
  Fill = count
End Function

Public Function Total() As Integer
  Dim i As Integer, s As Integer
  Visits = Visits + 1
  For i = 0 To count - 1
    s = s + stock(i)
  Next
  Total = s
End Function

Public Function Title() As String
  Title = "[" + name + "]"
End Function

' a list node's data copied into the page's own local memory, read back from there
Public Function FromList(ByVal node As Long) As Integer
  Dim buf As Integer, r As Integer
  buf = LocalAlloc(4)
  If buf = 0 Then FromList = -1 : Exit Function
  r = Memory.Copy(List.Data(node), CLng(Page()) * 65536 + buf, 4)
  FromList = (Peek(buf) + Peek(buf + 1) * 256) + (Peek(buf + 2) + Peek(buf + 3) * 256)
  r = LocalFree(buf)
End Function

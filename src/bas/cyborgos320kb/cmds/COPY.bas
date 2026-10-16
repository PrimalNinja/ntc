' COPY: files from one volume to another, in CyborgOS (build for cpm, with CybDir.cls).
'   COPY [v1:]name v2[:newname]       v2 alone: "B" or "B:"; a name with no volume: this slot's drive
'   COPY [v1:]pattern v2              * any characters, ? any one (*.CYB, T*, ????.COM, *.*): each
'                                     file that fits, same names
' Any file the drive has (its own directory: UniDOS's folder, a RAM disc's). A file is copied as
' CP/M sees it, 8K at a time: from UniDOS to its exact length (from its listing), else to its
' last record. An AMSDOS header (a CPC .BIN's) is not copied (CP/M reads past it)
Option Explicit
Dim buf(8191) As Byte
Dim sns(63) As String Max 12, szs(63) As Long, k As Integer
Dim a1 As String Max 40, a2 As String Max 40, v1 As String Max 2, v2 As String Max 2
Dim f1 As String Max 40, f2 As String Max 12, sn As String Max 12
Dim p As Integer, o As Integer, r As Integer, i As Integer, nd As Integer
Dim size As Long

a1 = UCase$(Trim$(System.CommandLine()))
p = InStr(a1, " ")
If p = 0 Then Print "COPY [v1:]name v2[:newname]   COPY [v1:]pattern v2" : End
a2 = Trim$(Mid$(a1, p + 1))
a1 = Left$(a1, p - 1)
If Mid$(a1, 2, 1) = ":" Then
  v1 = Left$(a1, 2) : f1 = Mid$(a1, 3)
Else
  v1 = Here() : f1 = a1
End If
If Len(a2) = 1 Then
  v2 = a2 + ":" : f2 = ""
ElseIf Mid$(a2, 2, 1) = ":" Then
  v2 = Left$(a2, 2) : f2 = Mid$(a2, 3)
Else
  v2 = Here() : f2 = a2
End If
If CybDir.LoadAll(v1) = False Then Print v1; ": its files can't be listed (UniDOS, or a RAM disc)" : End

If InStr(f1, "*") > 0 Or InStr(f1, "?") > 0 Then
  ' a pattern: the files that fit, then each copied to v2 with its name
  If f2 <> "" Then Print "COPY "; f1; ": a pattern copies to a drive (v2 alone), same names" : End
  If v1 = v2 Then Print "a file can't be copied over itself" : End
  k = 0
  For o = 0 To CybDir.Count() - 1
    If CybDir.Match(o, f1) And k < 64 Then
      sns(k) = CybDir.DiscName(o) : szs(k) = CybDir.Length(o)
      k = k + 1
    End If
  Next
  If k = 0 Then Print v1; f1; ": no file fits" : End
  nd = 0
  For i = 0 To k - 1
    r = CopyOne(sns(i), sns(i), szs(i))
    If r >= 0 Then nd = nd + 1
    If r = -2 Then Exit For                    ' (the disc full)
  Next
  Print nd; " of "; k; " files copied"
  End
End If

o = CybDir.Find(f1)
If o < 0 Then Print v1; f1; ": not found" : End
sn = CybDir.DiscName(o)
size = CybDir.Length(o)
If f2 = "" Then f2 = sn
If v1 = v2 And f2 = sn Then Print "a file can't be copied over itself" : End
r = CopyOne(sn, f2, size)
End

' this slot's drive, "A:"
Function Here() As String
  Here = FileSystem.CurrentVolume() + ":"
End Function

' v1's file s to v2 as t (size bytes at most, 8K a go), a line saying so: its bytes, -1 it isn't
' there or can't be made, -2 the disc is full (or a write failed)
Function CopyOne(ByVal s As String, ByVal t As String, ByVal size As Long) As Long
  Dim hi As Integer, ho As Integer, n As Integer, w As Integer, rr As Integer, total As Long
  CopyOne = -1
  hi = FileSystem.Open(v1 + s, FileSystem.ForReadRaw)
  If hi < 0 Then Print v1; s; ": not found" : Exit Function
  ho = FileSystem.Open(v2 + t, FileSystem.ForWrite)
  If ho < 0 Then rr = FileSystem.Close(hi) : Print v2; t; ": can't be made ("; ho; ")" : Exit Function
  total = 0
  Do While total < size
    If size - total > 8192 Then n = 8192 Else n = CInt(size - total)
    rr = FileSystem.Read(hi, VarPtr(buf), n)
    If rr <= 0 Then Exit Do
    w = FileSystem.Write(ho, VarPtr(buf), rr)
    If w <> rr Then
      Print v2; t; ": the disc is full, or a write failed"
      rr = FileSystem.Close(hi) : rr = FileSystem.Close(ho)
      CopyOne = -2
      Exit Function
    End If
    total = total + rr
    If rr < n Then Exit Do
  Loop
  rr = FileSystem.Close(hi)
  rr = FileSystem.Close(ho)
  Print v1; s; " to "; v2; t; ": "; total; " bytes"
  CopyOne = total
End Function

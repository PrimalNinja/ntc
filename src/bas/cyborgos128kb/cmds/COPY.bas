' COPY: a file from one volume to another, in CyborgOS (build for cpm, with CybDir.cls).
'   COPY [v1:]name v2[:newname]       v2 alone: "B" or "B:"; a name with no volume: this slot's drive
' The file must be in v1's FILES.DIR (only files added there are touched) and v2 must have a
' FILES.DIR (PREP makes one). The copy gets the same entry (its exact length, long name, flags)
' under its new name. The file is copied record by record as CP/M sees it: an AMSDOS header (a
' CPC .BIN's) is not copied, and the copy's last record is padded to 128 bytes.
Option Explicit
Dim buf(8191) As Byte
Dim a1 As String Max 40, a2 As String Max 40, v1 As String Max 2, v2 As String Max 2
Dim f1 As String Max 40, f2 As String Max 12, sn As String Max 12
Dim p As Integer, o As Integer, hi As Integer, ho As Integer, r As Integer, w As Integer, n As Integer
Dim total As Long, size As Long

a1 = UCase$(Trim$(System.CommandLine()))
p = InStr(a1, " ")
If p = 0 Then Print "COPY [v1:]name v2[:newname]" : End
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
If CybDir.Load(v1) = False Then Print v1; " has no FILES.DIR" : End
o = CybDir.Find(f1)
If o < 0 Then Print v1; f1; ": not in FILES.DIR" : End
sn = CybDir.DiscName(o)
size = CybDir.Length(o)
CybDir.Take o
If f2 = "" Then f2 = sn
If v1 = v2 And f2 = sn Then Print "a file can't be copied over itself" : End
If CybDir.Load(v2) = False Then Print v2; " has no FILES.DIR (PREP "; Left$(v2, 1); " makes one)" : End
hi = FileSystem.Open(v1 + sn, FileSystem.ForReadRaw)
If hi < 0 Then Print v1; sn; ": not on the disc" : End
ho = FileSystem.Open(v2 + f2, FileSystem.ForWrite)
If ho < 0 Then r = FileSystem.Close(hi) : Print v2; f2; ": can't be made ("; ho; ")" : End
total = 0
Do While total < size
  If size - total > 8192 Then n = 8192 Else n = CInt(size - total)
  r = FileSystem.Read(hi, VarPtr(buf), n)
  If r <= 0 Then Exit Do
  w = FileSystem.Write(ho, VarPtr(buf), r)
  If w <> r Then Print v2; f2; ": the disc is full, or a write failed" : Exit Do
  total = total + r
  If r < n Then Exit Do
Loop
r = FileSystem.Close(hi)
r = FileSystem.Close(ho)
If total < size Then Print v1; sn; ": shorter than FILES.DIR says ("; total; " of "; size; " bytes)"
If CybDir.PutAs(f2) = False Then Print v2; "FILES.DIR is full" : End
r = CybDir.Save(v2)
If r <> 0 Then Print v2; "FILES.DIR not written ("; r; ")" : End
Print v1; sn; " to "; v2; f2; ": "; total; " bytes"
End

' this slot's drive, "A:"
Function Here() As String
  Here = FileSystem.CurrentVolume() + ":"
End Function

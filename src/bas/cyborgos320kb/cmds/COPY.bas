' COPY: files from one volume to another, in CyborgOS (build for cpm, with CybDir.cls).
'   COPY [v1:]name v2[:newname]       v2 alone: "B" or "B:"; a name with no volume: this slot's drive
'   COPY [v1:]pattern v2              * any characters, ? any one (*.CYB, T*, ????.COM, *.*): each
'                                     file that fits (its disc name or long name), same names
' A file must be in v1's FILES.DIR (only files added there are touched) and v2 must have a
' FILES.DIR (PREP makes one). A copy gets the same entry (its exact length, long name, flags)
' under its new name. A file is copied record by record as CP/M sees it: an AMSDOS header (a CPC
' .BIN's) is not copied, and the copy's last record is padded to 128 bytes. With a pattern, v2's
' FILES.DIR is written once, after the last file (or when the disc or FILES.DIR is full)
Option Explicit
Dim buf(8191) As Byte
Dim ents(4095) As Byte                       ' (a pattern: the files' entries, 64 bytes each)
Dim sns(63) As String Max 12, k As Integer
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
If CybDir.Load(v1) = False Then Print v1; " has no FILES.DIR" : End

If InStr(f1, "*") > 0 Or InStr(f1, "?") > 0 Then
  ' a pattern: the files that fit (their entries kept), then each copied to v2 with its name
  If f2 <> "" Then Print "COPY "; f1; ": a pattern copies to a drive (v2 alone), same names" : End
  If v1 = v2 Then Print "a file can't be copied over itself" : End
  k = 0
  For o = 0 To CybDir.Count() * 64 - 64 Step 64
    If CybDir.Match(o, f1) And k < 64 Then
      CybDir.Keep o, VarPtr(ents) + k * 64
      sns(k) = CybDir.DiscName(o)
      k = k + 1
    End If
  Next
  If k = 0 Then Print v1; f1; ": no file in FILES.DIR fits" : End
  If CybDir.Load(v2) = False Then Print v2; " has no FILES.DIR (PREP "; Left$(v2, 1); " makes one)" : End
  nd = 0
  For i = 0 To k - 1
    size = CLng(ents(i * 64 + 14)) + CLng(ents(i * 64 + 15)) * 256
    r = CopyOne(sns(i), sns(i), size)
    If r >= 0 Then
      CybDir.Back VarPtr(ents) + i * 64
      If CybDir.PutAs(sns(i)) = False Then Print v2; "FILES.DIR is full" : Exit For
      nd = nd + 1
    End If
    If r = -2 Then Exit For                    ' (the disc full)
  Next
  If nd > 0 Then
    r = CybDir.Save(v2)
    If r <> 0 Then Print v2; "FILES.DIR not written ("; r; ")" : End
  End If
  Print nd; " of "; k; " files copied"
  End
End If

o = CybDir.Find(f1)
If o < 0 Then Print v1; f1; ": not in FILES.DIR" : End
sn = CybDir.DiscName(o)
size = CybDir.Length(o)
CybDir.Take o
If f2 = "" Then f2 = sn
If v1 = v2 And f2 = sn Then Print "a file can't be copied over itself" : End
If CybDir.Load(v2) = False Then Print v2; " has no FILES.DIR (PREP "; Left$(v2, 1); " makes one)" : End
If CopyOne(sn, f2, size) < 0 Then End
If CybDir.PutAs(f2) = False Then Print v2; "FILES.DIR is full" : End
r = CybDir.Save(v2)
If r <> 0 Then Print v2; "FILES.DIR not written ("; r; ")" : End
End

' this slot's drive, "A:"
Function Here() As String
  Here = FileSystem.CurrentVolume() + ":"
End Function

' v1's file s to v2 as t (size bytes, 8K a go), a line saying so: its bytes, -1 it isn't there or
' can't be made, -2 the disc is full (or a write failed)
Function CopyOne(ByVal s As String, ByVal t As String, ByVal size As Long) As Long
  Dim hi As Integer, ho As Integer, n As Integer, w As Integer, rr As Integer, total As Long
  CopyOne = -1
  hi = FileSystem.Open(v1 + s, FileSystem.ForReadRaw)
  If hi < 0 Then Print v1; s; ": not on the disc" : Exit Function
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
  If total < size Then Print v1; s; ": shorter than FILES.DIR says ("; total; " of "; size; " bytes)"
  Print v1; s; " to "; v2; t; ": "; total; " bytes"
  CopyOne = total
End Function

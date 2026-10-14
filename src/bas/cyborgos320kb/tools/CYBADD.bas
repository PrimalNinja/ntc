' CYBADD: entries for CyborgOS's FILES.DIR - a CP/M .COM with no AMSDOS header runs in CyborgOS
' only when FILES.DIR has an entry for it (its length - AMSDOS can't tell a headerless file's -
' and the say-so that it runs). A normal CPC program (cpcfw): RUN"CYBADD from BASIC. Asks for
' the drive, then each file and its long name (one word: RUN takes it as the name), and writes
' FILES.DIR again each time (an entry for a file already there is replaced). Its length is read
' from the disc, to the end of the file's last 128 byte record (all AMSDOS knows).
' Ent.cls (the entries, in Z80) is CyborgOS's; build: CYBADD.bas, ../Ent.cls - cpcfw.
Option PressAnyKeyOnEnd "Press a key"
Option Explicit
Option RomEnable All              ' every background ROM (the disc ROM, an IDE / SD interface's ...), for the files
Option NoRomDisc                  ' no ROMDISC: its FileSystem code left out
Dim buf(2047) As Byte             ' a file read through (its length counted)
Dim dir(4095) As Byte             ' FILES.DIR: 64 entries at most
Dim f As String, ln As String, dr As String, ln2 As String Max 60
Dim h As Integer, n As Integer, m As Integer, o As Integer, i As Integer, sz As Long

Print "CYBADD - entries for CyborgOS's FILES.DIR"
Input "Drive (A, B ...; Enter: A)"; dr
dr = UCase$(Left$(Trim$(dr), 1))
If dr = "" Then dr = "A"
dr = dr + ":"
ShowDir
Do
  Print
  Input "File (NAME.COM; Enter: done)"; f
  f = UCase$(Trim$(f))
  If f = "" Then Exit Do
  If InStr(f, ".") = 0 Then f = f + ".COM"
  Input "Long name (one word; Enter: none)"; ln
  ln = UCase$(Trim$(ln))
  If InStr(ln, " ") > 0 Then ln = Left$(ln, InStr(ln, " ") - 1)
  AddOne
Loop
End

' f's entry (long name ln) into FILES.DIR on drive dr
Sub AddOne()
  Dim r As Integer, e As Integer
  sz = 0
  h = FileSystem.Open(dr + f, FileSystem.ForReadRaw)
  If h < 0 Then Print f; ": not found" : Exit Sub
  Do
    r = FileSystem.Read(h, VarPtr(buf), 2048)
    sz = sz + r
  Loop Until r < 2048 Or sz > &HF400&
  e = FileSystem.Close(h)
  If sz = 0 Or sz > &HF400& Then Print f; ": empty, or too big for #0100-#F4FF" : Exit Sub
  LoadDir
  Ent.SetName VarPtr(f), Len(f)
  o = Ent.Where(VarPtr(dir), m)
  If o = m Then
    If m >= 4096 Then Print "FILES.DIR is full (64 entries)" : Exit Sub
    m = m + 64
  End If
  If sz > 32767 Then r = CInt(sz - 65536) Else r = CInt(sz)
  Ent.Make VarPtr(dir) + o, VarPtr(ln), Len(ln), r
  r = FileSystem.Save(dr + "FILES.DIR", VarPtr(dir), m)
  If r <> 0 Then Print "FILES.DIR not saved ("; r; ")" : Exit Sub
  Print f; ": "; sz; " bytes, in FILES.DIR"
  ShowDir
End Sub

' FILES.DIR into dir(): m = its bytes (whole entries; the last record's padding dropped)
Sub LoadDir()
  Dim e As Integer
  m = 0
  h = FileSystem.Open(dr + "FILES.DIR", FileSystem.ForReadRaw)
  If h >= 0 Then
    m = FileSystem.Read(h, VarPtr(dir), 4096)
    e = FileSystem.Close(h)
  End If
  m = m And &HFFC0
  Do While m > 0
    If dir(m - 64) = 1 Or dir(m - 64) = 2 Then Exit Do
    m = m - 64
  Loop
End Sub

' FILES.DIR listed, as CyborgOS's DIR does
Sub ShowDir()
  Dim r As Integer, k As Integer
  LoadDir
  k = 0
  For o = 0 To m - 64 Step 64
    ln2 = Space$(60)
    r = Ent.Show(VarPtr(dir) + o, VarPtr(ln2))
    If r > 0 Then Print Left$(ln2, r) : k = k + 1
  Next
  Print dr; "FILES.DIR: "; k; " entries"
End Sub

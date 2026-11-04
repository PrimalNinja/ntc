' PISHELL - the Pi's store as a shell on the CPC: walk its folders, see the files, view one,
' delete, copy to the disc and up from it. A plain CPC program over the CPC-CPLink's ports
' (&FD80 / &FD81) - no UniDOS needed. NTC BASIC, cpcfw.
'   Up / Down   move          Return    enter a folder, or view a text file (any key back)
'   Left        the folder above          D   delete the file (Y to confirm)
'   C           copy the file to the CPC's disc (its name)   U  upload a disc file (the name asked)
'   R           refresh       Q   quit
' The store's folders are the categories as Streamer sees them: GRAPHICS/V9990/..., MUSIC/MP3/...,
' GAMES/... - whatever an installer put there.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Const MAXE = 60
Dim en(MAXE) As String Max 12        ' the entries: the name (11 characters, 8 + 3)
Dim es(MAXE) As Integer              ' sizes (low word)
Dim ed(MAXE) As Byte                 ' 1: a folder
Dim nent As Integer, cur As Integer, top As Integer
Dim folder As String Max 60          ' the folder shown, "" the root, else "A/B/"
Dim chan As Integer, nid As Integer, sum As Integer
Dim buf(31) As Byte
Dim fbuf(8191) As Byte               ' a file's bytes (8K: a view, a copy)
Dim hType As Integer, hChan As Integer, hId As Integer, hLen As Integer, hLen0 As Integer
Dim k As Integer, i As Integer, r As Integer
Dim name As String Max 40

' ---- the link: a byte out when there is room, a byte in when there is one
Sub ByteOut(ByVal b As Integer)
#asm
            ld bc, #FD81
bo_w:       in a, (c)
            bit 1, a
            jr z, bo_w
            dec c
            ld a, ({b})
            out (c), a
#endasm
End Sub
Function ByteIn() As Integer
#asm
            ld bc, #FD81
bi_w:       in a, (c)
            bit 0, a
            jr z, bi_w
            dec c
            in a, (c)
            ld l, a
            ld h, 0
            ld ({result}), hl
#endasm
End Function
' a frame: chan, type, id, then the payload a byte at a time through FrameByte, then FrameEnd
Sub FrameStart(ByVal c As Integer, ByVal t As Integer, ByVal id As Integer, ByVal n As Integer)
  ByteOut &HA5
  sum = 0
  FrameByte c : FrameByte t : FrameByte id : FrameByte n And 255 : FrameByte n \ 256
End Sub
Sub FrameByte(ByVal b As Integer)
  ByteOut b
  sum = (sum + b) And 255
End Sub
Sub FrameEnd()
  ByteOut sum
End Sub
Sub FrameText(ByVal s As String Max 80)
  Dim i As Integer
  For i = 1 To Len(s)
    FrameByte Asc(Mid$(s, i, 1))
  Next
End Sub
' a frame's header read (hunting for A5): its type in A, its length in n, the payload left to read
hType As Integer, hChan As Integer, hId As Integer, hLen As Integer, hLen0 As Integer
Sub ReadHeader()
  Do While ByteIn() <> &HA5
  Loop
  hChan = ByteIn() : hMore = ByteIn() : hType = hMore And &H7F : hId = ByteIn()
  hLen = ByteIn() : hLen = hLen + ByteIn() * 256
  hLen0 = hLen
End Sub
' Done: a frame fully read - its check taken, its bytes given back as credit (the Pi sends on a
' channel only what it was told there is room for; without this its answers queue behind events)
Sub Done()
  Dim k As Integer
  k = ByteIn()                                      ' the check
  If hChan <> 0 Then
    FrameStart hChan, 7, 0, 2 : FrameByte hLen0 And 255 : FrameByte hLen0 \ 256 : FrameEnd
  End If
End Sub
Sub SkipFrame()
  Dim k As Integer
  Do While hLen > 0
    hLen = hLen - 1 : k = ByteIn()
  Loop
  Done
End Sub
' a request on chan 0 or the channel, its answer's text into buf (up to 31 bytes); True when "OK"
Function Ask(ByVal c As Integer, ByVal s As String Max 80) As Integer
  Dim i As Integer, k As Integer
  nid = nid + 1 : If nid > 250 Then nid = 1
  FrameStart c, 2, nid, Len(s) : FrameText s : FrameEnd
  Do
    ReadHeader
    If hType = 3 And hId = nid Then Exit Do
    SkipFrame
  Loop
  i = 0
  Do While hLen > 0
    k = ByteIn() : hLen = hLen - 1
    If i < 31 Then buf(i) = k : i = i + 1
  Loop
  buf(i) = 0
  Done
  Ask = (buf(0) = Asc("O"))
End Function
Function BufNum(ByVal at As Integer) As Integer
  Dim v As Integer
  v = 0
  Do While buf(at) >= 48 And buf(at) <= 57
    v = v * 10 + buf(at) - 48 : at = at + 1
  Loop
  BufNum = v
End Function

' ---- the store
Sub Connect()
  FrameStart 0, 1, 0, 37 : FrameText "COS1 machine=cpc name=PISHELL max=256" : FrameEnd
  ReadHeader : SkipFrame
  nid = 0
  If Ask(0, "OPEN store") Then chan = BufNum(3) Else chan = 0
End Sub

' Listing: the folder's entries - LIST folder fmt=cpc: 16-byte records (11 characters, 4 the size, a flag)
Sub Listing()
  Dim n As Integer, i As Integer, j As Integer, s As String Max 12, c As Integer
  nent = 0
  nid = nid + 1 : If nid > 250 Then nid = 1
  FrameStart chan, 2, nid, 6 + Len(folder) + 8
  FrameText "LIST " + folder + "/ fmt=cpc"
  FrameEnd
  Do
    ReadHeader
    If hType = 3 And hId = nid Then Exit Do
    SkipFrame
  Loop
  Do While hLen > 0                   ' the text ("OK n") to its 0
    c = ByteIn() : hLen = hLen - 1
    If c = 0 Then Exit Do
  Loop
  Do
    Do While hLen = 0
      Done
      If (hMore And 128) = 0 Then Exit Do
      ReadHeader
      Do While hLen > 0
        c = ByteIn() : hLen = hLen - 1
        If c = 0 Then Exit Do
      Loop
    Loop
    If hLen < 16 Then Exit Do
    s = ""
    For j = 1 To 11
      s = s + Chr$(ByteIn())
    Next
    es(nent) = ByteIn() : es(nent) = es(nent) + ByteIn() * 256
    c = ByteIn() : c = ByteIn()
    ed(nent) = 0
    If ByteIn() And 16 Then ed(nent) = 1
    hLen = hLen - 16
    If nent < MAXE Then en(nent) = s : nent = nent + 1
  Loop
  cur = 0 : top = 0
End Sub
Dim hMore As Integer

' the frame headers: the MORE bit kept for a listing in parts
Sub ReadHeaderM()
  ReadHeader
End Sub

Sub Show()
  Dim i As Integer, s As String Max 80
  StdIO.Cls
  Print "PISHELL  /" + folder + "   (" + Str$(nent) + " entries)"
  Print String$(78, "-")
  For i = top To top + 19
    If i < nent Then
      If i = cur Then s = ">" Else s = " "
      If ed(i) Then
        s = s + Left$(en(i), 8) + "     <folder>"
      Else
        s = s + Left$(en(i), 8) + "." + Mid$(en(i), 9, 3) + Right$(Space$(8) + Str$(es(i)), 8)
      End If
      Print s
    Else
      Print
    End If
  Next
  StdIO.Locate 1, 25
  Print "Up/Down  Return open/view  Left up  D delete  C copy to disc  U upload  R  Q quit";
End Sub

Function Tag(ByVal i As Integer) As String Max 60
  Dim s As String Max 12
  s = RTrim$(Left$(en(i), 8))
  If RTrim$(Mid$(en(i), 9, 3)) <> "" Then s = s + "." + RTrim$(Mid$(en(i), 9, 3))
  Tag = folder + s
End Function

' View: a text file's first 8K on the screen, a page at a time (any key, Q stops)
Sub View(ByVal t As String Max 60)
  Dim n As Integer, p As Integer, c As Integer, row As Integer
  n = GetFile(t)
  If n < 0 Then Exit Sub
  StdIO.Cls : row = 0
  For p = 0 To n - 1
    c = fbuf(p)
    If c = 10 Then
      Print
      row = row + 1
      If row >= 23 Then
        Print "-- more --";
        If StdIO.GetKey() = Asc("q") Then Exit For
        StdIO.Cls : row = 0
      End If
    ElseIf c >= 32 And c < 127 Then
      Print Chr$(c);
    End If
  Next
  Print : Print "-- end: any key --";
  c = StdIO.GetKey()
End Sub

' GetFile: GET tag - the bytes into fbuf (8K at most): the count, or -1
Function GetFile(ByVal t As String Max 60) As Integer
  Dim n As Integer, c As Integer, first As Integer
  n = 0 : first = 1
  nid = nid + 1 : If nid > 250 Then nid = 1
  FrameStart chan, 2, nid, 4 + Len(t) : FrameText "GET " + t : FrameEnd
  Do
    ReadHeader
    If hType = 3 And hId = nid Then Exit Do
    SkipFrame
  Loop
  Do
    Do While hLen > 0               ' the part's text to its 0
      c = ByteIn() : hLen = hLen - 1
      If c = 0 Then Exit Do
      If first And c = Asc("E") Then
        SkipFrame : GetFile = -1 : Exit Function
      End If
      first = 0
    Loop
    Do While hLen > 0
      c = ByteIn() : hLen = hLen - 1
      If n < 8192 Then fbuf(n) = c : n = n + 1
    Loop
    Done
    If (hMore And 128) = 0 Then Exit Do
    ReadHeader
  Loop
  GetFile = n
End Function

Sub AskLine(ByVal prompt As String Max 30)
  Dim k As Integer
  name = ""
  StdIO.Locate 1, 24
  Do
    Print Left$(prompt + name + "_" + Space$(60), 78); : StdIO.Locate 1, 24
    k = StdIO.GetKey()
    If k = 13 Then Exit Do
    If k = 27 Or k = 252 Then name = "" : Exit Do
    If k = 127 Then
      If Len(name) > 0 Then name = Left$(name, Len(name) - 1)
    ElseIf k >= 32 And k < 127 And Len(name) < 40 Then
      name = name + Chr$(k)
    End If
  Loop
End Sub

' ---- start
StdIO.Mode 2
Print "PISHELL - connecting to the Pi ..."
Connect
If chan = 0 Then Print "No Pi on the link (the store did not open)." : End
folder = ""
Listing
Show
Do
  k = StdIO.GetKey()
  If k = Asc("q") Or k = Asc("Q") Then Exit Do
  If k = 240 Then
    If cur > 0 Then cur = cur - 1 : If cur < top Then top = cur
    Show
  ElseIf k = 241 Then
    If cur < nent - 1 Then cur = cur + 1 : If cur >= top + 20 Then top = cur - 19
    Show
  ElseIf k = 242 Then
    If folder <> "" Then
      folder = Left$(folder, Len(folder) - 1)
      Do While Len(folder) > 0
        If Right$(folder, 1) = "/" Then Exit Do
        folder = Left$(folder, Len(folder) - 1)
      Loop
      Listing : Show
    End If
  ElseIf k = 13 And nent > 0 Then
    If ed(cur) Then
      folder = folder + RTrim$(Left$(en(cur), 8)) + "/"
      Listing : Show
    Else
      View Tag(cur)
      Show
    End If
  ElseIf (k = Asc("d") Or k = Asc("D")) And nent > 0 Then
    If ed(cur) = 0 Then
      StdIO.Locate 1, 24 : Print "Delete " + Tag(cur) + "? (Y) ";
      If StdIO.GetKey() = Asc("y") Or StdIO.GetKey() = Asc("Y") Then
        r = Ask(chan, "DELETE " + Tag(cur))
        Listing
      End If
      Show
    End If
  ElseIf (k = Asc("c") Or k = Asc("C")) And nent > 0 Then
    If ed(cur) = 0 Then
      r = GetFile(Tag(cur))
      If r >= 0 Then
        name = RTrim$(Left$(en(cur), 8))
        If RTrim$(Mid$(en(cur), 9, 3)) <> "" Then name = name + "." + RTrim$(Mid$(en(cur), 9, 3))
        r = FileSystem.Save(name, VarPtr(fbuf(0)), r)
        StdIO.Locate 1, 24 : Print "Copied to " + name + " (" + Str$(r) + ") - any key";
      Else
        StdIO.Locate 1, 24 : Print "Could not get it - any key";
      End If
      k = StdIO.GetKey() : Show
    End If
  ElseIf k = Asc("u") Or k = Asc("U") Then
    AskLine "Upload disc file: "
    If name <> "" Then
      r = FileSystem.Load(name, VarPtr(fbuf(0)), 8191)
      If r >= 0 Then
        nid = nid + 1 : If nid > 250 Then nid = 1
        FrameStart chan, 2, nid, 5 + Len(folder) + Len(name) + r
        FrameText "PUT " + folder + name : FrameByte 0
        For i = 0 To r - 1
          FrameByte fbuf(i)
        Next
        FrameEnd
        Do
          ReadHeader
          If hType = 3 And hId = nid Then Exit Do
          SkipFrame
        Loop
        SkipFrame
        Listing
      Else
        StdIO.Locate 1, 24 : Print "No such disc file - any key" : k = StdIO.GetKey()
      End If
    End If
    Show
  ElseIf k = Asc("r") Or k = Asc("R") Then
    Listing : Show
  End If
Loop
StdIO.Cls
Print "PISHELL done."

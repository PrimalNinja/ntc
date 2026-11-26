' Link - the Pi link for the NTC PI DEMOS: CyborgOS for the Pi's frames (cyborg-os/pi/proto.js,
' docs/cyborgos-pi.md) over a CPC-CPLink or a CPLink2 at &FD80 (data) / &FD81 (status: bit 0 a
' byte waiting, bit 1 room to write). Written in BASIC so that it can be read and changed while
' testing on the real card; the one #asm block is the CPLink2's Pi ROM copy. NTC platform: cpcfw.
'
'   Link.Hello name            HELLO; the Pi's answer in Link.Reply
'   Link.Ask(c, text)          a request on channel c (0: control); True when the answer is OK ...
'   Link.AskTo(c, text, addr, max)          ... its data put at addr (max bytes kept)
'   Link.AskWith(c, text, addr, n)          ... n bytes at addr sent with it (in parts when long)
'   Link.AskBoth(c, text, addr, n, raddr, rmax)
'   Link.Open(text)            OPEN service args: the channel, 0 when refused
'   Link.Shut c                CLOSE
'   Link.Send c, addr, n       a DATA frame;  Link.SendText c, text
'   Link.Poll(addr, max)       a frame if one is waiting: its type (0 none), Link.EvChan, Reply / data
'   Link.Wait(ticks, addr, max)  the same, waiting up to ticks (300 a second)
' LastEvent: the newest event that came while an answer was being waited for ("" none yet).
' After an answer: Reply (its text), BodyLen (the bytes of data that came), Kept (those put at
' addr), Parts (frames it came in), Bulk (True: through the CPLink2's Pi ROM), Lost (True: a byte
' did not come in time - the link is taken as dead from then on).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Const LINKD = &HFD80
Const LINKS = &HFD81
Public Reply As String Max 80
Public Lost As Integer
Public Patience As Integer
Public BodyLen As Integer, Kept As Integer, Parts As Integer, Bulk As Integer
Public EvChan As Integer
Public PiMax As Integer
Public Passed As Integer, Failed As Integer
Public Skipped As Integer
Public LastEvent As String Max 80
Private nid As Integer, sum As Integer
Private hType As Integer, hChan As Integer, hId As Integer, hLen As Integer, hLen0 As Integer, hMore As Integer

' ---- the card
Public Function Status() As Integer
  Status = Inp(LINKS)
End Function
Public Function IsCPLink2() As Integer
  IsCPLink2 = ((Inp(LINKS) And &HF0) = &HA0)
End Function

' ---- a byte out when there is room, a byte in when there is one - or Lost
Private Sub ByteOut(ByVal b As Integer)
  Dim t As Integer
  If Lost Then Exit Sub
  If (Inp(LINKS) And 2) = 0 Then
    t = Ticks
    Do While (Inp(LINKS) And 2) = 0
      If Ticks - t > Patience Then Lost = True : Exit Sub
    Loop
  End If
  Out LINKD, b
End Sub
Private Function ByteIn() As Integer
  Dim t As Integer
  ByteIn = 0
  If Lost Then Exit Function
  If (Inp(LINKS) And 1) = 0 Then
    t = Ticks
    Do While (Inp(LINKS) And 1) = 0
      If Ticks - t > Patience Then Lost = True : Exit Function
    Loop
  End If
  ByteIn = Inp(LINKD)
End Function

' ---- a frame out: chan, type, id, length, the payload a byte at a time, the check
Private Sub FrameStart(ByVal c As Integer, ByVal t As Integer, ByVal id As Integer, ByVal n As Integer)
  ByteOut &HA5
  sum = 0
  FrameByte c : FrameByte t : FrameByte id : FrameByte n And 255 : FrameByte n \ 256
End Sub
Private Sub FrameByte(ByVal b As Integer)
  ByteOut b
  sum = (sum + b) And 255
End Sub
Private Sub FrameText(ByVal s As String Max 80)
  Dim i As Integer
  For i = 1 To Len(s)
    FrameByte Asc(Mid$(s, i, 1))
  Next
End Sub
Private Sub FrameMem(ByVal addr As Integer, ByVal n As Integer)
  Dim i As Integer
  For i = 0 To n - 1
    FrameByte Peek(addr + i)
  Next
End Sub
Private Sub FrameEnd()
  ByteOut sum
End Sub

' ---- a frame in: its header (hunting for A5), then its payload read by the caller, then Done
Private Sub ReadHeader()
  Dim k As Integer, n As Integer
  n = 0
  Do
    k = ByteIn()
    If Lost Then Exit Sub
    ' 2000 bytes and no frame start: not a Pi talking (no card at all reads &FF for ever)
    n = n + 1
    If n > 2000 Then Lost = True : Exit Sub
  Loop Until k = &HA5
  hChan = ByteIn() : k = ByteIn() : hType = k And &H7F : hMore = k And &H80 : hId = ByteIn()
  hLen = ByteIn() : hLen = hLen + ByteIn() * 256
  hLen0 = hLen
End Sub
' Done: the check taken, and the frame's bytes given back as credit (the Pi sends on a channel
' only what it was told there is room for)
Private Sub Done()
  Dim k As Integer
  k = ByteIn()
  ' (not for a CLOSE: the channel is gone, and credit for it only gets ERR nochan back)
  If hChan <> 0 And hType <> 6 Then
    FrameStart hChan, 7, 0, 2 : FrameByte hLen0 And 255 : FrameByte hLen0 \ 256 : FrameEnd
  End If
End Sub
Private Sub SkipFrame()
  Dim k As Integer
  Do While hLen > 0 And Not Lost
    hLen = hLen - 1 : k = ByteIn()
  Loop
  Done
  Skipped = Skipped + 1
End Sub
' a payload read: its text into Reply (to the 0 or the end), its data to addr
Private Sub ReadPayload(ByVal addr As Integer, ByVal max As Integer, ByVal istext As Integer)
  Dim k As Integer
  Reply = ""
  Do While hLen > 0 And Not Lost
    k = ByteIn() : hLen = hLen - 1
    If istext Then
      If k = 0 Then
        istext = False
      Else
        If Len(Reply) < 79 Then Reply = Reply & Chr$(k)
      End If
    Else
      If Kept < max Then Poke addr + Kept, k : Kept = Kept + 1
      BodyLen = BodyLen + 1
    End If
  Loop
  Done
End Sub

' ---- the CPLink2's Pi ROM: n bytes from ROM rom (32, 33) at &C000 to dst. The firmware selects
' the ROM and puts things back (KL ROM SELECT / KL ROM DESELECT), on the real stack.
Private Sub RomCopy(ByVal dst As Integer, ByVal n As Integer, ByVal rom As Integer)
#asm
            ld (ntc_ip), sp
            ld sp, (ntc_csp)
            ld a, ({rom})
            ld c, a
            call #B90F                  ; KL ROM SELECT: C = the ROM; BC back = what was there
            push bc
            ld hl, #C000
            ld de, ({dst})
            ld bc, ({n})
            ld a, b
            or c
            jr z, lk_rc_none
            ldir
lk_rc_none: pop bc
            call #B918                  ; KL ROM DESELECT
            ld sp, (ntc_ip)
#endasm
End Sub

' the number in Reply from character at on (0 when there is none)
Public Function Num(ByVal at As Integer) As Integer
  Dim v As Integer, k As Integer
  v = 0
  Do While at <= Len(Reply)
    k = Asc(Mid$(Reply, at, 1))
    If k < 48 Or k > 57 Then Exit Do
    v = v * 10 + k - 48 : at = at + 1
  Loop
  Num = v
End Function

' ---- an answer: the RSP frames with this request's id, parts joined; other frames skipped
Private Function Answer(ByVal addr As Integer, ByVal max As Integer) As Integer
  Dim n As Integer, at As Integer, m As Integer
  Reply = "" : BodyLen = 0 : Kept = 0 : Bulk = False : Parts = 0
  Do
    ReadHeader
    If Lost Then Reply = "TIMEOUT (no byte from the Pi)" : Answer = False : Exit Function
    If hType = 3 And hId = nid Then
      Parts = Parts + 1
      ReadPayload addr, max, True
      If hMore = 0 Then Exit Do
    ElseIf hType = 5 Then
      ' an event that came while the answer was waited for: kept in LastEvent (the newest one).
      ' On the control channel "ERR nochan n" is all the Pi says to a request on a channel
      ' that is not open (no RSP comes), so it is this request's answer
      at = hChan
      ReadPayload 0, 0, True
      Skipped = Skipped + 1 : LastEvent = Reply
      If at = 0 And Left$(Reply, 10) = "ERR nochan" Then Answer = False : Exit Function
    Else
      SkipFrame
    End If
  Loop
  If Lost Then Reply = "TIMEOUT (the answer stopped)" : Answer = False : Exit Function
  If Left$(Reply, 5) = "BULK " Then
    ' the data is in the Pi ROM: ROM 32, and 33 past 16K
    n = Num(6) : Bulk = True : BodyLen = n
    m = n : If m > max Then m = max
    Kept = m
    If m > 16384 Then
      RomCopy addr, 16384, 32 : RomCopy addr + 16384, m - 16384, 33
    Else
      RomCopy addr, m, 32
    End If
    at = InStr(6, Reply, " ")
    If at > 0 Then Reply = Mid$(Reply, at + 1) Else Reply = ""
  End If
  Answer = (Left$(Reply, 2) = "OK")
End Function

' ---- a request out: its text, and n bytes at addr after a 0 (in parts when longer than the Pi takes)
Private Sub Request(ByVal c As Integer, ByVal s As String Max 80, ByVal addr As Integer, ByVal n As Integer)
  Dim room As Integer, k As Integer
  nid = nid + 1 : If nid > 250 Then nid = 1
  If n = 0 Then
    FrameStart c, 2, nid, Len(s) : FrameText s : FrameEnd
    Exit Sub
  End If
  room = PiMax - Len(s) - 1
  Do While n > 0
    k = n : If k > room Then k = room
    If n > k Then
      FrameStart c, &H82, nid, Len(s) + 1 + k
    Else
      FrameStart c, 2, nid, Len(s) + 1 + k
    End If
    FrameText s : FrameByte 0 : FrameMem addr, k : FrameEnd
    addr = addr + k : n = n - k
  Loop
End Sub

Public Function Ask(ByVal c As Integer, ByVal s As String Max 80) As Integer
  Request c, s, 0, 0
  Ask = Answer(0, 0)
End Function
Public Function AskTo(ByVal c As Integer, ByVal s As String Max 80, ByVal addr As Integer, ByVal max As Integer) As Integer
  Request c, s, 0, 0
  AskTo = Answer(addr, max)
End Function
Public Function AskWith(ByVal c As Integer, ByVal s As String Max 80, ByVal addr As Integer, ByVal n As Integer) As Integer
  Request c, s, addr, n
  AskWith = Answer(0, 0)
End Function
Public Function AskBoth(ByVal c As Integer, ByVal s As String Max 80, ByVal addr As Integer, ByVal n As Integer, ByVal raddr As Integer, ByVal rmax As Integer) As Integer
  Request c, s, addr, n
  AskBoth = Answer(raddr, rmax)
End Function

' ---- HELLO: who we are; the Pi's answer in Reply (True when it came)
Public Function Hello(ByVal name As String Max 16) As Integer
  Dim s As String Max 80
  If Patience = 0 Then Patience = 900
  PiMax = 1024 : Lost = False : nid = 0 : Skipped = 0 : LastEvent = ""
  s = "COS1 machine=cpc name=" & name & " max=256 cols=80 rows=24"
  FrameStart 0, 1, 0, Len(s) : FrameText s : FrameEnd
  Do
    ReadHeader
    If Lost Then Reply = "TIMEOUT (no HELLO from the Pi)" : Hello = False : Exit Function
    If hType = 1 Then Exit Do
    SkipFrame
  Loop
  BodyLen = 0 : Kept = 0
  ReadPayload 0, 0, True
  Hello = Not Lost
End Function

Public Function Open(ByVal s As String Max 70) As Integer
  If Ask(0, "OPEN " & s) Then Open = Num(4) Else Open = 0
End Function
Public Sub Shut(ByVal c As Integer)
  Dim r As Integer
  If c > 0 Then r = Ask(0, "CLOSE " & c)
End Sub

' ---- DATA out
Public Sub Send(ByVal c As Integer, ByVal addr As Integer, ByVal n As Integer)
  Dim k As Integer
  Do While n > 0
    k = n : If k > PiMax Then k = PiMax
    FrameStart c, 4, 0, k : FrameMem addr, k : FrameEnd
    addr = addr + k : n = n - k
  Loop
End Sub
Public Sub SendText(ByVal c As Integer, ByVal s As String Max 80)
  FrameStart c, 4, 0, Len(s) : FrameText s : FrameEnd
End Sub

' ---- a frame that came by itself (an event, data, a close): its type - 4 DATA (its bytes at
' addr, Kept of them), 5 EVT (its text in Reply), 6 CLOSE - its channel in EvChan; 0: none waiting
Public Function Poll(ByVal addr As Integer, ByVal max As Integer) As Integer
  Poll = 0
  If Lost Then Exit Function
  If (Inp(LINKS) And 1) = 0 Then Exit Function
  ReadHeader
  If Lost Then Exit Function
  EvChan = hChan : BodyLen = 0 : Kept = 0
  ReadPayload addr, max, (hType <> 4)
  Poll = hType
End Function
Public Function Wait(ByVal n As Integer, ByVal addr As Integer, ByVal max As Integer) As Integer
  Dim t As Integer, k As Integer
  t = Ticks : k = 0
  Do
    k = Poll(addr, max)
  Loop Until k <> 0 Or Lost Or (Ticks - t > n)
  Wait = k
End Function

' ---- the tests' own: a line a check, and the count at the end
Public Sub Title(ByVal s As String Max 60)
  Print s
  Print String$(Len(s), "-")
  Passed = 0 : Failed = 0
End Sub
Public Sub Check(ByVal s As String Max 60, ByVal ok As Integer)
  If ok Then
    Print "  ok    "; s
    Passed = Passed + 1
  Else
    Print "  FAIL  "; s; "  ["; Reply; "]"
    Failed = Failed + 1
  End If
End Sub
Public Sub Summary()
  Print
  If Lost Then Print "THE LINK WENT QUIET: a byte did not come from the Pi in time."
  Print Passed; " ok, "; Failed; " failed";
  If Failed = 0 And Not Lost Then Print " - ALL PASS" Else Print
End Sub

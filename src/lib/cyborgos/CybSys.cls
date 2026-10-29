' CybSys - the hypervisor's services. NTC platform class: CyborgOS (the same class CyborgOS's
' own commands - PS, KILL, RESET, FG, TOP, WAIT, MEM ... - were built with; a CybSys.cls in the
' project replaces this one). A program asks the hypervisor through BDOS 131: DE = a block - the op, a slot or value,
' then what comes back. Ops: 0 a slot's line for PS (its state, in front, its program's name),
' 1 kill a slot's program, 2 reset a slot (0: this one), 3 a slot to the front, 4 wait until no
' other program runs, 6 TOP's table into this slot, 7 the memory (the tables' end, the top of
' free RAM, the pages, the totals line), 8 32 pages of the map from page Word(2), 9 MODE (0-4 set,
' 255 which), 15 a table (Byte(1) 4: the claims, 10 bytes each), 16-19 the claims (Claim ...),
' 20 3 the clock (Clock), 4 the uptime (Uptime, 32 bits), 5 the host (Host), 28-33 the ports (PortOpen ...), 34 a port's name (PortName)
Option Explicit
Private b(63) As Byte
Private hsp As Integer
Private pm(127) As Byte                       ' (a port's message on its way)
Private pn As Integer, pc As Integer, ps As Integer, psl As Integer   ' its length, its caller, the last status

' Ask(op, v): the call made; its answer (A): 0 done, 1 nothing to do, 255 no such slot / not CyborgOS
Public Function Ask(ByVal op As Integer, ByVal v As Integer) As Integer
  b(0) = op : b(1) = v
  Ask = Bdos(131, VarPtr(b))
End Function

' Clock: the CPC's clock, in 1/300 s (its low 16 bits: Clock - t is the time since t, wrapping)
Public Function Clock() As Integer
  b(6) = 0 : b(7) = 0
  Clock = Ask(20, 3)
  Clock = b(6) + b(7) * 256
End Function

' Host: the machine CyborgOS runs on - 0 an Amstrad CPC, 1 a ZX Spectrum Next (255: not CyborgOS).
' A program is the same .CYB on both; what differs is the hardware under the hypervisor
Public Function Host() As Integer
  Host = Ask(20, 5)
End Function

' Shared(d): how many other slots are on drive letter d now (CD moves a letter only nobody else is on)
Public Function Shared(ByVal d As String) As Integer
  b(2) = Asc(d)
  Shared = Ask(20, 7)
End Function

' BootDrive: the boot drive's letter - "A" on the CPC (or "CYB d"), "D" (C:CYBORGOS/) on the Next:
' every slot starts on it, so CD on it takes a free letter rather than moving it (255: not CyborgOS)
Public Function BootDrive() As String
  BootDrive = Chr$(Ask(20, 6))
End Function

' Dos: the name of the DOS behind the drives, for messages - "UniDOS" on the CPC, "esxDOS"
' (NextZXOS's) on the Next; its error numbers are what the device calls (BDOS 30) give back
Public Function Dos() As String
  If Host() = 1 Then Dos = "esxDOS" Else Dos = "UniDOS"
End Function

' Uptime: the CPC's clock in full - 1/300 s since the CPC was reset (32 bits: wraps after 165 days)
Public Function Uptime() As Long
  Dim u As Long
  b(6) = 0 : b(7) = 0 : b(8) = 0 : b(9) = 0
  u = Ask(20, 4)
  u = b(9)
  u = u * 256 + b(8)
  u = u * 256 + b(7)
  u = u * 256 + b(6)
  Uptime = u
End Function

' the block's byte i, word i (from Ask), and the text at i (its length, then its characters)
Public Function ByteAt(ByVal i As Integer) As Integer
  ByteAt = b(i)
End Function
Public Function WordAt(ByVal i As Integer) As Integer
  WordAt = b(i) + b(i + 1) * 256
End Function
Public Sub SetWord(ByVal i As Integer, ByVal v As Integer)
  b(i) = v And 255 : b(i + 1) = ((v And &HFF00) \ 256) And 255   ' (And first: #8000 on, negative)
End Sub
Public Function TextAt(ByVal i As Integer) As String
  Dim k As Integer, s As String Max 60
  s = ""
  For k = 1 To b(i)
    s = s + Chr$(b(i + k))
  Next
  TextAt = s
End Function

' The claims - hardware a program drives itself (FDC, SOUND, MF2, NVRAM, M4, SERIAL ...): a
' name (8 characters at most) and a unit (0-254: which of them - SOUND 0 the CPC's own AY, 1 and 2
' a PlayCity's ...), held by one slot at a time. Claim it before touching the hardware; another
' slot's claim is refused while it is held. Its program ending, KILL, RESET free them all.
' Claim: 0 yours, else the slot that has it (255: no room in the table, or not CyborgOS)
' Release: 0 done, 1 not yours
' Take: it is yours now, from whoever had it (CLAIMS TAKE): the slot that had it (0 nobody)
' Held: 0 still yours, else the slot that has it (254 nobody) - a program that can lose it to
'   Take (a music player) asks now and then, and stops touching the hardware when it isn't
Public Function Claim(ByVal nm As String, ByVal u As Integer) As Integer
  Claim = Cl(16, nm, u)
End Function
Public Function Release(ByVal nm As String, ByVal u As Integer) As Integer
  Release = Cl(17, nm, u)
End Function
Public Function Take(ByVal nm As String, ByVal u As Integer) As Integer
  Take = Cl(18, nm, u)
End Function
Public Function Held(ByVal nm As String, ByVal u As Integer) As Integer
  Held = Cl(19, nm, u)
End Function
Private Function Cl(ByVal op As Integer, ByVal nm As String, ByVal u As Integer) As Integer
  Dim k As Integer
  nm = UCase$(nm)
  b(0) = op : b(1) = u
  For k = 1 To 8
    If k <= Len(nm) Then b(k + 1) = Asc(Mid$(nm, k, 1)) Else b(k + 1) = 32
  Next
  Cl = Bdos(131, VarPtr(b))
End Function

' The ports - a program serving others: a service (RAT, a model ...) opens a port by name (8
' characters at most); any slot calls it with a message (128 characters at most) and gets the
' service's answer. One call at a time a port: others wait their turn. Waiting sleeps the slot a
' tick at a time (as a key wait does), so the server gets the CPU. A port closes when its
' program ends (or is killed); a caller gone is forgotten.
' PortOpen(nm): 0 the port is this program's, 2 another program's, 255 no room (8 ports)
' PortClose(nm): 0 closed, 2 not this program's
' PortCall(nm, msg): msg sent, the answer back (waits for it); PortStatus() 0 done, 2 no such
' port (the answer then "")
' PortGet(nm): the server's next message - 0 one came (PortMessage(), PortCaller()), 1 none yet
' (the slot slept a tick: look at the keys, then again), 2 not this program's port
' PortReply(nm, msg): the answer to the message got: 0 done, 2 nothing to answer
Public Function PortOpen(ByVal nm As String) As Integer
  PortOpen = Pt(28, nm, 0)
End Function
Public Function PortClose(ByVal nm As String) As Integer
  PortClose = Pt(29, nm, 0)
End Function
Public Function PortCall(ByVal nm As String, ByVal msg As String) As String Max 128
  Dim r As Integer
  PortCall = ""
  PutMsg msg
  Do
    r = Pt(30, nm, pn)                           ' (1: another call in the box - its turn first)
  Loop While r = 1
  ps = r
  If r <> 0 Then Exit Function
  Do
    r = Pt(31, nm, 0)                            ' (1: not answered yet)
  Loop While r = 1
  ps = r
  If r = 0 Then PortCall = GetMsg()
End Function
Public Function PortGet(ByVal nm As String) As Integer
  PortGet = Pt(32, nm, 0)
  If PortGet = 0 Then pc = b(13)
End Function
Public Function PortMessage() As String Max 128
  PortMessage = GetMsg()
End Function
Public Function PortCaller() As Integer
  PortCaller = pc
End Function
Public Function PortReply(ByVal nm As String, ByVal msg As String) As Integer
  PutMsg msg
  PortReply = Pt(33, nm, pn)
End Function
' PortName(i): port i's name (0-7: the table's places), "" a free place; its slot: PortSlot()
Public Function PortName(ByVal i As Integer) As String
  Dim k As Integer, t As String Max 8
  t = "" : b(10) = 0
  If Ask(34, i) = 0 And b(10) <> 0 Then
    For k = 2 To 9
      If b(k) > 32 Then t = t + Chr$(b(k))
    Next
  End If
  psl = b(10)
  PortName = t
End Function
Public Function PortSlot() As Integer
  PortSlot = psl
End Function
Public Function PortStatus() As Integer
  PortStatus = ps
End Function
Private Function Pt(ByVal op As Integer, ByVal nm As String, ByVal n As Integer) As Integer
  Dim k As Integer, a As Integer
  nm = UCase$(nm)
  b(0) = op
  For k = 1 To 8
    If k <= Len(nm) Then b(k + 1) = Asc(Mid$(nm, k, 1)) Else b(k + 1) = 32
  Next
  a = VarPtr(pm)
  b(10) = a And 255 : b(11) = ((a And &HFF00) \ 256) And 255
  b(12) = n
  Pt = Bdos(131, VarPtr(b))
  pn = b(12)
End Function
Private Sub PutMsg(ByVal msg As String)
  Dim k As Integer
  pn = Len(msg)
  If pn > 128 Then pn = 128
  For k = 1 To pn
    pm(k - 1) = Asc(Mid$(msg, k, 1))
  Next
End Sub
Private Function GetMsg() As String Max 128
  Dim k As Integer
  GetMsg = ""
  For k = 0 To pn - 1
    GetMsg = GetMsg + Chr$(pm(k))
  Next
End Function

' Tail(): the command tail as it was typed (System.CommandLine's is in capitals, as CP/M has it -
' an address, a name on a server: their small letters matter). The line typed is still in the
' slot's command line buffer while its program runs (#F68F its length, #F690 its characters):
' its end, when it is the tail in other letters; else (RUN in another slot) the tail as it is
Public Function Tail() As String Max 72
  Dim k As Integer, n As Integer, m As Integer, c As Integer
  Tail = Trim$(System.CommandLine())
  m = Len(Tail)
  n = Peek(&HF68F)
  If n > 70 Then n = 70
  Do While n > 0                                 ' (the line's end: spaces after it left out)
    If Peek(&HF68F + n) <> 32 Then Exit Do
    n = n - 1
  Loop
  If n < m Or m = 0 Then Exit Function
  For k = 1 To m                                 ' its last m characters: the tail, in capitals?
    c = Peek(&HF68F + n - m + k)
    If c >= 97 And c <= 122 Then c = c - 32
    If c <> Asc(Mid$(Tail, k, 1)) Then Exit Function
  Next
  Tail = ""
  For k = 1 To m
    Tail = Tail + Chr$(Peek(&HF68F + n - m + k))
  Next
End Function

' BDOS function f, DE = d: A
Public Function Bdos(ByVal f As Integer, ByVal d As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({f})
            ld c, a
            ld de, ({d})
            ei                      ; (CP/M's BDOS: interrupts on)
            call 5
            di                      ; (off before SP is the threaded code again: it comes back with them on)
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function

' CybSys - CyborgOS's own commands (PS, KILL, RESET, FG, TOP, WAIT, MEM ...: build them for cpm,
' with this class) ask the hypervisor through BDOS 131: DE = a block - the op, a slot or value,
' then what comes back. Ops: 0 a slot's line for PS (its state, in front, its program's name),
' 1 kill a slot's program, 2 reset a slot (0: this one), 3 a slot to the front, 4 wait until no
' other program runs, 6 TOP's table into this slot, 7 the memory (the tables' end, the top of
' free RAM, the pages, the totals line), 8 32 pages of the map from page Word(2), 9 MODE (0-4 set,
' 255 which), 15 a table (Byte(1) 4: the claims, 10 bytes each), 16-19 the claims (Claim ...)
Option Explicit
Private b(63) As Byte
Private hsp As Integer

' Ask(op, v): the call made; its answer (A): 0 done, 1 nothing to do, 255 no such slot / not CyborgOS
Public Function Ask(ByVal op As Integer, ByVal v As Integer) As Integer
  b(0) = op : b(1) = v
  Ask = Bdos(131, VarPtr(b))
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

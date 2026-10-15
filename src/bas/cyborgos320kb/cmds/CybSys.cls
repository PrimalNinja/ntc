' CybSys - CyborgOS's own commands (PS, KILL, RESET, FG, TOP, WAIT, MEM ...: build them for cpm,
' with this class) ask the hypervisor through BDOS 131: DE = a block - the op, a slot or value,
' then what comes back. Ops: 0 a slot's line for PS (its state, in front, its program's name),
' 1 kill a slot's program, 2 reset a slot (0: this one), 3 a slot to the front, 4 wait until no
' other program runs, 6 TOP's table into this slot, 7 the memory (the tables' end, the top of
' free RAM, the pages, the totals line), 8 32 pages of the map from page Word(2), 9 MODE (0-4 set,
' 255 which)
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

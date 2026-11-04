' COSList: CyborgOS's List - the same calls as List.cls, with the nodes in the hypervisor's heap
' (the free half of the banks, shared with every slot) instead of the program's own 64K, so a
' list is as big as the slot's share of the pool, not the TPA. Every call is a BDOS 131 op
' (48-63) the kernel answers; a handle is a number the hypervisor owns, never an address, so
' a dump, a move and a revive keep it. A program written to List's calls - GetWord / SetWord,
' never Data() - runs on either by the class's name alone.
'   h = COSList.Create(size)             a list, size data bytes a node (1-2044); 0 no room
'   n = COSList.Append(h) / Prepend(h) / InsertAfter(h, node)      a node (cleared); 0 no room
'   COSList.Delete h, node               the node gone
'   COSList.First(h) / Last(h) / NextOf(node) / PrevOf(node)        a walk; 0 none
'   COSList.Count(h)
'   COSList.GetWord(node, o) / GetByte / SetWord node, o, v / SetByte
'   COSList.Read node, o, n, addr / Write node, o, n, addr          n bytes (1K at most) of its data
'   COSList.Search(h, o, v)              the first node whose word at o is v; 0 none
'   COSList.Sort h, o                    by the word at o, ascending
'   COSList.Destroy h                    the list and its nodes gone
'   COSList.Data(node)                   0: a node outside the slot has no address here
'   COSList.Status()                     the last op's answer: 0 done, 1 no room, 255 no such list / node
' A node handle is a Long: the list's number in its high word, the node's in the low.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private b(63) As Byte
Private m_st As Integer

Private Sub W(ByVal i As Integer, ByVal v As Integer)
  b(i) = v And 255 : b(i + 1) = ((v And &HFF00) \ 256) And 255
End Sub

Private Function R(ByVal i As Integer) As Integer
  R = b(i) + b(i + 1) * 256
End Function

Private Function Op(ByVal o As Integer) As Integer
  b(0) = o : b(1) = 0
  m_st = Bdos(131, VarPtr(b))
  Op = m_st
End Function

Public Function Status() As Integer
  Status = m_st
End Function

' the list number of a node handle, and the node's
Private Function LH(ByVal node As Long) As Integer
  LH = (node \ 65536) And &HFFFF
End Function

Private Function LN(ByVal node As Long) As Integer
  LN = node And &HFFFF
End Function

Private Function Handle(ByVal h As Integer, ByVal n As Integer) As Long
  If n = 0 Then Handle = 0 Else Handle = CLng(h And &HFFFF) * 65536 + (n And &HFFFF)
End Function

Public Function Create(ByVal size As Integer) As Long
  W 2, size
  If Op(48) <> 0 Then Create = 0 Else Create = R(2)
End Function

Public Function Destroy(ByVal h As Long) As Integer
  W 2, LN(h)
  Destroy = Op(49)
End Function

Public Function Append(ByVal h As Long) As Long
  W 2, LN(h)
  If Op(50) <> 0 Then Append = 0 Else Append = Handle(LN(h), R(4))
End Function

Public Function Prepend(ByVal h As Long) As Long
  W 2, LN(h)
  If Op(51) <> 0 Then Prepend = 0 Else Prepend = Handle(LN(h), R(4))
End Function

Public Function InsertAfter(ByVal h As Long, ByVal node As Long) As Long
  W 2, LN(h) : W 4, LN(node)
  If Op(52) <> 0 Then InsertAfter = 0 Else InsertAfter = Handle(LN(h), R(4))
End Function

Public Function Delete(ByVal h As Long, ByVal node As Long) As Integer
  W 2, LN(h) : W 4, LN(node)
  Delete = Op(53)
End Function

Public Function First(ByVal h As Long) As Long
  W 2, LN(h)
  If Op(54) <> 0 Then First = 0 Else First = Handle(LN(h), R(4))
End Function

Public Function Last(ByVal h As Long) As Long
  W 2, LN(h)
  If Op(55) <> 0 Then Last = 0 Else Last = Handle(LN(h), R(4))
End Function

Public Function NextOf(ByVal node As Long) As Long
  W 2, LH(node) : W 4, LN(node)
  If Op(56) <> 0 Then NextOf = 0 Else NextOf = Handle(LH(node), R(4))
End Function

Public Function PrevOf(ByVal node As Long) As Long
  W 2, LH(node) : W 4, LN(node)
  If Op(57) <> 0 Then PrevOf = 0 Else PrevOf = Handle(LH(node), R(4))
End Function

Public Function Count(ByVal h As Long) As Integer
  W 2, LN(h)
  If Op(58) <> 0 Then Count = 0 Else Count = R(4)
End Function

' n bytes of the node's data from offset o to addr in this program, and back
Public Sub Read(ByVal node As Long, ByVal o As Integer, ByVal n As Integer, ByVal addr As Integer)
  W 2, LH(node) : W 4, LN(node) : W 6, o : W 8, n : W 10, addr
  m_st = Op(59)
End Sub

Public Sub Write(ByVal node As Long, ByVal o As Integer, ByVal n As Integer, ByVal addr As Integer)
  W 2, LH(node) : W 4, LN(node) : W 6, o : W 8, n : W 10, addr
  m_st = Op(60)
End Sub

Public Function GetWord(ByVal node As Long, ByVal offset As Integer) As Integer
  Dim v As Integer
  Read node, offset, 2, VarPtr(v)
  If m_st <> 0 Then GetWord = 0 Else GetWord = v
End Function

Public Function GetByte(ByVal node As Long, ByVal offset As Integer) As Integer
  Dim v As Integer
  v = 0
  Read node, offset, 1, VarPtr(v)
  If m_st <> 0 Then GetByte = 0 Else GetByte = v And 255
End Function

Public Sub SetWord(ByVal node As Long, ByVal offset As Integer, ByVal value As Integer)
  Dim v As Integer
  v = value
  Write node, offset, 2, VarPtr(v)
End Sub

Public Sub SetByte(ByVal node As Long, ByVal offset As Integer, ByVal value As Integer)
  Dim v As Integer
  v = value And 255
  Write node, offset, 1, VarPtr(v)
End Sub

Public Function Data(ByVal node As Long) As Long
  Data = 0
End Function

Public Function Search(ByVal h As Long, ByVal offset As Integer, ByVal value As Integer) As Long
  W 2, LN(h) : W 6, offset : W 8, value
  If Op(61) <> 0 Then Search = 0 Else Search = Handle(LN(h), R(4))
End Function

Public Function Sort(ByVal h As Long, ByVal offset As Integer) As Integer
  W 2, LN(h) : W 6, offset
  Sort = Op(62)
End Function

' the node size and count of list h: Word(4), Word(6) of the block after
Public Function NodeSize(ByVal h As Long) As Integer
  W 2, LN(h)
  If Op(63) <> 0 Then NodeSize = 0 Else NodeSize = R(4)
End Function

' BDOS function fn, DE = dd: A (on the real stack, interrupts on for the call)
Private Function Bdos(ByVal fn As Integer, ByVal dd As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({fn})
            ld c, a
            ld de, ({dd})
            ei
            call 5
            di
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function
Private hsp As Integer

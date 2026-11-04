' Tree: a tree of behaviours gated by trits, walked with the short-circuit - a node whose gate is 0
' is skipped with its whole subtree (never looked at), a node gated -1 is given back as inhibited
' and its subtree is not entered, a node gated 1 is given back to act on and then its children are
' walked, first to last. The program does the acting: it asks for the next node and does what
' that node's action code means to it (a Select Case), so the class holds no code addresses and a
' behaviour is an ordinary Sub. Gates are data: a sensor, or another node's result, can set them
' between walks, so the tree rewires itself at run time.
'   Tree.Clear
'   n = Tree.Add(parent, gate, action)    a node under parent (0: a root), its gate (-1, 0, 1)
'                                         and an action code of the program's own; n is 1 up
'   Tree.SetGate n, t / Tree.GetGate(n)   a gate changed / read
'   Tree.Action(n)                        the action code
'   Tree.Start root                       a walk begins
'   n = Tree.Visit()                       the next node to act on (0: the walk is over);
'   Tree.Why()                            1 act, -1 inhibited (the subtree not entered)
'   Tree.Count()                          nodes in the tree
' Up to 255 nodes, 32 deep.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const MAXN = 255
Const MAXD = 32

Dim m_gate(MAXN) As Byte             ' 0, 1, 255
Dim m_act(MAXN) As Integer
Dim m_kid(MAXN) As Byte              ' the first child (0 none)
Dim m_sib(MAXN) As Byte              ' the next sibling (0 none)
Dim m_last(MAXN) As Byte             ' the last child so far (adding keeps the order)
Dim m_stk(MAXD) As Byte
Dim m_n As Integer, m_sp As Integer, m_why As Integer

Public Sub Clear()
  m_n = 0
  m_sp = 0
End Sub

Public Function Count() As Integer
  Count = m_n
End Function

Public Function Add(ByVal parent As Integer, ByVal gate As Integer, ByVal action As Integer) As Integer
  Dim n As Integer
  If m_n >= MAXN Then Add = 0 : Exit Function
  m_n = m_n + 1
  n = m_n
  m_gate(n) = Trit.ToByte(gate)
  m_act(n) = action
  m_kid(n) = 0
  m_sib(n) = 0
  m_last(n) = 0
  If parent > 0 And parent <= m_n Then
    If m_kid(parent) = 0 Then
      m_kid(parent) = n
    Else
      m_sib(m_last(parent)) = n
    End If
    m_last(parent) = n
  End If
  Add = n
End Function

Public Sub SetGate(ByVal n As Integer, ByVal t As Integer)
  If n > 0 And n <= m_n Then m_gate(n) = Trit.ToByte(t)
End Sub

Public Function GetGate(ByVal n As Integer) As Integer
  If n > 0 And n <= m_n Then GetGate = Trit.FromByte(m_gate(n)) Else GetGate = 0
End Function

Public Function Action(ByVal n As Integer) As Integer
  If n > 0 And n <= m_n Then Action = m_act(n) Else Action = 0
End Function

Public Sub Start(ByVal root As Integer)
  m_sp = 0
  If root > 0 And root <= m_n Then
    m_stk(0) = root
    m_sp = 1
  End If
End Sub

Public Function Why() As Integer
  Why = m_why
End Function

' the next node to act on; its children queued (last first, so the first is next) when it acts
Public Function Visit() As Integer
  Dim n As Integer, g As Integer, c As Integer, k As Integer, first As Integer
  Do
    If m_sp = 0 Then Visit = 0 : Exit Function
    m_sp = m_sp - 1
    n = m_stk(m_sp)
    g = m_gate(n)
    If g = 1 Then
      ' the children in order: the chain is walked once to count, then pushed from the end
      c = m_kid(n)
      k = 0
      Do While c <> 0
        k = k + 1
        c = m_sib(c)
      Loop
      first = m_sp
      m_sp = m_sp + k
      If m_sp > MAXD Then m_sp = first : Visit = 0 : Exit Function     ' (too deep: the walk ends)
      c = m_kid(n)
      Do While c <> 0
        k = k - 1
        m_stk(first + k) = c
        c = m_sib(c)
      Loop
      m_why = 1
      Visit = n
      Exit Function
    ElseIf g = 255 Then
      m_why = -1
      Visit = n
      Exit Function
    End If
    ' g = 0: the node and everything under it skipped - one compare, no visit
  Loop
End Function

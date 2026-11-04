' Tree (lib/z80/Tree.cls) self test: a tree of 9 nodes walked with gates 1 / 0 / -1 - the order of
' the nodes given back, the skipped subtrees, the inhibited ones, and a gate changed between walks.
' "TREE bad 0" when everything matched.
Option Explicit
Dim bad As Integer, r As Integer, a As Integer, b As Integer, c As Integer, n As Integer
Dim a1 As Integer, a2 As Integer, b1 As Integer, c1 As Integer, c2 As Integer
Dim seen As String Max 40

Sub Chk(ByVal name As String, ByVal got As String, ByVal want As String)
  If got <> want Then Print "FAIL "; name; " got ["; got; "] want ["; want; "]" : bad = bad + 1
End Sub

' the walk as a string: "n+" acted, "n-" inhibited
Function Walk(ByVal root As Integer) As String
  Dim s As String Max 40, k As Integer
  s = ""
  Tree.Start root
  Do
    k = Tree.Visit()
    If k = 0 Then Exit Do
    s = s + Trim$(Str$(Tree.Action(k)))
    If Tree.Why() = 1 Then s = s + "+" Else s = s + "-"
  Loop
  Walk = s
End Function

'        r(10)
'   a(20)   b(30)   c(40)
' a1 a2     b1      c1 c2
Tree.Clear
r = Tree.Add(0, 1, 10)
a = Tree.Add(r, 1, 20)
b = Tree.Add(r, 0, 30)
c = Tree.Add(r, -1, 40)
a1 = Tree.Add(a, 1, 21)
a2 = Tree.Add(a, 1, 22)
b1 = Tree.Add(b, 1, 31)
c1 = Tree.Add(c, 1, 41)
c2 = Tree.Add(c, 1, 42)
If Tree.Count() <> 9 Then Print "FAIL count"; Tree.Count() : bad = bad + 1
Chk "walk", Walk(r), "10+20+21+22+40-"
' b opened: its child comes between a's and c
Tree.SetGate b, 1
Chk "b open", Walk(r), "10+20+21+22+30+31+40-"
' a2 inhibited, c neutral: c and its children never seen
Tree.SetGate a2, -1
Tree.SetGate c, 0
Chk "a2 inhibit", Walk(r), "10+20+21+22-30+31+"
' the root neutral: nothing at all
Tree.SetGate r, 0
Chk "root off", Walk(r), ""
' the root inhibited: only it, nothing under it
Tree.SetGate r, -1
Chk "root inhibit", Walk(r), "10-"
' a subtree walked on its own
Tree.SetGate r, 1
Chk "subtree", Walk(a), "20+21+22-"
If Tree.GetGate(a2) <> -1 Then Print "FAIL getgate" : bad = bad + 1
Print "TREE bad"; bad

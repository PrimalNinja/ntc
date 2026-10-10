' tinyz80b - VB5/VB6 style BASIC to NTC (Native Threaded Code) for Z80
' type on the left, the NTC thread appears on the right
'
' types     Integer (16 bit) Byte Boolean String (40 chars)  Const  Type..End Type
' numbers   123 &HFF &O17 &X101 #FF TRUE FALSE
' variables Dim / Private / Public / Static, or just use them (Option Explicit
'           makes that an error). a$ is a String, undeclared names get their
'           type from how they are used
' arrays    Dim a(10), b(1 To 5), g(3, 4), s(10) As String, pts(5) As Point
' operators - (unary)  * / \ Mod  + -  &  = <> < <= > >=  Not  And  Or Xor
' procs     Sub / Function / Property Get|Let, ByVal / ByRef (default) / Optional
'           Exit Sub / Exit Function. No recursion (each has one set of locals)
' flow      If / ElseIf / Else / End If (block or one line), Select Case,
'           While/Wend, Do [While|Until]/Loop [While|Until], For/Next/Step,
'           Exit For|Do|While, GoTo, GoSub/Return, End, labels and line numbers
' strings   Len Left$ Right$ Mid$ Chr$ Asc Str$ CStr Val InStr UCase$ LCase$
'           Trim$ LTrim$ RTrim$ Space$ String$ Hex$
' numbers   Abs Sgn Rnd(n)=0..n-1 Int Fix CInt CBool CByte Peek Deek Inkey Ticks
' I/O       Print ; ,   Input ["prompt";] v   Cls  Locate x,y  Mode n  Frame
' memory    Poke a,v  Doke a,v  Randomize [n]  Call addr (machine code)
' turbo     Option Turbo / Turbo On / Turbo Off - turbo = SP is the thread,
'           interrupts off. Normal = interrupts on between keywords
' classes   a .cls file: methods and properties, obj.Method, Class.Member
' debug     Break name - puts dw bp_name in the thread
' comments  Rem or '

Option Explicit
Dim nm As String, i As Integer

Cls
Input "Your name"; nm
Print "Hello " & nm
For i = 1 To 10
  If i Mod 3 = 0 Then Print "fizz "; Else Print i; " ";
Next
Print
Print Shout(nm)
Break done
End

Function Shout(ByVal s As String) As String
  Shout = UCase$(s) & "!"
End Function

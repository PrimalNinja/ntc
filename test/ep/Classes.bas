' the ep128 platform's classes (test/epregress.sh): System, Memory (every segment the machine
' has, as a page), Keys. The answers depend on the machine's RAM and on the test's key script.
Option Explicit
Option Memory Heap Pages
Dim n As Integer, pg As Integer, a As Integer, i As Integer, count As Integer, bad As Integer
Dim t As Integer, p As Long

Print "plat "; System.Platform; " hz"; System.FrameRate; " segs"; System.Segments()
Print "own"; System.Segment(0) > 0; System.Segment(1) > 0; System.Segment(2) > 0; " screen"; System.Segment(3) >= 252; " none"; System.Segment(4)
n = Memory.Pages()
Print "pages"; n; " free"; Memory.FreePages(); " ram"; Memory.RamSize(); " banks"; Memory.Banks()

' every free page taken and marked with its own number, at both ends
count = 0
Do
    pg = Memory.AllocPage(Memory.TypeUser)
    If pg < 1 Then Exit Do
    a = Memory.SelectPage(pg)
    Poke a, pg And 255
    Poke a + 1, pg \ 256
    Poke a + &H3FFF, (pg * 7) And 255
    count = count + 1
Loop
' ... and read back: a segment that was two pages would have the later number
bad = 0
For pg = 1 To n
    If Memory.PageType(pg) = Memory.TypeUser Then
        a = Memory.SelectPage(pg)
        If Peek(a) <> (pg And 255) Or Peek(a + 1) <> (pg \ 256) Or Peek(a + &H3FFF) <> ((pg * 7) And 255) Then bad = bad + 1
    End If
Next pg
a = Memory.SelectPage(1)
Print "taken"; count; " bad"; bad; " free"; Memory.FreePages()
' the heap: with every page taken there is no room; with one given back there is
p = Memory.Alloc(1000)
Print "alloc"; p <> 0;
a = Memory.FreePage(n - (n - 1 - System.Segments()) )
p = Memory.Alloc(1000)
Print p <> 0; " page"; Memory.PageOf(p) > 0
Memory.WriteWord p, 12345
Print "word"; Memory.ReadWord(p)

' the clock: 50 a second (the frame interrupt), counted while 25 frames go by
t = System.Ticks()
For i = 1 To 25
    Frame
Next i
t = System.Ticks() - t
Print "ticks"; t >= 24 And t <= 27

' the joystick and a key: idle now; then up to 12 seconds for either to be held (the test's script)
Print "joy"; Keys.Joystick(0); Keys.Joystick(1); Keys.Joystick(2); " key"; Keys.Down(Keys.KeyQ)
For i = 1 To 600
    If Keys.Joystick(0) <> 0 Or Keys.Joystick(1) <> 0 Or Keys.Joystick(2) <> 0 Or Keys.Down(Keys.KeyQ) Then Exit For
    If (i Mod 50) = 0 Then Print ".";
    Frame
Next i
Frame
Print
Print "joy"; Keys.Joystick(0); Keys.Joystick(1); Keys.Joystick(2); " key"; Keys.Down(Keys.KeyQ)
Print "end"
End

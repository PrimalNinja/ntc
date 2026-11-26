' Classes.bas - the Amiga's library classes (System, Memory, Keys, Loader): each call made once;
' what can be read back is printed (test/amigaregress.sh checks the transcript).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Dim a As Long, b As Long, c As Long, n As Long, i As Integer, sum As Long
Dim buf As Long

Print "hz"; System.Hz(); " chip"; System.ChipRam(); " other"; System.OtherRam()
a = Memory.Alloc(1000)
b = Memory.Alloc(1000)
Print "alloc"; b - a
c = Memory.AllocOther(4096)
If c <> 0 Then Print "other block ok" Else Print "no other block"
c = Memory.AllocAny(4096)
If c <> 0 Then Print "any block ok" Else Print "any BAD"
If Memory.Free() > 100000 Then Print "free ok" Else Print "free BAD"
If Memory.Alloc(8000000) = 0 Then Print "too much ok" Else Print "too much BAD"
Print "drives"; Loader.Drives()

' the files: a short one, one of several tracks, one that is not there
buf = Memory.AllocAny(70000)
Print "size"; Loader.Size("hello.txt"); Loader.Size("BIG"); Loader.Size("NOPE")
n = Loader.Load("HELLO.TXT", buf, 70000)
Print "hello"; n; " ";
#asm
            NTC_RS
            movea.l {buf}, a2
            moveq #11, d3
cl_p:
            move.b (a2)+, d0
            jsr ntc_plat_putc
            dbra d3, cl_p
            jsr ntc_plat_newline
            NTC_TS
#endasm
n = Loader.Load("BIG", buf, 70000)
sum = 0
#asm
            movea.l {buf}, a0
            move.l {n}, d1
            moveq #0, d0
            moveq #0, d2
cl_s:
            move.b (a0)+, d2
            add.l d2, d0
            subq.l #1, d1
            bne cl_s
            move.l d0, {sum}
#endasm
Print "big"; n; sum
Print "small"; Loader.Load("BIG", buf, 100)
Print "nope"; Loader.Load("NOPE", buf, 70000)
Print "disc"; Loader.Disc("BIG"); Loader.Disc("TWO"); Loader.Drive(1)
' a file on the second disc: asked for until its disc is in a drive
n = Loader.Load("TWO", buf, 70000)
If n = Loader.WrongDisc Then
    Print "insert disc"; Loader.Wanted()
    i = 0
    Do While Loader.Drive(2) < 0
        Frame
        i = i + 1
        If i > 1500 Then Exit Do
    Loop
    n = Loader.Load("TWO", buf, 70000)
End If
sum = 0
If n > 0 Then
#asm
            movea.l {buf}, a0
            move.l {n}, d1
            moveq #0, d0
            moveq #0, d2
cl_t:
            move.b (a0)+, d2
            add.l d2, d0
            subq.l #1, d1
            bne cl_t
            move.l d0, {sum}
#endasm
End If
Print "two"; n; sum; " in drive"; Loader.Drive(2)
' the joystick and a key: idle now; then up to 12 seconds for either to be held (the test's script)
Print "joy"; Keys.Joystick(0); " key"; Keys.Down(Keys.KeyQ)
For i = 1 To 600
    If Keys.Joystick(0) <> 0 Or Keys.Down(Keys.KeyQ) Then Exit For
    If (i Mod 50) = 0 Then Print ".";
    Frame
Next i
Frame
Print
Print "joy"; Keys.Joystick(0); Keys.Joystick(1); " key"; Keys.Down(Keys.KeyQ)
Print "end"

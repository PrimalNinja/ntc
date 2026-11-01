' an inline #asm block that pushes while SP is the thread: the compiler must warn (regress.sh). Run, it
' prints pushy7 once and then pushy0: the push wrote over the thread words already run
Dim i As Integer, r As Integer
For i = 1 To 3
  r = Pushy()
  Print "pushy"; r
Next
Function Pushy() As Integer
#asm
            ld hl, 7
            push hl
            pop de
            ld ({result}), de
#endasm
End Function

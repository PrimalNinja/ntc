' C64 + REU: 20 tasks, one a screen line. Each moves its own letter along its own line - the
' odd lines to the right, the even lines to the left - at its own speed, and sleeps between
' steps. The main program is a 21st: it counts the frames at the bottom.
' Every task is the same Sub: which line, which letter and where it is come from Task.Id().
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Dim col(31) As Integer          ' each task's column
Dim i As Integer, id As Integer

Sub Mover()
  Dim me As Integer, row As Integer
  Do
    me = Task.Id()              ' (asked again after every sleep: locals are shared)
    row = &HE000 + (me - 1) * 40
    Poke row + col(me), 32
    If me And 1 Then
      col(me) = col(me) + 1
      If col(me) > 39 Then col(me) = 0
    Else
      col(me) = col(me) - 1
      If col(me) < 0 Then col(me) = 39
    End If
    Poke row + col(me), 64 + me
    Poke row + col(me) - &H0800, 1 + (me And 7)     ' its colour (colour RAM is &HD800)
    Task.Sleep 1 + (me And 3)
  Loop
End Sub

Cls
For i = 1 To 20
  id = Task.Start(AddressOf Mover)
  col(id) = (id * 7) Mod 40
Next
Locate 1, 22
Print "20 tasks, each one place in the thread"
Print "(two bytes). pieces of program: "; System.Pieces()
Do
  Locate 1, 25
  Print "frame "; Ticks; "  tasks "; Task.Count();
  Task.Sleep 5
Loop

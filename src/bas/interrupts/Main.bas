' Interrupts: classes whose Tick Sub runs at a rate (Option Class Interrupt), while the main
' program does its own thing. Up to 4 such classes. Normal mode, cpc or cpcmin (they need
' NTC's own interrupt handler).
Option Explicit
Dim loops As Long

Cls
Locate 1, 3 : Print "Clock: a Tick once a second"
Locate 1, 4 : Print "Star: a Tick every frame (50 a second)"
Locate 1, 8 : Print "Press a key to stop"
Do While Inkey <> 0 : Loop
Do
  loops = loops + 1
  Locate 1, 6 : Print "Main loop: "; loops;
Loop Until Inkey <> 0
Locate 1, 10
Print "Clock ticked "; Clock.Seconds; " times, the star "; Star.Moves
End

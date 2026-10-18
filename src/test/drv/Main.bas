' A class in a page with a Tick (a "driver": Option Page + Option Class Interrupt) - regress.sh
Option Page "DRV" = Drv
Option RomEnable 7
Option Reserve &H4000, &H4000
Option Turbo Off
Dim t As Integer, c As Integer, d As Integer
c = Drv.Count()
t = Ticks
Do : Loop Until Ticks - t >= 300
d = Drv.Count() - c
Print "ticks in a second: "; IIf(d >= 47 And d <= 52, "about 50", Str$(d))
Print "page "; Drv.Page()

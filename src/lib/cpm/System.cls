' System - what this machine is. NTC platform class: CP/M (BDOS console)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "CP/M"
Public Const CpuClock = 0           ' kHz, 0 = not known
Public Const TicksPerSecond = 0         ' Ticks rate, 0 = no clock
Public Const FrameRate = 0              ' screen frames a second, 0 = not known
Public Const HasInterrupts = True       ' normal mode lets interrupts in
Public Const HasHook = False             ' the Interrupt statement works
#If NTC_TERM_POS Then
Public Const HasScreen = True            ' a screen with rows and columns (Option Terminal)
#Else
Public Const HasScreen = False           ' a screen with rows and columns (not a stream)
#End If
Public Const HasKeyboard = True
Public Const MaxHandles = 0             ' file handles (no file devices yet)

' the tick count (the same as Ticks)
Public Function Ticks() As Integer
#asm
            pop hl
            ld (ntc_ivar), hl
            ld ix, got
            jp ntc_plat_ticks
got:
            ex de, hl
            ld hl, (ntc_ivar)
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

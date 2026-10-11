' System - what this machine is. NTC platform class: Amstrad CPC (direct hardware)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "CPC"
Public Const CpuClock = 4000           ' kHz, 0 = not known
Public Const TicksPerSecond = 300         ' Ticks rate, 0 = no clock
Public Const FrameRate = 50              ' screen frames a second, 0 = not known
Public Const HasInterrupts = True       ' normal mode lets interrupts in
Public Const HasHook = True             ' the Interrupt statement works
Public Const HasScreen = True           ' a screen with rows and columns (not a stream)
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

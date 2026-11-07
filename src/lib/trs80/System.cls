' System - what this machine is. NTC platform class: TRS-80 Model III (direct video)
' The same members on every platform; 0 / False = not on this machine.
' DRAFT: compiles + assembles (Z80); not run on a Model III / emulator. Grounded
' from Julian's TRS-80 hardware notes; points marked (check) are '!!TRS in the asm.
Public Const Platform = "TRS80"
Public Const CpuClock = 2030           ' kHz (Model III Z80 @ 2.03 MHz)
Public Const TicksPerSecond = 30        ' the 30Hz real-time clock, counted by Frame
Public Const FrameRate = 30
Public Const HasInterrupts = False      ' turbo-only: startup masks E0 (and E4 NMI)
Public Const HasHook = False            ' no Interrupt hook (clock not wired to a handler)
Public Const HasScreen = True           ' direct video #3C00, 64 x 16
Public Const HasKeyboard = True         ' matrix at #3800
Public Const MaxHandles = 0             ' no file devices yet (disk is poll/NMI, future)

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

' Command(name): a ROM's command - not on the TRS-80
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0).
' SCREEN, KEYBOARD and CLOCK (Frame counts the 30Hz tick) are on.
Public Function HasCapability(ByVal name As String) As Integer
#asm
            pop hl
            pop de
            ld bc, caps
            jp ntc_capfind
caps:
            db "SCREEN", 0
            dw -1
            db "KEYBOARD", 0
            dw -1
            db "CLOCK", 0
            dw -1
            db 0
#endasm
End Function

' CommandLine(): a /CMD launch passes no tail - always "" (COMMANDLINE cap off)
Public Function CommandLine() As String
    CommandLine = ""
End Function

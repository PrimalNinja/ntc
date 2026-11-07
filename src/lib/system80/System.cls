' System - what this machine is. NTC platform class: Dick Smith System 80 / Video Genie
' A TRS-80 Model I clone; same console/keyboard as trs80, differs in clock + startup.
' DRAFT: compiles + assembles (Z80); not run on a System 80 / emulator. '!!S80 in the asm.
Public Const Platform = "SYS80"
Public Const CpuClock = 1770           ' kHz (Model I / System 80 Z80 @ ~1.77 MHz)
Public Const TicksPerSecond = 0         ' the Model I 40Hz heartbeat (#37E0) not wired '!!S80
Public Const FrameRate = 0
Public Const HasInterrupts = False      ' di-only startup; nothing enabled
Public Const HasHook = False
Public Const HasScreen = True           ' direct video #3C00, 64 x 16 (Model I)
Public Const HasKeyboard = True         ' matrix at #3800 (Model I)
Public Const MaxHandles = 0             ' no file devices yet

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

' Command(name): a ROM's command - not on the System 80
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0).
' SCREEN and KEYBOARD on; CLOCK off (the Model I heartbeat isn't wired).
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
            db 0
#endasm
End Function

' CommandLine(): a /CMD launch passes no tail - always "" (COMMANDLINE cap off)
Public Function CommandLine() As String
    CommandLine = ""
End Function

' System - what this machine is. NTC platform class: TI-89 / 92+ / V200 (68000, AMS)
' The same members on every platform; 0 / False = not on this machine.
' SKELETON: compiles (68k) but UNVERIFIED - no 68k assembler / TI-68k emulator in
' the build box, and the AMS hardware values in ntc_plat_ti89.asm are guesses ('!!TI89?).
Public Const Platform = "TI89"
Public Const CpuClock = 10000          ' kHz (68000 ~10-12 MHz)
Public Const TicksPerSecond = 0         ' AMS timer not wired yet '!!TI89?
Public Const FrameRate = 0
Public Const HasInterrupts = True       ' AMS interrupts run on the supervisor stack
Public Const HasHook = False
Public Const HasScreen = True           ' mono LCD, 8x8 text cells (direct bitmap)
Public Const HasKeyboard = True         ' keypad (scankey stubbed until the port is wired)
Public Const MaxHandles = 0             ' no file devices yet

' the tick count: frames since start (ntc_frames in ntc_plat_ti89.asm)
Public Function Ticks() As Integer
#asm
            movea.l (sp)+, a0
            move.w ntc_frames, (a0)
#endasm
End Function

' Command(name): a ROM's command - not on AMS
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0).
' SCREEN and KEYBOARD on; CLOCK off (no timer wired).
Public Function HasCapability(ByVal name As String) As Integer
#asm
            movea.l (sp)+, a0
            movea.l (sp)+, a1
            lea caps, a2
            bra ntc_capfind
caps:
            dc.b "SCREEN", 0
            even
            dc.w -1
            dc.b "KEYBOARD", 0
            even
            dc.w -1
            dc.b 0
            even
#endasm
End Function

' CommandLine(): "" (an AMS program has no command line)
Public Function CommandLine() As String
    CommandLine = ""
End Function

' System - what this machine is. NTC platform class: Bare Metal (fill in)
' The same members on every platform; 0 / False = not on this machine.

' Nothing is known about the machine until the platform is filled in: every constant says
' so (change them as you fill the platform routines in - asm/ntc_plat_baremetal.asm)
Public Const Platform = "Bare Metal"
Public Const CpuClock = 0           ' kHz, 0 = not known
Public Const TicksPerSecond = 0         ' Ticks rate, 0 = no clock (ntc_plat_ticks)
Public Const FrameRate = 0              ' screen frames a second, 0 = not known
Public Const HasInterrupts = False      ' normal mode lets interrupts in (no handler at #0038 yet)
Public Const HasHook = False             ' the Interrupt statement works
Public Const HasScreen = False          ' a screen with rows and columns (ntc_plat_putc ...)
Public Const HasKeyboard = False        ' (ntc_plat_scankey, ntc_plat_getkey)
Public Const MaxHandles = 0             ' file handles (no file devices)

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

' Command(name): a ROM's command (|NAME) - only on the CPC firmware platforms (cpcfw, cpcmin)
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0). The names:
' COMMANDLINE (System.CommandLine has the command tail), SCREEN (rows and columns, not a
' stream), KEYBOARD, CLOCK (Ticks counts), HOOK (the Interrupt statement), INTERRUPTCLASSES
' (Option Class Interrupt), PAGES (RAM pages with Option Memory CPCExpansion), FILES
' (FileSystem Load / Save ...), ROMCOMMANDS (System.Command), OVERLAYS (Option Class Overlay)
Public Function HasCapability(ByVal name As String) As Integer
#asm
            pop hl
            pop de
            ld bc, caps
            jp ntc_capfind
caps:       db 0                ; (none yet: add "SCREEN", 0 / dw -1 and so on as they are filled in)
#endasm
End Function

' CommandLine(): what was typed after the program's name - "" here (no command line:
' HasCapability("COMMANDLINE") is False)
Public Function CommandLine() As String
    CommandLine = ""
End Function

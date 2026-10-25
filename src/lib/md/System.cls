' System - what this machine is. NTC platform class: Sega Mega Drive / Genesis (68000, direct hardware)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "MD"
Public Const CpuClock = 7670           ' kHz (7.67 MHz NTSC, 7.60 PAL), 0 = not known
Public Const TicksPerSecond = 60        ' Ticks rate: a tick a frame (50 on a PAL machine)
Public Const FrameRate = 60             ' screen frames a second (50 on a PAL machine)
Public Const HasInterrupts = True       ' the frame interrupt runs all the time (its own stack)
Public Const HasHook = False            ' the Interrupt statement works (not yet on the 68000)
Public Const HasScreen = True           ' a screen with rows and columns (not a stream)
Public Const HasKeyboard = False        ' pads only (Inkey / Input read pad 1)
Public Const MaxHandles = 0             ' file handles (no file devices)

' the tick count (the same as Ticks): frames since the start
Public Function Ticks() As Integer
#asm
            movea.l (sp)+, a0
            move.w ntc_ticks, (a0)
#endasm
End Function

' Command(name): a ROM's command (|NAME) - only on the CPC firmware platforms (cpcfw, cpcmin)
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0). The names:
' COMMANDLINE, SCREEN, KEYBOARD, CLOCK (Ticks counts), HOOK (the Interrupt statement),
' INTERRUPTCLASSES (Option Class Interrupt), PAGES, FILES, ROMCOMMANDS, OVERLAYS
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
            dc.b "CLOCK", 0
            even
            dc.w -1
            dc.b 0
            even
#endasm
End Function

' CommandLine(): what was typed after the program's name - "" here (no command line)
Public Function CommandLine() As String
    CommandLine = ""
End Function

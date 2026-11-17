' System - what this machine is. NTC platform class: Sharp X68000 (68000, boot disc)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "X68000"
Public Const CpuClock = 10000          ' kHz (10 MHz; 16 MHz on the XVI), 0 = not known
Public Const TicksPerSecond = 55        ' Ticks rate: a tick a frame (55.5 on the 768 x 512 screen)
Public Const FrameRate = 55             ' screen frames a second (the 768 x 512 screen)
Public Const HasInterrupts = True       ' the frame interrupt runs all the time (its own stack)
Public Const HasHook = False            ' the Interrupt statement works (not yet on the 68000)
Public Const HasScreen = True           ' a screen with rows and columns (not a stream)
Public Const HasKeyboard = True         ' the keyboard (the ROM's key calls)
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
            dc.b "KEYBOARD", 0
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

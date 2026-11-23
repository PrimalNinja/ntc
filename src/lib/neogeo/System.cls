' System - what this machine is. NTC platform class: SNK Neo Geo (68000, cartridge: AES / MVS)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "NEOGEO"
Public Const CpuClock = 12000          ' kHz (12 MHz), 0 = not known
Public Const TicksPerSecond = 59        ' Ticks rate: a tick a frame (59.19 a second)
Public Const FrameRate = 59             ' screen frames a second (59.19)
Public Const HasInterrupts = True       ' the VBlank interrupt runs all the time (the supervisor stack)
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

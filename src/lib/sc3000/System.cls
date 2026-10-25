' System - what this machine is. NTC platform class: Sega SC-3000 (cartridge)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "SC-3000"
Public Const CpuClock = 3580           ' kHz, 0 = not known
Public Const TicksPerSecond = 50          ' Ticks rate (the frames: 60 on an NTSC machine), 0 = no clock
Public Const FrameRate = 50             ' screen frames a second (60 on an NTSC machine), 0 = not known
Public Const HasInterrupts = True       ' normal mode lets interrupts in
Public Const HasHook = True              ' the Interrupt statement works
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
caps:               ; @const (a cartridge keeps the table in the ROM)
            db "SCREEN", 0
            dw -1
            db "KEYBOARD", 0
            dw -1
            db "CLOCK", 0
            dw -1
            db "HOOK", 0
            dw -1
            db "INTERRUPTCLASSES", 0
            dw -1
            db 0
#endasm
End Function

' CommandLine(): what was typed after the program's name - "" here (no command line:
' HasCapability("COMMANDLINE") is False)
Public Function CommandLine() As String
    CommandLine = ""
End Function

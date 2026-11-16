' System - what this machine is. NTC platform class: ZX Spectrum Next dot commands, the Large
' Model (zxndotl: 32K at #8000 and the Memory class's banks, BASIC's screen)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "ZXNDOTL"
Public Const CpuClock = 3500        ' kHz, 0 = not known (as NextZXOS runs BASIC: the command does not change it)
Public Const TicksPerSecond = 50        ' Ticks rate, 0 = no clock (the ROM's FRAMES)
Public Const FrameRate = 50             ' screen frames a second, 0 = not known
Public Const HasInterrupts = False      ' normal mode lets interrupts in (not here: BASIC's handler stays off while the command runs)
Public Const HasHook = False             ' the Interrupt statement works
Public Const HasScreen = True            ' a screen with rows and columns (BASIC's, through the ROM)
Public Const HasKeyboard = True
Public Const MaxHandles = 0             ' file handles (no FileSystem class on this platform yet)

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
' (Option Class Interrupt), PAGES (RAM pages with Option Memory Heap Pages), FILES
' (FileSystem Load / Save ...), ROMCOMMANDS (System.Command), OVERLAYS (Option Class Overlay)
Public Function HasCapability(ByVal name As String) As Integer
#asm
            pop hl
            pop de
            ld bc, caps
            jp ntc_capfind
caps:
            db "COMMANDLINE", 0
            dw -1
            db "KEYBOARD", 0
            dw -1
            db "CLOCK", 0
            dw -1
            db "SCREEN", 0
            dw -1
            db "PAGES", 0
            dw -1
            db 0
#endasm
End Function

' CommandLine(): what was typed after the command's name (.name FILE.TXT gives "FILE.TXT";
' as typed - up to 127 characters, to the end of the line, a ':' outside quotes, or Enter)
Public Function CommandLine() As String
#asm
            pop hl
            jp ntc_cmdget
#endasm
End Function

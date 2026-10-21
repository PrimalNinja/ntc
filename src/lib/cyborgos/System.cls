' System - what this machine is. NTC platform class: CyborgOS (a slot: CP/M 2.2 and the hypervisor)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "CyborgOS"
Public Const CpuClock = 0           ' kHz, 0 = not known
Public Const TicksPerSecond = 0         ' Ticks rate, 0 = no clock
Public Const FrameRate = 0              ' screen frames a second, 0 = not known
Public Const HasInterrupts = True       ' normal mode lets interrupts in
Public Const HasHook = False             ' the Interrupt statement works
Public Const HasScreen = True            ' CyborgOS's console: 80 columns, VT52 codes (Option Terminal VT52 is the default)

Public Const HasKeyboard = True
Public Const MaxHandles = 2             ' file handles (FileSystem.Open)

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
' (FileSystem Load / Save ...), ROMCOMMANDS (System.Command), OVERLAYS (Option Class Overlay),
' CYBORGOS (the hypervisor's services: CybSys)
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
            db "FILES", 0
            dw -1
            db "OVERLAYS", 0
            dw -1
            db "SCREEN", 0
            dw -1
            db "CYBORGOS", 0
            dw -1
            db 0
#endasm
End Function

' CommandLine(): what was typed after the program's name (A>PROG FILE.TXT gives "FILE.TXT";
' CP/M makes it capitals)
Public Function CommandLine() As String
#asm
            pop hl
            jp ntc_cmdget
#endasm
End Function

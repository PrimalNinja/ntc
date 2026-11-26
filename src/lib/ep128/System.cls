' System - what this machine is. NTC platform class: Enterprise 128 (direct hardware)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "EP128"
Public Const CpuClock = 4000           ' kHz, 0 = not known
Public Const TicksPerSecond = 50          ' Ticks rate, 0 = no clock (Nick's frame interrupt)
Public Const FrameRate = 50              ' screen frames a second, 0 = not known
Public Const HasInterrupts = True       ' normal mode lets interrupts in
Public Const HasHook = True             ' the Interrupt statement works
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

' Command(name): a ROM's command - only on the CPC firmware platforms (cpcfw, cpcmin)
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
            db "PAGES", 0
            dw -1
            db 0
#endasm
End Function

' CommandLine(): what was typed after the program's name - "" here (no command line:
' HasCapability("COMMANDLINE") is False)
Public Function CommandLine() As String
    CommandLine = ""
End Function

' Segments(): the free 16K segments the program was given at its start (the Memory class's
' pages with Option Memory Heap Pages; the program's own three and the screen's not counted)
Public Function Segments() As Integer
#asm
            pop hl
            ld a, (ep_nseg)
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

' Segment(page): the segment in the Z80's page 0-3 now (0 #0000-#3FFF ... 3 #C000-#FFFF: Dave's
' ports #B0-#B3 read back); -1 for any other number
Public Function Segment(ByVal page As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl
            ld a, d
            or a
            jr nz, bad
            ld a, e
            cp 4
            jr nc, bad
            add a, #B0
            ld c, a
            in a, (c)
            ld (hl), a
            inc hl
            ld (hl), 0
            jr done
bad:
            ld (hl), #FF
            inc hl
            ld (hl), #FF
done:
#endasm
End Function

' System - what this machine is. NTC platform class: MEGA65 (45GS02, direct hardware)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "M65"
Public Const CpuClock = 40500          ' kHz (40.5 MHz), 0 = not known
Public Const TicksPerSecond = 50        ' Ticks rate: a tick a frame (60 on an NTSC screen)
Public Const FrameRate = 50             ' screen frames a second (60 on an NTSC screen)
Public Const HasInterrupts = False      ' interrupts are off (they would write into the thread)
Public Const HasHook = False            ' the Interrupt statement works (not on the MEGA65)
Public Const HasScreen = True           ' a screen with rows and columns (not a stream)
Public Const HasKeyboard = True         ' the MEGA65's keyboard
Public Const MaxHandles = 0             ' file handles (no file devices yet)

' the tick count (the same as Ticks): frames since the start
Public Function Ticks() As Integer
#asm
            NTC_POP z_p2
            NTC_RS
            jsr ntc_plat_ticks
            sta z_t0
            stx z_t1
            NTC_TS
            ldy #0
            lda z_t0
            sta (z_p2),y
            iny
            lda z_t1
            sta (z_p2),y
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
            NTC_POP z_p0
            NTC_POP z_p1
            lda #<caps
            sta z_p2
            lda #>caps
            sta z_p2+1
            jmp ntc_capfind
caps:
            db "SCREEN", 0
            dw -1
            db "KEYBOARD", 0
            dw -1
            db "CLOCK", 0
            dw -1
            db 0
#endasm
End Function

' CommandLine(): what was typed after the program's name - "" here (no command line)
Public Function CommandLine() As String
    CommandLine = ""
End Function

' System - what this machine is. NTC platform class: Commodore 64 with an REU (6502, direct hardware)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "C64REU"
Public Const CpuClock = 985             ' kHz (PAL: 985, NTSC: 1023), 0 = not known
Public Const TicksPerSecond = 50        ' Ticks rate: a tick a frame (60 on an NTSC machine)
Public Const FrameRate = 50             ' screen frames a second (60 on an NTSC machine)
Public Const HasInterrupts = True       ' the frame's interrupt runs (Ticks, the frame hook)
Public Const HasHook = False            ' the Interrupt statement works (not here: FrameHook takes machine code)
Public Const HasScreen = True           ' a screen with rows and columns (not a stream)
Public Const HasKeyboard = True         ' the C64's keyboard
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

' FrameHook addr: machine code at addr is called every frame from the interrupt (jsr; it ends
' with rts and may use A, X, Y and about 16 bytes of stack). 0 = no hook. A music player's
' "play" routine goes here: it carries on while the program runs.
Public Sub FrameHook(ByVal addr As Integer)
#asm
            NTC_POP z_p0
            sei
            ldy #0
            lda (z_p0),y
            sta ntc_c64_hook
            iny
            lda (z_p0),y
            sta ntc_c64_hook+1
            cli
#endasm
End Sub

' Pieces(): how many 64 byte pieces of thread the program is (in the REU)
Public Function Pieces() As Integer
#asm
            NTC_POP z_p0
            ldy #0
            lda #<((ntc_thr_to-ntc_thr_from)/64)
            sta (z_p0),y
            iny
            lda #>((ntc_thr_to-ntc_thr_from)/64)
            sta (z_p0),y
#endasm
End Function

' Lots(): how many 96K lots the REU has room for after the kernel's 32K (Option Lot's code
' lots first, the rest for data): 5 on a 512K REU, 21 on 2 MB, 174 on 16 MB
Public Function Lots() As Integer
    Lots = (Reu.Banks() * 64 - 32) \ 96
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

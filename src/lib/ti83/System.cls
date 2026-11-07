' System - what this machine is. NTC platform class: TI-83 Plus / 84 Plus (TI-OS)
' The same members on every platform; 0 / False = not on this machine.
' DRAFT: assembles (Z80). bcall addresses are the standard ti83plus.inc values
' but unconfirmed in this box ('!!TI in the platform asm). Not run on a calc.
Public Const Platform = "TI83"
Public Const CpuClock = 6000           ' kHz (83+ ~6 MHz; 84+ clocks faster)
Public Const TicksPerSecond = 0         ' 83+ has no RTC (84+ crystal timer not wired yet) '!!TI
Public Const FrameRate = 0              ' the OS owns the LCD - not known
Public Const HasInterrupts = False      ' TI-OS owns the interrupt; NTC runs normal mode
Public Const HasHook = False            ' the Interrupt statement: not on TI-OS
Public Const HasScreen = True           ' large-font homescreen, 16 x 8 (_PutC / _PutS)
Public Const HasKeyboard = True         ' _GetCSC / _GetKey (ntc_plat_scankey / getkey)
Public Const MaxHandles = 0             ' file handles: 0 until a FileSystem (var/appvar) is added

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

' Command(name): a ROM's command - not on TI-OS
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0).
' CLOCK is off (no RTC on the 83+); SCREEN and KEYBOARD are on.
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
            db 0
#endasm
End Function

' CommandLine(): an Asm( launch passes no tail - always "" (COMMANDLINE cap off)
Public Function CommandLine() As String
    CommandLine = ""
End Function

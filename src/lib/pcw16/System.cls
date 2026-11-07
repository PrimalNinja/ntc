' System - what this machine is. NTC platform class: Amstrad PcW16 (Rosanne app)
' The same members on every platform; 0 / False = not on this machine.
' DRAFT: values from the documented machine; TicksPerSecond needs XAnne confirmation.
Public Const Platform = "PcW16"
Public Const CpuClock = 16000          ' kHz (16 MHz Z80)
Public Const TicksPerSecond = 16        ' bios_gettime ticks are sixteenths of a second  '!!XANNE confirm
Public Const FrameRate = 0              ' Rosanne owns the display - not known
Public Const HasInterrupts = False      ' Rosanne owns the interrupt; NTC runs normal mode without a handler
Public Const HasHook = False            ' the Interrupt statement: not on a Rosanne app
Public Const HasScreen = True           ' a windowed text console (ntc_plat_putc / os_scr_direct)
Public Const HasKeyboard = True         ' bios_keystate (ntc_plat_scankey / getkey)
Public Const MaxHandles = 0             ' file handles: 0 until ntc_plat_fs (FileSystem) is added

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

' Command(name): a ROM's command - not on a Rosanne app
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0)
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
            db 0
#endasm
End Function

' CommandLine(): a Rosanne app is launched by file - "" until app arguments are wired
' (HasCapability("COMMANDLINE") is False)
Public Function CommandLine() As String
    CommandLine = ""
End Function

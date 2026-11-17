' System - what this machine is. NTC platform class: Fujitsu FM Towns (80386, boot disc)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "TOWNS"
Public Const CpuClock = 16000          ' kHz (a 16 MHz 80386 on the first models), 0 = not known
Public Const TicksPerSecond = 60        ' Ticks rate: a tick a frame
Public Const FrameRate = 60             ' screen frames a second
Public Const HasInterrupts = True       ' the frame interrupt runs all the time (its own stack)
Public Const HasHook = False            ' the Interrupt statement works (not yet on this platform)
Public Const HasScreen = True           ' a screen with rows and columns (not a stream)
Public Const HasKeyboard = True         ' the keyboard, read at its ports
Public Const MaxHandles = 0             ' file handles (no file devices)

' the tick count (the same as Ticks): frames since the start
Public Function Ticks() As Integer
#asm
            pop esi
            mov ax, [ntc_ticks]
            mov [esi], ax
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
            pop esi
            pop edi
            mov ebx, caps
            jmp ntc_capfind
caps:
            db "SCREEN", 0
            align 2, db 0
            dw -1
            db "CLOCK", 0
            align 2, db 0
            dw -1
            db "KEYBOARD", 0
            align 2, db 0
            dw -1
            db 0
            align 2, db 0
#endasm
End Function

' CommandLine(): what was typed after the program's name - "" here (no command line)
Public Function CommandLine() As String
    CommandLine = ""
End Function

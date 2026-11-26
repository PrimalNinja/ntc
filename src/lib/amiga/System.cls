' System - what this machine is. NTC platform class: Commodore Amiga 500 (68000, boot disc)
' The same members on every platform; 0 / False = not on this machine.

Public Const Platform = "AMIGA"
Public Const CpuClock = 7093           ' kHz (7.09 MHz PAL, 7.16 MHz NTSC), 0 = not known
Public Const TicksPerSecond = 50        ' Ticks rate: a tick a frame (PAL; an NTSC machine: 60 - System.Hz() says)
Public Const FrameRate = 50             ' screen frames a second (PAL; System.Hz() says which)
Public Const HasInterrupts = True       ' the frame interrupt runs all the time (its own stack)
Public Const HasHook = False            ' the Interrupt statement works (not yet on the 68000)
Public Const HasScreen = True           ' a screen with rows and columns (not a stream)
Public Const HasKeyboard = True         ' the keyboard (through CIA-A)
Public Const MaxHandles = 0             ' file handles (no file devices: the Loader class reads the disc's files whole)

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
            dc.b "KEYBOARD", 0
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

' ---- this Amiga
' Hz(): frames a second - 50 (PAL) or 60 (NTSC)
Public Function Hz() As Integer
#asm
            movea.l (sp)+, a0
            moveq #0, d0
            move.b ntc_ami_hz, d0
            move.w d0, (a0)
#endasm
End Function

' ChipRam(): chip RAM in K (512, 1024 or 2048): what the custom chips can show and play
Public Function ChipRam() As Integer
#asm
            movea.l (sp)+, a0
            move.l ntc_ami_chip, d0
            lsr.l #8, d0
            lsr.l #2, d0
            move.w d0, (a0)
#endasm
End Function

' OtherRam(): the other RAM in K (0 when there is none): a trapdoor's "slow" RAM, "fast" RAM
Public Function OtherRam() As Integer
#asm
            movea.l (sp)+, a0
            moveq #0, d0
            tst.l ntc_ami_o1
            beq no1
            move.l ntc_ami_o1e, d0
            sub.l ntc_ami_o1, d0
no1:
            tst.l ntc_ami_o2
            beq no2
            add.l ntc_ami_o2e, d0
            sub.l ntc_ami_o2, d0
no2:
            addi.l #1023, d0
            lsr.l #8, d0
            lsr.l #2, d0
            move.w d0, (a0)
#endasm
End Function

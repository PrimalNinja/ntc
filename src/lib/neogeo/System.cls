' System - what this machine is. NTC platform class: SNK Neo Geo (68000)
' The same members on every platform; 0 / False = not on this machine.
' DRAFT: unverified on hardware (no 68k assembler / Neo Geo emulator in the build box).
Public Const Platform = "NEOGEO"
Public Const CpuClock = 12000          ' kHz (68000 at ~12 MHz)
Public Const TicksPerSecond = 60        ' a tick a frame (~60 Hz)
Public Const FrameRate = 60
Public Const HasInterrupts = True       ' the VBlank interrupt runs on the supervisor stack
Public Const HasHook = False
Public Const HasScreen = True           ' the fix layer (40x32 text tiles)
Public Const HasKeyboard = False        ' joysticks only (Inkey / Input read pad 1)
Public Const MaxHandles = 0             ' no file devices (cartridge)

' the tick count: frames since start (ntc_frames in ntc_plat_neogeo.asm)
Public Function Ticks() As Integer
#asm
            movea.l (sp)+, a0
            move.w ntc_frames, (a0)
#endasm
End Function

' Command(name): a ROM's command - not on the Neo Geo
Public Function Command(ByVal name As String) As Integer
    Command = -1
End Function

' HasCapability(name): True (-1) when this platform can do it, else False (0)
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
            dc.b "CLOCK", 0
            even
            dc.w -1
            dc.b 0
            even
#endasm
End Function

' CommandLine(): "" (a cartridge has no command line)
Public Function CommandLine() As String
    CommandLine = ""
End Function

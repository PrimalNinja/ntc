' Loader - loads a file from the game's discs. NTC platform class: Commodore Amiga 500
'
' The Amiga platform has no file system: test/amigabuild.js --file=NAME=path puts each file on
' the disc after the program (or on another disc of the set: @2 ...) and writes their list. This
' class reads the list and the files, working the drives itself: DF0, and DF1-DF3 when they are
' there. A file whose disc is in any drive is found there, so a two disc game with two drives
' never asks for a change.
'   n = Loader.Load("LEVEL1", buf, 65536)
'   If n = Loader.WrongDisc Then
'       Print "Insert disc"; Loader.Wanted()
'       Do While Loader.Drive(Loader.Wanted()) < 0 : Frame : Loop
'   End If
' A name is up to 15 characters, any case. Addresses and lengths are Longs: a file goes anywhere
' (a block from the Memory class: chip RAM for pictures and samples, other RAM for the rest).
' The first call reads the list from the boot disc in DF0. Each call leaves the motors off.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

' ---- what Load answers when it isn't a length (FileSystem's numbers on NTC's other machines)
Public Const OK = 0
Public Const NotSupported = -1    ' this platform can't
Public Const NotFound = -2        ' no file of that name in the list
Public Const BadName = -4
Public Const TooBig = -8          ' the file holds more than maxlen: nothing is loaded
Public Const Failed = -9          ' the disc would not read
Public Const WrongDisc = -10      ' the file's disc is not in a drive: Wanted() says which

' Load(name, address, maxlen): the file into memory. Its length, or a status
Public Function Load(ByVal name As String, ByVal addr As Long, ByVal maxlen As Long) As Long
#asm
            movea.l (sp)+, a0
            movea.l (sp)+, a1
            movea.l (a1), a1
            movea.l (sp)+, a2
            move.l (a2), d1
            NTC_RS
            jsr ntc_ami_fload
            NTC_TS
            movea.l (sp)+, a0
            move.l d0, (a0)
#endasm
End Function

' Size(name): the file's length, or NotFound / Failed
Public Function Size(ByVal name As String) As Long
#asm
            movea.l (sp)+, a0
            NTC_RS
            jsr ntc_ami_ffind
            tst.l d0
            bne done
            move.l 20(a1), d0
done:
            jsr ntc_ami_doff
            NTC_TS
            movea.l (sp)+, a0
            move.l d0, (a0)
#endasm
End Function

' Disc(name): the number of the disc the file is on (1 the boot disc), or 0 (no such file)
Public Function Disc(ByVal name As String) As Integer
#asm
            movea.l (sp)+, a0
            NTC_RS
            jsr ntc_ami_ffind
            tst.l d0
            beq found
            moveq #0, d0
            bra done
found:
            move.w 16(a1), d0
done:
            jsr ntc_ami_doff
            NTC_TS
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function

' Drive(disc): the drive (0-3: DF0-DF3) that disc of the set is in now, or -1 (in none). Each
' drive is looked at only when a disc has been put in since the last look.
Public Function Drive(ByVal disc As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            NTC_RS
            jsr ntc_ami_fdrive
            jsr ntc_ami_doff
            NTC_TS
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function

' Drives(): how many drives the Amiga has (1-4)
Public Function Drives() As Integer
#asm
            NTC_RS
            moveq #0, d2
            moveq #0, d3
dr_l:
            move.w d3, d0
            jsr ntc_ami_dprobe
            add.w d0, d2
            addq.w #1, d3
            cmpi.w #4, d3
            bcs dr_l
            NTC_TS
            movea.l (sp)+, a0
            move.w d2, (a0)
#endasm
End Function

' Wanted(): after Load answered WrongDisc: the disc it wants (else 0)
Public Function Wanted() As Integer
#asm
            movea.l (sp)+, a0
            move.w ntc_ami_fwant, (a0)
#endasm
End Function

' Read(drive, sector, address, bytes): sectors straight off a disc (880K: sectors 0-1759 of 512
' bytes), for a game that keeps its own layout. 0, or 1 no disc, 2 would not read. The motor is
' left on: MotorOff when done.
Public Function Read(ByVal drive As Integer, ByVal sector As Integer, ByVal addr As Long, ByVal bytes As Long) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d3
            movea.l (sp)+, a0
            moveq #0, d1
            move.w (a0), d1
            movea.l (sp)+, a0
            movea.l (a0), a1
            movea.l (sp)+, a0
            move.l (a0), d2
            NTC_RS
            move.w d3, d0
            movea.l a1, a0
            jsr ntc_ami_dread
            NTC_TS
            movea.l (sp)+, a0
            move.w d0, (a0)
#endasm
End Function

Public Sub MotorOff()
#asm
            NTC_RS
            jsr ntc_ami_doff
            NTC_TS
#endasm
End Sub

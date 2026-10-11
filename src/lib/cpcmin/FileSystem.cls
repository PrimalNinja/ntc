' FileSystem - files. NTC platform class: Amstrad CPC, minimal firmware - AMSDOS through the firmware
'
' This platform doesn't use the firmware, except here: each file call hands the machine back
' to the firmware for its length (its interrupts, its mode and ROM setting), then NTC takes it
' again (mode, ROMs, screen start, interrupt handler). The same calls as the cpcfw platform:
' Load / Save (CAS IN / OUT DIRECT), devices TAPE / DISC, volumes = AMSDOS commands (|A, |B,
' |C ...). Capability: LOAD, SAVE, DEVICES, VOLUMES (True), MAXOPEN 0; the rest NotSupported.
'
' Needs: AMSDOS running - RUN" of a binary drops it, so Option RomEnable 7 - and the
' firmware's RAM left alone (#A700-#BFFF: the program must end below #A600, checked when
' assembling; the stack stays the firmware's unless Option Stack moves it). While a file call
' runs, the screen may show the firmware's mode, and firmware messages (disc missing, Retry /
' Cancel, Press PLAY) appear on the screen. Uses a 2K buffer (CAS IN / OUT OPEN).

' ---- status
Public Const OK = 0
Public Const NotSupported = -1    ' this platform can't
Public Const NotFound = -2
Public Const Full = -3            ' disc or directory full, or a write failed
Public Const BadName = -4
Public Const NoHandle = -5        ' MAXOPEN files are open already
Public Const BadHandle = -6
Public Const EndOfFile = -7
Public Const TooBig = -8          ' Load: the file holds more than maxlen
Public Const Failed = -9
Public Const AlreadyExists = -10  ' Rename: the new name is taken
Public Const BadMode = -11        ' Open: mode not 1-3; writing to a file open for reading

' ---- Open modes
Public Const ForRead = 1          ' the file must be there
Public Const ForWrite = 2         ' a new file (an old one of that name is deleted)
Public Const ForUpdate = 3        ' read and write, Seek anywhere (made if not there)

' Capability("NAME"): the value, or 0 when this platform hasn't got it
Public Function Capability(ByVal name As String) As Integer
#asm
            pop hl
            pop de
            ld bc, caps
            jp ntc_capfind
caps:       db "LOAD", 0
            dw -1
            db "SAVE", 0
            dw -1
            db "DEVICES", 0
            dw -1
            db "VOLUMES", 0
            dw -1
            db "MAXOPEN", 0
            dw 0
            db 0
#endasm
End Function

' Load(name, address, maxlen): the file into memory. Its length, or a status
' (TooBig: longer than maxlen - nothing is loaded)
Public Function Load(ByVal name As String, ByVal addr As Integer, ByVal maxlen As Integer) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a2), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a3), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_load
            jp fs_go
#endasm
End Function

' Save(name, address, length): a binary file. OK or a status
Public Function Save(ByVal name As String, ByVal addr As Integer, ByVal length As Integer) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a2), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a3), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_save
            jp fs_go
#endasm
End Function

Public Function Delete(ByVal name As String) As Integer
    Delete = NotSupported
End Function

Public Function Exists(ByVal name As String) As Integer
    Exists = NotSupported
End Function

Public Function Rename(ByVal oldname As String, ByVal newname As String) As Integer
    Rename = NotSupported
End Function

Public Function Size(ByVal name As String) As Long
    Size = NotSupported
End Function

Public Function Open(ByVal name As String, ByVal mode As Integer) As Integer
    Open = NotSupported
End Function

Public Function Close(ByVal h As Integer) As Integer
    Close = NotSupported
End Function

Public Function ReadByte(ByVal h As Integer) As Integer
    ReadByte = NotSupported
End Function

Public Function WriteByte(ByVal h As Integer, ByVal b As Integer) As Integer
    WriteByte = NotSupported
End Function

Public Function Read(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
    Read = NotSupported
End Function

Public Function Write(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
    Write = NotSupported
End Function

Public Function Seek(ByVal h As Integer, ByVal position As Long) As Integer
    Seek = NotSupported
End Function

Public Function Eof(ByVal h As Integer) As Integer
    Eof = -1
End Function

Public Function ReadLine(ByVal h As Integer) As String
    ReadLine = ""
End Function

Public Function WriteLine(ByVal h As Integer, ByVal text As String) As Integer
    WriteLine = NotSupported
End Function

' ---- devices

' Devices(): how files travel, "TAPE,DISC" / "DISC"
Public Function Devices() As String
#asm
            pop hl
            ld (fs_res), hl
            ld hl, fs_devices
            jp fs_go0
#endasm
End Function

' CurrentDevice(): "TAPE" or "DISC"
Public Function CurrentDevice() As String
#asm
            pop hl
            ld (fs_res), hl
            ld hl, fs_curdev
            jp fs_go0
#endasm
End Function

' SelectDevice(name): "TAPE" or "DISC". OK, or NotFound
Public Function SelectDevice(ByVal name As String) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, fs_select
            jp fs_go
#endasm
End Function

' Volumes(): the volumes that worked so far, "A,C" (the platform can't list them all:
' each one used successfully joins the list)
Public Function Volumes() As String
#asm
            pop hl
            ld (fs_res), hl
            ld hl, fs_volumes
            jp fs_go0
#endasm
End Function

' CurrentVolume(): the volume last selected ("" = not known)
Public Function CurrentVolume() As String
#asm
            pop hl
            ld (fs_res), hl
            ld hl, fs_curvol
            jp fs_go0
#endasm
End Function

' SelectVolume(name): the volume files without one in their name go to. OK, NotFound
Public Function SelectVolume(ByVal name As String) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, fs_selvol
            jp fs_go
#endasm
End Function

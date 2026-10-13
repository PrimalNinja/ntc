' FileSystem - files. NTC platform class: Amstrad CPC through the firmware
'
' Load and Save (CAS IN / CAS OUT DIRECT), and one open file read or written byte by byte
' (CAS IN CHAR / CAS OUT CHAR): with AMSDOS they go to the disc drive that is selected, else to tape - the same
' as BASIC's LOAD and SAVE, with the firmware's own messages ("Press PLAY then any key",
' disc errors with Retry / Cancel). Capability: LOAD, SAVE, SEQUENTIAL, DEVICES, VOLUMES
' (True), MAXOPEN 1, ROMDISC (True). Seek, Delete, Rename return NotSupported. Uses a 2K buffer
' (CAS IN / OUT OPEN).
' Volume R is the ROMDISC (files kept in ROMs, read only: NTCDISC.ROM ...): SelectVolume "R",
' or "R:NAME.EXT" - Load, Open ForRead (handle 2, beside a disc file's handle 1), ReadByte,
' Read, ReadLine, Eof, Close, Exists, Size, DirEntry.
' Devices: TAPE, and DISC with a DOS (|TAPE, |DISC). Volumes: any name the DOS has a command
' for (|A, |B, |C, |M ... - AMSDOS, M4, UniDOS, ...); the ones that work join Volumes().
' RUN" of a binary drops AMSDOS (tape then): Option RomEnable 7 starts it again.
' A file saved here is a binary file (type 2): BASIC can LOAD "NAME", address it back. A file
' written with Open ForWrite is a text file: BASIC's OPENIN / LINE INPUT #9 read it.

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
            db "SEQUENTIAL", 0
            dw -1
            db "DEVICES", 0
            dw -1
            db "VOLUMES", 0
            dw -1
            db "ROMDISC", 0
            dw -1
            db "MAXOPEN", 0
            dw 1
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
            ld de, rd_load
            jp rd_route
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
            ld de, rd_ns
            jp rd_route
#endasm
End Function

Public Function Delete(ByVal name As String) As Integer
    Delete = NotSupported
End Function

' Exists(name): True / False - on the ROMDISC (volume R); NotSupported elsewhere
Public Function Exists(ByVal name As String) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, rd_ns
            ld de, rd_exists
            jp rd_route
#endasm
End Function

Public Function Rename(ByVal oldname As String, ByVal newname As String) As Integer
    Rename = NotSupported
End Function

' Size(name): bytes - on the ROMDISC (volume R); NotSupported elsewhere
Public Function Size(ByVal name As String) As Long
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, rd_nsl
            ld de, rd_size
            jp rd_route0
#endasm
End Function

' ---- one open file (handle 1)

' Open(name, mode): 1, or a status. ForRead: any file, read byte by byte (CAS IN CHAR).
' ForWrite: a new text file (CAS OUT CHAR; BASIC's OPENIN reads it). ForUpdate: NotSupported.
' One file open at a time (NoHandle); Load and Save return Failed while it is
Public Function Open(ByVal name As String, ByVal mode As Integer) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a2), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_open
            ld de, rd_open
            jp rd_route
#endasm
End Function

Public Function Close(ByVal h As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_closeh
            ld de, rd_close
            jp rd_routeh
#endasm
End Function

' ReadByte(h): 0-255, or EndOfFile
Public Function ReadByte(ByVal h As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_readb
            ld de, rd_readb
            jp rd_routeh
#endasm
End Function

Public Function WriteByte(ByVal h As Integer, ByVal b As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a2), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_writeb
            ld de, rd_ns
            jp rd_routeh
#endasm
End Function

' Read(h, address, count): bytes read into memory (fewer at the end of the file)
Public Function Read(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
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
            ld hl, fs_read
            ld de, rd_read
            jp rd_routeh
#endasm
End Function

' Write(h, address, count): bytes from memory. count, or a status
Public Function Write(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
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
            ld hl, fs_write
            ld de, rd_ns
            jp rd_routeh
#endasm
End Function

Public Function Seek(ByVal h As Integer, ByVal position As Long) As Integer
    Seek = NotSupported
End Function

' Eof(h): True when there is nothing more to read
Public Function Eof(ByVal h As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_eof
            ld de, rd_eof
            jp rd_routeh
#endasm
End Function

' ReadLine(h): the next line of text (up to LF; CR LF / LF not kept), "" at the end
Public Function ReadLine(ByVal h As Integer) As String
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
            pop hl
            ld (fs_res), hl
            ld hl, fs_readln
            ld de, rd_readln
            jp rd_routeh0
#endasm
End Function

' WriteLine(h, text): the text and CR LF
Public Function WriteLine(ByVal h As Integer, ByVal text As String) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fs_a1), de
            pop hl
            ld (fs_a2), hl
            pop hl
            ld (fs_res), hl
            ld hl, fs_writeln
            ld de, rd_ns
            jp rd_routeh
#endasm
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
            ld de, rd_fsvol
            jp rd_routev
#endasm
End Function

' ---- the ROMDISC (volume R: files kept in ROMs, read only)

' DirEntry(n): the ROMDISC's n-th file, "NAME.EXT" (1 = the first); "" past the last, or
' no ROMDISC fitted
Public Function DirEntry(ByVal n As Integer) As String
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a1), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_dirent
            jp fs_go0
#endasm
End Function

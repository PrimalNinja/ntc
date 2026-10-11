' FileSystem - files. NTC platform class: CP/M (BDOS, 128 byte records)
'
' What it can do: Capability("NAME") - the value, or 0 (False) when this platform hasn't
' got it: LOAD, SAVE, SEQUENTIAL, RANDOMACCESS, DELETE, RENAME, EXISTS, SIZE, MULTIPLE
' DEVICES, VOLUMES (True), MAXOPEN (2), RECORDSIZE (128), CPMVERSION (BDOS 12: &H22 CP/M 2.2,
' &H31 CP/M 3). Every platform's FileSystem has the same methods;
' one the platform can't do returns NotSupported.
'
' Results: 0 or more = done (a count, a handle, a byte), negative = the status below.
' Names: "NAME.EXT" or "B:NAME.EXT" (8.3, no * or ?). CP/M keeps whole 128 byte records,
' not an exact length: Save pads the last record with ^Z (26), Load and Size count whole
' records, and a text file ends at the first ^Z (Eof, ReadLine).

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
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, caps
            ld (fs_a2), hl
            ld hl, fs_capab
            jp fs_go
caps:       db "LOAD", 0
            dw -1
            db "SAVE", 0
            dw -1
            db "SEQUENTIAL", 0
            dw -1
            db "RANDOMACCESS", 0
            dw -1
            db "DELETE", 0
            dw -1
            db "RENAME", 0
            dw -1
            db "EXISTS", 0
            dw -1
            db "SIZE", 0
            dw -1
            db "MULTIPLE", 0
            dw -1
            db "DEVICES", 0
            dw -1
            db "VOLUMES", 0
            dw -1
            db "CPMVERSION", 0
            dw #8000
            db "MAXOPEN", 0
            dw 2
            db "RECORDSIZE", 0
            dw 128
            db 0
#endasm
End Function

' ---- whole files

' Load(name, address, maxlen): the file into memory. Bytes loaded, or a status
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

' Save(name, address, length): a new file with those bytes. OK or a status
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
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, fs_delete
            jp fs_go
#endasm
End Function

' Exists(name): True / False
Public Function Exists(ByVal name As String) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, fs_exists
            jp fs_go
#endasm
End Function

Public Function Rename(ByVal oldname As String, ByVal newname As String) As Integer
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_a2), hl
            pop hl
            ld (fs_res), hl
            ld hl, fs_rename
            jp fs_go
#endasm
End Function

' Size(name): bytes (whole records), or a status
Public Function Size(ByVal name As String) As Long
#asm
            pop hl
            ld (fs_a1), hl
            pop hl
            ld (fs_res), hl
            ld hl, fs_size
            jp fs_go4
#endasm
End Function

' ---- open files (handles 1 and 2)

' Open(name, mode): a handle, or a status. mode: ForRead, ForWrite, ForUpdate
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
            jp fs_go
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
            jp fs_go
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
            jp fs_go
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
            jp fs_go
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
            jp fs_go
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
            jp fs_go
#endasm
End Function

' Seek(h, position): the next read / write is at that byte (0 = the start)
Public Function Seek(ByVal h As Integer, ByVal position As Long) As Integer
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
            ld hl, fs_seek
            jp fs_go
#endasm
End Function

' Eof(h): True when there is nothing more to read (the end, or a ^Z)
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
            jp fs_go
#endasm
End Function

' ReadLine(h): the next line of text (CR LF / LF not kept), "" at the end
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
            jp fs_go0
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
            jp fs_go
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
            jp fs_go
#endasm
End Function

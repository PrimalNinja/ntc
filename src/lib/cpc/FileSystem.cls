' FileSystem - files. NTC platform class: Amstrad CPC, hardware (no firmware) - the ROMDISC
'
' This platform uses no firmware at all, so no AMSDOS / tape (the cpcmin platform keeps the
' firmware for that, cpcfw uses it for everything). Its one volume is R, the ROMDISC: files
' kept in ROMs, read only (NTCDISC.ROM, NTCDISC2.ROM ... in any ROM slots, made by ntcRomDisc /
' test/genromdisc.js). Names are 8.3 ("LEVEL1.DAT", or "R:LEVEL1.DAT"). Capability: LOAD,
' SEQUENTIAL, EXISTS, SIZE, DEVICES, VOLUMES, ROMDISC (True), MAXOPEN 1; SAVE and the rest 0.
' Load, Open ForRead (handle 2), ReadByte, Read, ReadLine, Eof, Close, Exists, Size, DirEntry;
' writing, Delete, Rename and Seek return NotSupported. Without a ROMDISC fitted: NotFound.
'   If FileSystem.Exists("TITLE.SCR") Then r = FileSystem.Load("TITLE.SCR", &HC000, 16384)

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
            db "SEQUENTIAL", 0
            dw -1
            db "EXISTS", 0
            dw -1
            db "SIZE", 0
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

' Load(name, address, maxlen): the file into memory. Its length, or a status (TooBig: longer
' than maxlen - nothing is loaded)
Public Function Load(ByVal name As String, ByVal addr As Integer, ByVal maxlen As Integer) As Integer
#asm
            pop hl
            ld (rd_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a2), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a3), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_load
            jp rd_go
#endasm
End Function

Public Function Save(ByVal name As String, ByVal addr As Integer, ByVal length As Integer) As Integer
    Save = NotSupported
End Function

Public Function Delete(ByVal name As String) As Integer
    Delete = NotSupported
End Function

' Exists(name): True / False
Public Function Exists(ByVal name As String) As Integer
#asm
            pop hl
            ld (rd_a1), hl
            pop hl
            ld (rd_res), hl
            ld hl, rd_exists
            jp rd_go
#endasm
End Function

Public Function Rename(ByVal oldname As String, ByVal newname As String) As Integer
    Rename = NotSupported
End Function

' Size(name): bytes, or a status
Public Function Size(ByVal name As String) As Long
#asm
            pop hl
            ld (rd_a1), hl
            pop hl
            ld (rd_res), hl
            ld hl, rd_size
            jp rd_go0
#endasm
End Function

' Open(name, mode): 2 (the handle), or a status. ForRead only (the ROMDISC is read only:
' NotSupported); one file open at a time (NoHandle)
Public Function Open(ByVal name As String, ByVal mode As Integer) As Integer
#asm
            pop hl
            ld (rd_a1), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a2), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_open
            jp rd_go
#endasm
End Function

Public Function Close(ByVal h As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a1), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_close
            jp rd_go
#endasm
End Function

' ReadByte(h): 0-255, or EndOfFile
Public Function ReadByte(ByVal h As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a1), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_readb
            jp rd_go
#endasm
End Function

Public Function WriteByte(ByVal h As Integer, ByVal b As Integer) As Integer
    WriteByte = NotSupported
End Function

' Read(h, address, count): bytes read into memory (fewer at the end of the file)
Public Function Read(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a1), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a2), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a3), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_read
            jp rd_go
#endasm
End Function

Public Function Write(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
    Write = NotSupported
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
            ld (rd_a1), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_eof
            jp rd_go
#endasm
End Function

' ReadLine(h): the next line of text (up to LF; CR LF / LF not kept), "" at the end
Public Function ReadLine(ByVal h As Integer) As String
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (rd_a1), de
            pop hl
            ld (rd_res), hl
            ld hl, rd_readln
            jp rd_go0
#endasm
End Function

Public Function WriteLine(ByVal h As Integer, ByVal text As String) As Integer
    WriteLine = NotSupported
End Function

' ---- devices and volumes: the ROMDISC only

' Devices(): "ROM" (a ROMDISC fitted), else ""
Public Function Devices() As String
    If SelectVolume("R") = OK Then Devices = "ROM" Else Devices = ""
End Function

Public Function CurrentDevice() As String
    CurrentDevice = "ROM"
End Function

' SelectDevice(name): "ROM". OK, or NotFound
Public Function SelectDevice(ByVal name As String) As Integer
    If UCase$(name) = "ROM" Then SelectDevice = SelectVolume("R") Else SelectDevice = NotFound
End Function

' Volumes(): "R" (a ROMDISC fitted), else ""
Public Function Volumes() As String
    If SelectVolume("R") = OK Then Volumes = "R" Else Volumes = ""
End Function

Public Function CurrentVolume() As String
    CurrentVolume = "R"
End Function

' SelectVolume(name): "R" (or "R:"): OK when a ROMDISC is fitted, else NotFound
Public Function SelectVolume(ByVal name As String) As Integer
    Dim v As String
    v = UCase$(name)
    If v = "R" Or v = "R:" Then
        SelectVolume = SelVol()
    Else
        SelectVolume = NotFound
    End If
End Function

Private Function SelVol() As Integer
#asm
            pop hl
            ld (rd_res), hl
            ld hl, rd_selvol
            jp rd_go
#endasm
End Function

' DirEntry(n): the ROMDISC's n-th file, "NAME.EXT" (1 = the first); "" past the last, or no
' ROMDISC fitted
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
            jp rd_go0
#endasm
End Function

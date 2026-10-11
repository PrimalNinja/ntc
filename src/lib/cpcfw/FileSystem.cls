' FileSystem - files. NTC platform class: Amstrad CPC through the firmware
'
' Load and Save only (for now), through the firmware's cassette calls (CAS IN / CAS OUT
' DIRECT): with AMSDOS they go to the disc drive that is selected, else to tape - the same
' as BASIC's LOAD and SAVE, with the firmware's own messages ("Press PLAY then any key",
' disc errors with Retry / Cancel). Capability: LOAD, SAVE (True), MAXOPEN 0. Everything
' else returns NotSupported. Uses a 2K buffer (CAS IN / OUT OPEN need one).
' A file saved here is a binary file (type 2): BASIC can LOAD "NAME", address it back.

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

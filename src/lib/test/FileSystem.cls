' FileSystem - files. NTC platform class: test harness - no files (yet)
'
' This platform has no file system: Capability("...") is 0 (False) for everything and every
' method returns NotSupported (Eof True, ReadLine ""). Every platform's FileSystem has the
' same methods, so a program written for files still compiles here and can check first:
'   If FileSystem.Capability("SAVE") Then r = FileSystem.Save("HISCORE", VarPtr(hs(0)), 64)

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
Public Const BadMode = -11        ' Open: mode not 1-4; writing to a file open for reading

' ---- Open modes
Public Const ForRead = 1          ' the file must be there
Public Const ForWrite = 2         ' a new file (an old one of that name is deleted)
Public Const ForUpdate = 3        ' read and write, Seek anywhere (made if not there)
Public Const ForReadRaw = 4       ' ForRead, every byte to the end of the file: a #1A is data (a file with no header)

' Capability("NAME"): the value, or 0 when this platform hasn't got it
Public Function Capability(ByVal name As String) As Integer
#asm
            pop hl
            pop de
            ld bc, caps
            jp ntc_capfind
caps:       db 0
#endasm
End Function

Public Function Load(ByVal name As String, ByVal addr As Integer, ByVal maxlen As Integer) As Integer
    Load = NotSupported
End Function

Public Function Save(ByVal name As String, ByVal addr As Integer, ByVal length As Integer) As Integer
    Save = NotSupported
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
Public Function Devices() As String
    Devices = ""
End Function
Public Function CurrentDevice() As String
    CurrentDevice = ""
End Function
Public Function SelectDevice(ByVal name As String) As Integer
    SelectDevice = NotSupported
End Function
Public Function Volumes() As String
    Volumes = ""
End Function
Public Function CurrentVolume() As String
    CurrentVolume = ""
End Function
Public Function SelectVolume(ByVal name As String) As Integer
    SelectVolume = NotSupported
End Function

' DirEntry(n): a ROMDISC's n-th file (the CPC platforms' volume R) - none here: ""
Public Function DirEntry(ByVal n As Integer) As String
    DirEntry = ""
End Function

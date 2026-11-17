' Loader - loads a file from where the program was run. NTC platform class: MSX (cartridge)
'
' This platform has no files: Load answers NotSupported. Every platform's Loader has the same
' method, so a program written for it still compiles here.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License

' ---- what Load answers when it isn't a length (FileSystem's numbers)
Public Const OK = 0
Public Const NotSupported = -1    ' this platform can't
Public Const NotFound = -2
Public Const BadName = -4
Public Const TooBig = -8          ' the file holds more than maxlen: nothing is loaded
Public Const Failed = -9

' Load(name, address, maxlen): NotSupported here
Public Function Load(ByVal name As String, ByVal addr As Integer, ByVal maxlen As Integer) As Integer
  Load = NotSupported
End Function

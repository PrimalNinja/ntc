' Loader - loads a file from where the program was run. NTC platform class: ZX Spectrum Next
'
' One method, Load, and nothing else: no Save, no open files, no drives or folders to choose.
' It is for a program that only reads its own data files, and costs a fraction of FileSystem.
' The file comes from the folder that was current when the program was run (the browser runs a
' NEX with its own folder current), on the default drive: "NAME.EXT". The folder is left as it
' is (FileSystem sets the card's top folder at its first call; this class sets nothing).
' The DOS call is FileSystem's: NextZXOS's esxDOS API (rst 8 with ROM 3 paged in) from a
' trampoline copied once to #BA00, the name at #BC00, a stat buffer at #BC40, the data through
' 384 bytes at #BC80 a chunk. All of it is assembly (no String or Long code is linked). A file of
' 64K or more is TooBig. The same numbers as FileSystem.Load.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License

' ---- what Load answers when it isn't a length (FileSystem's numbers)
Public Const OK = 0
Public Const NotSupported = -1    ' this platform can't
Public Const NotFound = -2
Public Const BadName = -4
Public Const TooBig = -8          ' the file holds more than maxlen: nothing is loaded
Public Const Failed = -9

' Load(name, address, maxlen): the file into memory. Its length, or a status
Public Function Load(ByVal name As String, ByVal addr As Integer, ByVal maxlen As Integer) As Integer
#asm
            pop hl
            ld (ld_nm), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (ld_ad), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (ld_mx), de
            pop hl
            ld (ld_rs), hl
            jp ld_go
#endasm
End Function

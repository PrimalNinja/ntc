' Loader - loads a file from where the program was run. NTC platform class: CP/M
'
' One method, Load, and nothing else: no Save, no open files, no drives or user areas to
' choose. It is for a program that only reads its own data files, and costs a fraction of
' FileSystem. The file comes from the drive and user area that were current when the program
' was run ("NAME.EXT", 8.3, no drive letter). Uses CP/M's own FCB at #005C and record buffer
' at #0080 (no memory of the program's). CP/M keeps no exact length: Load answers whole
' 128-byte records, as FileSystem.Load does (the same numbers).
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

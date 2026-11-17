' Loader - loads a file from where the program was run. NTC platform class: Amstrad CPC through
' the firmware
'
' One method, Load, and nothing else: no Save, no open files, no devices or volumes to choose.
' It is for a program that only reads its own data files, and costs a fraction of FileSystem.
' The file comes from where the program came from: the disc drive it was run from (AMSDOS), or
' tape. It is the firmware's CAS IN OPEN / CAS IN DIRECT, as BASIC's LOAD, with the firmware's
' own messages (Press PLAY then any key, disc errors with Retry / Cancel).
' RUN" of a binary drops AMSDOS (files are on tape then): Option ROM Enable 7 starts it again,
' and with this class in the program it comes back on the drive it was on (not drive A).
' Uses the 2K buffer (Option Buffer), as FileSystem does. The same numbers as FileSystem.Load.
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

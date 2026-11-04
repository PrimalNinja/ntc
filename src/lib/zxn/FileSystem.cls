' FileSystem - files. NTC platform class: ZX Spectrum Next, native - the SD card through
' NextZXOS's esxDOS API (rst 8 with ROM 3 paged in). Same methods as every platform's
' FileSystem; the same status values; Capability says what is here.
'
' How a call is made: the program's own code sits from #0040, in the RAM that ROM 3 must take
' (slots 0-1, #0000-#3FFF) for rst 8 - so the call runs from a trampoline this class copies
' once into #BA00 (free: between the ULA screen's end and the tilemap), with a stack of its own
' there, below the thread's stack (#BA00-#BDFF: the trampoline at #BA00, the system variables'
' copy at #BAB0, its stack #BB30-#BBFF, the name at #BC00, a buffer at #BC40, 384 bytes of data at
' #BC80 - all outside #C000-#FFFF, which +3DOS pages its bank 7 over during a file call; the
' platform's memtop keeps the heap below #BA00), interrupts left as they are (the SD driver wants them: an interrupt during the call runs
' ROM 3's handler, which writes its system variables at #5C00-#5C7B - program here - so those 124
' bytes are kept across the call), MMU 0 and 1 = 255 (ROM) and NextReg #8E = 3 (ROM 3, slots 6-7 kept)
' round the rst 8, then the two MMU slots as they were. DivMMC stays out: the NEX stub cut its
' automatic paging to rst 8 with ROM 3 (NextRegs #B8, #B9, #BB). Names: "NAME.EXT" or a path
' "GAMES/NAME.EXT" on the current drive ("*"); a drive letter "C:NAME" is passed to esxDOS as is.
' Every pointer the DOS gets must be above #4000 too (the program's first 16K is paged out under
' ROM 3 during the call): the name goes to #DB80, a stat / directory buffer to #BB80, and file
' data through a 512-byte bounce buffer at #DC00, a chunk at a time (Copy: an LDIR).
' Handles are esxDOS's (0-255) + 1, so 0 is never one; MAXOPEN is the DOS's.
' Reading a text file: ReadLine takes a line to CR / LF (CR LF as one), a #1A ends the file.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License

' ---- status
Public Const OK = 0
Public Const NotSupported = -1
Public Const NotFound = -2
Public Const Full = -3
Public Const BadName = -4
Public Const NoHandle = -5
Public Const BadHandle = -6
Public Const EndOfFile = -7
Public Const TooBig = -8
Public Const Failed = -9
Public Const AlreadyExists = -10
Public Const BadMode = -11

' ---- Open modes
Public Const ForRead = 1
Public Const ForWrite = 2
Public Const ForUpdate = 3
Public Const ForReadRaw = 4

Private Const BNAME = &HBC00         ' the name, ASCIIZ, as the DOS reads it
Private Const BNAME2 = &HBC40        ' a second name (Rename), or a stat / directory buffer
Private Const BDATA = &HBC80         ' 512 bytes of file data a chunk
Private Const BCHUNK = 384
Private nm As String Max 64          ' an ASCIIZ name for the DOS (copied to BNAME for the call)
Private ln As String Max 255         ' WriteLine's text (VarPtr: a module string's bytes)
Private nm2 As String Max 64
Private st(10) As Byte               ' F_FSTAT's 11 bytes: drive, device, attributes, date (2), time (2), size (4)
Private de(31) As Byte               ' a directory entry: attributes, the name (ASCIIZ), date, time, size
Private dh As Integer                ' the directory handle + 1 of a DirEntry walk, 0 none
Private dn As Integer                ' the entry number the walk is at
Private ready As Integer             ' the trampoline copied
Private inited As Integer            ' the first use done: the drive known, the folder set
Private drv As Integer               ' the drive letter esxDOS answered ('C' usually)
Private drvcode As Integer           ' its raw code (M_GETSETDRV's A: the letter in bits 7-3), what the calls take in A

' ---- the DOS call. Hook in B, A, BC-as-count / DE / IX as the hook wants (set before), the
' answer: carry set = an error (A the code), else the registers the hook gives.
' DosCall(hook, a, bc, de, ix) -> the DOS's A (0-255) or -1 on carry; BC and DE back in bcr, der
Public LastError As Integer           ' esxDOS's error code (A) of the last failed call - for finding out why
Private bcr As Integer, der As Integer, lreg As Integer   ' lreg: L for the call (F_SEEK's mode), 0 unless set
Private hlv As Integer               ' HL for the call: the name too (NextZXOS reads the pointer in HL, esxDOS in IX), F_SEEK's mode
Private Function DosCall(ByVal hook As Integer, ByVal a As Integer, ByVal bc As Integer, ByVal dex As Integer, ByVal ixr As Integer) As Integer
  If hook = &H9F Then hlv = lreg Else hlv = ixr
#asm
            ld a, ({ready})
            or a
            jr nz, dc_rdy
            ld hl, dc_tramp
            ld de, #BA00
            ld bc, dc_trampe - dc_tramp
            ldir                    ; the trampoline into #BA00, once
            ld a, 1
            ld ({ready}), a
dc_rdy:     ld a, ({hook})
            ld (#BA00 + (dc_hk - dc_tramp)), a
            ld hl, ({bc})
            ld (#BA00 + (dc_bc - dc_tramp)), hl
            ld hl, ({dex})
            ld (#BA00 + (dc_de - dc_tramp)), hl
            ld hl, ({ixr})
            ld (#BA00 + (dc_ix - dc_tramp)), hl
            ld a, ({a})
            ld (#BA00 + (dc_a - dc_tramp)), a
            ld hl, ({hlv})
            ld (#BA00 + (dc_l - dc_tramp)), hl
            ld (#BA00 + (dc_sp - dc_tramp)), sp
            jp #BA00                ; comes back to dc_back by jp
dc_back:    ld hl, (#BA00 + (dc_bc - dc_tramp))
            ld ({bcr}), hl
            ld hl, (#BA00 + (dc_de - dc_tramp))
            ld ({der}), hl
            ld a, (#BA00 + (dc_cy - dc_tramp))
            or a
            jr z, dc_ok
            ld a, (#BA00 + (dc_a - dc_tramp))
            ld l, a
            ld h, 0
            ld ({LastError}), hl
            ld hl, -1
            ld ({result}), hl
            jp dc_end
dc_ok:      ld a, (#BA00 + (dc_a - dc_tramp))
            ld l, a
            ld h, 0
            ld ({result}), hl
            jp dc_end
; ---- the trampoline (copied to #BA00, 164 bytes; the sysvars copy at #BAB0; its stack to #BC00)
dc_tramp:   ld sp, #BC00            ; own stack: #BB30-#BBFF
            ld hl, #5C00            ; the ROM's system variables' area kept (an interrupt during the call
            ld de, #BAB0            ; runs ROM 3's handler, which writes there): 124 bytes to #BAB0-#BB2B (the trampoline is 164 bytes: to #BAA3)
            ld bc, 124
            ldir
            ld bc, #243B            ; MMU 0, 1 read (NextReg #50, #51) and set to 255 (ROM)
            ld a, #50
            out (c), a
            inc b
            in a, (c)
            ld (#BA00 + (dc_m0 - dc_tramp)), a
            dec b
            ld a, #51
            out (c), a
            inc b
            in a, (c)
            ld (#BA00 + (dc_m1 - dc_tramp)), a
            dec b
            ld a, #50
            out (c), a
            inc b
            ld a, #FF
            out (c), a
            dec b
            ld a, #51
            out (c), a
            inc b
            ld a, #FF
            out (c), a
            dec b
            ld a, #8E               ; ROM 3, slots 6-7 kept
            out (c), a
            inc b
            ld a, #03
            out (c), a
            ld bc, (#BA00 + (dc_bc - dc_tramp))
            ld de, (#BA00 + (dc_de - dc_tramp))
            ld ix, (#BA00 + (dc_ix - dc_tramp))
            ld hl, (#BA00 + (dc_l - dc_tramp))  ; HL: the name too, or F_SEEK's mode in L
            ld a, (#BA00 + (dc_a - dc_tramp))
            rst 8
dc_hk:      db 0
            ld (#BA00 + (dc_bc - dc_tramp)), bc
            ld (#BA00 + (dc_de - dc_tramp)), de
            ld (#BA00 + (dc_a - dc_tramp)), a
            ld a, 0
            jr nc, dc_nocy
            ld a, 1
dc_nocy:    ld (#BA00 + (dc_cy - dc_tramp)), a
            ld bc, #243B
            ld a, #50               ; MMU 0, 1 back
            out (c), a
            inc b
            ld a, (#BA00 + (dc_m0 - dc_tramp))
            out (c), a
            dec b
            ld a, #51
            out (c), a
            inc b
            ld a, (#BA00 + (dc_m1 - dc_tramp))
            out (c), a
            ld hl, #BAB0            ; the system variables' area back
            ld de, #5C00
            ld bc, 124
            ldir
            ld sp, (#BA00 + (dc_sp - dc_tramp))
            jp dc_back
dc_bc:      dw 0
dc_de:      dw 0
dc_ix:      dw 0
dc_a:       db 0
dc_l:       dw 0
dc_cy:      db 0
dc_m0:      db 0
dc_m1:      db 0
dc_sp:      dw 0
dc_trampe:
dc_end:
#endasm
End Function

' the hooks
Private Const F_OPEN = &H9A
Private Const F_CLOSE = &H9B
Private Const F_READ = &H9D
Private Const F_WRITE = &H9E
Private Const F_SEEK = &H9F
Private Const F_FSTAT = &HA1
Private Const F_OPENDIR = &HA3
Private Const F_READDIR = &HA4
Private Const F_STAT = &HAC
Private Const F_UNLINK = &HAD
Private Const F_RENAME = &HB0

' FirstUse: before the first file call - the drive letter (M_GETSETDRV), then the folder set to the
' card's top (F_CHDIR "/"), as the hypervisor does: a NEX started by .nexload has no folder for "*"
' until one is set
Private Sub FirstUse()
  Dim a As Integer
  If inited Then Exit Sub
  inited = 1
  a = DosCall(&H89, 0, 0, 0, 0)
  If a >= 0 Then drv = (a \ 8) + Asc("A") Else drv = Asc("C")
  drvcode = Asc("*")                 ' the calls take "*" (the default drive) in A, as the hypervisor does
  nm = "/" + Chr$(0)
  Copy VarPtr(nm), BNAME, 2
  a = DosCall(&HA9, drvcode, 0, 0, BNAME)
End Sub

' Chdir: the current folder (a path: "GAMES", "/", ".."): OK or NotFound
Public Function Chdir(ByVal folder As String) As Integer
  FirstUse
  If NameZ(folder) <> OK Then Chdir = BadName : Exit Function
  If DosCall(&HA9, drvcode, 0, 0, BNAME) < 0 Then Chdir = NotFound Else Chdir = OK
End Function

' Copy n bytes from src to dst (an LDIR)
Private Sub Copy(ByVal src As Integer, ByVal dst As Integer, ByVal n As Integer)
#asm
            ld hl, ({src})
            ld de, ({dst})
            ld bc, ({n})
            ld a, b
            or c
            jr z, cp_none
            ldir
cp_none:
#endasm
End Sub

' NameZ: the name as ASCIIZ in nm (BadName when empty or too long); the first use done
Private Function NameZ(ByVal name As String) As Integer
  FirstUse
  If Len(name) = 0 Or Len(name) > 62 Then NameZ = BadName : Exit Function
  nm = name + Chr$(0)
  Copy VarPtr(nm), BNAME, Len(name) + 1
  NameZ = OK
End Function

' Capability("NAME"): the value, or 0 when this platform hasn't got it
Public Function Capability(ByVal name As String) As Integer
  Dim s As String Max 16
  s = UCase$(name)
  Capability = 0
  If s = "LOAD" Or s = "SAVE" Or s = "SEQUENTIAL" Or s = "RANDOMACCESS" Or s = "DELETE" Or s = "RENAME" Or s = "EXISTS" Or s = "SIZE" Or s = "MULTIPLE" Or s = "DIRECTORY" Or s = "PATHS" Then Capability = -1
  If s = "MAXOPEN" Then Capability = 8
  If s = "RECORDSIZE" Then Capability = 1
End Function

Public Function Load(ByVal name As String, ByVal addr As Integer, ByVal maxlen As Integer) As Integer
  Dim h As Integer, n As Integer, sz As Long
  h = Open(name, ForReadRaw)
  If h < 0 Then Load = h : Exit Function
  sz = Size(name)
  If sz > maxlen Then r0 = Close(h) : Load = TooBig : Exit Function
  n = Read(h, addr, maxlen)
  r0 = Close(h)
  Load = n
End Function
Private r0 As Integer

Public Function Save(ByVal name As String, ByVal addr As Integer, ByVal length As Integer) As Integer
  Dim h As Integer, n As Integer
  h = Open(name, ForWrite)
  If h < 0 Then Save = h : Exit Function
  n = Write(h, addr, length)
  r0 = Close(h)
  If n < 0 Then Save = n Else If n < length Then Save = Full Else Save = OK
End Function

Public Function Delete(ByVal name As String) As Integer
  If NameZ(name) <> OK Then Delete = BadName : Exit Function
  If DosCall(F_UNLINK, drvcode, 0, 0, BNAME) < 0 Then Delete = NotFound Else Delete = OK
End Function

Public Function Exists(ByVal name As String) As Integer
  If NameZ(name) <> OK Then Exists = 0 : Exit Function
  If DosCall(F_STAT, drvcode, 0, BNAME2, BNAME) < 0 Then Exists = 0 Else Exists = -1
End Function
' (F_STAT: A the drive, IX the name, DE a buffer for 11 bytes)

Public Function Rename(ByVal oldname As String, ByVal newname As String) As Integer
  If NameZ(oldname) <> OK Then Rename = BadName : Exit Function
  If Len(newname) = 0 Or Len(newname) > 62 Then Rename = BadName : Exit Function
  nm2 = newname + Chr$(0)
  Copy VarPtr(nm2), BNAME2, Len(newname) + 1
  If DosCall(F_RENAME, drvcode, 0, BNAME2, BNAME) < 0 Then Rename = NotFound Else Rename = OK
End Function

' Size: F_STAT's 11 bytes, the size in the last 4 (little-endian)
Public Function Size(ByVal name As String) As Long
  If NameZ(name) <> OK Then Size = BadName : Exit Function
  If DosCall(F_STAT, drvcode, 0, BNAME2, BNAME) < 0 Then Size = NotFound : Exit Function
  Copy BNAME2, VarPtr(st(0)), 11
  Size = CLng(st(7)) + CLng(st(8)) * 256 + CLng(st(9)) * 65536 + CLng(st(10)) * 16777216
End Function

' Open: the handle + 1 (1-256), or a status. Modes: ForRead / ForReadRaw read (the file must be
' there), ForWrite a new file (an old one replaced), ForUpdate read and write, made if not there
Public Function Open(ByVal name As String, ByVal mode As Integer) As Integer
  Dim m As Integer, a As Integer
  If mode < 1 Or mode > 4 Then Open = BadMode : Exit Function
  If NameZ(name) <> OK Then Open = BadName : Exit Function
  If mode = ForWrite Then m = &H0E Else If mode = ForUpdate Then m = &H0B Else m = &H01
  ' esxDOS: B the mode - bit 0 read, 1 write, 2 create if not there (#04), 3 open or create (#08), #0C create / truncate
  a = DosCall(F_OPEN, drvcode, m * 256, 0, BNAME)      ' the mode in B
  If a < 0 Then
    If mode = ForWrite Or mode = ForUpdate Then Open = Full Else Open = NotFound
  Else
    Open = a + 1
  End If
End Function

Public Function Close(ByVal h As Integer) As Integer
  If h < 1 Or h > 256 Then Close = BadHandle : Exit Function
  If DosCall(F_CLOSE, h - 1, 0, 0, 0) < 0 Then Close = Failed Else Close = OK
End Function

Public Function Read(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
  Dim got As Integer, n As Integer, want As Integer
  If h < 1 Or h > 256 Then Read = BadHandle : Exit Function
  got = 0
  Do While got < count
    want = count - got
    If want > BCHUNK Then want = BCHUNK
    If DosCall(F_READ, h - 1, want, 0, BDATA) < 0 Then Read = Failed : Exit Function
    n = bcr
    If n > 0 Then Copy BDATA, addr + got, n : got = got + n
    If n < want Then Exit Do
  Loop
  If got = 0 And count > 0 Then Read = EndOfFile Else Read = got
End Function

Public Function Write(ByVal h As Integer, ByVal addr As Integer, ByVal count As Integer) As Integer
  Dim done As Integer, n As Integer, want As Integer
  If h < 1 Or h > 256 Then Write = BadHandle : Exit Function
  done = 0
  Do While done < count
    want = count - done
    If want > BCHUNK Then want = BCHUNK
    Copy addr + done, BDATA, want
    If DosCall(F_WRITE, h - 1, want, 0, BDATA) < 0 Then Write = Full : Exit Function
    n = bcr
    done = done + n
    If n < want Then Exit Do
  Loop
  Write = done
End Function

Public Function ReadByte(ByVal h As Integer) As Integer
  Dim b(0) As Byte, n As Integer
  n = Read(h, VarPtr(b(0)), 1)
  If n < 0 Then ReadByte = n Else If n = 0 Then ReadByte = EndOfFile Else ReadByte = b(0)
End Function

Public Function WriteByte(ByVal h As Integer, ByVal b As Integer) As Integer
  Dim v(0) As Byte, n As Integer
  v(0) = b
  n = Write(h, VarPtr(v(0)), 1)
  If n < 0 Then WriteByte = n Else If n = 0 Then WriteByte = Full Else WriteByte = OK
End Function

' Seek: to position from the start (F_SEEK mode 0, BCDE the offset)
Public Function Seek(ByVal h As Integer, ByVal position As Long) As Integer
  If h < 1 Or h > 256 Then Seek = BadHandle : Exit Function
  If DosCall(F_SEEK, h - 1, CInt(position \ 65536), CInt(position And 65535), 0) < 0 Then Seek = Failed Else Seek = OK
End Function
' (F_SEEK's mode goes in L: lreg, 0 unless a caller sets it - Eof uses 1, forward by 0, to read
' the position back in BCDE)

' Eof: at the end - the position (F_SEEK forward 0: BCDE the position) against F_FSTAT's size
Public Function Eof(ByVal h As Integer) As Integer
  Dim pos As Long, sz As Long
  If h < 1 Or h > 256 Then Eof = BadHandle : Exit Function
  If DosCall(F_FSTAT, h - 1, 0, 0, BNAME2) < 0 Then Eof = BadHandle : Exit Function
  Copy BNAME2, VarPtr(st(0)), 11
  sz = CLng(st(7)) + CLng(st(8)) * 256 + CLng(st(9)) * 65536 + CLng(st(10)) * 16777216
  lreg = 1
  If DosCall(F_SEEK, h - 1, 0, 0, 0) < 0 Then lreg = 0 : Eof = Failed : Exit Function
  lreg = 0
  pos = CLng(der) + CLng(bcr) * 65536
  If pos >= sz Then Eof = -1 Else Eof = 0
End Function

Public Function ReadLine(ByVal h As Integer) As String
  Dim s As String Max 255, c As Integer
  s = ""
  Do
    c = ReadByte(h)
    If c < 0 Or c = 26 Then Exit Do
    If c = 10 Then Exit Do
    If c <> 13 And Len(s) < 255 Then s = s + Chr$(c)
  Loop
  ReadLine = s
End Function

Public Function WriteLine(ByVal h As Integer, ByVal text As String) As Integer
  Dim n As Integer
  If Len(text) > 0 Then
    ln = text                                 ' (its bytes where VarPtr reaches them: a module string, as nm)
    n = Write(h, VarPtr(ln), Len(text))
    If n < 0 Then WriteLine = n : Exit Function
  End If
  n = WriteByte(h, 13)
  If n < 0 Then WriteLine = n : Exit Function
  WriteLine = WriteByte(h, 10)
End Function

' CurrentDrive: esxDOS's default drive as a letter's code (M_GETSETDRV, A = 0), or a status
Public Function CurrentDrive() As Integer
  FirstUse
  CurrentDrive = drv
End Function

' ---- devices and volumes: the SD card, one device; folders are paths in a name
Public Function Devices() As String
  Devices = "SD"
End Function
Public Function CurrentDevice() As String
  CurrentDevice = "SD"
End Function
Public Function SelectDevice(ByVal name As String) As Integer
  If UCase$(name) = "SD" Then SelectDevice = OK Else SelectDevice = NotFound
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

' DirEntry(n): the n-th entry (0 on) of the current folder - "NAME.EXT" or "NAME/" for a folder,
' "" past the end. (F_OPENDIR on "." then F_READDIR n + 1 times, from the start when n is not the
' next; an entry: attributes, the name ASCIIZ, date, time, size.)
Public Function DirEntry(ByVal n As Integer) As String
  Dim i As Integer, a As Integer, s As String Max 20, p As Integer
  If dh = 0 Or n < dn Then
    If dh <> 0 Then r0 = DosCall(F_CLOSE, dh - 1, 0, 0, 0)
    ' the current folder's path (F_GETCWD: A the drive, IX a buffer - BDATA), then F_OPENDIR on it
    a = DosCall(&HA8, drvcode, 0, 0, BDATA)
    If a < 0 Then dh = 0 : DirEntry = "" : Exit Function
    a = DosCall(F_OPENDIR, drvcode, 0, 0, BDATA)        ' B = 0: short names
    If a < 0 Then dh = 0 : DirEntry = "" : Exit Function
    dh = a + 1 : dn = 0
  End If
  Do While dn <= n
    a = DosCall(F_READDIR, dh - 1, 0, 0, BNAME2)
    Copy BNAME2, VarPtr(de(0)), 32
    If a <= 0 Then
      r0 = DosCall(F_CLOSE, dh - 1, 0, 0, 0) : dh = 0 : dn = 0
      DirEntry = "" : Exit Function
    End If
    dn = dn + 1
  Loop
  s = ""
  p = 1
  Do While de(p) <> 0 And p < 20
    s = s + Chr$(de(p)) : p = p + 1
  Loop
  If de(0) And 16 Then s = s + "/"
  DirEntry = s
End Function

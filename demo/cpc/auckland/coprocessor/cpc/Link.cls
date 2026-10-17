' Link - the CPC side of the AUCKLAND coprocessor link (tools/s3dpi/PROTOCOL.TXT): the card keeps
' AUCKLAND.DAT and makes each frame; the CPC sends its keys (a packet through the card's I/O
' port) and reads the card's answer in a ROM it serves (#C000-#FFFF: the status block at #C100,
' the draw lists at #C200 and #E000), copies the list out, and draws it (XOR lines, Graphics).
' PORTS: the card's own aren't public yet - CMDP / KICKP are an M4-like stand-in (bytes to
' #FE00, a kick at #FC00): change them to the CPC-CPLINK2's. The ROM number: Setup.
' Test without a card: Load "FRAME.LST" (a list tools/s3dpi/sim wrote), then Draw.
Option Explicit
Public Const CMDP = &HFE00             ' (stand-in) a packet's bytes go here, one OUT each
Public Const KICKP = &HFC00            ' (stand-in) an OUT here: the packet is complete
Private rom As Integer                 ' the card's ROM number
Private lst(7679) As Byte              ' the list, copied out of the card's ROM
Private st(47) As Byte                 ' the status block, copied out
Private pk(9) As Byte, np As Integer   ' the packet being built
Private sps As Integer

' Inks: pen 1 white, 2 green, 3 cyan, black paper and border (AUCKLAND's)
Public Sub Inks()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ei
            xor a
            ld bc, 0
            call #BC32                  ; SCR SET INK
            ld a, 1
            ld bc, #1A1A
            call #BC32
            ld a, 2
            ld bc, #1212
            call #BC32
            ld a, 3
            ld bc, #1414
            call #BC32
            ld bc, 0
            call #BC38                  ; SCR SET BORDER
            di
            ld sp, ({sps})
#endasm
End Sub

' Setup(n): the card is ROM n
Public Sub Setup(ByVal n As Integer)
  rom = n
End Sub

' Hello(): True when the card answers (its status block says "S3DP")
Public Function Hello() As Integer
  pk(0) = 72 : np = 1 : Send                       ' H
  ReadStatus
  Hello = (st(0) = 83 And st(1) = 51 And st(2) = 68 And st(3) = 80)
End Function

' View(n): the camera at view n (0-); Name(): its name (the status block's message)
Public Sub View(ByVal n As Integer)
  pk(0) = 86 : pk(1) = n : np = 2 : Send           ' V
  ReadStatus
End Sub

' Frame(p, r, y, speed, skip, budget): the keys sent - the card moves the camera and makes the
' next list (pitch, roll, yaw: -1, 0, 1)
Public Sub Frame(ByVal p As Integer, ByVal r As Integer, ByVal y As Integer, ByVal speed As Integer, ByVal skip As Integer, ByVal budget As Integer)
  pk(0) = 70 : pk(1) = p And 255 : pk(2) = r And 255 : pk(3) = y And 255
  pk(4) = speed : pk(5) = skip : pk(6) = budget And 255 : pk(7) = (budget \ 256) And 255
  np = 8 : Send
End Sub

' Wait(seq): the status block read again until its sequence number isn't seq: the new one
Public Function Wait(ByVal seq As Integer) As Integer
  Do
    ReadStatus
  Loop While st(4) = seq
  Wait = st(4)
End Function

' Fetch(): the list the status block names copied out of the card's ROM
Public Sub Fetch()
  If st(5) = 0 Then RomCopy &HC200 Else RomCopy &HE000
End Sub

' Seq(), Lines(), Altitude(), CompassX(), CompassY() (-15..15, from above: up is ahead), Name()
Public Function Seq() As Integer
  Seq = st(4)
End Function
Public Function Lines() As Integer
  Lines = st(6) + st(7) * 256
End Function
Public Function Altitude() As Integer
  Altitude = st(8) + st(9) * 256
End Function
Public Function CompassX() As Integer
  CompassX = st(10) : If CompassX > 127 Then CompassX = CompassX - 256
End Function
Public Function CompassY() As Integer
  CompassY = st(11) : If CompassY > 127 Then CompassY = CompassY - 256
End Function
Public Function Name() As String
  Dim i As Integer, s As String Max 24
  s = ""
  For i = 16 To 39
    If st(i) = 0 Then Exit For
    s = s + Chr$(st(i))
  Next
  Name = s
End Function

' Load(file): a list from a file (a test with no card): its bytes
Public Function Load(ByVal f As String) As Integer
  Dim h As Integer, r As Integer
  Load = 0
  h = FileSystem.Open(f, FileSystem.ForReadRaw)
  If h < 0 Then Exit Function
  Load = FileSystem.Read(h, VarPtr(lst), 7680)
  r = FileSystem.Close(h)
End Function

' Draw(): rows 1-24 of the screen being drawn on cleared, the list drawn on it
Public Sub Draw()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            call lk_clear
            ld hl, {lst}
            ld de, 0
            ld (lk_px), de
            ld (lk_py), de
            ld a, 1
            ld (gfx_pen), a
lk_lp:
            ld a, (hl)
            and #C0
            cp #C0
            jr z, lk_end            ; the end
            cp #80
            jr nz, lk_pt
            ld a, (hl)              ; a pen
            and 3
            ld (gfx_pen), a
            inc hl
            jr lk_lp
lk_pt:
            ld b, a                 ; (the op)
            ld a, (hl)
            and 1
            ld d, a
            inc hl
            ld e, (hl)              ; DE = x
            inc hl
            ld c, (hl)              ; C = y
            inc hl
            ld a, b
            or a
            jr z, lk_mv             ; a move
            push hl
            ld (gfx_x1), de
            ld b, 0
            ld (gfx_y1), bc
            push de
            push bc
            ld hl, (lk_px)
            ld (gfx_x0), hl
            ld hl, (lk_py)
            ld (gfx_y0), hl
            call gfx_line
            pop bc
            pop de
            pop hl
lk_mv:
            ld (lk_px), de
            ld b, 0
            ld (lk_py), bc
            jr lk_lp
lk_end:
            ld sp, ({sps})
            ret
lk_px:      dw 0
lk_py:      dw 0
; lk_clear - rows 1-24 of the screen being drawn on cleared (row 0: the text line)
lk_clear:
            di                      ; SP goes through the screen
            call gfx_begin
            ld (lk_csp), sp
            ld a, (gfx_base)
            add a, #3F
            ld h, a
            ld l, #D0               ; the end of the last 2K block's 25 rows
            ld c, 8
lk_cb:
            ld (lk_crp), hl
            ld sp, (lk_crp)
            ld de, 0
            ld b, 60                ; 60 x 32 bytes: rows 1-24
lk_cl:
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            djnz lk_cl
            ld a, h
            sub 8
            ld h, a
            dec c
            jr nz, lk_cb
            ld sp, (lk_csp)
            call gfx_end
            ei
            ret
lk_csp:     dw 0
lk_crp:     dw 0
#endasm
End Sub

' ---- the card: its ROM read (KL ROM SELECT / RESTORE), a packet sent

Private Sub ReadStatus()
  RomRead &HC100, VarPtr(st), 48
End Sub

Private Sub RomCopy(ByVal a As Integer)
  RomRead a, VarPtr(lst), 7680
End Sub

' RomRead(from, to, n): n bytes from the card's ROM (from: #C000-#FFFF) to main RAM
Private Sub RomRead(ByVal a As Integer, ByVal t As Integer, ByVal n As Integer)
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld a, ({rom})
            ld c, a
            call #B90F              ; KL ROM SELECT: C its number - B, C the old state
            push bc
            ld hl, ({a})
            ld de, ({t})
            ld bc, ({n})
            ldir
            pop bc
            call #B918              ; KL ROM RESTORE
            ld sp, ({sps})
#endasm
End Sub

' Send(): pk(0 .. np - 1) out to the card, then the kick (stand-in ports: CMDP, KICKP)
Private Sub Send()
#asm
            ld a, ({np})
            or a
            jr z, sn_k
            ld e, a
            ld hl, {pk}
            ld bc, {CMDP}
sn_lp:
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, sn_lp
sn_k:
            ld bc, {KICKP}
            xor a
            out (c), a
#endasm
End Sub

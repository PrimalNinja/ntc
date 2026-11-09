' Esx - writing files to the SD card from the game: esxDOS calls with ROM 3 paged in (rst 8), the same trampoline as NTC's FileSystem class
' (DosCall, copied here because the whole FileSystem class is too big for this program's memory). The trampoline lives at #BA00-#BAA3, its
' stack to #BC00; the name goes to #BC00 and the data a chunk at a time to #BC80. Files go in the card's top folder.
' Save(name, addr, n): n bytes from addr into a new file (an old one replaced). 0, or the number of the failing step.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Private Const BNAME = &HBC00
Private Const BDATA = &HBC80
Private Const BCHUNK = 384
Private ready As Integer, inited As Integer, drvcode As Integer
Private bcr As Integer, der As Integer, hlv As Integer, LastError As Integer

Private Function DosCall(ByVal hook As Integer, ByVal a As Integer, ByVal bc As Integer, ByVal dex As Integer, ByVal ixr As Integer) As Integer
  hlv = ixr
#asm
            ld a, ({ready})
            or a
            jr nz, es_rdy
            ld hl, es_tramp
            ld de, #BA00
            ld bc, es_trampe - es_tramp
            ldir                    ; the trampoline into #BA00, once
            ld a, 1
            ld ({ready}), a
es_rdy:     ld a, ({hook})
            ld (#BA00 + (es_hk - es_tramp)), a
            ld hl, ({bc})
            ld (#BA00 + (es_bc - es_tramp)), hl
            ld hl, ({dex})
            ld (#BA00 + (es_de - es_tramp)), hl
            ld hl, ({ixr})
            ld (#BA00 + (es_ix - es_tramp)), hl
            ld a, ({a})
            ld (#BA00 + (es_a - es_tramp)), a
            ld hl, ({hlv})
            ld (#BA00 + (es_l - es_tramp)), hl
            ld (#BA00 + (es_sp - es_tramp)), sp
            jp #BA00                ; comes back to es_back by jp
es_back:    ld hl, (#BA00 + (es_bc - es_tramp))
            ld ({bcr}), hl
            ld hl, (#BA00 + (es_de - es_tramp))
            ld ({der}), hl
            ld a, (#BA00 + (es_cy - es_tramp))
            or a
            jr z, es_ok
            ld a, (#BA00 + (es_a - es_tramp))
            ld l, a
            ld h, 0
            ld ({LastError}), hl
            ld hl, -1
            ld ({result}), hl
            jp es_end
es_ok:      ld a, (#BA00 + (es_a - es_tramp))
            ld l, a
            ld h, 0
            ld ({result}), hl
            jp es_end
; ---- the trampoline (copied to #BA00, 164 bytes; the sysvars copy at #BAB0; its stack to #BC00)
es_tramp:   ld sp, #BC00            ; own stack: #BB30-#BBFF
            ld hl, #5C00            ; the ROM's system variables' area kept (an interrupt during the call
            ld de, #BAB0            ; runs ROM 3's handler, which writes there): 124 bytes to #BAB0-#BB2B (the trampoline is 164 bytes: to #BAA3)
            ld bc, 124
            ldir
            ld bc, #243B            ; MMU 0, 1 read (NextReg #50, #51) and set to 255 (ROM)
            ld a, #50
            out (c), a
            inc b
            in a, (c)
            ld (#BA00 + (es_m0 - es_tramp)), a
            dec b
            ld a, #51
            out (c), a
            inc b
            in a, (c)
            ld (#BA00 + (es_m1 - es_tramp)), a
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
            ld bc, (#BA00 + (es_bc - es_tramp))
            ld de, (#BA00 + (es_de - es_tramp))
            ld ix, (#BA00 + (es_ix - es_tramp))
            ld hl, (#BA00 + (es_l - es_tramp))  ; HL: the name too, or F_SEEK's mode in L
            ld a, (#BA00 + (es_a - es_tramp))
            rst 8
es_hk:      db 0
            ld (#BA00 + (es_bc - es_tramp)), bc
            ld (#BA00 + (es_de - es_tramp)), de
            ld (#BA00 + (es_a - es_tramp)), a
            ld a, 0
            jr nc, es_nocy
            ld a, 1
es_nocy:    ld (#BA00 + (es_cy - es_tramp)), a
            ld bc, #243B
            ld a, #50               ; MMU 0, 1 back
            out (c), a
            inc b
            ld a, (#BA00 + (es_m0 - es_tramp))
            out (c), a
            dec b
            ld a, #51
            out (c), a
            inc b
            ld a, (#BA00 + (es_m1 - es_tramp))
            out (c), a
            ld hl, #BAB0            ; the system variables' area back
            ld de, #5C00
            ld bc, 124
            ldir
            ld sp, (#BA00 + (es_sp - es_tramp))
            jp es_back
es_bc:      dw 0
es_de:      dw 0
es_ix:      dw 0
es_a:       db 0
es_l:       dw 0
es_cy:      db 0
es_m0:      db 0
es_m1:      db 0
es_sp:      dw 0
es_trampe:
es_end:
#endasm
End Function

Private Sub Copy(ByVal src As Integer, ByVal dst As Integer, ByVal n As Integer)
#asm
            ld hl, ({src})
            ld de, ({dst})
            ld bc, ({n})
            ld a, b
            or c
            jr z, ecp_none
            ldir
ecp_none:
#endasm
End Sub

Private Sub FirstUse()
  Dim a As Integer
  If inited <> 0 Then Exit Sub
  inited = 1
  drvcode = Asc("*")
  Poke BNAME, 47
  Poke BNAME + 1, 0
  a = DosCall(&HA9, drvcode, 0, 0, BNAME)
End Sub

' Save(kind, k, addr, n): a message file MSGnn.TXT (kind 0, k 1-10) or an encoding file ENCx.BIN (kind 1, k 0-9 for A-J): n bytes from addr,
' a new file (an old one replaced). 0, or the number of the failing step.
Public Function Save(ByVal kind As Integer, ByVal k As Integer, ByVal addr As Integer, ByVal n As Integer) As Integer
  Dim h As Integer, done As Integer, want As Integer, r As Integer, i As Integer
  FirstUse
  If kind = 0 Then
    Poke BNAME, 77
    Poke BNAME + 1, 83
    Poke BNAME + 2, 71
    Poke BNAME + 3, 48 + k \ 10
    Poke BNAME + 4, 48 + k Mod 10
    i = 5
  Else
    Poke BNAME, 69
    Poke BNAME + 1, 78
    Poke BNAME + 2, 67
    Poke BNAME + 3, 65 + k
    i = 4
  End If
  Poke BNAME + i, 46
  If kind = 0 Then
    Poke BNAME + i + 1, 84
    Poke BNAME + i + 2, 88
    Poke BNAME + i + 3, 84
  Else
    Poke BNAME + i + 1, 66
    Poke BNAME + i + 2, 73
    Poke BNAME + i + 3, 78
  End If
  Poke BNAME + i + 4, 0
  h = DosCall(&H9A, drvcode, &H0E00, 0, BNAME)
  If h < 0 Then
    Save = 1
    Exit Function
  End If
  Save = 0
  done = 0
  Do While done < n
    want = n - done
    If want > BCHUNK Then want = BCHUNK
    Copy addr + done, BDATA, want
    r = DosCall(&H9E, h, want, 0, BDATA)
    If r < 0 Or bcr <> want Then
      Save = 2
      Exit Do
    End If
    done = done + want
  Loop
  r = DosCall(&H9B, h, 0, 0, 0)
End Function

' RAMDISC: RAM discs in CyborgOS (build for cpm). A RAM disc is a drive (A-P) in free 16K pages
' with real CP/M random access: records read and written in place, any number of files open
' in any number of slots, true sizes (BDOS 35), searches (17, 18) of its own directory.
'   RAMDISC                       the RAM discs
'   RAMDISC v size                a RAM disc as drive v: 256KB, 1MB, 512K, 64 (KB) ... (16K steps, 4MB in all)
'   RAMDISC v 0 (or OFF)          dropped: its files are gone, its pages free again
'   RAMDISC Z SYSTEM d            (CyborgOS runs it at start, d its boot drive) the system drive Z:
'                                 the files named in d:CYBORGOS.Z (a text file, one a line) copied
'                                 there from d - its commands; Z grows a page at a time to fit them.
'                                 A line FOLDER/NAME.CYB (the installer's C/...): from d's folder
'                                 (UniDOS: a free drive letter's path for a moment), else from d
' Its contents go when CyborgOS ends (or the CPC is reset): COPY files back to a disc first.
' Z is for CyborgOS's own programs (which name it, "Z:"): CP/M programs only know A-P, and a slot
' whose drive is Z (BDOS 14) can't use it as its own drive
' The driver (Driver below) goes into a page of its own the first time (BDOS 130: the hypervisor
' puts it there and offers it every file call); it runs there, at #4000.
Option Explicit
Dim a As String Max 40, v As String Max 4, s As String Max 48
Dim p(5) As Byte                  ' BDOS 130: op, letter, the driver's address, length (words)
Dim b(71) As Byte                 ' BDOS 130 op 3: 3, the RAM disc's number; back, a line's length and text (BDOS 30's block too)
Dim fl As String Max 2            ' (Z SYSTEM) a free drive letter whose path is a folder of d's, "" none
Dim n As Long, k As Integer, r As Integer, i As Integer, c As Integer, mb As Integer
Dim hsp As Integer
Dim buf(16383) As Byte            ' RAMDISC Z SYSTEM: a file (16K at most), SYSTEM.DIR
Dim lst(1023) As Byte

a = UCase$(Trim$(System.CommandLine()))
k = Driver(0) : p(2) = k And 255 : p(3) = (k \ 256) And 255
k = Driver(1) : p(4) = k And 255 : p(5) = (k \ 256) And 255
If a = "" Then
  For i = 0 To 7
    b(0) = 3 : b(1) = i
    For k = 2 To 5
      b(k) = p(k)
    Next
    If Bdos(130, VarPtr(b)) <> 0 Then Exit For
    s = ""
    For k = 1 To b(2)
      s = s + Chr$(b(k + 2))
    Next
    Print s
  Next
  If i = 0 Then Print "No RAM discs (RAMDISC v size: a RAM disc as drive v)"
  End
End If
If Left$(a, 8) = "Z SYSTEM" Then v = Trim$(Mid$(a, 9)) : SysDrive
i = InStr(a, " ")
If i = 0 Then Usage
v = Left$(a, i - 1) : s = Trim$(Mid$(a, i + 1))
If Len(v) = 2 And Right$(v, 1) = ":" Then v = Left$(v, 1)
If Len(v) <> 1 Or v < "A" Or v > "P" Then Usage
p(1) = Asc(v)
If s = "0" Or s = "OFF" Then
  If Drop() Then Print v; ": dropped" Else Print v; ": not a RAM disc"
  End
End If
n = 0 : mb = 0
For i = 1 To Len(s)
  c = Asc(Mid$(s, i, 1))
  If c >= 48 And c <= 57 Then
    n = n * 10 + c - 48
    If n > 4096 Then Usage
  Else
    a = Mid$(s, i)
    If a = "MB" Or a = "M" Then mb = 1 Else If a <> "KB" And a <> "K" Then Usage
    Exit For
  End If
Next
If mb Then n = n * 1024
n = (n + 15) \ 16                 ' 16K pages
If n < 1 Or n > 256 Then Usage
p(0) = 0                          ' the drive, then its pages one by one
r = Bdos(130, VarPtr(p))
If r = 1 Then Print v; ": a RAM disc already (RAMDISC "; v; " 0 drops it)" : End
If r = 2 Then Print "Not enough free memory" : End
If r <> 0 Then Print "RAMDISC needs CyborgOS 320K" : End
p(0) = 2
For i = 1 To CInt(n)
  If Bdos(130, VarPtr(p)) <> 0 Then
    k = Drop()
    Print "Not enough free memory for "; n * 16; "K ("; (i - 1) * 16; "K free; MEM shows it)"
    End
  End If
Next
b(0) = &HC2 : b(1) = Asc(v) : b(2) = 0          ' (UniDOS: a path the letter had is dropped - the RAM disc
k = Bdos(30, VarPtr(b))                          ' is the letter now; BDOS 30 #C2)
Print v; ": RAM disc, "; n * 16; "K"

' RAMDISC Z SYSTEM d: Z made, the files d:CYBORGOS.Z names copied to it from d (Z a page bigger as each
' needs it: 7 2K blocks a page counted, 8 really but one may be the driver's block 0); stops at
' the first that doesn't fit (the rest stay on the disc, where CyborgOS finds them too)
Sub SysDrive()
  Dim f As String Max 24, m As Integer, fr As Integer, nb As Integer, kb As Integer
  Dim fd As String Max 12, j As Integer
  If v <> "" Then v = Left$(v, 1) + ":"
  fl = "" : fd = ""
  m = FileSystem.Load(v + "CYBORGOS.Z", VarPtr(lst), 1024)
  If m <= 0 Then Print "No "; v; "CYBORGOS.Z: no system drive Z" : End
  p(0) = 0 : p(1) = 90
  If Bdos(130, VarPtr(p)) <> 0 Then Print "Z: not made" : End
  p(0) = 2
  fr = 0 : k = 0 : kb = 0 : i = 0
  f = ""
  r = 0
  Do
    If r > 0 Then
      nb = (r + 2047) \ 2048
      Do While fr < nb
        If Bdos(130, VarPtr(p)) <> 0 Then Print "Z: no room for "; f; " (the rest from the disc)" : Exit Do
        fr = fr + 7
      Loop
      If fr < nb Then Exit Do
      r = FileSystem.Save("Z:" + f, VarPtr(buf), r)
      If r = 0 Then k = k + 1 : kb = kb + nb * 2
      fr = fr - nb
    End If
    f = ""
    Do While i < m
      c = lst(i) : i = i + 1
      If c = 26 Then i = m
      If c <= 32 Then
        If f <> "" Then Exit Do
      Else
        f = f + Chr$(c)
      End If
    Loop
    If f = "" Then Exit Do
    r = 0
    j = InStr(f, "/")
    If j > 0 Then                                ' FOLDER/NAME: from d's folder
      If fd <> Left$(f, j - 1) Then fd = Left$(f, j - 1) : Folder v + fd + "/"
      f = Mid$(f, j + 1)
      If fl <> "" Then r = FileSystem.Load(fl + f, VarPtr(buf), 16384)
    End If
    If r <= 0 Then r = FileSystem.Load(v + f, VarPtr(buf), 16384)
  Loop
  Folder ""
  Print "Z: system drive, "; Trim$(Str$(k)); " commands ("; Trim$(Str$(kb)); "K)"
  End
End Sub

' fl = a free drive letter (C-P: no path, not a RAM disc) with the path q (UniDOS), "" none; q
' "": that letter's path dropped again
Sub Folder(ByVal q As String)
  Dim c As Integer, j As Integer
  If fl <> "" Then
    b(0) = &HC2 : b(1) = Asc(fl) : b(2) = 0
    j = Bdos(30, VarPtr(b))
    fl = ""
  End If
  If q = "" Or Len(q) > 31 Then Exit Sub
  For c = 80 To 67 Step -1
    b(0) = &HC1 : b(1) = c
    If Bdos(30, VarPtr(b)) <> 0 Then Exit Sub    ' (no UniDOS)
    If b(2) = 0 And Bdos130Ram(c) = 0 Then
      b(0) = &HC2 : b(1) = c : b(2) = Len(q)
      For j = 1 To Len(q)
        b(j + 2) = Asc(Mid$(q, j, 1))
      Next
      If Bdos(30, VarPtr(b)) = 0 Then fl = Chr$(c) + ":"
      Exit Sub
    End If
  Next
End Sub

' True when drive letter c is a RAM disc (the RAM discs' list: "F: ...")
Function Bdos130Ram(ByVal c As Integer) As Integer
  Dim j As Integer
  Bdos130Ram = False
  For j = 0 To 7
    b(0) = 3 : b(1) = j
    If Bdos(130, VarPtr(b)) <> 0 Then Exit Function
    If b(3) = c Then Bdos130Ram = True : Exit Function
  Next
End Function

' the RAM disc dropped, a page at a time: True, False when it isn't one
Function Drop() As Integer
  Drop = False
  p(0) = 1
  Do While Bdos(130, VarPtr(p)) = 0
    Drop = True
  Loop
End Function

Sub Usage()
  Print "RAMDISC v size  (v A-P; size 64K, 256KB, 1MB ... 4MB)"
  Print "RAMDISC v 0     (dropped)"
  Print "RAMDISC         (the RAM discs)"
  End
End Sub

' BDOS function f, DE = d: A
Function Bdos(ByVal f As Integer, ByVal d As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({f})
            ld c, a
            ld de, ({d})
            ei                      ; (CP/M's BDOS: interrupts on)
            call 5
            di                      ; (off before SP is the threaded code again: it comes back with them on)
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function

' Driver(n): the driver - 0 its address here, 1 its length. Assembled to run at #4000 in its
' page (DISP). The hypervisor calls #4000 with IX = the call (f, fcb, slot, setting, dma,
' drive, buf: words) and the page in the window (its RAM setting at #4006); carry back = one of its drives' (HL the
' answer), no carry = not (the disc ROM's). Its copies go through the hypervisor's fl_dx (a
' jump at #4003): it can't switch the window it runs in.
'
' Its page: #4000 code; #5400 the pages (256 x 6: owner - its RAM disc + 1, 0 free -, -, page,
' RAM setting); #5A00 the blocks' chain (2048 x 2: 0 free, #FFFF the last, else the next):
' block g is 2K at (g And 7) * 2K of page g \ 8 (16 records); #6A00 the RAM discs (8 x 16:
' letter, -, blocks, free blocks); #6A80 the call, the FCB, the search, zeros, a line, the
' hypervisor's file; #6C00 the directory (256 x 20: RAM disc + 1 (0 free), name (8 + 3),
' folder (0: the top - not yet), flags, first block (0 none), records). Block 0 is never used.
' A file open: its FCB's d0 = #CB, d1 = its entry (any FCB with the name works too)
Function Driver(ByVal n As Integer) As Integer
#asm
            ld a, ({n})
            or a
            ld hl, dr_img
            jr z, dr_got
            ld hl, dr_end - dr_start
dr_got:
            ld ({result}), hl
            jp dr_out
dr_img:
            DISP #4000
dr_start:
            jp dr_entry
DX:         jp 0                    ; (#4003: the hypervisor's fl_dx, put in each call)
d_self:     dw 0                    ; (#4006: this page's RAM setting, put in each call)
D_POOL:      equ #5400
D_FAT:       equ #5A00
D_VOL:       equ #6A00
D_P:         equ #6A80               ; the call: f, fcb, slot, setting, dma, drive, buf
D_TMP:       equ #6AA0               ; the FCB (36)
D_SRC:       equ #6AD0               ; the search (15: drive, name, extent, the entry, its extent next)
D_PAT:       equ #6AE0               ; a name looked for (11, ? any character)
D_ZERO:      equ #6B00               ; 128 zeros
D_LINE:      equ #6B80               ; a line, a directory entry (48)
D_DIR:       equ #6C00
D_SIG:       equ #7F00               ; "CYBD", the magic word, the checksum of D_POOL + D_VOL:
                                     ; a reset leaves the pages, this boot's probe finds this
SRCH:        equ #F6F0               ; (in the slot's bank: BDOS 17's search)
            ASSERT dr_vars_end <= D_POOL, "the RAM disc driver's code"

dr_entry:
            push ix
            pop hl
            ld de, D_P
            ld bc, 14
            ldir
            ld a, (D_P)
            cp 110
            jp nc, dr_admin
            cp 100
            jp nc, dr_hyp
; ---- BDOS 15-23, 33-36
dr_bdos:
            ld (d_f), a
            cp 18
            jp z, dr_b18
            ld hl, (D_P + 2)        ; the FCB in
            ld de, D_TMP
            ld iy, (d_self)
            ld a, 36
            call dr_fromslot
            ld a, (D_TMP)
            call dr_letter
            call dr_vol
            ret nc
            ld hl, D_TMP + 1
            call dr_setpat
            ld a, (d_f)
            cp 15
            jp z, dr_open
            cp 16
            jp z, dr_close
            cp 17
            jp z, dr_b17
            cp 19
            jp z, dr_del
            cp 20
            jp z, dr_rdseq
            cp 21
            jp z, dr_wrseq
            cp 22
            jp z, dr_make
            cp 23
            jp z, dr_ren
            cp 33
            jp z, dr_rdran
            cp 34
            jp z, dr_wrran
            cp 35
            jp z, dr_size
            cp 36
            jp z, dr_setran
            or a                    ; (others: not here)
            ret
dr_ret:                             ; A = the answer
            ld l, a
            ld h, 0
            scf
            ret
dr_wb36:                            ; the FCB back (36 / 33 bytes), A the answer
            push af
            ld a, 36
            jr dr_wb
dr_wb33:
            push af
            ld a, 33
dr_wb:
            ld de, (D_P + 2)
            ld hl, D_TMP
            ld ix, (d_self)
            call dr_toslot
            pop af
            jr dr_ret

; 15: open - the first file that matches; its name (and d0, d1) into the FCB
dr_open:
            xor a
            call dr_find
            ld a, 255
            jr nc, dr_wb33
            ld a, (d_fi)
            call dr_mark
            ld hl, (d_e)
            inc hl
            ld de, D_TMP + 1
            ld bc, 11
            ldir
            call dr_getpos
            call dr_setpos
            xor a
            jr dr_wb33
dr_mark:                            ; d_e, d_i = the entry (HL, A from dr_find): the FCB's d0, d1
            ld (d_e), hl
            ld (d_i), a
            ld (D_TMP + 17), a
            ld a, #CB
            ld (D_TMP + 16), a
            ret
; the file the FCB names (open: d0, d1 first): carry, d_e
dr_fcbent:
            ld a, (D_TMP + 16)
            cp #CB
            jr nz, dr_fe_find
            ld a, (D_TMP + 17)
            call dr_ent
            call dr_match
            jr nz, dr_fe_find
            ld (d_e), hl
            scf
            ret
dr_fe_find:
            xor a
            call dr_find
            ret nc
            jr dr_mark              ; (carry kept: ld only)
; 16: close (the records are in already)
dr_close:
            call dr_fcbent
            ld a, 255
            jr nc, dr_wb33
            xor a
            jr dr_wb33
; 22: make - no ?; a file of that name already: emptied, kept
dr_make:
            ld hl, D_PAT
            ld b, 11
dr_mk_q:
            ld a, (hl)
            cp '?'
            ld a, 255
            jp z, dr_ret
            inc hl
            djnz dr_mk_q
            xor a
            call dr_find
            jr nc, dr_mk_new
            call dr_mark
            call dr_empty
            jr dr_mk_set
dr_mk_new:
            call dr_newent          ; a free entry: HL, A
            jr c, dr_mk_got
            ld a, 255
            jp dr_wb33
dr_mk_got:
            call dr_mark
            ld a, (d_v)
            inc a
            ld (hl), a
            inc hl
            ex de, hl
            ld hl, D_PAT
            ld bc, 11
            ldir
            ex de, hl
            ld b, 8
dr_mk_z:
            ld (hl), 0
            inc hl
            djnz dr_mk_z
dr_mk_set:
            call dr_getpos
            call dr_setpos
            xor a
            jp dr_wb33
dr_empty:                           ; d_e's file: no blocks, no records
            ld hl, (d_e)
            ld de, 14
            add hl, de
            ld c, (hl)
            ld (hl), 0
            inc hl
            ld b, (hl)
            ld (hl), 0
            inc hl
            ld (hl), 0
            inc hl
            ld (hl), 0
            jp dr_cfree
; 19: delete - every file that matches
dr_del:
            ld a, 255
            ld (d_res), a
            xor a
dr_dl_lp:
            call dr_find
            jr nc, dr_dl_end
            ld (d_e), hl
            ld (d_i), a
            call dr_empty
            ld hl, (d_e)
            ld (hl), 0
            xor a
            ld (d_res), a
            ld a, (d_i)
            inc a
            jr nz, dr_dl_lp
dr_dl_end:
            ld a, (d_res)
            jp dr_ret
; 23: rename - the new name at FCB 17-27 (not one there already)
dr_ren:
            ld hl, D_TMP + 17
            call dr_setpat
            xor a
            call dr_find
            ld a, 255
            jp c, dr_ret
            ld hl, D_TMP + 1
            call dr_setpat
            xor a
            call dr_find
            ld a, 255
            jp nc, dr_ret
            inc hl
            ex de, hl
            ld hl, D_TMP + 17
            ld b, 11
dr_rn_lp:
            ld a, (hl)
            and #7F
            ld (de), a
            inc hl
            inc de
            djnz dr_rn_lp
            xor a
            jp dr_ret
; 20 / 21: the record at the FCB's place, then on one
dr_rdseq:
            call dr_fcbent
            ld a, 9
            jp nc, dr_wb33
            call dr_getpos
            ld (d_r), hl
            call dr_rdrec
dr_sq_on:
            or a
            jp nz, dr_wb33
            ld hl, (d_r)
            inc hl
            call dr_setpos
            xor a
            jp dr_wb33
dr_wrseq:
            call dr_fcbent
            ld a, 9
            jp nc, dr_wb33
            call dr_getpos
            ld (d_r), hl
            call dr_wrrec
            jr dr_sq_on
; 33 / 34: record r0-r1 (r2 must be 0); the FCB's place set to it (not on)
dr_rdran:
            call dr_ranr
            jp nc, dr_wb33
            call dr_rdrec
            jr dr_rn_set
dr_wrran:
            call dr_ranr
            jp nc, dr_wb33
            call dr_wrrec
dr_rn_set:
            push af
            ld hl, (d_r)
            call dr_setpos
            pop af
            jp dr_wb33
dr_ranr:                            ; carry: d_r = r0-r1, else A = the answer
            call dr_fcbent
            ld a, 9
            ret nc
            ld a, (D_TMP + 35)
            or a
            ld a, 6
            ret nz                  ; (no carry: or a)
            ld hl, (D_TMP + 33)
            ld (d_r), hl
            scf
            ret
; 35: the size in records into r0-r2
dr_size:
            xor a
            call dr_find
            ld a, 255
            jp nc, dr_wb33
            ld (d_e), hl
            call dr_recs
            jr dr_rr_put
; 36: r0-r2 = the FCB's place
dr_setran:
            call dr_getpos
dr_rr_put:
            ld (D_TMP + 33), hl
            xor a
            ld (D_TMP + 35), a
            jp dr_wb36
dr_recs:                            ; HL = d_e's records
            ld hl, (d_e)
            ld de, 16
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret
; 17 / 18: search - the next file that matches (all its extents when the FCB's extent is ?),
; as a directory entry at the DMA; the search kept at SRCH in the slot's bank
dr_b17:
            ld hl, D_TMP
            ld de, D_SRC
            ld bc, 13
            ldir
            xor a
            ld (de), a
            inc de
            ld (de), a
            jr dr_s_go
dr_b18:
            ld hl, SRCH
            ld de, D_SRC
            ld iy, (d_self)
            ld a, 15
            call dr_fromslot
            ld a, (D_SRC)
            call dr_letter
            call dr_vol
            ret nc
            ld hl, D_SRC + 1
            call dr_setpat
dr_s_go:
            ld a, (D_SRC + 14)      ; (#FF: the last entry was the last)
            inc a
            ld a, 255
            jp z, dr_s_back
            ld a, (D_SRC + 13)
            call dr_find
            ld a, 255
            jp nc, dr_s_back
            ld (d_e), hl
            ld a, (d_fi)
            ld (d_i), a
            call dr_recs            ; its extents: (records + 127) \ 128, 1 at least
            ld de, 127
            add hl, de
            add hl, hl
            ld a, h
            or a
            jr nz, dr_s_nx
            inc a
dr_s_nx:
            ld (d_k2), a
            ld a, (D_SRC + 12)
            cp '?'
            ld a, (D_SRC + 14)      ; this extent
            jr z, dr_s_all
            xor a                   ; (an extent named: the first only)
            ld (d_k2), a
            inc a
            ld (d_k2), a
            xor a
dr_s_all:
            ld (d_x), a
            inc a
            ld (D_SRC + 14), a
            ld hl, d_k2
            cp (hl)
            jr c, dr_s_more
            ld a, (d_i)             ; its last: the next file next time
            inc a
            ld b, #FF               ; (entry 255: #FF, none after)
            jr z, dr_s_end
            ld (D_SRC + 13), a
            ld b, 0
dr_s_end:
            ld a, b
            ld (D_SRC + 14), a
dr_s_more:
            ld hl, D_LINE           ; the entry: user 0, the name, the extent, its records,
            ld (hl), 0              ; a block byte per 1K
            inc hl
            ex de, hl
            ld hl, (d_e)
            inc hl
            ld bc, 11
            ldir
            ex de, hl
            ld a, (d_x)
            and #1F
            ld (hl), a
            inc hl
            ld (hl), 0
            inc hl
            ld a, (d_x)
            rrca
            rrca
            rrca
            rrca
            rrca
            and 7
            ld (hl), a
            inc hl
            push hl
            call dr_recs            ; records in this extent: records - extent * 128, 0-128
            ld a, (d_x)
            ld d, a
            ld e, 0
            srl d
            rr e
            or a
            sbc hl, de
            jr nc, dr_s_pos
            ld hl, 0
dr_s_pos:
            ld a, h
            or a
            jr nz, dr_s_128
            ld a, l
            cp 129
            jr c, dr_s_rc
dr_s_128:
            ld a, 128
dr_s_rc:
            pop hl
            ld (hl), a
            inc hl
            add a, 7                ; its 1K blocks
            rrca
            rrca
            rrca
            and #1F
            ld c, a
            ld b, 16
dr_s_al:
            ld a, c
            or a
            jr z, dr_s_a0
            dec c
            ld a, 1
dr_s_a0:
            ld (hl), a
            inc hl
            djnz dr_s_al
            ld de, (D_P + 8)        ; to the DMA
            ld hl, D_LINE
            ld ix, (d_self)
            ld a, 32
            call dr_toslot
            xor a
dr_s_back:
            push af
            ld de, SRCH
            ld hl, D_SRC
            ld ix, (d_self)
            ld a, 15
            call dr_toslot
            pop af
            jp dr_ret

; ---- the records
; dr_rdrec: record d_r of d_e's file to the DMA: A = 0, 1 none there
dr_rdrec:
            call dr_recs
            ex de, hl
            ld hl, (d_r)
            or a
            sbc hl, de
            ld a, 1
            ret nc
            xor a
            ld (d_alloc), a
            call dr_rblock
            ld a, 1
            ret nc
            ld a, (d_r)
            and 15
            call dr_baddr
            ld de, (D_P + 8)
            ld a, 128
            call dr_toslot
            xor a
            ret
; dr_wrrec: the DMA to record d_r of d_e's file (blocks added as needed, zeroed): A = 0, 2 full
dr_wrrec:
            ld a, 1
            ld (d_alloc), a
            call dr_rblock
            ld a, 2
            ret nc
            ld a, (d_r)
            and 15
            call dr_baddr
            push ix
            pop iy
            ex de, hl
            ld hl, (D_P + 8)
            ld a, 128
            call dr_fromslot
            ld hl, (d_e)            ; its records: d_r + 1 at least
            ld de, 16
            add hl, de
            push hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, (d_r)
            inc hl
            ex de, hl
            or a
            sbc hl, de
            pop hl
            jr nc, dr_wr_ok
            ld (hl), e
            inc hl
            ld (hl), d
dr_wr_ok:
            xor a
            ret
; dr_rblock: BC = the block holding record d_r of d_e's file: carry; none (d_alloc 0), or no
; room (d_alloc 1): no carry. d_alloc 1: the chain made long enough
dr_rblock:
            ld hl, (d_r)
            ld b, 4
dr_rb_sh:
            srl h
            rr l
            djnz dr_rb_sh
            ld (d_bi), hl
            ld hl, (d_e)
            ld de, 15
            add hl, de              ; (its first block's high byte)
            ld b, (hl)
            dec hl
            ld c, (hl)
            ld a, b
            or c
            jr nz, dr_rb_lp
            ld a, (d_alloc)
            or a
            ret z
            push hl
            call dr_balloc
            pop hl
            ret nc
            ld (hl), c
            inc hl
            ld (hl), b
dr_rb_lp:
            ld hl, (d_bi)
            ld a, h
            or l
            scf
            ret z
            dec hl
            ld (d_bi), hl
            push bc
            call dr_fat
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop bc
            ld a, d
            and e
            inc a
            jr nz, dr_rb_nx         ; not the last
            ld a, (d_alloc)
            or a
            ret z
            push hl
            call dr_balloc
            pop hl
            ret nc
            ld (hl), b
            dec hl
            ld (hl), c
            jr dr_rb_lp
dr_rb_nx:
            ld b, d
            ld c, e
            jr dr_rb_lp
; dr_baddr: BC = block, A = record in it (0-15): IX = its page's RAM setting, HL = its address
dr_baddr:
            push af
            ld h, b
            ld l, c
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            add hl, hl
            ld de, D_POOL + 4
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            push de
            pop ix
            ld a, c
            and 7
            add a, a
            add a, a
            add a, a
            ld h, a
            pop af
            ld l, 0
            srl a
            rr l
            add a, h
            add a, #40
            ld h, a
            ret
dr_fat:                             ; HL = block BC's chain word
            ld h, b
            ld l, c
            add hl, hl
            ld de, D_FAT
            add hl, de
            ret
; dr_balloc: a free block of RAM disc d_v, zeroed, the last of a chain: BC, carry; none: no carry
dr_balloc:
            ld hl, 0
            ld (d_g), hl
            ld hl, D_POOL
dr_ba_p:
            ld a, (d_v)
            inc a
            cp (hl)
            jr nz, dr_ba_np
            push hl
            ld b, 8
dr_ba_k:
            push bc
            ld bc, (d_g)
            call dr_fat
            pop bc
            ld a, (hl)
            inc hl
            or (hl)
            jr z, dr_ba_got
            ld hl, (d_g)
            inc hl
            ld (d_g), hl
            djnz dr_ba_k
            pop hl
            jr dr_ba_n2
dr_ba_np:
            push hl
            ld hl, (d_g)
            ld de, 8
            add hl, de
            ld (d_g), hl
            pop hl
dr_ba_n2:
            ld de, 6
            add hl, de
            ld a, h
            cp high (D_POOL + 256 * 6)
            jr c, dr_ba_p
            or a
            ret
dr_ba_got:
            pop de
            ld (hl), #FF
            dec hl
            ld (hl), #FF
            call dr_vp
            ld de, 4
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            dec de
            ld (hl), d
            dec hl
            ld (hl), e
            ld bc, (d_g)
            push bc
            xor a
dr_bz_lp:
            push af
            push bc
            call dr_baddr
            push ix
            pop iy
            ex de, hl
            ld ix, (d_self)
            ld hl, D_ZERO
            ld a, 128
            call DX
            pop bc
            pop af
            inc a
            cp 16
            jr nz, dr_bz_lp
            pop bc
            scf
            ret
; dr_cfree: the chain from block BC back to free (BC 0: nothing)
dr_cfree:
            ld a, b
            or c
            ret z
dr_cf_lp:
            call dr_fat
            ld e, (hl)
            ld (hl), 0
            inc hl
            ld d, (hl)
            ld (hl), 0
            push de
            call dr_vp
            ld de, 4
            add hl, de
            inc (hl)
            jr nz, dr_cf_n
            inc hl
            inc (hl)
dr_cf_n:
            pop bc
            ld a, b
            and c
            inc a
            jr nz, dr_cf_lp
            ret
; dr_sig: "CYBD", the magic word #CB5A, and a 16-bit sum of D_POOL (1536) and D_VOL (128) at
; D_SIG - so the boot probe can tell this page (and the pages D_POOL lists) survived a reset.
; Called after the pool or the volumes change (init, a page added or dropped, a disc made or
; gone). Keeps every register
dr_sig:
            push af
            push bc
            push de
            push hl
            ld de, 0
            ld hl, D_POOL
            ld bc, 1536
            call dr_sigsum
            ld hl, D_SIG
            ld (hl), "C"
            inc hl
            ld (hl), "Y"
            inc hl
            ld (hl), "B"
            inc hl
            ld (hl), "D"
            inc hl
            ld (hl), #5A
            inc hl
            ld (hl), #CB
            inc hl
            ld (hl), e
            inc hl
            ld (hl), d
            pop hl
            pop de
            pop bc
            pop af
            ret
dr_sigsum:                          ; DE += the sum of BC bytes at HL
            ld a, (hl)
            add a, e
            ld e, a
            jr nc, dr_ss_n
            inc d
dr_ss_n:
            inc hl
            dec bc
            ld a, b
            or c
            jr nz, dr_sigsum
            ret
dr_vp:                              ; HL = RAM disc d_v's entry
            ld a, (d_v)
dr_vpa:
            add a, a
            add a, a
            add a, a
            add a, a
            ld l, a
            ld h, high D_VOL
            ret
; the FCB's place: HL = record (s2 * 32 + ex) * 128 + cr
dr_getpos:
            ld a, (D_TMP + 14)
            and #0F
            ld h, a
            ld l, 0
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a, (D_TMP + 12)
            and #1F
            ld e, a
            ld d, 0
            add hl, de
            ld b, 7
dr_gp_lp:
            add hl, hl
            djnz dr_gp_lp
            ld a, (D_TMP + 32)
            and #7F
            ld e, a
            add hl, de
            ret
; the FCB's place = record HL (cr, ex, s2), its rc the records in that extent
dr_setpos:
            ld (d_pos), hl
            ld a, l
            and #7F
            ld (D_TMP + 32), a
            add hl, hl
            ld a, h
            and #1F
            ld (D_TMP + 12), a
            ld a, h
            rlca
            rlca
            rlca
            and 7
            ld (D_TMP + 14), a
            call dr_recs            ; records - this extent's start
            ld de, (d_pos)
            ld a, e
            and #80
            ld e, a
            or a
            sbc hl, de
            jr nc, dr_sp_pos
            ld hl, 0
dr_sp_pos:
            ld a, h
            or a
            jr nz, dr_sp_128
            ld a, l
            cp 129
            jr c, dr_sp_rc
dr_sp_128:
            ld a, 128
dr_sp_rc:
            ld (D_TMP + 15), a
            ret
; ---- names, entries, RAM discs
dr_letter:                          ; A = an FCB's drive byte: the letter (0: the slot's drive, but
            or a                    ; never Z - CP/M programs don't get the system drive)
            jr z, dr_lt_own
            cp 27
            jr nc, dr_lt_own
            add a, 64
            ret
dr_lt_own:
            ld a, (D_P + 10)
            cp 'Z'
            ret nz
            xor a
            ret
dr_vol:                             ; A = a letter: carry, d_v = its RAM disc (0-7)
            or a
            ret z
            ld c, a
            ld hl, D_VOL
            ld b, 8
dr_vl_lp:
            ld a, (hl)
            cp c
            jr z, dr_vl_yes
            ld de, 16
            add hl, de
            djnz dr_vl_lp
            or a
            ret
dr_vl_yes:
            ld a, 8
            sub b
            ld (d_v), a
            scf
            ret
dr_setpat:                          ; the 11 characters at HL: D_PAT (capitals, bit 7 off)
            ld de, D_PAT
            ld b, 11
dr_spt_lp:
            ld a, (hl)
            and #7F
            call dr_upper
            ld (de), a
            inc hl
            inc de
            djnz dr_spt_lp
            ret
dr_upper:
            cp 'a'
            ret c
            cp 'z' + 1
            ret nc
            sub 32
            ret
dr_ent:                             ; HL = entry A
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, D_DIR
            add hl, de
            ret
dr_match:                           ; HL = an entry: Z = on RAM disc d_v, its name matching D_PAT
            ld a, (d_v)
            inc a
            cp (hl)
            ret nz
            push hl
            inc hl
            ld de, D_PAT
            ld b, 11
dr_mt_lp:
            ld a, (de)
            cp '?'
            jr z, dr_mt_ok
            cp (hl)
            jr nz, dr_mt_no
dr_mt_ok:
            inc hl
            inc de
            djnz dr_mt_lp
            pop hl
            xor a
            ret
dr_mt_no:
            pop hl
            ret
dr_find:                            ; from entry A on: the next that matches - carry, A, HL
            ld (d_fi), a
dr_fd_lp:
            ld a, (d_fi)
            call dr_ent
            call dr_match
            jr z, dr_fd_yes
            ld a, (d_fi)
            inc a
            ld (d_fi), a
            jr nz, dr_fd_lp
            or a
            ret
dr_fd_yes:
            ld a, (d_fi)
            scf
            ret
dr_newent:                          ; a free entry: carry, A, HL
            xor a
dr_ne_lp:
            push af
            call dr_ent
            pop af
            inc (hl)
            dec (hl)
            scf
            ret z
            inc a
            jr nz, dr_ne_lp
            or a
            ret
; ---- copies to and from a slot's bank (address split where its pages meet)
; dr_toslot: A bytes (1-128) from HL (RAM setting IX) to the slot's address DE
dr_toslot:
            ld (d_n), a
dr_ts_lp:
            push hl
            ex de, hl
            ld (d_sa), hl
            call dr_sw
            push bc
            pop iy
            ex de, hl
            call dr_room
            pop hl
            ld a, (d_k)
            call DX
            call dr_next
            ex de, hl
            ld hl, (d_sa)
            ex de, hl
            jr nz, dr_ts_lp
            ret
; dr_fromslot: A bytes (1-128) from the slot's address HL to DE (RAM setting IY)
dr_fromslot:
            ld (d_n), a
dr_fs_lp:
            ld (d_sa), hl
            push de
            call dr_sw
            push bc
            pop ix
            ex de, hl
            call dr_room
            ex de, hl
            pop de
            ld a, (d_k)
            call DX
            call dr_next
            ld hl, (d_sa)
            jr nz, dr_fs_lp
            ret
dr_room:                            ; DE = a window address: d_k = d_n, or less to the window's end
            ld hl, #8000
            or a
            sbc hl, de
            ld a, h
            or a
            ld a, (d_n)
            jr nz, dr_rm_k
            cp l
            jr c, dr_rm_k
            jr z, dr_rm_k
            ld a, l
dr_rm_k:
            ld (d_k), a
            ret
dr_next:                            ; d_sa += d_k, d_n -= d_k: NZ = more (HL, DE kept)
            push hl
            push de
            ld a, (d_k)
            ld e, a
            ld d, 0
            ld hl, (d_sa)
            add hl, de
            ld (d_sa), hl
            pop de
            pop hl
            ld a, (d_k)
            ld b, a
            ld a, (d_n)
            sub b
            ld (d_n), a
            ret
dr_sw:                              ; HL = a slot address: BC = its page's RAM setting, HL = in the window
            ld a, h
            rlca
            rlca
            and 3
            add a, 4
            ld c, a
            ld a, (D_P + 6)
            and #F8
            or c
            ld c, a
            ld a, (D_P + 7)
            ld b, a
            ld a, h
            and #3F
            or #40
            ld h, a
            ret

; ---- the hypervisor's own reading: 100 open the file named at fcb (dma characters, main RAM;
; "B:" first, else the hypervisor's drive), 101 read dma bytes to buf, 102 close, 103 into the
; slot (setting) from address dma, fcb bytes at most; 104 DIR's line fcb (#FFFF: the totals)
dr_hyp:
            cp 100
            jp z, dr_h100
            cp 104
            jp z, dr_h104
            cp 105
            ret nc
            ld c, a
            ld a, (d_hact)
            or a
            ret z                   ; (101-103: only for one opened here)
            ld a, c
            cp 102
            jr nz, dr_h_rd
            xor a
            ld (d_hact), a
            jp dr_ret
dr_h_rd:
            ld a, (d_hv)
            ld (d_v), a
            ld hl, (D_P + 12)       ; 101: to buf (main RAM), dma bytes
            ld de, (D_P + 8)
            ld b, 0
            ld a, c
            cp 101
            jr z, dr_h_go
            ld hl, (D_P + 8)        ; 103: to the slot, fcb bytes
            ld de, (D_P + 2)
            inc b
dr_h_go:
            ld (d_dst), hl
            ld (d_want), de
            ld a, b
            ld (d_toslot), a
            call dr_hread
            scf
            ret
dr_h100:
            xor a
            ld (d_hact), a
            ld hl, (D_P + 2)
            ld a, (D_P + 8)
            ld b, a
            ld a, (D_P + 10)
            ld c, a
            ld a, b
            cp 2
            jr c, dr_h_nm
            inc hl
            ld a, (hl)
            dec hl
            cp ':'
            jr nz, dr_h_nm
            ld a, (hl)
            call dr_upper
            ld c, a
            inc hl
            inc hl
            dec b
            dec b
dr_h_nm:
            push hl
            push bc
            ld a, c
            call dr_vol
            pop bc
            pop hl
            ret nc
            ld de, D_PAT            ; "NAME.EXT" as 8 + 3
            push hl
            ld h, d
            ld l, e
            ld (hl), ' '
            inc de
            push bc
            ld bc, 10
            ldir
            pop bc
            pop hl
            ld de, D_PAT
            ld c, 8
dr_h_c:
            ld a, b
            or a
            jr z, dr_h_named
            ld a, (hl)
            inc hl
            dec b
            cp '.'
            jr z, dr_h_dot
            call dr_upper
            inc c
            dec c
            jr z, dr_h_c
            ld (de), a
            inc de
            dec c
            jr dr_h_c
dr_h_dot:
            ld de, D_PAT + 8
            ld c, 3
            jr dr_h_c
dr_h_named:
            xor a
            call dr_find
            jr c, dr_h_fnd
            ld hl, D_PAT + 8        ; NAME.CYB not here: NAME.COM instead (RUN name - a .COM
            ld a, (hl)              ; with no entry, as with UniDOS), the caller's name made
            cp 'C'                  ; NAME.COM too
            jr nz, dr_h_nf
            inc hl
            ld a, (hl)
            cp 'Y'
            jr nz, dr_h_nf
            inc hl
            ld a, (hl)
            cp 'B'
            jr nz, dr_h_nf
            ld (hl), 'M'
            dec hl
            ld (hl), 'O'
            xor a
            call dr_find
            jr nc, dr_h_nf
            ld hl, (D_P + 2)
            ld a, (D_P + 8)
            ld e, a
            ld d, 0
            add hl, de
            dec hl
            ld (hl), 'M'
            dec hl
            ld (hl), 'O'
            jr dr_h_fnd
dr_h_nf:
            ld a, 255
            jp dr_ret
dr_h_fnd:
            ld a, (d_fi)
            ld (d_hent), a
            ld a, (d_v)
            ld (d_hv), a
            ld hl, 0
            ld (d_hrec), hl
            xor a
            ld (d_hoff), a
            inc a
            ld (d_hact), a
            xor a
            jp dr_ret
; dr_hread: d_want bytes of the hypervisor's file to d_dst (main RAM, or d_toslot: the slot):
; HL = how many
dr_hread:
            ld hl, 0
            ld (d_got), hl
            ld a, (d_hent)
            call dr_ent
            ld (d_e), hl
dr_hr_lp:
            ld hl, (d_want)
            ld a, h
            or l
            jp z, dr_hr_end
            call dr_recs
            ex de, hl
            ld hl, (d_hrec)
            or a
            sbc hl, de
            jp nc, dr_hr_end
            ld a, (d_hoff)
            ld b, a
            ld a, 128
            sub b
            ld c, a
            ld hl, (d_want)
            ld a, h
            or a
            jr nz, dr_hr_c
            ld a, l
            cp c
            jr nc, dr_hr_c
            ld c, a
dr_hr_c:
            ld a, c
            ld (d_k2), a
            ld hl, (d_hrec)
            ld (d_r), hl
            xor a
            ld (d_alloc), a
            call dr_rblock
            jp nc, dr_hr_end
            ld a, (d_r)
            and 15
            call dr_baddr
            ld a, (d_hoff)
            ld e, a
            ld d, 0
            add hl, de
            ld de, (d_dst)
            ld a, (d_toslot)
            or a
            ld a, (d_k2)
            jr nz, dr_hr_sl
            ld iy, 0
            call DX
            jr dr_hr_adv
dr_hr_sl:
            call dr_toslot
dr_hr_adv:
            ld a, (d_k2)
            ld e, a
            ld d, 0
            ld hl, (d_dst)
            add hl, de
            ld (d_dst), hl
            ld hl, (d_got)
            add hl, de
            ld (d_got), hl
            ld hl, (d_want)
            or a
            sbc hl, de
            ld (d_want), hl
            ld a, (d_hoff)
            add a, e
            cp 128
            jr nz, dr_hr_off
            ld hl, (d_hrec)
            inc hl
            ld (d_hrec), hl
            xor a
dr_hr_off:
            ld (d_hoff), a
            jp dr_hr_lp
dr_hr_end:
            ld hl, (d_got)
            ret
; 104: DIR's line fcb of the hypervisor's drive into buf: "NAME.EXT     nnnnK" (HL its length,
; 0 none); the one after the last file (or fcb #FFFF): "n files, nK free of nK"
dr_h104:
            ld a, (D_P + 10)
            call dr_vol
            ret nc
            ld hl, D_LINE
            ld (d_lp), hl
            ld hl, (D_P + 2)
            ld a, h
            and l
            inc a
            jr z, dr_h_tot
            ld a, h                 ; the nth file
            or a
            ld a, 0
            jr nz, dr_h_ln
            ld a, l
            ld (d_k2), a
            ld a, '?'
            ld hl, D_PAT
            ld b, 11
dr_h_q:
            ld (hl), a
            inc hl
            djnz dr_h_q
            xor a
dr_h_nth:
            call dr_find
            jr nc, dr_h_none
            ld (d_e), hl
            ld b, a
            ld a, (d_k2)
            or a
            jr z, dr_h_this
            dec a
            ld (d_k2), a
            ld a, b
            inc a
            jr nz, dr_h_nth
dr_h_none:
            ld a, (d_k2)            ; just past the last file: the totals
            or a
            jr z, dr_h_tot
            xor a
dr_h_ln:
            jp dr_ret
dr_h_this:
            ld hl, (d_e)
            inc hl
            call dr_fname
            ld a, 14                ; (to column 14)
            call dr_padto
            call dr_recs            ; K: (records + 7) \ 8
            ld de, 7
            add hl, de
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            call dr_dec
            ld a, 'K'
            call dr_putc
            jr dr_h_out
dr_h_tot:
            ld a, '?'
            ld hl, D_PAT
            ld b, 11
dr_h_tq:
            ld (hl), a
            inc hl
            djnz dr_h_tq
            ld hl, 0                ; files
            ld (d_got), hl
            xor a
dr_h_tl:
            call dr_find
            jr nc, dr_h_tc
            ld hl, (d_got)
            inc hl
            ld (d_got), hl
            inc a
            jr nz, dr_h_tl
dr_h_tc:
            ld hl, (d_got)
            call dr_dec
            ld hl, dr_t_files
            call dr_puts
            call dr_vp
            ld de, 4
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            add hl, hl              ; 2K blocks
            call dr_dec
            ld hl, dr_t_free
            call dr_puts
            call dr_vp
            inc hl
            inc hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            add hl, hl
            call dr_dec
            ld a, 'K'
            call dr_putc
dr_h_out:                           ; the line to buf (main RAM): HL = its length
            ld hl, (d_lp)
            ld de, D_LINE
            or a
            sbc hl, de
            ld a, l
            or a
            jp z, dr_ret
            ld (d_k2), a
            ld de, (D_P + 12)
            ld hl, D_LINE
            ld ix, (d_self)
            ld iy, 0
            call DX
            ld a, (d_k2)
            jp dr_ret
dr_t_files: db " files, ", 0
dr_t_free:  db "K free of ", 0
dr_fname:                           ; the 11 at HL as "NAME.EXT" to d_lp
            ld b, 8
dr_fn_n:
            ld a, (hl)
            inc hl
            cp ' '
            call nz, dr_putc
            djnz dr_fn_n
            ld a, (hl)
            cp ' '
            ret z
            ld a, '.'
            call dr_putc
            ld b, 3
dr_fn_x:
            ld a, (hl)
            inc hl
            cp ' '
            call nz, dr_putc
            djnz dr_fn_x
            ret
dr_putc:                            ; A to the line
            push hl
            ld hl, (d_lp)
            ld (hl), a
            inc hl
            ld (d_lp), hl
            pop hl
            ret
dr_puts:                            ; the text at HL (to a 0)
            ld a, (hl)
            or a
            ret z
            call dr_putc
            inc hl
            jr dr_puts
dr_padto:                           ; spaces to column A
            ld hl, (d_lp)
            ld de, D_LINE
            or a
            sbc hl, de
            cp l
            ret c
            ret z
            push af
            ld a, ' '
            call dr_putc
            pop af
            jr dr_padto
dr_dec:                             ; HL in decimal (no leading 0s)
            xor a
            ld (d_lead), a
            ld bc, -10000
            call dr_dg
            ld bc, -1000
            call dr_dg
            ld bc, -100
            call dr_dg
            ld bc, -10
            call dr_dg
            ld a, l
            add a, '0'
            jr dr_putc
dr_dg:
            ld a, '0' - 1
dr_dg_lp:
            inc a
            add hl, bc
            jr c, dr_dg_lp
            sbc hl, bc
            cp '0'
            jr nz, dr_dg_put
            ld e, a
            ld a, (d_lead)
            or a
            ret z
            ld a, e
dr_dg_put:
            ld (d_lead), a
            jr dr_putc

; ---- 110 start (setting = this page's); 111 a RAM disc (fcb = its letter), no pages yet;
; 112 a page for it (fcb = the page, setting its RAM setting); 113 one of a RAM disc's pages
; back (fcb = its letter: HL the page + #8000, 1 none left - the RAM disc gone); 114 is the letter a
; RAM disc's (0); 115 its line for RAMDISC's list (fcb = the slot's buffer: in, the RAM disc's
; number; out, the line's length and text)
dr_admin:
            cp 110
            jr z, dr_a110
            cp 111
            jp z, dr_a111
            cp 112
            jp z, dr_a112
            cp 113
            jp z, dr_a113
            cp 114
            jp z, dr_a114
            cp 115
            jp z, dr_a115
            cp 116
            jr z, dr_a116
            or a
            ret
; 116: RAMDISC's call (BDOS 130) - fcb = its block in the slot (op, letter or number): op 0
; 111, 2 112 (dma = the page, drive its RAM setting), 1 113 (none left: 1), 3 115 (fcb + 1)
dr_a116:
            ld hl, (D_P + 2)
            ld de, D_LINE
            ld iy, (d_self)
            ld a, 2
            call dr_fromslot
            ld hl, (D_P + 2)
            inc hl
            ld a, (D_LINE)
            cp 3
            jr nz, dr_a6_l
            ld (D_P + 2), hl
            jp dr_a115
dr_a6_l:
            ld hl, (D_LINE + 1)
            ld h, 0
            ld (D_P + 2), hl        ; the letter
            or a
            jp z, dr_a111
            cp 1
            jp z, dr_a113
            ld hl, (D_P + 8)
            ld (D_P + 2), hl
            ld hl, (D_P + 10)
            ld (D_P + 6), hl
            jp dr_a112
dr_a110:
            ld hl, D_POOL           ; the tables cleared
            ld de, D_POOL + 1
            ld bc, D_P - D_POOL - 1
            ld (hl), 0
            ldir
            ld hl, D_ZERO
            ld de, D_ZERO + 1
            ld bc, #8000 - D_ZERO - 1
            ld (hl), 0
            ldir
            ld hl, #FFFF            ; block 0: never used
            ld (D_FAT), hl
            xor a
            ld (d_hact), a
            call dr_sig
            jp dr_ret
dr_a111:
            ld a, (D_P + 2)
            call dr_vol
            ld a, 1
            jp c, dr_ret
            ld hl, D_VOL
            ld b, 8
dr_a1_lp:
            ld a, (hl)
            or a
            jr z, dr_a1_new
            ld de, 16
            add hl, de
            djnz dr_a1_lp
            ld a, 2
            jp dr_ret
dr_a1_new:
            ld a, 8
            sub b
            ld (d_addv), a
            push hl
            ld b, 16
dr_a1_z:
            ld (hl), 0
            inc hl
            djnz dr_a1_z
            pop hl
            ld a, (D_P + 2)
            ld (hl), a
            xor a
            call dr_sig
            jp dr_ret
dr_a112:
            ld hl, D_POOL
            ld bc, 0                ; its first block
dr_a2_lp:
            ld a, (hl)
            or a
            jr z, dr_a2_free
            ld de, 6
            add hl, de
            ex de, hl
            ld hl, 8
            add hl, bc
            ld b, h
            ld c, l
            ex de, hl
            ld a, h
            cp high (D_POOL + 256 * 6)
            jr c, dr_a2_lp
            ld a, 2
            jp dr_ret
dr_a2_free:
            ld a, (d_addv)
            inc a
            ld (hl), a
            inc hl
            inc hl
            ld de, (D_P + 2)        ; the page
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (D_P + 6)        ; its RAM setting: its bank's (C2) made its own (C4 - C7: pages
            ld a, (D_P + 2)         ; 2-5 are bank 1's, 6-9 bank 2's ...)
            sub 2
            and 3
            add a, 4
            ld d, a
            ld a, e
            and #F8
            or d
            ld (hl), a
            inc hl
            ld a, (D_P + 7)
            ld (hl), a
            push bc
            call dr_fat             ; its 8 blocks free (block 0 never)
            ld b, 16
dr_a2_z:
            ld (hl), 0
            inc hl
            djnz dr_a2_z
            ld hl, #FFFF
            ld (D_FAT), hl
            pop bc
            ld a, (d_addv)
            call dr_vpa
            inc hl
            inc hl
            ld de, 8
            ld a, b
            or c
            jr nz, dr_a2_8
            dec de                  ; (7 free: block 0)
dr_a2_8:
            ld c, (hl)              ; blocks += 8
            inc hl
            ld b, (hl)
            push hl
            ld hl, 8
            add hl, bc
            ld b, h
            ld c, l
            pop hl
            ld (hl), b
            dec hl
            ld (hl), c
            inc hl
            inc hl
            ld c, (hl)              ; free += 8 (7)
            inc hl
            ld b, (hl)
            ex de, hl
            add hl, bc
            ex de, hl
            ld (hl), d
            dec hl
            ld (hl), e
            xor a
            call dr_sig
            jp dr_ret
dr_a113:
            ld a, (D_P + 2)
            call dr_vol
            ret nc
            ld hl, D_DIR            ; its files gone
            ld a, (d_v)
            inc a
            ld c, a
            ld b, 0                 ; (256)
dr_a3_d:
            ld a, (hl)
            cp c
            jr nz, dr_a3_dn
            ld (hl), 0
dr_a3_dn:
            ld de, 20
            add hl, de
            djnz dr_a3_d
            ld hl, D_POOL
dr_a3_p:
            ld a, (hl)
            cp c
            jr z, dr_a3_one
            ld de, 6
            add hl, de
            ld a, h
            cp high (D_POOL + 256 * 6)
            jr c, dr_a3_p
            call dr_vp              ; no pages left: the RAM disc gone
            ld (hl), 0
            ld a, 1
            call dr_sig
            jp dr_ret
dr_a3_one:
            ld (hl), 0
            inc hl
            inc hl
            ld e, (hl)
            inc hl
            ld a, (hl)
            or #80                  ; (+ #8000: a page)
            ld d, a
            ex de, hl
            call dr_sig
            scf
            ret
dr_a114:
            ld a, (D_P + 2)
            call dr_vol
            ret nc
            xor a
            jp dr_ret
dr_a115:
            ld hl, (D_P + 2)        ; its number from the slot's buffer
            ld de, D_LINE
            ld iy, (d_self)
            ld a, 1
            call dr_fromslot
            ld a, (D_LINE)
            ld b, a
            ld hl, D_VOL
dr_a5_lp:
            ld a, (hl)
            or a
            jr z, dr_a5_nx
            dec b
            jp m, dr_a5_got
dr_a5_nx:
            ld de, 16
            add hl, de
            ld a, l
            cp low (D_VOL + 8 * 16)
            jr nz, dr_a5_lp
            ld a, 255
            jp dr_ret
dr_a5_got:
            call dr_vol             ; (its letter)
            ld hl, D_LINE + 1
            ld (d_lp), hl
            call dr_vp
            ld a, (hl)
            call dr_putc
            ld a, ':'
            call dr_putc
            ld a, ' '
            call dr_putc
            call dr_vp
            inc hl
            inc hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            add hl, hl
            call dr_dec
            ld a, 'K'
            call dr_putc
            ld a, ','
            call dr_putc
            ld a, ' '
            call dr_putc
            ld a, '?'
            ld hl, D_PAT
            ld b, 11
dr_a5_q:
            ld (hl), a
            inc hl
            djnz dr_a5_q
            ld hl, 0
            ld (d_got), hl
            xor a
dr_a5_f:
            call dr_find
            jr nc, dr_a5_fc
            ld hl, (d_got)
            inc hl
            ld (d_got), hl
            inc a
            jr nz, dr_a5_f
dr_a5_fc:
            ld hl, (d_got)
            call dr_dec
            ld hl, dr_t_files
            call dr_puts
            call dr_vp
            ld de, 4
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            add hl, hl
            call dr_dec
            ld hl, dr_t_freek
            call dr_puts
            ld hl, (d_lp)           ; length, then the line, to the slot
            ld de, D_LINE + 1
            or a
            sbc hl, de
            ld a, l
            ld (D_LINE), a
            inc a
            ld de, (D_P + 2)
            inc de
            ld hl, D_LINE
            ld ix, (d_self)
            call dr_toslot
            xor a
            jp dr_ret
dr_t_freek: db "K free", 0

d_f:        db 0
d_v:        db 0                    ; the call's RAM disc (0-7)
d_e:        dw 0                    ; its file's entry
d_i:        db 0                    ; ... its number
d_fi:       db 0
d_r:        dw 0                    ; a record
d_pos:      dw 0
d_bi:       dw 0
d_g:        dw 0
d_alloc:    db 0
d_res:      db 0
d_x:        db 0
d_k2:       db 0
d_n:        db 0
d_k:        db 0
d_sa:       dw 0
d_dst:      dw 0
d_want:     dw 0
d_got:      dw 0
d_toslot:   db 0
d_lp:       dw 0
d_lead:     db 0
d_addv:     db 0
d_hact:     db 0                    ; the hypervisor's file: open here
d_hv:       db 0                    ; ... its RAM disc, entry, record, byte in it
d_hent:     db 0
d_hrec:     dw 0
d_hoff:     db 0
dr_vars_end:
dr_end:
            ENT
dr_out:
#endasm
End Function

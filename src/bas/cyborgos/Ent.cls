' Ent - CyborgOS's FILES.DIR / NAME.HDR entries, in Z80 (BASIC for them made CyborgOS 3K bigger:
' too big for the RAM below AMSDOS's). Used by CyborgOS (RUN, DIR) and by CYBADD (it writes
' FILES.DIR); a program gets only the ones it calls. An entry is 64 bytes:
'   0      1 a file (0 unused; 2 a virtual directory - not yet)
'   1-11   its name on the disc, CP/M style: 8 + 3, capitals, spaces after
'   12     what it is: 1 a CP/M .COM, 0 other (a CPC .BIN ...)
'   13     flags (bit 0: it runs in CyborgOS)
'   14-15  its length in bytes
'   16-17  load address, 18-19 exec address (#0100 for a .COM)
'   20     the virtual directory it is in (0: the top; not yet), 21 a directory's own number
'   22-23  (nothing yet)
'   24-61  its long name (38 characters at most, 0 after)
'   62-63  the sum of bytes 0-61 (a damaged entry is not used)
Option Explicit
Private en(11) As Byte             ' SetName: a name as CP/M has it (8 + 3, spaces after); en(11): 1 = .COM
Private hsp As Integer             ' the thread's SP while on the real stack (Show)

' SetName(p, n): the name at p (n characters, capitals: NAME or NAME.EXT; no extension = .COM)
' made 8 + 3, for Length and Make
Public Sub SetName(ByVal p As Integer, ByVal n As Integer)
#asm
            ld hl, {en}
            ld b, 11
es_sp:
            ld (hl), ' '
            inc hl
            djnz es_sp
            ld (hl), 0              ; en(11): .COM?
            ld hl, ({p})
            ld a, ({n})
            ld c, a
            ld de, {en}
            ld b, 8
es_nm:
            ld a, c                 ; the name: up to "." (8 characters at most kept)
            or a
            jr z, es_noext
            ld a, (hl)
            inc hl
            dec c
            cp '.'
            jr z, es_ext
            inc b
            dec b
            jr z, es_nm
            ld (de), a
            inc de
            dec b
            jr es_nm
es_noext:
            ld hl, es_com
            ld c, 3
es_ext:
            ld de, {en} + 8
            ld b, 3
es_ex:
            ld a, c
            or a
            jr z, es_chk
            ld a, (hl)
            ld (de), a
            inc hl
            inc de
            dec c
            djnz es_ex
es_chk:
            ld hl, {en} + 8
            ld de, es_com
            ld b, 3
es_ck:
            ld a, (de)
            cp (hl)
            jr nz, es_done
            inc hl
            inc de
            djnz es_ck
            ld a, 1
            ld ({en} + 11), a
            jr es_done
es_com:     db "COM"
es_done:
#endasm
End Sub

' Length(p, s, n): the entry at p is a good one (kind 1, a CP/M .COM that runs here, its sum
' right, #F400 bytes at most) for SetName's name, or with the long name at s (n characters): its
' length, else 0
Public Function Length(ByVal p As Integer, ByVal s As Integer, ByVal n As Integer) As Integer
#asm
            ld hl, 0
            ld ({result}), hl
            ld hl, ({p})
            ld a, (hl)
            dec a
            jr nz, ei_done          ; not a file
            ld de, 12
            add hl, de
            ld a, (hl)
            dec a
            jr nz, ei_done          ; not a CP/M .COM
            inc hl
            bit 0, (hl)
            jr z, ei_done           ; not to run here
            ld hl, ({p})            ; the sum of bytes 0-61 = bytes 62-63
            ld de, 0
            ld b, 62
ei_sum:
            ld a, (hl)
            add a, e
            ld e, a
            jr nc, ei_s1
            inc d
ei_s1:
            inc hl
            djnz ei_sum
            ld a, (hl)
            cp e
            jr nz, ei_done
            inc hl
            ld a, (hl)
            cp d
            jr nz, ei_done
            ld hl, ({p})            ; the disc name
            inc hl
            ld de, {en}
            ld b, 11
ei_nm:
            ld a, (de)
            cp (hl)
            jr nz, ei_long
            inc hl
            inc de
            djnz ei_nm
            jr ei_yes
ei_long:
            ld a, ({n})             ; the long name: n characters, then a 0 (or all 38)
            or a
            jr z, ei_done
            cp 39
            jr nc, ei_done
            ld b, a
            ld hl, ({p})
            ld de, 24
            add hl, de
            ld de, ({s})
ei_ln:
            ld a, (de)
            cp (hl)
            jr nz, ei_done
            inc hl
            inc de
            djnz ei_ln
            ld a, ({n})
            cp 38
            jr z, ei_yes
            ld a, (hl)
            or a
            jr nz, ei_done
ei_yes:
            ld hl, ({p})
            ld de, 14
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, #F400            ; more than #0100-#F4FF: not used
            or a
            sbc hl, de
            jr c, ei_done
            ld ({result}), de
ei_done:
#endasm
End Function

' Make(p, s, n, size): the entry at p made for SetName's name: a file, CP/M .COM (when it is
' one), runs here, size bytes, loaded and run at #0100, long name at s (n characters, 38 kept)
Public Sub Make(ByVal p As Integer, ByVal s As Integer, ByVal n As Integer, ByVal size As Integer)
#asm
            ld hl, ({p})
            ld b, 64
em_z:
            ld (hl), 0
            inc hl
            djnz em_z
            ld hl, ({p})
            ld (hl), 1              ; a file
            inc hl
            ex de, hl
            ld hl, {en}
            ld bc, 11
            ldir                    ; its disc name
            ld a, ({en} + 11)
            ld (de), a              ; 12: a CP/M .COM
            inc de
            ld a, 1
            ld (de), a              ; 13: runs here
            inc de
            ld hl, ({size})
            ex de, hl
            ld (hl), e              ; 14-15: its length
            inc hl
            ld (hl), d
            inc hl
            inc hl
            ld (hl), 1              ; 16-17: load at #0100
            inc hl
            inc hl
            ld (hl), 1              ; 18-19: run at #0100
            ld hl, ({p})
            ld de, 24
            add hl, de
            ex de, hl
            ld a, ({n})
            cp 39
            jr c, em_ln
            ld a, 38
em_ln:
            or a
            jr z, em_sum
            ld c, a
            ld b, 0
            ld hl, ({s})
            ldir                    ; 24-61: its long name
em_sum:
            ld hl, ({p})
            ld de, 0
            ld b, 62
em_s:
            ld a, (hl)
            add a, e
            ld e, a
            jr nc, em_s1
            inc d
em_s1:
            inc hl
            djnz em_s
            ld (hl), e              ; 62-63: the sum of 0-61
            inc hl
            ld (hl), d
#endasm
End Sub

' DiscName(p, d): the entry at p's disc name written at d as NAME.EXT: its length
Public Function DiscName(ByVal p As Integer, ByVal d As Integer) As Integer
#asm
            ld hl, ({p})
            inc hl
            ld de, ({d})
            ld bc, #0800            ; B: 8 name characters, C: the count
ed_nm:
            ld a, (hl)
            inc hl
            cp ' ' + 1
            jr c, ed_n1
            ld (de), a
            inc de
            inc c
ed_n1:
            djnz ed_nm
            ld a, (hl)
            cp ' ' + 1
            jr c, ed_done
            ld a, '.'
            ld (de), a
            inc de
            inc c
            ld b, 3
ed_ex:
            ld a, (hl)
            inc hl
            cp ' ' + 1
            jr c, ed_e1
            ld (de), a
            inc de
            inc c
ed_e1:
            djnz ed_ex
ed_done:
            ld l, c
            ld h, 0
            ld ({result}), hl
#endasm
End Function

' Where(p, m): where in the m bytes of entries at p one has SetName's disc name (0, 64 ...), or m
Public Function Where(ByVal p As Integer, ByVal m As Integer) As Integer
#asm
            ld bc, 0                ; the offset
ea_lp:
            ld hl, ({m})
            or a
            sbc hl, bc
            jr z, ea_done           ; none
            ld hl, ({p})            ; this entry's disc name
            inc hl
            ld de, {en}
            ld a, 11
ea_nm:
            ex af, af'
            ld a, (de)
            cp (hl)
            jr nz, ea_next
            inc hl
            inc de
            ex af, af'
            dec a
            jr nz, ea_nm
            jr ea_done
ea_next:
            ld hl, ({p})
            ld de, 64
            add hl, de
            ld ({p}), hl
            ld hl, 64
            add hl, bc
            ld b, h
            ld c, l
            jr ea_lp
ea_done:
            ld ({result}), bc
#endasm
End Function


' Show(p, d): the entry at p as a line at d - "NAME.EXT     1152  LONGNAME" (the length in
' bytes): its length in characters, 0 for an unused or damaged entry (DIR lists FILES.DIR)
Public Function Show(ByVal p As Integer, ByVal d As Integer) As Integer
#asm
            ld ({hsp}), sp          ; (subroutine calls: the real stack)
            ld sp, (ntc_csp)
            ld hl, 0
            ld ({result}), hl
            ld hl, ({p})
            ld a, (hl)
            dec a
            jp nz, el_done          ; not a file
            ld de, 0                ; the sum of bytes 0-61 = bytes 62-63
            ld b, 62
el_sum:
            ld a, (hl)
            add a, e
            ld e, a
            jr nc, el_s1
            inc d
el_s1:
            inc hl
            djnz el_sum
            ld a, (hl)
            cp e
            jp nz, el_done
            inc hl
            ld a, (hl)
            cp d
            jp nz, el_done
            ld hl, ({d})            ; 13 spaces, then the disc name over them
            ld b, 13
el_sp:
            ld (hl), ' '
            inc hl
            djnz el_sp
            ld de, ({d})
            ld hl, ({p})
            inc hl
            ld b, 8
el_nm:
            ld a, (hl)
            inc hl
            cp ' ' + 1
            jr c, el_n1
            ld (de), a
            inc de
el_n1:
            djnz el_nm
            ld a, '.'
            ld (de), a
            inc de
            ld b, 3
el_ex:
            ld a, (hl)
            inc hl
            ld (de), a
            inc de
            djnz el_ex
            ld de, ({d})            ; the length in decimal, 5 wide, after column 13
            ld hl, 13
            add hl, de
            ex de, hl
            ld hl, ({p})
            ld bc, 14
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld bc, -10000
            call el_dig
            ld bc, -1000
            call el_dig
            ld bc, -100
            call el_dig
            ld bc, -10
            call el_dig
            ld a, l
            add a, '0'
            ld (de), a
            inc de
            ld a, ' '
            ld (de), a
            inc de
            ld (de), a
            inc de
            ld hl, ({p})            ; the long name
            ld bc, 24
            add hl, bc
            ld b, 38
el_ln:
            ld a, (hl)
            or a
            jr z, el_end
            ld (de), a
            inc hl
            inc de
            djnz el_ln
el_end:
            ex de, hl
            ld de, ({d})
            or a
            sbc hl, de
            ld ({result}), hl
            jr el_done
el_dig:                             ; HL / -BC: one digit at DE (a space for a leading 0)
            ld a, '0' - 1
el_dl:
            inc a
            add hl, bc
            jr c, el_dl
            sbc hl, bc
            cp '0'
            jr nz, el_dput
            ld a, ({result})        ; (0 until a digit has been written)
            or a
            ld a, ' '
            jr z, el_dsp
            ld a, '0'
el_dput:
            push af
            ld a, 1
            ld ({result}), a
            pop af
el_dsp:
            ld (de), a
            inc de
            ret
el_done:
            ld sp, ({hsp})
#endasm
End Function

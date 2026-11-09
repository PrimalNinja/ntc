' Blk - bulk copies between a data block (Option NexData) and Blk.Buf in main memory, one block switch per copy instead of one per byte.
' Resident: code in a page runs in the data window, so it can't select a block itself. Get copies n bytes of block bk from offset ofs into
' Buf from bo; Put copies Buf from bo into block bk at ofs. The window goes back to the caller's own page after.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Public Buf(1023) As Byte
Private sps As Integer

Public Sub Get(ByVal bk As Integer, ByVal ofs As Integer, ByVal bo As Integer, ByVal n As Integer)
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, ({bk})
            ld de, ntc_nexdata + 1
            add hl, de
            ld l, (hl)
            ld h, 0
            call zxn_sel
            ld hl, ({ofs})
            ld de, #4000
            add hl, de
            ld de, {buf}
            ld bc, ({bo})
            ex de, hl
            add hl, bc
            ex de, hl
            ld bc, ({n})
            ld a, b
            or c
            jr z, bg_end
            ldir
bg_end:     ld bc, (ntc_rampt)
            call nxt_win
            ld a, #FF
            ld (zxn_selb), a
            ld sp, ({sps})
#endasm
End Sub

Public Sub Put(ByVal bk As Integer, ByVal ofs As Integer, ByVal bo As Integer, ByVal n As Integer)
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, ({bk})
            ld de, ntc_nexdata + 1
            add hl, de
            ld l, (hl)
            ld h, 0
            call zxn_sel
            ld de, ({ofs})
            ld hl, #4000
            add hl, de
            ex de, hl
            ld hl, {buf}
            ld bc, ({bo})
            add hl, bc
            ld bc, ({n})
            ld a, b
            or c
            jr z, bp_end
            ldir
bp_end:     ld bc, (ntc_rampt)
            call nxt_win
            ld a, #FF
            ld (zxn_selb), a
            ld sp, ({sps})
#endasm
End Sub

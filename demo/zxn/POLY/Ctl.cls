' Ctl - POLY's controls, all read at once
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'   Read(), Elite's keys: Dive (S, 7, stick up) + Climb (X, 6, stick down) + RollL (N - the comma
'   key, 5, stick left) + RollR (M - the full stop, 8, stick right) + Faster (Space, fire) +
'   Slower (V - the slash) + YawL (Z) + YawR (C) + Auto (H)
Option Explicit

Public Const Dive = 1, Climb = 2, RollL = 4, RollR = 8, Faster = 16, Slower = 32, YawL = 64, YawR = 128, Auto = 256

Public Function Read() As Integer
#asm
            ld de, 0
            ld bc, #FDFE            ; A S D F G: S dive
            in a, (c)
            bit 1, a
            jr nz, rd_s
            set 0, e
rd_s:
            ld b, #FE               ; Caps Z X C V: X climb, Z C turn, V slower
            in a, (c)
            bit 2, a
            jr nz, rd_x
            set 1, e
rd_x:
            bit 1, a
            jr nz, rd_z
            set 6, e
rd_z:
            bit 3, a
            jr nz, rd_c
            set 7, e
rd_c:
            bit 4, a
            jr nz, rd_v
            set 5, e
rd_v:
            ld b, #7F               ; Space Sym M N B: N (,) roll left, M (.) roll right, Space faster
            in a, (c)
            bit 3, a
            jr nz, rd_n
            set 2, e
rd_n:
            bit 2, a
            jr nz, rd_m
            set 3, e
rd_m:
            rra
            jr c, rd_sp
            set 4, e
rd_sp:
            ld b, #F7               ; 1 2 3 4 5: 5 roll left
            in a, (c)
            bit 4, a
            jr nz, rd_5
            set 2, e
rd_5:
            ld b, #EF               ; 0 9 8 7 6: 8 roll right, 7 dive, 6 climb
            in a, (c)
            bit 2, a
            jr nz, rd_8
            set 3, e
rd_8:
            bit 3, a
            jr nz, rd_7
            set 0, e
rd_7:
            bit 4, a
            jr nz, rd_6
            set 1, e
rd_6:
            ld b, #BF               ; Enter L K J H: H the autopilot
            in a, (c)
            bit 4, a
            jr nz, rd_h
            set 0, d
rd_h:
            ld bc, #001F            ; Kempston: right left down up fire
            in a, (c)
            cp #FF                  ; (nothing there: #FF)
            jr z, rd_k
            rra
            jr nc, rd_kr
            set 3, e
rd_kr:
            rra
            jr nc, rd_kl
            set 2, e
rd_kl:
            rra
            jr nc, rd_kd
            set 1, e
rd_kd:
            rra
            jr nc, rd_ku
            set 0, e
rd_ku:
            rra
            jr nc, rd_k
            set 4, e
rd_k:
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' Dat - the class test's palettes (A_PAL.BIN: tools/neogeo/ngtiles.js makes it), in the program's
' ROM. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

' Pal(): the palettes' address: the sprites' (16 words), then the backdrop's 224
Public Function Pal() As Long
#asm
            movea.l (sp)+, a0
            move.l #dt_pal, (a0)
            bra dt_end
            even
dt_pal:
            incbin "A_PAL.BIN"
            even
dt_end:
#endasm
End Function

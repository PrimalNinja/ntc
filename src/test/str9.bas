' BDOS 9 under CyborgOS: a "$" string longer than 128 bytes, with a line end in it
Print "s9 start"
#asm
            ld de, s9_txt
            ld c, 9
            call 5
            jp s9_go
s9_txt:     db "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA", 13, 10
            db "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB", 13, 10
            db "s9 tail ok", 13, 10, "$"
s9_go:
#endasm
Print "s9 end"

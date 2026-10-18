; vt52t - CyborgOS's console, VT52 (regress.sh): three rows, then ESC Y + K (the first cut at
; column 2), ESC M on the second (the third up), ESC L on the first (a blank row in), ESC A / C
; and an X, ESC J below; then waits for a key (the screen as it is)
            org #0100
            ld de, m1
            call str
            ld de, m2
            call str
            jp 0
str:        ld c, 9
            jp 5
m1:         db 27, "E", "AAAAAAAA", 13, 10, "BBBBBBBB", 13, 10, "CCCCCCCC", 13, 10, "DDDDDDDD"
            db 27, "Y", 32, 34, 27, "K"           ; row 0 col 2: AA
            db 27, "Y", 33, 32, 27, "M"           ; row 1: B gone, C D up
            db 27, "Y", 32, 32, 27, "L"           ; row 0: a blank row in
            db 27, "Y", 34, 37, 27, "A", 27, "C", "X"   ; row 2 col 5, up, right: X at row 1 col 6 (36 would be BDOS 9 end)
            db 27, "Y", 35, 33, 27, "J"           ; row 3 col 1 to the end: D, then nothing
            db "$"
m2:         db 27, "Y", 38, 32, "vt52 done$"

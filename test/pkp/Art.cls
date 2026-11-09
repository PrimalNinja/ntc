' Art: a page class whose PUBLIC asm keywords are called straight from main (far).
' Fill pokes 42 into #A000 (main RAM, above the window); Val returns 42. Both bodies
' live in this class's page, so a far call must switch the page in first.
Public Sub Fill()
#asm
            ld hl, 42
            ld (#A000), hl
#endasm
End Sub
Public Function Val() As Integer
#asm
            pop hl
            ld de, 42
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

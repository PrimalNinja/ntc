' Vic - the MEGA65's VIC-IV as a game screen: 320 x 200 in 256 colours, two buffers, sprites
' drawn by the CPU, stars, a text layer. NTC platform class: MEGA65 (45GS02)
'
' Vic.Screen 1 turns it on (Vic.Screen 0 or Mode: the console again). Then once a frame:
' set the sprites (Vic.Sprite), Print the text you want (Locate, Print: 40 x 25, in the pen
' colour), and call Vic.Update: it draws the next picture into the buffer not on show - the
' playfield cleared, the stars, the sprites (79 first: sprite 0 is in front), the text - and
' shows it at the next frame (it waits for it: Vic.Update is the game loop's Frame).
' The playfield is the left Vic.Field columns (8 pixels each); the panel to the right of it
' is not cleared: its text is drawn when it changes, on the paper colour, and Vic.Stamp and
' Vic.Box draw into it (into both buffers). Sprites are clipped to the playfield.
' Images (Vic.Images: a table with each image's address): w, h (pixels; h even, 32 at most),
' then w columns of h / 2 bytes, two pixels a byte (the low nybble the upper one): 0 clear,
' 1-15 a colour, shown as palette entry 16 + the sprite's palette * 16 + it. Colours 0-15 are
' the C64's; Vic.Color sets 16-255 (&HRGB, 4 bits each).

Public Const FlipX = 1
Public Const FlipY = 2
Public Const Palette = 16           ' * 0-3: the colours 16-31, 32-47, 48-63, 64-79
Public Const Sprites = 80           ' sprites 0-79
Public Const Width = 320
Public Const Height = 200

' 1 = the graphics screen on (cleared), 0 = off (the console, 80 columns)
Public Sub Screen(ByVal onoff As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta z_t0
            NTC_RS
            lda z_t0
            jsr ntc_vic_screen
            NTC_TS
#endasm
End Sub

' the playfield's width in columns of 8 pixels (1-40; 32 at the start): sprites, stars and
' the clearing stay in it
Public Sub Field(ByVal cols As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_vic_fw
            sta ntc_vic_fpx
            lda #0
            sta ntc_vic_fpx+1
            asl ntc_vic_fpx
            rol ntc_vic_fpx+1
            asl ntc_vic_fpx
            rol ntc_vic_fpx+1
            asl ntc_vic_fpx
            rol ntc_vic_fpx+1
#endasm
End Sub

' palette entry n (16-255) = rgb (&HRGB)
Public Sub Color(ByVal n As Integer, ByVal rgb As Integer)
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            sta z_t0
            lda (z_p1),y
            sta $5E
            iny
            lda (z_p1),y
            sta $5F
            NTC_RS
            ldx z_t0
            jsr ntc_vic_color
            NTC_TS
#endasm
End Sub

' count palette entries from first, from a table of &HRGB words at addr
Public Sub Colors(ByVal addr As Integer, ByVal first As Integer, ByVal count As Integer)
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            NTC_POP z_p2
            ldy #0
            lda (z_p0),y
            sta z_p3
            iny
            lda (z_p0),y
            sta z_p3+1
            dey
            lda (z_p1),y
            sta z_t0
            lda (z_p2),y
            sta z_t1
            NTC_RS
lp:
            lda z_t1
            beq done
            ldy #0
            lda (z_p3),y
            sta $5E
            iny
            lda (z_p3),y
            sta $5F
            ldx z_t0
            jsr ntc_vic_color
            inc z_t0
            inw z_p3
            inw z_p3
            dec z_t1
            jmp lp
done:
            NTC_TS
#endasm
End Sub

' the image table: the address of a list of addresses, one for each image (number 0 on)
Public Sub Images(ByVal addr As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_vic_imgs
            iny
            lda (z_p0),y
            sta ntc_vic_imgs+1
#endasm
End Sub

' sprite n (0-79) shown: image img with its top left at x, y (pixels on the screen),
' attributes attr (FlipX, FlipY, Palette * 0-3)
Public Sub Sprite(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal img As Integer, ByVal attr As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y                ; n * 8
            sta z_p1
            lda #0
            sta z_p1+1
            asl z_p1
            rol z_p1+1
            asl z_p1
            rol z_p1+1
            asl z_p1
            rol z_p1+1
            clc
            lda z_p1
            adc #<ntc_vic_sat
            sta z_p1
            lda z_p1+1
            adc #>ntc_vic_sat
            sta z_p1+1
            NTC_POP z_p0                ; x
            ldy #0
            lda (z_p0),y
            sta (z_p1),y
            iny
            lda (z_p0),y
            sta (z_p1),y
            NTC_POP z_p0                ; y
            ldy #0
            lda (z_p0),y
            ldy #2
            sta (z_p1),y
            ldy #1
            lda (z_p0),y
            ldy #3
            sta (z_p1),y
            NTC_POP z_p0                ; img
            ldy #0
            lda (z_p0),y
            ldy #4
            sta (z_p1),y
            NTC_POP z_p0                ; attr
            ldy #0
            lda (z_p0),y
            ldy #5
            sta (z_p1),y
            lda #1
            iny
            sta (z_p1),y
#endasm
End Sub

' sprite n hidden
Public Sub Hide(ByVal n As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            asl
            asl
            asl
            sta z_t0
            lda (z_p0),y
            lsr
            lsr
            lsr
            lsr
            lsr
            sta z_t1
            clc
            lda z_t0
            adc #<(ntc_vic_sat+6)
            sta z_p1
            lda z_t1
            adc #>(ntc_vic_sat+6)
            sta z_p1+1
            lda #0
            sta (z_p1),y
#endasm
End Sub

' every sprite hidden
Public Sub HideAll()
#asm
            lda #<(ntc_vic_sat+6)
            sta z_p1
            lda #>(ntc_vic_sat+6)
            sta z_p1+1
            ldx #80
            ldy #0
lp:
            tya
            sta (z_p1),y
            clc
            lda z_p1
            adc #8
            sta z_p1
            bcc nc
            inc z_p1+1
nc:
            dex
            bne lp
#endasm
End Sub

' the next picture drawn and shown at the next frame (waits for it)
Public Sub Update()
#asm
            NTC_RS
            jsr ntc_vic_update
            NTC_TS
#endasm
End Sub

' the next picture drawn into the buffer not on show, but not shown (no wait): for timing,
' or a game that shows it itself with Vic.Update later
Public Sub Draw()
#asm
            NTC_RS
            lda #1
            sta ntc_vic_noflip
            jsr ntc_vic_update
            lda #0
            sta ntc_vic_noflip
            NTC_TS
#endasm
End Sub

' image img into both buffers now at x, y (anywhere on the screen: for the panel)
Public Sub Stamp(ByVal img As Integer, ByVal x As Integer, ByVal y As Integer, ByVal attr As Integer)
#asm
            NTC_POP z_p0                ; img: its address from the table
            ldy #0
            lda (z_p0),y
            asl
            sta z_t0
            lda #0
            rol
            sta z_t1
            clc
            lda z_t0
            adc ntc_vic_imgs
            sta z_p1
            lda z_t1
            adc ntc_vic_imgs+1
            sta z_p1+1
            lda (z_p1),y
            sta $60
            iny
            lda (z_p1),y
            sta $61
            NTC_POP z_p0                ; x
            ldy #0
            lda (z_p0),y
            sta $62
            iny
            lda (z_p0),y
            sta $63
            NTC_POP z_p0                ; y
            ldy #0
            lda (z_p0),y
            sta $64
            iny
            lda (z_p0),y
            sta $65
            NTC_POP z_p0                ; attr
            ldy #0
            lda (z_p0),y
            sta $69
            and #$30
            clc
            adc #16
            sta $68
            NTC_RS
            jsr ntc_vic_stamp
            NTC_TS
#endasm
End Sub

' a filled box in both buffers now: x, y, w, h (pixels), colour (palette entry)
Public Sub Box(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal colour As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta $62
            iny
            lda (z_p0),y
            sta $63
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta $64
            iny
            lda (z_p0),y
            sta $65
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta $66
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta $67
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta $68
            NTC_RS
            lda $66
            beq none
            lda $67
            beq none
            jsr ntc_vic_box
none:
            NTC_TS
#endasm
End Sub

' the text's colour (palette entry) for what is printed from now on
Public Sub Pen(ByVal colour As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_vic_pen
#endasm
End Sub

' the colour behind the panel's text
Public Sub Paper(ByVal colour As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_vic_paper
#endasm
End Sub

' the playfield's colour (behind everything)
Public Sub Back(ByVal colour As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_vic_bg
#endasm
End Sub

' star n (0-63) at x, y (0-255: y + the scroll, 200-255 off the screen) in a colour
Public Sub Star(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal colour As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            and #63
            tax
            NTC_POP z_p0
            lda (z_p0),y
            sta ntc_vic_sx,x
            NTC_POP z_p0
            lda (z_p0),y
            sta ntc_vic_sy,x
            NTC_POP z_p0
            lda (z_p0),y
            sta ntc_vic_sc,x
#endasm
End Sub

' how many stars are shown (0-64)
Public Sub Stars(ByVal n As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_vic_starn
#endasm
End Sub

' the stars' scroll: added to each star's y (wraps at 256)
Public Sub StarScroll(ByVal y As Integer)
#asm
            NTC_POP z_p0
            ldy #0
            lda (z_p0),y
            sta ntc_vic_stary
#endasm
End Sub

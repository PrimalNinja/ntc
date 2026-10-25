' StdIO - the console: screen and keyboard. NTC platform class: Amstrad CPC, the console on an MSX V9938 card (AMSDAP)
'
' Print, Input, Inkey, Inkey$, Cls, Locate and Mode use the same routines, so these
' methods and the BASIC statements can be mixed. Each method's body is only #asm, so it is
' a keyword: StdIO.PutStr s compiles to one thread word plus the argument, no procedure call.
'
' Your own StdIO class: put a StdIO.cls in the project and it replaces this one, and the
' console statements (Print, Input, Inkey, Inkey$, Cls, Locate, Mode) then call its methods:
' PutStr, PutChar, NewLine, Tab, GetLine, GetKey, Cls, Locate, Mode. Copy this file to start.

' ---- what this console can do (constants, worked out when compiling)
Public Const CanPosition = True      ' Locate and the cursor position work
Public Const CanClear = True       ' Cls clears (else it starts a new line)
Public Const CanInput = True         ' there is a keyboard
Public Const CanPoll = True         ' GetKey / Inkey look without waiting
Public Const CanColour = False        ' pen / paper colours (not yet)
Public Const Glyphs = False         ' the program draws the text itself (no: the video chip draws it)
Public Const Rows = 24            ' text rows, 0 = a stream with no bottom edge

' ---- output
Public Sub PutChar(ByVal c As Integer)
#asm
            pop hl
            ld a, (hl)
            ld ix, ntc_next
            cp 13
            jp z, ntc_plat_newline
            jp ntc_plat_putc
#endasm
End Sub

Public Sub PutStr(ByVal s As String)
#asm
            pop hl
            ld (ntc_sptr), hl
            jp ntc_printbuf
#endasm
End Sub

Public Sub PutInt(ByVal n As Integer)
#asm
            jp kw_printint
#endasm
End Sub

Public Sub NewLine()
#asm
            ld ix, ntc_next
            jp ntc_plat_newline
#endasm
End Sub

Public Sub Tab(ByVal col As Integer)
#asm
            jp kw_printtab
#endasm
End Sub

' ---- input
Public Function GetChar() As Integer
#asm
            pop hl              ; the result
            ld (ntc_ivar), hl
            ld ix, got
            jp ntc_plat_getkey
got:
            ld hl, (ntc_ivar)
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

Public Function GetKey() As Integer
#asm
            jp kw_inkey
#endasm
End Function

Public Sub GetLine(s As String)
#asm
            jp kw_inputstr
#endasm
End Sub

' ---- screen
Public Sub Cls()
#asm
            jp kw_cls
#endasm
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
#asm
            jp kw_locatevv
#endasm
End Sub

Public Sub Mode(ByVal m As Integer)
#asm
            jp kw_modev
#endasm
End Sub

Public Function Cols() As Integer
#asm
            pop hl
            ld a, (ntc_scols)
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

Public Function Column() As Integer
#asm
            pop hl              ; 1 based, like Locate
            ld a, (ntc_curx)
            inc a
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

Public Function Row() As Integer
#asm
            pop hl
            ld a, (ntc_cury)
            inc a
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

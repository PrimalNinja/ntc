' gfx.bas - the Graphics class's test, the same on every platform: a frame round the screen,
' the two diagonals, a line drawn twice (XOR: gone again), a dot, and a line off the screen
' (clipped: not drawn).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Dim w As Integer, h As Integer

Graphics.Pen 1
w = Graphics.Width()
h = Graphics.Height()
Graphics.Line 0, 0, w - 1, 0
Graphics.Line w - 1, 0, w - 1, h - 1
Graphics.Line w - 1, h - 1, 0, h - 1
Graphics.Line 0, h - 1, 0, 0
Graphics.Line 2, 2, w - 3, h - 3
Graphics.Line 2, h - 3, w - 3, 2
Graphics.Line 4, h \ 2, w \ 4, h \ 2
Graphics.Line 4, h \ 2, w \ 4, h \ 2
Graphics.Plot w \ 2, 4
Graphics.Line 0, 0, w, h
Graphics.Line -1, 5, 10, 5
Print "GFX"; w; h
Do
Loop

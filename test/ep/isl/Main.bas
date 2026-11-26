' Interrupt classes on the ep128 platform (test/epregress.sh): the frame interrupt, 50 a second.
' Three classes - 50 a second, 10 a second, every frame - counted over two seconds.
Dim t0 As Integer
t0 = Ticks
Do : Frame : Loop Until Ticks - t0 >= 100
Print "fifty"; Fifty.Count >= 90; Fifty.Count <= 105; " ten"; Ten.Count >= 17; Ten.Count <= 22; " frames"; Frames.Count >= 90
Print "ten<fifty "; Ten.Count < Fifty.Count
Print "done"
End

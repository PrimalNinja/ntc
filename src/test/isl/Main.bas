' Interrupt classes checks (regress.sh): cpc / cpcmin, normal mode
Dim t0 As Integer, i As Integer
t0 = Ticks
Do : Frame : Loop Until Ticks - t0 >= 300
Print "music"; Music.Beats > 40; Music.Beats < 60; " fast"; Fast.Count > 250; " slow"; Slow.Count <= 1; " frames"; Frames.Count > 0
Print "beats<=fast "; Music.Beats < Fast.Count
Print "done"

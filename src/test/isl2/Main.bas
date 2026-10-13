' Interrupt classes past 4, and shared classes (regress.sh): two fixed classes, six shared ones
' with weights 1, 1, 2, 2, 3, 3 that take turns in the interrupts the fixed ones leave
Dim t0 As Integer
t0 = Ticks
Do : Frame : Loop Until Ticks - t0 >= 300
Print "fixed "; F50.Count > 40; F50.Count < 60; F10.Count > 5; F10.Count < 15
Print "shared all run "; S1a.Count > 0; S1b.Count > 0; S2a.Count > 0; S2b.Count > 0; S3a.Count > 0; S3b.Count > 0
Print "weights "; S2a.Count > S1a.Count; S3a.Count > S2a.Count; S1a.Count + 2 >= S1b.Count; S1b.Count + 2 >= S1a.Count
Print "done"

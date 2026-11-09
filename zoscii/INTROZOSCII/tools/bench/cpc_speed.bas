Randomize 1234
Dim rm(1023), cn(255),ofs(255), fl(255), ad(1023), en(63), de(63)
Dim i, c, k, n, run
For i = 0 To 1023 : rm(i) = Rnd(256) : Next
For i = 0 To 1023 : c = rm(i) : cn(c) = cn(c) + 1 : Next
run = 0
For i = 0 To 255 : ofs(i) = run : run = run + cn(i) : Next
For i = 0 To 1023 : c = rm(i) : ad(ofs(c) + fl(c)) = i : fl(c) = fl(c) + 1 : Next
For n = 1 To ITER
  For i = 0 To 63
    c = 65 : k = cn(c)
    If k > 0 Then en(i) = ad(ofs(c) + Rnd(k))
  Next
Next
For n = 1 To ITERD
  For i = 0 To 63 : de(i) = rm(en(i)) : Next
Next
Print de(0); de(63)
End

' a tiny program: at org #0040 its font lands below #0100 (glyph words must not be taken for control words)
GoSub hello
GoSub hello
Print
Print "a b c"
End
hello:
  Print "hi ";
  Return

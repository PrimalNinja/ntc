' TICKER: a CyborgOS test program (build for cpm): counts, printing every 500th, until a key
Option Explicit
Dim i As Long, k As Integer
Print "Ticker - a key ends it"
Do
  i = i + 1
  If i Mod 500 = 0 Then Print "tick"; i
  k = Inkey
Loop Until k <> 0
Print "Ticker done, key"; k

' NTC self test - each check prints its number and ok or FAIL
' got = result, want = expected, then GOSUB chk
CLS
PRINT "NTC self test"
t = 0 : bad = 0

' ---- arithmetic and precedence
got = 10 - 2 * 3 + 4 : want = 8 : GOSUB chk
got = 100 / 5 * 2 : want = 40 : GOSUB chk
got = 10 - 2 - 3 : want = 5 : GOSUB chk
got = (6 + 3) * 4 / (2 - 9) : want = -5 : GOSUB chk
got = -7 / 2 : want = -3 : GOSUB chk
got = -7 MOD 2 : want = -1 : GOSUB chk
got = 7 MOD -2 : want = 1 : GOSUB chk
a = 7 : b = -3
got = a * b + a \ b : want = -23 : GOSUB chk
got = -a * -b : want = -21 : GOSUB chk
got = 32767 + 1 : want = -32768 : GOSUB chk
got = ABS(b) + SGN(b) : want = 2 : GOSUB chk

' ---- compares and logic
got = (a > b) : want = -1 : GOSUB chk
got = (a < b) : want = 0 : GOSUB chk
got = (a >= 7 AND b <= -3) : want = -1 : GOSUB chk
got = (a = 1 OR b = 1) : want = 0 : GOSUB chk
got = NOT 0 : want = -1 : GOSUB chk
got = &HF0 AND &H3C : want = &H30 : GOSUB chk
got = 5 XOR 3 : want = 6 : GOSUB chk

' ---- loops
s = 0 : FOR i = 1 TO 10 : s = s + i : NEXT
got = s : want = 55 : GOSUB chk
s = 0 : FOR i = 10 TO 1 STEP -3 : s = s + i : NEXT
got = s : want = 22 : GOSUB chk
s = 0 : st = 2 : FOR i = 1 TO 9 STEP st : s = s + i : NEXT
got = s : want = 25 : GOSUB chk
n = 0 : WHILE n < 7 : n = n + 1 : WEND
got = n : want = 7 : GOSUB chk
n = 0 : DO : n = n + 1 : IF n = 4 THEN EXIT DO
LOOP
got = n : want = 4 : GOSUB chk
n = 10 : DO WHILE n > 0 : n = n - 3 : LOOP
got = n : want = -2 : GOSUB chk
s = 0
FOR i = 1 TO 3 : FOR j = 1 TO 3 : s = s + i * j : NEXT j : NEXT i
got = s : want = 36 : GOSUB chk

' ---- IF forms
r = 0
IF a > 5 THEN
  IF b > 0 THEN
    r = 1
  ELSEIF b = -3 THEN
    r = 2
  ELSE
    r = 3
  END IF
END IF
got = r : want = 2 : GOSUB chk
r = 0 : IF 1 = 1 THEN IF 2 = 3 THEN r = 1 ELSE r = 2
got = r : want = 2 : GOSUB chk

' ---- GOSUB nesting
d = 0 : GOSUB lvl1
got = d : want = 111 : GOSUB chk

' ---- arrays
DIM arr(10)
FOR i = 0 TO 10 : arr(i) = i * i : NEXT
s = 0 : FOR i = 0 TO 10 : s = s + arr(i) : NEXT
got = s : want = 385 : GOSUB chk
got = arr(3) + arr(a) : want = 58 : GOSUB chk

' ---- memory
POKE &H8000, 200 : DOKE &H8002, -1234
got = PEEK(&H8000) : want = 200 : GOSUB chk
addr = &H8002 : got = DEEK(addr) : want = -1234 : GOSUB chk

' ---- strings
x$ = "abc" : y$ = x$ + "def" + x$
got = LEN(y$) : want = 9 : GOSUB chk
got = 0 : IF y$ = "abcdefabc" THEN got = 1
want = 1 : GOSUB chk
got = 0 : IF x$ <> y$ THEN got = 1
want = 1 : GOSUB chk

' ---- random
RANDOMIZE 99 : ok = 1
FOR i = 1 TO 100 : r = RND(6) : IF r < 0 OR r > 5 THEN ok = 0
NEXT
got = ok : want = 1 : GOSUB chk

PRINT
PRINT t; " tests, "; bad; " failed"

' ---- screen and keys (look at these)
PRINT "-12345 = "; -12345
INPUT "Type your name"; nm$
PRINT "Hello "; nm$; "!"
INPUT "Number"; v
PRINT v; " * 3 = "; v * 3
PRINT "Press a key";
DO : k = INKEY : FRAME : LOOP UNTIL k <> 0
PRINT " - code "; k
LOCATE 25, 25 : PRINT "bottom line";
END

chk:
  t = t + 1
  PRINT t; ":";
  IF got = want THEN PRINT "ok "; ELSE PRINT "FAIL "; : bad = bad + 1
  RETURN

lvl1: d = d + 1 : GOSUB lvl2 : RETURN
lvl2: d = d + 10 : GOSUB lvl3 : RETURN
lvl3: d = d + 100 : RETURN

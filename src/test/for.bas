n = 10 : m = -3
FOR i = 1 TO 10 : NEXT
PRINT "a"; i
FOR i = 1 TO n : s = s + i : NEXT : PRINT "b"; s; i
FOR i = n TO 1 STEP -1 : PRINT i; : NEXT : PRINT
FOR i = 1 TO n STEP 3 : PRINT i; : NEXT : PRINT
FOR i = 10 TO m STEP -4 : PRINT i; " "; : NEXT : PRINT
FOR i = 5 TO 1 : PRINT "x" : NEXT : PRINT "c"; i
FOR i = n TO 1 : PRINT "x" : NEXT : PRINT "d"; i
FOR i = m TO -1 : PRINT i; : NEXT : PRINT
FOR i = 254 TO 258 : PRINT i; " "; : NEXT : PRINT
FOR i = -2 TO 2 : PRINT i; " "; : NEXT : PRINT
st = 2 : FOR i = 1 TO 6 STEP st : PRINT i; : NEXT : PRINT

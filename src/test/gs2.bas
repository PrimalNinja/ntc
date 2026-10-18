' fallbacks: shared tail, GOTO into a sub, recursion chain, fall in from main
GOSUB s1 : GOSUB s2 : PRINT
GOSUB r1 : PRINT "r done"
GOSUB g1 : PRINT "g done"
n = 0 : GOSUB rec : PRINT "rec"; n
END
s1: PRINT "1";
s2: PRINT "2"; : RETURN
r1: PRINT "r1 "; : GOTO r1b
r1x: RETURN
g1: PRINT "g1 "; : RETURN
r1b: PRINT "r1b "; : RETURN
rec: n = n + 1 : IF n < 3 THEN GOSUB rec
RETURN

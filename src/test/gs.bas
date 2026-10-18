x = 3 : GOSUB sq : PRINT x
x = 5 : GOSUB sq : PRINT x
GOSUB outer : PRINT "back"
10 GOSUB 200
20 PRINT "a"; : GOSUB fall
GOTO done
PRINT "never"
done: PRINT "done" : END
sq: x = x * x : RETURN
outer: PRINT "o"; : GOSUB inner : PRINT "O"; : RETURN
inner: PRINT "i"; : RETURN
200 IF x > 10 THEN PRINT "big" : RETURN
210 PRINT "small" : RETURN
fall: PRINT "f";
fall2: PRINT "g"; : RETURN

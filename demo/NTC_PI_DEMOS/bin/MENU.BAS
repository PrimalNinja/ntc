10 MODE 2:PRINT "NTC PI DEMOS - CPC-CPLink / CPLink2 with CyborgOS for the Pi":PRINT
20 PRINT 1;"  PI01LINK  the card and the Pi: status, HELLO, PING, TIME, INFO, LIST"
30 PRINT 2;"  PI02STOR  the store: a tagged piece put, got back, compared; SIZE, APP"
40 PRINT 3;"  PI03BIG  data in parts: 6000 and 20000 bytes; the CPLink2's Pi ROM"
50 PRINT 4;"  PI04MATH  the maths coprocessor: EVAL, BIG, XFORM"
60 PRINT 5;"  PI05FLT  the float coprocessor: OP, ARR"
70 PRINT 6;"  PI06RUN  a command run on the Pi, its output back"
80 PRINT 7;"  PI07TERM  a shell on the Pi, the CPC its terminal"
90 PRINT 8;"  PI08VDU  the Pi's HDMI as a virtual display (mode=hd)"
100 PRINT 9;"  PI09AUD  music played by the Pi: a tone made here, PLAY, STATUS, ENDE"
110 PRINT 10;"  PI10VOX  speech: the Votrax SC-01 on the Pi"
120 PRINT 11;"  PI11DISK  Pi volumes: random access records, FIND, REN, ERA"
130 PRINT 12;"  PI12MIND  the generative model on the Pi"
140 PRINT 13;"  PI13MANY  several channels at once"
150 PRINT 14;"  PI14VDP  sprites on the Pi's HDMI (hwlib's Pi class)"
160 PRINT 15;"  PI15TILE  the vdp's tile layer, tiles from the store"
300 PRINT:INPUT "Which (1-15)";n:IF n<1 OR n>15 THEN 300
310 RESTORE:FOR i=1 TO n:READ a$:NEXT:PRINT "RUN ";a$:RUN a$
320 DATA PI01LINK,PI02STOR,PI03BIG,PI04MATH,PI05FLT,PI06RUN,PI07TERM,PI08VDU,PI09AUD,PI10VOX,PI11DISK,PI12MIND,PI13MANY,PI14VDP,PI15TILE

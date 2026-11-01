10 ' VDPDEMO - the Pi's VDP from Locomotive BASIC through Streamer (UniDOS): a sprite that
20 ' bounces, driven by the Pi; this program only sets it up and reads the events
30 ' needs: UniDOS, the Streamer ROM, a CPC-CPLink to a Pi with CyborgOS for the Pi
40 MODE 2
50 ' the channel to the Pi's VDP: the OPEN opcode (&80, length, the service text) in V9990:CMD - BASIC's
55 ' OPENOUT only chooses the stream; the Pi's answer (OK n) comes as a line on V9990:EVENTS
60 OPENOUT "V9990:CMD": o$="vdp profile=v9990 vsync=1": PRINT #9,CHR$(&80)+CHR$(LEN(o$))+o$;: CLOSEOUT
65 ' a pattern: SAVE it into V9990:PATTERNS once (a 16x16 4-bit pattern = 128 bytes; a SAVE ends the set)
70 FOR i=0 TO 127: POKE &4000+i,&11: NEXT          ' colour 1 everywhere: a square
75 SAVE "V9990:PATTERNS",B,&4000,128
80 ' the commands: SPR 1 pattern 0 at 10,10 visible, VEL 1 (3 px a frame right, 2 down), BOUNDS 1 = 4 (EDGE events)
90 OPENOUT "V9990:CMD"
100 a$=""
110 a$=a$+CHR$(1)+CHR$(1)+CHR$(0)+CHR$(0)+CHR$(0)+CHR$(10)+CHR$(0)+CHR$(10)+CHR$(0)+CHR$(1)   ' SPR id16 pat16 x16 y16 flags8
120 a$=a$+CHR$(5)+CHR$(1)+CHR$(0)+CHR$(48)+CHR$(0)+CHR$(32)+CHR$(0)                          ' VEL id16 vx16 vy16 (12.4: 48 = 3 px)
130 a$=a$+CHR$(6)+CHR$(1)+CHR$(0)+CHR$(4)                                                     ' BOUNDS id16 4 = EDGE events
140 a$=a$+CHR$(&7F)                                                                            ' COMMIT
150 PRINT #9,a$;
160 ' the events: a line each from V9990:EVENTS (V n every frame, EDGE 1 s at an edge)
170 OPENIN "V9990:EVENTS"
180 WHILE INKEY$="": LINE INPUT #9,e$: IF LEFT$(e$,4)="EDGE" THEN GOSUB 300
190 WEND
200 CLOSEIN: PRINT #9,CHR$(&81);: CLOSEOUT: END              ' &81: the channel closed on the Pi
300 ' at an edge: the velocity reversed (side 0 left 1 right 2 top 3 bottom) - one PRINT #9, the Pi does the rest
310 s=VAL(MID$(e$,8)): PRINT "edge";s
320 IF s<2 THEN vx=-vx ELSE vy=-vy
330 IF vx=0 AND vy=0 THEN vx=48:vy=32
340 b$=CHR$(5)+CHR$(1)+CHR$(0)+CHR$(vx AND 255)+CHR$((vx\256) AND 255)+CHR$(vy AND 255)+CHR$((vy\256) AND 255)+CHR$(&7F)
350 PRINT #9,b$;
360 RETURN

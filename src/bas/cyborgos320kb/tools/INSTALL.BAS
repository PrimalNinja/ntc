10 ' INSTALL: CyborgOS 320K installer (UniDOS) - its three discs (the floppy as drive B) to the folder CYBORGOS on drive A (the mass storage: IDE, SD ...). Only on cos-disk1: RUN"INSTALL
20 ' Locomotive BASIC 1.0 too: an RSX takes strings only as @var$ (p1$="X":|COPY,@p1$,@p2$). UniDOS: |SAVE,"PATH/" a folder made, |COPY a file (over one there), |DRIVE,"A","PATH" A's path
30 ' DATA from 1000: how many files, then "#n" (disc n) and its files as they go in CYBORGOS (C/..., HELP/...), "*" the end (gendsk writes them)
40 SPEED KEY 100,100:MODE 2:PRINT "CyborgOS Installer":PRINT "------------------":PRINT
50 PRINT "Map your floppy drive as drive B, and your mass storage unit (IDE, SD ...)"
60 PRINT "as drive A - UniDOS: |DRIVE,";CHR$(34);"A";CHR$(34);",";CHR$(34);"IDE:";CHR$(34);" and |DRIVE,";CHR$(34);"B";CHR$(34);",";CHR$(34);"DFA:";CHR$(34);"."
70 PRINT "CyborgOS goes in A:CYBORGOS/ - its commands in CYBORGOS/C, its help in"
75 PRINT "CYBORGOS/HELP; files there already are replaced. Three discs: cos-disk1"
78 PRINT "(this one), cos-disk2 and cos-disk3."
80 RESTORE:READ t:n=0:d=0
90 PRINT:PRINT "Press a key to start (ESC twice stops)":GOSUB 500
95 p1$="A:CYBORGOS/":|SAVE,@p1$:p1$="A:CYBORGOS/C/":|SAVE,@p1$:p1$="A:CYBORGOS/HELP/":|SAVE,@p1$
100 READ f$:IF f$="*" THEN 300
110 IF LEFT$(f$,1)<>"#" THEN 150
120 d=VAL(MID$(f$,2)):PRINT:PRINT "--- disc";d
130 IF d>1 THEN PRINT "Put CyborgOS disc";d;"(cos-disk";MID$(STR$(d),2);") in drive B, then press a key":GOSUB 500
140 GOTO 100
150 n=n+1:p1$="A:CYBORGOS/"+f$:s$=f$:k=INSTR(s$,"/"):IF k THEN s$=MID$(s$,k+1)
160 p2$="B:"+s$:|COPY,@p2$,@p1$
180 b=INT(40*n/t):PRINT "[";STRING$(b,"#");STRING$(40-b,".");"] ";:PRINT USING "###%";INT(100*n/t);:PRINT "  ";f$
190 GOTO 100
300 PRINT:PRINT "CyborgOS installed in A:CYBORGOS/ -";n;"files.":PRINT
310 PRINT "1  Run it on a real CPC":PRINT "2  Run it on WinAPE (keys repeat 10 times slower: KEYREP 10)":PRINT "3  Exit"
320 WHILE INKEY$<>"":WEND
330 k$=INKEY$:IF k$<"1" OR k$>"3" THEN 330
340 SPEED KEY 30,2:IF k$="3" THEN END
350 ' A's path the CYBORGOS folder (UniDOS keeps it), A the current drive, CyborgOS's command line to &BE80 (as CYBORGOS.BAS does), COSLOAD
360 p1$="A":p2$="CYBORGOS":|DRIVE,@p1$,@p2$:|A
370 o$="":IF k$="2" THEN o$=" KEYREP 10"
380 a$="CYB A"+o$:FOR i=1 TO LEN(a$):POKE &BE7F+i,ASC(MID$(a$,i,1)):NEXT:POKE &BE80+LEN(a$),0
390 RUN"COSLOAD.BIN"
500 ' a key (any typed before it dropped)
510 WHILE INKEY$<>"":WEND
520 WHILE INKEY$="":WEND
530 RETURN
1000 ' (gendsk puts the files here: DATA from 1000)

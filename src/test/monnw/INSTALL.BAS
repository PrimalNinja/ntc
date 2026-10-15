10 ' INSTALL: CyborgOS 320K - the files on this disc (drive B) to IDE: (each cos-disk has its own:
15 ' RUN"INSTALL with each in B; FILES.DIR, on disc 1, lists the files of all of them)
20 ' first each one erased, then each one copied from B (DATA, "*" ends it)
30 |A
40 RESTORE
50 READ f$:IF f$="*" THEN 80
60 |ERA,@f$
70 GOTO 50
80 RESTORE
90 READ f$:IF f$="*" THEN 120
100 PRINT f$:|COPY,"DFB:"+f$,"IDE:"
110 GOTO 90
120 PRINT "This disc's CyborgOS files installed on IDE:"
130 END
1010 DATA "MONNW.CYB","MONFR.CYB"
2000 DATA "*"

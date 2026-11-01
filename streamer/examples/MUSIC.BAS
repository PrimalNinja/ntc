10 ' MUSIC - a file on the Pi played by it: the MUSIC: device (the Pi's audio service). Lines are
20 ' requests; the answers come back on MUSIC:EVENTS. The file was put in the Pi's store once.
30 OPENOUT "MUSIC:CMD": o$="audio": PRINT #9,CHR$(&80)+CHR$(LEN(o$))+o$;: CLOSEOUT     ' the channel
40 OPENOUT "MUSIC:CMD"
50 PRINT #9,"VOL 70"
60 PRINT #9,"PLAY GAMES/TERRASTR/TITLE.MP3"
70 CLOSEOUT
80 OPENIN "MUSIC:EVENTS": LINE INPUT #9,a$: LINE INPUT #9,b$: CLOSEIN: PRINT a$;" ";b$
90 ' the controls, each a line: PAUSE / RESUME, SKIP 10 (SKIP -10 back), SEEK 60 (from a minute in),
95 ' PLAY tag 30 (from 30 s), LIST a b c then NEXT / PREV, STOP; EVENTS: ENDED tag, POS s (OPEN audio pos=1)

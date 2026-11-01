10 ' SPEAK - the SSA-1 (or dk'tronics) speech card through Streamer: phrases kept as BASIC
20 ' strings of SP0256-AL2 allophone codes, said with one PRINT #9. The node waits on the card's
30 ' /LRQ for each allophone, so a game goes on meanwhile. SPEECH:DKTRONIC for the other card.
40 ' allophones (SP0256-AL2): 0-4 pauses, 27 HH1, 7 EH, 45 LL, 53 OW, 1 PA2 ...
50 h$=CHR$(27)+CHR$(7)+CHR$(45)+CHR$(53)+CHR$(3)               ' "hello" and a pause
60 OPENOUT "SPEECH:SSA1"
70 PRINT #9,h$;
80 PRINT "said"
90 CLOSEOUT

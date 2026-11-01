# Streamer and the Pi - how a Locomotive BASIC program uses CyborgOS for the Pi

The Pi's services as UniDOS devices. A BASIC program opens a device's file, writes commands into
it and reads answers out of another, like any file. BASIC's OPENOUT / OPENIN / CLOSEOUT /
CLOSEIN only choose the stream; what opens or closes on the Pi is an opcode in the stream.
docs/streamer.md and docs/streamer-rom.md are the node's own documents; cyborg-os/docs/
cyborgos-pi.md and cyborgos-vdp.md the Pi's.

## 1. The devices and their paths

Every path is DEVICE:FILE - a device is a drive, its folder is the root, its files are streams
(nothing is stored on the CPC; CAT shows them at 0K). What each path takes or gives:

```
   V9990:CMD         write   the VDP command bytes (section 3) and the node's opcodes (section 2)
   V9990:PATTERNS    write   SAVE pattern data: the v9990 profile's 16 x 16 4-bit, 128 bytes a
                             pattern, as many as the SAVE holds (the PATTERNS 0 request)
   V9990:TILES       write   SAVE tile definitions: 8 x 8 4-bit, 32 bytes a tile (TILES 0)
   V9990:LAYER2      write   SAVE the bitmap layer whole: width x height at the profile's depth
                             (v9990: 256 x 212 4-bit; LAYER2)
   V9990:EVENTS      read    a line each: the answers (OK n, ERR ...), V n a frame, HIT a b,
                             EDGE id side, DIED id, DONE id, LIST's lines
   V9938:  ...               the same five: patterns 16 x 16 1-bit (32 bytes), tiles 8 x 8 1-bit
                             (8 bytes), no LAYER2 (ERR)
   ZXNEXT: ...               patterns 16 x 16 8-bit (256 bytes), tiles 8 x 8 4-bit (32 bytes),
                             LAYER2 320 x 256 8-bit (81920 bytes)
   MD:     ...               patterns 16 x 16 4-bit, tiles 8 x 8 4-bit, no LAYER2
   PI:     ...               patterns 32 x 32 RGBA (4096 bytes), tiles 8 x 8 RGBA (256 bytes),
                             LAYER2 1920 x 1080 RGBA (the pi1080 profile: 8 MB - from a store
                             tag on the Pi rather than a SAVE, when STORE: is there)

   SPEECH:SSA1       write   a string of SP0256-AL2 allophone codes, to the SSA-1 card
   SPEECH:DKTRONIC   write   the same, to the dk'tronics card (nothing comes back from a card)
   SPEECH:VOTRAX     write   SC-01 phoneme bytes (bits 0-5 the phoneme, 6-7 the inflection), to the
                             Pi's SC-01 emulation (80 OPEN votrax first)
   SPEECH:EVENTS     read    the Pi's answers (STATUS: ready / norom / off)
                             (to come: SPEECH:SP0256 the chip emulated on the Pi, SPEECH:VOICE a
                             human-like voice - the same device, a file each)

   MUSIC:CMD         write   a line a request, one PRINT #9 each (section 4), after the OPEN opcode
   MUSIC:EVENTS      read    the answers; ENDED tag; POS s
   MUSIC:MP3/ 8BIT/ 4BIT/ SID/ AY38912/ VGM/ FM/ MOD/ MIDI/ GME/   music installed by type (a game's
                             tunes go in their folder once); PLAY MUSIC/SID/X.SID plays it on the Pi -
                             MP3, 8-bit samples, C64 SID, Spectrum/CPC AY, Mega Drive/SMS/Neo Geo/
                             arcade VGM, Adlib/OPL FM, Amiga/PC trackers, MIDI (.mid/.xg, GM), console
                             chips (NES/GB/SNES/PCE/MSX). A new type: a folder and a Pi player, no ROM
                             change. A player the Pi lacks: ERR noplayer on EVENTS


   to come:
   STORE:path        both    the Pi's tagged store as files: STORE:GAMES/NAME/TILES.BIN - SAVE,
                             LOAD, OPENOUT / OPENIN, CAT, |ERA; a write past the first chunk
                             appends (a multi-megabyte file in pieces); a read from an offset
   VCPC:n/RUN        write   a program's name, or the program itself SAVEd, into Pi slot n
   VCPC:n/IN         write   keys to it
   VCPC:n/OUT        read    its console, a line a read
   VCPC:n/PS         read    its state
```

How a path is found: the device by its name (CheckDrive), the file by its 11-character name in
the device's list; a name not in the list is "no such file". There are no subfolders yet
(STORE: brings them: a tag's / is a folder).

## 2. The opcodes every CMD takes

```
   CHR$(&80)+CHR$(LEN(s$))+s$   OPEN: the channel to the service named (vdp profile=v9990
                                vsync=1 | audio | votrax); the answer OK n / ERR on EVENTS
   CHR$(&81)                    CLOSE          CHR$(&82)   RESET          CHR$(&83)   LIST
   CHR$(&84)                    END (PATTERNS: the set's last part now)
```

## 3. The VDP from BASIC

```
   OPENOUT "V9990:CMD": PRINT #9,CHR$(&80)+CHR$(25)+"vdp profile=v9990 vsync=1";: CLOSEOUT
   SAVE "V9990:PATTERNS",B,addr,128*n      the patterns (v9990: 16 x 16 4-bit, 128 bytes each)
   OPENOUT "V9990:CMD"
   PRINT #9,a$;                            a$ the command bytes (cyborgos-vdp.md section 4):
                                           SPR id pat x y flags, VEL id vx vy (12.4: 16 = 1 px),
                                           BOUNDS id mode (5 bounce), ANIM id first count delay,
                                           BOX x0 y0 x1 y1, TEXT col row len text, COMMIT (&7F)
   OPENIN "V9990:EVENTS": LINE INPUT #9,e$ V n each frame, HIT a b, EDGE id side, DIED id, OK /
                                           ERR answers
```

A frame of game: build the changes in a string, PRINT #9 it with CHR$(&7F) last, LINE INPUT #9
the events until a V. The Pi moves, bounces and animates the sprites between frames; the program
only changes what it wants changed. examples/VDPDEMO.BAS is a whole one.

## 4. Music, speech

```
   MUSIC:CMD    one line a PRINT #9: PLAY tag [seconds], STOP, PAUSE, RESUME, SKIP n, SEEK s,
                LIST tags, NEXT, PREV, STATUS, VOL n (after CHR$(&80)+CHR$(5)+"audio")
   MUSIC:EVENTS the answers; ENDED tag; POS s with pos=1 in the OPEN text
   SPEECH:SSA1 / DKTRONIC   PRINT #9 a string of allophone codes (CHR$(27)+CHR$(7)...); no Pi
   SPEECH:VOTRAX  PRINT #9 a string of SC-01 phoneme bytes (bits 0-5 the phoneme, 6-7 the
                inflection) after CHR$(&80)+CHR$(6)+"votrax"; the Pi needs SYS/SC01A.BIN in its
                store or stays silent
```

examples/MUSIC.BAS, SPEAK.BAS.

## 5. Where the files are

A game's assets live on the Pi, put there once (today from a PC with cosctl into the store;
STORE: as a device is to come, after which |COPY from a disc does it). The VDP's PATTERNS can
then name a tag instead of carrying bytes (to come in the node).

## 6. Not there yet

STORE: and VCPC: devices; the Pi's own SP0256 and the human-like voice; the CPLink2's bulk path;
a run on real UniDOS (the harness stands in for it).

# PIDEMOS.DSK - fifteen test programs for the CPC-CPLink and the CPLink2

(c) 2026 Cyborg Unicorn Pty Ltd - made 2026-11-26

A 178K data format disc for an Amstrad CPC with a CPC-CPLink or a CPLink2 card and a Raspberry Pi
running CyborgOS for the Pi (cosd). Each program tests one thing the Pi offers through the card
and prints `ok` or `FAIL` for every step. They are written in NTC BASIC and compiled to Z80.

STATUS: every program passes in the test harness (an emulated CPC and card against the real cosd).


## 1. What it needs

- A CPC 6128 (or a 464 / 664 with a disc drive) and the card.
- On the Pi: cosd.js and cplink-bridge from CyborgOS's `pi/` folder, started for the card:
  `--link=cplink:7001` for a CPC-CPLink, `--link=cplink2:7001` for a CPLink2.
- Nothing else on the CPC: no ROMs, no CP/M. The programs use the firmware for text and keys.


## 2. Running

    RUN"MENU"        a menu of the fifteen
    RUN"PI01LINK"    or any one by its name

Start with PI01LINK. If it does not pass, nothing else will.

    ok    PUT PIDEMO/PIECE (64 bytes)
    FAIL  the same bytes  [OK 64]

The text in square brackets after a FAIL is the last answer the Pi gave. The last line is the
count, with ALL PASS when nothing failed. `THE LINK WENT QUIET` means a byte did not come from
the Pi within 3 seconds; the program then stops asking and ends.


## 3. How the programs use the card

- Port &FD80: data. Port &FD81: status.
- Status bit 0 = 1: a byte from the Pi is waiting. Bit 1 = 1: there is room to write one.
- Status bits 4-7 = 1010: the card is taken as a CPLink2. Anything else: a CPC-CPLink.
  Status &FF: no card.
- A byte out: wait for bit 1, then OUT &FD80. A byte in: wait for bit 0, then INP &FD80. One byte
  at a time from BASIC, about 2000 bytes a second. No interrupts are used.
- Everything is in frames: `A5 channel type id length-low length-high payload check`.
- CPLink2 only, the Pi ROM: when an answer's data is more than two frames' worth (and 32K at
  most) the Pi writes it to the Pi ROM and sends a short frame `BULK n`. The program then has
  the firmware select ROM 32 (KL ROM SELECT, &B90F), copies from &C000 with one LDIR, deselects
  (KL ROM DESELECT, &B918), and for data past 16K does the same with ROM 33.

What the Pi side (cplink-bridge.c, 2026-11-27) takes the card's header to be, BCM numbers: D0-D7
on 2 3 4 7 8 9 10 11, DIR 17, DOR 23, SI 18, SOB 22, WNR 24, RNF 13 (CPLink2: high = to the ROM,
not the FIFO), RRD1 19, RRD2 26. A byte from the CPC is taken with SOB up, DOR seen low, SOB down.
Before a ROM write it waits for DIR, RRD1 and RRD2 all high (the CPC has read the last one), with
no time limit; it waits for DIR before every byte and after the last one, then drops RNF.


## 4. The programs

- PI01LINK - the status byte (printed), CPLink2 or not, HELLO, 50 PINGs timed, TIME, INFO, the
  list of services.
- PI02STOR - 64 bytes stored on the Pi under a tag, got back and compared; size, a part of it,
  append, list, delete, and the refusals.
- PI03BIG - 6000 bytes, then 20000, sent, got back, compared, timed. On a CPLink2 the answers
  come through the Pi ROM (ROM 32, and ROM 33 past 16K) and the program says so. THIS IS THE
  PI ROM TEST.
- PI04MATH - sums done on the Pi: floating point, big whole numbers, 3D points.
- PI05FLT - the float coprocessor: add, subtract, multiply, divide, divide by zero, arrays.
- PI06RUN - commands run on the Pi (echo, uname, ls).
- PI07TERM - a shell on the Pi with the CPC as its terminal.
- PI08VDU - drawing on the Pi's HDMI. Look at the Pi's screen.
- PI09AUD - a half second tone made on the CPC, stored and played by the Pi. Listen for a beep.
- PI10VOX - speech (a Votrax SC-01 emulated on the Pi). Says "hello" if the Pi has the chip's ROM.
- PI11DISK - a disc volume on the Pi: a file written, read back, renamed, erased.
- PI12MIND - a small text generating model on the Pi.
- PI13MANY - three services open at once, 20 rounds turn about, one closed in the middle.
- PI14VDP - the Pi's HDMI as a video chip: twelve balls bouncing. Runs until a key.
- PI15TILE - tiles sliding with a ball over them. Runs until a key.

PI01, PI02, PI03 and PI13 test the card. The rest test the Pi's services through it.


## 5. What to look at first on the card

- What bits 4-7 of a CPC-CPLink's status byte read. PI01LINK prints the byte.
- Whether bits 4-7 = 1010 is right for every CPLink2 (taken from the card's documents).
- The FIFOs: the harness's card always has room and never loses a byte. The CPC-CPLink has
  16 bytes, the CPLink2 1K. PI03BIG sends 20000 bytes each way.
- ROM 32 and 33 selected through the firmware.
- The timing between the Pi's ROM write and the CPC's read of it (PI03BIG on a CPLink2).

When something fails, the useful things to send back are: the card, the program's name, the
lines from the first FAIL to the end, and the status byte PI01LINK printed.

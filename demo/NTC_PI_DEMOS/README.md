# NTC PI DEMOS

(c) 2026 Cyborg Unicorn Pty Ltd - made 2026-11-26

Fifteen small NTC BASIC programs for an Amstrad CPC with a CPC-CPLink or a CPLink2 card and a
Raspberry Pi running CyborgOS for the Pi (cosd). Each one tests one thing the Pi offers and says
`ok` or `FAIL` for every step. They are for testing and fixing on the real hardware.

STATUS: every program passes on an emulated CPC against a real cosd, as a CPC-CPLink and as a
CPLink2. NONE of it has been run on a real CPC, a real card or a real Pi. See "What was run".


## 1. What you need

- A CPC with a CPC-CPLink or a CPLink2 (ports &FD80 data, &FD81 status).
- The Pi running cosd from the CyborgOS repo's `pi/` folder, on the link for the card:
  `--link=cplink:7001` or `--link=cplink2:7001`, with cplink-bridge running.
- The disc `dsk/PIDEMOS.DSK`, or the files in `bin/` copied to any disc.


## 2. Running them

    RUN"MENU"        a menu of the fifteen
    RUN"PI01LINK"    or any one by its name

Start with PI01LINK. If it does not pass, nothing else will.

Each program prints a line a step:

    ok    PUT PIDEMO/PIECE (64 bytes)
    FAIL  the same bytes  [OK 64]

The text in square brackets after a FAIL is the last answer the Pi gave. The last line is the
count, with ALL PASS when nothing failed.

`THE LINK WENT QUIET` means a byte did not come from the Pi within 3 seconds (10 in the programs
that run commands). The program then stops asking, so it ends instead of hanging.

PI14VDP and PI15TILE use NTC's own Pi class, which waits for the Pi with no time limit. If one of
them just sits there, run PI01LINK.


## 3. The programs

- PI01LINK - the card's status byte, whether it is a CPLink2, HELLO, PING (50, timed), TIME,
  INFO, the list of services. Needs: nothing but cosd.
- PI02STOR - the store. 64 bytes put as the tag PIDEMO/PIECE, got back and compared; SIZE; a part
  of it; APPEND; a text tag; LIST; an empty tag; DEL; and the refusals (a tag that is gone, a tag
  that climbs out with ../, an unknown request, a closed channel).
- PI03BIG - data bigger than a frame. 6000 bytes, then 20000, sent in parts, got back, compared,
  timed. On a CPC-CPLink the answer comes through the FIFO in frames; on a CPLink2 it comes
  through the Pi ROM (ROM 32, and ROM 33 past 16K) and the program says so.
- PI04MATH - EVAL (floating point), BIG (whole numbers of any size), XFORM (four 3D points
  projected by the Pi).
- PI05FLT - the float coprocessor behind NTC's Float class: add, subtract, multiply, divide, to
  and from a Long, divide by zero (the overflow flag), three sums in one ARR request.
- PI06RUN - commands run on the Pi: echo, uname, ls, an exit code, a command that is not there.
  A cosd started with --no-run refuses this; the program says so and counts no failure.
- PI07TERM - a shell on the Pi with the CPC as its terminal: a command typed for it, its answer
  looked for, exit, the EXIT event. Also refused with --no-run.
- PI08VDU - the Pi's HDMI as a full HD display. LOOK AT THE PI'S SCREEN (or http://pi:8084/):
  yellow and white text, a red box, a green outline, a magenta disc, a cyan line, on dark blue.
  A click or key on that page is shown on the CPC (10 seconds are waited).
- PI09AUD - music. A half second 440 Hz tone is made on the CPC, put in the store as
  MUSIC/8BIT/PIDEMO and played: YOU SHOULD HEAR A SHORT BEEP FROM THE PI. Then STATUS, the ENDED
  event, a tag that is not there, VOL, STOP. Needs aplay on the Pi (it is in the OS).
- PI10VOX - speech (the Votrax SC-01 emulated on the Pi). STATUS says ready, norom or off. Only
  ready speaks: YOU SHOULD HEAR "HELLO". norom: the chip's 512 byte ROM is not in the store as
  SYS/SC01A.BIN (it is not ours to ship). off: the votrax program is not built on the Pi.
- PI11DISK - Pi volumes. A volume PIDEMO made and mounted as P, a file written record by record
  with a gap, read back, sized, found, renamed, a folder made and removed, the file erased, the
  volume dropped. cosd must be able to write its volumes folder (/home/cyborgos).
- PI12MIND - the generative model on the Pi: MODELS, LOAD, INFO, 60 characters written, RESET
  and the same 60 again. Needs pi/ntck built on the Pi and GEN.MDL in ~/.cosd/models; without
  them the program says which is missing and counts no failure.
- PI13MANY - store, maths and float open at once and asked turn about for 20 rounds; one closed
  in the middle while the others carry on; opened again; CHANS.
- PI14VDP - the Pi's HDMI as a video chip, through NTC's Pi class. LOOK AT THE PI'S SCREEN:
  twelve red balls bouncing in a box. After 150 frames the Pi is asked where two of them are and
  whether they moved. Runs on until a key.
- PI15TILE - the tile layer. Four tiles put in the store, six rows of them sliding sideways, one
  ball over them. LOOK AT THE PI'S SCREEN. Runs on until a key.

Everything a program puts on the Pi it takes off again, except PI15TILE's four tiles
(HWLIB/GRAPHICS/V9990/TILES, 128 bytes).


## 4. What is here

    src/        the programs (PIxxNAME.bas) and their classes
      Link.cls    the link, written for these demos (section 5)
      Pi.cls      NTC's own class for the Pi's video chip (a copy of NTC's src/hwlib/lib/Pi.cls)
      Art.cls     the ball patterns (a copy of NTC's src/hwlib/tests/cpc_pi/Art.cls)
    bin/        PIxxNAME.BIN, each with its AMSDOS header, and MENU.BAS
    dsk/        PIDEMOS.DSK - a 178K data format disc with all sixteen files (128K used)
                README.md - the disc by itself, for someone who has only the disc
    tools/
      build.js    builds bin/ and dsk/ from src/ (node; needs NTC and sjasmplus)
      pirun.py    runs one program on an emulated CPC against a real cosd
      runall.js   runs them all on both cards and writes docs/results/
    docs/results/ what each program printed in the last run here

All fifteen are built for NTC's `cpcfw` platform (the firmware's text and keys).


## 5. Link.cls

The link as a class a program can use, in BASIC so it can be read and changed at the machine:

    If Not Link.Hello("NAME") Then Print Link.Reply : End
    ch = Link.Open("store")
    ok = Link.AskWith(ch, "PUT SCORES", VarPtr(a), 20)       ' 20 bytes sent with the request
    ok = Link.AskTo(ch, "GET SCORES", VarPtr(b), 20)         ' the answer's data put at b
    Link.Shut ch

- `Ask`, `AskTo`, `AskWith`, `AskBoth`: a request; True when the answer starts with OK.
- After an answer: `Reply` (its text), `BodyLen` (bytes of data that came), `Kept` (those stored),
  `Parts` (frames it came in), `Bulk` (True: through the CPLink2's Pi ROM).
- `Send`, `SendText`: DATA frames. `Poll`, `Wait`: a frame that came by itself (an event, data).
- `LastEvent`: the newest event that came while an answer was being waited for.
- `Lost`: a byte did not come in time. `Patience`: how long to wait, in ticks (300 a second).
- `Title`, `Check`, `Summary`: the tests' own lines.

It is not fast: about 2000 bytes a second through the FIFO (6000 bytes sent in about 3 seconds
on the emulated CPC). The one piece of machine code in it is the CPLink2's Pi ROM copy: it has
the firmware select ROM 32 / 33 (KL ROM SELECT, KL ROM DESELECT) and copies with one LDIR.


## 6. Building and testing without the hardware

    set NTC=...\NTC            (the folder with src and test in it)
    node tools/build.js

    set COS_PI=...\CYBORGOS\pi
    node tools/runall.js                                    every program, both cards
    python tools/pirun.py src/PI02STOR.bas src/Link.cls     one program
    python tools/pirun.py --card=cplink2 src/PI03BIG.bas src/Link.cls
    python tools/pirun.py --dead src/PI01LINK.bas src/Link.cls       the Pi never answers
    python tools/pirun.py --card=none src/PI01LINK.bas src/Link.cls  no card at all

pirun.py is NTC's CPC emulator and firmware stand-in with the card's two ports joined to a cosd
it starts. It stands in for cplink-bridge too: for `--card=cplink2` it takes cosd's Pi ROM writes
and shows them at &C000 when the program selects ROM 32 or 33. It needs python with the z80
module, node and sjasmplus, as NTC's own tests do.


## 7. What was run, and what was not

Run here on 2026-11-26, NTC BASIC 20261126-2, cosd from CyborgOS 20261116-7:

- All fifteen as a CPC-CPLink: all pass. All fifteen as a CPLink2: all pass (30 runs, 176 checks
  each card). What each printed is in docs/results/.
- PI03BIG as a CPLink2: both sizes came through the Pi ROM stand-in (2 ROM writes), 20000 bytes
  across ROM 32 and ROM 33, compared right.
- PI01LINK with a Pi that never answers, and with no card: both end with the reason, no hang.
- PI12MIND with pi/ntck built here and CyborgOS's GEN.MDL: 9 checks pass.
- dsk/PIDEMOS.DSK compared with a disc made by NTC's own disc writer from the same files: the
  same but for the padding bytes after each file's end.

NOT run, and so the first things to look at on the real machine:

- A real CPC, a real CPLink or CPLink2, a real Pi, cplink-bridge. Nothing.
- The status byte of a real CPC-CPLink. The programs take bits 4-7 = 1010 as a CPLink2 (from
  cyborgos-pi.md) and anything else as a CPC-CPLink. What a CPC-CPLink's upper bits read is not
  known here. PI01LINK prints the byte.
- The FIFO's size and speed. The emulated card always has room and never loses a byte; the real
  CPLink has 16 bytes.
- KL ROM SELECT with ROM 32 and 33 on real firmware (the CPLink2's Pi ROM). On the emulator the
  firmware is a stand-in.
- Sound: the Pi's players were stand-ins that "play" for 0.3 seconds. Nothing was heard.
- Speech: the votrax program and the SC-01's ROM were not here, so only "off" was seen. The
  phoneme bytes for HELLO have never been spoken.
- The pictures of PI08VDU, PI14VDP and PI15TILE: the Pi was asked for its state, nobody looked
  at a screen.
- MENU.BAS: written, not run (no Locomotive BASIC here).


## 8. Found while making these

1. NTC BASIC: a one-line If that comes after a colon only governs its first statement.
   `n = 1 : If n > 5 Then Print "A" : Print "B"` prints B. Written first on the line it is right
   (nothing printed). The user guide says the one-line form holds several statements joined with
   a colon. Cause: parseLine in ntc_parser.js tests `left(objText.s, 'if ')` on the rest of the
   line, which starts with a space after a colon, so the If is not seen as a one-line If and the
   line is cut at every colon. Not changed: one of NTC's own tests (test/zxnfs/Main.bas line 15,
   `For ... : If ... Then n = n + 1 : Next`) depends on it, and so may programs. Link.cls had one
   such line; it is two lines now.
2. cosd: a request on a channel that is not open gets no answer, only an event `ERR nochan n` on
   the control channel. A program waiting for the answer waits for ever. Link.cls takes that
   event as the answer.
3. cosd: after `CLOSE n` the Pi also sends a CLOSE frame on channel n. Giving credit back for
   that frame (as NTC's Pi.cls and PISHELL do for every frame) gets an `ERR nochan n` event.
   Link.cls gives no credit for a CLOSE.
4. cosd, audio: when the player cannot be started, PLAY still answers OK, an ERR event follows,
   and STATUS says "playing" from then on; no ENDED comes. Seen here when the stand-in player
   was not executable. On a Pi with no aplay it would look the same.
5. PISHELL (NTC's src/apps/pishell) asks the store for `LIST folder/ fmt=cpc` and reads 16 byte
   records. The store in this CyborgOS (pi/svc/store.js) has no fmt: it answers with lines of
   text and takes the second word as a prefix. PISHELL's listing cannot work against it. From
   reading both; PISHELL was not run. Its own test (src/apps/pishell/test/run_pi.py) stops at
   its first import here (it looks for NTC's test folder one level too high).
6. cosd, from reading the code, not run: an answer that is text only and longer than the CPC's
   frame (256) is cut into frames with no MORE mark on them, so the CPC takes the first piece as
   the whole answer. The vdp's STATE for all sprites is the case: about 20 sprites reach it.
   The demos ask for one sprite at a time.

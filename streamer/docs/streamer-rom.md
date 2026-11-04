# Streamer - the ROM as it is (2026-11-02)

What build/streamer.rom holds, device by device, and what it does not. src/streamer.asm is 2,117
bytes of a 16K ROM; test/streamer_test.py (31 checks against a live cosd: the categories end to end) is the proof of each
line marked "tested". Nothing here has run on real UniDOS yet: the harness calls the node's
entries the way UniDOS does, from the contracts in docs/ref/unidos/src/DOSNodes.a.

## The devices (|DRIVE lists these)

```
   device   files                 to / from                                   tested
   V9990:   CMD PATTERNS EVENTS TILES LAYER2   the Pi's vdp service, profile v9990         yes
   V9938:   CMD PATTERNS EVENTS   ... profile v9938                           name only
   ZXNEXT:     CMD PATTERNS EVENTS   ... profile zxn                             name only
   MD:      CMD PATTERNS EVENTS   ... profile md                              name only
   PI:      CMD PATTERNS EVENTS   ... profile pi1080                          name only
   SPEECH:  SSA1 DKTRONIC VOTRAX  the cards on the CPC (no Pi); VOTRAX the SC-01 yes (ports simulated;
            EVENTS                 emulated on the Pi (phoneme bytes)          the Pi live)
   MUSIC:   CMD EVENTS            the Pi's audio service                      yes
```

- CMD: PRINT #9 the bytes. Below #80 the VDP's commands (cyborg-os/docs/cyborgos-vdp.md section
  4), each sent as one DATA frame; a command cut by a PRINT's end continues with the next.
  #80 up the node's own: 80 OPEN len text, 81 CLOSE, 82 RESET, 83 LIST, 84 END - taken in any
  stream. The node sends the stream's version byte at OPEN.
- PATTERNS: SAVE pattern data into it: a PATTERNS 0 request in parts of 250, the last at the
  SAVE's close or at 84 END. TILES (tile definitions: a TILES 0 request) and LAYER2 (the bitmap
  layer: a LAYER2 request) the same way - the Next's layers on every VDP device.
- EVENTS: LINE INPUT #9: an event or an answer a line (CR LF); a read waits for the next; the
  read bytes go back as CREDIT.
- SPEECH: a string of allophone codes; each written when the card's /LRQ bit is clear (SSA-1
  &FBEE bit 6, dk'tronics &FBFE bit 7); a bad value masked to 0-63.
- SPEECH:VOTRAX the SC-01 phoneme bytes as they are (bits 0-5 the phoneme, 6-7 the inflection),
  DATA frames of up to 250, to the Pi's votrax service (80 OPEN votrax first); SPEECH:EVENTS its
  answers. The Pi needs the chip's ROM in its store (SYS/SC01A.BIN) or it says nothing.
- MUSIC: CMD a line a request (PLAY tag, STOP, VOL n, STATUS) - one PRINT #9 a line; EVENTS
  the answers.

A channel a device (w_chans): V9990: and MUSIC: open at once. BASIC's OPENOUT / OPENIN /
CLOSEOUT / CLOSEIN only choose the stream; HELLO goes once, at the first OPEN opcode.

## The UniDOS entries

```
   Init, CheckDrive (by name, bit 7 ignored, A kept on a miss), GetStatus (a media, a stream,
   the new API), GetName, GetDesc, GetFreeSpace (0), Examine / ExamineNext (the device's file
   list), InOpen / InRead / InClose (EVENTS only), OutOpen / OutWrite / OutClose, the rest
   "not supported" (seek, rename, delete, dirs, format, dates, RTC, NVRAM)
```

## The link

&FD80 data, &FD81 status (bit 0 a byte waiting, bit 1 room) - the CPC-CPLink and CPLink2's
FIFO ports. The frames of cyborg-os/pi/proto.js, written and read a byte at a time; no RAM
buffer; the node's scratch is 28 bytes at &BE80.

## vCPC support: none yet

The ROM has no VCPC: device. What it would be, from the discussion: VCPC:n/RUN (a program's
name, or the program itself SAVEd into it), VCPC:n/IN (keys), VCPC:n/OUT (its console, a line
a read), VCPC:n/PS (its state) - the vCPC on the Pi's slots as paths, through a slot service in
cosd that bridges to the vCPC. Needs, in order: the vCPC's console-as-socket mode
(cyborg-os-vcpc), the slot service (cyborg-os/pi), then the device here (a row, a file list of
four, the line-request writer MUSIC already has, and a read path like EVENTS). The CPC side is
the small part.

## Not there either

- STORE: (the Pi's tagged store as paths: PUT / APPEND / GET / LIST / DEL) and PIVOL: - the
  first device that needs the path parser (UniDOS's normalized path, DE, is ignored today) and
  InSeek.
- SPEECH:PI (the SP0256 emulated, the same way as the SC-01, its 2K ROM from the store) and
  VOICE:PI (Piper) - the Pi side first.
- The CPLink2's Pi ROM bulk path (a big answer read from &C000 with one LDIR) - the frames work
  on a CPLink2 as on a CPLink, only slower for big answers.
- AMDRUM and the old node's PRINT / TEST devices: dropped by decision.

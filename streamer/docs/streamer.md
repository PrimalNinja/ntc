# Streamer - a UniDOS node: devices as paths

The Pi's VDP (CyborgOS for the Pi: cosd's vdp service - cyborg-os/docs/cyborgos-vdp.md) as UniDOS
devices on a CPC with a CPC-CPLink (or CPLink2). One device a target, each its own command bytes
and asset format, not retargetable; a Locomotive BASIC program writes and reads them like files.

## The devices and their files (the folder of each)

```
   device  CMD                                PATTERNS              EVENTS
   V9990:  PRINT #9 the command bytes: the    SAVE pattern data     LINE INPUT #9: a line an
   V9938:  VDP's (cyborgos-vdp.md section 4,  into it: a PATTERNS   event (V n, HIT a b, EDGE
   ZXNEXT:    opcodes below #80) go to the Pi;   0 request in parts,   id s, DIED id) or an
   MD:     the node's own (#80 up) are done   the last when the     answer (OK n, ERR ..., the
   PI:     here (below)                       SAVE closes or at     LIST's lines); a read waits
                                              an #84 END            for the next
```

BASIC's OPENOUT / OPENIN / CLOSEOUT / CLOSEIN only choose the stream; nothing opens or closes on
the Pi by them. The node's opcodes, written into CMD like any command:

```
   80 OPEN len8 text   the channel to the service named - "vdp profile=v9990 vsync=1" - the answer
                       OK n (or ERR) read from EVENTS; the stream's version byte sent by the node
   81 CLOSE            the channel closed on the Pi
   82 RESET            closed, HELLO said again at the next OPEN
   83 LIST             the Pi's services as lines on EVENTS
   84 END              (PATTERNS) the set's last part sent now
```

HELLO goes once, before the first frame. The link: &FD80 data, &FD81 status (bit 0 a byte
waiting, bit 1 room to write). A VDP command is sent as one DATA frame (a command cut by a
PRINT's end: its first part goes, the rest with the next PRINT); each event read returns its
bytes as credit, so the Pi's queue, not the 16-byte FIFO, holds what arrives between reads.

## SPEECH: and MUSIC:

```
   SPEECH:SSA1      PRINT #9 a string of SP0256-AL2 allophone codes (0-63; others masked): each is
   SPEECH:DKTRONIC  written to the card when its /LRQ bit is clear (SSA-1 &FBEE bit 6, dk'tronics
                    &FBFE bit 7). No channel: the card is on the CPC. Same bytes, both cards; a
                    third card with the same chip is a row in the Cards table
   SPEECH:VOTRAX    PRINT #9 a string of SC-01 phoneme bytes (80 OPEN votrax first): the Pi speaks
   SPEECH:EVENTS    the Pi's answers (STATUS: ready / norom / off)
   MUSIC:CMD        80 OPEN audio first; then a line a request to the Pi's audio service (PLAY tag,
                    STOP, VOL n, STATUS): one PRINT #9 a line (a line is one write)
   MUSIC:EVENTS     the answers, a line each
```

Each device has a channel of its own (w_chans): V9990: and MUSIC: open at once from one program.
The node's opcodes (80 up) are taken in any stream.

## Build and install

build/build.bat (sjasmplus) makes build/streamer.rom, 16K; put it in a ROM slot as any UniDOS node;
|DRIVE lists V9990 and the others.

## Test

test/streamer_test.py: the ROM on NTC's Z80 core, its entries called as UniDOS calls them, the two
ports bridged to a cosd started on a TCP link - the frames reach the real vdp service and the events
come back through EVENTS; the speech cards' ports answered by the harness (busy twice, then ready). 33 checks. (Needs node and cyborg-os beside ntc: COS_PI= says where.)

## Not yet

A test on UniDOS itself (the harness stands in for it; the entry contracts are the ones in
docs/ref/unidos). The AUDIO, PRINT and SPEECH devices of the old node (_old/) are not carried.

## References

docs/ref/: UniDOS, UniDOS Albireo, UniDOS M4 (Julian's archives, 2026-11-02).

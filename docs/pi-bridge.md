# NTC BASIC and the Pi - how a program uses CyborgOS for the Pi

The Pi (cyborg-os/pi: cosd with its services, docs/cyborgos-pi.md there for the protocol and
the services, docs/cyborgos-vdp.md for the VDP) is a coprocessor behind a link. An NTC BASIC
program reaches it in one of three ways; this document is the NTC side. Streamer's own document
(streamer/docs/pi-bridge.md) is the Locomotive BASIC side.

## 1. The three doors

```
   a plain CPC program (platform cpc / cpcfw / cpcmin), the CPC-CPLink's ports direct
       hwlib's Pi.cls (the VDP)                                      - here now
       (a Link class for the other services: store, audio, votrax)   - to come
   a CyborgOS slot (platform cyborgos): C0 owns the link, a slot's channels by BDOS 131 ops
       Float's coprocessor (op 40) - answered by the vCPC today, by C0 on a CPC to come
       the channel ops (OPEN, REQ, DATA, EVT)                        - to come
   a program running ON the Pi (the vCPC there): the services local  - the vCPC's console as a
                                                                       socket and the slot
                                                                       service to come
```

## 2. The VDP from NTC: hwlib's Pi.cls

src/hwlib/lib/Pi.cls, the same calls as every hwlib chip library (src/hwlib/README.md), so a
program written for V9990.cls runs on the Pi by swapping the class:

```
   Pi.Profile = "v9990"       (before Init; v9938, zxn, md, pi720, pi1080, pi2160)
   Pi.Init                    HELLO, OPEN vdp, the stream's version
   Pi.Palette n, r, g, b      0-255 each
   Pi.Pattern n, addr         the profile's pattern format (v9990: 16 x 16 4-bit, 128 bytes)
   Pi.Put n, x, y, pattern    shown, bouncing within the box
   Pi.Move n, dx, dy          pixels a frame, kept until changed
   Pi.Anim n, first, count, delay
   Pi.Bounds x0, y0, x1, y1   the box every sprite bounces in
   Pi.Hide n
   Pi.Frame                   COMMIT, then the Pi's frame waited for
   Pi.X(n), Pi.Y(n)           where it is now (a round trip to the Pi: ask when needed)
```

The table lives on the Pi: between Frames the CPC does nothing for the sprites. The example is
src/hwlib/tests/cpc_pi (the V9990 balls on the Pi); src/hwlib/tests/cpc_pi/run_pi.py runs it with
no hardware against a cosd (the ports bridged), the way to test a game's Pi side on a PC.

Pi.cls's own, beyond the hwlib core (the Pi has the Next's layers):

```
   Pi.TilesTag "GRAPHICS/V9990/TILES"   tile definitions from the store (an installer's file);
   Pi.Tiles addr, count                 or from memory, 32 bytes a tile (8 x 8 4-bit)
   Pi.Tile col, row, t, flags           a cell (t -1: nothing); flags: mirror X 2, Y 4, rotate 8
   Pi.TileRow row, col, addr, count     a level's row from words in memory
   Pi.Scroll x, y / Pi.ScrollBy vx, vy  the layer's offset; moving by itself (16 = a pixel a frame)
   Pi.Layer2Tag "tag"                   the bitmap under the tiles, from the store
   Pi.PatternTag "tag"                  patterns from the store
   Pi.Seq s, addr, count / Pi.Play n, s, delay   animation sequences (0 stop, -k go to step k)
   Pi.HitBox n, x, y, w, h / Pi.Hit(n, m)        hit boxes; the Pi's HIT events use them
```

A profile's GRAPHICS/<PROFILE>/PATTERNS, TILES, LAYER2 and PALETTE in the store load by themselves
when the display opens, so a game whose installer put them there calls none of the Tag routines.
What Pi.cls does not do yet: mirror / scale (the Pi has FLAGS), the Pi-only sizes, paths and
emitters. docs/potentjs-gaps.md keeps the list.

## 3. Assets on the Pi

Patterns go up once through Pattern (128 bytes each over the link) or, better, are put in the
Pi's store once (STORE PUT GAMES/NAME/SPRITES.BIN from a PC with cosctl, or through Streamer's
STORE: device to come) and named: the PATTERNS request takes a tag. Pi.cls's Pattern sends bytes;
a PatternTag n, "tag" that names them is to come.

## 4. The protocol, if a program speaks it itself

A frame: A5, chan, type, id, len-lo, len-hi, payload, check (the low byte of the sum of chan to
the end of the payload). HELLO on channel 0, OPEN service ("OK n" the channel), REQ / RSP by id,
DATA, EVT, CREDIT returned for every frame read on a channel (without it the Pi's answers queue
behind its events). Pi.cls's FrameStart / FrameByte / FrameEnd / ReadHeader / Done are a working
set to copy. cyborg-os/pi/proto.js is the reference.

## 5. Running a program on the Pi

A cyborgos-platform program can run in the vCPC on the Pi (RCOPY it from a CyborgOS, or put its
.CYB in the store and run it there) - cyborg-os/docs/cyborgos-design.md section 8 and
cyborg-os/pi/platforms/README.md say how. The Pi's services are then local to it.

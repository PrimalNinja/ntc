# potentjs against NTC BASIC, Streamer and the Pi - what each has (kept as things land)

potentjs (the user's JS game library: JSprites / JSpriteSlots, JTileGrid, JSteps, JGameLoop,
JPixelScreen, JPad, JSound, JMusic, JITP) is the reference for the 8-bit side. "NTC" is hwlib
(src/hwlib: the chip libraries and Pi.cls); "Streamer" the UniDOS node's devices; "Pi" cosd's
services. The table holds what at least one of the three has; what potentjs alone has is the
list under it. Updated 2026-11-02.

```
   feature (potentjs)            NTC (hwlib)       Streamer        Pi:v9990      Pi:v9938      Pi:ZXNEXT     Pi:NATIVE
   -- sprites --
   put / move / hide / look      yes (all chips)   yes (CMD)       yes           yes           yes           yes
   setMover velocity             yes (Move)        yes (VEL)       yes 12.4      yes           yes           yes
   bounce in a box (Bounds)      yes               yes (BOX)       yes           yes           yes           yes
   wrap / kill / stop / edge     no                yes             yes           yes           yes           yes
   animate: a range at a delay   yes (Anim)        yes (ANIM)      yes           yes           yes           yes
   animate: a sequence (0, -n)   Pi.cls only       yes (SEQ,PLAY)  yes + DONE    yes + DONE    yes + DONE    yes + DONE
   collide (bounding box)        no                yes (CLASS)     yes (HIT)     yes (HIT)     yes (HIT)     yes (HIT)
   mirror X/Y, rotate, scale     Next only (hw)    yes (FLAGS)     yes (beyond   yes (beyond   yes (the      yes
                                                                   the chip)     the chip)     Next's)
   sprite size                   chip's            profile's       16x16 4-bit   16x16 1-bit   16x16 8-bit   32x32 RGBA
   sprites / patterns            chip's            profile's       125 / 512     32 / 256      128 / 64      4096 / 4096
   colours                       chip's            profile's       16 x 16       16 of 512     256 of 512    24-bit + alpha
   sprite priority               table order       table order     table order   table order   table order   table order
   -- tiles --
   a tile screen (JTileGrid)     no (chips' own)   yes (TILE/ROW,  32x26 cells   32x26         40x32 (the    160x90 .. 480x270
                                                   TILES file)     8x8 4-bit     8x8 1-bit     Next's) 4-bit 8x8 RGBA
   per-cell mirror / rotate      Next only         yes             yes           yes           yes           yes
   text from a font              chip text         TEXT op         TEXT op       TEXT op       TEXT op       TEXT op
   transparent tile              no                yes (FFFF)      yes           yes           yes           yes
   scroll (whole layer)          chip-specific     yes (SCROLL,V)  yes, wrapped  yes           yes           yes
   a bitmap under the tiles      Next (Graphics)   yes (LAYER2)    4-bit (B)     none          8-bit (L2)    RGBA
   -- loop --
   JGameLoop (pause)             the program's Do  BASIC's loop    n/a           n/a           n/a           n/a
   -- drawing --
   JPixelScreen (plot, line..)   Graphics.cls;     no              no (LAYER2    no            no (LAYER2    vdu hd mode (a
                                 chips' own                        whole only)                 whole only)   separate page)
   -- input --
   JPad (keys, touch, taps)      Keys.cls, joystick BASIC's INKEY  vdu TOUCH / KEY events, unshaped (the game's keys are the machine's)
   -- sound --
   JSound samples / sounds       Stream.cls (Next  SPEECH (SSA1,    MUSIC: a file by type - MP3, 8-bit
                                 DAC); Stream.cls  DKTRONIC,        samples, SID, AY, VGM (Mega Drive /
                                 (Pi)              VOTRAX); MUSIC   SMS / Neo Geo), FM (OPL), MOD, MIDI,
                                                                   GME (NES/GB/SNES/PCE/MSX); VOTRAX
   JSound tunes                  no                MUSIC           all the chip / tracker types above
   -- net --
   JITP (polling web services)   Http.cls (CyborgOS) no            run / store (the Pi's)
```

The Pi columns are profiles of the one vdp service (cyborg-os/docs/cyborgos-vdp.md): the same
commands everywhere, the numbers the profile's. A chip profile is what a real card has (so a game
carries to the card); NATIVE (pi720 / pi1080 / pi2160) is the Pi's own screen.

## What potentjs has that none of the three has yet

- A mover as a callback that can retire the sprite (ours: a velocity; the data form to design)
- Hit boxes (an inner box, offset and size, instead of the whole sprite)
- collideRange: the sprites one touches, nearest first, with a callback
- Sprites by name and by class (ours: ids, by design on 8-bit)
- A clip rectangle for a set of sprites
- Colour variants of a tile set (the same tiles in other palettes)
- A band of rows drawn slid sideways and wrapped (paintRows: the Next's copper scroll)
- JSteps: a game as steps and waits (call, wait n, until) without blocking
- JMusic: music sprites - note sequences a channel, stepped by the loop, conducting each other
  and signalling the game (to come with AUDIO:PI's AY / SID)

What stops a game today, from that list: hit boxes; and on the chip libraries, sequences and tiles (the Pi has both).

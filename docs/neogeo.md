# NTC on the SNK Neo Geo (`neogeo`)

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

The Neo Geo is a 68000 machine (12 MHz, 64K of work RAM) with a Z80 (4 MHz) for the sound, a
YM2610 (FM, an SSG that is an AY, ADPCM-A and ADPCM-B), 380 sprites and a fix layer. NTC builds
a cartridge for it with the same 68000 keyword library and compiler path as the Mega Drive
(`docs/md.md` section 1 says how NTC works on a 68000: the thread is A7 in user mode, interrupts
are on all the time, there is one mode, Integer is 16 bits, Long 32).

**State: stable for games.** A program runs as a cartridge's game: the console on the fix layer,
the pads, Frame and Ticks, NTC's sound driver on the Z80. NTC's self tests pass, and two games
(TIANLONG and SILK TO STEEL) run whole on it. NTC's tests run on the Geolith core with NTC's
stand-in BIOS (below).

## 1. What a program is

A cartridge in TerraOnion's `.neo` format (Geolith, the NeoSD and MiSTer's Neo Geo core read it):
a 4096 byte header and the cartridge's ROMs one after another:

| ROM | What | From |
|---|---|---|
| P | the 68000's program: vectors, the Neo Geo header at `$100`, the program, its RAM's first image. 1 MB (the part the 68000 sees without bank switching) | the compiler and vasm |
| S | the fix layer's 8 x 8 tiles (128K) | `--srom`, or NTC's font at tiles 32-126 |
| M1 | the Z80's program (64K) | `--mrom`, or NTC's sound driver |
| V | the ADPCM samples (up to 16 MB) | `--vrom` |
| C | the sprites' 16 x 16 tiles, C1 and C2 interleaved (as a .neo keeps them) | `--crom` |

The P ROM is stored a word at a time, low byte first, as the ROM dumps are.

The BIOS starts the machine, switches in the cartridge's vectors and fix tiles, and calls the
cartridge's USER routine (`$122`). NTC's goes back to the BIOS for request 0 (start-up) and 1
(the eye-catcher: the header says the game does it, and it does nothing), and runs the program
for 2 (the game) and 3 (an MVS's title). The header's NGH number is 3100 unless `--ngh` gives
another. (Not 2457 = `$999`: Geolith takes that for V-Liner and reads the pads its way.)

## 2. Memory

| Addresses | What |
|---|---|
| `$000000-$0FFFFF` | the P ROM: the program, its threads, keywords, strings, data |
| `$100000-$10BFFF` | the program's variables, the library's, then its arrays: 48K |
| `$10C000-$10DFFF` | free (a `--log` test build keeps the console's transcript here) |
| `$10E000-$10E7FF` | the real stack (the library's `jsr` calls) |
| `$10E800-$10F2FF` | free |
| `$10F300-$10FFFF` | the BIOS's (the supervisor stack below it) |

- **16 bit addresses.** NTC keeps an Integer's address (VarPtr, Peek, Poke, the library's own) in
  16 bits. On the Neo Geo they are made this RAM's: sign extended, then `$110000` added (the
  platform's `;@a16`). The RAM is the same 64K again every 64K up to `$1FFFFF`, so `$0000-$7FFF`
  is `$110000-$117FFF` and `$8000-$FFFF` is `$108000-$10FFFF`: both the RAM. The library's
  `movea.w` loads are followed by `NTC_A16` (a macro that adds it; nothing on the other 68000
  platforms).
- **User mode.** The Neo Geo doesn't keep its hardware for supervisor mode, so a program's `#asm`
  can write VRAM, the palettes and the registers straight. The VBlank interrupt runs in
  supervisor mode on the BIOS's stack, so it never touches the thread.
- **No `-(sp)` in `#asm` on the thread**, as on the Mega Drive: the thread is in ROM. `NTC_RS` /
  `NTC_TS` round a `jsr` or `bsr`.

## 3. The console, pads, Frame and Ticks

- **Screen:** the fix layer, 40 x 28 cells (its rows 2-29: the ones a TV shows). Character c is
  fix tile c + `ntc_tbase`, in the palette `ntc_tattr` >> 4. Palette 0's colour 1 is white; the
  backdrop colour (palette entry `$FFF`) is black. `Print`, `Cls`, `Locate`, `Mode` (one mode: it
  clears) and scrolling work. Every sprite starts hidden (0 tall) and full size.
- **Pads:** the VBlank interrupt reads both every frame. `Pad.Read(1)` / `Pad.Read(2)`: bit 0 Up,
  1 Down, 2 Left, 3 Right, 4 A, 5 B, 6 C, 7 D, 8 Start, 9 Select (`Pad.Up` ... `Pad.SelectKey`).
  `Inkey` / `Inkey$` give a button newly pressed on pad 1: Start 13, A B C D "A" "B" "C" "D",
  Select 27, the stick `&HF0-&HF3` (as the CPC's cursor keys). `Input` reads those until Start.
- **Frame** waits for the VBlank interrupt. **Ticks** counts frames: 59.19 a second.
- **End / Stop:** the program stops and stays (the interrupt keeps the watchdog kicked).

Classes (`lib/neogeo/`; the Neo Geo CD uses the same ones):

| Class | |
|---|---|
| `StdIO`, `System` | the console and what the machine is, as on every platform |
| `Pad` | `Read(1)` / `Read(2)`: every button by its own name |
| `Keys` | `Joystick(n)` (0 or 1) with the bits NTC's other machines use: `JoyUp` 1, `JoyDown` 2, `JoyLeft` 4, `JoyRight` 8, `JoyFire2` 16 (B), `JoyFire1` 32 (A), `JoyFire3` 64 (C), `JoyStart` 128, `JoyFire4` 256 (D), `JoySelect` 512. `Down(key)` is always 0 (no keyboard; the key names are there so the same line compiles) |
| `Vdp` | the video (below) |
| `Pcm` | `Init data&` (data is not used: the songs are in the V ROM), `Have(n)`, `Play n, loop`, `Quiet`, `Volume v`, `Update` - the music (ADPCM-B); `Sample n, channel, loudness`, `SampleOff channel`, `SampleVolume channel, loudness` - sounds played once (ADPCM-A, six channels) |
| `Psg` | the SSG: `Reg r, v`, `Tone channel, period, volume`, `Noise channel, period, volume`, `Off channel`, `Quiet` |
| `Fm` | the four FM channels: `Reg port, r, v`, `Key channel, operators`, `Quiet` |
| `Cdda` | the Neo Geo CD's audio tracks: `Play track`, `Quiet` (nothing on a cartridge) |
| `Sound` | `Send b`: a byte to the Z80's driver (the four classes above go through it) |

**`Vdp`** (first written for TIANLONG and SILK TO STEEL, the same class in both). The Neo Geo has
no tile planes: everything but the fix layer is sprites, columns 16 wide and 1-32 tiles tall, each
tile with a palette of its own.

- **The game's sprites:** a table in RAM of 128 entries in the X68000's form (so a game's sprite
  code is the same on both). `Sprite n, x, y, c, shown` writes an entry (c: the flips, a palette
  block 0-15, a pattern 0-255), `Sat()` is the table's address for `#asm`, `HideAll`, and `Update`
  once a frame sends it to sprites 100-227. `Map first, n, tile` says which C ROM tiles the
  patterns are. x, y are the X68000's 256 x 256 screen's, which sits at the Neo Geo's 32, -16.
- **The backdrop:** `Back tile, palettes&` shows a 256 x 192 picture (at 32, 16) made of sprites
  1-68 in four bands; `Bands a, b, c, d` scrolls each band sideways; `BackOff`, `BackPal`,
  `BackFlash`. A scrolled band stands up to 15 pixels past the picture's two sides: cover them
  with fix cells. The four bands' places are fixed (lines 0-55, 56-111, 112-151, 152-191).
- **Any sprite, straight:** `Strip n, tile, palette, h`, `Place n, x, y, h`, `Shrink n, hs, vs`,
  `Join n` (to the sprite before it), `Hide n`. Sprites 69-99 and 228-380 are free of the two above.
- **Palettes:** `Colors addr&, first, n`, `Color entry, v`, `Backdrop v`, `Rgb(r, g, b)` (0-31
  each). Palettes 0-15 are the fix layer's, 16-31 the table's blocks, 32-255 the backdrop's.
- **The fix layer:** `Cell x, y, v`, `Fill x, y, w, h, v` (v: palette << 12 | tile); `TextPalette
  p` and `TextBase t` change the palette and the font `Print` uses.
- `VAddr`, `VMod`, `VPut`: VRAM written a word at a time, for anything else.

## 4. Sound: NTC's Z80 driver

`src/asm/neogeo_sound_z80.asm` (sjasmplus) is the M1 ROM a cartridge gets unless `--mrom` gives
another. The 68000 sends it bytes with `ntc_ng_snd` (d0.b, on the real stack): each byte goes
through `REG_SOUND`, the Z80 takes it in its NMI, queues it, and answers with its count of the
bytes so far, which `ntc_ng_snd` waits for. The driver's main loop takes the queue as messages:

| Bytes | |
|---|---|
| `$10 r v` | the SSG's register r (0-13) = v: three square waves and a noise, as an AY at 2 MHz |
| `$20 n` | ADPCM-B: song n (0-31) from the song table, round and round |
| `$21` | ADPCM-B off |
| `$22 v` | ADPCM-B's loudness (0-255) |
| `$30 n c l` | ADPCM-A: sample n (0-63) from the sample table, once, on channel c (0-5), loudness l (0-31) |
| `$31 c` | ADPCM-A channel c stopped |
| `$32 c l` | ADPCM-A channel c's loudness |
| `$40 t`, `$41` | (Neo Geo CD) CD audio: track t (BCD) played round and round; stopped |
| `$50 r v` | FM: register r (`$20` up) = v on the chip's first port (the LFO, key on / off, channels 1 and 2) |
| `$51 r v` | FM: register r (`$30` up) = v on its second port (channels 3 and 4) |
| `$01`, `$03` | the BIOS's (a slot switch is coming; a soft reset: the driver starts again) |

The tables are in the M1 ROM; `ngbuild.js --songs` and `--samples` write them in:
- `$0100`, the songs: 32 x 8 bytes: start and end (256 byte units of the V ROM, little endian
  words; the end is the last unit), delta-N (the rate: 65536 = 55.5 kHz), loudness, 0;
- `$0200`, the samples: 64 x 4 bytes: start and end, as above. (ADPCM-A plays at 18.5 kHz and a
  sample can't cross a 1 MB edge of the V ROM.)

From BASIC: the `Pcm`, `Psg`, `Fm` and `Cdda` classes send these; `Sound.Send b` sends a byte of
a program's own.

**The tools** (`tools/neogeo/`):

```
node tools/neogeo/ngpcm.js --out=NAME [--rate=18518] [--inrate=12000] [--volume=1.0]
     [--samples=A.wav,B.wav,...] SONG0.wav SONG1.wav ...
node tools/neogeo/ngtiles.js --out=NAME [--sprites=A.png,...] [--backdrop=P.png,...] [--fix=F.png]
     [--first=1] [--order=rows|columns] [--fixfirst=256]
```

- `ngpcm.js` reads WAV files (8 or 16 bit, any rate) or raw 8 bit unsigned samples at `--inrate`,
  and writes `NAME_V.BIN` (the V ROM: the samples as ADPCM-A, then the songs as ADPCM-B at
  `--rate`), `NAME_SONG.BIN` and `NAME_SAMP.BIN` (the driver's two tables): `ngbuild.js --vrom
  --songs --samples`.
- `ngtiles.js` reads PNG pictures and writes `NAME_C.BIN` (the C ROM: `--crom`), `NAME_PAL.BIN`
  (the palettes, as `Vdp.Colors` and `Vdp.Back` take them: INCBIN them in the program),
  `NAME_S.BIN` and `NAME_FIX.BIN` with `--fix` (the S ROM with NTC's font kept and the picture's
  8 x 8 tiles from 256 on: `--srom`), and `NAME.txt` (each picture's first tile and palette).
  `--sprites` cuts a picture into 16 x 16 tiles with one palette for the picture; `--backdrop`
  cuts a 256 x 192 picture into `Vdp.Back`'s 224 tiles and 224 palettes.

## 5. Building and testing

Tools (none are part of NTC):

- **vasm** (68000, Motorola syntax): `make CPU=m68k SYNTAX=mot` gives `vasmm68k_mot`. `NTC_VASM`
  is its path.
- **sjasmplus** (the Z80 driver): `NTC_SJASM` is its path.
- **The Geolith libretro core:** `github.com/libretro/geolith-libretro`, `make` in `libretro/`
  gives `geolith_libretro.so`. `NTC_NGCORE` is its path.

```
node test/ngbuild.js Main.bas [More.cls ...] --out=GAME.neo [--name="GAME NAME"] [--ngh=3100] [--log]
     [--list=GAME.lst] [--asm=GAME.s] [--srom=S.BIN] [--crom=C.BIN] [--vrom=V.BIN] [--mrom=M1.BIN]
     [--songs=SONGS.BIN] [--samples=SAMPLES.BIN]
python3 test/ngrun.py GAME.neo [--frames=N] [--pad=frame:buttons,...] [--shot=out.png]
     [--shots=f1,f2:prefix] [--text] [--log] [--untilend] [--ram=addr,len] [--wav=out.wav]
```

- `ngbuild.js` compiles (`--platform=neogeo`), assembles with vasm (`-Fbin -coalesced`; `--log`
  adds `-DNTC_NGLOG=1`: the console's transcript kept in RAM from `$10C000`), puts the name in the
  soft DIPs and the NGH number in the header, and packs the `.neo`. The first time it also makes
  `test/ngsys/aes.zip` for Geolith: `neo-epo.bin` (NTC's stand-in BIOS, `test/ngbios.s`) and
  `000-lo.lo` (the sprites' vertical shrink table, worked out by `ngbuild.js`).
- `ngrun.py` runs a cartridge on the core with no window, in AES mode: it holds pad buttons by a
  script (U D L R A B C D, S Start, E Select, `-` none), saves pictures, prints the fix layer as
  text, reads RAM, records the sound (at the core's rate), and prints a `--log` build's
  transcript. Geolith wants its palette option set, or every colour comes out black; `ngrun.py`
  sets it.

**The stand-in BIOS** (`test/ngbios.s`) is not SNK's: it does only what an NTC cartridge needs
from one, the way SNK's does it - the 68000's vectors and the BIOS's jump table at their places,
the hardware made quiet (RAM, palettes and VRAM cleared, the watchdog kicked), the cartridge's
vectors and fix tiles switched in, USER called with request 0 and then 2, and the BIOS's own
VBlank, SYSTEM_RETURN and SYSTEM_IO. With SNK's BIOS a cartridge should run the same; that has
not been tried.

**Tests:** `bash test/ngregress.sh` (needs `NTC_VASM`, `NTC_SJASM`, `NTC_NGCORE` and Python's
Pillow): NTC's self test (36 tests), vb_test, vb_test2, 3, 4, 6, 7, 8, 9, vb_test_long, argfn, the
class demo and the sieve by their transcripts; the two tools; the classes (`test/neogeo/`): the
transcript (`Keys.Joystick` and `Pad.Read` with Up and A held), the picture (the table's sprite,
`Strip` / `Place` / `Join` / `Hide`, the backdrop's bands, `Cell`, `Fill`, the backdrop colour) and
the sound (the SSG, FM, a song and a sample each heard by itself, then quiet); and a Neo Geo CD
disc built. Not tested: `Vdp.Shrink`, `Vdp.TextBase`, `Cdda` (no Neo Geo CD emulator here).
vb_test11 has Z80 `#asm` in it.

## 6. In the compiler and library

- `;@a16 $110000` (platform header): the compiler writes `NTC_A16ADD equ $110000` and the
  `NTC_A16 aN` macro (an `adda.l`); with no `;@a16` (the other 68000 platforms) the macro is
  empty. The 68000 library has `NTC_A16` after each of its 15 `movea.w` address loads.
- `;@ramorg $100000`, `;@ramend $10C000`: the variables' RAM, as the X68000's.
- The platform's first section is `ntc_md_vectors` (the 68000 path's name for what comes first):
  the cartridge's vectors and header.

## 7. The Neo Geo CD (`neocd`)

**State: draft - built, not yet run.** `--platform=neocd` is the cartridge platform as a CD game
(`src/asm/ntc_plat_neocd.asm`: `;@base neogeo`, with only what is the CD's own). The console, the
pads, Frame, Ticks, `Pad`, `StdIO`, `System` and the sound driver are the cartridge's.

What is the CD's own:

- **The disc.** The CD BIOS loads the files `IPL.TXT` names (`name,bank,offset`, CR LF lines, a
  `$1A` byte at the end) into their memories by their extensions, then calls USER as a cartridge's
  BIOS does: `.PRG` the program (to 0 in the 2 MB of program RAM: the vectors and the header at
  `$100`, as a cartridge's P ROM), `.FIX` the fix tiles (an S ROM's layout), `.SPR` the sprites'
  tiles (1 MB banks), `.Z80` the Z80's program (its RAM), `.PCM` the ADPCM samples (the PCM RAM,
  1 MB). The BIOS wants all five.
- **Sprite tiles.** The same 128 bytes a tile as a cartridge's C ROM (the right half's 16 rows
  first, then the left half's), but each row's four bytes are planes 1 0 3 2 where a cartridge's
  interleaved C1 / C2 are planes 0 2 1 3.
- **Memory.** The 2 MB of program RAM has no 64K mirror: `$110000` is RAM of its own. So the
  variables move to `$0F8000-$107FFF` (`;@ramorg $0F8000`, `;@ramend $108000`, `;@a16 $100000`):
  a 16 bit address sign extended and `$100000` added lands in that 64K. The program (vectors,
  code, the RAM block's image) has to end below `$0F8000`.
- **Vectors.** 21-24 the CD BIOS's CD interrupt handlers (`$C004F2`, `$C004EC`, `$C004E6`,
  `$C004E0`); VBlank on both 25 and 26 (level 1 and level 2: the machines and the emulators don't
  agree which it is; the timer that would be the other is never on), acknowledged as all three.
- **VBlank** calls the BIOS's SYSTEM_IO each frame: the CD BIOS reads the pads and plays the CD
  audio from there.
- **CD audio.** The sound driver's `$40 t` puts a request in the Z80's RAM at `$FEF8` (`$80`, then
  the track at `$FEF9`, in BCD), `$41` a stop (`$82`). The header's CDDA flag (`$107`, the 0 after
  `NEO-GEO`) says that place, and the BIOS takes the request in SYSTEM_IO: it plays the track and,
  at its end, plays it again. (A play through the BIOS call `$C0056A` does not go round: the drive
  runs on into the next track.)

```
node test/ncdbuild.js Main.bas [More.cls ...] --out=GAME.cue [--name="GAME NAME"] [--ngh=3100] [--log]
     [--list=GAME.lst] [--asm=GAME.s] [--fix=S.BIN] [--crom=C.BIN | --spr=GAME.SPR] [--z80=M1.BIN]
     [--songs=SONGS.BIN] [--samples=SAMPLES.BIN] [--pcm=V.BIN] [--tracks=a.wav,b.wav,...]
```

`ncdbuild.js` compiles (`--platform=neocd`) and assembles as `ngbuild.js` does, and writes the disc
as a `.cue` and its tracks: `GAME_01.BIN` the data (an ISO 9660 file system with `IPL.TXT` and the
five files, as whole MODE1 sectors with their EDC and ECC, so it can go to a CD-R as it is), then
`GAME_02.BIN` on, the CD audio tracks from the WAV files (44.1 kHz, 16 bit, stereo), each with the
2 second gap before it. `--crom` takes a `.neo`'s C ROM bytes and turns them into the CD's order.

Checked so far: the file system reads back in another ISO 9660 reader (pycdlib); the `.SPR` of
TIANLONG decodes, by ngdevkit's description of the format, to the same pixels as its cartridge's
C ROM.

## 8. Not done

- The backdrop's bands are fixed at TIANLONG's four; no FM instruments or music player (`Fm` writes
  registers); the timer interrupt (level 2) is an empty handler.
- An MVS's coins and credits (the BIOS's `PLAYER_START`, `COIN_SOUND` are `rts`), backup RAM,
  the memory card, more than 1 MB of P ROM (bank switching).
- A run with SNK's BIOS, on a real AES or MVS, on a NeoSD or on MiSTer.
- The Neo Geo CD: any run at all (section 7). Loading more files while the program runs
  (`BIOSF_LOADFILE`).

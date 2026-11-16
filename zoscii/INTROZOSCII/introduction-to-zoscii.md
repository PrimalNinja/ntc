# INTRODUCTION TO ZOSCII — ZX Spectrum Next

An illustrated tour of ZOSCII and UNSIGNAL, written in NTC BASIC, with an "attacker" whose job is to prove the reasoning, not to break anything.
(c) 2026 Cyborg Unicorn Pty Ltd

## What it is

Fifteen sections from a contents menu (Q/A move, Space selects, O/P turn pages, Z returns):

1. The story so far: Vernam 1917, Shannon 1948 and 1949 (I(M;C)=0), Diffie-Hellman/RSA/Shamir/Shor and harvest-now-decrypt-later, then ZOSCII in 2025 by Julian Cassin.
2. Where ZOSCII came from: NTC's threaded text is a list of word addresses pointing at glyphs (`LD A,(HL)`). Live HELLO from the plain table against a random pick from a ROM.
3. What is a ROM? Read only memory is how we usually use it, not what ZOSCII needs: any block of bytes both sides have and nobody else knows (a chip, a file, RAM, a photo, 64 KB, 2 KB or 240 bytes). Not used up, needs no fairness, needs no maths: decode is one memory read.
4. Hiding a letter in a ROM: how many addresses hold a letter, six blind picks, the same address read by ROM 1, 2 and 3.
5. One stream, many meanings: file B read by ROM 1, ROM 1 with 45 cells changed, ROM 2, ROM 3.
6. Inside an UNSIGNAL file: the 4 header addresses read through the ROM, and a layout bar.
7. The rest of the family: ZOSCII, microZOSCII, UNSIGNAL, BRICS, ZWT, and the ZOSCII Rolling Hash with a live demo (change a letter and watch the hash). A page on the micro versions (microZOSCII, microUNSIGNAL, microBRICS).
8. Randomness, uncertain not fair (4 pages): unpredictable versus balanced, why a CSPRNG's evenness is a clean assumption handed to the attacker, captured versus generated, a live count of how skewed ROM 1 is, and why the real world fills a ROM from a JPEG or a song: ZOSCII needs the outsider to be uncertain, not the choices fair. The one thing to avoid is a generator that can repeat a sequence (never an unseeded one).
9. Shannon and key space (5 pages): the misconception that perfect secrecy needs a key as long as the message (that is the one-time pad; Shannon's condition is at least as many possible keys as possible messages, key space not key length); the key space of each ROM size (240 bytes typed in 2^1920, 256 bytes 2^2048, 512 bytes 2^4096, 2 KB 2^16384, 64 KB 2^524288, 128 KB 2^1048576; microUNSIGNAL and microBRICS add a 256-way offset, microBRICS one per block; a 2 KB ZOSCII ROM under a microUNSIGNAL layer multiplies the spaces); what actually protects you (no identifier says which ROM or message is right: plausible deniability, Shannon's nearest words equivocation, spurious keys and ideal system, weaponised ambiguity); known plain text attacks (page 5: they only have relevance if your entire security model is based on the primitive); and I(M;A)=0 exactly, from an attacker's point of view, for one address under a random unknown ROM; ZOSCII alone is the primitive (address frequencies can be counted but never reveal what is pointed to), so use UNSIGNAL or BRICS (or the micro ones) for one layer or as one of the layers, and 2+ layers or even BRICS remove any knowledge from address frequencies.
10. Getting the key across: out of band (swap or pick up a key in the office) is the strongest. Diffie-Hellman can be used when you can't meet (up to 4 shared secrets make a micro ROM that carries the full ROM), split over separate channels, but it is not the ultimate.
11. Have a play with ZOSCII: type a message, choose 1 to 3 layers (3 is plenty), the protocol of each layer (ZOSCII, UNSIGNAL, BRICS, microZOSCII, microUNSIGNAL or microBRICS; Q/A move, O/P change), the rolling hash (outside layer only), and the ROM pool (128K recommended, 64K, 2K). Layer 1 is the inside (encoded first) and the last layer is the outside, so "(OUTSIDE)" moves down as layers are added; layer n uses ROM n, a different key. A micro layer uses its own 256 nibble ROM and ignores the pool. UNSIGNAL and BRICS only work with the 128K pool and the 2K pool is one layer: nothing changes your settings behind your back, the encode says which rule was broken instead. Then attack your own file, decode it with the ROMs, or tamper with a byte. W on the setup screen opens the attacker on the four sample files.
12. See it, and 13. Try to work it out (hard coded, no ROM choice; Q or A on the first screen picks the protocol: ZOSCII, UNSIGNAL, BRICS, microZOSCII, microUNSIGNAL or microBRICS): a 128 KB ROM is made from the Rng each run, so it has never existed before. Every message is a random dictionary sentence of 52 characters (padded with spaces; plain ZOSCII's fixed length is a property of the primitive, UNSIGNAL's random prefix and suffix hide length), so every ZOSCII encoding is 104 bytes; with the other protocols the encodings are different lengths. Pages: 3 examples (a message and its encoding, the same message encoded twice, another message; long encodings are cut with "..."), THE CHALLENGE (instructions), the 10 messages with "52 CHARS", the 10 encodings A to J (shuffled against the messages) shown IN FULL over as many pages as they need (11 addresses a row, 22 bytes for the micro protocols; an encoding that does not fit carries on to the next page under "CONTINUED"), then the attacker, the answer and the proof. The challenge page: photograph the encoding pages and the messages page, or press Space to save the files: on the Next MSG01.TXT to MSG10.TXT (the 52 characters encoded) and ENCA.BIN to ENCJ.BIN (the raw encoding, low byte first) in the top folder of the SD card (8.3 names, esxDOS); in the browser one download, zoscii-challenge-yyyymmddhhnnss.zip, holding message1.txt to message10.txt and encodingA.bin to encodingJ.bin. Give the encodings to any analytical tool without the messages, then the messages, and ask it to decode or pair them: it has everything except the ROM. In 13 you pair each encoding with a message first (Q A choose, Space confirm) and the answer shows your score; blind guessing gets about one in ten. The proof picks an encoding and a different message whose letters don't clash with the encoding's repeated addresses, changes about 50 ROM bytes so the encoding reads as that message (UNSIGNAL: through its own header offset), then puts the ROM back.
14. Primitive and protocols: the difference (3 pages: ZOSCII: The Primitive; ZOSCII vs encryption primitives; ZOSCII: The Protocols). Page 2 sets the primitive against AES, ChaCha and XOR (lookup, not maths; ROM as key; I(M; A) = 0 per address; ROM places can be reused, AES resists known plain text and the primitive does not); page 3 is the protocols (UNSIGNAL, BRICS, micro, layers).
15. Tiny machines, tiny ROMs, bootstrapping (4 pages) Chat is real time on a Z80, big files are not. Amstrad CPC, 4 MHz, 64 byte messages, 1 KB ROM, emulated: NTC BASIC 24 encodes and 108 decodes a second; hand-coded NTC (written before the compiler) with a real random choice 25 and 68; 57 encodes a second before the compiler, with no real random choice (the author's measurement). Browser JavaScript 211,864 / 724,637 a second; GPU (Google Colab T4, 512 byte messages, 2M batch) 15,609,655 / 47,723,242 a second (7,992 and 24,434 MB/s); AES-256 in the same JavaScript test 13,885 / 17,543. The micro versions give real time messaging in interpreted BASIC on the VIC-20 (3.5 KB, with 32 KB expansion), Commodore 64 and Amstrad CPC. Bootstrapping: a person can type or scan about 54 characters; 3 lines of 54 give a 240 byte micro ROM (6 lines, 480), which encodes the 64 KB or 128 KB ROM. The lines can live in a session cookie, a phone contact list or a messenger list, be split between people on a submarine, scanned as a QR code, tapped in by NFC or typed. Fed by a computer or Diffie-Hellman (3 or 4 shares) the micro ROM is 256 or 512 bytes. It needs good entropy and good random.
16. The fine print.

The figures on page 14 come from `tools/bench/`: `bench.py` times the hand-coded CPC speed test (`speed_orig.asm`, and `speed_fixed.asm` with the random choice repaired: a 16 bit xorshift and a bit mask with retry instead of a counter and repeated subtraction, and the salt no longer zeroed every pass) in the Z80 module by counting T-states, and `cpc_speed.bas` is the NTC BASIC version, run with `test/cpcrun.py` in NTC's CPC emulator. All are emulated at 4 MHz without the CPC's wait states, so real hardware is somewhat slower. The ZX Next has been run only in an emulator.

## The attacker

The attacker holds the file and nothing else. Q/A choose the attack, O/P the file (A to D, and YOUR FILE once you have made one in Have a play), W/S the crib (the first word of your message is offered as a crib for your own file), Space runs it.

| Attack | What it does |
|---|---|
| Readings | For each way of cutting the file into addresses (starting at byte 0 or byte 1) counts pairs of equal addresses and compares with the count expected by chance, n(n-1)/2 divided by the pool size. |
| Crib drag | Places a guessed word at every position of every reading. Equal addresses under different letters rule a placement out. It reports "DEFINITELY ISN'T" or "MIGHT BE", never "IS". |
| Has the ROMs | Key compromise, not an attack: decodes layer by layer with the ROMs and shows the message. |

Fixed rule: equal addresses show which positions hold the same byte. They never say what the byte is, and they give no certainty either, because the alignment may be wrong. Real files normally have 1 to 3 layers, so a crib (plain text) means nothing against a layered file. The program says so.

Dev files: A = ZOSCII on a 2KB ROM (a small pool repeats addresses, so it stands out above chance). B = UNSIGNAL, 1 layer. C = 2 layers. D = 3 layers.

### Simplifications against the JS attacker (`unsignal-attacker.html`)

- Integer maths only. The Poisson tail is replaced by pairs against the expected count (shown to one decimal). "Above chance" means pairs >= 3 and more than 4 times the expected count.
- The crib verdict uses the best count of agreeing pairs, with no p-value.
- Pairs are counted with bucket chains on the low address byte.
- It works on the four supplied files and on the file you make in Have a play. There is no dictionary attack, no BRICS reading and no custom API.
- In Have a play, layered files use a random prefix and suffix of 10 to 70 bytes (UNSIGNAL's own range is 10 to 255) so that three layers fit in memory. A single layer uses 10 to 255.

## Build

```
node tools/devassets.js        # optional: makes the dev stand-in ROMs and files
node tools/assets.js           # packs assets/INTRO.DAT and writes src/Data.cls
node tools/build.js both       # needs NTC's src folder (NTC_SRC or argument) and sjasmplus (SJASMPLUS=...)
python3 tools/shots.py         # emulator walkthrough, writes screenshots/
```

`build/INTRO.NEX` is the turbo build, `build/INTRON.NEX` the normal one. Both need `INTRO.DAT` beside them.

## How it is put together

| File | Role |
|---|---|
| `src/Main.bas` | `Option Turbo`, `Option NexData "INTRO.DAT", 26`, `Option Reserve &H4000, &H4000` (the program stays out of the data window at #4000), then `Intro.Run`. |
| `src/Vid.cls` | Layer 2 320x256, 16-colour palette, 5x7 font, text, hex and big characters, `SelBlock` (pages a 16K data block into #4000), `TabB` (a byte of the tables), `Edge` (key edges), `Page`. |
| `src/Rom.cls` | `B()` reads ROM index offset+address in Z80 with the 17th bit kept. `Layer` decodes ZOSCII or UNSIGNAL (header read through the ROM). `Pick` and `Count` for a blind pick and a letter count. `Patch` applies the alternative-ROM cells. |
| `src/Attack.cls` | The three attacks. |
| `src/Intro.cls` | Title, menu and the pages (family, randomness, key sharing, rolling hash demo). |
| `src/Play.cls` | Have a play: typing, options, the encoder driver, decode and tamper. |
| `src/Data.cls` | Generated: offsets of every text, table and ROM block. Do not edit. |
| `tools/text.js` | Every on-screen string (characters 32 to 90 only, lowercase shows as upper case). |
| `tools/zlib.js` | The encoder, decoder and framer lifted unchanged from the JS attacker. |

Blocks of `INTRO.DAT` (16K each): 0 tables (font, then text, manifest, cribs; offsets from 16384 are read from the last block, TAB2); 1-8 ROM 1; 9-16 ROM 2; 17-24 ROM 3; 25 small ROM (2KB), files, patch; 26 blank scratch RAM (the file made in Have a play, and the attacker's address tables).

## The random numbers (src/Rng.cls)

NTC's own `Rnd` is a 16 bit xorshift that starts at the same seed every run, so the demo doesn't use it. `Rng` is the Next version of CyborgUnicorn.ZOSCII's ROMGenerator:

- Seed: every change on the keyboard (checked once a frame, from `Vid.Sync`) mixes the tick it happened on, the ticks since the last change (hold and bounce time), the keys down and the count of changes into a 64 bit pool. `Play` also mixes in the typed message.
- Source: INTRO.DAT's data blocks 0-24 in 1KB chunks, put in an order from the seed (the order table is in the scratch block at byte 2560, 2 bytes a chunk).
- Five readers each start at a random place in a random chunk, each goes forward or backward with two steps of 2-100 bytes (chosen from the seed) that alternate: 5, 75, 5, 75...; the output byte is the XOR of the five.
- `Pick(n)` is 0 to n-1: the bytes the readers give, wrapped into the range with Mod. No retry, nothing evened out.
- The program only calls `Rng.Rb`, `Rng.Pick`, `Rng.Mix`, `Rng.Reseed` and `Rng.Start`; a file based class (real MP3s, as CyborgOS does) can replace Rng.cls with the same calls.
- `tools/rng.js` is the same algorithm in JS, with entropy, mean, chi-square and serial correlation tests (`node tools/rng.js stats`). Its output matches the Next's byte for byte for a fixed pool.
- Limits: an all-zero pool stays all-zero (the program starts from the digits of pi, so it never is); the source memory is public, so the only secret in the stream is the seed; speed is about 1 ms a byte.

## Replacing the assets

Replace these files in `assets/` with the real ones (same names and formats), then run `node tools/assets.js` and `node tools/build.js both`:

- `rom1.bin`, `rom2.bin`, `rom3.bin`: exactly 131072 bytes each. A file with 2 layers uses ROM 1 and 2; 3 layers use ROM 1, 2 and 3.
- `rom_s.bin`: up to 2048 bytes.
- `file_a.bin` to `file_d.bin`: the encoded files as an attacker would hold them, at most 2304 bytes each. All files, the small ROM and the patch together must fit in one 16K block.
- `alt_b.bin`: the patch that makes ROM 1 read the plausibility file as another sentence. 4 bytes per cell: ROM index low, mid, high, new value.
- `manifest.json`: per file, `layers` outermost first as `[protocol, rom]` (protocol 0 ZOSCII, 1 UNSIGNAL; rom 0-2 = rom1-3, 3 = rom_s), `win` (the outer pool size in bytes); `cribs` (the words offered); `altFile` (which file the plausibility page uses).

The plausibility and anatomy pages assume file `altFile` is single-layer UNSIGNAL on ROM 1.

## Known limits

- A file can be at most 2304 bytes (the working arrays), and only the first 1280 addresses are used for the readings and crib tests.
- `Count` returns an Integer, so a byte value with more than 32767 places in the pool would overflow.

## Memory layout
The program is split into NTC pages (`Option Page ... Loaded n`, Option Memory CPCExpansion): SCR (the static text screens, `Screens.cls`), DEMO (`Demo.cls`) and PLAYP (`Play.cls`, `Attack.cls`). Code in a page runs in the data window (#4000-#7FFF), so it cannot select a data block itself; the work that touches blocks is in resident code (`Vid.Pe`, `Vid.Pk`, `Rom.Gen`, `AtkW.cls`, the Rng and Rom accessors), and `Vid.SelBlock -1` restores the current page, not bank 9. Program end #A192 turbo / #A195 normal, built with the NTC of 20261105-0940 (the main RAM limit is #BA00).

## The demo protocols (src/Proto.cls)
Baselines, written from the specs, not the only way: each rule is a small routine to replace (BlkSize, Pad, Offs). The big ROM is 128 KB with 16 bit addresses; the micro ROM is 256 nibbles (each value 16 times, shuffled) with 8 bit addresses, a message byte is two nibbles (high, low), so microZOSCII gives the same 104 bytes as ZOSCII. UNSIGNAL: 4 header addresses (offset low, offset high, prefix length, suffix length), a random prefix and suffix (10 to 255 bytes; micro: 10 to 15, the nibble values the spec allows), the payload read at the offset. BRICS: 6 header addresses (block 1 offset, block 1 size, prefix, suffix), then each block is a 4 address header for the next block (the last one's are noise) followed by its data, block sizes 8 to 24 elements in the demo (the spec suggests 128 to 512 for real files); micro sizes count addresses, so two per letter. The micro address space wraps (regime 2). Nothing validates a file: every ROM decodes every file. The proof page works for the big ROM protocols; the micro ROM is too small to rewrite for an arbitrary message (the 104 addresses repeat over 256 positions), and the page says so.

## Word list
The demo's random sentences use `assets/words.txt` (words of at most 8 letters). `tools/assets.js` leaves out a block list of 25 words: religions and their people, peoples and places in conflict, war and violence terms (BLOCK in assets.js; add to it, it applies to any word list you supply), so a random sentence never reads as a statement about any of them.

## The demo attacker (page 9 of the demo, Demo.Probe)
One screen, two panels like the JS attacker: the word you type and the notes on the left, the table of the 10 encodings on the right. Between the encodings and the answer (or the pairing game) you type a word or phrase (up to 15 letters, Play.Line) and the program slides it over each of the 10 encodings, at every position and, for 16-bit addresses, both byte pairings. A position is ruled out only where two equal addresses would need two different letters; every other position fits. The page shows, per encoding, the positions tried, ruled out and still possible. The file says nothing about where the text is or whether it is there, so most positions always remain. The pages are now 0-2 examples, 3 the challenge, 4 the texts, 5 on the encodings (as many pages as the encodings need), then the attacker, the pairing game (mode 1 only), the answer and the proof.

## Startup splash
Splash.cls (from CYBORGUNICORN_SPLASH) is a class in the SCR bank. Main.bas has `#Const SplashNoPlain = 1`, so the program shows the Cyborg Unicorn screen, then the NTC BASIC screen, then the title. A key skips a screen. tools/splashtest.py shots it.


## Update 20261109
- Section 14 now has a 4th page, WHY USE BRICS? (strongest protocol; same address, multiple values; perfect denial after the fact; prove/deny/fabricate; masks hide messages in 3rd party assets without modifying them).
- The Fine Print page 1 adds: recommended keys are JPEG photos (captured physics, cannot be fabricated or guessed, recognisable by you; show the look, never give the file).

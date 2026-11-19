# NTC on the Fujitsu FM Towns (`towns`)

The FM Towns is an 80386 machine (16 MHz on the first models, 1 MB of RAM or more, 1024
sprites, two screen layers of up to 32768 colours, FM and sample sound, a CD drive). It is
NTC's first x86 platform.

**State: games run.** A program boots from its own floppy image in 32 bit protected mode,
has the text console, the keyboard, Frame and Ticks, and since 20261119-1 the classes a game
needs (section 5): sprites, a scrolling backdrop and words (`Vdp`), held keys and the pads
(`Keys`), PCM music and sound effects (`Pcm`), free memory (`Memory`) and data files loaded
above 1 MB. They were lifted from TIANLONG, the first game written for the machine. It runs
NTC's self tests and that game on the Tsugaru emulator with the free compatible ROMs. There
is no file class, no Towns OS program (`.EXP`), no CD image, and nothing has run on a real
FM Towns.

## 1. How NTC works on the 80386

The same way as on the Z80 and the 68000, with the 80386's registers:

- **ESP is the thread pointer.** A keyword ends with `ret` (the next keyword's address is
  the next thread word) and takes its operands with `pop`. Thread words are 32 bits.
- **Ring 3.** The program runs in ring 3. An interrupt or an exception switches the CPU to
  ring 0 and to the ring 0 stack by itself, so it never writes on the thread. Interrupts
  are on all the time: there is one mode, and `Turbo On` / `Turbo Off` do nothing (as on
  the 68000).
- **Flat memory, no paging.** Ring 3 has every I/O port (IOPL 3) and all of memory, so
  `#asm`, `Inp` and `Out` reach the hardware directly.
- **Integer is 16 bits, Long 32 bits**, little endian (the low byte first, as on the Z80;
  the 68000 has the high byte first).
- **A compare leaves its result in the Z flag** (Z = true). `pop`, `mov`, `lea` and `ret`
  keep the flags, so the result reaches the next keyword.
- **A keyword that needs `call` or `push`** goes to the real stack first: `NTC_RS`, then
  `NTC_TS` to come back to the thread (the same two macros as the 68000 library).
- All of `eax ebx ecx edx esi edi ebp` are free in a keyword.

`#asm` is nasm syntax. A keyword function gets its arguments' addresses off the thread,
the result's address last:

```
Function AddAsm(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
            pop esi
            mov ax, [esi]
            pop esi
            add ax, [esi]
            pop edi
            mov [edi], ax
#endasm
End Function
```

In `#asm` inside ordinary code `{k}` is the variable's address: `mov ax, [{k}]`.

## 2. What a program is

A 2HD floppy image: 77 tracks, 2 sides, 8 sectors of 1024 bytes (1261568 bytes, a raw
image). The machine's ROM reads the first sector to `B000:0000` and, when it starts with
`IPL4`, far calls `B000:0004` in real mode. That sector is NTC's: it reads the rest of the
program with the ROM's disc call (`FFFB:0014`), sets up protected mode and starts the
program. Towns OS is not on the disc and is not needed.

## 3. Memory

| Addresses | What |
|---|---|
| `$000400-$0006FF` | the ring 0 stack (interrupts, exceptions) |
| `$000700-$00076F` | the TSS |
| `$000800-$000FFF` | the IDT (256 gates) |
| `$001000-$00FFFF` | the program's variables, the library's, then its arrays: 60K |
| `$010000-` | the program: start code, threads, keywords, strings |
| `-$0AFFFF` | the real stack (the library's `call`s), from the top down |
| `$0B0000-$0B03FF` | the boot sector (it holds the GDT) |
| `$100000-` | the high data (`section .ntchigh`), when the program has some |
| `$0C0000-` | the screen and the font ROM |

- **Variables and arrays have 60K.** NTC keeps a variable's address in 16 bits on this
  compiler path, so they are below `$10000`. `Peek`, `Poke`, `Deek`, `Doke`, `VarPtr`,
  `CallAddr` of machine code and array descriptors reach `$0000-$FFFF`. `#asm` reaches all
  of memory.
- **Code and strings** have `$10000` up to the real stack: about 600K.
- **High data** (a 2 MB machine): files a program names with `NTC_HIGHFILE label, "FILE"` in
  `#asm` are put on the disc after the program and loaded to `$100000` on by the boot sector
  (each track read to `$A0000`, then copied up in protected mode). The label is the address
  the file is loaded at; `#asm` reaches it (it is above 64K, so not `Peek`):

  ```
  Public Function Base() As Long
  #asm
              pop edi
              mov dword [edi], gd_data
              NTC_HIGHFILE gd_data, "GAME.DAT"
  #endasm
  End Function
  ```

  Up to 1 MB on a 2 MB FM Towns or Marty; the program and it share the disc's 1232K.
  `townsbuild.js` says how much there is and warns past 1 MB. (The macro is
  `section .ntchigh`, `incbin`, `section .ntccode`.)
- **Free memory:** the `Memory` class hands out what NTC does not use: from the end of the
  program to `$9F000` (`Memory.Alloc(bytes)`, `Memory.Free()`), and from the end of the high
  data to the top of the machine's RAM (`Memory.AllocHigh`, `Memory.FreeHigh`). A block is a
  Long address for `#asm`. `$9FFF0-$9FFFF` (the exception record, a test build's transcript
  pointer) and `$A0000-$AFFFF` (the real stack, a test build's transcript) are NTC's: a
  program that picks addresses by hand must keep off them.
- **`Inp(n)` and `Out n, v`** are the 80386's I/O ports (16 bit port numbers).

## 4. The console, keys, Frame and Ticks

- **Screen:** 80 x 25 characters, drawn on the 640 x 400 screen the ROM boots with, from
  the ROM's 8 x 16 font. `Print`, `Cls`, `Locate`, `Mode` (one mode: it clears) and
  scrolling work. White on black; no colours yet.
- **Keys:** `Inkey`, `Inkey$` and `Input` read the keyboard at its ports (`$600`, `$602`),
  with no interrupt. A key gives its character (the Towns JIS layout, Shift for capitals
  and the upper symbols); the cursor keys give `&HF0 &HF1 &HF2 &HF3` (up, down, left,
  right, as on the CPC), Return 13, ESC 27, Backspace 8, Delete 127. Caps lock and Ctrl
  are not used.
- **Frame** waits for the vertical blank interrupt (line 11). **Ticks** counts frames: 60
  a second (`System.TicksPerSecond`).
- **End / Stop:** the program stops and stays; a boot disc has nowhere to go back to.
- **An exception** (a bad address, an invalid instruction) stops the machine.

Classes: `StdIO` and `System` (`lib/towns/`), and the games' classes below.

## 5. The classes for games (`lib/towns/`)

| Class | Members |
|---|---|
| `Keys` | `Down(key)`: True while the key is held (`Keys.KeyQ`, `KeyLeft`, `KeySpace` ...: the same names as on the Next). `Joystick(n)`: the pad in port n + 1 as `JoyUp`, `JoyDown`, `JoyLeft`, `JoyRight`, `JoyFire1` (A), `JoyFire2` (B), `JoyRun`, `JoySelect` |
| `Memory` | `Alloc(bytes&)`, `Free()`, `AllocHigh(bytes&)`, `FreeHigh()`: Long addresses, 0 when there is not that much |
| `Vdp` | the screen: 256 x 240, two layers of 32768 colours (15 kHz, the Marty's TV). `Init`. Sprites: `Sat()` (the table's address: 128 x 4 words, as the hardware's), `HideAll`, `Update`, `Pcg addr&, first, n` (patterns, 128 bytes each), `Colors addr&, first, n` (palettes of 16). The backdrop: `Load pic&, pal&` (256 x 192, a byte a pixel), `Bands a, b, c, d` (the scroll of four bands: lines 0, 56, 112, 152), `Blit` (the bands that moved, drawn), `Dirty`, `Buffer()` (the backdrop's copy, to draw on), `BgColour(k)`, `GFill y, n, c`, `Pic4 pic&, pal&` (a 256 x 240 picture in 16 colours). Words: `Font addr&, colours&`, `Text cx, cy, s$, c, shadow`, `TFill cx, cy, w, h`. `IsSX()`, `WaveRam()` |
| `Pcm` | the RF5C68: `Init data&` (songs made by `tools/adpcm/okiadpcm.js --target=towns`), `Have(n)`, `Play n, loop`, `Quiet`, `Update` (once a frame: the music decoded on), `Voice k, step, loudness`, `Gate k, on` (channels 1-3 a square wave, 4 noise) |

- The keyboard sends a key's press and its release; the platform follows them (one routine
  for `Inkey`, `Input` and `Keys`, so they can be mixed).
- `Vdp` takes 96K from `Memory` at `Init` for the backdrop's copy. The four bands are the
  ones the Next's copper gives TIANLONG; a game with other bands draws on `Buffer()` itself.
- `Vdp` reads the machine's ID: the 386SX machines (the Marty, the UX) have the video and
  wave RAM at other addresses.

## 6. Building and testing

Tools (none are part of NTC):

- **nasm:** `www.nasm.us`, or the system's package. `NTC_NASM` can give its path.
- **Tsugaru** (the FM Towns emulator): `github.com/captainys/TOWNSEMU`, built with cmake;
  the test runner uses `Tsugaru_Headless`. `NTC_TSUGARU` is its path.
- **ROMs:** the free compatible ROMs from `github.com/captainys/TOWNSROM` (the files
  under `release/forTsugaru`), or a real machine's. `NTC_TOWNSROM` is their folder.

```
node test/townsbuild.js Main.bas [More.cls ...] --out=GAME.bin [--log]
python3 test/townsrun.py GAME.bin [--secs=N] [--keys=seconds:text,...] [--pad=seconds:bits,...] [--shot=out.png] [--log] [--anykey] [--freq=MHz]
bash test/townsregress.sh
```

- `townsbuild.js` compiles (`--platform=towns`), assembles with nasm (`-f bin`) and writes
  the disc image. `--log` makes a test build that keeps what the console prints in RAM
  from `$0A0000`.
- `townsrun.py` boots the disc on Tsugaru with no window: it types text at the times given
  (the emulator ends each typed text with Return), saves a picture, and prints a `--log`
  build's transcript. `--anykey` presses a key at a "Press a key" prompt; `--freq` sets the
  emulated CPU's speed.
- `--pad` holds the pad in port 1 (1 up, 2 down, 4 left, 8 right, 16 A, 32 B, 64 RUN; 0 lets
  go). Tsugaru has no console command for that: `test/tsugaru-padset.patch` adds one
  (`PADSET`); apply it to Tsugaru's source before building it.
- `townsregress.sh` runs 18 tests (the last, `test/towns/Classes.bas`: the Memory and Keys
  classes and a high data file; its pad press needs the patched Tsugaru): the self tests (vb_test, vb_test2-4, 6-9, long, argfn,
  class, sieve), `test/towns/self` (the 68000 self test, 154 checks, with its machine code
  in 80386), `test/towns/Extra.bas` (the keywords the others do not reach: its text is
  compared with `Extra.txt`, and is the same on the X68000), guide (typed input) and
  `test/towns/Main.bas` (typed input, Inkey, Ticks, Locate). vb_test runs at 2 MHz: its
  clock test wants a frame to pass in a short loop, which a 16 MHz 80386 finishes too soon.

## 7. In the compiler and library

- `;@cpu x86` in the platform header. The compiler uses its 68000 path (32 bit thread
  words, variables in a RAM block, the same call stubs) and a last pass turns the output
  into nasm: the data lines, and the small set of 68000 lines the compiler writes itself
  in a procedure's call stub. A line the pass does not know is a compile error, not a
  guess.
- `asm/ntc_lib_x86.asm` is the keyword library, written in nasm: every section the 68000
  library has (`asm/ntc_lib_68k.asm`), with the same names and operands.
- `;@ramorg` and `;@ramend` (as on the X68000): the variables are assembled at `$1000` and
  must end by `$10000`.
- nasm writes the file as: the boot sector, the code (run from `$10000`), then the
  variables' first image. The boot sector loads all of it at `$10000`; the start code
  copies the image down to `$1000`.

## 8. Not done

- Colours for the console's text, the FM sound chip, the mouse, files, the CD drive.
- Backdrop bands other than TIANLONG's four, tile layers.
- Blocks from `Memory` are not given back.
- A Towns OS program (`.EXP`) and a CD image that boots.
- More than 60K of variables and arrays.
- The `Interrupt` statement and interrupt classes.
- A run on a real FM Towns or on a real machine's ROM.

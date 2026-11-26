# The Commodore Amiga 500 platform (`amiga`)

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

**Status (2026-11-24): first stage, run on an emulator only.** A 68000 boot disc that takes the
machine and works the hardware itself. In it: the boot, the memory found (chip, slow, fast), the
console, the keyboard and joysticks, and a disc loader for one to four drives with discs
changed. Not in it yet: graphics, sprites, the blitter and sound classes (section 8).

It has run on the PUAE emulator with the Kickstart replacement the emulator carries (AROS). It
has not run on Commodore's Kickstart 1.3 or on a real Amiga.

## 1. What a program is

- A floppy image (`.ADF`: 80 tracks, 2 sides, 11 sectors of 512 bytes, 901120 bytes).
- Its first two sectors are the boot block. Kickstart reads it and runs it with the system alive.
  The boot block notes what memory the machine has, reads the program with the ROM's disc
  driver into memory the system lends it, then switches the system off for good (supervisor
  mode, no interrupts, no DMA), moves the program to where it runs and starts it.
- From there nothing of the operating system is used: no libraries, no AmigaDOS, no ROM calls.
  The program has the whole machine.
- The program runs in user mode with A7 as the thread; the interrupts run in supervisor mode on
  their own stack, so they stay on all the time (as on the X68000 and the Mega Drive).

## 2. Memory

| Addresses | What |
|---|---|
| `$000000`-`$0003FF` | the 68000's vectors |
| `$000400`-`$007FFF` | the program's variables, the library's, its arrays (their addresses are 16 bits) |
| `$008000`-`$00BFFF` | the real stack, top down |
| `$00C000`-`$00FFFF` | the supervisor stack (the interrupts), top down |
| `$010000`- | the program: start, threads, keywords, strings |
| after it, to the top of chip RAM | the chip pool: the console's screen (20K) first, then `Memory.Alloc`'s blocks |
| `$C00000`- (slow), `$200000`- (fast) | the other pool: `Memory.AllocOther`'s blocks |

What the machine has is found at the start, not set when building:

- **Chip RAM:** 512K, 1 MB or 2 MB. `System.ChipRam()` gives it in K.
- **Other RAM:** the trapdoor's "slow" RAM and "fast" RAM in the side slot, up to 8 MB.
  `System.OtherRam()` gives it in K (0: none). Up to two blocks of it are used.
- A game that needs more than 512K checks at its start and says so:
  `If System.ChipRam() < 1024 Then Print "This game needs 1 MB of chip RAM"`.

The `Memory` class hands the free memory out in blocks (Long addresses):

| Call | |
|---|---|
| `Memory.Alloc(bytes)` | chip RAM: what the custom chips show, play and blit. 0: not that much left |
| `Memory.AllocOther(bytes)` | the other RAM. 0: not that much, or the machine has none |
| `Memory.AllocAny(bytes)` | the other RAM when there is that much, else chip RAM: for anything the chips need not reach |
| `Memory.Free()`, `Memory.FreeOther()` | the bytes left |

Blocks are not given back.

The boot image (the variables and the program) has to fit in free memory while the system is
still alive, so keep big data out of the program: put it on the disc as files (section 5) and
load it into blocks.

## 3. The console

- One bitplane, 640 wide: 80 x 32 characters on a PAL machine (640 x 256), 80 x 25 on an NTSC
  one (640 x 200). NTC's own font (characters 32-126), white on blue.
- `Print`, `Input`, `Inkey`, `Cls`, `Locate` as on every platform. `Input` shows the cursor's
  cell inverted while it waits. `Mode` clears the screen and shows the console again (after a
  game's own display).
- `System.Hz()` is 50 or 60: the frames (and `Ticks`) a second.

## 4. Keys and joysticks

- The keyboard through CIA-A (US layout): `Inkey` / `Input` give characters; the cursor keys are
  `&HF0`-`&HF3` (up, down, left, right), Return 13, ESC 27, backspace 8, Del 127. Caps Lock works.
- `Keys.Down(key)`: a key held now (`Keys.KeyQ`, `Keys.KeySpace` ...: the Amiga's own key
  numbers under the names NTC's other machines use; also `KeyF1`-`KeyF10`, `KeyHelp`, `KeyAlt`,
  `KeyAmiga`).
- `Keys.Joystick(0)`: the stick in port 2 (where a game's joystick goes); `Keys.Joystick(1)`:
  the one in port 1. The bits are the other machines': `JoyUp` 1, `JoyDown` 2, `JoyLeft` 4,
  `JoyRight` 8, `JoyFire2` 16 (a second button), `JoyFire1` 32.

## 5. Discs and files

There is no file system on the disc. `amigabuild.js --file=NAME=path` puts each file after the
program and writes a list of them; the `Loader` class reads the list and the files, working the
drives directly (the motor, the head, the disc DMA, the MFM decoding and its checksums).

```
node test/amigabuild.js Main.bas --out=GAME.adf --file=TITLE=title.raw --file=LEVEL1=l1.bin
     --file=MUSIC=tune.raw@2
```

- `@2`, `@3` ... puts a file on another disc of the set (`GAME_2.adf` ...): a data disc that does
  not boot. The list is on the boot disc.
- A name is up to 15 characters, any case.

| Call | |
|---|---|
| `Loader.Load(name, address, maxlen)` | the file into memory: its length, or a status below |
| `Loader.Size(name)` | its length, or `NotFound` / `Failed` |
| `Loader.Disc(name)` | the disc it is on (1 the boot disc), 0 no such file |
| `Loader.Drive(disc)` | the drive (0-3) that disc is in now, or -1 |
| `Loader.Drives()` | how many drives the Amiga has (1-4) |
| `Loader.Wanted()` | after `WrongDisc`: the disc wanted |
| `Loader.Read(drive, sector, address, bytes)`, `Loader.MotorOff` | sectors straight off a disc, for a layout of the game's own |

Statuses: `NotFound` -2, `TooBig` -8 (the file is bigger than maxlen: nothing loaded), `Failed`
-9 (the disc would not read), `WrongDisc` -10 (its disc is not in any drive).

**Two drives, and changing discs.** A file is looked for on whichever drive has its disc, so a
two disc game on a machine with two drives never asks for anything. With one drive:

```
n = Loader.Load("MUSIC", buf, 300000)
If n = Loader.WrongDisc Then
    Print "Insert disc"; Loader.Wanted()
    Do While Loader.Drive(Loader.Wanted()) < 0 : Frame : Loop
    n = Loader.Load("MUSIC", buf, 300000)
End If
```

Each disc carries a label (its number and a mark shared by the set), so the wrong game's disc
is not taken for the right one. A drive is only looked at again when a disc has been put in.

A track takes a fifth of a second to read; a full disc about 35 seconds.

## 6. From `#asm`

- The custom chips (`$DFF000`), the CIAs and all memory are open to user mode; only the 68000's
  own privileged instructions need `lea routine, a0` / `trap #1` (it runs in supervisor mode and
  ends with `rts`).
- Interrupts: level 2 is the keyboard, level 3 the frame; the others are taken back and nothing
  done. A game's own handler goes in the vector (`$64`-`$78`) and is switched on in INTENA.
- `ntc_ami_scr`: the console's bitplane. `ntc_ami_cop`: its copper list. `ntc_ami_chip`: the top
  of chip RAM. `ntc_ami_alloc` (d0 = bytes, d1 = 0 chip / 1 other), `ntc_ami_dread` (sectors),
  `ntc_ami_fload` (a file): on the real stack.
- An exception (a bus or address error, a divide by 0 ...) stops with the screen red.

## 7. Building and testing

```
node test/amigabuild.js Main.bas [More.cls ...] --out=GAME.adf [--log] [--file=NAME=path[@disc]]
python3 test/amigarun.py GAME.adf [GAME_2.adf] [--model=A500] [--chip=1024] [--fast=8]
        [--drives=2] [--swap=frame:n] [--keys=...] [--joy=...] [--shot=out.png] [--log]
bash test/amigaregress.sh
```

- `amigabuild.js`: the NTC compiler, then vasm (`NTC_VASM`), then the disc with the boot block's
  checksum filled in.
- `amigarun.py`: the PUAE libretro core (`NTC_AMIGACORE`: github.com/libretro/libretro-uae,
  `make`), no window. It sets the machine (`--model`, `--chip`, `--slow`, `--fast`, `--ntsc`),
  types keys, holds the joystick, changes discs, saves pictures and prints a `--log` build's
  transcript.
- `amigaregress.sh`: 15 self tests by their transcripts (the ones the X68000 runs), then the
  classes: files read at the drive's real speed, a file on a second disc with one drive (the
  disc changed) and with two, the joystick, a key held, the memory found on five machines
  (512K + 512K slow; 1 MB chip; 1 MB + 8 MB fast; 2 MB + slow + 4 MB fast; 512K + slow + 2 MB
  fast), an NTSC machine.

**Not tested:**

- Commodore's Kickstart (1.2, 1.3, 2.x, 3.x) and a real Amiga. The boot block uses only exec's
  `AllocMem`, `DoIO` and `Supervisor` and three fields of exec's base, all the same since 1.2.
- A bare 512K machine: the replacement Kickstart does not start in 512K, so the smallest machine
  run is 512K chip + 512K slow. Nothing in NTC needs the second 512K.
- Real drives: the step and settle times are the usual ones (3 and 15 thousandths of a second);
  a worn disc's retries (four a track) have only seen an emulator's perfect disc.
- DF2 and DF3, a keyboard that is not US, a second joystick button.

## 8. Not done

- Graphics beyond the console: bitplane displays, the copper, sprites, the blitter. A game sets
  the chips itself from `#asm` for now.
- Sound: Paula's four sample channels.
- Writing to a disc (saves).
- The mouse.
- More than two blocks of other RAM; memory given back.
- `Vdp` and `Pcm` classes in the shape of the other 68000 machines': next, for TIANLONG.

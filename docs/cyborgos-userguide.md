# CyborgOS - user guide

CyborgOS runs several CP/M-style programs at once on an Amstrad CPC, each in its own 64K bank,
with a command line for each. It is an NTC BASIC program (the hypervisor) running with the
firmware; the programs are NTC BASIC programs built for the cpm platform. The design and what
is still to come are in [cyborgos.md](cyborgos.md).

This describes the first version (October 2026).

## 1. What you need

- A CPC 6128, or a CPC with a RAM expansion. CyborgOS uses half of the extra 64K banks for
  slots, at least 1 and at most 8; the rest is left for later (drivers, data, graphics):

  | Extra RAM | Slots |
  |---|---|
  | 64K (a 6128) | 1 |
  | 256K | 2 |
  | 512K | 4 |
  | 1MB or more | 8 |

- AMSDOS (a disc drive): programs are loaded from disc.
- `build/dsk/cyborgos.dsk` has CYBORGOS.BIN and two test programs (TICKER.CYB, CRUNCH.CYB).

## 2. Starting

```
RUN"CYBORGOS
```

The screen goes to mode 2 (80 x 25) and slot 1 shows its command line:

```
CyborgOS slot 1 of 4 - Control + 1-4, HELP
1>
```

## 3. Slots and the screen

Each slot is a whole 64K bank with its own text page (80 x 25). The slot in front is the one
on the screen and the one the keyboard types into; the others keep running, and their output
goes to their own page.

- **Control + 1 to 8** brings that slot to the front. A slot used for the first time opens with
  its command line.
- **FG** *slot* does the same from a command line.

A slot either shows its command line, or runs a program. When the program ends, the slot's
command line comes back (`[NAME.CYB ended]`).

## 4. Commands

Typed at a slot's prompt (`1>`), in capitals or not. Backspace / DEL rub out.

| Command | Does |
|---|---|
| `RUN` *name* [*slot*] | loads *name*.CYB from disc and runs it - in this slot, or in another one (which keeps running in the background while this command line stays) |
| `FG` *slot* | that slot to the front |
| `PS` | the slots: what each is doing (`*` = in front) |
| `KILL` *slot* | stops the program in that slot (its command line comes back) |
| `WAIT` | waits until no program runs; keys typed meanwhile wait too |
| `CLS` | clears this slot's page |
| `MEM` | 64K banks, slots, free 16K pages |
| `HELP` | the commands |
| `QUIT` | ends CyborgOS (it says how many programs ran) |

```
1> run crunch 2
CRUNCH.CYB runs in slot 2
1> run ticker 3
TICKER.CYB runs in slot 3
1> ps
 1 * command line
 2   CRUNCH.CYB
 3   TICKER.CYB
 4   -
1> fg 3
```

## 5. Programs

### What runs

A program is a CP/M program that talks to the console through the BDOS. NTC BASIC programs
built for the **cpm** platform are exactly that. In a slot a program has the whole bank from
#0100: about 62K.

The BDOS calls handled now:

| Function | Does |
|---|---|
| 0 | end (also `jp 0`, and a `ret` from the program) |
| 1 | a key, echoed (0 if none is waiting) |
| 2 | a character out |
| 6 | E = #FF: a key or 0; E = #FE: is one waiting; else E out |
| 9 | the string at DE, to `$` |
| 11 | is a key waiting |
| 12 | the version: 2.2 |
| 25 | the drive: A |
| others (files ...) | answer #FF (not yet) |

The console understands CR, LF, backspace and the VT52 codes NTC uses with `Option Terminal
VT52`: ESC E (clear), ESC H (home), ESC Y *row col* (move). So in a program: `Print`, `Inkey`,
`Input`, and with `Option Terminal VT52` also `Cls` and `Locate`. `End`, and
`Option PressAnyKeyOnEnd` (it waits for a key in its own slot), work as usual.

Not yet: files (the FileSystem class gives errors), and the Graphics class (it writes the
CPC's screen, which a program in a bank can't see).

### Making a .CYB

A `.CYB` file is a cpm build of the program with an AMSDOS header (AMSDOS reads a file without
a header as text, up to the first #1A byte, so a plain `.COM` can't be loaded whole).

- **The GUI:** platform **cpm**, tick **AMSDOS .BIN / .CYB**: assembling the program writes
  *NAME*.CYB beside the .COM (NAME is the project's name).
- **The command line:** `node test/cli.js prog.bas --platform=cpm --amsdos=NAME > NAME.ASM`, then
  `sjasmplus NAME.ASM` writes NAME.CYB.

Put the .CYB on the same disc as CYBORGOS.BIN (for example with a disc tool, or `cpmcp`).

```
' TICKER: counts until a key
Option Explicit
Dim i As Long, k As Integer
Print "Ticker - a key ends it"
Do
  i = i + 1
  If i Mod 500 = 0 Then Print "tick"; i
  k = Inkey
Loop Until k <> 0
Print "Ticker done, key"; k
```

### How programs share the CPU

The programs run in turn. A program runs until it calls the BDOS (printing, looking for a key)
or an interrupt stops it, then the next one gets the CPU. NTC lets interrupts in at its safe
points (every loop and jump in normal mode), so a program that never calls the BDOS (CRUNCH,
a long sum) still gives the CPU back. A program in **turbo** mode keeps interrupts off: it only
gives the CPU back at its next BDOS call.

Each BDOS call goes through the hypervisor (BASIC), so it takes a while: a program that calls
it in a tight loop (TICKER looks for a key every time round) runs slowly.

### A slot's bank

| Address | Holds |
|---|---|
| #0000 | `jp` the end (CP/M's warm boot) |
| #0005 | `jp` the BDOS; #0006 = #F600, the top of the program's memory |
| #0038 | `jp` the interrupt save |
| #0044-#0048 | the bank switch (`out (c), c`, `jp` its landing) |
| #005C, #0080 | CP/M's default FCB, the (empty) command tail |
| #0100-#F5FF | the program |
| #F600 | the BDOS and interrupt stubs |
| #F700-#FECF | the slot's text page (80 x 25) |
| #FFFE | the slot's saved SP |

## 6. Not yet

- Files for the programs (CP/M file calls), and `LOAD`, `SAVE`, `DISC`, `TAPE`, `CD`.
- The interrupt classes as the scheduler, with the front slot getting half of the shared time.
- Drivers (printer, serial, sound ...) that programs reach with far calls.
- Faster BDOS calls.

## 7. For developers

CyborgOS itself is `bas/cyborgos/Main.bas` and `Hyp.cls`, built for **cpcfw** (also with
`Option Library ROM`). It uses `Option Buffer &H8000` to keep its 2K file buffer out of the
program, and `Option Reserve &H4000, &H4000` for the window it reaches the banks through. The
test programs are in `bas/cyborgos/tasks/`. The regression tests run it in the harness with 4
slots (576K), 1 slot (128K) and as a Library: ROM build.

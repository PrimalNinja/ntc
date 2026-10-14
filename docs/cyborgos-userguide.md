# CyborgOS - user guide

CyborgOS runs several CP/M-style programs at once on an Amstrad CPC, each in its own 64K bank,
with a command line for each. It is an NTC BASIC program (the hypervisor) running with the
firmware; the programs are NTC BASIC programs built for the cpm platform. The design and what
is still to come are in [cyborgos.md](cyborgos.md).

This describes the first version (October 2026).

## 1. What you need

- A CPC 6128, or a CPC with a RAM expansion. CyborgOS uses half of the extra 64K banks for
  slots, at least 1 and at most 16; the rest is left for later (drivers, data, graphics):

  | Extra RAM | Slots |
  |---|---|
  | 64K (a 6128) | 1 |
  | 256K | 2 |
  | 512K | 4 |
  | 1MB | 8 |
| 2MB or more | 16 (CyborgOS sees at most 48 banks) |

- AMSDOS (a disc drive): programs are loaded from disc.
- `build/dsk/cyborgos.dsk` has CYBORGOS.BIN and three test programs (TICKER.CYB, CRUNCH.CYB, LINES.CYB),
  and CRUNCH again as a plain CRUNCH.COM with its FILES.DIR entry (long name BIGCRUNCH).

## 2. Starting

```
RUN"CYBORGOS
```

The screen goes to mode 2 (80 x 25) and slot 1 shows its command line:

```
CyborgOS slot 1 of 4 - Control + 1-4, Control + ESC: TOP, HELP

1>
```

## 3. Slots and the screen

Each slot is a whole 64K bank with its own text page (80 x 25). The slot in front is the one
on the screen and the one the keyboard types into; the others keep running, and their output
goes to their own page.

- **Control + 1 to 8** brings that slot to the front. With more than 8 slots, the same number
  pressed twice quickly (within 0.3 s, Control held) is slots 9 to 16 (Control + 3, 3: slot
  11); a single press then counts after 0.3 s, at once when Control is let go or another
  number is pressed. With 8 slots or fewer a press counts at once. A slot used for the first time opens with
  its command line. Hold Control and press the numbers one after another to step through the
  slots. The keys are looked at 50 times a second whatever runs; keys typed while Control is
  held don't go to the programs.
- **Control + ESC** shows the TOP screen: each slot's state (command line, running), its
  program, and in the last whole second its turns, BDOS calls that reached the hypervisor and
  characters out. It is drawn once (straight into screen memory, at once) and stays (other keys
  do nothing) until Control + ESC again or Control + a slot number. The `TOP` command prints the
  same table into the slot's console instead.
- **FG** *slot* does the same from a command line.

A slot either shows its command line, or runs a program. When the program ends, the slot's
command line comes back (`[NAME.CYB ended]`).

## 4. Commands

Typed at a slot's prompt (`1>`), in capitals or not. Backspace / DEL rub out.

| Command | Does |
|---|---|
| `RUN` *name* [*slot*] | loads the program from disc and runs it - in this slot, or in another one (which keeps running in the background while this command line stays). *name*: *name*.CYB, else *name*.COM (only with an entry: [6](#6-plain-com-files-filesdir-and-namehdr)), else the .COM whose FILES.DIR entry has the long name *name*; `RUN NAME.COM` / `RUN NAME.CYB` take that one |
| `ADD` *name*.COM [*long name*] | puts an entry for a plain .COM into FILES.DIR (replacing one for that file), so RUN takes it; its length is read from the disc |
| `FG` *slot* | that slot to the front |
| `PS` | the slots: what each is doing (`*` = in front) |
| `TOP` | the TOP table (each slot's state, program, and in the last whole second its turns, BDOS calls and characters) printed once into this slot's console, like PS |
| `KILL` *slot* | stops the program in that slot (its command line comes back) |
| `RESET` [*slot*] | that slot (or this one) as before its command line was first opened: its program, if any, stopped and nothing kept; this slot opens again at once, as new |
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
#0100: about 61K. All its registers (IX, IY and the alternate set too) are the same after a
BDOS call or an interrupt as before.

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

A `.CYB` file is a cpm build of the program with an AMSDOS header (the header gives its length;
a plain `.COM` needs an entry for that - [6](#6-plain-com-files-filesdir-and-namehdr)).

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

The programs run in turn. A program runs until it calls the BDOS (looking for a key, the
version ...) or an interrupt stops it, then the next one gets the CPU. NTC lets interrupts in
at its safe points (every loop and jump in normal mode), so a program that never calls the BDOS
(CRUNCH, a long sum) still gives the CPU back. A program in **turbo** mode keeps interrupts off:
it only gives the CPU back at its next BDOS call.

- **The slot in front gets half the turns**, however many run behind it; the others share the
  other half. With nothing behind it, it gets them all.
- **A turn is a time slice of 6 interrupts (1/50 s)**: the interrupts in between are handled
  for the program straight away (the firmware's handler, then back into the program) without a
  trip through the hypervisor's BASIC. A slice ends early at a BDOS call that needs the
  hypervisor, or when the system keys are due.
- **Keys don't leave the bank**: the hypervisor puts the slot's next key in its bank, and the
  BDOS stub there answers functions 1, 6 (#FF, #FE) and 11 from it. A program looking for a
  key costs no more than a call.
- **Characters out don't stop the program**: the BDOS stub collects them (128 at most) and
  hands them over when 128 wait, at another BDOS call or at the end of a slice (so text shows
  at most 1/50 s late). The hypervisor's console (Z80) writes them into the slot's page and,
  for the slot in front, straight into screen memory (mode 2; the firmware's text output is
  far slower). The page is a ring of 25 rows, so scrolling it copies nothing.

Measured on the real 6128 ROMs (realcpc): 200 lines of 62 characters scroll by at about 16 a
second.

### A slot's bank

| Address | Holds |
|---|---|
| #0000 | `jp` the end (CP/M's warm boot) |
| #0005 | `jp` the BDOS; #0006 = #F500, the top of the program's memory |
| #0038 | `jp` the interrupt save |
| #0044-#0048 | the bank switch (`out (c), c`, `jp` its landing) |
| #005C, #0080 | CP/M's default FCB, the (empty) command tail |
| #0100-#F4FF | the program (about 61K) |
| #F500 | the BDOS and interrupt stubs |
| #F600-#F680 | the characters out it collected, and their count |
| #F681 | the slot's next key (0: none), put there by the hypervisor |
| #F682-#F686 | its console: column, row, the page ring's top row, escape state and row |
| #F68F-#F6D5 | the slot's command line being typed (its length, then up to 70 characters) |
| #F6D8-#F6E4 | the name of the program it runs (its length, then up to 12 characters) |
| #F700-#FECF | the slot's text page (80 x 25) |
| #FFFE | the slot's saved SP |

## 6. Plain .COM files: FILES.DIR and NAME.HDR

A CP/M program copied to the disc as it is (a `.COM`, no AMSDOS header) runs too, once it has
an **entry**: AMSDOS can't say how long a file with no header is (it reads it as text and
reports each #1A byte as an end of file), so the entry says it - and it is also the say-so
that the program runs here: a `.COM` with no entry is not run (`NAME: not found`), so a
stray or broken one isn't started.

- **FILES.DIR** - one file of entries for the disc. `ADD NAME.COM` makes or adds to it (the
  length is read from the disc, to the end of the file's last 128 byte record: all AMSDOS
  knows); `ADD NAME.COM LONGNAME` gives it a long name too, and `RUN LONGNAME` runs it.
  The long name is one word for now (the command line splits at spaces).
- **NAME.HDR** - the entry for NAME.COM alone, beside it. RUN looks here first.
- `ADD` is not in the Library: ROM build of CyborgOS (no room below #4000 with it for the
  Memory class's tables); RUN reads the entries there too.

RUN then reads the .COM with `FileSystem.ForReadRaw`: every byte to its length, a #1A just a
byte (checked on the real ROMs: AMSDOS goes on after its "soft" end of file).

An entry is 64 bytes (both files: one after another; FILES.DIR as `ADD` saves it has an
AMSDOS header first, which AMSDOS takes off; one written without is read the same):

| Bytes | |
|---|---|
| 0 | 1 = a file (0 unused; 2 will be a virtual directory) |
| 1-11 | its name on the disc, CP/M style: 8 + 3 characters, capitals, spaces after |
| 12 | what it is: 1 = a CP/M .COM (RUN takes only these) |
| 13 | flags: bit 0 = it runs here |
| 14-15 | its length in bytes (#F400 at most: #0100-#F4FF) |
| 16-17, 18-19 | load and run address (#0100 for a .COM) |
| 20, 21 | the virtual directory it is in, a directory's own number (not used yet) |
| 22-23 | not used yet |
| 24-61 | its long name, up to 38 characters, 0 after |
| 62-63 | the sum of bytes 0-61 (a damaged entry is not used) |

The entries stand in until CyborgOS reads the disc's own directory (file sizes from the
record counts, random access); then plain `.COM` files need nothing - but the entries can
keep what a directory can't: long names, virtual directories, more about each program.
`src/test/ntcrun.py`'s `cyb_entry()` writes one on a PC (`gendsk.sh` uses it).

## 7. Not yet

- Files for the programs (CP/M file calls), and `LOAD`, `SAVE`, `DISC`, `TAPE`, `CD`.
- A plain `.COM` without an entry ([6](#6-plain-com-files-filesdir-and-namehdr)): that needs the
  disc's own directory read (record counts, AMSDOS's sector command #84), which comes with
  the file system work, and random access with it. Programs such as BBC BASIC also call the
  BIOS through the jump table at (#0001), which a slot's bank doesn't have yet.
- Virtual directories and long names with spaces (FILES.DIR has room for both).
- Drivers (printer, serial, sound ...) that programs reach with far calls.
- Faster BDOS calls.

## 8. For developers

CyborgOS itself is `bas/cyborgos/Main.bas`, `Hyp.cls` (the bank side, the switch) and
`Hot.cls` (the system keys, an interrupt class), built for **cpcfw** (also with `Option Library
ROM`). `Option Reserve &H4000, &H4000` keeps the window it reaches the banks through free: the
hypervisor (about 19K) is built round it, from #0040 and on from #8800, after the 2K file
buffer `Option Buffer &H8000` puts at #8000; the Memory class's tables follow it (`Option Memory
CPCExpansion 193`: up to 48 banks - all 64 of a 4MB expansion no longer fit there). The
test programs are in `bas/cyborgos/tasks/`. The regression tests run it in the harness with 4
slots (576K), 1 slot (128K) and as a Library: ROM build.

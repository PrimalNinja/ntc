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

- A disc system (AMSDOS, UniDOS, an IDE or SD interface ...): CyborgOS starts every background
  ROM (`Option RomEnable All`), and programs are loaded from disc.
- `build/dsk/cyborgos.dsk` has CYBORGOS.BIN and three test programs (TICKER.CYB, CRUNCH.CYB, LINES.CYB),
  CRUNCH again as a plain CRUNCH.COM, CYBADD.BIN (it writes FILES.DIR), and a FILES.DIR listing
  CYBADD.BIN and CRUNCH.COM (long name BIGCRUNCH).

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
  do nothing) until Control + ESC again or Control + a slot number. Under the slots: the memory
  CyborgOS sees (in KB) and its map, a character a 16K page (`B` a slot's bank, `-` free; as
  `Memory.Map`). The `TOP` command prints the same into the slot's console instead.
- **FG** *slot* does the same from a command line.

A slot either shows its command line, or runs a program. When the program ends, the slot's
command line comes back (`[NAME.CYB ended]`).

## 4. Commands

Typed at a slot's prompt (`1>`), in capitals or not. Backspace / DEL rub out.

| Command | Does |
|---|---|
| *name* [*args*] | not a command: runs the program *name* from this slot's drive (if it isn't there: from A, where the disc commands are), in this slot; the rest of the line is its command tail (#0080, as CP/M has it: `System.CommandLine` in NTC). Not found anywhere: `? NAME (HELP)` |
| `RUN` *name* [*args*] | the same, but always the program on the disc - `RUN CLS` runs CLS.CYB, not the CLS command |
| `RUN` *name* *slot* | runs it in another slot (which keeps running in the background while this command line stays) |
| `DIR` | lists FILES.DIR: each program's disc name, length in bytes and long name |
| `CD` [*drive*] | this slot's drive: the disc system's `|`*drive* command is run (AMSDOS's A, B; UniDOS's and the M4's own letters), and the drive is kept only when it is there and has a FILES.DIR. Each slot has its own (A to start with), as in CP/M; RUN and DIR use it. `CD` alone: the slot's drive |
| *drive*`:` | the same as `CD` *drive*: `B:` alone is `CD B`, as in CP/M; `CD B:` works too |
| `FG` *slot* | that slot to the front |
| `PS` | the slots: what each is doing (`*` = in front) |
| `TOP` | the TOP table (each slot's state, program, and in the last whole second its turns, BDOS calls and characters), then `Total memory: n KB   Free memory: n KB`, printed once into this slot's console, like PS |
| `KILL` *slot* | stops the program in that slot (its command line comes back) |
| `RESET` [*slot*] | that slot (or this one) as before its command line was first opened: its program, if any, stopped and nothing kept; this slot opens again at once, as new |
| `WAIT` | waits until no program runs; keys typed meanwhile wait too |
| `CLS` | clears this slot's page |
| `MEM` | main RAM as a table (each address range and what is there: CyborgOS, the window, free RAM, the firmware and ROMs, the screen); the map of the banks, a character a 16K page (B a slot's, - free), 32 pages (8 banks) a group, two groups a line; then the totals as TOP has them. Free memory is the 16K pages nothing has (main RAM's own page is the disc buffers') |
| `HELP` | the commands, then a line on each |
| `COPY`, `ERA`, `TYPE`, `PREP`, `RENAME` | disc commands: programs on the disc ([4a](#4a-disc-commands-copy-era-type-prep-rename)), not built in |
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

A program's name is found as *name*.CYB, else *name*.COM (only with an entry:
[6](#6-plain-com-files-filesdir-and-namehdr)), else the .COM whose FILES.DIR entry has the long
name *name*; `NAME.COM` / `NAME.CYB` take that one.

## 4a. Disc commands: COPY, ERA, TYPE, PREP, RENAME

Programs on the CyborgOS disc (`.CYB`, NTC BASIC built for cpm: `bas/cyborgos/cmds`), run by
their names like any program. They only touch files that are in the volume's FILES.DIR (the
files added there); a volume is `A:`, `B:` ..., or none for the slot's drive. A file is named
by its disc name (`README.TXT`; `NAME` alone also finds `NAME.COM`) or its long name.

| Command | Does |
|---|---|
| `PREP` *v* | makes an empty FILES.DIR on volume *v* (`B` or `B:`) - one 128 byte record of unused entries, as a disc ROM may make no file for an empty one - then looks for it again. A volume that has one already is left alone. CD needs it, and COPY's target |
| `COPY` [*v1*:]*name* *v2*[:*newname*] | copies the file to volume *v2* (which needs a FILES.DIR: PREP), as *newname* or the same name, and puts its entry (length, long name, flags) in *v2*'s FILES.DIR |
| `ERA` [*v*:]*name* | deletes the file and its entry |
| `TYPE` [*v*:]*name* | shows the text file, to its end or first ^Z |
| `RENAME` [*v*:]*name* *newname* | renames the file on the disc and in its entry (its long name and the rest stay); *newname* is a disc name (NAME.EXT) on the same volume, not one taken already |

```
1> prep b
B:FILES.DIR made (no entries)
1> copy readme.txt b:
A:README.TXT to B:README.TXT: 20 bytes
1> type b:readme.txt
```

COPY copies what CP/M sees: whole 128 byte records, without an AMSDOS header. A plain file
or `.COM` comes out the same (its exact length is in the entry); a CPC `.BIN` loses its header
and a `.CYB` copy no longer runs as a `.CYB`. The files go through the hypervisor's BDOS calls
(below), one file read and one written at a time.

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
| 13, 32 | reset the discs, the user number: nothing to do (0) |
| 14 | select a disc: the slot's drive (as CD) |
| 15, 16 | open (to read), close |
| 19 | delete (the disc ROM's `|ERA`) |
| 20, 33 | read the next record / record *n* (the file read again from its start when *n* is behind) |
| 21, 34 | write the next record (34 writes in order too) |
| 22 | make a file (to write) |
| 25 | the slot's drive |
| 26 | the DMA address |
| others | answer #FF (not yet) |

Files go through the firmware's cassette calls (the disc ROM's: AMSDOS, UniDOS ...): one file
being read and one being written at a time, over all the slots (another gets #FF until it is
closed); a slot's open files are closed when its program ends, is killed or reset. CP/M lets a
program open a file to read and never close it (a new open replaces it): until then it holds
the one file being read, and RUN, DIR and CD (which read files too) say "not found". A file is
read as CP/M sees it: 128 byte records, the last one padded with ^Z, an AMSDOS header left out.

The console understands CR, LF, backspace and the VT52 codes NTC uses with `Option Terminal
VT52`: ESC E (clear), ESC H (home), ESC Y *row col* (move). So in a program: `Print`, `Inkey`,
`Input`, and with `Option Terminal VT52` also `Cls` and `Locate`. `End`, and
`Option PressAnyKeyOnEnd` (it waits for a key in its own slot), work as usual.

Not yet: the Graphics class (it writes the CPC's screen, which a program in a bank can't see),
directory searches (BDOS 17, 18), rename (23) and file sizes (35).

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

- **FILES.DIR** - one file of entries for the disc. **CYBADD** writes it: a normal CPC program
  (`RUN"CYBADD` from BASIC - quit CyborgOS first). It asks for the drive, then each file and
  its long name (one word: the command line splits at spaces), reads the file's length from
  the disc (to the end of its last 128 byte record: all AMSDOS knows) and saves FILES.DIR again
  (an entry for a file already in it is replaced). `RUN LONGNAME` then runs it. FILES.DIR lists
  CYBADD.BIN itself (as "other": shown by DIR, not run by CyborgOS).
- **NAME.HDR** - the entry for NAME.COM alone, beside it. RUN looks here first.
- **The long name** is a second name for the file, not a description: one word (the command
  line splits at spaces), up to 38 characters. `RUN LONGNAME` runs a .COM by it, and COPY, ERA,
  TYPE and RENAME take it as well as the disc name; DIR shows it. (A description - with spaces -
  would need its own field; the entry has room: bytes 22-23 and a directory of its own later.)
- The CyborgOS disc's FILES.DIR lists every file on it: the CPC programs (CYBORGOS.BIN,
  CYBADD.BIN) as "other", the .CYB programs with their names as long names, and CRUNCH.COM
  (long name BIGCRUNCH).
- `DIR` lists FILES.DIR (until the disc's own directory is read, it is the directory).
- `DIR` and `CD` are not in the Library: ROM build of CyborgOS (no room below #4000 with them
  for the Memory class's tables); RUN reads the entries there too.

RUN then reads the .COM with `FileSystem.ForReadRaw`: every byte to its length, a #1A just a
byte (checked on the real ROMs: AMSDOS goes on after its "soft" end of file).

An entry is 64 bytes (both files: one after another; FILES.DIR as CYBADD saves it has an
AMSDOS header first, which AMSDOS takes off; one written without is read the same):

| Bytes | |
|---|---|
| 0 | 1 = a file (0 unused; 2 will be a virtual directory) |
| 1-11 | its name on the disc, CP/M style: 8 + 3 characters, capitals, spaces after |
| 12 | what it is: 1 = a CP/M .COM (RUN takes only these), 0 = other (a CPC .BIN ...) |
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

- The rest of the CP/M file calls (searches, rename, sizes), and `LOAD`, `SAVE`, `DISC`, `TAPE`.
- A plain `.COM` without an entry ([6](#6-plain-com-files-filesdir-and-namehdr)): that needs the
  disc's own directory read (record counts, AMSDOS's sector command #84), which comes with
  the file system work, and random access with it. Programs such as BBC BASIC also call the
  BIOS through the jump table at (#0001), which a slot's bank doesn't have yet.
- Virtual directories and long names with spaces (FILES.DIR has room for both).
- Drivers (printer, serial, sound ...) that programs reach with far calls.
- Faster BDOS calls.

## 8. For developers

CyborgOS itself is `bas/cyborgos/Main.bas`, `Hyp.cls` (the bank side, the switch), `Hot.cls`
(the system keys, an interrupt class) and `Ent.cls` (FILES.DIR entries, in Z80 - CYBADD,
`bas/cyborgos/tools/CYBADD.bas`, uses it too), built for **cpcfw** (also with `Option Library
ROM`). `Option Reserve &H4000, &H4000` keeps the window it reaches the banks through free: the
hypervisor is built round it, from #0040 and on from #8000; the Memory class's tables follow it
(`Option Memory CPCExpansion 193`: up to 48 banks - all 64 of a 4MB expansion no longer fit
there; the Library: ROM build takes 33 pages, 8 banks, below the ROM's RAM at #8800). Its file
work (RUN's loading, DIR, CD, the programs' BDOS file calls) is `Hyp.FileCall`, Z80 on the
firmware's cassette calls, with main RAM's #4000-#4FFF as the disc ROM's two 2K buffers. The
test programs are in `bas/cyborgos/tasks/`, the disc commands in `bas/cyborgos/cmds/` (each
built for cpm with `CybDir.cls`, which reads and writes FILES.DIR). The regression tests run it in the harness with 4
slots (576K), 1 slot (128K) and as a Library: ROM build.

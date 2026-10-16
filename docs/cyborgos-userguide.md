# CyborgOS - user guide

CyborgOS runs several CP/M programs at once on an Amstrad CPC, each in its own 64K bank, with
a command line for each. It is an NTC BASIC program (the hypervisor) running with the
firmware; the programs are CP/M programs - NTC BASIC programs built for the cpm platform, or
others that keep to the BDOS and BIOS. What the project is and its two versions:
[cyborgos-readme.md](cyborgos-readme.md); the design: [cyborgos.md](cyborgos.md); what is
next: [cyborgos-todo.md](cyborgos-todo.md).

This describes the 320K version (October 2026), the real hypervisor. The 128K version (a 6128
and up: one program with about 61K, for console programs that may work the hardware) is frozen
in `bas/cyborgos128kb/`, with its own user guide.

## 1. What you need

- A CPC with 320K or more: a 256K expansion or bigger (a 6128 alone gets "CyborgOS needs 320K").
  The first expansion bank's first 16K page (C4) is the hypervisor's own (the disc buffers; the
  RAM disc driver takes the next free page when RAMDISC is first used), and main RAM's own
  #4000-#7FFF is kept for a second screen. Half of
  the extra 64K banks are slots, at most 20; the rest is left for later (drivers, data,
  graphics):

  | Extra RAM | Slots |
  |---|---|
  | 256K | 2 |
  | 512K | 4 |
  | 1MB | 8 |
  | 2MB | 16 |
  | 2.5MB or more | 20, the most (Control + 1-9, 0, then twice for 11-20). The Library: ROM build: 4 at most |

  A program built for CyborgOS runs on the 128K version too: the slots are the same (a whole
  64K bank from #0100, the same BDOS); there it gets one slot on a 6128.

- A disc system (AMSDOS, UniDOS, an IDE or SD interface ...): CyborgOS starts every background
  ROM (`Option RomEnable All`), and programs are loaded from disc.
- **UniDOS** (OffseT's DOS) is needed for the disc commands: CyborgOS reads the real
  directories - UniDOS's listing for its drives and folders, a RAM disc's own for Z and RAMDISC's.
  It has no file list of its own (the FILES.DIR of earlier versions is gone). On AMSDOS alone it
  runs programs, but DIR, COPY's patterns and ERA's can't see a floppy's files (FLOPPY A can).
- The 320K version comes on three discs, `build/dsk/cos-disk1.dsk` - `cos-disk3.dsk`. Disc 1:
  CYBORGOS.BAS (the loader: RUN"CYBORGOS), WINAPE.BAS (the same for WinAPE: KEYREP 10), COSLOAD.BIN, CYBORGOS.BIN (this version), CYBORGOS.Z
  (the commands for the system drive Z), MON and its SYSTEM.MAP, three test programs (TICKER.CYB,
  CRUNCH.CYB, LINES.CYB; CRUNCH also as a plain CRUNCH.COM), the help texts (*.HLP) and
  INSTALL.BAS. Disc 2: the commands (.CYB: HELP, PS, TOP, KILL, RESET, FG, WAIT, MEM, MODE, DIR,
  CD, MKDIR, RMDIR, DRIVE, COPY, ERA, TYPE, RENAME, RAMDISC) and FLOPPY. Disc 3: Z ready-made
  (CYBORGOS.Z1 ...).
- INSTALL.BAS (on disc 1 only; `RUN"INSTALL` from BASIC) puts all three in a folder CYBORGOS on
  your mass storage. Map the floppy drive as drive B and the mass storage (IDE, SD ...) as drive
  A first (UniDOS: `|DRIVE,"A","IDE:"`, `|DRIVE,"B","DFA:"`) - the installer says so at the top.
  It makes `A:CYBORGOS/`, `CYBORGOS/C/` (the commands Z is made from) and `CYBORGOS/HELP/` (the
  help texts) with `|SAVE`, copies disc 1, then asks for disc 2 and disc 3 in drive B (a key when
  each is in), each file with `|COPY` (over one already there), with a bar and how far it has got
  (%). At the end: 1 run it on a real CPC, 2 run it on WinAPE (`KEYREP 10`: keys repeat 10 times
  slower), 3 exit. 1 and 2 make A's path the CYBORGOS folder (`|DRIVE,"A","CYBORGOS"` - UniDOS
  keeps it), then start it as CYBORGOS.BAS does. It runs on BASIC 1.0 too: RSXs get their
  strings as `@p1$`, never as literals; SPEED KEY 100,100 while it runs (WinAPE at full speed).
  `build/dsk/cyborgos128k.dsk` is the 128K version's (a 6128 and up); it keeps CYBADD.BIN, PREP
  and FILES.DIR.

Typed at a slot's prompt (`1>`), in capitals or not. Backspace / DEL rub out. Three are built in
(RUN, CLS, QUIT); the rest are programs (.CYB) on the system drive Z, run like any program -
they need nothing of the hypervisor's RAM, only a BDOS call (131) for what the hypervisor knows.

| Command | Does |
|---|---|
| *name* [*args*] | runs the program *name* - from Z, else this slot's drive, else the boot drive - in this slot; the rest of the line is its command tail (#0080, as CP/M has it: `System.CommandLine` in NTC). Not found anywhere: `? NAME (HELP)` |
| `RUN` [*slot*] *name* [*args*] | the same, also for a name that is a built-in command - `RUN CLS` runs CLS.CYB, not the CLS command. With a slot first: runs it there (it keeps running in the background while this command line stays) - `RUN 2 CRUNCH 3` |
| `DIR` [*v*:][*pattern*] [`FULL`] | the drive's files (UniDOS's listing; a RAM disc's own directory), across the screen - 13 columns each, as many as the console's width takes (BDOS 49), a name never split - with nothing else. A pattern (`*.CYB`, `T?*`) picks them; `B` alone is drive B. `FULL`: a line each - name, length in bytes (a RAM disc's from its records), UniDOS's date - and how many |
| `CD` [*drive*] | this slot's drive (A-P, a RAM disc too): kept only when the drive is there. Each slot has its own (the boot drive to start with), as in CP/M; programs, RUN and DIR use it. `CD` alone: the slot's drive |
| *drive*`:` | the same as `CD` *drive*: `B:` alone is `CD B`, as in CP/M; `CD B:` works too |
| `FG` *slot* | that slot to the front |
| `PS` | the slots: what each is doing (`*` = in front) |
| `TOP` | the TOP table (each slot's state, program, and in the last whole second its turns, BDOS calls and characters), then `Total memory: n KB   Free memory: n KB`, printed once into this slot's console, like PS |
| `KILL` *slot* | stops the program in that slot (its command line comes back) |
| `RESET` [*slot*] | that slot (or this one) as before its command line was first opened: its program, if any, stopped and nothing kept; this slot opens again at once, as new |
| `WAIT` | waits until no program runs; keys typed meanwhile wait too |
| `CLS` | clears this slot's page (built in) |
| `MODE` [*m*] | this slot's screen mode: `2`, `S`, `W`, `UW`, `P` (its console cleared); alone, the modes and this slot's (from BDOS 49) |
| `MEM` | main RAM as a table (each address range and what is there: CyborgOS, the window, free RAM, the firmware and ROMs, the screen); the map of the banks, a character a 16K page (B a slot's, U the hypervisor's: disc buffers, RAM discs - Z too -, - free), 32 pages (8 banks) a group, two groups a line; then the totals as TOP has them. Not in the Library: ROM build |
| `HELP` [*name*] | the commands (HELP.HLP); `HELP DIR`, `HELP CD` ...: that one's text, NAME.HLP (a name with a `.` as it is: `HELP MY.TXT`). Looked for on this slot's drive, then in the HELP folder of A or B (`CYBORGOS/HELP`, where the installer puts them - UniDOS), then on A and Z. The .HLP files are plain text (CR LF lines, ^Z at the end) - any can be edited, and a program can have one of its own |
| `FLOPPY` *from* [*to*] | CPC floppy discs read and written track by track, as COPY (*d*: `A`, `DFA`, `FDA`; `B`, `DFB`, `FDB`): `FLOPPY A` its files listed; `FLOPPY A` *folder* / *NAME*`.DSK` its files copied there, or the disc as an image; `FLOPPY` *folder* / *NAME*`.DSK` `A` the other way, onto the disc ([4a3](#4a3-floppy-floppy-discs-read-and-written-track-by-track)) |
| `COPY`, `ERA`, `TYPE`, `RENAME` | disc commands ([4a](#4a-disc-commands-copy-era-type-rename-and-help)) |
| `RAMDISC` | RAM discs ([4b](#4b-ram-discs-ramdisc)) |
| `QUIT` | ends CyborgOS (it says how many programs ran - the commands count too) (built in) |

```
1> run 2 crunch
CRUNCH.CYB runs in slot 2
1> run 3 ticker
TICKER.CYB runs in slot 3
1> ps
 1 * PS.CYB
 2   CRUNCH.CYB
 3   TICKER.CYB
 4   -
1> fg 3
```

A program's name is found as *name*.CYB, else *name*.COM (a plain CP/M program, read to its
real end: [6](#6-plain-com-files)); `NAME.COM` / `NAME.CYB` take that one.

## 4a. Disc commands: COPY, ERA, TYPE, RENAME (and HELP)

Programs on the CyborgOS disc (`.CYB`, NTC BASIC built for cpm: `bas/cyborgos320kb/cmds`), run by
their names like any program. They take any file the drive has - UniDOS's listing of its folder,
a RAM disc's own directory (Z, RAMDISC's) - a volume is `A:`, `B:` ..., or none for the slot's
drive; `NAME` alone also finds `NAME.COM`.

| Command | Does |
|---|---|
| `COPY` [*v1*:]*name* *v2*[:*newname*] | copies the file to volume *v2*, as *newname* or the same name |
| `COPY` [*v1*:]*pattern* *v2* | each file that fits the pattern (`*` any characters, `?` any one: `*.CYB`, `T*`, `????.COM`, `*.*`) copied to *v2* with its own name; it stops when the disc is full, says how many were copied |
| `ERA` [*v*:]*name*, `ERA` [*v*:]*pattern* | deletes the file; a pattern (`*.BAK`) each that fits. A folder: RMDIR |
| `TYPE` [*v*:]*name* | shows the text file, to its end or first ^Z |
| `RENAME` [*v*:]*name* *newname* | renames the file; *newname* is a disc name (NAME.EXT) on the same volume, not one taken already |

```
1> copy readme.txt b:
A:README.TXT to B:README.TXT: 20 bytes
1> type b:readme.txt
```

COPY copies what CP/M sees, 8K at a time: from UniDOS to the file's exact length (its listing
gives it), from a RAM disc to its last record. A copy is written in whole 128 byte records (CP/M's)
and AMSDOS / UniDOS put a ^Z after the last, so a 20 byte text file is 129 bytes on the disc; a
CPC `.BIN` loses its header (CP/M reads past it). The files go through the hypervisor's BDOS
calls (below), one file read and one written at a time on a disc (any number on a RAM disc).

## 4a2. UniDOS: devices and folders as drives

With UniDOS (OffseT's DOS: X-Mass, Albireo, M4, Nova ... its devices `IDE:`, `SD:`, `UMS:`,
`M4:`, `DFA:` ...) a drive letter can be a **path**: a device and its folders. CyborgOS finds
UniDOS by its Ctrl J BIOS command (KL FIND COMMAND) - with AMSDOS none of this is there and
nothing changes. A path is for every slot (it is the letter's); 31 characters at most.

| Command | What it does |
|---|---|
| `CD IDE:`, `CD IDE`, `IDE:` alone, `CD SD:GAMES/ACTION` | this slot's drive gets that path. With `CD` the `:` after a device's name doesn't matter (`CD IDE` is `CD IDE:`; a folder named as a device: `CD SD/`); any word ending in `:` typed alone is `CD` it (`B:`, `IDE:`, `DFB:`). On `A` or `B` (UniDOS's own two logical drives - the boot drive is one of them, so it is never moved) the first letter from `C` with no path and no RAM disc gets it instead, and becomes this slot's drive |
| `CD GAMES` | a folder in this drive's (from `A`/`B`: as above, the path `A:GAMES/`) |
| `CD ..` | the folder this drive's is in |
| `CD C: IDE:WORK` | drive `C`'s path set, `C` this slot's drive |
| `CD C: -` | drive `C`'s path dropped |
| (a RAM disc) | a RAM disc's letter never has a path: RAMDISC drops one it had, and `CD IDE:` from a RAM disc takes another letter |
| `CD` | this slot's drive and its path, every drive with a path, the devices UniDOS has |
| `CD B` | as before (UniDOS lists the folder) |
| `CD DFA:`, `CD DFB:` | a floppy as a path: UniDOS can't examine it, so it is taken as it is (`FLOPPY A` lists its files) |
| `MKDIR WORK`, `MKDIR IDE:GAMES/NEW` | a folder made, in this drive's folder or anywhere |
| `RMDIR WORK`, `RMDIR IDE:GAMES/OLD` | an empty folder removed (UniDOS deletes a folder with all it holds, so RMDIR looks first and refuses one that isn't empty) |
| `FLOPPY A GAMES` | a floppy's files copied into a folder ([4a3](#4a3-floppy-floppy-discs-read-and-written-track-by-track)) |
| `DRIVE` | the drive letters in use (A, B; a letter's path; RAM discs) and UniDOS's devices by their own names (IDE, SD, UMS, M4, DFA, DFB, TAPE, ZERO ...): what each is, its free space, or "not there" |
| *name* (a plain .COM) | where no NAME.CYB is, NAME.COM is opened instead, and UniDOS reads it to its real end (on a RAM disc too: its driver does the same). `RUN NAME.COM` too |
| `DIR`, `DIR IDE:`, `DIR SD:GAMES/*.BAS`, `DIR GAMES/` | the folder as UniDOS lists it: files, folders (`NAME/`); hidden ones only with `FULL`. `FULL`: sizes (any size), dates |
| `COPY`, `ERA`, `TYPE`, `RENAME` | take any file in the drive's folder |

```
1> cd ide:games
drive C: --> IDE:GAMES/
1> dir
ACTION/      LIST.TXT
1> cd
drive C: --> IDE:GAMES/
  C: --> IDE:GAMES/
Devices: IDE: SD: SD2: UMS: DFA: DFB: TAPE: ZERO:
```

`C: --> IDE:GAMES/`: drive C (this slot's, here) goes to IDE:GAMES/ - anything on C is there.

CP/M programs see the folder too: a file call on drive C goes to `IDE:GAMES/NAME.EXT`, and a
directory search (BDOS 17, 18) lists the folder itself (its files: 112 at most) - a drive UniDOS
can't examine (an AMSDOS floppy) lists nothing. The programs CyborgOS
runs come from the slot's drive's path too. It all runs in the hypervisor's own page: main RAM
is not touched.

## 4a3. FLOPPY: floppy discs read and written track by track

UniDOS turns off AMSDOS's sector calls, so a floppy (a real drive, a Gotek) that UniDOS can't read
well is read by FLOPPY itself: it drives the CPC's disc controller (the uPD765, ports #FB7E /
#FB7F, the motor #FA7E) with interrupts off, a track at a time. It works the same with AMSDOS. The
format is found from a sector's number: data (C1-C9), system (41-49, 2 tracks kept for the
system), IBM (01-08, 1 track) - 40 tracks, one side, 512 byte sectors, 1K blocks, 64 directory
entries. FLOPPY is a program on the disc (no main RAM, no hypervisor code) - on the boot drive,
not copied to Z (it would take another 16K page of Z for a command seldom run).

| Command | Does |
|---|---|
| `FLOPPY A` (`DFA`, `FDA`; `B`, `DFB`, `FDB`; a `:` after it or not) | the disc's files: name, size (its records x 128), the user area when not 0; how many, the K used, the format |
| `FLOPPY A GAMES` | each file copied into the folder `GAMES` in this drive's folder - made if it isn't there (UniDOS) |
| `FLOPPY A IDE:GAMES/X` | the same, a folder anywhere (31 characters at most) |
| `FLOPPY A C:` | into drive `C` as it is (a RAM disc ...; no UniDOS needed) |
| `FLOPPY GAMES A`, `FLOPPY IDE:GAMES/X A`, `FLOPPY C: A` | the other way: each file in the folder (or drive) onto the disc, added to what it has (one of the same name replaced; the disc formatted already, its format as above) - an AMSDOS header with it (the disc ROM's copy: BDOS 30 #C7), the last record padded with ^Z; its directory written after each file. It stops at the first that won't fit |
| `FLOPPY GAME.DSK A`, `FLOPPY IDE:IMGS/GAME.DSK A` | the image onto the disc: each track formatted as the image has it (its sectors' IDs and sizes, its gap and filler), then its sectors written (each tried 3 times; ones that couldn't be are counted). One side, 42 tracks at most; a track the image hasn't got is left as it is. A write-protected disc says so |
| `FLOPPY A GAME.DSK`, `FLOPPY A IDE:IMGS/GAME.DSK`, `FLOPPY A C:GAME.DSK` | the whole disc as a .DSK image instead of its files - in this drive's folder, a folder (made if need be), a drive. Extended DSK: each track's sectors as they pass the head (read ID round the track first, so any sector numbers and sizes - 4608 bytes a track at most), tracks 0-39 and 40, 41 when formatted, side 0. A sector that can't be read (3 tries) is kept as it came, its ST1 / ST2 in the image |

```
1> floppy a
BIG.DAT      20864
READ.TXT     128
GAME.BIN     1152
3 files, 22K on A (data format)
1> floppy dfa ide:games
IDE:GAMES/ made
BIG.DAT to IDE:GAMES/BIG.DAT: 20864 bytes
...
3 of 3 files copied
```

A file is copied as CP/M sees it, record by record, with its AMSDOS header if it has one, so the
copy loads as the original did (AMSDOS adds a ^Z after the last record of a file written this
way). A name in two user areas is copied once. Each sector is tried 4 times (the head back to
track 0 between); a sector that still can't be read stops it, saying which. Nothing else should
use the floppy drives while it runs (another slot's file on A or B, AMSDOS's motor timer). Not
tried on real hardware yet.

## 4b. RAM discs: RAMDISC

`RAMDISC` (a program on the disc) makes drives out of free memory, with what the disc ROM
can't give CP/M programs: real random access (records read and written in place, a file
opened and written to), any number of files open in any number of slots, true sizes (BDOS 35)
and searches (17, 18) of the RAM disc's own directory.

| Command | Does |
|---|---|
| `RAMDISC` *v* *size* | drive *v* (A-P) a RAM disc of *size*: `64K`, `256KB`, `1MB`, `512` (KB) ... in 16K steps, 4MB in all (CD, DIR, COPY, ERA, TYPE, RENAME read its own directory) |
| `RAMDISC` *v* `0` (or `OFF`) | dropped: its files gone, its memory free again |
| `RAMDISC` | the RAM discs: size, files, free |

```
1> ramdisc j 256kb
J: RAM disc, 256K
1> copy readme.txt j:
A:README.TXT to J:README.TXT: 20 bytes
1> cd j
drive J
1> dir
README.TXT
```

- **Its contents go when CyborgOS ends, but survive a reset.** A RAM disc stays in its pages
  through a reset (not a power-off); when CyborgOS starts again it finds the surviving discs (the
  driver page's signature and checksum) and reattaches them with no reloading, Z included. COPY
  what you want to keep to a real disc before a power-off.
- A RAM disc's letter takes over that drive while it is there (so pick one the disc system
  hasn't got: C to P).
- The memory comes from the free 16K pages (`MEM`: `U`), the same ones that slots don't use;
  `Not enough free memory` says how much there was. The first RAMDISC also takes one page for
  the driver (its code and the directories of all the RAM discs: 256 files in all, 2K blocks).
- `DIR` on a RAM disc lists its own directory (each file's size in K), then the totals.
- Programs run from a RAM disc like from a disc (its name alone runs it when it is the slot's
  drive).

## 4c. MON

`MON` (on the boot disc; `apps/mon/`) is a monitor of the CPC and CyborgOS, in the spirit of
SCOUT on the Amiga - the first application written for CyborgOS 320K. It sets MODE F and puts
the slot's mode back when it ends. What it shows comes from a **map**: a text file, made and
changed by hand.

```
MON                 SYSTEM.MAP: this drive's, else A:'s, else Z:'s
MON MY.MAP 2        MY.MAP; {s} in it is 2 - a program of yours running in slot 2
```

```
+- Hex: main 0 #0000 ----------------------------------------------------------+---+
|1:Home 2:Slots 3:Memory 4:rOms 5:Drives 6:Z 7:Firmware 8:mAin RAM             |   |
+------------------------------------------------------------------------------+---+
|><< 1K< [1K >>]                                                               < ^ |
|0000  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................         # |
|0040  18 0C F0 BD ED 49 C3 49 00 ED 7B 42 00 C9 F3 ED  .....I.I..{B....         # |
...
+------------------------------------------------------------------------------+---+
| m:hex/main/0/#0000~1                                              line 1 / 68|
```

- **SYSTEM.MAP's pages:** Slots (state, MODE, program; each a link to the slot: its memory, its
  console's text, its store's pages), Memory (the totals, main RAM's free part, each 16K page and
  who has it - a link to its hex), Main RAM (what CyborgOS keeps where), Firmware (the jumpblock
  from #BB00), ROMs (0-15: type, version, first name; each a link to the ROM: its header and all
  its names - the RSX commands), Drives (the RAM discs; each a link to its files), Z (the system
  drive's files). Change the map as CyborgOS changes; MON needs no change.
- **The screen:** a window of `-`, `|` and `+`: the toolbar (the map's tools), 19 lines of the
  page, a status line (the chosen link's URL, the line number). The 4 columns on the right: `<` at
  the current line and a scroll bar (`^` and `v` at its ends, `#` the part shown).
- **Keys:** Tab or right the next link (marked `>` `<`), left the one before, up / down the line
  (the page scrolls), Shift + up / down a page, Control + up / down the top / the end, Enter or
  Copy follows the link, 1-8 or a tool's capital letter the toolbar, B or DEL back, R the page
  again (fresh: read again), Q or ESC quits.
- **The mouse** (an Amiga mouse on the mouse card: X and Y moves at #F994 / #F995, the buttons at
  #F991): the pointer - an 8 x 8 checkerboard XORed on a character cell - follows it and goes
  when it hasn't moved for a while; the left button follows a link, picks a toolbar entry, or on
  the scroll bar moves a line (`^` `v`) or a page. MON reads the mouse itself; CyborgOS draws the
  pointer (a slot can't reach the screen). Later CyborgOS will hand the mouse to one slot at a
  time.
- **How it is made:** MON makes only the page asked for - a list a window of 48 rows (`more >>`;
  B back), hex and text 1K - as 8BML (8-bit Markup Language v1), laid out by `Bml.cls` (a
  class that knows nothing of MON: a web browser will give it 8BML from a server). CyborgOS hands
  the data over raw (BDOS 131: op 15 a whole table, op 10 up to 2K of memory, into MON's 2K at
  #E000); MON lays it out as the map says. Bml's lines go to the slot's store (16 to a 2K block),
  so a page can be thousands of lines. MON is NTC BASIC but for one Z80 loop (the lines to the
  console).

**The map.** A line a directive; words split by spaces; `"text"` in quotes (80 characters at
most; `\"` a quote, `\\` a `\`); `;` starts a comment line. 4K at most (comments and the spaces
before a line not counted). Its pages are nodes:

```
title "MON - CyborgOS monitor"       (before the first node: the home page's lines - title,
text "..."                            text, sub, link - and the toolbar)
tool slots "Slots"                   a tool: a node (dir/Z: with its arguments), its name (its
                                     capital letter its key; 8)
cat "CyborgOS"                       the home page's heading for the nodes after it
node slots "Slots - what each one runs"     a node with no parameters: listed on the home page
src os 0
count b 0
rec 16 16 base 1
f "Slot" #
f "State" b 0 enum "-,command line,running"
f "Program" sl 4 3
go slot {#}
view list
node slot n "A slot"                 a parameter: reached by a link (m:slot/2)
title "Slot {1}"
link hex slot {1} #0100 "Its program, from #0100"
```

In a node, in order (each line runs as it comes; `title` first wherever it is; a `view` uses the
layout lines before it - rec, count, f, go ... - and clears them, so a node can show several):

| Directive | |
|---|---|
| `title "text"` | the page's title (else the node's description) |
| `text`, `sub`, `line` `"text"`; `gap` | a paragraph, a sub heading, a line as it is; an empty line |
| `link node [args] "text"` | a link to a page |
| `src os k` | a CyborgOS table (op 15): 0 the slots, 1 the memory, 2 the ROMs, 3 the RAM discs |
| `src page p addr [len]` | a 16K page (#0000-#3FFF in it) |
| `src rom r addr [len]` | an upper ROM (#C000-#FFFF) |
| `src main 0 addr [len]` | main RAM |
| `src slot s addr [len]` | a slot's memory (one in use) |
| `src dir d` | drive d's files (BDOS 17, 18 - UniDOS's listing, a RAM disc's directory: 16 bytes each, the name at 1, its records at 15) |
| `deref w off [len]` | the source moved to the word at `off` in it (a pointer: a ROM's name table) |
| `rec size [first] [base b]` | records: their size, where the first is, the number the first gets |
| `count b off` / `count w off` / `count n` | how many: a byte or a word in the source, or n (else as many as fit) |
| `walk w off [max n]` | a linked list: each record's next at `off` (0, an address seen again, or not there: the end) |
| `skip b off v` / `skip w off v` | records with v there left out |
| `dup n` | records whose first n bytes are the first record's left out (ROMs not there) |
| `f "heading" type off ...` | a column (8 at most), see below |
| `go node [args]` | each row a link |
| `view list` / `data` / `hex` / `text` / `words` | the source shown: rows; one record, a line each column; hex; text (ASCII); names. `dis` (instructions): later - hex for now |

Column types: `b` `w` numbers, `hb` `hw` hex, `c` a letter, `s off len` a string, `sl off lenoff`
a string with its length at `lenoff`, `n7` a name (its last letter + #80), `fn` a CP/M 8 + 3 name,
`ver` 3 bytes as 1.23, `#` the record's number, `a` its address. After them: `xN` times N, `enum
"a,b,c"` (by place) or `enum "0=a,5=b"` (by value), `mask m` (an enum value not found: anded with
m, looked up again), `"unit"` after the value.

Numbers: decimal, `#` hex, `16K`. In `src`, `link` and `go` arguments, titles and text: `{1}`
`{2}` `{3}` the node's parameters, `{s}` MON's slot argument; in `go` also `{#}` the row's number,
`{@}` its address, `{heading}` a column's value.

**Your program's map.** Run it in one slot, MON in another: `MON MY.MAP 2`. Its nodes point at
your data with `src slot {s} address`; from fixed points (a table at a known address) `walk`
follows your linked lists and `deref` your pointers:

```
cat "My program"
node chain "The list"
src slot {s} #8000 64
rec 8
walk w 0
f "Addr" a
f "Value" w 2
f "Name" s 4 4
go hex slot {s} {@}
view list
```

**8BML in Bml.cls:** `-` (title), `.`, `<` (a back link), `>` (a toolbar of links), `b` and `t`
(text, word wrapped), `p` (a heading, centred, `=` under it), `s` (a sub heading, `-` under it),
`h`, `n`, `l` (a link: `-> text`; flag `r` right), `d` (a download link: `^ text`), `i` (an
image: its text, `:) text`), `v` (a table: `"columns"`, then each heading's `""`, `"text"`, then
each cell's `"url"`, `"text"` - a cell with a URL is a link), `x` (`[ text ]`), `y` and `z` (text
fields as `|____|`), `w` (a select: `[ text v]`). Not yet: filling in forms, images, music.
CyborgOS's own: `r"text"` - a line as it is (not wrapped, its spaces kept), for hex dumps and
lists.

## 5. Programs

### What runs

A program is a CP/M program that talks to the console through the BDOS. NTC BASIC programs
built for the **cpm** platform are exactly that. In a slot a program has the bank from #0100
to #EEFF: 59.5K. All its registers (IX, IY and the alternate set too) are the same after a BDOS
call or an interrupt as before.

When a program starts, its default FCBs (#005C, #006C) are filled from the command tail as the
CCP does it: `TYPE B:NOTES.TXT *.BAK` gives FCB 1 drive 2, `NOTES   TXT`, and FCB 2 `????????BAK`
(drive 0: the slot's own). The tail itself is at #0080 (its length, then the text in capitals).

The BDOS calls (A and L hold the answer, H is 0; the ones marked *bank* are answered in the
slot's bank, without the hypervisor):

| Function | Does |
|---|---|
| 0 | end (also `jp 0`, the BIOS's BOOT / WBOOT, and a `ret` from the program) |
| 1 | a key, waited for, echoed (*bank*; the slot sleeps until a key comes) |
| 2 | a character out (*bank*) |
| 3 | the reader: #1A (an end of file) (*bank*) |
| 4, 5 | the punch, the printer: taken, nothing done yet (*bank*) |
| 6 | E = #FF: a key or 0; E = #FE: is one waiting; else E out (*bank*) |
| 7, 8 | get / set the IOBYTE (#0003) (*bank*) |
| 9 | the string at DE, to `$` (*bank*) |
| 10 | a line typed into the buffer at DE (its size, then how many came, then the characters): DEL and backspace rub out, Control + U or X the whole line, Control + C at its start ends the program, Return ends it (*bank*) |
| 11 | is a key waiting (*bank*) |
| 12 | the version: #22 (CP/M 2.2) |
| 13, 32 | reset the discs, the user number: nothing to do (0) |
| 14 | select a disc: the slot's drive (as CD) |
| 15, 16 | open (to read; on a RAM disc to read and write), close |
| 17, 18 | search for the first / next file matching the FCB's name (`?` any character): its entry in the slot's drive's (or the FCB's drive's) folder as UniDOS lists it (a RAM disc: its own directory; an AMSDOS floppy: none), as a CP/M directory entry at the DMA (A = 0; the record count from its length, 128 at most); #FF none |
| 19 | delete (the disc ROM's `|ERA`) |
| 20, 33 | read the next record / record *n* (the file read again from its start when *n* is behind) |
| 21, 34, 40 | write the next record (34 and 40 write in order too) |
| 22 | make a file (to write) |
| 23 | rename (the disc ROM's `|REN`): the old name at FCB 0-11, the new at 16-27 |
| 24 | the logged-in discs: the slot's drive's bit |
| 25 | the slot's drive |
| 26 | the DMA address |
| 27, 31 | the allocation vector, the disc parameter block: a CPC data disc's (180 1K blocks, 64 directory entries) (*bank*) |
| 28, 29, 30, 37 | write protect, read-only discs, file attributes, reset drives: 0 (*bank*) |
| 35 | the file's size in records into r0-r2 (counted, reading it through) |
| 36 | the random record (r0-r2) from where the file is: the next record read or written (a file not open: from the FCB's extent and record) |
| others | answer #FF |

**The BIOS.** (#0001) points at a CP/M 2.2 BIOS jump table (WBOOT, its second entry), so a
program can call the BIOS directly: CONST, CONIN and CONOUT work as BDOS 11, 1 and 2; BOOT and
WBOOT end the program; LIST and PUNCH take the character and do nothing yet, READER gives #1A,
LISTST #FF; SETDMA is BDOS 26. The disc entries can't reach sectors here: SELDSK gives 0 (no
such drive), HOME / SETTRK / SETSEC do nothing, READ and WRITE give 1 (an error), SECTRAN
gives the sector back.

Files go through the firmware's cassette calls (the disc ROM's: AMSDOS, UniDOS ...): one file
being read and one being written at a time, over all the slots (another gets #FF until it is
closed); a slot's open files are closed when its program ends, is killed or reset. CP/M lets a
program open a file to read and never close it (a new open replaces it): until then it holds
the one file being read, and RUN, DIR and CD (which read files too) say "not found". A file is
read as CP/M sees it: 128 byte records, the last one padded with ^Z, an AMSDOS header left out.

The console understands CR, LF, backspace, TAB (to the next column of 8) and the VT52 codes NTC uses with `Option Terminal
VT52`: ESC E (clear), ESC H (home), ESC Y *row col* (move). So in a program: `Print`, `Inkey`,
`Input`, and with `Option Terminal VT52` also `Cls` and `Locate`. `End`, and
`Option PressAnyKeyOnEnd` (it waits for a key in its own slot), work as usual.

On a RAM disc ([4b](#4b-ram-discs-ramdisc)) the file calls are CP/M's own: a file opened can be
written, records read and written at random in place (after BDOS 33 the next sequential read
is record *n* again, as in CP/M), searches list the RAM disc's directory (each extent with `?`
as the extent), and any number of files are open. What follows is about discs.

Not yet: the Graphics class (it writes the CPC's screen, which a program in a bank can't see).
On a disc, searches need UniDOS (an AMSDOS floppy lists nothing). Random records: reading goes on from where the file
is (after BDOS 33, the next sequential read is the record after *n*, not *n* again); writing is
always the next record. Sector access through the BIOS.

### Making a .CYB

A `.CYB` file is a cpm build of the program with an AMSDOS header (the header gives its length;
a plain `.COM` is read to its real end - [6](#6-plain-com-files)).

- **The GUI:** platform **cpm**, tick **AMSDOS .BIN / .CYB**: assembling the program writes
  *NAME*.CYB beside the .COM (NAME is the project's name).
- **The command line:** `node test/cli.js prog.bas --platform=cpm --amsdos=NAME > NAME.ASM`, then
  `sjasmplus NAME.ASM` writes NAME.CYB.

Put the .CYB on the same disc as CYBORGOS.BIN (for example with a disc tool, or `cpmcp`).

A program that calls the BDOS from its own `#asm` (`call 5`, as the disc commands' `Bdos`
functions do) puts `ei` before it and `di` after it, as NTC's own calls do: the BDOS comes back
with interrupts on, and in normal mode SP is the program's threaded code - an interrupt there
writes its return address over the program.

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
| #0000 | `jp` the BIOS's WBOOT (the end); (#0001) - 3 = the BIOS jump table |
| #0003 | the IOBYTE |
| #0005 | `jp` the BDOS; #0006 = #EF00, the top of the program's memory |
| #0038 | `jp` the interrupt save |
| #0044-#0048 | the bank switch (`out (c), c`, `jp` its landing) |
| #005C, #006C, #0080 | CP/M's default FCBs, the command tail |
| #0100-#EEFF | the program (59.5K) |
| #EF00-#F23F | the BDOS, the BIOS jump table, the interrupt stubs, the disc parameters, the start-up (the default FCBs) |
| #F240-#F2FF | the program's first stack (SP #F2FC at the start: a `ret` to #0000 under it ends the program); a CP/M program that keeps it calls the BDOS on it. NTC programs have their own (256 bytes in the program) |
| #F300-#F5FF | the font (characters 32-127): the console draws the slot's text from it |
| #F600-#F680 | the characters out it collected, and their count |
| #F681 | the slot's next key (0: none), put there by the hypervisor |
| #F682-#F686 | its console: column, row, the page ring's top row, escape state and row |
| #F687-#F689 | its console's columns and rows, its MODE (0 2, 1 S, 2 W, 3 UW, 4 P): the console and BDOS 49 go by them |
| #F68A-#F68D | the status strip's text (MODE S) |
| #FF00-#FF1F | its store's page numbers (BDOS 131 op 12; 0 none) |
| #F68F-#F6D5 | the slot's command line being typed (its length, then up to 70 characters) |
| #F6D8-#F6E4 | the name of the program it runs (its length, then up to 12 characters) |
| #F6F0-#F6FC | BDOS 17's name (12 bytes) and the entries searched so far |
| #F700-#FEFF | the slot's text page: a ring of its rows (2K at most: 80 x 25, 80 x 24, 88 x 23, 96 x 21, 64 x 32) |
| #FFFE | the slot's saved SP |

## 6. Plain .COM files

A CP/M program copied to the disc as it is (a `.COM`, no AMSDOS header) runs by its name
(`CRUNCH`: CRUNCH.CYB, else CRUNCH.COM) or as `RUN CRUNCH.COM`. UniDOS reads a file with no
header to its real end (AMSDOS alone would stop at its first #1A byte), and a RAM disc knows its
records, so nothing more is needed - the FILES.DIR / NAME.HDR entries earlier versions wanted
for this are gone. RUN reads it with `FileSystem.ForReadRaw`: every byte, a #1A just a byte.

## 7. Not yet

- `LOAD`, `SAVE`, `DISC`, `TAPE`.
- True random access on discs (RAM discs have it: [4b](#4b-ram-discs-ramdisc)); an AMSDOS floppy's
  directory through the disc calls (FLOPPY reads one itself).
- Two-sided and 80 track floppies (FLOPPY: one side, 42 tracks); a disc to disc copy.
- Folders on RAM discs (the directory has a folder byte for them already).
- The printer and the punch (BDOS 4, 5; the BIOS's LIST, PUNCH).
- Drivers (printer, serial, sound ...) that programs reach with far calls.
- Faster BDOS calls.

## 8. For developers

CyborgOS itself is `bas/cyborgos320kb/Main.bas`, `Hyp.cls` (the bank side, the switch), `Hot.cls`
(the system keys, an interrupt class) and `Ent.cls` (64 byte file entries, in Z80 - unused since
FILES.DIR went; the 128K version's CYBADD uses its own), built for **cpcfw** (also with `Option Library
ROM`). `Option Reserve &H4000, &H4000` keeps the window it reaches the banks through free: the
hypervisor is built round it, from #0040 and on from #8000; the Memory class's tables follow it
(`Option Memory CPCExpansion 257`: all 64 banks of a 4MB expansion - about 400 bytes of main RAM
left with AMSDOS alone; the Library: ROM build takes 33 pages, 8 banks, below the ROM's RAM at #8800). Its file
work (RUN's loading, DIR, CD, the programs' BDOS file calls) is `Hyp.FileCall`, Z80 on the
firmware's cassette calls, with #4000-#4FFF of the hypervisor's own page (the first expansion
bank's page 0, C4) as the disc ROM's two 2K buffers; most of its code runs in that page too,
from #5300 after the font, with the bank image that Install copies into each slot. Both are
NTC window data (`; @window` in the #asm): in CYBORGOS.BIN's window hole, copied into the page
at the start, so they take no main RAM. The
test programs are in `bas/cyborgos320kb/tasks/`, the commands in `bas/cyborgos320kb/cmds/`, each
built for cpm: COPY, ERA, DIR with `CybDir.cls` (a drive's own directory read: UniDOS's listing,
a RAM disc's); PS, KILL, RESET, FG, WAIT, TOP, MEM with `CybSys.cls` (BDOS 131); HELP, CD, RAMDISC,
MKDIR, RMDIR, DRIVE, FLOPPY, TYPE, RENAME alone (HELP's texts: `bas/cyborgos320kb/help/*.HLP`, on disc 1). CyborgOS's own BDOS functions, for these commands:

| BDOS | DE = a block in the program | Does |
|---|---|---|
| 130 | op, letter, the driver's address, its length (words) | RAMDISC: op 0 a RAM disc as the letter (the driver goes into a page of its own the first time), 2 a free page more for it, 1 one of its pages back, 3 a line of the RAM discs' list |
| 131 | op, slot or value, then what comes back | op 9 MODE also 5 (F); 10 memory read (byte 1: 0 a 16K page, 1 an upper ROM, 2 main RAM, 3 a slot's memory - one in use; word 2 the page / ROM / slot, word 4 the address, word 6 where to in the slot, word 8 how many - 2K at most, a page or ROM to its end); 11 the pointer (byte 1: 0 off, 1 at byte 2, byte 3 - a column, a row; only while the slot is in front); 12 the store: word 2 K (16K pages of the slot's own, 512K at most; gone when the program ends); 13 / 14 a 2K block of it (word 2) from / to the slot (word 6, word 8); 15 a raw table into the slot at word 2 (2K at most; byte 1: 0 the slots - a word how many, then from 16 a 16 byte record each: state, in front, MODE, the name's length, the name; 1 the memory - words: the tables' end, the top of free main RAM, the pages, total K, free pages, then from 16 a byte a page: B a slot's, U CyborgOS's, - free; 2 the upper ROMs 0-31 - 64 bytes each: the first 16 of the ROM, 48 of its name table; 3 the RAM discs - the driver's table, 8 x 16: letter, -, blocks, free blocks). 10-15 not in the Library: ROM build. And: op 0 a slot's state, whether it is in front, its program's name; 1 kill; 2 reset (0: this slot); 3 to the front; 4 wait until no other program runs; 6 TOP's table into this slot; 7 the memory (the tables' end, the top, the pages, the totals line); 8 32 pages of the bank map; 9 MODE (0-4: this slot's, its console cleared; 255: which it is). 7 and 8 not in the Library: ROM build |

CyborgOS starts by running `RAMDISC Z SYSTEM` with the boot drive's letter (the system drive:
[2](#2-starting)). The regression tests run it in the harness with 4
slots (576K), 20 slots (4MB), 2 slots (320K), refused on 128K, and as a Library: ROM build.

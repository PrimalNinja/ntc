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
- `build/dsk/cyborgos320k.dsk` has CYBORGOS.BAS (the loader: RUN"CYBORGOS), CYBORGOS.BIN (this
  version), CYBORGOS.Z (the files for the system drive Z), the commands (HELP, PS, TOP, KILL,
  RESET, FG, WAIT, MEM, MODE, DIR, CD, COPY, ERA, TYPE, PREP, RENAME, RAMDISC - each a .CYB), MON
  and its SYSTEM.MAP, three test programs (TICKER.CYB, CRUNCH.CYB, LINES.CYB), INSTALL.BAS and a
  FILES.DIR listing every file on it. INSTALL.BAS (`RUN"INSTALL` from BASIC, the disc in B) puts
  CyborgOS on IDE:: each file erased there first (`|ERA`), then copied from B (`|COPY,"DFB:"...,"IDE:"`). CRUNCH is also on it as a plain
  CRUNCH.COM (long name BIGCRUNCH).
  `build/dsk/cyborgos128k.dsk` is the 128K version's (a 6128 and up); it also carries CYBADD.BIN
  (the 320K version drops it - `PREP ... ADD`/`REMOVE` keeps FILES.DIR instead).

## 2. Starting

```
RUN"CYBORGOS
```

CYBORGOS.BAS (ASCII BASIC) puts CyborgOS's command line at #BE80 (it outlives a reset), then runs
CYBORGOS.BIN. The line is `CYB` and the boot drive (`CYB A`), then words, a 0 after it:

| Word | |
|---|---|
| `KEYREP` *n* | the keys' start delay and repeat *n* times as long (KM SET DELAY, 255 at most each): for an emulator running faster than a CPC - WinAPE at 1000% wants `KEYREP 10` |

To start from another drive change `d$` in CYBORGOS.BAS (`CYB C` for drive C ...), for words `o$`
(`o$=" KEYREP 10"`). CyborgOS takes A when #BE80 doesn't start with `CYB `.

The screen goes to mode 2, slot 1 shows its command line (in MODE S: [3](#3-slots-and-the-screen)), and CyborgOS makes the
**system drive Z**: it runs `RAMDISC Z SYSTEM` (the boot drive), which reads the boot drive's
CYBORGOS.Z - a text file, one file name a line - and copies those files (the commands) from the
boot drive to a RAM disc Z, a page bigger at a time as each needs it. Keys typed meanwhile wait.

```
CyborgOS slot 1 of 4 - Control + 1-4, Control + ESC TOP, HELP

1> Z: system drive, 16 commands (86K)

[RAMDISC.CYB ended]
1>
```

A name typed at a prompt is looked for on Z first, then on the slot's drive, then on the boot
drive. So the commands on Z start at once (a memory copy, not a disc read) and act as built-in
ones: a program on a disc with a command's name is behind them (`RUN A:COPY` reaches it). A
command that didn't fit on Z, or is missing from CYBORGOS.Z, still runs: from the boot drive.
Z takes pages for as long as there are free ones: on a 320K machine that is all of them (82K:
every command but MEM), which leaves none for other RAM discs - shorten CYBORGOS.Z to keep some. Without CYBORGOS.Z (or RAMDISC.CYB) there is no Z
and every command comes from the disc.

Z is CyborgOS's own: CyborgOS's programs name it (`Z:`, e.g. `COPY A:NEW.CYB Z:` to update a
command), CP/M programs don't - they know A to P only, and a slot whose drive is Z can't use it
as its own drive. CD doesn't go there. More text files (settings ...) will join CYBORGOS.Z.

## 3. Slots and the screen

Each slot is a whole 64K bank with its own text page. The slot in front is the one
on the screen and the one the keyboard types into; the others keep running, and their output
goes to their own page.

**MODE.** Each slot has its own screen mode; the screen takes the mode of the slot in front.
All of them are in the 16K screen at #C000 (mode 2 pixels: 8 a character) and keep the hardware
scroll. The wider and taller ones use the border, for a widescreen TV's zoom or a monitor that
shows it:

| `MODE` | Screen | The console | |
|---|---|---|---|
| `2` | 80 x 25 | 80 x 25 | the standard CPC screen |
| `S` | 84 x 24 | 80 x 24 | and a status strip of 4 columns on the right (the slot's number at its top, for now). **The default**: a slot opens in it |
| `W` | 88 x 23 | 88 x 23 | wide |
| `UW` | 96 x 21 | 96 x 21 | ultrawide |
| `P` | 64 x 32 | 64 x 32 | portrait |
| `F` | 84 x 24 | 84 x 24 | all of it the program's (MON: its own status columns) |

`MODE` *m* clears the slot's console at the new size; `MODE` alone lists them and says this
slot's. TOP is always shown in MODE 2 (its table is 80 wide); the slot's own mode comes back
with it. A program learns the size of its console from BDOS 49 (CP/M 3's system control block:
offset #1A the width - 1, #1C the page length), answered in the slot's bank; text it writes
past the last column wraps there.

- **Control + 1 to 9, 0** brings that slot to the front (0 is slot 10). With more than 10
  slots, the same number pressed twice quickly (within 0.3 s, Control held) is slots 11 to 20
  (Control + 3, 3: slot 13; 0, 0: slot 20); a single press then counts after 0.3 s, at once
  when Control is let go or another number is pressed. With 10 slots or fewer a press counts
  at once. A slot used for the first time opens with
  its command line. Hold Control and press the numbers one after another to step through the
  slots. The keys are looked at 50 times a second whatever runs; keys typed while Control is
  held don't go to the programs.
- **Control + ESC** shows the TOP screen: each slot's state (command line, running), its
  program, and in the last whole second its turns, BDOS calls that reached the hypervisor and
  characters out. It is drawn once (straight into screen memory, at once) and stays (other keys
  do nothing) until Control + ESC again or Control + a slot number. Under the slots: the total
  and free memory (MEM has the map). The `TOP` command prints the same into the slot's console
  instead.
- **FG** *slot* does the same from a command line.

A slot either shows its command line, or runs a program. When the program ends, the slot's
command line comes back (`[NAME.CYB ended]`).

## 4. Commands

Typed at a slot's prompt (`1>`), in capitals or not. Backspace / DEL rub out. Three are built in
(RUN, CLS, QUIT); the rest are programs (.CYB) on the system drive Z, run like any program -
they need nothing of the hypervisor's RAM, only a BDOS call (131) for what the hypervisor knows.

| Command | Does |
|---|---|
| *name* [*args*] | runs the program *name* - from Z, else this slot's drive, else the boot drive - in this slot; the rest of the line is its command tail (#0080, as CP/M has it: `System.CommandLine` in NTC). Not found anywhere: `? NAME (HELP)` |
| `RUN` [*slot*] *name* [*args*] | the same, also for a name that is a built-in command - `RUN CLS` runs CLS.CYB, not the CLS command. With a slot first: runs it there (it keeps running in the background while this command line stays) - `RUN 2 CRUNCH 3` |
| `DIR` [*v*:][*pattern*] [`FULL`] | the names of the files in FILES.DIR, then of the drive's other files (a RAM disc's: ones programs made), across the screen - 13 columns each, as many as the console's width takes (BDOS 49), a name never split - with nothing else. A pattern (`*.CYB`, `T?*`) picks them; `B` alone is drive B. `FULL`: a line each - disc name, length in bytes, long name (the other files' sizes from their records) - and how many |
| `CD` [*drive*] | this slot's drive (A-P, a RAM disc too): kept only when the drive is there and has a FILES.DIR. Each slot has its own (the boot drive to start with), as in CP/M; programs, RUN and DIR use it. `CD` alone: the slot's drive |
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
| `HELP` | the commands, then a line on each |
| `COPY`, `ERA`, `TYPE`, `PREP`, `RENAME` | disc commands ([4a](#4a-disc-commands-copy-era-type-prep-rename-and-help)) |
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

A program's name is found as *name*.CYB, else *name*.COM (only with an entry:
[6](#6-plain-com-files-filesdir-and-namehdr)), else the .COM whose FILES.DIR entry has the long
name *name*; `NAME.COM` / `NAME.CYB` take that one.

## 4a. Disc commands: COPY, ERA, TYPE, PREP, RENAME (and HELP)

Programs on the CyborgOS disc (`.CYB`, NTC BASIC built for cpm: `bas/cyborgos320kb/cmds`), run by
their names like any program. They only touch files that are in the volume's FILES.DIR (the
files added there); a volume is `A:`, `B:` ..., or none for the slot's drive. A file is named
by its disc name (`README.TXT`; `NAME` alone also finds `NAME.COM`) or its long name.

| Command | Does |
|---|---|
| `PREP` *v* | makes an empty FILES.DIR on volume *v* (`B` or `B:`) - one 128 byte record of unused entries, as a disc ROM may make no file for an empty one - then looks for it again. A volume that has one already is left alone. CD needs it, and COPY's target |
| `PREP` [*v*:]*pattern* `ADD` | each file on *v* that fits the pattern (`*` any characters, `?` any one: `*.CYB`, `T*`, `*` all) and isn't already listed is added to FILES.DIR - its size from the directory, its long name the name before the `.`. On a RAM disc (Z and any `RAMDISC` drive) it sees the real directory; on a floppy it sees only what FILES.DIR already lists (reading a floppy's own catalogue is not done yet). It replaces the old CYBADD |
| `PREP` [*v*:]*pattern* `REMOVE` | each listed file that fits the pattern is dropped from FILES.DIR (any drive) |
| `COPY` [*v1*:]*name* *v2*[:*newname*] | copies the file to volume *v2* (which needs a FILES.DIR: PREP), as *newname* or the same name, and puts its entry (length, long name, flags) in *v2*'s FILES.DIR |
| `COPY` [*v1*:]*pattern* *v2* | each file that fits the pattern (`*` any characters, `?` any one: `*.CYB`, `T*`, `????.COM`, `*.*` - its disc name or long name) copied to *v2* with its own name; *v2*'s FILES.DIR written once at the end. It stops when the disc or FILES.DIR is full, says how many were copied |
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
and a `.CYB` copy no longer runs as a `.CYB` from a disc (on a RAM disc it does: there a file
is read as it is). The files go through the hypervisor's BDOS calls (below), one file read and
one written at a time on a disc (any number on a RAM disc).

## 4b. RAM discs: RAMDISC

`RAMDISC` (a program on the disc) makes drives out of free memory, with what the disc ROM
can't give CP/M programs: real random access (records read and written in place, a file
opened and written to), any number of files open in any number of slots, true sizes (BDOS 35)
and searches (17, 18) of the RAM disc's own directory.

| Command | Does |
|---|---|
| `RAMDISC` *v* *size* | drive *v* (A-P) a RAM disc of *size*: `64K`, `256KB`, `1MB`, `512` (KB) ... in 16K steps, 4MB in all. It gets an empty FILES.DIR (so CD, COPY, ERA, TYPE, RENAME work on it) |
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
FILES.DIR     1K
README.TXT    1K
2 files, 250K free of 256K
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
| `src dir d` | drive d's files (FILES.DIR's: 16 bytes each, the name at 1, its records at 15) |
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
| 17, 18 | search for the first / next file matching the FCB's name (`?` any character): its entry in the slot's drive's (or the FCB's drive's) FILES.DIR, as a CP/M directory entry at the DMA (A = 0; the record count from its length, 128 at most); #FF none |
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
On a disc, searches see what FILES.DIR lists (a file a program made isn't in it until COPY or PREP ADD adds
it), and not while a file is being read. Random records: reading goes on from where the file
is (after BDOS 33, the next sequential read is the record after *n*, not *n* again); writing is
always the next record. Sector access through the BIOS.

### Making a .CYB

A `.CYB` file is a cpm build of the program with an AMSDOS header (the header gives its length;
a plain `.COM` needs an entry for that - [6](#6-plain-com-files-filesdir-and-namehdr)).

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

## 6. Plain .COM files: FILES.DIR and NAME.HDR

A CP/M program copied to the disc as it is (a `.COM`, no AMSDOS header) runs too, once it has
an **entry**: AMSDOS can't say how long a file with no header is (it reads it as text and
reports each #1A byte as an end of file), so the entry says it - and it is also the say-so
that the program runs here: a `.COM` with no entry is not run (`NAME: not found`), so a
stray or broken one isn't started.

- **FILES.DIR** - one file of entries for the disc. `PREP [v:]pattern ADD` / `REMOVE` keeps it
  (inside CyborgOS; it replaces the old AMSDOS CYBADD): ADD takes each disc file that fits, reads
  its length from the directory and gives it a long name (the name before the `.`); `RUN LONGNAME`
  then runs it. ADD sees a RAM disc's real directory; a floppy's own catalogue is not read yet
  (the 128K version still ships CYBADD for that).
- **NAME.HDR** - the entry for NAME.COM alone, beside it. RUN looks here first.
- **The long name** is a second name for the file, not a description: one word (the command
  line splits at spaces), up to 38 characters. `RUN LONGNAME` runs a .COM by it, and COPY, ERA,
  TYPE and RENAME take it as well as the disc name; DIR shows it. (A description - with spaces -
  would need its own field; the entry has room: bytes 22-23 and a directory of its own later.)
- The CyborgOS disc's FILES.DIR lists every file on it: CYBORGOS.BIN (and on 128K CYBADD.BIN) as
  "other", the .CYB programs with their names as long names, and CRUNCH.COM (long name BIGCRUNCH).
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
| 14-15 | its length in bytes (#EE00 at most: #0100-#EEFF) |
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

- `LOAD`, `SAVE`, `DISC`, `TAPE`.
- A plain `.COM` without an entry ([6](#6-plain-com-files-filesdir-and-namehdr)), and searches
  of a disc's own directory: that needs the directory read (record counts, AMSDOS's sector
  command #84), which comes with the file system work, and true random access on discs with
  it (RAM discs have it now: [4b](#4b-ram-discs-ramdisc)).
- Folders on RAM discs (the directory has a folder byte for them already).
- The printer and the punch (BDOS 4, 5; the BIOS's LIST, PUNCH).
- Virtual directories and long names with spaces (FILES.DIR has room for both).
- Drivers (printer, serial, sound ...) that programs reach with far calls.
- Faster BDOS calls.

## 8. For developers

CyborgOS itself is `bas/cyborgos320kb/Main.bas`, `Hyp.cls` (the bank side, the switch), `Hot.cls`
(the system keys, an interrupt class) and `Ent.cls` (FILES.DIR entries, in Z80 - CYBADD,
`bas/cyborgos320kb/tools/CYBADD.bas`, uses it too), built for **cpcfw** (also with `Option Library
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
built for cpm: COPY, ERA, TYPE, PREP, RENAME, DIR with `CybDir.cls` (FILES.DIR read and
written); PS, KILL, RESET, FG, WAIT, TOP, MEM with `CybSys.cls` (BDOS 131); HELP, CD, RAMDISC
alone. CyborgOS's own BDOS functions, for these commands:

| BDOS | DE = a block in the program | Does |
|---|---|---|
| 130 | op, letter, the driver's address, its length (words) | RAMDISC: op 0 a RAM disc as the letter (the driver goes into a page of its own the first time), 2 a free page more for it, 1 one of its pages back, 3 a line of the RAM discs' list |
| 131 | op, slot or value, then what comes back | op 9 MODE also 5 (F); 10 memory read (byte 1: 0 a 16K page, 1 an upper ROM, 2 main RAM, 3 a slot's memory - one in use; word 2 the page / ROM / slot, word 4 the address, word 6 where to in the slot, word 8 how many - 2K at most, a page or ROM to its end); 11 the pointer (byte 1: 0 off, 1 at byte 2, byte 3 - a column, a row; only while the slot is in front); 12 the store: word 2 K (16K pages of the slot's own, 512K at most; gone when the program ends); 13 / 14 a 2K block of it (word 2) from / to the slot (word 6, word 8); 15 a raw table into the slot at word 2 (2K at most; byte 1: 0 the slots - a word how many, then from 16 a 16 byte record each: state, in front, MODE, the name's length, the name; 1 the memory - words: the tables' end, the top of free main RAM, the pages, total K, free pages, then from 16 a byte a page: B a slot's, U CyborgOS's, - free; 2 the upper ROMs 0-15 - 128 bytes each: the first 16 of the ROM, 112 of its name table; 3 the RAM discs - the driver's table, 8 x 16: letter, -, blocks, free blocks). 10-15 not in the Library: ROM build. And: op 0 a slot's state, whether it is in front, its program's name; 1 kill; 2 reset (0: this slot); 3 to the front; 4 wait until no other program runs; 6 TOP's table into this slot; 7 the memory (the tables' end, the top, the pages, the totals line); 8 32 pages of the bank map; 9 MODE (0-4: this slot's, its console cleared; 255: which it is). 7 and 8 not in the Library: ROM build |

CyborgOS starts by running `RAMDISC Z SYSTEM` with the boot drive's letter (the system drive:
[2](#2-starting)). The regression tests run it in the harness with 4
slots (576K), 20 slots (4MB), 2 slots (320K), refused on 128K, and as a Library: ROM build.

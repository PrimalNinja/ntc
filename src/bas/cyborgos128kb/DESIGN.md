# CyborgOS - design

CyborgOS is a hypervisor for the Amstrad CPC, written in NTC BASIC (with `#asm` only for
the bank switch), running up to 16 CP/M-style programs, each in its own 64K bank. The
hypervisor is an ordinary NTC program; the programs use a new compiler target, cyb, which
is very close to the cpm platform. It is also a show of what NTC BASIC can do.

Status (2026-10-15): the 128K version - `bas/cyborgos/` (Main.bas, Hyp.cls, Hot.cls,
Ent.cls; test programs in `tasks/`, disc commands in `cmds/`), on `build/dsk/cyborgos128k.dsk`, kept
as `bas/cyborgos128kb/`; the next one needs 320K (`bas/cyborgos320kb/`, below). Checked in the
harness (4 slots with 576K, 16 with 4MB, 1 with 128K) and on the real 6128 ROMs (realcpc: 1 slot). What it does now, and where it differs
from the design below:

- The switch at #0040 is in every cpc / cpcmin / cpcfw program's start code (`jr` over
  #0042-#004C: #0042 main RAM's SP, #0044 `out (c), c`, #0046 `jp` the landing
  `ld sp, (#0042) : ret`). A bank has `out (c), c` at #0044 and its own `jp` at #0046.
- The task entry is a CP/M BDOS at #0005 (decided: programs built for the cpm platform run
  unchanged). Handled now: 0 (end), 1, 2, 6, 9, 11, 12 (gives 2.2), 13, 14, 25, 26, 32 and the
  file calls 15, 16, 19-23, 33, 34 (Hyp.FileCall, Z80 on the disc ROM's cassette calls; delete
  and rename through its |ERA and |REN). Search (17, 18) and size (35) not yet (255).
- Programs are `.CYB` files: a cpm build with an AMSDOS header. `RUN name` loads name.CYB at
  #0100 of the slot's bank. A plain `.COM` (no header) runs when FILES.DIR or NAME.HDR has an
  entry for it (64 bytes: its disc name, length, long name ...; CYBADD.BIN writes
  them) - the length AMSDOS can't give, and the say-so that it runs. Read with
  `FileSystem.ForReadRaw` (each #1A is AMSDOS's "soft" end of file, and reading goes on to the
  last record: checked on the real ROMs). The entry routines are Z80 in Ent.cls (SetName, Length,
  Make, Where, DiscName, Show): in BASIC they made CyborgOS 3K bigger. CYBADD (a separate CPC
  program, `bas/cyborgos/tools/`) writes FILES.DIR: in CyborgOS, ADD cost 900 bytes, which took
  the Memory class's room for 16 slots. CD runs the disc system's |letter (KL FIND COMMAND, KL
  FAR PCALL) per slot. Until the disc's own
  directory is read (record counts, random access), then for long names and virtual
  directories.
- Scheduling is from the hypervisor's main loop: a program runs for a time slice of 6
  interrupts (1/50 s; the interrupts inside a slice are handled in Hyp.Run's code, with no trip
  through BASIC) or until a BDOS call that needs the hypervisor. NTC's safe points let
  interrupts in, so a program with no BDOS calls still gives the CPU back. The front slot gets
  every other turn (half the time). The system keys (Control + 1-8, Control + ESC) are an
  interrupt class (Hot.cls, 50 a second); with more than 8 slots (16 on 2MB or more) a number
  pressed twice quickly is slots 9-16. Each slot's command line is kept in its bank (#F68F).
- Keys: the hypervisor puts the slot's next key in its bank (#F681); the BDOS stub answers 1,
  6 (#FF / #FE) and 11 from it, with no switch.
- Characters out are collected by the BDOS stub in the bank (128) and handed over when full,
  at a far call or at the end of a slice (IX = how many). The console is Z80 (Hyp.Con): with
  the slot's page 3 in the window once, it reads them from the bank, writes the slot's page (a
  ring of 25 rows: no copy to scroll; the column, row, ring and escape state in the bank at
  #F682) and, for the front slot, screen memory directly (the firmware's matrices, its own
  addresses from SCR GET LOCATION; SCR HW ROLL to scroll). Main.bas keeps the BASIC it
  replaced, commented out, for comparison.
  TOP (Control + ESC) shows the last whole second's turns, BDOS calls and characters per slot,
  drawn once (Hyp.Say, straight into screen memory); the TOP command prints it into the console.
- Every register is kept for a program over a BDOS call and an interrupt (IX, IY, the
  alternate set); the hypervisor keeps its own (the firmware's BC') round each run, runs the
  firmware's interrupt handler (`rst #38`) for an interrupt that stopped a program, and turns
  the upper ROM off while a program runs (Library: ROM has the keyword ROM on).
- The command line is one copy in the hypervisor, with each slot's line in its bank (RUN, FG,
  PS, TOP, KILL, RESET, WAIT, CLS, MEM, DIR, CD, QUIT; `B:` alone is CD B). Any other name runs
  that program from the slot's drive (then A), the rest of the line its command tail. HELP,
  COPY, ERA, TYPE, PREP and RENAME are programs on the disc (`cmds/`). Control + 1-8 brings a
  slot to the front (more than 8 slots: the number twice for 9-16).
- Each slot's text page (80 x 25) is at #F700 of its bank; the BDOS stubs at #F500 (the top of
  the TPA), the characters out at #F600, the saved SP at #FFFE: about 61K for a program.
- Speed: 200 lines of 62 characters scroll at about 16 lines a second on the real ROMs (was 3,
  then 8 with the BASIC console; and the screen didn't scroll). Profiled on the real ROMs
  (realcpc PROF): the firmware (its interrupts, 300 a second) about 33%, Hyp.Con 27%, the
  program 18%, the hypervisor's BASIC the rest. A BDOS call that reaches the hypervisor is
  still a round trip through BASIC.
- Memory (the RAM build): `Option Reserve` builds round the window - the hypervisor fills
  #0040-#3FFF and goes on at #8000 to about #9E04 with its arrays (strings and variables are
  laid out one by one, filling what is left below the window); the Memory class's tables follow
  it, 3 bytes a page (its RAT, 1 byte, and each page's port, 2: PRIMAL's layout), up to the top
  of free RAM (#A5F0 with AMSDOS alone; lower when the ROMs started take more). Option Memory
  CPCExpansion 193: 48 banks at most (all 64 of 4MB don't fit); about 1.4K is left over with 48
  banks, more with fewer, less with ROMs like UniDOS - MEM's "free" line shows it. Main RAM's
  own #4000-#7FFF (page 1) is the disc ROM's two 2K file buffers (taken as a U page at the
  start). The Library: ROM build ends about #8685, tables for 8 banks (4 slots) to #8800.
- Room: the file work in Z80 (Hyp.FileCall, no FileSystem class or 2K buffer), the program
  names in each bank (#F6D8), HELP on the disc. Copies between main RAM and a slot are
  `Memory.Copy` through a 128 byte buffer (`Option Buffer Size 128`: PRIMAL's copy buffer size).
  AMSDOS's own messages ("NAME.CYB not found" when RUN looks) are kept off
  the console with TXT VDU DISABLE (Hyp.Vdu 0; on again for the last Print). Firmware
  jumpblock calls only - nothing in a ROM's own RAM (every CPC model's ROMs differ): so a disc
  error's "Retry, Ignore or Cancel?" is asked unseen and waits for a key (R / I / C).

## 1. The pieces

| Piece | Where | Built with |
|---|---|---|
| Hypervisor | main RAM (C0) | NTC, cpcfw target, full build or Library: ROM (firmware on for now) |
| Tasks (programs, the CLI) | one 64K bank each (C2, CA, D2 ... #FA) | NTC, the cyb target (CP/M-like, org #0100) |
| Drivers, classes, sprites, data | RAM pages outside the task banks | NTC page / overlay classes, called by the hypervisor |

The hypervisor owns everything banked: allocating banks and pages, loading, the #4000
window, files, drivers, the screen. A task sees only its own 64K and the switch.

## 2. How many tasks

Instances = half the extra 64K banks, at least 1, at most 16 (4 in the Library: ROM build).
They are allocated first (`AllocBank`, before anything else takes pages): up to 8 from the
first 512K block (port #7F), slots 9-16 from the next (#7E). The rest of the banks are left for
data, classes and drivers.

| Extra RAM | Banks | Tasks | Left for data, classes, drivers |
|---|---|---|---|
| 64K (6128) | 1 | 1 | none |
| 256K | 4 | 2 | 128K |
| 512K | 8 | 4 | 256K |
| 1024K | 16 | 8 | 512K |
| 2MB | 32 | 16 | 1MB |
| 4MB | 64 (48 in the tables) | 16 | 2MB (of the 48) |

The 320K version (next, `bas/cyborgos320kb/`): 320K at least (a 256K expansion; a 6128 alone
won't do). The hypervisor takes the first expansion bank's pages for its own data (C4 first,
then C5 ... as it grows: the memory tables - a RAT and the port table -, the disc buffers, the
font), never a slot; slots = banks - 1 (320K: 3, 576K: 7, 2MB and more: 16); main RAM's own
#4000-#7FFF is left free (a second screen).

## 3. Gate array settings

Value = `#C0 + bank * 8 + layout`, port high byte `#7F` (first 512K) down to `#78`.

| Layout | #0000 | #4000 | #8000 | #C000 | Used for |
|---|---|---|---|---|---|
| C0 | main 0 | main 1 | main 2 | main 3 | the hypervisor |
| C1 | main 0 | main 1 | main 2 | bank page 3 | a task drawing on the #4000 screen (main block 1) |
| C2 | page 0 | page 1 | page 2 | page 3 | a task running (its whole 64K) |
| C3 | main 0 | main 3 | main 2 | bank page 3 | a task drawing on the #C000 screen (main block 3), seen at #4000 |
| C4-C7 | main 0 | bank page n | main 2 | main 3 | the hypervisor reaching a task's or a class's page through the window |

Bank n's C2 is `#C2 + n * 8` (banks 0-7: #C2 #CA #D2 #DA #E2 #EA #F2 #FA); its C3 is that +1,
C1 that -1. The CRTC always shows main RAM, so a task in C2 can't see the screen; C1 / C3 let
a task's code in its own top 16K write the screen through #4000 (the same trick as Graphics
on CP/M Plus).

## 4. The switch

After `out (c), c` the next instruction is fetched from the other map. So each side keeps its
own bytes after the `out`, and only #0044-#0048 is reserved in both.

Main RAM (the hypervisor; NTC cpc / cpcmin / cpcfw programs start at #0040):
```
#0040  jr start                ; 18 xx   the program jumps over
#0042  dw 0                    ;         the hypervisor's saved SP (low: not in the screen)
#0044  out (c), c              ; ED 49   BC = the task's setting
#0046  jp hypervisorreceiver   ; C3 lo hi  runs when main RAM is switched in
#0049  start:
```

Each bank (in the BIOS scratch area CP/M gives #0040-#004F):
```
#0044  out (c), c              ; BC = #7FC0, or another bank's setting
#0046  jp cpmreceiver          ; runs when this bank is switched in
```

Handing over (either side): push what it wants kept (in its own memory - a bank's at the top
of its TPA), push its resume address, store SP in its own spot (main #0042, a bank e.g.
#FFFE), load BC with the target's setting, `jp #0044`. Jumps only, no calls.

Receiving: the receiver loads that side's SP from its own spot and `ret`s to the resume
address it pushed. Each side picks where it resumes: the interrupt route resumes with a full
restore, the far call route with almost none.

Bank to bank works the same: the arriving bank's own #0046 takes it to its own receiver.

## 5. Interrupts and scheduling (existing NTC interrupt classes)

- While a task runs, the interrupt is fetched from the bank's #0038: it saves the task (full
  register save on the task's stack, SP in its spot), switches to main RAM and returns into
  the hypervisor. On cpcfw the hypervisor then runs the firmware's handler (the clock, keys,
  sound and the fast ticker events that drive NTC's interrupt classes).
- **The scheduler is the interrupt classes.** Fixed-rate classes (music, network, drivers) are
  served first at their own rate; the 8 tasks are `Share` classes taking turns on the
  interrupts the fixed ones don't need (equal weights = round robin, a waiting task skips its
  turn). More or busier tasks only slow the tasks, never a fixed class.
- A task's Tick resumes that task. Keys and hotkeys (Ctrl+ESC task list, Ctrl+1..8 switch or
  start) are a Tick with the Keys class.
- Limits: 16 classes (8 tasks + 8 fixed); tasks run in normal mode only (cyb forces it: turbo
  keeps interrupts off).

## 6. Far calls (messages)

Through the same switch. Only SP changes and BC carries the setting, so A, DE, HL, IX, IY and
the alternate set reach the other side untouched:
- task to hypervisor: A = service, other registers = arguments; pointers are addresses in the
  task's own bank;
- the hypervisor knows the task (its current task), reads / writes the task's memory by
  putting the bank's page in the #4000 window (Memory class);
- reply: HL = result, carry = error, back through #0044 to the task's far call resume, which
  `ret`s to its caller without popping over HL.

Rules: one far call inside the hypervisor at a time (no task switch while a service runs; a
long one, such as a disc call, marks the caller waiting). Shared code in main RAM keeps
per-task state in arrays indexed by task number.

## 7. The bank (cyb target)

| Address | Use |
|---|---|
| #0000 | `jp` the exit (back to the CLI) |
| #0005 | the BDOS-style entry (decision: CP/M-compatible, see 10) |
| #0038 | the interrupt save, jump to the switch |
| #0044-#0048 | `out (c), c` / `jp cpmreceiver` |
| #005C-#00FF | CP/M page zero (FCB, command tail / DMA) |
| #0100 up | the program |
| top of the TPA | the receiver, save / restore, far call stub, stack, 2K text buffer, front flag |

About 61K for the program. A task that asks for graphics gets a 16K screen block (any RAM).

## 8. The screen

- Mode 2, text first. A background task writes its own 2K text buffer (or its 16K screen
  block); it doesn't know it isn't in front.
- The front task writes the real screen directly: C3 (screen at #C000) or C1 (screen at
  #4000), its drawing code in its own top 16K.
- On a switch the hypervisor copies the screen back to the old task's block and the new
  task's block in (or renders its text): about 0.2 s; a 2K text page about 0.08 s.

## 9. Fast graphics

Compiled sprites in classes in RAM pages, called by the hypervisor:
- one screen at #C000: a page class in the #4000 window writes #C000 directly;
- double buffering: the sprite code in a bank's page 3 (#C000), run in C3 or C1, writes
  either screen through #4000 - one copy serves both.

## 10. Open decisions

- The task entry: a CP/M-compatible BDOS at #0005 (C = function; cpm programs run unchanged,
  extra services above 127) or a far call of its own.
- Service numbers: a fixed table, or lookup by name for drivers.
- The CLI: one per bank, or one shared CLI in the hypervisor with per-task arrays (more room
  for programs; commands then run one at a time).
- The first driver to prove the model.

## 11. What NTC already has

- Harness: every RAM setting C0-C7 with bank bits (`--ram=576`, `4160`).
- Interrupt classes: 16, fixed rate / Frame / `Share n`.
- Memory: `Banks`, `AllocBank`, `FreeBank`, `BankPage`, `CallBank` (its 16-byte switch still
  floats; to move to the fixed #0040 area).
- Keys class; sequential files on cpcfw / cpcmin (the loader's base).
- cpm platform (org #0100, BDOS) - the cyb target's starting point.

## 12. Tasks (in order)

1. The fixed #0040 switch in the cpc / cpcmin / cpcfw start code; `CallBank` on it.
2. Text buffer class (80 x 25, drawn in mode 2).
3. The bank image and far call.
4. Harness: the hypervisor with tasks in banks.
5. The bank context switch: interrupt save in the bank, resume task n; two banks counting.
6. Hypervisor Ticks in BASIC: the tasks as Share classes, keys and hotkeys, the front screen.
7. Far call dispatcher and services (console, keys, ticks, exit, driver lookup).
8. cyb platform: `ntc_plat_cyb.asm`, `lib/cyb`, compiler / GUI entries.
9. A "hello" program in a bank.
10. File service and bank loader (queued, firmware per call).
11. The CLI: cls, load, save, disc, tape, cd, run.
12. Driver registry and one proxy class / driver.
13. Tests (8 tasks in the harness; one on the real-ROM emulator) and docs.

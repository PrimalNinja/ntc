# The Commodore 64 with an REU (`c64reu`)

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

**Status (2026-11-26): first build.** NTC BASIC for a
stock C64 that has a RAM Expansion Unit. The compiled program - the thread - does not live in
the C64's memory. It lives in the REU and comes to the 6502 64 bytes at a time. The C64's own
64K is left for the keyword library, variables, arrays, the screen, and anything the program
wants to put there.

Section 12 lists what is not done.

## 1. Why the REU

- NTC's rule is that the stack pointer is the instruction pointer: `rts` fetches the next
  keyword, `pla` takes its arguments.
- A 6502's stack pointer is 8 bits and stuck in page 1. So a 6502 can only ever "see" 256
  bytes of thread. The MEGA65's 45GS02 gets round that with a 16 bit SP. A plain 6502 cannot.
- The REU moves memory at one byte a cycle, to any address, any length. So the thread stays
  in the REU and the REU brings the part being run into page 1. The 6502 never leaves page 1
  for its program.

What that gives:

- The program is not in the C64's memory, so its size is not limited by it: a thread of up to
  65,024 bytes (about 12,000 keywords) beside up to 51K in the C64 (section 9) - and with
  `Option Lot` as many more lots of 64K of code as the REU holds (section 13).
- A place in the program is two bytes. A task is a place in the program. So a task switch is
  saving two bytes and loading two others. Section 6.
- The same REU holds the program's data: screens, sprite shapes, maps, music. Section 5.

What it costs:

- An REU is needed. Without one the program says so and goes back to BASIC.
- It is threaded code on a 1 MHz 6502: about 6 times C64 BASIC, well under hand written 6502.
  Section 11 has timings.
- The 6502 stops during every REU transfer (64 cycles for a piece of thread).

## 2. How the thread runs: three windows

Page 1 is cut in four:

| Addresses | What |
|---|---|
| `$0100-$013F` | window 0: 64 bytes of thread |
| `$0140-$017F` | window 1 |
| `$0180-$01BF` | window 2 |
| `$01C0-$01FF` | the real stack: the library's `jsr` calls, interrupts |

- The thread is cut into **pieces** of 64 bytes. A piece is always at an address that is a
  multiple of 64.
- A window holds one piece. SP runs through the window in use.
- The compiler ends every piece with a keyword, `kw_wnext`, that goes on to the next piece. It
  never cuts a keyword from its arguments: if the next keyword will not fit, the piece ends
  early and the gap is left empty. (The gap is in the REU. It costs nothing that matters.)
- A branch, a call or a return goes to a thread position. Three cases:
  - the position is in the window in use: SP is set. About 40 cycles, no REU.
  - it is in one of the other two windows: that window becomes the one in use. About 100
    cycles, no REU.
  - it is in none: its piece is fetched from the REU into the window used longest ago. About
    180 cycles (64 of them the REU's).

So the three windows work as a small cache. A loop of up to three pieces goes round without the
REU being asked at all. So does a loop and a Sub it calls, or two tasks taking turns.

The compiler helps: a loop or a small Sub that fits one piece but would straddle two is moved
to start a new piece. The build output says how it came out:

```
; Loops and Subs: 11 in one piece, 0 over more than one (three pieces at a time are in the windows)
```

### Interrupts

The frame's interrupt is on all the time (it counts `Ticks`). An interrupt pushes three bytes
below SP. When SP is in a window those bytes land on thread words already used - harmless,
unless the program branches back to them. So the interrupt sets a flag when SP was in a
window, and the next branch then fetches its piece again instead of trusting the window.
That is one or two extra fetches a frame.

### The parts, in the source

- `src/asm/ntc_lib_m65.asm` - the 6502 keyword library. It is the MEGA65's: the two CPUs
  share it. The C64's parts are inside `ifd NTC_C64`: `ntc_goxy` (go to a position),
  `kw_wnext`, the software multiply. The header's "THE WINDOWS" says how it works.
- `src/asm/ntc_plat_c64reu.asm` - the start code, the interrupt, the console, the keyboard,
  the REU transfers, tasks, the disc reader.
- `src/js/ntc_compiler.js` - `;@cpu 6502` in a platform file turns the window path on
  (`blnWin`): `winLayout` cuts the thread into pieces and moves it to the end of the program.
- `src/lib/c64reu/*.cls` - the classes.

The MEGA65's output is byte for byte what it was before this was added (checked on 13 test
programs).

## 3. What a program is, and memory

- `GAME.PRG`, loaded at `$0801`: `LOAD "GAME",8` and `RUN`. A one line BASIC stub, then the
  program.
- The thread is the last part of the file. The start code sends it to the REU (one transfer)
  and that memory then becomes the arrays'.
- The start code then takes the machine: all RAM, I/O at `$D000`, no BASIC, no KERNAL. Its own
  screen and font. The KERNAL's own memory is left as it was, so the `Disk` class can bring the
  KERNAL back for a file.
- `End` stops and leaves the screen up. A frame hook's music carries on.

| Addresses | What |
|---|---|
| `$0002-$004F` | the library's registers |
| `$0050-$006F` | the platform's |
| `$0070-$008D` | the windows', the multiply's |
| `$008E-$008F` | the lots' (which lot is running, whose workspace is in) |
| `$0062-$006F`, `$00FB-$00FE` | free for a program's `#asm` |
| `$0090-$00FF` | the KERNAL's own, left alone |
| `$0100-$01FF` | the three windows and the real stack (section 2) |
| `$0200-$03FF` | the KERNAL's own, left alone (`$0340-$03BF` is used while a file loads) |
| `$0400-$07FF` | free |
| `$0801-$CFFF` | the program: code, variables, strings, the library, then its arrays. With `Option Lot` the top of it is the running lot's workspace (section 13) |
| `$D000-$DFFF` | I/O: VIC, SID, colour RAM `$D800`, CIAs, the REU at `$DF00` |
| `$E000-$E3E7` | the screen: 40 x 25 characters, ASCII (`$E3F8-$E3FF`: the sprites' shapes) |
| `$E400-$E7FF` | sprite shapes 0-15 |
| `$E800-$EFFF` | the font: characters 0-255, 8 bytes each (NTC's own for 32-126) |
| `$F000-$FFBF` | sprite shapes 16-78 (free if not used) |
| `$FFFA-$FFFF` | the NMI, reset and IRQ vectors |

The REU:

| Where | What |
|---|---|
| bank 0, `$0100` up | the thread |
| bank 0, `$FF00-$FFFF` | NTC's notes: the `Task` class's start threads, a `--split` build's mark |
| banks 1 on | the program's, for anything (the `Reu` class) |

With `Option Lot` the REU is laid out differently: section 13.

## 4. The console, keys, joysticks

- 40 x 25, NTC's own font, so the text is ASCII: lower case, `{ } | \ ~` and all.
  `Print`, `Locate`, `Cls`, `Tab`, `Input`, `Inkey`, `Line Input` as on every platform.
- `StdIO.Pen c`, `StdIO.Paper c`, `StdIO.Border c`: the C64's 16 colours. Each character
  keeps the pen colour it was printed in.
- `Mode` clears the screen; there is one mode.
- `Input` / `Inkey` read the keyboard matrix when asked. RETURN 13, DEL 8, RUN/STOP 27, the
  cursor keys `&HF0` up, `&HF1` down, `&HF2` left, `&HF3` right. Letters are lower case, capitals
  with SHIFT. The shifted digits give `! " # $ % & ' ( )`. Signs the C64's keyboard has no key
  for: SHIFT `+` is `{`, SHIFT `-` is `}`, SHIFT `:` is `[`, SHIFT `;` is `]`, the pound key is
  `\` (shifted `|`), the up arrow is `^` (shifted `~`), the left arrow is `_`, SHIFT `@` is a
  backquote. No auto repeat.
- `Keys.Down(key)`: True while a key is held. `Keys.KeyQ`, `KeyA`, `KeyO`, `KeyP`, `KeySpace`,
  `KeyZ`, `KeyW`, `KeyS`, `KeyX`, `KeyEnter`, `KeyStop`, `KeyShift`, the F keys and more.
- `Joy.Read(2)` and `Joy.Read(1)`: `Joy.Up` 1, `Down` 2, `Left` 4, `Right` 8, `Fire` 16.
  A joystick in port 2 shares lines with the keyboard, as on any C64: while it is held some
  keys read wrongly.
- `Frame` waits for the next frame. `Ticks` counts frames (50 a second on a PAL machine).
- `System.FrameHook addr`: machine code called every frame from the interrupt - a music
  player's "play" routine. It carries on whatever the program is doing, a file load apart.

## 5. The REU as the program's own memory: the `Reu` class

A place in the REU is a bank (0-255) and an address in it (`&H0000`-`&HFFFF`).

| Member | What |
|---|---|
| `Reu.Banks()` | how many 64K banks there are (2 on a 1700, 8 on a 1750, up to 256). Nothing in the REU is changed by asking. It uses `$0400-$04FF` while it works. |
| `Reu.Size()` | the same in K |
| `Reu.Stash bank, addr, mem, bytes` | the C64's memory at `mem` into the REU |
| `Reu.Fetch bank, addr, mem, bytes` | out of the REU into the C64's memory |
| `Reu.Swap bank, addr, mem, bytes` | the two exchanged |
| `Reu.FetchRect bank, addr, pitch, mem, mempitch, width, rows` | a block of rows: a piece of a big map onto the screen, a picture, part of a sheet |
| `Reu.StashRect ...` | the same, into the REU |
| `Reu.Fill bank, addr, value, bytes` | REU memory set to a value |
| `Reu.MemFill mem, value, bytes` | the C64's memory set to a value by the REU |
| `Reu.Peek`, `Poke`, `Deek`, `Doke` | one byte or word |

What the speed means in practice (a frame is about 19,650 cycles):

- a whole text screen, 1,000 bytes: 1,000 cycles, a twentieth of a frame
- a screen and its colours: a tenth of a frame, so a new whole screen every frame is easy
- a sprite shape: 64 cycles
- a 6502 copy loop manages about 13,000 cycles for that same screen

Each call from BASIC has its own cost on top, about 400 cycles: taking the arguments and
setting the REU's registers. For many small transfers use `FetchRect`, which does the rows in
machine code: about 125 cycles a row and a cycle a byte, so 40 x 25 is 3,150.

A transfer stops the 6502 until it is done, and the frame's interrupt waits. Keep a transfer
under a few thousand bytes when music is playing from the frame hook.

## 6. Tasks: the `Task` class

```
Sub Blink()
    Do
        Poke &HD020, Peek(&HD020) Xor 1
        Task.Sleep 25
    Loop
End Sub

Task.Start AddressOf Blink
Do
    ' the main program
    Task.Yield
Loop
```

- Up to 32 tasks. The main program is task 0.
- `Task.Start(AddressOf TheSub)` gives the new task's number, or -1.
- `Task.Yield`: the others get a turn. `Task.Sleep frames`: this one waits, the others run.
- `Task.Id()`, `Task.Count()`, `Task.Stop n`. A task ends when its Sub ends.
- A task is its place in the thread and nothing else. A change of task is about 200 cycles
  when the other task's piece is in a window, about 300 when it has to be fetched.

Tasks take turns only at `Yield` and `Sleep`. Nothing changes under a task between two of its
own. That is on purpose, and it is also a limit that comes from NTC BASIC itself:

- A Sub's locals and parameters are one set, not one for each task. Two tasks may run the same
  Sub, but each must keep what it needs across a `Yield` in an array indexed by `Task.Id()`.
  `bas/c64_tasks` does exactly that with 20 tasks on one Sub.
- For the same reason only one task at a time should be inside a Sub that yields.
- `Gosub`'s return stack is shared: no `Yield` between a `Gosub` and its `Return`.

## 7. Sprites, characters, sound: `Vic` and `Sid`

`Vic`:

- `Vic.Sprite n, x, y` puts sprite n (0-7) there and turns it on. `Vic.Hide n`, `Vic.HideAll`.
- `Vic.Shape n, s`: sprite n shows shape s (0-78). `Vic.ShapeAddr(s)` is where shape s's 64
  bytes are: `Poke` them, or `Reu.Fetch` them from the REU.
- `Vic.Colour`, `Vic.Multi`, `Vic.MultiColours`, `Vic.Expand`, `Vic.Behind`.
- `Vic.Hit()`, `Vic.HitText()`: the collision registers. `Vic.Bit(n)`: sprite n's bit.
- `Vic.CharAddr(c)`: where character c's 8 bytes are. 0-31 and 128-255 are free for a
  program's own characters.
- `Vic.Scroll x, y`: the whole text screen moved left by x pixels and up by y (0-7 each), with
  38 columns and 24 rows showing so the edge coming in is out of sight. `Vic.ScrollOff`.
- `Vic.MultiText onoff, c1, c2`: multicolour text - characters printed in colours 8-15 are 4 x 8
  double width pixels in four colours.
- `Vic.Raster()`, `Vic.Border`, `Vic.Paper`.

### Scrolling a big map by the pixel

`bas/c64_dungeon` does it. The map is kept in the REU as characters, laid out as the screen
wants them, with its colours as a second map. Then:

- every frame: `Vic.Scroll` with the low 3 bits of the view's position
- every 8th pixel: the whole 40 x 25 view again from the two maps, `Reu.FetchRect` twice. That
  is about 6,300 cycles, 100 raster lines. Done straight after `Frame` it is finished while
  the border is being drawn, before the screen's first row is shown.

No shifting of the screen and no edge column to paint. In the sample a tile is 16 x 16 pixels
(2 x 2 multicolour characters), the level is 128 x 128 tiles - about 70 screens - and it
moves 2 or 4 pixels a frame, 50 frames a second, with the loop in BASIC.

`Sid`: `Sid.Volume v`, `Sid.Voice v, wave, attack, decay, sustain, release`, `Sid.Tone v, hz`,
`Sid.Note v, value`, `Sid.Off v`, `Sid.Quiet`. Waves: `Sid.Triangle`, `Saw`, `Pulse`, `Noise`.

## 8. Files into the REU: the `Disk` class

```
n = Disk.LoadReu("SHAPES", 1, 0)      ' the file SHAPES into bank 1 from address 0
If n = 0 Then Print "SHAPES is not on the disc"
```

- The whole file goes into the REU, not into the C64's memory. It can be bigger than 64K: it
  carries on into the next bank.
- The answer is the number of 128 byte blocks read (0: no such file). `Disk.LastBytes()` is
  how many bytes the last block had.
- The KERNAL does the reading, from the drive the program was loaded from. So it works with
  whatever `LOAD` works with: a 1541, an SD card drive, an Ultimate's drive.
- While it reads, the frame's interrupt is off: `Ticks` stand still and a frame hook stops.
- File names in capitals, 16 characters at most.
- A real 1541 gives about 400 bytes a second.

## 9. Building, and programs bigger than a PRG

```
node test/c64build.js Main.bas [More.cls ...] --out=GAME.PRG
```

- Needs node and vasm (`vasm6502_oldstyle`: http://sun.hasenbraten.de/vasm/, `make CPU=6502
  SYNTAX=oldstyle`). `NTC_VASM65` or `--vasm=` give its path.
- Writes `GAME.PRG` and `GAME.s`. It says what stays in the C64 and what goes to the REU.
- `--d64`: also `GAME.D64`, a 1541 disc with the program first. `--add=FILE` puts a data file
  on it too (for `Disk.LoadReu`).
- `--list`: vasm's listing. `--log`: a test build (section 10).
- Without the tool: pick `c64reu` in the web IDE (or `cli.js --platform=c64reu`), assemble
  with `vasm6502_oldstyle -opt-branch -Fbin`, and put the two bytes `01 08` in front.
- In a program: `#If NTC_C64REU Then` ... `#End If` for lines only this platform gets.

A PRG has to load below `$D000`: 51,199 bytes for everything. Past that:

```
node test/c64build.js Main.bas --out=GAME.PRG --split --d64
```

- `--split` puts the thread in a file of its own, `GAME.0`. The PRG then holds only what stays
  in the C64. The thread can be up to 65,024 bytes.
- When the program starts it reads `GAME.0` into the REU through the KERNAL
  ("LOADING THE PROGRAM INTO THE REU"), then carries on as usual.
- `--reu` also writes `GAME.REU`: the REU's first 64K with the thread already in it. A machine
  that loads that into its REU first (an Ultimate, an emulator) starts the program at once:
  the program finds its own mark in the REU and reads nothing from disc. The same happens when
  a program is run a second time without the REU being cleared.

The tests build one program this way that is 78K in all: 15.7K in the C64 and a 62K thread.

Past a 65K thread: `Option Lot`, section 13. With lots a `--split` build writes more files:
`GAME.0` is the kernel's thread, then two for each lot (its thread, its workspace).

## 10. Testing on the emulator

```
python3 test/c64run.py GAME.PRG --log --untilend
python3 test/c64run.py GAME.D64 --frames=3000 --keys=+50:hello\n --shot=out.png --screen
```

- The emulator is the VICE x64sc libretro core: `git clone https://github.com/libretro/vice-libretro`,
  `make EMUTYPE=x64sc`, and `NTC_C64CORE` set to the `.so`.
- `c64run.py` starts a PAL C64 with a 512K REU (`--reu=128kB` ... `16384kB`, `none`), loads and
  runs the PRG or the disc's first program, types keys (`--keys`), holds a key (`--hold`) or
  the joystick (`--joy`), saves the picture (`--shot`), prints the screen (`--screen`) and a
  `--log` build's text.
- A frame number written `+n` is n frames after the program started.
- A `--log` build keeps what the console prints in `$F000-$F7FF` as well, for `c64run.py --log`.
  Sprite shapes 16-47 are in the same memory: a program that uses them should not be built
  with `--log`.
- `bash test/c64regress.sh` runs 63 checks: the language self tests (the same ones the MEGA65
  runs, 163 + 256 checks), typed input, keys, held keys, the joystick, the `Reu` class on
  128K to 16 MB, no REU at all, tasks, sprites, a disc file into the REU, a `--split` build
  from disc, a 78K program, the samples building, and a stress test: a loop too long for the
  windows with a frame hook pushing 20 bytes every frame, 6,400 frames, sums checked. And lots:
  two lots with their own variables, lot to lot calls, 256K and 512K, an REU too small, a
  `--split` build from disc, a task running inside a lot, the calls a lot refuses, and a 120K program in two lots whose code is in two REU banks each.

## 11. Timings

From `test/c64/Bench.bas`, PAL, in frames (50 a second):

| What | Frames | Each, in cycles |
|---|---|---|
| empty `For` loop x 10,000 | 78 | 153 |
| `k = k + i` x 10,000 | 50 more | 98 |
| `k = i * 7` x 2,000 | 34 more | 330 |
| `k = i \ 7` x 2,000 | 103 more | 1,010 |
| `a(i) = i` x 5,050 | 33 more | 128 |
| a Sub call and back x 2,000 | 37 more | 360 |
| an `If ... Else` with a compare x 2,000 | 23 more | 230 |
| printing a full line, scrolling, x 40 | 50 | 24,500 |

- C64 BASIC's empty `For` loop is about 1,000 cycles a pass.
- Multiply and divide are plain shift and add loops. A table driven multiply would be
  several times quicker and is an easy thing to add.
- Scrolling the screen is a 6502 loop. The REU could do it in a tenth of the time.

## 12. Not done

- **NTSC.** Written to work (the interrupt is on a raster line both have); NTC's tests are PAL.
- **The `--reu` image.** Written and its mark checked by the program; NTC's tests do not load
  one into an REU before the start.
- **The `Interrupt` statement and interrupt classes** are not on this platform. Machine code
  goes on the frame hook.
- **Tasks are not preemptive.** Section 6 says why.
- **A lot's Sub called from outside its lot** takes no parameters and gives no result
  (section 13).
- **A lot's strings and stubs** come in with its workspace every time the lot is entered.
  Text that never changes could stay in the REU and be fetched when used; not done.
- **Files**: reading into the REU only. No writing, no `FileSystem` class.
- **Bitmap graphics**: no class. The VIC is the program's to `Poke`.
- **A C64 without an REU** is a different target (a different way of threading). Not done.

## 13. Lots: `Option Lot`

A program bigger than one 64K thread is cut into lots.

```
Option Lot Front  = Title
Option Lot First  = Stage1, Stage1Maps
Option Lot Second = Stage2
```

The REU past the kernel's first 32K is lots of 96K, one after another. A 512K REU has 5, a
2 MB one 21, 16 MB 174 (`System.Lots()` says how many the machine has).

- **A code lot** - one named by an `Option Lot` line, in the order of the lines: lot 1, lot 2
  ... - is the classes listed. 64K of it is their compiled code. 32K is their **workspace**:
  their variables, their strings and the small call stubs of their Subs.
- **Any other lot** is 96K of data, the program's to use: `Reu.LotBank(n)` and `Reu.LotAddr(n)`
  give where lot n starts, for the `Reu` and `Disk` classes.
- **The kernel** is everything in no lot: the main program and the classes no `Option Lot`
  line names. Its thread is in the REU's first 32K (32,256 bytes at most). Its variables,
  strings and stubs are in the C64's memory all the time.

### How it runs

- A lot's code is fetched into the windows a piece at a time, like any thread. Each window
  knows which lot its piece is from, so pieces of the kernel and of a lot sit side by side.
- A lot's workspace is in the C64's memory only while that lot is the one running, at one
  fixed place at the top of the program's memory (ending at `$CFFF`). Its size is the biggest
  lot's, worked out by the build.
- Going into a lot from outside it brings its workspace in from the REU. If another lot's was
  there, that one's variables go back to the REU first. Coming back does the reverse.
- So a lot's variables are still as it left them the next time it is entered.

What a call costs:

| Call | Cost |
|---|---|
| inside a lot, or inside the kernel | as before |
| from a lot to a kernel Sub and back | about 150 cycles more (the windows are looked over again each way); nothing is moved |
| into a lot from the kernel | the lot's workspace fetched, a cycle a byte; leaving, its variables put back, a cycle a byte of those |
| from one lot to another | both: the first lot's variables out, the second's workspace in, and the reverse coming back |

A lot with 2K of workspace costs about 2,500 cycles to enter - an eighth of a frame - and less
to leave. So a lot is for something entered and stayed in: a stage, the
title screen, a shop, a mini-game. What everything calls all the time goes in the kernel.

### The rules

- **A lot's Sub that is called from outside the lot takes no parameters and gives no result.**
  The caller's variables and the lot's are in the same memory at different times. What they
  share goes through a class in no lot (in `bas/c64_lots` that is `Game`). The compiler says
  which Sub breaks this.
- **Inside a lot anything goes**: its own Subs and Functions with parameters, calls to the
  kernel's with parameters, strings.
- **Nothing outside a lot can use the lot's variables**, only call its Subs. The compiler says
  where that is tried.
- **A class is in one lot.** A class two lots both need goes in the kernel.
- **Arrays** are not in the workspace: every class's arrays are in the C64's memory all the
  time, as before. Big tables belong in the REU, in a data lot.
- **`AddressOf` a lot's Sub** gives its entry, so a task can be started on it
  (`Task.Start(AddressOf Worker.Go)`). A task remembers which lot it was in and whose
  workspace it had; both are put back at its turn, so two tasks in two lots swap workspaces
  at every `Yield`.
- `Option Lot` is this platform's. On the other platforms the line is passed over and the
  classes are built as usual.

### Sizes and what the build says

```
GAME.PRG: 8269 bytes ($0801-$284B): 6537 stay in the C64, 1674 go to the REU
  the kernel's thread: 512 bytes (8 pieces) -> REU $000100
  lot 1 (Front), thread: 128 bytes (2 pieces) -> REU $008100
  lot 1 (Front), workspace: 278 bytes -> REU $018000
  lot 2 (First), thread: 256 bytes (4 pieces) -> REU $020100
  ...
  the running lot's workspace is at $CE00-$CFFF in the C64; the REU must be 512K or more for 3 lots
```

- A lot's thread: 65,280 bytes at most. Its workspace: 32,768. The kernel's thread: 32,256.
- Lot n starts at REU address `$8000 + (n - 1) * $18000`: its thread from `$0100` into it, its
  workspace 64K into it.
- A program checks the REU is big enough for its code lots when it starts, and says
  "THIS PROGRAM NEEDS A BIGGER REU" if not. Data lots it must check itself (`System.Lots()`).
- NTC's own notes in the REU (the `Task` class's start threads, a `--split` build's mark)
  are in the kernel's 32K when there are lots: `$7F00-$7FFF`.

### In the source

- `scanLots` and `winLayout` in `src/js/ntc_compiler.js`: the `Option Lot` lines, then each
  lot's threads, stubs, variables and strings sorted out of the compiled program by their
  names (`p_<class>_...`, `var_<class>_...`). A string is a lot's when only that lot uses it.
- A lot's Sub called from outside gets an entry in the kernel (`p_name_e`) and a start thread
  in the lot (`p_name_t`).
- `ntc_lots` in `src/asm/ntc_plat_c64reu.asm`: `ntc_lot_enter`, `ntc_lot_ret`, `ntc_ws_set`.
- A kernel Sub's stub keeps the caller's lot and puts it back (`NTC_LOTIN`, `NTC_LOTOUT`).

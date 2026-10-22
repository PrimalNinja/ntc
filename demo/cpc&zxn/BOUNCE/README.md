# BOUNCE - portable graphics on CyborgOS (Amstrad CPC and ZX Spectrum Next)

A small demo for anyone writing games for CyborgOS: balls bouncing round the screen, written in
NTC BASIC, built once into **one `.CYB` file that runs on both machines** - hardware sprites on
the Next, a compiled sprite on two flipped screens on the CPC - and that shares the machine
with the other slots like any CyborgOS program: go to another slot and back and it carries on.

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

```
BOUNCE        8 balls          BOUNCE 3      3 balls          Q quits
```

Run it in any slot (`RUN 2 BOUNCE`, then Shift + 2 on the Next / Control + 2 on the CPC).

## The files

| File | What |
|---|---|
| `BOUNCE.bas` | the game: the balls, the walls, the frame timing, the keys, the front / back rule. Written once |
| `ZxnScr.cls` | the screen on the Next: sprites over the console |
| `CpcScr.cls` | the screen on the CPC: two screens in main RAM, flipped; the RAM settings |
| `BallGfx.cls` | the ball, made by `tools/mkball.py`: the Next's sprite pattern, the CPC's compiled sprite. Don't edit it - run the tool |
| `gfx/ball.png` | the ball's picture, 16 x 16 (the tool draws one if it isn't there) |
| `tools/mkball.py` | `gfx/ball.png` -> `BallGfx.cls` |
| `build.sh` | builds `build/BOUNCE.CYB` |
| `test/` | the tests used: the Next in nextemu (`cosbot.py`), the CPC in NTC's harness (`cpctest.sh`, `shotm2.py`) |

## Build

    bash build.sh <NTC src folder>

`build/BOUNCE.CYB` is the program for both machines: copy it to the CPC's disc or the Next's SD
card next to CyborgOS's commands, or to a folder and `CD` to it first.

The command line underneath (what `build.sh` does):

    python3 tools/mkball.py
    node <NTC>/test/cli.js BOUNCE.bas ZxnScr.cls CpcScr.cls BallGfx.cls --platform=cyborgos --name=BOUNCE > build/BOUNCE.ASM
    cd build && sjasmplus BOUNCE.ASM          (writes BOUNCE.CYB)

## 1. One program, two machines

NTC's `cyborgos` platform makes a CP/M program (a slot is CP/M 2.2) with an AMSDOS header: the
`.CYB`. CyborgOS loads the same file on the CPC and on the Next. Text, keys, files and the
hypervisor's services (`CybSys`) are the same on both. **The graphics are not**: there is no
common screen hardware, so a portable game has

- the game once, in BASIC, calling a screen layer: `Init`, `Enter`, `Leave`, `Ball`, `Show`, `Done`;
- one class per machine with those Subs;
- a choice **when it runs**:

```basic
host = CybSys.Host()          ' 0 the CPC, 1 the Next (255: not CyborgOS) - BDOS 131 op 20, 5
If host = 1 Then ZxnScr.Init Else CpcScr.Init()
...
If host = 1 Then ZxnScr.Ball i, x, y Else CpcScr.Ball i, x, y
```

Not `System.Platform` or `#If`: NTC's System values are fixed when the program is compiled, and
it's compiled once for both. Ask before touching any hardware: the Next's NextReg port (#243B)
is the CPC's PPI, and the CPC's CRTC port (#BCxx) is something else on the Next.

The game works in its own coordinates (320 x 200 here) and each screen class maps them to its
machine (the Next: y + 28 to centre 200 lines in its 256; the CPC: a byte is 4 of those pixels).

**Why `.CYB` and not `.COM`.** A plain CP/M only loads `.COM` files, so it never starts a `.CYB`.
That's the protection for a program that uses CyborgOS's own calls: on CP/M 2.2 an unknown BDOS
function such as 131 comes back as 0, so `CybSys.Host()` would answer 0 ("a CPC") and BOUNCE
would start switching the gate array's RAM settings under a system with no slots - and crash.
The `host = 255` check only covers what answers 255. So:

- **`.CYB`** - anything that calls `CybSys` (BDOS 131) or drives the screen hardware as BOUNCE does;
- **`.COM`** - only a program that uses nothing past CP/M 2.2's own BDOS calls (CyborgOS runs
  those too).

## 2. Sharing the screen: only while in front

Every slot keeps running behind the one on the screen, so a program that draws must stop
drawing when its slot isn't the one shown, give the screen back the way it found it, and take
it again when it's back. That's all in `BOUNCE.bas`'s `WaitFrame`:

```basic
Sub WaitFrame()
  Do
    CybSys.Bdos 12, 0                       ' Yield: BDOS 12 ends this slot's turn
    If Front() Then                         ' BDOS 131 op 0: is this slot the one shown?
      If shown = 0 Then Enter : shown = 1   ' back in front: set the screen up again
      If CybSys.Clock() - last >= 6 Then Exit Do      ' 1/50 s gone (the clock: 300 a second)
    ElseIf shown Then
      Leave : shown = 0                     ' gone behind: the screen given back
    End If
  Loop
  last = CybSys.Clock()
End Sub
```

- **Yield.** A program built with `Option Turbo` runs with interrupts off, and CyborgOS only gets
  the CPU back when the program calls the BDOS. So it gives it away itself, every frame (any
  BDOS call below 13 ends the slot's turn). The other slots run inside that call.
- **Front.** After each Yield it asks. The slot's number comes from its own status strip text,
  `[2] ` at #F68A in its bank (`MySlot`).
- **Leave / Enter.** What each machine needs is below. Nothing is drawn while it's behind; the
  balls wait where they were (the game doesn't move on while it's away - a game that should
  keep playing would still run its logic there, and only skip the drawing).
- **Keys.** CyborgOS puts a key in the slot's KEY byte (#F681) only while it's in front, so
  `If Peek(&HF681) <> 0 Then k = Inkey` never sees another slot's typing. Don't scan the
  keyboard hardware: it's the whole machine's.
- **Text.** `Print` goes to the slot's console as always (on the Next the balls fly over it).
  On the CPC, while the game is in front, the console's screen *is* one of the game's two
  screens - so it prints nothing between Enter and Done.

## 3. The Next: sprites over the console

`ZxnScr.cls`. CyborgOS-Next's console is the tilemap. The game leaves it alone and puts the balls
in hardware sprites on top of it, so the only thing that differs between "in front" and
"behind" is one NextReg, #15 (the layers):

```basic
Public Sub Init()  : con15 = RegGet(&H15) : BallGfx.ZxnLoad : End Sub   ' the console's value noted
Public Sub Enter() : Reg &H15, (con15 And &HFC) Or 3 : End Sub          ' sprites on, over the border
Public Sub Leave() : Reg &H15, con15 : End Sub                           ' the console's back
```

A ball is a sprite: port #303B picks the sprite, four bytes to port #57 set it (x, y, the 9th
bit of x, shown + pattern 0). `BallGfx.ZxnLoad` puts the pattern into the sprite RAM (port
#303B then 256 bytes to #5B) and sets the sprite palette entries it uses (an 8 bit pattern's
colour is its RRRGGGBB value: each entry is set to itself, and the palette control #43 is put
back as it was).

**Two sprite games at once.** The sprite RAM and the sprite palette are one set for the whole
Next and can't be read back. BOUNCE loads its pattern once, which is fine while it's the only
sprite program. A second one would overwrite it: then each game loads its patterns and palette
again in `Enter`, and hides its sprites in `Leave` (16K to port #5B is a fraction of a frame at
28MHz). The same goes for a game that uses its own tilemap or Layer 2: note the registers the
console uses (#6B, #6C, #6E, #6F, #12, #70, #14, #4A, #4C, #43, #40, the layer order #15,
#68, #69, the scroll registers) in `Init`, put the game's in on `Enter` and the console's back on
`Leave`, and keep the game's pictures in its own memory (bank 5's first page, or Layer 2 in
pages from the store - BDOS 131 op 12). THE LITTLE SEOUL ENGINE and RATBOXN do it that way
(their `Nx.cls`: `Snap`, `Back`, `ConSave`).

## 4. The CPC: two screens in main RAM

`CpcScr.cls`. The CPC can't put the screen just anywhere: the gate array shows 16K of **main
RAM**. CyborgOS keeps two 16K pages there for screens: #C000 (the console's) and #4000 (free -
for double buffering). While a game is in front both are its own: it draws on one while the
other is shown, then flips the CRTC to it (R12 = #10 shows #4000, #30 shows #C000; the CRTC
takes R12 / R13 at its next frame, so the game waits a frame before drawing on the old one -
`WaitFrame` does).

### Reaching main RAM from a slot

A slot runs with RAM setting C2: its own 64K bank in all four 16K places, so main RAM isn't
there at all. To draw, the game switches the gate array's RAM setting for a moment:

| Setting | #0000 | #4000 | #8000 | #C000 |
|---|---|---|---|---|
| C2 (the slot's own) | bank page 4 | bank page 5 | bank page 6 | bank page 7 |
| C1 | main 0 | **main 1 (the #4000 screen)** | main 2 | bank page 7 |
| C3 | main 0 | **main 3 (the #C000 screen)** | main 2 | bank page 7 |

C1 and C3 both put a screen at **#4000-#7FFF** and keep the slot's own **page 7** at #C000. So:

- the drawing code lives in page 7 - it's copied to #E000 (`CpcScr`'s routines) and #E200
  (the compiled ball) at the start, below the stub at #EF00;
- it draws through the same window whichever screen it is (C1 for one, C3 for the other), so
  one copy of the code serves both;
- while C1 / C3 is in, **nothing may touch the stack** (it's in the program: main RAM then) and
  **interrupts stay off** (#0038 is main RAM's): a turbo program runs with them off, and the
  routines at #E000 / #E200 push and call nothing;
- each routine switches the window in at its start and the slot's own setting back at its end.

The slot's own setting (port #7F..#78 in B, the C2 value in C) is what CyborgOS loads into BC
when it switches into the bank (`Hyp.Run`: `ld bc, (setting)`, `out (c), c`), and the BDOS stub
hands BC back to the caller as it is. So `CpcScr.Init` makes one BDOS call and keeps BC:

```
            ld c, 12
            ei
            call 5
            di
            ld ({own}), bc         ; B = #7F..#78, C = #C2 + bank * 8
```

It checks it looks like a C2 setting and stops ("this slot's RAM setting not found") if not.
This isn't a documented BDOS answer yet - a CyborgOS op that gives it would be the proper way.

### What the game may change and what it may not

- **The CRTC is the game's** while it's in front (R12 / R13 here; a game could set its own
  sizes, R1 / R2 / R6 / R7, too). It can't be read back, but it doesn't need to be: when another
  slot comes to the front, CyborgOS sets the CRTC for that slot's console and redraws #C000
  itself (`ToFront`: `Hyp.Scr`, `Hyp.Show`). So `Leave` has nothing to do on the CPC.
- **The mode and the inks are the console's.** CyborgOS's firmware sets the gate array's mode
  and inks again itself (its interrupts run between the slots' turns), so a game can't keep
  its own: it draws in the console's mode 2 (640 x 200, 2 colours) in the console's colours.
  Colour games (mode 0 / 1, their own inks) need CyborgOS to hold the front slot's mode and inks
  for it - not there yet.
- **The slot's MODE.** `Init` sets the slot's console to MODE 2 (BDOS 131 op 9, 0: 80 x 25, no
  status strip), so the console's layout is the screens' (80 bytes a line) and CyborgOS's own
  writes to #C000 (the cursor) land inside the console's 80 x 25. `Done` puts the old MODE back,
  which also sets the CRTC and #C000 back for the console.
- **Text on the screens** comes from the slot's own font (#F300 in page 7, seen in C1 / C3 too):
  `CpcScr.Text` copies a character's 8 bytes a line apart (#800).

### The compiled sprite

`tools/mkball.py` turns `gfx/ball.png` into Z80 code that writes the ball's bytes straight into
the screen - no loop, no sprite data read, no masks:

```
            ld bc, (cs_win)        ; the back screen into the window
            out (c), c
            ld bc, #FF00           ; B = all ink, C = all paper: the commonest bytes
            ld d, h                ; line 0 ...
            ld e, l
            ld (hl), c             ; a byte all paper: ld (hl), c  (7 T)
            inc hl
            ld (hl), #3F           ; a byte part ink:  ld (hl), n  (10 T)
            ...
            ex de, hl              ; back to the line's start
            ld a, h                ; the next pixel line: #800 on; past a character row's 8th
            add a, 8               ;   line, back #4000 and on #50 (80 bytes)
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ...
            ld bc, (cs_own)        ; the slot's own bank back
            out (c), c
            ret
```

It's **plain + border**: nothing is ever behind the balls (the screen is paper), so there's no
mask, and the ball is drawn with a border of paper round it as wide as it moves in two frames
(2 bytes each side, 4 lines above and below - two frames because each screen last saw it two
frames ago). Drawing it in its new place wipes where it was, so nothing is cleared each frame.
Where two balls cross, the later one's border cuts into the other for a frame - the price of
no masks. A game with a background would use masked bytes (`ld a, (hl) : and m : or d : ld
(hl), a`) where the sprite is part see-through, and keep plain stores where it's solid.

## 5. Checklist for your own game

1. The game once, the screen behind a few Subs; `CybSys.Host()` picks the class at run time.
2. Yield every frame (BDOS 12), ask `Front` after each Yield.
3. Behind: draw nothing, give back what you changed (the Next: the registers you set; the CPC:
   nothing - CyborgOS resets the CRTC and #C000 itself).
4. In front again: set your screen up again, redraw (or restore) a whole frame.
5. Keys from the slot's KEY byte (`Peek(&HF681)`, `Inkey`), never the keyboard hardware.
6. Next: shared sprite RAM / palettes / tilemap memory - reload yours in `Enter` if another
   program may use them.
7. CPC: draw from page 7 (#C000-#EEFF) through C1 / C3, no stack and no interrupts while
   you're there, mode 2 and the console's inks.
8. `Done`: put the console back before you end.

## Tested

- **The Next:** CyborgOS-Next (892a7d8c, built by its own `tools/nexarc/build.sh`) in NTC's
  emulator with nextemu's picture, the SD card a folder (`test/cosbot.py`): `CD BOUNCE`,
  `RUN 2 BOUNCE`, Shift + 2 (the balls over slot 2's console), Shift + 1 (slot 1's console, no
  balls), Shift + 2 (the balls again, carrying on), Q (the console clean, "BOUNCE: n frames").
- **The CPC:** CPC CyborgOS (the same source, `cyborgos320kb`) in NTC's harness with 4MB
  (`test/cpctest.sh`; the harness takes about 7 minutes a run): `RUN 2 BOUNCE`, Control + 2 -
  both screens drawn, the CRTC flipping between them (`screenshots/cpc_front.png`: the one shown
  on top); Control + 1 - slot 1's console on #C000, R12 back at #C000, the game's last frame left
  unseen on #4000 (`cpc_slot1.png`); Control + 2 again, Q - "BOUNCE: n frames", the console
  back in its old MODE with its status strip.
- Screenshots of the Next: `next_front.png` (slot 2, the balls over its console),
  `next_slot1.png` (slot 1: none), `next_quit.png` (after Q).

Not on real hardware yet.

## Known limits

- The CPC version is mode 2 in the console's colours (see 4).
- The CPC's cursor: CyborgOS flashes the front slot's console cursor on the screen at #C000 every
  half second, so a small mark can show in the #C000 screen at the console's cursor place (top
  left after `Init`'s MODE 2). The balls' borders wipe it when they pass; a game with a fixed
  picture there would redraw that corner, or CyborgOS could skip the cursor while a slot owns the
  screen.
- Where two balls cross, one's paper border cuts into the other for a frame (no masks: see 4).
- The CPC's own RAM setting comes from BC after a BDOS call - how CyborgOS works today, not a
  documented answer.
- `System.CommandLine` is used (the ball count) - and has to be: NTC's platform `CybSys` class
  calls it, and without a reference in the program the build stops with "unknown function or
  array: system.commandline" (an NTC linking issue).

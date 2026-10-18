# CHIP8 - a CHIP-8 interpreter in NTC BASIC

`Main.bas` is a CHIP-8 virtual machine for the Amstrad CPC, written in NTC BASIC. CHIP-8 is the
classic 1970s interpreted game machine: 4K of memory with the program at `#200`, 16 byte registers
`V0`-`VF`, the index register `I`, a 16-level call stack, two 60Hz timers, a 64 x 32 XOR display
and a 16-key hex keypad. About 35 opcodes.

## Run

It is built for CyborgOS as a `.CYB` command and run by name with the ROM to play:

```
chip8 PACMAN.CH8
```

The ROM name comes from `System.CommandLine()` (as the other CyborgOS commands read theirs); with
no name a `CHIP8.CH8` on the drive is tried, and failing that a small built-in demo runs. The file
loads at `#200`, where the program counter starts.

```
node cli.js bas/chip8/Main.bas --platform=cpm        # the .CYB build; also cpc, cpcfw, cpcmin, test
```

**Display:** text on every target for now. The 64 x 32 bitmap is kept in memory and printed as `#`
/ space by `DumpScreen` - so `VF` (collision) is read back from the kept display and the whole
interpreter is proved without a screen. The regression test runs the demo ROM on `test` and checks
the printed digits and registers against `src/test/ref/chip8.txt`.

**Graphics is deferred** until the CPC / CyborgOS screen handling is settled. The graphics path -
each CHIP-8 pixel a 4 x 4 **XOR** block in mode 1, drawn with `Graphics.Plot`/`Line` (CHIP-8's XOR
sprites are exactly the CPC's XOR drawing) with the keypad read from the keyboard - is written and
kept behind `#If GFX`, switched off everywhere for now.

## The keypad

The 16 hex keys map to the usual CPC block:

```
  CPC            CHIP-8
  1 2 3 4        1 2 3 C
  Q W E R   ->   4 5 6 D
  A S D F        7 8 9 E
  Z X C V        A 0 B F
```

ESC quits. (The key numbers are in `SetKeymap`.)

## What it covers

All the standard opcodes: `00E0` clear, `00EE` return, `1NNN` jump, `2NNN` call, `3/4/5/9` skips,
`6XNN` set, `7XNN` add, the `8XY_` register maths (`0-7`, `E` - OR/AND/XOR, add-with-carry,
sub-with-borrow, shifts, all setting `VF`), `ANNN` set I, `BNNN` jump+V0, `CXNN` random, `DXYN`
draw, `EX9E`/`EXA1` key skips, and the `FX__` group: timers (`07`/`15`/`18`), `FX0A` wait-for-key,
`FX1E` add to I, `FX29` font sprite, `FX33` BCD, `FX55`/`FX65` store/load registers. Sprites are
clipped at the right and bottom edges. `FX55`/`FX65` leave `I` unchanged (the modern convention).

The built-in demo ROM (in `LoadDemo`) draws the font digits `1 2 3`, then does an add that carries
(so `VF` = 1) and the BCD of 16, and stops in a jump-to-itself - enough to exercise the fetch /
decode / execute loop, `DXYN`, the font, the maths flags and the memory opcodes in one run.

## Notes

- NTC integers are 16-bit; the opcode is handled as its two bytes (`hi`, `lo`) so nothing overflows,
  and register maths is masked to 8 bits with `And 255`.
- The demo ROM and the font/keymap tables are held as hex strings and unpacked at start (NTC BASIC
  has no `DATA`/`READ`).
- The graphics and keypad paths compile for the CPC but can't be exercised in the headless test
  harness; the interpreter itself is covered by the regression test.
- `zxn` falls back to the console display (the ZX Next needs its own graphics path - not done yet).

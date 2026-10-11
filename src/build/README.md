# build - test builds for every platform

Every example and test program from `bas/`, compiled for each platform as assembler
source, ready to assemble on Windows / MS-DOS with `build.bat`:

```
build.bat                                  sjasmplus.exe in this folder, or on the PATH
build.bat ..\primal\sjasmplus\sjasmplus.exe   or give its path (relative or full)
```

| Folder | Platform | Output | Use |
|---|---|---|---|
| `cpc\` | Amstrad CPC, hardware (no firmware) | `NAME.BIN` with an AMSDOS header, loads and runs at `#0040` | put it on a disk image / M4 / SD card, `RUN"NAME` |
| `cpcfw\` | Amstrad CPC, through the firmware | `NAME.BIN` with an AMSDOS header, `#0040` | `RUN"NAME` |
| `cpm\` | CP/M 2.2 / 3 | `NAME.COM` at `#0100` | copy to the CP/M disk, type `NAME` |
| `test\` | the test harness platform | `NAME.BIN`, raw, at `#4000` | for `test/ntcrun.py` |

The CPC files are written by sjasmplus itself (`DEVICE AMSTRADCPC6128` at the top of each
.ASM and `SAVEAMSDOS` at the end, from the compiler's `amsdos` option / `cli.js --amsdos=NAME`).

The .ASM files are generated - don't edit them. After changing the compiler, the library
or `bas/`, run `node genbuild.js` in `test/` (the regression run does it too, and checks that
every file assembles).

Programs: GUIDE, GUESS, SIEVE, SHELSORT, SIEVETIM (sieve timing, turbo / normal), NUMBERED, NTCTEST (asks for a name, a number,
a key), VBTEST, VBTEST2..VBTEST12 (VBTEST12 asks for a line at the end), LONGTEST,
CLASSDEM, CONSOLE (the StdIO / System classes; asks for a name and a key), OWNSTDIO (a
project's own StdIO). `cpm\` also has SIEVEC, the same sieve in Small C (from
`compare/smallc/`, not generated) - time it against SIEVETIM. The self tests end with a line like `64 tests, 0 failed`. Every program ends with
`Press a key` and waits, so the result stays on the screen.

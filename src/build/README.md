# build - test builds for every platform

Every example and test program from `bas/`, compiled for each platform as assembler
source, ready to assemble on Windows / MS-DOS with `build.bat`:

```
build.bat                                  sjasmplus.exe in this folder, or on the PATH
build.bat ..\primal\sjasmplus\sjasmplus.exe   or give its path (relative or full)
```

| Folder | Platform | Output | Use |
|---|---|---|---|
| `cpc\` | Amstrad CPC, no firmware (no files) | `NAME.BIN` with an AMSDOS header, loads and runs at `#0040` | put it on a disk image / M4 / SD card, `RUN"NAME` |
| `cpcmin\` | Amstrad CPC, minimal firmware (own screen and keys, firmware for discs and ROMs) | `NAME.BIN` with an AMSDOS header, `#0040` | `RUN"NAME` |
| `cpcfw\` | Amstrad CPC, through the firmware | `NAME.BIN` with an AMSDOS header, `#0040` | `RUN"NAME` |
| `cpm\` | CP/M 2.2 / 3 | `NAME.COM` at `#0100` | copy to the CP/M disk, type `NAME` |
| `test\` | the test harness platform | `NAME.BIN`, raw, at `#4000` | for `test/ntcrun.py` |

A program with pages (overlay classes: `OVERLAYS`, `PAGES` on cpcmin, cpcfw and cpm) also writes
their page files (`OVERLAYS.001`, `OVERLAYS.002`, `PAGES.001` ... - the program's name, numbered) when it is assembled: copy them to the disc
with the `.BIN` / `.COM`. `OVERLAYS` and `PAGES` are only built for cpcmin, cpcfw and cpm, `INTERRUP` (interrupt classes) for
cpc, cpcmin and cpcfw.

`dsk\` holds two disc images per platform with its programs already assembled, ready to insert
in an emulator (WinAPE: drive A or B): `cpc.dsk`, `cpcmin.dsk`, `cpcfw.dsk` (the examples and demos:
the `.BIN` files, `RUN"NAME`, and the page files `OVERLAYS.001` ..., `PAGES.001` ..., `CUBE3D.001`) and
`cpm.dsk` (the `.COM` files: boot CP/M from its system disc, then use this one, e.g. in drive B);
`cpctest.dsk`, `cpcmintest.dsk`, `cpcfwtest.dsk`, `cpmtest.dsk` hold the self tests (`NTCTEST`,
`VBTEST*`, `LONGTEST`) - one disc each would no longer hold them all.
They are CPCEMU `.DSK` files in the CPC **data format** (40 tracks, 9 sectors of 512 bytes, #C1-#C9),
which AMSDOS, CP/M 2.2 and CP/M Plus all read. They are remade with the .ASM files
(`test/gendsk.sh`, which needs sjasmplus and cpmtools); after changing a `.bas` yourself, assemble
with `build.bat` and copy the file onto the image with your usual disc tool.

The CPC files are written by sjasmplus itself (`DEVICE AMSTRADCPC6128` at the top of each
.ASM and `SAVEAMSDOS` at the end, from the compiler's `amsdos` option / `cli.js --amsdos=NAME`).

The .ASM files are generated - don't edit them. After changing the compiler, the library
or `bas/`, run `node genbuild.js` in `test/` (the regression run does it too, and checks that
every file assembles).

Programs: GUIDE, GUESS, SIEVE, SHELSORT, SIEVETIM (sieve timing, turbo / normal), FILES, FILESTEP,
FILESTPN, AMSDOS, MEMMAP (main memory and RAM pages as a map), LISTS, SORTTIME (5,000 list nodes
sorted, turbo / normal), CMDLINE (the command line, or ask), CUBE3D (3D wireframe shapes, cpc / cpcmin / cpcfw), OVERLAYS, PAGES (classes placed in pages, a class copied into two), INTERRUP, NUMBERED, NTCTEST (asks for a name, a number,
a key), VBTEST, VBTEST2..VBTEST12 (VBTEST12 asks for a line at the end), LONGTEST,
CLASSDEM, CONSOLE (the StdIO / System classes; asks for a name and a key), OWNSTDIO (a
project's own StdIO). `cpm\` also has SIEVEC, the same sieve in Small C (from
`compare/smallc/`, not generated) - time it against SIEVETIM. The self tests end with a line like `64 tests, 0 failed`. Every program ends with
`Press a key` and waits, so the result stays on the screen.

# NTC test harness (Python + Node scratch tools, not part of the compiler)

| File | What |
|---|---|
| `cli.js` | compile .bas / .cls files to .asm from the command line (`node cli.js main.bas [more files] [--turbo] [--nocomments] [--platform=cpm]`) |
| `cpcrun.py` | compile, assemble (sjasmplus) and run on an emulated CPC: IM 1 interrupts every 13333 T, keyboard matrix, typed input, prints the screen text. The lower ROM is emulated only for the font (`font_standin.txt`, a public domain font standing in for Amstrad's). Typed text: `\n` = Return, `~` = one look at the keyboard that finds no key. `python3 cpcrun.py prog.bas 'typed\n' [more files] [--turbo]` |
| `ntcrun.py` | the same as `cpcrun.py` with `--platform=cpc\|cpcfw\|cpm\|test`: the host platforms run on a plain Z80 with the firmware jumpblock / BDOS / test ports handed to the harness, which keeps a text screen |
| `stdio.bas`, `via/` + `ref/stdio.*.txt`, `ref/via.txt` | the StdIO / System platform classes on each platform, and a project with its own StdIO |
| `fs_cpm.bas`, `fs_fw.bas`, `fs_none.bas` + `ref/fs_*.txt` | the FileSystem class: CP/M (every method), CPC firmware (Load / Save), no files (test, cpc); the files go to `t/files` |
| `realcpc.c`, `realcpcbin.sh` | a CPC 6128 with the real Amstrad ROMs and AMSDOS (the floooh/chips emulator, built with gcc): boots BASIC, inserts a .DSK, types, takes screenshots, counts fetches of addresses (with the lower ROM on or off); `XROM=file [XSLOT=n]` fits a ROM image (e.g. `build/rom/NTCFW.ROM`, slot 6). For what the harness can't show - how the real firmware calls the program (cpcfw interrupts, Graphics under the firmware). Needs the chips headers and the ROM images (github.com/floooh/chips, chips-test) |
| `genrom.js` | `node genrom.js cpc\|cpcmin\|cpcfw`: builds that platform's keyword library ROM (`build/rom/NTCCPC`, `NTCMIN`, `NTCFW` `.ASM` / `.ROM`) and appends new entries to its registry `asm/ntc_rom_<platform>.txt` (then run `gen.js`) |
| `genbuild.js` | writes `build/<platform>/NAME.ASM` (every program in `bas/` for every platform) for `build/build.bat` |
| `guitest6.py` | every example on every platform in the GUI |
| `regress.sh` | every test program in both modes on the CPC, then on the test / cpcfw / cpm platforms, the platform classes, + ES5 check of the JS. Ends with ALL PASS |
| `gen.js` | rebuilds `js/ntc_lib.js` (from `asm/*.asm`) and `js/ntc_examples.js` (from `bas/`) - run after changing the library or examples |
| `guitest*.py` | Playwright tests of `ntc.html` (examples compile with no errors, procedure list, .vbp open) |
| `for.bas gs.bas gs2.bas scr0.bas scr2.bas` + `ref/` | FOR / GOSUB / screen tests with expected output |
| `vbp/` | a .vbp with its files for `guitest4.py` |

Needs: python3 with `pip install z80` (Z80Machine), sjasmplus on the PATH (or `SJASMPLUS=/path/to/sjasmplus`),
node with `npm install` here (acorn for the ES5 check), Playwright + Chromium for the GUI tests.

# NTC test harness (Python + Node scratch tools, not part of the compiler)

| File | What |
|---|---|
| `cli.js` | compile .bas / .cls files to .asm from the command line (`node cli.js main.bas [more files] [--turbo] [--nocomments]`) |
| `cpcrun.py` | compile, assemble (sjasmplus) and run on an emulated CPC: IM 1 interrupts every 13333 T, keyboard matrix, typed input, prints the screen text. `python3 cpcrun.py prog.bas 'typed\n' [more files] [--turbo]` |
| `regress.sh` | every test program in both modes + ES5 check of the JS. Ends with ALL PASS |
| `gen.js` | rebuilds `js/ntc_lib.js` (from `asm/*.asm`) and `js/ntc_examples.js` (from `bas/`) - run after changing the library or examples |
| `guitest*.py` | Playwright tests of `ntc.html` (examples compile with no errors, procedure list, .vbp open) |
| `for.bas gs.bas gs2.bas scr0.bas scr2.bas` + `ref/` | FOR / GOSUB / screen tests with expected output |
| `vbp/` | a .vbp with its files for `guitest4.py` |

Needs: python3 with `pip install z80` (Z80Machine), sjasmplus on the PATH (or `SJASMPLUS=/path/to/sjasmplus`),
node with `npm install` here (acorn for the ES5 check), Playwright + Chromium for the GUI tests.

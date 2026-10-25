# ntccheck - checking NTC itself

Node scripts (no packages) for checking a change to NTC. They load NTC's own `src/js` files.

| Script | What it does |
|---|---|
| `compare.js TREE_A TREE_B [platform ...]` | Compiles every program in `src/bas` (a `.bas`, or a folder with `Main.bas`) for each platform with both trees' compilers and compares the output (asm, errors, warnings). For a merge, or any change that should not change what is built. No platforms named: every platform tree A has. Exit code 1 when any differ. |
| `romwhy.js [cpc\|cpcmin\|cpcfw] [NTC_SRC]` | The library sections the keyword ROM (Library: ROM) leaves out, and the labels each one needed. Run it when `genrom.js` stops with "... moved: variables and constants keep their place". |

The regression suites are in `src/test` (`regress.sh`, `mdregress.sh`, `m65regress.sh`).
`regress.sh` needs python3 with the z80 module, sjasmplus, and node with `acorn` (for the ES5 check:
`npm install acorn` anywhere and point `NODE_PATH` at its `node_modules`).

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

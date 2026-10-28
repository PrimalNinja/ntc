# ColecoVision test tools

Build and test a ColecoVision cartridge written in NTC BASIC (the `colecovision` platform). `regress.sh` runs the ball test with these when `npm install` has been done here.

| File | What |
|---|---|
| `build.js` | `node build.js out.col Main.bas [Coleco.cls ...] [--layout]`: compile for the `colecovision` platform (`src/asm/ntc_plat_colecovision.asm`: `baremetal` with the ROM keys - cart `#8000-#FFFF`, RAM `#6000-#63FF` - and the cartridge header and start), Option Turbo, assemble with sjasmplus (on the PATH, `SJASMPLUS=path`, or `sjasmplus/sjasmplus.exe` on Windows), write the ROM (8, 16, 24 or 32K) and its `.asm` / `.sym` |
| `run.mjs` | `node run.mjs out.col [--png=pic.png] [--script="frames:bits,..."] [--quiet]`: run the ROM on a model of the hardware (no BIOS needed) and check it. Needs `npm install` here. Fails the run on: VDP NMI enabled (R#1 bit 5), VDP accesses closer than 29 T with the display on, writes to the ROM or unmapped memory, code run in the BIOS area. The default walk moves the ball round the screen and checks every position |

The test program is `test/coleco/ball/` (`Main.bas` and the hardware class `Coleco.cls`);
its build is in `build/coleco/`.

Model of what is checked: not a ColecoVision BIOS or a real console. It shares my reading of the
hardware (joystick on port `#FC` after `OUT #C0`, bits 0-3 up / right / down / left active low, bit 6
fire; VDP data `#BE`, control `#BF`), so those parts still need a run in a real emulator.

The header is `#55 #AA` (no title screen, no delay). For a title screen change it to `#AA #55` in
`ntc_plat_romhead` (src/asm/ntc_plat_colecovision.asm) and put the title text at `#8024`.

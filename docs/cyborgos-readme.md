# CyborgOS

(c) 2026 Cyborg Unicorn Pty Ltd - MIT License

CyborgOS is a separate project from NTC BASIC. NTC BASIC is the compiler, for several targets
(CPC with or without the firmware, CP/M, a ROM, the test harness). CyborgOS is a set of CPC
targets written in NTC BASIC: a hypervisor that runs CP/M programs - NTC BASIC programs built
for the cpm platform, or any CP/M 2.2 program that keeps to the BDOS and the BIOS - each in a
whole 64K bank of its own.

## The two versions

| | CyborgOS 128K | CyborgOS 320K |
|---|---|---|
| What it is for | one program with a big TPA: console programs, including ones that work the CPC's hardware directly | the real hypervisor: many programs at once |
| Needs | a 6128 (128K) or more | 320K or more (a 256K expansion) |
| Program space | #0100-#F4FF, about 61K | #0100-#EEFF, 59.5K |
| Slots | 1 on a 6128, up to 16 | half the extra 64K banks: 2 with 256K ... 20 with 3MB or more |
| CP/M | the BDOS console and file calls | a CP/M 2.2 BDOS and BIOS jump table, default FCBs from the command tail, RAM discs with real random access |
| Sources | `src/bas/cyborgos128kb/` | `src/bas/cyborgos320kb/` |
| Disc | `src/build/dsk/cyborgos128k.dsk` | `src/build/dsk/cyborgos320k.dsk` |
| Status | frozen: changed only when asked for | where new work goes |

**128K.** A program has the bank switched in as all 64K (the gate array's RAM setting C2), so
it has more room than the usual CPC CP/M (Amstrad's CP/M 2.2 gives about 41K) and still reaches
every I/O port: the CRTC, the sound chip, the PPI and the rest are not affected by the banking.
It suits programs that need a large TPA and drive the hardware themselves.

**320K.** The first expansion bank's 16K pages are the hypervisor's own (the disc buffers;
the RAM disc driver), main RAM's #4000-#7FFF is kept for a second screen, and half of the other
banks are slots. Each slot has its own command line and console (its own MODE: 80 x 25, 80 x 24 with a
status strip - the default -, 88 x 23, 96 x 21 or 64 x 32), switched with
Control + a number; Control + ESC shows TOP. The CP/M BDOS and BIOS are answered in the bank
where nothing of the hypervisor is needed (the console, keys), the rest through a far call to
the hypervisor (files, RAM discs, the clock).

A program built for CyborgOS runs on both: the slot is the same 64K bank from #0100.

## Documents

| | |
|---|---|
| [cyborgos-userguide.md](cyborgos-userguide.md) | using the 320K version: commands, disc commands, RAM discs, programs, the BDOS and BIOS, FILES.DIR, making a .CYB |
| [cyborgos.md](cyborgos.md) | the design: the bank switch, the time slices, the memory maps, decisions |
| [cyborgos-todo.md](cyborgos-todo.md) | what has been done (dated) and what is next |
| `src/bas/cyborgos128kb/README.md`, `USERGUIDE.md`, `DESIGN.md` | the 128K version, as it was frozen |

## Building

CyborgOS is built with NTC BASIC like any program (the hypervisor for **cpcfw**, the programs
and disc commands for **cpm** with an AMSDOS header: `.CYB`). `src/test/gendsk.sh` builds both
discs from their sources; `src/test/regress.sh` tests the 320K version in the harness
(`src/test/ntcrun.py`). See the user guide's section 8.

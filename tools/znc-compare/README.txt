NTC against ZNC (Chris Taylor's C-like compiler for the Next, github.com/taylorza/znc-compiler) - the
benchmark of 14 November 2026. T-states on the same Z80 core (the python z80 module NTC's tests use).

  b.znc / bg.znc   seven tests in ZNC (bg: the loop variables global)      b.bas   the same in NTC BASIC
  f.znc            ZNC's fixed (12.4) multiply and divide                  f.bas   NTC's Fixed 16 / 32, plain Long, Float
  znrun.py         a ZNC raw binary on a flat Z80: T-states between OUT (254), n marks
  nrun.py          an NTC zxn build on test/zxnrun.py's Next: the same marks

ZNC: build its compiler for the host (gcc -std=c99 -O2 -I tests/host -I . *.c tests/host/platform.c, less
farcall.c, after tools/rtlgenerate.py over RTL/*.asm), znc-host b.znc b.asm, drop the output / map / options
lines, sjasmplus --zxnext --raw=b.bin b.asm, python3 znrun.py b.bin 8000.
NTC: node test/cli.js b.bas --platform=zxn --name=B > b.asm, sjasmplus --sym=b.sym b.asm,
python3 nrun.py b.asm <NTC>/test. Option Turbo as the first line for the turbo figures.
ZNC's figures are without ZOPT (its peephole optimiser), which was not run.

Results (T-states, millions; lower is better)          ZNC local  ZNC global  NTC normal  NTC turbo
  sieve, 8191 flags x 3                                  46.4       36.2        49.6        35.0
  loop + add, 30000                                      13.1       10.4        12.0         9.3
  function call, 3 parameters x 10000                     7.9        7.0         9.9         7.3
  multiply / divide / mod x 5000                         17.5       16.9        22.5        21.8
  bubble sort, 100 integers                               7.2        5.8         8.1         7.2
  poke fill, 6144 bytes x 4                              14.4       10.1         9.3         7.1
  nested loops + test, 100 x 100                          5.8        4.7         6.6         4.8

Fixed point, T-states an operation (2000 turn loop, NTC turbo)       multiply   divide
  ZNC fixed (16 bit, 12.4, no rounding, no overflow check)             1630      2520
  NTC Fixed.Mul16 / Div16 before 20261114-1 (BASIC)                   38000     37600
  NTC Fixed.Mul16 / Div16 from 20261114-1 (Z80)                        3300      3270
  NTC Fixed.Mul32 / Div32 before                                      76700     74500
  NTC Fixed.Mul32 / Div32 from 20261114-1                              7360      7310
  NTC plain BASIC 12.4 through Long                                   20200     20100
  NTC Float.Multiply / Divide (IEEE single)                           13900     24300

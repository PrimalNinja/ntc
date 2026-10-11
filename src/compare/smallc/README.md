# compare/smallc - the sieve in Small C

The same program as `bas/sievetime.bas` (Sieve of Eratosthenes, primes below 8000, one byte
flag per number, 5 passes), written in plain Small C, to compare NTC with a classic Z80 C
compiler.

| File | What |
|---|---|
| `sieve.c` | the C source, standard Small C, nothing tuned |
| `SIEVEC.ASM` | what Small C made of it, plus its runtime library and a small CP/M console part; assembles with sjasmplus |

`test/genbuild.js` copies `SIEVEC.ASM` to `build/cpm/`, so `build.bat` makes `SIEVEC.COM`
next to `SIEVETIM.COM`. CP/M only (the console part uses BDOS).

## How SIEVEC.ASM was made

1. Small C: Ron Cain's compiler as revised by Chris Lewis (C3.0R1.1), from the
   ncb85/SmallC-85 revival (public domain). Built with gcc, run on `sieve.c`.
   It writes 8080 code for the ASXXXX assembler.
2. Each 8080 instruction written in Z80 mnemonics (`mov a,m` -> `ld a,(hl)`, `dad d` ->
   `add hl,de`, `call ccle` stays a call), one for one: no instruction added, removed
   or changed. The same for the runtime library (`crun8080lib.asm`: ccgint, ccpint,
   ccle, cceq, ...).
3. A small CP/M console part (puts, printn, getkey), outside the timed part.

## Results

Measured in the harness with CPC timing (each instruction rounded up to whole
microseconds, as the CPC's Gate Array does), 5 passes:

| | Time | |
|---|---|---|
| Small C | 33.2 s | |
| NTC, normal mode | 24.9 s | 1.33 x the speed of Small C |
| NTC, turbo | 17.5 s | 1.9 x the speed of Small C |

Run `SIEVEC` and `SIEVETIM` (5 passes) in the same CP/M and time them with a stopwatch.

Why Small C is slower here: every variable access is an address sum plus a runtime call
(`ld hl,2 / add hl,sp / call ccgint`), every compare is a runtime call (`call ccle`) that
gives 0 / 1, then `ld a,h / or l / jp nz`. NTC passes the variable's address in the thread
and does the whole compare-and-branch in one keyword.

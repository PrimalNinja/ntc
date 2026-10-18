# compare/bench - the speed comparison programs

The programs behind `docs/NTC.md` section 3 ("Speed compared"), each written plainly with the same
algorithm and the same answers:

| Test | NTC | Small C | Small C output (CP/M) | BBC BASIC |
|---|---|---|---|---|
| sieve | `sieve.bas` | `sieve.c` | `BSIEVEC.ASM` | `sieve.bbc` |
| sort | `sort.bas` | `sort.c` | `BSORTC.ASM` | `sort.bbc` |
| factor | `factor.bas` | `factor.c` | `BFACTORC.ASM` | `factor.bbc` |
| loop | `loop.bas` | `loop.c` | `BLOOPC.ASM` | `loop.bbc` |
| call | `call.bas` | `call.c` | `BCALLC.ASM` | `call.bbc` |
| divide | `divide.bas` | `divide.c` | `BDIVIDEC.ASM` | `divide.bbc` |
| string | `string.bas` | - (Small C has no strings) | | `string.bbc` |

`BSIEVEA.ASM` is the sieve in hand-written Z80. `io_z.inc` is its CP/M console part.

`ansi/` holds the same tests in standard C for z88dk's sccz80 and SDCC (the Small C files
are K&R C for Small C):

```
zcc +cpm -compiler=sccz80 -O3 sieve.c -o SIEVEZ.COM
sdasz80 -plosgff crt0_cpm_sdcc.rel crt0_cpm_sdcc.s
sdcc -mz80 --opt-code-speed --max-allocs-per-node 200000 --no-std-crt0 --code-loc 0x0120 --data-loc 0 -o sieve.ihx crt0_cpm_sdcc.rel sieve.c
objcopy -I ihex -O binary sieve.ihx SIEVES.COM      (or hex2bin: a binary from #0100)
```

`crt0_cpm_sdcc.s` is a small CP/M start-up for SDCC (stack below BDOS, initialised data,
`putchar` through BDOS 2).

- The NTC programs run the test twice, turbo then normal, each from `go` to the result.
- `B*C.ASM`: Small C's 8080 code written in Z80 mnemonics one for one, with Ron Cain's
  runtime library (see `compare/smallc/README.md`). `sjasmplus --raw=BSORTC.COM BSORTC.ASM`.
- The `.bbc` files: type them into BBC BASIC (Z80) for CP/M with line numbers
  (`10`, `20`, ...) and `RUN`. BBC BASIC (Z80) is (c) R.T. Russell, github.com/rtrussell/BBCZ80.
- Timing with a stopwatch: one run of each is short (under a second to a few seconds for
  NTC and C). For the sieve with a stopwatch use `bas/sievetime.bas` (SIEVETIM) and
  `compare/smallc` (SIEVEC), 5 passes.

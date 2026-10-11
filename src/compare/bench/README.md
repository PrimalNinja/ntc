# compare/bench - the speed comparison programs

The programs behind NTC.md section 3 ("Speed compared"), each written plainly with the same
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

- The NTC programs run the test twice, turbo then normal, each from `go` to the result.
- `B*C.ASM`: Small C's 8080 code written in Z80 mnemonics one for one, with Ron Cain's
  runtime library (see `compare/smallc/README.md`). `sjasmplus --raw=BSORTC.COM BSORTC.ASM`.
- The `.bbc` files: type them into BBC BASIC (Z80) for CP/M with line numbers
  (`10`, `20`, ...) and `RUN`. BBC BASIC (Z80) is (c) R.T. Russell, github.com/rtrussell/BBCZ80.
- Timing with a stopwatch: one run of each is short (under a second to a few seconds for
  NTC and C). For the sieve with a stopwatch use `bas/sievetime.bas` (SIEVETIM) and
  `compare/smallc` (SIEVEC), 5 passes.

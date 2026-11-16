ByRef in place - the measurements (build 20261116-2)
====================================================
Run from test/:  python3 ntcrun.py ../tools/byref-bench/br1.bas '' --platform=cpc [--turbo]
The T= figure at the end is the Z80 T-states the run took.

br1.bas   1000 calls of Work(x, y, z ByRef Integers, all written), 1000 of Cnt(t ByRef String, 30
          characters, read only), 1000 of One(x ByRef Integer)
br2.bas   Work with its three parameters ByVal
br3.bas   Work with its three parameters ByRef (as br1's)

                         20261115-1 (copies)   20261116-2 (in place)
br1 cpc normal  T        6,286,831             4,534,581     28% less
br1 cpc turbo   T        5,373,137             3,648,325     32% less
br1 program size         2414 bytes            2314 bytes
br3 cpc turbo   T        1,619,512             1,527,232      6% less
br2 cpc turbo   T        1,386,778             1,386,778     the same (ByVal is unchanged)

What the figures say: a String passed ByRef is no longer copied, which is where most of br1's gain
is. Three written Integers named four times each are a little quicker in place than copied in and
back. ByVal is still the quickest for Integers a procedure only reads or keeps to itself.

(c) 2026 Cyborg Unicorn Pty Ltd

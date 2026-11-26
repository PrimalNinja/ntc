#!/bin/bash
# the self tests on the Commodore 64 with an REU (c64reu, 6502): built with c64build.js --log,
# run on VICE by c64run.py, the console's transcript checked. Needs NTC_VASM65 (vasm, 6502
# oldstyle syntax) and NTC_C64CORE (the VICE x64sc libretro core: see docs/c64reu.md).
cd "$(dirname "$0")"
P=../src/bas
mkdir -p t/c64
fail=0
n_ok=0
run() { # name expected-grep [runner options] -- files...
  local n=$1 e=$2; shift 2
  local ro=()
  while [ "$1" != "--" ]; do ro+=("$1"); shift; done; shift
  if ! node c64build.js "$@" --out=t/c64/$n.prg --log >t/c64/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/c64/$n.build; fail=1; return; fi
  o=$(timeout 600 python3 c64run.py t/c64/$n.prg --frames=60000 --untilend --log "${ro[@]}" 2>&1)
  if echo "$o" | grep -q "$e"; then echo "ok   $n"; n_ok=$((n_ok+1)); else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
run c64_test "163 tests, 0 failed" -- $P/c64_test/Main.bas $P/c64_test/Counter.cls
run vb_test "64 tests, 0 failed" -- $P/vb_test.bas
run vb_test2 "30 tests, 0 failed" -- $P/vb_test2/Main.bas $P/vb_test2/Module2.bas
run vb_test3 "11 tests, 0 failed" -- $P/vb_test3.bas
run long "58 tests, 0 failed" -- $P/vb_test_long.bas
run vb_test4 "16 tests, 0 failed" -- $P/vb_test4.bas
run vb_test6 "22 tests, 0 failed" -- $P/vb_test6.bas
run vb_test7 "16 tests, 0 failed" -- $P/vb_test7.bas
run vb_test8 "5 tests, 0 failed" -- $P/vb_test8.bas
run vb_test9 "34 tests, 0 failed" -- $P/vb_test9.bas
run argfn "123040567080" -- argfn/Main.bas argfn/A2.cls
run class "x=12" -- $P/class_demo/Main.bas $P/class_demo/Counter.cls
run sieve "168 primes" -- $P/sieve.bas
if [ -f c64/extra.sh ]; then . c64/extra.sh; fi
if [ $fail == 0 ]; then echo "ALL PASS (c64reu: $n_ok)"; fi

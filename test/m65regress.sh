#!/bin/bash
# the self tests on the MEGA65 (m65, 45GS02): built with m65build.py --log, run on Xemu by
# m65run.py, the console's transcript checked. Needs NTC_VASM65 (vasm, 6502 oldstyle syntax)
# and NTC_XEMU (xmega65 with NTC's test driver: see docs/m65.md). Left out: programs that wait
# for typed text and vb_test5, vb_test10, vb_test11 (their #asm is Z80).
cd "$(dirname "$0")"
P=../src/bas
mkdir -p t/m65
fail=0
run() { # name expected-grep files...
  local n=$1 e=$2; shift 2
  if ! python3 m65build.py "$@" --out=t/m65/$n.prg --log >t/m65/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/m65/$n.build; fail=1; return; fi
  o=$(timeout 300 python3 m65run.py t/m65/$n.prg --frames=20000 --untilend --log 2>&1)
  if echo "$o" | grep -q "$e"; then echo "ok   $n"; else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
run m65_test "163 tests, 0 failed" $P/m65_test/Main.bas $P/m65_test/Counter.cls
run vb_test "64 tests, 0 failed" $P/vb_test.bas
run vb_test2 "30 tests, 0 failed" $P/vb_test2/Main.bas $P/vb_test2/Module2.bas
run vb_test3 "11 tests, 0 failed" $P/vb_test3.bas
run long "58 tests, 0 failed" $P/vb_test_long.bas
run vb_test4 "16 tests, 0 failed" $P/vb_test4.bas
run vb_test6 "22 tests, 0 failed" $P/vb_test6.bas
run vb_test7 "16 tests, 0 failed" $P/vb_test7.bas
run vb_test8 "5 tests, 0 failed" $P/vb_test8.bas
run vb_test9 "34 tests, 0 failed" $P/vb_test9.bas
run argfn "123040567080" argfn/Main.bas argfn/A2.cls
run class "x=12" $P/class_demo/Main.bas $P/class_demo/Counter.cls
run sieve "168 primes" $P/sieve.bas
if [ $fail == 0 ]; then echo "ALL PASS (m65)"; fi

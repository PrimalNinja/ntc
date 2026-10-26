#!/bin/bash
# the self tests on the Mega Drive (md, 68000): built with mdbuild.py --log, run on the
# Genesis Plus GX core by mdrun.py, the console's transcript checked. Needs NTC_VASM (vasm,
# Motorola syntax) and NTC_MDCORE (genesis_plus_gx_libretro.so built with the VDP's memory
# exported: see mdrun.py). Left out: programs that wait for typed text (a pad has no keys) and
# vb_test5, vb_test10, vb_test11 (their #asm is Z80).
cd "$(dirname "$0")"
P=../bas
mkdir -p t/md
fail=0
run() { # name expected-grep files...
  local n=$1 e=$2; shift 2
  if ! python3 mdbuild.py "$@" --out=t/md/$n.md --log >t/md/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/md/$n.build; fail=1; return; fi
  o=$(timeout 300 python3 mdrun.py t/md/$n.md --frames=20000 --untilend --log 2>&1)
  if echo "$o" | grep -q "$e"; then echo "ok   $n"; else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
run md_test "157 tests, 0 failed" $P/md_test/Main.bas $P/md_test/Counter.cls
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
# Pad.Read on a 6 button pad: X, Y, Z, Mode, A, then X Y Z together held by the script (the read
# stopped one TH step short of the 6 button pad's extra buttons: X, Y, Z, Mode were never seen)
if python3 mdbuild.py mdpad/Main.bas --out=t/md/pad.md --log >t/md/pad.build 2>&1; then
  o=$(timeout 300 python3 mdrun.py t/md/pad.md --frames=420 --log --pad=40:X,100:Y,160:Z,220:M,280:A,340:XYZ,400:- 2>&1 | grep -a "^pad" | tr '\n' ' ')
  if [ "$o" == "pad 256 pad 256 pad 512 pad 512 pad 1024 pad 1024 pad 2048 pad 2048 pad 64 pad 64 pad 1792 pad 1792 " ]; then echo "ok   pad6"; else echo "FAIL pad6: $o"; fail=1; fi
else echo "FAIL pad6 (build)"; tail -5 t/md/pad.build; fail=1; fi
if [ $fail == 0 ]; then echo "ALL PASS (md)"; fi

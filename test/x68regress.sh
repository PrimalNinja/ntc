#!/bin/bash
# the self tests on the Sharp X68000 (x68000, 68000): built with x68build.js --log (a boot disc),
# run on the px68k core by x68run.py, the console's transcript checked. Needs NTC_VASM (vasm,
# Motorola syntax), NTC_X68CORE (px68k_libretro.so) and NTC_X68SYS (the folder with
# keropi/iplrom.dat and keropi/cgrom.dat, Sharp's ROMs). Left out: vb_test5, vb_test10,
# vb_test11 (their #asm is Z80) and ntc_test (it pokes &H8000: a 16 bit address reaches only
# $0000-$7FFF here, &H8000 on is the ROM's end of memory).
cd "$(dirname "$0")"
P=../src/bas
mkdir -p t/x68
fail=0
run() { # name expected-grep keys files...
  local n=$1 e=$2 k=$3; shift 3
  if ! node x68build.js "$@" --out=t/x68/$n.xdf --log >t/x68/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/x68/$n.build; fail=1; return; fi
  o=$(timeout 600 python3 x68run.py t/x68/$n.xdf --frames=30000 --untilend --log ${k:+--keys=$k} 2>&1)
  if echo "$o" | tr '\n' ' ' | grep -q "$e"; then echo "ok   $n"; else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
run vb_test "64 tests, 0 failed" "" $P/vb_test.bas
run vb_test2 "30 tests, 0 failed" "" $P/vb_test2/Main.bas $P/vb_test2/Module2.bas
run vb_test3 "11 tests, 0 failed" "" $P/vb_test3.bas
run long "58 tests, 0 failed" "" $P/vb_test_long.bas
run vb_test4 "16 tests, 0 failed" "" $P/vb_test4.bas
run vb_test6 "22 tests, 0 failed" "" $P/vb_test6.bas
run vb_test7 "16 tests, 0 failed" "" $P/vb_test7.bas
run vb_test8 "5 tests, 0 failed" "" $P/vb_test8.bas
run vb_test9 "34 tests, 0 failed" "" $P/vb_test9.bas
run argfn "123040567080" "" argfn/Main.bas argfn/A2.cls
run class "x=12" "" $P/class_demo/Main.bas $P/class_demo/Counter.cls
run sieve "168 primes" "" $P/sieve.bas
# typed text: the keyboard through the ROM's key calls
run guide "ANN!" '400:Ann\n' $P/guide.bas
run keys "name Bob7 n21 k120 at ok" '400:Bob7\n,520:7\n,600:x' x68/Main.bas
# the keywords no self test reaches: the whole transcript, the same as the FM Towns'
run extra "zone two three at end" "" towns/Extra.bas
if ! echo "$o" | diff -q - towns/Extra.txt >/dev/null; then echo "FAIL extra (not the expected text)"; echo "$o" | diff - towns/Extra.txt | head -6; fail=1; fi
# the supervisor call (trap #1) and the Keys, Opm and Vdp classes: Q is held by the script
run classes "super ok idle ok opm ok key? held1 vdp ok end" '400:q' x68/Classes.bas x68/Sup.cls
if [ $fail == 0 ]; then echo "ALL PASS (x68000)"; fi

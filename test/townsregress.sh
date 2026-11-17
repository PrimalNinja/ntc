#!/bin/bash
# the self tests on the FM Towns (towns, 80386): built with townsbuild.js --log (a boot
# floppy image), run on Tsugaru by townsrun.py, the console's transcript checked. Needs nasm,
# NTC_TSUGARU (Tsugaru_Headless) and NTC_TOWNSROM (the folder with the Towns ROM files).
# Left out: vb_test5, vb_test10, vb_test11 (their #asm is Z80) and ntc_test.
# One test by name: bash townsregress.sh vb_test4
cd "$(dirname "$0")"
P=../src/bas
mkdir -p t/towns
fail=0
run() { # name expected-grep keys files...
  local n=$1 e=$2 k=$3; shift 3
  if ! node townsbuild.js "$@" --out=t/towns/$n.bin --log >t/towns/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/towns/$n.build; fail=1; return; fi
  o=$(timeout 300 python3 townsrun.py t/towns/$n.bin --secs=${SECS:-60} --log --anykey ${FREQ:+--freq=$FREQ} ${k:+--keys=$k} 2>&1)
  if echo "$o" | grep -q "$e"; then echo "ok   $n"; else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
want=${1:-}
t() { if [ -z "$want" ] || [ "$want" == "$1" ]; then run "$@"; fi; }
# vb_test at 2 MHz: its clock test wants a frame to pass during a 2000 turn loop, and at the
# emulator's own speed the loop is over in a tenth of a frame
SECS0=${SECS:-60}; FREQ=2; SECS=120
t vb_test "64 tests, 0 failed" "" $P/vb_test.bas
FREQ=; SECS=$SECS0
t vb_test2 "30 tests, 0 failed" "" $P/vb_test2/Main.bas $P/vb_test2/Module2.bas
t vb_test3 "11 tests, 0 failed" "" $P/vb_test3.bas
t long "58 tests, 0 failed" "" $P/vb_test_long.bas
t vb_test4 "16 tests, 0 failed" "" $P/vb_test4.bas
t vb_test6 "22 tests, 0 failed" "" $P/vb_test6.bas
t vb_test7 "16 tests, 0 failed" "" $P/vb_test7.bas
t vb_test8 "5 tests, 0 failed" "" $P/vb_test8.bas
t vb_test9 "34 tests, 0 failed" "" $P/vb_test9.bas
t argfn "123040567080" "" argfn/Main.bas argfn/A2.cls
t class "x=12" "" $P/class_demo/Main.bas $P/class_demo/Counter.cls
t sieve "168 primes" "" $P/sieve.bas
# the rest of the library: the 68000 self test with its machine code in 80386
t self "154 tests, 0 failed" "" towns/self/Main.bas towns/self/Counter.cls
# the keywords no self test reaches: the whole transcript, the same on the X68000
t extra "^end" "" towns/Extra.bas
if [ -z "$want" ] || [ "$want" == extra ]; then
  if ! echo "$o" | diff -q - towns/Extra.txt >/dev/null; then echo "FAIL extra (not the expected text)"; echo "$o" | diff - towns/Extra.txt | head -6; fail=1; fi
fi
# typed text: the keyboard at its ports (the emulator ends each typed text with Return)
t guide "ANN!" '5:Ann' $P/guide.bas
t keys "name Bob7 n21 k120 at ok" '4:Bob7,7:7,10:x' towns/Main.bas
if [ $fail == 0 ]; then echo "ALL PASS (towns)"; fi

#!/bin/bash
# regression: every program in both modes (needs python3 + z80 module, sjasmplus, node + acorn)
cd "$(dirname "$0")"
P=../bas
fail=0
mkdir -p t/m2 t/cls t/ex
check() { # name expected-grep output
  if echo "$3" | grep -q "$2"; then echo "ok   $1"; else echo "FAIL $1"; echo "$3" | tail -5; fail=1; fi
}
for m in --turbo ""; do
  mn=${m:-normal}
  cp $P/vb_test.bas t/vb.bas; o=$(timeout 100 python3 cpcrun.py t/vb.bas '' $m 2>&1); check "vb_test $mn" "64 tests, 0 failed" "$o"
  cp $P/ntc_test.bas t/old.bas; o=$(timeout 100 python3 cpcrun.py t/old.bas 'Bob\n7\nx' $m 2>&1); check "ntc_test $mn" "36 tests, 0 failed" "$o"
  cp $P/vb_test2/*.bas t/m2/; o=$(timeout 100 python3 cpcrun.py t/m2/Main.bas '' t/m2/Module2.bas $m 2>&1); check "vb_test2 $mn" "30 tests, 0 failed" "$o"
  cp $P/vb_test3.bas t/v3.bas; o=$(timeout 100 python3 cpcrun.py t/v3.bas '' $m 2>&1); check "vb_test3 $mn" "11 tests, 0 failed" "$o"
  cp $P/vb_test_long.bas t/lg.bas; o=$(timeout 200 python3 cpcrun.py t/lg.bas "" $m 2>&1); check "long $mn" "58 tests, 0 failed" "$o"
  cp $P/vb_test4.bas t/v4.bas; o=$(timeout 200 python3 cpcrun.py t/v4.bas "" $m 2>&1); check "vb_test4 $mn" "16 tests, 0 failed" "$o"
  cp $P/class_demo/* t/cls/; o=$(timeout 100 python3 cpcrun.py t/cls/Main.bas '' t/cls/Counter.cls $m 2>&1); check "class $mn" "x=12" "$o"
  cp $P/sieve.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/sieve.bas '' $m 2>&1); check "sieve $mn" "168 primes" "$o"
  cp $P/shellsort.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/shellsort.bas 'y\n' $m 2>&1); check "shellsort y $mn" "^6 8 9 26 26 31 34 34 34 35" "$o"
  o=$(timeout 100 python3 cpcrun.py t/ex/shellsort.bas 'n\n' $m 2>&1); check "shellsort n $mn" "^6 8 9 26 26 31 34 34 34 35" "$o"
  cp $P/guide.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/guide.bas 'Ann\n' $m 2>&1); check "guide $mn" "ANN!" "$o"
  for f in for gs gs2 scr0 scr2; do
    o=$(timeout 40 python3 cpcrun.py $f.bas '' $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/$f.txt)" ]; then echo "ok   $f $mn"; else echo "FAIL $f $mn"; fail=1; fi
  done
done
for f in ../js/ntc_parser.js ../js/ntc_compiler.js ../js/ntc_gui.js ../js/ntc_lib.js ../js/ntc_examples.js; do
  node -e "require('acorn').parse(require('fs').readFileSync('$f','utf8'),{ecmaVersion:5})" || { echo "FAIL ES5 $f"; fail=1; }
done
echo "ES5 checked"
[ $fail == 0 ] && echo "ALL PASS" || echo "SOME FAILED"

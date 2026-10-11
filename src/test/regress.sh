#!/bin/bash
# regression: every program in both modes on the CPC, then on the host platforms (test,
# cpcfw, cpm), then the platform classes (needs python3 + z80 module, sjasmplus, node + acorn)
cd "$(dirname "$0")"
P=../bas
fail=0
mkdir -p t/m2 t/cls t/ex
check() { # name expected-grep output - and the program must have ended (not waiting for a key)
  if echo "$3" | grep -q "$2" && echo "$3" | grep -q "^--- halted"; then echo "ok   $1"; else echo "FAIL $1"; echo "$3" | tail -5; fail=1; fi
}
# Interrupt hook: normal mode only (turbo has no interrupts)
o=$(timeout 60 python3 cpcrun.py hook.bas '' 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/hook.txt)" ]; then echo "ok   hook normal"; else echo "FAIL hook normal"; fail=1; fi
for m in --turbo ""; do
  mn=${m:-normal}
  cp $P/vb_test.bas t/vb.bas; o=$(timeout 100 python3 cpcrun.py t/vb.bas 'x' $m 2>&1); check "vb_test $mn" "64 tests, 0 failed" "$o"
  cp $P/ntc_test.bas t/old.bas; o=$(timeout 100 python3 cpcrun.py t/old.bas 'Bob\n7\nx' $m 2>&1); check "ntc_test $mn" "36 tests, 0 failed" "$o"
  cp $P/vb_test2/*.bas t/m2/; o=$(timeout 100 python3 cpcrun.py t/m2/Main.bas 'x' t/m2/Module2.bas $m 2>&1); check "vb_test2 $mn" "30 tests, 0 failed" "$o"
  cp $P/vb_test3.bas t/v3.bas; o=$(timeout 100 python3 cpcrun.py t/v3.bas '~x' $m 2>&1); check "vb_test3 $mn" "11 tests, 0 failed" "$o"
  cp $P/vb_test_long.bas t/lg.bas; o=$(timeout 200 python3 cpcrun.py t/lg.bas 'x' $m 2>&1); check "long $mn" "58 tests, 0 failed" "$o"
  cp $P/vb_test4.bas t/v4.bas; o=$(timeout 200 python3 cpcrun.py t/v4.bas 'x' $m 2>&1); check "vb_test4 $mn" "16 tests, 0 failed" "$o"
  mkdir -p t/v5; cp $P/vb_test5/* t/v5/; o=$(timeout 200 python3 cpcrun.py t/v5/Main.bas 'x' t/v5/Pool.cls $m 2>&1); check "vb_test5 $mn" "18 tests, 0 failed" "$o"
  cp $P/vb_test6.bas t/v6.bas; o=$(timeout 200 python3 cpcrun.py t/v6.bas 'x' $m 2>&1); check "vb_test6 $mn" "22 tests, 0 failed" "$o"
  cp $P/vb_test7.bas t/v7.bas; o=$(timeout 200 python3 cpcrun.py t/v7.bas 'x' $m 2>&1); check "vb_test7 $mn" "16 tests, 0 failed" "$o"
  cp $P/vb_test8.bas t/v8.bas; o=$(timeout 200 python3 cpcrun.py t/v8.bas 'x' $m 2>&1); check "vb_test8 $mn" "5 tests, 0 failed" "$o"
  cp $P/vb_test11.bas t/v11.bas; o=$(timeout 200 python3 cpcrun.py t/v11.bas 'x' $m 2>&1); check "vb_test11 $mn" "17 tests, 0 failed" "$o"
  cp $P/vb_test12.bas t/v12.bas; o=$(timeout 200 python3 cpcrun.py t/v12.bas 'abcdefgh\nx' $m 2>&1); check "vb_test12 $mn" "33 tests, 0 failed" "$o"
  cp $P/vb_test9.bas t/v9.bas; o=$(timeout 200 python3 cpcrun.py t/v9.bas 'x' $m 2>&1); check "vb_test9 $mn" "34 tests, 0 failed" "$o"
  mkdir -p t/v10; cp $P/vb_test10/* t/v10/; o=$(timeout 200 python3 cpcrun.py t/v10/Main.bas 'x' t/v10/Bag.cls $m 2>&1); check "vb_test10 $mn" "33 tests, 0 failed" "$o"
  cp $P/class_demo/* t/cls/; o=$(timeout 100 python3 cpcrun.py t/cls/Main.bas 'x' t/cls/Counter.cls $m 2>&1); check "class $mn" "x=12" "$o"
  cp $P/sieve.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/sieve.bas 'x' $m 2>&1); check "sieve $mn" "168 primes" "$o"
  cp $P/shellsort.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/shellsort.bas '300\ntnx' $m 2>&1); check "shellsort $mn" "^6 8 9 26 26 31 34 34 34 35" "$o"
  cp $P/sievetime.bas t/ex/; o=$(timeout 200 python3 cpcrun.py t/ex/sievetime.bas '1\ntnx' $m 2>&1); check "sievetime $mn" "1007 primes below 8000" "$o"
  cp $P/guide.bas t/ex/; o=$(timeout 100 python3 cpcrun.py t/ex/guide.bas 'Ann\nx' $m 2>&1); check "guide $mn" "ANN!" "$o"
  for f in for gs gs2 scr0 scr2 diag1 diag2 vbprint cmptext tiny wrap; do
    o=$(timeout 40 python3 cpcrun.py $f.bas '' $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/$f.txt)" ]; then echo "ok   $f $mn"; else echo "FAIL $f $mn"; fail=1; fi
  done
done
# the same programs on the host platforms (test harness console, CPC firmware, CP/M)
host() { # platform mode
  pl=$1; m=$2; mn="$pl ${m:-normal}"; R="timeout 200 python3 ntcrun.py"
  cp $P/vb_test.bas t/vb.bas; check "vb_test $mn" "64 tests, 0 failed" "$($R t/vb.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/ntc_test.bas t/old.bas; check "ntc_test $mn" "36 tests, 0 failed" "$($R t/old.bas 'Bob\n7\nx' --platform=$pl $m 2>&1)"
  cp $P/vb_test2/*.bas t/m2/; check "vb_test2 $mn" "30 tests, 0 failed" "$($R t/m2/Main.bas 'x' t/m2/Module2.bas --platform=$pl $m 2>&1)"
  cp $P/vb_test3.bas t/v3.bas; check "vb_test3 $mn" "11 tests, 0 failed" "$($R t/v3.bas '~x' --platform=$pl $m 2>&1)"
  cp $P/vb_test_long.bas t/lg.bas; check "long $mn" "58 tests, 0 failed" "$($R t/lg.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test4.bas t/v4.bas; check "vb_test4 $mn" "16 tests, 0 failed" "$($R t/v4.bas 'x' --platform=$pl $m 2>&1)"
  mkdir -p t/v5; cp $P/vb_test5/* t/v5/; check "vb_test5 $mn" "18 tests, 0 failed" "$($R t/v5/Main.bas 'x' t/v5/Pool.cls --platform=$pl $m 2>&1)"
  cp $P/vb_test6.bas t/v6.bas; check "vb_test6 $mn" "22 tests, 0 failed" "$($R t/v6.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test7.bas t/v7.bas; check "vb_test7 $mn" "16 tests, 0 failed" "$($R t/v7.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test8.bas t/v8.bas; check "vb_test8 $mn" "5 tests, 0 failed" "$($R t/v8.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test9.bas t/v9.bas; check "vb_test9 $mn" "34 tests, 0 failed" "$($R t/v9.bas 'x' --platform=$pl $m 2>&1)"
  mkdir -p t/v10; cp $P/vb_test10/* t/v10/; check "vb_test10 $mn" "33 tests, 0 failed" "$($R t/v10/Main.bas 'x' t/v10/Bag.cls --platform=$pl $m 2>&1)"
  cp $P/vb_test11.bas t/v11.bas; check "vb_test11 $mn" "17 tests, 0 failed" "$($R t/v11.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/vb_test12.bas t/v12.bas; check "vb_test12 $mn" "33 tests, 0 failed" "$($R t/v12.bas 'abcdefgh\nx' --platform=$pl $m 2>&1)"
  cp $P/class_demo/* t/cls/; check "class $mn" "x=12" "$($R t/cls/Main.bas 'x' t/cls/Counter.cls --platform=$pl $m 2>&1)"
  cp $P/sieve.bas t/ex/; check "sieve $mn" "168 primes" "$($R t/ex/sieve.bas 'x' --platform=$pl $m 2>&1)"
  cp $P/shellsort.bas t/ex/; check "shellsort $mn" "^6 8 9 26 26 31 34 34 34 35" "$($R t/ex/shellsort.bas '300\ntnx' --platform=$pl $m 2>&1)"
  cp $P/sievetime.bas t/ex/; check "sievetime $mn" "1007 primes below 8000" "$($R t/ex/sievetime.bas '1\ntnx' --platform=$pl $m 2>&1)"
  cp $P/guide.bas t/ex/; check "guide $mn" "ANN!" "$($R t/ex/guide.bas 'Ann\nx' --platform=$pl $m 2>&1)"
  L="for gs gs2 scr0 scr2 diag1 diag2 vbprint cmptext tiny wrap"
  [ "$pl" == cpm ] && L="for gs gs2 diag1 diag2 vbprint cmptext tiny"	# a stream: no Locate / Mode
  for f in $L; do
    o=$($R $f.bas '' --platform=$pl $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/$f.txt)" ]; then echo "ok   $f $mn"; else echo "FAIL $f $mn"; fail=1; fi
  done
}
for pl in test cpcfw cpm; do for m in --turbo ""; do host $pl "$m"; done; done
# StdIO / System platform classes on every platform, and a project's own StdIO
for pl in cpc cpcmin test cpcfw cpm; do
  cp stdio.bas t/stdio.bas; o=$(timeout 100 python3 ntcrun.py t/stdio.bas 'Bo\nZ' --platform=$pl 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/stdio.$pl.txt)" ]; then echo "ok   stdio $pl"; else echo "FAIL stdio $pl"; fail=1; fi
done
for f in term_vt52 term_ansi; do	# CP/M Option Terminal
  cp $f.bas t/; o=$(timeout 100 python3 ntcrun.py t/$f.bas '' --platform=cpm 2>&1 | grep -v "^--- ")
  if [ "$o" == "$(cat ref/$f.txt)" ]; then echo "ok   $f cpm"; else echo "FAIL $f cpm"; fail=1; fi
done
# FileSystem: CP/M (BDOS files), CPC firmware (Load / Save), no files (test, cpc); both modes
for m in --turbo ""; do
  # test platform ref [harness option]: fs_fw2 without Option RomEnable - RUN" (tape) and CALLed (disc)
  for c in "fs_cpm cpm fs_cpm" "fs_fw cpcfw fs_fw" "fs_fw2 cpcfw fs_fw2" "fs_fw2 cpcfw fs_fw2c --called" "fs_none test fs_none" "fs_none cpc fs_none" "fs_fw cpcmin fs_fw" "fs_fw2 cpcmin fs_fw2"; do
    set -- $c; rm -rf t/files; cp $1.bas t/
    o=$(timeout 100 python3 ntcrun.py t/$1.bas '' --platform=$2 $4 $m 2>&1 | grep -v "^--- ")
    if [ "$o" == "$(cat ref/$3.txt)" ]; then echo "ok   $3 $2 ${m:-normal}"; else echo "FAIL $3 $2 ${m:-normal}"; echo "$o" | head -5; fail=1; fi
  done
  for pl in cpcmin cpcfw; do   # AMSDOS through the firmware: cpcmin hands back for each file call
    rm -rf t/files; cp $P/amsdos.bas t/ex/
    check "amsdos $pl ${m:-normal}" "^done" "$(timeout 200 python3 ntcrun.py t/ex/amsdos.bas '~x~x~x~b~x' --platform=$pl $m 2>&1)"
  done
  for pl in cpm cpcfw test; do
    rm -rf t/files; cp $P/files.bas t/ex/
    check "files $pl ${m:-normal}" "Press a key" "$(timeout 100 python3 ntcrun.py t/ex/files.bas '~x' --platform=$pl $m 2>&1)"
  done
done
mkdir -p t/via; cp via/* t/via/; o=$(timeout 100 python3 ntcrun.py t/via/Main.bas 'Bo\n7\n' t/via/StdIO.cls --platform=test 2>&1 | grep -v "^--- ")
if [ "$o" == "$(cat ref/via.txt)" ]; then echo "ok   own StdIO"; else echo "FAIL own StdIO"; fail=1; fi
# build/: regenerate, then check every file assembles the way build.bat does it
SJ=${SJASMPLUS:-sjasmplus}
node genbuild.js > /dev/null || fail=1
rm -rf t/bc; mkdir -p t/bc; cp -r ../build/cpc ../build/cpcmin ../build/cpcfw ../build/cpm ../build/test t/bc/
b=0; n=0
for p in cpc cpcmin cpcfw cpm test; do
  for f in t/bc/$p/*.ASM; do
    g=$(basename $f .ASM); n=$((n+1))
    case $p in cpm) o="--raw=$g.COM";; test) o="--raw=$g.BIN";; *) o="";; esac
    (cd t/bc/$p && $SJ --nologo --msg=err $o $g.ASM > /dev/null) || { echo "FAIL build $p/$g"; b=1; }
  done
  if [ $p == cpm ]; then x=COM; else x=BIN; fi
  [ $(ls t/bc/$p/*.$x 2>/dev/null | wc -l) == $(ls t/bc/$p/*.ASM | wc -l) ] || { echo "FAIL build $p: not every file written"; b=1; }
done
if [ $b == 0 ]; then echo "ok   build/ ($n files assemble)"; else echo "FAIL build/"; fail=1; fi
# build/dsk/: a CPC data format disc per platform with its programs (needs cpmtools + libdsk)
if command -v dskform > /dev/null && command -v cpmcp > /dev/null; then
  SJASMPLUS=$SJ bash gendsk.sh > t/dsk.txt 2>&1 && echo "ok   build/dsk ($(grep -c files t/dsk.txt) images)" || { echo "FAIL build/dsk"; cat t/dsk.txt; fail=1; }
else
  echo "skip build/dsk (no cpmtools / libdsk)"
fi
# Option Reserve: a range the program stays out of assembles, one it reaches into stops the assembly
printf 'Option Reserve &HC000, &H4000\nPrint 1\n' > t/res1.bas; printf 'Option Reserve &H0200, &H100\nPrint 1\n' > t/res2.bas
node cli.js t/res1.bas --platform=cpm > t/res1.asm && (cd t && $SJ --nologo --msg=err --raw=res1.com res1.asm > /dev/null) && r1=ok || r1=bad
node cli.js t/res2.bas --platform=cpm > t/res2.asm && (cd t && $SJ --nologo --msg=err --raw=res2.com res2.asm 2>&1 | grep -q "Option Reserve #0200-#02FF") && r2=ok || r2=bad
if [ $r1 == ok ] && [ $r2 == ok ]; then echo "ok   Option Reserve"; else echo "FAIL Option Reserve ($r1 $r2)"; fail=1; fi
# Option Stack: End comes back to the caller's stack on every host platform; a stack in the program stops the assembly
printf 'Option Stack &H9000\nPrint "stack ok"\n' > t/stk1.bas
for pl in test cpm cpcfw; do check "Option Stack $pl" "stack ok" "$(timeout 60 python3 ntcrun.py t/stk1.bas '' --platform=$pl 2>&1)"; done
printf 'Option Stack &H0150\nPrint 1\n' > t/stk2.bas
node cli.js t/stk2.bas --platform=cpm > t/stk2.asm && (cd t && $SJ --nologo --msg=err --raw=stk2.com stk2.asm 2>&1 | grep -q "Option Stack #0150") && echo "ok   Option Stack in the program" || { echo "FAIL Option Stack in the program"; fail=1; }
# the Small C sieve (compare/smallc) runs on the CP/M host and finds 1007 primes
o=$(timeout 200 python3 -c "import ntcrun; h = ntcrun.Host('cpm', open('t/bc/cpm/SIEVEC.COM', 'rb').read(), 0x100, 'xx'); h.run(); print(h.scr.text()); print('--- halted' if h.m.halted else '--- NOT halted')" 2>&1)
check "Small C sieve cpm" "^01007" "$o"
for f in ../js/ntc_parser.js ../js/ntc_compiler.js ../js/ntc_gui.js ../js/ntc_lib.js ../js/ntc_examples.js; do
  node -e "require('acorn').parse(require('fs').readFileSync('$f','utf8'),{ecmaVersion:5})" || { echo "FAIL ES5 $f"; fail=1; }
done
echo "ES5 checked"
rm -f *.asm *.bin *.sym; rm -rf t/*
[ $fail == 0 ] && echo "ALL PASS" || echo "SOME FAILED"

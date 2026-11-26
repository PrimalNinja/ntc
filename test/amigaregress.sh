#!/bin/bash
# the self tests on the Commodore Amiga 500 (amiga, 68000): built with amigabuild.js --log (a boot
# disc), run on the PUAE core by amigarun.py with the Kickstart replacement the core carries
# (AROS), the console's transcript checked; then the library classes (System, Memory, Keys,
# Loader): the memory found on five machines, files off the disc, a file on a second disc with
# one drive (the disc changed) and with two, the joystick, a key held. Needs NTC_VASM (vasm,
# Motorola syntax) and NTC_AMIGACORE (puae_libretro.so). Left out: vb_test5, vb_test10,
# vb_test11 (their #asm is Z80) and ntc_test (it pokes &H8000: a 16 bit address reaches only
# $0000-$7FFF here). The machine is an A500 with the trapdoor's 512K (1 MB in all): the
# replacement Kickstart does not start in 512K, so a bare 512K A500 is not tested.
cd "$(dirname "$0")"
P=../src/bas
mkdir -p t/ami
fail=0
run() { # name expected-grep keys files...
  local n=$1 e=$2 k=$3; shift 3
  if ! node amigabuild.js "$@" --out=t/ami/$n.adf --log >t/ami/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/ami/$n.build; fail=1; return; fi
  o=$(timeout 600 python3 amigarun.py t/ami/$n.adf --model=A500 --frames=30000 --untilend --log ${k:+--keys=$k} 2>&1)
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
# typed text: the keyboard through CIA-A
run guide "ANN!" '700:Ann\n' $P/guide.bas
run keys "name Bob7 n21 k120 at ok" '700:Bob7\n,850:7\n,950:x' x68/Main.bas
# the keywords no self test reaches: the whole transcript, the same as the FM Towns'
run extra "zone two three at end" "" towns/Extra.bas
if ! echo "$o" | diff -q - towns/Extra.txt >/dev/null; then echo "FAIL extra (not the expected text)"; echo "$o" | diff - towns/Extra.txt | head -6; fail=1; fi

# the classes: three files, one of them on a second disc
python3 - <<'PY'
open('t/ami/hello.txt', 'wb').write(b'Hello, disc!')
open('t/ami/big.bin', 'wb').write(bytes((i * 7 + (i >> 8) * 13) & 255 for i in range(60000)))
open('t/ami/two.bin', 'wb').write(bytes((i * 3 + 5) & 255 for i in range(20000)))
PY
if ! node amigabuild.js amiga/Classes.bas --out=t/ami/classes.adf --log --file=HELLO.TXT=t/ami/hello.txt --file=BIG=t/ami/big.bin --file=TWO=t/ami/two.bin@2 >t/ami/classes.build 2>&1; then echo "FAIL classes (build)"; tail -5 t/ami/classes.build; fail=1; fi
chk() { # what expected-grep options...
  local w=$1 e=$2; shift 2
  o=$(timeout 600 python3 amigarun.py t/ami/classes.adf t/ami/classes_2.adf --frames=9000 --untilend --log "$@" 2>&1)
  if echo "$o" | tr '\n' ' ' | grep -q "$e"; then echo "ok   classes: $w"; else echo "FAIL classes: $w"; echo "$o" | tail -6; fail=1; fi
}
F="size1260000-2 hello12 Hello, disc! big600007649392 small-8 nope-2 disc120"
chk "one drive at its real speed - files read, the second disc asked for and changed" "drives1 $F insert disc2 two200002547568 in drive0 joy0 key0 [.]* joy00 key0 end" --model=A500 --swap=2500:2
chk "two drives - the second disc found in DF1, nothing asked" "drives2 $F two200002547568 in drive1 joy0 key0 [.]* joy00 key0 end" --model=A500 --drives=2 --speed=800
chk "the joystick (up and fire held): 33, port 1 idle" "joy0 key0 [.]* joy330 key0 end" --model=A500 --drives=2 --speed=800 --joy=1100:UF
chk "a key held" "joy0 key0 [.]* joy00 key-1 end" --model=A500 --drives=2 --speed=800 --hold=1100:q
chk "memory: 512K chip + 512K slow" "hz50 chip512 other512 alloc1000 other block ok any block ok free ok too much ok" --model=A500 --drives=2 --speed=800
chk "memory: 1 MB chip, nothing else" "hz50 chip1024 other0 alloc1000 no other block any block ok" --model=A500ECS --drives=2 --speed=800
chk "memory: 1 MB chip + 8 MB fast" "hz50 chip1024 other8192 alloc1000 other block ok" --model=A500ECS --fast=8 --drives=2 --speed=800
chk "memory: 2 MB chip + 512K slow + 4 MB fast" "hz50 chip2048 other4608" --model=A500 --chip=2048 --fast=4 --drives=2 --speed=800
chk "memory: 512K chip + 512K slow + 2 MB fast (two blocks)" "hz50 chip512 other2560" --model=A500 --fast=2 --drives=2 --speed=800
chk "an NTSC machine: 60 frames a second" "hz60 chip512" --model=A500 --ntsc --drives=2 --speed=800
if [ $fail == 0 ]; then echo "ALL PASS (amiga)"; else echo "SOME FAILED (amiga)"; fi

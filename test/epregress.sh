#!/bin/bash
# the self tests on the Enterprise 128 (ep128, Z80): built with epbuild.js --log --img (the
# program file, and a disc that starts it), run on the ep128emu core by eprun.py - EXOS 2.1
# and EXDOS load the file off the disc as a real machine does - the console's transcript
# checked. Then what is the platform's own: programs over 16K and over 32K (EXOS leaves their
# parts in different pages: the start code puts them right), the Interrupt hook, interrupt
# classes, the Memory class's pages on 128K to 3.7 MB (every segment a page, each read back),
# a 64K machine refused, keys and the three joysticks, 80 columns, the program file started
# from IS-BASIC. Needs sjasmplus and NTC_EPCORE (ep128emu_core_libretro.so; for the two
# biggest machines the core built as eprun.py's header says).
cd "$(dirname "$0")"
P=../src/bas
mkdir -p t/ep
fail=0
build() { # name files...
  local n=$1; shift
  if ! node epbuild.js "$@" --out=t/ep/$n.com --log --img >t/ep/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/ep/$n.build; fail=1; return 1; fi
  rm -f t/ep/$n.ep128cfg
}
go() { # name expected-grep options...: run t/ep/name.img, the transcript in $o
  local n=$1 e=$2; shift 2
  o=$(timeout 1800 python3 eprun.py t/ep/$n.img --frames=40000 --untilend --log "$@" 2>&1)
  echo "$o" | tr '\n' ' ' | grep -q "$e"
}
run() { # name expected-grep keys files...
  local n=$1 e=$2 k=$3; shift 3
  build $n "$@" || return
  if go $n "$e" ${k:+--keys=$k}; then echo "ok   $n"; else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
ram() { echo "memory.ram.size $2" > t/ep/$1.ep128cfg; }
run vb_test "64 tests, 0 failed" "" $P/vb_test.bas
run vb_test2 "30 tests, 0 failed" "" $P/vb_test2/Main.bas $P/vb_test2/Module2.bas
run vb_test3 "11 tests, 0 failed" "" $P/vb_test3.bas
run long "58 tests, 0 failed" "" $P/vb_test_long.bas
run vb_test4 "16 tests, 0 failed" "" $P/vb_test4.bas
run vb_test5 "18 tests, 0 failed" "" $P/vb_test5/Main.bas $P/vb_test5/Pool.cls
run vb_test6 "22 tests, 0 failed" "" $P/vb_test6.bas
run vb_test7 "16 tests, 0 failed" "" $P/vb_test7.bas
run vb_test8 "5 tests, 0 failed" "" $P/vb_test8.bas
run vb_test9 "34 tests, 0 failed" "" $P/vb_test9.bas
run vb_test10 "33 tests, 0 failed" "" $P/vb_test10/Main.bas $P/vb_test10/Bag.cls
run vb_test11 "17 tests, 0 failed" "" $P/vb_test11.bas
run argfn "123040567080" "" argfn/Main.bas argfn/A2.cls
run class "x=12" "" $P/class_demo/Main.bas $P/class_demo/Counter.cls
run sieve "168 primes" "" $P/sieve.bas
# typed text: the keyboard matrix
run ntc_test "36 tests, 0 failed" '+60:Bob\n,+250:7\n,+450:x' $P/ntc_test.bas
run guide "ANN!" '+60:Ann\n' $P/guide.bas
run keys "name Bob7 n21 k120 at ok" '+60:Bob7\n,+250:7\n,+400:x' x68/Main.bas
# the keywords no self test reaches: the whole transcript, the same as the FM Towns'
run extra "zone two three at end" "" towns/Extra.bas
if ! echo "$o" | grep -v "^\[ended\]$" | diff -q - towns/Extra.txt >/dev/null; then echo "FAIL extra (not the expected text)"; echo "$o" | diff - towns/Extra.txt | head -6; fail=1; fi

# the Interrupt hook and interrupt classes (the frame interrupt, 50 a second)
build hook hook.bas && { go hook "hook ran"; if [ "$(echo "$o" | grep -v '^\[ended\]$')" == "$(cat ref/hook.txt)" ]; then echo "ok   hook"; else echo "FAIL hook"; echo "$o" | tail -3; fail=1; fi; }
build isl ep/isl/Main.bas ep/isl/Fifty.cls ep/isl/Ten.cls ep/isl/Frames.cls && { if go isl "fifty-1-1 ten-1-1 frames-1 ten<fifty -1 done"; then echo "ok   interrupt classes (50 a second, 10 a second, every frame)"; else echo "FAIL interrupt classes"; echo "$o" | tail -4; fail=1; fi; }

# long programs: 26K (EXOS loads it into two segments) and 45K built round the window (three:
# the middle one is in no page when the program starts), the second with the Memory class's pages
python3 - <<'PY'
def prog(pages):
    lines = []
    if pages:
        lines += ['Option Memory Reserved &H4000, &H4000', 'Option Memory Heap Pages']
    lines += ['Dim n As Integer']
    lines += ['Part%d' % s for s in range(9)]
    lines += ['Print "sum "; n']
    if pages:
        lines += ['Print "pages"; Memory.Pages(); " free"; Memory.FreePages()']
    lines += ['End']
    k = 0
    for s in range(9):
        lines.append('Sub Part%d()' % s)
        for i in range(100):
            lines.append('  n = n + %d : If n > 30000 Then n = n - 30000' % (k * 7 % 100 + 1))
            k += 1
        lines += ['  Print "part %d "; n' % s, 'End Sub']
    return '\n'.join(lines) + '\n'
open('t/ep/two.bas', 'w').write(prog(False))
open('t/ep/three.bas', 'w').write(prog(True))
PY
build two t/ep/two.bas && { if go two "part 8 15450 sum 15450"; then echo "ok   a 26K program (two segments)"; else echo "FAIL a 26K program (two segments)"; echo "$o" | tail -4; fail=1; fi; }
build three t/ep/three.bas && { if go three "part 8 15450 sum 15450 pages5 free3"; then echo "ok   a 45K program round the window (three segments), pages"; else echo "FAIL a 45K program (three segments)"; echo "$o" | tail -4; fail=1; fi; }

# the Memory class: the CPC's own test, 33 pages (its answers are the CPC 576K's but for the RAM's size)
{ printf 'Option Memory Heap Pages 33\n'; cat mem_t.bas; } > t/ep/mem33.bas
build mem33 t/ep/mem33.bas && { ram mem33 608; go mem33 "done"; if [ "$(echo "$o" | grep -v '^\[ended\]$')" == "$(sed 's/ram576/ram592/' ref/mem_576.txt)" ]; then echo "ok   memory: the CPC's test, 33 pages (608K)"; else echo "FAIL memory 608K"; echo "$o" | diff - ref/mem_576.txt | head -6; fail=1; fi; }

# the classes: System, Memory (every segment a page, marked and read back), Keys
build classes ep/Classes.bas
chk() { # what expected-grep ram options...
  local w=$1 e=$2 r=$3; shift 3
  rm -f t/ep/classes.ep128cfg; [ "$r" != 128 ] && ram classes $r
  if go classes "$e" "$@"; then echo "ok   classes: $w"; else echo "FAIL classes: $w"; echo "$o" | tail -6; fail=1; fi
}
T="alloc0-1 page-1 word12345 ticks-1 joy000 key0"
chk "128K - 2 segments free (one is the test's log), a key held" "plat EP128 hz50 segs2 own-1-1-1 screen-1 none-1 pages5 free3 ram112 banks0 taken3 bad0 free0 $T [.]* joy000 key-1 end" 128 --hold=+200:q
chk "256K, the built in joystick (cursor up, Space)" "segs10 .* pages13 free11 ram240 banks2 taken11 bad0 free0 $T [.]* joy100 key0 end" 256 --hold=+250:up
chk "512K, control port 1 (up and fire: 33)" "segs26 .* pages29 free27 ram496 banks6 taken27 bad0 free0 $T [.]* joy0330 key0 end" 512 --joy=+300:UF
chk "1 MB, control port 2 (down, right and fire: 42)" "segs58 .* pages61 free59 ram1008 banks14 taken59 bad0 free0 $T [.]* joy0042 key0 end" 1024 --joy2=+500:DRF
chk "3.7 MB - 226 segments, each its own page" "segs226 .* pages229 free227 ram3696 banks56 taken227 bad0 free0 $T" 3712 --quiet=40
# 64K: not enough segments - a red border, nothing run
ram classes 64
timeout 300 python3 eprun.py t/ep/classes.img --frames=2500 --untilend --shot=t/ep/c64.png >/dev/null 2>&1
if python3 - <<'PY'
import struct, sys, zlib
d = open('t/ep/c64.png', 'rb').read()
i = d.index(b'IDAT')
raw = zlib.decompress(d[i + 4:i + 4 + struct.unpack('>I', d[i - 4:i])[0]])
w = struct.unpack('>I', d[16:20])[0]
at = (w * 3 + 1) * 100 + 1 + 30
sys.exit(0 if raw[at] > 200 and raw[at + 1] < 40 and raw[at + 2] < 40 else 1)
PY
then echo "ok   a 64K machine: stopped with a red border"; else echo "FAIL a 64K machine (no red border)"; fail=1; fi

# 80 columns: Mode 2, a line of 80 characters, Locate, the scroll - the transcript and the picture's text
build mode ep/Mode.bas && { if go mode "cols80 .*X end" --shot=t/ep/mode.png; then echo "ok   Mode 2: 80 columns"; else echo "FAIL Mode 2"; echo "$o" | tail -4; fail=1; fi; }
# the program file alone, loaded by IS-BASIC's START through the core's own file device (that
# device now and then hands a program over wrongly: up to three tries)
ok=0; for try in 1 2 3; do o=$(timeout 300 python3 eprun.py t/ep/sieve.com --frames=6000 --untilend --log 2>&1); if echo "$o" | grep -q "168 primes"; then ok=1; break; fi; done
if [ $ok == 1 ]; then echo "ok   the .COM alone, started from IS-BASIC"; else echo "FAIL the .COM alone, started from IS-BASIC"; echo "$o" | tail -3; fail=1; fi
if [ $fail == 0 ]; then echo "ALL PASS (ep128)"; else echo "SOME FAILED (ep128)"; fi

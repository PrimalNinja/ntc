#!/bin/bash
# the self tests on the Neo Geo (neogeo, 68000): built with ngbuild.js --log, run on the Geolith
# core by ngrun.py with NTC's stand-in BIOS, the console's transcript checked; then the library
# classes (Vdp, Keys, Pad, Pcm, Psg, Fm, Sound) with tiles and sounds made by tools/neogeo's two
# tools: the transcript, the picture and the sound. Needs NTC_VASM (vasm, Motorola syntax),
# NTC_SJASM (sjasmplus: the Z80's sound driver), NTC_NGCORE (geolith_libretro.so) and Python's
# Pillow. Left out: programs that wait for typed text (a pad has no keys) and vb_test5,
# vb_test10, vb_test11 (their #asm is Z80). The Neo Geo CD (neocd) is only built: no emulator
# for it here.
cd "$(dirname "$0")"
P=../src/bas
mkdir -p t/ng
fail=0
run() { # name expected-grep files...
  local n=$1 e=$2; shift 2
  if ! node ngbuild.js "$@" --out=t/ng/$n.neo --log >t/ng/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/ng/$n.build; fail=1; return; fi
  o=$(timeout 300 python3 ngrun.py t/ng/$n.neo --frames=20000 --untilend --log 2>&1)
  if echo "$o" | tr '\n' ' ' | grep -q "$e"; then echo "ok   $n"; else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
run ntc_test "36 tests, 0 failed" $P/ntc_test.bas
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

# the library classes: the tools make the tiles, palettes and sounds; the program uses each call
node neogeo/mkassets.js t/ng >/dev/null \
  && node ../tools/neogeo/ngtiles.js --out=t/ng/A --sprites=t/ng/Tiles.png --backdrop=t/ng/Back.png --fix=t/ng/Fix.png >t/ng/tools.log 2>&1 \
  && node ../tools/neogeo/ngpcm.js --out=t/ng/A --samples=t/ng/Hit.wav t/ng/Song.wav >>t/ng/tools.log 2>&1 \
  && grep -q "tiles 4-227" t/ng/A.txt && [ "$(stat -c %s t/ng/A_PAL.BIN)" = 7200 ] \
  && echo "ok   tools/neogeo: ngtiles.js (sprites, a backdrop, fix tiles), ngpcm.js (a sample, a song)" \
  || { echo "FAIL tools/neogeo"; tail -3 t/ng/tools.log; fail=1; }
( cd t/ng && node ../../ngbuild.js ../../neogeo/Classes.bas ../../neogeo/Dat.cls --out=classes.neo --log \
    --crom=A_C.BIN --srom=A_S.BIN --vrom=A_V.BIN --songs=A_SONG.BIN --samples=A_SAMP.BIN >classes.build 2>&1 )
o=$(timeout 300 python3 ngrun.py t/ng/classes.neo --frames=400 --untilend --log --pad=0:-,20:UA --shot=t/ng/classes.png --wav=t/ng/classes.wav 2>&1)
if echo "$o" | tr '\n' ' ' | grep -q "rgb 4F00 20F0 501F sat ok words in palette 1 joy 0 pad 0 key 0 joy 33 pad 17 have 1 end"; then
  echo "ok   classes: Vdp.Rgb, Sat; Keys.Joystick and Pad.Read with Up and A held (33, 17); Pcm.Have"
else echo "FAIL classes (transcript)"; echo "$o" | tail -5; tail -3 t/ng/classes.build; fail=1; fi
# the picture (320 x 240: the screen's line y is the picture's y + 8)
python3 - <<'PY' && echo "ok   classes: the picture - the sprite table's sprite, Strip / Place / Join, the backdrop's four bands (one scrolled), the fix layer's Cell and Fill, the backdrop colour" || { echo "FAIL classes (picture)"; fail=1; }
import sys
from PIL import Image
im = Image.open('t/ng/classes.png').convert('RGB')
want = {'the table\'s sprite': ((140, 112), (255, 0, 0)), 'Strip: first tile': ((208, 116), (255, 0, 0)),
	'Strip: second tile': ((208, 132), (0, 255, 0)), 'Join: first tile': ((224, 116), (0, 255, 0)),
	'Join: second tile': ((217, 125), (0, 0, 255)), 'band 0': ((60, 60), (255, 0, 255)), 'band 1': ((60, 100), (0, 255, 255)),
	'band 2': ((60, 150), (255, 133, 0)), 'band 3': ((60, 200), (133, 133, 133)), 'band 0\'s line': ((32, 60), (255, 255, 255)),
	'band 1\'s line, scrolled 8': ((280, 100), (255, 255, 255)), 'Cell': ((306, 218), (255, 255, 0)),
	'Fill': ((242, 180), (255, 255, 0)), 'Hide (a hidden sprite\'s place)': ((18, 26), (0, 0, 63)), 'the backdrop colour': ((10, 100), (0, 0, 63))}
bad = 0
for n, (xy, c) in want.items():
	g = im.getpixel(xy)
	if max(abs(g[i] - c[i]) for i in range(3)) > 12:
		print('  ' + n + ' at', xy, 'is', g, 'not', c); bad = 1
sys.exit(bad)
PY
# the sound: each source by itself is heard (a build of the test with only that one)
for w in psg fm song sample; do
  sed -e "s/^Const ONLY = .*/Const ONLY = \"$w\"/" neogeo/Sound.bas > t/ng/snd_$w.bas
  ( cd t/ng && node ../../ngbuild.js snd_$w.bas --out=snd_$w.neo --vrom=A_V.BIN --songs=A_SONG.BIN --samples=A_SAMP.BIN >snd_$w.build 2>&1 )
  timeout 300 python3 ngrun.py t/ng/snd_$w.neo --frames=150 --wav=t/ng/snd_$w.wav >/dev/null 2>&1
  python3 - t/ng/snd_$w.wav <<'PY' && echo "ok   sound: $w heard, then quiet" || { echo "FAIL sound: $w"; tail -2 t/ng/snd_$w.build; fail=1; }
import sys, wave, struct
w = wave.open(sys.argv[1]); d = w.readframes(w.getnframes()); a = struct.unpack('<%dh' % (len(d) // 2), d)
r = w.getframerate() * w.getnchannels()
def pk(seg): return max(seg) - min(seg)
on = pk(a[int(r * 0.8):int(r * 1.8)]); off = pk(a[int(r * 2.35):])
if not (on > 1500 and off < on // 8): print('  the swing while playing', on, 'after Quiet', off)
sys.exit(0 if on > 1500 and off < on // 8 else 1)
PY
done
# the Neo Geo CD: a disc is built (not run: no Neo Geo CD emulator here)
if node ncdbuild.js $P/sieve.bas --out=t/ng/cd.cue >t/ng/cd.build 2>&1 && [ -s t/ng/cd.cue ]; then echo "ok   neocd: a disc builds (not run)"; else echo "FAIL neocd build"; tail -4 t/ng/cd.build; fail=1; fi
[ $fail == 0 ] && echo "ALL PASS (neogeo)" || echo "SOME FAILED (neogeo)"

# the C64's own checks (sourced by c64regress.sh: run name expected [runner options] -- files)
run stress "l=1275000 k=240000 m=60000 " -- c64/Stress.bas
run input "\[Hi There\]246" '--keys=+20:Hi There\n' '--keys=+160:123\n' '--keys=+220:a' '--hold=+250:down,6' '--hold=+280:return,6' -- c64/Input.bas
run keys "key 241" '--keys=+20:x\n' '--keys=+60:1\n' '--keys=+100:a' '--hold=+130:down,6' '--hold=+160:return,6' -- c64/Input.bas
run joy "^0 17 238 255" '--joy=+1:uf,200' -- c64/Joy.bas
run reu "banks=8 k=512" -- c64/Reu.bas
run reu_block "block=10" -- c64/Reu.bas
run reu_bytes "bytes=77,12345,111" -- c64/Reu.bas
run reu_fill "fill=65,65,66,66,32" -- c64/Reu.bas
run reu_swap "swap=999,0" -- c64/Reu.bas
run reu_128k "banks=2 k=128" --reu=128kB -- c64/Reu.bas
run reu_16m "banks=256 k=16384" --reu=16384kB -- c64/Reu.bas
# no REU: the message, and BASIC again
o=$(python3 c64run.py t/c64/reu.prg --reu=none --frames=400 --screen 2>&1)
if echo "$o" | grep -q "THIS PROGRAM NEEDS AN REU"; then echo "ok   noreu"; n_ok=$((n_ok+1)); else echo "FAIL noreu"; fail=1; fi
run tasks "ids=123 count=4" -- c64/Tasks.bas
run tasks_turns "turns=100100" -- c64/Tasks.bas
run tasks_end "s=once count=4" -- c64/Tasks.bas
run tasks_stop "after stop=102152" -- c64/Tasks.bas
run tasks_sleep "slept=-1 sleeper=-1" -- c64/Tasks.bas
run vic "addr=E400,E7C0,F000,FF80" -- c64/Vic.bas
run vic_spr "spr=44,120,4,5,147,196,7" -- c64/Vic.bas
run vic_reg "reg=4,4,0,4,4,32" -- c64/Vic.bas
run vic_off "off=0 chr=EC00 ras=-1" -- c64/Vic.bas
run sid "sid ok" -- c64/Vic.bas
# from a disc: a data file into the REU (Disk.LoadReu), a --split build (the thread a file of
# its own), a program bigger than a PRG can be (a 62K thread)
rund() { # name expected -- c64build options and files...
  local n=$1 e=$2; shift 3
  if ! node c64build.js "$@" --out=t/c64/$n.prg --log --d64 >t/c64/$n.build 2>&1; then echo "FAIL $n (build)"; tail -5 t/c64/$n.build; fail=1; return; fi
  o=$(timeout 900 python3 c64run.py t/c64/$n.D64 --frames=60000 --untilend --log 2>&1)
  if echo "$o" | grep -q "$e"; then echo "ok   $n"; n_ok=$((n_ok+1)); else echo "FAIL $n"; echo "$o" | tail -4; fail=1; fi
}
node -e "var b=Buffer.alloc(1000);for(var i=0;i<1000;i++)b[i]=(i*3)&255;require('fs').writeFileSync('t/c64/DATA.BIN',b)"
rund disk "blocks=8 last=104" -- c64/Disk.bas --add=t/c64/DATA.BIN
if echo "$o" | grep -q "first=128" && echo "$o" | grep -q "tail=104" && echo "$o" | grep -q "none=0" && echo "$o" | grep -q "ticks=-1"; then echo "ok   disk_data"; n_ok=$((n_ok+1)); else echo "FAIL disk_data"; fail=1; fi
rund split "163 tests, 0 failed" -- $P/c64_test/Main.bas $P/c64_test/Counter.cls --split
big=$(node c64/genbig.js 320 t/c64/Big.bas)
rund big "pieces=972 total=$big x=0" -- t/c64/Big.bas --split
run reu_rect "rect=21,37,38,71" -- c64/Reu.bas
run reu_rectback "back=21,23,37,71" -- c64/Reu.bas
run held "held=-10-1" '--hold=+5:p,200' '--hold=+5:space,200' -- c64/Held.bas
# the samples build
for s in tasks world film sprites dungeon; do
  if node c64build.js $P/c64_$s/Main.bas --out=t/c64/s_$s.prg >t/c64/s_$s.build 2>&1; then echo "ok   sample_$s"; n_ok=$((n_ok+1)); else echo "FAIL sample_$s (build)"; tail -5 t/c64/s_$s.build; fail=1; fi
done
run vic_scroll "scr=20,18,11,12" -- c64/Vic.bas
run vic_scrolloff "scroff=8,27" -- c64/Vic.bas
# Option Lot: code in lots of the REU, each with its own workspace
L="c64/lots/Main.bas c64/lots/Shared.cls c64/lots/Stage1.cls c64/lots/Stage2.cls"
run lots "total=34 calls=3" -- $L
run lots_vars1 "say one/ 302/ 20" -- $L
run lots_vars2 "say two: 3001: 2" -- $L
run lots_512k "lots=5" -- $L
run lots_256k "lots=2" --reu=256kB -- $L
o=$(python3 c64run.py t/c64/lots.prg --reu=128kB --frames=400 --screen 2>&1)
if echo "$o" | grep -q "THIS PROGRAM NEEDS A BIGGER REU"; then echo "ok   lots_small"; n_ok=$((n_ok+1)); else echo "FAIL lots_small"; fail=1; fi
rund lots_split "say two: 3001: 2" -- $L --split
run lots_task "worker=5 w....." -- c64/lots2/Main.bas c64/lots2/Worker.cls c64/lots2/Other.cls
run lots_task2 "other=5 +++++" -- c64/lots2/Main.bas c64/lots2/Worker.cls c64/lots2/Other.cls
run lots_task3 "tasks=1" -- c64/lots2/Main.bas c64/lots2/Worker.cls c64/lots2/Other.cls
if node c64build.js c64/lotbad/Main.bas c64/lotbad/Bad.cls --out=t/c64/lotbad.prg 2>&1 | grep -q "can take no parameters"; then echo "ok   lots_refused"; n_ok=$((n_ok+1)); else echo "FAIL lots_refused"; fail=1; fi
C=$P/c64_lots
run sample_lots "score 115  title shown 1 time" -- $C/Main.bas $C/Game.cls $C/Title.cls $C/Stage1.cls $C/Stage2.cls
# a 120K program in two lots, each lot's code in two REU banks (a --split build from disc)
mkdir -p t/c64/biglots
bigl=$(node c64/genlots.js 250 t/c64/biglots)
rund lots_big "biga=$((bigl*2)) x=0 runs=2" -- t/c64/biglots/Main.bas t/c64/biglots/BigA.cls t/c64/biglots/BigB.cls --split
if echo "$o" | grep -q "bigb=$((bigl*3)) x=0 runs=1"; then echo "ok   lots_big_b"; n_ok=$((n_ok+1)); else echo "FAIL lots_big_b"; fail=1; fi

#!/bin/bash
# realcpcbin.sh NAME platform file.bas [more files] - compile, assemble (AMSDOS header) and put
# NAME.BIN (and any overlay .PAG) on t.dsk in the current folder, for realcpc. Scratch tool.
# Then: realcpc t.dsk script out_   with a script line like:  3 type run"name\n
N=$1; P=$2; shift 2
T=$(cd "$(dirname "$0")" && pwd)
node $T/cli.js "$@" --platform=$P --amsdos=$N > $N.ASM 2> $N.err; grep ERR $N.err
sjasmplus --nologo --msg=err $N.ASM >/dev/null || echo ASM FAIL
rm -f t.dsk; dskform -type dsk -format cpcdata t.dsk >/dev/null 2>&1
for f in $N.BIN *.PAG; do [ -f "$f" ] && cpmcp -f cpcdata -T dsk t.dsk $f 0:$f; done
rm -f *.PAG

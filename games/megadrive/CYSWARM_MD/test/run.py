#!/usr/bin/env python3
# run.py - runs build/CYSWARM.md on the Genesis Plus GX libretro core through NTC's test/mdrun.py
# (c) 2026 Cyborg Unicorn Pty Ltd
#
#   python3 test/run.py [mdrun.py's options: --frames=N --pad=100:S,104:- --shot=out.png ...]
#
# NTC_SRC: NTC's src folder (else ../ntc/src next to this folder); NTC_MDCORE: the core (see
# NTC's docs/md.md for building it with the VDP's memory exported).
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
game = os.path.join(here, '..')
ntc = os.environ.get('NTC_SRC') or next((p for p in (os.path.join(game, '..', 'ntc', 'src'), os.path.join(game, '..', '..', 'ntc', 'src')) if os.path.exists(os.path.join(p, 'test', 'mdrun.py'))), None)
if not ntc:
	sys.exit('NTC not found: set NTC_SRC to its src folder')
sys.exit(subprocess.call([sys.executable, os.path.join(ntc, 'test', 'mdrun.py'), os.path.join(game, 'build', 'CYSWARM.md')] + sys.argv[1:]))

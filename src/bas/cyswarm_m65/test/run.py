#!/usr/bin/env python3
# run.py - runs build/CYSWARM.PRG on the Xemu MEGA65 emulator through NTC's test/m65run.py
# (c) 2026 Cyborg Unicorn Pty Ltd
#
#   python3 test/run.py [m65run.py's options: --frames=N --joy=100:F,104:- --shot=out.png ...]
#
# NTC_SRC: NTC's src folder (else ../ntc/src next to this folder, or ../.. when it's NTC's
# bas/cyswarm_m65); NTC_XEMU: xmega65 built with NTC's test driver (see NTC's docs/m65.md).
import os
import subprocess
import sys

# NTC's test folder: beside its src/ (src/test/ in an older NTC)
def ntctest(src):
	t = os.path.join(src, '..', 'test')
	return t if os.path.exists(os.path.join(t, 'm65run.py')) else os.path.join(src, 'test')

here = os.path.dirname(os.path.abspath(__file__))
game = os.path.join(here, '..')
ntc = os.environ.get('NTC_SRC') or next((p for p in (os.path.join(game, '..', 'ntc', 'src'), os.path.join(game, '..', '..', 'ntc', 'src'), os.path.join(game, '..', '..')) if os.path.exists(os.path.join(p, '..', 'test', 'm65run.py')) or os.path.exists(os.path.join(p, 'test', 'm65run.py'))), None)
if not ntc:
	sys.exit('NTC not found: set NTC_SRC to its src folder')
sys.exit(subprocess.call([sys.executable, os.path.join(ntctest(ntc), 'm65run.py'), os.path.join(game, 'build', 'CYSWARM.PRG')] + sys.argv[1:]))

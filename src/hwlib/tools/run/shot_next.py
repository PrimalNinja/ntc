# shot_next.py - a Next test in ZEsarUX (next, or cube_next): screenshots after a few seconds
import sys, os, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('ZESARUX', '/tmp/claude-0/-home-claude/ac607555-f87f-5ddd-b185-d83b7802f0e0/scratchpad/zesarux/src/zesarux')
import zx
zx.ZBIN = os.environ['ZESARUX']
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
name = sys.argv[1] if len(sys.argv) > 1 else 'next'
z = zx.Zx(os.path.join(R, 'build', name, name.upper().replace('_', '')[:8] + '.NEX'), port=15301, wait=6)
os.makedirs(os.path.join(R, 'build', 'shots'), exist_ok=True)
for i in range(3):
    z.shot(os.path.join(R, 'build', 'shots', '%s_%d.png' % (name, i)), full=True); time.sleep(0.7)
z.close()

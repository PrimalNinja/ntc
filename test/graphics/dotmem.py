# dotmem.py - gfx.bas as a ZX Spectrum Next dot command (zxndot, zxndotl) on test/dotrun.py's
# NextZXOS stand-in; the Spectrum's screen (bank 5: #4000-#57FF) compared with expect.py.
#   python3 test/graphics/dotmem.py zxndot|zxndotl
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, subprocess, tempfile, io, contextlib
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(HERE, '..')); sys.path.insert(0, HERE)
import cpcrun, dotrun, expect

def main():
    plat = sys.argv[1]; d = tempfile.mkdtemp(prefix='gfx-'); asm = os.path.join(d, 'g.asm')
    r = subprocess.run(['node', os.path.join(HERE, '..', 'cli.js'), os.path.join(HERE, 'gfx.bas'), '--platform=' + plat, '--name=GFX'], capture_output=True, text=True)
    if 'ERR ' in r.stderr: print(r.stderr); return 1
    open(asm, 'w').write(r.stdout)
    b, syms = cpcrun.assemble(asm)
    os.environ.setdefault('NTC_LIMIT', '3000')
    with contextlib.redirect_stdout(io.StringIO()): z = dotrun.run(asm, syms, '')
    scr = z.m.memory[0x4000:0x5800] if z.mmu[2] == 10 else z.page(10)[:0x1800]
    lit = set()
    for y in range(192):
        for x in range(256):
            a = (y // 64) * 2048 + (y & 7) * 256 + ((y // 8) & 7) * 32 + x // 8
            if scr[a] & (128 >> (x & 7)): lit.add((x, y))
    return 0 if expect.check(plat, lit, 256, 192) else 1
sys.exit(main())

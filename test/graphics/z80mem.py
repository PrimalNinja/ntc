# z80mem.py - gfx.bas for a Z80 platform with no emulator in NTC's tests (trs80, system80, ti83,
# and the picture-in-memory class of test and baremetal - the PCW16's is the same file):
# compiled, assembled, run on the Z80 core alone, and the screen memory compared with expect.py.
# The TI-83 Plus's OS calls (rst #28, dw routine) are skipped.
#   python3 test/graphics/z80mem.py trs80|system80|ti83|test|baremetal
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, re, subprocess, tempfile
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(HERE, '..')); sys.path.insert(0, HERE)
import z80, cpcrun, expect

def main():
    plat = sys.argv[1]; d = tempfile.mkdtemp(prefix='gfx-'); asm = os.path.join(d, 'g.asm')
    r = subprocess.run(['node', os.path.join(HERE, '..', 'cli.js'), os.path.join(HERE, 'gfx.bas'), '--platform=' + plat], capture_output=True, text=True)
    if 'ERR ' in r.stderr: print(r.stderr); return 1
    open(asm, 'w').write(r.stdout)
    b, syms = cpcrun.assemble(asm)
    org = int(re.search(r'^\s*org\s+#([0-9A-Fa-f]+)', r.stdout, re.M).group(1), 16)
    m = z80.Z80Machine(); m.set_memory_block(org, b)
    if plat == 'ti83': m.set_memory_block(0x28, bytes([0xE3, 0x23, 0x23, 0xE3, 0xC9]))        # rst #28: skip the routine's word
    if plat in ('trs80', 'system80'): m.set_memory_block(0x3C00, bytes([32]) * 1024)
    m.pc = syms.get('ntc_start', org)
    for i in range(4000):
        m.ticks_to_stop = 100000; m.run()
    mem = m.memory; lit = set()
    if plat in ('trs80', 'system80'):
        for cy in range(16):
            for cx in range(64):
                v = mem[0x3C00 + cy * 64 + cx]
                if v >= 128:
                    for k in range(6):
                        if v & (1 << k): lit.add((cx * 2 + (k & 1), cy * 3 + k // 2))
        return 0 if expect.check(plat, lit, 128, 48, (0, 0, 31, 2)) else 1
    if plat in ('test', 'baremetal'):                              # the picture in memory (Graphics.Buffer())
        a = syms['arr_graphics_m_pic']
        for y in range(200):
            for x in range(320):
                if mem[a + y * 40 + x // 8] & (128 >> (x & 7)): lit.add((x, y))
        return 0 if expect.check(plat, lit, 320, 200) else 1
    for y in range(64):
        for x in range(96):
            if mem[0x9340 + y * 12 + x // 8] & (128 >> (x & 7)): lit.add((x, y))
    return 0 if expect.check(plat, lit, 96, 64) else 1
sys.exit(main())

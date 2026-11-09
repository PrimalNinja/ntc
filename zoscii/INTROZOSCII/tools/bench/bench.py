# bench.py - times a hand-coded NTC ZOSCII speed test (Z80, T-states) in the z80 module
#   python3 tools/bench/bench.py tools/bench/speed_orig.asm [iterations]
# CPC timing: T-states / 4 MHz (the CPC's wait states make real hardware somewhat slower)
import sys, os, re, subprocess, tempfile
import z80
SJ = os.environ.get('SJASMPLUS', 'sjasmplus')
src = os.path.abspath(sys.argv[1])
d = tempfile.mkdtemp()
subprocess.run([SJ, '--nologo', '--raw=' + d + '/o.bin', '--sym=' + d + '/o.sym', src], check=True, cwd=d)
b = open(d + '/o.bin', 'rb').read()
sy = {}
for l in open(d + '/o.sym'):
    m = re.match(r'(\w+):\s+EQU\s+0x([0-9A-Fa-f]+)', l)
    if m: sy[m.group(1)] = int(m.group(2), 16)
m = z80.Z80Machine()
mem = bytearray(65536); mem[0x2000:0x2000 + len(b)] = b
mem[0xF000] = 0x00; mem[0xF001] = 0xFF; mem[0xFF00] = 0x76
mem[0xBE80] = mem[0xBE81] = mem[0xBE82] = 1
m.set_memory_block(0, bytes(mem)); m.pc = 0x2000; m.sp = 0xF000
bps = {}
for n in ['bp_beforeprepare', 'bp_afterprepare', 'bp_beforeencode', 'bp_afterencode', 'bp_beforedecode', 'bp_afterdecode']:
    bps[sy[n]] = n; m.set_breakpoint(sy[n])
m.set_breakpoint(0xFF00)
BIG = 10 ** 9
m.ticks_to_stop = BIG
t = {}
for i in range(100000):
    ev = m.run()
    if m.halted or m.pc == 0xFF00: break
    if ev & 1 and m.pc in bps:
        t[bps[m.pc]] = BIG - m.ticks_to_stop
        if bps[m.pc] == 'bp_beforeencode' and os.environ.get('ZERO_RNG'):
            m.memory[sy['rng_state']] = 0; m.memory[sy['rng_state'] + 1] = 0
    m.step_over_breakpoint()
it = int(sys.argv[2]) if len(sys.argv) > 2 else 5
for a, z, nm in [('bp_beforeprepare', 'bp_afterprepare', 'prepare'), ('bp_beforeencode', 'bp_afterencode', 'encode'), ('bp_beforedecode', 'bp_afterdecode', 'decode')]:
    if a in t and z in t:
        T = t[z] - t[a]
        print('%-8s %10d T  %8.3f s @4MHz' % (nm, T, T / 4e6) + ('  %6.1f msgs/s (64 bytes)' % (it / (T / 4e6)) if nm != 'prepare' else ''))
# decode check
msg = bytes(m.memory[sy['dec_buffer']:sy['dec_buffer'] + 64]) if 'dec_buffer' in sy else bytes(m.memory[sy['dec']:sy['dec'] + 64]) if 'dec' in sy else b''
print('decoded:', msg[:16])
enc = []
if 'rom_data' in sy:
    print('decoded all A:', all(c == 65 for c in msg), ' distinct addresses in 64:', len(set(enc)), ' rom bytes = A:', sum(1 for i in range(1024) if m.memory[sy['rom_data'] + i] == 65))
else:
    print('decoded:', msg[:8], all(c == 65 for c in msg))

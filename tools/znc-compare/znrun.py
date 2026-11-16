# znrun.py BIN ORG [resultlabel=addr ...] - a flat Z80 (no interrupts): runs a ZNC raw binary, prints the T-states at each OUT (254), n
import sys, z80
b = open(sys.argv[1], 'rb').read(); org = int(sys.argv[2], 16)
m = z80.Z80Machine(); m.set_memory_block(org, b); m.pc = org; m.sp = 0xFF00
T = 0; q = 0; marks = []
def out(port, val):
    if (port & 0xFF) == 0xFE: marks.append((val, T + (q - m.ticks_to_stop)))
m.set_output_callback(out); m.set_input_callback(lambda p: 0xFF)
while not m.halted and T < 4000000000:
    q = 1000000; m.ticks_to_stop = q; m.run(); T += q - m.ticks_to_stop
for i in range(1, len(marks)): print('B%d %d' % (marks[i - 1][0], marks[i][1] - marks[i - 1][1]))
for a in sys.argv[3:]:
    n, ad = a.split('='); ad = int(ad, 16); print(n, m.memory[ad] | m.memory[ad + 1] << 8)

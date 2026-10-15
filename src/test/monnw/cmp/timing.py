# T (Z80 cycles) from boot until a marker is on the screen: old MON vs new, the same keys
import sys, os, subprocess
os.environ['NTC_RAM'] = '576'
sys.path.insert(0, '.')
import ntcrun, cpcrun
W = '~' * 40
r = subprocess.run(['node', 'cli.js', 't/cy/Main.bas', 't/cy/Hyp.cls', 't/cy/Hot.cls', 't/cy/Ent.cls', '--platform=cpcfw'], capture_output=True, text=True)
open('t/cy/Main.asm', 'w').write(r.stdout)
b, syms = cpcrun.assemble('t/cy/Main.asm')
runs = [('boot (no MON)', '', 'Control + 1'), ('index page', 'mon\n', 'Home'), ('tt home', 'mon tt.map\n', '+- T ---'), ('hex page', 'mon tt.map\n' + W * 2 + '2', '+- Hex ---'),
        ('list (Chain)', 'run 2 list\n' + W + 'mon test.map 2\n' + W * 2 + '\r', '|#8020'),
        ('text page', 'mon tt.map\n' + W * 2 + '1', '|+- T --')]
for v in sys.argv[1:] or ('OLD', 'NEW'):
    d = open('monnw/cmp/%s.COM' % v, 'rb').read(); open('t/files/A/MON.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)
    out = []
    for name, keys, mark in runs:
        h = ntcrun.Host('cpcfw', b, syms['ntc_start'], keys.replace('\n', '\r'))
        cpcrun.endkey_set(h.m, syms)
        n = 0; m = h.m
        while not m.halted and n < 40000:
            m.ticks_to_stop = 13333; cpcrun.endkey_run(h); n += 1; h.T += 13333 - m.ticks_to_stop
            steps = 0
            while not m.halted and steps < 2000:
                if m.iff1 and m.on_handle_active_int(): h.ints += 1; break
                m.ticks_to_stop = 1; cpcrun.endkey_run(h); steps += 1; h.T += 1 - m.ticks_to_stop
            if n % 10 == 0 and mark in h.scr.text(): break
        out.append('%s %.2f s' % (name, h.T / 4e6))
    print(v, ' | '.join(out))

# cpctime.py - run a program on the emulated CPC (cpcrun.py) at the real CPC's speed, and
# time it. cpcrun.py counts Z80 T states; a real CPC is slower, because the gate array
# stretches every instruction to a whole number of microseconds. This steps one instruction
# at a time, adds up the CPC's microseconds, and raises the 300 Hz interrupt every 3333
# microseconds as the real machine does - so Ticks, and anything timed with it, comes out
# as on a CPC. The frame sync (PPI port B bit 0) follows the same clock: a frame every 20 ms,
# the sync high for its first 512 us, so Frame and the double buffer flip wait as on a CPC.
# About 10x slower to run than cpcrun.py.
#
#   python3 cpctime.py prog.bas 'typed keys' [--mark=sym1,sym2...] [--ram=128] [cli.js options]
#
# Prints the screen at the end, the interrupts taken and the run time in CPC seconds; with
# --mark, every time the program reaches one of those labels (from the .sym file): the time
# from the start and from the mark before. Example (the List sort test):
#   python3 cpctime.py t/sorttime.bas '\nNX' --mark=lst_first,lst_sort
import sys, os, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cpcrun

# the time of each instruction: (Z80 T states, CPC microseconds). The CPC's gate array
# holds the Z80 so every memory access lands on a 4 T (1 microsecond) step: an instruction
# takes a whole number of microseconds, often more than T / 4. Unprefixed opcodes here;
# conditional ones and prefixes in timeof()
T = [0] * 256; N = [0] * 256
def s(op, t, n): T[op] = t; N[op] = n
for op in range(256):
    x, y, z = op >> 6, (op >> 3) & 7, op & 7
    if x == 1:
        if y == 6 or z == 6: s(op, 7, 2)
        else: s(op, 4, 1)
    elif x == 2:
        s(op, 7, 2) if z == 6 else s(op, 4, 1)
tab0 = {0x00:(4,1),0x01:(10,3),0x02:(7,2),0x03:(6,2),0x07:(4,1),0x08:(4,1),0x09:(11,3),0x0A:(7,2),0x0B:(6,2),0x0F:(4,1),
 0x11:(10,3),0x12:(7,2),0x13:(6,2),0x17:(4,1),0x18:(12,3),0x19:(11,3),0x1A:(7,2),0x1B:(6,2),0x1F:(4,1),
 0x21:(10,3),0x22:(16,5),0x23:(6,2),0x27:(4,1),0x29:(11,3),0x2A:(16,5),0x2B:(6,2),0x2F:(4,1),
 0x31:(10,3),0x32:(13,4),0x33:(6,2),0x34:(11,3),0x35:(11,3),0x36:(10,3),0x37:(4,1),0x39:(11,3),0x3A:(13,4),0x3B:(6,2),0x3F:(4,1),
 0x76:(4,1),0xC9:(10,3),0xCD:(17,5),0xC3:(10,3),0xD3:(11,3),0xDB:(11,3),0xD9:(4,1),0xE3:(19,6),0xE9:(4,1),0xEB:(4,1),
 0xF3:(4,1),0xF9:(6,2),0xFB:(4,1)}
for op in range(64):
    z = op & 7
    if z in (4, 5) and op not in tab0: tab0[op] = (4, 1)
    if z == 6 and op not in tab0: tab0[op] = (7, 2)
for op in range(0xC0, 0x100):
    z = op & 7
    if z == 1: tab0[op] = (10, 3)          # pop
    if z == 5: tab0[op] = (11, 4)          # push
    if z == 6: tab0[op] = (7, 2)           # alu n
    if z == 7: tab0[op] = (11, 4)          # rst
    if z == 2: tab0[op] = (10, 3)          # jp cc
for k, v in tab0.items(): s(k, *v)
JRCC = {0x20, 0x28, 0x30, 0x38}
def ed(op2):
    x, y, z = op2 >> 6, (op2 >> 3) & 7, op2 & 7
    if x == 1:
        return [(12,4),(12,4),(15,4),(20,6),(8,2),(14,4),(8,2),(9,3) if y < 4 else ((18,5) if y < 6 else (8,2))][z]
    if x == 2 and z < 4 and y >= 4: return (16, 5)
    return (8, 2)
HLMEM = set(op for op in range(0x40, 0xC0) if (op & 7) == 6 or ((op >> 3) & 7) == 6 and op < 0x80) - {0x76}
HLMEM |= {0x34, 0x35, 0x36}
IXT = {0x21:(14,4),0x22:(20,6),0x2A:(20,6),0x23:(10,3),0x2B:(10,3),0xE1:(14,4),0xE5:(15,5),0xE3:(23,7),0xE9:(8,2),0xF9:(10,3),
       0x09:(15,4),0x19:(15,4),0x29:(15,4),0x39:(15,4),0x36:(19,6),0x34:(23,6),0x35:(23,6)}


def timeof(m, mem, pc, op, op2, step):
    # step() has run the instruction at pc (op, op2 its first bytes): its time
    if op in (0xDD, 0xFD):
        if m.pc == ((pc + 1) & 0xFFFF): step()
        if op2 == 0xCB:
            t, n = (20, 6) if (mem[(pc + 3) & 0xFFFF] >> 6) == 1 else (23, 7)
        elif op2 in IXT: t, n = IXT[op2]
        elif op2 in HLMEM: t, n = 19, 5
        else: t, n = T[op2] + 4, N[op2] + 1
    elif op == 0xCB:
        if (op2 & 7) == 6: t, n = ((12, 3) if (op2 >> 6) == 1 else (15, 4))
        else: t, n = 8, 2
    elif op == 0xED:
        t, n = ed(op2)
        if op2 in (0xB0, 0xB8, 0xB1, 0xB9) and m.pc == pc: t, n = 21, 6
    elif op in JRCC:
        t, n = ((12, 3) if m.pc != ((pc + 2) & 0xFFFF) else (7, 2))
    elif op == 0x10:
        t, n = ((13, 4) if m.pc != ((pc + 2) & 0xFFFF) else (8, 3))
    elif (op & 0xC7) == 0xC0:
        t, n = ((11, 4) if m.pc != ((pc + 1) & 0xFFFF) else (5, 2))
    elif (op & 0xC7) == 0xC4:
        t, n = ((17, 5) if m.pc != ((pc + 3) & 0xFFFF) else (10, 3))
    else:
        t, n = T[op], N[op]
    if t == 0: t, n = 4, 1
    return n

def main():
    bas = sys.argv[1]
    typed = (sys.argv[2] if len(sys.argv) > 2 else '').replace('\\n', '\r').replace('\\x7f', '\x7f')
    marks = []; extra = []
    for a in sys.argv[3:]:
        if a.startswith('--ram='): os.environ['NTC_RAM'] = a[6:]
        elif a.startswith('--mark='): marks += [x for x in a[7:].split(',') if x]
        else: extra.append(a)
    asm = bas[:-4] + '.asm'
    here = os.path.dirname(os.path.abspath(__file__))
    r = subprocess.run(['node', os.path.join(here, 'cli.js'), bas] + extra, capture_output=True, text=True)
    if r.stderr: print(r.stderr)
    open(asm, 'w').write(r.stdout)
    b, syms = cpcrun.assemble(asm)
    c = cpcrun.CPC(b, syms.get('ntc_start', 0x4000), typed, syms)
    watch = {}
    for nm in marks:
        if nm in syms: watch[syms[nm]] = nm
        else: print('no label', nm)
    m = c.m; mem = m.memory
    # the vertical sync by the clock, as on a CPC: a frame every 20 ms, the sync (PPI port B
    # bit 0) high for its first 512 us, and the interrupt after it 2 lines (128 us) in
    now = [0.0]
    old_inp = c.inp
    def inp(port):
        if (port >> 8) & 0xff == 0xf5:
            return 1 if (now[0] + 128 - 3333.33) % 20000 < 512 else 0
        return old_inp(port)
    m.set_input_callback(inp)
    def step():
        m.ticks_to_stop = 1; cpcrun.endkey_run(c)
    us = 0; nextint = 3333.33; pend = False; hits = []
    while not m.halted and us < 1e9:
        pc = m.pc
        if pc in watch: hits.append((watch[pc], us))
        op = mem[pc]; op2 = mem[(pc + 1) & 0xFFFF]
        now[0] = us
        step()
        us += timeof(m, mem, pc, op, op2, step)
        if us >= nextint: nextint += 3333.33; pend = True
        if pend and m.iff1 and m.on_handle_active_int(): pend = False; us += 5; c.ints += 1
    print(c.screen(cpcrun.loadfont(syms, m.memory)))
    print('--- halted' if m.halted else '--- NOT halted', 'ints=%d' % c.ints, 'CPC time %.2f s' % (us / 1e6))
    last = 0
    for nm, t in hits:
        print('%-20s %9.3f s  +%.3f s' % (nm, t / 1e6, (t - last) / 1e6)); last = t

if __name__ == '__main__':
    main()

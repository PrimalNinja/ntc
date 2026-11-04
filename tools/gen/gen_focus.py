#!/usr/bin/env python3
# gen_focus.py - a MINIMAL NTC BASIC corpus for GEN: a handful of complete, correct short programs,
# each varying only a number (and a name), repeated hard. A 100K-weight net memorises these shapes
# cleanly, so after a program's opening it writes the one continuation it has seen and terminates
# with a form feed - no char-level garble, no greedy loop. The point of the demo: the net writes a
# whole, valid, terminating NTC program. (A varied corpus needs a far bigger model - see
# cyborgos-generative.md section 4; that is the roadmap, this is what one slot can show.)
#   python3 tools/gen/gen_focus.py OUTDIR
# Writes OUTDIR/basic.txt and OUTDIR/asm.txt (a copy; train with --asm-share 0).
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, random
random.seed(5)
out = sys.argv[1]; os.makedirs(out, exist_ok=True)
H = "' a program\nOption Explicit\n"
N = ['5', '8', '10', '16', '20', '32', '50', '100']

def count():   # For / Next
    v, n = random.choice(['i', 'j', 'k']), random.choice(N)
    return H + "Dim %s As Integer\nFor %s = 1 To %s\n  Print %s\nNext" % (v, v, n, v)

def whileup():
    v, n = random.choice(['i', 'n']), random.choice(N)
    return H + "Dim %s As Integer\n%s = 0\nWhile %s < %s\n  %s = %s + 1\n  Print %s\nWend" % (v, v, v, n, v, v, v)

def hello():
    return H + "Print \"hello\"\nPrint \"world\""

def addp():
    a, b = random.choice(N), random.choice(N)
    return H + "Dim n As Integer\nn = %s\nPrint n + %s" % (a, b)

def submain():
    n = random.choice(N)
    return H + "Sub Main()\n  Dim i As Integer\n  For i = 1 To %s\n    Print i\n  Next\nEnd Sub" % n

KINDS = [count, whileup, hello, addp, submain]
progs = [random.choice(KINDS)() for _ in range(3000)]
text = '\f'.join(progs)
open(os.path.join(out, 'basic.txt'), 'w').write(text)
open(os.path.join(out, 'asm.txt'), 'w').write(text[:20000])
print('gen_focus: %d programs, %d bytes, %d kinds' % (len(progs), len(text), len(KINDS)))

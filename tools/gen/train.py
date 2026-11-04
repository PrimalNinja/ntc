#!/usr/bin/env python3
# train.py - trains GEN's ternary GRU on the corpus (corpus.py's basic.txt and asm.txt) and writes
# the model the Z80 runs. Quantisation-aware from the first step: the forward pass is the integer
# one (qgru.py), so nothing is lost at export.
#   python3 tools/gen/train.py CORPUSDIR OUTDIR [--steps 3000] [--hidden 96] [--embed 32]
#                              [--seq 96] [--batch 32] [--lr 2e-3] [--resume OUTDIR/gen.pt]
# Writes OUTDIR/gen.pt (the checkpoint), OUTDIR/GEN.MDL (the Z80's file), OUTDIR/charset.txt,
# and prints the loss and a sample (from the exact integer model) every 200 steps.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys, os, time, argparse, random
import numpy as np, torch
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qgru import QGRU, IntModel

ap = argparse.ArgumentParser()
ap.add_argument('corpus'); ap.add_argument('out')
ap.add_argument('--steps', type=int, default=3000); ap.add_argument('--hidden', type=int, default=96)
ap.add_argument('--embed', type=int, default=32); ap.add_argument('--seq', type=int, default=96)
ap.add_argument('--batch', type=int, default=32); ap.add_argument('--lr', type=float, default=2e-3)
ap.add_argument('--resume', default=None); ap.add_argument('--seed', type=int, default=1)
ap.add_argument('--asm-share', type=float, default=0.33, help='the share of batches from asm.txt')
ap.add_argument('--report', type=int, default=200)
ap.add_argument('--losstemp', type=float, default=16.0, help='logits are divided by this before cross-entropy (gradient shaping only - does not change the exported integer model); lower = sharper, stronger gradient')
ap.add_argument('--trits', type=int, default=1, help='balanced trits per weight (1 ternary, 2 -> 9 levels, 4 -> 81 ...); more = finer weights, still multiply-free')
a = ap.parse_args()
torch.manual_seed(a.seed); random.seed(a.seed); np.random.seed(a.seed)
os.makedirs(a.out, exist_ok=True)

# the charset: every printable ASCII character, the newline and the form feed (a program's end)
charset = [chr(i) for i in range(32, 127)] + ['\n', '\f']
idx = {c: i for i, c in enumerate(charset)}
def load(name):
    t = open(os.path.join(a.corpus, name), encoding='latin-1').read()
    return np.array([idx.get(c, 0) for c in t], dtype=np.int64)
texts = {'basic': load('basic.txt'), 'asm': load('asm.txt')}
print('corpus: basic %d, asm %d characters; vocabulary %d' % (len(texts['basic']), len(texts['asm']), len(charset)))

model = QGRU(len(charset), a.embed, a.hidden, 2, trits=a.trits)
opt = torch.optim.Adam(model.parameters(), lr=a.lr)
step0 = 0
if a.resume and os.path.exists(a.resume):
    ck = torch.load(a.resume); model.load_state_dict(ck['model']); opt.load_state_dict(ck['opt']); step0 = ck['step']
    print('resumed at step', step0)
nparams = sum(p.numel() for p in model.parameters())
print('parameters: %d (ternary weights %d)' % (nparams, sum(c.ih.w.numel() + c.hh.w.numel() for c in model.cells) + model.out.w.numel()))

def batch():
    src = texts['asm'] if random.random() < a.asm_share else texts['basic']
    starts = np.random.randint(0, len(src) - a.seq - 1, size=a.batch)
    x = np.stack([src[s:s + a.seq] for s in starts]); y = np.stack([src[s + 1:s + a.seq + 1] for s in starts])
    return torch.tensor(x), torch.tensor(y)

def save(step):
    torch.save({'model': model.state_dict(), 'opt': opt.state_dict(), 'step': step}, os.path.join(a.out, 'gen.pt'))
    open(os.path.join(a.out, 'charset.txt'), 'w').write(''.join(charset))
    if a.trits == 0:
        return None, 0                               # float master: no integer model to export
    im = IntModel(model)
    n = im.write(os.path.join(a.out, 'GEN.MDL'), charset)
    return im, n

t0 = time.time(); lsum = 0; lcnt = 0
for step in range(step0 + 1, a.steps + 1):
    x, y = batch()
    logits, _ = model(x)
    loss = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]) / a.losstemp, y.reshape(-1))
    opt.zero_grad(); loss.backward()
    torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
    opt.step()
    lsum += loss.item(); lcnt += 1
    if step % a.report == 0 or step == a.steps:
        im, n = save(step)
        print('step %d  loss %.3f  %.1f s  model %d bytes' % (step, lsum / lcnt, time.time() - t0, n), flush=True)
        if im is not None:
            print('---\n' + im.generate("' a program\nOption Explicit\nDim i As Integer\n", 160, charset).replace('\f', '<FF>') + '\n---', flush=True)
        lsum = 0; lcnt = 0
print('done')

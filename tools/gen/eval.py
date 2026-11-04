#!/usr/bin/env python3
# eval.py - measure a trained model (a gen.pt from train.py): bits/char on a corpus and a set of
# keyword-completion probes, so k=1 / k=2 / k=8 / float can be compared at a held width. bits/char
# is the cross-entropy in bits at the training temperature (--losstemp), the same objective
# training minimised; lower is better, the float master is the floor.
#   python3 tools/gen/eval.py CKPT.pt --hidden H --trits K --corpus DIR [--losstemp 6]
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys, os, argparse, math, numpy as np, torch
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qgru import QGRU

ap = argparse.ArgumentParser()
ap.add_argument('ckpt'); ap.add_argument('--hidden', type=int, default=64); ap.add_argument('--embed', type=int, default=32)
ap.add_argument('--trits', type=int, default=2); ap.add_argument('--corpus', required=True)
ap.add_argument('--losstemp', type=float, default=6.0); ap.add_argument('--seq', type=int, default=128)
ap.add_argument('--maxwin', type=int, default=150, help='cap the number of windows scored (speed)')
a = ap.parse_args()

charset = [chr(i) for i in range(32, 127)] + ['\n', '\f']
idx = {c: i for i, c in enumerate(charset)}
m = QGRU(len(charset), a.embed, a.hidden, 2, trits=a.trits)
m.load_state_dict(torch.load(a.ckpt, map_location='cpu')['model']); m.eval()

# bits/char on the corpus (teacher-forced, non-overlapping windows)
text = open(os.path.join(a.corpus, 'basic.txt'), encoding='latin-1').read()
data = np.array([idx.get(c, 0) for c in text], dtype=np.int64)
tot_bits = 0.0; tot = 0
with torch.no_grad():
    for wi, s in enumerate(range(0, len(data) - a.seq - 1, a.seq)):
        if wi >= a.maxwin: break
        x = torch.tensor(data[s:s + a.seq][None, :]); y = torch.tensor(data[s + 1:s + a.seq + 1][None, :])
        logits, _ = m(x)
        logp = torch.log_softmax(logits.reshape(-1, logits.shape[-1]) / a.losstemp, dim=-1)
        tot_bits += float(-logp[range(a.seq), y.reshape(-1)].sum()) / math.log(2); tot += a.seq
bpc = tot_bits / tot

# keyword-completion probes: feed the prompt, greedy-generate, check the expected token appears next
def complete(prompt, n=12):
    with torch.no_grad():
        hs = None; seq = [idx.get(c, 0) for c in prompt]
        x = torch.tensor([seq]); logits, hs = m(x); out = []
        c = int(logits[0, -1].argmax())
        for _ in range(n):
            out.append(charset[c]); logits, hs = m(torch.tensor([[c]]), hs); c = int(logits[0, -1].argmax())
        return ''.join(out)
probes = [
    ("' a program\nOption Explicit\nDim i As Integer\nFor i = 1 To 10\n", "Print"),
    ("' a program\nOption Explicit\nDim i As Integer\nFor i = 1 To 10\n  Print i\n", "Next"),
    ("' a program\nOption Explicit\nSub Main()\n", "Dim"),
    ("' a program\nOption Explicit\nDim n As Integer\nn = 10\n", "Print"),
    ("' a program\nOption Explicit\nDim i As Integer\ni = 0\nWhile i < 10\n", "i ="),
]
hits = 0
print('%s  (H=%d, trits=%d)' % (a.ckpt, a.hidden, a.trits))
print('bits/char: %.3f' % bpc)
print('keyword completions:')
for pr, want in probes:
    got = complete(pr); ok = got.lstrip().startswith(want) or want in got[:len(want) + 3]
    hits += ok
    print('  %-7s %s  %r' % (('[ok]' if ok else '[miss]'), want, got))
print('keyword: %d/%d' % (hits, len(probes)))

#!/usr/bin/env python3
# mktest.py - the small model and its expected output for NTC's regression (test/net_t.bas): a
# 2-layer ternary GRU, 8 embedding, 16 hidden, trained a few steps on a short text so its weights
# mean something, written as test/net_t.mdl; the exact integer model then generates 48 characters
# after a prompt, written as test/net_t.txt. The Z80 must print the same 48 characters.
#   python3 tools/gen/mktest.py
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, random, numpy as np, torch
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qgru import QGRU, IntModel
HERE = os.path.dirname(os.path.abspath(__file__)); TEST = os.path.join(HERE, '..', '..', 'test')
torch.manual_seed(3); random.seed(3); np.random.seed(3)
charset = [chr(i) for i in range(32, 127)] + ['\n', '\f']
idx = {c: i for i, c in enumerate(charset)}
text = ("Dim i As Integer\nFor i = 1 To 10\n  Print i\nNext\n" * 40)
data = np.array([idx[c] for c in text], dtype=np.int64)
m = QGRU(len(charset), 8, 16, 2, trits=8)   # k=8: exercises the 8-plane 32-bit Horner path on the Z80 (subsumes k<8)
opt = torch.optim.Adam(m.parameters(), lr=3e-3)
for step in range(60):
    starts = np.random.randint(0, len(data) - 33, size=16)
    x = torch.tensor(np.stack([data[s:s + 32] for s in starts])); y = torch.tensor(np.stack([data[s + 1:s + 33] for s in starts]))
    logits, _ = m(x)
    loss = torch.nn.functional.cross_entropy(logits.reshape(-1, logits.shape[-1]) / 16.0, y.reshape(-1))
    opt.zero_grad(); loss.backward(); opt.step()
im = IntModel(m)
n = im.write(os.path.join(TEST, 'net_t.mdl'), charset)
prompt = "Dim i As Integer\nFor i = 1 To 10\n"
out = im.generate(prompt, 48, charset)
open(os.path.join(TEST, 'net_t.txt'), 'w').write(out)
print('model %d bytes, loss %.3f' % (n, loss.item()))
print(repr(out))

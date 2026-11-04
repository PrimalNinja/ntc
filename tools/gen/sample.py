#!/usr/bin/env python3
# sample.py - read a GEN.MDL (the packed ternary GRU) back and generate from it on the PC, with
# the exact integer arithmetic the Z80 runs (qgru.py's IntModel.step), so the text here is the
# text GEN / GRU prints on a CPC at noise 0, byte for byte (test/net_t proves the two agree).
#   python3 tools/gen/sample.py MODEL.MDL [-n 160] ["prompt" ["prompt" ...]]
# No prompt: a few built-in ones. \n in a prompt is a newline; output shows <FF> for a form feed.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys, os, argparse, numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qgru import IntModel, S, TANH_T, SIGM_T

def unpack4(buf, rows, cols):
    # cols is a multiple of 4; each byte holds 4 trits, trit j in bits 2j, code 3 = -1
    b = np.frombuffer(buf, dtype=np.uint8).reshape(rows, cols // 4).astype(np.int8)
    out = np.zeros((rows, cols), dtype=np.int8)
    for j in range(4):
        code = (b >> (2 * j)) & 3
        out[:, j::4] = np.where(code == 3, -1, np.where(code == 1, 1, 0))
    return out

def unpackK(d, p, R, n, K):
    # K planes, ROW-interleaved: for each row, its K plane-chunks (n/4 bytes each). Returns
    # (list of K (R,n) arrays, bytes consumed). Matches qgru.packK.
    row = n // 4
    planes = [np.zeros((R, n), dtype=np.int8) for _ in range(K)]
    for r in range(R):
        for j in range(K):
            planes[j][r] = unpack4(d[p:p + row], 1, n)[0]; p += row
    return planes, p

def load_mdl(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'GENM', 'not a GENM model'
    ver = d[4]
    assert ver in (1, 2), 'unknown GENM version %d' % ver
    V, E, H, L = d[5], d[6], d[7], d[8]
    p = 9; K = 1
    if ver == 2:
        K = d[9]; p = 10
    charset = [chr(c) for c in d[p:p + V]]; p += V
    embed = np.frombuffer(d[p:p + V * E], dtype=np.int8).reshape(V, E); p += V * E
    cells = []
    for l in range(L):
        wi = E if l == 0 else H
        kih, khh = d[p], d[p + 1]; p += 2
        wih, p = unpackK(d, p, 3 * H, wi, K)
        bih = np.frombuffer(d[p:p + 6 * H], dtype='<i2').astype(np.int32); p += 6 * H
        whh, p = unpackK(d, p, 3 * H, H, K)
        bhh = np.frombuffer(d[p:p + 6 * H], dtype='<i2').astype(np.int32); p += 6 * H
        cells.append(((wih, bih, int(kih)), (whh, bhh, int(khh))))
    kout = d[p]; p += 1
    wout, p = unpackK(d, p, V, H, K)
    bout = np.frombuffer(d[p:p + 2 * V], dtype='<i2').astype(np.int32); p += 2 * V
    im = IntModel.__new__(IntModel)
    im.V, im.E, im.H, im.L, im.K = V, E, H, L, K
    im.embed = embed; im.cells = cells; im.out = (wout, bout, int(kout))
    return im, charset

ap = argparse.ArgumentParser()
ap.add_argument('model'); ap.add_argument('-n', type=int, default=160)
ap.add_argument('-c', action='store_true', help='stop display at the first form feed (a program / reply end)')
ap.add_argument('--noise', type=int, default=0, help='+/- this on each logit before argmax (as GRU/MIND G amp); 0 greedy')
ap.add_argument('--seed', type=int, default=12345)
ap.add_argument('prompts', nargs='*')
a = ap.parse_args()

# the Z80's noise generator (Net.cls FeedNoise): m_seed = m_seed*75+74 (16-bit), noise = (seed\64) mod (2amp+1) - amp
class Z80Noise:
    def __init__(self, seed): self.s = seed & 0xFFFF
    def jolt(self, amp):
        self.s = (self.s * 75 + 74) & 0xFFFF
        sv = self.s if self.s < 32768 else self.s - 65536   # Integer is signed 16-bit
        q = int(sv / 64)                                    # NTC \ truncates toward zero
        m = q % (2 * amp + 1)
        if m < 0: m += (2 * amp + 1)                        # (match a non-negative table index)
        return m - amp
im, charset = load_mdl(a.model)

def gen(prompt, n, amp, seed):
    rng = Z80Noise(seed)
    hs = [np.zeros(im.H, dtype=np.int8) for _ in range(im.L)]
    idx = {ch: i for i, ch in enumerate(charset)}
    logits = None
    for ch in prompt:                                   # feed the prompt (no noise, as GRU does)
        logits, hs = im.step(idx.get(ch, 0), hs)
    out = []
    for _ in range(n):
        v = logits.copy()
        if amp > 0:
            v = v + np.array([rng.jolt(amp) for _ in range(len(v))])
        c = int(np.argmax(v)); out.append(charset[c])
        logits, hs = im.step(c, hs)
    return ''.join(out)

print('%s: vocab %d, embed %d, hidden %d, layers %d  (noise %d)' % (a.model, im.V, im.E, im.H, im.L, a.noise))
prompts = a.prompts or ["' a program\nOption Explicit\nDim i As Integer\n",
                        "For i = 1 To 10\n", "Sub Main()\n", "ld a, "]
for pr in prompts:
    pr = pr.replace('\\n', '\n')
    out = gen(pr, a.n, a.noise, a.seed)
    if a.c:
        out = out.split('\f')[0]
    print('\n=== prompt ' + repr(pr) + ' ===')
    print(pr + out.replace('\f', '<FF>'))

#!/usr/bin/env python3
# fgru.py - GEN's model in REAL FLOATS: the same AI test as genmdl.c / Net.cls / qgru.py's IntModel,
# but with true floating-point tanh / sigmoid and float arithmetic instead of the Z80's int8 tables
# and shifts. It reads the SAME GEN.MDL file (the ternary export), dequantises the weights to real
# numbers, and runs the textbook GRU the integer path approximates. Use it to see how far the
# int8/ternary machine drifts from the ideal float model on the same prompt.
#
#   python fgru.py MODEL.MDL "prompt" n        -> n greedy characters (newline shown as |)
#
# Dequantisation (the inverse of qgru.py's export, S = 64 = Tiny's 1.0):
#   embed_real = embed_int8 / S
#   W_real     = q * 2^-k        (q = the K balanced-trit planes combined: q = sum_j plane_j * 3^j)
#   b_real     = b_int16 / S
# The update, with real activations (vs the int8 tables sigm/tanh and mul(a,b)=(a*b+32)>>6):
#   gi = W_ih . x + b_ih ; gh = W_hh . h + b_hh
#   r = sigmoid(gi_r + gh_r) ; z = sigmoid(gi_z + gh_z)
#   n = tanh(gi_n + r * gh_n)
#   h = (1 - z) * n + z * h
#   logits = W_out . h + b_out ; next char = argmax
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import sys
import numpy as np

S = 64.0  # Tiny's scale (1.0 == 64)


def _unpack_row(buf, off, n, K):
    """K planes of n trits for one row, as qgru.packK wrote them (plane after plane, n/4 bytes each,
    trit 0 in bits 0-1, code 3 = -1). Returns the combined integer q (length n): q = sum_j p_j*3^j."""
    nb = n // 4
    q = np.zeros(n, dtype=np.int64)
    for j in range(K):                       # plane j = the 3^j digit (low trit first)
        plane = buf[off:off + nb]; off += nb
        p = np.zeros(n, dtype=np.int64)
        for b, byte in enumerate(plane):
            for s in range(4):               # 4 trits a byte, low trit first
                code = (byte >> (2 * s)) & 3
                p[b * 4 + s] = -1 if code == 3 else code
        q += p * (3 ** j)
    return q, off


def _weight(buf, off, rows, n, K, k):
    """A full ternary matrix (rows x n), K planes row-interleaved, dequantised to float: q * 2^-k."""
    W = np.zeros((rows, n), dtype=np.float64)
    for r in range(rows):
        q, off = _unpack_row(buf, off, n, K)
        W[r] = q
    return W * (2.0 ** -k), off


def _i16(buf, off, count):
    v = np.frombuffer(buf, dtype='<i2', count=count, offset=off).astype(np.float64)
    return v, off + count * 2


def load(path):
    b = open(path, 'rb').read()
    if b[:4] != b'GENM':
        raise ValueError('not a GEN.MDL file')
    ver, V, E, H, L, K = b[4], b[5], b[6], b[7], b[8], b[9]
    if ver != 2:
        raise ValueError('expected GEN.MDL v2, got v%d' % ver)
    off = 10
    charset = b[off:off + V].decode('latin1'); off += V
    embed = np.frombuffer(b, dtype=np.int8, count=V * E, offset=off).astype(np.float64).reshape(V, E) / S
    off += V * E
    layers = []
    for i in range(L):
        k_ih, k_hh = b[off], b[off + 1]; off += 2
        n_in = E if i == 0 else H
        W_ih, off = _weight(b, off, 3 * H, n_in, K, k_ih)
        b_ih, off = _i16(b, off, 3 * H); b_ih /= S
        W_hh, off = _weight(b, off, 3 * H, H, K, k_hh)
        b_hh, off = _i16(b, off, 3 * H); b_hh /= S
        layers.append((W_ih, b_ih, W_hh, b_hh))
    k_out = b[off]; off += 1
    W_out, off = _weight(b, off, V, H, K, k_out)
    b_out, off = _i16(b, off, V); b_out /= S
    return dict(V=V, E=E, H=H, L=L, K=K, charset=charset, embed=embed, layers=layers,
               W_out=W_out, b_out=b_out)


def _sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))


def step(m, c, hs):
    x = m['embed'][c]
    H = m['H']
    for i, (W_ih, b_ih, W_hh, b_hh) in enumerate(m['layers']):
        h = hs[i]
        gi = W_ih @ x + b_ih
        gh = W_hh @ h + b_hh
        r = _sigmoid(gi[:H] + gh[:H])
        z = _sigmoid(gi[H:2 * H] + gh[H:2 * H])
        n = np.tanh(gi[2 * H:] + r * gh[2 * H:])
        h = (1.0 - z) * n + z * h
        hs[i] = h; x = h
    return m['W_out'] @ x + m['b_out'], hs


def generate(m, prompt, n):
    hs = [np.zeros(m['H'], dtype=np.float64) for _ in range(m['L'])]
    idx = {ch: i for i, ch in enumerate(m['charset'])}
    logits = None
    for ch in prompt:
        logits, hs = step(m, idx.get(ch, 0), hs)
    out = []
    for _ in range(n):
        c = int(np.argmax(logits)); out.append(m['charset'][c])
        logits, hs = step(m, c, hs)
    return ''.join(out)


def main(argv):
    if len(argv) < 4:
        sys.stderr.write('usage: fgru.py MODEL.MDL "prompt" n\n')
        return 1
    m = load(argv[1])
    text = generate(m, argv[2], int(argv[3]))
    sys.stdout.write(text.replace('\n', '|') + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

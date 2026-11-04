#!/usr/bin/env python3
# qgru.py - GEN's model: a 2-layer GRU with ternary weights (-1 / 0 / 1, packed 4 a byte on the
# Z80), int8 activations in Tiny's units (1.0 = 64) and the integer arithmetic the Z80 does - the
# forward pass here IS the Z80's (every shift, saturation and table lookup the same), with the
# gradients of the smooth functions behind it (straight-through), so what trains is what runs,
# and the exported model gives the same bytes on the PC and the CPC.
#   The integer contract (per character, all values int8 unless said):
#     x = embed[c]                                     (int8, E wide)
#     for each layer: gi = (W_ih . x) >> k_ih + b_ih   (16 bits; the three gates r, z, n stacked)
#                     gh = (W_hh . h) >> k_hh + b_hh
#                     r = sigm(sat(gi_r + gh_r)); z = sigm(sat(gi_z + gh_z))
#                     n = tanh(sat(gi_n + mul(r, sat(gh_n))))
#                     h = sat(mul(64 - z, n) + mul(z, h))
#     logits = (W_out . h) >> k_out + b_out            (16 bits); the next character: the biggest
#   mul(a, b) = (a * b + 32) >> 6 saturated; sigm / tanh: the 256-entry tables of Tiny.cls
#   (tools/tiny/mktables.js); >> is an arithmetic shift (floor); sat clamps to -128 .. 127.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import math, torch, torch.nn as nn, torch.nn.functional as F
import numpy as np

S = 64  # Tiny's scale

def tables():
    t = np.zeros(256, dtype=np.int64); g = np.zeros(256, dtype=np.int64)
    for b in range(256):
        x = (b if b < 128 else b - 256) / S
        t[b] = max(-128, min(127, int(math.floor(math.tanh(x) * S + 0.5))))
        g[b] = max(-128, min(127, int(math.floor(S / (1 + math.exp(-x)) + 0.5))))
    return t, g
TANH_T, SIGM_T = tables()
TANH_TT = torch.tensor(TANH_T, dtype=torch.float32); SIGM_TT = torch.tensor(SIGM_T, dtype=torch.float32)

# ---- the integer operations with straight-through gradients

class Sat8(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x):
        ctx.save_for_backward(x)
        return torch.clamp(torch.round(x), -128, 127)
    @staticmethod
    def backward(ctx, g):
        x, = ctx.saved_tensors
        return g * ((x > -129) & (x < 128)).float()
sat8 = Sat8.apply

class Table(torch.autograd.Function):
    # forward: the Z80's table on the int8 input; backward: the smooth function's slope
    @staticmethod
    def forward(ctx, x, which):
        ctx.save_for_backward(x); ctx.which = which
        idx = (x.long() & 255)
        return (TANH_TT if which == 0 else SIGM_TT)[idx]
    @staticmethod
    def backward(ctx, g):
        x, = ctx.saved_tensors
        xr = x / S
        if ctx.which == 0: d = 1 - torch.tanh(xr) ** 2          # d tanh(x/S)*S / dx = 1 - tanh^2
        else:
            s = torch.sigmoid(xr); d = s * (1 - s)                # d (S*sigm(x/S)) / dx
        return g * d, None
def tanh8(x): return Table.apply(x, 0)
def sigm8(x): return Table.apply(x, 1)

class Shift(torch.autograd.Function):
    # floor(x / 2^k) with the gradient 1 / 2^k
    @staticmethod
    def forward(ctx, x, k):
        ctx.k = k
        return torch.floor(x / (2.0 ** k))
    @staticmethod
    def backward(ctx, g):
        return g / (2.0 ** ctx.k), None
shift = Shift.apply

def mul8(a, b):
    # (a * b + 32) >> 6, saturated - the product is exact in float32
    return sat8(torch.floor((a * b + 32) / 64))

def levels(trits):
    return (3 ** trits - 1) // 2          # k trits (balanced base 3): -L .. +L

class TernaryLinear(nn.Module):
    """y = (W_q . x) >> k + b, W_q quantised to k balanced-trit weights (-L..L, L=(3^trits-1)/2),
    W_q / alpha from the weights' mean size, alpha = 2^-k (the Z80's shift). trits=1 is plain ternary."""
    def __init__(self, n_in, n_out, trits=1):
        super().__init__()
        self.w = nn.Parameter(torch.randn(n_out, n_in) * (1.0 / math.sqrt(n_in)))
        self.b = nn.Parameter(torch.zeros(n_out))
        self.n_in, self.n_out, self.trits = n_in, n_out, trits
    def k(self):
        # alpha = the mean |w| (BitNet's), rounded to a power of two: the shift the Z80 does
        with torch.no_grad():
            a = self.w.abs().mean().clamp(min=1e-6)
            return int(round(-math.log2(a.item())))
    def quant(self):
        k = self.k(); alpha = 2.0 ** -k
        if self.trits == 0:
            return self.w / alpha, k                               # float master: weights unrounded, same shift/activation path
        L = levels(self.trits)
        q = torch.clamp(torch.round(self.w / alpha), -L, L)
        return self.w / alpha + (q - self.w / alpha).detach(), k   # straight-through
    def forward(self, x):
        q, k = self.quant()
        acc = F.linear(x, q)                     # exact: integers under 2^24
        b = torch.round(self.b * S)              # the bias in Tiny units, 16 bits
        b = self.b * S + (b - self.b * S).detach()
        return shift(acc, k) + b
    def export(self):
        k = self.k(); alpha = 2.0 ** -k; L = levels(self.trits)
        q = torch.clamp(torch.round(self.w.detach() / alpha), -L, L).to(torch.int64).numpy()
        planes = bal3_planes(q, self.trits)      # k arrays of -1/0/1 (low trit first)
        b = torch.round(self.b.detach() * S).clamp(-32768, 32767).to(torch.int16).numpy()
        return planes, b, k

class QGRUCell(nn.Module):
    def __init__(self, n_in, n_h, trits=1):
        super().__init__()
        self.ih = TernaryLinear(n_in, 3 * n_h, trits); self.hh = TernaryLinear(n_h, 3 * n_h, trits); self.n_h = n_h
    def forward(self, x, h):
        H = self.n_h
        gi = self.ih(x); gh = self.hh(h)
        r = sigm8(sat8(gi[..., :H] + gh[..., :H]))
        z = sigm8(sat8(gi[..., H:2*H] + gh[..., H:2*H]))
        n = tanh8(sat8(gi[..., 2*H:] + mul8(r, sat8(gh[..., 2*H:]))))
        return sat8(mul8(S - z, n) + mul8(z, h))

class QGRU(nn.Module):
    def __init__(self, vocab, n_e=32, n_h=96, layers=2, trits=1):
        super().__init__()
        self.vocab, self.n_e, self.n_h, self.layers, self.trits = vocab, n_e, n_h, layers, trits
        self.embed = nn.Parameter(torch.randn(vocab, n_e) * 0.5)
        self.cells = nn.ModuleList([QGRUCell(n_e if i == 0 else n_h, n_h, trits) for i in range(layers)])
        self.out = TernaryLinear(n_h, vocab, trits)
    def embed8(self):
        e = torch.clamp(torch.round(self.embed * S), -128, 127)
        return self.embed * S + (e - self.embed * S).detach()
    def forward(self, seq, hs=None):
        # seq: (B, T) long; returns logits (B, T, V) and the hidden states
        B, T = seq.shape
        if hs is None: hs = [torch.zeros(B, self.n_h) for _ in self.cells]
        e = self.embed8()[seq]                   # (B, T, E) int8 values
        outs = []
        for t in range(T):
            x = e[:, t]
            for i, c in enumerate(self.cells):
                hs[i] = c(x, hs[i]); x = hs[i]
            outs.append(self.out(x))
        return torch.stack(outs, 1), hs

# ---- the exact integer reference (numpy): what the Z80 must give, byte for byte

def bal3_planes(q, trits):
    """an integer array -> list of `trits` balanced-ternary digit planes (-1/0/1), low trit first;
    q = plane0 + 3*plane1 + 9*plane2 + ... . Python // floors, which is what balanced base 3 needs."""
    q = q.astype(np.int64).copy(); planes = []
    for _ in range(trits):
        d = ((q + 1) % 3) - 1                 # -1, 0, 1
        planes.append(d.astype(np.int8)); q = (q - d) // 3
    return planes

def pack4(t):
    """rows of trits (-1/0/1, n a multiple of 4) -> bytes: trit 0 in bits 0-1, 11 = -1"""
    t = np.asarray(t); r, c = t.shape
    codes = np.where(t < 0, 3, t).astype(np.uint8)
    out = np.zeros((r, c // 4), dtype=np.uint8)
    for j in range(4): out |= (codes[:, j::4] << (2 * j)).astype(np.uint8)
    return out

def packK(planes):
    """k planes (each R x n of -1/0/1) -> bytes, ROW-interleaved: for each row r, its k planes in
    turn (n/4 bytes each). So row r is at r*k*(n/4), plane j of it at +j*(n/4) - the Z80 walks it
    a row at a time, k planes to a row."""
    K = len(planes); R, n = planes[0].shape
    out = bytearray()
    for r in range(R):
        for j in range(K):
            out += pack4(planes[j][r:r + 1]).tobytes()
    return bytes(out)

class IntModel:
    def __init__(self, m):
        self.V, self.E, self.H, self.L, self.K = m.vocab, m.n_e, m.n_h, m.layers, m.trits
        self.embed = torch.clamp(torch.round(m.embed.detach() * S), -128, 127).to(torch.int8).numpy()
        self.cells = []
        for c in m.cells:
            self.cells.append((c.ih.export(), c.hh.export()))
        self.out = m.out.export()
    @staticmethod
    def sat(x): return np.clip(x, -128, 127)
    @staticmethod
    def mul(a, b): return IntModel.sat((a.astype(np.int32) * b.astype(np.int32) + 32) >> 6)
    @staticmethod
    def lin(ex, x):
        planes, b, k = ex
        acc = np.zeros(planes[0].shape[0], dtype=np.int32)
        for p in reversed(planes):               # Horner: acc = acc*3 + (plane . x), low trit last
            acc = acc * 3 + p.astype(np.int32) @ x.astype(np.int32)
        return (acc >> k) + b.astype(np.int32)
    def step(self, c, hs):
        x = self.embed[c].astype(np.int32)
        for i, (ih, hh) in enumerate(self.cells):
            H = self.H; h = hs[i].astype(np.int32)
            gi = self.lin(ih, x); gh = self.lin(hh, h)
            r = SIGM_T[self.sat(gi[:H] + gh[:H]) & 255]
            z = SIGM_T[self.sat(gi[H:2*H] + gh[H:2*H]) & 255]
            n = TANH_T[self.sat(gi[2*H:] + self.mul(r, self.sat(gh[2*H:]))) & 255]
            h = self.sat(self.mul(S - z, n) + self.mul(z, h))
            hs[i] = h.astype(np.int8); x = h
        return self.lin(self.out, x), hs
    def generate(self, prompt, n, charset):
        hs = [np.zeros(self.H, dtype=np.int8) for _ in range(self.L)]
        idx = {ch: i for i, ch in enumerate(charset)}
        out = []
        logits = None
        for ch in prompt:
            logits, hs = self.step(idx.get(ch, 0), hs)
        for _ in range(n):
            c = int(np.argmax(logits)); out.append(charset[c])
            logits, hs = self.step(c, hs)
        return ''.join(out)
    def write(self, path, charset):
        """GEN.MDL v2: 'GENM' 2 V E H L K | charset (V bytes) | embed V*E (int8) | per layer:
        k_ih k_hh, W_ih (K planes, row-interleaved), b_ih int16 x 3H, W_hh ..., b_hh | k_out,
        W_out (K planes), b_out int16 x V. Each weight is K balanced trits; K=1 is plain ternary
        and v1-compatible in meaning. Little end first."""
        b = bytearray(b'GENM' + bytes([2, self.V, self.E, self.H, self.L, self.K]))
        b += bytes(ord(c) for c in charset)
        b += self.embed.astype(np.uint8).tobytes()
        for (ih, hh) in self.cells:
            b += bytes([ih[2], hh[2]])
            b += packK(ih[0]); b += ih[1].astype('<i2').tobytes()
            b += packK(hh[0]); b += hh[1].astype('<i2').tobytes()
        b += bytes([self.out[2]])
        b += packK(self.out[0]); b += self.out[1].astype('<i2').tobytes()
        open(path, 'wb').write(b)
        return len(b)

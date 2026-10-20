# gen_xform.py - the unrolled vertex transform for E3.cls's Lib (printed; pasted between
# ;@@XFORM and ;@@XFORM-END). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# A vertex's coordinates come as u = v + 128 (unsigned) in B, C, IYL. Row i: HL starts at
# c_i - K_i (self-modified), then for each j: + or - (|C'ij| * u_j) >> 8, the sign by patching
# 3 bytes (00 00 19: nop, nop, add hl, de / B7 ED 52: or a, sbc hl, de).
U = ['b', 'c', 'iyl']
L = []
for i in range(3):
    L.append('xr%dc:      ld hl, 0' % i)
    for j in range(3):
        t = 'xt%d%d' % (i, j)
        L += ['            ld e, %s' % U[j],
              '%sh:      ld d, 0' % t, '            mul d, e',
              '%sa:      nop' % t, '            nop', '            add hl, de',
              '            ld e, %s' % U[j],
              '%sl:      ld d, 0' % t, '            mul d, e', '            ld e, d', '            ld d, 0',
              '%sb:      nop' % t, '            nop', '            add hl, de']
    L.append('            ld (xv_o%d), hl' % i)
T = []
for i in range(3):
    for j in range(3):
        t = 'xt%d%d' % (i, j)
        T.append('            dw %sh + 1, %sl + 1, %sa, %sb' % (t, t, t, t))
# the patch writer (SPLIT): each C'(i, j) (ccl + 2 (3 j + i)) into its term: |C'| high and low
# bytes, the two 3 byte patches by its sign
P = []
for i in range(3):
    for j in range(3):
        t = 'xt%d%d' % (i, j)
        P += ['            ld hl, ({ccl} + %d)' % (2 * (3 * j + i)),
              '            bit 7, h', '            jr z, %sp' % t.replace('xt', 'xs'),
              '            ex de, hl', '            ld hl, 0', '            or a', '            sbc hl, de',
              '            ld a, h', '            ld (%sh + 1), a' % t, '            ld a, l', '            ld (%sl + 1), a' % t,
              '            ld a, #B7', '            ld (%sa), a' % t, '            ld (%sb), a' % t,
              '            ld hl, #52ED', '            ld (%sa + 1), hl' % t, '            ld (%sb + 1), hl' % t,
              '            jr %se' % t.replace('xt', 'xs'),
              '%sp:' % t.replace('xt', 'xs'),
              '            ld a, h', '            ld (%sh + 1), a' % t, '            ld a, l', '            ld (%sl + 1), a' % t,
              '            xor a', '            ld (%sa), a' % t, '            ld (%sb), a' % t,
              '            ld hl, #1900', '            ld (%sa + 1), hl' % t, '            ld (%sb + 1), hl' % t,
              '%se:' % t.replace('xt', 'xs')]
print('\n'.join(L))
print(';@@XTAB')
print('\n'.join(T))
print(';@@SPLIT')
print('\n'.join(P))

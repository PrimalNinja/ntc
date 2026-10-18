# datinfo.py AUCKLAND.DAT: an S3D data file's header, views, landmarks and what its tiles hold
# (the format: tools/s3dmake/s3dmake.html, at the top of its script)
import struct, sys
d = open(sys.argv[1], 'rb').read()
B = 16384
assert d[:4] == b'S3D1', 'not S3D data'
nx, nz, nb, x0, z0, ts, sx, sz = struct.unpack('<HHHhhHhh', d[4:20])
nlm, lmo, dro, nv, vwo = struct.unpack('<HHHHH', d[22:32])
cx, cz = struct.unpack('<hh', d[48:52])
print('name %s, %d x %d tiles of %d units (0.5 m), %d data blocks of 16K' % (d[32:48].rstrip(b'\0').decode(), nx, nz, ts, nb))
print('world corner %d, %d; start %d, %d; centre %d, %d (units)' % (x0, z0, sx, sz, cx, cz))
far = sum(1 for i in range(nlm) if struct.unpack('<H', d[lmo + 2 * i:lmo + 2 * i + 2])[0] & 0x8000)
print('%d landmark tiles (%d far)' % (nlm, far))
for i in range(nv):
    o = vwo + 32 * i
    x, z, h, fx, fz = struct.unpack('<5h', d[o:o + 10])
    print('view %d: %-22s at %6d, %6d, %4d m up, looking %6d, %6d' % (i + 1, d[o + 10:o + 32].rstrip(b'\0').decode(), x, z, h // 2, fx, fz))
tb = tl = t3 = tt = mxn = mxh = full = 0
for k in range(nx * nz):
    b = d[64 + 3 * k]
    if not b:
        continue
    t = b * B + (d[65 + 3 * k] | d[66 + 3 * k] << 8)
    n0, n1, n2, nl, n3, nt = struct.unpack('<6H', d[t:t + 12])
    tb += n0 + n1 + n2; tl += nl; t3 += n3; tt += nt; full += 1
    p = t + 16
    for i in range(n0 + n1 + n2):
        mxn = max(mxn, d[p]); mxh = max(mxh, d[p + 1]); p += 2 + 2 * d[p]
print('%d tiles with something: %d buildings (up to %d corners, %d m), %d ground lines, %d 3D lines, %d trees' % (full, tb, mxn, mxh * 2, tl, t3, tt))

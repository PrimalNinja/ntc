// dpcm.js - songs for NTC's Pcm class on the Mega Drive: 8-bit unsigned mono PCM files turned into
// 4-bit DPCM at the Z80 player's rate (tools/md/z80pcm.asm: 7610 samples a second), each song in
// whole 32K blocks (the Z80's bank window) after a 32K block of its header. (First written for
// TIANLONG.) (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node dpcm.js --out=MUSIC.DAT [--rate=12000] SONG0.PCM [SONG1.PCM ...]
//
//   Up to 5 songs (Pcm.Play 0-4). MUSIC.DAT goes in the ROM on a 32K edge (#asm: align 15, then
//   incbin). Its header: for each song, its first block and how many (words, the 68000's byte
//   order). About 3.8K a second.
'use strict';
const fs = require('fs');
const opt = { out: '', rate: '12000' };
const files = [];
for (const a of process.argv.slice(2)) {
  const m = /^--([a-z]+)=(.*)$/.exec(a);
  if (m) opt[m[1]] = m[2]; else files.push(a);
}
if (!opt.out || files.length < 1 || files.length > 5) {
  console.error('usage: node dpcm.js --out=MUSIC.DAT [--rate=12000] SONG0.PCM [SONG1.PCM ...]');
  process.exit(1);
}
const RATE_IN = Number(opt.rate);
const RATE_OUT = 7670454 / 144 / 7;              // the Z80 player's: 7 counts of Timer A
const DELTAS = [0, 1, 2, 4, 8, 16, 32, 64, -128, -1, -2, -4, -8, -16, -32, -64];
const BLOCK = 32768;

function resample(src) {
  // a small low-pass (the new rate's half) then linear steps
  const n = src.length;
  const f = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    const a = src[Math.max(0, i - 1)], b = src[i], c = src[Math.min(n - 1, i + 1)];
    f[i] = (a + 2 * b + c) / 4;
  }
  const m = Math.floor(n * RATE_OUT / RATE_IN);
  const out = new Float64Array(m);
  const step = RATE_IN / RATE_OUT;
  for (let j = 0; j < m; j++) {
    const x = j * step, i = Math.floor(x), t = x - i;
    out[j] = i + 1 < n ? f[i] * (1 - t) + f[i + 1] * t : f[n - 1];
  }
  return out;
}

function encode(s) {
  // each sample: the step that lands nearest it without leaving 0-255
  const out = new Uint8Array(Math.ceil(s.length / 2));
  let v = 128, err = 0;
  for (let i = 0; i < s.length; i++) {
    let best = 0, be = 1e9;
    for (let k = 0; k < 16; k++) {
      const nv = v + DELTAS[k];
      if (nv < 0 || nv > 255) continue;
      const e = Math.abs(nv - s[i]);
      if (e < be) { be = e; best = k; }
    }
    v += DELTAS[best];
    err += be;
    if (i & 1) out[i >> 1] |= best; else out[i >> 1] = best << 4;
  }
  return { data: out, err: err / s.length };
}

const songs = [];
files.forEach(function(f, n) {
  const src = fs.readFileSync(f);
  const r = encode(resample(src));
  const blocks = Math.ceil(r.data.length / BLOCK);
  const buf = Buffer.alloc(blocks * BLOCK, 0);     // nibble 0: no change (the end holds its last value)
  Buffer.from(r.data).copy(buf);
  songs.push(buf);
  console.log('song ' + n + ' (' + f + '): ' + (src.length / RATE_IN).toFixed(1) + ' s, ' + blocks + ' blocks, mean error ' + r.err.toFixed(2));
});
const head = Buffer.alloc(BLOCK, 0);
let blk = 1;
songs.forEach((b, n) => {
  head.writeUInt16BE(blk, n * 4);
  head.writeUInt16BE(b.length / BLOCK, n * 4 + 2);
  blk += b.length / BLOCK;
});
fs.writeFileSync(opt.out, Buffer.concat([head].concat(songs)));
console.log(opt.out + ': ' + blk + ' blocks, ' + (blk * BLOCK) + ' bytes');

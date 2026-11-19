// okiadpcm.js - songs for NTC's Pcm class on the FM Towns and the X68000: 8-bit unsigned mono PCM
// files turned into 4-bit OKI ADPCM (the low nibble first) at 7812.5 samples a second. The FM
// Towns' Pcm class decodes it a frame at a time for the RF5C68; on the X68000 it is the MSM6258's
// own format, sent by the ROM's DMA call. (First written for TIANLONG.)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node okiadpcm.js --target=towns|x68000 --out=MUSIC.DAT [--rate=12000] [--volume=1.0] SONG0.PCM [SONG1.PCM ...]
//
//   Up to 5 songs (Pcm.Play 0-4); - for a song that is not there. --rate: the files' samples a
//   second. --volume: 1.0 full (TIANLONG's X68000 build used 0.625, to hear the sound effects).
//   MUSIC.DAT: 5 x (the song's place from the start, its bytes: 32 bits each, the target's byte
//   order; 0 0 for none), then the songs. About 3.9K a second: a 1232K floppy holds 5 minutes
//   less the program.
'use strict';
const fs = require('fs');
const opt = { target: '', out: '', rate: '12000', volume: '1' };
const files = [];
for (const a of process.argv.slice(2)) {
  const m = /^--([a-z]+)=(.*)$/.exec(a);
  if (m) opt[m[1]] = m[2]; else files.push(a);
}
if ((opt.target !== 'towns' && opt.target !== 'x68000') || !opt.out || files.length < 1 || files.length > 5) {
  console.error('usage: node okiadpcm.js --target=towns|x68000 --out=MUSIC.DAT [--rate=12000] [--volume=1.0] SONG0.PCM [SONG1.PCM ...]');
  process.exit(1);
}
const RATE_IN = Number(opt.rate);
const RATE_OUT = 8000000 / 1024;            // 7.8 kHz
const VOLUME = Number(opt.volume);
const STEPS = [16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130,
  143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060,
  1166, 1282, 1411, 1552];
const ADJ = [-1, -1, -1, -1, 2, 4, 6, 8];

function resample(src) {
  const n = src.length;
  const f = new Float64Array(n);
  for (let i = 0; i < n; i++) {
    const a = src[Math.max(0, i - 1)], b = src[i], c = src[Math.min(n - 1, i + 1)];
    f[i] = ((a + 2 * b + c) / 4 - 128) * 16 * VOLUME;          // 12 bits
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
  // OKI ADPCM: each nibble the sign and three bits of the difference in steps; the decoder's
  // value and step followed exactly
  const out = new Uint8Array(Math.ceil(s.length / 2));
  let v = 0, idx = 0;
  for (let i = 0; i < s.length; i++) {
    const step = STEPS[idx];
    let d = Math.round(s[i]) - v;
    let n = 0;
    if (d < 0) { n = 8; d = -d; }
    let diff = step >> 3;
    if (d >= step) { n |= 4; d -= step; diff += step; }
    if (d >= step >> 1) { n |= 2; d -= step >> 1; diff += step >> 1; }
    if (d >= step >> 2) { n |= 1; diff += step >> 2; }
    v += (n & 8) ? -diff : diff;
    if (v > 2047) v = 2047;
    if (v < -2048) v = -2048;
    idx += ADJ[n & 7];
    if (idx < 0) idx = 0;
    if (idx > 48) idx = 48;
    if (i & 1) out[i >> 1] |= n << 4; else out[i >> 1] = n;
  }
  return out;
}

const head = Buffer.alloc(5 * 8, 0);
const parts = [];
let off = head.length;
files.forEach(function(f, n) {
  if (f === '-') return;
  const src = fs.readFileSync(f);
  const d = Buffer.from(encode(resample(src)));
  if (opt.target === 'towns') { head.writeUInt32LE(off, n * 8); head.writeUInt32LE(d.length, n * 8 + 4); }
  else { head.writeUInt32BE(off, n * 8); head.writeUInt32BE(d.length, n * 8 + 4); }
  parts.push(d);
  off += d.length;
  console.log('song ' + n + ' (' + f + '): ' + (src.length / RATE_IN).toFixed(1) + ' s, ' + d.length + ' bytes');
});
fs.writeFileSync(opt.out, Buffer.concat([head].concat(parts)));
console.log(opt.out + ': ' + off + ' bytes');

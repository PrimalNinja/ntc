// ngpcm.js - sounds to the Neo Geo's V ROM, for NTC's neogeo platform (the Pcm class and NTC's
// sound driver on the Z80). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node tools/neogeo/ngpcm.js --out=NAME [--rate=18518] [--inrate=12000] [--volume=1.0]
//        [--samples=A.wav,B.wav,...] SONG0.wav SONG1.wav ...
//
// Reads WAV files (8 or 16 bit PCM, one or two channels, any rate) or raw files of 8 bit
// unsigned samples, one channel, at --inrate (any name not ending .wav), and writes:
//   NAME_V.BIN      the V ROM (test/ngbuild.js --vrom): the --samples first (ADPCM-A: played
//                   once, at 18518.5 a second, on one of six channels - Pcm.Sample n, c, l), then
//                   the songs (ADPCM-B: played round and round at --rate - Pcm.Play n, lp)
//   NAME_SONG.BIN   the driver's song table (--songs): 32 x 8 bytes
//   NAME_SAMP.BIN   its sample table (--samples): 64 x 4 bytes
// Up to 32 songs and 64 samples. An ADPCM-A sample can't cross a 1 MB edge of the V ROM (they go
// first, from 0: the tool says if one would). Both kinds are 4 bits a sample, so a second of a
// song at 18518 is 9.3K; the V ROM can be 16 MB.
//
// ADPCM-B (the YM2610's, as the Y8950's): each nibble, the high one first, a sign and three bits;
// the decoder adds (2 * n + 1) * step / 8 (taken away for a minus), kept within 16 bits, then the
// step times 57, 57, 57, 57, 77, 102, 128, 153 (for n 0-7) / 64, kept within 127-24576, from 0
// and a step of 127. ADPCM-A: 12 bits, the step one of 49 (16 .. 1552), moved by -1, -1, -1, -1,
// 2, 5, 7, 9. Each encoder follows its decoder exactly and takes the nibble nearest each sample.
'use strict';
const fs = require('fs');
const path = require('path');

const CHIP = 8000000 / 144;                           // ADPCM-B's clock: 55555.6 a second
const ARATE = 8000000 / 432;                          // ADPCM-A's rate: 18518.5
const MUL = [57, 57, 57, 57, 77, 102, 128, 153];
const ASTEP = [16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130,
	143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060,
	1166, 1282, 1411, 1552];
const AINC = [-1, -1, -1, -1, 2, 5, 7, 9];

function die(m) { console.error('ngpcm: ' + m); process.exit(1); }

// a file -> { x: Float64Array -1 .. 1 (one channel), rate }
function load(file, inrate) {
	const b = fs.readFileSync(file);
	if (!/\.wav$/i.test(file)) {
		const x = new Float64Array(b.length);
		for (let i = 0; i < b.length; i++) x[i] = (b[i] - 128) / 128;
		return { x, rate: inrate };
	}
	if (b.toString('latin1', 0, 4) !== 'RIFF' || b.toString('latin1', 8, 12) !== 'WAVE') die(file + ' is not a WAV file');
	let p = 12, fmt = null, data = null;
	while (p + 8 <= b.length) {
		const id = b.toString('latin1', p, p + 4), n = b.readUInt32LE(p + 4);
		if (id === 'fmt ') fmt = { tag: b.readUInt16LE(p + 8), ch: b.readUInt16LE(p + 10), rate: b.readUInt32LE(p + 12), bits: b.readUInt16LE(p + 22) };
		else if (id === 'data') data = b.slice(p + 8, Math.min(b.length, p + 8 + n));
		p += 8 + n + (n & 1);
	}
	if (!fmt || !data) die(file + ': no fmt or data chunk');
	if ((fmt.tag !== 1 && fmt.tag !== 0xFFFE) || (fmt.bits !== 8 && fmt.bits !== 16)) die(file + ': only 8 or 16 bit PCM is read');
	const step = fmt.ch * fmt.bits / 8, n = Math.floor(data.length / step), x = new Float64Array(n);
	for (let i = 0; i < n; i++) {
		let s = 0;
		for (let c = 0; c < fmt.ch; c++) s += fmt.bits === 8 ? (data[i * step + c] - 128) / 128 : data.readInt16LE(i * step + c * 2) / 32768;
		x[i] = s / fmt.ch;
	}
	return { x, rate: fmt.rate };
}

// to another rate: each new sample is the mean of the old ones it covers (going down), or the
// straight line between its two neighbours (going up)
function resample(x, from, to) {
	if (Math.abs(from - to) < 0.5) return x;
	const n = Math.max(1, Math.round(x.length * to / from)), out = new Float64Array(n), r = from / to;
	for (let i = 0; i < n; i++) {
		if (r > 1) {
			const a = Math.floor(i * r), b = Math.min(x.length, Math.max(a + 1, Math.floor((i + 1) * r)));
			let s = 0;
			for (let j = a; j < b; j++) s += x[j];
			out[i] = s / (b - a);
		} else {
			const t = i * r, a = Math.min(x.length - 1, Math.floor(t)), b = Math.min(x.length - 1, a + 1);
			out[i] = x[a] + (x[b] - x[a]) * (t - a);
		}
	}
	return out;
}

function clip(v) { return v > 1 ? 1 : (v < -1 ? -1 : v); }

// floats -> ADPCM-B bytes (whole 256 byte units)
function adpcmB(x, vol) {
	const n = x.length + ((512 - (x.length % 512)) % 512), out = Buffer.alloc(n / 2);
	let acc = 0, step = 127;
	for (let i = 0; i < n; i++) {
		const want = i < x.length ? clip(x[i] * vol) * 32767 : 0;
		let best = 0, be = Infinity, ba = 0;
		for (let k = 0; k < 16; k++) {
			const d = Math.floor(((2 * (k & 7) + 1) * step) / 8);
			let a = (k & 8) ? acc - d : acc + d;
			if (a > 32767) a = 32767;
			if (a < -32768) a = -32768;
			const e = Math.abs(a - want);
			if (e < be) { be = e; best = k; ba = a; }
		}
		acc = ba;
		step = Math.floor((step * MUL[best & 7]) / 64);
		if (step < 127) step = 127;
		if (step > 24576) step = 24576;
		if (i & 1) out[i >> 1] |= best; else out[i >> 1] = best << 4;
	}
	return out;
}

// floats -> ADPCM-A bytes (whole 256 byte units; the decoder's 12 bits never wrap)
function adpcmA(x, vol) {
	const n = x.length + ((512 - (x.length % 512)) % 512), out = Buffer.alloc(n / 2);
	let acc = 0, idx = 0;
	for (let i = 0; i < n; i++) {
		const want = i < x.length ? clip(x[i] * vol) * 2047 : 0;
		let best = 0, be = Infinity, ba = 0;
		for (let k = 0; k < 16; k++) {
			const d = Math.floor(((2 * (k & 7) + 1) * ASTEP[idx]) / 8);
			const a = (k & 8) ? acc - d : acc + d;
			if (a > 2047 || a < -2048) continue;
			const e = Math.abs(a - want);
			if (e < be) { be = e; best = k; ba = a; }
		}
		acc = ba;
		idx += AINC[best & 7];
		if (idx < 0) idx = 0;
		if (idx > 48) idx = 48;
		if (i & 1) out[i >> 1] |= best; else out[i >> 1] = best << 4;
	}
	return out;
}

function main() {
	const o = {}, files = [];
	process.argv.slice(2).forEach(a => { const m = a.match(/^--(\w+)=(.*)$/); if (m) o[m[1]] = m[2]; else files.push(a); });
	if (!o.out || (!files.length && !o.samples)) die('usage: node ngpcm.js --out=NAME [--rate=18518] [--inrate=12000] [--volume=1.0] [--samples=A.wav,...] SONG0.wav ...');
	const inrate = parseFloat(o.inrate || '12000'), vol = parseFloat(o.volume || '1');
	const deltaN = Math.max(1, Math.min(65535, Math.round(parseFloat(o.rate || '18518.5') / CHIP * 65536)));
	const rate = CHIP * deltaN / 65536;
	const samp = (o.samples || '').split(',').filter(x => x);
	if (files.length > 32) die('more than 32 songs');
	if (samp.length > 64) die('more than 64 samples');
	const V = [], songs = Buffer.alloc(32 * 8, 0), samps = Buffer.alloc(64 * 4, 0);
	let at = 0;
	samp.forEach((f, n) => {
		const s = load(f, inrate), a = adpcmA(resample(s.x, s.rate, ARATE), vol);
		if ((at >> 20) !== ((at + a.length - 1) >> 20)) die(f + ': sample ' + n + ' would cross a 1 MB edge of the V ROM (at ' + at + ', ' + a.length + ' bytes): fewer or shorter samples');
		samps.writeUInt16LE(at >> 8, n * 4);
		samps.writeUInt16LE((at + a.length - 1) >> 8, n * 4 + 2);
		V.push(a);
		console.log('sample ' + n + ': ' + path.basename(f) + ', ' + (s.x.length / s.rate).toFixed(2) + ' s, ' + a.length + ' bytes at ' + at);
		at += a.length;
	});
	files.forEach((f, n) => {
		const s = load(f, inrate), a = adpcmB(resample(s.x, s.rate, rate), vol);
		songs.writeUInt16LE(at >> 8, n * 8);
		songs.writeUInt16LE((at + a.length - 1) >> 8, n * 8 + 2);
		songs.writeUInt16LE(deltaN, n * 8 + 4);
		songs[n * 8 + 6] = 255;
		V.push(a);
		console.log('song ' + n + ': ' + path.basename(f) + ', ' + (s.x.length / s.rate).toFixed(1) + ' s at ' + rate.toFixed(0) + ' a second, ' + a.length + ' bytes at ' + at);
		at += a.length;
	});
	if (at > 16 * 1024 * 1024) die('the V ROM would be ' + at + ' bytes: past 16 MB');
	fs.writeFileSync(o.out + '_V.BIN', Buffer.concat(V));
	fs.writeFileSync(o.out + '_SONG.BIN', songs);
	fs.writeFileSync(o.out + '_SAMP.BIN', samps);
	console.log(path.basename(o.out) + '_V.BIN: ' + at + ' bytes');
}
if (require.main === module) main();
module.exports = { adpcmA, adpcmB, resample };

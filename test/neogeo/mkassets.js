// mkassets.js - the pictures and sounds test/ngregress.sh gives the Neo Geo's tools: written
// into the folder named (test/t/ng). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//   Tiles.png  48 x 16: three 16 x 16 tiles - all red, all green, a blue one with a clear middle
//   Back.png   256 x 192: the backdrop's four bands, one colour each, a white line down x 0
//   Fix.png    16 x 8: two fix tiles, yellow and cyan
//   Song.wav   a second of a 440 Hz tone; Hit.wav a tenth of a second of noise
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const out = process.argv[2] || '.';

function crc(b) {
	let c = ~0;
	for (let i = 0; i < b.length; i++) { c ^= b[i]; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xEDB88320 & -(c & 1)); }
	return ~c >>> 0;
}
function chunk(t, d) {
	const b = Buffer.alloc(12 + d.length);
	b.writeUInt32BE(d.length, 0); b.write(t, 4, 'latin1'); d.copy(b, 8);
	b.writeUInt32BE(crc(b.slice(4, 8 + d.length)), 8 + d.length);
	return b;
}
// rgba(x, y) -> [r, g, b, a]
function png(name, w, h, rgba) {
	const raw = Buffer.alloc(h * (1 + w * 4));
	for (let y = 0; y < h; y++)
		for (let x = 0; x < w; x++) Buffer.from(rgba(x, y)).copy(raw, y * (1 + w * 4) + 1 + x * 4);
	const ih = Buffer.alloc(13);
	ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6;
	fs.writeFileSync(path.join(out, name), Buffer.concat([Buffer.from([0x89, 0x50, 0x4E, 0x47, 13, 10, 26, 10]),
		chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}
function wav(name, rate, x) {
	const b = Buffer.alloc(44 + x.length * 2);
	b.write('RIFF', 0); b.writeUInt32LE(36 + x.length * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16);
	b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 2, 28);
	b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(x.length * 2, 40);
	x.forEach((v, i) => b.writeInt16LE(Math.round(v * 30000), 44 + i * 2));
	fs.writeFileSync(path.join(out, name), b);
}
png('Tiles.png', 48, 16, (x, y) => {
	if (x < 16) return [255, 0, 0, 255];
	if (x < 32) return [0, 255, 0, 255];
	const mx = x - 32;
	return (mx >= 4 && mx < 12 && y >= 4 && y < 12) ? [0, 0, 0, 0] : [0, 0, 255, 255];
});
const BAND = [[255, 0, 255], [0, 255, 255], [255, 128, 0], [128, 128, 128]];
png('Back.png', 256, 192, (x, y) => (x === 0 ? [255, 255, 255, 255] : BAND[y < 56 ? 0 : (y < 112 ? 1 : (y < 152 ? 2 : 3))].concat(255)));
png('Fix.png', 16, 8, (x, y) => (x < 8 ? [255, 255, 0, 255] : [0, 255, 255, 255]));
const song = [], hit = [];
for (let i = 0; i < 22050; i++) song.push(Math.sin(i * 2 * Math.PI * 440 / 22050) * 0.8);
let s = 12345;
for (let i = 0; i < 2205; i++) { s = (s * 1103515245 + 12345) >>> 0; hit.push(((s >> 16) & 255) / 128 - 1); }
wav('Song.wav', 22050, song);
wav('Hit.wav', 22050, hit);

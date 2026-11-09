// devassets.js - makes the DEVELOPMENT assets: random ROMs and a few strings encoded with them.
// (c) 2026 Cyborg Unicorn Pty Ltd
//
//   node tools/devassets.js
//
// These are stand-ins. For the final build, replace the files in assets/ with the real ROMs and encodings (same names, same
// formats - see inner-voyage... no: see introduction-to-zoscii.md, "Replacing the assets") and run tools/assets.js.
//
// Writes into assets/:
//   rom1.bin rom2.bin rom3.bin   128KB ROMs (layer ROMs; a file with 2 layers uses rom1 + rom2, 3 layers rom1 + rom2 + rom3)
//   rom_s.bin                    a 2KB ROM (a SMALL ROM: shows how a small pool leaks)
//   file_a.bin .. file_d.bin     the files an attacker holds, exactly as they would be sent
//   alt_b.bin                    the patch that turns rom1 into a ROM that reads file B as a different sentence
//   manifest.json                what each file is (protocol, layers, ROMs), the cribs, the texts
// ES5.
'use strict';
var fs = require('fs');
var path = require('path');
var Z = require('./zlib.js');
var A = path.join(__dirname, '..', 'assets');

// a repeatable generator, so the dev ROMs are the same each run (the encodings still differ: the encoder seeds from the clock)
var st = 0x2545F491;
function rnd() { st ^= st << 13; st >>>= 0; st ^= st >>> 17; st ^= st << 5; st >>>= 0; return st / 4294967296; }
function skewedRom(n, k)
{
	// skewed on purpose (the ROMs are not balanced): the byte is the k-th root of a uniform number
	var r = new Uint8Array(n), i;
	for (i = 0; i < n; i++) { r[i] = Math.min(255, Math.floor(Math.pow(rnd(), k) * 256)); }
	return r;
}
function covers(r, lo, hi)
{
	var seen = {}, i, c = 0;
	for (i = lo; i < hi; i++) { if (!seen[r[i]]) { seen[r[i]] = 1; c++; } }
	return c;
}

var roms = [skewedRom(131072, 1.3), skewedRom(131072, 1.6), skewedRom(131072, 1.2)];
var small;
do { small = skewedRom(2048, 1.2); } while (covers(small, 0, 2048) < 200);   // 2KB: most byte values are there (the letters used must be)
function arr(u) { return Array.prototype.slice.call(u); }
function bytes(s) { var o = [], i; for (i = 0; i < s.length; i++) { o.push(s.charCodeAt(i)); } return o; }

var MSG_A = 'the sender said meet me at the pier at three the pier is safe and the buyer will come alone with the case';
var MSG_B = 'meet me at the pier at three the pier is safe';
var ALTS = ['buy some milk and bread then go straight home', 'the red fox jumped over the old stone wall now', 'bring the milk and bread home before it gets dark'];

function ZOS(rom) { return { elemBits: 16, sliding: false, blocks: 0, blockMin: 128, blockMax: 512, prefix: { on: false, width: 1, min: 0, max: 0 }, suffix: { on: false, width: 1, min: 0, max: 0 }, rollingHash: 0, crc32: false, zac: { on: false, value: '', bytes: 16, closesBlock: true }, seed: 0 }; }
function UNS() { return { elemBits: 16, sliding: true, blocks: 0, blockMin: 128, blockMax: 512, prefix: { on: true, width: 1, min: 10, max: 255 }, suffix: { on: true, width: 1, min: 10, max: 255 }, rollingHash: 0, crc32: false, zac: { on: false, value: '', bytes: 16, closesBlock: true }, seed: 0 }; }

function enc(rom, msg, args)
{
	var f = Z.gen_encode(arr(rom), msg, args);
	if (!f.length && msg.length) { throw new Error('encode failed: a value is missing from the ROM window'); }
	return f;
}
function dec(rom, f, args) { return Z.gen_decode(arr(rom), f, args); }
function same(a, b) { var i; if (a.length !== b.length) { return false; } for (i = 0; i < a.length; i++) { if (a[i] !== b[i]) { return false; } } return true; }

// file A: ZOSCII (no framing) on the small ROM, a long message: a small pool repeats addresses
var fa = enc(small, bytes(MSG_A), ZOS());
if (!same(dec(small, fa, ZOS()), bytes(MSG_A))) { throw new Error('A does not round trip'); }
// file B: UNSIGNAL, ROM 1. Tried until the alternative sentence fits (no cell used for two different letters)
var fb, alt, altText, patch, tries = 0;
for (;;)
{
	tries++;
	if (tries > 400) { throw new Error('no alternative sentence fits file B'); }
	fb = enc(roms[0], bytes(MSG_B), UNS());
	altText = null;
	ALTS.forEach(function(a) { if (a.length === MSG_B.length && !altText) { altText = a; } });
	if (!altText) { throw new Error('no alternative sentence of length ' + MSG_B.length + ': ' + ALTS.map(function(a) { return a.length; })); }
	var fr = Z.gen_frame(arr(roms[0]), fb, UNS());
	var cells = fr.cells, want = bytes(altText), ok = true, map = {}, i;
	// the header cells must keep their values (they are read at absolute addresses)
	var hdr = [];
	for (i = 0; i < 4; i++) { hdr.push(fb[2 * i] | (fb[2 * i + 1] << 8)); }
	for (i = 0; i < cells.length; i++)
	{
		if (map[cells[i]] !== undefined && map[cells[i]] !== want[i]) { ok = false; break; }
		map[cells[i]] = want[i];
		if (hdr.indexOf(cells[i]) >= 0) { ok = false; break; }
	}
	if (ok) { patch = map; break; }
}
if (!same(dec(roms[0], fb, UNS()), bytes(MSG_B))) { throw new Error('B does not round trip'); }
var romAlt = new Uint8Array(roms[0]);
Object.keys(patch).forEach(function(k) { romAlt[+k] = patch[k]; });
if (String.fromCharCode.apply(null, dec(romAlt, fb, UNS())) !== altText) { throw new Error('alt ROM does not read B as the alternative sentence'); }
// file C: 2 layers (inner ROM 1, outer ROM 2)
var inC = enc(roms[0], bytes(MSG_B), UNS());
var fc = enc(roms[1], inC, UNS());
if (!same(dec(roms[0], dec(roms[1], fc, UNS()), UNS()), bytes(MSG_B))) { throw new Error('C does not round trip'); }
// file D: 3 layers
var in1, in2, fd;
do { in1 = enc(roms[0], bytes(MSG_B), UNS()); in2 = enc(roms[1], in1, UNS()); fd = enc(roms[2], in2, UNS()); } while (fd.length > 2300);   // the program's working arrays hold 2304 bytes
if (!same(dec(roms[0], dec(roms[1], dec(roms[2], fd, UNS()), UNS()), UNS()), bytes(MSG_B))) { throw new Error('D does not round trip'); }

function wr(name, a) { fs.writeFileSync(path.join(A, name), Buffer.from(a)); }
wr('rom1.bin', roms[0]); wr('rom2.bin', roms[1]); wr('rom3.bin', roms[2]); wr('rom_s.bin', small);
wr('file_a.bin', fa); wr('file_b.bin', fb); wr('file_c.bin', fc); wr('file_d.bin', fd);
var pb = [];
Object.keys(patch).forEach(function(k) { var i = +k; pb.push(i & 255, (i >> 8) & 255, (i >> 16) & 255, patch[k]); });
wr('alt_b.bin', pb);

var manifest = {
	_about: 'what the program knows about each file. layers are listed outermost first: [protocol, rom]; protocol 0 ZOSCII, 1 UNSIGNAL; rom 0-2 = rom1-3 (128KB), 3 = rom_s (2KB). win = the outer ROM window in bytes.',
	files: [
		{ name: 'A  ZOSCII, SMALL 2KB ROM', file: 'file_a.bin', layers: [[0, 3]], win: 2048 },
		{ name: 'B  UNSIGNAL, ONE LAYER', file: 'file_b.bin', layers: [[1, 0]], win: 65536 },
		{ name: 'C  UNSIGNAL, TWO LAYERS', file: 'file_c.bin', layers: [[1, 1], [1, 0]], win: 65536 },
		{ name: 'D  UNSIGNAL, THREE LAYERS', file: 'file_d.bin', layers: [[1, 2], [1, 1], [1, 0]], win: 65536 }
	],
	cribs: ['the pier', 'meet me', 'safe', 'the sender', 'xyzzy plugh', 'aaaaaaaa'],
	altFile: 1,
	_dev: { msgA: MSG_A, msgB: MSG_B, altText: altText }
};
fs.writeFileSync(path.join(A, 'manifest.json'), JSON.stringify(manifest, null, 1));
console.log('dev assets written to assets/ (alt sentence for B: "' + altText + '", ' + Object.keys(patch).length + ' patched cells, ' + tries + ' tries)');
console.log('file sizes: A ' + fa.length + ', B ' + fb.length + ', C ' + fc.length + ', D ' + fd.length);

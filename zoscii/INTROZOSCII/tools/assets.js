// assets.js - packs INTRODUCTION TO ZOSCII's data: assets/INTRO.DAT (the NEX's data blocks), src/Data.cls, and patches Main.bas's block count.
// (c) 2026 Cyborg Unicorn Pty Ltd
//
//   node tools/assets.js
//
// Reads from assets/: rom1.bin rom2.bin rom3.bin (128KB each), rom_s.bin (up to 2KB), file_a.bin .. (the encoded files), alt_b.bin
// (the patch list: 4 bytes a cell, ROM 1 index low, mid, high, new value) and manifest.json. node tools/devassets.js makes a development set.
// Blocks (16K each): 0 tables (text, font, manifest, cribs), 1-8 ROM 1, 9-16 ROM 2, 17-24 ROM 3, 25 the small ROM (2KB), then the files, then the patch,
// 26 scratch, 27-34 the demo's ROM (blank, made at run time), 35-38 the words (assets/words.txt), 39 the demo's messages (blank).
// ES5.
'use strict';
var fs = require('fs');
var path = require('path');
var ROOT = path.join(__dirname, '..');
var A = path.join(ROOT, 'assets');

function rd(n) { return fs.readFileSync(path.join(A, n)); }
function block() { return Buffer.alloc(16384); }
var man = JSON.parse(rd('manifest.json').toString('utf8'));
var blocks = [block()];                       // 0: the tables, filled below
var ROMB = [];
['rom1.bin', 'rom2.bin', 'rom3.bin'].forEach(function(n)
{
	var d = rd(n), k, b;
	if (d.length !== 131072) { throw new Error(n + ' must be 131072 bytes, not ' + d.length); }
	ROMB.push(blocks.length);
	for (k = 0; k < 8; k++) { b = block(); d.copy(b, 0, k * 16384, (k + 1) * 16384); blocks.push(b); }
});
var FILEB = blocks.length;                     // 25: the small ROM, the files, the patch
var fb = block(), fo = 0;
var small = rd('rom_s.bin');
if (small.length > 2048) { throw new Error('rom_s.bin must be at most 2048 bytes'); }
small.copy(fb, 0); fo = 2048;
var fileOff = [], fileLen = [];
man.files.forEach(function(f)
{
	var d = rd(f.file);
	fileOff.push(fo); fileLen.push(d.length);
	d.copy(fb, fo); fo += d.length;
});
var patch = rd('alt_b.bin'), PATCHOFF = fo;
patch.copy(fb, fo); fo += patch.length;
if (fo > 16384) { throw new Error('the files and the patch do not fit in one block (' + fo + ')'); }
blocks.push(fb);
var SCRB = blocks.length;                       // a blank block: scratch RAM (the file made in Have a Play, the attacker's tables)
blocks.push(block());

var GENB = blocks.length;                       // 8 blank blocks: the demo's ROM, made at run time from the Rng
var gi;
for (gi = 0; gi < 8; gi++) { blocks.push(block()); }
var DICTB = blocks.length;                      // 4 blocks: up to 8192 words, 8 bytes a word (0 padded), the most common English words of at most 8 letters
var words = rd('words.txt').toString('utf8').split(/\r?\n/).filter(function(x) { return /^[a-z]{1,8}$/.test(x); });
// words left out of the demo's random sentences: religions and their people, peoples and places in conflict, war and violence, so a random sentence never reads as a statement about any of them
var BLOCK = ('muslim muslims islam islamic jew jews jewish christ christian christians catholic catholics hindu hindus buddhist sikh allah god jihad church mosque ' +
  'arab arabs israel israeli palestine palestinian iraq iran afghan taliban isis hamas terror terrorism terrorist nazi nazis hitler ' +
  'war wars bomb bombs kill killed killing rape slave slavery gay racist racism negro').split(' ');
var nw = words.length;
words = words.filter(function(x) { return BLOCK.indexOf(x) < 0; });
console.log('words: ' + nw + ' -> ' + words.length + ' (' + (nw - words.length) + ' left out)');
if (words.length > 8192) { words = words.slice(0, 8192); }
for (gi = 0; gi < 4; gi++) { blocks.push(block()); }
words.forEach(function(wd, i) { blocks[DICTB + (i >> 11)].write(wd, (i & 2047) * 8, 'latin1'); });
var DEMOB = blocks.length;                      // 1 blank block: the ten sets of messages and their encodings
blocks.push(block());
var WOB = blocks.length;                        // 1 blank block: Rom.W (byte 0) and Rom.O (byte 4096), 2304 bytes each
blocks.push(block());
var TAB2 = blocks.length;                       // the tables' second block: Vid.TabB reads offsets 16384 and up from here
blocks.push(block());

var mb = path.join(ROOT, 'src', 'Main.bas'), mt = fs.readFileSync(mb, 'utf8');
mt = mt.replace(/Option NexData "INTRO.DAT", \d+/, 'Option NexData "INTRO.DAT", ' + blocks.length);
fs.writeFileSync(mb, mt);

// the 5 x 7 font: ASCII 32-90, 5 column bytes a glyph (bit 0 the top row)
var FONT = '00 00 00 00 00,00 00 5F 00 00,00 07 00 07 00,14 7F 14 7F 14,24 2A 7F 2A 12,23 13 08 64 62,36 49 55 22 50,00 05 03 00 00,00 1C 22 41 00,00 41 22 1C 00,14 08 3E 08 14,08 08 3E 08 08,00 50 30 00 00,08 08 08 08 08,00 60 60 00 00,20 10 08 04 02,3E 51 49 45 3E,00 42 7F 40 00,42 61 51 49 46,21 41 45 4B 31,18 14 12 7F 10,27 45 45 45 39,3C 4A 49 49 30,01 71 09 05 03,36 49 49 49 36,06 49 49 29 1E,00 36 36 00 00,00 56 36 00 00,08 14 22 41 00,14 14 14 14 14,00 41 22 14 08,02 01 51 09 06,32 49 79 41 3E,7E 11 11 11 7E,7F 49 49 49 36,3E 41 41 41 22,7F 41 41 22 1C,7F 49 49 49 41,7F 09 09 09 01,3E 41 49 49 7A,7F 08 08 08 7F,00 41 7F 41 00,20 40 41 3F 01,7F 08 14 22 41,7F 40 40 40 40,7F 02 0C 02 7F,7F 04 08 10 7F,3E 41 41 41 3E,7F 09 09 09 06,3E 41 51 21 5E,7F 09 19 29 46,46 49 49 49 31,01 01 7F 01 01,3F 40 40 40 3F,1F 20 40 20 1F,3F 40 38 40 3F,63 14 08 14 63,07 08 70 08 07,61 51 49 45 43'.split(',').join(' ').split(' ').map(function(h) { return parseInt(h, 16); });

var tab = Buffer.alloc(32768), toff = 0, out = [];
function pack(name, arr)
{
	name = name.replace('Data.', '');
	out.push('Public Const ' + name + ' = ' + toff);
	arr.forEach(function(v, i) { tab[toff + i] = v & 255; });
	toff += arr.length;
}
function strBytes(s) { var a = require('./lang.js').encode(s); a.push(0); return a; }

var LG = require('./lang.js');
FONT = FONT.concat(LG.extFont());       // + 24 glyphs (Spanish, Russian): text bytes 128 and up
pack('T_FONT', FONT);
out.push("' Data - tables made by tools/assets.js (don't edit: run the tool). (c) 2026 Cyborg Unicorn Pty Ltd");
out.push('Option Explicit');
out.push('Public Const TABB = 0');
out.push('Public Const ROMB0 = ' + ROMB[0]);
out.push('Public Const ROMB1 = ' + ROMB[1]);
out.push('Public Const ROMB2 = ' + ROMB[2]);
out.push('Public Const ROMBS = ' + FILEB);
out.push('Public Const FILEB = ' + FILEB);
out.push('Public Const SCRB = ' + SCRB);
out.push('Public Const WOB = ' + WOB);
out.push('Public Const TAB2 = ' + TAB2);
out.push('Public Const GENB = ' + GENB);
out.push('Public Const DICTB = ' + DICTB);
out.push('Public Const DEMOB = ' + DEMOB);
out.push('Public Const NWORDS = ' + words.length);
out.push('Public Const NFILES = ' + man.files.length);
out.push('Public Const NCRIBS = ' + man.cribs.length);
out.push('Public Const PATCHOFF = ' + PATCHOFF);
out.push('Public Const PATCHN = ' + (patch.length / 4));
out.push('Public Const ALTFILE = ' + man.altFile);
out.push('');
var LANG = (process.env.ZLANG || 'en').toLowerCase();
var txt = require(LANG === 'en' ? './text.js' : './lang/' + LANG + '.js');
txt.forEach(function(t)
{
	LG.encode(t[1], t[0]);
	pack('Data.' + t[0], strBytes(t[1]));
});
// file names and cribs as text, then the tables that point at them
var nameOff = [], cribOff = [];
man.files.forEach(function(f, i) { nameOff.push(toff); pack('Data.TX_FILE' + i, strBytes(f.name)); });
man.cribs.forEach(function(c, i) { cribOff.push(toff); pack('Data.TX_CRIB' + i, strBytes(c)); });
// manifest: 16 bytes a file: layers, (proto, rom) x 3, 0 (rolling hash on the outside layer: 1), win lo hi, file offset lo hi, length lo hi, name offset lo hi
var mf = [];
man.files.forEach(function(f, i)
{
	var r = [f.layers.length], k;
	for (k = 0; k < 3; k++) { r.push(f.layers[k] ? f.layers[k][0] : 0, f.layers[k] ? f.layers[k][1] : 0); }
	r.push(0, f.win & 255, f.win >> 8, fileOff[i] & 255, fileOff[i] >> 8, fileLen[i] & 255, fileLen[i] >> 8, nameOff[i] & 255, nameOff[i] >> 8);
	if (r.length !== 16) { throw new Error('manifest row is ' + r.length + ' bytes'); }
	mf = mf.concat(r);
});
pack('T_MAN', mf);
var cr = [];
cribOff.forEach(function(o) { cr.push(o & 255, o >> 8); });
pack('T_CRIBS', cr);
out.push('');
if (toff > 32768) { throw new Error('tables too big: ' + toff); }
tab.copy(blocks[0], 0, 0, 16384);
tab.copy(blocks[TAB2], 0, 16384, 32768);
fs.writeFileSync(path.join(A, 'INTRO.DAT'), Buffer.concat(blocks));
console.log('assets/INTRO.DAT: ' + blocks.length + ' blocks (tables ' + toff + ' bytes, files block ' + fo + ' bytes)');
fs.writeFileSync(path.join(ROOT, 'src', 'Data.cls'), out.join('\n') + '\n');
console.log('src/Data.cls');

#!/usr/bin/env node
// trscmd.js - wrap a raw NTC trs80 / system80 image into a TRS-80 /CMD load module.
// (c) 2026 Cyborg Unicorn Pty Ltd
//
// The NTC trs80 build is a RAW binary assembled at its org (#5200). A /CMD file
// is the loadable form: a run of records (type, length, data). This writes:
//   05 06 <name>          the module name (6 bytes)
//   01 <len> <lo><hi> ..  load blocks, up to 256 data bytes each (len counts the
//                         2 address bytes and wraps: 03=1B, 00=254, 01=255, 02=256)
//   02 02 <lo><hi>        the entry point (last record)
// Format: Julian's "TRS-80 hardware, for NTC BASIC" notes; electrickery.nl Trscmdff.txt.
//
// Usage:
//   node tools/trscmd.js <in.bin> <out.cmd> [loadHex] [entryHex] [name]
//     loadHex   load/org address, hex (default 5200 - the trs80 ;@org)
//     entryHex  entry point, hex   (default = loadHex)
//     name      module name, <=6 chars (default from out.cmd, upper-cased)
//
// Example:  node tools/trscmd.js BOUNCE.bin BOUNCE/CMD 5200 5200 BOUNCE

'use strict';
var fs = require('fs');

function die(m) { process.stderr.write('trscmd: ' + m + '\n'); process.exit(1); }

var a = process.argv.slice(2);
if (a.length < 2) { die('usage: trscmd.js <in.bin> <out.cmd> [loadHex] [entryHex] [name]'); }

var strIn = a[0], strOut = a[1];
var intLoad = parseInt((a[2] || '5200').replace(/^(#|0x|\$)/i, ''), 16);
var intEntry = (a[3] !== undefined) ? parseInt(a[3].replace(/^(#|0x|\$)/i, ''), 16) : intLoad;
var strName = (a[4] !== undefined) ? a[4] : strOut.replace(/^.*[\/\\]/, '').replace(/[\/.].*$/, '');

if (isNaN(intLoad) || intLoad < 0 || intLoad > 0xFFFF) { die('bad load address'); }
if (isNaN(intEntry) || intEntry < 0 || intEntry > 0xFFFF) { die('bad entry address'); }

var img = fs.readFileSync(strIn);
if (intLoad + img.length - 1 > 0xFFFF) { die('image runs past #FFFF at this load address'); }

// name record: 6 bytes, space-padded, upper-cased (TRS-80 names are upper case)
var name6 = (strName.toUpperCase() + '      ').slice(0, 6);
var out = [0x05, 0x06];
for (var i = 0; i < 6; i++) { out.push(name6.charCodeAt(i) & 0xFF); }

// load blocks: up to 256 data bytes each
var addr = intLoad, off = 0;
while (off < img.length) {
	var n = Math.min(256, img.length - off);         // data bytes this block (1..256)
	out.push(0x01);                                   // type 01 = load
	out.push((n + 2) & 0xFF);                         // length byte counts the 2 addr bytes, wraps
	out.push(addr & 0xFF, (addr >> 8) & 0xFF);        // load address (low, high)
	for (var j = 0; j < n; j++) { out.push(img[off + j]); }
	addr += n;
	off += n;
}

// entry record (last)
out.push(0x02, 0x02, intEntry & 0xFF, (intEntry >> 8) & 0xFF);

fs.writeFileSync(strOut, Buffer.from(out));
process.stderr.write('trscmd: ' + strOut + '  ' + img.length + ' bytes @ #' +
	intLoad.toString(16).toUpperCase() + ', entry #' + intEntry.toString(16).toUpperCase() +
	', ' + out.length + ' bytes /CMD\n');

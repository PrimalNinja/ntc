#!/usr/bin/env node
// amigabuild.js - build an Amiga boot disc (.ADF) from NTC BASIC (the amiga platform)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node amigabuild.js Main.bas [More.cls ...] --out=GAME.adf [--log] [--file=NAME=path[@disc]] ...
//                      [--vasm=path/to/vasmm68k_mot] [--asm=GAME.s] [--list=GAME.lst]
//                      [-- options for cli.js]
//
// Compiles with the NTC compiler (cli.js --platform=amiga), assembles with vasm (Motorola
// syntax: vasmm68k_mot -spaces -Fbin -coalesced) and puts the result at the start of a floppy
// image: 80 tracks, 2 sides, 11 sectors of 512 bytes (901120 bytes). Its first two sectors are
// the boot block (Kickstart reads it and runs it; this fills in its checksum); it loads the
// rest. No AmigaDOS on the disc: the program is all there is.
// --file=NAME=path: a file for the Loader class (Loader.Load "NAME", ...), after the program on
//   the disc. NAME: up to 15 characters, kept in capitals. @2, @3 ...: on another disc of the
//   set (GAME_2.adf ...: a data disc, not one that boots), for a game too big for one. The list
//   of the files is on the boot disc.
// --log: a test build (vasm -DNTC_AMILOG=1): what the console prints is kept in RAM from
//   $070000, for test/amigarun.py --log.
// vasm: http://sun.hasenbraten.de/vasm/ (make CPU=m68k SYNTAX=mot); NTC_VASM can give its path.
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');

var ADF_SIZE = 80 * 2 * 11 * 512;
var arrArgs = process.argv.slice(2);
var arrFiles = [], arrExtra = [], arrData = [];
var strOut = '', strAsm = '', strList = '', blnLog = false;
var strVasm = process.env.NTC_VASM || 'vasmm68k_mot';
var blnRest = false;

function die(str_a)
{
	process.stderr.write('ERR ' + str_a + '\n');
	process.exit(1);
}

arrArgs.forEach(function(str_a)
{
	var arrM = null;

	if (blnRest) { arrExtra.push(str_a); }
	else if (str_a === '--') { blnRest = true; }
	else if (str_a.indexOf('--out=') === 0) { strOut = str_a.slice(6); }
	else if (str_a.indexOf('--asm=') === 0) { strAsm = str_a.slice(6); }
	else if (str_a.indexOf('--list=') === 0) { strList = str_a.slice(7); }
	else if (str_a.indexOf('--vasm=') === 0) { strVasm = str_a.slice(7); }
	else if (str_a.indexOf('--file=') === 0)
	{
		arrM = str_a.slice(7).match(/^([^=]+)=(.*?)(?:@(\d+))?$/);
		if (!arrM) { die('--file=NAME=path[@disc]: ' + str_a); }
		if (arrM[1].length > 15) { die('a file\'s name is up to 15 characters: ' + arrM[1]); }
		arrData.push({ name: arrM[1].toUpperCase(), path: arrM[2], disc: arrM[3] ? parseInt(arrM[3], 10) : 1 });
	}
	else if (str_a === '--log') { blnLog = true; }
	else if (str_a.indexOf('--') === 0) { arrExtra.push(str_a); }
	else { arrFiles.push(str_a); }
});
if (arrFiles.length === 0)
{
	console.log('amigabuild.js Main.bas [More.cls ...] --out=GAME.adf [--log] [--file=NAME=path[@disc]]');
	process.exit(1);
}
strOut = strOut || arrFiles[0].replace(/\.[^.\/\\]*$/, '') + '.adf';
strAsm = strAsm || strOut.replace(/\.[^.\/\\]*$/, '') + '.s';
var strStem = strOut.replace(/\.[^.\/\\]*$/, '');
var strBin = strStem + '.bin';

var objR = cp.spawnSync(process.execPath, [path.join(__dirname, 'cli.js'), '--platform=amiga'].concat(arrExtra, arrFiles), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
if (objR.stderr) { process.stderr.write(objR.stderr); }
if ((objR.status !== 0) || /^ERR/m.test(objR.stderr || ''))
{
	process.exit(1);
}
fs.writeFileSync(strAsm, objR.stdout);

var arrCmd = ['-quiet', '-spaces', '-Fbin', '-coalesced', '-o', strBin];
if (blnLog) { arrCmd.push('-DNTC_AMILOG=1'); }
if (strList) { arrCmd.push('-L', strList); }
arrCmd.push(strAsm);
objR = cp.spawnSync(strVasm, arrCmd, { encoding: 'utf8' });
if (objR.error || (objR.status !== 0))
{
	process.stderr.write((objR.error ? String(objR.error) + '\n' : '') + (objR.stdout || '') + (objR.stderr || ''));
	process.exit(1);
}
var bufBin = fs.readFileSync(strBin);
if (bufBin.toString('latin1', 0, 4) !== 'DOS\0' || bufBin.toString('latin1', 0x3F0, 0x3F4) !== 'NTCD')
{
	die('the boot block is not where it should be: the disc would not boot');
}

// the discs: 1 the boot disc (the program, then its files), 2 ... data discs
var intDiscs = 1;
arrData.forEach(function(obj_a) { if (obj_a.disc > intDiscs) { intDiscs = obj_a.disc; } });
var arrDiscs = [], arrNext = [];
var intMark = 0, intI = 0;
for (intI = 0; intI < bufBin.length; intI += 97) { intMark = (intMark * 31 + bufBin[intI]) & 0xFFFF; }	// the set's mark: the same on each of its discs
intMark = intMark || 1;
for (intI = 1; intI <= intDiscs; intI++)
{
	arrDiscs.push(Buffer.alloc(ADF_SIZE, 0));
	arrNext.push(2);		// (a data disc: sectors 0-1 hold its label)
}
if (bufBin.length > ADF_SIZE) { die('the program (' + bufBin.length + ' bytes) is bigger than the disc (' + ADF_SIZE + ')'); }
bufBin.copy(arrDiscs[0], 0);
arrNext[0] = Math.ceil(bufBin.length / 512);
var intListAt = 0;
if (arrData.length > 0)
{
	// the list: an entry is 24 bytes - the name (16, 0 filled), its disc (a word), its first
	// sector (a word), its bytes (a long)
	intListAt = arrNext[0];
	arrNext[0] += Math.ceil(arrData.length * 24 / 512);
	arrData.forEach(function(obj_a, int_a)
	{
		var bufF = fs.readFileSync(obj_a.path);
		var intSecs = Math.ceil(bufF.length / 512);
		var intD = obj_a.disc - 1;
		var intO = intListAt * 512 + int_a * 24;

		if ((arrNext[intD] + intSecs) * 512 > ADF_SIZE) { die(obj_a.name + ' (' + bufF.length + ' bytes) does not fit on disc ' + obj_a.disc + ' (' + (ADF_SIZE - arrNext[intD] * 512) + ' left): put it on another with @' + (obj_a.disc + 1)); }
		bufF.copy(arrDiscs[intD], arrNext[intD] * 512);
		arrDiscs[0].write(obj_a.name, intO, 'latin1');
		arrDiscs[0].writeUInt16BE(obj_a.disc, intO + 16);
		arrDiscs[0].writeUInt16BE(arrNext[intD], intO + 18);
		arrDiscs[0].writeUInt32BE(bufF.length, intO + 20);
		obj_a.sector = arrNext[intD];
		obj_a.bytes = bufF.length;
		arrNext[intD] += intSecs;
	});
}
arrDiscs.forEach(function(buf_a, int_a)
{
	var intSum = 0, intK = 0, intV = 0;
	var strName = (int_a === 0) ? strOut : strStem + '_' + (int_a + 1) + '.adf';

	if (int_a > 0) { buf_a.write('NTC\0', 0, 'latin1'); }		// (not DOS: Kickstart will not try to boot it)
	buf_a.write('NTCD', 0x3F0, 'latin1');
	buf_a.writeUInt16BE(int_a + 1, 0x3F4);
	buf_a.writeUInt16BE(intMark, 0x3F6);
	buf_a.writeUInt16BE((int_a === 0) ? intListAt : 0, 0x3F8);
	buf_a.writeUInt16BE((int_a === 0) ? arrData.length : 0, 0x3FA);
	if (int_a === 0)
	{
		// the boot block's checksum: its 256 longs add (each carry added back in) to $FFFFFFFF
		buf_a.writeUInt32BE(0, 4);
		for (intK = 0; intK < 1024; intK += 4)
		{
			intV = intSum + buf_a.readUInt32BE(intK);
			intSum = (intV > 0xFFFFFFFF) ? (intV - 0x100000000 + 1) : intV;
		}
		buf_a.writeUInt32BE((~intSum) >>> 0, 4);
	}
	fs.writeFileSync(strName, buf_a);
	console.log(strName + ': ' + (int_a === 0 ? bufBin.length + ' bytes of program, ' : '') + (arrNext[int_a] * 512) + ' of ' + ADF_SIZE + ' bytes used');
});
arrData.forEach(function(obj_a)
{
	console.log('  ' + obj_a.name + ': disc ' + obj_a.disc + ', sector ' + obj_a.sector + ', ' + obj_a.bytes + ' bytes');
});

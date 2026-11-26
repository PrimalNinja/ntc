// c64build.js - an NTC BASIC program to a Commodore 64 PRG that needs an REU (the c64reu platform)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node c64build.js Main.bas [More.cls ...] --out=GAME.PRG [--split] [--d64] [--add=FILE ...]
//                     [--reu] [--log] [--list] [--vasm=path]
//
// Compiles for the c64reu platform (cli.js) and assembles with vasm (6502, oldstyle syntax:
// vasm6502_oldstyle -opt-branch -Fbin), then puts the load address ($0801) in front: a PRG
// that LOAD "GAME",8 and RUN start. The thread - the compiled BASIC - is the last part of the
// file; the program's start code puts it into the REU.
// The whole file must load below $D000: 51,199 bytes at most. A bigger program:
// --split: the threads go into files of their own, GAME.0, GAME.1 ..., which the program reads
//   into the REU when it starts (through the KERNAL, from the drive it was loaded from). The
//   PRG then holds only what stays in the C64. All the files go on the same disc.
//   GAME.0 is the kernel's thread (up to 65,024 bytes; 32,256 with lots). With Option Lot each
//   lot adds two files: its thread (up to 65,280 bytes) and its workspace (up to 32,768).
// --d64: also GAME.D64, a 1541 disc with the PRG (first, so LOAD "*",8 finds it), the --split
//   files, and every --add=FILE (a data file the program reads with Disk.LoadReu; its name on
//   the disc is the file's name in capitals, 16 characters at most, no extension dropped).
// --reu: with --split, also GAME.REU: the REU's memory with the threads and workspaces in it.
//   An Ultimate or an emulator that loads it into the REU first starts the program at once,
//   with nothing read from disc (the program finds its own mark there).
// Option Lot: the lots' workspaces all go at one address in the C64, as high as the biggest
//   lets it be (it ends at $CFFF). The program is assembled twice: once to measure them.
// --log: a test build (vasm -DNTC_C64LOG=1): what the console prints is also kept in
//   $F000-$F7FF, for test/c64run.py --log.
// --list: also GAME.lst (vasm's listing, with every label's address).
// Options this does not know (--const=NAME=value ...) go on to cli.js.
// vasm: http://sun.hasenbraten.de/vasm/ (make CPU=6502 SYNTAX=oldstyle). On the PATH, or
// NTC_VASM65 / --vasm= give its path.
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');

var arrFiles = [], arrExtra = [];
var strOut = '', strAsm = '', blnLog = false, blnList = false, blnSplit = false, blnD64 = false, blnReu = false;
var arrAdd = [];
var strVasm = process.env.NTC_VASM65 || 'vasm6502_oldstyle';

function die(str_a)
{
	process.stderr.write('ERR ' + str_a + '\n');
	process.exit(1);
}

process.argv.slice(2).forEach(function(str_a)
{
	if (str_a.indexOf('--out=') === 0) { strOut = str_a.slice(6); }
	else if (str_a.indexOf('--asm=') === 0) { strAsm = str_a.slice(6); }
	else if (str_a.indexOf('--vasm=') === 0) { strVasm = str_a.slice(7); }
	else if (str_a === '--log') { blnLog = true; }
	else if (str_a === '--list') { blnList = true; }
	else if (str_a === '--split') { blnSplit = true; }
	else if (str_a === '--d64') { blnD64 = true; }
	else if (str_a === '--reu') { blnReu = true; }
	else if (str_a.indexOf('--add=') === 0) { arrAdd.push(str_a.slice(6)); }
	else if (str_a.indexOf('--') === 0) { arrExtra.push(str_a); }
	else { arrFiles.push(str_a); }
});
if (arrFiles.length === 0)
{
	console.log('c64build.js Main.bas [More.cls ...] --out=GAME.PRG [--split] [--d64] [--add=FILE] [--reu] [--log] [--list]');
	process.exit(1);
}
strOut = strOut || arrFiles[0].replace(/\.[^.\/\\]*$/, '') + '.prg';
var strStem = strOut.replace(/\.[^.\/\\]*$/, '');
strAsm = strAsm || strStem + '.s';

var objR = cp.spawnSync(process.execPath, [path.join(__dirname, 'cli.js'), '--platform=c64reu', '--name=' + path.basename(strStem)].concat(arrExtra, arrFiles), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
if (objR.stderr) { process.stderr.write(objR.stderr); }
if ((objR.status !== 0) || /^ERR/m.test(objR.stderr || ''))
{
	process.exit(1);
}
fs.writeFileSync(strAsm, objR.stdout);

var strBin = strOut + '.bin';
var arrCmd = ['-quiet', '-opt-branch', '-Fbin', '-o', strBin];
if (blnLog) { arrCmd.push('-DNTC_C64LOG=1'); }
if (blnSplit) { arrCmd.push('-DNTC_C64SPLIT=1'); }
if (blnList) { arrCmd.push('-L', strStem + '.lst'); }
arrCmd.push(strAsm);
function assemble(arrMore_a)
{
	var objA = cp.spawnSync(strVasm, arrCmd.slice(0, -1).concat(arrMore_a || [], [strAsm]), { encoding: 'utf8' });

	if (objA.error || (objA.status !== 0))
	{
		process.stderr.write((objA.error ? String(objA.error) + '\n' : '') + (objA.stdout || '') + (objA.stderr || ''));
		process.exit(1);
	}
	return fs.readFileSync(strBin);
}
// the blobs: what goes into the REU. Each is after an "NTC!BLB>" in the file, in the order the
// compiler lists them ("blob: thread lot 0" ...)
var strAsmText = fs.readFileSync(strAsm, 'utf8');
var arrBlobInfo = [];
strAsmText.replace(/blob: (thread|workspace) lot (\d+)/g, function(strAll_a, strKind_a, strLot_a)
{
	arrBlobInfo.push({ kind: strKind_a, lot: parseInt(strLot_a, 10) });
	return strAll_a;
});
function blobs(buf_a)
{
	var arrAt = [];
	var intP = buf_a.indexOf('NTC!BLB>', 0, 'latin1');

	while (intP >= 0)
	{
		arrAt.push(intP);
		intP = buf_a.indexOf('NTC!BLB>', intP + 8, 'latin1');
	}
	if (arrAt.length !== arrBlobInfo.length) { die('the threads were not found in the program (' + arrAt.length + ' of ' + arrBlobInfo.length + ')'); }
	return { head: buf_a.slice(0, arrAt[0]), parts: arrAt.map(function(intAt_a, intK_a) { return buf_a.slice(intAt_a + 8, (intK_a + 1 < arrAt.length) ? arrAt[intK_a + 1] : buf_a.length); }) };
}
var intLots = arrBlobInfo.reduce(function(intM_a, obj_a) { return Math.max(intM_a, obj_a.lot); }, 0);
var intWsOrg = 0;
var bufFirst = assemble();
if (intLots > 0)
{
	var intWsMax = blobs(bufFirst).parts.reduce(function(intM_a, buf_a, intK_a) { return (arrBlobInfo[intK_a].kind === 'workspace') ? Math.max(intM_a, buf_a.length) : intM_a; }, 0);
	if (intWsMax > 0x8000) { die('a lot\'s workspace is ' + intWsMax + ' bytes: 32768 at most'); }
	intWsOrg = (0xD000 - intWsMax) & 0xFF00;
	bufFirst = assemble(['-DNTC_WS_ORG=' + intWsOrg]);
}
var bufBody = bufFirst;
fs.unlinkSync(strBin);

// a 1541 disc image (35 tracks, 683 sectors) with these files ({ name, data: Buffer }), all PRG
function d64(strDisc_a, arrFiles_a)
{
	var bufD = Buffer.alloc(174848, 0);
	var arrFree = [];			// every sector but track 18's, in the order they are handed out
	var arrBam = [];
	var intT = 0, intS = 0, intI = 0;

	function spt(intT_a) { return (intT_a <= 17) ? 21 : ((intT_a <= 24) ? 19 : ((intT_a <= 30) ? 18 : 17)); }
	function off(intT_a, intS_a)
	{
		var intO = 0, intK = 0;

		for (intK = 1; intK < intT_a; intK++) { intO += spt(intK); }
		return (intO + intS_a) * 256;
	}
	function petscii(str_a, intN_a)
	{
		var buf = Buffer.alloc(intN_a, 0xA0);

		buf.write(str_a.toUpperCase().slice(0, intN_a), 0, 'latin1');
		return buf;
	}
	for (intT = 1; intT <= 35; intT++)
	{
		arrBam[intT] = [];
		for (intS = 0; intS < spt(intT); intS++)
		{
			arrBam[intT][intS] = true;		// free
			if (intT !== 18) { arrFree.push([intT, intS]); }
		}
	}
	arrBam[18][0] = false;
	arrBam[18][1] = false;
	// the directory: 8 files a sector, sectors 18/1, 18/4, 18/7 ... chained
	var arrDirSec = [1, 4, 7, 10, 13, 16, 2, 5, 8, 11, 14, 17, 3, 6, 9, 12, 15, 18];
	var intDirN = Math.max(1, Math.ceil(arrFiles_a.length / 8));
	if (intDirN > arrDirSec.length) { die('the disc takes 144 files at most'); }
	for (intI = 0; intI < intDirN; intI++)
	{
		var intDs = off(18, arrDirSec[intI]);
		arrBam[18][arrDirSec[intI]] = false;
		if (intI + 1 < intDirN) { bufD[intDs] = 18; bufD[intDs + 1] = arrDirSec[intI + 1]; }
		else { bufD[intDs] = 0; bufD[intDs + 1] = 0xFF; }
	}
	arrFiles_a.forEach(function(obj_a, intN_a)
	{
		var intBlocks = Math.max(1, Math.ceil(obj_a.data.length / 254));
		var arrSec = arrFree.splice(0, intBlocks);
		var intE = off(18, arrDirSec[Math.floor(intN_a / 8)]) + (intN_a % 8) * 32;

		if (arrSec.length < intBlocks) { die('the files do not fit on the disc (664 blocks)'); }
		arrSec.forEach(function(arr_a, intK_a)
		{
			var intO = off(arr_a[0], arr_a[1]);
			var bufPart = obj_a.data.slice(intK_a * 254, intK_a * 254 + 254);

			arrBam[arr_a[0]][arr_a[1]] = false;
			if (intK_a === intBlocks - 1) { bufD[intO] = 0; bufD[intO + 1] = bufPart.length + 1; }
			else { bufD[intO] = arrSec[intK_a + 1][0]; bufD[intO + 1] = arrSec[intK_a + 1][1]; }
			bufPart.copy(bufD, intO + 2);
		});
		bufD[intE + 2] = 0x82;		// a closed PRG
		bufD[intE + 3] = arrSec[0][0];
		bufD[intE + 4] = arrSec[0][1];
		petscii(obj_a.name, 16).copy(bufD, intE + 5);
		bufD.writeUInt16LE(intBlocks, intE + 30);
	});
	var intB = off(18, 0);
	bufD[intB] = 18; bufD[intB + 1] = 1; bufD[intB + 2] = 0x41;
	for (intT = 1; intT <= 35; intT++)
	{
		var intBits = 0, intCount = 0;

		for (intS = 0; intS < spt(intT); intS++)
		{
			if (arrBam[intT][intS]) { intBits |= (1 << intS); intCount++; }
		}
		bufD[intB + 4 * intT] = intCount;
		bufD[intB + 4 * intT + 1] = intBits & 255;
		bufD[intB + 4 * intT + 2] = (intBits >> 8) & 255;
		bufD[intB + 4 * intT + 3] = (intBits >> 16) & 255;
	}
	petscii(strDisc_a, 16).copy(bufD, intB + 0x90);
	bufD[intB + 0xA0] = 0xA0; bufD[intB + 0xA1] = 0xA0;
	bufD.write('NT', intB + 0xA2, 'latin1');
	bufD[intB + 0xA4] = 0xA0;
	bufD.write('2A', intB + 0xA5, 'latin1');
	for (intI = 0xA7; intI <= 0xAA; intI++) { bufD[intB + intI] = 0xA0; }
	return bufD;
}

var strName = path.basename(strStem).toUpperCase().replace(/[^A-Z0-9_\-]/g, '').slice(0, 14) || 'GAME';
var objB = blobs(bufBody);
var arrFilesOut = [];
var strNum = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

// where a blob is in the REU: lot 0 from 0, lot n from $8000 + (n - 1) * $18000; a thread $0100
// into its lot, a workspace 64K into it
function reuAt(obj_a)
{
	return ((obj_a.lot === 0) ? 0 : 0x8000 + (obj_a.lot - 1) * 0x18000) + ((obj_a.kind === 'thread') ? 0x0100 : 0x10000);
}
objB.parts.forEach(function(buf_a, intK_a)
{
	var obj = arrBlobInfo[intK_a];
	var intMax = (obj.kind === 'workspace') ? 0x8000 : ((obj.lot === 0) ? ((intLots > 0) ? 0x7E00 : 0xFE00) : 0xFF00);

	if (buf_a.length > intMax)
	{
		die(((obj.lot === 0) ? 'the kernel\'s thread' : 'lot ' + obj.lot + '\'s ' + obj.kind) + ' is ' + buf_a.length + ' bytes: ' + intMax + ' at most');
	}
});
if (blnSplit)
{
	// the PRG is what is before the first blob; each blob is a file. The first file's name and
	// a mark for this build go in after "NTC!NAM>"
	var intNam = bufBody.indexOf('NTC!NAM>', 0, 'latin1');
	if (intNam < 0) { die('the files\' name was not found in the program'); }
	if (objB.parts.length > strNum.length) { die('too many lots for --split'); }
	bufBody = Buffer.from(objB.head);
	bufBody[intNam + 8] = strName.length + 2;
	Buffer.from(strName + '.0', 'latin1').copy(bufBody, intNam + 9);
	require('crypto').createHash('sha1').update(Buffer.concat(objB.parts)).digest().slice(0, 8).copy(bufBody, intNam + 25);
	objB.parts.forEach(function(buf_a, intK_a)
	{
		var bufF = buf_a.length ? buf_a : Buffer.from([0]);		// (an empty one is still a file)

		arrFilesOut.push({ name: strName + '.' + strNum[intK_a], data: bufF });
		fs.writeFileSync(strStem + '.' + strNum[intK_a], bufF);
	});
}
if (0x0801 + bufBody.length > 0xD000)
{
	die('the program is ' + bufBody.length + ' bytes: a PRG must end below $D000 (51199 bytes at most)' + (blnSplit ? '' : ' - try --split'));
}
if ((intLots > 0) && (0x0801 + objB.head.length > intWsOrg))
{
	die('the part that stays in the C64 ends at $' + (0x0801 + objB.head.length).toString(16).toUpperCase() + ', over the lots\' workspace at $' + intWsOrg.toString(16).toUpperCase());
}
var bufPrg = Buffer.concat([Buffer.from([0x01, 0x08]), bufBody]);
fs.writeFileSync(strOut, bufPrg);
var intInReu = objB.parts.reduce(function(intS_a, buf_a) { return intS_a + buf_a.length; }, 0);
console.log(path.basename(strOut) + ': ' + bufPrg.length + ' bytes ($0801-$' + (0x0800 + bufBody.length).toString(16).toUpperCase() + ')' +
	(blnSplit ? ', all of it stays in the C64' : ': ' + objB.head.length + ' stay in the C64, ' + intInReu + ' go to the REU'));
objB.parts.forEach(function(buf_a, intK_a)
{
	var obj = arrBlobInfo[intK_a];
	var arrP = new RegExp((obj.lot === 0) ? '^; The threads: (\\d+) pieces' : '^; Lot ' + obj.lot + ' \\(([^)]*)\\): (\\d+) pieces', 'm').exec(strAsmText);
	var strWhat = (obj.lot === 0) ? 'the kernel\'s thread' : 'lot ' + obj.lot + (arrP ? ' (' + arrP[1].split(':')[0] + ')' : '') + ', ' + ((obj.kind === 'thread') ? 'thread' : 'workspace');

	console.log('  ' + (blnSplit ? path.basename(strStem) + '.' + strNum[intK_a] + ': ' : '') + strWhat + ': ' + buf_a.length + ' bytes' +
		((obj.kind === 'thread') ? ' (' + (buf_a.length / 64) + ' pieces)' : '') + ' -> REU $' + ('00000' + reuAt(obj).toString(16).toUpperCase()).slice(-6));
});
if (intLots > 0)
{
	console.log('  the running lot\'s workspace is at $' + intWsOrg.toString(16).toUpperCase() + '-$CFFF in the C64; the REU must be ' + (Math.pow(2, Math.ceil(Math.log2(Math.ceil((0x8000 + intLots * 0x18000) / 65536)))) * 64) + 'K or more for ' + intLots + ' lot' + ((intLots > 1) ? 's' : ''));
}
if (blnReu)
{
	if (!blnSplit) { die('--reu goes with --split'); }
	var intNote = (intLots > 0) ? 0x7F00 : 0xFF00;
	var bufReu = Buffer.alloc(Math.ceil(Math.max(0x10000, 0x8000 + intLots * 0x18000) / 65536) * 65536, 0);
	objB.parts.forEach(function(buf_a, intK_a) { buf_a.copy(bufReu, reuAt(arrBlobInfo[intK_a])); });
	bufBody.copy(bufReu, intNote + 0xC0, bufBody.indexOf('NTC!NAM>', 0, 'latin1') + 25, bufBody.indexOf('NTC!NAM>', 0, 'latin1') + 33);
	fs.writeFileSync(strStem + '.REU', bufReu);
	console.log(path.basename(strStem) + '.REU: the REU\'s first ' + (bufReu.length / 1024) + 'K, the threads in it');
}
if (blnD64)
{
	var arrDisc = [{ name: strName, data: bufPrg }].concat(arrFilesOut);
	arrAdd.forEach(function(str_a)
	{
		arrDisc.push({ name: path.basename(str_a).toUpperCase().slice(0, 16), data: fs.readFileSync(str_a) });
	});
	fs.writeFileSync(strStem + '.D64', d64(strName, arrDisc));
	console.log(path.basename(strStem) + '.D64: ' + arrDisc.map(function(obj_a) { return obj_a.name; }).join(', '));
}

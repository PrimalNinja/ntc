#!/usr/bin/env node
// x68build.js - build an X68000 boot disc (.XDF) from NTC BASIC (the x68000 platform)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node x68build.js Main.bas [More.cls ...] --out=GAME.xdf [--log] [--vasm=path/to/vasmm68k_mot]
//                    [--asm=GAME.s] [--list=GAME.lst] [-- options for cli.js]
//
// Compiles with the NTC compiler (cli.js --platform=x68000), assembles with vasm (Motorola
// syntax: vasmm68k_mot -spaces -Fbin -coalesced) and puts the result at the start of a 2HD
// floppy image: 77 tracks, 2 sides, 8 sectors of 1024 bytes (1261568 bytes). The first
// sector is the boot sector (the X68000's ROM reads it to $2000 and runs it); it loads the
// rest. No Human68k on the disc: the program is all there is.
// --log: a test build (vasm -DNTC_X68LOG=1): what the console prints is kept in RAM from
//   $0F0000, for test/x68run.py --log.
// vasm: http://sun.hasenbraten.de/vasm/ (make CPU=m68k SYNTAX=mot); NTC_VASM can give its path.
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');

var XDF_SIZE = 77 * 2 * 8 * 1024;
var arrArgs = process.argv.slice(2);
var arrFiles = [], arrExtra = [];
var strOut = '', strAsm = '', strList = '', blnLog = false;
var strVasm = process.env.NTC_VASM || 'vasmm68k_mot';
var blnRest = false;

arrArgs.forEach(function(str_a)
{
	if (blnRest) { arrExtra.push(str_a); }
	else if (str_a === '--') { blnRest = true; }
	else if (str_a.indexOf('--out=') === 0) { strOut = str_a.slice(6); }
	else if (str_a.indexOf('--asm=') === 0) { strAsm = str_a.slice(6); }
	else if (str_a.indexOf('--list=') === 0) { strList = str_a.slice(7); }
	else if (str_a.indexOf('--vasm=') === 0) { strVasm = str_a.slice(7); }
	else if (str_a === '--log') { blnLog = true; }
	else if (str_a.indexOf('--') === 0) { arrExtra.push(str_a); }
	else { arrFiles.push(str_a); }
});
if (arrFiles.length === 0)
{
	console.log('x68build.js Main.bas [More.cls ...] --out=GAME.xdf [--log]');
	process.exit(1);
}
strOut = strOut || arrFiles[0].replace(/\.[^.\/\\]*$/, '') + '.xdf';
strAsm = strAsm || strOut.replace(/\.[^.\/\\]*$/, '') + '.s';
var strBin = strOut.replace(/\.[^.\/\\]*$/, '') + '.bin';

var objR = cp.spawnSync(process.execPath, [path.join(__dirname, 'cli.js'), '--platform=x68000'].concat(arrExtra, arrFiles), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
if (objR.stderr) { process.stderr.write(objR.stderr); }
if ((objR.status !== 0) || /^ERR/m.test(objR.stderr || ''))
{
	process.exit(1);
}
fs.writeFileSync(strAsm, objR.stdout);

var arrCmd = ['-quiet', '-spaces', '-Fbin', '-coalesced', '-o', strBin];
if (blnLog) { arrCmd.push('-DNTC_X68LOG=1'); }
if (strList) { arrCmd.push('-L', strList); }
arrCmd.push(strAsm);
objR = cp.spawnSync(strVasm, arrCmd, { encoding: 'utf8' });
if (objR.error || (objR.status !== 0))
{
	process.stderr.write((objR.error ? String(objR.error) + '\n' : '') + (objR.stdout || '') + (objR.stderr || ''));
	process.exit(1);
}
var bufBin = fs.readFileSync(strBin);
if (bufBin.length > XDF_SIZE)
{
	process.stderr.write('ERR the program (' + bufBin.length + ' bytes) is bigger than the disc (' + XDF_SIZE + ')\n');
	process.exit(1);
}
if (bufBin[0] !== 0x60)
{
	process.stderr.write('ERR the boot sector does not start with a branch ($60): the X68000 would not boot it\n');
	process.exit(1);
}
var bufDisc = Buffer.alloc(XDF_SIZE, 0);
bufBin.copy(bufDisc, 0);
fs.writeFileSync(strOut, bufDisc);
console.log(strOut + ': ' + bufBin.length + ' bytes of program on a ' + XDF_SIZE + ' byte disc');

#!/usr/bin/env node
// townsbuild.js - build an FM Towns boot disc from NTC BASIC (the towns platform)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node townsbuild.js Main.bas [More.cls ...] --out=GAME.bin [--log] [--nasm=path/to/nasm]
//                      [--asm=GAME.asm] [--list=GAME.lst] [-- options for cli.js]
//
// Compiles with the NTC compiler (cli.js --platform=towns), assembles with nasm (-f bin) and
// puts the result at the start of a 2HD floppy image: 77 tracks, 2 sides, 8 sectors of 1024
// bytes (1261568 bytes, a raw image). The first sector is the boot sector ("IPL4": the FM
// Towns' ROM reads it to B000:0000 and runs it); it loads the rest and starts it in 32 bit
// protected mode. No Towns OS on the disc: the program is all there is.
// --log: a test build (nasm -DNTC_TWLOG=1): what the console prints is kept in RAM from
//   $0A0000, for test/townsrun.py.
// nasm: https://www.nasm.us/ ; NTC_NASM can give its path.
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');

var DISC_SIZE = 77 * 2 * 8 * 1024;
var arrArgs = process.argv.slice(2);
var arrFiles = [], arrExtra = [];
var strOut = '', strAsm = '', strList = '', blnLog = false;
var strNasm = process.env.NTC_NASM || 'nasm';
var blnRest = false;

arrArgs.forEach(function(str_a)
{
	if (blnRest) { arrExtra.push(str_a); }
	else if (str_a === '--') { blnRest = true; }
	else if (str_a.indexOf('--out=') === 0) { strOut = str_a.slice(6); }
	else if (str_a.indexOf('--asm=') === 0) { strAsm = str_a.slice(6); }
	else if (str_a.indexOf('--list=') === 0) { strList = str_a.slice(7); }
	else if (str_a.indexOf('--nasm=') === 0) { strNasm = str_a.slice(7); }
	else if (str_a === '--log') { blnLog = true; }
	else if (str_a.indexOf('--') === 0) { arrExtra.push(str_a); }
	else { arrFiles.push(str_a); }
});
if (arrFiles.length === 0)
{
	console.log('townsbuild.js Main.bas [More.cls ...] --out=GAME.bin [--log]');
	process.exit(1);
}
strOut = strOut || arrFiles[0].replace(/\.[^.\/\\]*$/, '') + '.bin';
strAsm = strAsm || strOut.replace(/\.[^.\/\\]*$/, '') + '.asm';
var strPrg = strOut.replace(/\.[^.\/\\]*$/, '') + '.prg';

var objR = cp.spawnSync(process.execPath, [path.join(__dirname, 'cli.js'), '--platform=towns'].concat(arrExtra, arrFiles), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
if (objR.stderr) { process.stderr.write(objR.stderr); }
if ((objR.status !== 0) || /^ERR/m.test(objR.stderr || ''))
{
	process.exit(1);
}
fs.writeFileSync(strAsm, objR.stdout);

var arrCmd = ['-f', 'bin', '-o', strPrg];
if (blnLog) { arrCmd.push('-DNTC_TWLOG=1'); }
if (strList) { arrCmd.push('-l', strList); }
arrCmd.push(strAsm);
objR = cp.spawnSync(strNasm, arrCmd, { encoding: 'utf8' });
if (objR.error || (objR.status !== 0))
{
	process.stderr.write((objR.error ? String(objR.error) + '\n' : '') + (objR.stdout || '') + (objR.stderr || ''));
	process.exit(1);
}
var bufPrg = fs.readFileSync(strPrg);
if (bufPrg.length > DISC_SIZE)
{
	process.stderr.write('ERR the program (' + bufPrg.length + ' bytes) is bigger than the disc (' + DISC_SIZE + ')\n');
	process.exit(1);
}
if (bufPrg.slice(0, 4).toString('latin1') !== 'IPL4')
{
	process.stderr.write('ERR the boot sector does not start with IPL4: the FM Towns would not boot it\n');
	process.exit(1);
}
var bufDisc = Buffer.alloc(DISC_SIZE, 0);
bufPrg.copy(bufDisc, 0);
fs.writeFileSync(strOut, bufDisc);
console.log(strOut + ': ' + bufPrg.length + ' bytes of program on a ' + DISC_SIZE + ' byte disc');

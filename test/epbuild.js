// epbuild.js - an NTC BASIC program to an Enterprise 128 program file, and a disc with it
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node epbuild.js Main.bas [More.cls ...] --out=GAME.COM [--img] [--log] [--ram=K]
//
// Compiles for the ep128 platform (cli.js) and assembles with sjasmplus. The file's first 16
// bytes are EXOS's header - 0, 5 (a program loaded at #0100 and started there), the program's
// length, 12 zeros - assembled with the program, so what sjasmplus writes is the file as the
// machine loads it: LOAD "GAME.COM" from IS-BASIC, or :LOAD GAME.COM from EXDOS. At most
// 48,896 bytes of program (#0100-#BFFF: EXOS loads no more).
// --img: also GAME.IMG, a 720K EXDOS disc (the PC's format: 80 tracks, 2 sides, 9 sectors)
//   holding GAME.COM and an EXDOS.INI with the one line LOAD GAME.COM - EXDOS runs that file
//   when the machine starts, so the disc starts the program by itself (a key at the title
//   screen first). For a real drive, an SD card adapter that takes disc images, or an emulator.
// --log: a test build (sjasmplus -DNTC_EPLOG=1): what the console prints is also kept in a
//   segment of its own, for test/eprun.py --log.
// --ram=K: also writes GAME.ep128cfg, for the ep128emu libretro core (the machine's RAM in K:
//   64, 128, 256 ... 3712). Nothing to do with a real machine.
// Options this does not know (--turbo ...) go on to cli.js.
// sjasmplus: on the PATH, or SJASMPLUS / NTC_SJASM give its path.
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');

var arrArgs = process.argv.slice(2);
var arrFiles = [], arrExtra = [];
var strOut = '', strAsm = '', blnLog = false, blnImg = false, intRam = 0;
var strSjasm = process.env.SJASMPLUS || process.env.NTC_SJASM || 'sjasmplus';

function die(str_a)
{
	process.stderr.write('ERR ' + str_a + '\n');
	process.exit(1);
}

// a 720K FAT12 disc image with these files ({ name: 'GAME.COM', data: Buffer }) in its root
function discImage(arrFiles_a)
{
	var SEC = 512, SPC = 2, FATS = 2, FATSEC = 3, ROOT = 112, TOTAL = 1440;
	var bufImg = Buffer.alloc(TOTAL * SEC, 0);
	var intRootAt = 1 + FATS * FATSEC;
	var intDataAt = intRootAt + ROOT * 32 / SEC;
	var arrFat = [0xFF9, 0xFFF];
	var intNext = 2;

	bufImg[0] = 0xEB; bufImg[1] = 0x3C; bufImg[2] = 0x90;		// (the jump a PC's boot sector starts with: how a disc is known)
	bufImg.write('NTCBASIC', 3, 'latin1');
	bufImg.writeUInt16LE(SEC, 11);
	bufImg[13] = SPC;
	bufImg.writeUInt16LE(1, 14);
	bufImg[16] = FATS;
	bufImg.writeUInt16LE(ROOT, 17);
	bufImg.writeUInt16LE(TOTAL, 19);
	bufImg[21] = 0xF9;
	bufImg.writeUInt16LE(FATSEC, 22);
	bufImg.writeUInt16LE(9, 24);
	bufImg.writeUInt16LE(2, 26);
	bufImg[510] = 0x55; bufImg[511] = 0xAA;
	arrFiles_a.forEach(function(obj_a, intEntry_a)
	{
		var intClusters = Math.max(1, Math.ceil(obj_a.data.length / (SEC * SPC)));
		var arrName = obj_a.name.toUpperCase().split('.');
		var intAt = intRootAt * SEC + intEntry_a * 32;
		var intI = 0;

		if ((intNext - 2 + intClusters) * SPC > TOTAL - intDataAt) { die('the files do not fit on the disc'); }
		bufImg.write((arrName[0] + '        ').slice(0, 8) + ((arrName[1] || '') + '   ').slice(0, 3), intAt, 'latin1');
		bufImg[intAt + 11] = 0x20;
		bufImg.writeUInt16LE(0x6000, intAt + 22);		// 12:00
		bufImg.writeUInt16LE(0x5D79, intAt + 24);		// 25 November 2026 (a date: any will do)
		bufImg.writeUInt16LE(intNext, intAt + 26);
		bufImg.writeUInt32LE(obj_a.data.length, intAt + 28);
		obj_a.data.copy(bufImg, (intDataAt + (intNext - 2) * SPC) * SEC);
		for (intI = 0; intI < intClusters; intI++)
		{
			arrFat[intNext] = (intI === intClusters - 1) ? 0xFFF : intNext + 1;
			intNext++;
		}
	});
	arrFat.forEach(function(int_a, intN_a)
	{
		var intAt = Math.floor(intN_a * 3 / 2);
		var intF = 0, intB = 0;

		for (intF = 0; intF < FATS; intF++)
		{
			intB = (1 + intF * FATSEC) * SEC + intAt;
			if (intN_a & 1)
			{
				bufImg[intB] = (bufImg[intB] & 0x0F) | ((int_a << 4) & 0xF0);
				bufImg[intB + 1] = int_a >> 4;
			}
			else
			{
				bufImg[intB] = int_a & 0xFF;
				bufImg[intB + 1] = (bufImg[intB + 1] & 0xF0) | (int_a >> 8);
			}
		}
	});
	return bufImg;
}

arrArgs.forEach(function(str_a)
{
	if (str_a.indexOf('--out=') === 0) { strOut = str_a.slice(6); }
	else if (str_a.indexOf('--asm=') === 0) { strAsm = str_a.slice(6); }
	else if (str_a.indexOf('--sjasmplus=') === 0) { strSjasm = str_a.slice(12); }
	else if (str_a.indexOf('--ram=') === 0) { intRam = parseInt(str_a.slice(6), 10); }
	else if (str_a === '--log') { blnLog = true; }
	else if (str_a === '--img') { blnImg = true; }
	else if (str_a.indexOf('--') === 0) { arrExtra.push(str_a); }
	else { arrFiles.push(str_a); }
});
if (arrFiles.length === 0)
{
	console.log('epbuild.js Main.bas [More.cls ...] --out=GAME.COM [--img] [--log] [--ram=K]');
	process.exit(1);
}
strOut = strOut || arrFiles[0].replace(/\.[^.\/\\]*$/, '') + '.com';
var strStem = strOut.replace(/\.[^.\/\\]*$/, '');
strAsm = strAsm || strStem + '.asm';
var strSym = strStem + '.sym';

var objR = cp.spawnSync(process.execPath, [path.join(__dirname, 'cli.js'), '--platform=ep128'].concat(arrExtra, arrFiles), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
if (objR.stderr) { process.stderr.write(objR.stderr); }
if ((objR.status !== 0) || /^ERR/m.test(objR.stderr || ''))
{
	process.exit(1);
}
fs.writeFileSync(strAsm, objR.stdout);

// sjasmplus runs in the .asm's folder (files it writes itself land there)
var arrCmd = ['--nologo', '--msg=err', '--raw=' + path.basename(strOut), '--sym=' + path.basename(strSym)];
if (blnLog) { arrCmd.push('-DNTC_EPLOG=1'); }
arrCmd.push(path.basename(strAsm));
objR = cp.spawnSync(strSjasm, arrCmd, { encoding: 'utf8', cwd: path.dirname(path.resolve(strAsm)) });
if (objR.error || (objR.status !== 0) || /error:/.test((objR.stdout || '') + (objR.stderr || '')))
{
	process.stderr.write((objR.error ? String(objR.error) + '\n' : '') + (objR.stdout || '') + (objR.stderr || ''));
	process.exit(1);
}
var bufCom = fs.readFileSync(strOut);
var intLen = bufCom.length - 16;
if ((bufCom[0] !== 0) || (bufCom[1] !== 5) || (bufCom[2] + bufCom[3] * 256 !== intLen))
{
	die('the file is not EXOS\'s header and then the whole program, in one piece from #0100 (' + bufCom.length + ' bytes; the header says ' + (bufCom[2] + bufCom[3] * 256) + ' of program)');
}
if (intLen > 0xC000 - 0x100) { die('the program is ' + intLen + ' bytes: EXOS loads at most 48896 (#0100-#BFFF)'); }
if (intRam > 0)
{
	fs.writeFileSync(strStem + '.ep128cfg', 'memory.ram.size ' + intRam + '\n');
}
console.log(path.basename(strOut) + ': ' + intLen + ' bytes of program (#0100-#' + (0xFF + intLen).toString(16).toUpperCase() + '), ' + bufCom.length + ' in the file');
if (blnImg)
{
	var strName = path.basename(strStem).toUpperCase().replace(/[^A-Z0-9_]/g, '').slice(0, 8) || 'GAME';
	fs.writeFileSync(strStem + '.img', discImage([
		{ name: 'EXDOS.INI', data: Buffer.from('LOAD ' + strName + '.COM\r\n', 'latin1') },
		{ name: strName + '.COM', data: bufCom }
	]));
	console.log(path.basename(strStem) + '.img: a 720K EXDOS disc - ' + strName + '.COM, and EXDOS.INI to start it');
}

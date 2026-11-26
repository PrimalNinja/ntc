// build.js - the NTC PI DEMOS built: each program compiled with NTC BASIC (NTC's test/cli.js),
// assembled with sjasmplus, its AMSDOS binary put in bin/, and all of them on dsk/PIDEMOS.DSK
// (a 178K data format disc) with MENU.BAS.
//
//   node tools/build.js [--only=PI01LINK,PI02STOR]
//
//   NTC         the NTC folder (the one with src/ and test/)     default ../NTC beside this folder
//   SJASMPLUS   the assembler      default: NTC's sjasmplus/sjasmplus(.exe), else sjasmplus on the PATH
// (c) 2026 Cyborg Unicorn Pty Ltd
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process'), os = require('os');

var ROOT = path.resolve(__dirname, '..');
var NTC = path.resolve(process.env.NTC || path.join(ROOT, '..', 'NTC'));
var SRC = path.join(ROOT, 'src'), BIN = path.join(ROOT, 'bin'), DSK = path.join(ROOT, 'dsk');

// the programs: name, what it tests, its classes (Link.cls always)
var PROGRAMS = [
	['PI01LINK', 'the card and the Pi: status, HELLO, PING, TIME, INFO, LIST', []],
	['PI02STOR', 'the store: a tagged piece put, got back, compared; SIZE, APPEND, LIST, DEL', []],
	['PI03BIG', 'data in parts: 6000 and 20000 bytes; the CPLink2\'s Pi ROM', []],
	['PI04MATH', 'the maths coprocessor: EVAL, BIG, XFORM', []],
	['PI05FLT', 'the float coprocessor: OP, ARR', []],
	['PI06RUN', 'a command run on the Pi, its output back', []],
	['PI07TERM', 'a shell on the Pi, the CPC its terminal', []],
	['PI08VDU', 'the Pi\'s HDMI as a virtual display (mode=hd)', []],
	['PI09AUD', 'music played by the Pi: a tone made here, PLAY, STATUS, ENDED', []],
	['PI10VOX', 'speech: the Votrax SC-01 on the Pi', []],
	['PI11DISK', 'Pi volumes: random access records, FIND, REN, ERA', []],
	['PI12MIND', 'the generative model on the Pi', []],
	['PI13MANY', 'several channels at once', []],
	['PI14VDP', 'sprites on the Pi\'s HDMI (hwlib\'s Pi class)', ['Pi.cls', 'Art.cls']],
	['PI15TILE', 'the vdp\'s tile layer, tiles from the store', ['Pi.cls', 'Art.cls']]
];

function sjasm()
{
	var arr = [process.env.SJASMPLUS, path.join(NTC, 'sjasmplus', 'sjasmplus'), path.join(NTC, 'sjasmplus', 'sjasmplus.exe')], i;

	for (i = 0; i < arr.length; i++) { if (arr[i] && fs.existsSync(arr[i])) { return arr[i]; } }
	return 'sjasmplus';
}

// a CPC .DSK: 40 tracks of 9 sectors of 512 bytes (data format, sectors #C1-#C9, interleaved),
// CP/M's directory in the first 2K, 1K blocks. arrFiles_a: [{ name: 'NAME.EXT', data: Buffer }]
function dskMake(arrFiles_a)
{
	var img = Buffer.alloc(40 * 9 * 512, 0xE5), dir = Buffer.alloc(2048, 0xE5), intBlock = 2, intEntry = 0;

	arrFiles_a.forEach(function(objFile_a)
	{
		var arrN = objFile_a.name.split('.'), strName = (arrN[0] + '        ').slice(0, 8) + ((arrN[1] || '') + '   ').slice(0, 3);
		var data = Buffer.concat([objFile_a.data, Buffer.alloc((128 - (objFile_a.data.length % 128)) % 128, 0x1A)]);
		var intRecs = data.length / 128, intExtents = Math.max(1, Math.ceil(intRecs / 128)), intEx, j;

		for (intEx = 0; intEx < intExtents; intEx++)
		{
			var part = data.slice(intEx * 16384, (intEx + 1) * 16384), ent = Buffer.alloc(32, 0);
			ent[0] = 0; ent.write(strName, 1, 11, 'latin1'); ent[12] = intEx & 31; ent[14] = intEx >> 5; ent[15] = Math.min(128, part.length / 128);
			for (j = 0; j < Math.ceil(part.length / 1024); j++)
			{
				if (intBlock >= 180) { throw new Error('the disc is full at ' + objFile_a.name); }
				ent[16 + j] = intBlock;
				part.slice(j * 1024, (j + 1) * 1024).copy(img, intBlock * 1024);
				intBlock++;
			}
			if (intEntry >= 64) { throw new Error('the directory is full at ' + objFile_a.name); }
			ent.copy(dir, intEntry * 32); intEntry++;
		}
	});
	dir.copy(img, 0);
	var head = Buffer.alloc(256, 0), arrOut = [head], arrOrder = [0, 5, 1, 6, 2, 7, 3, 8, 4], t, i;
	head.write('MV - CPCEMU Disk-File\r\nDisk-Info\r\n', 0, 'latin1');
	head[0x30] = 40; head[0x31] = 1; head.writeUInt16LE(0x100 + 9 * 512, 0x32);
	for (t = 0; t < 40; t++)
	{
		var ti = Buffer.alloc(256, 0);
		ti.write('Track-Info\r\n', 0, 'latin1'); ti[0x10] = t; ti[0x14] = 2; ti[0x15] = 9; ti[0x16] = 0x52; ti[0x17] = 0xE5;
		for (i = 0; i < 9; i++) { Buffer.from([t, 0, 0xC1 + arrOrder[i], 2, 0, 0, 0, 0]).copy(ti, 0x18 + i * 8); }
		arrOut.push(ti);
		for (i = 0; i < 9; i++) { arrOut.push(img.slice((t * 9 + arrOrder[i]) * 512, (t * 9 + arrOrder[i]) * 512 + 512)); }
	}
	return { dsk: Buffer.concat(arrOut), blocks: intBlock - 2, entries: intEntry };
}

function menu()
{
	var arr = ['10 MODE 2:PRINT "NTC PI DEMOS - CPC-CPLink / CPLink2 with CyborgOS for the Pi":PRINT'], i;

	for (i = 0; i < PROGRAMS.length; i++) { arr.push((20 + i * 10) + ' PRINT ' + (i + 1) + ';"  ' + PROGRAMS[i][0] + '  ' + PROGRAMS[i][1].replace(/"/g, '\'').slice(0, 60) + '"'); }
	arr.push('300 PRINT:INPUT "Which (1-' + PROGRAMS.length + ')";n:IF n<1 OR n>' + PROGRAMS.length + ' THEN 300');
	arr.push('310 RESTORE:FOR i=1 TO n:READ a$:NEXT:PRINT "RUN ";a$:RUN a$');
	arr.push('320 DATA ' + PROGRAMS.map(function(p) { return p[0]; }).join(','));
	return Buffer.from(arr.join('\r\n') + '\r\n\x1A', 'latin1');
}

function main()
{
	var strOnly = (process.argv.slice(2).filter(function(a) { return a.indexOf('--only=') === 0; })[0] || '').slice(7);
	var arrOnly = strOnly ? strOnly.toUpperCase().split(',') : null;
	var strWork = fs.mkdtempSync(path.join(os.tmpdir(), 'pidemos-')), strSj = sjasm(), arrFiles = [], intBad = 0;

	[BIN, DSK].forEach(function(d) { fs.mkdirSync(d, { recursive: true }); });
	PROGRAMS.forEach(function(p)
	{
		if (arrOnly && arrOnly.indexOf(p[0]) < 0) { return; }
		var arrSrc = [path.join(SRC, p[0] + '.bas'), path.join(SRC, 'Link.cls')].concat(p[2].map(function(c) { return path.join(SRC, c); }));
		var r = cp.spawnSync('node', [path.join(NTC, 'test', 'cli.js')].concat(arrSrc, ['--platform=cpcfw', '--amsdos=' + p[0]]), { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
		if (/^ERR /m.test(r.stderr) || r.status !== 0) { console.log('FAIL ' + p[0] + ': does not compile\n' + r.stderr); intBad++; return; }
		if (r.stderr.trim()) { console.log(p[0] + ': ' + r.stderr.trim()); }
		fs.writeFileSync(path.join(strWork, p[0] + '.asm'), r.stdout);
		var a = cp.spawnSync(strSj, ['--nologo', '--msg=err', p[0] + '.asm'], { cwd: strWork, encoding: 'utf8' });
		var strBin = path.join(strWork, p[0] + '.BIN');
		if (a.status !== 0 || !fs.existsSync(strBin)) { console.log('FAIL ' + p[0] + ': does not assemble\n' + (a.stdout || '') + (a.stderr || '') + (a.error ? a.error.message : '')); intBad++; return; }
		var buf = fs.readFileSync(strBin);
		fs.writeFileSync(path.join(BIN, p[0] + '.BIN'), buf);
		arrFiles.push({ name: p[0] + '.BIN', data: buf });
		console.log('ok   ' + p[0] + '.BIN  ' + buf.length + ' bytes (loads at #' + buf.readUInt16LE(21).toString(16).toUpperCase() + ', ' + buf.readUInt16LE(24) + ' long)  ' + p[1]);
	});
	if (!arrOnly && !intBad)
	{
		var bufMenu = menu(), o;
		fs.writeFileSync(path.join(BIN, 'MENU.BAS'), bufMenu);
		o = dskMake([{ name: 'MENU.BAS', data: bufMenu }].concat(arrFiles));
		fs.writeFileSync(path.join(DSK, 'PIDEMOS.DSK'), o.dsk);
		console.log('ok   dsk/PIDEMOS.DSK  ' + (arrFiles.length + 1) + ' files, ' + o.blocks + 'K used of 178K, ' + o.entries + ' directory entries of 64');
	}
	fs.rmSync(strWork, { recursive: true, force: true });
	process.exit(intBad ? 1 : 0);
}
main();

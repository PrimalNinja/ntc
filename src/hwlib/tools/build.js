// build.js - builds every test (or the ones named): NTC BASIC -> assembler -> the target's file
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node tools/build.js [target ...]          (NTC_SRC = NTC's src folder, else the src this is in: src/hwlib)
//
// Each target: its platform, the files (the chip classes from lib/, the test's own from tests/<target>/)
// and what to make of the binary:
//   nex      the zxn platform's NEX (SAVENEX in the assembler)
//   bin      the cpc platform: a binary at #0040 with an AMSDOS header, RUN"NAME
//   msxrom   an MSX cartridge (16K / 32K at #4000): a stub copies the program into RAM at its
//            org (#C000) and runs it - NTC keeps variables beside the code, so it runs from RAM
//   sc3000   an SC-3000 / SG-1000 cartridge (#0000) for a RAM cartridge (BASIC Level III's 32K at
//            #8000): the stub copies the program to its org (#8000) and runs it
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');
var ROOT = path.join(__dirname, '..');
var NTC = process.env.NTC_SRC || path.join(ROOT, '..');		// NTC's src (hwlib is src/hwlib)
var SJ = process.env.SJASMPLUS || 'sjasmplus';

var T = {
	'next':      { platform: 'zxn',       lib: ['Zxn.cls'],                         out: 'nex' },
	'cpc':       { platform: 'cpc',       lib: ['Cpc.cls'],                         out: 'bin' },
	'cpcplus':   { platform: 'cpc',       lib: ['Asic.cls'],                        out: 'bin' },
	'cpc_v9990': { platform: 'cpc',       lib: ['V9990.cls', 'StdIO_V9990.cls'],    out: 'bin', consts: ['CPC'] },
	'msx1':      { platform: 'baremetal', lib: ['Tms9918.cls', 'StdIO_Tms9918.cls'], out: 'msxrom', consts: ['MSX'] },
	'msx2':      { platform: 'baremetal', lib: ['V9938.cls', 'StdIO_V9938.cls'],     out: 'msxrom', consts: ['MSX'] },
	'msx_v9990': { platform: 'baremetal', lib: ['V9990.cls', 'StdIO_V9990.cls'],    out: 'msxrom', consts: ['MSX'] },
	'sc3000':    { platform: 'baremetal', lib: ['Tms9918.cls', 'StdIO_Tms9918.cls'], out: 'sc3000', consts: ['SC3000'] },
	// the cube (vector) tests
	'cube_next':      { platform: 'zxn',       lib: ['Zxn.cls', 'StdIO_Zxn.cls', 'Vec.cls'],         out: 'nex' },
	'cube_cpc':       { platform: 'cpc',       lib: ['Cpc.cls', 'Vec.cls'],                          out: 'bin' },
	'cube_cpcplus':   { platform: 'cpc',       lib: ['Cpc.cls', 'Asic.cls', 'Vec.cls'],              out: 'bin' },
	'cube_cpc_v9990': { platform: 'cpc',       lib: ['V9990.cls', 'StdIO_V9990.cls', 'Vec.cls'],     out: 'bin', consts: ['CPC'] },
	'cube_msx1':      { platform: 'baremetal', lib: ['Tms9918.cls', 'StdIO_Tms9918.cls', 'Vec.cls'], out: 'msxrom', consts: ['MSX'] },
	'cube_msx2':      { platform: 'baremetal', lib: ['V9938.cls', 'StdIO_V9938.cls', 'Vec.cls'],     out: 'msxrom', consts: ['MSX'] },
	'cube_msx_v9990': { platform: 'baremetal', lib: ['V9990.cls', 'StdIO_V9990.cls', 'Vec.cls'],     out: 'msxrom', consts: ['MSX'] },
	'cube_sc3000':    { platform: 'baremetal', lib: ['Tms9918.cls', 'StdIO_Tms9918.cls', 'Vec.cls'], out: 'sc3000', consts: ['SC3000'] }
};

function run(cmd, args, opt)
{
	var r = cp.spawnSync(cmd, args, Object.assign({ encoding: 'utf8' }, opt || {}));
	// (NTC's compiler can print an ERR line and still end 0: that's a failed build too - Asic.cls's
	// 17 value Choose was built into a program that sent 0s, 2026-10-28)
	if (r.status !== 0 || /(^|\n)ERR /.test(r.stderr || '')) { throw new Error(cmd + ' ' + args.join(' ') + '\n' + r.stdout + r.stderr); }
	return r.stdout;
}

function build(name)
{
	var t = T[name], dir = path.join(ROOT, 'tests', name), out = path.join(ROOT, 'build', name);
	fs.mkdirSync(out, { recursive: true });
	// the files: the chip classes (StdIO_<chip>.cls is the project's StdIO), then the test's own
	var files = [];
	t.lib.forEach(function(f)
	{
		var dst = path.join(out, /^StdIO_/.test(f) ? 'StdIO.cls' : f);
		fs.copyFileSync(path.join(ROOT, 'lib', f), dst);
		files.push(dst);
	});
	fs.readdirSync(dir).filter(function(f) { return /\.(bas|cls)$/.test(f); }).sort(function(a, b) { return (a === 'Main.bas') ? -1 : (b === 'Main.bas') ? 1 : a.localeCompare(b); }).forEach(function(f)
	{
		var dst = path.join(out, f);
		fs.copyFileSync(path.join(dir, f), dst);
		files.push(dst);
	});
	var name8 = name.toUpperCase().replace(/[^A-Z0-9]/g, '').substr(0, 8);
	var asm = run(process.execPath, [path.join(NTC, 'test', 'cli.js')].concat(files.map(function(f) { return path.basename(f); }), ['--platform=' + t.platform], (t.consts || []).map(function(c) { return '--const=' + c; }), (t.out === 'bin') ? ['--amsdos=' + name8] : []), { cwd: out });
	fs.writeFileSync(path.join(out, name8 + '.asm'), asm);
	if (t.out === 'nex')
	{
		run(SJ, ['--nologo', '--sym=' + name8 + '.sym', name8 + '.asm'], { cwd: out });
		fs.renameSync(path.join(out, 'NTC.NEX'), path.join(out, name8 + '.NEX'));
		console.log(name + ': build/' + name + '/' + name8 + '.NEX');
		return;
	}
	if (t.out === 'bin')
	{
		// the CPC: a binary with an AMSDOS header (NTC's --amsdos: SAVEAMSDOS), for RUN"NAME
		run(SJ, ['--nologo', '--sym=' + name8 + '.sym', name8 + '.asm'], { cwd: out });
		console.log(name + ': build/' + name + '/' + name8 + '.BIN (' + (fs.statSync(path.join(out, name8 + '.BIN')).size - 128) + ' bytes at #40, an AMSDOS header: RUN"' + name8 + ')');
		return;
	}
	run(SJ, ['--nologo', '--sym=' + name8 + '.sym', '--raw=' + name8 + '.BIN', name8 + '.asm'], { cwd: out });
	var bin = fs.readFileSync(path.join(out, name8 + '.BIN'));
	var org = parseInt((/^\s*org\s+#([0-9A-Fa-f]+)/m.exec(asm) || [0, '0'])[1], 16);
	// a cartridge: the stub, then the program to copy to its org
	var stub = (t.out === 'msxrom') ? [
		'; MSX cartridge: "AB", the start; copies the program to RAM at its org and runs it',
		'            org #4000',
		'            db "AB"',
		'            dw start, 0, 0, 0, 0, 0, 0',
		'start:      di',
		'            ld hl, prog',
		'            ld de, #' + org.toString(16),
		'            ld bc, prog_end - prog',
		'            ldir',
		'            jp #' + org.toString(16),
		'prog:       incbin "' + name8 + '.BIN"',
		'prog_end:',
		'            ds (($ + #3FFF) & #C000) - $, #FF        ; to a whole 16K'
	] : [
		'; SC-3000 / SG-1000 cartridge at #0000 (a RAM cartridge at #8000 for the program)',
		'            org #0000',
		'            di',
		'            im 1',
		'            ld sp, #C7F0          ; the machine\'s own 2K at #C000 for the start',
		'            ld hl, prog',
		'            ld de, #' + org.toString(16),
		'            ld bc, prog_end - prog',
		'            ldir',
		'            jp #' + org.toString(16),
		'            ds #38 - $, 0',
		'            ei                    ; (IM 1: an interrupt that gets in just returns)',
		'            reti',
		'            ds #66 - $, 0',
		'            retn                  ; (the pause button\'s NMI)',
		'prog:       incbin "' + name8 + '.BIN"',
		'prog_end:',
		'            ds (($ + #1FFF) & #E000) - $, #FF        ; to a whole 8K'
	];
	if (org + bin.length > ((t.out === 'msxrom') ? 0xFF80 : 0xFF00)) { throw new Error(name + ': the program (' + bin.length + ' bytes) is too big for RAM at #' + org.toString(16)); }
	fs.writeFileSync(path.join(out, 'cart.asm'), stub.join('\n') + '\n');
	var ext = (t.out === 'msxrom') ? '.ROM' : '.SC';
	run(SJ, ['--nologo', '--raw=' + name8 + ext, 'cart.asm'], { cwd: out });
	console.log(name + ': build/' + name + '/' + name8 + ext + ' (program ' + bin.length + ' bytes, copied to #' + org.toString(16).toUpperCase() + ')');
}

var names = process.argv.slice(2);
if (names.length === 0) { names = Object.keys(T); }
names.forEach(function(n)
{
	try { build(n); }
	catch (e) { console.log(n + ': FAILED\n' + e.message); process.exitCode = 1; }
});

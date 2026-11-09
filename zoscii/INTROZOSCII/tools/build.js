// build.js - builds INTRODUCTION TO ZOSCII for the ZX Spectrum Next: NTC BASIC -> assembly -> NEX
// (c) 2026 Cyborg Unicorn Pty Ltd
//
//   node tools/build.js [turbo|normal|both] [path to NTC's src folder]
//
// Needs NTC (the folder with js/ntc_compiler.js: NTC/src) and sjasmplus on the PATH (or SJASMPLUS=...).
// NTC's src is looked for in the argument, then NTC_SRC, then ../../NTC/src, then ../NTC/src.
// Run tools/assets.js first: it writes assets/INTRO.DAT and the data classes in src/.
// The program is the files listed in FILES, in that order (Main.bas first).
// ES5.
'use strict';
var fs = require('fs');
var path = require('path');
var cp = require('child_process');

var ROOT = path.join(__dirname, '..');
var FILES = ['Main.bas', 'Vid.cls', 'Snd.cls', 'Rng.cls', 'Rom.cls', 'Blk.cls', 'AtkW.cls', 'Attack.cls', 'Play.cls', 'Screens.cls', 'Intro.cls', 'Proto.cls', 'Demo.cls', 'Esx.cls', 'Splash.cls', 'Data.cls'];
var NAME = 'INTRO';

function findNtc()
{
	var tries = [process.argv[3], process.env.NTC_SRC, path.join(ROOT, '..', 'NTC', 'src'), path.join(ROOT, '..', '..', 'NTC', 'src'), path.join(ROOT, '..', 'ntc', 'NTC', 'src')];
	for (var i = 0; i < tries.length; i++)
	{
		if (tries[i] && fs.existsSync(path.join(tries[i], 'js', 'ntc_compiler.js'))) { return path.resolve(tries[i]); }
	}
	return null;
}

var ntc = findNtc();
if (!ntc) { console.log('NTC\'s src folder not found: node tools/build.js both path/to/NTC/src'); process.exit(1); }
global.window = global;
function load(f, fix)
{
	var t = fs.readFileSync(path.join(ntc, 'js', f), 'utf8');
	(0, eval)(fix ? fix(t) : t);
}
load('ntc_lib.js', function(t) { return t.replace(/^var /gm, 'global.'); });
load('ntc_parser.js', function(t) { return t.replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'); });
load('ntc_compiler.js', function(t) { return t.replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'); });
load('ntc_flavour_js.js');
load('ntc_flavour_loco.js');

function buildOne(turbo, name)
{
	var files = FILES.filter(function(f) { return fs.existsSync(path.join(ROOT, 'src', f)); }).map(function(f)
	{
		return { name: f, text: fs.readFileSync(path.join(ROOT, 'src', f), 'utf8') };
	});
	var LANG = (process.env.ZLANG || 'en').toLowerCase();
	var bdir = LANG === 'en' ? path.join(ROOT, 'build') : path.join(ROOT, 'build', LANG.toUpperCase());
	if (!fs.existsSync(bdir)) { fs.mkdirSync(bdir, { recursive: true }); }
	var r = global.ntcCompile(files, { platform: 'zxn', name: name, turbo: turbo });
	(r.warnings || []).forEach(function(e) { console.log('warning ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); });
	if (r.errors.length)
	{
		r.errors.forEach(function(e) { console.log('error ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); });
		process.exit(1);
	}
	fs.writeFileSync(path.join(bdir, name + '.asm'), r.asm);
	var dat = path.join(ROOT, 'assets', 'INTRO.DAT');
	if (fs.existsSync(dat)) { fs.copyFileSync(dat, path.join(bdir, 'INTRO.DAT')); }
	var sj = process.env.SJASMPLUS || 'sjasmplus';
	var a = cp.spawnSync(sj, ['--nologo', '--sym=' + name + '.sym', name + '.asm'], { cwd: bdir, encoding: 'utf8' });
	if (a.error) { console.log('sjasmplus not found: assemble build/' + name + '.asm with it'); process.exit(1); }
	process.stdout.write(a.stdout || '');
	process.stdout.write(a.stderr || '');
	if (a.status) { console.log('the assembly failed: no NEX file'); process.exit(a.status); }
	var sym = fs.readFileSync(path.join(bdir, name + '.sym'), 'utf8');
	var m = /ntc_free:\s+EQU\s+0x([0-9A-Fa-f]+)/.exec(sym);
	if (m) { console.log(name + ': program ends at #' + m[1].slice(-4) + (turbo ? ' (turbo)' : ' (normal)')); }
}

var which = process.argv[2] || 'turbo';
if (which === 'turbo' || which === 'both') { buildOne(true, NAME); }
if (which === 'normal' || which === 'both') { buildOne(false, NAME + 'N'); }

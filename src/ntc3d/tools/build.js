// build.js - builds an NTC3D game: the IDE project, the assembler and the NEX file
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node tools/build.js <game folder> [path to NTC's src folder]
//
// The game folder's game.json: { "name": "NAME", "files": [ its own .bas / .cls ], "framework":
// "path to NTC3D's folder" } - with framework given, NTC3D's classes (E3, Nx, Obj3D, Fly3D, Hud3D)
// are built in from there (else the game has its own copies in its files list).
// 1. NAME.json: the project for NTC BASIC's IDE (ntc.html: Open... it), the zxn platform, turbo
// 2. build/NAME.asm: the compiler's output (NTC's own js/ files, loaded as its test/cli.js does)
// 3. build/NAME.NEX (+ NAME.sym for the tests): sjasmplus build/NAME.asm, when sjasmplus is on the
//    PATH (or SJASMPLUS=...); how much room is left under #BE00 is printed
// E3Data.cls and build/NAME.DAT come from the model tool (tools/e3models.js): run it first.
// game.json may also give "extras": ["Galaxy3D.cls", "Radar3D.cls"] (the framework's optional classes), "nobj" (how many objects: 32 when not given) and "features" (the
// framework's optional Z80: "ground" for the ground movers and OF_LAND): tools/prep.js applies them.
// NTC's src folder is looked for in the argument, then NTC_SRC, then the one this ntc3d/ is in. ES5.
'use strict';
var fs = require('fs');
var path = require('path');
var cp = require('child_process');

var FRAMEWORK = ['E3.cls', 'Nx.cls', 'Obj3D.cls', 'Fly3D.cls', 'Hud3D.cls'];
var here = path.resolve(process.argv[2] || '.');
var cfg = JSON.parse(fs.readFileSync(path.join(here, 'game.json'), 'utf8'));
var name = cfg.name;
var list = cfg.files.map(function(f) { return path.resolve(here, f); });
if (cfg.framework) FRAMEWORK.forEach(function(f) { list.push(path.resolve(here, cfg.framework, f)); });
if (cfg.framework) (cfg.extras || []).forEach(function(f) { list.push(path.resolve(here, cfg.framework, f)); });   // (the optional classes: Galaxy3D.cls, Radar3D.cls)

function findNtc()
{
	var tries = [process.argv[3], process.env.NTC_SRC, path.join(__dirname, '..', '..')];		// (NTC's src: ntc3d/ is in it)
	for (var i = 0; i < tries.length; i++)
	{
		if (tries[i] && fs.existsSync(path.join(tries[i], 'js', 'ntc_compiler.js'))) return path.resolve(tries[i]);
	}
	return null;
}

// 1. the IDE project
var prep = require('./prep.js').prep;
list.forEach(function(f)                                                        // <--- NEW: E3Data's MaxV, MaxFV (the model tool's): E3's buffers' sizes
{                                                                               // <--- NEW
	var m = /Public Const MaxV = (\d+), MaxFV = (\d+)/.exec(path.basename(f) === 'E3Data.cls' ? fs.readFileSync(f, 'utf8') : '');   // <--- NEW
	if (m) { cfg.maxv = Math.max(8, +m[1]); cfg.maxfv = Math.max(4, +m[2]); }   // <--- NEW
});                                                                             // <--- NEW
var files = list.map(function(f) { return { name: path.basename(f), text: prep(fs.readFileSync(f, 'utf8'), cfg) }; });
fs.writeFileSync(path.join(here, name + '.json'), JSON.stringify({ version: 1, name: name, mode: 'turbo', platform: 'zxn', files: files }, null, '\t'));
console.log(name + '.json: the IDE project (' + files.length + ' files)');

// 2. the assembler
var ntc = findNtc();
if (!ntc)
{
	console.log('NTC\'s src folder not found: give it as  node build.js <game> path/to/src  (the one with js/ntc_compiler.js)');
	process.exit(1);
}
global.window = global;
function load(f, fix)
{
	var t = fs.readFileSync(path.join(ntc, 'js', f), 'utf8');
	(0, eval)(fix ? fix(t) : t);           // (the global scope, as cli.js does at its top)
}
load('ntc_lib.js', function(t) { return t.replace(/^var /gm, 'global.'); });
load('ntc_parser.js', function(t) { return t.replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'); });
load('ntc_compiler.js', function(t) { return t.replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'); });
load('ntc_flavour_js.js');
load('ntc_flavour_loco.js');
var r = global.ntcCompile(files, { platform: 'zxn', name: name, turbo: true });
(r.warnings || []).forEach(function(e) { console.log('warning ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); });
if (r.errors.length)
{
	r.errors.forEach(function(e) { console.log('error ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); });
	process.exit(1);
}
var bdir = path.join(here, 'build');
if (!fs.existsSync(bdir)) fs.mkdirSync(bdir);
fs.writeFileSync(path.join(bdir, name + '.asm'), r.asm);
console.log('build/' + name + '.asm');

// 3. the NEX file
var sj = process.env.SJASMPLUS || 'sjasmplus';
var a = cp.spawnSync(sj, ['--nologo', '--sym=' + name + '.sym', name + '.asm'], { cwd: bdir, encoding: 'utf8' });
if (a.error)
{
	console.log('sjasmplus not found: assemble build/' + name + '.asm with it to get ' + name + '.NEX');
	process.exit(0);
}
process.stdout.write(a.stdout || '');
process.stdout.write(a.stderr || '');
if (a.status)
{
	try { fs.unlinkSync(path.join(bdir, name + '.NEX')); } catch (e) { }
	console.log('the assembly failed: no NEX file');
	process.exit(a.status);
}
var sym = fs.readFileSync(path.join(bdir, name + '.sym'), 'utf8');
var m = /ntc_free:\s+EQU\s+0x([0-9A-Fa-f]+)/.exec(sym);
if (m) console.log('the program ends at #' + m[1].slice(-4) + ': ' + (0xBE00 - parseInt(m[1], 16)) + ' bytes left under #BE00');
console.log('build/' + name + '.NEX: copy it to the Next\'s SD card and run it from the browser');

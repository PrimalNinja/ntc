// build.js - builds this game: the art, the IDE project, the assembler and the NEX file
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node build.js [path to NTC's src folder]
//
// 1. gfxtool.js: gfx/*.png + layout.txt -> GfxData.cls (so new art goes straight in) - when the
//    game has a gfx folder (the sea floor's colours are in World.cls, from tools/world.py)
// 2. NAME.json: the project for NTC BASIC's IDE (ntc.html: Open... it), every .bas / .cls,
//    the zxn platform, turbo
// 3. build/NAME.asm: the compiler's output (NTC's own js/ files, loaded as test/cli.js does)
// 4. build/NAME.NEX: sjasmplus build/NAME.asm, when sjasmplus is on the PATH (or SJASMPLUS=...)
//
// NTC's src folder is looked for in the argument, then NTC_SRC, then ../.. and ../../src (the
// game in src/bas/NAME, or next to src).
'use strict';
var fs = require('fs');
var path = require('path');
var cp = require('child_process');

var here = __dirname;
var cfg = JSON.parse(fs.readFileSync(path.join(here, 'game.json'), 'utf8'));
var name = cfg.name;

function findNtc()
{
	var tries = [process.argv[2], process.env.NTC_SRC, path.join(here, '..', '..'), path.join(here, '..', '..', 'src'), path.join(here, '..', 'src'), path.join(here, '..')];
	for (var i = 0; i < tries.length; i++)
	{
		if (tries[i] && fs.existsSync(path.join(tries[i], 'js', 'ntc_compiler.js'))) return path.resolve(tries[i]);
	}
	return null;
}

// 1. the art
if (fs.existsSync(path.join(here, 'gfx')))
{
	cp.execFileSync(process.execPath, [path.join(here, 'gfxtool.js'), 'build', path.join(here, 'gfx'), path.join(here, 'GfxData.cls')], { stdio: 'inherit' });
}

// 2. the IDE project
var files = cfg.files.map(function(f) { return { name: f, text: fs.readFileSync(path.join(here, f), 'utf8') }; });
fs.writeFileSync(path.join(here, name + '.json'), JSON.stringify({ version: 1, name: name, mode: 'turbo', platform: 'zxn', files: files }, null, '\t'));
console.log(name + '.json: the IDE project (' + files.length + ' files)');

// 3. the assembler
var ntc = findNtc();
if (!ntc)
{
	console.log('NTC\'s src folder not found: give it as  node build.js path/to/src  (the one with js/ntc_compiler.js)');
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
var r = global.ntcCompile(files, { platform: 'zxn', name: name, turbo: process.env.NOTURBO ? false : true });
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

// 4. the NEX file
var sj = process.env.SJASMPLUS || 'sjasmplus';
var a = cp.spawnSync(sj, ['--nologo', name + '.asm'], { cwd: bdir, encoding: 'utf8' });
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
console.log('build/' + name + '.NEX: copy it to the Next\'s SD card and run it from the browser');

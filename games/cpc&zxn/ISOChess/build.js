// build.js - builds ISOChess for every platform: cpc, cpcmin, cpcfw (ISOCHESS.BIN), zxn
// (ISOCHESS.NEX, with Nx.cls) and zx81 (ISOCHESS.P, with Zx.cls), each in its own folder
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node build.js [path to NTC's src folder] [platform ...]
//
// NTC's src folder is looked for in the argument, then NTC_SRC, then ../.. and ../../src.
// The compiler's output goes to <platform>/ISOCHESS.ASM; sjasmplus (on the PATH, or
// SJASMPLUS=...) then makes the file the platform loads.
'use strict';
var fs = require('fs');
var path = require('path');
var cp = require('child_process');

var here = __dirname;
var name = 'ISOCHESS';
var plats = { cpc: ['Nx.cls'], cpcmin: [], cpcfw: [], zxn: ['Nx.cls'], zx81: ['Zx.cls'] };
var args = process.argv.slice(2);
var ntcArg = (args.length && fs.existsSync(path.join(args[0], 'js', 'ntc_compiler.js'))) ? args.shift() : null;
var wanted = args.length ? args : Object.keys(plats);

function findNtc()
{
	var tries = [ntcArg, process.env.NTC_SRC, path.join(here, '..', '..'), path.join(here, '..', '..', 'src'), path.join(here, '..', 'src'), path.join(here, '..')];
	for (var i = 0; i < tries.length; i++)
	{
		if (tries[i] && fs.existsSync(path.join(tries[i], 'js', 'ntc_compiler.js'))) return path.resolve(tries[i]);
	}
	return null;
}
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
	(0, eval)(fix ? fix(t) : t);
}
load('ntc_lib.js', function(t) { return t.replace(/^var /gm, 'global.'); });
load('ntc_parser.js', function(t) { return t.replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'); });
load('ntc_compiler.js', function(t) { return t.replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'); });
load('ntc_flavour_js.js');
load('ntc_flavour_loco.js');

var failed = 0;
wanted.forEach(function(plat)
{
	if (!plats[plat]) { console.log('no such platform: ' + plat); failed++; return; }
	var files = ['ISOChess.bas'].concat(plats[plat]).map(function(f) { return { name: f, text: fs.readFileSync(path.join(here, f), 'utf8') }; });
	var opts = { platform: plat, name: name };
	if (plat === 'cpc' || plat === 'cpcmin' || plat === 'cpcfw') opts.amsdos = name;
	var r = global.ntcCompile(files, opts);
	(r.warnings || []).forEach(function(e) { console.log(plat + ': warning ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); });
	if (r.errors.length)
	{
		r.errors.forEach(function(e) { console.log(plat + ': error ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); });
		failed++;
		return;
	}
	var dir = path.join(here, plat);
	if (!fs.existsSync(dir)) fs.mkdirSync(dir);
	fs.writeFileSync(path.join(dir, name + '.ASM'), r.asm);
	var sj = process.env.SJASMPLUS || 'sjasmplus';
	var a = cp.spawnSync(sj, ['--nologo', name + '.ASM'], { cwd: dir, encoding: 'utf8' });
	if (a.error) { console.log(plat + ': ' + plat + '/' + name + '.ASM written; sjasmplus not found to assemble it'); return; }
	if (a.status) { process.stdout.write(a.stdout || ''); process.stdout.write(a.stderr || ''); console.log(plat + ': the assembly failed'); failed++; return; }
	var out = { zxn: '.NEX', zx81: '.P' }[plat] || '.BIN';
	console.log(plat + ': ' + plat + '/' + name + out);
});
process.exit(failed ? 1 : 0);

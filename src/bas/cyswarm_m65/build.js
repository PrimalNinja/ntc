// build.js - builds CYBORG SWARM for the MEGA65: the IDE project, the assembly and the PRG.
// (c) 2026 Cyborg Unicorn Pty Ltd
//
//   node build.js [path to NTC's src folder] [--vasm=path/to/vasm6502_oldstyle] [--log] [--gfx]
//
// 1. --gfx: tools/cyswarm_gfx.py and tools/cyswarm_data.py make Gfx.cls and Paths.cls again (only
//    needed after changing the art or the paths)
// 2. CYSWARM.json: the project for NTC BASIC's IDE (ntc.html: Open... it), platform m65
// 3. build/CYSWARM.s: the compiler's output (NTC's own js/ files, loaded as test/cli.js does)
// 4. vasm (6502 oldstyle syntax with the 45GS02's instructions; --vasm=, or NTC_VASM65, or
//    vasm6502_oldstyle on the PATH):
//    vasm6502_oldstyle -quiet -mega65 -opt-branch -Fbin -L build/CYSWARM.lst -o ... build/CYSWARM.s
// 5. the load address ($2001) put in front: build/CYSWARM.PRG, which BASIC 65 loads and RUNs
// --log: a test build (vasm -DNTC_M65LOG=1: what the console prints kept in RAM from $10000)
'use strict';
var fs = require('fs');
var path = require('path');
var cp = require('child_process');

var here = __dirname;
var cfg = JSON.parse(fs.readFileSync(path.join(here, 'game.json'), 'utf8'));
var args = process.argv.slice(2);
var vasm = process.env.NTC_VASM65 || 'vasm6502_oldstyle';
args.forEach(function(a) { if (a.indexOf('--vasm=') === 0) vasm = a.substr(7); });
var log = args.indexOf('--log') >= 0;

function findNtc()
{
	var tries = [args.filter(function(a) { return a.indexOf('--') !== 0; })[0], process.env.NTC_SRC, path.join(here, '..', 'ntc', 'src'), path.join(here, '..', '..', 'ntc', 'src'), path.join(here, '..', '..')];
	for (var i = 0; i < tries.length; i++)
	{
		if (tries[i] && fs.existsSync(path.join(tries[i], 'js', 'ntc_compiler.js'))) return path.resolve(tries[i]);
	}
	return null;
}

// 1. the graphics and the tables
if (args.indexOf('--gfx') >= 0)
{
	['cyswarm_gfx.py', 'cyswarm_data.py'].forEach(function(t)
	{
		var r = cp.spawnSync('python3', [path.join(here, 'tools', t)], { encoding: 'utf8' });
		process.stdout.write((r.stdout || '').split('\n')[0] + '\n');
		if (r.status) { process.stdout.write(r.stderr || ''); process.exit(1); }
	});
}

// 2. the IDE project
var files = cfg.files.map(function(f) { return { name: f, text: fs.readFileSync(path.join(here, f), 'utf8') }; });
fs.writeFileSync(path.join(here, cfg.name + '.json'), JSON.stringify({ version: 1, name: cfg.name, mode: 'turbo', platform: cfg.platform, files: files }, null, '\t'));
console.log(cfg.name + '.json: the IDE project (' + files.length + ' files)');

// 3. compile
var ntc = findNtc();
if (!ntc) { console.log('NTC not found: node build.js /path/to/ntc/src'); process.exit(1); }
global.window = global;
function load(f, fix) { var t = fs.readFileSync(path.join(ntc, 'js', f), 'utf8'); eval((fix ? fix(t) : t)); }
load('ntc_lib.js', function(t) { return t.replace(/^var /gm, 'global.'); });
load('ntc_parser.js', function(t) { return t.replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'); });
load('ntc_compiler.js', function(t) { return t.replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'); });
['ntc_flavour_js.js', 'ntc_flavour_php.js', 'ntc_flavour_loco.js'].forEach(function(f) { load(f); });
var r = ntcCompile(files, { platform: cfg.platform, name: cfg.name });
(r.warnings || []).forEach(function(e) { console.log('warning ' + (e.file || '') + ':' + e.line + ': ' + e.msg); });
if (r.errors.length)
{
	r.errors.forEach(function(e) { console.log('ERROR ' + (e.file || '') + ':' + e.line + ': ' + e.msg); });
	process.exit(1);
}
fs.mkdirSync(path.join(here, 'build'), { recursive: true });
var asm = path.join(here, 'build', cfg.name + '.s');
var prg = path.join(here, 'build', cfg.name + '.PRG');
fs.writeFileSync(asm, r.asm);
console.log('build/' + cfg.name + '.s: the assembly (NTC ' + ntc + ')');

// 4. assemble
var bin = prg + '.bin';
var va = cp.spawnSync(vasm, ['-quiet', '-mega65', '-opt-branch', '-Fbin', '-L', path.join(here, 'build', cfg.name + '.lst'), '-o', bin].concat(log ? ['-DNTC_M65LOG=1'] : []).concat([asm]), { encoding: 'utf8' });
if (va.error) { console.log('vasm not found (' + vasm + '): --vasm=path, or NTC_VASM65'); process.exit(1); }
if (va.status) { process.stdout.write((va.stdout || '') + (va.stderr || '')); process.exit(1); }

// 5. the load address
var b = fs.readFileSync(bin);
fs.unlinkSync(bin);
fs.writeFileSync(prg, Buffer.concat([Buffer.from([0x01, 0x20]), b]));
console.log('build/' + cfg.name + '.PRG: ' + (b.length + 2) + ' bytes ($2001-$' + (0x2000 + b.length).toString(16).toUpperCase() + ')');

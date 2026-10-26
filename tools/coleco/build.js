// Build a ColecoVision cartridge from NTC BASIC files.
//   node build.js out.col Main.bas [Coleco.cls ...] [--layout]
// Compiles for the colecovision platform (src/asm/ntc_plat_colecovision.asm: bare metal + ROM keys),
// Option Turbo, assembles with sjasmplus (SJASMPLUS=/path, else on the PATH) and writes the .col
// ROM (padded to 8 / 16 / 24 / 32K), plus out.asm, out.sym next to it.
// (c) 2026 Cyborg Unicorn Pty Ltd
var fs = require('fs');
var path = require('path');
var cp = require('child_process');

global.window = global;
var SRC = path.join(__dirname, '..', '..', 'src') + '/';
eval(fs.readFileSync(SRC + 'js/ntc_lib.js', 'utf8').replace(/^var /gm, 'global.'));
eval(fs.readFileSync(SRC + 'js/ntc_parser.js', 'utf8').replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'));
eval(fs.readFileSync(SRC + 'js/ntc_compiler.js', 'utf8').replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'));
eval(fs.readFileSync(SRC + 'js/ntc_flavour_js.js', 'utf8'));
eval(fs.readFileSync(SRC + 'js/ntc_flavour_php.js', 'utf8'));
eval(fs.readFileSync(SRC + 'js/ntc_flavour_loco.js', 'utf8'));

var args = process.argv.slice(2);
var files = [];
var out = null;
var layout = false;

args.forEach(function(a)
{
	if (a === '--layout') { layout = true; }
	else if (out === null) { out = a; }
	else { files.push({ name: path.basename(a), text: fs.readFileSync(a, 'utf8') }); }
});
if (!out || files.length === 0)
{
	console.error('usage: node build.js out.col Main.bas [Coleco.cls ...] [--layout]');
	process.exit(2);
}

var r = ntcCompile(files, { platform: 'colecovision', turbo: true, name: 'COL', showlayout: layout });
var bad = false;

r.errors.forEach(function(e) { console.error('ERR ' + (e.file || '') + ':' + e.line + ': ' + e.msg); bad = true; });
(r.warnings || []).forEach(function(e) { console.error('WARN ' + (e.file || '') + ':' + e.line + ': ' + e.msg); });
if (layout) { (r.layout || []).forEach(function(l) { console.error('LAYOUT ' + l); }); }
if (bad) { process.exit(1); }

var base = out.replace(/\.[^.]*$/, '');
var asmPath = base + '.asm';
var symPath = base + '.sym';

fs.writeFileSync(asmPath, r.asm);
var SJ = process.env.SJASMPLUS || ((process.platform === 'win32') ? path.join(__dirname, '..', '..', 'sjasmplus', 'sjasmplus.exe') : 'sjasmplus');
var p = cp.spawnSync(SJ, ['--nologo', '--raw=' + path.basename(out), '--sym=' + path.basename(symPath), path.basename(asmPath)], { cwd: path.dirname(path.resolve(asmPath)), encoding: 'utf8' });

if (p.error)
{
	console.error('cannot run ' + SJ + ': ' + p.error.message + ' (put sjasmplus on the PATH, or set SJASMPLUS)');
	process.exit(1);
}
if (p.status !== 0)
{
	console.error(String(p.stdout) + String(p.stderr));
	process.exit(1);
}
if (p.stderr) { console.error(p.stderr); }
var stray = path.join(path.dirname(path.resolve(asmPath)), 'COL.COL');		// the assembly's own OUTPUT file (the same ROM)

if ((path.resolve(out) !== stray) && fs.existsSync(stray)) { fs.unlinkSync(stray); }
var rom = fs.readFileSync(out);

console.log(out + ': ' + rom.length + ' bytes, header ' + rom[0].toString(16) + rom[1].toString(16) + ', start #' + (rom[10] | (rom[11] << 8)).toString(16));

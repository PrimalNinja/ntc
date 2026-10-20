// nb.js DIR [NTC_SRC] - compile DIR/game.json (its files relative to DIR) with NTC BASIC for the zxn
// platform (turbo), and assemble it with sjasmplus into DIR/build/NAME.NEX (+ NAME.sym for the tests)
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var fs = require('fs'), path = require('path'), cp = require('child_process');
var dir = path.resolve(process.argv[2] || '.');
var ntc = process.argv[3] || process.env.NTC_SRC || '/home/claude/ntc/src';
var cfg = JSON.parse(fs.readFileSync(path.join(dir, 'game.json'), 'utf8'));
var files = cfg.files.map(function(f) { return { name: path.basename(f), text: fs.readFileSync(path.join(dir, f), 'utf8') }; });
global.window = global;
function load(f, fix) { var t = fs.readFileSync(path.join(ntc, 'js', f), 'utf8'); (0, eval)(fix ? fix(t) : t); }
load('ntc_lib.js', function(t) { return t.replace(/^var /gm, 'global.'); });
load('ntc_parser.js', function(t) { return t.replace(/^var /gm, 'global.').replace('function IFtoPF', 'global.IFtoPF = function IFtoPF').replace('function ntcParse', 'global.ntcParse = function ntcParse'); });
load('ntc_compiler.js', function(t) { return t.replace('function ntcCompile', 'global.ntcCompile = function ntcCompile'); });
load('ntc_flavour_js.js'); load('ntc_flavour_loco.js');
var r = global.ntcCompile(files, { platform: 'zxn', name: cfg.name, turbo: true });
(r.warnings || []).forEach(function(e) { console.log('warning ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); });
if (r.errors.length) { r.errors.forEach(function(e) { console.log('error ' + (e.file || '') + ' line ' + e.line + ': ' + e.msg); }); process.exit(1); }
var b = path.join(dir, 'build'); if (!fs.existsSync(b)) fs.mkdirSync(b);
fs.writeFileSync(path.join(b, cfg.name + '.asm'), r.asm);
var a = cp.spawnSync('sjasmplus', ['--nologo', '--sym=' + cfg.name + '.sym', cfg.name + '.asm'], { cwd: b, encoding: 'utf8' });
var out = (a.stdout || '') + (a.stderr || '');
console.log(out.split('\n').filter(function(l) { return /error|warning|Errors/i.test(l); }).slice(0, 30).join('\n'));
var short = cfg.name.slice(0, 8) + '.NEX';
if (short !== cfg.name + '.NEX' && fs.existsSync(path.join(b, short))) fs.renameSync(path.join(b, short), path.join(b, cfg.name + '.NEX'));
process.exit(a.status);

// mktables.js - the tables Tiny.cls carries as #asm data: run it and paste its output where the
// class says (or: node tools/tiny/mktables.js > tables.inc and diff against the class).
//   node tools/tiny/mktables.js
// Tiny's scale is 64 (1.0 = 64; the range -2.0 .. 1.98). Tables, 256 entries each, indexed by the
// byte (0-127 then -128..-1 as 128-255): tanh, sigmoid (0 .. 1 as 0 .. 64) and the reciprocal
// 64 * 64 / x (saturated) for Div.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'use strict';
var S = 64;
function sat(v) { v = Math.round(v); return v > 127 ? 127 : (v < -128 ? -128 : v); }
function row(name, f)
{
	var out = []; for (var b = 0; b < 256; b++) { var x = (b < 128 ? b : b - 256) / S; out.push(sat(f(x)) & 255); }
	var s = '; ' + name + '\n';
	for (var i = 0; i < 256; i += 16) { s += (i === 0 ? ('tb_' + name + ':').padEnd(12) : ' '.repeat(12)) + 'db ' + out.slice(i, i + 16).join(',') + '\n'; }
	return s;
}
process.stdout.write(row('tanh', function(x) { return Math.tanh(x) * S; }));
process.stdout.write(row('sigm', function(x) { return S / (1 + Math.exp(-x)); }));
process.stdout.write(row('recip', function(x) { return x === 0 ? 127 : S / x; }));

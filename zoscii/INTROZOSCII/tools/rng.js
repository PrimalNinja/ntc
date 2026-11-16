// rng.js - a model of src/Rng.cls (the same steps, in JS) with ENT-style tests of its output: entropy, mean, chi-square, serial correlation.
//   node tools/rng.js stats [bytes]        the tests on the output of a few seeds (and, for comparison, NTC's old xorshift)
//   node tools/rng.js dump p0 p1 p2 p3 n   the first n bytes for a pool (hex numbers), to compare with the Next's
// (c) 2026 Cyborg Unicorn Pty Ltd
'use strict';
var fs = require('fs');
var path = require('path');
var DAT = fs.readFileSync(process.env.RNG_DAT || path.join(__dirname, '..', 'assets', 'INTRO.DAT'));
var NCH = 400;

function rol(v, n) { return ((v << n) | (v >>> (16 - n))) & 0xFFFF; }

function Rng(p0, p1, p2, p3)
{
	var p = [p0 & 0xFFFF, p1 & 0xFFFF, p2 & 0xFFFF, p3 & 0xFFFF];
	var ord = [], cp = [], co = [], sd = [], sw = [], cc = [], fromPool = 0;
	function round()
	{
		var a = (p[0] + p[1]) & 0xFFFF;
		p[1] = rol(p[1], 5) ^ a;
		a = rol(a, 8);
		var b = (p[2] + p[3]) & 0xFFFF;
		p[3] = rol(p[3], 4) ^ b;
		a = (a + p[3]) & 0xFFFF;
		p[3] = rol(p[3], 3) ^ a;
		b = (b + p[1]) & 0xFFFF;
		p[1] = rol(p[1], 7) ^ b;
		b = rol(b, 8);
		p[0] = a; p[2] = b;
	}
	function mix(v) { p[0] ^= (v & 0xFFFF); round(); round(); }
	function pw() { round(); return p[0] ^ p[1] ^ p[2] ^ p[3]; }
	function rb()
	{
		var v = 0, r, ch, t2;
		for (r = 0; r < 5; r++)
		{
			ch = cc[r];
			v ^= DAT[(ch >> 4) * 16384 + (ch & 15) * 1024 + co[r]];
			co[r] += sd[r]; t2 = sd[r]; sd[r] = sw[r]; sw[r] = t2;
			if (co[r] > 1023 || co[r] < 0)
			{
				if (co[r] < 0) { co[r] += 1024; cp[r]--; if (cp[r] < 0) { cp[r] = NCH - 1; } }
				else { co[r] -= 1024; cp[r]++; if (cp[r] >= NCH) { cp[r] = 0; } }
				cc[r] = ord[cp[r]];
			}
		}
		return v;
	}
	function pick(n)
	{
		if (n <= 1) { return 0; }
		var v;
		if (fromPool) { v = pw() & 32767; }                                     // the bytes as they come, wrapped into the range: no retry (as src/Rng.cls)
		else if (n > 256) { v = rb(); v = ((v * 256) + rb()) & 32767; }
		else { v = rb(); }
		return v % n;
	}
	function reseed()
	{
		var i, j, t, r;
		fromPool = 1;
		for (i = 0; i < NCH; i++) { ord[i] = i; }
		for (i = NCH - 1; i >= 1; i--) { j = pick(i + 1); t = ord[i]; ord[i] = ord[j]; ord[j] = t; }
		for (r = 0; r < 5; r++)
		{
			cp[r] = pick(NCH);
			co[r] = pick(1024);
			j = pick(2) * 2 - 1; t = 2 + pick(99); var u = 2 + pick(99);
			sd[r] = j * t; sw[r] = j * u;
			cc[r] = ord[cp[r]];
		}
		fromPool = 0;
	}
	reseed();
	return { rb: rb, pick: pick, mix: mix, reseed: reseed };
}

function stats(buf)
{
	var n = buf.length, c = new Array(256).fill(0), i, s = 0, e = 0, x2 = 0, ex = n / 256;
	for (i = 0; i < n; i++) { c[buf[i]]++; s += buf[i]; }
	for (i = 0; i < 256; i++) { if (c[i]) { e -= (c[i] / n) * Math.log2(c[i] / n); } x2 += (c[i] - ex) * (c[i] - ex) / ex; }
	var mean = s / n, sxy = 0, sxx = 0, sx = 0, sx2 = 0;
	for (i = 0; i < n - 1; i++) { sx += buf[i]; sx2 += buf[i] * buf[i]; sxy += buf[i] * buf[i + 1]; }
	var sc = (n * sxy - sx * sx) / (n * sx2 - sx * sx);
	return 'entropy ' + e.toFixed(5) + '  mean ' + mean.toFixed(2) + '  chi2 ' + x2.toFixed(1) + ' (255 +- 23 is normal)  serial corr ' + sc.toFixed(4);
}

function xorshift(seed, n)
{
	var s = seed, out = Buffer.alloc(n), i;
	for (i = 0; i < n; i++)
	{
		s ^= (s << 7) & 0xFFFF; s ^= s >> 9; s ^= (s << 8) & 0xFFFF; s &= 0xFFFF;
		out[i] = s & 255;
	}
	return out;
}

if (require.main === module)
{
	var mode = process.argv[2] || 'stats';
	if (mode === 'dump')
	{
		var a = process.argv.slice(3, 7).map(function(x) { return parseInt(x, 16); }), n = parseInt(process.argv[7], 10) || 32, g = Rng(a[0], a[1], a[2], a[3]), o = [];
		for (var i = 0; i < n; i++) { o.push(('0' + g.rb().toString(16)).slice(-2)); }
		console.log(o.join(' '));
	}
	else
	{
		var N = parseInt(process.argv[3], 10) || 200000;
		[[0x243F, 0x6A88, 0x85A3, 0x08D3], [1, 2, 3, 4], [0, 0, 0, 0], [0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF], [0x1234, 0x5678, 0x9ABC, 0xDEF0]].forEach(function(p)
		{
			var g = Rng(p[0], p[1], p[2], p[3]), b = Buffer.alloc(N), i;
			for (i = 0; i < N; i++) { b[i] = g.rb(); }
			console.log('pool ' + p.map(function(x) { return x.toString(16); }).join(' ') + ': ' + stats(b));
		});
		console.log('NTC xorshift low byte: ' + stats(xorshift(1, N)));
		var d = DAT.slice(16384, 16384 + 65536);
		console.log('the ROM data itself (64K): ' + stats(d));
		var g2 = Rng(1, 2, 3, 4), same = 0, k;
		var A = Rng(1, 2, 3, 4), B = Rng(1, 2, 3, 5);
		for (k = 0; k < 10000; k++) { if (A.rb() === B.rb()) { same++; } }
		console.log('pools differing by one bit: ' + same + ' of 10000 bytes equal (about 39 expected)');
		var C = Rng(1, 2, 3, 4), D = Rng(1, 2, 3, 4); same = 0;
		C.mix(7); D.mix(8); C.reseed(); D.reseed();
		for (k = 0; k < 10000; k++) { if (C.rb() === D.rb()) { same++; } }
		console.log('same pool, one mixed value differing (7 / 8): ' + same + ' of 10000 bytes equal');
		var h = new Array(7).fill(0), q;
		var E = Rng(0x243F, 0x6A88, 0x85A3, 0x08D3);
		for (k = 0; k < 70000; k++) { h[E.pick(7)]++; }
		console.log('pick(7) x 70000: ' + h.join(' ') + '  (10000 each expected: no skew)');
	}
}
module.exports = { Rng: Rng, stats: stats };

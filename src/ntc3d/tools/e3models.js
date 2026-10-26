// e3models.js - NTC3D's model tool: a game's model file -> its E3Data.cls (the tables the Z80
// reads straight off: sines, edge reciprocals, the font; the model kinds' K_ constants; where the
// data block's tables are) and build/NAME.DAT (one 16K block the NEX file carries, Option NexData:
// the projection's reciprocals, the palette - 16 ramps of 16 shades, 9 bit - the stars, the model
// table, the hit table and the models; E3 keeps it at #C000), and a picture of the models.
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node tools/e3models.js models.js [game folder] [--name NAME] [--png pictures.png]
//
// The game folder (where E3Data.cls goes, NAME.DAT into its build/) is the model file's own unless
// given; NAME is game.json's name there, else DATA. ES5: runs on any node.
//
// A model file is a node module: module.exports = function (M) { ... return { ramps, kinds,
// stars }; } - M is the builder below. Every model is one convex solid (E3 draws a model's faces
// in any order, so it must be convex): given as a cloud of points (whole numbers -127 .. 127: a
// model unit is 2^size world units, the size given where the game puts the object down), its hull
// is worked out here, flat faces merged, each face given a colour ramp by a function of its normal
// (which way it faces), its middle and its number.
//   ramps: 16 x { a: [r, g, b], b: [r, g, b], lift: 0 .. 1 } (0 - 1 each: the darkest shade, the
//          lightest; lift starts the ramp that far up, so a face turned from the sun still shows)
//   kinds: [ M.kind(NAME, near model, far model, hit) ... ] - K_NAME = its number; hit: [across,
//          up] half sizes in model units (Obj3D's hit box), or left out: the near model's extents
//   stars: { n, seed, colour: function (rnd, i) -> a palette index } (or left out: 96 grey ones)
'use strict';
var fs = require('fs');
var path = require('path');
var zlib = require('zlib');

// ---------------------------------------------------------------- numbers as Python does them
// (the first games' data was made by a Python tool: these keep every byte the same)
function pyRound(x)
{
	var f = Math.floor(x), d = x - f;
	if (d > 0.5) return f + 1;
	if (d < 0.5) return f;
	return (f % 2 === 0) ? f : f + 1;
}
function trunc(x) { return x < 0 ? Math.ceil(x) : Math.floor(x); }
function mul32(a, b)
{
	var al = a & 0xFFFF, ah = a >>> 16;
	return (((ah * b) & 0xFFFF) * 65536 + al * b) >>> 0;
}
// Python's random.Random(seed): MT19937, seeded by init_by_array([seed])
function PyRandom(seed)
{
	var mt = this.mt = new Array(624);
	var i, j, k, s;
	mt[0] = 19650218;
	for (i = 1; i < 624; i++) mt[i] = (mul32(mt[i - 1] ^ (mt[i - 1] >>> 30), 1812433253) + i) >>> 0;
	var key = [seed >>> 0];
	i = 1; j = 0;
	for (k = Math.max(624, key.length); k; k--)
	{
		s = mt[i - 1] ^ (mt[i - 1] >>> 30);
		mt[i] = (((mt[i] ^ mul32(s, 1664525)) >>> 0) + key[j] + j) >>> 0;
		i++; j++;
		if (i >= 624) { mt[0] = mt[623]; i = 1; }
		if (j >= key.length) j = 0;
	}
	for (k = 623; k; k--)
	{
		s = mt[i - 1] ^ (mt[i - 1] >>> 30);
		mt[i] = (((mt[i] ^ mul32(s, 1566083941)) >>> 0) - i) >>> 0;
		i++;
		if (i >= 624) { mt[0] = mt[623]; i = 1; }
	}
	mt[0] = 0x80000000;
	this.mti = 624;
}
PyRandom.prototype.u32 = function()
{
	var mt = this.mt, y, kk;
	if (this.mti >= 624)
	{
		for (kk = 0; kk < 624; kk++)
		{
			y = (mt[kk] & 0x80000000) | (mt[(kk + 1) % 624] & 0x7FFFFFFF);
			mt[kk] = (mt[(kk + 397) % 624] ^ (y >>> 1) ^ ((y & 1) ? 0x9908B0DF : 0)) >>> 0;
		}
		this.mti = 0;
	}
	y = mt[this.mti++];
	y ^= (y >>> 11);
	y ^= (y << 7) & 0x9D2C5680;
	y ^= (y << 15) & 0xEFC60000;
	y ^= (y >>> 18);
	return y >>> 0;
};
PyRandom.prototype.random = function()
{
	var a = this.u32() >>> 5, b = this.u32() >>> 6;
	return (a * 67108864 + b) / 9007199254740992;
};
PyRandom.prototype.uniform = function(a, b) { return a + (b - a) * this.random(); };
PyRandom.prototype.randrange = function(n)
{
	var k = 0, m = n, r;
	while (m) { k++; m = Math.floor(m / 2); }
	do { r = this.u32() >>> (32 - k); } while (r >= n);
	return r;
};

// ---------------------------------------------------------------- vectors
function sub(a, b) { return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]; }
function mul(a, k) { return [a[0] * k, a[1] * k, a[2] * k]; }
function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]; }
function dot(a, b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
function norm(v) { var l = Math.sqrt(dot(v, v)) || 1; return [v[0] / l, v[1] / l, v[2] / l]; }

// ---------------------------------------------------------------- hulls
// the convex hull of pts: [{ n: unit normal, f: [point indices, counter-clockwise seen from
// outside] }], flat faces merged, points inside the hull or in an edge's middle left out
function hull(pts)
{
	var n = pts.length, planes = [], faces = [], i, j, k;
	for (i = 0; i < n; i++)
	for (j = i + 1; j < n; j++)
	for (k = j + 1; k < n; k++)
	{
		var a = pts[i], b = pts[j], c = pts[k];
		var nn = cross(sub(b, a), sub(c, a));
		if (dot(nn, nn) < 1e-6) continue;
		nn = norm(nn);
		var side = pts.map(function(p) { return dot(nn, sub(p, a)); });
		if (side.every(function(s) { return s <= 1e-4; })) { }
		else if (side.every(function(s) { return s >= -1e-4; })) nn = mul(nn, -1);
		else continue;
		var d = dot(nn, a);
		if (planes.some(function(q) { return Math.abs(dot(nn, q[0]) - 1) < 1e-6 && Math.abs(q[1] - d) < 1e-3; })) continue;
		planes.push([nn, d]);
	}
	planes.forEach(function(pl)
	{
		var nn = pl[0], d = pl[1];
		var on = [];
		for (var q = 0; q < n; q++) if (Math.abs(dot(nn, pts[q]) - d) < 1e-3) on.push(q);
		var c = [0, 0, 0];
		on.forEach(function(q) { c[0] += pts[q][0]; c[1] += pts[q][1]; c[2] += pts[q][2]; });
		c = mul(c, 1.0 / on.length);
		var u = norm(sub(pts[on[0]], c)), v = cross(nn, u);
		var key = {};
		on.forEach(function(q) { var w = sub(pts[q], c); key[q] = Math.atan2(dot(w, v), dot(w, u)); });
		on.sort(function(x, y) { return key[x] - key[y]; });
		var keep = [], m = on.length;
		for (var t = 0; t < m; t++)
		{
			var p0 = pts[on[(t - 1 + m) % m]], p1 = pts[on[t]], p2 = pts[on[(t + 1) % m]];
			if (dot(cross(sub(p1, p0), sub(p2, p1)), nn) > 1e-3) keep.push(on[t]);
		}
		faces.push({ n: nn, f: keep });
	});
	return faces;
}

// a model: name, points, colour(normal, middle, k) -> a ramp; opt.keep(face) -> false drops a face
function Model(name, pts, colour, opt)
{
	this.name = name;
	pts = pts.map(function(p) { return [pyRound(p[0]), pyRound(p[1]), pyRound(p[2])]; });
	pts.forEach(function(p) { p.forEach(function(c) { if (c < -127 || c > 127) throw new Error(name + ': a point past 127: ' + p); }); });
	var fs_ = hull(pts);
	if (opt && opt.keep) fs_ = fs_.filter(opt.keep);
	var used = [];
	fs_.forEach(function(f) { f.f.forEach(function(q) { if (used.indexOf(q) < 0) used.push(q); }); });
	used.sort(function(a, b) { return a - b; });
	var self = this;
	this.verts = used.map(function(q) { return pts[q]; });
	this.faces = [];
	fs_.forEach(function(f, k)
	{
		var idx = f.f.map(function(q) { return used.indexOf(q); });
		var cen = [0, 0, 0];
		idx.forEach(function(q) { cen[0] += self.verts[q][0]; cen[1] += self.verts[q][1]; cen[2] += self.verts[q][2]; });
		cen = mul(cen, 1.0 / idx.length);
		self.faces.push({ ramp: colour(f.n, cen, k), n: f.n, idx: idx });
	});
	if (this.verts.length > 64) throw new Error(name + ': over 64 points');
	this.faces.forEach(function(f) { if (f.idx.length > 16) throw new Error(name + ': a face with over 16 points'); });
}
Model.prototype.bytes = function()
{
	var r = 0;
	this.verts.forEach(function(v) { r = Math.max(r, Math.sqrt(dot(v, v))); });
	var out = [this.verts.length, this.faces.length, Math.min(255, Math.ceil(r))];
	this.verts.forEach(function(v) { out.push(v[0] & 255, v[1] & 255, v[2] & 255); });
	var verts = this.verts;
	this.faces.forEach(function(f)
	{
		var n8 = [pyRound(f.n[0] * 120), pyRound(f.n[1] * 120), pyRound(f.n[2] * 120)];
		var d = dot(n8, verts[f.idx[0]]);           // the plane: n . v = d (seen from e when n . e > d)
		out.push(f.idx.length, f.ramp, n8[0] & 255, n8[1] & 255, n8[2] & 255, d & 255, (d >> 8) & 255);
		f.idx.forEach(function(q) { out.push(q); });
	});
	return out;
};
// one flat face, its points counter-clockwise seen from the side it faces
function oneFace(name, pts, ramp)
{
	var m = Object.create(Model.prototype);
	m.name = name;
	m.verts = pts.map(function(p) { return [trunc(p[0]), trunc(p[1]), trunc(p[2])]; });
	m.faces = [{ ramp: ramp, n: norm(cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))), idx: pts.map(function(p, i) { return i; }) }];
	return m;
}

// ---------------------------------------------------------------- compound models   // <--- NEW (to the builder)
// (NEW) a compound model: several convex parts (each a Model, at its place) drawn as one object.
// E3 draws a model's faces in order, those turned away left out - right for one convex solid, so
// for several the tool puts the parts in a painter's order: part A before part B when a face plane
// of one separates them and the eye is on B's side of it (otherwise by distance from the eye). The
// eye that order is for: opt.eye ([x, y, z] in model units, far off: [0, 60, 2000] - ahead, a
// little above). With opt.views 2 there are two orders: from ahead (+z) and from behind (-z), and
// E3 picks by which side of the object the camera is (a header block: #FF, 2, the two offsets).
function Compound(name, parts, opt)
{
	opt = opt || {};
	this.name = name;
	this.parts = parts;
	this.views = opt.views || 1;
	var e = opt.eye || [0, 60, 2000];
	this.eyes = this.views === 2 ? [[e[0], e[1], -e[2]], e] : [e];
	var self = this;
	this.variants = this.eyes.map(function(ey, i) { return self.forEye(ey, name + (self.views === 2 ? (i ? '_f' : '_b') : '')); });
	this.verts = this.variants[0].verts;            // (for the radius, the hit box, MaxV)
	this.faces = this.variants[0].faces;
}
function partOrder(parts, eye)
{
	var n = parts.length, before = [], i, j;
	for (i = 0; i < n; i++) before.push([]);
	function sep(a, b)      // a face plane of a with all of b on its outside: its sign for the eye
	{
		for (var k = 0; k < a.faces.length; k++)
		{
			var f = a.faces[k], d = dot(f.n, a.verts[f.idx[0]]);
			if (b.verts.every(function(v) { return dot(f.n, v) >= d - 0.5; })) return dot(f.n, eye) > d ? 1 : -1;
		}
		return 0;
	}
	function dist(m) { var c = [0, 0, 0]; m.verts.forEach(function(v) { c = [c[0] + v[0], c[1] + v[1], c[2] + v[2]]; }); c = mul(c, 1 / m.verts.length); var w = sub(c, eye); return dot(w, w); }
	for (i = 0; i < n; i++) for (j = i + 1; j < n; j++)
	{
		var s = sep(parts[i], parts[j]), t = 0;
		if (s) t = s;                                   // eye beyond i's plane: j is in front
		else { s = sep(parts[j], parts[i]); if (s) t = -s; else t = dist(parts[i]) > dist(parts[j]) ? 1 : -1; }
		if (t > 0) before[j].push(i); else before[i].push(j);
	}
	var out = [], done = [];
	while (out.length < n)
	{
		var pick = -1;
		for (i = 0; i < n && pick < 0; i++) if (!done[i] && before[i].every(function(q) { return done[q]; })) pick = i;
		if (pick < 0) for (i = 0; i < n; i++) if (!done[i]) { pick = i; break; }   // (a cycle: as given)
		done[pick] = true; out.push(parts[pick]);
	}
	return out;
}
Compound.prototype.forEye = function(eye, name)
{
	var m = Object.create(Model.prototype);
	m.name = name; m.verts = []; m.faces = [];
	partOrder(this.parts, eye).forEach(function(p)
	{
		var base = m.verts.length;
		p.verts.forEach(function(v) { m.verts.push(v); });
		p.faces.forEach(function(f) { m.faces.push({ ramp: f.ramp, n: f.n, idx: f.idx.map(function(q) { return q + base; }) }); });
	});
	if (m.verts.length > 64) throw new Error(name + ': over 64 points');
	if (m.faces.length > 64) throw new Error(name + ': over 64 faces');
	return m;
};

// ---------------------------------------------------------------- the builder a model file gets
var M = {
	Model: function(name, pts, colour, opt) { return new Model(name, pts, colour, opt); },
	Compound: function(name, parts, opt) { return new Compound(name, parts, opt); },     // <--- NEW
	box: function(x0, x1, y0, y1, z0, z1) { return [[x0, y0, z0], [x1, y0, z0], [x0, y1, z0], [x1, y1, z0], [x0, y0, z1], [x1, y0, z1], [x0, y1, z1], [x1, y1, z1]]; },   // <--- NEW (a box's corners)
	oneFace: oneFace,
	mirrorX: function(pts)
	{
		var out = [];
		pts.forEach(function(p) { out.push(p); if (p[0] !== 0) out.push([-p[0], p[1], p[2]]); });
		return out;
	},
	kind: function(name, near, far, hit) { return { name: name, near: near, far: far || near, hit: hit || null }; },
	random: function(seed) { return new PyRandom(seed); },
	round: pyRound, trunc: trunc, norm: norm, mul: mul, dot: dot, cross: cross, sub: sub
};

// ---------------------------------------------------------------- the tables
function palette(ramps)
{
	var out = [];
	for (var k = 0; k < 16; k++)
	{
		var e = rampEnds(ramps[k] || { a: [0, 0, 0], b: [1, 1, 1] });
		for (var s = 0; s < 16; s++)
		{
			var t = s / 15.0, c = [0, 1, 2].map(function(i) { return e[0][i] + (e[1][i] - e[0][i]) * t; });
			if (k === 0 && s === 0) c = [0, 0, 0];
			var R = Math.min(7, pyRound(c[0] * 7)), G = Math.min(7, pyRound(c[1] * 7)), B = Math.min(7, pyRound(c[2] * 7));
			out.push((R << 5) | (G << 2) | (B >> 1), B & 1);
		}
	}
	return out;
}
function rampEnds(r)
{
	var f = r.lift || 0;
	return [[0, 1, 2].map(function(i) { return r.a[i] + (r.b[i] - r.a[i]) * f; }), r.b];
}
function rgbOf(ramps, c)
{
	var k = c >> 4, s = c & 15, e = rampEnds(ramps[k] || { a: [0, 0, 0], b: [1, 1, 1] });
	var v = [0, 1, 2].map(function(i) { return e[0][i] + (e[1][i] - e[0][i]) * s / 15.0; });
	if (c === 0) v = [0, 0, 0];
	return v.map(function(x) { return pyRound(Math.min(7, pyRound(x * 7)) * 255 / 7); });
}
function sines() { var o = []; for (var i = 0; i < 256; i++) o.push(pyRound(Math.sin(i * 2 * Math.PI / 256) * 127) & 255); return o; }
function recipEdge() { var o = []; for (var d = 0; d < 256; d++) {   // <--- CHANGED (was 1024: 1.5K saved; E3's clipper halves to under 256)
		 var v = d < 2 ? 65535 : Math.floor(65536 / d); o.push(v & 255, v >> 8); } return o; }
function recipProj() { var o = []; for (var n = 256; n < 4096; n++) { var v = Math.min(65535, Math.floor(16777216 / n)); o.push(v & 255, v >> 8); } return o; }
function stars(st)
{
	st = st || {};
	var n = st.n || 96, rnd = new PyRandom(st.seed === undefined ? 11 : st.seed), out = [];
	for (var i = 0; i < n; i++)
	{
		var v, l;
		for (;;)
		{
			v = [rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)];
			l = Math.sqrt(dot(v, v));
			if (l > 0.2 && l <= 1) break;
		}
		v = v.map(function(c) { return pyRound(c / l * 126); });
		var col = st.colour ? st.colour(rnd, i) : trunc(6 + 9 * Math.pow(rnd.random(), 2));
		out.push(v[0] & 255, v[1] & 255, v[2] & 255, col);
	}
	return out;
}

// a 5 x 7 font (in 6 x 8 cells): ASCII 32 - 95, the ones drawn
var FONT = {
	' ': ['     ', '     ', '     ', '     ', '     ', '     ', '     '],
	'0': [' ### ', '#   #', '#  ##', '# # #', '##  #', '#   #', ' ### '],
	'1': ['  #  ', ' ##  ', '  #  ', '  #  ', '  #  ', '  #  ', ' ### '],
	'2': [' ### ', '#   #', '    #', '   # ', '  #  ', ' #   ', '#####'],
	'3': ['#####', '   # ', '  #  ', '   # ', '    #', '#   #', ' ### '],
	'4': ['   # ', '  ## ', ' # # ', '#  # ', '#####', '   # ', '   # '],
	'5': ['#####', '#    ', '#### ', '    #', '    #', '#   #', ' ### '],
	'6': ['  ## ', ' #   ', '#    ', '#### ', '#   #', '#   #', ' ### '],
	'7': ['#####', '    #', '   # ', '  #  ', ' #   ', ' #   ', ' #   '],
	'8': [' ### ', '#   #', '#   #', ' ### ', '#   #', '#   #', ' ### '],
	'9': [' ### ', '#   #', '#   #', ' ####', '    #', '   # ', ' ##  '],
	'A': [' ### ', '#   #', '#   #', '#####', '#   #', '#   #', '#   #'],
	'B': ['#### ', '#   #', '#   #', '#### ', '#   #', '#   #', '#### '],
	'C': [' ### ', '#   #', '#    ', '#    ', '#    ', '#   #', ' ### '],
	'D': ['#### ', '#   #', '#   #', '#   #', '#   #', '#   #', '#### '],
	'E': ['#####', '#    ', '#    ', '#### ', '#    ', '#    ', '#####'],
	'F': ['#####', '#    ', '#    ', '#### ', '#    ', '#    ', '#    '],
	'G': [' ### ', '#   #', '#    ', '# ###', '#   #', '#   #', ' ####'],
	'H': ['#   #', '#   #', '#   #', '#####', '#   #', '#   #', '#   #'],
	'I': [' ### ', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', ' ### '],
	'J': ['  ###', '   # ', '   # ', '   # ', '   # ', '#  # ', ' ##  '],
	'K': ['#   #', '#  # ', '# #  ', '##   ', '# #  ', '#  # ', '#   #'],
	'L': ['#    ', '#    ', '#    ', '#    ', '#    ', '#    ', '#####'],
	'M': ['#   #', '## ##', '# # #', '# # #', '#   #', '#   #', '#   #'],
	'N': ['#   #', '#   #', '##  #', '# # #', '#  ##', '#   #', '#   #'],
	'O': [' ### ', '#   #', '#   #', '#   #', '#   #', '#   #', ' ### '],
	'P': ['#### ', '#   #', '#   #', '#### ', '#    ', '#    ', '#    '],
	'Q': [' ### ', '#   #', '#   #', '#   #', '# # #', '#  # ', ' ## #'],
	'R': ['#### ', '#   #', '#   #', '#### ', '# #  ', '#  # ', '#   #'],
	'S': [' ####', '#    ', '#    ', ' ### ', '    #', '    #', '#### '],
	'T': ['#####', '  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '  #  '],
	'U': ['#   #', '#   #', '#   #', '#   #', '#   #', '#   #', ' ### '],
	'V': ['#   #', '#   #', '#   #', '#   #', '#   #', ' # # ', '  #  '],
	'W': ['#   #', '#   #', '#   #', '# # #', '# # #', '# # #', ' # # '],
	'X': ['#   #', '#   #', ' # # ', '  #  ', ' # # ', '#   #', '#   #'],
	'Y': ['#   #', '#   #', ' # # ', '  #  ', '  #  ', '  #  ', '  #  '],
	'Z': ['#####', '    #', '   # ', '  #  ', ' #   ', '#    ', '#####'],
	'-': ['     ', '     ', '     ', '#####', '     ', '     ', '     '],
	'.': ['     ', '     ', '     ', '     ', '     ', ' ##  ', ' ##  '],
	':': ['     ', ' ##  ', ' ##  ', '     ', ' ##  ', ' ##  ', '     '],
	'/': ['    #', '    #', '   # ', '  #  ', ' #   ', '#    ', '#    '],
	'%': ['##   ', '##  #', '   # ', '  #  ', ' #   ', '#  ##', '   ##'],
	'!': ['  #  ', '  #  ', '  #  ', '  #  ', '  #  ', '     ', '  #  '],
	',': ['     ', '     ', '     ', '     ', ' ##  ', '  #  ', ' #   '],
	"'": ['  #  ', '  #  ', ' #   ', '     ', '     ', '     ', '     '],
	'<': ['   # ', '  #  ', ' #   ', '#    ', ' #   ', '  #  ', '   # '],
	'>': [' #   ', '  #  ', '   # ', '    #', '   # ', '  #  ', ' #   '],
	'=': ['     ', '     ', '#####', '     ', '#####', '     ', '     '],
	'?': [' ### ', '#   #', '    #', '   # ', '  #  ', '     ', '  #  '],
	'(': ['   # ', '  #  ', ' #   ', ' #   ', ' #   ', '  #  ', '   # '],
	')': [' #   ', '  #  ', '   # ', '   # ', '   # ', '  #  ', ' #   '],
	'+': ['     ', '  #  ', '  #  ', '#####', '  #  ', '  #  ', '     ']
};
var FONT_CHARS = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-.:/%!,'<>=?()+";
function font()
{
	var out = [];
	FONT_CHARS.split('').forEach(function(ch)
	{
		FONT[ch].forEach(function(row) { var b = 0; for (var i = 0; i < row.length; i++) if (row[i] === '#') b |= 0x80 >> i; out.push(b); });
	});
	return out;
}
function fontIndex()
{
	var o = [];
	for (var c = 32; c < 96; c++) { var i = FONT_CHARS.indexOf(String.fromCharCode(c)); o.push(i < 0 ? 0 : i); }
	return o;
}

// (NEW) the text pages: [page: [x (under 0: in the middle), y, ink (the ULA's: ink + 8 x paper),   // <--- NEW (to texts' end)
// 'TEXT'], ...] -> a table of the pages' addresses (at base), then each page's lines: x, y, ink, the
// characters, 0; 255 after its last. Checked: the font's characters only, all on the screen
function texts(pages, base)
{
	var body = [], ptr = [];
	pages.forEach(function(pg, n)
	{
		ptr.push(base + pages.length * 2 + body.length);
		pg.forEach(function(ln)
		{
			var t = String(ln[3]), x = ln[0] < 0 ? 128 - t.length * 3 : ln[0], y = ln[1];
			if (x < 0 || x + t.length * 6 > 256 || y < 0 || y + 7 > 192) throw new Error('texts page ' + n + ': off the screen: ' + t);
			body.push(x, y, ln[2]);
			t.split('').forEach(function(ch) { var c = ch.charCodeAt(0); if (c < 32 || c > 95) throw new Error('texts: no ' + ch + ' in the font: ' + t); body.push(c); });
			body.push(0);
		});
		body.push(255);
	});
	var out = [];
	ptr.forEach(function(a) { out.push(a & 255, a >> 8); });
	return out.concat(body);
}

// ---------------------------------------------------------------- the files
function build(def, dir, name)
{
	var kinds = def.kinds, models = [];
	kinds.forEach(function(k) { [k.near, k.far].forEach(function(m) { if (models.indexOf(m) < 0) models.push(m); }); });
	var nstars = (def.stars && def.stars.n) || 96;
	var L = ["' E3Data - " + name + "'s tables and models, made by NTC3D's tools/e3models.js from its model file:",
		"' don't edit, run that. (c) 2026 Cyborg Unicorn Pty Ltd",
		'Option Explicit', '',
		'Public Const NStars = ' + nstars];
	kinds.forEach(function(k, i) { L.push('Public Const K_' + k.name + ' = ' + i); });
	L.push('');
	function block(fname, data, comment)
	{
		var lo = fname.toLowerCase();
		L.push("' " + comment, 'Public Function ' + fname + '() As Integer', '#asm',
			'            pop hl', '            ld de, ' + lo + '_d', '            ld (hl), e', '            inc hl', '            ld (hl), d',
			'            jp ' + lo + '_e', lo + '_d:');
		for (var i = 0; i < data.length; i += 16) L.push('            db ' + data.slice(i, i + 16).join(', '));
		L.push(lo + '_e:', '#endasm', 'End Function', '');
	}
	block('Sines', sines(), 'Sines(): 256 signed bytes, x 127');
	block('REdge', recipEdge(), 'REdge(): 65536 / dy, dy 0-255');   // <--- CHANGED
	block('Font', font(), 'Font(): the font, 5 x 7 (7 bytes a character)');
	block('FontIx', fontIndex(), "FontIx(): ASCII 32..95 to the font's characters");
	var allm = [], offs = [];
	models.forEach(function(m)                                                      // <--- CHANGED (compounds: a header, then their views)
	{
		if (!(m instanceof Compound) || m.views === 1)
		{
			offs.push(allm.length);
			allm = allm.concat((m instanceof Compound ? m.variants[0] : m).bytes());
			return;
		}
		var at = allm.length, hdr = [255, m.views], vo = [];
		allm = allm.concat(hdr, m.variants.map(function() { return [0, 0]; }).reduce(function(a, b) { return a.concat(b); }, []));
		m.variants.forEach(function(v, i) { vo.push(allm.length); allm = allm.concat(v.bytes()); allm[at + 2 + i * 2] = vo[i] & 255; allm[at + 3 + i * 2] = vo[i] >> 8; });
		offs.push(at);
	});
	var tab = [], hits = [];
	kinds.forEach(function(k)
	{
		var a = offs[models.indexOf(k.near)], b = offs[models.indexOf(k.far)];
		tab.push(a & 255, a >> 8, b & 255, b >> 8);
		var h = k.hit;
		if (!h)
		{
			var ax = 0, ay = 0;
			k.near.verts.forEach(function(v) { ax = Math.max(ax, Math.abs(v[0]), Math.abs(v[2])); ay = Math.max(ay, Math.abs(v[1])); });
			h = [ax, ay];
		}
		hits.push(Math.min(255, h[0]), Math.min(255, h[1]));
	});
	var parts = [['rproj', recipProj()], ['pal', palette(def.ramps)], ['stars', stars(def.stars)], ['modeltab', tab], ['hittab', hits], ['modeldata', allm]];
	if (def.skyline) parts.push(['skyline', def.skyline.reduce(function(a, r) { r.forEach(function(w) { a.push(w & 255, (w >> 8) & 255); }); return a; }, [])]);   // <--- NEW (E3.Skyline's table: E3Data.SkyAt)
	if (def.texts) parts.push(['texts', null]);                                    // <--- NEW (text pages: E3.Texts)
	var dat = Buffer.alloc(16384), at = 0, where = {};
	parts.forEach(function(p)
	{
		if (p[0] === 'texts')                                                       // <--- NEW: from #E000 on (E3.Texts reads them
		{                                                                           // <--- NEW  with the ULA's screen in slot 6)
			at = Math.max(at, 0x2000);                                              // <--- NEW
			p[1] = texts(def.texts, 0xC000 + at);                                   // <--- NEW
		}                                                                           // <--- NEW
		where[p[0]] = 0xC000 + at;
		for (var i = 0; i < p[1].length; i++) dat[at + i] = p[1][i];
		at += p[1].length;
		at = (at + 15) & ~15;
	});
	if (at > 16384) throw new Error('the data block is ' + at + ' bytes: over 16384');
	var bdir = path.join(dir, 'build');
	if (!fs.existsSync(bdir)) fs.mkdirSync(bdir);
	fs.writeFileSync(path.join(bdir, name + '.DAT'), dat);
	L.push("' DatAt(): where the data block's tables are, at #C000 on (its bank in slots 6 and 7): the",
		"' projection's reciprocals (2^24 / n, n 256-4095), the palette, the stars, the model table (near",
		"' and far models' offsets), the hit table (across, up), the models",
		'Public Function DatAt() As Integer', '#asm', '            pop hl', '            ld (hl), 0', '            inc hl',
		'            ld (hl), #C0', '            jp dat_e');
	parts.forEach(function(p) { L.push('@d_' + p[0] + ':     equ #' + where[p[0]].toString(16).toUpperCase()); });
	if (!def.texts) L.push('@d_texts:     equ 0');                                // <--- NEW (no text pages: E3.Texts not to be used, but E3 still assembles)
	L.push('dat_e:', '#endasm', 'End Function', '');
	L.splice(5, 0, 'Public Const PalAt = &H' + where.pal.toString(16).toUpperCase(), 'Public Const DatUsed = ' + at);
	if (def.skyline) L.splice(5, 0, 'Public Const SkyAt = &H' + where.skyline.toString(16).toUpperCase() + ', NSky = ' + def.skyline.length + "   ' (NEW: the skyline's table in the data block)");   // <--- NEW
	// (NEW) the most points in a model and in a face: the build sizes E3's buffers by them (prep.js)   // <--- NEW
	var mv = 0, mf = 0;                                                                                    // <--- NEW
	models.forEach(function(m) { mv = Math.max(mv, m.verts.length); m.faces.forEach(function(f) { mf = Math.max(mf, f.idx.length); }); });   // <--- NEW
	L.splice(7, 0, 'Public Const MaxV = ' + mv + ', MaxFV = ' + mf + "   ' (the build sizes E3's vertex buffers by these)");   // <--- NEW
	fs.writeFileSync(path.join(dir, 'E3Data.cls'), L.join('\n') + '\n');
	console.log('E3Data.cls, build/' + name + '.DAT (' + at + ' of 16384 bytes used): ' + kinds.length + ' kinds, ' + models.length + ' models, ' + allm.length + ' bytes of models');
	models.forEach(function(m) { console.log('  ' + (m.name + '            ').slice(0, 12) + m.verts.length + ' points ' + m.faces.length + ' faces ' + (m instanceof Compound ? m.variants[0].bytes().length * m.views + ' bytes (' + m.parts.length + ' parts, ' + m.views + ' view' + (m.views > 1 ? 's' : '') + ')' : m.bytes().length + ' bytes')); });   // <--- CHANGED
	return { models: models, kinds: kinds };
}

// ---------------------------------------------------------------- the picture (PNG)
function crcTable() { var t = [], c, n, k; for (n = 0; n < 256; n++) { c = n; for (k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1); t.push(c >>> 0); } return t; }
var CRC = crcTable();
function crc(buf) { var c = 0xFFFFFFFF; for (var i = 0; i < buf.length; i++) c = CRC[(c ^ buf[i]) & 255] ^ (c >>> 8); return (c ^ 0xFFFFFFFF) >>> 0; }
function chunk(type, data)
{
	var len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
	var td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
	var c = Buffer.alloc(4); c.writeUInt32BE(crc(td), 0);
	return Buffer.concat([len, td, c]);
}
function png(w, h, rgb)
{
	var raw = Buffer.alloc((w * 3 + 1) * h);
	for (var y = 0; y < h; y++) { raw[y * (w * 3 + 1)] = 0; rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3); }
	var ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 2; ih[10] = 0; ih[11] = 0; ih[12] = 0;
	return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
// each kind's near model seen from ahead, above and to one side, its faces lit as E3 lights them
function picture(res, ramps, file)
{
	var kinds = res.kinds, cell = 128, cols = 5, rows = Math.ceil(kinds.length / cols);
	var W = cols * cell, H = rows * (cell + 12), img = Buffer.alloc(W * H * 3);
	var sun = norm([-0.4, 0.75, -0.55]);
	var ca = Math.cos(2.5), sa = Math.sin(2.5), cb = Math.cos(-0.5), sb = Math.sin(-0.5);
	function view(v) { var x = v[0] * ca + v[2] * sa, z = -v[0] * sa + v[2] * ca, y = v[1]; return [x, y * cb - z * sb, y * sb + z * cb]; }
	function put(x, y, c) { if (x < 0 || y < 0 || x >= W || y >= H) return; var o = (y * W + x) * 3; img[o] = c[0]; img[o + 1] = c[1]; img[o + 2] = c[2]; }
	kinds.forEach(function(k, i)
	{
		var ox = (i % cols) * cell + cell / 2, oy = Math.floor(i / cols) * (cell + 12) + cell / 2 + 2;
		var m = k.near;
		if (m instanceof Compound) m = m.forEye([3000 * Math.cos(0.5) * Math.sin(2.5), 3000 * Math.sin(0.5), -3000 * Math.cos(0.5) * Math.cos(2.5)], m.name);   // <--- NEW (its order for the picture's eye)
		var vs = m.verts.map(view);
		m.faces.forEach(function(f)
		{
			var n = view(f.n);
			if (n[2] > -0.02 && m.faces.length > 1) return;          // turned away (we look along +z)
			var lit = Math.max(0, dot(f.n, sun)), c = rgbOf(ramps, f.ramp * 16 + Math.min(15, 4 + Math.round(11 * lit)));
			var pts = f.idx.map(function(q) { return [ox + vs[q][0] * 0.42, oy - vs[q][1] * 0.42]; });
			var y0 = Math.floor(Math.min.apply(null, pts.map(function(p) { return p[1]; }))), y1 = Math.ceil(Math.max.apply(null, pts.map(function(p) { return p[1]; })));
			for (var y = y0; y <= y1; y++)
			{
				var xs = [];
				for (var e = 0; e < pts.length; e++)
				{
					var a = pts[e], b = pts[(e + 1) % pts.length];
					if ((a[1] <= y + 0.5 && b[1] > y + 0.5) || (b[1] <= y + 0.5 && a[1] > y + 0.5)) xs.push(a[0] + (y + 0.5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1]));
				}
				xs.sort(function(p, q) { return p - q; });
				for (var s = 0; s + 1 < xs.length; s += 2) for (var x = Math.round(xs[s]); x < Math.round(xs[s + 1]); x++) put(x, y, c);
			}
		});
		// its name under it, in the font
		var nm = k.name, fx = ox - nm.length * 3, fy = Math.floor(i / cols) * (cell + 12) + cell + 2;
		nm.split('').forEach(function(ch, j)
		{
			(FONT[ch] || FONT[' ']).forEach(function(row, r) { for (var b = 0; b < 5; b++) if (row[b] === '#') put(fx + j * 6 + b, fy + r, [200, 200, 200]); });
		});
	});
	fs.writeFileSync(file, png(W, H, img));
	console.log(file + ': a picture of the ' + kinds.length + ' kinds');
}

if (require.main === module)
{
	var args = process.argv.slice(2), file = null, dir = null, name = null, pic = null;
	for (var i = 0; i < args.length; i++)
	{
		if (args[i] === '--name') name = args[++i];
		else if (args[i] === '--png') pic = args[++i];
		else if (!file) file = args[i];
		else dir = args[i];
	}
	if (!file) { console.log('node e3models.js models.js [game folder] [--name NAME] [--png pictures.png]'); process.exit(1); }
	file = path.resolve(file);
	dir = path.resolve(dir || path.dirname(file));
	if (!name)
	{
		var gj = path.join(dir, 'game.json');
		name = fs.existsSync(gj) ? JSON.parse(fs.readFileSync(gj, 'utf8')).name : 'DATA';
	}
	var def = require(file)(M);
	var res = build(def, dir, name);
	if (pic) picture(res, def.ramps, path.resolve(pic));
}
module.exports = { M: M, build: build, picture: picture, PyRandom: PyRandom };

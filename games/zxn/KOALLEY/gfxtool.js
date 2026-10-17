// gfxtool.js - the graphics of an NTC BASIC Next game: PNG sheets in, GfxData.cls out
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
// Swap the art without touching the game: edit the PNGs in gfx/ (or draw new ones of the same
// layout), run
//
//   node gfxtool.js build            gfx/ -> GfxData.cls
//   node gfxtool.js build DIR OUT    another folder / output file
//   node gfxtool.js info [DIR]       what the sheets hold: cells used, colours, sizes
//   node gfxtool.js grid [DIR]       gfx/*_grid.png: the sheets with the cell grid and the
//                                    layout's names marked (a guide for drawing - not read back)
//
// and build the game again. The game only uses the names in layout.txt (GfxData.S_PLAYER ...),
// so new art in the same cells (or moved cells with layout.txt changed to match) needs no change
// to the BASIC.
//
// The files in the folder:
//   tile_pal.png    16 x 1 pixels: the tilemap's 16 colours. Colour 15 is transparent (drawn
//                   magenta here; what is under the tilemap shows through)
//   tiles.png       128 pixels wide, 8 x 8 cells, 16 a row: cell n is tile n (row * 16 + column).
//                   Up to 16 rows (256 tiles). Cells 32-126 are the font: Print draws them (the
//                   character's code is its tile). Every pixel must be one of tile_pal's colours
//                   (the nearest is taken); magenta or see-through pixels are colour 15
//   spr_pal.png     16 x N pixels: the sprites' palettes. Row 0 is the one the sheet is drawn in;
//                   rows 1 .. N-1 are other colourings of the same 16 (a game picks one with a
//                   palette offset - player 2's colours, a flashing enemy). Colour 15 transparent
//   sprites.png     256 pixels wide, 16 x 16 cells, 16 a row, drawn in spr_pal's row 0 colours
//   layout.txt      names for cells (only the sprite cells named here are put in the game):
//                     tile   NAME  index [count]
//                     sprite NAME  col row [frames [w h]]
//                   a sprite entry is `frames` pictures side by side starting at cell (col, row),
//                   each w x h cells (default 1 x 1); its patterns are numbered in the order of
//                   the file, each picture's cells row by row. GfxData gets Public Consts:
//                   T_NAME (the tile), S_NAME (the first pattern), S_NAME_N (frames),
//                   S_NAME_W / S_NAME_H (cells across / down, when bigger than 1)
//
// GfxData.Load (run it once, after Tiles.Init / Spr.Init) puts the palettes in the Next's
// tilemap and sprite palettes, the tiles at bank 5 + #0000 (#C000, where Tiles.Init points the
// tilemap's tile definitions) and the sprite patterns (4 bit, 128 bytes each) in the sprite RAM.
'use strict';
var fs = require('fs');
var path = require('path');
var zlib = require('zlib');

// ---------------------------------------------------------------- PNG in / out
function crc32(buf)
{
	var c, n, k, t = crc32.t;
	if (!t)
	{
		t = crc32.t = [];
		for (n = 0; n < 256; n++)
		{
			c = n;
			for (k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
			t[n] = c >>> 0;
		}
	}
	c = 0xFFFFFFFF;
	for (n = 0; n < buf.length; n++) c = t[(c ^ buf[n]) & 255] ^ (c >>> 8);
	return (c ^ 0xFFFFFFFF) >>> 0;
}

function readPng(file)
{
	var d = fs.readFileSync(file);
	var sig = [137, 80, 78, 71, 13, 10, 26, 10], i;
	for (i = 0; i < 8; i++) if (d[i] !== sig[i]) throw new Error(file + ': not a PNG');
	var o = 8, w = 0, h = 0, depth = 0, ctype = 0, inter = 0, plte = null, trns = null, idat = [];
	while (o < d.length)
	{
		var len = d.readUInt32BE(o), type = d.toString('ascii', o + 4, o + 8), body = d.slice(o + 8, o + 8 + len);
		if (type === 'IHDR') { w = body.readUInt32BE(0); h = body.readUInt32BE(4); depth = body[8]; ctype = body[9]; inter = body[12]; }
		else if (type === 'PLTE') plte = body;
		else if (type === 'tRNS') trns = body;
		else if (type === 'IDAT') idat.push(body);
		else if (type === 'IEND') break;
		o += 12 + len;
	}
	if (inter) throw new Error(file + ': interlaced PNGs are not read - save it without interlacing');
	var chans = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[ctype];
	if (!chans) throw new Error(file + ': PNG colour type ' + ctype + ' not read');
	if (depth === 16) throw new Error(file + ': 16 bit PNGs are not read - save it as 8 bit');
	var raw = zlib.inflateSync(Buffer.concat(idat));
	var bpp = Math.max(1, (chans * depth) >> 3), stride = (w * chans * depth + 7) >> 3;
	var out = Buffer.alloc(w * h * 4), prev = Buffer.alloc(stride), cur, y, x, p = 0;
	for (y = 0; y < h; y++)
	{
		var f = raw[p++];
		cur = Buffer.from(raw.slice(p, p + stride)); p += stride;
		for (x = 0; x < stride; x++)
		{
			var a = x >= bpp ? cur[x - bpp] : 0, b = prev[x], c = x >= bpp ? prev[x - bpp] : 0, v = cur[x];
			if (f === 1) v += a;
			else if (f === 2) v += b;
			else if (f === 3) v += (a + b) >> 1;
			else if (f === 4) { var pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); }
			cur[x] = v & 255;
		}
		for (x = 0; x < w; x++)
		{
			var r, g, bl, al = 255, s;
			if (depth < 8)
			{
				var bit = x * depth, byte = cur[bit >> 3];
				s = (byte >> (8 - depth - (bit & 7))) & ((1 << depth) - 1);
				if (ctype === 3) { r = plte[s * 3]; g = plte[s * 3 + 1]; bl = plte[s * 3 + 2]; if (trns && s < trns.length) al = trns[s]; }
				else { r = g = bl = Math.round(s * 255 / ((1 << depth) - 1)); }
			}
			else
			{
				s = x * chans;
				if (ctype === 3) { var ix = cur[s]; r = plte[ix * 3]; g = plte[ix * 3 + 1]; bl = plte[ix * 3 + 2]; if (trns && ix < trns.length) al = trns[ix]; }
				else if (ctype === 0) { r = g = bl = cur[s]; }
				else if (ctype === 4) { r = g = bl = cur[s]; al = cur[s + 1]; }
				else if (ctype === 2) { r = cur[s]; g = cur[s + 1]; bl = cur[s + 2]; }
				else { r = cur[s]; g = cur[s + 1]; bl = cur[s + 2]; al = cur[s + 3]; }
			}
			var q = (y * w + x) * 4;
			out[q] = r; out[q + 1] = g; out[q + 2] = bl; out[q + 3] = al;
		}
		prev = cur;
	}
	return { w: w, h: h, px: out };
}

function writePng(file, w, h, px)
{
	var raw = Buffer.alloc((w * 4 + 1) * h), y;
	for (y = 0; y < h; y++)
	{
		raw[y * (w * 4 + 1)] = 0;
		px.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
	}
	function chunk(type, body)
	{
		var b = Buffer.alloc(12 + body.length);
		b.writeUInt32BE(body.length, 0); b.write(type, 4, 'ascii'); body.copy(b, 8);
		b.writeUInt32BE(crc32(b.slice(4, 8 + body.length)), 8 + body.length);
		return b;
	}
	var ih = Buffer.alloc(13);
	ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 6; ih[10] = 0; ih[11] = 0; ih[12] = 0;
	fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}

// ---------------------------------------------------------------- colours
// the Next's 8 bit colour: RRRGGGBB
function to332(r, g, b) { return (Math.round(r * 7 / 255) << 5) | (Math.round(g * 7 / 255) << 2) | Math.round(b * 3 / 255); }
function isClear(px, q) { return px[q + 3] < 128 || (px[q] === 255 && px[q + 1] === 0 && px[q + 2] === 255); }

function readPalette(file, rows)
{
	var img = readPng(file), pals = [], y, x;
	if (img.w < 16) throw new Error(file + ': must be 16 pixels wide');
	for (y = 0; y < Math.min(img.h, rows || 16); y++)
	{
		var p = [];
		for (x = 0; x < 16; x++)
		{
			var q = (y * img.w + x) * 4;
			p.push({ r: img.px[q], g: img.px[q + 1], b: img.px[q + 2], clear: x === 15 || isClear(img.px, q) });
		}
		pals.push(p);
	}
	return pals;
}

// a pixel -> palette index (15 = transparent): the nearest colour of pal (0-14)
function nearest(pal, px, q)
{
	if (isClear(px, q)) return 15;
	var best = 0, bd = 1e9, i;
	for (i = 0; i < 15; i++)
	{
		var dr = pal[i].r - px[q], dg = pal[i].g - px[q + 1], db = pal[i].b - px[q + 2];
		var dd = dr * dr * 3 + dg * dg * 4 + db * db * 2;
		if (dd < bd) { bd = dd; best = i; }
	}
	return best;
}

// ---------------------------------------------------------------- layout.txt
function readLayout(file)
{
	var tiles = [], sprites = [];
	fs.readFileSync(file, 'utf8').split(/\r?\n/).forEach(function(line, n)
	{
		line = line.replace(/[#'].*$/, '').trim();
		if (!line) return;
		var w = line.split(/\s+/);
		var kind = w[0].toLowerCase();
		if (!/^[A-Za-z_]\w*$/.test(w[1] || '')) throw new Error(file + ' line ' + (n + 1) + ': a name expected');
		if (kind === 'tile') tiles.push({ name: w[1].toUpperCase(), index: +w[2], count: +(w[3] || 1) });
		else if (kind === 'sprite') sprites.push({ name: w[1].toUpperCase(), col: +w[2], row: +w[3], frames: +(w[4] || 1), w: +(w[5] || 1), h: +(w[6] || 1), line: n + 1 });
		else throw new Error(file + ' line ' + (n + 1) + ': tile or sprite expected');
	});
	return { tiles: tiles, sprites: sprites };
}

// ---------------------------------------------------------------- the sheets
function load(dir)
{
	var tpal = readPalette(path.join(dir, 'tile_pal.png'), 1)[0];
	var spal = readPalette(path.join(dir, 'spr_pal.png'));
	var tiles = readPng(path.join(dir, 'tiles.png'));
	var sprites = readPng(path.join(dir, 'sprites.png'));
	var layout = readLayout(path.join(dir, 'layout.txt'));
	if (tiles.w !== 128 || tiles.h % 8 || tiles.h > 128) throw new Error('tiles.png must be 128 pixels wide and 8 to 128 high (a multiple of 8)');
	if (sprites.w !== 256 || sprites.h % 16) throw new Error('sprites.png must be 256 pixels wide, a multiple of 16 high');
	// tiles: 32 bytes each, 4 bits a pixel, the left pixel in the high nibble
	var ntiles = (tiles.h / 8) * 16, tdefs = [], t, y, x;
	for (t = 0; t < ntiles; t++)
	{
		var def = [], empty = true, cx = (t % 16) * 8, cy = (t >> 4) * 8;
		for (y = 0; y < 8; y++)
			for (x = 0; x < 8; x += 2)
			{
				var a = nearest(tpal, tiles.px, ((cy + y) * 128 + cx + x) * 4), b = nearest(tpal, tiles.px, ((cy + y) * 128 + cx + x + 1) * 4);
				if (a !== 15 || b !== 15) empty = false;
				def.push((a << 4) | b);
			}
		tdefs.push(empty ? null : def);
	}
	// sprites: the layout's cells, in order, 128 bytes each
	var pats = [], consts = [];
	layout.sprites.forEach(function(s)
	{
		var first = pats.length, f, j, i;
		for (f = 0; f < s.frames; f++)
			for (j = 0; j < s.h; j++)
				for (i = 0; i < s.w; i++)
				{
					var col = s.col + f * s.w + i, row = s.row + j;
					if (col > 15 || (row + 1) * 16 > sprites.h) throw new Error('layout.txt line ' + s.line + ': ' + s.name + ' reaches cell ' + col + ', ' + row + ' - off the sheet');
					var pat = [];
					for (y = 0; y < 16; y++)
						for (x = 0; x < 16; x += 2)
						{
							var q = ((row * 16 + y) * 256 + col * 16 + x) * 4;
							pat.push((nearest(spal[0], sprites.px, q) << 4) | nearest(spal[0], sprites.px, q + 4));
						}
					pats.push(pat);
				}
		consts.push(['S_' + s.name, first]);
		consts.push(['S_' + s.name + '_N', s.frames]);
		if (s.w > 1) consts.push(['S_' + s.name + '_W', s.w]);
		if (s.h > 1) consts.push(['S_' + s.name + '_H', s.h]);
	});
	if (pats.length > 128) throw new Error('layout.txt names ' + pats.length + ' sprite patterns: the Next holds 128 (4 bit)');
	layout.tiles.forEach(function(t2)
	{
		consts.push(['T_' + t2.name, t2.index]);
		if (t2.count > 1) consts.push(['T_' + t2.name + '_N', t2.count]);
	});
	return { tpal: tpal, spal: spal, tdefs: tdefs, pats: pats, consts: consts, layout: layout, tiles: tiles, sprites: sprites };
}

function hex(n) { return '#' + ('0' + n.toString(16).toUpperCase()).slice(-2); }
function dbLines(bytes, per)
{
	var out = [], i;
	for (i = 0; i < bytes.length; i += per) out.push('            db ' + bytes.slice(i, i + per).map(hex).join(', '));
	return out;
}

function build(dir, outFile)
{
	var g = load(dir), L = [], i;
	L.push("' GfxData - the game's graphics, made by gfxtool.js from " + path.basename(path.resolve(dir)) + "/*.png and layout.txt.");
	L.push("' Don't edit: change the PNGs and run  node gfxtool.js build");
	L.push("' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at");
	L.push("' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).");
	L.push('Option Explicit');
	L.push('');
	g.consts.forEach(function(c) { L.push('Public Const ' + c[0] + ' = ' + c[1]); });
	L.push('Public Const SpritePatterns = ' + g.pats.length);
	L.push('Public Const SpritePalettes = ' + g.spal.length);
	L.push('');
	// tile runs: consecutive tiles that aren't empty
	var runs = [], cur = null;
	g.tdefs.forEach(function(d, t)
	{
		if (d) { if (cur && cur.first + cur.n === t && cur.n < 255) cur.n++; else { cur = { first: t, n: 1 }; runs.push(cur); } }
	});
	L.push('Private sps As Integer');
	L.push('');
	L.push('Public Sub Load()');
	L.push('#asm');
	L.push('            ld ({sps}), sp          ; the real stack (calls)');
	L.push('            ld sp, (ntc_csp)');
	L.push('            ld bc, #243B');
	L.push('            ld a, #43               ; palette control: the tilemap\'s first palette');
	L.push('            out (c), a');
	L.push('            inc b');
	L.push('            ld a, #30');
	L.push('            out (c), a');
	L.push('            dec b');
	L.push('            ld hl, tpal');
	L.push('            ld e, 16');
	L.push('            call palset');
	L.push('            ld a, #43               ; the sprites\' first palette');
	L.push('            out (c), a');
	L.push('            inc b');
	L.push('            ld a, #20');
	L.push('            out (c), a');
	L.push('            dec b');
	L.push('            ld hl, spal');
	L.push('            ld e, ' + (g.spal.length * 16 & 255) + '                ; ' + g.spal.length + ' x 16 (0 = 256)');
	L.push('            call palset');
	L.push('            ld a, #43               ; back to the ULA\'s, first palettes in use');
	L.push('            out (c), a');
	L.push('            inc b');
	L.push('            xor a');
	L.push('            out (c), a');
	L.push('            ld hl, #C000            ; every tile transparent (colour 15) first');
	L.push('            ld de, #C001');
	L.push('            ld bc, #1FFF');
	L.push('            ld (hl), #FF');
	L.push('            ldir');
	L.push('            ld hl, truns');
	L.push('ld_run:');
	L.push('            ld a, (hl)              ; a run: first tile, count (0, 0 = the end), its definitions');
	L.push('            inc hl');
	L.push('            ld c, (hl)');
	L.push('            inc hl');
	L.push('            ld b, a');
	L.push('            or c');
	L.push('            jr z, ld_spr');
	L.push('            ld a, b');
	L.push('            ld e, a                 ; DE = #C000 + first * 32');
	L.push('            ld d, 0');
	L.push('            ex de, hl');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            ld a, h');
	L.push('            add a, #C0');
	L.push('            ld h, a');
	L.push('            ex de, hl');
	L.push('            ld a, c                 ; BC = count * 32 (count 1 - 255: tile 0 run of 0 not used)');
	L.push('            ld b, 0');
	L.push('            ld c, a');
	L.push('            push hl');
	L.push('            ld h, b');
	L.push('            ld l, c');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            add hl, hl');
	L.push('            ld b, h');
	L.push('            ld c, l');
	L.push('            pop hl');
	L.push('            ldir');
	L.push('            jr ld_run');
	L.push('ld_spr:');
	L.push('            ld bc, #303B            ; sprite patterns from pattern 0');
	L.push('            xor a');
	L.push('            out (c), a');
	L.push('            ld hl, pats');
	L.push('            ld de, ' + (g.pats.length * 128));
	L.push('            ld c, #5B');
	L.push('ld_pat:');
	L.push('            ld a, d');
	L.push('            or e');
	L.push('            jr z, ld_done');
	L.push('            ld a, (hl)');
	L.push('            out (c), a');
	L.push('            inc hl');
	L.push('            dec de');
	L.push('            jr ld_pat');
	L.push('ld_done:');
	L.push('            ld sp, ({sps})');
	L.push('            jp ld_end');
	L.push('; palset - E colours (0 = 256) from HL into the palette chosen, from index 0 (BC = #243B)');
	L.push('palset:');
	L.push('            ld a, #40');
	L.push('            out (c), a');
	L.push('            inc b');
	L.push('            xor a');
	L.push('            out (c), a');
	L.push('            dec b');
	L.push('ps_lp:');
	L.push('            ld a, #41');
	L.push('            out (c), a');
	L.push('            inc b');
	L.push('            ld a, (hl)');
	L.push('            out (c), a');
	L.push('            dec b');
	L.push('            inc hl');
	L.push('            dec e');
	L.push('            jr nz, ps_lp');
	L.push('            ret');
	L.push('tpal:');
	dbLines(g.tpal.map(function(c, i2) { return i2 === 15 ? 0xE3 : to332(c.r, c.g, c.b); }), 16).forEach(function(l) { L.push(l); });
	L.push('spal:');
	g.spal.forEach(function(p) { dbLines(p.map(function(c, i2) { return i2 === 15 ? 0xE3 : to332(c.r, c.g, c.b); }), 16).forEach(function(l) { L.push(l); }); });
	L.push('truns:');
	runs.forEach(function(r)
	{
		var k;
		L.push('            db ' + r.first + ', ' + r.n + '        ; tiles ' + r.first + '-' + (r.first + r.n - 1));
		for (k = 0; k < r.n; k++) dbLines(g.tdefs[r.first + k], 16).forEach(function(l) { L.push(l); });
	});
	L.push('            db 0, 0');
	L.push('pats:');
	g.pats.forEach(function(p) { dbLines(p, 16).forEach(function(l) { L.push(l); }); });
	L.push('ld_end:');
	L.push('#endasm');
	L.push('End Sub');
	L.push('');
	fs.writeFileSync(outFile, L.join('\r\n'));
	var tb = runs.reduce(function(s, r) { return s + 2 + r.n * 32; }, 2);
	console.log(outFile + ': ' + runs.reduce(function(s, r) { return s + r.n; }, 0) + ' tiles (' + tb + ' bytes), ' + g.pats.length + ' sprite patterns (' + g.pats.length * 128 + ' bytes), ' + g.spal.length + ' sprite palette(s)');
}

function info(dir)
{
	var g = load(dir);
	console.log('tiles.png: ' + g.tdefs.filter(function(d) { return d; }).length + ' of ' + g.tdefs.length + ' cells drawn');
	console.log('sprites.png: ' + (g.sprites.h / 16) * 16 + ' cells, ' + g.pats.length + ' patterns named in layout.txt (128 at most)');
	console.log('spr_pal.png: ' + g.spal.length + ' palette(s)');
	g.consts.forEach(function(c) { console.log('  ' + c[0] + ' = ' + c[1]); });
}

// the sheets scaled up with the grid and the names: a drawing guide
function grid(dir)
{
	var g = load(dir);
	function guide(img, cell, file, marks)
	{
		var S = 4, W = img.w * S, H = img.h * S, px = Buffer.alloc(W * H * 4), x, y;
		for (y = 0; y < H; y++)
			for (x = 0; x < W; x++)
			{
				var q = ((y / S | 0) * img.w + (x / S | 0)) * 4, o = (y * W + x) * 4;
				var clear = isClear(img.px, q), chk = ((x >> 3) + (y >> 3)) & 1;
				px[o] = clear ? (chk ? 60 : 40) : img.px[q]; px[o + 1] = clear ? (chk ? 60 : 40) : img.px[q + 1]; px[o + 2] = clear ? (chk ? 70 : 50) : img.px[q + 2]; px[o + 3] = 255;
				if (x % (cell * S) === 0 || y % (cell * S) === 0) { px[o] = 90; px[o + 1] = 90; px[o + 2] = 120; }
			}
		marks.forEach(function(m)
		{
			for (y = m.y * S; y < (m.y + m.h) * S; y++)
				for (x = m.x * S; x < (m.x + m.w) * S; x++)
					if (y === m.y * S || y === (m.y + m.h) * S - 1 || x === m.x * S || x === (m.x + m.w) * S - 1)
						if (x < W && y < H) { var o2 = (y * W + x) * 4; px[o2] = 255; px[o2 + 1] = 220; px[o2 + 2] = 0; }
		});
		writePng(file, W, H, px);
		console.log(file);
	}
	var sm = [];
	g.layout.sprites.forEach(function(s) { var f; for (f = 0; f < s.frames; f++) sm.push({ x: (s.col + f * s.w) * 16, y: s.row * 16, w: s.w * 16, h: s.h * 16 }); });
	var tm = [];
	g.layout.tiles.forEach(function(t) { var k; for (k = 0; k < t.count; k++) tm.push({ x: ((t.index + k) % 16) * 8, y: ((t.index + k) >> 4) * 8, w: 8, h: 8 }); });
	guide(g.sprites, 16, path.join(dir, 'sprites_grid.png'), sm);
	guide(g.tiles, 8, path.join(dir, 'tiles_grid.png'), tm);
}

var args = process.argv.slice(2);
var cmd = args[0] || 'build';
var here = __dirname;
var dir = args[1] || path.join(here, 'gfx');
try
{
	if (cmd === 'build') build(dir, args[2] || path.join(here, 'GfxData.cls'));
	else if (cmd === 'info') info(dir);
	else if (cmd === 'grid') grid(dir);
	else { console.log('node gfxtool.js build [dir] [out.cls] | info [dir] | grid [dir]'); process.exit(1); }
}
catch (e)
{
	console.error('gfxtool: ' + e.message);
	process.exit(1);
}

module.exports = { readPng: readPng, writePng: writePng };

// ngtiles.js - pictures to the Neo Geo's tiles, for NTC's neogeo platform (the Vdp class).
// (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node tools/neogeo/ngtiles.js --out=NAME [--first=1] [--order=rows|columns]
//        [--sprites=A.png,B.png,...] [--backdrop=P.png,Q.png,...] [--fix=F.png] [--fixfirst=256]
//
// Reads PNG files (8 bits a channel, or a palette; not interlaced) and writes:
//   NAME_C.BIN     the C ROM: 16 x 16 tiles of 16 colours (128 bytes each, C1 and C2 interleaved
//                  as a .neo cartridge holds them: test/ngbuild.js --crom). Tile 0 is clear; the
//                  first picture's tiles start at --first (1).
//   NAME_PAL.BIN   the palettes, 16 words each (the Neo Geo's colour words, high byte first: as
//                  Vdp.Colors takes them): one for each --sprites picture, in order, then 224 for
//                  each --backdrop picture (Vdp.Back's)
//   NAME_S.BIN     the S ROM (128K: --srom), with --fix: NTC's console font at tiles 32-126 and
//                  the picture's 8 x 8 tiles from --fixfirst (256) on; its palette (16 words) is
//                  NAME_FIX.BIN
//   NAME.txt       what is where: each picture's first tile, its tiles, its palette's offset
//
// --sprites: each picture is cut into 16 x 16 tiles, row by row (--order=columns: down each
//   column of tiles, then the next column - the order Vdp.Strip wants for a tall sprite). The
//   whole picture has one palette: up to 15 colours and the clear one. Clear is a pixel with
//   alpha under 128; a picture with no alpha: the colour of its top left pixel.
// --backdrop: a 256 x 192 picture as Vdp.Back wants it: four bands (lines 0-55, 56-111, 112-151,
//   152-191: 4, 4, 3 and 3 tiles down), 16 columns each, band b's column k's row r at tile
//   BOFF(b) + k * ROWS(b) + r (BOFF 0, 64, 128, 176): 224 tiles, each with a palette of its own
//   (its 15 most used colours; the rest go to the nearest of those).
// --fix: cut into 8 x 8 tiles, row by row; one palette for the picture, as --sprites.
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

function die(m) { console.error('ngtiles: ' + m); process.exit(1); }

// ---- PNG: { w, h, px: Uint8Array of r g b a }
function png(file) {
	const b = fs.readFileSync(file);
	if (b.readUInt32BE(0) !== 0x89504E47) die(file + ' is not a PNG');
	let p = 8, w = 0, h = 0, depth = 0, type = 0, lace = 0, pal = null, trns = null;
	const idat = [];
	while (p < b.length) {
		const n = b.readUInt32BE(p), t = b.toString('latin1', p + 4, p + 8), d = b.slice(p + 8, p + 8 + n);
		if (t === 'IHDR') { w = d.readUInt32BE(0); h = d.readUInt32BE(4); depth = d[8]; type = d[9]; lace = d[12]; }
		else if (t === 'PLTE') pal = d;
		else if (t === 'tRNS') trns = d;
		else if (t === 'IDAT') idat.push(d);
		else if (t === 'IEND') break;
		p += 12 + n;
	}
	if (lace) die(file + ': interlaced PNGs are not read (save it without interlacing)');
	if (type !== 3 && depth !== 8) die(file + ': ' + depth + ' bits a channel is not read (save it as 8 bit)');
	const ch = [1, 0, 3, 1, 2, 0, 4][type];
	const bpp = Math.max(1, (ch * depth) >> 3), line = Math.ceil(w * ch * depth / 8);
	const raw = zlib.inflateSync(Buffer.concat(idat));
	const cur = Buffer.alloc(line);
	let prev = Buffer.alloc(line);
	const px = new Uint8Array(w * h * 4);
	for (let y = 0; y < h; y++) {
		const f = raw[y * (line + 1)], src = raw.slice(y * (line + 1) + 1, (y + 1) * (line + 1));
		for (let i = 0; i < line; i++) {
			const a = i >= bpp ? cur[i - bpp] : 0, u = prev[i], c = i >= bpp ? prev[i - bpp] : 0;
			let v = src[i];
			if (f === 1) v += a;
			else if (f === 2) v += u;
			else if (f === 3) v += (a + u) >> 1;
			else if (f === 4) { const q = a + u - c, pa = Math.abs(q - a), pb = Math.abs(q - u), pc = Math.abs(q - c); v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? u : c); }
			cur[i] = v & 255;
		}
		for (let x = 0; x < w; x++) {
			const o = (y * w + x) * 4;
			let r, g, bl, al = 255;
			if (type === 3) {
				const n = depth === 8 ? cur[x] : (cur[(x * depth) >> 3] >> (8 - depth - ((x * depth) & 7))) & ((1 << depth) - 1);
				r = pal[n * 3]; g = pal[n * 3 + 1]; bl = pal[n * 3 + 2];
				if (trns && n < trns.length) al = trns[n];
			} else if (type === 0) { r = g = bl = cur[x]; }
			else if (type === 4) { r = g = bl = cur[x * 2]; al = cur[x * 2 + 1]; }
			else if (type === 2) { r = cur[x * 3]; g = cur[x * 3 + 1]; bl = cur[x * 3 + 2]; }
			else { r = cur[x * 4]; g = cur[x * 4 + 1]; bl = cur[x * 4 + 2]; al = cur[x * 4 + 3]; }
			px[o] = r; px[o + 1] = g; px[o + 2] = bl; px[o + 3] = al;
		}
		cur.copy(prev);
	}
	return { w, h, px, alpha: type === 4 || type === 6 || !!trns };
}

// the Neo Geo's colour word for 8 bit r, g, b (5 bits each: the low bit of each in bits 14-12)
function ngcol(r, g, b) {
	r >>= 3; g >>= 3; b >>= 3;
	return ((r & 1) << 14) | ((g & 1) << 13) | ((b & 1) << 12) | ((r >> 1) << 8) | ((g >> 1) << 4) | (b >> 1);
}

// the picture as colour words, -1 clear
function words(img) {
	const out = new Int32Array(img.w * img.h);
	const key = img.alpha ? -2 : ngcol(img.px[0], img.px[1], img.px[2]);
	for (let i = 0; i < out.length; i++) {
		const c = ngcol(img.px[i * 4], img.px[i * 4 + 1], img.px[i * 4 + 2]);
		out[i] = (img.alpha ? img.px[i * 4 + 3] < 128 : c === key) ? -1 : c;
	}
	return out;
}

function dist(a, b) {
	const f = c => [((c >> 8) & 15) * 2 + ((c >> 14) & 1), ((c >> 4) & 15) * 2 + ((c >> 13) & 1), (c & 15) * 2 + ((c >> 12) & 1)];
	const x = f(a), y = f(b);
	return (x[0] - y[0]) ** 2 + (x[1] - y[1]) ** 2 + (x[2] - y[2]) ** 2;
}

// the colours of some pixels -> a palette of at most `most` (the most used), and each colour's number
function palette(cols, most, what) {
	const cnt = new Map();
	cols.forEach(c => { if (c >= 0) cnt.set(c, (cnt.get(c) || 0) + 1); });
	const order = [...cnt.keys()].sort((a, b) => cnt.get(b) - cnt.get(a));
	const keep = order.slice(0, most);
	if (order.length > most && what) console.log('  ' + what + ': ' + order.length + ' colours: the ' + most + ' most used kept, the rest go to the nearest');
	const num = new Map();
	order.forEach(c => {
		let best = 0, bd = Infinity;
		keep.forEach((k, i) => { const d = dist(c, k); if (d < bd) { bd = d; best = i; } });
		num.set(c, best + 1);
	});
	const pal = [0].concat(keep);
	while (pal.length < 16) pal.push(0);
	return { pal, num };
}

// a 16 x 16 tile of colour numbers (get(x, y)) -> the C ROM's 128 bytes: bytes 64-127 the left 8
// pixels, 0-63 the right 8; each row 4 bytes, the bit planes 0, 2, 1, 3; bit x the half's pixel x
function ctile(get) {
	const out = Buffer.alloc(128, 0);
	for (let y = 0; y < 16; y++)
		for (let half = 0; half < 2; half++) {
			const o = (half === 0 ? 64 : 0) + y * 4, v = [0, 0, 0, 0];
			for (let x = 0; x < 8; x++) {
				const p = get(half * 8 + x, y);
				for (let n = 0; n < 4; n++) if (p & (1 << n)) v[n] |= 1 << x;
			}
			out[o] = v[0]; out[o + 2] = v[1]; out[o + 1] = v[2]; out[o + 3] = v[3];
		}
	return out;
}

// an 8 x 8 fix tile: 32 bytes, 4 columns of 8 bytes (pixel pairs 4-5, 6-7, 0-1, 2-3), each byte a
// pair (low nibble the left pixel)
function ftile(get) {
	const t = Buffer.alloc(32, 0), col = [0x10, 0x18, 0x00, 0x08];
	for (let y = 0; y < 8; y++)
		for (let x = 0; x < 8; x++) {
			const v = get(x, y);
			t[col[x >> 1] + y] |= (x & 1) ? (v << 4) : v;
		}
	return t;
}

function palBytes(pal) {
	const b = Buffer.alloc(32);
	pal.forEach((c, i) => b.writeUInt16BE(c, i * 2));
	return b;
}

function main() {
	const o = {};
	process.argv.slice(2).forEach(a => { const m = a.match(/^--(\w+)=(.*)$/); if (m) o[m[1]] = m[2]; else die('what is ' + a + '?'); });
	if (!o.out) die('usage: node ngtiles.js --out=NAME [--sprites=A.png,...] [--backdrop=P.png,...] [--fix=F.png] [--first=1] [--order=rows|columns] [--fixfirst=256]');
	const list = s => (s ? s.split(',').filter(x => x) : []);
	const tiles = [];
	const pals = [];
	const notes = [];
	let at = o.first !== undefined ? parseInt(o.first, 10) : 1;
	for (let i = 0; i < at; i++) tiles.push(Buffer.alloc(128, 0));
	list(o.sprites).forEach(f => {
		const img = png(f), w = words(img);
		if (img.w % 16 || img.h % 16) die(f + ': ' + img.w + ' x ' + img.h + ' is not whole 16 x 16 tiles');
		const p = palette(Array.from(w), 15, path.basename(f));
		const tw = img.w / 16, th = img.h / 16, first = tiles.length;
		const one = (tx, ty) => tiles.push(ctile((x, y) => { const c = w[(ty * 16 + y) * img.w + tx * 16 + x]; return c < 0 ? 0 : p.num.get(c); }));
		if (o.order === 'columns') { for (let tx = 0; tx < tw; tx++) for (let ty = 0; ty < th; ty++) one(tx, ty); }
		else for (let ty = 0; ty < th; ty++) for (let tx = 0; tx < tw; tx++) one(tx, ty);
		notes.push(path.basename(f) + ': sprites, tiles ' + first + '-' + (tiles.length - 1) + ' (' + tw + ' x ' + th + ', ' + (o.order === 'columns' ? 'down the columns' : 'row by row') + '), palette at ' + pals.length * 32 + ' of ' + path.basename(o.out) + '_PAL.BIN');
		pals.push(palBytes(p.pal));
	});
	const BTOP = [0, 56, 112, 152], BH = [56, 56, 40, 40], ROWS = [4, 4, 3, 3];
	list(o.backdrop).forEach(f => {
		const img = png(f), w = words(img);
		if (img.w !== 256 || img.h !== 192) die(f + ': a backdrop is 256 x 192 (this is ' + img.w + ' x ' + img.h + ')');
		const first = tiles.length, pfirst = pals.length;
		let n = 0;
		for (let b = 0; b < 4; b++)
			for (let k = 0; k < 16; k++)
				for (let r = 0; r < ROWS[b]; r++) {
					const cell = (x, y) => (r * 16 + y < BH[b] ? w[(BTOP[b] + r * 16 + y) * 256 + k * 16 + x] : -1);
					const cols = [];
					for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) cols.push(cell(x, y));
					// (the last tile's palette is 255: its colour 15 is entry 4095, the backdrop colour)
					const p = palette(cols, n === 223 ? 14 : 15, null);
					tiles.push(ctile((x, y) => { const c = cell(x, y); return c < 0 ? 0 : p.num.get(c); }));
					pals.push(palBytes(p.pal));
					n++;
				}
		notes.push(path.basename(f) + ': backdrop, tiles ' + first + '-' + (tiles.length - 1) + ' (Vdp.Back ' + first + ', the palettes\' address), its 224 palettes at ' + pfirst * 32 + ' of ' + path.basename(o.out) + '_PAL.BIN');
	});
	if (tiles.length > at || o.sprites || o.backdrop) {
		let c = Buffer.concat(tiles);
		let size = 0x10000;
		while (size < c.length) size *= 2;                    // (a C ROM is a power of 2)
		c = Buffer.concat([c, Buffer.alloc(size - c.length, 0)]);
		fs.writeFileSync(o.out + '_C.BIN', c);
		fs.writeFileSync(o.out + '_PAL.BIN', Buffer.concat(pals));
		notes.push(path.basename(o.out) + '_C.BIN: ' + tiles.length + ' tiles, ' + c.length + ' bytes; ' + path.basename(o.out) + '_PAL.BIN: ' + pals.length + ' palettes');
	}
	if (o.fix) {
		const img = png(o.fix), w = words(img);
		if (img.w % 8 || img.h % 8) die(o.fix + ': ' + img.w + ' x ' + img.h + ' is not whole 8 x 8 tiles');
		const p = palette(Array.from(w), 15, path.basename(o.fix));
		const ng = require(path.join(__dirname, '..', '..', 'test', 'ngbuild.js'));
		const s = ng.defaultS();
		const ff = o.fixfirst !== undefined ? parseInt(o.fixfirst, 10) : 256;
		let n = ff;
		for (let ty = 0; ty < img.h / 8; ty++)
			for (let tx = 0; tx < img.w / 8; tx++) {
				if (n >= 4096) die(o.fix + ': past the S ROM\'s 4096 tiles');
				ftile((x, y) => { const c = w[(ty * 8 + y) * img.w + tx * 8 + x]; return c < 0 ? 0 : p.num.get(c); }).copy(s, n * 32);
				n++;
			}
		fs.writeFileSync(o.out + '_S.BIN', s);
		fs.writeFileSync(o.out + '_FIX.BIN', palBytes(p.pal));
		notes.push(path.basename(o.fix) + ': fix tiles ' + ff + '-' + (n - 1) + ' in ' + path.basename(o.out) + '_S.BIN (NTC\'s font at 32-126), palette ' + path.basename(o.out) + '_FIX.BIN');
	}
	fs.writeFileSync(o.out + '.txt', notes.join('\n') + '\n');
	console.log(notes.join('\n'));
}
if (require.main === module) main();
module.exports = { png, ngcol, ctile, ftile };

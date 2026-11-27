// ngbuild.js - build a Neo Geo cartridge (.neo, TerraOnion's format: Geolith and the NeoSD /
// MiSTer read it) from NTC BASIC (the neogeo platform). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node ngbuild.js Main.bas [More.cls ...] --out=GAME.neo [--name="GAME NAME"] [--ngh=3100]
//        [--log] [--list=GAME.lst] [--asm=GAME.s] [--const=...]   (--ngh: decimal, 3100 if not given;
//        not 2457 = $999: Geolith takes that for V-Liner and reads the pads its way)
//        [--srom=S.BIN] [--crom=C.BIN] [--vrom=V.BIN] [--mrom=M1.BIN]
//        [--songs=SONGS.BIN] [--samples=SAMPLES.BIN]
//
// Compiles with the NTC compiler (cli.js --platform=neogeo), assembles with vasm (NTC_VASM:
// vasmm68k_mot -spaces -Fbin -coalesced) into the P ROM, puts the name in the soft DIPs' name
// and the NGH number at $108, and packs the cartridge:
//   P   the program (padded to 1 MB; stored a word at a time, low byte first, as the dumps are)
//   S   the fix layer's tiles (--srom, else NTC's font at tiles 32-126 and the Graphics class's
//       blocks at 256-511, colour 1)
//   M1  the Z80's program (--mrom, else NTC's driver: src/asm/neogeo_sound_z80.asm, assembled
//       with sjasmplus: NTC_SJASM), with --songs (32 x 8 bytes at $100) and --samples (64 x 4
//       bytes at $200) written in
//   V1  the ADPCM samples (--vrom, else 256 bytes of silence)
//   C   the sprites' tiles (--crom, already the cartridge's interleaved C1/C2 bytes; else one
//       empty tile)
// --log: a test build (vasm -DNTC_NGLOG=1): what the console prints is kept in RAM from
// $10C000 too, for ngrun.py --log.
// The first time, it also makes test/ngsys/aes.zip (for Geolith's AES mode: neo-epo.bin, NTC's
// stand-in BIOS from test/ngbios.s, and 000-lo.lo, the sprites' vertical shrink table).
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const here = __dirname;
const NTC = path.join(here, '..');

function die(m) { console.error(m); process.exit(1); }
function run(cmd, argv, opt) {
	const r = cp.spawnSync(cmd, argv, Object.assign({ encoding: 'utf8', maxBuffer: 1 << 28 }, opt || {}));
	if (r.error) die(cmd + ': ' + r.error.message);
	return r;
}
const VASM = process.env.NTC_VASM || 'vasmm68k_mot';
const SJASM = process.env.NTC_SJASM || 'sjasmplus';

// the byte order of the Neo Geo's 68000 ROMs in their files: each word low byte first
function swap16(b) {
	const o = Buffer.from(b);
	for (let i = 0; i + 1 < o.length; i += 2) { o[i] = b[i + 1]; o[i + 1] = b[i]; }
	return o;
}

// the L0 ROM: the vertical shrink tables (twice 256 tables of 256 bytes: table v lists the v + 1
// lines of 256 a sprite shrunk to v draws, added one at a time in an order that spreads them)
function l0rom() {
	const out = Buffer.alloc(131072, 255);
	const rows = [];
	for (const i of [8, 12, 10, 14, 9, 13, 11, 15])
		for (const j of [0, 16, -8, 8])
			for (const k of [0, -128, 64, -64, 32, -96, 96, -32]) rows.push(128 + i + j + k);
	for (let half = 0; half < 2; half++) {
		const on = new Array(256).fill(false);
		rows.forEach((r, n) => {
			on[r] = true;
			const t = half * 256 + n;
			let x = 0;
			for (let v = 0; v < 256; v++) if (on[v]) out[t * 256 + x++] = v;
		});
	}
	return out;
}

// NTC's stand-in BIOS and the L0 ROM, zipped for Geolith (test/ngsys/aes.zip)
function makeSys() {
	const dir = path.join(here, 'ngsys');
	const zip = path.join(dir, 'aes.zip');
	if (fs.existsSync(zip)) return;
	fs.mkdirSync(dir, { recursive: true });
	const bin = path.join(dir, 'ngbios.bin');
	const r = run(VASM, ['-quiet', '-spaces', '-Fbin', '-o', bin, path.join(here, 'ngbios.s')]);
	if (r.status !== 0) die(r.stdout + r.stderr);
	fs.writeFileSync(path.join(dir, 'neo-epo.bin'), swap16(fs.readFileSync(bin)));
	fs.writeFileSync(path.join(dir, '000-lo.lo'), l0rom());
	fs.unlinkSync(bin);
	const z = run('zip', ['-q', '-j', zip, path.join(dir, 'neo-epo.bin'), path.join(dir, '000-lo.lo')]);
	if (z.status !== 0) die('zip: ' + z.stderr);
	fs.unlinkSync(path.join(dir, 'neo-epo.bin'));
	fs.unlinkSync(path.join(dir, '000-lo.lo'));
}

// the fix layer's tiles from an 8 x 8 font (1 bit a pixel, a byte a row, bit 7 the left): tile
// 32 + n is character 32 + n in colour 1. A fix tile is 32 bytes: 4 columns of 8 bytes (pixel
// pairs 4-5, 6-7, 0-1, 2-3), each byte a pair (low nibble the left pixel)
function fixTile(rows, ink, shadow) {
	const t = Buffer.alloc(32, 0);
	const col = [0x10, 0x18, 0x00, 0x08];
	for (let y = 0; y < 8; y++)
		for (let x = 0; x < 8; x++) {
			let v = 0;
			if (shadow && shadow[y] & (0x80 >> x)) v = shadow.c;
			if (rows[y] & (0x80 >> x)) v = ink;
			if (!v) continue;
			const o = col[x >> 1] + y;
			t[o] |= (x & 1) ? (v << 4) : v;
		}
	return t;
}
function fontFromAsm() {
	// the md platform's font (95 characters from 32), the same one NTC's consoles use
	const src = fs.readFileSync(path.join(NTC, 'src', 'asm', 'ntc_plat_md.asm'), 'utf8');
	const i = src.indexOf('ntc_md_font:');
	const rows = [];
	src.slice(i).split('\n').slice(1).some(l => {
		const m = l.match(/dc\.b\s+([^;]+)/);
		if (!m) return true;
		m[1].split(',').forEach(v => rows.push(parseInt(v.trim().replace('$', ''), 16)));
		return rows.length >= 95 * 8;
	});
	return rows;
}
function defaultS() {
	const s = Buffer.alloc(128 * 1024, 0);
	const f = fontFromAsm();
	for (let c = 0; c < 95; c++) fixTile(f.slice(c * 8, c * 8 + 8), 1).copy(s, (32 + c) * 32);
	// tiles 256-511: the Graphics class's blocks - a cell as 2 x 4 dots of 4 x 2 pixels, tile
	// 256 + n with dot k (k = row * 2 + column) on when bit k of n is set, in colour 1
	for (let n = 0; n < 256; n++) {
		const rows = [0, 0, 0, 0, 0, 0, 0, 0];
		for (let k = 0; k < 8; k++)
			if (n & (1 << k)) { const m = (k & 1) ? 0x0F : 0xF0; rows[(k >> 1) * 2] |= m; rows[(k >> 1) * 2 + 1] |= m; }
		fixTile(rows, 1).copy(s, (256 + n) * 32);
	}
	return s;
}

function defaultM() {
	const out = path.join(here, 'ngsys', 'NTCSND.BIN');
	const r = run(SJASM, ['--nologo', '--raw=' + out, path.join(NTC, 'src', 'asm', 'neogeo_sound_z80.asm')]);
	if (r.status !== 0) die(r.stdout + r.stderr);
	return fs.readFileSync(out);
}

function pow2(n, min) { let p = min; while (p < n) p *= 2; return p; }

function main() {
	const files = [], extra = [];
	const o = { name: null, ngh: 3100, log: false };
	for (const a of process.argv.slice(2)) {
		const m = a.match(/^--(\w+)(?:=(.*))?$/);
		if (!m) { files.push(a); continue; }
		if (m[1] === 'const') extra.push(a);
		else if (m[1] === 'log') o.log = true;
		else o[m[1]] = m[2];
	}
	if (!files.length) die('ngbuild.js Main.bas ... --out=GAME.neo');
	makeSys();
	const out = o.out || files[0].replace(/\.[^.]+$/, '') + '.neo';
	const base = out.replace(/\.[^.]+$/, '');
	const asmout = o.asm || base + '.s';
	const c = run('node', [path.join(here, 'cli.js'), '--platform=neogeo', '--name=' + path.basename(base)].concat(extra, files));
	const errs = c.stderr.split('\n').filter(l => l.startsWith('ERR'));
	if (c.stderr.trim()) console.error(c.stderr.trim());
	if (errs.length || c.status !== 0) process.exit(1);
	fs.writeFileSync(asmout, c.stdout);
	const pbin = base + '.p';
	const va = ['-quiet', '-spaces', '-Fbin', '-coalesced', '-o', pbin];
	if (o.log) va.push('-DNTC_NGLOG=1');
	if (o.list) va.push('-L', o.list);
	va.push(asmout);
	const v = run(VASM, va);
	if (v.status !== 0) die(v.stdout + v.stderr);
	let p = fs.readFileSync(pbin);
	fs.unlinkSync(pbin);
	if (p.length > 0x100000) die(out + ': the program is ' + p.length + ' bytes: more than the 1 MB a P ROM shows at once');
	const P = Buffer.alloc(0x100000, 0xFF);
	p.copy(P);
	const name = String(o.name || path.basename(base)).toUpperCase().slice(0, 16).padEnd(16, ' ');
	const di = P.indexOf(Buffer.from('NTC BASIC       '));
	if (di > 0) Buffer.from(name, 'ascii').copy(P, di);
	P.writeUInt16BE(parseInt(o.ngh, 10) || 3100, 0x108);
	const S = o.srom ? fs.readFileSync(o.srom) : defaultS();
	let M = o.mrom ? Buffer.from(fs.readFileSync(o.mrom)) : defaultM();
	M = Buffer.concat([M, Buffer.alloc(pow2(M.length, 0x10000) - M.length, 0xFF)]);
	if (o.songs) fs.readFileSync(o.songs).copy(M, 0x100, 0, 32 * 8);
	if (o.samples) fs.readFileSync(o.samples).copy(M, 0x200, 0, 64 * 4);
	let V = o.vrom ? fs.readFileSync(o.vrom) : Buffer.alloc(256, 0x80);
	V = Buffer.concat([V, Buffer.alloc(pow2(V.length, 0x100000) - V.length, 0x80)]);
	let C = o.crom ? fs.readFileSync(o.crom) : Buffer.alloc(256, 0);
	C = Buffer.concat([C, Buffer.alloc(pow2(C.length, 0x100000) - C.length, 0)]);
	const head = Buffer.alloc(4096, 0);
	head.write('NEO', 0, 'ascii');
	head[3] = 1;
	[P.length, S.length, M.length, V.length, 0, C.length].forEach((n, i) => head.writeUInt32LE(n, 4 + i * 4));
	head.writeUInt32LE(2026, 28);
	head.writeUInt32LE(0, 32);
	head.writeUInt32LE(parseInt(o.ngh, 10) || 3100, 40);
	head.write(String(o.name || path.basename(base)).slice(0, 33), 44, 'ascii');
	head.write('NTC BASIC', 77, 'ascii');
	fs.writeFileSync(out, Buffer.concat([head, swap16(P), S, M, V, C]));
	console.log(out + ': the program ' + p.length + ' bytes; S ' + S.length + ', M1 ' + M.length + ', V ' + V.length + ', C ' + C.length);
}

// run as a program, or required (test/ncdbuild.js: the Neo Geo CD's, which takes the font, the
// sound driver and the byte order from here)
if (require.main === module) main();
module.exports = { run, die, swap16, defaultS, defaultM, fixTile, fontFromAsm, pow2, VASM, SJASM };

// ncdbuild.js - build a Neo Geo CD disc (a .cue with its .bin tracks: track 1 the data, MODE1/2352,
// then the CD audio tracks) from NTC BASIC (the neocd platform). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
//
//   node ncdbuild.js Main.bas [More.cls ...] --out=GAME.cue [--name="GAME NAME"] [--ngh=3100]
//        [--log] [--list=GAME.lst] [--asm=GAME.s] [--const=...]
//        [--fix=S.BIN] [--crom=C.BIN | --spr=GAME.SPR] [--z80=M1.BIN] [--songs=SONGS.BIN]
//        [--samples=SAMPLES.BIN] [--pcm=V.BIN] [--tracks=a.wav,b.wav,...]
//
// Compiles with the NTC compiler (cli.js --platform=neocd) and vasm, as test/ngbuild.js does for
// a cartridge, and writes the disc: an ISO 9660 file system (track 1) holding
//   IPL.TXT    the files the CD BIOS loads at start-up, and where
//   GAME.PRG   the program (to 0 in the program RAM: vectors, header, code, its RAM block's image)
//   GAME.FIX   the fix layer's tiles (--fix: an S ROM's bytes, the same layout; else NTC's font)
//   GAME.SPR   the sprites' tiles (--spr: as it is; --crom: a .neo's C ROM bytes - C1 and C2
//              interleaved - turned into the CD's order: each row's four bytes, planes 0 2 1 3 on
//              a cartridge, are planes 1 0 3 2 here)
//   GAME.Z80   the Z80's program (--z80, else NTC's driver: src/asm/neogeo_sound_z80.asm, with
//              --songs and --samples written into its tables at $100 and $200)
//   GAME.PCM   the ADPCM samples (--pcm; else 256 bytes of silence: the CD BIOS wants one)
// and the CD audio tracks after it (--tracks: WAV files, 44.1 kHz, 16 bit, stereo: track 2 on),
// each with the 2 second gap before it a CD has. The tracks are .bin files of their own beside
// the .cue (GAME_01.BIN, GAME_02.BIN ...); track 1's sectors are whole MODE1 sectors (sync,
// address, the data, its EDC and ECC), so the disc can be written to a CD-R as it is.
// The CD BIOS loads the files in IPL.TXT's order: FIX, SPR, PCM, Z80, PRG.
const fs = require('fs');
const path = require('path');
const ng = require('./ngbuild.js');
const here = __dirname;
const { run, die } = ng;

// ---------------------------------------------------------------- CD-ROM sectors (ECMA-130)
const EDC = new Uint32Array(256);
const ECC_F = new Uint8Array(256), ECC_B = new Uint8Array(256);
for (let i = 0; i < 256; i++) {
	let e = i;
	for (let j = 0; j < 8; j++) e = (e >>> 1) ^ ((e & 1) ? 0xD8018001 : 0);
	EDC[i] = e >>> 0;
	const f = ((i << 1) ^ ((i & 0x80) ? 0x11D : 0)) & 0xFF;
	ECC_F[i] = f;
	ECC_B[i ^ f] = i;
}
function edc(b, start, end) {
	let e = 0;
	for (let i = start; i < end; i++) e = (e >>> 8) ^ EDC[(e ^ b[i]) & 0xFF];
	return e >>> 0;
}
function eccBlock(s, majorCount, minorCount, majorMult, minorInc, dest) {
	const size = majorCount * minorCount;
	for (let major = 0; major < majorCount; major++) {
		let index = (major >> 1) * majorMult + (major & 1);
		let a = 0, b = 0;
		for (let minor = 0; minor < minorCount; minor++) {
			const t = s[0x0C + index];
			index += minorInc;
			if (index >= size) index -= size;
			a ^= t;
			b ^= t;
			a = ECC_F[a];
		}
		a = ECC_B[ECC_F[a] ^ b];
		s[dest + major] = a;
		s[dest + major + majorCount] = a ^ b;
	}
}
const bcd = n => ((Math.floor(n / 10) << 4) | (n % 10));
// a MODE1 sector (2352 bytes) for 2048 bytes of data at the disc's sector lba
function mode1(data, lba) {
	const s = Buffer.alloc(2352, 0);
	s.fill(0xFF, 1, 11);
	const a = lba + 150;
	s[12] = bcd(Math.floor(a / 4500));
	s[13] = bcd(Math.floor(a / 75) % 60);
	s[14] = bcd(a % 75);
	s[15] = 1;
	data.copy(s, 16, 0, 2048);
	s.writeUInt32LE(edc(s, 0, 0x810), 0x810);
	eccBlock(s, 86, 24, 2, 86, 0x81C);
	eccBlock(s, 52, 43, 86, 88, 0x8C8);
	return s;
}

// ---------------------------------------------------------------- ISO 9660
function both16(b, o, v) { b.writeUInt16LE(v, o); b.writeUInt16BE(v, o + 2); }
function both32(b, o, v) { b.writeUInt32LE(v, o); b.writeUInt32BE(v, o + 4); }
function dirRecord(name, lba, size, dir) {
	const n = Buffer.from(name, 'ascii');
	let len = 33 + n.length;
	if (len & 1) len++;
	const r = Buffer.alloc(len, 0);
	r[0] = len;
	both32(r, 2, lba);
	both32(r, 10, size);
	r[18] = 126; r[19] = 1; r[20] = 1;			// 2026-01-01
	r[25] = dir ? 2 : 0;
	both16(r, 28, 1);
	r[32] = n.length;
	n.copy(r, 33);
	return r;
}
function padText(b, o, len, t) { b.fill(0x20, o, o + len); Buffer.from(t.slice(0, len), 'ascii').copy(b, o); }
function dateText(b, o) { b.write('2026010100000000', o, 'ascii'); b[o + 16] = 0; }
// files: [{name, data}] in the root -> the ISO's 2048 byte sectors
function iso(volume, files) {
	const ROOT = 20;
	const recs = files.map(f => ({ f, rec: null }));
	// the root directory: ".", "..", then the files by name
	const sorted = files.slice().sort((a, b) => (a.name < b.name ? -1 : 1));
	let dirSize = 68;
	sorted.forEach(f => { let l = 33 + f.name.length + 2; if (l & 1) l++; dirSize += l; });
	const dirSectors = Math.ceil(dirSize / 2048) + 1;
	let lba = ROOT + dirSectors;
	sorted.forEach(f => { f.lba = lba; lba += Math.max(1, Math.ceil(f.data.length / 2048)); });
	const total = Math.max(lba, 300);
	const img = Buffer.alloc(total * 2048, 0);
	const dir = Buffer.alloc(dirSectors * 2048, 0);
	let at = 0;
	const put = r => { if ((at & 2047) + r.length > 2048) at = (at + 2047) & ~2047; r.copy(dir, at); at += r.length; };
	put(dirRecord('\0', ROOT, dirSectors * 2048, true));
	put(dirRecord('\x01', ROOT, dirSectors * 2048, true));
	sorted.forEach(f => put(dirRecord(f.name + ';1', f.lba, f.data.length, false)));
	dir.copy(img, ROOT * 2048);
	sorted.forEach(f => f.data.copy(img, f.lba * 2048));
	// the path tables (sectors 18: little endian, 19: big endian): the root only
	const pt = (o, be) => { img[o] = 1; img[o + 1] = 0; if (be) { img.writeUInt32BE(ROOT, o + 2); img.writeUInt16BE(1, o + 6); } else { img.writeUInt32LE(ROOT, o + 2); img.writeUInt16LE(1, o + 6); } };
	pt(18 * 2048, false);
	pt(19 * 2048, true);
	// the primary volume descriptor (16) and the terminator (17)
	const p = 16 * 2048;
	img[p] = 1; img.write('CD001', p + 1, 'ascii'); img[p + 6] = 1;
	padText(img, p + 8, 32, 'NEOGEO');
	padText(img, p + 40, 32, volume.toUpperCase().replace(/[^A-Z0-9_]/g, '_'));
	both32(img, p + 80, total);
	both16(img, p + 120, 1);
	both16(img, p + 124, 1);
	both16(img, p + 128, 2048);
	both32(img, p + 132, 10);
	img.writeUInt32LE(18, p + 140);
	img.writeUInt32BE(19, p + 148);
	dirRecord('\0', ROOT, dirSectors * 2048, true).copy(img, p + 156);
	padText(img, p + 190, 128, '');
	padText(img, p + 318, 128, 'CYBORG UNICORN');
	padText(img, p + 446, 128, 'NTC BASIC');
	padText(img, p + 574, 128, 'NTC BASIC');
	padText(img, p + 702, 37, ''); padText(img, p + 739, 37, ''); padText(img, p + 776, 37, '');
	dateText(img, p + 813); dateText(img, p + 830);
	img.write('0000000000000000', p + 847, 'ascii'); img.write('0000000000000000', p + 864, 'ascii');
	img[p + 881] = 1;
	const t = 17 * 2048;
	img[t] = 255; img.write('CD001', t + 1, 'ascii'); img[t + 6] = 1;
	return img;
}

// ---------------------------------------------------------------- the files
function crom2spr(c) {
	const o = Buffer.alloc(c.length);
	for (let i = 0; i + 3 < c.length; i += 4) {
		o[i] = c[i + 2]; o[i + 1] = c[i]; o[i + 2] = c[i + 3]; o[i + 3] = c[i + 1];
	}
	return o;
}
// the used part of a tile ROM (whole tiles of n bytes; at least one)
function trimTiles(b, n, empty) {
	let end = b.length;
	while (end > n && b.slice(end - n, end).every(v => v === empty)) end -= n;
	return b.slice(0, Math.max(n, end));
}
function wavData(file) {
	const b = fs.readFileSync(file);
	if (b.toString('ascii', 0, 4) !== 'RIFF' || b.toString('ascii', 8, 12) !== 'WAVE') die(file + ': not a WAV file');
	let o = 12, fmt = null;
	while (o + 8 <= b.length) {
		const id = b.toString('ascii', o, o + 4), n = b.readUInt32LE(o + 4);
		if (id === 'fmt ') fmt = { ch: b.readUInt16LE(o + 10), rate: b.readUInt32LE(o + 12), bits: b.readUInt16LE(o + 22) };
		if (id === 'data') {
			if (!fmt || fmt.ch !== 2 || fmt.rate !== 44100 || fmt.bits !== 16) die(file + ': CD audio must be 44.1 kHz, 16 bit, stereo');
			return b.slice(o + 8, o + 8 + n);
		}
		o += 8 + n + (n & 1);
	}
	die(file + ': no data');
}

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
	if (!files.length) die('ncdbuild.js Main.bas ... --out=GAME.cue');
	fs.mkdirSync(path.join(here, 'ngsys'), { recursive: true });
	const out = o.out || files[0].replace(/\.[^.]+$/, '') + '.cue';
	const base = out.replace(/\.[^.]+$/, '');
	const stem = path.basename(base).toUpperCase().replace(/[^A-Z0-9_]/g, '').slice(0, 8) || 'GAME';
	const asmout = o.asm || base + '.s';
	const c = run('node', [path.join(here, 'cli.js'), '--platform=neocd', '--name=' + path.basename(base)].concat(extra, files));
	const errs = c.stderr.split('\n').filter(l => l.startsWith('ERR'));
	if (c.stderr.trim()) console.error(c.stderr.trim());
	if (errs.length || c.status !== 0) process.exit(1);
	fs.writeFileSync(asmout, c.stdout);
	const pbin = base + '.prgtmp';
	const va = ['-quiet', '-spaces', '-Fbin', '-coalesced', '-o', pbin];
	if (o.log) va.push('-DNTC_NGLOG=1');
	if (o.list) va.push('-L', o.list);
	va.push(asmout);
	const v = run(ng.VASM, va);
	if (v.status !== 0) die(v.stdout + v.stderr);
	const P = fs.readFileSync(pbin);
	fs.unlinkSync(pbin);
	if (P.length > 0xF8000) die(out + ': the program is ' + P.length + ' bytes: it would run into its variables at $0F8000');
	const name = String(o.name || path.basename(base)).toUpperCase().slice(0, 16).padEnd(16, ' ');
	const di = P.indexOf(Buffer.from('NTC BASIC       '));
	if (di > 0) Buffer.from(name, 'ascii').copy(P, di);
	P.writeUInt16BE(parseInt(o.ngh, 10) || 3100, 0x108);
	const FIX = trimTiles(o.fix ? fs.readFileSync(o.fix) : ng.defaultS(), 32, 0);
	const SPR = trimTiles(o.spr ? fs.readFileSync(o.spr) : (o.crom ? crom2spr(fs.readFileSync(o.crom)) : Buffer.alloc(128, 0)), 128, 0);
	let Z = o.z80 ? Buffer.from(fs.readFileSync(o.z80)) : ng.defaultM();
	if (o.songs) fs.readFileSync(o.songs).copy(Z, 0x100, 0, 32 * 8);
	if (o.samples) fs.readFileSync(o.samples).copy(Z, 0x200, 0, 64 * 4);
	let zend = Z.length;
	while (zend > 0x400 && Z[zend - 1] === 0xFF) zend--;
	Z = Z.slice(0, (zend + 255) & ~255);
	const PCM = o.pcm ? fs.readFileSync(o.pcm) : Buffer.alloc(256, 0x08);
	if (PCM.length > 0x100000) die(out + ': the samples are more than the 1 MB of PCM RAM');
	if (SPR.length > 0x100000) die(out + ': the sprites are more than bank 0\'s 1 MB');
	const ipl = [stem + '.FIX,0,0', stem + '.SPR,0,0', stem + '.PCM,0,0', stem + '.Z80,0,0', stem + '.PRG,0,0'].join('\r\n') + '\r\n';
	const disc = iso(stem, [
		{ name: 'IPL.TXT', data: Buffer.concat([Buffer.from(ipl, 'ascii'), Buffer.from([0x1A])]) },
		{ name: stem + '.PRG', data: P },
		{ name: stem + '.FIX', data: FIX },
		{ name: stem + '.SPR', data: SPR },
		{ name: stem + '.Z80', data: Z },
		{ name: stem + '.PCM', data: PCM }]);
	const dir = path.dirname(path.resolve(out));
	const tname = n => stem + '_' + String(n).padStart(2, '0') + '.BIN';
	const n1 = disc.length / 2048;
	const t1 = Buffer.alloc(n1 * 2352);
	for (let i = 0; i < n1; i++) mode1(disc.slice(i * 2048, i * 2048 + 2048), i).copy(t1, i * 2352);
	fs.writeFileSync(path.join(dir, tname(1)), t1);
	let cue = 'FILE "' + tname(1) + '" BINARY\r\n  TRACK 01 MODE1/2352\r\n    INDEX 01 00:00:00\r\n';
	const tracks = o.tracks ? o.tracks.split(',').filter(Boolean) : [];
	tracks.forEach((f, i) => {
		const pcm = wavData(f);
		const len = Math.ceil(pcm.length / 2352) * 2352;
		const b = Buffer.alloc(150 * 2352 + len, 0);
		pcm.copy(b, 150 * 2352);
		fs.writeFileSync(path.join(dir, tname(i + 2)), b);
		const n = String(i + 2).padStart(2, '0');
		cue += 'FILE "' + tname(i + 2) + '" BINARY\r\n  TRACK ' + n + ' AUDIO\r\n    INDEX 00 00:00:00\r\n    INDEX 01 00:02:00\r\n';
	});
	fs.writeFileSync(out, cue);
	console.log(out + ': ' + stem + '.PRG ' + P.length + ', .FIX ' + FIX.length + ', .SPR ' + SPR.length + ', .Z80 ' + Z.length + ', .PCM ' + PCM.length + ' bytes; ' + tracks.length + ' CD audio tracks');
}

if (require.main === module) main();
module.exports = { crom2spr, mode1, iso, edc };

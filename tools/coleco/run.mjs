// Run a ColecoVision cartridge (.col) on a model of the hardware and check it. No BIOS image is
// needed: the program is started at the address in its header, as the BIOS does, and never calls
// the BIOS. Needs: npm install (z80-emulator).
//   node run.mjs game.col [--png=out.png] [--script="10:0,30:2,100:6,100:9"] [--quiet]
// The model: Z80 3.579545 MHz, 1K RAM #6000 (mirrored to #7FFF), the cartridge at #8000, the
// TMS9918A on #BE / #BF (VRAM, registers, frame flag every 59659 T = 60 Hz), controller 1 on #FC
// after #C0 (joystick mode), #80 (keypad mode). It FAILS the run when the program:
//   - sets R#1 bit 5 (the VDP frame interrupt = NMI: it would push on SP, which is the thread)
//   - touches the VDP closer than 29 T to its last access while the display is on
//   - writes to the cartridge or to unmapped memory, or runs code from the BIOS area
// --script: frames:joystick bits (1 up, 2 right, 4 down, 8 left, #40 fire), each step's sprite
// 0 position is printed. Default: a walk of the ball round the screen with the checks below.
// (c) 2026 Cyborg Unicorn Pty Ltd
import fs from 'fs';
import zlib from 'zlib';
import { Z80 } from 'z80-emulator';

const args = process.argv.slice(2);
const romPath = args.find((a) => !a.startsWith('--'));
const opt = (n) => { const a = args.find((x) => x.startsWith('--' + n + '=')); return a ? a.slice(n.length + 3) : null; };
const quiet = args.includes('--quiet');
const pngPath = opt('png');

if (!romPath) { console.error('usage: node run.mjs game.col [--png=out.png] [--script="frames:bits,..."] [--quiet]'); process.exit(2); }

const rom = fs.readFileSync(romPath);
const FRAME_T = 59659;
const fails = [];
const fail = (m) => { if (fails.length < 20) { fails.push(m); } };

const ram = new Uint8Array(1024);
const vram = new Uint8Array(16384);
const vreg = new Uint8Array(8);
let vlatch = -1;
let vaddr = 0;
let vflag = false;
let vlast = -1000;
let joyMode = 'none';
let joy = 0;
let t0 = 0;
let maxRam = 0;
let minSpRam = 0x10000;   // the lowest SP seen inside the RAM (#6000-#6400): the real stack's depth

const hal = {
	tStateCount: 0,
	readMemory(a) {
		a &= 0xFFFF;
		if (a >= 0x8000) { return a - 0x8000 < rom.length ? rom[a - 0x8000] : 0xFF; }
		if (a >= 0x6000 && a < 0x8000) { return ram[a & 0x3FF]; }
		return 0xFF;
	},
	writeMemory(a, v) {
		a &= 0xFFFF;
		if (a >= 0x6000 && a < 0x8000) { ram[a & 0x3FF] = v; maxRam = Math.max(maxRam, a & 0x3FF); return; }
		fail('write to #' + a.toString(16) + ' (' + (a >= 0x8000 ? 'cartridge ROM' : 'not RAM') + ') at pc #' + cpu.regs.pc.toString(16));
	},
	contendMemory() {},
	contendPort() {},
	readPort(p) {
		p &= 0xFF;
		if (p >= 0xA0 && p <= 0xBF && (p & 1)) { const s = (vflag ? 0x80 : 0) | 0x1F; vflag = false; vlatch = -1; return s; }
		if (p >= 0xA0 && p <= 0xBF) { vdpAccess(); const v = vram[vaddr]; vaddr = (vaddr + 1) & 0x3FFF; return v; }
		if (p === 0xFC || p === 0xFE) {
			if (joyMode === 'joy') { return (~joy & 0x4F) | 0x30; }
			if (joyMode === 'key') { return 0x7F; }
			fail('controller read before selecting a mode (#C0 / #80)');
			return 0xFF;
		}
		return 0xFF;
	},
	writePort(p, v) {
		p &= 0xFF;
		if (p >= 0xA0 && p <= 0xBF && (p & 1)) {
			vdpAccess();
			if (vlatch < 0) { vlatch = v; return; }
			if (v & 0x80 && !(v & 0x40)) {
				vreg[v & 7] = vlatch;
				if ((v & 7) === 1 && (vlatch & 0x20)) { fail('R#1 = #' + vlatch.toString(16) + ': the frame interrupt (NMI) is ON'); }
			} else { vaddr = ((v & 0x3F) << 8) | vlatch; }
			vlatch = -1;
			return;
		}
		if (p >= 0xA0 && p <= 0xBF) { vdpAccess(); vram[vaddr] = v; vaddr = (vaddr + 1) & 0x3FFF; return; }
		if (p >= 0xC0 && p <= 0xDF) { joyMode = 'joy'; return; }
		if (p >= 0x80 && p <= 0x9F) { joyMode = 'key'; return; }
	}
};
function vdpAccess() {
	if ((vreg[1] & 0x40) && hal.tStateCount - vlast < 29) { fail('VDP access ' + (hal.tStateCount - vlast) + ' T after the last one (< 29) at pc #' + cpu.regs.pc.toString(16)); }
	vlast = hal.tStateCount;
}

const cpu = new Z80(hal);
cpu.reset();
if (rom[0] === 0x55 && rom[1] === 0xAA) { /* no title screen */ } else if (rom[0] === 0xAA && rom[1] === 0x55) { /* title screen first */ } else { console.error('not a ColecoVision cartridge: no #AA55 / #55AA at #8000'); process.exit(1); }
cpu.regs.pc = rom[10] | (rom[11] << 8);
cpu.regs.sp = 0x73B9;

let nextFrame = FRAME_T;
function runFrames(n, bits) {
	joy = bits;
	for (let f = 0; f < n; f++) {
		while (hal.tStateCount < nextFrame) {
			const pc = cpu.regs.pc;
			if (pc < 0x2000) { fail('code run in the BIOS area at #' + pc.toString(16)); hal.tStateCount = nextFrame; break; }
			if (cpu.regs.halted) { hal.tStateCount = nextFrame; break; }
			cpu.step();
			const sp = cpu.regs.sp;
			if (sp >= 0x6000 && sp <= 0x6400) { minSpRam = Math.min(minSpRam, sp); }
		}
		nextFrame += FRAME_T;
		vflag = true;
		if (vreg[1] & 0x20) { fail('frame flag with the interrupt enabled: an NMI would be taken'); }
	}
}
const sprite0 = () => ({ y: (vram[0x1B00] + 1) & 0xFF, x: vram[0x1B01], pat: vram[0x1B02], col: vram[0x1B03], next: vram[0x1B04] });

const script = (opt('script') || '').split(',').filter(Boolean).map((s) => s.split(':').map(Number));
const steps = script.length ? script : [[5, 0], [30, 0], [10, 2], [20, 8], [20, 1], [20, 4], [150, 6], [150, 9], [20, 0x40]];
const results = [];

for (let w = 0; w < 200 && !(vreg[1] & 0x40); w++) { runFrames(1, 0); }   // the program's set up: until the display is on
runFrames(3, 0);
let r0 = sprite0();
if (!quiet) { console.log('start         sprite0 x=' + r0.x + ' y=' + r0.y + ' pat=' + r0.pat + ' col=' + r0.col + ' next Y=#' + r0.next.toString(16) + '  R=' + Array.from(vreg).map((v) => v.toString(16).padStart(2, '0')).join(' ')); }
results.push({ bits: -1, frames: 0, ...r0 });
for (const [n, bits] of steps) {
	runFrames(n, bits);
	const s = sprite0();
	results.push({ bits, frames: n, ...s });
	if (!quiet) { console.log('hold ' + String(bits).padStart(3) + ' x' + String(n).padStart(3) + '  sprite0 x=' + String(s.x).padStart(3) + ' y=' + String(s.y).padStart(3)); }
}

// the expected ball path of the default walk: 2 pixels a frame, kept inside x 8-232, y 8-168
if (!script.length) {
	let x = 120, y = 88;
	const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
	const exp = [{ x, y }];
	for (const [n, bits] of steps) {
		for (let i = 0; i < n; i++) {
			if (bits & 1) { y -= 2; }
			if (bits & 4) { y += 2; }
			if (bits & 8) { x -= 2; }
			if (bits & 2) { x += 2; }
			x = clamp(x, 8, 232); y = clamp(y, 8, 168);
		}
		exp.push({ x, y });
	}
	results.slice(1).forEach((r, i) => { if (r.x !== exp[i + 1].x || r.y !== exp[i + 1].y) { fail('step ' + i + ': sprite at ' + r.x + ',' + r.y + ', expected ' + exp[i + 1].x + ',' + exp[i + 1].y); } });
	if (results[0].x !== 120 || results[0].y !== 88) { fail('start position ' + results[0].x + ',' + results[0].y + ', expected 120,88'); }
}

if (!quiet) { console.log('RAM used up to #' + (0x6000 + maxRam).toString(16) + ', lowest SP in RAM ' + (minSpRam === 0x10000 ? 'none (SP stays in the thread)' : '#' + minSpRam.toString(16)) + ', ' + Math.round(hal.tStateCount / FRAME_T) + ' frames run'); }

if (pngPath) { writePng(pngPath); if (!quiet) { console.log('picture: ' + pngPath); } }

if (fails.length) { console.error('FAIL'); fails.forEach((m) => console.error('  ' + m)); process.exit(1); }
if (!quiet) { console.log('PASS'); }

function writePng(file) {
	const pal = [[0, 0, 0, 0], [0, 0, 0], [33, 200, 66], [94, 220, 120], [84, 85, 237], [125, 118, 252], [212, 82, 77], [66, 235, 245], [252, 85, 84], [255, 121, 120], [212, 193, 84], [230, 206, 128], [33, 176, 59], [201, 91, 186], [204, 204, 204], [255, 255, 255]];
	const W = 256, H = 192;
	const bg = pal[vreg[7] & 15] || [0, 0, 0];
	const px = new Uint8Array(W * H * 3);
	const put = (x, y, c) => { if (x >= 0 && x < W && y >= 0 && y < H && c) { const i = (y * W + x) * 3; px[i] = c[0]; px[i + 1] = c[1]; px[i + 2] = c[2]; } };
	for (let y = 0; y < H; y++) { for (let x = 0; x < W; x++) { put(x, y, bg); } }
	const nameB = (vreg[2] & 15) << 10, colB = vreg[3] << 6, patB = (vreg[4] & 7) << 11;
	for (let row = 0; row < 24; row++) {
		for (let col = 0; col < 32; col++) {
			const t = vram[nameB + row * 32 + col];
			const cb = vram[colB + (t >> 3)];
			for (let l = 0; l < 8; l++) {
				const b = vram[patB + t * 8 + l];
				for (let k = 0; k < 8; k++) {
					const ci = (b & (0x80 >> k)) ? (cb >> 4) : (cb & 15);
					put(col * 8 + k, row * 8 + l, ci ? pal[ci] : bg);
				}
			}
		}
	}
	const big = vreg[1] & 2, mag = (vreg[1] & 1) ? 2 : 1, sz = (big ? 16 : 8) * mag, spB = (vreg[6] & 7) << 11, satB = (vreg[5] & 0x7F) << 7;
	for (let s = 31; s >= 0; s--) {
		const y = vram[satB + s * 4];
		if (y === 0xD0) { continue; }
	}
	let n = 0;
	while (n < 32 && vram[satB + n * 4] !== 0xD0) { n++; }
	for (let s = n - 1; s >= 0; s--) {
		const y = (vram[satB + s * 4] + 1) & 0xFF, x0 = vram[satB + s * 4 + 1], pn = vram[satB + s * 4 + 2], c = vram[satB + s * 4 + 3];
		const sx = x0 - ((c & 0x80) ? 32 : 0), ci = c & 15;
		for (let l = 0; l < (big ? 16 : 8); l++) {
			for (let k = 0; k < (big ? 16 : 8); k++) {
				const base = spB + (big ? (pn & 0xFC) : pn) * 8;
				const byte = vram[base + (big ? (k >= 8 ? 16 : 0) + l : l)];
				const bit = byte & (0x80 >> (k & 7));
				if (bit && ci) { for (let my = 0; my < mag; my++) { for (let mx = 0; mx < mag; mx++) { put(sx + k * mag + mx, y + l * mag + my, pal[ci]); } } }
			}
		}
	}
	// 2x, PNG
	const S = 2, OW = W * S, OH = H * S, raw = Buffer.alloc((OW * 3 + 1) * OH);
	for (let y = 0; y < OH; y++) {
		raw[y * (OW * 3 + 1)] = 0;
		for (let x = 0; x < OW; x++) { const i = (Math.floor(y / S) * W + Math.floor(x / S)) * 3; const o = y * (OW * 3 + 1) + 1 + x * 3; raw[o] = px[i]; raw[o + 1] = px[i + 1]; raw[o + 2] = px[i + 2]; }
	}
	const crcT = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) { c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; } return c >>> 0; });
	const crc = (b) => { let c = 0xFFFFFFFF; for (const v of b) { c = crcT[(c ^ v) & 255] ^ (c >>> 8); } return (c ^ 0xFFFFFFFF) >>> 0; };
	const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
	const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(OW, 0); ihdr.writeUInt32BE(OH, 4); ihdr[8] = 8; ihdr[9] = 2;
	fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
}

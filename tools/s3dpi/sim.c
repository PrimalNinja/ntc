/* sim.c - the link simulated in one program: the "CPC" sends PROTOCOL.TXT's packets to the
   card (card.c), watches the status block's sequence number, copies the published list out of
   the "ROM", draws it as the Z80 does (XOR lines, 4 pens) - every step the real pair will do.
     sim AUCKLAND.DAT VIEW FRAMES [out-prefix]
   With out-prefix: each frame as a PPM picture, and the first frame's list as out-prefix.LST
   (the CPC side's test reads it: src/bas/aucklink, FRAME.LST) */
#include "card.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static uint8_t scr[200][320];
static void xline(int x0, int y0, int x1, int y1, int pen)
{
	int dx = abs(x1 - x0), dy = -abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, e = dx + dy;
	for (;;) {
		int e2 = 2 * e;
		scr[y0][x0] ^= (uint8_t)pen;
		if (x0 == x1 && y0 == y1) break;
		if (e2 >= dy) { e += dy; x0 += sx; }
		if (e2 <= dx) { e += dx; y0 += sy; }
	}
}
static int draw_list(const uint8_t *l)
{
	int px = 0, py = 0, pen = 1, n = 0;
	for (;;) {
		int op = l[0] & 0xC0;
		if (op == DL_END) break;
		if (op == DL_PEN) { pen = l[0] & 3; l++; continue; }
		{
			int x = ((l[0] & 1) << 8) | l[1], y = l[2];
			if (op == DL_DRAW) { xline(px, py, x, y, pen); n++; }
			px = x; py = y; l += 3;
		}
	}
	return n;
}
static void save_ppm(const char *name)
{
	static const uint8_t ink[4][3] = { { 0, 0, 0 }, { 255, 255, 255 }, { 0, 255, 0 }, { 0, 255, 255 } };
	FILE *o = fopen(name, "wb");
	int x, y;
	fprintf(o, "P6 320 200 255\n");
	for (y = 0; y < 200; y++) for (x = 0; x < 320; x++) fwrite(ink[scr[y][x] & 3], 1, 3, o);
	fclose(o);
}

int main(int argc, char **argv)
{
	static Card k;
	static uint8_t ram[7680];               /* the CPC's copy of a list */
	FILE *f; uint8_t *d; long size; int i, view, frames, seq;
	uint8_t pkt[8];
	char fn[256];
	if (argc < 4) { fprintf(stderr, "sim AUCKLAND.DAT VIEW FRAMES [out-prefix]\n"); return 1; }
	f = fopen(argv[1], "rb"); if (!f) { perror(argv[1]); return 1; }
	fseek(f, 0, SEEK_END); size = ftell(f); fseek(f, 0, SEEK_SET);
	d = (uint8_t *)malloc(size); if (fread(d, 1, size, f) != (size_t)size) return 1; fclose(f);
	if (card_init(&k, d, (uint32_t)size)) { fprintf(stderr, "not S3D data\n"); return 1; }
	view = atoi(argv[2]); frames = atoi(argv[3]);
	pkt[0] = CMD_HELLO; card_command(&k, pkt, 1);
	printf("status: %.4s, %d views\n", (char *)k.rom + ROM_STATUS, k.rom[ROM_STATUS + 12]);
	pkt[0] = CMD_VIEW; pkt[1] = (uint8_t)view; card_command(&k, pkt, 2);
	printf("view: %s\n", (char *)k.rom + ROM_STATUS + 16);
	seq = k.rom[ROM_STATUS + 4];
	for (i = 0; i < frames; i++) {
		const uint8_t *s = k.rom + ROM_STATUS;
		int which, n = 0;
		pkt[0] = CMD_FRAME; pkt[1] = 0; pkt[2] = 0; pkt[3] = (uint8_t)(i ? 1 : 0); pkt[4] = 8; pkt[5] = 0;
		pkt[6] = 1200 & 255; pkt[7] = 1200 >> 8;
		card_command(&k, pkt, 8);
		if (s[4] == seq) { printf("no new frame\n"); return 1; }      /* the CPC waits for this */
		seq = s[4]; which = s[5];
		memcpy(ram, k.rom + (which ? ROM_LIST1 : ROM_LIST0), sizeof ram);   /* LDIR out of the ROM */
		memset(scr, 0, sizeof scr);
		draw_list(ram);
		xline(296 - (int8_t)s[10] / 2, 182 - (int8_t)s[11] / 2, 296 + (int8_t)s[10], 182 + (int8_t)s[11], 3);
		while (ram[n] != DL_END && n < (int)sizeof ram) n += (ram[n] & 0xC0) == DL_PEN ? 1 : 3;
		printf("frame %d: seq %d, list %d, %d lines, %d bytes, %d m up, compass %d, %d\n", i, seq, which,
		       s[6] | s[7] << 8, n + 1, s[8] | s[9] << 8, (int8_t)s[10], (int8_t)s[11]);
		if (argc > 4) {
			sprintf(fn, "%s%03d.ppm", argv[4], i); save_ppm(fn);
			if (i == 0) { sprintf(fn, "%s.LST", argv[4]); f = fopen(fn, "wb"); fwrite(ram, 1, n + 1, f); fclose(f); }
		}
	}
	return 0;
}

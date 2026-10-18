/* host.c - s3dpi on a PC or a Pi (Linux, Windows): AUCKLAND.DAT's frames made and drawn the
   way the CPC would draw them (the draw list decoded, XOR lines, mode 1's 4 pens) into PPM
   pictures, with the list's size and the time a frame takes.
     host AUCKLAND.DAT VIEW FRAMES [out-prefix]     e.g. host AUCKLAND.DAT 0 1 shot
   (each frame: the camera moved 8 units on, yawing right a little) */
#include "s3dpi.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static uint8_t scr[200][320];
static void xline(int x0, int y0, int x1, int y1, int pen)    /* Bresenham, XOR (as gfx_line) */
{
	int dx = abs(x1 - x0), dy = -abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1, e = dx + dy;
	for (;;) {
		scr[y0][x0] ^= (uint8_t)pen;
		if (x0 == x1 && y0 == y1) break;
		int e2 = 2 * e;
		if (e2 >= dy) { e += dy; x0 += sx; }
		if (e2 <= dx) { e += dx; y0 += sy; }
	}
}
/* the CPC's side: the list drawn - what the Z80 loop does */
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
	S3dWorld w; S3dCam c; S3dStats st;
	static uint8_t list[7680];
	FILE *f; uint8_t *d; long size; int view, frames, i, n, dx, dy; char nm[32], fn[256];
	clock_t t0;
	if (argc < 4) { fprintf(stderr, "host AUCKLAND.DAT VIEW FRAMES [out-prefix]\n"); return 1; }
	f = fopen(argv[1], "rb"); if (!f) { perror(argv[1]); return 1; }
	fseek(f, 0, SEEK_END); size = ftell(f); fseek(f, 0, SEEK_SET);
	d = (uint8_t *)malloc(size); if (fread(d, 1, size, f) != (size_t)size) return 1; fclose(f);
	if (s3d_open(&w, d, (uint32_t)size)) { fprintf(stderr, "not S3D data\n"); return 1; }
	view = atoi(argv[2]); frames = atoi(argv[3]);
	memset(&c, 0, sizeof c); c.budget = 1200;
	s3d_view(&w, &c, view);
	printf("view %d: %s, %d x %d tiles\n", view + 1, s3d_view_name(&w, view, nm), w.nx, w.nz);
	for (i = 0; i < frames; i++) {
		if (i) s3d_steer(&w, &c, 0, 0, i % 4 == 0 ? 1 : 0, 8);
		t0 = clock();
		n = s3d_frame(&w, &c, list, sizeof list, &st);
		t0 = clock() - t0;
		memset(scr, 0, sizeof scr);
		draw_list(list);
		s3d_compass(&w, &c, &dx, &dy);
		xline(296 - dx / 2, 182 - dy / 2, 296 + dx, 182 + dy, 3);
		printf("frame %d: %d lines, %d points, %d bytes%s, %.2f ms, %d m up, compass %d, %d\n", i, st.lines, st.points, n,
		       st.full ? " (list full)" : "", 1000.0 * t0 / CLOCKS_PER_SEC, s3d_altitude(&c), dx, dy);
		if (argc > 4) { sprintf(fn, "%s%03d.ppm", argv[4], i); save_ppm(fn); }
	}
	return 0;
}

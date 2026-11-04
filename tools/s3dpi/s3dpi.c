/* s3dpi.c - the AUCKLAND engine in C (see s3dpi.h). The .DAT format: tools/s3dmake/s3dmake.html
   (the top of its script). Units: world 0.5 m; a tile's local steps 2 m (4 units). */
#include "s3dpi.h"
#include <string.h>

#define TILE 768                         /* units */
#define BLK 16384

static int r16(const uint8_t *p) { return (int16_t)(p[0] | (p[1] << 8)); }
static int u16(const uint8_t *p) { return p[0] | (p[1] << 8); }

int s3d_open(S3dWorld *w, const uint8_t *d, uint32_t size)
{
	memset(w, 0, sizeof *w);
	if (size < BLK || memcmp(d, "S3D1", 4) != 0) return -1;
	w->d = d; w->size = size;
	w->nx = u16(d + 4); w->nz = u16(d + 6);
	w->x0 = r16(d + 10); w->z0 = r16(d + 12);
	w->nlm = u16(d + 22); w->lm = d + u16(d + 24);
	w->nviews = u16(d + 28); w->views = d + u16(d + 30);
	w->cx = r16(d + 48); w->cz = r16(d + 50);
	return 0;
}

void s3d_view(const S3dWorld *w, S3dCam *c, int n)
{
	const uint8_t *v;
	int fx = 0, fz = 16384, x = 0, z = 0, h = 240;
	if (n >= 0 && n < w->nviews) {
		v = w->views + n * 32;
		x = r16(v); z = r16(v + 2); h = r16(v + 4); fx = r16(v + 6); fz = r16(v + 8);
	}
	c->b[0] = (int16_t)fz; c->b[1] = 0; c->b[2] = (int16_t)-fx;
	c->b[3] = 0; c->b[4] = 16384; c->b[5] = 0;
	c->b[6] = (int16_t)fx; c->b[7] = 0; c->b[8] = (int16_t)fz;
	c->qx = (int32_t)x * 256; c->qy = (int32_t)h * 256; c->qz = (int32_t)z * 256;
	if (c->budget <= 0) c->budget = 1200;
}

const char *s3d_view_name(const S3dWorld *w, int n, char *buf)
{
	int i;
	buf[0] = 0;
	if (n < 0 || n >= w->nviews) return buf;
	for (i = 0; i < 22 && w->views[n * 32 + 10 + i]; i++) buf[i] = (char)w->views[n * 32 + 10 + i];
	buf[i] = 0;
	return buf;
}

/* ---- the camera: 2 degree turns, kept square and of length 1 */
static void pair(int16_t *a, int16_t *b, int s)        /* A = A cos + B sin, B = B cos - A sin */
{
	const int32_t co = 16374;
	int i;
	for (i = 0; i < 3; i++) {
		int32_t na = ((int32_t)a[i] * co + (int32_t)b[i] * s) >> 14;
		int32_t nb = ((int32_t)b[i] * co - (int32_t)a[i] * s) >> 14;
		a[i] = (int16_t)na; b[i] = (int16_t)nb;
	}
}
static int32_t dot3(const int16_t *a, const int16_t *b) { return ((int32_t)a[0] * b[0] + (int32_t)a[1] * b[1] + (int32_t)a[2] * b[2]) >> 14; }
static void unit(int16_t *v)                            /* times (3 - |v|^2) / 2, twice */
{
	int k, i;
	for (k = 0; k < 2; k++) {
		int32_t m = (3 * 16384 - dot3(v, v)) / 2;
		for (i = 0; i < 3; i++) v[i] = (int16_t)(((int32_t)v[i] * m) >> 14);
	}
}
void s3d_steer(const S3dWorld *w, S3dCam *c, int pitch, int roll, int yaw, int speed)
{
	int16_t *R = c->b, *U = c->b + 3, *F = c->b + 6;
	int32_t d, lo, hi;
	int i;
	if (pitch) pair(F, U, pitch > 0 ? 572 : -572);     /* climb: forward towards up */
	if (roll) pair(U, R, roll > 0 ? 572 : -572);       /* roll right: up towards right */
	if (yaw) pair(F, R, yaw > 0 ? 572 : -572);         /* yaw right: forward towards right */
	unit(F);
	d = dot3(R, F);
	for (i = 0; i < 3; i++) R[i] = (int16_t)(R[i] - ((d * F[i]) >> 14));
	unit(R);
	U[0] = (int16_t)(((int32_t)F[1] * R[2] - (int32_t)F[2] * R[1]) >> 14);   /* up = forward x right */
	U[1] = (int16_t)(((int32_t)F[2] * R[0] - (int32_t)F[0] * R[2]) >> 14);
	U[2] = (int16_t)(((int32_t)F[0] * R[1] - (int32_t)F[1] * R[0]) >> 14);
	c->qx += (F[0] * speed) >> 6; c->qy += (F[1] * speed) >> 6; c->qz += (F[2] * speed) >> 6;
	lo = (w->x0 + 64) * 256; hi = (w->x0 + w->nx * TILE - 64) * 256;
	if (c->qx < lo) c->qx = lo;
	if (c->qx > hi) c->qx = hi;
	lo = (w->z0 + 64) * 256; hi = (w->z0 + w->nz * TILE - 64) * 256;
	if (c->qz < lo) c->qz = lo;
	if (c->qz > hi) c->qz = hi;
	if (c->qy < 8 * 256) c->qy = 8 * 256;
	if (c->qy > 4000 * 256) c->qy = 4000 * 256;
}
int s3d_altitude(const S3dCam *c) { return (c->qy >> 8) / 2; }

/* ---- a frame */
typedef struct { int32_t x, y, z; } V3;
typedef struct {
	const S3dWorld *w; const S3dCam *c;
	uint8_t *o; int n, max, full;
	int px, py, pen, pendn;         /* the pen: where (px -1: unknown), its colour */
	int lines, points, budget, tcap;
	int32_t ex[3], ey[3], ez[3];    /* a local step's camera-space change: x, height, z (1 unit, Q14) */
	V3 tm;                          /* the tile's middle, camera space */
} Fr;

static void put(Fr *f, int b) { f->o[f->n++] = (uint8_t)b; }
static int room(Fr *f, int k) { if (f->n + k + 1 > f->max) { f->full = 1; return 0; } return 1; }
static void setpen(Fr *f, int p) { if (p != f->pen && room(f, 1)) { put(f, DL_PEN | p); f->pen = p; } }
static void point(Fr *f, int op, int x, int y)
{
	if (!room(f, 3)) return;
	put(f, op | (x >> 8)); put(f, x & 255); put(f, y); f->points++;
	f->px = x; f->py = y;
}
static void seg2(Fr *f, int x0, int y0, int x1, int y1)      /* a screen line, both ends on it */
{
	if (f->px == x1 && f->py == y1) { int t = x0; x0 = x1; x1 = t; t = y0; y0 = y1; y1 = t; }
	if (f->px != x0 || f->py != y0) point(f, DL_MOVE, x0, y0);
	point(f, DL_DRAW, x1, y1);
	f->lines++;
}

/* inside tests: >= 0 inside (near Z >= 16; X <= Z; -X <= Z; 4Y <= 3Z; -4Y <= 3Z) */
static int32_t side(const V3 *p, int k)
{
	switch (k) {
	case 0: return p->z - 16;
	case 1: return p->z - p->x;
	case 2: return p->z + p->x;
	case 3: return 3 * p->z - 4 * p->y;
	default: return 3 * p->z + 4 * p->y;
	}
}
static int ocode(const V3 *p) { int k, o = 0; for (k = 0; k < 5; k++) if (side(p, k) < 0) o |= 1 << k; return o; }
static void proj(const V3 *p, int *sx, int *sy)
{
	int32_t x = 160 + (int32_t)((int64_t)p->x * 160 / p->z), y = 100 - (int32_t)((int64_t)p->y * 133 / p->z);
	*sx = x < 0 ? 0 : x > 319 ? 319 : (int)x;
	*sy = y < 0 ? 0 : y > 199 ? 199 : (int)y;
}
static void edge(Fr *f, V3 a, V3 b)                          /* a 3D edge: clipped, projected, drawn */
{
	int oa = ocode(&a), ob = ocode(&b), k, x0, y0, x1, y1;
	if (oa & ob) return;
	if (oa | ob) {
		for (k = 0; k < 5; k++) {
			int32_t da = side(&a, k), db = side(&b, k);
			if (da >= 0 && db >= 0) continue;
			if (da < 0 && db < 0) return;
			{
				int64_t t = (int64_t)da * 65536 / (da - db);          /* where it crosses, 0-65536 */
				V3 q;
				q.x = a.x + (int32_t)(((int64_t)(b.x - a.x) * t) >> 16);
				q.y = a.y + (int32_t)(((int64_t)(b.y - a.y) * t) >> 16);
				q.z = a.z + (int32_t)(((int64_t)(b.z - a.z) * t) >> 16);
				if (da < 0) a = q; else b = q;
			}
		}
		if (a.z < 16 || b.z < 16) return;
	}
	proj(&a, &x0, &y0); proj(&b, &x1, &y1);
	seg2(f, x0, y0, x1, y1);
}
static V3 vtx(const Fr *f, int lx, int h, int lz)            /* a local point (2 m steps) in camera space */
{
	V3 p;
	int32_t x = lx * 4, y = h * 4, z = lz * 4;
	p.x = f->tm.x + ((x * f->ex[0] + y * f->ey[0] + z * f->ez[0]) >> 14);
	p.y = f->tm.y + ((x * f->ex[1] + y * f->ey[1] + z * f->ez[1]) >> 14);
	p.z = f->tm.z + ((x * f->ex[2] + y * f->ey[2] + z * f->ez[2]) >> 14);
	return p;
}
static int budget_left(Fr *f) { return f->lines < f->budget && !f->full; }

static void building(Fr *f, const uint8_t *p, int lod)
{
	int n = p[0], h = p[1], i, all = 0x1F, k;
	V3 g[12], t[12];
	if (n < 2 || n > 12) return;
	for (i = 0; i < n; i++) {
		g[i] = vtx(f, (int8_t)p[2 + 2 * i], 0, (int8_t)p[3 + 2 * i]);
		t[i] = vtx(f, (int8_t)p[2 + 2 * i], h, (int8_t)p[3 + 2 * i]);
		all &= ocode(&g[i]) & ocode(&t[i]);
	}
	if (all) return;                                        /* wholly out of view */
	setpen(f, 1);
	for (i = 0; i < n; i++) {
		k = (i + 1) % n;
		if (lod & 1) edge(f, g[i], g[k]);
		edge(f, t[i], t[k]);
		if (lod & 2) edge(f, g[i], t[i]);
	}
}
static const uint8_t *line_pts(Fr *f, const uint8_t *p, int threed, int skipminor)
{
	int n = p[0], type = p[1], i, st = threed ? 3 : 2;
	const uint8_t *q = p + 2;
	V3 a, b;
	if (!(skipminor && type == 2) && n > 1) {
		setpen(f, type == 10 ? 2 : (type >= 4 && type <= 6) ? 3 : 1);
		a = vtx(f, (int8_t)q[0], threed ? q[2] : 0, (int8_t)q[1]);
		for (i = 1; i < n; i++) {
			b = vtx(f, (int8_t)q[i * st], threed ? q[i * st + 2] : 0, (int8_t)q[i * st + 1]);
			edge(f, a, b);
			a = b;
		}
	}
	return q + n * st;
}
static void tree(Fr *f, const uint8_t *p)
{
	V3 a = vtx(f, (int8_t)p[0], 0, (int8_t)p[1]), b = vtx(f, (int8_t)p[0], 4, (int8_t)p[1]);
	int x0, y0, x1, y1, dx, dy, mx, my, qx, qy;
	if (ocode(&a) || ocode(&b)) return;
	proj(&a, &x0, &y0); proj(&b, &x1, &y1);
	dx = x1 - x0; dy = y1 - y0;
	if ((dy < 0 ? -dy : dy) < 4) return;                    /* too small to see */
	mx = x0 + dx / 3; my = y0 + dy / 3;                     /* the crown's foot: a third up */
	qx = -dy / 4; qy = dx / 4;                              /* half its width */
	if (mx + qx < 0 || mx + qx > 319 || mx - qx < 0 || mx - qx > 319) return;
	if (my + qy < 0 || my + qy > 199 || my - qy < 0 || my - qy > 199) return;
	setpen(f, 3);
	seg2(f, x0, y0, mx, my);                                /* the trunk */
	seg2(f, mx + qx, my + qy, x1, y1);                      /* the crown */
	seg2(f, x1, y1, mx - qx, my - qy);
	seg2(f, mx - qx, my - qy, mx + qx, my + qy);
}

/* a tile: mode 0 all its distance allows, 1 its 3D lines only (a landmark further away) */
static void tile(Fr *f, int ti, int tj, int mode)
{
	const S3dWorld *w = f->w;
	const uint8_t *e, *t, *p;
	int32_t dx, dy, dz;
	int nb, i, lod, tz, start;
	if (ti < 0 || tj < 0 || ti >= w->nx || tj >= w->nz) return;
	e = w->d + 64 + 3 * (tj * w->nx + ti);
	if (!e[0]) return;
	t = w->d + (uint32_t)e[0] * BLK + u16(e + 1);
	dx = w->x0 + ti * TILE + TILE / 2 - (f->c->qx >> 8);
	dy = -(f->c->qy >> 8);
	dz = w->z0 + tj * TILE + TILE / 2 - (f->c->qz >> 8);
	f->tm.x = (int32_t)(((int64_t)f->c->b[0] * dx + (int64_t)f->c->b[1] * dy + (int64_t)f->c->b[2] * dz) >> 14);
	f->tm.y = (int32_t)(((int64_t)f->c->b[3] * dx + (int64_t)f->c->b[4] * dy + (int64_t)f->c->b[5] * dz) >> 14);
	f->tm.z = (int32_t)(((int64_t)f->c->b[6] * dx + (int64_t)f->c->b[7] * dy + (int64_t)f->c->b[8] * dz) >> 14);
	tz = f->tm.z;
	if (tz < -600) return;                                  /* behind */
	if (mode == 0 && tz > 3800) return;                     /* too far (1.9 km) */
	if ((f->tm.x < 0 ? -f->tm.x : f->tm.x) - tz > 900) return;   /* off to the side */
	p = t + 16;
	if (mode == 0) {
		/* the buildings: big always, middle nearer than 2000 units, small than 800 */
		nb = u16(t);
		if (tz <= 2000) nb += u16(t + 2);
		if (tz < 800) nb += u16(t + 4);
		lod = tz < 400 ? 3 : tz < 1200 ? 2 : 0;
		f->tcap = f->lines + f->budget / 4;
		for (i = 0; i < nb && budget_left(f) && f->lines < f->tcap; i++) { building(f, p, lod); p += 2 + 2 * p[0]; }
		/* (the rest skipped) */
		p = t + 16;
		nb = u16(t) + u16(t + 2) + u16(t + 4);
		for (i = 0; i < nb; i++) p += 2 + 2 * p[0];
		/* the ground lines: none past 3000; no minor roads past 1600 */
		if (tz < 3000) {
			f->tcap = f->lines + f->budget / 8;
			for (i = 0; i < u16(t + 6) && budget_left(f) && f->lines < f->tcap; i++) p = line_pts(f, p, 0, tz >= 1600);
		}
	}
	/* the 3D lines (landmarks, bridges): not in the budget */
	start = f->lines;
	p = t + u16(t + 12);
	for (i = 0; i < u16(t + 8) && !f->full; i++) p = line_pts(f, p, 1, 0);
	f->budget += f->lines - start;                          /* (they don't use up the budget) */
	/* the trees, nearer than 700 */
	if (mode == 0 && tz < 700) {
		p = t + u16(t + 14);
		for (i = 0; i < u16(t + 10) && budget_left(f); i++) { tree(f, p); p += 2; }
	}
}

int s3d_frame(const S3dWorld *w, const S3dCam *c, uint8_t *out, int max, S3dStats *st)
{
	static int8_t ring[49][2];
	static int made;
	Fr f;
	int i, ci, cj, k;
	if (!made) {                                            /* the 7 x 7, nearest first */
		int n = 0, d, a, b;
		for (d = 0; d <= 18; d++)
			for (a = -3; a <= 3; a++)
				for (b = -3; b <= 3; b++)
					if (a * a + b * b == d) { ring[n][0] = (int8_t)a; ring[n][1] = (int8_t)b; n++; }
		made = 1;
	}
	memset(&f, 0, sizeof f);
	f.w = w; f.c = c; f.o = out; f.max = max; f.px = -1; f.budget = c->budget;
	for (i = 0; i < 3; i++) {                               /* a unit step's camera-space change */
		f.ex[i] = c->b[i * 3 + 0]; f.ey[i] = c->b[i * 3 + 1]; f.ez[i] = c->b[i * 3 + 2];
	}
	ci = ((c->qx >> 8) - w->x0) / TILE; cj = ((c->qz >> 8) - w->z0) / TILE;
	/* the landmark tiles, 4 to 9 tiles away (the far ones to 29): their 3D lines */
	for (i = 0; i < w->nlm && i < 256; i++) {
		unsigned t = u16(w->lm + 2 * i), far = t & 0x8000;
		int ti, tj, dd;
		t &= 0x7FFF; ti = t % w->nx; tj = t / w->nx;
		dd = ti - ci < 0 ? ci - ti : ti - ci;
		k = tj - cj < 0 ? cj - tj : tj - cj;
		if (k > dd) dd = k;
		if (dd >= 4 && dd < (far ? 30 : 10)) tile(&f, ti, tj, 1);
	}
	for (i = 0; i < 49 && budget_left(&f); i++) tile(&f, ci + ring[i][0], cj + ring[i][1], 0);
	if (f.n < max) put(&f, DL_END); else { f.o[max - 1] = DL_END; f.n = max; }
	if (st) { st->lines = f.lines; st->points = f.points; st->bytes = f.n; st->full = f.full; }
	return f.n;
}

void s3d_compass(const S3dWorld *w, const S3dCam *c, int *dx, int *dy)
{
	int64_t vx = w->cx - (c->qx >> 8), vz = w->cz - (c->qz >> 8);
	int64_t a = (c->b[0] * vx + c->b[2] * vz) >> 14, b = (c->b[6] * vx + c->b[8] * vz) >> 14, m;
	m = (a < 0 ? -a : a) > (b < 0 ? -b : b) ? (a < 0 ? -a : a) : (b < 0 ? -b : b);
	if (m == 0) { *dx = *dy = 0; return; }
	*dx = (int)(a * 15 / m); *dy = (int)(-b * 15 / m);
}

/* cpcimg - hard disc images for WinAPE's IDE drive (and UniDOS's IDE node): a raw .IMG (the
   disc's sectors, no header) with an MBR and one FAT16 / FAT32 partition, 8.3 names (UniDOS's
   FatFs has long names off). Files in and out, folders.

     cpcimg new  DISC.IMG 256            a new image, 256 MB (4 .. 32768; FAT16 below 64 MB)
     cpcimg dir  DISC.IMG [FOLDER]       list the root or a folder (GAMES/ACTION)
     cpcimg put  DISC.IMG FILE... [-to FOLDER]   copy files in (a folder path is made as needed;
                                         a file already there is replaced)
     cpcimg get  DISC.IMG [FOLDER/]NAME [OUTFILE] copy a file out
     cpcimg md   DISC.IMG FOLDER         make a folder (and the ones above it)
     cpcimg del  DISC.IMG [FOLDER/]NAME  delete a file (or an empty folder)

   Builds with any C compiler: cl cpcimg.c, gcc cpcimg.c -o cpcimg (MinGW, Linux, macOS).
   Images bigger than 2 GB need 64-bit file offsets: _fseeki64 on Windows, fseeko elsewhere. */
#define _FILE_OFFSET_BITS 64
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <time.h>
#include <stdint.h>

#ifdef _WIN32
#define fseek64 _fseeki64
#else
#include <sys/types.h>
#define fseek64 fseeko
#endif

#define SEC 512
#define PART_START 2048         /* the partition at 1 MB (sector 2048), as tools do today */

typedef struct {
	FILE *f;
	int fat32;
	uint32_t part;          /* the partition's first sector */
	uint32_t spc;           /* sectors a cluster */
	uint32_t rsvd, nfats, fatsz, rootents, rootsecs, totsec;
	uint32_t fat0, root0, data0;    /* sectors (in the partition) */
	uint32_t nclus;         /* data clusters (2 .. nclus + 1) */
	uint32_t rootclus;      /* FAT32 */
	uint32_t *fat;          /* the whole FAT, in memory */
	int dirty;
} Vol;

static void die(const char *m, const char *a) { fprintf(stderr, "cpcimg: %s%s\n", m, a ? a : ""); exit(1); }
static void w16(uint8_t *p, uint32_t v) { p[0] = v & 255; p[1] = (v >> 8) & 255; }
static void w32(uint8_t *p, uint32_t v) { w16(p, v & 0xFFFF); w16(p + 2, v >> 16); }
static uint32_t r16(const uint8_t *p) { return p[0] | (p[1] << 8); }
static uint32_t r32(const uint8_t *p) { return r16(p) | (r16(p + 2) << 16); }

static void rd(Vol *v, uint32_t s, void *b, uint32_t n)
{
	if (fseek64(v->f, (int64_t)(v->part + s) * SEC, SEEK_SET) != 0 || fread(b, SEC, n, v->f) != n) die("can't read the image", 0);
}
static void wr(Vol *v, uint32_t s, const void *b, uint32_t n)
{
	if (fseek64(v->f, (int64_t)(v->part + s) * SEC, SEEK_SET) != 0 || fwrite(b, SEC, n, v->f) != n) die("can't write the image", 0);
}
static uint32_t csec(Vol *v, uint32_t c) { return v->data0 + (c - 2) * v->spc; }

/* ---- new: an empty image, MBR + one FAT partition */
static void cmd_new(const char *path, uint32_t mb)
{
	Vol v; uint8_t b[SEC]; uint32_t i, total, bytes, clusters = 0, ent, ns;
	static uint8_t zero[SEC * 64];
	if (mb < 4 || mb > 32768) die("the size is 4 .. 32768 MB", 0);
	memset(&v, 0, sizeof v);
	v.f = fopen(path, "wb+");
	if (!v.f) die("can't make ", path);
	total = mb * 2048;                       /* sectors on the disc */
	v.totsec = total - PART_START;
	v.fat32 = mb >= 64;
	bytes = mb <= 260 ? 512 : mb <= 8192 ? 4096 : mb <= 16384 ? 8192 : 16384;
	if (!v.fat32) bytes = mb < 16 ? 512 : 2048;
	v.spc = bytes / SEC;
	v.nfats = 2;
	v.rsvd = v.fat32 ? 32 : 4;
	v.rootents = v.fat32 ? 0 : 512;
	v.rootsecs = v.rootents * 32 / SEC;
	ent = v.fat32 ? 4 : 2;
	v.fatsz = 1;
	for (i = 0; i < 20; i++) {               /* the FAT's size and the clusters it maps settle */
		clusters = (v.totsec - v.rsvd - v.nfats * v.fatsz - v.rootsecs) / v.spc;
		v.fatsz = ((clusters + 2) * ent + SEC - 1) / SEC;
	}
	clusters = (v.totsec - v.rsvd - v.nfats * v.fatsz - v.rootsecs) / v.spc;
	if (v.fat32 ? clusters < 65525 : (clusters < 4085 || clusters > 65524)) die("no FAT type fits that size", 0);
	/* the whole file, zeros (the size first: the last sector) */
	memset(b, 0, SEC);
	if (fseek64(v.f, (int64_t)(total - 1) * SEC, SEEK_SET) != 0 || fwrite(b, SEC, 1, v.f) != 1) die("can't write ", path);
	/* the MBR */
	memset(b, 0, SEC);
	b[446 + 4] = v.fat32 ? 0x0C : 0x0E;      /* FAT32 LBA / FAT16 LBA */
	b[446 + 1] = 0xFE; b[446 + 2] = 0xFF; b[446 + 3] = 0xFF;   /* (CHS: beyond, LBA used) */
	b[446 + 5] = 0xFE; b[446 + 6] = 0xFF; b[446 + 7] = 0xFF;
	w32(b + 446 + 8, PART_START); w32(b + 446 + 12, v.totsec);
	b[510] = 0x55; b[511] = 0xAA;
	if (fseek64(v.f, 0, SEEK_SET) != 0 || fwrite(b, SEC, 1, v.f) != 1) die("can't write ", path);
	v.part = PART_START;
	/* the boot sector (BPB) */
	memset(b, 0, SEC);
	b[0] = 0xEB; b[1] = v.fat32 ? 0x58 : 0x3C; b[2] = 0x90;
	memcpy(b + 3, "CPCIMG  ", 8);
	w16(b + 11, SEC); b[13] = (uint8_t)v.spc; w16(b + 14, v.rsvd); b[16] = (uint8_t)v.nfats;
	w16(b + 17, v.rootents); w16(b + 19, 0); b[21] = 0xF8; w16(b + 22, v.fat32 ? 0 : v.fatsz);
	w16(b + 24, 63); w16(b + 26, 255); w32(b + 28, PART_START); w32(b + 32, v.totsec);
	if (v.fat32) {
		w32(b + 36, v.fatsz); w16(b + 40, 0); w16(b + 42, 0); w32(b + 44, 2); w16(b + 48, 1); w16(b + 50, 6);
		b[64] = 0x80; b[66] = 0x29; w32(b + 67, (uint32_t)time(0)); memcpy(b + 71, "CPC        ", 11); memcpy(b + 82, "FAT32   ", 8);
	} else {
		b[36] = 0x80; b[38] = 0x29; w32(b + 39, (uint32_t)time(0)); memcpy(b + 43, "CPC        ", 11); memcpy(b + 54, "FAT16   ", 8);
	}
	b[510] = 0x55; b[511] = 0xAA;
	wr(&v, 0, b, 1);
	if (v.fat32) {
		wr(&v, 6, b, 1);                     /* the backup */
		memset(b, 0, SEC);                   /* FSInfo */
		w32(b, 0x41615252); w32(b + 484, 0x61417272); w32(b + 488, clusters - 1); w32(b + 492, 3);
		b[510] = 0x55; b[511] = 0xAA;
		wr(&v, 1, b, 1); wr(&v, 7, b, 1);
	}
	/* the FATs (cleared; the first entries), the root folder (cleared) */
	memset(zero, 0, sizeof zero);
	ns = v.nfats * v.fatsz + v.rootsecs + (v.fat32 ? v.spc : 0);
	for (i = 0; i < ns; i += 64) wr(&v, v.rsvd + i, zero, ns - i < 64 ? ns - i : 64);
	for (i = 0; i < v.nfats; i++) {
		memset(b, 0, SEC);
		if (v.fat32) { w32(b, 0x0FFFFFF8); w32(b + 4, 0x0FFFFFFF); w32(b + 8, 0x0FFFFFFF); }
		else { w16(b, 0xFFF8); w16(b + 2, 0xFFFF); }
		wr(&v, v.rsvd + i * v.fatsz, b, 1);
	}
	fclose(v.f);
	printf("%s: %u MB, FAT%d, %u clusters of %u bytes (%u MB free)\n", path, mb, v.fat32 ? 32 : 16, clusters, bytes, (uint32_t)((uint64_t)clusters * bytes >> 20));
}

/* ---- open: the first partition (or a disc with no MBR: the volume at sector 0) */
static void vopen(Vol *v, const char *path)
{
	uint8_t b[SEC]; uint32_t i, n;
	memset(v, 0, sizeof *v);
	v->f = fopen(path, "rb+");
	if (!v->f) die("can't open ", path);
	rd(v, 0, b, 1);
	if (b[510] != 0x55 || b[511] != 0xAA) die("not a disc image (no boot signature): ", path);
	if (!(r16(b + 11) == SEC && (b[0] == 0xEB || b[0] == 0xE9))) {   /* an MBR: its first partition */
		for (i = 0; i < 4 && r32(b + 446 + i * 16 + 8) == 0; i++) ;
		if (i == 4) die("no partition in ", path);
		v->part = r32(b + 446 + i * 16 + 8);
		rd(v, 0, b, 1);
	}
	if (r16(b + 11) != SEC) die("not a FAT volume (512-byte sectors only): ", path);
	v->spc = b[13]; v->rsvd = r16(b + 14); v->nfats = b[16]; v->rootents = r16(b + 17);
	v->totsec = r16(b + 19) ? r16(b + 19) : r32(b + 32);
	v->fatsz = r16(b + 22) ? r16(b + 22) : r32(b + 36);
	v->rootsecs = (v->rootents * 32 + SEC - 1) / SEC;
	v->fat0 = v->rsvd; v->root0 = v->rsvd + v->nfats * v->fatsz; v->data0 = v->root0 + v->rootsecs;
	v->nclus = (v->totsec - v->data0) / v->spc;
	v->fat32 = v->nclus >= 65525;
	if (v->nclus < 4085) die("FAT12 isn't handled: ", path);
	v->rootclus = v->fat32 ? r32(b + 44) : 0;
	n = v->nclus + 2;
	v->fat = (uint32_t *)malloc(n * 4);
	{
		uint32_t ent = v->fat32 ? 4 : 2, secs = (n * ent + SEC - 1) / SEC, k;
		uint8_t *t = (uint8_t *)malloc(secs * SEC);
		if (!v->fat || !t) die("out of memory", 0);
		rd(v, v->fat0, t, secs);
		for (k = 0; k < n; k++) v->fat[k] = v->fat32 ? r32(t + k * 4) & 0x0FFFFFFF : r16(t + k * 2);
		free(t);
	}
}

static uint32_t eoc(Vol *v) { return v->fat32 ? 0x0FFFFFFF : 0xFFFF; }
static int is_end(Vol *v, uint32_t c) { return v->fat32 ? c >= 0x0FFFFFF8 : c >= 0xFFF8; }

static void vclose(Vol *v)
{
	if (v->dirty) {
		uint32_t n = v->nclus + 2, ent = v->fat32 ? 4 : 2, secs = (n * ent + SEC - 1) / SEC, k, fr = 0;
		uint8_t *t = (uint8_t *)calloc(v->fatsz, SEC);
		uint8_t b[SEC];
		if (!t) die("out of memory", 0);
		rd(v, v->fat0, t, v->fatsz);
		for (k = 0; k < n; k++) {
			if (v->fat32) w32(t + k * 4, (r32(t + k * 4) & 0xF0000000) | v->fat[k]); else w16(t + k * 2, v->fat[k]);
			if (k >= 2 && v->fat[k] == 0) fr++;
		}
		(void)secs;
		for (k = 0; k < v->nfats; k++) wr(v, v->fat0 + k * v->fatsz, t, v->fatsz);
		free(t);
		if (v->fat32) {                       /* FSInfo: the free count */
			rd(v, 1, b, 1);
			if (r32(b) == 0x41615252) { w32(b + 488, fr); w32(b + 492, 0xFFFFFFFF); wr(v, 1, b, 1); }
		}
	}
	fclose(v->f);
	free(v->fat);
}

static uint32_t alloc1(Vol *v, uint32_t near)
{
	uint32_t k, n = v->nclus + 2;
	for (k = near < 2 ? 2 : near; k < n; k++) if (v->fat[k] == 0) return k;
	for (k = 2; k < n; k++) if (v->fat[k] == 0) return k;
	die("the image is full", 0);
	return 0;
}
static void freechain(Vol *v, uint32_t c)
{
	while (c >= 2 && c < v->nclus + 2) { uint32_t nx = v->fat[c]; v->fat[c] = 0; v->dirty = 1; if (is_end(v, nx)) break; c = nx; }
}

/* ---- folders: entry i of folder d (d 0: the root - FAT16 its own area, FAT32 its cluster) */
static int dirent_sec(Vol *v, uint32_t d, uint32_t i, int grow, uint32_t *sec)
{
	uint32_t per = v->spc * SEC / 32, c, k;
	if (d == 0 && !v->fat32) {
		if (i >= v->rootents) return 0;
		*sec = v->root0 + i / 16; return 1;
	}
	c = d ? d : v->rootclus;
	for (k = i / per; k > 0; k--) {
		uint32_t nx = v->fat[c];
		if (is_end(v, nx)) {
			uint8_t z[SEC]; uint32_t s;
			if (!grow) return 0;
			nx = alloc1(v, c);
			v->fat[c] = nx; v->fat[nx] = eoc(v); v->dirty = 1;
			memset(z, 0, SEC);
			for (s = 0; s < v->spc; s++) wr(v, csec(v, nx) + s, z, 1);
		}
		c = nx;
	}
	*sec = csec(v, c) + (i % per) / 16; return 1;
}
static int dget(Vol *v, uint32_t d, uint32_t i, uint8_t *e)
{
	uint8_t b[SEC]; uint32_t s;
	if (!dirent_sec(v, d, i, 0, &s)) return 0;
	rd(v, s, b, 1); memcpy(e, b + (i % 16) * 32, 32); return 1;
}
static void dput(Vol *v, uint32_t d, uint32_t i, const uint8_t *e)
{
	uint8_t b[SEC]; uint32_t s;
	if (!dirent_sec(v, d, i, 1, &s)) die("the root folder is full (FAT16: 512 entries) - use a folder", 0);
	rd(v, s, b, 1); memcpy(b + (i % 16) * 32, e, 32); wr(v, s, b, 1);
}
static uint32_t eclus(Vol *v, const uint8_t *e) { return r16(e + 26) | (v->fat32 ? r16(e + 20) << 16 : 0); }

/* a name as 8.3 (11 characters, spaces): upper case; characters FAT refuses become _ */
static int name83(const char *s, char *o)
{
	const char *dot = strrchr(s, '.');
	int i, n = 0;
	memset(o, ' ', 11);
	if (!strcmp(s, ".") || !strcmp(s, "..")) { memcpy(o, s, strlen(s)); return 1; }
	for (i = 0; s[i] && (dot ? s + i < dot : 1) && n < 8; i++) {
		unsigned char c = (unsigned char)toupper((unsigned char)s[i]);
		if (c == ' ' || c == '.') continue;
		if (c < 33 || strchr("\"*+,/:;<=>?[\\]|", c) || c > 126) c = '_';
		o[n++] = c;
	}
	if (n == 0) return 0;
	if (dot) for (i = 1, n = 8; dot[i] && n < 11; i++) {
		unsigned char c = (unsigned char)toupper((unsigned char)dot[i]);
		if (c == ' ') continue;
		if (c < 33 || strchr("\"*+,/:;<=>?[\\]|.", c) || c > 126) c = '_';
		o[n++] = c;
	}
	return 1;
}
static void show83(const uint8_t *e, char *o)
{
	int i, n = 0;
	for (i = 0; i < 8 && e[i] != ' '; i++) o[n++] = e[i];
	if (e[8] != ' ') { o[n++] = '.'; for (i = 8; i < 11 && e[i] != ' '; i++) o[n++] = e[i]; }
	o[n] = 0;
}

/* find a name in folder d: its index (-1: none), the entry */
static long dfind(Vol *v, uint32_t d, const char *n11, uint8_t *e)
{
	uint32_t i;
	for (i = 0; dget(v, d, i, e); i++) {
		if (e[0] == 0) return -1;
		if (e[0] == 0xE5 || e[11] == 0x0F || (e[11] & 8)) continue;
		if (!memcmp(e, n11, 11)) return (long)i;
	}
	return -1;
}
static uint32_t dfree(Vol *v, uint32_t d)
{
	uint8_t e[32]; uint32_t i;
	for (i = 0; dget(v, d, i, e); i++) if (e[0] == 0 || e[0] == 0xE5) return i;
	return i;                                 /* past the end: dput grows the folder */
}
static void stamp(uint8_t *e)
{
	time_t t = time(0); struct tm *m = localtime(&t);
	uint32_t tm = (m->tm_hour << 11) | (m->tm_min << 5) | (m->tm_sec / 2);
	uint32_t dt = ((m->tm_year - 80) << 9) | ((m->tm_mon + 1) << 5) | m->tm_mday;
	w16(e + 14, tm); w16(e + 16, dt); w16(e + 18, dt); w16(e + 22, tm); w16(e + 24, dt);
}

/* a folder path (A/B/C): its cluster (0 the root); make: made as needed */
static uint32_t walk(Vol *v, const char *path, int make)
{
	char part[256], n11[11]; uint8_t e[32]; uint32_t d = 0; const char *p = path;
	while (*p) {
		int k = 0;
		while (*p == '/' || *p == '\\') p++;
		if (!*p) break;
		while (*p && *p != '/' && *p != '\\' && k < 255) part[k++] = *p++;
		part[k] = 0;
		if (!name83(part, n11)) die("bad folder name: ", part);
		if (dfind(v, d, n11, e) >= 0) {
			if (!(e[11] & 0x10)) die("not a folder: ", part);
			d = eclus(v, e);
			if (d == v->rootclus && v->fat32) d = 0;
		} else {
			uint32_t c, s, i; uint8_t z[SEC];
			if (!make) die("no such folder: ", part);
			c = alloc1(v, 2); v->fat[c] = eoc(v); v->dirty = 1;
			memset(z, 0, SEC);
			for (s = 0; s < v->spc; s++) wr(v, csec(v, c) + s, z, 1);
			memset(e, 0, 32); memcpy(e, n11, 11); e[11] = 0x10; stamp(e); w16(e + 26, c & 0xFFFF); if (v->fat32) w16(e + 20, c >> 16);
			i = dfree(v, d); dput(v, d, i, e);
			memset(e, 0, 32); memset(e, ' ', 11); e[0] = '.'; e[11] = 0x10; stamp(e); w16(e + 26, c & 0xFFFF); if (v->fat32) w16(e + 20, c >> 16);
			dput(v, c, 0, e);
			memset(e, ' ', 11); e[0] = '.'; e[1] = '.'; w16(e + 26, d & 0xFFFF); w16(e + 20, v->fat32 ? d >> 16 : 0);
			dput(v, c, 1, e);
			d = c;
		}
	}
	return d;
}

static void split(const char *path, char *folder, char *name)
{
	const char *s = path + strlen(path);
	while (s > path && s[-1] != '/' && s[-1] != '\\') s--;
	memcpy(folder, path, s - path); folder[s - path] = 0;
	strcpy(name, s);
}

static void cmd_dir(const char *img, const char *folder)
{
	Vol v; uint8_t e[32]; uint32_t d, i, nf = 0; uint64_t tot = 0, fr = 0; char nm[16];
	vopen(&v, img);
	d = walk(&v, folder ? folder : "", 0);
	for (i = 0; dget(&v, d, i, e); i++) {
		if (e[0] == 0) break;
		if (e[0] == 0xE5 || e[11] == 0x0F || (e[11] & 8)) continue;
		show83(e, nm);
		if (e[11] & 0x10) printf("%-12s  <folder>\n", nm);
		else { printf("%-12s  %10u\n", nm, r32(e + 28)); tot += r32(e + 28); nf++; }
	}
	for (i = 2; i < v.nclus + 2; i++) if (v.fat[i] == 0) fr++;
	printf("%u files, %llu bytes; %llu KB free\n", nf, (unsigned long long)tot, (unsigned long long)(fr * v.spc / 2));
	vclose(&v);
}

static void put1(Vol *v, uint32_t d, const char *src)
{
	char base[256], fo[256], n11[11]; uint8_t e[32]; FILE *in; long idx; uint32_t first = 0, prev = 0, size = 0, bpc = v->spc * SEC;
	uint8_t *buf = (uint8_t *)malloc(bpc);
	split(src, fo, base);
	if (!name83(base, n11)) die("bad name: ", base);
	in = fopen(src, "rb");
	if (!in) die("can't open ", src);
	idx = dfind(v, d, n11, e);
	if (idx >= 0) {
		if (e[11] & 0x10) die("a folder has that name: ", base);
		freechain(v, eclus(v, e));
	}
	for (;;) {
		size_t n = fread(buf, 1, bpc, in);
		uint32_t c;
		if (n == 0) break;
		memset(buf + n, 0, bpc - n);
		c = alloc1(v, prev ? prev + 1 : 2);
		v->fat[c] = eoc(v); v->dirty = 1;
		if (prev) v->fat[prev] = c; else first = c;
		wr(v, csec(v, c), buf, v->spc);
		prev = c; size += (uint32_t)n;
		if (n < bpc) break;
	}
	fclose(in); free(buf);
	memset(e, 0, 32); memcpy(e, n11, 11); e[11] = 0x20; stamp(e);
	w16(e + 26, first & 0xFFFF); if (v->fat32) w16(e + 20, first >> 16); w32(e + 28, size);
	dput(v, d, idx >= 0 ? (uint32_t)idx : dfree(v, d), e);
	{ char nm[16]; show83(e, nm); printf("%s -> %s (%u bytes)\n", src, nm, size); }
}

static void cmd_get(const char *img, const char *path, const char *out)
{
	Vol v; char fo[256], nm[256], n11[11]; uint8_t e[32]; uint32_t d, c, left; FILE *o; uint8_t *buf;
	vopen(&v, img);
	split(path, fo, nm);
	d = walk(&v, fo, 0);
	if (!name83(nm, n11) || dfind(&v, d, n11, e) < 0 || (e[11] & 0x10)) die("no such file: ", path);
	o = fopen(out ? out : nm, "wb");
	if (!o) die("can't make ", out ? out : nm);
	buf = (uint8_t *)malloc(v.spc * SEC);
	for (c = eclus(&v, e), left = r32(e + 28); left > 0 && c >= 2 && c < v.nclus + 2; c = v.fat[c]) {
		uint32_t n = left < v.spc * SEC ? left : v.spc * SEC;
		rd(&v, csec(&v, c), buf, v.spc);
		fwrite(buf, 1, n, o); left -= n;
		if (is_end(&v, v.fat[c])) break;
	}
	fclose(o); free(buf);
	printf("%s -> %s (%u bytes)\n", path, out ? out : nm, r32(e + 28) - left);
	vclose(&v);
}

static void cmd_del(const char *img, const char *path)
{
	Vol v; char fo[256], nm[256], n11[11]; uint8_t e[32], f[32]; uint32_t d, i; long idx;
	vopen(&v, img);
	split(path, fo, nm);
	d = walk(&v, fo, 0);
	if (!name83(nm, n11) || (idx = dfind(&v, d, n11, e)) < 0) die("no such file or folder: ", path);
	if (e[11] & 0x10) {
		for (i = 2; dget(&v, eclus(&v, e), i, f); i++) {
			if (f[0] == 0) break;
			if (f[0] != 0xE5) die("the folder isn't empty: ", path);
		}
	}
	freechain(&v, eclus(&v, e));
	e[0] = 0xE5; dput(&v, d, (uint32_t)idx, e);
	printf("%s deleted\n", path);
	vclose(&v);
}

int main(int argc, char **argv)
{
	if (argc >= 4 && !strcmp(argv[1], "new")) { cmd_new(argv[2], (uint32_t)atoi(argv[3])); return 0; }
	if (argc >= 3 && !strcmp(argv[1], "dir")) { cmd_dir(argv[2], argc > 3 ? argv[3] : 0); return 0; }
	if (argc >= 4 && !strcmp(argv[1], "put")) {
		Vol v; const char *to = ""; int i, last = argc;
		for (i = 3; i < argc - 1; i++) if (!strcmp(argv[i], "-to")) { to = argv[i + 1]; last = i; break; }
		vopen(&v, argv[2]);
		{ uint32_t d = walk(&v, to, 1); for (i = 3; i < last; i++) put1(&v, d, argv[i]); }
		vclose(&v); return 0;
	}
	if (argc >= 4 && !strcmp(argv[1], "get")) { cmd_get(argv[2], argv[3], argc > 4 ? argv[4] : 0); return 0; }
	if (argc >= 4 && !strcmp(argv[1], "md")) { Vol v; vopen(&v, argv[2]); walk(&v, argv[3], 1); vclose(&v); printf("%s made\n", argv[3]); return 0; }
	if (argc >= 4 && !strcmp(argv[1], "del")) { cmd_del(argv[2], argv[3]); return 0; }
	fprintf(stderr,
		"cpcimg - hard disc images for WinAPE's IDE drive and UniDOS (FAT16 / FAT32, 8.3 names)\n"
		"  cpcimg new  DISC.IMG MB                  a new image (4 .. 32768 MB; FAT16 below 64)\n"
		"  cpcimg dir  DISC.IMG [FOLDER]            list the root or a folder\n"
		"  cpcimg put  DISC.IMG FILE... [-to FOLDER] copy files in (folders made as needed)\n"
		"  cpcimg get  DISC.IMG [FOLDER/]NAME [OUT] copy a file out\n"
		"  cpcimg md   DISC.IMG FOLDER              make a folder\n"
		"  cpcimg del  DISC.IMG [FOLDER/]NAME       delete a file or an empty folder\n");
	return 1;
}

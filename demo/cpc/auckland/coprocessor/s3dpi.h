/* s3dpi - the AUCKLAND (STATE3D) engine in C, for a coprocessor next to a CPC: the data
   (AUCKLAND.DAT, 3.8 MB) is kept on the coprocessor; each frame the CPC sends its keys, the
   coprocessor moves the camera, culls, transforms, clips and projects, and hands back the
   frame as a list of screen lines (3 bytes a point) that the CPC draws with its own line
   routine. Integer arithmetic only (no FPU needed: an RP2040 does it at full speed).
   The same rules as the Z80 engine (src/bas/auckland/S3d.cls): tiles of 384 m, the 7 x 7
   round the camera nearest first, landmark tiles further, a line budget, the same LOD
   distances, the same projection (sx = 160 + X * 160 / Z, sy = 100 - Y * 133 / Z).
   The draw list and the link: PROTOCOL.TXT. */
#ifndef S3DPI_H
#define S3DPI_H
#include <stdint.h>

/* draw list: points of 3 bytes, ops in the first byte's top bits */
#define DL_MOVE   0x00    /* 00 0000 0x  xxxxxxxx yyyyyyyy: pen to (x, y), x 0-319, y 0-199 */
#define DL_DRAW   0x40    /* 01 0000 0x  ...              : a line from the pen to (x, y)    */
#define DL_PEN    0x80    /* 10 0000 pp (1 byte): the pen (1-3)                              */
#define DL_END    0xC0    /* 11 000000  (1 byte): the end of the frame's list                */

typedef struct {
	const uint8_t *d;     /* the whole .DAT (mapped: a file on a Pi, flash on a Pico) */
	uint32_t size;
	int nx, nz, x0, z0;   /* tiles across, north; the south-west corner (world units, 0.5 m) */
	int nlm, nviews;
	const uint8_t *lm, *views;
	int cx, cz;           /* the city's centre (the compass) */
} S3dWorld;

typedef struct {
	int32_t qx, qy, qz;   /* where: world units * 256 */
	int16_t b[9];         /* right, up, forward: 16384 = 1 (as the Z80's) */
	int budget;           /* lines a frame at most */
} S3dCam;

typedef struct {          /* what a frame came to */
	int lines, points, bytes;
	int full;             /* the list filled up before the frame was done */
} S3dStats;

int  s3d_open(S3dWorld *w, const uint8_t *data, uint32_t size);     /* 0 ok, else not S3D data */
void s3d_view(const S3dWorld *w, S3dCam *c, int view);               /* the camera at view n (0-) */
const char *s3d_view_name(const S3dWorld *w, int view, char *buf);  /* (22 characters at most) */
/* the keys: pitch, roll, yaw -1 / 0 / 1 (2 degrees), speed (world units a frame) */
void s3d_steer(const S3dWorld *w, S3dCam *c, int pitch, int roll, int yaw, int speed);
/* the frame into out (max bytes, ending DL_END); returns the bytes */
int  s3d_frame(const S3dWorld *w, const S3dCam *c, uint8_t *out, int max, S3dStats *st);
/* the compass: the way to the centre on the screen, from above (dx right, dy down), -15..15 */
void s3d_compass(const S3dWorld *w, const S3dCam *c, int *dx, int *dy);
int  s3d_altitude(const S3dCam *c);                                  /* metres */
#endif

/* card.c - the coprocessor side of the AUCKLAND link: commands in, the status block and the
   draw lists written into the 16K the CPC reads as a ROM (PROTOCOL.TXT) */
#include "card.h"
#include <string.h>

static void w16(uint8_t *p, int v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); }

static void status(Card *k, const char *msg, int lines)
{
	uint8_t *s = k->rom + ROM_STATUS;
	int dx, dy, i;
	memcpy(s, "S3DP", 4);
	s[5] = k->which;
	w16(s + 6, lines);
	w16(s + 8, s3d_altitude(&k->c));
	s3d_compass(&k->w, &k->c, &dx, &dy);
	s[10] = (uint8_t)(int8_t)dx; s[11] = (uint8_t)(int8_t)dy;
	s[12] = (uint8_t)k->w.nviews;
	if (msg) {
		for (i = 0; i < 24; i++) s[16 + i] = 0;
		for (i = 0; i < 24 && msg[i]; i++) s[16 + i] = (uint8_t)msg[i];
	}
	s[4] = k->seq;                                       /* last: the CPC watches it change */
}

int card_init(Card *k, const uint8_t *data, uint32_t size)
{
	memset(k, 0, sizeof *k);
	if (s3d_open(&k->w, data, size)) return -1;
	k->c.budget = 1200;
	s3d_view(&k->w, &k->c, 0);
	k->rom[ROM_LIST0] = k->rom[ROM_LIST1] = DL_END;
	status(k, "", 0);
	return 0;
}

void card_command(Card *k, const uint8_t *cmd, int len)
{
	char nm[32];
	if (len < 1) return;
	switch (cmd[0]) {
	case CMD_HELLO:
		status(k, "AUCKLAND", 0);
		break;
	case CMD_VIEW:
		if (len >= 2) { s3d_view(&k->w, &k->c, cmd[1]); status(k, s3d_view_name(&k->w, cmd[1], nm), 0); }
		break;
	case CMD_NAME:
		if (len >= 2) status(k, s3d_view_name(&k->w, cmd[1], nm), 0);
		break;
	case CMD_FRAME:
		if (len >= 8) {
			S3dStats st;
			int i, n = 1 + cmd[5];
			uint8_t *list;
			k->c.budget = cmd[6] | (cmd[7] << 8);
			for (i = 0; i < n; i++) s3d_steer(&k->w, &k->c, (int8_t)cmd[1], (int8_t)cmd[2], (int8_t)cmd[3], cmd[4]);
			k->which ^= 1;                               /* the list the CPC isn't reading */
			list = k->rom + (k->which ? ROM_LIST1 : ROM_LIST0);
			s3d_frame(&k->w, &k->c, list, LIST_MAX, &st);
			k->seq++;
			status(k, 0, st.lines);
		}
		break;
	}
}

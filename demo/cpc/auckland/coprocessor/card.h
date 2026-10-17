/* card.h - the coprocessor side of the AUCKLAND link (PROTOCOL.TXT): the 16K the CPC sees as
   a ROM (written here, read there), the commands the CPC sends. Hardware-free: the card's
   firmware hands each command packet to card_command() and maps rom[] into the CPC's ROM
   window (on the CPC-CPLINK2 / an M4-like card: the ROM image it serves). */
#ifndef CARD_H
#define CARD_H
#include <stdint.h>
#include "s3dpi.h"

#define ROM_STATUS 0x0100   /* (#C100 on the CPC) the status block */
#define ROM_LIST0  0x0200   /* (#C200) a draw list, 7680 bytes */
#define ROM_LIST1  0x2000   /* (#E000) the other */
#define LIST_MAX   7680

#define CMD_HELLO  'H'      /* -: the status block filled in (magic, views) */
#define CMD_VIEW   'V'      /* n: the camera at view n (0-), its name in the message */
#define CMD_FRAME  'F'      /* pitch, roll, yaw (s8 -1/0/1), speed (u8, units a frame), skip (u8),
                               budget (u16): moved (1 + skip times), the next list made */
#define CMD_NAME   'N'      /* n: view n's name in the message */

typedef struct {
	uint8_t rom[16384];     /* what the CPC reads at #C000-#FFFF */
	S3dWorld w;
	S3dCam c;
	uint8_t seq, which;
} Card;

int  card_init(Card *k, const uint8_t *data, uint32_t size);  /* 0 ok */
void card_command(Card *k, const uint8_t *cmd, int len);       /* one packet: cmd byte, its args */
#endif

/* ntctest.c - a test driver for NTC BASIC's MEGA65 target (added for NTC, not part of Xemu).

   Driven over two pipes: NTC_M65_FDS="in,out" (file descriptor numbers the caller passed in).
   Xemu stops at the end of every frame and reads commands, one a line, until "run":
     run N                 run N frames, then stop and read commands again ("ok" is written then)
     load ADDR HEXBYTES    write bytes into chip RAM at linear ADDR (hex)
     loadf ADDR FILE       copy FILE into chip RAM at linear ADDR
     go ADDR               the CPU carries on at ADDR (hex, in the CPU's 64K view)
     joy VALUE             joystick port 2 (hex, active low: FF = nothing; - = the host's)
     key CODE              one key into the $D610 ASCII queue (decimal)
     shot FILE             a PNG of the next frame (the whole PAL frame, borders too)
     mem ADDR LEN          answers with LEN bytes of chip RAM from linear ADDR, in hex
     hyp                   answers 1 while the hypervisor runs, else 0
     pc                    answers the CPU's PC (hex)
     frame                 answers the frame count
     exit                  quit at once
   Every command but run and exit answers one line ("ok", or the value). */
#include "xemu/emutools.h"
#include "xemu/emutools_files.h"
#include "xemu/cpu65.h"
#include "mega65.h"
#include "memory_mapper.h"
#include "hypervisor.h"
#include "input_devices.h"
#include "vic4.h"
#include "configdb.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

int ntc_joy2 = -1;
static FILE *ntc_in = NULL, *ntc_out = NULL;
static unsigned int ntc_frame = 0, ntc_left = 0;
static char ntc_shot[1024];

static int hexval ( int c )
{
	if (c >= '0' && c <= '9') return c - '0';
	if (c >= 'a' && c <= 'f') return c - 'a' + 10;
	if (c >= 'A' && c <= 'F') return c - 'A' + 10;
	return -1;
}

void ntctest_frame ( void )
{
	static char line[1 << 17];
	if (!ntc_in) {
		static int tried = 0;
		const char *fds = getenv("NTC_M65_FDS");
		int fi, fo;
		if (tried || !fds || sscanf(fds, "%d,%d", &fi, &fo) != 2)
			return;
		tried = 1;
		ntc_in = fdopen(fi, "r");
		ntc_out = fdopen(fo, "w");
		if (!ntc_in || !ntc_out) {
			ntc_in = NULL;
			return;
		}
	}
	ntc_frame++;
	if (!vic4_registered_screenshot_request && configdb.screenshot_and_exit == ntc_shot)
		configdb.screenshot_and_exit = NULL;		// the last shot is taken
	if (ntc_left) {
		ntc_left--;
		if (ntc_left)
			return;
		fputs("ok\n", ntc_out);
		fflush(ntc_out);
	}
	while (fgets(line, sizeof line, ntc_in)) {
		char cmd[16], a1[1024], a2[1024];
		cmd[0] = a1[0] = a2[0] = 0;
		char *p = strchr(line, '\n');
		if (p) *p = 0;
		if (sscanf(line, "%15s %1023s", cmd, a1) < 1)
			continue;
		p = line + strlen(cmd);
		while (*p == ' ') p++;
		char *rest = strchr(p, ' ');
		if (rest) { while (*rest == ' ') rest++; }
		if (!strcmp(cmd, "run")) {
			ntc_left = atoi(a1);
			if (ntc_left < 1) ntc_left = 1;
			return;
		} else if (!strcmp(cmd, "exit")) {
			configdb.screenshot_and_exit = NULL;
			fflush(stderr);
			_exit(0);
		} else if (!strcmp(cmd, "load") && rest) {
			unsigned int addr = strtoul(a1, NULL, 16);
			for (; hexval(rest[0]) >= 0 && hexval(rest[1]) >= 0 && addr < sizeof(main_ram); rest += 2)
				main_ram[addr++] = hexval(rest[0]) * 16 + hexval(rest[1]);
			fputs("ok\n", ntc_out);
		} else if (!strcmp(cmd, "loadf") && rest) {
			unsigned int addr = strtoul(a1, NULL, 16);
			FILE *f = fopen(rest, "rb");
			size_t n = 0;
			if (f) {
				n = fread(main_ram + addr, 1, sizeof(main_ram) - addr, f);
				fclose(f);
			}
			fprintf(ntc_out, "%u\n", (unsigned)n);
		} else if (!strcmp(cmd, "go")) {
			cpu65.pc = strtoul(a1, NULL, 16) & 0xFFFF;
			fputs("ok\n", ntc_out);
		} else if (!strcmp(cmd, "joy")) {
			ntc_joy2 = (a1[0] == '-') ? -1 : (int)strtol(a1, NULL, 16);
			fputs("ok\n", ntc_out);
		} else if (!strcmp(cmd, "key")) {
			hwa_kbd_set_fake_key((Uint8)atoi(a1));
			fputs("ok\n", ntc_out);
		} else if (!strcmp(cmd, "shot")) {
			snprintf(ntc_shot, sizeof ntc_shot, "%s", p);
			configdb.screenshot_and_exit = ntc_shot;
			vic4_registered_screenshot_request = 1;
			fputs("ok\n", ntc_out);
		} else if (!strcmp(cmd, "mem") && rest) {
			unsigned int addr = strtoul(a1, NULL, 16), len = strtoul(rest, NULL, 16);
			for (unsigned int i = 0; i < len; i++)
				fprintf(ntc_out, "%02x", (addr + i < sizeof(main_ram)) ? main_ram[addr + i] : 0);
			fputs("\n", ntc_out);
		} else if (!strcmp(cmd, "vic")) {
			for (int i = 0; i < 0x80; i++)
				fprintf(ntc_out, "%02x", vic_registers[i]);
			fputs("\n", ntc_out);
		} else if (!strcmp(cmd, "cram")) {
			unsigned int addr = strtoul(a1, NULL, 16), len = strtoul(rest ? rest : "1", NULL, 16);
			for (unsigned int i = 0; i < len; i++)
				fprintf(ntc_out, "%02x", colour_ram[(addr + i) & 0x7FFF]);
			fputs("\n", ntc_out);
		} else if (!strcmp(cmd, "hyp")) {
			fprintf(ntc_out, "%d\n", (int)in_hypervisor);
		} else if (!strcmp(cmd, "pc")) {
			fprintf(ntc_out, "%04x\n", cpu65.pc);
		} else if (!strcmp(cmd, "frame")) {
			fprintf(ntc_out, "%u\n", ntc_frame);
		} else {
			fprintf(ntc_out, "? %s\n", cmd);
		}
		fflush(ntc_out);
	}
	_exit(0);		// the pipe closed: the caller has gone
}

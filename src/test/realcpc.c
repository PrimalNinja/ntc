// realcpc - a CPC 6128 with the real ROMs, no window (the emulator is floooh/chips, MIT,
// github.com/floooh/chips; the ROM images from github.com/floooh/chips-test examples/roms).
// Scratch test tool, not delivered. Build:
//   gcc -O2 -I<chips> -o realcpc realcpc.c -lm
// usage: CPCROMS=<dir with cpc6128_os.bin, cpc6128_basic.bin, cpc6128_amsdos.bin> \
//        [WATCH=hex,hex...] realcpc disc.dsk|- script out_prefix
// It boots BASIC, puts the disc in, then follows the script (times in seconds from power on).
// script lines:  <seconds> type <text>   (\n = Return)
//                <seconds> shot <name>   (PPM of the screen)
//                <seconds> pc            (print PC, SP)
//                <seconds> mem <hex>     (16 bytes of RAM, as the CPU sees it with no ROMs)
//                <seconds> hits          (how often the WATCH addresses were fetched, and how
//                                         often with the lower ROM on)
//                <seconds> end
// XROM=<file> [XSLOT=n]: a ROM image (16K, or 16K + an AMSDOS header) in upper ROM slot n
// (default 6), there from power on - e.g. build/rom/NTCFW.ROM; XROM2=<file> [XSLOT2=n] ...
// XROM8: more ROMs (a keyword ROM set: NTCFW2.ROM ...; default slots 5, 4, 3 ...)
#define CHIPS_IMPL
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "chips/chips_common.h"
#include "chips/z80.h"
#include "chips/ay38910.h"
#include "chips/i8255.h"
#include "chips/mc6845.h"
#include "chips/am40010.h"
#include "chips/upd765.h"
#include "chips/mem.h"
#include "chips/kbd.h"
#include "chips/clk.h"
#include "chips/fdd.h"
#include "chips/fdd_cpc.h"
#include "systems/cpc.h"

static cpc_t cpc;
static int nwatch = 0; static unsigned watch[16]; static long hits[16], romhits[16];
static void dbg(void* u, uint64_t pins) {
    if ((pins & Z80_M1) && (pins & Z80_MREQ) && (pins & Z80_RD)) {
        unsigned a = Z80_GET_ADDR(pins);
        for (int i = 0; i < nwatch; i++) if (watch[i] == a) { hits[i]++; if (!(cpc.ga.regs.config & AM40010_CONFIG_LROMEN)) romhits[i]++; }
    }
}
static chips_range_t rd(const char* p) {
    FILE* f = fopen(p, "rb"); if (!f) { perror(p); exit(1); }
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    void* b = malloc(n); if (fread(b, 1, n, f) != (size_t)n) { perror(p); exit(1); } fclose(f);
    return (chips_range_t){ b, (size_t)n };
}
static const uint8_t* xroms[8]; static int xslots[8]; static int nxrom = 0;
static void xbankswitch(uint8_t ram_config, uint8_t rom_enable, uint8_t rom_select, void* user_data) {
    _cpc_bankswitch(ram_config, rom_enable, rom_select, user_data);
    for (int i = 0; i < nxrom; i++) if ((rom_select == xslots[i]) && !(rom_enable & AM40010_CONFIG_HROMEN)) {
        cpc_t* sys = (cpc_t*) user_data;
        mem_map_rw(&sys->mem, 0, 0xC000, 0x4000, xroms[i], sys->ram[_cpc_ram_config[ram_config & 7][3]]);
    }
}
static double now = 0;
static void run(double sec) { while (sec > 0) { double s = sec > 0.02 ? 0.02 : sec; cpc_exec(&cpc, (uint32_t)(s * 1e6)); now += s; sec -= s; } }
static void shot(const char* name) {
    chips_display_info_t d = cpc_display_info(&cpc);
    FILE* f = fopen(name, "wb");
    int w = d.screen.width, h = d.screen.height;
    fprintf(f, "P6\n%d %d\n255\n", w, h);
    const uint8_t* fb = d.frame.buffer.ptr; const uint32_t* pal = d.palette.ptr;
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        uint8_t i = fb[(y + d.screen.y) * d.frame.dim.width + x + d.screen.x];
        uint32_t c = pal[i]; uint8_t rgb[3] = { c & 255, (c >> 8) & 255, (c >> 16) & 255 };
        fwrite(rgb, 1, 3, f);
    }
    fclose(f);
}
int main(int argc, char** argv) {
    const char* R = getenv("CPCROMS");
    char p[512];
    if (!R || argc < 4) { fprintf(stderr, "usage: CPCROMS=dir realcpc disc.dsk|- script out_prefix\n"); return 1; }
    cpc_desc_t desc; memset(&desc, 0, sizeof desc);
    desc.type = CPC_TYPE_6128;
    sprintf(p, "%s/cpc6128_os.bin", R); desc.roms.cpc6128.os = rd(p);
    sprintf(p, "%s/cpc6128_basic.bin", R); desc.roms.cpc6128.basic = rd(p);
    sprintf(p, "%s/cpc6128_amsdos.bin", R); desc.roms.cpc6128.amsdos = rd(p);
    char* w = getenv("WATCH");
    if (w) { char* t = strtok(w, ","); while (t && nwatch < 16) { watch[nwatch++] = strtoul(t, 0, 16); t = strtok(0, ","); } desc.debug.callback.func = dbg; static bool st = false; desc.debug.stopped = &st; }
    for (int k = 1; k <= 8; k++) {
        char nx[16], ns[16]; sprintf(nx, (k == 1) ? "XROM" : "XROM%d", k); sprintf(ns, (k == 1) ? "XSLOT" : "XSLOT%d", k);
        char* xr = getenv(nx); if (!xr) continue;
        chips_range_t r = rd(xr); xroms[nxrom] = (const uint8_t*) r.ptr + ((r.size == 0x4080) ? 128 : 0);
        xslots[nxrom] = getenv(ns) ? atoi(getenv(ns)) : 7 - k; nxrom++;
    }
    cpc_init(&cpc, &desc);
    if (nxrom) { cpc.ga.bankswitch_cb = xbankswitch; xbankswitch(cpc.ga.ram_config, cpc.ga.regs.config, cpc.ga.rom_select, &cpc); }
    // Control + 1-8 typed as \c1 ... \c8 (codes #81-#88), Control + ESC as \ce (#89)
    for (int i = 1; i <= 8; i++) cpc.kbd.key_masks[0x80 + i] = cpc.kbd.key_masks['0' + i] | (2 << (KBD_MAX_COLUMNS + KBD_MAX_LINES));
    cpc.kbd.key_masks[0x89] = cpc.kbd.key_masks[0x03] | (2 << (KBD_MAX_COLUMNS + KBD_MAX_LINES));
    run(2.5);
    if (strcmp(argv[1], "-")) cpc_insert_disc(&cpc, rd(argv[1]));
    FILE* s = fopen(argv[2], "r"); char line[512];
    while (fgets(line, sizeof line, s)) {
        double t; char cmd[32]; int n = 0;
        if (sscanf(line, "%lf %31s %n", &t, cmd, &n) < 2) continue;
        char* arg = line + n; arg[strcspn(arg, "\r\n")] = 0;
        if (t > now) run(t - now);
        if (!strcmp(cmd, "type")) {
            for (char* c = arg; *c; c++) {
                int k = *c;
                if (c[0] == '\\' && c[1] == 'n') { k = 0x0D; c++; }
                else if (c[0] == '\\' && c[1] == 'c' && c[2] == 'e') { k = 0x89; c += 2; }
                else if (c[0] == '\\' && c[1] == 'c' && c[2] >= '1' && c[2] <= '8') { k = 0x80 + c[2] - '0'; c += 2; }
                cpc_key_down(&cpc, k); run(0.06); cpc_key_up(&cpc, k); run(0.06);
            }
        } else if (!strcmp(cmd, "shot")) { sprintf(p, "%s%s.ppm", argv[3], arg); shot(p); }
        else if (!strcmp(cmd, "pc")) printf("t=%.2f PC=%04X SP=%04X\n", now, cpc.cpu.pc, cpc.cpu.sp);
        else if (!strcmp(cmd, "mem")) { unsigned a = strtoul(arg, 0, 16); printf("t=%.2f %04X:", now, a); for (int i = 0; i < 16; i++) printf(" %02X", cpc.ram[((a + i) & 0xFFFF) >> 14][(a + i) & 0x3FFF]); printf("\n"); }
        else if (!strcmp(cmd, "hits")) { printf("t=%.2f", now); for (int i = 0; i < nwatch; i++) printf(" %04X:%ld(rom %ld)", watch[i], hits[i], romhits[i]); printf("\n"); }
        else if (!strcmp(cmd, "end")) break;
    }
    return 0;
}

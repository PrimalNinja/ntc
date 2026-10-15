; the window data (; @window ... ; @endwindow in #asm): put in the window hole by its guard
			MACRO ntc_windata
; (the hypervisor's page from #5300 - #4000 the disc buffers, #5000 the font: Install copies
; these into each bank from there, FileCall 99 put them there at the start)
            ds #5300 - $		; Hyp.cls 1155
; page zero (#0000-#0080)
fn_hyp_info_hi_p0:		; Hyp.cls 1157
            db #C3		; Hyp.cls 1158
            dw fn_hyp_info_sb_bwb                           ; #0000: warm boot - the BIOS's WBOOT (the task [1159]
            db 0, 0                             ; ends); (#0001) - 3: the BIOS jump table [1160]
            db #C3		; Hyp.cls 1161
            dw fn_hyp_info_sb_start                         ; #0005: BDOS (#0006: the top of the TPA) [1162]
            ds #38 - 8		; Hyp.cls 1163
            db #C3		; Hyp.cls 1164
            dw fn_hyp_info_sb_int                           ; #0038: the interrupt [1165]
            ds #44 - #3B		; Hyp.cls 1166
            db #ED, #49                         ; #0044: out (c), c [1167]
            db #C3		; Hyp.cls 1168
            dw fn_hyp_info_sb_land                          ; #0046: this bank switched in [1169]
            ds #5C - #49		; Hyp.cls 1170
            db 0, "           "                 ; #005C: the default FCB [1171]
            ds #80 - #68		; Hyp.cls 1172
            db 0                                ; #0080: no command tail [1173]
fn_hyp_info_hi_p0e:		; Hyp.cls 1174
; the stubs: assembled here, run at STUB in the bank (DISP: their labels are the bank's
; addresses). The BDOS: what needs nothing of the hypervisor is answered here, with no
; switch - the console out (2, 9: collected at OBUF; the hypervisor gets them, IX = how many, at
; the next far call or interrupt, or when 128 wait), the keys (1, 6, 10, 11: from KEY, where
; the hypervisor leaves the slot's next key), the IOBYTE (7, 8), the disc's parameters (27, 31)
; and the calls with nothing to do (3, 4, 5, 28, 29, 30, 37), CP/M 3's 49 for the console's
; size (MODE); the rest is a far call. Then the
; BIOS (its jump table: (#0001) - 3) and the start-up (the default FCBs)
fn_hyp_info_sb_img:		; Hyp.cls 1183
            DISP 61184		; Hyp.cls 1184
fn_hyp_info_sb_start:		; Hyp.cls 1185
            di                                  ; BDOS: C = function, DE = argument [1186]
            ld a, c		; Hyp.cls 1187
            cp 2		; Hyp.cls 1188
            jp z, fn_hyp_info_sb_put		; Hyp.cls 1189
            cp 6		; Hyp.cls 1190
            jr z, fn_hyp_info_sb_f6		; Hyp.cls 1191
            cp 11		; Hyp.cls 1192
            jr z, fn_hyp_info_sb_stat		; Hyp.cls 1193
            cp 1		; Hyp.cls 1194
            jr z, fn_hyp_info_sb_f1		; Hyp.cls 1195
            cp 9		; Hyp.cls 1196
            jp z, fn_hyp_info_sb_str		; Hyp.cls 1197
            cp 10		; Hyp.cls 1198
            jp z, fn_hyp_info_sb_line		; Hyp.cls 1199
            cp 3		; Hyp.cls 1200
            jr z, fn_hyp_info_sb_rdr		; Hyp.cls 1201
            cp 7		; Hyp.cls 1202
            jr z, fn_hyp_info_sb_iob		; Hyp.cls 1203
            cp 8		; Hyp.cls 1204
            jr z, fn_hyp_info_sb_siob		; Hyp.cls 1205
            cp 27		; Hyp.cls 1206
            jr z, fn_hyp_info_sb_alv		; Hyp.cls 1207
            cp 31		; Hyp.cls 1208
            jr z, fn_hyp_info_sb_dpb		; Hyp.cls 1209
            cp 4		; Hyp.cls 1210
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1211
            cp 5		; Hyp.cls 1212
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1213
            cp 28		; Hyp.cls 1214
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1215
            cp 29		; Hyp.cls 1216
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1217
            cp 30		; Hyp.cls 1218
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1219
            cp 37		; Hyp.cls 1220
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1221
            cp 49		; Hyp.cls 1222
            jp z, fn_hyp_info_sb_scb		; Hyp.cls 1223
            jp fn_hyp_info_sb_call		; Hyp.cls 1224
fn_hyp_info_sb_zero:		; Hyp.cls 1225
            xor a                               ; 4, 5 (the printer: not yet), 28, 29, 30, 37 [1226]
fn_hyp_info_sb_ret:		; Hyp.cls 1227
            ld l, a		; Hyp.cls 1228
            ld h, 0		; Hyp.cls 1229
            ei		; Hyp.cls 1230
            ret		; Hyp.cls 1231
fn_hyp_info_sb_rdr:		; Hyp.cls 1232
            ld a, #1A                           ; 3: the reader - the end of a file [1233]
            jr fn_hyp_info_sb_ret		; Hyp.cls 1234
fn_hyp_info_sb_iob:		; Hyp.cls 1235
            ld a, (#0003)                       ; 7: the IOBYTE [1236]
            jr fn_hyp_info_sb_ret		; Hyp.cls 1237
fn_hyp_info_sb_siob:		; Hyp.cls 1238
            ld a, e                             ; 8 [1239]
            ld (#0003), a		; Hyp.cls 1240
            jr fn_hyp_info_sb_zero		; Hyp.cls 1241
fn_hyp_info_sb_alv:		; Hyp.cls 1242
            ld hl, fn_hyp_info_sb_alvec                     ; 27: the allocation vector (a CPC data disc's) [1243]
            ei		; Hyp.cls 1244
            ret		; Hyp.cls 1245
fn_hyp_info_sb_dpb:		; Hyp.cls 1246
            ld hl, fn_hyp_info_sb_dpbv                      ; 31: the disc parameter block [1247]
            ei		; Hyp.cls 1248
            ret		; Hyp.cls 1249
fn_hyp_info_sb_f6:		; Hyp.cls 1250
            ld a, e		; Hyp.cls 1251
            cp #FF		; Hyp.cls 1252
            jr z, fn_hyp_info_sb_get		; Hyp.cls 1253
            cp #FE		; Hyp.cls 1254
            jr c, fn_hyp_info_sb_put		; Hyp.cls 1255
fn_hyp_info_sb_stat:		; Hyp.cls 1256
            ld a, (63105)                       ; 6 / #FE, 11: is a key waiting (#FF / 0) [1257]
            or a		; Hyp.cls 1258
            jr z, fn_hyp_info_sb_ret		; Hyp.cls 1259
            ld a, #FF		; Hyp.cls 1260
            jr fn_hyp_info_sb_ret		; Hyp.cls 1261
fn_hyp_info_sb_get:		; Hyp.cls 1262
            ld hl, 63105                        ; 6 / #FF: the key or 0 (no wait) [1263]
            ld a, (hl)		; Hyp.cls 1264
            ld (hl), 0		; Hyp.cls 1265
            jr fn_hyp_info_sb_ret		; Hyp.cls 1266
fn_hyp_info_sb_f1:		; Hyp.cls 1267
            call fn_hyp_info_sb_key                         ; 1: a key (waited for), echoed [1268]
            push af		; Hyp.cls 1269
            ld e, a		; Hyp.cls 1270
            call fn_hyp_info_sb_putc		; Hyp.cls 1271
            pop af		; Hyp.cls 1272
            jr fn_hyp_info_sb_ret		; Hyp.cls 1273
fn_hyp_info_sb_put:		; Hyp.cls 1274
            call fn_hyp_info_sb_putc                        ; 2: E out [1275]
            ei		; Hyp.cls 1276
            ret		; Hyp.cls 1277
fn_hyp_info_sb_str:		; Hyp.cls 1278
            ld h, d                             ; 9: the string at DE, to "$" [1279]
            ld l, e		; Hyp.cls 1280
fn_hyp_info_sb_st_lp:		; Hyp.cls 1281
            ld a, (hl)		; Hyp.cls 1282
            cp '$'		; Hyp.cls 1283
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1284
            push hl		; Hyp.cls 1285
            ld e, a		; Hyp.cls 1286
            call fn_hyp_info_sb_putc		; Hyp.cls 1287
            pop hl		; Hyp.cls 1288
            inc hl		; Hyp.cls 1289
            jr fn_hyp_info_sb_st_lp		; Hyp.cls 1290
; sb_putc - E collected at OBUF (the hypervisor shown them when 128 wait). Interrupts off
fn_hyp_info_sb_putc:		; Hyp.cls 1292
            ld hl, 62976 + 128                 ; the count [1293]
            ld a, (hl)		; Hyp.cls 1294
            inc (hl)		; Hyp.cls 1295
            ld l, a		; Hyp.cls 1296
            ld h, 62976 / 256		; Hyp.cls 1297
            ld (hl), e		; Hyp.cls 1298
            cp 127		; Hyp.cls 1299
            ret c		; Hyp.cls 1300
            push bc		; Hyp.cls 1301
            push de		; Hyp.cls 1302
            ld c, #80                           ; full: function #80, only the characters [1303]
            call fn_hyp_info_sb_call		; Hyp.cls 1304
            di		; Hyp.cls 1305
            pop de		; Hyp.cls 1306
            pop bc		; Hyp.cls 1307
            ret		; Hyp.cls 1308
; sb_key - A = the next key, waited for: none at KEY - a far call (#81) that has the hypervisor
; run the others until a key comes (or the clock moves on), then look again
fn_hyp_info_sb_key:		; Hyp.cls 1311
            ld hl, 63105		; Hyp.cls 1312
            ld a, (hl)		; Hyp.cls 1313
            or a		; Hyp.cls 1314
            jr z, fn_hyp_info_sb_k_wait		; Hyp.cls 1315
            ld (hl), 0		; Hyp.cls 1316
            ret		; Hyp.cls 1317
fn_hyp_info_sb_k_wait:		; Hyp.cls 1318
            push bc		; Hyp.cls 1319
            push de		; Hyp.cls 1320
            ld c, #81		; Hyp.cls 1321
            call fn_hyp_info_sb_call		; Hyp.cls 1322
            di		; Hyp.cls 1323
            pop de		; Hyp.cls 1324
            pop bc		; Hyp.cls 1325
            jr fn_hyp_info_sb_key		; Hyp.cls 1326
; 10: a line typed into the buffer at DE (its size, then how many came, then them): BS / DEL
; rub out, Control + U / X the whole line, Control + C at its start ends the program, CR / LF
; end it (CR echoed)
fn_hyp_info_sb_line:		; Hyp.cls 1330
            ld (fn_hyp_info_sb_lbuf), de		; Hyp.cls 1331
            xor a		; Hyp.cls 1332
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1333
fn_hyp_info_sb_l_lp:		; Hyp.cls 1334
            call fn_hyp_info_sb_key		; Hyp.cls 1335
            cp 13		; Hyp.cls 1336
            jr z, fn_hyp_info_sb_l_end		; Hyp.cls 1337
            cp 10		; Hyp.cls 1338
            jr z, fn_hyp_info_sb_l_end		; Hyp.cls 1339
            cp 8		; Hyp.cls 1340
            jr z, fn_hyp_info_sb_l_bs		; Hyp.cls 1341
            cp 127		; Hyp.cls 1342
            jr z, fn_hyp_info_sb_l_bs		; Hyp.cls 1343
            cp 21		; Hyp.cls 1344
            jr z, fn_hyp_info_sb_l_kill		; Hyp.cls 1345
            cp 24		; Hyp.cls 1346
            jr z, fn_hyp_info_sb_l_kill		; Hyp.cls 1347
            cp 3		; Hyp.cls 1348
            jr nz, fn_hyp_info_sb_l_ch		; Hyp.cls 1349
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1350
            or a		; Hyp.cls 1351
            jr nz, fn_hyp_info_sb_l_lp		; Hyp.cls 1352
            ld c, 0                             ; Control + C: the program ends [1353]
            jp fn_hyp_info_sb_call		; Hyp.cls 1354
fn_hyp_info_sb_l_ch:		; Hyp.cls 1355
            cp 32		; Hyp.cls 1356
            jr c, fn_hyp_info_sb_l_lp		; Hyp.cls 1357
            ld b, a		; Hyp.cls 1358
            ld hl, (fn_hyp_info_sb_lbuf)		; Hyp.cls 1359
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1360
            cp (hl)		; Hyp.cls 1361
            jr nc, fn_hyp_info_sb_l_lp                      ; full [1362]
            inc a		; Hyp.cls 1363
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1364
            ld e, a		; Hyp.cls 1365
            ld d, 0		; Hyp.cls 1366
            inc hl		; Hyp.cls 1367
            add hl, de		; Hyp.cls 1368
            ld (hl), b		; Hyp.cls 1369
            ld e, b		; Hyp.cls 1370
            call fn_hyp_info_sb_putc		; Hyp.cls 1371
            jr fn_hyp_info_sb_l_lp		; Hyp.cls 1372
fn_hyp_info_sb_l_kill:		; Hyp.cls 1373
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1374
            or a		; Hyp.cls 1375
            jr z, fn_hyp_info_sb_l_lp		; Hyp.cls 1376
            call fn_hyp_info_sb_l_rub		; Hyp.cls 1377
            jr fn_hyp_info_sb_l_kill		; Hyp.cls 1378
fn_hyp_info_sb_l_bs:		; Hyp.cls 1379
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1380
            or a		; Hyp.cls 1381
            jr z, fn_hyp_info_sb_l_lp		; Hyp.cls 1382
            call fn_hyp_info_sb_l_rub		; Hyp.cls 1383
            jr fn_hyp_info_sb_l_lp		; Hyp.cls 1384
fn_hyp_info_sb_l_rub:		; Hyp.cls 1385
            dec a		; Hyp.cls 1386
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1387
            ld e, 8		; Hyp.cls 1388
            call fn_hyp_info_sb_putc		; Hyp.cls 1389
            ld e, ' '		; Hyp.cls 1390
            call fn_hyp_info_sb_putc		; Hyp.cls 1391
            ld e, 8		; Hyp.cls 1392
            jp fn_hyp_info_sb_putc		; Hyp.cls 1393
fn_hyp_info_sb_l_end:		; Hyp.cls 1394
            ld hl, (fn_hyp_info_sb_lbuf)		; Hyp.cls 1395
            inc hl		; Hyp.cls 1396
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1397
            ld (hl), a		; Hyp.cls 1398
            ld e, 13		; Hyp.cls 1399
            call fn_hyp_info_sb_putc		; Hyp.cls 1400
            jp fn_hyp_info_sb_zero		; Hyp.cls 1401
fn_hyp_info_sb_lbuf:    dw 0		; Hyp.cls 1402
fn_hyp_info_sb_lcnt:    db 0		; Hyp.cls 1403
fn_hyp_info_sb_call:		; Hyp.cls 1404
            push ix                             ; a far call: IX, IY and the alternate [1405]
            push iy                             ; registers kept over it (ex af, af') [1406]
            db #08		; Hyp.cls 1407
            exx		; Hyp.cls 1408
            push af		; Hyp.cls 1409
            push bc		; Hyp.cls 1410
            push de		; Hyp.cls 1411
            push hl		; Hyp.cls 1412
            exx		; Hyp.cls 1413
            db #08		; Hyp.cls 1414
            ld a, (62976 + 128)		; Hyp.cls 1415
            ld ixl, a		; Hyp.cls 1416
            ld ixh, 0		; Hyp.cls 1417
            ld a, c		; Hyp.cls 1418
            ld hl, fn_hyp_info_sb_far		; Hyp.cls 1419
            push hl		; Hyp.cls 1420
            ld (#FFFE), sp		; Hyp.cls 1421
            ld bc, #7FC0		; Hyp.cls 1422
            scf                                 ; carry: a far call [1423]
            jp #0044		; Hyp.cls 1424
fn_hyp_info_sb_far:		; Hyp.cls 1425
            db #08                              ; the answer in A and HL; the program's [1426]
            exx                                 ; other registers back [1427]
            pop hl		; Hyp.cls 1428
            pop de		; Hyp.cls 1429
            pop bc		; Hyp.cls 1430
            pop af		; Hyp.cls 1431
            exx		; Hyp.cls 1432
            db #08		; Hyp.cls 1433
            pop iy		; Hyp.cls 1434
            pop ix		; Hyp.cls 1435
            ei		; Hyp.cls 1436
            ret		; Hyp.cls 1437
fn_hyp_info_sb_int:		; Hyp.cls 1438
            push af                             ; an interrupt: everything kept [1439]
            push bc		; Hyp.cls 1440
            push de		; Hyp.cls 1441
            push hl		; Hyp.cls 1442
            db #08                              ; ex af, af' [1443]
            exx		; Hyp.cls 1444
            push af		; Hyp.cls 1445
            push bc		; Hyp.cls 1446
            push de		; Hyp.cls 1447
            push hl		; Hyp.cls 1448
            push ix		; Hyp.cls 1449
            push iy		; Hyp.cls 1450
            ld a, (62976 + 128)		; Hyp.cls 1451
            ld ixl, a		; Hyp.cls 1452
            ld ixh, 0		; Hyp.cls 1453
            ld hl, fn_hyp_info_sb_rest		; Hyp.cls 1454
            push hl		; Hyp.cls 1455
            ld (#FFFE), sp		; Hyp.cls 1456
            ld bc, #7FC0		; Hyp.cls 1457
            or a                                ; no carry: an interrupt [1458]
            jp #0044		; Hyp.cls 1459
fn_hyp_info_sb_rest:		; Hyp.cls 1460
            pop iy		; Hyp.cls 1461
            pop ix		; Hyp.cls 1462
            pop hl		; Hyp.cls 1463
            pop de		; Hyp.cls 1464
            pop bc		; Hyp.cls 1465
            pop af		; Hyp.cls 1466
            exx		; Hyp.cls 1467
            db #08                              ; ex af, af' [1468]
            pop hl		; Hyp.cls 1469
            pop de		; Hyp.cls 1470
            pop bc		; Hyp.cls 1471
            pop af		; Hyp.cls 1472
            ei		; Hyp.cls 1473
            ret		; Hyp.cls 1474
fn_hyp_info_sb_land:		; Hyp.cls 1475
            ld sp, (#FFFE)                      ; this bank's SP [1476]
            push af		; Hyp.cls 1477
            ld a, e                             ; E = 1: the hypervisor has the characters [1478]
            or a		; Hyp.cls 1479
            jr z, fn_hyp_info_sb_lkeep		; Hyp.cls 1480
            xor a		; Hyp.cls 1481
            ld (62976 + 128), a		; Hyp.cls 1482
fn_hyp_info_sb_lkeep:		; Hyp.cls 1483
            pop af		; Hyp.cls 1484
            ret		; Hyp.cls 1485
fn_hyp_info_sb_scb:		; Hyp.cls 1486
            ld h, d                             ; 49 (CP/M 3's system control block): the [1487]
            ld l, e                             ; console's width - 1 (#1A), its page length [1488]
            inc hl                              ; (#1C) - MODE's; other bytes 0, sets kept [1489]
            ld a, (hl)                          ; nowhere [1490]
            or a		; Hyp.cls 1491
            jp nz, fn_hyp_info_sb_zero		; Hyp.cls 1492
            ld a, (de)		; Hyp.cls 1493
            cp #1C		; Hyp.cls 1494
            ld hl, 63112		; Hyp.cls 1495
            jr z, fn_hyp_info_sb_scb_a		; Hyp.cls 1496
            cp #1A		; Hyp.cls 1497
            jp nz, fn_hyp_info_sb_zero		; Hyp.cls 1498
            ld a, (63111)		; Hyp.cls 1499
            dec a		; Hyp.cls 1500
            jp fn_hyp_info_sb_ret		; Hyp.cls 1501
fn_hyp_info_sb_scb_a:		; Hyp.cls 1502
            ld a, (hl)		; Hyp.cls 1503
            jp fn_hyp_info_sb_ret		; Hyp.cls 1504
; the BIOS: CP/M 2.2's 17 entries. The console ones as the BDOS's; the printer and punch take
; nothing yet; the disc ones (sectors) can't be had here: SELDSK gives 0 (no such drive),
; READ / WRITE 1 (an error)
fn_hyp_info_sb_bios:		; Hyp.cls 1508
            jp fn_hyp_info_sb_bboot                         ; BOOT [1509]
fn_hyp_info_sb_bwb:		; Hyp.cls 1510
            jp fn_hyp_info_sb_bboot                         ; WBOOT: (#0001) [1511]
            jp fn_hyp_info_sb_bconst                        ; CONST [1512]
            jp fn_hyp_info_sb_bconin                        ; CONIN [1513]
            jp fn_hyp_info_sb_bconout                       ; CONOUT [1514]
            jp fn_hyp_info_sb_bnone                         ; LIST [1515]
            jp fn_hyp_info_sb_bnone                         ; PUNCH [1516]
            jp fn_hyp_info_sb_brdr                          ; READER [1517]
            jp fn_hyp_info_sb_bnone                         ; HOME [1518]
            jp fn_hyp_info_sb_bseld                         ; SELDSK [1519]
            jp fn_hyp_info_sb_bnone                         ; SETTRK [1520]
            jp fn_hyp_info_sb_bnone                         ; SETSEC [1521]
            jp fn_hyp_info_sb_bdma                          ; SETDMA [1522]
            jp fn_hyp_info_sb_bfail                         ; READ [1523]
            jp fn_hyp_info_sb_bfail                         ; WRITE [1524]
            jp fn_hyp_info_sb_blstst                        ; LISTST [1525]
            jp fn_hyp_info_sb_bsectr                        ; SECTRAN [1526]
fn_hyp_info_sb_bboot:		; Hyp.cls 1527
            ld c, 0                             ; the task ends [1528]
            jp fn_hyp_info_sb_start		; Hyp.cls 1529
fn_hyp_info_sb_bconst:		; Hyp.cls 1530
            di		; Hyp.cls 1531
            ld a, (63105)		; Hyp.cls 1532
            or a		; Hyp.cls 1533
            jr z, fn_hyp_info_sb_bc_n		; Hyp.cls 1534
            ld a, #FF		; Hyp.cls 1535
fn_hyp_info_sb_bc_n:		; Hyp.cls 1536
            ei		; Hyp.cls 1537
            ret		; Hyp.cls 1538
fn_hyp_info_sb_bconin:		; Hyp.cls 1539
            di		; Hyp.cls 1540
            call fn_hyp_info_sb_key		; Hyp.cls 1541
            ei		; Hyp.cls 1542
            ret		; Hyp.cls 1543
fn_hyp_info_sb_bconout:		; Hyp.cls 1544
            di		; Hyp.cls 1545
            ld e, c		; Hyp.cls 1546
            call fn_hyp_info_sb_putc		; Hyp.cls 1547
            ei		; Hyp.cls 1548
fn_hyp_info_sb_bnone:		; Hyp.cls 1549
            ret		; Hyp.cls 1550
fn_hyp_info_sb_brdr:		; Hyp.cls 1551
            ld a, #1A		; Hyp.cls 1552
            ret		; Hyp.cls 1553
fn_hyp_info_sb_bseld:		; Hyp.cls 1554
            ld hl, 0		; Hyp.cls 1555
            ret		; Hyp.cls 1556
fn_hyp_info_sb_bdma:		; Hyp.cls 1557
            ld d, b		; Hyp.cls 1558
            ld e, c		; Hyp.cls 1559
            ld c, 26		; Hyp.cls 1560
            jp fn_hyp_info_sb_start		; Hyp.cls 1561
fn_hyp_info_sb_bfail:		; Hyp.cls 1562
            ld a, 1		; Hyp.cls 1563
            ret		; Hyp.cls 1564
fn_hyp_info_sb_blstst:		; Hyp.cls 1565
            ld a, #FF		; Hyp.cls 1566
            ret		; Hyp.cls 1567
fn_hyp_info_sb_bsectr:		; Hyp.cls 1568
            ld h, b		; Hyp.cls 1569
            ld l, c		; Hyp.cls 1570
            ret		; Hyp.cls 1571
; a CPC data format disc's parameters (31) and allocation vector (27): 180 1K blocks, 64
; directory entries in the first two
fn_hyp_info_sb_dpbv:		; Hyp.cls 1574
            dw 36                               ; SPT: 128 byte records a track [1575]
            db 3, 7, 0                          ; BSH, BLM, EXM [1576]
            dw 179, 63                          ; DSM, DRM [1577]
            db #C0, 0                           ; AL0, AL1 [1578]
            dw 16, 0                            ; CKS, OFF [1579]
fn_hyp_info_sb_alvec:		; Hyp.cls 1580
            db #C0		; Hyp.cls 1581
            ds 22		; Hyp.cls 1582
; the start-up: the default FCBs (#005C, #006C) from the command tail (#0080), as the CCP
; makes them - "B:NAME.EXT", * as ?s - then the program at #0100
fn_hyp_info_sb_init:		; Hyp.cls 1585
            ld hl, #005C		; Hyp.cls 1586
            call fn_hyp_info_sb_iclr		; Hyp.cls 1587
            ld hl, #006C		; Hyp.cls 1588
            call fn_hyp_info_sb_iclr		; Hyp.cls 1589
            ld hl, #0081		; Hyp.cls 1590
            ld a, (#0080)		; Hyp.cls 1591
            ld b, a		; Hyp.cls 1592
            ld de, #005C		; Hyp.cls 1593
            call fn_hyp_info_sb_parse		; Hyp.cls 1594
            ld de, #006C		; Hyp.cls 1595
            call fn_hyp_info_sb_parse		; Hyp.cls 1596
            jp #0100		; Hyp.cls 1597
fn_hyp_info_sb_iclr:		; Hyp.cls 1598
            ld (hl), 0		; Hyp.cls 1599
            inc hl		; Hyp.cls 1600
            ld c, 11		; Hyp.cls 1601
fn_hyp_info_sb_ic_sp:		; Hyp.cls 1602
            ld (hl), ' '		; Hyp.cls 1603
            inc hl		; Hyp.cls 1604
            dec c		; Hyp.cls 1605
            jr nz, fn_hyp_info_sb_ic_sp		; Hyp.cls 1606
            ld c, 4		; Hyp.cls 1607
fn_hyp_info_sb_ic_z:		; Hyp.cls 1608
            ld (hl), 0		; Hyp.cls 1609
            inc hl		; Hyp.cls 1610
            dec c		; Hyp.cls 1611
            jr nz, fn_hyp_info_sb_ic_z		; Hyp.cls 1612
            ret		; Hyp.cls 1613
; sb_parse - HL = the tail, B = characters left; DE = an FCB: the next word into it
fn_hyp_info_sb_parse:		; Hyp.cls 1615
            ld a, b		; Hyp.cls 1616
            or a		; Hyp.cls 1617
            ret z		; Hyp.cls 1618
            ld a, (hl)		; Hyp.cls 1619
            cp ' '		; Hyp.cls 1620
            jr nz, fn_hyp_info_sb_p_word		; Hyp.cls 1621
            inc hl		; Hyp.cls 1622
            dec b		; Hyp.cls 1623
            jr fn_hyp_info_sb_parse		; Hyp.cls 1624
fn_hyp_info_sb_p_word:		; Hyp.cls 1625
            ld (fn_hyp_info_sb_pfcb), de		; Hyp.cls 1626
            ld a, b		; Hyp.cls 1627
            cp 2		; Hyp.cls 1628
            jr c, fn_hyp_info_sb_p_name		; Hyp.cls 1629
            inc hl		; Hyp.cls 1630
            ld a, (hl)		; Hyp.cls 1631
            dec hl		; Hyp.cls 1632
            cp ':'		; Hyp.cls 1633
            jr nz, fn_hyp_info_sb_p_name		; Hyp.cls 1634
            ld a, (hl)		; Hyp.cls 1635
            sub '@'		; Hyp.cls 1636
            ld (de), a                          ; its drive [1637]
            inc hl		; Hyp.cls 1638
            inc hl		; Hyp.cls 1639
            dec b		; Hyp.cls 1640
            dec b		; Hyp.cls 1641
fn_hyp_info_sb_p_name:		; Hyp.cls 1642
            inc de		; Hyp.cls 1643
            ld c, 8		; Hyp.cls 1644
            call fn_hyp_info_sb_pfield		; Hyp.cls 1645
            ld a, b		; Hyp.cls 1646
            or a		; Hyp.cls 1647
            ret z		; Hyp.cls 1648
            ld a, (hl)		; Hyp.cls 1649
            cp '.'		; Hyp.cls 1650
            jr nz, fn_hyp_info_sb_p_skip		; Hyp.cls 1651
            inc hl		; Hyp.cls 1652
            dec b		; Hyp.cls 1653
            ld de, (fn_hyp_info_sb_pfcb)		; Hyp.cls 1654
            ld a, e		; Hyp.cls 1655
            add a, 9		; Hyp.cls 1656
            ld e, a		; Hyp.cls 1657
            ld c, 3		; Hyp.cls 1658
            call fn_hyp_info_sb_pfield		; Hyp.cls 1659
fn_hyp_info_sb_p_skip:		; Hyp.cls 1660
            ld a, b                             ; the rest of the word [1661]
            or a		; Hyp.cls 1662
            ret z		; Hyp.cls 1663
            ld a, (hl)		; Hyp.cls 1664
            cp ' '		; Hyp.cls 1665
            ret z		; Hyp.cls 1666
            inc hl		; Hyp.cls 1667
            dec b		; Hyp.cls 1668
            jr fn_hyp_info_sb_p_skip		; Hyp.cls 1669
; sb_pfield - up to C characters into the field at DE, to a "." or a space; * fills it with ?
fn_hyp_info_sb_pfield:		; Hyp.cls 1671
            ld a, b		; Hyp.cls 1672
            or a		; Hyp.cls 1673
            ret z		; Hyp.cls 1674
            ld a, (hl)		; Hyp.cls 1675
            cp ' '		; Hyp.cls 1676
            ret z		; Hyp.cls 1677
            cp '.'		; Hyp.cls 1678
            ret z		; Hyp.cls 1679
            cp '*'		; Hyp.cls 1680
            jr z, fn_hyp_info_sb_pf_star		; Hyp.cls 1681
            inc c		; Hyp.cls 1682
            dec c		; Hyp.cls 1683
            jr z, fn_hyp_info_sb_pf_on                      ; (the field full: the extra left out) [1684]
            ld (de), a		; Hyp.cls 1685
            inc de		; Hyp.cls 1686
            dec c		; Hyp.cls 1687
fn_hyp_info_sb_pf_on:		; Hyp.cls 1688
            inc hl		; Hyp.cls 1689
            dec b		; Hyp.cls 1690
            jr fn_hyp_info_sb_pfield		; Hyp.cls 1691
fn_hyp_info_sb_pf_star:		; Hyp.cls 1692
            inc c		; Hyp.cls 1693
            dec c		; Hyp.cls 1694
            jr z, fn_hyp_info_sb_pf_on		; Hyp.cls 1695
            ld a, '?'		; Hyp.cls 1696
            ld (de), a		; Hyp.cls 1697
            inc de		; Hyp.cls 1698
            dec c		; Hyp.cls 1699
            jr fn_hyp_info_sb_pf_star		; Hyp.cls 1700
fn_hyp_info_sb_pfcb:    dw 0		; Hyp.cls 1701
fn_hyp_info_sb_end:		; Hyp.cls 1702
            ENT		; Hyp.cls 1703
            ASSERT fn_hyp_info_sb_end - fn_hyp_info_sb_start <= 62208 - 61184, "the bank stubs must fit below FONT"		; Hyp.cls 1704
            ASSERT fn_hyp_info_sb_end - fn_hyp_info_sb_start <= #340, "the stubs must leave a program's first stack (#F240-#F2FF) free"		; Hyp.cls 1705
; ---- the page code: in the hypervisor's page (window data), called with it in the window
asm_1_1746_n_fp_start:		; Hyp.cls 1946
            ASSERT asm_1_1746_n_fp_start >= #5300, "FileCall's page code: after the disc buffers and the font"		; Hyp.cls 1947
asm_1_1746_n_fp_go:		; Hyp.cls 1948
            ld (asm_1_1746_n_fp_sp), sp		; Hyp.cls 1949
            ld a, (var_hyp_filecall_f)		; Hyp.cls 1950
            cp 15		; Hyp.cls 1951
            jp z, asm_1_1746_n_fl_open		; Hyp.cls 1952
            cp 16		; Hyp.cls 1953
            jp z, asm_1_1746_n_fl_close		; Hyp.cls 1954
            cp 19		; Hyp.cls 1955
            jp z, asm_1_1746_n_fl_del		; Hyp.cls 1956
            cp 23		; Hyp.cls 1957
            jp z, asm_1_1746_n_fl_ren		; Hyp.cls 1958
            cp 20		; Hyp.cls 1959
            jp z, asm_1_1746_n_fl_rdseq		; Hyp.cls 1960
            cp 33		; Hyp.cls 1961
            jp z, asm_1_1746_n_fl_rdran		; Hyp.cls 1962
            cp 21		; Hyp.cls 1963
            jp z, asm_1_1746_n_fl_write		; Hyp.cls 1964
            cp 34		; Hyp.cls 1965
            jp z, asm_1_1746_n_fl_write		; Hyp.cls 1966
            cp 22		; Hyp.cls 1967
            jp z, asm_1_1746_n_fl_make		; Hyp.cls 1968
            cp 17		; Hyp.cls 1969
            jp z, asm_1_1746_n_fl_srch1		; Hyp.cls 1970
            cp 18		; Hyp.cls 1971
            jp z, asm_1_1746_n_fl_srch		; Hyp.cls 1972
            cp 35		; Hyp.cls 1973
            jp z, asm_1_1746_n_fl_size		; Hyp.cls 1974
            cp 36		; Hyp.cls 1975
            jp z, asm_1_1746_n_fl_setran		; Hyp.cls 1976
            cp 100		; Hyp.cls 1977
            jp z, asm_1_1746_n_fl_hopen		; Hyp.cls 1978
            cp 101		; Hyp.cls 1979
            jp z, asm_1_1746_n_fl_hread		; Hyp.cls 1980
            cp 102		; Hyp.cls 1981
            jp z, asm_1_1746_n_fl_hclose		; Hyp.cls 1982
            cp 103		; Hyp.cls 1983
            jp z, asm_1_1746_n_fl_hload		; Hyp.cls 1984
            jp asm_1_1746_n_fp_done		; Hyp.cls 1985
; ---- the hypervisor's own reading (RUN, DIR, CD): 100 open the file named at fcb (dma
; characters, main RAM); 101 read dma bytes (128 at most) to buf: how many; 102 close; 103 the
; rest of it into the slot (setting) from address dma, fcb bytes at most: how many. Not while
; a slot reads a file (255)
asm_1_1746_n_fl_hopen:		; Hyp.cls 1990
            ld a, (var_hyp_fin)		; Hyp.cls 1991
            or a		; Hyp.cls 1992
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 1993
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 1994
            ld de, asm_1_1746_n_fl_name_s + 1		; Hyp.cls 1995
            ld bc, (var_hyp_filecall_dma)		; Hyp.cls 1996
            ld a, c		; Hyp.cls 1997
            ld (asm_1_1746_n_fl_name_s), a		; Hyp.cls 1998
            ldir		; Hyp.cls 1999
            call asm_1_1746_n_fl_inopen		; Hyp.cls 2000
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2001
            ld a, 99                ; (99: the hypervisor's) [2002]
            ld (var_hyp_fin), a		; Hyp.cls 2003
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2004
asm_1_1746_n_fl_hread:		; Hyp.cls 2005
            ld a, (var_hyp_filecall_dma)		; Hyp.cls 2006
            ld (asm_1_1746_n_fl_n), a		; Hyp.cls 2007
            call asm_1_1746_n_fl_rdrec		; Hyp.cls 2008
            ld (asm_1_1746_n_fl_res), a		; Hyp.cls 2009
            jp asm_1_1746_n_fp_done		; Hyp.cls 2010
asm_1_1746_n_fl_hclose:		; Hyp.cls 2011
            ld a, (var_hyp_fin)		; Hyp.cls 2012
            cp 99		; Hyp.cls 2013
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 2014
            call asm_1_1746_n_fl_inclose		; Hyp.cls 2015
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2016
asm_1_1746_n_fl_hload:		; Hyp.cls 2017
            ld hl, 0		; Hyp.cls 2018
            ld (asm_1_1746_n_fl_cnt), hl		; Hyp.cls 2019
            ld hl, (var_hyp_filecall_dma)		; Hyp.cls 2020
            ld (asm_1_1746_n_fl_at), hl		; Hyp.cls 2021
asm_1_1746_n_fl_hl_lp:		; Hyp.cls 2022
            ld hl, (var_hyp_filecall_fcb)          ; what is left to load (fcb bytes at most) [2023]
            ld de, (asm_1_1746_n_fl_cnt)		; Hyp.cls 2024
            or a		; Hyp.cls 2025
            sbc hl, de		; Hyp.cls 2026
            jr z, asm_1_1746_n_fl_hl_end		; Hyp.cls 2027
            ld a, h		; Hyp.cls 2028
            or a		; Hyp.cls 2029
            ld a, 128		; Hyp.cls 2030
            jr nz, asm_1_1746_n_fl_hl_n		; Hyp.cls 2031
            ld a, l		; Hyp.cls 2032
            cp 128		; Hyp.cls 2033
            jr c, asm_1_1746_n_fl_hl_n		; Hyp.cls 2034
            ld a, 128		; Hyp.cls 2035
asm_1_1746_n_fl_hl_n:		; Hyp.cls 2036
            ld (asm_1_1746_n_fl_n), a		; Hyp.cls 2037
            ld (asm_1_1746_n_fl_want), a		; Hyp.cls 2038
            call asm_1_1746_n_fl_rdrec           ; a record's worth into buf [2039]
            jr z, asm_1_1746_n_fl_hl_end		; Hyp.cls 2040
            ld b, a		; Hyp.cls 2041
            ld (asm_1_1746_n_fl_want + 1), a		; Hyp.cls 2042
            ld hl, (asm_1_1746_n_fl_cnt)		; Hyp.cls 2043
            ld e, a		; Hyp.cls 2044
            ld d, 0		; Hyp.cls 2045
            add hl, de		; Hyp.cls 2046
            ld (asm_1_1746_n_fl_cnt), hl		; Hyp.cls 2047
            ld hl, (asm_1_1746_n_fl_at)		; Hyp.cls 2048
            ld c, b		; Hyp.cls 2049
            ld b, 0		; Hyp.cls 2050
            call asm_1_1746_n_fl_fits		; Hyp.cls 2051
            jr c, asm_1_1746_n_fl_hl_slow		; Hyp.cls 2052
            push bc		; Hyp.cls 2053
            ld de, (var_hyp_filecall_buf)          ; in one page: one ldir [2054]
            call asm_1_1746_n_fl_toslot		; Hyp.cls 2055
            pop bc		; Hyp.cls 2056
            ld hl, (asm_1_1746_n_fl_at)		; Hyp.cls 2057
            add hl, bc		; Hyp.cls 2058
            jr asm_1_1746_n_fl_hl_put		; Hyp.cls 2059
asm_1_1746_n_fl_hl_slow:		; Hyp.cls 2060
            ld b, c		; Hyp.cls 2061
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2062
asm_1_1746_n_fl_hl_cp:		; Hyp.cls 2063
            ld a, (de)              ; into the slot [2064]
            call asm_1_1746_n_fl_poke		; Hyp.cls 2065
            inc hl		; Hyp.cls 2066
            inc de		; Hyp.cls 2067
            djnz asm_1_1746_n_fl_hl_cp		; Hyp.cls 2068
asm_1_1746_n_fl_hl_put:		; Hyp.cls 2069
            ld (asm_1_1746_n_fl_at), hl		; Hyp.cls 2070
            ld a, (asm_1_1746_n_fl_want)		; Hyp.cls 2071
            ld b, a		; Hyp.cls 2072
            ld a, (asm_1_1746_n_fl_want + 1)		; Hyp.cls 2073
            cp b		; Hyp.cls 2074
            jr z, asm_1_1746_n_fl_hl_lp          ; a whole one: on [2075]
asm_1_1746_n_fl_hl_end:		; Hyp.cls 2076
            ld hl, (asm_1_1746_n_fl_cnt)		; Hyp.cls 2077
            ld (asm_1_1746_n_fl_res16), hl		; Hyp.cls 2078
            ld a, 1		; Hyp.cls 2079
            ld (asm_1_1746_n_fl_r16), a		; Hyp.cls 2080
            jp asm_1_1746_n_fp_done		; Hyp.cls 2081
; ---- 15: open (to read)
asm_1_1746_n_fl_open:		; Hyp.cls 2083
            ld a, (var_hyp_fin)		; Hyp.cls 2084
            or a		; Hyp.cls 2085
            jr z, asm_1_1746_n_fl_op_new		; Hyp.cls 2086
            ld b, a		; Hyp.cls 2087
            ld a, (asm_1_1746_n_fl_slot)		; Hyp.cls 2088
            cp b		; Hyp.cls 2089
            jp nz, asm_1_1746_n_fp_done          ; another slot's being read [2090]
            call asm_1_1746_n_fl_inclose         ; this slot's: CP/M needs no close after reading - this open [2091]
asm_1_1746_n_fl_op_new:                          ; replaces it (Exists opens and leaves it) [2092]
            call asm_1_1746_n_fl_name		; Hyp.cls 2093
            call asm_1_1746_n_fl_inopen		; Hyp.cls 2094
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2095
            ld hl, asm_1_1746_n_fl_name_s        ; kept, to open it again (33 going back) [2096]
            ld de, asm_1_1746_n_fl_inname		; Hyp.cls 2097
            ld bc, 17		; Hyp.cls 2098
            ldir		; Hyp.cls 2099
            ld a, (asm_1_1746_n_fl_slot)		; Hyp.cls 2100
            ld (var_hyp_fin), a		; Hyp.cls 2101
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2102
            ld (asm_1_1746_n_fl_infcb), hl		; Hyp.cls 2103
            ld hl, 0		; Hyp.cls 2104
            ld (asm_1_1746_n_fl_inrec), hl		; Hyp.cls 2105
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2106
; ---- 22: make (a new file, to write)
asm_1_1746_n_fl_make:		; Hyp.cls 2108
            ld a, (var_hyp_fout)		; Hyp.cls 2109
            or a		; Hyp.cls 2110
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 2111
            call asm_1_1746_n_fl_name		; Hyp.cls 2112
            call asm_1_1746_n_fl_plain		; Hyp.cls 2113
            ld hl, asm_1_1746_n_fl_name_s + 1		; Hyp.cls 2114
            ld a, (asm_1_1746_n_fl_name_s)		; Hyp.cls 2115
            ld b, a		; Hyp.cls 2116
            ld de, #4800		; Hyp.cls 2117
            call #BC8C              ; CAS OUT OPEN [2118]
            di		; Hyp.cls 2119
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2120
            ld a, (asm_1_1746_n_fl_slot)		; Hyp.cls 2121
            ld (var_hyp_fout), a		; Hyp.cls 2122
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2123
            ld (asm_1_1746_n_fl_outfcb), hl		; Hyp.cls 2124
            ld hl, 0		; Hyp.cls 2125
            ld (asm_1_1746_n_fl_outrec), hl		; Hyp.cls 2126
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2127
; ---- 16: close
asm_1_1746_n_fl_close:		; Hyp.cls 2129
            call asm_1_1746_n_fl_isin		; Hyp.cls 2130
            jr nz, asm_1_1746_n_fl_cl_out		; Hyp.cls 2131
            call asm_1_1746_n_fl_inclose		; Hyp.cls 2132
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2133
asm_1_1746_n_fl_cl_out:		; Hyp.cls 2134
            call asm_1_1746_n_fl_isout		; Hyp.cls 2135
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 2136
            xor a		; Hyp.cls 2137
            ld (var_hyp_fout), a		; Hyp.cls 2138
            call asm_1_1746_n_fl_plain		; Hyp.cls 2139
            call #BC8F              ; CAS OUT CLOSE [2140]
            di		; Hyp.cls 2141
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2142
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2143
; ---- 19: delete (|ERA, "name")
asm_1_1746_n_fl_del:		; Hyp.cls 2145
            call asm_1_1746_n_fl_name		; Hyp.cls 2146
            call asm_1_1746_n_fl_plain		; Hyp.cls 2147
            ld hl, asm_1_1746_n_fl_name_s + 1		; Hyp.cls 2148
            ld (asm_1_1746_n_fl_desc + 1), hl		; Hyp.cls 2149
            ld a, (asm_1_1746_n_fl_name_s)		; Hyp.cls 2150
            ld (asm_1_1746_n_fl_desc), a		; Hyp.cls 2151
            ld hl, asm_1_1746_n_fl_era		; Hyp.cls 2152
            call #BCD4              ; KL FIND COMMAND: C = its ROM, HL = its address [2153]
            di		; Hyp.cls 2154
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2155
            ld ix, asm_1_1746_n_fl_par		; Hyp.cls 2156
            ld a, 1                 ; one parameter: the string [2157]
            call #001B              ; KL FAR PCALL [2158]
            di		; Hyp.cls 2159
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2160
; ---- 23: rename (the disc ROM's |REN, "new", "old"): the old name at FCB 0-11, the new
; at 16-27 (its drive 0: the old one's)
asm_1_1746_n_fl_ren:		; Hyp.cls 2163
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2164
            call asm_1_1746_n_fl_peek		; Hyp.cls 2165
            ld (asm_1_1746_n_fl_dfl), a		; Hyp.cls 2166
            ld de, 16		; Hyp.cls 2167
            add hl, de		; Hyp.cls 2168
            call asm_1_1746_n_fl_namehl          ; the new name [2169]
            xor a		; Hyp.cls 2170
            ld (asm_1_1746_n_fl_dfl), a		; Hyp.cls 2171
            ld hl, asm_1_1746_n_fl_name_s		; Hyp.cls 2172
            ld de, asm_1_1746_n_fl_new_s		; Hyp.cls 2173
            ld bc, 17		; Hyp.cls 2174
            ldir		; Hyp.cls 2175
            call asm_1_1746_n_fl_name            ; the old one [2176]
            call asm_1_1746_n_fl_plain		; Hyp.cls 2177
            ld hl, asm_1_1746_n_fl_name_s + 1		; Hyp.cls 2178
            ld (asm_1_1746_n_fl_desc + 1), hl		; Hyp.cls 2179
            ld a, (asm_1_1746_n_fl_name_s)		; Hyp.cls 2180
            ld (asm_1_1746_n_fl_desc), a		; Hyp.cls 2181
            ld hl, asm_1_1746_n_fl_new_s + 1		; Hyp.cls 2182
            ld (asm_1_1746_n_fl_desc2 + 1), hl		; Hyp.cls 2183
            ld a, (asm_1_1746_n_fl_new_s)		; Hyp.cls 2184
            ld (asm_1_1746_n_fl_desc2), a		; Hyp.cls 2185
            ld hl, asm_1_1746_n_fl_rencmd		; Hyp.cls 2186
            call #BCD4              ; KL FIND COMMAND [2187]
            di		; Hyp.cls 2188
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2189
            ld ix, asm_1_1746_n_fl_par2          ; IX+0: the last parameter (the old name), IX+2: the new [2190]
            ld a, 2		; Hyp.cls 2191
            call #001B              ; KL FAR PCALL [2192]
            di		; Hyp.cls 2193
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2194
; ---- 33: read record r0-r1: on to it (from the start again if it is behind)
asm_1_1746_n_fl_rdran:		; Hyp.cls 2196
            call asm_1_1746_n_fl_isin		; Hyp.cls 2197
            jp nz, asm_1_1746_n_fl_rdout		; Hyp.cls 2198
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2199
            ld de, 33		; Hyp.cls 2200
            add hl, de		; Hyp.cls 2201
            call asm_1_1746_n_fl_peek		; Hyp.cls 2202
            ld e, a		; Hyp.cls 2203
            inc hl		; Hyp.cls 2204
            call asm_1_1746_n_fl_peek		; Hyp.cls 2205
            ld d, a		; Hyp.cls 2206
            ld (asm_1_1746_n_fl_want), de		; Hyp.cls 2207
            ld hl, (asm_1_1746_n_fl_inrec)		; Hyp.cls 2208
            or a		; Hyp.cls 2209
            sbc hl, de		; Hyp.cls 2210
            jr c, asm_1_1746_n_fl_rr_on		; Hyp.cls 2211
            jr z, asm_1_1746_n_fl_rr_on		; Hyp.cls 2212
            call asm_1_1746_n_fl_inclose         ; behind: open it again [2213]
            ld hl, asm_1_1746_n_fl_inname		; Hyp.cls 2214
            ld de, asm_1_1746_n_fl_name_s		; Hyp.cls 2215
            ld bc, 17		; Hyp.cls 2216
            ldir		; Hyp.cls 2217
            call asm_1_1746_n_fl_inopen		; Hyp.cls 2218
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2219
            ld a, (asm_1_1746_n_fl_slot)		; Hyp.cls 2220
            ld (var_hyp_fin), a		; Hyp.cls 2221
            ld hl, 0		; Hyp.cls 2222
            ld (asm_1_1746_n_fl_inrec), hl		; Hyp.cls 2223
asm_1_1746_n_fl_rr_on:		; Hyp.cls 2224
            ld hl, (asm_1_1746_n_fl_inrec)		; Hyp.cls 2225
            ld de, (asm_1_1746_n_fl_want)		; Hyp.cls 2226
            or a		; Hyp.cls 2227
            sbc hl, de		; Hyp.cls 2228
            jr nc, asm_1_1746_n_fl_rdseq		; Hyp.cls 2229
            call asm_1_1746_n_fl_rdrec		; Hyp.cls 2230
            jp z, asm_1_1746_n_fl_eof		; Hyp.cls 2231
            ld hl, (asm_1_1746_n_fl_inrec)		; Hyp.cls 2232
            inc hl		; Hyp.cls 2233
            ld (asm_1_1746_n_fl_inrec), hl		; Hyp.cls 2234
            jr asm_1_1746_n_fl_rr_on		; Hyp.cls 2235
; ---- 20: read the next record
asm_1_1746_n_fl_rdseq:		; Hyp.cls 2237
            call asm_1_1746_n_fl_isin		; Hyp.cls 2238
            jr nz, asm_1_1746_n_fl_rdout		; Hyp.cls 2239
            call asm_1_1746_n_fl_rdrec		; Hyp.cls 2240
            jr z, asm_1_1746_n_fl_eof		; Hyp.cls 2241
            ex de, hl		; Hyp.cls 2242
            ld hl, (asm_1_1746_n_fl_inrec)		; Hyp.cls 2243
            inc hl		; Hyp.cls 2244
            ld (asm_1_1746_n_fl_inrec), hl		; Hyp.cls 2245
            ex de, hl		; Hyp.cls 2246
            ld b, a                 ; the record padded with #1A [2247]
            ld a, 128		; Hyp.cls 2248
            sub b		; Hyp.cls 2249
            jr z, asm_1_1746_n_fl_rd_put		; Hyp.cls 2250
            ld b, a		; Hyp.cls 2251
            ld a, #1A		; Hyp.cls 2252
asm_1_1746_n_fl_rd_pad:		; Hyp.cls 2253
            ld (hl), a		; Hyp.cls 2254
            inc hl		; Hyp.cls 2255
            djnz asm_1_1746_n_fl_rd_pad		; Hyp.cls 2256
asm_1_1746_n_fl_rd_put:		; Hyp.cls 2257
            ld hl, (var_hyp_filecall_dma)          ; into the slot's DMA: in one page, one ldir [2258]
            ld bc, 128		; Hyp.cls 2259
            call asm_1_1746_n_fl_fits		; Hyp.cls 2260
            jr c, asm_1_1746_n_fl_rd_slow		; Hyp.cls 2261
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2262
            call asm_1_1746_n_fl_toslot		; Hyp.cls 2263
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2264
asm_1_1746_n_fl_rd_slow:                         ; (across two pages: a byte at a time) [2265]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2266
            ld de, (var_hyp_filecall_dma)		; Hyp.cls 2267
            ld b, 128		; Hyp.cls 2268
asm_1_1746_n_fl_rd_cp:		; Hyp.cls 2269
            ld a, (hl)		; Hyp.cls 2270
            ex de, hl		; Hyp.cls 2271
            call asm_1_1746_n_fl_poke		; Hyp.cls 2272
            ex de, hl		; Hyp.cls 2273
            inc hl		; Hyp.cls 2274
            inc de		; Hyp.cls 2275
            djnz asm_1_1746_n_fl_rd_cp		; Hyp.cls 2276
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2277
asm_1_1746_n_fl_rdout:		; Hyp.cls 2278
            call asm_1_1746_n_fl_isout           ; a file being written: nothing to read back [2279]
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 2280
asm_1_1746_n_fl_eof:		; Hyp.cls 2281
            ld a, 1		; Hyp.cls 2282
            ld (asm_1_1746_n_fl_res), a		; Hyp.cls 2283
            jp asm_1_1746_n_fp_done		; Hyp.cls 2284
; ---- 21 / 34: write the next record
asm_1_1746_n_fl_write:		; Hyp.cls 2286
            call asm_1_1746_n_fl_isout		; Hyp.cls 2287
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 2288
            ld hl, (var_hyp_filecall_dma)          ; the slot's DMA into buf [2289]
            ld bc, 128		; Hyp.cls 2290
            call asm_1_1746_n_fl_fits		; Hyp.cls 2291
            jr c, asm_1_1746_n_fl_wr_slow		; Hyp.cls 2292
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2293
            call asm_1_1746_n_fl_fromslot		; Hyp.cls 2294
            jr asm_1_1746_n_fl_wr_got		; Hyp.cls 2295
asm_1_1746_n_fl_wr_slow:		; Hyp.cls 2296
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2297
            ld b, 128		; Hyp.cls 2298
asm_1_1746_n_fl_wr_cp:		; Hyp.cls 2299
            call asm_1_1746_n_fl_peek		; Hyp.cls 2300
            ld (de), a		; Hyp.cls 2301
            inc hl		; Hyp.cls 2302
            inc de		; Hyp.cls 2303
            djnz asm_1_1746_n_fl_wr_cp		; Hyp.cls 2304
asm_1_1746_n_fl_wr_got:		; Hyp.cls 2305
            call asm_1_1746_n_fl_plain		; Hyp.cls 2306
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2307
            ld b, 128		; Hyp.cls 2308
asm_1_1746_n_fl_wr_lp:		; Hyp.cls 2309
            ld a, (hl)		; Hyp.cls 2310
            push bc		; Hyp.cls 2311
            push hl		; Hyp.cls 2312
            call #BC95              ; CAS OUT CHAR [2313]
            di		; Hyp.cls 2314
            pop hl		; Hyp.cls 2315
            pop bc		; Hyp.cls 2316
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2317
            inc hl		; Hyp.cls 2318
            djnz asm_1_1746_n_fl_wr_lp		; Hyp.cls 2319
            ld hl, (asm_1_1746_n_fl_outrec)		; Hyp.cls 2320
            inc hl		; Hyp.cls 2321
            ld (asm_1_1746_n_fl_outrec), hl		; Hyp.cls 2322
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2323
; ---- 35: the file's size in records (r0-r2): counted, reading it through. The file this slot
; is reading is opened again after, at its record; another slot's being read: 255
asm_1_1746_n_fl_size:		; Hyp.cls 2326
            ld a, (var_hyp_fin)		; Hyp.cls 2327
            or a		; Hyp.cls 2328
            jr z, asm_1_1746_n_fl_sz_free		; Hyp.cls 2329
            ld b, a		; Hyp.cls 2330
            ld a, (asm_1_1746_n_fl_slot)		; Hyp.cls 2331
            cp b		; Hyp.cls 2332
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 2333
            call asm_1_1746_n_fl_inclose		; Hyp.cls 2334
            ld a, 1		; Hyp.cls 2335
asm_1_1746_n_fl_sz_free:		; Hyp.cls 2336
            ld (asm_1_1746_n_fl_had), a		; Hyp.cls 2337
            call asm_1_1746_n_fl_name		; Hyp.cls 2338
            call asm_1_1746_n_fl_inopen		; Hyp.cls 2339
            jr nc, asm_1_1746_n_fl_sz_back		; Hyp.cls 2340
            ld hl, 0		; Hyp.cls 2341
            ld (asm_1_1746_n_fl_cnt), hl		; Hyp.cls 2342
asm_1_1746_n_fl_sz_lp:		; Hyp.cls 2343
            call asm_1_1746_n_fl_rdrec		; Hyp.cls 2344
            jr z, asm_1_1746_n_fl_sz_end		; Hyp.cls 2345
            ld hl, (asm_1_1746_n_fl_cnt)		; Hyp.cls 2346
            inc hl		; Hyp.cls 2347
            ld (asm_1_1746_n_fl_cnt), hl		; Hyp.cls 2348
            cp 128		; Hyp.cls 2349
            jr z, asm_1_1746_n_fl_sz_lp		; Hyp.cls 2350
asm_1_1746_n_fl_sz_end:		; Hyp.cls 2351
            call asm_1_1746_n_fl_inclose		; Hyp.cls 2352
            ld hl, (asm_1_1746_n_fl_cnt)		; Hyp.cls 2353
            call asm_1_1746_n_fl_ranput		; Hyp.cls 2354
            xor a		; Hyp.cls 2355
            ld (asm_1_1746_n_fl_res), a		; Hyp.cls 2356
asm_1_1746_n_fl_sz_back:		; Hyp.cls 2357
            ld a, (asm_1_1746_n_fl_had)		; Hyp.cls 2358
            or a		; Hyp.cls 2359
            jp z, asm_1_1746_n_fp_done		; Hyp.cls 2360
            ld hl, asm_1_1746_n_fl_inname        ; the slot's read file again, on to its record [2361]
            ld de, asm_1_1746_n_fl_name_s		; Hyp.cls 2362
            ld bc, 17		; Hyp.cls 2363
            ldir		; Hyp.cls 2364
            call asm_1_1746_n_fl_inopen		; Hyp.cls 2365
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2366
            ld a, (asm_1_1746_n_fl_slot)		; Hyp.cls 2367
            ld (var_hyp_fin), a		; Hyp.cls 2368
            ld hl, (asm_1_1746_n_fl_inrec)		; Hyp.cls 2369
asm_1_1746_n_fl_sz_skip:		; Hyp.cls 2370
            ld a, h		; Hyp.cls 2371
            or l		; Hyp.cls 2372
            jp z, asm_1_1746_n_fp_done		; Hyp.cls 2373
            push hl		; Hyp.cls 2374
            call asm_1_1746_n_fl_rdrec		; Hyp.cls 2375
            pop hl		; Hyp.cls 2376
            dec hl		; Hyp.cls 2377
            jr asm_1_1746_n_fl_sz_skip		; Hyp.cls 2378
; ---- 36: set the random record (r0-r2) from where the file is: the next record read or
; written; a file not open here: from the FCB's extent and record (ex * 128 + cr)
asm_1_1746_n_fl_setran:		; Hyp.cls 2381
            call asm_1_1746_n_fl_isin		; Hyp.cls 2382
            ld hl, (asm_1_1746_n_fl_inrec)		; Hyp.cls 2383
            jr z, asm_1_1746_n_fl_sr_put		; Hyp.cls 2384
            call asm_1_1746_n_fl_isout		; Hyp.cls 2385
            ld hl, (asm_1_1746_n_fl_outrec)		; Hyp.cls 2386
            jr z, asm_1_1746_n_fl_sr_put		; Hyp.cls 2387
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2388
            ld de, 32		; Hyp.cls 2389
            add hl, de		; Hyp.cls 2390
            call asm_1_1746_n_fl_peek            ; cr [2391]
            ld e, a		; Hyp.cls 2392
            ld bc, -20		; Hyp.cls 2393
            add hl, bc		; Hyp.cls 2394
            call asm_1_1746_n_fl_peek            ; ex [2395]
            ld h, a		; Hyp.cls 2396
            srl h		; Hyp.cls 2397
            ld a, e		; Hyp.cls 2398
            jr nc, asm_1_1746_n_fl_sr_lo		; Hyp.cls 2399
            or #80		; Hyp.cls 2400
asm_1_1746_n_fl_sr_lo:		; Hyp.cls 2401
            ld l, a		; Hyp.cls 2402
asm_1_1746_n_fl_sr_put:		; Hyp.cls 2403
            call asm_1_1746_n_fl_ranput		; Hyp.cls 2404
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2405
; ---- 17 / 18: search FILES.DIR (on the FCB's drive, else the slot's) for BDOS 17's name ("?"
; any character; kept at SRCH in the bank, SRCH + 12 the entries passed - 18 goes on from
; there): the next one, as a CP/M directory entry at the DMA (its record count from its
; length, 128 at most). 17 reads FILES.DIR into the hypervisor's page (#6000-#7FFF: 128 entries
; at most), then 17 and 18 look there - not the disc again for each 18 (a DIR read the file once
; per entry). 17: not while a file is being read (255)
asm_1_1746_n_fl_srch1:		; Hyp.cls 2412
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2413
            ld de, 63216		; Hyp.cls 2414
            ld b, 12		; Hyp.cls 2415
asm_1_1746_n_fl_s1_lp:		; Hyp.cls 2416
            call asm_1_1746_n_fl_peek		; Hyp.cls 2417
            ex de, hl		; Hyp.cls 2418
            call asm_1_1746_n_fl_poke		; Hyp.cls 2419
            ex de, hl		; Hyp.cls 2420
            inc hl		; Hyp.cls 2421
            inc de		; Hyp.cls 2422
            djnz asm_1_1746_n_fl_s1_lp		; Hyp.cls 2423
            ex de, hl		; Hyp.cls 2424
            xor a		; Hyp.cls 2425
            call asm_1_1746_n_fl_poke            ; none passed [2426]
            ld a, (var_hyp_fin)		; Hyp.cls 2427
            or a		; Hyp.cls 2428
            jp nz, asm_1_1746_n_fp_done		; Hyp.cls 2429
            ld de, asm_1_1746_n_fl_name_s + 1    ; "B:FILES.DIR" [2430]
            ld hl, 63216		; Hyp.cls 2431
            call asm_1_1746_n_fl_peek		; Hyp.cls 2432
            or a		; Hyp.cls 2433
            jr z, asm_1_1746_n_fl_s_own		; Hyp.cls 2434
            add a, 64		; Hyp.cls 2435
            jr asm_1_1746_n_fl_s_drv		; Hyp.cls 2436
asm_1_1746_n_fl_s_own:		; Hyp.cls 2437
            ld a, (var_hyp_filecall_drive)		; Hyp.cls 2438
            or a		; Hyp.cls 2439
            jr z, asm_1_1746_n_fl_s_nod		; Hyp.cls 2440
asm_1_1746_n_fl_s_drv:		; Hyp.cls 2441
            ld (de), a		; Hyp.cls 2442
            inc de		; Hyp.cls 2443
            ld a, ':'		; Hyp.cls 2444
            ld (de), a		; Hyp.cls 2445
            inc de		; Hyp.cls 2446
asm_1_1746_n_fl_s_nod:		; Hyp.cls 2447
            ld hl, asm_1_1746_n_fl_fdir		; Hyp.cls 2448
            ld bc, 9		; Hyp.cls 2449
            ldir		; Hyp.cls 2450
            ld hl, -(asm_1_1746_n_fl_name_s + 1)		; Hyp.cls 2451
            add hl, de		; Hyp.cls 2452
            ld a, l		; Hyp.cls 2453
            ld (asm_1_1746_n_fl_name_s), a		; Hyp.cls 2454
            xor a		; Hyp.cls 2455
            ld (asm_1_1746_n_fl_cn), a		; Hyp.cls 2456
            call asm_1_1746_n_fl_inopen		; Hyp.cls 2457
            jp nc, asm_1_1746_n_fp_done		; Hyp.cls 2458
            ld hl, #6000            ; FILES.DIR into the cache [2459]
            ld (asm_1_1746_n_fl_at), hl		; Hyp.cls 2460
asm_1_1746_n_fl_sc_ld:		; Hyp.cls 2461
            ld a, 64		; Hyp.cls 2462
            ld (asm_1_1746_n_fl_n), a		; Hyp.cls 2463
            call asm_1_1746_n_fl_rdrec		; Hyp.cls 2464
            cp 64		; Hyp.cls 2465
            jr nz, asm_1_1746_n_fl_sc_end		; Hyp.cls 2466
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2467
            ld de, (asm_1_1746_n_fl_at)		; Hyp.cls 2468
            ld bc, 64		; Hyp.cls 2469
            ldir		; Hyp.cls 2470
            ld (asm_1_1746_n_fl_at), de		; Hyp.cls 2471
            ld hl, asm_1_1746_n_fl_cn		; Hyp.cls 2472
            inc (hl)		; Hyp.cls 2473
            ld a, (hl)		; Hyp.cls 2474
            cp 128		; Hyp.cls 2475
            jr c, asm_1_1746_n_fl_sc_ld		; Hyp.cls 2476
asm_1_1746_n_fl_sc_end:		; Hyp.cls 2477
            call asm_1_1746_n_fl_inclose		; Hyp.cls 2478
asm_1_1746_n_fl_srch:		; Hyp.cls 2479
            ld hl, 63216 + 12		; Hyp.cls 2480
            call asm_1_1746_n_fl_peek		; Hyp.cls 2481
            ld (asm_1_1746_n_fl_skip), a		; Hyp.cls 2482
            xor a		; Hyp.cls 2483
            ld (asm_1_1746_n_fl_k), a		; Hyp.cls 2484
asm_1_1746_n_fl_s_lp:		; Hyp.cls 2485
            ld a, (asm_1_1746_n_fl_cn)           ; the next entry, from the cache [2486]
            ld b, a		; Hyp.cls 2487
            ld a, (asm_1_1746_n_fl_k)		; Hyp.cls 2488
            cp b		; Hyp.cls 2489
            jp nc, asm_1_1746_n_fp_done          ; (none: 255) [2490]
            ld l, a		; Hyp.cls 2491
            ld h, 0		; Hyp.cls 2492
            add hl, hl		; Hyp.cls 2493
            add hl, hl		; Hyp.cls 2494
            add hl, hl		; Hyp.cls 2495
            add hl, hl		; Hyp.cls 2496
            add hl, hl		; Hyp.cls 2497
            add hl, hl		; Hyp.cls 2498
            ld de, #6000		; Hyp.cls 2499
            add hl, de		; Hyp.cls 2500
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2501
            ld bc, 64		; Hyp.cls 2502
            ldir		; Hyp.cls 2503
            ld hl, asm_1_1746_n_fl_k		; Hyp.cls 2504
            inc (hl)		; Hyp.cls 2505
            ld a, (asm_1_1746_n_fl_skip)		; Hyp.cls 2506
            cp (hl)		; Hyp.cls 2507
            jr nc, asm_1_1746_n_fl_s_lp          ; passed already [2508]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2509
            ld a, (hl)		; Hyp.cls 2510
            dec a		; Hyp.cls 2511
            jr nz, asm_1_1746_n_fl_s_lp          ; not in use (1) [2512]
            inc hl		; Hyp.cls 2513
            ld de, 63216 + 1		; Hyp.cls 2514
            ld b, 11		; Hyp.cls 2515
asm_1_1746_n_fl_s_cmp:		; Hyp.cls 2516
            ex de, hl		; Hyp.cls 2517
            call asm_1_1746_n_fl_peek		; Hyp.cls 2518
            ex de, hl		; Hyp.cls 2519
            and #7F		; Hyp.cls 2520
            cp '?'		; Hyp.cls 2521
            jr z, asm_1_1746_n_fl_s_any		; Hyp.cls 2522
            ld c, a		; Hyp.cls 2523
            ld a, (hl)		; Hyp.cls 2524
            and #7F		; Hyp.cls 2525
            cp c		; Hyp.cls 2526
            jr nz, asm_1_1746_n_fl_s_lp		; Hyp.cls 2527
asm_1_1746_n_fl_s_any:		; Hyp.cls 2528
            inc hl		; Hyp.cls 2529
            inc de		; Hyp.cls 2530
            djnz asm_1_1746_n_fl_s_cmp		; Hyp.cls 2531
            ld hl, (var_hyp_filecall_buf)          ; the entry: user 0, the name, extent 0, the records, no blocks [2532]
            ld (hl), 0		; Hyp.cls 2533
            ld de, 14		; Hyp.cls 2534
            add hl, de		; Hyp.cls 2535
            ld e, (hl)		; Hyp.cls 2536
            inc hl		; Hyp.cls 2537
            ld d, (hl)		; Hyp.cls 2538
            ex de, hl		; Hyp.cls 2539
            ld bc, 127		; Hyp.cls 2540
            add hl, bc		; Hyp.cls 2541
            jr c, asm_1_1746_n_fl_s_big		; Hyp.cls 2542
            ld a, h		; Hyp.cls 2543
            cp #40		; Hyp.cls 2544
            jr nc, asm_1_1746_n_fl_s_big		; Hyp.cls 2545
            sla l		; Hyp.cls 2546
            rla		; Hyp.cls 2547
            jr asm_1_1746_n_fl_s_rc		; Hyp.cls 2548
asm_1_1746_n_fl_s_big:		; Hyp.cls 2549
            ld a, 128		; Hyp.cls 2550
asm_1_1746_n_fl_s_rc:		; Hyp.cls 2551
            ex de, hl		; Hyp.cls 2552
            ld (hl), a		; Hyp.cls 2553
            ld b, 3		; Hyp.cls 2554
asm_1_1746_n_fl_s_z1:		; Hyp.cls 2555
            dec hl		; Hyp.cls 2556
            ld (hl), 0		; Hyp.cls 2557
            djnz asm_1_1746_n_fl_s_z1		; Hyp.cls 2558
            ld de, 4		; Hyp.cls 2559
            add hl, de		; Hyp.cls 2560
            ld b, 16		; Hyp.cls 2561
asm_1_1746_n_fl_s_z2:		; Hyp.cls 2562
            ld (hl), 0		; Hyp.cls 2563
            inc hl		; Hyp.cls 2564
            djnz asm_1_1746_n_fl_s_z2		; Hyp.cls 2565
            ld hl, (var_hyp_filecall_dma)		; Hyp.cls 2566
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2567
            ld b, 32		; Hyp.cls 2568
asm_1_1746_n_fl_s_put:		; Hyp.cls 2569
            ld a, (de)		; Hyp.cls 2570
            call asm_1_1746_n_fl_poke		; Hyp.cls 2571
            inc hl		; Hyp.cls 2572
            inc de		; Hyp.cls 2573
            djnz asm_1_1746_n_fl_s_put		; Hyp.cls 2574
            ld hl, 63216 + 12		; Hyp.cls 2575
            ld a, (asm_1_1746_n_fl_k)		; Hyp.cls 2576
            call asm_1_1746_n_fl_poke		; Hyp.cls 2577
            jp asm_1_1746_n_fl_ok		; Hyp.cls 2578
asm_1_1746_n_fl_fdir:    db "FILES.DIR"		; Hyp.cls 2579
asm_1_1746_n_fl_skip:    db 0		; Hyp.cls 2580
asm_1_1746_n_fl_k:       db 0		; Hyp.cls 2581
asm_1_1746_n_fl_cn:      db 0                    ; FILES.DIR's entries in the cache (#6000) [2582]
asm_1_1746_n_fl_ranput:                          ; the FCB's r0-r2 = HL [2583]
            ex de, hl		; Hyp.cls 2584
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2585
            ld bc, 33		; Hyp.cls 2586
            add hl, bc		; Hyp.cls 2587
            ld a, e		; Hyp.cls 2588
            call asm_1_1746_n_fl_poke		; Hyp.cls 2589
            inc hl		; Hyp.cls 2590
            ld a, d		; Hyp.cls 2591
            call asm_1_1746_n_fl_poke		; Hyp.cls 2592
            inc hl		; Hyp.cls 2593
            xor a		; Hyp.cls 2594
            jp asm_1_1746_n_fl_poke		; Hyp.cls 2595
; ---- the parts
asm_1_1746_n_fl_isin:                            ; Z: the file being read is this slot's, this FCB [2597]
            ld a, (var_hyp_fin)		; Hyp.cls 2598
            ld hl, asm_1_1746_n_fl_infcb		; Hyp.cls 2599
            jr asm_1_1746_n_fl_is		; Hyp.cls 2600
asm_1_1746_n_fl_isout:		; Hyp.cls 2601
            ld a, (var_hyp_fout)		; Hyp.cls 2602
            ld hl, asm_1_1746_n_fl_outfcb		; Hyp.cls 2603
asm_1_1746_n_fl_is:		; Hyp.cls 2604
            ld b, a		; Hyp.cls 2605
            ld a, (asm_1_1746_n_fl_slot)		; Hyp.cls 2606
            cp b		; Hyp.cls 2607
            ret nz		; Hyp.cls 2608
            ld e, (hl)		; Hyp.cls 2609
            inc hl		; Hyp.cls 2610
            ld d, (hl)		; Hyp.cls 2611
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2612
            or a		; Hyp.cls 2613
            sbc hl, de		; Hyp.cls 2614
            ret		; Hyp.cls 2615
asm_1_1746_n_fl_inopen:                          ; open fl_name_s to read: carry = done [2616]
            call asm_1_1746_n_fl_plain		; Hyp.cls 2617
            ld hl, asm_1_1746_n_fl_name_s + 1		; Hyp.cls 2618
            ld a, (asm_1_1746_n_fl_name_s)		; Hyp.cls 2619
            ld b, a		; Hyp.cls 2620
            ld de, #4000		; Hyp.cls 2621
            call #BC77              ; CAS IN OPEN [2622]
            di		; Hyp.cls 2623
            ret		; Hyp.cls 2624
asm_1_1746_n_fl_inclose:		; Hyp.cls 2625
            xor a		; Hyp.cls 2626
            ld (var_hyp_fin), a		; Hyp.cls 2627
            call asm_1_1746_n_fl_plain		; Hyp.cls 2628
            call #BC7A              ; CAS IN CLOSE [2629]
            di		; Hyp.cls 2630
            ret		; Hyp.cls 2631
asm_1_1746_n_fl_rdrec:                           ; read up to fl_n bytes (128) into buf: A = how many (Z [2632]
            call asm_1_1746_n_fl_plain           ; none), HL past them. A #1A is a byte (the soft end of file) [2633]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2634
            ld a, (asm_1_1746_n_fl_n)		; Hyp.cls 2635
            ld b, a		; Hyp.cls 2636
asm_1_1746_n_fl_rr_lp:		; Hyp.cls 2637
            push bc		; Hyp.cls 2638
            push hl		; Hyp.cls 2639
            call #BC80              ; CAS IN CHAR [2640]
            di		; Hyp.cls 2641
            pop hl		; Hyp.cls 2642
            pop bc		; Hyp.cls 2643
            jr c, asm_1_1746_n_fl_rr_b		; Hyp.cls 2644
            cp #1A		; Hyp.cls 2645
            jr nz, asm_1_1746_n_fl_rr_end		; Hyp.cls 2646
asm_1_1746_n_fl_rr_b:		; Hyp.cls 2647
            ld (hl), a		; Hyp.cls 2648
            inc hl		; Hyp.cls 2649
            djnz asm_1_1746_n_fl_rr_lp		; Hyp.cls 2650
asm_1_1746_n_fl_rr_end:		; Hyp.cls 2651
            ld a, (asm_1_1746_n_fl_n)		; Hyp.cls 2652
            sub b		; Hyp.cls 2653
            ld c, a		; Hyp.cls 2654
            ld a, 128		; Hyp.cls 2655
            ld (asm_1_1746_n_fl_n), a            ; (128 again for the next) [2656]
            ld a, c		; Hyp.cls 2657
            or a		; Hyp.cls 2658
            ret		; Hyp.cls 2659
asm_1_1746_n_fl_fits:                            ; HL = a slot address, BC = bytes: NC = all in its 16K page. [2660]
            push hl                 ; Keeps BC, DE, HL [2661]
            ld a, h		; Hyp.cls 2662
            and #3F		; Hyp.cls 2663
            ld h, a		; Hyp.cls 2664
            add hl, bc		; Hyp.cls 2665
            ld a, h		; Hyp.cls 2666
            cp #40		; Hyp.cls 2667
            jr c, asm_1_1746_n_fl_ft_ok		; Hyp.cls 2668
            jr nz, asm_1_1746_n_fl_ft_no		; Hyp.cls 2669
            ld a, l		; Hyp.cls 2670
            or a		; Hyp.cls 2671
            jr nz, asm_1_1746_n_fl_ft_no		; Hyp.cls 2672
asm_1_1746_n_fl_ft_ok:		; Hyp.cls 2673
            pop hl		; Hyp.cls 2674
            or a		; Hyp.cls 2675
            ret		; Hyp.cls 2676
asm_1_1746_n_fl_ft_no:		; Hyp.cls 2677
            pop hl		; Hyp.cls 2678
            scf		; Hyp.cls 2679
            ret		; Hyp.cls 2680
asm_1_1746_n_fl_plain:                           ; the hypervisor's page in the window (the buffers) [2681]
            ld bc, (var_hyp_hps)		; Hyp.cls 2682
            out (c), c		; Hyp.cls 2683
            ret		; Hyp.cls 2684
asm_1_1746_n_fl_name:                            ; fl_name_s = the FCB's file: length, "B:NAME.EXT" [2685]
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2686
asm_1_1746_n_fl_namehl:                          ; (HL = an FCB in the slot) [2687]
            ld de, asm_1_1746_n_fl_name_s + 1		; Hyp.cls 2688
            call asm_1_1746_n_fl_peek            ; its drive: 0 = the slot's (or fl_dfl's) [2689]
            or a		; Hyp.cls 2690
            jr nz, asm_1_1746_n_fl_nm_d		; Hyp.cls 2691
            ld a, (asm_1_1746_n_fl_dfl)		; Hyp.cls 2692
            or a		; Hyp.cls 2693
            jr nz, asm_1_1746_n_fl_nm_d		; Hyp.cls 2694
            ld a, (var_hyp_filecall_drive)		; Hyp.cls 2695
            or a		; Hyp.cls 2696
            jr z, asm_1_1746_n_fl_nm_nod		; Hyp.cls 2697
            sub 64		; Hyp.cls 2698
asm_1_1746_n_fl_nm_d:		; Hyp.cls 2699
            add a, 64		; Hyp.cls 2700
            ld (de), a		; Hyp.cls 2701
            inc de		; Hyp.cls 2702
            ld a, ':'		; Hyp.cls 2703
            ld (de), a		; Hyp.cls 2704
            inc de		; Hyp.cls 2705
asm_1_1746_n_fl_nm_nod:		; Hyp.cls 2706
            ld b, 11		; Hyp.cls 2707
asm_1_1746_n_fl_nm_lp:		; Hyp.cls 2708
            inc hl		; Hyp.cls 2709
            ld a, b		; Hyp.cls 2710
            cp 3		; Hyp.cls 2711
            jr nz, asm_1_1746_n_fl_nm_c		; Hyp.cls 2712
            ld a, '.'		; Hyp.cls 2713
            ld (de), a		; Hyp.cls 2714
            inc de		; Hyp.cls 2715
asm_1_1746_n_fl_nm_c:		; Hyp.cls 2716
            call asm_1_1746_n_fl_peek		; Hyp.cls 2717
            and #7F		; Hyp.cls 2718
            cp ' ' + 1		; Hyp.cls 2719
            jr c, asm_1_1746_n_fl_nm_sk		; Hyp.cls 2720
            ld (de), a		; Hyp.cls 2721
            inc de		; Hyp.cls 2722
asm_1_1746_n_fl_nm_sk:		; Hyp.cls 2723
            djnz asm_1_1746_n_fl_nm_lp		; Hyp.cls 2724
            ex de, hl		; Hyp.cls 2725
            ld de, asm_1_1746_n_fl_name_s + 1		; Hyp.cls 2726
            or a		; Hyp.cls 2727
            sbc hl, de		; Hyp.cls 2728
            ld a, l		; Hyp.cls 2729
            ld (asm_1_1746_n_fl_name_s), a		; Hyp.cls 2730
            ret		; Hyp.cls 2731
asm_1_1746_n_fl_ok:		; Hyp.cls 2732
            xor a		; Hyp.cls 2733
            ld (asm_1_1746_n_fl_res), a		; Hyp.cls 2734
asm_1_1746_n_fp_done:                            ; back to FileCall in main RAM (fp_done) [2735]
            ld sp, (asm_1_1746_n_fp_sp)		; Hyp.cls 2736
            ret		; Hyp.cls 2737
asm_1_1746_n_fl_era:     db "ER", "A" + #80		; Hyp.cls 2738
asm_1_1746_n_fl_rencmd:  db "RE", "N" + #80		; Hyp.cls 2739
asm_1_1746_n_fl_par2:    dw asm_1_1746_n_fl_desc, asm_1_1746_n_fl_desc2		; Hyp.cls 2740
asm_1_1746_n_fl_desc2:   db 0		; Hyp.cls 2741
            dw 0		; Hyp.cls 2742
asm_1_1746_n_fl_dfl:     db 0                    ; fl_name: the drive for an FCB whose own is 0 (rename) [2743]
asm_1_1746_n_fl_new_s:   ds 17		; Hyp.cls 2744
asm_1_1746_n_fl_par:     dw asm_1_1746_n_fl_desc		; Hyp.cls 2745
asm_1_1746_n_fl_desc:    db 0		; Hyp.cls 2746
            dw 0		; Hyp.cls 2747
asm_1_1746_n_fl_n:       db 128                  ; bytes fl_rdrec reads [2748]
asm_1_1746_n_fl_cnt:     dw 0		; Hyp.cls 2749
asm_1_1746_n_fl_at:      dw 0		; Hyp.cls 2750
asm_1_1746_n_fl_infcb:   dw 0		; Hyp.cls 2751
asm_1_1746_n_fl_inrec:   dw 0		; Hyp.cls 2752
asm_1_1746_n_fl_want:    dw 0		; Hyp.cls 2753
asm_1_1746_n_fl_outfcb:  dw 0		; Hyp.cls 2754
asm_1_1746_n_fl_outrec:  dw 0                    ; the next record written (36) [2755]
asm_1_1746_n_fl_had:     db 0                    ; 35: this slot's read file closed for it [2756]
asm_1_1746_n_fl_name_s:  ds 17                   ; length, then "B:NAME.EXT" [2757]
asm_1_1746_n_fl_inname:  ds 17                   ; the one being read's (33 going back) [2758]
asm_1_1746_n_fp_sp:      dw 0		; Hyp.cls 2759
asm_1_1746_n_fp_end:		; Hyp.cls 2760
            ASSERT asm_1_1746_n_fp_end <= #6000, "FileCall's page code: below the FILES.DIR cache (#6000)"		; Hyp.cls 2761
			ENDM
; ============================================================
; NTC program - generated by NTC BASIC (VB style BASIC to NTC)
; platform: cpcfw (Amstrad CPC - firmware text and keys), starts in normal mode
; ============================================================

			DEVICE AMSTRADCPC6128		; for SAVEAMSDOS at the end
			org #0040

NTC_TERM	equ 0		; Option Terminal: 0 none, 1 VT52, 2 ANSI (CP/M)
NTC_STRMAX	equ 255		; the longest string (library buffers, temps)
NTC_MEMBANKS	equ 8		; Option Memory: the most 64K banks the Memory class looks for
NTC_ROMENABLE	equ 1		; Option RomEnable (cpcfw, cpcmin): the start code starts the ROMs
NTC_ROMLIB	equ 1		; 1 = the library is the keyword ROM (Library: ROM; ntcRomAsm builds it)
NTC_WINHOLE	equ 1		; 1 = the program is built round an Option Reserve range over the window #4000-#7FFF
NTC_BUFSIZE	equ 2048		; the library's buffer (ntc_buf: FileSystem, Memory.Copy): Option Buffer
NTC_CPMGFX	equ 0		; 1 = CP/M: Graphics draws on an Amstrad CPC's screen (2.2: #C000, Plus: block 1 from common memory)

ntc_start:
			jr ntc_start2
ntc_bk_sp:		dw 0			; #0042: main RAM's SP while a bank runs
ntc_bk_out:
			out (c), c		; #0044: BC = the other side's RAM setting
			jp ntc_bk_land		; #0046: main RAM switched in
ntc_bk_land:
			ld sp, (ntc_bk_sp)
			ret				; to where main RAM handed over
			ASSERT ntc_bk_out == #0044, "the bank switch must be at #0044"
ntc_start2:
			di
			call ntc_rj_find		; Library: ROM - find the ROM, patch the jump block
			jr nc, ntc_rj_ok
			ei
			ret				; no ROM (the message is shown): back to the caller
ntc_rj_ok:
			di				; (KL ROM SELECT lets interrupts in again)
			ld hl, ntc_rj_exit
			push hl			; End comes back here: the caller's ROM selection again
			ld (ntc_csp), sp
			ld a, (#BC77)		; Option RomEnable: start the ROMs again
			cp #DF			; AMSDOS has the cassette calls: they are running
			jp z, ntc_roms_on
			ei
			ld de, #A5F0		; the lowest address the ROMs may use (the keyword ROM's RAM is below)
			ld hl, #ABFF		; the highest (as usual for AMSDOS: it takes about #A700-#ABFF)
			call #BCCB		; KL ROM WALK: every background ROM
			inc hl			; the first byte the ROMs took
			ld (ntc_roms_at), hl
			ld de, #A600
			or a
			sbc hl, de
			jp nc, ntc_roms_fit	; AMSDOS alone (or no more): as usual
			ld hl, ntc_roms_msg
			call ntc_roms_puts
			ld a, (ntc_roms_at + 1)
			call ntc_roms_hex
			ld a, (ntc_roms_at)
			call ntc_roms_hex
			ld hl, ntc_roms_msg2
			call ntc_roms_puts
			call #BB06		; KM WAIT CHAR
			rst 0			; (the machine starts again)
ntc_roms_puts:
			ld a, (hl)
			or a
			ret z
			call #BB5A		; TXT OUTPUT
			inc hl
			jr ntc_roms_puts
ntc_roms_hex:
			push af
			rrca
			rrca
			rrca
			rrca
			call ntc_roms_dig
			pop af
ntc_roms_dig:
			and 15
			add a, #90
			daa
			adc a, #40
			daa
			jp #BB5A
ntc_roms_at:	dw 0
ntc_roms_msg:	db "The ROMs' RAM reaches down to #", 0
ntc_roms_msg2:	db ": no room for this program", 13, 10, "(fewer ROMs, or a smaller program)", 13, 10, "Press a key", 13, 10, 0
ntc_roms_fit:
			di
			ASSERT ntc_free <= #A600, "Option RomEnable: the program and its arrays must end below #A600 (the ROMs take their RAM from #ABFF down)"
ntc_roms_on:
			ld a, 1
			ld (ntc_nmode), a		; normal mode: waits let interrupts in
			; Option Class Interrupt: the classes' Tick subs, run at safe points (normal mode)
			ld hl, 6		; hot: every 6 interrupts
			ld (ntc_isl + 2), hl
			ld hl, 7			; the first after one period (+ the slot, so they take turns)
			ld (ntc_isl + 0), hl
			ld hl, p_hot_tick_c
			ld (ntc_isl + 6), hl
			ld a, 1
			ld (ntc_isln), a
			ld hl, (ntc_isl_tick + 1)	; (Library: ROM: its address in the ROM - the jump block, low in RAM, is hidden by the lower ROM in the interrupt)
			ld (ntc_irqv), hl		; the interrupt handler counts for them
			ld ix, ntc_go
			jp ntc_plat_irqon		; interrupt handler for normal mode
ntc_go:
			ld sp, main_thread
			ret

			IF ($ < 32768) && (ntc_rg1_e - ntc_rg1 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg1:
; ============================================================
; Main Thread
; ============================================================

main_thread:
			dw kw_bssinit, ntc_bss, ntc_bss_size		; the arrays: do they fit, clear them

			; Main.bas 82: Mode 2
			dw kw_model, 2

			; Main.bas 83: Hyp.Vdu 0                         ' the firmware's text off (TXT VDU DISABLE): AMSDOS says "NAME.CYB not
			dw p_hyp_vdu_c, lit_0

			; Main.bas 87: k = Memory.Banks()
			dw fn_memory_banks, var_k

			; Main.bas 88: If k < 4 Then Hyp.Vdu 1 : Print "CyborgOS needs 320K (a 256K expansion) or more" : End
			dw kw_scpltvl, var_k, 4
			dw kw_goto_iffalse_n, if1_1
			dw p_hyp_vdu_c, lit_1
			dw kw_printstrvar, str0
			dw kw_printnl
			dw kw_printnl0
			dw kw_printstrvar, str1
			dw kw_waitkey
			dw kw_stop
if1_1:

			; Main.bas 89: ns = k \ 2                                      ' half the banks are slots (the first bank never:
			dw kw_divvl, var_k, 2, var_ns

			; Main.bas 90: If ns > MAXS Then ns = MAXS                     ' its pages are the hypervisor's)
			dw kw_scpgtvl, var_ns, 4
			dw kw_goto_iffalse_n, if2_1
			dw kw_ltov, 4, var_ns
if2_1:

			; Main.bas 91: Hot.Slots ns                                    ' (more than 10: Control + a number twice is 11-20)
			dw p_hot_slots_c, var_ns

			; Main.bas 95: i = Memory.AllocPage(Memory.TypeUser)           ' (page 1)
			dw fn_memory_allocpage, lit_85, var_i

			; Main.bas 96: hp = Memory.AllocPage(Memory.TypeUser)          ' bank 1's page 0 (C4): the disc buffers ...
			dw fn_memory_allocpage, lit_85, var_hp

			; Main.bas 97: Memory.SelectPage hp
			dw fn_memory_selectpage, var_hp, var_memory_selectpage_selectpage

			; Main.bas 98: Hyp.UsePage                                     ' (its RAM setting, for Hyp.FileCall)
			dw fn_hyp_usepage

			; Main.bas 99: Hyp.FontInit                                    ' (the font into it, at #5000)
			dw fn_hyp_fontinit

			; Main.bas 107: i = Hyp.FileCall(99, 0, 0, 0, 0, 0, VarPtr(rb))  ' (the bank image and FileCall's page code into it,
			dw p_hyp_filecall_c, lit_99, lit_0, lit_0, lit_0, lit_0, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_i

			; Main.bas 114: For i = 1 To ns
			dw kw_ltov, 1, var_i
			dw kw_vtov, var_ns, for3_l
			dw kw_forupv_n, var_i, for3_l, for3_e
for3_t:

			; Main.bas 115: bk(i) = Memory.AllocBank()
			dw fn_memory_allocbank, var_memory_allocbank_allocbank
			dw kw_aset, arr_bk, var_i, var_memory_allocbank_allocbank

			; Main.bas 116: Memory.SelectPage Memory.BankPage(bk(i), 0)
			dw kw_aget, arr_bk, var_i, tmp0
			dw p_memory_bankpage_c, tmp0, lit_0
			dw fn_memory_selectpage, var_memory_bankpage_bankpage, var_memory_selectpage_selectpage

			; Main.bas 117: sg(i) = Hyp.Setting()
			dw fn_hyp_setting, var_hyp_setting_setting
			dw kw_aset, arr_sg, var_i, var_hyp_setting_setting

			; Main.bas 118: wp(i) = (sg(i) And &HFFF8) Or 7                ' its page 3 (#C000-#FFFF: OBUF, the console) in the window
			dw kw_aget, arr_sg, var_i, tmp1
			dw kw_andvl, tmp1, -8, tmp1
			dw kw_orvl, tmp1, 7, tmp1
			dw kw_aset, arr_wp, var_i, tmp1

			; Main.bas 120: wk(i) = -1
			dw kw_asetl, arr_wk, var_i, -1

			; Main.bas 121: Next
			dw kw_next1v_n, var_i, for3_l, for3_t
for3_e:

			; Main.bas 124: ob = Space$(82)
			dw kw_strspace, stmp0, lit_82
			dw kw_strcpy, var_ob, stmp0

			; Main.bas 125: front = 1
			dw kw_ltov, 1, var_front

			; Main.bas 126: OpenSlot 1
			dw p_openslot_c, lit_1

			; Main.bas 129: a = ""
			dw kw_strcpy, var_a, str2

			; Main.bas 130: If Peek(&HBE80) = 67 And Peek(&HBE81) = 89 And Peek(&HBE82) = 66 And Peek(&HBE83) = 32 Then
			dw kw_lptrtov8, -16768, tmp0
			dw kw_cpeqvl, tmp0, 67
			dw kw_ftov, tmp0
			dw kw_lptrtov8, -16767, tmp1
			dw kw_cpeqvl, tmp1, 89
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_lptrtov8, -16766, tmp1
			dw kw_cpeqvl, tmp1, 66
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_lptrtov8, -16765, tmp1
			dw kw_cpeqvl, tmp1, 32
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if4_1

			; Main.bas 131: i = &HBE84
			dw kw_ltov, -16764, var_i

			; Main.bas 132: Do While Peek(i) <> 0 And i < &HBEC0
do5_t:
			dw kw_vptrtov8, var_i, tmp0
			dw kw_cpnevl, tmp0, 0
			dw kw_ftov, tmp0
			dw kw_scpltvl, var_i, -16704
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, do5_e

			; Main.bas 133: a = a + Chr$(Peek(i))
			dw kw_vptrtov8, var_i, tmp1
			dw kw_strchr, stmp1, tmp1
			dw kw_strcat, var_a, stmp1

			; Main.bas 134: i = i + 1
			dw kw_inc, var_i

			; Main.bas 135: Loop
			dw do5_t_go
do5_e:

			; Main.bas 136: a = UCase$(a)
			dw kw_strucase, stmp0, var_a
			dw kw_strcpy, var_a, stmp0

			; Main.bas 137: End If
if4_1:

			; Main.bas 138: i = InStr(a, " KEYREP ")
			dw kw_strinstr, lit_1, var_a, str3, var_i

			; Main.bas 139: If i > 0 Then
			dw kw_scpgtvl, var_i, 0
			dw kw_goto_iffalse_n, if6_1

			; Main.bas 140: k = Val(Mid$(a, i + 8))
			dw kw_addl, var_i, 8, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strval, stmp0, var_k

			; Main.bas 141: If k > 1 Then Hyp.KeyRep k
			dw kw_scpgtvl, var_k, 1
			dw kw_goto_iffalse_n, if7_1
			dw p_hyp_keyrep_c, var_k
if7_1:

			; Main.bas 142: End If
if6_1:

			; Main.bas 153: Do
do8_t:

			; Main.bas 154: hk = Hot.Take()
			dw p_hot_take_c
			dw kw_vtov, var_hot_take_take, var_hk

			; Main.bas 155: If hk = Hot.TOPKEY Then
			dw kw_cpeqvl, var_hk, 99
			dw kw_goto_iffalse_n, if9_1

			; Main.bas 156: If front = 0 Then ToFront back Else ShowTop      ' Control + ESC: TOP, and again: back
			dw kw_cpeqvl, var_front, 0
			dw kw_goto_iffalse_n, if10_1
			dw p_tofront_c, var_back
			dw if9_e_go
if10_1:
			dw p_showtop_c
if10_e:

			; Main.bas 157: ElseIf hk > 0 And hk <= ns Then
			dw if9_e_go
if9_1:
			dw kw_scpgtvl, var_hk, 0
			dw kw_ftov, tmp0
			dw kw_scplevv, var_hk, var_ns
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if9_2

			; Main.bas 158: ToFront hk
			dw p_tofront_c, var_hk

			; Main.bas 159: End If
if9_2:
if9_e:

			; Main.bas 160: If pk <> 0 And wt = 0 Then                    ' (a key left by a program: after WAIT's prompt)
			dw kw_cpnevl, var_pk, 0
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_wt, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if11_1

			; Main.bas 161: k = pk : pk = 0
			dw kw_vtov, var_pk, var_k
			dw kw_ztov, var_pk

			; Main.bas 162: KeyIn k
			dw p_keyin_c, var_k

			; Main.bas 163: ElseIf wt = 0 Then
			dw if11_e_go
if11_1:
			dw kw_cpeqvl, var_wt, 0
			dw kw_goto_iffalse_n, if11_2

			; Main.bas 165: If front = 0 Or st(front) <> 2 Or kq(front) = 0 Then
			dw kw_cpeqvl, var_front, 0
			dw kw_ftov, tmp0
			dw kw_aget, arr_st, var_front, tmp1
			dw kw_cpnevl, tmp1, 2
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_aget, arr_kq, var_front, tmp1
			dw kw_cpeqvl, tmp1, 0
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if11_e

			; Main.bas 166: k = Inkey
			dw kw_inkey, tmp0
			dw kw_vtov, tmp0, var_k

			; Main.bas 167: If k <> 0 And Hot.Control() = 0 Then KeyIn k
			dw kw_cpnevl, var_k, 0
			dw kw_ftov, tmp0
			dw p_hot_control_c
			dw kw_vtov, var_hot_control_control, tmp1
			dw kw_cpeqvl, tmp1, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if11_e
			dw p_keyin_c, var_k
if13_1:

			; Main.bas 168: End If
if12_1:

			; Main.bas 169: ElseIf Running() = 0 Then
			dw if11_e_go
if11_2:
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if11_3

			; Main.bas 170: Prompt wt : wt = 0          ' WAIT: nothing runs any more
			dw p_prompt_c, var_wt
			dw kw_ztov, var_wt

			; Main.bas 171: End If
if11_3:
if11_e:

			; Main.bas 172: If Ticks - td >= 300 Then Roll
			dw kw_ticks, tmp0
			dw kw_subvv, tmp0, var_td, tmp0
			dw kw_scpgevl, tmp0, 300
			dw kw_goto_iffalse_n, if14_1
			dw p_roll_c
if14_1:

			; Main.bas 173: RunNext
			dw p_runnext_c

			; Main.bas 174: Loop Until quit
			dw kw_goto_ifzero_n, var_quit, do8_t
do8_e:

			; Main.bas 175: i = Hyp.Scr(0, 2)                 ' the CRTC as the firmware has it (80 x 25)
			dw p_hyp_scr_c, lit_0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_i

			; Main.bas 176: Hyp.Vdu 1
			dw p_hyp_vdu_c, lit_1

			; Main.bas 177: Mode 1
			dw kw_model, 1

			; Main.bas 178: Print "CyborgOS ended, "; runs; " programs ran"
			dw kw_printstrvar, str4
			dw kw_printint, var_runs
			dw kw_printstrvar, str5
			dw kw_printnl

			; Main.bas 179: End
			dw kw_printnl0
			dw kw_printstrvar, str1
			dw kw_waitkey
			dw kw_stop

ntc_rg1_e:
			IF ($ < 32768) && (ntc_rg2_e - ntc_rg2 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg2:
; ============================================================
; function running (normal mode)
; ============================================================

p_running:

			; Main.bas 183: Dim j As Integer

			; Main.bas 184: For j = 1 To ns
			dw kw_ltov, 1, var_running_j
			dw kw_vtov, var_ns, for15_l
			dw kw_forupv_n, var_running_j, for15_l, for15_e
for15_t:

			; Main.bas 185: If st(j) = 2 Then Running = Running + 1
			dw kw_aget, arr_st, var_running_j, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if16_1
			dw kw_inc, var_running_running
if16_1:

			; Main.bas 186: Next
			dw kw_next1v_n, var_running_j, for15_l, for15_t
for15_e:
			dw p_running_r

ntc_rg2_e:
			IF ($ < 32768) && (ntc_rg3_e - ntc_rg3 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg3:
; ============================================================
; function ready (normal mode)
; ============================================================

p_ready:

			; Main.bas 192: Ready = 0
			dw kw_ztov, var_ready_ready

			; Main.bas 193: If t < 1 Then Exit Function
			dw kw_scpltvl, var_ready_t, 1
			dw kw_goto_iffalse_n, if17_1
			dw p_ready_r
if17_1:

			; Main.bas 194: If st(t) <> 2 Then Exit Function
			dw kw_aget, arr_st, var_ready_t, tmp0
			dw kw_cpnevl, tmp0, 2
			dw kw_goto_iffalse_n, if18_1
			dw p_ready_r
if18_1:

			; Main.bas 195: If wk(t) = Ticks And kq(t) = 0 Then Exit Function
			dw kw_aget, arr_wk, var_ready_t, tmp0
			dw kw_ticks, tmp1
			dw kw_cpeqvv, tmp0, tmp1
			dw kw_ftov, tmp0
			dw kw_aget, arr_kq, var_ready_t, tmp1
			dw kw_cpeqvl, tmp1, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if19_1
			dw p_ready_r
if19_1:

			; Main.bas 196: Ready = -1
			dw kw_ltov, -1, var_ready_ready
			dw p_ready_r

ntc_rg3_e:
			IF ($ < 32768) && (ntc_rg4_e - ntc_rg4 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg4:
; ============================================================
; sub runnext (normal mode)
; ============================================================

p_runnext:

			; Main.bas 201: Dim n As Integer, t As Integer, r As Integer, c As Integer, q As Integer

			; Main.bas 202: fr = Not fr
			dw kw_notv, var_fr, var_fr

			; Main.bas 203: If fr Then
			dw kw_goto_ifzero_n, var_fr, if20_1

			; Main.bas 204: If Ready(front) Then t = front
			dw p_ready_c, var_front
			dw kw_goto_ifzero_n, var_ready_ready, if21_1
			dw kw_vtov, var_front, var_runnext_t
if21_1:

			; Main.bas 205: End If
if20_1:

			; Main.bas 206: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if22_1

			; Main.bas 207: For n = 1 To ns
			dw kw_ltov, 1, var_runnext_n
			dw kw_vtov, var_ns, for23_l
			dw kw_forupv_n, var_runnext_n, for23_l, for23_e
for23_t:

			; Main.bas 208: cur = cur + 1
			dw kw_inc, var_cur

			; Main.bas 209: If cur > ns Then cur = 1
			dw kw_scpgtvv, var_cur, var_ns
			dw kw_goto_iffalse_n, if24_1
			dw kw_ltov, 1, var_cur
if24_1:

			; Main.bas 210: If cur <> front Then
			dw kw_cpnevv, var_cur, var_front
			dw kw_goto_iffalse_n, if25_1

			; Main.bas 211: If Ready(cur) Then t = cur : Exit For
			dw p_ready_c, var_cur
			dw kw_goto_ifzero_n, var_ready_ready, if26_1
			dw kw_vtov, var_cur, var_runnext_t
			dw for23_e_go
if26_1:

			; Main.bas 212: End If
if25_1:

			; Main.bas 213: Next
			dw kw_next1v_n, var_runnext_n, for23_l, for23_t
for23_e:

			; Main.bas 214: End If
if22_1:

			; Main.bas 215: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if27_1

			; Main.bas 216: If Ready(front) Then t = front
			dw p_ready_c, var_front
			dw kw_goto_ifzero_n, var_ready_ready, if28_1
			dw kw_vtov, var_front, var_runnext_t
if28_1:

			; Main.bas 217: End If
if27_1:

			; Main.bas 218: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if29_1

			; Main.bas 219: If Running() = 0 Then Frame     ' nothing to run: wait a frame (a program waiting for a
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if30_1
			dw kw_frame
if30_1:

			; Main.bas 220: Exit Sub                        ' key looks again when the clock moves on)
			dw p_runnext_r

			; Main.bas 221: End If
if29_1:

			; Main.bas 222: n = 0
			dw kw_ztov, var_runnext_n

			; Main.bas 223: Do
do31_t:

			; Main.bas 224: Hyp.Reply ra(t), ra(t)
			dw kw_aget, arr_ra, var_runnext_t, tmp0
			dw kw_aget, arr_ra, var_runnext_t, tmp1
			dw p_hyp_reply_c, tmp0, tmp1

			; Main.bas 225: r = Hyp.Run(sg(t))
			dw kw_aget, arr_sg, var_runnext_t, tmp0
			dw p_hyp_run_c, tmp0
			dw kw_vtov, var_hyp_run_run, var_runnext_r

			; Main.bas 226: tn(t) = tn(t) + 1
			dw kw_aget, arr_tn, var_runnext_t, tmp1
			dw kw_inc, tmp1
			dw kw_aset, arr_tn, var_runnext_t, tmp1

			; Main.bas 227: If kq(t) <> 0 Then
			dw kw_aget, arr_kq, var_runnext_t, tmp0
			dw kw_cpnevl, tmp0, 0
			dw kw_goto_iffalse_n, if32_1

			; Main.bas 228: If Memory.ReadByte(Far(t, Hyp.KEY)) = 0 Then kq(t) = 0     ' the program took its key
			dw p_far_c, var_runnext_t, lit_m2431
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_memory_readbyte_readbyte
			dw kw_vtov, var_memory_readbyte_readbyte, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if33_1
			dw kw_asetl, arr_kq, var_runnext_t, 0
if33_1:

			; Main.bas 229: End If
if32_1:

			; Main.bas 230: c = Hyp.Count()
			dw p_hyp_count_c
			dw kw_vtov, var_hyp_count_count, var_runnext_c

			; Main.bas 231: If c > 0 Then Collected t, c
			dw kw_scpgtvl, var_runnext_c, 0
			dw kw_goto_iffalse_n, if34_1
			dw p_collected_c, var_runnext_t, var_runnext_c
if34_1:

			; Main.bas 232: If r = 0 Then
			dw kw_cpeqvl, var_runnext_r, 0
			dw kw_goto_iffalse_n, if35_1

			; Main.bas 236: q = q + 1
			dw kw_inc, var_runnext_q

			; Main.bas 237: If q >= TURNS Then Exit Do
			dw kw_scpgevl, var_runnext_q, 3
			dw kw_goto_iffalse_n, do31_t
			dw do31_e_go
if36_1:

			; Main.bas 238: ElseIf r <> 1 Then
			dw do31_t_go
if35_1:
			dw kw_cpnevl, var_runnext_r, 1
			dw kw_goto_iffalse_n, if35_2

			; Main.bas 239: Exit Do
			dw do31_e_go

			; Main.bas 240: Else
if35_2:

			; Main.bas 241: c = Hyp.Fn()
			dw p_hyp_fn_c
			dw kw_vtov, var_hyp_fn_fn, var_runnext_c

			; Main.bas 242: Bdos t
			dw p_bdos_c, var_runnext_t

			; Main.bas 245: n = n + 1
			dw kw_inc, var_runnext_n

			; Main.bas 246: If c < 13 Or c > 36 Or n >= 32 Or st(t) <> 2 Then Exit Do
			dw kw_scpltvl, var_runnext_c, 13
			dw kw_ftov, tmp0
			dw kw_scpgtvl, var_runnext_c, 36
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_scpgevl, var_runnext_n, 32
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_aget, arr_st, var_runnext_t, tmp1
			dw kw_cpnevl, tmp1, 2
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, do31_t
			dw do31_e_go
if37_1:

			; Main.bas 247: End If
if35_e:

			; Main.bas 248: Loop
			dw do31_t_go
do31_e:
			dw p_runnext_r

ntc_rg4_e:
			IF ($ < 32768) && (ntc_rg5_e - ntc_rg5 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg5:
; ============================================================
; sub bdos (normal mode)
; ============================================================

p_bdos:

			; Main.bas 253: Dim f As Integer, e As Integer, a As Integer

			; Main.bas 254: f = Hyp.Fn() : e = Hyp.Arg() And 255 : a = 0
			dw p_hyp_fn_c
			dw kw_vtov, var_hyp_fn_fn, var_bdos_f
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp0
			dw kw_andvl, tmp0, 255, var_bdos_e
			dw kw_ztov, var_bdos_a

			; Main.bas 255: nb(t) = nb(t) + 1
			dw kw_aget, arr_nb, var_bdos_t, tmp1
			dw kw_inc, tmp1
			dw kw_aset, arr_nb, var_bdos_t, tmp1

			; Main.bas 256: wk(t) = -1
			dw kw_asetl, arr_wk, var_bdos_t, -1

			; Main.bas 257: If f = 40 Then f = 34           ' write random with zero fill: as 34
			dw kw_cpeqvl, var_bdos_f, 40
			dw kw_goto_iffalse_n, if38_1
			dw kw_ltov, 34, var_bdos_f
if38_1:

			; Main.bas 258: Select Case f
			dw kw_vtov, var_bdos_f, var_bdos___sel39

			; Main.bas 259: Case 0
			dw kw_cpeqvl, var_bdos___sel39, 0
			dw kw_goto_iffalse_n, sel39_1
sel39_b1:

			; Main.bas 260: EndTask t
			dw p_endtask_c, var_bdos_t

			; Main.bas 261: Exit Sub
			dw p_bdos_r

			; Main.bas 282: Case 12
sel39_1:
			dw kw_cpeqvl, var_bdos___sel39, 12
			dw kw_goto_iffalse_n, sel39_2
sel39_b2:

			; Main.bas 283: a = &H22                    ' CP/M 2.2
			dw kw_ltov, 34, var_bdos_a

			; Main.bas 284: Case 13, 32                   ' reset the discs; user number: nothing to do here
			dw sel39_e_go
sel39_2:
			dw kw_cpeqvl, var_bdos___sel39, 13
			dw kw_goto_iftrue_n, sel39_b3
			dw kw_cpeqvl, var_bdos___sel39, 32
			dw kw_goto_iffalse_n, sel39_3
sel39_b3:

			; Main.bas 285: a = 0
			dw kw_ztov, var_bdos_a

			; Main.bas 286: Case 14                       ' select a disc: the slot's drive (as CD)
			dw sel39_e_go
sel39_3:
			dw kw_cpeqvl, var_bdos___sel39, 14
			dw kw_goto_iffalse_n, sel39_4
sel39_b4:

			; Main.bas 291: Case 25
			dw sel39_e_go
sel39_4:
			dw kw_cpeqvl, var_bdos___sel39, 25
			dw kw_goto_iffalse_n, sel39_5
sel39_b5:

			; Main.bas 293: a = 0
			dw kw_ztov, var_bdos_a

			; Main.bas 297: Case 26                       ' the DMA address (CP/M's record buffer)
			dw sel39_e_go
sel39_5:
			dw kw_cpeqvl, var_bdos___sel39, 26
			dw kw_goto_iffalse_n, sel39_6
sel39_b6:

			; Main.bas 298: dm(t) = Hyp.Arg()
			dw p_hyp_arg_c
			dw kw_aset, arr_dm, var_bdos_t, var_hyp_arg_arg

			; Main.bas 299: Case 24                       ' the login vector: the slot's drive
			dw sel39_e_go
sel39_6:
			dw kw_cpeqvl, var_bdos___sel39, 24
			dw kw_goto_iffalse_n, sel39_7
sel39_b7:

			; Main.bas 301: a = 1
			dw kw_ltov, 1, var_bdos_a

			; Main.bas 305: Case 15 To 36                 ' files: Hyp.FileCall
			dw sel39_e_go
sel39_7:
			dw kw_scpltvl, var_bdos___sel39, 15
			dw kw_goto_iftrue_n, sel39_8
			dw kw_scplevl, var_bdos___sel39, 36
			dw kw_goto_iffalse_n, sel39_8
sel39_b8:

			; Main.bas 307: a = Hyp.FileCall(f, Hyp.Arg(), t, sg(t), dm(t), 0, VarPtr(rb))
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp1
			dw kw_aget, arr_sg, var_bdos_t, tmp3
			dw kw_aget, arr_dm, var_bdos_t, tmp4
			dw p_hyp_filecall_c, var_bdos_f, tmp1, var_bdos_t, tmp3, tmp4, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_bdos_a

			; Main.bas 316: Case 131                      ' CyborgOS's own commands (PS, KILL, MEM ...)
			dw sel39_e_go
sel39_8:
			dw kw_cpeqvl, var_bdos___sel39, 131
			dw kw_goto_iffalse_n, sel39_9
sel39_b9:

			; Main.bas 317: a = Sys(t, Hyp.Arg())
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp1
			dw p_sys_c, var_bdos_t, tmp1
			dw kw_vtov, var_sys_sys, var_bdos_a

			; Main.bas 318: Case 128
			dw sel39_e_go
sel39_9:
			dw kw_cpeqvl, var_bdos___sel39, 128
			dw kw_goto_iffalse_n, sel39_10
sel39_b10:

			; Main.bas 320: Case 129                      ' the stub's key wait (BDOS 1, 10, BIOS CONIN): sleep till a key
			dw sel39_e_go
sel39_10:
			dw kw_cpeqvl, var_bdos___sel39, 129
			dw kw_goto_iffalse_n, sel39_11
sel39_b11:

			; Main.bas 321: If kq(t) = 0 Then wk(t) = Ticks
			dw kw_aget, arr_kq, var_bdos_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, sel39_e
			dw kw_ticks, tmp1
			dw kw_aset, arr_wk, var_bdos_t, tmp1
if40_1:

			; Main.bas 322: Case Else
			dw sel39_e_go
sel39_11:

			; Main.bas 323: a = 255
			dw kw_ltov, 255, var_bdos_a

			; Main.bas 324: End Select
sel39_e:

			; Main.bas 325: ra(t) = a
			dw kw_aset, arr_ra, var_bdos_t, var_bdos_a
			dw p_bdos_r

ntc_rg5_e:
			IF ($ < 32768) && (ntc_rg6_e - ntc_rg6 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg6:
; ============================================================
; function sys (normal mode)
; ============================================================

p_sys:

			; Main.bas 436: Dim o As Integer, s As Integer, d As Integer

			; Main.bas 437: o = Memory.ReadByte(Far(t, p)) : s = Memory.ReadByte(Far(t, p + 1))
			dw p_far_c, var_sys_t, var_sys_p
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_o
			dw kw_addl, var_sys_p, 1, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_s

			; Main.bas 438: If o = 4 Then
			dw kw_cpeqvl, var_sys_o, 4
			dw kw_goto_iffalse_n, if41_1

			; Main.bas 439: If Running() > 1 Then wt = t
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_scpgtvl, tmp0, 1
			dw kw_goto_iffalse_n, if42_1
			dw kw_vtov, var_sys_t, var_wt
if42_1:

			; Main.bas 440: Exit Function
			dw p_sys_r

			; Main.bas 441: ElseIf o = 6 Then
if41_1:
			dw kw_cpeqvl, var_sys_o, 6
			dw kw_goto_iffalse_n, if41_2

			; Main.bas 442: txs = t
			dw kw_vtov, var_sys_t, var_txs

			; Main.bas 443: TopLines front, 0
			dw p_toplines_c, var_front, lit_0

			; Main.bas 444: Exit Function
			dw p_sys_r

			; Main.bas 445: ElseIf o = 9 Then                               ' MODE: s 0-4 this slot's mode (its console
if41_2:
			dw kw_cpeqvl, var_sys_o, 9
			dw kw_goto_iffalse_n, if41_3

			; Main.bas 446: If s = 255 Then Sys = Memory.ReadByte(Far(t, Hyp.CMODE)) : Exit Function   ' cleared), 255: which
			dw kw_cpeqvl, var_sys_s, 255
			dw kw_goto_iffalse_n, if43_1
			dw p_far_c, var_sys_t, lit_m2423
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_sys
			dw p_sys_r
if43_1:

			; Main.bas 447: If s > 5 Then Sys = 255 : Exit Function                                     ' it is
			dw kw_scpgtvl, var_sys_s, 5
			dw kw_goto_iffalse_n, if44_1
			dw kw_ltov, 255, var_sys_sys
			dw p_sys_r
if44_1:

			; Main.bas 448: SetMode t, s
			dw p_setmode_c, var_sys_t, var_sys_s

			; Main.bas 449: Exit Function
			dw p_sys_r

			; Main.bas 473: End If
if41_3:
if41_e:

			; Main.bas 474: If o = 2 And s = 0 Then s = t
			dw kw_cpeqvl, var_sys_o, 2
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_sys_s, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if45_1
			dw kw_vtov, var_sys_t, var_sys_s
if45_1:

			; Main.bas 475: Sys = 255
			dw kw_ltov, 255, var_sys_sys

			; Main.bas 476: If s < 1 Or s > ns Then Exit Function
			dw kw_scpltvl, var_sys_s, 1
			dw kw_ftov, tmp0
			dw kw_scpgtvv, var_sys_s, var_ns
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if46_1
			dw p_sys_r
if46_1:

			; Main.bas 477: Sys = 0
			dw kw_ztov, var_sys_sys

			; Main.bas 478: If o = 0 Then
			dw kw_cpeqvl, var_sys_o, 0
			dw kw_goto_iffalse_n, if47_1

			; Main.bas 479: Memory.WriteByte Far(t, p + 2), st(s)
			dw kw_addl, var_sys_p, 2, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_aget, arr_st, var_sys_s, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 480: Memory.WriteByte Far(t, p + 3), IIf(s = front, 1, 0)
			dw kw_addl, var_sys_p, 3, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_cpeqvv, var_sys_s, var_front
			dw kw_ftov, tmp1
			dw kw_goto_ifzero_n, tmp1, ch48_0
			dw kw_ltov, 1, tmp1
			dw ch48_e_go
ch48_0:
			dw kw_ztov, tmp1
			dw ch48_e_go
ch48_1:
			dw kw_ztov, tmp1
ch48_e:
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 481: en = ""
			dw kw_strcpy, var_en, str2

			; Main.bas 482: If st(s) = 2 Then GetNm s
			dw kw_aget, arr_st, var_sys_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if49_1
			dw p_getnm_c, var_sys_s
if49_1:

			; Main.bas 483: PutEn t, p + 4
			dw kw_addl, var_sys_p, 4, tmp1
			dw p_puten_c, var_sys_t, tmp1

			; Main.bas 484: ElseIf o = 1 Then
			dw if47_e_go
if47_1:
			dw kw_cpeqvl, var_sys_o, 1
			dw kw_goto_iffalse_n, if47_2

			; Main.bas 485: If st(s) = 2 Then EndTask s Else Sys = 1
			dw kw_aget, arr_st, var_sys_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if50_1
			dw p_endtask_c, var_sys_s
			dw if47_e_go
if50_1:
			dw kw_ltov, 1, var_sys_sys
if50_e:

			; Main.bas 486: ElseIf o = 2 Then
			dw if47_e_go
if47_2:
			dw kw_cpeqvl, var_sys_o, 2
			dw kw_goto_iffalse_n, if47_3

			; Main.bas 487: ResetSlot s
			dw p_resetslot_c, var_sys_s

			; Main.bas 488: If s = t Then Prompt t                       ' (RESET of its own slot: the program gone)
			dw kw_cpeqvv, var_sys_s, var_sys_t
			dw kw_goto_iffalse_n, if47_e
			dw p_prompt_c, var_sys_t
if51_1:

			; Main.bas 489: ElseIf o = 3 Then
			dw if47_e_go
if47_3:
			dw kw_cpeqvl, var_sys_o, 3
			dw kw_goto_iffalse_n, if47_4

			; Main.bas 490: ToFront s
			dw p_tofront_c, var_sys_s

			; Main.bas 491: End If
if47_4:
if47_e:
			dw p_sys_r

ntc_rg6_e:
			IF ($ < 32768) && (ntc_rg7_e - ntc_rg7 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg7:
; ============================================================
; sub puten (normal mode)
; ============================================================

p_puten:

			; Main.bas 496: Memory.WriteByte Far(t, a), Len(en)
			dw p_far_c, var_puten_t, var_puten_a
			dw kw_strlen, var_en, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 497: Memory.Copy NearP(VarPtr(en)), Far(t, a + 1), Len(en)
			dw p_nearp_c, vp_var_en
			dw kw_addl, var_puten_a, 1, tmp2
			dw p_far_c, var_puten_t, tmp2
			dw kw_strlen, var_en, tmp2
			dw fn_memory_copy, var_nearp_nearp, var_far_far, tmp2, var_memory_copy_copy
			dw p_puten_r

ntc_rg7_e:
			IF ($ < 32768) && (ntc_rg8_e - ntc_rg8 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg8:
; ============================================================
; function hopen (normal mode)
; ============================================================

p_hopen:

			; Main.bas 503: HOpen = (Hyp.FileCall(100, VarPtr(dn), 0, 0, Len(dn), 0, 0) = 0)
			dw kw_strlen, var_dn, tmp4
			dw p_hyp_filecall_c, lit_100, vp_var_dn, lit_0, lit_0, tmp4, lit_0, lit_0
			dw kw_vtov, var_hyp_filecall_filecall, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_ftov, var_hopen_hopen
			dw p_hopen_r

ntc_rg8_e:
			IF ($ < 32768) && (ntc_rg9_e - ntc_rg9 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg9:
; ============================================================
; function hread (normal mode)
; ============================================================

p_hread:

			; Main.bas 506: HRead = Hyp.FileCall(101, 0, 0, 0, n, 0, VarPtr(rb))
			dw p_hyp_filecall_c, lit_101, lit_0, lit_0, lit_0, var_hread_n, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_hread_hread
			dw p_hread_r

ntc_rg9_e:
			IF ($ < 32768) && (ntc_rg10_e - ntc_rg10 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg10:
; ============================================================
; sub hclose (normal mode)
; ============================================================

p_hclose:

			; Main.bas 509: Dim r As Integer

			; Main.bas 510: r = Hyp.FileCall(102, 0, 0, 0, 0, 0, 0)
			dw p_hyp_filecall_c, lit_102, lit_0, lit_0, lit_0, lit_0, lit_0, lit_0
			dw kw_vtov, var_hyp_filecall_filecall, var_hclose_r
			dw p_hclose_r

ntc_rg10_e:
			IF ($ < 32768) && (ntc_rg11_e - ntc_rg11 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg11:
; ============================================================
; sub filesshut (normal mode)
; ============================================================

p_filesshut:

			; Main.bas 515: Hyp.FileShut t
			dw p_hyp_fileshut_c, var_filesshut_t
			dw p_filesshut_r

ntc_rg11_e:
			IF ($ < 32768) && (ntc_rg12_e - ntc_rg12 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg12:
; ============================================================
; sub collected (normal mode)
; ============================================================

p_collected:

			; Main.bas 524: nc(t) = nc(t) + n
			dw kw_aget, arr_nc, var_collected_t, tmp1
			dw kw_add, tmp1, var_collected_n, tmp1
			dw kw_aset, arr_nc, var_collected_t, tmp1

			; Main.bas 525: Hyp.Con wp(t), 0, n, IIf(t = front, 1, 0)       ' straight from the bank: no copy to main RAM
			dw kw_aget, arr_wp, var_collected_t, tmp0
			dw kw_cpeqvv, var_collected_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch52_0
			dw kw_ltov, 1, tmp3
			dw ch52_e_go
ch52_0:
			dw kw_ztov, tmp3
			dw ch52_e_go
ch52_1:
			dw kw_ztov, tmp3
ch52_e:
			dw p_hyp_con_c, tmp0, lit_0, var_collected_n, tmp3
			dw p_collected_r

ntc_rg12_e:
			IF ($ < 32768) && (ntc_rg13_e - ntc_rg13 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg13:
; ============================================================
; sub puts (normal mode)
; ============================================================

p_puts:

			; Main.bas 530: Hyp.Con wp(t), VarPtr(s), Len(s), IIf(t = front, 1, 0)
			dw kw_aget, arr_wp, var_puts_t, tmp0
			dw kw_strlen, var_puts_s, tmp2
			dw kw_cpeqvv, var_puts_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch53_0
			dw kw_ltov, 1, tmp3
			dw ch53_e_go
ch53_0:
			dw kw_ztov, tmp3
			dw ch53_e_go
ch53_1:
			dw kw_ztov, tmp3
ch53_e:
			dw p_hyp_con_c, tmp0, vp_var_puts_s, tmp2, tmp3
			dw p_puts_r

ntc_rg13_e:
			IF ($ < 32768) && (ntc_rg14_e - ntc_rg14 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg14:
; ============================================================
; sub putln (normal mode)
; ============================================================

p_putln:

			; Main.bas 534: PutS t, s + Chr$(13) + Chr$(10)
			dw kw_strcpy, stmp1, var_putln_s
			dw kw_strcat, stmp1, str6
			dw kw_strcat, stmp1, str7
			dw p_puts_c, var_putln_t, stmp1
			dw p_putln_r

ntc_rg14_e:
			IF ($ < 32768) && (ntc_rg15_e - ntc_rg15 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg15:
; ============================================================
; sub putc (normal mode)
; ============================================================

p_putc:

			; Main.bas 539: Hyp.Con wp(t), VarPtr(c), 1, IIf(t = front, 1, 0)   ' (the Integer's low byte is the character)
			dw kw_aget, arr_wp, var_putc_t, tmp0
			dw kw_cpeqvv, var_putc_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch54_0
			dw kw_ltov, 1, tmp3
			dw ch54_e_go
ch54_0:
			dw kw_ztov, tmp3
			dw ch54_e_go
ch54_1:
			dw kw_ztov, tmp3
ch54_e:
			dw p_hyp_con_c, tmp0, vp_var_putc_c, lit_1, tmp3
			dw p_putc_r

ntc_rg15_e:
			IF ($ < 32768) && (ntc_rg16_e - ntc_rg16 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg16:
; ============================================================
; function nearp (normal mode)
; ============================================================

p_nearp:

			; Main.bas 562: NearP = CLng(p)
			dw kw_l_itol, var_nearp_p, var_nearp_nearp

			; Main.bas 563: If p < 0 Then NearP = NearP + 65536
			dw kw_scpltvl, var_nearp_p, 0
			dw kw_goto_iffalse_n, if55_1
			dw kw_l_add, var_nearp_nearp, llit_65536, var_nearp_nearp
if55_1:
			dw p_nearp_r

ntc_rg16_e:
			IF ($ < 32768) && (ntc_rg17_e - ntc_rg17 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg17:
; ============================================================
; function far (normal mode)
; ============================================================

p_far:

			; Main.bas 568: Far = Hyp.FarPtr(Memory.BankPage(bk(t), ((a And &HC000) \ 16384) And 3), a)
			dw kw_aget, arr_bk, var_far_t, tmp1
			dw kw_andvl, var_far_a, -16384, tmp2
			dw kw_divvl, tmp2, 16384, tmp2
			dw kw_andvl, tmp2, 3, tmp2
			dw p_memory_bankpage_c, tmp1, tmp2
			dw kw_vtov, var_memory_bankpage_bankpage, tmp1
			dw fn_hyp_farptr, tmp1, var_far_a, var_far_far
			dw p_far_r

ntc_rg17_e:
			IF ($ < 32768) && (ntc_rg18_e - ntc_rg18 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg18:
; ============================================================
; sub clst (normal mode)
; ============================================================

p_clst:

			; Main.bas 573: PutS t, Chr$(27) + "E"
			dw kw_strcpy, stmp1, str8
			dw kw_strcat, stmp1, str9
			dw p_puts_c, var_clst_t, stmp1
			dw p_clst_r

ntc_rg18_e:
			IF ($ < 32768) && (ntc_rg19_e - ntc_rg19 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg19:
; ============================================================
; sub tofront (normal mode)
; ============================================================

p_tofront:

			; Main.bas 578: Dim r As Integer

			; Main.bas 579: front = t
			dw kw_vtov, var_tofront_t, var_front

			; Main.bas 580: If st(t) = 0 Then OpenSlot t : Exit Sub
			dw kw_aget, arr_st, var_tofront_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if56_1
			dw p_openslot_c, var_tofront_t
			dw p_tofront_r
if56_1:

			; Main.bas 581: r = Hyp.Scr(Memory.ReadByte(Far(t, Hyp.CMODE)), 2)   ' the screen in its mode (cleared)
			dw p_far_c, var_tofront_t, lit_m2423
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_memory_readbyte_readbyte
			dw kw_vtov, var_memory_readbyte_readbyte, tmp0
			dw p_hyp_scr_c, tmp0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_tofront_r

			; Main.bas 582: Hyp.Show wp(t)
			dw kw_aget, arr_wp, var_tofront_t, tmp0
			dw p_hyp_show_c, tmp0
			dw p_tofront_r

ntc_rg19_e:
			IF ($ < 32768) && (ntc_rg20_e - ntc_rg20 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg20:
; ============================================================
; sub setmode (normal mode)
; ============================================================

p_setmode:

			; Main.bas 589: Dim r As Integer

			; Main.bas 590: Memory.WriteByte Far(t, Hyp.CCOLS), Hyp.Scr(m, 0)
			dw p_far_c, var_setmode_t, lit_m2425
			dw p_hyp_scr_c, var_setmode_m, lit_0
			dw fn_memory_writebyte, var_far_far, var_hyp_scr_scr

			; Main.bas 591: Memory.WriteByte Far(t, Hyp.CROWS), Hyp.Scr(m, 1)
			dw p_far_c, var_setmode_t, lit_m2424
			dw p_hyp_scr_c, var_setmode_m, lit_1
			dw fn_memory_writebyte, var_far_far, var_hyp_scr_scr

			; Main.bas 592: Memory.WriteByte Far(t, Hyp.CMODE), m
			dw p_far_c, var_setmode_t, lit_m2423
			dw fn_memory_writebyte, var_far_far, var_setmode_m

			; Main.bas 593: en = Left$("[" + N(t) + "]   ", 4)
			dw p_n_c, var_setmode_t
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcpy, stmp0, str10
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str11
			dw kw_strleft, stmp0, stmp0, lit_4
			dw kw_strcpy, var_en, stmp0

			; Main.bas 594: Memory.Copy NearP(VarPtr(en)), Far(t, Hyp.CSTRIP), 4
			dw p_nearp_c, vp_var_en
			dw p_far_c, var_setmode_t, lit_m2422
			dw fn_memory_copy, var_nearp_nearp, var_far_far, lit_4, var_memory_copy_copy

			; Main.bas 595: If t = front Then r = Hyp.Scr(m, 2)
			dw kw_cpeqvv, var_setmode_t, var_front
			dw kw_goto_iffalse_n, if57_1
			dw p_hyp_scr_c, var_setmode_m, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_setmode_r
if57_1:

			; Main.bas 596: ClsT t
			dw p_clst_c, var_setmode_t
			dw p_setmode_r

ntc_rg20_e:
			IF ($ < 32768) && (ntc_rg21_e - ntc_rg21 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg21:
; ============================================================
; sub showtop (normal mode)
; ============================================================

p_showtop:

			; Main.bas 759: Dim j As Integer

			; Main.bas 760: If front <> 0 Then back = front
			dw kw_cpnevl, var_front, 0
			dw kw_goto_iffalse_n, if58_1
			dw kw_vtov, var_front, var_back
if58_1:

			; Main.bas 761: front = 0
			dw kw_ztov, var_front

			; Main.bas 762: j = Hyp.Scr(0, 2)               ' TOP in MODE 2 (80 x 25), the screen cleared
			dw p_hyp_scr_c, lit_0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_showtop_j

			; Main.bas 763: txs = 0
			dw kw_ztov, var_txs

			; Main.bas 764: TopLines back, 1
			dw p_toplines_c, var_back, lit_1
			dw p_showtop_r

ntc_rg21_e:
			IF ($ < 32768) && (ntc_rg22_e - ntc_rg22 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg22:
; ============================================================
; sub toplines (normal mode)
; ============================================================

p_toplines:

			; Main.bas 770: Dim j As Integer, s As String Max 14

			; Main.bas 771: txn = 0
			dw kw_ztov, var_txn

			; Main.bas 772: TopAdd "CyborgOS TOP"
			dw p_topadd_c, str12

			; Main.bas 773: If keys Then TopAdd "Control + ESC: back, " + SK() + ": that slot" Else TopAdd ""   ' (25 rows: 20 slots)
			dw kw_goto_ifzero_n, var_toplines_keys, if59_1
			dw p_sk_c
			dw kw_strcpy, stmp1, var_sk_sk
			dw kw_strcpy, stmp0, str13
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str14
			dw p_topadd_c, stmp0
			dw if59_e_go
if59_1:
			dw p_topadd_c, str2
if59_e:

			; Main.bas 774: TopAdd "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (last second)"
			dw p_topadd_c, str15

			; Main.bas 775: For j = 1 To ns
			dw kw_ltov, 1, var_toplines_j
			dw kw_vtov, var_ns, for60_l
			dw kw_forupv_n, var_toplines_j, for60_l, for60_e
for60_t:

			; Main.bas 776: If st(j) = 0 Then
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if61_1

			; Main.bas 777: s = "-"
			dw kw_strcpy, var_toplines_s, str16

			; Main.bas 778: ElseIf st(j) = 1 Then
			dw if61_e_go
if61_1:
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 1
			dw kw_goto_iffalse_n, if61_2

			; Main.bas 779: s = "command line"
			dw kw_strcpy, var_toplines_s, str17

			; Main.bas 780: ElseIf wk(j) >= 0 Then
			dw if61_e_go
if61_2:
			dw kw_aget, arr_wk, var_toplines_j, tmp0
			dw kw_scpgevl, tmp0, 0
			dw kw_goto_iffalse_n, if61_3

			; Main.bas 781: s = "waiting (key)"
			dw kw_strcpy, var_toplines_s, str18

			; Main.bas 782: Else
			dw if61_e_go
if61_3:

			; Main.bas 783: s = "running"
			dw kw_strcpy, var_toplines_s, str19

			; Main.bas 784: End If
if61_e:

			; Main.bas 785: en = ""
			dw kw_strcpy, var_en, str2

			; Main.bas 786: If st(j) = 2 Then GetNm j
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if62_1
			dw p_getnm_c, var_toplines_j
if62_1:

			; Main.bas 787: TopAdd " " + Right$(" " + N(j), 2) + IIf(j = mark, "*", " ") + "  " + Left$(s + Space$(15), 15) + Left$(en + Space$(13), 13) + Pad(Rate(lt(j), ld)) + Pad(Rate(lb(j), ld)) + Pad(Rate(lc(j), ld))
			dw p_n_c, var_toplines_j
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcpy, stmp1, str20
			dw kw_strcat, stmp1, stmp2
			dw kw_strright, stmp1, stmp1, lit_2
			dw kw_strcpy, stmp0, str20
			dw kw_strcat, stmp0, stmp1
			dw kw_cpeqvv, var_toplines_j, var_toplines_mark
			dw kw_ftov, tmp1
			dw kw_goto_ifzero_n, tmp1, ch63_0
			dw kw_strcpy, stmp1, str21
			dw ch63_e_go
ch63_0:
			dw kw_strcpy, stmp1, str20
			dw ch63_e_go
ch63_1:
			dw kw_strcpy, stmp1, str2
ch63_e:
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str22
			dw kw_strspace, stmp2, lit_15
			dw kw_strcpy, stmp1, var_toplines_s
			dw kw_strcat, stmp1, stmp2
			dw kw_strleft, stmp1, stmp1, lit_15
			dw kw_strcat, stmp0, stmp1
			dw kw_strspace, stmp2, lit_13
			dw kw_strcpy, stmp1, var_en
			dw kw_strcat, stmp1, stmp2
			dw kw_strleft, stmp1, stmp1, lit_13
			dw kw_strcat, stmp0, stmp1
			dw kw_aget, arr_lt, var_toplines_j, tmp1
			dw p_rate_c, tmp1, var_ld
			dw kw_vtov, var_rate_rate, tmp1
			dw p_pad_c, tmp1
			dw kw_strcpy, stmp1, var_pad_pad
			dw kw_strcat, stmp0, stmp1
			dw kw_aget, arr_lb, var_toplines_j, tmp1
			dw p_rate_c, tmp1, var_ld
			dw kw_vtov, var_rate_rate, tmp1
			dw p_pad_c, tmp1
			dw kw_strcpy, stmp1, var_pad_pad
			dw kw_strcat, stmp0, stmp1
			dw kw_aget, arr_lc, var_toplines_j, tmp1
			dw p_rate_c, tmp1, var_ld
			dw kw_vtov, var_rate_rate, tmp1
			dw p_pad_c, tmp1
			dw kw_strcpy, stmp1, var_pad_pad
			dw kw_strcat, stmp0, stmp1
			dw p_topadd_c, stmp0

			; Main.bas 788: Next
			dw kw_next1v_n, var_toplines_j, for60_l, for60_t
for60_e:

			; Main.bas 789: TopAdd ""
			dw p_topadd_c, str2

			; Main.bas 790: Totals
			dw p_totals_c

			; Main.bas 791: TopAdd en
			dw p_topadd_c, var_en
			dw p_toplines_r

ntc_rg22_e:
			IF ($ < 32768) && (ntc_rg23_e - ntc_rg23 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg23:
; ============================================================
; sub totals (normal mode)
; ============================================================

p_totals:

			; Main.bas 796: en = "Total memory: " + N(Memory.RamSize()) + " KB   Free memory: " + N(Memory.FreePages() * 16) + " KB"
			dw fn_memory_ramsize, var_memory_ramsize_ramsize
			dw kw_vtov, var_memory_ramsize_ramsize, tmp1
			dw p_n_c, tmp1
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcpy, stmp0, str23
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str24
			dw fn_memory_freepages, var_memory_freepages_freepages
			dw kw_vtov, var_memory_freepages_freepages, tmp1
			dw kw_mulvl, tmp1, 16, tmp1
			dw p_n_c, tmp1
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcat, stmp0, stmp1
			dw kw_strcpy, var_en, stmp0
			dw kw_strcat, var_en, str25
			dw p_totals_r

ntc_rg23_e:
			IF ($ < 32768) && (ntc_rg24_e - ntc_rg24 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg24:
; ============================================================
; sub topadd (normal mode)
; ============================================================

p_topadd:

			; Main.bas 804: If txs = 0 Then
			dw kw_cpeqvl, var_txs, 0
			dw kw_goto_iffalse_n, if64_1

			; Main.bas 805: Hyp.Say VarPtr(s), Len(s), 0, txn          ' straight into screen memory (Print took ~0.7 s)
			dw kw_strlen, var_topadd_s, tmp1
			dw p_hyp_say_c, vp_var_topadd_s, tmp1, lit_0, var_txn

			; Main.bas 806: Else
			dw if64_e_go
if64_1:

			; Main.bas 807: PutLn txs, s
			dw p_putln_c, var_txs, var_topadd_s

			; Main.bas 808: End If
if64_e:

			; Main.bas 809: txn = txn + 1
			dw kw_inc, var_txn
			dw p_topadd_r

ntc_rg24_e:
			IF ($ < 32768) && (ntc_rg25_e - ntc_rg25 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg25:
; ============================================================
; sub roll (normal mode)
; ============================================================

p_roll:

			; Main.bas 814: Dim j As Integer

			; Main.bas 815: ld = Ticks - td
			dw kw_ticks, tmp0
			dw kw_subvv, tmp0, var_td, var_ld

			; Main.bas 816: td = Ticks
			dw kw_ticks, tmp0
			dw kw_vtov, tmp0, var_td

			; Main.bas 817: For j = 1 To ns
			dw kw_ltov, 1, var_roll_j
			dw kw_vtov, var_ns, for65_l
			dw kw_forupv_n, var_roll_j, for65_l, for65_e
for65_t:

			; Main.bas 818: lt(j) = tn(j) : lb(j) = nb(j) : lc(j) = nc(j)
			dw kw_aget, arr_tn, var_roll_j, tmp1
			dw kw_aset, arr_lt, var_roll_j, tmp1
			dw kw_aget, arr_nb, var_roll_j, tmp1
			dw kw_aset, arr_lb, var_roll_j, tmp1
			dw kw_aget, arr_nc, var_roll_j, tmp1
			dw kw_aset, arr_lc, var_roll_j, tmp1

			; Main.bas 819: tn(j) = 0 : nb(j) = 0 : nc(j) = 0
			dw kw_asetl, arr_tn, var_roll_j, 0
			dw kw_asetl, arr_nb, var_roll_j, 0
			dw kw_asetl, arr_nc, var_roll_j, 0

			; Main.bas 820: Next
			dw kw_next1v_n, var_roll_j, for65_l, for65_t
for65_e:
			dw p_roll_r

ntc_rg25_e:
			IF ($ < 32768) && (ntc_rg26_e - ntc_rg26 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg26:
; ============================================================
; function pad (normal mode)
; ============================================================

p_pad:

			; Main.bas 825: Pad = Right$(Space$(9) + N(v), 9)
			dw kw_strspace, stmp1, lit_9
			dw p_n_c, var_pad_v
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcat, stmp1, stmp2
			dw kw_strright, var_pad_pad, stmp1, lit_9
			dw p_pad_r

ntc_rg26_e:
			IF ($ < 32768) && (ntc_rg27_e - ntc_rg27 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg27:
; ============================================================
; function rate (normal mode)
; ============================================================

p_rate:

			; Main.bas 830: If n > 1000 Then Rate = n \ (d \ 300 + 1) Else Rate = n * 30 \ (d \ 10 + 1)
			dw kw_scpgtvl, var_rate_n, 1000
			dw kw_goto_iffalse_n, if66_1
			dw kw_divvl, var_rate_d, 300, tmp2
			dw kw_inc, tmp2
			dw kw_divvv, var_rate_n, tmp2, var_rate_rate
			dw if66_e_go
if66_1:
			dw kw_mulvl, var_rate_n, 30, tmp1
			dw kw_divvl, var_rate_d, 10, tmp2
			dw kw_inc, tmp2
			dw kw_divvv, tmp1, tmp2, var_rate_rate
if66_e:
			dw p_rate_r

ntc_rg27_e:
			IF ($ < 32768) && (ntc_rg28_e - ntc_rg28 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg28:
; ============================================================
; sub install (normal mode)
; ============================================================

p_install:

			; Main.bas 837: Dim p As Integer, n As Integer

			; Main.bas 838: p = Hyp.Info(0) : n = Hyp.Info(1)             ' (one Info result each: it is one variable)
			dw fn_hyp_info, lit_0, var_install_p
			dw fn_hyp_info, lit_1, var_install_n

			; Main.bas 839: Memory.Copy Hyp.FarPtr(hp, p), Far(t, 0), n   ' (from the hypervisor's page)
			dw fn_hyp_farptr, var_hp, var_install_p, var_hyp_farptr_farptr
			dw p_far_c, var_install_t, lit_0
			dw fn_memory_copy, var_hyp_farptr_farptr, var_far_far, var_install_n, var_memory_copy_copy

			; Main.bas 840: p = Hyp.Info(2) : n = Hyp.Info(3)
			dw fn_hyp_info, lit_2, var_install_p
			dw fn_hyp_info, lit_3, var_install_n

			; Main.bas 841: Memory.Copy Hyp.FarPtr(hp, p), Far(t, Hyp.STUB), n
			dw fn_hyp_farptr, var_hp, var_install_p, var_hyp_farptr_farptr
			dw p_far_c, var_install_t, lit_m4352
			dw fn_memory_copy, var_hyp_farptr_farptr, var_far_far, var_install_n, var_memory_copy_copy

			; Main.bas 842: Memory.Copy Hyp.FarPtr(hp, Hyp.HFONT), Far(t, Hyp.FONT), 768   ' the font (Con draws from it)
			dw fn_hyp_farptr, var_hp, lit_4096, var_hyp_farptr_farptr
			dw p_far_c, var_install_t, lit_m3328
			dw fn_memory_copy, var_hyp_farptr_farptr, var_far_far, lit_768, var_memory_copy_copy

			; Main.bas 843: Memory.WriteByte Far(t, Hyp.OBUF + 128), 0      ' no characters collected
			dw p_far_c, var_install_t, lit_m2432
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 844: Memory.WriteByte Far(t, Hyp.KEY), 0             ' no key waiting
			dw p_far_c, var_install_t, lit_m2431
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 845: kq(t) = 0
			dw kw_asetl, arr_kq, var_install_t, 0
			dw p_install_r

ntc_rg28_e:
			IF ($ < 32768) && (ntc_rg29_e - ntc_rg29 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg29:
; ============================================================
; sub resetslot (normal mode)
; ============================================================

p_resetslot:

			; Main.bas 857: FilesShut s
			dw p_filesshut_c, var_resetslot_s

			; Main.bas 862: st(s) = 0
			dw kw_asetl, arr_st, var_resetslot_s, 0

			; Main.bas 867: kq(s) = 0
			dw kw_asetl, arr_kq, var_resetslot_s, 0

			; Main.bas 868: wk(s) = -1
			dw kw_asetl, arr_wk, var_resetslot_s, -1

			; Main.bas 869: tn(s) = 0 : nb(s) = 0 : nc(s) = 0
			dw kw_asetl, arr_tn, var_resetslot_s, 0
			dw kw_asetl, arr_nb, var_resetslot_s, 0
			dw kw_asetl, arr_nc, var_resetslot_s, 0

			; Main.bas 870: lt(s) = 0 : lb(s) = 0 : lc(s) = 0
			dw kw_asetl, arr_lt, var_resetslot_s, 0
			dw kw_asetl, arr_lb, var_resetslot_s, 0
			dw kw_asetl, arr_lc, var_resetslot_s, 0

			; Main.bas 871: If s = front Then
			dw kw_cpeqvv, var_resetslot_s, var_front
			dw kw_goto_iffalse_n, if67_1

			; Main.bas 872: Install s
			dw p_install_c, var_resetslot_s

			; Main.bas 873: st(s) = 1
			dw kw_asetl, arr_st, var_resetslot_s, 1

			; Main.bas 874: SetMode s, 1
			dw p_setmode_c, var_resetslot_s, lit_1

			; Main.bas 875: PutLn s, "CyborgOS slot " + N(s) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
			dw p_n_c, var_resetslot_s
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcpy, stmp1, str26
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str27
			dw p_n_c, var_ns
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str28
			dw p_sk_c
			dw kw_strcpy, stmp2, var_sk_sk
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str29
			dw p_putln_c, var_resetslot_s, stmp1

			; Main.bas 876: PutLn s, ""                   ' a blank line under the title
			dw p_putln_c, var_resetslot_s, str2

			; Main.bas 877: End If                          ' (the prompt: the command line puts it after the command)
if67_1:
			dw p_resetslot_r

ntc_rg29_e:
			IF ($ < 32768) && (ntc_rg30_e - ntc_rg30 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg30:
; ============================================================
; sub openslot (normal mode)
; ============================================================

p_openslot:

			; Main.bas 881: Install t
			dw p_install_c, var_openslot_t

			; Main.bas 882: st(t) = 1
			dw kw_asetl, arr_st, var_openslot_t, 1

			; Main.bas 883: SetMode t, 1                    ' MODE S: 80 x 24 and the status strip
			dw p_setmode_c, var_openslot_t, lit_1

			; Main.bas 884: PutLn t, "CyborgOS slot " + N(t) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
			dw p_n_c, var_openslot_t
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcpy, stmp1, str26
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str27
			dw p_n_c, var_ns
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str28
			dw p_sk_c
			dw kw_strcpy, stmp2, var_sk_sk
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str29
			dw p_putln_c, var_openslot_t, stmp1

			; Main.bas 885: PutLn t, ""                     ' a blank line under the title
			dw p_putln_c, var_openslot_t, str2

			; Main.bas 886: Prompt t
			dw p_prompt_c, var_openslot_t
			dw p_openslot_r

ntc_rg30_e:
			IF ($ < 32768) && (ntc_rg31_e - ntc_rg31 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg31:
; ============================================================
; function sk (normal mode)
; ============================================================

p_sk:

			; Main.bas 891: If ns <= 9 Then
			dw kw_scplevl, var_ns, 9
			dw kw_goto_iffalse_n, if68_1

			; Main.bas 892: SK = "Control + 1-" + N(ns)
			dw p_n_c, var_ns
			dw kw_strcpy, stmp3, var_n_n
			dw kw_strcpy, var_sk_sk, str30
			dw kw_strcat, var_sk_sk, stmp3

			; Main.bas 893: ElseIf ns = 10 Then
			dw if68_e_go
if68_1:
			dw kw_cpeqvl, var_ns, 10
			dw kw_goto_iffalse_n, if68_2

			; Main.bas 894: SK = "Control + 1-9, 0"
			dw kw_strcpy, var_sk_sk, str31

			; Main.bas 895: Else
			dw if68_e_go
if68_2:

			; Main.bas 896: SK = "Control + 1-9, 0 (twice 11-" + N(ns) + ")"
			dw p_n_c, var_ns
			dw kw_strcpy, stmp3, var_n_n
			dw kw_strcpy, stmp2, str32
			dw kw_strcat, stmp2, stmp3
			dw kw_strcpy, var_sk_sk, stmp2
			dw kw_strcat, var_sk_sk, str33

			; Main.bas 897: End If
if68_e:
			dw p_sk_r

ntc_rg31_e:
			IF ($ < 32768) && (ntc_rg32_e - ntc_rg32 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg32:
; ============================================================
; sub getnm (normal mode)
; ============================================================

p_getnm:

			; Main.bas 904: Dim n As Integer

			; Main.bas 905: n = Memory.ReadByte(Far(t, NMLEN))
			dw p_far_c, var_getnm_t, lit_m2344
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_getnm_n

			; Main.bas 906: en = Space$(12)
			dw kw_strspace, stmp0, lit_12
			dw kw_strcpy, var_en, stmp0

			; Main.bas 907: Memory.Copy Far(t, NMBUF), NearP(VarPtr(en)), n
			dw p_far_c, var_getnm_t, lit_m2343
			dw p_nearp_c, vp_var_en
			dw fn_memory_copy, var_far_far, var_nearp_nearp, var_getnm_n, var_memory_copy_copy

			; Main.bas 908: en = Left$(en, n)
			dw kw_strleft, stmp0, var_en, var_getnm_n
			dw kw_strcpy, var_en, stmp0
			dw p_getnm_r

ntc_rg32_e:
			IF ($ < 32768) && (ntc_rg33_e - ntc_rg33 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg33:
; ============================================================
; function n (normal mode)
; ============================================================

p_n:

			; Main.bas 912: N = Trim$(Str$(v))
			dw kw_strstr, stmp3, var_n_v
			dw kw_strtrim, var_n_n, stmp3
			dw p_n_r

ntc_rg33_e:
			IF ($ < 32768) && (ntc_rg34_e - ntc_rg34 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg34:
; ============================================================
; sub prompt (normal mode)
; ============================================================

p_prompt:

			; Main.bas 916: Memory.WriteByte Far(t, LNLEN), 0                ' an empty command line
			dw p_far_c, var_prompt_t, lit_m2417
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 917: PutS t, N(t) + "> "
			dw p_n_c, var_prompt_t
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcat, stmp1, str34
			dw p_puts_c, var_prompt_t, stmp1
			dw p_prompt_r

ntc_rg34_e:
			IF ($ < 32768) && (ntc_rg35_e - ntc_rg35 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg35:
; ============================================================
; sub keyin (normal mode)
; ============================================================

p_keyin:

			; Main.bas 922: Dim t As Integer, n As Integer

			; Main.bas 923: If front = 0 Then
			dw kw_cpeqvl, var_front, 0
			dw kw_goto_iffalse_n, if69_1

			; Main.bas 924: Exit Sub                      ' TOP stays until Control + ESC or Control + a slot
			dw p_keyin_r

			; Main.bas 925: End If
if69_1:

			; Main.bas 926: t = front
			dw kw_vtov, var_front, var_keyin_t

			; Main.bas 927: If st(t) = 2 Then
			dw kw_aget, arr_st, var_keyin_t, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if70_1

			; Main.bas 928: kq(t) = k                                     ' the key into its bank: its BDOS answers from it
			dw kw_aset, arr_kq, var_keyin_t, var_keyin_k

			; Main.bas 929: Memory.WriteByte Far(t, Hyp.KEY), k
			dw p_far_c, var_keyin_t, lit_m2431
			dw fn_memory_writebyte, var_far_far, var_keyin_k

			; Main.bas 930: Exit Sub
			dw p_keyin_r

			; Main.bas 931: End If
if70_1:

			; Main.bas 932: n = Memory.ReadByte(Far(t, LNLEN))             ' the command line so far (in the slot's bank)
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_keyin_n

			; Main.bas 933: If k = 13 Then
			dw kw_cpeqvl, var_keyin_k, 13
			dw kw_goto_iffalse_n, if71_1

			; Main.bas 934: PutLn t, ""
			dw p_putln_c, var_keyin_t, str2

			; Main.bas 935: Command t
			dw p_command_c, var_keyin_t

			; Main.bas 936: If st(t) = 1 And wt = 0 And front = t Then Prompt t
			dw kw_aget, arr_st, var_keyin_t, tmp0
			dw kw_cpeqvl, tmp0, 1
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_wt, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_cpeqvv, var_front, var_keyin_t
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if71_e
			dw p_prompt_c, var_keyin_t
if72_1:

			; Main.bas 937: ElseIf k = 127 Or k = 8 Then
			dw if71_e_go
if71_1:
			dw kw_cpeqvl, var_keyin_k, 127
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_keyin_k, 8
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if71_2

			; Main.bas 938: If n > 0 Then
			dw kw_scpgtvl, var_keyin_n, 0
			dw kw_goto_iffalse_n, if71_e

			; Main.bas 939: Memory.WriteByte Far(t, LNLEN), n - 1
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_addl, var_keyin_n, -1, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 940: PutC t, 8 : PutC t, 32 : PutC t, 8
			dw p_putc_c, var_keyin_t, lit_8
			dw p_putc_c, var_keyin_t, lit_32
			dw p_putc_c, var_keyin_t, lit_8

			; Main.bas 941: End If
if73_1:

			; Main.bas 942: ElseIf k >= 32 And k < 127 And n < 70 Then
			dw if71_e_go
if71_2:
			dw kw_scpgevl, var_keyin_k, 32
			dw kw_ftov, tmp0
			dw kw_scpltvl, var_keyin_k, 127
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_scpltvl, var_keyin_n, 70
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if71_3

			; Main.bas 943: Memory.WriteByte Far(t, LNBUF + n), k
			dw kw_addl, var_keyin_n, -2416, tmp1
			dw p_far_c, var_keyin_t, tmp1
			dw fn_memory_writebyte, var_far_far, var_keyin_k

			; Main.bas 944: Memory.WriteByte Far(t, LNLEN), n + 1
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_addl, var_keyin_n, 1, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 945: PutC t, k
			dw p_putc_c, var_keyin_t, var_keyin_k

			; Main.bas 946: End If
if71_3:
if71_e:
			dw p_keyin_r

ntc_rg35_e:
			IF ($ < 32768) && (ntc_rg36_e - ntc_rg36 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg36:
; ============================================================
; sub command (normal mode)
; ============================================================

p_command:

			; Main.bas 950: Dim c As String Max 72, p As Integer, s As Integer

			; Main.bas 951: p = Memory.ReadByte(Far(t, LNLEN))              ' the command line, from the slot's bank
			dw p_far_c, var_command_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_command_p

			; Main.bas 952: Memory.Copy Far(t, LNBUF), NearP(VarPtr(ob)), p
			dw p_far_c, var_command_t, lit_m2416
			dw p_nearp_c, vp_var_ob
			dw fn_memory_copy, var_far_far, var_nearp_nearp, var_command_p, var_memory_copy_copy

			; Main.bas 953: c = UCase$(Trim$(Left$(ob, p)))
			dw kw_strleft, stmp0, var_ob, var_command_p
			dw kw_strtrim, stmp0, stmp0
			dw kw_strucase, stmp0, stmp0
			dw kw_strcpy, var_command_c, stmp0

			; Main.bas 954: a = "" : b = ""
			dw kw_strcpy, var_a, str2
			dw kw_strcpy, var_b, str2

			; Main.bas 955: p = InStr(c, " ")
			dw kw_strinstr, lit_1, var_command_c, str20, var_command_p

			; Main.bas 956: If p > 0 Then
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if74_1

			; Main.bas 957: a = Trim$(Mid$(c, p + 1))
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_command_c, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_a, stmp0

			; Main.bas 958: c = Left$(c, p - 1)
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_command_c, tmp1
			dw kw_strcpy, var_command_c, stmp0

			; Main.bas 959: End If
if74_1:

			; Main.bas 960: p = InStr(a, " ")
			dw kw_strinstr, lit_1, var_a, str20, var_command_p

			; Main.bas 961: If p > 0 Then
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if75_1

			; Main.bas 962: b = Trim$(Mid$(a, p + 1))
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0

			; Main.bas 963: a = Left$(a, p - 1)
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_a, tmp1
			dw kw_strcpy, var_a, stmp0

			; Main.bas 964: End If
if75_1:

			; Main.bas 965: If Len(c) = 2 And Right$(c, 1) = ":" And a = "" Then   ' B: alone: CD B, as in CP/M (CD.CYB)
			dw kw_strlen, var_command_c, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_ftov, tmp0
			dw kw_strright, stmp1, var_command_c, lit_1
			dw kw_strcmpeq, stmp1, str35
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_strcmpeq, var_a, str2
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if76_1

			; Main.bas 966: If Asc(c) >= 65 And Asc(c) <= 90 Then a = Left$(c, 1) : c = "CD"
			dw kw_strasc, var_command_c, tmp0
			dw kw_scpgevl, tmp0, 65
			dw kw_ftov, tmp0
			dw kw_strasc, var_command_c, tmp1
			dw kw_scplevl, tmp1, 90
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if77_1
			dw kw_strleft, stmp0, var_command_c, lit_1
			dw kw_strcpy, var_a, stmp0
			dw kw_strcpy, var_command_c, str36
if77_1:

			; Main.bas 967: End If
if76_1:

			; Main.bas 968: Select Case c
			dw kw_strcpy, var_command___sel78, var_command_c

			; Main.bas 969: Case ""
			dw kw_strcmpeq, var_command___sel78, str2
			dw kw_goto_iffalse_n, sel78_1
sel78_b1:

			; Main.bas 970: Case "CLS"
			dw sel78_e_go
sel78_1:
			dw kw_strcmpeq, var_command___sel78, str37
			dw kw_goto_iffalse_n, sel78_2
sel78_b2:

			; Main.bas 971: ClsT t
			dw p_clst_c, var_command_t

			; Main.bas 972: Case "RUN"                                 ' RUN [slot] name [tail]: the program on the disc even
			dw sel78_e_go
sel78_2:
			dw kw_strcmpeq, var_command___sel78, str38
			dw kw_goto_iffalse_n, sel78_3
sel78_b3:

			; Main.bas 973: s = t                                    ' when a command has its name; with a slot: in that one
			dw kw_vtov, var_command_t, var_command_s

			; Main.bas 974: If a <> "" And N(Val(a)) = a Then
			dw kw_strcmpne, var_a, str2
			dw kw_ftov, tmp0
			dw kw_strval, var_a, tmp1
			dw p_n_c, tmp1
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcmpeq, stmp1, var_a
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if79_1

			; Main.bas 975: s = Val(a) : a = b : b = ""
			dw kw_strval, var_a, var_command_s
			dw kw_strcpy, var_a, var_b
			dw kw_strcpy, var_b, str2

			; Main.bas 976: p = InStr(a, " ")
			dw kw_strinstr, lit_1, var_a, str20, var_command_p

			; Main.bas 977: If p > 0 Then b = Trim$(Mid$(a, p + 1)) : a = Left$(a, p - 1)
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if80_1
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_a, tmp1
			dw kw_strcpy, var_a, stmp0
if80_1:

			; Main.bas 978: End If
if79_1:

			; Main.bas 979: If s < 1 Or s > ns Then PutLn t, "no slot" + Str$(s) : Exit Sub
			dw kw_scpltvl, var_command_s, 1
			dw kw_ftov, tmp0
			dw kw_scpgtvv, var_command_s, var_ns
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if81_1
			dw kw_strstr, stmp2, var_command_s
			dw kw_strcpy, stmp1, str39
			dw kw_strcat, stmp1, stmp2
			dw p_putln_c, var_command_t, stmp1
			dw p_command_r
if81_1:

			; Main.bas 980: If st(s) = 2 Then PutLn t, "slot" + Str$(s) + " is busy" : Exit Sub
			dw kw_aget, arr_st, var_command_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if82_1
			dw kw_strstr, stmp2, var_command_s
			dw kw_strcpy, stmp1, str40
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str41
			dw p_putln_c, var_command_t, stmp1
			dw p_command_r
if82_1:

			; Main.bas 981: StartTask t, s
			dw p_starttask_c, var_command_t, var_command_s

			; Main.bas 982: Case "QUIT"
			dw sel78_e_go
sel78_3:
			dw kw_strcmpeq, var_command___sel78, str42
			dw kw_goto_iffalse_n, sel78_4
sel78_b4:

			; Main.bas 983: quit = -1
			dw kw_ltov, -1, var_quit

			; Main.bas 984: Case Else                                  ' the rest are programs (the system drive Z's, else
			dw sel78_e_go
sel78_4:

			; Main.bas 985: b = Trim$(a + " " + b)                   ' the slot's drive, else A): PS, MEM, CD, DIR ... and
			dw kw_strcpy, stmp0, var_a
			dw kw_strcat, stmp0, str20
			dw kw_strcat, stmp0, var_b
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0

			; Main.bas 986: a = c                                    ' any other, the rest of the line their tail
			dw kw_strcpy, var_a, var_command_c

			; Main.bas 987: bare = -1
			dw kw_ltov, -1, var_bare

			; Main.bas 988: StartTask t, t
			dw p_starttask_c, var_command_t, var_command_t

			; Main.bas 989: bare = 0
			dw kw_ztov, var_bare

			; Main.bas 990: End Select
sel78_e:
			dw p_command_r

ntc_rg36_e:
			IF ($ < 32768) && (ntc_rg37_e - ntc_rg37 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg37:
; ============================================================
; sub starttask (normal mode)
; ============================================================

p_starttask:

			; Main.bas 1003: Dim h As Integer, n As Integer, rest As Integer, com As Integer, w As String Max 72, d As Integer

			; Main.bas 1004: If a = "" Then PutLn t, "RUN what?" : Exit Sub
			dw kw_strcmpeq, var_a, str2
			dw kw_goto_iffalse_n, if83_1
			dw p_putln_c, var_starttask_t, str43
			dw p_starttask_r
if83_1:

			; Main.bas 1005: w = a
			dw kw_strcpy, var_starttask_w, var_a

			; Main.bas 1006: d = 0                                          ' the drive looked on: Z (-1, the system drive: the
			dw kw_ztov, var_starttask_d

			; Main.bas 1011: Do
do84_t:

			; Main.bas 1020: a = w : h = 0 : com = 0
			dw kw_strcpy, var_a, var_starttask_w
			dw kw_ztov, var_starttask_h
			dw kw_ztov, var_starttask_com

			; Main.bas 1021: If InStr(a, ".") = 0 Then
			dw kw_strinstr, lit_1, var_a, str44, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if85_1

			; Main.bas 1022: dn = a + ".CYB"
			dw kw_strcpy, var_dn, var_a
			dw kw_strcat, var_dn, str45

			; Main.bas 1023: h = HOpen()
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h

			; Main.bas 1024: If h Then a = dn Else com = -1
			dw kw_goto_ifzero_n, var_starttask_h, if86_1
			dw kw_strcpy, var_a, var_dn
			dw if85_e_go
if86_1:
			dw kw_ltov, -1, var_starttask_com
if86_e:

			; Main.bas 1025: ElseIf Right$(a, 4) = ".COM" Then
			dw if85_e_go
if85_1:
			dw kw_strright, stmp0, var_a, lit_4
			dw kw_strcmpeq, stmp0, str46
			dw kw_goto_iffalse_n, if85_2

			; Main.bas 1026: com = -1
			dw kw_ltov, -1, var_starttask_com

			; Main.bas 1027: Else
			dw if85_e_go
if85_2:

			; Main.bas 1028: dn = a
			dw kw_strcpy, var_dn, var_a

			; Main.bas 1029: h = HOpen()
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h

			; Main.bas 1030: End If
if85_e:

			; Main.bas 1031: rest = &HEE00                                ' #0100 to the stub (#EF00)
			dw kw_ltov, -4608, var_starttask_rest

			; Main.bas 1032: If com Then
			dw kw_goto_ifzero_n, var_starttask_com, if87_1

			; Main.bas 1033: en = a
			dw kw_strcpy, var_en, var_a

			; Main.bas 1034: n = FindCom()                              ' (the entry in rb)
			dw p_findcom_c
			dw kw_vtov, var_findcom_findcom, var_starttask_n

			; Main.bas 1035: If n > 0 Then
			dw kw_scpgtvl, var_starttask_n, 0
			dw kw_goto_iffalse_n, if88_1

			; Main.bas 1036: rest = n                                 ' (an Integer used unsigned: up to #EE00)
			dw kw_vtov, var_starttask_n, var_starttask_rest

			; Main.bas 1037: en = Space$(12)
			dw kw_strspace, stmp0, lit_12
			dw kw_strcpy, var_en, stmp0

			; Main.bas 1038: a = Left$(en, Ent.DiscName(VarPtr(rb), VarPtr(en)))
			dw p_ent_discname_c, vp_arr_rb, vp_var_en
			dw kw_vtov, var_ent_discname_discname, tmp1
			dw kw_strleft, stmp0, var_en, tmp1
			dw kw_strcpy, var_a, stmp0

			; Main.bas 1039: dn = a
			dw kw_strcpy, var_dn, var_a

			; Main.bas 1040: h = HOpen()                              ' (read raw: a #1A is a byte)
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h

			; Main.bas 1041: End If
if88_1:

			; Main.bas 1042: End If
if87_1:

			; Main.bas 1043: If h Then Exit Do
			dw kw_goto_ifzero_n, var_starttask_h, do84_e
			dw do84_e_go
if89_1:

			; Main.bas 1045: Exit Do
			dw do84_e_go

			; Main.bas 1050: Loop
do84_e:

			; Main.bas 1051: If h = 0 Then
			dw kw_cpeqvl, var_starttask_h, 0
			dw kw_goto_iffalse_n, if90_1

			; Main.bas 1052: a = w
			dw kw_strcpy, var_a, var_starttask_w

			; Main.bas 1057: NotFound t
			dw p_notfound_c, var_starttask_t

			; Main.bas 1058: Exit Sub
			dw p_starttask_r

			; Main.bas 1059: End If
if90_1:

			; Main.bas 1060: If st(s) = 0 Then OpenSlot s
			dw kw_aget, arr_st, var_starttask_s, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if91_1
			dw p_openslot_c, var_starttask_s
if91_1:

			; Main.bas 1061: If s <> t Then PutLn s, "RUN " + a
			dw kw_cpnevv, var_starttask_s, var_starttask_t
			dw kw_goto_iffalse_n, if92_1
			dw kw_strcpy, stmp1, str47
			dw kw_strcat, stmp1, var_a
			dw p_putln_c, var_starttask_s, stmp1
if92_1:

			; Main.bas 1062: Install s
			dw p_install_c, var_starttask_s

			; Main.bas 1063: n = Hyp.FileCall(103, rest, s, sg(s), &H100, 0, VarPtr(rb))  ' at #0100, rest bytes at most
			dw kw_aget, arr_sg, var_starttask_s, tmp3
			dw p_hyp_filecall_c, lit_103, var_starttask_rest, var_starttask_s, tmp3, lit_256, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_starttask_n

			; Main.bas 1064: HClose
			dw p_hclose_c

			; Main.bas 1069: If com And n <> rest Then PutLn t, a + ": shorter than FILES.DIR says" : Exit Sub
			dw kw_cpnevv, var_starttask_n, var_starttask_rest
			dw kw_ftov, tmp1
			dw kw_andvv, var_starttask_com, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if93_1
			dw kw_strcpy, stmp1, var_a
			dw kw_strcat, stmp1, str48
			dw p_putln_c, var_starttask_t, stmp1
			dw p_starttask_r
if93_1:

			; Main.bas 1073: Memory.WriteWord Far(s, &HF2FC), Hyp.Info(4)
			dw p_far_c, var_starttask_s, lit_m3332
			dw fn_hyp_info, lit_4, var_hyp_info_info
			dw fn_memory_writeword, var_far_far, var_hyp_info_info

			; Main.bas 1074: Memory.WriteWord Far(s, &HF2FE), 0
			dw p_far_c, var_starttask_s, lit_m3330
			dw fn_memory_writeword, var_far_far, lit_0

			; Main.bas 1075: Memory.WriteWord Far(s, &HFFFE), &HF2FC
			dw p_far_c, var_starttask_s, lit_m2
			dw fn_memory_writeword, var_far_far, lit_m3332

			; Main.bas 1077: If b = "" Then
			dw kw_strcmpeq, var_b, str2
			dw kw_goto_iffalse_n, if94_1

			; Main.bas 1078: Memory.WriteByte Far(s, &H80), 0
			dw p_far_c, var_starttask_s, lit_128
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 1079: Else
			dw if94_e_go
if94_1:

			; Main.bas 1080: b = " " + b
			dw kw_strcpy, stmp0, str20
			dw kw_strcat, stmp0, var_b
			dw kw_strcpy, var_b, stmp0

			; Main.bas 1081: Memory.Copy NearP(VarPtr(b)), Far(s, &H81), Len(b)
			dw p_nearp_c, vp_var_b
			dw p_far_c, var_starttask_s, lit_129
			dw kw_strlen, var_b, tmp2
			dw fn_memory_copy, var_nearp_nearp, var_far_far, tmp2, var_memory_copy_copy

			; Main.bas 1082: Memory.WriteByte Far(s, &H80), Len(b)
			dw p_far_c, var_starttask_s, lit_128
			dw kw_strlen, var_b, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 1083: Memory.WriteByte Far(s, &H81 + Len(b)), 0
			dw kw_strlen, var_b, tmp2
			dw kw_addl, tmp2, 129, tmp1
			dw p_far_c, var_starttask_s, tmp1
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 1084: End If
if94_e:

			; Main.bas 1085: Memory.WriteByte Far(s, NMLEN), Len(a)
			dw p_far_c, var_starttask_s, lit_m2344
			dw kw_strlen, var_a, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 1086: Memory.Copy NearP(VarPtr(a)), Far(s, NMBUF), Len(a)
			dw p_nearp_c, vp_var_a
			dw p_far_c, var_starttask_s, lit_m2343
			dw kw_strlen, var_a, tmp2
			dw fn_memory_copy, var_nearp_nearp, var_far_far, tmp2, var_memory_copy_copy

			; Main.bas 1087: kq(s) = 0
			dw kw_asetl, arr_kq, var_starttask_s, 0

			; Main.bas 1088: Memory.WriteByte Far(s, &HF685), 0             ' no escape sequence rest half done
			dw p_far_c, var_starttask_s, lit_m2427
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 1089: wk(s) = -1
			dw kw_asetl, arr_wk, var_starttask_s, -1

			; Main.bas 1090: dm(s) = &H80                                   ' CP/M's record buffer to start with
			dw kw_asetl, arr_dm, var_starttask_s, 128

			; Main.bas 1091: st(s) = 2
			dw kw_asetl, arr_st, var_starttask_s, 2

			; Main.bas 1092: If s <> t Then PutLn t, a + " runs in slot" + Str$(s)
			dw kw_cpnevv, var_starttask_s, var_starttask_t
			dw kw_goto_iffalse_n, if95_1
			dw kw_strcpy, stmp1, var_a
			dw kw_strcat, stmp1, str49
			dw kw_strstr, stmp2, var_starttask_s
			dw kw_strcat, stmp1, stmp2
			dw p_putln_c, var_starttask_t, stmp1
if95_1:
			dw p_starttask_r

ntc_rg37_e:
			IF ($ < 32768) && (ntc_rg38_e - ntc_rg38 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg38:
; ============================================================
; sub notfound (normal mode)
; ============================================================

p_notfound:

			; Main.bas 1096: If bare Then PutLn t, "? " + a + " (HELP)" Else PutLn t, a + ": not found"
			dw kw_goto_ifzero_n, var_bare, if96_1
			dw kw_strcpy, stmp1, str50
			dw kw_strcat, stmp1, var_a
			dw kw_strcat, stmp1, str51
			dw p_putln_c, var_notfound_t, stmp1
			dw if96_e_go
if96_1:
			dw kw_strcpy, stmp1, var_a
			dw kw_strcat, stmp1, str52
			dw p_putln_c, var_notfound_t, stmp1
if96_e:
			dw p_notfound_r

ntc_rg38_e:
			IF ($ < 32768) && (ntc_rg39_e - ntc_rg39 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg39:
; ============================================================
; function findcom (normal mode)
; ============================================================

p_findcom:

			; Main.bas 1127: Dim r As Integer

			; Main.bas 1128: Ent.SetName VarPtr(en), Len(en)
			dw kw_strlen, var_en, tmp1
			dw p_ent_setname_c, vp_var_en, tmp1

			; Main.bas 1129: dn = en
			dw kw_strcpy, var_dn, var_en

			; Main.bas 1130: r = InStr(dn, ".")
			dw kw_strinstr, lit_1, var_dn, str44, var_findcom_r

			; Main.bas 1131: If r > 0 Then dn = Left$(dn, r - 1)
			dw kw_scpgtvl, var_findcom_r, 0
			dw kw_goto_iffalse_n, if97_1
			dw kw_addl, var_findcom_r, -1, tmp1
			dw kw_strleft, stmp0, var_dn, tmp1
			dw kw_strcpy, var_dn, stmp0
if97_1:

			; Main.bas 1132: r = 0
			dw kw_ztov, var_findcom_r

			; Main.bas 1133: If Len(dn) <= 8 Then dn = dn + ".HDR" : r = FindEnt()      ' (a longer name: only a long name)
			dw kw_strlen, var_dn, tmp0
			dw kw_scplevl, tmp0, 8
			dw kw_goto_iffalse_n, if98_1
			dw kw_strcat, var_dn, str53
			dw p_findent_c
			dw kw_vtov, var_findent_findent, var_findcom_r
if98_1:

			; Main.bas 1134: If r = 0 Then dn = "FILES.DIR" : r = FindEnt()
			dw kw_cpeqvl, var_findcom_r, 0
			dw kw_goto_iffalse_n, if99_1
			dw kw_strcpy, var_dn, str54
			dw p_findent_c
			dw kw_vtov, var_findent_findent, var_findcom_r
if99_1:

			; Main.bas 1135: FindCom = r
			dw kw_vtov, var_findcom_r, var_findcom_findcom
			dw p_findcom_r

ntc_rg39_e:
			IF ($ < 32768) && (ntc_rg40_e - ntc_rg40 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg40:
; ============================================================
; function findent (normal mode)
; ============================================================

p_findent:

			; Main.bas 1140: Dim r As Integer

			; Main.bas 1141: r = 0
			dw kw_ztov, var_findent_r

			; Main.bas 1142: If HOpen() Then
			dw p_hopen_c
			dw kw_goto_ifzero_n, var_hopen_hopen, if100_1

			; Main.bas 1143: Do While HRead(64) = 64
do101_t:
			dw p_hread_c, lit_64
			dw kw_vtov, var_hread_hread, tmp0
			dw kw_cpeqvl, tmp0, 64
			dw kw_goto_iffalse_n, do101_e

			; Main.bas 1144: r = Ent.Length(VarPtr(rb), VarPtr(en), Len(en))
			dw kw_strlen, var_en, tmp2
			dw p_ent_length_c, vp_arr_rb, vp_var_en, tmp2
			dw kw_vtov, var_ent_length_length, var_findent_r

			; Main.bas 1145: If r <> 0 Then Exit Do
			dw kw_cpnevl, var_findent_r, 0
			dw kw_goto_iffalse_n, do101_t
			dw do101_e_go
if102_1:

			; Main.bas 1146: Loop
			dw do101_t_go
do101_e:

			; Main.bas 1147: HClose
			dw p_hclose_c

			; Main.bas 1148: End If
if100_1:

			; Main.bas 1149: FindEnt = r
			dw kw_vtov, var_findent_r, var_findent_findent
			dw p_findent_r

ntc_rg40_e:
			IF ($ < 32768) && (ntc_rg41_e - ntc_rg41 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg41:
; ============================================================
; sub endtask (normal mode)
; ============================================================

p_endtask:

			; Main.bas 1154: Dim c As Integer

			; Main.bas 1155: FilesShut t
			dw p_filesshut_c, var_endtask_t

			; Main.bas 1160: st(t) = 1
			dw kw_asetl, arr_st, var_endtask_t, 1

			; Main.bas 1161: runs = runs + 1
			dw kw_inc, var_runs

			; Main.bas 1162: PutLn t, ""
			dw p_putln_c, var_endtask_t, str2

			; Main.bas 1163: GetNm t
			dw p_getnm_c, var_endtask_t

			; Main.bas 1164: PutLn t, "[" + en + " ended]"
			dw kw_strcpy, stmp1, str10
			dw kw_strcat, stmp1, var_en
			dw kw_strcat, stmp1, str55
			dw p_putln_c, var_endtask_t, stmp1

			; Main.bas 1165: If wt <> t Then Prompt t                       ' (WAIT: the prompt when nothing runs)
			dw kw_cpnevv, var_wt, var_endtask_t
			dw kw_goto_iffalse_n, if103_1
			dw p_prompt_c, var_endtask_t
if103_1:

			; Main.bas 1166: c = kq(t) : kq(t) = 0
			dw kw_aget, arr_kq, var_endtask_t, var_endtask_c
			dw kw_asetl, arr_kq, var_endtask_t, 0

			; Main.bas 1167: If c <> 0 And t = front Then pk = c    ' a key typed for it after its last look: the command line's
			dw kw_cpnevl, var_endtask_c, 0
			dw kw_ftov, tmp0
			dw kw_cpeqvv, var_endtask_t, var_front
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if104_1
			dw kw_vtov, var_endtask_c, var_pk
if104_1:
			dw p_endtask_r

ntc_rg41_e:
			IF ($ < 32768) && (ntc_rg42_e - ntc_rg42 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg42:
; ============================================================
; sub con (normal mode)
; ============================================================

p_hyp_con:

			; Hyp.cls 278: #asm
			dw asm_1_278_n
			dw p_hyp_con_r

ntc_rg42_e:
			IF ($ < 32768) && (ntc_rg43_e - ntc_rg43 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg43:
; ============================================================
; sub say (normal mode)
; ============================================================

p_hyp_say:

			; Hyp.cls 789: #asm
			dw asm_1_789_n
			dw p_hyp_say_r

ntc_rg43_e:
			IF ($ < 32768) && (ntc_rg44_e - ntc_rg44 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg44:
; ============================================================
; function scr (normal mode)
; ============================================================

p_hyp_scr:

			; Hyp.cls 883: #asm
			dw asm_1_883_n
			dw p_hyp_scr_r

ntc_rg44_e:
			IF ($ < 32768) && (ntc_rg45_e - ntc_rg45 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg45:
; ============================================================
; sub keyrep (normal mode)
; ============================================================

p_hyp_keyrep:

			; Hyp.cls 983: #asm
			dw asm_1_983_n
			dw p_hyp_keyrep_r

ntc_rg45_e:
			IF ($ < 32768) && (ntc_rg46_e - ntc_rg46 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg46:
; ============================================================
; sub show (normal mode)
; ============================================================

p_hyp_show:

			; Hyp.cls 1023: Con pg, 0, -1, 1
			dw p_hyp_con_c, var_hyp_show_pg, lit_0, lit_m1, lit_1
			dw p_hyp_show_r

ntc_rg46_e:
			IF ($ < 32768) && (ntc_rg47_e - ntc_rg47 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg47:
; ============================================================
; sub reply (normal mode)
; ============================================================

p_hyp_reply:

			; Hyp.cls 1029: ra = a : rhl = hl
			dw kw_vtov, var_hyp_reply_a, var_hyp_ra
			dw kw_vtov, var_hyp_reply_hl, var_hyp_rhl
			dw p_hyp_reply_r

ntc_rg47_e:
			IF ($ < 32768) && (ntc_rg48_e - ntc_rg48 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg48:
; ============================================================
; function fn (normal mode)
; ============================================================

p_hyp_fn:

			; Hyp.cls 1033: Fn = rfn And 255
			dw kw_andvl, var_hyp_rfn, 255, var_hyp_fn_fn
			dw p_hyp_fn_r

ntc_rg48_e:
			IF ($ < 32768) && (ntc_rg49_e - ntc_rg49 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg49:
; ============================================================
; function arg (normal mode)
; ============================================================

p_hyp_arg:

			; Hyp.cls 1037: Arg = rde
			dw kw_vtov, var_hyp_rde, var_hyp_arg_arg
			dw p_hyp_arg_r

ntc_rg49_e:
			IF ($ < 32768) && (ntc_rg50_e - ntc_rg50 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg50:
; ============================================================
; function count (normal mode)
; ============================================================

p_hyp_count:

			; Hyp.cls 1042: Count = rcnt
			dw kw_vtov, var_hyp_rcnt, var_hyp_count_count
			dw p_hyp_count_r

ntc_rg50_e:
			IF ($ < 32768) && (ntc_rg51_e - ntc_rg51 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg51:
; ============================================================
; function run (normal mode)
; ============================================================

p_hyp_run:

			; Hyp.cls 1047: #asm
			dw asm_1_1047_n
			dw p_hyp_run_r

ntc_rg51_e:
			IF ($ < 32768) && (ntc_rg52_e - ntc_rg52 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg52:
; ============================================================
; sub vdu (normal mode)
; ============================================================

p_hyp_vdu:

			; Hyp.cls 1716: #asm
			dw asm_1_1716_n
			dw p_hyp_vdu_r

ntc_rg52_e:
			IF ($ < 32768) && (ntc_rg53_e - ntc_rg53 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg53:
; ============================================================
; function filecall (normal mode)
; ============================================================

p_hyp_filecall:

			; Hyp.cls 1746: #asm
			dw asm_1_1746_n
			dw p_hyp_filecall_r

ntc_rg53_e:
			IF ($ < 32768) && (ntc_rg54_e - ntc_rg54 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg54:
; ============================================================
; sub fileshut (normal mode)
; ============================================================

p_hyp_fileshut:

			; Hyp.cls 2769: #asm
			dw asm_1_2769_n
			dw p_hyp_fileshut_r

ntc_rg54_e:
			IF ($ < 32768) && (ntc_rg55_e - ntc_rg55 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg55:
; ============================================================
; sub slots (normal mode)
; ============================================================

p_hot_slots:

			; Hot.cls 15: ns = n
			dw kw_vtov, var_hot_slots_n, var_hot_ns
			dw p_hot_slots_r

ntc_rg55_e:
			IF ($ < 32768) && (ntc_rg56_e - ntc_rg56 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg56:
; ============================================================
; sub tick (normal mode)
; ============================================================

p_hot_tick:

			; Hot.cls 19: Dim k As Integer

			; Hot.cls 20: ctl = Keys.Down(Keys.KeyControl)
			dw fn_keys_down, lit_23, var_hot_ctl

			; Hot.cls 21: If ctl Then
			dw kw_goto_ifzero_n, var_hot_ctl, if105_1

			; Hot.cls 22: If Keys.Down(64) Then k = 1
			dw fn_keys_down, lit_64, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if106_1
			dw kw_ltov, 1, var_hot_tick_k
if106_1:

			; Hot.cls 23: If Keys.Down(65) Then k = 2
			dw fn_keys_down, lit_65, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if107_1
			dw kw_ltov, 2, var_hot_tick_k
if107_1:

			; Hot.cls 24: If Keys.Down(57) Then k = 3
			dw fn_keys_down, lit_57, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if108_1
			dw kw_ltov, 3, var_hot_tick_k
if108_1:

			; Hot.cls 25: If Keys.Down(56) Then k = 4
			dw fn_keys_down, lit_56, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if109_1
			dw kw_ltov, 4, var_hot_tick_k
if109_1:

			; Hot.cls 26: If Keys.Down(49) Then k = 5
			dw fn_keys_down, lit_49, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if110_1
			dw kw_ltov, 5, var_hot_tick_k
if110_1:

			; Hot.cls 27: If Keys.Down(48) Then k = 6
			dw fn_keys_down, lit_48, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if111_1
			dw kw_ltov, 6, var_hot_tick_k
if111_1:

			; Hot.cls 28: If Keys.Down(41) Then k = 7
			dw fn_keys_down, lit_41, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if112_1
			dw kw_ltov, 7, var_hot_tick_k
if112_1:

			; Hot.cls 29: If Keys.Down(40) Then k = 8
			dw fn_keys_down, lit_40, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if113_1
			dw kw_ltov, 8, var_hot_tick_k
if113_1:

			; Hot.cls 30: If Keys.Down(33) Then k = 9
			dw fn_keys_down, lit_33, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if114_1
			dw kw_ltov, 9, var_hot_tick_k
if114_1:

			; Hot.cls 31: If Keys.Down(32) Then k = 10
			dw fn_keys_down, lit_32, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if115_1
			dw kw_ltov, 10, var_hot_tick_k
if115_1:

			; Hot.cls 32: If Keys.Down(Keys.KeyEsc) Then k = TOPKEY
			dw fn_keys_down, lit_66, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if116_1
			dw kw_ltov, 99, var_hot_tick_k
if116_1:

			; Hot.cls 33: End If
if105_1:

			; Hot.cls 34: If k <> 0 And k <> last Then
			dw kw_cpnevl, var_hot_tick_k, 0
			dw kw_ftov, tmp5
			dw kw_cpnevv, var_hot_tick_k, var_hot_last
			dw kw_ftov, tmp6
			dw kw_andvv, tmp5, tmp6, tmp5
			dw kw_goto_ifzero_n, tmp5, if117_1

			; Hot.cls 35: If k = TOPKEY Or ns <= 10 Then
			dw kw_cpeqvl, var_hot_tick_k, 99
			dw kw_ftov, tmp5
			dw kw_scplevl, var_hot_ns, 10
			dw kw_ftov, tmp6
			dw kw_orvv, tmp5, tmp6, tmp5
			dw kw_goto_ifzero_n, tmp5, if118_1

			; Hot.cls 36: If one <> 0 Then one = 0
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if119_1
			dw kw_ztov, var_hot_one
if119_1:

			; Hot.cls 37: pend = k                          ' at once (no double taps to wait for)
			dw kw_vtov, var_hot_tick_k, var_hot_pend

			; Hot.cls 38: ElseIf one = k Then
			dw if118_e_go
if118_1:
			dw kw_cpeqvv, var_hot_one, var_hot_tick_k
			dw kw_goto_iffalse_n, if118_2

			; Hot.cls 39: one = 0
			dw kw_ztov, var_hot_one

			; Hot.cls 40: If k + 10 <= ns Then pend = k + 10 Else pend = k  ' the second press: slot 11-20
			dw kw_addl, var_hot_tick_k, 10, tmp5
			dw kw_scplevv, tmp5, var_hot_ns
			dw kw_goto_iffalse_n, if120_1
			dw kw_addl, var_hot_tick_k, 10, var_hot_pend
			dw if118_e_go
if120_1:
			dw kw_vtov, var_hot_tick_k, var_hot_pend
if120_e:

			; Hot.cls 41: Else
			dw if118_e_go
if118_2:

			; Hot.cls 42: If one <> 0 Then pend = one       ' another number: the waiting one counts now
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if121_1
			dw kw_vtov, var_hot_one, var_hot_pend
if121_1:

			; Hot.cls 43: one = k : age = 0
			dw kw_vtov, var_hot_tick_k, var_hot_one
			dw kw_ztov, var_hot_age

			; Hot.cls 44: End If
if118_e:

			; Hot.cls 45: End If
if117_1:

			; Hot.cls 46: If one <> 0 Then
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if122_1

			; Hot.cls 47: age = age + 1
			dw kw_inc, var_hot_age

			; Hot.cls 48: If age > DOUBLE Or ctl = 0 Then pend = one : one = 0    ' no second press (or Control let go)
			dw kw_scpgtvl, var_hot_age, 15
			dw kw_ftov, tmp5
			dw kw_cpeqvl, var_hot_ctl, 0
			dw kw_ftov, tmp6
			dw kw_orvv, tmp5, tmp6, tmp5
			dw kw_goto_ifzero_n, tmp5, if123_1
			dw kw_vtov, var_hot_one, var_hot_pend
			dw kw_ztov, var_hot_one
if123_1:

			; Hot.cls 49: End If
if122_1:

			; Hot.cls 50: last = k
			dw kw_vtov, var_hot_tick_k, var_hot_last
			dw p_hot_tick_r

ntc_rg56_e:
			IF ($ < 32768) && (ntc_rg57_e - ntc_rg57 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg57:
; ============================================================
; function take (normal mode)
; ============================================================

p_hot_take:

			; Hot.cls 54: Take = pend
			dw kw_vtov, var_hot_pend, var_hot_take_take

			; Hot.cls 55: pend = 0
			dw kw_ztov, var_hot_pend
			dw p_hot_take_r

ntc_rg57_e:
			IF ($ < 32768) && (ntc_rg58_e - ntc_rg58 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg58:
; ============================================================
; function control (normal mode)
; ============================================================

p_hot_control:

			; Hot.cls 60: Control = ctl
			dw kw_vtov, var_hot_ctl, var_hot_control_control
			dw p_hot_control_r

ntc_rg58_e:
			IF ($ < 32768) && (ntc_rg59_e - ntc_rg59 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg59:
; ============================================================
; sub setname (normal mode)
; ============================================================

p_ent_setname:

			; Ent.cls 21: #asm
			dw asm_3_21_n
			dw p_ent_setname_r

ntc_rg59_e:
			IF ($ < 32768) && (ntc_rg60_e - ntc_rg60 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg60:
; ============================================================
; function length (normal mode)
; ============================================================

p_ent_length:

			; Ent.cls 89: #asm
			dw asm_3_89_n
			dw p_ent_length_r

ntc_rg60_e:
			IF ($ < 32768) && (ntc_rg61_e - ntc_rg61 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg61:
; ============================================================
; function discname (normal mode)
; ============================================================

p_ent_discname:

			; Ent.cls 245: #asm
			dw asm_3_245_n
			dw p_ent_discname_r

ntc_rg61_e:
			IF ($ < 32768) && (ntc_rg62_e - ntc_rg62 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg62:
; ============================================================
; function bankpage (normal mode)
; ============================================================

p_memory_bankpage:

			; Memory.cls 474: BankPage = 4 * bank - 2 + n
			dw kw_4x, var_memory_bankpage_bank, tmp1
			dw kw_addl, tmp1, -2, tmp1
			dw kw_add, tmp1, var_memory_bankpage_n, var_memory_bankpage_bankpage
			dw p_memory_bankpage_r

; ============================================================
; Jump stubs (code, ROMable)
;   label_go: GOTO label
;   label_gs: GOSUB label, return point -> label_rs (RAM)
;   label_rt: RETURN from label
;   p_name_c: call a procedure, p_name_r: end of it
;   turbo mode ends with ret, normal mode with jp ntc_xn
; ============================================================

do5_t_go:			ld sp, do5_t
			jp ntc_xn
if9_e_go:			ld sp, if9_e
			jp ntc_xn
if11_e_go:			ld sp, if11_e
			jp ntc_xn
for23_e_go:			ld sp, for23_e
			jp ntc_xn
do31_e_go:			ld sp, do31_e
			jp ntc_xn
do31_t_go:			ld sp, do31_t
			jp ntc_xn
sel39_e_go:			ld sp, sel39_e
			jp ntc_xn
ch48_e_go:			ld sp, ch48_e
			jp ntc_xn
if47_e_go:			ld sp, if47_e
			jp ntc_xn
ch52_e_go:			ld sp, ch52_e
			jp ntc_xn
ch53_e_go:			ld sp, ch53_e
			jp ntc_xn
ch54_e_go:			ld sp, ch54_e
			jp ntc_xn
if59_e_go:			ld sp, if59_e
			jp ntc_xn
if61_e_go:			ld sp, if61_e
			jp ntc_xn
ch63_e_go:			ld sp, ch63_e
			jp ntc_xn
if64_e_go:			ld sp, if64_e
			jp ntc_xn
if66_e_go:			ld sp, if66_e
			jp ntc_xn
if68_e_go:			ld sp, if68_e
			jp ntc_xn
if71_e_go:			ld sp, if71_e
			jp ntc_xn
sel78_e_go:			ld sp, sel78_e
			jp ntc_xn
if85_e_go:			ld sp, if85_e
			jp ntc_xn
do84_e_go:			ld sp, do84_e
			jp ntc_xn
if94_e_go:			ld sp, if94_e
			jp ntc_xn
if96_e_go:			ld sp, if96_e
			jp ntc_xn
do101_e_go:			ld sp, do101_e
			jp ntc_xn
do101_t_go:			ld sp, do101_t
			jp ntc_xn
if118_e_go:			ld sp, if118_e
			jp ntc_xn

p_running_c:		; call running (normal)
			ld hl, 0
			ld (var_running_running), hl
			ld hl, 0
			ld (var_running_j), hl
			ld (p_running_rs), sp
			ld sp, p_running
			jp ntc_xn
p_running_r:		; end of running
			ld sp, (p_running_rs)
			jp ntc_xn
p_ready_c:		; call ready (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ready_t), de
			ld hl, 0
			ld (var_ready_ready), hl
			ld (p_ready_rs), sp
			ld sp, p_ready
			jp ntc_xn
p_ready_r:		; end of ready
			ld sp, (p_ready_rs)
			jp ntc_xn
p_runnext_c:		; call runnext (normal)
			ld hl, 0
			ld (var_runnext_n), hl
			ld hl, 0
			ld (var_runnext_t), hl
			ld hl, 0
			ld (var_runnext_r), hl
			ld hl, 0
			ld (var_runnext_c), hl
			ld hl, 0
			ld (var_runnext_q), hl
			ld (p_runnext_rs), sp
			ld sp, p_runnext
			jp ntc_xn
p_runnext_r:		; end of runnext
			ld sp, (p_runnext_rs)
			jp ntc_xn
p_bdos_c:		; call bdos (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_bdos_t), de
			ld hl, 0
			ld (var_bdos_f), hl
			ld hl, 0
			ld (var_bdos_e), hl
			ld hl, 0
			ld (var_bdos_a), hl
			ld (p_bdos_rs), sp
			ld sp, p_bdos
			jp ntc_xn
p_bdos_r:		; end of bdos
			ld sp, (p_bdos_rs)
			jp ntc_xn
p_sys_c:		; call sys (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_sys_t), de
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_sys_p), de
			ld hl, 0
			ld (var_sys_sys), hl
			ld hl, 0
			ld (var_sys_o), hl
			ld hl, 0
			ld (var_sys_s), hl
			ld hl, 0
			ld (var_sys_d), hl
			ld (p_sys_rs), sp
			ld sp, p_sys
			jp ntc_xn
p_sys_r:		; end of sys
			ld sp, (p_sys_rs)
			jp ntc_xn
p_puten_c:		; call puten (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_puten_t), de
			pop hl			; a
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_puten_a), de
			ld (p_puten_rs), sp
			ld sp, p_puten
			jp ntc_xn
p_puten_r:		; end of puten
			ld sp, (p_puten_rs)
			jp ntc_xn
p_hopen_c:		; call hopen (normal)
			ld hl, 0
			ld (var_hopen_hopen), hl
			ld (p_hopen_rs), sp
			ld sp, p_hopen
			jp ntc_xn
p_hopen_r:		; end of hopen
			ld sp, (p_hopen_rs)
			jp ntc_xn
p_hread_c:		; call hread (normal)
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hread_n), de
			ld hl, 0
			ld (var_hread_hread), hl
			ld (p_hread_rs), sp
			ld sp, p_hread
			jp ntc_xn
p_hread_r:		; end of hread
			ld sp, (p_hread_rs)
			jp ntc_xn
p_hclose_c:		; call hclose (normal)
			ld hl, 0
			ld (var_hclose_r), hl
			ld (p_hclose_rs), sp
			ld sp, p_hclose
			jp ntc_xn
p_hclose_r:		; end of hclose
			ld sp, (p_hclose_rs)
			jp ntc_xn
p_filesshut_c:		; call filesshut (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_filesshut_t), de
			ld (p_filesshut_rs), sp
			ld sp, p_filesshut
			jp ntc_xn
p_filesshut_r:		; end of filesshut
			ld sp, (p_filesshut_rs)
			jp ntc_xn
p_collected_c:		; call collected (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_collected_t), de
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_collected_n), de
			ld (p_collected_rs), sp
			ld sp, p_collected
			jp ntc_xn
p_collected_r:		; end of collected
			ld sp, (p_collected_rs)
			jp ntc_xn
p_puts_c:		; call puts (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_puts_t), de
			pop hl			; s
			ld de, var_puts_s
			ld b, 255
p_puts_si1:
			ld a, (hl)
			ld (de), a
			or a
			jr z, p_puts_si1_e
			inc hl
			inc de
			djnz p_puts_si1
			xor a
			ld (de), a
p_puts_si1_e:
			ld (p_puts_rs), sp
			ld sp, p_puts
			jp ntc_xn
p_puts_r:		; end of puts
			ld sp, (p_puts_rs)
			jp ntc_xn
p_putln_c:		; call putln (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_putln_t), de
			pop hl			; s
			ld de, var_putln_s
			ld b, 255
p_putln_si1:
			ld a, (hl)
			ld (de), a
			or a
			jr z, p_putln_si1_e
			inc hl
			inc de
			djnz p_putln_si1
			xor a
			ld (de), a
p_putln_si1_e:
			ld (p_putln_rs), sp
			ld sp, p_putln
			jp ntc_xn
p_putln_r:		; end of putln
			ld sp, (p_putln_rs)
			jp ntc_xn
p_putc_c:		; call putc (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_putc_t), de
			pop hl			; c
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_putc_c), de
			ld (p_putc_rs), sp
			ld sp, p_putc
			jp ntc_xn
p_putc_r:		; end of putc
			ld sp, (p_putc_rs)
			jp ntc_xn
p_nearp_c:		; call nearp (normal)
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_nearp_p), de
			ld hl, 0
			ld (var_nearp_nearp), hl
			ld (var_nearp_nearp+2), hl
			ld (p_nearp_rs), sp
			ld sp, p_nearp
			jp ntc_xn
p_nearp_r:		; end of nearp
			ld sp, (p_nearp_rs)
			jp ntc_xn
p_far_c:		; call far (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_far_t), de
			pop hl			; a
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_far_a), de
			ld hl, 0
			ld (var_far_far), hl
			ld (var_far_far+2), hl
			ld (p_far_rs), sp
			ld sp, p_far
			jp ntc_xn
p_far_r:		; end of far
			ld sp, (p_far_rs)
			jp ntc_xn
p_clst_c:		; call clst (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_clst_t), de
			ld (p_clst_rs), sp
			ld sp, p_clst
			jp ntc_xn
p_clst_r:		; end of clst
			ld sp, (p_clst_rs)
			jp ntc_xn
p_tofront_c:		; call tofront (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_tofront_t), de
			ld hl, 0
			ld (var_tofront_r), hl
			ld (p_tofront_rs), sp
			ld sp, p_tofront
			jp ntc_xn
p_tofront_r:		; end of tofront
			ld sp, (p_tofront_rs)
			jp ntc_xn
p_setmode_c:		; call setmode (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_setmode_t), de
			pop hl			; m
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_setmode_m), de
			ld hl, 0
			ld (var_setmode_r), hl
			ld (p_setmode_rs), sp
			ld sp, p_setmode
			jp ntc_xn
p_setmode_r:		; end of setmode
			ld sp, (p_setmode_rs)
			jp ntc_xn
p_showtop_c:		; call showtop (normal)
			ld hl, 0
			ld (var_showtop_j), hl
			ld (p_showtop_rs), sp
			ld sp, p_showtop
			jp ntc_xn
p_showtop_r:		; end of showtop
			ld sp, (p_showtop_rs)
			jp ntc_xn
p_toplines_c:		; call toplines (normal)
			pop hl			; mark
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_toplines_mark), de
			pop hl			; keys
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_toplines_keys), de
			ld hl, 0
			ld (var_toplines_j), hl
			xor a
			ld (var_toplines_s), a
			ld (p_toplines_rs), sp
			ld sp, p_toplines
			jp ntc_xn
p_toplines_r:		; end of toplines
			ld sp, (p_toplines_rs)
			jp ntc_xn
p_totals_c:		; call totals (normal)
			ld (p_totals_rs), sp
			ld sp, p_totals
			jp ntc_xn
p_totals_r:		; end of totals
			ld sp, (p_totals_rs)
			jp ntc_xn
p_topadd_c:		; call topadd (normal)
			pop hl			; s
			ld de, var_topadd_s
			ld b, 255
p_topadd_si0:
			ld a, (hl)
			ld (de), a
			or a
			jr z, p_topadd_si0_e
			inc hl
			inc de
			djnz p_topadd_si0
			xor a
			ld (de), a
p_topadd_si0_e:
			ld (p_topadd_rs), sp
			ld sp, p_topadd
			jp ntc_xn
p_topadd_r:		; end of topadd
			ld sp, (p_topadd_rs)
			jp ntc_xn
p_roll_c:		; call roll (normal)
			ld hl, 0
			ld (var_roll_j), hl
			ld (p_roll_rs), sp
			ld sp, p_roll
			jp ntc_xn
p_roll_r:		; end of roll
			ld sp, (p_roll_rs)
			jp ntc_xn
p_pad_c:		; call pad (normal)
			pop hl			; v
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_pad_v), de
			xor a
			ld (var_pad_pad), a
			ld (p_pad_rs), sp
			ld sp, p_pad
			jp ntc_xn
p_pad_r:		; end of pad
			ld sp, (p_pad_rs)
			jp ntc_xn
p_rate_c:		; call rate (normal)
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_rate_n), de
			pop hl			; d
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_rate_d), de
			ld hl, 0
			ld (var_rate_rate), hl
			ld (p_rate_rs), sp
			ld sp, p_rate
			jp ntc_xn
p_rate_r:		; end of rate
			ld sp, (p_rate_rs)
			jp ntc_xn
p_install_c:		; call install (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_install_t), de
			ld hl, 0
			ld (var_install_p), hl
			ld hl, 0
			ld (var_install_n), hl
			ld (p_install_rs), sp
			ld sp, p_install
			jp ntc_xn
p_install_r:		; end of install
			ld sp, (p_install_rs)
			jp ntc_xn
p_resetslot_c:		; call resetslot (normal)
			pop hl			; s
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_resetslot_s), de
			ld (p_resetslot_rs), sp
			ld sp, p_resetslot
			jp ntc_xn
p_resetslot_r:		; end of resetslot
			ld sp, (p_resetslot_rs)
			jp ntc_xn
p_openslot_c:		; call openslot (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_openslot_t), de
			ld (p_openslot_rs), sp
			ld sp, p_openslot
			jp ntc_xn
p_openslot_r:		; end of openslot
			ld sp, (p_openslot_rs)
			jp ntc_xn
p_sk_c:		; call sk (normal)
			xor a
			ld (var_sk_sk), a
			ld (p_sk_rs), sp
			ld sp, p_sk
			jp ntc_xn
p_sk_r:		; end of sk
			ld sp, (p_sk_rs)
			jp ntc_xn
p_getnm_c:		; call getnm (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_getnm_t), de
			ld hl, 0
			ld (var_getnm_n), hl
			ld (p_getnm_rs), sp
			ld sp, p_getnm
			jp ntc_xn
p_getnm_r:		; end of getnm
			ld sp, (p_getnm_rs)
			jp ntc_xn
p_n_c:		; call n (normal)
			pop hl			; v
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_n_v), de
			xor a
			ld (var_n_n), a
			ld (p_n_rs), sp
			ld sp, p_n
			jp ntc_xn
p_n_r:		; end of n
			ld sp, (p_n_rs)
			jp ntc_xn
p_prompt_c:		; call prompt (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_prompt_t), de
			ld (p_prompt_rs), sp
			ld sp, p_prompt
			jp ntc_xn
p_prompt_r:		; end of prompt
			ld sp, (p_prompt_rs)
			jp ntc_xn
p_keyin_c:		; call keyin (normal)
			pop hl			; k
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_keyin_k), de
			ld hl, 0
			ld (var_keyin_t), hl
			ld hl, 0
			ld (var_keyin_n), hl
			ld (p_keyin_rs), sp
			ld sp, p_keyin
			jp ntc_xn
p_keyin_r:		; end of keyin
			ld sp, (p_keyin_rs)
			jp ntc_xn
p_command_c:		; call command (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_command_t), de
			xor a
			ld (var_command_c), a
			ld hl, 0
			ld (var_command_p), hl
			ld hl, 0
			ld (var_command_s), hl
			ld (p_command_rs), sp
			ld sp, p_command
			jp ntc_xn
p_command_r:		; end of command
			ld sp, (p_command_rs)
			jp ntc_xn
p_starttask_c:		; call starttask (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_starttask_t), de
			pop hl			; s
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_starttask_s), de
			ld hl, 0
			ld (var_starttask_h), hl
			ld hl, 0
			ld (var_starttask_n), hl
			ld hl, 0
			ld (var_starttask_rest), hl
			ld hl, 0
			ld (var_starttask_com), hl
			xor a
			ld (var_starttask_w), a
			ld hl, 0
			ld (var_starttask_d), hl
			ld (p_starttask_rs), sp
			ld sp, p_starttask
			jp ntc_xn
p_starttask_r:		; end of starttask
			ld sp, (p_starttask_rs)
			jp ntc_xn
p_notfound_c:		; call notfound (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_notfound_t), de
			ld (p_notfound_rs), sp
			ld sp, p_notfound
			jp ntc_xn
p_notfound_r:		; end of notfound
			ld sp, (p_notfound_rs)
			jp ntc_xn
p_findcom_c:		; call findcom (normal)
			ld hl, 0
			ld (var_findcom_findcom), hl
			ld hl, 0
			ld (var_findcom_r), hl
			ld (p_findcom_rs), sp
			ld sp, p_findcom
			jp ntc_xn
p_findcom_r:		; end of findcom
			ld sp, (p_findcom_rs)
			jp ntc_xn
p_findent_c:		; call findent (normal)
			ld hl, 0
			ld (var_findent_findent), hl
			ld hl, 0
			ld (var_findent_r), hl
			ld (p_findent_rs), sp
			ld sp, p_findent
			jp ntc_xn
p_findent_r:		; end of findent
			ld sp, (p_findent_rs)
			jp ntc_xn
p_endtask_c:		; call endtask (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_endtask_t), de
			ld hl, 0
			ld (var_endtask_c), hl
			ld (p_endtask_rs), sp
			ld sp, p_endtask
			jp ntc_xn
p_endtask_r:		; end of endtask
			ld sp, (p_endtask_rs)
			jp ntc_xn
p_hyp_con_c:		; call con (normal)
			pop hl			; pg
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_con_pg), de
			pop hl			; src
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_con_src), de
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_con_n), de
			pop hl			; front
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_con_front), de
			ld (p_hyp_con_rs), sp
			ld sp, p_hyp_con
			jp ntc_xn
p_hyp_con_r:		; end of con
			ld sp, (p_hyp_con_rs)
			jp ntc_xn
p_hyp_say_c:		; call say (normal)
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_say_p), de
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_say_n), de
			pop hl			; col
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_say_col), de
			pop hl			; row
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_say_row), de
			ld (p_hyp_say_rs), sp
			ld sp, p_hyp_say
			jp ntc_xn
p_hyp_say_r:		; end of say
			ld sp, (p_hyp_say_rs)
			jp ntc_xn
p_hyp_scr_c:		; call scr (normal)
			pop hl			; m
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_scr_m), de
			pop hl			; k
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_scr_k), de
			ld hl, 0
			ld (var_hyp_scr_scr), hl
			ld (p_hyp_scr_rs), sp
			ld sp, p_hyp_scr
			jp ntc_xn
p_hyp_scr_r:		; end of scr
			ld sp, (p_hyp_scr_rs)
			jp ntc_xn
p_hyp_keyrep_c:		; call keyrep (normal)
			pop hl			; f
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_keyrep_f), de
			ld (p_hyp_keyrep_rs), sp
			ld sp, p_hyp_keyrep
			jp ntc_xn
p_hyp_keyrep_r:		; end of keyrep
			ld sp, (p_hyp_keyrep_rs)
			jp ntc_xn
p_hyp_show_c:		; call show (normal)
			pop hl			; pg
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_show_pg), de
			ld (p_hyp_show_rs), sp
			ld sp, p_hyp_show
			jp ntc_xn
p_hyp_show_r:		; end of show
			ld sp, (p_hyp_show_rs)
			jp ntc_xn
p_hyp_reply_c:		; call reply (normal)
			pop hl			; a
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_reply_a), de
			pop hl			; hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_reply_hl), de
			ld (p_hyp_reply_rs), sp
			ld sp, p_hyp_reply
			jp ntc_xn
p_hyp_reply_r:		; end of reply
			ld sp, (p_hyp_reply_rs)
			jp ntc_xn
p_hyp_fn_c:		; call fn (normal)
			ld hl, 0
			ld (var_hyp_fn_fn), hl
			ld (p_hyp_fn_rs), sp
			ld sp, p_hyp_fn
			jp ntc_xn
p_hyp_fn_r:		; end of fn
			ld sp, (p_hyp_fn_rs)
			jp ntc_xn
p_hyp_arg_c:		; call arg (normal)
			ld hl, 0
			ld (var_hyp_arg_arg), hl
			ld (p_hyp_arg_rs), sp
			ld sp, p_hyp_arg
			jp ntc_xn
p_hyp_arg_r:		; end of arg
			ld sp, (p_hyp_arg_rs)
			jp ntc_xn
p_hyp_count_c:		; call count (normal)
			ld hl, 0
			ld (var_hyp_count_count), hl
			ld (p_hyp_count_rs), sp
			ld sp, p_hyp_count
			jp ntc_xn
p_hyp_count_r:		; end of count
			ld sp, (p_hyp_count_rs)
			jp ntc_xn
p_hyp_run_c:		; call run (normal)
			pop hl			; setting
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_run_setting), de
			ld hl, 0
			ld (var_hyp_run_run), hl
			ld (p_hyp_run_rs), sp
			ld sp, p_hyp_run
			jp ntc_xn
p_hyp_run_r:		; end of run
			ld sp, (p_hyp_run_rs)
			jp ntc_xn
p_hyp_vdu_c:		; call vdu (normal)
			pop hl			; on
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_vdu_on), de
			ld (p_hyp_vdu_rs), sp
			ld sp, p_hyp_vdu
			jp ntc_xn
p_hyp_vdu_r:		; end of vdu
			ld sp, (p_hyp_vdu_rs)
			jp ntc_xn
p_hyp_filecall_c:		; call filecall (normal)
			pop hl			; f
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_filecall_f), de
			pop hl			; fcb
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_filecall_fcb), de
			pop hl			; slot
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_filecall_slot), de
			pop hl			; setting
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_filecall_setting), de
			pop hl			; dma
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_filecall_dma), de
			pop hl			; drive
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_filecall_drive), de
			pop hl			; buf
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_filecall_buf), de
			ld hl, 0
			ld (var_hyp_filecall_filecall), hl
			ld (p_hyp_filecall_rs), sp
			ld sp, p_hyp_filecall
			jp ntc_xn
p_hyp_filecall_r:		; end of filecall
			ld sp, (p_hyp_filecall_rs)
			jp ntc_xn
p_hyp_fileshut_c:		; call fileshut (normal)
			pop hl			; slot
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_fileshut_slot), de
			ld (p_hyp_fileshut_rs), sp
			ld sp, p_hyp_fileshut
			jp ntc_xn
p_hyp_fileshut_r:		; end of fileshut
			ld sp, (p_hyp_fileshut_rs)
			jp ntc_xn
p_hot_slots_c:		; call slots (normal)
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hot_slots_n), de
			ld (p_hot_slots_rs), sp
			ld sp, p_hot_slots
			jp ntc_xn
p_hot_slots_r:		; end of slots
			ld sp, (p_hot_slots_rs)
			jp ntc_xn
p_hot_tick_c:		; call tick (normal)
			ld hl, 0
			ld (var_hot_tick_k), hl
			ld (p_hot_tick_rs), sp
			ld sp, p_hot_tick
			jp ntc_xn
p_hot_tick_r:		; end of tick
			xor a			; Tick done: it may run again
			ld (ntc_isl + 4), a
			ld sp, (p_hot_tick_rs)
			jp ntc_xn
p_hot_take_c:		; call take (normal)
			ld hl, 0
			ld (var_hot_take_take), hl
			ld (p_hot_take_rs), sp
			ld sp, p_hot_take
			jp ntc_xn
p_hot_take_r:		; end of take
			ld sp, (p_hot_take_rs)
			jp ntc_xn
p_hot_control_c:		; call control (normal)
			ld hl, 0
			ld (var_hot_control_control), hl
			ld (p_hot_control_rs), sp
			ld sp, p_hot_control
			jp ntc_xn
p_hot_control_r:		; end of control
			ld sp, (p_hot_control_rs)
			jp ntc_xn
p_ent_setname_c:		; call setname (normal)
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ent_setname_p), de
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ent_setname_n), de
			ld (p_ent_setname_rs), sp
			ld sp, p_ent_setname
			jp ntc_xn
p_ent_setname_r:		; end of setname
			ld sp, (p_ent_setname_rs)
			jp ntc_xn
p_ent_length_c:		; call length (normal)
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ent_length_p), de
			pop hl			; s
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ent_length_s), de
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ent_length_n), de
			ld hl, 0
			ld (var_ent_length_length), hl
			ld (p_ent_length_rs), sp
			ld sp, p_ent_length
			jp ntc_xn
p_ent_length_r:		; end of length
			ld sp, (p_ent_length_rs)
			jp ntc_xn
p_ent_discname_c:		; call discname (normal)
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ent_discname_p), de
			pop hl			; d
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ent_discname_d), de
			ld hl, 0
			ld (var_ent_discname_discname), hl
			ld (p_ent_discname_rs), sp
			ld sp, p_ent_discname
			jp ntc_xn
p_ent_discname_r:		; end of discname
			ld sp, (p_ent_discname_rs)
			jp ntc_xn
p_memory_bankpage_c:		; call bankpage (normal)
			pop hl			; bank
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_memory_bankpage_bank), de
			pop hl			; n
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_memory_bankpage_n), de
			ld hl, 0
			ld (var_memory_bankpage_bankpage), hl
			ld (p_memory_bankpage_rs), sp
			ld sp, p_memory_bankpage
			jp ntc_xn
p_memory_bankpage_r:		; end of bankpage
			ld sp, (p_memory_bankpage_rs)
			jp ntc_xn

ntc_rg62_e:
			IF ($ < 32768) && (ntc_rg63_e - ntc_rg63 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg63:
; ============================================================
; Inline assembly (#asm ... #endasm)
; ============================================================

fn_hyp_usepage:		; sub usepage (asm keyword), Hyp.cls line 48
            ld hl, (ntc_rampt)		; Hyp.cls 49
            ld (var_hyp_hps), hl		; Hyp.cls 50
			ret			; end of #asm

fn_hyp_setting:		; function setting (asm keyword), Hyp.cls line 96
            ld de, (ntc_rampt)		; Hyp.cls 97
            ld a, e		; Hyp.cls 98
            and #F8		; Hyp.cls 99
            or 2		; Hyp.cls 100
            ld e, a		; Hyp.cls 101
            pop hl		; Hyp.cls 102
            ld (hl), e		; Hyp.cls 103
            inc hl		; Hyp.cls 104
            ld (hl), d		; Hyp.cls 105
			ret			; end of #asm

fn_hyp_farptr:		; function farptr (asm keyword), Hyp.cls line 112
            pop hl		; Hyp.cls 113
            ld c, (hl)		; Hyp.cls 114
            inc hl		; Hyp.cls 115
            ld b, (hl)              ; BC = page [116]
            pop hl		; Hyp.cls 117
            ld e, (hl)		; Hyp.cls 118
            inc hl		; Hyp.cls 119
            ld a, (hl)		; Hyp.cls 120
            and #3F		; Hyp.cls 121
            or #40		; Hyp.cls 122
            ld d, a                 ; DE = #4000 + the address's low 14 bits [123]
            pop hl		; Hyp.cls 124
            ld (hl), e		; Hyp.cls 125
            inc hl		; Hyp.cls 126
            ld (hl), d		; Hyp.cls 127
            inc hl		; Hyp.cls 128
            ld (hl), c		; Hyp.cls 129
            inc hl		; Hyp.cls 130
            ld (hl), b		; Hyp.cls 131
			ret			; end of #asm

fn_hyp_fontinit:		; sub fontinit (asm keyword), Hyp.cls line 165
            ld (var_hyp_hsp), sp		; Hyp.cls 166
            ld sp, (ntc_csp)		; Hyp.cls 167
            ld bc, (var_hyp_hps)		; Hyp.cls 168
            out (c), c		; Hyp.cls 169
            ld de, 32               ; D = 0: a table, E = its first character [170]
            ld hl, #4000 + 4096		; Hyp.cls 171
            call #BBAB              ; TXT SET M TABLE (the matrices from 32 on, copied there) [172]
            di		; Hyp.cls 173
            ld de, #FF00            ; D <> 0: no table of its own any more [174]
            call #BBAB		; Hyp.cls 175
            di		; Hyp.cls 176
            ld bc, (ntc_rampt)		; Hyp.cls 177
            out (c), c		; Hyp.cls 178
            ld sp, (var_hyp_hsp)		; Hyp.cls 179
			ret			; end of #asm

asm_1_278_n:		; #asm, Hyp.cls line 278 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 279
            ld sp, (ntc_csp)		; Hyp.cls 280
            ld bc, (var_hyp_con_pg)		; Hyp.cls 281
            out (c), c              ; the slot's page 3 at #4000: OBUF #7600, state #7682, page #7700 [282]
            xor a		; Hyp.cls 283
            ld (asm_1_278_n_cn_pv), a		; Hyp.cls 284
            ld a, (var_hyp_con_front)		; Hyp.cls 285
            ld (asm_1_278_n_cn_front), a		; Hyp.cls 286
            ld a, (#7687)           ; its columns and rows (MODE) [287]
            ld (asm_1_278_n_cn_c), a		; Hyp.cls 288
            ld a, (#7688)		; Hyp.cls 289
            ld (asm_1_278_n_cn_r), a		; Hyp.cls 290
            ld hl, (var_hyp_con_n)		; Hyp.cls 291
            bit 7, h		; Hyp.cls 292
            jp nz, asm_1_278_n_cn_show		; Hyp.cls 293
            ld (asm_1_278_n_cn_left), hl		; Hyp.cls 294
            ld hl, (var_hyp_con_src)		; Hyp.cls 295
            ld a, h		; Hyp.cls 296
            or l		; Hyp.cls 297
            jr nz, asm_1_278_n_cn_src		; Hyp.cls 298
            ld hl, #7600            ; src 0: the characters the program collected (OBUF) [299]
asm_1_278_n_cn_src:		; Hyp.cls 300
            ld (asm_1_278_n_cn_ptr), hl		; Hyp.cls 301
asm_1_278_n_cn_lp:		; Hyp.cls 302
            ld hl, (asm_1_278_n_cn_left)		; Hyp.cls 303
            ld a, h		; Hyp.cls 304
            or l		; Hyp.cls 305
            jr z, asm_1_278_n_cn_done		; Hyp.cls 306
            dec hl		; Hyp.cls 307
            ld (asm_1_278_n_cn_left), hl		; Hyp.cls 308
            ld hl, (asm_1_278_n_cn_ptr)		; Hyp.cls 309
            ld a, (hl)		; Hyp.cls 310
            inc hl		; Hyp.cls 311
            ld (asm_1_278_n_cn_ptr), hl		; Hyp.cls 312
            call asm_1_278_n_cn_char		; Hyp.cls 313
            jr asm_1_278_n_cn_lp		; Hyp.cls 314
asm_1_278_n_cn_done:		; Hyp.cls 315
            ld bc, (ntc_rampt)      ; the window's page back [316]
            out (c), c		; Hyp.cls 317
            ld sp, (var_hyp_hsp)		; Hyp.cls 318
            jp asm_1_278_n_cn_end		; Hyp.cls 319

; the whole page to the screen (it was cleared): every character that isn't a space
asm_1_278_n_cn_show:		; Hyp.cls 322
            call asm_1_278_n_cn_strip		; Hyp.cls 323
            ld e, 0		; Hyp.cls 324
asm_1_278_n_cn_sh_row:		; Hyp.cls 325
            push de		; Hyp.cls 326
            ld a, e		; Hyp.cls 327
            call asm_1_278_n_cn_rowa            ; HL = row e of the page [328]
            pop de		; Hyp.cls 329
            ld d, 0		; Hyp.cls 330
asm_1_278_n_cn_sh_col:		; Hyp.cls 331
            ld a, (hl)		; Hyp.cls 332
            inc hl		; Hyp.cls 333
            cp 33		; Hyp.cls 334
            jr c, asm_1_278_n_cn_sh_skip		; Hyp.cls 335
            push hl		; Hyp.cls 336
            push de		; Hyp.cls 337
            call asm_1_278_n_cn_glyph		; Hyp.cls 338
            pop de		; Hyp.cls 339
            pop hl		; Hyp.cls 340
asm_1_278_n_cn_sh_skip:		; Hyp.cls 341
            inc d		; Hyp.cls 342
            ld a, (asm_1_278_n_cn_c)		; Hyp.cls 343
            dec a		; Hyp.cls 344
            cp d		; Hyp.cls 345
            jr nc, asm_1_278_n_cn_sh_col		; Hyp.cls 346
            inc e		; Hyp.cls 347
            ld a, (asm_1_278_n_cn_r)		; Hyp.cls 348
            dec a		; Hyp.cls 349
            cp e		; Hyp.cls 350
            jr nc, asm_1_278_n_cn_sh_row		; Hyp.cls 351
            jr asm_1_278_n_cn_done		; Hyp.cls 352

; cn_char: A = one character
asm_1_278_n_cn_char:		; Hyp.cls 355
            ld b, a		; Hyp.cls 356
            ld a, (#7685)           ; in an escape sequence? [357]
            or a		; Hyp.cls 358
            jr nz, asm_1_278_n_cn_esc0		; Hyp.cls 359
            ld a, b		; Hyp.cls 360
            cp 32		; Hyp.cls 361
            jp nc, asm_1_278_n_cn_print		; Hyp.cls 362
            ld hl, asm_1_278_n_cn_pv            ; a control code: the cursor may move (the pointers redone) [363]
            ld (hl), 0		; Hyp.cls 364
            cp 27		; Hyp.cls 365
            jr z, asm_1_278_n_cn_setesc		; Hyp.cls 366
            cp 13		; Hyp.cls 367
            jr z, asm_1_278_n_cn_cr		; Hyp.cls 368
            cp 10		; Hyp.cls 369
            jp z, asm_1_278_n_cn_nl		; Hyp.cls 370
            cp 9		; Hyp.cls 371
            jr z, asm_1_278_n_cn_tab		; Hyp.cls 372
            cp 8		; Hyp.cls 373
            ret nz                  ; other control codes: nothing [374]
            ld a, (#7682)           ; BS: back one (not past the start of the row) [375]
            or a		; Hyp.cls 376
            ret z		; Hyp.cls 377
            dec a		; Hyp.cls 378
            ld (#7682), a		; Hyp.cls 379
            ret		; Hyp.cls 380
asm_1_278_n_cn_tab:                             ; TAB: spaces to the next column of 8 [381]
            ld b, ' '		; Hyp.cls 382
            call asm_1_278_n_cn_print		; Hyp.cls 383
            ld a, (#7682)		; Hyp.cls 384
            and 7		; Hyp.cls 385
            jr nz, asm_1_278_n_cn_tab		; Hyp.cls 386
            ret		; Hyp.cls 387
asm_1_278_n_cn_setesc:		; Hyp.cls 388
            ld a, 1		; Hyp.cls 389
            ld (#7685), a		; Hyp.cls 390
            ret		; Hyp.cls 391
asm_1_278_n_cn_cr:		; Hyp.cls 392
            xor a		; Hyp.cls 393
            ld (#7682), a		; Hyp.cls 394
            ret		; Hyp.cls 395
asm_1_278_n_cn_esc0:		; Hyp.cls 396
            ld hl, asm_1_278_n_cn_pv		; Hyp.cls 397
            ld (hl), 0		; Hyp.cls 398
asm_1_278_n_cn_esc:		; Hyp.cls 399
            cp 1		; Hyp.cls 400
            jr nz, asm_1_278_n_cn_esc2		; Hyp.cls 401
            xor a                   ; ESC x [402]
            ld (#7685), a		; Hyp.cls 403
            ld a, b		; Hyp.cls 404
            cp 'E'		; Hyp.cls 405
            jp z, asm_1_278_n_cn_clear		; Hyp.cls 406
            cp 'H'		; Hyp.cls 407
            jr z, asm_1_278_n_cn_home		; Hyp.cls 408
            cp 'Y'		; Hyp.cls 409
            ret nz		; Hyp.cls 410
            ld a, 2		; Hyp.cls 411
            ld (#7685), a		; Hyp.cls 412
            ret		; Hyp.cls 413
asm_1_278_n_cn_home:		; Hyp.cls 414
            xor a		; Hyp.cls 415
            ld (#7682), a		; Hyp.cls 416
            ld (#7683), a		; Hyp.cls 417
            ret		; Hyp.cls 418
asm_1_278_n_cn_esc2:		; Hyp.cls 419
            cp 2		; Hyp.cls 420
            jr nz, asm_1_278_n_cn_esc3		; Hyp.cls 421
            ld a, b                 ; ESC Y row [422]
            sub 32		; Hyp.cls 423
            ld (#7686), a		; Hyp.cls 424
            ld a, 3		; Hyp.cls 425
            ld (#7685), a		; Hyp.cls 426
            ret		; Hyp.cls 427
asm_1_278_n_cn_esc3:		; Hyp.cls 428
            xor a                   ; ESC Y row col [429]
            ld (#7685), a		; Hyp.cls 430
            ld a, b		; Hyp.cls 431
            sub 32		; Hyp.cls 432
            ld hl, asm_1_278_n_cn_c		; Hyp.cls 433
            cp (hl)		; Hyp.cls 434
            jr c, asm_1_278_n_cn_e3_col		; Hyp.cls 435
            xor a		; Hyp.cls 436
asm_1_278_n_cn_e3_col:		; Hyp.cls 437
            ld (#7682), a		; Hyp.cls 438
            ld a, (#7686)		; Hyp.cls 439
            ld hl, asm_1_278_n_cn_r		; Hyp.cls 440
            cp (hl)		; Hyp.cls 441
            jr c, asm_1_278_n_cn_e3_row		; Hyp.cls 442
            xor a		; Hyp.cls 443
asm_1_278_n_cn_e3_row:		; Hyp.cls 444
            ld (#7683), a		; Hyp.cls 445
            ret		; Hyp.cls 446

; a printable character (B): into the page, on the screen if in front, the column on. The page
; and screen pointers are worked out at the first character after the cursor moved (cn_pv 0),
; then just stepped on - a run of characters costs the 8 screen bytes each, not a sum each
asm_1_278_n_cn_print:		; Hyp.cls 451
            ld a, (asm_1_278_n_cn_pv)		; Hyp.cls 452
            or a		; Hyp.cls 453
            jr nz, asm_1_278_n_cn_pr_have		; Hyp.cls 454
            ld a, (#7683)		; Hyp.cls 455
            call asm_1_278_n_cn_rowa		; Hyp.cls 456
            ld a, (#7682)		; Hyp.cls 457
            ld e, a		; Hyp.cls 458
            ld d, 0		; Hyp.cls 459
            add hl, de		; Hyp.cls 460
            ld (asm_1_278_n_cn_pp), hl		; Hyp.cls 461
            ld a, (asm_1_278_n_cn_front)		; Hyp.cls 462
            or a		; Hyp.cls 463
            jr z, asm_1_278_n_cn_pr_set		; Hyp.cls 464
            ld a, (#7682)		; Hyp.cls 465
            ld d, a		; Hyp.cls 466
            ld a, (#7683)		; Hyp.cls 467
            ld e, a		; Hyp.cls 468
            push bc                 ; (B: the character) [469]
            call asm_1_278_n_cn_scr		; Hyp.cls 470
            pop bc		; Hyp.cls 471
            ld (asm_1_278_n_cn_sp), hl		; Hyp.cls 472
asm_1_278_n_cn_pr_set:		; Hyp.cls 473
            ld a, 1		; Hyp.cls 474
            ld (asm_1_278_n_cn_pv), a		; Hyp.cls 475
asm_1_278_n_cn_pr_have:		; Hyp.cls 476
            ld hl, (asm_1_278_n_cn_pp)          ; the page [477]
            ld (hl), b		; Hyp.cls 478
            inc hl		; Hyp.cls 479
            ld (asm_1_278_n_cn_pp), hl		; Hyp.cls 480
            ld a, (asm_1_278_n_cn_front)		; Hyp.cls 481
            or a		; Hyp.cls 482
            jr z, asm_1_278_n_cn_pr_adv		; Hyp.cls 483
            ld hl, (asm_1_278_n_cn_sp)          ; the screen [484]
            push hl		; Hyp.cls 485
            ld a, b		; Hyp.cls 486
            call asm_1_278_n_cn_glyph8		; Hyp.cls 487
            pop hl		; Hyp.cls 488
            call asm_1_278_n_cn_next		; Hyp.cls 489
            ld (asm_1_278_n_cn_sp), hl		; Hyp.cls 490
asm_1_278_n_cn_pr_adv:		; Hyp.cls 491
            ld hl, #7682		; Hyp.cls 492
            inc (hl)		; Hyp.cls 493
            ld a, (hl)		; Hyp.cls 494
            ld hl, asm_1_278_n_cn_c		; Hyp.cls 495
            cp (hl)		; Hyp.cls 496
            ret c		; Hyp.cls 497
            xor a                   ; past the last column: the next row [498]
            ld (#7682), a		; Hyp.cls 499
            ld (asm_1_278_n_cn_pv), a		; Hyp.cls 500
; a line feed: the next row, or the page (and the screen) scroll
asm_1_278_n_cn_nl:		; Hyp.cls 502
            ld a, (#7683)		; Hyp.cls 503
            inc a		; Hyp.cls 504
            ld hl, asm_1_278_n_cn_r		; Hyp.cls 505
            cp (hl)		; Hyp.cls 506
            jr nc, asm_1_278_n_cn_scroll		; Hyp.cls 507
            ld (#7683), a		; Hyp.cls 508
            ret		; Hyp.cls 509
asm_1_278_n_cn_scroll:		; Hyp.cls 510
            ld a, (#7684)           ; the ring's top row moves on (no copy) [511]
            inc a		; Hyp.cls 512
            cp (hl)		; Hyp.cls 513
            jr c, asm_1_278_n_cn_sc_top		; Hyp.cls 514
            xor a		; Hyp.cls 515
asm_1_278_n_cn_sc_top:		; Hyp.cls 516
            ld (#7684), a		; Hyp.cls 517
            ld a, (asm_1_278_n_cn_r)		; Hyp.cls 518
            dec a		; Hyp.cls 519
            call asm_1_278_n_cn_rowa            ; the new last row cleared [520]
            ld a, (asm_1_278_n_cn_c)		; Hyp.cls 521
            ld b, a		; Hyp.cls 522
asm_1_278_n_cn_sc_cl:		; Hyp.cls 523
            ld (hl), ' '		; Hyp.cls 524
            inc hl		; Hyp.cls 525
            djnz asm_1_278_n_cn_sc_cl		; Hyp.cls 526
            ld a, (asm_1_278_n_cn_front)		; Hyp.cls 527
            or a		; Hyp.cls 528
            ret z		; Hyp.cls 529
            ld hl, (var_hyp_sco)          ; the screen: its start a row on (R12, R13), the new last row [530]
            ld de, (var_hyp_scc)          ; cleared, the status strip again (it went off the top) [531]
            add hl, de		; Hyp.cls 532
            ld a, h		; Hyp.cls 533
            and #07		; Hyp.cls 534
            ld h, a		; Hyp.cls 535
            ld (var_hyp_sco), hl		; Hyp.cls 536
            call asm_1_278_n_cn_crtc		; Hyp.cls 537
            ld a, (asm_1_278_n_cn_r)		; Hyp.cls 538
            dec a		; Hyp.cls 539
            ld e, a		; Hyp.cls 540
            ld d, 0		; Hyp.cls 541
            call asm_1_278_n_cn_scr		; Hyp.cls 542
            ld b, 8		; Hyp.cls 543
asm_1_278_n_cn_sc_ln:		; Hyp.cls 544
            push bc		; Hyp.cls 545
            push hl		; Hyp.cls 546
            ld a, (var_hyp_scc)		; Hyp.cls 547
            ld b, a		; Hyp.cls 548
asm_1_278_n_cn_sc_b:		; Hyp.cls 549
            ld (hl), 0		; Hyp.cls 550
            call asm_1_278_n_cn_next		; Hyp.cls 551
            djnz asm_1_278_n_cn_sc_b		; Hyp.cls 552
            pop hl		; Hyp.cls 553
            ld a, h		; Hyp.cls 554
            add a, 8		; Hyp.cls 555
            ld h, a		; Hyp.cls 556
            pop bc		; Hyp.cls 557
            djnz asm_1_278_n_cn_sc_ln		; Hyp.cls 558
            jp asm_1_278_n_cn_strip		; Hyp.cls 559

; ESC E: the page cleared, column, row and ring back to 0; the screen too if in front (written,
; not copied: the Library: ROM build may have the keyword ROM over it for reads)
asm_1_278_n_cn_clear:		; Hyp.cls 563
            ld hl, #7700		; Hyp.cls 564
            ld de, #7701		; Hyp.cls 565
            ld (hl), ' '		; Hyp.cls 566
            ld bc, 2047		; Hyp.cls 567
            ldir		; Hyp.cls 568
            xor a		; Hyp.cls 569
            ld (#7682), a		; Hyp.cls 570
            ld (#7683), a		; Hyp.cls 571
            ld (#7684), a		; Hyp.cls 572
            ld a, (asm_1_278_n_cn_front)		; Hyp.cls 573
            or a		; Hyp.cls 574
            ret z		; Hyp.cls 575
            ld hl, 0		; Hyp.cls 576
            ld (var_hyp_sco), hl		; Hyp.cls 577
            ld (var_hyp_pon), hl          ; (no pointer on the cleared screen) [578]
            call asm_1_278_n_cn_crtc		; Hyp.cls 579
            xor a		; Hyp.cls 580
            ld hl, #C000		; Hyp.cls 581
            ld c, #40		; Hyp.cls 582
asm_1_278_n_cn_cl_l:		; Hyp.cls 583
            ld b, 0		; Hyp.cls 584
asm_1_278_n_cn_cl_b:		; Hyp.cls 585
            ld (hl), a		; Hyp.cls 586
            inc hl		; Hyp.cls 587
            djnz asm_1_278_n_cn_cl_b		; Hyp.cls 588
            dec c		; Hyp.cls 589
            jr nz, asm_1_278_n_cn_cl_l		; Hyp.cls 590
; cn_strip: MODE S (the screen wider than the console): the status strip's 4 characters (#F68A)
; at the top of the columns right of the console
asm_1_278_n_cn_strip:		; Hyp.cls 593
            ld a, (asm_1_278_n_cn_front)		; Hyp.cls 594
            or a		; Hyp.cls 595
            ret z		; Hyp.cls 596
            ld a, (asm_1_278_n_cn_c)		; Hyp.cls 597
            ld d, a		; Hyp.cls 598
            ld a, (var_hyp_scc)		; Hyp.cls 599
            cp d		; Hyp.cls 600
            ret z		; Hyp.cls 601
            ret c		; Hyp.cls 602
            ld e, 0		; Hyp.cls 603
            ld hl, #768A		; Hyp.cls 604
            ld b, 4		; Hyp.cls 605
asm_1_278_n_cn_st_lp:		; Hyp.cls 606
            ld a, (hl)		; Hyp.cls 607
            push hl		; Hyp.cls 608
            push de		; Hyp.cls 609
            push bc		; Hyp.cls 610
            call asm_1_278_n_cn_glyph		; Hyp.cls 611
            pop bc		; Hyp.cls 612
            pop de		; Hyp.cls 613
            pop hl		; Hyp.cls 614
            inc hl		; Hyp.cls 615
            inc d		; Hyp.cls 616
            djnz asm_1_278_n_cn_st_lp		; Hyp.cls 617
            ret		; Hyp.cls 618

; cn_crtc: the screen's start (sco, bytes) to the CRTC: R12 = #30 + its words' high 2 bits, R13
; the low 8 (#C000, MA10 / MA11 clear: kept within 2K, never the carry into the next 16K)
asm_1_278_n_cn_crtc:		; Hyp.cls 622
            ld hl, (var_hyp_sco)		; Hyp.cls 623
            srl h		; Hyp.cls 624
            rr l		; Hyp.cls 625
            ld a, h		; Hyp.cls 626
            and 3		; Hyp.cls 627
            or #30		; Hyp.cls 628
            ld bc, #BC0C		; Hyp.cls 629
            out (c), c		; Hyp.cls 630
            inc b		; Hyp.cls 631
            out (c), a		; Hyp.cls 632
            ld bc, #BC0D		; Hyp.cls 633
            out (c), c		; Hyp.cls 634
            inc b		; Hyp.cls 635
            out (c), l		; Hyp.cls 636
            ret		; Hyp.cls 637

; cn_rowa: A = row of the screen -> HL = its row in the page ring (#7700 + ((top + A) mod rows)
; * columns)
asm_1_278_n_cn_rowa:		; Hyp.cls 641
            ld hl, #7684		; Hyp.cls 642
            add a, (hl)		; Hyp.cls 643
            ld hl, asm_1_278_n_cn_r		; Hyp.cls 644
            cp (hl)		; Hyp.cls 645
            jr c, asm_1_278_n_cn_ra_in		; Hyp.cls 646
            sub (hl)		; Hyp.cls 647
asm_1_278_n_cn_ra_in:		; Hyp.cls 648
            ld e, a		; Hyp.cls 649
            ld a, (asm_1_278_n_cn_c)		; Hyp.cls 650
            call asm_1_278_n_cn_mul		; Hyp.cls 651
            ld de, #7700		; Hyp.cls 652
            add hl, de		; Hyp.cls 653
            ret		; Hyp.cls 654

; cn_mul: HL = A * E (BC kept; D = 0 after)
asm_1_278_n_cn_mul:		; Hyp.cls 657
            push bc		; Hyp.cls 658
            ld hl, 0		; Hyp.cls 659
            ld d, 0		; Hyp.cls 660
            ld b, 8		; Hyp.cls 661
asm_1_278_n_cn_mu_lp:		; Hyp.cls 662
            add hl, hl		; Hyp.cls 663
            rlca		; Hyp.cls 664
            jr nc, asm_1_278_n_cn_mu_n		; Hyp.cls 665
            add hl, de		; Hyp.cls 666
asm_1_278_n_cn_mu_n:		; Hyp.cls 667
            djnz asm_1_278_n_cn_mu_lp		; Hyp.cls 668
            pop bc		; Hyp.cls 669
            ret		; Hyp.cls 670

; cn_next: HL = the next screen byte: + 1 within its 2K line block (BC kept)
asm_1_278_n_cn_next:		; Hyp.cls 673
            inc l		; Hyp.cls 674
            ret nz		; Hyp.cls 675
            ld a, h		; Hyp.cls 676
            inc a		; Hyp.cls 677
            and #07		; Hyp.cls 678
            push bc		; Hyp.cls 679
            ld c, a		; Hyp.cls 680
            ld a, h		; Hyp.cls 681
            and #F8		; Hyp.cls 682
            or c		; Hyp.cls 683
            ld h, a		; Hyp.cls 684
            pop bc		; Hyp.cls 685
            ret		; Hyp.cls 686

; cn_glyph: A = character, D = column, E = row: drawn (cn_show)
asm_1_278_n_cn_glyph:		; Hyp.cls 689
            push af		; Hyp.cls 690
            call asm_1_278_n_cn_scr		; Hyp.cls 691
            pop af		; Hyp.cls 692
; cn_glyph8: A = character, HL = its screen address: its 8 bytes into screen memory (mode 2, pen
; 1 on paper 0), one per pixel line (#800 apart; unrolled)
asm_1_278_n_cn_glyph8:		; Hyp.cls 695
            sub 32		; Hyp.cls 696
            cp 96		; Hyp.cls 697
            jr c, asm_1_278_n_cn_gl_ok		; Hyp.cls 698
            ld a, '?' - 32		; Hyp.cls 699
asm_1_278_n_cn_gl_ok:		; Hyp.cls 700
            push hl		; Hyp.cls 701
            ld l, a		; Hyp.cls 702
            ld h, 0		; Hyp.cls 703
            add hl, hl		; Hyp.cls 704
            add hl, hl		; Hyp.cls 705
            add hl, hl		; Hyp.cls 706
            ld de, 62208 - #8000   ; (the bank's page 3 in the window: FONT - #C000 + #4000) [707]
            add hl, de		; Hyp.cls 708
            ex de, hl               ; DE = its matrix [709]
            pop hl		; Hyp.cls 710
            ld a, (de)		; Hyp.cls 711
            ld (hl), a		; Hyp.cls 712
            inc de		; Hyp.cls 713
            ld a, h		; Hyp.cls 714
            add a, 8		; Hyp.cls 715
            ld h, a		; Hyp.cls 716
            ld a, (de)		; Hyp.cls 717
            ld (hl), a		; Hyp.cls 718
            inc de		; Hyp.cls 719
            ld a, h		; Hyp.cls 720
            add a, 8		; Hyp.cls 721
            ld h, a		; Hyp.cls 722
            ld a, (de)		; Hyp.cls 723
            ld (hl), a		; Hyp.cls 724
            inc de		; Hyp.cls 725
            ld a, h		; Hyp.cls 726
            add a, 8		; Hyp.cls 727
            ld h, a		; Hyp.cls 728
            ld a, (de)		; Hyp.cls 729
            ld (hl), a		; Hyp.cls 730
            inc de		; Hyp.cls 731
            ld a, h		; Hyp.cls 732
            add a, 8		; Hyp.cls 733
            ld h, a		; Hyp.cls 734
            ld a, (de)		; Hyp.cls 735
            ld (hl), a		; Hyp.cls 736
            inc de		; Hyp.cls 737
            ld a, h		; Hyp.cls 738
            add a, 8		; Hyp.cls 739
            ld h, a		; Hyp.cls 740
            ld a, (de)		; Hyp.cls 741
            ld (hl), a		; Hyp.cls 742
            inc de		; Hyp.cls 743
            ld a, h		; Hyp.cls 744
            add a, 8		; Hyp.cls 745
            ld h, a		; Hyp.cls 746
            ld a, (de)		; Hyp.cls 747
            ld (hl), a		; Hyp.cls 748
            inc de		; Hyp.cls 749
            ld a, h		; Hyp.cls 750
            add a, 8		; Hyp.cls 751
            ld h, a		; Hyp.cls 752
            ld a, (de)		; Hyp.cls 753
            ld (hl), a		; Hyp.cls 754
            ret		; Hyp.cls 755
; cn_scr: D = column, E = row -> HL = the screen address: the screen's start (sco) + row *
; columns (scc) + column, within each 2K line block, at #C000
asm_1_278_n_cn_scr:		; Hyp.cls 758
            push de		; Hyp.cls 759
            ld a, (var_hyp_scc)		; Hyp.cls 760
            call asm_1_278_n_cn_mul		; Hyp.cls 761
            pop de		; Hyp.cls 762
            ld c, d		; Hyp.cls 763
            ld b, 0		; Hyp.cls 764
            add hl, bc		; Hyp.cls 765
            ld bc, (var_hyp_sco)		; Hyp.cls 766
            add hl, bc		; Hyp.cls 767
            ld a, h		; Hyp.cls 768
            and #07		; Hyp.cls 769
            or #C0		; Hyp.cls 770
            ld h, a		; Hyp.cls 771
            ret		; Hyp.cls 772
asm_1_278_n_cn_front:   db 0		; Hyp.cls 773
asm_1_278_n_cn_c:       db 80                   ; the slot's columns, rows [774]
asm_1_278_n_cn_r:       db 25		; Hyp.cls 775
asm_1_278_n_cn_pv:      db 0                    ; cn_pp / cn_sp valid (0: the cursor moved) [776]
asm_1_278_n_cn_pp:      dw 0                    ; the page byte for the next character [777]
asm_1_278_n_cn_sp:      dw 0                    ; its screen address [778]
asm_1_278_n_cn_left:    dw 0		; Hyp.cls 779
asm_1_278_n_cn_ptr:     dw 0		; Hyp.cls 780
asm_1_278_n_cn_end:		; Hyp.cls 781
			ret			; end of #asm

asm_1_789_n:		; #asm, Hyp.cls line 789 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 790
            ld sp, (ntc_csp)		; Hyp.cls 791
            ld bc, (var_hyp_hps)          ; the hypervisor's page in the window: the font [792]
            out (c), c		; Hyp.cls 793
            ld hl, (var_hyp_sco)          ; the screen's start (TOP is shown in MODE 2: 80 columns) [794]
            ld (asm_1_789_n_sy_off), hl		; Hyp.cls 795
            ld hl, (var_hyp_say_p)		; Hyp.cls 796
            ld a, (var_hyp_say_n)		; Hyp.cls 797
            ld b, a		; Hyp.cls 798
            ld a, (var_hyp_say_col)		; Hyp.cls 799
            ld d, a		; Hyp.cls 800
            ld a, (var_hyp_say_row)		; Hyp.cls 801
            ld e, a		; Hyp.cls 802
            inc b		; Hyp.cls 803
asm_1_789_n_sy_lp:		; Hyp.cls 804
            dec b		; Hyp.cls 805
            jr z, asm_1_789_n_sy_done		; Hyp.cls 806
            ld a, d		; Hyp.cls 807
            cp 80		; Hyp.cls 808
            jr nc, asm_1_789_n_sy_done		; Hyp.cls 809
            ld a, (hl)		; Hyp.cls 810
            inc hl		; Hyp.cls 811
            push hl		; Hyp.cls 812
            push bc		; Hyp.cls 813
            push de		; Hyp.cls 814
            sub 32                  ; the character's matrix [815]
            cp 96		; Hyp.cls 816
            jr c, asm_1_789_n_sy_ok		; Hyp.cls 817
            ld a, '?' - 32		; Hyp.cls 818
asm_1_789_n_sy_ok:		; Hyp.cls 819
            ld l, a		; Hyp.cls 820
            ld h, 0		; Hyp.cls 821
            add hl, hl		; Hyp.cls 822
            add hl, hl		; Hyp.cls 823
            add hl, hl		; Hyp.cls 824
            ld bc, #4000 + 4096  ; (the hypervisor's page in the window) [825]
            add hl, bc		; Hyp.cls 826
            push hl		; Hyp.cls 827
            ld l, e                 ; its screen address: start + row * 80 + column, in 2K [828]
            ld h, 0		; Hyp.cls 829
            add hl, hl		; Hyp.cls 830
            add hl, hl		; Hyp.cls 831
            add hl, hl		; Hyp.cls 832
            add hl, hl		; Hyp.cls 833
            push hl		; Hyp.cls 834
            add hl, hl		; Hyp.cls 835
            add hl, hl		; Hyp.cls 836
            pop bc		; Hyp.cls 837
            add hl, bc		; Hyp.cls 838
            ld c, d		; Hyp.cls 839
            ld b, 0		; Hyp.cls 840
            add hl, bc		; Hyp.cls 841
            ld bc, (asm_1_789_n_sy_off)		; Hyp.cls 842
            add hl, bc		; Hyp.cls 843
            ld a, h		; Hyp.cls 844
            and #07		; Hyp.cls 845
            or #C0		; Hyp.cls 846
            ld h, a		; Hyp.cls 847
            pop de		; Hyp.cls 848
            ld b, 8		; Hyp.cls 849
asm_1_789_n_sy_ln:		; Hyp.cls 850
            ld a, (de)		; Hyp.cls 851
            ld (hl), a		; Hyp.cls 852
            inc de		; Hyp.cls 853
            ld a, h		; Hyp.cls 854
            add a, 8		; Hyp.cls 855
            ld h, a		; Hyp.cls 856
            djnz asm_1_789_n_sy_ln		; Hyp.cls 857
            pop de		; Hyp.cls 858
            pop bc		; Hyp.cls 859
            pop hl		; Hyp.cls 860
            inc d		; Hyp.cls 861
            jr asm_1_789_n_sy_lp		; Hyp.cls 862
asm_1_789_n_sy_done:		; Hyp.cls 863
            ld bc, (ntc_rampt)		; Hyp.cls 864
            out (c), c		; Hyp.cls 865
            ld sp, (var_hyp_hsp)		; Hyp.cls 866
            jr asm_1_789_n_sy_end		; Hyp.cls 867
asm_1_789_n_sy_off:     dw 0		; Hyp.cls 868
asm_1_789_n_sy_end:		; Hyp.cls 869
			ret			; end of #asm

asm_1_883_n:		; #asm, Hyp.cls line 883 (normal)
            ld (var_hyp_hsp), sp          ; (the real stack: SP is the thread) [884]
            ld sp, (ntc_csp)		; Hyp.cls 885
            ld a, (var_hyp_scr_m)		; Hyp.cls 886
            cp 6		; Hyp.cls 887
            jr c, asm_1_883_n_sm_ok		; Hyp.cls 888
            xor a		; Hyp.cls 889
asm_1_883_n_sm_ok:		; Hyp.cls 890
            ld l, a                 ; the mode's row of the table (6 bytes) [891]
            add a, a		; Hyp.cls 892
            add a, l		; Hyp.cls 893
            add a, a		; Hyp.cls 894
            ld e, a		; Hyp.cls 895
            ld d, 0		; Hyp.cls 896
            ld hl, asm_1_883_n_sm_tab		; Hyp.cls 897
            add hl, de		; Hyp.cls 898
            ld a, (var_hyp_scr_k)		; Hyp.cls 899
            or a		; Hyp.cls 900
            jr z, asm_1_883_n_sm_cols		; Hyp.cls 901
            dec a		; Hyp.cls 902
            jr z, asm_1_883_n_sm_rows		; Hyp.cls 903
            push hl                 ; 2: the screen [904]
            ld e, (hl)              ; its columns [905]
            ld d, 0		; Hyp.cls 906
            ld (var_hyp_scc), de		; Hyp.cls 907
            srl e		; Hyp.cls 908
            ld (var_hyp_scw), de		; Hyp.cls 909
            ld hl, 0		; Hyp.cls 910
            ld (var_hyp_sco), hl		; Hyp.cls 911
            ld (var_hyp_pon), hl          ; (no pointer on the cleared screen) [912]
            pop hl		; Hyp.cls 913
            inc hl		; Hyp.cls 914
            inc hl                  ; R1, R2, R6, R7 [915]
            di		; Hyp.cls 916
            ld d, 1		; Hyp.cls 917
            call asm_1_883_n_sm_crtc		; Hyp.cls 918
            ld d, 2		; Hyp.cls 919
            call asm_1_883_n_sm_crtc		; Hyp.cls 920
            ld d, 6		; Hyp.cls 921
            call asm_1_883_n_sm_crtc		; Hyp.cls 922
            ld d, 7		; Hyp.cls 923
            call asm_1_883_n_sm_crtc		; Hyp.cls 924
            ld hl, asm_1_883_n_sm_start         ; R12, R13: #C000 [925]
            ld d, 12		; Hyp.cls 926
            call asm_1_883_n_sm_crtc		; Hyp.cls 927
            ld d, 13		; Hyp.cls 928
            call asm_1_883_n_sm_crtc		; Hyp.cls 929
            xor a                   ; cleared (written, not copied: the Library: ROM build may [930]
            ld hl, #C000            ; have the keyword ROM over it for reads) [931]
            ld c, #40		; Hyp.cls 932
asm_1_883_n_sm_cl:		; Hyp.cls 933
            ld b, 0		; Hyp.cls 934
asm_1_883_n_sm_cl1:		; Hyp.cls 935
            ld (hl), a		; Hyp.cls 936
            inc hl		; Hyp.cls 937
            djnz asm_1_883_n_sm_cl1		; Hyp.cls 938
            dec c		; Hyp.cls 939
            jr nz, asm_1_883_n_sm_cl		; Hyp.cls 940
            ld hl, 0		; Hyp.cls 941
            jr asm_1_883_n_sm_res		; Hyp.cls 942
asm_1_883_n_sm_cols:		; Hyp.cls 943
            ld a, (hl)              ; the console's: the screen's, less the status strip's 4 (S) [944]
            inc hl		; Hyp.cls 945
            sub (hl)		; Hyp.cls 946
            jr asm_1_883_n_sm_a		; Hyp.cls 947
asm_1_883_n_sm_rows:		; Hyp.cls 948
            inc hl		; Hyp.cls 949
            inc hl		; Hyp.cls 950
            inc hl		; Hyp.cls 951
            inc hl		; Hyp.cls 952
            ld a, (hl)		; Hyp.cls 953
asm_1_883_n_sm_a:		; Hyp.cls 954
            ld l, a		; Hyp.cls 955
            ld h, 0		; Hyp.cls 956
asm_1_883_n_sm_res:		; Hyp.cls 957
            ld (var_hyp_scr_scr), hl		; Hyp.cls 958
            ld sp, (var_hyp_hsp)		; Hyp.cls 959
            ret                     ; (on with the thread) [960]
asm_1_883_n_sm_crtc:                            ; CRTC register D = (HL), HL on [961]
            ld bc, #BC00		; Hyp.cls 962
            out (c), d		; Hyp.cls 963
            ld b, #BD		; Hyp.cls 964
            ld a, (hl)		; Hyp.cls 965
            out (c), a		; Hyp.cls 966
            inc hl		; Hyp.cls 967
            ret		; Hyp.cls 968
asm_1_883_n_sm_start:   db #30, 0		; Hyp.cls 969
; columns, the status strip's, R1 (words a row), R2 (horizontal sync), R6 (rows), R7 (vertical sync)
asm_1_883_n_sm_tab:     db 80, 0, 40, 46, 25, 30		; Hyp.cls 971
            db 84, 4, 42, 47, 24, 30		; Hyp.cls 972
            db 88, 0, 44, 48, 23, 29		; Hyp.cls 973
            db 96, 0, 48, 50, 21, 28		; Hyp.cls 974
            db 64, 0, 32, 42, 32, 34		; Hyp.cls 975
            db 84, 0, 42, 47, 24, 30		; Hyp.cls 976
			ret			; end of #asm

asm_1_983_n:		; #asm, Hyp.cls line 983 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 984
            ld sp, (ntc_csp)		; Hyp.cls 985
            call #BB42              ; KM GET DELAY: H the start delay, L the repeat [986]
            di		; Hyp.cls 987
            ld a, h		; Hyp.cls 988
            call asm_1_983_n_kr_mul		; Hyp.cls 989
            ld h, a		; Hyp.cls 990
            ld a, l		; Hyp.cls 991
            call asm_1_983_n_kr_mul		; Hyp.cls 992
            ld l, a		; Hyp.cls 993
            call #BB3F              ; KM SET DELAY [994]
            di		; Hyp.cls 995
            ld sp, (var_hyp_hsp)		; Hyp.cls 996
            jr asm_1_983_n_kr_end		; Hyp.cls 997
asm_1_983_n_kr_mul:                             ; A = A x f, 255 at most (0: 256 to the firmware - kept) [998]
            or a		; Hyp.cls 999
            ret z		; Hyp.cls 1000
            push hl		; Hyp.cls 1001
            ld e, a		; Hyp.cls 1002
            ld d, 0		; Hyp.cls 1003
            ld hl, 0		; Hyp.cls 1004
            ld a, (var_hyp_keyrep_f)		; Hyp.cls 1005
            ld b, a		; Hyp.cls 1006
asm_1_983_n_kr_lp:		; Hyp.cls 1007
            add hl, de		; Hyp.cls 1008
            djnz asm_1_983_n_kr_lp		; Hyp.cls 1009
            ld a, h		; Hyp.cls 1010
            or a		; Hyp.cls 1011
            ld a, l		; Hyp.cls 1012
            pop hl		; Hyp.cls 1013
            ret z		; Hyp.cls 1014
            ld a, 255		; Hyp.cls 1015
            ret		; Hyp.cls 1016
asm_1_983_n_kr_end:		; Hyp.cls 1017
			ret			; end of #asm

asm_1_1047_n:		; #asm, Hyp.cls line 1047 (normal)
            ld (var_hyp_sps), sp		; Hyp.cls 1048
            ld sp, (ntc_csp)		; Hyp.cls 1049
            call #B903              ; KL U ROM DISABLE: the task's top 16K, not a ROM (Library: [1050]
            di                      ; ROM has the keyword ROM on), while it runs [1051]
            ld (var_hyp_rrom), a		; Hyp.cls 1052
            ld a, 6		; Hyp.cls 1053
            ld (var_hyp_slc), a		; Hyp.cls 1054
            ld a, 1                 ; from BASIC: it has taken the characters (Collected) [1055]
            ld (var_hyp_rclr), a		; Hyp.cls 1056
asm_1_1047_n_rn_again:		; Hyp.cls 1057
            push ix                 ; IX, IY and [1058]
            push iy		; Hyp.cls 1059
            db #08                  ; ex af, af': the alternate registers kept - the [1060]
            exx                     ; firmware's (BC' = its ROM / mode setting); a task [1061]
            push af                 ; may use them [1062]
            push bc		; Hyp.cls 1063
            push de		; Hyp.cls 1064
            push hl		; Hyp.cls 1065
            exx		; Hyp.cls 1066
            db #08		; Hyp.cls 1067
            ld hl, asm_1_1047_n_rn_back		; Hyp.cls 1068
            push hl                 ; where main RAM carries on [1069]
            ld (ntc_bk_sp), sp		; Hyp.cls 1070
            ld a, (var_hyp_rclr)		; Hyp.cls 1071
            ld e, a                 ; E = 1: the bank empties its characters out (BASIC has them) [1072]
            ld a, (var_hyp_ra)		; Hyp.cls 1073
            ld hl, (var_hyp_rhl)		; Hyp.cls 1074
            ld bc, (var_hyp_run_setting)		; Hyp.cls 1075
            jp ntc_bk_out           ; out (c), c: the task's bank; its #0046 lands it [1076]
asm_1_1047_n_rn_back:		; Hyp.cls 1077
            ld (var_hyp_rcnt), ix         ; the characters it collected (the stubs put them in IX) [1078]
            db #08                  ; ex af, af' [1079]
            exx		; Hyp.cls 1080
            pop hl                  ; the alternate registers back [1081]
            pop de		; Hyp.cls 1082
            pop bc		; Hyp.cls 1083
            pop af		; Hyp.cls 1084
            exx		; Hyp.cls 1085
            db #08		; Hyp.cls 1086
            pop iy		; Hyp.cls 1087
            pop ix		; Hyp.cls 1088
            push af                 ; carry: a BDOS call (A = C, DE = DE) [1089]
            push bc		; Hyp.cls 1090
            ld bc, (ntc_rampt)      ; the window's page back [1091]
            out (c), c		; Hyp.cls 1092
            pop bc		; Hyp.cls 1093
            pop af		; Hyp.cls 1094
            jr c, asm_1_1047_n_rn_far		; Hyp.cls 1095
            rst #38                 ; an interrupt stopped the task: the firmware's handler [1096]
            di		; Hyp.cls 1097
            ld hl, var_hyp_slc            ; a time slice is SLICE interrupts: until it is used up the [1098]
            dec (hl)                ; task carries on straight away (no trip through BASIC) [1099]
            jr z, asm_1_1047_n_rn_int		; Hyp.cls 1100
            ld a, (ntc_isldue)      ; ... unless an interrupt class (the system keys) is due [1101]
            or a		; Hyp.cls 1102
            jr nz, asm_1_1047_n_rn_int		; Hyp.cls 1103
            xor a                   ; its characters stay in its bank (and the count goes on) [1104]
            ld (var_hyp_rclr), a		; Hyp.cls 1105
            jp asm_1_1047_n_rn_again		; Hyp.cls 1106
asm_1_1047_n_rn_int:		; Hyp.cls 1107
            ld hl, 0		; Hyp.cls 1108
            jr asm_1_1047_n_rn_end		; Hyp.cls 1109
asm_1_1047_n_rn_far:		; Hyp.cls 1110
            ld (var_hyp_rfn), a		; Hyp.cls 1111
            ld (var_hyp_rde), de		; Hyp.cls 1112
            ld hl, 1		; Hyp.cls 1113
asm_1_1047_n_rn_end:		; Hyp.cls 1114
            ld (var_hyp_run_run), hl		; Hyp.cls 1115
            ld a, (var_hyp_rrom)		; Hyp.cls 1116
            call #B90C              ; KL ROM RESTORE [1117]
            di		; Hyp.cls 1118
            ld sp, (var_hyp_sps)		; Hyp.cls 1119

			ret			; end of #asm

fn_hyp_info:		; function info (asm keyword), Hyp.cls line 1129
            pop hl		; Hyp.cls 1130
            ld a, (hl)		; Hyp.cls 1131
            ld hl, fn_hyp_info_hi_p0		; Hyp.cls 1132
            or a		; Hyp.cls 1133
            jr z, fn_hyp_info_in_e		; Hyp.cls 1134
            ld hl, fn_hyp_info_hi_p0e - fn_hyp_info_hi_p0		; Hyp.cls 1135
            dec a		; Hyp.cls 1136
            jr z, fn_hyp_info_in_e		; Hyp.cls 1137
            ld hl, fn_hyp_info_sb_img		; Hyp.cls 1138
            dec a		; Hyp.cls 1139
            jr z, fn_hyp_info_in_e		; Hyp.cls 1140
            ld hl, fn_hyp_info_sb_end - fn_hyp_info_sb_start		; Hyp.cls 1141
            dec a		; Hyp.cls 1142
            jr z, fn_hyp_info_in_e		; Hyp.cls 1143
            ld hl, fn_hyp_info_sb_init		; Hyp.cls 1144
fn_hyp_info_in_e:		; Hyp.cls 1145
            ex de, hl		; Hyp.cls 1146
            pop hl		; Hyp.cls 1147
            ld (hl), e		; Hyp.cls 1148
            inc hl		; Hyp.cls 1149
            ld (hl), d		; Hyp.cls 1150
            ret		; Hyp.cls 1151

			ret			; end of #asm

asm_1_1716_n:		; #asm, Hyp.cls line 1716 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 1717
            ld sp, (ntc_csp)		; Hyp.cls 1718
            ld a, (var_hyp_vdu_on)		; Hyp.cls 1719
            or a		; Hyp.cls 1720
            jr z, asm_1_1716_n_vd_off		; Hyp.cls 1721
            call #BB54              ; TXT VDU ENABLE [1722]
            jr asm_1_1716_n_vd_done		; Hyp.cls 1723
asm_1_1716_n_vd_off:		; Hyp.cls 1724
            call #BB57              ; TXT VDU DISABLE [1725]
asm_1_1716_n_vd_done:		; Hyp.cls 1726
            di		; Hyp.cls 1727
            ld sp, (var_hyp_hsp)		; Hyp.cls 1728
			ret			; end of #asm

asm_1_1746_n:		; #asm, Hyp.cls line 1746 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 1747
            ld sp, (ntc_csp)		; Hyp.cls 1748
            ld (asm_1_1746_n_fl_ix), ix		; Hyp.cls 1749
            ld (asm_1_1746_n_fl_iy), iy		; Hyp.cls 1750
            ld a, 255		; Hyp.cls 1751
            ld (asm_1_1746_n_fl_res), a		; Hyp.cls 1752
            ld a, (var_hyp_filecall_slot)		; Hyp.cls 1753
            ld (asm_1_1746_n_fl_slot), a		; Hyp.cls 1754
            ld a, (var_hyp_filecall_f)		; Hyp.cls 1755
            cp 99		; Hyp.cls 1756
            jp z, asm_1_1746_n_fl_inst		; Hyp.cls 1757
            IF NTC_ROMLIB = 0		; Hyp.cls 1758
; the RAM discs' driver (RAMDISC.CYB's, in a page of its own at #4000) sees the call first:
; carry - it was one of its drives' (HL the answer), else on to the disc ROM. It gets IX = the
; call (f, fcb, slot, setting, dma, drive, buf; 100-105: drive = the hypervisor's drive), at
; #4003 a jump to fl_dx (its copies: it runs in the window, so can't switch it itself), at
; #4006 its page's RAM setting
            ASSERT var_hyp_filecall_buf - var_hyp_filecall_f = 12, "FileCall's parameters, one after another"		; Hyp.cls 1764
            ld a, (var_hyp_drs + 1)		; Hyp.cls 1765
            or a		; Hyp.cls 1766
            jr z, asm_1_1746_n_fl_nodrv		; Hyp.cls 1767
            di		; Hyp.cls 1768
            ld a, (var_hyp_filecall_f)		; Hyp.cls 1769
            cp 100		; Hyp.cls 1770
            jr c, asm_1_1746_n_fl_dr_go		; Hyp.cls 1771
            cp 106		; Hyp.cls 1772
            jr nc, asm_1_1746_n_fl_dr_go		; Hyp.cls 1773
            ld hl, (var_hyp_hdr)		; Hyp.cls 1774
            ld (var_hyp_filecall_drive), hl		; Hyp.cls 1775
asm_1_1746_n_fl_dr_go:		; Hyp.cls 1776
            ld bc, (var_hyp_drs)		; Hyp.cls 1777
            out (c), c		; Hyp.cls 1778
            ld hl, asm_1_1746_n_fl_dx		; Hyp.cls 1779
            ld (#4004), hl		; Hyp.cls 1780
            ld hl, (var_hyp_drs)		; Hyp.cls 1781
            ld (#4006), hl		; Hyp.cls 1782
            ld ix, var_hyp_filecall_f		; Hyp.cls 1783
            call #4000		; Hyp.cls 1784
            jr nc, asm_1_1746_n_fl_nodrv		; Hyp.cls 1785
            ld (asm_1_1746_n_fl_res16), hl		; Hyp.cls 1786
            ld a, 1		; Hyp.cls 1787
            ld (asm_1_1746_n_fl_r16), a		; Hyp.cls 1788
            jp asm_1_1746_n_fl_done		; Hyp.cls 1789
; fl_dx - A bytes (1-128) from HL to DE through dxb: IX = HL's RAM setting, IY = DE's (0:
; main RAM, no switch); the driver's page back in the window after. HL, DE on past them
asm_1_1746_n_fl_dx:		; Hyp.cls 1792
            ld (asm_1_1746_n_fl_dxn), a		; Hyp.cls 1793
            push de		; Hyp.cls 1794
            ld de, (var_hyp_dxb)		; Hyp.cls 1795
            push ix		; Hyp.cls 1796
            pop bc		; Hyp.cls 1797
            inc b		; Hyp.cls 1798
            dec b		; Hyp.cls 1799
            jr z, asm_1_1746_n_fl_dx1		; Hyp.cls 1800
            out (c), c		; Hyp.cls 1801
asm_1_1746_n_fl_dx1:		; Hyp.cls 1802
            ld c, a		; Hyp.cls 1803
            ld b, 0		; Hyp.cls 1804
            ldir		; Hyp.cls 1805
            pop de		; Hyp.cls 1806
            push hl		; Hyp.cls 1807
            push iy		; Hyp.cls 1808
            pop bc		; Hyp.cls 1809
            inc b		; Hyp.cls 1810
            dec b		; Hyp.cls 1811
            jr z, asm_1_1746_n_fl_dx2		; Hyp.cls 1812
            out (c), c		; Hyp.cls 1813
asm_1_1746_n_fl_dx2:		; Hyp.cls 1814
            ld hl, (var_hyp_dxb)		; Hyp.cls 1815
            ld a, (asm_1_1746_n_fl_dxn)		; Hyp.cls 1816
            ld c, a		; Hyp.cls 1817
            ld b, 0		; Hyp.cls 1818
            ldir		; Hyp.cls 1819
            pop hl		; Hyp.cls 1820
            ld bc, (var_hyp_drs)		; Hyp.cls 1821
            out (c), c		; Hyp.cls 1822
            ret		; Hyp.cls 1823
asm_1_1746_n_fl_dxn:     db 0		; Hyp.cls 1824
asm_1_1746_n_fl_nodrv:		; Hyp.cls 1825
            ENDIF		; Hyp.cls 1826
            di		; Hyp.cls 1827
            ld bc, (var_hyp_hps)          ; the rest runs in the hypervisor's page (window data from [1828]
            out (c), c              ; #5300: fp_go) [1829]
            call asm_1_1746_n_fp_go		; Hyp.cls 1830
            jp asm_1_1746_n_fl_done		; Hyp.cls 1831
; 99: the window data (#5300 to fp_end: the bank image, the page code) copied from main RAM's
; own #4000-#7FFF (where the file put it) into the hypervisor's page, through buf; once, at the
; start, before anything else uses main RAM's #4000-#7FFF
asm_1_1746_n_fl_inst:		; Hyp.cls 1835
            ld hl, #5300		; Hyp.cls 1836
asm_1_1746_n_fl_in_lp:		; Hyp.cls 1837
            push hl		; Hyp.cls 1838
            ld bc, #7FC0            ; main RAM's own [1839]
            out (c), c		; Hyp.cls 1840
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 1841
            ld bc, 128		; Hyp.cls 1842
            ldir		; Hyp.cls 1843
            ld bc, (var_hyp_hps)		; Hyp.cls 1844
            out (c), c		; Hyp.cls 1845
            pop de		; Hyp.cls 1846
            push de		; Hyp.cls 1847
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 1848
            ld bc, 128		; Hyp.cls 1849
            ldir		; Hyp.cls 1850
            pop hl		; Hyp.cls 1851
            ld bc, 128		; Hyp.cls 1852
            add hl, bc		; Hyp.cls 1853
            ld de, asm_1_1746_n_fp_end		; Hyp.cls 1854
            or a		; Hyp.cls 1855
            sbc hl, de		; Hyp.cls 1856
            add hl, de		; Hyp.cls 1857
            jr c, asm_1_1746_n_fl_in_lp		; Hyp.cls 1858
            xor a		; Hyp.cls 1859
            ld (asm_1_1746_n_fl_res), a		; Hyp.cls 1860
            jp asm_1_1746_n_fl_done		; Hyp.cls 1861
; ---- what the page code can't do itself (it runs in the window): switch the window to a slot's
; page and back. Each puts the hypervisor's page back in the window
asm_1_1746_n_fl_sel:                             ; the slot's page holding HL in the window: HL = there [1864]
            push de		; Hyp.cls 1865
            ld a, h		; Hyp.cls 1866
            rlca		; Hyp.cls 1867
            rlca		; Hyp.cls 1868
            and 3		; Hyp.cls 1869
            add a, 4		; Hyp.cls 1870
            ld e, a		; Hyp.cls 1871
            ld bc, (var_hyp_filecall_setting)		; Hyp.cls 1872
            ld a, c		; Hyp.cls 1873
            and #F8		; Hyp.cls 1874
            or e		; Hyp.cls 1875
            ld c, a		; Hyp.cls 1876
            out (c), c		; Hyp.cls 1877
            ld a, h		; Hyp.cls 1878
            and #3F		; Hyp.cls 1879
            or #40		; Hyp.cls 1880
            ld h, a		; Hyp.cls 1881
            pop de		; Hyp.cls 1882
            ret		; Hyp.cls 1883
asm_1_1746_n_fl_peek:                            ; A = the slot's byte at HL (BC, DE, HL kept) [1884]
            push bc		; Hyp.cls 1885
            push hl		; Hyp.cls 1886
            call asm_1_1746_n_fl_sel		; Hyp.cls 1887
            ld a, (hl)		; Hyp.cls 1888
asm_1_1746_n_fl_pk_back:		; Hyp.cls 1889
            ld bc, (var_hyp_hps)		; Hyp.cls 1890
            out (c), c		; Hyp.cls 1891
            pop hl		; Hyp.cls 1892
            pop bc		; Hyp.cls 1893
            ret		; Hyp.cls 1894
asm_1_1746_n_fl_poke:                            ; the slot's byte at HL = A (BC, DE, HL kept) [1895]
            push bc		; Hyp.cls 1896
            push hl		; Hyp.cls 1897
            push af		; Hyp.cls 1898
            call asm_1_1746_n_fl_sel		; Hyp.cls 1899
            pop af		; Hyp.cls 1900
            ld (hl), a		; Hyp.cls 1901
            jr asm_1_1746_n_fl_pk_back		; Hyp.cls 1902
asm_1_1746_n_fl_toslot:                          ; BC bytes from DE (main RAM) to the slot's HL (all in one of [1903]
            push bc                 ; its pages: fl_fits) [1904]
            call asm_1_1746_n_fl_sel		; Hyp.cls 1905
            pop bc		; Hyp.cls 1906
            ex de, hl		; Hyp.cls 1907
            ldir		; Hyp.cls 1908
            jr asm_1_1746_n_fl_blk_back		; Hyp.cls 1909
asm_1_1746_n_fl_fromslot:                        ; BC bytes from the slot's HL (in one page) to DE (main RAM) [1910]
            push bc		; Hyp.cls 1911
            call asm_1_1746_n_fl_sel		; Hyp.cls 1912
            pop bc		; Hyp.cls 1913
            ldir		; Hyp.cls 1914
asm_1_1746_n_fl_blk_back:		; Hyp.cls 1915
            ld bc, (var_hyp_hps)		; Hyp.cls 1916
            out (c), c		; Hyp.cls 1917
            ret		; Hyp.cls 1918
asm_1_1746_n_fl_done:		; Hyp.cls 1919
            di		; Hyp.cls 1920
            ld bc, (ntc_rampt)      ; the page that was in the window back [1921]
            out (c), c		; Hyp.cls 1922
            ld a, (asm_1_1746_n_fl_res)		; Hyp.cls 1923
            ld l, a		; Hyp.cls 1924
            ld h, 0		; Hyp.cls 1925
            ld a, (asm_1_1746_n_fl_r16)		; Hyp.cls 1926
            or a		; Hyp.cls 1927
            jr z, asm_1_1746_n_fl_d8		; Hyp.cls 1928
            ld hl, (asm_1_1746_n_fl_res16)		; Hyp.cls 1929
            xor a		; Hyp.cls 1930
            ld (asm_1_1746_n_fl_r16), a		; Hyp.cls 1931
asm_1_1746_n_fl_d8:		; Hyp.cls 1932
            ld (var_hyp_filecall_filecall), hl		; Hyp.cls 1933
            ld ix, (asm_1_1746_n_fl_ix)		; Hyp.cls 1934
            ld iy, (asm_1_1746_n_fl_iy)		; Hyp.cls 1935
            ld sp, (var_hyp_hsp)		; Hyp.cls 1936
            jp asm_1_1746_n_fl_exit		; Hyp.cls 1937
asm_1_1746_n_fl_ix:      dw 0		; Hyp.cls 1938
asm_1_1746_n_fl_iy:      dw 0		; Hyp.cls 1939
asm_1_1746_n_fl_res:     db 0		; Hyp.cls 1940
asm_1_1746_n_fl_r16:     db 0                    ; 1: the result is fl_res16 [1941]
asm_1_1746_n_fl_res16:   dw 0		; Hyp.cls 1942
asm_1_1746_n_fl_slot:    db 0		; Hyp.cls 1943
asm_1_1746_n_fl_exit:		; Hyp.cls 2763
			ret			; end of #asm

asm_1_2769_n:		; #asm, Hyp.cls line 2769 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 2770
            ld sp, (ntc_csp)		; Hyp.cls 2771
            ld bc, (var_hyp_hps)          ; (the buffers: the hypervisor's page) [2772]
            out (c), c		; Hyp.cls 2773
            ld a, (var_hyp_fileshut_slot)		; Hyp.cls 2774
            ld b, a		; Hyp.cls 2775
            ld a, (var_hyp_fin)		; Hyp.cls 2776
            cp b		; Hyp.cls 2777
            jr nz, asm_1_2769_n_fs_out		; Hyp.cls 2778
            xor a		; Hyp.cls 2779
            ld (var_hyp_fin), a		; Hyp.cls 2780
            push bc		; Hyp.cls 2781
            call #BC7A              ; CAS IN CLOSE [2782]
            di		; Hyp.cls 2783
            pop bc		; Hyp.cls 2784
asm_1_2769_n_fs_out:		; Hyp.cls 2785
            ld a, (var_hyp_fout)		; Hyp.cls 2786
            cp b		; Hyp.cls 2787
            jr nz, asm_1_2769_n_fs_done		; Hyp.cls 2788
            xor a		; Hyp.cls 2789
            ld (var_hyp_fout), a		; Hyp.cls 2790
            call #BC8F              ; CAS OUT CLOSE [2791]
            di		; Hyp.cls 2792
asm_1_2769_n_fs_done:		; Hyp.cls 2793
            ld bc, (ntc_rampt)		; Hyp.cls 2794
            out (c), c		; Hyp.cls 2795
            ld sp, (var_hyp_hsp)		; Hyp.cls 2796
			ret			; end of #asm

asm_3_21_n:		; #asm, Ent.cls line 21 (normal)
            ld hl, arr_ent_en		; Ent.cls 22
            ld b, 11		; Ent.cls 23
asm_3_21_n_es_sp:		; Ent.cls 24
            ld (hl), ' '		; Ent.cls 25
            inc hl		; Ent.cls 26
            djnz asm_3_21_n_es_sp		; Ent.cls 27
            ld (hl), 0              ; en(11): .COM? [28]
            ld hl, (var_ent_setname_p)		; Ent.cls 29
            ld a, (var_ent_setname_n)		; Ent.cls 30
            ld c, a		; Ent.cls 31
            ld de, arr_ent_en		; Ent.cls 32
            ld b, 8		; Ent.cls 33
asm_3_21_n_es_nm:		; Ent.cls 34
            ld a, c                 ; the name: up to "." (8 characters at most kept) [35]
            or a		; Ent.cls 36
            jr z, asm_3_21_n_es_noext		; Ent.cls 37
            ld a, (hl)		; Ent.cls 38
            inc hl		; Ent.cls 39
            dec c		; Ent.cls 40
            cp '.'		; Ent.cls 41
            jr z, asm_3_21_n_es_ext		; Ent.cls 42
            inc b		; Ent.cls 43
            dec b		; Ent.cls 44
            jr z, asm_3_21_n_es_nm		; Ent.cls 45
            ld (de), a		; Ent.cls 46
            inc de		; Ent.cls 47
            dec b		; Ent.cls 48
            jr asm_3_21_n_es_nm		; Ent.cls 49
asm_3_21_n_es_noext:		; Ent.cls 50
            ld hl, asm_3_21_n_es_com		; Ent.cls 51
            ld c, 3		; Ent.cls 52
asm_3_21_n_es_ext:		; Ent.cls 53
            ld de, arr_ent_en + 8		; Ent.cls 54
            ld b, 3		; Ent.cls 55
asm_3_21_n_es_ex:		; Ent.cls 56
            ld a, c		; Ent.cls 57
            or a		; Ent.cls 58
            jr z, asm_3_21_n_es_chk		; Ent.cls 59
            ld a, (hl)		; Ent.cls 60
            ld (de), a		; Ent.cls 61
            inc hl		; Ent.cls 62
            inc de		; Ent.cls 63
            dec c		; Ent.cls 64
            djnz asm_3_21_n_es_ex		; Ent.cls 65
asm_3_21_n_es_chk:		; Ent.cls 66
            ld hl, arr_ent_en + 8		; Ent.cls 67
            ld de, asm_3_21_n_es_com		; Ent.cls 68
            ld b, 3		; Ent.cls 69
asm_3_21_n_es_ck:		; Ent.cls 70
            ld a, (de)		; Ent.cls 71
            cp (hl)		; Ent.cls 72
            jr nz, asm_3_21_n_es_done		; Ent.cls 73
            inc hl		; Ent.cls 74
            inc de		; Ent.cls 75
            djnz asm_3_21_n_es_ck		; Ent.cls 76
            ld a, 1		; Ent.cls 77
            ld (arr_ent_en + 11), a		; Ent.cls 78
            jr asm_3_21_n_es_done		; Ent.cls 79
asm_3_21_n_es_com:     db "COM"		; Ent.cls 80
asm_3_21_n_es_done:		; Ent.cls 81
			ret			; end of #asm

asm_3_89_n:		; #asm, Ent.cls line 89 (normal)
            ld hl, 0		; Ent.cls 90
            ld (var_ent_length_length), hl		; Ent.cls 91
            ld hl, (var_ent_length_p)		; Ent.cls 92
            ld a, (hl)		; Ent.cls 93
            dec a		; Ent.cls 94
            jr nz, asm_3_89_n_ei_done          ; not a file [95]
            ld de, 12		; Ent.cls 96
            add hl, de		; Ent.cls 97
            ld a, (hl)		; Ent.cls 98
            dec a		; Ent.cls 99
            jr nz, asm_3_89_n_ei_done          ; not a CP/M .COM [100]
            inc hl		; Ent.cls 101
            bit 0, (hl)		; Ent.cls 102
            jr z, asm_3_89_n_ei_done           ; not to run here [103]
            ld hl, (var_ent_length_p)            ; the sum of bytes 0-61 = bytes 62-63 [104]
            ld de, 0		; Ent.cls 105
            ld b, 62		; Ent.cls 106
asm_3_89_n_ei_sum:		; Ent.cls 107
            ld a, (hl)		; Ent.cls 108
            add a, e		; Ent.cls 109
            ld e, a		; Ent.cls 110
            jr nc, asm_3_89_n_ei_s1		; Ent.cls 111
            inc d		; Ent.cls 112
asm_3_89_n_ei_s1:		; Ent.cls 113
            inc hl		; Ent.cls 114
            djnz asm_3_89_n_ei_sum		; Ent.cls 115
            ld a, (hl)		; Ent.cls 116
            cp e		; Ent.cls 117
            jr nz, asm_3_89_n_ei_done		; Ent.cls 118
            inc hl		; Ent.cls 119
            ld a, (hl)		; Ent.cls 120
            cp d		; Ent.cls 121
            jr nz, asm_3_89_n_ei_done		; Ent.cls 122
            ld hl, (var_ent_length_p)            ; the disc name [123]
            inc hl		; Ent.cls 124
            ld de, arr_ent_en		; Ent.cls 125
            ld b, 11		; Ent.cls 126
asm_3_89_n_ei_nm:		; Ent.cls 127
            ld a, (de)		; Ent.cls 128
            cp (hl)		; Ent.cls 129
            jr nz, asm_3_89_n_ei_long		; Ent.cls 130
            inc hl		; Ent.cls 131
            inc de		; Ent.cls 132
            djnz asm_3_89_n_ei_nm		; Ent.cls 133
            jr asm_3_89_n_ei_yes		; Ent.cls 134
asm_3_89_n_ei_long:		; Ent.cls 135
            ld a, (var_ent_length_n)             ; the long name: n characters, then a 0 (or all 38) [136]
            or a		; Ent.cls 137
            jr z, asm_3_89_n_ei_done		; Ent.cls 138
            cp 39		; Ent.cls 139
            jr nc, asm_3_89_n_ei_done		; Ent.cls 140
            ld b, a		; Ent.cls 141
            ld hl, (var_ent_length_p)		; Ent.cls 142
            ld de, 24		; Ent.cls 143
            add hl, de		; Ent.cls 144
            ld de, (var_ent_length_s)		; Ent.cls 145
asm_3_89_n_ei_ln:		; Ent.cls 146
            ld a, (de)		; Ent.cls 147
            cp (hl)		; Ent.cls 148
            jr nz, asm_3_89_n_ei_done		; Ent.cls 149
            inc hl		; Ent.cls 150
            inc de		; Ent.cls 151
            djnz asm_3_89_n_ei_ln		; Ent.cls 152
            ld a, (var_ent_length_n)		; Ent.cls 153
            cp 38		; Ent.cls 154
            jr z, asm_3_89_n_ei_yes		; Ent.cls 155
            ld a, (hl)		; Ent.cls 156
            or a		; Ent.cls 157
            jr nz, asm_3_89_n_ei_done		; Ent.cls 158
asm_3_89_n_ei_yes:		; Ent.cls 159
            ld hl, (var_ent_length_p)		; Ent.cls 160
            ld de, 14		; Ent.cls 161
            add hl, de		; Ent.cls 162
            ld e, (hl)		; Ent.cls 163
            inc hl		; Ent.cls 164
            ld d, (hl)		; Ent.cls 165
            ld hl, #F400            ; more than #0100-#F4FF: not used [166]
            or a		; Ent.cls 167
            sbc hl, de		; Ent.cls 168
            jr c, asm_3_89_n_ei_done		; Ent.cls 169
            ld (var_ent_length_length), de		; Ent.cls 170
asm_3_89_n_ei_done:		; Ent.cls 171
			ret			; end of #asm

asm_3_245_n:		; #asm, Ent.cls line 245 (normal)
            ld hl, (var_ent_discname_p)		; Ent.cls 246
            inc hl		; Ent.cls 247
            ld de, (var_ent_discname_d)		; Ent.cls 248
            ld bc, #0800            ; B: 8 name characters, C: the count [249]
asm_3_245_n_ed_nm:		; Ent.cls 250
            ld a, (hl)		; Ent.cls 251
            inc hl		; Ent.cls 252
            cp ' ' + 1		; Ent.cls 253
            jr c, asm_3_245_n_ed_n1		; Ent.cls 254
            ld (de), a		; Ent.cls 255
            inc de		; Ent.cls 256
            inc c		; Ent.cls 257
asm_3_245_n_ed_n1:		; Ent.cls 258
            djnz asm_3_245_n_ed_nm		; Ent.cls 259
            ld a, (hl)		; Ent.cls 260
            cp ' ' + 1		; Ent.cls 261
            jr c, asm_3_245_n_ed_done		; Ent.cls 262
            ld a, '.'		; Ent.cls 263
            ld (de), a		; Ent.cls 264
            inc de		; Ent.cls 265
            inc c		; Ent.cls 266
            ld b, 3		; Ent.cls 267
asm_3_245_n_ed_ex:		; Ent.cls 268
            ld a, (hl)		; Ent.cls 269
            inc hl		; Ent.cls 270
            cp ' ' + 1		; Ent.cls 271
            jr c, asm_3_245_n_ed_e1		; Ent.cls 272
            ld (de), a		; Ent.cls 273
            inc de		; Ent.cls 274
            inc c		; Ent.cls 275
asm_3_245_n_ed_e1:		; Ent.cls 276
            djnz asm_3_245_n_ed_ex		; Ent.cls 277
asm_3_245_n_ed_done:		; Ent.cls 278
            ld l, c		; Ent.cls 279
            ld h, 0		; Ent.cls 280
            ld (var_ent_discname_discname), hl		; Ent.cls 281
			ret			; end of #asm

fn_keys_down:		; function down (asm keyword), Keys.cls line 44
            pop hl		; Keys.cls 45
            ld e, (hl)		; Keys.cls 46
            inc hl		; Keys.cls 47
            ld d, (hl)		; Keys.cls 48
            ex de, hl		; Keys.cls 49
            jp ntc_kdown		; Keys.cls 50
			ret			; end of #asm

fn_memory_freepages:		; function freepages (asm keyword), Memory.cls line 80
            pop hl		; Memory.cls 81
            ld (mem_res), hl		; Memory.cls 82
            ld hl, mem_freepages		; Memory.cls 83
            jp mem_go		; Memory.cls 84
			ret			; end of #asm

fn_memory_ramsize:		; function ramsize (asm keyword), Memory.cls line 90
            pop hl		; Memory.cls 91
            ld (mem_res), hl		; Memory.cls 92
            ld hl, mem_ramsize		; Memory.cls 93
            jp mem_go		; Memory.cls 94
			ret			; end of #asm

fn_memory_allocpage:		; function allocpage (asm keyword), Memory.cls line 219
            pop hl		; Memory.cls 220
            ld e, (hl)		; Memory.cls 221
            inc hl		; Memory.cls 222
            ld d, (hl)		; Memory.cls 223
            ld (mem_a1), de		; Memory.cls 224
            pop hl		; Memory.cls 225
            ld (mem_res), hl		; Memory.cls 226
            ld hl, mem_allocpage		; Memory.cls 227
            jp mem_go		; Memory.cls 228
			ret			; end of #asm

fn_memory_selectpage:		; function selectpage (asm keyword), Memory.cls line 272
            pop hl		; Memory.cls 273
            ld e, (hl)		; Memory.cls 274
            inc hl		; Memory.cls 275
            ld d, (hl)		; Memory.cls 276
            ld (mem_a1), de		; Memory.cls 277
            pop hl		; Memory.cls 278
            ld (mem_res), hl		; Memory.cls 279
            ld hl, mem_selpage		; Memory.cls 280
            jp mem_go		; Memory.cls 281
			ret			; end of #asm

fn_memory_readbyte:		; function readbyte (asm keyword), Memory.cls line 362
            pop hl		; Memory.cls 363
            ld (mem_a1), hl		; Memory.cls 364
            pop hl		; Memory.cls 365
            ld (mem_res), hl		; Memory.cls 366
            ld hl, mem_readbyte		; Memory.cls 367
            jp mem_go		; Memory.cls 368
			ret			; end of #asm

fn_memory_writebyte:		; sub writebyte (asm keyword), Memory.cls line 384
            pop hl		; Memory.cls 385
            ld (mem_a1), hl		; Memory.cls 386
            pop hl		; Memory.cls 387
            ld e, (hl)		; Memory.cls 388
            inc hl		; Memory.cls 389
            ld d, (hl)		; Memory.cls 390
            ld (mem_a2), de		; Memory.cls 391
            ld hl, mem_writebyte		; Memory.cls 392
            jp mem_go0		; Memory.cls 393
			ret			; end of #asm

fn_memory_writeword:		; sub writeword (asm keyword), Memory.cls line 398
            pop hl		; Memory.cls 399
            ld (mem_a1), hl		; Memory.cls 400
            pop hl		; Memory.cls 401
            ld e, (hl)		; Memory.cls 402
            inc hl		; Memory.cls 403
            ld d, (hl)		; Memory.cls 404
            ld (mem_a2), de		; Memory.cls 405
            ld hl, mem_writeword		; Memory.cls 406
            jp mem_go0		; Memory.cls 407
			ret			; end of #asm

fn_memory_copy:		; function copy (asm keyword), Memory.cls line 415
            pop hl		; Memory.cls 416
            ld (mem_a1), hl		; Memory.cls 417
            pop hl		; Memory.cls 418
            ld (mem_a2), hl		; Memory.cls 419
            pop hl		; Memory.cls 420
            ld e, (hl)		; Memory.cls 421
            inc hl		; Memory.cls 422
            ld d, (hl)		; Memory.cls 423
            ld (mem_a3), de		; Memory.cls 424
            pop hl		; Memory.cls 425
            ld (mem_res), hl		; Memory.cls 426
            ld hl, mem_copy		; Memory.cls 427
            jp mem_go		; Memory.cls 428
			ret			; end of #asm

fn_memory_banks:		; function banks (asm keyword), Memory.cls line 436
            pop hl		; Memory.cls 437
            ld (mem_res), hl		; Memory.cls 438
            ld hl, mem_bankcount		; Memory.cls 439
            jp mem_go		; Memory.cls 440
			ret			; end of #asm

fn_memory_allocbank:		; function allocbank (asm keyword), Memory.cls line 446
            pop hl		; Memory.cls 447
            ld (mem_res), hl		; Memory.cls 448
            ld hl, mem_allocbank		; Memory.cls 449
            jp mem_go		; Memory.cls 450
			ret			; end of #asm


ntc_rg63_e:
			IF ($ < 32768) && (ntc_rg64_e - ntc_rg64 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg64:
; ============================================================
; Variables
; ============================================================

ntc_rg64_e:
			IF ($ < 32768) && (ntc_rg65_e - ntc_rg65 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg65:
var_k:			dw 0
ntc_rg65_e:
			IF ($ < 32768) && (ntc_rg66_e - ntc_rg66 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg66:
var_ns:			dw 0
ntc_rg66_e:
			IF ($ < 32768) && (ntc_rg67_e - ntc_rg67 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg67:
var_i:			dw 0
ntc_rg67_e:
			IF ($ < 32768) && (ntc_rg68_e - ntc_rg68 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg68:
var_hp:			dw 0
ntc_rg68_e:
			IF ($ < 32768) && (ntc_rg69_e - ntc_rg69 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg69:
var_memory_selectpage_selectpage:			dw 0
ntc_rg69_e:
			IF ($ < 32768) && (ntc_rg70_e - ntc_rg70 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg70:
var_hyp_filecall_filecall:			dw 0
ntc_rg70_e:
			IF ($ < 32768) && (ntc_rg71_e - ntc_rg71 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg71:
for3_l:			dw 0
ntc_rg71_e:
			IF ($ < 32768) && (ntc_rg72_e - ntc_rg72 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg72:
var_memory_allocbank_allocbank:			dw 0
ntc_rg72_e:
			IF ($ < 32768) && (ntc_rg73_e - ntc_rg73 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg73:
var_memory_bankpage_bankpage:			dw 0
ntc_rg73_e:
			IF ($ < 32768) && (ntc_rg74_e - ntc_rg74 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg74:
var_hyp_setting_setting:			dw 0
ntc_rg74_e:
			IF ($ < 32768) && (ntc_rg75_e - ntc_rg75 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg75:
			db 82			; capacity
var_ob:			ds 83
ntc_rg75_e:
			IF ($ < 32768) && (ntc_rg76_e - ntc_rg76 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg76:
var_front:			dw 0
ntc_rg76_e:
			IF ($ < 32768) && (ntc_rg77_e - ntc_rg77 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg77:
			db 72			; capacity
var_a:			ds 73
ntc_rg77_e:
			IF ($ < 32768) && (ntc_rg78_e - ntc_rg78 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg78:
var_hk:			dw 0
ntc_rg78_e:
			IF ($ < 32768) && (ntc_rg79_e - ntc_rg79 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg79:
var_hot_take_take:			dw 0
ntc_rg79_e:
			IF ($ < 32768) && (ntc_rg80_e - ntc_rg80 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg80:
var_back:			dw 0
ntc_rg80_e:
			IF ($ < 32768) && (ntc_rg81_e - ntc_rg81 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg81:
var_pk:			dw 0
ntc_rg81_e:
			IF ($ < 32768) && (ntc_rg82_e - ntc_rg82 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg82:
var_wt:			dw 0
ntc_rg82_e:
			IF ($ < 32768) && (ntc_rg83_e - ntc_rg83 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg83:
var_hot_control_control:			dw 0
ntc_rg83_e:
			IF ($ < 32768) && (ntc_rg84_e - ntc_rg84 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg84:
var_running_running:			dw 0
ntc_rg84_e:
			IF ($ < 32768) && (ntc_rg85_e - ntc_rg85 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg85:
var_td:			dw 0
ntc_rg85_e:
			IF ($ < 32768) && (ntc_rg86_e - ntc_rg86 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg86:
var_quit:			dw 0
ntc_rg86_e:
			IF ($ < 32768) && (ntc_rg87_e - ntc_rg87 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg87:
var_hyp_scr_scr:			dw 0
ntc_rg87_e:
			IF ($ < 32768) && (ntc_rg88_e - ntc_rg88 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg88:
var_runs:			dw 0
ntc_rg88_e:
			IF ($ < 32768) && (ntc_rg89_e - ntc_rg89 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg89:
p_running_rs:			dw 0
ntc_rg89_e:
			IF ($ < 32768) && (ntc_rg90_e - ntc_rg90 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg90:
var_running_j:			dw 0
ntc_rg90_e:
			IF ($ < 32768) && (ntc_rg91_e - ntc_rg91 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg91:
for15_l:			dw 0
ntc_rg91_e:
			IF ($ < 32768) && (ntc_rg92_e - ntc_rg92 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg92:
p_ready_rs:			dw 0
ntc_rg92_e:
			IF ($ < 32768) && (ntc_rg93_e - ntc_rg93 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg93:
var_ready_t:			dw 0
ntc_rg93_e:
			IF ($ < 32768) && (ntc_rg94_e - ntc_rg94 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg94:
var_ready_ready:			dw 0
ntc_rg94_e:
			IF ($ < 32768) && (ntc_rg95_e - ntc_rg95 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg95:
p_runnext_rs:			dw 0
ntc_rg95_e:
			IF ($ < 32768) && (ntc_rg96_e - ntc_rg96 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg96:
var_runnext_n:			dw 0
ntc_rg96_e:
			IF ($ < 32768) && (ntc_rg97_e - ntc_rg97 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg97:
var_runnext_t:			dw 0
ntc_rg97_e:
			IF ($ < 32768) && (ntc_rg98_e - ntc_rg98 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg98:
var_runnext_r:			dw 0
ntc_rg98_e:
			IF ($ < 32768) && (ntc_rg99_e - ntc_rg99 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg99:
var_runnext_c:			dw 0
ntc_rg99_e:
			IF ($ < 32768) && (ntc_rg100_e - ntc_rg100 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg100:
var_runnext_q:			dw 0
ntc_rg100_e:
			IF ($ < 32768) && (ntc_rg101_e - ntc_rg101 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg101:
var_fr:			dw 0
ntc_rg101_e:
			IF ($ < 32768) && (ntc_rg102_e - ntc_rg102 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg102:
for23_l:			dw 0
ntc_rg102_e:
			IF ($ < 32768) && (ntc_rg103_e - ntc_rg103 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg103:
var_cur:			dw 0
ntc_rg103_e:
			IF ($ < 32768) && (ntc_rg104_e - ntc_rg104 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg104:
var_hyp_run_run:			dw 0
ntc_rg104_e:
			IF ($ < 32768) && (ntc_rg105_e - ntc_rg105 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg105:
var_far_far:			dw 0, 0
ntc_rg105_e:
			IF ($ < 32768) && (ntc_rg106_e - ntc_rg106 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg106:
var_memory_readbyte_readbyte:			dw 0
ntc_rg106_e:
			IF ($ < 32768) && (ntc_rg107_e - ntc_rg107 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg107:
var_hyp_count_count:			dw 0
ntc_rg107_e:
			IF ($ < 32768) && (ntc_rg108_e - ntc_rg108 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg108:
var_hyp_fn_fn:			dw 0
ntc_rg108_e:
			IF ($ < 32768) && (ntc_rg109_e - ntc_rg109 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg109:
p_bdos_rs:			dw 0
ntc_rg109_e:
			IF ($ < 32768) && (ntc_rg110_e - ntc_rg110 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg110:
var_bdos_t:			dw 0
ntc_rg110_e:
			IF ($ < 32768) && (ntc_rg111_e - ntc_rg111 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg111:
var_bdos_f:			dw 0
ntc_rg111_e:
			IF ($ < 32768) && (ntc_rg112_e - ntc_rg112 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg112:
var_bdos_e:			dw 0
ntc_rg112_e:
			IF ($ < 32768) && (ntc_rg113_e - ntc_rg113 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg113:
var_bdos_a:			dw 0
ntc_rg113_e:
			IF ($ < 32768) && (ntc_rg114_e - ntc_rg114 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg114:
var_hyp_arg_arg:			dw 0
ntc_rg114_e:
			IF ($ < 32768) && (ntc_rg115_e - ntc_rg115 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg115:
var_bdos___sel39:			dw 0
ntc_rg115_e:
			IF ($ < 32768) && (ntc_rg116_e - ntc_rg116 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg116:
var_sys_sys:			dw 0
ntc_rg116_e:
			IF ($ < 32768) && (ntc_rg117_e - ntc_rg117 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg117:
p_sys_rs:			dw 0
ntc_rg117_e:
			IF ($ < 32768) && (ntc_rg118_e - ntc_rg118 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg118:
var_sys_t:			dw 0
ntc_rg118_e:
			IF ($ < 32768) && (ntc_rg119_e - ntc_rg119 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg119:
var_sys_p:			dw 0
ntc_rg119_e:
			IF ($ < 32768) && (ntc_rg120_e - ntc_rg120 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg120:
var_sys_o:			dw 0
ntc_rg120_e:
			IF ($ < 32768) && (ntc_rg121_e - ntc_rg121 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg121:
var_sys_s:			dw 0
ntc_rg121_e:
			IF ($ < 32768) && (ntc_rg122_e - ntc_rg122 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg122:
var_sys_d:			dw 0
ntc_rg122_e:
			IF ($ < 32768) && (ntc_rg123_e - ntc_rg123 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg123:
var_txs:			dw 0
ntc_rg123_e:
			IF ($ < 32768) && (ntc_rg124_e - ntc_rg124 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg124:
			db 60			; capacity
var_en:			ds 61
ntc_rg124_e:
			IF ($ < 32768) && (ntc_rg125_e - ntc_rg125 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg125:
p_puten_rs:			dw 0
ntc_rg125_e:
			IF ($ < 32768) && (ntc_rg126_e - ntc_rg126 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg126:
var_puten_t:			dw 0
ntc_rg126_e:
			IF ($ < 32768) && (ntc_rg127_e - ntc_rg127 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg127:
var_puten_a:			dw 0
ntc_rg127_e:
			IF ($ < 32768) && (ntc_rg128_e - ntc_rg128 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg128:
var_nearp_nearp:			dw 0, 0
ntc_rg128_e:
			IF ($ < 32768) && (ntc_rg129_e - ntc_rg129 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg129:
var_memory_copy_copy:			dw 0
ntc_rg129_e:
			IF ($ < 32768) && (ntc_rg130_e - ntc_rg130 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg130:
p_hopen_rs:			dw 0
ntc_rg130_e:
			IF ($ < 32768) && (ntc_rg131_e - ntc_rg131 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg131:
var_hopen_hopen:			dw 0
ntc_rg131_e:
			IF ($ < 32768) && (ntc_rg132_e - ntc_rg132 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg132:
			db 16			; capacity
var_dn:			ds 17
ntc_rg132_e:
			IF ($ < 32768) && (ntc_rg133_e - ntc_rg133 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg133:
p_hread_rs:			dw 0
ntc_rg133_e:
			IF ($ < 32768) && (ntc_rg134_e - ntc_rg134 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg134:
var_hread_n:			dw 0
ntc_rg134_e:
			IF ($ < 32768) && (ntc_rg135_e - ntc_rg135 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg135:
var_hread_hread:			dw 0
ntc_rg135_e:
			IF ($ < 32768) && (ntc_rg136_e - ntc_rg136 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg136:
p_hclose_rs:			dw 0
ntc_rg136_e:
			IF ($ < 32768) && (ntc_rg137_e - ntc_rg137 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg137:
var_hclose_r:			dw 0
ntc_rg137_e:
			IF ($ < 32768) && (ntc_rg138_e - ntc_rg138 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg138:
p_filesshut_rs:			dw 0
ntc_rg138_e:
			IF ($ < 32768) && (ntc_rg139_e - ntc_rg139 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg139:
var_filesshut_t:			dw 0
ntc_rg139_e:
			IF ($ < 32768) && (ntc_rg140_e - ntc_rg140 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg140:
p_collected_rs:			dw 0
ntc_rg140_e:
			IF ($ < 32768) && (ntc_rg141_e - ntc_rg141 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg141:
var_collected_t:			dw 0
ntc_rg141_e:
			IF ($ < 32768) && (ntc_rg142_e - ntc_rg142 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg142:
var_collected_n:			dw 0
ntc_rg142_e:
			IF ($ < 32768) && (ntc_rg143_e - ntc_rg143 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg143:
p_puts_rs:			dw 0
ntc_rg143_e:
			IF ($ < 32768) && (ntc_rg144_e - ntc_rg144 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg144:
var_puts_t:			dw 0
ntc_rg144_e:
			IF ($ < 32768) && (ntc_rg145_e - ntc_rg145 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg145:
			db 255			; capacity
var_puts_s:			ds 256
ntc_rg145_e:
			IF ($ < 32768) && (ntc_rg146_e - ntc_rg146 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg146:
p_putln_rs:			dw 0
ntc_rg146_e:
			IF ($ < 32768) && (ntc_rg147_e - ntc_rg147 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg147:
var_putln_t:			dw 0
ntc_rg147_e:
			IF ($ < 32768) && (ntc_rg148_e - ntc_rg148 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg148:
			db 255			; capacity
var_putln_s:			ds 256
ntc_rg148_e:
			IF ($ < 32768) && (ntc_rg149_e - ntc_rg149 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg149:
p_putc_rs:			dw 0
ntc_rg149_e:
			IF ($ < 32768) && (ntc_rg150_e - ntc_rg150 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg150:
var_putc_t:			dw 0
ntc_rg150_e:
			IF ($ < 32768) && (ntc_rg151_e - ntc_rg151 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg151:
var_putc_c:			dw 0
ntc_rg151_e:
			IF ($ < 32768) && (ntc_rg152_e - ntc_rg152 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg152:
p_nearp_rs:			dw 0
ntc_rg152_e:
			IF ($ < 32768) && (ntc_rg153_e - ntc_rg153 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg153:
var_nearp_p:			dw 0
ntc_rg153_e:
			IF ($ < 32768) && (ntc_rg154_e - ntc_rg154 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg154:
p_far_rs:			dw 0
ntc_rg154_e:
			IF ($ < 32768) && (ntc_rg155_e - ntc_rg155 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg155:
var_far_t:			dw 0
ntc_rg155_e:
			IF ($ < 32768) && (ntc_rg156_e - ntc_rg156 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg156:
var_far_a:			dw 0
ntc_rg156_e:
			IF ($ < 32768) && (ntc_rg157_e - ntc_rg157 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg157:
p_clst_rs:			dw 0
ntc_rg157_e:
			IF ($ < 32768) && (ntc_rg158_e - ntc_rg158 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg158:
var_clst_t:			dw 0
ntc_rg158_e:
			IF ($ < 32768) && (ntc_rg159_e - ntc_rg159 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg159:
p_tofront_rs:			dw 0
ntc_rg159_e:
			IF ($ < 32768) && (ntc_rg160_e - ntc_rg160 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg160:
var_tofront_t:			dw 0
ntc_rg160_e:
			IF ($ < 32768) && (ntc_rg161_e - ntc_rg161 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg161:
var_tofront_r:			dw 0
ntc_rg161_e:
			IF ($ < 32768) && (ntc_rg162_e - ntc_rg162 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg162:
p_setmode_rs:			dw 0
ntc_rg162_e:
			IF ($ < 32768) && (ntc_rg163_e - ntc_rg163 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg163:
var_setmode_t:			dw 0
ntc_rg163_e:
			IF ($ < 32768) && (ntc_rg164_e - ntc_rg164 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg164:
var_setmode_m:			dw 0
ntc_rg164_e:
			IF ($ < 32768) && (ntc_rg165_e - ntc_rg165 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg165:
var_setmode_r:			dw 0
ntc_rg165_e:
			IF ($ < 32768) && (ntc_rg166_e - ntc_rg166 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg166:
			db 255			; capacity
var_n_n:			ds 256
ntc_rg166_e:
			IF ($ < 32768) && (ntc_rg167_e - ntc_rg167 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg167:
p_showtop_rs:			dw 0
ntc_rg167_e:
			IF ($ < 32768) && (ntc_rg168_e - ntc_rg168 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg168:
var_showtop_j:			dw 0
ntc_rg168_e:
			IF ($ < 32768) && (ntc_rg169_e - ntc_rg169 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg169:
p_toplines_rs:			dw 0
ntc_rg169_e:
			IF ($ < 32768) && (ntc_rg170_e - ntc_rg170 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg170:
var_toplines_mark:			dw 0
ntc_rg170_e:
			IF ($ < 32768) && (ntc_rg171_e - ntc_rg171 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg171:
var_toplines_keys:			dw 0
ntc_rg171_e:
			IF ($ < 32768) && (ntc_rg172_e - ntc_rg172 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg172:
var_toplines_j:			dw 0
ntc_rg172_e:
			IF ($ < 32768) && (ntc_rg173_e - ntc_rg173 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg173:
			db 14			; capacity
var_toplines_s:			ds 15
ntc_rg173_e:
			IF ($ < 32768) && (ntc_rg174_e - ntc_rg174 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg174:
var_txn:			dw 0
ntc_rg174_e:
			IF ($ < 32768) && (ntc_rg175_e - ntc_rg175 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg175:
			db 255			; capacity
var_sk_sk:			ds 256
ntc_rg175_e:
			IF ($ < 32768) && (ntc_rg176_e - ntc_rg176 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg176:
for60_l:			dw 0
ntc_rg176_e:
			IF ($ < 32768) && (ntc_rg177_e - ntc_rg177 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg177:
var_ld:			dw 0
ntc_rg177_e:
			IF ($ < 32768) && (ntc_rg178_e - ntc_rg178 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg178:
var_rate_rate:			dw 0
ntc_rg178_e:
			IF ($ < 32768) && (ntc_rg179_e - ntc_rg179 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg179:
			db 255			; capacity
var_pad_pad:			ds 256
ntc_rg179_e:
			IF ($ < 32768) && (ntc_rg180_e - ntc_rg180 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg180:
p_totals_rs:			dw 0
ntc_rg180_e:
			IF ($ < 32768) && (ntc_rg181_e - ntc_rg181 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg181:
var_memory_ramsize_ramsize:			dw 0
ntc_rg181_e:
			IF ($ < 32768) && (ntc_rg182_e - ntc_rg182 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg182:
var_memory_freepages_freepages:			dw 0
ntc_rg182_e:
			IF ($ < 32768) && (ntc_rg183_e - ntc_rg183 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg183:
p_topadd_rs:			dw 0
ntc_rg183_e:
			IF ($ < 32768) && (ntc_rg184_e - ntc_rg184 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg184:
			db 255			; capacity
var_topadd_s:			ds 256
ntc_rg184_e:
			IF ($ < 32768) && (ntc_rg185_e - ntc_rg185 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg185:
p_roll_rs:			dw 0
ntc_rg185_e:
			IF ($ < 32768) && (ntc_rg186_e - ntc_rg186 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg186:
var_roll_j:			dw 0
ntc_rg186_e:
			IF ($ < 32768) && (ntc_rg187_e - ntc_rg187 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg187:
for65_l:			dw 0
ntc_rg187_e:
			IF ($ < 32768) && (ntc_rg188_e - ntc_rg188 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg188:
p_pad_rs:			dw 0
ntc_rg188_e:
			IF ($ < 32768) && (ntc_rg189_e - ntc_rg189 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg189:
var_pad_v:			dw 0
ntc_rg189_e:
			IF ($ < 32768) && (ntc_rg190_e - ntc_rg190 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg190:
p_rate_rs:			dw 0
ntc_rg190_e:
			IF ($ < 32768) && (ntc_rg191_e - ntc_rg191 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg191:
var_rate_n:			dw 0
ntc_rg191_e:
			IF ($ < 32768) && (ntc_rg192_e - ntc_rg192 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg192:
var_rate_d:			dw 0
ntc_rg192_e:
			IF ($ < 32768) && (ntc_rg193_e - ntc_rg193 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg193:
p_install_rs:			dw 0
ntc_rg193_e:
			IF ($ < 32768) && (ntc_rg194_e - ntc_rg194 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg194:
var_install_t:			dw 0
ntc_rg194_e:
			IF ($ < 32768) && (ntc_rg195_e - ntc_rg195 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg195:
var_install_p:			dw 0
ntc_rg195_e:
			IF ($ < 32768) && (ntc_rg196_e - ntc_rg196 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg196:
var_install_n:			dw 0
ntc_rg196_e:
			IF ($ < 32768) && (ntc_rg197_e - ntc_rg197 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg197:
var_hyp_farptr_farptr:			dw 0, 0
ntc_rg197_e:
			IF ($ < 32768) && (ntc_rg198_e - ntc_rg198 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg198:
p_resetslot_rs:			dw 0
ntc_rg198_e:
			IF ($ < 32768) && (ntc_rg199_e - ntc_rg199 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg199:
var_resetslot_s:			dw 0
ntc_rg199_e:
			IF ($ < 32768) && (ntc_rg200_e - ntc_rg200 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg200:
p_openslot_rs:			dw 0
ntc_rg200_e:
			IF ($ < 32768) && (ntc_rg201_e - ntc_rg201 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg201:
var_openslot_t:			dw 0
ntc_rg201_e:
			IF ($ < 32768) && (ntc_rg202_e - ntc_rg202 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg202:
p_sk_rs:			dw 0
ntc_rg202_e:
			IF ($ < 32768) && (ntc_rg203_e - ntc_rg203 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg203:
p_getnm_rs:			dw 0
ntc_rg203_e:
			IF ($ < 32768) && (ntc_rg204_e - ntc_rg204 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg204:
var_getnm_t:			dw 0
ntc_rg204_e:
			IF ($ < 32768) && (ntc_rg205_e - ntc_rg205 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg205:
var_getnm_n:			dw 0
ntc_rg205_e:
			IF ($ < 32768) && (ntc_rg206_e - ntc_rg206 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg206:
p_n_rs:			dw 0
ntc_rg206_e:
			IF ($ < 32768) && (ntc_rg207_e - ntc_rg207 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg207:
var_n_v:			dw 0
ntc_rg207_e:
			IF ($ < 32768) && (ntc_rg208_e - ntc_rg208 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg208:
p_prompt_rs:			dw 0
ntc_rg208_e:
			IF ($ < 32768) && (ntc_rg209_e - ntc_rg209 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg209:
var_prompt_t:			dw 0
ntc_rg209_e:
			IF ($ < 32768) && (ntc_rg210_e - ntc_rg210 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg210:
p_keyin_rs:			dw 0
ntc_rg210_e:
			IF ($ < 32768) && (ntc_rg211_e - ntc_rg211 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg211:
var_keyin_k:			dw 0
ntc_rg211_e:
			IF ($ < 32768) && (ntc_rg212_e - ntc_rg212 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg212:
var_keyin_t:			dw 0
ntc_rg212_e:
			IF ($ < 32768) && (ntc_rg213_e - ntc_rg213 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg213:
var_keyin_n:			dw 0
ntc_rg213_e:
			IF ($ < 32768) && (ntc_rg214_e - ntc_rg214 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg214:
p_command_rs:			dw 0
ntc_rg214_e:
			IF ($ < 32768) && (ntc_rg215_e - ntc_rg215 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg215:
var_command_t:			dw 0
ntc_rg215_e:
			IF ($ < 32768) && (ntc_rg216_e - ntc_rg216 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg216:
			db 72			; capacity
var_command_c:			ds 73
ntc_rg216_e:
			IF ($ < 32768) && (ntc_rg217_e - ntc_rg217 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg217:
var_command_p:			dw 0
ntc_rg217_e:
			IF ($ < 32768) && (ntc_rg218_e - ntc_rg218 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg218:
var_command_s:			dw 0
ntc_rg218_e:
			IF ($ < 32768) && (ntc_rg219_e - ntc_rg219 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg219:
			db 72			; capacity
var_b:			ds 73
ntc_rg219_e:
			IF ($ < 32768) && (ntc_rg220_e - ntc_rg220 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg220:
			db 255			; capacity
var_command___sel78:			ds 256
ntc_rg220_e:
			IF ($ < 32768) && (ntc_rg221_e - ntc_rg221 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg221:
var_bare:			dw 0
ntc_rg221_e:
			IF ($ < 32768) && (ntc_rg222_e - ntc_rg222 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg222:
p_starttask_rs:			dw 0
ntc_rg222_e:
			IF ($ < 32768) && (ntc_rg223_e - ntc_rg223 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg223:
var_starttask_t:			dw 0
ntc_rg223_e:
			IF ($ < 32768) && (ntc_rg224_e - ntc_rg224 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg224:
var_starttask_s:			dw 0
ntc_rg224_e:
			IF ($ < 32768) && (ntc_rg225_e - ntc_rg225 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg225:
var_starttask_h:			dw 0
ntc_rg225_e:
			IF ($ < 32768) && (ntc_rg226_e - ntc_rg226 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg226:
var_starttask_n:			dw 0
ntc_rg226_e:
			IF ($ < 32768) && (ntc_rg227_e - ntc_rg227 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg227:
var_starttask_rest:			dw 0
ntc_rg227_e:
			IF ($ < 32768) && (ntc_rg228_e - ntc_rg228 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg228:
var_starttask_com:			dw 0
ntc_rg228_e:
			IF ($ < 32768) && (ntc_rg229_e - ntc_rg229 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg229:
			db 72			; capacity
var_starttask_w:			ds 73
ntc_rg229_e:
			IF ($ < 32768) && (ntc_rg230_e - ntc_rg230 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg230:
var_starttask_d:			dw 0
ntc_rg230_e:
			IF ($ < 32768) && (ntc_rg231_e - ntc_rg231 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg231:
var_findcom_findcom:			dw 0
ntc_rg231_e:
			IF ($ < 32768) && (ntc_rg232_e - ntc_rg232 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg232:
var_ent_discname_discname:			dw 0
ntc_rg232_e:
			IF ($ < 32768) && (ntc_rg233_e - ntc_rg233 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg233:
var_hyp_info_info:			dw 0
ntc_rg233_e:
			IF ($ < 32768) && (ntc_rg234_e - ntc_rg234 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg234:
p_notfound_rs:			dw 0
ntc_rg234_e:
			IF ($ < 32768) && (ntc_rg235_e - ntc_rg235 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg235:
var_notfound_t:			dw 0
ntc_rg235_e:
			IF ($ < 32768) && (ntc_rg236_e - ntc_rg236 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg236:
p_findcom_rs:			dw 0
ntc_rg236_e:
			IF ($ < 32768) && (ntc_rg237_e - ntc_rg237 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg237:
var_findcom_r:			dw 0
ntc_rg237_e:
			IF ($ < 32768) && (ntc_rg238_e - ntc_rg238 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg238:
var_findent_findent:			dw 0
ntc_rg238_e:
			IF ($ < 32768) && (ntc_rg239_e - ntc_rg239 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg239:
p_findent_rs:			dw 0
ntc_rg239_e:
			IF ($ < 32768) && (ntc_rg240_e - ntc_rg240 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg240:
var_findent_r:			dw 0
ntc_rg240_e:
			IF ($ < 32768) && (ntc_rg241_e - ntc_rg241 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg241:
var_ent_length_length:			dw 0
ntc_rg241_e:
			IF ($ < 32768) && (ntc_rg242_e - ntc_rg242 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg242:
p_endtask_rs:			dw 0
ntc_rg242_e:
			IF ($ < 32768) && (ntc_rg243_e - ntc_rg243 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg243:
var_endtask_t:			dw 0
ntc_rg243_e:
			IF ($ < 32768) && (ntc_rg244_e - ntc_rg244 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg244:
var_endtask_c:			dw 0
ntc_rg244_e:
			IF ($ < 32768) && (ntc_rg245_e - ntc_rg245 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg245:
var_hyp_hps:			dw 0
ntc_rg245_e:
			IF ($ < 32768) && (ntc_rg246_e - ntc_rg246 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg246:
var_hyp_hsp:			dw 0
ntc_rg246_e:
			IF ($ < 32768) && (ntc_rg247_e - ntc_rg247 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg247:
p_hyp_con_rs:			dw 0
ntc_rg247_e:
			IF ($ < 32768) && (ntc_rg248_e - ntc_rg248 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg248:
var_hyp_con_pg:			dw 0
ntc_rg248_e:
			IF ($ < 32768) && (ntc_rg249_e - ntc_rg249 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg249:
var_hyp_con_src:			dw 0
ntc_rg249_e:
			IF ($ < 32768) && (ntc_rg250_e - ntc_rg250 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg250:
var_hyp_con_n:			dw 0
ntc_rg250_e:
			IF ($ < 32768) && (ntc_rg251_e - ntc_rg251 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg251:
var_hyp_con_front:			dw 0
ntc_rg251_e:
			IF ($ < 32768) && (ntc_rg252_e - ntc_rg252 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg252:
var_hyp_sco:			dw 0
ntc_rg252_e:
			IF ($ < 32768) && (ntc_rg253_e - ntc_rg253 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg253:
var_hyp_scc:			dw 0
ntc_rg253_e:
			IF ($ < 32768) && (ntc_rg254_e - ntc_rg254 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg254:
var_hyp_pon:			dw 0
ntc_rg254_e:
			IF ($ < 32768) && (ntc_rg255_e - ntc_rg255 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg255:
p_hyp_say_rs:			dw 0
ntc_rg255_e:
			IF ($ < 32768) && (ntc_rg256_e - ntc_rg256 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg256:
var_hyp_say_p:			dw 0
ntc_rg256_e:
			IF ($ < 32768) && (ntc_rg257_e - ntc_rg257 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg257:
var_hyp_say_n:			dw 0
ntc_rg257_e:
			IF ($ < 32768) && (ntc_rg258_e - ntc_rg258 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg258:
var_hyp_say_col:			dw 0
ntc_rg258_e:
			IF ($ < 32768) && (ntc_rg259_e - ntc_rg259 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg259:
var_hyp_say_row:			dw 0
ntc_rg259_e:
			IF ($ < 32768) && (ntc_rg260_e - ntc_rg260 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg260:
p_hyp_scr_rs:			dw 0
ntc_rg260_e:
			IF ($ < 32768) && (ntc_rg261_e - ntc_rg261 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg261:
var_hyp_scr_m:			dw 0
ntc_rg261_e:
			IF ($ < 32768) && (ntc_rg262_e - ntc_rg262 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg262:
var_hyp_scr_k:			dw 0
ntc_rg262_e:
			IF ($ < 32768) && (ntc_rg263_e - ntc_rg263 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg263:
var_hyp_scw:			dw 0
ntc_rg263_e:
			IF ($ < 32768) && (ntc_rg264_e - ntc_rg264 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg264:
p_hyp_keyrep_rs:			dw 0
ntc_rg264_e:
			IF ($ < 32768) && (ntc_rg265_e - ntc_rg265 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg265:
var_hyp_keyrep_f:			dw 0
ntc_rg265_e:
			IF ($ < 32768) && (ntc_rg266_e - ntc_rg266 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg266:
p_hyp_show_rs:			dw 0
ntc_rg266_e:
			IF ($ < 32768) && (ntc_rg267_e - ntc_rg267 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg267:
var_hyp_show_pg:			dw 0
ntc_rg267_e:
			IF ($ < 32768) && (ntc_rg268_e - ntc_rg268 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg268:
p_hyp_reply_rs:			dw 0
ntc_rg268_e:
			IF ($ < 32768) && (ntc_rg269_e - ntc_rg269 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg269:
var_hyp_reply_a:			dw 0
ntc_rg269_e:
			IF ($ < 32768) && (ntc_rg270_e - ntc_rg270 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg270:
var_hyp_reply_hl:			dw 0
ntc_rg270_e:
			IF ($ < 32768) && (ntc_rg271_e - ntc_rg271 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg271:
var_hyp_ra:			dw 0
ntc_rg271_e:
			IF ($ < 32768) && (ntc_rg272_e - ntc_rg272 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg272:
var_hyp_rhl:			dw 0
ntc_rg272_e:
			IF ($ < 32768) && (ntc_rg273_e - ntc_rg273 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg273:
p_hyp_fn_rs:			dw 0
ntc_rg273_e:
			IF ($ < 32768) && (ntc_rg274_e - ntc_rg274 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg274:
var_hyp_rfn:			dw 0
ntc_rg274_e:
			IF ($ < 32768) && (ntc_rg275_e - ntc_rg275 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg275:
p_hyp_arg_rs:			dw 0
ntc_rg275_e:
			IF ($ < 32768) && (ntc_rg276_e - ntc_rg276 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg276:
var_hyp_rde:			dw 0
ntc_rg276_e:
			IF ($ < 32768) && (ntc_rg277_e - ntc_rg277 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg277:
p_hyp_count_rs:			dw 0
ntc_rg277_e:
			IF ($ < 32768) && (ntc_rg278_e - ntc_rg278 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg278:
var_hyp_rcnt:			dw 0
ntc_rg278_e:
			IF ($ < 32768) && (ntc_rg279_e - ntc_rg279 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg279:
p_hyp_run_rs:			dw 0
ntc_rg279_e:
			IF ($ < 32768) && (ntc_rg280_e - ntc_rg280 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg280:
var_hyp_run_setting:			dw 0
ntc_rg280_e:
			IF ($ < 32768) && (ntc_rg281_e - ntc_rg281 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg281:
var_hyp_sps:			dw 0
ntc_rg281_e:
			IF ($ < 32768) && (ntc_rg282_e - ntc_rg282 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg282:
var_hyp_rrom:			dw 0
ntc_rg282_e:
			IF ($ < 32768) && (ntc_rg283_e - ntc_rg283 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg283:
var_hyp_slc:			dw 0
ntc_rg283_e:
			IF ($ < 32768) && (ntc_rg284_e - ntc_rg284 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg284:
var_hyp_rclr:			dw 0
ntc_rg284_e:
			IF ($ < 32768) && (ntc_rg285_e - ntc_rg285 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg285:
p_hyp_vdu_rs:			dw 0
ntc_rg285_e:
			IF ($ < 32768) && (ntc_rg286_e - ntc_rg286 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg286:
var_hyp_vdu_on:			dw 0
ntc_rg286_e:
			IF ($ < 32768) && (ntc_rg287_e - ntc_rg287 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg287:
p_hyp_filecall_rs:			dw 0
ntc_rg287_e:
			IF ($ < 32768) && (ntc_rg288_e - ntc_rg288 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg288:
var_hyp_filecall_f:			dw 0
ntc_rg288_e:
			IF ($ < 32768) && (ntc_rg289_e - ntc_rg289 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg289:
var_hyp_filecall_fcb:			dw 0
ntc_rg289_e:
			IF ($ < 32768) && (ntc_rg290_e - ntc_rg290 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg290:
var_hyp_filecall_slot:			dw 0
ntc_rg290_e:
			IF ($ < 32768) && (ntc_rg291_e - ntc_rg291 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg291:
var_hyp_filecall_setting:			dw 0
ntc_rg291_e:
			IF ($ < 32768) && (ntc_rg292_e - ntc_rg292 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg292:
var_hyp_filecall_dma:			dw 0
ntc_rg292_e:
			IF ($ < 32768) && (ntc_rg293_e - ntc_rg293 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg293:
var_hyp_filecall_drive:			dw 0
ntc_rg293_e:
			IF ($ < 32768) && (ntc_rg294_e - ntc_rg294 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg294:
var_hyp_filecall_buf:			dw 0
ntc_rg294_e:
			IF ($ < 32768) && (ntc_rg295_e - ntc_rg295 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg295:
var_hyp_drs:			dw 0
ntc_rg295_e:
			IF ($ < 32768) && (ntc_rg296_e - ntc_rg296 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg296:
var_hyp_hdr:			dw 0
ntc_rg296_e:
			IF ($ < 32768) && (ntc_rg297_e - ntc_rg297 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg297:
var_hyp_dxb:			dw 0
ntc_rg297_e:
			IF ($ < 32768) && (ntc_rg298_e - ntc_rg298 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg298:
var_hyp_fin:			dw 0
ntc_rg298_e:
			IF ($ < 32768) && (ntc_rg299_e - ntc_rg299 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg299:
var_hyp_fout:			dw 0
ntc_rg299_e:
			IF ($ < 32768) && (ntc_rg300_e - ntc_rg300 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg300:
p_hyp_fileshut_rs:			dw 0
ntc_rg300_e:
			IF ($ < 32768) && (ntc_rg301_e - ntc_rg301 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg301:
var_hyp_fileshut_slot:			dw 0
ntc_rg301_e:
			IF ($ < 32768) && (ntc_rg302_e - ntc_rg302 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg302:
p_hot_slots_rs:			dw 0
ntc_rg302_e:
			IF ($ < 32768) && (ntc_rg303_e - ntc_rg303 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg303:
var_hot_slots_n:			dw 0
ntc_rg303_e:
			IF ($ < 32768) && (ntc_rg304_e - ntc_rg304 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg304:
var_hot_ns:			dw 0
ntc_rg304_e:
			IF ($ < 32768) && (ntc_rg305_e - ntc_rg305 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg305:
p_hot_tick_rs:			dw 0
ntc_rg305_e:
			IF ($ < 32768) && (ntc_rg306_e - ntc_rg306 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg306:
var_hot_tick_k:			dw 0
ntc_rg306_e:
			IF ($ < 32768) && (ntc_rg307_e - ntc_rg307 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg307:
var_hot_ctl:			dw 0
ntc_rg307_e:
			IF ($ < 32768) && (ntc_rg308_e - ntc_rg308 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg308:
var_keys_down_down:			dw 0
ntc_rg308_e:
			IF ($ < 32768) && (ntc_rg309_e - ntc_rg309 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg309:
var_hot_last:			dw 0
ntc_rg309_e:
			IF ($ < 32768) && (ntc_rg310_e - ntc_rg310 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg310:
var_hot_one:			dw 0
ntc_rg310_e:
			IF ($ < 32768) && (ntc_rg311_e - ntc_rg311 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg311:
var_hot_pend:			dw 0
ntc_rg311_e:
			IF ($ < 32768) && (ntc_rg312_e - ntc_rg312 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg312:
var_hot_age:			dw 0
ntc_rg312_e:
			IF ($ < 32768) && (ntc_rg313_e - ntc_rg313 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg313:
p_hot_take_rs:			dw 0
ntc_rg313_e:
			IF ($ < 32768) && (ntc_rg314_e - ntc_rg314 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg314:
p_hot_control_rs:			dw 0
ntc_rg314_e:
			IF ($ < 32768) && (ntc_rg315_e - ntc_rg315 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg315:
p_ent_setname_rs:			dw 0
ntc_rg315_e:
			IF ($ < 32768) && (ntc_rg316_e - ntc_rg316 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg316:
var_ent_setname_p:			dw 0
ntc_rg316_e:
			IF ($ < 32768) && (ntc_rg317_e - ntc_rg317 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg317:
var_ent_setname_n:			dw 0
ntc_rg317_e:
			IF ($ < 32768) && (ntc_rg318_e - ntc_rg318 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg318:
p_ent_length_rs:			dw 0
ntc_rg318_e:
			IF ($ < 32768) && (ntc_rg319_e - ntc_rg319 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg319:
var_ent_length_p:			dw 0
ntc_rg319_e:
			IF ($ < 32768) && (ntc_rg320_e - ntc_rg320 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg320:
var_ent_length_s:			dw 0
ntc_rg320_e:
			IF ($ < 32768) && (ntc_rg321_e - ntc_rg321 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg321:
var_ent_length_n:			dw 0
ntc_rg321_e:
			IF ($ < 32768) && (ntc_rg322_e - ntc_rg322 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg322:
p_ent_discname_rs:			dw 0
ntc_rg322_e:
			IF ($ < 32768) && (ntc_rg323_e - ntc_rg323 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg323:
var_ent_discname_p:			dw 0
ntc_rg323_e:
			IF ($ < 32768) && (ntc_rg324_e - ntc_rg324 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg324:
var_ent_discname_d:			dw 0
ntc_rg324_e:
			IF ($ < 32768) && (ntc_rg325_e - ntc_rg325 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg325:
p_memory_bankpage_rs:			dw 0
ntc_rg325_e:
			IF ($ < 32768) && (ntc_rg326_e - ntc_rg326 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg326:
var_memory_bankpage_bank:			dw 0
ntc_rg326_e:
			IF ($ < 32768) && (ntc_rg327_e - ntc_rg327 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg327:
var_memory_bankpage_n:			dw 0
ntc_rg327_e:
			IF ($ < 32768) && (ntc_rg328_e - ntc_rg328 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg328:
tmp0:			dw 0
ntc_rg328_e:
			IF ($ < 32768) && (ntc_rg329_e - ntc_rg329 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg329:
tmp1:			dw 0
ntc_rg329_e:
			IF ($ < 32768) && (ntc_rg330_e - ntc_rg330 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg330:
tmp2:			dw 0
ntc_rg330_e:
			IF ($ < 32768) && (ntc_rg331_e - ntc_rg331 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg331:
tmp3:			dw 0
ntc_rg331_e:
			IF ($ < 32768) && (ntc_rg332_e - ntc_rg332 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg332:
tmp4:			dw 0
ntc_rg332_e:
			IF ($ < 32768) && (ntc_rg333_e - ntc_rg333 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg333:
tmp5:			dw 0
ntc_rg333_e:
			IF ($ < 32768) && (ntc_rg334_e - ntc_rg334 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg334:
tmp6:			dw 0
ntc_rg334_e:
			IF ($ < 32768) && (ntc_rg335_e - ntc_rg335 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg335:
			db 255			; capacity
stmp0:			ds 256
ntc_rg335_e:
			IF ($ < 32768) && (ntc_rg336_e - ntc_rg336 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg336:
			db 255			; capacity
stmp1:			ds 256
ntc_rg336_e:
			IF ($ < 32768) && (ntc_rg337_e - ntc_rg337 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg337:
			db 255			; capacity
stmp2:			ds 256
ntc_rg337_e:
			IF ($ < 32768) && (ntc_rg338_e - ntc_rg338 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg338:
			db 255			; capacity
stmp3:			ds 256
ntc_rg338_e:
			IF ($ < 32768) && (ntc_rg339_e - ntc_rg339 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg339:
ltmp0:			dw 0, 0

; numbers passed by address (read only)
ntc_rg339_e:
			IF ($ < 32768) && (ntc_rg340_e - ntc_rg340 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg340:
lit_0:			dw 0
ntc_rg340_e:
			IF ($ < 32768) && (ntc_rg341_e - ntc_rg341 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg341:
lit_1:			dw 1
ntc_rg341_e:
			IF ($ < 32768) && (ntc_rg342_e - ntc_rg342 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg342:
lit_85:			dw 85
ntc_rg342_e:
			IF ($ < 32768) && (ntc_rg343_e - ntc_rg343 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg343:
vp_arr_rb:			dw arr_rb
ntc_rg343_e:
			IF ($ < 32768) && (ntc_rg344_e - ntc_rg344 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg344:
lit_99:			dw 99
ntc_rg344_e:
			IF ($ < 32768) && (ntc_rg345_e - ntc_rg345 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg345:
lit_82:			dw 82
ntc_rg345_e:
			IF ($ < 32768) && (ntc_rg346_e - ntc_rg346 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg346:
lit_255:			dw 255
ntc_rg346_e:
			IF ($ < 32768) && (ntc_rg347_e - ntc_rg347 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg347:
lit_2:			dw 2
ntc_rg347_e:
			IF ($ < 32768) && (ntc_rg348_e - ntc_rg348 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg348:
lit_m2431:			dw -2431
ntc_rg348_e:
			IF ($ < 32768) && (ntc_rg349_e - ntc_rg349 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg349:
lit_m2423:			dw -2423
ntc_rg349_e:
			IF ($ < 32768) && (ntc_rg350_e - ntc_rg350 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg350:
vp_var_en:			dw var_en
ntc_rg350_e:
			IF ($ < 32768) && (ntc_rg351_e - ntc_rg351 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg351:
vp_var_dn:			dw var_dn
ntc_rg351_e:
			IF ($ < 32768) && (ntc_rg352_e - ntc_rg352 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg352:
lit_100:			dw 100
ntc_rg352_e:
			IF ($ < 32768) && (ntc_rg353_e - ntc_rg353 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg353:
lit_101:			dw 101
ntc_rg353_e:
			IF ($ < 32768) && (ntc_rg354_e - ntc_rg354 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg354:
lit_102:			dw 102
ntc_rg354_e:
			IF ($ < 32768) && (ntc_rg355_e - ntc_rg355 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg355:
vp_var_puts_s:			dw var_puts_s
ntc_rg355_e:
			IF ($ < 32768) && (ntc_rg356_e - ntc_rg356 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg356:
vp_var_putc_c:			dw var_putc_c
ntc_rg356_e:
			IF ($ < 32768) && (ntc_rg357_e - ntc_rg357 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg357:
llit_65536:			dw 0, 1
ntc_rg357_e:
			IF ($ < 32768) && (ntc_rg358_e - ntc_rg358 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg358:
lit_m2425:			dw -2425
ntc_rg358_e:
			IF ($ < 32768) && (ntc_rg359_e - ntc_rg359 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg359:
lit_m2424:			dw -2424
ntc_rg359_e:
			IF ($ < 32768) && (ntc_rg360_e - ntc_rg360 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg360:
lit_4:			dw 4
ntc_rg360_e:
			IF ($ < 32768) && (ntc_rg361_e - ntc_rg361 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg361:
lit_m2422:			dw -2422
ntc_rg361_e:
			IF ($ < 32768) && (ntc_rg362_e - ntc_rg362 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg362:
lit_15:			dw 15
ntc_rg362_e:
			IF ($ < 32768) && (ntc_rg363_e - ntc_rg363 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg363:
lit_13:			dw 13
ntc_rg363_e:
			IF ($ < 32768) && (ntc_rg364_e - ntc_rg364 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg364:
vp_var_topadd_s:			dw var_topadd_s
ntc_rg364_e:
			IF ($ < 32768) && (ntc_rg365_e - ntc_rg365 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg365:
lit_9:			dw 9
ntc_rg365_e:
			IF ($ < 32768) && (ntc_rg366_e - ntc_rg366 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg366:
lit_3:			dw 3
ntc_rg366_e:
			IF ($ < 32768) && (ntc_rg367_e - ntc_rg367 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg367:
lit_m4352:			dw -4352
ntc_rg367_e:
			IF ($ < 32768) && (ntc_rg368_e - ntc_rg368 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg368:
lit_4096:			dw 4096
ntc_rg368_e:
			IF ($ < 32768) && (ntc_rg369_e - ntc_rg369 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg369:
lit_m3328:			dw -3328
ntc_rg369_e:
			IF ($ < 32768) && (ntc_rg370_e - ntc_rg370 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg370:
lit_768:			dw 768
ntc_rg370_e:
			IF ($ < 32768) && (ntc_rg371_e - ntc_rg371 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg371:
lit_m2432:			dw -2432
ntc_rg371_e:
			IF ($ < 32768) && (ntc_rg372_e - ntc_rg372 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg372:
lit_m2344:			dw -2344
ntc_rg372_e:
			IF ($ < 32768) && (ntc_rg373_e - ntc_rg373 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg373:
lit_12:			dw 12
ntc_rg373_e:
			IF ($ < 32768) && (ntc_rg374_e - ntc_rg374 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg374:
lit_m2343:			dw -2343
ntc_rg374_e:
			IF ($ < 32768) && (ntc_rg375_e - ntc_rg375 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg375:
lit_m2417:			dw -2417
ntc_rg375_e:
			IF ($ < 32768) && (ntc_rg376_e - ntc_rg376 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg376:
lit_8:			dw 8
ntc_rg376_e:
			IF ($ < 32768) && (ntc_rg377_e - ntc_rg377 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg377:
lit_32:			dw 32
ntc_rg377_e:
			IF ($ < 32768) && (ntc_rg378_e - ntc_rg378 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg378:
lit_m2416:			dw -2416
ntc_rg378_e:
			IF ($ < 32768) && (ntc_rg379_e - ntc_rg379 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg379:
vp_var_ob:			dw var_ob
ntc_rg379_e:
			IF ($ < 32768) && (ntc_rg380_e - ntc_rg380 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg380:
lit_103:			dw 103
ntc_rg380_e:
			IF ($ < 32768) && (ntc_rg381_e - ntc_rg381 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg381:
lit_256:			dw 256
ntc_rg381_e:
			IF ($ < 32768) && (ntc_rg382_e - ntc_rg382 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg382:
lit_m3332:			dw -3332
ntc_rg382_e:
			IF ($ < 32768) && (ntc_rg383_e - ntc_rg383 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg383:
lit_m3330:			dw -3330
ntc_rg383_e:
			IF ($ < 32768) && (ntc_rg384_e - ntc_rg384 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg384:
lit_m2:			dw -2
ntc_rg384_e:
			IF ($ < 32768) && (ntc_rg385_e - ntc_rg385 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg385:
lit_128:			dw 128
ntc_rg385_e:
			IF ($ < 32768) && (ntc_rg386_e - ntc_rg386 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg386:
vp_var_b:			dw var_b
ntc_rg386_e:
			IF ($ < 32768) && (ntc_rg387_e - ntc_rg387 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg387:
lit_129:			dw 129
ntc_rg387_e:
			IF ($ < 32768) && (ntc_rg388_e - ntc_rg388 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg388:
vp_var_a:			dw var_a
ntc_rg388_e:
			IF ($ < 32768) && (ntc_rg389_e - ntc_rg389 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg389:
lit_m2427:			dw -2427
ntc_rg389_e:
			IF ($ < 32768) && (ntc_rg390_e - ntc_rg390 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg390:
lit_64:			dw 64
ntc_rg390_e:
			IF ($ < 32768) && (ntc_rg391_e - ntc_rg391 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg391:
lit_m1:			dw -1
ntc_rg391_e:
			IF ($ < 32768) && (ntc_rg392_e - ntc_rg392 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg392:
lit_23:			dw 23
ntc_rg392_e:
			IF ($ < 32768) && (ntc_rg393_e - ntc_rg393 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg393:
lit_65:			dw 65
ntc_rg393_e:
			IF ($ < 32768) && (ntc_rg394_e - ntc_rg394 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg394:
lit_57:			dw 57
ntc_rg394_e:
			IF ($ < 32768) && (ntc_rg395_e - ntc_rg395 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg395:
lit_56:			dw 56
ntc_rg395_e:
			IF ($ < 32768) && (ntc_rg396_e - ntc_rg396 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg396:
lit_49:			dw 49
ntc_rg396_e:
			IF ($ < 32768) && (ntc_rg397_e - ntc_rg397 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg397:
lit_48:			dw 48
ntc_rg397_e:
			IF ($ < 32768) && (ntc_rg398_e - ntc_rg398 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg398:
lit_41:			dw 41
ntc_rg398_e:
			IF ($ < 32768) && (ntc_rg399_e - ntc_rg399 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg399:
lit_40:			dw 40
ntc_rg399_e:
			IF ($ < 32768) && (ntc_rg400_e - ntc_rg400 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg400:
lit_33:			dw 33
ntc_rg400_e:
			IF ($ < 32768) && (ntc_rg401_e - ntc_rg401 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg401:
lit_66:			dw 66

ntc_rg401_e:
			IF ($ < 32768) && (ntc_rg402_e - ntc_rg402 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg402:
; ============================================================
; Strings
; ============================================================

ntc_rg402_e:
			IF ($ < 32768) && (ntc_rg403_e - ntc_rg403 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg403:
str0:			db "CyborgOS needs 320K (a 256K expansion) or more", 0
ntc_rg403_e:
			IF ($ < 32768) && (ntc_rg404_e - ntc_rg404 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg404:
str1:			db "Press a key", 0
ntc_rg404_e:
			IF ($ < 32768) && (ntc_rg405_e - ntc_rg405 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg405:
str2:			db 0
ntc_rg405_e:
			IF ($ < 32768) && (ntc_rg406_e - ntc_rg406 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg406:
str3:			db " KEYREP ", 0
ntc_rg406_e:
			IF ($ < 32768) && (ntc_rg407_e - ntc_rg407 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg407:
str4:			db "CyborgOS ended, ", 0
ntc_rg407_e:
			IF ($ < 32768) && (ntc_rg408_e - ntc_rg408 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg408:
str5:			db " programs ran", 0
ntc_rg408_e:
			IF ($ < 32768) && (ntc_rg409_e - ntc_rg409 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg409:
str6:			db 13, 0
ntc_rg409_e:
			IF ($ < 32768) && (ntc_rg410_e - ntc_rg410 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg410:
str7:			db 10, 0
ntc_rg410_e:
			IF ($ < 32768) && (ntc_rg411_e - ntc_rg411 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg411:
str8:			db 27, 0
ntc_rg411_e:
			IF ($ < 32768) && (ntc_rg412_e - ntc_rg412 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg412:
str9:			db "E", 0
ntc_rg412_e:
			IF ($ < 32768) && (ntc_rg413_e - ntc_rg413 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg413:
str10:			db "[", 0
ntc_rg413_e:
			IF ($ < 32768) && (ntc_rg414_e - ntc_rg414 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg414:
str11:			db "]   ", 0
ntc_rg414_e:
			IF ($ < 32768) && (ntc_rg415_e - ntc_rg415 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg415:
str12:			db "CyborgOS TOP", 0
ntc_rg415_e:
			IF ($ < 32768) && (ntc_rg416_e - ntc_rg416 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg416:
str13:			db "Control + ESC: back, ", 0
ntc_rg416_e:
			IF ($ < 32768) && (ntc_rg417_e - ntc_rg417 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg417:
str14:			db ": that slot", 0
ntc_rg417_e:
			IF ($ < 32768) && (ntc_rg418_e - ntc_rg418 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg418:
str15:			db "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (last second)", 0
ntc_rg418_e:
			IF ($ < 32768) && (ntc_rg419_e - ntc_rg419 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg419:
str16:			db "-", 0
ntc_rg419_e:
			IF ($ < 32768) && (ntc_rg420_e - ntc_rg420 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg420:
str17:			db "command line", 0
ntc_rg420_e:
			IF ($ < 32768) && (ntc_rg421_e - ntc_rg421 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg421:
str18:			db "waiting (key)", 0
ntc_rg421_e:
			IF ($ < 32768) && (ntc_rg422_e - ntc_rg422 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg422:
str19:			db "running", 0
ntc_rg422_e:
			IF ($ < 32768) && (ntc_rg423_e - ntc_rg423 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg423:
str20:			db " ", 0
ntc_rg423_e:
			IF ($ < 32768) && (ntc_rg424_e - ntc_rg424 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg424:
str21:			db "*", 0
ntc_rg424_e:
			IF ($ < 32768) && (ntc_rg425_e - ntc_rg425 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg425:
str22:			db "  ", 0
ntc_rg425_e:
			IF ($ < 32768) && (ntc_rg426_e - ntc_rg426 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg426:
str23:			db "Total memory: ", 0
ntc_rg426_e:
			IF ($ < 32768) && (ntc_rg427_e - ntc_rg427 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg427:
str24:			db " KB   Free memory: ", 0
ntc_rg427_e:
			IF ($ < 32768) && (ntc_rg428_e - ntc_rg428 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg428:
str25:			db " KB", 0
ntc_rg428_e:
			IF ($ < 32768) && (ntc_rg429_e - ntc_rg429 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg429:
str26:			db "CyborgOS slot ", 0
ntc_rg429_e:
			IF ($ < 32768) && (ntc_rg430_e - ntc_rg430 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg430:
str27:			db " of ", 0
ntc_rg430_e:
			IF ($ < 32768) && (ntc_rg431_e - ntc_rg431 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg431:
str28:			db " - ", 0
ntc_rg431_e:
			IF ($ < 32768) && (ntc_rg432_e - ntc_rg432 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg432:
str29:			db ", Control + ESC TOP, HELP", 0
ntc_rg432_e:
			IF ($ < 32768) && (ntc_rg433_e - ntc_rg433 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg433:
str30:			db "Control + 1-", 0
ntc_rg433_e:
			IF ($ < 32768) && (ntc_rg434_e - ntc_rg434 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg434:
str31:			db "Control + 1-9, 0", 0
ntc_rg434_e:
			IF ($ < 32768) && (ntc_rg435_e - ntc_rg435 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg435:
str32:			db "Control + 1-9, 0 (twice 11-", 0
ntc_rg435_e:
			IF ($ < 32768) && (ntc_rg436_e - ntc_rg436 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg436:
str33:			db ")", 0
ntc_rg436_e:
			IF ($ < 32768) && (ntc_rg437_e - ntc_rg437 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg437:
str34:			db "> ", 0
ntc_rg437_e:
			IF ($ < 32768) && (ntc_rg438_e - ntc_rg438 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg438:
str35:			db ":", 0
ntc_rg438_e:
			IF ($ < 32768) && (ntc_rg439_e - ntc_rg439 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg439:
str36:			db "CD", 0
ntc_rg439_e:
			IF ($ < 32768) && (ntc_rg440_e - ntc_rg440 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg440:
str37:			db "CLS", 0
ntc_rg440_e:
			IF ($ < 32768) && (ntc_rg441_e - ntc_rg441 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg441:
str38:			db "RUN", 0
ntc_rg441_e:
			IF ($ < 32768) && (ntc_rg442_e - ntc_rg442 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg442:
str39:			db "no slot", 0
ntc_rg442_e:
			IF ($ < 32768) && (ntc_rg443_e - ntc_rg443 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg443:
str40:			db "slot", 0
ntc_rg443_e:
			IF ($ < 32768) && (ntc_rg444_e - ntc_rg444 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg444:
str41:			db " is busy", 0
ntc_rg444_e:
			IF ($ < 32768) && (ntc_rg445_e - ntc_rg445 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg445:
str42:			db "QUIT", 0
ntc_rg445_e:
			IF ($ < 32768) && (ntc_rg446_e - ntc_rg446 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg446:
str43:			db "RUN what?", 0
ntc_rg446_e:
			IF ($ < 32768) && (ntc_rg447_e - ntc_rg447 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg447:
str44:			db ".", 0
ntc_rg447_e:
			IF ($ < 32768) && (ntc_rg448_e - ntc_rg448 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg448:
str45:			db ".CYB", 0
ntc_rg448_e:
			IF ($ < 32768) && (ntc_rg449_e - ntc_rg449 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg449:
str46:			db ".COM", 0
ntc_rg449_e:
			IF ($ < 32768) && (ntc_rg450_e - ntc_rg450 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg450:
str47:			db "RUN ", 0
ntc_rg450_e:
			IF ($ < 32768) && (ntc_rg451_e - ntc_rg451 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg451:
str48:			db ": shorter than FILES.DIR says", 0
ntc_rg451_e:
			IF ($ < 32768) && (ntc_rg452_e - ntc_rg452 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg452:
str49:			db " runs in slot", 0
ntc_rg452_e:
			IF ($ < 32768) && (ntc_rg453_e - ntc_rg453 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg453:
str50:			db "? ", 0
ntc_rg453_e:
			IF ($ < 32768) && (ntc_rg454_e - ntc_rg454 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg454:
str51:			db " (HELP)", 0
ntc_rg454_e:
			IF ($ < 32768) && (ntc_rg455_e - ntc_rg455 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg455:
str52:			db ": not found", 0
ntc_rg455_e:
			IF ($ < 32768) && (ntc_rg456_e - ntc_rg456 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg456:
str53:			db ".HDR", 0
ntc_rg456_e:
			IF ($ < 32768) && (ntc_rg457_e - ntc_rg457 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg457:
str54:			db "FILES.DIR", 0
ntc_rg457_e:
			IF ($ < 32768) && (ntc_rg458_e - ntc_rg458 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg458:
str55:			db " ended]", 0

ntc_rg458_e:
			IF ($ < 32768) && (ntc_rg459_e - ntc_rg459 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg459:
; ============================================================
; Keyword library (rom)
; ============================================================

; Library: ROM - the keyword library is in the ROM NTC CPCFW (NTCFW.ROM).
; Its routines: this jump block, the numbers made into addresses by the ROM at the start.
; Its variables and constants: fixed addresses (RAM #8800 - #A5EF is the ROM's).
ntc_rj_block:
kw_stop:		jp 1
ntc_xn:		jp 2
kw_goto_iffalse_n:	jp 11
kw_goto_iftrue_n:	jp 13
kw_goto_ifzero_n:	jp 15
kw_forupv_n:	jp 25
kw_next1v_n:	jp 33
kw_ltov:		jp 47
kw_vtov:		jp 48
kw_ztov:		jp 49
kw_ftov:		jp 50
kw_inc:		jp 51
kw_add:		jp 53
kw_addl:		jp 54
kw_subvv:	jp 55
kw_4x:		jp 58
kw_mulvl:	jp 61
kw_divvv:	jp 63
kw_divvl:	jp 64
kw_andvv:	jp 72
kw_andvl:	jp 73
kw_orvv:		jp 74
kw_orvl:		jp 75
kw_notv:		jp 78
kw_scpltvl:	jp 80
kw_scplevv:	jp 81
kw_scplevl:	jp 82
kw_scpgtvv:	jp 83
kw_scpgtvl:	jp 84
kw_scpgevl:	jp 86
kw_cpeqvv:	jp 95
kw_cpeqvl:	jp 96
kw_cpnevv:	jp 97
kw_cpnevl:	jp 98
kw_lptrtov8:	jp 99
kw_vptrtov8:	jp 100
kw_aget:		jp 111
kw_aset:		jp 112
kw_asetl:	jp 117
kw_strcpy:	jp 122
kw_strcat:	jp 124
kw_strlen:	jp 125
kw_strcmpeq:	jp 126
kw_strcmpne:	jp 127
kw_printstrvar:	jp 129
kw_printint:	jp 131
kw_printnl0:	jp 134
kw_printnl:	jp 138
kw_inkey:	jp 144
kw_model:	jp 150
kw_frame:	jp 152
kw_ticks:	jp 154
kw_strleft:	jp 156
kw_strright:	jp 157
kw_strmid:	jp 173
kw_strchr:	jp 174
kw_strstr:	jp 176
kw_strspace:	jp 178
kw_strucase:	jp 180
kw_strtrim:	jp 184
kw_strasc:	jp 185
kw_strval:	jp 186
kw_strinstr:	jp 187
kw_l_mov:	jp 206
kw_l_itol:	jp 207
kw_l_add:	jp 209
mem_go0:		jp 243
mem_go:		jp 245
mem_readbyte:	jp 254
mem_writebyte:	jp 256
mem_writeword:	jp 257
mem_freepages:	jp 260
mem_ramsize:	jp 261
mem_allocpage:	jp 266
mem_selpage:	jp 268
mem_copy:	jp 273
ntc_isl_tick:	jp 287
kw_bssinit:	jp 288
ntc_plat_irqon:	jp 314
mem_bankcount:	jp 329
mem_allocbank:	jp 330
ntc_kdown:	jp 334
kw_waitkey:	jp 348
NTC_RJ_N	equ 83		; entries
mem_a1	equ #884F		; ROM data
mem_a2	equ #8851		; ROM data
mem_a3	equ #8853		; ROM data
mem_res	equ #8855		; ROM data
ntc_csp	equ #8800		; ROM data
ntc_irqv	equ #8917		; ROM data
ntc_isl	equ #9786		; ROM bss
ntc_isldue	equ #8908		; ROM data
ntc_isln	equ #8907		; ROM data
ntc_nmode	equ #8807		; ROM data
ntc_rampt	equ #881F		; ROM data
ntc_v_free	equ #894E		; ROM data
ntc_v_romen	equ #8954		; ROM data
ntc_v_romold	equ #8956		; ROM data
ntc_v_stamp	equ #8952		; ROM data
ntc_v_start	equ #8950		; ROM data
			ASSERT ntc_free <= #8800, "Library: ROM - the program and its arrays must end below #8800 (the ROM's RAM)"

; End: the caller's ROM selection again, then back to the caller
ntc_rj_exit:
			ld bc, (ntc_rj_old)
			call #B918		; KL ROM DESELECT
			ret
ntc_rj_old:		dw 0			; the caller's ROM selection (C) and state (B)


; the start code (Library: ROM): run once, then the arrays go over it
ntc_rj_drop:
; the start: find the ROM set in slots 0 - 31 (its main ROM, then the others with the same
; stamp), have the main one patch the jump block. NC = ready; C = not there / too old
; (the message is shown, the caller's ROM selection is back)
ntc_rj_find:
			ld c, 0
			call #B90F		; KL ROM SELECT: B / C = the caller's state and selection
			ld (ntc_rj_old), bc
			xor a
			ld (ntc_rj_want), a
			call ntc_rj_scan		; the main ROM
			jp c, ntc_rj_nf
			ld (ntc_rj_slots), a
			ld e, (hl)
			inc hl
			ld d, (hl)			; its patcher
			ld (ntc_rj_call + 1), de
			ld a, 1
ntc_rj_more:				; the other ROMs of the set
			ld (ntc_rj_want), a
			ld hl, ntc_rj_n
			cp (hl)
			jr nc, ntc_rj_all
			call ntc_rj_scan
			jp c, ntc_rj_part
			ld b, a
			ld a, (ntc_rj_want)
			ld e, a
			ld d, 0
			ld hl, ntc_rj_slots
			add hl, de
			ld (hl), b
			inc a
			jr ntc_rj_more
ntc_rj_all:
			ld a, (ntc_rj_slots)
			ld c, a
			call #B90F		; KL ROM SELECT: the main ROM
			di					; (KL ROM SELECT lets interrupts in)
			ld a, (ntc_rj_slots)	; its slot
			ld hl, ntc_rj_block
			ld bc, NTC_RJ_N
			ld de, ntc_rj_slots
ntc_rj_call:
			call 0				; HL = jump block, BC = entries, A = slot, DE = slots; C: DE = a number it hasn't got
			jp c, ntc_rj_lacks
			IF (ntc_bss >= 32768) && (ntc_bssfrom <= 16384)	; fwdref-ok
			ld hl, ntc_bssfrom		; (the end of the program - or this start code, which tables may go over)
			ELSE
			ld hl, ntc_free
			ENDIF
			ld (ntc_v_free), hl
			ld hl, ntc_start
			ld (ntc_v_start), hl
			ld hl, 0
			ld (ntc_v_stamp), hl
			ld a, 1
			ld (ntc_v_romen), a
			ld a, (ntc_rj_old)
			ld (ntc_v_romold), a
			or a				; NC: ready
			ret
; ntc_rj_scan - a ROM of the set: ROM ntc_rj_want (0 = the main one, any stamp; the others
; with the main one's stamp). NC: A = its slot, HL = past its block's count byte (the main
; one: at its patcher), it is selected. C: not there
ntc_rj_scan:
			ld c, 0
ntc_rj_next:
			push bc
			call #B90F		; KL ROM SELECT: ROM C
			pop bc
			ld a, (#C000)
			cp 1				; a background ROM?
			jr nz, ntc_rj_skip
			ld hl, (#C004)		; its names
			ld a, h
			cp #C0
			jr c, ntc_rj_skip
ntc_rj_name:
			ld a, (hl)
			inc hl
			or a
			jr nz, ntc_rj_name		; to the 0 after the names
			ld de, ntc_rj_sig
			ld b, ntc_rj_sige - ntc_rj_sig
ntc_rj_cmp:
			ld a, (de)
			cp (hl)
			jr nz, ntc_rj_skip
			inc de
			inc hl
			djnz ntc_rj_cmp
			ld e, (hl)
			inc hl
			ld d, (hl)			; DE = its set's stamp
			inc hl
			ld a, (ntc_rj_want)
			cp (hl)				; its place in the set
			jr nz, ntc_rj_skip
			or a
			jr z, ntc_rj_got
			push hl
			ld hl, (ntc_rj_set)
			or a
			sbc hl, de
			pop hl
			jr nz, ntc_rj_skip		; another build's
ntc_rj_got:
			ld (ntc_rj_set), de
			inc hl
			ld a, (hl)
			ld (ntc_rj_n), a		; ROMs in the set
			inc hl
			ld a, c
			or a				; NC
			ret
ntc_rj_skip:
			inc c
			ld a, c
			cp 32
			jr c, ntc_rj_next
			scf					; C: not there
			ret
ntc_rj_nf:
			ld hl, ntc_rj_tnf
			jr ntc_rj_fail
ntc_rj_part:				; a ROM of the set is missing: its number (1 = the main one)
			ld a, (ntc_rj_want)
			inc a
			ld e, a
			ld d, 0
			ld (ntc_rj_num), de
			ld hl, ntc_rj_tpt
			jr ntc_rj_fnum
ntc_rj_lacks:
			ld (ntc_rj_num), de
			ld hl, ntc_rj_tlk
ntc_rj_fnum:
			ld a, 1
			ld (ntc_rj_pn), a		; the number after the message
ntc_rj_fail:
			push hl
			ld bc, (ntc_rj_old)
			call #B918		; KL ROM DESELECT: the caller's selection again
			pop hl
			call ntc_rj_puts
			ld a, (ntc_rj_pn)
			or a
			jr z, ntc_rj_nl
			ld a, (ntc_rj_num + 1)
			call ntc_rj_hex
			ld a, (ntc_rj_num)
			call ntc_rj_hex
ntc_rj_nl:
			ld hl, ntc_rj_tnl
			call ntc_rj_puts
			ei
			call #BB06		; KM WAIT CHAR: a key first (a RUN" program's return resets the machine)
			di
			scf
			ret
ntc_rj_puts:				; HL = text, 0 ends; DE = its start
			ld d, h
			ld e, l
ntc_rj_pl:
			ld a, (hl)
			or a
			ret z
			call #BB5A		; TXT OUTPUT
			inc hl
			jr ntc_rj_pl
ntc_rj_hex:
			push af
			rrca
			rrca
			rrca
			rrca
			call ntc_rj_dig
			pop af
ntc_rj_dig:
			and 15
			add a, #90
			daa
			adc a, #40
			daa
			jp #BB5A
ntc_rj_num:		dw 0
ntc_rj_pn:		db 0			; 1 = a number goes after the message
ntc_rj_want:	db 0			; the ROM of the set looked for
ntc_rj_n:		db 1			; ROMs in the set
ntc_rj_set:		dw 0			; the set's stamp
ntc_rj_slots:	ds 8			; each ROM's slot, the main one first
ntc_rj_sig:		db "NTC", 2, "CPCFW", 0	; the ROMs' NTC block
ntc_rj_sige:
ntc_rj_tnf:		db "ROM NTC CPCFW (NTCFW.ROM) not found", 0
ntc_rj_tlk:		db "ROM NTC CPCFW too old: no routine #", 0
ntc_rj_tpt:		db "ROM NTCFW<n>.ROM not found: n = #", 0
ntc_rj_tnl:		db 13, 10, "Press a key", 13, 10, 0
ntc_rj_dropend:
ntc_rg459_e:
ntc_end:				; the end of the program (and of its file)
			IF $ < #4000	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= #8000, "the window data (; @window) must fit in the window"
			ENDIF
ntc_fileend:			; the file ends here (the window data in it)
; arrays: after the program, not in its file - kw_bssinit checks they fit and clears them
			IF ntc_rj_dropend == ntc_end	; fwdref-ok
ntc_bssfrom	equ ntc_rj_drop		; the arrays over the start code (it has run)
			ELSE
ntc_bssfrom	equ ntc_end
			ENDIF
			IF (ntc_bssfrom < 32768) && (ntc_bssfrom + ntc_bss_size > 16384)	; fwdref-ok
ntc_bss		equ 32768		; after Option Reserve #4000-#7FFF
			ELSE
ntc_bss		equ ntc_bssfrom
			ENDIF
arr_bk		equ ntc_bss + 0		; 10 bytes
arr_sg		equ ntc_bss + 10		; 10 bytes
arr_st		equ ntc_bss + 20		; 10 bytes
arr_kq		equ ntc_bss + 30		; 10 bytes
arr_wp		equ ntc_bss + 40		; 10 bytes
arr_dm		equ ntc_bss + 50		; 10 bytes
arr_ra		equ ntc_bss + 60		; 10 bytes
arr_wk		equ ntc_bss + 70		; 10 bytes
arr_tn		equ ntc_bss + 80		; 10 bytes
arr_nb		equ ntc_bss + 90		; 10 bytes
arr_nc		equ ntc_bss + 100		; 10 bytes
arr_lt		equ ntc_bss + 110		; 10 bytes
arr_lb		equ ntc_bss + 120		; 10 bytes
arr_lc		equ ntc_bss + 130		; 10 bytes
arr_rb		equ ntc_bss + 140		; 128 bytes
arr_ent_en		equ ntc_bss + 268		; 12 bytes
ntc_bss_size	equ 280
ntc_free	equ ntc_bss + ntc_bss_size	; the first free byte (heap, Memory tables)
			IF ntc_free <= 32768	; fwdref-ok
ntc_memtab	equ 32768		; the Memory class's tables: above the window (Option Reserve)
			ELSE
ntc_memtab	equ ntc_free
			ENDIF
; Option Reserve: the program and its arrays (ntc_start .. ntc_free) must stay out of these
			ASSERT (ntc_free <= 16384) || (ntc_bss >= 32768), "the program (or its arrays) reaches into Option Reserve #4000-#7FFF (Main.bas line 23)"
			SAVEAMSDOS "CYBORGOS.BIN", ntc_start, ntc_fileend - ntc_start, ntc_start

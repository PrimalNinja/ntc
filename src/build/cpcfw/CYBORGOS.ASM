; the window data (; @window ... ; @endwindow in #asm): put in the window hole by its guard
			MACRO ntc_windata
; (the hypervisor's page from #5300 - #4000 the disc buffers, #5000 the font: Install copies
; these into each bank from there, FileCall 99 put them there at the start)
            ds #5300 - $		; Hyp.cls 1439
; page zero (#0000-#0080)
fn_hyp_info_hi_p0:		; Hyp.cls 1441
            db #C3		; Hyp.cls 1442
            dw fn_hyp_info_sb_bwb                           ; #0000: warm boot - the BIOS's WBOOT (the task [1443]
            db 0, 0                             ; ends); (#0001) - 3: the BIOS jump table [1444]
            db #C3		; Hyp.cls 1445
            dw fn_hyp_info_sb_start                         ; #0005: BDOS (#0006: the top of the TPA) [1446]
            ds #38 - 8		; Hyp.cls 1447
            db #C3		; Hyp.cls 1448
            dw fn_hyp_info_sb_int                           ; #0038: the interrupt [1449]
            ds #44 - #3B		; Hyp.cls 1450
            db #ED, #49                         ; #0044: out (c), c [1451]
            db #C3		; Hyp.cls 1452
            dw fn_hyp_info_sb_land                          ; #0046: this bank switched in [1453]
            ds #5C - #49		; Hyp.cls 1454
            db 0, "           "                 ; #005C: the default FCB [1455]
            ds #80 - #68		; Hyp.cls 1456
            db 0                                ; #0080: no command tail [1457]
fn_hyp_info_hi_p0e:		; Hyp.cls 1458
; the stubs: assembled here, run at STUB in the bank (DISP: their labels are the bank's
; addresses). The BDOS: what needs nothing of the hypervisor is answered here, with no
; switch - the console out (2, 9: collected at OBUF; the hypervisor gets them, IX = how many, at
; the next far call or interrupt, or when 128 wait), the keys (1, 6, 10, 11: from KEY, where
; the hypervisor leaves the slot's next key), the IOBYTE (7, 8), the disc's parameters (27, 31)
; and the calls with nothing to do (3, 4, 5, 28, 29, 30, 37 - 30 with #C0 on at DE is CyborgOS's
; UniDOS call), CP/M 3's 49 for the console's size (MODE); the rest is a far call. Then the
; BIOS (its jump table: (#0001) - 3) and the start-up (the default FCBs)
fn_hyp_info_sb_img:		; Hyp.cls 1467
            DISP 61184		; Hyp.cls 1468
fn_hyp_info_sb_start:		; Hyp.cls 1469
            di                                  ; BDOS: C = function, DE = argument [1470]
            ld a, c		; Hyp.cls 1471
            cp 2		; Hyp.cls 1472
            jp z, fn_hyp_info_sb_put		; Hyp.cls 1473
            cp 6		; Hyp.cls 1474
            jr z, fn_hyp_info_sb_f6		; Hyp.cls 1475
            cp 11		; Hyp.cls 1476
            jr z, fn_hyp_info_sb_stat		; Hyp.cls 1477
            cp 1		; Hyp.cls 1478
            jr z, fn_hyp_info_sb_f1		; Hyp.cls 1479
            cp 9		; Hyp.cls 1480
            jp z, fn_hyp_info_sb_str		; Hyp.cls 1481
            cp 10		; Hyp.cls 1482
            jp z, fn_hyp_info_sb_line		; Hyp.cls 1483
            cp 3		; Hyp.cls 1484
            jr z, fn_hyp_info_sb_rdr		; Hyp.cls 1485
            cp 7		; Hyp.cls 1486
            jr z, fn_hyp_info_sb_iob		; Hyp.cls 1487
            cp 8		; Hyp.cls 1488
            jr z, fn_hyp_info_sb_siob		; Hyp.cls 1489
            cp 27		; Hyp.cls 1490
            jr z, fn_hyp_info_sb_alv		; Hyp.cls 1491
            cp 31		; Hyp.cls 1492
            jr z, fn_hyp_info_sb_dpb		; Hyp.cls 1493
            cp 4		; Hyp.cls 1494
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1495
            cp 5		; Hyp.cls 1496
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1497
            cp 28		; Hyp.cls 1498
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1499
            cp 29		; Hyp.cls 1500
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1501
            cp 30		; Hyp.cls 1502
            jr z, fn_hyp_info_sb_f30		; Hyp.cls 1503
            cp 37		; Hyp.cls 1504
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1505
            cp 49		; Hyp.cls 1506
            jp z, fn_hyp_info_sb_scb		; Hyp.cls 1507
            jp fn_hyp_info_sb_call		; Hyp.cls 1508
fn_hyp_info_sb_f30:                                         ; 30: nothing - unless #C0 on at DE: CyborgOS's [1509]
            ld a, (de)                          ; UniDOS call (CD, DIR: the hypervisor's) [1510]
            cp #C0		; Hyp.cls 1511
            jp nc, fn_hyp_info_sb_call		; Hyp.cls 1512
fn_hyp_info_sb_zero:		; Hyp.cls 1513
            xor a                               ; 4, 5 (the printer: not yet), 28, 29, 30, 37 [1514]
fn_hyp_info_sb_ret:		; Hyp.cls 1515
            ld l, a		; Hyp.cls 1516
            ld h, 0		; Hyp.cls 1517
            ei		; Hyp.cls 1518
            ret		; Hyp.cls 1519
fn_hyp_info_sb_rdr:		; Hyp.cls 1520
            ld a, #1A                           ; 3: the reader - the end of a file [1521]
            jr fn_hyp_info_sb_ret		; Hyp.cls 1522
fn_hyp_info_sb_iob:		; Hyp.cls 1523
            ld a, (#0003)                       ; 7: the IOBYTE [1524]
            jr fn_hyp_info_sb_ret		; Hyp.cls 1525
fn_hyp_info_sb_siob:		; Hyp.cls 1526
            ld a, e                             ; 8 [1527]
            ld (#0003), a		; Hyp.cls 1528
            jr fn_hyp_info_sb_zero		; Hyp.cls 1529
fn_hyp_info_sb_alv:		; Hyp.cls 1530
            ld hl, fn_hyp_info_sb_alvec                     ; 27: the allocation vector (a CPC data disc's) [1531]
            ei		; Hyp.cls 1532
            ret		; Hyp.cls 1533
fn_hyp_info_sb_dpb:		; Hyp.cls 1534
            ld hl, fn_hyp_info_sb_dpbv                      ; 31: the disc parameter block [1535]
            ei		; Hyp.cls 1536
            ret		; Hyp.cls 1537
fn_hyp_info_sb_f6:		; Hyp.cls 1538
            ld a, e		; Hyp.cls 1539
            cp #FF		; Hyp.cls 1540
            jr z, fn_hyp_info_sb_get		; Hyp.cls 1541
            cp #FE		; Hyp.cls 1542
            jr c, fn_hyp_info_sb_put		; Hyp.cls 1543
fn_hyp_info_sb_stat:		; Hyp.cls 1544
            ld a, (63105)                       ; 6 / #FE, 11: is a key waiting (#FF / 0) [1545]
            or a		; Hyp.cls 1546
            jr z, fn_hyp_info_sb_ret		; Hyp.cls 1547
            ld a, #FF		; Hyp.cls 1548
            jr fn_hyp_info_sb_ret		; Hyp.cls 1549
fn_hyp_info_sb_get:		; Hyp.cls 1550
            ld hl, 63105                        ; 6 / #FF: the key or 0 (no wait) [1551]
            ld a, (hl)		; Hyp.cls 1552
            ld (hl), 0		; Hyp.cls 1553
            jr fn_hyp_info_sb_ret		; Hyp.cls 1554
fn_hyp_info_sb_f1:		; Hyp.cls 1555
            call fn_hyp_info_sb_key                         ; 1: a key (waited for), echoed [1556]
            push af		; Hyp.cls 1557
            ld e, a		; Hyp.cls 1558
            call fn_hyp_info_sb_putc		; Hyp.cls 1559
            pop af		; Hyp.cls 1560
            jr fn_hyp_info_sb_ret		; Hyp.cls 1561
fn_hyp_info_sb_put:		; Hyp.cls 1562
            call fn_hyp_info_sb_putc                        ; 2: E out [1563]
            ei		; Hyp.cls 1564
            ret		; Hyp.cls 1565
fn_hyp_info_sb_str:		; Hyp.cls 1566
            ld h, d                             ; 9: the string at DE, to "$" [1567]
            ld l, e		; Hyp.cls 1568
fn_hyp_info_sb_st_lp:		; Hyp.cls 1569
            ld a, (hl)		; Hyp.cls 1570
            cp '$'		; Hyp.cls 1571
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1572
            push hl		; Hyp.cls 1573
            ld e, a		; Hyp.cls 1574
            call fn_hyp_info_sb_putc		; Hyp.cls 1575
            pop hl		; Hyp.cls 1576
            inc hl		; Hyp.cls 1577
            jr fn_hyp_info_sb_st_lp		; Hyp.cls 1578
; sb_putc - E collected at OBUF (the hypervisor shown them when 128 wait). Interrupts off
fn_hyp_info_sb_putc:		; Hyp.cls 1580
            ld hl, 62976 + 128                 ; the count [1581]
            ld a, (hl)		; Hyp.cls 1582
            inc (hl)		; Hyp.cls 1583
            ld l, a		; Hyp.cls 1584
            ld h, 62976 / 256		; Hyp.cls 1585
            ld (hl), e		; Hyp.cls 1586
            cp 127		; Hyp.cls 1587
            ret c		; Hyp.cls 1588
            push bc		; Hyp.cls 1589
            push de		; Hyp.cls 1590
            ld c, #80                           ; full: function #80, only the characters [1591]
            call fn_hyp_info_sb_call		; Hyp.cls 1592
            di		; Hyp.cls 1593
            pop de		; Hyp.cls 1594
            pop bc		; Hyp.cls 1595
            ret		; Hyp.cls 1596
; sb_key - A = the next key, waited for: none at KEY - a far call (#81) that has the hypervisor
; run the others until a key comes (or the clock moves on), then look again
fn_hyp_info_sb_key:		; Hyp.cls 1599
            ld hl, 63105		; Hyp.cls 1600
            ld a, (hl)		; Hyp.cls 1601
            or a		; Hyp.cls 1602
            jr z, fn_hyp_info_sb_k_wait		; Hyp.cls 1603
            ld (hl), 0		; Hyp.cls 1604
            ret		; Hyp.cls 1605
fn_hyp_info_sb_k_wait:		; Hyp.cls 1606
            push bc		; Hyp.cls 1607
            push de		; Hyp.cls 1608
            ld c, #81		; Hyp.cls 1609
            call fn_hyp_info_sb_call		; Hyp.cls 1610
            di		; Hyp.cls 1611
            pop de		; Hyp.cls 1612
            pop bc		; Hyp.cls 1613
            jr fn_hyp_info_sb_key		; Hyp.cls 1614
; 10: a line typed into the buffer at DE (its size, then how many came, then them): BS / DEL
; rub out, Control + U / X the whole line, Control + C at its start ends the program, CR / LF
; end it (CR echoed)
fn_hyp_info_sb_line:		; Hyp.cls 1618
            ld (fn_hyp_info_sb_lbuf), de		; Hyp.cls 1619
            xor a		; Hyp.cls 1620
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1621
fn_hyp_info_sb_l_lp:		; Hyp.cls 1622
            call fn_hyp_info_sb_key		; Hyp.cls 1623
            cp 13		; Hyp.cls 1624
            jr z, fn_hyp_info_sb_l_end		; Hyp.cls 1625
            cp 10		; Hyp.cls 1626
            jr z, fn_hyp_info_sb_l_end		; Hyp.cls 1627
            cp 8		; Hyp.cls 1628
            jr z, fn_hyp_info_sb_l_bs		; Hyp.cls 1629
            cp 127		; Hyp.cls 1630
            jr z, fn_hyp_info_sb_l_bs		; Hyp.cls 1631
            cp 21		; Hyp.cls 1632
            jr z, fn_hyp_info_sb_l_kill		; Hyp.cls 1633
            cp 24		; Hyp.cls 1634
            jr z, fn_hyp_info_sb_l_kill		; Hyp.cls 1635
            cp 3		; Hyp.cls 1636
            jr nz, fn_hyp_info_sb_l_ch		; Hyp.cls 1637
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1638
            or a		; Hyp.cls 1639
            jr nz, fn_hyp_info_sb_l_lp		; Hyp.cls 1640
            ld c, 0                             ; Control + C: the program ends [1641]
            jp fn_hyp_info_sb_call		; Hyp.cls 1642
fn_hyp_info_sb_l_ch:		; Hyp.cls 1643
            cp 32		; Hyp.cls 1644
            jr c, fn_hyp_info_sb_l_lp		; Hyp.cls 1645
            ld b, a		; Hyp.cls 1646
            ld hl, (fn_hyp_info_sb_lbuf)		; Hyp.cls 1647
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1648
            cp (hl)		; Hyp.cls 1649
            jr nc, fn_hyp_info_sb_l_lp                      ; full [1650]
            inc a		; Hyp.cls 1651
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1652
            ld e, a		; Hyp.cls 1653
            ld d, 0		; Hyp.cls 1654
            inc hl		; Hyp.cls 1655
            add hl, de		; Hyp.cls 1656
            ld (hl), b		; Hyp.cls 1657
            ld e, b		; Hyp.cls 1658
            call fn_hyp_info_sb_putc		; Hyp.cls 1659
            jr fn_hyp_info_sb_l_lp		; Hyp.cls 1660
fn_hyp_info_sb_l_kill:		; Hyp.cls 1661
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1662
            or a		; Hyp.cls 1663
            jr z, fn_hyp_info_sb_l_lp		; Hyp.cls 1664
            call fn_hyp_info_sb_l_rub		; Hyp.cls 1665
            jr fn_hyp_info_sb_l_kill		; Hyp.cls 1666
fn_hyp_info_sb_l_bs:		; Hyp.cls 1667
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1668
            or a		; Hyp.cls 1669
            jr z, fn_hyp_info_sb_l_lp		; Hyp.cls 1670
            call fn_hyp_info_sb_l_rub		; Hyp.cls 1671
            jr fn_hyp_info_sb_l_lp		; Hyp.cls 1672
fn_hyp_info_sb_l_rub:		; Hyp.cls 1673
            dec a		; Hyp.cls 1674
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1675
            ld e, 8		; Hyp.cls 1676
            call fn_hyp_info_sb_putc		; Hyp.cls 1677
            ld e, ' '		; Hyp.cls 1678
            call fn_hyp_info_sb_putc		; Hyp.cls 1679
            ld e, 8		; Hyp.cls 1680
            jp fn_hyp_info_sb_putc		; Hyp.cls 1681
fn_hyp_info_sb_l_end:		; Hyp.cls 1682
            ld hl, (fn_hyp_info_sb_lbuf)		; Hyp.cls 1683
            inc hl		; Hyp.cls 1684
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1685
            ld (hl), a		; Hyp.cls 1686
            ld e, 13		; Hyp.cls 1687
            call fn_hyp_info_sb_putc		; Hyp.cls 1688
            jp fn_hyp_info_sb_zero		; Hyp.cls 1689
fn_hyp_info_sb_lbuf:    dw 0		; Hyp.cls 1690
fn_hyp_info_sb_lcnt:    db 0		; Hyp.cls 1691
fn_hyp_info_sb_call:		; Hyp.cls 1692
            push ix                             ; a far call: IX, IY and the alternate [1693]
            push iy                             ; registers kept over it (ex af, af') [1694]
            db #08		; Hyp.cls 1695
            exx		; Hyp.cls 1696
            push af		; Hyp.cls 1697
            push bc		; Hyp.cls 1698
            push de		; Hyp.cls 1699
            push hl		; Hyp.cls 1700
            exx		; Hyp.cls 1701
            db #08		; Hyp.cls 1702
            ld a, (62976 + 128)		; Hyp.cls 1703
            ld ixl, a		; Hyp.cls 1704
            ld ixh, 0		; Hyp.cls 1705
            ld a, c		; Hyp.cls 1706
            ld hl, fn_hyp_info_sb_far		; Hyp.cls 1707
            push hl		; Hyp.cls 1708
            ld (#FFFE), sp		; Hyp.cls 1709
            ld bc, #7FC0		; Hyp.cls 1710
            scf                                 ; carry: a far call [1711]
            jp #0044		; Hyp.cls 1712
fn_hyp_info_sb_far:		; Hyp.cls 1713
            db #08                              ; the answer in A and HL; the program's [1714]
            exx                                 ; other registers back [1715]
            pop hl		; Hyp.cls 1716
            pop de		; Hyp.cls 1717
            pop bc		; Hyp.cls 1718
            pop af		; Hyp.cls 1719
            exx		; Hyp.cls 1720
            db #08		; Hyp.cls 1721
            pop iy		; Hyp.cls 1722
            pop ix		; Hyp.cls 1723
            ei		; Hyp.cls 1724
            ret		; Hyp.cls 1725
fn_hyp_info_sb_int:		; Hyp.cls 1726
            push af                             ; an interrupt: everything kept [1727]
            push bc		; Hyp.cls 1728
            push de		; Hyp.cls 1729
            push hl		; Hyp.cls 1730
            db #08                              ; ex af, af' [1731]
            exx		; Hyp.cls 1732
            push af		; Hyp.cls 1733
            push bc		; Hyp.cls 1734
            push de		; Hyp.cls 1735
            push hl		; Hyp.cls 1736
            push ix		; Hyp.cls 1737
            push iy		; Hyp.cls 1738
            ld a, (62976 + 128)		; Hyp.cls 1739
            ld ixl, a		; Hyp.cls 1740
            ld ixh, 0		; Hyp.cls 1741
            ld hl, fn_hyp_info_sb_rest		; Hyp.cls 1742
            push hl		; Hyp.cls 1743
            ld (#FFFE), sp		; Hyp.cls 1744
            ld bc, #7FC0		; Hyp.cls 1745
            or a                                ; no carry: an interrupt [1746]
            jp #0044		; Hyp.cls 1747
fn_hyp_info_sb_rest:		; Hyp.cls 1748
            pop iy		; Hyp.cls 1749
            pop ix		; Hyp.cls 1750
            pop hl		; Hyp.cls 1751
            pop de		; Hyp.cls 1752
            pop bc		; Hyp.cls 1753
            pop af		; Hyp.cls 1754
            exx		; Hyp.cls 1755
            db #08                              ; ex af, af' [1756]
            pop hl		; Hyp.cls 1757
            pop de		; Hyp.cls 1758
            pop bc		; Hyp.cls 1759
            pop af		; Hyp.cls 1760
            ei		; Hyp.cls 1761
            ret		; Hyp.cls 1762
fn_hyp_info_sb_land:		; Hyp.cls 1763
            ld sp, (#FFFE)                      ; this bank's SP [1764]
            push af		; Hyp.cls 1765
            ld a, e                             ; E = 1: the hypervisor has the characters [1766]
            or a		; Hyp.cls 1767
            jr z, fn_hyp_info_sb_lkeep		; Hyp.cls 1768
            xor a		; Hyp.cls 1769
            ld (62976 + 128), a		; Hyp.cls 1770
fn_hyp_info_sb_lkeep:		; Hyp.cls 1771
            pop af		; Hyp.cls 1772
            ret		; Hyp.cls 1773
fn_hyp_info_sb_scb:		; Hyp.cls 1774
            ld h, d                             ; 49 (CP/M 3's system control block): the [1775]
            ld l, e                             ; console's width - 1 (#1A), its page length [1776]
            inc hl                              ; (#1C) - MODE's; other bytes 0, sets kept [1777]
            ld a, (hl)                          ; nowhere [1778]
            or a		; Hyp.cls 1779
            jp nz, fn_hyp_info_sb_zero		; Hyp.cls 1780
            ld a, (de)		; Hyp.cls 1781
            cp #1C		; Hyp.cls 1782
            ld hl, 63112		; Hyp.cls 1783
            jr z, fn_hyp_info_sb_scb_a		; Hyp.cls 1784
            cp #1A		; Hyp.cls 1785
            jp nz, fn_hyp_info_sb_zero		; Hyp.cls 1786
            ld a, (63111)		; Hyp.cls 1787
            dec a		; Hyp.cls 1788
            jp fn_hyp_info_sb_ret		; Hyp.cls 1789
fn_hyp_info_sb_scb_a:		; Hyp.cls 1790
            ld a, (hl)		; Hyp.cls 1791
            jp fn_hyp_info_sb_ret		; Hyp.cls 1792
; the BIOS: CP/M 2.2's 17 entries. The console ones as the BDOS's; the printer and punch take
; nothing yet; the disc ones (sectors) can't be had here: SELDSK gives 0 (no such drive),
; READ / WRITE 1 (an error)
fn_hyp_info_sb_bios:		; Hyp.cls 1796
            jp fn_hyp_info_sb_bboot                         ; BOOT [1797]
fn_hyp_info_sb_bwb:		; Hyp.cls 1798
            jp fn_hyp_info_sb_bboot                         ; WBOOT: (#0001) [1799]
            jp fn_hyp_info_sb_bconst                        ; CONST [1800]
            jp fn_hyp_info_sb_bconin                        ; CONIN [1801]
            jp fn_hyp_info_sb_bconout                       ; CONOUT [1802]
            jp fn_hyp_info_sb_bnone                         ; LIST [1803]
            jp fn_hyp_info_sb_bnone                         ; PUNCH [1804]
            jp fn_hyp_info_sb_brdr                          ; READER [1805]
            jp fn_hyp_info_sb_bnone                         ; HOME [1806]
            jp fn_hyp_info_sb_bseld                         ; SELDSK [1807]
            jp fn_hyp_info_sb_bnone                         ; SETTRK [1808]
            jp fn_hyp_info_sb_bnone                         ; SETSEC [1809]
            jp fn_hyp_info_sb_bdma                          ; SETDMA [1810]
            jp fn_hyp_info_sb_bfail                         ; READ [1811]
            jp fn_hyp_info_sb_bfail                         ; WRITE [1812]
            jp fn_hyp_info_sb_blstst                        ; LISTST [1813]
            jp fn_hyp_info_sb_bsectr                        ; SECTRAN [1814]
fn_hyp_info_sb_bboot:		; Hyp.cls 1815
            ld c, 0                             ; the task ends [1816]
            jp fn_hyp_info_sb_start		; Hyp.cls 1817
fn_hyp_info_sb_bconst:		; Hyp.cls 1818
            di		; Hyp.cls 1819
            ld a, (63105)		; Hyp.cls 1820
            or a		; Hyp.cls 1821
            jr z, fn_hyp_info_sb_bc_n		; Hyp.cls 1822
            ld a, #FF		; Hyp.cls 1823
fn_hyp_info_sb_bc_n:		; Hyp.cls 1824
            ei		; Hyp.cls 1825
            ret		; Hyp.cls 1826
fn_hyp_info_sb_bconin:		; Hyp.cls 1827
            di		; Hyp.cls 1828
            call fn_hyp_info_sb_key		; Hyp.cls 1829
            ei		; Hyp.cls 1830
            ret		; Hyp.cls 1831
fn_hyp_info_sb_bconout:		; Hyp.cls 1832
            di		; Hyp.cls 1833
            ld e, c		; Hyp.cls 1834
            call fn_hyp_info_sb_putc		; Hyp.cls 1835
            ei		; Hyp.cls 1836
fn_hyp_info_sb_bnone:		; Hyp.cls 1837
            ret		; Hyp.cls 1838
fn_hyp_info_sb_brdr:		; Hyp.cls 1839
            ld a, #1A		; Hyp.cls 1840
            ret		; Hyp.cls 1841
fn_hyp_info_sb_bseld:		; Hyp.cls 1842
            ld hl, 0		; Hyp.cls 1843
            ret		; Hyp.cls 1844
fn_hyp_info_sb_bdma:		; Hyp.cls 1845
            ld d, b		; Hyp.cls 1846
            ld e, c		; Hyp.cls 1847
            ld c, 26		; Hyp.cls 1848
            jp fn_hyp_info_sb_start		; Hyp.cls 1849
fn_hyp_info_sb_bfail:		; Hyp.cls 1850
            ld a, 1		; Hyp.cls 1851
            ret		; Hyp.cls 1852
fn_hyp_info_sb_blstst:		; Hyp.cls 1853
            ld a, #FF		; Hyp.cls 1854
            ret		; Hyp.cls 1855
fn_hyp_info_sb_bsectr:		; Hyp.cls 1856
            ld h, b		; Hyp.cls 1857
            ld l, c		; Hyp.cls 1858
            ret		; Hyp.cls 1859
; a CPC data format disc's parameters (31) and allocation vector (27): 180 1K blocks, 64
; directory entries in the first two
fn_hyp_info_sb_dpbv:		; Hyp.cls 1862
            dw 36                               ; SPT: 128 byte records a track [1863]
            db 3, 7, 0                          ; BSH, BLM, EXM [1864]
            dw 179, 63                          ; DSM, DRM [1865]
            db #C0, 0                           ; AL0, AL1 [1866]
            dw 16, 0                            ; CKS, OFF [1867]
fn_hyp_info_sb_alvec:		; Hyp.cls 1868
            db #C0		; Hyp.cls 1869
            ds 22		; Hyp.cls 1870
; the start-up: the default FCBs (#005C, #006C) from the command tail (#0080), as the CCP
; makes them - "B:NAME.EXT", * as ?s - then the program at #0100
fn_hyp_info_sb_init:		; Hyp.cls 1873
            ld hl, #005C		; Hyp.cls 1874
            call fn_hyp_info_sb_iclr		; Hyp.cls 1875
            ld hl, #006C		; Hyp.cls 1876
            call fn_hyp_info_sb_iclr		; Hyp.cls 1877
            ld hl, #0081		; Hyp.cls 1878
            ld a, (#0080)		; Hyp.cls 1879
            ld b, a		; Hyp.cls 1880
            ld de, #005C		; Hyp.cls 1881
            call fn_hyp_info_sb_parse		; Hyp.cls 1882
            ld de, #006C		; Hyp.cls 1883
            call fn_hyp_info_sb_parse		; Hyp.cls 1884
            jp #0100		; Hyp.cls 1885
fn_hyp_info_sb_iclr:		; Hyp.cls 1886
            ld (hl), 0		; Hyp.cls 1887
            inc hl		; Hyp.cls 1888
            ld c, 11		; Hyp.cls 1889
fn_hyp_info_sb_ic_sp:		; Hyp.cls 1890
            ld (hl), ' '		; Hyp.cls 1891
            inc hl		; Hyp.cls 1892
            dec c		; Hyp.cls 1893
            jr nz, fn_hyp_info_sb_ic_sp		; Hyp.cls 1894
            ld c, 4		; Hyp.cls 1895
fn_hyp_info_sb_ic_z:		; Hyp.cls 1896
            ld (hl), 0		; Hyp.cls 1897
            inc hl		; Hyp.cls 1898
            dec c		; Hyp.cls 1899
            jr nz, fn_hyp_info_sb_ic_z		; Hyp.cls 1900
            ret		; Hyp.cls 1901
; sb_parse - HL = the tail, B = characters left; DE = an FCB: the next word into it
fn_hyp_info_sb_parse:		; Hyp.cls 1903
            ld a, b		; Hyp.cls 1904
            or a		; Hyp.cls 1905
            ret z		; Hyp.cls 1906
            ld a, (hl)		; Hyp.cls 1907
            cp ' '		; Hyp.cls 1908
            jr nz, fn_hyp_info_sb_p_word		; Hyp.cls 1909
            inc hl		; Hyp.cls 1910
            dec b		; Hyp.cls 1911
            jr fn_hyp_info_sb_parse		; Hyp.cls 1912
fn_hyp_info_sb_p_word:		; Hyp.cls 1913
            ld (fn_hyp_info_sb_pfcb), de		; Hyp.cls 1914
            ld a, b		; Hyp.cls 1915
            cp 2		; Hyp.cls 1916
            jr c, fn_hyp_info_sb_p_name		; Hyp.cls 1917
            inc hl		; Hyp.cls 1918
            ld a, (hl)		; Hyp.cls 1919
            dec hl		; Hyp.cls 1920
            cp ':'		; Hyp.cls 1921
            jr nz, fn_hyp_info_sb_p_name		; Hyp.cls 1922
            ld a, (hl)		; Hyp.cls 1923
            sub '@'		; Hyp.cls 1924
            ld (de), a                          ; its drive [1925]
            inc hl		; Hyp.cls 1926
            inc hl		; Hyp.cls 1927
            dec b		; Hyp.cls 1928
            dec b		; Hyp.cls 1929
fn_hyp_info_sb_p_name:		; Hyp.cls 1930
            inc de		; Hyp.cls 1931
            ld c, 8		; Hyp.cls 1932
            call fn_hyp_info_sb_pfield		; Hyp.cls 1933
            ld a, b		; Hyp.cls 1934
            or a		; Hyp.cls 1935
            ret z		; Hyp.cls 1936
            ld a, (hl)		; Hyp.cls 1937
            cp '.'		; Hyp.cls 1938
            jr nz, fn_hyp_info_sb_p_skip		; Hyp.cls 1939
            inc hl		; Hyp.cls 1940
            dec b		; Hyp.cls 1941
            ld de, (fn_hyp_info_sb_pfcb)		; Hyp.cls 1942
            ld a, e		; Hyp.cls 1943
            add a, 9		; Hyp.cls 1944
            ld e, a		; Hyp.cls 1945
            ld c, 3		; Hyp.cls 1946
            call fn_hyp_info_sb_pfield		; Hyp.cls 1947
fn_hyp_info_sb_p_skip:		; Hyp.cls 1948
            ld a, b                             ; the rest of the word [1949]
            or a		; Hyp.cls 1950
            ret z		; Hyp.cls 1951
            ld a, (hl)		; Hyp.cls 1952
            cp ' '		; Hyp.cls 1953
            ret z		; Hyp.cls 1954
            inc hl		; Hyp.cls 1955
            dec b		; Hyp.cls 1956
            jr fn_hyp_info_sb_p_skip		; Hyp.cls 1957
; sb_pfield - up to C characters into the field at DE, to a "." or a space; * fills it with ?
fn_hyp_info_sb_pfield:		; Hyp.cls 1959
            ld a, b		; Hyp.cls 1960
            or a		; Hyp.cls 1961
            ret z		; Hyp.cls 1962
            ld a, (hl)		; Hyp.cls 1963
            cp ' '		; Hyp.cls 1964
            ret z		; Hyp.cls 1965
            cp '.'		; Hyp.cls 1966
            ret z		; Hyp.cls 1967
            cp '*'		; Hyp.cls 1968
            jr z, fn_hyp_info_sb_pf_star		; Hyp.cls 1969
            inc c		; Hyp.cls 1970
            dec c		; Hyp.cls 1971
            jr z, fn_hyp_info_sb_pf_on                      ; (the field full: the extra left out) [1972]
            ld (de), a		; Hyp.cls 1973
            inc de		; Hyp.cls 1974
            dec c		; Hyp.cls 1975
fn_hyp_info_sb_pf_on:		; Hyp.cls 1976
            inc hl		; Hyp.cls 1977
            dec b		; Hyp.cls 1978
            jr fn_hyp_info_sb_pfield		; Hyp.cls 1979
fn_hyp_info_sb_pf_star:		; Hyp.cls 1980
            inc c		; Hyp.cls 1981
            dec c		; Hyp.cls 1982
            jr z, fn_hyp_info_sb_pf_on		; Hyp.cls 1983
            ld a, '?'		; Hyp.cls 1984
            ld (de), a		; Hyp.cls 1985
            inc de		; Hyp.cls 1986
            dec c		; Hyp.cls 1987
            jr fn_hyp_info_sb_pf_star		; Hyp.cls 1988
fn_hyp_info_sb_pfcb:    dw 0		; Hyp.cls 1989
fn_hyp_info_sb_end:		; Hyp.cls 1990
            ENT		; Hyp.cls 1991
            ASSERT fn_hyp_info_sb_end - fn_hyp_info_sb_start <= 62208 - 61184, "the bank stubs must fit below FONT"		; Hyp.cls 1992
            ASSERT fn_hyp_info_sb_end - fn_hyp_info_sb_start <= #340, "the stubs must leave a program's first stack (#F240-#F2FF) free"		; Hyp.cls 1993
; ---- the page code: in the hypervisor's page (window data), called with it in the window
asm_1_2036_n_fp_start:		; Hyp.cls 2236
            ASSERT asm_1_2036_n_fp_start >= #5300, "FileCall's page code: after the disc buffers and the font"		; Hyp.cls 2237
asm_1_2036_n_fp_go:		; Hyp.cls 2238
            ld (asm_1_2036_n_fp_sp), sp		; Hyp.cls 2239
            ld a, (var_hyp_filecall_f)		; Hyp.cls 2240
            cp 15		; Hyp.cls 2241
            jp z, asm_1_2036_n_fl_open		; Hyp.cls 2242
            cp 16		; Hyp.cls 2243
            jp z, asm_1_2036_n_fl_close		; Hyp.cls 2244
            cp 19		; Hyp.cls 2245
            jp z, asm_1_2036_n_fl_del		; Hyp.cls 2246
            cp 23		; Hyp.cls 2247
            jp z, asm_1_2036_n_fl_ren		; Hyp.cls 2248
            cp 20		; Hyp.cls 2249
            jp z, asm_1_2036_n_fl_rdseq		; Hyp.cls 2250
            cp 33		; Hyp.cls 2251
            jp z, asm_1_2036_n_fl_rdran		; Hyp.cls 2252
            cp 21		; Hyp.cls 2253
            jp z, asm_1_2036_n_fl_write		; Hyp.cls 2254
            cp 34		; Hyp.cls 2255
            jp z, asm_1_2036_n_fl_write		; Hyp.cls 2256
            cp 22		; Hyp.cls 2257
            jp z, asm_1_2036_n_fl_make		; Hyp.cls 2258
            cp 17		; Hyp.cls 2259
            jp z, asm_1_2036_n_fl_srch1		; Hyp.cls 2260
            cp 18		; Hyp.cls 2261
            jp z, asm_1_2036_n_fl_srch		; Hyp.cls 2262
            cp 35		; Hyp.cls 2263
            jp z, asm_1_2036_n_fl_size		; Hyp.cls 2264
            cp 36		; Hyp.cls 2265
            jp z, asm_1_2036_n_fl_setran		; Hyp.cls 2266
            cp 100		; Hyp.cls 2267
            jp z, asm_1_2036_n_fl_hopen		; Hyp.cls 2268
            cp 101		; Hyp.cls 2269
            jp z, asm_1_2036_n_fl_hread		; Hyp.cls 2270
            cp 102		; Hyp.cls 2271
            jp z, asm_1_2036_n_fl_hclose		; Hyp.cls 2272
            cp 103		; Hyp.cls 2273
            jp z, asm_1_2036_n_fl_hload		; Hyp.cls 2274
            cp 30		; Hyp.cls 2275
            jp z, asm_1_2036_n_fl_unicall		; Hyp.cls 2276
            jp asm_1_2036_n_fp_done		; Hyp.cls 2277
; ---- the hypervisor's own reading (RUN, DIR, CD): 100 open the file named at fcb (dma
; characters, main RAM); 101 read dma bytes (128 at most) to buf: how many; 102 close; 103 the
; rest of it into the slot (setting) from address dma, fcb bytes at most: how many. Not while
; a slot reads a file (255)
asm_1_2036_n_fl_hopen:		; Hyp.cls 2282
            ld a, (var_hyp_fin)		; Hyp.cls 2283
            or a		; Hyp.cls 2284
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2285
            ld de, asm_1_2036_n_fl_name_s + 1		; Hyp.cls 2286
            ld hl, (var_hyp_filecall_fcb)          ; a name with no drive: the hypervisor's drive's path first [2287]
            ld bc, (var_hyp_filecall_dma)          ; when it has one (UniDOS: CD IDE: ...) [2288]
            ld a, ':'		; Hyp.cls 2289
            cpir		; Hyp.cls 2290
            jr z, asm_1_2036_n_fl_ho_nm		; Hyp.cls 2291
            ld a, (var_hyp_hdr)		; Hyp.cls 2292
            call asm_1_2036_n_fl_pfxm		; Hyp.cls 2293
asm_1_2036_n_fl_ho_nm:		; Hyp.cls 2294
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2295
            ld bc, (var_hyp_filecall_dma)		; Hyp.cls 2296
            ldir		; Hyp.cls 2297
            call asm_1_2036_n_fl_nlen		; Hyp.cls 2298
            call asm_1_2036_n_fl_inopen		; Hyp.cls 2299
            jr c, asm_1_2036_n_fl_ho_ok		; Hyp.cls 2300
            ld hl, asm_1_2036_n_fl_name_s        ; NAME.CYB not there: with UniDOS NAME.COM instead (RUN - a [2301]
            ld e, (hl)              ; .COM with no entry: UniDOS reads a file with no header to [2302]
            ld d, 0                 ; its real end) [2303]
            add hl, de		; Hyp.cls 2304
            ld a, (hl)		; Hyp.cls 2305
            cp 'B'		; Hyp.cls 2306
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2307
            ld (hl), 'M'		; Hyp.cls 2308
            dec hl		; Hyp.cls 2309
            ld a, (hl)		; Hyp.cls 2310
            cp 'Y'		; Hyp.cls 2311
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2312
            ld (hl), 'O'		; Hyp.cls 2313
            call asm_1_2036_n_fl_uni		; Hyp.cls 2314
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2315
            call asm_1_2036_n_fl_inopen		; Hyp.cls 2316
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2317
            ld hl, (var_hyp_filecall_fcb)          ; (the caller's name too: NAME.COM) [2318]
            ld bc, (var_hyp_filecall_dma)		; Hyp.cls 2319
            add hl, bc		; Hyp.cls 2320
            dec hl		; Hyp.cls 2321
            ld (hl), 'M'		; Hyp.cls 2322
            dec hl		; Hyp.cls 2323
            ld (hl), 'O'		; Hyp.cls 2324
asm_1_2036_n_fl_ho_ok:		; Hyp.cls 2325
            ld a, 99                ; (99: the hypervisor's) [2326]
            ld (var_hyp_fin), a		; Hyp.cls 2327
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2328
asm_1_2036_n_fl_hread:		; Hyp.cls 2329
            ld a, (var_hyp_filecall_dma)		; Hyp.cls 2330
            ld (asm_1_2036_n_fl_n), a		; Hyp.cls 2331
            call asm_1_2036_n_fl_rdrec		; Hyp.cls 2332
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 2333
            jp asm_1_2036_n_fp_done		; Hyp.cls 2334
asm_1_2036_n_fl_hclose:		; Hyp.cls 2335
            ld a, (var_hyp_fin)		; Hyp.cls 2336
            cp 99		; Hyp.cls 2337
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2338
            call asm_1_2036_n_fl_inclose		; Hyp.cls 2339
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2340
asm_1_2036_n_fl_hload:		; Hyp.cls 2341
            ld hl, 0		; Hyp.cls 2342
            ld (asm_1_2036_n_fl_cnt), hl		; Hyp.cls 2343
            ld hl, (var_hyp_filecall_dma)		; Hyp.cls 2344
            ld (asm_1_2036_n_fl_at), hl		; Hyp.cls 2345
asm_1_2036_n_fl_hl_lp:		; Hyp.cls 2346
            ld hl, (var_hyp_filecall_fcb)          ; what is left to load (fcb bytes at most) [2347]
            ld de, (asm_1_2036_n_fl_cnt)		; Hyp.cls 2348
            or a		; Hyp.cls 2349
            sbc hl, de		; Hyp.cls 2350
            jr z, asm_1_2036_n_fl_hl_end		; Hyp.cls 2351
            ld a, h		; Hyp.cls 2352
            or a		; Hyp.cls 2353
            ld a, 128		; Hyp.cls 2354
            jr nz, asm_1_2036_n_fl_hl_n		; Hyp.cls 2355
            ld a, l		; Hyp.cls 2356
            cp 128		; Hyp.cls 2357
            jr c, asm_1_2036_n_fl_hl_n		; Hyp.cls 2358
            ld a, 128		; Hyp.cls 2359
asm_1_2036_n_fl_hl_n:		; Hyp.cls 2360
            ld (asm_1_2036_n_fl_n), a		; Hyp.cls 2361
            ld (asm_1_2036_n_fl_want), a		; Hyp.cls 2362
            call asm_1_2036_n_fl_rdrec           ; a record's worth into buf [2363]
            jr z, asm_1_2036_n_fl_hl_end		; Hyp.cls 2364
            ld b, a		; Hyp.cls 2365
            ld (asm_1_2036_n_fl_want + 1), a		; Hyp.cls 2366
            ld hl, (asm_1_2036_n_fl_cnt)		; Hyp.cls 2367
            ld e, a		; Hyp.cls 2368
            ld d, 0		; Hyp.cls 2369
            add hl, de		; Hyp.cls 2370
            ld (asm_1_2036_n_fl_cnt), hl		; Hyp.cls 2371
            ld hl, (asm_1_2036_n_fl_at)		; Hyp.cls 2372
            ld c, b		; Hyp.cls 2373
            ld b, 0		; Hyp.cls 2374
            call asm_1_2036_n_fl_fits		; Hyp.cls 2375
            jr c, asm_1_2036_n_fl_hl_slow		; Hyp.cls 2376
            push bc		; Hyp.cls 2377
            ld de, (var_hyp_filecall_buf)          ; in one page: one ldir [2378]
            call asm_1_2036_n_fl_toslot		; Hyp.cls 2379
            pop bc		; Hyp.cls 2380
            ld hl, (asm_1_2036_n_fl_at)		; Hyp.cls 2381
            add hl, bc		; Hyp.cls 2382
            jr asm_1_2036_n_fl_hl_put		; Hyp.cls 2383
asm_1_2036_n_fl_hl_slow:		; Hyp.cls 2384
            ld b, c		; Hyp.cls 2385
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2386
asm_1_2036_n_fl_hl_cp:		; Hyp.cls 2387
            ld a, (de)              ; into the slot [2388]
            call asm_1_2036_n_fl_poke		; Hyp.cls 2389
            inc hl		; Hyp.cls 2390
            inc de		; Hyp.cls 2391
            djnz asm_1_2036_n_fl_hl_cp		; Hyp.cls 2392
asm_1_2036_n_fl_hl_put:		; Hyp.cls 2393
            ld (asm_1_2036_n_fl_at), hl		; Hyp.cls 2394
            ld a, (asm_1_2036_n_fl_want)		; Hyp.cls 2395
            ld b, a		; Hyp.cls 2396
            ld a, (asm_1_2036_n_fl_want + 1)		; Hyp.cls 2397
            cp b		; Hyp.cls 2398
            jr z, asm_1_2036_n_fl_hl_lp          ; a whole one: on [2399]
asm_1_2036_n_fl_hl_end:		; Hyp.cls 2400
            ld hl, (asm_1_2036_n_fl_cnt)		; Hyp.cls 2401
            ld (asm_1_2036_n_fl_res16), hl		; Hyp.cls 2402
            ld a, 1		; Hyp.cls 2403
            ld (asm_1_2036_n_fl_r16), a		; Hyp.cls 2404
            jp asm_1_2036_n_fp_done		; Hyp.cls 2405
; ---- 15: open (to read)
asm_1_2036_n_fl_open:		; Hyp.cls 2407
            ld a, (var_hyp_fin)		; Hyp.cls 2408
            or a		; Hyp.cls 2409
            jr z, asm_1_2036_n_fl_op_new		; Hyp.cls 2410
            ld b, a		; Hyp.cls 2411
            ld a, (asm_1_2036_n_fl_slot)		; Hyp.cls 2412
            cp b		; Hyp.cls 2413
            jp nz, asm_1_2036_n_fp_done          ; another slot's being read [2414]
            call asm_1_2036_n_fl_inclose         ; this slot's: CP/M needs no close after reading - this open [2415]
asm_1_2036_n_fl_op_new:                          ; replaces it (Exists opens and leaves it) [2416]
            call asm_1_2036_n_fl_name		; Hyp.cls 2417
            call asm_1_2036_n_fl_inopen		; Hyp.cls 2418
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2419
            ld hl, asm_1_2036_n_fl_name_s        ; kept, to open it again (33 going back) [2420]
            ld de, asm_1_2036_n_fl_inname		; Hyp.cls 2421
            ld bc, asm_1_2036_n_FL_NL		; Hyp.cls 2422
            ldir		; Hyp.cls 2423
            ld a, (asm_1_2036_n_fl_slot)		; Hyp.cls 2424
            ld (var_hyp_fin), a		; Hyp.cls 2425
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2426
            ld (asm_1_2036_n_fl_infcb), hl		; Hyp.cls 2427
            ld hl, 0		; Hyp.cls 2428
            ld (asm_1_2036_n_fl_inrec), hl		; Hyp.cls 2429
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2430
; ---- 22: make (a new file, to write)
asm_1_2036_n_fl_make:		; Hyp.cls 2432
            ld a, (var_hyp_fout)		; Hyp.cls 2433
            or a		; Hyp.cls 2434
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2435
            call asm_1_2036_n_fl_name		; Hyp.cls 2436
            call asm_1_2036_n_fl_plain		; Hyp.cls 2437
            ld hl, asm_1_2036_n_fl_name_s + 1		; Hyp.cls 2438
            ld a, (asm_1_2036_n_fl_name_s)		; Hyp.cls 2439
            ld b, a		; Hyp.cls 2440
            ld de, #4800		; Hyp.cls 2441
            call #BC8C              ; CAS OUT OPEN [2442]
            di		; Hyp.cls 2443
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2444
            ld a, (asm_1_2036_n_fl_slot)		; Hyp.cls 2445
            ld (var_hyp_fout), a		; Hyp.cls 2446
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2447
            ld (asm_1_2036_n_fl_outfcb), hl		; Hyp.cls 2448
            ld hl, 0		; Hyp.cls 2449
            ld (asm_1_2036_n_fl_outrec), hl		; Hyp.cls 2450
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2451
; ---- 16: close
asm_1_2036_n_fl_close:		; Hyp.cls 2453
            call asm_1_2036_n_fl_isin		; Hyp.cls 2454
            jr nz, asm_1_2036_n_fl_cl_out		; Hyp.cls 2455
            call asm_1_2036_n_fl_inclose		; Hyp.cls 2456
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2457
asm_1_2036_n_fl_cl_out:		; Hyp.cls 2458
            call asm_1_2036_n_fl_isout		; Hyp.cls 2459
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2460
            xor a		; Hyp.cls 2461
            ld (var_hyp_fout), a		; Hyp.cls 2462
            call asm_1_2036_n_fl_plain		; Hyp.cls 2463
            call #BC8F              ; CAS OUT CLOSE [2464]
            di		; Hyp.cls 2465
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2466
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2467
; ---- 19: delete (|ERA, "name")
asm_1_2036_n_fl_del:		; Hyp.cls 2469
            call asm_1_2036_n_fl_name		; Hyp.cls 2470
            call asm_1_2036_n_fl_plain		; Hyp.cls 2471
            ld hl, asm_1_2036_n_fl_name_s + 1		; Hyp.cls 2472
            ld (asm_1_2036_n_fl_desc + 1), hl		; Hyp.cls 2473
            ld a, (asm_1_2036_n_fl_name_s)		; Hyp.cls 2474
            ld (asm_1_2036_n_fl_desc), a		; Hyp.cls 2475
            ld a, 'Y'               ; (UniDOS asks before it deletes a folder, a read-only or a [2476]
            call #BB0C              ; hidden file - KM WAIT CHAR, its text unseen: the VDU is off. [2477]
            ld hl, asm_1_2036_n_fl_era           ; KM CHAR RETURN: a Y waiting for it; KM READ CHAR after [2478]
            call #BCD4              ; takes it back when nothing asked) KL FIND COMMAND [2479]
            di		; Hyp.cls 2480
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2481
            ld ix, asm_1_2036_n_fl_par		; Hyp.cls 2482
            ld a, 1                 ; one parameter: the string [2483]
            call #001B              ; KL FAR PCALL [2484]
            call #BB09              ; KM READ CHAR (interrupts: off again in fl_done) [2485]
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2486
; ---- 23: rename (the disc ROM's |REN, "new", "old"): the old name at FCB 0-11, the new
; at 16-27 (its drive 0: the old one's)
asm_1_2036_n_fl_ren:		; Hyp.cls 2489
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2490
            call asm_1_2036_n_fl_peek		; Hyp.cls 2491
            ld (asm_1_2036_n_fl_dfl), a		; Hyp.cls 2492
            ld de, 16		; Hyp.cls 2493
            add hl, de		; Hyp.cls 2494
            call asm_1_2036_n_fl_namehl          ; the new name [2495]
            xor a		; Hyp.cls 2496
            ld (asm_1_2036_n_fl_dfl), a		; Hyp.cls 2497
            ld hl, asm_1_2036_n_fl_name_s		; Hyp.cls 2498
            ld de, asm_1_2036_n_fl_new_s		; Hyp.cls 2499
            ld bc, asm_1_2036_n_FL_NL		; Hyp.cls 2500
            ldir		; Hyp.cls 2501
            call asm_1_2036_n_fl_name            ; the old one [2502]
            call asm_1_2036_n_fl_plain		; Hyp.cls 2503
            ld hl, asm_1_2036_n_fl_name_s + 1		; Hyp.cls 2504
            ld (asm_1_2036_n_fl_desc + 1), hl		; Hyp.cls 2505
            ld a, (asm_1_2036_n_fl_name_s)		; Hyp.cls 2506
            ld (asm_1_2036_n_fl_desc), a		; Hyp.cls 2507
            ld hl, asm_1_2036_n_fl_new_s + 1		; Hyp.cls 2508
            ld (asm_1_2036_n_fl_desc2 + 1), hl		; Hyp.cls 2509
            ld a, (asm_1_2036_n_fl_new_s)		; Hyp.cls 2510
            ld (asm_1_2036_n_fl_desc2), a		; Hyp.cls 2511
            ld hl, asm_1_2036_n_fl_rencmd		; Hyp.cls 2512
            call #BCD4              ; KL FIND COMMAND [2513]
            di		; Hyp.cls 2514
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2515
            ld ix, asm_1_2036_n_fl_par2          ; IX+0: the last parameter (the old name), IX+2: the new [2516]
            ld a, 2		; Hyp.cls 2517
            call #001B              ; KL FAR PCALL [2518]
            jp asm_1_2036_n_fl_ok              ; (interrupts: off again in fl_done) [2519]
; ---- 33: read record r0-r1: on to it (from the start again if it is behind)
asm_1_2036_n_fl_rdran:		; Hyp.cls 2521
            call asm_1_2036_n_fl_isin		; Hyp.cls 2522
            jp nz, asm_1_2036_n_fl_rdout		; Hyp.cls 2523
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2524
            ld de, 33		; Hyp.cls 2525
            add hl, de		; Hyp.cls 2526
            call asm_1_2036_n_fl_peek		; Hyp.cls 2527
            ld e, a		; Hyp.cls 2528
            inc hl		; Hyp.cls 2529
            call asm_1_2036_n_fl_peek		; Hyp.cls 2530
            ld d, a		; Hyp.cls 2531
            ld (asm_1_2036_n_fl_want), de		; Hyp.cls 2532
            ld hl, (asm_1_2036_n_fl_inrec)		; Hyp.cls 2533
            or a		; Hyp.cls 2534
            sbc hl, de		; Hyp.cls 2535
            jr c, asm_1_2036_n_fl_rr_on		; Hyp.cls 2536
            jr z, asm_1_2036_n_fl_rr_on		; Hyp.cls 2537
            call asm_1_2036_n_fl_inclose         ; behind: open it again [2538]
            ld hl, asm_1_2036_n_fl_inname		; Hyp.cls 2539
            ld de, asm_1_2036_n_fl_name_s		; Hyp.cls 2540
            ld bc, asm_1_2036_n_FL_NL		; Hyp.cls 2541
            ldir		; Hyp.cls 2542
            call asm_1_2036_n_fl_inopen		; Hyp.cls 2543
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2544
            ld a, (asm_1_2036_n_fl_slot)		; Hyp.cls 2545
            ld (var_hyp_fin), a		; Hyp.cls 2546
            ld hl, 0		; Hyp.cls 2547
            ld (asm_1_2036_n_fl_inrec), hl		; Hyp.cls 2548
asm_1_2036_n_fl_rr_on:		; Hyp.cls 2549
            ld hl, (asm_1_2036_n_fl_inrec)		; Hyp.cls 2550
            ld de, (asm_1_2036_n_fl_want)		; Hyp.cls 2551
            or a		; Hyp.cls 2552
            sbc hl, de		; Hyp.cls 2553
            jr nc, asm_1_2036_n_fl_rdseq		; Hyp.cls 2554
            call asm_1_2036_n_fl_rdrec		; Hyp.cls 2555
            jp z, asm_1_2036_n_fl_eof		; Hyp.cls 2556
            ld hl, (asm_1_2036_n_fl_inrec)		; Hyp.cls 2557
            inc hl		; Hyp.cls 2558
            ld (asm_1_2036_n_fl_inrec), hl		; Hyp.cls 2559
            jr asm_1_2036_n_fl_rr_on		; Hyp.cls 2560
; ---- 20: read the next record
asm_1_2036_n_fl_rdseq:		; Hyp.cls 2562
            call asm_1_2036_n_fl_isin		; Hyp.cls 2563
            jr nz, asm_1_2036_n_fl_rdout		; Hyp.cls 2564
            call asm_1_2036_n_fl_rdrec		; Hyp.cls 2565
            jr z, asm_1_2036_n_fl_eof		; Hyp.cls 2566
            ex de, hl		; Hyp.cls 2567
            ld hl, (asm_1_2036_n_fl_inrec)		; Hyp.cls 2568
            inc hl		; Hyp.cls 2569
            ld (asm_1_2036_n_fl_inrec), hl		; Hyp.cls 2570
            ex de, hl		; Hyp.cls 2571
            ld b, a                 ; the record padded with #1A [2572]
            ld a, 128		; Hyp.cls 2573
            sub b		; Hyp.cls 2574
            jr z, asm_1_2036_n_fl_rd_put		; Hyp.cls 2575
            ld b, a		; Hyp.cls 2576
            ld a, #1A		; Hyp.cls 2577
asm_1_2036_n_fl_rd_pad:		; Hyp.cls 2578
            ld (hl), a		; Hyp.cls 2579
            inc hl		; Hyp.cls 2580
            djnz asm_1_2036_n_fl_rd_pad		; Hyp.cls 2581
asm_1_2036_n_fl_rd_put:		; Hyp.cls 2582
            ld hl, (var_hyp_filecall_dma)          ; into the slot's DMA: in one page, one ldir [2583]
            ld bc, 128		; Hyp.cls 2584
            call asm_1_2036_n_fl_fits		; Hyp.cls 2585
            jr c, asm_1_2036_n_fl_rd_slow		; Hyp.cls 2586
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2587
            call asm_1_2036_n_fl_toslot		; Hyp.cls 2588
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2589
asm_1_2036_n_fl_rd_slow:                         ; (across two pages: a byte at a time) [2590]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2591
            ld de, (var_hyp_filecall_dma)		; Hyp.cls 2592
            ld b, 128		; Hyp.cls 2593
asm_1_2036_n_fl_rd_cp:		; Hyp.cls 2594
            ld a, (hl)		; Hyp.cls 2595
            ex de, hl		; Hyp.cls 2596
            call asm_1_2036_n_fl_poke		; Hyp.cls 2597
            ex de, hl		; Hyp.cls 2598
            inc hl		; Hyp.cls 2599
            inc de		; Hyp.cls 2600
            djnz asm_1_2036_n_fl_rd_cp		; Hyp.cls 2601
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2602
asm_1_2036_n_fl_rdout:		; Hyp.cls 2603
            call asm_1_2036_n_fl_isout           ; a file being written: nothing to read back [2604]
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2605
asm_1_2036_n_fl_eof:		; Hyp.cls 2606
            ld a, 1		; Hyp.cls 2607
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 2608
            jp asm_1_2036_n_fp_done		; Hyp.cls 2609
; ---- 21 / 34: write the next record
asm_1_2036_n_fl_write:		; Hyp.cls 2611
            call asm_1_2036_n_fl_isout		; Hyp.cls 2612
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2613
            ld hl, (var_hyp_filecall_dma)          ; the slot's DMA into buf [2614]
            ld bc, 128		; Hyp.cls 2615
            call asm_1_2036_n_fl_fits		; Hyp.cls 2616
            jr c, asm_1_2036_n_fl_wr_slow		; Hyp.cls 2617
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2618
            call asm_1_2036_n_fl_fromslot		; Hyp.cls 2619
            jr asm_1_2036_n_fl_wr_got		; Hyp.cls 2620
asm_1_2036_n_fl_wr_slow:		; Hyp.cls 2621
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2622
            ld b, 128		; Hyp.cls 2623
asm_1_2036_n_fl_wr_cp:		; Hyp.cls 2624
            call asm_1_2036_n_fl_peek		; Hyp.cls 2625
            ld (de), a		; Hyp.cls 2626
            inc hl		; Hyp.cls 2627
            inc de		; Hyp.cls 2628
            djnz asm_1_2036_n_fl_wr_cp		; Hyp.cls 2629
asm_1_2036_n_fl_wr_got:		; Hyp.cls 2630
            call asm_1_2036_n_fl_plain		; Hyp.cls 2631
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2632
            ld b, 128		; Hyp.cls 2633
asm_1_2036_n_fl_wr_lp:		; Hyp.cls 2634
            ld a, (hl)		; Hyp.cls 2635
            push bc		; Hyp.cls 2636
            push hl		; Hyp.cls 2637
            call #BC95              ; CAS OUT CHAR [2638]
            di		; Hyp.cls 2639
            pop hl		; Hyp.cls 2640
            pop bc		; Hyp.cls 2641
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2642
            inc hl		; Hyp.cls 2643
            djnz asm_1_2036_n_fl_wr_lp		; Hyp.cls 2644
            ld hl, (asm_1_2036_n_fl_outrec)		; Hyp.cls 2645
            inc hl		; Hyp.cls 2646
            ld (asm_1_2036_n_fl_outrec), hl		; Hyp.cls 2647
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2648
; ---- 35: the file's size in records (r0-r2): counted, reading it through. The file this slot
; is reading is opened again after, at its record; another slot's being read: 255
asm_1_2036_n_fl_size:		; Hyp.cls 2651
            ld a, (var_hyp_fin)		; Hyp.cls 2652
            or a		; Hyp.cls 2653
            jr z, asm_1_2036_n_fl_sz_free		; Hyp.cls 2654
            ld b, a		; Hyp.cls 2655
            ld a, (asm_1_2036_n_fl_slot)		; Hyp.cls 2656
            cp b		; Hyp.cls 2657
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 2658
            call asm_1_2036_n_fl_inclose		; Hyp.cls 2659
            ld a, 1		; Hyp.cls 2660
asm_1_2036_n_fl_sz_free:		; Hyp.cls 2661
            ld (asm_1_2036_n_fl_had), a		; Hyp.cls 2662
            call asm_1_2036_n_fl_name		; Hyp.cls 2663
            call asm_1_2036_n_fl_inopen		; Hyp.cls 2664
            jr nc, asm_1_2036_n_fl_sz_back		; Hyp.cls 2665
            ld hl, 0		; Hyp.cls 2666
            ld (asm_1_2036_n_fl_cnt), hl		; Hyp.cls 2667
asm_1_2036_n_fl_sz_lp:		; Hyp.cls 2668
            call asm_1_2036_n_fl_rdrec		; Hyp.cls 2669
            jr z, asm_1_2036_n_fl_sz_end		; Hyp.cls 2670
            ld hl, (asm_1_2036_n_fl_cnt)		; Hyp.cls 2671
            inc hl		; Hyp.cls 2672
            ld (asm_1_2036_n_fl_cnt), hl		; Hyp.cls 2673
            cp 128		; Hyp.cls 2674
            jr z, asm_1_2036_n_fl_sz_lp		; Hyp.cls 2675
asm_1_2036_n_fl_sz_end:		; Hyp.cls 2676
            call asm_1_2036_n_fl_inclose		; Hyp.cls 2677
            ld hl, (asm_1_2036_n_fl_cnt)		; Hyp.cls 2678
            call asm_1_2036_n_fl_ranput		; Hyp.cls 2679
            xor a		; Hyp.cls 2680
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 2681
asm_1_2036_n_fl_sz_back:		; Hyp.cls 2682
            ld a, (asm_1_2036_n_fl_had)		; Hyp.cls 2683
            or a		; Hyp.cls 2684
            jp z, asm_1_2036_n_fp_done		; Hyp.cls 2685
            ld hl, asm_1_2036_n_fl_inname        ; the slot's read file again, on to its record [2686]
            ld de, asm_1_2036_n_fl_name_s		; Hyp.cls 2687
            ld bc, asm_1_2036_n_FL_NL		; Hyp.cls 2688
            ldir		; Hyp.cls 2689
            call asm_1_2036_n_fl_inopen		; Hyp.cls 2690
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 2691
            ld a, (asm_1_2036_n_fl_slot)		; Hyp.cls 2692
            ld (var_hyp_fin), a		; Hyp.cls 2693
            ld hl, (asm_1_2036_n_fl_inrec)		; Hyp.cls 2694
asm_1_2036_n_fl_sz_skip:		; Hyp.cls 2695
            ld a, h		; Hyp.cls 2696
            or l		; Hyp.cls 2697
            jp z, asm_1_2036_n_fp_done		; Hyp.cls 2698
            push hl		; Hyp.cls 2699
            call asm_1_2036_n_fl_rdrec		; Hyp.cls 2700
            pop hl		; Hyp.cls 2701
            dec hl		; Hyp.cls 2702
            jr asm_1_2036_n_fl_sz_skip		; Hyp.cls 2703
; ---- 36: set the random record (r0-r2) from where the file is: the next record read or
; written; a file not open here: from the FCB's extent and record (ex * 128 + cr)
asm_1_2036_n_fl_setran:		; Hyp.cls 2706
            call asm_1_2036_n_fl_isin		; Hyp.cls 2707
            ld hl, (asm_1_2036_n_fl_inrec)		; Hyp.cls 2708
            jr z, asm_1_2036_n_fl_sr_put		; Hyp.cls 2709
            call asm_1_2036_n_fl_isout		; Hyp.cls 2710
            ld hl, (asm_1_2036_n_fl_outrec)		; Hyp.cls 2711
            jr z, asm_1_2036_n_fl_sr_put		; Hyp.cls 2712
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2713
            ld de, 32		; Hyp.cls 2714
            add hl, de		; Hyp.cls 2715
            call asm_1_2036_n_fl_peek            ; cr [2716]
            ld e, a		; Hyp.cls 2717
            ld bc, -20		; Hyp.cls 2718
            add hl, bc		; Hyp.cls 2719
            call asm_1_2036_n_fl_peek            ; ex [2720]
            ld h, a		; Hyp.cls 2721
            srl h		; Hyp.cls 2722
            ld a, e		; Hyp.cls 2723
            jr nc, asm_1_2036_n_fl_sr_lo		; Hyp.cls 2724
            or #80		; Hyp.cls 2725
asm_1_2036_n_fl_sr_lo:		; Hyp.cls 2726
            ld l, a		; Hyp.cls 2727
asm_1_2036_n_fl_sr_put:		; Hyp.cls 2728
            call asm_1_2036_n_fl_ranput		; Hyp.cls 2729
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2730
; ---- 17 / 18: search the folder (UniDOS: the FCB's drive's, else the slot's) for BDOS 17's
; name ("?" any character; kept at SRCH in the bank, SRCH + 12 the entries passed - 18 goes on
; from there): the next one, as a CP/M directory entry at the DMA (its record count from its
; length, 128 at most). 17 examines the folder (Ctrl J) into the hypervisor's page (#6000-#7BFF:
; 112 entries at most), then 17 and 18 look there. No UniDOS (or an AMSDOS floppy): none (255)
asm_1_2036_n_fl_srch1:		; Hyp.cls 2736
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2737
            ld de, 63216		; Hyp.cls 2738
            ld b, 12		; Hyp.cls 2739
asm_1_2036_n_fl_s1_lp:		; Hyp.cls 2740
            call asm_1_2036_n_fl_peek		; Hyp.cls 2741
            ex de, hl		; Hyp.cls 2742
            call asm_1_2036_n_fl_poke		; Hyp.cls 2743
            ex de, hl		; Hyp.cls 2744
            inc hl		; Hyp.cls 2745
            inc de		; Hyp.cls 2746
            djnz asm_1_2036_n_fl_s1_lp		; Hyp.cls 2747
            ex de, hl		; Hyp.cls 2748
            xor a		; Hyp.cls 2749
            call asm_1_2036_n_fl_poke            ; none passed [2750]
            xor a		; Hyp.cls 2751
            ld (asm_1_2036_n_fl_cn), a		; Hyp.cls 2752
            ld hl, #6000		; Hyp.cls 2753
            ld (asm_1_2036_n_fl_at), hl		; Hyp.cls 2754
            ld de, asm_1_2036_n_fl_name_s + 1    ; "B:" (or B's path) [2755]
            ld hl, 63216		; Hyp.cls 2756
            call asm_1_2036_n_fl_peek		; Hyp.cls 2757
            or a		; Hyp.cls 2758
            jr z, asm_1_2036_n_fl_s_own		; Hyp.cls 2759
            add a, 64		; Hyp.cls 2760
            jr asm_1_2036_n_fl_s_drv		; Hyp.cls 2761
asm_1_2036_n_fl_s_own:		; Hyp.cls 2762
            ld a, (var_hyp_filecall_drive)		; Hyp.cls 2763
            or a		; Hyp.cls 2764
            jr z, asm_1_2036_n_fl_s_nod		; Hyp.cls 2765
asm_1_2036_n_fl_s_drv:		; Hyp.cls 2766
            call asm_1_2036_n_fl_pfx		; Hyp.cls 2767
asm_1_2036_n_fl_s_nod:		; Hyp.cls 2768
; UniDOS: the directory itself (Ctrl J examine), its files into the cache - no file opened (so
; not held up by another slot's reading)
            push de		; Hyp.cls 2771
            call asm_1_2036_n_fl_exdir		; Hyp.cls 2772
            pop de		; Hyp.cls 2773
            jp nz, asm_1_2036_n_fp_done          ; (none to list: no UniDOS, an AMSDOS floppy - 255) [2774]
asm_1_2036_n_fl_sx_lp:		; Hyp.cls 2775
            ld hl, (asm_1_2036_n_fl_at)		; Hyp.cls 2776
            inc hl                  ; (the name straight into the entry) [2777]
            ld ix, asm_1_2036_n_FL_DATE		; Hyp.cls 2778
            ld c, 13                ; examine next [2779]
            call asm_1_2036_n_fl_cjc		; Hyp.cls 2780
            jr nc, asm_1_2036_n_fl_sx_end		; Hyp.cls 2781
            jr nz, asm_1_2036_n_fl_sx_end		; Hyp.cls 2782
            bit 4, a		; Hyp.cls 2783
            jr nz, asm_1_2036_n_fl_sx_lp         ; (a folder: not for CP/M) [2784]
            ld hl, (asm_1_2036_n_fl_at)		; Hyp.cls 2785
            ld (hl), 1              ; in use [2786]
            ld a, b		; Hyp.cls 2787
            or c		; Hyp.cls 2788
            jr z, asm_1_2036_n_fl_sx_sz		; Hyp.cls 2789
            ld de, #FFFF            ; (64K or more) [2790]
asm_1_2036_n_fl_sx_sz:		; Hyp.cls 2791
            ld bc, 12		; Hyp.cls 2792
            add hl, bc		; Hyp.cls 2793
            ld (hl), b              ; kind, flags 0 [2794]
            inc hl		; Hyp.cls 2795
            ld (hl), b		; Hyp.cls 2796
            inc hl		; Hyp.cls 2797
            ld (hl), e              ; its length [2798]
            inc hl		; Hyp.cls 2799
            ld (hl), d		; Hyp.cls 2800
            ld hl, (asm_1_2036_n_fl_at)		; Hyp.cls 2801
            ld bc, 64		; Hyp.cls 2802
            add hl, bc		; Hyp.cls 2803
            ld (asm_1_2036_n_fl_at), hl		; Hyp.cls 2804
            ld hl, asm_1_2036_n_fl_cn		; Hyp.cls 2805
            inc (hl)		; Hyp.cls 2806
            ld a, (hl)		; Hyp.cls 2807
            cp asm_1_2036_n_FL_CMAX		; Hyp.cls 2808
            jr c, asm_1_2036_n_fl_sx_lp		; Hyp.cls 2809
asm_1_2036_n_fl_sx_end:		; Hyp.cls 2810
            jp asm_1_2036_n_fl_srch		; Hyp.cls 2811
asm_1_2036_n_fl_srch:		; Hyp.cls 2812
            ld hl, 63216 + 12		; Hyp.cls 2813
            call asm_1_2036_n_fl_peek		; Hyp.cls 2814
            ld (asm_1_2036_n_fl_skip), a		; Hyp.cls 2815
            xor a		; Hyp.cls 2816
            ld (asm_1_2036_n_fl_k), a		; Hyp.cls 2817
asm_1_2036_n_fl_s_lp:		; Hyp.cls 2818
            ld a, (asm_1_2036_n_fl_cn)           ; the next entry, from the cache [2819]
            ld b, a		; Hyp.cls 2820
            ld a, (asm_1_2036_n_fl_k)		; Hyp.cls 2821
            cp b		; Hyp.cls 2822
            jp nc, asm_1_2036_n_fp_done          ; (none: 255) [2823]
            ld l, a		; Hyp.cls 2824
            ld h, 0		; Hyp.cls 2825
            add hl, hl		; Hyp.cls 2826
            add hl, hl		; Hyp.cls 2827
            add hl, hl		; Hyp.cls 2828
            add hl, hl		; Hyp.cls 2829
            add hl, hl		; Hyp.cls 2830
            add hl, hl		; Hyp.cls 2831
            ld de, #6000		; Hyp.cls 2832
            add hl, de		; Hyp.cls 2833
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2834
            ld bc, 64		; Hyp.cls 2835
            ldir		; Hyp.cls 2836
            ld hl, asm_1_2036_n_fl_k		; Hyp.cls 2837
            inc (hl)		; Hyp.cls 2838
            ld a, (asm_1_2036_n_fl_skip)		; Hyp.cls 2839
            cp (hl)		; Hyp.cls 2840
            jr nc, asm_1_2036_n_fl_s_lp          ; passed already [2841]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2842
            ld a, (hl)		; Hyp.cls 2843
            dec a		; Hyp.cls 2844
            jr nz, asm_1_2036_n_fl_s_lp          ; not in use (1) [2845]
            inc hl		; Hyp.cls 2846
            ld de, 63216 + 1		; Hyp.cls 2847
            ld b, 11		; Hyp.cls 2848
asm_1_2036_n_fl_s_cmp:		; Hyp.cls 2849
            ex de, hl		; Hyp.cls 2850
            call asm_1_2036_n_fl_peek		; Hyp.cls 2851
            ex de, hl		; Hyp.cls 2852
            and #7F		; Hyp.cls 2853
            cp '?'		; Hyp.cls 2854
            jr z, asm_1_2036_n_fl_s_any		; Hyp.cls 2855
            ld c, a		; Hyp.cls 2856
            ld a, (hl)		; Hyp.cls 2857
            and #7F		; Hyp.cls 2858
            cp c		; Hyp.cls 2859
            jr nz, asm_1_2036_n_fl_s_lp		; Hyp.cls 2860
asm_1_2036_n_fl_s_any:		; Hyp.cls 2861
            inc hl		; Hyp.cls 2862
            inc de		; Hyp.cls 2863
            djnz asm_1_2036_n_fl_s_cmp		; Hyp.cls 2864
            ld hl, (var_hyp_filecall_buf)          ; the entry: user 0, the name, extent 0, the records, no blocks [2865]
            ld (hl), 0		; Hyp.cls 2866
            ld de, 14		; Hyp.cls 2867
            add hl, de		; Hyp.cls 2868
            ld e, (hl)		; Hyp.cls 2869
            inc hl		; Hyp.cls 2870
            ld d, (hl)		; Hyp.cls 2871
            ex de, hl		; Hyp.cls 2872
            ld bc, 127		; Hyp.cls 2873
            add hl, bc		; Hyp.cls 2874
            jr c, asm_1_2036_n_fl_s_big		; Hyp.cls 2875
            ld a, h		; Hyp.cls 2876
            cp #40		; Hyp.cls 2877
            jr nc, asm_1_2036_n_fl_s_big		; Hyp.cls 2878
            sla l		; Hyp.cls 2879
            rla		; Hyp.cls 2880
            jr asm_1_2036_n_fl_s_rc		; Hyp.cls 2881
asm_1_2036_n_fl_s_big:		; Hyp.cls 2882
            ld a, 128		; Hyp.cls 2883
asm_1_2036_n_fl_s_rc:		; Hyp.cls 2884
            ex de, hl		; Hyp.cls 2885
            ld (hl), a		; Hyp.cls 2886
            ld b, 3		; Hyp.cls 2887
asm_1_2036_n_fl_s_z1:		; Hyp.cls 2888
            dec hl		; Hyp.cls 2889
            ld (hl), 0		; Hyp.cls 2890
            djnz asm_1_2036_n_fl_s_z1		; Hyp.cls 2891
            ld de, 4		; Hyp.cls 2892
            add hl, de		; Hyp.cls 2893
            ld b, 16		; Hyp.cls 2894
asm_1_2036_n_fl_s_z2:		; Hyp.cls 2895
            ld (hl), 0		; Hyp.cls 2896
            inc hl		; Hyp.cls 2897
            djnz asm_1_2036_n_fl_s_z2		; Hyp.cls 2898
            ld hl, (var_hyp_filecall_dma)		; Hyp.cls 2899
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2900
            ld b, 32		; Hyp.cls 2901
asm_1_2036_n_fl_s_put:		; Hyp.cls 2902
            ld a, (de)		; Hyp.cls 2903
            call asm_1_2036_n_fl_poke		; Hyp.cls 2904
            inc hl		; Hyp.cls 2905
            inc de		; Hyp.cls 2906
            djnz asm_1_2036_n_fl_s_put		; Hyp.cls 2907
            ld hl, 63216 + 12		; Hyp.cls 2908
            ld a, (asm_1_2036_n_fl_k)		; Hyp.cls 2909
            call asm_1_2036_n_fl_poke		; Hyp.cls 2910
            jp asm_1_2036_n_fl_ok		; Hyp.cls 2911
asm_1_2036_n_fl_skip:    db 0		; Hyp.cls 2912
asm_1_2036_n_fl_k:       db 0		; Hyp.cls 2913
asm_1_2036_n_fl_cn:      db 0                    ; the folder's entries in the cache (#6000) [2914]
asm_1_2036_n_fl_ranput:                          ; the FCB's r0-r2 = HL [2915]
            ex de, hl		; Hyp.cls 2916
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2917
            ld bc, 33		; Hyp.cls 2918
            add hl, bc		; Hyp.cls 2919
            ld a, e		; Hyp.cls 2920
            call asm_1_2036_n_fl_poke		; Hyp.cls 2921
            inc hl		; Hyp.cls 2922
            ld a, d		; Hyp.cls 2923
            call asm_1_2036_n_fl_poke		; Hyp.cls 2924
            inc hl		; Hyp.cls 2925
            xor a		; Hyp.cls 2926
            jp asm_1_2036_n_fl_poke		; Hyp.cls 2927
; ---- the parts
asm_1_2036_n_fl_isin:                            ; Z: the file being read is this slot's, this FCB [2929]
            ld a, (var_hyp_fin)		; Hyp.cls 2930
            ld hl, asm_1_2036_n_fl_infcb		; Hyp.cls 2931
            jr asm_1_2036_n_fl_is		; Hyp.cls 2932
asm_1_2036_n_fl_isout:		; Hyp.cls 2933
            ld a, (var_hyp_fout)		; Hyp.cls 2934
            ld hl, asm_1_2036_n_fl_outfcb		; Hyp.cls 2935
asm_1_2036_n_fl_is:		; Hyp.cls 2936
            ld b, a		; Hyp.cls 2937
            ld a, (asm_1_2036_n_fl_slot)		; Hyp.cls 2938
            cp b		; Hyp.cls 2939
            ret nz		; Hyp.cls 2940
            ld e, (hl)		; Hyp.cls 2941
            inc hl		; Hyp.cls 2942
            ld d, (hl)		; Hyp.cls 2943
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2944
            or a		; Hyp.cls 2945
            sbc hl, de		; Hyp.cls 2946
            ret		; Hyp.cls 2947
asm_1_2036_n_fl_inopen:                          ; open fl_name_s to read: carry = done [2948]
            call asm_1_2036_n_fl_plain		; Hyp.cls 2949
            ld hl, asm_1_2036_n_fl_name_s + 1		; Hyp.cls 2950
            ld a, (asm_1_2036_n_fl_name_s)		; Hyp.cls 2951
            ld b, a		; Hyp.cls 2952
            ld de, #4000		; Hyp.cls 2953
            call #BC77              ; CAS IN OPEN [2954]
            di		; Hyp.cls 2955
            ld (asm_1_2036_n_fl_hdr), hl         ; (its header: BDOS 30 #C7) [2956]
            ret		; Hyp.cls 2957
asm_1_2036_n_fl_inclose:		; Hyp.cls 2958
            xor a		; Hyp.cls 2959
            ld (var_hyp_fin), a		; Hyp.cls 2960
            call asm_1_2036_n_fl_plain		; Hyp.cls 2961
            call #BC7A              ; CAS IN CLOSE [2962]
            di		; Hyp.cls 2963
            ret		; Hyp.cls 2964
asm_1_2036_n_fl_rdrec:                           ; read up to fl_n bytes (128) into buf: A = how many (Z [2965]
            call asm_1_2036_n_fl_plain           ; none), HL past them. A #1A is a byte (the soft end of file) [2966]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2967
            ld a, (asm_1_2036_n_fl_n)		; Hyp.cls 2968
            ld b, a		; Hyp.cls 2969
asm_1_2036_n_fl_rr_lp:		; Hyp.cls 2970
            push bc		; Hyp.cls 2971
            push hl		; Hyp.cls 2972
            call #BC80              ; CAS IN CHAR [2973]
            di		; Hyp.cls 2974
            pop hl		; Hyp.cls 2975
            pop bc		; Hyp.cls 2976
            jr c, asm_1_2036_n_fl_rr_b		; Hyp.cls 2977
            cp #1A		; Hyp.cls 2978
            jr nz, asm_1_2036_n_fl_rr_end		; Hyp.cls 2979
asm_1_2036_n_fl_rr_b:		; Hyp.cls 2980
            ld (hl), a		; Hyp.cls 2981
            inc hl		; Hyp.cls 2982
            djnz asm_1_2036_n_fl_rr_lp		; Hyp.cls 2983
asm_1_2036_n_fl_rr_end:		; Hyp.cls 2984
            ld a, (asm_1_2036_n_fl_n)		; Hyp.cls 2985
            sub b		; Hyp.cls 2986
            ld c, a		; Hyp.cls 2987
            ld a, 128		; Hyp.cls 2988
            ld (asm_1_2036_n_fl_n), a            ; (128 again for the next) [2989]
            ld a, c		; Hyp.cls 2990
            or a		; Hyp.cls 2991
            ret		; Hyp.cls 2992
asm_1_2036_n_fl_fits:                            ; HL = a slot address, BC = bytes: NC = all in its 16K page. [2993]
            push hl                 ; Keeps BC, DE, HL [2994]
            ld a, h		; Hyp.cls 2995
            and #3F		; Hyp.cls 2996
            ld h, a		; Hyp.cls 2997
            add hl, bc		; Hyp.cls 2998
            ld a, h		; Hyp.cls 2999
            cp #40		; Hyp.cls 3000
            jr c, asm_1_2036_n_fl_ft_ok		; Hyp.cls 3001
            jr nz, asm_1_2036_n_fl_ft_no		; Hyp.cls 3002
            ld a, l		; Hyp.cls 3003
            or a		; Hyp.cls 3004
            jr nz, asm_1_2036_n_fl_ft_no		; Hyp.cls 3005
asm_1_2036_n_fl_ft_ok:		; Hyp.cls 3006
            pop hl		; Hyp.cls 3007
            or a		; Hyp.cls 3008
            ret		; Hyp.cls 3009
asm_1_2036_n_fl_ft_no:		; Hyp.cls 3010
            pop hl		; Hyp.cls 3011
            scf		; Hyp.cls 3012
            ret		; Hyp.cls 3013
asm_1_2036_n_fl_plain:                           ; the hypervisor's page in the window (the buffers) [3014]
            ld bc, (var_hyp_hps)		; Hyp.cls 3015
            out (c), c		; Hyp.cls 3016
            ret		; Hyp.cls 3017
asm_1_2036_n_fl_name:                            ; fl_name_s = the FCB's file: length, "B:NAME.EXT" [3018]
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3019
asm_1_2036_n_fl_namehl:                          ; (HL = an FCB in the slot) [3020]
            ld de, asm_1_2036_n_fl_name_s + 1		; Hyp.cls 3021
            call asm_1_2036_n_fl_peek            ; its drive: 0 = the slot's (or fl_dfl's) [3022]
            or a		; Hyp.cls 3023
            jr nz, asm_1_2036_n_fl_nm_d		; Hyp.cls 3024
            ld a, (asm_1_2036_n_fl_dfl)		; Hyp.cls 3025
            or a		; Hyp.cls 3026
            jr nz, asm_1_2036_n_fl_nm_d		; Hyp.cls 3027
            ld a, (var_hyp_filecall_drive)		; Hyp.cls 3028
            or a		; Hyp.cls 3029
            jr z, asm_1_2036_n_fl_nm_nod		; Hyp.cls 3030
            sub 64		; Hyp.cls 3031
asm_1_2036_n_fl_nm_d:		; Hyp.cls 3032
            add a, 64		; Hyp.cls 3033
            call asm_1_2036_n_fl_pfx             ; "B:", or B's path (UniDOS: "IDE:GAMES/") [3034]
asm_1_2036_n_fl_nm_nod:		; Hyp.cls 3035
            ld b, 11		; Hyp.cls 3036
asm_1_2036_n_fl_nm_lp:		; Hyp.cls 3037
            inc hl		; Hyp.cls 3038
            ld a, b		; Hyp.cls 3039
            cp 3		; Hyp.cls 3040
            jr nz, asm_1_2036_n_fl_nm_c		; Hyp.cls 3041
            ld a, '.'		; Hyp.cls 3042
            ld (de), a		; Hyp.cls 3043
            inc de		; Hyp.cls 3044
asm_1_2036_n_fl_nm_c:		; Hyp.cls 3045
            call asm_1_2036_n_fl_peek		; Hyp.cls 3046
            and #7F		; Hyp.cls 3047
            cp ' ' + 1		; Hyp.cls 3048
            jr c, asm_1_2036_n_fl_nm_sk		; Hyp.cls 3049
            ld (de), a		; Hyp.cls 3050
            inc de		; Hyp.cls 3051
asm_1_2036_n_fl_nm_sk:		; Hyp.cls 3052
            djnz asm_1_2036_n_fl_nm_lp		; Hyp.cls 3053
            ex de, hl		; Hyp.cls 3054
            ld de, asm_1_2036_n_fl_name_s + 1		; Hyp.cls 3055
            or a		; Hyp.cls 3056
            sbc hl, de		; Hyp.cls 3057
            ld a, l		; Hyp.cls 3058
            ld (asm_1_2036_n_fl_name_s), a		; Hyp.cls 3059
            ret		; Hyp.cls 3060
asm_1_2036_n_fl_ok:		; Hyp.cls 3061
            xor a		; Hyp.cls 3062
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 3063
asm_1_2036_n_fp_done:                            ; back to FileCall in main RAM (fp_done) [3064]
            ld sp, (asm_1_2036_n_fp_sp)		; Hyp.cls 3065
            ret		; Hyp.cls 3066
asm_1_2036_n_fl_era:     db "ER", "A" + #80		; Hyp.cls 3067
asm_1_2036_n_fl_rencmd:  db "RE", "N" + #80		; Hyp.cls 3068
asm_1_2036_n_fl_par2:    dw asm_1_2036_n_fl_desc, asm_1_2036_n_fl_desc2		; Hyp.cls 3069
asm_1_2036_n_fl_desc2:   db 0		; Hyp.cls 3070
            dw 0		; Hyp.cls 3071
asm_1_2036_n_fl_dfl:     db 0                    ; fl_name: the drive for an FCB whose own is 0 (rename) [3072]
asm_1_2036_n_fl_par:     dw asm_1_2036_n_fl_desc		; Hyp.cls 3073
asm_1_2036_n_fl_desc:    db 0		; Hyp.cls 3074
            dw 0		; Hyp.cls 3075
asm_1_2036_n_fl_n:       db 128                  ; bytes fl_rdrec reads [3076]
asm_1_2036_n_fl_cnt:     dw 0		; Hyp.cls 3077
asm_1_2036_n_fl_at:      dw 0		; Hyp.cls 3078
asm_1_2036_n_fl_infcb:   dw 0		; Hyp.cls 3079
asm_1_2036_n_fl_inrec:   dw 0		; Hyp.cls 3080
asm_1_2036_n_fl_want:    dw 0		; Hyp.cls 3081
asm_1_2036_n_fl_outfcb:  dw 0		; Hyp.cls 3082
asm_1_2036_n_fl_outrec:  dw 0                    ; the next record written (36) [3083]
asm_1_2036_n_fl_had:     db 0                    ; 35: this slot's read file closed for it [3084]
asm_1_2036_n_fp_sp:      dw 0		; Hyp.cls 3085
; ---- UniDOS: its Ctrl J BIOS command (found once, KL FIND COMMAND) - a drive letter can be a
; path (CD IDE:, CD SD:GAMES ...: any UniDOS device's folder), folders listed (examine). FL_MAP:
; letters A-P, 32 bytes each: the path's length (0 none: the letter itself, "B:"), the path
; ("IDE:GAMES/": a device or logical drive, its folders, the last "/" or ":"). Cleared when
; UniDOS is found, and only set with it: with AMSDOS no letter has a path. Up there with the
; names (48 characters: a path and NAME.EXT), BDOS 132's block, DIR's listing: the FILES.DIR
; cache is #6000-#7BFF (112 entries)
asm_1_2036_n_FL_CMAX:    equ 112                 ; the cache's entries [3093]
asm_1_2036_n_FL_NL:      equ 49                  ; a name: its length, then the characters [3094]
asm_1_2036_n_fl_name_s:  equ #7C00               ; length, then "B:NAME.EXT" (or "IDE:GAMES/NAME.EXT") [3095]
asm_1_2036_n_fl_inname:  equ asm_1_2036_n_fl_name_s + asm_1_2036_n_FL_NL   ; the one being read's (33 going back) [3096]
asm_1_2036_n_fl_new_s:   equ asm_1_2036_n_fl_inname + asm_1_2036_n_FL_NL   ; (23: the new name) [3097]
asm_1_2036_n_FL_UB:      equ #7D00               ; BDOS 132's block (72 bytes) [3098]
asm_1_2036_n_FL_EXK:     equ #7D48               ; the folder DIR lists (its path: length, 31 characters) [3099]
asm_1_2036_n_FL_DATE:    equ #7D68               ; a date examine gives (7), then a name (11) [3100]
asm_1_2036_n_FL_TN:      equ #7D70		; Hyp.cls 3101
asm_1_2036_n_FL_MAP:     equ #7E00		; Hyp.cls 3102
            ASSERT #6000 + asm_1_2036_n_FL_CMAX * 64 <= asm_1_2036_n_fl_name_s, "the search's cache, below the names"		; Hyp.cls 3103
            ASSERT asm_1_2036_n_fl_new_s + asm_1_2036_n_FL_NL <= asm_1_2036_n_FL_UB, "the names, below BDOS 132's block"		; Hyp.cls 3104
            ASSERT (asm_1_2036_n_FL_MAP & 255) = 0, "asm_1_2036_n_FL_MAP: a page's start (asm_1_2036_n_fl_mapa)"		; Hyp.cls 3105
asm_1_2036_n_fl_cjf:     db 0                    ; 0: not looked for yet, 1: UniDOS, 2: none [3106]
asm_1_2036_n_fl_cj:      dw 0                    ; Ctrl J's far address (address, ROM) [3107]
            db 0		; Hyp.cls 3108
asm_1_2036_n_fl_cjn:     db #8A                  ; (its name) [3109]
asm_1_2036_n_fl_exv:     db 0                    ; FL_EXK's listing is the one UniDOS examines now ... [3110]
asm_1_2036_n_fl_exi:     dw 0                    ; ... at this entry next [3111]
asm_1_2036_n_fl_ue:      dw 0		; Hyp.cls 3112
; carry: UniDOS here (the first time: looked for, the paths cleared)
asm_1_2036_n_fl_uni:		; Hyp.cls 3114
            ld a, (asm_1_2036_n_fl_cjf)		; Hyp.cls 3115
            cp 1		; Hyp.cls 3116
            jr z, asm_1_2036_n_fl_un_y		; Hyp.cls 3117
            or a		; Hyp.cls 3118
            ret nz                  ; (2: none - NC) [3119]
            ld hl, asm_1_2036_n_fl_cjn		; Hyp.cls 3120
            call #BCD4              ; KL FIND COMMAND: C = its ROM, HL = its address [3121]
            di		; Hyp.cls 3122
            ld a, 2		; Hyp.cls 3123
            jr nc, asm_1_2036_n_fl_un_s		; Hyp.cls 3124
            ld (asm_1_2036_n_fl_cj), hl		; Hyp.cls 3125
            ld a, c		; Hyp.cls 3126
            ld (asm_1_2036_n_fl_cj + 2), a		; Hyp.cls 3127
            ld hl, asm_1_2036_n_FL_MAP		; Hyp.cls 3128
            ld de, asm_1_2036_n_FL_MAP + 1		; Hyp.cls 3129
            ld bc, 511		; Hyp.cls 3130
            ld (hl), 0		; Hyp.cls 3131
            ldir		; Hyp.cls 3132
            ld a, 1		; Hyp.cls 3133
asm_1_2036_n_fl_un_s:		; Hyp.cls 3134
            ld (asm_1_2036_n_fl_cjf), a		; Hyp.cls 3135
            jr asm_1_2036_n_fl_uni		; Hyp.cls 3136
asm_1_2036_n_fl_un_y:		; Hyp.cls 3137
            scf		; Hyp.cls 3138
            ret		; Hyp.cls 3139
; Ctrl J command C (the other registers its input; its output back)
asm_1_2036_n_fl_cjc:		; Hyp.cls 3141
            rst #18                 ; (RST 3: a far call) [3142]
            dw asm_1_2036_n_fl_cj		; Hyp.cls 3143
            di		; Hyp.cls 3144
            ret		; Hyp.cls 3145
; A = a drive letter: HL = its FL_MAP entry, A = its path's length (Z: none). Carry: not A-P,
; or no UniDOS (no paths). A, HL only
asm_1_2036_n_fl_mapa:		; Hyp.cls 3148
            sub 'A'		; Hyp.cls 3149
            cp 16		; Hyp.cls 3150
            ccf		; Hyp.cls 3151
            ret c		; Hyp.cls 3152
            ld l, a		; Hyp.cls 3153
            ld a, (asm_1_2036_n_fl_cjf)		; Hyp.cls 3154
            cp 1		; Hyp.cls 3155
            scf		; Hyp.cls 3156
            ret nz		; Hyp.cls 3157
            ld h, 0		; Hyp.cls 3158
            add hl, hl		; Hyp.cls 3159
            add hl, hl		; Hyp.cls 3160
            add hl, hl		; Hyp.cls 3161
            add hl, hl		; Hyp.cls 3162
            add hl, hl		; Hyp.cls 3163
            ld a, h		; Hyp.cls 3164
            add a, asm_1_2036_n_FL_MAP / 256		; Hyp.cls 3165
            ld h, a		; Hyp.cls 3166
            ld a, (hl)		; Hyp.cls 3167
            or a		; Hyp.cls 3168
            ret		; Hyp.cls 3169
; A = a drive letter: "B:" at DE, or its path - DE past it (BC, HL kept)
asm_1_2036_n_fl_pfx:		; Hyp.cls 3171
            push af		; Hyp.cls 3172
            call asm_1_2036_n_fl_pfxm		; Hyp.cls 3173
            jr nz, asm_1_2036_n_fl_px_d		; Hyp.cls 3174
            pop af		; Hyp.cls 3175
            ld (de), a		; Hyp.cls 3176
            inc de		; Hyp.cls 3177
            ld a, ':'		; Hyp.cls 3178
            ld (de), a		; Hyp.cls 3179
            inc de		; Hyp.cls 3180
            ret		; Hyp.cls 3181
asm_1_2036_n_fl_px_d:		; Hyp.cls 3182
            pop af		; Hyp.cls 3183
            ret		; Hyp.cls 3184
; ... its path only, if it has one (NZ; Z: none, nothing put)
asm_1_2036_n_fl_pfxm:		; Hyp.cls 3186
            push hl		; Hyp.cls 3187
            call asm_1_2036_n_fl_mapa		; Hyp.cls 3188
            jr c, asm_1_2036_n_fl_pm_no		; Hyp.cls 3189
            jr z, asm_1_2036_n_fl_pm_no		; Hyp.cls 3190
            push bc		; Hyp.cls 3191
            ld c, a		; Hyp.cls 3192
            ld b, 0		; Hyp.cls 3193
            inc hl		; Hyp.cls 3194
            ldir		; Hyp.cls 3195
            pop bc		; Hyp.cls 3196
            or a		; Hyp.cls 3197
            jr asm_1_2036_n_fl_pm_r		; Hyp.cls 3198
asm_1_2036_n_fl_pm_no:		; Hyp.cls 3199
            xor a		; Hyp.cls 3200
asm_1_2036_n_fl_pm_r:		; Hyp.cls 3201
            pop hl		; Hyp.cls 3202
            ret		; Hyp.cls 3203
asm_1_2036_n_fl_nlen:                            ; fl_name_s's length: its characters end at DE [3204]
            ld hl, -(asm_1_2036_n_fl_name_s + 1)		; Hyp.cls 3205
            add hl, de		; Hyp.cls 3206
            ld a, l		; Hyp.cls 3207
            ld (asm_1_2036_n_fl_name_s), a		; Hyp.cls 3208
            ret		; Hyp.cls 3209
; the folder whose path is at fl_name_s + 1 to DE (fl_exdir2: fl_name_s, its length set)
; examined (Ctrl J 12): Z its listing ready (examine next: Ctrl J 13), NZ no UniDOS, a drive
; it can't examine (AMSDOS's floppies), not a folder
asm_1_2036_n_fl_exdir:		; Hyp.cls 3213
            call asm_1_2036_n_fl_nlen		; Hyp.cls 3214
asm_1_2036_n_fl_exdir2:		; Hyp.cls 3215
            call asm_1_2036_n_fl_uni		; Hyp.cls 3216
            jr nc, asm_1_2036_n_fl_ed_no		; Hyp.cls 3217
            xor a		; Hyp.cls 3218
            ld (asm_1_2036_n_fl_exv), a		; Hyp.cls 3219
            ld hl, asm_1_2036_n_fl_name_s		; Hyp.cls 3220
            ld b, (hl)		; Hyp.cls 3221
            inc hl		; Hyp.cls 3222
            ld ix, asm_1_2036_n_FL_DATE		; Hyp.cls 3223
            ld c, 12		; Hyp.cls 3224
            call asm_1_2036_n_fl_cjc		; Hyp.cls 3225
            ret c		; Hyp.cls 3226
asm_1_2036_n_fl_ed_no:		; Hyp.cls 3227
            ld a, 254               ; (254: no UniDOS, or a drive it can't examine) [3228]
            or a		; Hyp.cls 3229
            ret		; Hyp.cls 3230
; ---- 30: CP/M's set file attributes - not done here (255) - unless the block at DE (72 bytes)
; is CyborgOS's UniDOS call (CD, DIR): Byte(0) #C0 + the call (an FCB's drive byte is 0-16:
; never that), Byte(1) a drive letter (A-P). 255: no UniDOS (or a bad block). So Main sends it
; here with the other file calls, nothing of its own
;   0  UniDOS here: 0
;   1  the letter's path to Byte(2) (its length - 0 none -, the path)
;   2  the letter's path from Byte(2) (length, 31 at most - a "/" put at its end if it has no
;      "/" or ":" there -; 0: none, the letter itself again): it must be a folder (examined;
;      a drive UniDOS can't examine - DFA:, DFB:, AMSDOS's floppies - is taken as it is):
;      0 set, else UniDOS's error (not 0; 254 a drive it can't examine - a floppy AMSDOS has)
;   3  the devices (Ctrl J 1): 64 bytes at Byte(2) (names, the last character + #80, 255 the end)
;   4  a device (Ctrl J 2): its name at Byte(2) (the last character + #80) - 64 bytes at
;      Byte(8): the status (bit 0 there, 1 folders, 2 read only, 3 removable, 4 a stream, 5
;      the new API), -, free K (4 bytes), all K (4), the description (the last + #80)
;   5  the letter's folder's entry Word(2) (0 the first): Byte(4) its protection bits (bit 0
;      read only, 1 hidden, 2 system, 4 a folder), Byte(5-8) its size, Byte(9-15) its date (year
;      word, month, day, hours, minutes, seconds), Byte(16-26) its name (8 + 3): 0; 1 no more.
;      Byte(1) 0: the folder's path at Byte(28) (length, path) instead. One after another
;      (0, 1, 2 ...) each is the next examined, else the folder is examined again to it
;   6  a folder made: its path at Byte(2) (length, path ending "/": "IDE:GAMES/NEW/"): 0, else
;      UniDOS's error (255 also while a file is being written)
;   7  the header of the file this slot reads (the disc ROM's copy, 69 bytes - UniDOS's made-up
;      one for a file with none: its 24 bit length at 64 #800000) at Byte(2): 0; 255 none open
asm_1_2036_n_fl_unicall:		; Hyp.cls 3254
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3255
            ld de, asm_1_2036_n_FL_UB		; Hyp.cls 3256
            ld b, 72		; Hyp.cls 3257
asm_1_2036_n_fl_uc_in:		; Hyp.cls 3258
            call asm_1_2036_n_fl_peek		; Hyp.cls 3259
            ld (de), a		; Hyp.cls 3260
            inc hl		; Hyp.cls 3261
            inc de		; Hyp.cls 3262
            djnz asm_1_2036_n_fl_uc_in		; Hyp.cls 3263
            ld a, (asm_1_2036_n_FL_UB)		; Hyp.cls 3264
            sub #C0		; Hyp.cls 3265
            cp 8		; Hyp.cls 3266
            jp nc, asm_1_2036_n_fp_done          ; (CP/M's 30) [3267]
            ld (asm_1_2036_n_FL_UB), a		; Hyp.cls 3268
            call asm_1_2036_n_fl_uni		; Hyp.cls 3269
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 3270
            ld a, (asm_1_2036_n_FL_UB)		; Hyp.cls 3271
            or a		; Hyp.cls 3272
            jp z, asm_1_2036_n_fl_ok		; Hyp.cls 3273
            dec a		; Hyp.cls 3274
            jp z, asm_1_2036_n_fl_uc_get		; Hyp.cls 3275
            dec a		; Hyp.cls 3276
            jp z, asm_1_2036_n_fl_uc_set		; Hyp.cls 3277
            dec a		; Hyp.cls 3278
            jp z, asm_1_2036_n_fl_uc_dev		; Hyp.cls 3279
            dec a		; Hyp.cls 3280
            jp z, asm_1_2036_n_fl_uc_inf		; Hyp.cls 3281
            dec a		; Hyp.cls 3282
            jp z, asm_1_2036_n_fl_uc_dir		; Hyp.cls 3283
            dec a		; Hyp.cls 3284
            jr z, asm_1_2036_n_fl_uc_md		; Hyp.cls 3285
            ld a, (var_hyp_fin)           ; 7: the header of the file this slot reads (the disc ROM's, [3286]
            ld hl, asm_1_2036_n_fl_slot          ; from CAS IN OPEN: 69 bytes) to Byte(2) [3287]
            cp (hl)		; Hyp.cls 3288
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 3289
            ld hl, (asm_1_2036_n_fl_hdr)		; Hyp.cls 3290
            ld de, asm_1_2036_n_FL_UB + 2		; Hyp.cls 3291
            ld bc, 69		; Hyp.cls 3292
            ldir		; Hyp.cls 3293
            xor a		; Hyp.cls 3294
            ld b, 71		; Hyp.cls 3295
            jp asm_1_2036_n_fl_uc_back		; Hyp.cls 3296
asm_1_2036_n_fl_hdr:     dw 0		; Hyp.cls 3297
asm_1_2036_n_fl_uc_md:                           ; 6: a folder made (CAS OUT OPEN, the path ending "/") [3298]
            ld a, (var_hyp_fout)		; Hyp.cls 3299
            or a		; Hyp.cls 3300
            jp nz, asm_1_2036_n_fp_done		; Hyp.cls 3301
            ld hl, asm_1_2036_n_FL_UB + 2		; Hyp.cls 3302
            ld a, (hl)		; Hyp.cls 3303
            or a		; Hyp.cls 3304
            jp z, asm_1_2036_n_fp_done		; Hyp.cls 3305
            ld b, a		; Hyp.cls 3306
            inc hl		; Hyp.cls 3307
            ld de, #4800		; Hyp.cls 3308
            call #BC8C              ; CAS OUT OPEN [3309]
            di		; Hyp.cls 3310
            jr nc, asm_1_2036_n_fl_md_nc		; Hyp.cls 3311
            call #BC92              ; (a file: CAS OUT ABANDON - not made) [3312]
            di		; Hyp.cls 3313
            ld a, 1		; Hyp.cls 3314
            jr asm_1_2036_n_fl_md_r		; Hyp.cls 3315
asm_1_2036_n_fl_md_nc:		; Hyp.cls 3316
            and #7F		; Hyp.cls 3317
            cp #17                  ; (DSK_ERR_DIRECTORY_FOUND: made) [3318]
            jp z, asm_1_2036_n_fl_ok		; Hyp.cls 3319
            or a		; Hyp.cls 3320
            jr nz, asm_1_2036_n_fl_md_r		; Hyp.cls 3321
            inc a		; Hyp.cls 3322
asm_1_2036_n_fl_md_r:		; Hyp.cls 3323
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 3324
            jp asm_1_2036_n_fp_done		; Hyp.cls 3325
asm_1_2036_n_fl_uc_back:                         ; A the answer, the block's first B bytes back to the slot [3326]
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 3327
            ld a, (asm_1_2036_n_FL_UB)		; Hyp.cls 3328
            add a, #C0		; Hyp.cls 3329
            ld (asm_1_2036_n_FL_UB), a		; Hyp.cls 3330
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3331
            ld de, asm_1_2036_n_FL_UB		; Hyp.cls 3332
asm_1_2036_n_fl_uc_out:		; Hyp.cls 3333
            ld a, (de)		; Hyp.cls 3334
            call asm_1_2036_n_fl_poke		; Hyp.cls 3335
            inc hl		; Hyp.cls 3336
            inc de		; Hyp.cls 3337
            djnz asm_1_2036_n_fl_uc_out		; Hyp.cls 3338
            jp asm_1_2036_n_fp_done		; Hyp.cls 3339
asm_1_2036_n_fl_uc_get:		; Hyp.cls 3340
            ld a, (asm_1_2036_n_FL_UB + 1)		; Hyp.cls 3341
            call asm_1_2036_n_fl_mapa		; Hyp.cls 3342
            jp c, asm_1_2036_n_fp_done		; Hyp.cls 3343
            ld de, asm_1_2036_n_FL_UB + 2		; Hyp.cls 3344
            ld c, (hl)		; Hyp.cls 3345
            ld b, 0		; Hyp.cls 3346
            inc bc		; Hyp.cls 3347
            ldir		; Hyp.cls 3348
            xor a		; Hyp.cls 3349
            ld b, 34		; Hyp.cls 3350
            jr asm_1_2036_n_fl_uc_back		; Hyp.cls 3351
asm_1_2036_n_fl_uc_dev:		; Hyp.cls 3352
            ld de, asm_1_2036_n_FL_UB + 2		; Hyp.cls 3353
            ld c, 1		; Hyp.cls 3354
            call asm_1_2036_n_fl_cjc		; Hyp.cls 3355
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 3356
            xor a		; Hyp.cls 3357
            ld b, 66		; Hyp.cls 3358
            jr asm_1_2036_n_fl_uc_back		; Hyp.cls 3359
asm_1_2036_n_fl_uc_inf:		; Hyp.cls 3360
            ld hl, asm_1_2036_n_FL_UB + 2		; Hyp.cls 3361
            ld de, asm_1_2036_n_FL_UB + 8		; Hyp.cls 3362
            ld c, 2		; Hyp.cls 3363
            call asm_1_2036_n_fl_cjc		; Hyp.cls 3364
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 3365
            xor a		; Hyp.cls 3366
            ld b, 72		; Hyp.cls 3367
            jr asm_1_2036_n_fl_uc_back		; Hyp.cls 3368
asm_1_2036_n_fl_uc_set:		; Hyp.cls 3369
            ld a, (asm_1_2036_n_FL_UB + 1)		; Hyp.cls 3370
            call asm_1_2036_n_fl_mapa		; Hyp.cls 3371
            jp c, asm_1_2036_n_fp_done		; Hyp.cls 3372
            ld (asm_1_2036_n_fl_ue), hl		; Hyp.cls 3373
            xor a		; Hyp.cls 3374
            ld (asm_1_2036_n_fl_exv), a		; Hyp.cls 3375
            ld a, (asm_1_2036_n_FL_UB + 2)		; Hyp.cls 3376
            or a		; Hyp.cls 3377
            jr z, asm_1_2036_n_fl_us_put         ; none: the letter itself again [3378]
            cp 32		; Hyp.cls 3379
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 3380
            ld b, a		; Hyp.cls 3381
            ld hl, asm_1_2036_n_FL_UB + 3		; Hyp.cls 3382
asm_1_2036_n_fl_us_up:                           ; capitals [3383]
            ld a, (hl)		; Hyp.cls 3384
            cp 'a'		; Hyp.cls 3385
            jr c, asm_1_2036_n_fl_us_c		; Hyp.cls 3386
            cp 'z' + 1		; Hyp.cls 3387
            jr nc, asm_1_2036_n_fl_us_c		; Hyp.cls 3388
            sub 32		; Hyp.cls 3389
            ld (hl), a		; Hyp.cls 3390
asm_1_2036_n_fl_us_c:		; Hyp.cls 3391
            inc hl		; Hyp.cls 3392
            djnz asm_1_2036_n_fl_us_up		; Hyp.cls 3393
            dec hl		; Hyp.cls 3394
            ld a, (hl)		; Hyp.cls 3395
            cp ':'		; Hyp.cls 3396
            jr z, asm_1_2036_n_fl_us_ex		; Hyp.cls 3397
            cp '/'		; Hyp.cls 3398
            jr z, asm_1_2036_n_fl_us_ex		; Hyp.cls 3399
            ld a, (asm_1_2036_n_FL_UB + 2)		; Hyp.cls 3400
            cp 31		; Hyp.cls 3401
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 3402
            inc a		; Hyp.cls 3403
            ld (asm_1_2036_n_FL_UB + 2), a		; Hyp.cls 3404
            inc hl		; Hyp.cls 3405
            ld (hl), '/'		; Hyp.cls 3406
asm_1_2036_n_fl_us_ex:		; Hyp.cls 3407
            ld hl, asm_1_2036_n_FL_UB + 2        ; a folder? [3408]
            ld de, asm_1_2036_n_fl_name_s		; Hyp.cls 3409
            ld bc, 32		; Hyp.cls 3410
            ldir		; Hyp.cls 3411
            call asm_1_2036_n_fl_exdir2		; Hyp.cls 3412
            jr z, asm_1_2036_n_fl_us_put		; Hyp.cls 3413
            cp 254		; Hyp.cls 3414
            jr z, asm_1_2036_n_fl_us_put         ; (a floppy AMSDOS runs - DFA:, DFB: - can't be examined: taken) [3415]
            or a		; Hyp.cls 3416
            jr nz, asm_1_2036_n_fl_us_err		; Hyp.cls 3417
            inc a		; Hyp.cls 3418
asm_1_2036_n_fl_us_err:		; Hyp.cls 3419
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 3420
            jp asm_1_2036_n_fp_done		; Hyp.cls 3421
asm_1_2036_n_fl_us_put:		; Hyp.cls 3422
            ld hl, asm_1_2036_n_FL_UB + 2		; Hyp.cls 3423
            ld de, (asm_1_2036_n_fl_ue)		; Hyp.cls 3424
            ld bc, 32		; Hyp.cls 3425
            ldir		; Hyp.cls 3426
            jp asm_1_2036_n_fl_ok		; Hyp.cls 3427
asm_1_2036_n_fl_uc_dir:		; Hyp.cls 3428
            ld de, asm_1_2036_n_fl_name_s + 1    ; the folder's path [3429]
            ld a, (asm_1_2036_n_FL_UB + 1)		; Hyp.cls 3430
            or a		; Hyp.cls 3431
            jr z, asm_1_2036_n_fl_ud_p		; Hyp.cls 3432
            call asm_1_2036_n_fl_pfx		; Hyp.cls 3433
            jr asm_1_2036_n_fl_ud_k		; Hyp.cls 3434
asm_1_2036_n_fl_ud_p:		; Hyp.cls 3435
            ld hl, asm_1_2036_n_FL_UB + 28		; Hyp.cls 3436
            ld a, (hl)		; Hyp.cls 3437
            cp 32		; Hyp.cls 3438
            jp nc, asm_1_2036_n_fp_done		; Hyp.cls 3439
            ld c, a		; Hyp.cls 3440
            ld b, 0		; Hyp.cls 3441
            inc hl		; Hyp.cls 3442
            ldir		; Hyp.cls 3443
asm_1_2036_n_fl_ud_k:		; Hyp.cls 3444
            call asm_1_2036_n_fl_nlen		; Hyp.cls 3445
            ld hl, asm_1_2036_n_fl_name_s        ; the same folder, still the one examined, at this entry: [3446]
            ld de, asm_1_2036_n_FL_EXK           ; on from there [3447]
            ld a, (asm_1_2036_n_fl_exv)		; Hyp.cls 3448
            or a		; Hyp.cls 3449
            jr z, asm_1_2036_n_fl_ud_new		; Hyp.cls 3450
            ld a, (hl)		; Hyp.cls 3451
            inc a		; Hyp.cls 3452
            ld b, a		; Hyp.cls 3453
asm_1_2036_n_fl_ud_cmp:		; Hyp.cls 3454
            ld a, (de)		; Hyp.cls 3455
            cp (hl)		; Hyp.cls 3456
            jr nz, asm_1_2036_n_fl_ud_new		; Hyp.cls 3457
            inc hl		; Hyp.cls 3458
            inc de		; Hyp.cls 3459
            djnz asm_1_2036_n_fl_ud_cmp		; Hyp.cls 3460
            ld hl, (asm_1_2036_n_fl_exi)		; Hyp.cls 3461
            ld de, (asm_1_2036_n_FL_UB + 2)		; Hyp.cls 3462
            or a		; Hyp.cls 3463
            sbc hl, de		; Hyp.cls 3464
            jr z, asm_1_2036_n_fl_ud_next		; Hyp.cls 3465
asm_1_2036_n_fl_ud_new:		; Hyp.cls 3466
            ld hl, asm_1_2036_n_fl_name_s		; Hyp.cls 3467
            ld de, asm_1_2036_n_FL_EXK		; Hyp.cls 3468
            ld bc, 32		; Hyp.cls 3469
            ldir		; Hyp.cls 3470
            call asm_1_2036_n_fl_exdir2		; Hyp.cls 3471
            jr z, asm_1_2036_n_fl_ud_ok		; Hyp.cls 3472
            or a		; Hyp.cls 3473
            jr nz, asm_1_2036_n_fl_us_err		; Hyp.cls 3474
            inc a		; Hyp.cls 3475
            jr asm_1_2036_n_fl_us_err		; Hyp.cls 3476
asm_1_2036_n_fl_ud_ok:		; Hyp.cls 3477
            ld hl, 0		; Hyp.cls 3478
            ld (asm_1_2036_n_fl_exi), hl		; Hyp.cls 3479
            ld a, 1		; Hyp.cls 3480
            ld (asm_1_2036_n_fl_exv), a		; Hyp.cls 3481
asm_1_2036_n_fl_ud_skip:                         ; on to entry Word(2) [3482]
            ld hl, (asm_1_2036_n_fl_exi)		; Hyp.cls 3483
            ld de, (asm_1_2036_n_FL_UB + 2)		; Hyp.cls 3484
            or a		; Hyp.cls 3485
            sbc hl, de		; Hyp.cls 3486
            jr z, asm_1_2036_n_fl_ud_next		; Hyp.cls 3487
            ld hl, asm_1_2036_n_FL_TN		; Hyp.cls 3488
            ld ix, asm_1_2036_n_FL_DATE		; Hyp.cls 3489
            ld c, 13		; Hyp.cls 3490
            call asm_1_2036_n_fl_cjc		; Hyp.cls 3491
            jr nc, asm_1_2036_n_fl_ud_end		; Hyp.cls 3492
            jr nz, asm_1_2036_n_fl_ud_end		; Hyp.cls 3493
            ld hl, (asm_1_2036_n_fl_exi)		; Hyp.cls 3494
            inc hl		; Hyp.cls 3495
            ld (asm_1_2036_n_fl_exi), hl		; Hyp.cls 3496
            jr asm_1_2036_n_fl_ud_skip		; Hyp.cls 3497
asm_1_2036_n_fl_ud_next:		; Hyp.cls 3498
            ld hl, asm_1_2036_n_FL_UB + 16		; Hyp.cls 3499
            ld ix, asm_1_2036_n_FL_UB + 9		; Hyp.cls 3500
            ld c, 13		; Hyp.cls 3501
            call asm_1_2036_n_fl_cjc		; Hyp.cls 3502
            jr nc, asm_1_2036_n_fl_ud_end		; Hyp.cls 3503
            jr nz, asm_1_2036_n_fl_ud_end		; Hyp.cls 3504
            ld (asm_1_2036_n_FL_UB + 4), a		; Hyp.cls 3505
            ld (asm_1_2036_n_FL_UB + 5), de		; Hyp.cls 3506
            ld (asm_1_2036_n_FL_UB + 7), bc		; Hyp.cls 3507
            ld hl, (asm_1_2036_n_fl_exi)		; Hyp.cls 3508
            inc hl		; Hyp.cls 3509
            ld (asm_1_2036_n_fl_exi), hl		; Hyp.cls 3510
            xor a		; Hyp.cls 3511
            ld b, 28		; Hyp.cls 3512
            jp asm_1_2036_n_fl_uc_back		; Hyp.cls 3513
asm_1_2036_n_fl_ud_end:		; Hyp.cls 3514
            xor a		; Hyp.cls 3515
            ld (asm_1_2036_n_fl_exv), a		; Hyp.cls 3516
            inc a		; Hyp.cls 3517
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 3518
            jp asm_1_2036_n_fp_done		; Hyp.cls 3519
asm_1_2036_n_fp_end:		; Hyp.cls 3520
            ASSERT asm_1_2036_n_fp_end <= #6000, "FileCall's page code: below the search's cache (#6000)"		; Hyp.cls 3521
; ---- the service page's code (window data from #6000, copied there by FileCall 99)
            ds #6000 - $		; Hyp.cls 3677
asm_1_3589_n_sv_go:		; Hyp.cls 3678
            ld (asm_1_3589_n_sv_sp), sp		; Hyp.cls 3679
            ld hl, (var_hyp_svc_p)            ; the request (16 bytes) from the slot [3680]
            ld de, (var_hyp_svc_setting)		; Hyp.cls 3681
            call asm_1_3589_n_sv_sw		; Hyp.cls 3682
            push bc		; Hyp.cls 3683
            pop ix		; Hyp.cls 3684
            ld iy, (var_hyp_svp)		; Hyp.cls 3685
            ld de, asm_1_3589_n_sv_blk		; Hyp.cls 3686
            ld a, 16		; Hyp.cls 3687
            call asm_1_3589_n_sv_dx		; Hyp.cls 3688
            ld hl, (asm_1_3589_n_sv_blk + 8)     ; how many: 2K at most [3689]
            bit 7, h		; Hyp.cls 3690
            jr nz, asm_1_3589_n_sv_n2		; Hyp.cls 3691
            ld de, 2049		; Hyp.cls 3692
            or a		; Hyp.cls 3693
            sbc hl, de		; Hyp.cls 3694
            add hl, de		; Hyp.cls 3695
            jr c, asm_1_3589_n_sv_n1		; Hyp.cls 3696
asm_1_3589_n_sv_n2:		; Hyp.cls 3697
            ld hl, 2048		; Hyp.cls 3698
asm_1_3589_n_sv_n1:		; Hyp.cls 3699
            ld (asm_1_3589_n_sv_n), hl		; Hyp.cls 3700
            xor a		; Hyp.cls 3701
            ld (asm_1_3589_n_sv_stop), a		; Hyp.cls 3702
            ld a, 2                 ; (the copies to the slot: its bank) [3703]
            ld (asm_1_3589_n_sv_dk), a		; Hyp.cls 3704
            ld hl, (var_hyp_svc_setting)		; Hyp.cls 3705
            ld (asm_1_3589_n_sv_ds), hl		; Hyp.cls 3706
            ld hl, (asm_1_3589_n_sv_blk + 6)		; Hyp.cls 3707
            ld (asm_1_3589_n_sv_da), hl		; Hyp.cls 3708
            ld a, (asm_1_3589_n_sv_blk)		; Hyp.cls 3709
            cp 10		; Hyp.cls 3710
            jp z, asm_1_3589_n_sv_mem		; Hyp.cls 3711
            cp 11		; Hyp.cls 3712
            jp z, asm_1_3589_n_sv_ptr		; Hyp.cls 3713
            cp 13		; Hyp.cls 3714
            jp z, asm_1_3589_n_sv_store		; Hyp.cls 3715
            cp 14		; Hyp.cls 3716
            jp z, asm_1_3589_n_sv_store		; Hyp.cls 3717
            cp 15		; Hyp.cls 3718
            jp z, asm_1_3589_n_sv_tab		; Hyp.cls 3719
asm_1_3589_n_sv_err:		; Hyp.cls 3720
            ld sp, (asm_1_3589_n_sv_sp)		; Hyp.cls 3721
            ld a, 255		; Hyp.cls 3722
            ret		; Hyp.cls 3723
asm_1_3589_n_sv_ok:		; Hyp.cls 3724
            ld sp, (asm_1_3589_n_sv_sp)		; Hyp.cls 3725
            xor a		; Hyp.cls 3726
            ret		; Hyp.cls 3727
; 10: memory
asm_1_3589_n_sv_mem:		; Hyp.cls 3729
            ld hl, (asm_1_3589_n_sv_blk + 4)		; Hyp.cls 3730
            ld (asm_1_3589_n_sv_sa), hl		; Hyp.cls 3731
            ld hl, (asm_1_3589_n_sv_blk + 2)		; Hyp.cls 3732
            ld a, (asm_1_3589_n_sv_blk + 1)		; Hyp.cls 3733
            or a		; Hyp.cls 3734
            jr nz, asm_1_3589_n_sv_m1		; Hyp.cls 3735
            ld de, (mem_count)      ; 0: a page (below Pages) [3736]
            push hl		; Hyp.cls 3737
            or a		; Hyp.cls 3738
            sbc hl, de		; Hyp.cls 3739
            pop hl		; Hyp.cls 3740
            jp nc, asm_1_3589_n_sv_err		; Hyp.cls 3741
            call asm_1_3589_n_sv_pgset		; Hyp.cls 3742
            ld (asm_1_3589_n_sv_ss), bc		; Hyp.cls 3743
            ld a, 1		; Hyp.cls 3744
            ld (asm_1_3589_n_sv_stop), a		; Hyp.cls 3745
            jr asm_1_3589_n_sv_mgo		; Hyp.cls 3746
asm_1_3589_n_sv_m1:		; Hyp.cls 3747
            dec a		; Hyp.cls 3748
            jr nz, asm_1_3589_n_sv_m2		; Hyp.cls 3749
            ld (asm_1_3589_n_sv_ss), hl          ; 1: a ROM [3750]
            ld a, 1		; Hyp.cls 3751
            ld (asm_1_3589_n_sv_stop), a		; Hyp.cls 3752
            ld a, 3		; Hyp.cls 3753
            jr asm_1_3589_n_sv_mgo1		; Hyp.cls 3754
asm_1_3589_n_sv_m2:		; Hyp.cls 3755
            dec a		; Hyp.cls 3756
            jr nz, asm_1_3589_n_sv_m3		; Hyp.cls 3757
            ld a, 4                 ; 2: main RAM [3758]
            jr asm_1_3589_n_sv_mgo1		; Hyp.cls 3759
asm_1_3589_n_sv_m3:		; Hyp.cls 3760
            dec a		; Hyp.cls 3761
            jp nz, asm_1_3589_n_sv_err		; Hyp.cls 3762
            call asm_1_3589_n_sv_slot            ; 3: a slot's memory (one in use) [3763]
            jp z, asm_1_3589_n_sv_err		; Hyp.cls 3764
            ld (asm_1_3589_n_sv_ss), de		; Hyp.cls 3765
            ld a, 2		; Hyp.cls 3766
            jr asm_1_3589_n_sv_mgo1		; Hyp.cls 3767
asm_1_3589_n_sv_mgo:		; Hyp.cls 3768
            ld a, 1		; Hyp.cls 3769
asm_1_3589_n_sv_mgo1:		; Hyp.cls 3770
            ld (asm_1_3589_n_sv_sk), a		; Hyp.cls 3771
            call asm_1_3589_n_sv_copy		; Hyp.cls 3772
            jr asm_1_3589_n_sv_ok		; Hyp.cls 3773
; HL = a slot number: Z when it isn't one in use, else DE = its RAM setting
asm_1_3589_n_sv_slot:		; Hyp.cls 3775
            ld a, h		; Hyp.cls 3776
            or a		; Hyp.cls 3777
            jr nz, asm_1_3589_n_sv_sl0		; Hyp.cls 3778
            or l		; Hyp.cls 3779
            ret z		; Hyp.cls 3780
            ld de, (var_hyp_svns)		; Hyp.cls 3781
            ld a, (de)		; Hyp.cls 3782
            cp l		; Hyp.cls 3783
            jr c, asm_1_3589_n_sv_sl0		; Hyp.cls 3784
            add hl, hl		; Hyp.cls 3785
            push hl		; Hyp.cls 3786
            ld de, (var_hyp_svst)		; Hyp.cls 3787
            add hl, de		; Hyp.cls 3788
            ld a, (hl)		; Hyp.cls 3789
            pop hl		; Hyp.cls 3790
            or a		; Hyp.cls 3791
            ret z		; Hyp.cls 3792
            ld de, (var_hyp_svsg)		; Hyp.cls 3793
            add hl, de		; Hyp.cls 3794
            ld e, (hl)		; Hyp.cls 3795
            inc hl		; Hyp.cls 3796
            ld d, (hl)		; Hyp.cls 3797
            or 1                    ; (NZ) [3798]
            ret		; Hyp.cls 3799
asm_1_3589_n_sv_sl0:		; Hyp.cls 3800
            xor a		; Hyp.cls 3801
            ret		; Hyp.cls 3802
; 13 / 14: a 2K block of the store (13 from the slot, 14 to it)
asm_1_3589_n_sv_store:		; Hyp.cls 3804
            ld hl, (asm_1_3589_n_sv_blk + 2)		; Hyp.cls 3805
            ld a, h		; Hyp.cls 3806
            or a		; Hyp.cls 3807
            jp nz, asm_1_3589_n_sv_err		; Hyp.cls 3808
            ld a, l		; Hyp.cls 3809
            and 7		; Hyp.cls 3810
            add a, a		; Hyp.cls 3811
            add a, a		; Hyp.cls 3812
            add a, a		; Hyp.cls 3813
            ld (asm_1_3589_n_sv_sa + 1), a       ; the block's place in its page [3814]
            xor a		; Hyp.cls 3815
            ld (asm_1_3589_n_sv_sa), a		; Hyp.cls 3816
            srl l		; Hyp.cls 3817
            srl l		; Hyp.cls 3818
            srl l		; Hyp.cls 3819
            ld h, #FF               ; its page: the slot's byte at #FF00 + block / 8 [3820]
            ld de, (var_hyp_svc_setting)		; Hyp.cls 3821
            call asm_1_3589_n_sv_sw		; Hyp.cls 3822
            push bc		; Hyp.cls 3823
            pop ix		; Hyp.cls 3824
            ld iy, (var_hyp_svp)		; Hyp.cls 3825
            ld de, asm_1_3589_n_sv_tmp		; Hyp.cls 3826
            ld a, 1		; Hyp.cls 3827
            call asm_1_3589_n_sv_dx		; Hyp.cls 3828
            ld a, (asm_1_3589_n_sv_tmp)		; Hyp.cls 3829
            or a		; Hyp.cls 3830
            jp z, asm_1_3589_n_sv_err		; Hyp.cls 3831
            ld l, a		; Hyp.cls 3832
            ld h, 0		; Hyp.cls 3833
            call asm_1_3589_n_sv_pgset		; Hyp.cls 3834
            ld (asm_1_3589_n_sv_ss), bc		; Hyp.cls 3835
            ld a, 1		; Hyp.cls 3836
            ld (asm_1_3589_n_sv_sk), a		; Hyp.cls 3837
            ld a, (asm_1_3589_n_sv_blk)		; Hyp.cls 3838
            cp 14		; Hyp.cls 3839
            jr z, asm_1_3589_n_sv_st1		; Hyp.cls 3840
            ld hl, (asm_1_3589_n_sv_sa)          ; 13: the slot to the page [3841]
            ld (asm_1_3589_n_sv_da), hl		; Hyp.cls 3842
            ld hl, (asm_1_3589_n_sv_ss)		; Hyp.cls 3843
            ld (asm_1_3589_n_sv_ds), hl		; Hyp.cls 3844
            ld a, 1		; Hyp.cls 3845
            ld (asm_1_3589_n_sv_dk), a		; Hyp.cls 3846
            ld hl, (asm_1_3589_n_sv_blk + 6)		; Hyp.cls 3847
            ld (asm_1_3589_n_sv_sa), hl		; Hyp.cls 3848
            ld hl, (var_hyp_svc_setting)		; Hyp.cls 3849
            ld (asm_1_3589_n_sv_ss), hl		; Hyp.cls 3850
            ld a, 2		; Hyp.cls 3851
            ld (asm_1_3589_n_sv_sk), a		; Hyp.cls 3852
asm_1_3589_n_sv_st1:		; Hyp.cls 3853
            call asm_1_3589_n_sv_copy		; Hyp.cls 3854
            jp asm_1_3589_n_sv_ok		; Hyp.cls 3855
; 11: the pointer, while the slot is in front
asm_1_3589_n_sv_ptr:		; Hyp.cls 3857
            ld hl, (var_hyp_svfr)		; Hyp.cls 3858
            ld a, (hl)		; Hyp.cls 3859
            ld hl, var_hyp_svc_t		; Hyp.cls 3860
            cp (hl)		; Hyp.cls 3861
            jp nz, asm_1_3589_n_sv_ok		; Hyp.cls 3862
            ld a, (var_hyp_pon)		; Hyp.cls 3863
            or a		; Hyp.cls 3864
            call nz, asm_1_3589_n_pt_xor		; Hyp.cls 3865
            xor a		; Hyp.cls 3866
            ld (var_hyp_pon), a		; Hyp.cls 3867
            ld a, (asm_1_3589_n_sv_blk + 1)		; Hyp.cls 3868
            or a		; Hyp.cls 3869
            jp z, asm_1_3589_n_sv_ok		; Hyp.cls 3870
            ld a, (asm_1_3589_n_sv_blk + 2)		; Hyp.cls 3871
            ld hl, var_hyp_scc		; Hyp.cls 3872
            cp (hl)		; Hyp.cls 3873
            jp nc, asm_1_3589_n_sv_ok            ; (off the screen: none) [3874]
            ld (var_hyp_pox), a		; Hyp.cls 3875
            ld a, (asm_1_3589_n_sv_blk + 3)		; Hyp.cls 3876
            ld (var_hyp_poy), a		; Hyp.cls 3877
            call asm_1_3589_n_pt_xor		; Hyp.cls 3878
            ld a, 1		; Hyp.cls 3879
            ld (var_hyp_pon), a		; Hyp.cls 3880
            jp asm_1_3589_n_sv_ok		; Hyp.cls 3881
asm_1_3589_n_pt_xor:                             ; the checkerboard XORed at pox, poy (the screen is main RAM) [3882]
            ld a, (var_hyp_poy)		; Hyp.cls 3883
            ld e, a		; Hyp.cls 3884
            ld d, 0		; Hyp.cls 3885
            ld hl, 0		; Hyp.cls 3886
            ld a, (var_hyp_scc)		; Hyp.cls 3887
            ld b, 8		; Hyp.cls 3888
asm_1_3589_n_pt_mul:		; Hyp.cls 3889
            add hl, hl		; Hyp.cls 3890
            rlca		; Hyp.cls 3891
            jr nc, asm_1_3589_n_pt_mn		; Hyp.cls 3892
            add hl, de		; Hyp.cls 3893
asm_1_3589_n_pt_mn:		; Hyp.cls 3894
            djnz asm_1_3589_n_pt_mul		; Hyp.cls 3895
            ld a, (var_hyp_pox)		; Hyp.cls 3896
            ld e, a		; Hyp.cls 3897
            add hl, de		; Hyp.cls 3898
            ld de, (var_hyp_sco)		; Hyp.cls 3899
            add hl, de		; Hyp.cls 3900
            ld a, h		; Hyp.cls 3901
            and #07		; Hyp.cls 3902
            or #C0		; Hyp.cls 3903
            ld h, a		; Hyp.cls 3904
            ld b, 4		; Hyp.cls 3905
asm_1_3589_n_pt_ln:		; Hyp.cls 3906
            ld a, (hl)		; Hyp.cls 3907
            xor #AA		; Hyp.cls 3908
            ld (hl), a		; Hyp.cls 3909
            ld a, h		; Hyp.cls 3910
            add a, 8		; Hyp.cls 3911
            ld h, a		; Hyp.cls 3912
            ld a, (hl)		; Hyp.cls 3913
            xor #55		; Hyp.cls 3914
            ld (hl), a		; Hyp.cls 3915
            ld a, h		; Hyp.cls 3916
            add a, 8		; Hyp.cls 3917
            ld h, a		; Hyp.cls 3918
            djnz asm_1_3589_n_pt_ln		; Hyp.cls 3919
            ret		; Hyp.cls 3920
; 15: a table
asm_1_3589_n_sv_tab:		; Hyp.cls 3922
            ld hl, (asm_1_3589_n_sv_blk + 2)		; Hyp.cls 3923
            ld (asm_1_3589_n_sv_da), hl		; Hyp.cls 3924
            ld a, (asm_1_3589_n_sv_blk + 1)		; Hyp.cls 3925
            or a		; Hyp.cls 3926
            jr z, asm_1_3589_n_sv_t0		; Hyp.cls 3927
            dec a		; Hyp.cls 3928
            jp z, asm_1_3589_n_sv_t1		; Hyp.cls 3929
            dec a		; Hyp.cls 3930
            jp z, asm_1_3589_n_sv_t2		; Hyp.cls 3931
            dec a		; Hyp.cls 3932
            jp z, asm_1_3589_n_sv_t3		; Hyp.cls 3933
            jp asm_1_3589_n_sv_err		; Hyp.cls 3934
; 0: the slots - a word how many, then from 16 a record each: state, in front, MODE, the name's
; length, the name
asm_1_3589_n_sv_t0:		; Hyp.cls 3937
            call asm_1_3589_n_sv_clr		; Hyp.cls 3938
            ld hl, (var_hyp_svns)		; Hyp.cls 3939
            ld a, (hl)		; Hyp.cls 3940
            ld (asm_1_3589_n_sv_rec), a		; Hyp.cls 3941
            ld (asm_1_3589_n_sv_tn), a		; Hyp.cls 3942
            call asm_1_3589_n_sv_out16		; Hyp.cls 3943
            ld a, 1		; Hyp.cls 3944
            ld (asm_1_3589_n_sv_tj), a		; Hyp.cls 3945
asm_1_3589_n_sv_t0lp:		; Hyp.cls 3946
            ld a, (asm_1_3589_n_sv_tn)		; Hyp.cls 3947
            ld b, a		; Hyp.cls 3948
            ld a, (asm_1_3589_n_sv_tj)		; Hyp.cls 3949
            cp b		; Hyp.cls 3950
            jr z, asm_1_3589_n_sv_t0a		; Hyp.cls 3951
            jp nc, asm_1_3589_n_sv_ok		; Hyp.cls 3952
asm_1_3589_n_sv_t0a:		; Hyp.cls 3953
            ld hl, (asm_1_3589_n_sv_da)		; Hyp.cls 3954
            ld de, 16		; Hyp.cls 3955
            add hl, de		; Hyp.cls 3956
            ld (asm_1_3589_n_sv_da), hl		; Hyp.cls 3957
            call asm_1_3589_n_sv_clr		; Hyp.cls 3958
            ld a, (asm_1_3589_n_sv_tj)		; Hyp.cls 3959
            ld l, a		; Hyp.cls 3960
            ld h, 0		; Hyp.cls 3961
            add hl, hl		; Hyp.cls 3962
            ld de, (var_hyp_svst)		; Hyp.cls 3963
            add hl, de		; Hyp.cls 3964
            ld a, (hl)		; Hyp.cls 3965
            ld (asm_1_3589_n_sv_rec), a          ; its state [3966]
            ld hl, (var_hyp_svfr)		; Hyp.cls 3967
            ld a, (asm_1_3589_n_sv_tj)		; Hyp.cls 3968
            cp (hl)		; Hyp.cls 3969
            jr nz, asm_1_3589_n_sv_t0b		; Hyp.cls 3970
            ld a, 1		; Hyp.cls 3971
            ld (asm_1_3589_n_sv_rec + 1), a      ; in front [3972]
asm_1_3589_n_sv_t0b:		; Hyp.cls 3973
            ld a, (asm_1_3589_n_sv_rec)		; Hyp.cls 3974
            or a		; Hyp.cls 3975
            jr z, asm_1_3589_n_sv_t0d		; Hyp.cls 3976
            ld a, (asm_1_3589_n_sv_tj)           ; its RAM setting [3977]
            ld l, a		; Hyp.cls 3978
            ld h, 0		; Hyp.cls 3979
            add hl, hl		; Hyp.cls 3980
            ld de, (var_hyp_svsg)		; Hyp.cls 3981
            add hl, de		; Hyp.cls 3982
            ld e, (hl)		; Hyp.cls 3983
            inc hl		; Hyp.cls 3984
            ld d, (hl)		; Hyp.cls 3985
            ld (asm_1_3589_n_sv_tsg), de		; Hyp.cls 3986
            ld hl, 63113          ; MODE [3987]
            ld a, 1		; Hyp.cls 3988
            call asm_1_3589_n_sv_from		; Hyp.cls 3989
            ld a, (asm_1_3589_n_sv_tmp)		; Hyp.cls 3990
            ld (asm_1_3589_n_sv_rec + 2), a		; Hyp.cls 3991
            ld a, (asm_1_3589_n_sv_rec)		; Hyp.cls 3992
            cp 2		; Hyp.cls 3993
            jr nz, asm_1_3589_n_sv_t0d		; Hyp.cls 3994
            ld de, (asm_1_3589_n_sv_tsg)		; Hyp.cls 3995
            ld hl, #F6D8            ; the program's name: its length, then 12 [3996]
            ld a, 13		; Hyp.cls 3997
            call asm_1_3589_n_sv_from		; Hyp.cls 3998
            ld a, (asm_1_3589_n_sv_tmp)		; Hyp.cls 3999
            cp 13		; Hyp.cls 4000
            jr c, asm_1_3589_n_sv_t0c		; Hyp.cls 4001
            ld a, 12		; Hyp.cls 4002
asm_1_3589_n_sv_t0c:		; Hyp.cls 4003
            ld (asm_1_3589_n_sv_rec + 3), a		; Hyp.cls 4004
            ld hl, asm_1_3589_n_sv_tmp + 1		; Hyp.cls 4005
            ld de, asm_1_3589_n_sv_rec + 4		; Hyp.cls 4006
            ld bc, 12		; Hyp.cls 4007
            ldir		; Hyp.cls 4008
asm_1_3589_n_sv_t0d:		; Hyp.cls 4009
            ld hl, asm_1_3589_n_sv_tj		; Hyp.cls 4010
            push hl		; Hyp.cls 4011
            call asm_1_3589_n_sv_out16		; Hyp.cls 4012
            pop hl		; Hyp.cls 4013
            inc (hl)		; Hyp.cls 4014
            jp asm_1_3589_n_sv_t0lp		; Hyp.cls 4015
; 1: the memory - words: the tables' end, the top, the pages, total K, free pages; from 16 a byte a page
asm_1_3589_n_sv_t1:		; Hyp.cls 4017
            call asm_1_3589_n_sv_clr		; Hyp.cls 4018
            ld hl, (mem_tend)		; Hyp.cls 4019
            ld (asm_1_3589_n_sv_rec), hl		; Hyp.cls 4020
            call mem_top		; Hyp.cls 4021
            ld (asm_1_3589_n_sv_rec + 2), hl		; Hyp.cls 4022
            ld hl, (mem_count)		; Hyp.cls 4023
            ld (asm_1_3589_n_sv_rec + 4), hl		; Hyp.cls 4024
            call mem_ramsize		; Hyp.cls 4025
            ld (asm_1_3589_n_sv_rec + 6), hl		; Hyp.cls 4026
            call mem_freepages		; Hyp.cls 4027
            ld (asm_1_3589_n_sv_rec + 8), hl		; Hyp.cls 4028
            ld hl, asm_1_3589_n_sv_rec		; Hyp.cls 4029
            ld de, (asm_1_3589_n_sv_da)		; Hyp.cls 4030
            ld bc, 18               ; (and pages 0, 1: 0) [4031]
            call asm_1_3589_n_sv_out		; Hyp.cls 4032
            ld hl, (mem_count)      ; pages 2 on: the RAT (2030 at most) [4033]
            dec hl		; Hyp.cls 4034
            ld a, h		; Hyp.cls 4035
            or l		; Hyp.cls 4036
            jp z, asm_1_3589_n_sv_ok		; Hyp.cls 4037
            ld de, 2031		; Hyp.cls 4038
            or a		; Hyp.cls 4039
            sbc hl, de		; Hyp.cls 4040
            add hl, de		; Hyp.cls 4041
            jr c, asm_1_3589_n_sv_t1a		; Hyp.cls 4042
            ld hl, 2030		; Hyp.cls 4043
asm_1_3589_n_sv_t1a:		; Hyp.cls 4044
            ld (asm_1_3589_n_sv_n), hl		; Hyp.cls 4045
            ld hl, (mem_ttype)		; Hyp.cls 4046
            inc hl		; Hyp.cls 4047
            ld (asm_1_3589_n_sv_sa), hl		; Hyp.cls 4048
            ld hl, (asm_1_3589_n_sv_blk + 2)		; Hyp.cls 4049
            ld de, 18		; Hyp.cls 4050
            add hl, de		; Hyp.cls 4051
            ld (asm_1_3589_n_sv_da), hl		; Hyp.cls 4052
            xor a		; Hyp.cls 4053
            ld (asm_1_3589_n_sv_sk), a		; Hyp.cls 4054
            ld (asm_1_3589_n_sv_stop), a		; Hyp.cls 4055
            call asm_1_3589_n_sv_copy		; Hyp.cls 4056
            jp asm_1_3589_n_sv_ok		; Hyp.cls 4057
; 2: the upper ROMs 0-31 - 64 bytes each: the first 16, then 48 of the name table (0s if none)
asm_1_3589_n_sv_t2:		; Hyp.cls 4059
            xor a		; Hyp.cls 4060
            ld (asm_1_3589_n_sv_tj), a		; Hyp.cls 4061
asm_1_3589_n_sv_t2lp:		; Hyp.cls 4062
            call asm_1_3589_n_sv_clr		; Hyp.cls 4063
            ld a, (asm_1_3589_n_sv_tj)		; Hyp.cls 4064
            ld c, a		; Hyp.cls 4065
            call #B90F              ; KL ROM SELECT (#C000 only: this code at #6000 stays) [4066]
            di		; Hyp.cls 4067
            push bc		; Hyp.cls 4068
            ld hl, #C000		; Hyp.cls 4069
            ld de, asm_1_3589_n_sv_rec		; Hyp.cls 4070
            ld bc, 16		; Hyp.cls 4071
            ldir		; Hyp.cls 4072
            ld hl, (asm_1_3589_n_sv_rec + 4)		; Hyp.cls 4073
            ld a, h		; Hyp.cls 4074
            and #C0		; Hyp.cls 4075
            cp #C0		; Hyp.cls 4076
            jr nz, asm_1_3589_n_sv_t2a		; Hyp.cls 4077
            ld de, #FF90		; Hyp.cls 4078
            or a		; Hyp.cls 4079
            sbc hl, de		; Hyp.cls 4080
            add hl, de		; Hyp.cls 4081
            jr nc, asm_1_3589_n_sv_t2a		; Hyp.cls 4082
            ld de, asm_1_3589_n_sv_rec + 16		; Hyp.cls 4083
            ld bc, 48		; Hyp.cls 4084
            ldir		; Hyp.cls 4085
asm_1_3589_n_sv_t2a:		; Hyp.cls 4086
            pop bc		; Hyp.cls 4087
            call #B918              ; KL ROM DESELECT [4088]
            di		; Hyp.cls 4089
            ld hl, asm_1_3589_n_sv_rec		; Hyp.cls 4090
            ld de, (asm_1_3589_n_sv_da)		; Hyp.cls 4091
            ld bc, 64		; Hyp.cls 4092
            call asm_1_3589_n_sv_out		; Hyp.cls 4093
            ld hl, (asm_1_3589_n_sv_da)		; Hyp.cls 4094
            ld de, 64		; Hyp.cls 4095
            add hl, de		; Hyp.cls 4096
            ld (asm_1_3589_n_sv_da), hl		; Hyp.cls 4097
            ld hl, asm_1_3589_n_sv_tj		; Hyp.cls 4098
            inc (hl)		; Hyp.cls 4099
            ld a, (hl)		; Hyp.cls 4100
            cp 32		; Hyp.cls 4101
            jr c, asm_1_3589_n_sv_t2lp		; Hyp.cls 4102
            jp asm_1_3589_n_sv_ok		; Hyp.cls 4103
; 3: the RAM discs - the driver's table (its page, #6A00: 128 bytes), 0s if none
asm_1_3589_n_sv_t3:		; Hyp.cls 4105
            call asm_1_3589_n_sv_clr		; Hyp.cls 4106
            ld hl, (var_hyp_svdp)		; Hyp.cls 4107
            ld e, (hl)		; Hyp.cls 4108
            inc hl		; Hyp.cls 4109
            ld d, (hl)		; Hyp.cls 4110
            ld a, d		; Hyp.cls 4111
            or e		; Hyp.cls 4112
            jr z, asm_1_3589_n_sv_t3a		; Hyp.cls 4113
            ex de, hl		; Hyp.cls 4114
            call asm_1_3589_n_sv_pgset		; Hyp.cls 4115
            ld (asm_1_3589_n_sv_ss), bc		; Hyp.cls 4116
            ld hl, #6A00		; Hyp.cls 4117
            ld (asm_1_3589_n_sv_sa), hl		; Hyp.cls 4118
            ld hl, 128		; Hyp.cls 4119
            ld (asm_1_3589_n_sv_n), hl		; Hyp.cls 4120
            ld a, 1		; Hyp.cls 4121
            ld (asm_1_3589_n_sv_sk), a		; Hyp.cls 4122
            xor a		; Hyp.cls 4123
            ld (asm_1_3589_n_sv_stop), a		; Hyp.cls 4124
            call asm_1_3589_n_sv_copy		; Hyp.cls 4125
            jp asm_1_3589_n_sv_ok		; Hyp.cls 4126
asm_1_3589_n_sv_t3a:		; Hyp.cls 4127
            ld hl, asm_1_3589_n_sv_rec		; Hyp.cls 4128
            ld de, (asm_1_3589_n_sv_da)		; Hyp.cls 4129
            ld bc, 128		; Hyp.cls 4130
            call asm_1_3589_n_sv_out		; Hyp.cls 4131
            jp asm_1_3589_n_sv_ok		; Hyp.cls 4132
; sv_from - A bytes from slot (sv_tsg's) HL into sv_tmp
asm_1_3589_n_sv_from:		; Hyp.cls 4134
            ld de, (asm_1_3589_n_sv_tsg)		; Hyp.cls 4135
            push af		; Hyp.cls 4136
            call asm_1_3589_n_sv_sw		; Hyp.cls 4137
            push bc		; Hyp.cls 4138
            pop ix		; Hyp.cls 4139
            ld iy, (var_hyp_svp)		; Hyp.cls 4140
            ld de, asm_1_3589_n_sv_tmp		; Hyp.cls 4141
            pop af		; Hyp.cls 4142
            jp asm_1_3589_n_sv_dx		; Hyp.cls 4143
; sv_clr - sv_rec (128 bytes) 0
asm_1_3589_n_sv_clr:		; Hyp.cls 4145
            ld hl, asm_1_3589_n_sv_rec		; Hyp.cls 4146
            ld de, asm_1_3589_n_sv_rec + 1		; Hyp.cls 4147
            ld bc, 127		; Hyp.cls 4148
            ld (hl), 0		; Hyp.cls 4149
            ldir		; Hyp.cls 4150
            ret		; Hyp.cls 4151
; sv_out16 - sv_rec's first 16 to the slot at sv_da; sv_out - BC bytes from HL (here) to the slot's DE
asm_1_3589_n_sv_out16:		; Hyp.cls 4153
            ld hl, asm_1_3589_n_sv_rec		; Hyp.cls 4154
            ld de, (asm_1_3589_n_sv_da)		; Hyp.cls 4155
            ld bc, 16		; Hyp.cls 4156
asm_1_3589_n_sv_out:		; Hyp.cls 4157
            ld (asm_1_3589_n_sv_sa), hl		; Hyp.cls 4158
            ld (asm_1_3589_n_sv_da), de		; Hyp.cls 4159
            ld (asm_1_3589_n_sv_n), bc		; Hyp.cls 4160
            ld a, 1		; Hyp.cls 4161
            ld (asm_1_3589_n_sv_sk), a		; Hyp.cls 4162
            ld hl, (var_hyp_svp)		; Hyp.cls 4163
            ld (asm_1_3589_n_sv_ss), hl		; Hyp.cls 4164
            xor a		; Hyp.cls 4165
            ld (asm_1_3589_n_sv_stop), a		; Hyp.cls 4166
            ld hl, (asm_1_3589_n_sv_da)		; Hyp.cls 4167
            push hl		; Hyp.cls 4168
            call asm_1_3589_n_sv_copy		; Hyp.cls 4169
            pop hl		; Hyp.cls 4170
            ld (asm_1_3589_n_sv_da), hl          ; (where it went: kept) [4171]
            ret		; Hyp.cls 4172
; sv_copy - sv_n bytes from the source (sv_sk: 0 main RAM outside the window, 1 a page - RAM setting
; sv_ss, 2 a bank - C2 setting sv_ss, 3 ROM sv_ss, 4 main RAM anywhere) at sv_sa to the
; destination (sv_dk: 1 a page, 2 a bank; sv_ds) at sv_da, 128 at most a go, none across a 16K
; page's end; sv_stop: at the source's page end, stop
asm_1_3589_n_sv_copy:		; Hyp.cls 4177
            ld hl, (asm_1_3589_n_sv_n)		; Hyp.cls 4178
            ld a, h		; Hyp.cls 4179
            or l		; Hyp.cls 4180
            ret z		; Hyp.cls 4181
            ld bc, 128		; Hyp.cls 4182
            or a		; Hyp.cls 4183
            sbc hl, bc		; Hyp.cls 4184
            add hl, bc		; Hyp.cls 4185
            jr nc, asm_1_3589_n_sc_c1		; Hyp.cls 4186
            ld b, h		; Hyp.cls 4187
            ld c, l		; Hyp.cls 4188
asm_1_3589_n_sc_c1:		; Hyp.cls 4189
            ld (asm_1_3589_n_sv_c), bc		; Hyp.cls 4190
            ld a, (asm_1_3589_n_sv_sk)		; Hyp.cls 4191
            or a		; Hyp.cls 4192
            jr z, asm_1_3589_n_sc_dl		; Hyp.cls 4193
            ld hl, (asm_1_3589_n_sv_sa)		; Hyp.cls 4194
            call asm_1_3589_n_sc_room		; Hyp.cls 4195
asm_1_3589_n_sc_dl:		; Hyp.cls 4196
            ld hl, (asm_1_3589_n_sv_da)		; Hyp.cls 4197
            call asm_1_3589_n_sc_room		; Hyp.cls 4198
            ld a, (asm_1_3589_n_sv_sk)           ; the source: IX its RAM setting, HL where [4199]
            ld hl, (asm_1_3589_n_sv_sa)		; Hyp.cls 4200
            ld ix, 0		; Hyp.cls 4201
            or a		; Hyp.cls 4202
            jr z, asm_1_3589_n_sc_sok		; Hyp.cls 4203
            cp 1		; Hyp.cls 4204
            jr nz, asm_1_3589_n_sc_s2		; Hyp.cls 4205
            ld ix, (asm_1_3589_n_sv_ss)		; Hyp.cls 4206
            call asm_1_3589_n_sc_win		; Hyp.cls 4207
            jr asm_1_3589_n_sc_sok		; Hyp.cls 4208
asm_1_3589_n_sc_s2:		; Hyp.cls 4209
            cp 2		; Hyp.cls 4210
            jr nz, asm_1_3589_n_sc_s3		; Hyp.cls 4211
            ld de, (asm_1_3589_n_sv_ss)		; Hyp.cls 4212
            call asm_1_3589_n_sv_sw		; Hyp.cls 4213
            push bc		; Hyp.cls 4214
            pop ix		; Hyp.cls 4215
            jr asm_1_3589_n_sc_sok		; Hyp.cls 4216
asm_1_3589_n_sc_s3:		; Hyp.cls 4217
            cp 3		; Hyp.cls 4218
            jr nz, asm_1_3589_n_sc_s4		; Hyp.cls 4219
            ld a, (asm_1_3589_n_sv_ss)           ; a ROM: its bytes into buf first [4220]
            ld c, a		; Hyp.cls 4221
            call #B90F              ; KL ROM SELECT [4222]
            di		; Hyp.cls 4223
            push bc		; Hyp.cls 4224
            ld hl, (asm_1_3589_n_sv_sa)		; Hyp.cls 4225
            ld a, h		; Hyp.cls 4226
            or #C0		; Hyp.cls 4227
            ld h, a		; Hyp.cls 4228
            ld de, (var_hyp_svc_buf)		; Hyp.cls 4229
            ld bc, (asm_1_3589_n_sv_c)		; Hyp.cls 4230
            ldir		; Hyp.cls 4231
            pop bc		; Hyp.cls 4232
            call #B918              ; KL ROM DESELECT [4233]
            di		; Hyp.cls 4234
            ld hl, (var_hyp_svc_buf)		; Hyp.cls 4235
            jr asm_1_3589_n_sc_sok		; Hyp.cls 4236
asm_1_3589_n_sc_s4:		; Hyp.cls 4237
            ld a, h                 ; main RAM: its #4000-#7FFF is page 1 [4238]
            and #C0		; Hyp.cls 4239
            cp #40		; Hyp.cls 4240
            jr nz, asm_1_3589_n_sc_sok		; Hyp.cls 4241
            push hl		; Hyp.cls 4242
            ld hl, 1		; Hyp.cls 4243
            call asm_1_3589_n_sv_pgset		; Hyp.cls 4244
            pop hl		; Hyp.cls 4245
            push bc		; Hyp.cls 4246
            pop ix		; Hyp.cls 4247
asm_1_3589_n_sc_sok:		; Hyp.cls 4248
            push hl		; Hyp.cls 4249
            ld a, (asm_1_3589_n_sv_dk)           ; the destination: IY, DE [4250]
            ld hl, (asm_1_3589_n_sv_da)		; Hyp.cls 4251
            cp 1		; Hyp.cls 4252
            jr nz, asm_1_3589_n_sc_d2		; Hyp.cls 4253
            ld iy, (asm_1_3589_n_sv_ds)		; Hyp.cls 4254
            call asm_1_3589_n_sc_win		; Hyp.cls 4255
            jr asm_1_3589_n_sc_dok		; Hyp.cls 4256
asm_1_3589_n_sc_d2:		; Hyp.cls 4257
            ld de, (asm_1_3589_n_sv_ds)		; Hyp.cls 4258
            call asm_1_3589_n_sv_sw		; Hyp.cls 4259
            push bc		; Hyp.cls 4260
            pop iy		; Hyp.cls 4261
asm_1_3589_n_sc_dok:		; Hyp.cls 4262
            ex de, hl		; Hyp.cls 4263
            pop hl		; Hyp.cls 4264
            ld a, (asm_1_3589_n_sv_c)		; Hyp.cls 4265
            call asm_1_3589_n_sv_dx		; Hyp.cls 4266
            ld bc, (asm_1_3589_n_sv_c)		; Hyp.cls 4267
            ld hl, (asm_1_3589_n_sv_sa)		; Hyp.cls 4268
            add hl, bc		; Hyp.cls 4269
            ld (asm_1_3589_n_sv_sa), hl		; Hyp.cls 4270
            ld hl, (asm_1_3589_n_sv_da)		; Hyp.cls 4271
            add hl, bc		; Hyp.cls 4272
            ld (asm_1_3589_n_sv_da), hl		; Hyp.cls 4273
            ld hl, (asm_1_3589_n_sv_n)		; Hyp.cls 4274
            or a		; Hyp.cls 4275
            sbc hl, bc		; Hyp.cls 4276
            ld (asm_1_3589_n_sv_n), hl		; Hyp.cls 4277
            ld a, (asm_1_3589_n_sv_stop)		; Hyp.cls 4278
            or a		; Hyp.cls 4279
            jp z, asm_1_3589_n_sv_copy		; Hyp.cls 4280
            ld a, (asm_1_3589_n_sv_sa + 1)		; Hyp.cls 4281
            and #3F		; Hyp.cls 4282
            ld b, a		; Hyp.cls 4283
            ld a, (asm_1_3589_n_sv_sa)		; Hyp.cls 4284
            or b		; Hyp.cls 4285
            jp nz, asm_1_3589_n_sv_copy		; Hyp.cls 4286
            ret		; Hyp.cls 4287
asm_1_3589_n_sc_room:                            ; sv_c no more than to HL's 16K page's end [4288]
            ld a, h		; Hyp.cls 4289
            and #3F		; Hyp.cls 4290
            ld h, a		; Hyp.cls 4291
            ex de, hl		; Hyp.cls 4292
            ld hl, 16384		; Hyp.cls 4293
            or a		; Hyp.cls 4294
            sbc hl, de		; Hyp.cls 4295
            ld de, (asm_1_3589_n_sv_c)		; Hyp.cls 4296
            or a		; Hyp.cls 4297
            sbc hl, de		; Hyp.cls 4298
            ret nc		; Hyp.cls 4299
            add hl, de		; Hyp.cls 4300
            ld (asm_1_3589_n_sv_c), hl		; Hyp.cls 4301
            ret		; Hyp.cls 4302
asm_1_3589_n_sc_win:                             ; HL: its place in the window [4303]
            ld a, h		; Hyp.cls 4304
            and #3F		; Hyp.cls 4305
            or #40		; Hyp.cls 4306
            ld h, a		; Hyp.cls 4307
            ret		; Hyp.cls 4308
; sv_sw - DE = a bank's C2 setting, HL = an address in it: BC = the setting with its page in the
; window, HL = the address there
asm_1_3589_n_sv_sw:		; Hyp.cls 4311
            ld a, h		; Hyp.cls 4312
            rlca		; Hyp.cls 4313
            rlca		; Hyp.cls 4314
            and 3		; Hyp.cls 4315
            add a, 4		; Hyp.cls 4316
            ld b, a		; Hyp.cls 4317
            ld a, e		; Hyp.cls 4318
            and #F8		; Hyp.cls 4319
            or b		; Hyp.cls 4320
            ld c, a		; Hyp.cls 4321
            ld b, d		; Hyp.cls 4322
            jr asm_1_3589_n_sc_win		; Hyp.cls 4323
; sv_pgset - HL = a page: BC = its RAM setting (the Memory class's port table; 0 main RAM)
asm_1_3589_n_sv_pgset:		; Hyp.cls 4325
            ld a, h		; Hyp.cls 4326
            or l		; Hyp.cls 4327
            ld bc, #7FC0		; Hyp.cls 4328
            ret z		; Hyp.cls 4329
            add hl, hl		; Hyp.cls 4330
            ld de, (mem_tport)		; Hyp.cls 4331
            add hl, de		; Hyp.cls 4332
            dec hl		; Hyp.cls 4333
            ld b, (hl)		; Hyp.cls 4334
            dec hl		; Hyp.cls 4335
            ld c, (hl)		; Hyp.cls 4336
            ret		; Hyp.cls 4337
asm_1_3589_n_sv_sp:      dw 0		; Hyp.cls 4338
asm_1_3589_n_sv_n:       dw 0		; Hyp.cls 4339
asm_1_3589_n_sv_c:       dw 0		; Hyp.cls 4340
asm_1_3589_n_sv_sk:      db 0		; Hyp.cls 4341
asm_1_3589_n_sv_ss:      dw 0		; Hyp.cls 4342
asm_1_3589_n_sv_sa:      dw 0		; Hyp.cls 4343
asm_1_3589_n_sv_dk:      db 0		; Hyp.cls 4344
asm_1_3589_n_sv_ds:      dw 0		; Hyp.cls 4345
asm_1_3589_n_sv_da:      dw 0		; Hyp.cls 4346
asm_1_3589_n_sv_stop:    db 0		; Hyp.cls 4347
asm_1_3589_n_sv_tj:      db 0		; Hyp.cls 4348
asm_1_3589_n_sv_tn:      db 0		; Hyp.cls 4349
asm_1_3589_n_sv_tsg:     dw 0		; Hyp.cls 4350
asm_1_3589_n_sv_blk:     ds 16		; Hyp.cls 4351
asm_1_3589_n_sv_tmp:     ds 16		; Hyp.cls 4352
asm_1_3589_n_sv_rec:     ds 128		; Hyp.cls 4353
asm_1_3589_n_sv_end:		; Hyp.cls 4354
            ASSERT asm_1_3589_n_sv_end <= #8000, "the service page's code"		; Hyp.cls 4355
			ENDM
; ============================================================
; NTC program - generated by NTC BASIC (VB style BASIC to NTC)
; platform: cpcfw (Amstrad CPC - firmware text and keys), starts in normal mode
; ============================================================

			DEVICE AMSTRADCPC6128		; for SAVEAMSDOS at the end
			org #0040

NTC_TERM	equ 0		; Option Terminal: 0 none, 1 VT52, 2 ANSI (CP/M)
NTC_STRMAX	equ 82		; the longest string (library buffers, temps)
NTC_MEMBANKS	equ 64		; Option Memory: the most 64K banks the Memory class looks for
NTC_ROMENABLE	equ 1		; Option RomEnable (cpcfw, cpcmin): the start code starts the ROMs
NTC_ROMLIB	equ 0		; 1 = the library is the keyword ROM (Library: ROM; ntcRomAsm builds it)
NTC_WINHOLE	equ 1		; 1 = the program is built round an Option Reserve range over the window #4000-#7FFF
NTC_BUFSIZE	equ 128		; the library's buffer (ntc_buf: FileSystem, Memory.Copy): Option Buffer
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
			ld (ntc_csp), sp
			ld a, (#BC77)		; Option RomEnable: start the ROMs again
			cp #DF			; AMSDOS has the cassette calls: they are running
			jp z, ntc_roms_on
			ei
			ld de, ntc_free		; the lowest address the ROMs may use (above the arrays)
			ld hl, #ABFF		; the highest (as usual for AMSDOS: it takes about #A700-#ABFF)
			call #BCCB		; KL ROM WALK: every background ROM
			inc hl			; the first byte the ROMs took
			ld (ntc_roms_at), hl
			ld de, #A600
			or a
			sbc hl, de
			jp nc, ntc_roms_fit	; AMSDOS alone (or no more): as usual
			ld hl, (ntc_roms_at)
			ld de, -16
			add hl, de		; the event block under the ROMs' RAM: the new top
			ld (ntc_fwblk), hl
			ld (ntc_fwtop), hl
			ld de, ntc_free
			or a
			sbc hl, de
			jp nc, ntc_roms_fit	; the program still ends below it
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
			ld hl, ntc_isl_tick
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

			; Main.bas 84: Mode 2
			dw kw_model, 2

			; Main.bas 85: Hyp.Vdu 0                         ' the firmware's text off (TXT VDU DISABLE): AMSDOS says "NAME.CYB not
			dw p_hyp_vdu_c, lit_0

			; Main.bas 89: k = Memory.Banks()
			dw fn_memory_banks, var_k

			; Main.bas 90: If k < 4 Then Hyp.Vdu 1 : Print "CyborgOS needs 320K (a 256K expansion) or more" : End
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

			; Main.bas 91: ns = k \ 2                                      ' half the banks are slots (the first bank never:
			dw kw_divvl, var_k, 2, var_ns

			; Main.bas 92: If ns > MAXS Then ns = MAXS                     ' its pages are the hypervisor's)
			dw kw_scpgtvl, var_ns, 20
			dw kw_goto_iffalse_n, if2_1
			dw kw_ltov, 20, var_ns
if2_1:

			; Main.bas 93: Hot.Slots ns                                    ' (more than 10: Control + a number twice is 11-20)
			dw p_hot_slots_c, var_ns

			; Main.bas 97: i = Memory.AllocPage(Memory.TypeUser)           ' (page 1)
			dw fn_memory_allocpage, lit_85, var_i

			; Main.bas 98: hp = Memory.AllocPage(Memory.TypeUser)          ' bank 1's page 0 (C4): the disc buffers ...
			dw fn_memory_allocpage, lit_85, var_hp

			; Main.bas 99: Memory.SelectPage hp
			dw fn_memory_selectpage, var_hp, var_memory_selectpage_selectpage

			; Main.bas 100: Hyp.UsePage                                     ' (its RAM setting, for Hyp.FileCall)
			dw fn_hyp_usepage

			; Main.bas 101: Hyp.FontInit                                    ' (the font into it, at #5000)
			dw fn_hyp_fontinit

			; Main.bas 104: i = Memory.AllocPage(Memory.TypeUser)           ' bank 1's page 1 (C5): the services (Hyp.Svc: BDOS
			dw fn_memory_allocpage, lit_85, var_i

			; Main.bas 105: Memory.SelectPage i                             ' 131 ops 10-15), out of main RAM
			dw fn_memory_selectpage, var_i, var_memory_selectpage_selectpage

			; Main.bas 106: Hyp.UseSvc
			dw fn_hyp_usesvc

			; Main.bas 107: Hyp.SvcVars VarPtr(st), VarPtr(sg), VarPtr(ns), VarPtr(front), VarPtr(dp)
			dw p_hyp_svcvars_c, vp_arr_st, vp_arr_sg, vp_var_ns, vp_var_front, vp_var_dp

			; Main.bas 109: i = Hyp.FileCall(99, 0, 0, 0, 0, 0, VarPtr(rb))  ' (the bank image and FileCall's page code into it,
			dw p_hyp_filecall_c, lit_99, lit_0, lit_0, lit_0, lit_0, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_i

			; Main.bas 114: i = Hyp.Svc(0, 0, 0, VarPtr(rb))                ' (the services' code into the service page: #6000 on)
			dw p_hyp_svc_c, lit_0, lit_0, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_svc_svc, var_i

			; Main.bas 116: For i = 1 To ns
			dw kw_ltov, 1, var_i
			dw kw_vtov, var_ns, for3_l
			dw kw_forupv_n, var_i, for3_l, for3_e
for3_t:

			; Main.bas 117: bk(i) = Memory.AllocBank()
			dw fn_memory_allocbank, var_memory_allocbank_allocbank
			dw kw_aset, arr_bk, var_i, var_memory_allocbank_allocbank

			; Main.bas 118: Memory.SelectPage Memory.BankPage(bk(i), 0)
			dw kw_aget, arr_bk, var_i, tmp0
			dw p_memory_bankpage_c, tmp0, lit_0
			dw fn_memory_selectpage, var_memory_bankpage_bankpage, var_memory_selectpage_selectpage

			; Main.bas 119: sg(i) = Hyp.Setting()
			dw fn_hyp_setting, var_hyp_setting_setting
			dw kw_aset, arr_sg, var_i, var_hyp_setting_setting

			; Main.bas 120: wp(i) = (sg(i) And &HFFF8) Or 7                ' its page 3 (#C000-#FFFF: OBUF, the console) in the window
			dw kw_aget, arr_sg, var_i, tmp1
			dw kw_andvl, tmp1, -8, tmp1
			dw kw_orvl, tmp1, 7, tmp1
			dw kw_aset, arr_wp, var_i, tmp1

			; Main.bas 122: wk(i) = -1
			dw kw_asetl, arr_wk, var_i, -1

			; Main.bas 128: Next
			dw kw_next1v_n, var_i, for3_l, for3_t
for3_e:

			; Main.bas 131: ob = Space$(82)
			dw kw_strspace, var_ob, lit_82

			; Main.bas 132: front = 1
			dw kw_ltov, 1, var_front

			; Main.bas 133: OpenSlot 1
			dw p_openslot_c, lit_1

			; Main.bas 136: a = ""
			dw kw_strcpy, var_a, str2

			; Main.bas 137: If Peek(&HBE80) = 67 And Peek(&HBE81) = 89 And Peek(&HBE82) = 66 And Peek(&HBE83) = 32 Then
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

			; Main.bas 138: i = &HBE84
			dw kw_ltov, -16764, var_i

			; Main.bas 139: Do While Peek(i) <> 0 And i < &HBEC0
do5_t:
			dw kw_vptrtov8, var_i, tmp0
			dw kw_cpnevl, tmp0, 0
			dw kw_ftov, tmp0
			dw kw_scpltvl, var_i, -16704
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, do5_e

			; Main.bas 140: a = a + Chr$(Peek(i))
			dw kw_vptrtov8, var_i, tmp1
			dw kw_strchr, stmp1, tmp1
			dw kw_strcat, var_a, stmp1

			; Main.bas 141: i = i + 1
			dw kw_inc, var_i

			; Main.bas 142: Loop
			dw do5_t_go
do5_e:

			; Main.bas 143: a = UCase$(a)
			dw kw_strucase, stmp0, var_a
			dw kw_strcpy, var_a, stmp0

			; Main.bas 144: End If
if4_1:

			; Main.bas 145: i = InStr(a, " KEYREP ")
			dw kw_strinstr, lit_1, var_a, str3, var_i

			; Main.bas 146: If i > 0 Then
			dw kw_scpgtvl, var_i, 0
			dw kw_goto_iffalse_n, if6_1

			; Main.bas 147: k = Val(Mid$(a, i + 8))
			dw kw_addl, var_i, 8, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strval, stmp0, var_k

			; Main.bas 148: If k > 1 Then Hyp.KeyRep k
			dw kw_scpgtvl, var_k, 1
			dw kw_goto_iffalse_n, if7_1
			dw p_hyp_keyrep_c, var_k
if7_1:

			; Main.bas 149: End If
if6_1:

			; Main.bas 152: bd = 65                                         ' the boot drive: "CYB d" (A without it)
			dw kw_ltov, 65, var_bd

			; Main.bas 153: If a <> "" Then bd = Asc(a)
			dw kw_strcmpne, var_a, str2
			dw kw_goto_iffalse_n, if8_1
			dw kw_strasc, var_a, var_bd
if8_1:

			; Main.bas 154: If ProbeDiscs() = 0 And Memory.Banks() >= 8 Then ' no RAM discs survived a reset: make Z from the disc - only
			dw p_probediscs_c
			dw kw_vtov, var_probediscs_probediscs, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_ftov, tmp0
			dw fn_memory_banks, var_memory_banks_banks
			dw kw_vtov, var_memory_banks_banks, tmp1
			dw kw_scpgevl, tmp1, 8
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if9_1

			; Main.bas 157: a = "RAMDISC" : b = "Z SYSTEM " + Chr$(bd)    ' the system drive Z: the files CYBORGOS.Z names copied
			dw kw_strcpy, var_a, str4
			dw kw_strchr, stmp1, var_bd
			dw kw_strcpy, var_b, str5
			dw kw_strcat, var_b, stmp1

			; Main.bas 158: StartTask 1, 1                                ' to a RAM disc; the command line waits for it (WAIT)
			dw p_starttask_c, lit_1, lit_1

			; Main.bas 159: If st(1) = 2 Then wt = 1
			dw kw_cpeqvl, arr_st+2, 2
			dw kw_goto_iffalse_n, if10_1
			dw kw_ltov, 1, var_wt
if10_1:

			; Main.bas 160: End If
if9_1:

			; Main.bas 172: Do
do11_t:

			; Main.bas 173: hk = Hot.Take()
			dw p_hot_take_c
			dw kw_vtov, var_hot_take_take, var_hk

			; Main.bas 174: If hk = Hot.TOPKEY Then
			dw kw_cpeqvl, var_hk, 99
			dw kw_goto_iffalse_n, if12_1

			; Main.bas 175: If front = 0 Then ToFront back Else ShowTop      ' Control + ESC: TOP, and again: back
			dw kw_cpeqvl, var_front, 0
			dw kw_goto_iffalse_n, if13_1
			dw p_tofront_c, var_back
			dw if12_e_go
if13_1:
			dw p_showtop_c
if13_e:

			; Main.bas 176: ElseIf hk > 0 And hk <= ns Then
			dw if12_e_go
if12_1:
			dw kw_scpgtvl, var_hk, 0
			dw kw_ftov, tmp0
			dw kw_scplevv, var_hk, var_ns
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if12_2

			; Main.bas 177: ToFront hk
			dw p_tofront_c, var_hk

			; Main.bas 178: End If
if12_2:
if12_e:

			; Main.bas 179: If pk <> 0 And wt = 0 Then                    ' (a key left by a program: after WAIT's prompt)
			dw kw_cpnevl, var_pk, 0
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_wt, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if14_1

			; Main.bas 180: k = pk : pk = 0
			dw kw_vtov, var_pk, var_k
			dw kw_ztov, var_pk

			; Main.bas 181: KeyIn k
			dw p_keyin_c, var_k

			; Main.bas 182: ElseIf wt = 0 Then
			dw if14_e_go
if14_1:
			dw kw_cpeqvl, var_wt, 0
			dw kw_goto_iffalse_n, if14_2

			; Main.bas 184: If front = 0 Or st(front) <> 2 Or kq(front) = 0 Then
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
			dw kw_goto_ifzero_n, tmp0, if14_e

			; Main.bas 185: k = Inkey
			dw kw_inkey, tmp0
			dw kw_vtov, tmp0, var_k

			; Main.bas 186: If k <> 0 And (Hot.Control() = 0 Or (k < 32 And Hot.Held() = 0)) Then KeyIn k   ' (Control + a letter: the program's)
			dw kw_cpnevl, var_k, 0
			dw kw_ftov, tmp0
			dw p_hot_control_c
			dw kw_vtov, var_hot_control_control, tmp1
			dw kw_cpeqvl, tmp1, 0
			dw kw_ftov, tmp1
			dw kw_scpltvl, var_k, 32
			dw kw_ftov, tmp2
			dw p_hot_held_c
			dw kw_vtov, var_hot_held_held, tmp3
			dw kw_cpeqvl, tmp3, 0
			dw kw_ftov, tmp3
			dw kw_andvv, tmp2, tmp3, tmp2
			dw kw_orvv, tmp1, tmp2, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if14_e
			dw p_keyin_c, var_k
if16_1:

			; Main.bas 187: End If
if15_1:

			; Main.bas 188: ElseIf Running() = 0 Then
			dw if14_e_go
if14_2:
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if14_3

			; Main.bas 189: Prompt wt : wt = 0          ' WAIT: nothing runs any more
			dw p_prompt_c, var_wt
			dw kw_ztov, var_wt

			; Main.bas 190: End If
if14_3:
if14_e:

			; Main.bas 191: If Ticks - td >= 300 Then Roll
			dw kw_ticks, tmp0
			dw kw_subvv, tmp0, var_td, tmp0
			dw kw_scpgevl, tmp0, 300
			dw kw_goto_iffalse_n, if17_1
			dw p_roll_c
if17_1:

			; Main.bas 192: RunNext
			dw p_runnext_c

			; Main.bas 193: Loop Until quit
			dw kw_goto_ifzero_n, var_quit, do11_t
do11_e:

			; Main.bas 194: i = Hyp.Scr(0, 2)                 ' the CRTC as the firmware has it (80 x 25)
			dw p_hyp_scr_c, lit_0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_i

			; Main.bas 195: Hyp.Vdu 1
			dw p_hyp_vdu_c, lit_1

			; Main.bas 196: Mode 1
			dw kw_model, 1

			; Main.bas 197: Print "CyborgOS ended, "; runs; " programs ran"
			dw kw_printstrvar, str6
			dw kw_printint, var_runs
			dw kw_printstrvar, str7
			dw kw_printnl

			; Main.bas 198: End
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

			; Main.bas 202: Dim j As Integer

			; Main.bas 203: For j = 1 To ns
			dw kw_ltov, 1, var_running_j
			dw kw_vtov, var_ns, for18_l
			dw kw_forupv_n, var_running_j, for18_l, for18_e
for18_t:

			; Main.bas 204: If st(j) = 2 Then Running = Running + 1
			dw kw_aget, arr_st, var_running_j, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if19_1
			dw kw_inc, var_running_running
if19_1:

			; Main.bas 205: Next
			dw kw_next1v_n, var_running_j, for18_l, for18_t
for18_e:
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

			; Main.bas 211: Ready = 0
			dw kw_ztov, var_ready_ready

			; Main.bas 212: If t < 1 Then Exit Function
			dw kw_scpltvl, var_ready_t, 1
			dw kw_goto_iffalse_n, if20_1
			dw p_ready_r
if20_1:

			; Main.bas 213: If st(t) <> 2 Then Exit Function
			dw kw_aget, arr_st, var_ready_t, tmp0
			dw kw_cpnevl, tmp0, 2
			dw kw_goto_iffalse_n, if21_1
			dw p_ready_r
if21_1:

			; Main.bas 214: If wk(t) = Ticks And kq(t) = 0 Then Exit Function
			dw kw_aget, arr_wk, var_ready_t, tmp0
			dw kw_ticks, tmp1
			dw kw_cpeqvv, tmp0, tmp1
			dw kw_ftov, tmp0
			dw kw_aget, arr_kq, var_ready_t, tmp1
			dw kw_cpeqvl, tmp1, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if22_1
			dw p_ready_r
if22_1:

			; Main.bas 215: Ready = -1
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

			; Main.bas 220: Dim n As Integer, t As Integer, r As Integer, c As Integer, q As Integer

			; Main.bas 221: fr = Not fr
			dw kw_notv, var_fr, var_fr

			; Main.bas 222: If fr Then
			dw kw_goto_ifzero_n, var_fr, if23_1

			; Main.bas 223: If Ready(front) Then t = front
			dw p_ready_c, var_front
			dw kw_goto_ifzero_n, var_ready_ready, if24_1
			dw kw_vtov, var_front, var_runnext_t
if24_1:

			; Main.bas 224: End If
if23_1:

			; Main.bas 225: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if25_1

			; Main.bas 226: For n = 1 To ns
			dw kw_ltov, 1, var_runnext_n
			dw kw_vtov, var_ns, for26_l
			dw kw_forupv_n, var_runnext_n, for26_l, for26_e
for26_t:

			; Main.bas 227: cur = cur + 1
			dw kw_inc, var_cur

			; Main.bas 228: If cur > ns Then cur = 1
			dw kw_scpgtvv, var_cur, var_ns
			dw kw_goto_iffalse_n, if27_1
			dw kw_ltov, 1, var_cur
if27_1:

			; Main.bas 229: If cur <> front Then
			dw kw_cpnevv, var_cur, var_front
			dw kw_goto_iffalse_n, if28_1

			; Main.bas 230: If Ready(cur) Then t = cur : Exit For
			dw p_ready_c, var_cur
			dw kw_goto_ifzero_n, var_ready_ready, if29_1
			dw kw_vtov, var_cur, var_runnext_t
			dw for26_e_go
if29_1:

			; Main.bas 231: End If
if28_1:

			; Main.bas 232: Next
			dw kw_next1v_n, var_runnext_n, for26_l, for26_t
for26_e:

			; Main.bas 233: End If
if25_1:

			; Main.bas 234: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if30_1

			; Main.bas 235: If Ready(front) Then t = front
			dw p_ready_c, var_front
			dw kw_goto_ifzero_n, var_ready_ready, if31_1
			dw kw_vtov, var_front, var_runnext_t
if31_1:

			; Main.bas 236: End If
if30_1:

			; Main.bas 237: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if32_1

			; Main.bas 238: If Running() = 0 Then Frame     ' nothing to run: wait a frame (a program waiting for a
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if33_1
			dw kw_frame
if33_1:

			; Main.bas 239: Exit Sub                        ' key looks again when the clock moves on)
			dw p_runnext_r

			; Main.bas 240: End If
if32_1:

			; Main.bas 241: n = 0
			dw kw_ztov, var_runnext_n

			; Main.bas 242: Do
do34_t:

			; Main.bas 243: Hyp.Reply ra(t), ra(t)
			dw kw_aget, arr_ra, var_runnext_t, tmp0
			dw kw_aget, arr_ra, var_runnext_t, tmp1
			dw p_hyp_reply_c, tmp0, tmp1

			; Main.bas 244: r = Hyp.Run(sg(t))
			dw kw_aget, arr_sg, var_runnext_t, tmp0
			dw p_hyp_run_c, tmp0
			dw kw_vtov, var_hyp_run_run, var_runnext_r

			; Main.bas 245: tn(t) = tn(t) + 1
			dw kw_aget, arr_tn, var_runnext_t, tmp1
			dw kw_inc, tmp1
			dw kw_aset, arr_tn, var_runnext_t, tmp1

			; Main.bas 246: If kq(t) <> 0 Then
			dw kw_aget, arr_kq, var_runnext_t, tmp0
			dw kw_cpnevl, tmp0, 0
			dw kw_goto_iffalse_n, if35_1

			; Main.bas 247: If Memory.ReadByte(Far(t, Hyp.KEY)) = 0 Then kq(t) = 0     ' the program took its key
			dw p_far_c, var_runnext_t, lit_m2431
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_memory_readbyte_readbyte
			dw kw_vtov, var_memory_readbyte_readbyte, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if36_1
			dw kw_asetl, arr_kq, var_runnext_t, 0
if36_1:

			; Main.bas 248: End If
if35_1:

			; Main.bas 249: c = Hyp.Count()
			dw p_hyp_count_c
			dw kw_vtov, var_hyp_count_count, var_runnext_c

			; Main.bas 250: If c > 0 Then Collected t, c
			dw kw_scpgtvl, var_runnext_c, 0
			dw kw_goto_iffalse_n, if37_1
			dw p_collected_c, var_runnext_t, var_runnext_c
if37_1:

			; Main.bas 251: If r = 0 Then
			dw kw_cpeqvl, var_runnext_r, 0
			dw kw_goto_iffalse_n, if38_1

			; Main.bas 255: q = q + 1
			dw kw_inc, var_runnext_q

			; Main.bas 256: If q >= TURNS Then Exit Do
			dw kw_scpgevl, var_runnext_q, 3
			dw kw_goto_iffalse_n, do34_t
			dw do34_e_go
if39_1:

			; Main.bas 257: ElseIf r <> 1 Then
			dw do34_t_go
if38_1:
			dw kw_cpnevl, var_runnext_r, 1
			dw kw_goto_iffalse_n, if38_2

			; Main.bas 258: Exit Do
			dw do34_e_go

			; Main.bas 259: Else
if38_2:

			; Main.bas 260: c = Hyp.Fn()
			dw p_hyp_fn_c
			dw kw_vtov, var_hyp_fn_fn, var_runnext_c

			; Main.bas 261: Bdos t
			dw p_bdos_c, var_runnext_t

			; Main.bas 264: n = n + 1
			dw kw_inc, var_runnext_n

			; Main.bas 265: If c < 13 Or c > 36 Or n >= 32 Or st(t) <> 2 Then Exit Do
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
			dw kw_goto_ifzero_n, tmp0, do34_t
			dw do34_e_go
if40_1:

			; Main.bas 266: End If
if38_e:

			; Main.bas 267: Loop
			dw do34_t_go
do34_e:
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

			; Main.bas 272: Dim f As Integer, e As Integer, a As Integer

			; Main.bas 273: f = Hyp.Fn() : e = Hyp.Arg() And 255 : a = 0
			dw p_hyp_fn_c
			dw kw_vtov, var_hyp_fn_fn, var_bdos_f
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp0
			dw kw_andvl, tmp0, 255, var_bdos_e
			dw kw_ztov, var_bdos_a

			; Main.bas 274: nb(t) = nb(t) + 1
			dw kw_aget, arr_nb, var_bdos_t, tmp1
			dw kw_inc, tmp1
			dw kw_aset, arr_nb, var_bdos_t, tmp1

			; Main.bas 275: wk(t) = -1
			dw kw_asetl, arr_wk, var_bdos_t, -1

			; Main.bas 276: If f = 40 Then f = 34           ' write random with zero fill: as 34
			dw kw_cpeqvl, var_bdos_f, 40
			dw kw_goto_iffalse_n, if41_1
			dw kw_ltov, 34, var_bdos_f
if41_1:

			; Main.bas 277: Select Case f
			dw kw_vtov, var_bdos_f, var_bdos___sel42

			; Main.bas 278: Case 0
			dw kw_cpeqvl, var_bdos___sel42, 0
			dw kw_goto_iffalse_n, sel42_1
sel42_b1:

			; Main.bas 279: EndTask t
			dw p_endtask_c, var_bdos_t

			; Main.bas 280: Exit Sub
			dw p_bdos_r

			; Main.bas 301: Case 12
sel42_1:
			dw kw_cpeqvl, var_bdos___sel42, 12
			dw kw_goto_iffalse_n, sel42_2
sel42_b2:

			; Main.bas 302: a = &H22                    ' CP/M 2.2
			dw kw_ltov, 34, var_bdos_a

			; Main.bas 303: Case 13, 32                   ' reset the discs; user number: nothing to do here
			dw sel42_e_go
sel42_2:
			dw kw_cpeqvl, var_bdos___sel42, 13
			dw kw_goto_iftrue_n, sel42_b3
			dw kw_cpeqvl, var_bdos___sel42, 32
			dw kw_goto_iffalse_n, sel42_3
sel42_b3:

			; Main.bas 304: a = 0
			dw kw_ztov, var_bdos_a

			; Main.bas 305: Case 14                       ' select a disc: the slot's drive (as CD)
			dw sel42_e_go
sel42_3:
			dw kw_cpeqvl, var_bdos___sel42, 14
			dw kw_goto_iffalse_n, sel42_4
sel42_b4:

			; Main.bas 308: dv(t) = 65 + e
			dw kw_addl, var_bdos_e, 65, tmp1
			dw kw_aset, arr_dv, var_bdos_t, tmp1

			; Main.bas 310: Case 25
			dw sel42_e_go
sel42_4:
			dw kw_cpeqvl, var_bdos___sel42, 25
			dw kw_goto_iffalse_n, sel42_5
sel42_b5:

			; Main.bas 314: If dv(t) = 0 Then a = 0 Else a = dv(t) - 65
			dw kw_aget, arr_dv, var_bdos_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if43_1
			dw kw_ztov, var_bdos_a
			dw sel42_e_go
if43_1:
			dw kw_aget, arr_dv, var_bdos_t, tmp0
			dw kw_addl, tmp0, -65, var_bdos_a
if43_e:

			; Main.bas 316: Case 26                       ' the DMA address (CP/M's record buffer)
			dw sel42_e_go
sel42_5:
			dw kw_cpeqvl, var_bdos___sel42, 26
			dw kw_goto_iffalse_n, sel42_6
sel42_b6:

			; Main.bas 317: dm(t) = Hyp.Arg()
			dw p_hyp_arg_c
			dw kw_aset, arr_dm, var_bdos_t, var_hyp_arg_arg

			; Main.bas 318: Case 24                       ' the login vector: the slot's drive
			dw sel42_e_go
sel42_6:
			dw kw_cpeqvl, var_bdos___sel42, 24
			dw kw_goto_iffalse_n, sel42_7
sel42_b7:

			; Main.bas 322: If dv(t) = 0 Then a = 1 Else a = dv(t) - 64   ' (A 1, B 2)
			dw kw_aget, arr_dv, var_bdos_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if44_1
			dw kw_ltov, 1, var_bdos_a
			dw sel42_e_go
if44_1:
			dw kw_aget, arr_dv, var_bdos_t, tmp0
			dw kw_addl, tmp0, -64, var_bdos_a
if44_e:

			; Main.bas 324: Case 15 To 36                 ' files: Hyp.FileCall
			dw sel42_e_go
sel42_7:
			dw kw_scpltvl, var_bdos___sel42, 15
			dw kw_goto_iftrue_n, sel42_8
			dw kw_scplevl, var_bdos___sel42, 36
			dw kw_goto_iffalse_n, sel42_8
sel42_b8:

			; Main.bas 328: a = Hyp.FileCall(f, Hyp.Arg(), t, sg(t), dm(t), dv(t), VarPtr(rb))
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp1
			dw kw_aget, arr_sg, var_bdos_t, tmp3
			dw kw_aget, arr_dm, var_bdos_t, tmp4
			dw kw_aget, arr_dv, var_bdos_t, tmp5
			dw p_hyp_filecall_c, var_bdos_f, tmp1, var_bdos_t, tmp3, tmp4, tmp5, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_bdos_a

			; Main.bas 332: Case 130                      ' RAMDISC.CYB: the RAM discs' driver
			dw sel42_e_go
sel42_8:
			dw kw_cpeqvl, var_bdos___sel42, 130
			dw kw_goto_iffalse_n, sel42_9
sel42_b9:

			; Main.bas 333: a = RamDisc(t, Hyp.Arg())
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp1
			dw p_ramdisc_c, var_bdos_t, tmp1
			dw kw_vtov, var_ramdisc_ramdisc, var_bdos_a

			; Main.bas 335: Case 131                      ' CyborgOS's own commands (PS, KILL, MEM ...)
			dw sel42_e_go
sel42_9:
			dw kw_cpeqvl, var_bdos___sel42, 131
			dw kw_goto_iffalse_n, sel42_10
sel42_b10:

			; Main.bas 336: a = Sys(t, Hyp.Arg())
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp1
			dw p_sys_c, var_bdos_t, tmp1
			dw kw_vtov, var_sys_sys, var_bdos_a

			; Main.bas 337: Case 128
			dw sel42_e_go
sel42_10:
			dw kw_cpeqvl, var_bdos___sel42, 128
			dw kw_goto_iffalse_n, sel42_11
sel42_b11:

			; Main.bas 339: Case 129                      ' the stub's key wait (BDOS 1, 10, BIOS CONIN): sleep till a key
			dw sel42_e_go
sel42_11:
			dw kw_cpeqvl, var_bdos___sel42, 129
			dw kw_goto_iffalse_n, sel42_12
sel42_b12:

			; Main.bas 340: If kq(t) = 0 Then wk(t) = Ticks
			dw kw_aget, arr_kq, var_bdos_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, sel42_e
			dw kw_ticks, tmp1
			dw kw_aset, arr_wk, var_bdos_t, tmp1
if45_1:

			; Main.bas 341: Case Else
			dw sel42_e_go
sel42_12:

			; Main.bas 342: a = 255
			dw kw_ltov, 255, var_bdos_a

			; Main.bas 343: End Select
sel42_e:

			; Main.bas 344: ra(t) = a
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
; function ramdisc (normal mode)
; ============================================================

p_ramdisc:

			; Main.bas 354: Dim g As Integer, o As Integer, f As Long

			; Main.bas 355: o = Memory.ReadByte(Far(t, p))
			dw p_far_c, var_ramdisc_t, var_ramdisc_p
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_ramdisc_o

			; Main.bas 356: If dp = 0 Then
			dw kw_cpeqvl, var_dp, 0
			dw kw_goto_iffalse_n, if46_1

			; Main.bas 357: RamDisc = 255
			dw kw_ltov, 255, var_ramdisc_ramdisc

			; Main.bas 358: If o = 3 Then Exit Function                              ' (the list: none)
			dw kw_cpeqvl, var_ramdisc_o, 3
			dw kw_goto_iffalse_n, if47_1
			dw p_ramdisc_r
if47_1:

			; Main.bas 359: dp = Memory.AllocPage(Memory.TypeUser)
			dw fn_memory_allocpage, lit_85, var_dp

			; Main.bas 360: If dp = 0 Then RamDisc = 2 : Exit Function
			dw kw_cpeqvl, var_dp, 0
			dw kw_goto_iffalse_n, if48_1
			dw kw_ltov, 2, var_ramdisc_ramdisc
			dw p_ramdisc_r
if48_1:

			; Main.bas 361: f = Far(t, Memory.ReadWord(Far(t, p + 2)))                 ' (Far's FarPtr: one result for all calls)
			dw kw_addl, var_ramdisc_p, 2, tmp2
			dw p_far_c, var_ramdisc_t, tmp2
			dw kw_l_mov, var_far_far, ltmp1
			dw fn_memory_readword, ltmp1, var_memory_readword_readword
			dw kw_vtov, var_memory_readword_readword, tmp1
			dw p_far_c, var_ramdisc_t, tmp1
			dw kw_l_mov, var_far_far, var_ramdisc_f

			; Main.bas 362: Memory.Copy f, Hyp.FarPtr(dp, 0), Memory.ReadWord(Far(t, p + 4))
			dw fn_hyp_farptr, var_dp, lit_0, var_hyp_farptr_farptr
			dw kw_addl, var_ramdisc_p, 4, tmp3
			dw p_far_c, var_ramdisc_t, tmp3
			dw kw_l_mov, var_far_far, ltmp2
			dw fn_memory_readword, ltmp2, var_memory_readword_readword
			dw fn_memory_copy, var_ramdisc_f, var_hyp_farptr_farptr, var_memory_readword_readword, var_memory_copy_copy

			; Main.bas 363: g = Memory.SelectPage(dp)
			dw fn_memory_selectpage, var_dp, var_ramdisc_g

			; Main.bas 364: Hyp.UseDriver VarPtr(rb)
			dw p_hyp_usedriver_c, vp_arr_rb

			; Main.bas 365: g = Hyp.FileCall(110, 0, 0, 0, 0, 0, 0)                    ' (its tables cleared)
			dw p_hyp_filecall_c, lit_110, lit_0, lit_0, lit_0, lit_0, lit_0, lit_0
			dw kw_vtov, var_hyp_filecall_filecall, var_ramdisc_g

			; Main.bas 366: End If
if46_1:

			; Main.bas 367: g = 0
			dw kw_ztov, var_ramdisc_g

			; Main.bas 368: If o = 2 Then
			dw kw_cpeqvl, var_ramdisc_o, 2
			dw kw_goto_iffalse_n, if49_1

			; Main.bas 369: g = Memory.AllocPage(Memory.TypeUser)
			dw fn_memory_allocpage, lit_85, var_ramdisc_g

			; Main.bas 370: RamDisc = 2
			dw kw_ltov, 2, var_ramdisc_ramdisc

			; Main.bas 371: If g = 0 Then Exit Function
			dw kw_cpeqvl, var_ramdisc_g, 0
			dw kw_goto_iffalse_n, if50_1
			dw p_ramdisc_r
if50_1:

			; Main.bas 372: RamDisc = Memory.SelectPage(g)
			dw fn_memory_selectpage, var_ramdisc_g, var_ramdisc_ramdisc

			; Main.bas 373: End If
if49_1:

			; Main.bas 374: RamDisc = Hyp.FileCall(116, p, t, sg(t), g, Hyp.Setting(), 0)
			dw kw_aget, arr_sg, var_ramdisc_t, tmp3
			dw fn_hyp_setting, var_hyp_setting_setting
			dw kw_vtov, var_hyp_setting_setting, tmp5
			dw p_hyp_filecall_c, lit_116, var_ramdisc_p, var_ramdisc_t, tmp3, var_ramdisc_g, tmp5, lit_0
			dw kw_vtov, var_hyp_filecall_filecall, var_ramdisc_ramdisc

			; Main.bas 375: If RamDisc < 0 Then RamDisc = Memory.FreePage(RamDisc And &H7FFF) : RamDisc = 0   ' (a page back: + #8000)
			dw kw_scpltvl, var_ramdisc_ramdisc, 0
			dw kw_goto_iffalse_n, if51_1
			dw kw_andvl, var_ramdisc_ramdisc, 32767, tmp0
			dw fn_memory_freepage, tmp0, var_ramdisc_ramdisc
			dw kw_ztov, var_ramdisc_ramdisc
if51_1:

			; Main.bas 376: If g <> 0 And RamDisc <> 0 Then RamDisc = Memory.FreePage(g) : RamDisc = 2
			dw kw_cpnevl, var_ramdisc_g, 0
			dw kw_ftov, tmp0
			dw kw_cpnevl, var_ramdisc_ramdisc, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if52_1
			dw fn_memory_freepage, var_ramdisc_g, var_ramdisc_ramdisc
			dw kw_ltov, 2, var_ramdisc_ramdisc
if52_1:
			dw p_ramdisc_r

ntc_rg6_e:
			IF ($ < 32768) && (ntc_rg7_e - ntc_rg7 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg7:
; ============================================================
; function storesize (normal mode)
; ============================================================

p_storesize:

			; Main.bas 387: Dim n As Integer, j As Integer, g As Integer

			; Main.bas 388: n = (kb + 15) \ 16
			dw kw_addl, var_storesize_kb, 15, tmp0
			dw kw_divvl, tmp0, 16, var_storesize_n

			; Main.bas 389: If kb < 0 Or n > 32 Then n = 32
			dw kw_scpltvl, var_storesize_kb, 0
			dw kw_ftov, tmp0
			dw kw_scpgtvl, var_storesize_n, 32
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if53_1
			dw kw_ltov, 32, var_storesize_n
if53_1:

			; Main.bas 390: For j = 0 To 31
			dw kw_ztov, var_storesize_j
for54_t:

			; Main.bas 391: g = Memory.ReadByte(Far(t, STORE + j))
			dw kw_addl, var_storesize_j, -256, tmp1
			dw p_far_c, var_storesize_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_storesize_g

			; Main.bas 392: If j < n And g = 0 Then
			dw kw_scpltvv, var_storesize_j, var_storesize_n
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_storesize_g, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if55_1

			; Main.bas 393: g = Memory.AllocPage(Memory.TypeUser)
			dw fn_memory_allocpage, lit_85, var_storesize_g

			; Main.bas 394: If g = 0 Then StoreSize = 2 : Exit Function
			dw kw_cpeqvl, var_storesize_g, 0
			dw kw_goto_iffalse_n, if56_1
			dw kw_ltov, 2, var_storesize_storesize
			dw p_storesize_r
if56_1:

			; Main.bas 395: Memory.WriteByte Far(t, STORE + j), g
			dw kw_addl, var_storesize_j, -256, tmp1
			dw p_far_c, var_storesize_t, tmp1
			dw fn_memory_writebyte, var_far_far, var_storesize_g

			; Main.bas 396: ElseIf j >= n And g <> 0 Then
			dw if55_e_go
if55_1:
			dw kw_scpgevv, var_storesize_j, var_storesize_n
			dw kw_ftov, tmp0
			dw kw_cpnevl, var_storesize_g, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if55_2

			; Main.bas 397: g = Memory.FreePage(g)
			dw fn_memory_freepage, var_storesize_g, var_memory_freepage_freepage
			dw kw_vtov, var_memory_freepage_freepage, var_storesize_g

			; Main.bas 398: Memory.WriteByte Far(t, STORE + j), 0
			dw kw_addl, var_storesize_j, -256, tmp1
			dw p_far_c, var_storesize_t, tmp1
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 399: End If
if55_2:
if55_e:

			; Main.bas 400: Next
			dw kw_next1l_n, var_storesize_j, 31, for54_t
for54_e:
			dw p_storesize_r

ntc_rg7_e:
			IF ($ < 32768) && (ntc_rg8_e - ntc_rg8 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg8:
; ============================================================
; function probediscs (normal mode)
; ============================================================

p_probediscs:

			; Main.bas 409: Dim p As Integer, su As Integer, j As Integer, a As Integer, pg As Integer, r As Integer

			; Main.bas 410: ProbeDiscs = 0
			dw kw_ztov, var_probediscs_probediscs

			; Main.bas 411: For p = 2 To Memory.Pages()
			dw kw_ltov, 2, var_probediscs_p
			dw fn_memory_pages, for57_l
			dw kw_forupv_n, var_probediscs_p, for57_l, for57_e
for57_t:

			; Main.bas 412: If Memory.PageType(p) = Memory.TypeFree Then
			dw fn_memory_pagetype, var_probediscs_p, var_memory_pagetype_pagetype
			dw kw_vtov, var_memory_pagetype_pagetype, tmp0
			dw kw_cpeqvl, tmp0, 45
			dw kw_goto_iffalse_n, if58_1

			; Main.bas 413: r = Memory.SelectPage(p)
			dw fn_memory_selectpage, var_probediscs_p, var_probediscs_r

			; Main.bas 414: If Peek(&H7F00) = 67 And Peek(&H7F01) = 89 And Peek(&H7F02) = 66 And Peek(&H7F03) = 68 And Peek(&H7F04) = &H5A And Peek(&H7F05) = &HCB Then
			dw kw_lptrtov8, 32512, tmp0
			dw kw_cpeqvl, tmp0, 67
			dw kw_ftov, tmp0
			dw kw_lptrtov8, 32513, tmp1
			dw kw_cpeqvl, tmp1, 89
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_lptrtov8, 32514, tmp1
			dw kw_cpeqvl, tmp1, 66
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_lptrtov8, 32515, tmp1
			dw kw_cpeqvl, tmp1, 68
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_lptrtov8, 32516, tmp1
			dw kw_cpeqvl, tmp1, 90
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_lptrtov8, 32517, tmp1
			dw kw_cpeqvl, tmp1, 203
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if59_1

			; Main.bas 415: su = 0
			dw kw_ztov, var_probediscs_su

			; Main.bas 416: For j = &H5400 To &H59FF
			dw kw_ltov, 21504, var_probediscs_j
for60_t:

			; Main.bas 417: su = (su + Peek(j)) And &HFFFF
			dw kw_vptrtov8, var_probediscs_j, tmp1
			dw kw_add, var_probediscs_su, tmp1, tmp0
			dw kw_vtov, tmp0, var_probediscs_su

			; Main.bas 418: Next
			dw kw_next1l_n, var_probediscs_j, 23039, for60_t
for60_e:

			; Main.bas 419: If su = Peek(&H7F06) + Peek(&H7F07) * 256 Then
			dw kw_lptrtov8, 32518, tmp1
			dw kw_lptrtov8, 32519, tmp2
			dw kw_mulvl, tmp2, 256, tmp2
			dw kw_add, tmp1, tmp2, tmp1
			dw kw_cpeqvv, var_probediscs_su, tmp1
			dw kw_goto_iffalse_n, if61_1

			; Main.bas 420: dp = Hyp.ClaimPage(p)
			dw p_hyp_claimpage_c, var_probediscs_p
			dw kw_vtov, var_hyp_claimpage_claimpage, var_dp

			; Main.bas 421: For j = 0 To 255                       ' the pages D_POOL lists (owner <> 0) back too
			dw kw_ztov, var_probediscs_j
for62_t:

			; Main.bas 422: a = &H5400 + j * 6
			dw kw_mulvl, var_probediscs_j, 6, tmp1
			dw kw_addl, tmp1, 21504, var_probediscs_a

			; Main.bas 423: If Peek(a) <> 0 Then
			dw kw_vptrtov8, var_probediscs_a, tmp0
			dw kw_cpnevl, tmp0, 0
			dw kw_goto_iffalse_n, if63_1

			; Main.bas 424: pg = Peek(a + 2) + Peek(a + 3) * 256
			dw kw_addl, var_probediscs_a, 2, tmp0
			dw kw_vptrtov8, tmp0, tmp0
			dw kw_addl, var_probediscs_a, 3, tmp1
			dw kw_vptrtov8, tmp1, tmp1
			dw kw_mulvl, tmp1, 256, tmp1
			dw kw_add, tmp0, tmp1, var_probediscs_pg

			; Main.bas 425: r = Hyp.ClaimPage(pg)
			dw p_hyp_claimpage_c, var_probediscs_pg
			dw kw_vtov, var_hyp_claimpage_claimpage, var_probediscs_r

			; Main.bas 426: End If
if63_1:

			; Main.bas 427: Next
			dw kw_next1l_n, var_probediscs_j, 255, for62_t
for62_e:

			; Main.bas 428: r = Memory.SelectPage(dp)
			dw fn_memory_selectpage, var_dp, var_probediscs_r

			; Main.bas 429: Hyp.UseDriver VarPtr(rb)
			dw p_hyp_usedriver_c, vp_arr_rb

			; Main.bas 430: ProbeDiscs = -1
			dw kw_ltov, -1, var_probediscs_probediscs

			; Main.bas 431: Exit Function
			dw p_probediscs_r

			; Main.bas 432: End If
if61_1:

			; Main.bas 433: End If
if59_1:

			; Main.bas 434: End If
if58_1:

			; Main.bas 435: Next
			dw kw_next1v_n, var_probediscs_p, for57_l, for57_t
for57_e:
			dw p_probediscs_r

ntc_rg8_e:
			IF ($ < 32768) && (ntc_rg9_e - ntc_rg9 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg9:
; ============================================================
; sub storefree (normal mode)
; ============================================================

p_storefree:

			; Main.bas 441: Dim r As Integer

			; Main.bas 442: r = StoreSize(t, 0)
			dw p_storesize_c, var_storefree_t, lit_0
			dw kw_vtov, var_storesize_storesize, var_storefree_r
			dw p_storefree_r

ntc_rg9_e:
			IF ($ < 32768) && (ntc_rg10_e - ntc_rg10 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg10:
; ============================================================
; function sys (normal mode)
; ============================================================

p_sys:

			; Main.bas 455: Dim o As Integer, s As Integer, d As Integer

			; Main.bas 456: o = Memory.ReadByte(Far(t, p)) : s = Memory.ReadByte(Far(t, p + 1))
			dw p_far_c, var_sys_t, var_sys_p
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_o
			dw kw_addl, var_sys_p, 1, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_s

			; Main.bas 457: If o = 4 Then
			dw kw_cpeqvl, var_sys_o, 4
			dw kw_goto_iffalse_n, if64_1

			; Main.bas 458: If Running() > 1 Then wt = t
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_scpgtvl, tmp0, 1
			dw kw_goto_iffalse_n, if65_1
			dw kw_vtov, var_sys_t, var_wt
if65_1:

			; Main.bas 459: Exit Function
			dw p_sys_r

			; Main.bas 460: ElseIf o = 6 Then
if64_1:
			dw kw_cpeqvl, var_sys_o, 6
			dw kw_goto_iffalse_n, if64_2

			; Main.bas 461: txs = t
			dw kw_vtov, var_sys_t, var_txs

			; Main.bas 462: TopLines front, 0
			dw p_toplines_c, var_front, lit_0

			; Main.bas 463: Exit Function
			dw p_sys_r

			; Main.bas 464: ElseIf o = 9 Then                               ' MODE: s 0-4 this slot's mode (its console
if64_2:
			dw kw_cpeqvl, var_sys_o, 9
			dw kw_goto_iffalse_n, if64_3

			; Main.bas 465: If s = 255 Then Sys = Memory.ReadByte(Far(t, Hyp.CMODE)) : Exit Function   ' cleared), 255: which
			dw kw_cpeqvl, var_sys_s, 255
			dw kw_goto_iffalse_n, if66_1
			dw p_far_c, var_sys_t, lit_m2423
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_sys
			dw p_sys_r
if66_1:

			; Main.bas 466: If s > 5 Then Sys = 255 : Exit Function                                     ' it is
			dw kw_scpgtvl, var_sys_s, 5
			dw kw_goto_iffalse_n, if67_1
			dw kw_ltov, 255, var_sys_sys
			dw p_sys_r
if67_1:

			; Main.bas 467: SetMode t, s
			dw p_setmode_c, var_sys_t, var_sys_s

			; Main.bas 468: Exit Function
			dw p_sys_r

			; Main.bas 471: ElseIf o = 10 Or o = 11 Or o = 13 Or o = 14 Or o = 15 Then   ' memory, the pointer, the store's
if64_3:
			dw kw_cpeqvl, var_sys_o, 10
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_sys_o, 11
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_cpeqvl, var_sys_o, 13
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_cpeqvl, var_sys_o, 14
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_cpeqvl, var_sys_o, 15
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if64_4

			; Main.bas 472: Sys = Hyp.Svc(t, p, sg(t), VarPtr(rb))                     ' blocks, tables: in the service page
			dw kw_aget, arr_sg, var_sys_t, tmp2
			dw p_hyp_svc_c, var_sys_t, var_sys_p, tmp2, vp_arr_rb
			dw kw_vtov, var_hyp_svc_svc, var_sys_sys

			; Main.bas 473: Exit Function
			dw p_sys_r

			; Main.bas 474: ElseIf o = 12 Then                              ' the slot's store: Word(2) K (16K pages, 512K at most)
if64_4:
			dw kw_cpeqvl, var_sys_o, 12
			dw kw_goto_iffalse_n, if64_5

			; Main.bas 475: Sys = StoreSize(t, Memory.ReadWord(Far(t, p + 2)))
			dw kw_addl, var_sys_p, 2, tmp2
			dw p_far_c, var_sys_t, tmp2
			dw kw_l_mov, var_far_far, ltmp1
			dw fn_memory_readword, ltmp1, var_memory_readword_readword
			dw kw_vtov, var_memory_readword_readword, tmp1
			dw p_storesize_c, var_sys_t, tmp1
			dw kw_vtov, var_storesize_storesize, var_sys_sys

			; Main.bas 476: Exit Function
			dw p_sys_r

			; Main.bas 480: ElseIf o = 7 Then
if64_5:
			dw kw_cpeqvl, var_sys_o, 7
			dw kw_goto_iffalse_n, if64_6

			; Main.bas 481: Memory.WriteWord Far(t, p + 2), Memory.TableEnd()
			dw kw_addl, var_sys_p, 2, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw fn_memory_tableend, var_memory_tableend_tableend
			dw fn_memory_writeword, var_far_far, var_memory_tableend_tableend

			; Main.bas 482: Memory.WriteWord Far(t, p + 4), Memory.Top()
			dw kw_addl, var_sys_p, 4, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw fn_memory_top, var_memory_top_top
			dw fn_memory_writeword, var_far_far, var_memory_top_top

			; Main.bas 483: Memory.WriteWord Far(t, p + 6), Memory.Pages()
			dw kw_addl, var_sys_p, 6, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw fn_memory_pages, var_memory_pages_pages
			dw fn_memory_writeword, var_far_far, var_memory_pages_pages

			; Main.bas 484: Totals
			dw p_totals_c

			; Main.bas 485: PutEn t, p + 8
			dw kw_addl, var_sys_p, 8, tmp1
			dw p_puten_c, var_sys_t, tmp1

			; Main.bas 486: Exit Function
			dw p_sys_r

			; Main.bas 487: ElseIf o = 8 Then
if64_6:
			dw kw_cpeqvl, var_sys_o, 8
			dw kw_goto_iffalse_n, if64_7

			; Main.bas 488: en = Memory.Map(Memory.ReadWord(Far(t, p + 2)), 32)
			dw kw_addl, var_sys_p, 2, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readword, ltmp0, var_memory_readword_readword
			dw kw_vtov, var_memory_readword_readword, tmp0
			dw fn_memory_map, tmp0, lit_32, var_memory_map_map
			dw kw_strcpy, var_en, var_memory_map_map

			; Main.bas 489: PutEn t, p + 4
			dw kw_addl, var_sys_p, 4, tmp1
			dw p_puten_c, var_sys_t, tmp1

			; Main.bas 490: Exit Function
			dw p_sys_r

			; Main.bas 492: End If
if64_7:
if64_e:

			; Main.bas 493: If o = 2 And s = 0 Then s = t
			dw kw_cpeqvl, var_sys_o, 2
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_sys_s, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if68_1
			dw kw_vtov, var_sys_t, var_sys_s
if68_1:

			; Main.bas 494: Sys = 255
			dw kw_ltov, 255, var_sys_sys

			; Main.bas 495: If s < 1 Or s > ns Then Exit Function
			dw kw_scpltvl, var_sys_s, 1
			dw kw_ftov, tmp0
			dw kw_scpgtvv, var_sys_s, var_ns
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if69_1
			dw p_sys_r
if69_1:

			; Main.bas 496: Sys = 0
			dw kw_ztov, var_sys_sys

			; Main.bas 497: If o = 0 Then
			dw kw_cpeqvl, var_sys_o, 0
			dw kw_goto_iffalse_n, if70_1

			; Main.bas 498: Memory.WriteByte Far(t, p + 2), st(s)
			dw kw_addl, var_sys_p, 2, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_aget, arr_st, var_sys_s, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 499: Memory.WriteByte Far(t, p + 3), IIf(s = front, 1, 0)
			dw kw_addl, var_sys_p, 3, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_cpeqvv, var_sys_s, var_front
			dw kw_ftov, tmp1
			dw kw_goto_ifzero_n, tmp1, ch71_0
			dw kw_ltov, 1, tmp1
			dw ch71_e_go
ch71_0:
			dw kw_ztov, tmp1
			dw ch71_e_go
ch71_1:
			dw kw_ztov, tmp1
ch71_e:
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 500: en = ""
			dw kw_strcpy, var_en, str2

			; Main.bas 501: If st(s) = 2 Then GetNm s
			dw kw_aget, arr_st, var_sys_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if72_1
			dw p_getnm_c, var_sys_s
if72_1:

			; Main.bas 502: PutEn t, p + 4
			dw kw_addl, var_sys_p, 4, tmp1
			dw p_puten_c, var_sys_t, tmp1

			; Main.bas 503: ElseIf o = 1 Then
			dw if70_e_go
if70_1:
			dw kw_cpeqvl, var_sys_o, 1
			dw kw_goto_iffalse_n, if70_2

			; Main.bas 504: If st(s) = 2 Then EndTask s Else Sys = 1
			dw kw_aget, arr_st, var_sys_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if73_1
			dw p_endtask_c, var_sys_s
			dw if70_e_go
if73_1:
			dw kw_ltov, 1, var_sys_sys
if73_e:

			; Main.bas 505: ElseIf o = 2 Then
			dw if70_e_go
if70_2:
			dw kw_cpeqvl, var_sys_o, 2
			dw kw_goto_iffalse_n, if70_3

			; Main.bas 506: ResetSlot s
			dw p_resetslot_c, var_sys_s

			; Main.bas 507: If s = t Then Prompt t                       ' (RESET of its own slot: the program gone)
			dw kw_cpeqvv, var_sys_s, var_sys_t
			dw kw_goto_iffalse_n, if70_e
			dw p_prompt_c, var_sys_t
if74_1:

			; Main.bas 508: ElseIf o = 3 Then
			dw if70_e_go
if70_3:
			dw kw_cpeqvl, var_sys_o, 3
			dw kw_goto_iffalse_n, if70_4

			; Main.bas 509: ToFront s
			dw p_tofront_c, var_sys_s

			; Main.bas 510: End If
if70_4:
if70_e:
			dw p_sys_r

ntc_rg10_e:
			IF ($ < 32768) && (ntc_rg11_e - ntc_rg11 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg11:
; ============================================================
; sub puten (normal mode)
; ============================================================

p_puten:

			; Main.bas 515: Memory.WriteByte Far(t, a), Len(en)
			dw p_far_c, var_puten_t, var_puten_a
			dw kw_strlen, var_en, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 516: Memory.Copy NearP(VarPtr(en)), Far(t, a + 1), Len(en)
			dw p_nearp_c, vp_var_en
			dw kw_addl, var_puten_a, 1, tmp2
			dw p_far_c, var_puten_t, tmp2
			dw kw_strlen, var_en, tmp2
			dw fn_memory_copy, var_nearp_nearp, var_far_far, tmp2, var_memory_copy_copy
			dw p_puten_r

ntc_rg11_e:
			IF ($ < 32768) && (ntc_rg12_e - ntc_rg12 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg12:
; ============================================================
; function hopen (normal mode)
; ============================================================

p_hopen:

			; Main.bas 522: HOpen = (Hyp.FileCall(100, VarPtr(dn), 0, 0, Len(dn), 0, 0) = 0)
			dw kw_strlen, var_dn, tmp4
			dw p_hyp_filecall_c, lit_100, vp_var_dn, lit_0, lit_0, tmp4, lit_0, lit_0
			dw kw_vtov, var_hyp_filecall_filecall, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_ftov, var_hopen_hopen
			dw p_hopen_r

ntc_rg12_e:
			IF ($ < 32768) && (ntc_rg13_e - ntc_rg13 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg13:
; ============================================================
; sub hclose (normal mode)
; ============================================================

p_hclose:

			; Main.bas 528: Dim r As Integer

			; Main.bas 529: r = Hyp.FileCall(102, 0, 0, 0, 0, 0, 0)
			dw p_hyp_filecall_c, lit_102, lit_0, lit_0, lit_0, lit_0, lit_0, lit_0
			dw kw_vtov, var_hyp_filecall_filecall, var_hclose_r
			dw p_hclose_r

ntc_rg13_e:
			IF ($ < 32768) && (ntc_rg14_e - ntc_rg14 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg14:
; ============================================================
; sub filesshut (normal mode)
; ============================================================

p_filesshut:

			; Main.bas 534: Hyp.FileShut t
			dw p_hyp_fileshut_c, var_filesshut_t
			dw p_filesshut_r

ntc_rg14_e:
			IF ($ < 32768) && (ntc_rg15_e - ntc_rg15 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg15:
; ============================================================
; sub collected (normal mode)
; ============================================================

p_collected:

			; Main.bas 543: nc(t) = nc(t) + n
			dw kw_aget, arr_nc, var_collected_t, tmp1
			dw kw_add, tmp1, var_collected_n, tmp1
			dw kw_aset, arr_nc, var_collected_t, tmp1

			; Main.bas 544: Hyp.Con wp(t), 0, n, IIf(t = front, 1, 0)       ' straight from the bank: no copy to main RAM
			dw kw_aget, arr_wp, var_collected_t, tmp0
			dw kw_cpeqvv, var_collected_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch75_0
			dw kw_ltov, 1, tmp3
			dw ch75_e_go
ch75_0:
			dw kw_ztov, tmp3
			dw ch75_e_go
ch75_1:
			dw kw_ztov, tmp3
ch75_e:
			dw p_hyp_con_c, tmp0, lit_0, var_collected_n, tmp3
			dw p_collected_r

ntc_rg15_e:
			IF ($ < 32768) && (ntc_rg16_e - ntc_rg16 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg16:
; ============================================================
; sub puts (normal mode)
; ============================================================

p_puts:

			; Main.bas 549: Hyp.Con wp(t), VarPtr(s), Len(s), IIf(t = front, 1, 0)
			dw kw_aget, arr_wp, var_puts_t, tmp0
			dw kw_strlen, var_puts_s, tmp2
			dw kw_cpeqvv, var_puts_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch76_0
			dw kw_ltov, 1, tmp3
			dw ch76_e_go
ch76_0:
			dw kw_ztov, tmp3
			dw ch76_e_go
ch76_1:
			dw kw_ztov, tmp3
ch76_e:
			dw p_hyp_con_c, tmp0, vp_var_puts_s, tmp2, tmp3
			dw p_puts_r

ntc_rg16_e:
			IF ($ < 32768) && (ntc_rg17_e - ntc_rg17 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg17:
; ============================================================
; sub putln (normal mode)
; ============================================================

p_putln:

			; Main.bas 553: PutS t, s + Chr$(13) + Chr$(10)
			dw kw_strcpy, stmp1, var_putln_s
			dw kw_strcat, stmp1, str8
			dw kw_strcat, stmp1, str9
			dw p_puts_c, var_putln_t, stmp1
			dw p_putln_r

ntc_rg17_e:
			IF ($ < 32768) && (ntc_rg18_e - ntc_rg18 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg18:
; ============================================================
; sub putc (normal mode)
; ============================================================

p_putc:

			; Main.bas 558: Hyp.Con wp(t), VarPtr(c), 1, IIf(t = front, 1, 0)   ' (the Integer's low byte is the character)
			dw kw_aget, arr_wp, var_putc_t, tmp0
			dw kw_cpeqvv, var_putc_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch77_0
			dw kw_ltov, 1, tmp3
			dw ch77_e_go
ch77_0:
			dw kw_ztov, tmp3
			dw ch77_e_go
ch77_1:
			dw kw_ztov, tmp3
ch77_e:
			dw p_hyp_con_c, tmp0, vp_var_putc_c, lit_1, tmp3
			dw p_putc_r

ntc_rg18_e:
			IF ($ < 32768) && (ntc_rg19_e - ntc_rg19 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg19:
; ============================================================
; function nearp (normal mode)
; ============================================================

p_nearp:

			; Main.bas 581: NearP = CLng(p)
			dw kw_l_itol, var_nearp_p, var_nearp_nearp

			; Main.bas 582: If p < 0 Then NearP = NearP + 65536
			dw kw_scpltvl, var_nearp_p, 0
			dw kw_goto_iffalse_n, if78_1
			dw kw_l_add, var_nearp_nearp, llit_65536, var_nearp_nearp
if78_1:
			dw p_nearp_r

ntc_rg19_e:
			IF ($ < 32768) && (ntc_rg20_e - ntc_rg20 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg20:
; ============================================================
; function far (normal mode)
; ============================================================

p_far:

			; Main.bas 587: Far = Hyp.FarPtr(Memory.BankPage(bk(t), ((a And &HC000) \ 16384) And 3), a)
			dw kw_aget, arr_bk, var_far_t, tmp2
			dw kw_andvl, var_far_a, -16384, tmp3
			dw kw_divvl, tmp3, 16384, tmp3
			dw kw_andvl, tmp3, 3, tmp3
			dw p_memory_bankpage_c, tmp2, tmp3
			dw kw_vtov, var_memory_bankpage_bankpage, tmp2
			dw fn_hyp_farptr, tmp2, var_far_a, var_far_far
			dw p_far_r

ntc_rg20_e:
			IF ($ < 32768) && (ntc_rg21_e - ntc_rg21 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg21:
; ============================================================
; sub clst (normal mode)
; ============================================================

p_clst:

			; Main.bas 592: PutS t, Chr$(27) + "E"
			dw kw_strcpy, stmp1, str10
			dw kw_strcat, stmp1, str11
			dw p_puts_c, var_clst_t, stmp1
			dw p_clst_r

ntc_rg21_e:
			IF ($ < 32768) && (ntc_rg22_e - ntc_rg22 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg22:
; ============================================================
; sub tofront (normal mode)
; ============================================================

p_tofront:

			; Main.bas 597: Dim r As Integer

			; Main.bas 598: front = t
			dw kw_vtov, var_tofront_t, var_front

			; Main.bas 599: If st(t) = 0 Then OpenSlot t : Exit Sub
			dw kw_aget, arr_st, var_tofront_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if79_1
			dw p_openslot_c, var_tofront_t
			dw p_tofront_r
if79_1:

			; Main.bas 600: r = Hyp.Scr(Memory.ReadByte(Far(t, Hyp.CMODE)), 2)   ' the screen in its mode (cleared)
			dw p_far_c, var_tofront_t, lit_m2423
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_memory_readbyte_readbyte
			dw kw_vtov, var_memory_readbyte_readbyte, tmp0
			dw p_hyp_scr_c, tmp0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_tofront_r

			; Main.bas 601: Hyp.Show wp(t)
			dw kw_aget, arr_wp, var_tofront_t, tmp0
			dw p_hyp_show_c, tmp0
			dw p_tofront_r

ntc_rg22_e:
			IF ($ < 32768) && (ntc_rg23_e - ntc_rg23 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg23:
; ============================================================
; sub setmode (normal mode)
; ============================================================

p_setmode:

			; Main.bas 608: Dim r As Integer

			; Main.bas 609: Memory.WriteByte Far(t, Hyp.CCOLS), Hyp.Scr(m, 0)
			dw p_far_c, var_setmode_t, lit_m2425
			dw p_hyp_scr_c, var_setmode_m, lit_0
			dw fn_memory_writebyte, var_far_far, var_hyp_scr_scr

			; Main.bas 610: Memory.WriteByte Far(t, Hyp.CROWS), Hyp.Scr(m, 1)
			dw p_far_c, var_setmode_t, lit_m2424
			dw p_hyp_scr_c, var_setmode_m, lit_1
			dw fn_memory_writebyte, var_far_far, var_hyp_scr_scr

			; Main.bas 611: Memory.WriteByte Far(t, Hyp.CMODE), m
			dw p_far_c, var_setmode_t, lit_m2423
			dw fn_memory_writebyte, var_far_far, var_setmode_m

			; Main.bas 612: en = Left$("[" + N(t) + "]   ", 4)
			dw p_n_c, var_setmode_t
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcpy, stmp0, str12
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str13
			dw kw_strleft, stmp0, stmp0, lit_4
			dw kw_strcpy, var_en, stmp0

			; Main.bas 613: Memory.Copy NearP(VarPtr(en)), Far(t, Hyp.CSTRIP), 4
			dw p_nearp_c, vp_var_en
			dw p_far_c, var_setmode_t, lit_m2422
			dw fn_memory_copy, var_nearp_nearp, var_far_far, lit_4, var_memory_copy_copy

			; Main.bas 614: If t = front Then r = Hyp.Scr(m, 2)
			dw kw_cpeqvv, var_setmode_t, var_front
			dw kw_goto_iffalse_n, if80_1
			dw p_hyp_scr_c, var_setmode_m, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_setmode_r
if80_1:

			; Main.bas 615: ClsT t
			dw p_clst_c, var_setmode_t
			dw p_setmode_r

ntc_rg23_e:
			IF ($ < 32768) && (ntc_rg24_e - ntc_rg24 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg24:
; ============================================================
; sub showtop (normal mode)
; ============================================================

p_showtop:

			; Main.bas 778: Dim j As Integer

			; Main.bas 779: If front <> 0 Then back = front
			dw kw_cpnevl, var_front, 0
			dw kw_goto_iffalse_n, if81_1
			dw kw_vtov, var_front, var_back
if81_1:

			; Main.bas 780: front = 0
			dw kw_ztov, var_front

			; Main.bas 781: j = Hyp.Scr(0, 2)               ' TOP in MODE 2 (80 x 25), the screen cleared
			dw p_hyp_scr_c, lit_0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_showtop_j

			; Main.bas 782: txs = 0
			dw kw_ztov, var_txs

			; Main.bas 783: TopLines back, 1
			dw p_toplines_c, var_back, lit_1
			dw p_showtop_r

ntc_rg24_e:
			IF ($ < 32768) && (ntc_rg25_e - ntc_rg25 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg25:
; ============================================================
; sub toplines (normal mode)
; ============================================================

p_toplines:

			; Main.bas 789: Dim j As Integer, s As String Max 14

			; Main.bas 790: txn = 0
			dw kw_ztov, var_txn

			; Main.bas 791: TopAdd "CyborgOS TOP"
			dw p_topadd_c, str14

			; Main.bas 792: If keys Then TopAdd "Control + ESC: back, " + SK() + ": that slot" Else TopAdd ""   ' (25 rows: 20 slots)
			dw kw_goto_ifzero_n, var_toplines_keys, if82_1
			dw p_sk_c
			dw kw_strcpy, stmp1, var_sk_sk
			dw kw_strcpy, stmp0, str15
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str16
			dw p_topadd_c, stmp0
			dw if82_e_go
if82_1:
			dw p_topadd_c, str2
if82_e:

			; Main.bas 793: TopAdd "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (last second)"
			dw p_topadd_c, str17

			; Main.bas 794: For j = 1 To ns
			dw kw_ltov, 1, var_toplines_j
			dw kw_vtov, var_ns, for83_l
			dw kw_forupv_n, var_toplines_j, for83_l, for83_e
for83_t:

			; Main.bas 795: If st(j) = 0 Then
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if84_1

			; Main.bas 796: s = "-"
			dw kw_strcpy, var_toplines_s, str18

			; Main.bas 797: ElseIf st(j) = 1 Then
			dw if84_e_go
if84_1:
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 1
			dw kw_goto_iffalse_n, if84_2

			; Main.bas 798: s = "command line"
			dw kw_strcpy, var_toplines_s, str19

			; Main.bas 799: ElseIf wk(j) >= 0 Then
			dw if84_e_go
if84_2:
			dw kw_aget, arr_wk, var_toplines_j, tmp0
			dw kw_scpgevl, tmp0, 0
			dw kw_goto_iffalse_n, if84_3

			; Main.bas 800: s = "waiting (key)"
			dw kw_strcpy, var_toplines_s, str20

			; Main.bas 801: Else
			dw if84_e_go
if84_3:

			; Main.bas 802: s = "running"
			dw kw_strcpy, var_toplines_s, str21

			; Main.bas 803: End If
if84_e:

			; Main.bas 804: en = ""
			dw kw_strcpy, var_en, str2

			; Main.bas 805: If st(j) = 2 Then GetNm j
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if85_1
			dw p_getnm_c, var_toplines_j
if85_1:

			; Main.bas 806: TopAdd " " + Right$(" " + N(j), 2) + IIf(j = mark, "*", " ") + "  " + Left$(s + Space$(15), 15) + Left$(en + Space$(13), 13) + Pad(Rate(lt(j), ld)) + Pad(Rate(lb(j), ld)) + Pad(Rate(lc(j), ld))
			dw p_n_c, var_toplines_j
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcpy, stmp1, str22
			dw kw_strcat, stmp1, stmp2
			dw kw_strright, stmp1, stmp1, lit_2
			dw kw_strcpy, stmp0, str22
			dw kw_strcat, stmp0, stmp1
			dw kw_cpeqvv, var_toplines_j, var_toplines_mark
			dw kw_ftov, tmp1
			dw kw_goto_ifzero_n, tmp1, ch86_0
			dw kw_strcpy, stmp1, str23
			dw ch86_e_go
ch86_0:
			dw kw_strcpy, stmp1, str22
			dw ch86_e_go
ch86_1:
			dw kw_strcpy, stmp1, str2
ch86_e:
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str24
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

			; Main.bas 807: Next
			dw kw_next1v_n, var_toplines_j, for83_l, for83_t
for83_e:

			; Main.bas 808: TopAdd ""
			dw p_topadd_c, str2

			; Main.bas 809: Totals
			dw p_totals_c

			; Main.bas 810: TopAdd en
			dw p_topadd_c, var_en
			dw p_toplines_r

ntc_rg25_e:
			IF ($ < 32768) && (ntc_rg26_e - ntc_rg26 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg26:
; ============================================================
; sub totals (normal mode)
; ============================================================

p_totals:

			; Main.bas 815: en = "Total memory: " + N(Memory.RamSize()) + " KB   Free memory: " + N(Memory.FreePages() * 16) + " KB"
			dw fn_memory_ramsize, var_memory_ramsize_ramsize
			dw kw_vtov, var_memory_ramsize_ramsize, tmp1
			dw p_n_c, tmp1
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcpy, stmp0, str25
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str26
			dw fn_memory_freepages, var_memory_freepages_freepages
			dw kw_vtov, var_memory_freepages_freepages, tmp1
			dw kw_mulvl, tmp1, 16, tmp1
			dw p_n_c, tmp1
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcat, stmp0, stmp1
			dw kw_strcpy, var_en, stmp0
			dw kw_strcat, var_en, str27
			dw p_totals_r

ntc_rg26_e:
			IF ($ < 32768) && (ntc_rg27_e - ntc_rg27 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg27:
; ============================================================
; sub topadd (normal mode)
; ============================================================

p_topadd:

			; Main.bas 823: If txs = 0 Then
			dw kw_cpeqvl, var_txs, 0
			dw kw_goto_iffalse_n, if87_1

			; Main.bas 824: Hyp.Say VarPtr(s), Len(s), 0, txn          ' straight into screen memory (Print took ~0.7 s)
			dw kw_strlen, var_topadd_s, tmp1
			dw p_hyp_say_c, vp_var_topadd_s, tmp1, lit_0, var_txn

			; Main.bas 825: Else
			dw if87_e_go
if87_1:

			; Main.bas 826: PutLn txs, s
			dw p_putln_c, var_txs, var_topadd_s

			; Main.bas 827: End If
if87_e:

			; Main.bas 828: txn = txn + 1
			dw kw_inc, var_txn
			dw p_topadd_r

ntc_rg27_e:
			IF ($ < 32768) && (ntc_rg28_e - ntc_rg28 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg28:
; ============================================================
; sub roll (normal mode)
; ============================================================

p_roll:

			; Main.bas 833: Dim j As Integer

			; Main.bas 834: ld = Ticks - td
			dw kw_ticks, tmp0
			dw kw_subvv, tmp0, var_td, var_ld

			; Main.bas 835: td = Ticks
			dw kw_ticks, tmp0
			dw kw_vtov, tmp0, var_td

			; Main.bas 836: For j = 1 To ns
			dw kw_ltov, 1, var_roll_j
			dw kw_vtov, var_ns, for88_l
			dw kw_forupv_n, var_roll_j, for88_l, for88_e
for88_t:

			; Main.bas 837: lt(j) = tn(j) : lb(j) = nb(j) : lc(j) = nc(j)
			dw kw_aget, arr_tn, var_roll_j, tmp1
			dw kw_aset, arr_lt, var_roll_j, tmp1
			dw kw_aget, arr_nb, var_roll_j, tmp1
			dw kw_aset, arr_lb, var_roll_j, tmp1
			dw kw_aget, arr_nc, var_roll_j, tmp1
			dw kw_aset, arr_lc, var_roll_j, tmp1

			; Main.bas 838: tn(j) = 0 : nb(j) = 0 : nc(j) = 0
			dw kw_asetl, arr_tn, var_roll_j, 0
			dw kw_asetl, arr_nb, var_roll_j, 0
			dw kw_asetl, arr_nc, var_roll_j, 0

			; Main.bas 839: Next
			dw kw_next1v_n, var_roll_j, for88_l, for88_t
for88_e:
			dw p_roll_r

ntc_rg28_e:
			IF ($ < 32768) && (ntc_rg29_e - ntc_rg29 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg29:
; ============================================================
; function pad (normal mode)
; ============================================================

p_pad:

			; Main.bas 844: Pad = Right$(Space$(9) + N(v), 9)
			dw kw_strspace, stmp1, lit_9
			dw p_n_c, var_pad_v
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcat, stmp1, stmp2
			dw kw_strright, var_pad_pad, stmp1, lit_9
			dw p_pad_r

ntc_rg29_e:
			IF ($ < 32768) && (ntc_rg30_e - ntc_rg30 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg30:
; ============================================================
; function rate (normal mode)
; ============================================================

p_rate:

			; Main.bas 849: If n > 1000 Then Rate = n \ (d \ 300 + 1) Else Rate = n * 30 \ (d \ 10 + 1)
			dw kw_scpgtvl, var_rate_n, 1000
			dw kw_goto_iffalse_n, if89_1
			dw kw_divvl, var_rate_d, 300, tmp2
			dw kw_inc, tmp2
			dw kw_divvv, var_rate_n, tmp2, var_rate_rate
			dw if89_e_go
if89_1:
			dw kw_mulvl, var_rate_n, 30, tmp1
			dw kw_divvl, var_rate_d, 10, tmp2
			dw kw_inc, tmp2
			dw kw_divvv, tmp1, tmp2, var_rate_rate
if89_e:
			dw p_rate_r

ntc_rg30_e:
			IF ($ < 32768) && (ntc_rg31_e - ntc_rg31 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg31:
; ============================================================
; sub install (normal mode)
; ============================================================

p_install:

			; Main.bas 856: Dim p As Integer, n As Integer

			; Main.bas 857: p = Hyp.Info(0) : n = Hyp.Info(1)             ' (one Info result each: it is one variable)
			dw fn_hyp_info, lit_0, var_install_p
			dw fn_hyp_info, lit_1, var_install_n

			; Main.bas 858: Memory.Copy Hyp.FarPtr(hp, p), Far(t, 0), n   ' (from the hypervisor's page)
			dw fn_hyp_farptr, var_hp, var_install_p, var_hyp_farptr_farptr
			dw p_far_c, var_install_t, lit_0
			dw fn_memory_copy, var_hyp_farptr_farptr, var_far_far, var_install_n, var_memory_copy_copy

			; Main.bas 859: p = Hyp.Info(2) : n = Hyp.Info(3)
			dw fn_hyp_info, lit_2, var_install_p
			dw fn_hyp_info, lit_3, var_install_n

			; Main.bas 860: Memory.Copy Hyp.FarPtr(hp, p), Far(t, Hyp.STUB), n
			dw fn_hyp_farptr, var_hp, var_install_p, var_hyp_farptr_farptr
			dw p_far_c, var_install_t, lit_m4352
			dw fn_memory_copy, var_hyp_farptr_farptr, var_far_far, var_install_n, var_memory_copy_copy

			; Main.bas 861: Memory.Copy Hyp.FarPtr(hp, Hyp.HFONT), Far(t, Hyp.FONT), 768   ' the font (Con draws from it)
			dw fn_hyp_farptr, var_hp, lit_4096, var_hyp_farptr_farptr
			dw p_far_c, var_install_t, lit_m3328
			dw fn_memory_copy, var_hyp_farptr_farptr, var_far_far, lit_768, var_memory_copy_copy

			; Main.bas 862: Memory.WriteByte Far(t, Hyp.OBUF + 128), 0      ' no characters collected
			dw p_far_c, var_install_t, lit_m2432
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 863: Memory.WriteByte Far(t, Hyp.KEY), 0             ' no key waiting
			dw p_far_c, var_install_t, lit_m2431
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 864: kq(t) = 0
			dw kw_asetl, arr_kq, var_install_t, 0

			; Main.bas 867: For n = 0 To 31                                 ' no store yet
			dw kw_ztov, var_install_n
for90_t:

			; Main.bas 868: Memory.WriteByte Far(t, STORE + n), 0
			dw kw_addl, var_install_n, -256, tmp1
			dw p_far_c, var_install_t, tmp1
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 869: Next
			dw kw_next1l_n, var_install_n, 31, for90_t
for90_e:
			dw p_install_r

ntc_rg31_e:
			IF ($ < 32768) && (ntc_rg32_e - ntc_rg32 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg32:
; ============================================================
; sub resetslot (normal mode)
; ============================================================

p_resetslot:

			; Main.bas 876: FilesShut s
			dw p_filesshut_c, var_resetslot_s

			; Main.bas 879: If st(s) = 2 Then StoreFree s
			dw kw_aget, arr_st, var_resetslot_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if91_1
			dw p_storefree_c, var_resetslot_s
if91_1:

			; Main.bas 881: st(s) = 0
			dw kw_asetl, arr_st, var_resetslot_s, 0

			; Main.bas 884: dv(s) = 0
			dw kw_asetl, arr_dv, var_resetslot_s, 0

			; Main.bas 886: kq(s) = 0
			dw kw_asetl, arr_kq, var_resetslot_s, 0

			; Main.bas 887: wk(s) = -1
			dw kw_asetl, arr_wk, var_resetslot_s, -1

			; Main.bas 888: tn(s) = 0 : nb(s) = 0 : nc(s) = 0
			dw kw_asetl, arr_tn, var_resetslot_s, 0
			dw kw_asetl, arr_nb, var_resetslot_s, 0
			dw kw_asetl, arr_nc, var_resetslot_s, 0

			; Main.bas 889: lt(s) = 0 : lb(s) = 0 : lc(s) = 0
			dw kw_asetl, arr_lt, var_resetslot_s, 0
			dw kw_asetl, arr_lb, var_resetslot_s, 0
			dw kw_asetl, arr_lc, var_resetslot_s, 0

			; Main.bas 890: If s = front Then
			dw kw_cpeqvv, var_resetslot_s, var_front
			dw kw_goto_iffalse_n, if92_1

			; Main.bas 891: Install s
			dw p_install_c, var_resetslot_s

			; Main.bas 892: st(s) = 1
			dw kw_asetl, arr_st, var_resetslot_s, 1

			; Main.bas 893: SetMode s, 1
			dw p_setmode_c, var_resetslot_s, lit_1

			; Main.bas 894: PutLn s, "CyborgOS slot " + N(s) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
			dw p_n_c, var_resetslot_s
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcpy, stmp1, str28
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str29
			dw p_n_c, var_ns
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str30
			dw p_sk_c
			dw kw_strcpy, stmp2, var_sk_sk
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str31
			dw p_putln_c, var_resetslot_s, stmp1

			; Main.bas 895: PutLn s, ""                   ' a blank line under the title
			dw p_putln_c, var_resetslot_s, str2

			; Main.bas 896: End If                          ' (the prompt: the command line puts it after the command)
if92_1:
			dw p_resetslot_r

ntc_rg32_e:
			IF ($ < 32768) && (ntc_rg33_e - ntc_rg33 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg33:
; ============================================================
; sub openslot (normal mode)
; ============================================================

p_openslot:

			; Main.bas 900: Install t
			dw p_install_c, var_openslot_t

			; Main.bas 901: st(t) = 1
			dw kw_asetl, arr_st, var_openslot_t, 1

			; Main.bas 902: SetMode t, 1                    ' MODE S: 80 x 24 and the status strip
			dw p_setmode_c, var_openslot_t, lit_1

			; Main.bas 903: PutLn t, "CyborgOS slot " + N(t) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
			dw p_n_c, var_openslot_t
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcpy, stmp1, str28
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str29
			dw p_n_c, var_ns
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str30
			dw p_sk_c
			dw kw_strcpy, stmp2, var_sk_sk
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str31
			dw p_putln_c, var_openslot_t, stmp1

			; Main.bas 904: PutLn t, ""                     ' a blank line under the title
			dw p_putln_c, var_openslot_t, str2

			; Main.bas 905: Prompt t
			dw p_prompt_c, var_openslot_t
			dw p_openslot_r

ntc_rg33_e:
			IF ($ < 32768) && (ntc_rg34_e - ntc_rg34 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg34:
; ============================================================
; function sk (normal mode)
; ============================================================

p_sk:

			; Main.bas 910: If ns <= 9 Then
			dw kw_scplevl, var_ns, 9
			dw kw_goto_iffalse_n, if93_1

			; Main.bas 911: SK = "Control + 1-" + N(ns)
			dw p_n_c, var_ns
			dw kw_strcpy, stmp3, var_n_n
			dw kw_strcpy, var_sk_sk, str32
			dw kw_strcat, var_sk_sk, stmp3

			; Main.bas 912: ElseIf ns = 10 Then
			dw if93_e_go
if93_1:
			dw kw_cpeqvl, var_ns, 10
			dw kw_goto_iffalse_n, if93_2

			; Main.bas 913: SK = "Control + 1-9, 0"
			dw kw_strcpy, var_sk_sk, str33

			; Main.bas 914: Else
			dw if93_e_go
if93_2:

			; Main.bas 915: SK = "Control + 1-9, 0 (twice 11-" + N(ns) + ")"
			dw p_n_c, var_ns
			dw kw_strcpy, stmp3, var_n_n
			dw kw_strcpy, stmp2, str34
			dw kw_strcat, stmp2, stmp3
			dw kw_strcpy, var_sk_sk, stmp2
			dw kw_strcat, var_sk_sk, str35

			; Main.bas 916: End If
if93_e:
			dw p_sk_r

ntc_rg34_e:
			IF ($ < 32768) && (ntc_rg35_e - ntc_rg35 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg35:
; ============================================================
; sub getnm (normal mode)
; ============================================================

p_getnm:

			; Main.bas 923: Dim n As Integer

			; Main.bas 924: n = Memory.ReadByte(Far(t, NMLEN))
			dw p_far_c, var_getnm_t, lit_m2344
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_getnm_n

			; Main.bas 925: en = Space$(12)
			dw kw_strspace, stmp0, lit_12
			dw kw_strcpy, var_en, stmp0

			; Main.bas 926: Memory.Copy Far(t, NMBUF), NearP(VarPtr(en)), n
			dw p_far_c, var_getnm_t, lit_m2343
			dw p_nearp_c, vp_var_en
			dw fn_memory_copy, var_far_far, var_nearp_nearp, var_getnm_n, var_memory_copy_copy

			; Main.bas 927: en = Left$(en, n)
			dw kw_strleft, stmp0, var_en, var_getnm_n
			dw kw_strcpy, var_en, stmp0
			dw p_getnm_r

ntc_rg35_e:
			IF ($ < 32768) && (ntc_rg36_e - ntc_rg36 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg36:
; ============================================================
; function n (normal mode)
; ============================================================

p_n:

			; Main.bas 931: N = Trim$(Str$(v))
			dw kw_strstr, stmp3, var_n_v
			dw kw_strtrim, var_n_n, stmp3
			dw p_n_r

ntc_rg36_e:
			IF ($ < 32768) && (ntc_rg37_e - ntc_rg37 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg37:
; ============================================================
; sub prompt (normal mode)
; ============================================================

p_prompt:

			; Main.bas 935: Memory.WriteByte Far(t, LNLEN), 0                ' an empty command line
			dw p_far_c, var_prompt_t, lit_m2417
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 936: PutS t, N(t) + "> "
			dw p_n_c, var_prompt_t
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcat, stmp1, str36
			dw p_puts_c, var_prompt_t, stmp1
			dw p_prompt_r

ntc_rg37_e:
			IF ($ < 32768) && (ntc_rg38_e - ntc_rg38 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg38:
; ============================================================
; sub keyin (normal mode)
; ============================================================

p_keyin:

			; Main.bas 941: Dim t As Integer, n As Integer

			; Main.bas 942: If front = 0 Then
			dw kw_cpeqvl, var_front, 0
			dw kw_goto_iffalse_n, if94_1

			; Main.bas 943: Exit Sub                      ' TOP stays until Control + ESC or Control + a slot
			dw p_keyin_r

			; Main.bas 944: End If
if94_1:

			; Main.bas 945: t = front
			dw kw_vtov, var_front, var_keyin_t

			; Main.bas 949: If st(t) = 2 Then
			dw kw_aget, arr_st, var_keyin_t, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if95_1

			; Main.bas 950: If k = &HFC Then k = 27                       ' (ESC: the firmware's #FC - CP/M's #1B, as Amstrad's CP/M)
			dw kw_cpeqvl, var_keyin_k, 252
			dw kw_goto_iffalse_n, if96_1
			dw kw_ltov, 27, var_keyin_k
if96_1:

			; Main.bas 951: kq(t) = k                                     ' the key into its bank: its BDOS answers from it
			dw kw_aset, arr_kq, var_keyin_t, var_keyin_k

			; Main.bas 952: Memory.WriteByte Far(t, Hyp.KEY), k
			dw p_far_c, var_keyin_t, lit_m2431
			dw fn_memory_writebyte, var_far_far, var_keyin_k

			; Main.bas 953: Exit Sub
			dw p_keyin_r

			; Main.bas 954: End If
if95_1:

			; Main.bas 955: n = Memory.ReadByte(Far(t, LNLEN))             ' the command line so far (in the slot's bank)
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_keyin_n

			; Main.bas 956: If k = 13 Then
			dw kw_cpeqvl, var_keyin_k, 13
			dw kw_goto_iffalse_n, if97_1

			; Main.bas 957: PutLn t, ""
			dw p_putln_c, var_keyin_t, str2

			; Main.bas 958: Command t
			dw p_command_c, var_keyin_t

			; Main.bas 959: If st(t) = 1 And wt = 0 And front = t Then Prompt t
			dw kw_aget, arr_st, var_keyin_t, tmp0
			dw kw_cpeqvl, tmp0, 1
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_wt, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_cpeqvv, var_front, var_keyin_t
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if97_e
			dw p_prompt_c, var_keyin_t
if98_1:

			; Main.bas 960: ElseIf k = 127 Or k = 8 Then
			dw if97_e_go
if97_1:
			dw kw_cpeqvl, var_keyin_k, 127
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_keyin_k, 8
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if97_2

			; Main.bas 961: If n > 0 Then
			dw kw_scpgtvl, var_keyin_n, 0
			dw kw_goto_iffalse_n, if97_e

			; Main.bas 962: Memory.WriteByte Far(t, LNLEN), n - 1
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_addl, var_keyin_n, -1, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 963: PutC t, 8 : PutC t, 32 : PutC t, 8
			dw p_putc_c, var_keyin_t, lit_8
			dw p_putc_c, var_keyin_t, lit_32
			dw p_putc_c, var_keyin_t, lit_8

			; Main.bas 964: End If
if99_1:

			; Main.bas 965: ElseIf k >= 32 And k < 127 And n < 70 Then
			dw if97_e_go
if97_2:
			dw kw_scpgevl, var_keyin_k, 32
			dw kw_ftov, tmp0
			dw kw_scpltvl, var_keyin_k, 127
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_scpltvl, var_keyin_n, 70
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if97_3

			; Main.bas 966: Memory.WriteByte Far(t, LNBUF + n), k
			dw kw_addl, var_keyin_n, -2416, tmp1
			dw p_far_c, var_keyin_t, tmp1
			dw fn_memory_writebyte, var_far_far, var_keyin_k

			; Main.bas 967: Memory.WriteByte Far(t, LNLEN), n + 1
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_addl, var_keyin_n, 1, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 968: PutC t, k
			dw p_putc_c, var_keyin_t, var_keyin_k

			; Main.bas 969: End If
if97_3:
if97_e:
			dw p_keyin_r

ntc_rg38_e:
			IF ($ < 32768) && (ntc_rg39_e - ntc_rg39 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg39:
; ============================================================
; sub command (normal mode)
; ============================================================

p_command:

			; Main.bas 973: Dim c As String Max 72, p As Integer, s As Integer

			; Main.bas 974: p = Memory.ReadByte(Far(t, LNLEN))              ' the command line, from the slot's bank
			dw p_far_c, var_command_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_command_p

			; Main.bas 975: Memory.Copy Far(t, LNBUF), NearP(VarPtr(ob)), p
			dw p_far_c, var_command_t, lit_m2416
			dw p_nearp_c, vp_var_ob
			dw fn_memory_copy, var_far_far, var_nearp_nearp, var_command_p, var_memory_copy_copy

			; Main.bas 976: c = UCase$(Trim$(Left$(ob, p)))
			dw kw_strleft, stmp0, var_ob, var_command_p
			dw kw_strtrim, stmp0, stmp0
			dw kw_strucase, stmp0, stmp0
			dw kw_strcpy, var_command_c, stmp0

			; Main.bas 977: a = "" : b = ""
			dw kw_strcpy, var_a, str2
			dw kw_strcpy, var_b, str2

			; Main.bas 978: p = InStr(c, " ")
			dw kw_strinstr, lit_1, var_command_c, str22, var_command_p

			; Main.bas 979: If p > 0 Then
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if100_1

			; Main.bas 980: a = Trim$(Mid$(c, p + 1))
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_command_c, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_a, stmp0

			; Main.bas 981: c = Left$(c, p - 1)
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_command_c, tmp1
			dw kw_strcpy, var_command_c, stmp0

			; Main.bas 982: End If
if100_1:

			; Main.bas 983: p = InStr(a, " ")
			dw kw_strinstr, lit_1, var_a, str22, var_command_p

			; Main.bas 984: If p > 0 Then
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if101_1

			; Main.bas 985: b = Trim$(Mid$(a, p + 1))
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0

			; Main.bas 986: a = Left$(a, p - 1)
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_a, tmp1
			dw kw_strcpy, var_a, stmp0

			; Main.bas 987: End If
if101_1:

			; Main.bas 988: If Right$(c, 1) = ":" And a = "" Then a = c : c = "CD"   ' B: or IDE: alone: CD B:, CD IDE: (CD.CYB)
			dw kw_strright, stmp0, var_command_c, lit_1
			dw kw_strcmpeq, stmp0, str37
			dw kw_ftov, tmp0
			dw kw_strcmpeq, var_a, str2
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if102_1
			dw kw_strcpy, var_a, var_command_c
			dw kw_strcpy, var_command_c, str38
if102_1:

			; Main.bas 989: Select Case c
			dw kw_strcpy, var_command___sel103, var_command_c

			; Main.bas 990: Case ""
			dw kw_strcmpeq, var_command___sel103, str2
			dw kw_goto_iffalse_n, sel103_1
sel103_b1:

			; Main.bas 991: Case "CLS"
			dw sel103_e_go
sel103_1:
			dw kw_strcmpeq, var_command___sel103, str39
			dw kw_goto_iffalse_n, sel103_2
sel103_b2:

			; Main.bas 992: ClsT t
			dw p_clst_c, var_command_t

			; Main.bas 993: Case "RUN"                                 ' RUN [slot] name [tail]: the program on the disc even
			dw sel103_e_go
sel103_2:
			dw kw_strcmpeq, var_command___sel103, str40
			dw kw_goto_iffalse_n, sel103_3
sel103_b3:

			; Main.bas 994: s = t                                    ' when a command has its name; with a slot: in that one
			dw kw_vtov, var_command_t, var_command_s

			; Main.bas 995: If a <> "" And N(Val(a)) = a Then
			dw kw_strcmpne, var_a, str2
			dw kw_ftov, tmp0
			dw kw_strval, var_a, tmp1
			dw p_n_c, tmp1
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcmpeq, stmp1, var_a
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if104_1

			; Main.bas 996: s = Val(a) : a = b : b = ""
			dw kw_strval, var_a, var_command_s
			dw kw_strcpy, var_a, var_b
			dw kw_strcpy, var_b, str2

			; Main.bas 997: p = InStr(a, " ")
			dw kw_strinstr, lit_1, var_a, str22, var_command_p

			; Main.bas 998: If p > 0 Then b = Trim$(Mid$(a, p + 1)) : a = Left$(a, p - 1)
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if105_1
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_a, tmp1
			dw kw_strcpy, var_a, stmp0
if105_1:

			; Main.bas 999: End If
if104_1:

			; Main.bas 1000: If s < 1 Or s > ns Then PutLn t, "no slot" + Str$(s) : Exit Sub
			dw kw_scpltvl, var_command_s, 1
			dw kw_ftov, tmp0
			dw kw_scpgtvv, var_command_s, var_ns
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if106_1
			dw kw_strstr, stmp2, var_command_s
			dw kw_strcpy, stmp1, str41
			dw kw_strcat, stmp1, stmp2
			dw p_putln_c, var_command_t, stmp1
			dw p_command_r
if106_1:

			; Main.bas 1001: If st(s) = 2 Then PutLn t, "slot" + Str$(s) + " is busy" : Exit Sub
			dw kw_aget, arr_st, var_command_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if107_1
			dw kw_strstr, stmp2, var_command_s
			dw kw_strcpy, stmp1, str42
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str43
			dw p_putln_c, var_command_t, stmp1
			dw p_command_r
if107_1:

			; Main.bas 1002: StartTask t, s
			dw p_starttask_c, var_command_t, var_command_s

			; Main.bas 1003: Case "QUIT"
			dw sel103_e_go
sel103_3:
			dw kw_strcmpeq, var_command___sel103, str44
			dw kw_goto_iffalse_n, sel103_4
sel103_b4:

			; Main.bas 1004: quit = -1
			dw kw_ltov, -1, var_quit

			; Main.bas 1005: Case Else                                  ' the rest are programs (the system drive Z's, else
			dw sel103_e_go
sel103_4:

			; Main.bas 1006: b = Trim$(a + " " + b)                   ' the slot's drive, else A): PS, MEM, CD, DIR ... and
			dw kw_strcpy, stmp0, var_a
			dw kw_strcat, stmp0, str22
			dw kw_strcat, stmp0, var_b
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0

			; Main.bas 1007: a = c                                    ' any other, the rest of the line their tail
			dw kw_strcpy, var_a, var_command_c

			; Main.bas 1008: bare = -1
			dw kw_ltov, -1, var_bare

			; Main.bas 1009: StartTask t, t
			dw p_starttask_c, var_command_t, var_command_t

			; Main.bas 1010: bare = 0
			dw kw_ztov, var_bare

			; Main.bas 1011: End Select
sel103_e:
			dw p_command_r

ntc_rg39_e:
			IF ($ < 32768) && (ntc_rg40_e - ntc_rg40 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg40:
; ============================================================
; sub starttask (normal mode)
; ============================================================

p_starttask:

			; Main.bas 1019: Dim h As Integer, n As Integer, rest As Integer, com As Integer, w As String Max 72, d As Integer

			; Main.bas 1020: If a = "" Then PutLn t, "RUN what?" : Exit Sub
			dw kw_strcmpeq, var_a, str2
			dw kw_goto_iffalse_n, if108_1
			dw p_putln_c, var_starttask_t, str45
			dw p_starttask_r
if108_1:

			; Main.bas 1021: w = a
			dw kw_strcpy, var_starttask_w, var_a

			; Main.bas 1022: d = 0                                          ' the drive looked on: Z (-1, the system drive: the
			dw kw_ztov, var_starttask_d

			; Main.bas 1025: d = -1
			dw kw_ltov, -1, var_starttask_d

			; Main.bas 1027: Do
do109_t:

			; Main.bas 1030: If d = -1 Then
			dw kw_cpeqvl, var_starttask_d, -1
			dw kw_goto_iffalse_n, if110_1

			; Main.bas 1031: If Hyp.Drive(90) = 0 Then d = 0            ' (no system drive)
			dw p_hyp_drive_c, lit_90
			dw kw_vtov, var_hyp_drive_drive, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if111_1
			dw kw_ztov, var_starttask_d
if111_1:

			; Main.bas 1032: End If
if110_1:

			; Main.bas 1033: If d = 0 Then OwnDrive t
			dw kw_cpeqvl, var_starttask_d, 0
			dw kw_goto_iffalse_n, if112_1
			dw p_owndrive_c, var_starttask_t
if112_1:

			; Main.bas 1034: If d = 1 Then n = Hyp.Drive(bd)
			dw kw_cpeqvl, var_starttask_d, 1
			dw kw_goto_iffalse_n, if113_1
			dw p_hyp_drive_c, var_bd
			dw kw_vtov, var_hyp_drive_drive, var_starttask_n
if113_1:

			; Main.bas 1036: a = w : h = 0 : com = 0
			dw kw_strcpy, var_a, var_starttask_w
			dw kw_ztov, var_starttask_h
			dw kw_ztov, var_starttask_com

			; Main.bas 1037: If InStr(a, ".") = 0 Then
			dw kw_strinstr, lit_1, var_a, str46, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if114_1

			; Main.bas 1038: dn = a + ".CYB"
			dw kw_strcpy, var_dn, var_a
			dw kw_strcat, var_dn, str47

			; Main.bas 1039: h = HOpen()
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h

			; Main.bas 1040: If h Then a = dn Else com = -1
			dw kw_goto_ifzero_n, var_starttask_h, if115_1
			dw kw_strcpy, var_a, var_dn
			dw if114_e_go
if115_1:
			dw kw_ltov, -1, var_starttask_com
if115_e:

			; Main.bas 1041: ElseIf Right$(a, 4) = ".COM" Then
			dw if114_e_go
if114_1:
			dw kw_strright, stmp0, var_a, lit_4
			dw kw_strcmpeq, stmp0, str48
			dw kw_goto_iffalse_n, if114_2

			; Main.bas 1042: com = -1
			dw kw_ltov, -1, var_starttask_com

			; Main.bas 1043: Else
			dw if114_e_go
if114_2:

			; Main.bas 1044: dn = a
			dw kw_strcpy, var_dn, var_a

			; Main.bas 1045: h = HOpen()
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h

			; Main.bas 1046: End If
if114_e:

			; Main.bas 1047: rest = &HEE00                                ' #0100 to the stub (#EF00)
			dw kw_ltov, -4608, var_starttask_rest

			; Main.bas 1048: If com Then dn = a : h = HOpen()             ' (a .COM: UniDOS, a RAM disc read it to its end)
			dw kw_goto_ifzero_n, var_starttask_com, if116_1
			dw kw_strcpy, var_dn, var_a
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h
if116_1:

			; Main.bas 1049: If h Then Exit Do
			dw kw_goto_ifzero_n, var_starttask_h, if117_1
			dw do109_e_go
if117_1:

			; Main.bas 1053: If d = 1 Or (d = 0 And dv(t) = bd) Then Exit Do   ' not on Z nor the slot's drive: the boot drive
			dw kw_cpeqvl, var_starttask_d, 1
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_starttask_d, 0
			dw kw_ftov, tmp1
			dw kw_aget, arr_dv, var_starttask_t, tmp2
			dw kw_cpeqvv, tmp2, var_bd
			dw kw_ftov, tmp2
			dw kw_andvv, tmp1, tmp2, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if118_1
			dw do109_e_go
if118_1:

			; Main.bas 1054: d = d + 1
			dw kw_inc, var_starttask_d

			; Main.bas 1056: Loop
			dw do109_t_go
do109_e:

			; Main.bas 1057: If h = 0 Then
			dw kw_cpeqvl, var_starttask_h, 0
			dw kw_goto_iffalse_n, if119_1

			; Main.bas 1058: a = w
			dw kw_strcpy, var_a, var_starttask_w

			; Main.bas 1061: OwnDrive t
			dw p_owndrive_c, var_starttask_t

			; Main.bas 1063: NotFound t
			dw p_notfound_c, var_starttask_t

			; Main.bas 1064: Exit Sub
			dw p_starttask_r

			; Main.bas 1065: End If
if119_1:

			; Main.bas 1066: If st(s) = 0 Then OpenSlot s
			dw kw_aget, arr_st, var_starttask_s, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if120_1
			dw p_openslot_c, var_starttask_s
if120_1:

			; Main.bas 1067: If s <> t Then PutLn s, "RUN " + a
			dw kw_cpnevv, var_starttask_s, var_starttask_t
			dw kw_goto_iffalse_n, if121_1
			dw kw_strcpy, stmp1, str49
			dw kw_strcat, stmp1, var_a
			dw p_putln_c, var_starttask_s, stmp1
if121_1:

			; Main.bas 1068: Install s
			dw p_install_c, var_starttask_s

			; Main.bas 1069: n = Hyp.FileCall(103, rest, s, sg(s), &H100, 0, VarPtr(rb))  ' at #0100, rest bytes at most
			dw kw_aget, arr_sg, var_starttask_s, tmp3
			dw p_hyp_filecall_c, lit_103, var_starttask_rest, var_starttask_s, tmp3, lit_256, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_starttask_n

			; Main.bas 1070: HClose
			dw p_hclose_c

			; Main.bas 1073: If d <> 0 Then OwnDrive t                      ' (loaded from Z or A: the slot's drive again)
			dw kw_cpnevl, var_starttask_d, 0
			dw kw_goto_iffalse_n, if122_1
			dw p_owndrive_c, var_starttask_t
if122_1:

			; Main.bas 1078: Memory.WriteWord Far(s, &HF2FC), Hyp.Info(4)
			dw p_far_c, var_starttask_s, lit_m3332
			dw fn_hyp_info, lit_4, var_hyp_info_info
			dw fn_memory_writeword, var_far_far, var_hyp_info_info

			; Main.bas 1079: Memory.WriteWord Far(s, &HF2FE), 0
			dw p_far_c, var_starttask_s, lit_m3330
			dw fn_memory_writeword, var_far_far, lit_0

			; Main.bas 1080: Memory.WriteWord Far(s, &HFFFE), &HF2FC
			dw p_far_c, var_starttask_s, lit_m2
			dw fn_memory_writeword, var_far_far, lit_m3332

			; Main.bas 1082: If b = "" Then
			dw kw_strcmpeq, var_b, str2
			dw kw_goto_iffalse_n, if123_1

			; Main.bas 1083: Memory.WriteByte Far(s, &H80), 0
			dw p_far_c, var_starttask_s, lit_128
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 1084: Else
			dw if123_e_go
if123_1:

			; Main.bas 1085: b = " " + b
			dw kw_strcpy, stmp0, str22
			dw kw_strcat, stmp0, var_b
			dw kw_strcpy, var_b, stmp0

			; Main.bas 1086: Memory.Copy NearP(VarPtr(b)), Far(s, &H81), Len(b)
			dw p_nearp_c, vp_var_b
			dw p_far_c, var_starttask_s, lit_129
			dw kw_strlen, var_b, tmp2
			dw fn_memory_copy, var_nearp_nearp, var_far_far, tmp2, var_memory_copy_copy

			; Main.bas 1087: Memory.WriteByte Far(s, &H80), Len(b)
			dw p_far_c, var_starttask_s, lit_128
			dw kw_strlen, var_b, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 1088: Memory.WriteByte Far(s, &H81 + Len(b)), 0
			dw kw_strlen, var_b, tmp2
			dw kw_addl, tmp2, 129, tmp1
			dw p_far_c, var_starttask_s, tmp1
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 1089: End If
if123_e:

			; Main.bas 1090: Memory.WriteByte Far(s, NMLEN), Len(a)
			dw p_far_c, var_starttask_s, lit_m2344
			dw kw_strlen, var_a, tmp1
			dw fn_memory_writebyte, var_far_far, tmp1

			; Main.bas 1091: Memory.Copy NearP(VarPtr(a)), Far(s, NMBUF), Len(a)
			dw p_nearp_c, vp_var_a
			dw p_far_c, var_starttask_s, lit_m2343
			dw kw_strlen, var_a, tmp2
			dw fn_memory_copy, var_nearp_nearp, var_far_far, tmp2, var_memory_copy_copy

			; Main.bas 1092: kq(s) = 0
			dw kw_asetl, arr_kq, var_starttask_s, 0

			; Main.bas 1093: Memory.WriteByte Far(s, &HF685), 0             ' no escape sequence rest half done
			dw p_far_c, var_starttask_s, lit_m2427
			dw fn_memory_writebyte, var_far_far, lit_0

			; Main.bas 1094: wk(s) = -1
			dw kw_asetl, arr_wk, var_starttask_s, -1

			; Main.bas 1095: dm(s) = &H80                                   ' CP/M's record buffer to start with
			dw kw_asetl, arr_dm, var_starttask_s, 128

			; Main.bas 1096: st(s) = 2
			dw kw_asetl, arr_st, var_starttask_s, 2

			; Main.bas 1097: If s <> t Then PutLn t, a + " runs in slot" + Str$(s)
			dw kw_cpnevv, var_starttask_s, var_starttask_t
			dw kw_goto_iffalse_n, if124_1
			dw kw_strcpy, stmp1, var_a
			dw kw_strcat, stmp1, str50
			dw kw_strstr, stmp2, var_starttask_s
			dw kw_strcat, stmp1, stmp2
			dw p_putln_c, var_starttask_t, stmp1
if124_1:
			dw p_starttask_r

ntc_rg40_e:
			IF ($ < 32768) && (ntc_rg41_e - ntc_rg41 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg41:
; ============================================================
; sub notfound (normal mode)
; ============================================================

p_notfound:

			; Main.bas 1101: If bare Then PutLn t, "? " + a + " (HELP)" Else PutLn t, a + ": not found"
			dw kw_goto_ifzero_n, var_bare, if125_1
			dw kw_strcpy, stmp1, str51
			dw kw_strcat, stmp1, var_a
			dw kw_strcat, stmp1, str52
			dw p_putln_c, var_notfound_t, stmp1
			dw if125_e_go
if125_1:
			dw kw_strcpy, stmp1, var_a
			dw kw_strcat, stmp1, str53
			dw p_putln_c, var_notfound_t, stmp1
if125_e:
			dw p_notfound_r

ntc_rg41_e:
			IF ($ < 32768) && (ntc_rg42_e - ntc_rg42 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg42:
; ============================================================
; sub owndrive (normal mode)
; ============================================================

p_owndrive:

			; Main.bas 1108: Dim r As Integer

			; Main.bas 1109: If dv(t) = 0 Then dv(t) = bd
			dw kw_aget, arr_dv, var_owndrive_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if126_1
			dw kw_aset, arr_dv, var_owndrive_t, var_bd
if126_1:

			; Main.bas 1110: r = Hyp.Drive(dv(t))
			dw kw_aget, arr_dv, var_owndrive_t, tmp0
			dw p_hyp_drive_c, tmp0
			dw kw_vtov, var_hyp_drive_drive, var_owndrive_r
			dw p_owndrive_r

ntc_rg42_e:
			IF ($ < 32768) && (ntc_rg43_e - ntc_rg43 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg43:
; ============================================================
; sub endtask (normal mode)
; ============================================================

p_endtask:

			; Main.bas 1115: Dim c As Integer

			; Main.bas 1116: FilesShut t
			dw p_filesshut_c, var_endtask_t

			; Main.bas 1119: StoreFree t
			dw p_storefree_c, var_endtask_t

			; Main.bas 1121: st(t) = 1
			dw kw_asetl, arr_st, var_endtask_t, 1

			; Main.bas 1122: runs = runs + 1
			dw kw_inc, var_runs

			; Main.bas 1123: PutLn t, ""
			dw p_putln_c, var_endtask_t, str2

			; Main.bas 1124: GetNm t
			dw p_getnm_c, var_endtask_t

			; Main.bas 1125: PutLn t, "[" + en + " ended]"
			dw kw_strcpy, stmp1, str12
			dw kw_strcat, stmp1, var_en
			dw kw_strcat, stmp1, str54
			dw p_putln_c, var_endtask_t, stmp1

			; Main.bas 1126: If wt <> t Then Prompt t                       ' (WAIT: the prompt when nothing runs)
			dw kw_cpnevv, var_wt, var_endtask_t
			dw kw_goto_iffalse_n, if127_1
			dw p_prompt_c, var_endtask_t
if127_1:

			; Main.bas 1127: c = kq(t) : kq(t) = 0
			dw kw_aget, arr_kq, var_endtask_t, var_endtask_c
			dw kw_asetl, arr_kq, var_endtask_t, 0

			; Main.bas 1128: If c <> 0 And t = front Then pk = c    ' a key typed for it after its last look: the command line's
			dw kw_cpnevl, var_endtask_c, 0
			dw kw_ftov, tmp0
			dw kw_cpeqvv, var_endtask_t, var_front
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if128_1
			dw kw_vtov, var_endtask_c, var_pk
if128_1:
			dw p_endtask_r

ntc_rg43_e:
			IF ($ < 32768) && (ntc_rg44_e - ntc_rg44 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg44:
; ============================================================
; sub usedriver (normal mode)
; ============================================================

p_hyp_usedriver:

			; Hyp.cls 57: dxb = b
			dw kw_vtov, var_hyp_usedriver_b, var_hyp_dxb

			; Hyp.cls 58: #asm
			dw asm_1_58_n
			dw p_hyp_usedriver_r

ntc_rg44_e:
			IF ($ < 32768) && (ntc_rg45_e - ntc_rg45 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg45:
; ============================================================
; function claimpage (normal mode)
; ============================================================

p_hyp_claimpage:

			; Hyp.cls 68: #asm
			dw asm_1_68_n
			dw p_hyp_claimpage_r

ntc_rg45_e:
			IF ($ < 32768) && (ntc_rg46_e - ntc_rg46 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg46:
; ============================================================
; sub con (normal mode)
; ============================================================

p_hyp_con:

			; Hyp.cls 279: #asm
			dw asm_1_279_n
			dw p_hyp_con_r

ntc_rg46_e:
			IF ($ < 32768) && (ntc_rg47_e - ntc_rg47 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg47:
; ============================================================
; sub say (normal mode)
; ============================================================

p_hyp_say:

			; Hyp.cls 1073: #asm
			dw asm_1_1073_n
			dw p_hyp_say_r

ntc_rg47_e:
			IF ($ < 32768) && (ntc_rg48_e - ntc_rg48 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg48:
; ============================================================
; function scr (normal mode)
; ============================================================

p_hyp_scr:

			; Hyp.cls 1167: #asm
			dw asm_1_1167_n
			dw p_hyp_scr_r

ntc_rg48_e:
			IF ($ < 32768) && (ntc_rg49_e - ntc_rg49 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg49:
; ============================================================
; sub keyrep (normal mode)
; ============================================================

p_hyp_keyrep:

			; Hyp.cls 1267: #asm
			dw asm_1_1267_n
			dw p_hyp_keyrep_r

ntc_rg49_e:
			IF ($ < 32768) && (ntc_rg50_e - ntc_rg50 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg50:
; ============================================================
; sub show (normal mode)
; ============================================================

p_hyp_show:

			; Hyp.cls 1307: Con pg, 0, -1, 1
			dw p_hyp_con_c, var_hyp_show_pg, lit_0, lit_m1, lit_1
			dw p_hyp_show_r

ntc_rg50_e:
			IF ($ < 32768) && (ntc_rg51_e - ntc_rg51 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg51:
; ============================================================
; sub reply (normal mode)
; ============================================================

p_hyp_reply:

			; Hyp.cls 1313: ra = a : rhl = hl
			dw kw_vtov, var_hyp_reply_a, var_hyp_ra
			dw kw_vtov, var_hyp_reply_hl, var_hyp_rhl
			dw p_hyp_reply_r

ntc_rg51_e:
			IF ($ < 32768) && (ntc_rg52_e - ntc_rg52 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg52:
; ============================================================
; function fn (normal mode)
; ============================================================

p_hyp_fn:

			; Hyp.cls 1317: Fn = rfn And 255
			dw kw_andvl, var_hyp_rfn, 255, var_hyp_fn_fn
			dw p_hyp_fn_r

ntc_rg52_e:
			IF ($ < 32768) && (ntc_rg53_e - ntc_rg53 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg53:
; ============================================================
; function arg (normal mode)
; ============================================================

p_hyp_arg:

			; Hyp.cls 1321: Arg = rde
			dw kw_vtov, var_hyp_rde, var_hyp_arg_arg
			dw p_hyp_arg_r

ntc_rg53_e:
			IF ($ < 32768) && (ntc_rg54_e - ntc_rg54 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg54:
; ============================================================
; function count (normal mode)
; ============================================================

p_hyp_count:

			; Hyp.cls 1326: Count = rcnt
			dw kw_vtov, var_hyp_rcnt, var_hyp_count_count
			dw p_hyp_count_r

ntc_rg54_e:
			IF ($ < 32768) && (ntc_rg55_e - ntc_rg55 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg55:
; ============================================================
; function run (normal mode)
; ============================================================

p_hyp_run:

			; Hyp.cls 1331: #asm
			dw asm_1_1331_n
			dw p_hyp_run_r

ntc_rg55_e:
			IF ($ < 32768) && (ntc_rg56_e - ntc_rg56 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg56:
; ============================================================
; sub vdu (normal mode)
; ============================================================

p_hyp_vdu:

			; Hyp.cls 2004: #asm
			dw asm_1_2004_n
			dw p_hyp_vdu_r

ntc_rg56_e:
			IF ($ < 32768) && (ntc_rg57_e - ntc_rg57 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg57:
; ============================================================
; function filecall (normal mode)
; ============================================================

p_hyp_filecall:

			; Hyp.cls 2036: #asm
			dw asm_1_2036_n
			dw p_hyp_filecall_r

ntc_rg57_e:
			IF ($ < 32768) && (ntc_rg58_e - ntc_rg58 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg58:
; ============================================================
; sub fileshut (normal mode)
; ============================================================

p_hyp_fileshut:

			; Hyp.cls 3529: #asm
			dw asm_1_3529_n
			dw p_hyp_fileshut_r

ntc_rg58_e:
			IF ($ < 32768) && (ntc_rg59_e - ntc_rg59 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg59:
; ============================================================
; sub svcvars (normal mode)
; ============================================================

p_hyp_svcvars:

			; Hyp.cls 3582: svst = vst : svsg = vsg : svns = vns : svfr = vfr : svdp = vdp
			dw kw_vtov, var_hyp_svcvars_vst, var_hyp_svst
			dw kw_vtov, var_hyp_svcvars_vsg, var_hyp_svsg
			dw kw_vtov, var_hyp_svcvars_vns, var_hyp_svns
			dw kw_vtov, var_hyp_svcvars_vfr, var_hyp_svfr
			dw kw_vtov, var_hyp_svcvars_vdp, var_hyp_svdp
			dw p_hyp_svcvars_r

ntc_rg59_e:
			IF ($ < 32768) && (ntc_rg60_e - ntc_rg60 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg60:
; ============================================================
; function svc (normal mode)
; ============================================================

p_hyp_svc:

			; Hyp.cls 3589: #asm
			dw asm_1_3589_n
			dw p_hyp_svc_r

ntc_rg60_e:
			IF ($ < 32768) && (ntc_rg61_e - ntc_rg61 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg61:
; ============================================================
; function drive (normal mode)
; ============================================================

p_hyp_drive:

			; Hyp.cls 4369: #asm
			dw asm_1_4369_n
			dw p_hyp_drive_r

ntc_rg61_e:
			IF ($ < 32768) && (ntc_rg62_e - ntc_rg62 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg62:
; ============================================================
; sub slots (normal mode)
; ============================================================

p_hot_slots:

			; Hot.cls 15: ns = n
			dw kw_vtov, var_hot_slots_n, var_hot_ns
			dw p_hot_slots_r

ntc_rg62_e:
			IF ($ < 32768) && (ntc_rg63_e - ntc_rg63 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg63:
; ============================================================
; sub tick (normal mode)
; ============================================================

p_hot_tick:

			; Hot.cls 19: Dim k As Integer

			; Hot.cls 20: ctl = Keys.Down(Keys.KeyControl)
			dw fn_keys_down, lit_23, var_hot_ctl

			; Hot.cls 21: If ctl Then
			dw kw_goto_ifzero_n, var_hot_ctl, if129_1

			; Hot.cls 22: If Keys.Down(64) Then k = 1
			dw fn_keys_down, lit_64, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if130_1
			dw kw_ltov, 1, var_hot_tick_k
if130_1:

			; Hot.cls 23: If Keys.Down(65) Then k = 2
			dw fn_keys_down, lit_65, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if131_1
			dw kw_ltov, 2, var_hot_tick_k
if131_1:

			; Hot.cls 24: If Keys.Down(57) Then k = 3
			dw fn_keys_down, lit_57, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if132_1
			dw kw_ltov, 3, var_hot_tick_k
if132_1:

			; Hot.cls 25: If Keys.Down(56) Then k = 4
			dw fn_keys_down, lit_56, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if133_1
			dw kw_ltov, 4, var_hot_tick_k
if133_1:

			; Hot.cls 26: If Keys.Down(49) Then k = 5
			dw fn_keys_down, lit_49, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if134_1
			dw kw_ltov, 5, var_hot_tick_k
if134_1:

			; Hot.cls 27: If Keys.Down(48) Then k = 6
			dw fn_keys_down, lit_48, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if135_1
			dw kw_ltov, 6, var_hot_tick_k
if135_1:

			; Hot.cls 28: If Keys.Down(41) Then k = 7
			dw fn_keys_down, lit_41, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if136_1
			dw kw_ltov, 7, var_hot_tick_k
if136_1:

			; Hot.cls 29: If Keys.Down(40) Then k = 8
			dw fn_keys_down, lit_40, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if137_1
			dw kw_ltov, 8, var_hot_tick_k
if137_1:

			; Hot.cls 30: If Keys.Down(33) Then k = 9
			dw fn_keys_down, lit_33, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if138_1
			dw kw_ltov, 9, var_hot_tick_k
if138_1:

			; Hot.cls 31: If Keys.Down(32) Then k = 10
			dw fn_keys_down, lit_32, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if139_1
			dw kw_ltov, 10, var_hot_tick_k
if139_1:

			; Hot.cls 32: If Keys.Down(Keys.KeyEsc) Then k = TOPKEY
			dw fn_keys_down, lit_66, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if140_1
			dw kw_ltov, 99, var_hot_tick_k
if140_1:

			; Hot.cls 33: End If
if129_1:

			; Hot.cls 34: If k <> 0 And k <> last Then
			dw kw_cpnevl, var_hot_tick_k, 0
			dw kw_ftov, tmp6
			dw kw_cpnevv, var_hot_tick_k, var_hot_last
			dw kw_ftov, tmp7
			dw kw_andvv, tmp6, tmp7, tmp6
			dw kw_goto_ifzero_n, tmp6, if141_1

			; Hot.cls 35: If k = TOPKEY Or ns <= 10 Then
			dw kw_cpeqvl, var_hot_tick_k, 99
			dw kw_ftov, tmp6
			dw kw_scplevl, var_hot_ns, 10
			dw kw_ftov, tmp7
			dw kw_orvv, tmp6, tmp7, tmp6
			dw kw_goto_ifzero_n, tmp6, if142_1

			; Hot.cls 36: If one <> 0 Then one = 0
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if143_1
			dw kw_ztov, var_hot_one
if143_1:

			; Hot.cls 37: pend = k                          ' at once (no double taps to wait for)
			dw kw_vtov, var_hot_tick_k, var_hot_pend

			; Hot.cls 38: ElseIf one = k Then
			dw if142_e_go
if142_1:
			dw kw_cpeqvv, var_hot_one, var_hot_tick_k
			dw kw_goto_iffalse_n, if142_2

			; Hot.cls 39: one = 0
			dw kw_ztov, var_hot_one

			; Hot.cls 40: If k + 10 <= ns Then pend = k + 10 Else pend = k  ' the second press: slot 11-20
			dw kw_addl, var_hot_tick_k, 10, tmp6
			dw kw_scplevv, tmp6, var_hot_ns
			dw kw_goto_iffalse_n, if144_1
			dw kw_addl, var_hot_tick_k, 10, var_hot_pend
			dw if142_e_go
if144_1:
			dw kw_vtov, var_hot_tick_k, var_hot_pend
if144_e:

			; Hot.cls 41: Else
			dw if142_e_go
if142_2:

			; Hot.cls 42: If one <> 0 Then pend = one       ' another number: the waiting one counts now
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if145_1
			dw kw_vtov, var_hot_one, var_hot_pend
if145_1:

			; Hot.cls 43: one = k : age = 0
			dw kw_vtov, var_hot_tick_k, var_hot_one
			dw kw_ztov, var_hot_age

			; Hot.cls 44: End If
if142_e:

			; Hot.cls 45: End If
if141_1:

			; Hot.cls 46: If one <> 0 Then
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if146_1

			; Hot.cls 47: age = age + 1
			dw kw_inc, var_hot_age

			; Hot.cls 48: If age > DOUBLE Or ctl = 0 Then pend = one : one = 0    ' no second press (or Control let go)
			dw kw_scpgtvl, var_hot_age, 15
			dw kw_ftov, tmp6
			dw kw_cpeqvl, var_hot_ctl, 0
			dw kw_ftov, tmp7
			dw kw_orvv, tmp6, tmp7, tmp6
			dw kw_goto_ifzero_n, tmp6, if147_1
			dw kw_vtov, var_hot_one, var_hot_pend
			dw kw_ztov, var_hot_one
if147_1:

			; Hot.cls 49: End If
if146_1:

			; Hot.cls 50: last = k
			dw kw_vtov, var_hot_tick_k, var_hot_last
			dw p_hot_tick_r

ntc_rg63_e:
			IF ($ < 32768) && (ntc_rg64_e - ntc_rg64 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg64:
; ============================================================
; function take (normal mode)
; ============================================================

p_hot_take:

			; Hot.cls 54: Take = pend
			dw kw_vtov, var_hot_pend, var_hot_take_take

			; Hot.cls 55: pend = 0
			dw kw_ztov, var_hot_pend
			dw p_hot_take_r

ntc_rg64_e:
			IF ($ < 32768) && (ntc_rg65_e - ntc_rg65 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg65:
; ============================================================
; function control (normal mode)
; ============================================================

p_hot_control:

			; Hot.cls 60: Control = ctl
			dw kw_vtov, var_hot_ctl, var_hot_control_control
			dw p_hot_control_r

ntc_rg65_e:
			IF ($ < 32768) && (ntc_rg66_e - ntc_rg66 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg66:
; ============================================================
; function held (normal mode)
; ============================================================

p_hot_held:

			; Hot.cls 66: Held = last
			dw kw_vtov, var_hot_last, var_hot_held_held
			dw p_hot_held_r

ntc_rg66_e:
			IF ($ < 32768) && (ntc_rg67_e - ntc_rg67 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg67:
; ============================================================
; function bankpage (normal mode)
; ============================================================

p_memory_bankpage:

			; Memory.cls 474: BankPage = 4 * bank - 2 + n
			dw kw_4x, var_memory_bankpage_bank, tmp2
			dw kw_addl, tmp2, -2, tmp2
			dw kw_add, tmp2, var_memory_bankpage_n, var_memory_bankpage_bankpage
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
if12_e_go:			ld sp, if12_e
			jp ntc_xn
if14_e_go:			ld sp, if14_e
			jp ntc_xn
for26_e_go:			ld sp, for26_e
			jp ntc_xn
do34_e_go:			ld sp, do34_e
			jp ntc_xn
do34_t_go:			ld sp, do34_t
			jp ntc_xn
sel42_e_go:			ld sp, sel42_e
			jp ntc_xn
if55_e_go:			ld sp, if55_e
			jp ntc_xn
ch71_e_go:			ld sp, ch71_e
			jp ntc_xn
if70_e_go:			ld sp, if70_e
			jp ntc_xn
ch75_e_go:			ld sp, ch75_e
			jp ntc_xn
ch76_e_go:			ld sp, ch76_e
			jp ntc_xn
ch77_e_go:			ld sp, ch77_e
			jp ntc_xn
if82_e_go:			ld sp, if82_e
			jp ntc_xn
if84_e_go:			ld sp, if84_e
			jp ntc_xn
ch86_e_go:			ld sp, ch86_e
			jp ntc_xn
if87_e_go:			ld sp, if87_e
			jp ntc_xn
if89_e_go:			ld sp, if89_e
			jp ntc_xn
if93_e_go:			ld sp, if93_e
			jp ntc_xn
if97_e_go:			ld sp, if97_e
			jp ntc_xn
sel103_e_go:			ld sp, sel103_e
			jp ntc_xn
if114_e_go:			ld sp, if114_e
			jp ntc_xn
do109_e_go:			ld sp, do109_e
			jp ntc_xn
do109_t_go:			ld sp, do109_t
			jp ntc_xn
if123_e_go:			ld sp, if123_e
			jp ntc_xn
if125_e_go:			ld sp, if125_e
			jp ntc_xn
if142_e_go:			ld sp, if142_e
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
p_ramdisc_c:		; call ramdisc (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ramdisc_t), de
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_ramdisc_p), de
			ld hl, 0
			ld (var_ramdisc_ramdisc), hl
			ld hl, 0
			ld (var_ramdisc_g), hl
			ld hl, 0
			ld (var_ramdisc_o), hl
			ld hl, 0
			ld (var_ramdisc_f), hl
			ld (var_ramdisc_f+2), hl
			ld (p_ramdisc_rs), sp
			ld sp, p_ramdisc
			jp ntc_xn
p_ramdisc_r:		; end of ramdisc
			ld sp, (p_ramdisc_rs)
			jp ntc_xn
p_storesize_c:		; call storesize (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_storesize_t), de
			pop hl			; kb
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_storesize_kb), de
			ld hl, 0
			ld (var_storesize_storesize), hl
			ld hl, 0
			ld (var_storesize_n), hl
			ld hl, 0
			ld (var_storesize_j), hl
			ld hl, 0
			ld (var_storesize_g), hl
			ld (p_storesize_rs), sp
			ld sp, p_storesize
			jp ntc_xn
p_storesize_r:		; end of storesize
			ld sp, (p_storesize_rs)
			jp ntc_xn
p_probediscs_c:		; call probediscs (normal)
			ld hl, 0
			ld (var_probediscs_probediscs), hl
			ld hl, 0
			ld (var_probediscs_p), hl
			ld hl, 0
			ld (var_probediscs_su), hl
			ld hl, 0
			ld (var_probediscs_j), hl
			ld hl, 0
			ld (var_probediscs_a), hl
			ld hl, 0
			ld (var_probediscs_pg), hl
			ld hl, 0
			ld (var_probediscs_r), hl
			ld (p_probediscs_rs), sp
			ld sp, p_probediscs
			jp ntc_xn
p_probediscs_r:		; end of probediscs
			ld sp, (p_probediscs_rs)
			jp ntc_xn
p_storefree_c:		; call storefree (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_storefree_t), de
			ld hl, 0
			ld (var_storefree_r), hl
			ld (p_storefree_rs), sp
			ld sp, p_storefree
			jp ntc_xn
p_storefree_r:		; end of storefree
			ld sp, (p_storefree_rs)
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
			ld b, 82
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
			ld b, 82
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
			ld b, 82
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
p_owndrive_c:		; call owndrive (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_owndrive_t), de
			ld hl, 0
			ld (var_owndrive_r), hl
			ld (p_owndrive_rs), sp
			ld sp, p_owndrive
			jp ntc_xn
p_owndrive_r:		; end of owndrive
			ld sp, (p_owndrive_rs)
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
p_hyp_usedriver_c:		; call usedriver (normal)
			pop hl			; b
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_usedriver_b), de
			ld (p_hyp_usedriver_rs), sp
			ld sp, p_hyp_usedriver
			jp ntc_xn
p_hyp_usedriver_r:		; end of usedriver
			ld sp, (p_hyp_usedriver_rs)
			jp ntc_xn
p_hyp_claimpage_c:		; call claimpage (normal)
			pop hl			; page
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_claimpage_page), de
			ld hl, 0
			ld (var_hyp_claimpage_claimpage), hl
			ld (p_hyp_claimpage_rs), sp
			ld sp, p_hyp_claimpage
			jp ntc_xn
p_hyp_claimpage_r:		; end of claimpage
			ld sp, (p_hyp_claimpage_rs)
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
p_hyp_svcvars_c:		; call svcvars (normal)
			pop hl			; vst
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svcvars_vst), de
			pop hl			; vsg
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svcvars_vsg), de
			pop hl			; vns
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svcvars_vns), de
			pop hl			; vfr
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svcvars_vfr), de
			pop hl			; vdp
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svcvars_vdp), de
			ld (p_hyp_svcvars_rs), sp
			ld sp, p_hyp_svcvars
			jp ntc_xn
p_hyp_svcvars_r:		; end of svcvars
			ld sp, (p_hyp_svcvars_rs)
			jp ntc_xn
p_hyp_svc_c:		; call svc (normal)
			pop hl			; t
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svc_t), de
			pop hl			; p
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svc_p), de
			pop hl			; setting
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svc_setting), de
			pop hl			; buf
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_svc_buf), de
			ld hl, 0
			ld (var_hyp_svc_svc), hl
			ld (p_hyp_svc_rs), sp
			ld sp, p_hyp_svc
			jp ntc_xn
p_hyp_svc_r:		; end of svc
			ld sp, (p_hyp_svc_rs)
			jp ntc_xn
p_hyp_drive_c:		; call drive (normal)
			pop hl			; letter
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld (var_hyp_drive_letter), de
			ld hl, 0
			ld (var_hyp_drive_drive), hl
			ld (p_hyp_drive_rs), sp
			ld sp, p_hyp_drive
			jp ntc_xn
p_hyp_drive_r:		; end of drive
			ld sp, (p_hyp_drive_rs)
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
p_hot_held_c:		; call held (normal)
			ld hl, 0
			ld (var_hot_held_held), hl
			ld (p_hot_held_rs), sp
			ld sp, p_hot_held
			jp ntc_xn
p_hot_held_r:		; end of held
			ld sp, (p_hot_held_rs)
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

ntc_rg67_e:
			IF ($ < 32768) && (ntc_rg68_e - ntc_rg68 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg68:
; ============================================================
; Inline assembly (#asm ... #endasm)
; ============================================================

fn_hyp_usepage:		; sub usepage (asm keyword), Hyp.cls line 48
            ld hl, (ntc_rampt)		; Hyp.cls 49
            ld (var_hyp_hps), hl		; Hyp.cls 50
			ret			; end of #asm

asm_1_58_n:		; #asm, Hyp.cls line 58 (normal)
            ld hl, (ntc_rampt)		; Hyp.cls 59
            ld (var_hyp_drs), hl		; Hyp.cls 60
			ret			; end of #asm

asm_1_68_n:		; #asm, Hyp.cls line 68 (normal)
            ld hl, (var_hyp_claimpage_page)		; Hyp.cls 69
            ld a, h		; Hyp.cls 70
            or l		; Hyp.cls 71
            jr z, asm_1_68_n_cp_no		; Hyp.cls 72
            ld de, (mem_count)		; Hyp.cls 73
            ex de, hl		; Hyp.cls 74
            or a		; Hyp.cls 75
            sbc hl, de              ; page - count: carry means page > count [76]
            jr c, asm_1_68_n_cp_no		; Hyp.cls 77
            ld hl, (var_hyp_claimpage_page)         ; the RAT byte: (mem_ttype) + page - 1 [78]
            ld de, (mem_ttype)		; Hyp.cls 79
            add hl, de		; Hyp.cls 80
            dec hl		; Hyp.cls 81
            ld a, (hl)		; Hyp.cls 82
            cp "-"                  ; free? [83]
            jr nz, asm_1_68_n_cp_no		; Hyp.cls 84
            ld (hl), "U"            ; TypeUser [85]
            ld hl, (var_hyp_claimpage_page)		; Hyp.cls 86
            jr asm_1_68_n_cp_done		; Hyp.cls 87
asm_1_68_n_cp_no:		; Hyp.cls 88
            ld hl, 0		; Hyp.cls 89
asm_1_68_n_cp_done:		; Hyp.cls 90
            ld (var_hyp_claimpage_claimpage), hl		; Hyp.cls 91
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

asm_1_279_n:		; #asm, Hyp.cls line 279 (normal)
; CN_SB 1: the scrollback (Shift + Up / Down: 48 rows a slot, kept in a 16K page Main gives - #If
; SCROLLBACK in Main.bas, set the two together). Off for now: 526 bytes of main RAM (2026-10-16)
asm_1_279_n_CN_SB:      equ 0		; Hyp.cls 282
            ld (var_hyp_hsp), sp		; Hyp.cls 283
            ld sp, (ntc_csp)		; Hyp.cls 284
            ld bc, (var_hyp_con_pg)		; Hyp.cls 285
            out (c), c              ; the slot's page 3 at #4000: OBUF #7600, state #7682, page #7700 [286]
            IF asm_1_279_n_CN_SB		; Hyp.cls 287
            ld (asm_1_279_n_cn_pg), bc		; Hyp.cls 288
            ENDIF		; Hyp.cls 289
            xor a		; Hyp.cls 290
            ld (asm_1_279_n_cn_pv), a		; Hyp.cls 291
            ld a, (var_hyp_con_front)		; Hyp.cls 292
            ld (asm_1_279_n_cn_front), a		; Hyp.cls 293
            ld a, (#7687)           ; its columns and rows (MODE) [294]
            ld (asm_1_279_n_cn_c), a		; Hyp.cls 295
            ld a, (#7688)		; Hyp.cls 296
            ld (asm_1_279_n_cn_r), a		; Hyp.cls 297
            ld hl, (var_hyp_con_n)		; Hyp.cls 298
            bit 7, h		; Hyp.cls 299
            jp nz, asm_1_279_n_cn_neg		; Hyp.cls 300
            ld (asm_1_279_n_cn_left), hl		; Hyp.cls 301
            IF asm_1_279_n_CN_SB		; Hyp.cls 302
            ld a, (asm_1_279_n_cn_front)        ; in front and looking back (scrollback): the page again first [303]
            or a		; Hyp.cls 304
            jr z, asm_1_279_n_cn_live		; Hyp.cls 305
            ld a, (#7F26)		; Hyp.cls 306
            or a		; Hyp.cls 307
            jr z, asm_1_279_n_cn_live		; Hyp.cls 308
            xor a		; Hyp.cls 309
            ld (#7F26), a		; Hyp.cls 310
            call asm_1_279_n_cn_cls		; Hyp.cls 311
            call asm_1_279_n_cn_strip		; Hyp.cls 312
            call asm_1_279_n_cn_draw		; Hyp.cls 313
            ld hl, (asm_1_279_n_cn_left)		; Hyp.cls 314
asm_1_279_n_cn_live:		; Hyp.cls 315
            ENDIF		; Hyp.cls 316
            ld hl, (var_hyp_con_src)		; Hyp.cls 317
            ld a, h		; Hyp.cls 318
            or l		; Hyp.cls 319
            jr nz, asm_1_279_n_cn_src		; Hyp.cls 320
            ld hl, #7600            ; src 0: the characters the program collected (OBUF) [321]
asm_1_279_n_cn_src:		; Hyp.cls 322
            ld (asm_1_279_n_cn_ptr), hl		; Hyp.cls 323
asm_1_279_n_cn_lp:		; Hyp.cls 324
            ld hl, (asm_1_279_n_cn_left)		; Hyp.cls 325
            ld a, h		; Hyp.cls 326
            or l		; Hyp.cls 327
            jr z, asm_1_279_n_cn_done		; Hyp.cls 328
            dec hl		; Hyp.cls 329
            ld (asm_1_279_n_cn_left), hl		; Hyp.cls 330
            ld hl, (asm_1_279_n_cn_ptr)		; Hyp.cls 331
            ld a, (hl)		; Hyp.cls 332
            inc hl		; Hyp.cls 333
            ld (asm_1_279_n_cn_ptr), hl		; Hyp.cls 334
            call asm_1_279_n_cn_char		; Hyp.cls 335
            jr asm_1_279_n_cn_lp		; Hyp.cls 336
asm_1_279_n_cn_done:		; Hyp.cls 337
            ld bc, (ntc_rampt)      ; the window's page back [338]
            out (c), c		; Hyp.cls 339
            ld sp, (var_hyp_hsp)		; Hyp.cls 340
            jp asm_1_279_n_cn_end		; Hyp.cls 341

; n < 0: -1 the whole page to the screen (it was cleared: Show), not looking back any more; -2
; the scrollback (src: the key - #F4 Shift + Up a screen back, #F5 Shift + Down one on), drawn
asm_1_279_n_cn_neg:		; Hyp.cls 345
            IF asm_1_279_n_CN_SB		; Hyp.cls 346
            inc hl		; Hyp.cls 347
            ld a, h		; Hyp.cls 348
            or l		; Hyp.cls 349
            jr nz, asm_1_279_n_cn_view		; Hyp.cls 350
            ld (#7F26), a		; Hyp.cls 351
            ENDIF		; Hyp.cls 352
asm_1_279_n_cn_show:		; Hyp.cls 353
            call asm_1_279_n_cn_strip		; Hyp.cls 354
            call asm_1_279_n_cn_draw		; Hyp.cls 355
            jr asm_1_279_n_cn_done		; Hyp.cls 356
            IF asm_1_279_n_CN_SB		; Hyp.cls 357
asm_1_279_n_cn_view:		; Hyp.cls 358
            ld a, (#7F21)           ; (no history page: nothing) [359]
            or a		; Hyp.cls 360
            jr z, asm_1_279_n_cn_done		; Hyp.cls 361
            ld a, (asm_1_279_n_cn_r)		; Hyp.cls 362
            dec a		; Hyp.cls 363
            ld b, a                 ; a screen: its rows - 1 [364]
            ld a, (var_hyp_con_src)		; Hyp.cls 365
            cp #F4		; Hyp.cls 366
            ld a, (#7F26)		; Hyp.cls 367
            jr nz, asm_1_279_n_cn_vw_dn		; Hyp.cls 368
            add a, b		; Hyp.cls 369
            ld hl, #7F25		; Hyp.cls 370
            cp (hl)		; Hyp.cls 371
            jr c, asm_1_279_n_cn_vw_set		; Hyp.cls 372
            ld a, (hl)              ; (not past the oldest row kept) [373]
            jr asm_1_279_n_cn_vw_set		; Hyp.cls 374
asm_1_279_n_cn_vw_dn:		; Hyp.cls 375
            sub b		; Hyp.cls 376
            jr nc, asm_1_279_n_cn_vw_set		; Hyp.cls 377
            xor a		; Hyp.cls 378
asm_1_279_n_cn_vw_set:		; Hyp.cls 379
            ld hl, #7F26		; Hyp.cls 380
            cp (hl)		; Hyp.cls 381
            jr z, asm_1_279_n_cn_done		; Hyp.cls 382
            ld (hl), a		; Hyp.cls 383
            call asm_1_279_n_cn_cls		; Hyp.cls 384
            jr asm_1_279_n_cn_show		; Hyp.cls 385

            ENDIF		; Hyp.cls 387

; the screen's rows: the page's - or, looking back (#FF26 rows), the history's first, then the
; page's. Row e shows line count + e - back of history + page (count the rows kept, #FF25)
asm_1_279_n_cn_draw:		; Hyp.cls 391
            ld e, 0		; Hyp.cls 392
            IF asm_1_279_n_CN_SB		; Hyp.cls 393
asm_1_279_n_cn_dr_row:		; Hyp.cls 394
            push de		; Hyp.cls 395
            ld a, (#7F25)		; Hyp.cls 396
            add a, e		; Hyp.cls 397
            ld hl, #7F26		; Hyp.cls 398
            sub (hl)                ; the line: count + e - back [399]
            ld hl, #7F25		; Hyp.cls 400
            sub (hl)		; Hyp.cls 401
            jr c, asm_1_279_n_cn_dr_h		; Hyp.cls 402
            call asm_1_279_n_cn_rowa            ; HL = row (line - count) of the page [403]
            ld a, (asm_1_279_n_cn_c)		; Hyp.cls 404
            jr asm_1_279_n_cn_dr_go		; Hyp.cls 405
asm_1_279_n_cn_dr_h:		; Hyp.cls 406
            add a, (hl)		; Hyp.cls 407
            call asm_1_279_n_cn_hget            ; HL = the history's row (copied in), 80 characters at most [408]
            ld a, (asm_1_279_n_cn_c)		; Hyp.cls 409
            cp asm_1_279_n_HW		; Hyp.cls 410
            jr c, asm_1_279_n_cn_dr_go		; Hyp.cls 411
            ld a, asm_1_279_n_HW		; Hyp.cls 412
asm_1_279_n_cn_dr_go:		; Hyp.cls 413
            ld b, a		; Hyp.cls 414
            pop de		; Hyp.cls 415
            push de		; Hyp.cls 416
            ld d, 0		; Hyp.cls 417
asm_1_279_n_cn_dr_col:		; Hyp.cls 418
            ld a, (hl)		; Hyp.cls 419
            inc hl		; Hyp.cls 420
            cp 33		; Hyp.cls 421
            jr c, asm_1_279_n_cn_dr_sk		; Hyp.cls 422
            push hl		; Hyp.cls 423
            push de		; Hyp.cls 424
            push bc		; Hyp.cls 425
            call asm_1_279_n_cn_glyph		; Hyp.cls 426
            pop bc		; Hyp.cls 427
            pop de		; Hyp.cls 428
            pop hl		; Hyp.cls 429
asm_1_279_n_cn_dr_sk:		; Hyp.cls 430
            inc d		; Hyp.cls 431
            djnz asm_1_279_n_cn_dr_col		; Hyp.cls 432
            pop de		; Hyp.cls 433
            inc e		; Hyp.cls 434
            ld a, (asm_1_279_n_cn_r)		; Hyp.cls 435
            dec a		; Hyp.cls 436
            cp e		; Hyp.cls 437
            jr nc, asm_1_279_n_cn_dr_row		; Hyp.cls 438
            ret		; Hyp.cls 439
            ELSE		; Hyp.cls 440
asm_1_279_n_cn_sh_row:                          ; (no scrollback: the page's rows as they are) [441]
            push de		; Hyp.cls 442
            ld a, e		; Hyp.cls 443
            call asm_1_279_n_cn_rowa            ; HL = row e of the page [444]
            pop de		; Hyp.cls 445
            ld d, 0		; Hyp.cls 446
asm_1_279_n_cn_sh_col:		; Hyp.cls 447
            ld a, (hl)		; Hyp.cls 448
            inc hl		; Hyp.cls 449
            cp 33		; Hyp.cls 450
            jr c, asm_1_279_n_cn_sh_skip		; Hyp.cls 451
            push hl		; Hyp.cls 452
            push de		; Hyp.cls 453
            call asm_1_279_n_cn_glyph		; Hyp.cls 454
            pop de		; Hyp.cls 455
            pop hl		; Hyp.cls 456
asm_1_279_n_cn_sh_skip:		; Hyp.cls 457
            inc d		; Hyp.cls 458
            ld a, (asm_1_279_n_cn_c)		; Hyp.cls 459
            dec a		; Hyp.cls 460
            cp d		; Hyp.cls 461
            jr nc, asm_1_279_n_cn_sh_col		; Hyp.cls 462
            inc e		; Hyp.cls 463
            ld a, (asm_1_279_n_cn_r)		; Hyp.cls 464
            dec a		; Hyp.cls 465
            cp e		; Hyp.cls 466
            jr nc, asm_1_279_n_cn_sh_row		; Hyp.cls 467
            ret		; Hyp.cls 468
            ENDIF		; Hyp.cls 469

            IF asm_1_279_n_CN_SB		; Hyp.cls 471
; the scrollback: each row that scrolls off the top of the page - its first HW characters - goes
; to the slot's history: HROWS rows (a ring) in a 16K page of its own that Main gave it (#FF20:
; its RAM setting, 0 none; #FF22 where in it; #FF24 the next row written, #FF25 how many, #FF26
; how far back the screen looks). Copied 8 bytes at a time through the stack - only the window
; changes, so no main RAM for a buffer
asm_1_279_n_HW:         equ 80		; Hyp.cls 477
asm_1_279_n_HROWS:      equ 48		; Hyp.cls 478
asm_1_279_n_cn_hput:                            ; HL = the row going (the page) [479]
            ld a, (#7F21)		; Hyp.cls 480
            or a		; Hyp.cls 481
            ret z		; Hyp.cls 482
            ld (asm_1_279_n_cn_hs), hl		; Hyp.cls 483
            ld hl, (asm_1_279_n_cn_pg)		; Hyp.cls 484
            ld (asm_1_279_n_cn_h1), hl		; Hyp.cls 485
            ld hl, (#7F20)		; Hyp.cls 486
            ld (asm_1_279_n_cn_h2), hl		; Hyp.cls 487
            ld a, (#7F24)		; Hyp.cls 488
            call asm_1_279_n_cn_haddr		; Hyp.cls 489
            ld (asm_1_279_n_cn_hd), hl		; Hyp.cls 490
            ld hl, #7F24            ; the next row on, one more kept [491]
            ld a, (hl)		; Hyp.cls 492
            inc a		; Hyp.cls 493
            cp asm_1_279_n_HROWS		; Hyp.cls 494
            jr c, asm_1_279_n_cn_hp_h		; Hyp.cls 495
            xor a		; Hyp.cls 496
asm_1_279_n_cn_hp_h:		; Hyp.cls 497
            ld (hl), a		; Hyp.cls 498
            inc hl		; Hyp.cls 499
            ld a, (hl)		; Hyp.cls 500
            cp asm_1_279_n_HROWS		; Hyp.cls 501
            jr nc, asm_1_279_n_cn_hcp		; Hyp.cls 502
            inc (hl)		; Hyp.cls 503
; cn_hcp: HW bytes from cn_hs in RAM setting cn_h1 to cn_hd in cn_h2, then the slot's page back
asm_1_279_n_cn_hcp:		; Hyp.cls 505
            ld a, asm_1_279_n_HW / 8		; Hyp.cls 506
asm_1_279_n_cn_hc_lp:		; Hyp.cls 507
            ld (asm_1_279_n_cn_hn), a		; Hyp.cls 508
            ld bc, (asm_1_279_n_cn_h1)		; Hyp.cls 509
            out (c), c		; Hyp.cls 510
            ld hl, (asm_1_279_n_cn_hs)		; Hyp.cls 511
            ld b, 4		; Hyp.cls 512
asm_1_279_n_cn_hc_in:		; Hyp.cls 513
            ld e, (hl)		; Hyp.cls 514
            inc hl		; Hyp.cls 515
            ld d, (hl)		; Hyp.cls 516
            inc hl		; Hyp.cls 517
            push de		; Hyp.cls 518
            djnz asm_1_279_n_cn_hc_in		; Hyp.cls 519
            ld (asm_1_279_n_cn_hs), hl		; Hyp.cls 520
            ld bc, (asm_1_279_n_cn_h2)		; Hyp.cls 521
            out (c), c		; Hyp.cls 522
            ld hl, (asm_1_279_n_cn_hd)		; Hyp.cls 523
            ld de, 8		; Hyp.cls 524
            add hl, de		; Hyp.cls 525
            ld (asm_1_279_n_cn_hd), hl		; Hyp.cls 526
            ld b, 4		; Hyp.cls 527
asm_1_279_n_cn_hc_out:		; Hyp.cls 528
            pop de		; Hyp.cls 529
            dec hl		; Hyp.cls 530
            ld (hl), d		; Hyp.cls 531
            dec hl		; Hyp.cls 532
            ld (hl), e		; Hyp.cls 533
            djnz asm_1_279_n_cn_hc_out		; Hyp.cls 534
            ld a, (asm_1_279_n_cn_hn)		; Hyp.cls 535
            dec a		; Hyp.cls 536
            jr nz, asm_1_279_n_cn_hc_lp		; Hyp.cls 537
            ld bc, (asm_1_279_n_cn_pg)		; Hyp.cls 538
            out (c), c		; Hyp.cls 539
            ret		; Hyp.cls 540
asm_1_279_n_cn_hget:                            ; A = a line of the history (0 the oldest kept): copied to [541]
            ld hl, #7F24            ; #FF30 in the slot's page (HL) [542]
            add a, (hl)		; Hyp.cls 543
            inc hl		; Hyp.cls 544
            sub (hl)		; Hyp.cls 545
            jr nc, asm_1_279_n_cn_hg_r		; Hyp.cls 546
            add a, asm_1_279_n_HROWS		; Hyp.cls 547
asm_1_279_n_cn_hg_r:		; Hyp.cls 548
            call asm_1_279_n_cn_haddr		; Hyp.cls 549
            ld (asm_1_279_n_cn_hs), hl		; Hyp.cls 550
            ld hl, (#7F20)		; Hyp.cls 551
            ld (asm_1_279_n_cn_h1), hl		; Hyp.cls 552
            ld hl, (asm_1_279_n_cn_pg)		; Hyp.cls 553
            ld (asm_1_279_n_cn_h2), hl		; Hyp.cls 554
            ld hl, #7F30		; Hyp.cls 555
            ld (asm_1_279_n_cn_hd), hl		; Hyp.cls 556
            call asm_1_279_n_cn_hcp		; Hyp.cls 557
            ld hl, #7F30		; Hyp.cls 558
            ret		; Hyp.cls 559
asm_1_279_n_cn_haddr:                           ; A = a history row: HL = its address in the history page [560]
            ld e, a		; Hyp.cls 561
            ld a, asm_1_279_n_HW		; Hyp.cls 562
            call asm_1_279_n_cn_mul		; Hyp.cls 563
            ld de, (#7F22)		; Hyp.cls 564
            add hl, de		; Hyp.cls 565
            ret		; Hyp.cls 566
; cn_cls: the screen cleared (written only: the Library: ROM build's keyword ROM may be over it)
asm_1_279_n_cn_cls:		; Hyp.cls 568
            ld hl, #C000		; Hyp.cls 569
            ld bc, #4000		; Hyp.cls 570
asm_1_279_n_cn_cl_lp:		; Hyp.cls 571
            ld (hl), 0		; Hyp.cls 572
            inc hl		; Hyp.cls 573
            dec bc		; Hyp.cls 574
            ld a, b		; Hyp.cls 575
            or c		; Hyp.cls 576
            jr nz, asm_1_279_n_cn_cl_lp		; Hyp.cls 577
            ret		; Hyp.cls 578
            ENDIF		; Hyp.cls 579

; cn_char: A = one character
asm_1_279_n_cn_char:		; Hyp.cls 582
            ld b, a		; Hyp.cls 583
            ld a, (#7685)           ; in an escape sequence? [584]
            or a		; Hyp.cls 585
            jr nz, asm_1_279_n_cn_esc0		; Hyp.cls 586
            ld a, b		; Hyp.cls 587
            cp 32		; Hyp.cls 588
            jp nc, asm_1_279_n_cn_print		; Hyp.cls 589
            ld hl, asm_1_279_n_cn_pv            ; a control code: the cursor may move (the pointers redone) [590]
            ld (hl), 0		; Hyp.cls 591
            cp 27		; Hyp.cls 592
            jr z, asm_1_279_n_cn_setesc		; Hyp.cls 593
            cp 13		; Hyp.cls 594
            jr z, asm_1_279_n_cn_cr		; Hyp.cls 595
            cp 10		; Hyp.cls 596
            jp z, asm_1_279_n_cn_nl		; Hyp.cls 597
            cp 9		; Hyp.cls 598
            jr z, asm_1_279_n_cn_tab		; Hyp.cls 599
            cp 8		; Hyp.cls 600
            ret nz                  ; other control codes: nothing [601]
            ld a, (#7682)           ; BS: back one (not past the start of the row) [602]
            or a		; Hyp.cls 603
            ret z		; Hyp.cls 604
            dec a		; Hyp.cls 605
            ld (#7682), a		; Hyp.cls 606
            ret		; Hyp.cls 607
asm_1_279_n_cn_tab:                             ; TAB: spaces to the next column of 8 [608]
            ld b, ' '		; Hyp.cls 609
            call asm_1_279_n_cn_print		; Hyp.cls 610
            ld a, (#7682)		; Hyp.cls 611
            and 7		; Hyp.cls 612
            jr nz, asm_1_279_n_cn_tab		; Hyp.cls 613
            ret		; Hyp.cls 614
asm_1_279_n_cn_setesc:		; Hyp.cls 615
            ld a, 1		; Hyp.cls 616
            ld (#7685), a		; Hyp.cls 617
            ret		; Hyp.cls 618
asm_1_279_n_cn_cr:		; Hyp.cls 619
            xor a		; Hyp.cls 620
            ld (#7682), a		; Hyp.cls 621
            ret		; Hyp.cls 622
asm_1_279_n_cn_esc0:		; Hyp.cls 623
            ld hl, asm_1_279_n_cn_pv		; Hyp.cls 624
            ld (hl), 0		; Hyp.cls 625
asm_1_279_n_cn_esc:		; Hyp.cls 626
            cp 1		; Hyp.cls 627
            jr nz, asm_1_279_n_cn_esc2		; Hyp.cls 628
            xor a                   ; ESC x [629]
            ld (#7685), a		; Hyp.cls 630
            ld a, b		; Hyp.cls 631
            cp 'E'		; Hyp.cls 632
            jp z, asm_1_279_n_cn_clear		; Hyp.cls 633
            cp 'H'		; Hyp.cls 634
            jr z, asm_1_279_n_cn_home		; Hyp.cls 635
            cp 'I'		; Hyp.cls 636
            jp z, asm_1_279_n_cn_rev		; Hyp.cls 637
            cp 'Y'		; Hyp.cls 638
            ret nz		; Hyp.cls 639
            ld a, 2		; Hyp.cls 640
            ld (#7685), a		; Hyp.cls 641
            ret		; Hyp.cls 642
asm_1_279_n_cn_home:		; Hyp.cls 643
            xor a		; Hyp.cls 644
            ld (#7682), a		; Hyp.cls 645
            ld (#7683), a		; Hyp.cls 646
            ret		; Hyp.cls 647
asm_1_279_n_cn_esc2:		; Hyp.cls 648
            cp 2		; Hyp.cls 649
            jr nz, asm_1_279_n_cn_esc3		; Hyp.cls 650
            ld a, b                 ; ESC Y row [651]
            sub 32		; Hyp.cls 652
            ld (#7686), a		; Hyp.cls 653
            ld a, 3		; Hyp.cls 654
            ld (#7685), a		; Hyp.cls 655
            ret		; Hyp.cls 656
asm_1_279_n_cn_esc3:		; Hyp.cls 657
            xor a                   ; ESC Y row col [658]
            ld (#7685), a		; Hyp.cls 659
            ld a, b		; Hyp.cls 660
            sub 32		; Hyp.cls 661
            ld hl, asm_1_279_n_cn_c		; Hyp.cls 662
            cp (hl)		; Hyp.cls 663
            jr c, asm_1_279_n_cn_e3_col		; Hyp.cls 664
            xor a		; Hyp.cls 665
asm_1_279_n_cn_e3_col:		; Hyp.cls 666
            ld (#7682), a		; Hyp.cls 667
            ld a, (#7686)		; Hyp.cls 668
            ld hl, asm_1_279_n_cn_r		; Hyp.cls 669
            cp (hl)		; Hyp.cls 670
            jr c, asm_1_279_n_cn_e3_row		; Hyp.cls 671
            xor a		; Hyp.cls 672
asm_1_279_n_cn_e3_row:		; Hyp.cls 673
            ld (#7683), a		; Hyp.cls 674
            ret		; Hyp.cls 675

; a printable character (B): into the page, on the screen if in front, the column on. The page
; and screen pointers are worked out at the first character after the cursor moved (cn_pv 0),
; then just stepped on - a run of characters costs the 8 screen bytes each, not a sum each
asm_1_279_n_cn_print:		; Hyp.cls 680
            ld a, (asm_1_279_n_cn_pv)		; Hyp.cls 681
            or a		; Hyp.cls 682
            jr nz, asm_1_279_n_cn_pr_have		; Hyp.cls 683
            ld a, (#7683)		; Hyp.cls 684
            call asm_1_279_n_cn_rowa		; Hyp.cls 685
            ld a, (#7682)		; Hyp.cls 686
            ld e, a		; Hyp.cls 687
            ld d, 0		; Hyp.cls 688
            add hl, de		; Hyp.cls 689
            ld (asm_1_279_n_cn_pp), hl		; Hyp.cls 690
            ld a, (asm_1_279_n_cn_front)		; Hyp.cls 691
            or a		; Hyp.cls 692
            jr z, asm_1_279_n_cn_pr_set		; Hyp.cls 693
            ld a, (#7682)		; Hyp.cls 694
            ld d, a		; Hyp.cls 695
            ld a, (#7683)		; Hyp.cls 696
            ld e, a		; Hyp.cls 697
            push bc                 ; (B: the character) [698]
            call asm_1_279_n_cn_scr		; Hyp.cls 699
            pop bc		; Hyp.cls 700
            ld (asm_1_279_n_cn_sp), hl		; Hyp.cls 701
asm_1_279_n_cn_pr_set:		; Hyp.cls 702
            ld a, 1		; Hyp.cls 703
            ld (asm_1_279_n_cn_pv), a		; Hyp.cls 704
asm_1_279_n_cn_pr_have:		; Hyp.cls 705
            ld hl, (asm_1_279_n_cn_pp)          ; the page [706]
            ld (hl), b		; Hyp.cls 707
            inc hl		; Hyp.cls 708
            ld (asm_1_279_n_cn_pp), hl		; Hyp.cls 709
            ld a, (asm_1_279_n_cn_front)		; Hyp.cls 710
            or a		; Hyp.cls 711
            jr z, asm_1_279_n_cn_pr_adv		; Hyp.cls 712
            ld hl, (asm_1_279_n_cn_sp)          ; the screen [713]
            push hl		; Hyp.cls 714
            ld a, b		; Hyp.cls 715
            call asm_1_279_n_cn_glyph8		; Hyp.cls 716
            pop hl		; Hyp.cls 717
            call asm_1_279_n_cn_next		; Hyp.cls 718
            ld (asm_1_279_n_cn_sp), hl		; Hyp.cls 719
asm_1_279_n_cn_pr_adv:		; Hyp.cls 720
            ld hl, #7682		; Hyp.cls 721
            inc (hl)		; Hyp.cls 722
            ld a, (hl)		; Hyp.cls 723
            ld hl, asm_1_279_n_cn_c		; Hyp.cls 724
            cp (hl)		; Hyp.cls 725
            ret c		; Hyp.cls 726
            xor a                   ; past the last column: the next row [727]
            ld (#7682), a		; Hyp.cls 728
            ld (asm_1_279_n_cn_pv), a		; Hyp.cls 729
; a line feed: the next row, or the page (and the screen) scroll
asm_1_279_n_cn_nl:		; Hyp.cls 731
            ld a, (#7683)		; Hyp.cls 732
            inc a		; Hyp.cls 733
            ld hl, asm_1_279_n_cn_r		; Hyp.cls 734
            cp (hl)		; Hyp.cls 735
            jr nc, asm_1_279_n_cn_scroll		; Hyp.cls 736
            ld (#7683), a		; Hyp.cls 737
            ret		; Hyp.cls 738
asm_1_279_n_cn_scroll:		; Hyp.cls 739
            ld a, (#7684)           ; the ring's top row moves on (no copy) [740]
            inc a		; Hyp.cls 741
            cp (hl)		; Hyp.cls 742
            jr c, asm_1_279_n_cn_sc_top		; Hyp.cls 743
            xor a		; Hyp.cls 744
asm_1_279_n_cn_sc_top:		; Hyp.cls 745
            ld (#7684), a		; Hyp.cls 746
            ld a, (asm_1_279_n_cn_r)		; Hyp.cls 747
            dec a		; Hyp.cls 748
            call asm_1_279_n_cn_rowa            ; the new last row cleared (the old top row: kept first) [749]
            IF asm_1_279_n_CN_SB		; Hyp.cls 750
            push hl		; Hyp.cls 751
            call asm_1_279_n_cn_hput		; Hyp.cls 752
            pop hl		; Hyp.cls 753
            ENDIF		; Hyp.cls 754
            ld a, (asm_1_279_n_cn_c)		; Hyp.cls 755
            ld b, a		; Hyp.cls 756
asm_1_279_n_cn_sc_cl:		; Hyp.cls 757
            ld (hl), ' '		; Hyp.cls 758
            inc hl		; Hyp.cls 759
            djnz asm_1_279_n_cn_sc_cl		; Hyp.cls 760
            ld a, (asm_1_279_n_cn_front)		; Hyp.cls 761
            or a		; Hyp.cls 762
            ret z		; Hyp.cls 763
            ld hl, (var_hyp_sco)          ; the screen: its start a row on (R12, R13), the new last row [764]
            ld de, (var_hyp_scc)          ; cleared, the status strip again (it went off the top) [765]
            add hl, de		; Hyp.cls 766
            ld a, h		; Hyp.cls 767
            and #07		; Hyp.cls 768
            ld h, a		; Hyp.cls 769
            ld (var_hyp_sco), hl		; Hyp.cls 770
            call asm_1_279_n_cn_crtc		; Hyp.cls 771
            ld a, (asm_1_279_n_cn_r)		; Hyp.cls 772
            dec a		; Hyp.cls 773
            ld e, a		; Hyp.cls 774
asm_1_279_n_cn_sc_clr:                          ; E = a screen row: cleared, then the status strip again [775]
            ld d, 0		; Hyp.cls 776
            call asm_1_279_n_cn_scr		; Hyp.cls 777
            ld b, 8		; Hyp.cls 778
asm_1_279_n_cn_sc_ln:		; Hyp.cls 779
            push bc		; Hyp.cls 780
            push hl		; Hyp.cls 781
            ld a, (var_hyp_scc)		; Hyp.cls 782
            ld b, a		; Hyp.cls 783
asm_1_279_n_cn_sc_b:		; Hyp.cls 784
            ld (hl), 0		; Hyp.cls 785
            call asm_1_279_n_cn_next		; Hyp.cls 786
            djnz asm_1_279_n_cn_sc_b		; Hyp.cls 787
            pop hl		; Hyp.cls 788
            ld a, h		; Hyp.cls 789
            add a, 8		; Hyp.cls 790
            ld h, a		; Hyp.cls 791
            pop bc		; Hyp.cls 792
            djnz asm_1_279_n_cn_sc_ln		; Hyp.cls 793
            jp asm_1_279_n_cn_strip		; Hyp.cls 794

; ESC I (reverse line feed): the row before, or on the top row the page (and the screen) scroll
; back: the ring's top row a row back, the new top row cleared; on the screen its start a row
; back (R12, R13) and the new top row cleared - the line feed's scroll the other way
asm_1_279_n_cn_rev:		; Hyp.cls 799
            ld a, (#7683)		; Hyp.cls 800
            or a		; Hyp.cls 801
            jr z, asm_1_279_n_cn_rv_sc		; Hyp.cls 802
            dec a		; Hyp.cls 803
            ld (#7683), a		; Hyp.cls 804
            ret		; Hyp.cls 805
asm_1_279_n_cn_rv_sc:		; Hyp.cls 806
            ld a, (#7684)		; Hyp.cls 807
            or a		; Hyp.cls 808
            jr nz, asm_1_279_n_cn_rv_top		; Hyp.cls 809
            ld a, (asm_1_279_n_cn_r)		; Hyp.cls 810
asm_1_279_n_cn_rv_top:		; Hyp.cls 811
            dec a		; Hyp.cls 812
            ld (#7684), a		; Hyp.cls 813
            xor a		; Hyp.cls 814
            call asm_1_279_n_cn_rowa            ; (row 0 of the page now) [815]
            ld a, (asm_1_279_n_cn_c)		; Hyp.cls 816
            ld b, a		; Hyp.cls 817
asm_1_279_n_cn_rv_cl:		; Hyp.cls 818
            ld (hl), ' '		; Hyp.cls 819
            inc hl		; Hyp.cls 820
            djnz asm_1_279_n_cn_rv_cl		; Hyp.cls 821
            ld a, (asm_1_279_n_cn_front)		; Hyp.cls 822
            or a		; Hyp.cls 823
            ret z		; Hyp.cls 824
            ld hl, (var_hyp_sco)		; Hyp.cls 825
            ld de, (var_hyp_scc)		; Hyp.cls 826
            or a		; Hyp.cls 827
            sbc hl, de		; Hyp.cls 828
            ld a, h		; Hyp.cls 829
            and #07		; Hyp.cls 830
            ld h, a		; Hyp.cls 831
            ld (var_hyp_sco), hl		; Hyp.cls 832
            call asm_1_279_n_cn_crtc		; Hyp.cls 833
            ld e, 0		; Hyp.cls 834
            jp asm_1_279_n_cn_sc_clr		; Hyp.cls 835

; ESC E: the page cleared, column, row and ring back to 0; the screen too if in front (written,
; not copied: the Library: ROM build may have the keyword ROM over it for reads)
asm_1_279_n_cn_clear:		; Hyp.cls 839
            ld hl, #7700		; Hyp.cls 840
            ld de, #7701		; Hyp.cls 841
            ld (hl), ' '		; Hyp.cls 842
            ld bc, 2047		; Hyp.cls 843
            ldir		; Hyp.cls 844
            xor a		; Hyp.cls 845
            ld (#7682), a		; Hyp.cls 846
            ld (#7683), a		; Hyp.cls 847
            ld (#7684), a		; Hyp.cls 848
            ld a, (asm_1_279_n_cn_front)		; Hyp.cls 849
            or a		; Hyp.cls 850
            ret z		; Hyp.cls 851
            ld hl, 0		; Hyp.cls 852
            ld (var_hyp_sco), hl		; Hyp.cls 853
            ld (var_hyp_pon), hl          ; (no pointer on the cleared screen) [854]
            call asm_1_279_n_cn_crtc		; Hyp.cls 855
            xor a		; Hyp.cls 856
            ld hl, #C000		; Hyp.cls 857
            ld c, #40		; Hyp.cls 858
asm_1_279_n_cn_cl_l:		; Hyp.cls 859
            ld b, 0		; Hyp.cls 860
asm_1_279_n_cn_cl_b:		; Hyp.cls 861
            ld (hl), a		; Hyp.cls 862
            inc hl		; Hyp.cls 863
            djnz asm_1_279_n_cn_cl_b		; Hyp.cls 864
            dec c		; Hyp.cls 865
            jr nz, asm_1_279_n_cn_cl_l		; Hyp.cls 866
; cn_strip: MODE S (the screen wider than the console): the status strip's 4 characters (#F68A)
; at the top of the columns right of the console
asm_1_279_n_cn_strip:		; Hyp.cls 869
            ld a, (asm_1_279_n_cn_front)		; Hyp.cls 870
            or a		; Hyp.cls 871
            ret z		; Hyp.cls 872
            ld a, (asm_1_279_n_cn_c)		; Hyp.cls 873
            ld d, a		; Hyp.cls 874
            ld a, (var_hyp_scc)		; Hyp.cls 875
            cp d		; Hyp.cls 876
            ret z		; Hyp.cls 877
            ret c		; Hyp.cls 878
            ld e, 0		; Hyp.cls 879
            ld hl, #768A		; Hyp.cls 880
            ld b, 4		; Hyp.cls 881
asm_1_279_n_cn_st_lp:		; Hyp.cls 882
            ld a, (hl)		; Hyp.cls 883
            push hl		; Hyp.cls 884
            push de		; Hyp.cls 885
            push bc		; Hyp.cls 886
            call asm_1_279_n_cn_glyph		; Hyp.cls 887
            pop bc		; Hyp.cls 888
            pop de		; Hyp.cls 889
            pop hl		; Hyp.cls 890
            inc hl		; Hyp.cls 891
            inc d		; Hyp.cls 892
            djnz asm_1_279_n_cn_st_lp		; Hyp.cls 893
            ret		; Hyp.cls 894

; cn_crtc: the screen's start (sco, bytes) to the CRTC: R12 = #30 + its words' high 2 bits, R13
; the low 8 (#C000, MA10 / MA11 clear: kept within 2K, never the carry into the next 16K)
asm_1_279_n_cn_crtc:		; Hyp.cls 898
            ld hl, (var_hyp_sco)		; Hyp.cls 899
            srl h		; Hyp.cls 900
            rr l		; Hyp.cls 901
            ld a, h		; Hyp.cls 902
            and 3		; Hyp.cls 903
            or #30		; Hyp.cls 904
            ld bc, #BC0C		; Hyp.cls 905
            out (c), c		; Hyp.cls 906
            inc b		; Hyp.cls 907
            out (c), a		; Hyp.cls 908
            ld bc, #BC0D		; Hyp.cls 909
            out (c), c		; Hyp.cls 910
            inc b		; Hyp.cls 911
            out (c), l		; Hyp.cls 912
            ret		; Hyp.cls 913

; cn_rowa: A = row of the screen -> HL = its row in the page ring (#7700 + ((top + A) mod rows)
; * columns)
asm_1_279_n_cn_rowa:		; Hyp.cls 917
            ld hl, #7684		; Hyp.cls 918
            add a, (hl)		; Hyp.cls 919
            ld hl, asm_1_279_n_cn_r		; Hyp.cls 920
            cp (hl)		; Hyp.cls 921
            jr c, asm_1_279_n_cn_ra_in		; Hyp.cls 922
            sub (hl)		; Hyp.cls 923
asm_1_279_n_cn_ra_in:		; Hyp.cls 924
            ld e, a		; Hyp.cls 925
            ld a, (asm_1_279_n_cn_c)		; Hyp.cls 926
            call asm_1_279_n_cn_mul		; Hyp.cls 927
            ld de, #7700		; Hyp.cls 928
            add hl, de		; Hyp.cls 929
            ret		; Hyp.cls 930

; cn_mul: HL = A * E (BC kept; D = 0 after)
asm_1_279_n_cn_mul:		; Hyp.cls 933
            push bc		; Hyp.cls 934
            ld hl, 0		; Hyp.cls 935
            ld d, 0		; Hyp.cls 936
            ld b, 8		; Hyp.cls 937
asm_1_279_n_cn_mu_lp:		; Hyp.cls 938
            add hl, hl		; Hyp.cls 939
            rlca		; Hyp.cls 940
            jr nc, asm_1_279_n_cn_mu_n		; Hyp.cls 941
            add hl, de		; Hyp.cls 942
asm_1_279_n_cn_mu_n:		; Hyp.cls 943
            djnz asm_1_279_n_cn_mu_lp		; Hyp.cls 944
            pop bc		; Hyp.cls 945
            ret		; Hyp.cls 946

; cn_next: HL = the next screen byte: + 1 within its 2K line block (BC kept)
asm_1_279_n_cn_next:		; Hyp.cls 949
            inc l		; Hyp.cls 950
            ret nz		; Hyp.cls 951
            ld a, h		; Hyp.cls 952
            inc a		; Hyp.cls 953
            and #07		; Hyp.cls 954
            push bc		; Hyp.cls 955
            ld c, a		; Hyp.cls 956
            ld a, h		; Hyp.cls 957
            and #F8		; Hyp.cls 958
            or c		; Hyp.cls 959
            ld h, a		; Hyp.cls 960
            pop bc		; Hyp.cls 961
            ret		; Hyp.cls 962

; cn_glyph: A = character, D = column, E = row: drawn (cn_show)
asm_1_279_n_cn_glyph:		; Hyp.cls 965
            push af		; Hyp.cls 966
            call asm_1_279_n_cn_scr		; Hyp.cls 967
            pop af		; Hyp.cls 968
; cn_glyph8: A = character, HL = its screen address: its 8 bytes into screen memory (mode 2, pen
; 1 on paper 0), one per pixel line (#800 apart; unrolled)
asm_1_279_n_cn_glyph8:		; Hyp.cls 971
            sub 32		; Hyp.cls 972
            cp 96		; Hyp.cls 973
            jr c, asm_1_279_n_cn_gl_ok		; Hyp.cls 974
            ld a, '?' - 32		; Hyp.cls 975
asm_1_279_n_cn_gl_ok:		; Hyp.cls 976
            push hl		; Hyp.cls 977
            ld l, a		; Hyp.cls 978
            ld h, 0		; Hyp.cls 979
            add hl, hl		; Hyp.cls 980
            add hl, hl		; Hyp.cls 981
            add hl, hl		; Hyp.cls 982
            ld de, 62208 - #8000   ; (the bank's page 3 in the window: FONT - #C000 + #4000) [983]
            add hl, de		; Hyp.cls 984
            ex de, hl               ; DE = its matrix [985]
            pop hl		; Hyp.cls 986
            ld a, (de)		; Hyp.cls 987
            ld (hl), a		; Hyp.cls 988
            inc de		; Hyp.cls 989
            ld a, h		; Hyp.cls 990
            add a, 8		; Hyp.cls 991
            ld h, a		; Hyp.cls 992
            ld a, (de)		; Hyp.cls 993
            ld (hl), a		; Hyp.cls 994
            inc de		; Hyp.cls 995
            ld a, h		; Hyp.cls 996
            add a, 8		; Hyp.cls 997
            ld h, a		; Hyp.cls 998
            ld a, (de)		; Hyp.cls 999
            ld (hl), a		; Hyp.cls 1000
            inc de		; Hyp.cls 1001
            ld a, h		; Hyp.cls 1002
            add a, 8		; Hyp.cls 1003
            ld h, a		; Hyp.cls 1004
            ld a, (de)		; Hyp.cls 1005
            ld (hl), a		; Hyp.cls 1006
            inc de		; Hyp.cls 1007
            ld a, h		; Hyp.cls 1008
            add a, 8		; Hyp.cls 1009
            ld h, a		; Hyp.cls 1010
            ld a, (de)		; Hyp.cls 1011
            ld (hl), a		; Hyp.cls 1012
            inc de		; Hyp.cls 1013
            ld a, h		; Hyp.cls 1014
            add a, 8		; Hyp.cls 1015
            ld h, a		; Hyp.cls 1016
            ld a, (de)		; Hyp.cls 1017
            ld (hl), a		; Hyp.cls 1018
            inc de		; Hyp.cls 1019
            ld a, h		; Hyp.cls 1020
            add a, 8		; Hyp.cls 1021
            ld h, a		; Hyp.cls 1022
            ld a, (de)		; Hyp.cls 1023
            ld (hl), a		; Hyp.cls 1024
            inc de		; Hyp.cls 1025
            ld a, h		; Hyp.cls 1026
            add a, 8		; Hyp.cls 1027
            ld h, a		; Hyp.cls 1028
            ld a, (de)		; Hyp.cls 1029
            ld (hl), a		; Hyp.cls 1030
            ret		; Hyp.cls 1031
; cn_scr: D = column, E = row -> HL = the screen address: the screen's start (sco) + row *
; columns (scc) + column, within each 2K line block, at #C000
asm_1_279_n_cn_scr:		; Hyp.cls 1034
            push de		; Hyp.cls 1035
            ld a, (var_hyp_scc)		; Hyp.cls 1036
            call asm_1_279_n_cn_mul		; Hyp.cls 1037
            pop de		; Hyp.cls 1038
            ld c, d		; Hyp.cls 1039
            ld b, 0		; Hyp.cls 1040
            add hl, bc		; Hyp.cls 1041
            ld bc, (var_hyp_sco)		; Hyp.cls 1042
            add hl, bc		; Hyp.cls 1043
            ld a, h		; Hyp.cls 1044
            and #07		; Hyp.cls 1045
            or #C0		; Hyp.cls 1046
            ld h, a		; Hyp.cls 1047
            ret		; Hyp.cls 1048
asm_1_279_n_cn_front:   db 0		; Hyp.cls 1049
asm_1_279_n_cn_c:       db 80                   ; the slot's columns, rows [1050]
asm_1_279_n_cn_r:       db 25		; Hyp.cls 1051
asm_1_279_n_cn_pv:      db 0                    ; cn_pp / cn_sp valid (0: the cursor moved) [1052]
asm_1_279_n_cn_pp:      dw 0                    ; the page byte for the next character [1053]
asm_1_279_n_cn_sp:      dw 0                    ; its screen address [1054]
asm_1_279_n_cn_left:    dw 0		; Hyp.cls 1055
asm_1_279_n_cn_ptr:     dw 0		; Hyp.cls 1056
            IF asm_1_279_n_CN_SB		; Hyp.cls 1057
asm_1_279_n_cn_pg:      dw 0                    ; the slot's page 3 setting (pg) [1058]
asm_1_279_n_cn_h1:      dw 0                    ; cn_hcp: from (its setting, address), to, 8-byte runs left [1059]
asm_1_279_n_cn_hs:      dw 0		; Hyp.cls 1060
asm_1_279_n_cn_h2:      dw 0		; Hyp.cls 1061
asm_1_279_n_cn_hd:      dw 0		; Hyp.cls 1062
asm_1_279_n_cn_hn:      db 0		; Hyp.cls 1063
            ENDIF		; Hyp.cls 1064
asm_1_279_n_cn_end:		; Hyp.cls 1065
			ret			; end of #asm

asm_1_1073_n:		; #asm, Hyp.cls line 1073 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 1074
            ld sp, (ntc_csp)		; Hyp.cls 1075
            ld bc, (var_hyp_hps)          ; the hypervisor's page in the window: the font [1076]
            out (c), c		; Hyp.cls 1077
            ld hl, (var_hyp_sco)          ; the screen's start (TOP is shown in MODE 2: 80 columns) [1078]
            ld (asm_1_1073_n_sy_off), hl		; Hyp.cls 1079
            ld hl, (var_hyp_say_p)		; Hyp.cls 1080
            ld a, (var_hyp_say_n)		; Hyp.cls 1081
            ld b, a		; Hyp.cls 1082
            ld a, (var_hyp_say_col)		; Hyp.cls 1083
            ld d, a		; Hyp.cls 1084
            ld a, (var_hyp_say_row)		; Hyp.cls 1085
            ld e, a		; Hyp.cls 1086
            inc b		; Hyp.cls 1087
asm_1_1073_n_sy_lp:		; Hyp.cls 1088
            dec b		; Hyp.cls 1089
            jr z, asm_1_1073_n_sy_done		; Hyp.cls 1090
            ld a, d		; Hyp.cls 1091
            cp 80		; Hyp.cls 1092
            jr nc, asm_1_1073_n_sy_done		; Hyp.cls 1093
            ld a, (hl)		; Hyp.cls 1094
            inc hl		; Hyp.cls 1095
            push hl		; Hyp.cls 1096
            push bc		; Hyp.cls 1097
            push de		; Hyp.cls 1098
            sub 32                  ; the character's matrix [1099]
            cp 96		; Hyp.cls 1100
            jr c, asm_1_1073_n_sy_ok		; Hyp.cls 1101
            ld a, '?' - 32		; Hyp.cls 1102
asm_1_1073_n_sy_ok:		; Hyp.cls 1103
            ld l, a		; Hyp.cls 1104
            ld h, 0		; Hyp.cls 1105
            add hl, hl		; Hyp.cls 1106
            add hl, hl		; Hyp.cls 1107
            add hl, hl		; Hyp.cls 1108
            ld bc, #4000 + 4096  ; (the hypervisor's page in the window) [1109]
            add hl, bc		; Hyp.cls 1110
            push hl		; Hyp.cls 1111
            ld l, e                 ; its screen address: start + row * 80 + column, in 2K [1112]
            ld h, 0		; Hyp.cls 1113
            add hl, hl		; Hyp.cls 1114
            add hl, hl		; Hyp.cls 1115
            add hl, hl		; Hyp.cls 1116
            add hl, hl		; Hyp.cls 1117
            push hl		; Hyp.cls 1118
            add hl, hl		; Hyp.cls 1119
            add hl, hl		; Hyp.cls 1120
            pop bc		; Hyp.cls 1121
            add hl, bc		; Hyp.cls 1122
            ld c, d		; Hyp.cls 1123
            ld b, 0		; Hyp.cls 1124
            add hl, bc		; Hyp.cls 1125
            ld bc, (asm_1_1073_n_sy_off)		; Hyp.cls 1126
            add hl, bc		; Hyp.cls 1127
            ld a, h		; Hyp.cls 1128
            and #07		; Hyp.cls 1129
            or #C0		; Hyp.cls 1130
            ld h, a		; Hyp.cls 1131
            pop de		; Hyp.cls 1132
            ld b, 8		; Hyp.cls 1133
asm_1_1073_n_sy_ln:		; Hyp.cls 1134
            ld a, (de)		; Hyp.cls 1135
            ld (hl), a		; Hyp.cls 1136
            inc de		; Hyp.cls 1137
            ld a, h		; Hyp.cls 1138
            add a, 8		; Hyp.cls 1139
            ld h, a		; Hyp.cls 1140
            djnz asm_1_1073_n_sy_ln		; Hyp.cls 1141
            pop de		; Hyp.cls 1142
            pop bc		; Hyp.cls 1143
            pop hl		; Hyp.cls 1144
            inc d		; Hyp.cls 1145
            jr asm_1_1073_n_sy_lp		; Hyp.cls 1146
asm_1_1073_n_sy_done:		; Hyp.cls 1147
            ld bc, (ntc_rampt)		; Hyp.cls 1148
            out (c), c		; Hyp.cls 1149
            ld sp, (var_hyp_hsp)		; Hyp.cls 1150
            jr asm_1_1073_n_sy_end		; Hyp.cls 1151
asm_1_1073_n_sy_off:     dw 0		; Hyp.cls 1152
asm_1_1073_n_sy_end:		; Hyp.cls 1153
			ret			; end of #asm

asm_1_1167_n:		; #asm, Hyp.cls line 1167 (normal)
            ld (var_hyp_hsp), sp          ; (the real stack: SP is the thread) [1168]
            ld sp, (ntc_csp)		; Hyp.cls 1169
            ld a, (var_hyp_scr_m)		; Hyp.cls 1170
            cp 6		; Hyp.cls 1171
            jr c, asm_1_1167_n_sm_ok		; Hyp.cls 1172
            xor a		; Hyp.cls 1173
asm_1_1167_n_sm_ok:		; Hyp.cls 1174
            ld l, a                 ; the mode's row of the table (6 bytes) [1175]
            add a, a		; Hyp.cls 1176
            add a, l		; Hyp.cls 1177
            add a, a		; Hyp.cls 1178
            ld e, a		; Hyp.cls 1179
            ld d, 0		; Hyp.cls 1180
            ld hl, asm_1_1167_n_sm_tab		; Hyp.cls 1181
            add hl, de		; Hyp.cls 1182
            ld a, (var_hyp_scr_k)		; Hyp.cls 1183
            or a		; Hyp.cls 1184
            jr z, asm_1_1167_n_sm_cols		; Hyp.cls 1185
            dec a		; Hyp.cls 1186
            jr z, asm_1_1167_n_sm_rows		; Hyp.cls 1187
            push hl                 ; 2: the screen [1188]
            ld e, (hl)              ; its columns [1189]
            ld d, 0		; Hyp.cls 1190
            ld (var_hyp_scc), de		; Hyp.cls 1191
            srl e		; Hyp.cls 1192
            ld (var_hyp_scw), de		; Hyp.cls 1193
            ld hl, 0		; Hyp.cls 1194
            ld (var_hyp_sco), hl		; Hyp.cls 1195
            ld (var_hyp_pon), hl          ; (no pointer on the cleared screen) [1196]
            pop hl		; Hyp.cls 1197
            inc hl		; Hyp.cls 1198
            inc hl                  ; R1, R2, R6, R7 [1199]
            di		; Hyp.cls 1200
            ld d, 1		; Hyp.cls 1201
            call asm_1_1167_n_sm_crtc		; Hyp.cls 1202
            ld d, 2		; Hyp.cls 1203
            call asm_1_1167_n_sm_crtc		; Hyp.cls 1204
            ld d, 6		; Hyp.cls 1205
            call asm_1_1167_n_sm_crtc		; Hyp.cls 1206
            ld d, 7		; Hyp.cls 1207
            call asm_1_1167_n_sm_crtc		; Hyp.cls 1208
            ld hl, asm_1_1167_n_sm_start         ; R12, R13: #C000 [1209]
            ld d, 12		; Hyp.cls 1210
            call asm_1_1167_n_sm_crtc		; Hyp.cls 1211
            ld d, 13		; Hyp.cls 1212
            call asm_1_1167_n_sm_crtc		; Hyp.cls 1213
            xor a                   ; cleared (written, not copied: the Library: ROM build may [1214]
            ld hl, #C000            ; have the keyword ROM over it for reads) [1215]
            ld c, #40		; Hyp.cls 1216
asm_1_1167_n_sm_cl:		; Hyp.cls 1217
            ld b, 0		; Hyp.cls 1218
asm_1_1167_n_sm_cl1:		; Hyp.cls 1219
            ld (hl), a		; Hyp.cls 1220
            inc hl		; Hyp.cls 1221
            djnz asm_1_1167_n_sm_cl1		; Hyp.cls 1222
            dec c		; Hyp.cls 1223
            jr nz, asm_1_1167_n_sm_cl		; Hyp.cls 1224
            ld hl, 0		; Hyp.cls 1225
            jr asm_1_1167_n_sm_res		; Hyp.cls 1226
asm_1_1167_n_sm_cols:		; Hyp.cls 1227
            ld a, (hl)              ; the console's: the screen's, less the status strip's 4 (S) [1228]
            inc hl		; Hyp.cls 1229
            sub (hl)		; Hyp.cls 1230
            jr asm_1_1167_n_sm_a		; Hyp.cls 1231
asm_1_1167_n_sm_rows:		; Hyp.cls 1232
            inc hl		; Hyp.cls 1233
            inc hl		; Hyp.cls 1234
            inc hl		; Hyp.cls 1235
            inc hl		; Hyp.cls 1236
            ld a, (hl)		; Hyp.cls 1237
asm_1_1167_n_sm_a:		; Hyp.cls 1238
            ld l, a		; Hyp.cls 1239
            ld h, 0		; Hyp.cls 1240
asm_1_1167_n_sm_res:		; Hyp.cls 1241
            ld (var_hyp_scr_scr), hl		; Hyp.cls 1242
            ld sp, (var_hyp_hsp)		; Hyp.cls 1243
            ret                     ; (on with the thread) [1244]
asm_1_1167_n_sm_crtc:                            ; CRTC register D = (HL), HL on [1245]
            ld bc, #BC00		; Hyp.cls 1246
            out (c), d		; Hyp.cls 1247
            ld b, #BD		; Hyp.cls 1248
            ld a, (hl)		; Hyp.cls 1249
            out (c), a		; Hyp.cls 1250
            inc hl		; Hyp.cls 1251
            ret		; Hyp.cls 1252
asm_1_1167_n_sm_start:   db #30, 0		; Hyp.cls 1253
; columns, the status strip's, R1 (words a row), R2 (horizontal sync), R6 (rows), R7 (vertical sync)
asm_1_1167_n_sm_tab:     db 80, 0, 40, 46, 25, 30		; Hyp.cls 1255
            db 84, 4, 42, 47, 24, 30		; Hyp.cls 1256
            db 88, 0, 44, 48, 23, 29		; Hyp.cls 1257
            db 96, 0, 48, 50, 21, 28		; Hyp.cls 1258
            db 64, 0, 32, 42, 32, 34		; Hyp.cls 1259
            db 84, 0, 42, 47, 24, 30		; Hyp.cls 1260
			ret			; end of #asm

asm_1_1267_n:		; #asm, Hyp.cls line 1267 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 1268
            ld sp, (ntc_csp)		; Hyp.cls 1269
            call #BB42              ; KM GET DELAY: H the start delay, L the repeat [1270]
            di		; Hyp.cls 1271
            ld a, h		; Hyp.cls 1272
            call asm_1_1267_n_kr_mul		; Hyp.cls 1273
            ld h, a		; Hyp.cls 1274
            ld a, l		; Hyp.cls 1275
            call asm_1_1267_n_kr_mul		; Hyp.cls 1276
            ld l, a		; Hyp.cls 1277
            call #BB3F              ; KM SET DELAY [1278]
            di		; Hyp.cls 1279
            ld sp, (var_hyp_hsp)		; Hyp.cls 1280
            jr asm_1_1267_n_kr_end		; Hyp.cls 1281
asm_1_1267_n_kr_mul:                             ; A = A x f, 255 at most (0: 256 to the firmware - kept) [1282]
            or a		; Hyp.cls 1283
            ret z		; Hyp.cls 1284
            push hl		; Hyp.cls 1285
            ld e, a		; Hyp.cls 1286
            ld d, 0		; Hyp.cls 1287
            ld hl, 0		; Hyp.cls 1288
            ld a, (var_hyp_keyrep_f)		; Hyp.cls 1289
            ld b, a		; Hyp.cls 1290
asm_1_1267_n_kr_lp:		; Hyp.cls 1291
            add hl, de		; Hyp.cls 1292
            djnz asm_1_1267_n_kr_lp		; Hyp.cls 1293
            ld a, h		; Hyp.cls 1294
            or a		; Hyp.cls 1295
            ld a, l		; Hyp.cls 1296
            pop hl		; Hyp.cls 1297
            ret z		; Hyp.cls 1298
            ld a, 255		; Hyp.cls 1299
            ret		; Hyp.cls 1300
asm_1_1267_n_kr_end:		; Hyp.cls 1301
			ret			; end of #asm

asm_1_1331_n:		; #asm, Hyp.cls line 1331 (normal)
            ld (var_hyp_sps), sp		; Hyp.cls 1332
            ld sp, (ntc_csp)		; Hyp.cls 1333
            call #B903              ; KL U ROM DISABLE: the task's top 16K, not a ROM (Library: [1334]
            di                      ; ROM has the keyword ROM on), while it runs [1335]
            ld (var_hyp_rrom), a		; Hyp.cls 1336
            ld a, 6		; Hyp.cls 1337
            ld (var_hyp_slc), a		; Hyp.cls 1338
            ld a, 1                 ; from BASIC: it has taken the characters (Collected) [1339]
            ld (var_hyp_rclr), a		; Hyp.cls 1340
asm_1_1331_n_rn_again:		; Hyp.cls 1341
            push ix                 ; IX, IY and [1342]
            push iy		; Hyp.cls 1343
            db #08                  ; ex af, af': the alternate registers kept - the [1344]
            exx                     ; firmware's (BC' = its ROM / mode setting); a task [1345]
            push af                 ; may use them [1346]
            push bc		; Hyp.cls 1347
            push de		; Hyp.cls 1348
            push hl		; Hyp.cls 1349
            exx		; Hyp.cls 1350
            db #08		; Hyp.cls 1351
            ld hl, asm_1_1331_n_rn_back		; Hyp.cls 1352
            push hl                 ; where main RAM carries on [1353]
            ld (ntc_bk_sp), sp		; Hyp.cls 1354
            ld a, (var_hyp_rclr)		; Hyp.cls 1355
            ld e, a                 ; E = 1: the bank empties its characters out (BASIC has them) [1356]
            ld a, (var_hyp_ra)		; Hyp.cls 1357
            ld hl, (var_hyp_rhl)		; Hyp.cls 1358
            ld bc, (var_hyp_run_setting)		; Hyp.cls 1359
            jp ntc_bk_out           ; out (c), c: the task's bank; its #0046 lands it [1360]
asm_1_1331_n_rn_back:		; Hyp.cls 1361
            ld (var_hyp_rcnt), ix         ; the characters it collected (the stubs put them in IX) [1362]
            db #08                  ; ex af, af' [1363]
            exx		; Hyp.cls 1364
            pop hl                  ; the alternate registers back [1365]
            pop de		; Hyp.cls 1366
            pop bc		; Hyp.cls 1367
            pop af		; Hyp.cls 1368
            exx		; Hyp.cls 1369
            db #08		; Hyp.cls 1370
            pop iy		; Hyp.cls 1371
            pop ix		; Hyp.cls 1372
            push af                 ; carry: a BDOS call (A = C, DE = DE) [1373]
            push bc		; Hyp.cls 1374
            ld bc, (ntc_rampt)      ; the window's page back [1375]
            out (c), c		; Hyp.cls 1376
            pop bc		; Hyp.cls 1377
            pop af		; Hyp.cls 1378
            jr c, asm_1_1331_n_rn_far		; Hyp.cls 1379
            rst #38                 ; an interrupt stopped the task: the firmware's handler [1380]
            di		; Hyp.cls 1381
            ld hl, var_hyp_slc            ; a time slice is SLICE interrupts: until it is used up the [1382]
            dec (hl)                ; task carries on straight away (no trip through BASIC) [1383]
            jr z, asm_1_1331_n_rn_int		; Hyp.cls 1384
            ld a, (ntc_isldue)      ; ... unless an interrupt class (the system keys) is due [1385]
            or a		; Hyp.cls 1386
            jr nz, asm_1_1331_n_rn_int		; Hyp.cls 1387
            xor a                   ; its characters stay in its bank (and the count goes on) [1388]
            ld (var_hyp_rclr), a		; Hyp.cls 1389
            jp asm_1_1331_n_rn_again		; Hyp.cls 1390
asm_1_1331_n_rn_int:		; Hyp.cls 1391
            ld hl, 0		; Hyp.cls 1392
            jr asm_1_1331_n_rn_end		; Hyp.cls 1393
asm_1_1331_n_rn_far:		; Hyp.cls 1394
            ld (var_hyp_rfn), a		; Hyp.cls 1395
            ld (var_hyp_rde), de		; Hyp.cls 1396
            ld hl, 1		; Hyp.cls 1397
asm_1_1331_n_rn_end:		; Hyp.cls 1398
            ld (var_hyp_run_run), hl		; Hyp.cls 1399
            ld a, (var_hyp_rrom)		; Hyp.cls 1400
            call #B90C              ; KL ROM RESTORE [1401]
            di		; Hyp.cls 1402
            ld sp, (var_hyp_sps)		; Hyp.cls 1403

			ret			; end of #asm

fn_hyp_info:		; function info (asm keyword), Hyp.cls line 1413
            pop hl		; Hyp.cls 1414
            ld a, (hl)		; Hyp.cls 1415
            ld hl, fn_hyp_info_hi_p0		; Hyp.cls 1416
            or a		; Hyp.cls 1417
            jr z, fn_hyp_info_in_e		; Hyp.cls 1418
            ld hl, fn_hyp_info_hi_p0e - fn_hyp_info_hi_p0		; Hyp.cls 1419
            dec a		; Hyp.cls 1420
            jr z, fn_hyp_info_in_e		; Hyp.cls 1421
            ld hl, fn_hyp_info_sb_img		; Hyp.cls 1422
            dec a		; Hyp.cls 1423
            jr z, fn_hyp_info_in_e		; Hyp.cls 1424
            ld hl, fn_hyp_info_sb_end - fn_hyp_info_sb_start		; Hyp.cls 1425
            dec a		; Hyp.cls 1426
            jr z, fn_hyp_info_in_e		; Hyp.cls 1427
            ld hl, fn_hyp_info_sb_init		; Hyp.cls 1428
fn_hyp_info_in_e:		; Hyp.cls 1429
            ex de, hl		; Hyp.cls 1430
            pop hl		; Hyp.cls 1431
            ld (hl), e		; Hyp.cls 1432
            inc hl		; Hyp.cls 1433
            ld (hl), d		; Hyp.cls 1434
            ret		; Hyp.cls 1435

			ret			; end of #asm

asm_1_2004_n:		; #asm, Hyp.cls line 2004 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 2005
            ld sp, (ntc_csp)		; Hyp.cls 2006
            ld a, (var_hyp_vdu_on)		; Hyp.cls 2007
            or a		; Hyp.cls 2008
            jr z, asm_1_2004_n_vd_off		; Hyp.cls 2009
            call #BB54              ; TXT VDU ENABLE [2010]
            jr asm_1_2004_n_vd_done		; Hyp.cls 2011
asm_1_2004_n_vd_off:		; Hyp.cls 2012
            call #BB57              ; TXT VDU DISABLE [2013]
asm_1_2004_n_vd_done:		; Hyp.cls 2014
            di		; Hyp.cls 2015
            ld sp, (var_hyp_hsp)		; Hyp.cls 2016
			ret			; end of #asm

asm_1_2036_n:		; #asm, Hyp.cls line 2036 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 2037
            ld sp, (ntc_csp)		; Hyp.cls 2038
            ld (asm_1_2036_n_fl_ix), ix		; Hyp.cls 2039
            ld (asm_1_2036_n_fl_iy), iy		; Hyp.cls 2040
            ld a, 255		; Hyp.cls 2041
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 2042
            ld a, (var_hyp_filecall_slot)		; Hyp.cls 2043
            ld (asm_1_2036_n_fl_slot), a		; Hyp.cls 2044
            ld a, (var_hyp_filecall_f)		; Hyp.cls 2045
            cp 99		; Hyp.cls 2046
            jp z, asm_1_2036_n_fl_inst		; Hyp.cls 2047
            IF NTC_ROMLIB = 0		; Hyp.cls 2048
; the RAM discs' driver (RAMDISC.CYB's, in a page of its own at #4000) sees the call first:
; carry - it was one of its drives' (HL the answer), else on to the disc ROM. It gets IX = the
; call (f, fcb, slot, setting, dma, drive, buf; 100-105: drive = the hypervisor's drive), at
; #4003 a jump to fl_dx (its copies: it runs in the window, so can't switch it itself), at
; #4006 its page's RAM setting
            ASSERT var_hyp_filecall_buf - var_hyp_filecall_f = 12, "FileCall's parameters, one after another"		; Hyp.cls 2054
            ld a, (var_hyp_drs + 1)		; Hyp.cls 2055
            or a		; Hyp.cls 2056
            jr z, asm_1_2036_n_fl_nodrv		; Hyp.cls 2057
            di		; Hyp.cls 2058
            ld a, (var_hyp_filecall_f)		; Hyp.cls 2059
            cp 100		; Hyp.cls 2060
            jr c, asm_1_2036_n_fl_dr_go		; Hyp.cls 2061
            cp 106		; Hyp.cls 2062
            jr nc, asm_1_2036_n_fl_dr_go		; Hyp.cls 2063
            ld hl, (var_hyp_hdr)		; Hyp.cls 2064
            ld (var_hyp_filecall_drive), hl		; Hyp.cls 2065
asm_1_2036_n_fl_dr_go:		; Hyp.cls 2066
            ld bc, (var_hyp_drs)		; Hyp.cls 2067
            out (c), c		; Hyp.cls 2068
            ld hl, asm_1_2036_n_fl_dx		; Hyp.cls 2069
            ld (#4004), hl		; Hyp.cls 2070
            ld hl, (var_hyp_drs)		; Hyp.cls 2071
            ld (#4006), hl		; Hyp.cls 2072
            ld ix, var_hyp_filecall_f		; Hyp.cls 2073
            call #4000		; Hyp.cls 2074
            jr nc, asm_1_2036_n_fl_nodrv		; Hyp.cls 2075
            ld (asm_1_2036_n_fl_res16), hl		; Hyp.cls 2076
            ld a, 1		; Hyp.cls 2077
            ld (asm_1_2036_n_fl_r16), a		; Hyp.cls 2078
            jp asm_1_2036_n_fl_done		; Hyp.cls 2079
; fl_dx - A bytes (1-128) from HL to DE through dxb: IX = HL's RAM setting, IY = DE's (0:
; main RAM, no switch); the driver's page back in the window after. HL, DE on past them
asm_1_2036_n_fl_dx:		; Hyp.cls 2082
            ld (asm_1_2036_n_fl_dxn), a		; Hyp.cls 2083
            push de		; Hyp.cls 2084
            ld de, (var_hyp_dxb)		; Hyp.cls 2085
            push ix		; Hyp.cls 2086
            pop bc		; Hyp.cls 2087
            inc b		; Hyp.cls 2088
            dec b		; Hyp.cls 2089
            jr z, asm_1_2036_n_fl_dx1		; Hyp.cls 2090
            out (c), c		; Hyp.cls 2091
asm_1_2036_n_fl_dx1:		; Hyp.cls 2092
            ld c, a		; Hyp.cls 2093
            ld b, 0		; Hyp.cls 2094
            ldir		; Hyp.cls 2095
            pop de		; Hyp.cls 2096
            push hl		; Hyp.cls 2097
            push iy		; Hyp.cls 2098
            pop bc		; Hyp.cls 2099
            inc b		; Hyp.cls 2100
            dec b		; Hyp.cls 2101
            jr z, asm_1_2036_n_fl_dx2		; Hyp.cls 2102
            out (c), c		; Hyp.cls 2103
asm_1_2036_n_fl_dx2:		; Hyp.cls 2104
            ld hl, (var_hyp_dxb)		; Hyp.cls 2105
            ld a, (asm_1_2036_n_fl_dxn)		; Hyp.cls 2106
            ld c, a		; Hyp.cls 2107
            ld b, 0		; Hyp.cls 2108
            ldir		; Hyp.cls 2109
            pop hl		; Hyp.cls 2110
            ld bc, (var_hyp_drs)		; Hyp.cls 2111
            out (c), c		; Hyp.cls 2112
            ret		; Hyp.cls 2113
asm_1_2036_n_fl_dxn:     db 0		; Hyp.cls 2114
asm_1_2036_n_fl_nodrv:		; Hyp.cls 2115
            ENDIF		; Hyp.cls 2116
            di		; Hyp.cls 2117
            ld bc, (var_hyp_hps)          ; the rest runs in the hypervisor's page (window data from [2118]
            out (c), c              ; #5300: fp_go) [2119]
            call asm_1_2036_n_fp_go		; Hyp.cls 2120
            jp asm_1_2036_n_fl_done		; Hyp.cls 2121
; 99: the window data (#5300 to fp_end: the bank image, the page code) copied from main RAM's
; own #4000-#7FFF (where the file put it) into the hypervisor's page, through buf; once, at the
; start, before anything else uses main RAM's #4000-#7FFF
asm_1_2036_n_fl_inst:		; Hyp.cls 2125
            ld hl, #5300		; Hyp.cls 2126
asm_1_2036_n_fl_in_lp:		; Hyp.cls 2127
            push hl		; Hyp.cls 2128
            ld bc, #7FC0            ; main RAM's own [2129]
            out (c), c		; Hyp.cls 2130
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2131
            ld bc, 128		; Hyp.cls 2132
            ldir		; Hyp.cls 2133
            ld bc, (var_hyp_hps)		; Hyp.cls 2134
            out (c), c		; Hyp.cls 2135
            pop de		; Hyp.cls 2136
            push de		; Hyp.cls 2137
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2138
            ld bc, 128		; Hyp.cls 2139
            ldir		; Hyp.cls 2140
            pop hl		; Hyp.cls 2141
            ld bc, 128		; Hyp.cls 2142
            add hl, bc		; Hyp.cls 2143
            ld de, asm_1_2036_n_fp_end		; Hyp.cls 2144
            or a		; Hyp.cls 2145
            sbc hl, de		; Hyp.cls 2146
            add hl, de		; Hyp.cls 2147
            jr c, asm_1_2036_n_fl_in_lp		; Hyp.cls 2148
            xor a		; Hyp.cls 2149
            ld (asm_1_2036_n_fl_res), a		; Hyp.cls 2150
            jp asm_1_2036_n_fl_done		; Hyp.cls 2151
; ---- what the page code can't do itself (it runs in the window): switch the window to a slot's
; page and back. Each puts the hypervisor's page back in the window
asm_1_2036_n_fl_sel:                             ; the slot's page holding HL in the window: HL = there [2154]
            push de		; Hyp.cls 2155
            ld a, h		; Hyp.cls 2156
            rlca		; Hyp.cls 2157
            rlca		; Hyp.cls 2158
            and 3		; Hyp.cls 2159
            add a, 4		; Hyp.cls 2160
            ld e, a		; Hyp.cls 2161
            ld bc, (var_hyp_filecall_setting)		; Hyp.cls 2162
            ld a, c		; Hyp.cls 2163
            and #F8		; Hyp.cls 2164
            or e		; Hyp.cls 2165
            ld c, a		; Hyp.cls 2166
            out (c), c		; Hyp.cls 2167
            ld a, h		; Hyp.cls 2168
            and #3F		; Hyp.cls 2169
            or #40		; Hyp.cls 2170
            ld h, a		; Hyp.cls 2171
            pop de		; Hyp.cls 2172
            ret		; Hyp.cls 2173
asm_1_2036_n_fl_peek:                            ; A = the slot's byte at HL (BC, DE, HL kept) [2174]
            push bc		; Hyp.cls 2175
            push hl		; Hyp.cls 2176
            call asm_1_2036_n_fl_sel		; Hyp.cls 2177
            ld a, (hl)		; Hyp.cls 2178
asm_1_2036_n_fl_pk_back:		; Hyp.cls 2179
            ld bc, (var_hyp_hps)		; Hyp.cls 2180
            out (c), c		; Hyp.cls 2181
            pop hl		; Hyp.cls 2182
            pop bc		; Hyp.cls 2183
            ret		; Hyp.cls 2184
asm_1_2036_n_fl_poke:                            ; the slot's byte at HL = A (BC, DE, HL kept) [2185]
            push bc		; Hyp.cls 2186
            push hl		; Hyp.cls 2187
            push af		; Hyp.cls 2188
            call asm_1_2036_n_fl_sel		; Hyp.cls 2189
            pop af		; Hyp.cls 2190
            ld (hl), a		; Hyp.cls 2191
            jr asm_1_2036_n_fl_pk_back		; Hyp.cls 2192
asm_1_2036_n_fl_toslot:                          ; BC bytes from DE (main RAM) to the slot's HL (all in one of [2193]
            push bc                 ; its pages: fl_fits) [2194]
            call asm_1_2036_n_fl_sel		; Hyp.cls 2195
            pop bc		; Hyp.cls 2196
            ex de, hl		; Hyp.cls 2197
            ldir		; Hyp.cls 2198
            jr asm_1_2036_n_fl_blk_back		; Hyp.cls 2199
asm_1_2036_n_fl_fromslot:                        ; BC bytes from the slot's HL (in one page) to DE (main RAM) [2200]
            push bc		; Hyp.cls 2201
            call asm_1_2036_n_fl_sel		; Hyp.cls 2202
            pop bc		; Hyp.cls 2203
            ldir		; Hyp.cls 2204
asm_1_2036_n_fl_blk_back:		; Hyp.cls 2205
            ld bc, (var_hyp_hps)		; Hyp.cls 2206
            out (c), c		; Hyp.cls 2207
            ret		; Hyp.cls 2208
asm_1_2036_n_fl_done:		; Hyp.cls 2209
            di		; Hyp.cls 2210
            ld bc, (ntc_rampt)      ; the page that was in the window back [2211]
            out (c), c		; Hyp.cls 2212
            ld a, (asm_1_2036_n_fl_res)		; Hyp.cls 2213
            ld l, a		; Hyp.cls 2214
            ld h, 0		; Hyp.cls 2215
            ld a, (asm_1_2036_n_fl_r16)		; Hyp.cls 2216
            or a		; Hyp.cls 2217
            jr z, asm_1_2036_n_fl_d8		; Hyp.cls 2218
            ld hl, (asm_1_2036_n_fl_res16)		; Hyp.cls 2219
            xor a		; Hyp.cls 2220
            ld (asm_1_2036_n_fl_r16), a		; Hyp.cls 2221
asm_1_2036_n_fl_d8:		; Hyp.cls 2222
            ld (var_hyp_filecall_filecall), hl		; Hyp.cls 2223
            ld ix, (asm_1_2036_n_fl_ix)		; Hyp.cls 2224
            ld iy, (asm_1_2036_n_fl_iy)		; Hyp.cls 2225
            ld sp, (var_hyp_hsp)		; Hyp.cls 2226
            jp asm_1_2036_n_fl_exit		; Hyp.cls 2227
asm_1_2036_n_fl_ix:      dw 0		; Hyp.cls 2228
asm_1_2036_n_fl_iy:      dw 0		; Hyp.cls 2229
asm_1_2036_n_fl_res:     db 0		; Hyp.cls 2230
asm_1_2036_n_fl_r16:     db 0                    ; 1: the result is fl_res16 [2231]
asm_1_2036_n_fl_res16:   dw 0		; Hyp.cls 2232
asm_1_2036_n_fl_slot:    db 0		; Hyp.cls 2233
asm_1_2036_n_fl_exit:		; Hyp.cls 3523
			ret			; end of #asm

asm_1_3529_n:		; #asm, Hyp.cls line 3529 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 3530
            ld sp, (ntc_csp)		; Hyp.cls 3531
            ld bc, (var_hyp_hps)          ; (the buffers: the hypervisor's page) [3532]
            out (c), c		; Hyp.cls 3533
            ld a, (var_hyp_fileshut_slot)		; Hyp.cls 3534
            ld b, a		; Hyp.cls 3535
            ld a, (var_hyp_fin)		; Hyp.cls 3536
            cp b		; Hyp.cls 3537
            jr nz, asm_1_3529_n_fs_out		; Hyp.cls 3538
            xor a		; Hyp.cls 3539
            ld (var_hyp_fin), a		; Hyp.cls 3540
            push bc		; Hyp.cls 3541
            call #BC7A              ; CAS IN CLOSE [3542]
            di		; Hyp.cls 3543
            pop bc		; Hyp.cls 3544
asm_1_3529_n_fs_out:		; Hyp.cls 3545
            ld a, (var_hyp_fout)		; Hyp.cls 3546
            cp b		; Hyp.cls 3547
            jr nz, asm_1_3529_n_fs_done		; Hyp.cls 3548
            xor a		; Hyp.cls 3549
            ld (var_hyp_fout), a		; Hyp.cls 3550
            call #BC8F              ; CAS OUT CLOSE [3551]
            di		; Hyp.cls 3552
asm_1_3529_n_fs_done:		; Hyp.cls 3553
            ld bc, (ntc_rampt)		; Hyp.cls 3554
            out (c), c		; Hyp.cls 3555
            ld sp, (var_hyp_hsp)		; Hyp.cls 3556
			ret			; end of #asm

fn_hyp_usesvc:		; sub usesvc (asm keyword), Hyp.cls line 3575
            ld hl, (ntc_rampt)		; Hyp.cls 3576
            ld (var_hyp_svp), hl		; Hyp.cls 3577
			ret			; end of #asm

asm_1_3589_n:		; #asm, Hyp.cls line 3589 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 3590
            ld sp, (ntc_csp)		; Hyp.cls 3591
            ld (asm_1_3589_n_sv_ix), ix		; Hyp.cls 3592
            ld (asm_1_3589_n_sv_iy), iy		; Hyp.cls 3593
            di		; Hyp.cls 3594
            ld a, (var_hyp_svc_t)		; Hyp.cls 3595
            or a		; Hyp.cls 3596
            jr z, asm_1_3589_n_sv_inst		; Hyp.cls 3597
            ld bc, (var_hyp_svp)		; Hyp.cls 3598
            out (c), c		; Hyp.cls 3599
            call asm_1_3589_n_sv_go              ; (in the service page) A = the answer [3600]
asm_1_3589_n_sv_back:		; Hyp.cls 3601
            di		; Hyp.cls 3602
            ld l, a		; Hyp.cls 3603
            ld h, 0		; Hyp.cls 3604
            ld (var_hyp_svc_svc), hl		; Hyp.cls 3605
            ld bc, (ntc_rampt)      ; the page that was in the window back [3606]
            out (c), c		; Hyp.cls 3607
            ld ix, (asm_1_3589_n_sv_ix)		; Hyp.cls 3608
            ld iy, (asm_1_3589_n_sv_iy)		; Hyp.cls 3609
            ld sp, (var_hyp_hsp)		; Hyp.cls 3610
            jp asm_1_3589_n_sv_exit		; Hyp.cls 3611
asm_1_3589_n_sv_inst:		; Hyp.cls 3612
            ld hl, #6000		; Hyp.cls 3613
asm_1_3589_n_sv_in_lp:		; Hyp.cls 3614
            push hl		; Hyp.cls 3615
            ld bc, #7FC0            ; main RAM's own [3616]
            out (c), c		; Hyp.cls 3617
            ld de, (var_hyp_svc_buf)		; Hyp.cls 3618
            ld bc, 128		; Hyp.cls 3619
            ldir		; Hyp.cls 3620
            ld bc, (var_hyp_svp)		; Hyp.cls 3621
            out (c), c		; Hyp.cls 3622
            pop de		; Hyp.cls 3623
            push de		; Hyp.cls 3624
            ld hl, (var_hyp_svc_buf)		; Hyp.cls 3625
            ld bc, 128		; Hyp.cls 3626
            ldir		; Hyp.cls 3627
            pop hl		; Hyp.cls 3628
            ld bc, 128		; Hyp.cls 3629
            add hl, bc		; Hyp.cls 3630
            ld de, asm_1_3589_n_sv_end		; Hyp.cls 3631
            or a		; Hyp.cls 3632
            sbc hl, de		; Hyp.cls 3633
            add hl, de		; Hyp.cls 3634
            jr c, asm_1_3589_n_sv_in_lp		; Hyp.cls 3635
            xor a		; Hyp.cls 3636
            jr asm_1_3589_n_sv_back		; Hyp.cls 3637
asm_1_3589_n_sv_ix:      dw 0		; Hyp.cls 3638
asm_1_3589_n_sv_iy:      dw 0		; Hyp.cls 3639
; sv_dx - A bytes (1-128) from HL to DE through buf: IX = HL's RAM setting, IY = DE's (0: none -
; main RAM outside the window); the service page back in the window after. HL, DE on past them
asm_1_3589_n_sv_dx:		; Hyp.cls 3642
            ld (asm_1_3589_n_sv_dxn), a		; Hyp.cls 3643
            push de		; Hyp.cls 3644
            ld de, (var_hyp_svc_buf)		; Hyp.cls 3645
            push ix		; Hyp.cls 3646
            pop bc		; Hyp.cls 3647
            inc b		; Hyp.cls 3648
            dec b		; Hyp.cls 3649
            jr z, asm_1_3589_n_sv_dx1		; Hyp.cls 3650
            out (c), c		; Hyp.cls 3651
asm_1_3589_n_sv_dx1:		; Hyp.cls 3652
            ld c, a		; Hyp.cls 3653
            ld b, 0		; Hyp.cls 3654
            ldir		; Hyp.cls 3655
            pop de		; Hyp.cls 3656
            push hl		; Hyp.cls 3657
            push iy		; Hyp.cls 3658
            pop bc		; Hyp.cls 3659
            inc b		; Hyp.cls 3660
            dec b		; Hyp.cls 3661
            jr z, asm_1_3589_n_sv_dx2		; Hyp.cls 3662
            out (c), c		; Hyp.cls 3663
asm_1_3589_n_sv_dx2:		; Hyp.cls 3664
            ld hl, (var_hyp_svc_buf)		; Hyp.cls 3665
            ld a, (asm_1_3589_n_sv_dxn)		; Hyp.cls 3666
            ld c, a		; Hyp.cls 3667
            ld b, 0		; Hyp.cls 3668
            ldir		; Hyp.cls 3669
            pop hl		; Hyp.cls 3670
            ld bc, (var_hyp_svp)		; Hyp.cls 3671
            out (c), c		; Hyp.cls 3672
            ret		; Hyp.cls 3673
asm_1_3589_n_sv_dxn:     db 0		; Hyp.cls 3674
asm_1_3589_n_sv_exit:		; Hyp.cls 4357
			ret			; end of #asm

asm_1_4369_n:		; #asm, Hyp.cls line 4369 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 4370
            ld sp, (ntc_csp)		; Hyp.cls 4371
            ld (asm_1_4369_n_dv_ix), ix		; Hyp.cls 4372
            ld (asm_1_4369_n_dv_iy), iy		; Hyp.cls 4373
            ld hl, 0		; Hyp.cls 4374
            ld (var_hyp_drive_drive), hl		; Hyp.cls 4375
            ld hl, (var_hyp_drive_letter)		; Hyp.cls 4376
            ld (var_hyp_hdr), hl		; Hyp.cls 4377
            IF NTC_ROMLIB = 0		; Hyp.cls 4378
            ld a, (var_hyp_drs + 1)		; Hyp.cls 4379
            or a		; Hyp.cls 4380
            jr z, asm_1_4369_n_dv_rsx		; Hyp.cls 4381
            ld (asm_1_4369_n_dv_blk + 2), hl		; Hyp.cls 4382
            di		; Hyp.cls 4383
            ld bc, (var_hyp_drs)		; Hyp.cls 4384
            out (c), c		; Hyp.cls 4385
            ld ix, asm_1_4369_n_dv_blk		; Hyp.cls 4386
            call #4000		; Hyp.cls 4387
            ld bc, (ntc_rampt)		; Hyp.cls 4388
            out (c), c		; Hyp.cls 4389
            jr nc, asm_1_4369_n_dv_rsx		; Hyp.cls 4390
            ld hl, -1		; Hyp.cls 4391
            ld (var_hyp_drive_drive), hl		; Hyp.cls 4392
            jr asm_1_4369_n_dv_done		; Hyp.cls 4393
asm_1_4369_n_dv_blk:     dw 114, 0, 0, 0, 0, 0, 0		; Hyp.cls 4394
            ENDIF		; Hyp.cls 4395
asm_1_4369_n_dv_rsx:		; Hyp.cls 4396
            ld a, (var_hyp_drive_letter)		; Hyp.cls 4397
            or #80                  ; a one letter command name: its last letter + #80 [4398]
            ld (asm_1_4369_n_dv_nm), a		; Hyp.cls 4399
            ld hl, asm_1_4369_n_dv_nm		; Hyp.cls 4400
            call #BCD4              ; KL FIND COMMAND: carry = found, C = its ROM, HL = its address [4401]
            di		; Hyp.cls 4402
            jr nc, asm_1_4369_n_dv_done		; Hyp.cls 4403
            xor a                   ; no parameters [4404]
            call #001B              ; KL FAR PCALL [4405]
            di		; Hyp.cls 4406
            ld hl, -1		; Hyp.cls 4407
            ld (var_hyp_drive_drive), hl		; Hyp.cls 4408
            jr asm_1_4369_n_dv_done		; Hyp.cls 4409
asm_1_4369_n_dv_nm:      db 0		; Hyp.cls 4410
asm_1_4369_n_dv_ix:      dw 0		; Hyp.cls 4411
asm_1_4369_n_dv_iy:      dw 0		; Hyp.cls 4412
asm_1_4369_n_dv_done:		; Hyp.cls 4413
            ld ix, (asm_1_4369_n_dv_ix)		; Hyp.cls 4414
            ld iy, (asm_1_4369_n_dv_iy)		; Hyp.cls 4415
            ld sp, (var_hyp_hsp)		; Hyp.cls 4416
			ret			; end of #asm

fn_keys_down:		; function down (asm keyword), Keys.cls line 44
            pop hl		; Keys.cls 45
            ld e, (hl)		; Keys.cls 46
            inc hl		; Keys.cls 47
            ld d, (hl)		; Keys.cls 48
            ex de, hl		; Keys.cls 49
            jp ntc_kdown		; Keys.cls 50
			ret			; end of #asm

fn_memory_pages:		; function pages (asm keyword), Memory.cls line 70
            pop hl		; Memory.cls 71
            ld (mem_res), hl		; Memory.cls 72
            ld hl, mem_pages		; Memory.cls 73
            jp mem_go		; Memory.cls 74
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

fn_memory_pagetype:		; function pagetype (asm keyword), Memory.cls line 110
            pop hl		; Memory.cls 111
            ld e, (hl)		; Memory.cls 112
            inc hl		; Memory.cls 113
            ld d, (hl)		; Memory.cls 114
            ld (mem_a1), de		; Memory.cls 115
            pop hl		; Memory.cls 116
            ld (mem_res), hl		; Memory.cls 117
            ld hl, mem_pagetype		; Memory.cls 118
            jp mem_go		; Memory.cls 119
			ret			; end of #asm

fn_memory_tableend:		; function tableend (asm keyword), Memory.cls line 146
            pop hl		; Memory.cls 147
            ld (mem_res), hl		; Memory.cls 148
            ld hl, mem_tableend		; Memory.cls 149
            jp mem_go		; Memory.cls 150
			ret			; end of #asm

fn_memory_top:		; function top (asm keyword), Memory.cls line 176
            pop hl		; Memory.cls 177
            ld (mem_res), hl		; Memory.cls 178
            ld hl, mem_top		; Memory.cls 179
            jp mem_go		; Memory.cls 180
			ret			; end of #asm

fn_memory_map:		; function map (asm keyword), Memory.cls line 196
            pop hl		; Memory.cls 197
            ld e, (hl)		; Memory.cls 198
            inc hl		; Memory.cls 199
            ld d, (hl)		; Memory.cls 200
            ld (mem_a1), de		; Memory.cls 201
            pop hl		; Memory.cls 202
            ld e, (hl)		; Memory.cls 203
            inc hl		; Memory.cls 204
            ld d, (hl)		; Memory.cls 205
            ld (mem_a2), de		; Memory.cls 206
            pop hl		; Memory.cls 207
            ld (mem_res), hl		; Memory.cls 208
            ld hl, mem_map		; Memory.cls 209
            jp mem_go0		; Memory.cls 210
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

fn_memory_freepage:		; function freepage (asm keyword), Memory.cls line 235
            pop hl		; Memory.cls 236
            ld e, (hl)		; Memory.cls 237
            inc hl		; Memory.cls 238
            ld d, (hl)		; Memory.cls 239
            ld (mem_a1), de		; Memory.cls 240
            pop hl		; Memory.cls 241
            ld (mem_res), hl		; Memory.cls 242
            ld hl, mem_freepage		; Memory.cls 243
            jp mem_go		; Memory.cls 244
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

fn_memory_readword:		; function readword (asm keyword), Memory.cls line 373
            pop hl		; Memory.cls 374
            ld (mem_a1), hl		; Memory.cls 375
            pop hl		; Memory.cls 376
            ld (mem_res), hl		; Memory.cls 377
            ld hl, mem_readword		; Memory.cls 378
            jp mem_go		; Memory.cls 379
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


ntc_rg68_e:
			IF ($ < 32768) && (ntc_rg69_e - ntc_rg69 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg69:
; ============================================================
; Variables
; ============================================================

ntc_rg69_e:
			IF ($ < 32768) && (ntc_rg70_e - ntc_rg70 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg70:
var_k:			dw 0
ntc_rg70_e:
			IF ($ < 32768) && (ntc_rg71_e - ntc_rg71 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg71:
var_ns:			dw 0
ntc_rg71_e:
			IF ($ < 32768) && (ntc_rg72_e - ntc_rg72 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg72:
var_i:			dw 0
ntc_rg72_e:
			IF ($ < 32768) && (ntc_rg73_e - ntc_rg73 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg73:
var_hp:			dw 0
ntc_rg73_e:
			IF ($ < 32768) && (ntc_rg74_e - ntc_rg74 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg74:
var_memory_selectpage_selectpage:			dw 0
ntc_rg74_e:
			IF ($ < 32768) && (ntc_rg75_e - ntc_rg75 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg75:
var_front:			dw 0
ntc_rg75_e:
			IF ($ < 32768) && (ntc_rg76_e - ntc_rg76 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg76:
var_dp:			dw 0
ntc_rg76_e:
			IF ($ < 32768) && (ntc_rg77_e - ntc_rg77 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg77:
var_hyp_filecall_filecall:			dw 0
ntc_rg77_e:
			IF ($ < 32768) && (ntc_rg78_e - ntc_rg78 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg78:
var_hyp_svc_svc:			dw 0
ntc_rg78_e:
			IF ($ < 32768) && (ntc_rg79_e - ntc_rg79 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg79:
for3_l:			dw 0
ntc_rg79_e:
			IF ($ < 32768) && (ntc_rg80_e - ntc_rg80 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg80:
var_memory_allocbank_allocbank:			dw 0
ntc_rg80_e:
			IF ($ < 32768) && (ntc_rg81_e - ntc_rg81 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg81:
var_memory_bankpage_bankpage:			dw 0
ntc_rg81_e:
			IF ($ < 32768) && (ntc_rg82_e - ntc_rg82 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg82:
var_hyp_setting_setting:			dw 0
ntc_rg82_e:
			IF ($ < 32768) && (ntc_rg83_e - ntc_rg83 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg83:
			db 82			; capacity
var_ob:			ds 83
ntc_rg83_e:
			IF ($ < 32768) && (ntc_rg84_e - ntc_rg84 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg84:
			db 72			; capacity
var_a:			ds 73
ntc_rg84_e:
			IF ($ < 32768) && (ntc_rg85_e - ntc_rg85 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg85:
var_bd:			dw 0
ntc_rg85_e:
			IF ($ < 32768) && (ntc_rg86_e - ntc_rg86 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg86:
var_probediscs_probediscs:			dw 0
ntc_rg86_e:
			IF ($ < 32768) && (ntc_rg87_e - ntc_rg87 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg87:
var_memory_banks_banks:			dw 0
ntc_rg87_e:
			IF ($ < 32768) && (ntc_rg88_e - ntc_rg88 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg88:
			db 72			; capacity
var_b:			ds 73
ntc_rg88_e:
			IF ($ < 32768) && (ntc_rg89_e - ntc_rg89 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg89:
var_wt:			dw 0
ntc_rg89_e:
			IF ($ < 32768) && (ntc_rg90_e - ntc_rg90 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg90:
var_hk:			dw 0
ntc_rg90_e:
			IF ($ < 32768) && (ntc_rg91_e - ntc_rg91 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg91:
var_hot_take_take:			dw 0
ntc_rg91_e:
			IF ($ < 32768) && (ntc_rg92_e - ntc_rg92 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg92:
var_back:			dw 0
ntc_rg92_e:
			IF ($ < 32768) && (ntc_rg93_e - ntc_rg93 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg93:
var_pk:			dw 0
ntc_rg93_e:
			IF ($ < 32768) && (ntc_rg94_e - ntc_rg94 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg94:
var_hot_control_control:			dw 0
ntc_rg94_e:
			IF ($ < 32768) && (ntc_rg95_e - ntc_rg95 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg95:
var_hot_held_held:			dw 0
ntc_rg95_e:
			IF ($ < 32768) && (ntc_rg96_e - ntc_rg96 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg96:
var_running_running:			dw 0
ntc_rg96_e:
			IF ($ < 32768) && (ntc_rg97_e - ntc_rg97 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg97:
var_td:			dw 0
ntc_rg97_e:
			IF ($ < 32768) && (ntc_rg98_e - ntc_rg98 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg98:
var_quit:			dw 0
ntc_rg98_e:
			IF ($ < 32768) && (ntc_rg99_e - ntc_rg99 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg99:
var_hyp_scr_scr:			dw 0
ntc_rg99_e:
			IF ($ < 32768) && (ntc_rg100_e - ntc_rg100 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg100:
var_runs:			dw 0
ntc_rg100_e:
			IF ($ < 32768) && (ntc_rg101_e - ntc_rg101 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg101:
p_running_rs:			dw 0
ntc_rg101_e:
			IF ($ < 32768) && (ntc_rg102_e - ntc_rg102 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg102:
var_running_j:			dw 0
ntc_rg102_e:
			IF ($ < 32768) && (ntc_rg103_e - ntc_rg103 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg103:
for18_l:			dw 0
ntc_rg103_e:
			IF ($ < 32768) && (ntc_rg104_e - ntc_rg104 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg104:
p_ready_rs:			dw 0
ntc_rg104_e:
			IF ($ < 32768) && (ntc_rg105_e - ntc_rg105 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg105:
var_ready_t:			dw 0
ntc_rg105_e:
			IF ($ < 32768) && (ntc_rg106_e - ntc_rg106 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg106:
var_ready_ready:			dw 0
ntc_rg106_e:
			IF ($ < 32768) && (ntc_rg107_e - ntc_rg107 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg107:
p_runnext_rs:			dw 0
ntc_rg107_e:
			IF ($ < 32768) && (ntc_rg108_e - ntc_rg108 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg108:
var_runnext_n:			dw 0
ntc_rg108_e:
			IF ($ < 32768) && (ntc_rg109_e - ntc_rg109 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg109:
var_runnext_t:			dw 0
ntc_rg109_e:
			IF ($ < 32768) && (ntc_rg110_e - ntc_rg110 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg110:
var_runnext_r:			dw 0
ntc_rg110_e:
			IF ($ < 32768) && (ntc_rg111_e - ntc_rg111 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg111:
var_runnext_c:			dw 0
ntc_rg111_e:
			IF ($ < 32768) && (ntc_rg112_e - ntc_rg112 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg112:
var_runnext_q:			dw 0
ntc_rg112_e:
			IF ($ < 32768) && (ntc_rg113_e - ntc_rg113 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg113:
var_fr:			dw 0
ntc_rg113_e:
			IF ($ < 32768) && (ntc_rg114_e - ntc_rg114 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg114:
for26_l:			dw 0
ntc_rg114_e:
			IF ($ < 32768) && (ntc_rg115_e - ntc_rg115 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg115:
var_cur:			dw 0
ntc_rg115_e:
			IF ($ < 32768) && (ntc_rg116_e - ntc_rg116 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg116:
var_hyp_run_run:			dw 0
ntc_rg116_e:
			IF ($ < 32768) && (ntc_rg117_e - ntc_rg117 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg117:
var_far_far:			dw 0, 0
ntc_rg117_e:
			IF ($ < 32768) && (ntc_rg118_e - ntc_rg118 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg118:
var_memory_readbyte_readbyte:			dw 0
ntc_rg118_e:
			IF ($ < 32768) && (ntc_rg119_e - ntc_rg119 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg119:
var_hyp_count_count:			dw 0
ntc_rg119_e:
			IF ($ < 32768) && (ntc_rg120_e - ntc_rg120 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg120:
var_hyp_fn_fn:			dw 0
ntc_rg120_e:
			IF ($ < 32768) && (ntc_rg121_e - ntc_rg121 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg121:
p_bdos_rs:			dw 0
ntc_rg121_e:
			IF ($ < 32768) && (ntc_rg122_e - ntc_rg122 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg122:
var_bdos_t:			dw 0
ntc_rg122_e:
			IF ($ < 32768) && (ntc_rg123_e - ntc_rg123 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg123:
var_bdos_f:			dw 0
ntc_rg123_e:
			IF ($ < 32768) && (ntc_rg124_e - ntc_rg124 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg124:
var_bdos_e:			dw 0
ntc_rg124_e:
			IF ($ < 32768) && (ntc_rg125_e - ntc_rg125 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg125:
var_bdos_a:			dw 0
ntc_rg125_e:
			IF ($ < 32768) && (ntc_rg126_e - ntc_rg126 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg126:
var_hyp_arg_arg:			dw 0
ntc_rg126_e:
			IF ($ < 32768) && (ntc_rg127_e - ntc_rg127 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg127:
var_bdos___sel42:			dw 0
ntc_rg127_e:
			IF ($ < 32768) && (ntc_rg128_e - ntc_rg128 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg128:
var_ramdisc_ramdisc:			dw 0
ntc_rg128_e:
			IF ($ < 32768) && (ntc_rg129_e - ntc_rg129 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg129:
var_sys_sys:			dw 0
ntc_rg129_e:
			IF ($ < 32768) && (ntc_rg130_e - ntc_rg130 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg130:
p_ramdisc_rs:			dw 0
ntc_rg130_e:
			IF ($ < 32768) && (ntc_rg131_e - ntc_rg131 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg131:
var_ramdisc_t:			dw 0
ntc_rg131_e:
			IF ($ < 32768) && (ntc_rg132_e - ntc_rg132 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg132:
var_ramdisc_p:			dw 0
ntc_rg132_e:
			IF ($ < 32768) && (ntc_rg133_e - ntc_rg133 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg133:
var_ramdisc_g:			dw 0
ntc_rg133_e:
			IF ($ < 32768) && (ntc_rg134_e - ntc_rg134 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg134:
var_ramdisc_o:			dw 0
ntc_rg134_e:
			IF ($ < 32768) && (ntc_rg135_e - ntc_rg135 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg135:
var_ramdisc_f:			dw 0, 0
ntc_rg135_e:
			IF ($ < 32768) && (ntc_rg136_e - ntc_rg136 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg136:
var_memory_readword_readword:			dw 0
ntc_rg136_e:
			IF ($ < 32768) && (ntc_rg137_e - ntc_rg137 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg137:
var_hyp_farptr_farptr:			dw 0, 0
ntc_rg137_e:
			IF ($ < 32768) && (ntc_rg138_e - ntc_rg138 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg138:
var_memory_copy_copy:			dw 0
ntc_rg138_e:
			IF ($ < 32768) && (ntc_rg139_e - ntc_rg139 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg139:
p_storesize_rs:			dw 0
ntc_rg139_e:
			IF ($ < 32768) && (ntc_rg140_e - ntc_rg140 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg140:
var_storesize_t:			dw 0
ntc_rg140_e:
			IF ($ < 32768) && (ntc_rg141_e - ntc_rg141 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg141:
var_storesize_kb:			dw 0
ntc_rg141_e:
			IF ($ < 32768) && (ntc_rg142_e - ntc_rg142 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg142:
var_storesize_storesize:			dw 0
ntc_rg142_e:
			IF ($ < 32768) && (ntc_rg143_e - ntc_rg143 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg143:
var_storesize_n:			dw 0
ntc_rg143_e:
			IF ($ < 32768) && (ntc_rg144_e - ntc_rg144 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg144:
var_storesize_j:			dw 0
ntc_rg144_e:
			IF ($ < 32768) && (ntc_rg145_e - ntc_rg145 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg145:
var_storesize_g:			dw 0
ntc_rg145_e:
			IF ($ < 32768) && (ntc_rg146_e - ntc_rg146 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg146:
var_memory_freepage_freepage:			dw 0
ntc_rg146_e:
			IF ($ < 32768) && (ntc_rg147_e - ntc_rg147 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg147:
p_probediscs_rs:			dw 0
ntc_rg147_e:
			IF ($ < 32768) && (ntc_rg148_e - ntc_rg148 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg148:
var_probediscs_p:			dw 0
ntc_rg148_e:
			IF ($ < 32768) && (ntc_rg149_e - ntc_rg149 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg149:
var_probediscs_su:			dw 0
ntc_rg149_e:
			IF ($ < 32768) && (ntc_rg150_e - ntc_rg150 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg150:
var_probediscs_j:			dw 0
ntc_rg150_e:
			IF ($ < 32768) && (ntc_rg151_e - ntc_rg151 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg151:
var_probediscs_a:			dw 0
ntc_rg151_e:
			IF ($ < 32768) && (ntc_rg152_e - ntc_rg152 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg152:
var_probediscs_pg:			dw 0
ntc_rg152_e:
			IF ($ < 32768) && (ntc_rg153_e - ntc_rg153 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg153:
var_probediscs_r:			dw 0
ntc_rg153_e:
			IF ($ < 32768) && (ntc_rg154_e - ntc_rg154 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg154:
for57_l:			dw 0
ntc_rg154_e:
			IF ($ < 32768) && (ntc_rg155_e - ntc_rg155 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg155:
var_memory_pagetype_pagetype:			dw 0
ntc_rg155_e:
			IF ($ < 32768) && (ntc_rg156_e - ntc_rg156 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg156:
var_hyp_claimpage_claimpage:			dw 0
ntc_rg156_e:
			IF ($ < 32768) && (ntc_rg157_e - ntc_rg157 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg157:
p_storefree_rs:			dw 0
ntc_rg157_e:
			IF ($ < 32768) && (ntc_rg158_e - ntc_rg158 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg158:
var_storefree_t:			dw 0
ntc_rg158_e:
			IF ($ < 32768) && (ntc_rg159_e - ntc_rg159 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg159:
var_storefree_r:			dw 0
ntc_rg159_e:
			IF ($ < 32768) && (ntc_rg160_e - ntc_rg160 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg160:
p_sys_rs:			dw 0
ntc_rg160_e:
			IF ($ < 32768) && (ntc_rg161_e - ntc_rg161 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg161:
var_sys_t:			dw 0
ntc_rg161_e:
			IF ($ < 32768) && (ntc_rg162_e - ntc_rg162 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg162:
var_sys_p:			dw 0
ntc_rg162_e:
			IF ($ < 32768) && (ntc_rg163_e - ntc_rg163 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg163:
var_sys_o:			dw 0
ntc_rg163_e:
			IF ($ < 32768) && (ntc_rg164_e - ntc_rg164 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg164:
var_sys_s:			dw 0
ntc_rg164_e:
			IF ($ < 32768) && (ntc_rg165_e - ntc_rg165 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg165:
var_sys_d:			dw 0
ntc_rg165_e:
			IF ($ < 32768) && (ntc_rg166_e - ntc_rg166 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg166:
var_txs:			dw 0
ntc_rg166_e:
			IF ($ < 32768) && (ntc_rg167_e - ntc_rg167 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg167:
var_memory_tableend_tableend:			dw 0
ntc_rg167_e:
			IF ($ < 32768) && (ntc_rg168_e - ntc_rg168 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg168:
var_memory_top_top:			dw 0
ntc_rg168_e:
			IF ($ < 32768) && (ntc_rg169_e - ntc_rg169 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg169:
var_memory_pages_pages:			dw 0
ntc_rg169_e:
			IF ($ < 32768) && (ntc_rg170_e - ntc_rg170 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg170:
			db 60			; capacity
var_en:			ds 61
ntc_rg170_e:
			IF ($ < 32768) && (ntc_rg171_e - ntc_rg171 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg171:
			db 82			; capacity
var_memory_map_map:			ds 83
ntc_rg171_e:
			IF ($ < 32768) && (ntc_rg172_e - ntc_rg172 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg172:
p_puten_rs:			dw 0
ntc_rg172_e:
			IF ($ < 32768) && (ntc_rg173_e - ntc_rg173 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg173:
var_puten_t:			dw 0
ntc_rg173_e:
			IF ($ < 32768) && (ntc_rg174_e - ntc_rg174 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg174:
var_puten_a:			dw 0
ntc_rg174_e:
			IF ($ < 32768) && (ntc_rg175_e - ntc_rg175 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg175:
var_nearp_nearp:			dw 0, 0
ntc_rg175_e:
			IF ($ < 32768) && (ntc_rg176_e - ntc_rg176 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg176:
p_hopen_rs:			dw 0
ntc_rg176_e:
			IF ($ < 32768) && (ntc_rg177_e - ntc_rg177 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg177:
var_hopen_hopen:			dw 0
ntc_rg177_e:
			IF ($ < 32768) && (ntc_rg178_e - ntc_rg178 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg178:
			db 16			; capacity
var_dn:			ds 17
ntc_rg178_e:
			IF ($ < 32768) && (ntc_rg179_e - ntc_rg179 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg179:
p_hclose_rs:			dw 0
ntc_rg179_e:
			IF ($ < 32768) && (ntc_rg180_e - ntc_rg180 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg180:
var_hclose_r:			dw 0
ntc_rg180_e:
			IF ($ < 32768) && (ntc_rg181_e - ntc_rg181 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg181:
p_filesshut_rs:			dw 0
ntc_rg181_e:
			IF ($ < 32768) && (ntc_rg182_e - ntc_rg182 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg182:
var_filesshut_t:			dw 0
ntc_rg182_e:
			IF ($ < 32768) && (ntc_rg183_e - ntc_rg183 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg183:
p_collected_rs:			dw 0
ntc_rg183_e:
			IF ($ < 32768) && (ntc_rg184_e - ntc_rg184 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg184:
var_collected_t:			dw 0
ntc_rg184_e:
			IF ($ < 32768) && (ntc_rg185_e - ntc_rg185 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg185:
var_collected_n:			dw 0
ntc_rg185_e:
			IF ($ < 32768) && (ntc_rg186_e - ntc_rg186 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg186:
p_puts_rs:			dw 0
ntc_rg186_e:
			IF ($ < 32768) && (ntc_rg187_e - ntc_rg187 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg187:
var_puts_t:			dw 0
ntc_rg187_e:
			IF ($ < 32768) && (ntc_rg188_e - ntc_rg188 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg188:
			db 82			; capacity
var_puts_s:			ds 83
ntc_rg188_e:
			IF ($ < 32768) && (ntc_rg189_e - ntc_rg189 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg189:
p_putln_rs:			dw 0
ntc_rg189_e:
			IF ($ < 32768) && (ntc_rg190_e - ntc_rg190 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg190:
var_putln_t:			dw 0
ntc_rg190_e:
			IF ($ < 32768) && (ntc_rg191_e - ntc_rg191 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg191:
			db 82			; capacity
var_putln_s:			ds 83
ntc_rg191_e:
			IF ($ < 32768) && (ntc_rg192_e - ntc_rg192 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg192:
p_putc_rs:			dw 0
ntc_rg192_e:
			IF ($ < 32768) && (ntc_rg193_e - ntc_rg193 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg193:
var_putc_t:			dw 0
ntc_rg193_e:
			IF ($ < 32768) && (ntc_rg194_e - ntc_rg194 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg194:
var_putc_c:			dw 0
ntc_rg194_e:
			IF ($ < 32768) && (ntc_rg195_e - ntc_rg195 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg195:
p_nearp_rs:			dw 0
ntc_rg195_e:
			IF ($ < 32768) && (ntc_rg196_e - ntc_rg196 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg196:
var_nearp_p:			dw 0
ntc_rg196_e:
			IF ($ < 32768) && (ntc_rg197_e - ntc_rg197 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg197:
p_far_rs:			dw 0
ntc_rg197_e:
			IF ($ < 32768) && (ntc_rg198_e - ntc_rg198 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg198:
var_far_t:			dw 0
ntc_rg198_e:
			IF ($ < 32768) && (ntc_rg199_e - ntc_rg199 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg199:
var_far_a:			dw 0
ntc_rg199_e:
			IF ($ < 32768) && (ntc_rg200_e - ntc_rg200 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg200:
p_clst_rs:			dw 0
ntc_rg200_e:
			IF ($ < 32768) && (ntc_rg201_e - ntc_rg201 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg201:
var_clst_t:			dw 0
ntc_rg201_e:
			IF ($ < 32768) && (ntc_rg202_e - ntc_rg202 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg202:
p_tofront_rs:			dw 0
ntc_rg202_e:
			IF ($ < 32768) && (ntc_rg203_e - ntc_rg203 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg203:
var_tofront_t:			dw 0
ntc_rg203_e:
			IF ($ < 32768) && (ntc_rg204_e - ntc_rg204 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg204:
var_tofront_r:			dw 0
ntc_rg204_e:
			IF ($ < 32768) && (ntc_rg205_e - ntc_rg205 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg205:
p_setmode_rs:			dw 0
ntc_rg205_e:
			IF ($ < 32768) && (ntc_rg206_e - ntc_rg206 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg206:
var_setmode_t:			dw 0
ntc_rg206_e:
			IF ($ < 32768) && (ntc_rg207_e - ntc_rg207 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg207:
var_setmode_m:			dw 0
ntc_rg207_e:
			IF ($ < 32768) && (ntc_rg208_e - ntc_rg208 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg208:
var_setmode_r:			dw 0
ntc_rg208_e:
			IF ($ < 32768) && (ntc_rg209_e - ntc_rg209 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg209:
			db 82			; capacity
var_n_n:			ds 83
ntc_rg209_e:
			IF ($ < 32768) && (ntc_rg210_e - ntc_rg210 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg210:
p_showtop_rs:			dw 0
ntc_rg210_e:
			IF ($ < 32768) && (ntc_rg211_e - ntc_rg211 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg211:
var_showtop_j:			dw 0
ntc_rg211_e:
			IF ($ < 32768) && (ntc_rg212_e - ntc_rg212 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg212:
p_toplines_rs:			dw 0
ntc_rg212_e:
			IF ($ < 32768) && (ntc_rg213_e - ntc_rg213 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg213:
var_toplines_mark:			dw 0
ntc_rg213_e:
			IF ($ < 32768) && (ntc_rg214_e - ntc_rg214 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg214:
var_toplines_keys:			dw 0
ntc_rg214_e:
			IF ($ < 32768) && (ntc_rg215_e - ntc_rg215 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg215:
var_toplines_j:			dw 0
ntc_rg215_e:
			IF ($ < 32768) && (ntc_rg216_e - ntc_rg216 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg216:
			db 14			; capacity
var_toplines_s:			ds 15
ntc_rg216_e:
			IF ($ < 32768) && (ntc_rg217_e - ntc_rg217 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg217:
var_txn:			dw 0
ntc_rg217_e:
			IF ($ < 32768) && (ntc_rg218_e - ntc_rg218 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg218:
			db 82			; capacity
var_sk_sk:			ds 83
ntc_rg218_e:
			IF ($ < 32768) && (ntc_rg219_e - ntc_rg219 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg219:
for83_l:			dw 0
ntc_rg219_e:
			IF ($ < 32768) && (ntc_rg220_e - ntc_rg220 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg220:
var_ld:			dw 0
ntc_rg220_e:
			IF ($ < 32768) && (ntc_rg221_e - ntc_rg221 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg221:
var_rate_rate:			dw 0
ntc_rg221_e:
			IF ($ < 32768) && (ntc_rg222_e - ntc_rg222 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg222:
			db 82			; capacity
var_pad_pad:			ds 83
ntc_rg222_e:
			IF ($ < 32768) && (ntc_rg223_e - ntc_rg223 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg223:
p_totals_rs:			dw 0
ntc_rg223_e:
			IF ($ < 32768) && (ntc_rg224_e - ntc_rg224 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg224:
var_memory_ramsize_ramsize:			dw 0
ntc_rg224_e:
			IF ($ < 32768) && (ntc_rg225_e - ntc_rg225 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg225:
var_memory_freepages_freepages:			dw 0
ntc_rg225_e:
			IF ($ < 32768) && (ntc_rg226_e - ntc_rg226 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg226:
p_topadd_rs:			dw 0
ntc_rg226_e:
			IF ($ < 32768) && (ntc_rg227_e - ntc_rg227 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg227:
			db 82			; capacity
var_topadd_s:			ds 83
ntc_rg227_e:
			IF ($ < 32768) && (ntc_rg228_e - ntc_rg228 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg228:
p_roll_rs:			dw 0
ntc_rg228_e:
			IF ($ < 32768) && (ntc_rg229_e - ntc_rg229 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg229:
var_roll_j:			dw 0
ntc_rg229_e:
			IF ($ < 32768) && (ntc_rg230_e - ntc_rg230 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg230:
for88_l:			dw 0
ntc_rg230_e:
			IF ($ < 32768) && (ntc_rg231_e - ntc_rg231 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg231:
p_pad_rs:			dw 0
ntc_rg231_e:
			IF ($ < 32768) && (ntc_rg232_e - ntc_rg232 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg232:
var_pad_v:			dw 0
ntc_rg232_e:
			IF ($ < 32768) && (ntc_rg233_e - ntc_rg233 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg233:
p_rate_rs:			dw 0
ntc_rg233_e:
			IF ($ < 32768) && (ntc_rg234_e - ntc_rg234 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg234:
var_rate_n:			dw 0
ntc_rg234_e:
			IF ($ < 32768) && (ntc_rg235_e - ntc_rg235 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg235:
var_rate_d:			dw 0
ntc_rg235_e:
			IF ($ < 32768) && (ntc_rg236_e - ntc_rg236 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg236:
p_install_rs:			dw 0
ntc_rg236_e:
			IF ($ < 32768) && (ntc_rg237_e - ntc_rg237 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg237:
var_install_t:			dw 0
ntc_rg237_e:
			IF ($ < 32768) && (ntc_rg238_e - ntc_rg238 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg238:
var_install_p:			dw 0
ntc_rg238_e:
			IF ($ < 32768) && (ntc_rg239_e - ntc_rg239 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg239:
var_install_n:			dw 0
ntc_rg239_e:
			IF ($ < 32768) && (ntc_rg240_e - ntc_rg240 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg240:
p_resetslot_rs:			dw 0
ntc_rg240_e:
			IF ($ < 32768) && (ntc_rg241_e - ntc_rg241 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg241:
var_resetslot_s:			dw 0
ntc_rg241_e:
			IF ($ < 32768) && (ntc_rg242_e - ntc_rg242 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg242:
p_openslot_rs:			dw 0
ntc_rg242_e:
			IF ($ < 32768) && (ntc_rg243_e - ntc_rg243 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg243:
var_openslot_t:			dw 0
ntc_rg243_e:
			IF ($ < 32768) && (ntc_rg244_e - ntc_rg244 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg244:
p_sk_rs:			dw 0
ntc_rg244_e:
			IF ($ < 32768) && (ntc_rg245_e - ntc_rg245 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg245:
p_getnm_rs:			dw 0
ntc_rg245_e:
			IF ($ < 32768) && (ntc_rg246_e - ntc_rg246 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg246:
var_getnm_t:			dw 0
ntc_rg246_e:
			IF ($ < 32768) && (ntc_rg247_e - ntc_rg247 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg247:
var_getnm_n:			dw 0
ntc_rg247_e:
			IF ($ < 32768) && (ntc_rg248_e - ntc_rg248 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg248:
p_n_rs:			dw 0
ntc_rg248_e:
			IF ($ < 32768) && (ntc_rg249_e - ntc_rg249 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg249:
var_n_v:			dw 0
ntc_rg249_e:
			IF ($ < 32768) && (ntc_rg250_e - ntc_rg250 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg250:
p_prompt_rs:			dw 0
ntc_rg250_e:
			IF ($ < 32768) && (ntc_rg251_e - ntc_rg251 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg251:
var_prompt_t:			dw 0
ntc_rg251_e:
			IF ($ < 32768) && (ntc_rg252_e - ntc_rg252 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg252:
p_keyin_rs:			dw 0
ntc_rg252_e:
			IF ($ < 32768) && (ntc_rg253_e - ntc_rg253 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg253:
var_keyin_k:			dw 0
ntc_rg253_e:
			IF ($ < 32768) && (ntc_rg254_e - ntc_rg254 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg254:
var_keyin_t:			dw 0
ntc_rg254_e:
			IF ($ < 32768) && (ntc_rg255_e - ntc_rg255 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg255:
var_keyin_n:			dw 0
ntc_rg255_e:
			IF ($ < 32768) && (ntc_rg256_e - ntc_rg256 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg256:
p_command_rs:			dw 0
ntc_rg256_e:
			IF ($ < 32768) && (ntc_rg257_e - ntc_rg257 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg257:
var_command_t:			dw 0
ntc_rg257_e:
			IF ($ < 32768) && (ntc_rg258_e - ntc_rg258 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg258:
			db 72			; capacity
var_command_c:			ds 73
ntc_rg258_e:
			IF ($ < 32768) && (ntc_rg259_e - ntc_rg259 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg259:
var_command_p:			dw 0
ntc_rg259_e:
			IF ($ < 32768) && (ntc_rg260_e - ntc_rg260 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg260:
var_command_s:			dw 0
ntc_rg260_e:
			IF ($ < 32768) && (ntc_rg261_e - ntc_rg261 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg261:
			db 82			; capacity
var_command___sel103:			ds 83
ntc_rg261_e:
			IF ($ < 32768) && (ntc_rg262_e - ntc_rg262 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg262:
var_bare:			dw 0
ntc_rg262_e:
			IF ($ < 32768) && (ntc_rg263_e - ntc_rg263 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg263:
p_starttask_rs:			dw 0
ntc_rg263_e:
			IF ($ < 32768) && (ntc_rg264_e - ntc_rg264 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg264:
var_starttask_t:			dw 0
ntc_rg264_e:
			IF ($ < 32768) && (ntc_rg265_e - ntc_rg265 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg265:
var_starttask_s:			dw 0
ntc_rg265_e:
			IF ($ < 32768) && (ntc_rg266_e - ntc_rg266 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg266:
var_starttask_h:			dw 0
ntc_rg266_e:
			IF ($ < 32768) && (ntc_rg267_e - ntc_rg267 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg267:
var_starttask_n:			dw 0
ntc_rg267_e:
			IF ($ < 32768) && (ntc_rg268_e - ntc_rg268 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg268:
var_starttask_rest:			dw 0
ntc_rg268_e:
			IF ($ < 32768) && (ntc_rg269_e - ntc_rg269 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg269:
var_starttask_com:			dw 0
ntc_rg269_e:
			IF ($ < 32768) && (ntc_rg270_e - ntc_rg270 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg270:
			db 72			; capacity
var_starttask_w:			ds 73
ntc_rg270_e:
			IF ($ < 32768) && (ntc_rg271_e - ntc_rg271 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg271:
var_starttask_d:			dw 0
ntc_rg271_e:
			IF ($ < 32768) && (ntc_rg272_e - ntc_rg272 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg272:
var_hyp_drive_drive:			dw 0
ntc_rg272_e:
			IF ($ < 32768) && (ntc_rg273_e - ntc_rg273 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg273:
var_hyp_info_info:			dw 0
ntc_rg273_e:
			IF ($ < 32768) && (ntc_rg274_e - ntc_rg274 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg274:
p_notfound_rs:			dw 0
ntc_rg274_e:
			IF ($ < 32768) && (ntc_rg275_e - ntc_rg275 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg275:
var_notfound_t:			dw 0
ntc_rg275_e:
			IF ($ < 32768) && (ntc_rg276_e - ntc_rg276 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg276:
p_owndrive_rs:			dw 0
ntc_rg276_e:
			IF ($ < 32768) && (ntc_rg277_e - ntc_rg277 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg277:
var_owndrive_t:			dw 0
ntc_rg277_e:
			IF ($ < 32768) && (ntc_rg278_e - ntc_rg278 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg278:
var_owndrive_r:			dw 0
ntc_rg278_e:
			IF ($ < 32768) && (ntc_rg279_e - ntc_rg279 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg279:
p_endtask_rs:			dw 0
ntc_rg279_e:
			IF ($ < 32768) && (ntc_rg280_e - ntc_rg280 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg280:
var_endtask_t:			dw 0
ntc_rg280_e:
			IF ($ < 32768) && (ntc_rg281_e - ntc_rg281 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg281:
var_endtask_c:			dw 0
ntc_rg281_e:
			IF ($ < 32768) && (ntc_rg282_e - ntc_rg282 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg282:
var_hyp_hps:			dw 0
ntc_rg282_e:
			IF ($ < 32768) && (ntc_rg283_e - ntc_rg283 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg283:
p_hyp_usedriver_rs:			dw 0
ntc_rg283_e:
			IF ($ < 32768) && (ntc_rg284_e - ntc_rg284 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg284:
var_hyp_usedriver_b:			dw 0
ntc_rg284_e:
			IF ($ < 32768) && (ntc_rg285_e - ntc_rg285 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg285:
var_hyp_dxb:			dw 0
ntc_rg285_e:
			IF ($ < 32768) && (ntc_rg286_e - ntc_rg286 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg286:
var_hyp_drs:			dw 0
ntc_rg286_e:
			IF ($ < 32768) && (ntc_rg287_e - ntc_rg287 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg287:
p_hyp_claimpage_rs:			dw 0
ntc_rg287_e:
			IF ($ < 32768) && (ntc_rg288_e - ntc_rg288 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg288:
var_hyp_claimpage_page:			dw 0
ntc_rg288_e:
			IF ($ < 32768) && (ntc_rg289_e - ntc_rg289 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg289:
var_hyp_hsp:			dw 0
ntc_rg289_e:
			IF ($ < 32768) && (ntc_rg290_e - ntc_rg290 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg290:
p_hyp_con_rs:			dw 0
ntc_rg290_e:
			IF ($ < 32768) && (ntc_rg291_e - ntc_rg291 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg291:
var_hyp_con_pg:			dw 0
ntc_rg291_e:
			IF ($ < 32768) && (ntc_rg292_e - ntc_rg292 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg292:
var_hyp_con_src:			dw 0
ntc_rg292_e:
			IF ($ < 32768) && (ntc_rg293_e - ntc_rg293 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg293:
var_hyp_con_n:			dw 0
ntc_rg293_e:
			IF ($ < 32768) && (ntc_rg294_e - ntc_rg294 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg294:
var_hyp_con_front:			dw 0
ntc_rg294_e:
			IF ($ < 32768) && (ntc_rg295_e - ntc_rg295 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg295:
var_hyp_sco:			dw 0
ntc_rg295_e:
			IF ($ < 32768) && (ntc_rg296_e - ntc_rg296 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg296:
var_hyp_scc:			dw 0
ntc_rg296_e:
			IF ($ < 32768) && (ntc_rg297_e - ntc_rg297 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg297:
var_hyp_pon:			dw 0
ntc_rg297_e:
			IF ($ < 32768) && (ntc_rg298_e - ntc_rg298 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg298:
p_hyp_say_rs:			dw 0
ntc_rg298_e:
			IF ($ < 32768) && (ntc_rg299_e - ntc_rg299 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg299:
var_hyp_say_p:			dw 0
ntc_rg299_e:
			IF ($ < 32768) && (ntc_rg300_e - ntc_rg300 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg300:
var_hyp_say_n:			dw 0
ntc_rg300_e:
			IF ($ < 32768) && (ntc_rg301_e - ntc_rg301 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg301:
var_hyp_say_col:			dw 0
ntc_rg301_e:
			IF ($ < 32768) && (ntc_rg302_e - ntc_rg302 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg302:
var_hyp_say_row:			dw 0
ntc_rg302_e:
			IF ($ < 32768) && (ntc_rg303_e - ntc_rg303 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg303:
p_hyp_scr_rs:			dw 0
ntc_rg303_e:
			IF ($ < 32768) && (ntc_rg304_e - ntc_rg304 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg304:
var_hyp_scr_m:			dw 0
ntc_rg304_e:
			IF ($ < 32768) && (ntc_rg305_e - ntc_rg305 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg305:
var_hyp_scr_k:			dw 0
ntc_rg305_e:
			IF ($ < 32768) && (ntc_rg306_e - ntc_rg306 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg306:
var_hyp_scw:			dw 0
ntc_rg306_e:
			IF ($ < 32768) && (ntc_rg307_e - ntc_rg307 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg307:
p_hyp_keyrep_rs:			dw 0
ntc_rg307_e:
			IF ($ < 32768) && (ntc_rg308_e - ntc_rg308 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg308:
var_hyp_keyrep_f:			dw 0
ntc_rg308_e:
			IF ($ < 32768) && (ntc_rg309_e - ntc_rg309 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg309:
p_hyp_show_rs:			dw 0
ntc_rg309_e:
			IF ($ < 32768) && (ntc_rg310_e - ntc_rg310 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg310:
var_hyp_show_pg:			dw 0
ntc_rg310_e:
			IF ($ < 32768) && (ntc_rg311_e - ntc_rg311 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg311:
p_hyp_reply_rs:			dw 0
ntc_rg311_e:
			IF ($ < 32768) && (ntc_rg312_e - ntc_rg312 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg312:
var_hyp_reply_a:			dw 0
ntc_rg312_e:
			IF ($ < 32768) && (ntc_rg313_e - ntc_rg313 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg313:
var_hyp_reply_hl:			dw 0
ntc_rg313_e:
			IF ($ < 32768) && (ntc_rg314_e - ntc_rg314 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg314:
var_hyp_ra:			dw 0
ntc_rg314_e:
			IF ($ < 32768) && (ntc_rg315_e - ntc_rg315 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg315:
var_hyp_rhl:			dw 0
ntc_rg315_e:
			IF ($ < 32768) && (ntc_rg316_e - ntc_rg316 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg316:
p_hyp_fn_rs:			dw 0
ntc_rg316_e:
			IF ($ < 32768) && (ntc_rg317_e - ntc_rg317 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg317:
var_hyp_rfn:			dw 0
ntc_rg317_e:
			IF ($ < 32768) && (ntc_rg318_e - ntc_rg318 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg318:
p_hyp_arg_rs:			dw 0
ntc_rg318_e:
			IF ($ < 32768) && (ntc_rg319_e - ntc_rg319 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg319:
var_hyp_rde:			dw 0
ntc_rg319_e:
			IF ($ < 32768) && (ntc_rg320_e - ntc_rg320 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg320:
p_hyp_count_rs:			dw 0
ntc_rg320_e:
			IF ($ < 32768) && (ntc_rg321_e - ntc_rg321 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg321:
var_hyp_rcnt:			dw 0
ntc_rg321_e:
			IF ($ < 32768) && (ntc_rg322_e - ntc_rg322 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg322:
p_hyp_run_rs:			dw 0
ntc_rg322_e:
			IF ($ < 32768) && (ntc_rg323_e - ntc_rg323 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg323:
var_hyp_run_setting:			dw 0
ntc_rg323_e:
			IF ($ < 32768) && (ntc_rg324_e - ntc_rg324 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg324:
var_hyp_sps:			dw 0
ntc_rg324_e:
			IF ($ < 32768) && (ntc_rg325_e - ntc_rg325 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg325:
var_hyp_rrom:			dw 0
ntc_rg325_e:
			IF ($ < 32768) && (ntc_rg326_e - ntc_rg326 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg326:
var_hyp_slc:			dw 0
ntc_rg326_e:
			IF ($ < 32768) && (ntc_rg327_e - ntc_rg327 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg327:
var_hyp_rclr:			dw 0
ntc_rg327_e:
			IF ($ < 32768) && (ntc_rg328_e - ntc_rg328 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg328:
p_hyp_vdu_rs:			dw 0
ntc_rg328_e:
			IF ($ < 32768) && (ntc_rg329_e - ntc_rg329 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg329:
var_hyp_vdu_on:			dw 0
ntc_rg329_e:
			IF ($ < 32768) && (ntc_rg330_e - ntc_rg330 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg330:
p_hyp_filecall_rs:			dw 0
ntc_rg330_e:
			IF ($ < 32768) && (ntc_rg331_e - ntc_rg331 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg331:
var_hyp_filecall_f:			dw 0
ntc_rg331_e:
			IF ($ < 32768) && (ntc_rg332_e - ntc_rg332 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg332:
var_hyp_filecall_fcb:			dw 0
ntc_rg332_e:
			IF ($ < 32768) && (ntc_rg333_e - ntc_rg333 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg333:
var_hyp_filecall_slot:			dw 0
ntc_rg333_e:
			IF ($ < 32768) && (ntc_rg334_e - ntc_rg334 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg334:
var_hyp_filecall_setting:			dw 0
ntc_rg334_e:
			IF ($ < 32768) && (ntc_rg335_e - ntc_rg335 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg335:
var_hyp_filecall_dma:			dw 0
ntc_rg335_e:
			IF ($ < 32768) && (ntc_rg336_e - ntc_rg336 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg336:
var_hyp_filecall_drive:			dw 0
ntc_rg336_e:
			IF ($ < 32768) && (ntc_rg337_e - ntc_rg337 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg337:
var_hyp_filecall_buf:			dw 0
ntc_rg337_e:
			IF ($ < 32768) && (ntc_rg338_e - ntc_rg338 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg338:
var_hyp_hdr:			dw 0
ntc_rg338_e:
			IF ($ < 32768) && (ntc_rg339_e - ntc_rg339 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg339:
var_hyp_fin:			dw 0
ntc_rg339_e:
			IF ($ < 32768) && (ntc_rg340_e - ntc_rg340 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg340:
var_hyp_fout:			dw 0
ntc_rg340_e:
			IF ($ < 32768) && (ntc_rg341_e - ntc_rg341 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg341:
p_hyp_fileshut_rs:			dw 0
ntc_rg341_e:
			IF ($ < 32768) && (ntc_rg342_e - ntc_rg342 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg342:
var_hyp_fileshut_slot:			dw 0
ntc_rg342_e:
			IF ($ < 32768) && (ntc_rg343_e - ntc_rg343 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg343:
var_hyp_svp:			dw 0
ntc_rg343_e:
			IF ($ < 32768) && (ntc_rg344_e - ntc_rg344 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg344:
p_hyp_svcvars_rs:			dw 0
ntc_rg344_e:
			IF ($ < 32768) && (ntc_rg345_e - ntc_rg345 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg345:
var_hyp_svcvars_vst:			dw 0
ntc_rg345_e:
			IF ($ < 32768) && (ntc_rg346_e - ntc_rg346 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg346:
var_hyp_svcvars_vsg:			dw 0
ntc_rg346_e:
			IF ($ < 32768) && (ntc_rg347_e - ntc_rg347 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg347:
var_hyp_svcvars_vns:			dw 0
ntc_rg347_e:
			IF ($ < 32768) && (ntc_rg348_e - ntc_rg348 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg348:
var_hyp_svcvars_vfr:			dw 0
ntc_rg348_e:
			IF ($ < 32768) && (ntc_rg349_e - ntc_rg349 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg349:
var_hyp_svcvars_vdp:			dw 0
ntc_rg349_e:
			IF ($ < 32768) && (ntc_rg350_e - ntc_rg350 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg350:
var_hyp_svst:			dw 0
ntc_rg350_e:
			IF ($ < 32768) && (ntc_rg351_e - ntc_rg351 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg351:
var_hyp_svsg:			dw 0
ntc_rg351_e:
			IF ($ < 32768) && (ntc_rg352_e - ntc_rg352 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg352:
var_hyp_svns:			dw 0
ntc_rg352_e:
			IF ($ < 32768) && (ntc_rg353_e - ntc_rg353 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg353:
var_hyp_svfr:			dw 0
ntc_rg353_e:
			IF ($ < 32768) && (ntc_rg354_e - ntc_rg354 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg354:
var_hyp_svdp:			dw 0
ntc_rg354_e:
			IF ($ < 32768) && (ntc_rg355_e - ntc_rg355 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg355:
p_hyp_svc_rs:			dw 0
ntc_rg355_e:
			IF ($ < 32768) && (ntc_rg356_e - ntc_rg356 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg356:
var_hyp_svc_t:			dw 0
ntc_rg356_e:
			IF ($ < 32768) && (ntc_rg357_e - ntc_rg357 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg357:
var_hyp_svc_p:			dw 0
ntc_rg357_e:
			IF ($ < 32768) && (ntc_rg358_e - ntc_rg358 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg358:
var_hyp_svc_setting:			dw 0
ntc_rg358_e:
			IF ($ < 32768) && (ntc_rg359_e - ntc_rg359 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg359:
var_hyp_svc_buf:			dw 0
ntc_rg359_e:
			IF ($ < 32768) && (ntc_rg360_e - ntc_rg360 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg360:
var_hyp_pox:			dw 0
ntc_rg360_e:
			IF ($ < 32768) && (ntc_rg361_e - ntc_rg361 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg361:
var_hyp_poy:			dw 0
ntc_rg361_e:
			IF ($ < 32768) && (ntc_rg362_e - ntc_rg362 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg362:
p_hyp_drive_rs:			dw 0
ntc_rg362_e:
			IF ($ < 32768) && (ntc_rg363_e - ntc_rg363 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg363:
var_hyp_drive_letter:			dw 0
ntc_rg363_e:
			IF ($ < 32768) && (ntc_rg364_e - ntc_rg364 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg364:
p_hot_slots_rs:			dw 0
ntc_rg364_e:
			IF ($ < 32768) && (ntc_rg365_e - ntc_rg365 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg365:
var_hot_slots_n:			dw 0
ntc_rg365_e:
			IF ($ < 32768) && (ntc_rg366_e - ntc_rg366 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg366:
var_hot_ns:			dw 0
ntc_rg366_e:
			IF ($ < 32768) && (ntc_rg367_e - ntc_rg367 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg367:
p_hot_tick_rs:			dw 0
ntc_rg367_e:
			IF ($ < 32768) && (ntc_rg368_e - ntc_rg368 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg368:
var_hot_tick_k:			dw 0
ntc_rg368_e:
			IF ($ < 32768) && (ntc_rg369_e - ntc_rg369 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg369:
var_hot_ctl:			dw 0
ntc_rg369_e:
			IF ($ < 32768) && (ntc_rg370_e - ntc_rg370 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg370:
var_keys_down_down:			dw 0
ntc_rg370_e:
			IF ($ < 32768) && (ntc_rg371_e - ntc_rg371 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg371:
var_hot_last:			dw 0
ntc_rg371_e:
			IF ($ < 32768) && (ntc_rg372_e - ntc_rg372 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg372:
var_hot_one:			dw 0
ntc_rg372_e:
			IF ($ < 32768) && (ntc_rg373_e - ntc_rg373 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg373:
var_hot_pend:			dw 0
ntc_rg373_e:
			IF ($ < 32768) && (ntc_rg374_e - ntc_rg374 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg374:
var_hot_age:			dw 0
ntc_rg374_e:
			IF ($ < 32768) && (ntc_rg375_e - ntc_rg375 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg375:
p_hot_take_rs:			dw 0
ntc_rg375_e:
			IF ($ < 32768) && (ntc_rg376_e - ntc_rg376 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg376:
p_hot_control_rs:			dw 0
ntc_rg376_e:
			IF ($ < 32768) && (ntc_rg377_e - ntc_rg377 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg377:
p_hot_held_rs:			dw 0
ntc_rg377_e:
			IF ($ < 32768) && (ntc_rg378_e - ntc_rg378 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg378:
p_memory_bankpage_rs:			dw 0
ntc_rg378_e:
			IF ($ < 32768) && (ntc_rg379_e - ntc_rg379 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg379:
var_memory_bankpage_bank:			dw 0
ntc_rg379_e:
			IF ($ < 32768) && (ntc_rg380_e - ntc_rg380 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg380:
var_memory_bankpage_n:			dw 0
ntc_rg380_e:
			IF ($ < 32768) && (ntc_rg381_e - ntc_rg381 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg381:
tmp0:			dw 0
ntc_rg381_e:
			IF ($ < 32768) && (ntc_rg382_e - ntc_rg382 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg382:
tmp1:			dw 0
ntc_rg382_e:
			IF ($ < 32768) && (ntc_rg383_e - ntc_rg383 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg383:
tmp2:			dw 0
ntc_rg383_e:
			IF ($ < 32768) && (ntc_rg384_e - ntc_rg384 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg384:
tmp3:			dw 0
ntc_rg384_e:
			IF ($ < 32768) && (ntc_rg385_e - ntc_rg385 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg385:
tmp4:			dw 0
ntc_rg385_e:
			IF ($ < 32768) && (ntc_rg386_e - ntc_rg386 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg386:
tmp5:			dw 0
ntc_rg386_e:
			IF ($ < 32768) && (ntc_rg387_e - ntc_rg387 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg387:
tmp6:			dw 0
ntc_rg387_e:
			IF ($ < 32768) && (ntc_rg388_e - ntc_rg388 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg388:
tmp7:			dw 0
ntc_rg388_e:
			IF ($ < 32768) && (ntc_rg389_e - ntc_rg389 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg389:
			db 82			; capacity
stmp0:			ds 83
ntc_rg389_e:
			IF ($ < 32768) && (ntc_rg390_e - ntc_rg390 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg390:
			db 82			; capacity
stmp1:			ds 83
ntc_rg390_e:
			IF ($ < 32768) && (ntc_rg391_e - ntc_rg391 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg391:
			db 82			; capacity
stmp2:			ds 83
ntc_rg391_e:
			IF ($ < 32768) && (ntc_rg392_e - ntc_rg392 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg392:
			db 82			; capacity
stmp3:			ds 83
ntc_rg392_e:
			IF ($ < 32768) && (ntc_rg393_e - ntc_rg393 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg393:
ltmp0:			dw 0, 0
ntc_rg393_e:
			IF ($ < 32768) && (ntc_rg394_e - ntc_rg394 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg394:
ltmp1:			dw 0, 0
ntc_rg394_e:
			IF ($ < 32768) && (ntc_rg395_e - ntc_rg395 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg395:
ltmp2:			dw 0, 0

; numbers passed by address (read only)
ntc_rg395_e:
			IF ($ < 32768) && (ntc_rg396_e - ntc_rg396 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg396:
lit_0:			dw 0
ntc_rg396_e:
			IF ($ < 32768) && (ntc_rg397_e - ntc_rg397 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg397:
lit_1:			dw 1
ntc_rg397_e:
			IF ($ < 32768) && (ntc_rg398_e - ntc_rg398 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg398:
lit_85:			dw 85
ntc_rg398_e:
			IF ($ < 32768) && (ntc_rg399_e - ntc_rg399 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg399:
vp_arr_st:			dw arr_st
ntc_rg399_e:
			IF ($ < 32768) && (ntc_rg400_e - ntc_rg400 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg400:
vp_arr_sg:			dw arr_sg
ntc_rg400_e:
			IF ($ < 32768) && (ntc_rg401_e - ntc_rg401 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg401:
vp_var_ns:			dw var_ns
ntc_rg401_e:
			IF ($ < 32768) && (ntc_rg402_e - ntc_rg402 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg402:
vp_var_front:			dw var_front
ntc_rg402_e:
			IF ($ < 32768) && (ntc_rg403_e - ntc_rg403 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg403:
vp_var_dp:			dw var_dp
ntc_rg403_e:
			IF ($ < 32768) && (ntc_rg404_e - ntc_rg404 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg404:
vp_arr_rb:			dw arr_rb
ntc_rg404_e:
			IF ($ < 32768) && (ntc_rg405_e - ntc_rg405 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg405:
lit_99:			dw 99
ntc_rg405_e:
			IF ($ < 32768) && (ntc_rg406_e - ntc_rg406 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg406:
lit_82:			dw 82
ntc_rg406_e:
			IF ($ < 32768) && (ntc_rg407_e - ntc_rg407 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg407:
lit_255:			dw 255
ntc_rg407_e:
			IF ($ < 32768) && (ntc_rg408_e - ntc_rg408 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg408:
lit_2:			dw 2
ntc_rg408_e:
			IF ($ < 32768) && (ntc_rg409_e - ntc_rg409 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg409:
lit_m2431:			dw -2431
ntc_rg409_e:
			IF ($ < 32768) && (ntc_rg410_e - ntc_rg410 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg410:
lit_110:			dw 110
ntc_rg410_e:
			IF ($ < 32768) && (ntc_rg411_e - ntc_rg411 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg411:
lit_116:			dw 116
ntc_rg411_e:
			IF ($ < 32768) && (ntc_rg412_e - ntc_rg412 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg412:
lit_m2423:			dw -2423
ntc_rg412_e:
			IF ($ < 32768) && (ntc_rg413_e - ntc_rg413 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg413:
lit_32:			dw 32
ntc_rg413_e:
			IF ($ < 32768) && (ntc_rg414_e - ntc_rg414 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg414:
vp_var_en:			dw var_en
ntc_rg414_e:
			IF ($ < 32768) && (ntc_rg415_e - ntc_rg415 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg415:
vp_var_dn:			dw var_dn
ntc_rg415_e:
			IF ($ < 32768) && (ntc_rg416_e - ntc_rg416 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg416:
lit_100:			dw 100
ntc_rg416_e:
			IF ($ < 32768) && (ntc_rg417_e - ntc_rg417 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg417:
lit_101:			dw 101
ntc_rg417_e:
			IF ($ < 32768) && (ntc_rg418_e - ntc_rg418 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg418:
lit_102:			dw 102
ntc_rg418_e:
			IF ($ < 32768) && (ntc_rg419_e - ntc_rg419 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg419:
vp_var_puts_s:			dw var_puts_s
ntc_rg419_e:
			IF ($ < 32768) && (ntc_rg420_e - ntc_rg420 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg420:
vp_var_putc_c:			dw var_putc_c
ntc_rg420_e:
			IF ($ < 32768) && (ntc_rg421_e - ntc_rg421 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg421:
llit_65536:			dw 0, 1
ntc_rg421_e:
			IF ($ < 32768) && (ntc_rg422_e - ntc_rg422 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg422:
lit_m2425:			dw -2425
ntc_rg422_e:
			IF ($ < 32768) && (ntc_rg423_e - ntc_rg423 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg423:
lit_m2424:			dw -2424
ntc_rg423_e:
			IF ($ < 32768) && (ntc_rg424_e - ntc_rg424 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg424:
lit_4:			dw 4
ntc_rg424_e:
			IF ($ < 32768) && (ntc_rg425_e - ntc_rg425 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg425:
lit_m2422:			dw -2422
ntc_rg425_e:
			IF ($ < 32768) && (ntc_rg426_e - ntc_rg426 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg426:
lit_15:			dw 15
ntc_rg426_e:
			IF ($ < 32768) && (ntc_rg427_e - ntc_rg427 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg427:
lit_13:			dw 13
ntc_rg427_e:
			IF ($ < 32768) && (ntc_rg428_e - ntc_rg428 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg428:
vp_var_topadd_s:			dw var_topadd_s
ntc_rg428_e:
			IF ($ < 32768) && (ntc_rg429_e - ntc_rg429 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg429:
lit_9:			dw 9
ntc_rg429_e:
			IF ($ < 32768) && (ntc_rg430_e - ntc_rg430 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg430:
lit_3:			dw 3
ntc_rg430_e:
			IF ($ < 32768) && (ntc_rg431_e - ntc_rg431 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg431:
lit_m4352:			dw -4352
ntc_rg431_e:
			IF ($ < 32768) && (ntc_rg432_e - ntc_rg432 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg432:
lit_4096:			dw 4096
ntc_rg432_e:
			IF ($ < 32768) && (ntc_rg433_e - ntc_rg433 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg433:
lit_m3328:			dw -3328
ntc_rg433_e:
			IF ($ < 32768) && (ntc_rg434_e - ntc_rg434 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg434:
lit_768:			dw 768
ntc_rg434_e:
			IF ($ < 32768) && (ntc_rg435_e - ntc_rg435 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg435:
lit_m2432:			dw -2432
ntc_rg435_e:
			IF ($ < 32768) && (ntc_rg436_e - ntc_rg436 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg436:
lit_m2344:			dw -2344
ntc_rg436_e:
			IF ($ < 32768) && (ntc_rg437_e - ntc_rg437 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg437:
lit_12:			dw 12
ntc_rg437_e:
			IF ($ < 32768) && (ntc_rg438_e - ntc_rg438 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg438:
lit_m2343:			dw -2343
ntc_rg438_e:
			IF ($ < 32768) && (ntc_rg439_e - ntc_rg439 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg439:
lit_m2417:			dw -2417
ntc_rg439_e:
			IF ($ < 32768) && (ntc_rg440_e - ntc_rg440 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg440:
lit_8:			dw 8
ntc_rg440_e:
			IF ($ < 32768) && (ntc_rg441_e - ntc_rg441 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg441:
lit_m2416:			dw -2416
ntc_rg441_e:
			IF ($ < 32768) && (ntc_rg442_e - ntc_rg442 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg442:
vp_var_ob:			dw var_ob
ntc_rg442_e:
			IF ($ < 32768) && (ntc_rg443_e - ntc_rg443 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg443:
lit_90:			dw 90
ntc_rg443_e:
			IF ($ < 32768) && (ntc_rg444_e - ntc_rg444 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg444:
lit_103:			dw 103
ntc_rg444_e:
			IF ($ < 32768) && (ntc_rg445_e - ntc_rg445 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg445:
lit_256:			dw 256
ntc_rg445_e:
			IF ($ < 32768) && (ntc_rg446_e - ntc_rg446 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg446:
lit_m3332:			dw -3332
ntc_rg446_e:
			IF ($ < 32768) && (ntc_rg447_e - ntc_rg447 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg447:
lit_m3330:			dw -3330
ntc_rg447_e:
			IF ($ < 32768) && (ntc_rg448_e - ntc_rg448 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg448:
lit_m2:			dw -2
ntc_rg448_e:
			IF ($ < 32768) && (ntc_rg449_e - ntc_rg449 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg449:
lit_128:			dw 128
ntc_rg449_e:
			IF ($ < 32768) && (ntc_rg450_e - ntc_rg450 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg450:
vp_var_b:			dw var_b
ntc_rg450_e:
			IF ($ < 32768) && (ntc_rg451_e - ntc_rg451 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg451:
lit_129:			dw 129
ntc_rg451_e:
			IF ($ < 32768) && (ntc_rg452_e - ntc_rg452 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg452:
vp_var_a:			dw var_a
ntc_rg452_e:
			IF ($ < 32768) && (ntc_rg453_e - ntc_rg453 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg453:
lit_m2427:			dw -2427
ntc_rg453_e:
			IF ($ < 32768) && (ntc_rg454_e - ntc_rg454 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg454:
lit_m1:			dw -1
ntc_rg454_e:
			IF ($ < 32768) && (ntc_rg455_e - ntc_rg455 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg455:
lit_23:			dw 23
ntc_rg455_e:
			IF ($ < 32768) && (ntc_rg456_e - ntc_rg456 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg456:
lit_64:			dw 64
ntc_rg456_e:
			IF ($ < 32768) && (ntc_rg457_e - ntc_rg457 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg457:
lit_65:			dw 65
ntc_rg457_e:
			IF ($ < 32768) && (ntc_rg458_e - ntc_rg458 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg458:
lit_57:			dw 57
ntc_rg458_e:
			IF ($ < 32768) && (ntc_rg459_e - ntc_rg459 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg459:
lit_56:			dw 56
ntc_rg459_e:
			IF ($ < 32768) && (ntc_rg460_e - ntc_rg460 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg460:
lit_49:			dw 49
ntc_rg460_e:
			IF ($ < 32768) && (ntc_rg461_e - ntc_rg461 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg461:
lit_48:			dw 48
ntc_rg461_e:
			IF ($ < 32768) && (ntc_rg462_e - ntc_rg462 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg462:
lit_41:			dw 41
ntc_rg462_e:
			IF ($ < 32768) && (ntc_rg463_e - ntc_rg463 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg463:
lit_40:			dw 40
ntc_rg463_e:
			IF ($ < 32768) && (ntc_rg464_e - ntc_rg464 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg464:
lit_33:			dw 33
ntc_rg464_e:
			IF ($ < 32768) && (ntc_rg465_e - ntc_rg465 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg465:
lit_66:			dw 66

ntc_rg465_e:
			IF ($ < 32768) && (ntc_rg466_e - ntc_rg466 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg466:
; ============================================================
; Strings
; ============================================================

ntc_rg466_e:
			IF ($ < 32768) && (ntc_rg467_e - ntc_rg467 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg467:
str0:			db "CyborgOS needs 320K (a 256K expansion) or more", 0
ntc_rg467_e:
			IF ($ < 32768) && (ntc_rg468_e - ntc_rg468 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg468:
str1:			db "Press a key", 0
ntc_rg468_e:
			IF ($ < 32768) && (ntc_rg469_e - ntc_rg469 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg469:
str2:			db 0
ntc_rg469_e:
			IF ($ < 32768) && (ntc_rg470_e - ntc_rg470 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg470:
str3:			db " KEYREP ", 0
ntc_rg470_e:
			IF ($ < 32768) && (ntc_rg471_e - ntc_rg471 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg471:
str4:			db "RAMDISC", 0
ntc_rg471_e:
			IF ($ < 32768) && (ntc_rg472_e - ntc_rg472 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg472:
str5:			db "Z SYSTEM ", 0
ntc_rg472_e:
			IF ($ < 32768) && (ntc_rg473_e - ntc_rg473 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg473:
str6:			db "CyborgOS ended, ", 0
ntc_rg473_e:
			IF ($ < 32768) && (ntc_rg474_e - ntc_rg474 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg474:
str7:			db " programs ran", 0
ntc_rg474_e:
			IF ($ < 32768) && (ntc_rg475_e - ntc_rg475 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg475:
str8:			db 13, 0
ntc_rg475_e:
			IF ($ < 32768) && (ntc_rg476_e - ntc_rg476 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg476:
str9:			db 10, 0
ntc_rg476_e:
			IF ($ < 32768) && (ntc_rg477_e - ntc_rg477 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg477:
str10:			db 27, 0
ntc_rg477_e:
			IF ($ < 32768) && (ntc_rg478_e - ntc_rg478 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg478:
str11:			db "E", 0
ntc_rg478_e:
			IF ($ < 32768) && (ntc_rg479_e - ntc_rg479 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg479:
str12:			db "[", 0
ntc_rg479_e:
			IF ($ < 32768) && (ntc_rg480_e - ntc_rg480 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg480:
str13:			db "]   ", 0
ntc_rg480_e:
			IF ($ < 32768) && (ntc_rg481_e - ntc_rg481 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg481:
str14:			db "CyborgOS TOP", 0
ntc_rg481_e:
			IF ($ < 32768) && (ntc_rg482_e - ntc_rg482 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg482:
str15:			db "Control + ESC: back, ", 0
ntc_rg482_e:
			IF ($ < 32768) && (ntc_rg483_e - ntc_rg483 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg483:
str16:			db ": that slot", 0
ntc_rg483_e:
			IF ($ < 32768) && (ntc_rg484_e - ntc_rg484 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg484:
str17:			db "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (last second)", 0
ntc_rg484_e:
			IF ($ < 32768) && (ntc_rg485_e - ntc_rg485 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg485:
str18:			db "-", 0
ntc_rg485_e:
			IF ($ < 32768) && (ntc_rg486_e - ntc_rg486 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg486:
str19:			db "command line", 0
ntc_rg486_e:
			IF ($ < 32768) && (ntc_rg487_e - ntc_rg487 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg487:
str20:			db "waiting (key)", 0
ntc_rg487_e:
			IF ($ < 32768) && (ntc_rg488_e - ntc_rg488 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg488:
str21:			db "running", 0
ntc_rg488_e:
			IF ($ < 32768) && (ntc_rg489_e - ntc_rg489 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg489:
str22:			db " ", 0
ntc_rg489_e:
			IF ($ < 32768) && (ntc_rg490_e - ntc_rg490 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg490:
str23:			db "*", 0
ntc_rg490_e:
			IF ($ < 32768) && (ntc_rg491_e - ntc_rg491 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg491:
str24:			db "  ", 0
ntc_rg491_e:
			IF ($ < 32768) && (ntc_rg492_e - ntc_rg492 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg492:
str25:			db "Total memory: ", 0
ntc_rg492_e:
			IF ($ < 32768) && (ntc_rg493_e - ntc_rg493 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg493:
str26:			db " KB   Free memory: ", 0
ntc_rg493_e:
			IF ($ < 32768) && (ntc_rg494_e - ntc_rg494 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg494:
str27:			db " KB", 0
ntc_rg494_e:
			IF ($ < 32768) && (ntc_rg495_e - ntc_rg495 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg495:
str28:			db "CyborgOS slot ", 0
ntc_rg495_e:
			IF ($ < 32768) && (ntc_rg496_e - ntc_rg496 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg496:
str29:			db " of ", 0
ntc_rg496_e:
			IF ($ < 32768) && (ntc_rg497_e - ntc_rg497 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg497:
str30:			db " - ", 0
ntc_rg497_e:
			IF ($ < 32768) && (ntc_rg498_e - ntc_rg498 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg498:
str31:			db ", Control + ESC TOP, HELP", 0
ntc_rg498_e:
			IF ($ < 32768) && (ntc_rg499_e - ntc_rg499 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg499:
str32:			db "Control + 1-", 0
ntc_rg499_e:
			IF ($ < 32768) && (ntc_rg500_e - ntc_rg500 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg500:
str33:			db "Control + 1-9, 0", 0
ntc_rg500_e:
			IF ($ < 32768) && (ntc_rg501_e - ntc_rg501 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg501:
str34:			db "Control + 1-9, 0 (twice 11-", 0
ntc_rg501_e:
			IF ($ < 32768) && (ntc_rg502_e - ntc_rg502 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg502:
str35:			db ")", 0
ntc_rg502_e:
			IF ($ < 32768) && (ntc_rg503_e - ntc_rg503 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg503:
str36:			db "> ", 0
ntc_rg503_e:
			IF ($ < 32768) && (ntc_rg504_e - ntc_rg504 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg504:
str37:			db ":", 0
ntc_rg504_e:
			IF ($ < 32768) && (ntc_rg505_e - ntc_rg505 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg505:
str38:			db "CD", 0
ntc_rg505_e:
			IF ($ < 32768) && (ntc_rg506_e - ntc_rg506 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg506:
str39:			db "CLS", 0
ntc_rg506_e:
			IF ($ < 32768) && (ntc_rg507_e - ntc_rg507 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg507:
str40:			db "RUN", 0
ntc_rg507_e:
			IF ($ < 32768) && (ntc_rg508_e - ntc_rg508 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg508:
str41:			db "no slot", 0
ntc_rg508_e:
			IF ($ < 32768) && (ntc_rg509_e - ntc_rg509 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg509:
str42:			db "slot", 0
ntc_rg509_e:
			IF ($ < 32768) && (ntc_rg510_e - ntc_rg510 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg510:
str43:			db " is busy", 0
ntc_rg510_e:
			IF ($ < 32768) && (ntc_rg511_e - ntc_rg511 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg511:
str44:			db "QUIT", 0
ntc_rg511_e:
			IF ($ < 32768) && (ntc_rg512_e - ntc_rg512 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg512:
str45:			db "RUN what?", 0
ntc_rg512_e:
			IF ($ < 32768) && (ntc_rg513_e - ntc_rg513 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg513:
str46:			db ".", 0
ntc_rg513_e:
			IF ($ < 32768) && (ntc_rg514_e - ntc_rg514 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg514:
str47:			db ".CYB", 0
ntc_rg514_e:
			IF ($ < 32768) && (ntc_rg515_e - ntc_rg515 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg515:
str48:			db ".COM", 0
ntc_rg515_e:
			IF ($ < 32768) && (ntc_rg516_e - ntc_rg516 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg516:
str49:			db "RUN ", 0
ntc_rg516_e:
			IF ($ < 32768) && (ntc_rg517_e - ntc_rg517 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg517:
str50:			db " runs in slot", 0
ntc_rg517_e:
			IF ($ < 32768) && (ntc_rg518_e - ntc_rg518 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg518:
str51:			db "? ", 0
ntc_rg518_e:
			IF ($ < 32768) && (ntc_rg519_e - ntc_rg519 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg519:
str52:			db " (HELP)", 0
ntc_rg519_e:
			IF ($ < 32768) && (ntc_rg520_e - ntc_rg520 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg520:
str53:			db ": not found", 0
ntc_rg520_e:
			IF ($ < 32768) && (ntc_rg521_e - ntc_rg521 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg521:
str54:			db " ended]", 0

ntc_rg521_e:
			IF ($ < 32768) && (ntc_rg522_e - ntc_rg522 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg522:
; ============================================================
; Keyword library (used)
; ============================================================

ntc_rg522_e:
			IF ($ < 32768) && (ntc_rg523_e - ntc_rg523 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg523:
;## ntc_data @shared ntc_d_nmode
; ------------------------------------------------------------
; Scratch space: the core every program has (with ntc_d_nmode). The rest of
; the run time's variables are @data sections, each linked only when a
; linked section's code names one of its labels (no header lists them).
; They stay in this order: the keyword ROM's registry keeps each variable's
; address (a Library: ROM program has them as fixed addresses)
; ------------------------------------------------------------
ntc_next:		ret				; IX target that continues the thread
ntc_csp:		dw 0			; caller SP, for kw_stop (and the normal mode stack)
ntc_ip:			dw 0			; normal mode: thread position while out of the thread

ntc_rg523_e:
			IF ($ < 32768) && (ntc_rg524_e - ntc_rg524 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg524:
;## ntc_d_gnlo @data
ntc_gnlo:		db 0			; ntc_getn: low byte

ntc_rg524_e:
			IF ($ < 32768) && (ntc_rg525_e - ntc_rg525 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg525:
;## ntc_d_nmode @data
ntc_nmode:		db 0			; 1 = running in normal mode (waits let interrupts in)

ntc_rg525_e:
			IF ($ < 32768) && (ntc_rg526_e - ntc_rg526 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg526:
;## ntc_d_div @data
ntc_mode:		db 0			; div mode 0=quotient 1=remainder
ntc_sgnq:		db 0			; quotient sign (bit 7)
ntc_sgnr:		db 0			; remainder sign (bit 7)

ntc_rg526_e:
			IF ($ < 32768) && (ntc_rg527_e - ntc_rg527 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg527:
;## ntc_d_lead @data
ntc_lead:		db 0			; printint: digit seen

ntc_rg527_e:
			IF ($ < 32768) && (ntc_rg528_e - ntc_rg528 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg528:
;## ntc_d_sptr @data
ntc_sptr:		dw 0			; printbuf: text pointer

ntc_rg528_e:
			IF ($ < 32768) && (ntc_rg529_e - ntc_rg529 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg529:
;## ntc_d_iptr @data
ntc_iptr:		dw 0			; gets: buffer pointer
ntc_ilink:		dw 0			; gets: where to go when done

ntc_rg529_e:
			IF ($ < 32768) && (ntc_rg530_e - ntc_rg530 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg530:
;## ntc_d_ivar @data
ntc_ivar:		dw 0			; inputint / inkey: dest var

ntc_rg530_e:
			IF ($ < 32768) && (ntc_rg531_e - ntc_rg531 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg531:
;## ntc_d_aptr @data
ntc_aptr:		dw 0			; atoi: text pointer

ntc_rg531_e:
			IF ($ < 32768) && (ntc_rg532_e - ntc_rg532 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg532:
;## ntc_d_hook @data
ntc_hookon:		db 0			; 1 = the Interrupt hook may run (set, and not running now)
ntc_hookset:	db 0			; 1 = an Interrupt hook is set
ntc_hookpend:	db 0			; 1 = an interrupt came, the hook runs at the next safe point
ntc_hook:		dw 0			; the hook Sub's call stub

ntc_rg532_e:
			IF ($ < 32768) && (ntc_rg533_e - ntc_rg533 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg533:
;## ntc_d_hostix @data
ntc_hostix:		dw 0			; host platforms: IX kept over a firmware / BDOS call

ntc_rg533_e:
			IF ($ < 32768) && (ntc_rg534_e - ntc_rg534 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg534:
;## ntc_d_rampt @data
ntc_rampt:		dw #7FC0		; the gate array's RAM setting now (B = port, C = value): the
								; Memory class keeps it, Graphics puts it back after drawing

ntc_rg534_e:
			IF ($ < 32768) && (ntc_rg535_e - ntc_rg535 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg535:
;## ntc_d_numbuf @data
ntc_numbuf:		ds 14			; printint / long print: digits (+ spaces for Option VBPrint)

ntc_rg535_e:
			IF ($ < 32768) && (ntc_rg536_e - ntc_rg536 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg536:
;## ntc_d_inbuf @data
				db 40			; ntc_inbuf's capacity (as every string variable has)
ntc_inbuf:		ds 41			; inputint: typed text

ntc_rg536_e:
			IF ($ < 32768) && (ntc_rg537_e - ntc_rg537 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg537:
;## kw_stop ntc_data ntc_plat_exit @shared
kw_stop:
			ld ix, ntc_stop_back
			jp ntc_plat_exit
ntc_stop_back:
			ld sp, (ntc_csp)
			ei
			ret

ntc_rg537_e:
			IF ($ < 32768) && (ntc_rg538_e - ntc_rg538 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg538:
;## kw_waitkey ntc_data ntc_plat_key
; kw_waitkey - wait for a key (Option PressAnyKeyOnEnd, before kw_stop)
kw_waitkey:
			ld ix, ntc_next
			jp ntc_plat_getkey

ntc_rg538_e:
			IF ($ < 32768) && (ntc_rg539_e - ntc_rg539 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg539:
;## ntc_xnh ntc_data ntc_islots @shared
; ntc_xn for a program with an Interrupt hook (Interrupt MySub) or interrupt
; classes (Option Class Interrupt): the same window, then a pending hook
; runs as a call of the hook Sub from this point (its return goes back into
; the thread), else a due class's Tick (not one still running). Flags are
; kept when nothing runs. Linked instead of ntc_xn.
ntc_xn:
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			nop					; an interrupt can be taken here
			di
			push af
			ld a, (ntc_hookpend)
			or a
			jr nz, ntc_xn_hookp
			ld a, (ntc_isldue)
			or a
			jr nz, ntc_xn_isl
ntc_xn_none:
			pop af
			ld sp, (ntc_ip)
			ret
ntc_xn_isl:
			ld hl, ntc_isl + 4		; the first slot due and not running
			ld a, (ntc_isln)
			ld b, a
			ld c, 0					; due but still running: stays due
ntc_xi_lp:
			ld a, (hl)
			or a
			jr nz, ntc_xi_skip
			inc hl
			ld a, (hl)
			dec hl
			or a
			jr nz, ntc_xi_run
ntc_xi_skip:
			inc hl
			ld a, (hl)
			dec hl
			or c
			ld c, a
			ld de, 8
			add hl, de
			djnz ntc_xi_lp
			ld a, c
			ld (ntc_isldue), a
			jr ntc_xn_none
ntc_xi_run:
			ld (hl), 1				; running (its return stub clears it)
			inc hl
			ld (hl), 0				; not due
			inc hl
			ld e, (hl)				; Tick's call stub
			inc hl
			ld d, (hl)
			pop af
			ld sp, (ntc_ip)
			ex de, hl
			jp (hl)
ntc_xn_hookp:
			pop af
ntc_xn_hook:
			xor a
			ld (ntc_hookpend), a
			ld (ntc_hookon), a	; not again until the hook returns
			ld sp, (ntc_ip)
			ld hl, (ntc_hook)
			jp (hl)

ntc_rg539_e:
			IF ($ < 32768) && (ntc_rg540_e - ntc_rg540 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg540:
;## kw_goto_iffalse (normal mode copy)
;kw_goto_iffalse, <label>  - branch if NZ (false)
kw_goto_iffalse_n:
			pop hl
			jp z, ntc_xn
			ld sp, hl
			jp ntc_xn

ntc_rg540_e:
			IF ($ < 32768) && (ntc_rg541_e - ntc_rg541 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg541:
;## kw_goto_iftrue (normal mode copy)
;kw_goto_iftrue, <label>  - branch if Z (true)
kw_goto_iftrue_n:
			pop hl
			jp nz, ntc_xn
			ld sp, hl
			jp ntc_xn

ntc_rg541_e:
			IF ($ < 32768) && (ntc_rg542_e - ntc_rg542 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg542:
;## kw_goto_ifzero (normal mode copy)
;kw_goto_ifzero, <var>, <label>  - branch if var = 0
kw_goto_ifzero_n:
			pop hl
			ld a, (hl)
			inc hl
			or (hl)
			pop hl
			jp nz, ntc_xn
			ld sp, hl
			jp ntc_xn

ntc_rg542_e:
			IF ($ < 32768) && (ntc_rg543_e - ntc_rg543 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg543:
;## ntc_for_jump (normal mode copy)
; tails for the FOR / NEXT keywords. DE = var value, HL = limit,
; SP = thread at the label word. Signed compare by flipping bit 15.
; ntc_for_gt: jump to the label if var > limit, else skip it
ntc_for_gt_n:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			or a
			sbc hl, de			; limit - var, carry = var > limit
			pop hl
			jp nc, ntc_xn
			ld sp, hl
			jp ntc_xn
; ntc_for_lt: jump to the label if var < limit, else skip it
ntc_for_lt_n:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			ex de, hl
			or a
			sbc hl, de			; var - limit, carry = var < limit
			pop hl
			jp nc, ntc_xn
			ld sp, hl
			jp ntc_xn
; ntc_for_le: jump to the label if var <= limit (loop again). A not 0: the
; step took var past 32767 (or -32768): the loop ends (ntc_for_ge too)
ntc_for_le_n:
			or a
			jr nz, ntc_for_end_n
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			or a
			sbc hl, de			; limit - var, no carry = var <= limit
			pop hl
			jp c, ntc_xn
			ld sp, hl
			jp ntc_xn
; ntc_for_ge: jump to the label if var >= limit (loop again)
ntc_for_ge_n:
			or a
			jr nz, ntc_for_end_n
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
			ex de, hl
			or a
			sbc hl, de			; var - limit, no carry = var >= limit
			pop hl
			jp c, ntc_xn
			ld sp, hl
			jp ntc_xn
ntc_for_end_n:
			pop hl
			jp ntc_xn

ntc_rg543_e:
			IF ($ < 32768) && (ntc_rg544_e - ntc_rg544 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg544:
;## kw_forupv (normal mode copy) ntc_for_jump
;kw_forupv, <var>, <limit var>, <endlabel>
kw_forupv_n:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_for_gt_n

ntc_rg544_e:
			IF ($ < 32768) && (ntc_rg545_e - ntc_rg545 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg545:
;## kw_next1l (normal mode copy) ntc_for_jump
;kw_next1l, <var>, <literal limit>, <toplabel>
;  NEXT for STEP 1: inc var, back to the top while var <= limit
kw_next1l_n:
			pop hl
			inc (hl)
			ld e, (hl)
			inc hl
			jr nz, ntc_n1l_nc_n
			inc (hl)
ntc_n1l_nc_n:
			ld d, (hl)
			pop hl
			ld a, d					; A = #FF when it went past 32767 (#8000)
			xor #80
			or e
			sub 1
			sbc a, a
			jp ntc_for_le_n

ntc_rg545_e:
			IF ($ < 32768) && (ntc_rg546_e - ntc_rg546 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg546:
;## kw_next1v (normal mode copy) ntc_for_jump
;kw_next1v, <var>, <limit var>, <toplabel>
kw_next1v_n:
			pop hl
			inc (hl)
			ld e, (hl)
			inc hl
			jr nz, ntc_n1v_nc_n
			inc (hl)
ntc_n1v_nc_n:
			ld d, (hl)
			pop hl
			ld c, (hl)
			inc hl
			ld h, (hl)
			ld l, c
			ld a, d					; A = #FF when it went past 32767 (#8000)
			xor #80
			or e
			sub 1
			sbc a, a
			jp ntc_for_le_n

ntc_rg546_e:
			IF ($ < 32768) && (ntc_rg547_e - ntc_rg547 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg547:
;## kw_ltov
;kw_ltov, <literal>, <destvar>
kw_ltov:
			pop de
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg547_e:
			IF ($ < 32768) && (ntc_rg548_e - ntc_rg548 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg548:
;## kw_vtov
;kw_vtov, <sourcevar>, <destvar>
kw_vtov:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg548_e:
			IF ($ < 32768) && (ntc_rg549_e - ntc_rg549 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg549:
;## kw_ztov
;kw_ztov, <destvar>
kw_ztov:
			xor a
			pop hl
			ld (hl), a
			inc hl
			ld (hl), a
			ret

ntc_rg549_e:
			IF ($ < 32768) && (ntc_rg550_e - ntc_rg550 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg550:
;## kw_ftov
;kw_ftov, <destvar>  - Z flag to var: true = -1, false = 0
kw_ftov:
			pop hl
			jr z, ntc_ftov_t
			ld (hl), 0
			inc hl
			ld (hl), 0
			ret
ntc_ftov_t:
			ld (hl), #ff
			inc hl
			ld (hl), #ff
			ret

; ============================================================
; Arithmetic
; ============================================================

ntc_rg550_e:
			IF ($ < 32768) && (ntc_rg551_e - ntc_rg551 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg551:
;## kw_inc
;kw_inc, <var>
kw_inc:
			pop hl
			inc (hl)
			ret nz
			inc hl
			inc (hl)
			ret

ntc_rg551_e:
			IF ($ < 32768) && (ntc_rg552_e - ntc_rg552 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg552:
;## kw_add
;kw_add, <var1>, <var2>, <destvar>
kw_add:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, de
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg552_e:
			IF ($ < 32768) && (ntc_rg553_e - ntc_rg553 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg553:
;## kw_addl
;kw_addl, <var>, <literal>, <destvar>
kw_addl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			add hl, de
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg553_e:
			IF ($ < 32768) && (ntc_rg554_e - ntc_rg554 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg554:
;## kw_subvv
;kw_subvv, <var1>, <var2>, <destvar>  - var1 - var2
kw_subvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ex de, hl
			or a
			sbc hl, de
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg554_e:
			IF ($ < 32768) && (ntc_rg555_e - ntc_rg555 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg555:
;## kw_4x
;kw_4x, <var>, <destvar>
kw_4x:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, hl
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg555_e:
			IF ($ < 32768) && (ntc_rg556_e - ntc_rg556 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg556:
;## ntc_mul
; BC * DE -> pop destvar, store. Low 16 bits (same signed/unsigned)
ntc_mul:
			ld hl, 0
			ld a, 16
ntc_mul_loop:
			add hl, hl
			sla e
			rl d
			jr nc, ntc_mul_skip
			add hl, bc
ntc_mul_skip:
			dec a
			jr nz, ntc_mul_loop
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg556_e:
			IF ($ < 32768) && (ntc_rg557_e - ntc_rg557 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg557:
;## kw_mulvl ntc_mul
;kw_mulvl, <var>, <literal>, <destvar>
kw_mulvl:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop de
			jp ntc_mul

ntc_rg557_e:
			IF ($ < 32768) && (ntc_rg558_e - ntc_rg558 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg558:
;## ntc_div ntc_data
; HL / DE signed, truncating. (ntc_mode) 0 = quotient, 1 = remainder.
; Remainder takes the dividend's sign. Divide by zero gives
; quotient 0, remainder = dividend. Pops destvar and stores.
ntc_div:
			ld a, d
			or e
			jr nz, ntc_div_nz
			ld a, (ntc_mode)
			or a
			jr nz, ntc_div_store
			ld hl, 0
			jr ntc_div_store
ntc_div_nz:
			ld a, h
			ld (ntc_sgnr), a
			xor d
			ld (ntc_sgnq), a
			bit 7, h
			jr z, ntc_div_hpos
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
ntc_div_hpos:
			bit 7, d
			jr z, ntc_div_dpos
			xor a
			sub e
			ld e, a
			sbc a, a
			sub d
			ld d, a
ntc_div_dpos:
			ld a, h
			ld c, l
			ld hl, 0
			ld b, 16
ntc_div_loop:
			sla c
			rla
			adc hl, hl
			sbc hl, de
			jr nc, ntc_div_one
			add hl, de
			djnz ntc_div_loop
			jr ntc_div_done
ntc_div_one:
			inc c
			djnz ntc_div_loop
ntc_div_done:
			ld b, a
			ld a, (ntc_mode)
			or a
			jr z, ntc_div_q
			ld a, (ntc_sgnr)
			jr ntc_div_sign
ntc_div_q:
			ld h, b
			ld l, c
			ld a, (ntc_sgnq)
ntc_div_sign:
			rla
			jr nc, ntc_div_store
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
ntc_div_store:
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg558_e:
			IF ($ < 32768) && (ntc_rg559_e - ntc_rg559 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg559:
;## kw_divvv ntc_div
;kw_divvv, <var1>, <var2>, <destvar>  - var1 / var2
kw_divvv:
			xor a
			ld (ntc_mode), a
ntc_divvv:
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld h, b
			ld l, c
			jp ntc_div

ntc_rg559_e:
			IF ($ < 32768) && (ntc_rg560_e - ntc_rg560 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg560:
;## kw_divvl ntc_div
;kw_divvl, <var>, <literal>, <destvar>
kw_divvl:
			xor a
			ld (ntc_mode), a
ntc_divvl:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			pop de
			jp ntc_div

ntc_rg560_e:
			IF ($ < 32768) && (ntc_rg561_e - ntc_rg561 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg561:
;## kw_andvv
;kw_andvv, <var1>, <var2>, <destvar>
kw_andvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			and e
			ld e, a
			inc hl
			ld a, (hl)
			and d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg561_e:
			IF ($ < 32768) && (ntc_rg562_e - ntc_rg562 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg562:
;## kw_andvl
;kw_andvl, <var>, <literal>, <destvar>
kw_andvl:
			pop hl
			pop de
			ld a, (hl)
			and e
			ld e, a
			inc hl
			ld a, (hl)
			and d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg562_e:
			IF ($ < 32768) && (ntc_rg563_e - ntc_rg563 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg563:
;## kw_orvv
;kw_orvv, <var1>, <var2>, <destvar>
kw_orvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			or e
			ld e, a
			inc hl
			ld a, (hl)
			or d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg563_e:
			IF ($ < 32768) && (ntc_rg564_e - ntc_rg564 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg564:
;## kw_orvl
;kw_orvl, <var>, <literal>, <destvar>
kw_orvl:
			pop hl
			pop de
			ld a, (hl)
			or e
			ld e, a
			inc hl
			ld a, (hl)
			or d
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg564_e:
			IF ($ < 32768) && (ntc_rg565_e - ntc_rg565 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg565:
;## kw_notv
;kw_notv, <var>, <destvar>
kw_notv:
			pop hl
			ld a, (hl)
			cpl
			ld e, a
			inc hl
			ld a, (hl)
			cpl
			ld d, a
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

; ============================================================
; Compares - result in Z flag (Z = true)
; Tails take DE = a, HL = b and test a <rel> b.
; ============================================================

ntc_rg565_e:
			IF ($ < 32768) && (ntc_rg566_e - ntc_rg566 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg566:
;## ntc_cmp
ntc_cmp_slt:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_ult:
			ex de, hl
			or a
			sbc hl, de
			sbc a, a
			inc a
			ret
ntc_cmp_sge:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_uge:
			ex de, hl
			or a
			sbc hl, de
			sbc a, a
			ret
ntc_cmp_sgt:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_ugt:
			or a
			sbc hl, de
			sbc a, a
			inc a
			ret
ntc_cmp_sle:
			ld a, d
			xor #80
			ld d, a
			ld a, h
			xor #80
			ld h, a
ntc_cmp_ule:
			or a
			sbc hl, de
			sbc a, a
			ret
ntc_cmp_eq:
			or a
			sbc hl, de
			ret
ntc_cmp_ne:
			or a
			sbc hl, de
			jr z, ntc_cmp_ne_f
			xor a
			ret
ntc_cmp_ne_f:
			or 1
			ret

ntc_rg566_e:
			IF ($ < 32768) && (ntc_rg567_e - ntc_rg567 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg567:
;## kw_scpltvv ntc_cmp
;kw_scpltvv, <var1>, <var2>  - signed var1 < var2
kw_scpltvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_slt

ntc_rg567_e:
			IF ($ < 32768) && (ntc_rg568_e - ntc_rg568 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg568:
;## kw_scpltvl ntc_cmp
;kw_scpltvl, <var>, <literal>
kw_scpltvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_slt

ntc_rg568_e:
			IF ($ < 32768) && (ntc_rg569_e - ntc_rg569 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg569:
;## kw_scplevv ntc_cmp
kw_scplevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_sle

ntc_rg569_e:
			IF ($ < 32768) && (ntc_rg570_e - ntc_rg570 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg570:
;## kw_scplevl ntc_cmp
kw_scplevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_sle

ntc_rg570_e:
			IF ($ < 32768) && (ntc_rg571_e - ntc_rg571 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg571:
;## kw_scpgtvv ntc_cmp
kw_scpgtvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_sgt

ntc_rg571_e:
			IF ($ < 32768) && (ntc_rg572_e - ntc_rg572 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg572:
;## kw_scpgtvl ntc_cmp
kw_scpgtvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_sgt

ntc_rg572_e:
			IF ($ < 32768) && (ntc_rg573_e - ntc_rg573 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg573:
;## kw_scpgevv ntc_cmp
kw_scpgevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_sge

ntc_rg573_e:
			IF ($ < 32768) && (ntc_rg574_e - ntc_rg574 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg574:
;## kw_scpgevl ntc_cmp
kw_scpgevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_sge

ntc_rg574_e:
			IF ($ < 32768) && (ntc_rg575_e - ntc_rg575 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg575:
;## kw_cpeqvv ntc_cmp
;kw_cpeqvv, <var1>, <var2>
kw_cpeqvv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_eq

ntc_rg575_e:
			IF ($ < 32768) && (ntc_rg576_e - ntc_rg576 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg576:
;## kw_cpeqvl ntc_cmp
kw_cpeqvl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_eq

ntc_rg576_e:
			IF ($ < 32768) && (ntc_rg577_e - ntc_rg577 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg577:
;## kw_cpnevv ntc_cmp
kw_cpnevv:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jp ntc_cmp_ne

ntc_rg577_e:
			IF ($ < 32768) && (ntc_rg578_e - ntc_rg578 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg578:
;## kw_cpnevl ntc_cmp
kw_cpnevl:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			jp ntc_cmp_ne

; ============================================================
; Memory (PEEK / POKE / DEEK / DOKE)
; ============================================================

ntc_rg578_e:
			IF ($ < 32768) && (ntc_rg579_e - ntc_rg579 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg579:
;## kw_lptrtov8
;kw_lptrtov8, <literaladdr>, <destvar>  - PEEK(literal)
kw_lptrtov8:
			pop hl
			ld a, (hl)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

ntc_rg579_e:
			IF ($ < 32768) && (ntc_rg580_e - ntc_rg580 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg580:
;## kw_vptrtov8
;kw_vptrtov8, <addrvar>, <destvar>  - PEEK(var)
kw_vptrtov8:
			pop hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			ld a, (de)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

ntc_rg580_e:
			IF ($ < 32768) && (ntc_rg581_e - ntc_rg581 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg581:
;## kw_aget
;kw_aget, <arraybase>, <indexvar>, <destvar>
kw_aget:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, de
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg581_e:
			IF ($ < 32768) && (ntc_rg582_e - ntc_rg582 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg582:
;## kw_aset
;kw_aset, <arraybase>, <indexvar>, <sourcevar>
kw_aset:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, de
			ex de, hl
			pop hl
			ld c, (hl)
			inc hl
			ld b, (hl)
			ex de, hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

ntc_rg582_e:
			IF ($ < 32768) && (ntc_rg583_e - ntc_rg583 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg583:
;## kw_asetl
;kw_asetl, <arraybase>, <indexvar>, <literal>
kw_asetl:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			add hl, hl
			add hl, de
			pop bc
			ld (hl), c
			inc hl
			ld (hl), b
			ret

; ============================================================
; Random (16 bit xorshift 7,9,8 - period 65535)
; ============================================================

ntc_rg583_e:
			IF ($ < 32768) && (ntc_rg584_e - ntc_rg584 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg584:
;## kw_strcpy
;kw_strcpy, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcpy:
			pop de
			pop hl
			dec de
			ld a, (de)
			ld b, a
			inc de
ntc_strcpy_loop:
			ld a, (hl)
			ld (de), a
			or a
			ret z
			inc hl
			inc de
			djnz ntc_strcpy_loop
			xor a
			ld (de), a
			ret

ntc_rg584_e:
			IF ($ < 32768) && (ntc_rg585_e - ntc_rg585 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg585:
;## kw_strcat
;kw_strcat, <destaddr>, <srcaddr>  - cut at the destination's capacity byte
kw_strcat:
			pop de
			dec de
			ld a, (de)
			ld b, a
			inc de
ntc_strcat_end:
			ld a, (de)
			or a
			jr z, ntc_strcat_copy
			inc de
			djnz ntc_strcat_end
			pop hl
			ret
ntc_strcat_copy:
			pop hl
ntc_strcat_loop:
			ld a, (hl)
			ld (de), a
			or a
			ret z
			inc hl
			inc de
			djnz ntc_strcat_loop
			xor a
			ld (de), a
			ret

ntc_rg585_e:
			IF ($ < 32768) && (ntc_rg586_e - ntc_rg586 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg586:
;## kw_strlen
;kw_strlen, <straddr>, <destvar>
kw_strlen:
			pop hl
			ld bc, 0
ntc_strlen_loop:
			ld a, (hl)
			or a
			jr z, ntc_strlen_done
			inc hl
			inc c
			jr ntc_strlen_loop
ntc_strlen_done:
			pop hl
			ld (hl), c
			inc hl
			ld (hl), b
			ret

ntc_rg586_e:
			IF ($ < 32768) && (ntc_rg587_e - ntc_rg587 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg587:
;## kw_strcmpeq
;kw_strcmpeq, <addr1>, <addr2>  - Z if equal
kw_strcmpeq:
			pop de
			pop hl
ntc_streq_loop:
			ld a, (de)
			cp (hl)
			ret nz
			or a
			ret z
			inc hl
			inc de
			jr ntc_streq_loop

ntc_rg587_e:
			IF ($ < 32768) && (ntc_rg588_e - ntc_rg588 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg588:
;## kw_strcmpne
;kw_strcmpne, <addr1>, <addr2>  - Z if not equal
kw_strcmpne:
			pop de
			pop hl
ntc_strne_loop:
			ld a, (de)
			cp (hl)
			jr nz, ntc_strne_t
			or a
			jr z, ntc_strne_f
			inc hl
			inc de
			jr ntc_strne_loop
ntc_strne_t:
			xor a
			ret
ntc_strne_f:
			inc a
			ret

; ============================================================
; I/O - no firmware, no call, no push. SP stays in the thread.
; Shared routines are entered with jp and the return address in
; IX, and end with jp (ix). Keywords that are done use
; ld ix, ntc_next (a ret) so the routine continues the thread.
; ============================================================

ntc_rg588_e:
			IF ($ < 32768) && (ntc_rg589_e - ntc_rg589 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg589:
;## ntc_printbuf ntc_data ntc_plat_screen
; print the 0 terminated ASCII text at (ntc_sptr), then ret (thread)
ntc_printbuf:
			ld hl, (ntc_sptr)
			ld a, (hl)
			or a
			ret z
			inc hl
			ld (ntc_sptr), hl
			ld ix, ntc_printbuf
			jp ntc_plat_putc

ntc_rg589_e:
			IF ($ < 32768) && (ntc_rg590_e - ntc_rg590 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg590:
;## kw_printstrvar ntc_printbuf
;kw_printstrvar, <straddr>
kw_printstrvar:
			pop hl
			ld (ntc_sptr), hl
			jp ntc_printbuf

ntc_rg590_e:
			IF ($ < 32768) && (ntc_rg591_e - ntc_rg591 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg591:
;## ntc_itoa ntc_data
; HL = signed value, DE = buffer: writes the digits and a 0 (DE ends on
; the 0). jp (ix) back. Uses A, BC, IY.
ntc_itoa:
			bit 7, h
			jr z, ntc_ia_pos
			ld a, '-'
			ld (de), a
			inc de
			xor a
			sub l
			ld l, a
			sbc a, a
			sub h
			ld h, a
ntc_ia_pos:
			xor a
			ld (ntc_lead), a
			ld iy, ntc_pow10
ntc_ia_pow:
			ld c, (iy+0)
			ld b, (iy+1)
			ld a, b
			or c
			jr z, ntc_ia_last
			ld a, '0' - 1
ntc_ia_sub:
			inc a
			and a
			sbc hl, bc
			jr nc, ntc_ia_sub
			add hl, bc
			cp '0'
			jr nz, ntc_ia_out
			ld b, a
			ld a, (ntc_lead)
			or a
			ld a, b
			jr z, ntc_ia_skip
ntc_ia_out:
			ld (de), a
			inc de
			ld a, 1
			ld (ntc_lead), a
ntc_ia_skip:
			inc iy
			inc iy
			jr ntc_ia_pow
ntc_ia_last:
			ld a, l
			add a, '0'
			ld (de), a
			inc de
			xor a
			ld (de), a
			jp (ix)
ntc_pow10:		dw 10000, 1000, 100, 10, 0

ntc_rg591_e:
			IF ($ < 32768) && (ntc_rg592_e - ntc_rg592 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg592:
;## kw_printint ntc_printbuf ntc_itoa
;kw_printint, <var>  - signed decimal
kw_printint:
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ld de, ntc_numbuf
			ld ix, ntc_pi_done
			jp ntc_itoa
ntc_pi_done:
			ld hl, ntc_numbuf
			ld (ntc_sptr), hl
			jp ntc_printbuf

ntc_rg592_e:
			IF ($ < 32768) && (ntc_rg593_e - ntc_rg593 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg593:
;## kw_printnl0 ntc_data ntc_plat_screen
;kw_printnl0  - new line unless the cursor is at the start of a line
kw_printnl0:
			ld a, (ntc_curx)
			or a
			ret z
			ld ix, ntc_next
			jp ntc_plat_newline

ntc_rg593_e:
			IF ($ < 32768) && (ntc_rg594_e - ntc_rg594 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg594:
;## kw_printnl ntc_data ntc_plat_screen
;kw_printnl
kw_printnl:
			ld ix, ntc_next
			jp ntc_plat_newline

ntc_rg594_e:
			IF ($ < 32768) && (ntc_rg595_e - ntc_rg595 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg595:
;## ntc_atoi ntc_data
; text to number into the var at (ntc_ivar). ntc_atoi reads ntc_inbuf,
; ntc_atoi_hl reads HL. Spaces first, then - , then digits (or &H hex).
ntc_atoi:
			ld hl, ntc_inbuf
ntc_atoi_hl:
			ld a, (hl)
			cp ' '
			jr nz, ntc_atoi_sign
			inc hl
			jr ntc_atoi_hl
ntc_atoi_sign:
			ld c, 0
			cp '-'
			jr nz, ntc_atoi_amp
			inc c
			inc hl
			ld a, (hl)
ntc_atoi_amp:
			ld de, 0
			cp '&'
			jr nz, ntc_atoi_loop
			inc hl
			ld a, (hl)
			or #20
			cp 'h'
			jr nz, ntc_atoi_done
			inc hl
ntc_atoi_hex:
			ld a, (hl)
			sub '0'
			jr c, ntc_atoi_done
			cp 10
			jr c, ntc_atoi_hd
			or #20
			sub 'a' - '0'
			jr c, ntc_atoi_done
			cp 6
			jr nc, ntc_atoi_done
			add a, 10
ntc_atoi_hd:
			ex de, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			or l
			ld l, a
			ex de, hl
			inc hl
			jr ntc_atoi_hex
ntc_atoi_loop:
			ld a, (hl)
			sub '0'
			jr c, ntc_atoi_done
			cp 10
			jr nc, ntc_atoi_done
			ld (ntc_aptr), hl
			ex de, hl
			ld d, h
			ld e, l
			add hl, hl
			add hl, hl
			add hl, de
			add hl, hl
			ld e, a
			ld d, 0
			add hl, de
			ex de, hl
			ld hl, (ntc_aptr)
			inc hl
			jr ntc_atoi_loop
ntc_atoi_done:
			ld a, c
			or a
			jr z, ntc_atoi_store
			xor a
			sub e
			ld e, a
			sbc a, a
			sub d
			ld d, a
ntc_atoi_store:
			ld hl, (ntc_ivar)
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg595_e:
			IF ($ < 32768) && (ntc_rg596_e - ntc_rg596 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg596:
;## kw_inkey ntc_data ntc_plat_key
;kw_inkey, <destvar>  - new key press or 0, no wait
kw_inkey:
			pop hl
			ld (ntc_ivar), hl
			ld ix, ntc_inkey_got
			jp ntc_plat_scankey
ntc_inkey_got:
			ld hl, (ntc_ivar)
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

ntc_rg596_e:
			IF ($ < 32768) && (ntc_rg597_e - ntc_rg597 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg597:
;## kw_model ntc_data ntc_plat_screen
;kw_model, <literal>  - 0, 1 or 2, clears the screen
kw_model:
			pop hl
			ld a, l
			ld ix, ntc_next
			jp ntc_plat_mode

ntc_rg597_e:
			IF ($ < 32768) && (ntc_rg598_e - ntc_rg598 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg598:
;## kw_frame ntc_data ntc_plat_frame
;kw_frame  - wait for the start of the next frame flyback
kw_frame:
			ld ix, ntc_next
			jp ntc_plat_frame

ntc_rg598_e:
			IF ($ < 32768) && (ntc_rg599_e - ntc_rg599 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg599:
;## kw_ticks ntc_data ntc_plat_ticks
;kw_ticks, <destvar>  - tick count from the platform (CPC: interrupts, 300 a second,
;  only moving in normal mode)
kw_ticks:
			pop hl
			ld (ntc_ivar), hl
			ld ix, ntc_tk_got
			jp ntc_plat_ticks
ntc_tk_got:
			ex de, hl
			ld hl, (ntc_ivar)
			ld (hl), e
			inc hl
			ld (hl), d
			ret

; ============================================================
; String functions. Numbers are passed as the address of a word
; (a literal goes in as lit_n, a dw in the data). Results go to a
; string buffer (41 bytes). Dest may be the same as the source.
; ============================================================

ntc_rg599_e:
			IF ($ < 32768) && (ntc_rg600_e - ntc_rg600 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg600:
;## ntc_getn ntc_data
; BC = address of a word: A = its value limited to 0..255
; (below 0 = 0, above 255 = 255). jp (ix) back. Keeps DE, HL.
ntc_getn:
			ld a, (bc)
			ld (ntc_gnlo), a
			inc bc
			ld a, (bc)
			or a
			jp m, ntc_gn_zero
			jr nz, ntc_gn_max
			ld a, (ntc_gnlo)
			jp (ix)
ntc_gn_zero:
			xor a
			jp (ix)
ntc_gn_max:
			ld a, 255
			jp (ix)

ntc_rg600_e:
			IF ($ < 32768) && (ntc_rg601_e - ntc_rg601 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg601:
;## kw_strleft ntc_getn
;kw_strleft, <dest>, <src>, <nvar>  - Left$(src, n)
kw_strleft:
			pop de
			pop hl
			pop bc
			ld ix, ntc_sl_n
			jp ntc_getn
ntc_sl_n:
			ld b, a
; copy up to B chars from HL to DE, then the 0
ntc_strncpy:
			inc b
ntc_sn_loop:
			dec b
			jr z, ntc_sn_end
			ld a, (hl)
			or a
			jr z, ntc_sn_end
			ld (de), a
			inc hl
			inc de
			jr ntc_sn_loop
ntc_sn_end:
			xor a
			ld (de), a
			ret

ntc_rg601_e:
			IF ($ < 32768) && (ntc_rg602_e - ntc_rg602 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg602:
;## kw_strright ntc_getn kw_strleft
;kw_strright, <dest>, <src>, <nvar>  - Right$(src, n)
kw_strright:
			pop de
			pop hl
			pop bc
			ld ix, ntc_sr_n
			jp ntc_getn
ntc_sr_n:
			ld c, a
			ld (ntc_sptr), hl
			ld b, 0
ntc_sr_len:
			ld a, (hl)
			or a
			jr z, ntc_sr_got
			inc hl
			inc b
			jr ntc_sr_len
ntc_sr_got:
			ld a, b
			sub c
			jr nc, ntc_sr_skip
			xor a
ntc_sr_skip:
			ld hl, (ntc_sptr)
			ld c, a
			ld b, 0
			add hl, bc
			ld b, 255
			jp ntc_strncpy

ntc_rg602_e:
			IF ($ < 32768) && (ntc_rg603_e - ntc_rg603 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg603:
;## kw_strmid ntc_getn kw_strleft
;kw_strmid, <dest>, <src>, <startvar>, <lenvar>  - Mid$(src, start, len)
kw_strmid:
			pop de
			pop hl
			pop bc
			ld ix, ntc_sm_s
			jp ntc_getn
ntc_sm_s:
			or a
			jr z, ntc_sm_s1
			dec a
ntc_sm_s1:
			ld b, a
			inc b
ntc_sm_skip:
			dec b
			jr z, ntc_sm_len
			ld a, (hl)
			or a
			jr z, ntc_sm_len
			inc hl
			jr ntc_sm_skip
ntc_sm_len:
			pop bc
			ld ix, ntc_sm_n
			jp ntc_getn
ntc_sm_n:
			ld b, a
			jp ntc_strncpy

ntc_rg603_e:
			IF ($ < 32768) && (ntc_rg604_e - ntc_rg604 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg604:
;## kw_strchr
;kw_strchr, <dest>, <nvar>  - Chr$(n)
kw_strchr:
			pop de
			pop hl
			ld a, (hl)
			ld (de), a
			inc de
			xor a
			ld (de), a
			ret

ntc_rg604_e:
			IF ($ < 32768) && (ntc_rg605_e - ntc_rg605 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg605:
;## kw_strstr ntc_itoa
;kw_strstr, <dest>, <nvar>  - Str$(n): a space before 0 and positives
kw_strstr:
			pop de
			pop hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			bit 7, h
			jr nz, ntc_st_go
			ld a, ' '
			ld (de), a
			inc de
ntc_st_go:
			ld ix, ntc_next
			jp ntc_itoa

ntc_rg605_e:
			IF ($ < 32768) && (ntc_rg606_e - ntc_rg606 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg606:
;## kw_strspace ntc_getn
;kw_strspace, <dest>, <nvar>  - Space$(n)
kw_strspace:
			pop de
			pop bc
			ld ix, ntc_sp_n
			jp ntc_getn
ntc_sp_n:
			ld c, ' '
; A = count (NTC_STRMAX at most), C = char, DE = dest
ntc_strfill:
	IF NTC_STRMAX < 255
			cp NTC_STRMAX + 1
			jr c, ntc_sf_ok
			ld a, NTC_STRMAX
ntc_sf_ok:
	ENDIF
			ld b, a
			inc b
ntc_sf_loop:
			dec b
			jr z, ntc_sf_end
			ld a, c
			ld (de), a
			inc de
			jr ntc_sf_loop
ntc_sf_end:
			xor a
			ld (de), a
			ret

ntc_rg606_e:
			IF ($ < 32768) && (ntc_rg607_e - ntc_rg607 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg607:
;## kw_strucase
;kw_strucase, <dest>, <src>  - UCase$
kw_strucase:
			pop de
			pop hl
ntc_uc_loop:
			ld a, (hl)
			cp 'a'
			jr c, ntc_uc_put
			cp 'z' + 1
			jr nc, ntc_uc_put
			sub 32
ntc_uc_put:
			ld (de), a
			or a
			ret z
			inc hl
			inc de
			jr ntc_uc_loop

ntc_rg607_e:
			IF ($ < 32768) && (ntc_rg608_e - ntc_rg608 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg608:
;## kw_strrtrim ntc_data
;kw_strrtrim, <dest>, <src>  - RTrim$
kw_strrtrim:
			pop de
			pop hl
			ld (ntc_sptr), de
ntc_rt_copy:
			ld a, (hl)
			ld (de), a
			or a
			jr z, ntc_rt_back
			inc hl
			inc de
			jr ntc_rt_copy
ntc_rt_back:
			ld hl, (ntc_sptr)
			ex de, hl
ntc_rt_loop:
			or a
			sbc hl, de
			add hl, de
			ret z
			dec hl
			ld a, (hl)
			cp ' '
			ret nz
			ld (hl), 0
			jr ntc_rt_loop

ntc_rg608_e:
			IF ($ < 32768) && (ntc_rg609_e - ntc_rg609 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg609:
;## kw_strtrim kw_strrtrim
;kw_strtrim, <dest>, <src>  - Trim$
kw_strtrim:
			pop de
			pop hl
ntc_tr_skip:
			ld a, (hl)
			cp ' '
			jr nz, ntc_tr_go
			inc hl
			jr ntc_tr_skip
ntc_tr_go:
			ld (ntc_sptr), de
			jp ntc_rt_copy

ntc_rg609_e:
			IF ($ < 32768) && (ntc_rg610_e - ntc_rg610 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg610:
;## kw_strasc
;kw_strasc, <src>, <destvar>  - Asc(src), 0 if empty
kw_strasc:
			pop hl
			ld a, (hl)
			pop hl
			ld (hl), a
			inc hl
			ld (hl), 0
			ret

ntc_rg610_e:
			IF ($ < 32768) && (ntc_rg611_e - ntc_rg611 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg611:
;## kw_strval ntc_atoi
;kw_strval, <src>, <destvar>  - Val(src): decimal or &H hex
kw_strval:
			pop hl
			pop de
			ld (ntc_ivar), de
			jp ntc_atoi_hl

ntc_rg611_e:
			IF ($ < 32768) && (ntc_rg612_e - ntc_rg612 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg612:
;## kw_strinstr ntc_getn ntc_data
;kw_strinstr, <startvar>, <s1>, <s2>, <destvar>  - InStr(start, s1, s2)
kw_strinstr:
			pop bc
			ld ix, ntc_in_s
			jp ntc_getn
ntc_in_s:
			or a
			jr nz, ntc_in_s1
			inc a
ntc_in_s1:
			ld c, a
			pop hl
			ld b, a
ntc_in_adv:
			dec b
			jr z, ntc_in_try0
			ld a, (hl)
			or a
			jr z, ntc_in_nfpop
			inc hl
			jr ntc_in_adv
ntc_in_try0:
			pop de
			ld (ntc_sptr), de
ntc_in_try:
			ld (ntc_iptr), hl
			ld de, (ntc_sptr)
ntc_in_cmp:
			ld a, (de)
			or a
			jr z, ntc_in_found
			cp (hl)
			jr nz, ntc_in_next
			inc hl
			inc de
			jr ntc_in_cmp
ntc_in_next:
			ld hl, (ntc_iptr)
			ld a, (hl)
			or a
			jr z, ntc_in_nf
			inc hl
			inc c
			jr ntc_in_try
ntc_in_nfpop:
			pop de
ntc_in_nf:
			ld c, 0
ntc_in_found:
			pop hl
			ld (hl), c
			inc hl
			ld (hl), 0
			ret

ntc_rg612_e:
			IF ($ < 32768) && (ntc_rg613_e - ntc_rg613 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg613:
;## kw_l_mov
;kw_l_mov, <src>, <dest>  - dest = src (4 bytes)
kw_l_mov:
			pop hl
			pop de
			ldi
			ldi
			ldi
			ldi
			ret

ntc_rg613_e:
			IF ($ < 32768) && (ntc_rg614_e - ntc_rg614 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg614:
;## kw_l_itol
;kw_l_itol, <intvar>, <dest>  - Integer to Long (sign extended)
kw_l_itol:
			pop hl
			pop de
			ld a, (hl)
			ld (de), a
			inc hl
			inc de
			ld a, (hl)
			ld (de), a
			inc de
			rla
			sbc a, a
			ld (de), a
			inc de
			ld (de), a
			ret

ntc_rg614_e:
			IF ($ < 32768) && (ntc_rg615_e - ntc_rg615 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg615:
;## kw_l_add
;kw_l_add, <a>, <b>, <dest>  - a + b
kw_l_add:
			pop hl
			pop de
			pop ix
			ld a, (de)
			add a, (hl)
			ld (ix+0), a
			inc hl
			inc de
			ld a, (de)
			adc a, (hl)
			ld (ix+1), a
			inc hl
			inc de
			ld a, (de)
			adc a, (hl)
			ld (ix+2), a
			inc hl
			inc de
			ld a, (de)
			adc a, (hl)
			ld (ix+3), a
			ret

ntc_rg615_e:
			IF ($ < 32768) && (ntc_rg616_e - ntc_rg616 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg616:
;## ntc_buf2k
; ntc_buf - a buffer shared by the classes that need one: FileSystem's
; CAS IN / OUT OPEN buffer (CPC firmware: 2K) and Memory.Copy's page to page
; copy (that much at a time). NTC_BUFSIZE (Option Buffer): 2048 unless set
ntc_buf:		ds NTC_BUFSIZE

ntc_rg616_e:
			IF ($ < 32768) && (ntc_rg617_e - ntc_rg617 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg617:
;## ntc_memcore ntc_data ntc_mem ntc_memcore2 ntc_plat_memtop @shared
; ------------------------------------------------------------
; ntc_memcore - the Memory class, the part every scheme shares. The scheme
; (Option Memory, else the platform's default) is the section ntc_mem -
; only the one chosen is in the library (@if:): CPCExpansion (16K pages
; through the #4000 window, up to 4MB) or Small (main RAM only, no paging).
; Each class method jumps to mem_go with HL = the routine: mem_go runs it
; on the real stack (call / push are fine there), interrupts on in normal
; mode (off in turbo), and stores its HL result at mem_res (mem_go4: a Long, high
; word in mem_hi; mem_go0: no store - the routine writes the result
; itself, or there is none). A routine that fails jumps to mem_err with
; HL = the status; mem_err puts back the page that was in the window
; and unwinds to mem_go.
; Far pointer = a Long: address, page (page 0 = plain memory).
; Heap: blocks from mem_hlo to mem_hhi (a D page, or Small's main RAM),
; each with a 2 byte header: length including the header (bits 0-14),
; bit 15 = in use. Free blocks are at most #4000 (joins stop there).
; The scheme supplies: mem_start (the first call), mem_sel (HL = page
; into the window), mem_chk (HL = a page number, else BadPage).
; ------------------------------------------------------------
MEM_WIN		equ #4000
MEM_BADPAGE	equ -2

mem_a1:			dw 0
mem_a2:			dw 0
mem_a3:			dw 0
mem_res:		dw 0
mem_hi:			dw 0
mem_sp:			dw 0
mem_esp:		dw 0
mem_six:		dw 0
mem_siy:		dw 0
mem_need:		dw 0
mem_max:		dw 0
mem_srca:		dw 0
mem_dsta:		dw 0
mem_srcp:		dw 0
mem_dstp:		dw 0
mem_left:		dw 0
mem_chunk:		dw 0
mem_cur:		dw 1			; the page in the window
mem_keep:		dw 1			; the page to put back
mem_hlo:		dw MEM_WIN		; the heap region mem_fit / mem_big work in
mem_hhi:		dw #8000
mem_store:		db 0
mem_init:		db 0			; 1 = the first call has been

; mem_go / mem_go4 / mem_go0 - HL = the routine (see above)
mem_go0:
			xor a
			jr mem_gostart
mem_go4:
			ld a, 4
			jr mem_gostart
mem_go:
			ld a, 2
mem_gostart:
			ld (mem_store), a
			ld (mem_sp), sp
			ld sp, (ntc_csp)
			ld (mem_six), ix
			ld (mem_siy), iy
			ld de, 0
			ld (mem_hi), de
			push hl
			call mem_start
			pop hl
			ld de, (mem_cur)
			ld (mem_keep), de
			ld a, (ntc_nmode)		; normal mode: interrupts in during the call (Ticks keep
			or a					; counting through a long Sort or Copy); turbo: off
			jr z, mem_gocall
			ei
mem_gocall:
			ld (mem_esp), sp
			call mem_jphl
mem_back:
			di
			ld ix, (mem_six)
			ld iy, (mem_siy)
			ld a, (mem_store)
			or a
			jr z, mem_gone
			ex de, hl
			ld hl, (mem_res)
			ld (hl), e
			inc hl
			ld (hl), d
			cp 4
			jr nz, mem_gone
			ld de, (mem_hi)
			inc hl
			ld (hl), e
			inc hl
			ld (hl), d
mem_gone:
			ld sp, (mem_sp)
			ret
mem_jphl:
			jp (hl)
mem_err:
			ld sp, (mem_esp)
			push hl
			ld hl, (mem_keep)
			call mem_sel
			pop hl
			ld de, 0
			ld (mem_hi), de
			jr mem_back

mem_chk_bad:
			ld hl, MEM_BADPAGE
			jp mem_err

ntc_rg617_e:
			IF ($ < 32768) && (ntc_rg618_e - ntc_rg618 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg618:
;## ntc_memcore2 ntc_memcore @shared @far
; ntc_memcore2 - the rest of the shared part: far pointers, the heap, bytes
; and words. Runs on the real stack (through mem_go), so a keyword ROM set
; can place it in another ROM of the set (@far).

; mem_far - HL = a far pointer's address (Long: address, page): DE = the
; address, HL = the page (0 = plain memory). Page not 0: it must be a page
; this machine has and the address in the window, else mem_err BadPage.
mem_far:
			ld e, (hl)
			inc hl
			ld d, (hl)
			inc hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			or h
			ret z
			call mem_chk
			ld a, d
			and #C0
			cp #40
			jp nz, mem_chk_bad		; (jr: another part, maybe across Option Reserve)
			ret

; PageOf(ptr): a far pointer's page
mem_pageof:
			ld hl, (mem_a1)
			inc hl
			inc hl
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			ret

; Address(ptr): its page into the window (page 0: nothing); the address
mem_address:
			ld hl, (mem_a1)
			call mem_far
			ld a, h
			or l
			call nz, mem_sel
			ex de, hl
			ret

; HeapStart(), HeapEnd(): the heap region (CPCExpansion: the window, a D page at a time)
mem_heapstart:
			ld hl, (mem_hlo)
			ret
mem_heapend:
			ld hl, (mem_hhi)
			ret
; ProgramStart(), ProgramEnd() (the first byte after the program and its
; arrays), Top() (the platform's top of free RAM), StackTop() (the real stack)
mem_progstart:
			ld hl, ntc_start
			ret
mem_progend:
			ld hl, ntc_free
			ret
mem_top:
			jp ntc_plat_memtop
mem_stacktop:
			ld hl, (ntc_csp)
			ret

; mem_atend - Z when HL = mem_hhi (the heap region's end). Keeps BC, DE, HL.
mem_atend:
			ld a, (mem_hhi)
			cp l
			ret nz
			ld a, (mem_hhi + 1)
			cp h
			ret
; mem_cap - HL = two joined blocks' length: NC = too long (over #4000), C = fine
mem_cap:
			ld a, h
			cp #40
			ret c
			scf
			ccf
			ret nz
			ld a, l
			cp 1					; #4000 exactly: C
			ret

; mem_fit - in the heap region (mem_hlo .. mem_hhi: a D page, or Small's main RAM): the first free block of mem_need
; bytes or more (free neighbours joined on the way), split when 4 or more
; bytes are left over, marked in use. Z: HL = its data. NZ: none.
mem_fit:
			ld hl, (mem_hlo)
mem_f_lp:
			call mem_atend
			jr z, mem_f_none
			ld e, (hl)
			inc hl
			ld d, (hl)
			dec hl
			bit 7, d
			jr z, mem_f_free
			res 7, d
mem_f_next:
			add hl, de
			jr mem_f_lp
mem_f_free:
			push hl
			add hl, de				; the block after
			call mem_atend
			jr z, mem_f_last
			ld c, (hl)
			inc hl
			ld b, (hl)
			bit 7, b
			jr nz, mem_f_last
			ld h, d					; free too: join them, up to #4000
			ld l, e
			add hl, bc
			call mem_cap
			jr nc, mem_f_last
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			dec hl
			jr mem_f_free
mem_f_last:
			pop hl
			push hl
			ex de, hl				; HL = its length, DE = the block
			ld bc, (mem_need)
			or a
			sbc hl, bc				; what is left over
			jr c, mem_f_small
			ld a, h
			or a
			jr nz, mem_f_cut
			ld a, l
			cp 4
			jr nc, mem_f_cut
			add hl, bc				; all of it
			ld b, h
			ld c, l
			pop hl
			jr mem_f_take
mem_f_cut:
			ex de, hl				; DE = left over, HL = the block
			pop hl
			push hl
			add hl, bc				; the free block after it
			ld (hl), e
			inc hl
			ld (hl), d
			pop hl
mem_f_take:
			ld (hl), c
			inc hl
			ld a, b
			or #80
			ld (hl), a
			inc hl
			xor a
			ret
mem_f_small:
			add hl, bc				; HL = its length again
			ex de, hl
			pop hl
			jr mem_f_next
mem_f_none:
			or 1					; NZ
			ret

; mem_big - in the heap region: join free neighbours, mem_max =
; the biggest free block's length if bigger
mem_big:
			ld hl, (mem_hlo)
mem_b_lp:
			call mem_atend
			ret z
			ld e, (hl)
			inc hl
			ld d, (hl)
			dec hl
			bit 7, d
			jr z, mem_b_free
			res 7, d
mem_b_next:
			add hl, de
			jr mem_b_lp
mem_b_free:
			push hl
			add hl, de
			call mem_atend
			jr z, mem_b_end
			ld c, (hl)
			inc hl
			ld b, (hl)
			bit 7, b
			jr nz, mem_b_end
			ld h, d
			ld l, e
			add hl, bc
			call mem_cap
			jr nc, mem_b_end
			ex de, hl
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			dec hl
			jr mem_b_free
mem_b_end:
			pop hl
			push hl
			ld hl, (mem_max)
			or a
			sbc hl, de
			pop hl
			jr nc, mem_b_next
			ld (mem_max), de
			jr mem_b_next

; ---- single bytes and words through far pointers (the window is put back)

; mem_at - mem_a1 = a far pointer's address: its page in, HL = the address
mem_at:
			ld hl, (mem_a1)
			call mem_far
			ld a, h
			or l
			call nz, mem_sel
			ex de, hl
			ret

mem_readbyte:
			call mem_at
			ld l, (hl)
			ld h, 0
			jr mem_putback
mem_readword:
			call mem_at
			ld a, (hl)
			inc hl
			ld h, (hl)
			ld l, a
			jr mem_putback
mem_writebyte:
			call mem_at
			ld a, (mem_a2)
			ld (hl), a
			jr mem_putback
mem_writeword:
			call mem_at
			ld de, (mem_a2)
			ld (hl), e
			inc hl
			ld (hl), d
mem_putback:
			push hl
			ld hl, (mem_keep)
			call mem_sel
			pop hl
			ret

ntc_rg618_e:
			IF ($ < 32768) && (ntc_rg619_e - ntc_rg619 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg619:
;## ntc_mem ntc_memcore ntc_membank @shared @far
; ------------------------------------------------------------
; ntc_mem (CPCExpansion) - 16K RAM pages in the #4000-#7FFF window (CPC gate
; array RAM setting: C0 = plain, C4-C7 + bank * 8 = page 0-3 of a 64K bank;
; the port's high byte #7F .. #78 picks the 512K block), up to a 4MB
; expansion: 64 banks, 257 pages (NTC_MEMBANKS: Option Memory's limit).
;   Page 1  = main RAM #4000-#7FFF (setting #C0)
;   Page 2+ = 4 pages for each bank the probe finds, the standard 512K
;             (port #7F) first, then the blocks on #7E .. #78
;   Page numbers are 16 bit (a far pointer's high word); 0 = plain memory.
;   No pages at all when the program (ntc_start .. ntc_free) or the
;   real stack is in the window: switching would hide them.
; Tables, made by the first call (mem_start) from ntc_free up, sized to
; what the probe finds (3 bytes a page); fewer pages when there isn't room
; below #4000 (or below the real stack):
;   the port table - 2 bytes a page: the BC that selects it (out (c), c),
;                    so selecting a page is a look-up, nothing worked out
;   the RAT        - 1 byte a page, its type: - free, C, D, I, U, B (the 4
;                    pages of a whole bank, AllocBank)
; No lists: a free page or bank is found by scanning the RAT (CPIR), a page
; is freed by writing - back. C / I / U pages come from the low block first
; (main + the #7F block), D pages from the high one (#78-#7E); each falls
; back to the other. On 576K or less every page is low.
; The page in the window is kept in mem_cur, written before the port,
; so an interrupt handler can always put the right page back.
; A new D page is one free block of #4000.
; ------------------------------------------------------------
MEM_BANKS	equ NTC_MEMBANKS	; 0 - 64
MEM_LB		equ 6			; the whole-bank kind (mem_kinds)

mem_count:		dw 0			; pages (0 = no paging)
mem_tport:		dw 0			; the port table (2 bytes a page: its BC)
mem_ttype:		dw 0			; the RAT (1 byte a page: its type)
mem_tend:		dw 0			; the first byte after them
mem_fp:			dw 0			; (making the port table: the next bank found)
mem_banks:		db 0			; 64K banks found
mem_tl:			db 0
mem_sw:			db 0			; mem_scan: 0 low, 1 high, 2 any
mem_kinds:		db "--CDIUB"		; the type character of each kind (0, 1 free)
mem_found:		ds MEM_BANKS + 1	; probe: the banks found (0-63), in order
mem_save:		ds MEM_BANKS + 1	; probe: the bytes the markers replace
mem_bksp:		dw 0			; CallBank: the real stack while bank code runs
mem_bkrmr:		db 0			; and the ROM / mode byte to put back

; mem_start - the first call: can this program page, what is fitted, the tables
mem_start:
			ld a, (mem_init)
			or a
			ret nz
			inc a
			ld (mem_init), a
			ld hl, ntc_free
			ld (mem_tend), hl
	IF NTC_WINHOLE
			jr mem_st_prog			; the program is built round the window (Option Reserve)
	ENDIF
	IF NTC_ROMLIB					; the keyword ROM: free RAM from #8000 on = built round it
			ld a, h
			cp #80
			jr nc, mem_st_prog
	ENDIF
			ld de, MEM_WIN + 1		; the program must be out of the window:
			or a					; it ends by #4000 ...
			sbc hl, de
			jr c, mem_st_prog
			ld hl, ntc_start		; ... or starts at #8000 or above
			ld de, #8000
			or a
			sbc hl, de
			ret c
mem_st_prog:
			ld hl, (ntc_csp)		; and the real stack too: at or below #4000,
			ld de, MEM_WIN + 1		; or 64 bytes or more above #8000
			or a
			sbc hl, de
			jr c, mem_probe
			ld hl, (ntc_csp)
			ld de, #8040
			or a
			sbc hl, de
			ret c
; the probe: interrupts off, nothing written until every byte is saved.
; Markers go in bank 63 down to bank 0, then main RAM, so a bank the
; hardware doesn't decode (a 6128 has one bank, a 512K expansion ignores
; the port's block bits) reads back a lower bank's marker, and a 64K
; machine (C4-C7 do nothing) reads main RAM's.
mem_probe:
		IF MEM_BANKS > 0
			ld a, i					; P/V = interrupts were on
			di
			push af
			ld bc, #7FC0
			out (c), c
			ld a, (MEM_WIN)
			ld (mem_save + MEM_BANKS), a
			ld hl, mem_save
			ld e, 0
mem_pr_save:
			call mem_jbc
			out (c), c
			ld a, (MEM_WIN)
			ld (hl), a
			inc hl
			inc e
			ld a, e
			cp MEM_BANKS
			jr nz, mem_pr_save
			ld e, MEM_BANKS
mem_pr_mark:
			dec e
			call mem_jbc
			out (c), c
			ld a, e
			add a, #40
			ld (MEM_WIN), a
			ld a, e
			or a
			jr nz, mem_pr_mark
			ld bc, #7FC0
			out (c), c
			ld a, #A5
			ld (MEM_WIN), a
			ld hl, mem_found
			ld d, 0
			ld e, 0
mem_pr_read:
			call mem_jbc
			out (c), c
			ld a, e
			add a, #40
			push hl
			ld hl, MEM_WIN
			cp (hl)
			pop hl
			jr nz, mem_pr_none
			ld (hl), e				; this bank is there
			inc hl
			inc d
mem_pr_none:
			inc e
			ld a, e
			cp MEM_BANKS
			jr nz, mem_pr_read
			ld hl, mem_save + MEM_BANKS	; put the bytes back, bank 63 down to 0
			ld e, MEM_BANKS
mem_pr_back:
			dec e
			dec hl
			call mem_jbc
			out (c), c
			ld a, (hl)
			ld (MEM_WIN), a
			ld a, e
			or a
			jr nz, mem_pr_back
			ld bc, #7FC0
			out (c), c
			ld a, (mem_save + MEM_BANKS)
			ld (MEM_WIN), a
			ld a, d
			ld (mem_banks), a
			pop af
			jp po, mem_pr_di
			ei
mem_pr_di:
		ENDIF
			ld a, (mem_banks)		; pages = 1 + 4 a bank
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			inc hl
			ld (mem_count), hl
	IF NTC_WINHOLE
			call ntc_plat_memtop		; built round the window: the tables go above it
			jr mem_tb_lim			; (ntc_memtab), up to the platform's top
	ENDIF
	IF NTC_ROMLIB					; the keyword ROM: a program built round the window (it has no
			ld hl, ntc_free			; NTC_WINHOLE here) has its free RAM above it - up to the top
			ld a, h
			cp #80
			jr c, mem_tb_low
			call ntc_plat_memtop
			jr mem_tb_lim
mem_tb_low:
	ENDIF
			ld de, (ntc_csp)		; the tables must end by #4000, or 128 bytes
			ld hl, MEM_WIN			; under the real stack when it is lower
			or a
			sbc hl, de
			ld hl, MEM_WIN
			jr c, mem_tb_lim
			ld hl, -128
			add hl, de
mem_tb_lim:
			ld (mem_tend), hl		; the limit, for now
mem_tb_fit:
			ld hl, (mem_count)
			ld a, h
			or l
			jr z, mem_tb_none
			ld d, h
			ld e, l
			add hl, hl
			add hl, de				; 3 bytes a page
	IF NTC_WINHOLE
			ld de, ntc_memtab
	ELSE
			ld de, ntc_free
	ENDIF
			add hl, de
			ex de, hl				; DE = their end
			ld hl, (mem_tend)
			or a
			sbc hl, de
			jr nc, mem_tb_ok
			ld hl, (mem_count)		; no room: one page fewer
			dec hl
			ld (mem_count), hl
			jr mem_tb_fit
mem_tb_none:
	IF NTC_WINHOLE
			ld hl, ntc_memtab
	ELSE
			ld hl, ntc_free
	ENDIF
			ld (mem_tend), hl
			ret
mem_tb_ok:
			ld (mem_tend), de
	IF NTC_WINHOLE
			ld hl, ntc_memtab
	ELSE
			ld hl, ntc_free
	ENDIF
			ld (mem_tport), hl
			ld de, (mem_count)
			add hl, de
			add hl, de
			ld (mem_ttype), hl
			ld bc, (mem_count)		; the RAT: every page free
			ld (hl), '-'
			dec bc
			ld a, b
			or c
			jr z, mem_tb_ports
			ld d, h
			ld e, l
			inc de
			ldir
mem_tb_ports:						; the port table: page 1 main RAM, then 4 a bank found
			ld hl, (mem_tport)
			ld (hl), #C0
			inc hl
			ld (hl), #7F
			inc hl
			ld de, (mem_count)
			dec de					; DE = pages left
			ld bc, mem_found
			ld (mem_fp), bc
mem_tb_bk:
			ld a, d
			or e
			ret z
			push de
			ld bc, (mem_fp)
			ld a, (bc)
			inc bc
			ld (mem_fp), bc
			ld e, a
			call mem_jbc			; BC = its page 0's port (keeps DE, HL)
			pop de
			ld a, 4
mem_tb_pg:
			ld (hl), c
			inc hl
			ld (hl), b
			inc hl
			inc c
			dec de
			push af
			ld a, d
			or e
			jr z, mem_tb_pend		; (fewer pages than found: the rest left out)
			pop af
			dec a
			jr nz, mem_tb_pg
			jr mem_tb_bk
mem_tb_pend:
			pop af
			ret

; mem_jbc - E = bank 0-63: BC = the port for its page 0 (B = #7F - E / 8,
; C = #C4 + (E and 7) * 8). Keeps DE, HL.
mem_jbc:
			ld a, e
			rrca
			rrca
			rrca
			and 7
			ld b, a
			ld a, #7F
			sub b
			ld b, a
			ld a, e
			and 7
			add a, a
			add a, a
			add a, a
			add a, #C4
			ld c, a
			ret

; mem_sel - HL = page (valid): into the window. mem_cur first, then the
; port; nothing done when it is in already. Keeps BC, DE, HL.
mem_sel:
			push hl
			push de
			push bc
			ld de, (mem_cur)
			ld a, e
			cp l
			jr nz, mem_se_do
			ld a, d
			cp h
			jr z, mem_se_end
mem_se_do:
			ld (mem_cur), hl
			ld a, h
			or l
			ld bc, #7FC0			; (0: plain RAM)
			jr z, mem_se_out
			add hl, hl				; its port from the port table
			ld de, (mem_tport)
			add hl, de
			dec hl
			ld b, (hl)
			dec hl
			ld c, (hl)
mem_se_out:
			ld (ntc_rampt), bc
			out (c), c
mem_se_end:
			pop bc
			pop de
			pop hl
			ret

; mem_chk - HL = a page number: 1 .. mem_count, else mem_err BadPage.
; Keeps BC, DE, HL.
mem_chk:
			ld a, h
			or l
			jp z, mem_chk_bad
			push de
			push hl
			ex de, hl
			ld hl, (mem_count)
			or a
			sbc hl, de
			pop hl
			pop de
			ret nc
			jp mem_chk_bad
; ---- the tables (BC = a page)

; mem_tpb - HL = its type byte (in the RAT). Keeps A, BC, DE.
mem_tpb:
			ld hl, (mem_ttype)
			add hl, bc
			dec hl
			ret
; mem_push - A = a kind (mem_kinds: 2-6): the page is of that kind now. Keeps A, BC, DE.
mem_push:
			push af
			push de
			ld e, a
			ld d, 0
			ld hl, mem_kinds
			add hl, de
			ld a, (hl)
			call mem_tpb
			ld (hl), a
			pop de
			pop af
			ret
; mem_remove - (A = a kind) nothing to take it off: the RAT has no lists. NZ. Keeps BC, DE.
mem_remove:
			ld a, 1
			or a
			ret
; mem_lowhigh - A = the block the page is in: 0 low (main, or the #7F
; block) or 1 high. Keeps BC, DE.
mem_lowhigh:
			push de
			ld h, b
			ld l, c
			add hl, hl
			ld de, (mem_tport)
			add hl, de
			dec hl					; its port's high byte
			ld a, (hl)
			pop de
			cp #7F
			ld a, 0
			ret z
			inc a
			ret
; mem_tofree - the page free again. Keeps BC, DE.
mem_tofree:
			call mem_tpb
			ld (hl), '-'
			ret
; mem_scan - A = 0 low, 1 high, 2 either: BC = the first free page in it, NZ;
; Z = none
mem_scan:
			ld (mem_sw), a
			ld hl, (mem_ttype)
			ld bc, (mem_count)
mem_sc_lp:
			ld a, b
			or c
			ret z
			ld a, '-'
			cpir
			jr nz, mem_sc_none
			push bc
			push hl
			ld de, (mem_ttype)
			or a
			sbc hl, de				; the page: its entry is at HL - 1
			ld b, h
			ld c, l
			ld a, (mem_sw)
			cp 2
			jr z, mem_sc_hit
			call mem_lowhigh
			ld hl, mem_sw
			cp (hl)
			jr z, mem_sc_hit
			pop hl
			pop bc
			jr mem_sc_lp
mem_sc_hit:
			pop af
			pop af
			ld a, 1
			or a
			ret
mem_sc_none:
			xor a
			ret
; mem_dnext - BC = a page (0: before the first): BC = the next D page, NZ;
; Z = none
mem_dnext:
			ld hl, (mem_count)
			or a
			sbc hl, bc
			ret z
			push hl
			ld hl, (mem_ttype)
			add hl, bc
			pop bc
			ld a, 'D'
			cpir
			jr nz, mem_sc_none
			ld de, (mem_ttype)
			or a
			sbc hl, de
			ld b, h
			ld c, l
			ld a, 1
			or a
			ret
; mem_listof - A = the page's kind (2-6), or its free block (0, 1). Keeps BC, DE.
mem_listof:
			call mem_tpb
			ld a, (hl)
			push bc
			ld hl, mem_kinds + 2
			ld b, 5
			ld c, 2
mem_lo_lp:
			cp (hl)
			jr z, mem_lo_got
			inc hl
			inc c
			djnz mem_lo_lp
			pop bc
			jp mem_lowhigh
mem_lo_got:
			ld a, c
			pop bc
			ret
; mem_kindlist - A = a type character: A = its kind (2-5), NZ; Z = not one.
mem_kindlist:
			ld hl, mem_kinds + 2
			ld b, 4
			ld c, 2
mem_kl_lp:
			cp (hl)
			jr z, mem_kl_got
			inc hl
			inc c
			djnz mem_kl_lp
			xor a
			ret
mem_kl_got:
			ld a, c
			or a
			ret
; mem_take - A = a kind (2-5): a free page of that kind now - D from the
; high block first, the others from the low one - a D page made one free
; block. BC = the page, NZ; Z = none left.
mem_take:
			ld (mem_tl), a
			cp 3
			ld a, 1
			jr z, mem_tk_s
			xor a
mem_tk_s:
			call mem_scan
			jr nz, mem_tk_got
			ld a, 2
			call mem_scan
			ret z
mem_tk_got:
			ld a, (mem_tl)
			call mem_push
			cp 3
			jr nz, mem_tk_done
			ld h, b
			ld l, c
			call mem_sel
			ld hl, #4000
			ld (MEM_WIN), hl
			ld hl, (mem_keep)
			call mem_sel
mem_tk_done:
			ld a, 1
			or a
			ret

; ---- what's there

; Pages(): pages (0 = no paging, 1 = 64K, 5 = 128K ... 33 = 512K ... 257 = 4MB)
mem_pages:
			ld hl, (mem_count)
			ret

; FreePages(): the free pages (- in the RAT)
mem_freepages:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			ld b, h
			ld c, l
			ld hl, (mem_ttype)
			ld de, 0
mem_fp_lp:
			ld a, '-'
			cpir
			jr nz, mem_fp_end
			inc de
			ld a, b
			or c
			jr nz, mem_fp_lp
mem_fp_end:
			ex de, hl
			ret

; RamSize(): K of RAM the probe found (64 + 64 a bank), 0 = not probed
mem_ramsize:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			ld a, (mem_banks)
			ld l, a
			ld h, 0
			inc hl
			add hl, hl				; x 64
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			add hl, hl
			ret

; Model(): 0 none, 1 small (1 page), 2 medium (up to 5), 3 large (up to
; 33, a 512K expansion), 4 huge (more)
mem_model:
			ld de, (mem_count)
			ld hl, 0
			ld a, d
			or a
			jr nz, mem_md_huge
			ld a, e
			or a
			ret z
			inc l
			cp 2
			ret c
			inc l
			cp 6
			ret c
			inc l
			cp 34
			ret c
mem_md_huge:
			ld l, 4
			ret

; TableEnd(): the first byte after Memory's tables (they start at the program's end)
mem_tableend:
			ld hl, (mem_tend)
			ret

; PageType(page): its type character
mem_pagetype:
			ld hl, (mem_a1)
			call mem_chk
			ld b, h
			ld c, l
			call mem_tpb
			ld l, (hl)
			ld h, 0
			ret

; Map(first, count): one character per page from first, into the string
; result (as many as fit; pages past the last are left out)
mem_map:
			ld hl, (mem_res)
			dec hl
			ld a, (hl)				; the string's capacity
			inc hl
			ld (mem_srca), hl
			ld (mem_chunk), a
			ld bc, (mem_a1)
			ld hl, (mem_a2)
			ld (mem_left), hl
mem_mp_lp:
			ld hl, (mem_left)
			bit 7, h
			jr nz, mem_mp_end
			ld a, h
			or l
			jr z, mem_mp_end
			ld a, b
			or c
			jr z, mem_mp_end
			ld hl, (mem_count)
			or a
			sbc hl, bc
			jr c, mem_mp_end
			ld a, (mem_chunk)
			or a
			jr z, mem_mp_end
			dec a
			ld (mem_chunk), a
			call mem_tpb
			ld a, (hl)
			ld hl, (mem_srca)
			ld (hl), a
			inc hl
			ld (mem_srca), hl
			inc bc
			ld hl, (mem_left)
			dec hl
			ld (mem_left), hl
			jr mem_mp_lp
mem_mp_end:
			ld hl, (mem_srca)
			ld (hl), 0
			ret

; ---- whole pages

; AllocPage(kind): a free page, now of that kind (C, D, I, U); 0 = none left
mem_allocpage:
			ld hl, (mem_count)
			ld a, h
			or l
			jr z, mem_ap_none
			ld hl, (mem_a1)
			ld a, h
			or a
			jr nz, mem_ap_none
			ld a, l
			call mem_kindlist
			jr z, mem_ap_none
			call mem_take
			jr z, mem_ap_none
			ld h, b
			ld l, c
			ret
mem_ap_none:
			ld hl, 0
			ret

; FreePage(page): back to free (a D page's blocks go with it). OK, or
; BadPage (not a page, or free already)
mem_freepage:
			ld hl, (mem_a1)
			call mem_chk
			ld b, h
			ld c, l
			call mem_listof
			cp 2
			jp c, mem_chk_bad
			call mem_remove
			call mem_tofree
			ld hl, 0
			ret

; SelectPage(page): into the window; #4000
mem_selpage:
			ld hl, (mem_a1)
			call mem_chk
			call mem_sel
			ld hl, MEM_WIN
			ret

; CurrentPage(): the page in the window (0 = no paging)
mem_curpage:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			ld hl, (mem_cur)
			ret

; ---- whole 64K banks (page numbers 4 * bank - 2 .. 4 * bank + 1)

; Banks(): whole banks the tables cover (0 = none)
mem_bankcount:
			ld hl, (mem_count)
			ld a, h
			or l
			ret z
			dec hl
			srl h
			rr l
			srl h
			rr l
			ret

; mem_bkfirst - (mem_a1) = a bank, 1 .. Banks(): BC = its first page, else
; mem_err BadPage
mem_bkfirst:
			call mem_bankcount
			ld de, (mem_a1)
			ld a, d
			or e
			jp z, mem_chk_bad
			or a
			sbc hl, de
			jp c, mem_chk_bad
			ex de, hl
			dec hl
			add hl, hl
			add hl, hl
			inc hl
			inc hl
			ld b, h
			ld c, l
			ret

; AllocBank(): a bank whose 4 pages are all free, now type B; 0 = none
mem_allocbank:
			call mem_bankcount
			ld a, l
			or a
			jr z, mem_ab_none
			ld (mem_tl), a			; banks left to try
			ld bc, 2
mem_ab_lp:
			push bc
			ld d, 4
mem_ab_chk:
			call mem_listof
			cp 2
			jr nc, mem_ab_used
			inc bc
			dec d
			jr nz, mem_ab_chk
			pop bc					; all 4 free: onto the bank list
			push bc
			ld d, 4
mem_ab_take:
			call mem_listof
			call mem_remove
			ld a, MEM_LB
			call mem_push
			inc bc
			dec d
			jr nz, mem_ab_take
			pop hl					; bank = (first page + 2) / 4
			inc hl
			inc hl
			srl h
			rr l
			srl h
			rr l
			ret
mem_ab_used:
			pop bc
			ld hl, 4
			add hl, bc
			ld b, h
			ld c, l
			ld a, (mem_tl)
			dec a
			ld (mem_tl), a
			jr nz, mem_ab_lp
mem_ab_none:
			ld hl, 0
			ret

; FreeBank(bank): its 4 pages back to free. OK, or BadPage (not a bank,
; or not taken with AllocBank)
mem_bkstub:
			ld hl, ntc_bk_stub
			ret

mem_freebank:
			call mem_bkfirst
			push bc
			ld d, 4
mem_fb_chk:
			call mem_listof
			cp MEM_LB
			jp nz, mem_chk_bad
			inc bc
			dec d
			jr nz, mem_fb_chk
			pop bc
			ld d, 4
mem_fb_lp:
			ld a, MEM_LB
			call mem_remove
			call mem_tofree
			inc bc
			dec d
			jr nz, mem_fb_lp
			ld hl, 0
			ret

; CallBank(bank, address, value): runs the bank's code at address with the
; whole 64K being that bank (RAM setting C2), HL = value; its HL comes back.
; The bank must be taken (AllocBank). The switch code (ntc_bk_stub, about
; 20 bytes) is copied into the bank at its own address first, so those
; bytes of the bank are overwritten. Interrupts are off and both ROMs are
; off while the bank code runs; it starts with the stack at the bank's top
; (#FFFF down) and ends with ret. It must keep the alternate registers.
mem_callbank:
			call mem_bkfirst
			call mem_listof
			cp MEM_LB
			jp nz, mem_chk_bad
			ld hl, ntc_bk_stub		; copy the switch code into the bank
mem_cb_cp:
			push bc
			ld a, h					; its page in the bank: address / #4000
			rlca
			rlca
			and 3
			add a, c
			ld c, a
			jr nc, mem_cb_nc
			inc b
mem_cb_nc:
			push hl
			ld h, b
			ld l, c
			call mem_sel
			pop hl
			ld b, (hl)
			ld a, h
			and #3F
			or #40
			ld d, a
			ld e, l
			ld a, b
			ld (de), a
			pop bc
			inc hl
			ld a, l
			cp low ntc_bk_end
			jr nz, mem_cb_cp
			ld a, h
			cp high ntc_bk_end
			jr nz, mem_cb_cp
			ld hl, (mem_keep)
			call mem_sel
			call mem_bkfirst		; BC = C2 for the bank: its page 0's port
			ld h, b					; ((#C4 + bank bits) and #F8, or 2)
			ld l, c
			add hl, hl
			ld de, (mem_tport)
			add hl, de
			dec hl
			ld b, (hl)
			dec hl
			ld a, (hl)
			and #F8
			or 2
			ld c, a
			ld de, (mem_a2)
			ld hl, (mem_a3)
			jp ntc_bk_go

; ---- heap in D pages

; Alloc(size): a far pointer to size bytes in a D page, 0 = no room.
; Tries the page in the window, then the other D pages, then takes a free
; page. The window is left as it was.
mem_alloc:
			ld hl, (mem_count)
			ld a, h
			or l
			jr z, mem_al_fail
			ld hl, (mem_a1)
			ld a, h
			or l
			jr nz, mem_al_size
			inc hl
mem_al_size:
			ld de, #3FFF			; up to #3FFE: a page less its header
			or a
			push hl
			sbc hl, de
			pop hl
			jr nc, mem_al_fail
			inc hl
			inc hl
			ld (mem_need), hl
			ld bc, (mem_keep)
			call mem_tpb
			ld a, (hl)
			cp 'D'
			jr nz, mem_al_scan
			ld h, b
			ld l, c
			call mem_try
			jr z, mem_al_got
mem_al_scan:
			ld bc, 0
mem_al_lp:
			call mem_dnext
			jr z, mem_al_new
			ld hl, (mem_keep)
			or a
			sbc hl, bc
			jr z, mem_al_lp
			push bc
			ld h, b
			ld l, c
			call mem_try
			pop bc
			jr z, mem_al_got
			jr mem_al_lp
mem_al_new:
			ld a, 3
			call mem_take
			jr z, mem_al_back
			ld h, b
			ld l, c
			call mem_try
mem_al_got:
			ld de, (mem_cur)		; HL = the data, its page is in
			ld (mem_hi), de
			push hl
			ld hl, (mem_keep)
			call mem_sel
			pop hl
			ret
mem_al_back:
			ld hl, (mem_keep)
			call mem_sel
mem_al_fail:
			ld hl, 0
			ld (mem_hi), hl
			ret

; mem_try - HL = a D page: select it, then mem_fit
mem_try:
			call mem_sel
			jp mem_fit

; Free(ptr): a block Alloc gave back. A page with nothing left in use
; goes back to free. OK, or BadPage (not a block in use in a D page)
mem_free:
			ld hl, (mem_a1)
			call mem_far
			ld a, h
			or l
			jp z, mem_chk_bad
			ld b, h
			ld c, l
			call mem_tpb
			ld a, (hl)
			cp 'D'
			jp nz, mem_chk_bad
			ld h, b
			ld l, c
			call mem_sel
			ex de, hl
			dec hl
			bit 7, (hl)
			jr z, mem_err_page
			res 7, (hl)
			ld hl, #4000			; is the whole page free now?
			ld (mem_need), hl
			push bc
			call mem_fit			; only a page with every block free fits
			pop bc
			jr nz, mem_fr_done
			ld a, 3
			call mem_remove
			call mem_tofree
mem_fr_done:
			ld hl, (mem_keep)
			call mem_sel
			ld hl, 0
			ret
mem_err_page:
			ld hl, (mem_keep)
			call mem_sel
			jp mem_chk_bad

; Largest(): the biggest block Alloc could give now
mem_largest:
			ld hl, 0
			ld (mem_max), hl
			call mem_freepages		; a free page: a whole page
			ld a, h
			or l
			ld hl, #3FFE
			ret nz
			ld bc, 0
mem_lg_lp:
			call mem_dnext
			jr z, mem_lg_end
			ld h, b
			ld l, c
			call mem_sel
			push bc
			call mem_big
			pop bc
			jr mem_lg_lp
mem_lg_end:
			ld hl, (mem_keep)
			call mem_sel
			ld hl, (mem_max)
			ld a, h
			or l
			ret z
			dec hl
			dec hl
			ret

ntc_rg619_e:
			IF ($ < 32768) && (ntc_rg620_e - ntc_rg620 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg620:
;## ntc_membank ntc_plat_rmr @shared @romram
; ------------------------------------------------------------
; ntc_membank - Memory's CallBank switch (CPCExpansion). Runs from RAM
; (a keyword ROM can't be seen once both ROMs are off). BC = the C2
; setting and port for the bank, DE = the address in the bank, HL = value.
; ntc_bk_stub .. ntc_bk_end is also copied into the bank at the same
; address: each out is followed by the next byte from the other 64K.
; ------------------------------------------------------------
ntc_bk_go:
			ld a, i					; P/V = interrupts were on
			di
			push af
			ld (mem_bksp), sp
			call ntc_plat_rmr
			ld (mem_bkrmr), a
			or #0C					; both ROMs off
			push bc
			ld b, #7F
			out (c), a
			pop bc
ntc_bk_stub:
			out (c), c				; the bank is all 64K now
			ld sp, 0
			ld bc, ntc_bk_ret
			push bc
			push de
			ret						; to the bank's code, HL = value
ntc_bk_ret:
			ld bc, #7FC0
			out (c), c				; main RAM again
ntc_bk_end:
			ld sp, (mem_bksp)
			ld a, (mem_bkrmr)
			ld b, #7F
			out (c), a				; the ROMs as they were
			ld bc, (ntc_rampt)
			out (c), c				; and the window's page
			pop af
			jp po, ntc_bk_di
			ei
ntc_bk_di:
			ret

ntc_rg620_e:
			IF ($ < 32768) && (ntc_rg621_e - ntc_rg621 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg621:
;## ntc_keys ntc_data @shared
; ------------------------------------------------------------
; ntc_keys - the Keys class (CPC): the keyboard matrix read straight from the
; hardware (PSG register 14 through the PPI), all 10 lines each time, so it
; works with or without the firmware, in turbo and normal mode. Entered
; with jp from a method, with the method's result pointer still on the
; thread: the result goes there and ret carries on. No stack used.
;   ntc_kdown - HL = a key number 0-79 (the CPC's, as INKEY(n)): -1 held, 0 not
;   ntc_kjoy  - HL = joystick 0 / 1: bits up 1, down 2, left 4, right 8,
;               fire 2 16, fire 1 32 (as JOY(n))
; ------------------------------------------------------------
ntc_kmat:		ds 10			; the matrix (0 = pressed)
ntc_karg:		db 0
ntc_kwhat:		db 0

ntc_kdown:
			ld a, h
			or a
			jr nz, ntc_kd_no
			ld a, l
			cp 80
			jr nc, ntc_kd_no
			ld (ntc_karg), a
			xor a
			jr ntc_kscan
ntc_kjoy:
			ld a, l
			and 1
			ld (ntc_karg), a
			ld a, 1
ntc_kscan:
			ld (ntc_kwhat), a
			ld bc, #F40E		; PSG register 14
			out (c), c
			ld bc, #F6C0		; PSG: select register
			out (c), c
			ld bc, #F600		; PSG: inactive
			out (c), c
			ld bc, #F792		; PPI port A input
			out (c), c
			ld hl, ntc_kmat
			ld a, #40			; PSG read + line 0
ntc_ksc_line:
			ld b, #F6
			out (c), a
			ld b, #F4
			in d, (c)
			ld (hl), d
			inc hl
			inc a
			cp #4A
			jr nz, ntc_ksc_line
			ld bc, #F782		; PPI port A output
			out (c), c
			ld bc, #F600
			out (c), c
			ld a, (ntc_kwhat)
			or a
			jr nz, ntc_kj_got
			ld a, (ntc_karg)	; line = n / 8, bit = n and 7
			ld c, a
			rrca
			rrca
			rrca
			and 31
			ld e, a
			ld d, 0
			ld hl, ntc_kmat
			add hl, de
			ld a, c
			and 7
			ld b, a
			inc b
			ld a, (hl)
ntc_kd_rot:
			rrca
			djnz ntc_kd_rot
			ld de, 0
			jr c, ntc_k_set		; 1 = not pressed
			dec de
			jr ntc_k_set
ntc_kd_no:
			ld de, 0
			jr ntc_k_set
ntc_kj_got:
			ld a, (ntc_karg)	; joystick 0 = line 9, 1 = line 6
			ld hl, ntc_kmat + 9
			or a
			jr z, ntc_kj_line
			ld hl, ntc_kmat + 6
ntc_kj_line:
			ld a, (hl)
			cpl
			and #3F
			ld e, a
			ld d, 0
ntc_k_set:
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			ret

ntc_rg621_e:
			IF ($ < 32768) && (ntc_rg622_e - ntc_rg622 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg622:
;## ntc_memcopy ntc_mem ntc_buf2k @shared @far
; Copy(src, dst, length): far pointer to far pointer, up to NTC_BUFSIZE at a
; time through ntc_buf (so page to page works with one window). A page's end
; (#8000) carries on at #4000 of the next page. The window is put back.
; OK, or BadPage.
mem_copy:
			ld hl, (mem_a1)
			call mem_far
			ld (mem_srca), de
			ld (mem_srcp), hl
			ld hl, (mem_a2)
			call mem_far
			ld (mem_dsta), de
			ld (mem_dstp), hl
			ld hl, (mem_a3)
			ld (mem_left), hl
mem_cp_lp:
			ld hl, (mem_left)
			ld a, h
			or l
			jr z, mem_cp_done
			ld de, NTC_BUFSIZE
			call mem_min
			ld de, (mem_srcp)
			ld a, d
			or e
			ld de, (mem_srca)
			call nz, mem_room
			ld de, (mem_dstp)
			ld a, d
			or e
			ld de, (mem_dsta)
			call nz, mem_room
			ld (mem_chunk), hl
			ld hl, (mem_srcp)
			ld a, h
			or l
			call nz, mem_cp_sel
			ld hl, (mem_srca)
			ld de, ntc_buf
			ld bc, (mem_chunk)
			ldir
			ld (mem_srca), hl
			ld hl, (mem_dstp)
			ld a, h
			or l
			call nz, mem_cp_sel
			ld hl, ntc_buf
			ld de, (mem_dsta)
			ld bc, (mem_chunk)
			ldir
			ld (mem_dsta), de
			ld hl, mem_srcp
			ld de, (mem_srca)
			call mem_cp_wrap
			ld (mem_srca), de
			ld hl, mem_dstp
			ld de, (mem_dsta)
			call mem_cp_wrap
			ld (mem_dsta), de
			ld hl, (mem_left)
			ld de, (mem_chunk)
			or a
			sbc hl, de
			ld (mem_left), hl
			jp mem_cp_lp
mem_cp_done:
			ld hl, (mem_keep)
			call mem_sel
			ld hl, 0
			ret
mem_cp_sel:
			call mem_chk			; a page past the last one: BadPage
			jp mem_sel
; HL = the smaller of HL and DE
mem_min:
			push hl
			or a
			sbc hl, de
			pop hl
			ret c
			ex de, hl
			ret
; DE = an address in the window: HL = no more than #8000 - DE
mem_room:
			push hl
			ld hl, #8000
			or a
			sbc hl, de
			ex de, hl
			pop hl
			jr mem_min
; HL = a page word, DE = the address: #8000 in a page -> #4000 of the next
mem_cp_wrap:
			ld a, (hl)
			inc hl
			or (hl)
			dec hl
			ret z
			ld a, d
			cp #80
			ret nz
			inc (hl)
			jr nz, mem_cw_hi
			inc hl
			inc (hl)
mem_cw_hi:
			ld d, #40
			ret

ntc_rg622_e:
			IF ($ < 32768) && (ntc_rg623_e - ntc_rg623 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg623:
;## ntc_islots ntc_data @shared
; ------------------------------------------------------------
; ntc_islots - interrupt classes (Option Class Interrupt rate | Frame | Share n):
; up to 16 classes whose Tick Sub runs at the next safe point after it is due
; (normal mode). Slot n, 8 bytes at ntc_isl + n * 8:
;   +0 count (dw)  +2 reload (dw: interrupts between runs, 0 = every frame,
;   #8000 + weight = a shared class)  +4 running (db: Tick started, its return
;   stub clears it)  +5 due (db)  +6 Tick's call stub (dw)
; Fixed classes (a rate, Frame) are counted every interrupt. Shared classes take
; turns in the interrupts no fixed class fell due in: the current one is marked
; due on each such interrupt until it has had its weight of turns, then the
; next shared one. The start code fills the slots and puts ntc_isl_tick in
; ntc_irqv, which the platform's interrupt handler calls. The counts start a
; slot apart so classes of the same rate take turns.
; ------------------------------------------------------------
ntc_isln:		db 0			; slots in use
ntc_isldue:		db 0			; 1 = a slot may be due
ntc_islvs:		db 0			; vertical sync at the last interrupt
ntc_islfr:		db 0			; 1 = this interrupt is the frame's (sync just started)
ntc_islph:		db 0			; interrupts since the frame's (0-5)
ntc_islfx:		db 0			; 1 = a fixed class fell due in this interrupt
ntc_islsc:		db 0			; the shared class having its turns (slot number)
ntc_islsw:		db 0			; turns it has left
ntc_islshn:		db 0			; shared classes (0 = none)
ntc_isl:		ds 128			; 16 slots

; ntc_isl_tick - from the interrupt handler (call, real stack): count each
; slot, mark the ones due. Keeps BC, DE, IX, IY.
ntc_isl_tick:
			push bc
			push de
			ld b, #F5				; PPI port B bit 0: vertical sync
			in a, (c)
			and 1
			ld e, a
			ld a, (ntc_islvs)
			cpl
			and e
			ld d, a					; 1 = the sync started since the last interrupt
			ld a, e
			ld (ntc_islvs), a
			ld a, (ntc_islph)		; a frame is 6 interrupts: count them, so a frame is
			inc a					; still seen when this interrupt came in after the
			cp 6					; sync had ended (taken late: a long keyword); the
			jr c, ntc_it_ph			; sync puts the count back to 0
			xor a
ntc_it_ph:
			bit 0, d
			jr z, ntc_it_ph2
			xor a
ntc_it_ph2:
			ld (ntc_islph), a
			or a
			ld a, 0
			jr nz, ntc_it_fr
			inc a
ntc_it_fr:
			ld (ntc_islfr), a
			xor a
			ld (ntc_islfx), a
			ld a, (ntc_isln)
			or a
			jp z, ntc_it_end
			ld b, a
			ld hl, ntc_isl
ntc_it_lp:
			push hl
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			bit 7, d				; a shared class: the turns below mark it
			jr nz, ntc_it_nx
			ld a, d
			or e
			jr nz, ntc_it_rate
			ld a, (ntc_islfr)		; every frame: when the sync starts
			or a
			jr z, ntc_it_nx
			jr ntc_it_due
ntc_it_rate:
			ld e, (hl)
			inc hl
			ld d, (hl)
			dec de
			ld (hl), d
			dec hl
			ld (hl), e
			ld a, d
			or e
			jr nz, ntc_it_nx
			push hl					; due: count again from the reload
			inc hl
			inc hl
			ld e, (hl)
			inc hl
			ld d, (hl)
			pop hl
			ld (hl), e
			inc hl
			ld (hl), d
			dec hl
ntc_it_due:
			push hl
			ld de, 5
			add hl, de
			ld (hl), 1
			pop hl
			ld a, 1
			ld (ntc_isldue), a
			ld (ntc_islfx), a
ntc_it_nx:
			ld de, 8
			add hl, de
			djnz ntc_it_lp
			; shared classes: an interrupt no fixed class used is a turn
			ld a, (ntc_islfx)
			or a
			jp nz, ntc_it_end
			ld a, (ntc_islshn)
			or a
			jp z, ntc_it_end
			ld a, (ntc_islsw)
			or a
			jr nz, ntc_it_take
			ld a, (ntc_islsc)		; its turns are used: the next shared class
ntc_it_find:
			inc a
			ld hl, ntc_isln
			cp (hl)
			jr c, ntc_it_fi2
			xor a
ntc_it_fi2:
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_isl + 2
			add hl, de
			ld e, (hl)				; E = the weight
			inc hl
			bit 7, (hl)
			jr z, ntc_it_find		; not shared (there is one: ntc_islshn)
			ld (ntc_islsc), a
			ld a, e
ntc_it_take:
			dec a
			ld (ntc_islsw), a
			ld a, (ntc_islsc)
			ld l, a
			ld h, 0
			add hl, hl
			add hl, hl
			add hl, hl
			ld de, ntc_isl + 5
			add hl, de
			ld (hl), 1				; due
			ld a, 1
			ld (ntc_isldue), a
ntc_it_end:
			pop de
			pop bc
			ret

ntc_rg623_e:
			IF ($ < 32768) && (ntc_rg624_e - ntc_rg624 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg624:
;## kw_bssinit ntc_data ntc_plat_memtop ntc_plat_screen kw_stop @shared
;kw_bssinit, <start>, <size>  - the start of the main thread: the program's arrays live after
;  it (from ntc_end, not in its file). Check they fit under the platform's top (and 256 bytes
;  under the real stack when that is above them), then clear them. Too big: a message, the
;  program stops.
kw_bssinit:
			pop hl
			ld (ntc_bsa), hl
			pop bc
			ld (ntc_bsz), bc
			ld (ntc_bsp), sp
			ld sp, (ntc_csp)
			add hl, bc				; HL = their end
			ex de, hl
			call ntc_plat_memtop	; HL = the platform's top
			or a
			sbc hl, de
			jr c, ntc_bs_big
			ld hl, (ntc_csp)		; the real stack, when above them
			ld bc, (ntc_bsa)
			or a
			sbc hl, bc
			jr c, ntc_bs_ok
			ld hl, (ntc_csp)
			ld bc, -256
			add hl, bc
			or a
			sbc hl, de
			jr c, ntc_bs_big
ntc_bs_ok:
			ld bc, (ntc_bsz)
			ld a, b
			or c
			jr z, ntc_bs_done
			ld hl, (ntc_bsa)
			ld (hl), 0
			dec bc
			ld a, b
			or c
			jr z, ntc_bs_done
			ld d, h
			ld e, l
			inc de
			ldir
ntc_bs_done:
			ld sp, (ntc_bsp)
			ret
ntc_bs_big:
			ld hl, ntc_bstxt
ntc_bs_pl:
			ld a, (hl)
			or a
			jr z, ntc_bs_stop
			inc hl
			ld (ntc_bsa), hl
			ld ix, ntc_bs_pn
			jp ntc_plat_putc
ntc_bs_pn:
			ld hl, (ntc_bsa)
			jr ntc_bs_pl
ntc_bs_stop:
			ld ix, kw_stop
			jp ntc_plat_newline
ntc_bsa:		dw 0
ntc_bsz:		dw 0
ntc_bsp:		dw 0
ntc_bstxt:		db "Not enough memory for the arrays", 0

ntc_rg624_e:
			IF ($ < 32768) && (ntc_rg625_e - ntc_rg625 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg625:
;## ntc_plat_data
ntc_curx:		db 0			; cursor column (0 based) - kept here for Tab
ntc_cury:		db 0			; cursor row (0 based)
ntc_scols:		db 40			; columns in this mode
ntc_smode:		db 1			; screen mode (for the Graphics class)
ntc_fwa:		db 0			; ntc_fwcall: A on return
ntc_fwwrap:		db 0			; 1 = the last character made the firmware wrap
ntc_irqset:		db 0			; 1 = the firmware's fast ticker calls ntc_fwevt
ntc_irqv:		dw 0			; interrupt classes' counting (ntc_isl_tick), 0 = none
ntc_irqix:		dw 0
NTC_FWBLK	equ #A5F0		; the fast ticker's event block (central 32K, below the firmware)
ntc_fwtop:		dw #A600		; the top of free RAM (#A5F0 with the fast ticker's block)
ntc_fwblk:		dw NTC_FWBLK		; the fast ticker's event block: lower (and the top with it) when the ROMs
								; started take more RAM than AMSDOS's #A700-#ABFF (Option RomEnable)

ntc_rg625_e:
			IF ($ < 32768) && (ntc_rg626_e - ntc_rg626 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg626:
;## ntc_plat_fw ntc_plat_data ntc_data @shared
; ------------------------------------------------------------
; ntc_fwcall - IY = firmware address; A, BC, DE, HL go in and come
; back as the firmware leaves them (A also in ntc_fwa, carry kept).
; IX is kept. Interrupts are on during the call.
; ------------------------------------------------------------
ntc_fwcall:
			ld (ntc_hostix), ix
			ld (ntc_ip), sp
			ld sp, (ntc_csp)
			ei
			call ntc_fwjp
			di
			ld sp, (ntc_ip)
			ld (ntc_fwa), a
			ld ix, (ntc_hostix)
			jp (ix)
ntc_fwjp:
			jp (iy)

ntc_rg626_e:
			IF ($ < 32768) && (ntc_rg627_e - ntc_rg627 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg627:
;## ntc_plat_screen ntc_plat_fw ntc_plat_data ntc_data
; ntc_plat_putc - A = character: TXT OUTPUT. The firmware wraps by itself after
; the last column, so only the column is counted here; a new line straight after
; that wrap is left out (it would leave an empty line)
ntc_plat_putc:
			ld iy, #BB5A			; TXT OUTPUT
			ld (ntc_pclink), ix
			ld ix, ntc_pc_back
			jp ntc_fwcall
ntc_pc_back:
			ld ix, (ntc_pclink)
			xor a
			ld (ntc_fwwrap), a
			ld a, (ntc_scols)
			ld b, a
			ld a, (ntc_curx)
			inc a
			ld (ntc_curx), a
			cp b
			jr nz, ntc_pc_done
			xor a				; the firmware wrapped to the next line
			ld (ntc_curx), a
			inc a
			ld (ntc_fwwrap), a
ntc_pc_done:
			jp (ix)

; ntc_plat_newline - CR LF (the firmware scrolls); nothing straight after a wrap
ntc_plat_newline:
			ld a, (ntc_fwwrap)
			or a
			jr z, ntc_nl_go
			xor a
			ld (ntc_fwwrap), a
			jp (ix)
ntc_nl_go:
			ld (ntc_pclink), ix
			ld a, 13
			ld iy, #BB5A
			ld ix, ntc_nl_lf
			jp ntc_fwcall
ntc_nl_lf:
			ld a, 10
			ld iy, #BB5A
			ld ix, ntc_nl_done
			jp ntc_fwcall
ntc_nl_done:
			xor a
			ld (ntc_curx), a
			ld a, (ntc_cury)
			inc a
			cp 25
			jr c, ntc_nl_row
			ld a, 24
ntc_nl_row:
			ld (ntc_cury), a
			ld ix, (ntc_pclink)
			jp (ix)

ntc_pclink:		dw 0

ntc_rg627_e:
			IF ($ < 32768) && (ntc_rg628_e - ntc_rg628 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg628:
;## ntc_plat_mode @unit ntc_plat_screen ntc_plat_fw ntc_plat_data ntc_data
; ntc_plat_mode - A = mode 0-2 (3 = 2): SCR SET MODE (clears)
ntc_plat_mode:
			cp 3
			jr c, ntc_md_ok
			ld a, 2
ntc_md_ok:
			ld b, 20
			or a
			jr z, ntc_md_set
			ld b, 40
			cp 1
			jr z, ntc_md_set
			ld b, 80
ntc_md_set:
			ld (ntc_smode), a
			ld c, a
			ld a, b
			ld (ntc_scols), a
			xor a
			ld (ntc_fwwrap), a
			ld (ntc_curx), a
			ld (ntc_cury), a
			ld a, c
			ld iy, #BC0E			; SCR SET MODE
			jp ntc_fwcall

ntc_rg628_e:
			IF ($ < 32768) && (ntc_rg629_e - ntc_rg629 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg629:
;## ntc_plat_key ntc_plat_fw ntc_data
; ntc_plat_scankey - A = key from the firmware's buffer, or 0
ntc_plat_scankey:
			ld (ntc_kslink), ix
			ld iy, #BB09			; KM READ CHAR
			ld ix, ntc_ks_back
			jp ntc_fwcall
ntc_ks_back:
			ld ix, (ntc_kslink)
			jr c, ntc_ks_got
			xor a
			jp (ix)
ntc_ks_got:
			ld a, (ntc_fwa)
			jp (ix)

; ntc_plat_getkey - wait for a key: KM WAIT CHAR
ntc_plat_getkey:
			ld iy, #BB06			; KM WAIT CHAR
			jp ntc_fwcall
ntc_kslink:		dw 0

ntc_rg629_e:
			IF ($ < 32768) && (ntc_rg630_e - ntc_rg630 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg630:
;## ntc_plat_frame ntc_plat_fw
; ntc_plat_frame - MC WAIT FLYBACK
ntc_plat_frame:
			ld iy, #BD19
			jp ntc_fwcall

ntc_rg630_e:
			IF ($ < 32768) && (ntc_rg631_e - ntc_rg631 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg631:
;## ntc_plat_ticks ntc_plat_fw
; ntc_plat_ticks - HL = the firmware's 1/300 s clock (KL TIME PLEASE, low word)
ntc_plat_ticks:
			ld iy, #BD0D
			jp ntc_fwcall

ntc_rg631_e:
			IF ($ < 32768) && (ntc_rg632_e - ntc_rg632 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg632:
;## ntc_plat_exit ntc_plat_data ntc_plat_fw
ntc_plat_exit:
			ld bc, #7FC0		; RAM setting back to plain (a Memory page may be in #4000)
			out (c), c
			ld a, (ntc_irqset)	; the fast ticker out of the firmware's list
			or a
			jr z, ntc_ex_done
			xor a
			ld (ntc_irqset), a
			ld (ntc_irqix), ix
			ld hl, (ntc_fwblk)
			ld iy, #BCE6		; KL DEL FAST TICKER
			ld ix, ntc_ex_back
			jp ntc_fwcall
ntc_ex_back:
			ld ix, (ntc_irqix)
ntc_ex_done:
			jp (ix)

ntc_rg632_e:
			IF ($ < 32768) && (ntc_rg633_e - ntc_rg633 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg633:
;## ntc_plat_irq ntc_plat_data ntc_plat_fw ntc_data @shared
; ------------------------------------------------------------
; ntc_plat_irqon - normal mode's interrupt work under the firmware: the
; firmware keeps its own interrupt handler (keys, sound, AMSDOS), and a fast
; ticker event (KL NEW FAST TICKER, 300 a second) calls ntc_fwevt, which
; marks an Interrupt hook / interrupt classes as due - they run at the next
; safe point, as on cpc. The event block must be in the central 32K (the
; firmware reads it with the lower ROM on): #A5F0, just under the firmware's
; RAM, so the top of free RAM becomes #A5F0.
; The class is asynchronous, NOT express: the firmware (6128 ROM, KL EVENT
; at #01E2) calls an express event straight from the interrupt with the lower
; ROM on and never looks at the far address, so a routine below #4000 (this
; program starts at #0040) would run ROM code there. A plain asynchronous
; event is run at the end of the interrupt through KL FAR ICALL, which uses
; the far address: ROM select #FF = both ROMs off.
; ------------------------------------------------------------
ntc_plat_irqon:
			ld (ntc_irqix), ix
			ld hl, (ntc_fwblk)
			ld (ntc_fwtop), hl
			ld b, #80				; asynchronous, far address (not express: see above)
			ld c, #FF				; ROM select: upper and lower ROM off
			ld de, ntc_fwevt
			ld iy, #BCE0			; KL NEW FAST TICKER
			ld ix, ntc_iq_on
			jp ntc_fwcall
ntc_iq_on:
			ld a, 1
			ld (ntc_irqset), a
			ld ix, (ntc_irqix)
			jp (ix)
; the event routine: at the end of an interrupt (interrupts may be on; the
; firmware never runs it twice at once); AF, BC, DE, HL free
ntc_fwevt:
			ld a, (ntc_hookon)		; an Interrupt hook: run it at the next safe point
			or a
			jr z, ntc_fe_nohook
			ld (ntc_hookpend), a
ntc_fe_nohook:
			ld hl, (ntc_irqv)		; interrupt classes: count them
			ld a, h
			or l
			ret z
			jp (hl)
			ASSERT ntc_free <= NTC_FWBLK, "Interrupt / interrupt classes on cpcfw: the program and its arrays must end below #A5F0 (the firmware event block)"

; ============================================================
; File system (FileSystem class) - Load / Save through the firmware's
; cassette calls (CAS IN / CAS OUT DIRECT). With AMSDOS present they
; go to the disc (the drive that is selected), else to tape, exactly
; as BASIC's LOAD / SAVE do - with the firmware's own messages
; ("Press PLAY then any key", disc errors and Retry / Cancel).
;
; RUN"NAME of a binary resets the firmware (MC BOOT PROGRAM), which
; drops the background ROMs - AMSDOS too - so the cassette calls go
; back to tape. Loaded from BASIC and CALLed (MEMORY &1FFF : LOAD"NAME"
; : CALL &2000, built at org #2000), AMSDOS keeps running. Option
; RomEnable starts the ROMs again in the start code. The first file
; call checks: CAS IN OPEN (#BC77) a far call (RST 3, #DF) = AMSDOS has
; the cassette calls. AMSDOS's RAM is about #A700-#ABFF: the program
; must end below #A600 (checked when assembling). Devices: AMSDOS's own
; commands |TAPE, |DISC, |A, |B (KL FIND COMMAND, then KL FAR PCALL).
; ============================================================
; The methods are keywords: arguments into fs_a1 .. fs_a3, the
; result's address into fs_res, then fs_go with HL = the routine.
; fs_go runs it on the real stack with interrupts on and stores its
; HL result; a routine that fails jumps to fs_err with HL = status.

ntc_rg633_e:
			IF ($ < 32768) && (ntc_rg634_e - ntc_rg634 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg634:
;## ntc_plat_memtop ntc_plat_data
; ntc_plat_memtop - HL = the first byte the Memory class's Small heap must not
; use: #A600 (the firmware's and AMSDOS's RAM is above), #A5F0 when the fast
; ticker's event block is there (Interrupt, interrupt classes). Called on the
; real stack (call / ret).
ntc_plat_memtop:
			ld hl, (ntc_fwtop)
			ret

ntc_rg634_e:
			IF ($ < 32768) && (ntc_rg635_e - ntc_rg635 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg635:
;## ntc_plat_rmr ntc_plat_data
; ntc_plat_rmr - A = the gate array's ROM / mode byte now: the firmware keeps
; it in C' (B' = #7F), so Memory's CallBank can turn both ROMs off and put
; them back. Keeps BC, DE, HL.
ntc_plat_rmr:
			exx
			ld a, c
			exx
			ret


ntc_rg635_e:
ntc_end:				; the end of the program (and of its file)
			IF $ < #4000	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= #8000, "the window data (; @window) must fit in the window"
			ENDIF
ntc_fileend:			; the file ends here (the window data in it)
; arrays: after the program, not in its file - kw_bssinit checks they fit and clears them
ntc_bssfrom	equ ntc_end
			IF (ntc_bssfrom < 32768) && (ntc_bssfrom + ntc_bss_size > 16384)	; fwdref-ok
ntc_bss		equ 32768		; after Option Reserve #4000-#7FFF
			ELSE
ntc_bss		equ ntc_bssfrom
			ENDIF
arr_bk		equ ntc_bss + 0		; 42 bytes
arr_sg		equ ntc_bss + 42		; 42 bytes
arr_st		equ ntc_bss + 84		; 42 bytes
arr_kq		equ ntc_bss + 126		; 42 bytes
arr_wp		equ ntc_bss + 168		; 42 bytes
arr_dm		equ ntc_bss + 210		; 42 bytes
arr_dv		equ ntc_bss + 252		; 42 bytes
arr_ra		equ ntc_bss + 294		; 42 bytes
arr_wk		equ ntc_bss + 336		; 42 bytes
arr_tn		equ ntc_bss + 378		; 42 bytes
arr_nb		equ ntc_bss + 420		; 42 bytes
arr_nc		equ ntc_bss + 462		; 42 bytes
arr_lt		equ ntc_bss + 504		; 42 bytes
arr_lb		equ ntc_bss + 546		; 42 bytes
arr_lc		equ ntc_bss + 588		; 42 bytes
arr_rb		equ ntc_bss + 630		; 128 bytes
arr_ent_en		equ ntc_bss + 758		; 12 bytes
ntc_bss_size	equ 770
ntc_free	equ ntc_bss + ntc_bss_size	; the first free byte (heap, Memory tables)
			IF ntc_free <= 32768	; fwdref-ok
ntc_memtab	equ 32768		; the Memory class's tables: above the window (Option Reserve)
			ELSE
ntc_memtab	equ ntc_free
			ENDIF
; Option Reserve: the program and its arrays (ntc_start .. ntc_free) must stay out of these
			ASSERT (ntc_free <= 16384) || (ntc_bss >= 32768), "the program (or its arrays) reaches into Option Reserve #4000-#7FFF (Main.bas line 25)"
			SAVEAMSDOS "CYBORGOS.BIN", ntc_start, ntc_fileend - ntc_start, ntc_start

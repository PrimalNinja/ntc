; the window data (; @window ... ; @endwindow in #asm): put in the window hole by its guard
			MACRO ntc_windata
; (the hypervisor's page from #5300 - #4000 the disc buffers, #5000 the font: Install copies
; these into each bank from there, FileCall 99 put them there at the start)
            ds #5300 - $		; Hyp.cls 1719
; page zero (#0000-#0080)
fn_hyp_info_hi_p0:		; Hyp.cls 1721
            db #C3		; Hyp.cls 1722
            dw fn_hyp_info_sb_bwb                           ; #0000: warm boot - the BIOS's WBOOT (the task [1723]
            db 0, 0                             ; ends); (#0001) - 3: the BIOS jump table [1724]
            db #C3		; Hyp.cls 1725
            dw fn_hyp_info_sb_start                         ; #0005: BDOS (#0006: the top of the TPA) [1726]
            ds #38 - 8		; Hyp.cls 1727
            db #C3		; Hyp.cls 1728
            dw fn_hyp_info_sb_int                           ; #0038: the interrupt [1729]
            ds #44 - #3B		; Hyp.cls 1730
            db #ED, #49                         ; #0044: out (c), c [1731]
            db #C3		; Hyp.cls 1732
            dw fn_hyp_info_sb_land                          ; #0046: this bank switched in [1733]
            ds #5C - #49		; Hyp.cls 1734
            db 0, "           "                 ; #005C: the default FCB [1735]
            ds #80 - #68		; Hyp.cls 1736
            db 0                                ; #0080: no command tail [1737]
fn_hyp_info_hi_p0e:		; Hyp.cls 1738
; the stubs: assembled here, run at STUB in the bank (DISP: their labels are the bank's
; addresses). The BDOS: what needs nothing of the hypervisor is answered here, with no
; switch - the console out (2, 9: collected at OBUF; the hypervisor gets them, IX = how many, at
; the next far call or interrupt, or when 128 wait), the keys (1, 6, 10, 11: from KEY, where
; the hypervisor leaves the slot's next key), the IOBYTE (7, 8), the disc's parameters (27, 31)
; and the calls with nothing to do (3, 4, 5, 28, 29, 30, 37 - 30 with #C0 on at DE is CyborgOS's
; UniDOS call), CP/M 3's 49 for the console's size (MODE); the rest is a far call. Then the
; BIOS (its jump table: (#0001) - 3) and the start-up (the default FCBs)
fn_hyp_info_sb_img:		; Hyp.cls 1747
            DISP 61184		; Hyp.cls 1748
fn_hyp_info_sb_start:		; Hyp.cls 1749
            di                                  ; BDOS: C = function, DE = argument [1750]
            ld a, c		; Hyp.cls 1751
            cp 2		; Hyp.cls 1752
            jp z, fn_hyp_info_sb_put		; Hyp.cls 1753
            cp 6		; Hyp.cls 1754
            jr z, fn_hyp_info_sb_f6		; Hyp.cls 1755
            cp 11		; Hyp.cls 1756
            jr z, fn_hyp_info_sb_stat		; Hyp.cls 1757
            cp 1		; Hyp.cls 1758
            jr z, fn_hyp_info_sb_f1		; Hyp.cls 1759
            cp 9		; Hyp.cls 1760
            jp z, fn_hyp_info_sb_str		; Hyp.cls 1761
            cp 10		; Hyp.cls 1762
            jp z, fn_hyp_info_sb_line		; Hyp.cls 1763
            cp 3		; Hyp.cls 1764
            jr z, fn_hyp_info_sb_rdr		; Hyp.cls 1765
            cp 7		; Hyp.cls 1766
            jr z, fn_hyp_info_sb_iob		; Hyp.cls 1767
            cp 8		; Hyp.cls 1768
            jr z, fn_hyp_info_sb_siob		; Hyp.cls 1769
            cp 27		; Hyp.cls 1770
            jr z, fn_hyp_info_sb_alv		; Hyp.cls 1771
            cp 31		; Hyp.cls 1772
            jr z, fn_hyp_info_sb_dpb		; Hyp.cls 1773
            cp 4		; Hyp.cls 1774
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1775
            cp 5		; Hyp.cls 1776
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1777
            cp 28		; Hyp.cls 1778
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1779
            cp 29		; Hyp.cls 1780
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1781
            cp 30		; Hyp.cls 1782
            jr z, fn_hyp_info_sb_f30		; Hyp.cls 1783
            cp 37		; Hyp.cls 1784
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1785
            cp 49		; Hyp.cls 1786
            jp z, fn_hyp_info_sb_scb		; Hyp.cls 1787
            jp fn_hyp_info_sb_call		; Hyp.cls 1788
fn_hyp_info_sb_f30:                                         ; 30: nothing - unless #C0 on at DE: CyborgOS's [1789]
            ld a, (de)                          ; UniDOS call (CD, DIR: the hypervisor's) [1790]
            cp #C0		; Hyp.cls 1791
            jp nc, fn_hyp_info_sb_call		; Hyp.cls 1792
fn_hyp_info_sb_zero:		; Hyp.cls 1793
            xor a                               ; 4, 5 (the printer: not yet), 28, 29, 30, 37 [1794]
fn_hyp_info_sb_ret:		; Hyp.cls 1795
            ld l, a		; Hyp.cls 1796
            ld h, 0		; Hyp.cls 1797
            ei		; Hyp.cls 1798
            ret		; Hyp.cls 1799
fn_hyp_info_sb_rdr:		; Hyp.cls 1800
            ld a, #1A                           ; 3: the reader - the end of a file [1801]
            jr fn_hyp_info_sb_ret		; Hyp.cls 1802
fn_hyp_info_sb_iob:		; Hyp.cls 1803
            ld a, (#0003)                       ; 7: the IOBYTE [1804]
            jr fn_hyp_info_sb_ret		; Hyp.cls 1805
fn_hyp_info_sb_siob:		; Hyp.cls 1806
            ld a, e                             ; 8 [1807]
            ld (#0003), a		; Hyp.cls 1808
            jr fn_hyp_info_sb_zero		; Hyp.cls 1809
fn_hyp_info_sb_alv:		; Hyp.cls 1810
            ld hl, fn_hyp_info_sb_alvec                     ; 27: the allocation vector (a CPC data disc's) [1811]
            ei		; Hyp.cls 1812
            ret		; Hyp.cls 1813
fn_hyp_info_sb_dpb:		; Hyp.cls 1814
            ld hl, fn_hyp_info_sb_dpbv                      ; 31: the disc parameter block [1815]
            ei		; Hyp.cls 1816
            ret		; Hyp.cls 1817
fn_hyp_info_sb_f6:		; Hyp.cls 1818
            ld a, e		; Hyp.cls 1819
            cp #FF		; Hyp.cls 1820
            jr z, fn_hyp_info_sb_get		; Hyp.cls 1821
            cp #FE		; Hyp.cls 1822
            jr c, fn_hyp_info_sb_put		; Hyp.cls 1823
fn_hyp_info_sb_stat:		; Hyp.cls 1824
            ld a, (63105)                       ; 6 / #FE, 11: is a key waiting (#FF / 0) [1825]
            or a		; Hyp.cls 1826
            jr z, fn_hyp_info_sb_ret		; Hyp.cls 1827
            ld a, #FF		; Hyp.cls 1828
            jr fn_hyp_info_sb_ret		; Hyp.cls 1829
fn_hyp_info_sb_get:		; Hyp.cls 1830
            ld hl, 63105                        ; 6 / #FF: the key or 0 (no wait) [1831]
            ld a, (hl)		; Hyp.cls 1832
            ld (hl), 0		; Hyp.cls 1833
            jr fn_hyp_info_sb_ret		; Hyp.cls 1834
fn_hyp_info_sb_f1:		; Hyp.cls 1835
            call fn_hyp_info_sb_key                         ; 1: a key (waited for), echoed [1836]
            push af		; Hyp.cls 1837
            ld e, a		; Hyp.cls 1838
            call fn_hyp_info_sb_putc		; Hyp.cls 1839
            pop af		; Hyp.cls 1840
            jr fn_hyp_info_sb_ret		; Hyp.cls 1841
fn_hyp_info_sb_put:		; Hyp.cls 1842
            call fn_hyp_info_sb_putc                        ; 2: E out [1843]
            ei		; Hyp.cls 1844
            ret		; Hyp.cls 1845
fn_hyp_info_sb_str:		; Hyp.cls 1846
            ld h, d                             ; 9: the string at DE, to "$" [1847]
            ld l, e		; Hyp.cls 1848
fn_hyp_info_sb_st_lp:		; Hyp.cls 1849
            ld a, (hl)		; Hyp.cls 1850
            cp '$'		; Hyp.cls 1851
            jr z, fn_hyp_info_sb_zero		; Hyp.cls 1852
            push hl		; Hyp.cls 1853
            ld e, a		; Hyp.cls 1854
            call fn_hyp_info_sb_putc		; Hyp.cls 1855
            pop hl		; Hyp.cls 1856
            inc hl		; Hyp.cls 1857
            jr fn_hyp_info_sb_st_lp		; Hyp.cls 1858
; sb_putc - E collected at OBUF (the hypervisor shown them when 128 wait). Interrupts off
fn_hyp_info_sb_putc:		; Hyp.cls 1860
            ld hl, 62976 + 128                 ; the count [1861]
            ld a, (hl)		; Hyp.cls 1862
            inc (hl)		; Hyp.cls 1863
            ld l, a		; Hyp.cls 1864
            ld h, 62976 / 256		; Hyp.cls 1865
            ld (hl), e		; Hyp.cls 1866
            cp 127		; Hyp.cls 1867
            ret c		; Hyp.cls 1868
            push bc		; Hyp.cls 1869
            push de		; Hyp.cls 1870
            ld c, #80                           ; full: function #80, only the characters [1871]
            call fn_hyp_info_sb_call		; Hyp.cls 1872
            di		; Hyp.cls 1873
            pop de		; Hyp.cls 1874
            pop bc		; Hyp.cls 1875
            ret		; Hyp.cls 1876
; sb_key - A = the next key, waited for: none at KEY - a far call (#81) that has the hypervisor
; run the others until a key comes (or the clock moves on), then look again
fn_hyp_info_sb_key:		; Hyp.cls 1879
            ld hl, 63105		; Hyp.cls 1880
            ld a, (hl)		; Hyp.cls 1881
            or a		; Hyp.cls 1882
            jr z, fn_hyp_info_sb_k_wait		; Hyp.cls 1883
            ld (hl), 0		; Hyp.cls 1884
            ret		; Hyp.cls 1885
fn_hyp_info_sb_k_wait:		; Hyp.cls 1886
            push bc		; Hyp.cls 1887
            push de		; Hyp.cls 1888
            ld c, #81		; Hyp.cls 1889
            call fn_hyp_info_sb_call		; Hyp.cls 1890
            di		; Hyp.cls 1891
            pop de		; Hyp.cls 1892
            pop bc		; Hyp.cls 1893
            jr fn_hyp_info_sb_key		; Hyp.cls 1894
; 10: a line typed into the buffer at DE (its size, then how many came, then them): BS / DEL
; rub out, Control + U / X the whole line, Control + C at its start ends the program, CR / LF
; end it (CR echoed)
fn_hyp_info_sb_line:		; Hyp.cls 1898
            ld (fn_hyp_info_sb_lbuf), de		; Hyp.cls 1899
            xor a		; Hyp.cls 1900
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1901
fn_hyp_info_sb_l_lp:		; Hyp.cls 1902
            call fn_hyp_info_sb_key		; Hyp.cls 1903
            cp 13		; Hyp.cls 1904
            jr z, fn_hyp_info_sb_l_end		; Hyp.cls 1905
            cp 10		; Hyp.cls 1906
            jr z, fn_hyp_info_sb_l_end		; Hyp.cls 1907
            cp 8		; Hyp.cls 1908
            jr z, fn_hyp_info_sb_l_bs		; Hyp.cls 1909
            cp 127		; Hyp.cls 1910
            jr z, fn_hyp_info_sb_l_bs		; Hyp.cls 1911
            cp 21		; Hyp.cls 1912
            jr z, fn_hyp_info_sb_l_kill		; Hyp.cls 1913
            cp 24		; Hyp.cls 1914
            jr z, fn_hyp_info_sb_l_kill		; Hyp.cls 1915
            cp 3		; Hyp.cls 1916
            jr nz, fn_hyp_info_sb_l_ch		; Hyp.cls 1917
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1918
            or a		; Hyp.cls 1919
            jr nz, fn_hyp_info_sb_l_lp		; Hyp.cls 1920
            ld c, 0                             ; Control + C: the program ends [1921]
            jp fn_hyp_info_sb_call		; Hyp.cls 1922
fn_hyp_info_sb_l_ch:		; Hyp.cls 1923
            cp 32		; Hyp.cls 1924
            jr c, fn_hyp_info_sb_l_lp		; Hyp.cls 1925
            ld b, a		; Hyp.cls 1926
            ld hl, (fn_hyp_info_sb_lbuf)		; Hyp.cls 1927
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1928
            cp (hl)		; Hyp.cls 1929
            jr nc, fn_hyp_info_sb_l_lp                      ; full [1930]
            inc a		; Hyp.cls 1931
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1932
            ld e, a		; Hyp.cls 1933
            ld d, 0		; Hyp.cls 1934
            inc hl		; Hyp.cls 1935
            add hl, de		; Hyp.cls 1936
            ld (hl), b		; Hyp.cls 1937
            ld e, b		; Hyp.cls 1938
            call fn_hyp_info_sb_putc		; Hyp.cls 1939
            jr fn_hyp_info_sb_l_lp		; Hyp.cls 1940
fn_hyp_info_sb_l_kill:		; Hyp.cls 1941
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1942
            or a		; Hyp.cls 1943
            jr z, fn_hyp_info_sb_l_lp		; Hyp.cls 1944
            call fn_hyp_info_sb_l_rub		; Hyp.cls 1945
            jr fn_hyp_info_sb_l_kill		; Hyp.cls 1946
fn_hyp_info_sb_l_bs:		; Hyp.cls 1947
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1948
            or a		; Hyp.cls 1949
            jr z, fn_hyp_info_sb_l_lp		; Hyp.cls 1950
            call fn_hyp_info_sb_l_rub		; Hyp.cls 1951
            jr fn_hyp_info_sb_l_lp		; Hyp.cls 1952
fn_hyp_info_sb_l_rub:		; Hyp.cls 1953
            dec a		; Hyp.cls 1954
            ld (fn_hyp_info_sb_lcnt), a		; Hyp.cls 1955
            ld e, 8		; Hyp.cls 1956
            call fn_hyp_info_sb_putc		; Hyp.cls 1957
            ld e, ' '		; Hyp.cls 1958
            call fn_hyp_info_sb_putc		; Hyp.cls 1959
            ld e, 8		; Hyp.cls 1960
            jp fn_hyp_info_sb_putc		; Hyp.cls 1961
fn_hyp_info_sb_l_end:		; Hyp.cls 1962
            ld hl, (fn_hyp_info_sb_lbuf)		; Hyp.cls 1963
            inc hl		; Hyp.cls 1964
            ld a, (fn_hyp_info_sb_lcnt)		; Hyp.cls 1965
            ld (hl), a		; Hyp.cls 1966
            ld e, 13		; Hyp.cls 1967
            call fn_hyp_info_sb_putc		; Hyp.cls 1968
            jp fn_hyp_info_sb_zero		; Hyp.cls 1969
fn_hyp_info_sb_lbuf:    dw 0		; Hyp.cls 1970
fn_hyp_info_sb_lcnt:    db 0		; Hyp.cls 1971
fn_hyp_info_sb_call:		; Hyp.cls 1972
            push ix                             ; a far call: IX, IY and the alternate [1973]
            push iy                             ; registers kept over it (ex af, af') [1974]
            db #08		; Hyp.cls 1975
            exx		; Hyp.cls 1976
            push af		; Hyp.cls 1977
            push bc		; Hyp.cls 1978
            push de		; Hyp.cls 1979
            push hl		; Hyp.cls 1980
            exx		; Hyp.cls 1981
            db #08		; Hyp.cls 1982
            ld a, (62976 + 128)		; Hyp.cls 1983
            ld ixl, a		; Hyp.cls 1984
            ld ixh, 0		; Hyp.cls 1985
            ld a, c		; Hyp.cls 1986
            ld hl, fn_hyp_info_sb_far		; Hyp.cls 1987
            push hl		; Hyp.cls 1988
            ld (#FFFE), sp		; Hyp.cls 1989
            ld bc, #7FC0		; Hyp.cls 1990
            scf                                 ; carry: a far call [1991]
            jp #0044		; Hyp.cls 1992
fn_hyp_info_sb_far:		; Hyp.cls 1993
            db #08                              ; the answer in A and HL; the program's [1994]
            exx                                 ; other registers back [1995]
            pop hl		; Hyp.cls 1996
            pop de		; Hyp.cls 1997
            pop bc		; Hyp.cls 1998
            pop af		; Hyp.cls 1999
            exx		; Hyp.cls 2000
            db #08		; Hyp.cls 2001
            pop iy		; Hyp.cls 2002
            pop ix		; Hyp.cls 2003
            ei		; Hyp.cls 2004
            ret		; Hyp.cls 2005
fn_hyp_info_sb_int:		; Hyp.cls 2006
            push af                             ; an interrupt: everything kept [2007]
            push bc		; Hyp.cls 2008
            push de		; Hyp.cls 2009
            push hl		; Hyp.cls 2010
            db #08                              ; ex af, af' [2011]
            exx		; Hyp.cls 2012
            push af		; Hyp.cls 2013
            push bc		; Hyp.cls 2014
            push de		; Hyp.cls 2015
            push hl		; Hyp.cls 2016
            push ix		; Hyp.cls 2017
            push iy		; Hyp.cls 2018
            ld a, (62976 + 128)		; Hyp.cls 2019
            ld ixl, a		; Hyp.cls 2020
            ld ixh, 0		; Hyp.cls 2021
            ld hl, fn_hyp_info_sb_rest		; Hyp.cls 2022
            push hl		; Hyp.cls 2023
            ld (#FFFE), sp		; Hyp.cls 2024
            ld bc, #7FC0		; Hyp.cls 2025
            or a                                ; no carry: an interrupt [2026]
            jp #0044		; Hyp.cls 2027
fn_hyp_info_sb_rest:		; Hyp.cls 2028
            pop iy		; Hyp.cls 2029
            pop ix		; Hyp.cls 2030
            pop hl		; Hyp.cls 2031
            pop de		; Hyp.cls 2032
            pop bc		; Hyp.cls 2033
            pop af		; Hyp.cls 2034
            exx		; Hyp.cls 2035
            db #08                              ; ex af, af' [2036]
            pop hl		; Hyp.cls 2037
            pop de		; Hyp.cls 2038
            pop bc		; Hyp.cls 2039
            pop af		; Hyp.cls 2040
            ei		; Hyp.cls 2041
            ret		; Hyp.cls 2042
fn_hyp_info_sb_land:		; Hyp.cls 2043
            ld sp, (#FFFE)                      ; this bank's SP [2044]
            push af		; Hyp.cls 2045
            ld a, e                             ; E = 1: the hypervisor has the characters [2046]
            or a		; Hyp.cls 2047
            jr z, fn_hyp_info_sb_lkeep		; Hyp.cls 2048
            xor a		; Hyp.cls 2049
            ld (62976 + 128), a		; Hyp.cls 2050
fn_hyp_info_sb_lkeep:		; Hyp.cls 2051
            pop af		; Hyp.cls 2052
            ret		; Hyp.cls 2053
fn_hyp_info_sb_scb:		; Hyp.cls 2054
            ld h, d                             ; 49 (CP/M 3's system control block): the [2055]
            ld l, e                             ; console's width - 1 (#1A), its page length [2056]
            inc hl                              ; (#1C) - MODE's; other bytes 0, sets kept [2057]
            ld a, (hl)                          ; nowhere [2058]
            or a		; Hyp.cls 2059
            jp nz, fn_hyp_info_sb_zero		; Hyp.cls 2060
            ld a, (de)		; Hyp.cls 2061
            cp #1C		; Hyp.cls 2062
            ld hl, 63112		; Hyp.cls 2063
            jr z, fn_hyp_info_sb_scb_a		; Hyp.cls 2064
            cp #1A		; Hyp.cls 2065
            jp nz, fn_hyp_info_sb_zero		; Hyp.cls 2066
            ld a, (63111)		; Hyp.cls 2067
            dec a		; Hyp.cls 2068
            jp fn_hyp_info_sb_ret		; Hyp.cls 2069
fn_hyp_info_sb_scb_a:		; Hyp.cls 2070
            ld a, (hl)		; Hyp.cls 2071
            jp fn_hyp_info_sb_ret		; Hyp.cls 2072
; the BIOS: CP/M 2.2's 17 entries. The console ones as the BDOS's; the printer and punch take
; nothing yet; the disc ones (sectors) can't be had here: SELDSK gives 0 (no such drive),
; READ / WRITE 1 (an error)
fn_hyp_info_sb_bios:		; Hyp.cls 2076
            jp fn_hyp_info_sb_bboot                         ; BOOT [2077]
fn_hyp_info_sb_bwb:		; Hyp.cls 2078
            jp fn_hyp_info_sb_bboot                         ; WBOOT: (#0001) [2079]
            jp fn_hyp_info_sb_bconst                        ; CONST [2080]
            jp fn_hyp_info_sb_bconin                        ; CONIN [2081]
            jp fn_hyp_info_sb_bconout                       ; CONOUT [2082]
            jp fn_hyp_info_sb_bnone                         ; LIST [2083]
            jp fn_hyp_info_sb_bnone                         ; PUNCH [2084]
            jp fn_hyp_info_sb_brdr                          ; READER [2085]
            jp fn_hyp_info_sb_bnone                         ; HOME [2086]
            jp fn_hyp_info_sb_bseld                         ; SELDSK [2087]
            jp fn_hyp_info_sb_bnone                         ; SETTRK [2088]
            jp fn_hyp_info_sb_bnone                         ; SETSEC [2089]
            jp fn_hyp_info_sb_bdma                          ; SETDMA [2090]
            jp fn_hyp_info_sb_bfail                         ; READ [2091]
            jp fn_hyp_info_sb_bfail                         ; WRITE [2092]
            jp fn_hyp_info_sb_blstst                        ; LISTST [2093]
            jp fn_hyp_info_sb_bsectr                        ; SECTRAN [2094]
fn_hyp_info_sb_bboot:		; Hyp.cls 2095
            ld c, 0                             ; the task ends [2096]
            jp fn_hyp_info_sb_start		; Hyp.cls 2097
fn_hyp_info_sb_bconst:		; Hyp.cls 2098
            di		; Hyp.cls 2099
            ld a, (63105)		; Hyp.cls 2100
            or a		; Hyp.cls 2101
            jr z, fn_hyp_info_sb_bc_n		; Hyp.cls 2102
            ld a, #FF		; Hyp.cls 2103
fn_hyp_info_sb_bc_n:		; Hyp.cls 2104
            ei		; Hyp.cls 2105
            ret		; Hyp.cls 2106
fn_hyp_info_sb_bconin:		; Hyp.cls 2107
            di		; Hyp.cls 2108
            call fn_hyp_info_sb_key		; Hyp.cls 2109
            ei		; Hyp.cls 2110
            ret		; Hyp.cls 2111
fn_hyp_info_sb_bconout:		; Hyp.cls 2112
            di		; Hyp.cls 2113
            ld e, c		; Hyp.cls 2114
            call fn_hyp_info_sb_putc		; Hyp.cls 2115
            ei		; Hyp.cls 2116
fn_hyp_info_sb_bnone:		; Hyp.cls 2117
            ret		; Hyp.cls 2118
fn_hyp_info_sb_brdr:		; Hyp.cls 2119
            ld a, #1A		; Hyp.cls 2120
            ret		; Hyp.cls 2121
fn_hyp_info_sb_bseld:		; Hyp.cls 2122
            ld hl, 0		; Hyp.cls 2123
            ret		; Hyp.cls 2124
fn_hyp_info_sb_bdma:		; Hyp.cls 2125
            ld d, b		; Hyp.cls 2126
            ld e, c		; Hyp.cls 2127
            ld c, 26		; Hyp.cls 2128
            jp fn_hyp_info_sb_start		; Hyp.cls 2129
fn_hyp_info_sb_bfail:		; Hyp.cls 2130
            ld a, 1		; Hyp.cls 2131
            ret		; Hyp.cls 2132
fn_hyp_info_sb_blstst:		; Hyp.cls 2133
            ld a, #FF		; Hyp.cls 2134
            ret		; Hyp.cls 2135
fn_hyp_info_sb_bsectr:		; Hyp.cls 2136
            ld h, b		; Hyp.cls 2137
            ld l, c		; Hyp.cls 2138
            ret		; Hyp.cls 2139
; a CPC data format disc's parameters (31) and allocation vector (27): 180 1K blocks, 64
; directory entries in the first two
fn_hyp_info_sb_dpbv:		; Hyp.cls 2142
            dw 36                               ; SPT: 128 byte records a track [2143]
            db 3, 7, 0                          ; BSH, BLM, EXM [2144]
            dw 179, 63                          ; DSM, DRM [2145]
            db #C0, 0                           ; AL0, AL1 [2146]
            dw 16, 0                            ; CKS, OFF [2147]
fn_hyp_info_sb_alvec:		; Hyp.cls 2148
            db #C0		; Hyp.cls 2149
            ds 22		; Hyp.cls 2150
; the start-up: the default FCBs (#005C, #006C) from the command tail (#0080), as the CCP
; makes them - "B:NAME.EXT", * as ?s - then the program at #0100
fn_hyp_info_sb_init:		; Hyp.cls 2153
            ld hl, #005C		; Hyp.cls 2154
            call fn_hyp_info_sb_iclr		; Hyp.cls 2155
            ld hl, #006C		; Hyp.cls 2156
            call fn_hyp_info_sb_iclr		; Hyp.cls 2157
            ld hl, #0081		; Hyp.cls 2158
            ld a, (#0080)		; Hyp.cls 2159
            ld b, a		; Hyp.cls 2160
            ld de, #005C		; Hyp.cls 2161
            call fn_hyp_info_sb_parse		; Hyp.cls 2162
            ld de, #006C		; Hyp.cls 2163
            call fn_hyp_info_sb_parse		; Hyp.cls 2164
            jp #0100		; Hyp.cls 2165
fn_hyp_info_sb_iclr:		; Hyp.cls 2166
            ld (hl), 0		; Hyp.cls 2167
            inc hl		; Hyp.cls 2168
            ld c, 11		; Hyp.cls 2169
fn_hyp_info_sb_ic_sp:		; Hyp.cls 2170
            ld (hl), ' '		; Hyp.cls 2171
            inc hl		; Hyp.cls 2172
            dec c		; Hyp.cls 2173
            jr nz, fn_hyp_info_sb_ic_sp		; Hyp.cls 2174
            ld c, 4		; Hyp.cls 2175
fn_hyp_info_sb_ic_z:		; Hyp.cls 2176
            ld (hl), 0		; Hyp.cls 2177
            inc hl		; Hyp.cls 2178
            dec c		; Hyp.cls 2179
            jr nz, fn_hyp_info_sb_ic_z		; Hyp.cls 2180
            ret		; Hyp.cls 2181
; sb_parse - HL = the tail, B = characters left; DE = an FCB: the next word into it
fn_hyp_info_sb_parse:		; Hyp.cls 2183
            ld a, b		; Hyp.cls 2184
            or a		; Hyp.cls 2185
            ret z		; Hyp.cls 2186
            ld a, (hl)		; Hyp.cls 2187
            cp ' '		; Hyp.cls 2188
            jr nz, fn_hyp_info_sb_p_word		; Hyp.cls 2189
            inc hl		; Hyp.cls 2190
            dec b		; Hyp.cls 2191
            jr fn_hyp_info_sb_parse		; Hyp.cls 2192
fn_hyp_info_sb_p_word:		; Hyp.cls 2193
            ld (fn_hyp_info_sb_pfcb), de		; Hyp.cls 2194
            ld a, b		; Hyp.cls 2195
            cp 2		; Hyp.cls 2196
            jr c, fn_hyp_info_sb_p_name		; Hyp.cls 2197
            inc hl		; Hyp.cls 2198
            ld a, (hl)		; Hyp.cls 2199
            dec hl		; Hyp.cls 2200
            cp ':'		; Hyp.cls 2201
            jr nz, fn_hyp_info_sb_p_name		; Hyp.cls 2202
            ld a, (hl)		; Hyp.cls 2203
            sub '@'		; Hyp.cls 2204
            ld (de), a                          ; its drive [2205]
            inc hl		; Hyp.cls 2206
            inc hl		; Hyp.cls 2207
            dec b		; Hyp.cls 2208
            dec b		; Hyp.cls 2209
fn_hyp_info_sb_p_name:		; Hyp.cls 2210
            inc de		; Hyp.cls 2211
            ld c, 8		; Hyp.cls 2212
            call fn_hyp_info_sb_pfield		; Hyp.cls 2213
            ld a, b		; Hyp.cls 2214
            or a		; Hyp.cls 2215
            ret z		; Hyp.cls 2216
            ld a, (hl)		; Hyp.cls 2217
            cp '.'		; Hyp.cls 2218
            jr nz, fn_hyp_info_sb_p_skip		; Hyp.cls 2219
            inc hl		; Hyp.cls 2220
            dec b		; Hyp.cls 2221
            ld de, (fn_hyp_info_sb_pfcb)		; Hyp.cls 2222
            ld a, e		; Hyp.cls 2223
            add a, 9		; Hyp.cls 2224
            ld e, a		; Hyp.cls 2225
            ld c, 3		; Hyp.cls 2226
            call fn_hyp_info_sb_pfield		; Hyp.cls 2227
fn_hyp_info_sb_p_skip:		; Hyp.cls 2228
            ld a, b                             ; the rest of the word [2229]
            or a		; Hyp.cls 2230
            ret z		; Hyp.cls 2231
            ld a, (hl)		; Hyp.cls 2232
            cp ' '		; Hyp.cls 2233
            ret z		; Hyp.cls 2234
            inc hl		; Hyp.cls 2235
            dec b		; Hyp.cls 2236
            jr fn_hyp_info_sb_p_skip		; Hyp.cls 2237
; sb_pfield - up to C characters into the field at DE, to a "." or a space; * fills it with ?
fn_hyp_info_sb_pfield:		; Hyp.cls 2239
            ld a, b		; Hyp.cls 2240
            or a		; Hyp.cls 2241
            ret z		; Hyp.cls 2242
            ld a, (hl)		; Hyp.cls 2243
            cp ' '		; Hyp.cls 2244
            ret z		; Hyp.cls 2245
            cp '.'		; Hyp.cls 2246
            ret z		; Hyp.cls 2247
            cp '*'		; Hyp.cls 2248
            jr z, fn_hyp_info_sb_pf_star		; Hyp.cls 2249
            inc c		; Hyp.cls 2250
            dec c		; Hyp.cls 2251
            jr z, fn_hyp_info_sb_pf_on                      ; (the field full: the extra left out) [2252]
            ld (de), a		; Hyp.cls 2253
            inc de		; Hyp.cls 2254
            dec c		; Hyp.cls 2255
fn_hyp_info_sb_pf_on:		; Hyp.cls 2256
            inc hl		; Hyp.cls 2257
            dec b		; Hyp.cls 2258
            jr fn_hyp_info_sb_pfield		; Hyp.cls 2259
fn_hyp_info_sb_pf_star:		; Hyp.cls 2260
            inc c		; Hyp.cls 2261
            dec c		; Hyp.cls 2262
            jr z, fn_hyp_info_sb_pf_on		; Hyp.cls 2263
            ld a, '?'		; Hyp.cls 2264
            ld (de), a		; Hyp.cls 2265
            inc de		; Hyp.cls 2266
            dec c		; Hyp.cls 2267
            jr fn_hyp_info_sb_pf_star		; Hyp.cls 2268
fn_hyp_info_sb_pfcb:    dw 0		; Hyp.cls 2269
fn_hyp_info_sb_end:		; Hyp.cls 2270
            ENT		; Hyp.cls 2271
            ASSERT fn_hyp_info_sb_end - fn_hyp_info_sb_start <= 62208 - 61184, "the bank stubs must fit below FONT"		; Hyp.cls 2272
            ASSERT fn_hyp_info_sb_end - fn_hyp_info_sb_start <= #340, "the stubs must leave a program's first stack (#F240-#F2FF) free"		; Hyp.cls 2273
; ---- the page code: in the hypervisor's page (window data), called with it in the window
asm_1_2316_n_fp_start:		; Hyp.cls 2573
            ASSERT asm_1_2316_n_fp_start >= #5300, "FileCall's page code: after the disc buffers and the font"		; Hyp.cls 2574
asm_1_2316_n_fp_go:		; Hyp.cls 2575
            ld (asm_1_2316_n_fp_sp), sp		; Hyp.cls 2576
            ld a, (var_hyp_filecall_f)		; Hyp.cls 2577
            cp 15		; Hyp.cls 2578
            jp z, asm_1_2316_n_fl_open		; Hyp.cls 2579
            cp 16		; Hyp.cls 2580
            jp z, asm_1_2316_n_fl_close		; Hyp.cls 2581
            cp 19		; Hyp.cls 2582
            jp z, asm_1_2316_n_fl_del		; Hyp.cls 2583
            cp 23		; Hyp.cls 2584
            jp z, asm_1_2316_n_fl_ren		; Hyp.cls 2585
            cp 20		; Hyp.cls 2586
            jp z, asm_1_2316_n_fl_rdseq		; Hyp.cls 2587
            cp 33		; Hyp.cls 2588
            jp z, asm_1_2316_n_fl_rdran		; Hyp.cls 2589
            cp 21		; Hyp.cls 2590
            jp z, asm_1_2316_n_fl_write		; Hyp.cls 2591
            cp 34		; Hyp.cls 2592
            jp z, asm_1_2316_n_fl_write		; Hyp.cls 2593
            cp 22		; Hyp.cls 2594
            jp z, asm_1_2316_n_fl_make		; Hyp.cls 2595
            cp 17		; Hyp.cls 2596
            jp z, asm_1_2316_n_fl_srch1		; Hyp.cls 2597
            cp 18		; Hyp.cls 2598
            jp z, asm_1_2316_n_fl_srch		; Hyp.cls 2599
            cp 35		; Hyp.cls 2600
            jp z, asm_1_2316_n_fl_size		; Hyp.cls 2601
            cp 36		; Hyp.cls 2602
            jp z, asm_1_2316_n_fl_setran		; Hyp.cls 2603
            cp 100		; Hyp.cls 2604
            jp z, asm_1_2316_n_fl_hopen		; Hyp.cls 2605
            cp 101		; Hyp.cls 2606
            jp z, asm_1_2316_n_fl_hread		; Hyp.cls 2607
            cp 102		; Hyp.cls 2608
            jp z, asm_1_2316_n_fl_hclose		; Hyp.cls 2609
            cp 103		; Hyp.cls 2610
            jp z, asm_1_2316_n_fl_hload		; Hyp.cls 2611
            cp 30		; Hyp.cls 2612
            jp z, asm_1_2316_n_fl_unicall		; Hyp.cls 2613
            jp asm_1_2316_n_fp_done		; Hyp.cls 2614
; ---- the hypervisor's own reading (RUN, DIR, CD): 100 open the file named at fcb (dma
; characters, main RAM); 101 read dma bytes (128 at most) to buf: how many; 102 close; 103 the
; rest of it into the slot (setting) from address dma, fcb bytes at most: how many. Not while
; a slot reads a file (255)
asm_1_2316_n_fl_hopen:		; Hyp.cls 2619
            ld a, (var_hyp_fin)		; Hyp.cls 2620
            or a		; Hyp.cls 2621
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2622
            ld de, asm_1_2316_n_fl_name_s + 1		; Hyp.cls 2623
            ld hl, (var_hyp_filecall_fcb)          ; a name with no drive: the hypervisor's drive's path first [2624]
            ld bc, (var_hyp_filecall_dma)          ; when it has one (UniDOS: CD IDE: ...) [2625]
            ld a, ':'		; Hyp.cls 2626
            cpir		; Hyp.cls 2627
            jr z, asm_1_2316_n_fl_ho_nm		; Hyp.cls 2628
            ld a, (var_hyp_hdr)		; Hyp.cls 2629
            call asm_1_2316_n_fl_pfxm		; Hyp.cls 2630
asm_1_2316_n_fl_ho_nm:		; Hyp.cls 2631
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2632
            ld bc, (var_hyp_filecall_dma)		; Hyp.cls 2633
            ldir		; Hyp.cls 2634
            call asm_1_2316_n_fl_nlen		; Hyp.cls 2635
            call asm_1_2316_n_fl_inopen		; Hyp.cls 2636
            jr c, asm_1_2316_n_fl_ho_ok		; Hyp.cls 2637
            ld hl, asm_1_2316_n_fl_name_s        ; NAME.CYB not there: with UniDOS NAME.COM instead (RUN - a [2638]
            ld e, (hl)              ; .COM with no entry: UniDOS reads a file with no header to [2639]
            ld d, 0                 ; its real end) [2640]
            add hl, de		; Hyp.cls 2641
            ld a, (hl)		; Hyp.cls 2642
            cp 'B'		; Hyp.cls 2643
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2644
            ld (hl), 'M'		; Hyp.cls 2645
            dec hl		; Hyp.cls 2646
            ld a, (hl)		; Hyp.cls 2647
            cp 'Y'		; Hyp.cls 2648
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2649
            ld (hl), 'O'		; Hyp.cls 2650
            call asm_1_2316_n_fl_uni		; Hyp.cls 2651
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2652
            call asm_1_2316_n_fl_inopen		; Hyp.cls 2653
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2654
            ld hl, (var_hyp_filecall_fcb)          ; (the caller's name too: NAME.COM) [2655]
            ld bc, (var_hyp_filecall_dma)		; Hyp.cls 2656
            add hl, bc		; Hyp.cls 2657
            dec hl		; Hyp.cls 2658
            ld (hl), 'M'		; Hyp.cls 2659
            dec hl		; Hyp.cls 2660
            ld (hl), 'O'		; Hyp.cls 2661
asm_1_2316_n_fl_ho_ok:		; Hyp.cls 2662
            ld a, 99                ; (99: the hypervisor's) [2663]
            ld (var_hyp_fin), a		; Hyp.cls 2664
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2665
asm_1_2316_n_fl_hread:		; Hyp.cls 2666
            ld a, (var_hyp_filecall_dma)		; Hyp.cls 2667
            ld (asm_1_2316_n_fl_n), a		; Hyp.cls 2668
            call asm_1_2316_n_fl_rdrec		; Hyp.cls 2669
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 2670
            jp asm_1_2316_n_fp_done		; Hyp.cls 2671
asm_1_2316_n_fl_hclose:		; Hyp.cls 2672
            ld a, (var_hyp_fin)		; Hyp.cls 2673
            cp 99		; Hyp.cls 2674
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2675
            call asm_1_2316_n_fl_inclose		; Hyp.cls 2676
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2677
asm_1_2316_n_fl_hload:		; Hyp.cls 2678
            ld hl, 0		; Hyp.cls 2679
            ld (asm_1_2316_n_fl_cnt), hl		; Hyp.cls 2680
            ld hl, (var_hyp_filecall_dma)		; Hyp.cls 2681
            ld (asm_1_2316_n_fl_at), hl		; Hyp.cls 2682
asm_1_2316_n_fl_hl_lp:		; Hyp.cls 2683
            ld hl, (var_hyp_filecall_fcb)          ; what is left to load (fcb bytes at most) [2684]
            ld de, (asm_1_2316_n_fl_cnt)		; Hyp.cls 2685
            or a		; Hyp.cls 2686
            sbc hl, de		; Hyp.cls 2687
            jr z, asm_1_2316_n_fl_hl_end		; Hyp.cls 2688
            ld a, h		; Hyp.cls 2689
            or a		; Hyp.cls 2690
            ld a, 128		; Hyp.cls 2691
            jr nz, asm_1_2316_n_fl_hl_n		; Hyp.cls 2692
            ld a, l		; Hyp.cls 2693
            cp 128		; Hyp.cls 2694
            jr c, asm_1_2316_n_fl_hl_n		; Hyp.cls 2695
            ld a, 128		; Hyp.cls 2696
asm_1_2316_n_fl_hl_n:		; Hyp.cls 2697
            ld (asm_1_2316_n_fl_n), a		; Hyp.cls 2698
            ld (asm_1_2316_n_fl_want), a		; Hyp.cls 2699
            call asm_1_2316_n_fl_rdrec           ; a record's worth into buf [2700]
            jr z, asm_1_2316_n_fl_hl_end		; Hyp.cls 2701
            ld b, a		; Hyp.cls 2702
            ld (asm_1_2316_n_fl_want + 1), a		; Hyp.cls 2703
            ld hl, (asm_1_2316_n_fl_cnt)		; Hyp.cls 2704
            ld e, a		; Hyp.cls 2705
            ld d, 0		; Hyp.cls 2706
            add hl, de		; Hyp.cls 2707
            ld (asm_1_2316_n_fl_cnt), hl		; Hyp.cls 2708
            ld hl, (asm_1_2316_n_fl_at)		; Hyp.cls 2709
            ld c, b		; Hyp.cls 2710
            ld b, 0		; Hyp.cls 2711
            call asm_1_2316_n_fl_fits		; Hyp.cls 2712
            jr c, asm_1_2316_n_fl_hl_slow		; Hyp.cls 2713
            push bc		; Hyp.cls 2714
            ld de, (var_hyp_filecall_buf)          ; in one page: one ldir [2715]
            call asm_1_2316_n_fl_toslot		; Hyp.cls 2716
            pop bc		; Hyp.cls 2717
            ld hl, (asm_1_2316_n_fl_at)		; Hyp.cls 2718
            add hl, bc		; Hyp.cls 2719
            jr asm_1_2316_n_fl_hl_put		; Hyp.cls 2720
asm_1_2316_n_fl_hl_slow:		; Hyp.cls 2721
            ld b, c		; Hyp.cls 2722
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2723
asm_1_2316_n_fl_hl_cp:		; Hyp.cls 2724
            ld a, (de)              ; into the slot [2725]
            call asm_1_2316_n_fl_poke		; Hyp.cls 2726
            inc hl		; Hyp.cls 2727
            inc de		; Hyp.cls 2728
            djnz asm_1_2316_n_fl_hl_cp		; Hyp.cls 2729
asm_1_2316_n_fl_hl_put:		; Hyp.cls 2730
            ld (asm_1_2316_n_fl_at), hl		; Hyp.cls 2731
            ld a, (asm_1_2316_n_fl_want)		; Hyp.cls 2732
            ld b, a		; Hyp.cls 2733
            ld a, (asm_1_2316_n_fl_want + 1)		; Hyp.cls 2734
            cp b		; Hyp.cls 2735
            jr z, asm_1_2316_n_fl_hl_lp          ; a whole one: on [2736]
asm_1_2316_n_fl_hl_end:		; Hyp.cls 2737
            ld hl, (asm_1_2316_n_fl_cnt)		; Hyp.cls 2738
            ld (asm_1_2316_n_fl_res16), hl		; Hyp.cls 2739
            ld a, 1		; Hyp.cls 2740
            ld (asm_1_2316_n_fl_r16), a		; Hyp.cls 2741
            jp asm_1_2316_n_fp_done		; Hyp.cls 2742
; ---- 15: open (to read)
asm_1_2316_n_fl_open:		; Hyp.cls 2744
            ld a, (var_hyp_fin)		; Hyp.cls 2745
            or a		; Hyp.cls 2746
            jr z, asm_1_2316_n_fl_op_new		; Hyp.cls 2747
            ld b, a		; Hyp.cls 2748
            ld a, (asm_1_2316_n_fl_slot)		; Hyp.cls 2749
            cp b		; Hyp.cls 2750
            jp nz, asm_1_2316_n_fp_done          ; another slot's being read [2751]
            call asm_1_2316_n_fl_inclose         ; this slot's: CP/M needs no close after reading - this open [2752]
asm_1_2316_n_fl_op_new:                          ; replaces it (Exists opens and leaves it) [2753]
            call asm_1_2316_n_fl_name		; Hyp.cls 2754
            call asm_1_2316_n_fl_inopen		; Hyp.cls 2755
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2756
            ld hl, asm_1_2316_n_fl_name_s        ; kept, to open it again (33 going back) [2757]
            ld de, asm_1_2316_n_fl_inname		; Hyp.cls 2758
            ld bc, asm_1_2316_n_FL_NL		; Hyp.cls 2759
            ldir		; Hyp.cls 2760
            ld a, (asm_1_2316_n_fl_slot)		; Hyp.cls 2761
            ld (var_hyp_fin), a		; Hyp.cls 2762
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2763
            ld (asm_1_2316_n_fl_infcb), hl		; Hyp.cls 2764
            ld a, 1		; Hyp.cls 2765
            ld (asm_1_2316_n_fl_infcb + 2), a		; Hyp.cls 2766
            ld hl, 0		; Hyp.cls 2767
            ld (asm_1_2316_n_fl_inrec), hl		; Hyp.cls 2768
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2769
; ---- 22: make (a new file, to write)
asm_1_2316_n_fl_make:		; Hyp.cls 2771
            ld a, (var_hyp_fout)		; Hyp.cls 2772
            or a		; Hyp.cls 2773
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2774
            call asm_1_2316_n_fl_name		; Hyp.cls 2775
            call asm_1_2316_n_fl_plain		; Hyp.cls 2776
            ld hl, asm_1_2316_n_fl_name_s + 1		; Hyp.cls 2777
            ld a, (asm_1_2316_n_fl_name_s)		; Hyp.cls 2778
            ld b, a		; Hyp.cls 2779
            ld de, #4800		; Hyp.cls 2780
            call #BC8C              ; CAS OUT OPEN [2781]
            di		; Hyp.cls 2782
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2783
            ld a, (asm_1_2316_n_fl_slot)		; Hyp.cls 2784
            ld (var_hyp_fout), a		; Hyp.cls 2785
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2786
            ld (asm_1_2316_n_fl_outfcb), hl		; Hyp.cls 2787
            ld a, 1		; Hyp.cls 2788
            ld (asm_1_2316_n_fl_outfcb + 2), a		; Hyp.cls 2789
            ld hl, 0		; Hyp.cls 2790
            ld (asm_1_2316_n_fl_outrec), hl		; Hyp.cls 2791
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2792
; ---- 16: close
asm_1_2316_n_fl_close:		; Hyp.cls 2794
            call asm_1_2316_n_fl_isin		; Hyp.cls 2795
            jr nz, asm_1_2316_n_fl_cl_out		; Hyp.cls 2796
            call asm_1_2316_n_fl_inclose		; Hyp.cls 2797
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2798
asm_1_2316_n_fl_cl_out:		; Hyp.cls 2799
            call asm_1_2316_n_fl_isout		; Hyp.cls 2800
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2801
            xor a		; Hyp.cls 2802
            ld (var_hyp_fout), a		; Hyp.cls 2803
            call asm_1_2316_n_fl_plain		; Hyp.cls 2804
            call #BC8F              ; CAS OUT CLOSE [2805]
            di		; Hyp.cls 2806
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2807
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2808
; ---- 19: delete (|ERA, "name")
asm_1_2316_n_fl_del:		; Hyp.cls 2810
            call asm_1_2316_n_fl_name		; Hyp.cls 2811
            call asm_1_2316_n_fl_plain		; Hyp.cls 2812
            ld hl, asm_1_2316_n_fl_name_s + 1		; Hyp.cls 2813
            ld (asm_1_2316_n_fl_desc + 1), hl		; Hyp.cls 2814
            ld a, (asm_1_2316_n_fl_name_s)		; Hyp.cls 2815
            ld (asm_1_2316_n_fl_desc), a		; Hyp.cls 2816
            ld hl, asm_1_2316_n_fl_yes           ; (UniDOS asks before it deletes a folder - all it holds too -, [2817]
            ld a, (hl)              ; a read-only or a hidden file: KM WAIT CHAR, its text unseen, [2818]
            ld (hl), 0              ; the VDU off. KM CHAR RETURN: the answer waiting for it - N, [2819]
            or a                    ; so a CP/M program's delete never takes a folder; Y only after [2820]
            ld a, 'N'               ; BDOS 30 op 8, RMDIR's, for its empty folder) [2821]
            jr z, asm_1_2316_n_fl_del_n		; Hyp.cls 2822
            ld a, 'Y'		; Hyp.cls 2823
asm_1_2316_n_fl_del_n:		; Hyp.cls 2824
            call #BB0C		; Hyp.cls 2825
            ld hl, asm_1_2316_n_fl_era           ; KL FIND COMMAND; KM READ CHAR after [2826]
            call #BCD4              ; takes the answer back when nothing asked [2827]
            di		; Hyp.cls 2828
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2829
            ld ix, asm_1_2316_n_fl_par		; Hyp.cls 2830
            ld a, 1                 ; one parameter: the string [2831]
            call #001B              ; KL FAR PCALL [2832]
            call #BB09              ; KM READ CHAR (interrupts: off again in fl_done) [2833]
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2834
; ---- 23: rename (the disc ROM's |REN, "new", "old"): the old name at FCB 0-11, the new
; at 16-27 (its drive 0: the old one's)
asm_1_2316_n_fl_ren:		; Hyp.cls 2837
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2838
            call asm_1_2316_n_fl_peek		; Hyp.cls 2839
            ld (asm_1_2316_n_fl_dfl), a		; Hyp.cls 2840
            ld de, 16		; Hyp.cls 2841
            add hl, de		; Hyp.cls 2842
            call asm_1_2316_n_fl_namehl          ; the new name [2843]
            xor a		; Hyp.cls 2844
            ld (asm_1_2316_n_fl_dfl), a		; Hyp.cls 2845
            ld hl, asm_1_2316_n_fl_name_s		; Hyp.cls 2846
            ld de, asm_1_2316_n_fl_new_s		; Hyp.cls 2847
            ld bc, asm_1_2316_n_FL_NL		; Hyp.cls 2848
            ldir		; Hyp.cls 2849
            call asm_1_2316_n_fl_name            ; the old one [2850]
            call asm_1_2316_n_fl_plain		; Hyp.cls 2851
            ld hl, asm_1_2316_n_fl_name_s + 1		; Hyp.cls 2852
            ld (asm_1_2316_n_fl_desc + 1), hl		; Hyp.cls 2853
            ld a, (asm_1_2316_n_fl_name_s)		; Hyp.cls 2854
            ld (asm_1_2316_n_fl_desc), a		; Hyp.cls 2855
            ld hl, asm_1_2316_n_fl_new_s + 1		; Hyp.cls 2856
            ld (asm_1_2316_n_fl_desc2 + 1), hl		; Hyp.cls 2857
            ld a, (asm_1_2316_n_fl_new_s)		; Hyp.cls 2858
            ld (asm_1_2316_n_fl_desc2), a		; Hyp.cls 2859
            ld hl, asm_1_2316_n_fl_rencmd		; Hyp.cls 2860
            call #BCD4              ; KL FIND COMMAND [2861]
            di		; Hyp.cls 2862
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2863
            ld ix, asm_1_2316_n_fl_par2          ; IX+0: the last parameter (the old name), IX+2: the new [2864]
            ld a, 2		; Hyp.cls 2865
            call #001B              ; KL FAR PCALL [2866]
            jp asm_1_2316_n_fl_ok              ; (interrupts: off again in fl_done) [2867]
; ---- 33: read record r0-r1: on to it (from the start again if it is behind)
asm_1_2316_n_fl_rdran:		; Hyp.cls 2869
            call asm_1_2316_n_fl_isin		; Hyp.cls 2870
            jp nz, asm_1_2316_n_fl_rdout		; Hyp.cls 2871
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2872
            ld de, 33		; Hyp.cls 2873
            add hl, de		; Hyp.cls 2874
            call asm_1_2316_n_fl_peek		; Hyp.cls 2875
            ld e, a		; Hyp.cls 2876
            inc hl		; Hyp.cls 2877
            call asm_1_2316_n_fl_peek		; Hyp.cls 2878
            ld d, a		; Hyp.cls 2879
            ld (asm_1_2316_n_fl_want), de		; Hyp.cls 2880
            ld hl, (asm_1_2316_n_fl_inrec)		; Hyp.cls 2881
            or a		; Hyp.cls 2882
            sbc hl, de		; Hyp.cls 2883
            jr c, asm_1_2316_n_fl_rr_on		; Hyp.cls 2884
            jr z, asm_1_2316_n_fl_rr_on		; Hyp.cls 2885
            call asm_1_2316_n_fl_inclose         ; behind: open it again [2886]
            ld hl, asm_1_2316_n_fl_inname		; Hyp.cls 2887
            ld de, asm_1_2316_n_fl_name_s		; Hyp.cls 2888
            ld bc, asm_1_2316_n_FL_NL		; Hyp.cls 2889
            ldir		; Hyp.cls 2890
            call asm_1_2316_n_fl_inopen		; Hyp.cls 2891
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2892
            ld a, (asm_1_2316_n_fl_slot)		; Hyp.cls 2893
            ld (var_hyp_fin), a		; Hyp.cls 2894
            ld hl, 0		; Hyp.cls 2895
            ld (asm_1_2316_n_fl_inrec), hl		; Hyp.cls 2896
asm_1_2316_n_fl_rr_on:		; Hyp.cls 2897
            ld hl, (asm_1_2316_n_fl_inrec)		; Hyp.cls 2898
            ld de, (asm_1_2316_n_fl_want)		; Hyp.cls 2899
            or a		; Hyp.cls 2900
            sbc hl, de		; Hyp.cls 2901
            jr nc, asm_1_2316_n_fl_rdseq		; Hyp.cls 2902
            call asm_1_2316_n_fl_rdrec		; Hyp.cls 2903
            jp z, asm_1_2316_n_fl_eof		; Hyp.cls 2904
            ld hl, (asm_1_2316_n_fl_inrec)		; Hyp.cls 2905
            inc hl		; Hyp.cls 2906
            ld (asm_1_2316_n_fl_inrec), hl		; Hyp.cls 2907
            jr asm_1_2316_n_fl_rr_on		; Hyp.cls 2908
; ---- 20: read the next record
asm_1_2316_n_fl_rdseq:		; Hyp.cls 2910
            call asm_1_2316_n_fl_isin		; Hyp.cls 2911
            jr nz, asm_1_2316_n_fl_rdout		; Hyp.cls 2912
            call asm_1_2316_n_fl_rdrec		; Hyp.cls 2913
            jr z, asm_1_2316_n_fl_eof		; Hyp.cls 2914
            ex de, hl		; Hyp.cls 2915
            ld hl, (asm_1_2316_n_fl_inrec)		; Hyp.cls 2916
            inc hl		; Hyp.cls 2917
            ld (asm_1_2316_n_fl_inrec), hl		; Hyp.cls 2918
            ex de, hl		; Hyp.cls 2919
            ld b, a                 ; the record padded with #1A [2920]
            ld a, 128		; Hyp.cls 2921
            sub b		; Hyp.cls 2922
            jr z, asm_1_2316_n_fl_rd_put		; Hyp.cls 2923
            ld b, a		; Hyp.cls 2924
            ld a, #1A		; Hyp.cls 2925
asm_1_2316_n_fl_rd_pad:		; Hyp.cls 2926
            ld (hl), a		; Hyp.cls 2927
            inc hl		; Hyp.cls 2928
            djnz asm_1_2316_n_fl_rd_pad		; Hyp.cls 2929
asm_1_2316_n_fl_rd_put:		; Hyp.cls 2930
            ld hl, (var_hyp_filecall_dma)          ; into the slot's DMA: in one page, one ldir [2931]
            ld bc, 128		; Hyp.cls 2932
            call asm_1_2316_n_fl_fits		; Hyp.cls 2933
            jr c, asm_1_2316_n_fl_rd_slow		; Hyp.cls 2934
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2935
            call asm_1_2316_n_fl_toslot		; Hyp.cls 2936
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2937
asm_1_2316_n_fl_rd_slow:                         ; (across two pages: a byte at a time) [2938]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2939
            ld de, (var_hyp_filecall_dma)		; Hyp.cls 2940
            ld b, 128		; Hyp.cls 2941
asm_1_2316_n_fl_rd_cp:		; Hyp.cls 2942
            ld a, (hl)		; Hyp.cls 2943
            ex de, hl		; Hyp.cls 2944
            call asm_1_2316_n_fl_poke		; Hyp.cls 2945
            ex de, hl		; Hyp.cls 2946
            inc hl		; Hyp.cls 2947
            inc de		; Hyp.cls 2948
            djnz asm_1_2316_n_fl_rd_cp		; Hyp.cls 2949
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2950
asm_1_2316_n_fl_rdout:		; Hyp.cls 2951
            call asm_1_2316_n_fl_isout           ; a file being written: nothing to read back [2952]
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2953
asm_1_2316_n_fl_eof:		; Hyp.cls 2954
            ld a, 1		; Hyp.cls 2955
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 2956
            jp asm_1_2316_n_fp_done		; Hyp.cls 2957
; ---- 21 / 34: write the next record
asm_1_2316_n_fl_write:		; Hyp.cls 2959
            call asm_1_2316_n_fl_isout		; Hyp.cls 2960
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 2961
            ld hl, (var_hyp_filecall_dma)          ; the slot's DMA into buf [2962]
            ld bc, 128		; Hyp.cls 2963
            call asm_1_2316_n_fl_fits		; Hyp.cls 2964
            jr c, asm_1_2316_n_fl_wr_slow		; Hyp.cls 2965
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2966
            call asm_1_2316_n_fl_fromslot		; Hyp.cls 2967
            jr asm_1_2316_n_fl_wr_got		; Hyp.cls 2968
asm_1_2316_n_fl_wr_slow:		; Hyp.cls 2969
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2970
            ld b, 128		; Hyp.cls 2971
asm_1_2316_n_fl_wr_cp:		; Hyp.cls 2972
            call asm_1_2316_n_fl_peek		; Hyp.cls 2973
            ld (de), a		; Hyp.cls 2974
            inc hl		; Hyp.cls 2975
            inc de		; Hyp.cls 2976
            djnz asm_1_2316_n_fl_wr_cp		; Hyp.cls 2977
asm_1_2316_n_fl_wr_got:		; Hyp.cls 2978
            call asm_1_2316_n_fl_plain		; Hyp.cls 2979
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2980
            ld b, 128		; Hyp.cls 2981
asm_1_2316_n_fl_wr_lp:		; Hyp.cls 2982
            ld a, (hl)		; Hyp.cls 2983
            push bc		; Hyp.cls 2984
            push hl		; Hyp.cls 2985
            call #BC95              ; CAS OUT CHAR [2986]
            di		; Hyp.cls 2987
            pop hl		; Hyp.cls 2988
            pop bc		; Hyp.cls 2989
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 2990
            inc hl		; Hyp.cls 2991
            djnz asm_1_2316_n_fl_wr_lp		; Hyp.cls 2992
            ld hl, (asm_1_2316_n_fl_outrec)		; Hyp.cls 2993
            inc hl		; Hyp.cls 2994
            ld (asm_1_2316_n_fl_outrec), hl		; Hyp.cls 2995
            jp asm_1_2316_n_fl_ok		; Hyp.cls 2996
; ---- 35: the file's size in records (r0-r2): counted, reading it through. The file this slot
; is reading is opened again after, at its record; another slot's being read: 255
asm_1_2316_n_fl_size:		; Hyp.cls 2999
            ld a, (var_hyp_fin)		; Hyp.cls 3000
            or a		; Hyp.cls 3001
            jr z, asm_1_2316_n_fl_sz_free		; Hyp.cls 3002
            ld b, a		; Hyp.cls 3003
            ld a, (asm_1_2316_n_fl_slot)		; Hyp.cls 3004
            cp b		; Hyp.cls 3005
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 3006
            call asm_1_2316_n_fl_inclose		; Hyp.cls 3007
            ld a, 1		; Hyp.cls 3008
asm_1_2316_n_fl_sz_free:		; Hyp.cls 3009
            ld (asm_1_2316_n_fl_had), a		; Hyp.cls 3010
            call asm_1_2316_n_fl_name		; Hyp.cls 3011
            call asm_1_2316_n_fl_inopen		; Hyp.cls 3012
            jr nc, asm_1_2316_n_fl_sz_back		; Hyp.cls 3013
            ld hl, 0		; Hyp.cls 3014
            ld (asm_1_2316_n_fl_cnt), hl		; Hyp.cls 3015
asm_1_2316_n_fl_sz_lp:		; Hyp.cls 3016
            call asm_1_2316_n_fl_rdrec		; Hyp.cls 3017
            jr z, asm_1_2316_n_fl_sz_end		; Hyp.cls 3018
            ld hl, (asm_1_2316_n_fl_cnt)		; Hyp.cls 3019
            inc hl		; Hyp.cls 3020
            ld (asm_1_2316_n_fl_cnt), hl		; Hyp.cls 3021
            cp 128		; Hyp.cls 3022
            jr z, asm_1_2316_n_fl_sz_lp		; Hyp.cls 3023
asm_1_2316_n_fl_sz_end:		; Hyp.cls 3024
            call asm_1_2316_n_fl_inclose		; Hyp.cls 3025
            ld hl, (asm_1_2316_n_fl_cnt)		; Hyp.cls 3026
            call asm_1_2316_n_fl_ranput		; Hyp.cls 3027
            xor a		; Hyp.cls 3028
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 3029
asm_1_2316_n_fl_sz_back:		; Hyp.cls 3030
            ld a, (asm_1_2316_n_fl_had)		; Hyp.cls 3031
            or a		; Hyp.cls 3032
            jp z, asm_1_2316_n_fp_done		; Hyp.cls 3033
            ld hl, asm_1_2316_n_fl_inname        ; the slot's read file again, on to its record [3034]
            ld de, asm_1_2316_n_fl_name_s		; Hyp.cls 3035
            ld bc, asm_1_2316_n_FL_NL		; Hyp.cls 3036
            ldir		; Hyp.cls 3037
            call asm_1_2316_n_fl_inopen		; Hyp.cls 3038
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 3039
            ld a, (asm_1_2316_n_fl_slot)		; Hyp.cls 3040
            ld (var_hyp_fin), a		; Hyp.cls 3041
            ld hl, (asm_1_2316_n_fl_inrec)		; Hyp.cls 3042
asm_1_2316_n_fl_sz_skip:		; Hyp.cls 3043
            ld a, h		; Hyp.cls 3044
            or l		; Hyp.cls 3045
            jp z, asm_1_2316_n_fp_done		; Hyp.cls 3046
            push hl		; Hyp.cls 3047
            call asm_1_2316_n_fl_rdrec		; Hyp.cls 3048
            pop hl		; Hyp.cls 3049
            dec hl		; Hyp.cls 3050
            jr asm_1_2316_n_fl_sz_skip		; Hyp.cls 3051
; ---- 36: set the random record (r0-r2) from where the file is: the next record read or
; written; a file not open here: from the FCB's extent and record (ex * 128 + cr)
asm_1_2316_n_fl_setran:		; Hyp.cls 3054
            call asm_1_2316_n_fl_isin		; Hyp.cls 3055
            ld hl, (asm_1_2316_n_fl_inrec)		; Hyp.cls 3056
            jr z, asm_1_2316_n_fl_sr_put		; Hyp.cls 3057
            call asm_1_2316_n_fl_isout		; Hyp.cls 3058
            ld hl, (asm_1_2316_n_fl_outrec)		; Hyp.cls 3059
            jr z, asm_1_2316_n_fl_sr_put		; Hyp.cls 3060
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3061
            ld de, 32		; Hyp.cls 3062
            add hl, de		; Hyp.cls 3063
            call asm_1_2316_n_fl_peek            ; cr [3064]
            ld e, a		; Hyp.cls 3065
            ld bc, -20		; Hyp.cls 3066
            add hl, bc		; Hyp.cls 3067
            call asm_1_2316_n_fl_peek            ; ex [3068]
            ld h, a		; Hyp.cls 3069
            srl h		; Hyp.cls 3070
            ld a, e		; Hyp.cls 3071
            jr nc, asm_1_2316_n_fl_sr_lo		; Hyp.cls 3072
            or #80		; Hyp.cls 3073
asm_1_2316_n_fl_sr_lo:		; Hyp.cls 3074
            ld l, a		; Hyp.cls 3075
asm_1_2316_n_fl_sr_put:		; Hyp.cls 3076
            call asm_1_2316_n_fl_ranput		; Hyp.cls 3077
            jp asm_1_2316_n_fl_ok		; Hyp.cls 3078
; ---- 17 / 18: search the folder (UniDOS: the FCB's drive's, else the slot's) for BDOS 17's
; name ("?" any character; kept at SRCH in the bank, SRCH + 12 the entries passed - 18 goes on
; from there): the next one, as a CP/M directory entry at the DMA (its record count from its
; length, 128 at most). 17 examines the folder (Ctrl J) into the hypervisor's page (#6000-#7BFF:
; 112 entries at most), then 17 and 18 look there. No UniDOS (or an AMSDOS floppy): none (255)
asm_1_2316_n_fl_srch1:		; Hyp.cls 3084
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3085
            ld de, 63216		; Hyp.cls 3086
            ld b, 12		; Hyp.cls 3087
asm_1_2316_n_fl_s1_lp:		; Hyp.cls 3088
            call asm_1_2316_n_fl_peek		; Hyp.cls 3089
            ex de, hl		; Hyp.cls 3090
            call asm_1_2316_n_fl_poke		; Hyp.cls 3091
            ex de, hl		; Hyp.cls 3092
            inc hl		; Hyp.cls 3093
            inc de		; Hyp.cls 3094
            djnz asm_1_2316_n_fl_s1_lp		; Hyp.cls 3095
            ex de, hl		; Hyp.cls 3096
            xor a		; Hyp.cls 3097
            call asm_1_2316_n_fl_poke            ; none passed [3098]
            xor a		; Hyp.cls 3099
            ld (asm_1_2316_n_fl_cn), a		; Hyp.cls 3100
            ld hl, #6000		; Hyp.cls 3101
            ld (asm_1_2316_n_fl_at), hl		; Hyp.cls 3102
            ld de, asm_1_2316_n_fl_name_s + 1    ; "B:" (or B's path) [3103]
            ld hl, 63216		; Hyp.cls 3104
            call asm_1_2316_n_fl_peek		; Hyp.cls 3105
            or a		; Hyp.cls 3106
            jr z, asm_1_2316_n_fl_s_own		; Hyp.cls 3107
            add a, 64		; Hyp.cls 3108
            jr asm_1_2316_n_fl_s_drv		; Hyp.cls 3109
asm_1_2316_n_fl_s_own:		; Hyp.cls 3110
            ld a, (var_hyp_filecall_drive)		; Hyp.cls 3111
            or a		; Hyp.cls 3112
            jr z, asm_1_2316_n_fl_s_nod		; Hyp.cls 3113
asm_1_2316_n_fl_s_drv:		; Hyp.cls 3114
            call asm_1_2316_n_fl_pfx		; Hyp.cls 3115
asm_1_2316_n_fl_s_nod:		; Hyp.cls 3116
; UniDOS: the directory itself (Ctrl J examine), its files into the cache - no file opened (so
; not held up by another slot's reading)
            push de		; Hyp.cls 3119
            call asm_1_2316_n_fl_exdir		; Hyp.cls 3120
            pop de		; Hyp.cls 3121
            jp nz, asm_1_2316_n_fp_done          ; (none to list: no UniDOS, an AMSDOS floppy - 255) [3122]
asm_1_2316_n_fl_sx_lp:		; Hyp.cls 3123
            ld hl, (asm_1_2316_n_fl_at)		; Hyp.cls 3124
            inc hl                  ; (the name straight into the entry) [3125]
            ld ix, asm_1_2316_n_FL_DATE		; Hyp.cls 3126
            ld c, 13                ; examine next [3127]
            call asm_1_2316_n_fl_cjc		; Hyp.cls 3128
            jr nc, asm_1_2316_n_fl_sx_end		; Hyp.cls 3129
            jr nz, asm_1_2316_n_fl_sx_end		; Hyp.cls 3130
            bit 4, a		; Hyp.cls 3131
            jr nz, asm_1_2316_n_fl_sx_lp         ; (a folder: not for CP/M) [3132]
            ld hl, (asm_1_2316_n_fl_at)		; Hyp.cls 3133
            ld (hl), 1              ; in use [3134]
            ld a, b		; Hyp.cls 3135
            or c		; Hyp.cls 3136
            jr z, asm_1_2316_n_fl_sx_sz		; Hyp.cls 3137
            ld de, #FFFF            ; (64K or more) [3138]
asm_1_2316_n_fl_sx_sz:		; Hyp.cls 3139
            ld bc, 12		; Hyp.cls 3140
            add hl, bc		; Hyp.cls 3141
            ld (hl), b              ; kind, flags 0 [3142]
            inc hl		; Hyp.cls 3143
            ld (hl), b		; Hyp.cls 3144
            inc hl		; Hyp.cls 3145
            ld (hl), e              ; its length [3146]
            inc hl		; Hyp.cls 3147
            ld (hl), d		; Hyp.cls 3148
            ld hl, (asm_1_2316_n_fl_at)		; Hyp.cls 3149
            ld bc, 64		; Hyp.cls 3150
            add hl, bc		; Hyp.cls 3151
            ld (asm_1_2316_n_fl_at), hl		; Hyp.cls 3152
            ld hl, asm_1_2316_n_fl_cn		; Hyp.cls 3153
            inc (hl)		; Hyp.cls 3154
            ld a, (hl)		; Hyp.cls 3155
            cp asm_1_2316_n_FL_CMAX		; Hyp.cls 3156
            jr c, asm_1_2316_n_fl_sx_lp		; Hyp.cls 3157
asm_1_2316_n_fl_sx_end:		; Hyp.cls 3158
            jp asm_1_2316_n_fl_srch		; Hyp.cls 3159
asm_1_2316_n_fl_srch:		; Hyp.cls 3160
            ld hl, 63216 + 12		; Hyp.cls 3161
            call asm_1_2316_n_fl_peek		; Hyp.cls 3162
            ld (asm_1_2316_n_fl_skip), a		; Hyp.cls 3163
            xor a		; Hyp.cls 3164
            ld (asm_1_2316_n_fl_k), a		; Hyp.cls 3165
asm_1_2316_n_fl_s_lp:		; Hyp.cls 3166
            ld a, (asm_1_2316_n_fl_cn)           ; the next entry, from the cache [3167]
            ld b, a		; Hyp.cls 3168
            ld a, (asm_1_2316_n_fl_k)		; Hyp.cls 3169
            cp b		; Hyp.cls 3170
            jp nc, asm_1_2316_n_fp_done          ; (none: 255) [3171]
            ld l, a		; Hyp.cls 3172
            ld h, 0		; Hyp.cls 3173
            add hl, hl		; Hyp.cls 3174
            add hl, hl		; Hyp.cls 3175
            add hl, hl		; Hyp.cls 3176
            add hl, hl		; Hyp.cls 3177
            add hl, hl		; Hyp.cls 3178
            add hl, hl		; Hyp.cls 3179
            ld de, #6000		; Hyp.cls 3180
            add hl, de		; Hyp.cls 3181
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 3182
            ld bc, 64		; Hyp.cls 3183
            ldir		; Hyp.cls 3184
            ld hl, asm_1_2316_n_fl_k		; Hyp.cls 3185
            inc (hl)		; Hyp.cls 3186
            ld a, (asm_1_2316_n_fl_skip)		; Hyp.cls 3187
            cp (hl)		; Hyp.cls 3188
            jr nc, asm_1_2316_n_fl_s_lp          ; passed already [3189]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 3190
            ld a, (hl)		; Hyp.cls 3191
            dec a		; Hyp.cls 3192
            jr nz, asm_1_2316_n_fl_s_lp          ; not in use (1) [3193]
            inc hl		; Hyp.cls 3194
            ld de, 63216 + 1		; Hyp.cls 3195
            ld b, 11		; Hyp.cls 3196
asm_1_2316_n_fl_s_cmp:		; Hyp.cls 3197
            ex de, hl		; Hyp.cls 3198
            call asm_1_2316_n_fl_peek		; Hyp.cls 3199
            ex de, hl		; Hyp.cls 3200
            and #7F		; Hyp.cls 3201
            cp '?'		; Hyp.cls 3202
            jr z, asm_1_2316_n_fl_s_any		; Hyp.cls 3203
            ld c, a		; Hyp.cls 3204
            ld a, (hl)		; Hyp.cls 3205
            and #7F		; Hyp.cls 3206
            cp c		; Hyp.cls 3207
            jr nz, asm_1_2316_n_fl_s_lp		; Hyp.cls 3208
asm_1_2316_n_fl_s_any:		; Hyp.cls 3209
            inc hl		; Hyp.cls 3210
            inc de		; Hyp.cls 3211
            djnz asm_1_2316_n_fl_s_cmp		; Hyp.cls 3212
            ld hl, (var_hyp_filecall_buf)          ; the entry: user 0, the name, extent 0, the records, no blocks [3213]
            ld (hl), 0		; Hyp.cls 3214
            ld de, 14		; Hyp.cls 3215
            add hl, de		; Hyp.cls 3216
            ld e, (hl)		; Hyp.cls 3217
            inc hl		; Hyp.cls 3218
            ld d, (hl)		; Hyp.cls 3219
            ex de, hl		; Hyp.cls 3220
            ld bc, 127		; Hyp.cls 3221
            add hl, bc		; Hyp.cls 3222
            jr c, asm_1_2316_n_fl_s_big		; Hyp.cls 3223
            ld a, h		; Hyp.cls 3224
            cp #40		; Hyp.cls 3225
            jr nc, asm_1_2316_n_fl_s_big		; Hyp.cls 3226
            sla l		; Hyp.cls 3227
            rla		; Hyp.cls 3228
            jr asm_1_2316_n_fl_s_rc		; Hyp.cls 3229
asm_1_2316_n_fl_s_big:		; Hyp.cls 3230
            ld a, 128		; Hyp.cls 3231
asm_1_2316_n_fl_s_rc:		; Hyp.cls 3232
            ex de, hl		; Hyp.cls 3233
            ld (hl), a		; Hyp.cls 3234
            ld b, 3		; Hyp.cls 3235
asm_1_2316_n_fl_s_z1:		; Hyp.cls 3236
            dec hl		; Hyp.cls 3237
            ld (hl), 0		; Hyp.cls 3238
            djnz asm_1_2316_n_fl_s_z1		; Hyp.cls 3239
            ld de, 4		; Hyp.cls 3240
            add hl, de		; Hyp.cls 3241
            ld b, 16		; Hyp.cls 3242
asm_1_2316_n_fl_s_z2:		; Hyp.cls 3243
            ld (hl), 0		; Hyp.cls 3244
            inc hl		; Hyp.cls 3245
            djnz asm_1_2316_n_fl_s_z2		; Hyp.cls 3246
            ld hl, (var_hyp_filecall_dma)		; Hyp.cls 3247
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 3248
            ld b, 32		; Hyp.cls 3249
asm_1_2316_n_fl_s_put:		; Hyp.cls 3250
            ld a, (de)		; Hyp.cls 3251
            call asm_1_2316_n_fl_poke		; Hyp.cls 3252
            inc hl		; Hyp.cls 3253
            inc de		; Hyp.cls 3254
            djnz asm_1_2316_n_fl_s_put		; Hyp.cls 3255
            ld hl, 63216 + 12		; Hyp.cls 3256
            ld a, (asm_1_2316_n_fl_k)		; Hyp.cls 3257
            call asm_1_2316_n_fl_poke		; Hyp.cls 3258
            jp asm_1_2316_n_fl_ok		; Hyp.cls 3259
asm_1_2316_n_fl_skip:    db 0		; Hyp.cls 3260
asm_1_2316_n_fl_k:       db 0		; Hyp.cls 3261
asm_1_2316_n_fl_cn:      db 0                    ; the folder's entries in the cache (#6000) [3262]
asm_1_2316_n_fl_ranput:                          ; the FCB's r0-r2 = HL [3263]
            ex de, hl		; Hyp.cls 3264
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3265
            ld bc, 33		; Hyp.cls 3266
            add hl, bc		; Hyp.cls 3267
            ld a, e		; Hyp.cls 3268
            call asm_1_2316_n_fl_poke		; Hyp.cls 3269
            inc hl		; Hyp.cls 3270
            ld a, d		; Hyp.cls 3271
            call asm_1_2316_n_fl_poke		; Hyp.cls 3272
            inc hl		; Hyp.cls 3273
            xor a		; Hyp.cls 3274
            jp asm_1_2316_n_fl_poke		; Hyp.cls 3275
; ---- the parts
asm_1_2316_n_fl_inopen:                          ; open fl_name_s to read: carry = done [3277]
            call asm_1_2316_n_fl_plain		; Hyp.cls 3278
            ld hl, asm_1_2316_n_fl_name_s + 1		; Hyp.cls 3279
            ld a, (asm_1_2316_n_fl_name_s)		; Hyp.cls 3280
            ld b, a		; Hyp.cls 3281
            ld de, #4000		; Hyp.cls 3282
            call #BC77              ; CAS IN OPEN [3283]
            di		; Hyp.cls 3284
            ld (asm_1_2316_n_fl_hdr), hl         ; (its header: BDOS 30 #C7) [3285]
            ret		; Hyp.cls 3286
asm_1_2316_n_fl_inclose:		; Hyp.cls 3287
            xor a		; Hyp.cls 3288
            ld (var_hyp_fin), a		; Hyp.cls 3289
            call asm_1_2316_n_fl_plain		; Hyp.cls 3290
            call #BC7A              ; CAS IN CLOSE [3291]
            di		; Hyp.cls 3292
            ret		; Hyp.cls 3293
asm_1_2316_n_fl_rdrec:                           ; read up to fl_n bytes (128) into buf: A = how many (Z [3294]
            call asm_1_2316_n_fl_plain           ; none), HL past them. A #1A is a byte (the soft end of file) [3295]
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 3296
            ld a, (asm_1_2316_n_fl_n)		; Hyp.cls 3297
            ld b, a		; Hyp.cls 3298
asm_1_2316_n_fl_rr_lp:		; Hyp.cls 3299
            push bc		; Hyp.cls 3300
            push hl		; Hyp.cls 3301
            call #BC80              ; CAS IN CHAR [3302]
            di		; Hyp.cls 3303
            pop hl		; Hyp.cls 3304
            pop bc		; Hyp.cls 3305
            jr c, asm_1_2316_n_fl_rr_b		; Hyp.cls 3306
            cp #1A		; Hyp.cls 3307
            jr nz, asm_1_2316_n_fl_rr_end		; Hyp.cls 3308
asm_1_2316_n_fl_rr_b:		; Hyp.cls 3309
            ld (hl), a		; Hyp.cls 3310
            inc hl		; Hyp.cls 3311
            djnz asm_1_2316_n_fl_rr_lp		; Hyp.cls 3312
asm_1_2316_n_fl_rr_end:		; Hyp.cls 3313
            ld a, (asm_1_2316_n_fl_n)		; Hyp.cls 3314
            sub b		; Hyp.cls 3315
            ld c, a		; Hyp.cls 3316
            ld a, 128		; Hyp.cls 3317
            ld (asm_1_2316_n_fl_n), a            ; (128 again for the next) [3318]
            ld a, c		; Hyp.cls 3319
            or a		; Hyp.cls 3320
            ret		; Hyp.cls 3321
asm_1_2316_n_fl_fits:                            ; HL = a slot address, BC = bytes: NC = all in its 16K page. [3322]
            push hl                 ; Keeps BC, DE, HL [3323]
            ld a, h		; Hyp.cls 3324
            and #3F		; Hyp.cls 3325
            ld h, a		; Hyp.cls 3326
            add hl, bc		; Hyp.cls 3327
            ld a, h		; Hyp.cls 3328
            cp #40		; Hyp.cls 3329
            jr c, asm_1_2316_n_fl_ft_ok		; Hyp.cls 3330
            jr nz, asm_1_2316_n_fl_ft_no		; Hyp.cls 3331
            ld a, l		; Hyp.cls 3332
            or a		; Hyp.cls 3333
            jr nz, asm_1_2316_n_fl_ft_no		; Hyp.cls 3334
asm_1_2316_n_fl_ft_ok:		; Hyp.cls 3335
            pop hl		; Hyp.cls 3336
            or a		; Hyp.cls 3337
            ret		; Hyp.cls 3338
asm_1_2316_n_fl_ft_no:		; Hyp.cls 3339
            pop hl		; Hyp.cls 3340
            scf		; Hyp.cls 3341
            ret		; Hyp.cls 3342
asm_1_2316_n_fl_plain:                           ; the hypervisor's page in the window (the buffers) [3343]
            ld bc, (var_hyp_hps)		; Hyp.cls 3344
            out (c), c		; Hyp.cls 3345
            ret		; Hyp.cls 3346
asm_1_2316_n_fl_name:                            ; fl_name_s = the FCB's file: length, "B:NAME.EXT" [3347]
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3348
asm_1_2316_n_fl_namehl:                          ; (HL = an FCB in the slot) [3349]
            ld de, asm_1_2316_n_fl_name_s + 1		; Hyp.cls 3350
            call asm_1_2316_n_fl_peek            ; its drive: 0 = the slot's (or fl_dfl's) [3351]
            or a		; Hyp.cls 3352
            jr nz, asm_1_2316_n_fl_nm_d		; Hyp.cls 3353
            ld a, (asm_1_2316_n_fl_dfl)		; Hyp.cls 3354
            or a		; Hyp.cls 3355
            jr nz, asm_1_2316_n_fl_nm_d		; Hyp.cls 3356
            ld a, (var_hyp_filecall_drive)		; Hyp.cls 3357
            or a		; Hyp.cls 3358
            jr z, asm_1_2316_n_fl_nm_nod		; Hyp.cls 3359
            sub 64		; Hyp.cls 3360
asm_1_2316_n_fl_nm_d:		; Hyp.cls 3361
            add a, 64		; Hyp.cls 3362
            call asm_1_2316_n_fl_pfx             ; "B:", or B's path (UniDOS: "IDE:GAMES/") [3363]
asm_1_2316_n_fl_nm_nod:		; Hyp.cls 3364
            ld b, 11		; Hyp.cls 3365
asm_1_2316_n_fl_nm_lp:		; Hyp.cls 3366
            inc hl		; Hyp.cls 3367
            ld a, b		; Hyp.cls 3368
            cp 3		; Hyp.cls 3369
            jr nz, asm_1_2316_n_fl_nm_c		; Hyp.cls 3370
            ld a, '.'		; Hyp.cls 3371
            ld (de), a		; Hyp.cls 3372
            inc de		; Hyp.cls 3373
asm_1_2316_n_fl_nm_c:		; Hyp.cls 3374
            call asm_1_2316_n_fl_peek		; Hyp.cls 3375
            and #7F		; Hyp.cls 3376
            cp ' ' + 1		; Hyp.cls 3377
            jr c, asm_1_2316_n_fl_nm_sk		; Hyp.cls 3378
            ld (de), a		; Hyp.cls 3379
            inc de		; Hyp.cls 3380
asm_1_2316_n_fl_nm_sk:		; Hyp.cls 3381
            djnz asm_1_2316_n_fl_nm_lp		; Hyp.cls 3382
            ex de, hl		; Hyp.cls 3383
            ld de, asm_1_2316_n_fl_name_s + 1		; Hyp.cls 3384
            or a		; Hyp.cls 3385
            sbc hl, de		; Hyp.cls 3386
            ld a, l		; Hyp.cls 3387
            ld (asm_1_2316_n_fl_name_s), a		; Hyp.cls 3388
            ret		; Hyp.cls 3389
asm_1_2316_n_fl_ok:		; Hyp.cls 3390
            xor a		; Hyp.cls 3391
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 3392
asm_1_2316_n_fp_done:                            ; back to FileCall in main RAM (fp_done) [3393]
            ld sp, (asm_1_2316_n_fp_sp)		; Hyp.cls 3394
            ret		; Hyp.cls 3395
asm_1_2316_n_fl_era:     db "ER", "A" + #80		; Hyp.cls 3396
asm_1_2316_n_fl_rencmd:  db "RE", "N" + #80		; Hyp.cls 3397
asm_1_2316_n_fl_par2:    dw asm_1_2316_n_fl_desc, asm_1_2316_n_fl_desc2		; Hyp.cls 3398
asm_1_2316_n_fl_desc2:   db 0		; Hyp.cls 3399
            dw 0		; Hyp.cls 3400
asm_1_2316_n_fl_dfl:     db 0                    ; fl_name: the drive for an FCB whose own is 0 (rename) [3401]
asm_1_2316_n_fl_par:     dw asm_1_2316_n_fl_desc		; Hyp.cls 3402
asm_1_2316_n_fl_desc:    db 0		; Hyp.cls 3403
            dw 0		; Hyp.cls 3404
asm_1_2316_n_fl_n:       db 128                  ; bytes fl_rdrec reads [3405]
asm_1_2316_n_fl_cnt:     dw 0		; Hyp.cls 3406
asm_1_2316_n_fl_at:      dw 0		; Hyp.cls 3407
asm_1_2316_n_fl_infcb:   dw 0		; Hyp.cls 3408
            db 0                    ; (1: fl_infcb the open's - fl_is) [3409]
asm_1_2316_n_fl_inrec:   dw 0		; Hyp.cls 3410
asm_1_2316_n_fl_want:    dw 0		; Hyp.cls 3411
asm_1_2316_n_fl_outfcb:  dw 0		; Hyp.cls 3412
            db 0		; Hyp.cls 3413
asm_1_2316_n_fl_outrec:  dw 0                    ; the next record written (36) [3414]
asm_1_2316_n_fl_had:     db 0                    ; 35: this slot's read file closed for it [3415]
asm_1_2316_n_fp_sp:      dw 0		; Hyp.cls 3416
; ---- UniDOS: its Ctrl J BIOS command (found once, KL FIND COMMAND) - a drive letter can be a
; path (CD IDE:, CD SD:GAMES ...: any UniDOS device's folder), folders listed (examine). FL_MAP:
; letters A-P, 32 bytes each: the path's length (0 none: the letter itself, "B:"), the path
; ("IDE:GAMES/": a device or logical drive, its folders, the last "/" or ":"). Cleared when
; UniDOS is found, and only set with it: with AMSDOS no letter has a path. Up there with the
; names (48 characters: a path and NAME.EXT), BDOS 132's block, DIR's listing: the FILES.DIR
; cache is #6000-#7BFF (112 entries)
asm_1_2316_n_FL_CMAX:    equ 112                 ; the cache's entries [3424]
asm_1_2316_n_FL_NL:      equ 49                  ; a name: its length, then the characters [3425]
asm_1_2316_n_fl_name_s:  equ #7C00               ; length, then "B:NAME.EXT" (or "IDE:GAMES/NAME.EXT") [3426]
asm_1_2316_n_fl_inname:  equ asm_1_2316_n_fl_name_s + asm_1_2316_n_FL_NL   ; the one being read's (33 going back) [3427]
asm_1_2316_n_fl_new_s:   equ asm_1_2316_n_fl_inname + asm_1_2316_n_FL_NL   ; (23: the new name) [3428]
asm_1_2316_n_FL_UB:      equ #7D00               ; BDOS 132's block (72 bytes) [3429]
asm_1_2316_n_FL_EXK:     equ #7D48               ; the folder DIR lists (its path: length, 31 characters) [3430]
asm_1_2316_n_FL_DATE:    equ #7D68               ; a date examine gives (7), then a name (11) [3431]
asm_1_2316_n_FL_TN:      equ #7D70		; Hyp.cls 3432
asm_1_2316_n_FL_MAP:     equ #7E00		; Hyp.cls 3433
            ASSERT #6000 + asm_1_2316_n_FL_CMAX * 64 <= asm_1_2316_n_fl_name_s, "the search's cache, below the names"		; Hyp.cls 3434
            ASSERT asm_1_2316_n_fl_new_s + asm_1_2316_n_FL_NL <= asm_1_2316_n_FL_UB, "the names, below BDOS 132's block"		; Hyp.cls 3435
            ASSERT (asm_1_2316_n_FL_MAP & 255) = 0, "asm_1_2316_n_FL_MAP: a page's start (asm_1_2316_n_fl_mapa)"		; Hyp.cls 3436
asm_1_2316_n_fl_cjf:     db 0                    ; 0: not looked for yet, 1: UniDOS, 2: none [3437]
asm_1_2316_n_fl_cj:      dw 0                    ; Ctrl J's far address (address, ROM) [3438]
            db 0		; Hyp.cls 3439
asm_1_2316_n_fl_cjn:     db #8A                  ; (its name) [3440]
asm_1_2316_n_fl_exv:     db 0                    ; FL_EXK's listing is the one UniDOS examines now ... [3441]
asm_1_2316_n_fl_exi:     dw 0                    ; ... at this entry next [3442]
asm_1_2316_n_fl_ue:      dw 0		; Hyp.cls 3443
; carry: UniDOS here (the first time: looked for, the paths cleared)
asm_1_2316_n_fl_uni:		; Hyp.cls 3445
            ld a, (asm_1_2316_n_fl_cjf)		; Hyp.cls 3446
            cp 1		; Hyp.cls 3447
            jr z, asm_1_2316_n_fl_un_y		; Hyp.cls 3448
            or a		; Hyp.cls 3449
            ret nz                  ; (2: none - NC) [3450]
            ld hl, asm_1_2316_n_fl_cjn		; Hyp.cls 3451
            call #BCD4              ; KL FIND COMMAND: C = its ROM, HL = its address [3452]
            di		; Hyp.cls 3453
            ld a, 2		; Hyp.cls 3454
            jr nc, asm_1_2316_n_fl_un_s		; Hyp.cls 3455
            ld (asm_1_2316_n_fl_cj), hl		; Hyp.cls 3456
            ld a, c		; Hyp.cls 3457
            ld (asm_1_2316_n_fl_cj + 2), a		; Hyp.cls 3458
            ld hl, asm_1_2316_n_FL_MAP		; Hyp.cls 3459
            ld de, asm_1_2316_n_FL_MAP + 1		; Hyp.cls 3460
            ld bc, 511		; Hyp.cls 3461
            ld (hl), 0		; Hyp.cls 3462
            ldir		; Hyp.cls 3463
            ld a, 1		; Hyp.cls 3464
asm_1_2316_n_fl_un_s:		; Hyp.cls 3465
            ld (asm_1_2316_n_fl_cjf), a		; Hyp.cls 3466
            jr asm_1_2316_n_fl_uni		; Hyp.cls 3467
asm_1_2316_n_fl_un_y:		; Hyp.cls 3468
            scf		; Hyp.cls 3469
            ret		; Hyp.cls 3470
; Ctrl J command C (the other registers its input; its output back)
asm_1_2316_n_fl_cjc:		; Hyp.cls 3472
            rst #18                 ; (RST 3: a far call) [3473]
            dw asm_1_2316_n_fl_cj		; Hyp.cls 3474
            di		; Hyp.cls 3475
            ret		; Hyp.cls 3476
; A = a drive letter: HL = its FL_MAP entry, A = its path's length (Z: none). Carry: not A-P,
; or no UniDOS (no paths). A, HL only
asm_1_2316_n_fl_mapa:		; Hyp.cls 3479
            sub 'A'		; Hyp.cls 3480
            cp 16		; Hyp.cls 3481
            ccf		; Hyp.cls 3482
            ret c		; Hyp.cls 3483
            ld l, a		; Hyp.cls 3484
            ld a, (asm_1_2316_n_fl_cjf)		; Hyp.cls 3485
            cp 1		; Hyp.cls 3486
            scf		; Hyp.cls 3487
            ret nz		; Hyp.cls 3488
            ld h, 0		; Hyp.cls 3489
            add hl, hl		; Hyp.cls 3490
            add hl, hl		; Hyp.cls 3491
            add hl, hl		; Hyp.cls 3492
            add hl, hl		; Hyp.cls 3493
            add hl, hl		; Hyp.cls 3494
            ld a, h		; Hyp.cls 3495
            add a, asm_1_2316_n_FL_MAP / 256		; Hyp.cls 3496
            ld h, a		; Hyp.cls 3497
            ld a, (hl)		; Hyp.cls 3498
            or a		; Hyp.cls 3499
            ret		; Hyp.cls 3500
; A = a drive letter: "B:" at DE, or its path - DE past it (BC, HL kept)
asm_1_2316_n_fl_pfx:		; Hyp.cls 3502
            push af		; Hyp.cls 3503
            call asm_1_2316_n_fl_pfxm		; Hyp.cls 3504
            jr nz, asm_1_2316_n_fl_px_d		; Hyp.cls 3505
            pop af		; Hyp.cls 3506
            ld (de), a		; Hyp.cls 3507
            inc de		; Hyp.cls 3508
            ld a, ':'		; Hyp.cls 3509
            ld (de), a		; Hyp.cls 3510
            inc de		; Hyp.cls 3511
            ret		; Hyp.cls 3512
asm_1_2316_n_fl_px_d:		; Hyp.cls 3513
            pop af		; Hyp.cls 3514
            ret		; Hyp.cls 3515
; ... its path only, if it has one (NZ; Z: none, nothing put)
asm_1_2316_n_fl_pfxm:		; Hyp.cls 3517
            push hl		; Hyp.cls 3518
            call asm_1_2316_n_fl_mapa		; Hyp.cls 3519
            jr c, asm_1_2316_n_fl_pm_no		; Hyp.cls 3520
            jr z, asm_1_2316_n_fl_pm_no		; Hyp.cls 3521
            push bc		; Hyp.cls 3522
            ld c, a		; Hyp.cls 3523
            ld b, 0		; Hyp.cls 3524
            inc hl		; Hyp.cls 3525
            ldir		; Hyp.cls 3526
            pop bc		; Hyp.cls 3527
            or a		; Hyp.cls 3528
            jr asm_1_2316_n_fl_pm_r		; Hyp.cls 3529
asm_1_2316_n_fl_pm_no:		; Hyp.cls 3530
            xor a		; Hyp.cls 3531
asm_1_2316_n_fl_pm_r:		; Hyp.cls 3532
            pop hl		; Hyp.cls 3533
            ret		; Hyp.cls 3534
asm_1_2316_n_fl_nlen:                            ; fl_name_s's length: its characters end at DE [3535]
            ld hl, -(asm_1_2316_n_fl_name_s + 1)		; Hyp.cls 3536
            add hl, de		; Hyp.cls 3537
            ld a, l		; Hyp.cls 3538
            ld (asm_1_2316_n_fl_name_s), a		; Hyp.cls 3539
            ret		; Hyp.cls 3540
; the folder whose path is at fl_name_s + 1 to DE (fl_exdir2: fl_name_s, its length set)
; examined (Ctrl J 12): Z its listing ready (examine next: Ctrl J 13), NZ no UniDOS, a drive
; it can't examine (AMSDOS's floppies), not a folder
asm_1_2316_n_fl_exdir:		; Hyp.cls 3544
            call asm_1_2316_n_fl_nlen		; Hyp.cls 3545
asm_1_2316_n_fl_exdir2:		; Hyp.cls 3546
            call asm_1_2316_n_fl_uni		; Hyp.cls 3547
            jr nc, asm_1_2316_n_fl_ed_no		; Hyp.cls 3548
            xor a		; Hyp.cls 3549
            ld (asm_1_2316_n_fl_exv), a		; Hyp.cls 3550
            ld hl, asm_1_2316_n_fl_name_s		; Hyp.cls 3551
            ld b, (hl)		; Hyp.cls 3552
            inc hl		; Hyp.cls 3553
            ld ix, asm_1_2316_n_FL_DATE		; Hyp.cls 3554
            ld c, 12		; Hyp.cls 3555
            call asm_1_2316_n_fl_cjc		; Hyp.cls 3556
            ret c		; Hyp.cls 3557
asm_1_2316_n_fl_ed_no:		; Hyp.cls 3558
            ld a, 254               ; (254: no UniDOS, or a drive it can't examine) [3559]
            or a		; Hyp.cls 3560
            ret		; Hyp.cls 3561
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
asm_1_2316_n_fl_unicall:		; Hyp.cls 3585
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3586
            ld de, asm_1_2316_n_FL_UB		; Hyp.cls 3587
            ld b, 72		; Hyp.cls 3588
asm_1_2316_n_fl_uc_in:		; Hyp.cls 3589
            call asm_1_2316_n_fl_peek		; Hyp.cls 3590
            ld (de), a		; Hyp.cls 3591
            inc hl		; Hyp.cls 3592
            inc de		; Hyp.cls 3593
            djnz asm_1_2316_n_fl_uc_in		; Hyp.cls 3594
            ld a, (asm_1_2316_n_FL_UB)		; Hyp.cls 3595
            sub #C0		; Hyp.cls 3596
            cp 9		; Hyp.cls 3597
            jp nc, asm_1_2316_n_fp_done          ; (CP/M's 30) [3598]
            ld (asm_1_2316_n_FL_UB), a		; Hyp.cls 3599
            call asm_1_2316_n_fl_uni		; Hyp.cls 3600
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 3601
            ld a, (asm_1_2316_n_FL_UB)		; Hyp.cls 3602
            or a		; Hyp.cls 3603
            jp z, asm_1_2316_n_fl_ok		; Hyp.cls 3604
            dec a		; Hyp.cls 3605
            jp z, asm_1_2316_n_fl_uc_get		; Hyp.cls 3606
            dec a		; Hyp.cls 3607
            jp z, asm_1_2316_n_fl_uc_set		; Hyp.cls 3608
            dec a		; Hyp.cls 3609
            jp z, asm_1_2316_n_fl_uc_dev		; Hyp.cls 3610
            dec a		; Hyp.cls 3611
            jp z, asm_1_2316_n_fl_uc_inf		; Hyp.cls 3612
            dec a		; Hyp.cls 3613
            jp z, asm_1_2316_n_fl_uc_dir		; Hyp.cls 3614
            dec a		; Hyp.cls 3615
            jr z, asm_1_2316_n_fl_uc_md		; Hyp.cls 3616
            cp 2		; Hyp.cls 3617
            jr z, asm_1_2316_n_fl_uc_yes		; Hyp.cls 3618
            ld a, (var_hyp_fin)           ; 7: the header of the file this slot reads (the disc ROM's, [3619]
            ld hl, asm_1_2316_n_fl_slot          ; from CAS IN OPEN: 69 bytes) to Byte(2) [3620]
            cp (hl)		; Hyp.cls 3621
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 3622
            ld hl, (asm_1_2316_n_fl_hdr)		; Hyp.cls 3623
            ld de, asm_1_2316_n_FL_UB + 2		; Hyp.cls 3624
            ld bc, 69		; Hyp.cls 3625
            ldir		; Hyp.cls 3626
            xor a		; Hyp.cls 3627
            ld b, 71		; Hyp.cls 3628
            jp asm_1_2316_n_fl_uc_back		; Hyp.cls 3629
asm_1_2316_n_fl_hdr:     dw 0		; Hyp.cls 3630
asm_1_2316_n_fl_uc_yes:                          ; 8: the next delete (19) may take a folder (RMDIR's) [3631]
            ld a, 1		; Hyp.cls 3632
            ld (asm_1_2316_n_fl_yes), a		; Hyp.cls 3633
            jp asm_1_2316_n_fl_ok		; Hyp.cls 3634
asm_1_2316_n_fl_yes:     db 0		; Hyp.cls 3635
asm_1_2316_n_fl_uc_md:                           ; 6: a folder made (CAS OUT OPEN, the path ending "/") [3636]
            ld a, (var_hyp_fout)		; Hyp.cls 3637
            or a		; Hyp.cls 3638
            jp nz, asm_1_2316_n_fp_done		; Hyp.cls 3639
            ld hl, asm_1_2316_n_FL_UB + 2		; Hyp.cls 3640
            ld a, (hl)		; Hyp.cls 3641
            or a		; Hyp.cls 3642
            jp z, asm_1_2316_n_fp_done		; Hyp.cls 3643
            ld b, a		; Hyp.cls 3644
            inc hl		; Hyp.cls 3645
            ld de, #4800		; Hyp.cls 3646
            call #BC8C              ; CAS OUT OPEN [3647]
            di		; Hyp.cls 3648
            jr nc, asm_1_2316_n_fl_md_nc		; Hyp.cls 3649
            call #BC92              ; (a file: CAS OUT ABANDON - not made) [3650]
            di		; Hyp.cls 3651
            ld a, 1		; Hyp.cls 3652
            jr asm_1_2316_n_fl_md_r		; Hyp.cls 3653
asm_1_2316_n_fl_md_nc:		; Hyp.cls 3654
            and #7F		; Hyp.cls 3655
            cp #17                  ; (DSK_ERR_DIRECTORY_FOUND: made) [3656]
            jp z, asm_1_2316_n_fl_ok		; Hyp.cls 3657
            or a		; Hyp.cls 3658
            jr nz, asm_1_2316_n_fl_md_r		; Hyp.cls 3659
            inc a		; Hyp.cls 3660
asm_1_2316_n_fl_md_r:		; Hyp.cls 3661
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 3662
            jp asm_1_2316_n_fp_done		; Hyp.cls 3663
asm_1_2316_n_fl_uc_back:                         ; A the answer, the block's first B bytes back to the slot [3664]
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 3665
            ld a, (asm_1_2316_n_FL_UB)		; Hyp.cls 3666
            add a, #C0		; Hyp.cls 3667
            ld (asm_1_2316_n_FL_UB), a		; Hyp.cls 3668
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 3669
            ld de, asm_1_2316_n_FL_UB		; Hyp.cls 3670
asm_1_2316_n_fl_uc_out:		; Hyp.cls 3671
            ld a, (de)		; Hyp.cls 3672
            call asm_1_2316_n_fl_poke		; Hyp.cls 3673
            inc hl		; Hyp.cls 3674
            inc de		; Hyp.cls 3675
            djnz asm_1_2316_n_fl_uc_out		; Hyp.cls 3676
            jp asm_1_2316_n_fp_done		; Hyp.cls 3677
asm_1_2316_n_fl_uc_get:		; Hyp.cls 3678
            ld a, (asm_1_2316_n_FL_UB + 1)		; Hyp.cls 3679
            call asm_1_2316_n_fl_mapa		; Hyp.cls 3680
            jp c, asm_1_2316_n_fp_done		; Hyp.cls 3681
            ld de, asm_1_2316_n_FL_UB + 2		; Hyp.cls 3682
            ld c, (hl)		; Hyp.cls 3683
            ld b, 0		; Hyp.cls 3684
            inc bc		; Hyp.cls 3685
            ldir		; Hyp.cls 3686
            xor a		; Hyp.cls 3687
            ld b, 34		; Hyp.cls 3688
            jr asm_1_2316_n_fl_uc_back		; Hyp.cls 3689
asm_1_2316_n_fl_uc_dev:		; Hyp.cls 3690
            ld de, asm_1_2316_n_FL_UB + 2		; Hyp.cls 3691
            ld c, 1		; Hyp.cls 3692
            call asm_1_2316_n_fl_cjc		; Hyp.cls 3693
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 3694
            xor a		; Hyp.cls 3695
            ld b, 66		; Hyp.cls 3696
            jr asm_1_2316_n_fl_uc_back		; Hyp.cls 3697
asm_1_2316_n_fl_uc_inf:		; Hyp.cls 3698
            ld hl, asm_1_2316_n_FL_UB + 2		; Hyp.cls 3699
            ld de, asm_1_2316_n_FL_UB + 8		; Hyp.cls 3700
            ld c, 2		; Hyp.cls 3701
            call asm_1_2316_n_fl_cjc		; Hyp.cls 3702
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 3703
            xor a		; Hyp.cls 3704
            ld b, 72		; Hyp.cls 3705
            jr asm_1_2316_n_fl_uc_back		; Hyp.cls 3706
asm_1_2316_n_fl_uc_set:		; Hyp.cls 3707
            ld a, (asm_1_2316_n_FL_UB + 1)		; Hyp.cls 3708
            call asm_1_2316_n_fl_mapa		; Hyp.cls 3709
            jp c, asm_1_2316_n_fp_done		; Hyp.cls 3710
            ld (asm_1_2316_n_fl_ue), hl		; Hyp.cls 3711
            xor a		; Hyp.cls 3712
            ld (asm_1_2316_n_fl_exv), a		; Hyp.cls 3713
            ld a, (asm_1_2316_n_FL_UB + 2)		; Hyp.cls 3714
            or a		; Hyp.cls 3715
            jr z, asm_1_2316_n_fl_us_put         ; none: the letter itself again [3716]
            cp 32		; Hyp.cls 3717
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 3718
            ld b, a		; Hyp.cls 3719
            ld hl, asm_1_2316_n_FL_UB + 3		; Hyp.cls 3720
asm_1_2316_n_fl_us_up:                           ; capitals [3721]
            ld a, (hl)		; Hyp.cls 3722
            cp 'a'		; Hyp.cls 3723
            jr c, asm_1_2316_n_fl_us_c		; Hyp.cls 3724
            cp 'z' + 1		; Hyp.cls 3725
            jr nc, asm_1_2316_n_fl_us_c		; Hyp.cls 3726
            sub 32		; Hyp.cls 3727
            ld (hl), a		; Hyp.cls 3728
asm_1_2316_n_fl_us_c:		; Hyp.cls 3729
            inc hl		; Hyp.cls 3730
            djnz asm_1_2316_n_fl_us_up		; Hyp.cls 3731
            dec hl		; Hyp.cls 3732
            ld a, (hl)		; Hyp.cls 3733
            cp ':'		; Hyp.cls 3734
            jr z, asm_1_2316_n_fl_us_ex		; Hyp.cls 3735
            cp '/'		; Hyp.cls 3736
            jr z, asm_1_2316_n_fl_us_ex		; Hyp.cls 3737
            ld a, (asm_1_2316_n_FL_UB + 2)		; Hyp.cls 3738
            cp 31		; Hyp.cls 3739
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 3740
            inc a		; Hyp.cls 3741
            ld (asm_1_2316_n_FL_UB + 2), a		; Hyp.cls 3742
            inc hl		; Hyp.cls 3743
            ld (hl), '/'		; Hyp.cls 3744
asm_1_2316_n_fl_us_ex:		; Hyp.cls 3745
            ld hl, asm_1_2316_n_FL_UB + 2        ; a folder? [3746]
            ld de, asm_1_2316_n_fl_name_s		; Hyp.cls 3747
            ld bc, 32		; Hyp.cls 3748
            ldir		; Hyp.cls 3749
            call asm_1_2316_n_fl_exdir2		; Hyp.cls 3750
            jr z, asm_1_2316_n_fl_us_put		; Hyp.cls 3751
            cp 254		; Hyp.cls 3752
            jr z, asm_1_2316_n_fl_us_put         ; (a floppy AMSDOS runs - DFA:, DFB: - can't be examined: taken) [3753]
            or a		; Hyp.cls 3754
            jr nz, asm_1_2316_n_fl_us_err		; Hyp.cls 3755
            inc a		; Hyp.cls 3756
asm_1_2316_n_fl_us_err:		; Hyp.cls 3757
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 3758
            jp asm_1_2316_n_fp_done		; Hyp.cls 3759
asm_1_2316_n_fl_us_put:		; Hyp.cls 3760
            ld hl, asm_1_2316_n_FL_UB + 2		; Hyp.cls 3761
            ld de, (asm_1_2316_n_fl_ue)		; Hyp.cls 3762
            ld bc, 32		; Hyp.cls 3763
            ldir		; Hyp.cls 3764
            jp asm_1_2316_n_fl_ok		; Hyp.cls 3765
asm_1_2316_n_fl_uc_dir:		; Hyp.cls 3766
            ld de, asm_1_2316_n_fl_name_s + 1    ; the folder's path [3767]
            ld a, (asm_1_2316_n_FL_UB + 1)		; Hyp.cls 3768
            or a		; Hyp.cls 3769
            jr z, asm_1_2316_n_fl_ud_p		; Hyp.cls 3770
            call asm_1_2316_n_fl_pfx		; Hyp.cls 3771
            jr asm_1_2316_n_fl_ud_k		; Hyp.cls 3772
asm_1_2316_n_fl_ud_p:		; Hyp.cls 3773
            ld hl, asm_1_2316_n_FL_UB + 28		; Hyp.cls 3774
            ld a, (hl)		; Hyp.cls 3775
            cp 32		; Hyp.cls 3776
            jp nc, asm_1_2316_n_fp_done		; Hyp.cls 3777
            ld c, a		; Hyp.cls 3778
            ld b, 0		; Hyp.cls 3779
            inc hl		; Hyp.cls 3780
            ldir		; Hyp.cls 3781
asm_1_2316_n_fl_ud_k:		; Hyp.cls 3782
            call asm_1_2316_n_fl_nlen		; Hyp.cls 3783
            ld hl, asm_1_2316_n_fl_name_s        ; the same folder, still the one examined, at this entry: [3784]
            ld de, asm_1_2316_n_FL_EXK           ; on from there [3785]
            ld a, (asm_1_2316_n_fl_exv)		; Hyp.cls 3786
            or a		; Hyp.cls 3787
            jr z, asm_1_2316_n_fl_ud_new		; Hyp.cls 3788
            ld a, (hl)		; Hyp.cls 3789
            inc a		; Hyp.cls 3790
            ld b, a		; Hyp.cls 3791
asm_1_2316_n_fl_ud_cmp:		; Hyp.cls 3792
            ld a, (de)		; Hyp.cls 3793
            cp (hl)		; Hyp.cls 3794
            jr nz, asm_1_2316_n_fl_ud_new		; Hyp.cls 3795
            inc hl		; Hyp.cls 3796
            inc de		; Hyp.cls 3797
            djnz asm_1_2316_n_fl_ud_cmp		; Hyp.cls 3798
            ld hl, (asm_1_2316_n_fl_exi)		; Hyp.cls 3799
            ld de, (asm_1_2316_n_FL_UB + 2)		; Hyp.cls 3800
            or a		; Hyp.cls 3801
            sbc hl, de		; Hyp.cls 3802
            jr z, asm_1_2316_n_fl_ud_next		; Hyp.cls 3803
asm_1_2316_n_fl_ud_new:		; Hyp.cls 3804
            ld hl, asm_1_2316_n_fl_name_s		; Hyp.cls 3805
            ld de, asm_1_2316_n_FL_EXK		; Hyp.cls 3806
            ld bc, 32		; Hyp.cls 3807
            ldir		; Hyp.cls 3808
            call asm_1_2316_n_fl_exdir2		; Hyp.cls 3809
            jr z, asm_1_2316_n_fl_ud_ok		; Hyp.cls 3810
            or a		; Hyp.cls 3811
            jr nz, asm_1_2316_n_fl_us_err		; Hyp.cls 3812
            inc a		; Hyp.cls 3813
            jr asm_1_2316_n_fl_us_err		; Hyp.cls 3814
asm_1_2316_n_fl_ud_ok:		; Hyp.cls 3815
            ld hl, 0		; Hyp.cls 3816
            ld (asm_1_2316_n_fl_exi), hl		; Hyp.cls 3817
            ld a, 1		; Hyp.cls 3818
            ld (asm_1_2316_n_fl_exv), a		; Hyp.cls 3819
asm_1_2316_n_fl_ud_skip:                         ; on to entry Word(2) [3820]
            ld hl, (asm_1_2316_n_fl_exi)		; Hyp.cls 3821
            ld de, (asm_1_2316_n_FL_UB + 2)		; Hyp.cls 3822
            or a		; Hyp.cls 3823
            sbc hl, de		; Hyp.cls 3824
            jr z, asm_1_2316_n_fl_ud_next		; Hyp.cls 3825
            ld hl, asm_1_2316_n_FL_TN		; Hyp.cls 3826
            ld ix, asm_1_2316_n_FL_DATE		; Hyp.cls 3827
            ld c, 13		; Hyp.cls 3828
            call asm_1_2316_n_fl_cjc		; Hyp.cls 3829
            jr nc, asm_1_2316_n_fl_ud_end		; Hyp.cls 3830
            jr nz, asm_1_2316_n_fl_ud_end		; Hyp.cls 3831
            ld hl, (asm_1_2316_n_fl_exi)		; Hyp.cls 3832
            inc hl		; Hyp.cls 3833
            ld (asm_1_2316_n_fl_exi), hl		; Hyp.cls 3834
            jr asm_1_2316_n_fl_ud_skip		; Hyp.cls 3835
asm_1_2316_n_fl_ud_next:		; Hyp.cls 3836
            ld hl, asm_1_2316_n_FL_UB + 16		; Hyp.cls 3837
            ld ix, asm_1_2316_n_FL_UB + 9		; Hyp.cls 3838
            ld c, 13		; Hyp.cls 3839
            call asm_1_2316_n_fl_cjc		; Hyp.cls 3840
            jr nc, asm_1_2316_n_fl_ud_end		; Hyp.cls 3841
            jr nz, asm_1_2316_n_fl_ud_end		; Hyp.cls 3842
            ld (asm_1_2316_n_FL_UB + 4), a		; Hyp.cls 3843
            ld (asm_1_2316_n_FL_UB + 5), de		; Hyp.cls 3844
            ld (asm_1_2316_n_FL_UB + 7), bc		; Hyp.cls 3845
            ld hl, (asm_1_2316_n_fl_exi)		; Hyp.cls 3846
            inc hl		; Hyp.cls 3847
            ld (asm_1_2316_n_fl_exi), hl		; Hyp.cls 3848
            xor a		; Hyp.cls 3849
            ld b, 28		; Hyp.cls 3850
            jp asm_1_2316_n_fl_uc_back		; Hyp.cls 3851
asm_1_2316_n_fl_ud_end:		; Hyp.cls 3852
            xor a		; Hyp.cls 3853
            ld (asm_1_2316_n_fl_exv), a		; Hyp.cls 3854
            inc a		; Hyp.cls 3855
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 3856
            jp asm_1_2316_n_fp_done		; Hyp.cls 3857
asm_1_2316_n_fp_end:		; Hyp.cls 3858
            ASSERT asm_1_2316_n_fp_end <= #6000, "FileCall's page code: below the search's cache (#6000)"		; Hyp.cls 3859
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
			dw kw_scpgtvl, var_ns, 4
			dw kw_goto_iffalse_n, if2_1
			dw kw_ltov, 4, var_ns
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

			; Main.bas 109: i = Hyp.FileCall(99, 0, 0, 0, 0, 0, VarPtr(rb))  ' (the bank image and FileCall's page code into it,
			dw p_hyp_filecall_c, lit_99, lit_0, lit_0, lit_0, lit_0, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_i

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
			dw kw_vtov, var_memory_bankpage_bankpage, tmp0
			dw fn_memory_selectpage, tmp0, var_memory_selectpage_selectpage

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
			dw kw_strspace, stmp0, lit_82
			dw kw_strcpy, var_ob, stmp0

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

			; Main.bas 172: Do
do8_t:

			; Main.bas 173: hk = Hot.Take()
			dw p_hot_take_c
			dw kw_vtov, var_hot_take_take, var_hk

			; Main.bas 174: If hk = Hot.TOPKEY Then
			dw kw_cpeqvl, var_hk, 99
			dw kw_goto_iffalse_n, if9_1

			; Main.bas 175: If front = 0 Then ToFront back Else ShowTop      ' Control + ESC: TOP, and again: back
			dw kw_cpeqvl, var_front, 0
			dw kw_goto_iffalse_n, if10_1
			dw p_tofront_c, var_back
			dw if9_e_go
if10_1:
			dw p_showtop_c
if10_e:

			; Main.bas 176: ElseIf hk > 0 And hk <= ns Then
			dw if9_e_go
if9_1:
			dw kw_scpgtvl, var_hk, 0
			dw kw_ftov, tmp0
			dw kw_scplevv, var_hk, var_ns
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if9_2

			; Main.bas 177: ToFront hk
			dw p_tofront_c, var_hk

			; Main.bas 178: End If
if9_2:
if9_e:

			; Main.bas 179: If pk <> 0 And wt = 0 Then                    ' (a key left by a program: after WAIT's prompt)
			dw kw_cpnevl, var_pk, 0
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_wt, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if11_1

			; Main.bas 180: k = pk : pk = 0
			dw kw_vtov, var_pk, var_k
			dw kw_ztov, var_pk

			; Main.bas 181: KeyIn k
			dw p_keyin_c, var_k

			; Main.bas 182: ElseIf wt = 0 Then
			dw if11_e_go
if11_1:
			dw kw_cpeqvl, var_wt, 0
			dw kw_goto_iffalse_n, if11_2

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
			dw kw_goto_ifzero_n, tmp0, if11_e

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
			dw kw_goto_ifzero_n, tmp0, if11_e
			dw p_keyin_c, var_k
if13_1:

			; Main.bas 187: End If
if12_1:

			; Main.bas 188: ElseIf Running() = 0 Then
			dw if11_e_go
if11_2:
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if11_3

			; Main.bas 189: Prompt wt : wt = 0          ' WAIT: nothing runs any more
			dw p_prompt_c, var_wt
			dw kw_ztov, var_wt

			; Main.bas 190: End If
if11_3:
if11_e:

			; Main.bas 191: If Ticks - td >= 300 Then Roll
			dw kw_ticks, tmp0
			dw kw_subvv, tmp0, var_td, tmp0
			dw kw_scpgevl, tmp0, 300
			dw kw_goto_iffalse_n, if14_1
			dw p_roll_c
if14_1:

			; Main.bas 192: If front <> 0 Then
			dw kw_cpnevl, var_front, 0
			dw kw_goto_iffalse_n, if15_1

			; Main.bas 193: If Ticks - tc >= 150 Then tc = Ticks : Hyp.Con wp(front), 0, -3, 1   ' the cursor flashes (0.5 s)
			dw kw_ticks, tmp0
			dw kw_subvv, tmp0, var_tc, tmp0
			dw kw_scpgevl, tmp0, 150
			dw kw_goto_iffalse_n, if16_1
			dw kw_ticks, tmp0
			dw kw_vtov, tmp0, var_tc
			dw kw_aget, arr_wp, var_front, tmp0
			dw p_hyp_con_c, tmp0, lit_0, lit_m3, lit_1
if16_1:

			; Main.bas 194: End If
if15_1:

			; Main.bas 195: RunNext
			dw p_runnext_c

			; Main.bas 196: Loop Until quit
			dw kw_goto_ifzero_n, var_quit, do8_t
do8_e:

			; Main.bas 197: i = Hyp.Scr(0, 2)                 ' the CRTC as the firmware has it (80 x 25)
			dw p_hyp_scr_c, lit_0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_i

			; Main.bas 198: Hyp.Vdu 1
			dw p_hyp_vdu_c, lit_1

			; Main.bas 199: Mode 1
			dw kw_model, 1

			; Main.bas 200: Print "CyborgOS ended, "; runs; " programs ran"
			dw kw_printstrvar, str4
			dw kw_printint, var_runs
			dw kw_printstrvar, str5
			dw kw_printnl

			; Main.bas 201: End
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

			; Main.bas 205: Dim j As Integer

			; Main.bas 206: For j = 1 To ns
			dw kw_ltov, 1, var_running_j
			dw kw_vtov, var_ns, for17_l
			dw kw_forupv_n, var_running_j, for17_l, for17_e
for17_t:

			; Main.bas 207: If st(j) = 2 Then Running = Running + 1
			dw kw_aget, arr_st, var_running_j, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if18_1
			dw kw_inc, var_running_running
if18_1:

			; Main.bas 208: Next
			dw kw_next1v_n, var_running_j, for17_l, for17_t
for17_e:
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

			; Main.bas 214: Ready = 0
			dw kw_ztov, var_ready_ready

			; Main.bas 215: If t < 1 Then Exit Function
			dw kw_scpltvl, var_ready_t, 1
			dw kw_goto_iffalse_n, if19_1
			dw p_ready_r
if19_1:

			; Main.bas 216: If st(t) <> 2 Then Exit Function
			dw kw_aget, arr_st, var_ready_t, tmp0
			dw kw_cpnevl, tmp0, 2
			dw kw_goto_iffalse_n, if20_1
			dw p_ready_r
if20_1:

			; Main.bas 217: If wk(t) = Ticks And kq(t) = 0 Then Exit Function
			dw kw_aget, arr_wk, var_ready_t, tmp0
			dw kw_ticks, tmp1
			dw kw_cpeqvv, tmp0, tmp1
			dw kw_ftov, tmp0
			dw kw_aget, arr_kq, var_ready_t, tmp1
			dw kw_cpeqvl, tmp1, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if21_1
			dw p_ready_r
if21_1:

			; Main.bas 218: Ready = -1
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

			; Main.bas 223: Dim n As Integer, t As Integer, r As Integer, c As Integer, q As Integer

			; Main.bas 224: fr = Not fr
			dw kw_notv, var_fr, var_fr

			; Main.bas 225: If fr Then
			dw kw_goto_ifzero_n, var_fr, if22_1

			; Main.bas 226: If Ready(front) Then t = front
			dw p_ready_c, var_front
			dw kw_goto_ifzero_n, var_ready_ready, if23_1
			dw kw_vtov, var_front, var_runnext_t
if23_1:

			; Main.bas 227: End If
if22_1:

			; Main.bas 228: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if24_1

			; Main.bas 229: For n = 1 To ns
			dw kw_ltov, 1, var_runnext_n
			dw kw_vtov, var_ns, for25_l
			dw kw_forupv_n, var_runnext_n, for25_l, for25_e
for25_t:

			; Main.bas 230: cur = cur + 1
			dw kw_inc, var_cur

			; Main.bas 231: If cur > ns Then cur = 1
			dw kw_scpgtvv, var_cur, var_ns
			dw kw_goto_iffalse_n, if26_1
			dw kw_ltov, 1, var_cur
if26_1:

			; Main.bas 232: If cur <> front Then
			dw kw_cpnevv, var_cur, var_front
			dw kw_goto_iffalse_n, if27_1

			; Main.bas 233: If Ready(cur) Then t = cur : Exit For
			dw p_ready_c, var_cur
			dw kw_goto_ifzero_n, var_ready_ready, if28_1
			dw kw_vtov, var_cur, var_runnext_t
			dw for25_e_go
if28_1:

			; Main.bas 234: End If
if27_1:

			; Main.bas 235: Next
			dw kw_next1v_n, var_runnext_n, for25_l, for25_t
for25_e:

			; Main.bas 236: End If
if24_1:

			; Main.bas 237: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if29_1

			; Main.bas 238: If Ready(front) Then t = front
			dw p_ready_c, var_front
			dw kw_goto_ifzero_n, var_ready_ready, if30_1
			dw kw_vtov, var_front, var_runnext_t
if30_1:

			; Main.bas 239: End If
if29_1:

			; Main.bas 240: If t = 0 Then
			dw kw_cpeqvl, var_runnext_t, 0
			dw kw_goto_iffalse_n, if31_1

			; Main.bas 241: If Running() = 0 Then Frame     ' nothing to run: wait a frame (a program waiting for a
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if32_1
			dw kw_frame
if32_1:

			; Main.bas 242: Exit Sub                        ' key looks again when the clock moves on)
			dw p_runnext_r

			; Main.bas 243: End If
if31_1:

			; Main.bas 244: n = 0
			dw kw_ztov, var_runnext_n

			; Main.bas 245: Do
do33_t:

			; Main.bas 246: Hyp.Reply ra(t), ra(t)
			dw kw_aget, arr_ra, var_runnext_t, tmp0
			dw kw_aget, arr_ra, var_runnext_t, tmp1
			dw p_hyp_reply_c, tmp0, tmp1

			; Main.bas 247: r = Hyp.Run(sg(t))
			dw kw_aget, arr_sg, var_runnext_t, tmp0
			dw p_hyp_run_c, tmp0
			dw kw_vtov, var_hyp_run_run, var_runnext_r

			; Main.bas 248: tn(t) = tn(t) + 1
			dw kw_aget, arr_tn, var_runnext_t, tmp1
			dw kw_inc, tmp1
			dw kw_aset, arr_tn, var_runnext_t, tmp1

			; Main.bas 249: If kq(t) <> 0 Then
			dw kw_aget, arr_kq, var_runnext_t, tmp0
			dw kw_cpnevl, tmp0, 0
			dw kw_goto_iffalse_n, if34_1

			; Main.bas 250: If Memory.ReadByte(Far(t, Hyp.KEY)) = 0 Then kq(t) = 0     ' the program took its key
			dw p_far_c, var_runnext_t, lit_m2431
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_memory_readbyte_readbyte
			dw kw_vtov, var_memory_readbyte_readbyte, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if35_1
			dw kw_asetl, arr_kq, var_runnext_t, 0
if35_1:

			; Main.bas 251: End If
if34_1:

			; Main.bas 252: c = Hyp.Count()
			dw p_hyp_count_c
			dw kw_vtov, var_hyp_count_count, var_runnext_c

			; Main.bas 253: If c > 0 Then Collected t, c
			dw kw_scpgtvl, var_runnext_c, 0
			dw kw_goto_iffalse_n, if36_1
			dw p_collected_c, var_runnext_t, var_runnext_c
if36_1:

			; Main.bas 254: If r = 0 Then
			dw kw_cpeqvl, var_runnext_r, 0
			dw kw_goto_iffalse_n, if37_1

			; Main.bas 258: q = q + 1
			dw kw_inc, var_runnext_q

			; Main.bas 259: If q >= TURNS Then Exit Do
			dw kw_scpgevl, var_runnext_q, 3
			dw kw_goto_iffalse_n, do33_t
			dw do33_e_go
if38_1:

			; Main.bas 260: ElseIf r <> 1 Then
			dw do33_t_go
if37_1:
			dw kw_cpnevl, var_runnext_r, 1
			dw kw_goto_iffalse_n, if37_2

			; Main.bas 261: Exit Do
			dw do33_e_go

			; Main.bas 262: Else
if37_2:

			; Main.bas 263: c = Hyp.Fn()
			dw p_hyp_fn_c
			dw kw_vtov, var_hyp_fn_fn, var_runnext_c

			; Main.bas 264: Bdos t
			dw p_bdos_c, var_runnext_t

			; Main.bas 269: n = n + 1
			dw kw_inc, var_runnext_n

			; Main.bas 270: If c = 131 Or c = 128 Then c = 13
			dw kw_cpeqvl, var_runnext_c, 131
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_runnext_c, 128
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if39_1
			dw kw_ltov, 13, var_runnext_c
if39_1:

			; Main.bas 271: If c < 13 Or c > 36 Or n >= 32 Or st(t) <> 2 Or wk(t) <> -1 Then Exit Do   ' (asleep: a port's wait)
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
			dw kw_aget, arr_wk, var_runnext_t, tmp1
			dw kw_cpnevl, tmp1, -1
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, do33_t
			dw do33_e_go
if40_1:

			; Main.bas 272: End If
if37_e:

			; Main.bas 273: Loop
			dw do33_t_go
do33_e:
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

			; Main.bas 278: Dim f As Integer, e As Integer, a As Integer

			; Main.bas 279: f = Hyp.Fn() : e = Hyp.Arg() And 255 : a = 0
			dw p_hyp_fn_c
			dw kw_vtov, var_hyp_fn_fn, var_bdos_f
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp0
			dw kw_andvl, tmp0, 255, var_bdos_e
			dw kw_ztov, var_bdos_a

			; Main.bas 280: nb(t) = nb(t) + 1
			dw kw_aget, arr_nb, var_bdos_t, tmp1
			dw kw_inc, tmp1
			dw kw_aset, arr_nb, var_bdos_t, tmp1

			; Main.bas 281: wk(t) = -1
			dw kw_asetl, arr_wk, var_bdos_t, -1

			; Main.bas 282: If f = 40 Then f = 34           ' write random with zero fill: as 34
			dw kw_cpeqvl, var_bdos_f, 40
			dw kw_goto_iffalse_n, if41_1
			dw kw_ltov, 34, var_bdos_f
if41_1:

			; Main.bas 283: Select Case f
			dw kw_vtov, var_bdos_f, var_bdos___sel42

			; Main.bas 284: Case 0
			dw kw_cpeqvl, var_bdos___sel42, 0
			dw kw_goto_iffalse_n, sel42_1
sel42_b1:

			; Main.bas 285: EndTask t
			dw p_endtask_c, var_bdos_t

			; Main.bas 286: Exit Sub
			dw p_bdos_r

			; Main.bas 307: Case 12
sel42_1:
			dw kw_cpeqvl, var_bdos___sel42, 12
			dw kw_goto_iffalse_n, sel42_2
sel42_b2:

			; Main.bas 308: a = &H22                    ' CP/M 2.2
			dw kw_ltov, 34, var_bdos_a

			; Main.bas 309: Case 13, 32                   ' reset the discs; user number: nothing to do here
			dw sel42_e_go
sel42_2:
			dw kw_cpeqvl, var_bdos___sel42, 13
			dw kw_goto_iftrue_n, sel42_b3
			dw kw_cpeqvl, var_bdos___sel42, 32
			dw kw_goto_iffalse_n, sel42_3
sel42_b3:

			; Main.bas 310: a = 0
			dw kw_ztov, var_bdos_a

			; Main.bas 311: Case 14                       ' select a disc: the slot's drive (as CD)
			dw sel42_e_go
sel42_3:
			dw kw_cpeqvl, var_bdos___sel42, 14
			dw kw_goto_iffalse_n, sel42_4
sel42_b4:

			; Main.bas 316: Case 25
			dw sel42_e_go
sel42_4:
			dw kw_cpeqvl, var_bdos___sel42, 25
			dw kw_goto_iffalse_n, sel42_5
sel42_b5:

			; Main.bas 318: a = 0
			dw kw_ztov, var_bdos_a

			; Main.bas 322: Case 26                       ' the DMA address (CP/M's record buffer)
			dw sel42_e_go
sel42_5:
			dw kw_cpeqvl, var_bdos___sel42, 26
			dw kw_goto_iffalse_n, sel42_6
sel42_b6:

			; Main.bas 323: dm(t) = Hyp.Arg()
			dw p_hyp_arg_c
			dw kw_aset, arr_dm, var_bdos_t, var_hyp_arg_arg

			; Main.bas 324: Case 24                       ' the login vector: the slot's drive
			dw sel42_e_go
sel42_6:
			dw kw_cpeqvl, var_bdos___sel42, 24
			dw kw_goto_iffalse_n, sel42_7
sel42_b7:

			; Main.bas 326: a = 1
			dw kw_ltov, 1, var_bdos_a

			; Main.bas 335: Case 15 To 36                 ' files: Hyp.FileCall
			dw sel42_e_go
sel42_7:
			dw kw_scpltvl, var_bdos___sel42, 15
			dw kw_goto_iftrue_n, sel42_8
			dw kw_scplevl, var_bdos___sel42, 36
			dw kw_goto_iffalse_n, sel42_8
sel42_b8:

			; Main.bas 337: a = Hyp.FileCall(f, Hyp.Arg(), t, sg(t), dm(t), 0, VarPtr(rb))
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp1
			dw kw_aget, arr_sg, var_bdos_t, tmp3
			dw kw_aget, arr_dm, var_bdos_t, tmp4
			dw p_hyp_filecall_c, var_bdos_f, tmp1, var_bdos_t, tmp3, tmp4, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_bdos_a

			; Main.bas 346: Case 131                      ' CyborgOS's own commands (PS, KILL, MEM ...)
			dw sel42_e_go
sel42_8:
			dw kw_cpeqvl, var_bdos___sel42, 131
			dw kw_goto_iffalse_n, sel42_9
sel42_b9:

			; Main.bas 347: a = Sys(t, Hyp.Arg())
			dw p_hyp_arg_c
			dw kw_vtov, var_hyp_arg_arg, tmp1
			dw p_sys_c, var_bdos_t, tmp1
			dw kw_vtov, var_sys_sys, var_bdos_a

			; Main.bas 348: Case 128
			dw sel42_e_go
sel42_9:
			dw kw_cpeqvl, var_bdos___sel42, 128
			dw kw_goto_iffalse_n, sel42_10
sel42_b10:

			; Main.bas 350: Case 129                      ' the stub's key wait (BDOS 1, 10, BIOS CONIN): sleep till a key
			dw sel42_e_go
sel42_10:
			dw kw_cpeqvl, var_bdos___sel42, 129
			dw kw_goto_iffalse_n, sel42_11
sel42_b11:

			; Main.bas 351: If kq(t) = 0 Then wk(t) = Ticks
			dw kw_aget, arr_kq, var_bdos_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, sel42_e
			dw kw_ticks, tmp1
			dw kw_aset, arr_wk, var_bdos_t, tmp1
if43_1:

			; Main.bas 352: Case Else
			dw sel42_e_go
sel42_11:

			; Main.bas 353: a = 255
			dw kw_ltov, 255, var_bdos_a

			; Main.bas 354: End Select
sel42_e:

			; Main.bas 355: ra(t) = a
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

			; Main.bas 467: Dim o As Integer, s As Integer, d As Integer

			; Main.bas 468: o = Memory.ReadByte(Far(t, p)) : s = Memory.ReadByte(Far(t, p + 1))
			dw p_far_c, var_sys_t, var_sys_p
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_o
			dw kw_addl, var_sys_p, 1, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_s

			; Main.bas 469: If o = 4 Then
			dw kw_cpeqvl, var_sys_o, 4
			dw kw_goto_iffalse_n, if44_1

			; Main.bas 470: If Running() > 1 Then wt = t
			dw p_running_c
			dw kw_vtov, var_running_running, tmp0
			dw kw_scpgtvl, tmp0, 1
			dw kw_goto_iffalse_n, if45_1
			dw kw_vtov, var_sys_t, var_wt
if45_1:

			; Main.bas 471: Exit Function
			dw p_sys_r

			; Main.bas 472: ElseIf o = 6 Then
if44_1:
			dw kw_cpeqvl, var_sys_o, 6
			dw kw_goto_iffalse_n, if44_2

			; Main.bas 473: txs = t
			dw kw_vtov, var_sys_t, var_txs

			; Main.bas 474: TopLines front, 0
			dw p_toplines_c, var_front, lit_0

			; Main.bas 475: Exit Function
			dw p_sys_r

			; Main.bas 476: ElseIf o = 9 Then                               ' MODE: s 0-4 this slot's mode (its console
if44_2:
			dw kw_cpeqvl, var_sys_o, 9
			dw kw_goto_iffalse_n, if44_3

			; Main.bas 477: If s = 255 Then Sys = Memory.ReadByte(Far(t, Hyp.CMODE)) : Exit Function   ' cleared), 255: which
			dw kw_cpeqvl, var_sys_s, 255
			dw kw_goto_iffalse_n, if46_1
			dw p_far_c, var_sys_t, lit_m2423
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_sys_sys
			dw p_sys_r
if46_1:

			; Main.bas 478: If s > 5 Then Sys = 255 : Exit Function                                     ' it is
			dw kw_scpgtvl, var_sys_s, 5
			dw kw_goto_iffalse_n, if47_1
			dw kw_ltov, 255, var_sys_sys
			dw p_sys_r
if47_1:

			; Main.bas 479: SetMode t, s
			dw p_setmode_c, var_sys_t, var_sys_s

			; Main.bas 480: Exit Function
			dw p_sys_r

			; Main.bas 505: End If
if44_3:
if44_e:

			; Main.bas 506: If o = 2 And s = 0 Then s = t
			dw kw_cpeqvl, var_sys_o, 2
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_sys_s, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if48_1
			dw kw_vtov, var_sys_t, var_sys_s
if48_1:

			; Main.bas 507: Sys = 255
			dw kw_ltov, 255, var_sys_sys

			; Main.bas 508: If s < 1 Or s > ns Then Exit Function
			dw kw_scpltvl, var_sys_s, 1
			dw kw_ftov, tmp0
			dw kw_scpgtvv, var_sys_s, var_ns
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if49_1
			dw p_sys_r
if49_1:

			; Main.bas 509: Sys = 0
			dw kw_ztov, var_sys_sys

			; Main.bas 510: If o = 0 Then
			dw kw_cpeqvl, var_sys_o, 0
			dw kw_goto_iffalse_n, if50_1

			; Main.bas 511: Memory.WriteByte Far(t, p + 2), st(s)
			dw kw_addl, var_sys_p, 2, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw kw_aget, arr_st, var_sys_s, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 512: Memory.WriteByte Far(t, p + 3), IIf(s = front, 1, 0)
			dw kw_addl, var_sys_p, 3, tmp1
			dw p_far_c, var_sys_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw kw_cpeqvv, var_sys_s, var_front
			dw kw_ftov, tmp1
			dw kw_goto_ifzero_n, tmp1, ch51_0
			dw kw_ltov, 1, tmp1
			dw ch51_e_go
ch51_0:
			dw kw_ztov, tmp1
			dw ch51_e_go
ch51_1:
			dw kw_ztov, tmp1
ch51_e:
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 513: en = ""
			dw kw_strcpy, var_en, str2

			; Main.bas 514: If st(s) = 2 Then GetNm s
			dw kw_aget, arr_st, var_sys_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if52_1
			dw p_getnm_c, var_sys_s
if52_1:

			; Main.bas 515: PutEn t, p + 4
			dw kw_addl, var_sys_p, 4, tmp1
			dw p_puten_c, var_sys_t, tmp1

			; Main.bas 516: ElseIf o = 1 Then
			dw if50_e_go
if50_1:
			dw kw_cpeqvl, var_sys_o, 1
			dw kw_goto_iffalse_n, if50_2

			; Main.bas 517: If st(s) = 2 Then EndTask s Else Sys = 1
			dw kw_aget, arr_st, var_sys_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if53_1
			dw p_endtask_c, var_sys_s
			dw if50_e_go
if53_1:
			dw kw_ltov, 1, var_sys_sys
if53_e:

			; Main.bas 518: ElseIf o = 2 Then
			dw if50_e_go
if50_2:
			dw kw_cpeqvl, var_sys_o, 2
			dw kw_goto_iffalse_n, if50_3

			; Main.bas 519: ResetSlot s
			dw p_resetslot_c, var_sys_s

			; Main.bas 520: If s = t Then Prompt t                       ' (RESET of its own slot: the program gone)
			dw kw_cpeqvv, var_sys_s, var_sys_t
			dw kw_goto_iffalse_n, if50_e
			dw p_prompt_c, var_sys_t
if54_1:

			; Main.bas 521: ElseIf o = 3 Then
			dw if50_e_go
if50_3:
			dw kw_cpeqvl, var_sys_o, 3
			dw kw_goto_iffalse_n, if50_4

			; Main.bas 522: ToFront s
			dw p_tofront_c, var_sys_s

			; Main.bas 523: End If
if50_4:
if50_e:
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

			; Main.bas 528: Memory.WriteByte Far(t, a), Len(en)
			dw p_far_c, var_puten_t, var_puten_a
			dw kw_l_mov, var_far_far, ltmp0
			dw kw_strlen, var_en, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 529: Memory.Copy NearP(VarPtr(en)), Far(t, a + 1), Len(en)
			dw p_nearp_c, vp_var_en
			dw kw_l_mov, var_nearp_nearp, ltmp0
			dw kw_addl, var_puten_a, 1, tmp2
			dw p_far_c, var_puten_t, tmp2
			dw kw_l_mov, var_far_far, ltmp1
			dw kw_strlen, var_en, tmp2
			dw fn_memory_copy, ltmp0, ltmp1, tmp2, var_memory_copy_copy
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

			; Main.bas 535: HOpen = (Hyp.FileCall(100, VarPtr(dn), 0, 0, Len(dn), 0, 0) = 0)
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
; sub hclose (normal mode)
; ============================================================

p_hclose:

			; Main.bas 541: Dim r As Integer

			; Main.bas 542: r = Hyp.FileCall(102, 0, 0, 0, 0, 0, 0)
			dw p_hyp_filecall_c, lit_102, lit_0, lit_0, lit_0, lit_0, lit_0, lit_0
			dw kw_vtov, var_hyp_filecall_filecall, var_hclose_r
			dw p_hclose_r

ntc_rg9_e:
			IF ($ < 32768) && (ntc_rg10_e - ntc_rg10 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg10:
; ============================================================
; sub filesshut (normal mode)
; ============================================================

p_filesshut:

			; Main.bas 547: Dim r As Integer

			; Main.bas 548: Hyp.FileShut t
			dw p_hyp_fileshut_c, var_filesshut_t
			dw p_filesshut_r

ntc_rg10_e:
			IF ($ < 32768) && (ntc_rg11_e - ntc_rg11 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg11:
; ============================================================
; sub collected (normal mode)
; ============================================================

p_collected:

			; Main.bas 561: nc(t) = nc(t) + n
			dw kw_aget, arr_nc, var_collected_t, tmp1
			dw kw_add, tmp1, var_collected_n, tmp1
			dw kw_aset, arr_nc, var_collected_t, tmp1

			; Main.bas 562: Hyp.Con wp(t), 0, n, IIf(t = front, 1, 0)       ' straight from the bank: no copy to main RAM
			dw kw_aget, arr_wp, var_collected_t, tmp0
			dw kw_cpeqvv, var_collected_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch55_0
			dw kw_ltov, 1, tmp3
			dw ch55_e_go
ch55_0:
			dw kw_ztov, tmp3
			dw ch55_e_go
ch55_1:
			dw kw_ztov, tmp3
ch55_e:
			dw p_hyp_con_c, tmp0, lit_0, var_collected_n, tmp3
			dw p_collected_r

ntc_rg11_e:
			IF ($ < 32768) && (ntc_rg12_e - ntc_rg12 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg12:
; ============================================================
; sub puts (normal mode)
; ============================================================

p_puts:

			; Main.bas 567: Hyp.Con wp(t), VarPtr(s), Len(s), IIf(t = front, 1, 0)
			dw kw_aget, arr_wp, var_puts_t, tmp0
			dw kw_strlen, var_puts_s, tmp2
			dw kw_cpeqvv, var_puts_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch56_0
			dw kw_ltov, 1, tmp3
			dw ch56_e_go
ch56_0:
			dw kw_ztov, tmp3
			dw ch56_e_go
ch56_1:
			dw kw_ztov, tmp3
ch56_e:
			dw p_hyp_con_c, tmp0, vp_var_puts_s, tmp2, tmp3
			dw p_puts_r

ntc_rg12_e:
			IF ($ < 32768) && (ntc_rg13_e - ntc_rg13 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg13:
; ============================================================
; sub putln (normal mode)
; ============================================================

p_putln:

			; Main.bas 571: PutS t, s + Chr$(13) + Chr$(10)
			dw kw_strcpy, stmp1, var_putln_s
			dw kw_strcat, stmp1, str6
			dw kw_strcat, stmp1, str7
			dw p_puts_c, var_putln_t, stmp1
			dw p_putln_r

ntc_rg13_e:
			IF ($ < 32768) && (ntc_rg14_e - ntc_rg14 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg14:
; ============================================================
; sub putc (normal mode)
; ============================================================

p_putc:

			; Main.bas 576: Hyp.Con wp(t), VarPtr(c), 1, IIf(t = front, 1, 0)   ' (the Integer's low byte is the character)
			dw kw_aget, arr_wp, var_putc_t, tmp0
			dw kw_cpeqvv, var_putc_t, var_front
			dw kw_ftov, tmp3
			dw kw_goto_ifzero_n, tmp3, ch57_0
			dw kw_ltov, 1, tmp3
			dw ch57_e_go
ch57_0:
			dw kw_ztov, tmp3
			dw ch57_e_go
ch57_1:
			dw kw_ztov, tmp3
ch57_e:
			dw p_hyp_con_c, tmp0, vp_var_putc_c, lit_1, tmp3
			dw p_putc_r

ntc_rg14_e:
			IF ($ < 32768) && (ntc_rg15_e - ntc_rg15 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg15:
; ============================================================
; function nearp (normal mode)
; ============================================================

p_nearp:

			; Main.bas 599: NearP = CLng(p)
			dw kw_l_itol, var_nearp_p, var_nearp_nearp

			; Main.bas 600: If p < 0 Then NearP = NearP + 65536
			dw kw_scpltvl, var_nearp_p, 0
			dw kw_goto_iffalse_n, if58_1
			dw kw_l_add, var_nearp_nearp, llit_65536, var_nearp_nearp
if58_1:
			dw p_nearp_r

ntc_rg15_e:
			IF ($ < 32768) && (ntc_rg16_e - ntc_rg16 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg16:
; ============================================================
; function far (normal mode)
; ============================================================

p_far:

			; Main.bas 605: Far = Hyp.FarPtr(Memory.BankPage(bk(t), ((a And &HC000) \ 16384) And 3), a)
			dw kw_aget, arr_bk, var_far_t, tmp1
			dw kw_andvl, var_far_a, -16384, tmp2
			dw kw_divvl, tmp2, 16384, tmp2
			dw kw_andvl, tmp2, 3, tmp2
			dw p_memory_bankpage_c, tmp1, tmp2
			dw kw_vtov, var_memory_bankpage_bankpage, tmp1
			dw fn_hyp_farptr, tmp1, var_far_a, var_far_far
			dw p_far_r

ntc_rg16_e:
			IF ($ < 32768) && (ntc_rg17_e - ntc_rg17 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg17:
; ============================================================
; sub clst (normal mode)
; ============================================================

p_clst:

			; Main.bas 610: PutS t, Chr$(27) + "E"
			dw kw_strcpy, stmp1, str8
			dw kw_strcat, stmp1, str9
			dw p_puts_c, var_clst_t, stmp1
			dw p_clst_r

ntc_rg17_e:
			IF ($ < 32768) && (ntc_rg18_e - ntc_rg18 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg18:
; ============================================================
; sub tofront (normal mode)
; ============================================================

p_tofront:

			; Main.bas 615: Dim r As Integer

			; Main.bas 616: front = t
			dw kw_vtov, var_tofront_t, var_front

			; Main.bas 617: If st(t) = 0 Then OpenSlot t : Exit Sub
			dw kw_aget, arr_st, var_tofront_t, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if59_1
			dw p_openslot_c, var_tofront_t
			dw p_tofront_r
if59_1:

			; Main.bas 618: r = Hyp.Scr(Memory.ReadByte(Far(t, Hyp.CMODE)), 2)   ' the screen in its mode (cleared)
			dw p_far_c, var_tofront_t, lit_m2423
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_memory_readbyte_readbyte
			dw kw_vtov, var_memory_readbyte_readbyte, tmp0
			dw p_hyp_scr_c, tmp0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_tofront_r

			; Main.bas 619: Hyp.Show wp(t)
			dw kw_aget, arr_wp, var_tofront_t, tmp0
			dw p_hyp_show_c, tmp0
			dw p_tofront_r

ntc_rg18_e:
			IF ($ < 32768) && (ntc_rg19_e - ntc_rg19 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg19:
; ============================================================
; sub setmode (normal mode)
; ============================================================

p_setmode:

			; Main.bas 626: Dim r As Integer

			; Main.bas 627: Memory.WriteByte Far(t, Hyp.CCOLS), Hyp.Scr(m, 0)
			dw p_far_c, var_setmode_t, lit_m2425
			dw kw_l_mov, var_far_far, ltmp0
			dw p_hyp_scr_c, var_setmode_m, lit_0
			dw kw_vtov, var_hyp_scr_scr, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 628: Memory.WriteByte Far(t, Hyp.CROWS), Hyp.Scr(m, 1)
			dw p_far_c, var_setmode_t, lit_m2424
			dw kw_l_mov, var_far_far, ltmp0
			dw p_hyp_scr_c, var_setmode_m, lit_1
			dw kw_vtov, var_hyp_scr_scr, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 629: Memory.WriteByte Far(t, Hyp.CMODE), m
			dw p_far_c, var_setmode_t, lit_m2423
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, var_setmode_m

			; Main.bas 630: en = Left$("[" + N(t) + "]   ", 4)
			dw p_n_c, var_setmode_t
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcpy, stmp0, str10
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str11
			dw kw_strleft, stmp0, stmp0, lit_4
			dw kw_strcpy, var_en, stmp0

			; Main.bas 631: Memory.Copy NearP(VarPtr(en)), Far(t, Hyp.CSTRIP), 4
			dw p_nearp_c, vp_var_en
			dw kw_l_mov, var_nearp_nearp, ltmp0
			dw p_far_c, var_setmode_t, lit_m2422
			dw kw_l_mov, var_far_far, ltmp1
			dw fn_memory_copy, ltmp0, ltmp1, lit_4, var_memory_copy_copy

			; Main.bas 632: If t = front Then r = Hyp.Scr(m, 2)
			dw kw_cpeqvv, var_setmode_t, var_front
			dw kw_goto_iffalse_n, if60_1
			dw p_hyp_scr_c, var_setmode_m, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_setmode_r
if60_1:

			; Main.bas 633: ClsT t
			dw p_clst_c, var_setmode_t
			dw p_setmode_r

ntc_rg19_e:
			IF ($ < 32768) && (ntc_rg20_e - ntc_rg20 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg20:
; ============================================================
; sub showtop (normal mode)
; ============================================================

p_showtop:

			; Main.bas 796: Dim j As Integer

			; Main.bas 797: If front <> 0 Then back = front
			dw kw_cpnevl, var_front, 0
			dw kw_goto_iffalse_n, if61_1
			dw kw_vtov, var_front, var_back
if61_1:

			; Main.bas 798: front = 0
			dw kw_ztov, var_front

			; Main.bas 799: j = Hyp.Scr(0, 2)               ' TOP in MODE 2 (80 x 25), the screen cleared
			dw p_hyp_scr_c, lit_0, lit_2
			dw kw_vtov, var_hyp_scr_scr, var_showtop_j

			; Main.bas 800: txs = 0
			dw kw_ztov, var_txs

			; Main.bas 801: TopLines back, 1
			dw p_toplines_c, var_back, lit_1
			dw p_showtop_r

ntc_rg20_e:
			IF ($ < 32768) && (ntc_rg21_e - ntc_rg21 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg21:
; ============================================================
; sub toplines (normal mode)
; ============================================================

p_toplines:

			; Main.bas 807: Dim j As Integer, s As String Max 14

			; Main.bas 808: txn = 0
			dw kw_ztov, var_txn

			; Main.bas 809: TopAdd "CyborgOS TOP"
			dw p_topadd_c, str12

			; Main.bas 810: If keys Then TopAdd "Control + ESC: back, " + SK() + ": that slot" Else TopAdd ""   ' (25 rows: 20 slots)
			dw kw_goto_ifzero_n, var_toplines_keys, if62_1
			dw p_sk_c
			dw kw_strcpy, stmp1, var_sk_sk
			dw kw_strcpy, stmp0, str13
			dw kw_strcat, stmp0, stmp1
			dw kw_strcat, stmp0, str14
			dw p_topadd_c, stmp0
			dw if62_e_go
if62_1:
			dw p_topadd_c, str2
if62_e:

			; Main.bas 811: TopAdd "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (last second)"
			dw p_topadd_c, str15

			; Main.bas 812: For j = 1 To ns
			dw kw_ltov, 1, var_toplines_j
			dw kw_vtov, var_ns, for63_l
			dw kw_forupv_n, var_toplines_j, for63_l, for63_e
for63_t:

			; Main.bas 813: If st(j) = 0 Then
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if64_1

			; Main.bas 814: s = "-"
			dw kw_strcpy, var_toplines_s, str16

			; Main.bas 815: ElseIf st(j) = 1 Then
			dw if64_e_go
if64_1:
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 1
			dw kw_goto_iffalse_n, if64_2

			; Main.bas 816: s = "command line"
			dw kw_strcpy, var_toplines_s, str17

			; Main.bas 817: ElseIf wk(j) >= 0 Then
			dw if64_e_go
if64_2:
			dw kw_aget, arr_wk, var_toplines_j, tmp0
			dw kw_scpgevl, tmp0, 0
			dw kw_goto_iffalse_n, if64_3

			; Main.bas 818: s = "waiting (key)"
			dw kw_strcpy, var_toplines_s, str18

			; Main.bas 819: Else
			dw if64_e_go
if64_3:

			; Main.bas 820: s = "running"
			dw kw_strcpy, var_toplines_s, str19

			; Main.bas 821: End If
if64_e:

			; Main.bas 822: en = ""
			dw kw_strcpy, var_en, str2

			; Main.bas 823: If st(j) = 2 Then GetNm j
			dw kw_aget, arr_st, var_toplines_j, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if65_1
			dw p_getnm_c, var_toplines_j
if65_1:

			; Main.bas 824: TopAdd " " + Right$(" " + N(j), 2) + IIf(j = mark, "*", " ") + "  " + Left$(s + Space$(15), 15) + Left$(en + Space$(13), 13) + Pad(Rate(lt(j), ld)) + Pad(Rate(lb(j), ld)) + Pad(Rate(lc(j), ld))
			dw p_n_c, var_toplines_j
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcpy, stmp1, str20
			dw kw_strcat, stmp1, stmp2
			dw kw_strright, stmp1, stmp1, lit_2
			dw kw_strcpy, stmp0, str20
			dw kw_strcat, stmp0, stmp1
			dw kw_cpeqvv, var_toplines_j, var_toplines_mark
			dw kw_ftov, tmp1
			dw kw_goto_ifzero_n, tmp1, ch66_0
			dw kw_strcpy, stmp1, str21
			dw ch66_e_go
ch66_0:
			dw kw_strcpy, stmp1, str20
			dw ch66_e_go
ch66_1:
			dw kw_strcpy, stmp1, str2
ch66_e:
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

			; Main.bas 825: Next
			dw kw_next1v_n, var_toplines_j, for63_l, for63_t
for63_e:

			; Main.bas 826: TopAdd ""
			dw p_topadd_c, str2

			; Main.bas 827: Totals
			dw p_totals_c

			; Main.bas 828: TopAdd en
			dw p_topadd_c, var_en
			dw p_toplines_r

ntc_rg21_e:
			IF ($ < 32768) && (ntc_rg22_e - ntc_rg22 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg22:
; ============================================================
; sub totals (normal mode)
; ============================================================

p_totals:

			; Main.bas 833: en = "Total memory: " + N(Memory.RamSize()) + " KB   Free memory: " + N(Memory.FreePages() * 16) + " KB"
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

ntc_rg22_e:
			IF ($ < 32768) && (ntc_rg23_e - ntc_rg23 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg23:
; ============================================================
; sub topadd (normal mode)
; ============================================================

p_topadd:

			; Main.bas 841: If txs = 0 Then
			dw kw_cpeqvl, var_txs, 0
			dw kw_goto_iffalse_n, if67_1

			; Main.bas 842: Hyp.Say VarPtr(s), Len(s), 0, txn          ' straight into screen memory (Print took ~0.7 s)
			dw kw_strlen, var_topadd_s, tmp1
			dw p_hyp_say_c, vp_var_topadd_s, tmp1, lit_0, var_txn

			; Main.bas 843: Else
			dw if67_e_go
if67_1:

			; Main.bas 844: PutLn txs, s
			dw p_putln_c, var_txs, var_topadd_s

			; Main.bas 845: End If
if67_e:

			; Main.bas 846: txn = txn + 1
			dw kw_inc, var_txn
			dw p_topadd_r

ntc_rg23_e:
			IF ($ < 32768) && (ntc_rg24_e - ntc_rg24 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg24:
; ============================================================
; sub roll (normal mode)
; ============================================================

p_roll:

			; Main.bas 851: Dim j As Integer

			; Main.bas 852: ld = Ticks - td
			dw kw_ticks, tmp0
			dw kw_subvv, tmp0, var_td, var_ld

			; Main.bas 853: td = Ticks
			dw kw_ticks, tmp0
			dw kw_vtov, tmp0, var_td

			; Main.bas 854: For j = 1 To ns
			dw kw_ltov, 1, var_roll_j
			dw kw_vtov, var_ns, for68_l
			dw kw_forupv_n, var_roll_j, for68_l, for68_e
for68_t:

			; Main.bas 855: lt(j) = tn(j) : lb(j) = nb(j) : lc(j) = nc(j)
			dw kw_aget, arr_tn, var_roll_j, tmp1
			dw kw_aset, arr_lt, var_roll_j, tmp1
			dw kw_aget, arr_nb, var_roll_j, tmp1
			dw kw_aset, arr_lb, var_roll_j, tmp1
			dw kw_aget, arr_nc, var_roll_j, tmp1
			dw kw_aset, arr_lc, var_roll_j, tmp1

			; Main.bas 856: tn(j) = 0 : nb(j) = 0 : nc(j) = 0
			dw kw_asetl, arr_tn, var_roll_j, 0
			dw kw_asetl, arr_nb, var_roll_j, 0
			dw kw_asetl, arr_nc, var_roll_j, 0

			; Main.bas 857: Next
			dw kw_next1v_n, var_roll_j, for68_l, for68_t
for68_e:
			dw p_roll_r

ntc_rg24_e:
			IF ($ < 32768) && (ntc_rg25_e - ntc_rg25 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg25:
; ============================================================
; function pad (normal mode)
; ============================================================

p_pad:

			; Main.bas 862: Pad = Right$(Space$(9) + N(v), 9)
			dw kw_strspace, stmp1, lit_9
			dw p_n_c, var_pad_v
			dw kw_strcpy, stmp2, var_n_n
			dw kw_strcat, stmp1, stmp2
			dw kw_strright, var_pad_pad, stmp1, lit_9
			dw p_pad_r

ntc_rg25_e:
			IF ($ < 32768) && (ntc_rg26_e - ntc_rg26 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg26:
; ============================================================
; function rate (normal mode)
; ============================================================

p_rate:

			; Main.bas 867: If n > 1000 Then Rate = n \ (d \ 300 + 1) Else Rate = n * 30 \ (d \ 10 + 1)
			dw kw_scpgtvl, var_rate_n, 1000
			dw kw_goto_iffalse_n, if69_1
			dw kw_divvl, var_rate_d, 300, tmp2
			dw kw_inc, tmp2
			dw kw_divvv, var_rate_n, tmp2, var_rate_rate
			dw if69_e_go
if69_1:
			dw kw_mulvl, var_rate_n, 30, tmp1
			dw kw_divvl, var_rate_d, 10, tmp2
			dw kw_inc, tmp2
			dw kw_divvv, tmp1, tmp2, var_rate_rate
if69_e:
			dw p_rate_r

ntc_rg26_e:
			IF ($ < 32768) && (ntc_rg27_e - ntc_rg27 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg27:
; ============================================================
; sub install (normal mode)
; ============================================================

p_install:

			; Main.bas 874: Dim p As Integer, n As Integer

			; Main.bas 875: p = Hyp.Info(0) : n = Hyp.Info(1)             ' (one Info result each: it is one variable)
			dw fn_hyp_info, lit_0, var_install_p
			dw fn_hyp_info, lit_1, var_install_n

			; Main.bas 876: Memory.Copy Hyp.FarPtr(hp, p), Far(t, 0), n   ' (from the hypervisor's page)
			dw fn_hyp_farptr, var_hp, var_install_p, var_hyp_farptr_farptr
			dw kw_l_mov, var_hyp_farptr_farptr, ltmp0
			dw p_far_c, var_install_t, lit_0
			dw kw_l_mov, var_far_far, ltmp1
			dw fn_memory_copy, ltmp0, ltmp1, var_install_n, var_memory_copy_copy

			; Main.bas 877: p = Hyp.Info(2) : n = Hyp.Info(3)
			dw fn_hyp_info, lit_2, var_install_p
			dw fn_hyp_info, lit_3, var_install_n

			; Main.bas 878: Memory.Copy Hyp.FarPtr(hp, p), Far(t, Hyp.STUB), n
			dw fn_hyp_farptr, var_hp, var_install_p, var_hyp_farptr_farptr
			dw kw_l_mov, var_hyp_farptr_farptr, ltmp0
			dw p_far_c, var_install_t, lit_m4352
			dw kw_l_mov, var_far_far, ltmp1
			dw fn_memory_copy, ltmp0, ltmp1, var_install_n, var_memory_copy_copy

			; Main.bas 879: Memory.Copy Hyp.FarPtr(hp, Hyp.HFONT), Far(t, Hyp.FONT), 768   ' the font (Con draws from it)
			dw fn_hyp_farptr, var_hp, lit_4096, var_hyp_farptr_farptr
			dw kw_l_mov, var_hyp_farptr_farptr, ltmp0
			dw p_far_c, var_install_t, lit_m3328
			dw kw_l_mov, var_far_far, ltmp1
			dw fn_memory_copy, ltmp0, ltmp1, lit_768, var_memory_copy_copy

			; Main.bas 880: Memory.WriteByte Far(t, Hyp.OBUF + 128), 0      ' no characters collected
			dw p_far_c, var_install_t, lit_m2432
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, lit_0

			; Main.bas 881: Memory.WriteByte Far(t, Hyp.KEY), 0             ' no key waiting
			dw p_far_c, var_install_t, lit_m2431
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, lit_0

			; Main.bas 882: kq(t) = 0
			dw kw_asetl, arr_kq, var_install_t, 0
			dw p_install_r

ntc_rg27_e:
			IF ($ < 32768) && (ntc_rg28_e - ntc_rg28 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg28:
; ============================================================
; sub resetslot (normal mode)
; ============================================================

p_resetslot:

			; Main.bas 894: FilesShut s
			dw p_filesshut_c, var_resetslot_s

			; Main.bas 899: st(s) = 0
			dw kw_asetl, arr_st, var_resetslot_s, 0

			; Main.bas 904: kq(s) = 0
			dw kw_asetl, arr_kq, var_resetslot_s, 0

			; Main.bas 905: wk(s) = -1
			dw kw_asetl, arr_wk, var_resetslot_s, -1

			; Main.bas 906: tn(s) = 0 : nb(s) = 0 : nc(s) = 0
			dw kw_asetl, arr_tn, var_resetslot_s, 0
			dw kw_asetl, arr_nb, var_resetslot_s, 0
			dw kw_asetl, arr_nc, var_resetslot_s, 0

			; Main.bas 907: lt(s) = 0 : lb(s) = 0 : lc(s) = 0
			dw kw_asetl, arr_lt, var_resetslot_s, 0
			dw kw_asetl, arr_lb, var_resetslot_s, 0
			dw kw_asetl, arr_lc, var_resetslot_s, 0

			; Main.bas 908: If s = front Then
			dw kw_cpeqvv, var_resetslot_s, var_front
			dw kw_goto_iffalse_n, if70_1

			; Main.bas 909: Install s
			dw p_install_c, var_resetslot_s

			; Main.bas 910: st(s) = 1
			dw kw_asetl, arr_st, var_resetslot_s, 1

			; Main.bas 911: SetMode s, 1
			dw p_setmode_c, var_resetslot_s, lit_1

			; Main.bas 912: PutLn s, "CyborgOS slot " + N(s) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
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

			; Main.bas 913: PutLn s, ""                   ' a blank line under the title
			dw p_putln_c, var_resetslot_s, str2

			; Main.bas 914: End If                          ' (the prompt: the command line puts it after the command)
if70_1:
			dw p_resetslot_r

ntc_rg28_e:
			IF ($ < 32768) && (ntc_rg29_e - ntc_rg29 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg29:
; ============================================================
; sub openslot (normal mode)
; ============================================================

p_openslot:

			; Main.bas 918: Install t
			dw p_install_c, var_openslot_t

			; Main.bas 919: st(t) = 1
			dw kw_asetl, arr_st, var_openslot_t, 1

			; Main.bas 920: SetMode t, 1                    ' MODE S: 80 x 24 and the status strip
			dw p_setmode_c, var_openslot_t, lit_1

			; Main.bas 921: PutLn t, "CyborgOS slot " + N(t) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
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

			; Main.bas 922: PutLn t, ""                     ' a blank line under the title
			dw p_putln_c, var_openslot_t, str2

			; Main.bas 923: Prompt t
			dw p_prompt_c, var_openslot_t
			dw p_openslot_r

ntc_rg29_e:
			IF ($ < 32768) && (ntc_rg30_e - ntc_rg30 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg30:
; ============================================================
; function sk (normal mode)
; ============================================================

p_sk:

			; Main.bas 928: If ns <= 9 Then
			dw kw_scplevl, var_ns, 9
			dw kw_goto_iffalse_n, if71_1

			; Main.bas 929: SK = "Control + 1-" + N(ns)
			dw p_n_c, var_ns
			dw kw_strcpy, stmp3, var_n_n
			dw kw_strcpy, var_sk_sk, str30
			dw kw_strcat, var_sk_sk, stmp3

			; Main.bas 930: ElseIf ns = 10 Then
			dw if71_e_go
if71_1:
			dw kw_cpeqvl, var_ns, 10
			dw kw_goto_iffalse_n, if71_2

			; Main.bas 931: SK = "Control + 1-9, 0"
			dw kw_strcpy, var_sk_sk, str31

			; Main.bas 932: Else
			dw if71_e_go
if71_2:

			; Main.bas 933: SK = "Control + 1-9, 0 (twice 11-" + N(ns) + ")"
			dw p_n_c, var_ns
			dw kw_strcpy, stmp3, var_n_n
			dw kw_strcpy, stmp2, str32
			dw kw_strcat, stmp2, stmp3
			dw kw_strcpy, var_sk_sk, stmp2
			dw kw_strcat, var_sk_sk, str33

			; Main.bas 934: End If
if71_e:
			dw p_sk_r

ntc_rg30_e:
			IF ($ < 32768) && (ntc_rg31_e - ntc_rg31 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg31:
; ============================================================
; sub getnm (normal mode)
; ============================================================

p_getnm:

			; Main.bas 941: Dim n As Integer

			; Main.bas 942: n = Memory.ReadByte(Far(t, NMLEN))
			dw p_far_c, var_getnm_t, lit_m2344
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_getnm_n

			; Main.bas 943: en = Space$(12)
			dw kw_strspace, stmp0, lit_12
			dw kw_strcpy, var_en, stmp0

			; Main.bas 944: Memory.Copy Far(t, NMBUF), NearP(VarPtr(en)), n
			dw p_far_c, var_getnm_t, lit_m2343
			dw kw_l_mov, var_far_far, ltmp0
			dw p_nearp_c, vp_var_en
			dw kw_l_mov, var_nearp_nearp, ltmp1
			dw fn_memory_copy, ltmp0, ltmp1, var_getnm_n, var_memory_copy_copy

			; Main.bas 945: en = Left$(en, n)
			dw kw_strleft, stmp0, var_en, var_getnm_n
			dw kw_strcpy, var_en, stmp0
			dw p_getnm_r

ntc_rg31_e:
			IF ($ < 32768) && (ntc_rg32_e - ntc_rg32 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg32:
; ============================================================
; function n (normal mode)
; ============================================================

p_n:

			; Main.bas 949: N = Trim$(Str$(v))
			dw kw_strstr, stmp3, var_n_v
			dw kw_strtrim, var_n_n, stmp3
			dw p_n_r

ntc_rg32_e:
			IF ($ < 32768) && (ntc_rg33_e - ntc_rg33 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg33:
; ============================================================
; sub prompt (normal mode)
; ============================================================

p_prompt:

			; Main.bas 953: Memory.WriteByte Far(t, LNLEN), 0                ' an empty command line
			dw p_far_c, var_prompt_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, lit_0

			; Main.bas 954: PutS t, N(t) + "> "
			dw p_n_c, var_prompt_t
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcat, stmp1, str34
			dw p_puts_c, var_prompt_t, stmp1
			dw p_prompt_r

ntc_rg33_e:
			IF ($ < 32768) && (ntc_rg34_e - ntc_rg34 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg34:
; ============================================================
; sub keyin (normal mode)
; ============================================================

p_keyin:

			; Main.bas 959: Dim t As Integer, n As Integer

			; Main.bas 960: If front = 0 Then
			dw kw_cpeqvl, var_front, 0
			dw kw_goto_iffalse_n, if72_1

			; Main.bas 961: Exit Sub                      ' TOP stays until Control + ESC or Control + a slot
			dw p_keyin_r

			; Main.bas 962: End If
if72_1:

			; Main.bas 963: t = front
			dw kw_vtov, var_front, var_keyin_t

			; Main.bas 967: If st(t) = 2 Then
			dw kw_aget, arr_st, var_keyin_t, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if73_1

			; Main.bas 968: If k = &HFC Then k = 27                       ' (ESC: the firmware's #FC - CP/M's #1B, as Amstrad's CP/M)
			dw kw_cpeqvl, var_keyin_k, 252
			dw kw_goto_iffalse_n, if74_1
			dw kw_ltov, 27, var_keyin_k
if74_1:

			; Main.bas 969: kq(t) = k                                     ' the key into its bank: its BDOS answers from it
			dw kw_aset, arr_kq, var_keyin_t, var_keyin_k

			; Main.bas 970: Memory.WriteByte Far(t, Hyp.KEY), k
			dw p_far_c, var_keyin_t, lit_m2431
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, var_keyin_k

			; Main.bas 971: Exit Sub
			dw p_keyin_r

			; Main.bas 972: End If
if73_1:

			; Main.bas 973: n = Memory.ReadByte(Far(t, LNLEN))             ' the command line so far (in the slot's bank)
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_keyin_n

			; Main.bas 974: If k = 13 Then
			dw kw_cpeqvl, var_keyin_k, 13
			dw kw_goto_iffalse_n, if75_1

			; Main.bas 975: PutLn t, ""
			dw p_putln_c, var_keyin_t, str2

			; Main.bas 976: Command t
			dw p_command_c, var_keyin_t

			; Main.bas 977: If st(t) = 1 And wt = 0 And front = t Then Prompt t
			dw kw_aget, arr_st, var_keyin_t, tmp0
			dw kw_cpeqvl, tmp0, 1
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_wt, 0
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_cpeqvv, var_front, var_keyin_t
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if75_e
			dw p_prompt_c, var_keyin_t
if76_1:

			; Main.bas 978: ElseIf k = 127 Or k = 8 Then
			dw if75_e_go
if75_1:
			dw kw_cpeqvl, var_keyin_k, 127
			dw kw_ftov, tmp0
			dw kw_cpeqvl, var_keyin_k, 8
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if75_2

			; Main.bas 979: If n > 0 Then
			dw kw_scpgtvl, var_keyin_n, 0
			dw kw_goto_iffalse_n, if75_e

			; Main.bas 980: Memory.WriteByte Far(t, LNLEN), n - 1
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw kw_addl, var_keyin_n, -1, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 981: PutC t, 8 : PutC t, 32 : PutC t, 8
			dw p_putc_c, var_keyin_t, lit_8
			dw p_putc_c, var_keyin_t, lit_32
			dw p_putc_c, var_keyin_t, lit_8

			; Main.bas 982: End If
if77_1:

			; Main.bas 983: ElseIf k >= 32 And k < 127 And n < 70 Then
			dw if75_e_go
if75_2:
			dw kw_scpgevl, var_keyin_k, 32
			dw kw_ftov, tmp0
			dw kw_scpltvl, var_keyin_k, 127
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_scpltvl, var_keyin_n, 70
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if75_3

			; Main.bas 984: Memory.WriteByte Far(t, LNBUF + n), k
			dw kw_addl, var_keyin_n, -2416, tmp1
			dw p_far_c, var_keyin_t, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, var_keyin_k

			; Main.bas 985: Memory.WriteByte Far(t, LNLEN), n + 1
			dw p_far_c, var_keyin_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw kw_addl, var_keyin_n, 1, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 986: PutC t, k
			dw p_putc_c, var_keyin_t, var_keyin_k

			; Main.bas 987: End If
if75_3:
if75_e:
			dw p_keyin_r

ntc_rg34_e:
			IF ($ < 32768) && (ntc_rg35_e - ntc_rg35 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg35:
; ============================================================
; sub command (normal mode)
; ============================================================

p_command:

			; Main.bas 991: Dim c As String Max 72, p As Integer, s As Integer

			; Main.bas 992: p = Memory.ReadByte(Far(t, LNLEN))              ' the command line, from the slot's bank
			dw p_far_c, var_command_t, lit_m2417
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_readbyte, ltmp0, var_command_p

			; Main.bas 993: Memory.Copy Far(t, LNBUF), NearP(VarPtr(ob)), p
			dw p_far_c, var_command_t, lit_m2416
			dw kw_l_mov, var_far_far, ltmp0
			dw p_nearp_c, vp_var_ob
			dw kw_l_mov, var_nearp_nearp, ltmp1
			dw fn_memory_copy, ltmp0, ltmp1, var_command_p, var_memory_copy_copy

			; Main.bas 994: c = UCase$(Trim$(Left$(ob, p)))
			dw kw_strleft, stmp0, var_ob, var_command_p
			dw kw_strtrim, stmp0, stmp0
			dw kw_strucase, stmp0, stmp0
			dw kw_strcpy, var_command_c, stmp0

			; Main.bas 995: a = "" : b = ""
			dw kw_strcpy, var_a, str2
			dw kw_strcpy, var_b, str2

			; Main.bas 996: p = InStr(c, " ")
			dw kw_strinstr, lit_1, var_command_c, str20, var_command_p

			; Main.bas 997: If p > 0 Then
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if78_1

			; Main.bas 998: a = Trim$(Mid$(c, p + 1))
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_command_c, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_a, stmp0

			; Main.bas 999: c = Left$(c, p - 1)
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_command_c, tmp1
			dw kw_strcpy, var_command_c, stmp0

			; Main.bas 1000: End If
if78_1:

			; Main.bas 1001: p = InStr(a, " ")
			dw kw_strinstr, lit_1, var_a, str20, var_command_p

			; Main.bas 1002: If p > 0 Then
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if79_1

			; Main.bas 1003: b = Trim$(Mid$(a, p + 1))
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0

			; Main.bas 1004: a = Left$(a, p - 1)
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_a, tmp1
			dw kw_strcpy, var_a, stmp0

			; Main.bas 1005: End If
if79_1:

			; Main.bas 1006: If Right$(c, 1) = ":" And a = "" Then a = c : c = "CV"   ' B: or IDE: alone: CV B:, CV IDE: (CV.CYB)
			dw kw_strright, stmp0, var_command_c, lit_1
			dw kw_strcmpeq, stmp0, str35
			dw kw_ftov, tmp0
			dw kw_strcmpeq, var_a, str2
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if80_1
			dw kw_strcpy, var_a, var_command_c
			dw kw_strcpy, var_command_c, str36
if80_1:

			; Main.bas 1007: Select Case c
			dw kw_strcpy, var_command___sel81, var_command_c

			; Main.bas 1008: Case ""
			dw kw_strcmpeq, var_command___sel81, str2
			dw kw_goto_iffalse_n, sel81_1
sel81_b1:

			; Main.bas 1009: Case "CLS"
			dw sel81_e_go
sel81_1:
			dw kw_strcmpeq, var_command___sel81, str37
			dw kw_goto_iffalse_n, sel81_2
sel81_b2:

			; Main.bas 1010: ClsT t
			dw p_clst_c, var_command_t

			; Main.bas 1011: Case "RUN"                                 ' RUN [slot] name [tail]: the program on the disc even
			dw sel81_e_go
sel81_2:
			dw kw_strcmpeq, var_command___sel81, str38
			dw kw_goto_iffalse_n, sel81_3
sel81_b3:

			; Main.bas 1012: s = t                                    ' when a command has its name; with a slot: in that one
			dw kw_vtov, var_command_t, var_command_s

			; Main.bas 1013: If a <> "" And N(Val(a)) = a Then
			dw kw_strcmpne, var_a, str2
			dw kw_ftov, tmp0
			dw kw_strval, var_a, tmp1
			dw p_n_c, tmp1
			dw kw_strcpy, stmp1, var_n_n
			dw kw_strcmpeq, stmp1, var_a
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if82_1

			; Main.bas 1014: s = Val(a) : a = b : b = ""
			dw kw_strval, var_a, var_command_s
			dw kw_strcpy, var_a, var_b
			dw kw_strcpy, var_b, str2

			; Main.bas 1015: p = InStr(a, " ")
			dw kw_strinstr, lit_1, var_a, str20, var_command_p

			; Main.bas 1016: If p > 0 Then b = Trim$(Mid$(a, p + 1)) : a = Left$(a, p - 1)
			dw kw_scpgtvl, var_command_p, 0
			dw kw_goto_iffalse_n, if83_1
			dw kw_addl, var_command_p, 1, tmp1
			dw kw_strmid, stmp0, var_a, tmp1, lit_255
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0
			dw kw_addl, var_command_p, -1, tmp1
			dw kw_strleft, stmp0, var_a, tmp1
			dw kw_strcpy, var_a, stmp0
if83_1:

			; Main.bas 1017: End If
if82_1:

			; Main.bas 1018: If s < 1 Or s > ns Then PutLn t, "no slot" + Str$(s) : Exit Sub
			dw kw_scpltvl, var_command_s, 1
			dw kw_ftov, tmp0
			dw kw_scpgtvv, var_command_s, var_ns
			dw kw_ftov, tmp1
			dw kw_orvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if84_1
			dw kw_strstr, stmp2, var_command_s
			dw kw_strcpy, stmp1, str39
			dw kw_strcat, stmp1, stmp2
			dw p_putln_c, var_command_t, stmp1
			dw p_command_r
if84_1:

			; Main.bas 1019: If st(s) = 2 Then PutLn t, "slot" + Str$(s) + " is busy" : Exit Sub
			dw kw_aget, arr_st, var_command_s, tmp0
			dw kw_cpeqvl, tmp0, 2
			dw kw_goto_iffalse_n, if85_1
			dw kw_strstr, stmp2, var_command_s
			dw kw_strcpy, stmp1, str40
			dw kw_strcat, stmp1, stmp2
			dw kw_strcat, stmp1, str41
			dw p_putln_c, var_command_t, stmp1
			dw p_command_r
if85_1:

			; Main.bas 1020: StartTask t, s
			dw p_starttask_c, var_command_t, var_command_s

			; Main.bas 1021: Case "QUIT"
			dw sel81_e_go
sel81_3:
			dw kw_strcmpeq, var_command___sel81, str42
			dw kw_goto_iffalse_n, sel81_4
sel81_b4:

			; Main.bas 1022: quit = -1
			dw kw_ltov, -1, var_quit

			; Main.bas 1023: Case Else                                  ' the rest are programs (the system drive Z's, else
			dw sel81_e_go
sel81_4:

			; Main.bas 1024: b = Trim$(a + " " + b)                   ' the slot's drive, else A): PS, MEM, CD, DIR ... and
			dw kw_strcpy, stmp0, var_a
			dw kw_strcat, stmp0, str20
			dw kw_strcat, stmp0, var_b
			dw kw_strtrim, stmp0, stmp0
			dw kw_strcpy, var_b, stmp0

			; Main.bas 1025: a = c                                    ' any other, the rest of the line their tail
			dw kw_strcpy, var_a, var_command_c

			; Main.bas 1026: bare = -1
			dw kw_ltov, -1, var_bare

			; Main.bas 1027: StartTask t, t
			dw p_starttask_c, var_command_t, var_command_t

			; Main.bas 1028: bare = 0
			dw kw_ztov, var_bare

			; Main.bas 1029: End Select
sel81_e:
			dw p_command_r

ntc_rg35_e:
			IF ($ < 32768) && (ntc_rg36_e - ntc_rg36 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg36:
; ============================================================
; sub starttask (normal mode)
; ============================================================

p_starttask:

			; Main.bas 1037: Dim h As Integer, n As Integer, rest As Integer, com As Integer, w As String Max 72, d As Integer

			; Main.bas 1038: If a = "" Then PutLn t, "RUN what?" : Exit Sub
			dw kw_strcmpeq, var_a, str2
			dw kw_goto_iffalse_n, if86_1
			dw p_putln_c, var_starttask_t, str43
			dw p_starttask_r
if86_1:

			; Main.bas 1039: w = a
			dw kw_strcpy, var_starttask_w, var_a

			; Main.bas 1040: d = 0                                          ' the drive looked on: Z (-1, the system drive: the
			dw kw_ztov, var_starttask_d

			; Main.bas 1045: Do
do87_t:

			; Main.bas 1054: a = w : h = 0 : com = 0
			dw kw_strcpy, var_a, var_starttask_w
			dw kw_ztov, var_starttask_h
			dw kw_ztov, var_starttask_com

			; Main.bas 1055: If InStr(a, ".") = 0 Then
			dw kw_strinstr, lit_1, var_a, str44, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if88_1

			; Main.bas 1056: dn = a + ".CYB"
			dw kw_strcpy, var_dn, var_a
			dw kw_strcat, var_dn, str45

			; Main.bas 1057: h = HOpen()
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h

			; Main.bas 1058: If h Then a = dn Else com = -1
			dw kw_goto_ifzero_n, var_starttask_h, if89_1
			dw kw_strcpy, var_a, var_dn
			dw if88_e_go
if89_1:
			dw kw_ltov, -1, var_starttask_com
if89_e:

			; Main.bas 1059: ElseIf Right$(a, 4) = ".COM" Then
			dw if88_e_go
if88_1:
			dw kw_strright, stmp0, var_a, lit_4
			dw kw_strcmpeq, stmp0, str46
			dw kw_goto_iffalse_n, if88_2

			; Main.bas 1060: com = -1
			dw kw_ltov, -1, var_starttask_com

			; Main.bas 1061: Else
			dw if88_e_go
if88_2:

			; Main.bas 1062: dn = a
			dw kw_strcpy, var_dn, var_a

			; Main.bas 1063: h = HOpen()
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h

			; Main.bas 1064: End If
if88_e:

			; Main.bas 1065: rest = &HEE00                                ' #0100 to the stub (#EF00)
			dw kw_ltov, -4608, var_starttask_rest

			; Main.bas 1066: If com Then dn = a : h = HOpen()             ' (a .COM: UniDOS, a RAM disc read it to its end)
			dw kw_goto_ifzero_n, var_starttask_com, if90_1
			dw kw_strcpy, var_dn, var_a
			dw p_hopen_c
			dw kw_vtov, var_hopen_hopen, var_starttask_h
if90_1:

			; Main.bas 1067: If h Then Exit Do
			dw kw_goto_ifzero_n, var_starttask_h, do87_e
			dw do87_e_go
if91_1:

			; Main.bas 1069: Exit Do
			dw do87_e_go

			; Main.bas 1074: Loop
do87_e:

			; Main.bas 1075: If h = 0 Then
			dw kw_cpeqvl, var_starttask_h, 0
			dw kw_goto_iffalse_n, if92_1

			; Main.bas 1076: a = w
			dw kw_strcpy, var_a, var_starttask_w

			; Main.bas 1081: NotFound t
			dw p_notfound_c, var_starttask_t

			; Main.bas 1082: Exit Sub
			dw p_starttask_r

			; Main.bas 1083: End If
if92_1:

			; Main.bas 1084: If st(s) = 0 Then OpenSlot s
			dw kw_aget, arr_st, var_starttask_s, tmp0
			dw kw_cpeqvl, tmp0, 0
			dw kw_goto_iffalse_n, if93_1
			dw p_openslot_c, var_starttask_s
if93_1:

			; Main.bas 1085: If s <> t Then PutLn s, "RUN " + a
			dw kw_cpnevv, var_starttask_s, var_starttask_t
			dw kw_goto_iffalse_n, if94_1
			dw kw_strcpy, stmp1, str47
			dw kw_strcat, stmp1, var_a
			dw p_putln_c, var_starttask_s, stmp1
if94_1:

			; Main.bas 1086: Install s
			dw p_install_c, var_starttask_s

			; Main.bas 1087: n = Hyp.FileCall(103, rest, s, sg(s), &H100, 0, VarPtr(rb))  ' at #0100, rest bytes at most
			dw kw_aget, arr_sg, var_starttask_s, tmp3
			dw p_hyp_filecall_c, lit_103, var_starttask_rest, var_starttask_s, tmp3, lit_256, lit_0, vp_arr_rb
			dw kw_vtov, var_hyp_filecall_filecall, var_starttask_n

			; Main.bas 1088: HClose
			dw p_hclose_c

			; Main.bas 1096: Memory.WriteWord Far(s, &HF2FC), Hyp.Info(4)
			dw p_far_c, var_starttask_s, lit_m3332
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_hyp_info, lit_4, var_hyp_info_info
			dw kw_vtov, var_hyp_info_info, tmp1
			dw fn_memory_writeword, ltmp0, tmp1

			; Main.bas 1097: Memory.WriteWord Far(s, &HF2FE), 0
			dw p_far_c, var_starttask_s, lit_m3330
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writeword, ltmp0, lit_0

			; Main.bas 1098: Memory.WriteWord Far(s, &HFFFE), &HF2FC
			dw p_far_c, var_starttask_s, lit_m2
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writeword, ltmp0, lit_m3332

			; Main.bas 1100: If b = "" Then
			dw kw_strcmpeq, var_b, str2
			dw kw_goto_iffalse_n, if95_1

			; Main.bas 1101: Memory.WriteByte Far(s, &H80), 0
			dw p_far_c, var_starttask_s, lit_128
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, lit_0

			; Main.bas 1102: Else
			dw if95_e_go
if95_1:

			; Main.bas 1103: b = " " + b
			dw kw_strcpy, stmp0, str20
			dw kw_strcat, stmp0, var_b
			dw kw_strcpy, var_b, stmp0

			; Main.bas 1104: Memory.Copy NearP(VarPtr(b)), Far(s, &H81), Len(b)
			dw p_nearp_c, vp_var_b
			dw kw_l_mov, var_nearp_nearp, ltmp0
			dw p_far_c, var_starttask_s, lit_129
			dw kw_l_mov, var_far_far, ltmp1
			dw kw_strlen, var_b, tmp2
			dw fn_memory_copy, ltmp0, ltmp1, tmp2, var_memory_copy_copy

			; Main.bas 1105: Memory.WriteByte Far(s, &H80), Len(b)
			dw p_far_c, var_starttask_s, lit_128
			dw kw_l_mov, var_far_far, ltmp0
			dw kw_strlen, var_b, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 1106: Memory.WriteByte Far(s, &H81 + Len(b)), 0
			dw kw_strlen, var_b, tmp2
			dw kw_addl, tmp2, 129, tmp1
			dw p_far_c, var_starttask_s, tmp1
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, lit_0

			; Main.bas 1107: End If
if95_e:

			; Main.bas 1108: Memory.WriteByte Far(s, NMLEN), Len(a)
			dw p_far_c, var_starttask_s, lit_m2344
			dw kw_l_mov, var_far_far, ltmp0
			dw kw_strlen, var_a, tmp1
			dw fn_memory_writebyte, ltmp0, tmp1

			; Main.bas 1109: Memory.Copy NearP(VarPtr(a)), Far(s, NMBUF), Len(a)
			dw p_nearp_c, vp_var_a
			dw kw_l_mov, var_nearp_nearp, ltmp0
			dw p_far_c, var_starttask_s, lit_m2343
			dw kw_l_mov, var_far_far, ltmp1
			dw kw_strlen, var_a, tmp2
			dw fn_memory_copy, ltmp0, ltmp1, tmp2, var_memory_copy_copy

			; Main.bas 1110: kq(s) = 0
			dw kw_asetl, arr_kq, var_starttask_s, 0

			; Main.bas 1111: Memory.WriteByte Far(s, &HF685), 0             ' no escape sequence rest half done
			dw p_far_c, var_starttask_s, lit_m2427
			dw kw_l_mov, var_far_far, ltmp0
			dw fn_memory_writebyte, ltmp0, lit_0

			; Main.bas 1112: wk(s) = -1
			dw kw_asetl, arr_wk, var_starttask_s, -1

			; Main.bas 1113: dm(s) = &H80                                   ' CP/M's record buffer to start with
			dw kw_asetl, arr_dm, var_starttask_s, 128

			; Main.bas 1114: st(s) = 2
			dw kw_asetl, arr_st, var_starttask_s, 2

			; Main.bas 1115: If s <> t Then PutLn t, a + " runs in slot" + Str$(s)
			dw kw_cpnevv, var_starttask_s, var_starttask_t
			dw kw_goto_iffalse_n, if96_1
			dw kw_strcpy, stmp1, var_a
			dw kw_strcat, stmp1, str48
			dw kw_strstr, stmp2, var_starttask_s
			dw kw_strcat, stmp1, stmp2
			dw p_putln_c, var_starttask_t, stmp1
if96_1:
			dw p_starttask_r

ntc_rg36_e:
			IF ($ < 32768) && (ntc_rg37_e - ntc_rg37 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg37:
; ============================================================
; sub notfound (normal mode)
; ============================================================

p_notfound:

			; Main.bas 1119: If bare Then PutLn t, "? " + a + " (HELP)" Else PutLn t, a + ": not found"
			dw kw_goto_ifzero_n, var_bare, if97_1
			dw kw_strcpy, stmp1, str49
			dw kw_strcat, stmp1, var_a
			dw kw_strcat, stmp1, str50
			dw p_putln_c, var_notfound_t, stmp1
			dw if97_e_go
if97_1:
			dw kw_strcpy, stmp1, var_a
			dw kw_strcat, stmp1, str51
			dw p_putln_c, var_notfound_t, stmp1
if97_e:
			dw p_notfound_r

ntc_rg37_e:
			IF ($ < 32768) && (ntc_rg38_e - ntc_rg38 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg38:
; ============================================================
; sub endtask (normal mode)
; ============================================================

p_endtask:

			; Main.bas 1133: Dim c As Integer

			; Main.bas 1134: FilesShut t
			dw p_filesshut_c, var_endtask_t

			; Main.bas 1139: st(t) = 1
			dw kw_asetl, arr_st, var_endtask_t, 1

			; Main.bas 1140: runs = runs + 1
			dw kw_inc, var_runs

			; Main.bas 1141: PutLn t, ""
			dw p_putln_c, var_endtask_t, str2

			; Main.bas 1142: GetNm t
			dw p_getnm_c, var_endtask_t

			; Main.bas 1143: PutLn t, "[" + en + " ended]"
			dw kw_strcpy, stmp1, str10
			dw kw_strcat, stmp1, var_en
			dw kw_strcat, stmp1, str52
			dw p_putln_c, var_endtask_t, stmp1

			; Main.bas 1144: If wt <> t Then Prompt t                       ' (WAIT: the prompt when nothing runs)
			dw kw_cpnevv, var_wt, var_endtask_t
			dw kw_goto_iffalse_n, if98_1
			dw p_prompt_c, var_endtask_t
if98_1:

			; Main.bas 1145: c = kq(t) : kq(t) = 0
			dw kw_aget, arr_kq, var_endtask_t, var_endtask_c
			dw kw_asetl, arr_kq, var_endtask_t, 0

			; Main.bas 1146: If c <> 0 And t = front Then pk = c    ' a key typed for it after its last look: the command line's
			dw kw_cpnevl, var_endtask_c, 0
			dw kw_ftov, tmp0
			dw kw_cpeqvv, var_endtask_t, var_front
			dw kw_ftov, tmp1
			dw kw_andvv, tmp0, tmp1, tmp0
			dw kw_goto_ifzero_n, tmp0, if99_1
			dw kw_vtov, var_endtask_c, var_pk
if99_1:
			dw p_endtask_r

ntc_rg38_e:
			IF ($ < 32768) && (ntc_rg39_e - ntc_rg39 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg39:
; ============================================================
; sub con (normal mode)
; ============================================================

p_hyp_con:

			; Hyp.cls 282: #asm
			dw asm_1_282_n
			dw p_hyp_con_r

ntc_rg39_e:
			IF ($ < 32768) && (ntc_rg40_e - ntc_rg40 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg40:
; ============================================================
; sub say (normal mode)
; ============================================================

p_hyp_say:

			; Hyp.cls 1351: #asm
			dw asm_1_1351_n
			dw p_hyp_say_r

ntc_rg40_e:
			IF ($ < 32768) && (ntc_rg41_e - ntc_rg41 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg41:
; ============================================================
; function scr (normal mode)
; ============================================================

p_hyp_scr:

			; Hyp.cls 1445: #asm
			dw asm_1_1445_n
			dw p_hyp_scr_r

ntc_rg41_e:
			IF ($ < 32768) && (ntc_rg42_e - ntc_rg42 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg42:
; ============================================================
; sub keyrep (normal mode)
; ============================================================

p_hyp_keyrep:

			; Hyp.cls 1547: #asm
			dw asm_1_1547_n
			dw p_hyp_keyrep_r

ntc_rg42_e:
			IF ($ < 32768) && (ntc_rg43_e - ntc_rg43 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg43:
; ============================================================
; sub show (normal mode)
; ============================================================

p_hyp_show:

			; Hyp.cls 1587: Con pg, 0, -1, 1
			dw p_hyp_con_c, var_hyp_show_pg, lit_0, lit_m1, lit_1
			dw p_hyp_show_r

ntc_rg43_e:
			IF ($ < 32768) && (ntc_rg44_e - ntc_rg44 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg44:
; ============================================================
; sub reply (normal mode)
; ============================================================

p_hyp_reply:

			; Hyp.cls 1593: ra = a : rhl = hl
			dw kw_vtov, var_hyp_reply_a, var_hyp_ra
			dw kw_vtov, var_hyp_reply_hl, var_hyp_rhl
			dw p_hyp_reply_r

ntc_rg44_e:
			IF ($ < 32768) && (ntc_rg45_e - ntc_rg45 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg45:
; ============================================================
; function fn (normal mode)
; ============================================================

p_hyp_fn:

			; Hyp.cls 1597: Fn = rfn And 255
			dw kw_andvl, var_hyp_rfn, 255, var_hyp_fn_fn
			dw p_hyp_fn_r

ntc_rg45_e:
			IF ($ < 32768) && (ntc_rg46_e - ntc_rg46 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg46:
; ============================================================
; function arg (normal mode)
; ============================================================

p_hyp_arg:

			; Hyp.cls 1601: Arg = rde
			dw kw_vtov, var_hyp_rde, var_hyp_arg_arg
			dw p_hyp_arg_r

ntc_rg46_e:
			IF ($ < 32768) && (ntc_rg47_e - ntc_rg47 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg47:
; ============================================================
; function count (normal mode)
; ============================================================

p_hyp_count:

			; Hyp.cls 1606: Count = rcnt
			dw kw_vtov, var_hyp_rcnt, var_hyp_count_count
			dw p_hyp_count_r

ntc_rg47_e:
			IF ($ < 32768) && (ntc_rg48_e - ntc_rg48 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg48:
; ============================================================
; function run (normal mode)
; ============================================================

p_hyp_run:

			; Hyp.cls 1611: #asm
			dw asm_1_1611_n
			dw p_hyp_run_r

ntc_rg48_e:
			IF ($ < 32768) && (ntc_rg49_e - ntc_rg49 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg49:
; ============================================================
; sub vdu (normal mode)
; ============================================================

p_hyp_vdu:

			; Hyp.cls 2284: #asm
			dw asm_1_2284_n
			dw p_hyp_vdu_r

ntc_rg49_e:
			IF ($ < 32768) && (ntc_rg50_e - ntc_rg50 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg50:
; ============================================================
; function filecall (normal mode)
; ============================================================

p_hyp_filecall:

			; Hyp.cls 2316: #asm
			dw asm_1_2316_n
			dw p_hyp_filecall_r

ntc_rg50_e:
			IF ($ < 32768) && (ntc_rg51_e - ntc_rg51 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg51:
; ============================================================
; sub fileshut (normal mode)
; ============================================================

p_hyp_fileshut:

			; Hyp.cls 3867: #asm
			dw asm_1_3867_n
			dw p_hyp_fileshut_r

ntc_rg51_e:
			IF ($ < 32768) && (ntc_rg52_e - ntc_rg52 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg52:
; ============================================================
; sub slots (normal mode)
; ============================================================

p_hot_slots:

			; Hot.cls 15: ns = n
			dw kw_vtov, var_hot_slots_n, var_hot_ns
			dw p_hot_slots_r

ntc_rg52_e:
			IF ($ < 32768) && (ntc_rg53_e - ntc_rg53 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg53:
; ============================================================
; sub tick (normal mode)
; ============================================================

p_hot_tick:

			; Hot.cls 19: Dim k As Integer

			; Hot.cls 20: ctl = Keys.Down(Keys.KeyControl)
			dw fn_keys_down, lit_23, var_hot_ctl

			; Hot.cls 21: If ctl Then
			dw kw_goto_ifzero_n, var_hot_ctl, if100_1

			; Hot.cls 22: If Keys.Down(64) Then k = 1
			dw fn_keys_down, lit_64, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if101_1
			dw kw_ltov, 1, var_hot_tick_k
if101_1:

			; Hot.cls 23: If Keys.Down(65) Then k = 2
			dw fn_keys_down, lit_65, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if102_1
			dw kw_ltov, 2, var_hot_tick_k
if102_1:

			; Hot.cls 24: If Keys.Down(57) Then k = 3
			dw fn_keys_down, lit_57, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if103_1
			dw kw_ltov, 3, var_hot_tick_k
if103_1:

			; Hot.cls 25: If Keys.Down(56) Then k = 4
			dw fn_keys_down, lit_56, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if104_1
			dw kw_ltov, 4, var_hot_tick_k
if104_1:

			; Hot.cls 26: If Keys.Down(49) Then k = 5
			dw fn_keys_down, lit_49, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if105_1
			dw kw_ltov, 5, var_hot_tick_k
if105_1:

			; Hot.cls 27: If Keys.Down(48) Then k = 6
			dw fn_keys_down, lit_48, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if106_1
			dw kw_ltov, 6, var_hot_tick_k
if106_1:

			; Hot.cls 28: If Keys.Down(41) Then k = 7
			dw fn_keys_down, lit_41, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if107_1
			dw kw_ltov, 7, var_hot_tick_k
if107_1:

			; Hot.cls 29: If Keys.Down(40) Then k = 8
			dw fn_keys_down, lit_40, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if108_1
			dw kw_ltov, 8, var_hot_tick_k
if108_1:

			; Hot.cls 30: If Keys.Down(33) Then k = 9
			dw fn_keys_down, lit_33, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if109_1
			dw kw_ltov, 9, var_hot_tick_k
if109_1:

			; Hot.cls 31: If Keys.Down(32) Then k = 10
			dw fn_keys_down, lit_32, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if110_1
			dw kw_ltov, 10, var_hot_tick_k
if110_1:

			; Hot.cls 32: If Keys.Down(Keys.KeyEsc) Then k = TOPKEY
			dw fn_keys_down, lit_66, var_keys_down_down
			dw kw_goto_ifzero_n, var_keys_down_down, if111_1
			dw kw_ltov, 99, var_hot_tick_k
if111_1:

			; Hot.cls 33: End If
if100_1:

			; Hot.cls 34: If k <> 0 And k <> last Then
			dw kw_cpnevl, var_hot_tick_k, 0
			dw kw_ftov, tmp5
			dw kw_cpnevv, var_hot_tick_k, var_hot_last
			dw kw_ftov, tmp6
			dw kw_andvv, tmp5, tmp6, tmp5
			dw kw_goto_ifzero_n, tmp5, if112_1

			; Hot.cls 35: If k = TOPKEY Or ns <= 10 Then
			dw kw_cpeqvl, var_hot_tick_k, 99
			dw kw_ftov, tmp5
			dw kw_scplevl, var_hot_ns, 10
			dw kw_ftov, tmp6
			dw kw_orvv, tmp5, tmp6, tmp5
			dw kw_goto_ifzero_n, tmp5, if113_1

			; Hot.cls 36: If one <> 0 Then one = 0
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if114_1
			dw kw_ztov, var_hot_one
if114_1:

			; Hot.cls 37: pend = k                          ' at once (no double taps to wait for)
			dw kw_vtov, var_hot_tick_k, var_hot_pend

			; Hot.cls 38: ElseIf one = k Then
			dw if113_e_go
if113_1:
			dw kw_cpeqvv, var_hot_one, var_hot_tick_k
			dw kw_goto_iffalse_n, if113_2

			; Hot.cls 39: one = 0
			dw kw_ztov, var_hot_one

			; Hot.cls 40: If k + 10 <= ns Then pend = k + 10 Else pend = k  ' the second press: slot 11-20
			dw kw_addl, var_hot_tick_k, 10, tmp5
			dw kw_scplevv, tmp5, var_hot_ns
			dw kw_goto_iffalse_n, if115_1
			dw kw_addl, var_hot_tick_k, 10, var_hot_pend
			dw if113_e_go
if115_1:
			dw kw_vtov, var_hot_tick_k, var_hot_pend
if115_e:

			; Hot.cls 41: Else
			dw if113_e_go
if113_2:

			; Hot.cls 42: If one <> 0 Then pend = one       ' another number: the waiting one counts now
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if116_1
			dw kw_vtov, var_hot_one, var_hot_pend
if116_1:

			; Hot.cls 43: one = k : age = 0
			dw kw_vtov, var_hot_tick_k, var_hot_one
			dw kw_ztov, var_hot_age

			; Hot.cls 44: End If
if113_e:

			; Hot.cls 45: End If
if112_1:

			; Hot.cls 46: If one <> 0 Then
			dw kw_cpnevl, var_hot_one, 0
			dw kw_goto_iffalse_n, if117_1

			; Hot.cls 47: age = age + 1
			dw kw_inc, var_hot_age

			; Hot.cls 48: If age > DOUBLE Or ctl = 0 Then pend = one : one = 0    ' no second press (or Control let go)
			dw kw_scpgtvl, var_hot_age, 15
			dw kw_ftov, tmp5
			dw kw_cpeqvl, var_hot_ctl, 0
			dw kw_ftov, tmp6
			dw kw_orvv, tmp5, tmp6, tmp5
			dw kw_goto_ifzero_n, tmp5, if118_1
			dw kw_vtov, var_hot_one, var_hot_pend
			dw kw_ztov, var_hot_one
if118_1:

			; Hot.cls 49: End If
if117_1:

			; Hot.cls 50: last = k
			dw kw_vtov, var_hot_tick_k, var_hot_last
			dw p_hot_tick_r

ntc_rg53_e:
			IF ($ < 32768) && (ntc_rg54_e - ntc_rg54 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg54:
; ============================================================
; function take (normal mode)
; ============================================================

p_hot_take:

			; Hot.cls 54: Take = pend
			dw kw_vtov, var_hot_pend, var_hot_take_take

			; Hot.cls 55: pend = 0
			dw kw_ztov, var_hot_pend
			dw p_hot_take_r

ntc_rg54_e:
			IF ($ < 32768) && (ntc_rg55_e - ntc_rg55 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg55:
; ============================================================
; function control (normal mode)
; ============================================================

p_hot_control:

			; Hot.cls 60: Control = ctl
			dw kw_vtov, var_hot_ctl, var_hot_control_control
			dw p_hot_control_r

ntc_rg55_e:
			IF ($ < 32768) && (ntc_rg56_e - ntc_rg56 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg56:
; ============================================================
; function held (normal mode)
; ============================================================

p_hot_held:

			; Hot.cls 66: Held = last
			dw kw_vtov, var_hot_last, var_hot_held_held
			dw p_hot_held_r

ntc_rg56_e:
			IF ($ < 32768) && (ntc_rg57_e - ntc_rg57 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg57:
; ============================================================
; function bankpage (normal mode)
; ============================================================

p_memory_bankpage:

			; Memory.cls 452: BankPage = 4 * bank - 2 + n
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
for25_e_go:			ld sp, for25_e
			jp ntc_xn
do33_e_go:			ld sp, do33_e
			jp ntc_xn
do33_t_go:			ld sp, do33_t
			jp ntc_xn
sel42_e_go:			ld sp, sel42_e
			jp ntc_xn
ch51_e_go:			ld sp, ch51_e
			jp ntc_xn
if50_e_go:			ld sp, if50_e
			jp ntc_xn
ch55_e_go:			ld sp, ch55_e
			jp ntc_xn
ch56_e_go:			ld sp, ch56_e
			jp ntc_xn
ch57_e_go:			ld sp, ch57_e
			jp ntc_xn
if62_e_go:			ld sp, if62_e
			jp ntc_xn
if64_e_go:			ld sp, if64_e
			jp ntc_xn
ch66_e_go:			ld sp, ch66_e
			jp ntc_xn
if67_e_go:			ld sp, if67_e
			jp ntc_xn
if69_e_go:			ld sp, if69_e
			jp ntc_xn
if71_e_go:			ld sp, if71_e
			jp ntc_xn
if75_e_go:			ld sp, if75_e
			jp ntc_xn
sel81_e_go:			ld sp, sel81_e
			jp ntc_xn
if88_e_go:			ld sp, if88_e
			jp ntc_xn
do87_e_go:			ld sp, do87_e
			jp ntc_xn
if95_e_go:			ld sp, if95_e
			jp ntc_xn
if97_e_go:			ld sp, if97_e
			jp ntc_xn
if113_e_go:			ld sp, if113_e
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
			ld hl, 0
			ld (var_filesshut_r), hl
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

ntc_rg57_e:
			IF ($ < 32768) && (ntc_rg58_e - ntc_rg58 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg58:
; ============================================================
; Inline assembly (#asm ... #endasm)
; ============================================================

fn_hyp_usepage:		; sub usepage (asm keyword), Hyp.cls line 49
            ld hl, (ntc_rampt)		; Hyp.cls 50
            ld (var_hyp_hps), hl		; Hyp.cls 51
			ret			; end of #asm

fn_hyp_setting:		; function setting (asm keyword), Hyp.cls line 97
            ld de, (ntc_rampt)		; Hyp.cls 98
            ld a, e		; Hyp.cls 99
            and #F8		; Hyp.cls 100
            or 2		; Hyp.cls 101
            ld e, a		; Hyp.cls 102
            pop hl		; Hyp.cls 103
            ld (hl), e		; Hyp.cls 104
            inc hl		; Hyp.cls 105
            ld (hl), d		; Hyp.cls 106
			ret			; end of #asm

fn_hyp_farptr:		; function farptr (asm keyword), Hyp.cls line 113
            pop hl		; Hyp.cls 114
            ld c, (hl)		; Hyp.cls 115
            inc hl		; Hyp.cls 116
            ld b, (hl)              ; BC = page [117]
            pop hl		; Hyp.cls 118
            ld e, (hl)		; Hyp.cls 119
            inc hl		; Hyp.cls 120
            ld a, (hl)		; Hyp.cls 121
            and #3F		; Hyp.cls 122
            or #40		; Hyp.cls 123
            ld d, a                 ; DE = #4000 + the address's low 14 bits [124]
            pop hl		; Hyp.cls 125
            ld (hl), e		; Hyp.cls 126
            inc hl		; Hyp.cls 127
            ld (hl), d		; Hyp.cls 128
            inc hl		; Hyp.cls 129
            ld (hl), c		; Hyp.cls 130
            inc hl		; Hyp.cls 131
            ld (hl), b		; Hyp.cls 132
			ret			; end of #asm

fn_hyp_fontinit:		; sub fontinit (asm keyword), Hyp.cls line 166
            ld (var_hyp_hsp), sp		; Hyp.cls 167
            ld sp, (ntc_csp)		; Hyp.cls 168
            ld bc, (var_hyp_hps)		; Hyp.cls 169
            out (c), c		; Hyp.cls 170
            ld de, 32               ; D = 0: a table, E = its first character [171]
            ld hl, #4000 + 4096		; Hyp.cls 172
            call #BBAB              ; TXT SET M TABLE (the matrices from 32 on, copied there) [173]
            di		; Hyp.cls 174
            ld de, #FF00            ; D <> 0: no table of its own any more [175]
            call #BBAB		; Hyp.cls 176
            di		; Hyp.cls 177
            ld bc, (ntc_rampt)		; Hyp.cls 178
            out (c), c		; Hyp.cls 179
            ld sp, (var_hyp_hsp)		; Hyp.cls 180
			ret			; end of #asm

asm_1_282_n:		; #asm, Hyp.cls line 282 (normal)
; CN_SB 1: the scrollback (Shift + Up / Down: 48 rows a slot, kept in a 16K page Main gives - #If
; SCROLLBACK in Main.bas, set the two together). Off for now: 526 bytes of main RAM (2026-10-16)
asm_1_282_n_CN_SB:      equ 0		; Hyp.cls 285
            ld (var_hyp_hsp), sp		; Hyp.cls 286
            ld sp, (ntc_csp)		; Hyp.cls 287
            ld bc, (var_hyp_con_pg)		; Hyp.cls 288
            out (c), c              ; the slot's page 3 at #4000: OBUF #7600, state #7682, page #7700 [289]
            IF asm_1_282_n_CN_SB		; Hyp.cls 290
            ld (asm_1_282_n_cn_pg), bc		; Hyp.cls 291
            ENDIF		; Hyp.cls 292
            xor a		; Hyp.cls 293
            ld (asm_1_282_n_cn_pv), a		; Hyp.cls 294
            ld a, (var_hyp_con_front)		; Hyp.cls 295
            ld (asm_1_282_n_cn_front), a		; Hyp.cls 296
            ld a, (#7687)           ; its columns and rows (MODE) [297]
            ld (asm_1_282_n_cn_c), a		; Hyp.cls 298
            ld a, (#7688)		; Hyp.cls 299
            ld (asm_1_282_n_cn_r), a		; Hyp.cls 300
            ld a, (var_hyp_ccu)           ; the cursor off first, whatever comes (it was on: cn_was) [301]
            ld (asm_1_282_n_cn_was), a		; Hyp.cls 302
            or a		; Hyp.cls 303
            call nz, asm_1_282_n_cn_cuxor		; Hyp.cls 304
            ld hl, (var_hyp_con_n)		; Hyp.cls 305
            bit 7, h		; Hyp.cls 306
            jp nz, asm_1_282_n_cn_neg		; Hyp.cls 307
            ld (asm_1_282_n_cn_left), hl		; Hyp.cls 308
            IF asm_1_282_n_CN_SB		; Hyp.cls 309
            ld a, (asm_1_282_n_cn_front)        ; in front and looking back (scrollback): the page again first [310]
            or a		; Hyp.cls 311
            jr z, asm_1_282_n_cn_live		; Hyp.cls 312
            ld a, (#7F26)		; Hyp.cls 313
            or a		; Hyp.cls 314
            jr z, asm_1_282_n_cn_live		; Hyp.cls 315
            xor a		; Hyp.cls 316
            ld (#7F26), a		; Hyp.cls 317
            call asm_1_282_n_cn_cls		; Hyp.cls 318
            call asm_1_282_n_cn_strip		; Hyp.cls 319
            call asm_1_282_n_cn_draw		; Hyp.cls 320
            ld hl, (asm_1_282_n_cn_left)		; Hyp.cls 321
asm_1_282_n_cn_live:		; Hyp.cls 322
            ENDIF		; Hyp.cls 323
            ld hl, (var_hyp_con_src)		; Hyp.cls 324
            ld a, h		; Hyp.cls 325
            or l		; Hyp.cls 326
            jr nz, asm_1_282_n_cn_src		; Hyp.cls 327
            ld hl, #7600            ; src 0: the characters the program collected (OBUF) [328]
asm_1_282_n_cn_src:		; Hyp.cls 329
            ld (asm_1_282_n_cn_ptr), hl		; Hyp.cls 330
asm_1_282_n_cn_lp:		; Hyp.cls 331
            ld hl, (asm_1_282_n_cn_left)		; Hyp.cls 332
            ld a, h		; Hyp.cls 333
            or l		; Hyp.cls 334
            jr z, asm_1_282_n_cn_done		; Hyp.cls 335
            dec hl		; Hyp.cls 336
            ld (asm_1_282_n_cn_left), hl		; Hyp.cls 337
            ld hl, (asm_1_282_n_cn_ptr)		; Hyp.cls 338
            ld a, (hl)		; Hyp.cls 339
            inc hl		; Hyp.cls 340
            ld (asm_1_282_n_cn_ptr), hl		; Hyp.cls 341
            call asm_1_282_n_cn_char		; Hyp.cls 342
            jr asm_1_282_n_cn_lp		; Hyp.cls 343
asm_1_282_n_cn_done:		; Hyp.cls 344
            ld bc, (ntc_rampt)      ; the window's page back [345]
            out (c), c		; Hyp.cls 346
            ld sp, (var_hyp_hsp)		; Hyp.cls 347
            jp asm_1_282_n_cn_end		; Hyp.cls 348

; n < 0: -1 the whole page to the screen (it was cleared: Show), not looking back any more; -2
; the scrollback (src: the key - #F4 Shift + Up a screen back, #F5 Shift + Down one on), drawn
asm_1_282_n_cn_neg:		; Hyp.cls 352
            ld a, l		; Hyp.cls 353
            cp #FD                  ; -3: the cursor flashes - on (it was off), an underline XORed [354]
            jr nz, asm_1_282_n_cn_neg1          ; where the next character goes; off (it was on: done above) [355]
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 356
            or a		; Hyp.cls 357
            jr z, asm_1_282_n_cn_done		; Hyp.cls 358
            ld a, (asm_1_282_n_cn_was)		; Hyp.cls 359
            or a		; Hyp.cls 360
            jr nz, asm_1_282_n_cn_done		; Hyp.cls 361
            ld a, (#7682)		; Hyp.cls 362
            ld d, a		; Hyp.cls 363
            ld a, (#7683)		; Hyp.cls 364
            ld e, a		; Hyp.cls 365
            call asm_1_282_n_cn_scr		; Hyp.cls 366
            ld a, h		; Hyp.cls 367
            add a, #38              ; (its cell's last pixel line) [368]
            ld h, a		; Hyp.cls 369
            ld (asm_1_282_n_cn_ca), hl		; Hyp.cls 370
            call asm_1_282_n_cn_cuxor		; Hyp.cls 371
            jr asm_1_282_n_cn_done		; Hyp.cls 372
asm_1_282_n_cn_neg1:		; Hyp.cls 373
            IF asm_1_282_n_CN_SB		; Hyp.cls 374
            inc hl		; Hyp.cls 375
            ld a, h		; Hyp.cls 376
            or l		; Hyp.cls 377
            jr nz, asm_1_282_n_cn_view		; Hyp.cls 378
            ld (#7F26), a		; Hyp.cls 379
            ENDIF		; Hyp.cls 380
asm_1_282_n_cn_show:		; Hyp.cls 381
            call asm_1_282_n_cn_strip		; Hyp.cls 382
            call asm_1_282_n_cn_draw		; Hyp.cls 383
            jr asm_1_282_n_cn_done		; Hyp.cls 384
            IF asm_1_282_n_CN_SB		; Hyp.cls 385
asm_1_282_n_cn_view:		; Hyp.cls 386
            ld a, (#7F21)           ; (no history page: nothing) [387]
            or a		; Hyp.cls 388
            jr z, asm_1_282_n_cn_done		; Hyp.cls 389
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 390
            dec a		; Hyp.cls 391
            ld b, a                 ; a screen: its rows - 1 [392]
            ld a, (var_hyp_con_src)		; Hyp.cls 393
            cp #F4		; Hyp.cls 394
            ld a, (#7F26)		; Hyp.cls 395
            jr nz, asm_1_282_n_cn_vw_dn		; Hyp.cls 396
            add a, b		; Hyp.cls 397
            ld hl, #7F25		; Hyp.cls 398
            cp (hl)		; Hyp.cls 399
            jr c, asm_1_282_n_cn_vw_set		; Hyp.cls 400
            ld a, (hl)              ; (not past the oldest row kept) [401]
            jr asm_1_282_n_cn_vw_set		; Hyp.cls 402
asm_1_282_n_cn_vw_dn:		; Hyp.cls 403
            sub b		; Hyp.cls 404
            jr nc, asm_1_282_n_cn_vw_set		; Hyp.cls 405
            xor a		; Hyp.cls 406
asm_1_282_n_cn_vw_set:		; Hyp.cls 407
            ld hl, #7F26		; Hyp.cls 408
            cp (hl)		; Hyp.cls 409
            jr z, asm_1_282_n_cn_done		; Hyp.cls 410
            ld (hl), a		; Hyp.cls 411
            call asm_1_282_n_cn_cls		; Hyp.cls 412
            jr asm_1_282_n_cn_show		; Hyp.cls 413

            ENDIF		; Hyp.cls 415

; the screen's rows: the page's - or, looking back (#FF26 rows), the history's first, then the
; page's. Row e shows line count + e - back of history + page (count the rows kept, #FF25)
asm_1_282_n_cn_draw:		; Hyp.cls 419
            ld e, 0		; Hyp.cls 420
            IF asm_1_282_n_CN_SB		; Hyp.cls 421
asm_1_282_n_cn_dr_row:		; Hyp.cls 422
            push de		; Hyp.cls 423
            ld a, (#7F25)		; Hyp.cls 424
            add a, e		; Hyp.cls 425
            ld hl, #7F26		; Hyp.cls 426
            sub (hl)                ; the line: count + e - back [427]
            ld hl, #7F25		; Hyp.cls 428
            sub (hl)		; Hyp.cls 429
            jr c, asm_1_282_n_cn_dr_h		; Hyp.cls 430
            call asm_1_282_n_cn_rowa            ; HL = row (line - count) of the page [431]
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 432
            jr asm_1_282_n_cn_dr_go		; Hyp.cls 433
asm_1_282_n_cn_dr_h:		; Hyp.cls 434
            add a, (hl)		; Hyp.cls 435
            call asm_1_282_n_cn_hget            ; HL = the history's row (copied in), 80 characters at most [436]
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 437
            cp asm_1_282_n_HW		; Hyp.cls 438
            jr c, asm_1_282_n_cn_dr_go		; Hyp.cls 439
            ld a, asm_1_282_n_HW		; Hyp.cls 440
asm_1_282_n_cn_dr_go:		; Hyp.cls 441
            ld b, a		; Hyp.cls 442
            pop de		; Hyp.cls 443
            push de		; Hyp.cls 444
            ld d, 0		; Hyp.cls 445
asm_1_282_n_cn_dr_col:		; Hyp.cls 446
            ld a, (hl)		; Hyp.cls 447
            inc hl		; Hyp.cls 448
            cp 33		; Hyp.cls 449
            jr c, asm_1_282_n_cn_dr_sk		; Hyp.cls 450
            push hl		; Hyp.cls 451
            push de		; Hyp.cls 452
            push bc		; Hyp.cls 453
            call asm_1_282_n_cn_glyph		; Hyp.cls 454
            pop bc		; Hyp.cls 455
            pop de		; Hyp.cls 456
            pop hl		; Hyp.cls 457
asm_1_282_n_cn_dr_sk:		; Hyp.cls 458
            inc d		; Hyp.cls 459
            djnz asm_1_282_n_cn_dr_col		; Hyp.cls 460
            pop de		; Hyp.cls 461
            inc e		; Hyp.cls 462
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 463
            dec a		; Hyp.cls 464
            cp e		; Hyp.cls 465
            jr nc, asm_1_282_n_cn_dr_row		; Hyp.cls 466
            ret		; Hyp.cls 467
            ELSE		; Hyp.cls 468
asm_1_282_n_cn_sh_row:                          ; (no scrollback: the page's rows as they are) [469]
            push de		; Hyp.cls 470
            ld a, e		; Hyp.cls 471
            call asm_1_282_n_cn_rowa            ; HL = row e of the page [472]
            pop de		; Hyp.cls 473
            ld d, 0		; Hyp.cls 474
asm_1_282_n_cn_sh_col:		; Hyp.cls 475
            ld a, (hl)		; Hyp.cls 476
            inc hl		; Hyp.cls 477
            cp 33		; Hyp.cls 478
            jr c, asm_1_282_n_cn_sh_skip		; Hyp.cls 479
            push hl		; Hyp.cls 480
            push de		; Hyp.cls 481
            call asm_1_282_n_cn_glyph		; Hyp.cls 482
            pop de		; Hyp.cls 483
            pop hl		; Hyp.cls 484
asm_1_282_n_cn_sh_skip:		; Hyp.cls 485
            inc d		; Hyp.cls 486
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 487
            dec a		; Hyp.cls 488
            cp d		; Hyp.cls 489
            jr nc, asm_1_282_n_cn_sh_col		; Hyp.cls 490
            inc e		; Hyp.cls 491
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 492
            dec a		; Hyp.cls 493
            cp e		; Hyp.cls 494
            jr nc, asm_1_282_n_cn_sh_row		; Hyp.cls 495
            ret		; Hyp.cls 496
            ENDIF		; Hyp.cls 497

            IF asm_1_282_n_CN_SB		; Hyp.cls 499
; the scrollback: each row that scrolls off the top of the page - its first HW characters - goes
; to the slot's history: HROWS rows (a ring) in a 16K page of its own that Main gave it (#FF20:
; its RAM setting, 0 none; #FF22 where in it; #FF24 the next row written, #FF25 how many, #FF26
; how far back the screen looks). Copied 8 bytes at a time through the stack - only the window
; changes, so no main RAM for a buffer
asm_1_282_n_HW:         equ 80		; Hyp.cls 505
asm_1_282_n_HROWS:      equ 48		; Hyp.cls 506
asm_1_282_n_cn_hput:                            ; HL = the row going (the page) [507]
            ld a, (#7F21)		; Hyp.cls 508
            or a		; Hyp.cls 509
            ret z		; Hyp.cls 510
            ld (asm_1_282_n_cn_hs), hl		; Hyp.cls 511
            ld hl, (asm_1_282_n_cn_pg)		; Hyp.cls 512
            ld (asm_1_282_n_cn_h1), hl		; Hyp.cls 513
            ld hl, (#7F20)		; Hyp.cls 514
            ld (asm_1_282_n_cn_h2), hl		; Hyp.cls 515
            ld a, (#7F24)		; Hyp.cls 516
            call asm_1_282_n_cn_haddr		; Hyp.cls 517
            ld (asm_1_282_n_cn_hd), hl		; Hyp.cls 518
            ld hl, #7F24            ; the next row on, one more kept [519]
            ld a, (hl)		; Hyp.cls 520
            inc a		; Hyp.cls 521
            cp asm_1_282_n_HROWS		; Hyp.cls 522
            jr c, asm_1_282_n_cn_hp_h		; Hyp.cls 523
            xor a		; Hyp.cls 524
asm_1_282_n_cn_hp_h:		; Hyp.cls 525
            ld (hl), a		; Hyp.cls 526
            inc hl		; Hyp.cls 527
            ld a, (hl)		; Hyp.cls 528
            cp asm_1_282_n_HROWS		; Hyp.cls 529
            jr nc, asm_1_282_n_cn_hcp		; Hyp.cls 530
            inc (hl)		; Hyp.cls 531
; cn_hcp: HW bytes from cn_hs in RAM setting cn_h1 to cn_hd in cn_h2, then the slot's page back
asm_1_282_n_cn_hcp:		; Hyp.cls 533
            ld a, asm_1_282_n_HW / 8		; Hyp.cls 534
asm_1_282_n_cn_hc_lp:		; Hyp.cls 535
            ld (asm_1_282_n_cn_hn), a		; Hyp.cls 536
            ld bc, (asm_1_282_n_cn_h1)		; Hyp.cls 537
            out (c), c		; Hyp.cls 538
            ld hl, (asm_1_282_n_cn_hs)		; Hyp.cls 539
            ld b, 4		; Hyp.cls 540
asm_1_282_n_cn_hc_in:		; Hyp.cls 541
            ld e, (hl)		; Hyp.cls 542
            inc hl		; Hyp.cls 543
            ld d, (hl)		; Hyp.cls 544
            inc hl		; Hyp.cls 545
            push de		; Hyp.cls 546
            djnz asm_1_282_n_cn_hc_in		; Hyp.cls 547
            ld (asm_1_282_n_cn_hs), hl		; Hyp.cls 548
            ld bc, (asm_1_282_n_cn_h2)		; Hyp.cls 549
            out (c), c		; Hyp.cls 550
            ld hl, (asm_1_282_n_cn_hd)		; Hyp.cls 551
            ld de, 8		; Hyp.cls 552
            add hl, de		; Hyp.cls 553
            ld (asm_1_282_n_cn_hd), hl		; Hyp.cls 554
            ld b, 4		; Hyp.cls 555
asm_1_282_n_cn_hc_out:		; Hyp.cls 556
            pop de		; Hyp.cls 557
            dec hl		; Hyp.cls 558
            ld (hl), d		; Hyp.cls 559
            dec hl		; Hyp.cls 560
            ld (hl), e		; Hyp.cls 561
            djnz asm_1_282_n_cn_hc_out		; Hyp.cls 562
            ld a, (asm_1_282_n_cn_hn)		; Hyp.cls 563
            dec a		; Hyp.cls 564
            jr nz, asm_1_282_n_cn_hc_lp		; Hyp.cls 565
            ld bc, (asm_1_282_n_cn_pg)		; Hyp.cls 566
            out (c), c		; Hyp.cls 567
            ret		; Hyp.cls 568
asm_1_282_n_cn_hget:                            ; A = a line of the history (0 the oldest kept): copied to [569]
            ld hl, #7F24            ; #FF30 in the slot's page (HL) [570]
            add a, (hl)		; Hyp.cls 571
            inc hl		; Hyp.cls 572
            sub (hl)		; Hyp.cls 573
            jr nc, asm_1_282_n_cn_hg_r		; Hyp.cls 574
            add a, asm_1_282_n_HROWS		; Hyp.cls 575
asm_1_282_n_cn_hg_r:		; Hyp.cls 576
            call asm_1_282_n_cn_haddr		; Hyp.cls 577
            ld (asm_1_282_n_cn_hs), hl		; Hyp.cls 578
            ld hl, (#7F20)		; Hyp.cls 579
            ld (asm_1_282_n_cn_h1), hl		; Hyp.cls 580
            ld hl, (asm_1_282_n_cn_pg)		; Hyp.cls 581
            ld (asm_1_282_n_cn_h2), hl		; Hyp.cls 582
            ld hl, #7F30		; Hyp.cls 583
            ld (asm_1_282_n_cn_hd), hl		; Hyp.cls 584
            call asm_1_282_n_cn_hcp		; Hyp.cls 585
            ld hl, #7F30		; Hyp.cls 586
            ret		; Hyp.cls 587
asm_1_282_n_cn_haddr:                           ; A = a history row: HL = its address in the history page [588]
            ld e, a		; Hyp.cls 589
            ld a, asm_1_282_n_HW		; Hyp.cls 590
            call asm_1_282_n_cn_mul		; Hyp.cls 591
            ld de, (#7F22)		; Hyp.cls 592
            add hl, de		; Hyp.cls 593
            ret		; Hyp.cls 594
; cn_cls: the screen cleared (written only: the Library: ROM build's keyword ROM may be over it)
asm_1_282_n_cn_cls:		; Hyp.cls 596
            ld hl, #C000		; Hyp.cls 597
            ld bc, #4000		; Hyp.cls 598
asm_1_282_n_cn_cl_lp:		; Hyp.cls 599
            ld (hl), 0		; Hyp.cls 600
            inc hl		; Hyp.cls 601
            dec bc		; Hyp.cls 602
            ld a, b		; Hyp.cls 603
            or c		; Hyp.cls 604
            jr nz, asm_1_282_n_cn_cl_lp		; Hyp.cls 605
            ret		; Hyp.cls 606
            ENDIF		; Hyp.cls 607

; cn_char: A = one character
asm_1_282_n_cn_char:		; Hyp.cls 610
            ld b, a		; Hyp.cls 611
            ld a, (#7685)           ; in an escape sequence? [612]
            or a		; Hyp.cls 613
            jr nz, asm_1_282_n_cn_esc0		; Hyp.cls 614
            ld a, b		; Hyp.cls 615
            cp 32		; Hyp.cls 616
            jp nc, asm_1_282_n_cn_print		; Hyp.cls 617
            ld hl, asm_1_282_n_cn_pv            ; a control code: the cursor may move (the pointers redone) [618]
            ld (hl), 0		; Hyp.cls 619
            cp 27		; Hyp.cls 620
            jr z, asm_1_282_n_cn_setesc		; Hyp.cls 621
            cp 13		; Hyp.cls 622
            jr z, asm_1_282_n_cn_cr		; Hyp.cls 623
            cp 10		; Hyp.cls 624
            jp z, asm_1_282_n_cn_nl		; Hyp.cls 625
            cp 9		; Hyp.cls 626
            jr z, asm_1_282_n_cn_tab		; Hyp.cls 627
            cp 8		; Hyp.cls 628
            ret nz                  ; other control codes: nothing [629]
            ld a, (#7682)           ; BS: back one (not past the start of the row) [630]
            or a		; Hyp.cls 631
            ret z		; Hyp.cls 632
            dec a		; Hyp.cls 633
            ld (#7682), a		; Hyp.cls 634
            ret		; Hyp.cls 635
asm_1_282_n_cn_tab:                             ; TAB: spaces to the next column of 8 [636]
            ld b, ' '		; Hyp.cls 637
            call asm_1_282_n_cn_print		; Hyp.cls 638
            ld a, (#7682)		; Hyp.cls 639
            and 7		; Hyp.cls 640
            jr nz, asm_1_282_n_cn_tab		; Hyp.cls 641
            ret		; Hyp.cls 642
asm_1_282_n_cn_setesc:		; Hyp.cls 643
            ld a, 1		; Hyp.cls 644
            ld (#7685), a		; Hyp.cls 645
            ret		; Hyp.cls 646
asm_1_282_n_cn_cr:		; Hyp.cls 647
            xor a		; Hyp.cls 648
            ld (#7682), a		; Hyp.cls 649
            ret		; Hyp.cls 650
asm_1_282_n_cn_esc0:		; Hyp.cls 651
            ld hl, asm_1_282_n_cn_pv		; Hyp.cls 652
            ld (hl), 0		; Hyp.cls 653
asm_1_282_n_cn_esc:		; Hyp.cls 654
            cp 1		; Hyp.cls 655
            jr nz, asm_1_282_n_cn_esc2		; Hyp.cls 656
            xor a                   ; ESC x [657]
            ld (#7685), a		; Hyp.cls 658
            ld a, b		; Hyp.cls 659
            cp 'E'		; Hyp.cls 660
            jp z, asm_1_282_n_cn_clear		; Hyp.cls 661
            cp 'H'		; Hyp.cls 662
            jr z, asm_1_282_n_cn_home		; Hyp.cls 663
            cp 'I'		; Hyp.cls 664
            jp z, asm_1_282_n_cn_rev		; Hyp.cls 665
            cp 'Y'		; Hyp.cls 666
            jr z, asm_1_282_n_cn_sety		; Hyp.cls 667
            cp 'A'		; Hyp.cls 668
            jr z, asm_1_282_n_cn_up		; Hyp.cls 669
            cp 'B'		; Hyp.cls 670
            jr z, asm_1_282_n_cn_down		; Hyp.cls 671
            cp 'C'		; Hyp.cls 672
            jr z, asm_1_282_n_cn_right		; Hyp.cls 673
            cp 'D'		; Hyp.cls 674
            jr z, asm_1_282_n_cn_lft		; Hyp.cls 675
            cp 'K'		; Hyp.cls 676
            jp z, asm_1_282_n_cn_eol		; Hyp.cls 677
            cp 'J'		; Hyp.cls 678
            jp z, asm_1_282_n_cn_eos		; Hyp.cls 679
            cp 'l'		; Hyp.cls 680
            jp z, asm_1_282_n_cn_eln		; Hyp.cls 681
            cp 'o'		; Hyp.cls 682
            jp z, asm_1_282_n_cn_sol		; Hyp.cls 683
            cp 'd'		; Hyp.cls 684
            jp z, asm_1_282_n_cn_sos		; Hyp.cls 685
            cp 'M'		; Hyp.cls 686
            jp z, asm_1_282_n_cn_dell		; Hyp.cls 687
            cp 'L'		; Hyp.cls 688
            jp z, asm_1_282_n_cn_insl		; Hyp.cls 689
            ret                     ; (the rest - e f j k p q ...: nothing) [690]
asm_1_282_n_cn_sety:		; Hyp.cls 691
            ld a, 2		; Hyp.cls 692
            ld (#7685), a		; Hyp.cls 693
            ret		; Hyp.cls 694
asm_1_282_n_cn_up:                              ; ESC A, B, C, D: up, down, right, left (not past the edge) [695]
            ld hl, #7683		; Hyp.cls 696
            jr asm_1_282_n_cn_dec		; Hyp.cls 697
asm_1_282_n_cn_lft:		; Hyp.cls 698
            ld hl, #7682		; Hyp.cls 699
asm_1_282_n_cn_dec:		; Hyp.cls 700
            ld a, (hl)		; Hyp.cls 701
            or a		; Hyp.cls 702
            ret z		; Hyp.cls 703
            dec (hl)		; Hyp.cls 704
            ret		; Hyp.cls 705
asm_1_282_n_cn_down:		; Hyp.cls 706
            ld de, #7683		; Hyp.cls 707
            ld hl, asm_1_282_n_cn_r		; Hyp.cls 708
            jr asm_1_282_n_cn_inc		; Hyp.cls 709
asm_1_282_n_cn_right:		; Hyp.cls 710
            ld de, #7682		; Hyp.cls 711
            ld hl, asm_1_282_n_cn_c		; Hyp.cls 712
asm_1_282_n_cn_inc:		; Hyp.cls 713
            ld a, (de)		; Hyp.cls 714
            inc a		; Hyp.cls 715
            cp (hl)		; Hyp.cls 716
            ret nc		; Hyp.cls 717
            ld (de), a		; Hyp.cls 718
            ret		; Hyp.cls 719
asm_1_282_n_cn_home:		; Hyp.cls 720
            xor a		; Hyp.cls 721
            ld (#7682), a		; Hyp.cls 722
            ld (#7683), a		; Hyp.cls 723
            ret		; Hyp.cls 724
asm_1_282_n_cn_esc2:		; Hyp.cls 725
            cp 2		; Hyp.cls 726
            jr nz, asm_1_282_n_cn_esc3		; Hyp.cls 727
            ld a, b                 ; ESC Y row [728]
            sub 32		; Hyp.cls 729
            ld (#7686), a		; Hyp.cls 730
            ld a, 3		; Hyp.cls 731
            ld (#7685), a		; Hyp.cls 732
            ret		; Hyp.cls 733
asm_1_282_n_cn_esc3:		; Hyp.cls 734
            xor a                   ; ESC Y row col [735]
            ld (#7685), a		; Hyp.cls 736
            ld a, b		; Hyp.cls 737
            sub 32		; Hyp.cls 738
            ld hl, asm_1_282_n_cn_c		; Hyp.cls 739
            cp (hl)		; Hyp.cls 740
            jr c, asm_1_282_n_cn_e3_col		; Hyp.cls 741
            xor a		; Hyp.cls 742
asm_1_282_n_cn_e3_col:		; Hyp.cls 743
            ld (#7682), a		; Hyp.cls 744
            ld a, (#7686)		; Hyp.cls 745
            ld hl, asm_1_282_n_cn_r		; Hyp.cls 746
            cp (hl)		; Hyp.cls 747
            jr c, asm_1_282_n_cn_e3_row		; Hyp.cls 748
            xor a		; Hyp.cls 749
asm_1_282_n_cn_e3_row:		; Hyp.cls 750
            ld (#7683), a		; Hyp.cls 751
            ret		; Hyp.cls 752

; a printable character (B): into the page, on the screen if in front, the column on. The page
; and screen pointers are worked out at the first character after the cursor moved (cn_pv 0),
; then just stepped on - a run of characters costs the 8 screen bytes each, not a sum each
asm_1_282_n_cn_print:		; Hyp.cls 757
            ld a, (asm_1_282_n_cn_pv)		; Hyp.cls 758
            or a		; Hyp.cls 759
            jr nz, asm_1_282_n_cn_pr_have		; Hyp.cls 760
            ld a, (#7683)		; Hyp.cls 761
            call asm_1_282_n_cn_rowa		; Hyp.cls 762
            ld a, (#7682)		; Hyp.cls 763
            ld e, a		; Hyp.cls 764
            ld d, 0		; Hyp.cls 765
            add hl, de		; Hyp.cls 766
            ld (asm_1_282_n_cn_pp), hl		; Hyp.cls 767
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 768
            or a		; Hyp.cls 769
            jr z, asm_1_282_n_cn_pr_set		; Hyp.cls 770
            ld a, (#7682)		; Hyp.cls 771
            ld d, a		; Hyp.cls 772
            ld a, (#7683)		; Hyp.cls 773
            ld e, a		; Hyp.cls 774
            push bc                 ; (B: the character) [775]
            call asm_1_282_n_cn_scr		; Hyp.cls 776
            pop bc		; Hyp.cls 777
            ld (asm_1_282_n_cn_sp), hl		; Hyp.cls 778
asm_1_282_n_cn_pr_set:		; Hyp.cls 779
            ld a, 1		; Hyp.cls 780
            ld (asm_1_282_n_cn_pv), a		; Hyp.cls 781
asm_1_282_n_cn_pr_have:		; Hyp.cls 782
            ld hl, (asm_1_282_n_cn_pp)          ; the page [783]
            ld (hl), b		; Hyp.cls 784
            inc hl		; Hyp.cls 785
            ld (asm_1_282_n_cn_pp), hl		; Hyp.cls 786
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 787
            or a		; Hyp.cls 788
            jr z, asm_1_282_n_cn_pr_adv		; Hyp.cls 789
            ld hl, (asm_1_282_n_cn_sp)          ; the screen [790]
            push hl		; Hyp.cls 791
            ld a, b		; Hyp.cls 792
            call asm_1_282_n_cn_glyph8		; Hyp.cls 793
            pop hl		; Hyp.cls 794
            call asm_1_282_n_cn_next		; Hyp.cls 795
            ld (asm_1_282_n_cn_sp), hl		; Hyp.cls 796
asm_1_282_n_cn_pr_adv:		; Hyp.cls 797
            ld hl, #7682		; Hyp.cls 798
            inc (hl)		; Hyp.cls 799
            ld a, (hl)		; Hyp.cls 800
            ld hl, asm_1_282_n_cn_c		; Hyp.cls 801
            cp (hl)		; Hyp.cls 802
            ret c		; Hyp.cls 803
            xor a                   ; past the last column: the next row [804]
            ld (#7682), a		; Hyp.cls 805
            ld (asm_1_282_n_cn_pv), a		; Hyp.cls 806
; a line feed: the next row, or the page (and the screen) scroll
asm_1_282_n_cn_nl:		; Hyp.cls 808
            ld a, (#7683)		; Hyp.cls 809
            inc a		; Hyp.cls 810
            ld hl, asm_1_282_n_cn_r		; Hyp.cls 811
            cp (hl)		; Hyp.cls 812
            jr nc, asm_1_282_n_cn_scroll		; Hyp.cls 813
            ld (#7683), a		; Hyp.cls 814
            ret		; Hyp.cls 815
asm_1_282_n_cn_scroll:		; Hyp.cls 816
            ld a, (#7684)           ; the ring's top row moves on (no copy) [817]
            inc a		; Hyp.cls 818
            cp (hl)		; Hyp.cls 819
            jr c, asm_1_282_n_cn_sc_top		; Hyp.cls 820
            xor a		; Hyp.cls 821
asm_1_282_n_cn_sc_top:		; Hyp.cls 822
            ld (#7684), a		; Hyp.cls 823
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 824
            dec a		; Hyp.cls 825
            call asm_1_282_n_cn_rowa            ; the new last row cleared (the old top row: kept first) [826]
            IF asm_1_282_n_CN_SB		; Hyp.cls 827
            push hl		; Hyp.cls 828
            call asm_1_282_n_cn_hput		; Hyp.cls 829
            pop hl		; Hyp.cls 830
            ENDIF		; Hyp.cls 831
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 832
            ld b, a		; Hyp.cls 833
asm_1_282_n_cn_sc_cl:		; Hyp.cls 834
            ld (hl), ' '		; Hyp.cls 835
            inc hl		; Hyp.cls 836
            djnz asm_1_282_n_cn_sc_cl		; Hyp.cls 837
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 838
            or a		; Hyp.cls 839
            ret z		; Hyp.cls 840
            ld hl, (var_hyp_sco)          ; the screen: its start a row on (R12, R13), the new last row [841]
            ld de, (var_hyp_scc)          ; cleared, the status strip again (it went off the top) [842]
            add hl, de		; Hyp.cls 843
            ld a, h		; Hyp.cls 844
            and #07		; Hyp.cls 845
            ld h, a		; Hyp.cls 846
            ld (var_hyp_sco), hl		; Hyp.cls 847
            call asm_1_282_n_cn_crtc		; Hyp.cls 848
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 849
            dec a		; Hyp.cls 850
            ld e, a		; Hyp.cls 851
asm_1_282_n_cn_sc_clr:                          ; E = a screen row: cleared, then the status strip again [852]
            ld d, 0		; Hyp.cls 853
            call asm_1_282_n_cn_scr		; Hyp.cls 854
            ld b, 8		; Hyp.cls 855
asm_1_282_n_cn_sc_ln:		; Hyp.cls 856
            push bc		; Hyp.cls 857
            push hl		; Hyp.cls 858
            ld a, (var_hyp_scc)		; Hyp.cls 859
            ld b, a		; Hyp.cls 860
asm_1_282_n_cn_sc_b:		; Hyp.cls 861
            ld (hl), 0		; Hyp.cls 862
            call asm_1_282_n_cn_next		; Hyp.cls 863
            djnz asm_1_282_n_cn_sc_b		; Hyp.cls 864
            pop hl		; Hyp.cls 865
            ld a, h		; Hyp.cls 866
            add a, 8		; Hyp.cls 867
            ld h, a		; Hyp.cls 868
            pop bc		; Hyp.cls 869
            djnz asm_1_282_n_cn_sc_ln		; Hyp.cls 870
            jp asm_1_282_n_cn_strip		; Hyp.cls 871

; ESC I (reverse line feed): the row before, or on the top row the page (and the screen) scroll
; back: the ring's top row a row back, the new top row cleared; on the screen its start a row
; back (R12, R13) and the new top row cleared - the line feed's scroll the other way
asm_1_282_n_cn_rev:		; Hyp.cls 876
            ld a, (#7683)		; Hyp.cls 877
            or a		; Hyp.cls 878
            jr z, asm_1_282_n_cn_rv_sc		; Hyp.cls 879
            dec a		; Hyp.cls 880
            ld (#7683), a		; Hyp.cls 881
            ret		; Hyp.cls 882
asm_1_282_n_cn_rv_sc:		; Hyp.cls 883
            ld a, (#7684)		; Hyp.cls 884
            or a		; Hyp.cls 885
            jr nz, asm_1_282_n_cn_rv_top		; Hyp.cls 886
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 887
asm_1_282_n_cn_rv_top:		; Hyp.cls 888
            dec a		; Hyp.cls 889
            ld (#7684), a		; Hyp.cls 890
            xor a		; Hyp.cls 891
            call asm_1_282_n_cn_rowa            ; (row 0 of the page now) [892]
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 893
            ld b, a		; Hyp.cls 894
asm_1_282_n_cn_rv_cl:		; Hyp.cls 895
            ld (hl), ' '		; Hyp.cls 896
            inc hl		; Hyp.cls 897
            djnz asm_1_282_n_cn_rv_cl		; Hyp.cls 898
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 899
            or a		; Hyp.cls 900
            ret z		; Hyp.cls 901
            ld hl, (var_hyp_sco)		; Hyp.cls 902
            ld de, (var_hyp_scc)		; Hyp.cls 903
            or a		; Hyp.cls 904
            sbc hl, de		; Hyp.cls 905
            ld a, h		; Hyp.cls 906
            and #07		; Hyp.cls 907
            ld h, a		; Hyp.cls 908
            ld (var_hyp_sco), hl		; Hyp.cls 909
            call asm_1_282_n_cn_crtc		; Hyp.cls 910
            ld e, 0		; Hyp.cls 911
            jp asm_1_282_n_cn_sc_clr		; Hyp.cls 912

; ESC K the row from the cursor on cleared, J the rest of the page too, l the whole row, o the
; row up to the cursor, d the page up to it; M the cursor's row deleted (those below up a row, a
; blank one at the end), L a blank one put in (those below down, the last gone) - the column 0.
; The page changed first, then its rows drawn again on the screen when in front
asm_1_282_n_cn_eol:		; Hyp.cls 918
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 919
            ld hl, #7682		; Hyp.cls 920
            sub (hl)		; Hyp.cls 921
            ld b, a		; Hyp.cls 922
            ld d, (hl)		; Hyp.cls 923
            ld a, (#7683)		; Hyp.cls 924
            ld e, a		; Hyp.cls 925
            jp asm_1_282_n_cn_wipen		; Hyp.cls 926
asm_1_282_n_cn_eos:		; Hyp.cls 927
            call asm_1_282_n_cn_eol		; Hyp.cls 928
            ld a, (#7683)		; Hyp.cls 929
asm_1_282_n_cn_eos_lp:		; Hyp.cls 930
            inc a		; Hyp.cls 931
            ld hl, asm_1_282_n_cn_r		; Hyp.cls 932
            cp (hl)		; Hyp.cls 933
            ret nc		; Hyp.cls 934
            push af		; Hyp.cls 935
            ld e, a		; Hyp.cls 936
            call asm_1_282_n_cn_wrow		; Hyp.cls 937
            pop af		; Hyp.cls 938
            jr asm_1_282_n_cn_eos_lp		; Hyp.cls 939
asm_1_282_n_cn_eln:		; Hyp.cls 940
            ld a, (#7683)		; Hyp.cls 941
            ld e, a		; Hyp.cls 942
            jp asm_1_282_n_cn_wrow		; Hyp.cls 943
asm_1_282_n_cn_sol:		; Hyp.cls 944
            ld a, (#7682)		; Hyp.cls 945
            inc a		; Hyp.cls 946
            ld b, a		; Hyp.cls 947
            ld d, 0		; Hyp.cls 948
            ld a, (#7683)		; Hyp.cls 949
            ld e, a		; Hyp.cls 950
            jp asm_1_282_n_cn_wipen		; Hyp.cls 951
asm_1_282_n_cn_sos:		; Hyp.cls 952
            call asm_1_282_n_cn_sol		; Hyp.cls 953
            ld a, (#7683)		; Hyp.cls 954
asm_1_282_n_cn_sos_lp:		; Hyp.cls 955
            or a		; Hyp.cls 956
            ret z		; Hyp.cls 957
            dec a		; Hyp.cls 958
            push af		; Hyp.cls 959
            ld e, a		; Hyp.cls 960
            call asm_1_282_n_cn_wrow		; Hyp.cls 961
            pop af		; Hyp.cls 962
            jr asm_1_282_n_cn_sos_lp		; Hyp.cls 963
asm_1_282_n_cn_dell:		; Hyp.cls 964
            xor a		; Hyp.cls 965
            ld (#7682), a		; Hyp.cls 966
            ld a, (#7683)		; Hyp.cls 967
            ld b, a                 ; B: the row filled from the one below [968]
asm_1_282_n_cn_dl_lp:		; Hyp.cls 969
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 970
            dec a		; Hyp.cls 971
            cp b		; Hyp.cls 972
            jr z, asm_1_282_n_cn_dl_end		; Hyp.cls 973
            ld c, b		; Hyp.cls 974
            inc c		; Hyp.cls 975
            ld a, b		; Hyp.cls 976
            push bc		; Hyp.cls 977
            call asm_1_282_n_cn_cpr		; Hyp.cls 978
            pop bc		; Hyp.cls 979
            inc b		; Hyp.cls 980
            jr asm_1_282_n_cn_dl_lp		; Hyp.cls 981
asm_1_282_n_cn_dl_end:		; Hyp.cls 982
            ld e, b		; Hyp.cls 983
            call asm_1_282_n_cn_wrow            ; the last row blank [984]
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 985
            dec a		; Hyp.cls 986
            ld c, a		; Hyp.cls 987
            ld a, (#7683)		; Hyp.cls 988
            jr asm_1_282_n_cn_redr		; Hyp.cls 989
asm_1_282_n_cn_insl:		; Hyp.cls 990
            xor a		; Hyp.cls 991
            ld (#7682), a		; Hyp.cls 992
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 993
            dec a		; Hyp.cls 994
            ld b, a                 ; B: the row filled from the one above [995]
asm_1_282_n_cn_il_lp:		; Hyp.cls 996
            ld a, (#7683)		; Hyp.cls 997
            cp b		; Hyp.cls 998
            jr z, asm_1_282_n_cn_il_end		; Hyp.cls 999
            ld c, b		; Hyp.cls 1000
            dec c		; Hyp.cls 1001
            ld a, b		; Hyp.cls 1002
            push bc		; Hyp.cls 1003
            call asm_1_282_n_cn_cpr		; Hyp.cls 1004
            pop bc		; Hyp.cls 1005
            dec b		; Hyp.cls 1006
            jr asm_1_282_n_cn_il_lp		; Hyp.cls 1007
asm_1_282_n_cn_il_end:		; Hyp.cls 1008
            ld e, b		; Hyp.cls 1009
            call asm_1_282_n_cn_wrow            ; the cursor's row blank [1010]
            ld a, (asm_1_282_n_cn_r)		; Hyp.cls 1011
            ld c, a		; Hyp.cls 1012
            ld a, (#7683)		; Hyp.cls 1013
            inc a		; Hyp.cls 1014
; cn_redr: rows A to C - 1 drawn again from the page
asm_1_282_n_cn_redr:		; Hyp.cls 1016
            cp c		; Hyp.cls 1017
            ret nc		; Hyp.cls 1018
            push af		; Hyp.cls 1019
            push bc		; Hyp.cls 1020
            ld e, a		; Hyp.cls 1021
            ld d, 0		; Hyp.cls 1022
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 1023
            ld b, a		; Hyp.cls 1024
            call asm_1_282_n_cn_drwn		; Hyp.cls 1025
            pop bc		; Hyp.cls 1026
            pop af		; Hyp.cls 1027
            inc a		; Hyp.cls 1028
            jr asm_1_282_n_cn_redr		; Hyp.cls 1029
; cn_cpr: the page's row C copied to its row A
asm_1_282_n_cn_cpr:		; Hyp.cls 1031
            push af		; Hyp.cls 1032
            ld a, c		; Hyp.cls 1033
            call asm_1_282_n_cn_rowa		; Hyp.cls 1034
            pop af		; Hyp.cls 1035
            push hl		; Hyp.cls 1036
            call asm_1_282_n_cn_rowa		; Hyp.cls 1037
            ex de, hl		; Hyp.cls 1038
            pop hl		; Hyp.cls 1039
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 1040
            ld c, a		; Hyp.cls 1041
            ld b, 0		; Hyp.cls 1042
            ldir		; Hyp.cls 1043
            ret		; Hyp.cls 1044
; cn_wrow: row E blank; cn_wipen: B characters of row E from column D blank (B > 0) - in the page,
; then drawn (cn_drwn: B characters of row E from column D, from the page, when in front)
asm_1_282_n_cn_wrow:		; Hyp.cls 1047
            ld d, 0		; Hyp.cls 1048
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 1049
            ld b, a		; Hyp.cls 1050
asm_1_282_n_cn_wipen:		; Hyp.cls 1051
            push de		; Hyp.cls 1052
            push bc		; Hyp.cls 1053
            ld a, e		; Hyp.cls 1054
            call asm_1_282_n_cn_rowa		; Hyp.cls 1055
            pop bc		; Hyp.cls 1056
            pop de		; Hyp.cls 1057
            push bc		; Hyp.cls 1058
            ld a, l		; Hyp.cls 1059
            add a, d		; Hyp.cls 1060
            ld l, a		; Hyp.cls 1061
            jr nc, asm_1_282_n_cn_wn_lp		; Hyp.cls 1062
            inc h		; Hyp.cls 1063
asm_1_282_n_cn_wn_lp:		; Hyp.cls 1064
            ld (hl), ' '		; Hyp.cls 1065
            inc hl		; Hyp.cls 1066
            djnz asm_1_282_n_cn_wn_lp		; Hyp.cls 1067
            pop bc		; Hyp.cls 1068
asm_1_282_n_cn_drwn:		; Hyp.cls 1069
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 1070
            or a		; Hyp.cls 1071
            ret z		; Hyp.cls 1072
            push de		; Hyp.cls 1073
            push bc		; Hyp.cls 1074
            ld a, e		; Hyp.cls 1075
            call asm_1_282_n_cn_rowa		; Hyp.cls 1076
            pop bc		; Hyp.cls 1077
            pop de		; Hyp.cls 1078
            ld a, l		; Hyp.cls 1079
            add a, d		; Hyp.cls 1080
            ld l, a		; Hyp.cls 1081
            jr nc, asm_1_282_n_cn_dw_p		; Hyp.cls 1082
            inc h		; Hyp.cls 1083
asm_1_282_n_cn_dw_p:                            ; the screen address worked out once, then stepped on (as [1084]
            push hl                 ; cn_print: a sum each character was a fifth of the time [1085]
            push bc                 ; a screen of text took - ESC K's) [1086]
            call asm_1_282_n_cn_scr		; Hyp.cls 1087
            pop bc		; Hyp.cls 1088
            pop de                  ; DE: the page's characters, HL the screen [1089]
asm_1_282_n_cn_dw_lp:		; Hyp.cls 1090
            ld a, (de)		; Hyp.cls 1091
            inc de		; Hyp.cls 1092
            push hl		; Hyp.cls 1093
            push de		; Hyp.cls 1094
            push bc		; Hyp.cls 1095
            call asm_1_282_n_cn_glyph8		; Hyp.cls 1096
            pop bc		; Hyp.cls 1097
            pop de		; Hyp.cls 1098
            pop hl		; Hyp.cls 1099
            call asm_1_282_n_cn_next		; Hyp.cls 1100
            djnz asm_1_282_n_cn_dw_lp		; Hyp.cls 1101
            ret		; Hyp.cls 1102

; ESC E: the page cleared, column, row and ring back to 0; the screen too if in front (written,
; not copied: the Library: ROM build may have the keyword ROM over it for reads)
asm_1_282_n_cn_clear:		; Hyp.cls 1106
            ld hl, #7700		; Hyp.cls 1107
            ld de, #7701		; Hyp.cls 1108
            ld (hl), ' '		; Hyp.cls 1109
            ld bc, 2047		; Hyp.cls 1110
            ldir		; Hyp.cls 1111
            xor a		; Hyp.cls 1112
            ld (#7682), a		; Hyp.cls 1113
            ld (#7683), a		; Hyp.cls 1114
            ld (#7684), a		; Hyp.cls 1115
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 1116
            or a		; Hyp.cls 1117
            ret z		; Hyp.cls 1118
            ld hl, 0		; Hyp.cls 1119
            ld (var_hyp_sco), hl		; Hyp.cls 1120
            ld (var_hyp_pon), hl          ; (no pointer on the cleared screen) [1121]
            call asm_1_282_n_cn_crtc		; Hyp.cls 1122
            xor a		; Hyp.cls 1123
            ld hl, #C000		; Hyp.cls 1124
            ld c, #40		; Hyp.cls 1125
asm_1_282_n_cn_cl_l:		; Hyp.cls 1126
            ld b, 0		; Hyp.cls 1127
asm_1_282_n_cn_cl_b:		; Hyp.cls 1128
            ld (hl), a		; Hyp.cls 1129
            inc hl		; Hyp.cls 1130
            djnz asm_1_282_n_cn_cl_b		; Hyp.cls 1131
            dec c		; Hyp.cls 1132
            jr nz, asm_1_282_n_cn_cl_l		; Hyp.cls 1133
; cn_strip: MODE S (the screen wider than the console): the status strip's 4 characters (#F68A)
; at the top of the columns right of the console
asm_1_282_n_cn_strip:		; Hyp.cls 1136
            ld a, (asm_1_282_n_cn_front)		; Hyp.cls 1137
            or a		; Hyp.cls 1138
            ret z		; Hyp.cls 1139
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 1140
            ld d, a		; Hyp.cls 1141
            ld a, (var_hyp_scc)		; Hyp.cls 1142
            cp d		; Hyp.cls 1143
            ret z		; Hyp.cls 1144
            ret c		; Hyp.cls 1145
            ld e, 0		; Hyp.cls 1146
            ld hl, #768A		; Hyp.cls 1147
            ld b, 4		; Hyp.cls 1148
asm_1_282_n_cn_st_lp:		; Hyp.cls 1149
            ld a, (hl)		; Hyp.cls 1150
            push hl		; Hyp.cls 1151
            push de		; Hyp.cls 1152
            push bc		; Hyp.cls 1153
            call asm_1_282_n_cn_glyph		; Hyp.cls 1154
            pop bc		; Hyp.cls 1155
            pop de		; Hyp.cls 1156
            pop hl		; Hyp.cls 1157
            inc hl		; Hyp.cls 1158
            inc d		; Hyp.cls 1159
            djnz asm_1_282_n_cn_st_lp		; Hyp.cls 1160
            ret		; Hyp.cls 1161

; cn_crtc: the screen's start (sco, bytes) to the CRTC: R12 = #30 + its words' high 2 bits, R13
; the low 8 (#C000, MA10 / MA11 clear: kept within 2K, never the carry into the next 16K)
asm_1_282_n_cn_crtc:		; Hyp.cls 1165
            ld hl, (var_hyp_sco)		; Hyp.cls 1166
            srl h		; Hyp.cls 1167
            rr l		; Hyp.cls 1168
            ld a, h		; Hyp.cls 1169
            and 3		; Hyp.cls 1170
            or #30		; Hyp.cls 1171
            ld bc, #BC0C		; Hyp.cls 1172
            out (c), c		; Hyp.cls 1173
            inc b		; Hyp.cls 1174
            out (c), a		; Hyp.cls 1175
            ld bc, #BC0D		; Hyp.cls 1176
            out (c), c		; Hyp.cls 1177
            inc b		; Hyp.cls 1178
            out (c), l		; Hyp.cls 1179
            ret		; Hyp.cls 1180

; cn_rowa: A = row of the screen -> HL = its row in the page ring (#7700 + ((top + A) mod rows)
; * columns)
asm_1_282_n_cn_rowa:		; Hyp.cls 1184
            ld hl, #7684		; Hyp.cls 1185
            add a, (hl)		; Hyp.cls 1186
            ld hl, asm_1_282_n_cn_r		; Hyp.cls 1187
            cp (hl)		; Hyp.cls 1188
            jr c, asm_1_282_n_cn_ra_in		; Hyp.cls 1189
            sub (hl)		; Hyp.cls 1190
asm_1_282_n_cn_ra_in:		; Hyp.cls 1191
            ld e, a		; Hyp.cls 1192
            ld a, (asm_1_282_n_cn_c)		; Hyp.cls 1193
            call asm_1_282_n_cn_mul		; Hyp.cls 1194
            ld de, #7700		; Hyp.cls 1195
            add hl, de		; Hyp.cls 1196
            ret		; Hyp.cls 1197

; cn_mul: HL = A * E (BC kept; D = 0 after)
asm_1_282_n_cn_mul:		; Hyp.cls 1200
            push bc		; Hyp.cls 1201
            ld hl, 0		; Hyp.cls 1202
            ld d, 0		; Hyp.cls 1203
            ld b, 8		; Hyp.cls 1204
asm_1_282_n_cn_mu_lp:		; Hyp.cls 1205
            add hl, hl		; Hyp.cls 1206
            rlca		; Hyp.cls 1207
            jr nc, asm_1_282_n_cn_mu_n		; Hyp.cls 1208
            add hl, de		; Hyp.cls 1209
asm_1_282_n_cn_mu_n:		; Hyp.cls 1210
            djnz asm_1_282_n_cn_mu_lp		; Hyp.cls 1211
            pop bc		; Hyp.cls 1212
            ret		; Hyp.cls 1213

; cn_next: HL = the next screen byte: + 1 within its 2K line block (BC kept)
asm_1_282_n_cn_next:		; Hyp.cls 1216
            inc l		; Hyp.cls 1217
            ret nz		; Hyp.cls 1218
            ld a, h		; Hyp.cls 1219
            inc a		; Hyp.cls 1220
            and #07		; Hyp.cls 1221
            push bc		; Hyp.cls 1222
            ld c, a		; Hyp.cls 1223
            ld a, h		; Hyp.cls 1224
            and #F8		; Hyp.cls 1225
            or c		; Hyp.cls 1226
            ld h, a		; Hyp.cls 1227
            pop bc		; Hyp.cls 1228
            ret		; Hyp.cls 1229

; cn_glyph: A = character, D = column, E = row: drawn (cn_show)
asm_1_282_n_cn_glyph:		; Hyp.cls 1232
            push af		; Hyp.cls 1233
            call asm_1_282_n_cn_scr		; Hyp.cls 1234
            pop af		; Hyp.cls 1235
; cn_glyph8: A = character, HL = its screen address: its 8 bytes into screen memory (mode 2, pen
; 1 on paper 0), one per pixel line (#800 apart; unrolled)
asm_1_282_n_cn_glyph8:		; Hyp.cls 1238
            sub 32		; Hyp.cls 1239
            cp 96		; Hyp.cls 1240
            jr c, asm_1_282_n_cn_gl_ok		; Hyp.cls 1241
            ld a, '?' - 32		; Hyp.cls 1242
asm_1_282_n_cn_gl_ok:		; Hyp.cls 1243
            push hl		; Hyp.cls 1244
            ld l, a		; Hyp.cls 1245
            ld h, 0		; Hyp.cls 1246
            add hl, hl		; Hyp.cls 1247
            add hl, hl		; Hyp.cls 1248
            add hl, hl		; Hyp.cls 1249
            ld de, 62208 - #8000   ; (the bank's page 3 in the window: FONT - #C000 + #4000) [1250]
            add hl, de		; Hyp.cls 1251
            ex de, hl               ; DE = its matrix [1252]
            pop hl		; Hyp.cls 1253
            ld a, (de)		; Hyp.cls 1254
            ld (hl), a		; Hyp.cls 1255
            inc de		; Hyp.cls 1256
            ld a, h		; Hyp.cls 1257
            add a, 8		; Hyp.cls 1258
            ld h, a		; Hyp.cls 1259
            ld a, (de)		; Hyp.cls 1260
            ld (hl), a		; Hyp.cls 1261
            inc de		; Hyp.cls 1262
            ld a, h		; Hyp.cls 1263
            add a, 8		; Hyp.cls 1264
            ld h, a		; Hyp.cls 1265
            ld a, (de)		; Hyp.cls 1266
            ld (hl), a		; Hyp.cls 1267
            inc de		; Hyp.cls 1268
            ld a, h		; Hyp.cls 1269
            add a, 8		; Hyp.cls 1270
            ld h, a		; Hyp.cls 1271
            ld a, (de)		; Hyp.cls 1272
            ld (hl), a		; Hyp.cls 1273
            inc de		; Hyp.cls 1274
            ld a, h		; Hyp.cls 1275
            add a, 8		; Hyp.cls 1276
            ld h, a		; Hyp.cls 1277
            ld a, (de)		; Hyp.cls 1278
            ld (hl), a		; Hyp.cls 1279
            inc de		; Hyp.cls 1280
            ld a, h		; Hyp.cls 1281
            add a, 8		; Hyp.cls 1282
            ld h, a		; Hyp.cls 1283
            ld a, (de)		; Hyp.cls 1284
            ld (hl), a		; Hyp.cls 1285
            inc de		; Hyp.cls 1286
            ld a, h		; Hyp.cls 1287
            add a, 8		; Hyp.cls 1288
            ld h, a		; Hyp.cls 1289
            ld a, (de)		; Hyp.cls 1290
            ld (hl), a		; Hyp.cls 1291
            inc de		; Hyp.cls 1292
            ld a, h		; Hyp.cls 1293
            add a, 8		; Hyp.cls 1294
            ld h, a		; Hyp.cls 1295
            ld a, (de)		; Hyp.cls 1296
            ld (hl), a		; Hyp.cls 1297
            ret		; Hyp.cls 1298
; cn_scr: D = column, E = row -> HL = the screen address: the screen's start (sco) + row *
; columns (scc) + column, within each 2K line block, at #C000
asm_1_282_n_cn_scr:		; Hyp.cls 1301
            push de		; Hyp.cls 1302
            ld a, (var_hyp_scc)		; Hyp.cls 1303
            call asm_1_282_n_cn_mul		; Hyp.cls 1304
            pop de		; Hyp.cls 1305
            ld c, d		; Hyp.cls 1306
            ld b, 0		; Hyp.cls 1307
            add hl, bc		; Hyp.cls 1308
            ld bc, (var_hyp_sco)		; Hyp.cls 1309
            add hl, bc		; Hyp.cls 1310
            ld a, h		; Hyp.cls 1311
            and #07		; Hyp.cls 1312
            or #C0		; Hyp.cls 1313
            ld h, a		; Hyp.cls 1314
            ret		; Hyp.cls 1315
asm_1_282_n_cn_cuxor:                           ; the cursor's underline XORed at cn_ca, on <-> off [1316]
            ld hl, (asm_1_282_n_cn_ca)		; Hyp.cls 1317
            ld a, (hl)		; Hyp.cls 1318
            cpl		; Hyp.cls 1319
            ld (hl), a		; Hyp.cls 1320
            ld a, (var_hyp_ccu)		; Hyp.cls 1321
            xor 1		; Hyp.cls 1322
            ld (var_hyp_ccu), a		; Hyp.cls 1323
            ret		; Hyp.cls 1324
asm_1_282_n_cn_was:     db 0		; Hyp.cls 1325
asm_1_282_n_cn_ca:      dw 0		; Hyp.cls 1326
asm_1_282_n_cn_front:   db 0		; Hyp.cls 1327
asm_1_282_n_cn_c:       db 80                   ; the slot's columns, rows [1328]
asm_1_282_n_cn_r:       db 25		; Hyp.cls 1329
asm_1_282_n_cn_pv:      db 0                    ; cn_pp / cn_sp valid (0: the cursor moved) [1330]
asm_1_282_n_cn_pp:      dw 0                    ; the page byte for the next character [1331]
asm_1_282_n_cn_sp:      dw 0                    ; its screen address [1332]
asm_1_282_n_cn_left:    dw 0		; Hyp.cls 1333
asm_1_282_n_cn_ptr:     dw 0		; Hyp.cls 1334
            IF asm_1_282_n_CN_SB		; Hyp.cls 1335
asm_1_282_n_cn_pg:      dw 0                    ; the slot's page 3 setting (pg) [1336]
asm_1_282_n_cn_h1:      dw 0                    ; cn_hcp: from (its setting, address), to, 8-byte runs left [1337]
asm_1_282_n_cn_hs:      dw 0		; Hyp.cls 1338
asm_1_282_n_cn_h2:      dw 0		; Hyp.cls 1339
asm_1_282_n_cn_hd:      dw 0		; Hyp.cls 1340
asm_1_282_n_cn_hn:      db 0		; Hyp.cls 1341
            ENDIF		; Hyp.cls 1342
asm_1_282_n_cn_end:		; Hyp.cls 1343
			ret			; end of #asm

asm_1_1351_n:		; #asm, Hyp.cls line 1351 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 1352
            ld sp, (ntc_csp)		; Hyp.cls 1353
            ld bc, (var_hyp_hps)          ; the hypervisor's page in the window: the font [1354]
            out (c), c		; Hyp.cls 1355
            ld hl, (var_hyp_sco)          ; the screen's start (TOP is shown in MODE 2: 80 columns) [1356]
            ld (asm_1_1351_n_sy_off), hl		; Hyp.cls 1357
            ld hl, (var_hyp_say_p)		; Hyp.cls 1358
            ld a, (var_hyp_say_n)		; Hyp.cls 1359
            ld b, a		; Hyp.cls 1360
            ld a, (var_hyp_say_col)		; Hyp.cls 1361
            ld d, a		; Hyp.cls 1362
            ld a, (var_hyp_say_row)		; Hyp.cls 1363
            ld e, a		; Hyp.cls 1364
            inc b		; Hyp.cls 1365
asm_1_1351_n_sy_lp:		; Hyp.cls 1366
            dec b		; Hyp.cls 1367
            jr z, asm_1_1351_n_sy_done		; Hyp.cls 1368
            ld a, d		; Hyp.cls 1369
            cp 80		; Hyp.cls 1370
            jr nc, asm_1_1351_n_sy_done		; Hyp.cls 1371
            ld a, (hl)		; Hyp.cls 1372
            inc hl		; Hyp.cls 1373
            push hl		; Hyp.cls 1374
            push bc		; Hyp.cls 1375
            push de		; Hyp.cls 1376
            sub 32                  ; the character's matrix [1377]
            cp 96		; Hyp.cls 1378
            jr c, asm_1_1351_n_sy_ok		; Hyp.cls 1379
            ld a, '?' - 32		; Hyp.cls 1380
asm_1_1351_n_sy_ok:		; Hyp.cls 1381
            ld l, a		; Hyp.cls 1382
            ld h, 0		; Hyp.cls 1383
            add hl, hl		; Hyp.cls 1384
            add hl, hl		; Hyp.cls 1385
            add hl, hl		; Hyp.cls 1386
            ld bc, #4000 + 4096  ; (the hypervisor's page in the window) [1387]
            add hl, bc		; Hyp.cls 1388
            push hl		; Hyp.cls 1389
            ld l, e                 ; its screen address: start + row * 80 + column, in 2K [1390]
            ld h, 0		; Hyp.cls 1391
            add hl, hl		; Hyp.cls 1392
            add hl, hl		; Hyp.cls 1393
            add hl, hl		; Hyp.cls 1394
            add hl, hl		; Hyp.cls 1395
            push hl		; Hyp.cls 1396
            add hl, hl		; Hyp.cls 1397
            add hl, hl		; Hyp.cls 1398
            pop bc		; Hyp.cls 1399
            add hl, bc		; Hyp.cls 1400
            ld c, d		; Hyp.cls 1401
            ld b, 0		; Hyp.cls 1402
            add hl, bc		; Hyp.cls 1403
            ld bc, (asm_1_1351_n_sy_off)		; Hyp.cls 1404
            add hl, bc		; Hyp.cls 1405
            ld a, h		; Hyp.cls 1406
            and #07		; Hyp.cls 1407
            or #C0		; Hyp.cls 1408
            ld h, a		; Hyp.cls 1409
            pop de		; Hyp.cls 1410
            ld b, 8		; Hyp.cls 1411
asm_1_1351_n_sy_ln:		; Hyp.cls 1412
            ld a, (de)		; Hyp.cls 1413
            ld (hl), a		; Hyp.cls 1414
            inc de		; Hyp.cls 1415
            ld a, h		; Hyp.cls 1416
            add a, 8		; Hyp.cls 1417
            ld h, a		; Hyp.cls 1418
            djnz asm_1_1351_n_sy_ln		; Hyp.cls 1419
            pop de		; Hyp.cls 1420
            pop bc		; Hyp.cls 1421
            pop hl		; Hyp.cls 1422
            inc d		; Hyp.cls 1423
            jr asm_1_1351_n_sy_lp		; Hyp.cls 1424
asm_1_1351_n_sy_done:		; Hyp.cls 1425
            ld bc, (ntc_rampt)		; Hyp.cls 1426
            out (c), c		; Hyp.cls 1427
            ld sp, (var_hyp_hsp)		; Hyp.cls 1428
            jr asm_1_1351_n_sy_end		; Hyp.cls 1429
asm_1_1351_n_sy_off:     dw 0		; Hyp.cls 1430
asm_1_1351_n_sy_end:		; Hyp.cls 1431
			ret			; end of #asm

asm_1_1445_n:		; #asm, Hyp.cls line 1445 (normal)
            ld (var_hyp_hsp), sp          ; (the real stack: SP is the thread) [1446]
            ld sp, (ntc_csp)		; Hyp.cls 1447
            xor a		; Hyp.cls 1448
            ld (var_hyp_ccu), a           ; (the screen cleared: no cursor on it) [1449]
            ld a, (var_hyp_scr_m)		; Hyp.cls 1450
            cp 6		; Hyp.cls 1451
            jr c, asm_1_1445_n_sm_ok		; Hyp.cls 1452
            xor a		; Hyp.cls 1453
asm_1_1445_n_sm_ok:		; Hyp.cls 1454
            ld l, a                 ; the mode's row of the table (6 bytes) [1455]
            add a, a		; Hyp.cls 1456
            add a, l		; Hyp.cls 1457
            add a, a		; Hyp.cls 1458
            ld e, a		; Hyp.cls 1459
            ld d, 0		; Hyp.cls 1460
            ld hl, asm_1_1445_n_sm_tab		; Hyp.cls 1461
            add hl, de		; Hyp.cls 1462
            ld a, (var_hyp_scr_k)		; Hyp.cls 1463
            or a		; Hyp.cls 1464
            jr z, asm_1_1445_n_sm_cols		; Hyp.cls 1465
            dec a		; Hyp.cls 1466
            jr z, asm_1_1445_n_sm_rows		; Hyp.cls 1467
            push hl                 ; 2: the screen [1468]
            ld e, (hl)              ; its columns [1469]
            ld d, 0		; Hyp.cls 1470
            ld (var_hyp_scc), de		; Hyp.cls 1471
            srl e		; Hyp.cls 1472
            ld (var_hyp_scw), de		; Hyp.cls 1473
            ld hl, 0		; Hyp.cls 1474
            ld (var_hyp_sco), hl		; Hyp.cls 1475
            ld (var_hyp_pon), hl          ; (no pointer on the cleared screen) [1476]
            pop hl		; Hyp.cls 1477
            inc hl		; Hyp.cls 1478
            inc hl                  ; R1, R2, R6, R7 [1479]
            di		; Hyp.cls 1480
            ld d, 1		; Hyp.cls 1481
            call asm_1_1445_n_sm_crtc		; Hyp.cls 1482
            ld d, 2		; Hyp.cls 1483
            call asm_1_1445_n_sm_crtc		; Hyp.cls 1484
            ld d, 6		; Hyp.cls 1485
            call asm_1_1445_n_sm_crtc		; Hyp.cls 1486
            ld d, 7		; Hyp.cls 1487
            call asm_1_1445_n_sm_crtc		; Hyp.cls 1488
            ld hl, asm_1_1445_n_sm_start         ; R12, R13: #C000 [1489]
            ld d, 12		; Hyp.cls 1490
            call asm_1_1445_n_sm_crtc		; Hyp.cls 1491
            ld d, 13		; Hyp.cls 1492
            call asm_1_1445_n_sm_crtc		; Hyp.cls 1493
            xor a                   ; cleared (written, not copied: the Library: ROM build may [1494]
            ld hl, #C000            ; have the keyword ROM over it for reads) [1495]
            ld c, #40		; Hyp.cls 1496
asm_1_1445_n_sm_cl:		; Hyp.cls 1497
            ld b, 0		; Hyp.cls 1498
asm_1_1445_n_sm_cl1:		; Hyp.cls 1499
            ld (hl), a		; Hyp.cls 1500
            inc hl		; Hyp.cls 1501
            djnz asm_1_1445_n_sm_cl1		; Hyp.cls 1502
            dec c		; Hyp.cls 1503
            jr nz, asm_1_1445_n_sm_cl		; Hyp.cls 1504
            ld hl, 0		; Hyp.cls 1505
            jr asm_1_1445_n_sm_res		; Hyp.cls 1506
asm_1_1445_n_sm_cols:		; Hyp.cls 1507
            ld a, (hl)              ; the console's: the screen's, less the status strip's 4 (S) [1508]
            inc hl		; Hyp.cls 1509
            sub (hl)		; Hyp.cls 1510
            jr asm_1_1445_n_sm_a		; Hyp.cls 1511
asm_1_1445_n_sm_rows:		; Hyp.cls 1512
            inc hl		; Hyp.cls 1513
            inc hl		; Hyp.cls 1514
            inc hl		; Hyp.cls 1515
            inc hl		; Hyp.cls 1516
            ld a, (hl)		; Hyp.cls 1517
asm_1_1445_n_sm_a:		; Hyp.cls 1518
            ld l, a		; Hyp.cls 1519
            ld h, 0		; Hyp.cls 1520
asm_1_1445_n_sm_res:		; Hyp.cls 1521
            ld (var_hyp_scr_scr), hl		; Hyp.cls 1522
            ld sp, (var_hyp_hsp)		; Hyp.cls 1523
            ret                     ; (on with the thread) [1524]
asm_1_1445_n_sm_crtc:                            ; CRTC register D = (HL), HL on [1525]
            ld bc, #BC00		; Hyp.cls 1526
            out (c), d		; Hyp.cls 1527
            ld b, #BD		; Hyp.cls 1528
            ld a, (hl)		; Hyp.cls 1529
            out (c), a		; Hyp.cls 1530
            inc hl		; Hyp.cls 1531
            ret		; Hyp.cls 1532
asm_1_1445_n_sm_start:   db #30, 0		; Hyp.cls 1533
; columns, the status strip's, R1 (words a row), R2 (horizontal sync), R6 (rows), R7 (vertical sync)
asm_1_1445_n_sm_tab:     db 80, 0, 40, 46, 25, 30		; Hyp.cls 1535
            db 84, 4, 42, 47, 24, 30		; Hyp.cls 1536
            db 88, 0, 44, 48, 23, 29		; Hyp.cls 1537
            db 96, 0, 48, 50, 21, 28		; Hyp.cls 1538
            db 64, 0, 32, 42, 32, 34		; Hyp.cls 1539
            db 84, 0, 42, 47, 24, 30		; Hyp.cls 1540
			ret			; end of #asm

asm_1_1547_n:		; #asm, Hyp.cls line 1547 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 1548
            ld sp, (ntc_csp)		; Hyp.cls 1549
            call #BB42              ; KM GET DELAY: H the start delay, L the repeat [1550]
            di		; Hyp.cls 1551
            ld a, h		; Hyp.cls 1552
            call asm_1_1547_n_kr_mul		; Hyp.cls 1553
            ld h, a		; Hyp.cls 1554
            ld a, l		; Hyp.cls 1555
            call asm_1_1547_n_kr_mul		; Hyp.cls 1556
            ld l, a		; Hyp.cls 1557
            call #BB3F              ; KM SET DELAY [1558]
            di		; Hyp.cls 1559
            ld sp, (var_hyp_hsp)		; Hyp.cls 1560
            jr asm_1_1547_n_kr_end		; Hyp.cls 1561
asm_1_1547_n_kr_mul:                             ; A = A x f, 255 at most (0: 256 to the firmware - kept) [1562]
            or a		; Hyp.cls 1563
            ret z		; Hyp.cls 1564
            push hl		; Hyp.cls 1565
            ld e, a		; Hyp.cls 1566
            ld d, 0		; Hyp.cls 1567
            ld hl, 0		; Hyp.cls 1568
            ld a, (var_hyp_keyrep_f)		; Hyp.cls 1569
            ld b, a		; Hyp.cls 1570
asm_1_1547_n_kr_lp:		; Hyp.cls 1571
            add hl, de		; Hyp.cls 1572
            djnz asm_1_1547_n_kr_lp		; Hyp.cls 1573
            ld a, h		; Hyp.cls 1574
            or a		; Hyp.cls 1575
            ld a, l		; Hyp.cls 1576
            pop hl		; Hyp.cls 1577
            ret z		; Hyp.cls 1578
            ld a, 255		; Hyp.cls 1579
            ret		; Hyp.cls 1580
asm_1_1547_n_kr_end:		; Hyp.cls 1581
			ret			; end of #asm

asm_1_1611_n:		; #asm, Hyp.cls line 1611 (normal)
            ld (var_hyp_sps), sp		; Hyp.cls 1612
            ld sp, (ntc_csp)		; Hyp.cls 1613
            call #B903              ; KL U ROM DISABLE: the task's top 16K, not a ROM (Library: [1614]
            di                      ; ROM has the keyword ROM on), while it runs [1615]
            ld (var_hyp_rrom), a		; Hyp.cls 1616
            ld a, 6		; Hyp.cls 1617
            ld (var_hyp_slc), a		; Hyp.cls 1618
            ld a, 1                 ; from BASIC: it has taken the characters (Collected) [1619]
            ld (var_hyp_rclr), a		; Hyp.cls 1620
asm_1_1611_n_rn_again:		; Hyp.cls 1621
            push ix                 ; IX, IY and [1622]
            push iy		; Hyp.cls 1623
            db #08                  ; ex af, af': the alternate registers kept - the [1624]
            exx                     ; firmware's (BC' = its ROM / mode setting); a task [1625]
            push af                 ; may use them [1626]
            push bc		; Hyp.cls 1627
            push de		; Hyp.cls 1628
            push hl		; Hyp.cls 1629
            exx		; Hyp.cls 1630
            db #08		; Hyp.cls 1631
            ld hl, asm_1_1611_n_rn_back		; Hyp.cls 1632
            push hl                 ; where main RAM carries on [1633]
            ld (ntc_bk_sp), sp		; Hyp.cls 1634
            ld a, (var_hyp_rclr)		; Hyp.cls 1635
            ld e, a                 ; E = 1: the bank empties its characters out (BASIC has them) [1636]
            ld a, (var_hyp_ra)		; Hyp.cls 1637
            ld hl, (var_hyp_rhl)		; Hyp.cls 1638
            ld bc, (var_hyp_run_setting)		; Hyp.cls 1639
            jp ntc_bk_out           ; out (c), c: the task's bank; its #0046 lands it [1640]
asm_1_1611_n_rn_back:		; Hyp.cls 1641
            ld (var_hyp_rcnt), ix         ; the characters it collected (the stubs put them in IX) [1642]
            db #08                  ; ex af, af' [1643]
            exx		; Hyp.cls 1644
            pop hl                  ; the alternate registers back [1645]
            pop de		; Hyp.cls 1646
            pop bc		; Hyp.cls 1647
            pop af		; Hyp.cls 1648
            exx		; Hyp.cls 1649
            db #08		; Hyp.cls 1650
            pop iy		; Hyp.cls 1651
            pop ix		; Hyp.cls 1652
            push af                 ; carry: a BDOS call (A = C, DE = DE) [1653]
            push bc		; Hyp.cls 1654
            ld bc, (ntc_rampt)      ; the window's page back [1655]
            out (c), c		; Hyp.cls 1656
            pop bc		; Hyp.cls 1657
            pop af		; Hyp.cls 1658
            jr c, asm_1_1611_n_rn_far		; Hyp.cls 1659
            rst #38                 ; an interrupt stopped the task: the firmware's handler [1660]
            di		; Hyp.cls 1661
            ld hl, var_hyp_slc            ; a time slice is SLICE interrupts: until it is used up the [1662]
            dec (hl)                ; task carries on straight away (no trip through BASIC) [1663]
            jr z, asm_1_1611_n_rn_int		; Hyp.cls 1664
            ld a, (ntc_isldue)      ; ... unless an interrupt class (the system keys) is due [1665]
            or a		; Hyp.cls 1666
            jr nz, asm_1_1611_n_rn_int		; Hyp.cls 1667
            xor a                   ; its characters stay in its bank (and the count goes on) [1668]
            ld (var_hyp_rclr), a		; Hyp.cls 1669
            jp asm_1_1611_n_rn_again		; Hyp.cls 1670
asm_1_1611_n_rn_int:		; Hyp.cls 1671
            ld hl, 0		; Hyp.cls 1672
            jr asm_1_1611_n_rn_end		; Hyp.cls 1673
asm_1_1611_n_rn_far:		; Hyp.cls 1674
            ld (var_hyp_rfn), a		; Hyp.cls 1675
            ld (var_hyp_rde), de		; Hyp.cls 1676
            ld hl, 1		; Hyp.cls 1677
asm_1_1611_n_rn_end:		; Hyp.cls 1678
            ld (var_hyp_run_run), hl		; Hyp.cls 1679
            ld a, (var_hyp_rrom)		; Hyp.cls 1680
            call #B90C              ; KL ROM RESTORE [1681]
            di		; Hyp.cls 1682
            ld sp, (var_hyp_sps)		; Hyp.cls 1683

			ret			; end of #asm

fn_hyp_info:		; function info (asm keyword), Hyp.cls line 1693
            pop hl		; Hyp.cls 1694
            ld a, (hl)		; Hyp.cls 1695
            ld hl, fn_hyp_info_hi_p0		; Hyp.cls 1696
            or a		; Hyp.cls 1697
            jr z, fn_hyp_info_in_e		; Hyp.cls 1698
            ld hl, fn_hyp_info_hi_p0e - fn_hyp_info_hi_p0		; Hyp.cls 1699
            dec a		; Hyp.cls 1700
            jr z, fn_hyp_info_in_e		; Hyp.cls 1701
            ld hl, fn_hyp_info_sb_img		; Hyp.cls 1702
            dec a		; Hyp.cls 1703
            jr z, fn_hyp_info_in_e		; Hyp.cls 1704
            ld hl, fn_hyp_info_sb_end - fn_hyp_info_sb_start		; Hyp.cls 1705
            dec a		; Hyp.cls 1706
            jr z, fn_hyp_info_in_e		; Hyp.cls 1707
            ld hl, fn_hyp_info_sb_init		; Hyp.cls 1708
fn_hyp_info_in_e:		; Hyp.cls 1709
            ex de, hl		; Hyp.cls 1710
            pop hl		; Hyp.cls 1711
            ld (hl), e		; Hyp.cls 1712
            inc hl		; Hyp.cls 1713
            ld (hl), d		; Hyp.cls 1714
            ret		; Hyp.cls 1715

			ret			; end of #asm

asm_1_2284_n:		; #asm, Hyp.cls line 2284 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 2285
            ld sp, (ntc_csp)		; Hyp.cls 2286
            ld a, (var_hyp_vdu_on)		; Hyp.cls 2287
            or a		; Hyp.cls 2288
            jr z, asm_1_2284_n_vd_off		; Hyp.cls 2289
            call #BB54              ; TXT VDU ENABLE [2290]
            jr asm_1_2284_n_vd_done		; Hyp.cls 2291
asm_1_2284_n_vd_off:		; Hyp.cls 2292
            call #BB57              ; TXT VDU DISABLE [2293]
asm_1_2284_n_vd_done:		; Hyp.cls 2294
            di		; Hyp.cls 2295
            ld sp, (var_hyp_hsp)		; Hyp.cls 2296
			ret			; end of #asm

asm_1_2316_n:		; #asm, Hyp.cls line 2316 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 2317
            ld sp, (ntc_csp)		; Hyp.cls 2318
            ld (asm_1_2316_n_fl_ix), ix		; Hyp.cls 2319
            ld (asm_1_2316_n_fl_iy), iy		; Hyp.cls 2320
            ld a, 255		; Hyp.cls 2321
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 2322
            ld a, (var_hyp_filecall_slot)		; Hyp.cls 2323
            ld (asm_1_2316_n_fl_slot), a		; Hyp.cls 2324
            ld a, (var_hyp_filecall_f)		; Hyp.cls 2325
            cp 99		; Hyp.cls 2326
            jp z, asm_1_2316_n_fl_inst		; Hyp.cls 2327
            IF NTC_ROMLIB = 0		; Hyp.cls 2328
; the RAM discs' driver (RAMDISC.CYB's, in a page of its own at #4000) sees the call first:
; carry - it was one of its drives' (HL the answer), else on to the disc ROM. It gets IX = the
; call (f, fcb, slot, setting, dma, drive, buf; 100-105: drive = the hypervisor's drive), at
; #4003 a jump to fl_dx (its copies: it runs in the window, so can't switch it itself), at
; #4006 its page's RAM setting
            ASSERT var_hyp_filecall_buf - var_hyp_filecall_f = 12, "FileCall's parameters, one after another"		; Hyp.cls 2334
            ld a, (var_hyp_drs + 1)		; Hyp.cls 2335
            or a		; Hyp.cls 2336
            jr z, asm_1_2316_n_fl_nodrv		; Hyp.cls 2337
            di		; Hyp.cls 2338
            ld a, (var_hyp_filecall_f)		; Hyp.cls 2339
            cp 100		; Hyp.cls 2340
            jr c, asm_1_2316_n_fl_dr_go		; Hyp.cls 2341
            cp 106		; Hyp.cls 2342
            jr nc, asm_1_2316_n_fl_dr_go		; Hyp.cls 2343
            ld hl, (var_hyp_hdr)		; Hyp.cls 2344
            ld (var_hyp_filecall_drive), hl		; Hyp.cls 2345
asm_1_2316_n_fl_dr_go:		; Hyp.cls 2346
            ld bc, (var_hyp_drs)		; Hyp.cls 2347
            out (c), c		; Hyp.cls 2348
            ld hl, asm_1_2316_n_fl_dx		; Hyp.cls 2349
            ld (#4004), hl		; Hyp.cls 2350
            ld hl, (var_hyp_drs)		; Hyp.cls 2351
            ld (#4006), hl		; Hyp.cls 2352
            ld ix, var_hyp_filecall_f		; Hyp.cls 2353
            call #4000		; Hyp.cls 2354
            jr nc, asm_1_2316_n_fl_nodrv		; Hyp.cls 2355
            ld (asm_1_2316_n_fl_res16), hl		; Hyp.cls 2356
            ld a, 1		; Hyp.cls 2357
            ld (asm_1_2316_n_fl_r16), a		; Hyp.cls 2358
            jp asm_1_2316_n_fl_done		; Hyp.cls 2359
; fl_dx - A bytes (1-128) from HL to DE through dxb: IX = HL's RAM setting, IY = DE's (0:
; main RAM, no switch); the driver's page back in the window after. HL, DE on past them
asm_1_2316_n_fl_dx:		; Hyp.cls 2362
            ld (asm_1_2316_n_fl_dxn), a		; Hyp.cls 2363
            push de		; Hyp.cls 2364
            ld de, (var_hyp_dxb)		; Hyp.cls 2365
            push ix		; Hyp.cls 2366
            pop bc		; Hyp.cls 2367
            inc b		; Hyp.cls 2368
            dec b		; Hyp.cls 2369
            jr z, asm_1_2316_n_fl_dx1		; Hyp.cls 2370
            out (c), c		; Hyp.cls 2371
asm_1_2316_n_fl_dx1:		; Hyp.cls 2372
            ld c, a		; Hyp.cls 2373
            ld b, 0		; Hyp.cls 2374
            ldir		; Hyp.cls 2375
            pop de		; Hyp.cls 2376
            push hl		; Hyp.cls 2377
            push iy		; Hyp.cls 2378
            pop bc		; Hyp.cls 2379
            inc b		; Hyp.cls 2380
            dec b		; Hyp.cls 2381
            jr z, asm_1_2316_n_fl_dx2		; Hyp.cls 2382
            out (c), c		; Hyp.cls 2383
asm_1_2316_n_fl_dx2:		; Hyp.cls 2384
            ld hl, (var_hyp_dxb)		; Hyp.cls 2385
            ld a, (asm_1_2316_n_fl_dxn)		; Hyp.cls 2386
            ld c, a		; Hyp.cls 2387
            ld b, 0		; Hyp.cls 2388
            ldir		; Hyp.cls 2389
            pop hl		; Hyp.cls 2390
            ld bc, (var_hyp_drs)		; Hyp.cls 2391
            out (c), c		; Hyp.cls 2392
            ret		; Hyp.cls 2393
asm_1_2316_n_fl_dxn:     db 0		; Hyp.cls 2394
asm_1_2316_n_fl_nodrv:		; Hyp.cls 2395
            ENDIF		; Hyp.cls 2396
            di		; Hyp.cls 2397
            ld bc, (var_hyp_hps)          ; the rest runs in the hypervisor's page (window data from [2398]
            out (c), c              ; #5300: fp_go) [2399]
            call asm_1_2316_n_fp_go		; Hyp.cls 2400
            jp asm_1_2316_n_fl_done		; Hyp.cls 2401
; 99: the window data (#5300 to fp_end: the bank image, the page code) copied from main RAM's
; own #4000-#7FFF (where the file put it) into the hypervisor's page, through buf; once, at the
; start, before anything else uses main RAM's #4000-#7FFF
asm_1_2316_n_fl_inst:		; Hyp.cls 2405
            ld hl, #5300		; Hyp.cls 2406
asm_1_2316_n_fl_in_lp:		; Hyp.cls 2407
            push hl		; Hyp.cls 2408
            ld bc, #7FC0            ; main RAM's own [2409]
            out (c), c		; Hyp.cls 2410
            ld de, (var_hyp_filecall_buf)		; Hyp.cls 2411
            ld bc, 128		; Hyp.cls 2412
            ldir		; Hyp.cls 2413
            ld bc, (var_hyp_hps)		; Hyp.cls 2414
            out (c), c		; Hyp.cls 2415
            pop de		; Hyp.cls 2416
            push de		; Hyp.cls 2417
            ld hl, (var_hyp_filecall_buf)		; Hyp.cls 2418
            ld bc, 128		; Hyp.cls 2419
            ldir		; Hyp.cls 2420
            pop hl		; Hyp.cls 2421
            ld bc, 128		; Hyp.cls 2422
            add hl, bc		; Hyp.cls 2423
            ld de, asm_1_2316_n_fp_end		; Hyp.cls 2424
            or a		; Hyp.cls 2425
            sbc hl, de		; Hyp.cls 2426
            add hl, de		; Hyp.cls 2427
            jr c, asm_1_2316_n_fl_in_lp		; Hyp.cls 2428
            xor a		; Hyp.cls 2429
            ld (asm_1_2316_n_fl_res), a		; Hyp.cls 2430
            jp asm_1_2316_n_fl_done		; Hyp.cls 2431
; ---- what the page code can't do itself (it runs in the window): switch the window to a slot's
; page and back. Each puts the hypervisor's page back in the window
asm_1_2316_n_fl_sel:                             ; the slot's page holding HL in the window: HL = there [2434]
            push de		; Hyp.cls 2435
            ld a, h		; Hyp.cls 2436
            rlca		; Hyp.cls 2437
            rlca		; Hyp.cls 2438
            and 3		; Hyp.cls 2439
            add a, 4		; Hyp.cls 2440
            ld e, a		; Hyp.cls 2441
            ld bc, (var_hyp_filecall_setting)		; Hyp.cls 2442
            ld a, c		; Hyp.cls 2443
            and #F8		; Hyp.cls 2444
            or e		; Hyp.cls 2445
            ld c, a		; Hyp.cls 2446
            out (c), c		; Hyp.cls 2447
            ld a, h		; Hyp.cls 2448
            and #3F		; Hyp.cls 2449
            or #40		; Hyp.cls 2450
            ld h, a		; Hyp.cls 2451
            pop de		; Hyp.cls 2452
            ret		; Hyp.cls 2453
asm_1_2316_n_fl_peek:                            ; A = the slot's byte at HL (BC, DE, HL kept) [2454]
            push bc		; Hyp.cls 2455
            push hl		; Hyp.cls 2456
            call asm_1_2316_n_fl_sel		; Hyp.cls 2457
            ld a, (hl)		; Hyp.cls 2458
asm_1_2316_n_fl_pk_back:		; Hyp.cls 2459
            ld bc, (var_hyp_hps)		; Hyp.cls 2460
            out (c), c		; Hyp.cls 2461
            pop hl		; Hyp.cls 2462
            pop bc		; Hyp.cls 2463
            ret		; Hyp.cls 2464
asm_1_2316_n_fl_poke:                            ; the slot's byte at HL = A (BC, DE, HL kept) [2465]
            push bc		; Hyp.cls 2466
            push hl		; Hyp.cls 2467
            push af		; Hyp.cls 2468
            call asm_1_2316_n_fl_sel		; Hyp.cls 2469
            pop af		; Hyp.cls 2470
            ld (hl), a		; Hyp.cls 2471
            jr asm_1_2316_n_fl_pk_back		; Hyp.cls 2472
asm_1_2316_n_fl_toslot:                          ; BC bytes from DE (main RAM) to the slot's HL (all in one of [2473]
            push bc                 ; its pages: fl_fits) [2474]
            call asm_1_2316_n_fl_sel		; Hyp.cls 2475
            pop bc		; Hyp.cls 2476
            ex de, hl		; Hyp.cls 2477
            ldir		; Hyp.cls 2478
            jr asm_1_2316_n_fl_blk_back		; Hyp.cls 2479
asm_1_2316_n_fl_fromslot:                        ; BC bytes from the slot's HL (in one page) to DE (main RAM) [2480]
            push bc		; Hyp.cls 2481
            call asm_1_2316_n_fl_sel		; Hyp.cls 2482
            pop bc		; Hyp.cls 2483
            ldir		; Hyp.cls 2484
asm_1_2316_n_fl_blk_back:		; Hyp.cls 2485
            ld bc, (var_hyp_hps)		; Hyp.cls 2486
            out (c), c		; Hyp.cls 2487
            ret		; Hyp.cls 2488
asm_1_2316_n_fl_done:		; Hyp.cls 2489
            di		; Hyp.cls 2490
            ld bc, (ntc_rampt)      ; the page that was in the window back [2491]
            out (c), c		; Hyp.cls 2492
            ld a, (asm_1_2316_n_fl_res)		; Hyp.cls 2493
            ld l, a		; Hyp.cls 2494
            ld h, 0		; Hyp.cls 2495
            ld a, (asm_1_2316_n_fl_r16)		; Hyp.cls 2496
            or a		; Hyp.cls 2497
            jr z, asm_1_2316_n_fl_d8		; Hyp.cls 2498
            ld hl, (asm_1_2316_n_fl_res16)		; Hyp.cls 2499
            xor a		; Hyp.cls 2500
            ld (asm_1_2316_n_fl_r16), a		; Hyp.cls 2501
asm_1_2316_n_fl_d8:		; Hyp.cls 2502
            ld (var_hyp_filecall_filecall), hl		; Hyp.cls 2503
            ld ix, (asm_1_2316_n_fl_ix)		; Hyp.cls 2504
            ld iy, (asm_1_2316_n_fl_iy)		; Hyp.cls 2505
            ld sp, (var_hyp_hsp)		; Hyp.cls 2506
            jp asm_1_2316_n_fl_exit		; Hyp.cls 2507
asm_1_2316_n_fl_ix:      dw 0		; Hyp.cls 2508
asm_1_2316_n_fl_iy:      dw 0		; Hyp.cls 2509
asm_1_2316_n_fl_res:     db 0		; Hyp.cls 2510
asm_1_2316_n_fl_r16:     db 0                    ; 1: the result is fl_res16 [2511]
asm_1_2316_n_fl_res16:   dw 0		; Hyp.cls 2512
asm_1_2316_n_fl_slot:    db 0		; Hyp.cls 2513
; (main RAM: the page code calls them - no room left in the page)
asm_1_2316_n_fl_isin:                            ; Z: the file being read is this slot's, this FCB [2515]
            ld a, (var_hyp_fin)		; Hyp.cls 2516
            ld hl, asm_1_2316_n_fl_infcb		; Hyp.cls 2517
            jr asm_1_2316_n_fl_is		; Hyp.cls 2518
asm_1_2316_n_fl_isout:		; Hyp.cls 2519
            ld a, (var_hyp_fout)		; Hyp.cls 2520
            ld hl, asm_1_2316_n_fl_outfcb		; Hyp.cls 2521
asm_1_2316_n_fl_is:                              ; (its FCB: the one it was opened with - or, the first [2522]
            ld b, a                 ; call after with another, that one: a program's own copy [2523]
            ld a, (asm_1_2316_n_fl_slot)         ; of it, BBC BASIC's channels) [2524]
            cp b		; Hyp.cls 2525
            ret nz		; Hyp.cls 2526
            ld e, (hl)		; Hyp.cls 2527
            inc hl		; Hyp.cls 2528
            ld d, (hl)		; Hyp.cls 2529
            inc hl		; Hyp.cls 2530
            push hl		; Hyp.cls 2531
            call asm_1_2316_n_fl_cmpf		; Hyp.cls 2532
            pop de		; Hyp.cls 2533
            ret z		; Hyp.cls 2534
            ld a, (de)              ; (the open's FCB still: this one from now on - unless it [2535]
            xor 1                   ; is the other file's: a program reading the record it [2536]
            ret nz                  ; writes, through that file's FCB) [2537]
            push de		; Hyp.cls 2538
            ld a, (var_hyp_fin)		; Hyp.cls 2539
            ld de, (asm_1_2316_n_fl_infcb)		; Hyp.cls 2540
            call asm_1_2316_n_fl_oth		; Hyp.cls 2541
            jr z, asm_1_2316_n_fl_is_no		; Hyp.cls 2542
            ld a, (var_hyp_fout)		; Hyp.cls 2543
            ld de, (asm_1_2316_n_fl_outfcb)		; Hyp.cls 2544
            call asm_1_2316_n_fl_oth		; Hyp.cls 2545
asm_1_2316_n_fl_is_no:		; Hyp.cls 2546
            pop de		; Hyp.cls 2547
            jr nz, asm_1_2316_n_fl_is_re		; Hyp.cls 2548
            inc a                   ; (NZ: not this one) [2549]
            ret		; Hyp.cls 2550
asm_1_2316_n_fl_is_re:		; Hyp.cls 2551
            xor a		; Hyp.cls 2552
            ld (de), a		; Hyp.cls 2553
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2554
            ex de, hl		; Hyp.cls 2555
            dec hl		; Hyp.cls 2556
            ld (hl), d		; Hyp.cls 2557
            dec hl		; Hyp.cls 2558
            ld (hl), e		; Hyp.cls 2559
            ret		; Hyp.cls 2560
asm_1_2316_n_fl_oth:                             ; Z: the slot's file (A: fin / fout), its FCB DE the call's [2561]
            ld b, a		; Hyp.cls 2562
            ld a, (asm_1_2316_n_fl_slot)		; Hyp.cls 2563
            cp b		; Hyp.cls 2564
            ret nz		; Hyp.cls 2565
asm_1_2316_n_fl_cmpf:                            ; Z: the call's FCB is DE [2566]
            ld hl, (var_hyp_filecall_fcb)		; Hyp.cls 2567
            or a		; Hyp.cls 2568
            sbc hl, de		; Hyp.cls 2569
            ret		; Hyp.cls 2570
asm_1_2316_n_fl_exit:		; Hyp.cls 3861
			ret			; end of #asm

asm_1_3867_n:		; #asm, Hyp.cls line 3867 (normal)
            ld (var_hyp_hsp), sp		; Hyp.cls 3868
            ld sp, (ntc_csp)		; Hyp.cls 3869
            ld bc, (var_hyp_hps)          ; (the buffers: the hypervisor's page) [3870]
            out (c), c		; Hyp.cls 3871
            ld a, (var_hyp_fileshut_slot)		; Hyp.cls 3872
            ld b, a		; Hyp.cls 3873
            ld a, (var_hyp_fin)		; Hyp.cls 3874
            cp b		; Hyp.cls 3875
            jr nz, asm_1_3867_n_fs_out		; Hyp.cls 3876
            xor a		; Hyp.cls 3877
            ld (var_hyp_fin), a		; Hyp.cls 3878
            push bc		; Hyp.cls 3879
            call #BC7A              ; CAS IN CLOSE [3880]
            di		; Hyp.cls 3881
            pop bc		; Hyp.cls 3882
asm_1_3867_n_fs_out:		; Hyp.cls 3883
            ld a, (var_hyp_fout)		; Hyp.cls 3884
            cp b		; Hyp.cls 3885
            jr nz, asm_1_3867_n_fs_done		; Hyp.cls 3886
            xor a		; Hyp.cls 3887
            ld (var_hyp_fout), a		; Hyp.cls 3888
            call #BC8F              ; CAS OUT CLOSE [3889]
            di		; Hyp.cls 3890
asm_1_3867_n_fs_done:		; Hyp.cls 3891
            ld bc, (ntc_rampt)		; Hyp.cls 3892
            out (c), c		; Hyp.cls 3893
            ld sp, (var_hyp_hsp)		; Hyp.cls 3894
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

fn_memory_selectpage:		; function selectpage (asm keyword), Memory.cls line 250
            pop hl		; Memory.cls 251
            ld e, (hl)		; Memory.cls 252
            inc hl		; Memory.cls 253
            ld d, (hl)		; Memory.cls 254
            ld (mem_a1), de		; Memory.cls 255
            pop hl		; Memory.cls 256
            ld (mem_res), hl		; Memory.cls 257
            ld hl, mem_selpage		; Memory.cls 258
            jp mem_go		; Memory.cls 259
			ret			; end of #asm

fn_memory_readbyte:		; function readbyte (asm keyword), Memory.cls line 340
            pop hl		; Memory.cls 341
            ld (mem_a1), hl		; Memory.cls 342
            pop hl		; Memory.cls 343
            ld (mem_res), hl		; Memory.cls 344
            ld hl, mem_readbyte		; Memory.cls 345
            jp mem_go		; Memory.cls 346
			ret			; end of #asm

fn_memory_writebyte:		; sub writebyte (asm keyword), Memory.cls line 362
            pop hl		; Memory.cls 363
            ld (mem_a1), hl		; Memory.cls 364
            pop hl		; Memory.cls 365
            ld e, (hl)		; Memory.cls 366
            inc hl		; Memory.cls 367
            ld d, (hl)		; Memory.cls 368
            ld (mem_a2), de		; Memory.cls 369
            ld hl, mem_writebyte		; Memory.cls 370
            jp mem_go0		; Memory.cls 371
			ret			; end of #asm

fn_memory_writeword:		; sub writeword (asm keyword), Memory.cls line 376
            pop hl		; Memory.cls 377
            ld (mem_a1), hl		; Memory.cls 378
            pop hl		; Memory.cls 379
            ld e, (hl)		; Memory.cls 380
            inc hl		; Memory.cls 381
            ld d, (hl)		; Memory.cls 382
            ld (mem_a2), de		; Memory.cls 383
            ld hl, mem_writeword		; Memory.cls 384
            jp mem_go0		; Memory.cls 385
			ret			; end of #asm

fn_memory_copy:		; function copy (asm keyword), Memory.cls line 393
            pop hl		; Memory.cls 394
            ld (mem_a1), hl		; Memory.cls 395
            pop hl		; Memory.cls 396
            ld (mem_a2), hl		; Memory.cls 397
            pop hl		; Memory.cls 398
            ld e, (hl)		; Memory.cls 399
            inc hl		; Memory.cls 400
            ld d, (hl)		; Memory.cls 401
            ld (mem_a3), de		; Memory.cls 402
            pop hl		; Memory.cls 403
            ld (mem_res), hl		; Memory.cls 404
            ld hl, mem_copy		; Memory.cls 405
            jp mem_go		; Memory.cls 406
			ret			; end of #asm

fn_memory_banks:		; function banks (asm keyword), Memory.cls line 414
            pop hl		; Memory.cls 415
            ld (mem_res), hl		; Memory.cls 416
            ld hl, mem_bankcount		; Memory.cls 417
            jp mem_go		; Memory.cls 418
			ret			; end of #asm

fn_memory_allocbank:		; function allocbank (asm keyword), Memory.cls line 424
            pop hl		; Memory.cls 425
            ld (mem_res), hl		; Memory.cls 426
            ld hl, mem_allocbank		; Memory.cls 427
            jp mem_go		; Memory.cls 428
			ret			; end of #asm


ntc_rg58_e:
			IF ($ < 32768) && (ntc_rg59_e - ntc_rg59 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg59:
; ============================================================
; Variables
; ============================================================

ntc_rg59_e:
			IF ($ < 32768) && (ntc_rg60_e - ntc_rg60 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg60:
var_k:			dw 0
ntc_rg60_e:
			IF ($ < 32768) && (ntc_rg61_e - ntc_rg61 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg61:
var_ns:			dw 0
ntc_rg61_e:
			IF ($ < 32768) && (ntc_rg62_e - ntc_rg62 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg62:
var_i:			dw 0
ntc_rg62_e:
			IF ($ < 32768) && (ntc_rg63_e - ntc_rg63 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg63:
var_hp:			dw 0
ntc_rg63_e:
			IF ($ < 32768) && (ntc_rg64_e - ntc_rg64 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg64:
var_memory_selectpage_selectpage:			dw 0
ntc_rg64_e:
			IF ($ < 32768) && (ntc_rg65_e - ntc_rg65 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg65:
var_hyp_filecall_filecall:			dw 0
ntc_rg65_e:
			IF ($ < 32768) && (ntc_rg66_e - ntc_rg66 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg66:
for3_l:			dw 0
ntc_rg66_e:
			IF ($ < 32768) && (ntc_rg67_e - ntc_rg67 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg67:
var_memory_allocbank_allocbank:			dw 0
ntc_rg67_e:
			IF ($ < 32768) && (ntc_rg68_e - ntc_rg68 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg68:
var_memory_bankpage_bankpage:			dw 0
ntc_rg68_e:
			IF ($ < 32768) && (ntc_rg69_e - ntc_rg69 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg69:
var_hyp_setting_setting:			dw 0
ntc_rg69_e:
			IF ($ < 32768) && (ntc_rg70_e - ntc_rg70 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg70:
			db 82			; capacity
var_ob:			ds 83
ntc_rg70_e:
			IF ($ < 32768) && (ntc_rg71_e - ntc_rg71 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg71:
var_front:			dw 0
ntc_rg71_e:
			IF ($ < 32768) && (ntc_rg72_e - ntc_rg72 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg72:
			db 72			; capacity
var_a:			ds 73
ntc_rg72_e:
			IF ($ < 32768) && (ntc_rg73_e - ntc_rg73 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg73:
var_hk:			dw 0
ntc_rg73_e:
			IF ($ < 32768) && (ntc_rg74_e - ntc_rg74 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg74:
var_hot_take_take:			dw 0
ntc_rg74_e:
			IF ($ < 32768) && (ntc_rg75_e - ntc_rg75 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg75:
var_back:			dw 0
ntc_rg75_e:
			IF ($ < 32768) && (ntc_rg76_e - ntc_rg76 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg76:
var_pk:			dw 0
ntc_rg76_e:
			IF ($ < 32768) && (ntc_rg77_e - ntc_rg77 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg77:
var_wt:			dw 0
ntc_rg77_e:
			IF ($ < 32768) && (ntc_rg78_e - ntc_rg78 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg78:
var_hot_control_control:			dw 0
ntc_rg78_e:
			IF ($ < 32768) && (ntc_rg79_e - ntc_rg79 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg79:
var_hot_held_held:			dw 0
ntc_rg79_e:
			IF ($ < 32768) && (ntc_rg80_e - ntc_rg80 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg80:
var_running_running:			dw 0
ntc_rg80_e:
			IF ($ < 32768) && (ntc_rg81_e - ntc_rg81 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg81:
var_td:			dw 0
ntc_rg81_e:
			IF ($ < 32768) && (ntc_rg82_e - ntc_rg82 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg82:
var_tc:			dw 0
ntc_rg82_e:
			IF ($ < 32768) && (ntc_rg83_e - ntc_rg83 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg83:
var_quit:			dw 0
ntc_rg83_e:
			IF ($ < 32768) && (ntc_rg84_e - ntc_rg84 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg84:
var_hyp_scr_scr:			dw 0
ntc_rg84_e:
			IF ($ < 32768) && (ntc_rg85_e - ntc_rg85 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg85:
var_runs:			dw 0
ntc_rg85_e:
			IF ($ < 32768) && (ntc_rg86_e - ntc_rg86 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg86:
p_running_rs:			dw 0
ntc_rg86_e:
			IF ($ < 32768) && (ntc_rg87_e - ntc_rg87 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg87:
var_running_j:			dw 0
ntc_rg87_e:
			IF ($ < 32768) && (ntc_rg88_e - ntc_rg88 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg88:
for17_l:			dw 0
ntc_rg88_e:
			IF ($ < 32768) && (ntc_rg89_e - ntc_rg89 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg89:
p_ready_rs:			dw 0
ntc_rg89_e:
			IF ($ < 32768) && (ntc_rg90_e - ntc_rg90 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg90:
var_ready_t:			dw 0
ntc_rg90_e:
			IF ($ < 32768) && (ntc_rg91_e - ntc_rg91 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg91:
var_ready_ready:			dw 0
ntc_rg91_e:
			IF ($ < 32768) && (ntc_rg92_e - ntc_rg92 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg92:
p_runnext_rs:			dw 0
ntc_rg92_e:
			IF ($ < 32768) && (ntc_rg93_e - ntc_rg93 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg93:
var_runnext_n:			dw 0
ntc_rg93_e:
			IF ($ < 32768) && (ntc_rg94_e - ntc_rg94 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg94:
var_runnext_t:			dw 0
ntc_rg94_e:
			IF ($ < 32768) && (ntc_rg95_e - ntc_rg95 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg95:
var_runnext_r:			dw 0
ntc_rg95_e:
			IF ($ < 32768) && (ntc_rg96_e - ntc_rg96 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg96:
var_runnext_c:			dw 0
ntc_rg96_e:
			IF ($ < 32768) && (ntc_rg97_e - ntc_rg97 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg97:
var_runnext_q:			dw 0
ntc_rg97_e:
			IF ($ < 32768) && (ntc_rg98_e - ntc_rg98 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg98:
var_fr:			dw 0
ntc_rg98_e:
			IF ($ < 32768) && (ntc_rg99_e - ntc_rg99 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg99:
for25_l:			dw 0
ntc_rg99_e:
			IF ($ < 32768) && (ntc_rg100_e - ntc_rg100 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg100:
var_cur:			dw 0
ntc_rg100_e:
			IF ($ < 32768) && (ntc_rg101_e - ntc_rg101 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg101:
var_hyp_run_run:			dw 0
ntc_rg101_e:
			IF ($ < 32768) && (ntc_rg102_e - ntc_rg102 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg102:
var_far_far:			dw 0, 0
ntc_rg102_e:
			IF ($ < 32768) && (ntc_rg103_e - ntc_rg103 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg103:
var_memory_readbyte_readbyte:			dw 0
ntc_rg103_e:
			IF ($ < 32768) && (ntc_rg104_e - ntc_rg104 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg104:
var_hyp_count_count:			dw 0
ntc_rg104_e:
			IF ($ < 32768) && (ntc_rg105_e - ntc_rg105 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg105:
var_hyp_fn_fn:			dw 0
ntc_rg105_e:
			IF ($ < 32768) && (ntc_rg106_e - ntc_rg106 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg106:
p_bdos_rs:			dw 0
ntc_rg106_e:
			IF ($ < 32768) && (ntc_rg107_e - ntc_rg107 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg107:
var_bdos_t:			dw 0
ntc_rg107_e:
			IF ($ < 32768) && (ntc_rg108_e - ntc_rg108 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg108:
var_bdos_f:			dw 0
ntc_rg108_e:
			IF ($ < 32768) && (ntc_rg109_e - ntc_rg109 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg109:
var_bdos_e:			dw 0
ntc_rg109_e:
			IF ($ < 32768) && (ntc_rg110_e - ntc_rg110 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg110:
var_bdos_a:			dw 0
ntc_rg110_e:
			IF ($ < 32768) && (ntc_rg111_e - ntc_rg111 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg111:
var_hyp_arg_arg:			dw 0
ntc_rg111_e:
			IF ($ < 32768) && (ntc_rg112_e - ntc_rg112 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg112:
var_bdos___sel42:			dw 0
ntc_rg112_e:
			IF ($ < 32768) && (ntc_rg113_e - ntc_rg113 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg113:
var_sys_sys:			dw 0
ntc_rg113_e:
			IF ($ < 32768) && (ntc_rg114_e - ntc_rg114 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg114:
p_sys_rs:			dw 0
ntc_rg114_e:
			IF ($ < 32768) && (ntc_rg115_e - ntc_rg115 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg115:
var_sys_t:			dw 0
ntc_rg115_e:
			IF ($ < 32768) && (ntc_rg116_e - ntc_rg116 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg116:
var_sys_p:			dw 0
ntc_rg116_e:
			IF ($ < 32768) && (ntc_rg117_e - ntc_rg117 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg117:
var_sys_o:			dw 0
ntc_rg117_e:
			IF ($ < 32768) && (ntc_rg118_e - ntc_rg118 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg118:
var_sys_s:			dw 0
ntc_rg118_e:
			IF ($ < 32768) && (ntc_rg119_e - ntc_rg119 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg119:
var_sys_d:			dw 0
ntc_rg119_e:
			IF ($ < 32768) && (ntc_rg120_e - ntc_rg120 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg120:
var_txs:			dw 0
ntc_rg120_e:
			IF ($ < 32768) && (ntc_rg121_e - ntc_rg121 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg121:
			db 60			; capacity
var_en:			ds 61
ntc_rg121_e:
			IF ($ < 32768) && (ntc_rg122_e - ntc_rg122 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg122:
p_puten_rs:			dw 0
ntc_rg122_e:
			IF ($ < 32768) && (ntc_rg123_e - ntc_rg123 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg123:
var_puten_t:			dw 0
ntc_rg123_e:
			IF ($ < 32768) && (ntc_rg124_e - ntc_rg124 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg124:
var_puten_a:			dw 0
ntc_rg124_e:
			IF ($ < 32768) && (ntc_rg125_e - ntc_rg125 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg125:
var_nearp_nearp:			dw 0, 0
ntc_rg125_e:
			IF ($ < 32768) && (ntc_rg126_e - ntc_rg126 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg126:
var_memory_copy_copy:			dw 0
ntc_rg126_e:
			IF ($ < 32768) && (ntc_rg127_e - ntc_rg127 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg127:
p_hopen_rs:			dw 0
ntc_rg127_e:
			IF ($ < 32768) && (ntc_rg128_e - ntc_rg128 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg128:
var_hopen_hopen:			dw 0
ntc_rg128_e:
			IF ($ < 32768) && (ntc_rg129_e - ntc_rg129 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg129:
			db 16			; capacity
var_dn:			ds 17
ntc_rg129_e:
			IF ($ < 32768) && (ntc_rg130_e - ntc_rg130 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg130:
p_hclose_rs:			dw 0
ntc_rg130_e:
			IF ($ < 32768) && (ntc_rg131_e - ntc_rg131 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg131:
var_hclose_r:			dw 0
ntc_rg131_e:
			IF ($ < 32768) && (ntc_rg132_e - ntc_rg132 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg132:
p_filesshut_rs:			dw 0
ntc_rg132_e:
			IF ($ < 32768) && (ntc_rg133_e - ntc_rg133 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg133:
var_filesshut_t:			dw 0
ntc_rg133_e:
			IF ($ < 32768) && (ntc_rg134_e - ntc_rg134 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg134:
var_filesshut_r:			dw 0
ntc_rg134_e:
			IF ($ < 32768) && (ntc_rg135_e - ntc_rg135 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg135:
p_collected_rs:			dw 0
ntc_rg135_e:
			IF ($ < 32768) && (ntc_rg136_e - ntc_rg136 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg136:
var_collected_t:			dw 0
ntc_rg136_e:
			IF ($ < 32768) && (ntc_rg137_e - ntc_rg137 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg137:
var_collected_n:			dw 0
ntc_rg137_e:
			IF ($ < 32768) && (ntc_rg138_e - ntc_rg138 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg138:
p_puts_rs:			dw 0
ntc_rg138_e:
			IF ($ < 32768) && (ntc_rg139_e - ntc_rg139 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg139:
var_puts_t:			dw 0
ntc_rg139_e:
			IF ($ < 32768) && (ntc_rg140_e - ntc_rg140 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg140:
			db 255			; capacity
var_puts_s:			ds 256
ntc_rg140_e:
			IF ($ < 32768) && (ntc_rg141_e - ntc_rg141 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg141:
p_putln_rs:			dw 0
ntc_rg141_e:
			IF ($ < 32768) && (ntc_rg142_e - ntc_rg142 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg142:
var_putln_t:			dw 0
ntc_rg142_e:
			IF ($ < 32768) && (ntc_rg143_e - ntc_rg143 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg143:
			db 255			; capacity
var_putln_s:			ds 256
ntc_rg143_e:
			IF ($ < 32768) && (ntc_rg144_e - ntc_rg144 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg144:
p_putc_rs:			dw 0
ntc_rg144_e:
			IF ($ < 32768) && (ntc_rg145_e - ntc_rg145 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg145:
var_putc_t:			dw 0
ntc_rg145_e:
			IF ($ < 32768) && (ntc_rg146_e - ntc_rg146 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg146:
var_putc_c:			dw 0
ntc_rg146_e:
			IF ($ < 32768) && (ntc_rg147_e - ntc_rg147 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg147:
p_nearp_rs:			dw 0
ntc_rg147_e:
			IF ($ < 32768) && (ntc_rg148_e - ntc_rg148 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg148:
var_nearp_p:			dw 0
ntc_rg148_e:
			IF ($ < 32768) && (ntc_rg149_e - ntc_rg149 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg149:
p_far_rs:			dw 0
ntc_rg149_e:
			IF ($ < 32768) && (ntc_rg150_e - ntc_rg150 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg150:
var_far_t:			dw 0
ntc_rg150_e:
			IF ($ < 32768) && (ntc_rg151_e - ntc_rg151 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg151:
var_far_a:			dw 0
ntc_rg151_e:
			IF ($ < 32768) && (ntc_rg152_e - ntc_rg152 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg152:
p_clst_rs:			dw 0
ntc_rg152_e:
			IF ($ < 32768) && (ntc_rg153_e - ntc_rg153 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg153:
var_clst_t:			dw 0
ntc_rg153_e:
			IF ($ < 32768) && (ntc_rg154_e - ntc_rg154 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg154:
p_tofront_rs:			dw 0
ntc_rg154_e:
			IF ($ < 32768) && (ntc_rg155_e - ntc_rg155 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg155:
var_tofront_t:			dw 0
ntc_rg155_e:
			IF ($ < 32768) && (ntc_rg156_e - ntc_rg156 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg156:
var_tofront_r:			dw 0
ntc_rg156_e:
			IF ($ < 32768) && (ntc_rg157_e - ntc_rg157 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg157:
p_setmode_rs:			dw 0
ntc_rg157_e:
			IF ($ < 32768) && (ntc_rg158_e - ntc_rg158 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg158:
var_setmode_t:			dw 0
ntc_rg158_e:
			IF ($ < 32768) && (ntc_rg159_e - ntc_rg159 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg159:
var_setmode_m:			dw 0
ntc_rg159_e:
			IF ($ < 32768) && (ntc_rg160_e - ntc_rg160 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg160:
var_setmode_r:			dw 0
ntc_rg160_e:
			IF ($ < 32768) && (ntc_rg161_e - ntc_rg161 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg161:
			db 255			; capacity
var_n_n:			ds 256
ntc_rg161_e:
			IF ($ < 32768) && (ntc_rg162_e - ntc_rg162 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg162:
p_showtop_rs:			dw 0
ntc_rg162_e:
			IF ($ < 32768) && (ntc_rg163_e - ntc_rg163 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg163:
var_showtop_j:			dw 0
ntc_rg163_e:
			IF ($ < 32768) && (ntc_rg164_e - ntc_rg164 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg164:
p_toplines_rs:			dw 0
ntc_rg164_e:
			IF ($ < 32768) && (ntc_rg165_e - ntc_rg165 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg165:
var_toplines_mark:			dw 0
ntc_rg165_e:
			IF ($ < 32768) && (ntc_rg166_e - ntc_rg166 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg166:
var_toplines_keys:			dw 0
ntc_rg166_e:
			IF ($ < 32768) && (ntc_rg167_e - ntc_rg167 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg167:
var_toplines_j:			dw 0
ntc_rg167_e:
			IF ($ < 32768) && (ntc_rg168_e - ntc_rg168 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg168:
			db 14			; capacity
var_toplines_s:			ds 15
ntc_rg168_e:
			IF ($ < 32768) && (ntc_rg169_e - ntc_rg169 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg169:
var_txn:			dw 0
ntc_rg169_e:
			IF ($ < 32768) && (ntc_rg170_e - ntc_rg170 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg170:
			db 255			; capacity
var_sk_sk:			ds 256
ntc_rg170_e:
			IF ($ < 32768) && (ntc_rg171_e - ntc_rg171 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg171:
for63_l:			dw 0
ntc_rg171_e:
			IF ($ < 32768) && (ntc_rg172_e - ntc_rg172 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg172:
var_ld:			dw 0
ntc_rg172_e:
			IF ($ < 32768) && (ntc_rg173_e - ntc_rg173 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg173:
var_rate_rate:			dw 0
ntc_rg173_e:
			IF ($ < 32768) && (ntc_rg174_e - ntc_rg174 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg174:
			db 255			; capacity
var_pad_pad:			ds 256
ntc_rg174_e:
			IF ($ < 32768) && (ntc_rg175_e - ntc_rg175 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg175:
p_totals_rs:			dw 0
ntc_rg175_e:
			IF ($ < 32768) && (ntc_rg176_e - ntc_rg176 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg176:
var_memory_ramsize_ramsize:			dw 0
ntc_rg176_e:
			IF ($ < 32768) && (ntc_rg177_e - ntc_rg177 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg177:
var_memory_freepages_freepages:			dw 0
ntc_rg177_e:
			IF ($ < 32768) && (ntc_rg178_e - ntc_rg178 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg178:
p_topadd_rs:			dw 0
ntc_rg178_e:
			IF ($ < 32768) && (ntc_rg179_e - ntc_rg179 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg179:
			db 255			; capacity
var_topadd_s:			ds 256
ntc_rg179_e:
			IF ($ < 32768) && (ntc_rg180_e - ntc_rg180 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg180:
p_roll_rs:			dw 0
ntc_rg180_e:
			IF ($ < 32768) && (ntc_rg181_e - ntc_rg181 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg181:
var_roll_j:			dw 0
ntc_rg181_e:
			IF ($ < 32768) && (ntc_rg182_e - ntc_rg182 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg182:
for68_l:			dw 0
ntc_rg182_e:
			IF ($ < 32768) && (ntc_rg183_e - ntc_rg183 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg183:
p_pad_rs:			dw 0
ntc_rg183_e:
			IF ($ < 32768) && (ntc_rg184_e - ntc_rg184 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg184:
var_pad_v:			dw 0
ntc_rg184_e:
			IF ($ < 32768) && (ntc_rg185_e - ntc_rg185 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg185:
p_rate_rs:			dw 0
ntc_rg185_e:
			IF ($ < 32768) && (ntc_rg186_e - ntc_rg186 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg186:
var_rate_n:			dw 0
ntc_rg186_e:
			IF ($ < 32768) && (ntc_rg187_e - ntc_rg187 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg187:
var_rate_d:			dw 0
ntc_rg187_e:
			IF ($ < 32768) && (ntc_rg188_e - ntc_rg188 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg188:
p_install_rs:			dw 0
ntc_rg188_e:
			IF ($ < 32768) && (ntc_rg189_e - ntc_rg189 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg189:
var_install_t:			dw 0
ntc_rg189_e:
			IF ($ < 32768) && (ntc_rg190_e - ntc_rg190 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg190:
var_install_p:			dw 0
ntc_rg190_e:
			IF ($ < 32768) && (ntc_rg191_e - ntc_rg191 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg191:
var_install_n:			dw 0
ntc_rg191_e:
			IF ($ < 32768) && (ntc_rg192_e - ntc_rg192 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg192:
var_hyp_farptr_farptr:			dw 0, 0
ntc_rg192_e:
			IF ($ < 32768) && (ntc_rg193_e - ntc_rg193 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg193:
p_resetslot_rs:			dw 0
ntc_rg193_e:
			IF ($ < 32768) && (ntc_rg194_e - ntc_rg194 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg194:
var_resetslot_s:			dw 0
ntc_rg194_e:
			IF ($ < 32768) && (ntc_rg195_e - ntc_rg195 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg195:
p_openslot_rs:			dw 0
ntc_rg195_e:
			IF ($ < 32768) && (ntc_rg196_e - ntc_rg196 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg196:
var_openslot_t:			dw 0
ntc_rg196_e:
			IF ($ < 32768) && (ntc_rg197_e - ntc_rg197 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg197:
p_sk_rs:			dw 0
ntc_rg197_e:
			IF ($ < 32768) && (ntc_rg198_e - ntc_rg198 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg198:
p_getnm_rs:			dw 0
ntc_rg198_e:
			IF ($ < 32768) && (ntc_rg199_e - ntc_rg199 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg199:
var_getnm_t:			dw 0
ntc_rg199_e:
			IF ($ < 32768) && (ntc_rg200_e - ntc_rg200 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg200:
var_getnm_n:			dw 0
ntc_rg200_e:
			IF ($ < 32768) && (ntc_rg201_e - ntc_rg201 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg201:
p_n_rs:			dw 0
ntc_rg201_e:
			IF ($ < 32768) && (ntc_rg202_e - ntc_rg202 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg202:
var_n_v:			dw 0
ntc_rg202_e:
			IF ($ < 32768) && (ntc_rg203_e - ntc_rg203 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg203:
p_prompt_rs:			dw 0
ntc_rg203_e:
			IF ($ < 32768) && (ntc_rg204_e - ntc_rg204 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg204:
var_prompt_t:			dw 0
ntc_rg204_e:
			IF ($ < 32768) && (ntc_rg205_e - ntc_rg205 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg205:
p_keyin_rs:			dw 0
ntc_rg205_e:
			IF ($ < 32768) && (ntc_rg206_e - ntc_rg206 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg206:
var_keyin_k:			dw 0
ntc_rg206_e:
			IF ($ < 32768) && (ntc_rg207_e - ntc_rg207 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg207:
var_keyin_t:			dw 0
ntc_rg207_e:
			IF ($ < 32768) && (ntc_rg208_e - ntc_rg208 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg208:
var_keyin_n:			dw 0
ntc_rg208_e:
			IF ($ < 32768) && (ntc_rg209_e - ntc_rg209 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg209:
p_command_rs:			dw 0
ntc_rg209_e:
			IF ($ < 32768) && (ntc_rg210_e - ntc_rg210 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg210:
var_command_t:			dw 0
ntc_rg210_e:
			IF ($ < 32768) && (ntc_rg211_e - ntc_rg211 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg211:
			db 72			; capacity
var_command_c:			ds 73
ntc_rg211_e:
			IF ($ < 32768) && (ntc_rg212_e - ntc_rg212 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg212:
var_command_p:			dw 0
ntc_rg212_e:
			IF ($ < 32768) && (ntc_rg213_e - ntc_rg213 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg213:
var_command_s:			dw 0
ntc_rg213_e:
			IF ($ < 32768) && (ntc_rg214_e - ntc_rg214 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg214:
			db 72			; capacity
var_b:			ds 73
ntc_rg214_e:
			IF ($ < 32768) && (ntc_rg215_e - ntc_rg215 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg215:
			db 255			; capacity
var_command___sel81:			ds 256
ntc_rg215_e:
			IF ($ < 32768) && (ntc_rg216_e - ntc_rg216 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg216:
var_bare:			dw 0
ntc_rg216_e:
			IF ($ < 32768) && (ntc_rg217_e - ntc_rg217 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg217:
p_starttask_rs:			dw 0
ntc_rg217_e:
			IF ($ < 32768) && (ntc_rg218_e - ntc_rg218 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg218:
var_starttask_t:			dw 0
ntc_rg218_e:
			IF ($ < 32768) && (ntc_rg219_e - ntc_rg219 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg219:
var_starttask_s:			dw 0
ntc_rg219_e:
			IF ($ < 32768) && (ntc_rg220_e - ntc_rg220 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg220:
var_starttask_h:			dw 0
ntc_rg220_e:
			IF ($ < 32768) && (ntc_rg221_e - ntc_rg221 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg221:
var_starttask_n:			dw 0
ntc_rg221_e:
			IF ($ < 32768) && (ntc_rg222_e - ntc_rg222 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg222:
var_starttask_rest:			dw 0
ntc_rg222_e:
			IF ($ < 32768) && (ntc_rg223_e - ntc_rg223 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg223:
var_starttask_com:			dw 0
ntc_rg223_e:
			IF ($ < 32768) && (ntc_rg224_e - ntc_rg224 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg224:
			db 72			; capacity
var_starttask_w:			ds 73
ntc_rg224_e:
			IF ($ < 32768) && (ntc_rg225_e - ntc_rg225 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg225:
var_starttask_d:			dw 0
ntc_rg225_e:
			IF ($ < 32768) && (ntc_rg226_e - ntc_rg226 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg226:
var_hyp_info_info:			dw 0
ntc_rg226_e:
			IF ($ < 32768) && (ntc_rg227_e - ntc_rg227 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg227:
p_notfound_rs:			dw 0
ntc_rg227_e:
			IF ($ < 32768) && (ntc_rg228_e - ntc_rg228 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg228:
var_notfound_t:			dw 0
ntc_rg228_e:
			IF ($ < 32768) && (ntc_rg229_e - ntc_rg229 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg229:
p_endtask_rs:			dw 0
ntc_rg229_e:
			IF ($ < 32768) && (ntc_rg230_e - ntc_rg230 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg230:
var_endtask_t:			dw 0
ntc_rg230_e:
			IF ($ < 32768) && (ntc_rg231_e - ntc_rg231 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg231:
var_endtask_c:			dw 0
ntc_rg231_e:
			IF ($ < 32768) && (ntc_rg232_e - ntc_rg232 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg232:
var_hyp_hps:			dw 0
ntc_rg232_e:
			IF ($ < 32768) && (ntc_rg233_e - ntc_rg233 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg233:
var_hyp_hsp:			dw 0
ntc_rg233_e:
			IF ($ < 32768) && (ntc_rg234_e - ntc_rg234 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg234:
p_hyp_con_rs:			dw 0
ntc_rg234_e:
			IF ($ < 32768) && (ntc_rg235_e - ntc_rg235 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg235:
var_hyp_con_pg:			dw 0
ntc_rg235_e:
			IF ($ < 32768) && (ntc_rg236_e - ntc_rg236 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg236:
var_hyp_con_src:			dw 0
ntc_rg236_e:
			IF ($ < 32768) && (ntc_rg237_e - ntc_rg237 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg237:
var_hyp_con_n:			dw 0
ntc_rg237_e:
			IF ($ < 32768) && (ntc_rg238_e - ntc_rg238 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg238:
var_hyp_con_front:			dw 0
ntc_rg238_e:
			IF ($ < 32768) && (ntc_rg239_e - ntc_rg239 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg239:
var_hyp_ccu:			dw 0
ntc_rg239_e:
			IF ($ < 32768) && (ntc_rg240_e - ntc_rg240 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg240:
var_hyp_sco:			dw 0
ntc_rg240_e:
			IF ($ < 32768) && (ntc_rg241_e - ntc_rg241 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg241:
var_hyp_scc:			dw 0
ntc_rg241_e:
			IF ($ < 32768) && (ntc_rg242_e - ntc_rg242 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg242:
var_hyp_pon:			dw 0
ntc_rg242_e:
			IF ($ < 32768) && (ntc_rg243_e - ntc_rg243 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg243:
p_hyp_say_rs:			dw 0
ntc_rg243_e:
			IF ($ < 32768) && (ntc_rg244_e - ntc_rg244 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg244:
var_hyp_say_p:			dw 0
ntc_rg244_e:
			IF ($ < 32768) && (ntc_rg245_e - ntc_rg245 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg245:
var_hyp_say_n:			dw 0
ntc_rg245_e:
			IF ($ < 32768) && (ntc_rg246_e - ntc_rg246 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg246:
var_hyp_say_col:			dw 0
ntc_rg246_e:
			IF ($ < 32768) && (ntc_rg247_e - ntc_rg247 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg247:
var_hyp_say_row:			dw 0
ntc_rg247_e:
			IF ($ < 32768) && (ntc_rg248_e - ntc_rg248 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg248:
p_hyp_scr_rs:			dw 0
ntc_rg248_e:
			IF ($ < 32768) && (ntc_rg249_e - ntc_rg249 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg249:
var_hyp_scr_m:			dw 0
ntc_rg249_e:
			IF ($ < 32768) && (ntc_rg250_e - ntc_rg250 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg250:
var_hyp_scr_k:			dw 0
ntc_rg250_e:
			IF ($ < 32768) && (ntc_rg251_e - ntc_rg251 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg251:
var_hyp_scw:			dw 0
ntc_rg251_e:
			IF ($ < 32768) && (ntc_rg252_e - ntc_rg252 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg252:
p_hyp_keyrep_rs:			dw 0
ntc_rg252_e:
			IF ($ < 32768) && (ntc_rg253_e - ntc_rg253 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg253:
var_hyp_keyrep_f:			dw 0
ntc_rg253_e:
			IF ($ < 32768) && (ntc_rg254_e - ntc_rg254 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg254:
p_hyp_show_rs:			dw 0
ntc_rg254_e:
			IF ($ < 32768) && (ntc_rg255_e - ntc_rg255 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg255:
var_hyp_show_pg:			dw 0
ntc_rg255_e:
			IF ($ < 32768) && (ntc_rg256_e - ntc_rg256 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg256:
p_hyp_reply_rs:			dw 0
ntc_rg256_e:
			IF ($ < 32768) && (ntc_rg257_e - ntc_rg257 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg257:
var_hyp_reply_a:			dw 0
ntc_rg257_e:
			IF ($ < 32768) && (ntc_rg258_e - ntc_rg258 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg258:
var_hyp_reply_hl:			dw 0
ntc_rg258_e:
			IF ($ < 32768) && (ntc_rg259_e - ntc_rg259 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg259:
var_hyp_ra:			dw 0
ntc_rg259_e:
			IF ($ < 32768) && (ntc_rg260_e - ntc_rg260 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg260:
var_hyp_rhl:			dw 0
ntc_rg260_e:
			IF ($ < 32768) && (ntc_rg261_e - ntc_rg261 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg261:
p_hyp_fn_rs:			dw 0
ntc_rg261_e:
			IF ($ < 32768) && (ntc_rg262_e - ntc_rg262 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg262:
var_hyp_rfn:			dw 0
ntc_rg262_e:
			IF ($ < 32768) && (ntc_rg263_e - ntc_rg263 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg263:
p_hyp_arg_rs:			dw 0
ntc_rg263_e:
			IF ($ < 32768) && (ntc_rg264_e - ntc_rg264 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg264:
var_hyp_rde:			dw 0
ntc_rg264_e:
			IF ($ < 32768) && (ntc_rg265_e - ntc_rg265 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg265:
p_hyp_count_rs:			dw 0
ntc_rg265_e:
			IF ($ < 32768) && (ntc_rg266_e - ntc_rg266 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg266:
var_hyp_rcnt:			dw 0
ntc_rg266_e:
			IF ($ < 32768) && (ntc_rg267_e - ntc_rg267 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg267:
p_hyp_run_rs:			dw 0
ntc_rg267_e:
			IF ($ < 32768) && (ntc_rg268_e - ntc_rg268 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg268:
var_hyp_run_setting:			dw 0
ntc_rg268_e:
			IF ($ < 32768) && (ntc_rg269_e - ntc_rg269 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg269:
var_hyp_sps:			dw 0
ntc_rg269_e:
			IF ($ < 32768) && (ntc_rg270_e - ntc_rg270 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg270:
var_hyp_rrom:			dw 0
ntc_rg270_e:
			IF ($ < 32768) && (ntc_rg271_e - ntc_rg271 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg271:
var_hyp_slc:			dw 0
ntc_rg271_e:
			IF ($ < 32768) && (ntc_rg272_e - ntc_rg272 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg272:
var_hyp_rclr:			dw 0
ntc_rg272_e:
			IF ($ < 32768) && (ntc_rg273_e - ntc_rg273 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg273:
p_hyp_vdu_rs:			dw 0
ntc_rg273_e:
			IF ($ < 32768) && (ntc_rg274_e - ntc_rg274 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg274:
var_hyp_vdu_on:			dw 0
ntc_rg274_e:
			IF ($ < 32768) && (ntc_rg275_e - ntc_rg275 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg275:
p_hyp_filecall_rs:			dw 0
ntc_rg275_e:
			IF ($ < 32768) && (ntc_rg276_e - ntc_rg276 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg276:
var_hyp_filecall_f:			dw 0
ntc_rg276_e:
			IF ($ < 32768) && (ntc_rg277_e - ntc_rg277 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg277:
var_hyp_filecall_fcb:			dw 0
ntc_rg277_e:
			IF ($ < 32768) && (ntc_rg278_e - ntc_rg278 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg278:
var_hyp_filecall_slot:			dw 0
ntc_rg278_e:
			IF ($ < 32768) && (ntc_rg279_e - ntc_rg279 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg279:
var_hyp_filecall_setting:			dw 0
ntc_rg279_e:
			IF ($ < 32768) && (ntc_rg280_e - ntc_rg280 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg280:
var_hyp_filecall_dma:			dw 0
ntc_rg280_e:
			IF ($ < 32768) && (ntc_rg281_e - ntc_rg281 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg281:
var_hyp_filecall_drive:			dw 0
ntc_rg281_e:
			IF ($ < 32768) && (ntc_rg282_e - ntc_rg282 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg282:
var_hyp_filecall_buf:			dw 0
ntc_rg282_e:
			IF ($ < 32768) && (ntc_rg283_e - ntc_rg283 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg283:
var_hyp_drs:			dw 0
ntc_rg283_e:
			IF ($ < 32768) && (ntc_rg284_e - ntc_rg284 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg284:
var_hyp_hdr:			dw 0
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
var_hyp_fin:			dw 0
ntc_rg286_e:
			IF ($ < 32768) && (ntc_rg287_e - ntc_rg287 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg287:
var_hyp_fout:			dw 0
ntc_rg287_e:
			IF ($ < 32768) && (ntc_rg288_e - ntc_rg288 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg288:
p_hyp_fileshut_rs:			dw 0
ntc_rg288_e:
			IF ($ < 32768) && (ntc_rg289_e - ntc_rg289 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg289:
var_hyp_fileshut_slot:			dw 0
ntc_rg289_e:
			IF ($ < 32768) && (ntc_rg290_e - ntc_rg290 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg290:
p_hot_slots_rs:			dw 0
ntc_rg290_e:
			IF ($ < 32768) && (ntc_rg291_e - ntc_rg291 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg291:
var_hot_slots_n:			dw 0
ntc_rg291_e:
			IF ($ < 32768) && (ntc_rg292_e - ntc_rg292 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg292:
var_hot_ns:			dw 0
ntc_rg292_e:
			IF ($ < 32768) && (ntc_rg293_e - ntc_rg293 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg293:
p_hot_tick_rs:			dw 0
ntc_rg293_e:
			IF ($ < 32768) && (ntc_rg294_e - ntc_rg294 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg294:
var_hot_tick_k:			dw 0
ntc_rg294_e:
			IF ($ < 32768) && (ntc_rg295_e - ntc_rg295 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg295:
var_hot_ctl:			dw 0
ntc_rg295_e:
			IF ($ < 32768) && (ntc_rg296_e - ntc_rg296 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg296:
var_keys_down_down:			dw 0
ntc_rg296_e:
			IF ($ < 32768) && (ntc_rg297_e - ntc_rg297 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg297:
var_hot_last:			dw 0
ntc_rg297_e:
			IF ($ < 32768) && (ntc_rg298_e - ntc_rg298 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg298:
var_hot_one:			dw 0
ntc_rg298_e:
			IF ($ < 32768) && (ntc_rg299_e - ntc_rg299 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg299:
var_hot_pend:			dw 0
ntc_rg299_e:
			IF ($ < 32768) && (ntc_rg300_e - ntc_rg300 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg300:
var_hot_age:			dw 0
ntc_rg300_e:
			IF ($ < 32768) && (ntc_rg301_e - ntc_rg301 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg301:
p_hot_take_rs:			dw 0
ntc_rg301_e:
			IF ($ < 32768) && (ntc_rg302_e - ntc_rg302 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg302:
p_hot_control_rs:			dw 0
ntc_rg302_e:
			IF ($ < 32768) && (ntc_rg303_e - ntc_rg303 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg303:
p_hot_held_rs:			dw 0
ntc_rg303_e:
			IF ($ < 32768) && (ntc_rg304_e - ntc_rg304 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg304:
p_memory_bankpage_rs:			dw 0
ntc_rg304_e:
			IF ($ < 32768) && (ntc_rg305_e - ntc_rg305 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg305:
var_memory_bankpage_bank:			dw 0
ntc_rg305_e:
			IF ($ < 32768) && (ntc_rg306_e - ntc_rg306 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg306:
var_memory_bankpage_n:			dw 0
ntc_rg306_e:
			IF ($ < 32768) && (ntc_rg307_e - ntc_rg307 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg307:
tmp0:			dw 0
ntc_rg307_e:
			IF ($ < 32768) && (ntc_rg308_e - ntc_rg308 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg308:
tmp1:			dw 0
ntc_rg308_e:
			IF ($ < 32768) && (ntc_rg309_e - ntc_rg309 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg309:
tmp2:			dw 0
ntc_rg309_e:
			IF ($ < 32768) && (ntc_rg310_e - ntc_rg310 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg310:
tmp3:			dw 0
ntc_rg310_e:
			IF ($ < 32768) && (ntc_rg311_e - ntc_rg311 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg311:
tmp4:			dw 0
ntc_rg311_e:
			IF ($ < 32768) && (ntc_rg312_e - ntc_rg312 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg312:
tmp5:			dw 0
ntc_rg312_e:
			IF ($ < 32768) && (ntc_rg313_e - ntc_rg313 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg313:
tmp6:			dw 0
ntc_rg313_e:
			IF ($ < 32768) && (ntc_rg314_e - ntc_rg314 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg314:
			db 255			; capacity
stmp0:			ds 256
ntc_rg314_e:
			IF ($ < 32768) && (ntc_rg315_e - ntc_rg315 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg315:
			db 255			; capacity
stmp1:			ds 256
ntc_rg315_e:
			IF ($ < 32768) && (ntc_rg316_e - ntc_rg316 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg316:
			db 255			; capacity
stmp2:			ds 256
ntc_rg316_e:
			IF ($ < 32768) && (ntc_rg317_e - ntc_rg317 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg317:
			db 255			; capacity
stmp3:			ds 256
ntc_rg317_e:
			IF ($ < 32768) && (ntc_rg318_e - ntc_rg318 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg318:
ltmp0:			dw 0, 0
ntc_rg318_e:
			IF ($ < 32768) && (ntc_rg319_e - ntc_rg319 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg319:
ltmp1:			dw 0, 0

; numbers passed by address (read only)
ntc_rg319_e:
			IF ($ < 32768) && (ntc_rg320_e - ntc_rg320 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg320:
lit_0:			dw 0
ntc_rg320_e:
			IF ($ < 32768) && (ntc_rg321_e - ntc_rg321 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg321:
lit_1:			dw 1
ntc_rg321_e:
			IF ($ < 32768) && (ntc_rg322_e - ntc_rg322 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg322:
lit_85:			dw 85
ntc_rg322_e:
			IF ($ < 32768) && (ntc_rg323_e - ntc_rg323 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg323:
vp_arr_rb:			dw arr_rb
ntc_rg323_e:
			IF ($ < 32768) && (ntc_rg324_e - ntc_rg324 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg324:
lit_99:			dw 99
ntc_rg324_e:
			IF ($ < 32768) && (ntc_rg325_e - ntc_rg325 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg325:
lit_82:			dw 82
ntc_rg325_e:
			IF ($ < 32768) && (ntc_rg326_e - ntc_rg326 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg326:
lit_255:			dw 255
ntc_rg326_e:
			IF ($ < 32768) && (ntc_rg327_e - ntc_rg327 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg327:
lit_m3:			dw -3
ntc_rg327_e:
			IF ($ < 32768) && (ntc_rg328_e - ntc_rg328 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg328:
lit_2:			dw 2
ntc_rg328_e:
			IF ($ < 32768) && (ntc_rg329_e - ntc_rg329 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg329:
lit_m2431:			dw -2431
ntc_rg329_e:
			IF ($ < 32768) && (ntc_rg330_e - ntc_rg330 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg330:
lit_m2423:			dw -2423
ntc_rg330_e:
			IF ($ < 32768) && (ntc_rg331_e - ntc_rg331 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg331:
vp_var_en:			dw var_en
ntc_rg331_e:
			IF ($ < 32768) && (ntc_rg332_e - ntc_rg332 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg332:
vp_var_dn:			dw var_dn
ntc_rg332_e:
			IF ($ < 32768) && (ntc_rg333_e - ntc_rg333 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg333:
lit_100:			dw 100
ntc_rg333_e:
			IF ($ < 32768) && (ntc_rg334_e - ntc_rg334 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg334:
lit_101:			dw 101
ntc_rg334_e:
			IF ($ < 32768) && (ntc_rg335_e - ntc_rg335 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg335:
lit_102:			dw 102
ntc_rg335_e:
			IF ($ < 32768) && (ntc_rg336_e - ntc_rg336 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg336:
vp_var_puts_s:			dw var_puts_s
ntc_rg336_e:
			IF ($ < 32768) && (ntc_rg337_e - ntc_rg337 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg337:
vp_var_putc_c:			dw var_putc_c
ntc_rg337_e:
			IF ($ < 32768) && (ntc_rg338_e - ntc_rg338 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg338:
llit_65536:			dw 0, 1
ntc_rg338_e:
			IF ($ < 32768) && (ntc_rg339_e - ntc_rg339 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg339:
lit_m2425:			dw -2425
ntc_rg339_e:
			IF ($ < 32768) && (ntc_rg340_e - ntc_rg340 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg340:
lit_m2424:			dw -2424
ntc_rg340_e:
			IF ($ < 32768) && (ntc_rg341_e - ntc_rg341 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg341:
lit_4:			dw 4
ntc_rg341_e:
			IF ($ < 32768) && (ntc_rg342_e - ntc_rg342 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg342:
lit_m2422:			dw -2422
ntc_rg342_e:
			IF ($ < 32768) && (ntc_rg343_e - ntc_rg343 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg343:
lit_15:			dw 15
ntc_rg343_e:
			IF ($ < 32768) && (ntc_rg344_e - ntc_rg344 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg344:
lit_13:			dw 13
ntc_rg344_e:
			IF ($ < 32768) && (ntc_rg345_e - ntc_rg345 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg345:
vp_var_topadd_s:			dw var_topadd_s
ntc_rg345_e:
			IF ($ < 32768) && (ntc_rg346_e - ntc_rg346 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg346:
lit_9:			dw 9
ntc_rg346_e:
			IF ($ < 32768) && (ntc_rg347_e - ntc_rg347 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg347:
lit_3:			dw 3
ntc_rg347_e:
			IF ($ < 32768) && (ntc_rg348_e - ntc_rg348 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg348:
lit_m4352:			dw -4352
ntc_rg348_e:
			IF ($ < 32768) && (ntc_rg349_e - ntc_rg349 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg349:
lit_4096:			dw 4096
ntc_rg349_e:
			IF ($ < 32768) && (ntc_rg350_e - ntc_rg350 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg350:
lit_m3328:			dw -3328
ntc_rg350_e:
			IF ($ < 32768) && (ntc_rg351_e - ntc_rg351 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg351:
lit_768:			dw 768
ntc_rg351_e:
			IF ($ < 32768) && (ntc_rg352_e - ntc_rg352 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg352:
lit_m2432:			dw -2432
ntc_rg352_e:
			IF ($ < 32768) && (ntc_rg353_e - ntc_rg353 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg353:
lit_m2344:			dw -2344
ntc_rg353_e:
			IF ($ < 32768) && (ntc_rg354_e - ntc_rg354 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg354:
lit_12:			dw 12
ntc_rg354_e:
			IF ($ < 32768) && (ntc_rg355_e - ntc_rg355 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg355:
lit_m2343:			dw -2343
ntc_rg355_e:
			IF ($ < 32768) && (ntc_rg356_e - ntc_rg356 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg356:
lit_m2417:			dw -2417
ntc_rg356_e:
			IF ($ < 32768) && (ntc_rg357_e - ntc_rg357 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg357:
lit_8:			dw 8
ntc_rg357_e:
			IF ($ < 32768) && (ntc_rg358_e - ntc_rg358 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg358:
lit_32:			dw 32
ntc_rg358_e:
			IF ($ < 32768) && (ntc_rg359_e - ntc_rg359 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg359:
lit_m2416:			dw -2416
ntc_rg359_e:
			IF ($ < 32768) && (ntc_rg360_e - ntc_rg360 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg360:
vp_var_ob:			dw var_ob
ntc_rg360_e:
			IF ($ < 32768) && (ntc_rg361_e - ntc_rg361 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg361:
lit_103:			dw 103
ntc_rg361_e:
			IF ($ < 32768) && (ntc_rg362_e - ntc_rg362 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg362:
lit_256:			dw 256
ntc_rg362_e:
			IF ($ < 32768) && (ntc_rg363_e - ntc_rg363 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg363:
lit_m3332:			dw -3332
ntc_rg363_e:
			IF ($ < 32768) && (ntc_rg364_e - ntc_rg364 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg364:
lit_m3330:			dw -3330
ntc_rg364_e:
			IF ($ < 32768) && (ntc_rg365_e - ntc_rg365 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg365:
lit_m2:			dw -2
ntc_rg365_e:
			IF ($ < 32768) && (ntc_rg366_e - ntc_rg366 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg366:
lit_128:			dw 128
ntc_rg366_e:
			IF ($ < 32768) && (ntc_rg367_e - ntc_rg367 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg367:
vp_var_b:			dw var_b
ntc_rg367_e:
			IF ($ < 32768) && (ntc_rg368_e - ntc_rg368 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg368:
lit_129:			dw 129
ntc_rg368_e:
			IF ($ < 32768) && (ntc_rg369_e - ntc_rg369 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg369:
vp_var_a:			dw var_a
ntc_rg369_e:
			IF ($ < 32768) && (ntc_rg370_e - ntc_rg370 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg370:
lit_m2427:			dw -2427
ntc_rg370_e:
			IF ($ < 32768) && (ntc_rg371_e - ntc_rg371 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg371:
lit_m1:			dw -1
ntc_rg371_e:
			IF ($ < 32768) && (ntc_rg372_e - ntc_rg372 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg372:
lit_23:			dw 23
ntc_rg372_e:
			IF ($ < 32768) && (ntc_rg373_e - ntc_rg373 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg373:
lit_64:			dw 64
ntc_rg373_e:
			IF ($ < 32768) && (ntc_rg374_e - ntc_rg374 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg374:
lit_65:			dw 65
ntc_rg374_e:
			IF ($ < 32768) && (ntc_rg375_e - ntc_rg375 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg375:
lit_57:			dw 57
ntc_rg375_e:
			IF ($ < 32768) && (ntc_rg376_e - ntc_rg376 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg376:
lit_56:			dw 56
ntc_rg376_e:
			IF ($ < 32768) && (ntc_rg377_e - ntc_rg377 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg377:
lit_49:			dw 49
ntc_rg377_e:
			IF ($ < 32768) && (ntc_rg378_e - ntc_rg378 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg378:
lit_48:			dw 48
ntc_rg378_e:
			IF ($ < 32768) && (ntc_rg379_e - ntc_rg379 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg379:
lit_41:			dw 41
ntc_rg379_e:
			IF ($ < 32768) && (ntc_rg380_e - ntc_rg380 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg380:
lit_40:			dw 40
ntc_rg380_e:
			IF ($ < 32768) && (ntc_rg381_e - ntc_rg381 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg381:
lit_33:			dw 33
ntc_rg381_e:
			IF ($ < 32768) && (ntc_rg382_e - ntc_rg382 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg382:
lit_66:			dw 66

ntc_rg382_e:
			IF ($ < 32768) && (ntc_rg383_e - ntc_rg383 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg383:
; ============================================================
; Strings
; ============================================================

ntc_rg383_e:
			IF ($ < 32768) && (ntc_rg384_e - ntc_rg384 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg384:
str0:			db "CyborgOS needs 320K (a 256K expansion) or more", 0
ntc_rg384_e:
			IF ($ < 32768) && (ntc_rg385_e - ntc_rg385 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg385:
str1:			db "Press a key", 0
ntc_rg385_e:
			IF ($ < 32768) && (ntc_rg386_e - ntc_rg386 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg386:
str2:			db 0
ntc_rg386_e:
			IF ($ < 32768) && (ntc_rg387_e - ntc_rg387 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg387:
str3:			db " KEYREP ", 0
ntc_rg387_e:
			IF ($ < 32768) && (ntc_rg388_e - ntc_rg388 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg388:
str4:			db "CyborgOS ended, ", 0
ntc_rg388_e:
			IF ($ < 32768) && (ntc_rg389_e - ntc_rg389 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg389:
str5:			db " programs ran", 0
ntc_rg389_e:
			IF ($ < 32768) && (ntc_rg390_e - ntc_rg390 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg390:
str6:			db 13, 0
ntc_rg390_e:
			IF ($ < 32768) && (ntc_rg391_e - ntc_rg391 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg391:
str7:			db 10, 0
ntc_rg391_e:
			IF ($ < 32768) && (ntc_rg392_e - ntc_rg392 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg392:
str8:			db 27, 0
ntc_rg392_e:
			IF ($ < 32768) && (ntc_rg393_e - ntc_rg393 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg393:
str9:			db "E", 0
ntc_rg393_e:
			IF ($ < 32768) && (ntc_rg394_e - ntc_rg394 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg394:
str10:			db "[", 0
ntc_rg394_e:
			IF ($ < 32768) && (ntc_rg395_e - ntc_rg395 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg395:
str11:			db "]   ", 0
ntc_rg395_e:
			IF ($ < 32768) && (ntc_rg396_e - ntc_rg396 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg396:
str12:			db "CyborgOS TOP", 0
ntc_rg396_e:
			IF ($ < 32768) && (ntc_rg397_e - ntc_rg397 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg397:
str13:			db "Control + ESC: back, ", 0
ntc_rg397_e:
			IF ($ < 32768) && (ntc_rg398_e - ntc_rg398 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg398:
str14:			db ": that slot", 0
ntc_rg398_e:
			IF ($ < 32768) && (ntc_rg399_e - ntc_rg399 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg399:
str15:			db "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (last second)", 0
ntc_rg399_e:
			IF ($ < 32768) && (ntc_rg400_e - ntc_rg400 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg400:
str16:			db "-", 0
ntc_rg400_e:
			IF ($ < 32768) && (ntc_rg401_e - ntc_rg401 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg401:
str17:			db "command line", 0
ntc_rg401_e:
			IF ($ < 32768) && (ntc_rg402_e - ntc_rg402 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg402:
str18:			db "waiting (key)", 0
ntc_rg402_e:
			IF ($ < 32768) && (ntc_rg403_e - ntc_rg403 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg403:
str19:			db "running", 0
ntc_rg403_e:
			IF ($ < 32768) && (ntc_rg404_e - ntc_rg404 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg404:
str20:			db " ", 0
ntc_rg404_e:
			IF ($ < 32768) && (ntc_rg405_e - ntc_rg405 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg405:
str21:			db "*", 0
ntc_rg405_e:
			IF ($ < 32768) && (ntc_rg406_e - ntc_rg406 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg406:
str22:			db "  ", 0
ntc_rg406_e:
			IF ($ < 32768) && (ntc_rg407_e - ntc_rg407 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg407:
str23:			db "Total memory: ", 0
ntc_rg407_e:
			IF ($ < 32768) && (ntc_rg408_e - ntc_rg408 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg408:
str24:			db " KB   Free memory: ", 0
ntc_rg408_e:
			IF ($ < 32768) && (ntc_rg409_e - ntc_rg409 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg409:
str25:			db " KB", 0
ntc_rg409_e:
			IF ($ < 32768) && (ntc_rg410_e - ntc_rg410 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg410:
str26:			db "CyborgOS slot ", 0
ntc_rg410_e:
			IF ($ < 32768) && (ntc_rg411_e - ntc_rg411 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg411:
str27:			db " of ", 0
ntc_rg411_e:
			IF ($ < 32768) && (ntc_rg412_e - ntc_rg412 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg412:
str28:			db " - ", 0
ntc_rg412_e:
			IF ($ < 32768) && (ntc_rg413_e - ntc_rg413 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg413:
str29:			db ", Control + ESC TOP, HELP", 0
ntc_rg413_e:
			IF ($ < 32768) && (ntc_rg414_e - ntc_rg414 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg414:
str30:			db "Control + 1-", 0
ntc_rg414_e:
			IF ($ < 32768) && (ntc_rg415_e - ntc_rg415 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg415:
str31:			db "Control + 1-9, 0", 0
ntc_rg415_e:
			IF ($ < 32768) && (ntc_rg416_e - ntc_rg416 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg416:
str32:			db "Control + 1-9, 0 (twice 11-", 0
ntc_rg416_e:
			IF ($ < 32768) && (ntc_rg417_e - ntc_rg417 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg417:
str33:			db ")", 0
ntc_rg417_e:
			IF ($ < 32768) && (ntc_rg418_e - ntc_rg418 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg418:
str34:			db "> ", 0
ntc_rg418_e:
			IF ($ < 32768) && (ntc_rg419_e - ntc_rg419 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg419:
str35:			db ":", 0
ntc_rg419_e:
			IF ($ < 32768) && (ntc_rg420_e - ntc_rg420 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg420:
str36:			db "CV", 0
ntc_rg420_e:
			IF ($ < 32768) && (ntc_rg421_e - ntc_rg421 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg421:
str37:			db "CLS", 0
ntc_rg421_e:
			IF ($ < 32768) && (ntc_rg422_e - ntc_rg422 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg422:
str38:			db "RUN", 0
ntc_rg422_e:
			IF ($ < 32768) && (ntc_rg423_e - ntc_rg423 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg423:
str39:			db "no slot", 0
ntc_rg423_e:
			IF ($ < 32768) && (ntc_rg424_e - ntc_rg424 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg424:
str40:			db "slot", 0
ntc_rg424_e:
			IF ($ < 32768) && (ntc_rg425_e - ntc_rg425 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg425:
str41:			db " is busy", 0
ntc_rg425_e:
			IF ($ < 32768) && (ntc_rg426_e - ntc_rg426 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg426:
str42:			db "QUIT", 0
ntc_rg426_e:
			IF ($ < 32768) && (ntc_rg427_e - ntc_rg427 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg427:
str43:			db "RUN what?", 0
ntc_rg427_e:
			IF ($ < 32768) && (ntc_rg428_e - ntc_rg428 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg428:
str44:			db ".", 0
ntc_rg428_e:
			IF ($ < 32768) && (ntc_rg429_e - ntc_rg429 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg429:
str45:			db ".CYB", 0
ntc_rg429_e:
			IF ($ < 32768) && (ntc_rg430_e - ntc_rg430 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg430:
str46:			db ".COM", 0
ntc_rg430_e:
			IF ($ < 32768) && (ntc_rg431_e - ntc_rg431 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg431:
str47:			db "RUN ", 0
ntc_rg431_e:
			IF ($ < 32768) && (ntc_rg432_e - ntc_rg432 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg432:
str48:			db " runs in slot", 0
ntc_rg432_e:
			IF ($ < 32768) && (ntc_rg433_e - ntc_rg433 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg433:
str49:			db "? ", 0
ntc_rg433_e:
			IF ($ < 32768) && (ntc_rg434_e - ntc_rg434 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg434:
str50:			db " (HELP)", 0
ntc_rg434_e:
			IF ($ < 32768) && (ntc_rg435_e - ntc_rg435 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg435:
str51:			db ": not found", 0
ntc_rg435_e:
			IF ($ < 32768) && (ntc_rg436_e - ntc_rg436 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg436:
str52:			db " ended]", 0

ntc_rg436_e:
			IF ($ < 32768) && (ntc_rg437_e - ntc_rg437 + $ > 16384)	; fwdref-ok
			ds #4000 - $		; the window data (; @window), from #4000
			ntc_windata
			ASSERT $ <= 32768, "the window data (; @window) must fit in the window"
			ds 32768 - $		; Option Reserve #4000-#7FFF: round it
			ENDIF
ntc_rg437:
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
NTC_RJ_N	equ 82		; entries
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
ntc_rg437_e:
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
			ASSERT (ntc_free <= 16384) || (ntc_bss >= 32768), "the program (or its arrays) reaches into Option Reserve #4000-#7FFF (Main.bas line 25)"
			SAVEAMSDOS "CYBORGOS.BIN", ntc_start, ntc_fileend - ntc_start, ntc_start

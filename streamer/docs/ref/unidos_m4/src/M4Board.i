;
; m4board constants
;


; I/O Ports

DataPort                Equ &fe00
AckPort                 Equ &fc00


; Command codes

C_OPEN                  Equ &4301 ; data[0] = mode, data[1] = filename. Return data[0] = fd (*), data[1] = res.
                                  ; OffseT: this is also handling read/write file default extensions, msglen is ignored
C_READ                  Equ &4302 ; data[0] = fd, data[1..2] = read size. Return data[0] = res, data[1..] = data.
                                  ; OffseT: This is not skipping header as stated in C_READ2 description!
C_WRITE                 Equ &4303 ; data[0] = fd, data[1..] = data. Return data[0] = res.
C_CLOSE                 Equ &4304 ; data[0] = fd. Return data[0] = res.
                                  ; OffseT: msglen ignored
C_SEEK                  Equ &4305 ; data[0] = fd, data[1..4] = offset. Return data[0] = res.
                                  ; OffseT: msglen ignored
C_READDIR               Equ &4306 ; No args. Return data[0] = dir entry (formatted). Loop until response size == 2.
                                  ; From v110 b9, one argument can be given data[0] = max name len (to support lfn).
                                  ; OffseT: When max name len is not provided entry is returned as a single formatted 17 chars formatted string:
                                  ;                     For files      : "FILENAME.EXT 000K"
                                  ;                     For directories: ">DIRECTORYNAMEXXX"
                                  ;               When max name len is provided entry is returned as fllowed:
                                  ;                     For files, two string are returned (name, then formatted size in K/M/G...)
                                  ;                     For directories, only one string is returned (beginning with '>' char
C_EOF                   Equ &4307 ; data[0] = fd. Return data[0] == 0 (not eof). Only valid for read fd.
C_CD                    Equ &4308 ; data[0...] = "directory name". Return data[0] = res.
                                  ; OffseT: Always returns -1 in case of error?
C_FREE                  Equ &4309 ; Freespace sd card / DSK image.  Return data[0] = "\r\n%iK free\r\n\r\n".
C_FTELL                 Equ &430A ; Implemented v1.0.5. data[0] = fd. Return data[0-3] = current file pos
C_READSECTOR            Equ &430B ; For diskimages only. data[0] = track, data[1] = sector, data[2] = drive (not used). Return data[0] = res. data[1..513] sector data
C_WRITESECTOR           Equ &430C ; For diskimages only. data[0] = track, data[1] = sector, data[2] = drive (not used) data[3..515] sector data
C_FORMATTRACK           Equ &430D ; Not implemented yet
C_ERASEFILE             Equ &430E ; data[0] = "filename". Return data[0] = res;
                                  ; OffseT: looks like it also returns data[1..] "ascii error"
C_RENAME                Equ &430F ; data[0] = "newname\0oldname": Return data[0] = res, data[1..] "ascii error".
                                  ; OffseT: looks like it is actually: "oldname\0newname"
C_MAKEDIR               Equ &4310 ; data[0] = "dirname". Return data[0] = res;
                                  ; OffseT: looks like it also returns data[1..] "ascii error"
C_FSIZE                 Equ &4311 ; Implemented v1.0.5. data[0] = fd. Return data[0-3] = file size
                                  ; OffseT: Returns -1 in case of error?
C_READ2                 Equ &4312 ; Implemented v1.0.7. Same as C_READ, except without checking (and seeking past) for AMSDOS header.
                                  ; OffseT: not the same a C_READ! data[4..7] = read size, data[8..] = data, msglen ignored
C_GETPATH               Equ &4313 ; Implemented v1.0.8. Return data = current path in ascii.
C_SDREAD                Equ &4314 ; Implemented v1.0.9. Read RAW sdcard sector. data[0..3] = Physical LBA, data[4] = numsectors (max. 4).
                                  ; return data[0] = error. data[1..] = sector data
C_SDWRITE               Equ &4315 ; Implemented v1.0.9. Write RAW sdcard sector. data[0..3] = Physical LBA, data[4] = numsectors (max. 4),
                                  ; data[5..] sector data.  Return data[0] = error.
                                  ; Error codes for C_SDREAD & C_SDWRITE: 0: Successful, 1: R/W Error, 2: Write Protected, 3: Not Ready, 4: Invalid Parameter
C_FSTAT                 Equ &4316 ; Implemented v1.1.0. File stat. data[0]=file/dir.  Return:
                                  ;         data[0] = error (0 = ok).
                                  ;         data[1..4] = File size in bytes.
                                  ;         data[5..6] = Date. bit15:9 Year origin from 1980 (0..127) bit8:5 Month (1..12) bit4:0  Day (1..31)
                                  ;         data[7..8] = Time. bit15:11 Hour (0..23) bit10:5 Minute (0..59) bit4:0 Second / 2 (0..29)
                                  ;         data[9] = Attrib. &01 Read only, &02 Hidden, &04 System, &10 Directory, &20 Archive.
                                  ;         data[10..22] = Short name.
                                  ;         data[23..280] = Long name.
C_SNAFLAT               Equ &4317 ; OffseT: data[0] = fd. Return data[0] = SNA memory size in KB (fd now points to uncompressed SNA memory data)
C_ROMSOFF               Equ &4318
C_NMIOFF                Equ &4319 ; OffseT: No args (msglen ignored). Disable NMI rom in "next" RMR write
C_RAMDISOFF             Equ &431A ; OffseT: No args (msglen ignored). Disable both /RAMDIS and /NIM signals
C_WRITE2                Equ &431B ; OffseT: data[0] = fd, data[1..2] = write size. data[3..] = data. Return data[0] = res.
                                  ; max = &400?, msglen ignored
C_COPYFILE2             Equ &431C ; OffseT: msglen ignored, is this the only difference with C_COPYFILE?
C_NMI                   Equ &431D ; Implemented v2.0.5. No args. Trigger NMI/Hackmenu
C_HTTPGET               Equ &4320 ; data[0] = "url:port/file". Return data[0] = "Downloaded...".
C_SETNETWORK            Equ &4321 ; data[0] = setupstring (see |netset above).
C_M4OFF                 Equ &4322 ; No args. Disable M4 rom and reset.
C_NETSTAT               Equ &4323 ; No args. Return data[0] = "network status string".
                                  ;         From v1.1.0 there is a status byte after the return string, which can be:
                                  ;         0 = Idle.
                                  ;         1 = Connecting.
                                  ;         2 = Wrong password
                                  ;         3 = No accesspoint found
                                  ;         4 = Connection failed
                                  ;         5 = Connected (and got IP)
                                  ;         Rest are unknown status (ERROR!)
C_TIME                  Equ &4324 ; No args. Return data[0] = "hh:mm:ss yyyy-mm-dd".
C_DIRSETARGS            Equ &4325 ; data[0] = "folder/match string" (wildcards etc.) Should be used before C_READDIR, if no args, use null string.
C_VERSION               Equ &4326 ; No args. Return current M4 and ESP version strings.
C_UPGRADE               Equ &4327 ; No args. Downloads upgrades from internet, if newer version available.
C_HTTPGETMEM            Equ &4328 ; data[0..1] = size, data[2] = "url:port/file, offset=". Return data[0..1] = downloaded size. (into internal buf, see C_COPYBUF).
C_COPYBUF               Equ &4329 ; data[0..1] = offset into internal buf (0..3FFF), data[2..3] = size. Returns data[0] = data (dest).
C_COPYFILE              Equ &432A ; data[0..] = "srcfile\0destfile\0". Return data[0] = res, data[1..] = ascii error..
                                  ; OffseT: Argument are in the opposite "destfile\0srcfile\0"
C_ROMSUPDATE            Equ &432B ; No Args and return. Updates romchanges made to romconfig.bin and romslots.bin without rebooting.
C_ROMLIST               Equ &432C
C_CMDRBTRUN             Equ &432D
C_CTRBOOT               Equ &432E
C_CTRUPLOAD             Equ &432F ; OffseT: data[0..] = "cpr name". No result!
C_DSKEXT                Equ &4330 ; OffseT: data[0..] = "destpath\0srcdsk": Return data[0] = res, data[1..] "ascii error".
C_NETSOCKET             Equ &4331 ; Implemented v1.0.9. data[0] = domain, data[1] = type, data[2] = protocol. Return data[0] = socket number or &FF (error).
                                  ; Only TCP protocol for now.
C_NETCONNECT            Equ &4332 ; Implemented v1.0.9. data[0] = socket, data[1..4] = ip, data[5-6] = port. Return data[0] = 0 (OK) or ERROR &FF.
C_NETCLOSE              Equ &4333 ; Implemented v1.0.9. data[0] = socket.
C_NETSEND               Equ &4334 ; Implemented v1.0.9. data[0] = socket, data[1..2] = size, data[3...] = outgoing data. Return data[0] = 0 OK, &FF error.
C_NETRECV               Equ &4335 ; Implemented v1.0.9. data[0] = socket, data[1..2] = receive size (don't flood buffer, max. &800).
                                  ; OffseT: Return data[0] = 0 OK, data[1..2] = received size, data[3..] = data
                                  ; Return data[0] = 0. data[1..2] = actual received size. data[3...] = received data. Look at sockinfo for status.
C_NETHOSTIP             Equ &4336 ; Implemented v1.0.9. data[0..] = hostname string\0. Return data[0] = 1 Lookup in progress. Any other = error. Look in M4rom sockinfo for IP and status
C_NETRSSI               Equ &4337 ; Implemented v1.0.9. No args. Return RSSI value for connection (31 = fail, rest? = signal strength).
C_NETBIND               Equ &4338 ; Implemented v1.0.9. data[0] = socket, data[1..4] = IP number, data[5..6] = port number. return 0 = ok otherwise error.
C_NETLISTEN             Equ &4339 ; Implemented v1.0.9. data[0] = socket. Return return 0 = ok otherwise error.
C_NETACCEPT             Equ &433A ; Implemented v1.0.9. data[0] = socket. Return return 0 = ok otherwise error. Refer to sockinfo for status.
C_GETNETWORK            Equ &433B ; Implemented v1.1.0. No args. Returns the following structure:
                                  ;         char name[15+1];                    ; 0
                                  ;         unsigned char ssid[32];             ; 16
                                  ;         unsigned char password[64];         ; 48
                                  ;         unsigned int ip;                    ; 112
                                  ;         unsigned int nm;                    ; 116
                                  ;         unsigned int gw;                    ; 120
                                  ;         unsigned int dns1;                  ; 124
                                  ;         unsigned int dns2;                  ; 128
                                  ;         unsigned int dhcp;                  ; 132
                                  ;         int timezone;                       ; 136
                                  ;         unsigned char ntpserver[48];        ; 140
                                  ;         unsigned char reserved1;            ; 188
                                  ;         unsigned char reserved2;            ; 189
                                  ;         unsigned char mac[6];               ; 190
C_WIFIPOW               Equ &433C ; Implemented ?. WiFi power data[0] = 0 turn OFF power, 1 = turn ON power.
C_ROMCP                 Equ &43FC ; Implemented ?. ROM copy within M4 ROMS (RAM) data[0-1] = dest offset, data[2] = src bank (0 for M4 rom, not used yet), data[3-4] = src offset, data[5] = dest bank (0 for M4 rom, not used yet), data[6-7] = size
C_ROMWRITE              Equ &43FD ; Implemented ?. Write to ROM (M4 or HACK/NMI rom). data[0-1] = dest offset, data[2-3] = size, data[4] = rom (255 = NMI/HACK ROM, 0 = M4 ROM).
                                  ; OffseT: data[5...] are the actual data to be written
                                  ;         dest offset bit 14 and 15 are ignored!
C_CONFIG                Equ &43FE ; Write to M4 ROM config area. data[0] = offset in config area (&FF04+offset), using command size(-3).
C_ROMLOW                Equ &433D ; Implemented v2.0.7. Map lower rom : data[0] = 0 system lower rom, 1 = lowerrom from romboard if enabled, 2 = lowerrom from HACK menu.
C_WRITE_COC             Equ &4343


; C_OPEN flags:
; For system compatiblity, there is two file descriptors like AMSDOS 1 = read, 2 = write.
; However if you OR the open mode with &80, you get "real mode" fatfs and can have 10 open file descriptors, this is recommended for any developers.
FA_OPEN_EXISTING        Equ &00
FA_READ                 Equ &01
FA_WRITE                Equ &02
FA_CREATE_NEW           Equ &04
FA_CREATE_ALWAYS        Equ &08
FA_OPEN_ALWAYS          Equ &10
FA_REALMODE             Equ &80


; Error codes for file handling

FR_OK                   Equ 0
FR_DISK_ERR             Equ 1
FR_INT_ERR              Equ 2
FR_NOT_READY            Equ 3
FR_NO_FILE              Equ 4
FR_NO_PATH              Equ 5
FR_INVALID_NAME         Equ 6
FR_DENIED               Equ 7
FR_EXIST                Equ 8
FR_INVALID_OBJECT       Equ 9
FR_WRITE_PROTECTED      Equ 10
FR_INVALID_DRIVE        Equ 11
FR_NOT_ENABLED          Equ 12
FR_NO_FILESYSTEM        Equ 13
FR_MKFS_ABORTED         Equ 14
FR_TIMEOUT              Equ 15
FR_LOCKED               Equ 16
FR_NOT_ENOUGH_CORE      Equ 17
FR_TOO_MANY_OPEN_FILES  Equ 18
FR_INVALID_PARAMETER    Equ 19
FR_END_OF_FILE_REACHED  Equ 20 ; OffseT


; Réseau

SOCK_STS_IDLE           Equ 0
SOCK_STS_CONNECT        Equ 1 ; Connection in progress
SOCK_STS_SEND           Equ 2 ; Send in progress
SOCK_STS_CLOSED         Equ 3 ; Remote closed connection
SOCK_STS_ACCEPT         Equ 4 ; Wait incoming connection (accept)
SOCK_STS_LOOKUP         Equ 5 ; Wait for DNS lookup

; Error codes of commands

CR_COMMAND_FAILURE      Equ -1


; Hardcoded offsets into NMI ROM

NMIROM_M4ROM            Equ &0000 ; M4 ROM slot
NMIROM_PENSEL           Equ &012e ; Pen selection
NMIROM_PALETTE          Equ &012f ; Palette
NMIROM_RMR              Equ &0140 ; RMR
NMIROM_MMR              Equ &0141 ; MMR
NMIROM_CRTCSEL          Equ &0142 ; CRTC register selection
NMIROM_CRTCREG          Equ &0143 ; CRTC registers
NMIROM_ROMNUM           Equ &0155 ; Upper ROM number
NMIROM_PPIA             Equ &0156 ; PPI port A
NMIROM_PPIB             Equ &0157 ; PPI port B
NMIROM_PPIC             Equ &0158 ; PPI port C
NMIROM_PPICTRL          Equ &0159 ; PPI control port
NMIROM_PSGSEL           Equ &015a ; PSG register selection
NMIROM_PSGREG           Equ &015b ; PSG registers


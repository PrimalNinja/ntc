; ============================================================
; Streamer - a UniDOS node: devices are categories, their folders are
; paths on the Pi's store, their CMD is one conversation with the Pi
; (CyborgOS for the Pi: cosd - cyborg-os/docs/cyborgos-pi.md and
; cyborgos-vdp.md) over a CPC-CPLink / CPLink2 (&FD80 data, &FD81
; status: bit 0 a byte waiting, bit 1 room).
; (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
; ============================================================
;   GRAPHICS:CMD        OPENOUT it, PRINT #9 the VDP's command bytes
;                       (cyborgos-vdp.md section 4, opcodes below #80)
;                       and the node's own (#80 up, below); 80 OPEN
;                       names the profile: "vdp profile=v9990 vsync=1"
;   GRAPHICS:EVENTS     OPENIN it, LINE INPUT #9: the Pi's events and
;                       answers, a line each
;   GRAPHICS:V9990/PATTERNS, TILES, LAYER2 (and V9938/, ZXNEXT/, MD/,
;                       PINATIVE/): assets - a SAVE into one is a PUT
;                       of the store tag GRAPHICS/V9990/PATTERNS on the
;                       Pi, which keeps the profile's set and loads it
;                       when a CMD opens that profile. A LOAD reads one
;                       back (GET). CAT lists what the Pi has
;   SPEECH:CMD          85 TARGET n first (0 SSA1 card, 1 DKTRONIC card,
;                       2 VOTRAX on the Pi); then the bytes: allophones
;                       to a card (written when its /LRQ says), or
;                       phonemes to the Pi (DATA); SPEECH:EVENTS
;   MUSIC:CMD           a line a request to the Pi's audio service,
;                       after 80 OPEN "audio"; MUSIC:EVENTS the answers;
;                       MUSIC:MP3/, 8BIT/, 4BIT/, SID/, AY38912/ the music
;                       installed by type (PLAY MUSIC/MP3/TITLE.MP3)
;   STORE:path          the Pi's tagged store as files: SAVE / LOAD /
;                       CAT / OPENOUT / OPENIN; a folder is a tag's /
; The node's opcodes, in any CMD:
;   80 OPEN len text    the category's channel to the service named:
;                       OK n / ERR back on EVENTS
;   81 CLOSE  82 RESET  83 LIST (the Pi's services, on EVENTS)
;   84 END (an asset's last part now)   85 TARGET n (SPEECH)
; BASIC's OPENOUT / OPENIN / CLOSEOUT / CLOSEIN only choose the stream.
; HELLO goes once. The normalized path UniDOS gives (DE: a count, then
; 11-character names) is what a folder is read from - Albireo's node
; reads it the same way. The old node is _old/.
; ============================================================
		DEVICE AMSTRADCPC6128
		org #C000
		output "../build/streamer.rom"

LINK_DATA	equ #FD80
LINK_STAT	equ #FD81
; the node's scratch (UniDOS leaves the top of the firmware's area to a node's small needs; the
; old node used #BE80): the channel, the open file, a frame header being read
WORK		equ #BE80
w_chans		equ WORK + 20		; a device's channel on the link (0: not open), NDEV bytes - GetChan / SetChan
w_store		equ WORK + 28		; the store's channel (0: not open) - assets and STORE: go there
w_tgt		equ WORK + 29		; SPEECH's target: 0 SSA1, 1 DKTRONIC, 2 VOTRAX (the Pi)
w_more		equ WORK + 30		; a GET being read: 1 another part follows
w_lst		equ WORK + 31		; a listing: 1 from the Pi's LIST (records), 0 the root files, 2 its folders
w_size		equ WORK + 32		; a LIST record's size (4)
w_flag		equ WORK + 36		; its flag (#10 a folder)
TAG		equ #BEB0		; the tag being built: DEVICE/FOLDER/NAME.EXT, 0-ended (#BEB0-#BEDF, 48 bytes; verify on UniDOS)
w_file		equ WORK + 1		; the stream open: 1 CMD, 2 PATTERNS, 3 EVENTS, 0 none
w_id		equ WORK + 2		; the next request id
w_hdr		equ WORK + 3		; a frame's header read: chan type id lenlo lenhi (5 bytes)
w_left		equ WORK + 8		; payload bytes left in the frame being read (2)
w_dev		equ WORK + 10		; the device number of the stream open
w_sum		equ WORK + 11		; the check being formed
w_pass		equ WORK + 12		; bytes of a VDP command still to pass through (2)
w_hello		equ WORK + 14		; 1: HELLO sent
w_len		equ WORK + 15		; the frame being read: its length (2)
w_chan		equ WORK + 17		; the channel of the stream open (set at open from w_chans)

; ---- the ROM header and UniDOS's node table
ROMType		db 2			; an expansion ROM
ROMMark		db 1
ROMVer		db 0
ROMRev		db 1
		dw RSXTable
		jp InitROM
		jp Node_Init
		jp Node_CheckDrive
		jp Node_GetStatus
		jp Node_GetName
		jp Node_GetDesc
		jp Node_GetFreeSpace
		jp Node_InOpen
		jp Node_InRead
		jp Node_InClose
		jp Node_Fail		; InSeek
		jp Node_OutOpen
		jp Node_OutWrite
		jp Node_OutClose
		jp Node_Fail		; OutSeek
		jp Node_Examine
		jp Node_ExamineNext
		jp Node_Fail		; Rename
		jp Node_Fail		; Delete
		jp Node_Fail		; CreateDir
		jp Node_Fail		; SetProtection
		jp Node_Fail		; Format
		jp Node_Fail		; SetFileDate
		jp Node_Void
		jp Node_Void
		jp Node_Void
		jp Node_Fail		; ReadRTC
		jp Node_Fail		; WriteRTC
		jp Node_Fail		; OpenNVRAM
		jp Node_Fail		; CloseNVRAM
		jp Node_Fail		; ReadNVRAM
		jp Node_Fail		; WriteNVRAM
		jp Node_Fail		; SeekNVRAM

RSXTable	db "STREAME", "R" + #80
		db "DOS Nod", "e" + #80
		db 0
InitROM		or a			; nothing to add to the firmware
		scf
		ret

; ---- the devices (categories): name (bit 7 on the last letter), 0, number, the store prefix (the
; tag a folder's file goes under, 0-ended), the root file list (dw), the root folder list (dw)
Devices		db "GRAPHIC", "S" + #80, 0, 0
		db "GRAPHICS", 0
		dw FilesCmd, FoldersGfx
		db "SPEEC", "H" + #80, 0, 1
		db "SPEECH", 0
		dw FilesCmd, FoldersNone
		db "MUSI", "C" + #80, 0, 2
		db "MUSIC", 0
		dw FilesCmd, FoldersMusic
		db "STOR", "E" + #80, 0, 3
		db "", 0
		dw FilesNone, FoldersNone
		db 0
NDEV		equ 4
DevDesc		db "the Pi: a category as path", "s" + #80, 0
; kinds: 1 CMD (the conversation), 3 EVENTS, 6 a line a request (MUSIC's CMD), 10 an asset / store
; file (PUT in parts; GET on read)
FilesCmd	db "CMD        ", 1
		db "EVENTS     ", 3
		db 0
FilesNone	db 0
FoldersGfx	db "V9990      "
		db "V9938      "
		db "ZXNEXT     "
		db "MD         "
		db "PINATIVE   "
		db 0
FoldersNone	db 0
FoldersMusic	db "MP3        "	; MP3 files
		db "8BIT       "	; 8-bit unsigned samples at 12324 Hz (NTC's Stream.cls .MUS)
		db "4BIT       "	; 4-bit samples (to come on the Pi)
		db "SID        "	; SID tunes (sidplayfp)
		db "AY38912    "	; AY .ym / .vgm (vgmplay), .ay (gme)
		db "VGM        "	; Mega Drive, Master System, arcade .vgm / .vgz (vgmplay)
		db "FM         "	; Adlib OPL2 / OPL3 .imf .dro .rad .d00 (adplay)
		db "MOD        "	; .mod .xm .s3m .it (xmp)
		db "MIDI       "	; .mid with a soundfont (fluidsynth)
		db "GME        "	; .nsf .gbs .spc .hes .kss .sap (mpv with libgme)
		db 0
; the speech cards: an SP0256-AL2 each - port (data and status, the same), the status bit that is
; /LRQ (0 = ready). From the cards' documentation (cpcwiki): SSA-1 &FBEE bit 6; dk'tronics &FBFE bit 7
Cards		dw #FBEE
		db 6
		dw #FBFE
		db 7

; ---- the exits: carry set found / supported, clear not; Z the result
Node_Fail	and a			; carry clear, A kept (CheckDrive must keep A) - not "ccf"
		ret
Node_Success	scf
		ret
Node_Void	ret
Node_Init	jp Node_Success

; CheckDrive: HL the name (bit 7 may be set on a character), C its length; carry and A the device
Node_CheckDrive	push bc
		push de
		push hl
		push af			; (A kept when the name isn't ours)
		ld de, Devices
cd_dev		ld a, (de)
		or a
		jr z, cd_none
		push hl
		push de
		ld b, c
cd_cmp		ld a, (de)
		xor (hl)
		and #7F
		jr nz, cd_next
		ld a, (de)
		inc hl
		inc de
		djnz cd_cmp
		and #80			; the name ended where the device's did (bit 7 on its last letter)
		jr z, cd_next
		pop de
		pop hl
		; skip to the device number: past the name's last letter and the 0
cd_skip		ld a, (de)
		inc de
		or a
		jr nz, cd_skip
		ld a, (de)
		pop hl			; (the saved AF: dropped)
		pop hl
		pop de
		pop bc
		scf
		ret
cd_next		pop de
		pop hl
cd_sk2		ld a, (de)		; to the end of this entry: name 0 num profile 0
		inc de
		or a
		jr nz, cd_sk2
		inc de
cd_sk3		ld a, (de)
		inc de
		or a
		jr nz, cd_sk3
		inc de
		inc de			; the file list's dw
		inc de
		inc de			; the folder list's dw
		jr cd_dev
cd_none		pop af
		pop hl
		pop de
		pop bc
		jp Node_Fail

; a device number in A: carry if it is ours (A below NDEV: cp leaves carry set)
IsOurs		cp NDEV
		ret
; the device's (w_dev) channel: GetChan -> A and w_chan; SetChan A -> the table and w_chan
GetChan		push hl
		push bc
		ld a, (w_dev)
		ld c, a
		ld b, 0
		ld hl, w_chans
		add hl, bc
		ld a, (hl)
		ld (w_chan), a
		pop bc
		pop hl
		ret
SetChan		push hl
		push bc
		ld (w_chan), a
		ld c, a
		ld a, (w_dev)
		ld b, a
		ld a, c
		ld c, b
		ld b, 0
		ld hl, w_chans
		add hl, bc
		ld (hl), a
		pop bc
		pop hl
		ret

Node_GetStatus	call IsOurs
		ret nc
		ld a, %00110001		; a media, a stream (no $$$ / BAK), the new API
		ret

; GetName: A the device, DE a buffer of 8; the name copied, bit 7 on its last letter
Node_GetName	call IsOurs
		ret nc
		push hl
		call DevEntry		; HL the entry
		call CopyName
		pop hl
		scf
		ret
; GetDesc: A the device, DE a 32-byte buffer
Node_GetDesc	call IsOurs
		ret nc
		push hl
		ld hl, DevDesc
		call CopyName
		pop hl
		scf
		ret
CopyName	ld a, (hl)
		ld (de), a
		inc hl
		inc de
		bit 7, a
		jr z, CopyName
		ret
; DevEntry: A the device -> HL its entry in Devices (the name)
DevEntry	push bc
		push de
		ld hl, Devices
		ld b, a
		inc b
		jr de_test
de_next		ld a, (hl)
		inc hl
		or a
		jr nz, de_next		; past the name and its 0
		inc hl			; the number
de_skp		ld a, (hl)
		inc hl
		or a
		jr nz, de_skp		; past the prefix and its 0
		inc hl
		inc hl			; past the file list's dw
		inc hl
		inc hl			; past the folder list's dw
de_test		djnz de_next
		pop de
		pop bc
		ret
; DevPrefix: A the device -> HL its store prefix text (0-ended; "" for STORE)
DevPrefix	call DevEntry		; HL at the entry's name
dp_1		ld a, (hl)
		inc hl
		or a
		jr nz, dp_1		; past the name and its 0
		inc hl			; past the number: the prefix text
		ret
; DevFiles: A the device -> HL its root file list; DevFolders -> HL its root folder list
DevFiles	call DevPrefix
df_1		ld a, (hl)
		inc hl
		or a
		jr nz, df_1
		ld a, (hl)
		inc hl
		ld h, (hl)
		ld l, a
		ret
DevFolders	call DevPrefix
dfo_1		ld a, (hl)
		inc hl
		or a
		jr nz, dfo_1
		inc hl
		inc hl
		ld a, (hl)
		inc hl
		ld h, (hl)
		ld l, a
		ret

Node_GetFreeSpace
		call IsOurs
		ret nc
		ld hl, 0
		ld de, 0
		ld bc, 0
		xor a
		scf
		ret

; ---- paths. UniDOS's normalized path at DE: a count byte, then that many 11-character names
; (8 + 3, space padded). A path of 0 is a category's root. MakeTag: TAG = the device's prefix, then
; "/" + each path name (8.3, trimmed), then "/" + the file name (HL, 11 characters; HL = 0: none)
MakeTag		push hl
		push de
		push bc
		push hl			; [hl de bc][name]
		ld a, (w_dev)
		call DevPrefix		; HL the prefix
		ld de, TAG
mt_p		ld a, (hl)
		or a
		jr z, mt_pe
		ld (de), a
		inc hl
		inc de
		jr mt_p
mt_pe		pop hl			; the file name   [hl de bc]
		pop bc
		pop bc			; BC = the path pointer (DE at entry)  [hl]
		push bc
		push bc			; [hl][path][path]
		ld a, (bc)		; the count
		push hl			; [hl][path][path][name]
		ld h, b
		ld l, c
		inc hl			; the first name
mt_c		or a
		jr z, mt_ce
		push af
		call TagSlash
		call TagName		; HL's 11 characters as NAME.EXT at DE, HL on by 11
		pop af
		dec a
		jr mt_c
mt_ce		pop hl			; the file name   [hl][path][path]
		ld a, h
		or l
		jr z, mt_end
		call TagSlash
		call TagName
mt_end		xor a
		ld (de), a
		pop bc
		pop bc			; [hl]
		pop de			; (the pushed HL: an original of DE is not needed back)
		ld h, d
		ld l, e
		ret
TagSlash	push af
		ld a, e
		cp low TAG		; nothing yet (STORE's "" prefix): no slash
		jr z, ts_no
		ld a, '/'
		ld (de), a
		inc de
ts_no		pop af
		ret
; TagName: the 11-character name at HL as NAME.EXT at DE (spaces dropped, bit 7 cleared, upper)
TagName		push bc
		ld b, 8
tn_1		ld a, (hl)
		and #7F
		inc hl
		cp ' '
		jr z, tn_2
		ld (de), a
		inc de
tn_2		djnz tn_1
		ld a, (hl)
		and #7F
		cp ' '
		jr z, tn_noext
		ld a, '.'
		ld (de), a
		inc de
		ld b, 3
tn_3		ld a, (hl)
		and #7F
		inc hl
		cp ' '
		jr z, tn_4
		ld (de), a
		inc de
tn_4		djnz tn_3
		pop bc
		ret
tn_noext	inc hl
		inc hl
		inc hl
		pop bc
		ret

; ---- Examine: HL = 0 - a listing of the folder at DE (the root: the category's files and
; folders; deeper, and STORE's root: the Pi's LIST of the tag prefix); HL a name - does it exist
Node_Examine	call IsOurs
		ret nc
		ld (w_dev), a
		push af
		ld a, h
		or l
		jp nz, ex_file
		ld a, (de)
		or a
		jr nz, ex_pi
		ld a, (w_dev)
		cp 3
		jr z, ex_pi		; STORE's root is the Pi's store
		pop af
		call DevFiles
		ld (w_hdr), hl		; the root listing's cursor: the files, then the folders
		xor a
		ld (w_lst), a
		scf
		ret
ex_pi		pop af
		ld hl, 0
		call MakeTag		; TAG = prefix/folders
		call EnsureStore
		ld a, 1
		ld (w_lst), a
		push hl
		push de
		push bc
		ld hl, TAG
		call TextLen		; DE the tag's length
		ld hl, 14
		add hl, de
		ex de, hl		; "LIST " + tag + "/ fmt=cpc"
		ld a, (w_store)
		ld b, 2
		ld c, 4
		call FrameStart
		ld hl, ListPfx
		call FrameText
		ld hl, TAG
		call FrameText
		ld hl, CpcFmt
		call FrameText
		call FrameEnd
lp_ans		call ReadHeader		; the answer: RSP id 4 - its "OK n" line skipped, the entries follow
		ld a, (w_hdr + 1)
		and #7F
		cp 3
		jr nz, lp_skip
		ld a, (w_hdr + 2)
		cp 4
		jr z, lp_got
lp_skip		call SkipFrame
		jr lp_ans
lp_got		ld a, (w_hdr + 1)
		and #80
		ld (w_more), a
lp_line		call LinkIn		; the answer's text ("OK n") to its 0: the records follow
		push af
		ld hl, (w_left)
		dec hl
		ld (w_left), hl
		pop af
		or a
		jr nz, lp_line
		pop bc
		pop de
		pop hl
		xor a
		scf
		ret
ListPfx		db "LIST ", 0
CpcFmt		db "/ fmt=cpc", 0
ex_file		pop af
		call FindFile		; a named file: Z when known
		ld a, 0
		scf
		ret z
		ld a, 1			; not found
		or a
		scf
		ret

; ExamineNext: the next entry - from the root tables (w_lst 0: the files, 12 bytes an entry; then
; w_lst 2: the folders, 11 bytes an entry, bit 4 of A set), or a line of the Pi's LIST (w_lst 1)
Node_ExamineNext
		call IsOurs
		ret nc
		ld a, (w_lst)
		cp 1
		jp z, exn_pi
		push de
		push bc
		or a
		jr nz, exn_fold
		ld de, (w_hdr)		; the files' cursor
		ld a, (de)
		or a
		jr z, exn_tofold
		ld bc, 11
		push hl
		ex de, hl
		ldir			; the 11 characters into UniDOS's buffer
		inc hl			; past the kind byte
		ld (w_hdr), hl
		pop hl
		pop bc
		pop de
		xor a			; a file, size 0
		scf
		ret
exn_tofold	ld a, 2
		ld (w_lst), a
		push hl			; UniDOS's buffer kept (DevFolders returns in HL)
		ld a, (w_dev)
		call DevFolders
		ld (w_hdr), hl
		pop hl
exn_fold	ld de, (w_hdr)
		ld a, (de)
		or a
		jr z, exn_end
		ld bc, 11
		push hl
		ex de, hl
		ldir			; the 11 characters; HL on to the next entry (no kind byte on a folder)
		ld (w_hdr), hl
		pop hl
		pop bc
		pop de
		ld a, #10		; a folder
		cp a			; Z: an entry
		scf
		ret
exn_end		pop bc
		pop de
		ld a, 1
		or a
		scf
		ret
; an entry of the Pi's LIST (fmt=cpc): a 16-byte record - 11 characters the name (into UniDOS's
; buffer at HL), 4 bytes the size (BCDE), a flag byte (A: #10 a folder); the records in the
; answer's parts (MORE: the next part read when one is used up); none left: the end
exn_pi		push hl
		call RecordLeft		; Z: a record is there
		pop hl
		jr nz, exp_end
		push hl
		ld b, 11
exp_n		call LinkIn
		ld (hl), a
		inc hl
		djnz exp_n
		call LinkIn
		ld (w_size), a
		call LinkIn
		ld (w_size + 1), a
		call LinkIn
		ld (w_size + 2), a
		call LinkIn
		ld (w_size + 3), a
		call LinkIn
		ld (w_flag), a
		ld hl, (w_left)
		ld de, 16
		or a
		sbc hl, de
		ld (w_left), hl
		pop hl
		ld de, (w_size)
		ld bc, (w_size + 2)
		ld a, (w_flag)
		scf
		ret
exp_end		ld a, 1
		or a
		scf
		ret
; RecordLeft: is a record in this part, else in the next (MORE)? Z: yes; NZ: no more - the end
RecordLeft	ld hl, (w_left)
		ld a, h
		or l
		jr nz, rl_have
		call LinkIn		; the check of the part just finished
		ld a, (w_more)
		or a
		jr z, rl_none
		call ReadHeader
		ld a, (w_hdr + 1)
		and #80
		ld (w_more), a
rl_txt		call LinkIn		; each part begins with the answer's text and a 0 again
		push af
		ld hl, (w_left)
		dec hl
		ld (w_left), hl
		pop af
		or a
		jr nz, rl_txt
		jr RecordLeft
rl_have		xor a			; Z (a record never straddles parts: the Pi keeps parts whole)
		ret
rl_none		or 1			; NZ
		ret

; FindFile: HL the normalized name (11 characters), DE the path -> Z and A = the kind: a root file
; (1 CMD, 3 EVENTS) by the device's list; in a folder (or STORE's root), 10 - a store file, TAG made
FindFile	push de
		push bc
		ld a, (de)
		or a
		jr nz, ff_tag
		ld a, (w_dev)
		cp 3			; STORE's root: files there too
		jr z, ff_tag
		push hl
		ld a, (w_dev)
		call DevFiles
		ex de, hl
		pop hl
ff_try		ld a, (de)
		or a
		jr z, ff_no
		push hl
		push de
		ld b, 11
ff_cmp		ld a, (de)
		xor (hl)
		and #7F
		jr nz, ff_diff
		inc hl
		inc de
		djnz ff_cmp
		ld a, (de)		; the kind byte after the 11 characters
		pop de
		pop hl
		pop bc
		pop de
		cp a			; Z
		ret
ff_diff		pop de
		pop hl
		push hl
		ld hl, 12
		add hl, de
		ex de, hl
		pop hl
		jr ff_try
ff_no		pop bc
		pop de
		ld a, 1
		or a
		ret
ff_tag		pop bc
		pop de
		call MakeTag
		ld a, 10
		cp a
		ret

; ---- the link: a byte out, a byte in (waiting), a frame out, a frame's header in
LinkOut		push bc
		ld bc, LINK_STAT
lo_wait		in a, (c)
		bit 1, a
		jr z, lo_wait
		dec c			; the data port
		out (c), l		; (L the byte: see FrameByte)
		pop bc
		ret
LinkIn		push bc
		ld bc, LINK_STAT
li_wait		in a, (c)
		bit 0, a
		jr z, li_wait
		dec c
		in a, (c)
		pop bc
		ret
; FrameByte: the byte in A out, added to the check
FrameByte	push hl
		push af
		ld l, a
		call LinkOut
		pop af
		push af
		ld hl, w_sum
		add a, (hl)
		ld (hl), a
		pop af
		pop hl
		ret
; FrameStart: A the chan, B the type, C the id, DE the length: A5 and the header out, the check started
FrameStart	push hl			; (HL kept: the caller's data pointer)
		push af
		ld a, #A5
		ld l, a
		call LinkOut
		xor a
		ld (w_sum), a
		pop af
		call FrameByte
		ld a, b
		call FrameByte
		ld a, c
		call FrameByte
		ld a, e
		call FrameByte
		ld a, d
		call FrameByte
		pop hl
		ret
; FrameEnd: the check out (HL kept)
FrameEnd	push hl
		ld a, (w_sum)
		ld l, a
		call LinkOut
		pop hl
		ret
; FrameText: the 0-ended text at HL out as frame bytes
FrameText	ld a, (hl)
		or a
		ret z
		call FrameByte
		inc hl
		jr FrameText
; TextLen: HL a 0-ended text -> DE its length
TextLen		push hl
		ld de, 0
tl_1		ld a, (hl)
		or a
		jr z, tl_e
		inc hl
		inc de
		jr tl_1
tl_e		pop hl
		ret
; ReadHeader: wait for a frame (hunting for A5), its header into w_hdr, w_left = its length
ReadHeader	call LinkIn
		cp #A5
		jr nz, ReadHeader
		push hl
		push bc
		ld hl, w_hdr
		ld b, 5
rh_1		call LinkIn
		ld (hl), a
		inc hl
		djnz rh_1
		ld hl, (w_hdr + 3)
		ld (w_left), hl
		pop bc
		pop hl
		ret
; SkipFrame: the rest of a frame read and dropped (its payload and the check)
SkipFrame	push hl
		ld hl, (w_left)
sf_1		ld a, h
		or l
		jr z, sf_e
		call LinkIn
		dec hl
		jr sf_1
sf_e		call LinkIn		; the check
		pop hl
		ret

; ---- the link's HELLO, once; the channel opened by the OPEN opcode's text; the answer "OK n" read
Hello		db "COS1 machine=cpc name=STREAMER max=256", 0
OpenTxt		db "OPEN ", 0
ListTxt		db "LIST", 0
SayHello	ld a, (w_hello)
		or a
		ret nz
		push hl
		push de
		push bc
		ld hl, Hello
		call TextLen
		xor a			; chan 0
		ld b, 1			; HELLO
		ld c, 0
		call FrameStart
		ld hl, Hello
		call FrameText
		call FrameEnd
		call ReadHeader		; the Pi's HELLO
		call SkipFrame
		ld a, 1
		ld (w_hello), a
		pop bc
		pop de
		pop hl
		ret
; OpenChannel: HL the service text, B its length -> OPEN on channel 0, "OK n" read into w_chan
OpenChannel	call SayHello
		push hl
		push de
		push bc
		ld e, b
		ld d, 0
		push hl
		ld hl, 5
		add hl, de
		ex de, hl
		pop hl
		push hl
		push bc
		xor a
		ld b, 2			; REQ
		ld c, 1
		call FrameStart
		ld hl, OpenTxt
		call FrameText
		pop bc
		pop hl
oc_txt		ld a, b
		or a
		jr z, oc_sent
		ld a, (hl)
		call FrameByte
		inc hl
		dec b
		jr oc_txt
oc_sent		call FrameEnd
oc_ans		call ReadHeader		; its answer: an RSP on chan 0 with this request's id (1) - anything else skipped
		ld a, (w_hdr + 1)
		and #7F
		cp 3
		jp nz, oc_skip
		ld a, (w_hdr)
		or a
		jp nz, oc_skip
		ld a, (w_hdr + 2)
		cp 1
		jp nz, oc_skip
		call LinkIn		; O or E
		cp 'O'
		jr nz, oc_err
		call LinkIn		; K
		call LinkIn		; space
		ld hl, (w_left)
		dec hl
		dec hl
		dec hl
		ld (w_left), hl
		ld e, 0
oc_num		ld a, h
		or l
		jr z, oc_done
		call LinkIn
		sub '0'
		cp 10
		jr nc, oc_done
		ld d, a
		ld a, e
		add a, a
		ld b, a
		add a, a
		add a, a
		add a, b
		add a, d
		ld e, a
		dec hl
		jr oc_num
oc_done		ld (w_left), hl		; (what the digits left: SkipFrame reads exactly that, then the check)
		call SkipFrame
		ld a, e
		call SetChan
		ld a, 2
		ld (w_id), a
		ld hl, 0
		ld (w_pass), hl
		; the stream's version byte, for GRAPHICS's channel only (the VDP's stream wants it; a store
		; or audio channel would take it as stray data)
		ld a, (w_dev)
		or a
		jr nz, oc_nover
		ld a, (w_chan)
		ld b, 4			; DATA
		ld c, 0
		ld de, 1
		call FrameStart
		ld a, 1
		call FrameByte
		call FrameEnd
oc_nover	pop bc
		pop de
		pop hl
		ret
oc_err		call SkipFrame		; (ERR: the channel stays 0)
		pop bc
		pop de
		pop hl
		ret
oc_skip		call SkipFrame
		jp oc_ans
; CloseChannel: a CLOSE frame on the channel, w_chan 0
CloseChannel	ld a, (w_chan)
		or a
		ret z
		push hl
		push bc
		push de
		ld b, 6			; CLOSE
		ld c, 0
		ld de, 0
		call FrameStart
		call FrameEnd
		xor a
		ld (w_chan), a
		pop de
		pop bc
		pop hl
		ret
; SendCredit: a CREDIT frame on the channel for the bytes of the frame just read (w_len)
SendCredit	push hl
		push de
		push bc
		push af
		ld a, (w_chan)
		ld b, 7			; CREDIT
		ld c, 0
		ld de, 2
		call FrameStart
		ld a, (w_len)
		call FrameByte
		ld a, (w_len + 1)
		call FrameByte
		call FrameEnd
		pop af
		pop bc
		pop de
		pop hl
		ret
; ListServices: LIST on channel 0; its answer comes back as lines through EVENTS (an RSP is a line too)
ListServices	call SayHello
		push hl
		push bc
		push de
		ld de, 4
		xor a
		ld b, 2
		ld c, 3
		call FrameStart
		ld hl, ListTxt
		call FrameText
		call FrameEnd
		pop de
		pop bc
		pop hl
		ret
; CreditBack: the frame just read (its hLen0 payload) credited back on w_chan - the Pi sends on a
; channel only what it was told there is room for; a GET's later parts wait on this
CreditBack	push hl
		push de
		push bc
		push af
		ld a, (w_chan)
		ld b, 7
		ld c, 0
		ld de, 2
		call FrameStart
		ld a, (w_hdr + 3)	; hLen0 lo
		call FrameByte
		ld a, (w_hdr + 4)	; hLen0 hi
		call FrameByte
		call FrameEnd
		pop af
		pop bc
		pop de
		pop hl
		ret
; EnsureStore: the store's channel open (OPEN store on channel 0, "OK n" into w_store), once
StoreTxt	db "store credit=60000", 0
EnsureStore	ld a, (w_store)
		or a
		ret nz
		push hl
		push de
		push bc
		push af
		ld a, (w_dev)
		push af
		ld a, (w_chan)
		push af
		ld hl, StoreTxt
		ld b, 5
		call OpenChannel	; (sets the device's channel: taken into w_store, the device's restored)
		ld a, (w_chan)
		ld (w_store), a
		pop af
		call SetChan
		pop af
		ld (w_dev), a
		pop af
		pop bc
		pop de
		pop hl
		ret
; the VDP opcodes' lengths (the opcode byte in): 0 = unknown (passed as one byte)
OpLen		db 0, 10, 7, 5, 4, 7, 4, 5, 3	; 00, 01 SPR, 02 POS, 03 PAT, 04 SHOW, 05 VEL, 06 BOUNDS, 07 CLASS, 08 KILL
		db 7, 1, 1, 9, 4, 1, 5		; 09 ANIM, 0A, 0B, 0C BOX, 0D FLAGS, 0E (SEQ: cl_seq), 0F PLAY

; ---- the output streams: CMD (the conversation), a store file (PUT tag in parts, the last at close)
Node_OutOpen	call IsOurs
		ret nc
		ld (w_dev), a
		push hl
		call FindFile
		pop hl
		jr nz, oo_no
		ld (w_file), a
		call GetChan
		ld a, (w_file)
		cp 10
		jr nz, oo_ok
		call EnsureStore
		ld a, (w_store)
		ld (w_chan), a
oo_ok		xor a
		scf
		ret
oo_no		ld a, 1
		or a
		scf
		ret
; OutWrite: HL the data, DE its length. CMD: the stream read a command at a time - the node's
; opcodes (80 up) done here, a VDP command (its length from OpLen, TEXT's from its len8) sent as
; one DATA frame; a command cut by the write's end sends what it has and w_pass says how much
; is still to come in the next write. PATTERNS: chunks of 250 as parts of a PATTERNS 0 request
Node_OutWrite	call IsOurs
		ret nc
		push hl
		push de
		push bc
ow_top		ld a, d
		or e
		jp z, ow_done
		ld a, (hl)
		cp #80
		jp nc, ow_op		; the node's opcodes (80 up): in any stream, then the dispatch again
		ld a, (w_file)
		cp 10
		jp z, ow_patterns	; a store file: PUT in parts
		ld a, (w_dev)
		cp 2
		jp z, ow_line		; MUSIC: a line a request
		cp 1
		jr nz, ow_cmd		; GRAPHICS: the VDP stream
		ld a, (w_tgt)		; SPEECH: by its target
		cp 2
		jp z, ow_raw		; the Pi's votrax: the bytes as DATA
		jp ow_speech		; a card
ow_cmd		ld a, d
		or e
		jp z, ow_done
		ld bc, (w_pass)
		ld a, b
		or c
		jr z, ow_fresh
		call SendPart		; the rest of a cut command
		jr ow_cmd
ow_fresh	ld a, (hl)
		cp #80
		jr c, ow_vdp
ow_op		cp #80
		jr nz, ow_n1
		inc hl			; 80 OPEN len8 text (whole within this write)
		ld b, (hl)
		inc hl
		dec de
		dec de
		push de
		push bc
		call OpenChannel
		pop bc
		pop de
		ld c, b
		ld b, 0
		add hl, bc
		ex de, hl
		or a
		sbc hl, bc
		ex de, hl
		jp ow_top
ow_n1		cp #81
		jr nz, ow_n2
		call CloseChannel
		jr ow_one
ow_n2		cp #82
		jr nz, ow_n3
		call CloseChannel
		xor a
		ld (w_hello), a		; (the next OPEN says HELLO again)
		jr ow_one
ow_n3		cp #83
		jr nz, ow_n4
		call ListServices
		jr ow_one
ow_n4		cp #85
		jr nz, ow_one
		inc hl			; 85 TARGET n
		dec de
		ld a, (hl)
		ld (w_tgt), a
ow_one		inc hl
		dec de
		jp ow_top
ow_vdp		call CmdLen		; BC the command's whole length
		call SendPart
		jp ow_cmd
; CmdLen: A the opcode at (HL) -> BC its length: TEXT 4 + its len8, TILEROW 4 + 3 x its n8, SEQ
; 3 + 2 x its count8 (the count must be in this write), OpLen for 01-0F, 20 TILE 6, 40 / 41 SCROLL
; 6, else 1 (7F COMMIT, anything unknown: a byte at a time - the Pi joins them)
CmdLen		cp #30
		jr z, cl_text
		cp #21
		jr z, cl_row
		cp #0E
		jr z, cl_seq
		cp #20
		jr z, cl_six
		cp #40
		jr z, cl_six
		cp #41
		jr z, cl_six
		jr cl_tab
cl_six		ld bc, 6
		ret
cl_row		push hl
		inc hl
		inc hl
		inc hl
		ld a, (hl)
		pop hl
		ld c, a
		ld b, 0
		add a, a
		add a, c		; x3
		add a, 4
		ld c, a
		ret nc
		inc b
		ret
cl_seq		push hl
		inc hl
		inc hl
		ld a, (hl)
		pop hl
		add a, a		; x2
		add a, 3
		ld c, a
		ld b, 0
		ret nc
		inc b
		ret
cl_text	cp #30
		jr nz, cl_tab
		push hl
		inc hl
		inc hl
		inc hl
		ld c, (hl)
		pop hl
		ld b, 0
		ld a, c
		add a, 4
		ld c, a
		ret nc
		inc b
		ret
cl_tab		cp 16
		jr nc, cl_one
		push hl
		ld hl, OpLen
		ld c, a
		ld b, 0
		add hl, bc
		ld c, (hl)
		pop hl
		ld a, c
		or a
		ret nz
		inc c			; (0 in the table: a byte)
		ret
cl_one		ld bc, 1
		ret
; SendPart: HL the data, BC the command's (remaining) length, DE the bytes this write still has ->
; min(BC, DE) bytes sent as one DATA frame on the channel; HL and DE moved on; w_pass = what is
; left of the command (0 when it went whole)
SendPart	push hl
		ld h, b
		ld l, c
		or a
		sbc hl, de		; BC - DE
		jr c, sp_all		; BC < DE: the whole command
		jr z, sp_all		; BC = DE
		ld (w_pass), hl		; BC - DE left for the next write
		ld b, d
		ld c, e			; send DE
		jr sp_go
sp_all		ld hl, 0
		ld (w_pass), hl		; send BC
sp_go		pop hl
		push bc
		push de
		ld a, (w_chan)
		ld d, b
		ld e, c
		ld b, 4			; DATA
		ld c, 0
		call FrameStart
		pop de
		pop bc
		push bc
sp_1		ld a, b
		or c
		jr z, sp_2
		ld a, (hl)
		call FrameByte
		inc hl
		dec bc
		jr sp_1
sp_2		call FrameEnd
		pop bc
		ex de, hl
		or a
		sbc hl, bc		; DE - sent
		ex de, hl
		ret
ow_patterns	ld a, d
		or e
		jp z, ow_done
		ld a, (hl)
		cp #84			; 84 END: the last part now
		jr nz, ow_pchunk
		call PatLast
		inc hl
		dec de
		jr ow_patterns
ow_pchunk	push de
		ld bc, 250
		ld a, d
		or a
		jr nz, ow_pcap
		ld a, e
		cp 251
		jr nc, ow_pcap
		ld c, e
		ld b, 0
ow_pcap		; BC the chunk, HL the data, the write's DE on the stack
		push bc			; [chunk]
		push hl			; [chunk][data]
		call ReqLen		; DE the request text's length
		inc de			; + the 0
		pop hl			; the data        [chunk]
		pop bc			; the chunk       []
		push bc			; [chunk]
		push hl			; [chunk][data]
		ld h, b
		ld l, c
		add hl, de		; the chunk + the text + the 0
		ex de, hl		; DE the frame's length
		ld a, (w_chan)
		ld b, 2 + #80		; REQ + MORE: a part of the request
		ld c, 2
		call FrameStart
		call ReqOut
		xor a
		call FrameByte		; the 0 between the text and the data
		pop hl			; the data        [chunk]
		pop bc			; the chunk       []
ow_pb1		ld a, b
		or c
		jr z, ow_pbend
		ld a, (hl)
		call FrameByte
		inc hl
		dec bc
		jr ow_pb1
ow_pbend	call FrameEnd
		pop de
		ld a, d
		or a
		jr nz, ow_psub
		ld a, e
		cp 251
		jr nc, ow_psub
		ld de, 0
		jr ow_patterns
ow_psub		ex de, hl
		ld bc, 250
		or a
		sbc hl, bc
		ex de, hl
		jr ow_patterns
ow_done		pop bc
		pop de			; (the count given: all of it taken)
		pop hl
		xor a
		scf
		ret
; a speech card (kind 4 SSA1, 5 DKTRONIC): each byte an allophone (0-63, the rest masked), written
; when the card's /LRQ bit says it is ready - the chip queues a few, says each, no CPU between
ow_speech	ld a, (w_tgt)
		ld c, a
		add a, a
		add a, c		; x3: the Cards row
		ld c, a
		ld b, 0
		push hl
		ld hl, Cards
		add hl, bc
		ld c, (hl)
		inc hl
		ld b, (hl)		; BC the port
		inc hl
		ld a, (hl)		; the /LRQ bit number -> a mask in w_sum
		pop hl
		push bc
		ld b, a
		ld a, 1
		inc b
sp_m1		dec b
		jr z, sp_m2
		add a, a
		jr sp_m1
sp_m2		ld (w_sum), a
		pop bc
sp_next		ld a, d
		or e
		jp z, ow_done
		push de
sp_wait		in a, (c)
		ld e, a
		ld a, (w_sum)
		and e
		jr nz, sp_wait		; /LRQ 1: busy
		pop de
		ld a, (hl)
		and #3F
		out (c), a
		inc hl
		dec de
		jr sp_next
; raw bytes (kind 7: VOTRAX's CMD): the write as DATA frames of up to 250 - phonemes with their
; inflection bits, nothing parsed (the node's opcodes were looked at before the dispatch)
ow_raw		ld a, d
		or e
		jp z, ow_done
		ld bc, 250
		ld a, d
		or a
		jr nz, or_cap
		ld a, e
		cp 251
		jr nc, or_cap
		ld c, e
		ld b, 0
or_cap		call SendPart
		jr ow_raw
; a line a request (kind 6: MUSIC's CMD): what a PRINT #9 writes, less its CR / LF end, goes as one
; REQ on the device's channel (80 OPEN audio first); the answer comes back on EVENTS
ow_line		ld a, d
		or e
		jp z, ow_done
		push hl
		push de
		; the text's length without a trailing CR / LF
		ld b, d
		ld c, e
		add hl, bc
		dec hl
		ld a, (hl)
		cp 10
		jr nz, ol_1
		dec bc
		dec hl
		ld a, (hl)
ol_1		cp 13
		jr nz, ol_2
		dec bc
ol_2		pop de
		pop hl
		push hl
		push de
		push bc
		ld a, (w_chan)
		ld d, b
		ld e, c
		ld b, 2			; REQ
		ld a, (w_id)
		ld c, a
		inc a
		ld (w_id), a
		ld a, (w_chan)
		call FrameStart
		pop bc
ol_3		ld a, b
		or c
		jr z, ol_4
		ld a, (hl)
		call FrameByte
		inc hl
		dec bc
		jr ol_3
ol_4		call FrameEnd
		pop de
		pop hl
		jp ow_done
; PatLast: PATTERNS' last, empty part (no MORE): the request completes on the Pi; its answer read and dropped
PatLast		push hl
		push de
		push bc
		call ReqLen
		inc de
		ld a, (w_chan)
		ld b, 2
		ld c, 2
		call FrameStart
		call ReqOut
		xor a
		call FrameByte
		call FrameEnd
		call ReadHeader
		call SkipFrame
		pop bc
		pop de
		pop hl
		ret
PutTxt		db "PUT ", 0
; ReqTxt: the store file's request - "PUT " then TAG - sent by ReqOut; ReqLen -> DE its length
ReqLen		push hl
		ld hl, TAG
		call TextLen
		inc de
		inc de
		inc de
		inc de			; "PUT "
		pop hl
		ret
ReqOut		push hl
		ld hl, PutTxt
		call FrameText
		ld hl, TAG
		call FrameText
		pop hl
		ret
; OutClose: BASIC's CLOSEOUT - nothing on the Pi; PATTERNS alone sends its last part here too (a
; SAVE closes by itself, so a SAVE needs no 84 END)
Node_OutClose	call IsOurs
		ret nc
		ld a, (w_file)
		cp 10
		call z, PatLast		; a store file: its last part
		xor a
		ld (w_file), a
		scf
		ret

; ---- the input streams: EVENTS (an event or answer a line), or a store file (GET tag: its bytes)
GetTxt		db "GET ", 0
Node_InOpen	call IsOurs
		ret nc
		ld (w_dev), a
		push hl
		call FindFile
		pop hl
		jp nz, io_no
		cp 3
		jp z, io_ev
		cp 10
		jp nz, io_no
		; a store file: GET tag sent; the answer's parts read by InRead (text "OK size", 0, data)
		ld (w_file), a
		call EnsureStore
		ld a, (w_store)
		ld (w_chan), a
		push hl
		push de
		push bc
		ld hl, TAG
		call TextLen
		inc de
		inc de
		inc de
		inc de
		ld a, (w_store)
		ld b, 2
		ld c, 5
		call FrameStart
		ld hl, GetTxt
		call FrameText
		ld hl, TAG
		call FrameText
		call FrameEnd
ig_ans		call ReadHeader
		ld a, (w_hdr + 1)
		and #7F
		cp 3
		jr nz, ig_skip
		ld a, (w_hdr + 2)
		cp 5
		jr z, ig_got
ig_skip		call SkipFrame
		jr ig_ans
ig_got		ld a, (w_hdr + 1)
		and #80
		ld (w_more), a
		call LinkIn		; O or E
		push af
		ld hl, (w_left)
		dec hl
		ld (w_left), hl		; count the O/E too (it is part of the text)
		pop af
		cp 'O'
		jr nz, ig_err
ig_txt		call LinkIn		; the text to its 0 (the data follows)
		push af
		ld hl, (w_left)
		dec hl
		ld (w_left), hl
		pop af
		or a
		jr nz, ig_txt
		pop bc
		pop de
		pop hl
		xor a
		scf
		ret
ig_err		call SkipFrame
		pop bc
		pop de
		pop hl
		ld a, 1
		or a
		scf
		ret
io_ev		ld (w_file), a
		call GetChan
		xor a
		scf
		ret
io_no		ld a, 1
		or a
		scf
		ret
; InRead: HL the buffer, DE room. EVENTS: the next EVT / RSP's text, then CR LF. A store file: the
; GET's data, part after part (MORE), until none is left (DE 0 then: the end)
Node_InRead	call IsOurs
		ret nc
		ld a, (w_file)
		cp 10
		jp z, ir_store
		push hl
		push bc
		push de
ir_next		call ReadHeader
		ld a, (w_hdr + 1)
		and #7F
		cp 5			; EVT
		jr z, ir_evt
		cp 3			; RSP (OK n, ERR ..., LIST's lines): a line too
		jr z, ir_evt
		call SkipFrame
		jr ir_next
ir_evt		push hl
		ld hl, (w_hdr + 3)
		ld (w_len), hl		; (the frame's length: credit given back once it is read)
		pop hl
		pop de
		push de
		ld bc, 0		; given so far
ir_1		push hl
		ld hl, (w_left)
		ld a, h
		or l
		pop hl
		jr z, ir_end
		call LinkIn
		push hl
		ld hl, (w_left)
		dec hl
		ld (w_left), hl
		pop hl
		or a
		jr nz, ir_put
		ld a, d			; the 0 between an answer's text and its data (LIST's lines): a CR LF
		or e
		jr z, ir_1
		ld (hl), 13
		inc hl
		inc bc
		dec de
		ld a, 10
ir_put		push af
		ld a, d
		or e
		jr z, ir_full
		pop af
		ld (hl), a
		inc hl
		inc bc
		dec de
		jr ir_1
ir_full		pop af
		jr ir_1
ir_end		call LinkIn		; the check
		call SendCredit		; the frame's bytes back as credit: the Pi may send the next
		ld a, d
		or e
		jr z, ir_out
		ld (hl), 13
		inc hl
		inc bc
		dec de
		ld a, d
		or e
		jr z, ir_out
		ld (hl), 10
		inc bc
ir_out		pop de
		ld d, b
		ld e, c
		pop bc
		pop hl
		xor a
		scf
		ret
; a store file's data: what is left of the part, then the next part (MORE), into the buffer
ir_store	; HL buffer, DE room -> bytes into (HL), DE = count given
		ld (irs_buf), hl
		ld (irs_room), de
		ld bc, 0
irs_loop	ld hl, (irs_room)
		or a
		sbc hl, bc
		jp z, irs_out		; room filled
		ld hl, (w_left)
		ld a, h
		or l
		jr nz, irs_data
		ld a, (w_more)
		cp 2
		jr z, irs_out
		call LinkIn		; the finished part's check
		call CreditBack
		ld a, (w_more)
		or a
		jr nz, irs_part
		ld a, 2
		ld (w_more), a
		jr irs_out
irs_part	call ReadHeader
		ld a, (w_hdr + 1)
		and #80
		ld (w_more), a
irs_ptx	ld hl, (w_left)
		ld a, h
		or l
		jr z, irs_loop
		call LinkIn
		ld hl, (w_left)
		dec hl
		ld (w_left), hl
		or a
		jr nz, irs_ptx		; the text up to and including its 0
		jr irs_loop
irs_data	call LinkIn
		push bc
		ld hl, (irs_buf)
		add hl, bc
		ld (hl), a
		pop bc
		inc bc
		ld hl, (w_left)
		dec hl
		ld (w_left), hl
		jr irs_loop
irs_out		ld d, b
		ld e, c
		xor a
		scf
		ret
irs_buf		dw 0
irs_room	dw 0
Node_InClose	call IsOurs
		ret nc
		xor a
		ld (w_file), a
		scf
		ret

		ds #10000 - $, #FF		; the ROM filled to 16K

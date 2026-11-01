				; streamer UniDOS node
				; allows data to be copied to the device & folder and have an effect

				; status of stream implementations
				;
				;AUDIO:
				;	AMDRUM.DAC - AMDRUM *
				;	ASIC.DAC - Plus Machine DAC simulation * (Not implemented)
				;	AY8912.DAC - all CPC DAC simulation *
				;	DIGBLAST.DAC - DigiBlaster *
				;	MMACHINE.DAC - RAM Music Machine * **

				;		* hardcoded delay that should be user specified, see DAC_DELAY
				;		** untested
				;	note, all the DACs should be able to play the same sample data. Future functionality will allow for sound fonts 
				;	to be configured via streams.

				;PRINT:
				;	7BIT - Standard 7bit Printer Port
				;	8BIT - 8bit Printer Port (Not implemented)

				;	note, all the printers ports should be able to print the same text
				;	later printer drivers could be easily added, e.g. epson, citoh (does anyone use them anymore?)

				;RTG:
				;	CRTC6845.VDP - Standard CRTC6845 (Not implemented)
				;	V9990.VDP - V9990 Graphics Card (Not implemented)

				;	note, goal here is to create a virtual VDP which can handle different protocol-like commands such
				;	as sendit sprite data, tile data, CRTC6845 would use extended memory. sprites & tiles will be
				;	allocated IDs, there will be protocol commands to move them via attribute memory that is streamed

				;SPEECH:
				;	DKTRONIC.RAW - DkTronics Speech Synthesizer (Not implemented)
				;	SSA1.RAW - Amstrad SSA1 Speech Synthesizer (Not implemented)

				;	note, pretty straight forward as they use the same chip, just different ports. RAW takes raw allophone data.
				;	it is possible to add additional vocabluary streams that could interpret common words.

				;TEST:
				;	TXT2SCRN - Text to Screen

				;Pending Improvements
				;	- Change the filename and device test heirarchies in most functions to lists rather than 
				;	  manual testing of each element

				org #c000

				write "D:\dev\cpc\unidos\streamer.rom"
				write direct -1,1,#C0

CODE_START:

ROMType 			db 2; 1 (secondary ROM) or 2 (expansion ROM)

ROMMark 			db 1; It is customary that the version of a ROM
ROMVer 				db 4; is displayed in the form M VR
ROMRev 				db 1; (i.e. 1.00 here)

ROMRSX dw RSXTable

				jp InitROM
				jp DOSNode_Init			; implemented
				jp DOSNode_CheckDrive		; implemented
				jp DOSNode_GetStatus		; implemented
				jp DOSNode_GetName		; implemented
				jp DOSNode_GetDesc		; implemented
				jp DOSNode_GetFreeSpace		; implemented
				jp DOSNode_InOpenStream
				jp DOSNode_InReadStream
				jp DOSNode_InCloseStream
				jp DOSNode_InSeekStream
				jp DOSNode_OutOpenStream	; implemented
				jp DOSNode_OutWriteStream	; implemented
				jp DOSNode_OutCloseStream	; implemented
				jp DOSNode_OutSeekStream
				jp DOSNode_Examine		; implemented
				jp DOSNode_ExamineNext		; implemented
				jp DOSNode_Rename
				jp DOSNode_Delete
				jp DOSNode_CreateDir
				jp DOSNode_SetProtection
				jp DOSNode_Format
				jp DOSNode_SetFileDate
				jp DOSNode_Void
				jp DOSNode_Void
				jp DOSNode_Void
				jp DOSNode_ReadRTC
				jp DOSNode_WriteRTC
				jp DOSNode_OpenNVRAM
				jp DOSNode_CloseNVRAM
				jp DOSNode_ReadNVRAM
				jp DOSNode_WriteNVRAM
				jp DOSNode_SeekNVRAM
				; You can add your personal RSX here (if ROM type 1)

RSXTable
				str "STREAMER"
				str "DOS Node"

				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80
				db #80

				; You can add your personal RSX here (if ROM type 1)
				db 0; End of the RSX table

        ; Actual ROM code starts here
InitROM:			or a
				ret

; Error codes
DSK_ERR_USER_HAS_HIT_ESCAPE     equ #00
DSK_ERR_BAD_COMMAND             equ #10
DSK_ERR_FILE_NOT_FOUND		equ #12

BYTES_FREE_HW			equ #00ff		; high word
BYTES_FREE_LW			equ #ffff		; low word
DAC_DELAY			equ 2			; slow dac playing a bit
PORT_AMDRUM			equ #ff
PORT_DBLAST			equ #ef
PORT_MMACHINE			equ #f8f0

MC_PRINT_CHAR			equ #bd2b
TXT_OUT_CHAR			equ #bb5a

Drive_AUD			equ #0
Drive_PRN			equ #1
Drive_RTG			equ #2
Drive_SPCH			equ #3
Drive_TEST			equ #4

DriveNames:
DriveNameAUD:			db "AUDI", "O" + #80, 0, Drive_AUD
DriveNamePRN:			db "PRIN", "T" + #80, 0, Drive_PRN
DriveNameRTG:			db "RT", "G" + #80, 0, Drive_RTG
DriveNameSPCH:			db "SPEEC", "H" + #80, 0, Drive_SPCH
DriveNameTEST:			db "TES", "T" + #80, 0, Drive_TEST
				db 0

DriveDescAUD:			db "Audio Device", "s" + #80, 0
DriveDescPRN:			db "Printer Device", "s" + #80, 0
DriveDescRTG:			db "Retargetable Graphics Device", "s" + #80, 0
DriveDescSPCH:			db "Speech Device", "s" + #80, 0
DriveDescTEST:			db "Test Device", "s" + #80, 0

; fake directories
DIR_ROOT:			db "ROOT", 0
AUD_AMDRUM:			db "AMDRUM  DAC", 0
AUD_ASIC:			db "ASIC    DAC", 0
AUD_AY8912:			db "AY8912  DAC", 0
AUD_DBLAST:			db "DBLAST  DAC", 0
AUD_MMACH:			db "MMACHINEDAC", 0
PRN_7BIT:			db "7BIT    ASC", 0
PRN_8BIT:			db "8BIT    ASC", 0
RTG_CRTC6845:			db "CRTC6845VDP", 0
RTG_V9990:			db "V9990   VDP", 0
SPCH_DKTRONIC:			db "DKTRONICRAW", 0
SPCH_SSA1:			db "SSA1    RAW", 0
TEST_TXT2SCRN:			db "TXT2SCRN   ", 0

;
; Initialize the noeud DOS
;
; Input   - A = initialization status (see flags Init_*)
;               Bit0 = 1 if the CPC is doing a cold boot
;               Other bits are unused
; Output  - If Carry = 1 then the node was intialized
;           If Carry = 0 then the node could not be initialized
; Altered - AF

DOSNode_Init:	
		jp DOSNode_Success

;
; Check if a drive name is handled by the DOS node
;
; Input   - HL = pointer to the drive name
;                (bit 7 could be set on some character and mush be ignored)
;           C = length of the drive name
; Output - If Carry = 1 a drive was found in the node
;                A = physical drive number
;           If Carry = 0 the drive was not found in the node
;		 A = MUST BE PRESERVED
; Altered - AF

DOSNode_CheckDrive:
				push de
				push hl
				push af
				ld de, DriveNames
				ex de, hl
				call ListGetIDByName
				jp nz, DOSNode_CheckDriveFail

				pop hl		; discard the original value of AF
				pop hl
				pop de
				jp DOSNode_Success

DOSNode_CheckDriveFail:		pop af
				pop hl
				pop de
				jp DOSNode_Fail


;
; Return a drive status
;
; Input   - A = drive number
; Output  - If Carry = 1 a status was returned
;                A = status of the drive (see flags flags Media_*)
;                    Bit0 = 1 if a media is inserted in the drive
;                    Bit1 = 1 if the media support directories
;                    Bit2 = 1 if the media is write protected
;                    Bit3 = 1 if the media is removable
;                    Bit4 = 1 if the media is a stream (linear read/write only)
;                        $$$ and BAK filesis then disabled
;                    Bit5 = 1 if the media can be reached by the new UniDOS API
;                    Other bits are unused
;           If Carry = 0 then the drive is unknown and no status was returned
; Alteted - AF

DOSNode_GetStatus:
				cp Drive_AUD
				jr z, DOSNode_GetStatusEnd

				cp Drive_PRN
				jr z, DOSNode_GetStatusEnd

				cp Drive_RTG
				jr z, DOSNode_GetStatusEnd

				cp Drive_SPCH
				jr z, DOSNode_GetStatusEnd

				cp Drive_TEST
				jr z, DOSNode_GetStatusEnd

				jp DOSNode_Fail

DOSNode_GetStatusEnd:
				ld a, %00110001	;Media_NewAPI_F+Media_StreamOnly_F+Media_Available_F
				jp DOSNode_Success

;
; Return the name corresponding to a physical drive
;
; Input   - A = drive number
;           DE = address of a buffer of 8 bytes when to store the name
; Output  - If Carry = 1 the name was found
;                DE points to the first character after the end of the copied string
;                (the string is stored with the bit 7 of its last character set)
;          If Carry = 0 not description was found and the buffer is left unchanged.
; Altered - AF,DE

DOSNode_GetName:
				push hl
				
				cp Drive_AUD
				ld hl, DriveNameAUD
				jr z, DOSNode_GetNameCopy

				cp Drive_PRN
				ld hl, DriveNamePRN
				jr z, DOSNode_GetNameCopy

				cp Drive_RTG
				ld hl, DriveNameRTG
				jr z, DOSNode_GetNameCopy

				cp Drive_SPCH
				ld hl, DriveNameSPCH
				jr z, DOSNode_GetNameCopy

				cp Drive_TEST
				ld hl, DriveNameTEST
				jr z, DOSNode_GetNameCopy

				pop hl
				jp DOSNode_Fail

DOSNode_GetNameCopy:
				call StrCopy
				pop hl
				jp DOSNode_Success
		
;
; Return the description corresponding to a physical drive
;
; Input  - A = drive number
;          DE = addess of the 32 bytes buffer where to store the description
; Ouput  - If Carry = 1 a description was found
;                DE points to the first character after the end of the copied string
;                (the string is stored with the bit 7 of its last character set)
;          If Carry = 0 not description was found and the buffer is left unchanged.
; Altered - AF,DE

DOSNode_GetDesc:
				push hl
				
				cp Drive_AUD
				ld hl, DriveDescAUD
				jr z, DOSNode_GetDescCopy

				cp Drive_PRN
				ld hl, DriveDescPRN
				jr z, DOSNode_GetDescCopy

				cp Drive_RTG
				ld hl, DriveDescRTG
				jr z, DOSNode_GetDescCopy

				cp Drive_SPCH
				ld hl, DriveDescSPCH
				jr z, DOSNode_GetDescCopy

				cp Drive_TEST
				ld hl, DriveDescTEST
				jr z, DOSNode_GetDescCopy

				pop hl
				jp DOSNode_Fail

DOSNode_GetDescCopy:
				call StrCopy
				pop hl
				jp DOSNode_Success

;
; Return the free space on a physical drive
;
; Input   - A = drive number
; Output  - If Carry = 1 the routine is supported for this drive
;                If Z then the free space could be obtained
;                    BCDE = free space in kilo-bytes
;                If NZ then an error occured
;                    A = error code
;           If Carry = 0 then the routines is invalid for this drive
; Altered - AF,BC,DE 

DOSNode_GetFreeSpace:
				cp Drive_AUD
				jr z, DOSNode_GetFreeSpaceEnd

				cp Drive_PRN
				jr z, DOSNode_GetFreeSpaceEnd

				cp Drive_RTG
				jr z, DOSNode_GetFreeSpaceEnd

				cp Drive_SPCH
				jr z, DOSNode_GetFreeSpaceEnd

				cp Drive_TEST
				jr z, DOSNode_GetFreeSpaceEnd

				jp DOSNode_Fail

DOSNode_GetFreeSpaceEnd:
				ld bc, BYTES_FREE_HW
				ld de, BYTES_FREE_LW
				xor a
				jp DOSNode_Success

;
; Open the input stream
;
; Input   - A = drive number
;           HL = pointer to the normalized name
;               note, if the drive is of type stream then this name can
;               contain 11x&ff in case where no file name was provided
;               by the user (when he uses the anonymous reference ".");
;               the routine should then just open the just encountered
;               file on the stream and can optionally update the name
;               if it could be obtained from the stream itself
;          DE = pointer the normalized path
;          The pointed memory is always located in the current ROM/RAM space area
; Ouput  - If Carry = 1 the routine is supported for the provided drive
;                If Z then a file was opened
;                If NZ then no file could be opened
;                    A = error code
;               In any case, the routine might truncate the provided normalized path to match the nearest parent
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_InOpenStream:
				jp DOSNode_Fail

;
; Read from the input stream
;
; Input  - A = drive number
;           HL = address where to stored the read data
;           DE = number of bytes to read
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then data could be read
;                    DE = number of bytes read
;                If NZ then a error occured
;                    A = error code
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF,DE

DOSNode_InReadStream:
				jp DOSNode_Fail

;
; Close the input stream
;
; Input   - A = drive number
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the stream was properly closed
;                If NZ then the stream was closed with an error
;                    A = error code
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_InCloseStream:
				jp DOSNode_Fail

;
; Change the position into the input stream
;
; Input   - A = drive number
;           DEHL = new position in the input stream
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the new position could be reached
;                If NZ then an error occured
;                    A = error code
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_InSeekStream:
				jp DOSNode_Fail

;
; Open the output stream
;
; Input   - A = drive number
;           HL = pointer to the normalized name
;           DE = pointer to the normalized path
;          The pointed memory is always located in the current ROM/RAM space area
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then a file was created
;                If NZ then no file was created
;                    A = error code
;               In any case, the routine might truncate the provided normalized path to match the nearest parent
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_OutOpenStream:
				cp Drive_AUD
				jp z, DOSNode_OutOpenStream_Success

				cp Drive_PRN
				jp z, DOSNode_OutOpenStream_Success

				cp Drive_RTG
				jp z, DOSNode_OutOpenStream_Success

				cp Drive_SPCH
				jp z, DOSNode_OutOpenStream_Success

				cp Drive_TEST
				jp z, DOSNode_OutOpenStream_Success

				jp DOSNode_Fail

DOSNode_OutOpenStream_Success:
				push hl
				push de
				pop hl
				ld (#be80), hl	; pointer to path we are writing to

				pop hl
				jp DOSNode_Success

;
; Write into the ouput stream
;
; Input   - A = drive number
;           HL = address where are located the data to write
;           DE = number of bytes to write
; Sortie - If Carry = 1 the routine is supported for the provided drive
;                If Z then data could be written
;                    DE = nomber of written bytes
;                If NZ then an error occured
;                    A = error code
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF,DE

DOSNode_OutWriteStream:
				cp Drive_AUD
				jr z, DOSNode_OutWriteStream_AUD

				cp Drive_PRN
				jp z, DOSNode_OutWriteStream_PRN

				cp Drive_RTG
				jp z, DOSNode_OutWriteStream_RTG

				cp Drive_SPCH
				jp z, DOSNode_OutWriteStream_SPCH

				cp Drive_TEST
				jp z, DOSNode_OutWriteStream_TEST

				jp DOSNode_Fail

; ----------------------------------------

DOSNode_OutWriteStream_AUD:
				push de
				push hl
				ld de, AUD_AMDRUM
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_AUD2

				; otherwise we found our directory
				jp AUD_AMDRUM_Output

DOSNode_OutWriteStream_AUD2:
				push de
				push hl
				ld de, AUD_ASIC
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_AUD3

				; otherwise we found our directory
				jp AUD_ASIC_Output

DOSNode_OutWriteStream_AUD3:
				push de
				push hl
				ld de, AUD_AY8912
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_AUD4

				; otherwise we found our directory
				jp AUD_AY8912_Output

DOSNode_OutWriteStream_AUD4:
				push de
				push hl
				ld de, AUD_DBLAST
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_AUD5

				; otherwise we found our directory
				jp AUD_DBLAST_Output

DOSNode_OutWriteStream_AUD5:
				push de
				push hl
				ld de, AUD_MMACH
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jp nz, DOSNode_OutWriteStream_Fail

				; otherwise we found our directory
				jp AUD_MMACH_Output

; ----------------------------------------

DOSNode_OutWriteStream_PRN:
				push de
				push hl
				ld de, PRN_7BIT
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_PRN2

				; otherwise we found our directory
				jp PRN_7BIT_Output
				
DOSNode_OutWriteStream_PRN2:
				push de
				push hl
				ld de, PRN_8BIT
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_Fail

				; otherwise we found our directory
				jp PRN_8BIT_Output
				
; ----------------------------------------

DOSNode_OutWriteStream_RTG:
				push de
				push hl
				ld de, RTG_CRTC6845
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_RTG2

				; otherwise we found our directory
				jp RTG_CRTC6845_Output
				
DOSNode_OutWriteStream_RTG2:
				push de
				push hl
				ld de, RTG_V9990
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_Fail

				; otherwise we found our directory
				jp RTG_V9990_Output
				
; ----------------------------------------

DOSNode_OutWriteStream_SPCH:

				push de
				push hl
				ld de, SPCH_SSA1
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_SPCH2

				; otherwise we found our directory
				jp SPCH_SSA1_Output

DOSNode_OutWriteStream_SPCH2:
				push de
				push hl
				ld de, SPCH_DKTRONIC
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_Fail

				; otherwise we found our directory
				jp SPCH_DKTRONIC_Output

; ----------------------------------------

DOSNode_OutWriteStream_TEST:

				push de
				push hl
				ld de, TEST_TXT2SCRN
				ld hl, (#be80)	; read pointer
				inc hl		;

				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_OutWriteStream_Fail

				; otherwise we found our directory
				jp TEST_TXT2SCRN_Output

DOSNode_OutWriteStream_Fail:
				ld a, DSK_ERR_BAD_COMMAND
				jp DOSNode_Success

;
; Close the output stream
;
; Input   - A = drive number
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the stream was properly closed
;                If NZ then the stream was closed with an error
;                    A = error code
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_OutCloseStream:
				cp Drive_AUD
				jp z, DOSNode_Success

				cp Drive_PRN
				jp z, DOSNode_Success

				cp Drive_RTG
				jp z, DOSNode_Success

				cp Drive_SPCH
				jp z, DOSNode_Success

				cp Drive_TEST
				jp z, DOSNode_Success

				jp DOSNode_Fail

;
; Change the position into the output stream
;
; Input   - A = drive number
;           DEHL = new position in the ouput stream
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the new position could be reached
;                If NZ then an error occured
;                    A = error code
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_OutSeekStream:
				jp DOSNode_Fail

;
; Check that a file or directory exists and return associated information
;
; Input   - A = drive number
;           HL = pointer to the normalized name
;               If HL = 0 then it is the contents of the directory which has to be analyzed
;               and ExamineNext will be called next to retrieve each entry
;           DE = pointer to the normalized path
;           IX = buffer where to store last modification time and date
;           The pointed memory is always located in the current ROM/RAM space area
; Output  - If Carry = 1 the routine is supported for the provided drive
;
;                If HL was not 0 in input
;                    If Z then the file or directory exists
;                        A = protection bits of the file
;                            Bit 0 - Read-only
;                            Bit 1 - Hidden
;                            Bit 2 - System
;                            Bit 4 = Directory
;                            Bit 5 = Archived
;                        BCDE = Length of the file
;                        IX = buffer where last modification time and date of the entry were stored
;                            One 16-bit word with year (1978..9999)
;                            One byte with number of month (1..12)
;                            One byte with number of day in the month (1..28,29,30 or 31)
;                            One byte with hours (0..23)
;                            One byte with minutes (0..59)
;                            One byte with seconds (0..59)
;                    If NZ then the file or directory was not found
;                        A = error code
;
;                If HL was 0 in input
;                    If Z then the directory is ready to be examined through ExamineNext
;                    If NZ then an error occurred
;                        A = error code
;
;                In any case, the routine might truncate the provided normalized path to match the nearest parent
;
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_Examine:
				push hl
				push af

				ld a, h					; examine directory via ExamineNext
				or l					;
				jp z, DOSNode_Use_ExamineNext

				pop af
				pop hl

				;ld (#be82), a

				cp Drive_AUD
				jr z, DOSNode_Examine_AUD

				cp Drive_PRN
				jr z, DOSNode_Examine_PRN

				cp Drive_RTG
				jp z, DOSNode_Examine_RTG

				cp Drive_SPCH
				jp z, DOSNode_Examine_SPCH

				cp Drive_TEST
				jp z, DOSNode_Examine_TEST

				jp DOSNode_Fail				; don't really care as we are not really writing a file

				; non-root (means we are already in a folder)
DOSNode_Examine_AUD:
				push de
				push hl
				ld de, AUD_AMDRUM
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_AUD2

				; otherwise we found our directory
				jp DOSNode_Examine_Found

DOSNode_Examine_AUD2:
				push de
				push hl
				ld de, AUD_ASIC
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_AUD3

				; otherwise we found our directory
				jp DOSNode_Examine_Found

DOSNode_Examine_AUD3:
				push de
				push hl
				ld de, AUD_AY8912
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_AUD4

				; otherwise we found our directory
				jp DOSNode_Examine_Found

DOSNode_Examine_AUD4:
				push de
				push hl
				ld de, AUD_DBLAST
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_AUD5

				; otherwise we found our directory
				jp DOSNode_Examine_Found

DOSNode_Examine_AUD5:
				push de
				push hl
				ld de, AUD_MMACH
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jp nz, DOSNode_Examine_Fail

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Examine_PRN:
				push de
				push hl
				ld de, PRN_7BIT
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_PRN2

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Examine_PRN2:
				push de
				push hl
				ld de, PRN_8BIT
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_Fail

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Examine_RTG:
				push de
				push hl
				ld de, RTG_CRTC6845
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_RTG2

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Examine_RTG2:
				push de
				push hl
				ld de, RTG_V9990
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_Fail

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Examine_SPCH:
				push de
				push hl
				ld de, SPCH_SSA1
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_SPCH2

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Examine_SPCH2:
				push de
				push hl
				ld de, SPCH_DKTRONIC
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_Fail

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Examine_TEST:
				push de
				push hl
				ld de, TEST_TXT2SCRN
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_Examine_Fail

				; otherwise we found our directory
				jr DOSNode_Examine_Found

DOSNode_Use_ExamineNext:	
				pop hl		;discard the preserved af
				pop hl
				jp DOSNode_Success

DOSNode_Examine_Found:
				ld a, DSK_ERR_FILE_NOT_FOUND
				jp DOSNode_Success

DOSNode_Examine_Fail:		
				;ld a, (#be82)
				ld a, DSK_ERR_USER_HAS_HIT_ESCAPE
				jp DOSNode_Fail


;
; Get the next entry from a directory being examined
;
; Input   - A = drive number
;           HL = pointer to the memory where to store the normalize name
;           IX = buffer where to store last modification time and date
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then an entry was found
;                    HL = pointer to the memory updated with the found normalized name
;                        A = protection bits of the file
;                            Bit 0 - Read-only
;                            Bit 1 - Hidden
;                            Bit 2 - System
;                            Bit 4 = Directory
;                            Bit 5 = Archived
;                        BCDE = Length of the file
;                        IX = buffer where last modification time and date of the entry were stored
;                            One 16-bit word with year (1978..9999)
;                            One byte with number of month (1..12)
;                            One byte with number of day in the month (1..28,29,30 or 31)
;                            One byte with hours (0..23)
;                            One byte with minutes (0..59)
;                            One byte with seconds (0..59)
;                If NZ then an error occurred
;                    A = error code (dsk_err_file_not_found indicates that all entries were examined)
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_ExamineNext:
				cp Drive_AUD
				jr z, DOSNode_ExamineNext_AUD

				cp Drive_PRN
				jr z, DOSNode_ExamineNext_PRN

				cp Drive_RTG
				jp z, DOSNode_ExamineNext_RTG

				cp Drive_SPCH
				jp z, DOSNode_ExamineNext_SPCH

				cp Drive_TEST
				jp z, DOSNode_ExamineNext_TEST

				jp DOSNode_ExamineNext_Fail

DOSNode_ExamineNext_AUD:
				; if not root, then file not found
				push de
				push hl
				ld de, DIR_ROOT
				ex de, hl
				ld b, 4
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_AUD2

				; otherwise we found our directory
				ld de, AUD_AMDRUM	;<-- this is a directory
				jp DOSNode_ExamineNext_Found

DOSNode_ExamineNext_AUD2:
				push de
				push hl
				ld de, AUD_AMDRUM
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_AUD3

				; otherwise we found our directory
				ld de, AUD_ASIC	;<-- this is a directory
				jp DOSNode_ExamineNext_Found

DOSNode_ExamineNext_AUD3:
				push de
				push hl
				ld de, AUD_ASIC
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jp nz, DOSNode_ExamineNext_AUD4

				; otherwise we found our directory
				ld de, AUD_AY8912	;<-- this is a directory
				jp DOSNode_ExamineNext_Found

DOSNode_ExamineNext_AUD4:
				push de
				push hl
				ld de, AUD_AY8912
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jp nz, DOSNode_ExamineNext_AUD5

				; otherwise we found our directory
				ld de, AUD_DBLAST	;<-- this is a directory
				jp DOSNode_ExamineNext_Found

DOSNode_ExamineNext_AUD5:
				push de
				push hl
				ld de, AUD_DBLAST
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jp nz, DOSNode_ExamineNext_Fail

				; otherwise we found our directory
				ld de, AUD_MMACH	;<-- this is a directory
				jp DOSNode_ExamineNext_Found

DOSNode_ExamineNext_PRN:
				; if not root, then file not found
				push de
				push hl
				ld de, DIR_ROOT
				ex de, hl
				ld b, 4
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_PRN2

				; otherwise we found our directory
				ld de, PRN_7BIT	;<-- this is a directory
				jr DOSNode_ExamineNext_Found

DOSNode_ExamineNext_PRN2:
				; if not root, then file not found
				push de
				push hl
				ld de, PRN_7BIT
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_Fail

				; otherwise we found our directory
				ld de, PRN_8BIT	;<-- this is a directory
				jr DOSNode_ExamineNext_Found

DOSNode_ExamineNext_RTG:
				; if not root, then file not found
				push de
				push hl
				ld de, DIR_ROOT
				ex de, hl
				ld b, 4
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_RTG2

				; otherwise we found our directory
				ld de, RTG_CRTC6845	;<-- this is a directory
				jr DOSNode_ExamineNext_Found

DOSNode_ExamineNext_RTG2:
				; if not root, then file not found
				push de
				push hl
				ld de, RTG_CRTC6845
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_Fail

				; otherwise we found our directory
				ld de, RTG_V9990	;<-- this is a directory
				jr DOSNode_ExamineNext_Found

DOSNode_ExamineNext_SPCH:
				; if not root, then file not found
				push de
				push hl
				ld de, DIR_ROOT
				ex de, hl
				ld b, 4
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_SPCH2

				; otherwise we found our directory
				ld de, SPCH_DKTRONIC	;<-- this is a directory
				jr DOSNode_ExamineNext_Found

DOSNode_ExamineNext_SPCH2:
				push de
				push hl
				ld de, SPCH_DKTRONIC
				ex de, hl
				ld b, 11
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_Fail

				; otherwise we found our directory
				ld de, SPCH_SSA1	;<-- this is a directory
				jr DOSNode_ExamineNext_Found

DOSNode_ExamineNext_TEST:
				; if not root, then file not found
				push de
				push hl
				ld de, DIR_ROOT
				ex de, hl
				ld b, 4
				call StrCompareB
				pop hl
				pop de
				jr nz, DOSNode_ExamineNext_Fail

				; otherwise we found our directory
				ld de, TEST_TXT2SCRN	;<-- this is a directory

DOSNode_ExamineNext_Found:
				push hl

				ex de, hl
				ld bc, 11
				ldir
				
				ld a, %00010000
				ld bc, 0
				ld de, 0

				pop hl
				jp DOSNode_Success

DOSNode_ExamineNext_Fail:	ld a, DSK_ERR_FILE_NOT_FOUND
				jp DOSNode_Success

;
; Rename a file or a directory
;
; Input   - A = drive number
;           HL = pointer to the normalized name
;           DE = pointer to the normalized path
;           IX = pointer to the new normalized name
;           BC = pointer to the new normalized path
;           The pointed memory is always located in the current ROM/RAM space area
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the file or directory was renamed
;                If NZ then the file or directory could not be renamed
;                    A = error code
;                In any case, the routine might truncate the provided normalized path to match the nearest parent
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF
	
DOSNode_Rename:			jp DOSNode_Fail

;
; Delete a file or a directory
;
; Input  - A = drive number
;           HL = pointer to the normalized name
;           DE = pointer to the normalized path
;           The pointed memory is always located in the current ROM/RAM space area
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the file or directory was deleted
;                If NZ then the file or directory could not be deleted
;                    A = error code
;                In any case, the routine might truncate the provided normalized path to match the nearest parent
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_Delete:			jp DOSNode_Fail

;
; Create a directory
;
; Input  - A = drive number
;           HL = pointer to the normalized name
;           DE = pointer to the normalized path
;           The pointed memory is always located in the current ROM/RAM space area
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the directory was created
;                If NZ then the directory could not be created
;                    A = error code
;                In any case, the routine might truncate the provided normalized path to match the nearest parent
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_CreateDir:
				jp DOSNode_Fail

;
; Change the protection bits of a file
;
; Input  - A = drive number
;           HL = pointer to the normalized name
;           DE = pointer to the normalized path
;           B = Protections to modify
;           C = New protections
;                Bit 0 - Read-only
;                Bit 1 - Hidden
;                Bit 5 = Archived
;           Other bits are ignored
;           The pointed memory is always located in the current ROM/RAM space area
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the protections were modified
;                If NZ then the protections could not be modified
;                    A = error code
;                In any case, the routine might truncate the provided normalized path to match the nearest parent
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_SetProtection:
				jp DOSNode_Fail

;
; Change last modification time and date of a file or a directory
;
; Input  - A = drive number
;           HL = pointer to the normalized name
;           DE = pointer to the normalized path
;           IX = buffer where last modification time and date to use for the entry are stored
;               One 16-bit word with year (1978..9999)
;               One byte with number of month (1..12)
;               One byte with number of day in the month (1..28,29,30 or 31)
;               One byte with hours (0..23)
;               One byte with minutes (0..59)
;               One byte with seconds (0..59)
;           The pointed memory is always located in the current ROM/RAM space area
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the time and date were modified
;                If NZ then the time and date could not be modified
;                    A = error code
;                In any case, the routine might truncate the provided normalized path to match the nearest parent
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_SetFileDate:
				jp DOSNode_Fail
				
;
; Format a drive
;
; Input  - A = drive number
; Output  - If Carry = 1 the routine is supported for the provided drive
;                If Z then the drive was formatted
;                If NZ then format failed
;                    A = error code
;           If Carry = 0 then the routine is invalid for the provided drive
; Altered - AF

DOSNode_Format:			jp DOSNode_Fail
				
;
; Read the contents of the real time clock
;
; Input   - IX = buffer where to store current time and date (7 octets)
; Output  - If Carry = 1 the the DOS node handles a relax time clock
;                IX = buffer where current time and date were stored
;                    One 16-bit word with year (1978..9999)
;                    One byte with number of the month (1..12)
;                    One byte with the number of the day in the month (1..28,29,30 or 31)
;                    One byte with hours (0..23)
;                    One byte with minutes (0..59)
;                    One byte with seconds (0..59)
;                 A = number of the day in the week (1..7, from Monday to Sunday)
;           If Carry = 0 the the DOS node do not handle a real time clock
; Altered - AF

DOSNode_ReadRTC:
				jp DOSNode_Fail

;
; Write into the real time clock
;
; Input   - IX = buffer containing time and date to write into real time clock (7 bytes)
;               One 16-bit word with year (1978..9999)
;               One byte with number of the month (1..12)
;               One byte with the number of the day in the month (1..28,29,30 or 31)
;               One byte with hours (0..23)
;               One byte with minutes (0..59)
;               One byte with seconds (0..59)
; Output  - If Carry = 1 then the DOS node handles a real time clock
;               If Z then the contents of the real time clock was updated
;               If NZ then an error occurred
;                   A = error code
;          If Carry = 1 then the DOS node do not handle a real time clock
; Altered - AF

DOSNode_WriteRTC:
				jp DOSNode_Fail

;
; Open the non volatile memory
;
; Input  - C = opening mode
;                If 0 then the non volatile memory shall be opened with its current contents
;                If 1 then the non volatile memory shall be opened with its contents reset
; Output  - If Carry = 1 then the DOS node provides non volatile memory
;                If Z then the non volatile memory has been opened and is ready for usage
;                If NZ then a error occured
;                    A = error code
;           If Carry = 0 then the DOS node do not provide non volatile memory
; Altered - AF

DOSNode_OpenNVRAM:
				jp DOSNode_Fail

;
; Close and update the non volatile memory memory contents
;
; Input  - None
; Output  - If Carry = 1 then the DOS node provides non volatile memory
;                If Z then the non volatile memory was properly updated
;                If NZ then an error occured
;           If Carry = 0 then the DOS node do not provide non volatile memory
; Altered - AF

DOSNode_CloseNVRAM:
				jp DOSNode_Fail

;
; Read data from the non volatile memory
;
; Input  - HL = address where to write read data
;           DE = number of bytes to read
; Output  - If Carry = 1 then the DOS node provides non volatile memory
;                If Z then data were read
;                    DE = number of bytes read
;                If NZ then a error occured
;                    A = error code
;           If Carry = 0 then the DOS node do not provide non volatile memory
; Altered - AF,DE

DOSNode_ReadNVRAM:
				jp DOSNode_Fail

;
; Write data to the non volatile memory
;
; Input  - HL = address where a located data to write
;           DE = number of bytes to write
; Output  - If Carry = 1 then the DOS node provides non volatile memory
;                If Z then data were written
;                    DE = number of bytes written
;                If NZ then a error occured
;                    A = error code
;           If Carry = 0 then the DOS node do not provide non volatile memory
; Altered - AF,DE

DOSNode_WriteNVRAM:
				jp DOSNode_Fail

;
; Change the position in the non volatile memory
;
; Input  - DEHL = new position
; Output  - If Carry = 1 then the DOS node provides non volatile memory
;                If Z then the new position was reached
;                If NZ then a error occured
;                    A = error code
;           If Carry = 0 then the DOS node do not provide non volatile memory
; Altered - AF,DE

DOSNode_SeekNVRAM:
				jp DOSNode_Fail

DOSNode_Void:			
				ret

DOSNode_Fail:			ccf
				ret

DOSNode_Success:
				scf
				ret

				; ------------------------- ListGetIDByName
				; -- parameters:
				; -- 	HL = address of list to find a string within
				; -- 	DE = string to find
				; -- 
				; -- return:
				; -- 	Z if found, NZ if not
				; --	A = entry number of found item
				; -- 	all other registers unknown

ListGetIDByName:
				ld a, (hl)
				or a
				jr z, ListGetIDByNameNotFound

				push de
				push hl
				call StrCompare
				pop hl
				call StrSkip
				pop de

				jr z, ListGetIDByNameFound
				
				inc hl		; skip 0 terminator
				inc hl		; skip device id
				jr ListGetIDByName
				
ListGetIDByNameFound:
				inc hl		; skip 0 terminator
				ld a, (hl)	; return the device id in a
				ret
				
ListGetIDByNameNotFound:
				ld a,1	;is there a better way to unset Z
				and a	;
				ret
				
				; ------------------------- StrCompare
				; -- parameters:
				; -- 	HL = zero terminated string source of truth
				; -- 	DE = string to compare
				; -- 
				; -- return:
				; -- 	Z if equal, NZ if not
				; -- 	all other registers unknown

StrCompare:	
StrCompareLoop:
				ld a, (hl)
				or a
				ret z						; found it, return

				call ToUpper
				and #7f
				
				push af
				ld a, (de)
				call ToUpper
				and #7f
				ld b, a
				pop af
				
				cp b
				ret nz						; didnt find it, return
				inc hl
				inc de
				jr StrCompareLoop

				; ------------------------- StrCompareB
				; -- parameters:
				; -- 	HL = string source of truth
				; -- 	DE = string to compare
				; --	B = length of string to compare
				; -- 
				; -- return:
				; -- 	Z if equal, NZ if not
				; -- 	all other registers unknown

StrCompareB:			push bc
StrCompareBLoop:
				ld a, (hl)
				call ToUpper
				and #7f
				
				push bc

				push af
				ld a, (de)
				call ToUpper
				and #7f
				ld b, a
				pop af

				cp b

				pop bc
				jr nz, StrCompareBEnd				; didnt find it, return
				inc hl
				inc de
				djnz StrCompareBLoop

StrCompareBEnd:
				pop bc
				ret

				; ------------------------- ToUpper
				; -- parameters:
				; -- 	A = character to make into uppercase
				; -- 
				; -- return:
				; -- 	A = uppercase character
				; -- 	all other registers preserved except flags

ToUpper: 			cp 'a'
				ret c
				cp 'z' + 1
				ret nc
				add a, 'A' - 'a'
				ret
		
				; ------------------------- StrCopy
				; copy a zero terminated string but including the zero terminator
				; -- parameters:
				; -- 	HL = source string address
				; -- 	DE = destination string address
				; -- 
				; -- return:
				; -- 	HL = the address of the source string terminator
				; -- 	DE = the address of the destination string terminator
				; -- 	all other registers unknown

StrCopy:	
				ld a,(hl)
				ld (de), a
				or a
				ret z						; end of string return
				inc hl
				inc de
				jr StrCopy
				
StrSkip:			push af

StrSkipLoop:
				ld a,(hl)
				or a
				jr z, StrSkipEnd
				inc hl
				jr StrSkipLoop
				
StrSkipEnd:			pop af
				ret

				; ------------------------- ValidateChar
				; -- parameters:
				; -- 	A = character to validate
				; -- 
				; -- return:
				; -- 	C if valid, NC if not
				; -- 	all other registers preserved

ValidateChar:
				cp 10
				jp z, DOSNode_Success

				cp 13
				jp z, DOSNode_Success

				cp ' '
				jr c, DOSNode_Fail

				cp 'z'
				jr nc, DOSNode_Fail

				jp DOSNode_Success


				; ------------------------- START OF STREAM OUTPUTS
				;           HL = address where are located the data to write
				;           DE = number of bytes to write

				; ------------------------- AMDRUM
AUD_AMDRUM_Output:

				push hl
				push bc
				push af
				di

AUD_AMDRUM_OutputLoop:

				ld b, DAC_DELAY

AUD_AMDRUM_OutputLoop2:

				push bc
				
				;ld c, (hl)
				rst #20			;ram_lam
				ld c, a			;
				ld b, PORT_AMDRUM
				out (c), c

				pop bc
				djnz AUD_AMDRUM_OutputLoop2
				
				inc hl
				dec de
				
				ld a,d
				or e
				jr nz, AUD_AMDRUM_OutputLoop

AUD_AMDRUM_OutputEnd:
				ei
				pop af
				pop bc
				pop hl
				jp DOSNode_Success

				; ------------------------- ASIC DAC simulation
AUD_ASIC_Output:
				jp DOSNode_Fail		; NOT YET IMPLEMENTED

				; ------------------------- AY8912 DAC simulation
AUD_AY8912_Output:
				jp DOSNode_Fail		; NOT YET IMPLEMENTED

				; ------------------------- DIGIBLASTER
AUD_DBLAST_Output:
				push hl
				push bc
				push af
				di

AUD_DBLAST_OutputLoop:

				ld b, DAC_DELAY

AUD_DBLAST_OutputLoop2:

				push bc
				
				;ld c, (hl)
				rst #20			;ram_lam
				ld b, PORT_DBLAST
				xor #80			;invert the 7th bit
				out (c), a

				pop bc
				djnz AUD_DBLAST_OutputLoop2
				
				inc hl
				dec de
				
				ld a,d
				or e
				jr nz, AUD_DBLAST_OutputLoop

AUD_DBLAST_OutputEnd:
				ei
				pop af
				pop bc
				pop hl
				jp DOSNode_Success

				; ------------------------- MUSIC MACHINE
AUD_MMACH_Output:

				push hl
				push bc
				push af
				di

AUD_MMACH_OutputLoop:

				ld b, DAC_DELAY

AUD_MMACH_OutputLoop2:

				push bc
				
				;ld c, (hl)
				rst #20			;ram_lam
				ld c, a			;
				ld b, PORT_MMACHINE
				out (c), c

				pop bc
				djnz AUD_MMACH_OutputLoop2
				
				inc hl
				dec de
				
				ld a,d
				or e
				jr nz, AUD_MMACH_OutputLoop

AUD_MMACH_OutputEnd:
				ei
				pop af
				pop bc
				pop hl
				jp DOSNode_Success


				; ------------------------- Standard 7bit Printer Port
PRN_7BIT_Output:
				push hl
				push af

PRN_7BIT_OutputLoop:
				;ld a, (hl)
				rst #20			;ram_lam
				call ValidateChar
				jr nc, PRN_7BIT_OutputSkip

PRN_7BIT_OutputLoop2:
				call MC_PRINT_CHAR
				jr nc, PRN_7BIT_OutputLoop2
				
PRN_7BIT_OutputSkip:
				inc hl
				dec de
				
				ld a,d
				or e
				jr nz, PRN_7BIT_OutputLoop

PRN_7BIT_OutputEnd:
				pop af
				pop hl
				jp DOSNode_Success

				; ------------------------- 8bit Printer Port
PRN_8BIT_Output:
				jp DOSNode_Fail		; NOT YET IMPLEMENTED

				; ------------------------- CRTC6845 Onboard Graphics
RTG_CRTC6845_Output:
				jp DOSNode_Fail		; NOT YET IMPLEMENTED

				; ------------------------- V9990 Graphics Card
RTG_V9990_Output:
				jp DOSNode_Fail		; NOT YET IMPLEMENTED

				; ------------------------- SSA1 Speech Synthesizer
SPCH_SSA1_Output:
				jp DOSNode_Fail		; NOT YET IMPLEMENTED

				; ------------------------- DkTronics Speech Synthesizer
SPCH_DKTRONIC_Output:
				jp DOSNode_Fail		; NOT YET IMPLEMENTED

				; ------------------------- TXT2SCRN Output to Display
TEST_TXT2SCRN_Output:

				push hl
				push af

TEST_TXT2SCRN_OutputLoop:
				;ld a, (hl)
				rst #20			;ram_lam
				call ValidateChar
				jr nc, TEST_TXT2SCRN_OutputSkip

				call TXT_OUT_CHAR
				
TEST_TXT2SCRN_OutputSkip:
				inc hl
				dec de
				
				ld a,d
				or e
				jr nz, TEST_TXT2SCRN_OutputLoop

TEST_TXT2SCRN_OutputEnd:
				pop af
				pop hl
				jp DOSNode_Success

				; ------------------------- END OF STREAM OUTPUTS

CODE_END:			; ds #4000 - (CODE_END - CODE_START)

;				save "STREAMER.ROM", #C000, #4000, AMSDOS

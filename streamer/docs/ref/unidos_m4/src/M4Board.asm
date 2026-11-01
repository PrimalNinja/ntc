;
; M4 Board DOS Node
;
; Gestionnaire du noeud DOS de la M4 Board pour l'UniDOS
; Par OffseT/Futurs' - (c) 2021
;
; Prévu pour être assemblé avec rasm 1.4+
;

firmware=3
use_ftp=1
use_test=0

        Save"bin/M4.rom",&c000,&4000,amsdos

        Read"SystemCalls.i"
        Read"SystemData.i"
        Read"M4Board.i"

        Read"DOSMap.i"

        Org &c000
        Limit &ffff

CodeStart       db 2    ; ROM d'extension

                db 1    ; Marque
                db 4    ; Version
                db 3    ; Révision

_RsxTable       dw RSXTable

_InitRom        jp InitROM
                jp DOSNode_Init
                jp DOSNode_CheckDrive
                jp DOSNode_GetStatus
                jp DOSNode_GetName
                jp DOSNode_GetDesc
                jp DOSNode_GetFreeSpace
                jp DOSNode_InOpenStream
                jp DOSNode_InReadStream
                jp DOSNode_InCloseStream
                jp DOSNode_InSeekStream
                jp DOSNode_OutOpenStream
                jp DOSNode_OutWriteStream
                jp DOSNode_OutCloseStream
                jp DOSNode_OutSeekStream
                jp DOSNode_Examine
                jp DOSNode_ExamineNext
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
                jp RSX_Library
                jp RSX_HTTPGet
                jp RSX_DSK
                jp RSX_CPR
                jp RSX_SNA
If use_ftp
                jp RSX_FTP
EndIf
                jp RSX_M4_Disable
                jp RSX_M4_FlashROM
                jp RSX_M4_ROMOn
                jp RSX_M4_ROMOff
                jp RSX_M4_NetConfig
                jp RSX_M4_NetStat
;                jp RSX_M4_WIFIOn   ; Désactivé pour le moment car couper le WIFI fait planter
;                jp RSX_M4_WIFIOff  ; tout appel aux autres commandes de gestion du réseau...
                jp RSX_M4_Version
                jp RSX_M4_Upgrade
If use_test
                jp RSX_Test
EndIf

RSXTable        str "M4 "
                str "DOS Node"
Repeat 31
                db &80
REnd
                str "LIBRARY"
                str "HTTPGET"
                str "DSK"
                str "CPR"
                str "SNA"
If use_ftp
                str "FTP"
EndIf
                str "M4.DISABLE"
                str "M4.FLASHROM"
                str "M4.ROMON"
                str "M4.ROMOFF"
                str "M4.NETCONFIG"
                str "M4.NETSTAT"
;                str "M4.WIFION"
;                str "M4.WIFIOFF"
                str "M4.VERSION"
                str "M4.UPGRADE"
If use_test
                str "TEST"
EndIf
                ; Fin de la table des RSX
                db 0

;
; Initialise la ROM
;

InitROM or a
        ret

        Read"LowLevel.a"
        Read"Sockets.a"
        Read"FTP.a"
        Read"DOSNode.a"
        Read"DataAccess.a"
        Read"Misc.a"

;
; |TEST
;

RSX_TEST
        call RSX_Install

        call M4_FTPConnect
        ret nc

        call TestFTP

        call M4_FTPDisconnect

        ret

TestFTP
        ; Système distant

        push bc
        MAKE_ID_DEHL 'S','Y','S','T'
        call M4_FTPStartCommand
        call M4_FTPFinalizeCommand
        pop bc

        call M4_FTPSendCommand
        ret nc
        call M4_FTPGetResponse
        ret nc

        ; Démarre une session LIST

        call M4_FTPList

GetEntryLoop
        push bc
        ld hl,&4000
        call M4_FTPGetEntry
        pop bc
        jr c,GetEntryLoop

        push bc
        ld c,b
        call M4_DestroySocket
        pop bc

        call M4_FTPGetResponse
        ret

        ; Récupère les données LIST

        push bc
        ld c,b
        call RSXTestGetData
RSXTestExit
        call M4_DestroySocket
        pop bc

        call M4_FTPGetResponse
        ret

RSXTestGetData
RSXTestGetDataLoop
        ld hl,_DOS_ROM_TEMP_STORE+&24
        ld de,1
        call M4_ReadSocket
        ret nc
        ld a,(hl)
        call _TXT_OUTPUT
        jr RSXTestGetDataLoop

RSXCheckResult
        push af
        push hl

        ld hl,ResultOk
        jr c,RSXCheckResultOk
        ld hl,ResultKo
RSXCheckResultOk
        call PrintString
        call _KM_WAIT_KEY

        pop hl
        pop af
        ret

RSXRegs push af

        call PrintHexaNumber8
        ld a,' ':call _TXT_OUTPUT

        ld a,h:call PrintHexaNumber8
        ld a,l:call PrintHexaNumber8
        ld a,' ':call _TXT_OUTPUT

        ld a,d:call PrintHexaNumber8
        ld a,e:call PrintHexaNumber8
        ld a,' ':call _TXT_OUTPUT

        ld a,b:call PrintHexaNumber8
        ld a,c:call PrintHexaNumber8
        ld a,' ':call _TXT_OUTPUT

        ld a,ixh:call PrintHexaNumber8
        ld a,ixl:call PrintHexaNumber8
        ld a,' ':call _TXT_OUTPUT

        ld a,iyh:call PrintHexaNumber8
        ld a,iyl:call PrintHexaNumber8
        ld a,' ':call _TXT_OUTPUT

        ld a,'\r':call _TXT_OUTPUT
        ld a,'\n':call _TXT_OUTPUT

        pop af
        ret

ResultOk
        str "Success!\r\n"
ResultKo
        str "Failed!\r\n"

;
; |LIBRARY
;

RSX_Library
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        cp 2
        jp nc,Return_BadCommand

        ld b,0

        cp 1
        call z,RSX_GetArg1_String

        call M4_LibraryListInit
        jp nc,Return_LibDirNotFound

        ld c,0  ; Marqueur de contenu
LibListLoop
        call _TXT_GET_WINDOW
        ld a,d
        sub 6
        cp LibItemMaxLen
        jr c,LibListLoopMaxLen
        ld a,LibItemMaxLen
LibListLoopMaxLen
        ld hl,_DOS_ROM_ALT_BUFFER
        ld b,a
        call M4_LibraryListNext
        jr nc,LibListLoopEnd

        ld c,1

        push af
        push hl
        call LibListPrintType
        pop hl
        pop af

        or a
        call z,LibListPrintNameAltPen
        call nz,LibListPrintName

        ld a,'\r'
        call _TXT_OUTPUT
        ld a,'\n'
        call _TXT_OUTPUT

        call TestESC
        ret c

        jr LibListLoop

LibListLoopEnd
        ld a,c
        or a
        jr nz,LibListSuccess
        ld hl,Msg_LibraryIsEmpty
        call PrintString
LibListSuccess
        scf
        ret

LibListPrintType
        cp 5    ; Nombre de types connus dans LibListTypes
        jr nc,LibListPrintTypeUnknown
        add a,a
        ld e,a
        ld d,0
        ld hl,LibListTypes
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp PrintAltPenString
LibListPrintTypeUnknown
        ld hl,Msg_TypeUnknown
        jp PrintAltPenString

LibListPrintNameAltPen
        push af
        call SetAlternatePen
        push af
        call LibListPrintName
        pop af
        call _TXT_SET_PEN
        pop af
        ret
LibListPrintName
LibListPrintNameLoop
        ld a,(hl)
        and &7f
        call _TXT_OUTPUT
        bit 7,(hl)
        ret nz
        inc hl
        jr LibListPrintNameLoop

LibListTypes
        dw Msg_TypeDir,Msg_TypeDSK,Msg_TypeExtendedDSK,Msg_TypeCPR,Msg_TypeSNA

;
; |HTTPGET
;

RSX_HTTPGet
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        cp 3
        jp nc,Return_BadCommand

        or a
        jp z,Return_BadCommand

        ld b,0

        cp 2
        call z,RSX_GetArg2_String

        ld c,b
        ex de,hl

        call RSX_GetArg1_String

        ld a,b
        or a
        jp z,Return_BadCommand

        call M4_HTTPGet
        ret c

        cp DSK_ERR_FILE_NOT_FOUND
        jp nc,Return_HostNotReachable

        cp DSK_ERR_NOT_A_DIRECTORY
        jp nc,Msg_LibDirNotFound

        jp Return_BadCommand

;
; |DSK
;

RSX_DSK
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jr z,DSKDisplay

        cp 1
        jp nz,Return_BadCommand

        call RSX_GetArg1_String
        xor a
        cp b
        jp z,Return_BadCommand

        call M4_MountDSK
        jp nc,Return_MountFailed

        call M4_SetDSK
        ret

DSKDisplay
        call M4_CurrentDSK
        jp nc,Return_NoValidDSK

        ld hl,_DOS_ROM_TEMP_STORE
        call M4_GetDSK
        jp nc,Return_NoValidDSK

        ld a,(_DOS_ROM_TEMP_STORE+2)
        ld hl,_DOS_ROM_TEMP_STORE+3
        ld b,a
DSKDisplayLoop
        ld a,(hl)
        inc hl
        call _TXT_OUTPUT
        djnz DSKDisplayLoop
        ld a,'\r'
        call _TXT_OUTPUT
        ld a,'\n'
        call _TXT_OUTPUT
        ret

;
; |CPR
;

RSX_CPR
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        cp 1
        jp nz,Return_BadCommand

        call RSX_GetArg1_String
        xor a
        cp b
        jp z,Return_BadCommand

        call M4_FlashCPR
        jp nc,Return_CPRFlashFailed

        call M4_StartCPR

        ret

;
; |SNA
;

RSX_SNA
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        cp 1
        jp nz,Return_BadCommand

        call RSX_GetArg1_String
        xor a
        cp b
        jp z,Return_BadCommand

        call _TXT_VDU_DISABLE

        call M4_LoadSNA ; Pas de retour si ok

        call _TXT_VDU_ENABLE

        jp Return_SNAFailed

;
; |FTP
;

RSX_FTP
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jr z,FTPDisplay

        cp 1
        jr z,FTPConfigAnonymous

        cp 3
        jr z,FTPConfigUserPass

        jp Return_BadCommand

FTPConfigUserPass
        call FTPCheckGetServerIP
        call FTPAddInfo         ; Serveur
        jp nc,Return_BadCommand

        call RSX_GetArg2_String 
        call FTPAddInfo         ; Identifiant
        jp nc,Return_BadCommand

        call RSX_GetArg3_String 
        call FTPAddInfo         ; Mot de passe
        jp nc,Return_BadCommand

        ld hl,_DOS_ROM_TEMP_STORE
        ld b,a
        call M4_SetFTP
        ret

FTPConfigAnonymous
        call FTPCheckGetServerIP
        call FTPAddInfo         ; Serveur
        jp nc,Return_BadCommand

        ld hl,FTP_Anonymous
        ld b,9
        call FTPPrepareArg
        call FTPAddInfo         ; Identifiant
        jp nc,Return_BadCommand

        ld hl,FTP_Email
        ld b,19
        call FTPAddInfo         ; Mot de passe
        jp nc,Return_BadCommand

        ld hl,_DOS_ROM_TEMP_STORE
        ld b,a
        call M4_SetFTP
        ret

FTPDisplay
        ld hl,_DOS_ROM_TEMP_STORE
        call M4_GetFTP
        jp nc,Return_NoValidFTP

        ld hl,_DOS_ROM_TEMP_STORE+6

        call FTPDisplayNewLine

        call FTPDisplayServer
        call FTPDisplayPort
        call FTPDisplayLogin
        call FTPDisplayPassword
        call FTPDisplayStatus

        jp FTPDisplayNewLine

FTPPrepareArg
        push af
        push bc
        push de

        ld a,b
        ld de,_DOS_ROM_ALT_BUFFER
        push de
        ld b,0
        ld c,a
        ldir
        pop hl
        ld b,a

        pop de
        pop bc
        pop af
        ret

FTP_Anonymous
        db "anonymous"
FTP_Email
        db "unidos@cpcscene.net"

FTPCheckGetServerIP
        call RSX_GetArg1_String ; Serveur:Port
        ld a,':'
        call SplitString        ; HL/B = serveur, DE/C = port
        push hl
        push bc
        ex de,hl
        ld b,c
        call FTPGetPort
        ld (_DOS_ROM_TEMP_STORE+4),de
        pop bc
        pop hl
        jp nc,Return_BadCommand

        push hl
        call M4_GetIPFromHost
        ld (_DOS_ROM_TEMP_STORE+0),hl
        ld (_DOS_ROM_TEMP_STORE+2),de
        pop hl
        jp nc,Return_HostNotReachable

        ld a,6                  ; IP(4)+Port(2)
        ld de,_DOS_ROM_TEMP_STORE+6
        ret

FTPDisplayServer
        push hl
        ld hl,FTPServerString
        call PrintAltPenString
        pop hl

        call FTPDisplayInfo

        push af
        push bc
        push de
        push hl

        call SetAlternatePen
        push af

        ld hl,FTPParentOn
        call PrintString

        ld de,_DOS_ROM_TEMP_STORE+3 ; Fin IP (little endian...)
        ld b,4
        jr FTPDisplayServerIP

FTPDisplayServerIPLoop
        ld a,'.'
        call _TXT_OUTPUT

FTPDisplayServerIP
        push bc
        push de

        ld a,(de)

        ld e,a
        ld d,0
        call PrintNumber

        pop de
        pop bc
        dec de
        djnz FTPDisplayServerIPLoop

        ld hl,FTPParentOff
        call Printstring

        pop af
        call _TXT_SET_PEN

        pop hl
        pop de
        pop bc
        pop af
        ret

FTPDisplayPort
        push af
        push bc
        push de
        push hl

        ld hl,FTPPortString
        call PrintAltPenString
        ld de,(_DOS_ROM_TEMP_STORE+4)
        call PrintNumber

        pop hl
        pop de
        pop bc
        pop af

        jr FTPDisplayNewLine

FTPDisplayLogin
        push hl
        ld hl,FTPLoginString
        call PrintAltPenString
        pop hl

        call FTPDisplayInfo

        jr FTPDisplayNewLine

FTPDisplayPassword
        push hl
        ld hl,FTPPasswordString
        call PrintAltPenString
        pop hl

        call FTPDisplayInfo

        jr FTPDisplayNewLine

FTPDisplayStatus
        push hl
        ld hl,FTPStatusString
        call PrintAltPenString
        pop hl

        call M4_FTPConnect
        jr nc,FTPDisplayStatusError
        call M4_FTPDisconnect

        ld hl,FTPStatusConnected
        jp PrintString

FTPDisplayStatusError
        ld hl,FTPStatusSocketError
        jp z,PrintString
        ld hl,FTPStatusFTPError
        jp PrintString

FTPDisplayNewLine
        push hl
        ld hl,Msg_NewLine
        call PrintString
        pop hl
        ret

FTPDisplayInfo
        ld b,(hl)
        inc hl
FTPDisplayInfoLoop
        ld a,(hl)
        inc hl
        call _TXT_OUTPUT
        djnz FTPDisplayInfoLoop
        ret

FTPServerString
        str "  Server: "
FTPPortString
        str "    Port: "
FTPLoginString
        str "   Login: "
FTPPasswordString
        str "Password: "
FTPStatusString
        str "  Status: "
FTPStatusConnected
        str "Connected\r\n"
FTPStatusSocketError
        str "Network error\r\n"
FTPStatusFTPError
        str "Login failed\r\n"
FTPParentOn
        str " ("
FTPParentOff
        str ")\r\n"

FTPAddInfo
        add a,b
        inc a
        cp FTPInfoMaxLen+1
        ret nc
        ex de,hl
        ld (hl),b
        inc hl
        ex de,hl
        ld c,b
        ld b,0
        ldir
        scf
        ret
; Entrée - HL/B, Sortie - DE (C=OK, NC=KO)
FTPGetPort
        ld de,21    ; Port
        xor a
        cp b
        scf
        ret z   ; C, valeur par défaut

        push bc
        ld a,b

        ld bc,0
        ld de,0
FTPGetPortLoop
        push af
        ld a,(hl)
        inc hl
        call IsDigit
        jr nc,FTPGetPortInvalid
        call MultiplySize
        call GetSizeDigit
        ld a,c
        or b
        jr nz,FTPGetPortInvalid
        pop af
        dec a
        jr nz,FTPGetPortLoop
FTPGetPortExit
        pop bc
        scf
        ret
FTPGetPortInvalid
        pop af
        pop bc
        cp a    ; NC
        ret

;
; |M4.DISABLE
;

RSX_M4_Disable
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp nz,Return_BadCommand

        call M4_Disable
        scf
        ret

;
; |M4.FLASHROM
;

RSX_M4_FlashROM
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        cp 2
        jp nz,Return_BadCommand

        ld a,(ix-3)
        or a
        jp nz,Return_ROMBadSlot

        ld hl,Msg_FlashROMWarnText
        call PrintString

FlashROMLoopWaitKey
        call _KM_FLUSH
        call _KM_WAIT_CHAR
        call ToUpper
        cp 'Y'
        jr nz,FlashROMCancelled
        call _TXT_OUTPUT

        call _CAS_IN_ABANDON

        call RSX_GetArg1_String

        push ix
        call _CAS_IN_OPEN
        pop ix
        ret nc

        ld hl,&c000
        push ix
        call _CAS_IN_DIRECT
        pop ix
        jr nc,FlashROMClose

        call _CAS_IN_CLOSE

        call M4_Check   ; Réinitialise la zone private data correspondant au noeud M4
                        ; (nécessaire à l'utilisation des routines du LowLevel.a)
        ld hl,&c000
        ld c,(ix-4)
        call M4_FlashROM

        push af
        call _SCR_CLEAR
        pop af

        jp nc,Return_ROMFlashFailed

        call RSX_GetArg1_String
        ld a,b
        cp 31
        jr c,FlashROMNameFits
        ld b,31
FlashROMNameFits
        ld c,(ix-4)
        ld d,2  ; Rechargement en flash
        call M4_ROMSetStatus

        jp nc,Return_ROMStatusFailed

        call M4_ResyncROMs

        rst 0
        ret

FlashROMClose
        call _CAS_IN_CLOSE
        jp Return_BadCommand

FlashROMCancelled
        ld hl,Msg_FlashROMCancelled
        call PrintString
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret

;
; |M4.ROMON
;

RSX_M4_ROMOn
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp z,Return_BadCommand

        ld d,1  ; On
        ld b,0  ; Pas de mise à jour du nom
        jr ROMOnOff

;
; |M4.ROMOFF
;

RSX_M4_ROMOff
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp z,Return_BadCommand

        ld d,0  ; Off
        ld b,0  ; Pas de mise à jour du nom
ROMOnOff
        push ix
        pop hl

        ld e,a
ROMOnOffLoop
        dec hl
        ld a,(hl)
        or a
        jp nz,Return_ROMBadSlot
        dec hl
        ld c,(hl)
        call M4_ROMOnOff
        jp nc,Return_ROMStatusFailed
        dec e
        jr nz,ROMOnOffLoop

        rst 0
        ret

;
; |M4.NETCONFIG
;

RSX_M4_NetConfig
        call M4_Check   ; Simple redirection vers la M4 ROM ; on ne touche pas à IX
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        cp 1
        jp nz,Return_BadCommand

        ld hl,M4ROM_NetSetRSXName
        call CopyRSXNameToRAM

        push ix
        call GetPrivateDataIX
        ld c,(ix+1)
        pop ix

        ld de,_DOS_ROM_TEMP_ROUTINE+&20
        call SearchRSXInSingleROM

        jp nc,Return_BadCommand

        ; Va planter si le WIFI est éteint...

        ld a,1
        FAR_PCHL

        ret

M4ROM_NetSetRSXName
        str "NETSET"

;
; |M4.NETSTAT
;

RSX_M4_NetStat
        call M4_Check   ; Simple redirection vers la M4 ROM ; on ne touche pas à IX
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp nz,Return_BadCommand

        ld hl,M4ROM_NetStatRSXName
        call CopyRSXNameToRAM

        push ix
        call GetPrivateDataIX
        ld c,(ix+1)
        pop ix

        ld de,_DOS_ROM_TEMP_ROUTINE+&20
        call SearchRSXInSingleROM

        jp nc,Return_BadCommand

        ; Va planter si le WIFI est éteint...

        xor a
        FAR_PCHL

        ret

M4ROM_NetStatRSXName
        str "NETSTAT"

;
; |M4.WIFION
;

RSX_M4_WIFIOn
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp nz,Return_BadCommand

        ld a,1
        call M4_SetWifi

        scf
        ret

;
; |M4.WIFIOFF
;

RSX_M4_WIFIOff
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp nz,Return_BadCommand

        xor a
        call M4_SetWifi

        scf
        ret

;
; |M4.VERSION
;

RSX_M4_Version
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp nz,Return_BadCommand

        ld hl,_DOS_ROM_ALT_BUFFER
        call M4_Version

        call PrintString
        scf
        ret

;
; |M4.UPGRADE
;

RSX_M4_Upgrade
        call RSX_Install
        jp nc,Return_BadCommand
        jp nz,Return_BadCommand

        or a
        jp nz,Return_BadCommand

        ld hl,_DOS_ROM_ALT_BUFFER
        call M4_Upgrade

        call PrintString
        scf
        ret

;
; Routines annexes
;

; Prépare l'espace de travail (« private data ») pour un appel depuis des RSX
RSX_Install
        call RSX_FixIX
        jp M4_Check

; Modifie l'index d'accès aux paramètres pour qu'il soit identique selon le nom d'arguments
; IX-2/1 = premier, IX-3/4 = deuxième, IX-5/6 = troisième, etc..
RSX_FixIX
        ld c,a
        ld b,0
        add ix,bc
        add ix,bc
        ret

; HL=pointeur vers la chaîne, B=taille de la chaîne
RSX_GetArg1_String
        ld h,(ix-1)
        ld l,(ix-2)
GetArgcommon
        push af
        push bc
        push hl
        inc hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop bc
        ld a,(bc)
        pop bc
        ld b,a
        pop af
        ret

; HL=pointeur vers la chaîne, B=taille de la chaîne
RSX_GetArg2_String
        ld h,(ix-3)
        ld l,(ix-4)
        jr getargcommon

; HL=pointeur vers la chaîne, B=taille de la chaîne
RSX_GetArg3_String
        ld h,(ix-5)
        ld l,(ix-6)
        jr getargcommon

; Routines de sortie en erreur

Return_BadCommand
        ld hl,Msg_BadCommand
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_MountFailed
        ld hl,Msg_MountFailed
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_NoValidDSK
        ld hl,Msg_NoValidDSK
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_LibDirNotFound
        ld hl,Msg_LibDirNotFound
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_ROMBadSlot
        ld hl,Msg_ROMBadSlot
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_ROMStatusFailed
        ld hl,Msg_ROMStatusFailed
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_ROMFlashFailed
        ld hl,Msg_ROMFlashFailed
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_CPRFlashFailed
        ld hl,Msg_CPRFlashFailed
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_SNAFailed
        ld hl,Msg_SNAFailed
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_HostNotReachable
        ld hl,Msg_HostNotReachable
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret
Return_NoValidFTP
        ld hl,Msg_NoValidFTP
        call printerrstring
        ld a,dsk_err_quiet_bad_command
        cp a    ; NC/Z
        ret


Msg_TypeDir   
        str "[Dir] "
Msg_TypeDSK
        str " DSK: "
Msg_TypeExtendedDSK
        str "eDSK: "
Msg_TypeCPR
        str " CPR: "
Msg_TypeSNA
        str " SNA: "
Msg_TypeUnknown
        str " ???: "

Msg_NewLine
        str "\r\n"
Msg_BadCommand
        str "\r\nBad command\r\n"
Msg_MountFailed
        str "\r\nMount failed\r\n"
Msg_NoValidDSK
        str "\r\nNo valid DSK selected\r\n"
Msg_LibDirNotFound
        str "\r\nLibrary not found\r\n"
Msg_ROMBadSlot
        str "\r\nBad slot number\r\n"
Msg_ROMStatusFailed
        str "\r\nFailed to update ROM status\r\n"
Msg_FlashROMWarnText
	str "System will reboot after ROM flashing\r\nAre you sure? (Y/n) "
Msg_ROMFlashFailed
        str "\r\nFailed to flash ROM\r\n"
Msg_FlashROMCancelled
	str "** cancelled **"
Msg_CPRFlashFailed
        str "\r\nFailed to flash CPR\r\n"
Msg_NotAplus
        str "\r\nAmstrad Plus required\r\n"
Msg_SNAFailed
        str "\r\nFailed to load snapshot\r\n"
Msg_HostNotReachable
        str "\r\nHost not reachable\r\n"
Msg_NoValidFTP
        str "\r\nNo valid FTP set\r\n"
Msg_LibraryIsEmpty
        str "\r\nNo library item\r\n"

CodeEnd

;
; Somme de contrôle
;

        Org &ffff
        Limit $+1

        SumMem codestart,$

Breakpoint M4_ReadSocket

;Breakpoint DOSNode_InOpenStream
;Breakpoint DOSNode_InReadStream
;Breakpoint DOSNode_InCloseStream
;Breakpoint DOSNode_InSeekStream
;Breakpoint DOSNode_OutOpenStream
;Breakpoint DOSNode_OutWriteStream
;Breakpoint DOSNode_OutCloseStream
;Breakpoint DOSNode_OutSeekStream
;Breakpoint DOSNode_Examine
;Breakpoint DOSNode_ExamineNext
;Breakpoint DOSNode_Rename
;Breakpoint DOSNode_Delete
;Breakpoint DOSNode_CreateDir
;Breakpoint DOSNode_SetProtection


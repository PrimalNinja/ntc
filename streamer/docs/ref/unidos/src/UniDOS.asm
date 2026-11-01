;
; UniDOS
;
; Système d'exploitation disque multi-périphérique
; Par OffseT/Futurs' - (c) 2021-2022
;
; Prévu pour être assemblé avec rasm 1.4+
;

firmware=3

        Save"bin/UniDOS.rom",&c000,&4000,amsdos

        Read"SystemCalls.i"
        Read"SystemData.i"
        Read"ConfigFile.i"

        Read"DataMap.i"

        Org &c000
        Limit &ffff

CodeStart

_ROMTag             db 1    ; ROM de second plan

                    db 1    ; Marque
                    db 5    ; Version
                    db 1    ; Revision

_RsxTable           dw rsxtable

                    ; RSX de base de l'AMSDOS
_InitRom            jp initrom
_Cat                jp rsx_cat
_Disc               jp rsx_disc
_Disc_In            jp rsx_disc.in
_Disc_Out           jp rsx_disc.out
_Tape               jp rsx_tape
_Tape_In            jp rsx_tape.in
_Tape_Out           jp rsx_tape.out
_A                  jp rsx_a
_B                  jp rsx_b
_Drive              jp rsx_drive
_Path               jp rsx_path
_Dir                jp rsx_dir
_Era                jp rsx_era
_Ren                jp rsx_ren
                    ; BIOS de base de l'AMSDOS
_ctrl_a             jp bios_setmessage
_ctrl_b             jp bios_setupdisc
_ctrl_c             jp bios_selectformat
_ctrl_d             jp bios_readsector
_ctrl_e             jp bios_writesector
_ctrl_f             jp bios_formattrack
_ctrl_g             jp bios_movetrack
_ctrl_h             jp bios_getstatus
_ctrl_i             jp bios_setretrycount
                    ; CP/M 2
                    jp bios_void ; cpm_enter_firmware
                    jp bios_void ; cpm_set_reg_save
                    jp bios_void ; cpm_set_sio
                    jp bios_void ; cpm_setcmnd_buffer
                    jp bios_void ; cpm_d0_in_status
                    jp bios_void ; cpm_d0_in
                    jp bios_void ; cpm_d0_out_status
                    jp bios_void ; cpm_d0_out
                    jp bios_void ; cpm_d1_in_status
                    jp bios_void ; cpm_d1_in
                    jp bios_void ; cpm_d1_out_status
                    jp bios_void ; cpm_d1_out
                     ; Menu du firmware v4
                    jp firm_plusmenu
                    ; BIOS additionnelles de l'UniDOS
_ctrl_j             jp bios_command
                    ; RSX additionnelles de l'UniDOS
_Protect            jp rsx_protect
_Unprotect          jp rsx_unprotect
_Hide               jp rsx_hide
_Show               jp rsx_show
_MakeLink           jp rsx_makelink
_ReadLink           jp rsx_readlink
_Info               jp rsx_info
_List               jp rsx_list
_Copy               jp rsx_copy
_Format             jp rsx_format
_Node               jp rsx_node
_Load               jp rsx_load
_Save               jp rsx_save
_SaveA              jp rsx_savea
_Clock              jp rsx_clock
_SetFileDate        jp rsx_setfiledate
_AMSDOS             jp rsx_amsdos

RSXTable
                    ; RSX de base de l'AMSDOS
_RSX_UniDOS         str "UNIDOS "
_RSX_CAT            str "CAT"  ; Remplace |CPM
_RSX_DISC           str "DISC"
_RSX_DISC_IN        str "DISC.IN"
_RSX_DISC_OUT       str "DISC.OUT"
_RSX_TAPE           str "TAPE"
_RSX_TAPE_IN        str "TAPE.IN"
_RSX_TAPE_OUT       str "TAPE.OUT"
_RSX_A              str "A"
_RSX_B              str "B"
_RSX_DRIVE          str "DRIVE"
_RSX_PATH           str "PATH" ; Remplace |USER
_RSX_DIR            str "DIR"
_RSX_ERA            str "ERA"
_RSX_REN            str "REN"
                    ; BIOS de base de l'AMSDOS
_RSX_CTRL_A         db &81    ; Ctrl A
_RSX_CTRL_B         db &82    ; Ctrl B
_RSX_CTRL_C         db &83    ; Ctrl C
_RSX_CTRL_D         db &84    ; Ctrl D
_RSX_CTRL_E         db &85    ; Ctrl E
_RSX_CTRL_F         db &86    ; Ctrl F
_RSX_CTRL_G         db &87    ; Ctrl G
_RSX_CTRL_H         db &88    ; Ctrl H
_RSX_CTRL_I         db &89    ; Ctrl I
                    ; CP/M
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    db &80
                    ; Menu du firmware v4
                    db &80
                    ; BIOS additionnelles de l'UniDOS
_RSX_CTRL_J         db &8a    ; Ctrl J
                    ; RSX addtionnelles de l'UniDOS
_RSX_PROTECT        str "PROTECT"
_RSX_UNPROTECT      str "UNPROTECT"
_RSX_HIDE           str "HIDE"
_RSX_SHOW           str "SHOW"
_RSX_MAKELINK       str "MAKELINK"
_RSX_READLINK       str "READLINK"
_RSX_INFO           str "INFO"
_RSX_LIST           str "LIST"
_RSX_COPY           str "COPY"
_RSX_FORMAT         str "FORMAT"
_RSX_NODE           str "NODE"
_RSX_LOAD           str "LOAD"
_RSX_SAVE           str "SAVE"
_RSX_SAVEA          str "SAVEA"
_RSX_CLOCK          str "CLOCK"
_RSX_SETFILEDATE    str "SETFILEDATE"
_RSX_AMSDOS         str "AMSDOS"
                    ; Fin de la table des RSX
                    db 0

;
; Erreur d'initialisation
;

CheckSumError
        ld de,msg_init_checksum_error
        jr errorinit
InvalidInstall
        ld de,msg_init_bad_rom_order
        jr errorinit
WrongSystemInstall
        ld de,msg_init_incompatible_basic
ErrorInit
        ld hl,msg_init_error
        call printstring
        ex de,hl
        call printstring
        jp skipinit

;
; Initialise la ROM
;

InitROM push ix
        push iy

        push hl
        push de

; Somme de contrôle valide ?

        call checksum
        jr nz,checksumerror

; Est-ce que le bon système est installé ?

        call checkbasic
        jr nz,wrongsysteminstall

; Installation du vecteur KL OLD FIND COMMAND en préalable à tout appel kernel

        call installoldfindcommand

; Est-ce qu'une ROM disque compatible Amsdos est déjà en place ?

        pop de
        pop hl

        push hl
        push de

        call isfirstrominit         ; Dans le cas où la liste des ROM n'a pas été mise à zéro (Starkos de CNG Soft)
        call nz,findamsdos          ; C = numéro de la ROM AMSDOS
        jr c,integratedinstall

; Peut-être que la ROM est là mais non initialisée ?

        ld c,0                      ; C = no AMSDOS
        push bc
        call huntamsdos
        ld a,c
        pop bc
        jp nc,standaloneinstall

; On initialise manuellement la ROM AMSDOS trouvée

AmsdosManualInstall
        ld c,a
        call _kl_curr_selection
        cp c
        jr nc,invalidinstall

        pop de
        pop hl
        push bc
        call _kl_init_back
        pop bc
        push hl
        push de
        jr nc,standaloneinstall

; Installation à la place de l'Amsdos

IntegratedInstall
        ld iy,(_dos_rom_base_address)
        PUT_C amsdosrom

        call checkdisabletag        ; On interrompt l'init ici si le tag de désactivation est installé
        jr nz,skipinit              ; (après d'être assuré que l'Amsdos est bien présent)

        call configuredataspace

        call _kl_curr_selection
        ld e,a
        ld d,0
        ld ix,_kl_rom_base_address_table
        add ix,de
        add ix,de
        ld de,(_dos_rom_base_address)
        ld (ix+0),e                 ; Mise en place de l'adresse de travail
        ld (ix+1),d

        call _kl_curr_selection     ; Recherche de la position où insérer notre ROM tag
        ld ix,_kl_rom_block_chain
NextROMBlockLoop
        ld e,(ix+0)
        ld d,(ix+1)
        cp (ix+2)
        jr c,romtagfound
NoMatchRomBlock
        ld ixl,e
        ld ixh,d
        jr nextromblockloop

ROMTagFound
        ld a,(ix+2)                 ; Création de notre ROM tag
        GETPTR_HL romtag
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),a
        inc hl
        ld (hl),0
        dec hl
        dec hl
        dec hl
        ex de,hl

        call _kl_curr_selection      ; Chaînage de notre ROM tag
        ld (ix+0),e
        ld (ix+1),d
        ld (ix+2),a

        call checkreboot
        ld de,msg_init_integrated
        call c,displayinitmsg        ; Affichage de l'invite uniquement au premier démarrage

; On ne se déclare pas au système

SkipInit
        pop de
        pop hl
        pop iy
        pop ix

        xor a ; NC
        ret

; Installation indépendante

StandaloneInstall
        call checkdisabletag        ; On interrompt l'init ici si le tag de désactivation est installé
        jr nz,skipinit              ; (dans ce cas, il n'y aura même pas l'Amsdos mais bon...)

        pop de
        pop hl

; Réservation de l'espace mémoire de travail

        ld bc,-datasize
        add hl,bc

; Installation de l'espace mémoire

        push hl
        push de

        inc hl
        push hl:pop iy
        ld (_dos_rom_base_address),iy

        PUT_8 amsdosrom,0
        call configuredataspace

        call checkreboot
        ld de,msg_init_standalone
        call c,displayinitmsg        ; Affichage de l'invite uniquement au premier démarrage

        pop de
        pop hl
        pop iy
        pop ix

        scf
        ret

;
; Affiche le message d'invite de l'UniDOS
;
; Entrée - DE = pointeur vers msg_init_integrated ou msg_init_standalone
; Sortie - N/A
; Altéré - AF,DE,HL

DisplayInitMsg
        ld hl,msg_init_unidos
        call printstring
        ex de,hl
        call printstring
        ld a,164 ; £Symbole © affiché isolément à cause de son bit 7 à 1 !
        call _txt_output
        ld hl,msg_init_copyright
        jp printstring

;
; Message d'avertissement qu'UniDOS fonctionne en mode dégradé
;
; Entrée - Aucune
; Sortie - Aucune
; Altéré - AF,BC,HL

WarnEmulatedNVRAM
        ld hl,msg_init_missing_nvram
        jp printstring

;
; Configure l'espace de données de la ROM
;
; Entrée - IY = Adresse de la zone mémoire de la ROM
; Sortie - Aucune
; Altéré - AF,BC,DE,HL

ConfigureDataSpace
        call initdata

        call installindirections

        call device_initalldosnodes
        call nc,warnemulatednvram

        call savetapejumpblock

        call checkqualifiers        ; Suppression de la persistance si CTRL+SHIFT sont appuyés
        call z,deleteconfig

        ld c,sc_currentlogicaldrive_f+sc_currentpath_f
        jp loadconfig               ; On se synchronize sur les dernières indirections sauvées

;
; Initialise l'espace mémoire de travail
;
; Entrée - IY = Adresse de la zone mémoire de la ROM
; Sortie - N/A
; Altéré - AF,HL

InitData
        ld a,&ff
        PUT_A fileindrive
        PUT_A fileoutdrive
        PUT_A examinedirdrive

        ld a,&10
        ld (dsk_retry_count),a

        xor a
        PUT_A currentlogicaldrive
        PUT_A currentuser

        PUT_8 cachedlogicaldrive,-1
        PUT_8 currentphysicaldrive,defaultphysicaldrive_a
        PUT_A currentpath

        PUT_A optionflags

        PUT_A dosnoderom
        PUT_A nvramid
        PUT_A rtcid

        ld (dsk_message_status),a

        call getdosnodesinitstatushl
        ld (hl),a:inc hl
        ld (hl),a:inc hl
        ld (hl),a:inc hl
        ld (hl),a

        ret

;
; Installation du vecteur KL OLD FIND COMMAND à partir du vecteur orginel KL FIND COMMAND
;
; Entrée - Aucune
; Sortie - N/A
; Altéré - AF,BC,DE,HL

InstallOldFindCommand
        ld hl,_kl_find_command
        ld a,(hl)
        cp &cf ; RST &08
        ret nz
        ld de,_kl_old_find_command
        ldi:ldi:ldi
        ret

;
; Installation des indirections
;
; Entrée - IY = Adresse de la zone mémoire de la ROM
; Sortie - N/A
; Altéré - AF,BC,DE,HL

InstallIndirections

        ; Indirection "KL FIND COMMAND" améliorée

        GETPTR_HL findcommandfaraddress
        call _kl_curr_selection
        ld de,findcommand_vectordispatcher
        call setfarcall
        ld hl,_kl_find_command
        call setindirection

        ; Indirections CAS

        ld hl,_dos_rom_hook_address     ; Poke d'un RET à l'adresse d'invocation
        ld (hl),&c9                     ; des indirections

        call saveamsdosfarcall

ResetIndirections
        GETPTR_HL faraddress            ; HL = Adresse des données de l'indirection
        call _kl_curr_selection         ; A  = ROM de la routine d'indirection
        ld de,cas_vectordispatcher      ; DE = Adresse de la routine d'indirection
        call setfarcall                 ; Mise en place des données "far address"

        ld hl,_cas_in_open              ; HL = Première indirection
        ld a,13                         ; A  = Nombre d'indirections
LoopInstallRedirection
        call setindirection
        dec a
        jr nz,loopinstallredirection
        ret

SetFarCall
        ld b,h
        ld c,l                          ; BC = Adresse des données de l'indirection
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        ld (hl),a
        ret
SetIndirection
        ld (hl),&df
        inc hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ret

;
; Vérifie la somme de contrôle de la ROM
;
; Entrée - Aucune
; Sortie - Si Z alors la somme est valide
;          Si NZ alors la somme est invalide
; Altéré - AF,BC,HL

CheckSum
        ld hl,&c000
        ld bc,&ff00
CheckSumLoop
        ld a,c
        add (hl)
        ld c,a
        inc hl
        ld a,l
        and h
        cp b
        jr nz,checksumloop
        ld a,c
        cp (hl)
        ret

;
; Sauve les données "farcall" des indirections AMSDOS si elles ont été mises en place
;
; Entrée - IY = Adresse de la zone mémoire de la ROM
; Sortie - N/A
; Altéré - AF,BC,DE,HL

SaveAmsdosFarCall
        call GetAmsdosROM_RegA
        or a
        ret z

        GETPTR_HL faraddress+2
        cp (hl)
        ret nz

        dec hl
        GETPTR_DE amsdosfaraddress+1
        ldd:ldd
        ret

;
; Sauve les indirections de gestion cassette si elle n'ont pas été déjà prises en charge
;
; Entrée - IY = Adresse de la zone mémoire de la ROM
; Sortie - N/A
; Altéré - AF,BC,DE,HL

SaveTapeJumpBlock
        call GetAmsdosROM_RegA
        or a
        ret nz

        GETPTR_DE tapejumpblocksaved
        ld hl,_cas_in_open              ; HL = Première indirection
        ld bc,13*3
        ldir
        ret

; Vérifie l'état d'activation d'UniDOS lors d'un démarrage à chaud

CheckDisableTag
        call ReadDisableROMTag
        and disablerom_unidos_f
        ret

; Désactivation du menu de choix BASIC ou JEU sur CPC+

Firm_PlusMenu
        ld hl,0
        rst &28:dw &0077    ; rst 5,&0077
        ret

; Redirige l'appel "far fall" vers le bon vecteur et corrige l'adresse de retour

FindCommand_VectorDispatcher
        di
        ex af,af'
        exx
        ld a,c
        pop de
        pop bc
        pop hl
        ex (sp),hl
        push bc
        push de
        ld c,a
        ld b,&7f
        ld hl,findcommand
        push hl
        exx
        ex af,af'
        ei
        ret

; Redirige l'appel "far fall" vers le bon vecteur et corrige l'adresse de retour

CAS_VectorDispatcher
        ; Attention ici, on peut être invoqué alors que les ROMs ne sont
        ; pas initialisées (notamment suite à un "RUN" du firmware),
        ; il faut récupérer à la main l'adresse de notre IY...
        ; L'Amsdos va le récupérer à une adresse statique, on fait pareil !
        ld iy,(_dos_rom_base_address)

        di
        ex af,af'
        exx
        ld a,c
        pop de
        pop bc
        pop hl
        ex (sp),hl
        push bc
        push de
        ld c,a
        ld b,&7f
        ld de,cas_jumptable-_cas_in_open-3
        add hl,de
        push hl
        exx
        ex af,af'
        ei
        jp _dos_rom_hook_address

CAS_JumpTable
        jp cas_inopen
        jp cas_inclose
        jp cas_inabandon
        jp cas_inchar
        jp cas_indirect
        jp cas_return
        jp cas_testeof
        jp cas_outopen
        jp cas_outclose
        jp cas_outabandon
        jp cas_outchar
        jp cas_outdirect
        jp cas_catalog

        Read"BIOS.a"
        Read"RSX.a"
        Read"CAS_InVectors.a"
        Read"CAS_OutVectors.a"
        Read"CAS_Catalog.a"
        Read"CAS_Misc.a"
        Read"Messages.a"
        Read"Display.a"
        Read"Compute.a"
        Read"Misc.a"
        Read"DirScan.a"
        Read"DOSNodes.a"
        Read"ConfigFile.a"
        Read"DataAccess.a"
        Read"AlienDOS.a"
        Read"FileCopy.a"
        Read"EmulatedNVRAM.a"

CodeEnd

; Somme de contrôle

        Org &ffff
        Limit $+1

        SumMem codestart,$

;Breakpoint OutCloseOurs
;Breakpoint OutCloseDoFlush

Equ_FileInMode       Equ DataMap.FileInMode
Equ_FileInBufferBase Equ DataMap.FileInBufferBase
Equ_FileInBufferCur  Equ DataMap.FileInBufferCur
Equ_FileInHead       Equ DataMap.FileInHead


Equ_User Equ DataMap.FileInHead.User
Equ_Name Equ DataMap.FileInHead.Name
Equ_Ext Equ DataMap.FileInHead.Ext

Equ_Type Equ DataMap.FileInHead.Type
Equ_BufferLeft Equ DataMap.FileInHead.BufferLeft
Equ_LoadAdr Equ DataMap.FileInHead.LoadAdr

Equ_Length Equ DataMap.FileInHead.Length
Equ_Entry Equ DataMap.FileInHead.Entry

Equ_Length24b Equ DataMap.FileInHead.Length24b
Equ_CSH Equ DataMap.FileInHead.CSH

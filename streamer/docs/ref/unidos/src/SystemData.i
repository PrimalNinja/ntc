;
; Références système
;

;
; Types de fichiers
;

DSK_FILE_TYPE_PROTECTED_FLAG    Equ 1
DSK_FILE_TYPE_VERSION0_FLAG     Equ (0<<4)
DSK_FILE_TYPE_VERSION1_FLAG     Equ (1<<4)

DSK_FILE_TYPE_BASIC             Equ &0+dsk_file_type_version0_flag
DSK_FILE_TYPE_BASIC_PROTECTED   Equ &0+dsk_file_type_version0_flag+dsk_file_type_protected_flag
DSK_FILE_TYPE_BINARY            Equ &2+dsk_file_type_version0_flag
DSK_FILE_TYPE_BINARY_PROTECTED  Equ &2+dsk_file_type_version0_flag+dsk_file_type_protected_flag
DSK_FILE_TYPE_SCREEN_IMAGE      Equ &4+dsk_file_type_version0_flag
DSK_FILE_TYPE_ASCII             Equ &6+dsk_file_type_version1_flag
DSK_FILE_TYPE_SYMBOLIC_LINK     Equ &8+dsk_file_type_version0_flag  ; Nouveau type spécifique UniDOS
DSK_FILE_TYPE_PROTEXT_DOCUMENT  Equ &a+dsk_file_type_version0_flag

;
; Modes d'accès aux fichiers
;

DSK_FILE_MODE_PENDING   Equ &00
DSK_FILE_MODE_CHAR      Equ &01
DSK_FILE_MODE_DIRECT    Equ &02
DSK_FILE_MODE_STREAM    Equ &03 ; Nouveau mode spécifique UniDOS

;
; Données de gestion disque
;

DSK_RETRY_COUNT     Equ &be66   ; Tentatives en lecture/écriture disque (&10 par défaut)
DSK_MESSAGE_STATUS  Equ &be78   ; État d'activation des messages Amsdos (&00 = on, sinon off)

;
; Codes d'erreur disque
;

DSK_ERR_USER_HAS_HIT_ESCAPE             Equ &00
DSK_ERR_BAD_CHANNEL_STATE               Equ &0e
DSK_ERR_HARD_END_OF_FILE                Equ &0f
DSK_ERR_BAD_COMMAND                     Equ &10
DSK_ERR_FILE_ALREADY_EXISTS             Equ &11
DSK_ERR_FILE_NOT_FOUND                  Equ &12
DSK_ERR_DIRECTORY_FULL                  Equ &13
DSK_ERR_DISC_FULL                       Equ &14
DSK_ERR_DISC_CHANGED                    Equ &15
DSK_ERR_FILE_IS_READ_ONLY               Equ &16
DSK_ERR_DIRECTORY_FOUND                 Equ &17 ; Nouveau code spécifique UniDOS
DSK_ERR_FILE_IS_NOT_A_LINK              Equ &18 ; Nouveau code spécifique UniDOS
DSK_ERR_UNSUPPORTED_DRIVE               Equ &19 ; Nouveau code spécifique UniDOS
DSK_ERR_SOFT_END_OF_FILE                Equ &1a
DSK_ERR_NOT_A_DIRECTORY                 Equ &1b ; Nouveau code spécifique UniDOS
DSK_ERR_RENAME_ACROSS_MEDIAS            Equ &1c ; Nouveau code spécifique UniDOS
DSK_ERR_RENAME_ACROSS_DIRECTORIES       Equ &1d ; Nouveau code spécifique UniDOS
DSK_ERR_CLOCK_NOT_FOUND                 Equ &1e ; Nouveau code spécifique UniDOS
DSK_ERR_CLOCK_IS_READ_ONLY              Equ &1f ; Nouveau code spécifique UniDOS
; Erreurs bas niveau (provoquent une requête DOS)
DSK_ERR_NO_MEDIA                        Equ &48
DSK_ERR_NO_DATA                         Equ &44
DSK_ERR_WRITE_PROTECTED_MEDIA           Equ &42

DSK_ERR_QUIET_FLAG                      Equ (1<<7)
DSK_ERR_FDC_FLAG                        Equ (1<<6)

DSK_ERR_QUIET_USER_HAS_HIT_ESCAPE       Equ dsk_err_quiet_flag+dsk_err_user_has_hit_escape
DSK_ERR_QUIET_BAD_CHANNEL_STATE         Equ dsk_err_quiet_flag+dsk_err_bad_channel_state
DSK_ERR_QUIET_HARD_END_OF_FILE          Equ dsk_err_quiet_flag+dsk_err_hard_end_of_file
DSK_ERR_QUIET_BAD_COMMAND               Equ dsk_err_quiet_flag+dsk_err_bad_command
DSK_ERR_QUIET_FILE_ALREADY_EXISTS       Equ dsk_err_quiet_flag+dsk_err_file_already_exists
DSK_ERR_QUIET_FILE_NOT_FOUND            Equ dsk_err_quiet_flag+dsk_err_file_not_found
DSK_ERR_QUIET_DIRECTORY_FULL            Equ dsk_err_quiet_flag+dsk_err_directory_full
DSK_ERR_QUIET_DISC_FULL                 Equ dsk_err_quiet_flag+dsk_err_disc_full
DSK_ERR_QUIET_DISC_CHANGED              Equ dsk_err_quiet_flag+dsk_err_disc_changed
DSK_ERR_QUIET_FILE_IS_READ_ONLY         Equ dsk_err_quiet_flag+dsk_err_file_is_read_only
DSK_ERR_QUIET_DIRECTORY_FOUND           Equ dsk_err_quiet_flag+dsk_err_directory_found
DSK_ERR_QUIET_FILE_IS_NOT_A_LINK        Equ dsk_err_quiet_flag+dsk_err_file_is_not_a_link
DSK_ERR_QUIET_UNSUPPORTED_DRIVE         Equ dsk_err_quiet_flag+dsk_err_unsupported_drive
DSK_ERR_QUIET_SOFT_END_OF_FILE          Equ dsk_err_quiet_flag+dsk_err_soft_end_of_file
DSK_ERR_QUIET_NOT_A_DIRECTORY           Equ dsk_err_quiet_flag+dsk_err_not_a_directory
DSK_ERR_QUIET_RENAME_ACROSS_MEDIAS      Equ dsk_err_quiet_flag+dsk_err_rename_across_medias
DSK_ERR_QUIET_RENAME_ACROSS_DIRECTORIES Equ dsk_err_quiet_flag+dsk_err_rename_across_directories
DSK_ERR_QUIET_CLOCK_NOT_FOUND           Equ dsk_err_quiet_flag+dsk_err_clock_not_found
DSK_ERR_QUIET_CLOCK_IS_READ_ONLY        Equ dsk_err_quiet_flag+dsk_err_clock_is_read_only
; Erreurs bas niveau (provoquent une requête DOS)
DSK_ERR_QUIET_NO_MEDIA                  Equ dsk_err_quiet_flag+dsk_err_no_media
DSK_ERR_QUIET_NO_DATA                   Equ dsk_err_quiet_flag+dsk_err_no_data
DSK_ERR_QUIET_WRITE_PROTECTED_MEDIA     Equ dsk_err_quiet_flag+dsk_err_write_protected_media

;
; Commandes pour le vecteur BIOS CRTL-J de l'UniDOS
;

CMD_CAT_FAKED_PARENT        Equ 0
CMD_DEVICE_LIST             Equ 1
CMD_DEVICE_INFO             Equ 2
CMD_DISABLED_LINK           Equ 3
CMD_EMULATE_SOFT_EOF        Equ 4   ; Obsolète depuis UniDOS 1.38 (toujours activé)
CMD_CAS_IN_READ             Equ 5
CMD_CAS_IN_SEEK             Equ 6
CMD_CAS_OUT_WRITE           Equ 7
CMD_CAS_OUT_SEEK            Equ 8
CMD_DISABLED_DIRECTORY      Equ 9
CMD_ENABLED_SORT_DIR_FIRST  Equ 10
CMD_IS_ACTIVE_DOSNODE       Equ 11
CMD_EXAMINE                 Equ 12
CMD_EXAMINE_NEXT            Equ 13

;
; Flags pour les API des noeuds DOS
;

; Init bits
Init_ColdBoot_B     Equ 0   ; Flag d'entrée  : l'initialisation du noeud DOS a lieu dans le cadre d'un démarrage à froid
Init_HaveNVRAM_B    Equ 5   ; Flag de sortie : une mémoire non volatile mise à disposition par le noeud DOS
Init_HaveRTC_B      Equ 7   ; Flag de sortie : une horloge temps réel est mise à disposition par le noeud DOS
; Init flags
Init_ColdBoot_F     Equ 1 << init_coldboot_b
Init_HaveNVRAM_F    Equ 1 << init_havenvram_b
Init_HaveRTC_F      Equ 1 << init_havertc_b

; Media bits
Media_Available_B   Equ 0
Media_HandleDir_B   Equ 1
Media_ReadOnly_B    Equ 2
Media_Removable_B   Equ 3
Media_StreamOnly_B  Equ 4
Media_NewAPI_B      Equ 5
Media_Formatable_B  Equ 6
; Media flags
Media_Available_F   Equ 1 << media_available_b
Media_HandleDir_F   Equ 1 << media_handledir_b
Media_ReadOnly_F    Equ 1 << media_readonly_b
Media_Removable_F   Equ 1 << media_removable_b
Media_StreamOnly_F  Equ 1 << media_streamonly_b
Media_NewAPI_F      Equ 1 << media_newapi_b
Media_Formatable_F  Equ 1 << media_formatable_b

;
; Header AMSDOS
;

Struct FileHead

    User        ds 1
    Name        ds 8
    Ext         ds 3
                ds 6
    Type        ds 1    ; Voir DSK_FILE_TYPE_*
    BufferLeft  ds 2    ; Nombre d'octets écrits/lus dans le tampon de travail (donnée temporaire)
    LoadAdr     ds 2    ; Adresse de chargement (ou adresse du tampon pour un fichier ASCII)
                ds 1
    Length      ds 2    ; Longueur du fichier (&0000 pour un fichier ASCII)
    Entry       ds 2    ; Adresse d'exécution
                ds 36
    Length24b   ds 3    ; Longueur du fichier sur 24 bits
    CSH         ds 2    ; Check Sum of Header

EndStruct

FileHeadSize Equ {sizeof}FileHead

;
; Liens symboliques
;

MaxLinkSize   Equ 51

;
; Chemins
;

DirMaxDepth   Equ 6
DirBufferSize Equ 1+DirMaxDepth*(8+3)

;
; Marqueur de désactivation de ROMs au démarrage
;

DisableROMTagAdr        Equ &baf7

; Disable bits
DisableROM_UniDOS_B     Equ 7   ; UniDOS ne doit pas être initialisé au boot
DisableROM_DevTools_B   Equ 6   ; Les outils de développement ne doivent pas être initialisés au boot
; Init flags
DisableROM_UniDOS_F     Equ 1 << disablerom_unidos_b
DisableROM_DevTools_F   Equ 1 << disablerom_devtools_b

MagicNumber             Equ &feca

Struct DisableROMTag

    MagicNumber ds 2    ; Les flags sont inactif si MagicNumber ne vaut pas DisableTagMagicNumber
    Flags       ds 1    ; Chaque bit mis à un désactive un type de ROM au démarrage

EndStruct


;
; Données diverses
;

; Basic

    if firmware > 1
_BAS_MEMORY                 Equ &ae5e   ; Valeur de la mémoire haute (664/6128 seulement)
    else
_BAS_MEMORY                 Equ &ae7b   ; Valeur de la mémoire haute (464 seulement)
    endif

; Carte mémoire de l'interface cassette

    if firmware > 1
_KL_CAS_FILE_IN             Equ &b11a
_KL_CAS_FILE_IN_HEADER      Equ &b11f
_KL_CAS_FILE_OUT            Equ &b15f
_KL_CAS_FILE_OUT_HEADER     Equ &b164
    else
_KL_CAS_FILE_IN             Equ &b802
_KL_CAS_FILE_IN_HEADER      Equ &b807
_KL_CAS_FILE_OUT            Equ &b847
_KL_CAS_FILE_OUT_HEADER     Equ &b84c
    endif

; Carte mémoire du kernel

    if firmware > 1
_KL_ROM_BASE_ADDRESS_TABLE  Equ &b8da
_KL_ROM_BLOCK_CHAIN         Equ &b8d3
_KL_ROM_UPPER_SELECT_NUMBER Equ &b8d6
_KL_TIME                    Equ &b8b4
_KL_TEMP_RSX                Equ &b8c3
    else
_KL_ROM_BASE_ADDRESS_TABLE  Equ &b1ac
_KL_ROM_BLOCK_CHAIN         Equ &b1a6
_KL_ROM_UPPER_SELECT_NUMBER Equ &b1a9
_KL_TIME                    Equ &b187
_KL_TEMP_RSX                Equ &b196
    endif

_KL_ROM_INITIAL_HIMEM       Equ &abff

; Carte mémoire du DOS

    if firmware > 1
_DOS_ROM_TEMP_ROUTINE       Equ &b13b   ; Espace temporaire utilisé pour l'appel de routines externes (&24 octets) - Peut être utilisé par les noeuds DOS
                                        ;   Utilisé en interne pour la gestion des appels vers les autres ROMs
_DOS_ROM_TEMP_STORE         Equ &b180   ; Espace temporaire de stockage de données (&64 octets)                    - Peut être utilisé par les noeuds DOS
                                        ;   Utilisé en interne pour l'indirection de modification de la sortie Amsdos
_DOS_ROM_TEMP_NVRAM         Equ &b8fa   ; Espace temportaire utilisé lors de la gestion de la NVRAM (&6 octets)    - Réservé à l'usage exclusif d'UniDOS
    else
_DOS_ROM_TEMP_ROUTINE       Equ &b823   ; Espace temporaire utilisé pour l'appel de routines externes (&24 octets) - Peut être utilisé par les noeuds DOS
                                        ;   Utilisé en interne pour la gestion des appels vers les autres ROMs
_DOS_ROM_TEMP_STORE         Equ &b868   ; Espace temporaire de stockage de données (&64 octets)                    - Peut être utilisé par les noeuds DOS
                                        ;   Utilisé en interne pour l'indirection de modification de la sortie Amsdos
_DOS_ROM_TEMP_NVRAM         Equ &b1ba   ; Espace temportaire utilisé lors de la gestion de la NVRAM (&6 octets)    - Réservé à l'usage exclusif d'UniDOS
    endif

_DOS_ROM_BASE_ADDRESS       Equ &be7d   ; Adresse où est stockée l'adresse de la zone de travail de l'Amsdos
_DOS_ROM_HOOK_ADDRESS       Equ &be7f   ; Adresse appelée à l'invocation des indirections CAS_x (contient RET par défaut)

_DOS_ROM_ALT_BUFFER         Equ &be80   ; Adresse du tampon de travail secondaire - (&80 octets)                   - Peut être utilisé par les noeuds DOS (en dehors des routines in/out uniquement)
                                        ;   Utilisé en interne pour la gestion des liens et la copie de fichiers
                                        ;   À utiliser exceptionnellement car ça peut poser des problèmes de compatibilité


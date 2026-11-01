;
; Organisation des données de travail du noeud DOS de l'Albireo
;

;
; Identifiants des lecteurs de notre noeuds DOS (8 au maximum, de 0 à 7)
;

DriveBit_2ndBoard   Equ 2

Drive_SD1           Equ &0
Drive_UMS1          Equ &1
Drive_SD2           Equ &0 + (1 << drivebit_2ndboard)
Drive_UMS2          Equ &1 + (1 << drivebit_2ndboard)

;
; Ports d'accès aux Albireo
;

AlbireoCmdPortA     Equ &fe81
AlbireoDataPortA    Equ &fe80
AlbireoCmdPortB     Equ &fe41
AlbireoDataPortB    Equ &fe40

;
; Adresses de stockage temporaire
;

CurrentDrive        Equ _dos_rom_temp_store             ; 1 byte
CurrentLowLevel     Equ _dos_rom_temp_store+1           ; 2 bytes
CurrentCmdPort      Equ _dos_rom_temp_store+1+2         ; 2 bytes
CurrentDataPort     Equ _dos_rom_temp_store+1+2+2       ; 2 bytes
ClusterInfo1        Equ _dos_rom_temp_store+1+2+2+2     ; 21 bytes
ClusterInfo2        Equ _dos_rom_temp_store+1+2+2+2+21  ; 21 bytes

;
; Structures de données pour FileInHandler, FileOutHandler et ExamineDirHandler
;

Struct FileIn

    Path    ds dirbuffersize    ; Répertoire du fichier en lecture
    Offset  ds 4                ; Position globale dans le fichier qui correspond au tampon en cours

EndStruct

Struct FileOut

    Path    ds dirbuffersize    ; Répertoire du fichier en écriture
    Offset  ds 4                ; Position globale dans le fichier qui correspond au tampon en cours

EndStruct

Struct ExamineDir

    Path    ds dirbuffersize    ; Répertoire du Examine sur un répertoire en cours
    Pos     ds 2                ; Position dans le examine sur un répertoire en cours

EndStruct

Struct NVRAMData

    Dummy   ds 1                ; Le noeud Albireo n'a pas besoin de données de gestion pour sa mémoire non volatile

EndStruct

;
; Données privée du noeud
;

; Valeurs possibles pour LowLevelFile (donnée privée 0 - bits 0-3)
LLF_KindUnknown         Equ 0
LLF_KindInStream        Equ 1
LLF_KindOutStream       Equ 2
LLF_KindExamineDir      Equ 3
LLF_KindNone            Equ 15

; Valeurs possibles pour LowLevelMount (donnée privée 0 - bits 4-7)
LLM_MicroSD         Equ  3
LLM_USBHost         Equ  6
LLM_None            Equ 15

;
; Carte mémoire de l'UniDOS (basée à l'adresse stockée en  _DOS_ROM_BASE_ADDRESS)
;

Struct DOSMap

    CurrentLogicalDrive     ds 1                ; Lecteur logique courant (0=A, 1=B)
    CurrentUser             ds 1                ; User courant

    Reserved1               ds 6                ; Ne pas toucher !

    FileInOpened            ds 1                ; &FF si le fichier d'entrée est fermé, lecteur sur lequel il est ouvert sinon
                            ds 1
    FileInName              ds 8                ; Nom du fichier d'entrée
    FileInExt               ds 3                ; Extension du fichier d'entrée

    Reserved2               ds 23               ; Ne pas toucher !

    FileOutOpened           ds 1                ; &FF si le fichier de sortie est ferme, lecteur sur lequel il est ouvert sinon
                            ds 1
    FileOutName             ds 8                ; Nom du fichier de sortie
    FileOutExt              ds 3                ; Extension du fichier de sortie

    Reserved3               ds 23               ; Ne pas toucher !

    FileInMode              ds 1                ; Voir DSK_FILE_MODE_*
    FileInBufferBase        ds 2                ; Adresse de base du tampon de 2K pour la lecture octet par octet
    FileInBufferCur         ds 2                ; Adresse courante du tampon

    struct FileHead         FileInHead          ; Zone de header du fichier d'entrée

    FileOutMode             ds 1                ; Voir DSK_FILE_MODE_*
    FileOutBufferBase       ds 2                ; Adresse de base du tampon de 2K pour l'écriture octet par octet
    FileOutBufferCur        ds 2                ; Adresse courante du tampon

    Struct FileHead         FileOutHead         ; Zone de header du fichier de sortie

    RecordBuffer            ds 128              ; Zone de travail où se trouve le header juste après une ouverture de fichier

    Reserved4               ds 42               ; Ne pas toucher

    DOSNodePrivateData      ds 2                ; Données privées réservées à l'usage du noeud en cours d'appel

    Reserved5               ds 416              ; Ne pas toucher !

    struct FileIn           FileInHandler       ; Zone à disposition du noeud DOS pour la gestion du fichier en entrée
                            ds 80-{sizeof}FileIn
    struct FileOut          FileOutHandler      ; Zone à disposition du noeud DOS pour la gestion du fichier en sortie
                            ds 80-{sizeof}FileOut
    struct ExamineDir       ExamineDirHandler   ; Zone à disposition du noeud DOS pour la gestion du parcours des répertoires
                            ds 80-{sizeof}ExamineDir

    ExamineDirDrive         ds 1                ; &FF si aucun Examine sur un répertoire n'est en cours, lecteur sur lequel il est en cours sinon

    Reserved6               ds 205              ; Ne pas toucher !

    struct NVRAMData        NVRAMHandler        ; Zone à disposition du noeud DOS pour la gestion de la mémoire non volatile
                            ds 6-{sizeof}NVRAMData

    Reserved7               ds 12               ; Ne pas toucher !

EndStruct

DOSSize Equ {sizeof}DOSMap


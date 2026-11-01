;
; Organisation des données de travail du noeud DOS de la M4Board
;

LibItemMaxLen   Equ &50 ; Max=&61 (taille disponible dans la zone de stockage temporaire _DOS_ROM_TEMP_STORE)
FTPInfoMaxLen   Equ &61 ; Max=&61 (taille disponible dans la zone de stockage temporaire _DOS_ROM_TEMP_STORE)

; Offsets relatifs à la zone ROM_Response de la M4 ROM
DSKNameOft      Equ &0900
FTPInfoOft      Equ DSKNameOft+LibItemMaxLen+3
M4StoreOft      Equ &0a00

; Clef de validation des sockets lors du Examine
KeySock         Equ &ca

;
; Identifiants des lecteurs de notre noeuds DOS (8 au maximum, de 0 à 7)
;

Drive_M4    Equ &0
Drive_DSK   Equ &1
Drive_FTP   Equ &2

;
; Structures de données pour FileInHandler, FileOutHandler et ExamineDirHandler
;

Struct FileIn

    path    ds DirBufferSize    ; Chemin du fichier
    oft     ds 4                ; Position globale dans le fichier
    len     ds 4                ; Taille du fichier restante (lecteur FTP: uniquement)

EndStruct

Struct FileOut

    path    ds DirBufferSize    ; Chemin du fichier
    oft     ds 4                ; Position globale dans le fichier

EndStruct

Struct ExamineDir

    path    ds DirBufferSize    ; Chemin en cours d'examin (lecteurs M4: et DSK: seulement)
    index   ds 2                ; Dernier index traité (lecteurs M4: et DSK:)
    cmdSock ds 1                ; Socket allouée pour les commandes (lecteur FTP: seulement)
    datSock ds 1                ; Socket allouée pour les données (lecteur FTP: seulement)
    keySock ds 1                ; Clef de validité des sockets (lecteur FTP: seulement)

EndStruct

Struct NVRAMData

    fd      ds 1                ; Descripteur de fichier

EndStruct

;
; Données privée du noeud
;

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

;
; Macros
;

Macro DEHL_x2
        ex de,hl
        add hl,hl
        ex de,hl
        add hl,hl
        jr nc,$+3
        inc de
MEnd

Macro PUSH_DEHL
        push de
        push hl
MEnd

Macro POPADD_DEHL
        pop bc
        add hl,bc
        jr nc,$+3
        inc de
        pop bc
        ex de,hl
        add hl,bc
        ex de,hl
MEnd

Macro ADD_DEHL_BC
        add hl,bc
        jr nc,$+3
        inc de
MEnd

Macro SUB_DEHL_BC
        or a
        sbc hl,bc
        jr nc,$+3
        dec de
MEnd

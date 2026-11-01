;
; Données d'exécution (relatif à IY)
; L'organisation est censée être la plus compatible possible avec l'Amsdos
; Les * indiquent des données spécifiques à l'UniDOS
;

Struct ChunkHead

    ID                      ds 2        ; Identifiant du chunk
    Size                    ds 2        ; Taille des données du chunk (header non compris)

EndStruct

ChunkHeadSize Equ {sizeof}ChunkHead

Struct ChunkHandler

    Pos                     ds 2   ; Position courante du chunk dans le fichier
    struct ChunkHead        Head   ; Données du chunk courant

EndStruct



; Identifiants des lecteurs physiques administrés par UniDOS (sous la forme %00000nnn)
; L'ajout dynamique d'autres lecteurs se fait via les noeuds DOS
; (sous la forme %rrrrrnnn où r est le numéro de la ROM et n du lecteur)
PhysicalDrive_DFA           Equ &00 ; Via l'AMSDOS (&00 = lecteur A)
PhysicalDrive_DFB           Equ &01 ; Via l'AMSDOS (&01 = lecteur B)
PhysicalDrive_TAPE          Equ &07 ; Via le firmware
; Valeurs par défaut pour les lecteurs logiques A et B
DefaultPhysicalDrive_A      Equ physicaldrive_dfa
DefaultPhysicalDrive_B      Equ physicaldrive_dfb


; Pour OptionFlags (réglées via le vecteur BIOS CTRL-J)
; Bits
OPT_CatFakedParent_B        Equ 0
OPT_DisabledLink_B          Equ 1
OPT_DisabledDirectory_B     Equ 2
OPT_EnabledSortDirFirst_B   Equ 3
; Flags
OPT_CatFakedParent_F        Equ 1 << opt_catfakedparent_b
OPT_DisabledLink_F          Equ 1 << opt_disabledlink_b
OPT_DisabledDirectory_F     Equ 1 << opt_disableddirectory_b
OPT_EnabledSortDirFirst_F   Equ 1 << opt_enabledsortdirfirst_b


Struct DataMap

    CurrentLogicalDrive     ds 1                ; Lecteur logique courant (0=A, 1=B) - Pour l'Amsdos lecteur logique = lecteur physique
    CurrentUser             ds 1                ; User courant (mis à 0 à l'init de l'UniDOS mais inutilisé)

                            ds 4                ; Réservé Amsdos
    ReturnAddress           ds 2                ; Adresse de retour en cas d'erreur (Amsdos uniquement, non utilisé par l'UniDOS)

    FileInDrive             ds 1                ; &FF si le fichier d'entrée est fermé, lecteur sur lequel il est ouvert sinon
                            ds 1                ; Réservé Amsdos
    FileInName              ds 8                ; Nom du fichier d'entrée
    FileInExt               ds 3                ; Extension du fichier d'entrée
                            ds 23               ; Réservé Amsdos

    FileOutDrive            ds 1                ; &FF si le fichier de sortie est ferme, lecteur sur lesquel il est ouvert sinon
                            ds 1                ; Réservé Amsdos
    FileOutName             ds 8                ; Nom du fichier de sortie
    FileOutExt              ds 3                ; Extension du fichier de sortie
                            ds 23               ; Réservé Amsdos

    FileInMode              ds 1                ; Voir DSK_FILE_MODE_*
    FileInBufferBase        ds 2                ; Adresse de base du tampon de 2K pour la lecture octet par octet
    FileInBufferCur         ds 2                ; Adresse courante du tampon

    struct FileHead         FileInHead          ; Zone de header du fichier d'entrée

    FileOutMode             ds 1                ; Voir DSK_FILE_MODE_*
    FileOutBufferBase       ds 2                ; Adresse de base du tampon de 2K pour l'écriture octet par octet
    FileOutBufferCur        ds 2                ; Adresse courante du tampon

    Struct FileHead         FileOutHead         ; Zone de header du fichier de sortie

    WorkArea                ds 128              ; Zone de stockage des enregistrements et de formatage des noms de fichier

    TapeJumpBlockSaved      ds 13*3
    FarAddress              ds 3                ; Données du "far address" pour les indirections des vecteurs entrées/sorties

    DOSNodePrivateData      ds 2                ; DOS Nodes: données privées du noeuds DOS en cours d'appel

                            ds 25*2             ; Réservé Amsdos
                            ds 16               ; Réservé Amsdos
                            ds 94               ; Réservé Amsdos

    ; Le buffer pour les enregistrements du répertoire de l'AMSDOS nous est inutile en tant que tel
    ; On y stocke donc nos données de travail volatiles ci-dessous (utilisées uniquement le temps d'une routine de haut niveau CAS ou RSX)

    DirectoryBuffer                             ; Zone de stockage des entrées de répertoire

    WorkDrive               ds 1                ; * Zone de stockage du lecteur physique pendant le traitement
    WorkPath                ds dirbuffersize    ; * Zone de stockage du chemin pendant le traitement
    WorkLogicalDrive        ds 1                ; * Zone de stockage du lecteur logique pendant l'analyse des chemins ('A', 'B' ou &00)

    TempBufferBase          ds 2                ; * Zone de stockage temporaire de l'adresse du tampon d'entrée/sortie

    FileIsDir               ds 1                ; * Variable pour savoir si le nom en entrée est explicitement un répertoire (chemin terminé par /)
    MediaStatus             ds 1                ; * Si &FF le fichier est ouvert sur un media de type flux
    RootReached             ds 1                ; * Flag de tentative de dépassement de la racine d'un disque
    RetryCount              ds 1                ; * Décompte des tentatives automatiques

    FileInDefaultExtCheck   ds 2                ; * Gestion des extensions par defaut (BAS/BIN/...) à l'ouverture d'un fichier
    FileOutExtFound         ds 1                ; * Flag de présence de l'extension dans le fichier à ouvrir
    FileDate                ds 7                ; * Horodatage du fichier ou répertoire en cours de traitement

    DirCount                ds 2                ; * Nombre d'entrées traitées pendant le dernier DirScan ou catalog (poids faible seulement)
    EntryFound              ds 1                ; * &FF si le DirScan a trouvé au moins un fichier au cours de la session
    DirNbrCol               ds 1                ; * Nombre de colonnes affichables pendant un DirScan/Dir
    DirCurCol               ds 1                ; * Numéro de colonne courant pendant un DirScan/Dir
    SetProtection           ds 2                ; * Protections de fichier en cours de réglage pour un DirScan/Hide-Show-Protect-Unprotect
    SetFileDate             ds 7                ; * Horodatage de fichier en cours de régl&ge pour une DirScan/SetFileDate
    EraAskMask              ds 1                ; * Masque du choix utilisateurs à la demande de confirmation pendant un DirScan/Era
    EraSkipCount            ds 2                ; * Nombre d'entrées sautées pendant un DirScan/Era

    DriveName               ds 8                ; * Nom du lecteur pendant la création d'un message DOS

    Unused1                 ds 128-dirbuffersize-43

    ; Le buffer de chargement des secteurs de l'AMSDOS nous est inutile en tant que tel
    ; On y stocke donc également nos données de travail persistantes et semi-persistantes

    ; Les premiers 128 octets du buffer de lecture en provenance de l'AMSDOS sont conservés pour compatibilité

_Start_ReadBuffer
    ReadBuffer              ds 128              ; Début du buffer de lecture (utilisé pour la lecture ASCII, DirScan et Copyfile)

    ; Données semi-persistances liées à la gestion des sessions d'ouvertures de fichiers/répertoires

_Start_WorkData
    ; Zone dédiée à la gestion du flux en entrée (privé au noeud DOS sur lequel le flux est ouvert)
    FileIn                  ds 80
    ; Zone dédiée à la gestion du flux en sortie (privé au noeud DOS sur lequel le flux est ouvert)
    FileOut                 ds 80
    ; Zone dédiée au parcours des répertoires (privé au noeud DOS sur lequel le parcours est en lancé)
    ExamineDir              ds 80
    ; Données privées de l'UniDOS
    ExamineDirDrive         ds 1                ; * &FF si aucun Examine sur un répertoire n'est en cours, lecteur sur lequel il est en cours sinon
    FileIn1stRecordSize     ds 1                ; * Taille effective du premier enregistrement lu pour le décodage de l'entête Amsdos
    FileOutPath             ds dirbuffersize    ; * Répertoire du fichier en sortie

    ; Données persistantes avec l'état courant des chemins et lecteurs physiques associés aux lecteurs logiques

    SavedLogicalDrive       ds 1                ; * Sauvegarde temporaire du lecteur logique courant pendant que l'AMSDOS est actif

    CachedLogicalDrive      ds 1                ; * Lecteur logique pour lequel l'assignation courante est mise en cache
_Start_CurrentPath
    CurrentPhysicalDrive    ds 1                ; * Lecteur physique courant (relatif à CachedLogicalDrive)
    CurrentPath             ds dirbuffersize    ; * Répertoire courant (relatif à CachedLogicalDrive)
_End_CurrentPath

    Unused2                 ds 512-128-3*80-2*dirbuffersize-5-4

    ; Les données de la fin de la zone mémoire de la ROM ne sont jamais touchées par l'AMSDOS,
    ; on peut les utiliser pour y stocker des informations persistantes importantes (jusqu'à 80 octets)
    ; Attention : ParaDOS utilise les 50 premiers octets de cette zone pour sa gestion des lecteurs double face

    DOSNodesPrivateTable    ds 60               ; * DOS Nodes : données privées des 30 noeuds DOS, deux octets par ROM
                                                ;   De 1 à 31 en sautant la ROM UniDOS
_End_WorkData
_End_ReadBuffer

    ; La partie qui suit est disponible tout le temps, y compris lorsque l'AMSDOS est activé

    DOSNodesInitStatus      ds 4                ; * DOS Nodes : flags permettant de déterminer les noeuds correctement initialisés
    NVRAMData               ds 6                ; * DOS Nodes : zone dédiée à la gestion de la mémoire non volatile
                                                ;   (privé au noeud DOS ayant été affectée à la gestion de la mémoire non volatile)
    DOSNodeROM              ds 1                ; * DOS Nodes : numéro de la ROM du noeud DOS en cours d'appel
                                                ;   (si le bit 7 est mis alors la table des données privées est invalide)
    OptionFlags             ds 1                ; * Flags de configuration non persistants, voir OPT_*
    NVRAMId                 ds 1                ; * Init : Id utilisé pour la gestion de la mémoire non volatile (bit 3-7 = numéro de ROM)
    RTCId                   ds 1                ; * Init : ID utilisé pour la gestion de l'horloge temps réel (bit 3-7 = numéro de ROM)
    FindCommandFarAddress   ds 3                ; * Init : données du "far address" à utiliser pour l'indirections du vecteur KL FIND COMMAND
    AmsdosFarAddress        ds 2                ; * Init : données du "far address" à utiliser pour les indirections des vecteurs entrées/sorties de l'AMSDOS
    AmsdosROM               ds 1                ; * Init : ROM sous-jacente à utiliser pour passer la main à l'AMSDOS lorsque l'UniDOS est inactif, 0 si non disponible
    ROMTag                  ds 4                ; * Init : tag de ROM pour le chaînage système manuel

EndStruct

DataSize        Equ {sizeof}DataMap


;
; Macros de récupération des pointeurs vers les données (relatives à IY)
;

Macro GETPTR_HL offset
        push bc
        ld bc,datamap.{offset}
        call getpointerhl
        pop bc
MEnd

Macro GETPTR_DE offset
        push bc
        ld bc,datamap.{offset}
        call getpointerde
        pop bc
MEnd

Macro GETPTR_IX offset
        push bc
        ld bc,datamap.{offset}
        call getpointerix
        pop bc
MEnd

;
; Macros génériques d'accès aux données (relatives à IY)
;
; Note : à ne pas utiliser directement, utiliser plutôt
;        les macros dédiées qui sont déclarées après
;

Macro GET_R8 r8,offset,aux
        if datamap.{offset}>127
        push {aux}
        ld {aux},datamap.{offset}
        call getr8_{r8}
        pop {aux}
        else
        ld {r8},(iy+datamap.{offset})
        endif
MEnd

Macro PUT_R8 offset,r8,aux
        if datamap.{offset}>127
        push {aux}
        ld {aux},datamap.{offset}
        call putr8_{r8}
        pop {aux}
        else
        ld (iy+datamap.{offset}),{r8}
        endif
MEnd

Macro GET_R16 r16h,r16l,offset
        if datamap.{offset}>126
        ld {r16h}{r16l},datamap.{offset}
        call getr16_{r16h}{r16l}
        else
        ld {r16l},(iy+datamap.{offset}+0)
        ld {r16h},(iy+datamap.{offset}+1)
        endif
MEnd

Macro PUT_R16 offset,r16h,r16l,aux
        if datamap.{offset}>126
        push {aux}
        ld {aux},datamap.{offset}
        call putr16_{r16h}{r16l}
        pop {aux}
        else
        ld (iy+datamap.{offset}+0),{r16l}
        ld (iy+datamap.{offset}+1),{r16h}
        endif
MEnd

Macro GET_R24 r24h,r24i,r24l,offset
        if datamap.{offset}>125
        ld {r24i}{r24l},datamap.{offset}
        call getr24_{r24h}{r24i}{r24l}
        else
        ld {r24l},(iy+datamap.{offset}+0)
        ld {r24i},(iy+datamap.{offset}+1)
        ld {r24h},(iy+datamap.{offset}+2)
        endif
MEnd

Macro PUT_R24 offset,r24h,r24i,r24l,aux
        if datamap.{offset}>125
        push {aux}
        ld {aux},datamap.{offset}
        call putr24_{r24h}{r24i}{r24l}
        pop {aux}
        else
        ld (iy+datamap.{offset}+0),{r24l}
        ld (iy+datamap.{offset}+1),{r24i}
        ld (iy+datamap.{offset}+2),{r24h}
        endif
MEnd

Macro GET_R32 r32hh,r32hl,r32lh,r32ll,offset
        if datamap.{offset}>124
        push iy
        push bc
        ld bc,datamap.{offset}
        add iy,bc
        pop bc
        ld {r32ll},(iy+0)
        ld {r32lh},(iy+1)
        ld {r32hl},(iy+2)
        ld {r32hh},(iy+3)
        pop iy
        else
        ld {r32ll},(iy+datamap.{offset}+0)
        ld {r32lh},(iy+datamap.{offset}+1)
        ld {r32hl},(iy+datamap.{offset}+2)
        ld {r32hh},(iy+datamap.{offset}+3)
        endif
MEnd

Macro PUT_R32 offset,r32hh,r32hl,r32lh,r32ll
        if datamap.{offset}>124
        push iy
        push bc
        ld bc,datamap.{offset}
        add iy,bc
        pop bc
        ld (iy+0),{r32ll}
        ld (iy+1),{r32lh}
        ld (iy+2),{r32hl}
        ld (iy+3),{r32hh}
        pop iy
        else
        ld (iy+datamap.{offset}+0),{r32ll}
        ld (iy+datamap.{offset}+1),{r32lh}
        ld (iy+datamap.{offset}+2),{r32hl}
        ld (iy+datamap.{offset}+3),{r32hh}
        endif
MEnd

;
; Macros d'accès aux données par registres (relatives à IY)
;

Macro GET_A offset
        GET_R8 a,{offset},bc
MEnd

Macro GET_B offset
        GET_R8 b,{offset},de
MEnd

Macro GET_C offset
        GET_R8 c,{offset},de
MEnd

Macro GET_D offset
        GET_R8 d,{offset},bc
MEnd

Macro GET_E offset
        GET_R8 e,{offset},bc
MEnd

Macro GET_H offset
        GET_R8 h,{offset},bc
MEnd

Macro GET_L offset
        GET_R8 l,{offset},bc
MEnd

Macro GET_BC offset
        GET_R16 b,c,{offset}
MEnd

Macro GET_DE offset
        GET_R16 d,e,{offset}
MEnd

Macro GET_HL offset
        GET_R16 h,l,{offset}
MEnd

Macro GET_CDE offset
        GET_R24 c,d,e,{offset}
MEnd

Macro GET_BCDE offset
        GET_R32 b,c,d,e,{offset}
MEnd

Macro GET_BCHL offset
        GET_R32 b,c,h,l,{offset}
MEnd

Macro GET_DEHL offset
        GET_R32 d,e,h,l,{offset}
MEnd

Macro PUT_A offset
        PUT_R8 {offset},a,bc
MEnd

Macro PUT_B offset
        PUT_R8 {offset},b,de
MEnd

Macro PUT_C offset
        PUT_R8 {offset},c,de
MEnd

Macro PUT_D offset
        PUT_R8 {offset},d,bc
MEnd

Macro PUT_E offset
        PUT_R8 {offset},e,bc
MEnd

Macro PUT_H offset
        PUT_R8 {offset},h,bc
MEnd

Macro PUT_L offset
        PUT_R8 {offset},l,bc
MEnd

Macro PUT_BC offset
        PUT_R16 {offset},b,c,de
MEnd

Macro PUT_DE offset
        PUT_R16 {offset},d,e,bc
MEnd

Macro PUT_HL offset
        PUT_R16 {offset},h,l,bc
MEnd

Macro PUT_CDE offset
        PUT_R24 {offset},c,d,e,hl
MEnd

Macro PUT_BCDE offset
        PUT_R32 {offset},b,c,d,e
MEnd

Macro PUT_BCHL offset
        PUT_R32 {offset},b,c,h,l
MEnd

Macro PUT_DEHL offset
        PUT_R32 {offset},d,e,h,l
MEnd

;
; Macros de modification par valeur des données (relatives à IY)
;

Macro PUT_8 offset,val
        if datamap.{offset}>127
        push af
        ld a,{val}
        PUT_A {offset}
        pop af
        else
        PUT_R8 {offset},{val},bc
        endif
MEnd

Macro PUT_16 offset,val
        if datamap.{offset}>127
        push de
        ld de,{val}
        PUT_DE {offset}
        pop de
        else
        PUT_R16 {offset},{val} >> 8,{val} and 255,bc
        endif
MEnd

Macro PUT_24 offset,val
        push bc
        push de
        ld c,{val} >> 16
        ld de,{val} and &ffff
        PUT_R24 {offset},c,d,e,hl
        pop de
        pop bc
MEnd

Macro PUT_32 offset,val
        PUT_R32 {offset},(({val} >> 24) and &ff),(({val} >> 16) and &ff),(({val} >> 8) and &ff),({val} and &ff),
MEnd

Macro INC_8 offset
        if datamap.{offset}>127
        push bc
        ld bc,datamap.{offset}
        call inc8
        pop bc
        else
        inc (iy+datamap.{offset})
        endif
MEnd

Macro INC_16 offset
        if datamap.{offset}>126
        push bc
        ld bc,datamap.{offset}
        call inc16
        pop bc
        else
        push bc
        ld c,(iy+datamap.{offset}+0)
        ld b,(iy+datamap.{offset}+1)
        inc bc
        ld (iy+datamap.{offset}+0),c
        ld (iy+datamap.{offset}+1),b
        pop bc
        endif
MEnd

Macro DEC_8 offset
        if datamap.{offset}>127
        push bc
        ld bc,datamap.{offset}
        call dec8
        pop bc
        else
        dec (iy+datamap.{offset})
        endif
MEnd

Macro DEC_16 offset
        if datamap.{offset}>126
        push bc
        ld bc,datamap.{offset}
        call dec16
        pop bc
        else
        push bc
        ld c,(iy+datamap.{offset}+0)
        ld b,(iy+datamap.{offset}+1)
        dec bc
        ld (iy+datamap.{offset}+0),c
        ld (iy+datamap.{offset}+1),b
        pop bc
        endif
MEnd

;
; Macros de comparaison des données (relatives à IY)
;

Macro CP_A offset
        if datamap.{offset}>127
        push iy
        push bc
        ld bc,datamap.{offset}
        add iy,bc
        pop bc
        cp (iy)
        pop iy
        else
        cp (iy+datamap.{offset})
        endif
MEnd


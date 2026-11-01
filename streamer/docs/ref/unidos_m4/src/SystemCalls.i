;
; RAM
;

Macro RAM_LAM
    	rst &20
MEnd

;
; RST
;

Macro LOW_JUMP vector
        rst &08
        dw {vector}
MEnd

Macro FAR_CALL vector
        rst &18
        dw {vector}
MEnd

Macro FAR_PCHL
        call _kl_far_pchl
MEnd

If 0
Macro BRK
        rst &30
MEnd
EndIf

;
; Kernel
;

_KL_FAR_PCHL            Equ &001b
_KL_FAR_CALL            Equ &0023
_KL_U_ROM_ENABLE        Equ &b900
_KL_U_ROM_DISABLE       Equ &b903
_KL_L_ROM_ENABLE        Equ &b906
_KL_L_ROM_DISABLE       Equ &b909
_KL_ROM_RESTORE         Equ &b90c
_KL_ROM_SELECT          Equ &b90f
_KL_CURR_SELECTION      Equ &b912
_KL_PROBE_ROM           Equ &b915
_KL_LDIR                Equ &b91b
_KL_LDDR                Equ &b91e
_KL_SCAN_NEEDED         Equ &b92a
_KL_INIT_BACK           Equ &bcce
_KL_FIND_COMMAND        Equ &bcd4

;
; Key manager
;

_KM_INITIALISE          Equ &bb00
_KM_WAIT_CHAR           Equ &bb06
_KM_READ_CHAR           Equ &bb09
_KM_CHAR_RETURN         Equ &bb0c
_KM_WAIT_KEY            Equ &bb18
_KM_READ_KEY            Equ &bb1b
_KM_TEST_KEY            Equ &bb1e
_KM_GET_JOYSTICK        Equ &bb24
_KM_FLUSH               Equ &bd3d
_KM_TEST_BREAK          Equ &bdee
_KM_SCAN_KEYS           Equ &bdf4

;
; Text VDU
;

_TXT_INITIALISE         Equ &bb4e
_TXT_RESET              Equ &bb51
_TXT_VDU_ENABLE         Equ &bb54
_TXT_VDU_DISABLE        Equ &bb57
_TXT_OUTPUT             Equ &bb5a
_TXT_RD_CHAR            Equ &bb60
_TXT_GET_WINDOW         Equ &bb69
_TXT_SET_COLUMN         Equ &bb6f
_TXT_SET_CURSOR         Equ &bb75
_TXT_GET_CURSOR         Equ &bb78
_TXT_CUR_ON             Equ &bb81
_TXT_CUR_OFF            Equ &bb84
_TXT_VALIDATE           Equ &bb87
_TXT_SET_PEN            Equ &bb90
_TXT_GET_PEN            Equ &bb93
_TXT_SET_PAPER          Equ &bb96
_TXT_CLEAR_WINDOW       Equ &bb6c
_TXT_ASK_STATE          Equ &bd40

;
; Screen pack
;

_SCR_RESET              Equ &bc02
_SCR_SET_MODE           Equ &bc0e
_SCR_GET_MODE           Equ &bc11
_SCR_CLEAR              Equ &bc14
_SCR_CHAR_POSITION      Equ &bc1a
_SCR_SET_INK            Equ &bc32
_SCR_SET_BORDER         Equ &bc38

;
; Cassette
;

_CAS_IN_OPEN            Equ &bc77
_CAS_IN_CLOSE           Equ &bc7a
_CAS_IN_ABANDON         Equ &bc7d
_CAS_IN_CHAR            Equ &bc80
_CAS_IN_DIRECT          Equ &bc83
_CAS_RETURN             Equ &bc86
_CAS_TEST_EOF           Equ &bc89
_CAS_OUT_OPEN           Equ &bc8c
_CAS_OUT_CLOSE          Equ &bc8f
_CAS_OUT_ABANDON        Equ &bc92
_CAS_OUT_CHAR           Equ &bc95
_CAS_OUT_DIRECT         Equ &bc98
_CAS_CATALOG            Equ &bc9b

;
; Machine pack
;

_MC_WAIT_FLYBACK        Equ &bd19

;
; Sound manager
;

_SOUND_RESET            Equ &bca7
_SOUND_QUEUE            Equ &bcaa
_SOUND_AMPL_ENVELOPE    Equ &bcbc

;
; Routines annexes
;

    if firmware > 1
_TEXT_INPUT             Equ &bd5e
    endif

;
; Routines internes de la ROM Basic (FAR CALL)
;

    if firmware > 1
_BAS_CAT                Equ &d297       ; Routine du CAT (664/6128 seulement)
_BAS_SETMEMORY          Equ &f56e       ; Routine de configuration de la mémoire haute (664/6128 seulement)
_BAS_FREEBUFFER         Equ &f763       ; Routine de libération du tampon de lecture ou d'écriture du Basic (664/6128 seulement)
    endif

;
; Routines additionnelles (installées par UniDOS)
;

_KL_OLD_FIND_COMMAND    Equ &bdc1       ; Routine _KL_FIND_COMMAND originelle (ne cherche les RSX dans les noeuds DOS de type "extension")

;
; Noeuds DOS (UniDOS)
;

_DOSNODE_INIT                       Equ &c009
_DOSNODE_CHECK_DRIVE                Equ  1*3+_dosnode_init
_DOSNODE_GET_STATUS                 Equ  2*3+_dosnode_init
_DOSNODE_GET_NAME                   Equ  3*3+_dosnode_init
_DOSNODE_GET_DESC                   Equ  4*3+_dosnode_init
_DOSNODE_GET_FREE_SPACE             Equ  5*3+_dosnode_init
_DOSNODE_IN_OPEN_STREAM             Equ  6*3+_dosnode_init
_DOSNODE_IN_READ_STREAM             Equ  7*3+_dosnode_init
_DOSNODE_IN_CLOSE_STREAM            Equ  8*3+_dosnode_init
_DOSNODE_IN_SEEK_STREAM             Equ  9*3+_dosnode_init
_DOSNODE_OUT_OPEN_STREAM            Equ 10*3+_dosnode_init
_DOSNODE_OUT_WRITE_STREAM           Equ 11*3+_dosnode_init
_DOSNODE_OUT_CLOSE_STREAM           Equ 12*3+_dosnode_init
_DOSNODE_OUT_SEEK_STREAM            Equ 13*3+_dosnode_init
_DOSNODE_EXAMINE                    Equ 14*3+_dosnode_init
_DOSNODE_EXAMINE_NEXT               Equ 15*3+_dosnode_init
_DOSNODE_RENAME                     Equ 16*3+_dosnode_init
_DOSNODE_DELETE                     Equ 17*3+_dosnode_init
_DOSNODE_CREATE_DIR                 Equ 18*3+_dosnode_init
_DOSNODE_SET_PROTECTION             Equ 19*3+_dosnode_init
_DOSNODE_FORMAT                     Equ 20*3+_dosnode_init
_DOSNODE_SET_FILE_DATE              Equ 21*3+_dosnode_init
_DOSNODE_RESERVED_1                 Equ 22*3+_dosnode_init
_DOSNODE_RESERVED_2                 Equ 23*3+_dosnode_init
_DOSNODE_RESERVED_3                 Equ 24*3+_dosnode_init
_DOSNODE_READ_RTC                   Equ 25*3+_dosnode_init
_DOSNODE_WRITE_RTC                  Equ 26*3+_dosnode_init
_DOSNODE_OPEN_NVRAM                 Equ 27*3+_dosnode_init
_DOSNODE_CLOSE_NVRAM                Equ 28*3+_dosnode_init
_DOSNODE_READ_NVRAM                 Equ 29*3+_dosnode_init
_DOSNODE_WRITE_NVRAM                Equ 30*3+_dosnode_init
_DOSNODE_SEEK_NVRAM                 Equ 31*3+_dosnode_init


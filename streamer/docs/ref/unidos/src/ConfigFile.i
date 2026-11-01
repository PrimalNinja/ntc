;
; Flags de paramétrage pour la sauvegarde et le chargement du fichier de configuration
;

; Bits
SC_CurrentIndirections_B    Equ 0
SC_CurrentLogicalDrive_B    Equ 1
SC_CurrentPath_B            Equ 2
SC_ReadBuffer_B             Equ 3
SC_WorkData_B               Equ 4

; Flags
SC_CurrentIndirections_F    Equ 1 << sc_currentindirections_b
SC_CurrentLogicalDrive_F    Equ 1 << sc_currentlogicaldrive_b
SC_CurrentPath_F            Equ 1 << sc_currentpath_b
SC_ReadBuffer_F             Equ 1 << sc_readbuffer_b
SC_WorkData_F               Equ 1 << sc_workdata_b


;
; Albireo DOS Node
;
; Gestionnaire du noeud DOS de l'Albireo pour l'UniDOS
; Par OffseT/Futurs' - (c) 2021
;
; Prévu pour être assemblé avec rasm 1.4+
;

firmware=3

        Save"bin/Albireo.rom",&c000,&4000,amsdos

        Read"SystemCalls.i"
        Read"SystemData.i"
        Read"CH376.i"

        Read"DOSMap.i"

        Org &c000
        Limit &ffff

CodeStart       db 2    ; ROM d'extension

                db 1    ; Marque
                db 4    ; Version
                db 1    ; Révision

_RsxTable       dw rsxtable

_InitRom        jp initrom
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

RSXTable        str "ALBIREO "
                str "DOS Node"
Repeat 31
                db &80
REnd
                ; Fin de la table des RSX
                db 0

;
; Initialise la ROM
;

InitROM xor a ; NC
        ret

        Read"LowLevel.a"
        Read"DOSNode.a"
        Read"DataAccess.a"

CodeEnd

;
; Somme de contrôle
;

        Org &ffff
        Limit $+1

        SumMem codestart,$


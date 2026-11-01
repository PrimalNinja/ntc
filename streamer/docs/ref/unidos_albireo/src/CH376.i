;
; Définition des constantes des codes des commandes et des erreurs du CH376
;

CMD_GET_IC_VER          Equ &01        ; Get firmware version
CMD_SET_BAUDRATE        Equ &02        ; serial mode: set serial baud rate(default reset baud rate is 9600bps,determined by D4/D5/D6 pins)
CMD_ENTER_SLEEP         Equ &03        ; Enter sleep mode
CMD_RESET_ALL           Equ &05        ; Execute hardware reset
CMD_CHECK_EXIST         Equ &06        ; Check communication interface and working state
CMD_CHK_SUSPEND         Equ &0b        ; USB device mode: set USB bus suspend state mode
CMD_SET_SDO_INT         Equ &0b        ; USB device mode: set USB bus suspend state mode
CMD_GET_FILE_SIZE       Equ &0c        ; USB host mode: get current file size
CMD_SET_FILE_SIZE       Equ &0d        ; USB host mode: set current file size
CMD_SET_USB_MODE        Equ &15        ; Set USB working mode
CMD_GET_STATUS          Equ &22        ; Get interrupt state and cancel interrupt request
CMD_UNLOCK_USB          Equ &23        ; USB device mode: release current USB buffer
CMD_RD_USB_DATA0        Equ &27        ; Read data block from current USB interrupt point buffer or host's RX buffer
CMD_RD_USB_DATA         Equ &28        ; USB device mode: read data block from current USB interrupt point buffer and release buffer, equal to CMD_RD_USB_DATA0 + CMD_UNLOCK_USB
CMD_WR_USB_DATA7        Equ &2b        ; USB device mode: write data block to USB point 2 TX buffer
CMD_WR_HOST_DATA        Equ &2c        ; Write data block to USB host point TX buffer
CMD_WR_REQ_DATA         Equ &2d        ; Write requested data block to specified internal buffer
CMD_WR_OFS_DATA         Equ &2e        ; Write data block to specified off address in the internal buffer
CMD_SET_FILE_NAME       Equ &2f        ; Host file mode: set file name
CMD_DISK_CONNECT        Equ &30        ; Host file mode(not support SD card): check if disk is connect
CMD_DISK_MOUNT          Equ &31        ; Host file mode: initialize disk and check if disk is ready
CMD_FILE_OPEN           Equ &32        ; Host file mode: open file or directory(folder), or enumerate files and directories(folders)
CMD_FILE_ENUM_GO        Equ &33        ; Host file mode: continue with enumeration
CMD_FILE_CREATE         Equ &34        ; Host file mode: create a new file. The original file will be deleted if it exists
CMD_FILE_ERASE          Equ &35        ; Host file mode: delete file. If the file is open, it will be deleted directly, otherwise the file will be firstly opened then deleted. The sub folder must open first
CMD_FILE_CLOSE          Equ &36        ; Host file mode: close currently opened file or folder
CMD_DIR_INFO_READ       Equ &37        ; Host file mode: read the directory information of the file
CMD_DIR_INFO_SAVE       Equ &38        ; Host file mode: save the directory information of the file
CMD_BYTE_LOCATE         Equ &39        ; Host file mode: move file pointer by byte
CMD_BYTE_READ           Equ &3a        ; Host file mode: read data block form current address by unit of byte
CMD_BYTE_RD_GO          Equ &3b        ; Host file mode: continue with byte reading
CMD_BYTE_WRITE          Equ &3c        ; Host file mode: write data block to current address by unit of byte
CMD_BYTE_WR_GO          Equ &3d        ; Host file mode: continue with byte writing
CMD_DISK_CAPACITY       Equ &3e        ; Host file mode: query physic disk capacity
CMD_DISK_QUERY          Equ &3f        ; Host file mode: query remaining capacity
CMD_DIR_CREATE          Equ &40        ; Host file mode: create directory and open it (ff the directory exists, it will just be opened)
CMD_SEC_LOCATE          Equ &4a        ; Host file mode: move file pointer by the unit of sector
CMD_SEC_READ            Equ &4b        ; Host file mode (SD card not supported): read data block form current address by the unit of sector
CMD_SEC_WRITE           Equ &4c        ; Host file mode (SD card not supported): write data block to current address by the unit of sector
CMD_DISK_BOC_CMD        Equ &50        ; Host mode (SD card not supported): execute BulkOnly transmit protocol command in USB storage controller
CMD_DISK_READ           Equ &54        ; Host mode (SD card not supported): read physic sector from USB storage
CMD_DISK_RD_GO          Equ &55        ; Host mode (SD card not supported): continue reading physic sector from USB storage
CMD_DISK_WRITE          Equ &56        ; Host mode (SD card not supported): write physic sector to USB storage
CMD_DISK_WR_GO          Equ &57        ; Host mode (SD card not supported): continue writing physic sector to USB storage
CMD_SET_USB_SPEED       Equ &04
CMD_GET_DEV_RATE        Equ &0a
CMD_GET_TOGGLE          Equ &0a
CMD_READ_VAR8           Equ &0a
CMD_SET_RETRY           Equ &0b
CMD_WRITE_VAR8          Equ &0b
CMD_READ_VAR32          Equ &0c
CMD_WRITE_VAR32         Equ &0d
CMD_DELAY_100US         Equ &0f
CMD_SET_USB_ID          Equ &12
CMD_SET_USB_ADDR        Equ &13
CMD_TEST_CONNECT        Equ &16
CMD_ABORT_NAK           Equ &17
CMD_SET_ENDP2           Equ &18
CMD_SET_ENDP3           Equ &19
CMD_SET_ENDP4           Equ &1a
CMD_SET_ENDP5           Equ &1b
CMD_SET_ENDP6           Equ &1c
CMD_SET_ENDP7           Equ &1d
CMD_DIRTY_BUFFER        Equ &25
CMD_WR_USB_DATA3        Equ &29
CMD_WR_USB_DATA5        Equ &2a
CMD_CLR_STALL           Equ &41
CMD_SET_ADDRESS         Equ &45
CMD_GET_DESCR           Equ &46
CMD_SET_CONFIG          Equ &49
CMD_AUTO_SETUP          Equ &4d
CMD_ISSUE_TKN_X         Equ &4e
CMD_ISSUE_TOKEN         Equ &4f
CMD_DISK_INIT           Equ &51
CMD_DISK_RESET          Equ &52
CMD_DISK_SIZE           Equ &53
CMD_DISK_INQUIRY        Equ &58
CMD_DISK_READY          Equ &59
CMD_DISK_R_SENSE        Equ &5a
CMD_RD_DISK_SEC         Equ &5b
CMD_WR_DISK_SEC         Equ &5c
CMD_DISK_MAX_LUN        Equ &5d

CMD_RET_SUCCESS         Equ &51
CMD_RET_ABORT           Equ &5f

USB_INT_USB_SUSPEND     Equ &05
USB_INT_WAKE_UP         Equ &06

USB_INT_EP0_SETUP       Equ &0c
USB_INT_EP0_OUT         Equ &00
USB_INT_EP0_IN          Equ &08
USB_INT_EP1_OUT         Equ &01
USB_INT_EP1_IN          Equ &09
USB_INT_EP2_OUT         Equ &02
USB_INT_EP2_IN          Equ &0a

USB_INT_BUS_RESET1      Equ &03
USB_INT_BUS_RESET2      Equ &07
USB_INT_BUS_RESET3      Equ &0b
USB_INT_BUS_RESET4      Equ &0f

USB_INT_SUCCESS         Equ &14
USB_INT_CONNECT         Equ &15
USB_INT_DISCONNECT      Equ &16
USB_INT_BUF_OVER        Equ &17
USB_INT_USB_READY       Equ &18
USB_INT_DISK_READ       Equ &1d
USB_INT_DISK_WRITE      Equ &1e
USB_INT_DISK_ERR        Equ &1f

ERR_DISK_DISCON         Equ &82
ERR_LARGE_SECTOR        Equ &84
ERR_TYPE_ERROR          Equ &92
ERR_BPB_ERROR           Equ &a1
ERR_DISK_FULL           Equ &b1
ERR_FDT_OVER            Equ &b2
ERR_FILE_CLOSE          Equ &b4
ERR_OPEN_DIR            Equ &41
ERR_MISS_FILE           Equ &42
ERR_FOUND_NAME          Equ &43

ERR_MISS_DIR            Equ &b3
ERR_LONG_BUF_OVER       Equ &48
ERR_LONG_NAME_ERR       Equ &49
ERR_NAME_EXIST          Equ &4a

ERR_USB_UNKNOWN         Equ &fa

DEF_DISK_UNKNOWN        Equ &00
DEF_DISK_DISCONN        Equ &01
DEF_DISK_CONNECT        Equ &02
DEF_DISK_MOUNTED        Equ &03
DEF_DISK_READY          Equ &10
DEF_DISK_OPEN_ROOT      Equ &12
DEF_DISK_OPEN_DIR       Equ &13
DEF_DISK_OPEN_FILE      Equ &14

DEF_SECTOR_SIZE         Equ 512

DEF_WILDCARD_CHAR       Equ &2a
DEF_SEPAR_CHAR1         Equ &5c
DEF_SEPAR_CHAR2         Equ &2f
DEF_FILE_YEAR           Equ 2004
DEF_FILE_MONTH          Equ 1
DEF_FILE_DATE           Equ 1

SPC_CMD_INQUIRY         Equ &12
SPC_CMD_READ_CAPACITY   Equ &25
SPC_CMD_READ10          Equ &28
SPC_CMD_WRITE10         Equ &2a
SPC_CMD_TEST_READY      Equ &00
SPC_CMD_REQUEST_SENSE   Equ &03
SPC_CMD_MODESENSE6      Equ &1a
SPC_CMD_MODESENSE10     Equ &5a
SPC_CMD_START_STOP      Equ &1b

VAR_SYS_BASE_INFO       Equ &20
VAR_RETRY_TIMES         Equ &25
VAR_FILE_BIT_FLAG       Equ &26
VAR_DISK_STATUS         Equ &2b
VAR_SD_BIT_FLAG         Equ &30
VAR_UDISK_TOGGLE        Equ &31
VAR_UDISK_LUN           Equ &34
VAR_SEC_PER_CLUS        Equ &38
VAR_FILE_DIR_INDEX      Equ &3b
VAR_CLUS_SEC_OFS        Equ &3c

VAR_DISK_ROOT           Equ &44
VAR_DSK_TOTAL_CLUS      Equ &48
VAR_DSK_START_LBA       Equ &4c
VAR_DSK_DAT_START       Equ &50
VAR_LBA_BUFFER          Equ &54
VAR_LBA_CURRENT         Equ &58
VAR_FAT_DIR_LBA         Equ &5c
VAR_START_CLUSTER       Equ &60
VAR_CURRENT_CLUST       Equ &64
VAR_FILE_SIZE           Equ &68
VAR_CURRENT_OFFSET      Equ &6c

DEF_USB_PID_NULL        Equ &00
DEF_USB_PID_SOF         Equ &05
DEF_USB_PID_SETUP       Equ &0d
DEF_USB_PID_IN          Equ &09
DEF_USB_PID_OUT         Equ &01
DEF_USB_PID_ACK         Equ &02
DEF_USB_PID_NAK         Equ &0a
DEF_USB_PID_STALL       Equ &0e
DEF_USB_PID_DATA0       Equ &03
DEF_USB_PID_DATA1       Equ &0b
DEF_USB_PID_PRE         Equ &0c

DEF_USB_REQ_READ        Equ &80
DEF_USB_REQ_WRITE       Equ &00
DEF_USB_REQ_TYPE        Equ &60
DEF_USB_REQ_STAND       Equ &00
DEF_USB_REQ_CLASS       Equ &20
DEF_USB_REQ_VENDOR      Equ &40
DEF_USB_REQ_RESERVE     Equ &60
DEF_USB_CLR_FEATURE     Equ &01
DEF_USB_SET_FEATURE     Equ &03
DEF_USB_GET_STATUS      Equ &00
DEF_USB_SET_ADDRESS     Equ &05
DEF_USB_GET_DESCR       Equ &06
DEF_USB_SET_DESCR       Equ &07
DEF_USB_GET_CONFIG      Equ &08
DEF_USB_SET_CONFIG      Equ &09
DEF_USB_GET_INTERF      Equ &0a
DEF_USB_SET_INTERF      Equ &0b
DEF_USB_SYNC_FRAME      Equ &0c

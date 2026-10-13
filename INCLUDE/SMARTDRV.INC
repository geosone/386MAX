;
; SMARTDRV.INC - SMARTDrive 3.x (SMARTAAR device) IOCTL
;
; Open 386MAX - GNU General Public License version 3.
;
; Data returned by IOCTL read from the SMARTAAR device (SMARTDRV.SYS of
; Windows 3.0/3.1), 44 bytes.
;

SD_IOCTL_Read	struc
SD_IR_Write_Through   db ?	; write-through flag
SD_IR_Write_Buff      db ?	; buffer write flag
SD_IR_Enable_Int13    db ?	; 1 = cache enabled
SD_IR_Driver_Type     db ?
SD_IR_Tick_Setting    dw ?	; ticks between flushes
SD_IR_Lock_Cache      db ?	; <> 0: cache locked
SD_IR_Reboot_Flush    db ?	; <> 0: flush on reboot
SD_IR_Cache_All       db ?	; 0: full track writes not cached
SD_IR_Double_Buffer   db ?	; 0 off, 1 on, 2 dynamic
SD_IR_Original_INT13  dd ?	; INT 13h hooked by SMARTDRV
SD_IR_Minor_Ver       db ?
SD_IR_Major_Ver       db ?
		      dw ?
SD_IR_Total_Sec_Read  dw ?	; sectors read
SD_IR_Cache_Sec_Read  dw ?	; ... from the cache
SD_IR_Track_Sec_Read  dw ?	; ... from the track buffer
SD_IR_Cache_Hit_Ratio db ?	; percent
SD_IR_Track_Hit_Ratio db ?	; percent
SD_IR_Total_Tracks    dw ?	; tracks in the cache
SD_IR_Total_Used      dw ?	; ... in use
SD_IR_Total_Locked    dw ?	; ... locked
SD_IR_Total_Dirty     dw ?	; ... dirty
SD_IR_Current_Size    dw ?	; cache size in 16 KB pages
SD_IR_Dev_Size	      dw ?	; size requested
SD_IR_Min_Cache_Size  dw ?	; minimum size
SD_IR_Cache_Lock_Ptr  dd ?	; byte to increment to lock the cache
SD_IOCTL_Read	ends

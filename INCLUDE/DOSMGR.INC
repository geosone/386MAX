;
; DOSMGR.INC - services of the DOS manager VxD (DOSMGR)
;
; Open 386MAX - GNU General Public License version 3.
;
; Only what 386MAX.VXD uses; service numbers are the ordinals in the
; service table of the device.
;

Begin_Service_Table DOSMGR
DOSMGR_Service	DOSMGR_Get_Version	; 0
DOSMGR_Service	_DOSMGR_Set_Exec_VM_Data ; 1
DOSMGR_Service	DOSMGR_Copy_VM_Drive_State ; 2
DOSMGR_Service	_DOSMGR_Exec_VM 	; 3
DOSMGR_Service	DOSMGR_Get_IndosPtr	; 4
DOSMGR_Service	DOSMGR_Add_Device	; 5
DOSMGR_Service	DOSMGR_Remove_Device	; 6
DOSMGR_Service	DOSMGR_Instance_Device	; 7
End_Service_Table DOSMGR

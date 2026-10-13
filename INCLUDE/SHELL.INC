;
; SHELL.INC - services of the SHELL VxD
;
; Open 386MAX - GNU General Public License version 3.
;
; Only what 386MAX.VXD uses; service numbers are the ordinals in the
; service table of the device.
;

Begin_Service_Table SHELL
SHELL_Service	SHELL_Get_Version	; 0
SHELL_Service	SHELL_Resolve_Contention ; 1
SHELL_Service	SHELL_Event		; 2
SHELL_Service	SHELL_SYSMODAL_Message	; 3
SHELL_Service	SHELL_Message		; 4
SHELL_Service	SHELL_GetVMInfo 	; 5 (Windows 3.1)
SHELL_Service	RESERVED		; 6
SHELL_Service	RESERVED		; 7
SHELL_Service	RESERVED		; 8
SHELL_Service	RESERVED		; 9
SHELL_Service	SHELL_Hook_Properties	; 0Ah (Windows 95)
End_Service_Table SHELL

; SHELL_Message buttons and results
MB_OK		equ	00h
MB_OKCANCEL	equ	01h
MB_ICONEXCLAMATION equ	30h
MB_DEFBUTTON2	equ	0100h
IDOK		equ	1

; SHELL_GetVMInfo flags
SGVMI_Windowed	equ	00000004h	; VM runs in a window

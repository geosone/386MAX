;
; VDD.INC - services of the display VxD (VDD)
;
; Open 386MAX - GNU General Public License version 3.
;
; Only what 386MAX.VXD uses; service numbers are the ordinals in the
; service table of the device.
;

Begin_Service_Table VDD
VDD_Service	VDD_Get_Version 	; 0: version and ID string
VDD_Service	VDD_PIF_State		; 1: video PIF bits of a VM
End_Service_Table VDD

; VDD_PIF_State bits
fVidNoTrpTxt	equ	0002h		; do not trap text mode
fVidHghRsGrfxMd equ	0040h		; hi-res graphics memory

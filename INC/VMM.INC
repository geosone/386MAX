;
; VMM.INC - Windows 3.1x/9x Virtual Machine Manager interface for VxDs
;
; Open 386MAX - GNU General Public License version 3.
;
; Written for 386MAX.VXD (VXD/*.ASM): the segments and macros of a VxD
; (VxD_*_SEG, BeginProc/EndProc, VMMcall/VxDcall, Begin_Service_Table for
; the service tables of other devices), the structures and the services and
; constants that 386MAX.VXD uses.  Service numbers are the ordinals of the
; VMM service table (cross-checked with the list in DOSLIB,
; github.com/joncampbell123/doslib, windows/w9xvmm).
;

BeginDoc	equ	<>
EndDoc		equ	<>
loopd		equ	<loop>

;------------------------------------------------------------------------------
; Device IDs
;------------------------------------------------------------------------------

VMM_Device_ID		equ	0001h
VDD_Device_ID		equ	000Ah
DOSMGR_Device_ID	equ	0015h
SHELL_Device_ID 	equ	0017h
VDD2_Device_ID		equ	001Ch	; Secondary display adapter

VMM_Init_Order		equ	00000000h

;------------------------------------------------------------------------------
; Structures
;------------------------------------------------------------------------------

; PUSHAD frame
Pushad_Struc	struc
Pushad_EDI	dd	?
Pushad_ESI	dd	?
Pushad_EBP	dd	?
Pushad_ESP	dd	?
Pushad_EBX	dd	?
Pushad_EDX	dd	?
Pushad_ECX	dd	?
Pushad_EAX	dd	?
Pushad_Struc	ends

; Client register frame of a VM (EBP points to it)
Client_Reg_Struc struc
Client_EDI	dd	?		; 00h
Client_ESI	dd	?		; 04h
Client_EBP	dd	?		; 08h
		dd	?		; 0Ch: ESP of PUSHAD
Client_EBX	dd	?		; 10h
Client_EDX	dd	?		; 14h
Client_ECX	dd	?		; 18h
Client_EAX	dd	?		; 1Ch
Client_Error	dd	?		; 20h: error code
Client_EIP	dd	?		; 24h
Client_CS	dw	?, ?		; 28h
Client_EFlags	dd	?		; 2Ch
Client_ESP	dd	?		; 30h
Client_SS	dw	?, ?		; 34h
Client_ES	dw	?, ?		; 38h
Client_DS	dw	?, ?		; 3Ch
Client_FS	dw	?, ?		; 40h
Client_GS	dw	?, ?		; 44h
Client_Alt_EIP	dd	?		; 48h: alternate (PM/V86) state
Client_Alt_CS	dw	?, ?
Client_Alt_EFlags dd	?
Client_Alt_ESP	dd	?
Client_Alt_SS	dw	?, ?
Client_Alt_ES	dw	?, ?
Client_Alt_DS	dw	?, ?
Client_Alt_FS	dw	?, ?
Client_Alt_GS	dw	?, ?
Client_Reg_Struc ends

; the same frame as words ...
Client_Word_Reg_Struc struc
Client_DI	dw	?, ?
Client_SI	dw	?, ?
Client_BP	dw	?, ?
		dd	?
Client_BX	dw	?, ?
Client_DX	dw	?, ?
Client_CX	dw	?, ?
Client_AX	dw	?, ?
		dd	?
Client_IP	dw	?, ?
		dd	?
Client_Flags	dw	?, ?
Client_SP	dw	?, ?
Client_Word_Reg_Struc ends

; ... and as bytes
Client_Byte_Reg_Struc struc
		dd	4 dup (?)
Client_BL	db	?
Client_BH	db	?, ?, ?
Client_DL	db	?
Client_DH	db	?, ?, ?
Client_CL	db	?
Client_CH	db	?, ?, ?
Client_AL	db	?
Client_AH	db	?, ?, ?
Client_Byte_Reg_Struc ends

; Device descriptor block
VxD_Desc_Block	struc
DDB_Next		dd	?	; 00h: used by VMM
DDB_SDK_Version 	dw	030Ah	; 04h
DDB_Req_Device_Number	dw	0	; 06h: device ID
DDB_Dev_Major_Version	db	0	; 08h
DDB_Dev_Minor_Version	db	0	; 09h
DDB_Flags		dw	0	; 0Ah: used by VMM
DDB_Name		db	'        ' ; 0Ch
DDB_Init_Order		dd	80000000h ; 14h
DDB_Control_Proc	dd	?	; 18h
DDB_V86_API_Proc	dd	0	; 1Ch
DDB_PM_API_Proc 	dd	0	; 20h
DDB_V86_API_CSIP	dd	0	; 24h
DDB_PM_API_CSIP 	dd	0	; 28h
DDB_Reference_Data	dd	?	; 2Ch: from real mode init
DDB_Service_Table_Ptr	dd	0	; 30h
DDB_Service_Table_Size	dd	0	; 34h
VxD_Desc_Block	ends

; _AddInstanceItem
InstDataStruc	struc
InstLinkF	dd	0		; used by VMM
InstLinkB	dd	0		; used by VMM
InstLinAddr	dd	?		; linear address of the block
InstSize	dd	?		; size in bytes
InstType	dd	?		; ALWAYS_Field
InstDataStruc	ends

ALWAYS_Field	equ	200h		; always switched

; VM control block
CB_VM_Status	equ	dword ptr 00h
CB_High_Linear	equ	dword ptr 04h

VMStat_Exclusive	equ	00000001h
VMStat_Background	equ	00000002h
VMStat_PM_Exec		equ	00000020h

;------------------------------------------------------------------------------
; Constants
;------------------------------------------------------------------------------

; control messages
Sys_Critical_Init	equ	00h
Device_Init		equ	01h
Init_Complete		equ	02h
Sys_VM_Init		equ	03h
System_Exit		equ	05h
Sys_Critical_Exit	equ	06h
Create_VM		equ	07h
VM_Init 		equ	09h
VM_Terminate		equ	0Ah
VM_Not_Executeable	equ	0Bh
Destroy_VM		equ	0Ch
Debug_Query		equ	14h

; real mode init: flags in BX on entry, result in AX
Duplicate_Device_ID	equ	0001h
Duplicate_From_INT2F	equ	0002h
Loading_From_INT2F	equ	0004h
Device_Load_Ok		equ	0
Abort_Device_Load	equ	1
Abort_Win386_Load	equ	2
No_Fail_Message 	equ	8000h

; _HeapAllocate, _PageAllocate
HeapZeroInit		equ	00000001h
PageZeroInit		equ	00000001h
PageUseAlign		equ	00000002h
PageFixed		equ	00000008h
PageLocked		equ	00000080h
PG_VM			equ	0
PG_SYS			equ	1
PG_HOOKED		equ	7
PG_IGNORE		equ	0FFFFFFFFh

; _Allocate_Global_V86_Data_Area
GVDAWordAlign		equ	00000001h
GVDADWordAlign		equ	00000002h
GVDAParaAlign		equ	00000004h
GVDAInstance		equ	00000100h

; Begin_Critical_Section, Wait_Semaphore
Block_Svc_Ints		equ	01h
Block_Svc_If_Ints_Locked equ	02h
Block_Enable_Ints	equ	04h

; I/O trapping
Output			equ	04h

; page table bits (_ModifyPageBits)
P_PRES			equ	01h
P_WRITE 		equ	02h
P_USER			equ	04h
P_AVAIL 		equ	P_PRES+P_WRITE+P_USER

;------------------------------------------------------------------------------
; Segments
;------------------------------------------------------------------------------

_LTEXT	segment dword use32 public 'CODE'       ; locked code
_LTEXT	ends
_TEXT	segment dword use32 public 'PCODE'      ; pageable code
_TEXT	ends
_ITEXT	segment dword use32 public 'ICODE'      ; init code
_ITEXT	ends
_LDATA	segment dword public 'CODE'             ; locked data
_LDATA	ends
_DATA	segment dword public 'PCODE'            ; pageable data
_DATA	ends
_IDATA	segment dword public 'ICODE'            ; init data
_IDATA	ends
_RCODE	segment word use16 public 'RCODE'       ; real mode init
_RCODE	ends

_LGROUP group	_LTEXT, _LDATA
_PGROUP group	_TEXT, _DATA
_IGROUP group	_ITEXT, _IDATA

	assume	cs:FLAT, ds:FLAT, es:FLAT, ss:FLAT

OFFSET32	equ	<offset FLAT:>

??_RCODE_SEG = 0			; 1 inside VxD_REAL_INIT_SEG

VxD_LOCKED_CODE_SEG macro
_LTEXT	segment
	assume	cs:FLAT, ds:FLAT, es:FLAT, ss:FLAT
	endm
VxD_LOCKED_CODE_ENDS macro
_LTEXT	ends
	endm

VxD_ICODE_SEG macro
_ITEXT	segment
	assume	cs:FLAT, ds:FLAT, es:FLAT, ss:FLAT
	endm
VxD_ICODE_ENDS macro
_ITEXT	ends
	endm

VxD_LOCKED_DATA_SEG macro NO_ALIGN
_LDATA	segment
ifb <NO_ALIGN>
	align	4
endif
	endm
VxD_LOCKED_DATA_ENDS macro
_LDATA	ends
	endm

VxD_IDATA_SEG macro
_IDATA	segment
	endm
VxD_IDATA_ENDS macro
_IDATA	ends
	endm

VxD_REAL_INIT_SEG macro
_RCODE	segment
	assume	cs:_RCODE, ds:_RCODE, es:_RCODE, ss:_RCODE
??_RCODE_SEG = 1
	endm
VxD_REAL_INIT_ENDS macro
??_RCODE_SEG = 0
_RCODE	ends
	endm

VxD_CODE_SEG	equ	<VxD_LOCKED_CODE_SEG>
VxD_CODE_ENDS	equ	<VxD_LOCKED_CODE_ENDS>
VxD_DATA_SEG	equ	<VxD_LOCKED_DATA_SEG>
VxD_DATA_ENDS	equ	<VxD_LOCKED_DATA_ENDS>

;------------------------------------------------------------------------------
; Procedures: BeginProc name [,PUBLIC] ... EndProc name
; Protected mode procedures are always public, real mode ones with PUBLIC.
;------------------------------------------------------------------------------

@CurProc equ	<>

BeginProc macro Name, P1
@CurProc substr @CurProc,1,0
@CurProc catstr @CurProc,<Name>
if ??_RCODE_SEG
  ifidni <P1>, <PUBLIC>
	public	Name
  endif
else
	public	Name
endif
Name	proc	near
	endm

EndProc macro Name
Name	endp
	endm

;------------------------------------------------------------------------------
; Service calls: VMMcall/VxDcall service [,<C arguments>]
; C arguments are pushed from right to left and removed after the call.
;------------------------------------------------------------------------------

PushCParams macro P1, P2, P3, P4, P5, P6, P7, P8, P9, P10
	irp	Param, <P10, P9, P8, P7, P6, P5, P4, P3, P2, P1>
	ifnb	<Param>
	push	Param
	endif
	endm
	endm

ClearCParams macro Count, P1, P2, P3, P4, P5, P6, P7, P8, P9, P10
ifnb <P1>
	ClearCParams %(Count+1), <P2>, <P3>, <P4>, <P5>, <P6>, <P7>, <P8>, <P9>, <P10>
else
if Count
	add	esp, Count*4
endif
endif
	endm

VxDcall macro Service, Params
	PushCParams Params
	int	20h			; dynamic link to the service
	dd	Service
	ClearCParams 0, Params
	endm

VMMcall macro Service, Params
	VxDcall <Service>, <Params>
	endm

; Save the client registers on the stack / restore them
Push_Client_State macro
	sub	esp, size Client_Reg_Struc
	push	edi
	lea	edi, [esp+4]
	VMMcall Save_Client_State
	pop	edi
	endm

Pop_Client_State macro
	push	esi
	lea	esi, [esp+4]
	VMMcall Restore_Client_State
	pop	esi
	add	esp, size Client_Reg_Struc
	endm

; Reg_32 = flat address of client Seg:Off (Seg only: offset 0)
Client_Ptr_Flat macro Reg_32, Cli_Seg, Cli_Off
ifdifi <Reg_32>, <EAX>
	push	eax
endif
ifb <Cli_Off>
	mov	ax, (Client_&Cli_Seg * 100h) + 0FFh
else
	mov	ax, (Client_&Cli_Seg * 100h) + Client_&Cli_Off
endif
	VMMcall Map_Flat
ifdifi <Reg_32>, <EAX>
	mov	Reg_32, eax
	pop	eax
endif
	endm

; Execute a software interrupt in the current VM
VxDint	macro	Int_Number
	push	dword ptr Int_Number
	VMMcall Exec_VxD_Int
	endm

;------------------------------------------------------------------------------
; Service tables of other devices (callers only):
;	Begin_Service_Table dev
;	dev_Service name		; name = (dev_Device_ID shl 16) + number
;	End_Service_Table dev
;------------------------------------------------------------------------------

Begin_Service_Table macro Device_Name, Def_Segment
Num_&Device_Name&_Services = 0
Device_Name&_Service macro Procedure, P2, P3
  ifdifi <Procedure>, <RESERVED>
Procedure = (Device_Name&_Device_ID shl 16) + Num_&Device_Name&_Services
  endif
Num_&Device_Name&_Services = Num_&Device_Name&_Services + 1
	endm
	endm

End_Service_Table macro Device_Name, Def_Segment
	purge	Device_Name&_Service
	endm

;------------------------------------------------------------------------------
; Device descriptor: Declare_Virtual_Device name, major, minor, control
;	procedure, device ID, init order [, V86 API proc, PM API proc]
; defines the public name_DDB (no service table)
;------------------------------------------------------------------------------

Declare_Virtual_Device macro Name, Major_Ver, Minor_Ver, Ctrl_Proc, Device_Num, Init_Order, V86_Proc, PM_Proc
VxD_LOCKED_DATA_SEG
	public	Name&_DDB
Name&_DDB VxD_Desc_Block <0, 030Ah, Device_Num, Major_Ver, Minor_Ver, 0, '&Name', Init_Order, OFFSET32 Ctrl_Proc>
ifnb <V86_Proc>
	org	Name&_DDB.DDB_V86_API_Proc
	dd	OFFSET32 V86_Proc
endif
ifnb <PM_Proc>
	org	Name&_DDB.DDB_PM_API_Proc
	dd	OFFSET32 PM_Proc
endif
ifnb <V86_Proc&PM_Proc>
	org	Name&_DDB + size VxD_Desc_Block
endif
VxD_LOCKED_DATA_ENDS
	endm

;------------------------------------------------------------------------------
; VMM services used by 386MAX.VXD (device 1, ordinal in the comment)
;------------------------------------------------------------------------------

Get_VMM_Version                 equ	000010000h	; 000h
Get_Cur_VM_Handle               equ	000010001h	; 001h
Get_Sys_VM_Handle               equ	000010003h	; 003h
Test_Sys_VM_Handle              equ	000010004h	; 004h
Validate_VM_Handle              equ	000010005h	; 005h
Install_V86_Break_Point         equ	000010009h	; 009h
Remove_V86_Break_Point          equ	00001000Ah	; 00Ah
Allocate_V86_Call_Back          equ	00001000Bh	; 00Bh
Schedule_VM_Event               equ	00001000Fh	; 00Fh
Map_Flat                        equ	00001001Ch	; 01Ch
Begin_Critical_Section          equ	00001001Fh	; 01Fh
End_Critical_Section            equ	000010020h	; 020h
Create_Semaphore                equ	000010025h	; 025h
Destroy_Semaphore               equ	000010026h	; 026h
Wait_Semaphore                  equ	000010027h	; 027h
Signal_Semaphore                equ	000010028h	; 028h
Suspend_VM                      equ	00001002Bh	; 02Bh
Resume_VM                       equ	00001002Ch	; 02Ch
Nuke_VM                         equ	00001002Eh	; 02Eh
Get_Time_Slice_Priority         equ	000010032h	; 032h
Set_Time_Slice_Priority         equ	000010033h	; 033h
Get_Next_VM_Handle              equ	00001003Bh	; 03Bh
Hook_V86_Int_Chain              equ	000010041h	; 041h
Get_V86_Int_Vector              equ	000010042h	; 042h
Set_V86_Int_Vector              equ	000010043h	; 043h
Simulate_Int                    equ	000010046h	; 046h
Simulate_Far_Call               equ	000010048h	; 048h
Simulate_Push                   equ	00001004Dh	; 04Dh
_HeapAllocate                   equ	00001004Fh	; 04Fh
_HeapFree                       equ	000010051h	; 051h
_PageAllocate                   equ	000010053h	; 053h
_PageFree                       equ	000010055h	; 055h
_MapIntoV86                     equ	00001005Dh	; 05Dh
_PhysIntoV86                    equ	00001005Eh	; 05Eh
_ModifyPageBits                 equ	000010060h	; 060h
_CopyPageTable                  equ	000010061h	; 061h
_GetNulPageHandle               equ	00001006Ah	; 06Ah
_MapPhysToLinear                equ	00001006Ch	; 06Ch
Hook_V86_Page                   equ	000010071h	; 071h
_Assign_Device_V86_Pages        equ	000010072h	; 072h
_Get_Device_V86_Pages_Array     equ	000010074h	; 074h
_Allocate_GDT_Selector          equ	000010076h	; 076h
_Free_GDT_Selector              equ	000010077h	; 077h
_Allocate_LDT_Selector          equ	000010078h	; 078h
_Free_LDT_Selector              equ	000010079h	; 079h
_BuildDescriptorDWORDs          equ	00001007Ah	; 07Ah
_SetDescriptor                  equ	00001007Ch	; 07Ch
Hook_V86_Fault                  equ	00001007Fh	; 07Fh
Hook_PM_Fault                   equ	000010080h	; 080h
Begin_Nest_V86_Exec             equ	000010082h	; 082h
Begin_Nest_Exec                 equ	000010083h	; 083h
Exec_Int                        equ	000010084h	; 084h
Resume_Exec                     equ	000010085h	; 085h
End_Nest_Exec                   equ	000010086h	; 086h
Save_Client_State               equ	00001008Dh	; 08Dh
Restore_Client_State            equ	00001008Eh	; 08Eh
Exec_VxD_Int                    equ	00001008Fh	; 08Fh
Hook_Device_Service             equ	000010090h	; 090h
System_Control                  equ	000010093h	; 093h
_AddInstanceItem                equ	0000100A6h	; 0A6h
_Allocate_Device_CB_Area        equ	0000100A7h	; 0A7h
_Allocate_Global_V86_Data_Area  equ	0000100A8h	; 0A8h
Get_Profile_Decimal_Int         equ	0000100ABh	; 0ABh
Convert_Hex_String              equ	0000100B0h	; 0B0h
Get_Profile_Boolean             equ	0000100B1h	; 0B1h
Get_Profile_String              equ	0000100B3h	; 0B3h
Get_Next_Profile_String         equ	0000100B4h	; 0B4h
Get_Config_Directory            equ	0000100B7h	; 0B7h
GetSet_HMA_Info                 equ	0000100BCh	; 0BCh
Fatal_Error_Handler             equ	0000100BEh	; 0BEh
Fatal_Memory_Error              equ	0000100BFh	; 0BFh
Close_VM                        equ	0000100ECh	; 0ECh

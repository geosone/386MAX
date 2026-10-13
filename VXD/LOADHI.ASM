	 title	 LOADHI -- Device frame of 386MAX.VXD (UMBs in Windows VMs)
	 page	 78,130
	 name	 LOADHI

COMMENT|		Module Specifications

Open 386MAX - GNU General Public License version 3.

Segmentation:  _LTEXT/_LDATA (locked), _ITEXT/_IDATA (init), _RCODE (real
	       mode init)

Replaces the binary-only LoadHi objects (LOADHI, INSTINIT, INSTSWAP) of
the original build.  This module is the device frame of 386MAX.VXD: its
device descriptor LoadHi_DDB, the control procedure, the real mode init
entry, and the UMB services that the 386MAX part of the VxD (VMAX_*)
expects; VMAX_LHI.ASM supplies the 386MAX specific callbacks:

	Real_Mode_Hook		real mode init of the 386MAX part
	Control_Call_Hook	every control message, before our own handling
	Get_Hooks_To_Install	which LoadHi functions are wanted:
				bit 0 = hook DOSMGR_Instance_Device,
				bit 1 = set up the UMB pages ourselves
	Get_UMB_Info		first UMB page and number of pages
	Get_Mapped_Page_Num	physical page behind a UMB page
	Get_Device_Info 	start and size of a device loaded high

Windows 3.1 or later (VMM 3.10+, also Windows 9x) is required.  Windows 3.0
needed separate instance data handling and patches of its V86MMGR; its
386 enhanced mode is refused in real mode init with a message.

Device number 1Ch is VDD2_Device_ID: our single service VDD2_Get_Version
reports a secondary display adapter when UMBs cover B000h-B7FFh, so that
the display VxD leaves that area alone.

|

.386p
.xlist
	 include VMM.INC
	 include MASM.INC
.list

LoadHi_Device_ID equ	VDD2_Device_ID	; 1Ch, see above

LH_HOOK_INSTDEV  equ	01h	; Get_Hooks_To_Install: DOSMGR_Instance_Device
LH_SETUP_UMBS	 equ	02h	; ...			set up the UMB pages

DOSMGR_Instance_Device_Svc equ (DOSMGR_Device_ID shl 16) + 7

INSTDATA_LEN	 equ	size InstDataStruc
MAXGLOBAL	 equ	32	; number of GLOBAL= names we remember

	 page
VxD_LOCKED_DATA_SEG

	 public  LoadHi_DDB
LoadHi_DDB VxD_Desc_Block <0,0300h,LoadHi_Device_ID,1,0,0,'LoadHi  ',\
	 VMM_Init_Order,OFFSET32 LoadHi_Control,0,0,0,0,0,\
	 OFFSET32 LoadHi_Service_Table,1>

LoadHi_Service_Table label dword
	 dd	 OFFSET32 VDD2_Get_Version

LH_FLAGS	dd	0	; result of Get_Hooks_To_Install
FIRST_UMB_PAGE	dd	0	; first V86 page that may hold UMBs
NUM_UMB_PAGES	dd	0	; number of pages from FIRST_UMB_PAGE on
MONO_UMB	dd	0	; non-zero if a UMB lies in B000h-B7FFh
OLD_INSTDEV	dd	0	; original DOSMGR_Instance_Device

NUM_GLOBAL	dd	0	; GLOBAL= device names (8 chars each)
GLOBAL_NAMES	db	MAXGLOBAL*8 dup (?)

VxD_LOCKED_DATA_ENDS

VxD_IDATA_SEG

MSG_NOINIT	db	'386MAX.VXD: UMB set-up failed', 0
MSG_OLDWIN	db	'386MAX.VXD: Windows 3.1 or later required', 0
KEY_GLOBAL	db	'GLOBAL', 0
KEY_LOCAL	db	'LOCAL', 0
DEV_NAME	db	8 dup (?)

VxD_IDATA_ENDS

	 page
VxD_LOCKED_CODE_SEG

	 extrn	 Control_Call_Hook:near
	 extrn	 Get_Hooks_To_Install:near
	 extrn	 Get_Mapped_Page_Num:near

BeginProc LoadHi_Control
COMMENT|

Control procedure.  The 386MAX part sees every message first; carry from
it fails the message.  Our own work is needed only when we set up the UMB
pages (Get_Hooks_To_Install bit 1, i.e. an older 386MAX is updated);
Sys_Critical_Init always runs because it asks for the hooks.

|

	 pushad
	 call	 Control_Call_Hook ; 386MAX part
	 popad
	 jc	 short LHC_XIT	; Failed by the 386MAX part

	 cmp	 eax,Sys_Critical_Init
	 je	 LoadHi_Sys_Critical_Init

	 test	 LH_FLAGS,LH_SETUP_UMBS ; Do we manage the UMB pages?
	 jz	 short LHC_OK	; No, nothing more to do

	 cmp	 eax,Device_Init
	 je	 LoadHi_Device_Init
	 cmp	 eax,Create_VM
	 je	 LoadHi_Map_Pages
LHC_OK:
	 clc
LHC_XIT:
	 ret
EndProc LoadHi_Control

BeginProc LoadHi_Map_Pages
COMMENT|

Map the UMB pages into the VM EBX (Sys_Critical_Init for the system VM,
Create_VM for the others).  Carry set if a page could not be mapped.

|

	 REGSAVE <eax,ecx,edx>
	 mov	 eax,FIRST_UMB_PAGE
	 mov	 ecx,NUM_UMB_PAGES
	 jecxz	 LMP_OK
LMP_NEXT:
	 call	 Get_Mapped_Page_Num ; EDX = physical page (0 = none)
	 or	 edx,edx
	 jz	 short LMP_SKIP

	 REGSAVE <eax,ecx>
	 VMMcall _PhysIntoV86 <edx, ebx, eax, 1, 0>
	 or	 eax,eax	; 0 = failed
	 REGREST <ecx,eax>
	 jz	 short LMP_ERR
LMP_SKIP:
	 inc	 eax
	 loop	 LMP_NEXT
LMP_OK:
	 clc
	 jmp	 short LMP_XIT
LMP_ERR:
	 stc
LMP_XIT:
	 REGREST <edx,ecx,eax>
	 ret
EndProc LoadHi_Map_Pages

BeginProc ProcessPageInMonoDispArea
COMMENT|

EAX = V86 page that gets a UMB, EDX = physical page (0 = none).  A UMB in
B000h-B7FFh makes VDD2_Get_Version answer, see the module header.

|

	 cmp	 eax,0B0h
	 jb	 short @F
	 cmp	 eax,0B7h
	 ja	 short @F
	 or	 edx,edx
	 jz	 short @F
	 mov	 MONO_UMB,-1
@@:
	 ret
EndProc ProcessPageInMonoDispArea

BeginProc VDD2_Get_Version
COMMENT|

Service 0 of device 1Ch.  With a UMB in the monochrome area: EAX = version
2.00, ESI -> device name, carry clear.  Otherwise EAX = ESI = 0, carry set
(no secondary display adapter).

|

	 cmp	 MONO_UMB,0
	 je	 short @F
	 mov	 eax,0200h
	 mov	 esi,OFFSET32 LoadHi_DDB.DDB_Name
	 clc
	 ret
@@:
	 xor	 eax,eax
	 xor	 esi,esi
	 stc
	 ret
EndProc VDD2_Get_Version

BeginProc LoadHi_Instance_Device
COMMENT|

Hook of DOSMGR_Instance_Device (ESI -> 8 character device name, carry
clear if instanced).  A character device loaded into a UMB is instanced
here (start and size from Get_Device_Info) unless SYSTEM.INI names it
GLOBAL=; everything else goes to DOSMGR.

|

	 call	 IS_GLOBAL	; Carry set if GLOBAL=
	 jc	 short LID_CHAIN
	 call	 Get_Device_Info ; EDX = start, EAX = size
	 jc	 short LID_CHAIN
	 call	 INSTANCE_BLOCK ; Carry set if failed
	 jc	 short LID_CHAIN
	 ret			; Carry clear
LID_CHAIN:
	 jmp	 dword ptr OLD_INSTDEV ; Let DOSMGR handle it
EndProc LoadHi_Instance_Device

BeginProc IS_GLOBAL
COMMENT|

Carry set if the 8 character device name at ESI is in GLOBAL_NAMES.

|

	 REGSAVE <ecx,edx,esi,edi>
	 mov	 edx,NUM_GLOBAL
	 mov	 edi,OFFSET32 GLOBAL_NAMES
IG_NEXT:
	 dec	 edx		; Any (more) names?
	 js	 short IG_NO	; No
	 REGSAVE <esi,edi>
	 mov	 ecx,8
	 cld
	 repe	 cmpsb
	 REGREST <edi,esi>
	 lea	 edi,[edi+8]	; (flags kept)
	 jne	 IG_NEXT
	 stc			; Found
	 jmp	 short IG_XIT
IG_NO:
	 clc
IG_XIT:
	 REGREST <edi,esi,edx,ecx>
	 ret
EndProc IS_GLOBAL

BeginProc INSTANCE_BLOCK
COMMENT|

Make EAX bytes from linear address EDX instance data (per VM, always
switched).  Carry set if it failed.

|

	 pushad
	 mov	 esi,edx	; Start
	 mov	 edi,eax	; Size
	 VMMcall _HeapAllocate <INSTDATA_LEN, HeapZeroInit>
	 or	 eax,eax
	 jz	 short IB_ERR
	 mov	 [eax].InstLinAddr,esi
	 mov	 [eax].InstSize,edi
	 mov	 [eax].InstType,ALWAYS_Field
	 VMMcall _AddInstanceItem <eax, 0>
	 or	 eax,eax
	 jz	 short IB_ERR
	 popad
	 clc
	 ret
IB_ERR:
	 popad
	 stc
	 ret
EndProc INSTANCE_BLOCK

VxD_LOCKED_CODE_ENDS

	 page
VxD_ICODE_SEG

	 extrn	 Get_UMB_Info:near
	 extrn	 Get_Device_Info:near

BeginProc LoadHi_Sys_Critical_Init
COMMENT|

EBX = system VM, EDX = reference data.  Ask the 386MAX part which
functions it wants, hook DOSMGR_Instance_Device, and if we set up the UMBs:
assign the UMB pages to us and map them into the system VM.

|

	 VMMcall Get_VMM_Version ; AX = version
	 cmp	 ax,030Ah
	 jb	 LSCI_OLDWIN

	 REGSAVE <edx>
	 call	 Get_Hooks_To_Install ; AX = version, EDX = reference data
	 REGREST <edx>
	 mov	 LH_FLAGS,eax

	 test	 LH_FLAGS,LH_HOOK_INSTDEV
	 jz	 short @F
	 mov	 eax,DOSMGR_Instance_Device_Svc
	 mov	 esi,OFFSET32 LoadHi_Instance_Device
	 VMMcall Hook_Device_Service
	 jc	 LSCI_ERR
	 mov	 OLD_INSTDEV,esi
@@:
	 test	 LH_FLAGS,LH_SETUP_UMBS
	 jz	 LSCI_OK

	 call	 Get_UMB_Info	; EAX = first page, EDX = number of pages
	 cmp	 eax,0A0h	; Never below the video area
	 jb	 LSCI_ERR
	 mov	 FIRST_UMB_PAGE,eax
	 mov	 NUM_UMB_PAGES,edx

	 mov	 ecx,edx
	 jecxz	 LSCI_MAP
LSCI_NEXT:
	 call	 Get_Mapped_Page_Num ; EDX = physical page (0 = none)
	 or	 edx,edx
	 jz	 LSCI_SKIP
	 call	 ProcessPageInMonoDispArea
	 REGSAVE <eax,ecx>
	 VMMcall _Assign_Device_V86_Pages <eax, 1, 0, 0> ; Global
	 or	 eax,eax	; 0 = failed
	 REGREST <ecx,eax>
	 jz	 LSCI_ERR
LSCI_SKIP:
	 inc	 eax
	 loop	 LSCI_NEXT
LSCI_MAP:
	 call	 LoadHi_Map_Pages ; EBX = system VM
	 jc	 LSCI_ERR
LSCI_OK:
	 clc
	 ret

LSCI_OLDWIN:
	 mov	 esi,OFFSET32 MSG_OLDWIN
	 jmp	 short @F
LSCI_ERR:
	 mov	 esi,OFFSET32 MSG_NOINIT
@@:
	 xor	 eax,eax
	 VMMcall Fatal_Error_Handler ; Does not return
EndProc LoadHi_Sys_Critical_Init

BeginProc LoadHi_Device_Init
COMMENT|

Only when we set up the UMBs: remember the GLOBAL= device names of
[386Enh] and instance the devices loaded high that are named by LOCAL=.

|

	 xor	 esi,esi	; [386Enh]
	 xor	 edx,edx	; No default
	 mov	 edi,OFFSET32 KEY_GLOBAL
	 VMMcall Get_Profile_String
LDI_GLOBAL:
	 jc	 short LDI_LOCAL0
	 mov	 eax,NUM_GLOBAL
	 cmp	 eax,MAXGLOBAL
	 jae	 short LDI_LOCAL0
	 lea	 edi,GLOBAL_NAMES[eax*8]
	 call	 COPY_NAME	; EDX -> name, EDI -> 8 bytes
	 inc	 NUM_GLOBAL
	 xor	 esi,esi
	 mov	 edi,OFFSET32 KEY_GLOBAL
	 VMMcall Get_Next_Profile_String
	 jmp	 LDI_GLOBAL

LDI_LOCAL0:
	 xor	 esi,esi
	 xor	 edx,edx
	 mov	 edi,OFFSET32 KEY_LOCAL
	 VMMcall Get_Profile_String
LDI_LOCAL:
	 jc	 short LDI_XIT
	 mov	 edi,OFFSET32 DEV_NAME
	 call	 COPY_NAME
	 REGSAVE <edx>
	 mov	 esi,OFFSET32 DEV_NAME
	 call	 IS_GLOBAL
	 jc	 short @F
	 call	 Get_Device_Info ; EDX = start, EAX = size
	 jc	 short @F
	 call	 INSTANCE_BLOCK
@@:
	 REGREST <edx>
	 xor	 esi,esi
	 mov	 edi,OFFSET32 KEY_LOCAL
	 VMMcall Get_Next_Profile_String
	 jmp	 LDI_LOCAL
LDI_XIT:
	 clc
	 ret
EndProc LoadHi_Device_Init

BeginProc COPY_NAME
COMMENT|

Copy the device name at EDX (zero-terminated) blank padded to 8 bytes at
EDI.

|

	 REGSAVE <eax,ecx,esi,edi>
	 mov	 esi,edx
	 mov	 ecx,8
	 cld
@@:
	 lodsb
	 or	 al,al
	 jz	 short @F
	 stosb
	 loop	 @B
	 jmp	 short CN_XIT
@@:
	 mov	 al,' '
	 rep	 stosb
CN_XIT:
	 REGREST <edi,esi,ecx,eax>
	 ret
EndProc COPY_NAME

VxD_ICODE_ENDS

	 page
VxD_REAL_INIT_SEG

	 extrn	 Real_Mode_Hook:near

LoadHi_Real_Init proc near
COMMENT|

Real mode init (AX = Windows version, BX = flags).  Load only as part of
386MAX's INT 2Fh 1605h device list, once; refuse Windows 3.0.

|

	 test	 bx,Duplicate_Device_ID or Duplicate_From_INT2F
	 jnz	 short LRI_NOLOAD
	 test	 bx,Loading_From_INT2F
	 jz	 short LRI_NOLOAD
	 cmp	 ax,030Ah
	 jb	 short LRI_OLDWIN
	 jmp	 Real_Mode_Hook ; 386MAX part, returns to Windows

LRI_OLDWIN:
	 mov	 dx,offset MSG_RM_OLDWIN
	 mov	 ah,09h
	 int	 21h
	 mov	 ax,Abort_Win386_Load or No_Fail_Message
	 jmp	 short @F
LRI_NOLOAD:
	 mov	 ax,Abort_Device_Load or No_Fail_Message
@@:
	 xor	 bx,bx		; No excluded pages
	 xor	 si,si		; No instance data
	 ret
LoadHi_Real_Init endp

MSG_RM_OLDWIN db 'Open 386MAX: 386 enhanced mode needs Windows 3.1 or later.'
	 db	 13, 10, '$'

VxD_REAL_INIT_ENDS

	 end	 LoadHi_Real_Init

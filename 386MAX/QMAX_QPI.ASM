;' $Header$
	 title	 QMAX_QPI -- 386MAX QEMM Programming Interface (QPI)
	 page	 58,122
	 name	 QMAX_QPI

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2026 Open 386MAX.  GNU General Public License version 3.

Segmentation:  Group PGROUP:
	       Program segment CODE,  byte-aligned,  public, class 'prog'
	       Program segment ECODE, dword-aligned, public, class 'ecode'
	       Data    segment EDATA, dword-aligned, public, class 'edata'
	       Group JGROUP:
	       Program segment JCODE, dword-aligned, public, class 'jcode'
	       Data    segment JDATA, dword-aligned, public, class 'jcode'

Program derived from:  None.

Original code by:  Open 386MAX, 2026.

Modifications by:  None.

The subset of the QEMM Programming Interface (QPI) which SBEMU's real
mode support uses, plus the separately identified Open MaxView extension.
The QPI part provides I/O port trapping with a callback in VM, the way
Jemm's QPIEMU provides it.

* The entry point in VM is the old VCPI one (OLDVCPI in QMAX_OVR, an
  INT 0FEh), returned by INT 67h AH=3Fh, CX='QE', DX='MM' (QEMM's
  way) and by INT 2Fh AX=1684h, BX=4354h (Jemm's QPIEMU, QMAX_XMS).
  INTFE (QMAX_VCP) passes the QPI functions (AH=03h, 1Ah) and Open
  MaxView functions (AH=4Dh) to QPI_API
  below; those of the old VCPI spec are AH=0Ch, 10h.
* I/O to a port trapped via QPI faults because its bit in the I/O
  permission bit map is set.  CHECK_INP/CHECK_OUT (QMAX_IOP) call
  QPI_CHECK which calls the callback in VM (QPI_CALLVM) the way HARDINT
  calls a VM interrupt handler.

Because PGROUP is full, all but the hooks lives here in JGROUP.

|

.386p
.xlist
	 include MASM.INC
	 include 386.INC
	 include PTR.INC
	 include CPUFLAGS.INC
	 include ALLMEM.INC
	 include MASM5.MAC
	 include IOTRAP.INC
	 include MAXVIEW.INC

	 include QMAX_DTE.INC
	 include QMAX_OEM.INC
	 include QMAX_EMM.INC
.list

@MAX_EHNDLCNT equ 255		; Maximum # EMS handles (as QMAX_I67)

PGROUP	 group	 CODE,ECODE,EDATA
JGROUP	 group	 JCODE,JDATA


CODE	 segment use16 byte public 'prog' ; Start CODE segment
	 assume  cs:PGROUP,ds:PGROUP

	 extrn	 GLB_FLAG:word
	 extrn	 QPI_DEFCB:far
	 extrn	 LCL_FLAG:word
	 include QMAX_LCL.INC
	 extrn	 HARDRET:far

CODE	 ends			; End CODE segment


ECODE	 segment use16 dword public 'ecode' ; Start ECODE segment
	 assume  cs:PGROUP

	 extrn	 EMM_EXIT1:near
	 extrn	 FCHECK_INP_NOQPI:far
	 extrn	 FCHECK_OUT_NOQPI:far
	 extrn	 FWRAP_ENABLE:far
	 extrn	 FVCPI_ALLOC:far
	 extrn	 FVCPI_DEALLOC:far
	 extrn	 FVCPI_COUNT:far
	 extrn	 FWRAP_DISABLE:far
	 extrn	 FSET_PPL0STK:far

ECODE	 ends			; End ECODE segment


EDATA	 segment use16 dword public 'edata' ; Start EDATA segment
	 assume  ds:PGROUP

	 extrn	 SEL_DS3:word
	 extrn	 SEL_4GB3:word
	 extrn	 SEL_DSJG3:word
	 extrn	 HIMEM_CS:word
	 extrn	 PCURTSS:dword
	 extrn	 HARDCNT:word
	 extrn	 PIOBIT:dword
	 extrn	 IOTRAP_TYP:dword
	 extrn	 QPI_NPORT:word
	 extrn	 FRAME:word
	 extrn	 NPHYS16S:byte
	 extrn	 PPHYS2SEG:dword
	 extrn	 PRGPDT:dword
	 extrn	 PDTLEN:dword
	 extrn	 POVR_MAC:word
	 extrn	 SYSROM_START:word
	 extrn	 TOTSIZE:dword
	 extrn	 EMMSIZE:dword
	 extrn	 PRGSIZE:word
	 extrn	 OVRSIZE:word
	 extrn	 OFFCR3:dword
	 extrn	 PDTDIR2:dword
	 extrn	 PPDT1MB:dword
	 extrn	 PPDTPDIR:dword
	 extrn	 PaDIR2:dword
	 extrn	 HMAP:byte
	 extrn	 HP_LAST:dword
	 extrn	 PHNDLPAGE:dword
	 extrn	 PPAGELINK:dword
	 extrn	 PLINKBASE:dword

EDATA	 ends			; End EDATA segment


JDATA	 segment use16 dword public 'jcode' ; Start JDATA segment
	 assume  ds:JGROUP

@QPI_MAX equ	 128		; # I/O ports QPI clients may trap

	 public  QPI_CB,QPI_PORT,QPI_OWN
QPI_CB	 dd	 0		; I/O trap callback (Seg:Off in VM), 0 = none
QPI_PORT dw	 @QPI_MAX dup (?) ; I/O ports trapped via QPI (QPI_NPORT of them)
QPI_OWN  db	 @QPI_MAX dup (?) ; 1 = I/O permission bit was set already

	 public  QPI_DIR,QPI_DIRLEN
QPI_DIR  db	 65 dup (0)	; Directory of 386MAX.SYS (QMAX_ARG), for 1E03h
QPI_DIRLEN dw	 0		; Its length
QPI_DRVNAME db	 '386MAX.SYS'   ; Driver file name, for 1E04h
@QPI_DRVLEN equ  $-QPI_DRVNAME	; Its length

QPI_DVX  dd	 0		; 22h:  DV/X shared pool control block (Seg:Off)
QPI_QUOTA dd	 0		; 23h:  VCPI quota DWORD (Seg:Off), 0 = unlimited
QPI_W28  dw	 0		; 28h:  EMM import structure word

@QPI_NDEF equ	 110h		; # pages with a default PTE (0-10FFFFh)
QPI_DEFOK db	 0		; 1 = QPI_DEFPTE is filled in
QPI_DEFPTE dd	 @QPI_NDEF dup (?) ; Default PTEs (0Fh), taken at the first call

; 22h control block
DVX_STR  struc
DVX_PREV dd	 ?		; 00:  Previous block (Seg:Off)
DVX_FREE dd	 ?		; 04:  Our # free 4KB pages
DVX_GIVE dd	 ?		; 08:  # pages the owner can give back
	 dd	 ?		; 0C:  (reserved)
DVX_ARG  dd	 ?		; 10:  Request argument/result
DVX_FLAG db	 ?		; 14:  Flags (bit 2 = superseded)
DVX_VER  db	 ?		; 15:  Version (02h)
DVX_STR  ends

@DVX_OLD equ	 04h		; DVX_FLAG:  superseded by a newer block

JDATA	 ends			; End JDATA segment


JCODE	 segment use16 dword public 'jcode' ; Start JCODE segment
	 assume  cs:JGROUP

	 extrn	 PHYS2LIN:near

	 public  @QMAX_QPI_JCODE
@QMAX_QPI_JCODE:		; Mark module start in .MAP file

	 FPPROC  QPI_CHECK -- Check For QPI I/O Trapping
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:PGROUP
COMMENT|

Check for an I/O port trapped via QPI and call the QPI callback.

On entry:

BL	 =	 0 for input, @IOTRAP_OUT for output
DX	 =	 I/O port #
IOTRAP_TYP =	 I/O width
SS:EBP	 ==>	 Caller's INTXX_STR

On exit:

CF	 =	 1 if the callback handled it
	 =	 0 if not (EAX unchanged)
AL/AX/EAX =	 input value supplied by the callback

BX	 =	 undefined

|

	 cmp	 QPI_CB,0	; Izit a callback installed?
	 je	 short QPI_CHECK_NO ; Jump if not

	 test	 [ebp].INTXX_EFL,mask $VMHI ; Izit from VM?
	 jz	 short QPI_CHECK_NO ; Jump if not

	 REGSAVE <eax,ecx,edi>	; Save registers

	 call	 QPI_FIND	; Return with CF=0 if trapped via QPI
	 jc	 short QPI_CHECK_XFOUND ; Jump if not

	 mov	 ecx,IOTRAP_TYP ; Get the I/O type
	 and	 ecx,@IOTRAP_WID ; Isolate the width
	 shl	 ecx,3		; Shift to QPI's position (bits 3-4)
	 or	 cl,bl		; Include the direction

	 mov	 eax,[ebp].INTXX_EAX ; Pass caller's EAX (the value if output)
	 call	 QPI_CALLVM	; Call the callback, EAX = value

; As QEMM 97, the callback's CF is ignored:  the callback does the I/O
; (itself or via 1A04h/1A05h).  RBIL's "CF=1 = not handled" would make us
; do the access a second time, with programs written for QEMM, whose
; callbacks return with any CF.

	 mov	 [esp+2*4],eax	; Return the value as EAX

	 REGREST <edi,ecx,eax>	; Restore

	 stc			; Indicate it's been handled

	 ret			; Return to caller

QPI_CHECK_XFOUND:
	 REGREST <edi,ecx,eax>	; Restore
QPI_CHECK_NO:
	 clc			; Indicate not handled

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_CHECK endp			; End QPI_CHECK procedure
	 NPPROC  QPI_FIND -- Find I/O Port Trapped Via QPI
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:PGROUP
COMMENT|

Find an I/O port in the table of ports trapped via QPI.

On entry:

DX	 =	 I/O port #

On exit:

CF	 =	 0 if found
	 =	 1 if not
EDI	 =	 index into QPI_PORT and QPI_OWN (if found)

|

	 REGSAVE <cx>		; Save register

	 mov	 cx,QPI_NPORT	; Get # trapped I/O ports
	 xor	 edi,edi	; Start with the first one
	 jcxz	 QPI_FIND_NO	; Jump if none
@@:
	 cmp	 dx,QPI_PORT[edi*2] ; Izit this one?
	 je	 short QPI_FIND_EXIT ; Jump if so (note CF=0)

	 inc	 edi		; Skip to next entry

	 loop	 @B		; Jump if more entries to check
QPI_FIND_NO:
	 stc			; Indicate not found
QPI_FIND_EXIT:
	 REGREST <cx>		; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_FIND endp			; End QPI_FIND procedure
	 NPPROC  QPI_CALLVM -- Call QPI Callback in VM
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:PGROUP
COMMENT|

Call the QPI I/O trap callback in VM the way HARDINT calls a VM
interrupt handler:  the callback's RETF goes to HARDRET whose INT 0FFh
lands in INTFF which strips the stack back to the HARDINT_STR return
frame built here and returns to QPI_CALLVM_RET with the callback's EAX
and flags.

The callback gets (as with QEMM)

EAX	 =	 caller's EAX (with the value if output)
CL	 =	 I/O type (bit 2 = output, bits 3-4 = width)
CH	 =	 bit 1 = caller's IF
DX	 =	 I/O port #

and runs with interrupts disabled.  It returns with

AL/AX/EAX =	 input value

(CF is ignored by QPI_CHECK, as by QEMM 97.)

On entry:

EAX, CL, DX as above
SS:EBP	 ==>	 Caller's INTXX_STR (from VM)

On exit:

CF	 =	 callback's CF
EAX	 =	 callback's EAX

All other registers preserved.

|

	 pushad 		; Save all EGP registers
	 mov	 ebx,esp	; SS:EBX ==> PUSHAD frame

; Setup the return frame for INTFF (see HARDINT_STR)

	 pushfd 		; Return EFL
	 PUSHW	 0		; Interrupt # (unused)
	 PUSHW	 cs		; Return CS
	 push	 dword ptr (offset JGROUP:QPI_CALLVM_RET) ; Return EIP

	 REGSAVE <ds,es,fs,gs>	; Save (restored by INTFF)

	 mov	 ds,SEL_DS3	; Get PGROUP data selector at PL3
	 assume  ds:PGROUP	; Tell the assembler about it

	 inc	 HARDCNT	; Count in another nesting level (INTFF counts out)

	 push	 GLB_FLAG	; Save (restored by INTFF)

	 FIXICALL PGROUP:FWRAP_ENABLE,DTE_CS2 ; Ensure 1MB wrap enabled

	 mov	 eax,PCURTSS	; Get offset in PGROUP of current TSS
	 push	 PGROUP:[eax].TSS_SS0  ; Save old stack selector
	 push	 PGROUP:[eax].TSS_ESP0 ; Save pointer to stack top

; Save SS:ESP as new top of stack pointer for faults from the callback

	 mov	 PGROUP:[eax].TSS_SS0,ss ; Save for next time
	 mov	 PGROUP:[eax].TSS_ESP0,esp ; ...

	 cli			; Disallow interrupts

	 FIXICALL PGROUP:FSET_PPL0STK,DTE_CS2 ; Set PPL0STK... pointers

; Put the return address HIMEM_CS:HARDRET on the caller's VM stack

	 movzx	 esi,[ebp].INTXX_SS ; Get caller's stack segment
	 shl	 esi,4-0	; Convert from paras to bytes
	 movzx	 edi,[ebp].INTXX_ESP.ELO ; Get caller's stack pointer
	 sub	 di,type VECTOR ; Make room for the return address

	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 mov	 AGROUP:[esi+edi].VOFF,offset PGROUP:HARDRET ; Return offset
	 mov	 ax,HIMEM_CS	; Get segment of high DOS memory
	 mov	 AGROUP:[esi+edi].VSEG,ax ; Return segment

; Setup the stack to IRETD to the callback in VM

	 movzx	 eax,[ebp].INTXX_GS ; Get caller's GS
	 push	 eax		; Pass as dword
	 movzx	 eax,[ebp].INTXX_FS ; Get caller's FS
	 push	 eax		; Pass as dword
	 movzx	 eax,[ebp].INTXX_DS ; Get caller's DS
	 push	 eax		; Pass as dword
	 movzx	 eax,[ebp].INTXX_ES ; Get caller's ES
	 push	 eax		; Pass as dword
	 movzx	 eax,[ebp].INTXX_SS ; Get caller's SS
	 push	 eax		; Pass as dword
	 push	 edi		; Pass ESP with the return address

	 mov	 eax,[ebp].INTXX_EFL ; Get caller's flags
	 and	 eax,not ((mask $RFHI) or (mask $IOPL) or (mask $IF) or (mask $TF)) ; RF=IOPL=IF=TF=0
	 or	 eax,(mask $VMHI) or (@VMIOPL shl $IOPL) ; VM=1, IOPL=@VMIOPL
	 push	 eax		; Pass EFL

	 movzx	 eax,QPI_CB.VSEG ; Get callback's segment
	 push	 eax		; Pass CS as dword
	 movzx	 eax,QPI_CB.VOFF ; Get callback's offset
	 push	 eax		; Pass EIP

; Setup the callback's registers

	 mov	 ecx,ss:[ebx+6*4] ; Get the I/O type (ECX)
	 mov	 eax,[ebp].INTXX_EFL ; Get caller's flags
	 and	 eax,mask $IF	; Isolate IF
	 or	 ecx,eax	; Pass it in CH bit 1
	 mov	 edx,ss:[ebx+5*4] ; Get the I/O port # (EDX)
	 mov	 eax,ss:[ebx+7*4] ; Get the value (EAX)

	 mov	 ebx,[ebp].INTXX_EBX ; Pass caller's remaining registers
	 mov	 esi,[ebp].INTXX_ESI ; ...
	 mov	 edi,[ebp].INTXX_EDI ; ...
	 mov	 ebp,[ebp].INTXX_EBP ; ...

	 iretd			; Call the callback in VM

QPI_CALLVM_RET:
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:PGROUP

; INTFF returns here with the callback's EAX and flags

	 mov	 [esp+7*4],eax	; Return callback's EAX

	 popad			; Restore all EGP registers

	 ret			; Return to caller with CF significant

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_CALLVM endp 		; End QPI_CALLVM procedure
	 NPPROC  QPI_UNTRAPIN -- Untrapped Input From I/O Port
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:PGROUP
COMMENT|

Read from an I/O port, bypassing the QPI callback, but not 386MAX's own
virtualization (DMA, A20, ...).

On entry:

ECX	 =	 I/O width (@IOTRAP_DB, @IOTRAP_DW, or @IOTRAP_DD)
DX	 =	 I/O port #
SS:EBP	 ==>	 Caller's INTXX_STR

On exit:

AL/AX/EAX =	 value read

|

	 REGSAVE <ebx,ecx,edx,esi,edi,ds,es,fs,gs> ; Save registers

	 mov	 IOTRAP_TYP,ecx ; Mark as input of this width

; 386MAX's own virtualization only applies while the port's bit is set
; in the I/O permission bit map (e.g. CHECK3B5INP clears it after the
; first access, from then on the port goes to the hardware)

	 movzx	 esi,dx 	; Copy the I/O port #
	 mov	 ebx,PIOBIT	; Get offset in PGROUP of I/O bit map
	 bt	 PGROUP:[ebx],esi ; Izit trapped?
	 jnc	 short QPI_UNTRAPIN_HW ; Jump if not

	 push	 ecx		; Save width
	 push	 edx		; ...  port
	 FIXICALL PGROUP:FCHECK_INP_NOQPI,DTE_CS2 ; Check on I/O port inputs
				; Return with CF=1 if value supplied in EAX
	 pop	 edx		; Restore
	 pop	 ecx		; ...
	 jc	 short QPI_UNTRAPIN_EXIT ; Jump if value supplied
QPI_UNTRAPIN_HW:
	 cmp	 cl,@IOTRAP_DW	; Izit word I/O?
	 je	 short QPI_UNTRAPIN_DW ; Jump if so
	 ja	 short QPI_UNTRAPIN_DD ; Jump if dword I/O

	 in	 al,dx		; Read byte

	 jmp	 short QPI_UNTRAPIN_EXIT ; Join common exit code

QPI_UNTRAPIN_DW:
	 in	 ax,dx		; Read word

	 jmp	 short QPI_UNTRAPIN_EXIT ; Join common exit code

QPI_UNTRAPIN_DD:
	 in	 eax,dx 	; Read dword
QPI_UNTRAPIN_EXIT:
	 REGREST <gs,fs,es,ds,edi,esi,edx,ecx,ebx> ; Restore
	 assume  ds:nothing,es:nothing ; Tell the assembler about it
	 assume  fs:nothing,gs:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_UNTRAPIN endp		; End QPI_UNTRAPIN procedure
	 NPPROC  QPI_UNTRAPOUT -- Untrapped Output To I/O Port
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:PGROUP
COMMENT|

Write to an I/O port, bypassing the QPI callback, but not 386MAX's own
virtualization (DMA, A20, ...).

On entry:

EAX	 =	 value to write
ECX	 =	 I/O width (@IOTRAP_DB, @IOTRAP_DW, or @IOTRAP_DD)
DX	 =	 I/O port #
SS:EBP	 ==>	 Caller's INTXX_STR

|

	 REGSAVE <eax,ebx,ecx,edx,esi,edi,ds,es,fs,gs> ; Save registers

	 push	 [ebp].INTXX_EAX ; Save caller's EAX
	 mov	 [ebp].INTXX_EAX,eax ; Pass the value as the caller's

	 mov	 IOTRAP_TYP,ecx ; Mark as I/O of this width

; 386MAX's own virtualization only applies while the port's bit is set
; in the I/O permission bit map (e.g. CHECK3B5INP clears it after the
; first access, from then on the port goes to the hardware)

	 movzx	 esi,dx 	; Copy the I/O port #
	 mov	 ebx,PIOBIT	; Get offset in PGROUP of I/O bit map
	 bt	 PGROUP:[ebx],esi ; Izit trapped?
	 jnc	 short QPI_UNTRAPOUT_HW ; Jump if not

	 push	 ecx		; Save width
	 push	 edx		; ...  port
	 push	 eax		; ...  value
	 FIXICALL PGROUP:FCHECK_OUT_NOQPI,DTE_CS2 ; Check on I/O port outputs
				; Return with CF=1 if already done
	 pop	 eax		; Restore
	 pop	 edx		; ...
	 pop	 ecx		; ...
	 jc	 short QPI_UNTRAPOUT_EXIT ; Jump if already done

QPI_UNTRAPOUT_HW:
	 cmp	 cl,@IOTRAP_DW	; Izit word I/O?
	 je	 short QPI_UNTRAPOUT_DW ; Jump if so
	 ja	 short QPI_UNTRAPOUT_DD ; Jump if dword I/O

	 out	 dx,al		; Write byte

	 jmp	 short QPI_UNTRAPOUT_EXIT ; Join common exit code

QPI_UNTRAPOUT_DW:
	 out	 dx,ax		; Write word

	 jmp	 short QPI_UNTRAPOUT_EXIT ; Join common exit code

QPI_UNTRAPOUT_DD:
	 out	 dx,eax 	; Write dword
QPI_UNTRAPOUT_EXIT:
	 pop	 [ebp].INTXX_EAX ; Restore caller's EAX

	 REGREST <gs,fs,es,ds,edi,esi,edx,ecx,ebx,eax> ; Restore
	 assume  ds:nothing,es:nothing ; Tell the assembler about it
	 assume  fs:nothing,gs:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_UNTRAPOUT endp		; End QPI_UNTRAPOUT procedure
	 NPPROC  QPI_DEFSNAP -- Take The Default PTEs
	 assume  ds:PGROUP,es:JGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Copy the PTEs of 0-10FFFFh (with the 1MB wrap disabled) into QPI_DEFPTE
for 0Fh.  Called at the first QPI call, i.e. with 386MAX's own mapping
(we keep no other copy of it).

|

	 REGSAVE <eax,ecx,esi,edi> ; Save registers

	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap (pages 100-10F)

	 mov	 esi,PRGPDT	; DS:ESI ==> the PTEs
	 lea	 edi,QPI_DEFPTE ; ES:EDI ==> the copy
	 mov	 ecx,@QPI_NDEF	; # PTEs
S32  rep movs	 <QPI_DEFPTE[edi],PGROUP:[esi].EDD> ; Copy them

	 mov	 es:QPI_DEFOK,1 ; Mark as filled in

	 REGREST <edi,esi,ecx,eax> ; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_DEFSNAP endp		; End QPI_DEFSNAP procedure


	 NPPROC  QPI_PT2LIN -- Linear Address Of A Page Table
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

EBX	 =	 physical address of a page table

On exit:

CF	 =	 0 if addressable, EBX = its linear address
	 =	 1 if not

Our own table for 0-4MB (PaDIR2) is outside the range PHYS2LIN
searches; it's always mapped at PPDTPDIR shl 10.

|

	 cmp	 ebx,PaDIR2	; Izit our own table?
	 jne	 short @F	; Jump if not

	 mov	 ebx,PPDTPDIR	; Get offset in PDT of its PTE
	 shl	 ebx,12-2	; Convert from 4KB in dwords to bytes (CF=0)

	 ret			; Return to caller

@@:
	 call	 PHYS2LIN	; EBX = linear address, CF=1 if none

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_PT2LIN endp 		; End QPI_PT2LIN procedure


	 NPPROC  QPI_SEG2LIN -- Convert Seg:Off To Linear Address
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On entry:

EBX	 =	 Seg:Off (segment in the high word)

On exit:

EBX	 =	 linear address

|

	 push	 eax		; Save for a moment

	 movzx	 eax,bx 	; Copy offset
	 shr	 ebx,16 	; Shift down the segment
	 shl	 ebx,4-0	; Convert from paras to bytes
	 add	 ebx,eax	; Plus offset

	 pop	 eax		; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_SEG2LIN endp		; End QPI_SEG2LIN procedure


	 FPPROC  QPI_API -- QEMM Programming Interface Functions
	 assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:PGROUP
COMMENT|

QPI functions, jumped to from INTFE (QMAX_VCP), the old VCPI entry
point returned by INT 67h AH=3Fh, CX='QE', DX='MM' and by INT 2Fh
AX=1684h, BX=4354h and by INT 2Fh AX=D201h.  Supported:

AH	 =	 00h	 Get state (AL = 0:  ON)
	 =	 01h	 Set state (OFF refused)
	 =	 03h	 Get version (AX = BX = 0703h)
	 =	 04h	 Allocate a 4KB page (EDX = physical page #)
	 =	 05h	 Free the 4KB page DX
	 =	 06h	 Clone the active page table into page DX
	 =	 07h	 Get the active page table (DX)
	 =	 08h	 Make page table DX active (mapping context)
	 =	 09h	 Get the page frame of PTE CX (DX)
	 =	 0Ah	 Set ...		 (PTE = DX shl 12 or 7)
	 =	 0Bh	 Map EMS handle DX at page CX (BX 16KB pages)
	 =	 0Ch	 Get available memory (QMAX_VCP, the old 0Ch too)
	 =	 0Fh	 Restore default PTEs CX..CX+DX-1 (AL = dirty)
	 =	 10h	 Old VCPI functions (QMAX_VCP)
	 =	 11h	 Get memory type map (256 bytes at ES:DI)
	 =	 12h	 Get HIRAM chain (BX = first high DOS MCB)
AX	 =	 1600h	 Get memory access status (256 bytes at ES:DI)
	 =	 1601h	 Set ...
AH	 =	 17h	 Get memory usage statistics (81 bytes at ES:DI)
	 =	 18h	 Is conventional memory mapped at ES:BX for CX pages?
AX	 =	 1A00h	 Untrapped IN  AL,DX (result in BL)
	 =	 1A01h	 Untrapped OUT DX,BL
	 =	 1A02h	 Untrapped OUT DX,BH; IN BL,DX+1
	 =	 1A03h	 Untrapped OUT DX,BH; OUT DX+1,BL
	 =	 1A04h	 Untrapped I/O (CX = flags, EBX = value)
	 =	 1A05h	 Virtualized I/O (the same)
	 =	 1A06h	 Get I/O trap callback (ES:DI, default QPI_DEFCB)
	 =	 1A07h	 Set I/O trap callback (ES:DI)
	 =	 1A08h	 Get port DX trap status (BL)
	 =	 1A09h	 Trap port DX
	 =	 1A0Ah	 Untrap port DX
	 =	 1B05h	 Is the file DS:DX a Windows driver (.DRV, GDI.EXE)?
	 =	 1B07h	 Windows import pointer set? (AL = 0)
	 =	 1E00h	 Stealth configuration (none)
	 =	 1E01h	 # Stealth'ed ROMs (none)
	 =	 1E02h	 Stealth ROM list (none)
	 =	 1E03h	 Directory of the driver into ES:DI (BX = length)
	 =	 1E04h	 File name of the driver ...
	 =	 1F00h	 Get PTE of page CX (0-3FFh) into EDX
	 =	 1F01h	 Set ...
	 =	 1F02h	 Get CR0
	 =	 1F03h	 Change CR0.MP/EM/ET
	 =	 2000h	 Get VirtualHDIRQ state (not supported)
	 =	 2001h	 Set ...		 (ignored)
	 =	 2200h	 Get DV/X shared pool control block (ES:DI)
	 =	 2201h	 Register ...
	 =	 2300h	 Get VCPI quota pointer of slot BX (ES:DI)
	 =	 2301h	 Set ...
	 =	 2302h	 Clear ...
	 =	 23FFh	 Reset ...
AH	 =	 28h	 Set the EMM import word (BX)
AX	 =	 2A00h	 Get ANALYSIS bitmap (32 bytes at ES:DI, empty)
	 =	 2A01h	 ...
	 =	 4D00h	 Query Open MaxView extension
	 =	 4D01h	 Get backend/root-context status

On entry:

AX	 =	 function #
SS:EBP	 ==>	 INTXX_STR

On exit:

Caller's CF =	 0 if successful
	    =	 1 if not

|

	 mov	 es,SEL_DSJG3	; Get JGROUP data selector at PL3
	 assume  es:JGROUP	; Tell the assembler about it

	 or	 [ebp].INTXX_EFL,mask $CF ; Assume failure

	 cmp	 es:QPI_DEFOK,0 ; Do we have the default PTEs?
	 jne	 short @F	; Jump if so

	 call	 QPI_DEFSNAP	; Take them now
@@:
	 mov	 ax,[ebp].INTXX_EAX.ELO ; Get the function # again
	 mov	 dx,[ebp].INTXX_EDX.ELO ; Get the I/O port #

	 cmp	 ah,@MV_API	; Izit Open MaxView extension?
	 je	 near ptr QPI_API_MV ; Jump if so

	 cmp	 ah,00h 	; Izit Get State?
	 je	 near ptr QPI_API_STATE ; Jump if so

	 cmp	 ah,01h 	; Izit Set State?
	 je	 near ptr QPI_API_SETST ; Jump if so

	 cmp	 ah,03h 	; Izit Get Version?
	 je	 near ptr QPI_API_VER ; Jump if so
	 cmp	 ah,04h 	; Izit Allocate 4KB Page?
	 je	 near ptr QPI_API_ALLOC ; Jump if so
	 cmp	 ah,05h 	; Izit Free 4KB Page?
	 je	 near ptr QPI_API_FREE ; Jump if so
	 cmp	 ah,09h 	; Izit Get PTE Frame?
	 je	 near ptr QPI_API_GETFRM ; Jump if so
	 cmp	 ah,0Ah 	; Izit Set PTE Frame?
	 je	 near ptr QPI_API_SETFRM ; Jump if so
	 cmp	 ah,06h 	; Izit Clone Page Table?
	 je	 near ptr QPI_API_CLONE ; Jump if so
	 cmp	 ah,07h 	; Izit Get Mapping Context?
	 je	 near ptr QPI_API_GETCTX ; Jump if so
	 cmp	 ah,08h 	; Izit Set Mapping Context?
	 je	 near ptr QPI_API_SETCTX ; Jump if so
	 cmp	 ah,0Bh 	; Izit Map EMS Handle?
	 je	 near ptr QPI_API_MAPH ; Jump if so
	 cmp	 ah,0Fh 	; Izit Restore Default Mapping?
	 je	 near ptr QPI_API_UNMAP ; Jump if so

	 cmp	 ah,0Ch 	; Izit Get Available Memory?
	 je	 near ptr QPI_API_AVAIL ; Jump if so

	 cmp	 ah,11h 	; Izit Get Memory Type Map?
	 je	 near ptr QPI_API_TYPES ; Jump if so

	 cmp	 ah,12h 	; Izit Get HIRAM Chain?
	 je	 near ptr QPI_API_HIRAM ; Jump if so

	 cmp	 ah,16h 	; Izit Get/Set Memory Access Status?
	 je	 near ptr QPI_API_ACC ; Jump if so

	 cmp	 ah,17h 	; Izit Get Memory Usage Statistics?
	 je	 near ptr QPI_API_STAT17 ; Jump if so

	 cmp	 ah,18h 	; Izit Check Conventional Memory Mapping?
	 je	 near ptr QPI_API_CONV ; Jump if so

	 cmp	 ah,1Bh 	; Izit Windows support?
	 je	 near ptr QPI_API_WIN ; Jump if so

	 cmp	 ah,1Eh 	; Izit Stealth information?
	 je	 near ptr QPI_API_STEALTH ; Jump if so

	 cmp	 ah,1Fh 	; Izit Get/Set PTE?
	 je	 near ptr QPI_API_PTE ; Jump if so

	 cmp	 ah,20h 	; Izit VirtualHDIRQ?
	 je	 near ptr QPI_API_VHI ; Jump if so

	 cmp	 ah,22h 	; Izit DV/X shared pool?
	 je	 near ptr QPI_API_DVX ; Jump if so

	 cmp	 ah,23h 	; Izit VCPI quota?
	 je	 near ptr QPI_API_QUOTA ; Jump if so

	 cmp	 ah,28h 	; Izit EMM import word?
	 je	 near ptr QPI_API_W28 ; Jump if so

	 cmp	 ah,2Ah 	; Izit ANALYSIS bitmaps?
	 je	 near ptr QPI_API_ANAL ; Jump if so

; Others:  CF set.  As QEMM 97 without the feature:  19h, 1Dh (NOPs),
; 21h (no Stealth), 24h (no ST-DBL), 25h (no kernel debugger), 26h (no
; VxD loader), 27h (no QuickBoot), 29h (no DISKBUF), 2Bh, 2Ch (no ANALYSIS)

	 cmp	 ah,1Ah 	; Izit I/O trapping?
	 jne	 short QPI_API_EXIT ; Jump if not

	 cmp	 al,00h 	; Izit untrapped input?
	 je	 near ptr QPI_API_IN ; Jump if so

	 cmp	 al,01h 	; Izit untrapped output?
	 je	 near ptr QPI_API_OUT ; Jump if so

	 cmp	 al,02h 	; Izit untrapped indexed input?
	 je	 near ptr QPI_API_INDEX ; Jump if so

	 cmp	 al,03h 	; Izit untrapped indexed output?
	 je	 near ptr QPI_API_INDEX ; Jump if so

	 cmp	 al,04h 	; Izit untrapped I/O?
	 je	 near ptr QPI_API_IO ; Jump if so

	 cmp	 al,05h 	; Izit virtualized I/O?
	 je	 near ptr QPI_API_IO ; Jump if so (the same, see QPI_UNTRAPIN)

	 cmp	 al,06h 	; Izit get callback?
	 je	 near ptr QPI_API_GETCB ; Jump if so

	 cmp	 al,07h 	; Izit set callback?
	 je	 near ptr QPI_API_SETCB ; Jump if so

	 cmp	 al,08h 	; Izit get trap status?
	 je	 near ptr QPI_API_STAT ; Jump if so

	 cmp	 al,09h 	; Izit trap port?
	 je	 near ptr QPI_API_TRAP ; Jump if so

	 cmp	 al,0Ah 	; Izit untrap port?
	 je	 near ptr QPI_API_UNTRAP ; Jump if so
QPI_API_EXIT:
	 FIXIJMP PGROUP:EMM_EXIT1,DTE_CS2 ; Return to caller with CF significant

QPI_API_OK:
	 and	 [ebp].INTXX_EFL,not (mask $CF) ; Indicate success

	 jmp	 QPI_API_EXIT	; Join common exit code

QPI_API_MV:
	 cmp	 al,@MV_QUERY	; Izit ABI/capability query?
	 je	 short QPI_API_MV_QUERY ; Jump if so

	 cmp	 al,@MV_STATUS	; Izit backend status query?
	 je	 short QPI_API_MV_STATUS ; Jump if so

	 mov	 [ebp].INTXX_EAX.ELO,@MVERR_UNSUPPORTED ; Defined failure
	 jmp	 QPI_API_EXIT	; Return with CF set

QPI_API_MV_QUERY:
	 mov	 [ebp].INTXX_EAX.ELO,@MV_ABI_VERSION
	 mov	 [ebp].INTXX_EBX.ELO,@MV_SIGNATURE_1
	 mov	 [ebp].INTXX_ECX.ELO,@MV_SIGNATURE_2
	 mov	 [ebp].INTXX_EDX.ELO,@MV_CAPABILITIES
	 jmp	 QPI_API_OK

QPI_API_MV_STATUS:
	 xor	 ax,ax		; Successful status call
	 mov	 [ebp].INTXX_EAX.ELO,ax
	 mov	 [ebp].INTXX_EBX.ELO,@MV_ROOT_CONTEXT ; Current context
	 mov	 [ebp].INTXX_ECX.ELO,1 ; One active root context
	 mov	 [ebp].INTXX_EDX.ELO,1 ; One context supported for now
	 jmp	 QPI_API_OK

QPI_API_VER:
	 mov	 [ebp].INTXX_EAX.ELO,0703h ; Version 7.03
	 mov	 [ebp].INTXX_EBX.ELO,0703h ; ...

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_IN:
	 mov	 ecx,@IOTRAP_DB ; Byte I/O
	 call	 QPI_UNTRAPIN	; Return with AL = value
	 mov	 [ebp].INTXX_EBX.ELO.LO,al ; Return in caller's BL

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_OUT:
	 mov	 ecx,@IOTRAP_DB ; Byte I/O
	 movzx	 eax,[ebp].INTXX_EBX.ELO.LO ; Get caller's BL
	 call	 QPI_UNTRAPOUT	; Write it

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_IO:
	 mov	 ecx,[ebp].INTXX_ECX ; Get the I/O type
	 test	 cl,20h 	; Izit string I/O?
	 jnz	 near ptr QPI_API_EXIT ; Jump if so (not supported)

	 shr	 ecx,3		; Shift down the width
	 and	 ecx,@IOTRAP_WID ; Isolate it
	 cmp	 cl,@IOTRAP_DD	; Izit valid?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 test	 [ebp].INTXX_ECX.ELO.LO,@IOTRAP_OUT ; Izit output?
	 jnz	 short QPI_API_IOOUT ; Jump if so

	 call	 QPI_UNTRAPIN	; Return with AL/AX/EAX = value

	 mov	 [ebp].INTXX_EBX.ELO.LO,al ; Return in caller's BL

	 cmp	 cl,@IOTRAP_DB	; Izit byte I/O?
	 je	 near ptr QPI_API_OK ; Jump if so

	 mov	 [ebp].INTXX_EBX.ELO,ax ; Return in caller's BX

	 cmp	 cl,@IOTRAP_DW	; Izit word I/O?
	 je	 near ptr QPI_API_OK ; Jump if so

	 mov	 [ebp].INTXX_EBX,eax ; Return in caller's EBX

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_IOOUT:
	 mov	 eax,[ebp].INTXX_EBX ; Get caller's EBX
	 call	 QPI_UNTRAPOUT	; Write it

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_GETCB:
	 mov	 eax,QPI_CB	; Get the callback

	 or	 eax,eax	; Izit none?
	 jnz	 short @F	; Jump if not

	 mov	 ax,HIMEM_CS	; Get segment of our code in VM
	 shl	 eax,16 	; Shift to segment position
	 mov	 ax,offset PGROUP:QPI_DEFCB ; The default callback (as QEMM)
@@:
	 mov	 [ebp].INTXX_EDI.ELO,ax ; Return offset in caller's DI
	 shr	 eax,16 	; Shift down the segment
	 mov	 [ebp].INTXX_ES,ax ; Return in caller's ES

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_SETCB:
	 mov	 ax,[ebp].INTXX_ES ; Get caller's ES
	 shl	 eax,16 	; Shift to segment position
	 mov	 ax,[ebp].INTXX_EDI.ELO ; Get caller's DI

	 cmp	 ax,offset PGROUP:QPI_DEFCB ; Izit the default callback?
	 jne	 short @F	; Jump if not

	 mov	 bx,[ebp].INTXX_ES ; Get its segment again
	 cmp	 bx,HIMEM_CS	; Izit ours?
	 jne	 short @F	; Jump if not

	 xor	 eax,eax	; None (we do the I/O without the round trip)
@@:
	 mov	 es:QPI_CB,eax	; Save as the callback

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_STAT:
	 call	 QPI_FIND	; Return with CF=0 if trapped via QPI
	 setnc	 [ebp].INTXX_EBX.ELO.LO ; Return 1 in BL if trapped, 0 if not

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_TRAP:
	 call	 QPI_FIND	; Return with CF=0 if trapped via QPI
	 jnc	 near ptr QPI_API_OK ; Jump if already trapped

	 movzx	 edi,QPI_NPORT	; Get # trapped I/O ports
	 cmp	 di,@QPI_MAX	; Izit full?
	 jae	 near ptr QPI_API_EXIT ; Jump if so

	 mov	 es:QPI_PORT[edi*2],dx ; Save the I/O port #

	 movzx	 esi,dx 	; Copy the I/O port #
	 mov	 ebx,PIOBIT	; Get offset in PGROUP of I/O bit map
	 bts	 PGROUP:[ebx],esi ; Trap the I/O port
	 setc	 es:QPI_OWN[edi] ; Remember whether we trapped it already

	 inc	 QPI_NPORT	; Count in another one

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_UNTRAP:
	 call	 QPI_FIND	; Return with CF=0 if trapped via QPI
	 jc	 near ptr QPI_API_EXIT ; Jump if not

	 cmp	 QPI_OWN[edi],0 ; Did we trap it already?
	 jne	 short @F	; Jump if so

	 movzx	 esi,dx 	; Copy the I/O port #
	 mov	 ebx,PIOBIT	; Get offset in PGROUP of I/O bit map
	 btr	 PGROUP:[ebx],esi ; Untrap the I/O port
@@:

; Move the last entry into this one's place

	 dec	 QPI_NPORT	; Count out this one
	 movzx	 esi,QPI_NPORT	; Get index of the last entry
	 mov	 ax,QPI_PORT[esi*2] ; Get its I/O port #
	 mov	 es:QPI_PORT[edi*2],ax ; Save in this one's place
	 mov	 al,QPI_OWN[esi] ; Get its flag
	 mov	 es:QPI_OWN[edi],al ; Save in this one's place

	 jmp	 QPI_API_OK	; Join common exit code

; Caller's ES:DI as linear address in EDI (for AGROUP)

QPI_ESDI macro
	 movzx	 eax,[ebp].INTXX_ES ; Get caller's ES
	 shl	 eax,4-0	; Convert from paras to bytes
	 movzx	 edi,[ebp].INTXX_EDI.ELO ; Get caller's DI
	 add	 edi,eax	; Plus segment
	 endm			; QPI_ESDI


; 0C:  Get available memory (INTFE has put the free count into EDX, which
; is what the old VCPI function 0Ch returns, with AH = 0)

QPI_API_AVAIL:
	 mov	 edx,[ebp].INTXX_EDX ; Get # free 4KB pages

	 cmp	 edx,0FFFFh	; Izit too big for DX?
	 jbe	 short @F	; Jump if not

	 mov	 edx,0FFFFh	; Use the maximum
	 mov	 [ebp].INTXX_EDX,edx ; Return in caller's EDX
@@:
	 mov	 eax,EMMSIZE	; Get EMS memory size in 1KB
	 shr	 eax,12-10	; Convert to 4KB pages

	 cmp	 eax,edx	; Izit at least the free count?
	 jae	 short @F	; Jump if so

	 mov	 eax,edx	; Use the free count
@@:
	 cmp	 eax,0FFFFh	; Izit too big for CX?
	 jbe	 short @F	; Jump if not

	 mov	 eax,0FFFFh	; Use the maximum
@@:
	 mov	 [ebp].INTXX_ECX.ELO,ax ; Total 4KB pages
	 mov	 [ebp].INTXX_EBX.ELO,1 ; BX = 1
	 mov	 [ebp].INTXX_EAX.ELO.HI,0 ; AH = 0 (old VCPI status)

	 jmp	 QPI_API_OK	; Join common exit code


QPI_API_STATE:			; 00:  Get state
	 mov	 [ebp].INTXX_EAX.ELO.LO,0 ; ON, not AUTO

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_SETST:			; 01:  Set state
	 test	 al,01h 	; Turn OFF?
	 jnz	 near ptr QPI_API_EXIT ; Jump if so (386MAX stays on)

	 jmp	 QPI_API_OK	; Join common exit code


; 11:  Get memory type map of the first megabyte (one byte per 4KB page)

QPI_API_TYPES:
	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap
	 push	 es		; Save JGROUP selector

	 QPI_ESDI		; EDI = linear address of caller's buffer
	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 movzx	 edx,AGROUP:[0413h].ELO ; Get BIOS memory size in KB
	 shl	 edx,10 	; Convert to bytes:  end of conventional memory

	 movzx	 ebx,FRAME	; Get EMS page frame segment
	 shl	 ebx,4-0	; Convert to bytes

	 xor	 ecx,ecx	; Start with page 0
QPI_API_TYPES_NXT:
	 mov	 esi,ecx	; Copy page #
	 shl	 esi,12 	; Convert to linear address

	 mov	 al,04h 	; Conventional:  excluded (the EMS-mappable pages
				; become 00h below, as QEMM 97 reports them)

	 cmp	 esi,edx	; Izit below the end of conventional memory?
	 jb	 short QPI_API_TYPES_SET ; Jump if so

	 mov	 al,09h 	; Page frame (00h below, as QEMM 97)

	 or	 ebx,ebx	; Izit an EMS page frame?
	 jz	 short @F	; Jump if not

	 mov	 eax,esi	; Copy linear address
	 sub	 eax,ebx	; Less frame start
	 cmp	 eax,64*1024	; Izit within the frame?
	 mov	 al,09h 	; Page frame
	 jb	 short QPI_API_TYPES_SET ; Jump if so
@@:
	 mov	 eax,ecx	; Copy page #
	 shl	 eax,2		; Convert to offset in PDT
	 add	 eax,PRGPDT	; Plus offset in PGROUP of PDT
	 mov	 eax,PGROUP:[eax].PDT_PTE ; Get the PTE
	 and	 ax,mask $PTE_FRM ; Isolate the frame (a word mask)

	 cmp	 eax,esi	; Izit mapped to itself?
	 je	 short QPI_API_TYPES_ID ; Jump if so

	 movzx	 eax,SYSROM_START ; Get start of system ROM
	 shr	 eax,8		; Convert from paras to pages
	 cmp	 ecx,eax	; Izit system ROM?
	 mov	 al,02h 	; Mapped ROM (shadowed)
	 jae	 short QPI_API_TYPES_SET ; Jump if so

	 mov	 al,03h 	; High RAM (option ROMs are set below)
	 jmp	 short QPI_API_TYPES_SET ; Join common code

QPI_API_TYPES_ID:

	 mov	 al,05h 	; Assume video

	 cmp	 cl,0C0h	; Izit below C000?
	 jb	 short QPI_API_TYPES_SET ; Jump if so (A000-BFFF)

	 mov	 al,06h 	; Assume system ROM

	 movzx	 eax,SYSROM_START ; Get start of system ROM
	 shr	 eax,8		; Convert from paras to pages
	 cmp	 ecx,eax	; Izit system ROM?
	 mov	 al,06h 	; System ROM
	 jae	 short QPI_API_TYPES_SET ; Jump if so

	 mov	 al,04h 	; Excluded (adapter ROMs are set below)
QPI_API_TYPES_SET:
	 mov	 AGROUP:[edi+ecx],al ; Save type

	 inc	 ecx		; Next page

	 cmp	 ecx,256	; Izit the end?
	 jb	 short QPI_API_TYPES_NXT ; Jump if not

; Mark adapter ROMs (55AAh, length in 512 bytes) in C000-EFFF

	 mov	 esi,0C0000h	; Start of adapter ROM area
QPI_API_TYPES_ROM:
	 cmp	 AGROUP:[esi].ELO,0AA55h ; Izit a ROM signature?
	 jne	 short QPI_API_TYPES_XROM ; Jump if not

	 movzx	 ecx,AGROUP:[esi+2].LO ; Get length in 512 bytes
	 shl	 ecx,9		; Convert to bytes
	 jz	 short QPI_API_TYPES_XROM ; Jump if empty

	 lea	 ecx,[esi+ecx-1] ; Last byte of the ROM
	 shr	 ecx,12 	; Convert to page #
	 mov	 eax,esi	; Copy start
	 shr	 eax,12 	; Convert to page #
@@:
	 cmp	 AGROUP:[edi+eax].LO,04h ; Izit identity-mapped (excluded)?
	 jne	 short QPI_API_TYPES_MR ; Jump if not

	 mov	 AGROUP:[edi+eax].LO,06h ; Adapter ROM:  06h (ROM), as QEMM 97

	 jmp	 short QPI_API_TYPES_XPG ; Join common code

QPI_API_TYPES_MR:
	 cmp	 AGROUP:[edi+eax].LO,03h ; Izit remapped (high RAM)?
	 jne	 short QPI_API_TYPES_XPG ; Jump if not

	 mov	 AGROUP:[edi+eax].LO,02h ; Mapped ROM (shadowed option ROM)
QPI_API_TYPES_XPG:
	 inc	 eax		; Next page

	 cmp	 eax,ecx	; Izit the last?
	 jbe	 short @B	; Jump if not
QPI_API_TYPES_XROM:
	 add	 esi,2048	; Next possible ROM start

	 cmp	 esi,0F0000h	; Izit the end of the adapter area?
	 jb	 short QPI_API_TYPES_ROM ; Jump if not

; The EMS-mappable 16KB pages, the frame as well as the conventional
; memory we map, are 00h ("mappable"), as QEMM 97 reports them

	 mov	 esi,PPHYS2SEG	; Get offset in PGROUP of PHYS2SEG
	 movzx	 ecx,NPHYS16S.ELO ; Get # physical 16KB pages in EMS system
	 jcxz	 QPI_API_TYPES_XEMS ; Jump if none
QPI_API_TYPES_EMS:
	 movzx	 eax,PGROUP:[esi].ELO ; Get its segment
	 shr	 eax,8		; Convert from paras to 4KB pages

	 cmp	 eax,256-4	; Izit within the first MB?
	 ja	 short @F	; Jump if not

	 mov	 AGROUP:[edi+eax].EDD,0 ; Its four 4KB pages are mappable
@@:
	 add	 esi,2		; Skip to the next one
	 loop	 QPI_API_TYPES_EMS ; Jump if more physical pages
QPI_API_TYPES_XEMS:

	 pop	 es		; Restore JGROUP selector
	 assume  es:JGROUP	; Tell the assembler about it

	 mov	 [ebp].INTXX_EBX.ELO.LO,0 ; BL = ???

	 jmp	 QPI_API_OK	; Join common exit code


; 12:  Get HIRAM chain

QPI_API_HIRAM:
	 mov	 ax,POVR_MAC	; Get first MCB in high DOS memory

	 cmp	 ax,-1		; Izit valid?
	 jne	 short @F	; Jump if so

	 xor	 ax,ax		; No high memory
@@:
	 mov	 [ebp].INTXX_EBX.ELO,ax ; Return in caller's BX

	 jmp	 QPI_API_OK	; Join common exit code


; 1600:  Get memory access status (bit 0 read, bit 1 written per 4KB page)
; 1601:  Set ...

QPI_API_ACC:
	 cmp	 al,01h 	; Izit a valid subfunction?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 push	 es		; Save JGROUP selector

	 QPI_ESDI		; EDI = linear address of caller's buffer
	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 xor	 ecx,ecx	; Start with page 0
QPI_API_ACC_NXT:
	 lea	 esi,[ecx*4]	; Offset of the PTE
	 add	 esi,PRGPDT	; Plus offset in PGROUP of PDT

	 cmp	 [ebp].INTXX_EAX.ELO.LO,01h ; Izit set?
	 je	 short QPI_API_ACC_SET ; Jump if so

	 mov	 eax,PGROUP:[esi].PDT_PTE ; Get the PTE
	 shr	 eax,5		; Shift Accessed (5) to bit 0, Dirty (6) to bit 1
	 and	 al,03h 	; Isolate them
	 mov	 AGROUP:[edi+ecx],al ; Save status

	 jmp	 short QPI_API_ACC_LOOP ; Join common code

QPI_API_ACC_SET:
	 movzx	 eax,AGROUP:[edi+ecx].LO ; Get new status
	 and	 al,03h 	; Isolate read/written
	 shl	 eax,5		; Shift to Accessed/Dirty
	 and	 PGROUP:[esi].PDT_PTE,not (3 shl 5) ; Clear them
	 or	 PGROUP:[esi].PDT_PTE,eax ; Set new ones
QPI_API_ACC_LOOP:
	 inc	 ecx		; Next page

	 cmp	 ecx,256	; Izit the end?
	 jb	 short QPI_API_ACC_NXT ; Jump if not

	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...

	 pop	 es		; Restore JGROUP selector
	 assume  es:JGROUP	; Tell the assembler about it

	 jmp	 QPI_API_OK	; Join common exit code


; 17:  Get memory usage statistics (81 bytes at ES:DI)

QPI_API_STAT17:
	 push	 es		; Save JGROUP selector

	 QPI_ESDI		; EDI = linear address of caller's buffer
	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 push	 edi		; Save start
	 mov	 ecx,81 	; Size of the statistics
	 xor	 al,al		; Fill with zero
S32  rep stos	 AGROUP:[edi].LO ; Clear them
	 pop	 edi		; Restore

	 movzx	 eax,AGROUP:[0413h].ELO ; Get BIOS memory size in KB
	 shl	 eax,10 	; Convert to bytes
	 mov	 AGROUP:[edi+01h],eax ; Initial conventional memory

	 mov	 eax,TOTSIZE	; Get extended memory size in KB
	 shl	 eax,10 	; Convert to bytes
	 mov	 AGROUP:[edi+05h],eax ; Initial extended memory

	 mov	 eax,EMMSIZE	; Get EMS memory size in KB
	 shl	 eax,10 	; Convert to bytes
	 mov	 AGROUP:[edi+09h],eax ; Initial expanded memory
	 mov	 AGROUP:[edi+45h],eax ; EMS/XMS pool provided

	 movzx	 eax,PRGSIZE	; Get program size in KB
	 shl	 eax,10 	; Convert to bytes
	 mov	 AGROUP:[edi+21h],eax ; Code size

	 movzx	 eax,OVRSIZE	; Get high DOS memory size in KB
	 shl	 eax,10 	; Convert to bytes
	 mov	 AGROUP:[edi+35h],eax ; High RAM

	 pop	 es		; Restore JGROUP selector
	 assume  es:JGROUP	; Tell the assembler about it

	 jmp	 QPI_API_OK	; Join common exit code


; 18:  Is conventional memory mapped into ES:BX for CX pages?

QPI_API_CONV:
	 movzx	 esi,[ebp].INTXX_ES ; Get caller's ES
	 shl	 esi,4-0	; Convert from paras to bytes
	 movzx	 eax,[ebp].INTXX_EBX.ELO ; Get caller's BX
	 add	 esi,eax	; ESI = linear start
	 and	 esi,not 0FFFh	; Round down to the page

	 movzx	 ecx,[ebp].INTXX_ECX.ELO ; Get # pages
	 mov	 [ebp].INTXX_EAX.ELO.LO,01h ; Assume all conventional
	 jecxz	 QPI_API_CONV_DONE ; Jump if none
QPI_API_CONV_NXT:
	 mov	 eax,esi	; Copy linear address
	 shr	 eax,12-2	; Convert to offset in PDT

	 cmp	 eax,PDTLEN	; Izit within the PDT?
	 jae	 short QPI_API_CONV_NO ; Jump if not

	 add	 eax,PRGPDT	; Plus offset in PGROUP of PDT
	 mov	 eax,PGROUP:[eax].PDT_PTE ; Get the PTE
	 and	 ax,mask $PTE_FRM ; Isolate the frame (a word mask)

	 cmp	 eax,esi	; Izit mapped to itself?
	 jne	 short QPI_API_CONV_NO ; Jump if not

	 add	 esi,4096	; Next page
	 loop	 QPI_API_CONV_NXT ; Jump if more

	 jmp	 short QPI_API_CONV_DONE ; Join common code

QPI_API_CONV_NO:
	 mov	 [ebp].INTXX_EAX.ELO.LO,00h ; Some page is remapped
QPI_API_CONV_DONE:
	 jmp	 QPI_API_OK	; Join common exit code


; 1A02:  OUT DX,BH; IN BL,DX+1 (untrapped)
; 1A03:  OUT DX,BH; OUT DX+1,BL (untrapped)

QPI_API_INDEX:
	 mov	 ecx,@IOTRAP_DB ; Byte I/O
	 movzx	 eax,[ebp].INTXX_EBX.ELO.HI ; Get caller's BH
	 call	 QPI_UNTRAPOUT	; Write the index

	 inc	 dx		; Next port
	 mov	 ecx,@IOTRAP_DB ; Byte I/O

	 cmp	 [ebp].INTXX_EAX.ELO.LO,03h ; Izit write?
	 je	 short @F	; Jump if so

	 call	 QPI_UNTRAPIN	; Return with AL = value
	 mov	 [ebp].INTXX_EBX.ELO.LO,al ; Return in caller's BL

	 jmp	 QPI_API_OK	; Join common exit code

@@:
	 movzx	 eax,[ebp].INTXX_EBX.ELO.LO ; Get caller's BL
	 call	 QPI_UNTRAPOUT	; Write the data

	 jmp	 QPI_API_OK	; Join common exit code


; 1B05:  Is the ASCIIZ filename at DS:DX a Windows driver?

QPI_API_WIN:
	 cmp	 al,07h 	; Izit Windows import pointer query?
	 jne	 short @F	; Jump if not

	 mov	 [ebp].INTXX_EAX.ELO.LO,0 ; None (no EMM import record)

	 jmp	 QPI_API_OK	; Join common exit code
@@:
	 cmp	 al,05h 	; Izit determine driver?
	 jne	 near ptr QPI_API_EXIT ; Jump if not (no QEMM Windows support)

	 push	 es		; Save JGROUP selector

	 movzx	 esi,[ebp].INTXX_DS ; Get caller's DS
	 shl	 esi,4-0	; Convert from paras to bytes
	 movzx	 eax,[ebp].INTXX_EDX.ELO ; Get caller's DX
	 add	 esi,eax	; ESI = linear address of the name
	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 mov	 edi,esi	; Find the end
@@:
	 cmp	 AGROUP:[edi].LO,0 ; Izit the end?
	 je	 short @F	; Jump if so

	 inc	 edi		; Next byte

	 mov	 eax,edi	; Copy current
	 sub	 eax,esi	; Less start
	 cmp	 eax,128	; Izit too long?
	 jb	 short @B	; Jump if not
@@:
	 mov	 eax,edi	; Copy end
	 sub	 eax,esi	; Less start = length
	 mov	 bl,0		; Assume neither

	 cmp	 eax,4		; Long enough for ".DRV"?
	 jb	 short QPI_API_WIN_DONE ; Jump if not

	 mov	 eax,AGROUP:[edi-4] ; Get the last four bytes
	 and	 eax,0DFDFDFFFh ; Upper case (not the dot)
	 cmp	 eax,'VRD.'     ; Izit ".DRV"?
	 mov	 bl,01h 	; Driver
	 je	 short QPI_API_WIN_DONE ; Jump if so

	 mov	 bl,0		; Assume neither

	 mov	 eax,edi	; Copy end
	 sub	 eax,esi	; Less start = length
	 cmp	 eax,7		; Long enough for "GDI.EXE"?
	 jb	 short QPI_API_WIN_DONE ; Jump if not

	 mov	 eax,AGROUP:[edi-7] ; Get "GDI."
	 and	 eax,0FFDFDFDFh ; Upper case (not the dot)
	 cmp	 eax,'.IDG'     ; Izit "GDI."?
	 jne	 short QPI_API_WIN_DONE ; Jump if not

	 mov	 eax,AGROUP:[edi-4] ; Get ".EXE"
	 and	 eax,0DFDFDFFFh ; Upper case (not the dot)
	 cmp	 eax,'EXE.'     ; Izit ".EXE"?
	 jne	 short QPI_API_WIN_DONE ; Jump if not

	 cmp	 edi,esi	; Izit just "GDI.EXE" or a path?
	 je	 short @F	; Jump if just the name

	 mov	 al,AGROUP:[edi-8] ; Get the character before
	 cmp	 al,'\'         ; Izit a path separator?
	 je	 short @F	; Jump if so

	 cmp	 al,':'         ; Izit a drive?
	 jne	 short QPI_API_WIN_DONE ; Jump if not
@@:
	 mov	 bl,0FFh	; GDI.EXE
QPI_API_WIN_DONE:
	 pop	 es		; Restore JGROUP selector
	 assume  es:JGROUP	; Tell the assembler about it

	 mov	 [ebp].INTXX_EAX.ELO.LO,bl ; Return status in AL

	 jmp	 QPI_API_OK	; Join common exit code


; 1E00:  Stealth configuration (none)
; 1E01:  # Stealth'ed ROMs (none)
; 1E02:  Stealth ROM list (none)

QPI_API_STEALTH:
	 cmp	 al,02h 	; Izit a Stealth subfunction?
	 ja	 near ptr QPI_API_NAME ; Jump if not

	 xor	 eax,eax	; Nothing
	 mov	 [ebp].INTXX_EBX.ELO,ax ; BL = flags, BH = disk buffer flags / BX = count
	 mov	 [ebp].INTXX_ECX.ELO,ax ; CL = Stealth type, CH = interrupt

	 cmp	 [ebp].INTXX_EAX.ELO.LO,00h ; Izit configuration?
	 jne	 near ptr QPI_API_OK ; Jump if not

	 mov	 [ebp].INTXX_EDX.ELO,ax ; DL = disk buffer size, DH = reserved
	 mov	 [ebp].INTXX_ESI.ELO,ax ; Reserved
	 mov	 [ebp].INTXX_EDI.ELO,ax ; ...

	 jmp	 QPI_API_OK	; Join common exit code


; 1E03:  Get directory of the driver ("C:\386MAX\") into ES:DI
; 1E04:  Get file name of the driver ("386MAX.SYS") ...
; As QEMM 97:  not NUL-terminated, BX = length, DI advanced by BX.
; 1E05:  CF=1 (disabled in QEMM 97)

QPI_API_NAME:
	 cmp	 al,04h 	; Izit a valid subfunction?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 lea	 si,QPI_DRVNAME ; JGROUP:SI ==> driver file name
	 mov	 cx,@QPI_DRVLEN ; CX = its length
	 je	 short @F	; Jump if 1E04h

	 lea	 si,QPI_DIR	; JGROUP:SI ==> directory
	 mov	 cx,QPI_DIRLEN	; CX = its length
@@:
	 QPI_ESDI		; EDI = linear address of caller's ES:DI

	 mov	 [ebp].INTXX_EBX.ELO,cx ; Return length in BX
	 add	 [ebp].INTXX_EDI.ELO,cx ; Advance caller's DI

	 REGSAVE <ds,es>	; Save for a moment

	 mov	 ax,SEL_4GB3	; Get AGROUP data selector at PL3
	 push	 es		; Get JGROUP selector
	 pop	 ds		; Address it
	 assume  ds:JGROUP	; Tell the assembler about it
	 mov	 es,ax		; Address AGROUP
	 assume  es:AGROUP	; Tell the assembler about it

	 jcxz	 QPI_API_NAME_DONE ; Jump if nothing to copy
@@:
	 lods	 QPI_DIR[si]	; Get next byte
	 mov	 AGROUP:[edi],al ; Save in caller's buffer
	 inc	 edi		; Next byte

	 loop	 @B		; Jump if more bytes
QPI_API_NAME_DONE:
	 REGREST <es,ds>	; Restore
	 assume  ds:PGROUP,es:JGROUP ; Tell the assembler about it

	 jmp	 QPI_API_OK	; Join common exit code


; 1F00:  Get PTE of page CX into EDX
; 1F01:  Set ...	       from EDX (raw, PCD/PWT included; TLB flushed)
; 1F02:  Get CR0 into EAX
; 1F03:  Change only CR0.MP/EM/ET:  CR0 = (CR0 and (ECX or not 16h)) or
;	 (EBX and 16h), new CR0 in EAX
; As QEMM 97:  pages 0-3FFh (the first 4MB, RBIL says 0-10Fh), no check
; of the PTE; we refuse only pages beyond our page table (PDTLEN).
; This is how DOS software maps memory-mapped I/O of a PCI card.

@CR0_FPU equ	 16h		; CR0.MP, EM, ET

QPI_API_PTE:
	 cmp	 al,03h 	; Izit a valid subfunction?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 cmp	 al,02h 	; Izit a CR0 function?
	 jb	 short QPI_API_PTE1 ; Jump if not

	 mov	 eax,cr0	; Get current CR0
	 je	 short @F	; Jump if 1F02 (flags from CMP above)

	 mov	 ecx,[ebp].INTXX_ECX ; Get the bits to keep
	 or	 ecx,not @CR0_FPU ; Never change other bits
	 and	 eax,ecx	; Keep them
	 mov	 ecx,[ebp].INTXX_EBX ; Get the bits to set
	 and	 ecx,@CR0_FPU	; Only these
	 or	 eax,ecx	; Set them
	 mov	 cr0,eax	; Tell the CPU about it
@@:
	 mov	 [ebp].INTXX_EAX,eax ; Return CR0 in caller's EAX

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_PTE1:
	 movzx	 esi,[ebp].INTXX_ECX.ELO ; Get page #

	 cmp	 esi,3FFh	; Izit within the first 4MB?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 shl	 esi,2		; Convert to offset in PDT

	 cmp	 esi,PDTLEN	; Izit within our page table?
	 jae	 near ptr QPI_API_EXIT ; Jump if not

	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap (pages 100-10F)

	 add	 esi,PRGPDT	; Plus offset in PGROUP of PDT

	 cmp	 [ebp].INTXX_EAX.ELO.LO,01h ; Izit set?
	 je	 short @F	; Jump if so

	 mov	 eax,PGROUP:[esi].PDT_PTE ; Get the PTE
	 mov	 [ebp].INTXX_EDX,eax ; Return in caller's EDX

	 jmp	 QPI_API_OK	; Join common exit code

@@:
	 mov	 eax,[ebp].INTXX_EDX ; Get new PTE
	 mov	 PGROUP:[esi].PDT_PTE,eax ; Set it

	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...

	 jmp	 QPI_API_OK	; Join common exit code


; 04:  Allocate a 4KB page:  EDX = physical page # (address shr 12), 0 and
;      CF=1 if there is none (QEMM 97:  EDX 32 bits)
; 05:  Free the 4KB page DX (QEMM 97:  always CF=0)

QPI_API_ALLOC:
	 FIXICALL PGROUP:FVCPI_ALLOC,DTE_CS2 ; EDX = physical address
	 jnc	 short @F	; Jump if we got one

	 mov	 [ebp].INTXX_EDX,0 ; None
	 jmp	 QPI_API_EXIT	; Join common error code
@@:
	 shr	 edx,12 	; Convert to page #
	 mov	 [ebp].INTXX_EDX,edx ; Return in caller's EDX

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_FREE:
	 movzx	 edx,[ebp].INTXX_EDX.ELO ; Get page #
	 shl	 edx,12 	; Convert to physical address
	 FIXICALL PGROUP:FVCPI_DEALLOC,DTE_CS2 ; Free it (an unknown page:  CF=1)

	 jmp	 QPI_API_OK	; Join common exit code (always CF=0)

; 09:  Get the page frame of PTE CX into DX
; 0A:  Set the PTE CX to the page frame DX (present, writable, user)
; As QEMM 97 without checks of the frame; CX within our page table

QPI_API_GETFRM:
	 call	 QPI_PTEADDR	; ESI = offset in PGROUP of the PTE, CF=1 if none
	 jc	 near ptr QPI_API_EXIT ; Jump if out of range

	 mov	 eax,PGROUP:[esi].PDT_PTE ; Get the PTE
	 shr	 eax,12 	; Isolate the page frame
	 mov	 [ebp].INTXX_EDX.ELO,ax ; Return in caller's DX

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_SETFRM:
	 call	 QPI_PTEADDR	; ESI = offset in PGROUP of the PTE, CF=1 if none
	 jc	 near ptr QPI_API_EXIT ; Jump if out of range

	 movzx	 eax,[ebp].INTXX_EDX.ELO ; Get page frame
	 shl	 eax,12 	; Convert to physical address
	 or	 al,07h 	; Present, writable, user
	 mov	 PGROUP:[esi].PDT_PTE,eax ; Set it

	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...

	 jmp	 QPI_API_OK	; Join common exit code

; ESI = offset in PGROUP of the PTE of page CX (caller's), CF=1 if beyond
; the first 4MB or our page table

QPI_PTEADDR:
	 movzx	 esi,[ebp].INTXX_ECX.ELO ; Get page #

	 cmp	 esi,3FFh	; Izit within the first 4MB?
	 ja	 short QPI_PTEADDR_ERR ; Jump if not

	 shl	 esi,2		; Convert to offset in PDT

	 cmp	 esi,PDTLEN	; Izit within our page table?
	 jae	 short QPI_PTEADDR_ERR ; Jump if not

	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap (pages 100-10F)

	 add	 esi,PRGPDT	; Plus offset in PGROUP of PDT

	 clc			; Indicate it's valid

	 retn			; Return to caller

QPI_PTEADDR_ERR:
	 stc			; Indicate it's out of range

	 retn			; Return to caller


; Mapping contexts as QEMM 97 has them (DESQview's per-task address
; spaces):  a mapping context is a page table for linear 0-4MB in a
; physical page the caller allocated (04h).  We switch it the way the
; EMS alternate map register sets do (SET_AMRS in QMAX_OSE):  PDE 0 and
; the PTE of our page table alias (PRGPDT), so all of 386MAX's PTE code
; works on the active table.

; 06:  Clone the active page table into the physical page DX
;      (QEMM 97 checks nothing; we refuse pages we can't address)

QPI_API_CLONE:
	 movzx	 ebx,[ebp].INTXX_EDX.ELO ; Get page frame
	 shl	 ebx,12 	; Convert to physical address
	 mov	 edx,ebx	; Save it
	 call	 QPI_PT2LIN	; EBX = its linear address, CF=1 if none
	 jc	 near ptr QPI_API_EXIT ; Jump if not addressable

	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap (pages 100-10F)

	 push	 es		; Save for a moment

	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 mov	 edi,ebx	; ES:EDI ==> the new table
	 mov	 esi,PRGPDT	; DS:ESI ==> the active table
	 mov	 ecx,4096/4	; # PTEs in a page table
S32  rep movs	 <AGROUP:[edi].EDD,PGROUP:[esi].EDD> ; Copy it

; If our page table alias is within the first 4MB, the clone must map
; itself there (as EMS 5B03h does)

	 test	 LCL_FLAG,@LCL_4MB ; Izit beyond the first 4MB?
	 jnz	 short @F	; Jump if so

	 mov	 edi,PDTDIR2	; Get offset of its PTE
	 mov	 eax,edx	; Get the new table's physical address
	 or	 ax,@PTE_RP	; Present, writable, supervisor
	 mov	 AGROUP:[ebx+edi].EDD,eax ; Map itself
@@:
	 pop	 es		; Restore
	 assume  es:JGROUP	; Tell the assembler about it

	 jmp	 QPI_API_OK	; Join common exit code


; 07:  Get the physical page of the active page table (DX)

QPI_API_GETCTX:
	 mov	 ebx,OFFCR3	; Get offset of the page directory
	 mov	 eax,PGROUP:[ebx].EDD ; Get PDE 0
	 shr	 eax,12 	; Isolate the page frame
	 mov	 [ebp].INTXX_EDX.ELO,ax ; Return in caller's DX

	 jmp	 QPI_API_OK	; Join common exit code


; 08:  Make the page table in the physical page DX active (one made by
;      06h; the HMA PTEs are carried over as A20 is global)

QPI_API_SETCTX:
	 movzx	 ebx,[ebp].INTXX_EDX.ELO ; Get page frame
	 shl	 ebx,12 	; Convert to physical address
	 mov	 edx,ebx	; Save it
	 call	 QPI_PT2LIN	; EBX = its linear address, CF=1 if none
	 jc	 near ptr QPI_API_EXIT ; Jump if not addressable

	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap (pages 100-10F)

	 pushf			; Save flags
	 cli			; Disallow interrupts

	 push	 es		; Save for a moment

	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 mov	 esi,PPDT1MB	; Get offset of the HMA PTEs
	 lea	 edi,[ebx+esi]	; ES:EDI ==> those in the new table
	 add	 esi,PRGPDT	; DS:ESI ==> those in the active one
	 mov	 ecx,64/4	; # 4KB pages in the HMA
S32  rep movs	 <AGROUP:[edi].EDD,PGROUP:[esi].EDD> ; Copy them

	 pop	 es		; Restore
	 assume  es:JGROUP	; Tell the assembler about it

	 mov	 eax,edx	; Get the new table's physical address
	 or	 ax,@PTE_URP	; Present, writable, user
	 mov	 edi,OFFCR3	; Get offset of the page directory
	 mov	 PGROUP:[edi].EDD,eax ; PDE 0

	 test	 LCL_FLAG,@LCL_4MB ; Izit our alias beyond the first 4MB?
	 jz	 short @F	; Jump if not (the table maps itself)

	 and	 ax,not (mask $PTE_US) ; Supervisor only
	 mov	 edi,PDTDIR2	; Get offset of the alias PTE
	 add	 edi,PRGPDT	; Plus offset in PGROUP of PDT
	 mov	 PGROUP:[edi].EDD,eax ; Point the alias to the new table
@@:
	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...

	 popf			; Restore flags

	 jmp	 QPI_API_OK	; Join common exit code


; 0B:  Map the 16KB pages of EMS handle DX at the linear 4KB page CX on,
;      BX pages (0 = all)
; As QEMM 97:  always AH=0 and CF=0, an invalid handle maps nothing.  We
; stop at the end of the first 4MB.

QPI_API_MAPH:
	 mov	 [ebp].INTXX_EAX.ELO.HI,0 ; AH = 0

	 movzx	 edx,[ebp].INTXX_EDX.ELO ; Get the handle
	 cmp	 dx,@MAX_EHNDLCNT-1 ; Izit a handle?
	 ja	 near ptr QPI_API_OK ; Jump if not (nothing to do)

	 bt	 HMAP.ELO,dx	; Izit allocated?
	 jnc	 near ptr QPI_API_OK ; Jump if not (nothing to do)

	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap (pages 100-10F)

	 movzx	 ecx,[ebp].INTXX_EBX.ELO ; Get # 16KB pages (0 = all)
	 movzx	 edi,[ebp].INTXX_ECX.ELO ; Get first linear 4KB page
	 shl	 edi,2		; Convert to offset in PDT

	 mov	 ebx,edx	; Copy the handle
	 shl	 ebx,2		; Times four to index table of dwords
	 add	 ebx,PHNDLPAGE	; EBX ==> HNDLPAGE[handle]
	 mov	 edx,PRGPDT	; Get offset in PGROUP of PDT
QPI_API_MAPH_NXT:
	 mov	 ebx,PGROUP:[ebx].PL_NEXT ; Get the next logical page

	 cmp	 ebx,HP_LAST	; Izit the end?
	 je	 short QPI_API_MAPH_DONE ; Jump if so

	 cmp	 edi,4096-16	; Izit beyond the first 4MB?
	 ja	 short QPI_API_MAPH_DONE ; Jump if so

; Offset in the PDT of the 4 PTEs of this 16KB page (as PGMAP_COM)

	 mov	 esi,ebx	; Copy the link
	 sub	 esi,PPAGELINK	; Convert to (size PL_STR) * 16KB page #
	 mov	 eax,esi	; Copy it
	 add	 eax,PLINKBASE	; Plus base of the PDT offsets
	 shl	 esi,4-2	; Convert from dword to four-dword index
	 add	 esi,PGROUP:[eax].EDD ; Plus the corresponding offset

	 REGSAVE <ecx>		; Save # pages
	 mov	 ecx,4		; # 4KB pages in 16KB
@@:
	 mov	 eax,PGROUP:[esi+edx].EDD ; Get the PTE
	 or	 ax,@PTE_URP	; Present, writable, user
	 mov	 PGROUP:[edi+edx].EDD,eax ; Map it
	 add	 esi,4		; Next PTE
	 add	 edi,4		; ...
	 loop	 @B		; Jump if more
	 REGREST <ecx>		; Restore

	 jecxz	 QPI_API_MAPH_NXT ; Jump if all pages wanted

	 loop	 QPI_API_MAPH_NXT ; Jump if more pages wanted
QPI_API_MAPH_DONE:
	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...

	 jmp	 QPI_API_OK	; Join common exit code


; 0F:  Restore the default mapping of DX pages from the linear 4KB page CX
;      on; AL = 1 if one of them was written to (dirty), else 0
; The default PTEs (0-10FFFFh) were taken at the first QPI call.  We
; restore nothing beyond them (QEMM 97 uses garbage) and nothing for DX=0
; (QEMM 97 hangs).

QPI_API_UNMAP:
	 FIXICALL PGROUP:FWRAP_DISABLE,DTE_CS2 ; Disable the 1MB wrap (pages 100-10F)

	 movzx	 esi,[ebp].INTXX_ECX.ELO ; Get first page
	 movzx	 ecx,[ebp].INTXX_EDX.ELO ; Get # pages
	 mov	 edx,PRGPDT	; Get offset in PGROUP of PDT
	 xor	 bl,bl		; Nothing dirty yet
	 jecxz	 QPI_API_UNMAP_DONE ; Jump if none
QPI_API_UNMAP_NXT:
	 cmp	 esi,@QPI_NDEF	; Izit one with a default?
	 jae	 short QPI_API_UNMAP_DONE ; Jump if not

	 mov	 eax,QPI_DEFPTE[esi*4] ; Get the default PTE
	 xchg	 eax,PGROUP:[edx+esi*4].EDD ; Restore it, get the old one
	 test	 al,mask $PTE_D ; Was it written to?
	 setnz	 al		; AL = 1 if so
	 or	 bl,al		; Remember

	 inc	 esi		; Next page
	 loop	 QPI_API_UNMAP_NXT ; Jump if more
QPI_API_UNMAP_DONE:
	 mov	 [ebp].INTXX_EAX.ELO.LO,bl ; AL = dirty flag

	 mov	 eax,cr3	; Flush the TLB
	 mov	 cr3,eax	; ...

	 jmp	 QPI_API_OK	; Join common exit code


; 2000:  Get VirtualHDIRQ information (not supported:  0)
; 2001:  Set ...			  (ignored, old = 0)

QPI_API_VHI:
	 cmp	 al,01h 	; Izit a valid subfunction?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 mov	 [ebp].INTXX_EBX.ELO.LO,0 ; Not enabled, not respected

	 jmp	 QPI_API_OK	; Join common exit code


; 2200:  Get the DV/X shared pool control block (ES:DI, 0:0 = none)
; 2201:  Register the block at ES:DI (0:0 = back to the previous one)
; As QEMM 97 (DESQview/X):  the block's version byte must be 02h, the new
; block is linked to the previous one (DVX_PREV), which is marked as
; superseded, and the block that becomes current gets our free page
; count in DVX_FREE.  Not done (yet):  keeping DVX_FREE up to date on
; every allocation, the INT 2Fh "pool changed" broadcast and requests
; for pages (QEMM asks the owner when it runs out).

QPI_API_DVX:
	 cmp	 al,01h 	; Izit a valid subfunction?
	 ja	 near ptr QPI_API_EXIT ; Jump if not
	 je	 short QPI_API_DVX1 ; Jump if register

	 mov	 eax,QPI_DVX	; Get the current block
	 mov	 [ebp].INTXX_EDI.ELO,ax ; Return offset in caller's DI
	 shr	 eax,16 	; Shift down the segment
	 mov	 [ebp].INTXX_ES,ax ; Return in caller's ES

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_DVX1:
	 push	 fs		; Save for a moment

	 mov	 fs,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  fs:AGROUP	; Tell the assembler about it

	 mov	 ax,[ebp].INTXX_ES ; Get caller's ES
	 shl	 eax,16 	; Shift to segment position
	 mov	 ax,[ebp].INTXX_EDI.ELO ; Get caller's DI

	 mov	 ebx,QPI_DVX	; Get the current block

	 or	 eax,eax	; Izit unregister?
	 jnz	 short QPI_API_DVX_REG ; Jump if not

	 or	 ebx,ebx	; Izit registered?
	 jz	 short QPI_API_DVX_OK ; Jump if not (nothing to do)

	 call	 QPI_SEG2LIN	; EBX = linear address of the block
	 mov	 eax,AGROUP:[ebx].DVX_PREV ; Get the previous one
	 mov	 es:QPI_DVX,eax ; It's current again

	 or	 eax,eax	; Izit none?
	 jz	 short QPI_API_DVX_OK ; Jump if so

	 mov	 ebx,eax	; Copy Seg:Off
	 call	 QPI_SEG2LIN	; EBX = linear address of the block
	 and	 AGROUP:[ebx].DVX_FLAG,not @DVX_OLD ; Active again

	 jmp	 short QPI_API_DVX_CUR ; Join common code

QPI_API_DVX_REG:
	 mov	 ecx,ebx	; Save the previous block
	 mov	 ebx,eax	; Copy Seg:Off
	 call	 QPI_SEG2LIN	; EBX = linear address of the block

	 cmp	 AGROUP:[ebx].DVX_VER,02h ; Izit the version we know?
	 jne	 short QPI_API_DVX_ERR ; Jump if not

	 mov	 AGROUP:[ebx].DVX_PREV,ecx ; Link to the previous one
	 and	 AGROUP:[ebx].DVX_FLAG,not @DVX_OLD ; Active
	 mov	 es:QPI_DVX,eax ; It's the current one

	 jecxz	 QPI_API_DVX_CUR ; Jump if there was none

	 push	 ebx		; Save new block
	 mov	 ebx,ecx	; Copy previous one's Seg:Off
	 call	 QPI_SEG2LIN	; EBX = linear address of the block
	 or	 AGROUP:[ebx].DVX_FLAG,@DVX_OLD ; Superseded
	 pop	 ebx		; Restore
QPI_API_DVX_CUR:
	 FIXICALL PGROUP:FVCPI_COUNT,DTE_CS2 ; EDX = # free 4KB pages
	 mov	 AGROUP:[ebx].DVX_FREE,edx ; Tell the owner
QPI_API_DVX_OK:
	 pop	 fs		; Restore
	 assume  fs:nothing	; Tell the assembler about it

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_DVX_ERR:
	 pop	 fs		; Restore
	 assume  fs:nothing	; Tell the assembler about it

	 jmp	 QPI_API_EXIT	; Return with CF set


; 23FF:  Reset the VCPI quota (unlimited)
; 2300:  Get the quota DWORD of slot BX (ES:DI, 0:0 = unlimited)
; 2301:  Set ...			    (ES:DI, 0:0 = unlimited)
; 2302:  Clear ...
; As QEMM 97:  one slot (BX = 0); the DWORD counts the KB VCPI clients
; may still allocate (DESQview's per-process VCPI limit).  Not done
; (yet):  VCPI DE03h-DE05h don't consult it, so the limit isn't enforced.

QPI_API_QUOTA:
	 cmp	 al,0FFh	; Izit reset?
	 je	 short QPI_API_QUOTA_CLR ; Jump if so

	 cmp	 al,02h 	; Izit a valid subfunction?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 cmp	 [ebp].INTXX_EBX.ELO,0 ; Izit slot 0?
	 jne	 near ptr QPI_API_EXIT ; Jump if not (the only one)

	 cmp	 al,01h 	; Izit get or set?
	 ja	 short QPI_API_QUOTA_CLR ; Jump if clear
	 je	 short QPI_API_QUOTA_SET ; Jump if set

	 mov	 eax,QPI_QUOTA	; Get the pointer
	 mov	 [ebp].INTXX_EDI.ELO,ax ; Return offset in caller's DI
	 shr	 eax,16 	; Shift down the segment
	 mov	 [ebp].INTXX_ES,ax ; Return in caller's ES

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_QUOTA_SET:
	 mov	 ax,[ebp].INTXX_ES ; Get caller's ES
	 shl	 eax,16 	; Shift to segment position
	 mov	 ax,[ebp].INTXX_EDI.ELO ; Get caller's DI
	 mov	 es:QPI_QUOTA,eax ; Save (0:0 clears it)

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_QUOTA_CLR:
	 mov	 es:QPI_QUOTA,0 ; Unlimited

	 jmp	 QPI_API_OK	; Join common exit code


; 28:  Set the word of the EMM import structure (BX); we build no such
;      structure for Windows, so it's only kept

QPI_API_W28:
	 mov	 ax,[ebp].INTXX_EBX.ELO ; Get caller's BX
	 mov	 es:QPI_W28,ax	; Save it

	 jmp	 QPI_API_OK	; Join common exit code


; 2A00:  Get the ANALYSIS "pages touched" bitmap (32 bytes at ES:DI)
; 2A01:  Get the ANALYSIS "pages watched" bitmap ...
; We have no ANALYSIS:  both are empty (QEMM 97 crashes for AL > 01h)

QPI_API_ANAL:
	 cmp	 al,01h 	; Izit a valid subfunction?
	 ja	 near ptr QPI_API_EXIT ; Jump if not

	 QPI_ESDI		; EDI = linear address of caller's ES:DI

	 push	 es		; Save for a moment

	 mov	 es,SEL_4GB3	; Get AGROUP data selector at PL3
	 assume  es:AGROUP	; Tell the assembler about it

	 xor	 eax,eax	; Nothing touched
	 mov	 ecx,32/4	; # dwords in the bitmap
S32  rep stos	 AGROUP:[edi].EDD ; Clear it

	 pop	 es		; Restore
	 assume  es:JGROUP	; Tell the assembler about it

	 jmp	 QPI_API_OK	; Join common exit code

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_API endp			; End QPI_API procedure

JCODE	 ends			; End JCODE segment

	 MEND			; End QMAX_QPI module


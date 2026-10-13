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
mode support uses:  I/O port trapping with a callback in VM, the way
Jemm's QPIEMU provides it.

* The entry point in VM is the old VCPI one (OLDVCPI in QMAX_OVR, an
  INT 0FEh), returned by INT 67h AH=3Fh, CX='QE', DX='MM' (QEMM's
  way) and by INT 2Fh AX=1684h, BX=4354h (Jemm's QPIEMU, QMAX_XMS).
  INTFE (QMAX_VCP) passes the QPI functions (AH=03h, 1Ah) to QPI_API
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

	 include QMAX_DTE.INC
	 include QMAX_OEM.INC
.list

PGROUP	 group	 CODE,ECODE,EDATA
JGROUP	 group	 JCODE,JDATA


CODE	 segment use16 byte public 'prog' ; Start CODE segment
	 assume  cs:PGROUP,ds:PGROUP

	 extrn	 GLB_FLAG:word
	 extrn	 HARDRET:far

CODE	 ends			; End CODE segment


ECODE	 segment use16 dword public 'ecode' ; Start ECODE segment
	 assume  cs:PGROUP

	 extrn	 EMM_EXIT1:near
	 extrn	 FCHECK_INP_NOQPI:far
	 extrn	 FCHECK_OUT_NOQPI:far
	 extrn	 FWRAP_ENABLE:far
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

EDATA	 ends			; End EDATA segment


JDATA	 segment use16 dword public 'jcode' ; Start JDATA segment
	 assume  ds:JGROUP

@QPI_MAX equ	 128		; # I/O ports QPI clients may trap

	 public  QPI_CB,QPI_PORT,QPI_OWN
QPI_CB	 dd	 0		; I/O trap callback (Seg:Off in VM), 0 = none
QPI_PORT dw	 @QPI_MAX dup (?) ; I/O ports trapped via QPI (QPI_NPORT of them)
QPI_OWN  db	 @QPI_MAX dup (?) ; 1 = I/O permission bit was set already

JDATA	 ends			; End JDATA segment


JCODE	 segment use16 dword public 'jcode' ; Start JCODE segment
	 assume  cs:JGROUP

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
	 call	 QPI_CALLVM	; Call the callback
				; Return with CF=0 if handled, EAX = value
	 jc	 short QPI_CHECK_XFOUND ; Jump if not handled

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

CF	 =	 0 if it handled the I/O
	 =	 1 if not
AL/AX/EAX =	 input value

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

	 push	 ecx		; Save width
	 push	 edx		; ...  port
	 FIXICALL PGROUP:FCHECK_INP_NOQPI,DTE_CS2 ; Check on I/O port inputs
				; Return with CF=1 if value supplied in EAX
	 pop	 edx		; Restore
	 pop	 ecx		; ...
	 jc	 short QPI_UNTRAPIN_EXIT ; Jump if value supplied

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

	 push	 ecx		; Save width
	 push	 edx		; ...  port
	 push	 eax		; ...  value
	 FIXICALL PGROUP:FCHECK_OUT_NOQPI,DTE_CS2 ; Check on I/O port outputs
				; Return with CF=1 if already done
	 pop	 eax		; Restore
	 pop	 edx		; ...
	 pop	 ecx		; ...
	 jc	 short QPI_UNTRAPOUT_EXIT ; Jump if already done

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
	 FPPROC  QPI_API -- QEMM Programming Interface Functions
	 assume  ds:PGROUP,es:PGROUP,fs:nothing,gs:nothing,ss:PGROUP
COMMENT|

QPI functions, jumped to from INTFE (QMAX_VCP), the old VCPI entry
point returned by INT 67h AH=3Fh, CX='QE', DX='MM' and by INT 2Fh
AX=1684h, BX=4354h.  Only the functions SBEMU uses are supported:

AH	 =	 03h	 Get version (AX = BX = 0703h)
AX	 =	 1A00h	 Untrapped IN  AL,DX (result in BL)
	 =	 1A01h	 Untrapped OUT DX,BL
	 =	 1A04h	 Untrapped I/O (CX = flags, EBX = value)
	 =	 1A06h	 Get I/O trap callback (ES:DI)
	 =	 1A07h	 Set I/O trap callback (ES:DI)
	 =	 1A08h	 Get port DX trap status (BL)
	 =	 1A09h	 Trap port DX
	 =	 1A0Ah	 Untrap port DX

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

	 mov	 dx,[ebp].INTXX_EDX.ELO ; Get the I/O port #

	 cmp	 ah,03h 	; Izit Get Version?
	 je	 short QPI_API_VER ; Jump if so

	 cmp	 ah,1Ah 	; Izit I/O trapping?
	 jne	 short QPI_API_EXIT ; Jump if not

	 cmp	 al,00h 	; Izit untrapped input?
	 je	 short QPI_API_IN ; Jump if so

	 cmp	 al,01h 	; Izit untrapped output?
	 je	 short QPI_API_OUT ; Jump if so

	 cmp	 al,04h 	; Izit untrapped I/O?
	 je	 short QPI_API_IO ; Jump if so

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
	 jnz	 short QPI_API_EXIT ; Jump if so (not supported)

	 shr	 ecx,3		; Shift down the width
	 and	 ecx,@IOTRAP_WID ; Isolate it
	 cmp	 cl,@IOTRAP_DD	; Izit valid?
	 ja	 short QPI_API_EXIT ; Jump if not

	 test	 [ebp].INTXX_ECX.ELO.LO,@IOTRAP_OUT ; Izit output?
	 jnz	 short QPI_API_IOOUT ; Jump if so

	 call	 QPI_UNTRAPIN	; Return with AL/AX/EAX = value

	 mov	 [ebp].INTXX_EBX.ELO.LO,al ; Return in caller's BL

	 cmp	 cl,@IOTRAP_DB	; Izit byte I/O?
	 je	 short QPI_API_OK ; Jump if so

	 mov	 [ebp].INTXX_EBX.ELO,ax ; Return in caller's BX

	 cmp	 cl,@IOTRAP_DW	; Izit word I/O?
	 je	 short QPI_API_OK ; Jump if so

	 mov	 [ebp].INTXX_EBX,eax ; Return in caller's EBX

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_IOOUT:
	 mov	 eax,[ebp].INTXX_EBX ; Get caller's EBX
	 call	 QPI_UNTRAPOUT	; Write it

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_GETCB:
	 mov	 eax,QPI_CB	; Get the callback
	 mov	 [ebp].INTXX_EDI.ELO,ax ; Return offset in caller's DI
	 shr	 eax,16 	; Shift down the segment
	 mov	 [ebp].INTXX_ES,ax ; Return in caller's ES

	 jmp	 QPI_API_OK	; Join common exit code

QPI_API_SETCB:
	 mov	 ax,[ebp].INTXX_ES ; Get caller's ES
	 shl	 eax,16 	; Shift to segment position
	 mov	 ax,[ebp].INTXX_EDI.ELO ; Get caller's DI
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

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

QPI_API endp			; End QPI_API procedure

JCODE	 ends			; End JCODE segment

	 MEND			; End QMAX_QPI module

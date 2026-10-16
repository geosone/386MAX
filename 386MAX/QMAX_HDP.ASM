;' $Header$
	 title	 QMAX_HDP -- 386MAX HDPMI-Compatible Vendor API
	 page	 58,122
	 name	 QMAX_HDP

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2026 Open 386MAX.  GNU General Public License version 3.

Segmentation:  Group PGROUP:
	       Data    segment EDATA, dword-aligned, public, class 'edata'
	       Group JGROUP:
	       Program segment JCODE, dword-aligned, public, class 'jcode'
	       Data    segment JDATA, dword-aligned, public, class 'jcode'

Program derived from:  None.

Original code by:  Open 386MAX, 2026.

Modifications by:  None.

The vendor-specific API that HDPMI offers under the name "HDPMI", so
programs written for HDPMI (VSBHDA, the HX runtime) find what they need
on 386MAX's own DPMI host.  Written from the published interface
description only (function numbers, registers, flags).

A client gets the entry point with INT 2Fh AX=168Ah (or INT 31h 0A00h)
and DS:eSI ==> 'HDPMI',0 (DPMIFN_CHKVSAPI in QMAX_L31 asks HDP_CHKNAME
here).  The PL3 stubs PMVSAPInn_HDPMI (QMAX_DIF) enter DPMIFN_VSAPI
(QMAX_M31) through the vendor API call gate, which calls HDP_API here
with the caller's registers.

AX	 =	 0-3	 Debug functions (debug versions only):  CF=1
	 =	 4	 Accept no new clients:  CF=1 (386MAX is the one
			 resident host; there is no other instance)
	 =	 5	 Set the HDPMI=32 flag (separate context for new
			 clients):  BL = new value, AL = old value
	 =	 6	 Trap the I/O ports DX..DX+CX-1 in protected mode
			 (DS:eSI ==> IN and OUT handler), EAX = handle
	 =	 7	 Remove the trap range EDX
	 =	 8	 Simulate I/O bypassing all traps
	 =	 9	 CLI (BL=0) or STI (BL=1) handler CX:eDX (0:0 = none)
	 =	 10	 Simulate a hardware interrupt:  CF=1 (as HDPMI)

Port traps in protected mode work as in HDPMI's IOPL 0 variants:

* While a trap range or a CLI/STI handler is installed, DPMI clients
  run with IOPL 0 (DPMIOPLF/HDP_IOPLF, used wherever the host builds a
  client's flags), so IN/OUT/INS/OUTS to a port whose bit is set in the
  I/O permission bit map fault, as do CLI and STI.  Otherwise clients
  keep IOPL 3, 386MAX's old behaviour.
* The general protection fault handler (QMAX_I0D) decodes the prefixes
  and dispatches the opcode through GP_ACT.  Once the API is in use, the
  entries of IN/OUT/INS/OUTS/CLI/STI point to GP_HDPSTUB (QMAX_IOP),
  which asks HDP_GPIO here where to continue.  Faults from VM86 mode
  continue with the old entries.
* A trapped port of the current client calls the range's handler like
  an exception handler (PMFLTCOM with the vector HDP_OVR32/HDP_OVR16
  instead of the client's INT 0Dh one) with HDPMI's error code; the
  handler advances EIP and returns with RETF.  Other ports are read or
  written directly, as they were at IOPL 3.
* A CLI/STI handler is entered with an IRET frame on the client's stack
  and IF already changed.

|

.386p
.xlist
	 include MASM.INC
	 include 386.INC
	 include PTR.INC
	 include CPUFLAGS.INC
	 include ALLMEM.INC
	 include MASM5.MAC

	 include QMAX_DTE.INC
	 include QMAX_I31.INC
	 include QMAX_TSS.INC
	 include QMAX_EMM.INC
	 include QMAXDPMI.INC
.list

PGROUP	 group	 ECODE,EDATA
IGROUP	 group	 IDATA
JGROUP	 group	 JCODE,JDATA


ECODE	 segment use16 dword public 'ecode' ; Start ECODE segment
	 assume  cs:PGROUP

	 extrn	 INT0D_IRETD:near
	 extrn	 INT0D_UGHNF:near
	 extrn	 GP_HDPSTUB:near
	 extrn	 FALLOCMEM:far
	 extrn	 FDEALLOCMEM:far

ECODE	 ends			; End ECODE segment


EDATA	 segment use16 dword public 'edata' ; Start EDATA segment
	 assume  ds:PGROUP

	 extrn	 GP_ACT:word
	 extrn	 PIOBIT:dword
	 extrn	 PCURTSS:dword
	 extrn	 DPMITYPE:byte
	 extrn	 DPMI_CPFHOOK:byte
	 extrn	 QPI_NPORT:word
	 extrn	 DPMI_IDEF:word
	 extrn	 PMHDPCLI:abs
	 extrn	 PVMTSS:dword

EDATA	 ends			; End EDATA segment


IDATA	 segment use16 dword public 'idata' ; Start IDATA segment
	 assume  ds:IGROUP

	 extrn	 DPMIOPLF:dword
	 extrn	 HDP_OVRFLG:byte
	 extrn	 HDP_OVRHOOK:byte
	 extrn	 HDP_OVR32:fword
	 extrn	 HDP_OVR16:dword
	 extrn	 DPMITYPEIG:byte
	 extrn	 VMMcurrentClient:word

IDATA	 ends			; End IDATA segment


JDATA	 segment use16 dword public 'jcode' ; Start JDATA segment
	 assume  ds:JGROUP

	 extrn	 QPI_PORT:word

	 public  HDP_FLAG,HDP_SEP,HDP_IOPLF
ifdef @HDP_ON
HDP_FLAG db	 01h		; Flags (test build:  'HDPMI' answered)
else
HDP_FLAG db	 0		; Flags
endif				; IFDEF @HDP_ON
@HDP_NAME equ	 01h		; The name 'HDPMI' is answered
@HDP_GPON equ	 02h		; GP_ACT entries point to GP_HDPSTUB
HDP_SEP  db	 1		; HDPMI=32 flag:  1 = new clients get a
				; separate context (what 386MAX always did)
HDP_IOPLF dd	 3 shl 12	; IOPL for DPMI clients' flags (copy of
				; DPMIOPLF in IGROUP, for JGROUP code)

@HDP_NRNG equ	 16		; # trap ranges (HDPMI has 8)
@HDP_NOWN equ	 64		; # ports per range whose bit we remember

HDPR_STR struc
HDPR_PORT dw	 ?		; First port
HDPR_CNT dw	 ?		; # ports (0 = entry free)
HDPR_IN  df	 ?		; IN  handler (Sel:Off32, or Seg:Off16 in the dword)
HDPR_OUT df	 ?		; OUT handler (...)
HDPR_TYPE db	 ?		; Owner's DPMITYPE
	 db	 ?		; (filler)
HDPR_OWN dd	 ?		; Owner's TSS (PCURTSS)
HDPR_SET dd	 (@HDP_NOWN/32) dup (?) ; 1 = we set the port's IOPB bit
HDPR_STR ends

HDP_RNG  HDPR_STR @HDP_NRNG dup (<>) ; The trap ranges
HDP_NRNG dw	 0		; # ranges in use

HDP_CLI  df	 0		; CLI handler (0 = none)
HDP_STI  df	 0		; STI ...
HDP_CLITYP db	 ?		; DPMITYPE of the CLI handler's owner
HDP_STITYP db	 ?		; ...		  STI ...
HDP_CLIOWN dd	 ?		; TSS of the CLI handler's owner
HDP_STIOWN dd	 ?		; ...	     STI ...

; The GP_ACT entries we redirect, and their old values

HDP_GPOPS db	 0E4h,0E5h,0E6h,0E7h,0ECh,0EDh,0EEh,0EFh ; IN/OUT
	 db	 06Ch,06Dh,06Eh,06Fh ; INS/OUTS
	 db	 0FAh,0FBh	; CLI, STI
@HDP_NGPOPS equ  $-HDP_GPOPS	; # opcodes
HDP_GPOLD dw	 @HDP_NGPOPS dup (?) ; Old GP_ACT entries

; Segment override prefix flags (QMAX_I0D GPMAC) and their opcodes

	 extrn	 $$ES:abs
	 extrn	 $$CS:abs
	 extrn	 $$SS:abs
	 extrn	 $$DS:abs
	 extrn	 $$FS:abs
	 extrn	 $$GS:abs
	 extrn	 $$OSP:abs
	 extrn	 $$ASP:abs
	 extrn	 $$REP:abs

JDATA	 ends			; End JDATA segment


JCODE	 segment use16 dword public 'jcode' ; Start JCODE segment
	 assume  cs:JGROUP

	 extrn	 FSEGSEL_BASE:far

	 public  @QMAX_HDP_JCODE
@QMAX_HDP_JCODE:		; Mark module start in .MAP file

	 FPPROC  HDP_CHKNAME -- Is It 'HDPMI',0?
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Check the vendor name for the HDPMI API.

On entry:

DS:EAX	 ==>	 ASCIIZ name

On exit:

ZF	 =	 1 if it's 'HDPMI',0 and the name is enabled
	 =	 0 otherwise

All registers preserved.

|

	 cmp	 ds:[eax].EDD,'MPDH' ; Izit bytes 0-3 of 'HDPMI',0?
	 jne	 short HDP_CHKNAME_EXIT ; Jump if not (note ZF=0)

	 cmp	 ds:[eax+4].ELO,'I' ; Izit bytes 4-5 of 'HDPMI',0?
	 jne	 short HDP_CHKNAME_EXIT ; Jump if not (note ZF=0)

	 push	 ds		; Save for a moment
	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:JGROUP	; Tell the assembler about it

	 test	 HDP_FLAG,@HDP_NAME ; Answered?
	 pop	 ds		; Restore
	 assume  ds:nothing	; Tell the assembler about it
	 jz	 short HDP_CHKNAME_NO ; Jump if not

	 cmp	 eax,eax	; Set ZF=1

	 ret			; Return to caller
HDP_CHKNAME_NO:
	 push	 ax		; Save for a moment
	 mov	 al,1		; Set ZF=0
	 cmp	 al,0		; ...
	 pop	 ax		; Restore (flags unchanged)
HDP_CHKNAME_EXIT:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_CHKNAME endp		; End HDP_CHKNAME procedure
	 FPPROC  HDP_ENABLE -- Answer the Name 'HDPMI' or Not
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Enable or disable the name 'HDPMI' (386MAX vendor API AX=0200h).

On entry:

BL	 =	 1 to answer 'HDPMI'
	 =	 0 not to

On exit:

AL	 =	 previous setting

|

	 push	 ds		; Save for a moment
	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:JGROUP	; Tell the assembler about it

	 mov	 al,HDP_FLAG	; Get the flags
	 and	 al,@HDP_NAME	; Isolate the name bit (=1)
	 and	 HDP_FLAG,not @HDP_NAME ; Clear it

	 test	 bl,1		; Enable?
	 jz	 short @F	; Jump if not

	 or	 HDP_FLAG,@HDP_NAME ; Enable it
@@:
	 pop	 ds		; Restore
	 assume  ds:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_ENABLE endp 		; End HDP_ENABLE procedure
	 FPPROC  HDP_API -- HDPMI-Compatible Vendor API
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

HDPMI-compatible vendor API, called from DPMIFN_VSAPI at PL0 with the
caller's registers and IF=0.

On entry:

AX	 =	 function (see the module header)

On exit:

CF	 =	 0 if successful
	 =	 1 if not
Registers as the function returns them, all others preserved.

|

	 cmp	 ax,5		; Izit set the HDPMI=32 flag?
	 je	 short HDP_API5 ; Jump if so

	 cmp	 ax,6		; Izit trap a port range?
	 je	 near ptr HDP_API6 ; Jump if so

	 cmp	 ax,7		; Izit remove a port range?
	 je	 near ptr HDP_API7 ; Jump if so

	 cmp	 ax,8		; Izit simulate I/O?
	 je	 short HDP_API8 ; Jump if so

	 cmp	 ax,9		; Izit CLI/STI handler?
	 je	 near ptr HDP_API9 ; Jump if so
HDP_API_ERR:
	 stc			; Indicate not supported

	 ret			; Return to caller

; 5:  BL = new value of the HDPMI=32 flag, AL = old value

HDP_API5:
	 push	 ds		; Save for a moment
	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:JGROUP	; Tell the assembler about it

	 mov	 al,HDP_SEP	; Return the old value
	 mov	 HDP_SEP,bl	; Set the new one
	 and	 HDP_SEP,1	; ...as 0 or 1

	 pop	 ds		; Restore
	 assume  ds:nothing	; Tell the assembler about it

	 clc			; Indicate success

	 ret			; Return to caller

; 8:  simulate I/O
; BX	 =	 flags:  bit 0 = OUT, bit 3 = string, bits 4-5 = size
;		 (00 byte, 01 word, 11 dword), bit 6 = port in BH
;		 (IN/OUT) or 16-bit addressing (INS/OUTS), bit 7 = REP
; DX	 =	 port (unless IN/OUT with bit 6 set)
; ECX	 =	 value (IN/OUT) or count (REP INS/OUTS)
; DS:eSI ==>	 values for OUTS, ES:eDI ==> buffer for INS
; Out:	 EAX = ECX for IN/OUT, modified by IN

HDP_API8:
	 test	 bl,08h 	; Izit a string instruction?
	 jnz	 near ptr HDP_API8_STR ; Jump if so

	 push	 edx		; Save the port register

	 test	 bl,40h 	; Izit port in BH?
	 jz	 short @F	; Jump if not

	 movzx	 dx,bh		; Get the port
@@:
	 mov	 eax,ecx	; Start with the value

	 test	 bl,01h 	; Izit OUT?
	 jnz	 short HDP_API8_OUT ; Jump if so

	 test	 bl,10h 	; Izit byte?
	 jnz	 short @F	; Jump if not

	 in	 al,dx		; Read the byte

	 jmp	 short HDP_API8_DONE ; Join common code

@@:
	 test	 bl,20h 	; Izit word?
	 jnz	 short @F	; Jump if not

	 in	 ax,dx		; Read the word

	 jmp	 short HDP_API8_DONE ; Join common code

@@:
	 in	 eax,dx 	; Read the dword

	 jmp	 short HDP_API8_DONE ; Join common code

HDP_API8_OUT:
	 test	 bl,10h 	; Izit byte?
	 jnz	 short @F	; Jump if not

	 out	 dx,al		; Write the byte

	 jmp	 short HDP_API8_DONE ; Join common code

@@:
	 test	 bl,20h 	; Izit word?
	 jnz	 short @F	; Jump if not

	 out	 dx,ax		; Write the word

	 jmp	 short HDP_API8_DONE ; Join common code

@@:
	 out	 dx,eax 	; Write the dword
HDP_API8_DONE:
	 pop	 edx		; Restore

	 clc			; Indicate success

	 ret			; Return to caller

; INS/OUTS with the caller's DS:eSI/ES:eDI, (E)CX = count with REP

HDP_API8_STR:
	 test	 bl,80h 	; Izit REP?
	 jnz	 short @F	; Jump if so

	 push	 ecx		; Save the count register
	 mov	 ecx,1		; Once
	 call	 HDP_STRIO	; Do it
	 pop	 ecx		; Restore

	 jmp	 short HDP_API8_STRX ; Join common code

@@:
	 call	 HDP_STRIO	; Do it
HDP_API8_STRX:
	 clc			; Indicate success

	 ret			; Return to caller

; 6:  trap the ports DX..DX+CX-1, DS:eSI ==> handlers, EAX = handle

HDP_API6:
	 REGSAVE <ebx,ecx,edx,esi,edi,es> ; Save registers

	 movzx	 ecx,cx 	; Count
	 jecxz	 HDP_API6_ERR	; Jump if none

	 movzx	 edx,dx 	; First port
	 lea	 eax,[edx+ecx]	; One past the last
	 cmp	 eax,10000h	; Beyond the last port?
	 ja	 short HDP_API6_ERR ; Jump if so

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

; No port may be trapped already

	 xor	 edi,edi	; Start with the first range
HDP_API6_OVL:
	 cmp	 es:HDP_RNG[edi].HDPR_CNT,0 ; Izit free?
	 je	 short HDP_API6_NXT1 ; Jump if so
	 movzx	 ebx,es:HDP_RNG[edi].HDPR_PORT ; Its first port
	 cmp	 eax,ebx	; Do we end before it?
	 jbe	 short HDP_API6_NXT1 ; Jump if so

	 add	 bx,es:HDP_RNG[edi].HDPR_CNT ; One past its last port
	 jnc	 short @F	; Jump if below 10000h

	 mov	 ebx,10000h	; Up to the last port
@@:
	 cmp	 edx,ebx	; Do we start after it?
	 jb	 short HDP_API6_ERR ; Jump if not (overlap)
HDP_API6_NXT1:
	 add	 edi,size HDPR_STR ; Next range
	 cmp	 edi,@HDP_NRNG*(size HDPR_STR) ; Done?
	 jb	 short HDP_API6_OVL ; Jump if not

; Find a free entry

	 xor	 edi,edi	; Start with the first range
@@:
	 cmp	 es:HDP_RNG[edi].HDPR_CNT,0 ; Izit free?
	 je	 short HDP_API6_FREE ; Jump if so

	 add	 edi,size HDPR_STR ; Next range
	 cmp	 edi,@HDP_NRNG*(size HDPR_STR) ; Done?
	 jb	 short @B	; Jump if not
HDP_API6_ERR:
	 REGREST <es,edi,esi,edx,ecx,ebx> ; Restore
	 assume  es:nothing	; Tell the assembler about it

	 stc			; Indicate failure

	 ret			; Return to caller

	 assume  es:JGROUP	; Tell the assembler about it
HDP_API6_FREE:
	 mov	 es:HDP_RNG[edi].HDPR_PORT,dx ; Save the first port

; The handlers:  FAR32 (Off32, Sel) or FAR16 (Off16, Sel) each

	 push	 ds		; Save for a moment
	 push	 DTE_DS 	; Get PGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 mov	 al,DPMITYPE	; Get the client's type
	 mov	 es:HDP_RNG[edi].HDPR_TYPE,al ; Save it
	 mov	 ebx,PCURTSS	; Get the client's TSS
	 mov	 es:HDP_RNG[edi].HDPR_OWN,ebx ; Save as the owner

	 pop	 ds		; Restore
	 assume  ds:nothing	; Tell the assembler about it

	 cmp	 al,@DPMITYPE16 ; Izit a 16-bit client?
	 jne	 short @F	; Jump if not

	 movzx	 esi,si 	; Use SI
	 movzx	 eax,ds:[esi+0].ELO ; IN  offset
	 mov	 es:HDP_RNG[edi].HDPR_IN.FOFF,eax ; Save it
	 mov	 ax,ds:[esi+2].ELO ; ... selector
	 mov	 es:HDP_RNG[edi].HDPR_IN.FSEL,ax ; Save it
	 movzx	 eax,ds:[esi+4].ELO ; OUT offset
	 mov	 es:HDP_RNG[edi].HDPR_OUT.FOFF,eax ; Save it
	 mov	 ax,ds:[esi+6].ELO ; ... selector
	 mov	 es:HDP_RNG[edi].HDPR_OUT.FSEL,ax ; Save it

	 jmp	 short HDP_API6_SET ; Join common code

@@:
	 mov	 eax,ds:[esi+0].EDD ; IN  offset
	 mov	 es:HDP_RNG[edi].HDPR_IN.FOFF,eax ; Save it
	 mov	 ax,ds:[esi+4].ELO ; ... selector
	 mov	 es:HDP_RNG[edi].HDPR_IN.FSEL,ax ; Save it
	 mov	 eax,ds:[esi+6].EDD ; OUT offset
	 mov	 es:HDP_RNG[edi].HDPR_OUT.FOFF,eax ; Save it
	 mov	 ax,ds:[esi+10].ELO ; ... selector
	 mov	 es:HDP_RNG[edi].HDPR_OUT.FSEL,ax ; Save it
HDP_API6_SET:

; Set the ports' bits in the I/O permission bit map, remember which
; ones we set (for the first @HDP_NOWN ports)

	 mov	 es:HDP_RNG[edi].HDPR_SET[0],0 ; None yet
	 mov	 es:HDP_RNG[edi].HDPR_SET[4],0 ; ...

	 push	 ds		; Save for a moment
	 push	 DTE_DS 	; Get PGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 mov	 esi,PIOBIT	; Get offset in PGROUP of I/O bit map
	 xor	 ebx,ebx	; Index in the range
HDP_API6_BIT:
	 lea	 eax,[edx+ebx]	; The port
	 bts	 PGROUP:[esi],eax ; Trap it
	 jc	 short @F	; Jump if it was trapped already

	 cmp	 ebx,@HDP_NOWN	; Can we remember it?
	 jae	 short @F	; Jump if not (we leave it set)

	 bts	 es:HDP_RNG[edi].HDPR_SET,ebx ; We set it
@@:
	 inc	 ebx		; Next port
	 cmp	 ebx,ecx	; Done?
	 jb	 short HDP_API6_BIT ; Jump if not

	 pop	 ds		; Restore
	 assume  ds:nothing	; Tell the assembler about it

	 mov	 es:HDP_RNG[edi].HDPR_CNT,cx ; Mark as in use
	 inc	 es:HDP_NRNG	; Count in another one

	 mov	 eax,edi	; Copy the offset
	 xor	 edx,edx	; Zero to use as dword
	 mov	 ecx,size HDPR_STR ; Size of an entry
	 div	 ecx		; Index
	 inc	 eax		; Handle = index + 1

	 REGREST <es,edi,esi,edx,ecx,ebx> ; Restore
	 assume  es:nothing	; Tell the assembler about it

	 call	 HDP_ACTIVATE	; Redirect the GP_ACT entries, set the IOPL

	 clc			; Indicate success

	 ret			; Return to caller

; 7:  remove the trap range EDX (handle)

HDP_API7:
	 REGSAVE <eax,edi,es>	; Save registers

	 lea	 eax,[edx-1]	; Index
	 cmp	 eax,@HDP_NRNG	; Izit valid?
	 jae	 short HDP_API7_ERR ; Jump if not

	 imul	 edi,eax,size HDPR_STR ; Offset of the range

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 cmp	 es:HDP_RNG[edi].HDPR_CNT,0 ; Izit in use?
	 je	 short HDP_API7_ERR ; Jump if not

	 call	 HDP_DELRNG	; Remove it

	 REGREST <es,edi,eax>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 call	 HDP_ACTIVATE	; Set the IOPL

	 clc			; Indicate success

	 ret			; Return to caller

HDP_API7_ERR:
	 REGREST <es,edi,eax>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 stc			; Indicate failure

	 ret			; Return to caller

; 9:  CLI (BL=0) or STI (BL=1) handler CX:eDX, 0:0 = none

HDP_API9:
	 REGSAVE <eax,edx,es>	; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 push	 ds		; Save for a moment
	 push	 DTE_DS 	; Get PGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 mov	 al,DPMITYPE	; Get the client's type

	 pop	 ds		; Restore
	 assume  ds:nothing	; Tell the assembler about it

	 cmp	 al,@DPMITYPE16 ; Izit a 16-bit client?
	 jne	 short @F	; Jump if not

	 movzx	 edx,dx 	; Use DX
@@:
	 cmp	 bl,1		; Izit STI?
	 je	 short HDP_API9_STI ; Jump if so
	 ja	 short HDP_API9_ERR ; Jump if invalid

	 mov	 es:HDP_CLI.FOFF,edx ; Save the offset
	 mov	 es:HDP_CLI.FSEL,cx ; ...	 selector
	 mov	 es:HDP_CLITYP,al ; ...	 type
	 call	 HDP_GETOWN	; EDX = the client's TSS
	 mov	 es:HDP_CLIOWN,edx ; ... owner

	 jmp	 short HDP_API9_OK ; Join common code

HDP_API9_STI:
	 mov	 es:HDP_STI.FOFF,edx ; Save the offset
	 mov	 es:HDP_STI.FSEL,cx ; ...	 selector
	 mov	 es:HDP_STITYP,al ; ...	 type
	 call	 HDP_GETOWN	; EDX = the client's TSS
	 mov	 es:HDP_STIOWN,edx ; ... owner
HDP_API9_OK:
	 REGREST <es,edx,eax>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 call	 HDP_ACTIVATE	; Redirect the GP_ACT entries, set the IOPL

	 clc			; Indicate success

	 ret			; Return to caller

HDP_API9_ERR:
	 REGREST <es,edx,eax>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 stc			; Indicate failure

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_API endp			; End HDP_API procedure
	 NPPROC  HDP_GETOWN -- The Current Client's TSS
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

On exit:

EDX	 =	 PCURTSS

|

	 push	 ds		; Save for a moment
	 push	 DTE_DS 	; Get PGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 mov	 edx,PCURTSS	; Get the current TSS

	 pop	 ds		; Restore
	 assume  ds:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_GETOWN endp 		; End HDP_GETOWN procedure
	 NPPROC  HDP_DELRNG -- Remove a Trap Range
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Remove a trap range:  clear the bits of its ports which we set in the
I/O permission bit map, unless QPI traps the port, too.

On entry:

EDI	 =	 offset of the range in HDP_RNG (in use)

All registers preserved.

|

	 REGSAVE <ebx,ecx,edx,esi,ds,es> ; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 push	 DTE_DS 	; Get PGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 movzx	 ecx,es:HDP_RNG[edi].HDPR_CNT ; Get # ports
	 mov	 es:HDP_RNG[edi].HDPR_CNT,0 ; Free it
	 dec	 es:HDP_NRNG	; Count it out

	 movzx	 edx,es:HDP_RNG[edi].HDPR_PORT ; First port
	 cmp	 ecx,@HDP_NOWN	; Beyond what we remember?
	 jbe	 short @F	; Jump if not

	 mov	 ecx,@HDP_NOWN	; Clear only those
@@:
	 xor	 ebx,ebx	; Index in the range
HDP_DELRNG_BIT:
	 bt	 es:HDP_RNG[edi].HDPR_SET,ebx ; Did we set it?
	 jnc	 short HDP_DELRNG_NXT ; Jump if not

	 push	 edx		; Save for a moment
	 add	 edx,ebx	; The port
	 call	 HDP_QPIPORT	; Izit trapped via QPI (CF=1)?
	 jc	 short @F	; Jump if so (leave it)

	 mov	 esi,PIOBIT	; Get offset in PGROUP of I/O bit map
	 btr	 PGROUP:[esi],edx ; Untrap it
@@:
	 pop	 edx		; Restore
HDP_DELRNG_NXT:
	 inc	 ebx		; Next port
	 cmp	 ebx,ecx	; Done?
	 jb	 short HDP_DELRNG_BIT ; Jump if not

	 REGREST <es,ds,esi,edx,ecx,ebx> ; Restore
	 assume  ds:nothing,es:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_DELRNG endp 		; End HDP_DELRNG procedure
	 FPPROC  HDP_CLIENTEND -- A DPMI Client Terminates
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A DPMI client terminates (DPMIFN_TERMINATE in QMAX_I31):  remove its
trap ranges and CLI/STI handlers, as their selectors become invalid.
(HDPMI keeps them:  its clients going resident stay alive there as
they do here.)

On entry:

EDX	 =	 the client's TSS (PCURTSS)

All registers preserved.

|

	 REGSAVE <edi,es>	; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 test	 es:HDP_FLAG,@HDP_GPON ; Was the API ever used?
	 jz	 short HDP_CLIENTEND_EXIT ; Jump if not

	 xor	 edi,edi	; Start with the first range
HDP_CLIENTEND_NXT:
	 cmp	 es:HDP_RNG[edi].HDPR_CNT,0 ; Izit in use?
	 je	 short @F	; Jump if not

	 cmp	 edx,es:HDP_RNG[edi].HDPR_OWN ; Izit the client's?
	 jne	 short @F	; Jump if not

	 call	 HDP_DELRNG	; Remove it
@@:
	 add	 edi,size HDPR_STR ; Next range
	 cmp	 edi,@HDP_NRNG*(size HDPR_STR) ; Done?
	 jb	 short HDP_CLIENTEND_NXT ; Jump if not

	 cmp	 edx,es:HDP_CLIOWN ; The client's CLI handler?
	 jne	 short @F	; Jump if not

	 mov	 es:HDP_CLI.FSEL,0 ; Remove it
@@:
	 cmp	 edx,es:HDP_STIOWN ; The client's STI handler?
	 jne	 short @F	; Jump if not

	 mov	 es:HDP_STI.FSEL,0 ; Remove it
@@:
	 call	 HDP_ACTIVATE	; Set the IOPL
HDP_CLIENTEND_EXIT:
	 REGREST <es,edi>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_CLIENTEND endp		; End HDP_CLIENTEND procedure
	 NPPROC  HDP_ACTIVATE -- Redirect GP_ACT Entries, Set the IOPL
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

The first time a trap is installed, point the GP_ACT entries of
IN/OUT/INS/OUTS/CLI/STI to GP_HDPSTUB.	Then set the IOPL for DPMI
clients:  0 while a trap range or a CLI/STI handler is installed,
3 otherwise.

All registers preserved.

|

	 REGSAVE <eax,ebx,ecx,esi,ds,es> ; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 push	 DTE_DS 	; Get PGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:PGROUP	; Tell the assembler about it

	 test	 es:HDP_FLAG,@HDP_GPON ; Redirected already?
	 jnz	 short HDP_ACTIVATE_IOPL ; Jump if so

	 or	 es:HDP_FLAG,@HDP_GPON ; Mark as redirected

	 xor	 ecx,ecx	; Index in HDP_GPOPS
@@:
	 movzx	 esi,es:HDP_GPOPS[ecx] ; Get the opcode
	 mov	 ax,offset PGROUP:GP_HDPSTUB ; Our entry
	 xchg	 ax,GP_ACT[esi*2] ; Swap with the old one
	 mov	 es:HDP_GPOLD[ecx*2],ax ; Save it

	 inc	 ecx		; Next opcode
	 cmp	 ecx,@HDP_NGPOPS ; Done?
	 jb	 short @B	; Jump if not
HDP_ACTIVATE_IOPL:
	 mov	 eax,3 shl 12	; Assume IOPL 3

	 cmp	 es:HDP_NRNG,0	; Any trap ranges?
	 jne	 short @F	; Jump if so

	 cmp	 es:HDP_CLI.FSEL,0 ; A CLI handler?
	 jne	 short @F	; Jump if so

	 cmp	 es:HDP_STI.FSEL,0 ; An STI handler?
	 je	 short HDP_ACTIVATE_SET ; Jump if not
@@:
	 xor	 eax,eax	; IOPL 0
HDP_ACTIVATE_SET:
	 mov	 es:HDP_IOPLF,eax ; Save for JGROUP

	 push	 DTE_DSIG	; Get IGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:IGROUP	; Tell the assembler about it

	 mov	 DPMIOPLF,eax	; Save for IGROUP

	 REGREST <es,ds,esi,ecx,ebx,eax> ; Restore
	 assume  ds:nothing,es:nothing ; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_ACTIVATE endp		; End HDP_ACTIVATE procedure
	 NPPROC  HDP_QPIPORT -- Izit Trapped Via QPI?
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Is the port trapped via QPI (QMAX_QPI)?

On entry:

EDX	 =	 port

On exit:

CF	 =	 1 if so
	 =	 0 if not

All registers preserved.

|

	 REGSAVE <ecx,esi,fs>	; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 fs		; Address it
	 assume  fs:JGROUP	; Tell the assembler about it

	 movzx	 ecx,QPI_NPORT	; # ports trapped via QPI
	 xor	 esi,esi	; Index
	 jecxz	 HDP_QPIPORT_NO ; Jump if none
@@:
	 cmp	 dx,fs:QPI_PORT[esi*2] ; Izit this one?
	 je	 short HDP_QPIPORT_YES ; Jump if so

	 inc	 esi		; Next one
	 loop	 @B		; Jump if more
HDP_QPIPORT_NO:
	 clc			; Not trapped via QPI

	 jmp	 short HDP_QPIPORT_EXIT ; Join common exit code

HDP_QPIPORT_YES:
	 stc			; Trapped via QPI
HDP_QPIPORT_EXIT:
	 REGREST <fs,esi,ecx>	; Restore
	 assume  fs:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_QPIPORT endp		; End HDP_QPIPORT procedure
	 NPPROC  HDP_FINDRNG -- Find the Trap Range of a Port
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Find the trap range of a port.

On entry:

DX	 =	 port

On exit:

CF	 =	 0 if found
	 =	 1 if not
EDI	 =	 offset of the range in HDP_RNG (if found)

All other registers preserved.

|

	 REGSAVE <eax,es>	; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 xor	 edi,edi	; Start with the first range
	 cmp	 es:HDP_NRNG,0	; Any?
	 je	 short HDP_FINDRNG_NO ; Jump if not
@@:
	 mov	 ax,dx		; Copy the port
	 sub	 ax,es:HDP_RNG[edi].HDPR_PORT ; Less its first port
	 cmp	 ax,es:HDP_RNG[edi].HDPR_CNT ; Within the range?
	 jb	 short HDP_FINDRNG_EXIT ; Jump if so (CF=1)

	 add	 edi,size HDPR_STR ; Next range
	 cmp	 edi,@HDP_NRNG*(size HDPR_STR) ; Done?
	 jb	 short @B	; Jump if not
HDP_FINDRNG_NO:
	 clc			; Not found (complemented below)
HDP_FINDRNG_EXIT:
	 cmc			; CF=0 if found

	 REGREST <es,eax>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_FINDRNG endp		; End HDP_FINDRNG procedure
	 FPPROC  HDP_PORTUSED -- Izit Trapped Via the HDPMI API?
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Is the port trapped via the HDPMI API?  Called by QPI 1A0Ah, which
then leaves the port's bit set.

On entry:

DX	 =	 port

On exit:

CF	 =	 1 if so
	 =	 0 if not

All registers preserved.

|

	 push	 edi		; Save for a moment
	 call	 HDP_FINDRNG	; CF=0 if found
	 cmc			; CF=1 if found
	 pop	 edi		; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_PORTUSED endp		; End HDP_PORTUSED procedure
	 NPPROC  HDP_STRIO -- INS/OUTS for Function 8
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

INS/OUTS for function 8.

On entry:

BL	 =	 flags (see function 8)
DX	 =	 port
ECX	 =	 count (CX with 16-bit addressing)
DS:eSI ==>	 values (OUTS)
ES:eDI ==>	 buffer (INS)

On exit:

eSI, eDI, eCX as the instruction leaves them

|

	 test	 bl,40h 	; Izit 16-bit addressing?
	 jnz	 short HDP_STRIO16 ; Jump if so

	 test	 bl,01h 	; Izit OUTS?
	 jnz	 short HDP_STRIO32_OUT ; Jump if so

	 test	 bl,10h 	; Izit byte?
	 jnz	 short @F	; Jump if not

	 rep	 ins byte ptr es:[edi],dx ; Read the bytes

	 ret			; Return to caller

@@:
	 test	 bl,20h 	; Izit word?
	 jnz	 short @F	; Jump if not

	 rep	 ins word ptr es:[edi],dx ; Read the words

	 ret			; Return to caller

@@:
	 rep	 ins dword ptr es:[edi],dx ; Read the dwords

	 ret			; Return to caller

HDP_STRIO32_OUT:
	 test	 bl,10h 	; Izit byte?
	 jnz	 short @F	; Jump if not

	 rep	 outs dx,byte ptr ds:[esi] ; Write the bytes

	 ret			; Return to caller

@@:
	 test	 bl,20h 	; Izit word?
	 jnz	 short @F	; Jump if not

	 rep	 outs dx,word ptr ds:[esi] ; Write the words

	 ret			; Return to caller

@@:
	 rep	 outs dx,dword ptr ds:[esi] ; Write the dwords

	 ret			; Return to caller

HDP_STRIO16:
	 test	 bl,01h 	; Izit OUTS?
	 jnz	 short HDP_STRIO16_OUT ; Jump if so

	 test	 bl,10h 	; Izit byte?
	 jnz	 short @F	; Jump if not

	 rep	 ins byte ptr es:[di],dx ; Read the bytes

	 ret			; Return to caller

@@:
	 test	 bl,20h 	; Izit word?
	 jnz	 short @F	; Jump if not

	 rep	 ins word ptr es:[di],dx ; Read the words

	 ret			; Return to caller

@@:
	 rep	 ins dword ptr es:[di],dx ; Read the dwords

	 ret			; Return to caller

HDP_STRIO16_OUT:
	 test	 bl,10h 	; Izit byte?
	 jnz	 short @F	; Jump if not

	 rep	 outs dx,byte ptr ds:[si] ; Write the bytes

	 ret			; Return to caller

@@:
	 test	 bl,20h 	; Izit word?
	 jnz	 short @F	; Jump if not

	 rep	 outs dx,word ptr ds:[si] ; Write the words

	 ret			; Return to caller

@@:
	 rep	 outs dx,dword ptr ds:[si] ; Write the dwords

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_STRIO endp			; End HDP_STRIO procedure

	 FPPROC  HDP_GPIO -- I/O or CLI/STI General Protection Fault
	 assume  ds:PGROUP,es:AGROUP,fs:nothing,gs:nothing,ss:nothing
COMMENT|

General protection fault on IN/OUT/INS/OUTS/CLI/STI, called from
GP_HDPSTUB (QMAX_IOP) for the GP_ACT entries HDP_ACTIVATE redirected.

On entry:

EAX	 =	 opcode
BX	 =	 prefix flags ($$ES, ..., $$REP of QMAX_I0D)
ES:ESI	 ==>	 the byte after the opcode (AGROUP)
SS:EBP	 ==>	 INTXX_STR, INTXX_EIP past the opcode

On exit:

DI	 =	 where to continue in PGROUP:  the old GP_ACT entry (VM86
		 mode, or nothing for us to do), INT0D_IRETD (done) or
		 INT0D_UGHNF (call the trap handler as INT 0Dh handler)

All other registers preserved for the old entry.

|

	 test	 [ebp].INTXX_EFL.EHI,02h ; Izit from VM86 mode?
	 jnz	 near ptr HDP_GPIO_OLD ; Jump if so

	 test	 [ebp].INTXX_CS,4 ; Izit a GDT selector:  our own PL3 code
				; (e.g. the CLI in the vendor API stubs)?
	 jz	 near ptr HDP_GPIO_OLD ; Jump if so (as before)

	 cmp	 al,0FAh	; Izit CLI or STI?
	 jae	 near ptr HDP_GPIO_CLISTI ; Jump if so

	 REGSAVE <eax,ebx,ecx,edx,esi> ; Save registers

; CL	 =	 flags:  bit 0 = OUT, bit 1 = string, bit 2 = immediate port
; CH	 =	 HDPMI size bits (00h byte, 10h word, 30h dword)
; DL	 =	 1 if 32-bit operands, DH = 1 if 32-bit addresses

	 mov	 cl,al		; Copy the opcode
	 shr	 cl,1		; Bit 1 (OUT) to bit 0
	 and	 cl,01h 	; Isolate it

	 cmp	 al,0E0h	; Izit INS/OUTS?
	 jae	 short @F	; Jump if not

	 or	 cl,02h 	; Mark as string
@@:
	 cmp	 al,0E8h	; Izit IN/OUT with an immediate port?
	 jae	 short @F	; Jump if not

	 cmp	 al,0E0h	; ...
	 jb	 short @F	; Jump if not

	 or	 cl,04h 	; Mark as immediate
@@:
	 movzx	 edx,[ebp].INTXX_CS ; Get the code selector
	 lar	 edx,edx	; Get its access rights
	 shr	 edx,22 	; D bit to bit 0
	 and	 dl,1		; Isolate it
	 mov	 dh,dl		; Copy for addresses

	 test	 bx,$$OSP	; Operand size prefix?
	 jz	 short @F	; Jump if not

	 xor	 dl,1		; The other size
@@:
	 test	 bx,$$ASP	; Address size prefix?
	 jz	 short @F	; Jump if not

	 xor	 dh,1		; The other size
@@:
	 mov	 ch,00h 	; Assume byte

	 test	 al,01h 	; Izit word/dword?
	 jz	 short @F	; Jump if not

	 mov	 ch,10h 	; Assume word

	 cmp	 dl,1		; 32-bit operands?
	 jne	 short @F	; Jump if not

	 mov	 ch,30h 	; Dword
@@:

; The port in DX (later), the immediate one in AH

	 test	 cl,04h 	; Immediate?
	 jz	 short @F	; Jump if not

	 mov	 ah,AGROUP:[esi] ; Get the port
@@:
	 push	 edx		; Save the sizes
	 movzx	 edx,ah 	; Assume immediate port

	 test	 cl,04h 	; Immediate?
	 jnz	 short @F	; Jump if so

	 movzx	 edx,[ebp].INTXX_EDX.ELO ; Get the port
@@:
	 mov	 edi,edx	; Copy the port
	 pop	 edx		; Restore the sizes

; Is it trapped for the current client?

	 push	 edx		; Save the sizes
	 mov	 dx,di		; The port
	 push	 edi		; Save the port
	 call	 HDP_FINDRNG	; EDI = range if found (CF=0)
	 mov	 esi,edi	; Copy the range offset
	 pop	 edi		; Restore the port
	 pop	 edx		; Restore the sizes
	 jc	 near ptr HDP_GPIO_RAW ; Jump if not trapped

	 push	 ds		; Save for a moment
	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:JGROUP	; Tell the assembler about it

	 mov	 eax,HDP_RNG[esi].HDPR_OWN ; Get the owner's TSS
	 mov	 ah,HDP_RNG[esi].HDPR_TYPE ; ...	  type (EAX bits 8-15
				; aren't part of a TSS offset:  they are
				; compared on their own below)
	 pop	 ds		; Restore
	 assume  ds:PGROUP	; Tell the assembler about it

	 cmp	 ah,DPMITYPE	; Same type of client?
	 jne	 near ptr HDP_GPIO_RAW ; Jump if not

	 push	 ds		; Save for a moment
	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:JGROUP	; Tell the assembler about it

	 mov	 eax,HDP_RNG[esi].HDPR_OWN ; Get the owner's TSS

	 pop	 ds		; Restore
	 assume  ds:PGROUP	; Tell the assembler about it

	 call	 HDP_SAMECTX	; Izit the current client's context?
	 jne	 near ptr HDP_GPIO_RAW ; Jump if not

; Build HDPMI's error code in EAX

	 mov	 ax,[ebp].INTXX_OIPHI ; Original EIP, high-order word
	 shl	 eax,16 	; Shift to high-order word
	 mov	 ax,[ebp].INTXX_OIPLO ; Original EIP, low-order word
	 neg	 eax		; Negate to subtract
	 add	 eax,[ebp].INTXX_EIP ; Length up to the opcode

	 test	 cl,04h 	; Immediate?
	 jz	 short @F	; Jump if not

	 inc	 eax		; Count in the port byte
@@:
	 and	 eax,07h	; Bits 0-2:  length
	 or	 al,ch		; Bits 4-5:  size

	 test	 cl,02h 	; Izit a string instruction?
	 jz	 short HDP_GPIO_ERRIO ; Jump if not

	 or	 al,08h 	; Bit 3:  string

	 cmp	 dh,1		; 32-bit addresses?
	 je	 short @F	; Jump if so

	 or	 al,40h 	; Bit 6:  16-bit addresses
@@:
	 test	 bx,$$REP	; REP prefix?
	 jz	 short @F	; Jump if not

	 or	 al,80h 	; Bit 7:  REP
@@:
	 test	 cl,01h 	; Izit OUTS?
	 jz	 short HDP_GPIO_ERRX ; Jump if not

	 call	 HDP_SEGPFX	; AH = segment override prefix (0 = none)

	 jmp	 short HDP_GPIO_ERRX ; Join common code

HDP_GPIO_ERRIO:
	 test	 cl,04h 	; Immediate?
	 jz	 short HDP_GPIO_ERRX ; Jump if not

	 or	 al,40h 	; Bit 6:  port in bits 8-15
	 push	 edi		; Pass the port
	 mov	 ah,[esp].LO	; Bits 8-15:  port
	 add	 esp,4		; Strip it
HDP_GPIO_ERRX:
	 mov	 [ebp].INTXX_ERR,eax ; Save as the error code

; The handler to call instead of the client's INT 0Dh one

	 push	 es		; Save for a moment
	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 lea	 esi,HDP_RNG[esi].HDPR_IN ; Assume IN

	 test	 cl,01h 	; Izit OUT?
	 jz	 short @F	; Jump if not

	 add	 esi,HDPR_OUT-HDPR_IN ; Skip to OUT handler
@@:
	 bts	 DPMI_CPFHOOK.ELO,0Dh ; Mark INT 0Dh as hooked for INTCOM_DPMI_FAULT
	 setc	 al		; Remember whether it was

	 push	 ds		; Save for a moment
	 push	 DTE_DSIG	; Get IGROUP data selector
	 pop	 ds		; Address it
	 assume  ds:IGROUP	; Tell the assembler about it

	 mov	 HDP_OVRHOOK,al ; Save to restore in PMFLTCOM
	 mov	 HDP_OVRFLG,1	; Mark the vector as pending

	 mov	 eax,es:[esi].FOFF ; Get the offset
	 mov	 HDP_OVR32.FOFF,eax ; Save as 32-bit vector
	 mov	 HDP_OVR16.VOFF,ax ; ...	16-...
	 mov	 ax,es:[esi].FSEL ; Get the selector
	 mov	 HDP_OVR32.FSEL,ax ; Save as 32-bit vector
	 mov	 HDP_OVR16.VSEG,ax ; ...	16-...

	 pop	 ds		; Restore
	 pop	 es		; ...
	 assume  ds:PGROUP,es:AGROUP ; Tell the assembler about it

	 REGREST <esi,edx,ecx,ebx,eax> ; Restore

	 mov	 di,offset PGROUP:INT0D_UGHNF ; Call it as INT 0Dh handler

	 ret			; Return to caller

; Not trapped for this client:  do the I/O as it would have been done
; at IOPL 3.  EDI = port, CL, CH, DL, DH as above.

HDP_GPIO_RAW:
	 test	 cl,02h 	; Izit a string instruction?
	 jnz	 near ptr HDP_GPIO_RAWSTR ; Jump if so

	 mov	 edx,edi	; Copy the port
	 mov	 eax,[ebp].INTXX_EAX ; Get the value

	 test	 cl,01h 	; Izit OUT?
	 jnz	 short HDP_GPIO_RAWOUT ; Jump if so

	 cmp	 ch,10h 	; Izit word?
	 je	 short HDP_GPIO_INW ; Jump if so
	 ja	 short HDP_GPIO_IND ; Jump if dword

	 in	 al,dx		; Read the byte

	 jmp	 short HDP_GPIO_RAWX ; Join common code

HDP_GPIO_INW:
	 in	 ax,dx		; Read the word

	 jmp	 short HDP_GPIO_RAWX ; Join common code

HDP_GPIO_IND:
	 in	 eax,dx 	; Read the dword

	 jmp	 short HDP_GPIO_RAWX ; Join common code

HDP_GPIO_RAWOUT:
	 cmp	 ch,10h 	; Izit word?
	 je	 short HDP_GPIO_OUTW ; Jump if so
	 ja	 short HDP_GPIO_OUTD ; Jump if dword

	 out	 dx,al		; Write the byte

	 jmp	 short HDP_GPIO_RAWX ; Join common code

HDP_GPIO_OUTW:
	 out	 dx,ax		; Write the word

	 jmp	 short HDP_GPIO_RAWX ; Join common code

HDP_GPIO_OUTD:
	 out	 dx,eax 	; Write the dword
HDP_GPIO_RAWX:
	 mov	 [ebp].INTXX_EAX,eax ; Return the (partly) new value

	 test	 cl,04h 	; Immediate?
	 jz	 short HDP_GPIO_DONE ; Jump if not

	 inc	 [ebp].INTXX_EIP ; Skip past the port byte
HDP_GPIO_DONE:
	 REGREST <esi,edx,ecx,ebx,eax> ; Restore

	 mov	 di,offset PGROUP:INT0D_IRETD ; Done

	 ret			; Return to caller

; INS/OUTS:  with the caller's selectors, count and direction

HDP_GPIO_RAWSTR:
	 mov	 al,cl		; Copy the flags
	 and	 al,01h 	; Bit 0:  OUT
	 or	 al,ch		; Bits 4-5:  size

	 cmp	 dh,1		; 32-bit addresses?
	 je	 short @F	; Jump if so

	 or	 al,40h 	; Bit 6:  16-bit addresses
@@:
	 mov	 ecx,1		; Assume once

	 test	 bx,$$REP	; REP prefix?
	 jz	 short @F	; Jump if not

	 mov	 ecx,[ebp].INTXX_ECX ; Get the count
@@:
	 call	 HDP_SEGPFX	; AH = segment override prefix (0 = none)
	 mov	 edx,edi	; Copy the port

	 REGSAVE <ds,es>	; Save selectors
	 push	 ebx		; Save the prefix flags
	 mov	 es,[ebp].INTXX_ES ; The caller's ES
	 assume  es:nothing	; Tell the assembler about it

	 mov	 ds,[ebp].INTXX_DS ; Assume the caller's DS
	 assume  ds:nothing	; Tell the assembler about it

	 cmp	 ah,26h 	; ES?
	 jne	 short @F	; Jump if not

	 mov	 ds,[ebp].INTXX_ES ; Use the caller's ES
@@:
	 cmp	 ah,36h 	; SS?
	 jne	 short @F	; Jump if not

	 mov	 ds,[ebp].INTXX_SS ; Use the caller's SS
@@:
	 cmp	 ah,64h 	; FS?
	 jne	 short @F	; Jump if not

	 mov	 ds,[ebp].INTXX_FS ; Use the caller's FS
@@:
	 cmp	 ah,65h 	; GS?
	 jne	 short @F	; Jump if not

	 mov	 ds,[ebp].INTXX_GS ; Use the caller's GS
@@:
	 mov	 esi,[ebp].INTXX_ESI ; The caller's ESI
	 mov	 edi,[ebp].INTXX_EDI ; ...	   EDI
	 mov	 bl,al		; Function 8's flags

	 test	 [ebp].INTXX_EFL.ELO,0400h ; DF=1?
	 jz	 short @F	; Jump if not

	 std			; Backwards
@@:
	 call	 HDP_STRIO	; Do it
	 cld			; Forwards again

	 mov	 [ebp].INTXX_ESI,esi ; Return the new ESI
	 mov	 [ebp].INTXX_EDI,edi ; ...		 EDI

	 pop	 ebx		; Restore the prefix flags
	 REGREST <es,ds>	; Restore
	 assume  ds:PGROUP,es:AGROUP ; Tell the assembler about it

	 test	 bx,$$REP	; REP prefix?
	 jz	 short @F	; Jump if not

	 mov	 [ebp].INTXX_ECX,ecx ; Return the new count
@@:
	 jmp	 HDP_GPIO_DONE	; Join common code

; CLI/STI:  call the handler if there's one for this type of client

HDP_GPIO_CLISTI:
	 REGSAVE <eax,ebx,ecx,edx,esi,fs> ; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 fs		; Address it
	 assume  fs:JGROUP	; Tell the assembler about it

	 lea	 ebx,HDP_CLI	; Assume CLI
	 mov	 cl,HDP_CLITYP	; ...
	 mov	 edx,HDP_CLIOWN ; ...

	 cmp	 al,0FAh	; Izit CLI?
	 je	 short @F	; Jump if so

	 lea	 ebx,HDP_STI	; It's STI
	 mov	 cl,HDP_STITYP	; ...
	 mov	 edx,HDP_STIOWN ; ...
@@:
	 cmp	 fs:[ebx].FSEL,0 ; Izit installed?
	 je	 near ptr HDP_GPIO_CSOLD ; Jump if not

	 cmp	 cl,DPMITYPE	; For this type of client?
	 jne	 near ptr HDP_GPIO_CSOLD ; Jump if not

	 xchg	 eax,edx	; EAX = the owner's TSS, EDX = opcode
	 call	 HDP_SAMECTX	; Izit the current client's context?
	 xchg	 eax,edx	; Restore (flags unchanged)
	 jne	 near ptr HDP_GPIO_CSOLD ; Jump if not

; Change IF as the instruction would

	 and	 [ebp].INTXX_EFL,not 0200h ; IF=0

	 cmp	 al,0FAh	; Izit CLI?
	 je	 short @F	; Jump if so

	 or	 [ebp].INTXX_EFL,0200h ; IF=1
@@:

; Push an IRET frame onto the caller's stack

	 movzx	 esi,[ebp].INTXX_SS ; Get the stack selector
	 FIXICALL JGROUP:FSEGSEL_BASE,DTE_CSJG ; Return with ESI = base
				; (EDX clobbered)
	 movzx	 edx,[ebp].INTXX_SS ; Get the stack selector again
	 lar	 edx,edx	; Get its access rights (B bit)

	 mov	 eax,[ebp].INTXX_ESP ; Get the stack pointer
	 mov	 ecx,12 	; Size of an IRETD frame

	 cmp	 DPMITYPE,@DPMITYPE16 ; Izit a 16-bit client?
	 jne	 short @F	; Jump if not

	 mov	 ecx,6		; Size of an IRET frame
@@:
	 sub	 eax,ecx	; Make room

	 test	 edx,1 shl 22	; Izit a 32-bit stack?
	 jnz	 short @F	; Jump if so

	 movzx	 eax,ax 	; Use SP (64KB wrap)
	 mov	 [ebp].INTXX_ESP,eax ; Save the new SP, high-order word 0:
				; a 32-bit handler addresses the frame with
				; ESP (DOS/4GW runs on a 16-bit stack with
				; garbage in the high-order word of ESP)

	 jmp	 short HDP_GPIO_CSFRM ; Join common code

@@:
	 mov	 [ebp].INTXX_ESP,eax ; Save the new ESP
HDP_GPIO_CSFRM:
	 add	 esi,eax	; ES:ESI ==> the frame (AGROUP)

	 cmp	 ecx,6		; Izit an IRET frame?
	 je	 short @F	; Jump if so

	 mov	 eax,[ebp].INTXX_EIP ; Return EIP (past CLI/STI)
	 mov	 AGROUP:[esi+0],eax ; Save in the frame
	 movzx	 eax,[ebp].INTXX_CS ; Return CS
	 mov	 AGROUP:[esi+4],eax ; Save in the frame
	 mov	 eax,[ebp].INTXX_EFL ; Flags
	 mov	 AGROUP:[esi+8],eax ; Save in the frame

	 mov	 eax,fs:[ebx].FOFF ; Get the handler's offset

	 jmp	 short HDP_GPIO_CSGO ; Join common code

@@:
	 mov	 ax,[ebp].INTXX_EIP.ELO ; Return IP (past CLI/STI)
	 mov	 AGROUP:[esi+0],ax ; Save in the frame
	 mov	 ax,[ebp].INTXX_CS ; Return CS
	 mov	 AGROUP:[esi+2],ax ; Save in the frame
	 mov	 ax,[ebp].INTXX_EFL.ELO ; Flags
	 mov	 AGROUP:[esi+4],ax ; Save in the frame

	 movzx	 eax,fs:[ebx].FOFF.ELO ; Get the handler's offset
HDP_GPIO_CSGO:
	 mov	 [ebp].INTXX_EIP,eax ; Continue there
	 mov	 ax,fs:[ebx].FSEL ; ...
	 mov	 [ebp].INTXX_CS,ax ; ...

; On a 16-bit stack go through PMHDPCLI (QMAX_DIF), which clears ESP's
; high-order word:  the handler's address below the IRET frame

	 test	 edx,1 shl 22	; Izit a 32-bit stack?
	 jnz	 short HDP_GPIO_CSX ; Jump if so

	 mov	 eax,[ebp].INTXX_EIP ; The handler's offset
	 mov	 AGROUP:[esi-8],eax ; Below the frame
	 mov	 ax,[ebp].INTXX_CS ; The handler's selector
	 mov	 AGROUP:[esi-8+4],ax ; ...
	 mov	 [ebp].INTXX_EIP,PMHDPCLI ; Continue in our stub
	 mov	 ax,DPMI_IDEF	; ...
	 mov	 [ebp].INTXX_CS,ax ; ...
HDP_GPIO_CSX:

	 REGREST <fs,esi,edx,ecx,ebx,eax> ; Restore
	 assume  fs:nothing	; Tell the assembler about it

	 mov	 di,offset PGROUP:INT0D_IRETD ; Done

	 ret			; Return to caller

HDP_GPIO_CSOLD:
	 REGREST <fs,esi,edx,ecx,ebx,eax> ; Restore
	 assume  fs:nothing	; Tell the assembler about it
HDP_GPIO_OLD:
	 push	 ecx		; Save for a moment
	 push	 es		; ...

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 xor	 ecx,ecx	; Index in HDP_GPOPS
@@:
	 cmp	 al,es:HDP_GPOPS[ecx] ; Izit this opcode?
	 je	 short @F	; Jump if so

	 inc	 ecx		; Next one
	 cmp	 ecx,@HDP_NGPOPS-1 ; The last one?
	 jb	 short @B	; Jump if not
@@:
	 mov	 di,es:HDP_GPOLD[ecx*2] ; Get the old entry

	 pop	 es		; Restore
	 assume  es:AGROUP	; Tell the assembler about it
	 pop	 ecx		; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_GPIO endp			; End HDP_GPIO procedure
	 NPPROC  HDP_SAMECTX -- Izit the Current Client's Context?
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

Is the TSS the current client's or one sharing its context (the same
LDT, HDPMI API function 5)?

On entry:

EAX	 =	 offset in PGROUP of the TSS

On exit:

ZF	 =	 1 if so
	 =	 0 if not

All registers preserved.

|

	 cmp	 eax,PCURTSS	; Izit the current client?
	 je	 short HDP_SAMECTX_EXIT ; Jump if so (ZF=1)

	 push	 ebx		; Save for a moment
	 mov	 ebx,PCURTSS	; Get the current TSS
	 mov	 bx,PGROUP:[ebx].TSS_LDT ; Its LDT
	 cmp	 bx,PGROUP:[eax].TSS_LDT ; The same?
	 pop	 ebx		; Restore
HDP_SAMECTX_EXIT:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_SAMECTX endp		; End HDP_SAMECTX procedure
	 FPPROC  HDP_SHRCHK -- Does a New Client Share Its Parent's Context?
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A new client (INT31_VM2PM in QMAX_I31) shares its parent's context
(LDT, address space, PM interrupt and exception vectors) if the HDPMI=32
flag is 0 (HDPMI API function 5, BL=0, as VSBHDA sets it), the parent is
a DPMI client, and both have the same bitness.

On entry:

EDX	 =	 offset in PGROUP of the new TSS (DPTSS_PLNKTSS = parent)
DPMITYPE =	 the new client's type, DPMITYPEIG the parent's

On exit:

EAX	 =	 offset in PGROUP of the TSS whose context we share, 0 if none

|

	 xor	 eax,eax	; Assume not

	 REGSAVE <ebx,ds,es>	; Save registers

	 push	 DTE_DSJG	; Get JGROUP data selector
	 pop	 es		; Address it
	 assume  es:JGROUP	; Tell the assembler about it

	 cmp	 es:HDP_SEP,0	; Shared contexts?
	 jne	 short HDP_SHRCHK_EXIT ; Jump if not

	 mov	 ebx,PGROUP:[edx].DPTSS_PLNKTSS ; Get the parent
	 cmp	 ebx,PVMTSS	; Izit a DPMI client?
	 je	 short HDP_SHRCHK_EXIT ; Jump if not

	 test	 PGROUP:[ebx].DPTSS_FLAG,mask $DPTSS_INIT ; Izit initialized?
	 jz	 short HDP_SHRCHK_EXIT ; Jump if not

	 push	 DTE_DSIG	; Get IGROUP data selector
	 pop	 es		; Address it
	 assume  es:IGROUP	; Tell the assembler about it

	 mov	 al,DPMITYPE	; Get the new client's type
	 cmp	 al,es:DPMITYPEIG ; Same as the parent's?
	 mov	 eax,0		; Assume not
	 jne	 short HDP_SHRCHK_EXIT ; Jump if not

	 mov	 eax,PGROUP:[ebx].DPTSS_SHRTSS ; The one the parent shares
	 or	 eax,eax	; Izit shared?
	 jnz	 short HDP_SHRCHK_EXIT ; Jump if so

	 mov	 eax,ebx	; The parent's own
HDP_SHRCHK_EXIT:
	 REGREST <es,ds,ebx>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_SHRCHK endp 		; End HDP_SHRCHK procedure
	 FPPROC  HDP_SHRVMM -- Use the Shared Address Space
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A new client sharing a context uses its address space (page directory,
free list through LSM_GET_CLIENT_LIST, VMM owner) instead of
VMM_INIT_CLIENT's own.

On entry:

EDX	 =	 offset in PGROUP of the new TSS (DPTSS_SHRTSS set)

All registers preserved.

|

	 REGSAVE <eax,ebx,es>	; Save registers

	 mov	 ebx,PGROUP:[edx].DPTSS_SHRTSS ; Get the TSS we share
	 mov	 eax,PGROUP:[ebx].TSS_CR3 ; Its page directory
	 mov	 PGROUP:[edx].TSS_CR3,eax ; Ours

	 push	 DTE_DSIG	; Get IGROUP data selector
	 pop	 es		; Address it
	 assume  es:IGROUP	; Tell the assembler about it

	 mov	 ax,PGROUP:[ebx].DPTSS_SEL ; The VMM's client id
	 mov	 es:VMMcurrentClient,ax ; Is the shared one's

	 REGREST <es,ebx,eax>	; Restore
	 assume  es:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_SHRVMM endp 		; End HDP_SHRVMM procedure
	 FPPROC  HDP_SHRLDT -- Use the Parent's LDT
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A new client sharing its parent's context uses the parent's LDT.
Remember which entries are in use, so that the client's own ones can
be freed when it terminates (HDP_SHREND).

On entry:

EDX	 =	 offset in PGROUP of the new TSS (DPTSS_PLNKTSS = parent)

On exit:

CF	 =	 0 if successful
	 =	 1 if no memory for the bitmap

|

	 REGSAVE <eax,ebx,ecx,esi,edi,es> ; Save registers

	 mov	 ebx,PGROUP:[edx].DPTSS_PLNKTSS ; Get the parent

	 mov	 ax,PGROUP:[ebx].TSS_LDT ; Its LDT selector
	 mov	 PGROUP:[edx].TSS_LDT,ax ; Use it
	 lldt	 ax		; Tell the CPU about it
	 mov	 eax,PGROUP:[ebx].DPTSS_LaLDT ; Its linear address
	 mov	 PGROUP:[edx].DPTSS_LaLDT,eax ; Use it
	 mov	 eax,PGROUP:[ebx].DPTSS_LDT_SIZ ; Its size
	 mov	 PGROUP:[edx].DPTSS_LDT_SIZ,eax ; Use it

; The bitmap of the entries in use

	 shr	 eax,3-0	; # entries
	 mov	 PGROUP:[edx].DPTSS_LDTSNAPN,eax ; Save it
	 add	 eax,8*@DPMI_BOUND-1 ; Round up to the allocation unit
	 shr	 eax,3-0	; # bytes
	 and	 eax,not (@DPMI_BOUND-1) ; ...(as DPMIFN_FREEMEM does)

	 push	 @ALLOC_DPMI	; Tell 'em what kind of memory we're allocating
	 push	 eax		; Pass # bytes to allocate
	 FIXICALL PGROUP:FALLOCMEM,DTE_CS2 ; Allocate 'em
				; Return with EBX = linear address of memory
	 jc	 short HDP_SHRLDT_EXIT ; Jump if no memory found

	 mov	 PGROUP:[edx].DPTSS_LDTSNAP,ebx ; Save for later use

	 push	 DTE_D4GB	; Get all memory selector
	 pop	 es		; Address it
	 assume  es:AGROUP	; Tell the assembler about it

	 mov	 esi,PGROUP:[edx].DPTSS_LaLDT ; AGROUP:ESI ==> LDT
	 xor	 ecx,ecx	; Entry index
@@:
	 btr	 AGROUP:[ebx],ecx ; Assume free

	 mov	 eax,AGROUP:[esi+ecx*8].EDQLO ; Get the low half
	 or	 eax,AGROUP:[esi+ecx*8].EDQHI ; ...	 high ...
	 jz	 short HDP_SHRLDT_NXT ; Jump if free

	 bts	 AGROUP:[ebx],ecx ; In use
HDP_SHRLDT_NXT:
	 inc	 ecx		; Next entry
	 cmp	 ecx,PGROUP:[edx].DPTSS_LDTSNAPN ; Done?
	 jb	 short @B	; Jump if not

	 clc			; Indicate success
HDP_SHRLDT_EXIT:
	 REGREST <es,edi,esi,ecx,ebx,eax> ; Restore
	 assume  es:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_SHRLDT endp 		; End HDP_SHRLDT procedure
	 FPPROC  HDP_SHREND -- A Client Sharing Its Parent's Context Ends
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

A client sharing its parent's context terminates (or fails to start):
free the LDT entries it allocated (those not in use when it started),
free the bitmap, and give the LDT's address and size (it may have
grown) to the clients sharing it.  Instead of DPMIFN_FREELDT and
VMM_TERMINATE_CLIENT:  the LDT and the address space stay.

On entry:

EDX	 =	 offset in PGROUP of the TSS

|

	 REGSAVE <eax,ebx,ecx,esi,edi,es> ; Save registers

	 mov	 ebx,PGROUP:[edx].DPTSS_LDTSNAP ; Get the bitmap
	 or	 ebx,ebx	; Izit there?
	 jz	 near ptr HDP_SHREND_SYNC ; Jump if not

	 push	 DTE_D4GB	; Get all memory selector
	 pop	 es		; Address it
	 assume  es:AGROUP	; Tell the assembler about it

	 mov	 esi,PGROUP:[edx].DPTSS_LaLDT ; AGROUP:ESI ==> LDT
	 mov	 edi,PGROUP:[edx].DPTSS_LDT_SIZ ; Size of the LDT
	 add	 edi,esi	; AGROUP:EDI ==> its trailing bitmap
	 mov	 eax,PGROUP:[edx].DPTSS_LDT_SIZ ; Size of the LDT
	 shr	 eax,3-0	; # entries now
	 xor	 ecx,ecx	; Entry index
HDP_SHREND_NXT:
	 cmp	 ecx,PGROUP:[edx].DPTSS_LDTSNAPN ; Beyond the bitmap?
	 jae	 short @F	; Jump if so (the client's)

	 bt	 AGROUP:[ebx],ecx ; Was it in use?
	 jc	 short HDP_SHREND_KEEP ; Jump if so
@@:
	 mov	 AGROUP:[esi+ecx*8].EDQLO,0 ; Free it
	 mov	 AGROUP:[esi+ecx*8].EDQHI,0 ; ...
	 btr	 AGROUP:[edi],ecx ; Not a segment selector
HDP_SHREND_KEEP:
	 inc	 ecx		; Next entry
	 cmp	 ecx,eax	; Done?
	 jb	 short HDP_SHREND_NXT ; Jump if not

	 mov	 eax,PGROUP:[edx].DPTSS_LDTSNAPN ; # entries
	 add	 eax,8*@DPMI_BOUND-1 ; Round up to the allocation unit
	 shr	 eax,3-0	; # bytes
	 and	 eax,not (@DPMI_BOUND-1) ; ...(as DPMIFN_FREEMEM does)

	 push	 eax		; Pass byte length
	 push	 ebx		; Pass linear address
	 FIXICALL PGROUP:FDEALLOCMEM,DTE_CS2 ; Deallocate the memory

	 mov	 PGROUP:[edx].DPTSS_LDTSNAP,0 ; Gone
HDP_SHREND_SYNC:
	 FIXICALL JGROUP:HDP_SYNCLDT,DTE_CSJG ; The LDT's address and size

	 REGREST <es,edi,esi,ecx,ebx,eax> ; Restore
	 assume  es:nothing	; Tell the assembler about it

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_SHREND endp 		; End HDP_SHREND procedure
	 FPPROC  HDP_SYNCLDT -- Give the LDT's Address and Size to Its Sharers
	 assume  ds:PGROUP,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

The LDT of a TSS may have grown (DPMIFN_GROWLDT in QMAX_M31):  copy its
address and size to all TSSs using the same LDT.

On entry:

EDX	 =	 offset in PGROUP of the TSS

All registers preserved.

|

	 REGSAVE <eax,ecx,esi>	; Save registers

	 mov	 esi,PVMTSS	; Get offset in PGROUP of the 1st TSS
	 mov	 ecx,@TSS_MAX	; # TSSs
HDP_SYNCLDT_NXT:
	 cmp	 esi,edx	; Izit this one?
	 je	 short @F	; Jump if so

	 cmp	 PGROUP:[esi].TSS_LINK,-1 ; Izit in use?
	 je	 short @F	; Jump if not

	 mov	 ax,PGROUP:[esi].TSS_LDT ; Its LDT
	 cmp	 ax,PGROUP:[edx].TSS_LDT ; The same?
	 jne	 short @F	; Jump if not

	 mov	 eax,PGROUP:[edx].DPTSS_LaLDT ; Address
	 mov	 PGROUP:[esi].DPTSS_LaLDT,eax ; ...
	 mov	 eax,PGROUP:[edx].DPTSS_LDT_SIZ ; Size
	 mov	 PGROUP:[esi].DPTSS_LDT_SIZ,eax ; ...
@@:
	 add	 esi,type DPTSS_STR ; Next TSS
	 loop	 HDP_SYNCLDT_NXT ; Jump if more

	 REGREST <esi,ecx,eax>	; Restore

	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_SYNCLDT endp		; End HDP_SYNCLDT procedure
	 FPPROC  HDP_IRETD -- IRETD with a Clean ESP on 16-bit Stacks
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

IRETD to a PL3 caller whose stack is 16-bit.  The CPU loads only SP
there:  ESP's high-order word stays the one of our PL0 stack, which is
above 64KB in PGROUP.  32-bit code on such a stack that addresses it
with ESP (VSBHDA's INT 31h hook called by DOS/4GW) then runs into the
segment limit.  As HDPMI does (its PL0 stack is below 64KB), make that
word 0:  switch to the alias DTE_ESPFIX whose base is our stack's base
plus ESP's high-order word, so the frame stays at the same linear
address and ESP's high-order word becomes 0 (Linux calls this espfix).

Jumped to (FIXIJMP) instead of IRETD, with SS:ESP ==> the IRETD frame
and all registers as for the IRETD.

|

IRETD_STR struc
IRETD_EIP dd	 ?		; EIP
IRETD_CS dw	 ?,?		; CS w/filler
IRETD_EFL dd	 ?		; EFL
IRETD_ESP dd	 ?		; ESP
IRETD_SS dw	 ?,?		; SS w/filler
IRETD_STR ends

	 push	 eax		; Save for a moment

	 test	 [esp+4].IRETD_EFL,2 shl 16 ; Izit to VM86 mode?
	 jnz	 near ptr HDP_IRETD_PLAIN ; Jump if so

	 test	 [esp+4].IRETD_CS,3 ; Izit to PL0 (no stack in the frame)?
	 jz	 near ptr HDP_IRETD_PLAIN ; Jump if so

	 test	 esp,0FFFF0000h ; Izit our ESP's high-order word 0 already?
	 jz	 near ptr HDP_IRETD_PLAIN ; Jump if so

	 movzx	 eax,[esp+4].IRETD_SS ; Get the caller's SS
	 lar	 eax,eax	; Get its access rights
	 jnz	 near ptr HDP_IRETD_PLAIN ; Jump if invalid (let IRETD fault)

	 test	 eax,1 shl 22	; Izit a 32-bit stack?
	 jnz	 near ptr HDP_IRETD_PLAIN ; Jump if so

; DTE_ESPFIX:  base = our stack's base + ESP's high-order word, 64KB

	 REGSAVE <ebx,ecx,ds>	; Save registers

	 push	 DTE_D4GB	; Get all memory selector
	 pop	 ds		; Address it
	 assume  ds:AGROUP	; Tell the assembler about it

	 sub	 esp,8		; Room for the GDTR
	 SGDTD	 [esp].EDF	; Get it
	 mov	 ebx,[esp+2]	; GDT base
	 add	 esp,8		; Strip

	 mov	 ecx,ss 	; Our stack selector
	 and	 ecx,not 7	; Its offset in the GDT
	 mov	 eax,AGROUP:[ebx+ecx+2] ; Base bits 0-23 (and access)
	 and	 eax,00FFFFFFh	; Isolate the base
	 mov	 cl,AGROUP:[ebx+ecx+7] ; Base bits 24-31
	 shl	 ecx,24 	; ...
	 or	 eax,ecx	; Our stack's base
	 mov	 ecx,esp	; Our ESP
	 and	 ecx,0FFFF0000h ; Its high-order word
	 add	 eax,ecx	; The alias's base

	 add	 ebx,DTE_ESPFIX ; The alias's descriptor
	 mov	 AGROUP:[ebx+0].ELO,0FFFFh ; Limit 64KB
	 mov	 AGROUP:[ebx+2].ELO,ax ; Base bits 0-15
	 shr	 eax,16 	; Base bits 16-31
	 mov	 AGROUP:[ebx+4].LO,al ; Base bits 16-23
	 mov	 AGROUP:[ebx+5].LO,92h ; Present, DPL 0, data R/W
	 mov	 AGROUP:[ebx+6].LO,0 ; Byte granular, 16-bit, limit bits 16-19 = 0
	 mov	 AGROUP:[ebx+7].LO,ah ; Base bits 24-31

	 REGREST <ds,ecx,ebx>	; Restore
	 assume  ds:nothing	; Tell the assembler about it

	 cli			; No interrupts on the alias
	 mov	 eax,DTE_ESPFIX ; The alias
	 mov	 ss,ax		; Switch to it (no interrupt before the next)
	 and	 esp,0FFFFh	; The same linear address, high-order word 0
HDP_IRETD_PLAIN:
	 pop	 eax		; Restore

	 iretd			; Return (flags from the frame)

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_IRETD endp			; End HDP_IRETD procedure
	 NPPROC  HDP_SEGPFX -- Segment Override Prefix of the Instruction
	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing
COMMENT|

The segment override prefix of the instruction as an opcode.

On entry:

BX	 =	 prefix flags

On exit:

AH	 =	 26h, 2Eh, 36h, 3Eh, 64h, 65h, or 0 if none

|

	 mov	 ah,26h 	; Assume ES
	 test	 bx,$$ES	; Izit ES?
	 jnz	 short HDP_SEGPFX_EXIT ; Jump if so

	 mov	 ah,2Eh 	; Assume CS
	 test	 bx,$$CS	; Izit CS?
	 jnz	 short HDP_SEGPFX_EXIT ; Jump if so

	 mov	 ah,36h 	; Assume SS
	 test	 bx,$$SS	; Izit SS?
	 jnz	 short HDP_SEGPFX_EXIT ; Jump if so

	 mov	 ah,3Eh 	; Assume DS
	 test	 bx,$$DS	; Izit DS?
	 jnz	 short HDP_SEGPFX_EXIT ; Jump if so

	 mov	 ah,64h 	; Assume FS
	 test	 bx,$$FS	; Izit FS?
	 jnz	 short HDP_SEGPFX_EXIT ; Jump if so

	 mov	 ah,65h 	; Assume GS
	 test	 bx,$$GS	; Izit GS?
	 jnz	 short HDP_SEGPFX_EXIT ; Jump if so

	 mov	 ah,0		; None
HDP_SEGPFX_EXIT:
	 ret			; Return to caller

	 assume  ds:nothing,es:nothing,fs:nothing,gs:nothing,ss:nothing

HDP_SEGPFX endp 		; End HDP_SEGPFX procedure

JCODE	 ends			; End JCODE segment

	 MEND			; End QMAX_HDP module

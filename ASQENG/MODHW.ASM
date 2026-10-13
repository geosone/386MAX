	 TITLE	 MODHW
	 page	 58,122
	 name	 MODHW

COMMENT|		Module Specifications

Open 386MAX - GNU General Public License version 3.

BIOS and CPU access with 32-bit registers for the reports on newer
hardware (MODINFO.C): E820/E801 memory map, CPUID, PCI BIOS configuration
reads and copies from physical memory above 1 MB (INT 15h AH=87h).  All
functions need a 386 or later; the caller checks the CPU.

C prototypes (far pascal), see MODINFO.H.

|
	.MODEL	LARGE,PASCAL
	.386
	.CODE

; int pascal far MODHW_E820(DWORD far *cont, void far *buf);
; One entry of the E820 memory map into buf (24 bytes, ACPI 3 attributes
; preset to 1).  *cont: 0 for the first call, then the value returned by
; the BIOS.  Return: bytes stored (20 or 24), 0 if no (more) entry.
MODHW_E820 PROC USES di si,cont:dword,buf:dword
	push	ds
	les	di,buf
	mov	dword ptr es:[di+20],1	; Attributes if the BIOS stores 20 bytes
	lds	si,cont
	mov	ebx,[si]
	mov	eax,0E820h
	mov	ecx,24
	mov	edx,534D4150h		; 'SMAP'
	int	15h
	jc	short E820_NO
	cmp	eax,534D4150h
	jne	short E820_NO
	lds	si,cont
	mov	[si],ebx
	mov	ax,cx			; Bytes stored
	cmp	ax,20
	jb	short E820_NO
	jmp	short E820_X
E820_NO:
	xor	ax,ax
E820_X:
	pop	ds
	ret
MODHW_E820 ENDP

; int pascal far MODHW_E801(WORD far *res);
; res[0] = KB 1-16 MB, res[1] = 64 KB blocks above 16 MB (AX/BX or CX/DX).
; Return: 1 if supported.
MODHW_E801 PROC USES di,res:dword
	xor	cx,cx
	xor	dx,dx
	mov	ax,0E801h
	int	15h
	jc	short E801_NO
	jcxz	@F			; Some BIOSes return only CX/DX ...
	mov	ax,cx
	mov	bx,dx
@@:
	les	di,res
	mov	es:[di],ax
	mov	es:[di+2],bx
	mov	ax,1
	ret
E801_NO:
	xor	ax,ax
	ret
MODHW_E801 ENDP

; int pascal far MODHW_HASCPUID(void);
; Return: 1 if the ID flag in EFLAGS can be changed (CPUID available).
MODHW_HASCPUID PROC
	pushfd
	pushfd
	pop	eax
	mov	ecx,eax
	xor	eax,200000h		; Toggle ID
	push	eax
	popfd
	pushfd
	pop	eax
	popfd
	xor	eax,ecx
	shr	eax,21
	and	ax,1
	ret
MODHW_HASCPUID ENDP

; void pascal far MODHW_CPUID(DWORD leaf, DWORD far *regs);
; regs[0..3] = EAX, EBX, ECX, EDX of CPUID leaf (ECX = 0).
MODHW_CPUID PROC USES di,leaf:dword,regs:dword
	push	ebx
	mov	eax,leaf
	xor	ecx,ecx
	db	0Fh,0A2h		; CPUID
	les	di,regs
	mov	es:[di],eax
	mov	es:[di+4],ebx
	mov	es:[di+8],ecx
	mov	es:[di+12],edx
	pop	ebx
	ret
MODHW_CPUID ENDP

; int pascal far MODHW_PCIBIOS(WORD far *info);
; PCI BIOS installation check (INT 1Ah AX=B101h): info[0] = version (BCD),
; info[1] = last bus, info[2] = hardware mechanisms.  Return: 1 if present.
MODHW_PCIBIOS PROC USES di si,info:dword
	push	ebx
	xor	edi,edi
	mov	ax,0B101h
	int	1Ah
	jc	short PB_NO
	or	ah,ah
	jnz	short PB_NO
	cmp	edx,20494350h		; 'PCI '
	jne	short PB_NO
	xor	ch,ch
	les	di,info
	mov	es:[di],bx
	mov	es:[di+2],cx
	xor	ah,ah
	mov	es:[di+4],ax
	mov	ax,1
	jmp	short PB_X
PB_NO:
	xor	ax,ax
PB_X:
	pop	ebx
	ret
MODHW_PCIBIOS ENDP

; DWORD pascal far MODHW_PCIREAD(WORD busdevfn, WORD reg);
; Configuration dword reg (multiple of 4) of bus (high byte) / device and
; function (low byte), INT 1Ah AX=B10Ah.  Return: the value, 0FFFFFFFFh on
; error.
MODHW_PCIREAD PROC USES di,busdevfn:word,reg:word
	push	ebx
	mov	bx,busdevfn
	mov	di,reg
	mov	ax,0B10Ah
	int	1Ah
	jc	short PR_ERR
	or	ah,ah
	jz	short PR_OK
PR_ERR:
	mov	ecx,-1
PR_OK:
	mov	ax,cx
	shr	ecx,16
	mov	dx,cx
	pop	ebx
	ret
MODHW_PCIREAD ENDP

; int pascal far MODHW_XMOVE(DWORD phys, void far *dst, WORD bytes);
; Copy bytes (even, <= 65534) from physical address phys (below 4 GB) to
; dst with INT 15h AH=87h.  Return: 1 if done.
GDTE	struc
GD_LIM	dw	?
GD_BASL dw	?
GD_BASM db	?
GD_ACC	db	?
GD_LIMH db	?
GD_BASH db	?
GDTE	ends

MODHW_XMOVE PROC USES si di,phys:dword,dst:dword,bytes:word
	LOCAL	gdt[6]:GDTE
	push	ss
	pop	es
	lea	di,gdt
	mov	cx,(6*(size GDTE))/2
	xor	ax,ax
	rep	stosw			; All descriptors zero
	mov	ax,bytes
	dec	ax			; Limit
	mov	gdt[2*(size GDTE)].GD_LIM,ax	; Source
	mov	gdt[3*(size GDTE)].GD_LIM,ax	; Destination
	mov	eax,phys
	mov	gdt[2*(size GDTE)].GD_BASL,ax
	shr	eax,16
	mov	gdt[2*(size GDTE)].GD_BASM,al
	mov	gdt[2*(size GDTE)].GD_BASH,ah
	mov	gdt[2*(size GDTE)].GD_ACC,93h
	movzx	eax,word ptr dst+2	; Linear address of dst
	shl	eax,4
	movzx	edx,word ptr dst
	add	eax,edx
	mov	gdt[3*(size GDTE)].GD_BASL,ax
	shr	eax,16
	mov	gdt[3*(size GDTE)].GD_BASM,al
	mov	gdt[3*(size GDTE)].GD_BASH,ah
	mov	gdt[3*(size GDTE)].GD_ACC,93h
	lea	si,gdt			; ES:SI -> GDT
	mov	cx,bytes
	shr	cx,1			; Words
	mov	ah,87h
	int	15h
	mov	ax,0
	jc	short XM_X
	inc	ax
XM_X:
	ret
MODHW_XMOVE ENDP

	END

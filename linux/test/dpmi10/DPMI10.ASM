; DPMI10.ASM - calls the DPMI 1.0 functions of the active DPMI host
; (16-bit client), prints OK or FAIL (error code) for each and a summary.
; Build: jwasm -mz DPMI10.ASM

	.model	small
	.386
	.stack	1024

RMREGS	struc
r_edi	dd ?
r_esi	dd ?
r_ebp	dd ?
	dd ?
r_ebx	dd ?
r_edx	dd ?
r_ecx	dd ?
r_eax	dd ?
r_flags	dw ?
r_es	dw ?
r_ds	dw ?
r_fs	dw ?
r_gs	dw ?
r_ip	dw ?
r_cs	dw ?
r_sp	dw ?
r_ss	dw ?
RMREGS	ends

	.data
rmseg	dw ?
entry	dd ?
nfail	dw 0
rm	RMREGS <>
hexbuf	db '00000000 $'
crlf	db 13,10,'$'
okmsg	db 'OK $'
failmsg	db 'FAIL $'
nodpmi	db 'no DPMI host',13,10,'$'
nomode	db 'switch to protected mode failed',13,10,'$'
banner	db 'DPMI 1.0 function test (16-bit client)',13,10,'$'
sumok	db 'DPMI10: all tests passed',13,10,'$'
sumfail	db 'DPMI10: failures: $'
sel1	dw ?
sel2	dw ?
selinc	dw ?
handle	dd ?
lin	dd ?
vidsel	dw ?
capbuf	db 128 dup (0)
infobuf	db 128 dup (0)
attrbuf	dw 32 dup (0)
ldtbuf	dw ?
	db 8 dup (?)
	dw ?
	db 8 dup (?)
shmname	db 'DPMI10TEST',0
smr	dd 4096, 0, 0, 0
	dd ?
	dw ?
	dw 3 dup (0)
pmexc	dd ?
	dw ?
rmexc	dd ?
watchvar dw 0
	.code

; DX = offset of a $ string
print	proc
	pushad
	push	es
	movzx	edx,dx
	mov	rm.r_edx,edx
	mov	rm.r_eax,0900h
	mov	ax,rmseg
	mov	rm.r_ds,ax
	mov	rm.r_ss,0
	mov	rm.r_sp,0
	mov	rm.r_flags,0
	push	ds
	pop	es
	mov	di,offset rm
	mov	ax,0300h
	mov	bx,0021h
	xor	cx,cx
	int	31h
	pop	es
	popad
	ret
print	endp

; EAX = value
hex32	proc
	pushad
	mov	di,offset hexbuf+7
	mov	cx,8
hexl:	mov	bl,al
	and	bl,0Fh
	add	bl,'0'
	cmp	bl,'9'
	jbe	@F
	add	bl,'A'-'9'-1
@@:	mov	[di],bl
	dec	di
	shr	eax,4
	loop	hexl
	mov	dx,offset hexbuf
	call	print
	popad
	ret
hex32	endp

; CF, AX from the INT 31h call
okfail	proc
	jc	ofail
	mov	dx,offset okmsg
	call	print
	clc
	ret
ofail:	inc	nfail
	mov	dx,offset failmsg
	call	print
	movzx	eax,ax
	call	hex32
	stc
	ret
okfail	endp

HDR	macro	txt
	local	m
	.data
m	db	txt,': $'
	.code
	pushfd
	push	dx
	mov	dx,offset m
	call	print
	pop	dx
	popfd
	endm

RES	macro	txt
	HDR	txt
	call	okfail
	endm

NL	macro
	pushfd
	push	dx
	mov	dx,offset crlf
	call	print
	pop	dx
	popfd
	endm

; test failed although the call succeeded
BAD	macro
	inc	nfail
	push	dx
	mov	dx,offset failmsg
	call	print
	pop	dx
	endm

start:
	mov	ax,@data
	mov	ds,ax
	mov	rmseg,ax
	mov	bx,ss			; shrink to code+data+stack
	mov	ax,sp
	shr	ax,4
	inc	ax
	add	bx,ax
	mov	ax,es
	sub	bx,ax
	mov	ah,4Ah
	int	21h
	mov	ah,9
	mov	dx,offset banner
	int	21h
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jz	@F
	mov	dx,offset nodpmi
	jmp	rmexit
@@:	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	swfail
	mov	es,ax
@@:	xor	ax,ax
	call	entry
	jnc	pm
swfail:	mov	dx,offset nomode
rmexit:	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

pm:	push	ds
	pop	es

; 0400h version
	mov	ax,0400h
	int	31h
	RES	'0400 version'
	push	ax
	movzx	eax,ax
	call	hex32
	pop	ax
	cmp	ah,1
	jae	@F
	BAD
@@:	NL

; 0401h capabilities
	mov	ax,0401h
	mov	di,offset capbuf
	int	31h
	RES	'0401 capabilities'
	jc	@F
	movzx	eax,ax
	call	hex32
@@:	NL

; 0000h, 000Eh, 000Fh multiple LDT entries
	mov	ax,0000h
	mov	cx,2
	int	31h
	RES	'0000 alloc 2 selectors'
	NL
	mov	sel1,ax
	mov	ax,0003h
	int	31h
	mov	selinc,ax
	add	ax,sel1
	mov	sel2,ax
	mov	ax,sel1
	mov	ldtbuf,ax
	mov	ax,sel2
	mov	ldtbuf+10,ax
	mov	ax,000Eh
	mov	cx,2
	mov	di,offset ldtbuf
	int	31h
	RES	'000E get multiple LDT entries'
	NL
	mov	word ptr ldtbuf+2,0FFFh		; limit
	mov	word ptr ldtbuf+4,3450h		; base 0-15
	mov	byte ptr ldtbuf+6,12h		; base 16-23
	mov	ax,cs
	and	al,3
	shl	al,5
	or	al,92h				; present data, DPL = CPL
	mov	byte ptr ldtbuf+7,al
	mov	byte ptr ldtbuf+8,0
	mov	byte ptr ldtbuf+9,0
	mov	ax,000Fh
	mov	cx,2
	mov	di,offset ldtbuf
	int	31h
	RES	'000F set multiple LDT entries'
	jc	l0f
	mov	ax,0006h
	mov	bx,sel1
	int	31h
	cmp	cx,0012h
	jne	l0fbad
	cmp	dx,3450h
	je	l0f
l0fbad:	BAD
l0f:	NL

; 0504h..050Ah linear memory blocks
	mov	ax,0504h
	xor	ebx,ebx
	mov	ecx,10000h
	mov	edx,1
	int	31h
	RES	'0504 alloc linear block'
	jc	nolin
	mov	lin,ebx
	mov	handle,esi
	mov	eax,ebx
	call	hex32
	NL

	mov	ax,0506h
	mov	esi,handle
	xor	ebx,ebx
	mov	ecx,16
	xor	edx,edx
	mov	dx,offset attrbuf
	int	31h
	RES	'0506 get page attributes'
	jc	@F
	mov	ax,attrbuf
	and	ax,7
	cmp	ax,1
	je	@F
	BAD
@@:	NL

	mov	attrbuf,0			; page 0 uncommitted
	mov	ax,0507h
	mov	esi,handle
	xor	ebx,ebx
	mov	ecx,1
	xor	edx,edx
	mov	dx,offset attrbuf
	int	31h
	RES	'0507 set page attributes'
	jc	@F
	mov	attrbuf,0FFFFh
	mov	ax,0506h
	mov	esi,handle
	xor	ebx,ebx
	mov	ecx,1
	xor	edx,edx
	mov	dx,offset attrbuf
	int	31h
	test	attrbuf,7
	jz	@F
	BAD
@@:	NL

	mov	ax,050Ah
	mov	di,word ptr handle
	mov	si,word ptr handle+2
	int	31h
	RES	'050A get block size and base'
	jc	@F
	cmp	si,1
	jne	l0abad
	or	di,di
	jnz	l0abad
	cmp	bx,word ptr lin+2
	jne	l0abad
	cmp	cx,word ptr lin
	je	@F
l0abad:	BAD
@@:	NL

	mov	ax,0505h
	mov	esi,handle
	mov	ecx,20000h
	mov	edx,1
	xor	ebx,ebx
	xor	edi,edi
	int	31h
	RES	'0505 resize linear block'
	jc	@F
	mov	lin,ebx
	mov	handle,esi
	mov	ax,050Ah
	mov	di,word ptr handle
	mov	si,word ptr handle+2
	int	31h
	cmp	si,2
	je	@F
	BAD
@@:	NL

	mov	ax,0509h			; map B8000 at offset 0
	mov	esi,handle
	xor	ebx,ebx
	mov	ecx,1
	mov	edx,0B8000h
	int	31h
	RES	'0509 map conventional memory'
	jc	l09
	mov	ax,0002h
	mov	bx,0B800h
	int	31h
	mov	vidsel,ax
	mov	ax,0007h			; sel2 -> block base
	mov	bx,sel2
	mov	cx,word ptr lin+2
	mov	dx,word ptr lin
	int	31h
	mov	ax,0008h
	mov	bx,sel2
	xor	cx,cx
	mov	dx,0FFFh
	int	31h
	push	ds
	mov	ds,vidsel
	mov	ax,ds:[0]
	mov	word ptr ds:[0],1E44h
	pop	ds
	push	ax
	push	fs
	push	gs
	mov	fs,sel2
	mov	gs,vidsel
	mov	cx,fs:[0]
	pop	gs
	pop	fs
	pop	ax
	push	ds
	mov	ds,vidsel
	mov	ds:[0],ax
	pop	ds
	cmp	cx,1E44h
	je	l09
	BAD
l09:	NL

	mov	ax,0508h			; device memory (QEMU VGA LFB)
	mov	esi,handle
	mov	ebx,1000h
	mov	ecx,1
	mov	edx,0FD000000h
	int	31h
	RES	'0508 map device memory'
	NL

	mov	ax,0502h
	mov	di,word ptr handle
	mov	si,word ptr handle+2
	int	31h
	RES	'0502 free linear block'
	NL
nolin:

; 050Bh memory information
	mov	ax,050Bh
	mov	di,offset infobuf
	int	31h
	RES	'050B memory information'
	jc	@F
	mov	eax,dword ptr infobuf		; allocated physical memory
	call	hex32
@@:	NL

; 0800h/0801h physical mapping
	mov	ax,0800h
	mov	bx,0FD00h
	xor	cx,cx
	mov	si,1
	xor	di,di
	int	31h
	RES	'0800 map physical address'
	jc	@F
	push	bx
	push	cx
	mov	ax,0801h
	pop	cx
	pop	bx
	int	31h
	RES	'0801 free physical mapping'
@@:	NL

; 0D00h..0D03h shared memory
	mov	dword ptr smr+16,offset shmname
	mov	word ptr smr+20,ds
	mov	ax,0D00h
	mov	di,offset smr
	int	31h
	RES	'0D00 alloc shared memory'
	jc	noshm
	mov	eax,dword ptr smr+12
	call	hex32
	NL
	mov	ax,0D02h
	mov	di,word ptr smr+8
	mov	si,word ptr smr+10
	xor	dx,dx
	int	31h
	RES	'0D02 serialize'
	NL
	mov	ax,0D03h
	mov	di,word ptr smr+8
	mov	si,word ptr smr+10
	xor	dx,dx
	int	31h
	RES	'0D03 free serialization'
	NL
	mov	ax,0D01h
	mov	di,word ptr smr+8
	mov	si,word ptr smr+10
	int	31h
	RES	'0D01 free shared memory'
noshm:	NL

; 0E00h/0E01h coprocessor
	mov	ax,0E00h
	int	31h
	RES	'0E00 coprocessor status'
	jc	@F
	movzx	eax,ax
	call	hex32
@@:	NL
	mov	ax,0E01h
	xor	bx,bx
	int	31h
	RES	'0E01 set coprocessor emulation'
	NL

; 0210h..0213h extended exception handlers
	mov	ax,0210h
	mov	bl,0Dh
	int	31h
	RES	'0210 get PM exception handler'
	jc	@F
	mov	pmexc,edx
	mov	word ptr pmexc+4,cx
	mov	ax,0212h
	mov	bl,0Dh
	mov	edx,pmexc
	mov	cx,word ptr pmexc+4
	int	31h
	RES	'0212 set'
@@:	NL
	mov	ax,0211h
	mov	bl,0Dh
	int	31h
	RES	'0211 get RM exception handler'
	jc	@F
	mov	word ptr rmexc,dx
	mov	word ptr rmexc+2,cx
	mov	ax,0213h
	mov	bl,0Dh
	mov	dx,word ptr rmexc
	mov	cx,word ptr rmexc+2
	int	31h
	RES	'0213 set'
@@:	NL

; 0B00h..0B03h debug watchpoints
	movzx	eax,rmseg
	shl	eax,4
	add	eax,offset watchvar
	mov	cx,ax
	shr	eax,16
	mov	bx,ax
	mov	ax,0B00h
	mov	dx,0102h			; write, 2 bytes
	int	31h
	RES	'0B00 set watchpoint'
	jc	@F
	push	bx
	mov	ax,0B02h
	int	31h
	RES	'0B02 query'
	pop	bx
	push	bx
	mov	ax,0B03h
	int	31h
	RES	'0B03 reset'
	pop	bx
	mov	ax,0B01h
	int	31h
	RES	'0B01 clear'
@@:	NL

	mov	ax,0001h
	mov	bx,sel1
	int	31h
	mov	ax,0001h
	mov	bx,sel2
	int	31h

	cmp	nfail,0
	jne	@F
	mov	dx,offset sumok
	call	print
	mov	ax,4C00h
	int	21h
@@:	mov	dx,offset sumfail
	call	print
	movzx	eax,nfail
	call	hex32
	NL
	mov	ax,4C02h
	int	21h

	end	start

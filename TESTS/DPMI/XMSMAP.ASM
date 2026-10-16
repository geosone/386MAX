; XMSMAP.ASM - a DPMI client gets a DMA buffer the way sound drivers do
; it (VSBHDA, SBEMU, Mpxplay):  XMS block allocated and locked through
; the XMS driver (INT 2Fh 4310h entry called with INT 31h 0301h), its
; physical address mapped with INT 31h 0800h, then written through the
; mapping and read back by an XMS move into DOS memory.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no DPMI host.
; Build: jwasm -mz XMSMAP.ASM

	.model	small
	.386
	.stack	2048

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

KB	equ	64			; block size in KB

	.data
entry	dd	?
rm	RMREGS	<>
xmsent	dd	?			; XMS driver entry
handle	dw	?
phys	dd	?
lin	dd	?
dmemseg	dw	?
dossel	dw	?
mapsel	dw	?
nfail	dw	0
hexbuf	db	'00000000 $'
crlf	db	13,10,'$'
okmsg	db	'OK $'
failmsg	db	'FAIL $'
nodpmi	db	'no DPMI host',13,10,'$'
banner	db	'XMS block + physical mapping from a DPMI client',13,10,'$'
emm	dw	0,0			; XMS move structure:  length
	dw	0			; source handle
	dd	0			; source offset
	dw	0			; destination handle (0 = conventional)
	dd	0			; destination Seg:Off
	.code

print	proc			; DS:DX ==> '$' string
	push	ax
	mov	ah,9
	int	21h
	pop	ax
	ret
print	endp

hex32	proc			; EAX
	pushad
	mov	di,offset hexbuf+7
	mov	cx,8
@@:	mov	bl,al
	and	bl,0Fh
	add	bl,'0'
	cmp	bl,'9'
	jbe	short h1
	add	bl,7
h1:	mov	[di],bl
	dec	di
	shr	eax,4
	loop	@B
	mov	dx,offset hexbuf
	call	print
	popad
	ret
hex32	endp

; CF:  OK/FAIL, then text (DX) and a new line
result	proc
	push	dx
	mov	dx,offset okmsg
	jnc	@F
	inc	nfail
	mov	dx,offset failmsg
@@:	call	print
	pop	dx
	call	print
	mov	dx,offset crlf
	call	print
	ret
result	endp

; call the XMS driver (AH = function, BX, DX, SI as given) through 0301h
xmscall	proc
	mov	word ptr rm.r_eax,ax
	mov	word ptr rm.r_ebx,bx
	mov	word ptr rm.r_edx,dx
	mov	word ptr rm.r_esi,si
	mov	ax,word ptr xmsent
	mov	rm.r_ip,ax
	mov	ax,word ptr xmsent+2
	mov	rm.r_cs,ax
	mov	ax,dmemseg
	add	ax,KB*1024/16		; the move structure's paragraph
	mov	rm.r_ds,ax
	mov	rm.r_ss,0
	mov	rm.r_sp,0
	mov	rm.r_flags,0
	push	es
	push	ds
	pop	es
	mov	di,offset rm
	mov	ax,0301h
	xor	bx,bx
	xor	cx,cx
	int	31h
	pop	es
	mov	ax,word ptr rm.r_eax
	mov	bx,word ptr rm.r_ebx
	mov	dx,word ptr rm.r_edx
	ret
xmscall	endp

TXT	macro	t
	local	m
	.data
m	db	t,'$'
	.code
	mov	dx,offset m
	endm

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,2048/16+1
	mov	ah,4Ah
	int	21h
	mov	dx,offset banner
	call	print
nox:	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jz	@F
nod:	mov	dx,offset nodpmi
	call	print
	mov	ax,4C02h
	int	21h
@@:	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	nod
	mov	es,ax
@@:	xor	ax,ax
	call	entry
	jc	nod
	push	ds
	pop	es

	; the XMS driver entry (INT 2Fh 4310h through 0300h)
	mov	rm.r_eax,4310h
	mov	rm.r_ss,0
	mov	rm.r_sp,0
	mov	rm.r_flags,0
	mov	di,offset rm
	mov	ax,0300h
	mov	bx,002Fh
	xor	cx,cx
	int	31h
	mov	ax,rm.r_es
	shl	eax,16
	mov	ax,word ptr rm.r_ebx
	mov	xmsent,eax
	or	eax,eax
	jnz	@F
	stc
@@:	TXT	'XMS driver entry'
	call	result
	jc	done
	; DOS memory for the read-back
	mov	ax,0100h
	mov	bx,KB*1024/16+1		; + 1 paragraph for the move structure
	int	31h
	mov	dmemseg,ax
	mov	dossel,dx
	TXT	'DOS memory'
	call	result
	jc	done

	; allocate and lock
	mov	ah,09h
	mov	dx,KB
	call	xmscall
	mov	handle,dx
	cmp	ax,1
	je	@F
	movzx	eax,bl
	call	hex32
	stc
@@:	TXT	'XMS 09h allocate 64 KB'
	call	result
	jc	done
	mov	ah,0Ch
	mov	dx,handle
	call	xmscall
	mov	word ptr phys,bx
	mov	word ptr phys+2,dx
	cmp	ax,1
	je	@F
	movzx	eax,bl
	call	hex32
	stc
	jmp	short lck
@@:	mov	eax,phys
	call	hex32
	clc
lck:	TXT	'XMS 0Ch lock (physical address)'
	call	result
	jc	free

	; map it
	mov	bx,word ptr phys+2
	mov	cx,word ptr phys
	mov	si,(KB*1024) shr 16	; size SI:DI
	mov	di,(KB*1024) and 0FFFFh
	mov	ax,0800h
	int	31h
	jnc	@F
	push	eax
	movzx	eax,ax
	call	hex32
	pop	eax
	stc
	jmp	short map
@@:	mov	word ptr lin,cx
	mov	word ptr lin+2,bx
	mov	eax,lin
	call	hex32
	clc
map:	TXT	'0800h map the physical address'
	call	result
	jc	unlock

	; selector for the mapping, write a pattern
	mov	ax,0000h
	mov	cx,1
	int	31h
	mov	mapsel,ax
	mov	bx,ax
	mov	cx,word ptr lin+2
	mov	dx,word ptr lin
	mov	ax,0007h
	int	31h
	mov	bx,mapsel
	xor	cx,cx
	mov	dx,KB*1024-1
	mov	ax,0008h
	int	31h
	push	es
	mov	es,mapsel
	xor	di,di
	mov	cx,KB*1024/2
	mov	ax,0A55Ah
	rep	stosw
	pop	es

	; read back by XMS move into DOS memory and compare
	mov	word ptr emm,KB*1024 and 0FFFFh
	mov	word ptr emm+2,KB*1024 shr 16
	mov	ax,handle
	mov	word ptr emm+4,ax
	mov	dword ptr emm+6,0
	mov	word ptr emm+10,0
	mov	ax,dmemseg
	mov	word ptr emm+12,0
	mov	word ptr emm+14,ax
	mov	bx,dmemseg		; the move structure behind the buffer
	add	bx,KB*1024/16
	mov	ax,0002h
	int	31h
	push	es
	mov	es,ax
	mov	si,offset emm
	xor	di,di
	mov	cx,16/2
	rep	movsw
	pop	es
	mov	ah,0Bh			; DS:SI = structure
	xor	si,si
	call	xmscall
	cmp	ax,1
	jne	cmpf
	push	es
	mov	es,dossel
	xor	di,di
	mov	cx,KB*1024/2
	mov	ax,0A55Ah
	repe	scasw
	pop	es
	je	@F
cmpf:	stc
	jmp	short cmpd
@@:	clc
cmpd:	TXT	'written through the mapping = XMS block content'
	call	result

	mov	bx,word ptr lin+2
	mov	cx,word ptr lin
	mov	ax,0801h
	int	31h
unlock:	mov	ah,0Dh
	mov	dx,handle
	call	xmscall
free:	mov	ah,0Ah
	mov	dx,handle
	call	xmscall
done:	cmp	nfail,0
	je	@F
	mov	ax,4C01h
	int	21h
@@:	mov	ax,4C00h
	int	21h

	end	start

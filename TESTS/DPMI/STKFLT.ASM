; STKFLT.ASM - stack fault (exception 0Ch) in a DPMI client:  SP = 2,
; then PUSH.  The host must not crash (it terminates the client or calls
; its handler).
; Build: jwasm -mz STKFLT.ASM

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
banner	db 'stack fault test (16-bit client)',13,10,'$'
sumok	db 'about to fault',13,10,'$'
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
	mov	ax,0000h			; flat 32-bit stack selector
	mov	cx,1
	int	31h
	mov	bx,ax
	mov	ax,0007h			; base 0
	xor	cx,cx
	xor	dx,dx
	int	31h
	mov	ax,0008h			; limit 4 GB
	mov	cx,-1
	mov	dx,-1
	int	31h
	mov	ax,cs
	and	al,3
	shl	al,5
	or	al,92h
	mov	cl,al
	mov	ch,0CFh				; G, B
	mov	ax,0009h
	int	31h
	mov	dx,offset sumok			; "before" marker
	call	print
	mov	ss,bx
	mov	esp,2
	push	eax				; writes to FFFFFFFEh
	push	eax
	mov	ax,4C00h
	int	21h

	end	start

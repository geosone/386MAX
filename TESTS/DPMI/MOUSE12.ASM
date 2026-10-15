; MOUSE12.ASM - INT 33h AX=0012h (large graphics cursor) through the DPMI
; host from a 16-bit client: a 2x16 cursor, and one too large for the host
; buffer (must be ignored).  Needs a mouse driver.
; Build: jwasm -mz MOUSE12.ASM

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
banner	db 'INT 33h AX=0012h translation test (16-bit client)',13,10,'$'
sumok	db 'MOUSE12: all tests passed',13,10,'$'
sumfail	db 'MOUSE12: failures: $'
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
cursor	dw 64 dup (5A5Ah)
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
	xor	ax,ax				; reset driver
	int	33h
	HDR	'0000 reset'
	movzx	eax,ax
	call	hex32
	NL
	mov	ax,0012h			; 2 words x 16 rows, 128 bytes
	mov	bx,0200h
	mov	cx,1000h
	mov	dx,offset cursor
	int	33h
	HDR	'0012 large cursor 2x16'
	mov	dx,offset okmsg
	call	print
	NL
	mov	ax,0012h			; 255 x 255: too large, ignored
	mov	bx,0FF00h
	mov	cx,0FF00h
	mov	dx,offset cursor
	int	33h
	HDR	'0012 large cursor 255x255'
	mov	dx,offset okmsg
	call	print
	NL
	mov	dx,offset sumok
	call	print
	mov	ax,4C00h
	int	21h

	end	start

; MOUSE18.ASM - INT 33h AX=0018h/0019h (alternate mouse handlers) through
; the DPMI host from a 16-bit client.  Installs a normal handler (000Ch)
; and three alternate ones (Shift/Ctrl/Alt), checks 0019h and that a
; fourth is refused, then waits for mouse events with the Shift flag set
; in the BIOS data area (the alternate handler) and cleared (the normal
; one).  The mouse has to move meanwhile.  With "K" on the command line
; it exits without removing them and leaves the Shift flag set:  the host
; must remove them from the driver on termination.
; Build: jwasm -mz MOUSE18.ASM

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
banner	db 'INT 33h AX=0018h translation test (16-bit client)',13,10,'$'
sumok	db 'MOUSE18: all tests passed',13,10,'$'
sumfail	db 'MOUSE18: failures: $'
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
keep	db 0
cnt0	dw 0
cnt1	dw 0
sel40	dw ?
timeout	db 'TIMEOUT $'
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
	cmp	byte ptr es:[82h],'K'
	jne	@F
	mov	keep,1
@@:
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
	mov	ax,000Ah			; data alias of CS to store DS
	mov	bx,cs
	int	31h
	push	es
	mov	es,ax
	mov	es:[dsel],ds
	pop	es
	mov	ax,0001h
	mov	bx,es
	push	es
	mov	ax,0002h
	mov	bx,0040h
	int	31h
	mov	sel40,ax
	pop	es

	xor	ax,ax
	int	33h
	HDR	'0000 reset'
	movzx	eax,ax
	call	hex32
	NL

	push	es
	mov	ax,000Ch			; normal handler: movement
	mov	cx,0001h
	push	cs
	pop	es
	mov	dx,offset h0
	int	33h
	pop	es

	push	es
	push	cs
	pop	es
	mov	ax,0018h			; Shift + movement
	mov	cx,0021h
	mov	dx,offset h1
	int	33h
	pop	es
	HDR	'0018 Shift handler'
	call	chk18
	NL
	mov	ax,0019h
	mov	cx,0021h
	int	33h
	HDR	'0019 query'
	cmp	cx,0021h
	jne	q19f
	cmp	dx,offset h1
	jne	q19f
	mov	ax,cs
	cmp	bx,ax
	jne	q19f
	mov	dx,offset okmsg
	call	print
	jmp	short q19x
q19f:	BAD
q19x:	NL
	push	es
	push	cs
	pop	es
	mov	ax,0018h			; Ctrl
	mov	cx,0041h
	mov	dx,offset h1
	int	33h
	HDR	'0018 Ctrl handler'
	call	chk18
	NL
	mov	ax,0018h			; Alt
	mov	cx,0081h
	mov	dx,offset h1
	int	33h
	HDR	'0018 Alt handler'
	call	chk18
	NL
	mov	ax,0018h			; a fourth one: refused
	mov	cx,0061h
	mov	dx,offset h1
	int	33h
	pop	es
	HDR	'0018 fourth refused'
	cmp	ax,-1
	je	@F
	BAD
	jmp	short f4x
@@:	mov	dx,offset okmsg
	call	print
f4x:	NL

; Shift set: wait for the alternate handler
	push	ds
	mov	ds,sel40
	or	byte ptr ds:[17h],02h
	pop	ds
	mov	si,offset cnt1
	call	waitcnt
	HDR	'alternate handler called'
	call	waitres
	NL

; Shift clear: wait for the normal handler
	push	ds
	mov	ds,sel40
	and	byte ptr ds:[17h],not 02h
	pop	ds
	mov	si,offset cnt0
	call	waitcnt
	HDR	'normal handler called'
	call	waitres
	NL

	cmp	keep,0
	je	remove
	push	ds				; leave Shift set and exit
	mov	ds,sel40
	or	byte ptr ds:[17h],02h
	pop	ds
	jmp	done

remove:	push	es
	xor	dx,dx
	mov	es,dx
	mov	ax,0018h			; remove the Shift handler
	mov	cx,0021h
	int	33h
	pop	es
	HDR	'0018 remove'
	call	chk18
	NL
	mov	ax,0019h
	mov	cx,0021h
	int	33h
	HDR	'0019 after removal'
	or	cx,cx
	jz	@F
	BAD
	jmp	short r19x
@@:	mov	dx,offset okmsg
	call	print
r19x:	NL
	xor	ax,ax				; driver reset removes the rest
	int	33h

done:	cmp	nfail,0
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

chk18	proc
	cmp	ax,0018h
	je	@F
	BAD
	movzx	eax,ax
	call	hex32
	ret
@@:	mov	dx,offset okmsg
	call	print
	ret
chk18	endp

; wait up to 15 s (BIOS ticks) until word [SI] != 0; CF=1 on timeout
waitcnt	proc
	mov	word ptr [si],0
	push	es
	mov	es,sel40
	mov	bx,es:[6Ch]
@@:	cmp	word ptr [si],0
	jne	wok
	mov	ax,es:[6Ch]
	sub	ax,bx
	cmp	ax,15*18
	jb	@B
	pop	es
	stc
	ret
wok:	pop	es
	clc
	ret
waitcnt	endp

waitres	proc
	jnc	@F
	inc	nfail
	mov	dx,offset timeout
	call	print
	ret
@@:	mov	dx,offset okmsg
	call	print
	ret
waitres	endp

; mouse handlers (called with RETF; DS from the code segment)
dsel	dw	?
h0	proc	far
	push	ds
	mov	ds,cs:dsel
	inc	cnt0
	pop	ds
	ret
h0	endp
h1	proc	far
	push	ds
	mov	ds,cs:dsel
	inc	cnt1
	pop	ds
	ret
h1	endp

	end	start

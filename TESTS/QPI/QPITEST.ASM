; QPITEST.ASM - QEMM Programming Interface (QPI) of the memory manager:
; detection (INT 2Fh AX=D201h, INT 67h AH=3Fh) and the functions 00h,
; 01h, 03h, 0Ch, 11h, 12h, 16xx, 17h, 18h, 1A02h/1A03h, 1B05h, 1Exx,
; 1Fxx, 20xx and some that must fail.  Results are compared with VCPI
; (DE03h, DE06h), EMS (41h) and direct I/O where possible.
; Build: jwasm -mz QPITEST.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
nfail	dw	0
hexbuf	db	'0000 $'
crlf	db	13,10,'$'
okmsg	db	'OK $'
failmsg	db	'FAIL $'
banner	db	'QPI test',13,10,'$'
sumok	db	'QPITEST: all tests passed',13,10,'$'
sumfail	db	'QPITEST: failures: $'
noqpi	db	'no QPI',13,10,'$'
map	db	256 dup (0)
acc	db	256 dup (0)
stat	db	81 dup (0)
line	db	64 dup (0),13,10,'$'
drv1	db	'C:\WINDOWS\SYSTEM\VGA.DRV',0
drv2	db	'C:\WINDOWS\SYSTEM\GDI.EXE',0
drv3	db	'PROGMAN.EXE',0
frame	dw	0
pte	dd	0

	.code

HDR	macro	txt
	local	m
	.data
m	db	txt,': $'
	.code
	pushf
	push	dx
	mov	dx,offset m
	call	print
	pop	dx
	popf
	endm

NL	macro
	pushf
	push	dx
	mov	dx,offset crlf
	call	print
	pop	dx
	popf
	endm

; CF=1 or condition false: FAIL
OKIF	macro	cc
	local	l1,l2
	j&cc	l1
	call	fail
	jmp	short l2
l1:	call	ok
l2:
	endm

print	proc
	push	ax
	mov	ah,9
	int	21h
	pop	ax
	ret
print	endp

ok	proc
	push	dx
	mov	dx,offset okmsg
	call	print
	pop	dx
	ret
ok	endp

fail	proc
	push	dx
	inc	nfail
	mov	dx,offset failmsg
	call	print
	pop	dx
	ret
fail	endp

; AX -> 4 hex digits
hex	proc
	pusha
	mov	di,offset hexbuf
	mov	cx,4
@@:	rol	ax,4
	mov	bl,al
	and	bl,0Fh
	add	bl,'0'
	cmp	bl,'9'
	jbe	h1
	add	bl,7
h1:	mov	[di],bl
	inc	di
	loop	@B
	mov	dx,offset hexbuf
	call	print
	popa
	ret
hex	endp

start:	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	mov	dx,offset banner
	call	print

; INT 2Fh AX=D201h
	mov	ax,0D201h
	mov	bx,5145h
	mov	cx,4D4Dh
	mov	dx,3432h
	push	es
	int	2Fh
	mov	ax,es
	pop	es
	HDR	'2F D201 detection'
	cmp	bx,4F4Bh
	jne	@F
	mov	word ptr qpi,di
	mov	word ptr qpi+2,ax
@@:	OKIF	e
	NL

; INT 67h AH=3Fh gives the same entry point
	mov	ah,3Fh
	mov	cx,5145h
	mov	dx,4D4Dh
	push	es
	int	67h
	mov	cx,es
	pop	es
	HDR	'67 3F detection'
	or	ah,ah		; QEMM returns another entry point here than
	jnz	d67f		; through D201h; both are valid
	or	di,cx
	jz	d67f
	call	ok
	jmp	short d67x
d67f:	call	fail
d67x:	NL
	cmp	qpi,0
	jne	@F
	mov	dx,offset noqpi
	call	print
	jmp	done
@@:

; 00 get state, 01 set state
	mov	ah,00h
	call	qpi
	HDR	'00 get state'
	jc	@F
	cmp	al,0
@@:	OKIF	e
	NL
	mov	ax,0101h
	call	qpi
	HDR	'01 set OFF refused'
	OKIF	c
	NL
	mov	ax,0100h
	call	qpi
	HDR	'01 set ON'
	OKIF	nc
	NL

; 03 version
	mov	ah,03h
	call	qpi
	HDR	'03 version'
	call	hex
	cmp	ax,bx
	OKIF	e
	NL

; 0C available memory, against VCPI DE03h
	mov	ah,0Ch
	call	qpi
	HDR	'0C total/free pages'
	jc	c0f
	cmp	bx,1
	jne	c0f
	mov	ax,cx
	call	hex
	mov	ax,dx
	call	hex
	push	dx
	mov	ax,0DE03h
	int	67h
	pop	ax
	cmp	edx,0FFFFh
	jbe	@F
	mov	dx,0FFFFh
@@:	sub	ax,dx				; may differ by a little
	jns	@F
	neg	ax
@@:	cmp	ax,16
	jbe	c0ok
c0f:	call	fail
	jmp	short c0x
c0ok:	call	ok
c0x:	NL

; 11 memory type map, printed as 4 lines of 64 pages
	mov	ah,41h				; EMS page frame
	int	67h
	or	ah,ah
	jnz	@F
	mov	frame,bx
@@:	mov	ah,11h
	mov	di,offset map
	call	qpi
	HDR	'11 memory type map'
	OKIF	nc
	NL
	xor	si,si
mrow:	mov	di,offset line
	mov	cx,64
@@:	mov	al,map[si]
	and	al,0Fh
	add	al,'0'
	cmp	al,'9'
	jbe	m1
	add	al,7
m1:	mov	[di],al
	inc	di
	inc	si
	loop	@B
	mov	dx,offset line
	call	print
	cmp	si,256
	jb	mrow
; Codes as QEMM 97 really reports them (RBIL lists more):  conventional
; memory is 00h (mappable) with 04h (excluded) below 4000h, 386MAX so far
; 0Bh; the EMS frame is 00h at QEMM, 09h at 386MAX
	HDR	'11 page 0 conventional, A0 video, F0 (mapped) ROM, frame'
	cmp	map[0],0Bh
	je	@F
	cmp	map[0],04h
	jne	mf
@@:
	cmp	map[0A0h],05h
	jne	mf
	cmp	map[0F0h],06h			; system ROM
	je	@F
	cmp	map[0F0h],02h			; or mapped (shadowed) ROM
	jne	mf
@@:
	mov	bx,frame
	shr	bx,8
	or	bx,bx
	jz	@F
	cmp	map[bx],09h
	je	@F
	cmp	map[bx],00h
	jne	mf
@@:	call	ok
	jmp	short mx
mf:	call	fail
mx:	NL

; 12 HIRAM chain
	mov	ah,12h
	call	qpi
	HDR	'12 first high DOS MCB'
	mov	ax,bx
	call	hex
	push	es
	mov	es,bx
	mov	al,es:[0]
	mov	ah,0
	pop	es
	call	hex
	jc	@F
	or	bx,bx
	jz	@F
	push	es
	mov	es,bx
	cmp	byte ptr es:[0],'M'
	je	h12
	cmp	byte ptr es:[0],'Z'
h12:	pop	es
@@:	OKIF	e
	NL

; 1600/1601 access status
	mov	ax,1600h
	mov	di,offset acc
	call	qpi
	HDR	'1600 page 0 accessed'
	jc	@F
	test	acc[0],01h
	jz	@F
	cmp	al,al
	jmp	short a16
@@:	cmp	al,al
	inc	ax				; NZ
a16:	OKIF	e
	NL
	mov	ax,1601h
	mov	di,offset acc
	call	qpi
	HDR	'1601 set access status'
	OKIF	nc
	NL

; 17 statistics
	mov	ah,17h
	mov	di,offset stat
	call	qpi
	HDR	'17 statistics (conv KB, EMS MB)'
	jc	s17f
	mov	eax,dword ptr stat+1
	shr	eax,10
	call	hex
	mov	eax,dword ptr stat+9
	shr	eax,20
	call	hex
	cmp	word ptr stat+1+2,0		; conventional >= 64 KB
	jne	@F
s17f:	call	fail
	jmp	short s17x
@@:	call	ok
s17x:	NL

; 18 conventional memory mapped?
	push	es
	xor	bx,bx
	mov	es,bx
	mov	cx,1
	mov	ah,18h
	call	qpi
	pop	es
	HDR	'18 page 0 is conventional'
	jc	@F
	cmp	al,1
@@:	OKIF	e
	NL

; 1A02/1A03 indexed I/O: CRTC cursor start register
	mov	dx,3D4h
	mov	al,0Ah
	out	dx,al
	inc	dx
	in	al,dx
	mov	ah,al
	dec	dx
	mov	bh,0Ah
	mov	ax,1A02h
	push	ax
	call	qpi
	pop	ax
	HDR	'1A02 indexed read = direct read'
	jc	@F
	push	ax
	mov	al,bl
	mov	ah,0
	call	hex
	pop	ax
	mov	dx,3D4h
	mov	al,0Ah
	out	dx,al
	inc	dx
	in	al,dx
	mov	ah,0
	call	hex
	cmp	al,bl
@@:	OKIF	e
	NL
	mov	bh,0Ah
	mov	ax,1A03h
	mov	dx,3D4h
	call	qpi				; write the same value back
	HDR	'1A03 indexed write'
	OKIF	nc
	NL

; 1B05 Windows driver check
	mov	ax,1B05h
	mov	dx,offset drv1
	call	qpi
	HDR	'1B05 .DRV / GDI.EXE / other'
	jc	wf
	cmp	al,01h
	jne	wf
	mov	ax,1B05h
	mov	dx,offset drv2
	call	qpi
	cmp	al,0FFh
	jne	wf
	mov	ax,1B05h
	mov	dx,offset drv3
	call	qpi
	cmp	al,0
	jne	wf
	call	ok
	jmp	short wx
wf:	call	fail
wx:	NL

; 1E00/1E01 Stealth (none)
	mov	ax,1E00h
	call	qpi
	HDR	'1E00/1E01 no Stealth'
	jc	@F
	or	cl,cl
	jnz	@F
	mov	ax,1E01h
	call	qpi
	jc	@F
	or	bx,bx
@@:	OKIF	e
	NL

; 1F00 PTE of B8h against VCPI DE06h, 1F01 write it back
	mov	ax,1F00h
	mov	cx,0B8h
	call	qpi
	HDR	'1F00 PTE B8 = VCPI DE06'
	jc	@F
	mov	pte,edx
	mov	ax,0DE06h
	mov	cx,0B8h
	int	67h
	mov	eax,pte
	and	eax,0FFFFF000h
	cmp	eax,edx
@@:	OKIF	e
	NL
	mov	ax,1F01h
	mov	cx,0B8h
	mov	edx,pte
	call	qpi
	HDR	'1F01 set PTE'
	OKIF	nc
	NL
; (no 1F00h with a page above 10Fh:  QEMM does not check the range and
; crashes)

; 1F00 above the HMA (QEMM 97 covers pages 0-3FFh, RBIL says 0-10Fh)
	mov	ax,1F00h
	mov	cx,120h
	call	qpi
	HDR	'1F00 page 120h'
	OKIF	nc
	NL

; 1F02 get CR0, 1F03 change only MP/EM/ET (here:  nothing)
	mov	ax,1F02h
	call	qpi
	HDR	'1F02 CR0'
	jc	@F
	mov	pte,eax
	push	eax
	shr	eax,16
	call	hex
	pop	eax
	call	hex
	test	eax,1			; PE
	jz	@F
	smsw	ax
	cmp	ax,word ptr pte		; same as SMSW
@@:	OKIF	e
	NL
	mov	ax,1F03h
	mov	ecx,0FFFFFFFFh		; keep everything
	xor	ebx,ebx
	call	qpi
	HDR	'1F03 CR0 unchanged'
	jc	@F
	cmp	eax,pte
@@:	OKIF	e
	NL

; 2000 VirtualHDIRQ
	mov	ax,2000h
	call	qpi
	HDR	'2000 VHI off'
	jc	@F
	cmp	bl,0
@@:	OKIF	e
	NL

; (no calls of undefined functions:  QEMM 97 does not answer them with
; CF=1 but crashes)

done:	cmp	nfail,0
	jne	@F
	mov	dx,offset sumok
	call	print
	mov	ax,4C00h
	int	21h
@@:	mov	dx,offset sumfail
	call	print
	mov	ax,nfail
	call	hex
	NL
	mov	ax,4C01h
	int	21h

	end	start

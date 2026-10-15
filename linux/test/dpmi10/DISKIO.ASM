; DISKIO.ASM - absolute disk I/O through the DPMI host's translation:
; INT 25h/26h (old and packet form), INT 21h AX=7305h, INT 13h AH=02h/08h,
; called from protected mode (16-bit client).  Transfers of 20 sectors
; exceed the host's translation buffer and are compared with single-sector
; reads.  INT 26h writes the sectors back unchanged.  Drive C:.
; Build: jwasm -mz DISKIO.ASM

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

	.data
rmseg	dw ?
entry	dd ?
nfail	dw 0
rm	RMREGS <>
hexbuf	db '00000000 $'
crlf	db 13,10,'$'
okmsg	db 'OK $'
samemsg	db 'data same $'
diffmsg	db 'DATA DIFFERS $'
nosup	db 'not supported by DOS $'
big32	db 'error 0207h as DOS (partition > 32 MB) $'
failmsg	db 'FAIL $'
nodpmi	db 'no DPMI host',13,10,'$'
nomode	db 'switch to protected mode failed',13,10,'$'
banner	db 'Disk I/O translation test (16-bit client)',13,10,'$'
sumok	db 'DISKIO: all tests passed',13,10,'$'
sumfail	db 'DISKIO: failures: $'
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
NSEC	equ	20
pkt	dd 0
	dw NSEC
	dw offset bulk
pktsel	dw ?
pkt1	dd 0
	dw 1
	dw ?
pkt1sel	dw ?
spdiff	dw ?
bulk	db NSEC*512 dup (0)
single	db NSEC*512 dup (0)
dirname	db 'C:\Long Directory Name',0
filname	db 'C:\Long Directory Name\A long file name.txt',0
newname	db 'C:\Long Directory Name\Another long name.txt',0
pattern	db 'C:\Long Directory Name\*.txt',0
rootdir	db 'C:\',0
lfnstr	db 'abcxyz',0
fhandle	dw ?
srchh	dw ?
strbuf	db 300 dup (0)
outbuf	db 600 dup (0)
finddat	db 318 dup (0)
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

; DS:SI = ASCIIZ string (up to 290 chars), printed in quotes
printz	proc
	pushad
	push	es
	push	ds
	pop	es
	mov	di,offset strbuf
	mov	al,'"'
	stosb
	mov	cx,290
@@:	lodsb
	or	al,al
	jz	@F
	stosb
	loop	@B
@@:	mov	al,'"'
	stosb
	mov	al,' '
	stosb
	mov	al,'$'
	stosb
	mov	dx,offset strbuf
	call	print
	pop	es
	popad
	ret
printz	endp

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
	mov	pktsel,ds
	mov	pkt1sel,ds

; INT 25h packet form, one sector at a time into single
	xor	esi,esi
	mov	di,offset single
rd1:	mov	dword ptr pkt1,esi
	mov	word ptr pkt1+6,di
	push	si
	push	di
	mov	al,2
	mov	cx,-1
	mov	bx,offset pkt1
	int	25h
	pop	cx				; flags left on the stack
	pop	di
	pop	si
	jc	rd1f
	add	di,512
	inc	si
	cmp	si,NSEC
	jb	rd1
	clc
rd1f:	RES	'INT 25h single sectors'
	jc	@F
	cmp	word ptr single+510,0AA55h
	je	@F
	BAD
@@:	NL

; INT 25h old form, 20 sectors at once, and the flags word on the stack
	mov	di,offset bulk
	mov	cx,NSEC*512/2
	xor	ax,ax
	rep	stosw
	mov	dx,sp
	mov	al,2
	mov	cx,NSEC
	mov	bx,offset bulk
	push	dx
	mov	dx,0
	int	25h
	pop	cx				; original flags
	pop	dx
	pushf
	push	ax
	mov	ax,sp
	add	ax,2+2
	sub	ax,dx
	mov	spdiff,ax
	pop	ax
	popf
	HDR	'INT 25h old form 20 sectors'
	jnc	o25
	cmp	ax,0207h			; DOS 4+: partition > 32 MB
	jne	o25f
	mov	dx,offset big32
	call	print
	jmp	short o25x
o25f:	call	okfail
	jmp	short o25x
o25:	call	okfail
	call	cmpbuf
o25x:	NL
	HDR	'INT 25h flags word left on stack'
	cmp	spdiff,0
	je	@F
	BAD
	jmp	short f25
@@:	mov	dx,offset okmsg
	call	print
f25:	NL

; INT 25h packet form
	call	clrbulk
	mov	al,2
	mov	cx,-1
	mov	bx,offset pkt
	int	25h
	pop	cx
	RES	'INT 25h packet 20 sectors'
	call	cmpbuf
	NL

; INT 26h packet form: write the 20 sectors back unchanged, then read again
	mov	word ptr pkt+6,offset single
	mov	al,2
	mov	cx,-1
	mov	bx,offset pkt
	int	26h
	pop	cx
	RES	'INT 26h packet 20 sectors'
	NL
	mov	word ptr pkt+6,offset bulk
	call	clrbulk
	mov	al,2
	mov	cx,-1
	mov	bx,offset pkt
	int	25h
	pop	cx
	RES	'INT 25h after write'
	call	cmpbuf
	NL

; INT 21h AX=7305h read (FAT32 API; FreeDOS and MS-DOS 7.1)
	call	clrbulk
	mov	ax,7305h
	mov	cx,-1
	mov	dl,3
	xor	si,si
	mov	bx,offset pkt
	stc
	int	21h
	HDR	'7305 read 20 sectors'
	jnc	@F
	cmp	ax,7300h			; not supported by this DOS
	jne	f7305
	mov	dx,offset nosup
	call	print
	jmp	short n7305
f7305:	call	okfail
	jmp	short n7305
@@:	call	okfail
	call	cmpbuf
n7305:	NL

; INT 13h AH=02h: MBR, then 17 sectors from cylinder 0 head 0
	mov	ax,0201h
	mov	cx,0001h
	mov	dx,0080h
	mov	bx,offset single
	int	13h
	RES	'INT 13h read MBR'
	jc	@F
	cmp	word ptr single+510,0AA55h
	je	@F
	BAD
@@:	NL
	mov	si,1
	mov	di,offset single
r13:	mov	ax,0201h
	mov	cx,si
	mov	dx,0080h
	mov	bx,di
	push	si
	push	di
	int	13h
	pop	di
	pop	si
	jc	r13f
	add	di,512
	inc	si
	cmp	si,17
	jbe	r13
	clc
r13f:	RES	'INT 13h single sectors'
	NL
	call	clrbulk
	mov	ax,0211h			; 17 sectors
	mov	cx,0001h
	mov	dx,0080h
	mov	bx,offset bulk
	int	13h
	RES	'INT 13h 17 sectors'
	jc	@F
	push	ax
	movzx	eax,al
	call	hex32
	pop	ax
	cmp	al,17
	je	c13
	BAD
c13:	mov	cx,17*512
	call	cmpn
@@:	NL

; INT 13h AH=08h hard disk (passed through)
	mov	ah,08h
	mov	dl,80h
	int	13h
	RES	'INT 13h AH=08h'
	jc	@F
	movzx	eax,cx
	call	hex32
@@:	NL

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

clrbulk	proc
	push	ax
	push	cx
	push	di
	mov	di,offset bulk
	mov	cx,NSEC*512/2
	mov	ax,0FFFFh
	rep	stosw
	pop	di
	pop	cx
	pop	ax
	ret
clrbulk	endp

; if CF clear: compare bulk with single (NSEC sectors), print and count
cmpbuf	proc
	jc	cbx
	push	cx
	mov	cx,NSEC*512
	call	cmpn
	pop	cx
cbx:	ret
cmpbuf	endp

cmpn	proc
	push	si
	push	di
	mov	si,offset bulk
	mov	di,offset single
	repe	cmpsb
	pop	di
	pop	si
	je	@F
	inc	nfail
	mov	dx,offset diffmsg
	call	print
	ret
@@:	mov	dx,offset samemsg
	call	print
	ret
cmpn	endp

	end	start

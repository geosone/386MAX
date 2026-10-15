; DOSXLAT.ASM - DOS API translation of the DPMI host for long filename
; (71xx), FAT32 (73xx) and other pointer functions, called from protected
; mode (16-bit client); prints OK or FAIL (error code) for each and the
; returned names.  Needs an LFN API (Windows or DOSLFN) for the 71xx part.
; Build: jwasm -mz DOSXLAT.ASM

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
banner	db 'DOS API translation test (16-bit client)',13,10,'$'
sumok	db 'DOSXLAT: all tests passed',13,10,'$'
sumfail	db 'DOSXLAT: failures: $'
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

; 7139h mkdir
	mov	ax,7139h
	mov	dx,offset dirname
	stc
	int	21h
	RES	'7139 mkdir'
	NL

; 713Bh chdir, 7147h get current directory
	mov	ax,713Bh
	mov	dx,offset dirname
	stc
	int	21h
	RES	'713B chdir'
	NL
	mov	ax,7147h
	xor	dl,dl
	mov	si,offset outbuf
	stc
	int	21h
	RES	'7147 current directory'
	jc	@F
	mov	si,offset outbuf
	call	printz
	cmp	byte ptr outbuf+5,' '		; "Long Directory Name"
	je	@F
	BAD
@@:	NL
	mov	ax,713Bh
	mov	dx,offset rootdir
	int	21h

; 716Ch create, write, 71A6h info by handle, close
	mov	ax,716Ch
	mov	bx,0002h
	xor	cx,cx
	mov	dx,0012h			; create or truncate
	mov	si,offset filname
	stc
	int	21h
	RES	'716C create'
	NL
	jc	nofile
	mov	fhandle,ax
	mov	bx,ax
	mov	ah,40h
	mov	cx,6
	mov	dx,offset lfnstr
	int	21h
	mov	ax,71A6h
	mov	bx,fhandle
	mov	dx,offset outbuf
	stc
	int	21h
	RES	'71A6 file information'
	jc	@F
	mov	eax,dword ptr outbuf+36		; file size low
	call	hex32
	cmp	eax,6
	je	@F
	BAD
@@:	NL
	mov	ah,3Eh
	mov	bx,fhandle
	int	21h
nofile:

; 7143h get attributes
	mov	ax,7143h
	xor	bl,bl
	mov	dx,offset filname
	stc
	int	21h
	RES	'7143 attributes'
	NL

; 714Eh find first, 714Fh find next, 71A1h close
	mov	ax,714Eh
	mov	cx,0037h
	mov	si,1
	mov	dx,offset pattern
	mov	di,offset finddat
	stc
	int	21h
	RES	'714E find first'
	jc	@F
	mov	srchh,ax
	mov	si,offset finddat+44		; long name
	call	printz
	mov	si,offset finddat+304		; short name
	call	printz
	cmp	byte ptr finddat+45,' '		; "A long ..."
	je	nf
	BAD
nf:	NL
	mov	ax,714Fh
	mov	bx,srchh
	mov	si,1
	mov	di,offset finddat
	int	21h				; no second file: CF=1 AX=12h
	HDR	'714F find next'
	jnc	nfbad
	cmp	ax,12h
	je	nfok
nfbad:	BAD
	jmp	short nfx
nfok:	mov	dx,offset okmsg
	call	print
nfx:	NL
	mov	ax,71A1h
	mov	bx,srchh
	int	21h
@@:	NL

; 7160h full path (CL=0) and short path (CL=1)
	mov	ax,7160h
	xor	cx,cx
	mov	si,offset filname
	mov	di,offset outbuf
	stc
	int	21h
	RES	'7160 full path'
	jc	@F
	mov	si,offset outbuf
	call	printz
@@:	NL
	mov	ax,7160h
	mov	cx,1
	mov	si,offset filname
	mov	di,offset outbuf
	stc
	int	21h
	RES	'7160 short path'
	jc	@F
	mov	si,offset outbuf
	call	printz
@@:	NL

; 71A8h generate short name
	mov	ax,71A8h
	mov	si,offset newname+24		; "Another long name.txt"
	mov	di,offset outbuf
	mov	dx,0101h
	stc
	int	21h
	RES	'71A8 short name'
	jc	@F
	mov	si,offset outbuf
	call	printz
@@:	NL

; 7156h rename, 7141h delete, 713Ah rmdir
	mov	ax,7156h
	mov	dx,offset filname
	mov	di,offset newname
	stc
	int	21h
	RES	'7156 rename'
	NL
	mov	ax,7141h
	xor	si,si
	mov	dx,offset newname
	stc
	int	21h
	RES	'7141 delete'
	NL
	mov	ax,713Ah
	mov	dx,offset dirname
	stc
	int	21h
	RES	'713A rmdir'
	NL

; 71A0h volume information
	mov	ax,71A0h
	mov	dx,offset rootdir
	mov	di,offset outbuf
	mov	cx,32
	stc
	int	21h
	RES	'71A0 volume information'
	jc	@F
	mov	si,offset outbuf
	call	printz
@@:	NL

; 7303h extended free space
	mov	ax,7303h
	mov	dx,offset rootdir
	mov	di,offset outbuf
	mov	cx,44
	mov	word ptr outbuf+2,0		; version
	stc
	int	21h
	RES	'7303 free space'
	jc	@F
	mov	eax,dword ptr outbuf+12		; free clusters
	call	hex32
@@:	NL

; 7302h extended DPB
	mov	ax,7302h
	mov	dl,3
	mov	di,offset outbuf
	mov	cx,63
	stc
	int	21h
	RES	'7302 extended DPB'
	jc	@F
	movzx	eax,word ptr outbuf+2+2		; bytes per sector
	call	hex32
	cmp	ax,512
	je	@F
	BAD
@@:	NL

; 6501h extended country information into ES:DI
	mov	ax,6501h
	mov	bx,-1
	mov	dx,-1
	mov	cx,41
	mov	di,offset outbuf
	mov	byte ptr outbuf,0
	int	21h
	RES	'6501 country information'
	jc	@F
	cmp	byte ptr outbuf,1		; info ID
	je	@F
	BAD
@@:	NL

; 6521h capitalize
	mov	ax,6521h
	mov	cx,6
	mov	dx,offset lfnstr
	int	21h
	RES	'6521 capitalize'
	jc	@F
	cmp	byte ptr lfnstr,'A'
	je	@F
	BAD
@@:	NL

; 6300h DBCS table, 5D06h swappable data area: returned pointers readable
	mov	ax,6300h
	push	ds
	int	21h
	mov	ax,ds
	lar	cx,ax
	pop	ds
	HDR	'6300 DBCS table pointer'
	jz	@F
	BAD
	jmp	short d63
@@:	mov	dx,offset okmsg
	call	print
d63:	NL

	mov	ax,5D06h
	push	ds
	int	21h
	mov	ax,ds
	lar	cx,ax
	pop	ds
	HDR	'5D06 swappable data area pointer'
	jz	@F
	BAD
	jmp	short d5d
@@:	mov	dx,offset okmsg
	call	print
d5d:	NL

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

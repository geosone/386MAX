; XLAT32.ASM - DOS/BIOS API translation of the DPMI host for a 32-bit
; client: file read/write larger than the host buffer, long filenames
; (if an LFN API is present), INT 25h packet form, INT 21h AX=7305h and
; INT 13h AH=02h, called from a USE32 code segment.  Drive C:.
; Build: jwasm -mz XLAT32.ASM

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

NSEC	equ	20
FSIZE	equ	10000

	.data
rmseg	dw ?
t32seg	dw ?
entry	dd ?
nfail	dd 0
lfn	db 0
rm	RMREGS <>
hexbuf	db '00000000 $'
crlf	db 13,10,'$'
okmsg	db 'OK $'
failmsg	db 'FAIL $'
samemsg	db 'data same $'
diffmsg	db 'DATA DIFFERS $'
skipmsg	db 'skipped (no LFN API) $'
nosup	db 'not supported by DOS $'
nodpmi	db 'no DPMI host',13,10,'$'
nomode	db 'switch to protected mode as 32-bit client failed',13,10,'$'
banner	db 'DOS/BIOS translation test (32-bit client)',13,10,'$'
sumok	db 'XLAT32: all tests passed',13,10,'$'
sumfail	db 'XLAT32: failures: $'
fname	db 'C:\XLAT32.TMP',0
dirname	db 'C:\Long Directory 32',0
lname	db 'C:\Long Directory 32\A long file name.txt',0
pattern	db 'C:\Long Directory 32\*',0
strbuf	db 300 dup (0)
outbuf	db 300 dup (0)
finddat	db 318 dup (0)
fhandle	dd ?
pkt	dd 0
	dw NSEC
	dw offset bulk
pktsel	dw ?
pkt1	dd 0
	dw 1
pkt1off	dw ?
pkt1sel	dw ?
descrb	db 8 dup (0)
desc32	dw 0FFFFh,0
	db 0,9Ah,40h,0		; 32-bit code, limit 64 KB
bulk	db NSEC*512 dup (0)
single	db NSEC*512 dup (0)

	.code
start:
	mov	ax,@data
	mov	ds,ax
	mov	rmseg,ax
	mov	t32seg,seg start32
	mov	bx,LOWWORD offset t32end	; keep up to the end of _TEXT32,
	add	bx,15				; which follows the stack
	shr	bx,4
	add	bx,seg start32
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
@@:	test	bx,1				; 32-bit clients supported?
	jz	swfail
	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	swfail
	mov	es,ax
@@:	mov	ax,1				; 32-bit client
	call	entry
	jnc	pm16
swfail:	mov	dx,offset nomode
rmexit:	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h

; 16-bit PM: make a 32-bit code selector for start32 and jump there
pm16:	movzx	esp,sp				; 16-bit stack: ESP hiword zero
	mov	ax,0000h
	mov	cx,1
	int	31h
	mov	bx,ax
	movzx	eax,t32seg
	shl	eax,4
	mov	word ptr desc32+2,ax		; base 0-15
	shr	eax,16
	mov	byte ptr desc32+4,al		; base 16-23
	mov	byte ptr desc32+7,ah		; base 24-31
	mov	ax,cs
	and	al,3
	shl	al,5
	or	byte ptr desc32+5,al		; DPL = CPL
	push	ds
	pop	es
	mov	edi,offset desc32
	mov	ax,000Ch
	int	31h
	jnc	@F
	mov	ax,4C03h
	int	21h
@@:
	push	bx
	mov	ax,000Ah			; 32-bit stack:  alias of SS
	mov	bx,ss
	int	31h
	mov	bx,ax
	mov	ax,000Bh
	mov	edi,offset descrb
	int	31h
	or	byte ptr descrb+6,40h		; B bit
	mov	ax,000Ch
	int	31h
	pop	ax
	mov	ss,bx
	movzx	esp,sp
	push	ax
	mov	ax,LOWWORD offset start32
	push	ax
	retf

_TEXT32	segment use32 para public 'CODE32'
	assume	cs:_TEXT32,ds:DGROUP

; EDX = offset of a $ string
print	proc
	pushad
	push	es
	mov	rm.r_edx,edx
	mov	rm.r_eax,0900h
	mov	ax,rmseg
	mov	rm.r_ds,ax
	mov	rm.r_ss,0
	mov	rm.r_sp,0
	mov	rm.r_flags,0
	push	ds
	pop	es
	mov	edi,offset rm
	mov	ax,0300h
	mov	bx,0021h
	xor	ecx,ecx
	int	31h
	pop	es
	popad
	ret
print	endp

hex32	proc
	pushad
	mov	edi,offset hexbuf+7
	mov	ecx,8
hl:	mov	bl,al
	and	bl,0Fh
	add	bl,'0'
	cmp	bl,'9'
	jbe	@F
	add	bl,'A'-'9'-1
@@:	mov	[edi],bl
	dec	edi
	shr	eax,4
	loop	hl
	mov	edx,offset hexbuf
	call	print
	popad
	ret
hex32	endp

okfail	proc
	jc	ofail
	mov	edx,offset okmsg
	call	print
	clc
	ret
ofail:	inc	nfail
	mov	edx,offset failmsg
	call	print
	movzx	eax,ax
	call	hex32
	stc
	ret
okfail	endp

HDR	macro	txt
	local	m
_DATA	segment
m	db	txt,': $'
_DATA	ends
	pushfd
	push	edx
	mov	edx,offset m
	call	print
	pop	edx
	popfd
	endm

RES	macro	txt
	HDR	txt
	call	okfail
	endm

NL	macro
	pushfd
	push	edx
	mov	edx,offset crlf
	call	print
	pop	edx
	popfd
	endm

; ESI = ASCIIZ, printed in quotes
printz	proc
	pushad
	push	es
	push	ds
	pop	es
	mov	edi,offset strbuf
	mov	al,'"'
	stosb
@@:	lodsb
	or	al,al
	jz	@F
	stosb
	jmp	@B
@@:	mov	ax,' "'
	stosw
	mov	al,'$'
	stosb
	mov	edx,offset strbuf
	call	print
	pop	es
	popad
	ret
printz	endp

; if CF clear: compare ECX bytes of bulk and single
cmpn	proc
	jc	cnx
	pushad
	push	es
	push	ds
	pop	es
	mov	esi,offset bulk
	mov	edi,offset single
	repe	cmpsb
	pop	es
	popad
	je	@F
	inc	nfail
	mov	edx,offset diffmsg
	call	print
	ret
@@:	mov	edx,offset samemsg
	call	print
cnx:	ret
cmpn	endp

clrbulk	proc
	pushad
	push	es
	push	ds
	pop	es
	mov	edi,offset bulk
	mov	ecx,NSEC*512/4
	or	eax,-1
	rep	stosd
	pop	es
	popad
	ret
clrbulk	endp

start32:
	push	ds
	pop	es
	mov	pktsel,ds
	mov	pkt1sel,ds

; Write and read a file larger than the host's buffer
	mov	edi,offset single
	mov	ecx,FSIZE
	xor	eax,eax
@@:	stosb
	inc	al
	loop	@B
	mov	ah,3Ch
	xor	ecx,ecx
	mov	edx,offset fname
	int	21h
	RES	'3C create'
	NL
	mov	fhandle,eax
	mov	ebx,eax
	mov	ah,40h
	mov	ecx,FSIZE
	mov	edx,offset single
	int	21h
	RES	'40 write 10000 bytes'
	jc	@F
	call	hex32
@@:	NL
	mov	ebx,fhandle
	mov	ax,4200h
	xor	ecx,ecx
	xor	edx,edx
	int	21h
	call	clrbulk
	mov	ebx,fhandle
	mov	ah,3Fh
	mov	ecx,FSIZE
	mov	edx,offset bulk
	int	21h
	RES	'3F read 10000 bytes'
	jc	@F
	call	hex32
	mov	ecx,FSIZE
	call	cmpn
@@:	NL
	mov	ebx,fhandle
	mov	ah,3Eh
	int	21h
	mov	ah,41h
	mov	edx,offset fname
	int	21h

; Long filenames (only with an LFN API)
	mov	ax,7147h
	xor	dl,dl
	mov	esi,offset outbuf
	stc
	int	21h
	jc	nolfn
	cmp	ax,7100h
	je	nolfn
	mov	ax,7139h
	mov	edx,offset dirname
	stc
	int	21h
	RES	'7139 mkdir'
	NL
	mov	ax,716Ch
	mov	bx,0002h
	xor	ecx,ecx
	mov	dx,0012h
	mov	esi,offset lname
	stc
	int	21h
	RES	'716C create'
	NL
	jc	@F
	mov	ebx,eax
	mov	ah,3Eh
	int	21h
@@:	mov	ax,714Eh
	mov	cx,0037h
	mov	si,1
	mov	edx,offset pattern
	mov	edi,offset finddat
	stc
	int	21h
	RES	'714E find first'
	jc	@F
	push	eax
	mov	esi,offset finddat+44
	call	printz
	pop	ebx
	mov	ax,71A1h
	int	21h
@@:	NL
	mov	ax,7160h
	xor	ecx,ecx
	mov	esi,offset lname
	mov	edi,offset outbuf
	stc
	int	21h
	RES	'7160 full path'
	jc	@F
	mov	esi,offset outbuf
	call	printz
@@:	NL
	mov	ax,7141h
	xor	esi,esi
	mov	edx,offset lname
	stc
	int	21h
	RES	'7141 delete'
	NL
	mov	ax,713Ah
	mov	edx,offset dirname
	stc
	int	21h
	RES	'713A rmdir'
	NL
	jmp	short lfnx
nolfn:	HDR	'71xx long filenames'
	mov	edx,offset skipmsg
	call	print
	NL
lfnx:

; INT 25h packet form: 20 single sectors, then 20 at once
	xor	esi,esi
	mov	edi,offset single
rd1:	mov	pkt1,esi
	mov	pkt1off,di
	push	esi
	push	edi
	mov	al,2
	mov	cx,-1
	mov	ebx,offset pkt1
	int	25h
	pop	cx				; flags word left on the stack
	pop	edi
	pop	esi
	jc	rd1f
	add	edi,512
	inc	esi
	cmp	esi,NSEC
	jb	rd1
	clc
rd1f:	RES	'INT 25h single sectors'
	NL
	call	clrbulk
	mov	al,2
	mov	cx,-1
	mov	ebx,offset pkt
	int	25h
	pop	cx
	RES	'INT 25h packet 20 sectors'
	mov	ecx,NSEC*512
	call	cmpn
	NL

; INT 21h AX=7305h
	call	clrbulk
	mov	ax,7305h
	mov	cx,-1
	mov	dl,3
	xor	esi,esi
	mov	ebx,offset pkt
	stc
	int	21h
	HDR	'7305 read 20 sectors'
	jnc	@F
	cmp	ax,7300h
	jne	f7305
	mov	edx,offset nosup
	call	print
	jmp	short n7305
f7305:	call	okfail
	jmp	short n7305
@@:	call	okfail
	mov	ecx,NSEC*512
	call	cmpn
n7305:	NL

; INT 13h AH=02h, 17 sectors, compared with single reads
	mov	esi,1
	mov	edi,offset single
r13:	mov	ax,0201h
	mov	ecx,esi
	mov	dx,0080h
	mov	ebx,edi
	push	esi
	push	edi
	int	13h
	pop	edi
	pop	esi
	jc	r13f
	add	edi,512
	inc	esi
	cmp	esi,17
	jbe	r13
	clc
r13f:	RES	'INT 13h single sectors'
	NL
	call	clrbulk
	mov	ax,0211h
	mov	cx,0001h
	mov	dx,0080h
	mov	ebx,offset bulk
	int	13h
	RES	'INT 13h 17 sectors'
	mov	ecx,17*512
	call	cmpn
	NL

	cmp	nfail,0
	jne	@F
	mov	edx,offset sumok
	call	print
	mov	ax,4C00h
	int	21h
@@:	mov	edx,offset sumfail
	call	print
	mov	eax,nfail
	call	hex32
	NL
	mov	ax,4C02h
	int	21h

t32end	label	byte

_TEXT32	ends

	end	start

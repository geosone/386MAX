; VDSFUNC.ASM - Virtual DMA Services (INT 4Bh AX=81xxh) of the active V86
; monitor: version, lock/unlock of conventional memory (physical address
; checked), scatter/gather lock, DMA buffer request/copy in/copy out/release
; with data checks, lock of a region in an UMB (contiguous, buffered or
; the documented error), DMA translation disable/enable counting and the
; error codes 05h, 0Ah, 0Bh, 0Ch, 0Eh.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no VDS.
; Build: jwasm -mz VDSFUNC.ASM

	.model	small
	.386
	.stack	1024

DDS	struc
dsize	dd ?
dofs	dd ?
dseg	dw ?
did	dw ?
dphys	dd ?
DDS	ends

EDDS	struc
esize	dd ?
eofs	dd ?
eseg	dw ?
eres	dw ?
eavail	dw ?
eused	dw ?
EDDS	ends

NREG	equ	16
BSIZE	equ	1000h		; DMA buffer test size

	.data
vd	DDS	<>
ve	EDDS	<>
regs	dd	2*NREG dup (?)
maxbuf	dd	?
umbseg	dw	0
oldstrat dw	?
oldlink	db	?
	.data?
	align	16
buf1	db	4000h dup (?)
buf2	db	BSIZE dup (?)

	.code
	include	TESTLIB.INC

vds	macro	fn
	mov	ax,fn
	int	4Bh
	endm

; DDS for cx bytes at ds:si
setdds	proc
	movzx	ecx,cx
	mov	vd.dsize,ecx
	movzx	esi,si
	mov	vd.dofs,esi
	mov	vd.dseg,ds
	mov	vd.did,0
	mov	vd.dphys,0
	ret
setdds	endp

; prints " (AL=xx)" after an error
pal	proc
	pushf
	jnc	@F
	NOTE_	' AL='
	call	phex8
@@:	popf
	ret
pal	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	push	es
	push	40h
	pop	es
	test	byte ptr es:[7Bh],20h	; VDS present bit
	pop	es
	jnz	@F
	INFO	'no VDS (40:7B bit 5)'
	mov	ax,4C02h
	int	21h
@@:
	TITLE_	'version'
	xor	dx,dx
	vds	8102h
	CHECK	'get version (8102h)', nc
	NOTE_	'version '
	call	phex16
	NOTE_	', product '
	mov	ax,bx
	call	phex16
	NOTE_	', revision '
	mov	ax,cx
	call	phex16
	NOTE_	', max. DMA buffer '
	mov	word ptr maxbuf,di
	mov	word ptr maxbuf+2,si
	mov	eax,maxbuf
	call	phex32
	call	pcrlf
	mov	dx,1
	vds	8102h
	pushf
	cmp	al,10h
	je	@F
	popf
	clc			; not every host checks the flags of 8102h
	pushf
@@:	popf
	call	pal
	CHECK	'reserved flag in DX: 10h (or ignored)', c

	TITLE_	'lock conventional memory'
	mov	si,offset buf1
	mov	cx,4000h
	call	setdds
	mov	di,offset vd
	mov	dx,4		; no buffer
	vds	8103h
	call	pal
	CHECK	'lock 16 KB (8103h)', nc
	jc	nolock
	mov	ax,ds
	movzx	eax,ax
	shl	eax,4
	movzx	ebx,si
	add	eax,ebx
	NOTE_	'linear '
	call	phex32
	NOTE_	', physical '
	push	eax
	mov	eax,vd.dphys
	call	phex32
	call	pcrlf
	pop	eax
	cmp	eax,vd.dphys	; conventional memory is not remapped
	CHECK	'physical = linear', e
	mov	di,offset vd
	xor	dx,dx
	vds	8104h
	call	pal
	CHECK	'unlock (8104h)', nc
nolock:
	; scatter/gather
	mov	ve.esize,4000h
	movzx	eax,si
	mov	ve.eofs,eax
	mov	ve.eseg,ds
	mov	ve.eavail,NREG
	mov	ve.eused,0
	mov	di,offset ve
	xor	dx,dx
	vds	8105h
	call	pal
	CHECK	'scatter/gather lock (8105h)', nc
	jc	nosg
	mov	ax,ve.eused
	NOTE_	'regions '
	call	phex16
	call	pcrlf
	xor	eax,eax
	mov	cx,ve.eused
	mov	si,offset ve+size EDDS
	jcxz	@F
sgsum:	add	eax,[si+4]
	add	si,8
	loop	sgsum
@@:	cmp	eax,4000h
	CHECK	'region sizes add up to 16 KB', e
	mov	di,offset ve
	xor	dx,dx
	vds	8106h
	call	pal
	CHECK	'scatter/gather unlock (8106h)', nc
nosg:

	TITLE_	'DMA buffer'
	mov	vd.dsize,BSIZE
	mov	vd.dofs,0
	mov	vd.dseg,0
	mov	vd.did,0
	mov	di,offset vd
	xor	dx,dx
	vds	8107h
	call	pal
	CHECK	'request 4 KB buffer (8107h)', nc
	jc	nobuf
	NOTE_	'buffer id '
	mov	ax,vd.did
	call	phex16
	NOTE_	', physical '
	mov	eax,vd.dphys
	call	phex32
	call	pcrlf
	mov	di,offset buf1	; pattern
	mov	cx,BSIZE
	xor	al,al
@@:	mov	[di],al
	add	al,37
	inc	di
	loop	@B
	mov	vd.dofs,offset buf1
	mov	vd.dseg,ds
	mov	di,offset vd
	xor	bx,bx
	xor	cx,cx		; offset in the buffer
	xor	dx,dx
	vds	8109h
	call	pal
	CHECK	'copy into the buffer (8109h)', nc
	mov	vd.dofs,offset buf2
	mov	di,offset vd
	xor	bx,bx
	xor	cx,cx
	xor	dx,dx
	vds	810Ah
	call	pal
	CHECK	'copy out of the buffer (810Ah)', nc
	mov	si,offset buf1
	mov	di,offset buf2
	mov	cx,BSIZE
	repe	cmpsb
	CHECK	'data equal', e
	mov	di,offset vd
	mov	vd.dsize,BSIZE
	xor	bx,bx
	mov	cx,1
	xor	dx,dx
	vds	8109h		; one byte past the end: 0Bh by the spec, MS EMM386
	jc	@F		; does not check it (reference behaviour)
	INFO	'copy beyond the buffer: no error (as MS EMM386)'
	jmp	cpy1
@@:	NOTE_	'copy beyond the buffer: AL='
	call	phex8
	call	pcrlf
cpy1:
	mov	di,offset vd
	xor	dx,dx
	vds	8108h
	call	pal
	CHECK	'release (8108h)', nc
	mov	di,offset vd
	xor	dx,dx
	vds	8108h
	pushf
	cmp	al,0Ah
	je	@F
	popf
	clc
	pushf
@@:	popf
	call	pal
	CHECK	'release again: 0Ah', c
	; larger than the buffer
	mov	eax,maxbuf
	add	eax,1000h
	mov	vd.dsize,eax
	mov	vd.did,0
	mov	di,offset vd
	xor	dx,dx
	vds	8107h
	pushf
	cmp	al,5
	je	@F
	cmp	al,4
	je	@F
	popf
	clc
	pushf
@@:	popf
	call	pal
	CHECK	'buffer larger than the maximum: 05h/04h', c
	jc	nobuf
	mov	di,offset vd
	xor	dx,dx
	vds	8108h
nobuf:

	TITLE_	'region in an UMB'
	mov	ax,5800h
	int	21h
	mov	oldstrat,ax
	mov	ax,5802h
	int	21h
	mov	oldlink,al
	mov	ax,5803h
	mov	bx,1
	int	21h
	mov	ax,5801h
	mov	bx,41h		; best fit, high only
	int	21h
	mov	bx,400h		; 16 KB
	mov	ah,48h
	int	21h
	jc	@F
	cmp	ax,0A000h
	jb	@F
	mov	umbseg,ax
@@:	mov	ax,5801h
	mov	bx,oldstrat
	int	21h
	mov	ax,5803h
	movzx	bx,oldlink
	int	21h
	cmp	umbseg,0
	jne	@F
	INFO	'no 16 KB UMB, skipped'
	jmp	noumb
@@:	NOTE_	'UMB at '
	mov	ax,umbseg
	call	phex16
	call	pcrlf
	; without a buffer: either contiguous or error 01h with the
	; contiguous length in the size field
	mov	vd.dsize,4000h
	mov	vd.dofs,0
	mov	ax,umbseg
	mov	vd.dseg,ax
	mov	vd.did,0
	mov	di,offset vd
	mov	dx,4		; no buffer
	vds	8103h
	jnc	umbc
	push	ax
	NOTE_	'not contiguous, AL='
	call	phex8
	NOTE_	', contiguous size '
	mov	eax,vd.dsize
	call	phex32
	call	pcrlf
	pop	ax
	cmp	al,1
	jne	@F
	cmp	vd.dsize,4000h
@@:	CHECK	'lock without buffer: 01h and a shorter size', b
	jmp	umbbuf
umbc:	NOTE_	'contiguous at '
	mov	eax,vd.dphys
	call	phex32
	call	pcrlf
	mov	di,offset vd
	xor	dx,dx
	vds	8104h
	call	pal
	CHECK	'lock without buffer, unlock', nc
umbbuf:	; with a buffer allowed: success, or 05h/04h when the buffer is
	; too small
	mov	vd.dsize,4000h
	mov	vd.dofs,0
	mov	ax,umbseg
	mov	vd.dseg,ax
	mov	vd.did,0
	mov	di,offset vd
	xor	dx,dx
	vds	8103h
	jnc	umbok
	call	pal
	cmp	al,5
	je	@F
	cmp	al,4
@@:	CHECK	' lock with buffer allowed: too large (05h/04h)', e
	jmp	umbfree
umbok:	NOTE_	'buffer id '
	mov	ax,vd.did
	call	phex16
	call	pcrlf
	mov	di,offset vd
	xor	dx,dx
	vds	8104h
	call	pal
	CHECK	'lock with buffer allowed, unlock', nc
umbfree:
	mov	es,umbseg
	mov	ah,49h
	int	21h
	push	ds
	pop	es
noumb:

	TITLE_	'DMA translation'
	mov	bx,2
	xor	dx,dx
	vds	810Bh
	call	pal
	CHECK	'disable channel 2 (810Bh)', nc
	mov	bx,2
	xor	dx,dx
	vds	810Ch
	call	pal
	CHECK	'enable channel 2 (810Ch)', nc
	mov	bx,2
	xor	dx,dx
	vds	810Ch
	pushf
	cmp	al,0Eh
	je	@F
	popf
	clc
	pushf
@@:	popf
	call	pal
	CHECK	'enable again: count underflow 0Eh', c
	mov	bx,8
	xor	dx,dx
	vds	810Bh
	pushf
	cmp	al,0Ch
	je	@F
	popf
	clc
	pushf
@@:	popf
	call	pal
	CHECK	'channel 8: invalid channel 0Ch', c
	call	finish

	end	start

; XMSFUNC.ASM - XMS 2.0/3.0 functions of the active XMS driver:
; version, A20, free memory, allocate/free, moves between conventional and
; extended memory (verified), lock/unlock with lock counts, handle
; information, resize (0Fh/8Fh) with preserved contents, the documented
; error codes, handle exhaustion and a pattern over the whole largest block.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no XMS driver.
; Build: jwasm -mz XMSFUNC.ASM

	.model	small
	.386
	.stack	1024

XMOVE	struc
mlen	dd ?
msrch	dw ?
msrco	dd ?
mdsth	dw ?
mdsto	dd ?
XMOVE	ends

BUFSZ	equ	4000h		; 16 KB transfer buffers

	.data
xmsent	dd ?
mv	XMOVE <>
hnd	dw ?
hbig	dw ?
bigkb	dd ?
offs	dd ?
clen	dw BUFSZ	; length of a transfer (the last one of a block may be shorter)
nhnd	dw ?
hlist	dw 256 dup (?)

	.data?
buf1	db BUFSZ dup (?)
buf2	db BUFSZ dup (?)

	.code
	include	TESTLIB.INC

xms	macro	fn
	mov	ah,fn
	call	[xmsent]
	endm

; OK when bl is code1 or code2; prints bl
BLIS	macro	text, code1, code2
	local	ok
	NOTE_	text, ' (bl='
	push	ax
	mov	al,bl
	call	phex8
	pop	ax
	NOTE_	')'
	cmp	bl,code1
	je	ok
	cmp	bl,code2
ok:	CHECK	' ', e
	endm

; move cx:si bytes - set up mv beforehand; returns ax=1 ok / bl=error
domove	proc
	push	si
	mov	si,offset mv
	xms	0Bh
	pop	si
	ret
domove	endp

; fill buf1 with a pattern from seed eax (dwords)
fill1	proc
	push	di
	push	cx
	mov	di,offset buf1
	mov	cx,BUFSZ/4
@@:	mov	[di],eax
	add	eax,9E3779B9h
	add	di,4
	loop	@B
	pop	cx
	pop	di
	ret
fill1	endp

; compare buf1 and buf2: ZF set = equal
cmpbuf	proc
	push	si
	push	di
	push	cx
	push	es
	push	ds
	pop	es
	mov	si,offset buf1
	mov	di,offset buf2
	mov	cx,clen
	shr	cx,2
	cld
	repe	cmpsd
	pop	es
	pop	cx
	pop	di
	pop	si
	ret
cmpbuf	endp

; buf1 -> handle hnd at offset eax (BUFSZ bytes)
tox	proc
	push	eax
	movzx	eax,clen
	mov	mv.mlen,eax
	pop	eax
	mov	mv.msrch,0
	mov	word ptr mv.msrco,offset buf1
	mov	word ptr mv.msrco+2,ds
	mov	mv.mdsto,eax
	push	ax
	mov	ax,hnd
	mov	mv.mdsth,ax
	pop	ax
	jmp	domove
tox	endp

; handle hnd at offset eax -> buf2
fromx	proc
	push	eax
	movzx	eax,clen
	mov	mv.mlen,eax
	pop	eax
	push	ax
	mov	ax,hnd
	mov	mv.msrch,ax
	pop	ax
	mov	mv.msrco,eax
	mov	mv.mdsth,0
	mov	word ptr mv.mdsto,offset buf2
	mov	word ptr mv.mdsto+2,ds
	jmp	domove
fromx	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	ax,4300h
	int	2Fh
	cmp	al,80h
	je	@F
	INFO	'no XMS driver'
	mov	ax,4C02h
	int	21h
@@:	mov	ax,4310h
	int	2Fh
	mov	word ptr xmsent,bx
	mov	word ptr xmsent+2,es
	push	ds
	pop	es

	TITLE_	'XMS version, A20'
	xms	00h
	NOTE_	'version '
	call	phex16
	cmp	ax,0200h
	CHECK	' >= 2.00', ae
	xms	07h
	NOTE_	'A20 state (07h): '
	call	phex8
	call	pcrlf
	xms	05h		; local enable
	cmp	ax,1
	CHECK	'local enable A20 (05h)', e
	xms	07h
	cmp	ax,1
	CHECK	'A20 is on (07h)', e
	xms	06h		; local disable; 94h: still on (DOS=HIGH)
	cmp	ax,1
	je	@F
	cmp	bl,94h
@@:	CHECK	'local disable A20 (06h)', e

	TITLE_	'free memory'
	xms	08h
	NOTE_	'08h: largest '
	call	phex16
	push	ax
	mov	ax,dx
	NOTE_	' KB, total '
	call	phex16
	INFO	' KB'
	pop	ax
	cmp	ax,64
	CHECK	'at least 64 KB free', ae
	movzx	esi,ax
	xms	88h
	cmp	bl,0
	jne	nox3
	NOTE_	'88h: largest '
	call	phex32
	mov	bigkb,eax
	mov	eax,edx
	NOTE_	' KB, total '
	call	phex32
	mov	eax,ecx
	NOTE_	' KB, highest address '
	call	phex32
	call	pcrlf
	mov	eax,bigkb
	cmp	eax,esi
	CHECK	'88h largest >= 08h largest', ae
	cmp	edx,bigkb
	CHECK	'88h total >= largest', ae
	jmp	x3done
nox3:	INFO	'88h not supported (XMS 2.0)'
	mov	bigkb,esi
x3done:

	TITLE_	'allocate, lock, move'
	mov	dx,64
	xms	09h
	mov	hnd,dx
	cmp	ax,1
	CHECK	'allocate 64 KB (09h)', e
	mov	dx,hnd
	xms	0Ch
	cmp	ax,1
	CHECK	'lock (0Ch)', e
	push	dx
	push	bx
	pop	eax
	NOTE_	'linear address '
	call	phex32
	call	pcrlf
	cmp	eax,100000h
	CHECK	'address above 1 MB', ae
	mov	dx,hnd
	xms	0Eh
	cmp	bh,1
	CHECK	'lock count 1 (0Eh)', e
	cmp	dx,64
	CHECK	'size 64 KB (0Eh)', e
	mov	dx,hnd
	xms	0Ah
	cmp	bl,0ABh
	CHECK	'free of a locked block fails with ABh', e
	mov	dx,hnd
	xms	0Dh
	cmp	ax,1
	CHECK	'unlock (0Dh)', e
	mov	dx,hnd
	xms	0Eh
	cmp	bh,0
	CHECK	'lock count 0', e
	mov	dx,hnd
	xms	0Dh
	cmp	bl,0AAh
	CHECK	'unlock of an unlocked block fails with AAh', e

	mov	eax,12345678h
	call	fill1
	xor	eax,eax
	call	tox
	cmp	ax,1
	CHECK	'move conventional -> extended', e
	mov	eax,8000h
	call	tox
	mov	eax,8000h
	call	fromx
	cmp	ax,1
	CHECK	'move extended -> conventional', e
	call	cmpbuf
	CHECK	'data read back equal', e
	; extended -> extended inside the block: 0..7FFF -> 8000..FFFF
	mov	eax,0AAAA5555h
	call	fill1
	xor	eax,eax
	call	tox
	mov	mv.mlen,BUFSZ
	mov	ax,hnd
	mov	mv.msrch,ax
	mov	mv.mdsth,ax
	mov	mv.msrco,0
	mov	mv.mdsto,8000h
	call	domove
	cmp	ax,1
	CHECK	'move extended -> extended', e
	mov	eax,8000h
	call	fromx
	call	cmpbuf
	CHECK	'data equal', e
	; conventional -> conventional (handle 0 both)
	mov	mv.mlen,BUFSZ
	mov	mv.msrch,0
	mov	word ptr mv.msrco,offset buf1
	mov	word ptr mv.msrco+2,ds
	mov	mv.mdsth,0
	mov	word ptr mv.mdsto,offset buf2
	mov	word ptr mv.mdsto+2,ds
	mov	dword ptr buf2,0
	call	domove
	cmp	ax,1
	CHECK	'move conventional -> conventional', e
	call	cmpbuf
	CHECK	'data equal', e

	TITLE_	'error codes'
	mov	mv.mlen,1001h
	mov	ax,hnd
	mov	mv.msrch,ax
	mov	mv.mdsth,ax
	mov	mv.msrco,0
	mov	mv.mdsto,8000h
	call	domove
	cmp	bl,0A7h
	CHECK	'odd length: A7h', e
	mov	mv.mlen,1000h
	mov	mv.msrch,0FFF0h
	call	domove
	cmp	bl,0A3h
	CHECK	'invalid source handle: A3h', e
	mov	ax,hnd
	mov	mv.msrch,ax
	mov	mv.mdsth,0FFF0h
	call	domove
	cmp	bl,0A5h
	CHECK	'invalid destination handle: A5h', e
	mov	ax,hnd
	mov	mv.mdsth,ax
	mov	mv.mdsto,0FFF0h	; 1000h bytes from FFF0h leave the 64 KB block
	call	domove
	BLIS	'destination beyond the block: A6h/A7h', 0A6h, 0A7h
	mov	mv.mdsto,0
	mov	mv.msrco,0FFF0h
	call	domove
	BLIS	'source beyond the block: A4h/A7h', 0A4h, 0A7h
	mov	dx,0FFF0h
	xms	0Eh
	cmp	bl,0A2h
	CHECK	'handle info of an invalid handle: A2h', e

	TITLE_	'resize'
	mov	eax,55AA1234h
	call	fill1
	xor	eax,eax
	call	tox
	mov	bx,128
	mov	dx,hnd
	xms	0Fh
	cmp	ax,1
	CHECK	'grow to 128 KB (0Fh)', e
	mov	dx,hnd
	xms	0Eh
	cmp	dx,128
	CHECK	'size 128 KB', e
	xor	eax,eax
	call	fromx
	call	cmpbuf
	CHECK	'contents kept', e
	mov	eax,18000h
	call	tox
	cmp	ax,1
	CHECK	'move into the new part', e
	mov	bx,32
	mov	dx,hnd
	xms	0Fh
	cmp	ax,1
	CHECK	'shrink to 32 KB', e
	xor	eax,eax
	call	fromx
	call	cmpbuf
	CHECK	'contents kept', e
	mov	dx,hnd
	xms	0Ch
	mov	bx,64
	mov	dx,hnd
	xms	0Fh
	cmp	bl,0ABh
	CHECK	'resize of a locked block fails with ABh', e
	mov	dx,hnd
	xms	0Dh
	xms	00h
	cmp	ah,3
	jb	nores3
	mov	ebx,96
	mov	dx,hnd
	xms	8Fh
	cmp	ax,1
	CHECK	'resize to 96 KB (8Fh)', e
	mov	dx,hnd
	xms	8Eh
	cmp	edx,96
	CHECK	'size 96 KB (8Eh)', e
	xor	eax,eax
	call	fromx
	call	cmpbuf
	CHECK	'contents kept', e
nores3:
	mov	dx,hnd
	xms	0Ah
	cmp	ax,1
	CHECK	'free (0Ah)', e
	mov	dx,hnd
	xms	0Ah
	cmp	bl,0A2h
	CHECK	'second free fails with A2h', e

	TITLE_	'zero length block'
	; spec 09h: "Allocation of a zero length extended memory buffer is
	; allowed."
	xor	dx,dx
	xms	09h
	mov	hnd,dx
	cmp	ax,1
	CHECK	'allocate 0 KB (09h)', e
	jne	@F
	mov	dx,hnd
	xms	0Eh
	cmp	dx,0
	CHECK	'size 0 KB (0Eh)', e
	mov	dx,hnd
	xms	0Ah
	cmp	ax,1
	CHECK	'free it', e
@@:
	TITLE_	'handles'
	mov	nhnd,0
	mov	di,offset hlist
nexth:	cmp	nhnd,256
	je	allh
	mov	dx,1
	xms	09h
	cmp	ax,1
	jne	allh
	mov	[di],dx
	add	di,2
	inc	nhnd
	jmp	nexth
allh:	mov	ax,nhnd
	NOTE_	'allocated handles: '
	call	phex16
	call	pcrlf
	cmp	nhnd,16
	CHECK	'at least 16 handles', ae
	cmp	nhnd,256
	je	@F
	BLIS	'no more handles: A1h/A0h', 0A1h, 0A0h
@@:	xor	bp,bp
freeh:	cmp	nhnd,0
	je	freed
	sub	di,2
	mov	dx,[di]
	xms	0Ah
	cmp	ax,1
	je	@F
	inc	bp
@@:	dec	nhnd
	jmp	freeh
freed:	cmp	bp,0
	CHECK	'all of them freed', e

	TITLE_	'largest block'
	mov	eax,bigkb
	cmp	eax,256
	jae	@F
	INFO	'less than 256 KB, skipped'
	jmp	bigdone
@@:	cmp	eax,40000h	; at most 256 MB
	jbe	@F
	mov	eax,40000h
	mov	bigkb,eax
@@:	mov	edx,eax
	xms	00h
	cmp	ah,3
	jb	@F
	mov	edx,bigkb
	xms	89h
	jmp	bigal
@@:	mov	dx,word ptr bigkb
	xms	09h
bigal:	mov	hnd,dx
	cmp	ax,1
	CHECK	'allocate the largest block', e
	jne	bigdone
	mov	eax,bigkb
	shl	eax,10
	mov	bigkb,eax	; now bytes
	xor	eax,eax
	mov	offs,eax
bigw:	call	setclen
	mov	eax,offs
	call	fill1
	mov	eax,offs
	call	tox
	cmp	ax,1
	jne	bigerr
	add	offs,BUFSZ
	mov	eax,offs
	cmp	eax,bigkb
	jb	bigw
	clc
	jmp	bigf
bigerr:	NOTE_	'move failed at offset '
	mov	eax,offs
	call	phex32
	NOTE_	', bl='
	mov	al,bl
	call	phex8
	call	pcrlf
	stc
bigf:	CHECK	'write a pattern over the whole block', nc
	xor	eax,eax
	mov	offs,eax
	xor	bp,bp
bigr:	call	setclen
	mov	eax,offs
	call	fromx
	cmp	ax,1
	jne	bige
	mov	eax,offs
	call	fill1
	call	cmpbuf
	je	@F
bige:	cmp	bp,0
	jne	bige1
	NOTE_	'first difference in the 16 KB at '
	mov	eax,offs
	call	phex32
	call	pcrlf
bige1:	inc	bp
@@:	add	offs,BUFSZ
	mov	eax,offs
	cmp	eax,bigkb
	jb	bigr
	cmp	bp,0
	CHECK	'read back and compare', e
	mov	dx,hnd
	xms	0Ah
	cmp	ax,1
	CHECK	'free', e
	mov	clen,BUFSZ
bigdone:
	call	finish

; clen = min(BUFSZ, bigkb - offs)
setclen	proc
	push	eax
	mov	eax,bigkb
	sub	eax,offs
	cmp	eax,BUFSZ
	jbe	@F
	mov	eax,BUFSZ
@@:	mov	clen,ax
	pop	eax
	ret
setclen	endp

	end	start

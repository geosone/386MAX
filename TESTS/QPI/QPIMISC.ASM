; QPIMISC.ASM - QEMM Programming Interface:  the smaller functions of
; QEMM 97 beyond RBIL:  1B07h, 1E03h/1E04h (driver directory and file
; name), 1E05h, 22h (DESQview/X shared pool control block), 23h (VCPI
; quota pointer), 28h and 2Ah (ANALYSIS bitmaps).  Expected values follow QEMM 97 (reference profile qemm).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPIMISC.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
buf	db	80 dup ('?')
bufend	label	byte
blk1	db	22 dup (0)		; 22h control blocks (version at 15h)
	db	10 dup (0)
blk2	db	22 dup (0)
	db	10 dup (0)
blkbad	db	22 dup (0)
	db	10 dup (0)
quota	dd	1000
bmp	db	32 dup (0AAh)
	.code
	include	TESTLIB.INC

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; ES:DI -> data (Seg:Off of a block in DGROUP) in EAX
blkptr	macro	b
	mov	ax,ds
	shl	eax,16
	mov	ax,offset b
	endm

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	push	es
	mov	ah,3Fh
	mov	cx,5145h
	mov	dx,4D4Dh
	int	67h
	mov	word ptr qpi,di
	mov	word ptr qpi+2,es
	pop	es
	cmp	ah,0
	jne	@F
	mov	eax,qpi
	or	eax,eax
	jnz	haveqpi
@@:	INFO	'no QPI'
	mov	ax,4C02h
	int	21h
haveqpi:

	TITLE_	'1E03h/1E04h driver directory and file name'
	mov	di,offset buf
	mov	ax,1E03h
	call	qcall
	CHECK	'1E03 CF=0', nc
	mov	cx,bx
	mov	si,offset buf
	sub	di,si
	cmp	di,bx
	CHECK	'1E03 DI advanced by BX', e
	cmp	bx,3
	CHECK	'1E03 BX >= 3 ("C:\")', ae
	cmp	byte ptr buf+1,':'
	CHECK	'1E03 starts with a drive', e
	mov	bx,cx
	cmp	byte ptr buf[bx-1],'\'
	CHECK	'1E03 ends with "\"', e
	cmp	byte ptr buf[bx],'?'
	CHECK	'1E03 not NUL-terminated', e
	NOTE_	'  directory: '
	mov	byte ptr buf[bx],'$'
	mov	dx,offset buf
	call	pstr
	call	pcrlf
	mov	di,offset buf
	mov	al,'?'
	mov	cx,bufend-buf
	rep	stosb
	mov	di,offset buf
	mov	ax,1E04h
	call	qcall
	CHECK	'1E04 CF=0', nc
	mov	si,offset buf
	sub	di,si
	cmp	di,bx
	CHECK	'1E04 DI advanced by BX', e
	cmp	dword ptr buf[bx-4],'SYS.'
	CHECK	'1E04 ends with ".SYS"', e
	NOTE_	'  file: '
	mov	byte ptr buf[bx],'$'
	mov	dx,offset buf
	call	pstr
	call	pcrlf
	mov	ax,1E05h
	call	qcall
	CHECK	'1E05 CF=1 (disabled)', c

	TITLE_	'1B07h, 28h, 2Ah'
	mov	ax,1B07h
	call	qcall
	CHECK	'1B07 CF=0', nc
	cmp	al,1
	CHECK	'1B07 AL = 0 or 1', be
	mov	ax,2800h
	xor	bx,bx
	call	qcall
	CHECK	'2800 BX=0 CF=0', nc
	mov	di,offset bmp
	mov	ax,2A00h
	call	qcall
	CHECK	'2A00 CF=0', nc
	cmp	byte ptr bmp,0AAh
	CHECK	'2A00 bitmap written', ne
	mov	di,offset bmp
	mov	ax,2A01h
	call	qcall
	CHECK	'2A01 CF=0', nc

; (19h, 1Dh and 2Bh are not called:  QEMM 97 crashes on 19h although its
; table says CF=1)

	TITLE_	'22h DESQview/X shared pool control block'
	mov	ax,2200h
	call	qcall
	CHECK	'2200 CF=0', nc
	mov	ax,es
	shl	eax,16
	mov	ax,di
	push	ds
	pop	es
	or	eax,eax
	CHECK	'2200 no block registered', z
	mov	byte ptr blk1+15h,2
	mov	byte ptr blk2+15h,2
	mov	byte ptr blkbad+15h,1
	mov	di,offset blkbad
	mov	ax,2201h
	call	qcall
	CHECK	'2201 version 01h refused', c
	mov	di,offset blk1
	mov	ax,2201h
	call	qcall
	CHECK	'2201 register block 1', nc
	cmp	dword ptr blk1+4,0
	CHECK	'block 1 got the free page count', ne
	cmp	dword ptr blk1,0
	CHECK	'block 1 has no previous block', e
	mov	ax,2200h
	call	qcall
	mov	ax,es
	push	ds
	pop	es
	cmp	ax,seg blk1
	jne	@F
	cmp	di,offset blk1
@@:	CHECK	'2200 returns block 1', e
	mov	di,offset blk2
	mov	ax,2201h
	call	qcall
	CHECK	'2201 register block 2', nc
	blkptr	blk1
	cmp	dword ptr blk2,eax
	CHECK	'block 2 linked to block 1', e
	test	byte ptr blk1+14h,4
	CHECK	'block 1 marked superseded', nz
	xor	di,di
	mov	es,di
	mov	ax,2201h
	call	qcall
	push	ds
	pop	es
	CHECK	'2201 0:0 back to block 1', nc
	test	byte ptr blk1+14h,4
	CHECK	'block 1 active again', z
	mov	ax,2200h
	call	qcall
	mov	ax,es
	push	ds
	pop	es
	cmp	ax,seg blk1
	jne	@F
	cmp	di,offset blk1
@@:	CHECK	'2200 returns block 1 again', e
	xor	di,di
	mov	es,di
	mov	ax,2201h
	call	qcall
	push	ds
	pop	es
	mov	ax,2200h
	call	qcall
	mov	ax,es
	shl	eax,16
	mov	ax,di
	push	ds
	pop	es
	or	eax,eax
	CHECK	'2201 0:0 again: none registered', z

	TITLE_	'23h VCPI quota pointer'
	mov	di,offset quota
	xor	bx,bx
	mov	ax,2301h
	call	qcall
	CHECK	'2301 set slot 0', nc
	xor	bx,bx
	mov	ax,2300h
	call	qcall
	mov	ax,es
	push	ds
	pop	es
	CHECK	'2300 get slot 0', nc
	cmp	ax,seg quota
	jne	@F
	cmp	di,offset quota
@@:	CHECK	'2300 returns the quota pointer', e
	mov	bx,1
	mov	ax,2300h
	call	qcall
	push	ds
	pop	es
	CHECK	'2300 slot 1 refused', c
	xor	bx,bx
	mov	ax,2302h
	call	qcall
	CHECK	'2302 clear slot 0', nc
	mov	ax,23FFh
	call	qcall
	CHECK	'23FF reset', nc

	call	finish

	end	start

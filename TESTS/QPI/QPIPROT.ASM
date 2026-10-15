; QPIPROT.ASM - QEMM Programming Interface 14h (DESQview protection
; levels), the part DESQview 2.80 uses on QEMM 97 (level 0):  1400h
; initialize (AX = 4705h, required process segment sizes 0/48h/49h/5Bh
; paragraphs), 1402h set level 0 (a NOP), 1406h apply, 1401h end.
; The configuration has no regions and an empty handler array.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPIPROT.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
cfg	dw	0			; +00 breakpoint segment (none)
	dd	?			; +02 real handler array
	dd	?			; +06 region list
	dd	?			; +0A size buffer
	dd	?			; +0E violation callback
	dw	0			; +12 shared region segment
	dd	?			; +14 ==> shared region size
handlers dd	128 dup (0)
regions	dw	0			; no regions
sizes	dw	4 dup (0FFFFh)
shsize	dw	0
lvl	dw	0			; 1402h structure:  +00 X
	dw	0			; +02 process memory segment
	dw	0			; +04 its size in paragraphs
	dw	3 dup (0)		; +06 head node
	dw	0			; +0C shared flag
xseg	db	0180h dup (0)		; the process segment X (rounded up)
	.code
	include	TESTLIB.INC

cb	proc	far			; violation callback (never called)
	ret
cb	endp

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; DS:SI field := DS:offset
setptr	macro	fld,ofs
	mov	word ptr fld,offset ofs
	mov	word ptr fld+2,ds
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
	setptr	cfg+02h,handlers
	setptr	cfg+06h,regions
	setptr	cfg+0Ah,sizes
	setptr	cfg+14h,shsize
	mov	word ptr cfg+0Eh,offset cb
	mov	word ptr cfg+10h,cs
	mov	ax,offset xseg+15	; X = first paragraph within xseg
	shr	ax,4
	mov	bx,ds
	add	ax,bx
	mov	lvl,ax

	TITLE_	'14h protection levels (level 0, as DESQview uses them)'
	mov	di,offset cfg
	mov	bl,3			; all 4 sizes
	mov	ax,1400h
	call	qcall
	CHECK	'1400 CF=0', nc
	cmp	ax,4705h
	CHECK	'1400 AX=4705h', e
	cmp	sizes,0000h
	CHECK	'size level 0 = 0', e
	cmp	sizes+2,0048h
	CHECK	'size level 1 = 48h', e
	cmp	sizes+4,0049h
	CHECK	'size level 2 = 49h', e
	cmp	sizes+6,005Bh
	CHECK	'size level 3 = 5Bh', e
	mov	di,offset lvl
	xor	bl,bl
	mov	ax,1402h
	call	qcall
	CHECK	'1402 level 0 CF=0', nc
	push	es
	mov	ax,lvl
	mov	es,ax
	cmp	word ptr es:[136h],0
	pop	es
	CHECK	'level 0 is a NOP (X untouched)', e
	mov	ax,1406h
	call	qcall
	CHECK	'1406 CF=0', nc
	mov	ax,1401h
	call	qcall
	CHECK	'1401 CF=0', nc
	call	finish

	end	start

; QPITRAP.ASM - I/O port trapping through the QEMM programming interface
; as QEMM 97 does it (1A06h-1A0Ah):  a callback is installed and a free
; port above 3FFh (as a PCI card's I/O BAR) is trapped; IN and OUT reach
; the callback once each with DX = port, CX bit 2 = OUT, and the value the
; callback returns for IN arrives in AL although it returns with CF=1
; (QEMM ignores the callback's CF; RBIL's "CF=1 = not handled" would make
; the memory manager access the port a second time).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPITRAP.ASM

	.model	small
	.386
	.stack	1024

PORT	equ	06E0h		; unused port above 3FFh

	.data
qpi	dd	0
oldcb	dd	?
	.code
	include	TESTLIB.INC

; the callback (V86, far):  counts calls, remembers CX/DX, returns 5Ah for IN
calls	dw	0
lastcx	dw	?
lastdx	dw	?
lastal	db	?
cb	proc	far
	inc	cs:calls
	mov	cs:lastcx,cx
	mov	cs:lastdx,dx
	mov	cs:lastal,al
	test	cl,4		; OUT?
	jnz	@F
	mov	al,5Ah		; IN:  the value
@@:	stc			; ignored by QEMM
	ret
cb	endp

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	; QPI entry (INT 67h AH=3Fh)
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
	TITLE_	'callback, trap a port above 3FFh'
	mov	ax,1A06h	; get the current callback
	call	qcall
	mov	word ptr oldcb,di
	mov	word ptr oldcb+2,es
	push	ds
	pop	es
	CHECK	'1A06 get callback', nc
	push	es
	push	cs
	pop	es
	mov	di,offset cb
	mov	ax,1A07h	; set ours
	call	qcall
	pop	es
	CHECK	'1A07 set callback', nc
	mov	dx,PORT
	mov	ax,1A09h	; trap the port
	call	qcall
	CHECK	'1A09 trap port 6E0h', nc
	mov	dx,PORT
	mov	ax,1A08h	; status
	call	qcall
	cmp	bl,0
	CHECK	'1A08 port is trapped', ne

	TITLE_	'IN and OUT through the callback'
	mov	cs:calls,0
	mov	dx,PORT
	in	al,dx
	cmp	al,5Ah
	CHECK	'IN delivers the callback''s value (callback CF=1)', e
	cmp	cs:calls,1
	CHECK	'callback called once', e
	cmp	cs:lastdx,PORT
	CHECK	'DX = port', e
	test	byte ptr cs:lastcx,4
	CHECK	'CX bit 2 clear for IN', z
	mov	dx,PORT
	mov	al,0A5h
	out	dx,al
	cmp	cs:calls,2
	CHECK	'OUT: callback called once more', e
	test	byte ptr cs:lastcx,4
	CHECK	'CX bit 2 set for OUT', nz
	cmp	cs:lastal,0A5h
	CHECK	'AL = value written', e

	TITLE_	'restore'
	mov	dx,PORT
	mov	ax,1A0Ah	; untrap
	call	qcall
	CHECK	'1A0A untrap', nc
	mov	cs:calls,0
	mov	dx,PORT
	in	al,dx
	cmp	cs:calls,0
	CHECK	'no callback after untrap', e
	les	di,oldcb
	mov	ax,1A07h
	call	qcall
	push	ds
	pop	es
	CHECK	'old callback back', nc
	call	finish

	end	start

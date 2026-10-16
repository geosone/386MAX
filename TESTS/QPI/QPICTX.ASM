; QPICTX.ASM - QEMM Programming Interface:  mapping contexts (DESQview's
; per-task address spaces) and page mapping, as QEMM 97 does them:
;   04h/05h allocate/free a 4KB page, 06h clone the page table into it,
;   07h/08h get/set the active page table, 0Ah set a PTE,
;   0Fh restore the default mapping (AL = dirty), 0Bh map an EMS handle.
; A 4KB page L of our own DOS memory is remapped in a second context only;
; switching back and forth must show the right contents.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPICTX.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
ctx0	dw	?			; default page table
ctxp	dw	?			; our clone
pageq	dw	?			; a page mapped at L in the clone
lpage	dw	?			; linear page # of L
lseg	dw	?			; its segment
frame	dw	?			; EMS page frame
hndl	dw	?
	.code
	include	TESTLIB.INC

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; the first word of L into AX
peekl	proc
	push	es
	mov	es,lseg
	mov	ax,es:[0]
	pop	es
	ret
peekl	endp

; AX into the first word of L
pokel	proc
	push	es
	mov	es,lseg
	mov	es:[0],ax
	pop	es
	ret
pokel	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,1024/16+1
	mov	ah,4Ah
	int	21h
	push	ds
	pop	es
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
	; 20 KB of DOS memory:  L = its first 16 KB aligned to 4 KB
	mov	ah,48h
	mov	bx,20*1024/16
	int	21h
	jnc	@F
	INFO	'no DOS memory'
	mov	ax,4C01h
	int	21h
@@:	add	ax,0FFh
	and	ax,0FF00h
	mov	lseg,ax
	shr	ax,8
	mov	lpage,ax
	mov	ax,1111h
	call	pokel

	TITLE_	'mapping contexts (04h, 06h, 07h, 08h)'
	mov	ax,0700h
	call	qcall
	CHECK	'07 get context', nc
	mov	ctx0,dx
	or	dx,dx
	CHECK	'07 page table frame not 0', nz
	mov	ax,0400h
	call	qcall
	CHECK	'04 allocate a page', nc
	mov	ctxp,dx
	mov	ax,0400h
	call	qcall
	CHECK	'04 allocate a second page', nc
	mov	pageq,dx
	mov	dx,ctxp
	mov	ax,0600h
	call	qcall
	CHECK	'06 clone into it', nc
	mov	dx,ctxp
	mov	ax,0800h
	call	qcall
	CHECK	'08 switch to the clone', nc
	mov	ax,0700h
	call	qcall
	cmp	dx,ctxp
	CHECK	'07 returns the clone', e
	call	peekl
	cmp	ax,1111h
	CHECK	'L same in the clone', e

	TITLE_	'a page remapped in one context only (0Ah)'
	mov	cx,lpage
	mov	dx,pageq
	mov	ax,0A00h
	call	qcall
	CHECK	'0A map page Q at L (clone)', nc
	mov	ax,2222h
	call	pokel
	mov	dx,ctx0
	mov	ax,0800h
	call	qcall
	CHECK	'08 back to the default context', nc
	call	peekl
	cmp	ax,1111h
	CHECK	'L unchanged in the default context', e
	mov	dx,ctxp
	mov	ax,0800h
	call	qcall
	call	peekl
	cmp	ax,2222h
	CHECK	'L = page Q in the clone again', e

	TITLE_	'0Fh restore the default mapping'
	mov	cx,lpage
	mov	dx,1
	mov	ax,0F00h
	call	qcall
	CHECK	'0F CF=0', nc
	cmp	al,1
	CHECK	'0F AL=1 (Q was written to)', e
	call	peekl
	cmp	ax,1111h
	CHECK	'L back to our memory', e
	mov	cx,lpage
	mov	dx,1
	mov	ax,0F00h
	call	qcall
	NOTE_	'  0F again: AL='	; QEMM 97:  1 (its reference PTE is dirty)
	call	phex8
	call	pcrlf
	mov	dx,ctx0
	mov	ax,0800h
	call	qcall
	mov	ax,0700h
	call	qcall
	cmp	dx,ctx0
	CHECK	'back in the default context', e
	mov	dx,ctxp
	mov	ax,0500h
	call	qcall
	CHECK	'05 free the clone', nc
	mov	dx,pageq
	mov	ax,0500h
	call	qcall
	CHECK	'05 free page Q', nc

	TITLE_	'0Bh map an EMS handle'
	mov	ah,41h
	int	67h
	cmp	ah,0
	je	@F
	INFO	'no EMS page frame:  skipped'
	jmp	ctxdone
@@:	mov	frame,bx
	mov	ah,43h
	mov	bx,1
	int	67h
	cmp	ah,0
	je	@F
	INFO	'no EMS page:  skipped'
	jmp	ctxdone
@@:	mov	hndl,dx
	mov	ax,4400h			; logical page 0 -> frame page 0
	xor	bx,bx
	int	67h
	push	es
	mov	es,frame
	mov	word ptr es:[0],3333h
	mov	word ptr es:[1000h],4444h
	pop	es
	mov	dx,hndl
	mov	cx,lpage
	mov	bx,1
	mov	ax,0B00h
	call	qcall
	CHECK	'0B map the handle at L', nc
	cmp	ah,0
	CHECK	'0B AH=0', e
	call	peekl
	cmp	ax,3333h
	CHECK	'L shows EMS page 0', e
	push	es
	mov	es,lseg
	mov	ax,es:[1000h]
	pop	es
	cmp	ax,4444h
	CHECK	'L+4K shows its second 4KB', e
	mov	cx,lpage
	mov	dx,4
	mov	ax,0F00h
	call	qcall
	call	peekl
	cmp	ax,1111h
	CHECK	'0F: L back to our memory', e
	mov	dx,hndl
	mov	ah,45h
	int	67h
ctxdone:
	call	finish

	end	start

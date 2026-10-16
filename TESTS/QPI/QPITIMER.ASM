; QPITIMER.ASM - QEMM Programming Interface 15h:  timer channel 0
; virtualization as QEMM 97 does it (DESQview emulates a program's tick
; rate with it):  while a WORD is registered, the channel 0 divisor a
; program writes (43h mode, then 40h LSB/MSB) is recorded in the WORD,
; and the OUTs still reach the PIT.  Latch commands are not recorded;
; after 15h with 0:0 nothing is.  The PIT is set back to the BIOS rate
; (divisor 0 = 65536, mode 3) at the end.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPITIMER.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
divw	dw	0			; the registered WORD
	.code
	include	TESTLIB.INC

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; PIT channel 0 mode 3, LSB/MSB, divisor BX
setpit	proc
	mov	al,36h
	out	43h,al
	mov	al,bl
	out	40h,al
	mov	al,bh
	out	40h,al
	ret
setpit	endp

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
	TITLE_	'15h on:  the divisor is recorded'
	mov	bx,offset divw
	mov	ax,1500h
	call	qcall
	CHECK	'15 register the WORD', nc
	cli
	mov	bx,1234h
	call	setpit
	mov	al,00h			; latch channel 0
	out	43h,al
	in	al,40h
	mov	ah,al
	in	al,40h
	xchg	al,ah
	mov	si,ax			; current count
	sti
	cmp	divw,1234h
	CHECK	'WORD = 1234h (LSB, MSB)', e
	cmp	si,1234h
	CHECK	'the PIT got it too (count < 1234h)', b
	mov	divw,0FFFFh
	cli
	mov	al,00h			; latch command:  not recorded
	out	43h,al
	in	al,40h
	in	al,40h
	sti
	cmp	divw,0FFFFh
	CHECK	'latch command not recorded', e
	cli
	mov	al,26h			; channel 0, MSB only, mode 3
	out	43h,al
	xor	al,al
	out	40h,al
	sti
	cmp	divw,00FFh
	CHECK	'MSB only:  only the high byte', e
	cli
	xor	bx,bx
	call	setpit
	sti
	cmp	divw,0
	CHECK	'WORD = 0 (the BIOS rate again)', e

	TITLE_	'15h off'
	xor	bx,bx
	mov	es,bx
	mov	ax,1500h
	call	qcall
	push	ds
	pop	es
	CHECK	'15 0:0 off', nc
	mov	divw,5555h
	cli
	xor	bx,bx
	call	setpit
	sti
	cmp	divw,5555h
	CHECK	'nothing recorded after 15h 0:0', e

	call	finish

	end	start

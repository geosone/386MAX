; QPIIRQ.ASM - QEMM Programming Interface:  IRQ calldowns (1Ch) as QEMM 97
; has them:  1C01h/1C03h make the hardware interrupts of the master/slave
; PIC go to 8 V86 handlers instead of the IVT, 1C00h/1C02h turn that off,
; 1C04h simulates a hardware interrupt.  Software INTs of those vectors
; still go to the IVT.  Our IRQ0 handler counts and chains to the BIOS
; (which sends the EOI); the other slots get the IVT handlers.
; QEMM 97 crashes on a software INT 08h while calldowns are on (its gate
; is then DPL0); 386MAX sends it to the IVT.  That check is skipped when
; the driver (QPI 1E04h) is QEMM's.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPIIRQ.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
tab1	dd	8 dup (?)		; IRQ0-7 handlers
tab2	dd	8 dup (?)		; IRQ8-15 handlers
old60	dd	?
name4	db	16 dup (0)
	.code
	include	TESTLIB.INC

cnt0	dw	0
cnt60	dw	0
cnt70	dw	0
old08	dd	?
old70	dd	?

h0	proc	far			; IRQ0 calldown
	inc	cs:cnt0
	jmp	cs:old08
h0	endp

h60	proc	far			; INT 60h (1C04h with calldowns off)
	inc	cs:cnt60
	iret
h60	endp

h70	proc	far			; IRQ8 calldown
	inc	cs:cnt70
	jmp	cs:old70
h70	endp

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; wait about 4 timer ticks (BIOS tick count), with interrupts on
wait4	proc
	push	es
	push	40h
	pop	es
	sti
	mov	ax,es:[6Ch]
	mov	ecx,40000000h		; give up some day
@@:	mov	dx,es:[6Ch]
	sub	dx,ax
	cmp	dx,4
	jae	@F
	dec	ecx
	jnz	@B
@@:	pop	es
	ret
wait4	endp

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
	; the IVT handlers of IRQ0-15 into the tables, ours for IRQ0/IRQ8
	push	ds
	xor	ax,ax
	mov	ds,ax
	mov	si,08h*4
	mov	di,offset tab1
	mov	cx,8*2
	rep	movsw
	mov	si,70h*4
	mov	cx,8*2
	rep	movsw
	pop	ds
	mov	eax,tab1
	mov	cs:old08,eax
	mov	eax,tab2
	mov	cs:old70,eax
	mov	word ptr tab1,offset h0
	mov	word ptr tab1+2,cs
	mov	word ptr tab2,offset h70
	mov	word ptr tab2+2,cs

	TITLE_	'1C04h with calldowns off'
	mov	ax,3560h
	int	21h
	mov	word ptr old60,bx
	mov	word ptr old60+2,es
	push	ds
	push	cs
	pop	ds
	mov	dx,offset h60
	mov	ax,2560h
	int	21h
	pop	ds
	push	ds
	pop	es
	mov	bx,60h
	mov	ax,1C04h
	call	qcall
	CHECK	'1C04 INT 60h CF=0', nc
	cmp	cs:cnt60,1
	CHECK	'the IVT handler ran once', e
	push	ds
	lds	dx,old60
	mov	ax,2560h
	int	21h
	pop	ds

	TITLE_	'IRQ0-7 calldowns (1C01h)'
	mov	di,offset tab1
	mov	ax,1C01h
	call	qcall
	CHECK	'1C01 set and enable', nc
	call	wait4
	cmp	dx,4
	CHECK	'the BIOS clock still runs (chained)', ae
	cmp	cs:cnt0,3
	CHECK	'the IRQ0 calldown counted the ticks', ae
	mov	di,offset name4
	mov	ax,1E04h
	call	qcall
	cmp	dword ptr name4,'MMEQ'	; "QEMM..."?
	jne	@F
	INFO	'(QEMM:  no software INT 08h, it crashes)'
	jmp	short noswint
@@:	mov	bx,cs:cnt0
	int	08h			; software INT:  IVT, not the calldown
	cmp	bx,cs:cnt0
	CHECK	'software INT 08h goes to the IVT', e
noswint:
	mov	bx,cs:cnt0
	cli
	push	bx
	mov	bx,08h
	mov	ax,1C04h
	call	qcall
	pop	bx
	sti
	CHECK	'1C04 IRQ0 CF=0', nc
	inc	bx
	cmp	cs:cnt0,bx
	CHECK	'1C04 IRQ0 went to the calldown', ae
	mov	ax,1C00h
	call	qcall
	CHECK	'1C00 disable', nc
	mov	bx,cs:cnt0
	push	bx
	call	wait4
	pop	bx
	cmp	dx,4
	CHECK	'the BIOS clock runs after 1C00', ae
	cmp	cs:cnt0,bx
	CHECK	'no calldown after 1C00', e

	TITLE_	'IRQ8-15 calldowns (1C03h)'
	mov	di,offset tab2
	mov	ax,1C03h
	call	qcall
	CHECK	'1C03 set and enable', nc
	cli
	mov	bx,70h
	mov	ax,1C04h
	call	qcall
	sti
	CHECK	'1C04 IRQ8 CF=0', nc
	cmp	cs:cnt70,1
	CHECK	'1C04 IRQ8 went to the calldown', ae
	mov	ax,1C02h
	call	qcall
	CHECK	'1C02 disable', nc

	call	finish

	end	start

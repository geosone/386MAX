; HDPAPI.ASM - the HDPMI vendor API ("HDPMI" through INT 2Fh AX=168Ah)
; as a 32-bit client sees it:  function 5 (HDPMI=32 flag) and function 8
; (simulate I/O:  IN/OUT with the port in DX or BH, INS/OUTS with REP).
; Open 386MAX answers the name by default; its own vendor API "386MAX"
; AX=0200h BL=0 hides it, BL=1 answers it again.  HDPMI answers it always.
; The 32-bit client stays in a 16-bit code segment.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no 32-bit DPMI host.
; Build: jwasm -mz HDPAPI.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
maxapi	df	0			; '386MAX' vendor API (0 = none)
hdpapi	df	0			; 'HDPMI' vendor API
nmax	db	'386MAX',0
nhdp	db	'HDPMI',0
imr	db	?
sep	db	?
inbuf	db	4 dup (0EEh)
outbuf	db	0,0,0
mnodpmi	db	'no 32-bit DPMI host',13,10,'$'
	.code
	include	TESTLIB.INC

; 168Ah for the name at DS:SI, CF=0 and ES:EDI = entry if found
vendor	proc
	movzx	esi,si
	mov	ax,168Ah
	int	2Fh
	cmp	al,0
	je	@F
	stc
	ret
@@:	clc
	ret
vendor	endp

hdp	proc			; call the HDPMI API
	call	[hdpapi]
	ret
hdp	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,2048/16+1
	mov	ah,4Ah
	int	21h
	mov	ax,1687h
	int	2Fh
	or	ax,ax
	jnz	nodpmi
	test	bx,1			; 32-bit clients supported?
	jz	nodpmi
	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	nodpmi
	mov	es,ax
@@:	mov	ax,1			; 32-bit client
	call	entry
	jnc	pm
nodpmi:	mov	dx,offset mnodpmi
	mov	ah,9
	int	21h
	mov	ax,4C02h
	int	21h

pm:	movzx	esp,sp
	push	ds
	pop	es

	TITLE_	'168Ah "HDPMI"'
	mov	si,offset nmax		; Open 386MAX:  answer "HDPMI"
	call	vendor
	jc	@F
	mov	dword ptr maxapi,edi
	mov	word ptr maxapi+4,es
	push	ds
	pop	es
	mov	si,offset nhdp		; answered by default
	call	vendor
	CHECK	'386MAX:  answered by default', nc
	push	ds
	pop	es
	mov	ax,0200h
	mov	bl,1
	call	[maxapi]
	pushf
	cmp	al,1
	CHECK	'386MAX AX=0200h BL=1:  AL=1 (was on)', e
	popf
	CHECK	'... CF=0', nc
@@:	push	ds
	pop	es
	mov	si,offset nhdp
	call	vendor
	jnc	@F
	push	ds
	pop	es
	INFO	'no HDPMI API:  skipped'
	jmp	done
@@:	mov	dword ptr hdpapi,edi
	mov	word ptr hdpapi+4,es
	push	ds
	pop	es
	clc
	CHECK	'found, ES:EDI = entry', nc

	TITLE_	'5:  HDPMI=32 flag'
	mov	ax,5
	mov	bl,1
	call	hdp
	mov	sep,al			; the host's value
	CHECK	'BL=1 CF=0', nc
	mov	ax,5
	mov	bl,0
	call	hdp
	cmp	al,1
	CHECK	'BL=0:  AL=1 (old value)', e
	mov	ax,5
	mov	bl,sep			; back to the host's value
	call	hdp
	cmp	al,0
	CHECK	'back:  AL=0', e

	cmp	dword ptr maxapi,0	; HDPMI's IOPL 3 variants have no 6-10
	jne	@F
	mov	ax,8
	xor	bx,bx
	mov	dx,21h
	call	hdp
	jnc	@F
	INFO	'functions 6-10 missing (IOPL 3 host):  skipped'
	jmp	done
@@:
	TITLE_	'8:  simulate I/O'
	cli
	in	al,21h
	mov	imr,al
	sti
	mov	ax,8			; IN AL,DX
	xor	bx,bx
	mov	dx,21h
	mov	ecx,12345678h
	call	hdp
	pushf
	cmp	al,imr
	CHECK	'IN 21h:  AL = IMR', e
	popf
	CHECK	'... CF=0', nc
	shr	eax,8
	cmp	eax,123456h
	CHECK	'... rest of EAX = ECX', e
	mov	ax,8			; IN AL,21h (port in BH)
	mov	bx,2140h
	mov	dx,0FFFFh
	xor	ecx,ecx
	call	hdp
	cmp	al,imr
	CHECK	'IN 21h, port in BH:  AL = IMR', e
	mov	ax,8			; OUT DX,AL (the same value)
	mov	bx,1
	mov	dx,21h
	movzx	ecx,imr
	call	hdp
	CHECK	'OUT 21h CF=0', nc
	cli
	in	al,21h
	sti
	cmp	al,imr
	CHECK	'... IMR unchanged', e
	mov	ax,8			; REP INSB, 2 bytes
	mov	bx,0088h
	mov	dx,21h
	mov	edi,offset inbuf
	mov	ecx,2
	call	hdp
	pushf
	cmp	edi,offset inbuf+2
	CHECK	'REP INSB:  EDI + 2', e
	popf
	jecxz	@F
	stc
@@:	CHECK	'... ECX = 0', nc
	mov	al,imr
	cmp	al,inbuf
	jne	@F
	cmp	al,inbuf+1
	jne	@F
	cmp	inbuf+2,0EEh
@@:	CHECK	'... both bytes = IMR, no more', e
	mov	ax,8			; REP OUTSB, 3 bytes to the POST port
	mov	bx,0089h
	mov	dx,80h
	mov	esi,offset outbuf
	mov	ecx,3
	call	hdp
	cmp	esi,offset outbuf+3
	CHECK	'REP OUTSB to 80h:  ESI + 3', e
	mov	ax,8			; INSB without REP:  one byte
	mov	bx,0008h
	mov	dx,21h
	mov	edi,offset inbuf+2
	mov	ecx,5
	call	hdp
	pushf
	cmp	edi,offset inbuf+3
	CHECK	'INSB without REP:  one byte', e
	popf
	cmp	ecx,5
	CHECK	'... ECX unchanged', e

	TITLE_	'not supported'
	mov	ax,10
	call	hdp
	CHECK	'10 (simulate HW interrupt) CF=1', c

	mov	eax,dword ptr maxapi
	or	eax,eax
	jz	done
	TITLE_	'386MAX AX=0200h BL=0'
	mov	ax,0200h
	mov	bl,0
	call	[maxapi]
	cmp	al,1
	CHECK	'AL=1 (was on)', e
	mov	si,offset nhdp
	call	vendor
	push	ds
	pop	es
	CHECK	'"HDPMI" no longer answered', c
	mov	ax,0200h		; on again
	mov	bl,1
	call	[maxapi]
done:	call	finish

	end	start

; HDPTRAP.ASM - port and CLI traps of the HDPMI vendor API (functions 6,
; 7 and 9) for a 32-bit client:  ports 300h-30Fh and 0EAh-0EBh trapped,
; then IN/OUT with the port in DX and immediate, byte/word/dword, REP
; OUTSB with a segment prefix:  the handler sees HDPMI's error code and
; port, returns IN values and advances EIP.  Ports outside the ranges
; go to the hardware.  A CLI handler is called with an IRET frame.
; Open 386MAX answers "HDPMI" after "386MAX" AX=0200h BL=1.
; The 32-bit client stays in a 16-bit code segment.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no 32-bit DPMI host.
; Build: jwasm -mz HDPTRAP.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
maxapi	df	0			; '386MAX' vendor API (0 = none)
hdpapi	df	0			; 'HDPMI' vendor API
nmax	db	'386MAX',0
nhdp	db	'HDPMI',0
procs	dd	offset inproc		; TRAPPROCS:  IN  handler
	dw	?
	dd	offset outproc		; OUT handler
	dw	?
procs2	dd	offset inproc		; TRAPPROCS of the 3rd range
	dw	?
	dd	offset outproc2		; another OUT handler
	dw	?
h1	dd	0			; handles
h2	dd	0
h3	dd	0
imr	db	?
src	db	11h,22h,33h
cnt	dw	?
mnodpmi	db	'no 32-bit DPMI host',13,10,'$'
	.code
	include	TESTLIB.INC

; what the handlers saw (in the code segment, written through dsel)
dsel	dw	?			; data alias of CS
nin	dw	0			; # IN handler calls
nout	dw	0			; # OUT handler calls
lerr	dd	0			; last error code
lport	dw	0			; last port (DX at the fault)
lval	dd	0			; last EAX at the fault
lcx	dd	0			; ECX at the fault
ncli	dw	0			; # CLI handler calls
nout2	dw	0			; # calls of the 3rd range's OUT handler
clicnt	dd	0			; EFL in the IRET frame of the CLI handler

; IN handler:  DPMI exception frame (32-bit), returns 0A5A5A5A5h
inproc	proc	far
	push	ds
	mov	ds,cs:dsel
	inc	nin
	call	recfault
	pop	ds
	mov	eax,0A5A5A5A5h
	jmp	short advance
inproc	endp

; OUT handler:  for REP OUTS, ECX = 0 afterwards
outproc	proc	far
	push	ds
	mov	ds,cs:dsel
	inc	nout
	call	recfault
	pop	ds
	test	byte ptr [esp+8],80h	; REP?
	jz	advance
	xor	ecx,ecx
advance::
	push	eax
	mov	eax,[esp+4+8]		; error code
	and	eax,7			; instruction length
	add	[esp+4+12],eax		; EIP past the instruction
	pop	eax
	db	66h
	retf
outproc	endp

; OUT handler of the 3rd range
outproc2 proc	far
	push	ds
	mov	ds,cs:dsel
	inc	nout2
	pop	ds
	jmp	advance
outproc2 endp

; DS = alias; error code at [esp+2+2+8] (call, push ds)
recfault	proc	near
	push	eax
	mov	eax,[esp+2+4+2+8]
	mov	lerr,eax
	pop	eax
	mov	lport,dx
	mov	lval,eax
	mov	lcx,ecx
	ret
recfault	endp

; CLI handler:  IRETD frame on the stack, IF already 0
clih	proc	far
	push	ds
	mov	ds,cs:dsel
	inc	ncli
	push	eax
	mov	eax,[esp+4+2+8]		; EFL in the frame
	mov	clicnt,eax
	pop	eax
	pop	ds
	iretd
clih	endp

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

ds2es	proc
	push	ds
	pop	es
	ret
ds2es	endp

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
	mov	ax,000Ah		; data alias of CS
	mov	bx,cs
	int	31h
	mov	es,ax
	mov	es:dsel,ax
	call	ds2es
	mov	word ptr procs+4,cs
	mov	word ptr procs+10,cs
	mov	word ptr procs2+4,cs
	mov	word ptr procs2+10,cs

	mov	si,offset nmax		; Open 386MAX:  answer "HDPMI"
	call	vendor
	jc	@F
	mov	dword ptr maxapi,edi
	mov	word ptr maxapi+4,es
	mov	ax,0200h
	mov	bl,1
	call	[maxapi]
@@:	call	ds2es
	mov	si,offset nhdp
	call	vendor
	jnc	@F
	call	ds2es
	INFO	'no HDPMI API:  skipped'
	jmp	done
@@:	mov	dword ptr hdpapi,edi
	mov	word ptr hdpapi+4,es
	call	ds2es

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
	TITLE_	'6:  trap ranges'
	mov	ax,6
	mov	dx,300h
	mov	cx,10h
	mov	esi,offset procs
	call	hdp
	mov	h1,eax
	pushf
	CHECK	'300h-30Fh CF=0', nc
	popf
	jc	done
	or	eax,eax
	CHECK	'... handle <> 0', nz
	mov	ax,6
	mov	dx,0EAh
	mov	cx,2
	mov	esi,offset procs
	call	hdp
	mov	h2,eax
	CHECK	'0EAh-0EBh CF=0', nc
	mov	ax,6
	mov	dx,30Fh
	mov	cx,2
	mov	esi,offset procs
	call	hdp
	CHECK	'30Fh-310h (overlap) CF=1', c
	mov	ax,6			; above an existing one, own handlers
	mov	dx,310h
	mov	cx,2
	mov	esi,offset procs2
	call	hdp
	mov	h3,eax
	CHECK	'310h-311h (other handlers) CF=0', nc
	mov	ax,6
	mov	dx,320h
	xor	cx,cx
	call	hdp
	CHECK	'count 0 CF=1', c

	TITLE_	'IN/OUT to trapped ports'
	mov	dx,300h			; OUT DX,AL
	mov	al,5Ah
	out	dx,al
	cmp	nout,1
	CHECK	'OUT DX,AL:  OUT handler called', e
	cmp	lerr,0001h
	CHECK	'... error code 0001h (1 byte, byte size)', e
	cmp	lport,300h
	CHECK	'... DX = 300h', e
	cmp	byte ptr lval,5Ah
	CHECK	'... AL = 5Ah', e
	mov	dx,302h			; IN AL,DX
	mov	eax,12345678h
	in	al,dx
	cmp	nin,1
	CHECK	'IN AL,DX:  IN handler called', e
	cmp	eax,0A5A5A5A5h
	CHECK	'... EAX from the handler', e
	in	al,0EAh			; IN AL,0EAh
	cmp	lerr,0EA42h
	CHECK	'IN AL,0EAh:  error code EA42h (port, 2 bytes)', e
	mov	ax,1234h		; OUT 0EBh,AX (16-bit code:  word)
	out	0EBh,ax
	cmp	lerr,0EB52h
	CHECK	'OUT 0EBh,AX:  error code EB52h (word)', e
	cmp	word ptr lval,1234h
	CHECK	'... AX = 1234h', e
	mov	dx,304h			; IN EAX,DX (operand size prefix)
	in	eax,dx
	cmp	lerr,0032h
	CHECK	'IN EAX,DX:  error code 0032h (dword, 2 bytes)', e
	mov	dx,306h			; REP OUTS DX,BYTE PTR ES:[SI]
	mov	si,offset src
	mov	ecx,3
	rep	outs dx,byte ptr es:[si]
	cmp	lerr,26CBh
	CHECK	'ES: REP OUTSB:  error code 26CBh', e
	cmp	lcx,3
	CHECK	'... ECX = 3 at the fault', e
	jecxz	@F
	stc
@@:	CHECK	'... ECX = 0 afterwards (handler)', nc

	mov	dx,311h			; the 3rd range's own OUT handler
	out	dx,al
	cmp	nout2,1
	CHECK	'OUT 311h:  the 3rd range''s handler', e

	TITLE_	'ports outside the ranges'
	mov	ax,8			; the real IMR
	xor	bx,bx
	mov	dx,21h
	call	hdp
	mov	imr,al
	mov	cx,nin
	add	cx,nout
	mov	cnt,cx
	in	al,21h
	cmp	al,imr
	CHECK	'IN AL,21h = IMR', e
	mov	dx,21h
	in	al,dx
	cmp	al,imr
	CHECK	'IN AL,DX (21h) = IMR', e
	out	dx,al
	mov	cx,nin
	add	cx,nout
	cmp	cx,cnt
	CHECK	'... no handler called', e

	TITLE_	'9:  CLI handler'
	mov	ax,9
	mov	bl,0
	mov	cx,cs
	mov	edx,offset clih
	call	hdp
	CHECK	'BL=0 CX:EDX CF=0', nc
	cli
	pushfd
	sti
	pop	eax
	cmp	ncli,1
	CHECK	'CLI:  handler called', e
	test	clicnt,200h
	CHECK	'... IF=0 in its IRET frame', z
	test	eax,200h
	CHECK	'... IF=0 after CLI', z
	pushfd
	pop	eax
	test	eax,200h
	CHECK	'STI:  IF=1', nz
	mov	ax,9
	mov	bl,0
	xor	cx,cx
	xor	edx,edx
	call	hdp
	cli
	sti
	cmp	ncli,1
	CHECK	'0:0 removes it', e

	TITLE_	'7:  remove the ranges'
	mov	ax,7
	mov	edx,h1
	call	hdp
	CHECK	'300h-30Fh CF=0', nc
	mov	ax,7
	mov	edx,h1
	call	hdp
	CHECK	'again CF=1', c
	mov	ax,7
	mov	edx,h2
	call	hdp
	CHECK	'0EAh-0EBh CF=0', nc
	mov	ax,7
	mov	edx,h3
	call	hdp
	CHECK	'310h-311h CF=0', nc
	mov	cx,nin
	add	cx,nout
	mov	cnt,cx
	mov	dx,300h
	in	al,dx
	mov	cx,nin
	add	cx,nout
	cmp	cx,cnt
	CHECK	'IN 300h:  no handler called', e

	mov	eax,dword ptr maxapi
	or	eax,eax
	jz	done
	mov	ax,0200h
	mov	bl,0
	call	[maxapi]
done:	call	finish

	end	start

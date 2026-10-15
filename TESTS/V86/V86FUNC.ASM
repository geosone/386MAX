; V86FUNC.ASM - behaviour of the V86 monitor towards real-mode programs:
; divide error and INT 3/single step reflected to the program's vectors,
; HLT with interrupts on, CLI/STI/PUSHF, software interrupts above 80h,
; a program hooking INT 67h, INT 15h AH=87h block move and AH=88h.
; Errorlevel 0 = all OK, 1 = a check failed.
; Build: jwasm -mz V86FUNC.ASM

	.model	small
	.386
	.stack	1024

	.data
hits	dw	0
hits67	dw	0
emmst	db	?
old0	dd	?
old1	dd	?
old3	dd	?
old67	dd	?
old88	dd	?
; INT 15h AH=87h descriptor table (6 descriptors)
gdt87	db	16 dup (0)
srcd	dw	0FFFFh, ?
	db	?, 93h, 0, 0
dstd	dw	0FFFFh, ?
	db	?, 93h, 0, 0
	db	16 dup (0)
	.data?
src	db	1000h dup (?)
dst	db	1000h dup (?)

	.code
	include	TESTLIB.INC

; set vector al to cs:dx, old one into [di]
hook	proc
	push	es
	push	bx
	push	ax
	mov	ah,35h
	int	21h
	mov	word ptr [di],bx
	mov	word ptr [di+2],es
	pop	ax
	push	ds
	push	cs
	pop	ds
	mov	ah,25h
	int	21h
	pop	ds
	pop	bx
	pop	es
	ret
hook	endp

; restore vector al from [di]
unhook	proc
	push	ds
	push	ax
	lds	dx,[di]
	pop	ax
	mov	ah,25h
	int	21h
	pop	ds
	ret
unhook	endp

; INT 0: count, skip the 2-byte DIV
int0h:	push	bp
	mov	bp,sp
	add	word ptr [bp+2],2
	push	ds
	push	ax
	mov	ax,@data
	mov	ds,ax
	inc	hits
	pop	ax
	pop	ds
	pop	bp
	iret

; INT 1 / INT 3: count, clear TF
int13h:	push	bp
	mov	bp,sp
	and	word ptr [bp+6],not 100h
	push	ds
	push	ax
	mov	ax,@data
	mov	ds,ax
	inc	hits
	pop	ax
	pop	ds
	pop	bp
	iret

; INT 88h: count, return AX+1
int88h:	push	ds
	push	ax
	mov	ax,@data
	mov	ds,ax
	inc	hits
	pop	ax
	pop	ds
	inc	ax
	iret

; INT 67h hook: count, chain
int67h:	push	ds
	push	ax
	mov	ax,@data
	mov	ds,ax
	inc	hits67
	pop	ax
	pop	ds
	jmp	cs:[oldsave]

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax

	TITLE_	'exceptions reflected to the program'
	mov	hits,0
	mov	al,0
	mov	di,offset old0
	mov	dx,offset int0h
	call	hook
	mov	ax,1234h
	xor	dx,dx
	xor	bl,bl
	div	bl		; 2 bytes: F6 F3
	mov	al,0
	mov	di,offset old0
	call	unhook
	cmp	hits,1
	CHECK	'divide error -> INT 0 of the program', e
	mov	hits,0
	mov	al,3
	mov	di,offset old3
	mov	dx,offset int13h
	call	hook
	int	3
	mov	al,3
	mov	di,offset old3
	call	unhook
	cmp	hits,1
	CHECK	'INT 3 -> the program''s handler', e
	mov	hits,0
	mov	al,1
	mov	di,offset old1
	mov	dx,offset int13h
	call	hook
	pushf
	pop	ax
	or	ah,1		; TF
	push	ax
	popf
	nop			; trap after this instruction
	nop
	mov	al,1
	mov	di,offset old1
	call	unhook
	cmp	hits,1
	CHECK	'single step -> INT 1 once', e

	TITLE_	'interrupt flag, HLT'
	cli
	pushf
	pop	ax
	sti
	test	ah,2
	CHECK	'PUSHF after CLI: IF clear', z
	pushf
	pop	ax
	test	ah,2
	CHECK	'PUSHF after STI: IF set', nz
	push	es
	push	40h
	pop	es
	sti
	hlt			; returns (QEMM: at once, without a tick)
	mov	eax,es:[6Ch]
	mov	ecx,10000000h	; the timer runs: wait for a tick
@@:	cmp	eax,es:[6Ch]
	jne	@F
	dec	ecx
	jnz	@B
@@:	pop	es
	or	ecx,ecx
	CHECK	'HLT with IF=1 returns, timer runs', nz

	TITLE_	'software interrupts'
	mov	hits,0
	mov	al,88h
	mov	di,offset old88
	mov	dx,offset int88h
	call	hook
	mov	ax,41h
	int	88h
	push	ax
	mov	al,88h
	mov	di,offset old88
	call	unhook
	pop	ax
	cmp	ax,42h
	jne	@F
	cmp	hits,1
@@:	CHECK	'INT 88h -> the program''s handler', e
	; a program hooking INT 67h: the EMM is still reached through it
	mov	ah,40h
	int	67h
	mov	emmst,ah	; 0: an EMM answers
	mov	al,67h
	mov	di,offset old67
	mov	dx,offset int67h
	call	hook
	mov	eax,old67
	mov	cs:oldsave,eax
	mov	ah,40h
	int	67h
	mov	bl,ah
	mov	al,67h
	mov	di,offset old67
	call	unhook
	cmp	hits67,1
	CHECK	'hooked INT 67h called', e
	cmp	emmst,0
	jne	@F		; no EMM: status irrelevant
	cmp	bl,0
	CHECK	'and chained to the EMM (status 0)', e
@@:

	TITLE_	'INT 15h'
	mov	ah,88h
	int	15h
	NOTE_	'AH=88h extended memory (KB) '
	call	phex16
	call	pcrlf
	mov	di,offset src
	mov	cx,1000h
	xor	al,al
@@:	mov	[di],al
	add	al,13
	inc	di
	loop	@B
	mov	ax,ds
	movzx	eax,ax
	shl	eax,4
	lea	edx,[eax+offset src]
	mov	srcd+2,dx
	shr	edx,16
	mov	byte ptr srcd+4,dl
	lea	edx,[eax+offset dst]
	mov	dstd+2,dx
	shr	edx,16
	mov	byte ptr dstd+4,dl
	mov	si,offset gdt87
	mov	cx,1000h/2
	mov	ah,87h
	int	15h
	pushf
	NOTE_	'AH=87h status '
	mov	al,ah
	call	phex8
	popf
	CHECK	' (move 4 KB in the first MB)', nc
	mov	si,offset src
	mov	di,offset dst
	mov	cx,1000h
	repe	cmpsb
	CHECK	'data equal', e
	call	finish

oldsave	dd	?		; in the code segment: the INT 67h hook chains through it

	end	start

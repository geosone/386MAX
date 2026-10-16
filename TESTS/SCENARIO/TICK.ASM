; TICK.ASM - load generator for multitasking scenarios (DESQview windows,
; BBS nodes): about once a second (18 timer ticks) appends a line with a
; running number to a file (opened, written and closed each time, so the
; data reaches the disk), with C also writes a byte to COM1 (3F8h) like a
; node sending data.  Runs until the machine is stopped (no keyboard
; check:  in a DESQview foreground window a pending key ended it at once).
;   TICK file [C]
; Build: jwasm -mz TICK.ASM

	.model	small
	.386
	.stack	512

	.data
fname	db	80 dup (0)
com	db	0
count	dw	0
line	db	'tick '
num	db	'00000',13,10
LINELEN	equ	$-line
usage	db	'TICK file [C]',13,10,'$'
lasttk	dw	?

	.code
start:
	mov	ax,@data
	mov	es,ax
	; command line -> file name, optional C
	mov	si,81h
	mov	di,offset fname
@@:	lodsb
	cmp	al,' '
	je	@B
	cmp	al,13
	je	noarg
	dec	si
cpy:	lodsb
	cmp	al,' '
	je	endnm
	cmp	al,13
	je	endnm2
	stosb
	jmp	cpy
endnm:	lodsb
	cmp	al,' '
	je	endnm
	and	al,0DFh
	cmp	al,'C'
	jne	endnm2
	mov	es:com,1
endnm2:	mov	ax,es
	mov	ds,ax
	; create the file empty
	mov	ah,3Ch
	xor	cx,cx
	mov	dx,offset fname
	int	21h
	jc	fail
	mov	bx,ax
	mov	ah,3Eh
	int	21h
	cmp	com,0
	je	loop1
	mov	dx,3FBh		; COM1 9600 8N1
	mov	al,83h
	out	dx,al
	mov	dx,3F8h
	mov	al,12
	out	dx,al
	inc	dx
	xor	al,al
	out	dx,al
	mov	dx,3FBh
	mov	al,03h
	out	dx,al

loop1:	; wait 18 ticks
	push	ds
	push	40h
	pop	ds
	mov	ax,ds:[6Ch]
	pop	ds
	mov	lasttk,ax
wait1:	push	ds
	push	40h
	pop	ds
	mov	ax,ds:[6Ch]
	pop	ds
	sub	ax,lasttk
	cmp	ax,18
	jb	wait1
	; number -> text
	inc	count
	mov	ax,count
	mov	di,offset num+4
	mov	cx,5
	mov	bx,10
@@:	xor	dx,dx
	div	bx
	add	dl,'0'
	mov	[di],dl
	dec	di
	loop	@B
	; append the line
	mov	ax,3D01h
	mov	dx,offset fname
	int	21h
	jc	fail
	mov	bx,ax
	mov	ax,4202h
	xor	cx,cx
	xor	dx,dx
	int	21h
	mov	ah,40h
	mov	cx,LINELEN
	mov	dx,offset line
	int	21h
	mov	ah,3Eh
	int	21h
	cmp	com,0
	je	loop1
	mov	dx,3F8h
	mov	al,'*'
	out	dx,al
	jmp	loop1

noarg:	push	es
	pop	ds
	mov	dx,offset usage
	mov	ah,9
	int	21h
fail:	mov	ax,4C01h
	int	21h

	end	start

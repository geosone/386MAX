; EXEC32.ASM - INT 21h AX=4B00h from a 32-bit DPMI client:  the parameter
; block at ES:EBX has 8-byte slots for the command line, FCB 1 and FCB 2
; (offset dword, selector word, filler), as on HDPMI, Windows 9x/XP and
; DPMIONE.  The client starts this program again; the child (real mode,
; argument Z) checks that DOS got the command tail and both FCBs (PSP:80h,
; 5Ch, 6Ch) and returns the result as its errorlevel.
; The 32-bit client stays in a 16-bit code segment.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no 32-bit DPMI host.
; Build: jwasm -mz EXEC32.ASM

	.model	small
	.386
	.stack	2048

	.data
entry	dd	?
path	db	80 dup (0)		; this program
tail	db	2,' Z',13		; command tail for the child
fcb1	db	0,'FCBONE  AAA',25 dup (0)
fcb2	db	0,'FCBTWO  BBB',25 dup (0)
pblock	dd	offset tail		; 8-byte slots
	dw	?,0
	dd	offset fcb1
	dw	?,0
	dd	offset fcb2
	dw	?,0
	dd	-1,-1			; (a 6-byte layout would read these)
mnodpmi	db	'no 32-bit DPMI host',13,10,'$'
	.code
	include	TESTLIB.INC

; the child:  errorlevel 0 if PSP:80h, 5Ch and 6Ch are as passed
child	proc
	mov	al,1
	cmp	word ptr es:[80h],' '*256+2 ; length 2, ' '
	jne	@F
	cmp	byte ptr es:[82h],'Z'
	jne	@F
	mov	al,2
	cmp	dword ptr es:[5Dh],'OBCF' ; 'FCBO'
	jne	@F
	cmp	word ptr es:[61h],'EN'	; 'NE'
	jne	@F
	mov	al,3
	cmp	dword ptr es:[6Dh],'TBCF' ; 'FCBT'
	jne	@F
	cmp	word ptr es:[71h],'OW'	; 'WO'
	jne	@F
	mov	al,0
@@:	mov	ah,4Ch
	int	21h
child	endp

start:
	mov	ax,@data
	mov	ds,ax
	cmp	byte ptr es:[80h],2	; started as the child?
	jne	@F
	cmp	byte ptr es:[82h],'Z'
	jne	@F
	jmp	child
@@:	push	es			; this program's path
	mov	es,es:[2Ch]
	xor	di,di
	xor	al,al
	mov	cx,-1
@@:	repne	scasb
	scasb
	jne	@B
	add	di,2
	mov	si,offset path
@@:	mov	al,es:[di]
	mov	[si],al
	inc	di
	inc	si
	or	al,al
	jnz	@B
	pop	es
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
	test	bx,1
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
	mov	word ptr pblock+4,ds	; the selectors
	mov	word ptr pblock+12,ds
	mov	word ptr pblock+20,ds
	push	ds
	pop	es

	TITLE_	'INT 21h 4B00h, 32-bit parameter block (8-byte slots)'
	mov	edx,offset path
	mov	ebx,offset pblock
	mov	ax,4B00h
	int	21h
	CHECK	'4B00h CF=0', nc
	mov	ah,4Dh
	int	21h
	push	ax
	cmp	al,1
	CHECK	'child:  command tail', ne
	pop	ax
	push	ax
	cmp	al,2
	CHECK	'child:  FCB 1 at PSP:5Ch', ne
	pop	ax
	push	ax
	cmp	al,3
	CHECK	'child:  FCB 2 at PSP:6Ch', ne
	pop	ax
	cmp	al,0
	CHECK	'child:  errorlevel 0', e
	call	finish

	end	start

; Microsoft C run time helpers called by the Windows libraries compiled
; with Microsoft C (TEXT/CTL3DS.LIB): long shifts, _fmemicmp, __acrtused.
; The near helpers are called from the library's _TEXT segment, so they
; must lie in _TEXT too.
	.286

; reference of every Microsoft C object to its run time start up code
	public	__acrtused
__acrtused equ	9876h

_TEXT	segment word public 'CODE'
	assume	cs:_TEXT

; __aNlshl: DX:AX <<= CL
	public	__aNlshl
__aNlshl proc near
	xor	ch,ch
	jcxz	nlshl_done
nlshl_loop:
	shl	ax,1
	rcl	dx,1
	loop	nlshl_loop
nlshl_done:
	ret
__aNlshl endp

; __aNulshr: DX:AX >>= CL (unsigned)
	public	__aNulshr
__aNulshr proc near
	xor	ch,ch
	jcxz	nulshr_done
nulshr_loop:
	shr	dx,1
	rcr	ax,1
	loop	nulshr_loop
nulshr_done:
	ret
__aNulshr endp

_TEXT	ends

OWMSC_TEXT segment word public 'CODE'
	assume	cs:OWMSC_TEXT

; __aFulshr: DX:AX >>= CL (unsigned), far
	public	__aFulshr
__aFulshr proc far
	xor	ch,ch
	jcxz	fulshr_done
fulshr_loop:
	shr	dx,1
	rcr	ax,1
	loop	fulshr_loop
fulshr_done:
	ret
__aFulshr endp

; int __cdecl __far _fmemicmp(const void __far *a, const void __far *b, size_t n)
	public	__fmemicmp
__fmemicmp proc far
	push	bp
	mov	bp,sp
	push	si
	push	di
	push	ds
	lds	si,[bp+6]		; a
	les	di,[bp+10]		; b
	mov	cx,[bp+14]		; n
	xor	ax,ax
	jcxz	fmi_done
fmi_loop:
	mov	al,[si]
	mov	ah,es:[di]
	inc	si
	inc	di
	cmp	al,'A'
	jb	fmi_a
	cmp	al,'Z'
	ja	fmi_a
	or	al,20h
fmi_a:
	cmp	ah,'A'
	jb	fmi_b
	cmp	ah,'Z'
	ja	fmi_b
	or	ah,20h
fmi_b:
	cmp	al,ah
	jne	fmi_diff
	loop	fmi_loop
	xor	ax,ax
	jmp	short fmi_done
fmi_diff:
	mov	dl,ah
	xor	ah,ah
	xor	dh,dh
	sub	ax,dx			; <0, >0
fmi_done:
	pop	ds
	pop	di
	pop	si
	pop	bp
	ret
__fmemicmp endp

OWMSC_TEXT ends
	end

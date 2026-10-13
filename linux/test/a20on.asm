; A20ON.SYS - test driver: switch the A20 line on (port 92h and keyboard
; controller) and stay off, to simulate hardware with A20 always on (and
; the state after a warm boot) for the 386MAX tests.  Loads nothing.
;
;   nasm -f bin -o A20ON.SYS linux/test/a20on.asm
;   CONFIG.SYS: DEVICE=A20ON.SYS   (before 386MAX.SYS)

	org	0
	dd	-1			; next driver
	dw	8000h			; character device
	dw	strategy
	dw	interrupt
	db	'A20ON$$$'

req	dd	0

strategy:
	mov	[cs:req],bx
	mov	[cs:req+2],es
	retf

interrupt:
	push	ax
	push	bx
	push	cx
	push	ds
	lds	bx,[cs:req]
	cmp	byte [bx+2],0		; INIT?
	jne	.done
	in	al,92h			; fast A20 on
	or	al,02h
	and	al,0FEh
	out	92h,al
	call	kbc_wait		; keyboard controller: A20 on
	mov	al,0D1h
	out	64h,al
	call	kbc_wait
	mov	al,0DFh
	out	60h,al
	call	kbc_wait
	push	cs
	pop	ax
	mov	word [bx+0Eh],0		; end of driver: nothing resident
	mov	[bx+10h],ax
	mov	dx,msg - 0
	push	ds
	push	cs
	pop	ds
	mov	dx,msg
	mov	ah,9
	int	21h
	pop	ds
.done:
	mov	word [bx+3],0100h	; done
	pop	ds
	pop	cx
	pop	bx
	pop	ax
	retf

kbc_wait:
	mov	cx,0
.1:	in	al,64h
	test	al,02h
	loopnz	.1
	ret

msg	db	'A20ON: A20 line switched on', 13, 10, '$'

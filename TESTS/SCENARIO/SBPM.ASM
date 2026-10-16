; SBPM.ASM - Sound Blaster playback from protected mode (A220 I5 D1):  a
; 32-bit DPMI client (it stays in a 16-bit code segment) resets the DSP,
; plays 1 s of a 444 Hz square wave (8-bit single cycle DMA, 11111 Hz)
; three times from a DOS memory buffer and counts the IRQs in a protected
; mode handler (INT 31h 0205h, IRETD).  The counterpart of the real mode
; SBPLAY for SB emulations that trap ports in protected mode (VSBHDA).
; Output as SBPLAY:  "IRQ after ticks", "IRQs total", errorlevel 0 if all
; three IRQs came.
; Build: jwasm -mz SBPM.ASM

	.model	small
	.386
	.stack	1024

BASE	equ	220h
LEN	equ	11111

	.data
entry	dd	?
irqs	db	0
loops	db	3
oldmask	db	?
oldoff	dd	?			; old PM handler of INT 0Dh
oldsel	dw	?
bufseg	dw	?			; DOS memory buffer
bufsel	dw	?
bios	dw	?			; selector of 0040h
ticks	dw	?
mstart	db	'SBPM: 3 x 1 s square wave, A220 I5 D1, protected mode',13,10,'$'
mnodpmi	db	'no 32-bit DPMI host',13,10,'$'
mnodsp	db	'no DSP at 220h',13,10,'$'
mnomem	db	'no DOS memory',13,10,'$'
mtimeout db	'no IRQ within 3 s',13,10,'$'
mirq	db	'IRQ after ticks: '
mirqn	db	'00',13,10,'$'
mirqs	db	'IRQs total: '
mirqsn	db	'00',13,10,'$'

	.code

; AL -> two hex digits at DS:DI
hex2	proc
	push	ax
	shr	al,4
	call	@F
	pop	ax
@@:	and	al,0Fh
	add	al,'0'
	cmp	al,'9'
	jbe	@F
	add	al,7
@@:	mov	[di],al
	inc	di
	ret
hex2	endp

print	proc			; DS:DX = '$' string (DOS via the host)
	push	eax
	movzx	edx,dx
	mov	ah,9
	int	21h
	pop	eax
	ret
print	endp

dspreset proc
	mov	dx,BASE+6
	mov	al,1
	out	dx,al
	mov	cx,200
@@:	in	al,dx
	loop	@B
	xor	al,al
	out	dx,al
	mov	dx,BASE+0Eh
	mov	cx,0FFFFh
@@:	in	al,dx
	test	al,80h
	jnz	@F
	loop	@B
@@:	mov	dx,BASE+0Ah
	in	al,dx
	ret
dspreset endp

dspw	proc
	push	ax
	mov	dx,BASE+0Ch
	mov	cx,0FFFFh
@@:	in	al,dx
	test	al,80h
	jz	@F
	loop	@B
@@:	pop	ax
	out	dx,al
	ret
dspw	endp

; IRQ5 handler for a 32-bit client (IRETD frame)
isr	proc	far
	push	eax
	push	edx
	push	ds
	mov	ax,cs:dsel
	mov	ds,ax
	mov	dx,BASE+0Eh
	in	al,dx			; acknowledge 8-bit IRQ
	inc	irqs
	mov	al,20h
	out	20h,al
	pop	ds
	pop	edx
	pop	eax
	iretd
isr	endp
dsel	dw	?			; our data selector, for the handler

start:
	mov	ax,@data
	mov	ds,ax
	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,1024/16+1
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
	mov	ax,000Ah		; data alias of CS, to store our DS
	mov	bx,cs			; for the handler
	int	31h
	mov	es,ax
	mov	es:dsel,ds
	push	ds
	pop	es
	mov	dx,offset mstart
	call	print
	; selector for 0040h
	mov	bx,40h
	mov	ax,0002h
	int	31h
	mov	bios,ax
	; DOS memory buffer:  2 x LEN, the half that doesn't cross 64K
	mov	ax,0100h
	mov	bx,(2*LEN+15)/16+1
	int	31h
	jnc	@F
	mov	dx,offset mnomem
	call	print
	jmp	exit1
@@:	mov	bufseg,ax
	mov	bufsel,dx
	call	dspreset
	cmp	al,0AAh
	je	@F
	mov	dx,offset mnodsp
	call	print
	jmp	exit1
@@:	; fill the buffer:  25 samples per period (12 high, 13 low)
	mov	es,bufsel
	xor	edi,edi
	mov	ecx,2*LEN
	xor	bl,bl
fill:	mov	al,0C0h
	cmp	bl,12
	jb	@F
	mov	al,40h
@@:	mov	es:[di],al
	inc	di
	inc	bl
	cmp	bl,25
	jb	@F
	xor	bl,bl
@@:	loop	fill
	push	ds
	pop	es
	; hook IRQ5 (INT 0Dh) in protected mode
	mov	ax,0204h
	mov	bl,0Dh
	int	31h
	mov	oldoff,edx
	mov	oldsel,cx
	mov	ax,0205h
	mov	bl,0Dh
	mov	cx,cs
	mov	edx,offset isr
	int	31h
	in	al,21h
	mov	oldmask,al
	and	al,0DFh
	out	21h,al
	sti
	mov	al,0D1h			; speaker on
	call	dspw
	mov	al,40h			; time constant
	call	dspw
	mov	al,166			; 256-1000000/11111
	call	dspw
play:	cli
	movzx	eax,bufseg		; physical address of the buffer half
	shl	eax,4
	mov	ebx,eax
	add	bx,LEN
	jnc	@F
	add	eax,LEN			; the second half then
@@:	mov	ebx,eax
	mov	al,5
	out	0Ah,al			; mask ch1
	xor	al,al
	out	0Ch,al			; clear flip flop
	mov	al,49h
	out	0Bh,al			; single, read, ch1
	mov	al,bl
	out	02h,al
	mov	al,bh
	out	02h,al
	shr	ebx,16
	mov	al,bl
	out	83h,al			; page ch1
	mov	ax,LEN-1
	out	03h,al
	mov	al,ah
	out	03h,al
	mov	al,1
	out	0Ah,al			; unmask ch1
	sti
	mov	al,14h			; 8-bit single cycle output
	call	dspw
	mov	al,(LEN-1) and 0FFh
	call	dspw
	mov	al,(LEN-1) shr 8
	call	dspw
	; wait for the IRQ, timeout 3 s
	mov	bl,irqs
	push	es
	mov	es,bios
	mov	cx,es:[6Ch]
wt:	cmp	bl,irqs
	jne	got
	mov	ax,es:[6Ch]
	sub	ax,cx
	cmp	ax,55
	jb	wt
	pop	es
	mov	dx,offset mtimeout
	call	print
	jmp	short next
got:	mov	ax,es:[6Ch]
	pop	es
	sub	ax,cx
	mov	di,offset mirqn
	call	hex2
	mov	dx,offset mirq
	call	print
next:	dec	loops
	jnz	play
	mov	al,0D3h			; speaker off
	call	dspw
	cli
	mov	al,oldmask
	out	21h,al
	sti
	mov	ax,0205h
	mov	bl,0Dh
	mov	cx,oldsel
	mov	edx,oldoff
	int	31h
	mov	al,irqs
	mov	di,offset mirqsn
	call	hex2
	mov	dx,offset mirqs
	call	print
	cmp	irqs,3
	je	@F
exit1:	mov	ax,4C01h
	int	21h
@@:	mov	ax,4C00h
	int	21h

	end	start

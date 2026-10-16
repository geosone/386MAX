; WAVPM.ASM - WAVPLAY.C for a plain 32-bit DPMI client:  plays a 16-bit
; PCM WAVE file (up to 4 channels, mixed down to stereo:  left = even
; channels, right = odd ones) on a Sound Blaster 16 or an emulation of
; it, 8-bit stereo, auto-init DMA with two half buffers refilled after
; each IRQ.  The WAVE header is parsed and the buffers are allocated in
; real mode; the client (it stays in a 16-bit code segment) reads the
; data, converts it and handles the IRQ in protected mode.
; BLASTER gives A, I and D (8-bit DMA).  Usage:  WAVPM file.wav
; Errorlevel 0 if every block raised its IRQ, 1 if not, 2 on errors.
; Build: jwasm -mz WAVPM.ASM

	.model	small
	.386
	.stack	2048

HALF	equ	8192			; bytes per half buffer (stereo 8-bit)
FRAMES	equ	HALF/2			; frames per half

	.data
entry	dd	?
base	dw	220h
irq	db	5
dma	db	1
fhandle	dw	?
chans	dw	?
rate	dd	?
left	dd	?			; data bytes not read yet
expect	dw	?			; blocks to play
blocks	dw	0
played	dw	0
irqs	dw	0			; IRQ count (the handler)
more	db	1
bufseg	dw	?			; DMA buffer (64 KB aligned half pair)
bufsel	dw	?
phys	dd	?
bios	dw	?
oldoff	dd	?
oldsel	dw	?
vec	db	?
pic	dw	?
picmask	db	?
fname	db	80 dup (0)
hdr	db	40 dup (?)
hexbuf	db	'00000000$'
mban	db	'WAVPM (DPMI):  SB16 8-bit stereo, auto-init DMA',13,10,'$'
musage	db	'usage:  WAVPM file.wav',13,10,'$'
mnowav	db	'no 16-bit PCM WAVE file with up to 4 channels',13,10,'$'
mnodpmi	db	'no 32-bit DPMI host',13,10,'$'
mnomem	db	'no memory',13,10,'$'
mnodsp	db	'no DSP',13,10,'$'
mnosb16	db	'not a Sound Blaster 16',13,10,'$'
mfmt1	db	'channels, Hz, bytes:  $'
mtime	db	'no IRQ within 1 s',13,10,'$'
mres1	db	'blocks played:  $'
mres2	db	' of $'
mres3	db	', IRQs:  $'
crlf	db	13,10,'$'
sp1	db	' $'
inb	dw	FRAMES*4 dup (?)	; one half's worth of frames (4 channels)
	.code

dsel	dw	?			; our data selector, for the handler

; IRQ handler of the 32-bit client (IRETD frame)
isr	proc	far
	push	eax
	push	edx
	push	ds
	mov	ds,cs:dsel
	mov	dx,base
	add	dx,0Eh
	in	al,dx			; acknowledge the 8-bit DMA IRQ
	inc	irqs
	mov	al,20h
	cmp	irq,8
	jb	@F
	out	0A0h,al
@@:	out	20h,al
	pop	ds
	pop	edx
	pop	eax
	iretd
isr	endp

print	proc			; DS:DX ==> '$' string
	push	eax
	movzx	edx,dx
	mov	ah,9
	int	21h
	pop	eax
	ret
print	endp

phex	proc			; EAX in hex
	pushad
	mov	di,offset hexbuf+7
	mov	cx,8
@@:	mov	bl,al
	and	bl,0Fh
	add	bl,'0'
	cmp	bl,'9'
	jbe	ph1
	add	bl,7
ph1:	mov	[di],bl
	dec	di
	shr	eax,4
	loop	@B
	mov	dx,offset hexbuf
	call	print
	popad
	ret
phex	endp

dspw	proc			; AL to the DSP
	push	ax
	push	cx
	push	dx
	mov	ah,al
	mov	dx,base
	add	dx,0Ch
	mov	cx,0FFFFh
@@:	in	al,dx
	test	al,80h
	jz	@F
	loop	@B
@@:	mov	al,ah
	out	dx,al
	pop	dx
	pop	cx
	pop	ax
	ret
dspw	endp

dspr	proc			; AL from the DSP
	push	cx
	push	dx
	mov	dx,base
	add	dx,0Eh
	mov	cx,0FFFFh
@@:	in	al,dx
	test	al,80h
	jnz	@F
	loop	@B
@@:	sub	dx,4
	in	al,dx
	pop	dx
	pop	cx
	ret
dspr	endp

; read the next frames into INB, convert them into half BL (0/1) of the
; DMA buffer, silence after the end;  MORE := 0 if there was no data
fill	proc
	pushad
	push	es
	mov	ecx,FRAMES*2		; bytes per frame:  chans*2
	movzx	eax,chans
	imul	ecx,eax			; bytes wanted
	cmp	ecx,left
	jbe	@F
	mov	ecx,left
@@:	sub	left,ecx
	xor	eax,eax			; frames got
	jecxz	fnone
	push	bx
	mov	bx,fhandle
	mov	edx,offset inb
	mov	ah,3Fh
	int	21h
	pop	bx
	movzx	eax,ax			; bytes read
	jnc	@F
	xor	eax,eax
@@:	movzx	ecx,chans
	add	ecx,ecx
	xor	edx,edx
	div	ecx			; EAX = frames got
fnone:	or	eax,eax
	jnz	@F
	mov	more,0
@@:	mov	ebp,eax			; frames got
	mov	es,bufsel
	movzx	edi,bl
	imul	edi,HALF		; ES:EDI ==> the half
	mov	esi,offset inb
	xor	ecx,ecx			; frame #
floop:	cmp	ecx,ebp
	jae	fsil
	push	ecx
	xor	ebx,ebx			; left sum
	xor	edx,edx			; right sum
	xor	ecx,ecx			; channel #
fch:	movsx	eax,word ptr [esi]
	add	esi,2
	test	cl,1
	jnz	fr
	add	ebx,eax
	jmp	short fn
fr:	add	edx,eax
fn:	inc	cx
	cmp	cx,chans
	jb	fch
	cmp	chans,1			; mono:  right = left
	jne	@F
	mov	edx,ebx
@@:	cmp	chans,3			; 3 or 4 channels:  2 per side
	jb	@F
	sar	ebx,1
	cmp	chans,4
	jb	@F
	sar	edx,1
@@:	sar	ebx,8
	add	bl,128
	sar	edx,8
	add	dl,128
	mov	es:[edi],bl
	mov	es:[edi+1],dl
	add	edi,2
	pop	ecx
	inc	ecx
	cmp	ecx,FRAMES
	jb	floop
	jmp	short fdone
fsil:	mov	word ptr es:[edi],8080h
	add	edi,2
	inc	ecx
	cmp	ecx,FRAMES
	jb	fsil
fdone:	pop	es
	popad
	ret
fill	endp

; real mode:  BLASTER from the environment (ES = PSP)
blaster	proc
	push	es
	mov	es,es:[2Ch]
	xor	di,di
bl1:	cmp	byte ptr es:[di],0
	je	bldone
	cmp	dword ptr es:[di],'SALB'
	jne	blskip
	cmp	dword ptr es:[di+4],'=RET'
	jne	blskip
	add	di,8
bl2:	mov	al,es:[di]
	or	al,al
	jz	bldone
	inc	di
	and	al,0DFh
	cmp	al,'A'
	jne	@F
	call	gethex
	mov	base,ax
	jmp	bl2
@@:	cmp	al,'I'
	jne	@F
	call	getdec
	mov	irq,al
	jmp	bl2
@@:	cmp	al,'D'
	jne	bl2
	call	getdec
	mov	dma,al
	jmp	bl2
blskip:	mov	al,es:[di]
	inc	di
	or	al,al
	jnz	blskip
	jmp	bl1
bldone:	pop	es
	ret
blaster	endp

gethex	proc			; ES:DI ==> hex digits, AX = value
	xor	ax,ax
@@:	mov	bl,es:[di]
	sub	bl,'0'
	cmp	bl,9
	jbe	gh1
	and	bl,0DFh
	sub	bl,7
	cmp	bl,0Fh
	ja	ghx
	cmp	bl,10
	jb	ghx
gh1:	shl	ax,4
	or	al,bl
	inc	di
	jmp	@B
ghx:	ret
gethex	endp

getdec	proc			; ES:DI ==> decimal digits, AX = value
	xor	ax,ax
@@:	mov	bl,es:[di]
	sub	bl,'0'
	cmp	bl,9
	ja	gdx
	imul	ax,10
	add	al,bl
	adc	ah,0
	inc	di
	jmp	@B
gdx:	ret
getdec	endp

; real mode:  read CX bytes to DS:DX, CF=1 if fewer
rread	proc
	push	cx
	mov	bx,fhandle
	mov	ah,3Fh
	int	21h
	pop	cx
	jc	@F
	cmp	ax,cx
	jb	@F
	clc
	ret
@@:	stc
	ret
rread	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	dx,offset mban
	mov	ah,9
	int	21h
	call	blaster
	mov	si,81h			; the file name
@@:	mov	al,es:[si]
	inc	si
	cmp	al,' '
	je	@B
	mov	di,offset fname
@@:	cmp	al,' '
	jbe	@F
	mov	[di],al
	inc	di
	mov	al,es:[si]
	inc	si
	jmp	@B
@@:	cmp	fname,0
	jne	@F
	mov	dx,offset musage
	jmp	err2
@@:	mov	bx,ss			; shrink to code+data+stack (ES = PSP)
	mov	ax,es
	sub	bx,ax
	add	bx,2048/16+1
	mov	ah,4Ah
	int	21h

	; the WAVE header
	mov	dx,offset fname
	mov	ax,3D00h
	int	21h
	jc	nowav
	mov	fhandle,ax
	mov	dx,offset hdr
	mov	cx,12
	call	rread
	jc	nowav
	cmp	dword ptr hdr,'FFIR'
	jne	nowav
	cmp	dword ptr hdr+8,'EVAW'
	jne	nowav
chunk:	mov	dx,offset hdr
	mov	cx,8
	call	rread
	jc	nowav
	mov	eax,dword ptr hdr+4	; chunk size
	cmp	dword ptr hdr,' tmf'
	je	fmtck
	cmp	dword ptr hdr,'atad'
	je	datack
	inc	eax			; skip (word aligned)
	and	al,0FEh
	mov	dx,ax
	shr	eax,16
	mov	cx,ax
	mov	bx,fhandle
	mov	ax,4201h
	int	21h
	jmp	chunk
fmtck:	cmp	eax,16
	jb	nowav
	cmp	eax,40
	ja	nowav
	mov	cx,ax
	mov	dx,offset hdr
	call	rread
	jc	nowav
	mov	ax,word ptr hdr		; format tag
	cmp	ax,0FFFEh		; extensible:  the sub format
	jne	@F
	cmp	cx,26
	jb	nowav
	mov	ax,word ptr hdr+24
@@:	cmp	ax,1
	jne	nowav
	cmp	word ptr hdr+14,16	; bits
	jne	nowav
	mov	ax,word ptr hdr+2
	mov	chans,ax
	or	ax,ax
	jz	nowav
	cmp	ax,4
	ja	nowav
	mov	eax,dword ptr hdr+4
	mov	rate,eax
	jmp	chunk
datack:	cmp	chans,0
	je	nowav
	mov	left,eax
	movzx	ecx,chans		; blocks = ceil(frames / FRAMES)
	add	ecx,ecx
	xor	edx,edx
	div	ecx
	add	eax,FRAMES-1
	shr	eax,12			; / FRAMES (4096)
	mov	expect,ax
	jmp	short gotwav
nowav:	mov	dx,offset mnowav
err2:	mov	ah,9
	int	21h
	mov	ax,4C02h
	int	21h

gotwav:	; the DMA buffer:  2 halves not crossing 64 KB
	mov	bx,(4*HALF)/16
	mov	ah,48h
	int	21h
	jnc	@F
	mov	dx,offset mnomem
	jmp	err2
@@:	movzx	eax,ax
	shl	eax,4
	mov	edx,eax
	and	edx,0FFFFh
	add	edx,2*HALF
	cmp	edx,10000h
	jbe	@F
	add	eax,0FFFFh
	and	eax,0FFFF0000h
@@:	mov	phys,eax
	shr	eax,4
	mov	bufseg,ax

	; protected mode
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
@@:	mov	ax,1
	call	entry
	jnc	pm
nodpmi:	mov	dx,offset mnodpmi
	jmp	err2

pm:	movzx	esp,sp
	mov	ax,000Ah		; data alias of CS for the handler
	mov	bx,cs
	int	31h
	mov	es,ax
	mov	es:dsel,ds		; (writes through the alias)
	push	ds
	pop	es
	mov	bx,40h
	mov	ax,0002h
	int	31h
	mov	bios,ax
	mov	bx,bufseg
	mov	ax,0002h
	int	31h
	mov	bufsel,ax

	mov	dx,offset mfmt1
	call	print
	movzx	eax,chans
	call	phex
	mov	dx,offset sp1
	call	print
	mov	eax,rate
	call	phex
	mov	dx,offset sp1
	call	print
	mov	eax,left
	call	phex
	mov	dx,offset crlf
	call	print

	; the DSP:  reset, version 4 or later
	mov	dx,base
	add	dx,6
	mov	al,1
	out	dx,al
	mov	cx,200
@@:	in	al,dx
	loop	@B
	xor	al,al
	out	dx,al
	call	dspr
	cmp	al,0AAh
	je	@F
	mov	dx,offset mnodsp
	jmp	pmerr
@@:	mov	al,0E1h
	call	dspw
	call	dspr
	mov	ah,al
	call	dspr
	cmp	ah,4
	jae	@F
	mov	dx,offset mnosb16
pmerr:	call	print
	mov	ax,4C02h
	int	21h

@@:	mov	bl,0
	call	fill
	mov	bl,1
	call	fill

	; the IRQ
	mov	al,irq
	add	al,8
	mov	pic,21h
	cmp	irq,8
	jb	@F
	add	al,70h-16
	mov	pic,0A1h
@@:	mov	vec,al
	mov	bl,al
	mov	ax,0204h
	int	31h
	mov	oldoff,edx
	mov	oldsel,cx
	mov	bl,vec
	mov	cx,cs
	mov	edx,offset isr
	mov	ax,0205h
	int	31h
	mov	dx,pic
	in	al,dx
	mov	picmask,al
	mov	cl,irq
	and	cl,7
	mov	ah,1
	shl	ah,cl
	not	ah
	and	al,ah
	out	dx,al

	; the DMA channel:  single, auto-init, read
	movzx	dx,dma
	mov	al,dl
	or	al,4
	out	0Ah,al
	out	0Ch,al
	mov	al,dl
	or	al,58h
	out	0Bh,al
	shl	dx,1			; address port
	mov	eax,phys
	out	dx,al
	mov	al,ah
	out	dx,al
	shr	eax,16
	mov	bl,dma			; page port
	mov	dx,87h
	cmp	bl,0
	je	@F
	mov	dx,83h
	cmp	bl,1
	je	@F
	mov	dx,81h
	cmp	bl,2
	je	@F
	mov	dx,82h
@@:	out	dx,al
	movzx	dx,dma
	shl	dx,1
	inc	dx			; count port
	mov	ax,2*HALF-1
	out	dx,al
	mov	al,ah
	out	dx,al
	mov	al,dma
	out	0Ah,al			; unmask

	mov	al,41h			; output rate
	call	dspw
	mov	al,byte ptr rate+1
	call	dspw
	mov	al,byte ptr rate
	call	dspw
	sti
	mov	al,0C6h			; 8-bit, auto-init, FIFO
	call	dspw
	mov	al,20h			; stereo, unsigned
	call	dspw
	mov	al,(HALF-1) and 0FFh
	call	dspw
	mov	al,(HALF-1) shr 8
	call	dspw

	; after IRQ n the half (n-1)&1 is played:  refill it
play:	push	es
	mov	es,bios
	mov	cx,es:[6Ch]
@@:	mov	ax,irqs
	cmp	ax,played
	jne	got
	mov	ax,es:[6Ch]
	sub	ax,cx
	cmp	ax,18
	jb	@B
	pop	es
	mov	dx,offset mtime
	call	print
	jmp	short stop
got:	pop	es
	inc	played
	inc	blocks
	cmp	more,0
	je	stop			; the last data half is out
	mov	bl,byte ptr played
	dec	bl
	and	bl,1
	call	fill
	jmp	play

stop:	mov	al,0DAh			; exit 8-bit auto-init
	call	dspw
	mov	al,0D0h
	call	dspw
	mov	al,dma
	or	al,4
	out	0Ah,al
	mov	dx,pic
	mov	al,picmask
	out	dx,al
	mov	bl,vec
	mov	cx,oldsel
	mov	edx,oldoff
	mov	ax,0205h
	int	31h
	mov	dx,offset mres1
	call	print
	movzx	eax,blocks
	call	phex
	mov	dx,offset mres2
	call	print
	movzx	eax,expect
	call	phex
	mov	dx,offset mres3
	call	print
	movzx	eax,irqs
	call	phex
	mov	dx,offset crlf
	call	print
	mov	ax,blocks
	cmp	ax,expect
	jne	@F
	mov	ax,4C00h
	int	21h
@@:	mov	ax,4C01h
	int	21h

	end	start

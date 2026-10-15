; QPIVID.ASM - QEMM Programming Interface 13h (VIDRAM / DESQview video),
; the parts for text mode background windows, as QEMM 97 does them:
;   1301h find a dirty video page, 130Ah DAC buffer (filled by the 0Dh
;   DAC traps), 1308h all CRT ports trapped (writes dropped, GC 06h
;   remembered, 3DAh synthetic), 1309h Hercules callback, 1312h CF=1.
; Nothing is printed while ports are trapped; checks come afterwards.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPIVID.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
dacbuf	db	2+256*3 dup (0)
dac	db	3 dup (?)		; real DAC entry 5 before
real0c	db	?
realgc6	db	?
r_d1	db	0			; results (1 = as expected)
r_d2	db	0
r_d3	db	0
r_dac1	db	0
r_dac2	db	0
r_dac3	db	0
r_8on	db	0
r_8crt	db	0
r_8gc	db	0
r_8gcr	db	0
r_8rt	db	0
r_8off	db	0
r_herc	db	0
r_12	db	0
	.code
	include	TESTLIB.INC

hval	dw	0FFFFh

hcb	proc	far			; Hercules callback:  AL = value
	mov	byte ptr cs:hval,al
	mov	byte ptr cs:hval+1,0
	ret
hcb	endp

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; real register AH of the indexed port pair DX/DX+1 into AL (1A02h)
rawrd	proc
	push	bx
	mov	bh,ah
	mov	ax,1A02h
	call	qcall
	mov	al,bl
	pop	bx
	ret
rawrd	endp

; 1301h for B800h-BFFFh with the cursor at B800:DI:  CX, DI
dirty	proc
	mov	dx,0B800h
	mov	cx,0800h
	mov	ax,1301h
	call	qcall
	ret
dirty	endp

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
	mov	ah,0Fh			; colour text mode?
	int	10h
	cmp	al,7
	jne	@F
	INFO	'mono display:  skipped'
	jmp	done
@@:
	; 1301h:  clear all, write page BAh, find it, then none
	mov	si,12
@@:	xor	di,di
	call	dirty
	jc	@F
	jcxz	@F
	dec	si
	jnz	@B
@@:	push	es
	mov	ax,0B800h
	mov	es,ax
	mov	al,es:[2000h]
	mov	es:[2000h],al		; page BAh dirty
	pop	es
	xor	di,di
	call	dirty
	jc	@F
	cmp	cx,1000h
	jne	@F
	mov	r_d1,1
	cmp	di,0A000h
	jne	@F
	mov	r_d2,1
@@:	mov	di,0A000h
	call	dirty
	jc	@F
	or	cx,cx
	jnz	@F
	mov	r_d3,1
@@:
	; 130Ah + 0Dh:  DAC writes go to the buffer, not to the DAC
	mov	dx,3C7h
	mov	al,5
	out	dx,al
	mov	dx,3C9h
	in	al,dx
	mov	dac,al
	in	al,dx
	mov	dac+1,al
	in	al,dx
	mov	dac+2,al
	mov	cx,ds
	mov	dx,offset dacbuf
	mov	ax,130Ah
	call	qcall
	jc	@F
	mov	ax,0D02h
	call	qcall
	jc	@F
	mov	r_dac1,1
@@:	mov	dx,3C8h
	mov	al,5
	out	dx,al
	inc	dx
	mov	al,11h
	out	dx,al
	mov	al,22h
	out	dx,al
	mov	al,33h
	out	dx,al
	mov	al,0Ah
	out	dx,al
	cmp	word ptr dacbuf,0106h	; index 6, component 1
	jne	@F
	cmp	word ptr dacbuf+2+15,2211h
	jne	@F
	cmp	word ptr dacbuf+2+17,0A33h
	jne	@F
	mov	r_dac2,1
@@:	mov	dx,3C7h
	mov	al,5
	out	dx,al
	mov	dx,3C9h
	in	al,dx
	cmp	al,dac
	jne	@F
	in	al,dx
	cmp	al,dac+1
	jne	@F
	in	al,dx
	cmp	al,dac+2
	jne	@F
	mov	r_dac3,1
@@:	mov	ax,0D00h
	call	qcall
	xor	cx,cx
	xor	dx,dx
	mov	ax,130Ah
	call	qcall

	; 1308h:  all CRT ports trapped
	mov	dx,3D4h
	mov	ah,0Ch
	call	rawrd
	mov	real0c,al
	mov	dx,3CEh
	mov	ah,06h
	call	rawrd
	mov	realgc6,al
	mov	bl,1
	mov	ax,1308h
	call	qcall
	jc	@F
	mov	r_8on,1
@@:	mov	dx,3D4h			; CRTC 0Ch := real XOR 55h:  dropped
	mov	al,0Ch
	out	dx,al
	inc	dx
	mov	al,real0c
	xor	al,55h
	out	dx,al
	mov	dx,3D4h
	mov	ah,0Ch
	call	rawrd
	cmp	al,real0c
	jne	@F
	mov	r_8crt,1
@@:	mov	dx,3CEh			; GC 06h := real XOR 0Ch:  remembered
	mov	al,06h
	out	dx,al
	inc	dx
	mov	al,realgc6
	xor	al,0Ch
	out	dx,al
	in	al,dx
	mov	bl,realgc6
	xor	bl,0Ch
	cmp	al,bl
	jne	@F
	mov	r_8gc,1
@@:	mov	dx,3CEh
	mov	ah,06h
	call	rawrd
	cmp	al,realgc6
	jne	@F
	mov	r_8gcr,1
@@:	mov	dx,3DAh			; 300 reads:  both kinds
	mov	cx,300
	xor	bx,bx
rtl:	in	al,dx
	and	al,09h
	jz	rt0
	cmp	al,09h
	jne	rtx
	mov	bl,1
	jmp	short rtn
rt0:	mov	bh,1
rtn:	loop	rtl
	cmp	bx,0101h
	jne	rtx
	mov	r_8rt,1
rtx:	xor	bl,bl
	mov	ax,1308h
	call	qcall
	mov	dx,3CEh			; through again:  the real GC 06h
	mov	al,06h
	out	dx,al
	inc	dx
	in	al,dx
	cmp	al,realgc6
	jne	@F
	mov	r_8off,1
@@:
	; 1309h:  Hercules callback in 0Dh mode 1
	push	es
	push	cs
	pop	es
	mov	bx,offset hcb
	mov	ax,1309h
	call	qcall
	pop	es
	mov	ax,0D01h
	call	qcall
	mov	dx,3B8h
	mov	al,29h
	out	dx,al
	mov	ax,0D00h
	call	qcall
	cmp	cs:hval,0029h
	jne	@F
	mov	r_herc,1
@@:	mov	ax,1312h
	call	qcall
	jnc	@F
	mov	r_12,1
@@:
	TITLE_	'1301h find a dirty page'
	cmp	r_d1,1
	CHECK	'page written -> CX=1000h', e
	cmp	r_d2,1
	CHECK	'DI = A000h (page BAh)', e
	cmp	r_d3,1
	CHECK	'again from there:  CX=0', e
	TITLE_	'130Ah DAC buffer with 0Dh'
	cmp	r_dac1,1
	CHECK	'130A, 0D02 CF=0', e
	cmp	r_dac2,1
	CHECK	'buffer:  index, component, RGB', e
	cmp	r_dac3,1
	CHECK	'real DAC unchanged', e
	TITLE_	'1308h all CRT ports'
	cmp	r_8on,1
	CHECK	'1308 BL=1 CF=0', e
	cmp	r_8crt,1
	CHECK	'CRTC write dropped', e
	cmp	r_8gc,1
	CHECK	'IN 3CFh = GC 06h written', e
	cmp	r_8gcr,1
	CHECK	'real GC 06h unchanged', e
	cmp	r_8rt,1
	CHECK	'3DAh display enable/retrace set and clear', e
	cmp	r_8off,1
	CHECK	'1308 BL=0:  through again', e
	TITLE_	'1309h, 1312h'
	cmp	r_herc,1
	CHECK	'Hercules callback AL = value written', e
	cmp	r_12,1
	CHECK	'1312 CF=1', e
done:	call	finish

	end	start

; QPICRT.ASM - QEMM Programming Interface 0Dh/0Eh:  CRTC/DAC trapping
; with cursor callbacks as QEMM 97 does it (DESQview keeps background
; programs off the real CRTC and DAC with it).  Mode 2 (colour):
;  - cursor address (3D5h index 0Eh/0Fh, byte and word OUT) goes to the
;    GET/SET callbacks, the real CRTC is not changed; IN 3D5h of those
;    indexes returns GET's value
;  - cursor shape (0Ah/0Bh) goes through, other indexes are dropped
;  - DAC writes (3C8h/3C9h) are dropped
;  - 3DAh reads give display enable/retrace both set or both clear
;  - 1A02h/1A03h reach the real CRTC past the trapping
; Nothing is printed while the trapping is on (the BIOS sets the cursor
; through the CRTC); the results are checked afterwards.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no QPI.
; Build: jwasm -mz QPICRT.ASM

	.model	small
	.386
	.stack	1024

	.data
qpi	dd	0
mode	db	?
real0e	db	?			; real CRTC registers before
real0f	db	?
real0a	db	?
real0c	db	?
dac	db	3 dup (?)		; DAC entry 1 before
r_cf	db	0			; results (1 = as expected)
r_set1	db	0
r_set2	db	0
r_word	db	0
r_in	db	0
r_real	db	0
r_shape	db	0
r_drop	db	0
r_dac	db	0
r_rt	db	0
r_1a03	db	0
r_off	db	0
	.code
	include	TESTLIB.INC

curpos	dw	0
nset	dw	0

get	proc	far			; GET:  BX = cursor address
	mov	bx,cs:curpos
	ret
get	endp

set	proc	far			; SET:  BX = cursor address
	mov	cs:curpos,bx
	inc	cs:nset
	ret
set	endp

qcall	proc			; call the QPI entry
	call	[qpi]
	ret
qcall	endp

; real CRTC register AH into AL (QPI 1A02h:  untrapped indexed read)
crtrd	proc
	push	bx
	push	dx
	mov	bh,ah
	mov	dx,3D4h
	mov	ax,1A02h
	call	qcall
	mov	al,bl
	pop	dx
	pop	bx
	ret
crtrd	endp

; CRTC register AH := AL through the (trapped) ports
crtwr	proc
	push	dx
	push	ax
	mov	dx,3D4h
	mov	al,ah
	out	dx,al
	pop	ax
	inc	dx
	out	dx,al
	pop	dx
	ret
crtwr	endp

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
	; the real state before
	mov	ah,0Eh
	call	crtrd
	mov	real0e,al
	mov	ah,0Fh
	call	crtrd
	mov	real0f,al
	mov	ah,0Ah
	call	crtrd
	mov	real0a,al
	mov	ah,0Ch
	call	crtrd
	mov	real0c,al
	mov	dx,3C7h
	mov	al,1
	out	dx,al
	mov	dx,3C9h
	in	al,dx
	mov	dac,al
	in	al,dx
	mov	dac+1,al
	in	al,dx
	mov	dac+2,al

	; callbacks, mode 2
	push	ds
	mov	bx,offset get
	push	cs
	pop	es
	mov	dx,offset set
	push	cs
	pop	ds
	mov	ax,0E00h
	call	qcall_far
	pop	ds
	push	ds
	pop	es
	mov	ax,0D02h
	call	qcall
	jc	@F
	cmp	al,02h
	jne	@F
	mov	r_cf,1
@@:	cli
	mov	cs:curpos,0
	mov	cs:nset,0
	mov	ax,0E12h		; cursor high := 12h
	call	crtwr
	cmp	cs:curpos,1200h
	jne	@F
	cmp	cs:nset,1
	jne	@F
	mov	r_set1,1
@@:	mov	ax,0F34h		; cursor low := 34h
	call	crtwr
	cmp	cs:curpos,1234h
	jne	@F
	mov	r_set2,1
@@:	mov	dx,3D4h
	mov	ax,560Eh		; word OUT:  index 0Eh, data 56h
	out	dx,ax
	cmp	cs:curpos,5634h
	jne	@F
	mov	r_word,1
@@:	mov	dx,3D4h
	mov	al,0Fh
	out	dx,al
	inc	dx
	in	al,dx
	cmp	al,34h
	jne	@F
	mov	r_in,1
@@:	mov	ah,0Eh			; real cursor unchanged
	call	crtrd
	cmp	al,real0e
	jne	@F
	mov	ah,0Fh
	call	crtrd
	cmp	al,real0f
	jne	@F
	mov	r_real,1
@@:	mov	al,real0a		; cursor shape goes through
	xor	al,01h
	mov	ah,0Ah
	call	crtwr
	mov	ah,0Ah
	call	crtrd
	mov	bl,real0a
	xor	bl,01h
	cmp	al,bl
	jne	@F
	mov	r_shape,1
@@:	mov	al,real0a
	mov	ah,0Ah
	call	crtwr
	mov	al,real0c		; start address high:  dropped
	xor	al,55h
	mov	ah,0Ch
	call	crtwr
	mov	ah,0Ch
	call	crtrd
	cmp	al,real0c
	jne	@F
	mov	r_drop,1
@@:	mov	dx,3C8h			; DAC entry 1 := 3Fh 3Fh 3Fh:  dropped
	mov	al,1
	out	dx,al
	inc	dx
	mov	al,3Fh
	out	dx,al
	out	dx,al
	out	dx,al
	mov	dx,3C7h
	mov	al,1
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
	mov	r_dac,1
@@:	mov	dx,3DAh			; 300 reads:  bits 0/3 both set or
	mov	cx,300			; both clear, and both kinds seen
	xor	bx,bx			; BL = 09h seen, BH = 00h seen
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
	mov	r_rt,1
rtx:	mov	ax,cs:nset		; 1A03h:  real CRTC, no callback
	push	ax
	mov	dx,3D4h
	mov	bh,0Fh
	mov	bl,real0f
	mov	ax,1A03h
	call	qcall
	pop	ax
	cmp	ax,cs:nset
	jne	@F
	mov	r_1a03,1
@@:	sti
	mov	ax,0D00h		; off
	call	qcall
	mov	ax,cs:nset
	push	ax
	mov	al,real0f		; through to the CRTC again
	mov	ah,0Fh
	call	crtwr
	pop	ax
	cmp	ax,cs:nset
	jne	@F
	mov	ah,0Fh
	call	crtrd
	cmp	al,real0f
	jne	@F
	mov	r_off,1
@@:
	TITLE_	'0Dh mode 2 (colour) with 0Eh cursor callbacks'
	cmp	r_cf,1
	CHECK	'0D02 CF=0 AL=02h', e
	cmp	r_set1,1
	CHECK	'OUT index 0Eh -> GET/SET, BH replaced', e
	cmp	r_set2,1
	CHECK	'OUT index 0Fh -> BL replaced', e
	cmp	r_word,1
	CHECK	'word OUT 3D4h (index+data) -> SET', e
	cmp	r_in,1
	CHECK	'IN 3D5h index 0Fh = GET''s BL', e
	cmp	r_real,1
	CHECK	'real cursor registers unchanged', e
	cmp	r_shape,1
	CHECK	'cursor shape (0Ah) goes through', e
	cmp	r_drop,1
	CHECK	'other index (0Ch) dropped', e
	cmp	r_dac,1
	CHECK	'DAC writes dropped', e
	cmp	r_rt,1
	CHECK	'3DAh:  display enable/retrace set and clear', e
	cmp	r_1a03,1
	CHECK	'1A03h:  real CRTC, no callback', e
	cmp	r_off,1
	CHECK	'0D00 off:  through to the CRTC again', e
done:	call	finish

; far call to the QPI entry with our DS changed (DS = CS here)
qcall_far proc
	push	ds
	push	ax
	mov	ax,@data
	mov	ds,ax
	pop	ax
	push	word ptr qpi+2
	push	word ptr qpi
	pop	cs:qtmp
	pop	cs:qtmp+2
	pop	ds
	call	dword ptr cs:qtmp
	ret
qcall_far endp
qtmp	dw	?,?

	end	start

; EMSFUNC.ASM - LIM EMS 3.2/4.0 functions of the active EMM: status,
; page frame, allocate/map/deallocate with data checks, error codes, save/
; restore page map (47h/48h, 4Eh, 4Fh), map multiple (50h), reallocate
; (51h), handle names (53h/54h), alter map and jump/call (55h/56h), move
; and exchange regions (57h) incl. page crossing and overlap, mappable
; pages (58h), raw pages (59h) and the alternate map register sets (5Bh).
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no EMM.
; Build: jwasm -mz EMSFUNC.ASM

	.model	small
	.386
	.stack	1024

NPG	equ	8		; logical pages of the test handle
CBUF	equ	6000h		; conventional buffers

MOVR	struc
rlen	dd ?
stype	db ?
shnd	dw ?
soff	dw ?
sseg	dw ?
dtype	db ?
dhnd	dw ?
doff	dw ?
dseg	dw ?
MOVR	ends

	.data
frame	dw ?
hnd	dw ?
hnd2	dw ?
nmap	dw ?
mvr	MOVR <>
name1	db 'EMSFUNC1'
mlist	dw 1, ?		; 4Fh: one segment
mmult	dw 5,0, 6,1	; 50h: log 5 -> phys 0, log 6 -> phys 1
msegs	dw 3,?, 4,?	; 5001h: log 3 -> seg frame, log 4 -> seg frame+400h
; 56h/55h: map structures {count, ptr to list}
newmap	db 2
	dw offset newlst, seg newlst
newlst	dw 7,0, 2,1
oldmap	db 2
	dw offset oldlst, seg oldlst
oldlst	dw 0,0, 1,1
calls	dw 0
jmpst	dw offset jmptgt, seg jmptgt	; 55h: target, then the new map
	db 1
	dw offset newlst, seg newlst
callst	dd ?		; 56h: far target
	db 2
	dw offset newlst, seg newlst
	db 2
	dw offset oldlst, seg oldlst
	db 8 dup (0)
mapsz	dw ?
altset	db ?
ivt21	dd ?

	.data?
mapbuf	db 1024 dup (?)
mapbuf2	db 1024 dup (?)
cbuf1	db CBUF dup (?)
cbuf2	db CBUF dup (?)
hdir	db 3*255 dup (?)
physa	dw 2*64 dup (?)

	.code
	include	TESTLIB.INC

; ems call with ah set: returns ah=status, flags of "cmp ah,0"
ems	macro	fn
	mov	ax,fn
	int	67h
	cmp	ah,0
	endm

; map logical page bx of hnd into physical page al
mapp	proc
	push	dx
	mov	ah,44h
	mov	dx,hnd
	int	67h
	cmp	ah,0
	pop	dx
	ret
mapp	endp

; es = segment of physical page al (al 0..3)
physseg proc
	push	ax
	movzx	ax,al
	shl	ax,10
	add	ax,frame
	mov	es,ax
	pop	ax
	ret
physseg endp

; write the signature of logical page bx into physical page al
wsig	proc
	push	es
	call	physseg
	mov	word ptr es:[0],bx
	mov	word ptr es:[2],'PE'
	mov	word ptr es:[3FFCh],bx
	xor	word ptr es:[3FFCh],0A5A5h
	pop	es
	ret
wsig	endp

; check the signature of logical page bx in physical page al: ZF=1 ok
csig	proc
	push	es
	push	ax
	call	physseg
	cmp	word ptr es:[0],bx
	jne	cs1
	cmp	word ptr es:[2],'PE'
	jne	cs1
	mov	ax,bx
	xor	ax,0A5A5h
	cmp	word ptr es:[3FFCh],ax
cs1:	pop	ax
	pop	es
	ret
csig	endp

; far procedure called through 56h: checks the new mapping
callee	proc	far
	push	ds
	push	ax
	push	bx
	mov	ax,@data
	mov	ds,ax
	mov	al,0
	mov	bx,7
	call	csig
	jne	@F
	mov	al,1
	mov	bx,2
	call	csig
	jne	@F
	inc	calls
@@:	pop	bx
	pop	ax
	pop	ds
	ret
callee	endp

; fill cbuf1 with pattern from seed eax
fillc	proc
	push	di
	push	cx
	mov	di,offset cbuf1
	mov	cx,CBUF/4
@@:	mov	[di],eax
	add	eax,3B9AC9F1h
	add	di,4
	loop	@B
	pop	cx
	pop	di
	ret
fillc	endp

; compare cx bytes cbuf1 / cbuf2: ZF
cmpc	proc
	push	si
	push	di
	push	es
	push	ds
	pop	es
	mov	si,offset cbuf1
	mov	di,offset cbuf2
	cld
	repe	cmpsb
	pop	es
	pop	di
	pop	si
	ret
cmpc	endp

movreg	proc			; 5700h/5701h with al
	mov	ah,57h
	mov	si,offset mvr
	int	67h
	ret
movreg	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	; EMM present: INT 67h set and status (40h) ok; the device name at
	; INT 67h segment:000Ah is not checked (MS EMM386 points INT 67h to a
	; stub elsewhere)
	push	ds
	xor	ax,ax
	mov	ds,ax
	mov	eax,ds:[67h*4]
	pop	ds
	or	eax,eax
	jz	noemm
	mov	ah,40h
	int	67h
	cmp	ah,0
	je	@F
noemm:	INFO	'no EMM'
	mov	ax,4C02h
	int	21h
@@:
	TITLE_	'status, version, frame, pages'
	ems	4000h
	CHECK	'status (40h)', e
	ems	4600h
	NOTE_	'version '
	call	phex8
	cmp	al,40h
	CHECK	' >= 4.0', ae
	ems	4100h
	mov	frame,bx
	NOTE_	'page frame '
	mov	ax,bx
	call	phex16
	cmp	frame,0A000h
	CHECK	' (41h) above A000h', a
	ems	4200h
	NOTE_	'free/total pages '
	mov	ax,bx
	call	phex16
	mov	ax,dx
	NOTE_	'/'
	call	phex16
	cmp	bx,NPG*2+4
	CHECK	' (42h) enough free', ae

	TITLE_	'allocate, map'
	mov	bx,NPG
	ems	4300h
	mov	hnd,dx
	CHECK	'allocate 8 pages (43h)', e
	mov	dx,hnd
	ems	4C00h
	cmp	bx,NPG
	CHECK	'handle pages 8 (4Ch)', e
	ems	4B00h
	cmp	bx,2
	CHECK	'active handles >= 2 (4Bh)', ae
	mov	nmap,bx
	mov	di,offset hdir
	ems	4D00h
	cmp	bx,nmap
	CHECK	'handle directory (4Dh) count equal', e
	; write a signature into each logical page through physical page 0..3
	xor	bx,bx
	xor	bp,bp
wl:	mov	ax,bx
	and	al,3
	push	ax
	call	mapp
	pop	ax
	jne	@F
	call	wsig
	inc	bp
@@:	inc	bx
	cmp	bx,NPG
	jb	wl
	cmp	bp,NPG
	CHECK	'map all pages and write (44h)', e
	; read back in a different order: page n through physical page 3-(n and 3)
	xor	bx,bx
	xor	bp,bp
rl:	mov	al,bl
	and	al,3
	xor	al,3
	push	ax
	call	mapp
	pop	ax
	call	csig
	jne	@F
	inc	bp
@@:	inc	bx
	cmp	bx,NPG
	jb	rl
	cmp	bp,NPG
	CHECK	'contents of all pages', e
	; same logical page in two physical pages
	mov	al,0
	mov	bx,5
	call	mapp
	mov	al,2
	mov	bx,5
	call	mapp
	push	es
	mov	al,0
	call	physseg
	mov	word ptr es:[100h],1234h
	mov	al,2
	call	physseg
	cmp	word ptr es:[100h],1234h
	pop	es
	CHECK	'one logical page in two physical pages', e

	TITLE_	'error codes'
	mov	al,0
	mov	bx,NPG
	call	mapp
	cmp	ah,8Ah
	CHECK	'logical page out of range: 8Ah', e
	mov	al,0F0h
	mov	bx,0
	call	mapp
	cmp	ah,8Bh
	CHECK	'invalid physical page: 8Bh', e
	mov	ax,4400h
	mov	bx,0
	mov	dx,0FFF0h
	int	67h
	cmp	ah,83h
	CHECK	'invalid handle: 83h', e
	mov	bx,7FFFh
	ems	4300h
	cmp	ah,87h
	je	@F
	cmp	ah,88h
@@:	CHECK	'too many pages: 87h/88h', e
	ems	4F05h
	cmp	ah,8Fh
	CHECK	'invalid subfunction: 8Fh', e

	TITLE_	'save/restore page map'
	mov	al,0
	mov	bx,0
	call	mapp
	mov	dx,hnd
	ems	4700h
	CHECK	'save (47h)', e
	mov	al,0
	mov	bx,1
	call	mapp
	mov	dx,hnd
	ems	4700h
	cmp	ah,8Dh
	CHECK	'second save: 8Dh', e
	mov	dx,hnd
	ems	4800h
	CHECK	'restore (48h)', e
	mov	al,0
	mov	bx,0
	call	csig
	CHECK	'page 0 back in physical page 0', e

	ems	4E03h
	mov	mapsz,ax
	NOTE_	'map size (4E03h) '
	movzx	ax,al
	mov	mapsz,ax
	call	phex16
	call	pcrlf
	mov	al,0
	mov	bx,3
	call	mapp
	mov	al,1
	mov	bx,4
	call	mapp
	mov	di,offset mapbuf
	ems	4E00h
	CHECK	'get map (4E00h)', e
	mov	al,0
	mov	bx,6
	call	mapp
	mov	al,1
	mov	bx,7
	call	mapp
	mov	si,offset mapbuf
	ems	4E01h
	CHECK	'set map (4E01h)', e
	mov	al,0
	mov	bx,3
	call	csig
	jne	@F
	mov	al,1
	mov	bx,4
	call	csig
@@:	CHECK	'mapping restored', e
	mov	si,offset mapbuf
	mov	di,offset mapbuf2
	ems	4E02h
	CHECK	'get and set map (4E02h)', e

	mov	ax,frame
	mov	mlist+2,ax
	mov	bx,1
	ems	4F02h
	NOTE_	'partial map size (4F02h) '
	call	phex8
	call	pcrlf
	mov	al,0
	mov	bx,2
	call	mapp
	mov	si,offset mlist
	mov	di,offset mapbuf
	ems	4F00h
	CHECK	'get partial map (4F00h)', e
	mov	al,0
	mov	bx,5
	call	mapp
	mov	si,offset mapbuf
	ems	4F01h
	CHECK	'set partial map (4F01h)', e
	mov	al,0
	mov	bx,2
	call	csig
	CHECK	'mapping restored', e

	TITLE_	'map multiple, reallocate'
	mov	si,offset mmult
	mov	cx,2
	mov	dx,hnd
	ems	5000h
	CHECK	'map multiple by number (5000h)', e
	mov	al,0
	mov	bx,5
	call	csig
	jne	@F
	mov	al,1
	mov	bx,6
	call	csig
@@:	CHECK	'pages 5 and 6 mapped', e
	mov	ax,frame
	mov	msegs+2,ax
	add	ax,400h
	mov	msegs+6,ax
	mov	si,offset msegs
	mov	cx,2
	mov	dx,hnd
	ems	5001h
	CHECK	'map multiple by segment (5001h)', e
	mov	al,0
	mov	bx,3
	call	csig
	jne	@F
	mov	al,1
	mov	bx,4
	call	csig
@@:	CHECK	'pages 3 and 4 mapped', e

	mov	bx,NPG+4
	mov	dx,hnd
	ems	5100h
	CHECK	'grow to 12 pages (51h)', e
	mov	dx,hnd
	ems	4C00h
	cmp	bx,NPG+4
	CHECK	'12 pages', e
	mov	al,0
	mov	bx,NPG+3
	call	mapp
	CHECK	'map the last new page', e
	xor	bx,bx
	xor	bp,bp
@@:	mov	al,0
	call	mapp
	call	csig
	jne	rl2
	inc	bp
rl2:	inc	bx
	cmp	bx,NPG
	jb	@B
	cmp	bp,NPG
	CHECK	'old contents kept', e

	TITLE_	'handle names'
	mov	si,offset name1
	mov	dx,hnd
	ems	5301h
	CHECK	'set name (5301h)', e
	mov	di,offset mapbuf
	mov	dx,hnd
	ems	5300h
	mov	si,offset name1
	mov	di,offset mapbuf
	mov	cx,8
	repe	cmpsb
	CHECK	'get name (5300h)', e
	mov	si,offset name1
	ems	5401h
	cmp	dx,hnd
	CHECK	'search name (5401h)', e
	ems	5402h
	NOTE_	'total handles (5402h) '
	mov	ax,bx
	call	phex16
	call	pcrlf
	mov	bx,1
	ems	4300h
	mov	hnd2,dx
	mov	si,offset name1
	mov	dx,hnd2
	ems	5301h
	cmp	ah,0A1h
	CHECK	'duplicate name: A1h', e
	mov	dx,hnd2
	ems	4500h

	TITLE_	'alter map and jump/call'
	mov	al,0
	mov	bx,0
	call	mapp
	mov	al,1
	mov	bx,1
	call	mapp
	ems	5602h
	NOTE_	'stack space (5602h) '
	mov	ax,bx
	call	phex16
	call	pcrlf
	mov	word ptr callst,offset callee
	mov	word ptr callst+2,seg callee
	mov	si,offset callst
	mov	dx,hnd
	ems	5600h
	CHECK	'alter map and call (5600h)', e
	cmp	calls,1
	CHECK	'called with the new map', e
	mov	al,0
	mov	bx,0
	call	csig
	jne	@F
	mov	al,1
	mov	bx,1
	call	csig
@@:	CHECK	'old map after the return', e
	mov	si,offset jmpst
	mov	dx,hnd
	ems	5500h
	stc			; not reached when the jump works
	jmp	jmpres
jmptgt:	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	mov	al,0
	mov	bx,7
	mov	dx,hnd
	call	csig
	clc
	je	jmpres
	stc
jmpres:	CHECK	'alter map and jump (5500h)', nc

	TITLE_	'move/exchange region'
	mov	eax,11223344h
	call	fillc
	mov	mvr.rlen,6000h	; conventional -> page 1 offset 2000h (crosses 2 pages)
	mov	mvr.stype,0
	mov	mvr.shnd,0
	mov	mvr.soff,offset cbuf1
	mov	mvr.sseg,ds
	mov	mvr.dtype,1
	mov	ax,hnd
	mov	mvr.dhnd,ax
	mov	mvr.doff,2000h
	mov	mvr.dseg,1
	mov	al,0
	call	movreg
	cmp	ah,0
	CHECK	'conventional -> EMS (5700h)', e
	mov	mvr.stype,1
	mov	ax,hnd
	mov	mvr.shnd,ax
	mov	mvr.soff,2000h
	mov	mvr.sseg,1
	mov	mvr.dtype,0
	mov	mvr.dhnd,0
	mov	mvr.doff,offset cbuf2
	mov	mvr.dseg,ds
	mov	al,0
	call	movreg
	cmp	ah,0
	CHECK	'EMS -> conventional', e
	mov	cx,6000h
	call	cmpc
	CHECK	'data equal', e
	; EMS -> EMS overlapping: page 1:2000h -> page 1:3000h, 6000h bytes
	mov	mvr.stype,1
	mov	mvr.dtype,1
	mov	ax,hnd
	mov	mvr.shnd,ax
	mov	mvr.dhnd,ax
	mov	mvr.soff,2000h
	mov	mvr.sseg,1
	mov	mvr.doff,3000h
	mov	mvr.dseg,1
	mov	al,0
	call	movreg
	cmp	ah,92h
	CHECK	'overlapping EMS -> EMS: 92h', e
	mov	mvr.dtype,0
	mov	mvr.dhnd,0
	mov	mvr.doff,offset cbuf2
	mov	mvr.dseg,ds
	mov	mvr.soff,3000h
	mov	al,0
	call	movreg
	mov	cx,6000h
	call	cmpc
	CHECK	'data moved correctly', e
	; exchange conventional <-> EMS page 4
	mov	eax,99887766h
	call	fillc
	mov	mvr.rlen,4000h
	mov	mvr.stype,0
	mov	mvr.shnd,0
	mov	mvr.soff,offset cbuf1
	mov	mvr.sseg,ds
	mov	mvr.dtype,1
	mov	ax,hnd
	mov	mvr.dhnd,ax
	mov	mvr.doff,0
	mov	mvr.dseg,4
	mov	al,1
	call	movreg
	cmp	ah,0
	CHECK	'exchange (5701h)', e
	mov	ax,word ptr cbuf1
	cmp	ax,4
	CHECK	'page 4 signature in conventional memory', e
	mov	al,0
	mov	bx,4
	call	mapp
	push	es
	mov	al,0
	call	physseg
	mov	eax,es:[0]
	pop	es
	cmp	eax,99887766h
	CHECK	'pattern in EMS page 4', e
	; conventional -> conventional
	mov	eax,5A5A0001h
	call	fillc
	mov	mvr.rlen,CBUF
	mov	mvr.stype,0
	mov	mvr.shnd,0
	mov	mvr.soff,offset cbuf1
	mov	mvr.sseg,ds
	mov	mvr.dtype,0
	mov	mvr.dhnd,0
	mov	mvr.doff,offset cbuf2
	mov	mvr.dseg,ds
	mov	al,0
	call	movreg
	mov	cx,CBUF
	call	cmpc
	CHECK	'conventional -> conventional', e

	TITLE_	'mappable pages, raw pages'
	ems	5801h
	NOTE_	'mappable pages (5801h) '
	mov	ax,cx
	call	phex16
	cmp	cx,4
	CHECK	' >= 4', ae
	mov	di,offset physa
	ems	5800h
	CHECK	'address array (5800h)', e
	; the frame segment must be in the array as physical page 0
	mov	si,offset physa
	mov	ax,frame
@@:	cmp	[si],ax
	je	fnd
	add	si,4
	loop	@B
	or	si,si		; ZF=0
	jmp	fnd1
fnd:	cmp	word ptr [si+2],0
fnd1:	CHECK	'frame = physical page 0', e
	ems	5901h
	CHECK	'raw pages (5901h)', e

	TITLE_	'alternate map register sets'
	ems	5B00h		; BL=0: ES:DI = save area (may be 0:0)
	push	ds
	pop	es
	CHECK	'get alternate map set (5B00h)', e
	mov	altset,bl
	NOTE_	'current set '
	mov	al,bl
	call	phex8
	call	pcrlf
	ems	5B02h
	NOTE_	'save area size (5B02h) '
	mov	ax,dx
	call	phex16
	call	pcrlf
	; set 0 with a context area (format of 4E00h): the EMM restores the
	; map from it
	mov	al,0
	mov	bx,0
	call	mapp
	mov	di,offset mapbuf
	ems	4E00h
	mov	al,0
	mov	bx,1
	call	mapp
	mov	di,offset mapbuf
	mov	bl,0
	ems	5B01h
	CHECK	'set 0 with context area (5B01h)', e
	mov	al,0
	mov	bx,0
	call	csig
	CHECK	'map restored from the save area', e
	ems	5B03h
	jne	noalt
	mov	altset,bl
	NOTE_	'allocated set (5B03h) '
	mov	al,bl
	call	phex8
	call	pcrlf
	mov	bl,altset
	ems	5B04h
	CHECK	'deallocate set (5B04h)', e
	jmp	altdone
noalt:	NOTE_	'5B03h: no alternate sets, status '
	mov	al,ah
	call	phex8
	call	pcrlf
altdone:
	mov	di,offset mapbuf
	xor	bx,bx
	mov	ax,5B01h
	int	67h		; back to set 0 without save area

	; a zeroed context area is no valid mapping: the EMM must refuse it
	; (A3h, as Jemm) or keep the mapping (MS EMM386) - not map page 0
	; everywhere, which overwrites conventional memory
	mov	al,0
	mov	bx,0
	call	mapp
	mov	di,offset mapbuf2
	mov	cx,1024/2
	xor	ax,ax
	rep	stosw
	push	ds
	push	0
	pop	ds
	mov	eax,ds:[21h*4]	; IVT: page 0 of conventional memory
	pop	ds
	mov	ivt21,eax
	mov	di,offset mapbuf2
	mov	bl,0
	ems	5B01h
	pushf
	NOTE_	'zeroed context area (5B01h): status '
	mov	al,ah
	call	phex8
	popf
	je	zacc
	cmp	al,al		; refused: fine
	jmp	zchk
zacc:	push	ds
	push	0
	pop	ds
	mov	eax,ds:[21h*4]
	pop	ds
	cmp	eax,ivt21	; conventional memory still in place?
	jne	zchk
	mov	al,0
	mov	bx,0
	call	csig		; accepted: the mapping must be the same
zchk:	CHECK	', refused or mapping kept', e
	xor	bx,bx
	mov	di,bx
	push	ds
	push	0
	pop	es
	mov	ax,5B01h	; back to set 0 without an area (ES:DI = 0:0)
	int	67h
	pop	es

	TITLE_	'deallocate'
	mov	dx,hnd
	ems	4500h
	CHECK	'deallocate (45h)', e
	mov	dx,hnd
	ems	4500h
	cmp	ah,83h
	CHECK	'second deallocate: 83h', e
	call	finish

	end	start

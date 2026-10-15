; VCPIFUNC.ASM - VCPI 1.0 functions of the active V86 monitor: presence,
; protected mode interface (DE01h), memory (DE02h-DE06h), CR0 and debug
; registers (DE07h-DE09h), 8259 vectors (DE0Ah/DE0Bh) and round trips
; V86 -> protected mode -> V86 (DE0Ch) with an own GDT, TSS and page
; tables; in protected mode a page allocated with DE04h is mapped, written
; and read back.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no VCPI.
; Build: jwasm -mz VCPIFUNC.ASM

	.model	small
	.386p
	.stack	1024

NROUNDS	equ	100		; mode switch round trips
PMLIN	equ	300000h		; linear address of the DE04h page in PM
NALLOC	equ	16
MARK	equ	49504356h	; 'VCPI'

DESC	struc
dlim	dw ?
dbase0	dw ?
dbase1	db ?
dacc	db ?
dlimf	db ?
dbase2	db ?
DESC	ends

SEL_CODE equ	08h
SEL_DATA equ	10h
SEL_TSS	equ	18h
SEL_FLAT equ	20h
SEL_VCPI equ	28h		; 3 descriptors filled by DE01h

	.data
gdt	DESC	<>
	DESC	<0FFFFh,0,0,9Ah,0,0>	; 16-bit code (our code segment)
	DESC	<0FFFFh,0,0,92h,0,0>	; 16-bit data (DGROUP, also stack)
	DESC	<103,0,0,89h,0,0>	; TSS
	DESC	<0FFFFh,0,0,92h,0CFh,0>	; flat data 4 GB
	DESC	3 dup (<>)		; VCPI
GDTSIZE	equ	$-gdt
gdtr	dw	GDTSIZE-1
	dd	?
idtr	dw	0
	dd	0
sw	dd	?	; CR3
	dd	?	; linear address of gdtr
	dd	?	; linear address of idtr
	dw	0	; LDTR
	dw	SEL_TSS	; TR
	dd	?	; EIP
	dw	SEL_CODE ; CS
vcpient	dd	?	; entry offset
	dw	SEL_VCPI
tss	db	104 dup (0)
ptlin	dd	?	; linear address of the page directory (4 KB aligned)
ptseg	dw	?	; segment of the page directory
pdphys	dd	?
pgphys	dd	?	; DE04h page used in PM
rmsp	dw	?
rmss	dw	?
rounds	dw	0
pmcr0	dd	?
pmval	dd	?
pmbad	dw	0
marker	dd	0
lmarker	dd	?
linsw	dd	?	; linear address of sw
pages	dd	NALLOC dup (?)
dregs	dd	8 dup (?)

	.data?
pmstk	db	512 dup (?)
pmstktop label	byte

	.code
	include	TESTLIB.INC

vcpi	macro	fn
	mov	ax,fn
	int	67h
	cmp	ah,0
	endm

; base of descriptor [di] = eax
setbase	proc
	mov	[di].DESC.dbase0,ax
	ror	eax,16
	mov	[di].DESC.dbase1,al
	mov	[di].DESC.dbase2,ah
	ror	eax,16
	ret
setbase	endp

cmosrd	proc			; al = CMOS register -> al
	cli
	out	70h,al
	jmp	$+2
	in	al,71h
	sti
	ret
cmosrd	endp

start:
	mov	ax,@data
	mov	ds,ax
	; keep only PSP .. end of stack
	mov	bx,ss
	mov	ax,es
	sub	bx,ax
	mov	ax,sp
	shr	ax,4
	inc	ax
	add	bx,ax
	mov	ah,4Ah
	int	21h
	push	ds
	pop	es

	; VCPI present?  (EMM with DE00h)
	push	ds
	xor	ax,ax
	mov	ds,ax
	mov	eax,ds:[67h*4]
	pop	ds
	or	eax,eax
	jz	novcpi
	vcpi	0DE00h
	je	@F
novcpi:	INFO	'no VCPI server'
	mov	ax,4C02h
	int	21h
@@:
	TITLE_	'presence, memory'
	NOTE_	'VCPI version '
	mov	ax,bx
	call	phex16
	cmp	bx,0100h
	CHECK	' >= 1.0 (DE00h)', ae
	vcpi	0DE02h
	NOTE_	'highest page address '
	mov	eax,edx
	call	phex32
	cmp	edx,0FF000h
	CHECK	' (DE02h) >= FF000h', ae
	; the address of the highest page lies below the top of RAM (CMOS
	; 34h/35h: 64 KB blocks above 16 MB, 30h/31h: KB above 1 MB; INT 15h
	; E801h is no use: memory managers hide their memory there)
	; spec: "physical address of highest 4K memory page"
	mov	al,35h
	call	cmosrd
	mov	ah,al
	mov	al,34h
	call	cmosrd
	movzx	eax,ax
	shl	eax,16
	add	eax,1000000h
	cmp	eax,1000000h
	jne	@F
	mov	al,31h
	call	cmosrd
	mov	ah,al
	mov	al,30h
	call	cmosrd
	movzx	eax,ax
	shl	eax,10
	add	eax,100000h
@@:	NOTE_	'top of RAM (CMOS) '
	call	phex32
	cmp	edx,eax
	CHECK	', highest page below it', b
	vcpi	0DE03h
	NOTE_	'free pages '
	mov	eax,edx
	call	phex32
	mov	ebp,edx
	cmp	edx,NALLOC+1
	CHECK	' (DE03h) enough', ae
	; allocate NALLOC pages: distinct, aligned, counted
	xor	si,si
	xor	cx,cx
@@:	vcpi	0DE04h
	jne	al1
	mov	pages[si],edx
	test	dx,0FFFh
	jnz	al1
	add	si,4
	inc	cx
	cmp	cx,NALLOC
	jb	@B
al1:	cmp	cx,NALLOC
	CHECK	'allocate 16 pages (DE04h), 4 KB aligned', e
	vcpi	0DE03h
	lea	eax,[ebp-NALLOC]
	cmp	edx,eax
	CHECK	'free count 16 lower', e
	; distinct?
	xor	si,si
	xor	bx,bx
dl1:	mov	eax,pages[si]
	lea	di,[si+4]
dl2:	cmp	di,NALLOC*4
	jae	dl3
	cmp	eax,pages[di]
	jne	@F
	inc	bx
@@:	add	di,4
	jmp	dl2
dl3:	add	si,4
	cmp	si,NALLOC*4
	jb	dl1
	cmp	bx,0
	CHECK	'pages distinct', e
	mov	eax,pages
	mov	pgphys,eax	; keep page 0 for the PM test
	mov	si,4
	xor	bx,bx
@@:	mov	edx,pages[si]
	vcpi	0DE05h
	je	fr1
	inc	bx
fr1:	add	si,4
	cmp	si,NALLOC*4
	jb	@B
	cmp	bx,0
	CHECK	'free 15 pages (DE05h)', e
	vcpi	0DE03h
	lea	eax,[ebp-1]
	cmp	edx,eax
	CHECK	'free count back (one kept)', e

	TITLE_	'first megabyte, registers'
	mov	cx,0B8h
	vcpi	0DE06h
	NOTE_	'physical address of page B8h '
	mov	eax,edx
	call	phex32
	and	edx,0FFFFF000h
	cmp	edx,0B8000h
	CHECK	' (DE06h) = B8000h', e
	mov	cx,100h
	vcpi	0DE06h
	cmp	ah,8Bh
	CHECK	'page 100h refused: 8Bh', e
	vcpi	0DE07h
	NOTE_	'CR0 '
	mov	eax,ebx
	call	phex32
	and	ebx,80000001h
	cmp	ebx,80000001h
	CHECK	' (DE07h) PE and PG', e
	mov	di,offset dregs
	vcpi	0DE08h
	CHECK	'read debug registers (DE08h)', e
	mov	di,offset dregs
	vcpi	0DE09h
	CHECK	'write debug registers (DE09h)', e
	vcpi	0DE0Ah
	NOTE_	'8259 vectors master/slave '
	mov	ax,bx
	call	phex16
	NOTE_	'/'
	mov	ax,cx
	call	phex16
	call	pcrlf
	push	bx
	push	cx
	vcpi	0DE0Ah
	pop	cx
	pop	bx
	vcpi	0DE0Bh
	CHECK	'set 8259 vectors to the same values (DE0Bh)', e

	TITLE_	'mode switch'
	; page directory and table 0: 4 KB aligned in a DOS block
	mov	bx,300h
	mov	ah,48h
	int	21h
	jnc	@F
	INFO	'no memory for the page tables'
	jmp	done
@@:	movzx	eax,ax
	shl	eax,4
	add	eax,0FFFh
	and	eax,0FFFFF000h
	mov	ptlin,eax
	shr	eax,4
	mov	ptseg,ax
	mov	es,ax		; clear directory and table
	xor	di,di
	xor	eax,eax
	mov	cx,2000h/4
	cld
	rep	stosd
	; DE01h: table 0 at ES:1000h, the 3 descriptors at DS:gdt+SEL_VCPI
	mov	di,1000h
	mov	si,offset gdt+SEL_VCPI
	vcpi	0DE01h
	push	ds
	pop	es
	CHECK	'protected mode interface (DE01h)', e
	mov	vcpient,ebx
	sub	di,1000h
	NOTE_	'entry '
	mov	eax,ebx
	call	phex32
	NOTE_	', table entries filled '
	mov	ax,di
	shr	ax,2
	call	phex16
	call	pcrlf
	cmp	di,100h*4
	CHECK	'first megabyte in the table', ae
	; physical addresses of directory and table
	mov	ecx,ptlin
	shr	ecx,12
	vcpi	0DE06h
	CHECK	'physical address of the page directory (DE06h)', e
	and	edx,0FFFFF000h
	mov	pdphys,edx
	NOTE_	'directory linear/physical '
	mov	eax,ptlin
	call	phex32
	NOTE_	'/'
	mov	eax,edx
	call	phex32
	call	pcrlf
	inc	cx
	vcpi	0DE06h
	and	edx,0FFFFF000h
	mov	es,ptseg
	or	dl,7
	mov	es:[0],edx		; PDE 0
	mov	edx,pgphys
	or	dl,3
	mov	es:[1000h+(PMLIN shr 12)*4],edx	; the DE04h page at PMLIN
	push	ds
	pop	es
	; descriptors and tables
	mov	ax,cs
	movzx	eax,ax
	shl	eax,4
	mov	di,offset gdt+SEL_CODE
	call	setbase
	mov	ax,ds
	movzx	eax,ax
	shl	eax,4
	mov	ebx,eax
	mov	di,offset gdt+SEL_DATA
	call	setbase
	lea	eax,[ebx+offset tss]
	mov	di,offset gdt+SEL_TSS
	call	setbase
	lea	eax,[ebx+offset gdt]
	mov	dword ptr gdtr+2,eax
	lea	eax,[ebx+offset gdtr]
	mov	sw+4,eax
	lea	eax,[ebx+offset idtr]
	mov	sw+8,eax
	lea	eax,[ebx+offset marker]
	mov	lmarker,eax
	mov	eax,pdphys
	mov	sw,eax
	mov	dword ptr sw+10h,offset pmentry
	lea	eax,[ebx+offset sw]
	mov	linsw,eax
	mov	rmss,ss

roundtrip:
	mov	rmsp,sp
	mov	gdt[SEL_TSS].DESC.dacc,89h	; LTR marks it busy each time
	cli
	mov	esi,linsw	; registers other than SS:ESP and the segment
	mov	ax,0DE0Ch	; registers are undefined after each switch
	int	67h		; returns only on errors
	sti
	NOTE_	'DE0Ch failed, ah='
	mov	al,ah
	call	phex8
	call	pcrlf
	stc
	jmp	swres

pmentry:			; protected mode, CPL 0, interrupts off
	mov	ax,SEL_DATA
	mov	ds,ax
	mov	es,ax
	mov	ss,ax
	mov	esp,offset pmstktop
	mov	ax,SEL_FLAT
	mov	fs,ax
	mov	eax,cr0
	mov	pmcr0,eax
	mov	eax,0C0DE0000h
	add	ax,rounds
	mov	ebx,PMLIN
	mov	fs:[ebx],eax	; the DE04h page
	cmp	fs:[ebx],eax
	je	@F
	inc	pmbad
@@:	mov	ebx,lmarker		; our data through the flat selector
	mov	dword ptr fs:[ebx],MARK
	inc	rounds
	; back to V86: GS FS DS ES SS ESP EFLAGS CS EIP (dwords), call the server
	xor	eax,eax
	mov	ax,@data
	push	eax		; GS
	push	eax		; FS
	push	eax		; DS
	push	eax		; ES
	movzx	eax,rmss
	push	eax		; SS
	movzx	eax,rmsp
	push	eax		; ESP
	pushfd			; EFLAGS (reserved)
	mov	ax,_TEXT
	push	eax		; CS
	pushd	offset backv86	; EIP
	; servers (Jemm, 386MAX) address their data through DS: flat DS as
	; the clients of the time had it
	mov	ax,SEL_FLAT
	mov	ds,ax
	mov	ax,0DE0Ch
	call	fword ptr ss:vcpient

backv86:			; V86 again
	mov	ax,@data
	mov	ds,ax
	mov	es,ax
	sti
	cmp	rounds,NROUNDS
	jb	roundtrip
	clc
swres:	CHECK	'100 round trips V86 -> PM -> V86 (DE0Ch)', nc
	jc	swdone
	cmp	pmbad,0
	CHECK	'DE04h page written and read in PM', e
	mov	eax,pmcr0
	NOTE_	'CR0 in PM '
	call	phex32
	and	eax,80000001h
	cmp	eax,80000001h
	CHECK	' PE and PG', e
	cmp	marker,MARK
	CHECK	'PM write to our data seen in V86', e
	mov	ax,sp
	cmp	ax,rmsp
	CHECK	'stack pointer restored', e
	; timer interrupts still running?
	push	es
	push	40h
	pop	es
	mov	eax,es:[6Ch]
	mov	ecx,10000000h
@@:	cmp	eax,es:[6Ch]
	jne	@F
	dec	ecx
	jnz	@B
@@:	pop	es
	or	ecx,ecx
	CHECK	'timer ticks after the switches', nz
swdone:
	mov	edx,pgphys
	vcpi	0DE05h
	CHECK	'free the last page (DE05h)', e
done:	call	finish

	end	start

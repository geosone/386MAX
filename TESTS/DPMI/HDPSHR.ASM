; HDPSHR.ASM - shared client context (HDPMI API function 5, BL=0), the
; way VSBHDA uses it:  a resident 32-bit client traps ports and hooks a
; protected mode interrupt, then a program started from real mode
; (here:  this program again, through INT 31h 0300h INT 21h 4B00h with
; the argument C) enters protected mode as a nested client.  The child
; must see the parent's INT 60h handler and port trap, and it leaves a
; memory block and selectors allocated.  Afterwards the parent's vector,
; memory and LDT must be as before, the child's selectors freed.
; Open 386MAX answers "HDPMI" unless "386MAX" AX=0200h BL=0 hid it.
; The 32-bit clients stay in a 16-bit code segment.
; Errorlevel 0 = all OK, 1 = a check failed, 2 = no 32-bit DPMI host.
; Build: jwasm -mz HDPSHR.ASM

	.model	small
	.386
	.stack	2048

RMREGS	struc
r_edi	dd ?
r_esi	dd ?
r_ebp	dd ?
	dd ?
r_ebx	dd ?
r_edx	dd ?
r_ecx	dd ?
r_eax	dd ?
r_flags	dw ?
r_es	dw ?
r_ds	dw ?
r_fs	dw ?
r_gs	dw ?
r_ip	dw ?
r_cs	dw ?
r_sp	dw ?
r_ss	dw ?
RMREGS	ends

	.data
entry	dd	?
child	db	0			; 1 = started with the argument C
rmds	dw	?			; real mode segment of the data
maxapi	df	0			; '386MAX' vendor API (0 = none)
hdpapi	df	0
oldname	db	1			; "HDPMI" answered before the test			; 'HDPMI' vendor API
nmax	db	'386MAX',0
nhdp	db	'HDPMI',0
procs	dd	offset inproc		; TRAPPROCS
	dw	?
	dd	offset inproc
	dw	?
htrap	dd	0
oldsep	db	?
old60	df	?			; PM INT 60h before
oldrm60	dd	?			; RM INT 60h before
rm	RMREGS	<>
path	db	80 dup (0)		; this program
tail	db	2,' C',13		; command tail for the child
pblock	dw	0			; EXEC block:  environment (inherit)
	dw	offset tail,?		; command tail
	dd	-1,-1			; FCBs (none)
iretop	db	0CFh			; IRET for RM INT 60h
s1	dw	?			; a free selector before the child
memh	dd	?			; our memory block:  handle
meml	dd	?			; ...		     linear address
memsel	dw	?
el	db	?			; the child's errorlevel
r60	dd	?
mnodpmi	db	'no 32-bit DPMI host',13,10,'$'
	.code
	include	TESTLIB.INC

dsel	dw	?			; data alias of CS
n60	dw	0			; INT 60h handler calls
nin	dw	0			; IN handler calls

; PM INT 60h of the parent:  EAX = 'HDP!'
int60	proc	far
	push	ds
	mov	ds,cs:dsel
	inc	n60
	pop	ds
	mov	eax,'HDP!'
	iretd
int60	endp

; IN/OUT handler of the parent:  AL = 0A5h, EIP past the instruction
inproc	proc	far
	push	ds
	mov	ds,cs:dsel
	inc	nin
	pop	ds
	mov	al,0A5h
	push	eax
	mov	eax,[esp+4+8]		; error code
	and	eax,7			; instruction length
	add	[esp+4+12],eax		; EIP past the instruction
	pop	eax
	db	66h
	retf
inproc	endp

vendor	proc			; 168Ah for DS:SI, CF=0 and ES:EDI if found
	movzx	esi,si
	mov	ax,168Ah
	int	2Fh
	cmp	al,0
	je	@F
	stc
	ret
@@:	clc
	ret
vendor	endp

hdp	proc
	call	[hdpapi]
	ret
hdp	endp

ds2es	proc
	push	ds
	pop	es
	ret
ds2es	endp

; INT 31h 0300h INT 21h with rm.r_eax etc. set, CF from the real mode call
rm21	proc
	mov	rm.r_ss,0
	mov	rm.r_sp,0
	mov	rm.r_flags,0
	call	ds2es
	mov	edi,offset rm
	mov	ax,0300h
	mov	bx,21h
	xor	cx,cx
	int	31h
	jc	@F
	test	rm.r_flags,1
	jz	@F
	stc
@@:	ret
rm21	endp

start:
	mov	ax,@data
	mov	ds,ax
	mov	rmds,ax
	mov	pblock+4,ax		; command tail segment
	movzx	cx,byte ptr es:[80h]	; argument C?
	mov	di,81h
	jcxz	cnone
	mov	al,'C'
	repne	scasb
	jne	cnone
	mov	child,1
cnone:	; this program's path from the environment
	push	es
	mov	es,es:[2Ch]
	xor	di,di
	xor	al,al
	mov	cx,-1
@@:	repne	scasb			; end of a string
	scasb				; end of the environment?
	jne	@B
	add	di,2			; skip the count
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
	cmp	child,0
	jne	runchild
	mov	ax,000Ah		; data alias of CS
	mov	bx,cs
	int	31h
	mov	es,ax
	mov	es:dsel,ax
	call	ds2es
	mov	word ptr procs+4,cs
	mov	word ptr procs+10,cs

	mov	si,offset nmax		; Open 386MAX:  answer "HDPMI"
	call	vendor
	jc	@F
	mov	dword ptr maxapi,edi
	mov	word ptr maxapi+4,es
	mov	ax,0200h
	mov	bl,1
	call	[maxapi]
	mov	oldname,al
@@:	call	ds2es
	mov	si,offset nhdp
	call	vendor
	jnc	@F
	call	ds2es
	INFO	'no HDPMI API:  skipped'
	jmp	done
@@:	mov	dword ptr hdpapi,edi
	mov	word ptr hdpapi+4,es
	call	ds2es
	cmp	dword ptr maxapi,0	; HDPMI's IOPL 3 variants have no 6-10
	jne	@F
	mov	ax,8
	xor	bx,bx
	mov	dx,21h
	call	hdp
	jnc	@F
	INFO	'functions 6-10 missing (IOPL 3 host):  skipped'
	jmp	done
@@:
	TITLE_	'parent:  resident state'
	mov	ax,0501h		; a memory block with a pattern
	xor	bx,bx
	mov	cx,1000h
	int	31h
	pushf
	CHECK	'0501h 4 KB', nc
	popf
	jc	done
	shl	esi,16
	mov	si,di
	mov	memh,esi
	shl	ebx,16
	mov	bx,cx
	mov	meml,ebx
	mov	ax,0000h
	mov	cx,1
	int	31h
	mov	memsel,ax
	mov	bx,ax
	mov	cx,word ptr meml+2
	mov	dx,word ptr meml
	mov	ax,0007h
	int	31h
	mov	bx,memsel
	xor	cx,cx
	mov	dx,0FFFh
	mov	ax,0008h
	int	31h
	push	es
	mov	es,memsel
	mov	dword ptr es:[0],5AA51234h
	pop	es
	mov	ax,0000h		; a free selector, given back
	mov	cx,1
	int	31h
	mov	s1,ax
	mov	bx,ax
	mov	ax,0001h
	int	31h
	mov	ax,6			; trap 300h-30Fh
	mov	dx,300h
	mov	cx,10h
	mov	esi,offset procs
	call	hdp
	mov	htrap,eax
	CHECK	'6:  trap 300h-30Fh', nc
	mov	ax,5			; shared contexts
	mov	bl,0
	call	hdp
	mov	oldsep,al
	CHECK	'5:  BL=0 (shared contexts)', nc
	mov	ax,0204h		; PM INT 60h := ours
	mov	bl,60h
	int	31h
	mov	dword ptr old60,edx
	mov	word ptr old60+4,cx
	mov	ax,0205h
	mov	bl,60h
	mov	cx,cs
	mov	edx,offset int60
	int	31h
	CHECK	'0205h INT 60h', nc
	mov	ax,0200h		; RM INT 60h := IRET (if not inherited)
	mov	bl,60h
	int	31h
	mov	word ptr oldrm60,dx
	mov	word ptr oldrm60+2,cx
	mov	ax,0201h
	mov	bl,60h
	mov	cx,rmds
	mov	dx,offset iretop
	int	31h

	TITLE_	'child (nested client, started from real mode)'
	call	tl_commit
	mov	rm.r_eax,4B00h		; EXEC this program with C
	mov	ax,rmds
	mov	rm.r_ds,ax
	mov	rm.r_es,ax
	mov	rm.r_edx,offset path
	mov	rm.r_ebx,offset pblock
	call	rm21
	CHECK	'EXEC', nc
	mov	rm.r_eax,4D00h
	call	rm21
	mov	al,byte ptr rm.r_eax
	mov	el,al

	TITLE_	'parent afterwards'
	cmp	el,0
	CHECK	'child:  errorlevel 0', e
	cmp	n60,1
	CHECK	'our INT 60h handler called by the child', e
	cmp	nin,1
	CHECK	'our IN handler called by the child', e
	mov	ax,0204h
	mov	bl,60h
	int	31h
	cmp	edx,offset int60
	jne	@F
	mov	ax,cs
	cmp	cx,ax
@@:	CHECK	'PM INT 60h is ours again', e
	mov	eax,0
	int	60h
	cmp	eax,'HDP!'
	CHECK	'... and works', e
	push	es
	mov	es,memsel
	cmp	dword ptr es:[0],5AA51234h
	pop	es
	CHECK	'our memory block unchanged', e
	mov	ax,0000h		; the child's selectors are free again
	mov	cx,1
	int	31h
	pushf
	cmp	ax,s1
	CHECK	'first free selector as before the child', e
	popf
	jc	@F
	mov	bx,ax
	mov	ax,0001h
	int	31h
@@:	mov	dx,300h			; our trap still works
	in	al,dx
	cmp	al,0A5h
	CHECK	'our trap still works', e

	mov	ax,0201h		; clean up
	mov	bl,60h
	mov	cx,word ptr oldrm60+2
	mov	dx,word ptr oldrm60
	int	31h
	mov	ax,0205h
	mov	bl,60h
	mov	cx,word ptr old60+4
	mov	edx,dword ptr old60
	int	31h
	mov	ax,5
	mov	bl,oldsep
	call	hdp
	mov	ax,7
	mov	edx,htrap
	call	hdp
	mov	esi,memh
	mov	di,si
	shr	esi,16
	mov	ax,0502h
	int	31h
	CHECK	'0502h our block (handle still valid)', nc
	mov	eax,dword ptr maxapi
	or	eax,eax
	jz	done
	mov	ax,0200h
	mov	bl,oldname		; as it was
	call	[maxapi]
done:	call	finish

; the child:  sees the parent's INT 60h and trap, leaves memory and
; selectors allocated
runchild:
	INFO	'(child)'

	mov	eax,0
	int	60h
	mov	r60,eax
	cmp	eax,'HDP!'
	CHECK	'INT 60h:  the parent''s handler', e
	mov	dx,302h
	mov	al,0
	in	al,dx
	cmp	al,0A5h
	CHECK	'IN 302h:  the parent''s trap handler', e
	mov	ax,0501h
	xor	bx,bx
	mov	cx,1000h
	int	31h
	CHECK	'0501h 4 KB (not freed)', nc
	mov	ax,0000h
	mov	cx,3
	int	31h
	CHECK	'0000h 3 selectors (not freed)', nc
	call	finish

	end	start

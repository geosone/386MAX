; PM26: 16-bit DPMI client; INT 25h/26h packet form for sectors 0-19 of C:
; NOT through the host's INT 25h/26h translation but through DPMI 0301h
; (call a real-mode stub "int 2xh; pop dx; retf") with the buffers in DOS
; memory:  read -> write back -> read again, compare.  Separates the host's
; V86 side / mode switches from its INT 25h/26h translation.  Before the
; fix of 440Dh in 386MAX the DOS 7 volume lock hung here (EDR, MS-DOS 7.1).
; Errorlevel 0 = same, 1 = differs or error, 2 = no DPMI.
; Build: jwasm -mz PM26.ASM
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

NSEC	equ	20
; DOS block layout (offsets)
O_STUB	equ	0		; int 2xh / pop dx / retf  (6 bytes)
O_PKT	equ	10h		; packet
O_BUF1	equ	20h
O_BUF2	equ	O_BUF1+NSEC*512
DOSLEN	equ	O_BUF2+NSEC*512

	.data
entry	dd ?
rm	RMREGS <>
dseg	dw ?
dsel	dw ?
msgok	db 'PM26: same',13,10,'$'
msgdif	db 'PM26: DIFFERS',13,10,'$'
msgerr	db 'PM26: error in step $'
stepc	db '0',13,10,'$'
msgnod	db 'PM26: no DPMI',13,10,'$'
	.code

; AL = 25h/26h, buffer offset in BX:  run the stub via 0301h; CF = error
rmdisk	proc
	push	es
	mov	es,dsel
	mov	byte ptr es:[O_STUB],0CDh
	mov	es:[O_STUB+1],al
	mov	byte ptr es:[O_STUB+2],5Ah	; pop dx
	mov	byte ptr es:[O_STUB+3],0CBh	; retf
	mov	dword ptr es:[O_PKT],0
	mov	word ptr es:[O_PKT+4],NSEC
	mov	word ptr es:[O_PKT+6],bx
	mov	ax,dseg
	mov	word ptr es:[O_PKT+8],ax
	pop	es
	mov	di,offset rm
	xor	eax,eax
	mov	cx,sizeof RMREGS/2
	push	di
	rep	stosw
	pop	di
	mov	rm.r_eax,2
	mov	rm.r_ecx,0FFFFh
	mov	rm.r_ebx,O_PKT
	mov	ax,dseg
	mov	rm.r_ds,ax
	mov	rm.r_cs,ax
	mov	rm.r_ip,O_STUB
	mov	ax,0301h
	xor	bx,bx
	xor	cx,cx
	int	31h
	jc	@F
	bt	rm.r_flags,0
@@:	ret
rmdisk	endp

start:	mov	ax,@data
	mov	ds,ax
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
	mov	word ptr entry,di
	mov	word ptr entry+2,es
	or	si,si
	jz	@F
	mov	bx,si
	mov	ah,48h
	int	21h
	jc	nodpmi
	mov	es,ax
@@:	xor	ax,ax
	call	entry
	jc	nodpmi
	push	ds
	pop	es
	mov	ax,0100h
	mov	bx,(DOSLEN+15)/16
	int	31h
	mov	stepc,'1'
	jc	err
	mov	dseg,ax
	mov	dsel,dx
	; DOS 7: volume lock
	mov	ah,30h
	int	21h
	cmp	al,7
	jb	@F
	mov	ax,440Dh
	mov	bx,0003h
	mov	cx,084Ah
	xor	dx,dx
	int	21h
@@:	mov	stepc,'2'
	mov	al,25h
	mov	bx,O_BUF1
	call	rmdisk
	jc	err
	mov	stepc,'3'
	mov	al,26h
	mov	bx,O_BUF1
	call	rmdisk
	jc	err
	mov	stepc,'4'
	mov	al,25h
	mov	bx,O_BUF2
	call	rmdisk
	jc	err
	mov	ah,30h
	int	21h
	cmp	al,7
	jb	@F
	mov	ax,440Dh
	mov	bx,0003h
	mov	cx,086Ah
	int	21h
@@:	push	ds
	mov	ds,dsel
	push	ds
	pop	es
	mov	si,O_BUF1
	mov	di,O_BUF2
	mov	cx,NSEC*512
	cld
	repe	cmpsb
	pop	ds
	mov	dx,offset msgok
	mov	al,0
	je	@F
	mov	dx,offset msgdif
	mov	al,1
@@:	push	ax
	mov	ah,9
	int	21h
	pop	ax
	mov	ah,4Ch
	int	21h
err:	mov	dx,offset msgerr
	mov	ah,9
	int	21h
	mov	dx,offset stepc
	mov	ah,9
	int	21h
	mov	ax,4C01h
	int	21h
nodpmi:	mov	dx,offset msgnod
	mov	ah,9
	int	21h
	mov	ax,4C02h
	int	21h
	end	start

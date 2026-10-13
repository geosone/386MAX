; TOOLHELP interrupt callback of FAULTLOG.EXE (linux/test/faultlog).
; Called through MakeProcInstance (AX = our DGROUP) with this frame:
;   SP+0 return IP, +2 return CS (TOOLHELP), +4 AX, +6 exception number,
;   +8 handle, +10 faulting IP, +12 faulting CS, +14 flags
; Calls FaultLog(num, ip, cs) (pascal) and passes the fault on (RETF).
	.286
	extrn	FAULTLOG:far

FLTHND_TEXT segment word public 'CODE'
	assume	cs:FLTHND_TEXT

	public	FAULTHANDLER
FAULTHANDLER proc far
	push	bp
	mov	bp,sp
	pusha
	push	ds
	push	es
	mov	ds,ax			; our DGROUP (instance thunk)
	push	word ptr [bp+8]		; exception number
	push	word ptr [bp+12]	; IP
	push	word ptr [bp+14]	; CS
	call	FAULTLOG		; pascal: pops its arguments
	pop	es
	pop	ds
	popa
	mov	ax,[bp+6]		; the faulting program's AX
	pop	bp
	retf				; not handled: on to the next handler
FAULTHANDLER endp

FLTHND_TEXT ends
	end

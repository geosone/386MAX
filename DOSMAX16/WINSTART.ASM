;
; WINSTART.ASM - start-up of a Windows 3.x program without C run time
;
; Open 386MAX - GNU General Public License version 3.
;
; Entry point of SETEWV.EXE: starts the task like the start-up code of the
; C compilers (InitTask, WaitEvent, InitApp), calls WINMAIN (near, Pascal
; convention: hInstance, hPrevInstance, lpCmdLine, nCmdShow) and ends the
; program with its return value.  DGROUP begins with the 16 bytes that
; Windows reserves at the start of the automatic data segment.
;
	.286

DGROUP	group	NULL,_DATA

NULL	segment para public 'BEGDATA'   ; first in DGROUP
	dw	0,0		; reserved for Windows
	dw	5		; number of the following reserved words
	dw	5 dup (0)	; pLocalHeap, pAtomTable, pStackTop, ... (InitTask)
NULL	ends

_DATA	segment word public 'DATA'
_DATA	ends

	extrn	INITTASK:far, WAITEVENT:far, INITAPP:far

_TEXT	segment word public 'CODE'
	assume	cs:_TEXT, ds:DGROUP, ss:DGROUP

	extrn	WINMAIN:near

	public	__astart
__astart proc	far
	xor	bp,bp		; end of the BP chain
	push	bp
	call	INITTASK	; AX=1 ok, DI=hInstance, SI=hPrevInstance,
	or	ax,ax		; ES:BX=command line, DX=nCmdShow
	jz	short fail
	push	di		; hInstance        (WinMain arguments)
	push	si		; hPrevInstance
	push	es		; lpCmdLine
	push	bx
	push	dx		; nCmdShow
	push	di		; hInstance        (InitApp argument)
	xor	ax,ax
	push	ax
	call	WAITEVENT	; WaitEvent(0)
	call	INITAPP 	; InitApp(hInstance)
	or	ax,ax
	jz	short fail
	call	WINMAIN 	; WinMain(...) (removes its arguments)
	mov	ah,4Ch		; end with its return value
	int	21h
fail:
	mov	ax,4CFFh
	int	21h
__astart endp

_TEXT	ends

	end	__astart

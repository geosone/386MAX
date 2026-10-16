; TESTLIB.INC - output and result counting for the real-mode tests in TESTS
;
; Include after .model/.stack and the .data of the test.  The test calls
;   TITLE_ "text"         heading
;   CHECK  "text", cond   OK when the flags (after a cmp/test) satisfy cond
;                         (z, nz, c, nc, e, ne, ...), otherwise FAIL
;   INFO   "text"         a line without result
;   NOTE_  "text"         text without new line
;   call   phex16 / phex8 / phex32   (ax / al / eax)
;   call   finish          prints the summary and exits with
;                          errorlevel 0 (all OK) or 1 (any FAIL)
; and may call skip_all with dx -> '$' text to end with errorlevel 0
; when the service under test is missing (the runner reports SKIP through
; the list's needs= instead).

	.data
tl_nok	dw 0
tl_nfail dw 0
tl_ok	db ' OK',13,10,'$'
tl_fail db ' FAIL',13,10,'$'
tl_sum1 db 13,10,'OK: $'
tl_sum2 db '  FAIL: $'
tl_crlf db 13,10,'$'
tl_hex	db '0123456789ABCDEF'

	.code
; dx -> '$' string
pstr	proc
	push	ax
	mov	ah,9
	int	21h
	pop	ax
	ret
pstr	endp

pchar	proc			; al
	push	ax
	push	dx
	mov	dl,al
	mov	ah,2
	int	21h
	pop	dx
	pop	ax
	ret
pchar	endp

phex4	proc			; low nibble of al
	push	ax
	push	bx
	and	al,0Fh
	mov	bx,offset tl_hex
	xlat
	call	pchar
	pop	bx
	pop	ax
	ret
phex4	endp

phex8	proc
	push	ax
	push	ax
	shr	al,4
	call	phex4
	pop	ax
	call	phex4
	pop	ax
	ret
phex8	endp

phex16	proc
	xchg	al,ah
	call	phex8
	xchg	al,ah
	call	phex8
	ret
phex16	endp

phex32	proc
	ror	eax,16
	call	phex16
	ror	eax,16
	call	phex16
	ret
phex32	endp

pcrlf	proc
	push	dx
	mov	dx,offset tl_crlf
	call	pstr
	pop	dx
	call	tl_commit
	ret
pcrlf	endp

; commit stdout (INT 21h AH=68h) so that the output of a test that resets
; the machine is on the disk; harmless when stdout is the console
tl_commit proc
	push	ax
	push	bx
	mov	ah,68h
	mov	bx,1
	int	21h
	pop	bx
	pop	ax
	ret
tl_commit endp

; result after the text: carry clear = OK
tl_result proc
	pushf
	push	dx
	jc	@F
	inc	tl_nok
	mov	dx,offset tl_ok
	jmp	tl_r1
@@:	inc	tl_nfail
	mov	dx,offset tl_fail
tl_r1:	call	pstr
	call	tl_commit
	pop	dx
	popf
	ret
tl_result endp

finish	proc
	mov	dx,offset tl_sum1
	call	pstr
	mov	ax,tl_nok
	call	phex16
	mov	dx,offset tl_sum2
	call	pstr
	mov	ax,tl_nfail
	call	phex16
	call	pcrlf
	mov	ax,4C00h
	cmp	tl_nfail,0
	je	@F
	mov	al,1
@@:	int	21h
finish	endp

skip_all proc
	call	pstr
	call	pcrlf
	mov	ax,4C00h
	int	21h
skip_all endp

; text output; the string goes into _DATA
TLSTR	macro	text:vararg
	local	s
	.data
s	db	text,'$'
	.code
	exitm	<offset s>
	endm

NOTE_	macro	text:vararg
	push	dx
	mov	dx,TLSTR(text)
	call	pstr
	pop	dx
	endm

INFO	macro	text:vararg
	NOTE_	text,13,10
	endm

TITLE_	macro	text:vararg
	NOTE_	13,10,'== ',text,13,10
	endm

; CHECK "text", cond: the flags of the preceding compare decide; registers
; and flags are kept
CHECK	macro	text, cond
	local	ok, done
	pushf
	NOTE_	text
	popf
	j&cond	ok
	stc
	jmp	done
ok:	clc
done:	call	tl_result
	endm


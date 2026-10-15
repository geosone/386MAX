; MAXVIEWT.COM -- Open MaxView backend API conformance probe.
;
; SPDX-License-Identifier: GPL-3.0-only

.286
.model tiny
.code

	 include MAXVIEW.INC

	 org	 100h

START:
	 push	 cs
	 pop	 ds

; Obtain the QPI entry point.  Clear ES:DI first because other multiplex
; handlers are allowed to leave an unsupported request unchanged.

	 xor	 di,di
	 mov	 es,di
	 mov	 ax,1684h
	 mov	 bx,4354h
	 int	 2Fh
	 mov	 ax,es
	 or	 ax,di
	 jz	 short NO_API
	 mov	 word ptr QPI_ENTRY,di
	 mov	 ax,es
	 mov	 word ptr QPI_ENTRY[2],ax

; Query and validate the 1.0 ABI without assuming future capabilities.

	 mov	 ax,@MV_API*256+@MV_QUERY
	 pushf
	 call	 dword ptr QPI_ENTRY
	 jc	 short BAD_API
	 cmp	 ax,@MV_ABI_VERSION
	 jne	 short BAD_API
	 cmp	 bx,@MV_SIGNATURE_1
	 jne	 short BAD_API
	 cmp	 cx,@MV_SIGNATURE_2
	 jne	 short BAD_API
	 test	 dx,@MVCAP_STATUS
	 jz	 short BAD_API

; ABI 1.0 has one active root context and does not claim multiple contexts.

	 mov	 ax,@MV_API*256+@MV_STATUS
	 pushf
	 call	 dword ptr QPI_ENTRY
	 jc	 short BAD_API
	 or	 ax,ax
	 jnz	 short BAD_API
	 cmp	 bx,@MV_ROOT_CONTEXT
	 jne	 short BAD_API
	 cmp	 cx,1
	 jne	 short BAD_API
	 cmp	 dx,1
	 jne	 short BAD_API

; Unknown functions have a defined failure result.

	 mov	 ax,@MV_API*256+0FFh
	 pushf
	 call	 dword ptr QPI_ENTRY
	 jnc	 short BAD_API
	 cmp	 ax,@MVERR_UNSUPPORTED
	 jne	 short BAD_API

	 mov	 dx,offset OK_MSG
	 mov	 ax,4C00h
	 jmp	 short PRINT_EXIT

NO_API:
	 mov	 dx,offset NO_MSG
	 mov	 ax,4C02h
	 jmp	 short PRINT_EXIT

BAD_API:
	 mov	 dx,offset BAD_MSG
	 mov	 ax,4C01h

PRINT_EXIT:
	 push	 ax
	 mov	 ah,09h
	 int	 21h
	 pop	 ax
	 int	 21h

QPI_ENTRY dd	 0
OK_MSG	 db	 'Open MaxView API 1.0: PASS',13,10,'$'
BAD_MSG  db	 'Open MaxView API 1.0: FAIL',13,10,'$'
NO_MSG	 db	 'Open MaxView API: not present',13,10,'$'

	 end	 START


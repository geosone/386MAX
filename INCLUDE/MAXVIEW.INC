;' $Header$
; Open MaxView extension to the Open 386MAX QPI entry point.
;
; This file is part of Open 386MAX and is distributed under GPL-3.0.

; AH selects the private function group.  AL selects a subfunction.
@MV_API                 equ     4Dh
@MV_QUERY               equ     00h
@MV_STATUS              equ     01h

; ABI 1.0 identification returned by AX=4D00h.
@MV_ABI_VERSION         equ     0100h
@MV_SIGNATURE_1         equ     4D56h   ; BH:BL = "MV"
@MV_SIGNATURE_2         equ     4D58h   ; CH:CL = "MX"

; Capability bits returned in DX.  Only status/root-context discovery is
; implemented by this first ABI revision.  The remaining bits are reserved
; for the VM backend and must remain clear until their complete contracts are
; implemented.
@MVCAP_STATUS           equ     0001h
@MVCAP_CONTEXT_LIFE     equ     0002h
@MVCAP_PAGE_MAP         equ     0004h
@MVCAP_STATE            equ     0008h
@MVCAP_VIDEO_IO         equ     0010h
@MVCAP_INTERRUPT        equ     0020h
@MVCAP_PRIORITY         equ     0040h
@MVCAP_SCHED_RETURN     equ     0080h
@MV_CAPABILITIES        equ     @MVCAP_STATUS

@MV_ROOT_CONTEXT        equ     0001h
@MVERR_UNSUPPORTED      equ     0001h


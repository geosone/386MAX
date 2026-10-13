;
; WINDOWS.INC - Windows 3.x names for assembler modules
;
; Open 386MAX - GNU General Public License version 3.
;
; Only what the 386MAX sources use (GOAHEAD); the values are those of the
; Windows 3.1 API (see OpenWatcom's windows.h).
;

NULL		equ	0
FALSE		equ	0
TRUE		equ	1

; GetWinFlags
WF_CPU386	equ	0004h
WF_WIN386	equ	0020h		; 386 enhanced mode

; GlobalAlloc
GMEM_FIXED	equ	0000h
GMEM_ZEROINIT	equ	0040h
GPTR		equ	GMEM_FIXED or GMEM_ZEROINIT

; messages
WM_INITDIALOG	equ	0110h
WM_COMMAND	equ	0111h
WM_USER 	equ	0400h

; dialog box command IDs
IDOK		equ	1

; installable driver messages and DRV_CONFIGURE results
DRV_LOAD	equ	0001h
DRV_OPEN	equ	0003h
DRV_CLOSE	equ	0004h
DRV_FREE	equ	0006h
DRV_INSTALL	equ	0009h
DRV_REMOVE	equ	000Ah
DRVCNF_CANCEL	equ	0000h
DRVCNF_RESTART	equ	0002h

RECT	struc
rcleft	dw	?
rctop	dw	?
rcright dw	?
rcbottom dw	?
RECT	ends

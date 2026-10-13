	 title	 SHDMAP.ASM -- Write-Protected Shadow DRAM in C0000-EFFFF
	 page	 58,122
	 name	 SHDMAP

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2026 Open 386MAX.  GNU General Public License version 3.

Open 386MAX addition for MAXIMIZE (CHKRAM.C):  without 386MAX, MAXIMIZE
finds RAM in high DOS memory by writing to it, and protects what it finds
with RAM= in the profile.  The shadow DRAM a BIOS doesn't use is read from
DRAM but write-protected; where the chipset ignores the write protection
(QEMU/KVM) the write test finds it writable, and MAXIMIZE would protect
C0000-EFFFF.  The chipset registers tell the truth, as 386MAX itself reads
them (GET_SHDMAP in 386MAX\QMAX_MEM.ASM):

Intel host bridges:  PAM registers (one nibble per 16KB, bit 0 = read,
bit 1 = write enable, the low nibble of PAM1 is C0000-C3FFF)
  at 59h:  430FX/HX/VX/TX, 440FX/LX/BX/GX/ZX, 810
  at 90h:  845 to 4 Series (G45, Q35)
  at 80h:  2nd generation Core (Sandy Bridge) and later
AMD K8 and later:  fixed range MTRRs 268h-26Bh (one byte per 4KB,
  bit 4 = RdMem, bit 3 = WrMem, visible if SYSCFG.MtrrFixDramModEn),
  only in real mode (RDMSR faults in V86 mode).

unsigned shd_protmap (void);

Returns the 16KB blocks of C0000-EFFFF (bit 0 = C0000) which are read
from DRAM but write-protected; 0 if unknown.

|

.model large,c

.code
.386p

PAM59_TAB dw	 122Dh,1250h,7030h,7100h ; 430FX/HX/VX/TX
	 dw	 1237h,7180h,7190h,7192h ; 440FX/LX/BX/BX (AGP disabled)
	 dw	 71A0h,71A2h,84C4h,84CAh ; 440GX/GX, 450KX/GX
	 dw	 7120h,7122h,7124h,7194h ; 810/810-DC100/810E, 440MX
PAM59_CNT equ	 ($-PAM59_TAB)/2 ; # entries

PAM80_TAB db	 01h,0Ah,0Ch,0Dh,15h,16h,19h,1Fh ; SNB to SKL
	 db	 3Eh,59h,8Ah,9Ah,9Bh,4Ch,46h,0A7h ; KBL to RPL
	 db	 7Dh		; MTL/ARL
PAM80_CNT equ	 $-PAM80_TAB	; # entries

; Read a dword from the configuration space of the host bridge
; (bus 0, device 0, function 0) via configuration mechanism #1.
; On entry:  AL = register # (multiple of 4)
; On exit:   EAX = register value
PCI_RDCFG proc	 near
	 push	 dx		; Save register
	 and	 eax,0FCh	; Isolate the register #
	 or	 eax,80000000h	; Enable configuration cycle
	 mov	 dx,0CF8h	; Configuration address port
	 out	 dx,eax		; Select the register
	 mov	 dl,0FCh	; Configuration data port (0CFCh)
	 in	 eax,dx		; Read it
	 pop	 dx		; Restore
	 ret			; Return to caller
PCI_RDCFG endp

	 public  shd_protmap
shd_protmap proc far
	 push	 bp		; Save registers
	 push	 si		; ...
	 push	 di		; ...
	 xor	 di,di		; Initialize read  enable map
	 xor	 bp,bp		; ...	     write ...

; Configuration mechanism #1 via the PCI BIOS (Int 1Ah, AX=B101h)
	 mov	 ax,0B101h	; PCI BIOS present?
	 xor	 edi,edi	; (some BIOSes expect EDI=0)
	 int	 1Ah		; Return with EDX = 'PCI ', AL bit 0 = mech #1
	 jc	 near ptr SHD_EXIT ; Jump if not
	 cmp	 edx,20494350h	; 'PCI '?
	 jne	 near ptr SHD_EXIT ; Jump if not
	 test	 al,1		; Mechanism #1?
	 jz	 near ptr SHD_EXIT ; Jump if not

	 pushf			; Save interrupt flag
	 cli			; No interrupts during config cycles
	 mov	 al,00h 	; Vendor and device ID
	 call	 PCI_RDCFG	; Return with EAX = register
	 cmp	 ax,8086h	; Izit Intel?
	 je	 short SHD_INTEL ; Jump if so
	 cmp	 ax,1022h	; Izit AMD?
	 je	 near ptr SHD_AMD ; Jump if so
	 jmp	 SHD_DONE	; Unknown host bridge

SHD_INTEL:
	 shr	 eax,16 	; AX = device ID
	 lea	 si,PAM59_TAB	; CS:SI ==> device IDs with PAM at 59h
	 mov	 cx,PAM59_CNT	; # entries
@@:
	 cmp	 ax,cs:[si]	; Izit this one?
	 je	 short SHD_59	; Jump if so
	 add	 si,2		; Skip to next entry
	 loop	 @B		; Jump if more entries to check

	 cmp	 ax,1A30h	; 845?
	 je	 short SHD_90	; Jump if so
	 cmp	 ax,2550h	; 845E to 4 Series (Q35, G45)?
	 jb	 short @F	; Jump if not
	 cmp	 ax,2EFFh	; ...
	 jbe	 short SHD_90	; Jump if so
@@:
	 mov	 bx,ax		; Copy device ID
	 lea	 si,PAM80_TAB	; CS:SI ==> high bytes of device IDs (PAM at 80h)
	 mov	 cx,PAM80_CNT	; # entries
@@:
	 cmp	 bh,cs:[si]	; Izit this family?
	 je	 short SHD_80	; Jump if so
	 inc	 si		; Skip to next entry
	 loop	 @B		; Jump if more entries to check
	 jmp	 SHD_DONE	; Unknown Intel host bridge

SHD_59:
	 mov	 bl,59h 	; PAM0 register
	 jmp	 short SHD_PAM	; Join common code
SHD_90:
	 mov	 bl,90h 	; PAM0 register
	 jmp	 short SHD_PAM	; Join common code
SHD_80:
	 mov	 bl,80h 	; PAM0 register

; BL = PCI register of PAM0; PAM1 (C0000-C7FFF) to PAM6 (E8000-EFFFF)
; follow as six consecutive bytes.
SHD_PAM:
	 xor	 bh,bh		; Zero to use as word
	 inc	 bx		; Skip PAM0 (F0000-FFFFF)
	 xor	 dx,dx		; Bit # in maps (16KB blocks from C0000)
	 mov	 cx,6		; PAM1 to PAM6
SHD_PAMNEXT:
	 mov	 al,bl		; Copy register #
	 call	 PCI_RDCFG	; Return with EAX = dword
	 push	 cx		; Save for a moment
	 mov	 cl,bl		; Copy register #
	 and	 cl,3		; Byte # within dword
	 shl	 cl,3		; Times 8 to get bit shift
	 shr	 eax,cl 	; AL = PAM byte
	 pop	 cx		; Restore

	 mov	 ah,al		; Copy for high nibble
	 test	 al,1		; Low nibble's read enable?
	 jz	 short @F	; Jump if not
	 bts	 di,dx		; Mark as read from DRAM
@@:
	 test	 al,2		; Low nibble's write enable?
	 jz	 short @F	; Jump if not
	 bts	 bp,dx		; Mark as written to DRAM
@@:
	 inc	 dx		; Next 16KB block
	 test	 ah,10h 	; High nibble's read enable?
	 jz	 short @F	; Jump if not
	 bts	 di,dx		; Mark as read from DRAM
@@:
	 test	 ah,20h 	; High nibble's write enable?
	 jz	 short @F	; Jump if not
	 bts	 bp,dx		; Mark as written to DRAM
@@:
	 inc	 dx		; Next 16KB block
	 inc	 bx		; Next PAM register
	 loop	 SHD_PAMNEXT	; Jump if more PAM registers
	 jmp	 SHD_DONE	; Join common code

; AMD:	the fixed range MTRRs are valid only on family 0Fh and later; they
; can only be read in real mode (in V86 mode RDMSR faults)
SHD_AMD:
	 smsw	 ax		; Get machine status word
	 test	 ax,1		; Protected (V86) mode?
	 jnz	 near ptr SHD_DONE ; Jump if so

	 xor	 eax,eax	; Function 0:  vendor
	 db	 0Fh,0A2h	; CPUID:  EBX:EDX:ECX = vendor
	 cmp	 ebx,68747541h	; "AuthenticAMD"?
	 jne	 near ptr SHD_DONE ; Jump if not
	 cmp	 ecx,444D4163h	; ...
	 jne	 near ptr SHD_DONE ; Jump if not

	 mov	 eax,1		; Function 1:  family
	 db	 0Fh,0A2h	; CPUID:  EAX = signature
	 shr	 eax,8		; Family to low nibble
	 and	 al,0Fh 	; Isolate family
	 cmp	 al,0Fh 	; K8 or later?
	 jne	 near ptr SHD_DONE ; Jump if not

	 mov	 ecx,0C0010010h ; SYSCFG
	 db	 0Fh,32h	; RDMSR:  EDX:EAX
	 bt	 eax,18 	; MtrrFixDramEn?
	 jnc	 near ptr SHD_DONE ; Jump if not (RdMem/WrMem unused)

	 push	 edx		; Save SYSCFG
	 push	 eax		; ...
	 bts	 eax,19 	; Make RdMem/WrMem visible (MtrrFixDramModEn)
	 db	 0Fh,30h	; WRMSR

	 xor	 bx,bx		; Bit # in maps (16KB blocks from C0000)
	 mov	 ecx,268h	; C0000-C7FFF
SHD_MTRR:
	 db	 0Fh,32h	; RDMSR:  EDX:EAX = 8 bytes for 8 * 4KB
	 mov	 si,2		; Two 16KB blocks
SHD_MTRR0:
	 push	 eax		; Save for a moment
	 and	 eax,10101010h	; Isolate RdMem of the four 4KB pages
	 cmp	 eax,10101010h	; All set?
	 pop	 eax		; Restore
	 jne	 short @F	; Jump if not
	 bts	 di,bx		; Mark as read from DRAM
@@:
	 test	 eax,08080808h	; Any WrMem?
	 jz	 short @F	; Jump if not
	 bts	 bp,bx		; Mark as written to DRAM
@@:
	 inc	 bx		; Next 16KB block
	 mov	 eax,edx	; Next four 4KB pages
	 dec	 si		; One fewer block
	 jnz	 short SHD_MTRR0 ; Jump if more

	 inc	 ecx		; Next MTRR
	 cmp	 ecx,26Bh	; Through E8000-EFFFF?
	 jbe	 short SHD_MTRR ; Jump if more

	 mov	 ecx,0C0010010h ; SYSCFG
	 pop	 eax		; Restore original value
	 pop	 edx		; ...
	 db	 0Fh,30h	; WRMSR

SHD_DONE:
	 popf			; Restore interrupt flag
SHD_EXIT:
	 not	 bp		; Not write enabled
	 and	 di,bp		; Read from DRAM, write-protected
	 and	 di,0FFFh	; Only C0000-EFFFF
	 mov	 ax,di		; Return value
	 pop	 di		; Restore
	 pop	 si		; ...
	 pop	 bp		; ...
	 ret			; Return to caller
shd_protmap endp

	 end

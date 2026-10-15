	 title	 EMUDET.ASM -- Emulator Detection and Debug Console Log
	 page	 58,122
	 name	 EMUDET

COMMENT|		Module Specifications

Copyright:  (C) Copyright 2026 Open 386MAX.  GNU General Public License version 3.

Open 386MAX addition for MAXIMIZE:  for the development tests in emulators.

int emu_detect (char far *name);

Returns the kind of machine and copies its name (at most 15 characters and
a NUL) to name:
  0  no emulator found (real hardware, or one that looks like it: 86Box
     emulates real chipsets and BIOSes)
  1  QEMU with TCG     2  QEMU with KVM     3  VirtualBox
  4  VMware            5  Hyper-V           6  Bochs
  7  another hypervisor (its CPUID signature is the name)
CPUID leaf 40000000h is asked only when CPUID 1 reports a hypervisor
(ECX bit 31); without one, the BIOS ROM F000:0000-FFFF is searched for
"Bochs" and "VirtualBox" (read only: no port is touched).

int dbg_avail (void);
void dbg_puts (char far *text);

The debug console of Bochs and QEMU (-debugcon, 86Box: "port E9 hack")
returns E9h when port E9h is read; dbg_puts writes the text there, and
nothing when the port reads anything else (real hardware).

|

.model large,c

.data
EMU_TAB	 db	 'TCGTCGTCGTCG',1,'QEMU TCG',0
	 db	 'KVMKVMKVM',0,0,0,2,'QEMU KVM',0
	 db	 'VBoxVBoxVBox',3,'VirtualBox',0
	 db	 'VMwareVMware',4,'VMware',0
	 db	 'Microsoft Hv',5,'Hyper-V',0
	 db	 0
SIGBUF	 db	 13 dup (0)
STR_BOCHS db	 'Bochs'
STR_VBOX db	 'VirtualBox'

.code
.586				; CPUID (only executed when the ID flag works)

; Copy the NUL-terminated string at DS:SI to ES:DI (at most 15 + NUL)
CPYNAME	 proc	 near
	 mov	 cx,15
@@:	 lodsb
	 or	 al,al
	 jz	 short @F
	 stosb
	 loop	 @B
@@:	 mov	 byte ptr es:[di],0
	 ret
CPYNAME	 endp

; Search F000:0000-FFFF for the CX bytes at DS:SI; CF=0 if found
BIOSSTR	 proc	 near
	 push	 es
	 push	 di
	 push	 0F000h
	 pop	 es
	 xor	 di,di
	 mov	 bx,cx
BIOSS1:	 push	 si
	 push	 di
	 mov	 cx,bx
	 repe	 cmpsb
	 pop	 di
	 pop	 si
	 je	 short BIOSS2	; Found
	 inc	 di
	 mov	 ax,di
	 add	 ax,bx
	 jnc	 short BIOSS1	; Not yet at the end
	 stc
	 jmp	 short BIOSS3
BIOSS2:	 clc
BIOSS3:	 pop	 di
	 pop	 es
	 ret
BIOSSTR	 endp

emu_detect proc	 uses si di ds, nameptr:far ptr byte
	 mov	 ax,@data
	 mov	 ds,ax
	 assume  ds:@data

; CPUID present?  (EFLAGS bit 21 can be toggled)
	 pushfd
	 pop	 eax
	 mov	 ecx,eax
	 xor	 eax,200000h
	 push	 eax
	 popfd
	 pushfd
	 pop	 eax
	 push	 ecx
	 popfd
	 cmp	 eax,ecx
	 je	 short EMU_BIOS	; No CPUID

	 mov	 eax,1
	 cpuid
	 bt	 ecx,31 	; Hypervisor present?
	 jnc	 short EMU_BIOS ; No

	 mov	 eax,40000000h
	 cpuid
	 mov	 dword ptr SIGBUF,ebx
	 mov	 dword ptr SIGBUF+4,ecx
	 mov	 dword ptr SIGBUF+8,edx

	 mov	 si,offset EMU_TAB
EMU_NEXT:
	 cmp	 byte ptr [si],0 ; End of the table?
	 je	 short EMU_OTHER
	 push	 si
	 mov	 di,offset SIGBUF
	 push	 ds
	 pop	 es
	 mov	 cx,12
	 repe	 cmpsb
	 pop	 si
	 je	 short EMU_FOUND
	 add	 si,13		; Skip signature and id
@@:	 lodsb			; Skip the name
	 or	 al,al
	 jnz	 short @B
	 jmp	 short EMU_NEXT

EMU_FOUND:
	 add	 si,12
	 lodsb			; The id
	 movzx	 dx,al
	 les	 di,nameptr
	 call	 CPYNAME
	 mov	 ax,dx
	 jmp	 short EMU_EXIT

EMU_OTHER:
	 mov	 si,offset SIGBUF
	 les	 di,nameptr
	 call	 CPYNAME
	 mov	 ax,7
	 jmp	 short EMU_EXIT

EMU_BIOS:
	 mov	 si,offset STR_BOCHS
	 mov	 cx,5
	 call	 BIOSSTR
	 jc	 short @F
	 les	 di,nameptr
	 mov	 si,offset STR_BOCHS
	 mov	 cx,5
	 rep	 movsb
	 mov	 byte ptr es:[di],0
	 mov	 ax,6
	 jmp	 short EMU_EXIT
@@:	 mov	 si,offset STR_VBOX
	 mov	 cx,10
	 call	 BIOSSTR
	 jc	 short @F
	 les	 di,nameptr
	 mov	 si,offset STR_VBOX
	 mov	 cx,10
	 rep	 movsb
	 mov	 byte ptr es:[di],0
	 mov	 ax,3
	 jmp	 short EMU_EXIT
@@:	 les	 di,nameptr
	 mov	 byte ptr es:[di],0
	 xor	 ax,ax
EMU_EXIT:
	 ret
	 assume  ds:nothing
emu_detect endp

dbg_avail proc
	 in	 al,0E9h
	 cmp	 al,0E9h
	 mov	 ax,0
	 jne	 short @F
	 inc	 ax
@@:	 ret
dbg_avail endp

dbg_puts proc	 uses si ds, text:far ptr byte
	 in	 al,0E9h
	 cmp	 al,0E9h
	 jne	 short DBGP_EXIT ; No debug console
	 lds	 si,text
@@:	 lodsb
	 or	 al,al
	 jz	 short DBGP_EXIT
	 out	 0E9h,al
	 jmp	 short @B
DBGP_EXIT:
	 ret
dbg_puts endp

	 end

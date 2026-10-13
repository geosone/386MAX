; QEXIT.COM - leave QEMU through isa-debug-exit (iobase 501h; 386MAX
; touches port 0F4h while it starts, so the usual 0F4h does not work)
        org     100h
        mov     dx, 501h
        mov     al, 0
        out     dx, al
        mov     ax, 4C00h
        int     21h

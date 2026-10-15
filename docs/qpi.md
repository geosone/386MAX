# QEMM programming interface (QPI) in Open 386MAX

Open 386MAX 9.x implements the QEMM programming interface (QPI) the way
QEMM 97 (9.0) behaves, so programs written for QEMM run unchanged:
SBEMU/VSBHDA (port trapping), DESQview-like multitaskers, drivers for
cards that QEMM's API made reachable from DOS.  Where QEMM 97 differs from
Ralf Brown's Interrupt List, QEMM 97 wins.  Every group has a test in
`TESTS/QPI` that gives the same result on 386MAX and on QEMM 97.

## Entry point

* `INT 67h`, `AH=3Fh`, `CX=5145h` ('QE'), `DX=4D4Dh` ('MM'): `ES:DI`
* `INT 2Fh`, `AX=D201h`, `BX=5145h` (QEMM's multiplex way)
* `INT 2Fh`, `AX=1684h`, `BX=4354h` (Jemm's QPIEMU way)

Far call to it with the function in `AX`.  `CF=0` success, `CF=1` error or
not supported.  Version (`AH=03h`): `AX=BX=0703h`.

## Multitasking building blocks

These are the functions DESQview uses on QEMM to run several DOS programs;
Open MaxView can use them the same way.

| Need | QPI | Notes |
|---|---|---|
| A page of memory | `04h` / `05h` | `EDX` = physical page number (`address >> 12`) |
| Own address space per task | `06h` clone the active page table for 0-4 MB into a page from `04h`; `07h` get the active one; `08h` make one active | The context includes conventional memory, video, UMBs and HMA mapping. The HMA PTEs are carried over on `08h` (A20 is global). |
| Map pages into a task | `0Ah` set a PTE (`DX` = page frame, user R/W), `1F00h`/`1F01h` raw PTE get/set for pages 0-3FFh (PCD/PWT allowed: MMIO), `0Bh` map an EMS handle's 16 KB pages at a linear page, `0Fh` restore the default PTEs (AL = dirty) | `0Fh` restores the mapping 386MAX had at the first QPI call. |
| Trap I/O ports | `1A06h`/`1A07h` callback, `1A09h`/`1A0Ah` trap/untrap, `1A08h` status | Callback: `DX` = port, `CX` bit 2 = OUT, bits 3-4 = width, bit 9 = caller's IF; data in `AL/AX/EAX`; returns with `RETF`; its `CF` is ignored. `1A06h` always returns a callback (a default one that does the I/O), so unhandled ports can be chained to the old one. |
| Do I/O past the traps | `1A00h`-`1A04h` (raw for ports virtualized by `15h`/`0Dh`/`1308h`), `1A05h` (through 386MAX's own virtualization) | Use them inside a callback; a direct IN/OUT to a trapped port traps again. |
| Take the IRQs | `1C01h`/`1C03h` 8 V86 handlers for IRQ0-7 / IRQ8-15, `1C00h`/`1C02h` off | Handlers are entered like real-mode ISRs, no EOI is sent for them. Software `INT n` of those vectors still goes to the IVT. |
| Inject an interrupt | `1C04h` `BX` = vector (08h-0Fh, 70h-77h follow the current PIC bases) | The handler runs right after the QPI call returns. |
| A task's tick rate | `15h` `ES:BX` = WORD | The channel 0 divisor a program writes (43h/40h) is recorded; the PIT still gets it. |
| Keep a background task off the CRTC/DAC | `0Dh` mode 1/2, `0Eh` cursor GET/SET callbacks | Cursor position writes go to the callbacks, other CRTC writes are dropped (colour: shape 0Ah/0Bh passes), DAC writes dropped (recorded with `130Ah`), 3DAh reads give a synthetic retrace pattern. |
| Find what a background task drew | `1301h` | Dirty video pages, round robin. |
| Trap all video ports | `1308h` | Writes from 3B4h on dropped, GC 06h remembered. |

A task switch is then: save the task's registers (the scheduler runs in V86,
e.g. from the IRQ0 calldown), `08h` to the next task's page table, restore
its registers.

## Rules and limits

* **Return to the default context** (`07h` value at start) before your
  program ends.  Windows (`INT 2Fh 1605h`) refuses to start while another
  context is active, because Windows takes over 386MAX's page table for
  0-4 MB.
* 386MAX keeps the EMS frame mapping state (what `INT 67h` reports) once,
  not per context.  Map EMS into a task with `0Bh` rather than switching
  `INT 67h` mappings per task.
* The page tables are switched the way EMS 4.0 alternate map register sets
  are; do not mix `08h` with `INT 67h AH=5Bh` sets.
* `23h` (VCPI quota) is stored but not enforced; `22h` (DESQview/X pool
  block) writes the free page count only when a block becomes current.
* Not implemented (`CF=1`): `02h`, `1B00h`-`1B04h` (386MAX has its own
  Windows support), the graphics virtualization of `13h` (`1300h`,
  `1302h`-`1305h`, `1307h`, `130Bh`, `130Dh`-`1310h`), `14h` (DESQview
  protection levels), `19h`, `1Dh`, `21h` (no Stealth), `24h`, `25h`
  (debugger interface), `26h` (VxD loader), `27h`, `29h`, `2Bh`, `2Ch`.
* QPI is a V86 interface; it is not available inside Windows DOS boxes.

## Tests

`TESTS/QPI`: `QPITEST` (detection, information functions), `QPITRAP`
(ports), `QPIMISC` (1B07h, 1E03h/1E04h, 22h, 23h, 28h, 2Ah), `QPICTX`
(contexts, 0Ah, 0Bh, 0Fh), `QPIIRQ` (1Ch), `QPITIMER` (15h), `QPICRT`
(0Dh/0Eh), `QPIVID` (13h).  Run them with `linux/test/suite.py`; the
`qemm` profile runs them on QEMM 97 for comparison (local image only).

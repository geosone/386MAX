# HDPMI-compatible vendor API in Open 386MAX

Open 386MAX 9.x is growing the vendor API that HDPMI offers under the name
`"HDPMI"`, so programs written for HDPMI run on 386MAX's own DPMI host
without loading HDPMI. The first user is VSBHDA (Sound Blaster emulation
for protected-mode games). The HX runtime comes next.

Everything here was written from HDPMI's published interface description:
function numbers, registers, flags and observable behaviour. No HDPMI code
was used. Behaviour is measured against HDPMI32i (the IOPL 0 variant) with
the tests in `TESTS/DPMI` and the `maxhdpmii` profile of
`linux/test/suite.py`.

## Status

The API is **not answered by default yet**. VSBHDA asks for `"HDPMI"`. If
it finds the API, it installs protected-mode port traps and relies on
nested clients sharing its context. Both are implemented now, but the
name stays hidden until VSBHDA with protected-mode games has been tested
(see below). Without the name, VSBHDA runs as before, with real-mode
support only.

To enable the name, call the `"386MAX"` vendor API with `AX=0200h`, `BL=1`
(`BL=0` hides it again). `AL` returns the previous setting. The tests use
this switch.

## Entry point

`INT 2Fh AX=168Ah` with `DS:(E)SI` pointing to `"HDPMI",0` returns `AL=0`
and the entry point in `ES:(E)DI`. `INT 31h AX=0A00h` works the same way.
Call the entry far, with the function number in `AX`. On return, `CF=0`
means success and `CF=1` means error or not supported.

| AX | Function | Open 386MAX |
|----|----------|-------------|
| 0-3 | Debug log functions (only in HDPMI's debug builds) | CF=1 |
| 4 | Host accepts no new clients | CF=1. 386MAX is the single resident host; no other instance can be started. |
| 5 | Set the HDPMI=32 flag (each new client gets a separate context). `BL` = new value, `AL` = old value. | Yes. 386MAX's default is 1 (separate contexts, as before). With 0, nested clients share their parent's context (see below). |
| 6 | Trap the ports `DX`..`DX+CX-1`. `DS:(E)SI` points to the IN and OUT handlers (FAR32 = offset dword + selector word each; FAR16 = offset word + selector word each). Returns `EAX` = handle. | Yes. 16 ranges (HDPMI has 8). Fails if `CX=0`, if the range passes port FFFFh, if any port is already trapped, or if the table is full. |
| 7 | Remove the trap range `EDX` | Yes |
| 8 | Simulate I/O, bypassing all traps | Yes: IN/OUT byte/word/dword, port in `DX` or `BH`, INS/OUTS with REP, 16- or 32-bit addressing |
| 9 | CLI (`BL=0`) or STI (`BL=1`) handler `CX:(E)DX`; `0:0` removes it | Yes |
| 10 | Simulate a hardware interrupt | CF=1, as in HDPMI |

## Port traps in protected mode

386MAX implements the port traps the way HDPMI's IOPL 0 variants do:

* **IOPL.** While a trap range or a CLI/STI handler is installed, DPMI
  clients run with IOPL 0. IN/OUT/INS/OUTS to a port whose bit is set in
  the I/O permission bit map then fault, and so do CLI and STI. The client
  that installs the trap continues at IOPL 0 as well. With no traps
  installed, clients keep IOPL 3, which is 386MAX's old behaviour.
* **Trap handler call.** An access to a trapped port by the client that
  installed the range calls the range's handler like an exception
  handler, using the DPMI exception frame with HDPMI's error code:

  | Bits | Meaning |
  |------|---------|
  | 0-2 | Instruction length |
  | 3 | String instruction |
  | 4-5 | Size: 00 byte, 01 word, 11 dword |
  | 6 | IN/OUT: the port is in bits 8-15. INS/OUTS: 16-bit addressing. |
  | 7 | REP prefix |
  | 8-15 | Immediate port, or the segment override prefix of OUTS |

  The handler must advance `EIP` in the frame. It returns with `RETF`.
  For IN it returns the value in `AL`/`AX`/`EAX`.
* **Ports outside the ranges.** Accesses go to the hardware, as they did
  at IOPL 3.
* **CLI/STI handlers.** The handler is entered with an IRET frame on the
  client's stack and `IF` already changed. It returns with `IRET(D)`.
* **Host code.** 386MAX's own ring 3 code (the vendor API stubs, for
  example) is never passed to the handlers.
* **Client termination.** When a client terminates, its ranges and
  handlers are removed, because their selectors become invalid.
* **Shared ports.** A port trapped both through QPI (real-mode traps) and
  through this API keeps its bit until both have released it.

## Shared context (function 5, `BL=0`)

VSBHDA calls function 5 with `BL=0` and then goes resident. A game started
later enters protected mode as a nested client. With the flag at 0, a
nested client of the same bitness shares its parent's context:

* **LDT.** The child uses the parent's LDT, so the parent's selectors
  (VSBHDA's handlers) stay valid while the child runs.
* **Address space.** The child uses the parent's page directory and
  linear free list. Its memory blocks come from the same address space.
* **Vectors.** The child inherits the protected-mode interrupt and
  exception vectors and hook state (the VME redirection bitmap too). This
  includes VSBHDA's INT 31h/21h and IRQ hooks.
* **LPM stack.** The child continues on the parent's locked stack.
* **Own TSS and handle table.** The child keeps them. Memory block
  handles name their owner (TSS slot in the high word, index in the low
  word, never 0). A handle of any client sharing the context is valid,
  so VSBHDA can call 0508h on its own block at interrupt time while the
  game is the current client.
* **Traps and CLI/STI handlers** of the parent apply to the child.
* **When the child ends,** its memory blocks, its LDT entries (those not
  in use when it started) and its vectors are removed. The parent's
  state is as before.

With different bitness (16-bit game under a 32-bit resident), or with the
flag at 1, the child gets its own context, as 386MAX always did.

## Still missing for VSBHDA with protected-mode games

* **VCPI.** DOS/4GW and similar extenders must use DPMI rather than VCPI
  while traps are installed.
* **More tests with VSBHDA and protected-mode programs** before the name
  is answered by default. Tested so far, with the name switched on in a
  test build (`make -C 386MAX DEFS="@HDP_ON"`):
  * VSBHDA 2.0 on QEMU HDA
  * `TESTS/SCENARIO/SBPM`, Sound Blaster playback by a 32-bit DPMI client
    (3 IRQs, 440 Hz)
  * SBPLAY in real mode, which still works next to it

  DOS/4GW games remain to be tested.

## Tests

* `TESTS/DPMI/HDPAPI` (functions 5, 8, 10)
* `TESTS/DPMI/HDPTRAP` (functions 6, 7, 9; error codes; ports outside
  the ranges)
* `TESTS/DPMI/HDPSHR` (shared context: a resident client with a trap
  and an INT 60h hook starts a nested client from real mode)

Both give the same results on 386MAX and on HDPMI32i (profile
`maxhdpmii`).

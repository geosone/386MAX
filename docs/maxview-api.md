# Open MaxView backend API

Open 386MAX 9.x exposes a private, versioned function group for Open MaxView
through the existing QPI entry point.  It is deliberately distinct from the
legacy QEMM functions and never advertises an unfinished service.

Obtain the entry point with either of the existing mechanisms:

* `INT 67h`, `AH=3Fh`, `CX='QE'`, `DX='MM'`; or
* `INT 2Fh`, `AX=1684h`, `BX=4354h`.

Both return the callable entry point in `ES:DI`.  Call it as an interrupt-style
far entry (push flags, then far call).  Carry is clear on success and set on
failure.  Constants shared with assembler clients are in
`INCLUDE/MAXVIEW.INC`.

## `AX=4D00h`: query ABI

On success:

| Register | Value |
|---|---|
| `AX` | ABI version (`0100h` means 1.0) |
| `BX` | first signature word, `4D56h` (`MV`) |
| `CX` | second signature word, `4D58h` (`MX`) |
| `DX` | capability mask |

The 1.0 implementation sets only `MVCAP_STATUS` (bit 0).  Bits for context
lifecycle, page mapping, saved state, video/I/O virtualisation, interrupt
injection, priorities and scheduler return are reserved and stay clear.

## `AX=4D01h`: query backend status

This call is available when `MVCAP_STATUS` is set.

| Register | Value |
|---|---|
| `AX` | zero |
| `BX` | opaque current context ID (`0001h` is the root context) |
| `CX` | number of active contexts |
| `DX` | current context limit |

The first implementation reports one root context and a limit of one.  It
therefore provides detection and an ABI foundation, but does not claim that
concurrent V86 contexts exist.

Unknown `4Dxxh` functions return carry set and `AX=0001h`
(`MVERR_UNSUPPORTED`).  Callers must test capability bits before using future
functions and must not infer support from the ABI version alone.

`linux/test/maxview-api/MAXVIEWT.ASM` is a real-mode conformance probe.  It is
built exclusively with the repository's JWasm/JWlink toolchain:

```sh
make -C linux/test/maxview-api
```

## QEMM functions for multitasking

The building blocks for running several DOS tasks (mapping contexts,
port trapping, IRQ calldowns, timer and video virtualization) are already
available through the QEMM functions of the same entry point, as DESQview
uses them on QEMM.  See [qpi.md](qpi.md).

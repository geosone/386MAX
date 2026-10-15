# Open 386MAX regression tests

DOS programs that check the services of a memory manager: XMS, EMS, DPMI
(with the DOS and BIOS translation), QPI.  Every test prints one line per
check (OK / FAIL) and ends with errorlevel 0 when all checks passed.

| Directory | Test | What it checks |
|---|---|---|
| XMS  | XMSFUNC | XMS 2.0/3.0: version, A20 (03h-07h), free memory (08h/88h), allocate/free, moves conventional/extended in all directions with data checks, lock counts, handle information (0Eh/8Eh), resize (0Fh/8Fh) keeping the contents, error codes A2h-A7h/AAh/ABh, handle exhaustion, a pattern over the whole largest block |
| EMS  | EMSFUNC | LIM EMS 4.0: 40h-46h, map/data checks, error codes 83h/87h/8Ah/8Bh/8Dh/8Fh/92h, 47h/48h, 4Eh, 4Fh, 50h, 51h, 53h/54h, 55h/56h (alter map and jump/call), 57h (move/exchange, page crossing, overlap), 58h, 59h, 5Bh |
| VCPI | VCPIFUNC | VCPI 1.0: DE00h-DE0Bh (memory, CR0, debug registers, 8259 vectors), 100 round trips V86 -> protected mode -> V86 through DE0Ch with an own GDT/TSS/page tables, a DE04h page used in protected mode |
| VDS  | VDSFUNC | Virtual DMA Services: 8102h-810Ch, lock of conventional memory and of an UMB, scatter/gather, DMA buffer with copy in/out, translation counting, error codes |
| DPMI | DPMI10  | DPMI 1.0 functions (16-bit client) |
| DPMI | DOSXLAT | DOS API translation in protected mode: LFN (71xxh), FAT32 (73xxh), country, DBCS, swappable data area |
| DPMI | XLAT32  | the same for a 32-bit client |
| DPMI | PM26    | INT 25h/26h through 0301h with DOS buffers (host's V86 side, mode switches) |
| DPMI | DISKIO  | INT 13h/25h/26h and 7305h from protected mode, buffers above 4 KB, DOS 7 volume lock |
| DPMI | STKFLT  | a 32-bit client with an invalid stack calls INT 21h (must not reset the machine) |
| DPMI | MOUSE12, MOUSE18 | INT 33h 0Ch/12h/18h/19h handlers (need a mouse driver) |
| QPI  | QPITEST | QEMM programming interface (INT 2Fh D201h, INT 67h 3Fh) |
| QPI  | QPITRAP | port trapping with callback (1A06h-1A0Ah), default callback, 1A05h |
| QPI  | QPIMISC | 1B07h, 1E03h/1E04h, 22h (DESQview/X pool block), 23h (VCPI quota), 28h, 2Ah |
| QPI  | QPICTX  | mapping contexts 04h-08h, 0Ah, 0Bh (EMS handle), 0Fh (DESQview's per-task address spaces) |
| QPI  | QPIIRQ  | IRQ calldowns 1C00h-1C04h |
| QPI  | QPITIMER | timer channel 0 virtualization 15h |
| QPI  | QPICRT  | CRTC/DAC trapping 0Dh with cursor callbacks 0Eh, 3DAh retrace pattern, 1A02h/1A03h past it |
| QPI  | QPIVID  | VIDRAM 13h for text background windows: 1301h dirty pages, 130Ah DAC buffer, 1308h all CRT ports, 1309h Hercules callback |
| QPI  | QPIPROT | DESQview protection levels 14h (initialization, level 0 as DESQview uses it) |

`MAX.LST` lists the tests with what they need (`needs=xms,ems,dpmi,...`)
and their timeout; `INC/TESTLIB.INC` has the output and counting macros.

## Running them

* **Build:** `make TESTS` (part of `make`) puts the programs, `RUNTESTS.BAT`
  and this file into `build/TESTS`.  `make devpkg` packs `build/bin` and the
  tests into `release/open386max-<ver>-dev-<commit>.zip`.
* **Under DOS:** `RUNTESTS.BAT` (or `RUNTESTS MOUSE` with a mouse driver
  loaded) runs all tests; `RESULT.TXT` gets PASS/FAIL per test, `<NAME>.TXT`
  the output.  When the machine hangs, the last `RUN <NAME>` line names the
  test.
* **In QEMU:** `linux/test/suite.py` boots a DOS image
  (`linux/test/mkdosdisk.sh`) with the memory manager of a profile, runs the
  tests in one boot and continues after a hang or reset with the next test:

  ```
  linux/test/suite.py                       # 386MAX, MS-DOS 6.22, own tests
  linux/test/suite.py -d edrdos -d freedos  # other systems
  linux/test/suite.py --check               # compare with BASELINE/, exit 1 on regressions
  linux/test/suite.py --update              # store the results as the new baseline
  linux/test/suite.py -p max -p jemmex --matrix   # build/suite/matrix.md
  ```

  Profiles: `max` (386MAX), `emm386` (MS HIMEM.SYS + EMM386.EXE from the DOS
  image), `himem` (HIMEM.SYS only), and with `REFDIR=` a directory holding
  the programs: `jemmex`, `jemm386` (HimemX + Jemm386), `himemx` (XMS only),
  `hdpmi` (HimemX + HDPMI16/32, DPMI), `cwsdpmi` (HimemX + CWSDPMI, the DPMI
  host of DJGPP and so of many games; 32-bit clients only), `maxcws`
  (386MAX with NODPMI + CWSDPMI as its VCPI client) and `maxhdpmi` (386MAX
  with NODPMI + HDPMI16/32 as its VCPI client, as VSBHDA setups use it:
  separates 386MAX's DPMI host from its V86/VCPI side).

  MS-DOS has no DPMI host of its own: programs got DPMI from the Windows
  3.x/9x DOS box, from MSDPMI (Microsoft C 7), from their extender (CWSDPMI,
  DOS/4GW, Borland RTM) or from the memory manager (386MAX, QEMM QDPMI).

## What the tests expect

Goal: 386MAX behaves like the hosts real DOS programs run on.  The
specifications (XMS 3.0, LIM EMS 4.0, VCPI 1.0, VDS 1.0, DPMI 0.9/1.0, QPI)
are the starting point; where the common hosts behave differently, the tests
accept their behaviour, and the majority of them is the target:

| Area | Reference hosts | Programs that depend on it |
|---|---|---|
| XMS | MS HIMEM.SYS, HimemX, Jemm | all |
| EMS, VCPI, VDS | MS EMM386.EXE, Jemm386/JemmEx | games, DOS extenders (DOS/4GW, CWSDPMI over VCPI) |
| DPMI | CWSDPMI, HDPMI, the Windows 3.x/9x DOS box | DJGPP and Watcom games, HX programs |
| QPI (QEMM API) | QEMM, Jemm's QPIEMU | SBEMU, VSBHDA (port trapping for Sound Blaster emulation), DESQview-like multitaskers (Open MaxView), programs written for QEMM |

A deviation of 386MAX from the majority of the reference columns in the
matrix counts as an error.

Sources: XMS 3.0 (Microsoft, Lotus, Intel, AST 1991), LIM EMS 4.0 (Lotus,
Intel, Microsoft 1987), VCPI 1.0 (Phar Lap, Quarterdeck 1989), VDS
(Microsoft 1990, also Ralf Brown's Interrupt List INT 4Bh), DPMI 0.9/1.0
(DPMI Committee 1990/1991).

## External test suites (not in this repository)

Other projects' tests run through the same runner, locally only, because
their licenses differ (or they have none); what they check is covered by the
own tests above:

| Suite | Source | Run with |
|---|---|---|
| `jemm` | Jemm's `Test` directory (github.com/Baron-von-Riedesel/Jemm) | `JEMM_TEST=<Jemm>/Test linux/test/suite.py -s jemm` |
| `hx`   | HX's HDPMI regression tests (github.com/Baron-von-Riedesel/HX) | `HX_REG=<dir with the built tests> linux/test/suite.py -s hx` |

| Jemm test | own test |
|---|---|
| XMSTEST, XMSTEST2-5 | XMS/XMSFUNC |
| EMS4E, EMS4F, EMS56, EMS57, EMS57A, EMS5B, FRAMERES, INT67 | EMS/EMSFUNC |
| TESTVCPI | VCPI/VCPIFUNC |
| TESTVDS, TESTVDS2/3 | VDS/VDSFUNC |
| TESTDMA, TESTDMA2/3 (real floppy DMA into an UMB) | (planned) |
| EXC00, EXC06, HLTTEST, HLTTEST2, INT88, I15MOVE | (planned: V86/V86FUNC) |

## Results

See `RESULTS.md` (matrix of all profiles, updated with the suite runs).

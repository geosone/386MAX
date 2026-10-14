# Open 386MAX

Open 386MAX is the **386MAX memory manager** for DOS, Windows 3.1x and
Windows 9x: memory manager (386MAX.SYS, 386LOAD, 386UTIL), MAXIMIZE,
ASQ, the MAX shell, ExtraDOS, the Windows tools (MAXedit, MAXmeter, the PIF
editor, GoAhead, DOSMAX, the Toolbox) and the DOS and Windows installers.

Qualitas, Inc. released the 386MAX sources under the GNU GPL v3
([sudleyplace/386MAX](https://github.com/sudleyplace/386MAX)). This fork
builds everything with **open-source tools on Linux**, replaces the parts
that existed only as binaries, and develops 386MAX further:

- runs on modern hardware: chipset shadow RAM (PAM/MTRR), E820/E801
  reserved areas (AHCI, EBDA, ACPI) stay untouched, more than 256 MB RAM,
  ISA DMA above 16 MB
- QEMM QPI port trapping API for SBEMU and VSBHDA
- no serial numbers or registration; version 8.54, English and German

Tested in QEMU with complete installation and MAXIMIZE runs (DOS and
Windows SETUP, all three MAXIMIZE passes): MS-DOS 6.22, MS-DOS 7.1,
Enhanced DR-DOS, SvarDOS, Windows for Workgroups 3.11 and Windows 98 SE
(linux/test: maxdos.sh, win311.sh, win98.sh).

Releases with floppy, USB and CD images:
[Releases](https://github.com/geosone/386MAX/releases)

## Build

Requirements: GNU make, gcc, Python 3, [Open Watcom](https://github.com/open-watcom/open-watcom-v2)
(`WATCOM=/opt/watcom`), mtools, and for the media xorriso, dosfstools and zip.

```sh
git clone --recursive https://github.com/geosone/386MAX
cd 386MAX
make                         # tools and all projects, programs in build/bin
make MAXLANG=GR              # German
python3 linux/tools/mkpkg.py build/package .   # installation package
```

The version number is in one place, the file `VERSION` (e.g. `8.51`); the
build passes it to all programs, resources and the release media.

`linux/jwasm` and `linux/jwlink` are git submodules (branch `386max` of
[geosone/JWasm](https://github.com/geosone/JWasm) and
[geosone/jwlink](https://github.com/geosone/jwlink)): JWasm with MASM 5.1
compatibility and jwlink with Microsoft LINK and Windows 3.x VxD
compatibility. `make` builds them into `linux/bin` first.

All Windows programs are plain Win16 programs (Windows SDK API, no MFC).

Release media, one build per language:

```sh
linux/scripts/buildlang.sh US    # release/US/tree, release/US/package
linux/scripts/mkmedia.sh US      # floppy set, USB image, ISO, ZIP in release/US
```

## Layout

| Path | Content |
|---|---|
| `386MAX`, `386LOAD`, `386DISK`, `EXTRADOS`, `VXD`, ... | the DOS and VxD parts (assembler) |
| `ASQ`, `ASQENG`, `MAXIMIZE`, `INSTALL`, `QSHELL`, `QUILIB`, ... | the DOS programs in C |
| `MAXEDIT`, `MAXMETER`, `QPIFEDIT`, `MAXCTRL`, `MAXSETUP`, `WINMXMZ`, ... | the Windows programs |
| `CTL3D`, `SFTTABS`, `HELPENG`, `VERLIB`, `HHELP`, `RDOSMAX` | new GPL code for parts that were only binaries |
| `DOSHELP`, `MAXHELP` | DOS and Windows help |
| `PACKAGE` | data files and file list of the installation package |
| `INC`, `INCLUDE` | shared include files |
| `linux/mk` | build rules (`dos.mk`, `win.mk`) |
| `linux/tools` | help compilers, package tools, logo generator, build helpers |
| `linux/test` | tests in QEMU (DOS, Windows for Workgroups 3.11, installation) |
| `linux/scripts` | language builds and release media |

The tests need a DOS boot image and, for Windows, a Windows for Workgroups
3.11 installation; neither is part of this repository (no Microsoft files).

## License

GNU General Public License version 3, see `LICENSE`.

(C) Copyright 1987-97 Qualitas, Inc.; Open 386MAX contributors 2022-2026.

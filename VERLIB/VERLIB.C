/*
 * VERLIB.C - version information of Windows executables for DOS programs
 * (VERL.LIB, replaces the library version of the Windows SDK's VER.DLL).
 *
 * GetFileVersionInfoSize and GetFileVersionInfo read the version resource
 * (RT_VERSION) of a Windows (NE) executable, as ASQ does with WINVER.EXE.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <io.h>
#include <fcntl.h>

typedef unsigned short WORD;
typedef unsigned long DWORD;

#define RT_VERSION	16

static WORD get16(unsigned char *p) { return p[0] | ((WORD)p[1] << 8); }
static DWORD get32(unsigned char *p) { return get16(p) | ((DWORD)get16(p+2) << 16); }

static int readat(int fh, DWORD pos, void far *buf, unsigned cb)
{
	return lseek(fh, pos, SEEK_SET) == (long)pos && read(fh, buf, cb) == cb;
}

/* the version resource of an NE file: offset and length, FALSE if none */
static int findver(int fh, DWORD *pos, DWORD *len)
{
	unsigned char b[64];
	DWORD ne, p;
	WORD shift;

	if (!readat(fh, 0, b, 64) || b[0] != 'M' || b[1] != 'Z')
		return 0;
	ne = get32(b + 0x3C);
	if (!readat(fh, ne, b, 64) || b[0] != 'N' || b[1] != 'E')
		return 0;
	p = ne + get16(b + 0x24);		/* resource table */
	if (get16(b + 0x24) == get16(b + 0x26) || !readat(fh, p, b, 2))
		return 0;
	shift = get16(b);
	p += 2;
	for (;;) {				/* type entries */
		WORD type, count;
		if (!readat(fh, p, b, 8))
			return 0;
		type = get16(b);
		count = get16(b + 2);
		if (!type)
			return 0;
		p += 8;
		if (type == (0x8000 | RT_VERSION) && count) {
			if (!readat(fh, p, b, 12))
				return 0;
			*pos = (DWORD)get16(b) << shift;
			*len = (DWORD)get16(b + 2) << shift;
			return 1;
		}
		p += 12L * count;
	}
}

DWORD far pascal GetFileVersionInfoSize(const char far *name, DWORD far *handle)
{
	char path[128];
	DWORD pos, len = 0;
	int fh, i;

	for (i = 0; i < sizeof(path) - 1 && name[i]; i++)
		path[i] = name[i];
	path[i] = 0;
	if (handle)
		*handle = 0;
	if ((fh = open(path, O_RDONLY | O_BINARY)) < 0)
		return 0;
	if (!findver(fh, &pos, &len))
		len = 0;
	close(fh);
	return len;
}

int far pascal GetFileVersionInfo(const char far *name, DWORD handle, DWORD cb, void far *data)
{
	char path[128];
	DWORD pos, len;
	int fh, i, ok = 0;

	(void)handle;
	for (i = 0; i < sizeof(path) - 1 && name[i]; i++)
		path[i] = name[i];
	path[i] = 0;
	if ((fh = open(path, O_RDONLY | O_BINARY)) < 0)
		return 0;
	if (findver(fh, &pos, &len)) {
		if (len > cb)
			len = cb;
		ok = len < 0xFFF0L && readat(fh, pos, data, (unsigned)len);
	}
	close(fh);
	return ok;
}

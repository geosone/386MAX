/*
 * HELPENG.C - QuickHelp help engine (replacement of the Microsoft help
 * engine library LHELP.LIB).
 *
 * Implements the interface of INCLUDE/HELP.H for the DOS programs (ASQ,
 * MAXIMIZE, SETUPDOS): it reads QuickHelp databases (signature 'LN',
 * version 2, also several concatenated in one file), decompresses topics
 * (Huffman coding, keywords, run lengths) and gives access to their lines,
 * attributes and cross references.  File access and memory go through the
 * application's callbacks (QUILIB/HELPBACK.C).
 *
 * The file format follows the description in fancidev/DosHelp
 * (QuickHelp/Serialization/Format.txt, Apache 2.0); the compiler of the
 * databases is linux/tools/qhelp.py.
 *
 * Context numbers (nc): high word = database handle (1..MAXDB), low word =
 * 8000h + topic index (as returned by HelpNc, HelpNcNext, ...), or a
 * context string number (1-based), or 0 (the first topic).
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <string.h>
#include <ctype.h>
#include <dos.h>
#include "help.h"

#ifndef TRUE
#define TRUE  1
#define FALSE 0
#endif

/* callbacks of the application (QUILIB/HELPBACK.C) */
int pascal far OpenFileOnPath(char far *, int);
void pascal far HelpCloseFile(int);
unsigned long pascal far ReadHelpFile(unsigned, unsigned long, char far *, unsigned short);
unsigned pascal far HelpAlloc(unsigned);
void far * pascal far HelpLock(mh);
void pascal far HelpUnlock(mh);
void pascal far HelpDealloc(mh);

#define MAXDB	   40		/* databases (all files)		*/
#define MAXFILE    4		/* open files				*/
#define MAXBACK    32		/* HelpNcRecord history			*/
#define MAXBUF	   8		/* decompressed topics with local xrefs */
#define HDRSIZE    0x46 	/* database header			*/

#define UNIQ	   0x8000

typedef struct {
	int	fh;			/* 0 = free			*/
	char	name[80];
} HFILE;

typedef struct {
	ushort	file;			/* 1-based index into Files, 0 = free */
	ulong	base;			/* file offset of the database	*/
	uchar	hdr[HDRSIZE];		/* header as in the file	*/
	ushort	attrs;
	uchar	ctlchar;
	ushort	ntopics, nctx, width;
	mh	hMeta;			/* sections index .. topics + keyword table */
	uchar far *meta;
	ulong far *index;		/* topic offsets [ntopics+1]	*/
	uchar far *ctx; 		/* context strings		*/
	ushort far *map;		/* context -> topic [nctx]	*/
	uchar far *kw;			/* keywords (length, bytes)	*/
	ushort	nkw;
	ushort far *kwoff;		/* offsets of the keywords in kw */
	ushort far *tree;		/* Huffman tree, NULL = none	*/
} HDB;

/* header of a decompressed topic (HelpDecomp); topichdr first */
#pragma pack(1)
typedef struct {
	topichdr th;
	ushort	cb;			/* bytes of line data that follow */
	ushort	db;			/* database handle		*/
} DTOPIC;
#pragma pack()

static HFILE Files[MAXFILE];
static HDB Dbs[MAXDB];
static nc Back[MAXBACK];
static int nBack, iBack;
static struct { uchar far *p; ushort cb; ushort db; } Bufs[MAXBUF];
static int iBuf;

static ushort get16(uchar far *p) { return p[0] | ((ushort)p[1] << 8); }
static ulong get32(uchar far *p) { return get16(p) | ((ulong)get16(p+2) << 16); }

/* database of an nc, NULL if none */
static HDB *dbof(nc n)
{
	unsigned h = fmhnc(n);
	if (h < 1 || h > MAXDB || !Dbs[h-1].file)
		return NULL;
	return &Dbs[h-1];
}

/* topic index of an nc, -1 if invalid */
static int topicof(HDB *d, nc n)
{
	ushort lo = (ushort)n;
	ushort t;

	if (!d)
		return -1;
	if (lo & UNIQ)
		t = lo & ~UNIQ;
	else if (lo == 0)
		t = 0;
	else if (lo <= d->nctx)
		t = d->map[lo-1];
	else
		return -1;
	return t < d->ntopics ? t : -1;
}

static nc mknc(HDB *d, int topic)
{
	return ((ulong)(d - Dbs + 1) << 16) | UNIQ | topic;
}

static void freedb(HDB *d)
{
	if (d->hMeta) {
		HelpUnlock(d->hMeta);
		HelpDealloc(d->hMeta);
	}
	memset(d, 0, sizeof(*d));
}

/* load database at file offset base: 0 = ok, else HELPERR_ */
static int loaddb(HDB *d, unsigned file, ulong base)
{
	int fh = Files[file-1].fh;
	ulong oIndex, oCtx, oMap, oKw, oHuff, oText, cb;
	ushort i, n;
	uchar far *p;

	d->file = file;
	d->base = base;
	if (ReadHelpFile(fh, base, (char far *)d->hdr, HDRSIZE) != HDRSIZE)
		return HELPERR_READ;
	if (d->hdr[0] != 'L' || d->hdr[1] != 'N')
		return HELPERR_NOTHELP;
	if (get16(d->hdr+2) != 2)
		return HELPERR_BADVERS;
	d->attrs = get16(d->hdr+4);
	d->ctlchar = d->hdr[6];
	d->ntopics = get16(d->hdr+8);
	d->nctx = get16(d->hdr+10);
	d->width = get16(d->hdr+12);
	oIndex = get32(d->hdr+0x22);
	oCtx = get32(d->hdr+0x26);
	oMap = get32(d->hdr+0x2A);
	oKw = get32(d->hdr+0x2E);
	oHuff = get32(d->hdr+0x32);
	oText = get32(d->hdr+0x36);
	if (oIndex < HDRSIZE || oText < oIndex || oCtx < oIndex || oMap < oCtx)
		return HELPERR_NOTHELP;

	/* the sections from the topic index to the topics in one block, the
	 * keyword offset table behind them */
	cb = oText - oIndex;
	if (cb + 2 * 1024 + 16 > 0xFFF0L)
		return HELPERR_MEMORY;
	d->hMeta = HelpAlloc((unsigned)cb + 2 * 1024 + 16);
	if (!d->hMeta || !(d->meta = HelpLock(d->hMeta)))
		return HELPERR_MEMORY;
	if (ReadHelpFile(fh, base + oIndex, (char far *)d->meta, (ushort)cb) != cb)
		return HELPERR_READ;
	d->index = (ulong far *)d->meta;
	d->ctx = d->meta + (ushort)(oCtx - oIndex);
	d->map = (ushort far *)(d->meta + (ushort)(oMap - oIndex));
	d->kwoff = (ushort far *)(d->meta + (((ushort)cb + 1) & ~1));
	d->nkw = 0;
	if (oKw) {
		ulong end = oHuff ? oHuff : oText;
		d->kw = d->meta + (ushort)(oKw - oIndex);
		for (i = 0; i < end - oKw && d->nkw < 1024; i += 1 + d->kw[i])
			d->kwoff[d->nkw++] = i;
	}
	d->tree = oHuff ? (ushort far *)(d->meta + (ushort)(oHuff - oIndex)) : NULL;

	/* the context strings: check that there are nctx of them */
	p = d->ctx;
	for (n = 0; n < d->nctx; n++) {
		while (*p)
			p++;
		p++;
		if (p > (uchar far *)d->map)
			return HELPERR_NOTHELP;
	}
	return 0;
}

void far pascal LOADDS HelpInit(void)
{
}

nc far pascal LOADDS HelpOpen(char far *name)
{
	unsigned file;
	int fh, err;
	ulong base, size, first = 0;
	HDB *d;

	for (file = 0; file < MAXFILE && Files[file].fh; file++)
		;
	if (file == MAXFILE)
		return HELPERR_LIMIT;
	fh = OpenFileOnPath(name, 0);
	if (!fh)
		return HELPERR_FNF;
	Files[file].fh = fh;
	_fstrncpy(Files[file].name, name, sizeof(Files[file].name) - 1);
	file++;
	size = ReadHelpFile(fh, 0, NULL, 0);

	/* the databases of the file, one behind the other */
	for (base = 0; base + HDRSIZE <= size; ) {
		for (d = Dbs; d < Dbs + MAXDB && d->file; d++)
			;
		if (d == Dbs + MAXDB) {
			err = HELPERR_LIMIT;
			goto fail;
		}
		err = loaddb(d, file, base);
		if (err) {
			freedb(d);
			if (first && err == HELPERR_NOTHELP)
				break;	/* something else appended */
			goto fail;
		}
		if (!first)
			first = (ulong)(d - Dbs + 1) << 16;
		if (!get32(d->hdr+0x42))
			break;
		base += get32(d->hdr+0x42);
	}
	if (!first) {
		err = HELPERR_NOTHELP;
		goto fail;
	}
	return first;

fail:
	HelpClose(first ? first : 0xFFFF0000L | file);
	return err;
}

/* closes the file of nc; 0 = all files */
void far pascal LOADDS HelpClose(nc n)
{
	unsigned file = 0, i;
	HDB *d;

	if (n == 0xFFFF0000L + (ushort)n)	/* (HelpOpen: file number) */
		file = (ushort)n;
	else if (n && (d = dbof(n)) != NULL)
		file = d->file;
	else if (n)
		return;
	for (i = 0; i < MAXDB; i++)
		if (Dbs[i].file && (!file || Dbs[i].file == file))
			freedb(&Dbs[i]);
	for (i = 1; i <= MAXFILE; i++)
		if (Files[i-1].fh && (!file || i == file)) {
			HelpCloseFile(Files[i-1].fh);
			Files[i-1].fh = 0;
		}
	if (!file)
		nBack = iBack = 0;
}

/* compare a name with the database's file name (without directory) */
static int dbnamecmp(HDB *d, char far *s, int len)
{
	uchar far *nm = d->hdr + 0x10;
	char far *p;

	for (p = s + len; p > s && p[-1] != '\\' && p[-1] != '/' && p[-1] != ':'; p--)
		;
	len -= (int)(p - s);
	if (len > 13 || _fstrnicmp((char far *)nm, p, len) || nm[len])
		return 1;
	return 0;
}

/* context string in database d -> nc, 0 = not found */
static nc findctx(HDB *d, char far *s)
{
	uchar far *p = d->ctx;
	ushort i;

	for (i = 0; i < d->nctx; i++) {
		int r = (d->attrs & 1) ? _fstrcmp((char far *)p, s)
				       : _fstricmp((char far *)p, s);
		if (!r)
			return d->map[i] < d->ntopics ? mknc(d, d->map[i]) : 0;
		p += _fstrlen((char far *)p) + 1;
	}
	return 0;
}

/* local cross reference: an empty string followed by a word, inside a
 * decompressed topic */
static nc localref(char far *s)
{
	int i;
	ushort w;
	HDB *d;

	for (i = 0; i < MAXBUF; i++) {
		uchar far *b = Bufs[i].p;
		if (b && FP_SEG(b) == FP_SEG(s) && FP_OFF(s) >= FP_OFF(b)
		      && FP_OFF(s) < FP_OFF(b) + Bufs[i].cb)
			break;
	}
	if (i == MAXBUF || !(d = dbof((ulong)Bufs[i].db << 16)))
		return 0;
	w = get16((uchar far *)s + 1);
	if (w & UNIQ)
		return (w & ~UNIQ) < d->ntopics ? mknc(d, w & ~UNIQ) : 0;
	return w && w <= d->nctx ? mknc(d, d->map[w-1]) : 0;
}

nc far pascal LOADDS HelpNc(char far *s, nc ncInit)
{
	HDB *d = dbof(ncInit), *e;
	char far *bang;
	nc r;

	if (!*s)
		return localref(s);
	bang = _fstrchr(s, '!');
	if (bang) {
		/* "file!context": the database of that name */
		for (e = Dbs; e < Dbs + MAXDB; e++)
			if (e->file && !dbnamecmp(e, s, (int)(bang - s)))
				break;
		if (e == Dbs + MAXDB)
			return 0;
		if (!bang[1])
			return (ulong)(e - Dbs + 1) << 16;
		return findctx(e, bang + 1);
	}
	/* the databases of the file, from the one of ncInit on */
	if (!d)
		d = Dbs;
	for (e = d; e < Dbs + MAXDB; e++) {
		if (!e->file || (ncInit && e->file != d->file))
			continue;
		if ((r = findctx(e, s)) != 0)
			return r;
	}
	return 0;
}

nc far pascal LOADDS HelpNcCmp(char far *s, nc ncInit,
	f (pascal far *cmp)(uchar far *, uchar far *, ushort, f, f))
{
	(void)cmp;
	return HelpNc(s, ncInit);
}

nc far pascal LOADDS HelpNcUniq(nc n)
{
	HDB *d = dbof(n);
	int t = topicof(d, n);
	return t < 0 ? 0 : mknc(d, t);
}

nc far pascal LOADDS HelpNcNext(nc n)
{
	HDB *d = dbof(n);
	int t = topicof(d, n);
	if (t < 0 || t + 1 >= d->ntopics)
		return 0;
	return mknc(d, t + 1);
}

nc far pascal LOADDS HelpNcPrev(nc n)
{
	HDB *d = dbof(n);
	int t = topicof(d, n);
	if (t <= 0)
		return 0;
	return mknc(d, t - 1);
}

/* history of visited topics */
void far pascal LOADDS HelpNcRecord(nc n)
{
	Back[iBack] = n;
	iBack = (iBack + 1) % MAXBACK;
	if (nBack < MAXBACK)
		nBack++;
}

nc far pascal LOADDS HelpNcBack(void)
{
	if (!nBack)
		return 0;
	nBack--;
	iBack = (iBack + MAXBACK - 1) % MAXBACK;
	return Back[iBack];
}

/* size of the compressed topic */
ushort far pascal LOADDS HelpNcCb(nc n)
{
	HDB *d = dbof(n);
	int t = topicof(d, n);
	if (t < 0)
		return 0;
	return (ushort)(d->index[t+1] - d->index[t]);
}

/* reads the compressed topic; returns the size of the decompressed one */
ushort far pascal LOADDS HelpLook(nc n, PB pb)
{
	HDB *d = dbof(n);
	int t = topicof(d, n);
	ushort cb;

	if (t < 0)
		return 0;
	cb = (ushort)(d->index[t+1] - d->index[t]);
	if (cb < 2 || ReadHelpFile(Files[d->file-1].fh, d->base + d->index[t],
				   (char far *)pb, cb) != cb)
		return 0;
	return sizeof(DTOPIC) + get16((uchar far *)pb) + 1;
}

/* the stream of the compressed topic, Huffman decoded */
typedef struct {
	uchar far *p, far *end;
	uchar bit;
	ushort far *tree;
} STREAM;

static int nextsym(STREAM *s)
{
	ushort node = 0;

	if (!s->tree)
		return s->p < s->end ? *s->p++ : -1;
	for (;;) {
		if (s->p >= s->end)
			return -1;
		if (*s->p & s->bit)
			node++;
		else
			node = s->tree[node] / 2;
		s->bit >>= 1;
		if (!s->bit) {
			s->bit = 0x80;
			s->p++;
		}
		if (s->tree[node] & 0x8000)
			return s->tree[node] & 0xFF;
	}
}

f far pascal LOADDS HelpDecomp(PB pbComp, PB pbDest, nc n)
{
	HDB *d = dbof(n);
	uchar far *c = pbComp;
	DTOPIC far *dt = pbDest;
	uchar far *o = (uchar far *)(dt + 1), far *oend;
	ushort len, cb, i;
	STREAM s;
	int x, y;

	if (topicof(d, n) < 0)
		return TRUE;
	len = get16(c);
	cb = HelpNcCb(n);
	dt->th.appChar = d->ctlchar;
	dt->th.linChar = d->ctlchar;
	dt->th.ftype = 0;
	dt->th.lnCur = 0;
	dt->th.lnOff = 0;
	dt->db = fmhnc(n);
	s.p = c + 2;
	s.end = c + cb;
	s.bit = 0x80;
	s.tree = d->tree;
	oend = o + len;
	while (o < oend && (x = nextsym(&s)) >= 0) {
		if (x >= 0x10 && x <= 0x17) {		/* keyword */
			uchar far *k;
			if ((y = nextsym(&s)) < 0)
				break;
			i = ((x & 3) << 8) | y;
			if (i >= d->nkw)
				break;
			k = d->kw + d->kwoff[i];
			for (i = 0; i < k[0] && o < oend; i++)
				*o++ = k[1+i];
			if ((x & 4) && o < oend)
				*o++ = ' ';
		} else if (x == 0x18) {			/* spaces */
			if ((y = nextsym(&s)) < 0)
				break;
			while (y-- > 0 && o < oend)
				*o++ = ' ';
		} else if (x == 0x19) {			/* repeated byte */
			if ((x = nextsym(&s)) < 0 || (y = nextsym(&s)) < 0)
				break;
			while (y-- > 0 && o < oend)
				*o++ = (uchar)x;
		} else if (x == 0x1A) { 		/* escaped byte */
			if ((x = nextsym(&s)) < 0)
				break;
			*o++ = (uchar)x;
		} else
			*o++ = (uchar)x;
	}
	dt->cb = (ushort)(o - (uchar far *)(dt + 1));

	/* remember the buffer for local cross references */
	Bufs[iBuf].p = pbDest;
	Bufs[iBuf].cb = sizeof(DTOPIC) + dt->cb;
	Bufs[iBuf].db = dt->db;
	iBuf = (iBuf + 1) % MAXBUF;
	return o < oend;
}

/* fShow: show the lines that start with the control character */
void far pascal LOADDS HelpCtl(PB pb, f fShow)
{
	DTOPIC far *dt = pb;
	dt->th.linChar = fShow ? 0xFF : dt->th.appChar;
	dt->th.lnCur = 0;
	dt->th.lnOff = 0;
}

/* line records: [len+1] text [len+1] attributes */
#define LTEXT(l)	((l)[0])
#define LATTR(l)	((l) + (l)[0])
#define LNEXT(l)	(LATTR(l) + LATTR(l)[0])

static int visible(DTOPIC far *dt, uchar far *l)
{
	return dt->th.linChar == 0xFF || LTEXT(l) < 2 || l[1] != dt->th.linChar;
}

/* line ln (1-based, visible lines), NULL beyond the end */
static uchar far *hgetline(PB pb, ushort ln)
{
	DTOPIC far *dt = pb;
	uchar far *b, far *e, far *l;
	ushort cur;

	if (!dt || !ln)
		return NULL;
	b = (uchar far *)(dt + 1);
	e = b + dt->cb;
	if (dt->th.lnCur && dt->th.lnCur <= ln) {
		cur = dt->th.lnCur;
		l = b + dt->th.lnOff;
	} else {
		cur = 1;
		l = b;
		while (l < e && !visible(dt, l))
			l = LNEXT(l);
	}
	while (l < e && cur < ln) {
		l = LNEXT(l);
		while (l < e && !visible(dt, l))
			l = LNEXT(l);
		cur++;
	}
	if (l >= e || LNEXT(l) > e)
		return NULL;
	dt->th.lnCur = cur;
	dt->th.lnOff = (ushort)(l - b);
	return l;
}

int far pascal LOADDS HelpcLines(PB pb)
{
	DTOPIC far *dt = pb;
	uchar far *l, far *e;
	int n = 0;

	if (!dt)
		return 0;
	l = (uchar far *)(dt + 1);
	e = l + dt->cb;
	for (; l < e; l = LNEXT(l))
		if (visible(dt, l))
			n++;
	return n;
}

/* text of a line; returns its length + 1, 0 beyond the end */
ushort far pascal LOADDS HelpGetLine(ushort ln, ushort cbMax, uchar far *dst, PB pb)
{
	uchar far *l = hgetline(pb, ln);
	ushort n;

	if (!l || !cbMax)
		return 0;
	n = LTEXT(l) - 1;
	if (n > cbMax - 1)
		n = cbMax - 1;
	_fmemcpy(dst, l + 1, n);
	dst[n] = 0;
	return n + 1;
}

/* style runs of a line (style, count), covering the whole text */
static ushort styles(uchar far *l, ushort *st, ushort *cnt, ushort max)
{
	uchar far *a = LATTR(l) + 1, far *ae = LATTR(l) + LATTR(l)[0];
	ushort len = LTEXT(l) - 1, pos = 0, n = 0;

	if (a < ae && *a != 0xFF) {
		if (*a && n < max) {
			st[n] = A_PLAIN;
			cnt[n++] = *a;
			pos += *a;
		}
		a++;
		while (a + 1 < ae && *a != 0xFF && n < max) {
			if (a[1]) {
				st[n] = a[0];
				cnt[n++] = a[1];
				pos += a[1];
			}
			a += 2;
		}
	}
	if (pos < len && n < max) {
		st[n] = A_PLAIN;
		cnt[n++] = len - pos;
	}
	return n;
}

/* a line as character/attribute pairs (attribute = colors[style]); returns
 * the bytes stored, -1 beyond the end */
int far pascal LOADDS HelpGetCells(int ln, int cbMax, char far *dst, PB pb, uchar far *colors)
{
	uchar far *l = hgetline(pb, (ushort)ln);
	ushort st[128], cnt[128], nr, r, k, len, pos = 0;
	int max = cbMax / 2;

	if (!l)
		return -1;
	len = LTEXT(l) - 1;
	nr = styles(l, st, cnt, 128);
	for (r = 0; r < nr; r++)
		for (k = 0; k < cnt[r] && pos < len && pos < max; k++, pos++) {
			dst[2*pos] = l[1+pos];
			dst[2*pos+1] = colors[st[r]];
		}
	return 2 * pos;
}

/* the style runs of a line, closed by an entry 0FFFFh; returns the count */
ushort far pascal LOADDS HelpGetLineAttr(ushort ln, int cbMax, lineattr far *la, PB pb)
{
	uchar far *l = hgetline(pb, ln);
	ushort st[128], cnt[128], nr, r, max = cbMax / sizeof(lineattr);

	if (!l || !max)
		return 0;
	nr = styles(l, st, cnt, 128);
	if (nr > max - 1)
		nr = max - 1;
	for (r = 0; r < nr; r++) {
		la[r].attr = st[r];
		la[r].cb = cnt[r];
	}
	la[nr].attr = la[nr].cb = 0xFFFF;
	return nr;
}

/* cross references: after 0FFh in the attributes, entries of start
 * column, end column (1-based, inclusive) and context string, an empty
 * string followed by a word for a local context */
typedef struct {
	uchar far *a, far *e;
} XREFS;

static void xrefs(uchar far *l, XREFS *x)
{
	uchar far *a = LATTR(l) + 1;
	x->e = LATTR(l) + LATTR(l)[0];
	if (a < x->e && *a != 0xFF) {
		a++;
		while (a + 1 < x->e && *a != 0xFF)
			a += 2;
	}
	x->a = a < x->e ? a + 1 : x->e;
}

/* next entry: start, end and string; FALSE at the end */
static f nextxref(XREFS *x, ushort *s, ushort *e, uchar far **str)
{
	uchar far *p;

	if (x->a + 2 >= x->e)
		return FALSE;
	*s = x->a[0];
	*e = x->a[1];
	*str = p = x->a + 2;
	while (p < x->e && *p)
		p++;
	if (p == *str)
		p += 2;
	x->a = p + 1;
	return TRUE;
}

/* dir 0: the first hotspot at or behind hs->line/col; dir < 0: the last
 * one before it; dir > 0: the next one that starts with character dir */
f far pascal LOADDS HelpHlNext(int dir, PB pb, hotspot far *hs)
{
	ushort ln, n = HelpcLines(pb), s, e;
	uchar far *l, far *str;
	XREFS x;
	f found = FALSE;
	hotspot best;

	if (dir < 0) {
		for (ln = 1; ln <= n && ln <= hs->line; ln++) {
			if (!(l = hgetline(pb, ln)))
				break;
			xrefs(l, &x);
			while (nextxref(&x, &s, &e, &str))
				if (ln < hs->line || s < hs->col) {
					best.line = ln;
					best.col = s;
					best.ecol = e;
					best.pXref = str;
					found = TRUE;
				}
		}
	} else {
		for (ln = hs->line ? hs->line : 1; ln <= n && !found; ln++) {
			if (!(l = hgetline(pb, ln)))
				break;
			xrefs(l, &x);
			while (nextxref(&x, &s, &e, &str)) {
				if (ln == hs->line && (dir ? s <= hs->col : e < hs->col))
					continue;
				if (dir > 0 && s <= LTEXT(l) - 1
				    && toupper(l[s]) != toupper((uchar)dir))
					continue;
				best.line = ln;
				best.col = s;
				best.ecol = e;
				best.pXref = str;
				found = TRUE;
				break;
			}
		}
	}
	if (found)
		*hs = best;
	return found;
}

/* the cross reference at hs->line/col (also sets col and ecol), NULL if
 * there is none */
char far * pascal far LOADDS HelpXRef(PB pb, hotspot far *hs)
{
	uchar far *l = hgetline(pb, hs->line), far *str;
	ushort s, e;
	XREFS x;

	if (!l)
		return NULL;
	xrefs(l, &x);
	while (nextxref(&x, &s, &e, &str))
		if (s <= hs->col && hs->col <= e) {
			hs->col = s;
			hs->ecol = e;
			hs->pXref = str;
			return (char far *)str;
		}
	return NULL;
}

/* the (first) context string of nc */
f far pascal LOADDS HelpSzContext(uchar far *dst, nc n)
{
	HDB *d = dbof(n);
	int t = topicof(d, n);
	uchar far *p;
	ushort i;

	*dst = 0;
	if (t < 0)
		return FALSE;
	p = d->ctx;
	for (i = 0; i < d->nctx; i++) {
		if (d->map[i] == t) {
			_fstrcpy((char far *)dst, (char far *)d->hdr + 0x10);
			_fstrcat((char far *)dst, "!");
			_fstrcat((char far *)dst, (char far *)p);
			return TRUE;
		}
		p += _fstrlen((char far *)p) + 1;
	}
	return FALSE;
}

/* information about the database of nc: 0 = ok, else the size needed */
int far pascal LOADDS HelpGetInfo(nc n, helpinfo far *hi, int cb)
{
	HDB *d = dbof(n);
	char *name;
	int need;
	ushort i;

	if (!d)
		return -1;
	name = Files[d->file-1].name;
	need = sizeof(helpinfo) + strlen(name);
	if (cb < need)
		return need;
	_fmemset(hi, 0, need);
	hi->fileinfo.fhHelp = Files[d->file-1].fh;
	hi->fileinfo.ncInit = (ulong)(d - Dbs + 1) << 16;
	_fmemcpy(hi->fileinfo.fname, d->hdr + 0x10, 14);
	hi->fileinfo.foff = d->base;
	if (d + 1 < Dbs + MAXDB && d[1].file == d->file)
		hi->fileinfo.ncLink = (ulong)(d - Dbs + 2) << 16;
	hi->fileinfo.hdr.wMagic = get16(d->hdr);
	hi->fileinfo.hdr.wVersion = get16(d->hdr+2);
	hi->fileinfo.hdr.wFlags = d->attrs;
	hi->fileinfo.hdr.appChar = d->ctlchar;
	hi->fileinfo.hdr.cTopics = d->ntopics;
	hi->fileinfo.hdr.cContexts = d->nctx;
	hi->fileinfo.hdr.cbWidth = d->width;
	hi->fileinfo.hdr.cPreDef = get16(d->hdr+14);
	_fmemcpy(hi->fileinfo.hdr.fname, d->hdr + 0x10, 14);
	for (i = 0; i < HS_count; i++)
		hi->fileinfo.hdr.tbPos[i] = get32(d->hdr + 0x22 + 4*i);
	_fstrcpy(hi->filename, name);
	return 0;
}

void far pascal LOADDS HelpShrink(void)
{
}

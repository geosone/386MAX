/*
 * HLPFILE.C - reading Windows 3.1 help files (WinHelp .HLP) in DOS
 *
 * The internal file system (B+ trees), |SYSTEM, |FONT, |CONTEXT,
 * |TTLBTREE, |KWBTREE/|KWDATA and the topic records of |TOPIC (also LZ77
 * and phrase compressed).  Format as described in helpdeco's helpfile.txt
 * (M. Winterhoff, GPL); linux/tools/whc.py is the compiler.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <io.h>
#include <malloc.h>
#include "HLPFILE.H"

#define TBHDR	12
#define DECOMP	0x4000

static ushort g16(uchar far *p) { return p[0] | ((ushort)p[1] << 8); }
static ulong g32(uchar far *p) { return g16(p) | ((ulong)g16(p + 2) << 16); }

static int rd(HELPFILE *hf, ulong pos, void far *buf, ushort n)
{
	if (lseek(hf->fh, pos, SEEK_SET) != (long)pos)
		return 0;
	return read(hf->fh, buf, n) == n;
}

/* --- LZ77 (help files, phrase tables) ----------------------------------- */

static ushort lz77(uchar far *src, ushort slen, uchar far *dst, ushort dmax)
{
	ushort i = 0, o = 0, mask, w, len, back;
	uchar bits;

	while (i < slen) {
		bits = src[i++];
		for (mask = 1; mask & 0xFF; mask <<= 1) {
			if (i >= slen)
				break;
			if (bits & mask) {
				if (i + 1 >= slen)
					return o;
				w = g16(src + i);
				i += 2;
				len = (w >> 12) + 3;
				back = (w & 0x0FFF) + 1;
				while (len--) {
					if (o >= dmax)
						return o;
					dst[o] = o >= back ? dst[o - back] : 0;
					o++;
				}
			} else {
				if (o >= dmax)
					return o;
				dst[o++] = src[i++];
			}
		}
	}
	return o;
}

/* --- B+ trees ------------------------------------------------------------- */

static uchar far *Page;
static ulong PageAt = NOTOPIC;

static uchar far *bt_page(HELPFILE *hf, BTREE *bt, short page)
{
	ulong at = bt->base + 38 + (ulong)page * bt->pagesize;

	if (at != PageAt) {
		if (!rd(hf, at, Page, bt->pagesize))
			return NULL;
		PageAt = at;
	}
	return Page;
}

static int bt_open(HELPFILE *hf, BTREE *bt, ulong off)
{
	uchar h[38];

	if (!rd(hf, off, h, 38) || g16(h) != 0x293B)
		return 0;
	bt->base = off;
	bt->pagesize = g16(h + 4);
	_fmemcpy(bt->fmt, h + 6, 16);
	bt->fmt[16] = 0;
	bt->root = (short)g16(h + 26);
	bt->levels = (short)g16(h + 32);
	bt->entries = (long)g32(h + 34);
	return bt->pagesize <= 4096 && bt->levels > 0;
}

static ushort fsize(char c, uchar far *p)
{
	switch (c) {
	case 'z': case 'i': case 'F':
		return _fstrlen((char far *)p) + 1;
	case 'L': case '4':
		return 4;
	case '2':
		return 2;
	}
	return 0;
}

/* size of a leaf entry */
static ushort leafsize(BTREE *bt, uchar far *p)
{
	ushort n = 0;
	char *f;

	for (f = bt->fmt; *f; f++)
		n += fsize(*f, p + n);
	return n;
}

/* the leaf entry for which cmp() is 0 (cmp < 0: entry key smaller than the
 * searched one); le: else the last one with a smaller key */
static uchar far *bt_find(HELPFILE *hf, BTREE *bt, int (*cmp)(uchar far *, void *),
			  void *arg, int le)
{
	short page = bt->root, lv, n, i;
	uchar far *p, far *pg, far *best = NULL;
	ushort ks;

	for (lv = bt->levels; lv > 1; lv--) {
		if (!(pg = bt_page(hf, bt, page)))
			return NULL;
		n = (short)g16(pg + 2);
		page = (short)g16(pg + 4);
		p = pg + 6;
		for (i = 0; i < n; i++) {
			ks = fsize(bt->fmt[0], p);
			if (cmp(p, arg) > 0)
				break;
			page = (short)g16(p + ks);
			p += ks + 2;
		}
	}
	if (!(pg = bt_page(hf, bt, page)))
		return NULL;
	n = (short)g16(pg + 2);
	p = pg + 8;
	for (i = 0; i < n; i++) {
		int c = cmp(p, arg);
		if (c == 0)
			return p;
		if (c > 0)
			break;
		best = p;
		p += leafsize(bt, p);
	}
	return le ? best : NULL;
}

/* all leaf entries */
static int bt_each(HELPFILE *hf, BTREE *bt, int (*fn)(uchar far *, void *), void *arg)
{
	short page = bt->root, lv, n, i;
	uchar far *pg, far *p;

	for (lv = bt->levels; lv > 1; lv--) {
		if (!(pg = bt_page(hf, bt, page)))
			return 0;
		page = (short)g16(pg + 4);
	}
	while (page != -1) {
		short cur = page;
		ushort o = 8;
		if (!(pg = bt_page(hf, bt, cur)))
			return 0;
		n = (short)g16(pg + 2);
		page = (short)g16(pg + 6);
		for (i = 0; i < n; i++) {
			if (!(pg = bt_page(hf, bt, cur)))	/* (fn may read pages) */
				return 0;
			p = pg + o;
			o += leafsize(bt, p);
			if (!fn(p, arg))
				return 1;
		}
	}
	return 1;
}

static int cmpname(uchar far *k, void *arg)
{
	return _fstrcmp((char far *)k, (char far *)arg);
}

/* data offset of an internal file, 0 = none */
static ulong hfile(HELPFILE *hf, char *name, ulong *size)
{
	uchar far *e = bt_find(hf, &hf->dir, cmpname, name, 0);
	ulong off;
	uchar h[9];

	if (!e)
		return 0;
	off = g32(e + _fstrlen((char far *)e) + 1);
	if (!rd(hf, off, h, 9))
		return 0;
	if (size)
		*size = g32(h + 4);
	return off + 9;
}

/* --- open ------------------------------------------------------------------- */

static void sysrec(HELPFILE *hf, ushort type, uchar far *d, ushort n)
{
	switch (type) {
	case 1:
		_fstrncpy(hf->title, (char far *)d, sizeof(hf->title) - 1);
		break;
	case 3:
		if (n >= 4)
			hf->contents = g32(d);
		break;
	case 6:
		if (n >= 90 && !hf->hascolor) {
			ushort fl = g16(d);
			hf->hascolor = 1;
			hf->srcolor = (fl & 0x100) ? g32(d + 82) : 0xFFFFFFUL;
			hf->nsrcolor = (fl & 0x200) ? g32(d + 86) : 0xFFFFFFUL;
		}
		break;
	}
}

static int phrases(HELPFILE *hf, ulong off, ulong size)
{
	uchar h[8];
	uchar far *buf;
	ulong dsize;
	ushort n, i, hl;

	if (!rd(hf, off, h, 8))
		return 0;
	n = g16(h);
	if (g16(h + 2) != 0x0100 || size > 0xFFF0UL)
		return 0;
	dsize = g32(h + 4);
	hl = 8 + 2 * (n + 1);
	if (dsize > 0xFFF0UL || size < hl)
		return 0;
	if (!(buf = _fmalloc((ushort)size)))
		return 0;
	hf->phroff = _fmalloc(2 * (n + 1));
	hf->phrtext = _fmalloc((ushort)dsize + 1);
	if (!hf->phroff || !hf->phrtext || !rd(hf, off, buf, (ushort)size)) {
		_ffree(buf);
		return 0;
	}
	for (i = 0; i <= n; i++)
		hf->phroff[i] = g16(buf + 8 + 2 * i) - 2 * (n + 1);
	lz77(buf + hl, (ushort)size - hl, (uchar far *)hf->phrtext, (ushort)dsize);
	hf->nphr = n;
	_ffree(buf);
	return 1;
}

int hlp_open(HELPFILE *hf, char *name)
{
	uchar h[16];
	ulong off, size;
	uchar far *sys;

	memset(hf, 0, sizeof(*hf));
	hf->contents = 0;
	if (!Page && !(Page = _fmalloc(4096)))
		return 0;
	PageAt = NOTOPIC;
	hf->fh = open(name, O_RDONLY | O_BINARY);
	if (hf->fh < 0)
		return 0;
	if (!rd(hf, 0, h, 16) || g32(h) != 0x00035F3FUL
	    || !bt_open(hf, &hf->dir, g32(h + 4) + 9))
		goto fail;
	/* |SYSTEM */
	off = hfile(hf, "|SYSTEM", &size);
	if (!off || size < 12 || size > 0xFFF0UL || !(sys = _fmalloc((ushort)size)))
		goto fail;
	if (rd(hf, off, sys, (ushort)size) && g16(sys) == 0x036C) {
		ushort p = 12;
		hf->minor = g16(sys + 2);
		hf->flags = g16(sys + 10);
		if (hf->minor <= 16)
			_fstrncpy(hf->title, (char far *)sys + 12, sizeof(hf->title) - 1);
		else
			while (p + 4 <= (ushort)size) {
				ushort t = g16(sys + p), n = g16(sys + p + 2);
				if (p + 4 + n > (ushort)size)
					break;
				sysrec(hf, t, sys + p + 4, n);
				p += 4 + n;
			}
	}
	_ffree(sys);
	if (hf->minor <= 16)		/* Windows 3.0 help files: not supported */
		goto fail;
	hf->lz = hf->flags == 4 || hf->flags == 8;
	hf->blocksize = hf->flags == 8 ? 2048 : 4096;
	if (!(hf->topic = hfile(hf, "|TOPIC", &hf->topiclen)))
		goto fail;
	if ((off = hfile(hf, "|CONTEXT", NULL)) != 0)
		hf->hasctx = bt_open(hf, &hf->ctx, off);
	if ((off = hfile(hf, "|TTLBTREE", NULL)) != 0)
		hf->hasttl = bt_open(hf, &hf->ttl, off);
	if ((off = hfile(hf, "|KWBTREE", NULL)) != 0)
		hf->haskw = bt_open(hf, &hf->kw, off);
	hf->kwdata = hfile(hf, "|KWDATA", NULL);
	if ((off = hfile(hf, "|Phrases", &size)) != 0)
		phrases(hf, off, size);
	return 1;
fail:
	close(hf->fh);
	hf->fh = -1;
	return 0;
}

void hlp_close(HELPFILE *hf)
{
	if (hf->fh >= 0)
		close(hf->fh);
	if (hf->phroff)
		_ffree(hf->phroff);
	if (hf->phrtext)
		_ffree(hf->phrtext);
	hf->fh = -1;
	hf->phroff = NULL;
	hf->phrtext = NULL;
}

int hlp_fonts(HELPFILE *hf, HFONT far *fonts, int max)
{
	ulong off, size;
	uchar h[8], d[11];
	ushort n, i, odesc;

	if (!(off = hfile(hf, "|FONT", &size)) || !rd(hf, off, h, 8))
		return 0;
	n = g16(h + 2);
	odesc = g16(h + 6);
	if (g16(h + 4) >= 12)		/* multimedia fonts */
		return 0;
	for (i = 0; i < n && i < max; i++) {
		if (!rd(hf, off + odesc + 11UL * i, d, 11))
			break;
		fonts[i].attr = d[0];
		fonts[i].halfpoints = d[1];
		fonts[i].rgb[0] = d[5];
		fonts[i].rgb[1] = d[6];
		fonts[i].rgb[2] = d[7];
	}
	return i;
}

/* --- contexts, titles, keywords -------------------------------------------- */

static const uchar HashTab[256] = {
	0x00, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB,
	0xDC, 0xDD, 0xDE, 0xDF, 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7,
	0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF, 0xF0, 0x0B, 0xF2, 0xF3,
	0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0x0C, 0xFF,
	0x0A, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
	0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
	0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23,
	0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0D,
	0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B,
	0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
	0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x50, 0x51, 0x52, 0x53,
	0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
	0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B,
	0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
	0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x80, 0x81, 0x82, 0x83,
	0x0B, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F,
	0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B,
	0x9C, 0x9D, 0x9E, 0x9F, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
	0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3,
	0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,
	0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB,
	0xCC, 0xCD, 0xCE, 0xCF};

long hlp_hash(char far *s)
{
	ulong h = 0;

	if (!*s)
		return 1;
	for (; *s; s++)
		h = h * 43 + (long)(signed char)HashTab[(uchar)*s];
	return (long)h;
}

static int cmphash(uchar far *k, void *arg)
{
	long a = (long)g32(k), b = *(long *)arg;
	return a < b ? -1 : a > b;
}

/* topic offset of a context (hash), NOTOPIC if unknown */
ulong hlp_context(HELPFILE *hf, long hash)
{
	uchar far *e;

	if (!hf->hasctx || !(e = bt_find(hf, &hf->ctx, cmphash, &hash, 0)))
		return NOTOPIC;
	return g32(e + 4);
}

static int cmpoff(uchar far *k, void *arg)
{
	ulong a = g32(k), b = *(ulong *)arg;
	return a < b ? -1 : a > b;
}

/* title of the topic at (or before) a topic offset */
int hlp_title(HELPFILE *hf, ulong toff, char *buf, int size)
{
	uchar far *e;

	*buf = 0;
	if (!hf->hasttl || !(e = bt_find(hf, &hf->ttl, cmpoff, &toff, 1)))
		return 0;
	_fstrncpy(buf, (char far *)e + 4, size - 1);
	buf[size - 1] = 0;
	return 1;
}

struct kwarg {
	void (*fn)(char far *, ushort, ulong, void *);
	void *arg;
	BTREE *bt;
};

static int kwone(uchar far *e, void *a)
{
	struct kwarg *k = a;
	ushort n = _fstrlen((char far *)e) + 1;
	k->fn((char far *)e, g16(e + n), g32(e + n + 2), k->arg);
	return 1;
}

int hlp_keywords(HELPFILE *hf, void (*fn)(char far *, ushort, ulong, void *), void *arg)
{
	struct kwarg k;

	if (!hf->haskw)
		return 0;
	k.fn = fn;
	k.arg = arg;
	k.bt = &hf->kw;
	return bt_each(hf, &hf->kw, kwone, &k);
}

/* topic offsets of a keyword */
int hlp_kwtopics(HELPFILE *hf, ulong off, ushort count, ulong far *dst)
{
	ushort i;
	uchar b[4];

	if (!hf->kwdata)
		return 0;
	for (i = 0; i < count; i++) {
		if (!rd(hf, hf->kwdata + off + 4UL * i, b, 4))
			return i;
		dst[i] = g32(b);
	}
	return count;
}

/* --- |TOPIC ----------------------------------------------------------------- */

static struct {
	HELPFILE *hf;
	long	blk;
	uchar far *buf;
	ushort	len;
	uchar	hdr[TBHDR];
} Cache[2];
static int CacheNext;

static int tblock(HELPFILE *hf, long blk)
{
	int i;
	ulong at = hf->topic + (ulong)blk * hf->blocksize, n;
	uchar far *raw;

	for (i = 0; i < 2; i++)
		if (Cache[i].hf == hf && Cache[i].blk == blk && Cache[i].buf)
			return i;
	if ((ulong)blk * hf->blocksize >= hf->topiclen)
		return -1;
	i = CacheNext;
	CacheNext ^= 1;
	if (!Cache[i].buf && !(Cache[i].buf = _fmalloc(DECOMP)))
		return -1;
	Cache[i].hf = NULL;
	n = hf->topiclen - (ulong)blk * hf->blocksize;
	if (n > hf->blocksize)
		n = hf->blocksize;
	if (n < TBHDR || !rd(hf, at, Cache[i].hdr, TBHDR))
		return -1;
	n -= TBHDR;
	if (hf->lz) {
		if (!(raw = _fmalloc((ushort)n)))
			return -1;
		if (!rd(hf, at + TBHDR, raw, (ushort)n)) {
			_ffree(raw);
			return -1;
		}
		Cache[i].len = lz77(raw, (ushort)n, Cache[i].buf, DECOMP);
		_ffree(raw);
	} else {
		if (!rd(hf, at + TBHDR, Cache[i].buf, (ushort)n))
			return -1;
		Cache[i].len = (ushort)n;
	}
	Cache[i].hf = hf;
	Cache[i].blk = blk;
	return i;
}

/* reads n bytes at a TOPICPOS (records may go on in the next block) */
static ushort tread(HELPFILE *hf, ulong pos, uchar far *dst, ushort n)
{
	ushort done = 0, off, k;
	long blk;
	int c;

	if (pos < TBHDR)
		return 0;
	blk = (pos - TBHDR) / DECOMP;
	off = (ushort)((pos - TBHDR) % DECOMP);
	while (done < n) {
		if ((c = tblock(hf, blk)) < 0)
			break;
		if (off < Cache[c].len) {
			k = Cache[c].len - off;
			if (k > n - done)
				k = n - done;
			_fmemcpy(dst + done, Cache[c].buf + off, k);
			done += k;
		}
		blk++;
		off = 0;
	}
	return done;
}

void hlp_freelink(TLINK *tl)
{
	if (tl->ld1)
		_ffree(tl->ld1);
	if (tl->ld2)
		_ffree(tl->ld2);
	tl->ld1 = tl->ld2 = NULL;
}

/* phrase compressed LinkData2 */
static ushort unphrase(HELPFILE *hf, uchar far *src, ushort n, uchar far *dst, ushort max)
{
	ushort i = 0, o = 0, k, a, b;

	while (i < n && o < max) {
		uchar c = src[i++];
		if (c == 0 || c > 15 || i >= n) {
			dst[o++] = c;
			continue;
		}
		k = (c * 256 - 256 + src[i++]);
		if (k / 2 < hf->nphr) {
			a = hf->phroff[k / 2];
			b = hf->phroff[k / 2 + 1];
			while (a < b && o < max)
				dst[o++] = hf->phrtext[a++];
			if ((k & 1) && o < max)
				dst[o++] = ' ';
		}
	}
	return o;
}

/* the record at a TOPICPOS */
int hlp_link(HELPFILE *hf, ulong pos, TLINK *tl)
{
	uchar h[21];
	long bsize, dlen2, dlen1;
	ushort raw;
	uchar far *r;

	tl->ld1 = tl->ld2 = NULL;
	if (pos == 0 || pos == NOTOPIC || tread(hf, pos, h, 21) != 21)
		return 0;
	bsize = (long)g32(h);
	dlen2 = (long)g32(h + 4);
	dlen1 = (long)g32(h + 16);
	tl->pos = pos;
	tl->next = g32(h + 12);
	tl->type = h[20];
	if (dlen1 < 21 || bsize < dlen1 || bsize > 0xFFF0L || dlen2 > 0xFFF0L || dlen2 < 0)
		return 0;
	tl->len1 = (ushort)(dlen1 - 21);
	raw = (ushort)(bsize - dlen1);
	tl->ld1 = _fmalloc(tl->len1 + 1);
	tl->ld2 = _fmalloc((dlen2 > raw ? (ushort)dlen2 : raw) + 1);
	if (!tl->ld1 || !tl->ld2)
		goto fail;
	if (tread(hf, pos + 21, tl->ld1, tl->len1) != tl->len1)
		goto fail;
	if (dlen2 > raw && hf->nphr) {
		if (!(r = _fmalloc(raw + 1)))
			goto fail;
		if (tread(hf, pos + dlen1, r, raw) != raw) {
			_ffree(r);
			goto fail;
		}
		tl->len2 = unphrase(hf, r, raw, tl->ld2, (ushort)dlen2);
		_ffree(r);
	} else {
		if (tread(hf, pos + dlen1, tl->ld2, raw) != raw)
			goto fail;
		tl->len2 = dlen2 < raw ? (ushort)dlen2 : raw;
	}
	tl->ld2[tl->len2] = 0;
	return 1;
fail:
	hlp_freelink(tl);
	return 0;
}

/* compressed values of LinkData1 */
static long cslong(uchar far **p)
{
	uchar far *q = *p;
	if (q[0] & 1) {
		*p += 4;
		return (long)(g32(q) >> 1) - 0x40000000L;
	}
	*p += 2;
	return (long)(g16(q) >> 1) - 0x4000;
}

static ushort cushort(uchar far **p)
{
	uchar far *q = *p;
	if (q[0] & 1) {
		*p += 2;
		return g16(q) >> 1;
	}
	*p += 1;
	return q[0] >> 1;
}

/* TOPICPOS of the topic header of the topic at a topic offset */
ulong hlp_findtopic(HELPFILE *hf, ulong toff)
{
	long blk = toff >> 15;
	ushort want = (ushort)(toff & 0x7FFF), cnt = 0;
	ulong pos, hdr;
	uchar h[28];
	uchar far *p;
	int c;

	if ((c = tblock(hf, blk)) < 0)
		return NOTOPIC;
	hdr = g32(Cache[c].hdr + 8);
	pos = g32(Cache[c].hdr + 4);
	while (pos != 0 && pos != NOTOPIC && pos >= TBHDR && (long)((pos - TBHDR) / DECOMP) == blk) {
		if (tread(hf, pos, h, 27) != 27)
			break;
		if (h[20] == 2) {
			if (cnt <= want)
				hdr = pos;
		} else if (h[20] == 0x20 || h[20] == 0x23) {
			ushort tlen;
			p = h + 21;
			cslong(&p);
			tlen = cushort(&p);
			if (cnt + tlen > want && hdr != 0)
				break;
			cnt += tlen;
		}
		pos = g32(h + 12);
	}
	return hdr ? hdr : NOTOPIC;
}

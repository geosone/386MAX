/*
 * HHELP.C - reader for Windows help files in DOS text mode
 *
 *	HHELP file.hlp
 *
 * Shows the topics of a Windows 3.1 help file (as made by linux/tools/
 * whc.py or HC31): text with the paragraph layout (indents, tab stops,
 * alignment), the colors of the help file's fonts and windows, the
 * non-scrolling region, links (Tab/Enter or the mouse), popups, Back,
 * browse sequences and the keyword search.  Pictures are shown as a mark.
 * Replaces the third-party HHELP.EXE of the original package (the DOS
 * reader of MAXHELP.HLP, started by MAXHELP.BAT).
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dos.h>
#include <i86.h>
#include <bios.h>
#include <malloc.h>
#include "HLPFILE.H"

#define MAXCOL	132
#define MAXLINES 3000
#define MAXSPANS 1500
#define MAXHOTS 600
#define PARAMAX 8192
#define MAXBACK 40
#define POPWIDTH 60

/* --- screen ----------------------------------------------------------------- */

static ushort far *Video;
static int Rows, Cols;
static ushort far *Saved;
static uchar SaveRow, SaveCol;
static ushort SaveShape;
static int Mouse;

static void screen_init(void)
{
	union REGS r;
	uchar mode = *(uchar far *)MK_FP(0x40, 0x49);

	Video = MK_FP(mode == 7 ? 0xB000 : 0xB800, 0);
	Cols = *(ushort far *)MK_FP(0x40, 0x4A);
	Rows = *(uchar far *)MK_FP(0x40, 0x84) + 1;
	if (Rows < 25 || Rows > 60)
		Rows = 25;
	if (Cols < 80 || Cols > MAXCOL)
		Cols = 80;
	Saved = _fmalloc(Rows * Cols * 2);
	if (Saved)
		_fmemcpy(Saved, Video, Rows * Cols * 2);
	r.h.ah = 3;
	r.h.bh = 0;
	int86(0x10, &r, &r);
	SaveRow = r.h.dh;
	SaveCol = r.h.dl;
	SaveShape = r.w.cx;
	r.h.ah = 1;
	r.w.cx = 0x2000;			/* cursor off */
	int86(0x10, &r, &r);
	/* bright backgrounds instead of blinking */
	r.w.ax = 0x1003;
	r.h.bl = 0;
	int86(0x10, &r, &r);
	r.w.ax = 0;
	int86(0x33, &r, &r);
	Mouse = r.w.ax == 0xFFFF;
	if (Mouse) {
		r.w.ax = 1;
		int86(0x33, &r, &r);
	}
}

static void mouse_hide(void)
{
	union REGS r;
	if (Mouse) {
		r.w.ax = 2;
		int86(0x33, &r, &r);
	}
}

static void mouse_show(void)
{
	union REGS r;
	if (Mouse) {
		r.w.ax = 1;
		int86(0x33, &r, &r);
	}
}

static void screen_done(void)
{
	union REGS r;

	mouse_hide();
	if (Saved)
		_fmemcpy(Video, Saved, Rows * Cols * 2);
	r.w.ax = 0x1003;
	r.h.bl = 1;
	int86(0x10, &r, &r);
	r.h.ah = 1;
	r.w.cx = SaveShape;
	int86(0x10, &r, &r);
	r.h.ah = 2;
	r.h.bh = 0;
	r.h.dh = SaveRow;
	r.h.dl = SaveCol;
	int86(0x10, &r, &r);
}

static void putcell(int row, int col, uchar ch, uchar attr)
{
	if (row >= 0 && row < Rows && col >= 0 && col < Cols)
		Video[row * Cols + col] = ch | (attr << 8);
}

static void putstr(int row, int col, const char *s, uchar attr, int width)
{
	while (width-- > 0)
		putcell(row, col++, *s ? (uchar)*s++ : ' ', attr);
}

/* ANSI (Windows) -> code page 437 */
static const uchar Ansi[128] = {
	'E', ' ', ',', 159, '"', '.', 197, 206, '^', '%', 'S', '<', 'O', ' ', 'Z', ' ',
	' ', '\'', '\'', '"', '"', 7, '-', '-', '~', 'T', 's', '>', 'o', ' ', 'z', 'Y',
	255, 173, 155, 156, 'o', 157, 179, 21, '"', 'c', 166, 174, 170, '-', 'R', '-',
	248, 241, 253, '3', '\'', 230, 20, 250, ',', '1', 167, 175, 172, 171, '/', 168,
	'A', 'A', 'A', 'A', 142, 143, 146, 128, 'E', 144, 'E', 'E', 'I', 'I', 'I', 'I',
	'D', 165, 'O', 'O', 'O', 'O', 153, 'x', 'O', 'U', 'U', 'U', 154, 'Y', 'P', 225,
	133, 160, 131, 'a', 132, 134, 145, 135, 138, 130, 136, 137, 141, 161, 140, 139,
	'd', 164, 149, 162, 147, 'o', 148, 246, 'o', 151, 163, 150, 129, 'y', 'p', 152};

static uchar ansi(uchar c)
{
	return c < 128 ? c : Ansi[c - 128];
}

/* --- keyboard and mouse ------------------------------------------------- */

#define K_UP	0x4800
#define K_DOWN	0x5000
#define K_PGUP	0x4900
#define K_PGDN	0x5100
#define K_HOME	0x4700
#define K_END	0x4F00
#define K_LEFT	0x4B00
#define K_RIGHT 0x4D00
#define K_STAB	0x0F00
#define K_F1	0x3B00
#define K_ALTB	0x3000
#define K_ALTC	0x2E00
#define K_ALTS	0x1F00
#define K_MOUSE 0xFFFF

static int MouseRow, MouseCol, MouseBtn;

static ushort getkey(void)
{
	union REGS r;
	static int down;

	for (;;) {
		if (_bios_keybrd(_NKEYBRD_READY)) {
			ushort k = _bios_keybrd(_NKEYBRD_READ);
			if ((k & 0xFF) == 0xE0 && (k >> 8))
				k &= 0xFF00;
			return (k & 0xFF) ? (k & 0xFF) : k & 0xFF00;
		}
		if (Mouse) {
			r.w.ax = 3;
			int86(0x33, &r, &r);
			if (r.w.bx & 3) {
				if (!down) {
					down = 1;
					MouseRow = r.w.dx / 8;
					MouseCol = r.w.cx / 8;
					MouseBtn = r.w.bx & 3;
					return K_MOUSE;
				}
			} else
				down = 0;
		}
		r.w.ax = 0x1680;		/* release the time slice */
		int86(0x2F, &r, &r);
	}
}

/* --- help file data ------------------------------------------------------ */

static HELPFILE Hf;
static HFONT far *Fonts;
static int NFonts;

static const uchar Pal[16][3] = {
	{0, 0, 0}, {0, 0, 128}, {0, 128, 0}, {0, 128, 128}, {128, 0, 0}, {128, 0, 128},
	{128, 128, 0}, {192, 192, 192}, {128, 128, 128}, {0, 0, 255}, {0, 255, 0},
	{0, 255, 255}, {255, 0, 0}, {255, 0, 255}, {255, 255, 0}, {255, 255, 255}};

static int nearest(uchar r, uchar g, uchar b, int n)
{
	int i, best = 0;
	long d, bd = 0x7FFFFFFFL;

	for (i = 0; i < n; i++) {
		long dr = (long)r - Pal[i][0], dg = (long)g - Pal[i][1], db = (long)b - Pal[i][2];
		d = dr * dr + dg * dg + db * db;
		if (d < bd) {
			bd = d;
			best = i;
		}
	}
	return best;
}

static int dark(int bg)
{
	return bg != 7 && bg != 15 && bg != 3 && bg != 2 && bg != 6;
}

/* colors of a region (background from the help window) */
typedef struct {
	uchar bg, text, bold, hot, popup, sel;
} COLORS;

static COLORS NsColors, SrColors, PopColors;

static void setcolors(COLORS *c, int bg)
{
	c->bg = bg;
	c->text = dark(bg) ? 15 : 0;
	c->bold = dark(bg) ? 15 : 1;
	c->hot = dark(bg) ? 10 : 2;
	c->popup = dark(bg) ? 11 : 3;
	c->sel = dark(bg) ? 0x2F : 0x2F;
}

/* attribute of text in font f */
static uchar fontattr(COLORS *c, int f)
{
	int fg = c->text;

	if (f >= 0 && f < NFonts) {
		HFONT far *ft = &Fonts[f];
		int autoc = (ft->rgb[0] == 1 && ft->rgb[1] == 1 && ft->rgb[2] == 0)
			|| (ft->rgb[0] == 0 && ft->rgb[1] == 0 && ft->rgb[2] == 0);
		if (!autoc)
			fg = nearest(ft->rgb[0], ft->rgb[1], ft->rgb[2], 16);
		else if (ft->attr & 1)
			fg = c->bold;
		if (fg == c->bg || (fg & 7) == c->bg)
			fg = c->text;
	}
	return (c->bg << 4) | fg;
}

/* --- layout ------------------------------------------------------------------ */

typedef struct {
	uchar ch, attr;
	short hot;
	uchar kind;			/* 0 char, 1 tab, 2 line break, 3 nbsp */
} CELL;

typedef struct {
	ushort far *line[MAXLINES];
	int	nlines;
	int	width;
	struct { short line, col, len, hot; } span[MAXSPANS];
	int	nspans;
} PAGE;

typedef struct {
	uchar	kind;			/* 1 jump, 2 popup, 3 other */
	long	hash;
} HOT;

static PAGE far *Ns, far *Sr, far *Pop;
static HOT Hots[MAXHOTS];
static int NHots;
static CELL far *Para;
static int NPara;
static PARAFMT Pf;
static int PrevSa;
static COLORS *Col;

static void page_clear(PAGE far *pg, int width)
{
	int i;
	for (i = 0; i < pg->nlines; i++)
		_ffree(pg->line[i]);
	pg->nlines = 0;
	pg->nspans = 0;
	pg->width = width;
}

static ushort far *newline(PAGE far *pg)
{
	ushort far *l;
	int i;

	if (pg->nlines >= MAXLINES || !(l = _fmalloc(Cols * 2)))
		return NULL;
	for (i = 0; i < Cols; i++)
		l[i] = ' ' | (Col->bg << 12) | (Col->text << 8);
	pg->line[pg->nlines++] = l;
	return l;
}

/* help units (twips / 10) -> columns (0.1 inch per column) */
static int ucol(int u)
{
	return u <= 0 ? -((-u * 10 + 72) / 144) : (u * 10 + 72) / 144;
}

static void addspan(PAGE far *pg, int line, int col, int hot)
{
	int n = pg->nspans;
	if (n && pg->span[n - 1].line == line && pg->span[n - 1].hot == hot
	    && pg->span[n - 1].col + pg->span[n - 1].len == col) {
		pg->span[n - 1].len++;
		return;
	}
	if (n >= MAXSPANS)
		return;
	pg->span[n].line = line;
	pg->span[n].col = col;
	pg->span[n].len = 1;
	pg->span[n].hot = hot;
	pg->nspans++;
}

/* right/center alignment of a finished line */
static void align_line(PAGE far *pg, ushort far *l, int ln, int lstart, int x, int right)
{
	int end = x, shift, k;

	if (!Pf.align)
		return;
	while (end > lstart && (l[end - 1] & 0xFF) == ' ')
		end--;
	shift = Pf.align == 1 ? right - end : (right - end) / 2;
	if (shift <= 0)
		return;
	for (k = end - 1; k >= lstart; k--)
		l[k + shift] = l[k];
	for (k = lstart; k < lstart + shift; k++)
		l[k] = ' ' | (Col->bg << 12) | (Col->text << 8);
	for (k = 0; k < pg->nspans; k++)
		if (pg->span[k].line == ln)
			pg->span[k].col += shift;
}

/* puts the collected paragraph onto lines (word wrap) */
static void para_flush(PAGE far *pg)
{
	int left = ucol(Pf.li), right = pg->width - ucol(Pf.ri), x, i, j, k;
	int sb = Pf.sb + PrevSa, keep = 1, lstart, ln;
	ushort far *l;

	if (left < 0)
		left = 0;
	if (left > pg->width - 10)
		left = pg->width - 10;
	if (right > pg->width)
		right = pg->width;
	if (right < left + 10)
		right = left + 10;
	if (sb >= 10 && pg->nlines)
		newline(pg);
	PrevSa = Pf.sa;
	if (!(l = newline(pg)))
		return;
	ln = pg->nlines - 1;
	x = left + ucol(Pf.fi);
	if (x < 0)
		x = 0;
	lstart = x;
	for (i = 0; i < NPara; ) {
		CELL far *c = &Para[i];
		if (c->kind == 2) {			/* line break */
			i++;
			keep = 1;
			goto newl;
		}
		if (c->kind == 1) {			/* tab */
			int t = -1;
			for (k = 0; k < Pf.ntabs; k++)
				if (ucol(Pf.tab[k]) > x) {
					t = ucol(Pf.tab[k]);
					break;
				}
			if (t < 0)
				t = (x / 5 + 1) * 5;
			if (t >= right) {
				keep = 0;
				i++;
				goto newl;
			}
			while (x < t) {
				if (c->hot >= 0)
					addspan(pg, ln, x, c->hot);
				l[x++] = ' ' | (c->attr << 8);
			}
			i++;
			continue;
		}
		if (c->ch == ' ' && c->kind == 0) {
			/* no spaces at the start of a wrapped line */
			if (!(x == lstart && !keep) && x < right) {
				if (c->hot >= 0)
					addspan(pg, ln, x, c->hot);
				l[x++] = ' ' | (c->attr << 8);
			}
			i++;
			continue;
		}
		/* a word */
		for (j = i; j < NPara && Para[j].kind != 1 && Para[j].kind != 2
		     && !(Para[j].ch == ' ' && Para[j].kind == 0); j++)
			;
		if (x + (j - i) > right && x > lstart) {
			keep = 0;
			goto newl;
		}
		for (; i < j && x < right; i++) {
			if (Para[i].hot >= 0)
				addspan(pg, ln, x, Para[i].hot);
			l[x++] = Para[i].ch | (Para[i].attr << 8);
		}
		if (i < j) {				/* longer than a line */
			keep = 0;
			goto newl;
		}
		continue;
newl:
		align_line(pg, l, ln, lstart, x, right);
		if (!(l = newline(pg)))
			return;
		ln = pg->nlines - 1;
		x = lstart = left;
		if (!keep)
			continue;
		keep = 0;
	}
	align_line(pg, l, ln, lstart, x, right);
	NPara = 0;
}

static void para_add(uchar ch, uchar attr, short hot, uchar kind)
{
	if (NPara < PARAMAX) {
		Para[NPara].ch = ch;
		Para[NPara].attr = attr;
		Para[NPara].hot = hot;
		Para[NPara].kind = kind;
		NPara++;
	}
}

/* --- records ------------------------------------------------------------------- */

static ushort g16(uchar far *p) { return p[0] | ((ushort)p[1] << 8); }
static ulong g32(uchar far *p) { return g16(p) | ((ulong)g16(p + 2) << 16); }

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

static short csshort(uchar far **p)
{
	uchar far *q = *p;
	if (q[0] & 1) {
		*p += 2;
		return (short)(g16(q) >> 1) - 0x4000;
	}
	*p += 1;
	return (q[0] >> 1) - 0x40;
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

static int newhot(uchar kind, long hash)
{
	if (NHots >= MAXHOTS)
		return -1;
	Hots[NHots].kind = kind;
	Hots[NHots].hash = hash;
	return NHots++;
}

/* a displayable record (0x20, 0x23) into page pg */
static void record(PAGE far *pg, TLINK *tl)
{
	uchar far *p = tl->ld1, far *end = tl->ld1 + tl->len1;
	uchar far *s = tl->ld2, far *send = tl->ld2 + tl->len2;
	uchar attr = fontattr(Col, -1);
	short hot = -1;
	int table = tl->type == 0x23;

	cslong(&p);
	cushort(&p);
	if (table) {
		uchar ncol = *p++, tt = *p++;
		if (tt == 0 || tt == 2)
			p += 2;
		p += 4 * ncol;
	}
	while (p < end) {
		ushort bits;
		if (table) {
			if ((short)g16(p) == -1)
				break;
			p += 5;
		}
		p += 4;
		bits = g16(p);
		p += 2;
		memset(&Pf, 0, sizeof(Pf));
		if (bits & 0x0001) cslong(&p);
		if (bits & 0x0002) Pf.sb = csshort(&p);
		if (bits & 0x0004) Pf.sa = csshort(&p);
		if (bits & 0x0008) csshort(&p);
		if (bits & 0x0010) Pf.li = csshort(&p);
		if (bits & 0x0020) Pf.ri = csshort(&p);
		if (bits & 0x0040) Pf.fi = csshort(&p);
		if (bits & 0x0100) {
			Pf.border = *p;
			p += 3;
		}
		if (bits & 0x0200) {
			short n = csshort(&p), i;
			for (i = 0; i < n; i++) {
				ushort t = cushort(&p);
				uchar tt = 0;
				if (t & 0x4000)
					tt = (uchar)cushort(&p);
				if (i < 32) {
					Pf.tab[i] = t & 0x3FFF;
					Pf.tabtype[i] = tt;
				}
			}
			Pf.ntabs = n < 32 ? n : 32;
		}
		Pf.align = (bits & 0x0400) ? 1 : (bits & 0x0800) ? 2 : 0;
		NPara = 0;
		for (;;) {
			uchar c;
			/* the next string */
			while (s < send && *s) {
				para_add(ansi(*s), hot >= 0 ? ((Col->bg << 4)
					 | (Hots[hot].kind == 2 ? Col->popup : Col->hot)) : attr,
					 hot, 0);
				s++;
			}
			if (s < send)
				s++;
			if (p >= end)
				break;
			c = *p++;
			if (c == 0xFF)
				break;
			switch (c) {
			case 0x20: p += 4; break;
			case 0x21: p += 2; break;
			case 0x80:
				attr = fontattr(Col, (short)g16(p));
				p += 2;
				break;
			case 0x81:
				para_add(' ', attr, -1, 2);
				break;
			case 0x82:
				para_flush(pg);
				break;
			case 0x83:
				para_add(' ', attr, hot, 1);
				break;
			case 0x86: case 0x87: case 0x88: {
				uchar t = *p++;
				long n = cslong(&p);
				if (t == 0x22)
					cushort(&p);
				p += n;
				para_add(254, attr, hot, 0);	/* picture */
				break;
			}
			case 0x89:
				hot = -1;
				break;
			case 0x8B:
				para_add(' ', attr, hot, 3);
				break;
			case 0x8C:
				break;
			case 0xC8: case 0xCC: {
				short n = (short)g16(p);
				p += 2 + (n > 3 ? n - 3 : 0);
				hot = newhot(3, 0);
				break;
			}
			case 0xE0: case 0xE2: case 0xE6:
				hot = newhot(2, (long)g32(p));
				p += 4;
				break;
			case 0xE1: case 0xE3: case 0xE7:
				hot = newhot(1, (long)g32(p));
				p += 4;
				break;
			case 0xEA: case 0xEB: case 0xEE: case 0xEF: {
				short n = (short)g16(p);
				p += 2 + n;
				hot = newhot(3, 0);
				break;
			}
			default:
				p = end;		/* unknown: stop */
				break;
			}
		}
		if (NPara)
			para_flush(pg);
		if (!table)
			break;
	}
}

/* --- topics ------------------------------------------------------------------- */

static ulong CurTopic = NOTOPIC;
static char CurTitle[128];
static ulong BrowsePrev, BrowseNext;

/* reads the topic at a topic offset into Ns and Sr (or Pop) */
static int load_topic(ulong toff, int popup)
{
	ulong hdr = hlp_findtopic(&Hf, toff), pos, ns, sr;
	TLINK tl;

	if (hdr == NOTOPIC || !hlp_link(&Hf, hdr, &tl) || tl.type != 2)
		return 0;
	if (popup) {
		page_clear(Pop, POPWIDTH - 4);
	} else {
		NHots = 0;
		page_clear(Ns, Cols - 2);
		page_clear(Sr, Cols - 2);
		_fmemcpy(CurTitle, tl.ld2, tl.len2 < 127 ? tl.len2 : 127);
		CurTitle[tl.len2 < 127 ? tl.len2 : 127] = 0;
		if (tl.len1 >= 28) {
			BrowsePrev = g32(tl.ld1 + 4);
			BrowseNext = g32(tl.ld1 + 8);
		}
	}
	ns = tl.len1 >= 28 ? g32(tl.ld1 + 16) : NOTOPIC;
	sr = tl.len1 >= 28 ? g32(tl.ld1 + 20) : NOTOPIC;
	pos = tl.next;
	hlp_freelink(&tl);
	PrevSa = 0;
	while (hlp_link(&Hf, pos, &tl)) {
		if (tl.type == 2) {
			hlp_freelink(&tl);
			break;
		}
		if (tl.type == 0x20 || tl.type == 0x23) {
			int inns = ns != NOTOPIC && (sr == NOTOPIC || pos < sr);
			PAGE far *pg = popup ? Pop : inns ? Ns : Sr;
			Col = popup ? &PopColors : inns ? &NsColors : &SrColors;
			if (!popup && !inns && pg->nlines == 0)
				PrevSa = 0;
			record(pg, &tl);
		}
		pos = tl.next;
		hlp_freelink(&tl);
		if (pos == 0 || pos == NOTOPIC)
			break;
	}
	if (!popup) {
		/* no empty lines at the end of the non-scrolling region */
		while (Ns->nlines) {
			ushort far *l = Ns->line[Ns->nlines - 1];
			int k;
			for (k = 0; k < Ns->width && (l[k] & 0xFF) == ' '; k++)
				;
			if (k < Ns->width)
				break;
			_ffree(Ns->line[--Ns->nlines]);
		}
		CurTopic = toff;
	}
	return 1;
}

/* --- display ------------------------------------------------------------------- */

static int Top;				/* first line of Sr shown */
static int Sel = -1;			/* selected hotspot */
static int NsRows, SrRow, SrRows;

static void status(const char *msg)
{
	putstr(Rows - 1, 0, msg, 0x30, Cols);
}

static void draw(void)
{
	int r, c, k;
	char buf[MAXCOL + 1];
	uchar ta = 0x70;

	mouse_hide();
	sprintf(buf, " %s", Hf.title[0] ? Hf.title : "Help");
	putstr(0, 0, buf, ta, Cols);
	NsRows = Ns->nlines;
	if (NsRows > (Rows - 3) / 2)
		NsRows = (Rows - 3) / 2;
	for (r = 0; r < NsRows; r++) {
		putcell(1 + r, 0, ' ', NsColors.bg << 4);
		for (c = 0; c < Cols - 2; c++)
			Video[(1 + r) * Cols + 1 + c] = Ns->line[r][c];
		putcell(1 + r, Cols - 1, ' ', NsColors.bg << 4);
	}
	SrRow = 1 + NsRows;
	SrRows = Rows - 1 - SrRow;
	for (r = 0; r < SrRows; r++) {
		int l = Top + r;
		putcell(SrRow + r, 0, ' ', SrColors.bg << 4);
		for (c = 0; c < Cols - 2; c++)
			Video[(SrRow + r) * Cols + 1 + c] = l < Sr->nlines ? Sr->line[l][c]
				: ' ' | (SrColors.bg << 12);
		putcell(SrRow + r, Cols - 1, ' ', SrColors.bg << 4);
	}
	/* scroll mark */
	if (Sr->nlines > SrRows) {
		int pos = (int)((long)Top * (SrRows - 1) / (Sr->nlines - SrRows));
		for (r = 0; r < SrRows; r++)
			putcell(SrRow + r, Cols - 1, r == pos ? 219 : 176, (SrColors.bg << 4) | 8);
	}
	/* selected hotspot */
	if (Sel >= 0) {
		for (k = 0; k < Ns->nspans; k++)
			if (Ns->span[k].hot == Sel && Ns->span[k].line < NsRows)
				for (c = 0; c < Ns->span[k].len; c++)
					putcell(1 + Ns->span[k].line, 1 + Ns->span[k].col + c,
						Ns->line[Ns->span[k].line][Ns->span[k].col + c] & 0xFF, NsColors.sel);
		for (k = 0; k < Sr->nspans; k++)
			if (Sr->span[k].hot == Sel && Sr->span[k].line >= Top
			    && Sr->span[k].line < Top + SrRows)
				for (c = 0; c < Sr->span[k].len; c++)
					putcell(SrRow + Sr->span[k].line - Top, 1 + Sr->span[k].col + c,
						Sr->line[Sr->span[k].line][Sr->span[k].col + c] & 0xFF, SrColors.sel);
	}
	status(" Esc Exit  Tab Link  \x11\xD9 Go  Bksp Back  C Contents  S Search  < > Browse");
	mouse_show();
}

/* first line of a hotspot in Sr, -1 if only in Ns */
static int hotline(int h)
{
	int k;
	for (k = 0; k < Sr->nspans; k++)
		if (Sr->span[k].hot == h)
			return Sr->span[k].line;
	return -1;
}

static int visible(int h)
{
	int k;
	for (k = 0; k < Ns->nspans; k++)
		if (Ns->span[k].hot == h && Ns->span[k].line < NsRows)
			return 1;
	k = hotline(h);
	return k >= Top && k < Top + SrRows;
}

/* --- popups, messages, lists ------------------------------------------------- */

static void box(int r0, int c0, int h, int w, uchar a)
{
	int r, c;
	for (r = 0; r < h; r++)
		for (c = 0; c < w; c++) {
			uchar ch = ' ';
			if (r == 0 || r == h - 1)
				ch = 205;
			if (c == 0 || c == w - 1)
				ch = 186;
			if (r == 0 && c == 0) ch = 201;
			if (r == 0 && c == w - 1) ch = 187;
			if (r == h - 1 && c == 0) ch = 200;
			if (r == h - 1 && c == w - 1) ch = 188;
			putcell(r0 + r, c0 + c, ch, a);
		}
}

static void message(const char *s)
{
	int w = strlen(s) + 6, c0 = (Cols - w) / 2, r0 = Rows / 2 - 2;
	mouse_hide();
	box(r0, c0, 3, w, 0x4F);
	putstr(r0 + 1, c0 + 3, s, 0x4F, w - 6);
	mouse_show();
	getkey();
	draw();
}

static void popup(ulong toff)
{
	int h, w = POPWIDTH, r0, c0, r, c, top = 0, rows;
	ushort k;
	int nh = NHots;

	if (!load_topic(toff, 1)) {
		NHots = nh;
		message("Topic not found");
		return;
	}
	NHots = nh;
	for (;;) {
		h = Pop->nlines + 2;
		if (h > Rows - 4)
			h = Rows - 4;
		rows = h - 2;
		r0 = (Rows - h) / 2;
		c0 = (Cols - w) / 2;
		mouse_hide();
		box(r0, c0, h, w, (PopColors.bg << 4) | PopColors.text);
		for (r = 0; r < rows; r++)
			for (c = 0; c < w - 4; c++)
				Video[(r0 + 1 + r) * Cols + c0 + 2 + c] = top + r < Pop->nlines
					? Pop->line[top + r][c] : ' ' | (PopColors.bg << 12);
		mouse_show();
		k = getkey();
		if (k == K_DOWN && top + rows < Pop->nlines)
			top++;
		else if (k == K_UP && top > 0)
			top--;
		else
			break;
	}
	draw();
}

/* keyword search */
typedef struct {
	char far *kw;
	ushort	count;
	ulong	off;
} KWE;

static KWE far *Kws;
static int NKws, MaxKws;
static char far *KwText;
static ushort KwUsed, KwMax;

static void kwcollect(char far *kw, ushort count, ulong off, void *arg)
{
	ushort n = _fstrlen(kw) + 1;
	(void)arg;
	if (NKws >= MaxKws || KwUsed + n > KwMax)
		return;
	_fmemcpy(KwText + KwUsed, kw, n);
	Kws[NKws].kw = KwText + KwUsed;
	Kws[NKws].count = count;
	Kws[NKws].off = off;
	KwUsed += n;
	NKws++;
}

/* list box: returns the chosen index or -1 */
static int listbox(const char *title, int n, void (*item)(int, char *, int), int sel, int search)
{
	int w = Cols - 16, h = Rows - 6, r0 = 3, c0 = 8, rows = h - 4, top = 0, r;
	char buf[MAXCOL + 1], typed[40];
	int nt = 0;
	ushort k;

	typed[0] = 0;
	for (;;) {
		if (sel < 0)
			sel = 0;
		if (sel >= n)
			sel = n - 1;
		if (sel < top)
			top = sel;
		if (sel >= top + rows)
			top = sel - rows + 1;
		mouse_hide();
		box(r0, c0, h, w, 0x70);
		putstr(r0, c0 + 2, title, 0x70, strlen(title));
		if (search) {
			sprintf(buf, "Search: %s_", typed);
			putstr(r0 + 1, c0 + 2, buf, 0x70, w - 4);
		}
		for (r = 0; r < rows; r++) {
			buf[0] = 0;
			if (top + r < n)
				item(top + r, buf, w - 6);
			putstr(r0 + 2 + r, c0 + 2, "", 0x70, 1);
			putstr(r0 + 2 + r, c0 + 3, buf, top + r == sel ? 0x1F : 0x70, w - 5);
		}
		putstr(r0 + h - 1, c0 + 2, " \x18\x19 Select  \x11\xD9 Show  Esc Cancel ", 0x70, 36);
		mouse_show();
		k = getkey();
		switch (k) {
		case 27:
			return -1;
		case 13:
			return n ? sel : -1;
		case K_UP: sel--; break;
		case K_DOWN: sel++; break;
		case K_PGUP: sel -= rows; break;
		case K_PGDN: sel += rows; break;
		case K_HOME: sel = 0; break;
		case K_END: sel = n - 1; break;
		case K_MOUSE:
			if (MouseRow >= r0 + 2 && MouseRow < r0 + 2 + rows && top + MouseRow - r0 - 2 < n) {
				if (sel == top + MouseRow - r0 - 2)
					return sel;
				sel = top + MouseRow - r0 - 2;
			}
			break;
		default:
			if (search && (k == 8 || (k >= ' ' && k < 256))) {
				int i;
				if (k == 8) {
					if (nt)
						typed[--nt] = 0;
				} else if (nt < 38) {
					typed[nt++] = (char)k;
					typed[nt] = 0;
				}
				for (i = 0; i < n; i++) {
					item(i, buf, sizeof(buf) - 1);
					if (strnicmp(buf, typed, nt) >= 0)
						break;
				}
				sel = i;
			}
		}
	}
}

static void kwitem(int i, char *buf, int w)
{
	int k;
	for (k = 0; k < w && Kws[i].kw[k]; k++)
		buf[k] = ansi(Kws[i].kw[k]);
	buf[k] = 0;
}

static ulong far *TopicList;
static int NTopicList;

static void titem(int i, char *buf, int w)
{
	char t[128];
	int k;
	hlp_title(&Hf, TopicList[i], t, sizeof(t));
	for (k = 0; k < w && t[k]; k++)
		buf[k] = ansi(t[k]);
	buf[k] = 0;
}

/* --- navigation -------------------------------------------------------------- */

static struct { ulong toff; int top; } Back[MAXBACK];
static int NBack;

static void go(ulong toff, int record)
{
	ulong old = CurTopic;
	int oldtop = Top;

	if (toff == NOTOPIC)
		return;
	if (!load_topic(toff, 0)) {
		if (old != NOTOPIC)
			load_topic(old, 0);
		message("Topic not found");
		return;
	}
	if (record && old != NOTOPIC) {
		if (NBack == MAXBACK) {
			memmove(Back, Back + 1, sizeof(Back[0]) * (MAXBACK - 1));
			NBack--;
		}
		Back[NBack].toff = old;
		Back[NBack].top = oldtop;
		NBack++;
	}
	Top = 0;
	Sel = -1;
}

static void follow(int h)
{
	ulong t;

	if (h < 0 || h >= NHots)
		return;
	if (Hots[h].kind == 3) {
		message("This link is not supported in DOS");
		return;
	}
	t = hlp_context(&Hf, Hots[h].hash);
	if (t == NOTOPIC) {
		message("Topic not found");
		return;
	}
	if (Hots[h].kind == 2)
		popup(t);
	else
		go(t, 1);
}

static void search(void)
{
	int i;

	if (!Kws) {
		MaxKws = 2000;
		KwMax = 0xFF00;
		Kws = _fmalloc(sizeof(KWE) * MaxKws);
		KwText = _fmalloc(KwMax);
		if (!Kws || !KwText) {
			message("Not enough memory");
			return;
		}
		hlp_keywords(&Hf, kwcollect, NULL);
	}
	if (!NKws) {
		message("This help file has no keywords");
		return;
	}
	i = listbox(" Search ", NKws, kwitem, 0, 1);
	draw();
	if (i < 0)
		return;
	if (TopicList)
		_ffree(TopicList);
	TopicList = _fmalloc(4 * (Kws[i].count + 1));
	if (!TopicList)
		return;
	NTopicList = hlp_kwtopics(&Hf, Kws[i].off, Kws[i].count, TopicList);
	if (NTopicList == 1)
		go(TopicList[0], 1);
	else if (NTopicList > 1) {
		int t = listbox(" Topics ", NTopicList, titem, 0, 0);
		if (t >= 0)
			go(TopicList[t], 1);
	}
}

static void usage(void)
{
	puts("HHELP - reader for Windows help files\n"
	     "usage: HHELP file.hlp\n"
	     "Open 386MAX - GNU General Public License version 3.");
}

/* the help file: as given, else next to HHELP.EXE */
static int openhelp(char *name, char **argv0)
{
	char path[160], *p;

	if (hlp_open(&Hf, name))
		return 1;
	strncpy(path, argv0[0], sizeof(path) - 20);
	path[sizeof(path) - 20] = 0;
	p = strrchr(path, '\\');
	if (!p)
		return 0;
	strcpy(p + 1, name);
	return hlp_open(&Hf, path);
}

int main(int argc, char **argv)
{
	ushort k;
	int i, done = 0;

	if (argc < 2 || argv[1][0] == '/' && argv[1][1] == '?') {
		usage();
		return 1;
	}
	if (!openhelp(argv[1], argv)) {
		printf("HHELP: can't open %s as a Windows 3.1 help file\n", argv[1]);
		return 1;
	}
	Fonts = _fmalloc(sizeof(HFONT) * 256);
	Ns = _fmalloc(sizeof(PAGE));
	Sr = _fmalloc(sizeof(PAGE));
	Pop = _fmalloc(sizeof(PAGE));
	Para = _fmalloc(sizeof(CELL) * PARAMAX);
	if (!Fonts || !Ns || !Sr || !Pop || !Para) {
		puts("HHELP: not enough memory");
		return 1;
	}
	Ns->nlines = Sr->nlines = Pop->nlines = 0;
	NFonts = hlp_fonts(&Hf, Fonts, 256);
	screen_init();
	setcolors(&NsColors, Hf.hascolor ? nearest((uchar)Hf.nsrcolor, (uchar)(Hf.nsrcolor >> 8),
				  (uchar)(Hf.nsrcolor >> 16), 8) : 1);
	setcolors(&SrColors, Hf.hascolor ? nearest((uchar)Hf.srcolor, (uchar)(Hf.srcolor >> 8),
				  (uchar)(Hf.srcolor >> 16), 8) : 7);
	if (NsColors.bg == SrColors.bg)
		setcolors(&NsColors, SrColors.bg == 1 ? 3 : 1);
	setcolors(&PopColors, SrColors.bg);
	go(Hf.contents, 0);
	if (CurTopic == NOTOPIC) {
		screen_done();
		printf("HHELP: no contents topic in %s\n", argv[1]);
		return 1;
	}
	while (!done) {
		draw();
		k = getkey();
		switch (k) {
		case 27:
			done = 1;
			break;
		case K_UP:
			if (Top > 0) Top--;
			break;
		case K_DOWN:
			if (Top + SrRows < Sr->nlines) Top++;
			break;
		case K_PGUP:
			Top -= SrRows - 1;
			if (Top < 0) Top = 0;
			break;
		case K_PGDN:
			Top += SrRows - 1;
			if (Top > Sr->nlines - SrRows) Top = Sr->nlines - SrRows;
			if (Top < 0) Top = 0;
			break;
		case K_HOME:
			Top = 0;
			break;
		case K_END:
			Top = Sr->nlines - SrRows;
			if (Top < 0) Top = 0;
			break;
		case 9: case K_STAB: {
			/* next / previous link (in the visible part first) */
			int n = NHots, s = Sel, step = k == 9 ? 1 : -1, tries;
			if (!n)
				break;
			for (tries = 0; tries < n; tries++) {
				s = s < 0 ? (step > 0 ? 0 : n - 1) : (s + step + n) % n;
				if (visible(s))
					break;
			}
			if (tries == n) {	/* none visible: scroll to the next */
				s = Sel < 0 ? 0 : (Sel + step + n) % n;
				if (hotline(s) >= 0) {
					Top = hotline(s);
					if (Top > Sr->nlines - SrRows) Top = Sr->nlines - SrRows;
					if (Top < 0) Top = 0;
				}
			}
			Sel = s;
			break;
		}
		case 13:
			if (Sel >= 0)
				follow(Sel);
			break;
		case 8: case K_ALTB:
			if (NBack) {
				NBack--;
				go(Back[NBack].toff, 0);
				Top = Back[NBack].top;
				if (Top > Sr->nlines - SrRows) Top = Sr->nlines - SrRows;
				if (Top < 0) Top = 0;
			}
			break;
		case 'c': case 'C': case 'i': case 'I': case K_ALTC:
			go(Hf.contents, 1);
			break;
		case 's': case 'S': case K_ALTS:
			search();
			break;
		case '<': case ',':
			if (BrowsePrev != NOTOPIC)
				go(BrowsePrev, 1);
			break;
		case '>': case '.':
			if (BrowseNext != NOTOPIC)
				go(BrowseNext, 1);
			break;
		case K_MOUSE: {
			int hit = -1;
			if (MouseBtn & 2) {		/* right button: back */
				if (NBack) {
					NBack--;
					go(Back[NBack].toff, 0);
					Top = Back[NBack].top;
				}
				break;
			}
			for (i = 0; i < Ns->nspans; i++)
				if (MouseRow == 1 + Ns->span[i].line && Ns->span[i].line < NsRows
				    && MouseCol >= 1 + Ns->span[i].col && MouseCol < 1 + Ns->span[i].col + Ns->span[i].len)
					hit = Ns->span[i].hot;
			for (i = 0; i < Sr->nspans; i++)
				if (MouseRow == SrRow + Sr->span[i].line - Top
				    && MouseCol >= 1 + Sr->span[i].col && MouseCol < 1 + Sr->span[i].col + Sr->span[i].len)
					hit = Sr->span[i].hot;
			if (hit >= 0) {
				Sel = hit;
				draw();
				follow(hit);
			} else if (MouseRow == Rows - 1)
				done = MouseCol < 10;
			break;
		}
		}
	}
	screen_done();
	hlp_close(&Hf);
	return 0;
}

/*
 * HLPFILE.H - reading Windows 3.1 help files (WinHelp .HLP) in DOS
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#ifndef HLPFILE_H
#define HLPFILE_H

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned long ulong;

#define NOTOPIC 0xFFFFFFFFUL

/* a B+ tree in an internal file */
typedef struct {
	ulong	base;			/* file offset of the tree header	*/
	ushort	pagesize;
	short	root, levels;
	long	entries;
	char	fmt[17];		/* structure string		*/
} BTREE;

typedef struct {
	int	fh;
	char	title[128];
	ulong	contents;		/* topic offset of the contents	*/
	ushort	minor, flags;
	int	lz;			/* topic blocks LZ77 compressed */
	ushort	blocksize;
	ulong	topic, topiclen;	/* |TOPIC data in the file	*/
	BTREE	dir, ctx, ttl, kw;
	int	hasctx, hasttl, haskw;
	ulong	kwdata; 		/* |KWDATA data offset, 0 = none */
	ushort	nphr;			/* phrases (|Phrases)		*/
	ushort far *phroff;
	char far *phrtext;
	ulong	nsrcolor;		/* colors of the main window	*/
	ulong	srcolor;
	int	hascolor;
} HELPFILE;

/* paragraph format of a displayable record */
typedef struct {
	short	sb, sa, li, ri, fi;	/* help units (twips / 10)	*/
	int	align;			/* 0 left, 1 right, 2 center	*/
	int	ntabs;
	short	tab[32];
	uchar	tabtype[32];
	int	border;
} PARAFMT;

/* a font of |FONT */
typedef struct {
	uchar	attr;			/* 1 bold 2 italic 4 underline	*/
	uchar	halfpoints;
	uchar	rgb[3];
} HFONT;

int	hlp_open(HELPFILE *hf, char *name);
void	hlp_close(HELPFILE *hf);
int	hlp_fonts(HELPFILE *hf, HFONT far *fonts, int max);
ulong	hlp_context(HELPFILE *hf, long hash);
long	hlp_hash(char far *name);
int	hlp_title(HELPFILE *hf, ulong toff, char *buf, int size);
int	hlp_keywords(HELPFILE *hf, void (*fn)(char far *kw, ushort count, ulong off, void *arg), void *arg);
int	hlp_kwtopics(HELPFILE *hf, ulong off, ushort count, ulong far *dst);
ulong	hlp_findtopic(HELPFILE *hf, ulong toff);

/* the records of a topic: topic header and displayable records */
typedef struct {
	ulong	pos;			/* TOPICPOS of the record	*/
	ulong	next;
	uchar	type;
	uchar far *ld1;
	ushort	len1;
	uchar far *ld2;
	ushort	len2;
} TLINK;

int	hlp_link(HELPFILE *hf, ulong pos, TLINK *tl);
void	hlp_freelink(TLINK *tl);

#endif

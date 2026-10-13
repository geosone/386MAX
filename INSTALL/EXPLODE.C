/******************************************************************************
 *									      *
 * Open 386MAX - GNU General Public License version 3.			      *
 *									      *
 * EXPLODE.C								      *
 *									      *
 * Open source replacement for the decompression part of the PKWARE Data     *
 * Compression Library (IMPLODE.LIB): explode() and crc32() with the same    *
 * interface (IMPLODE.H).  The compressed format follows the description in  *
 * zlib's contrib/blast/blast.c by Mark Adler; the archives are made by      *
 * linux/tools/qpack.py.						      *
 *									      *
 ******************************************************************************/

#include <setjmp.h>
#include <implode.h>

#define MAXBITS 13		/* Maximum code length */
#define MAXWIN	4096		/* Maximum window size */
#define INSIZE	2048		/* Input buffer in work_buff after the window */

/* Huffman code: number of codes per length and symbols in code order */
typedef struct {
	short count[MAXBITS + 1];
	short symbol[256];
} HUFF;

/* State of one explode() call */
typedef struct {
	unsigned (far pascal *rd)(char far *, unsigned short far *);
	void (far pascal *wr)(char far *, unsigned short far *);
	unsigned char far *in;	/* Next input byte */
	unsigned left;		/* Bytes left in the input buffer */
	unsigned char far *inbuf;
	unsigned long bitbuf;	/* Bit buffer */
	int bitcnt;		/* Bits in bitbuf */
	unsigned char far *out; /* Output window */
	unsigned next;		/* Next position in the window */
	int first;		/* TRUE until the window was written once */
	jmp_buf env;		/* Error exit */
} STATE;

/* Compact code length tables: low 4 bits length, high 4 bits repeat-1 */
static const unsigned char litlen[] = {
	11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23, 8,
	9, 7, 6, 7, 8, 7, 6, 55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7, 22, 5,
	7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9, 8, 25, 11, 8, 11, 9, 12,
	8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24, 10, 27,
	44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61, 12, 45,
	44, 173};
static const unsigned char lenlen[] = {2, 35, 36, 53, 38, 23};
static const unsigned char distlen[] = {2, 20, 53, 230, 247, 151, 248};
static const short base[16] = {
	3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264};
static const char extra[16] = {
	0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8};

static HUFF litcode, lencode, distcode;
static int built;

static void construct(HUFF *h, const unsigned char *rep, int n)
{
	short length[256];
	short offs[MAXBITS + 1];
	int sym, len, k;

	for (sym = 0; n--; rep++) {
		for (k = (*rep >> 4) + 1; k; k--)
			length[sym++] = *rep & 15;
	}
	for (len = 0; len <= MAXBITS; len++) h->count[len] = 0;
	for (k = 0; k < sym; k++) h->count[length[k]]++;
	offs[1] = 0;
	for (len = 1; len < MAXBITS; len++)
		offs[len + 1] = offs[len] + h->count[len];
	for (k = 0; k < sym; k++)
		if (length[k]) h->symbol[offs[length[k]]++] = k;
}

static void flush(STATE *s, unsigned n)
{
	unsigned short size = n;

	s->wr((char far *) s->out, &size);
}

static int bits(STATE *s, int need)
{
	unsigned long val = s->bitbuf;

	while (s->bitcnt < need) {
		if (s->left == 0) {
			unsigned short size = INSIZE;

			s->left = s->rd((char far *) s->inbuf, &size);
			s->in = s->inbuf;
			if (s->left == 0) longjmp(s->env, CMP_BAD_DATA);
		}
		val |= (unsigned long) *s->in++ << s->bitcnt;
		s->left--;
		s->bitcnt += 8;
	}
	s->bitbuf = val >> need;
	s->bitcnt -= need;
	return (int) (val & ((1UL << need) - 1));
}

/* Decode a symbol: the codes are stored bit-inverted, first bit first */
static int decode(STATE *s, HUFF *h)
{
	int len, code = 0, first = 0, index = 0, count;

	for (len = 1; len <= MAXBITS; len++) {
		code |= bits(s, 1) ^ 1;
		count = h->count[len];
		if (code < first + count) return h->symbol[index + (code - first)];
		index += count;
		first = (first + count) << 1;
		code <<= 1;
	}
	longjmp(s->env, CMP_BAD_DATA);
	return -1;
}

unsigned far pascal explode(
	unsigned (far pascal * read_buff)(char far *buffer,unsigned short far *size),
	void (far pascal * write_buff)(char far *buffer,unsigned short far *size),
	char far *work_buff)
{
	STATE s;
	int lit, dict, len, symbol, err;
	unsigned dist, from;

	if (!built) {
		construct(&litcode, litlen, sizeof(litlen));
		construct(&lencode, lenlen, sizeof(lenlen));
		construct(&distcode, distlen, sizeof(distlen));
		built = 1;
	}

	s.rd = read_buff;
	s.wr = write_buff;
	s.out = (unsigned char far *) work_buff;
	s.inbuf = s.out + MAXWIN;
	s.left = 0;
	s.bitbuf = 0;
	s.bitcnt = 0;
	s.next = 0;
	s.first = 1;

	if ((err = setjmp(s.env)) != 0) return err;

	lit = bits(&s, 8);
	if (lit > 1) return CMP_INVALID_MODE;
	dict = bits(&s, 8);
	if (dict < 4 || dict > 6) return CMP_INVALID_DICTSIZE;

	for (;;) {
		if (bits(&s, 1)) {
			/* Length and distance */
			symbol = decode(&s, &lencode);
			len = base[symbol] + bits(&s, extra[symbol]);
			if (len == 519) break;		/* End of data */
			symbol = len == 2 ? 2 : dict;
			dist = (decode(&s, &distcode) << symbol) + bits(&s, symbol) + 1;
			if (s.first && dist > s.next) return CMP_BAD_DATA;
			do {
				from = (s.next - dist) & (MAXWIN - 1);
				s.out[s.next++] = s.out[from];
				if (s.next == MAXWIN) {
					flush(&s, MAXWIN);
					s.next = 0;
					s.first = 0;
				}
			} while (--len);
		}
		else {
			/* Literal */
			symbol = lit ? decode(&s, &litcode) : bits(&s, 8);
			s.out[s.next++] = (unsigned char) symbol;
			if (s.next == MAXWIN) {
				flush(&s, MAXWIN);
				s.next = 0;
				s.first = 0;
			}
		}
	}
	if (s.next) flush(&s, s.next);
	return CMP_NO_ERROR;
}

/* CRC-32 (polynomial EDB88320h) of size bytes, starting from *old_crc */
unsigned long far pascal crc32(
	unsigned char far *buffer,
	unsigned short far *size,
	unsigned long far *old_crc)
{
	static unsigned long table[256];
	static int done;
	unsigned long c;
	unsigned n;
	int k;

	if (!done) {
		for (n = 0; n < 256; n++) {
			c = n;
			for (k = 0; k < 8; k++)
				c = c & 1 ? (c >> 1) ^ 0xEDB88320UL : c >> 1;
			table[n] = c;
		}
		done = 1;
	}
	c = *old_crc;
	for (n = *size; n; n--)
		c = table[(unsigned char) (c ^ *buffer++)] ^ (c >> 8);
	return c;
}

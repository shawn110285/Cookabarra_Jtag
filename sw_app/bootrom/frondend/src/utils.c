
#include "../include/uart.h"
#include "../include/utils.h"

static unsigned char asciiToHex(char ascii);
static unsigned int hexToBin(const char *hex);

static unsigned char asciiToHex(char ascii)
{
    unsigned char result;

    if(ascii <= '9' && ascii >= '0')
    {
        result = ascii - '0';
    }
    else if(ascii >= 'a' && ascii <= 'f')
    {
        result = ascii - 'a' + 10;
    }
    else if(ascii >= 'A' && ascii <= 'F')
    {
        result = ascii - 'A' + 10;
    }
    else
    {
        result = 0xFF;
    }

    return result;
}

static unsigned int hexToBin(const char *hex)
{
    unsigned int temp;

    temp = asciiToHex(hex[0]) << 4;
    temp |= asciiToHex(hex[1]);

    return temp;
}

#if 0
unsigned char hexStringToBin(const char * str, ihex_format_t *hex)
{
    unsigned char result = 0;


    unsigned int offset;
    unsigned int index;
    unsigned char checkSum;
    unsigned int temp;

    /* start */
    if(str[0] != ':')
    {
        result = RESPONE_FAIL;
    }

    offset = 0;
    checkSum = 0;

    /* length */
    offset ++;
    hex->length = hexToBin(str + offset);
    checkSum += hex->length;

    /* A record with 16-byte length data */
    if(hex->length > 16)
    {
        result = RESPONE_FAIL;
    }

    /* 2-byte address */
    hex->address = 0;
    for(index = 0;index < 2;index ++)
    {
        offset += 2;
        temp = hexToBin(str + offset);
        checkSum += temp;
        hex->address |= temp << 8 * (1 - index);
    }

    /* 1-byte type */
    offset += 2;
    hex->type = hexToBin(str + offset);
    checkSum += hex->type;

    /* data */
    for(index = 0;index < hex->length ;index ++)
    {
        offset += 2;
        temp = hexToBin(str + offset);
        hex->data[index] = temp;
        checkSum += temp;
    }

    /* checksum */
    offset += 2;
    temp = hexToBin(str + offset);
    if(temp == (unsigned int)(0x100 - checkSum)) /* CRC = The two's complement of 'checkSum' */
    {
        result = RESPONE_SUCCESS;
    }
    else
    {
        result = RESPONE_FAIL;
    }

    return result;
}
#endif





/*----------------------------------------------*/
/* Formatted string output                      */
/*----------------------------------------------*/
/*  xprintf("%d", 1234);			"1234"
    xprintf("%6d,%3d%%", -200, 5);	"  -200,  5%"
    xprintf("%-6u", 100);			"100   "
    xprintf("%ld", 12345678L);		"12345678"
    xprintf("%04x", 0xA3);			"00a3"
    xprintf("%08LX", 0x123ABC);		"00123ABC"
    xprintf("%016b", 0x550F);		"0101010100001111"
    xprintf("%s", "String");		"String"
    xprintf("%-4s", "abc");			"abc "
    xprintf("%4s", "abc");			" abc"
    xprintf("%c", 'a');				"a"
    xprintf("%f", 10.0);            <xprintf lacks floating point support>
*/

void xvprintf(const char* fmt, va_list arp )
{
	unsigned int r, i, j, w, f;
	unsigned long v;
	char s[16], c, d, *p;

	for (;;)
    {
		c = *fmt++;					/* Get a char */
		if (!c) break;				/* End of format? */
		if (c != '%')
    {				/* Pass through it if not a % sequense */
			uart_send_char(c); continue;
		}

		f = 0;
		c = *fmt++;					/* Get first char of the sequense */
		if (c == '0')
    {				/* Flag: '0' padded */
			f = 1; c = *fmt++;
		}
    else
    {
			if (c == '-')
      {			/* Flag: left justified */
				f = 2; c = *fmt++;
			}
		}

		for (w = 0; c >= '0' && c <= '9'; c = *fmt++)	/* Minimum width */
			w = w * 10 + c - '0';

		if (c == 'l' || c == 'L')
    {	/* Prefix: Size is long int */
			f |= 4; c = *fmt++;
		}

		if (!c) break;				/* End of format? */
		d = c;
		if (d >= 'a') d -= 0x20;
		switch (d)
    {				/* Type is... */
		case 'S' :					/* String */
			p = va_arg(arp, char*);
			for (j = 0; p[j]; j++) ;
			while (!(f & 2) && j++ < w) uart_send_char(' ');
			uart_send_string(p);
			while (j++ < w) uart_send_char(' ');
			continue;

		case 'C' :					/* Character */
			uart_send_char((char)va_arg(arp, int));
      continue;

		case 'B' :					/* Binary */
			r = 2; break;

		case 'O' :					/* Octal */
			r = 8; break;

		case 'D' :					/* Signed decimal */
		case 'U' :					/* Unsigned decimal */
			r = 10; break;

		case 'X' :					/* Hexdecimal */
			r = 16; break;

		default:					/* Unknown type (passthrough) */
			uart_send_char(c); continue;
		}

		/* Get an argument and put it in numeral */
		v = (f & 4) ? va_arg(arp, long) : ((d == 'D') ? (long)va_arg(arp, int) : (long)va_arg(arp, unsigned int));
		if (d == 'D' && (v & 0x80000000))
    {
			v = 0 - v;
			f |= 8;
		}
		i = 0;
		do
    {
			d = (char)(v % r); v /= r;
			if (d > 9) d += (c == 'x') ? 0x27 : 0x07;
			s[i++] = d + '0';
		} while (v && i < sizeof(s));

		if (f & 8) s[i++] = '-';
		j = i; d = (f & 1) ? '0' : ' ';
		while (!(f & 2) && j++ < w) uart_send_char(d);
		do uart_send_char(s[--i]); while(i);
		while (j++ < w) uart_send_char(' ');
	}
}

void xprintf (const char*	fmt,  ... )
{
	va_list arp;

	va_start(arp, fmt);
	xvprintf(fmt, arp);
	va_end(arp);
}


#ifndef _UTILS_H_
#define _UTILS_H_

#include <stdarg.h>

extern int put_char(char c);
extern int put_str(const char *str);
extern void put_hex(unsigned int  h);
extern void xvprintf(const char* fmt, va_list arp );
extern void xprintf (const char* fmt,  ... );

#endif /* _UTILS_H_ */

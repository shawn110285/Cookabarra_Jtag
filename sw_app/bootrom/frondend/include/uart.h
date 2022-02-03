
#ifndef _UART_H_
#define _UART_H_

extern void uart_init(void);
extern void uart_send_char(char ch);
extern void uart_send_hex(unsigned int  h);
extern void uart_send_string(char *str);

extern char uart_check_rx_buf();
extern char uart_read_char();
extern void uart_read_string(char *str,unsigned int num);

#endif /* _UART_H_ */

#include "../include/reg.h"
#include "../include/uart.h"

// 115200bps, 8 N 1
void uart_init()
{
    //config the baud_rate to 115200
    DEV_WRITE((UART_BASE + UART_BAUD), 0x1b8);
    // enable tx and rx
    DEV_WRITE((UART_BASE + UART_CTRL), 0x3);
}

// send one char to uart
void uart_send_char(char ch)
{
    while (DEV_READ(UART_BASE + UART_STATUS) & 0x1);
    DEV_WRITE((UART_BASE + UART_TXDATA), ch);
}


void uart_send_hex(unsigned int  h)
{
    int cur_digit;
    // Iterate through h taking top 4 bits each time and outputting ASCII of hex
    // digit for those 4 bits
    for (int i = 0; i < 8; i++)
    {
        cur_digit = h >> 28;

        if (cur_digit < 10)
        uart_send_char('0' + cur_digit);
        else
        uart_send_char('A' - 10 + cur_digit);

        h <<= 4;
    }
}

void uart_send_string(char *str)
{
    while (*str != '\0')
    {
        uart_send_char(*str);
        str++;
    }
}

char uart_check_rx_buf()
{
    return (DEV_READ(UART_BASE + UART_STATUS) & 0x2);
}

// Block, get one char from uart.
char uart_read_char()
{
    while (!(DEV_READ(UART_BASE + UART_STATUS) & 0x2));
    DEV_WRITE((UART_BASE + UART_STATUS), 0x0);  //clear the rx status
    return (DEV_READ(UART_BASE + UART_RXDATA) & 0xff);
}


void uart_read_string(char *str, unsigned int length)
{
    unsigned int index;
    char temp;

    index = 0;
    temp = 0;

    while (1)
    {
        temp = uart_read_char();
        // uart_send_char(temp);

        if (temp == '\r' || temp == '\n')
        {
            uart_send_char('\n');
            break;
        }

        if (index < length)
        {
            str[index] = temp;
            index++;
        }
    }

    str[index] = '\0';
}



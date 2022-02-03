#include <stdint.h>
#include "../include/reg.h"
#include "../include/timer.h"
#include "../include/uart.h"
#include "../include/utils.h"


static uint32_t readmcause()
{
    unsigned long long  val;
    asm volatile("csrr %0, mcause" : "=r"(val));
    return val;
}


void general_exeception_handler()
{
    DEV_WRITE((GPIO_BASE + GPIO_OUT), get_mcause()&0xF);
    uart_send_string("exception handler!!! \r\n");
    uart_send_string("============ \r\n");
    uart_send_string("\r\nMTVEC:  0x");
    uart_send_hex(get_mtvec());
    uart_send_string("\r\nMEPC:   0x");
    uart_send_hex(get_mepc());
    uart_send_string("\r\nMCAUSE: 0x");
    uart_send_hex(get_mcause());
    uart_send_string("\r\nMTVAL:  0x");
    uart_send_hex(get_mtval());
    uart_send_string("\r\nhalt the processor\r\n");
    while(1);
}

void handle_trap(uint32_t cause, uint32_t  epc, uint32_t regs[32])
{
    if(readmcause() == 0x80000007)  //timer interrupt
    {
        uint32_t  led = DEV_READ(GPIO_BASE + GPIO_IN);
        simple_timer_handler();
        if(led & 0x04)
        {
            DEV_WRITE((GPIO_BASE + GPIO_OUT), led&(~0x04));
        }
        else
        {
            DEV_WRITE((GPIO_BASE + GPIO_OUT), led|0x04);
        }
    }
    else
    {
        general_exeception_handler();
    }
}

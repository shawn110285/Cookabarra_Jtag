
#ifndef __SOC_REGS_H__
#define __SOC_REGS_H__

#include <stdint.h>

#define DEV_WRITE(addr, val) (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr) (*((volatile uint32_t *)(addr)))

#define read_csr(reg) ({ unsigned long __tmp; \
  asm volatile ("csrr %0, " #reg : "=r"(__tmp)); \
  __tmp; })

#define write_csr(reg, val) ({ \
    asm volatile ("csrw " #reg ", %0" :: "r"(val)); })


#define SYSTEM_CLK_FREQ   (50*1000000)    /*50 MHZ*/


/*========================= timer related reg =======================*/
#define TIMER_BASE          0x4000
#define TIMER_MTIME         0x0
#define TIMER_MTIMEH        0x4
#define TIMER_MTIMECMP      0x8
#define TIMER_MTIMECMPH     0xC


/*========================= uart related reg =======================*/
#define UART_BASE           0x5000

// addr: 0x00
// rw. bit[0]: tx enable, 1 = enable, 0 = disable
// rw. bit[1]: rx enable, 1 = enable, 0 = disable
#define  UART_CTRL          0x0

// addr: 0x04
// ro. bit[0]: tx busy, 1 = busy, 0 = idle
// rw. bit[1]: rx over, 1 = over, 0 = receiving
// must check this bit before tx data
#define  UART_STATUS        0x4

// addr: 0x08
// rw. clk_i div
#define  UART_BAUD          0x8

// addr: 0x10
// ro. rx data
#define  UART_TXDATA        0xc
#define  UART_RXDATA        0x10

/*========================= gpio related reg =======================*/
#define GPIO_BASE           0x6000
#define GPIO_IN             0x0
#define GPIO_OUT            0x4



extern unsigned int get_mepc();
extern unsigned int get_mcause();
extern unsigned int get_mtval();
extern unsigned int get_mtvec();

#endif  // __SOC_REGS_H__

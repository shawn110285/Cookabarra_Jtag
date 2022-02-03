#include "../include/reg.h"

unsigned int get_mepc()
{
    uint32_t result;
    __asm__ volatile("csrr %0, mepc;" : "=r"(result));
    return result;
}

unsigned int get_mcause()
{
    uint32_t result;
    __asm__ volatile("csrr %0, mcause;" : "=r"(result));
    return result;
}

unsigned int get_mtval()
{
    uint32_t result;
    __asm__ volatile("csrr %0, mtval;" : "=r"(result));
    return result;
}


unsigned int get_mtvec()
{
    uint32_t result;
    __asm__ volatile("csrr %0, mtvec;" : "=r"(result));
    return result;
}

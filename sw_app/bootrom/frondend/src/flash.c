

#include "../include/flash.h"


void flash_init(void)
{
    /*
    FCTL2 = FWKEY + FSSEL_2 + FN3;
    */
}

/* Segment size is 512B */
void flash_erase_segment(unsigned char * addr)
{
    /*
    unsigned char *ptr;

    ptr = addr;
    FCTL1 = FWKEY + ERASE;
    FCTL3 = FWKEY;

    *ptr = 0xFF;
    while (FCTL3 & BUSY);

    FCTL1 = FWKEY;
    FCTL3 = FWKEY + LOCK;
    */
}

void flash_write_byte(unsigned char * addr, unsigned char data)
{
    /*
    unsigned char *ptr;

    ptr = addr;
    FCTL1 = FWKEY + WRT;
    FCTL3 = FWKEY;

    *ptr = data;
    while (FCTL3 & BUSY);

    FCTL1 = FWKEY;
    FCTL3 = FWKEY + LOCK;
    */
}
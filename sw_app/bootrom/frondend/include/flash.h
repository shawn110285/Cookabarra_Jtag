
#ifndef _FLASH_H_
#define _FLASH_H_

void flash_init(void);
void flash_erase_segment(unsigned char * addr);
void flash_write_byte(unsigned char * addr, unsigned char data);

#endif /* _FLASH_H_ */
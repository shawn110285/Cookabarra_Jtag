
#ifndef _BOOTLOADER_H_
#define _BOOTLOADER_H_


typedef enum
{
    START_STATE = 0,
    MENU_STATE,
    CLEAR_STATE,
    DOWNLOAD_STATE,
    START_APPLICATION_STATE,
    END_STATE
} Bootloader_State_t;

#endif /* _BOOTLOADER_H_ */

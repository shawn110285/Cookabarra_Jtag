#include "../include/bootloader.h"
#include "../include/reg.h"
#include "../include/timer.h"
#include "../include/uart.h"
#include "../include/flash.h"
#include "../include/utils.h"


char * menuStr = "------------Cookabarra Boot Menu------------\r\n"
        " (D):Download Program From Serial\r\n"
        " (E):Erase Flash\r\n"
        " (S):Start App\r\n";

char * commandStr = "command:";
char * commandErrorStr = "command error!\r\n";
char * strPompt = "Press Any Key to Interrupt Boot!\r\n";

unsigned char currentState;
unsigned int  timer_count = 0;


static void timerCallback(void);
static char checkApplication(void);
static void call_application();
static void eraseApplication(void);
static void downloadProgram(void);




void main()
{
    char command[5] = { 0 };


    DEV_WRITE((GPIO_BASE + GPIO_OUT), 0x04);

    uart_init();
    DEV_WRITE((GPIO_BASE + GPIO_OUT), 0x08);

    uart_send_string(strPompt);
    DEV_WRITE((GPIO_BASE + GPIO_OUT), 0x03);

    flash_init();
    DEV_WRITE((GPIO_BASE + GPIO_OUT), 0x06);


    timer_enable(50000000, timerCallback);
    DEV_WRITE((GPIO_BASE + GPIO_OUT), 0x07);

    currentState = START_STATE;
    timer_count = 0;

    while (1)
    {
        switch (currentState)
        {
            case START_STATE:
            {
                if ( timer_count < 6 )
                {
                    xprintf("wait for more %d Seconds! \r", 6 - timer_count);
                    if( uart_check_rx_buf())
                    {
                        uart_read_char();    //block here
                        currentState = MENU_STATE;
                        uart_send_string(menuStr);
                        uart_send_string(commandStr);
                        //timer_disable();
                    }
                }
                else
                {
                    currentState = START_APPLICATION_STATE;
                    //timer_disable();
                }
            }
            break;

            case MENU_STATE:
            {
                uart_read_string(command, 5);
                uart_send_string(command);
                if (command[1] != '\0')
                {
                    uart_send_string(commandErrorStr);
                    uart_send_string(commandStr);
                    for(int i=0; i<5; i++)
                    {
                        uart_send_char(command[i]);
                        uart_send_string("\r\n");
                    }
                }
                else
                {
                    switch (command[0])
                    {
                        case 'D':
                        case 'd':
                            downloadProgram();
                            uart_send_string(commandStr);
                            break;

                        case 'E':
                        case 'e':
                            uart_send_string(commandStr);
                            eraseApplication();
                            uart_send_string(commandStr);
                            break;

                        case 'S':
                        case 's':
                            currentState = START_APPLICATION_STATE;
                            break;

                        default:
                            uart_send_string(commandErrorStr);
                            uart_send_string(commandStr);
                            break;
                    }
                }
            }
            break;

            case START_APPLICATION_STATE:
            {
                DEV_WRITE((GPIO_BASE + GPIO_OUT), 0x2);
                uart_send_string("\r\n=======================================\r\n");
                uart_send_string("start the application!\r\n");
                currentState = END_STATE;
                call_application();
            }
            break;
        }
    }
}

static char checkApplication(void)
{
    return 1;
}


static void call_application()
{
    /* asm ("lui   x1, 0x10000 \n"
         "addi  x1, x1, 0x080 \n"
         "jalr  x0, 0(x1) \n" ); */

    while(1);
}

static void timerCallback(void)
{
    timer_count ++;
}


static void eraseApplication(void)
{
    unsigned int ptr;

    uart_send_string("Start to erase flash \r\n");

    for (ptr = 0; ptr <= 10; ptr += 0x200)
    {
        flash_erase_segment((unsigned char * )ptr);
        uart_send_char('.');
    }

    uart_send_string("\r\nErase Complete!\r\n");
}

static void downloadProgram(void)
{
    unsigned int index;
    char buffer[43];
    char command = 0;
    char length;
    char temp;

    uart_send_char('n');
    while (1)
    {
        command = uart_read_char();
        switch (command)
        {
            case 's':   // start a new line transmission
            {
                length = uart_read_char();  //length transit as a integer

                for (index = 0; index < length; index++)
                {
                    temp = uart_read_char();
                    buffer[index] = temp;
                }
                // convert the string to binary and write to the ram

                uart_send_char('n');  //give a acknowledgement to the sender
            }
            break;

            case 'f':  // complete the whole file
            {
                uart_send_char('n'); //acknowledgement
                return;
            }
            break;

            default:
            {
                uart_send_string("\r\n unknown command! \r\n");
            }
            break;
        }
    }
}


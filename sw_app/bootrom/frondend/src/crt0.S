
/* exceptions vector */

.section .vectors, "ax"
//  .option norvc;

  // All interrupts/exceptions go to the default_exc_handler.
  .org 0x00
  .rept 32
  jal x0, default_exc_handler
  .endr

  // reset vector
  .org 0x80
  jal x0, reset_handler


.section .text

default_exc_handler:
  // save the registers to the stack
  addi sp, sp, -2000
  sw x1, 1*4(sp)
  sw x2, 2*4(sp)
  sw x3, 3*4(sp)
  sw x4, 4*4(sp)
  sw x5, 5*4(sp)
  sw x6, 6*4(sp)
  sw x7, 7*4(sp)
  sw x8, 8*4(sp)
  sw x9, 9*4(sp)
  sw x10, 10*4(sp)
  sw x11, 11*4(sp)
  sw x12, 12*4(sp)
  sw x13, 13*4(sp)
  sw x14, 14*4(sp)
  sw x15, 15*4(sp)
  sw x16, 16*4(sp)
  sw x17, 17*4(sp)
  sw x18, 18*4(sp)
  sw x19, 19*4(sp)
  sw x20, 20*4(sp)
  sw x21, 21*4(sp)
  sw x22, 22*4(sp)
  sw x23, 23*4(sp)
  sw x24, 24*4(sp)
  sw x25, 25*4(sp)
  sw x26, 26*4(sp)
  sw x27, 27*4(sp)
  sw x28, 28*4(sp)
  sw x29, 29*4(sp)
  sw x30, 30*4(sp)
  sw x31, 31*4(sp)

  // setup the stack and jump to the c hanlder with 3 parameters
  csrr a0, mcause
  csrr a1, mepc
  mv a2, sp
  jal handle_trap
  // csrw mepc, a0   // the c code hanlder also could change the epc

  // retore the registers from the stack
  lw x1, 1*4(sp)
  lw x2, 2*4(sp)
  lw x3, 3*4(sp)
  lw x4, 4*4(sp)
  lw x5, 5*4(sp)
  lw x6, 6*4(sp)
  lw x7, 7*4(sp)
  lw x8, 8*4(sp)
  lw x9, 9*4(sp)
  lw x10, 10*4(sp)
  lw x11, 11*4(sp)
  lw x12, 12*4(sp)
  lw x13, 13*4(sp)
  lw x14, 14*4(sp)
  lw x15, 15*4(sp)
  lw x16, 16*4(sp)
  lw x17, 17*4(sp)
  lw x18, 18*4(sp)
  lw x19, 19*4(sp)
  lw x20, 20*4(sp)
  lw x21, 21*4(sp)
  lw x22, 22*4(sp)
  lw x23, 23*4(sp)
  lw x24, 24*4(sp)
  lw x25, 25*4(sp)
  lw x26, 26*4(sp)
  lw x27, 27*4(sp)
  lw x28, 28*4(sp)
  lw x29, 29*4(sp)
  lw x30, 30*4(sp)
  lw x31, 31*4(sp)

  addi sp, sp, 2000
  mret

reset_handler:
  /* set all registers to zero */
  mv  x1, x0
  mv  x2, x1
  mv  x3, x1
  mv  x4, x1
  mv  x5, x1
  mv  x6, x1
  mv  x7, x1
  mv  x8, x1
  mv  x9, x1
  mv x10, x1
  mv x11, x1
  mv x12, x1
  mv x13, x1
  mv x14, x1
  mv x15, x1
  mv x16, x1
  mv x17, x1
  mv x18, x1
  mv x19, x1
  mv x20, x1
  mv x21, x1
  mv x22, x1
  mv x23, x1
  mv x24, x1
  mv x25, x1
  mv x26, x1
  mv x27, x1
  mv x28, x1
  mv x29, x1
  mv x30, x1
  mv x31, x1

  /* stack initilization */
  la  sp, _stack_start      //x2:sp, x3:gp, x4:tp, x1:ra

_start:
  .global _start

  /* turn on the LED0 */
  lui   a0, 0x00006    /* the highest 20 bits 0f 0x00400000*/
  addi  a0, a0, 0x04
  addi  a1, x0, 0x01
  sw    a1, 0x0(a0)


  /* clear BSS */
  la x26, _bss_start
  la x27, _bss_end

  bgeu x26, x27, zero_loop_end

zero_loop:
  sw x0, 0(x26)
  addi x26, x26, 4
  bltu x26, x27, zero_loop

zero_loop_end:


main_entry:
  /* turn on the LED1 */
  lui   a0, 0x00006
  addi  a0, a0, 0x04
  addi  a1, x0, 0x02
  sw    a1, 0x0(a0)

  /* jump to main program entry point (argc = argv = 0) */
  addi x10, x0, 0
  addi x11, x0, 0
  jal x1, main

  /* If execution ends up here just put the core to sleep */
sleep_loop:
  // wfi
  j sleep_loop




/* Copyright lowRISC contributors.
   Licensed under the Apache License, Version 2.0, see LICENSE for details.
   SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)


MEMORY
{
    /* 992 kB should be enough for anybody... */
    rom         : ORIGIN = 0x000000, LENGTH = 0x2000  /* 8 kB */
    ram         : ORIGIN = 0x002000, LENGTH = 0x1000  /* 4 kB */
    stack       : ORIGIN = 0x003000, LENGTH = 0x1000  /* 4 kB */
}

/* Stack information variables */
_min_stack     = 512;   /* 512 - minimum stack space to reserve */
_stack_len     = LENGTH(stack);
_stack_start   = ORIGIN(stack) + LENGTH(stack);

/*
_entry_point = _vectors_start + 0x80;
ENTRY(_entry_point)
*/


SECTIONS
{
    .vectors :
    {
        . = ALIGN(4);
		_vectors_start = .;
        KEEP(*(.vectors))
		_vectors_end = .;
    } > rom

    .text : {
        . = ALIGN(4);
        *(.text)
        *(.text.*)
    }  > rom

    .rodata : {
        . = ALIGN(4);
        /* Small RO data before large RO data */
        *(.srodata)
        *(.srodata.*)
        *(.rodata);
        *(.rodata.*)
    } > rom

    .data : {
        . = ALIGN(4);
        /* Small data before large data */
        *(.sdata)
        *(.sdata.*)
        *(.data);
        *(.data.*)
    } > rom

    .bss :
    {
        . = ALIGN(4);
        _bss_start = .;
        /* Small BSS before large BSS */
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _bss_end = .;
    } > ram

    /* ensure there is enough room for stack */
    .stack (NOLOAD): {
        . = ALIGN(4);
        . = . + _min_stack ;
        . = ALIGN(4);
        stack = . ;
        _stack = . ;
    } > stack
}

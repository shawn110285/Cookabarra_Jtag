
# ARCH = rv32im # to disable compressed instructions
ARCH ?= rv32im
CC = riscv32-unknown-elf-gcc   # riscv64-unknown-elf-gcc

OBJCOPY ?= $(subst gcc,objcopy,$(wordlist 1,1,$(CC)))
OBJDUMP ?= $(subst gcc,objdump,$(wordlist 1,1,$(CC)))


COMMON_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

SRCS = $(wildcard $(COMMON_DIR)/src/*.c)
INCS := -I$(COMMON_DIR)/inc

C_SRCS = $(filter %.c, $(SRCS))
ASM_SRCS = $(filter %.S, $(SRCS))


CRT ?= $(COMMON_DIR)/src/crt0.S
OBJS := ${C_SRCS:.c=.o} ${ASM_SRCS:.S=.o} ${CRT:.S=.o}
DEPS = $(OBJS:%.o=%.d)

LINKER_SCRIPT ?= $(COMMON_DIR)/link.ld
CFLAGS ?= -march=$(ARCH) -mabi=ilp32 -static -mcmodel=medany -Wall -O1 \
	-fvisibility=hidden -nostdlib -nostartfiles -ffreestanding

PROGRAM = bootrom

OUTFILES := $(PROGRAM).dis $(PROGRAM).elf $(PROGRAM).vmem $(PROGRAM).bin $(PROGRAM).dump

all: $(OUTFILES)

$(PROGRAM).elf: $(OBJS) $(LINKER_SCRIPT)
	$(CC) $(CFLAGS) -T $(LINKER_SCRIPT) $(OBJS) -o $@ $(LIBS)

%.dis: %.elf
	$(OBJDUMP) -fhSD $^ > $@

%.vmem: %.bin
	srec_cat $^ -binary -offset 0x0000 -byte-swap 4 -o $@ -vmem   # 0x00100000

%.dump: %.elf
	$(OBJDUMP) --disassemble-all $< > $@

%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

%.o: %.c
	$(CC) $(CFLAGS) -MMD -c $(INCS) -o $@ $<

%.o: %.S
	$(CC) $(CFLAGS) -MMD -c $(INCS) -o $@ $<

clean:
	$(RM) -f $(OBJS) $(DEPS) $(OUTFILES)

distclean: clean
	$(RM) -f $(OUTFILES)

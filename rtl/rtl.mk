## ===============================================================================
## Purpose:	Builds the rtl project
## Targets:
##	all:    build a verilator simulation,include the core and the tb.
##	clean:	Removes all build products
##  E-mail:  shawn110285@gmail.com
## ================================================================================

.PHONY: all
.DELETE_ON_ERROR:


#ROOT_DIR := /var/cpu_testbench/koala
RTL_ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# the rtl files of the cpu core
RTL_DIR :=$(RTL_ROOT_DIR)/core
INC_DIR :=$(RTL_ROOT_DIR)/core/include
BUS_DIR := $(RTL_ROOT_DIR)/soc/bus
ROM_DIR := $(RTL_ROOT_DIR)/soc/rom
RAM_DIR := $(RTL_ROOT_DIR)/soc/ram
TIMER_DIR := $(RTL_ROOT_DIR)/soc/timer
UART_DIR := $(RTL_ROOT_DIR)/soc/uart
GPIO_DIR := $(RTL_ROOT_DIR)/soc/gpio
JTAG_DIR := $(RTL_ROOT_DIR)/soc/jtag


CORE_RTL_FILES := $(RTL_DIR)/ifu/ifu.v     $(RTL_DIR)/ifu/bp.v        $(RTL_DIR)/ifu/if_id.v     $(RTL_DIR)/dec/id.v        $(RTL_DIR)/dec/id_ex.v   \
				  $(RTL_DIR)/exu/ex.v      $(RTL_DIR)/exu/div.v       $(RTL_DIR)/exu/ex_mem.v    $(RTL_DIR)/lsu/mem.v     \
				  $(RTL_DIR)/lsu/mem_wb.v  $(RTL_DIR)/wb/gpr.v        $(RTL_DIR)/wb/csr.v	     $(RTL_DIR)/ctrl/ctrl.v   \
				  $(RTL_DIR)/core_top.v

BUS_FILES := $(BUS_DIR)/bus.v
ROM_FILES := $(ROM_DIR)/rom.sv
RAM_FILES := $(RAM_DIR)/ram.sv
TIMER_FILES := $(TIMER_DIR)/timer.sv
UART_FILES := $(UART_DIR)/uart.v
GPIO_FILES := $(GPIO_DIR)/gpio.v
JTAG_FILES := $(JTAG_DIR)/dtm_jtag.v  $(JTAG_DIR)/dm_jtag.v  $(JTAG_DIR)/jtag_top.v  $(JTAG_DIR)/dmi_cdc.sv  $(JTAG_DIR)/cdc_2phase.sv

VERILOG_FILES :=  $(CORE_RTL_FILES)  \
				  $(BUS_FILES)  \
				  $(UART_FILES)  \
				  $(GPIO_FILES)  \
	              $(TIMER_FILES) \
				  $(ROM_FILES) \
				  $(RAM_FILES) \
				  $(JTAG_FILES) \
				  $(RTL_ROOT_DIR)/soc/simple_system.v

TOP_MOD = simple_system
VERILOG_OBJ_DIR = obj_dir

VERILATOR = verilator

#-Wall                      Enable all style warnings
#-Wno-style                 Disable all style warnings
#-Werror-<message>          Convert warnings to errors
#-Wno-lint                  Disable all lint warnings
#-Wno-<message>             Disable warning
#-I<dir>                    Directory to search for includes

# INCLUDE_DIR := ../ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_assert.sv
# VFLAGS := --cc -trace -Wall
VFLAGS = --cc -trace   # -Wno-style -DRVFI -Wno-IMPLICIT -Wno-WIDTH -Wno-CASEINCOMPLETE

## Find the directory containing the Verilog sources.  This is given from
## calling: "verilator -V" and finding the VERILATOR_ROOT output line from
## within it.  From this VERILATOR_ROOT value, we can find all the components
## we need here--in particular, the verilator include directory
VERILATOR_ROOT ?= $(shell bash -c '$(VERILATOR) -V|grep VERILATOR_ROOT | head -1 | sed -e "s/^.*=\s*//"')

# covert the verilog file into the cpp file
$(VERILOG_OBJ_DIR)/V$(TOP_MOD).cpp: $(VERILOG_FILES)
	@echo "===================compile RTL into cpp files, start=========================="
	$(VERILATOR) $(VFLAGS) -I$(INC_DIR) --top-module $(TOP_MOD) $(VERILOG_FILES) V$(TOP_MOD).cpp
	@echo "===================compile RTL into cpp files, end ==========================="

# create the c++ lib from the above cpp file
$(VERILOG_OBJ_DIR)/V$(TOP_MOD)__ALL.a: $(VERILOG_OBJ_DIR)/V$(TOP_MOD).cpp
	@echo "===============add rtl object files into cpp files, start======================"
#	make --no-print-directory -C $(VERILOG_OBJ_DIR) -f V$(TOP_MOD).mk
	make -C $(VERILOG_OBJ_DIR) -f V$(TOP_MOD).mk
	@echo "===============add rtl object files into cpp files, end======================"

all: $(VERILOG_OBJ_DIR)/V$(TOP_MOD)__ALL.a

.PHONY: clean
clean:
	@echo "=========================cleaning RTL objects, start============================"
	rm -rf ./$(VERILOG_OBJ_DIR)/
	@echo "=========================cleaning RTL objects, end============================"


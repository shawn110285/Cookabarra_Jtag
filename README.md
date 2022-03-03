# Cookabarra_Jtag
debug module was partially supported 


## 1.build the verilator simulator 

shawnliu@shawnliu-Aspire-TC-780:/var/cpu_testbench/git_hub/Cookabarra_SOC$ make all

and then start the simulator

`shawnliu@shawnliu-Aspire-TC-780:/var/cpu_testbench/git_hub/Cookabarra_SOC$ ./tb`  

Built with Verilator 4.212 2021-09-01.
Recommended: Verilator 4.0 or later.
This emulator compiled with JTAG Remote Bitbang client. To enable, use +jtag_rbb_enable=1.
Listening on port 9823
Attempting to accept client socket
Accepted successfully.
================ reset the system from boot_addr ===============   
================ reset the system from boot_addr ===============  
================ reset the system from boot_addr ===============  
================ reset the system from boot_addr ===============  
================ reset the system from boot_addr ===============  
================ reset the system from boot_addr ===============  
================ reset the system from boot_addr ===============  
================ reset the system from boot_addr ===============  
================ reset the system from boot_addr ===============  
reset the cpu,done  
================ reset the system from boot_addr ===============  
invalid instruction opcode (00), pc=       128,  the instruction is (00000000)  
invalid instruction opcode (00), pc=       128,  the instruction is (00000000)  
dm write dmcontrol, data=0x00000000, dmcontrol =0x00000000  




## 2.openocd

  shawnliu@shawnliu-Aspire-TC-780:/var/cpu_testbench/git_hub/Cookabarra_SOC/openocd$ openocd -f ./openocd_local_bitbang.cfg
  Open On-Chip Debugger 0.10.0+dev (SiFive OpenOCD 0.10.0-2020.04.6)
  Licensed under GNU GPL v2
  For bug reports:
  https://github.com/sifive/freedom-tools/issues
  Info : only one transport option; autoselect 'jtag'
  Info : Initializing remote_bitbang driver
  Info : Connecting to localhost:9823
  Info : remote_bitbang driver initialized
  Info : This adapter doesn't support configurable speed
  Info : JTAG tap: riscv.cpu tap/device found: 0x1e200a6f (mfg: 0x537 (Wuhan Xun Zhan Electronic Technology), part: 0xe200, ver: 0x1)
  Info : datacount=1 progbufsize=0
  Warn : We won't be able to execute fence instructions on this target. Memory may not always appear consistent. (progbufsize=0, impebreak=0)
  Info : Examined RISC-V core; found 1 harts
  Info :  hart 0: XLEN=32, misa=0x40001100
  Info : Listening on port 3333 for gdb connections
  Info : Listening on port 6666 for tcl connections
  Info : Listening on port 4444 for telnet connections




## 3. gdb

   shawnliu@shawnliu-Aspire-TC-780:/var/cpu_testbench/git_hub/Cookabarra_SOC/sw_app/bootrom/frondend$ riscv32-unknown-elf-gdb
   GNU gdb (GDB) 8.2.50.20181127-git
   Copyright (C) 2018 Free Software Foundation, Inc.
   License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
   This is free software: you are free to change and redistribute it.
   There is NO WARRANTY, to the extent permitted by law.
   Type "show copying" and "show warranty" for details.
   This GDB was configured as "--host=x86_64-pc-linux-gnu --target=riscv32-unknown-elf".
   Type "show configuration" for configuration details.
   For bug reporting instructions, please see:
   <http://www.gnu.org/software/gdb/bugs/>.
   Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word".


(gdb) show remotetimeout
Timeout limit to wait for target to respond is 2.
(gdb) set remotetimeout 20

### 3.1 connect to openocd (gdb server)

(gdb) target remote localhost:3333
Remote debugging using localhost:3333
warning: No executable has been specified and target does not support
determining executable automatically.  Try using the "file" command.
Ignoring packet error, continuing...
0x80000036 in ?? ()


### 3.2 access gpr registers

(gdb) info reg
ra             0x5f555555	0x5f555555
sp             0x0	0x0
gp             0xd0580000	0xd0580000
tp             0x80000178	0x80000178
t0             0xff	255
t1             0x0	0
t2             0x0	0
fp             0x0	0x0
s1             0x0	0
a0             0x0	0
a1             0x0	0
a2             0x0	0
a3             0x0	0
a4             0x0	0
a5             0x0	0
a6             0x0	0
a7             0x0	0
s2             0x0	0
s3             0x0	0
s4             0x0	0
s5             0x0	0
s6             0x0	0
s7             0x0	0
s8             0x0	0
s9             0x0	0
s10            0x0	0
s11            0x0	0
t3             0x0	0
t4             0x0	0
t5             0x0	0
t6             0x0	0
pc             0x80000036	0x80000036
(gdb) 

### 3.3 access CSR

(gdb) p $misa
$1 = 1073746176
(gdb) p $mtvec
$2 = 1
(gdb) p $mstatus
$3 = 6280
(gdb) p $mvendorid
$4 = 0
(gdb) p $minstret
$5 = 513177
(gdb) p $mcycle
$6 = 540351
(gdb) p $mcycleh
$7 = 0
(gdb) p $mie
$8 = 128
(gdb) p $mtvec
$9 = 1
(gdb) 

### 3.4 access memory

(gdb) x/wx 0x100000
0x100000:	0x7e40006f
(gdb) x/wx 0x100004
0x100004:	0x53dbd36b
(gdb) x/wx 0x100008
0x100008:	0xafc353cf
(gdb) x/wx 0x80
0x80:	0xe4f6fdf4
(gdb) x 0x80
0x80:	0x003007b7

### 3.5 load file

(gdb) target remote localhost:3333
Remote debugging using localhost:3333
warning: No executable has been specified and target does not support
determining executable automatically.  Try using the "file" command.
Ignoring packet error, continuing...
0x00000000 in ?? ()
(gdb) file ./bootrom.elf 
A program is being debugged already.
Are you sure you want to change the file? (y or n) y
Reading symbols from ./bootrom.elf...
(No debugging symbols found in ./bootrom.elf)
(gdb) load
Loading section .vectors, size 0x84 lma 0x0
Loading section .text, size 0xc00 lma 0x84
Loading section .rodata, size 0x2fc lma 0xc84
Ignoring packet error, continuing...
Loading section .data, size 0x10 lma 0xf80
Ignoring packet error, continuing...
Start address 0x84, load size 3984
Ignoring packet error, continuing...
Transfer rate: 255 bytes/sec, 996 bytes/write.

### 3.5 jump to a address or a function

jump function
set $pc=address
(gdb) jump reset_handler
Continuing at 0x8f8.
Could not write register "pc"; remote failure reply 'E0E'

(gdb) monitor reset halt
JTAG tap: riscv.cpu tap/device found: 0x1e200a6f (mfg: 0x537 (Wuhan Xun Zhan Electronic Technology), part: 0xe200, ver: 0x1)
(gdb) 



 

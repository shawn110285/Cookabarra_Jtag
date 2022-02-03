#!/usr/bin/env python3
#
# This is free and unencumbered software released into the public domain.
#
# Anyone is free to copy, modify, publish, use, compile, sell, or
# distribute this software, either in source code form or as a compiled
# binary, for any purpose, commercial or non-commercial, and by any
# means.
# example: python3 makehex.py uart_tx.bin 32768 > uart_tx.hex

from sys import argv

binfile = argv[1]

with open(binfile, "rb") as f:
    bindata = f.read()

for i in range( len(bindata) // 4):
    w = bindata[4*i : 4*i+4]
    # print("assign rom_mem[%d] = 32'h%02x%02x%02x%02x;" % (i, w[3], w[2], w[1], w[0]))
    print("     32'h%02x%02x%02x%02x," % (w[3], w[2], w[1], w[0]))

if (len(bindata) // 4 < 1024):
   for i in range(1024 - len(bindata) // 4):
        print("     32'h00000000,")
   print("/*==================================1024 ================= */")
   for i in range(1024):
        print("     32'h00000000,")
else: 
   if (len(bindata) // 4 < 2048):
       for i in range(2048 - len(bindata) // 4):
           print("     32'h00000000,")

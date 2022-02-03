/*-------------------------------------------------------------------------
// Module:  ram
// File:    ram.sv
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: ram
--------------------------------------------------------------------------*/

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------

`include "defines.v"

module ram(
    // lsu data port
	input wire				      clk_i,
	input wire                    n_rst_i,
	input wire					  ce_i,
	input wire[3:0]				  sel_i,
	input wire[`DataAddrBus]	  addr_i,
	input wire					  we_i,
	input wire[`DataBus]		  data_i,
	output wire                   rvalid_o,
	output reg[`DataBus]		  data_o,

    // jtag access signals
    input wire                    jtag_ce_i,
	input wire[3:0]               jtag_sel_i,
	input wire[`DataAddrBus]      jtag_addr_i,
	input wire					  jtag_we_i,
	input wire[`DataBus]		  jtag_data_i,
    output wire					  jtag_rvalid_o,
	output wire[`DataBus]		  jtag_data_o
);

   /* verilator lint_off LITENDIAN */
   logic [0:`RamNum-1][`DataBus]  ram_mem;
   /* verilator lint_on LITENDIAN */

   assign rvalid_o = ce_i & (~we_i);
    /*------------------ lsu access port ----------------------*/
    assign rvalid_o = ce_i & (~we_i);

	always @ (posedge clk_i) begin
		if( (ce_i != `ChipDisable) && (we_i == `WriteEnable) )begin
			if (sel_i[3] == 1'b1) begin
				ram_mem[addr_i[`RamNumLog2+1:2]][31:24] <= data_i[31:24];
			end

			if (sel_i[2] == 1'b1) begin
				ram_mem[addr_i[`RamNumLog2+1:2]][23:16] <= data_i[23:16];
			end

			if (sel_i[1] == 1'b1) begin
				ram_mem[addr_i[`RamNumLog2+1:2]][15:8] <= data_i[15:8];
			end

			if (sel_i[0] == 1'b1) begin
				ram_mem[addr_i[`RamNumLog2+1:2]][7:0] <= data_i[7:0];
			end
		// jtag write
		end else if( (jtag_ce_i != `ChipDisable) && (jtag_we_i == `WriteEnable) )begin
			if (jtag_sel_i[3] == 1'b1) begin
				ram_mem[jtag_addr_i[`RamNumLog2+1:2]][31:24] <= jtag_data_i[31:24];
			end

			if (jtag_sel_i[2] == 1'b1) begin
				ram_mem[jtag_addr_i[`RamNumLog2+1:2]][23:16] <= jtag_data_i[23:16];
			end

			if (jtag_sel_i[1] == 1'b1) begin
				ram_mem[jtag_addr_i[`RamNumLog2+1:2]][15:8] <= jtag_data_i[15:8];
			end

			if (jtag_sel_i[0] == 1'b1) begin
				ram_mem[jtag_addr_i[`RamNumLog2+1:2]][7:0] <= jtag_data_i[7:0];
			end
		end
	end

	always @ (*) begin
		if (ce_i == `ChipDisable) begin
			data_o = `ZeroWord;
	    end else if(we_i == `WriteDisable) begin
		    data_o =  ram_mem[addr_i[`RamNumLog2+1:2]];
		end else begin
			data_o = `ZeroWord;
		end
	end

    /*------------------ jtag read  ----------------------*/
    assign jtag_rvalid_o = jtag_ce_i & (~jtag_we_i);

	always @ (*) begin
		if (jtag_ce_i == `ChipDisable) begin
			jtag_data_o = `ZeroWord;
	    end else if(jtag_we_i == `WriteDisable) begin
		    jtag_data_o = ram_mem[jtag_addr_i[`RamNumLog2+1:2]];
		end else begin
			jtag_data_o = `ZeroWord;
		end
	end


/*
    // Task for loading 'ram_mem' with SystemVerilog system task $readmemh()
    export "DPI-C" task simutil_ramload;

    task simutil_ramload;
        input string file;
        $readmemh(file, ram_mem);
    endtask

    // Function for setting a specific element in |ram_mem|
    // Returns 1 (true) for success, 0 (false) for errors.
    export "DPI-C" function simutil_set_ram;

    function int simutil_set_ram(input int index, input bit [`InstBus] val);
        if (index >= `RamNum) begin
            return 0;
        end
        ram_mem[index] = val;
        return 1;
    endfunction

    // Function for getting a specific element in |ram_mem|
    export "DPI-C" function simutil_get_ram;

    function int simutil_get_ram(input int index, output bit [31:0] val);
        if (index >= `RamNum) begin
          return 0;
        end

        val = 0;
        val = ram_mem[index];
        return 1;
    endfunction
*/
endmodule

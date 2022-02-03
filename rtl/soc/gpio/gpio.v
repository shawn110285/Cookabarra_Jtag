
/*-------------------------------------------------------------------------
// Module:  gpio
// File:    gpio.sv
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: gpio
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

module gpio(
	input wire				      clk_i,
    input wire                    n_rst_i,
	input wire					  gpio_ce_i,
   // input wire                    gpio_cyc_i,
	input wire[3:0]				  gpio_sel_i,  // not used

	input wire[31:0]	          gpio_addr_i,
	input wire					  gpio_we_i,
	input wire[31:0]		      gpio_data_i,
	output wire                   gpio_ack_o,
	output reg[31:0]		      gpio_data_o,

    input wire[31:0]              gpio_pin_i,
    output wire[31:0]             gpio_pin_o
    );

    // rx buf: 0x0
    wire[31:0] gpio_data_in;
    // tx buf: 0x4
    reg[31:0] gpio_data_out;

	reg    rvalid;
    assign gpio_ack_o = gpio_ce_i /*& gpio_cyc_i */ & (gpio_we_i ? 1: rvalid);

    // write
    always @ (posedge clk_i or negedge n_rst_i) begin
        if (n_rst_i == 1'b0) begin
            gpio_data_out <= 32'h0;
        end else begin
            if ( (gpio_ce_i == 1'b1) /* && (gpio_cyc_i == 1'b1) */ && (gpio_we_i == 1'b1) && (gpio_addr_i[7:0] == 8'h04) )begin
                gpio_data_out <= gpio_data_i;
            end else begin

            end
        end
    end

    // read
    always @ (posedge clk_i or negedge n_rst_i) begin
        if (n_rst_i == 1'b0) begin
            rvalid <= 1'b0;
            gpio_data_o <=  32'h0;
        end else begin
            if ( (gpio_ce_i == 1'b1) /* && (gpio_cyc_i == 1'b1) */ && (gpio_we_i == 1'b0) && (gpio_addr_i[7:0] == 8'h0) ) begin
                rvalid <= 1'b1;
                gpio_data_o <= gpio_data_in;
            end else begin
                rvalid <= 1'b0;
                gpio_data_o <=  32'h0;
            end
        end
    end

    // get the status of the input io
    assign gpio_data_in = gpio_pin_i;

    // control the output io
    assign gpio_pin_o = gpio_data_out;

endmodule

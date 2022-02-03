
/*-------------------------------------------------------------------------
// Module:  timer
// File:    timer.sv
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: a simplified implementation of mtime and mtimecmp
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


module timer (
  input  wire                    clk_i,
  input  wire                    rst_ni,

  // Bus interface
  input  wire                    timer_req_i,
  input  wire[3:0]               timer_sel_i,
  input  wire[31:0]              timer_addr_i,
  input  wire                    timer_we_i,
  input  wire [31:0]             timer_wdata_i,
  output wire                    timer_rvalid_o,
  output wire [31:0]             timer_rdata_o,
  output wire                    timer_intr_o
);

    // Register map
    localparam MTIME_LOW = 0;
    localparam MTIME_HIGH = 4;
    localparam MTIMECMP_LOW = 8;
    localparam MTIMECMP_HIGH = 12;

    wire     timer_we;
    wire     mtime_we, mtimeh_we;
    wire     mtimecmp_we, mtimecmph_we;

    reg[63:0]  mtime;
    reg[63:0]  mtimecmp;

    assign timer_we = timer_req_i & timer_we_i;
    assign mtime_we     = timer_we & (timer_addr_i[9:0] == MTIME_LOW);
    assign mtimeh_we    = timer_we & (timer_addr_i[9:0] == MTIME_HIGH);
    assign mtimecmp_we  = timer_we & (timer_addr_i[9:0] == MTIMECMP_LOW);
    assign mtimecmph_we = timer_we & (timer_addr_i[9:0] == MTIMECMP_HIGH);

    always @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            mtime <= 'b0;
        end else if(mtime_we) begin
            mtime[31:0] <= timer_wdata_i[31:0];
        end else if(mtimeh_we) begin
            mtime[63:32] <= timer_wdata_i[31:0];
        end else begin
            mtime <= mtime + 64'd1;
        end
    end

    always @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            mtimecmp <= 'b0;
        end else if(mtimecmp_we) begin
            mtimecmp[31:0] <= timer_wdata_i[31:0];
        end else if(mtimecmph_we) begin
            mtimecmp[63:32] <= timer_wdata_i[31:0];
        end
    end

    // interrupt
    assign timer_intr_o = ((mtime >= mtimecmp) & ~(mtimecmp_we | mtimecmph_we));

    /* =================================== Read data  ========================================*/
    reg [31:0] rdata_r;
    reg        rvalid_r;

    always @ ( * ) begin
        rdata_r = 'b0;
        rvalid_r = 1'b1;
        case (timer_addr_i[9:0])
            MTIME_LOW: begin
                rdata_r = mtime[31:0];
            end

            MTIME_HIGH: begin
                rdata_r = mtime[63:32];
            end

            MTIMECMP_LOW: begin
                rdata_r = mtimecmp[31:0];
            end

            MTIMECMP_HIGH: begin
                rdata_r = mtimecmp[63:32];
            end

            default: begin
                rdata_r = 'b0;
                rvalid_r = 1'b0;
            end
        endcase
    end

    assign timer_rdata_o  = rdata_r;
    assign timer_rvalid_o = rvalid_r;

endmodule

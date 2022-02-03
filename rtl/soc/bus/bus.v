
/*-------------------------------------------------------------------------
// Module:  bus
// File:    bus.sv
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description:  the bus connected cpu(lsu) to rom, ram, timer, uart and gpio
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

module bus(
    input wire              clk_i,
    input wire              n_rst_i,

    // master
    input wire              m_req_i,
    input wire[3:0]         m_sel_i,
    input wire[31:0]        m_addr_i,
    input wire              m_we_i,
    input wire[31:0]        m_data_i,
    output reg              m_rvalid_o,  // rx data is ready
    output reg[31:0]        m_data_o,


    // slave 0 (ram)
    output reg              s0_req_o,
    output reg[3:0]         s0_sel_o,
    output reg[31:0]        s0_addr_o,
    output reg              s0_we_o,
    output reg[31:0]        s0_data_o,
    input wire              s0_rvalid_i,  // rx data is ready
    input wire[31:0]        s0_data_i,


    // slave 1  (timer)
    output reg             s1_req_o,
    output reg[3:0]        s1_sel_o,
    output reg[31:0]       s1_addr_o,
    output reg             s1_we_o,
    output reg[31:0]       s1_data_o,
    input wire             s1_rvalid_i,  // rx data is ready
    input wire[31:0]       s1_data_i,

    // slave 2 (uart)
    output reg             s2_req_o,
    output reg[3:0]        s2_sel_o,
    output reg[31:0]       s2_addr_o,
    output reg             s2_we_o,
    output reg[31:0]       s2_data_o,
    input wire             s2_rvalid_i,  // rx data is ready
    input wire[31:0]       s2_data_i,

    // slave 3 (gpio)
    output reg             s3_req_o,
    output reg[3:0]        s3_sel_o,
    output reg[31:0]       s3_addr_o,
    output reg             s3_we_o,
    output reg[31:0]       s3_data_o,
    input wire             s3_rvalid_i,  // rx data is ready
    input wire[31:0]       s3_data_i,

    // slave 4 (spi)
    output reg             s4_req_o,
    output reg[3:0]        s4_sel_o,
    output reg[31:0]       s4_addr_o,
    output reg             s4_we_o,
    output reg[31:0]       s4_data_o,
    input wire             s4_rvalid_i,  // rx data is ready
    input wire[31:0]       s4_data_i
    );

    // the memory address mapping
    localparam  slave0_base_addr_cfg = 20'h00000;   //rom        8k  0                            ~ 010, 00 00,0000,0000 -1   (0~8k-1)
    localparam slave01_base_addr_cfg = 20'h00001;   //rom        8k  0                            ~ 010, 00 00,0000,0000 -1   (0~8k-1)
    localparam  slave1_base_addr_cfg = 20'h00002;   //ram        8k  010, 00 00,0000,0000(0x2000) ~ 100, 00 00,0000,0000(4000 -1) (8k -16k-1)
    localparam slave11_base_addr_cfg = 20'h00003;   //ram        8k  010, 00 00,0000,0000(0x2000) ~ 100, 00 00,0000,0000(4000 -1) (8k -16k-1)
    localparam slave2_base_addr_cfg = 20'h00004;    //timer      4k  100, 00 00,0000,0000(4000)   ~ 101, 00 00,0000,0000(0x5000) (16k - 20k-1)
    localparam slave3_base_addr_cfg = 20'h00005;    //uart       4k  101, 00 00,0000,0000(5000)   ~ 110, 00 00,0000,0000(0x6000) (20k - 24k-1)
    localparam slave4_base_addr_cfg = 20'h00006;    //gpio       4k  110, 00 00,0000,0000(6000)   ~ 111, 00 00,0000,0000(0x6000) (24k - 28k-1)


    always @ (*) begin
        m_rvalid_o = 1'b0;
        m_data_o = 32'h00000000;

        s0_req_o = 1'b0;
        s1_req_o = 1'b0;
        s2_req_o = 1'b0;
        s3_req_o = 1'b0;
        s4_req_o = 1'b0;

        s0_sel_o = 4'b0;
        s1_sel_o = 4'b0;
        s2_sel_o = 4'b0;
        s3_sel_o = 4'b0;
        s4_sel_o = 4'b0;

        s0_addr_o = 32'h00000000;
        s1_addr_o = 32'h00000000;
        s2_addr_o = 32'h00000000;
        s3_addr_o = 32'h00000000;
        s4_addr_o = 32'h00000000;

        s0_we_o = 1'b0;
        s1_we_o = 1'b0;
        s2_we_o = 1'b0;
        s3_we_o = 1'b0;
        s4_we_o = 1'b0;

        s0_data_o = 32'h00000000;
        s1_data_o = 32'h00000000;
        s2_data_o = 32'h00000000;
        s3_data_o = 32'h00000000;
        s4_data_o = 32'h00000000;

        case (m_addr_i[31:12])
            slave0_base_addr_cfg, slave01_base_addr_cfg: begin
                s0_req_o = m_req_i;
                s0_sel_o = m_sel_i;
                s0_addr_o = m_addr_i;
                s0_we_o = m_we_i;
                s0_data_o = m_data_i;

                m_rvalid_o = s0_rvalid_i;
                m_data_o = s0_data_i;
            end

            slave1_base_addr_cfg, slave11_base_addr_cfg: begin
                s1_req_o = m_req_i;
                s1_sel_o = m_sel_i;
                s1_addr_o = m_addr_i;
                s1_we_o = m_we_i;
                s1_data_o = m_data_i;

                m_rvalid_o = s1_rvalid_i;
                m_data_o = s1_data_i;
            end

            slave2_base_addr_cfg: begin
                s2_req_o = m_req_i;
                s2_sel_o = m_sel_i;
                s2_addr_o = m_addr_i;
                s2_we_o = m_we_i;
                s2_data_o = m_data_i;

                m_rvalid_o = s2_rvalid_i;
                m_data_o = s2_data_i;
            end

            slave3_base_addr_cfg: begin
                s3_req_o = m_req_i;
                s3_sel_o = m_sel_i;
                s3_addr_o = m_addr_i;
                s3_we_o = m_we_i;
                s3_data_o = m_data_i;

                m_rvalid_o = s3_rvalid_i;
                m_data_o = s3_data_i;
            end

            slave4_base_addr_cfg: begin
                s4_req_o = m_req_i;
                s4_sel_o = m_sel_i;
                s4_addr_o = m_addr_i;
                s4_we_o = m_we_i;
                s4_data_o = m_data_i;

                m_rvalid_o = s4_rvalid_i;
                m_data_o = s4_data_i;
            end

            default: begin

            end
        endcase //case (m_addr_i[31:28])
    end  // always @ (*) begin

endmodule

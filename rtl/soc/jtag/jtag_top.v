/*-------------------------------------------------------------------------
// Module:  jtag_top
// File:    jtag_top.v
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: jtag top
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

module jtag_top #(
    parameter DMI_ADDR_BITS = 6,    // the addr length of dmi registers(ABSTRACTCS, COMMAND) , not the length of the risc-v gpr
    parameter DMI_DATA_BITS = 32,
    parameter DMI_OP_BITS = 2)
    (
        input wire         clk_i,
        input wire         nrst_i,

        input wire         jtag_TCK,
        input wire         jtag_TMS,
        input wire         jtag_TDI,
        output wire        jtag_TDO,

        output wire        reg_req_o,
        output wire[4:0]   reg_addr_o,
        output wire        reg_we_o,
        output wire[31:0]  reg_wdata_o,
        input wire[31:0]   reg_rdata_i,

        output wire        csr_req_o,     //access signal
        output wire[31:0]  csr_addr_o,    // the reg address
        output wire        csr_we_o,      // write enable
        output wire[31:0]  csr_wdata_o,   // the data to write
        input reg[31:0]    csr_rdata_i,   // the read result

        output wire        mem_ce_o,
        output wire[3:0]   mem_sel_o,
        output wire[31:0]  mem_addr_o,
        output wire        mem_we_o,
        output wire[31:0]  mem_wdata_o,
        input wire         mem_rvalid_i,
        input wire[31:0]   mem_rdata_i,

        output wire        halt_req_o,
        output wire        reset_req_o
    );

    parameter DM_RESP_BITS = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;
    parameter DTM_REQ_BITS = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;

    // dtm request, connecting with dtm
    wire                     dtm_req_valid_o;
    wire[DTM_REQ_BITS - 1:0] dtm_req_data_o;
    wire                     dm_req_ack_i;
    // dtm request, connecting with dm
    wire                     dtm_req_valid_i;
    wire[DTM_REQ_BITS - 1:0] dtm_req_data_i;
    wire                     dm_req_ack_o;

    // dm respone, connecting with dm
    wire                   dm_resp_valid_o;
    wire[DM_RESP_BITS-1:0] dm_resp_data_o;
    wire                   dtm_resp_ack_i;
    // dm respone, connecting with dtm
    wire                   dm_resp_valid_i;
    wire[DM_RESP_BITS-1:0] dm_resp_data_i;
    wire                   dtm_resp_ack_o;


    // ---------
    // CDC
    // ---------
    wire trst_n = nrst_i;

    dmi_cdc  #( .REQUEST_DW(DTM_REQ_BITS),
                .RESPONSE_DW(DM_RESP_BITS)
    ) dmi_cdc0 (
        // pass the request from dtm to dm
        .tck_i             ( jtag_TCK         ),
        .trst_ni           ( trst_n           ),
        .jtag_dmi_valid_i  ( dtm_req_valid_o  ),
        .jtag_dmi_req_i    ( dtm_req_data_o   ),
        .jtag_dmi_ready_o  ( dm_req_ack_i     ),

        .jtag_dmi_resp_o   ( dm_resp_data_i    ),
        .jtag_dmi_valid_o  ( dm_resp_valid_i   ),
        .jtag_dmi_ready_i  ( dtm_resp_ack_o     ),

        // pass the response from dm to dtm
        .clk_i             ( clk_i            ),
        .rst_ni            ( nrst_i           ),
        .core_dmi_valid_o  ( dtm_req_valid_i  ),
        .core_dmi_req_o    ( dtm_req_data_i   ),
        .core_dmi_ready_i  ( dm_req_ack_o    ),

        .core_dmi_valid_i  ( dm_resp_valid_o  ),
        .core_dmi_resp_i   ( dm_resp_data_o   ),
        .core_dmi_ready_o  ( dtm_resp_ack_i   )

    );


    dtm_jtag #(
        .DMI_ADDR_BITS(DMI_ADDR_BITS),
        .DMI_DATA_BITS(DMI_DATA_BITS),
        .DMI_OP_BITS(DMI_OP_BITS)
    ) dtm_jtag0(
        .nrst_i(nrst_i),
        .jtag_TCK(jtag_TCK),
        .jtag_TDI(jtag_TDI),
        .jtag_TMS(jtag_TMS),
        .jtag_TDO(jtag_TDO),

        .dtm_req_valid_o(dtm_req_valid_o),
        .dtm_req_data_o(dtm_req_data_o),
        .dm_req_ack_i(dm_req_ack_i),

        .dm_resp_valid_i(dm_resp_valid_i),
        .dm_resp_data_i(dm_resp_data_i),
        .dtm_resp_ack_o(dtm_resp_ack_o)
    );

    dm_jtag #(
        .DMI_ADDR_BITS(DMI_ADDR_BITS),
        .DMI_DATA_BITS(DMI_DATA_BITS),
        .DMI_OP_BITS(DMI_OP_BITS)
    ) dm_jtag0(
        .clk_i(clk_i),
        .nrst_i(nrst_i),

        .dtm_req_valid_i(dtm_req_valid_i),
        .dtm_req_data_i(dtm_req_data_i),
        .dm_req_ack_o(dm_req_ack_o),

        .dm_resp_valid_o(dm_resp_valid_o),
        .dm_resp_data_o(dm_resp_data_o),
        .dtm_resp_ack_i(dtm_resp_ack_i),

         //GPRs access
        .dm_reg_req_o(reg_req_o),
        .dm_reg_addr_o(reg_addr_o),
        .dm_reg_we_o(reg_we_o),
        .dm_reg_wdata_o(reg_wdata_o),
        .dm_reg_rdata_i(reg_rdata_i),

        // CSR access
        .dm_csr_req_o(csr_req_o),
        .dm_csr_addr_o(csr_addr_o),
        .dm_csr_we_o(csr_we_o),
        .dm_csr_wdata_o(csr_wdata_o),
        .dm_csr_rdata_i(csr_rdata_i),

        //memory access
        .dm_mem_ce_o(mem_ce_o),
        .dm_mem_sel_o(mem_sel_o),
        .dm_mem_we_o(mem_we_o),
        .dm_mem_addr_o(mem_addr_o),
        .dm_mem_wdata_o(mem_wdata_o),
        .dm_mem_rvalid_i(mem_rvalid_i),
        .dm_mem_rdata_i(mem_rdata_i),

        .dm_halt_req_o(halt_req_o),
        .dm_reset_req_o(reset_req_o)
    );

endmodule

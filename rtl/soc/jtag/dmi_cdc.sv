/* Copyright 2018 ETH Zurich and University of Bologna.
* Copyright and related rights are licensed under the Solderpad Hardware
* License, Version 0.51 (the “License”); you may not use this file except in
* compliance with the License.  You may obtain a copy of the License at
* http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
* or agreed to in writing, software, hardware and materials distributed under
* this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
* CONDITIONS OF ANY KIND, either express or implied. See the License for the
* specific language governing permissions and limitations under the License.
*
* File:   axi_riscv_debug_module.sv
* Author: Andreas Traber <atraber@iis.ee.ethz.ch>
* Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
*
* Description: Clock domain crossings for JTAG to DMI very heavily based
*              on previous work by Andreas Traber for the PULP project.
*              This is mainly a wrapper around the existing CDCs.
*/

module dmi_cdc #(parameter REQUEST_DW = 32,
                 parameter RESPONSE_DW = 32)
(
  // JTAG side (master side)
  input  logic                     tck_i,
  input  logic                     trst_ni,

  input  logic                     jtag_dmi_valid_i,
  input  logic[REQUEST_DW-1:0]     jtag_dmi_req_i,
  output logic                     jtag_dmi_ready_o,

  output logic                     jtag_dmi_valid_o,
  output logic[RESPONSE_DW-1:0]    jtag_dmi_resp_o,
  input  logic                     jtag_dmi_ready_i,

  // core side (slave side)
  input  logic                     clk_i,
  input  logic                     rst_ni,

  output logic                     core_dmi_valid_o,
  output logic[REQUEST_DW-1:0]     core_dmi_req_o,
  input  logic                     core_dmi_ready_i,

  input  logic                     core_dmi_valid_i,
  input  logic[RESPONSE_DW-1:0]    core_dmi_resp_i,
  output logic                     core_dmi_ready_o
);

  cdc_2phase  #( .DW (REQUEST_DW) ) i_cdc_req
  (
    .src_rst_ni  ( trst_ni          ),
    .src_clk_i   ( tck_i            ),
    .src_data_i  ( jtag_dmi_req_i   ),
    .src_valid_i ( jtag_dmi_valid_i ),
    .src_ready_o ( jtag_dmi_ready_o ),

    .dst_rst_ni  ( rst_ni           ),
    .dst_clk_i   ( clk_i            ),
    .dst_data_o  ( core_dmi_req_o   ),
    .dst_valid_o ( core_dmi_valid_o ),
    .dst_ready_i ( core_dmi_ready_i )
  );

  cdc_2phase  #( .DW (RESPONSE_DW) ) i_cdc_resp
  (
    .src_rst_ni  ( rst_ni           ),
    .src_clk_i   ( clk_i            ),
    .src_data_i  ( core_dmi_resp_i  ),
    .src_valid_i ( core_dmi_valid_i ),
    .src_ready_o ( core_dmi_ready_o ),

    .dst_rst_ni  ( trst_ni          ),
    .dst_clk_i   ( tck_i            ),
    .dst_data_o  ( jtag_dmi_resp_o  ),
    .dst_valid_o ( jtag_dmi_valid_o ),
    .dst_ready_i ( jtag_dmi_ready_i )
  );

endmodule

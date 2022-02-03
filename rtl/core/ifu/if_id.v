/*-------------------------------------------------------------------------
// Module:  if_id
// File:    if_id.v
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: fetch instruction from the instruction rom
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

//`include "../include/defines.v"
`include "defines.v"

module if_id(

    input wire                    clk_i,
    input wire                    n_rst_i,

    /* ------- signals from the ctrl unit --------*/
    input wire[5:0]               stall_i,
    input wire                    ctrl_redirect_pc_i,
    input wire                    flush_i,

    /* ------- signals from the ifu  -------------*/
    input wire[`InstAddrBus]      pc_i,
    input wire[`InstAddrBus]      next_pc_i,
    input wire                    next_taken_i,
	input wire                    branch_slot_end_i,

    /* ------- signals from the inst_rom  --------*/
    input wire[`InstBus]          inst_i, //the instruction

    /* ---------signals from exu -----------------*/
    input wire                    branch_redirect_i,

	/* ------- signals to the decode -------------*/
    output reg[`InstAddrBus]      pc_o,
    output reg[`InstBus]          inst_o,
    output reg[`InstAddrBus]      next_pc_o,
    output reg                    next_taken_o,

	output reg                    branch_slot_end_o
);

    reg branch_stage;

    /* handle branch status */
    always @ (posedge clk_i or negedge n_rst_i) begin
        if (n_rst_i == `RstEnable) begin
            branch_stage = 1'b0;
        end else begin //if (n_rst_i == `RstEnable) begin
            if (branch_redirect_i == 1'b1) begin
                // this case is ok no matter whatever branch_slot_end_i is.
                branch_stage = 1'b1;
            end else begin
                if (branch_slot_end_i) begin
                    branch_stage = 1'b0;
                end
            end
        end
    end

    always @ (posedge clk_i or negedge n_rst_i) begin
        if (n_rst_i == `RstEnable) begin
            pc_o <= `ZeroWord;
            inst_o <= `NOP_INST;
            branch_slot_end_o <= 1'b0;
            next_pc_o <= `ZeroWord;
            next_taken_o <= 1'b0;
        end else begin //if (n_rst_i == `RstEnable) begin
            if( (flush_i == 1'b1) || (ctrl_redirect_pc_i == 1'b1) ) begin
                pc_o <= pc_i;
                inst_o <= `NOP_INST;
                branch_slot_end_o <= branch_slot_end_i;
            end else begin  //if(flush_i == 1'b1 ) begin
                if ( (branch_redirect_i == 1'b1) || (branch_stage == 1'b1) )begin
                    pc_o <= pc_i;
                    inst_o <= `NOP_INST;
                    branch_slot_end_o <= 1'b0;
                end else begin  //if (branch_redirect_i == 1'b1) begin
                    branch_slot_end_o <= branch_slot_end_i;
                    if(stall_i[1] == `Stop) begin
                        if(stall_i[2] == `NoStop) begin
                            // stop the fetching but keep the decoder on going
                            pc_o <= pc_i;
                            inst_o <= `NOP_INST;
                        end else begin //if(stall_i[2] == `NoStop) begin
                            pc_o <= pc_o;
                            inst_o <= inst_o;
                            next_pc_o <= next_pc_o;
                            next_taken_o <= next_taken_o;
                        end // if(stall_i[2] == `NoStop) begin
                    end else begin //if(stall_i[1] == `Stop) begin
                        // pass the signals from ifu to decoder
                        pc_o <= pc_i;
                        inst_o <= inst_i;
                        next_pc_o <= next_pc_i;
                        next_taken_o <= next_taken_i;
                    end // if(stall_i[1] == `Stop) begin
                end // if (branch_redirect_i == 1'b1) begin
            end // if(flush_i == 1'b1 ) begin
        end // if (n_rst_i == `RstEnable) begin
    end
endmodule

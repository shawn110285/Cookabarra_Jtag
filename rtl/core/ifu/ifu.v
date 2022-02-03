/*-------------------------------------------------------------------------
// Module:  ifu
// File:    ifu.v
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: generate the pc for instruction fetching
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

module ifu(
    input   wire                  clk_i,
    input   wire                  n_rst_i,

    /* ------- signals from the ctrl unit --------*/
    input wire[5:0]               stall_i,
    input wire                    ctrl_redirect_pc_i,
    input wire                    flush_i,
    input wire[`InstAddrBus]      new_pc_i,

    /* --------signals from bp --------------------*/
    input wire[`InstAddrBus]       next_pc_i,     // next pc predicted by bp
    input wire                     next_taken_i,  // next pc is a branch take or not? forward to execute via fetch module

    //bypass from exu
    input wire                    branch_redirect_i,     //miss predicted, need to redirect the pc
    input wire[`InstAddrBus]      branch_redirect_pc_i,  //the redirect pc

	/* ------- signals to inst_rom and decode unit --------*/
    output reg[`InstAddrBus]      pc_o, // the pc, to the inst_rom and decode module
    output reg                    ce_o,  // to inst_rom

    /*-----the prediction info to exe unit---------------*/
    output wire[`InstAddrBus]      next_pc_o,     // next pc predicted by bp
    output wire                    next_taken_o,

    /*-----if miss predicted, redirected pc to branch target started from here*/
    output reg                    branch_slot_end_o
);
    assign  next_pc_o = next_pc_i;
    assign  next_taken_o = next_taken_i;

    reg[`InstAddrBus]  local_branch_redirect_pc;
    reg                local_branch_redirect;

    always @ (posedge clk_i or negedge n_rst_i) begin
        if (n_rst_i == `RstEnable) begin
            ce_o <= `ChipDisable;
        end else begin
            ce_o <= `ChipEnable;
        end
    end

    always @ (posedge clk_i) begin
        if (ce_o == `ChipDisable) begin  // delay one tap,
            $display("================ reset the system from boot_addr ===============");
            pc_o <= `REBOOT_ADDR;
            local_branch_redirect <= `NotBranch;
            local_branch_redirect_pc <= `REBOOT_ADDR;
            branch_slot_end_o <= 1'b0;
        end else begin
            if( (flush_i == 1'b1) || (ctrl_redirect_pc_i == 1'b1) ) begin
                pc_o <= new_pc_i;
                branch_slot_end_o <= 1'b0;
            end else begin
                if(branch_redirect_i == `Branch) begin
                    if(stall_i[0] == `NoStop) begin
                        pc_o <= branch_redirect_pc_i;  // fetch the instruction from the branch target address
                        branch_slot_end_o <= 1'b1;
                    end else begin  // if(stall_i[0] == `NoStop)
                        pc_o <= pc_o;
                        // save the branch request for n cycles
                        local_branch_redirect <= branch_redirect_i;
                        local_branch_redirect_pc <= branch_redirect_pc_i;
                    end
                end else begin  // if(branch_redirect_i == `Branch) begin
                    if(stall_i[0] == `NoStop) begin
                        if(local_branch_redirect) begin
                            pc_o <= local_branch_redirect_pc;
                            local_branch_redirect <= `NotBranch;
                            branch_slot_end_o <= 1'b1;
                        end else begin
                            pc_o <= next_pc_i;    // next line prediction  current_pc
                            branch_slot_end_o <= 1'b0;
                        end
                    end else begin  // if(stall_i[0] == `NoStop)
                        pc_o <= pc_o;
                        branch_slot_end_o <= 1'b0;
                    end
                end // if(branch_redirect_i == `Branch) begin
            end // if(flush_i == 1'b1) begin
        end // if (ce_o == `ChipDisable) begin  // delay one tap,
    end // always @ (posedge clk_i) begin
endmodule

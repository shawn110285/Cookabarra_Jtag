/*-------------------------------------------------------------------------
// Module:  dtm_jtag
// File:    dtm_jtag.v
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: the RISC-V Debug transport Module implementation based on JTAG

// dtm)----->dmi(bus) ----> dm ---(abstract commmands or reset/halt control)--> risc-v core
//                           |
//                           |-----(bus access)---> momory system
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


module dtm_jtag #(
    parameter DMI_ADDR_BITS = 5,
    parameter DMI_DATA_BITS = 32,
    parameter DMI_OP_BITS = 2)
    (
        // the input signals from the jtag connector
        input                                                       nrst_i,
        input                                                       jtag_TCK,
        input                                                       jtag_TDI,
        input                                                       jtag_TMS,
        // the output signal to the jtag connector
        output reg                                                  jtag_TDO,

        // signals (access request) from dtm to dm
        output                                                      dtm_req_valid_o,
        output [DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS-1:0]    dtm_req_data_o,
        // signals (ack to the above request) from dm to dtm
        input                                                       dm_req_ack_i,

        // signals (response to the access request) from dtm to dtm
        input                                                       dm_resp_valid_i,
        input [DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS-1:0]     dm_resp_data_i,
        // signal (acke the response) from dtm to dm
        output                                                      dtm_resp_ack_o
    );

    localparam IR_BITS        = 5;
    localparam DM_RESP_BITS   = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;
    localparam DTM_REQ_BITS   = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;
    // the length of the shift reg
    localparam SHIFT_REG_BITS = DTM_REQ_BITS;

    /* 1-bit register that has no effect. It is used when a debugger does not want to communicate with this TAP. */
    localparam REG_BYPASS       = 5'b11111;  // 0x1c
    localparam REG_IDCODE       = 5'b00001;
    localparam REG_DTMCS        = 5'b10000;
    localparam REG_DMI          = 5'b10001;

/*=================================== jtag tap state switch ===========================================
    Test Access Port (TAP) Controller: a state machine whose transitions are controlled by the TMS signal,
    controls the behaviour of the JTAG system
*/
    localparam TEST_LOGIC_RESET_STATE = 0;
    localparam RUN_TEST_IDLE_STATE    = 1;
    localparam SELECT_DR_SCAN_STATE   = 2;
    localparam CAPTURE_DR_STATE       = 3;
    localparam SHIFT_DR_STATE         = 4;
    localparam EXIT1_DR_STATE         = 5;
    localparam PAUSE_DR_STATE         = 6;
    localparam EXIT2_DR_STATE         = 7;

    localparam UPDATE_DR_STATE        = 8;
    localparam SELECT_IR_SCAN_STATE   = 9;

    localparam CAPTURE_IR_STATE       = 10;
    localparam SHIFT_IR_STATE         = 11;

    localparam EXIT1_IR_STATE         = 12;
    localparam PAUSE_IR_STATE         = 13;
    localparam EXIT2_IR_STATE         = 14;
    localparam UPDATE_IR_STATE        = 15;


    // =====================================================================================
    // Jtag idcode { version[31:28], partNumber[27:12], manufacturer_id[11:1], 1'b1}
    // =====================================================================================
    wire [31:0]   idcode;
    localparam IDCODE_VERSION     = 4'h1;
    localparam IDCODE_PART_NUMBER = 16'he200;
    localparam IDCODE_MANUF_ID    = 11'h537;

    assign idcode = {IDCODE_VERSION, IDCODE_PART_NUMBER, IDCODE_MANUF_ID, 1'h1};


    /* ============================ debug transport module control and status register ==========================================
    dtmcs: { 0[31:18], dimhardreset[17], dmireset[16], 0[15], idle[14:12], dmistat[11:10], abits[9:4], version[3:0]}
        xxxxxxxxxxxxxx (14 bits):0
        dmihardreset (1 bit): Writing 1 to this bit does a hard reset of the DTM, causing the DTM to forget about any outstanding DMI transactions.
        dmireset (1bit) : Writing 1 to this bit clears the sticky error state and allows the DTM to retry or complete the previous transaction.
        x(1bit):
        idle(3 bits): This is a hint to the debugger of the minimum number of cycles a debugger should spend in Run-Test/Idle after every DMI scan to avoid a ‘busy’ return code (dmistat of 3).
        dmistat (2 bits): 0: No error. 1: Reserved. Interpret the same as 2. 2: An operation failed (resulted in op of 2). 3: An operation was attempted while a DMI access was still in progress
        abits(6 bits): The size of address in dmi.
        version (4 bits): 0: Version described in spec version 0.11.  1: Version described in spec version 0.13
    */
    localparam DTM_VERSION  = 4'h1;
    wire [31:0]     dtmcs;
    wire [1:0]      dmi_stat;
    wire [5:0]      addr_bits = DMI_ADDR_BITS;

    assign dtmcs = {14'b0,
                    1'b0,  // dmihardreset
                    1'b0,  // dmireset
                    1'b0,
                    3'h5,  // idle
                    dmi_stat,
                    addr_bits,
                    DTM_VERSION};


    assign dtm_resp_ack_o = dm_resp_valid_i;
    wire[SHIFT_REG_BITS - 1:0] busy_response = {{(DMI_ADDR_BITS + DMI_DATA_BITS){1'b0}}, {(DMI_OP_BITS){1'b1}}};
    wire[SHIFT_REG_BITS - 1:0] none_busy_response = dm_resp_data_i;

    reg [3:0]    jtag_state;
    wire jtag_reset_state      = jtag_state == TEST_LOGIC_RESET_STATE;
    wire jtag_shift_dr_state   = jtag_state == SHIFT_DR_STATE;
    wire jtag_pause_dr_state   = jtag_state == PAUSE_DR_STATE;
    wire jtag_update_dr_state  = jtag_state == UPDATE_DR_STATE;
    wire jtag_capture_dr_state = jtag_state == CAPTURE_DR_STATE;
    wire jtag_shift_ir_state   = jtag_state == SHIFT_IR_STATE;
    wire jtag_pause_ir_state   = jtag_state == PAUSE_IR_STATE;
    wire jtag_update_ir_state  = jtag_state == UPDATE_IR_STATE;
    wire jtag_capture_ir_state = jtag_state == CAPTURE_IR_STATE;

    always @(posedge jtag_TCK or negedge nrst_i) begin
        if (!nrst_i) begin
            jtag_state <= TEST_LOGIC_RESET_STATE;
        end else begin
            case (jtag_state)
                TEST_LOGIC_RESET_STATE  : jtag_state <= jtag_TMS ? TEST_LOGIC_RESET_STATE : RUN_TEST_IDLE_STATE;
                RUN_TEST_IDLE_STATE     : jtag_state <= jtag_TMS ? SELECT_DR_SCAN_STATE   : RUN_TEST_IDLE_STATE;
                SELECT_DR_SCAN_STATE    : jtag_state <= jtag_TMS ? SELECT_IR_SCAN_STATE   : CAPTURE_DR_STATE;
                CAPTURE_DR_STATE        : jtag_state <= jtag_TMS ? EXIT1_DR_STATE         : SHIFT_DR_STATE;
                SHIFT_DR_STATE          : jtag_state <= jtag_TMS ? EXIT1_DR_STATE         : SHIFT_DR_STATE;
                EXIT1_DR_STATE          : jtag_state <= jtag_TMS ? UPDATE_DR_STATE        : PAUSE_DR_STATE;
                PAUSE_DR_STATE          : jtag_state <= jtag_TMS ? EXIT2_DR_STATE         : PAUSE_DR_STATE;
                EXIT2_DR_STATE          : jtag_state <= jtag_TMS ? UPDATE_DR_STATE        : SHIFT_DR_STATE;
                UPDATE_DR_STATE         : jtag_state <= jtag_TMS ? SELECT_DR_SCAN_STATE   : RUN_TEST_IDLE_STATE;
                SELECT_IR_SCAN_STATE    : jtag_state <= jtag_TMS ? TEST_LOGIC_RESET_STATE : CAPTURE_IR_STATE;
                CAPTURE_IR_STATE        : jtag_state <= jtag_TMS ? EXIT1_IR_STATE         : SHIFT_IR_STATE;
                SHIFT_IR_STATE          : jtag_state <= jtag_TMS ? EXIT1_IR_STATE         : SHIFT_IR_STATE;
                EXIT1_IR_STATE          : jtag_state <= jtag_TMS ? UPDATE_IR_STATE        : PAUSE_IR_STATE;
                PAUSE_IR_STATE          : jtag_state <= jtag_TMS ? EXIT2_IR_STATE         : PAUSE_IR_STATE;
                EXIT2_IR_STATE          : jtag_state <= jtag_TMS ? UPDATE_IR_STATE        : SHIFT_IR_STATE;
                UPDATE_IR_STATE         : jtag_state <= jtag_TMS ? SELECT_DR_SCAN_STATE   : RUN_TEST_IDLE_STATE;
            endcase
        end
    end



    reg[SHIFT_REG_BITS - 1:0]  shift_reg;
    wire dtm_reset = shift_reg[16];

    /*
    JTAG TAPs used as a DTM must have an IR of at least 5 bits. When the TAP is reset, IR must default to 00001,
    selecting the IDCODE instruction. If the IR actually has more than 5 bits, then the encodings should be extended
    with 0’s in their most significant bits. The only regular JTAG registers a debugger might use are BYPASS and IDCODE,
    but this specification leaves IR space for many other standard JTAG instructions.
    Unimplemented instructions must select the BYPASS register.
    */

    // =====================================================================================
    // select the ir register on the UPDATE_IR_STATE state
    // =====================================================================================
    reg [IR_BITS - 1:0]   ir_reg;
    always @(negedge jtag_TCK or negedge nrst_i) begin
        if (!nrst_i) begin
            ir_reg <= REG_IDCODE;
        end else begin
            if (jtag_reset_state) begin
                ir_reg <= REG_IDCODE;
            end else if (jtag_update_ir_state) begin
                ir_reg <= (shift_reg[IR_BITS - 1:0] == '0) ? 5'h1f : shift_reg[IR_BITS - 1:0];
            end
        end
    end

    /* dmi register allows access to the Debug Module Interface (DMI) ,
    In Update-DR, the DTM starts the operation specified in op unless the current status reported in op is sticky.
    In Capture-DR, the DTM updates data with the result from that operation, updating op if the current op isn’t sticky.

    still-in-progress status is sticky to accommodate debuggers that batch together a number of scans,
    which must all be executed or stop as soon as there’s a problem.
    */

    // IR or DR shift
    always @(posedge jtag_TCK or negedge nrst_i) begin
        if (nrst_i != 1'b0) begin
            case (jtag_state)
                // IR
                CAPTURE_IR_STATE:
                    shift_reg <= {{(SHIFT_REG_BITS - 1){1'b0}}, 1'b1}; //JTAG spec says it must be b01

                SHIFT_IR_STATE:
                    shift_reg <= {{(SHIFT_REG_BITS - IR_BITS){1'b0}}, jtag_TDI, shift_reg[IR_BITS - 1:1]}; // right shift 1 bit

                // DR
                // In Capture-DR, the DTM updates data with the result from that operation, updating op if the current op isn’t sticky.
                CAPTURE_DR_STATE: begin
                    case (ir_reg)
                        REG_BYPASS: begin
                            shift_reg <= {(SHIFT_REG_BITS){1'b0}};
                            //$display("tranfer bypass to host");
                        end

                        REG_IDCODE: begin
                            shift_reg <= {{(SHIFT_REG_BITS - DMI_DATA_BITS){1'b0}}, idcode};
                            //$display("tranfer idcode to host, idcode=0x%h", idcode);
                        end

                        REG_DTMCS: begin
                            shift_reg <= {{(SHIFT_REG_BITS - DMI_DATA_BITS){1'b0}}, dtmcs};
                            //$display("tranfer dtmcs to host, dmi_stat=%d (dm_busy=%d, sticky_busy=%d), addr_bits=%d", dmi_stat, dm_is_busy, sticky_busy, addr_bits);
                        end

                        REG_DMI: begin
                            shift_reg <=  is_busy ? busy_response : none_busy_response;
                            //$display("tranfer dmi to host, is_busy=0x%h, dmi=0x%h", is_busy, (is_busy ? busy_response : none_busy_response));
                        end

                        default: begin
                            shift_reg <= {(SHIFT_REG_BITS){1'b0}};
                        end
                    endcase
                end

                SHIFT_DR_STATE  :
                    case (ir_reg)
                        REG_BYPASS:
                            shift_reg <= {{(SHIFT_REG_BITS - 1){1'b0}}, jtag_TDI}; // in = out

                        REG_IDCODE:
                            shift_reg <= {{(SHIFT_REG_BITS - DMI_DATA_BITS){1'b0}}, jtag_TDI, shift_reg[31:1]}; // right shift 1 bit

                        REG_DTMCS:
                            shift_reg <= {{(SHIFT_REG_BITS - DMI_DATA_BITS){1'b0}}, jtag_TDI, shift_reg[31:1]}; // right shift 1 bit

                        REG_DMI:
                            shift_reg <= {jtag_TDI, shift_reg[SHIFT_REG_BITS - 1:1]}; // right shift 1 bit

                        default:
                            shift_reg <= {{(SHIFT_REG_BITS - 1){1'b0}} , jtag_TDI};
                    endcase

                default: begin

                end
            endcase
        end // if (nrst_i != 1'b0) begin
    end

    /* ================================= start access DM module ===================================
    To read an arbitrary Debug Module register, select dmi, and scan in a value with op set to 1,
    and address set to the desired register address.
    In Update-DR the operation will start, and in Capture-DR its results will be captured into data.
    If the operation didn’t complete in time, op will be 3 and the value in data must be ignored.
    The busy condition must be cleared by writing dmireset in dtmcs, and then the second scan scan must be performed again.
    This process must be repeated until op returns 0. In later operations the debugger should allow for more time between
    Capture-DR and Update-DR.

    To write an arbitrary Debug Bus register, select dmi, and scan in a value with op set to 2, and
    address and data set to the desired register address and data respectively. From then on everything
    happens exactly as with a read, except that a write is performed instead of the read.


    dmi {address[abits+33:34] , data[33:2], op[1:0]}:
     address: Address used for DMI access. In Update-DR this value is used to access the DM over the DMI.
        data: The data to send to the DM over the DMI during Update-DR,
              and the data returned from the DM as a result of the previous operation.
          op: When the debugger writes this field, it has the following meaning:
                0: Ignore data and address. (nop) Don’t send anything over the DMI during Update-DR.
                    This operation should never result in a busy or error response.
                    The address and data reported in the following Capture-DR are undefined.
                1: Read from address. (read)
                2: Write data to address. (write)
                3: Reserved.

            When the debugger reads this field, it means the following:
                0: The previous operation completed successfully.
                1: Reserved.
                2: A previous operation failed. The data scanned into dmi in this access will be ignored. This status
                    is sticky and can be cleared by writing dmireset in dtmcs. This indicates that the DM itself responded with
                    an error, e.g. in the System Bus and Serial Port overflow/underflow cases.
                3: An operation was attempted while a DMI request is still in progress. The data scanned into
                    dmi in this access will be ignored. This status is sticky and can be cleared by writing dmireset in
                    dtmcs. If a debugger sees this status, it needs to give the target more TCK edges between Update-
                    DR and Capture-DR. The simplest way to do that is to add extra transitions in Run-Test/Idle.
                    (The DTM, DM, and/or component may be in different clock domains, so synchronization may
                    be required. Some relatively fixed number of TCK ticks may be needed for the request to reach the
                    DM, complete, and for the response to be synchronized back into the TCK domain.)
    */

    reg    sticky_busy;
    reg    dm_is_busy;
    wire   is_busy;
    assign is_busy = dm_is_busy | sticky_busy;
    assign dmi_stat = is_busy ? 2'b01 : 2'b00;

    // =====================================================================================
    //  dm_is_busy, busy on talking with dm
    // =====================================================================================
    always @ (posedge jtag_TCK or negedge nrst_i) begin
        if (!nrst_i) begin
            dm_is_busy <= 1'b0;
        end else begin
            if (dtm_req_valid) begin
                dm_is_busy <= 1'b1;
            end else if (dm_resp_valid_i) begin
                dm_is_busy <= 1'b0;
            end
        end
    end

    // sticky_busy
    // In Update-DR, the DTM starts the operation specified in op unless the current status reported in op is sticky.
    // In Capture-DR, the DTM updates data with the result from that operation, updating op if the current op isn’t sticky.
    always @ (posedge jtag_TCK or negedge nrst_i) begin
        if (!nrst_i) begin
            sticky_busy <= 1'b0;
        end else begin
            if (jtag_update_dr_state) begin
                if (ir_reg == REG_DTMCS & dtm_reset) begin
                    sticky_busy <= 1'b0;
                end
            end else if (jtag_capture_dr_state) begin
                if (ir_reg == REG_DMI) begin
                    sticky_busy <= is_busy;
                end
            end
        end
    end


    reg                         dtm_req_valid;
    reg [DTM_REQ_BITS - 1:0]    dtm_req_data;

    assign dtm_req_valid_o = dtm_req_valid;
    assign dtm_req_data_o = dtm_req_data;

    always @(posedge jtag_TCK or negedge nrst_i) begin
        if (!nrst_i) begin
            dtm_req_valid <= 1'b0;
            dtm_req_data <= {DTM_REQ_BITS{1'b0}};
        end else begin
            // In Update-DR, the DTM starts the operation specified in op unless the current status reported in op is sticky.
            if (jtag_update_dr_state) begin
                if (ir_reg == REG_DMI) begin
                    // if DM can be access
                    // $display("tranfer data from host to dmi, dmi=0x%h, dm_busy=%d, sticky_busy=%d, dm_req_ack_i=%d", shift_reg, dm_is_busy, sticky_busy, dm_req_ack_i);
                    if (!is_busy & dm_req_ack_i) begin
                        dtm_req_valid <= 1'b1;
                        dtm_req_data <= shift_reg;
                    end
                end
            end else begin
                dtm_req_valid <= 1'b0;
            end
        end
    end


    // output via tdo on the negative edge of clk_i
    always @(negedge jtag_TCK) begin
        if (jtag_shift_ir_state) begin
            jtag_TDO <= shift_reg[0];
        end else if (jtag_shift_dr_state) begin
            jtag_TDO <= shift_reg[0];
        end else begin
            jtag_TDO <= 1'b0;
        end
    end

endmodule

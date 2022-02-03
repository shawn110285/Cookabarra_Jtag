/*-------------------------------------------------------------------------
// Module:  csr
// File:    csr.v
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: csr (control and status register)
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

module csr_file(

    input wire               clk_i,
    input wire               n_rst_i,

    /* --- interrupt signals from clint or clic--------*/
    input  wire              irq_software_i,
    input  wire              irq_timer_i,
    input  wire              irq_external_i,

    /* --- exu read csr -------------------*/
    input wire[11:0]         raddr_i,           // the register to read
    output reg[`RegBus]      rdata_o,           // ouput the register


    /*------ wb module update the csr  --------*/
    input wire               we_i,            // write enable
    input wire[11:0]         waddr_i,         // the register to write
    input wire[`RegBus]      wdata_i,         // the data to write

    input wire               instret_incr_i,   // 0 or 1 indicate increase the counter of instret

    /* ---- ctrl update epc, mcause, mtval, global ie ----*/
    input wire               ie_type_i,          // interrupt or exception
    input wire               set_cause_i,
    input wire [3:0]         trap_casue_i,

    input wire               set_epc_i,
    input wire[`RegBus]      epc_i,

    input wire               set_mtval_i,
    input wire[`RegBus]      mtval_i,

    input wire               mstatus_ie_clear_i,
    input wire               mstatus_ie_set_i,

    /*-- to control , interrupt enablers, mtvec, epc etc-----*/
    output wire              mstatus_ie_o,
    output wire              mie_external_o,
    output wire              mie_timer_o,
    output wire              mie_sw_o,

    output wire              mip_external_o,
    output wire              mip_timer_o,
    output wire              mip_sw_o,
    output wire[`RegBus]     mtvec_o,
    output wire[`RegBus]     epc_o,

    /* --------------- jtag access ----------*/
    input wire                    jtag_csr_req_i,   //access signal
    input wire[`RegBus]           jtag_csr_addr_i,  // the reg address
    input wire                    jtag_csr_we_i,    // write enable, not supported at the moment
    input wire[`RegBus]           jtag_csr_wdata_i, // the data to write
    output reg[`RegBus]           jtag_csr_rdata_o   // the read result
);

    // mvendorid
    // The mvendorid CSR is a 32-bit read-only register providing the JEDEC manufacturer ID of the
    // provider of the core. This register must be readable in any implementation, but a value of 0 can be
    // returned to indicate the field is not implemented or that this is a non-commercial implementation.
    localparam CSR_MVENDORID_VALUE  = 32'b0;

    // Architecture ID
    // The marchid CSR is an MXLEN-bit read-only register encoding the base microarchitecture of the
    // hart. This register must be readable in any implementation, but a value of 0 can be returned to
    // indicate the field is not implemented. The combination of mvendorid and marchid should uniquely
    // identify the type of hart microarchitecture that is implemented.
    localparam CSR_MARCHID_VALUE = 32'b0;

    // mimpid
    // The mimpid CSR provides a unique encoding of the version of the processor implementation. This
    // register must be readable in any implementation, but a value of 0 can be returned to indicate that
    // the field is not implemented.
    localparam  CSR_MIMPID_VALUE = 32'b0;

    // hardid
    // The mhartid CSR is an MXLEN-bit read-only register containing the integer ID of the hardware
    // thread running the code. This register must be readable in any implementation. Hart IDs might
    // not necessarily be numbered contiguously in a multiprocessor system, but at least one hart must
    // have a hart ID of zero.
    localparam CSR_MHARTID = 32'b0;



    /*--------------------------------------------- MISA ------------------------------------------*/
    // The misa CSR is a WARL read-write register reporting the ISA supported by the hart. This
    // register must be readable in any implementation, but a value of zero can be returned to indicate
    // the misa register has not been implemented
    wire [1:0]  mxl; // machine XLEN
    wire [25:0] mextensions; // ISA extensions
    wire [`RegBus] misa; // machine ISA register
    assign mxl = 2'b01;
    assign mextensions = 26'b00000000000001000100000000;  // i and m
    assign misa = {mxl, 4'b0, mextensions};


    /*--------------------------------------------- mcycle ------------------------------------------*/
    // mcycle : counts the number of clock cycles executed by the processor core on which the hart is running.
    // 64-bit precision on all RV32 and RV64 systems.
    reg[`DoubleRegBus] mcycle;   //server as cycle as well

    /*--------------------------------------------- minstret ----------------------------------------*/
    // minstret:  counts the number of instructions the hart has retired.
    // 64-bit precision on all RV32 and RV64 systems.
    reg[`DoubleRegBus] minstret;

    always @ (posedge clk_i or negedge n_rst_i) begin
        if (n_rst_i == `RstEnable) begin
            mcycle <= {`ZeroWord, `ZeroWord};
            minstret <= {`ZeroWord, `ZeroWord};
        end else begin
            mcycle <= mcycle + 64'd1;
            if(instret_incr_i) begin
                minstret <= minstret + 64'd1;
            end
        end
    end

    /*--------------------------------------------- mstatus ----------------------------------------*/
    // {SD(1), WPRI(8), TSR(1), TW(1), TVM(1), MXR(1), SUM(1), MPRV(1), XS(2),
    //  FS(2), MPP(2), WPRI(2), SPP(1), MPIE(1), WPRI(1), SPIE(1), UPIE(1),MIE(1), WPRI(1), SIE(1), UIE(1)}
    // Global interrupt-enable bits, MIE, SIE, and UIE, are provided for each privilege mode.
    // xPIE holds the value of the interrupt-enable bit active prior to the trap, and xPP holds the previous privilege mode.
    wire[`RegBus]      mstatus;
    reg                mstatus_pie; // prior interrupt enable
    reg                mstatus_ie;
    assign             mstatus_ie_o = mstatus_ie;
    assign mstatus = {19'b0, 2'b11, 3'b0, mstatus_pie, 3'b0 , mstatus_ie, 3'b0};

    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            mstatus_ie <= 1'b0;
            mstatus_pie <= 1'b1;
        end else if( (waddr_i == `CSR_MSTATUS_ADDR) && (we_i == `WriteEnable) ) begin
            mstatus_ie <= wdata_i[3];
            mstatus_pie <= wdata_i[7];
        end else if(mstatus_ie_clear_i == 1'b1) begin
            mstatus_pie <= mstatus_ie;
            mstatus_ie <= 1'b0;
        end else if(mstatus_ie_set_i == 1'b1) begin
            mstatus_ie <= mstatus_pie;
            mstatus_pie <= 1'b1;
        end
    end



    /*--------------------------------------------- mie ----------------------------------------*/
    // mie: {WPRI[31:12], MEIE(1), WPRI(1), SEIE(1), UEIE(1), MTIE(1), WPRI(1), STIE(1), UTIE(1), MSIE(1), WPRI(1), SSIE(1), USIE(1)}
    // MTIE, STIE, and UTIE for M-mode, S-mode, and U-mode timer interrupts respectively.
    // MSIE, SSIE, and USIE fields enable software interrupts in M-mode, S-mode software, and U-mode, respectively.
    // MEIE, SEIE, and UEIE fields enable external interrupts in M-mode, S-mode software, and U-mode, respectively.
    wire[`RegBus]  mie;
    reg           mie_external; // external interrupt enable
    reg           mie_timer;    // timer interrupt enable
    reg           mie_sw;       // software interrupt enable

    assign mie_external_o = mie_external;
    assign mie_timer_o = mie_timer;
    assign mie_sw_o = mie_sw;

    assign mie = {20'b0, mie_external, 3'b0, mie_timer, 3'b0, mie_sw, 3'b0};

    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            mie_external <= 1'b0;
            mie_timer <= 1'b0;
            mie_sw <= 1'b0;
        end else if((waddr_i == `CSR_MIE_ADDR) && (we_i == `WriteEnable)) begin
            mie_external <= wdata_i[11];
            mie_timer <= wdata_i[7];
            mie_sw <= wdata_i[3];
        end
    end


    /*--------------------------------------------- mtvec ----------------------------------------*/
    // The mtvec register is an MXLEN-bit read/write register that holds trap vector configuration,
    // consisting of a vector base address (BASE) and a vector mode (MODE).
    // mtvec = { base[maxlen-1:2], mode[1:0]}
    // The value in the BASE field must always be aligned on a 4-byte boundary, and the MODE setting may impose
    // additional alignment constraints on the value in the BASE field.
    // when mode =2'b00, direct mode, When MODE=Direct, all traps into machine mode cause the pc to be set to the address in the BASE field.
    // when mode =2'b01, Vectored mode, all synchronous exceptions into machine mode cause the pc to be set to the address in the BASE
    // field, whereas interrupts cause the pc to be set to the address in the BASE field plus four times the interrupt cause number.

    reg[`RegBus]     mtvec;
    assign mtvec_o = mtvec;

    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            mtvec <= `MTVEC_RESET;
        end else if( (waddr_i == `CSR_MTVEC_ADDR) && (we_i == `WriteEnable) ) begin
            mtvec <= wdata_i;
        end
    end


    /*--------------------------------------------- mscratch ----------------------------------------*/
    // mscratch : Typically, it is used to hold a pointer to a machine-mode hart-local context space and swapped
    // with a user register upon entry to an M-mode trap handler.
    reg[`RegBus]       mscratch;

    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            mscratch <= `ZeroWord;
        end else if( (waddr_i == `CSR_MSCRATCH_ADDR) && (we_i == `WriteEnable) ) begin
            mscratch <= wdata_i;
        end
    end

    /*--------------------------------------------- mepc ----------------------------------------*/
    // When a trap is taken into M-mode, mepc is written with the virtual address of the instruction
    // that was interrupted or that encountered the exception.
    // The low bit of mepc (mepc[0]) is always zero.
    // On implementations that support only IALIGN=32, the two low bits (mepc[1:0]) are always zero.
    reg[`RegBus]       mepc;

    assign epc_o = mepc;
    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            mepc <= `ZeroWord;
        end else if(set_epc_i) begin
            mepc <= {epc_i[31:2], 2'b00};
        end else if( (waddr_i == `CSR_MEPC_ADDR) && (we_i == `WriteEnable) ) begin
            mepc <= {wdata_i[31:2], 2'b00};
        end
    end


    /*--------------------------------------------- mcause ----------------------------------------*/
    // When a trap is taken into M-mode, mcause is written with a code indicating the event that caused the trap.
    // Otherwise, mcause is never written by the implementation, though it may be explicitly written by software.
    // mcause = {interupt[31:30], Exception code }
    // The Interrupt bit in the mcause register is set if the trap was caused by an interrupt. The Exception
    // Code field contains a code identifying the last exception.

    wire[`RegBus]       mcause;
    reg [3:0]          cause; // interrupt cause
    reg [26:0]         cause_rem; // remaining bits of mcause register
    reg                int_or_exc; // interrupt or exception signal

    assign mcause = {int_or_exc, cause_rem, cause};
    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            cause <= 4'b0000;
            cause_rem <= 27'b0;
            int_or_exc <= 1'b0;
        end else if(set_cause_i) begin
            cause <= trap_casue_i;
            cause_rem <= 27'b0;
            int_or_exc <= ie_type_i;
        end else if( (waddr_i == `CSR_MCAUSE_ADDR) && (we_i == `WriteEnable) ) begin
            cause <= wdata_i[3:0];
            cause_rem <= wdata_i[30:4];
            int_or_exc <= wdata_i[31];
        end
    end

    /*--------------------------------------------- mip ----------------------------------------*/
    // mip: {WPRI[31:12], MEIP(1), WPRI(1), SEIP(1), UEIP(1), MTIP(1), WPRI(1), STIP(1), UTIP(1), MSIP(1), WPRI(1), SSIP(1), USIP(1)}
    // The MTIP, STIP, UTIP bits correspond to timer interrupt-pending bits for machine, supervisor, and user timer interrupts, respectively.
    wire[`RegBus]      mip;
    reg                mip_external; // external interrupt pending
    reg                mip_timer; // timer interrupt pending
    reg                mip_sw; // software interrupt pending

    assign mip = {20'b0, mip_external, 3'b0, mip_timer, 3'b0, mip_sw, 3'b0};

    assign mip_external_o = mip_external;
    assign mip_timer_o = mip_timer;
    assign mip_sw_o = mip_sw;

    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            mip_external <= 1'b0;
            mip_timer <= 1'b0;
            mip_sw <= 1'b0;
        end else begin
            mip_external <= irq_external_i;
            mip_timer <= irq_timer_i;
            mip_sw <= irq_software_i;
        end
    end


    /*--------------------------------------------- mtval ----------------------------------------*/
    // When a trap is taken into M-mode, mtval is either set to zero or written with exception-specific information
    // to assist software in handling the trap.
    // When a hardware breakpoint is triggered, or an instruction-fetch, load, or store address-misaligned,
    // access, or page-fault exception occurs, mtval is written with the faulting virtual address.
    // On an illegal instruction trap, mtval may be written with the first XLEN or ILEN bits of the faulting instruction
    reg[`RegBus]       mtval;

    always @(posedge clk_i or negedge n_rst_i)  begin
        if(n_rst_i == `RstEnable)
            mtval <= 32'b0;
        else if(set_mtval_i) begin
            mtval <= mtval_i;
        end else if( (waddr_i == `CSR_MTVAL_ADDR) && (we_i == `WriteEnable) )
            mtval <= wdata_i;
    end



    /* ----------------------- read csr --------------------------------------*/
    always @ (*) begin
        // bypass the write port to the read port
        if ((waddr_i == raddr_i) && (we_i == `WriteEnable)) begin
            rdata_o = wdata_i;
        end else begin
            case (raddr_i)
                `CSR_MVENDORID_ADDR: begin
                    rdata_o = CSR_MVENDORID_VALUE;
                end

                `CSR_MARCHID_ADDR: begin
                    rdata_o = CSR_MARCHID_VALUE;
                end

                `CSR_MIMPID_ADDR: begin
                    rdata_o = CSR_MIMPID_VALUE;
                end

                `CSR_MHARTID_ADDR: begin
                    rdata_o = CSR_MHARTID;
                end

                `CSR_MISA_ADDR: begin
                    rdata_o = misa;
                end

                `CSR_MCYCLE_ADDR, `CSR_CYCLE_ADDR: begin
                    rdata_o = mcycle[`RegBus];
                end

                `CSR_MCYCLEH_ADDR, `CSR_CYCLEH_ADDR: begin
                    rdata_o = mcycle[63:32];
                end

               `CSR_MINSTRET_ADDR: begin
                    rdata_o = minstret[`RegBus];
                end

                `CSR_MINSTRETH_ADDR: begin
                    rdata_o = minstret[63:32];
                end

                `CSR_MSTATUS_ADDR: begin
                    rdata_o = mstatus;
                end

                `CSR_MIE_ADDR: begin
                    rdata_o = mie;
                end

                `CSR_MTVEC_ADDR: begin
                    rdata_o = mtvec;
                end

                `CSR_MTVAL_ADDR: begin
                    rdata_o = mtval;
                end

                `CSR_MIP_ADDR: begin
                    rdata_o = mip;
                end

                `CSR_MSCRATCH_ADDR: begin
                    rdata_o = mscratch;
                end

                `CSR_MEPC_ADDR: begin
                    rdata_o = mepc;
                end

                `CSR_MCAUSE_ADDR: begin
                    rdata_o = mcause;
                end

                default: begin
                    rdata_o = `ZeroWord;
                end
            endcase // case (waddr_i[11:0])
        end //end else begin
    end //always @ (*) begin

    /* ----------------------- jtag read csr --------------------------------------*/


    /*--------------------------------------------- dcsr ----------------------------------------
        dcsr: debug control and Status, 0x7b0
             {xdebugver[31:28], 0[27:16], ebreakm[15], ebreakh[14], ebreaks[13], ebreaku[12],
              0[11], stopcount[10], stoptime[9], cause[8:6], 0[5:3], step[2], prv[1:0] }
        xdebugver: 0: There is no external debug support. 4: External debug support exists as it is described in this document.
        ebreakm, ebreakh, ebreaks, ebreaku: When 1, ebreak instructions in other Mode enter Debug Mode.
        stopcount: 0: Increment counters as usual.
                   1: Don’t increment any counters while in Debug Mode. This includes the cycle and instret CSRs.
                      This is preferred for most debugging scenarios.
        stoptime: 0: Increment timers as usual.
                  1: Don’t increment any hart-local timers while in Debug Mode.
        cause: Explains why Debug Mode was entered. 1: An ebreak instruction was executed.
                                                    2: The Trigger Module caused a halt.
                                                    3: haltreq was set
                                                    4: The hart single stepped because step was set
        step: When set and not in Debug Mode, the hart will only execute a single instruction and then enter Debug Mode.
        prv: Contains the privilege level the hart was operating in when Debug Mode was entered.

        When ebreak is executed in Debug Mode, it halts the processor again but without updating dpc or dcsr.
    */
    wire[3:0]          xdebugver = 4'h4;
    wire               ebreakm = 1'b1;
    wire               ebreakh = 1'b1;
    wire               ebreaks = 1'b1;
    wire               ebreaku = 1'b1;

    wire               stopcount = 1'b0;
    wire               stoptime = 1'b0;
    wire[2:0]          dcsr_cause = 3'b0;
    wire               step = 1'b0;
    wire[1:0]          prv= 2'b11;

    reg[`RegBus]       dcsr;
    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            dcsr <= {xdebugver, 12'b0, ebreakm, ebreakh, ebreaks, ebreaku, 1'b0, stopcount, stoptime, dcsr_cause, 3'b0, step, prv};
        end else if( (jtag_csr_req_i == 1'b1) && (jtag_csr_we_i == 1'b1) && (jtag_csr_addr_i[11:0] == `CSR_DCSR_ADDR) ) begin
            dcsr <= jtag_csr_wdata_i;
        end
    end

    reg[`RegBus]       dpc;
    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            dpc <= `ZeroWord;
        end else if( (jtag_csr_req_i == 1'b1) && (jtag_csr_we_i == 1'b1) && (jtag_csr_addr_i[11:0] == `CSR_DPC_ADDR) ) begin
            dpc <= jtag_csr_wdata_i;
        end
    end

    reg[`RegBus]    dscratch0;
    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            dscratch0 <= `ZeroWord;
        end else if( (jtag_csr_req_i == 1'b1) && (jtag_csr_we_i == 1'b1) && (jtag_csr_addr_i[11:0] == `CSR_DSCRATCH0_ADDR) ) begin
            dscratch0 <= jtag_csr_wdata_i;
        end
    end

    reg[`RegBus]    dscratch1;
    always @(posedge clk_i or negedge n_rst_i) begin
        if(n_rst_i == `RstEnable) begin
            dscratch1 <= `ZeroWord;
        end else if( (jtag_csr_req_i == 1'b1) && (jtag_csr_we_i == 1'b1) && (jtag_csr_addr_i[11:0] == `CSR_DSCRATCH1_ADDR) ) begin
            dscratch1 <= jtag_csr_wdata_i;
        end
    end


    always @ (*) begin
        if( jtag_csr_req_i == 1'b1 ) begin
            // bypass the write port to the read port
            if ( (waddr_i[11:0] == jtag_csr_addr_i[11:0]) && (we_i == `WriteEnable) ) begin
                jtag_csr_rdata_o = wdata_i;
            end else begin
                case (jtag_csr_addr_i[11:0])
                    `CSR_MVENDORID_ADDR: begin
                        jtag_csr_rdata_o = CSR_MVENDORID_VALUE;
                    end

                    `CSR_MARCHID_ADDR: begin
                        jtag_csr_rdata_o = CSR_MARCHID_VALUE;
                    end

                    `CSR_MIMPID_ADDR: begin
                        jtag_csr_rdata_o = CSR_MIMPID_VALUE;
                    end

                    `CSR_MHARTID_ADDR: begin
                        jtag_csr_rdata_o = CSR_MHARTID;
                    end

                    `CSR_MISA_ADDR: begin
                        jtag_csr_rdata_o = misa;
                    end

                    `CSR_MCYCLE_ADDR, `CSR_CYCLE_ADDR: begin
                        jtag_csr_rdata_o = mcycle[`RegBus];
                    end

                    `CSR_MCYCLEH_ADDR, `CSR_CYCLEH_ADDR: begin
                        jtag_csr_rdata_o = mcycle[63:32];
                    end

                    `CSR_MINSTRET_ADDR: begin
                        jtag_csr_rdata_o = minstret[`RegBus];
                    end

                    `CSR_MINSTRETH_ADDR: begin
                        jtag_csr_rdata_o = minstret[63:32];
                    end

                    `CSR_MSTATUS_ADDR: begin
                        jtag_csr_rdata_o = mstatus;
                    end

                    `CSR_MIE_ADDR: begin
                        jtag_csr_rdata_o = mie;
                    end

                    `CSR_MTVEC_ADDR: begin
                        jtag_csr_rdata_o = mtvec;
                    end

                    `CSR_MTVAL_ADDR: begin
                        jtag_csr_rdata_o = mtval;
                    end

                    `CSR_MIP_ADDR: begin
                        jtag_csr_rdata_o = mip;
                    end

                    `CSR_MSCRATCH_ADDR: begin
                        jtag_csr_rdata_o = mscratch;
                    end

                    `CSR_MEPC_ADDR: begin
                        jtag_csr_rdata_o = mepc;
                    end

                    `CSR_MCAUSE_ADDR: begin
                        jtag_csr_rdata_o = mcause;
                    end

                    `CSR_DCSR_ADDR: begin
                        jtag_csr_rdata_o = dcsr;
                    end

                    `CSR_DPC_ADDR: begin
                        jtag_csr_rdata_o = dpc;
                    end

                    `CSR_DSCRATCH0_ADDR: begin
                        jtag_csr_rdata_o = dscratch0;
                    end

                    `CSR_DSCRATCH1_ADDR: begin
                        jtag_csr_rdata_o = dscratch1;
                    end

                    default: begin
                        jtag_csr_rdata_o = `ZeroWord;
                    end
                endcase // case (waddr_i[11:0])
            end // if ( (waddr_i[11:0] == jtag_csr_addr_i[11:0]) && (we_i == `WriteEnable) ) begin
        end else begin// if( jtag_csr_req_i == 1'b1 ) begin
            jtag_csr_rdata_o = `ZeroWord;
        end // if( jtag_csr_req_i == 1'b1 ) begin
    end //always @ (*) begin

endmodule

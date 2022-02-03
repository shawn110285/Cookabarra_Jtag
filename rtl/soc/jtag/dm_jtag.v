/*-------------------------------------------------------------------------
// Module:  dtm_jtag
// File:    dtm_jtag.v
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: the implementation of RISC-V Debug Module
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




/*
The Debug Module can halt harts and allow them to run again using the dmcontrol register.When
a debugger wants to halt a single hart it selects it in hartsel and sets haltreq, then waits for allhalted
to indicate the hart is halted before clearing haltreq to 0. Setting haltreq has no effect on a hart
which is already halted.
To resume, the debugger selects the hart with hartsel, and sets resumereq. This action sets the
hart’s resumeack bit to 0. Once the hart has resumed, it sets its resumeack bit to 1. Thus, the
debugger should wait for allresumeack to indicate the hart has resumed before clearing resumereq
to 0.*/


/* Debuggers execute abstract commands by writing them to command. Debuggers can determine
whether an abstract command is complete by reading busy in abstractcs. If the command takes
arguments, the debugger must write them to the data registers before writing to command. If a
command returns results, the Debug Module must ensure they are placed in the data registers
before busy is cleared. */


/*
To support executing arbitrary instructions on a halted hart, a Debug Module can include a Pro-
gram Buffer that a debugger can write small programs to. Systems that support all necessary
functionality using abstract commands only may choose to omit the Program Buffer.
A debugger can write a small program to the Program Buffer, and then execute it exactly once
with the Access Register Abstract Command, setting the postexec bit in command. If progsize is
1, the Program Buffer may only hold a single instruction. This can be a 32-bit instruction, or a
compressed instruction in the lower 16 bits accompanied by a compressed nop in the upper 16 bits.
If progsize is greater than 1, the debugger can write whatever program it likes, but the program
must end with ebreak or ebreak.c.

When a Program Buffer is present, a debugger can access the system bus by having a RISC-V
hart perform the accesses it requires. A Debug Module may also include a System Bus Access
block to provide memory access without involving a hart, regardless of whether Program Buffer is
implemented. The System Bus Access block uses physical addresses.
*/

/*
Below are two possible implementations. A designer could choose one, mix and match, or come up with their own design.
B.1 Abstract Command Based
    Halting happens by stalling the processor execution pipeline.
    Muxes on the register file(s) allow for accessing GPRs and CSRs using the Access Register abstract command.

B.2 Execution Based
    This implementation only implements the Access Register abstract command for GPRs on a halted hart,
    and relies on the Program Buffer for all other operations.
*/

/*


A debugger continuously monitors haltsum to see if any harts have spontaneously halted.

Single Step:
A debugger can single step the core by setting a breakpoint on the next instruction and letting the
core run, or by asking the hardware to perform a single step. The former requires the debugger to
have much more knowledge of the hardware than the latter, so the latter is preferred.
Using the hardware single step feature is almost the same as regular running. The debugger just
sets step in dcsr before letting the core run. The core behaves exactly as in the running case, except
that interrupts are left off and it only fetches and executes a single instruction before re-entering
Debug Mode.

Handling Exceptions:
Generally the debugger can avoid exceptions by being careful with the programs it writes. Some-
times they are unavoidable though, eg. if the user asks to access memory or a CSR that is not
implemented. A typical debugger will not know enough about the platform to know what’s going
to happen, and must attempt the access to determine the outcome.
When an exception occurs while executing the Program Buffer, cmderr becomes set. The debugger
can check this field to see whether a program encountered an exception. If there was an exception,
it’s left to the debugger to know what must have caused it.

*/


module dm_jtag #(
    parameter DMI_ADDR_BITS = 6,
    parameter DMI_DATA_BITS = 32,
    parameter DMI_OP_BITS = 2)
    (
        input wire                      clk_i,
        input wire                      nrst_i,

        // request from dtm and the ack to it
        input wire                      dtm_req_valid_i,
        input wire[DTM_REQ_BITS-1:0]    dtm_req_data_i,
        output wire                     dm_req_ack_o,

        // response to dtm and the ack from it
        output wire                     dm_resp_valid_o,
        output wire[DM_RESP_BITS-1:0]   dm_resp_data_o,
        input wire                      dtm_resp_ack_i,  // this signal not used at the moment, the flow control was done on the dtm side

        // access the risc-v gpr
        output wire                     dm_reg_req_o,
        output wire[4:0]                dm_reg_addr_o,
        output wire                     dm_reg_we_o,
        output wire[31:0]               dm_reg_wdata_o,
        input  wire[31:0]               dm_reg_rdata_i,

        // access the risc-v csr
        output wire                     dm_csr_req_o,
        output wire[31:0]               dm_csr_addr_o,
        output wire                     dm_csr_we_o,
        output wire[31:0]               dm_csr_wdata_o,
        input  wire[31:0]               dm_csr_rdata_i,

        // access the memory
        output wire                     dm_mem_ce_o,
        output wire[3:0]                dm_mem_sel_o,
        output wire[31:0]               dm_mem_addr_o,
        output wire                     dm_mem_we_o,
        output wire[31:0]               dm_mem_wdata_o,
        input wire                      dm_mem_rvalid_i,
        input wire[31:0]                dm_mem_rdata_i,

        // cpu halt and reset
        output                          dm_halt_req_o,   //halt the core
        output                          dm_reset_req_o   //reset the core
    );

    localparam DM_RESP_BITS = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;
    localparam DTM_REQ_BITS = DMI_ADDR_BITS + DMI_DATA_BITS + DMI_OP_BITS;
    localparam SHIFT_REG_BITS = DTM_REQ_BITS;

    // DM registers' address
    localparam DMCONTROL  = 6'h10;    //dmcontrol
    localparam DMSTATUS   = 6'h11;    //dmstatus
    localparam HARTINFO   = 6'h12;
    localparam ABSTRACTCS = 6'h16;    //abstract, cs
    localparam DATA0      = 6'h04;
    localparam SBCS       = 6'h38;    //system bus control status
    localparam SBADDRESS0 = 6'h39;    //system bus address
    localparam SBDATA0    = 6'h3C;    //system bus data0
    localparam COMMAND    = 6'h17;    //abstract command

    /* ================================================== dmstatu (readonly) ===========================================================
        dmstatus register reports status for the overall debug module as well as the currently selected harts, as defined in hasel.
        dmstatus = {0[31:25], ndmresetpending, stickyunavail, impebreak, 0[21;20], allhavereset[19], anyhavereset[18],
                    allresumeack[17], anyresumeack[16], allnonexistent[15], anynonexistent[14], allunavail[13],
                    anyunavail[12], allrunning[11], anyrunning[10], allhalted[9], anyhalted[8], authenticated[7],
                    authbusy[6] 0[5] cfgstrvalid[4] version[3:0]}
        allresumeack: This field is 1 when all currently selected harts have acknowledged the previous resumereq.
    ====================================================================================================================================*/
    reg dmstatus_allresumeack;
    reg dmstatus_anyresumeack;

    wire dmstatus_allnonexistent = 1'b0;
    wire dmstatus_anynonexistent = 1'b0;
    wire dmstatus_allunavail = 1'b0;
    wire dmstatus_anyunavail = 1'b0;

    reg dmstatus_allrunning;
    reg dmstatus_anyrunning;
    reg dmstatus_allhalted;
    reg dmstatus_anyhalted;

    //On components that don’t implement authentication, this bit must be preset as 1
    wire dmstatus_authenticated = 1'b1;
    wire dmstatus_authbusy = 0;

    // When cfgstrvalid is set, reading (cfgstraddr0 register returns bits 31:0 of the configuration string address.
    wire dmstatus_cfgstrvalid = 0;

    // the Debug Module conforms to version 0.13 of this specification.
    wire[3:0] dmstatus_version = 2;
    wire [31:0] dmstatus = {14'b0, dmstatus_allresumeack,  dmstatus_anyresumeack, dmstatus_allnonexistent, dmstatus_anynonexistent,
                            dmstatus_allunavail, dmstatus_anyunavail, dmstatus_allrunning, dmstatus_anyrunning, dmstatus_allhalted,
                            dmstatus_anyhalted, dmstatus_authenticated, dmstatus_authbusy, 1'b0, dmstatus_cfgstrvalid, dmstatus_version};

    /* ====================================================== dmcontrol ===================================================================
        dmcontrol register controls the overall debug module as well as the currently selected harts, as defined in hasel.
        dmcontrol = {haltreq[31], resumereq[30], hartreset[29], 0[28:27], hasel[26], hartsel[25:16], 0[15:2], ndmreset[1], dmactive[0]}
        haltreq: Halt request signal for all currently selected harts. When set to 1, each selected hart will halt.
        resumereq: Resume request signal for all currently selected harts.
        hartreset: This optional bit controls reset to all the currently selected harts.
        hasel:Selects the definition of currently selected harts.
            0: There is a single currently selected hart, that selected by hartsel.
            1: There may be multiple currently selected harts that selected by hartsel, plus those selected by the hart array mask register.
        hartsel: The DM-specific index of the hart to select.
        ndmreset: This bit controls the reset signal from the DM to the rest of the system. To perform a system reset the debugger writes 1,
                  and then writes 0 to deassert the reset. This bit must not reset the Debug Module registers.
        dmactive: This bit serves as a reset signal for the Debug Module itself.

        The debugger can select a hart by writing its index to hartsel. Hart indexes start at 0 and are continuous until the final index.
    ====================================================================================================================================*/
    reg [31:0] dmcontrol;

    /* ===================================================== hartinfo (readonly)=========================================================
       hartinfo register gives information about the hart currently selected by hartsel.
       {0 nscratch 0 dataaccess datasize dataaddr}
       nscratch: Number of dscratch registers available for the debugger to use during program buffer execution
       dataaccess: 0: The data registers are shadowed in the hart by CSR registers.
       datasize: If dataaccess is 0: Number of CSR registers dedicated to shadowing the data registers.
       dataaddr: If dataaccess is 0: The number of the first CSR dedicated to shadowing the data registers.
    ====================================================================================================================================*/
    wire[3:0] nscratch = 4'b0;
    wire dataaccess = 0;
    wire[3:0] datasize = 4'b0;   //1'b1, DATA0 only
    wire[11:0] dataaddr = 12'b0; //{6'b0, DATA0};
    wire[31:0] hartinfo = {8'b0, nscratch, 3'b0, dataaccess, datasize, dataaddr};

    /* ====================================================== abstractcs ===================================================================
        Abstract Control and Status
        {0[31:29], progsize[28:24], 0[23:13], busy[12], 0[11], cmderr[10:8], 0[7:5], datacount[4:0]}
        progsize: Size of the Program Buffer, in 32-bit words. Valid sizes are 0 - 16.
        busy: 1: An abstract command is currently being executed
        cmderr: Gets set if an abstract command fails. The bits in this field remain set until they are cleared by writing 1 to them.
               No abstract command is started until the value is reset to 0.
        datacount: Number of data registers that are implemented as part of the abstract command interface.
    ====================================================================================================================================*/
    wire[4:0] abstractcs_progsize = 5'b0;
    reg abstractcs_busy;
    reg[2:0] abstractcs_cmderr;
    wire[4:0] abstractcs_datacount = 5'b1;
    wire [31:0] abstractcs = {3'b0, abstractcs_progsize, 11'b0, abstractcs_busy, 1'b0, abstractcs_cmderr, 3'b0, abstractcs_datacount};

    /* ====================================================== dmstatu===================================================================
       Basic read/write registers that may be read or changed by abstract commands.
       data0 = {data[31:0]}
    ====================================================================================================================================*/
    reg [31:0] data0;


    /* ====================================================== sbcs =====================================================================
        sbcs: System Bus Access Control and Status
        sbcs = { 0[31:21], sbsingleread[20], sbaccess[19:17], sbautoincrement[16], sbautoread[15], sberror[14:12]
                sbasize[11:5], sbaccess128[4], sbaccess64[3], sbaccess32[2], sbaccess16[1], sbaccess8[0] }
    ====================================================================================================================================*/
    reg [31:0] sbcs;

    //  sbcs_sbsingleread: When a 1 is written here, triggers a read at the address in sbaddress using the access size set by sbcs_sbaccess.
    wire sbcs_sbsingleread = sbcs[20];

    //  sbcs_sbaccess: Select the access size to use for system
    wire[2:0] sbcs_sbaccess = sbcs[19:17];

    // sbautoincrement: When 1, the internal address value
    wire sbcs_sbautoincrement = sbcs[16];

    // sbautoread: When 1, every read from sbdata0 automatically triggers a system bus read at the new address
    wire sbcs_sbautoread = sbcs[15];

    //Width of system bus addresses in bits. (0 indicates there is no bus access support.)
    reg[6:0] sbcs_sbasize;

    /* ====================================================== sbaddress0 ===============================================================
       System Bus Address 31:0
       sbaddress0 = { address[31:0] }
       If sbasize is 0, then this register is not present
    ====================================================================================================================================*/
    reg [31:0] sbaddress0;
    wire[31:0] sbaddress0_next = sbaddress0 + 4;

    /* ====================================================== sbdata0 ===================================================================
        System Bus Data (sbdata0, at 0x3c) = {data[31:0]}
        Writes to this register:
            1. If the bus master is busy then accesses set sberror, return error, and don’t do anything else.
            2. Update internal data.
            3. Start a bus write of the internal data to the internal address.
            4. If sbautoincrement is set, increment the internal address.

        Reads from this register:
            1. If bits 31:0 of the internal data register haven’t been updated since the last time this register
               was read, then set sberror, return error, and don’t do anything else.
            2. “Return” the data.
            3. If sbautoincrement is set, increment the internal address.
            4. If sbautoread is set, start another system bus read.
   ====================================================================================================================================*/
    reg [31:0] sbdata0;



    /* ================================================ command (write only) ============================================================
    command {cmdtype[31:24], 0[23], size[22:20], 0[19], postexec[18], transfer[17], write[16], regno[15:0]}
        cmdtype: This is 0 to indicate Access Register Command.
        size:   2: Access the lowest 32 bits of the register.
                3: Access the lowest 64 bits of the register.
                4: Access the lowest 128 bits of the register.
        postexec: When 1, execute the program in the Program Buffer exactly once after performing the transfer, if any.
        transfer: 0: Don’t do the operation specified by write.
                1: Do the operation specified by write.
        write: When transfer is set: 0: Copy data from the specified register into arg0 portion of data.
                                     1: Copy data from arg0 portion of data into the specified register.
        regno: Number of the register to access

    This command gives the debugger access to CPU registers and program buffer. It performs the following sequence of operations:
        1. Copy data from the register specified by regno into the arg0 region of data, if write is clear and transfer is set.
        2. Copy data from the arg0 region of data into the register specified by regno, if write is set and transfer is set.
        3. Execute the Program Buffer, if postexec is set.

    Writes to this register cause the corresponding abstract command to be executed.
    Writing while an abstract command is executing causes cmderr to be set.

    Which data registers are used for the arguments is described in the below Table
    ----------------------------------------------------------------------------------
    XLEN   | arg0/return value  | arg1           |arg2
    ----------------------------------------------------------------------------------
    32     | data0              | data1          | data2
    ----------------------------------------------------------------------------------
    64     | data0, data1       | data2, data3   | data4, data5
    ----------------------------------------------------------------------------------
    128     | data0 - data3      | data4 - data7  | data8 - data11
    ----------------------------------------------------------------------------------

    the abstract register numbers defined in the table
    ----------------------------------------------------------------------------------
    0x0000 - 0x0fff  | csr
    ----------------------------------------------------------------------------------
    0x1000 - 0x101f  | GPRs
    ----------------------------------------------------------------------------------
    0x1020 - 0x103f  | floating point registers
    ----------------------------------------------------------------------------------
    0xc000 - 0xffff  | Reserved for non-standard extensions and internal use
    ----------------------------------------------------------------------------------

    The DM supports a set of abstract commands, most of which are optional.
    Debuggers can only determine which abstract commands are supported by a given hart in a given state
    by attempting them and then looking at cmderr in abstractcs to see if they were successful.

    Debuggers execute abstract commands by writing them to command. Debuggers can determine
    whether an abstract command is complete by reading busy in abstractcs. If the command takes
    arguments, the debugger must write them to the data registers before writing to command. If a
    command returns results, the Debug Module must ensure they are placed in the data registers
    before busy is cleared.

    =================================================================================================================================*/
    reg [31:0] command;


    // access GPRs
    reg       dm_reg_req;
    reg[4:0]  dm_reg_addr;
    reg       dm_reg_we;
    reg[31:0] dm_reg_wdata;

    assign dm_reg_req_o = dm_reg_req;
    assign dm_reg_addr_o = dm_reg_addr;
    assign dm_reg_we_o = dm_reg_we;
    assign dm_reg_wdata_o = dm_reg_wdata;

    // access csr
    reg        dm_csr_req;
    reg[31:0]  dm_csr_addr;
    reg        dm_csr_we;
    reg[31:0]  dm_csr_wdata;

    assign dm_csr_req_o = dm_csr_req;
    assign dm_csr_addr_o = dm_csr_addr;
    assign dm_csr_we_o = dm_csr_we;
    assign dm_csr_wdata_o = dm_csr_wdata;

    // access memory
    reg       dm_mem_ce;
    reg[3:0]  dm_mem_sel;
    reg[31:0] dm_mem_addr;
    reg       dm_mem_we;
    reg[31:0] dm_mem_wdata;

    assign dm_mem_ce_o = dm_mem_ce;
    assign dm_mem_sel_o  = dm_mem_sel;
    assign dm_mem_addr_o = dm_mem_addr;
    assign dm_mem_we_o = dm_mem_we;
    assign dm_mem_wdata_o = dm_mem_wdata;

    // hart control
    reg dm_halt_req;
    reg dm_reset_req;

    assign dm_halt_req_o = dm_halt_req;
    assign dm_reset_req_o = dm_reset_req;

    localparam  DTM_OP_NOP   = 2'b00;
    localparam  DTM_OP_READ  = 2'b01;
    localparam  DTM_OP_WRITE = 2'b10;

    wire[DMI_OP_BITS-1:0]    op      = dtm_req_data_i[DMI_OP_BITS-1:0];
    wire[DMI_DATA_BITS-1:0]  data    = dtm_req_data_i[DMI_DATA_BITS+DMI_OP_BITS-1:DMI_OP_BITS];
    wire[DMI_ADDR_BITS-1:0]  address = dtm_req_data_i[DTM_REQ_BITS-1:DMI_DATA_BITS+DMI_OP_BITS];

    assign dm_req_ack_o = dtm_req_valid_i;

    //decode dmcontrol
    wire dmcontrol_haltreq = data[31];
    wire dmcontrol_resumereq = data[30];
    wire dmcontrol_hartreset = data[29];
    wire dmcontrol_hasel = data[26];
    wire[9:0] dmcontrol_hartsel = data[25:16];
    wire dmcontrol_ndmreset = data[1];
    wire dmcontrol_dmactive = data[0];

    //decode command
    wire[7:0] command_cmdtype = data[31:24];
    wire[2:0] command_size = data[22:20];
    wire command_postexec = data[18];
    wire command_transfer = data[17];
    wire command_write = data[16];
    wire[15:0] command_regno = data[15:0];

    /*============= transfer local response to dtm =============*/
    reg[31:0]              read_data;                     // the data to transfer to dtm
    assign dm_resp_data_o = {address, read_data, 2'b00};  // success response

    reg                    dm_resp_valid;
    assign dm_resp_valid_o = dm_resp_valid;

    always @ (posedge clk_i or negedge nrst_i) begin
        if (!nrst_i) begin
            dm_reg_req <= 1'b0;
            dm_reg_addr <= 5'h0;
            dm_reg_we <= 1'b0;
            dm_reg_wdata <= 32'h0;

            dm_mem_addr <= 32'h0;
            dm_mem_we <= 1'b0;
            dm_mem_wdata <= 32'h0;

            dm_halt_req <= 1'b0;
            dm_reset_req <= 1'b0;

            // dmstatus;
            dmstatus_allresumeack <= 1'b1;
            dmstatus_anyresumeack <= 1'b1;

            dmstatus_allrunning <= 1'b1;
            dmstatus_anyrunning <= 1'b1;
            dmstatus_allhalted <= 1'b0;
            dmstatus_anyhalted <= 1'b0;

            dmcontrol <= 32'h0;

            // System Bus Access Control and Status: sbaccess32 =1, sbasize=32,
            sbcs <= 32'h204;

            // abstractcs <= 32'h1000003;
            abstractcs_busy <= 1'b0;
            abstractcs_cmderr <= 3'b0;

            sbaddress0 <= 32'h0;
            sbdata0 <= 32'h0;
            command <= 32'h0;
            data0 <= 32'h0;

            dm_reg_req <= 1'b0;
            read_data <= 32'h0;
            dm_resp_valid <= 1'b0;

        end else begin
            if (dtm_req_valid_i) begin
                dm_resp_valid <= 1'b1;
                case (op)
                    /*================================================= read operation ============================*/
                    DTM_OP_READ: begin
                        case (address)
                            DMSTATUS: begin
                                read_data <= dmstatus;
                                // $display("dm read dmstatus, return 0x%h", dmstatus);
                            end

                            DMCONTROL: begin
                                read_data <= dmcontrol;
                                $display("dm read dmcontrol, return 0x%h", dmcontrol);
                            end

                            HARTINFO: begin
                                read_data <= hartinfo;
                                $display("dm read hartinfo, return 0x%h", hartinfo);
                            end

                            SBCS: begin
                                read_data <= sbcs;
                                $display("dm read sbcs, return 0x%h", sbcs);
                            end

                            ABSTRACTCS: begin
                                read_data <= abstractcs;
                                $display("dm read abstractcs, return 0x%h", abstractcs);
                            end

                            DATA0: begin   // read the registers
                                if (dm_reg_req == 1'b1) begin
                                    read_data <= dm_reg_rdata_i;
                                    $display("dm read GPRs(%d), return 0x%h", dm_reg_addr, dm_reg_rdata_i);
                                    dm_reg_req <= 1'b0;
                                end else if (dm_csr_req == 1'b1) begin
                                    read_data <= dm_csr_rdata_i;
                                    $display("dm read csr(%x), return 0x%h", dm_csr_addr, dm_csr_rdata_i);
                                    dm_csr_req <= 1'b0;
                                end
                            end

                            SBDATA0: begin  // read memory
                                $display("dm read memory (0x%h), return 0x%h", dm_mem_addr, dm_mem_rdata_i);
                                read_data <= dm_mem_rdata_i;

                                if (sbcs_sbautoincrement == 1'b1) begin
                                    sbaddress0 <= sbaddress0_next;
                                    dm_mem_addr <= sbaddress0_next;
                                    $display("dm read memory, address increment by 4 automatically");
                                end

                                if (sbcs_sbautoread == 1'b1) begin
                                    dm_mem_ce <= 1'b1;
                                    dm_mem_sel <= 4'b1111;
                                    sbaddress0 <= sbaddress0_next;
                                    dm_mem_addr <= sbaddress0_next;
                                    dm_mem_we <= 1'b0;
                                    $display("dm read memory automatically, address increment by 4");
                                end
                            end

                            default: begin
                                read_data <= {(DMI_DATA_BITS){1'b0}};
                            end
                        endcase
                    end

                    /*================================================= write operation ============================*/
                    DTM_OP_WRITE: begin
                        read_data <= {(DMI_DATA_BITS){1'b0}};
                        case (address)
                            DMCONTROL: begin
                                // save to dmcontrol
                                dmcontrol <= (data & 32'hf000ffff);  // // we have only one hart, mask all other bits, hasel =0,
                                $display("dm write dmcontrol, data=0x%h, dmcontrol =0x%h", data, (data & 32'hf000ffff));
                                if (dmcontrol_dmactive == 1'b0) begin
                                    // dmactive: This bit serves as a reset signal for the Debug Module itself.
                                    // 0: The module’s state, including authentication mechanism, takes its reset values
                                    // 1: The module functions normally.
                                    $display("dm write dmcontrol, reset the dm");

                                    // dmstatus: not halted, all running
                                    dmstatus_allresumeack <= 1'b1;
                                    dmstatus_anyresumeack <= 1'b1;

                                    dmstatus_allrunning <= 1'b1;
                                    dmstatus_anyrunning <= 1'b1;
                                    dmstatus_allhalted <= 1'b0;
                                    dmstatus_anyhalted <= 1'b0;

                                    //sbcs
                                    sbcs <= 32'h204;  // 32'h20040404;

                                    //abstractcs;
                                    abstractcs_busy <= 1'b0;
                                    abstractcs_cmderr <= 3'b0;

                                    dm_halt_req <= 1'b0;
                                    dm_reset_req <= 1'b0;
                                // DM is active
                                end else begin
                                    // haltreq
                                    if (dmcontrol_haltreq == 1'b1) begin
                                        // To halt a hart, the debugger sets hartsel and haltreq. Then it waits for allhalted to become 1.
                                        dm_halt_req <= 1'b1;
                                        // clear ALL_RUNNING, ANY_RUNNING and set ALL_HALTED in dmstatus
                                        dmstatus_allrunning <= 1'b0;
                                        dmstatus_anyrunning <= 1'b0;
                                        dmstatus_allhalted <= 1'b1;
                                        dmstatus_anyhalted <= 1'b1;
                                        $display("dm write dmcontrol, halt request for the hart, hart_index=0x%h", dmcontrol_hartsel);
                                    // resumereq
                                    end else if (dm_halt_req == 1'b1 && dmcontrol_resumereq == 1'b1) begin
                                        dm_halt_req <= 1'b0;
                                        // set ALL_RUNNING, ANY_RUNNING and clear ALL_HALTED in dmstatus
                                        dmstatus_allrunning <= 1'b1;
                                        dmstatus_anyrunning <= 1'b1;
                                        dmstatus_allhalted <= 1'b0;
                                        dmstatus_anyhalted <= 1'b0;
                                        $display("dm write dmcontrol, resume request for the hart, hart_index=0x%h", dmcontrol_hartsel);
                                    end // if (dmcontrol_resumereq == 1'b1) begin

                                    // hartreset: This optional bit controls reset to all the currently selected harts. To perform a reset the debugger
                                    // writes 1, and then writes 0 to deassert the reset signal.
                                    if (dmcontrol_hartreset == 1'b1) begin
                                        dm_reset_req <= 1'b1;
                                        $display("dm write dmcontrol, assert the hartreset the hart, hart_index=0x%h", dmcontrol_hartsel);
                                    end else begin
                                        dm_reset_req <= 1'b0;
                                        $display("dm write dmcontrol, deassert the hartreset for the hart, hart_index=0x%h", dmcontrol_hartsel);
                                    end

                                    // ndmreset: This bit controls the reset signal from the DM to the rest of the system. To perform a system
                                    // reset the debugger writes 1, and then writes 0 to deassert the reset.
                                    // This bit must not reset the Debug Module registers.
                                    if (dmcontrol_ndmreset == 1'b1) begin
                                        dm_reset_req <= 1'b1;
                                        $display("dm write dmcontrol, assert the ndmreset the hart, hart_index=0x%h", dmcontrol_hartsel);
                                    end else begin
                                        dm_reset_req <= 1'b0;
                                        $display("dm write dmcontrol, deassert the ndmreset for the hart, hart_index=0x%h", dmcontrol_hartsel);
                                    end
                                end // if (dmcontrol_dmactive == 1'b0) begin
                            end  // DMCONTROL: begin

                            COMMAND: begin
                                if (command_cmdtype == 8'h0) begin  // cmdtype == 0: indicate access register command
                                    if (command_size > 3'h2) begin // aarsize: 2 stands for low 32 bit, 3 for 64 bits, 4 for 128 bits
                                        $display("dm write command, read register, unsupported command_size=%d, data=0x%h", command_size, data);
                                        abstractcs_cmderr <= 3'b10; // 2 (not supported): The requested command is not supported.
                                    end else begin
                                        if (command_postexec == 1'b0) begin  // postexec, not support at the moment
                                            abstractcs_cmderr <= 3'b0;  // accept
                                            if (command_transfer == 1'b1) begin
                                                if (command_write == 1'b0) begin // read
                                                    /*
                                                    == read register ==
                                                    Read s0 using abstract command:
                                                    -------------------------------------------------------------------------------
                                                    Op    | Address | Value                       |    Comment                     |
                                                    -------------------------------------------------------------------------------
                                                    Write | command | size = 2, transfer, 0x1008  |   Read s0                      |
                                                    -------------------------------------------------------------------------------
                                                    Read  | data0   | -                           |   Returns value that was in s0 |
                                                    --------------------------------------------------------------------------------
                                                    */
                                                    if (command_regno > 16'h103f) begin  // reserved
                                                        $display("dm read the reserved register(0x%h)", command_regno);
                                                    end else if(command_regno > 16'h101f) begin // floating point
                                                        $display("dm read the float point register(0x%h)", command_regno);
                                                    end else if(command_regno > 16'h0fff) begin // gpr
                                                        $display("dm read the gpr (0x%h)", command_regno - 16'h1000);
                                                        dm_reg_req <= 1'b1;
                                                        /* verilator lint_off WIDTH */
                                                        dm_reg_addr <= command_regno - 16'h1000;
                                                        /* verilator lint_on WIDTH */
                                                    end else begin //access the csr module in the core
                                                        $display("dm read the CSR (0x%h)", command_regno);
                                                        dm_csr_req <= 1'b1;
                                                        dm_csr_addr <= {16'b0, command_regno};
                                                    end
                                                    // If the failure is that the requested register does not exist in the hart,
                                                    // cmderr must be set to 3 (exception).
                                                end else begin // write
                                                    /*
                                                    == write register ==
                                                    Write mstatus using abstract command:
                                                    ---------------------------------------------------------------------
                                                    Op    | Address | Value                            |    Comment     |
                                                    ---------------------------------------------------------------------
                                                    Write | data0   | new value                        |   Read s0      |
                                                    ---------------------------------------------------------------------
                                                    Write | command | size = 2, transfer, write, 0x300 |   Write mstatus|
                                                    ---------------------------------------------------------------------
                                                    */
                                                    if (command_regno > 16'h103f) begin  // reserved
                                                        $display("dm write to the reserved register(0x%h)", command_regno);
                                                    end else if(command_regno > 16'h101f) begin // floating point
                                                        $display("dm write to the float point register(0x%h)", command_regno);
                                                    end else if(command_regno > 16'h0fff) begin // gpr
                                                        $display("dm write to the GPRs(%d) with value(0x%h)", (command_regno - 16'h1000), data0);
                                                        dm_reg_req <= 1'b1;
                                                        /* verilator lint_off WIDTH */
                                                        dm_reg_addr <= command_regno - 16'h1000;
                                                        /* verilator lint_on WIDTH */
                                                        dm_reg_we <= 1'b1;
                                                        dm_reg_wdata <= data0;
                                                    end else begin //csr
                                                        $display("dm write to the csr(%d) with value(0x%h)", command_regno, data0);
                                                        dm_csr_req <= 1'b1;
                                                        dm_csr_addr <= {16'b0, command_regno};
                                                        dm_csr_we <= 1'b1;
                                                        dm_csr_wdata <= data0;
                                                    end
                                                end // if (command_write == 1'b0) begin // read
                                            end else begin
                                                $display("dm write command, access register, transfer is not set, data=0x%h", data);
                                            end  // if (comand_transfer == 1'b1) begin
                                        end else begin // if (command_postexec == 1'b0) begin  // postexec, not support at the moment
                                            $display("dm write command, access register,postexec not support, data=0x%h", data);
                                            abstractcs_cmderr <= 3'b10; // 2 (not supported): The requested command is not supported.
                                        end // if (command_postexec == 1'b0) begin  // postexec, not support at the moment
                                    end // if (command_size > 3'h2) begin
                                /* ================================ access the momory , to support later ================================================*/
                                /*
                                end else if (command_cmdtype == 8'h2) // Access Memory Command in v1.0
                                    if (command_size > 3'h2) begin // aarsize: 2 stands for low 32 bit, 3 for 64 bits, 4 for 128 bits
                                        $display("dm write command, Access memory, unsupported command_size=%d, data=0x%h", command_size, data);
                                        abstractcs_cmderr <= 3'b10; // 2 (not supported): The requested command is not supported.
                                    end else begin
                                        if (command_postexec == 1'b0) begin  // postexec, not support at the moment
                                            abstractcs_cmderr <= 3'b0;  // accept
                                            if (command_transfer == 1'b1) begin
                                                if (command_write == 1'b0) begin // read memory
                                                    // Copy data from the memory location specified in arg1 into the arg0 portion of data

                                                end else begin // write
                                                    // Copy data from the arg0 portion of data into the memory location specified in arg1, if write is set.

                                                end // if (command_write == 1'b0) begin // read

                                                // If aampostincrement is set, increment arg1.
                                            end else begin
                                                $display("dm write command, access memory, transfer is not set, data=0x%h", data);
                                            end  // if (comand_transfer == 1'b1) begin
                                        end else begin // if (command_postexec == 1'b0) begin  // postexec, not support at the moment
                                            $display("dm write command, access memory,postexec not support, data=0x%h", data);
                                            abstractcs_cmderr <= 3'b10; // 2 (not supported): The requested command is not supported.
                                        end // if (command_postexec == 1'b0) begin  // postexec, not support at the moment
                                    end // if (command_size > 3'h2) begin
                                */
                                end else begin // cmdtype == 0: indicate access register command
                                    $display("dm write command, unknown cmdtype(%d), data=0x%h", command_cmdtype, data);
                                    abstractcs_cmderr <= 3'b10; // 2 (not supported): The requested command is not supported.
                                end //cmdtype == 0, access the registers
                            end

                            DATA0: begin
                                $display("dm write DATA0, data=0x%h", data);
                                data0 <= data;
                            end

                            SBCS: begin
                                $display("dm write SBCS, data=0x%h", data);
                                /*
                                == read memory
                                Read a word from memory using system bus access:
                                -------------------------------------------------------------------------------
                                Op    | Address   | Value                      | Comment                      |
                                -------------------------------------------------------------------------------
                                Write | sbaddress0| address                    | the memory address to read   |
                                -------------------------------------------------------------------------------
                                Write | sbcs      | sbaccess = 2, sbsingleread | Perform a read               |
                                -------------------------------------------------------------------------------
                                Read  | sbdata0   |     -                      | Value read from memory       |
                                -------------------------------------------------------------------------------
                                */
                                sbcs <= data;
                                // When set, triggers a read
                                if(data[20] == 1'b1) begin
                                    $display("dm init a memory read operation, sbaccess=0x%h, sbautoincrement=0x%h, sbautoread=0x%h, addr=0x%h", data[19:17], data[16],  data[15], sbaddress0);
                                    dm_mem_ce <= 1'b1;
                                    dm_mem_sel <= 4'b1111;
                                    dm_mem_addr <= sbaddress0;  // in the test, sometimes, the address is fall behind the sbcs
                                    dm_mem_we <= 1'b0;
                                end
                            end

                            SBADDRESS0: begin
                                $display("dm write SBADDRESS0, data=0x%h", data);
                                sbaddress0 <= data;
                                dm_mem_addr <= data;  // in the test, sometimes, the address is fall behind the sbcs
                            end

                            SBDATA0: begin
                                $display("dm write SBDATA0 to init a memory write operation, address=0x%h, data=0x%h", sbaddress0, data);
                                /*
                                == write memory
                                Write a word to memory using system bus access:
                                ------------------------------------------------------------
                                Op    | Address   | Value     | Comment                     |
                                -------------------------------------------------------------
                                Write |sbaddress0 | address   | the memory address to write |
                                -------------------------------------------------------------
                                Write | sbdata0   | value     | Perform a write             |
                                -------------------------------------------------------------
                                */
                                sbdata0 <= data;
                                dm_mem_ce <= 1'b1;
                                dm_mem_sel <= 4'b1111;
                                dm_mem_addr <= sbaddress0;
                                dm_mem_we <= 1'b1;
                                dm_mem_wdata <= data;
                                if (sbcs_sbautoincrement == 1'b1) begin
                                    sbaddress0 <= sbaddress0_next;
                                    $display("dm write memory, address increment by 4 automatically");
                                end
                            end

                            default: begin

                            end
                        endcase
                    end

                    DTM_OP_NOP: begin
                        read_data <= {(DMI_DATA_BITS){1'b0}};
                    end

                    default: begin

                    end
                endcase
            end else begin
                dm_resp_valid <= 1'b0;
                dm_mem_we <= 1'b0;
                dm_reg_we <= 1'b0;
                dm_reset_req <= 1'b0;
            end
        end
    end

endmodule

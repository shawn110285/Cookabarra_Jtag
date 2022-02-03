
/*-------------------------------------------------------------------------
// Module:  simple_system
// File:    simple_system.v
// Author:  shawn Liu
// E-mail:  shawn110285@gmail.com
// Description: a simple soc based on the CPU core
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


module simple_system(

    input  wire          clk_i,
    input  wire          n_rst_i,

    // uart
	input wire           uart_rxd,
	output wire          uart_txd,
    // gpio
	output wire[3:0]     led,
	output wire          beep,

	input  wire[3:0]     key,
	input  wire          touch_key,

    input  wire          jtag_TCK,     // JTAG TCK
    input  wire          jtag_TMS,     // JTAG TMS
    input  wire          jtag_TDI,     // JTAG TDI
    output wire          jtag_TDO      // JTAG TDO
);

    /* 2 division
    reg clk_div2_r;
    always @(posedge clk_i or negedge n_rst_i) begin
        if( !n_rst_i) begin
            clk_div2_r <= 1'b0;
        end else begin
            clk_div2_r <= ~clk_div2_r;
        end
    end
    wire clk_div2 = clk_div2_r;

    // 4 division
    reg clk_div4_r;
    always @(posedge clk_div2 or negedge n_rst_i) begin
        if( !n_rst_i) begin
            clk_div4_r <= 1'b0;
        end else begin
            clk_div4_r <= ~clk_div4_r;
        end
    end
    */

    wire sys_clk_i = clk_i;  //clk_div4_r;

    //jtag access the gpr
    wire         jtag_reg_req_o;
    wire[4:0]    jtag_reg_addr_o;
    wire         jtag_reg_we_o;
    wire[31:0]   jtag_reg_wdata_o;
    wire[31:0]   jtag_reg_rdata_i;

    //jtag access the csr
    wire         jtag_csr_req_o;
    wire[31:0]   jtag_csr_addr_o;
    wire         jtag_csr_we_o;
    wire[31:0]   jtag_csr_wdata_o;
    wire[31:0]   jtag_csr_rdata_i;

    //jtag access the memory
    wire         jtag_mem_ce_o;
    wire[3:0]    jtag_mem_sel_o;
    wire[31:0]   jtag_mem_addr_o;
    wire         jtag_mem_we_o;
    wire[31:0]   jtag_mem_wdata_o;
    wire         jtag_mem_rvalid_i;
    wire[31:0]   jtag_mem_rdata_i;

    wire         jtag_halt_req_o;
    wire         jtag_reset_req_o;

    jtag_top jtag_top0(
        .clk_i       (sys_clk_i),
        .nrst_i      (n_rst_i),

        .jtag_TCK    (jtag_TCK),
        .jtag_TMS    (jtag_TMS),
        .jtag_TDI    (jtag_TDI),
        .jtag_TDO    (jtag_TDO),

        .reg_req_o    (jtag_reg_req_o),
        .reg_addr_o   (jtag_reg_addr_o),
        .reg_we_o     (jtag_reg_we_o),
        .reg_wdata_o  (jtag_reg_wdata_o),
        .reg_rdata_i  (jtag_reg_rdata_i),

        .csr_req_o    (jtag_csr_req_o),     //access signal
        .csr_addr_o   (jtag_csr_addr_o),    // the reg address
        .csr_we_o     (jtag_csr_we_o),      // write enable
        .csr_wdata_o  (jtag_csr_wdata_o),   // the data to write
        .csr_rdata_i  (jtag_csr_rdata_i),   // the read result

        .mem_ce_o     (jtag_mem_ce_o),
        .mem_sel_o    (jtag_mem_sel_o),
        .mem_addr_o   (jtag_mem_addr_o),
        .mem_we_o     (jtag_mem_we_o),
        .mem_wdata_o  (jtag_mem_wdata_o),
        .mem_rvalid_i (jtag_mem_rvalid_i),
        .mem_rdata_i  (jtag_mem_rdata_i),

        .halt_req_o   (jtag_halt_req_o),
        .reset_req_o  (jtag_reset_req_o)
    );


    // master
    wire              m_req_i;
    wire[3:0]         m_sel_i;
    wire[31:0]        m_addr_i;
    wire              m_we_i;
    wire[31:0]        m_data_i;
    wire              m_rvalid_o;
    wire[31:0]        m_data_o;


    // slave 0 (rom)
    wire             s0_req_o;
    wire[3:0]        s0_sel_o;
    wire[31:0]       s0_addr_o;
    wire             s0_we_o;
    wire[31:0]       s0_data_o;
    wire             s0_rvalid_i;
    wire[31:0]       s0_data_i;


    // slave 1  (ram)
    wire             s1_req_o;
    wire[3:0]        s1_sel_o;
    wire[31:0]       s1_addr_o;
    wire             s1_we_o;
    wire[31:0]       s1_data_o;
    wire             s1_rvalid_i;
    wire[31:0]       s1_data_i;

    // slave 2 (timer)
    wire             s2_req_o;
    wire[3:0]        s2_sel_o;
    wire[31:0]       s2_addr_o;
    wire             s2_we_o;
    wire[31:0]       s2_data_o;
    wire             s2_rvalid_i;
    wire[31:0]       s2_data_i;

    // slave 3 (uart)
    wire             s3_req_o;
    wire[3:0]        s3_sel_o;
    wire[31:0]       s3_addr_o;
    wire             s3_we_o;
    wire[31:0]       s3_data_o;
    wire             s3_rvalid_i;
    wire[31:0]       s3_data_i;

    // slave 4 (gpio)
    wire             s4_req_o;
    wire[3:0]        s4_sel_o;
    wire[31:0]       s4_addr_o;
    wire             s4_we_o;
    wire[31:0]       s4_data_o;
    wire             s4_rvalid_i;
    wire[31:0]       s4_data_i;


    bus bus0 (
        .clk_i        (sys_clk_i),
        .n_rst_i      (n_rst_i),

        .m_req_i      (m_req_i),
        .m_sel_i      (m_sel_i),
        .m_addr_i     (m_addr_i),
        .m_we_i       (m_we_i),
        .m_data_i     (m_data_i),
        .m_rvalid_o   (m_rvalid_o),
        .m_data_o     (m_data_o),

        .s0_req_o     (s0_req_o),
        .s0_sel_o     (s0_sel_o),
        .s0_addr_o    (s0_addr_o),
        .s0_we_o      (s0_we_o),
        .s0_data_o    (s0_data_o),
        .s0_rvalid_i  (s0_rvalid_i),
        .s0_data_i    (s0_data_i),

        .s1_req_o     (s1_req_o),
        .s1_sel_o     (s1_sel_o),
        .s1_addr_o    (s1_addr_o),
        .s1_we_o      (s1_we_o),
        .s1_data_o    (s1_data_o),
        .s1_rvalid_i  (s1_rvalid_i),
        .s1_data_i    (s1_data_i),

        .s2_req_o     (s2_req_o),
        .s2_sel_o     (s2_sel_o),
        .s2_addr_o    (s2_addr_o),
        .s2_we_o      (s2_we_o),
        .s2_data_o    (s2_data_o),
        .s2_rvalid_i  (s2_rvalid_i),
        .s2_data_i    (s2_data_i),

        .s3_req_o     (s3_req_o),
        .s3_sel_o     (s3_sel_o),
        .s3_addr_o    (s3_addr_o),
        .s3_we_o      (s3_we_o),
        .s3_data_o    (s3_data_o),
        .s3_rvalid_i  (s3_rvalid_i),
        .s3_data_i    (s3_data_i),

        .s4_req_o     (s4_req_o),
        .s4_sel_o     (s4_sel_o),
        .s4_addr_o    (s4_addr_o),
        .s4_we_o      (s4_we_o),
        .s4_data_o    (s4_data_o),
        .s4_rvalid_i  (s4_rvalid_i),
        .s4_data_i    (s4_data_i)
    );


    //wires connected cpu fetch unit and rom (memory map: 32'h000000 ~ 32'h0FFFFF)
    wire               rom_ce;
    wire[`InstAddrBus] inst_addr;
    wire[`InstBus]     inst;

	rom rom0
    (
		.rom_clk_i(sys_clk_i),
		.rom_n_rst_i(n_rst_i),
		.rom_ce_i(rom_ce),
		.rom_addr_i(inst_addr),
		.rom_data_o(inst),

        // lsu access via the bus
		.clk_i(sys_clk_i),
        .n_rst_i(n_rst_i),
		.ce_i(s0_req_o),
		.sel_i(s0_sel_o),
		.addr_i(s0_addr_o),
		.we_i(s0_we_o),
		.data_i(s0_data_o),
        .rvalid_o(s0_rvalid_i),
		.data_o(s0_data_i)
	);


    // SRAM block for instruction and data storage
	ram ram0(
        // lsu access via the bus
		.clk_i(sys_clk_i),
        .n_rst_i(n_rst_i),
		.ce_i(s1_req_o),
		.sel_i(s1_sel_o),
		.addr_i(s1_addr_o),
		.we_i(s1_we_o),
		.data_i(s1_data_o),
        .rvalid_o(s1_rvalid_i),
		.data_o(s1_data_i),

        // jtag access
		.jtag_ce_i(jtag_mem_ce_o),
		.jtag_sel_i(jtag_mem_sel_o),
		.jtag_addr_i(jtag_mem_addr_o),
		.jtag_we_i(jtag_mem_we_o),
		.jtag_data_i(jtag_mem_wdata_o),
        .jtag_rvalid_o(jtag_mem_rvalid_i),
		.jtag_data_o(jtag_mem_rdata_i)
	);


    // wire connected timer and cpu irq_timer
    wire timer_irq_O;
    timer timer0 (
        .clk_i          (sys_clk_i),
        .rst_ni         (n_rst_i),
        .timer_req_i    (s2_req_o),
        .timer_sel_i    (s2_sel_o),
        .timer_addr_i   (s2_addr_o),
        .timer_we_i     (s2_we_o),
        .timer_wdata_i  (s2_data_o),
        .timer_rvalid_o (s2_rvalid_i),
        .timer_rdata_o  (s2_data_i),
        .timer_intr_o   (timer_irq_O)
    );

    uart uart0 (
	    .clk_i(sys_clk_i),
        .n_rst_i(n_rst_i),

	    .uart_ce_i(s3_req_o),
	    .uart_sel_i(s3_sel_o),
	    .uart_addr_i(s3_addr_o),
	    .uart_we_i(s3_we_o),
	    .uart_txdata_i(s3_data_o),
	    .uart_ack_o(s3_rvalid_i),
	    .uart_rxdata_o(s3_data_i),

		.uart_tx_pin_o(uart_txd),
		.uart_rx_pin_i(uart_rxd)
    );

	wire[31:0] gpio_in;
	wire[31:0] gpio_out;
	assign gpio_in = {27'b0, touch_key, key[3:0]};
	assign { beep, led[3:0] } =  gpio_out[4:0];
	gpio gpio0
	(
		.clk_i(sys_clk_i),
		.n_rst_i(n_rst_i),
		.gpio_ce_i(s4_req_o),
		.gpio_sel_i(s4_sel_o),

		.gpio_addr_i(s4_addr_o),
		.gpio_we_i(s4_we_o),
		.gpio_data_i(s4_data_o),
		.gpio_ack_o(s4_rvalid_i),
		.gpio_data_o(s4_data_i),

		.gpio_pin_i(gpio_in),
		.gpio_pin_o(gpio_out)
    );

    core_top core_top0(
		.sys_clk_i         (sys_clk_i),
		.sys_nrst_i        (n_rst_i),

        // access from ifu
		.rom_ce_o          (rom_ce),
		.rom_addr_o        (inst_addr),
		.rom_data_i        (inst),

        // access from lsu
		.ram_ce_o          (m_req_i),
		.ram_sel_o         (m_sel_i),
		.ram_addr_o        (m_addr_i),
		.ram_we_o          (m_we_i),
		.ram_data_o        (m_data_i),
        .ram_data_rvalid   (m_rvalid_o),
		.ram_data_i        (m_data_o),

		.irq_software_i    (1'b0),
		.irq_timer_i       (timer_irq_O),    //   timer_irq_O
		.irq_external_i    (1'b0),

        //jtag access the gpr
        .jtag_reg_req_i    (jtag_reg_req_o),
        .jtag_reg_addr_i   (jtag_reg_addr_o),
        .jtag_reg_we_i     (jtag_reg_we_o),
        .jtag_reg_wdata_i  (jtag_reg_wdata_o),
        .jtag_reg_rdata_o  (jtag_reg_rdata_i),

        // jtag access the csr
        .jtag_csr_req_i    (jtag_csr_req_o),   //access signal
        .jtag_csr_addr_i   (jtag_csr_addr_o),  // the reg address
        .jtag_csr_we_i     (jtag_csr_we_o),    // write enable
        .jtag_csr_wdata_i  (jtag_csr_wdata_o), // the data to write
        .jtag_csr_rdata_o  (jtag_csr_rdata_i),   // the read result

        .jtag_halt_req_i   (jtag_halt_req_o),
        .jtag_reset_req_i  (jtag_reset_req_o)
	);

endmodule

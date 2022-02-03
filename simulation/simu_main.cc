/* ============================================================================
  A Verilog main() program that calls a local serial port co-simulator.
  =============================================================================*/
using namespace std;

#include <verilated.h>
#include "verilated_vcd_c.h"
#include "Vsimple_system.h"       //auto created by the verilator from the rtl
// #include "Vsimple_system__Dpi.h"   //auto created by the verilator from the rtl that support dpi
#include "uartsim.h"
#include "remote_bitbang.h"


#define JTAP_SUPPORT        1

int main(int argc,  char ** argv)
{
    printf("Built with %s %s.\n", Verilated::productName(),
    Verilated::productVersion());
    printf("Recommended: Verilator 4.0 or later.\n");


    // call commandArgs first!
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);

    // Set debug level, 0 is off, 9 is highest presently used
    Verilated::debug(0);
    // Randomization reset policy
    Verilated::randReset(2);
    Verilated::mkdir("./log");

    // Instantiate our design
    Vsimple_system * ptTbTop = new Vsimple_system;

    // Tracing (vcd)
    VerilatedVcdC * m_trace = NULL;
    const char* flag_vcd = Verilated::commandArgsPlusMatch("vcd");
    if (flag_vcd && 0==strcmp(flag_vcd, "+vcd"))
    {
        Verilated::traceEverOn(true); // Verilator must compute traced signals
        m_trace = new VerilatedVcdC;
        ptTbTop->trace(m_trace, 1); // Trace 99 levels of hierarchy
        m_trace->open("./log/tb.vcd");
    }

    FILE * trace_fd = NULL;
    // If verilator was invoked with --trace argument,
    // and if at run time passed the +trace argument, turn on tracing
    const char* flag_trace = Verilated::commandArgsPlusMatch("trace");
    if (flag_trace && 0==strcmp(flag_trace, "+trace"))
    {
        trace_fd = fopen("./log/tb.trace", "w");
    }

    int m_cpu_tickcount = 0;
    //int m_jtag_tickcount = 0;

    //jtag
#ifdef JTAP_SUPPORT
    remote_bitbang_t * jtag = NULL;
    jtag = new remote_bitbang_t(9823);
#endif

    //uart
    UARTSIM  * uart = NULL;
    uart = new(UARTSIM);
    unsigned   baudclocks = 0x1B8;
    uart->setup(baudclocks);


    /*  Wipe memory to 0 */
    //printf("Wipe memory to 0 \n");
    //char * pucMemory = ptTbTop->x_axi_slave128.x_f_spsram_large

    // Note that if the DPI task or function accesses any register or net within the RTL,
    // it will require a scope to be set. This can be done using the standard functions within svdpi.h,
    // after the module is instantiated, but before the task(s) and/or function(s) are called.
    // For example, if the top level module is instantiated with the name “dut”
    // and the name references within tasks are all hierarchical (dotted) names with respect to that top level module,
    // then the scope could be set with
    // svSetScope(svGetScopeFromName("TOP.dut"));

    /* hard code to the rom
    printf("load vmem file (%s) into rom \n", argv[1]);
    //svSetScope(svGetScopeFromName("TOP.simple_system.inst_rom0"));
    svSetScope(svGetScopeFromName("TOP.simple_system.rom0"));
    simutil_romload(argv[1]);
    */

    /*
    printf("load vmem file (%s) into ram \n", argv[1]);
    //svSetScope(svGetScopeFromName("TOP.simple_system.inst_rom0"));
    svSetScope(svGetScopeFromName("TOP.simple_system.ram0"));
    simutil_ramload(argv[1]);
    */

    while(!contextp->gotFinish())  /* && m_cpu_tickcount < 200 */
    {
        //cpu reset
        if(m_cpu_tickcount<10)
        {
            ptTbTop->n_rst_i = 0;
        }
        else
        {
            if(ptTbTop->n_rst_i == 0)
                printf("reset the cpu,done \n");
            ptTbTop->n_rst_i = 1;
        }

        ptTbTop->clk_i = 1;

#ifdef JTAP_SUPPORT
        jtag->tick(&(ptTbTop->jtag_TCK), &(ptTbTop->jtag_TMS), &(ptTbTop->jtag_TDI), ptTbTop->jtag_TDO);
#endif

        ptTbTop->eval();
        if(m_trace)
        {
	        m_trace->dump(m_cpu_tickcount*10);   //  Tick every 10 ns
	    }

        if(m_cpu_tickcount>=2)   //skip the reset process
        {
            ptTbTop->uart_rxd = (*uart)(ptTbTop->uart_txd);  //get the uart_tx and sent the char via rx_pin to riscv cpu
        }

        ptTbTop->clk_i = 0;
        ptTbTop->eval();
        if(m_trace)
        {
            m_trace->dump(m_cpu_tickcount*10+5);   // Trailing edge dump
            m_trace->flush();
        }
        m_cpu_tickcount++;
    }

    if(m_trace)
    {
        m_trace->flush();
        m_trace->close();
    }

    if(trace_fd)
    {
        fflush(trace_fd);
        fclose(trace_fd);
    }

#if VM_COVERAGE
    VerilatedCov::write("log/coverage.dat");
#endif // VM_COVERAGE

    delete ptTbTop;
    exit(0);
}


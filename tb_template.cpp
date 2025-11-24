#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vmul_top.h"
#include "Vmul_top__Syms.h"

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;
Vmul_top *dut;
VerilatedVcdC *m_trace;
void tick() {
    dut->clk = 0; dut->eval();
    m_trace->dump(sim_time++);
    dut->clk = 1; dut->eval();
    m_trace->dump(sim_time++);
}
int main(int argc, char** argv, char** env) {
    dut = new Vmul_top;
    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

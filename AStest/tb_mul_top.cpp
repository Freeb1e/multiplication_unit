#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vmul_top.h"
#include "Vmul_top__Syms.h"
#include "ram_model.hpp"
#define MAX_SIM_TIME 13440
vluint64_t sim_time = 0;
Vmul_top *dut;
VerilatedVcdC *m_trace;
void tick()
{
    dut->clk = 0;
    dut->eval();
    m_trace->dump(sim_time++);
    dut->clk = 1;
    dut->eval();
    m_trace->dump(sim_time++);
}

int main(int argc, char **argv, char **env)
{
    dut = new Vmul_top;
    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 6);
    m_trace->open("waveform.vcd");
    RamModel ram_HASH;
    RamModel ram_sp;
    ram_HASH.init_from_bin("A_buffer.bin");
    ram_sp.init_from_bin("S.bin");
    dut->rst_n = 0;
    dut->calc_init = 0;
    dut->mem_mode = 0;
    tick();
    dut->rst_n = 1;
    dut->calc_init = 1;
    dut->mem_mode = 1;
    tick();
    dut->calc_init = 0;
    while (sim_time < MAX_SIM_TIME)
    {
        dut->clk ^= 1;
        uint64_t HASHdata = ram_HASH.eval(dut->clk, (dut->addr_HASH) >> 6, 0, 0);
        uint64_t spdata = ram_sp.eval(dut->clk, (dut->addr_sp) >> 6, 0, 0);
        if(dut->clk==0){
            dut->bram_data_HASH = HASHdata;
            dut->bram_data_sp = spdata;
        }
        

        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

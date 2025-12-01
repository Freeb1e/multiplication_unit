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
    RamModel ram_sp_second;
    #ifdef AS_TEST
    ram_HASH.init_from_bin("A_buffer.bin");
    ram_sp.init_from_bin("S.bin");
    ram_sp_second.init_from_bin("B_matrix.bin");
    #else
    ram_HASH.init_from_bin("A_full.bin");
    ram_sp.init_from_bin("S_tr.bin");
    #endif
    dut->rst_n = 0;
    dut->calc_init = 0;
    dut->mem_mode = 0;
    tick();
    dut->rst_n = 1;
    dut->calc_init = 1;
    #ifdef AS_TEST
    dut->mem_mode = 1;
    #else
    dut->mem_mode = 2;
    #endif
    tick();
    dut->calc_init = 0;
    while (sim_time < MAX_SIM_TIME)
    {
        dut->clk ^= 1;
        uint64_t spdata, spdata_null1, spdata_null2;
        uint64_t HASHdata = ram_HASH.eval(dut->clk, (dut->addr_HASH) >> 6, 0, 0);

        uint32_t addr_sp2;
        if (dut->addr_sp_2 > 1344 * 8 * 8)
        {
            addr_sp2 = (dut->addr_sp_2 - 1344 * 8 * 8) >> 6;
        }
        else
        {
            addr_sp2 = 0;
        }
        if (dut->addr_sp < 1344 * 8 * 8)
        {
            spdata = ram_sp.eval(dut->clk, (dut->addr_sp) >> 6, 0, 0);
            ram_sp_second.eval_dual(dut->clk, (dut->addr_sp - 1344 * 8 * 8) >> 6, 0, 0, addr_sp2, dut->wen_sp_2, dut->bram_wdata_sp_2, spdata_null1, spdata_null2);
        }
        else
        {
            ram_sp_second.eval_dual(dut->clk, (dut->addr_sp - 1344 * 8 * 8) >> 6, 0, 0, addr_sp2, dut->wen_sp_2, dut->bram_wdata_sp_2, spdata, spdata_null1);
        }

        // spdata = (dut->addr_sp < 1344*8*8 )?ram_sp.eval(dut->clk, (dut->addr_sp) >> 6, 0, 0) :ram_sp_second.eval(dut->clk, (dut->addr_sp - 1344*8*8) >> 6, dut->wen_sp, dut->bram_wdata_sp);

        if (dut->clk == 0)
        {
            dut->bram_data_HASH = HASHdata;
            dut->bram_data_sp = spdata;
        }
        if (dut->clk == 1 && dut->wen_sp_2 == 1)
        {
            // 获取 64 位原始数据 (假设 bram_wdata_sp 为 64 位)
            unsigned long long raw_data = dut->bram_wdata_sp_2;

            // 按照 16 位进行拆分 (0xFFFF 是 16 位的掩码)
            unsigned int val0 = raw_data & 0xFFFF;         // 第 1 个数 (低 16 位)
            unsigned int val1 = (raw_data >> 16) & 0xFFFF; // 第 2 个数
            unsigned int val2 = (raw_data >> 32) & 0xFFFF; // 第 3 个数
            unsigned int val3 = (raw_data >> 48) & 0xFFFF; // 第 4 个数 (高 16 位)

            std::cout << "Writing SP Data at time " << sim_time
                      << ": Addr=" << dut->addr_sp_2 - 1344 * 8 * 8
                      << " | Data(Dec Split)= "
                      << val0 << ", " << val1 << ", " << val2 << ", " << val3
                      << std::endl;
        }
        if (sim_time == 2800 * 2)
            ram_sp_second.dump_to_txt("B_matrix_out.txt");
        // if(sim_time==2750)dut->HASH_ready=1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vplatform_top.h"
#include "Vplatform_top__Syms.h"
#include "memory.h"
#define MAX_SIM_TIME 4000
vluint64_t sim_time = 0;

Vplatform_top *dut = nullptr;
VerilatedVcdC *m_trace = nullptr;

const char* test_file= nullptr;
const char* dump_file= nullptr;

uint8_t calc_mode =0; // 1 for AS, 2 for SA
void tick()
{
    dut->clk = 0;
    dut->eval();
    m_trace->dump(sim_time++);
    dut->clk = 1;
    dut->eval();
    m_trace->dump(sim_time++);
}

void init_AS_test()
{
    calc_mode = 1;

    test_file = "./testdata/AStest/A_buffer.bin";
    if(load_bin_to_ram(test_file, HASH_buffer_ram, HASH_RAM_SIZE, 0))
    {
        printf("Loaded test data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load test data into HASH RAM.\n");
    }
    test_file = "./testdata/AStest/S.bin";
    if(load_bin_to_ram(test_file, SP_ram, HASH_RAM_SIZE, 0))
    {
        printf("Loaded S data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load S data into HASH RAM.\n");
    }
    test_file = "./testdata/AStest/B_matrix.bin";
    if(load_bin_to_ram(test_file, SP_ram, HASH_RAM_SIZE, 1344*8))
    {
        printf("Loaded B matrix 0 data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load B matrix 0 data into HASH RAM.\n");
    }
}


void init_SA_test()
{
    calc_mode = 2;
    test_file = "./testdata/SAtest/A_full.bin";
    if(load_bin_to_ram(test_file, HASH_buffer_ram, HASH_RAM_SIZE, 0))
    {
        printf("Loaded test data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load test data into HASH RAM.\n");
    }
    test_file = "./testdata/SAtest/S_tr.bin";
    if(load_bin_to_ram(test_file, SP_ram, HASH_RAM_SIZE, 0))
    {
        printf("Loaded S data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load S data into HASH RAM.\n");
    }
    test_file = "./testdata/SAtest/B_matrix0.bin";
    if(load_bin_to_ram(test_file, SP_ram, HASH_RAM_SIZE, 1344*8))
    {
        printf("Loaded B matrix 0 data into HASH RAM successfully.\n");
    }
    else
    {
        printf("Failed to load B matrix 0 data into HASH RAM.\n");
    }
}
#define AS_TEST
int main(int argc, char** argv, char** env) {

    dut = new Vplatform_top;
    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
    #ifdef AS_TEST
    init_AS_test();
    #else
    init_SA_test();
    #endif
    dut->rst_n = 0;
    dut->calc_init = 0;
    dut->mem_mode = 0;
    tick();
    dut->rst_n = 1;
    dut->calc_init = 1;
    dut->mem_mode = calc_mode;
    tick();
    dut->calc_init = 0;


    while (sim_time < MAX_SIM_TIME) {
        dut->clk ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    dump_file = "./testdata/output/Bout.bin";
    if(dump_ram_to_bin(dump_file, SP_ram, SP_RAM_SIZE, 1344*8, 1344*8))
    {
        printf("Dumped output data from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output data from SP_RAM.\n");
    }
    dump_file = "./testdata/output/Bout.txt";
    if(dump_ram_to_matrix(dump_file, SP_ram, SP_RAM_SIZE,1344*8, 1344, 8))
    {
        printf("Dumped output matrix from SP_RAM successfully.\n");
    }
    else
    {
        printf("Failed to dump output matrix from SP_RAM.\n");
    }
    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

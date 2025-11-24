#include <stdlib.h>
#include <iostream>
#include <iomanip>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vtransposition_top_default.h"

#define MAX_SIM_TIME 80
#define SYSTOLIC_WIDTH 4
#define DATA_WIDTH 16

vluint64_t sim_time = 0;
Vtransposition_top_default *dut;
VerilatedVcdC *m_trace;

// 模拟时钟
void tick() {
    dut->clk = 0; dut->eval();
    m_trace->dump(sim_time++);
    dut->clk = 1; dut->eval();
    m_trace->dump(sim_time++);
}

// 辅助打印函数
void print_vector(const char* prefix, vluint64_t val) {
    std::cout << prefix << " [ ";
    for(int k=0; k<SYSTOLIC_WIDTH; k++) {
        uint16_t chunk = (val >> (k*DATA_WIDTH)) & 0xFFFF;
        std::cout << std::hex << std::setw(4) << std::setfill('0') << chunk << " ";
    }
    std::cout << "]" << std::endl;
}

int main(int argc, char** argv, char** env) {
    dut = new Vtransposition_top_default;
    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    // 1. 复位
    dut->rst_n = 0; dut->mode = 0; dut->martix_in = 0;
    tick();
    dut->rst_n = 1;
    
    std::cout << "--- Simulation Start: Right Shift Input -> Up Shift Output ---" << std::endl;

    // 准备输入数据：矩阵的 4 个 列 (Column 0 ~ Column 3)
    // 假设我们要转置一个矩阵：
    // 1 2 3 4
    // 1 2 3 4
    // 1 2 3 4
    // 1 2 3 4
    // 
    // 输入时（Mode 0），我们是按“列”灌入的。
    // 我们希望最后的寄存器状态是左边是Col0，右边是Col3。
    // 由于是右移（Push Right），最先输入的会跑到最右边。
    // 所以输入顺序应该是：Column 3 -> Column 2 -> Column 1 -> Column 0。
    
    vluint64_t col_inputs[4] = {
        0x0001000200030004, // Col 3 (全为4) - 最先进，会被推到最右边
        0x0005000600070008, // Col 2 (全为3)
        0x000a000b000c000d, // Col 1 (全为2)
        0x0011002100310041  // Col 0 (全为1) - 最后进，留在最左边
    };

    // 2. 写入阶段 (Mode 0: Shift Right)
    dut->mode = 0;
    std::cout << "\n[Write Phase] Shifting Right (Input Columns)..." << std::endl;
    for(int i=0; i<4; i++) {
        dut->martix_in = col_inputs[i];
        tick(); 
        print_vector("Input (Col)", col_inputs[i]);
    }

    // 3. 读出阶段 (Mode 1: Shift Up)
    dut->mode = 1;
    dut->martix_in = 0; // 读模式下输入置零
    std::cout << "\n[Read Phase] Shifting Up (Output Rows)..." << std::endl;
    
    // 我们期待读出的行数据。
    // 如果内部是：
    // Col0 Col1 Col2 Col3
    //  1    2    3    4
    //  1    2    3    4 ...
    // 
    // 那么每一行读出来都应该是 1 2 3 4 (即 0x0004000300020001)
    
    for(int i=0; i<4; i++) {
        // 先打印当前 Row 0 的输出，然后再 Tick 移位
        // 注意：Verilator 中 combinational logic (assign) 会在 eval() 后立即更新
        // 所以 tick() 的上升沿后，matrix_out 已经是当前周期的值了
        
        // 这里为了模拟时序：上个上升沿产生的数据，现在读取
        print_vector("Output (Row)", dut->martix_out);
        tick();
    }

    dut->final();
    m_trace->close();
    delete dut;
    delete m_trace;
    return 0;
}
#include "ram_model.hpp"
#include <fstream>
#include <iostream>

RamModel::RamModel() : last_clk(false), output_reg(0) {
    memory.resize(1024, 0);
}

RamModel::~RamModel() {}

bool RamModel::init_from_bin(const std::string &filename) {
    std::ifstream file(filename, std::ios::in | std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::cerr << "[RamModel] Error: Cannot open " << filename << std::endl;
        return false;
    }
    std::streamsize file_size = file.tellg();
    file.seekg(0, std::ios::beg);
    size_t num_words = file_size / sizeof(uint64_t);
    memory.resize(num_words);
    file.read(reinterpret_cast<char*>(memory.data()), file_size);
    std::cout << "[RamModel] Loaded " << num_words << " words from " << filename << std::endl;
    return true;
}

uint64_t RamModel::eval(bool clk, uint64_t addr, bool wen, uint64_t wdata) {
    // 上升沿检测
    bool is_posedge = (!last_clk && clk);

    if (is_posedge) {
        // --- 同步操作开始 ---
        
        // 1. 防止地址越界读取
        uint64_t current_data = 0;
        if (addr < memory.size()) {
            current_data = memory[addr];
        } else {
            // 越界读取返回 0 或保持不变，这里返回 0
            current_data = 0; 
        }

        // 2. 更新输出寄存器 (同步读)
        // 这里实现了 "Read-First" 模式：即使发生写操作，输出的也是写入前的旧数据
        // 如果你想实现 "Write-First" (写穿透)，把这行放到写操作之后即可
        output_reg = current_data;

        // 3. 写操作 (同步写)
        if (wen) {
            if (addr >= memory.size()) {
                memory.resize(addr + 1, 0);
            }
            memory[addr] = wdata;
        }
        
        // --- 同步操作结束 ---
    }

    last_clk = clk;

    // 任何时候都返回寄存器里的值
    // 如果不在上升沿，这里返回的就是上一次锁存的值
    return output_reg;
}

// ============================================================
//  测试主函数
//  编译: g++ -DMAIN_TEST ram_model.cpp -o test_ram
// ============================================================
#ifdef MAIN_TEST
#include <iomanip>
int main() {
    RamModel ram;
    // 手动塞点数据模拟初始化
    //std::ofstream("test.bin", std::ios::binary).write("abcdefgh", 8);
    ram.init_from_bin("S.bin"); // 此时地址0的数据应该是 0x6867666564636261 (little endian)

    bool clk, wen;
    uint64_t addr, wdata;
    
    std::cout << "测试说明: 这是一个同步读 RAM (BRAM)。" << std::endl;
    std::cout << "即使改变地址，rdata 也不会变，必须等 clk 0->1 才会刷新。" << std::endl;
    std::cout << "输入: <clk> <wen> <addr> [data]" << std::endl;

    while (std::cin >> clk >> wen >> addr) {
        wdata = 0;
        if(wen) std::cin >> std::hex >> wdata >> std::dec;

        uint64_t rdata = ram.eval(clk, addr, wen, wdata);

        std::cout << "Clk:" << clk << " Addr:" << addr 
                  << " -> RData:" << std::hex << rdata << std::dec << std::endl;
    }
    return 0;
}
#endif
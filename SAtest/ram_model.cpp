#include "ram_model.hpp"
#include <fstream>
#include <iostream>
#include <iomanip>

// 构造函数初始化两个输出寄存器
RamModel::RamModel() : last_clk(false), output_reg_a(0), output_reg_b(0) {
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

// [保留旧接口] 单端口 eval，内部映射到 Port A
uint64_t RamModel::eval(bool clk, uint64_t addr, bool wen, uint64_t wdata) {
    // 复用 eval_dual 的逻辑，或者为了性能单独写也可以。
    // 这里为了不破坏 last_clk 逻辑，单独实现一遍 Port A 逻辑，
    // 同时也保持 output_reg_b 不变。
    
    bool is_posedge = (!last_clk && clk);

    if (is_posedge) {
        // --- Port A 同步操作 ---
        // 1. 读 (Read-First)
        if (addr < memory.size()) {
            output_reg_a = memory[addr];
        } else {
            output_reg_a = 0; 
        }

        // 2. 写
        if (wen) {
            if (addr >= memory.size()) {
                memory.resize(addr + 1, 0);
            }
            memory[addr] = wdata;
        }
    }

    last_clk = clk;
    return output_reg_a;
}

// [新增] 双端口 eval
void RamModel::eval_dual(bool clk, 
                         uint64_t addr_a, bool wen_a, uint64_t wdata_a,
                         uint64_t addr_b, bool wen_b, uint64_t wdata_b,
                         uint64_t &rdata_a, uint64_t &rdata_b) {
    
    bool is_posedge = (!last_clk && clk);

    if (is_posedge) {
        // -----------------------
        // 1. 同步读取 (Read-First)
        // -----------------------
        
        // Port A Read
        if (addr_a < memory.size()) {
            output_reg_a = memory[addr_a];
        } else {
            output_reg_a = 0;
        }

        // Port B Read
        if (addr_b < memory.size()) {
            output_reg_b = memory[addr_b];
        } else {
            output_reg_b = 0;
        }

        // -----------------------
        // 2. 同步写入
        // -----------------------
        
        // 自动扩容逻辑 (取最大地址)
        size_t max_addr = std::max(wen_a ? addr_a : 0, wen_b ? addr_b : 0);
        if (max_addr >= memory.size()) {
            memory.resize(max_addr + 1, 0);
        }

        // Port A Write
        if (wen_a) {
            memory[addr_a] = wdata_a;
        }

        // Port B Write
        // 注意：如果 addr_a == addr_b 且同时写，这里 B 会覆盖 A。
        // 这通常被称为 "Write Priority" 或模拟时的顺序执行。
        if (wen_b) {
            memory[addr_b] = wdata_b;
        }
    }

    last_clk = clk;

    // 更新输出引用
    rdata_a = output_reg_a;
    rdata_b = output_reg_b;
}

void RamModel::dump_to_txt(const std::string &filename) {
    std::ofstream outfile(filename);
    
    if (!outfile.is_open()) {
        std::cerr << "[RamModel] Error: Cannot create output file " << filename << std::endl;
        return;
    }

    outfile << "Addr | Data (Hex 64-bit)    | Split Dec (16-bit: Low->High)      | Full Dec" << std::endl;
    outfile << "-----|----------------------|------------------------------------|---------" << std::endl;

    for (size_t i = 0; i < memory.size(); ++i) {
        uint64_t raw = memory[i];
        uint16_t v0 = raw & 0xFFFF;
        uint16_t v1 = (raw >> 16) & 0xFFFF;
        uint16_t v2 = (raw >> 32) & 0xFFFF;
        uint16_t v3 = (raw >> 48) & 0xFFFF;

        outfile << std::dec << std::setw(4) << std::setfill('0') << i << " | ";
        outfile << "0x" << std::hex << std::setw(16) << std::setfill('0') << raw << " | ";
        outfile << std::dec << std::setfill(' ');
        outfile << std::setw(5) << v0 << ", "
                << std::setw(5) << v1 << ", "
                << std::setw(5) << v2 << ", "
                << std::setw(5) << v3 << " | ";
        outfile << raw << std::endl;
    }

    outfile.close();
    std::cout << "[RamModel] Memory dumped to " << filename << std::endl;
}

// ============================================================
//  测试主函数更新 (增加了双端口测试)
// ============================================================
#ifdef MAIN_TEST
int main() {
    RamModel ram;
    // 初始化模拟数据
    // 假设 S.bin 不存在，手动造几个数据以便测试
    // ram.init_from_bin("S.bin"); 
    
    // 手动写入一些初始值
    // 使用 eval 接口预热: addr 0 = 0x10, addr 1 = 0x20
    ram.eval(0, 0, 1, 0x10); ram.eval(1, 0, 1, 0x10); // clk rising
    ram.eval(0, 1, 1, 0x20); ram.eval(1, 1, 1, 0x20); // clk rising

    std::cout << "--- Dual Port Test ---" << std::endl;
    
    bool clk = 0;
    // 模拟时钟循环
    for(int i=0; i<4; i++) {
        clk = !clk; // 翻转时钟
        
        // Port A: 读地址 0 (期望 0x10)
        // Port B: 写地址 2, 数据 0x99
        uint64_t addr_a = 0, wdata_a = 0; bool wen_a = 0;
        uint64_t addr_b = 2, wdata_b = 0x99; bool wen_b = 1;
        
        uint64_t r_a, r_b;
        
        ram.eval_dual(clk, 
                      addr_a, wen_a, wdata_a, 
                      addr_b, wen_b, wdata_b,
                      r_a, r_b);
                      
        std::cout << "Clk:" << clk 
                  << " | A_Addr:" << addr_a << " A_RData:" << std::hex << r_a 
                  << " | B_Addr:" << addr_b << " B_Wen:" << wen_b << " B_RData:" << r_b << std::dec << std::endl;
    }
    
    // 验证 Port B 是否写入成功 (通过 Port A 读取地址 2)
    std::cout << "--- Verify Write ---" << std::endl;
    clk = 0; ram.eval(clk, 2, 0, 0); // clk 0
    clk = 1; uint64_t res = ram.eval(clk, 2, 0, 0); // clk 1
    std::cout << "Read Addr 2 from Port A: 0x" << std::hex << res << std::dec << std::endl;

    return 0;
}
#endif
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
void RamModel::dump_decimal_matrix(const std::string &filename) {
    std::ofstream outfile(filename);
    
    if (!outfile.is_open()) {
        std::cerr << "[RamModel] Error: Cannot create matrix file " << filename << std::endl;
        return;
    }

    // 配置参数
    const int ELEMENTS_PER_ROW = 1344; // 用户要求：1344个元素一行
    const int ELEMENTS_PER_WORD = 4;   // 64bit / 16bit = 4
    
    // 计算多少个 RAM Word (64bit) 构成一行输出
    // 1344 / 4 = 336 个 Word
    const int WORDS_PER_ROW = ELEMENTS_PER_ROW / ELEMENTS_PER_WORD; 

    // 遍历内存
    for (size_t i = 0; i < memory.size(); ++i) {
        uint64_t data = memory[i];
        // 拆分 64位 -> 4 x 16位
        uint16_t v0 = data & 0xFFFF;          // 低 16位
        uint16_t v1 = (data >> 16) & 0xFFFF;
        uint16_t v2 = (data >> 32) & 0xFFFF;
        uint16_t v3 = (data >> 48) & 0xFFFF;  // 高 16位

        outfile << std::dec << std::setfill(' '); 
        
        // 输出当前字的 4 个元素
        outfile << std::setw(6) << v0 << " "
                << std::setw(6) << v1 << " "
                << std::setw(6) << v2 << " "
                << std::setw(6) << v3;

        // 判断换行逻辑
        // 如果当前是本行的第 336 个字 (index 从 0 开始，所以 i+1 是计数)
        if ((i + 1) % WORDS_PER_ROW == 0) {
            outfile << std::endl;
        } else {
            // 如果不是行尾，且不是最后一个数据，加一个空格分隔下一个字
            outfile << " "; 
        }
    }
    
    // 确保文件最后有换行（如果循环结束时没有刚好换行）
    if (memory.size() % WORDS_PER_ROW != 0) {
        outfile << std::endl;
    }

    outfile.close();
    std::cout << "[RamModel] Decimal Matrix saved to " << filename 
              << " (Format: " << ELEMENTS_PER_ROW << " elements/row)" << std::endl;
}
void RamModel::dump_to_bin(const std::string &filename) {
    std::ofstream outfile(filename, std::ios::out | std::ios::binary);
    
    if (!outfile.is_open()) {
        std::cerr << "[RamModel] Error: Cannot create binary file " << filename << std::endl;
        return;
    }

    // 直接将 vector 中的内存数据块写入文件
    // 注意：这将按照当前机器的字节序（通常是 Little Endian）写入
    if (!memory.empty()) {
        outfile.write(reinterpret_cast<const char*>(memory.data()), memory.size() * sizeof(uint64_t));
    }

    outfile.close();
    std::cout << "[RamModel] Binary Dump saved to " << filename 
              << " (" << memory.size() * sizeof(uint64_t) << " bytes)" << std::endl;
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
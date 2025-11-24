#ifndef RAM_MODEL_HPP
#define RAM_MODEL_HPP

#include <vector>
#include <string>
#include <cstdint>

class RamModel {
private:
    std::vector<uint64_t> memory;
    bool last_clk;          // 上一次时钟状态
    uint64_t output_reg;    // 输出寄存器 (模拟 BRAM 的输出端口锁存)

public:
    RamModel();
    ~RamModel();

    bool init_from_bin(const std::string &filename);

    /**
     * @brief 只有在时钟上升沿才会更新读/写
     * * @param clk   时钟
     * @param addr  地址
     * @param wen   写使能
     * @param wdata 写数据
     * @return uint64_t 当前输出寄存器的值 (注意：读数据会有1拍延迟)
     */
    uint64_t eval(bool clk, uint64_t addr, bool wen, uint64_t wdata);
};

#endif // RAM_MODEL_HPP
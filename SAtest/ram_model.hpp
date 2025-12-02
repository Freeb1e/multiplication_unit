#ifndef RAM_MODEL_HPP
#define RAM_MODEL_HPP

#include <vector>
#include <string>
#include <cstdint>

class RamModel {
private:
    std::vector<uint64_t> memory;
    bool last_clk;           // 上一次时钟状态
    uint64_t output_reg_a;   // 端口 A 输出寄存器 (原 output_reg)
    uint64_t output_reg_b;   // 端口 B 输出寄存器 (新增)

public:
    RamModel();
    ~RamModel();

    bool init_from_bin(const std::string &filename);
    void dump_to_txt(const std::string &filename);

    /**
     * @brief [兼容旧接口] 单端口模式 (Port A only)
     * 只有在时钟上升沿才会更新读/写
     */
    uint64_t eval(bool clk, uint64_t addr, bool wen, uint64_t wdata);

    /**
     * @brief [新增] 双端口模式 (True Dual-Port)
     * 在时钟上升沿同时处理两个端口的读写。
     * * @param clk     时钟 (假设双端口共用时钟)
     * @param addr_a  端口 A 地址
     * @param wen_a   端口 A 写使能
     * @param wdata_a 端口 A 写数据
     * @param addr_b  端口 B 地址
     * @param wen_b   端口 B 写使能
     * @param wdata_b 端口 B 写数据
     * @param rdata_a [输出] 端口 A 读数据引用
     * @param rdata_b [输出] 端口 B 读数据引用
     */
    void eval_dual(bool clk, 
                   uint64_t addr_a, bool wen_a, uint64_t wdata_a,
                   uint64_t addr_b, bool wen_b, uint64_t wdata_b,
                   uint64_t &rdata_a, uint64_t &rdata_b);
    void dump_decimal_matrix(const std::string &filename);
    void dump_to_bin(const std::string &filename);
};

#endif // RAM_MODEL_HPP
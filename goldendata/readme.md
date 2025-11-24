while (!Verilated::gotFinish()) {
    top->clk = !top->clk; // 翻转时钟
    
    // 重要：如果是 BRAM 模型，你需要在 Verilator eval 之前还是之后调用？
    // 推荐顺序：
    // 1. 改变时钟
    // 2. 调用 RAM 模型 (检测到上升沿，更新 rdata)
    // 3. 将 RAM 的 rdata 赋给 top
    // 4. top->eval() (让 FPGA 逻辑看到新的 rdata)

    uint64_t rdata = my_ram.eval(top->clk, top->addr, top->wen, top->wdata);
    
    top->rdata = rdata; // 将 BRAM 的输出连到 Verilog 模块
    
    top->eval(); // FPGA 逻辑现在能看到时钟沿和新的 rdata
}

**注意：**
由于这是同步读，如果您的 Verilog 逻辑在状态机中发出了读地址（Address），数据要在**下一个时钟周期**才会回来。请确保您的 Verilog 状态机或流水线设计已经考虑了这 1 个周期的读取延迟（Read Latency）。
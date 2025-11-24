#include <stdlib.h>
#include <iostream>
#include <string>
#include <fstream>
#include <vector>
#include <iomanip>
#include <cstdlib>
#include <cstring>


void bram_print(uint32_t *block);
uint32_t bram_core(uint32_t addr, uint32_t din, bool we, bool clk,bool rst,uint32_t *block);

uint32_t bram1[256*4]={0};


void print_acache_bytes(uint64_t offset);
int main() {
    // 示例：读取Acache.bin文件偏移0处的8字节
    uint64_t offset = 0; // 可修改为任意偏移
    while(1){
        std::cin>>offset;
        print_acache_bytes(offset);
    }
    
    return 0;
} 


// 读取Acache.bin文件指定偏移的8字节并以十六进制输出
void print_acache_bytes(uint64_t offset) {
    std::ifstream file("Acache.bin", std::ios::binary);
    file.seekg(offset, std::ios::beg);
    unsigned char buffer[8] = {0};
    file.read(reinterpret_cast<char*>(buffer), 8);
    for (int i = 0; i < 8; ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)buffer[i] << " ";
    }
    std::cout << std::dec << std::endl;
}



uint32_t bram_core(uint32_t addr, uint32_t din, bool we, bool clk,bool rst,uint32_t *block) {
    uint32_t word_index = addr/sizeof(uint32_t);
    if(!rst){
        memset(block,0,sizeof(uint32_t)*256);
        return 0;
    } else if(we && !clk) {
        *(block+word_index) = din;
        return 0;
    } else {
        return block[word_index];
    }
}

void bram_print(uint32_t *block) {
    using namespace std;
    cout << "BRAM内容:" << endl;
    for(int i=0;i<256;i++) {
        cout << hex << setfill('0') << setw(8) << block[i] << " ";
        if((i+1)%8==0)
            cout << endl;
    }
}
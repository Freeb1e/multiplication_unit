#include "Vplatform_top__Dpi.h"
extern bool load_bin_to_ram(const char* filename, uint8_t* ram_ptr, uint32_t max_size, uint32_t offset);
extern bool dump_ram_to_bin(const char* filename, const uint8_t* ram_ptr, uint32_t max_size, uint32_t start_offset, uint32_t write_len);
extern bool dump_ram_to_matrix(const char* filename, const uint8_t* ram_ptr, uint32_t max_size, 
                        uint32_t start_offset, uint32_t rows, uint32_t cols);
#define HASH_RAM_SIZE  1344*1344*2
#define SP_RAM_SIZE    (64 * 1024)

extern uint8_t HASH_buffer_ram[HASH_RAM_SIZE];
extern uint8_t SP_ram[SP_RAM_SIZE];

#define MATRIX_ROWS    8
#define MATRIX_COLS    1344
#define BYTES_PER_ITEM 2


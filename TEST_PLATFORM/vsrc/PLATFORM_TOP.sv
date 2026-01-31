module platform_top(
    input logic clk,
    input logic rst_n,
    input logic calc_init,
    input logic [2:0] mem_mode,
    input logic HASH_ready,
    input logic [31:0] BASE_ADDR_S,
    input logic [31:0] BASE_ADDR_HASH,
    input logic [31:0] BASE_ADDR_B,
    input logic [10:0] MATRIX_SIZE
);

    logic [31:0] addr_sb;
    logic [31:0] addr_HASH;
    logic [31:0] addr_sb_2;
    logic wen_sb;
    logic wen_HASH;
    logic wen_sb_2;
    logic [63:0] bram_wdata_sb;
    logic [63:0] bram_wdata_sb_2;
    logic [63:0] bram_wdata_HASH;

    logic [63:0] bram_data_sb;
    logic [63:0] bram_data_HASH;
    logic [63:0] bram_data_sb_2;
    
    mul_top u_mul_top(
        .clk             	(clk              ),
        .rst_n           	(rst_n            ),
        .mem_mode        	(mem_mode         ),
        .calc_init       	(calc_init        ),

        .BASE_ADDR_S   	(BASE_ADDR_S ),
        .BASE_ADDR_HASH 	(BASE_ADDR_HASH  ),
        .MATRIX_SIZE    	(MATRIX_SIZE ),
        .BASE_ADDR_B   	    (BASE_ADDR_B),

        .bram_data_sb    	(bram_data_sb     ),
        .bram_data_HASH  	(bram_data_HASH   ),
        .bram_data_sb_2  	(bram_data_sb_2   ),

        .addr_sb         	(addr_sb          ),
        .addr_HASH       	(addr_HASH        ),
        .addr_sb_2       	(addr_sb_2        ),

        .wen_sb          	(wen_sb           ),
        .wen_HASH        	(wen_HASH         ),
        .wen_sb_2        	(wen_sb_2         ),

        .bram_wdata_sb   	(bram_wdata_sb    ),
        .bram_wdata_sb_2 	(bram_wdata_sb_2  ),
        .bram_wdata_HASH 	(bram_wdata_HASH  ),

        .HASH_ready      	(HASH_ready       )
    );
    
    
    block_ram_dpi #(
        .BRAM_ID 	(0  ))
    HASH_RAM(
        .clk   	(clk    ),
        .raddr 	(addr_HASH  ),
        .waddr 	(32'h0  ),
        .wdata 	(64'h0  ),
        .wmask 	(8'h0  ),
        .wen   	(1'h0    ),
        .rdata 	(bram_data_HASH )
    );
    block_ram_dpi #(
        .BRAM_ID 	(1  ))
    sp_RAM_port1(
        .clk   	(clk    ),
        .raddr 	(addr_sb  ),
        .waddr 	(addr_sb  ),
        .wdata 	(bram_wdata_sb  ),
        .wmask 	(8'hFF  ),
        .wen   	(wen_sb    ),
        .rdata 	(bram_data_sb  )
    ); 
    block_ram_dpi #(
        .BRAM_ID 	(1  ))
    sp_RAM_port2(
        .clk   	(clk    ),
        .raddr 	(addr_sb_2  ),
        .waddr 	(addr_sb_2  ),
        .wdata 	(bram_wdata_sb_2   ),
        .wmask 	(8'hFF  ),
        .wen   	(wen_sb_2    ),
        .rdata 	(bram_data_sb_2  )
    ); 
endmodule 

module platform_top(
    input logic clk,
    input logic rst_n,
    input logic calc_init,
    input logic [2:0] mem_mode,
    output logic HASH_ready
);

    logic [31:0] addr_sp;
    logic [31:0] addr_dp;
    logic [31:0] addr_HASH;
    logic [31:0] addr_sp_2;
    logic wen_sp;
    logic wen_dp;
    logic wen_HASH;
    logic wen_sp_2;
    logic [63:0] bram_wdata_sp;
    logic [63:0] bram_wdata_sp_2;
    logic [63:0] bram_wdata_dp;
    logic [63:0] bram_wdata_HASH;

    logic [63:0] bram_data_sp;
    logic [63:0] bram_data_dp;
    logic [63:0] bram_data_HASH;
    logic [63:0] bram_data_sp_2;
    
    mul_top u_mul_top(
        .clk             	(clk              ),
        .rst_n           	(rst_n            ),
        .mem_mode        	(mem_mode         ),
        .calc_init       	(calc_init        ),

        .bram_data_sp    	(bram_data_sp     ),
        .bram_data_dp    	(bram_data_dp     ),
        .bram_data_HASH  	(bram_data_HASH   ),
        .bram_data_sp_2  	(bram_data_sp_2   ),

        .addr_sp         	(addr_sp          ),
        .addr_dp         	(addr_dp          ),
        .addr_HASH       	(addr_HASH        ),
        .addr_sp_2       	(addr_sp_2        ),

        .wen_sp          	(wen_sp           ),
        .wen_dp          	(wen_dp           ),
        .wen_HASH        	(wen_HASH         ),
        .wen_sp_2        	(wen_sp_2         ),

        .bram_wdata_sp   	(bram_wdata_sp    ),
        .bram_wdata_sp_2 	(bram_wdata_sp_2  ),
        .bram_wdata_dp   	(bram_wdata_dp    ),
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
        .raddr 	(addr_sp  ),
        .waddr 	(addr_sp  ),
        .wdata 	(bram_wdata_sp  ),
        .wmask 	(8'hFF  ),
        .wen   	(wen_sp    ),
        .rdata 	(bram_data_sp  )
    ); 
    block_ram_dpi #(
        .BRAM_ID 	(1  ))
    sp_RAM_port2(
        .clk   	(clk    ),
        .raddr 	(addr_sp_2  ),
        .waddr 	(addr_sp_2  ),
        .wdata 	(bram_wdata_sp_2   ),
        .wmask 	(8'hFF  ),
        .wen   	(wen_sp_2    ),
        .rdata 	(bram_data_sp_2  )
    ); 
endmodule 

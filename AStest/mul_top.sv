//`include "transposition.sv"
//`include "systolic.sv"
module mul_top(
        input logic clk,
        input logic rst_n,
        input logic [2:0] mem_mode,//0:idle 1:AS 2:SA 3:SB 4:BS
        input logic calc_init,
        input logic [63:0] bram_data_sp,
        input logic [63:0] bram_data_dp,
        input logic [63:0] bram_data_HASH,

        output logic [31:0] addr_sp,
        output logic [31:0] addr_dp,
        output logic [31:0] addr_HASH,
        output logic wen_sp,
        output logic wen_dp,
        output logic wen_HASH,
        output logic [63:0] bram_wdata_sp,
        output logic [63:0] bram_wdata_dp,
        output logic [63:0] bram_wdata_HASH
    );
    logic [63:0] data_left;
    logic [63:0] data_right;

    logic transposition_slect;

    logic [4*16-1:0] martix_out_transposition_1,martix_out_transposition_2;
    logic transposition_mode_1,transposition_mode_2;

    logic [4*16-1:0] martix_out_transposition_3,martix_out_transposition_4;
    logic transposition_mode_3,transposition_mode_4;

    mem_ctrl #(
                 .IDLE              	(0   ),
                 .AS                	(1   ),
                 .SA                	(2   ),
                 .SB                	(3   ),
                 .BS                	(4   ),
                 .Frodo_standard_A  	(32'd1344*16  ),
                 .Frodo_standard_SE 	(32'd1344*8  ))
             u_mem_ctrl(
                 .clk            	(clk             ),
                 .rst_n          	(rst_n           ),
                 .mem_mode       	(mem_mode        ),
                 .calc_init      	(calc_init       ),
                 .bram_data_sp   	(bram_data_sp    ),
                 .bram_data_dp   	(bram_data_dp    ),
                 .bram_data_HASH 	(bram_data_HASH  ),
                 .data_left      	(data_left       ),
                 .data_right     	(data_right      ),
                 .addr_sp        	(addr_sp         ),
                 .addr_dp        	(addr_dp         ),
                 .addr_HASH      	(addr_HASH       ),
                 .transposition_slect  (transposition_slect    ),
                 .systolic_state   	(systolic_state     ),
                 .systolic_mode   	(systolic_mode),
                 .data_adder     	(data_adder),
                 .wen_sp         	(wen_sp          ),
                 .wen_dp         	(wen_dp          ),
                 .wen_HASH       	(wen_HASH)
             );

    // 左矩阵转置器
    assign transposition_mode_1 = transposition_slect ? 1'b1 : 1'b0;
    assign transposition_mode_2 = transposition_slect ? 1'b0 : 1'b1;

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_1(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_left   ),
                                  .martix_out 	(martix_out_transposition_1  ),
                                  .mode       	(transposition_mode_1        )
                              );

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_2(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_left   ),
                                  .martix_out 	(martix_out_transposition_2  ),
                                  .mode       	(transposition_mode_2      )
                              );
    //右矩阵转置器
    logic [63:0] b_mult_in;
    assign b_mult_in = (~delayaddr5) ? {
               8'd0, data_right[31:24],  // Byte 3 -> [63:48]
               8'd0, data_right[23:16],  // Byte 2 -> [47:32]
               8'd0, data_right[15:8],   // Byte 1 -> [31:16]
               8'd0, data_right[7:0]     // Byte 0 -> [15:0]
           }: {
               8'd0, data_right[63:56],  // Byte 7 -> [63:48]
               8'd0, data_right[55:48],  // Byte 6 -> [47:32]
               8'd0, data_right[47:40],  // Byte 5 -> [31:16]
               8'd0, data_right[39:32]   // Byte 4 -> [15:0]
           };
    logic delayaddr5;

    delay_reg #(
                  .DATA_WIDTH   	(1  ),
                  .DELAY_CYCLES 	(1   ))
              u_delay_reg(
                  .clk          	(clk           ),
                  .rst_n        	(rst_n         ),
                  .din          	(addr_sp[5]           ),
                  .delay_switch 	(1'b1  ),
                  .dout         	(delayaddr5          )
              );


    assign transposition_mode_3 = transposition_slect ? 1'b1 : 1'b0;
    assign transposition_mode_4 = transposition_slect ? 1'b0 : 1'b1;

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_3(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(b_mult_in  ),
                                  .martix_out 	(martix_out_transposition_3  ),
                                  .mode       	(transposition_mode_3        )
                              );

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_4(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(b_mult_in    ),
                                  .martix_out 	(martix_out_transposition_4  ),
                                  .mode       	(transposition_mode_4      )
                              );

    // output declaration of module systolic_top
    logic [4*16-1:0] a_in_raw;
    logic [4*16-1:0] b_in_raw;
    logic [4*16-1:0] sum_in_raw;
    logic [4*16-1:0] sum_out;
    logic systolic_mode;//mode 0：权重固定 mode 1：输出固定
    logic systolic_state;//state 0：数据传输  state 1：计算

    assign a_in_raw = transposition_slect ? martix_out_transposition_1 : martix_out_transposition_2 ;
    assign b_in_raw = transposition_slect ? martix_out_transposition_3 : martix_out_transposition_4 ;
    systolic_top #(
                     .DATA_WIDTH     	(16  ),
                     .SUM_WIDTH      	(16  ),
                     .SYSTOLIC_WIDTH 	(4   ))
                 u_systolic_top(
                     .clk        	(clk         ),
                     .rst_n      	(rst_n       ),
                     .a_in_raw   	(a_in_raw    ),
                     .b_in_raw   	(b_in_raw    ),
                     .sum_in_raw 	(sum_in_raw  ),
                     .sum_out    	(sum_out     ),
                     .mode       	(systolic_mode        ),
                     .state      	(systolic_state       )
                 );
    //加法器
    wire [16-1:0] sum1;
    wire [16-1:0] sum2;
    wire [16-1:0] sum3;
    wire [16-1:0] sum4;
    logic [4*16-1:0] data_adder;
    Adder_4 #(
                .DATA_WIDTH 	(16  ))
            u_Adder_4(
                .a1   	(sum_out[16*1-1:16*0]   ),
                .a2   	(sum_out[16*2-1:16*1]   ),
                .a3   	(sum_out[16*3-1:16*2]   ),
                .a4   	(sum_out[16*4-1:16*3]   ),
                .b1   	(data_adder[16*1-1:16*0] ),
                .b2   	(data_adder[16*2-1:16*1] ),
                .b3   	(data_adder[16*3-1:16*2] ),
                .b4   	(data_adder[16*4-1:16*3] ),
                .sum1 	(sum1  ),
                .sum2 	(sum2  ),
                .sum3 	(sum3  ),
                .sum4 	(sum4  )
            );
    always_comb begin
        bram_wdata_sp = {sum4, sum3, sum2, sum1};
    end
endmodule

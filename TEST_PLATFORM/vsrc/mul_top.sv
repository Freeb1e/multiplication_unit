//`include "transposition.sv"
//`include "systolic.sv"
module mul_top(
        input logic clk,
        input logic rst_n,
        input logic [2:0] mem_mode,//0:idle 1:AS 2:SA 3:SB 4:BS
        input logic calc_init,
        input logic [63:0] bram_data_sb,
        input logic [63:0] bram_data_HASH,
        input logic [63:0] bram_data_sb_2,

        input logic [31:0] BASE_ADDR_S,
        input logic [31:0] BASE_ADDR_HASH,
        input logic [10:0] MATRIX_SIZE,
        input logic [31:0] BASE_ADDR_B,
        output logic [31:0] addr_sb,
        output logic [31:0] addr_HASH,
        output logic [31:0] addr_sb_2,
        output logic wen_sb,
        output logic wen_HASH,
        output logic wen_sb_2,
        output logic [63:0] bram_wdata_sb,
        output logic [63:0] bram_wdata_sb_2,
        output logic [63:0] bram_wdata_HASH,
        input logic HASH_ready
    );
    logic [63:0] data_left;
    logic [63:0] data_right;

    logic transposition_slect;

    logic [4*16-1:0] martix_out_transposition_1,martix_out_transposition_2;
    logic transposition_mode_1,transposition_mode_2;

    logic [4*16-1:0] martix_out_transposition_3,martix_out_transposition_4;
    logic transposition_mode_3,transposition_mode_4;

    logic [3:0] current_state;
    // parameter FREE=4'd0,AS_SQUARE=4'd1,AS_SAVE=4'd2,AS_WAITHASH=4'd3,SA_loadweight1=4'd4,SA_loadweight2=4'd5,SA_calculate1=4'd6,SA_calculate2=4'd7,SA_WAITHASH=4'd8;
    // parameter DEBUG=4'd15;
    parameter IDLE=4'd0;
    parameter AS_CALC=4'd1,AS_SAVE=4'd2;
    parameter SA_LOADWEIGHT=4'd3,SA_CALC=4'd4;
    logic transposition_dir;
    logic systolic_enable;
    logic transposition_rst_sync;
    mem_ctrl u_mem_ctrl(
                 .clk            	(clk             ),
                 .rst_n          	(rst_n           ),
                 .mem_mode       	(mem_mode        ),
                 .calc_init      	(calc_init       ),
                 .bram_data_sb   	(bram_data_sb    ),
                 .bram_data_HASH 	(bram_data_HASH  ),
                 .data_left      	(data_left       ),
                 .data_right     	(data_right      ),
                 .addr_sb        	(addr_sb         ),
                 .addr_HASH      	(addr_HASH       ),
                 .transposition_slect  (transposition_slect    ),
                 .systolic_state   	(systolic_state     ),
                 .systolic_mode   	(systolic_mode),
                 .data_adder     	(data_adder),
                 .wen_sb         	(wen_sb          ),
                 .wen_HASH       	(wen_HASH),
                 .HASH_ready     	(HASH_ready      ),
                 .current_state  	(current_state   ),
                 .addr_sb_2      	(addr_sb_2       ),
                 .wen_sb_2       	(wen_sb_2        ),
                 .systolic_enable     (systolic_enable),
                 .transposition_rst_sync (transposition_rst_sync),
                 .bram_data_sb_2        (bram_data_sb_2),
                 .BASE_ADDR_S   	(BASE_ADDR_S ),
                 .BASE_ADDR_HASH 	(BASE_ADDR_HASH),
                 .MATRIX_SIZE    	(MATRIX_SIZE ),
                 .BASE_ADDR_B   	(BASE_ADDR_B)
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
                                  .mode       	(transposition_mode_1        ),
                                  //.dir        (transposition_dir       ),
                                  .rst_sync (transposition_rst_sync)
                              );

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_2(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_left   ),
                                  .martix_out 	(martix_out_transposition_2  ),
                                  .mode       	(transposition_mode_2      ),
                                  //.dir        (transposition_dir      ),
                                  .rst_sync (transposition_rst_sync)
                              );
    //右矩阵转置器
    logic [63:0] HALF_SLECT_DATA;
    assign HALF_SLECT_DATA = (~delayaddr5) ? {
               {8{data_right[31]}}, data_right[31:24],  // Byte 3 -> [63:48]
               {8{data_right[23]}}, data_right[23:16],  // Byte 2 -> [47:32]
               {8{data_right[15]}}, data_right[15:8],   // Byte 1 -> [31:16]
               {8{data_right[7]}}, data_right[7:0]     // Byte 0 -> [15:0]
           }: {
               {8{data_right[63]}}, data_right[63:56],  // Byte 7 -> [63:48]
               {8{data_right[55]}}, data_right[55:48],  // Byte 6 -> [47:32]
               {8{data_right[47]}}, data_right[47:40],  // Byte 5 -> [31:16]
               {8{data_right[39]}}, data_right[39:32]   // Byte 4 -> [15:0]
           };
    logic delayaddr5;

    delay_reg #(
                  .DATA_WIDTH   	(1  ),
                  .DELAY_CYCLES 	(1   ))
              u_delay_reg(
                  .clk          	(clk           ),
                  .rst_n        	(rst_n         ),
                  .din          	(addr_sb[5]           ),
                  .delay_switch 	(1'b1  ),
                  .dout         	(delayaddr5          )
              );


    assign transposition_mode_3 = transposition_slect ? 1'b1 : 1'b0;
    assign transposition_mode_4 = transposition_slect ? 1'b0 : 1'b1;
    logic [63:0] data_right_processed;
    assign data_right_processed =(current_state == SA_CALC) ? sum_out : HALF_SLECT_DATA;
    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_3(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_right_processed  ),
                                  .martix_out 	(martix_out_transposition_3  ),
                                  .mode       	(transposition_mode_3        ),
                                  //.dir        (transposition_dir       ),
                                  .rst_sync (transposition_rst_sync)
                              );

    transposition_top_default #(
                                  .DATA_WIDTH     	(16  ),
                                  .SYSTOLIC_WIDTH 	(4   ))
                              u_transposition_top_default_4(
                                  .clk        	(clk         ),
                                  .rst_n      	(rst_n       ),
                                  .martix_in  	(data_right_processed    ),
                                  .martix_out 	(martix_out_transposition_4  ),
                                  .mode       	(transposition_mode_4      ),
                                  //.dir        (transposition_dir       ),
                                  .rst_sync (transposition_rst_sync)
                              );
    logic [63:0] sum_out_transposed;
    assign sum_out_transposed = (transposition_slect) ? martix_out_transposition_3 : martix_out_transposition_4 ;
    // output declaration of module systolic_top
    logic [4*16-1:0] a_in_raw;
    logic [4*16-1:0] b_in_raw;
    logic [4*16-1:0] sum_in_raw;
    logic [4*16-1:0] sum_out;
    logic systolic_mode;//mode 0：权重固定 mode 1：输出固定
    logic systolic_state;//state 0：数据传输  state 1：计算

    always_comb begin
        case(current_state)
            AS_CALC,AS_SAVE: begin
                a_in_raw = transposition_slect ? martix_out_transposition_1 : martix_out_transposition_2 ;
                b_in_raw = transposition_slect ? martix_out_transposition_3 : martix_out_transposition_4 ;
            end
            SA_LOADWEIGHT: begin
                a_in_raw = HALF_SLECT_DATA ;
                b_in_raw = 64'd0;
            end
            SA_CALC: begin
                a_in_raw = transposition_slect ? martix_out_transposition_1 : martix_out_transposition_2 ;
                b_in_raw = 0;
            end
            default: begin
                a_in_raw = 64'd0 ;
                b_in_raw = HALF_SLECT_DATA;
            end
        endcase
    end
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
                     .state      	(systolic_state       ),
                     .enable     	(systolic_enable      )
                 );


    //加法器
    wire [16-1:0] sum1;
    wire [16-1:0] sum2;
    wire [16-1:0] sum3;
    wire [16-1:0] sum4;
    logic [4*16-1:0] data_adder;
    logic [4*16-1:0] sum_out_mux;
    always_comb begin
        if(current_state == SA_CALC)begin
            sum_out_mux = sum_out_transposed;
        end else begin
            sum_out_mux = sum_out;
        end
    end
    Adder_4 #(
                .DATA_WIDTH 	(16  ))
            u_Adder_4(
                .a1   	(sum_out_mux[16*1-1:16*0]   ),
                .a2   	(sum_out_mux[16*2-1:16*1]   ),
                .a3   	(sum_out_mux[16*3-1:16*2]   ),
                .a4   	(sum_out_mux[16*4-1:16*3]   ),
                .b1   	(data_adder[16*1-1:16*0] ),
                .b2   	(data_adder[16*2-1:16*1] ),
                .b3   	(data_adder[16*3-1:16*2] ),
                .b4   	(data_adder[16*4-1:16*3] ),
                .sum1 	(sum1  ),
                .sum2 	(sum2  ),
                .sum3 	(sum3  ),
                .sum4 	(sum4  ),
                .clk   	(clk    ),
                .rst_n 	(rst_n  )
            );
    always_comb begin
            bram_wdata_sb_2 = {sum4, sum3, sum2, sum1};
    end
endmodule

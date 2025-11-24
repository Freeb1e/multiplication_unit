module mem_ctrl(
        input logic clk,
        input logic rst_n,
        input logic [2:0] mem_mode,//0:idle 1:AS 2:SA 3:SB 4:BS
        input logic calc_init,
        input logic [63:0] bram_data_sp,
        input logic [63:0] bram_data_dp,
        input logic [63:0] bram_data_HASH,
        output logic [63:0] data_left,
        output logic [63:0] data_right,
        output logic [31:0] addr_sp,
        output logic [31:0] addr_dp,
        output logic [31:0] addr_HASH,
        output logic transposition_slect,
        output logic systolic_state,
        output logic systolic_mode
    );

    parameter IDLE=3'd0,AS=3'd1,SA=3'd2,SB=3'd3,BS=3'd4;
    logic [2:0] mode;
    logic [1:0] count_4;
    logic [31:0] cnt_line;
    logic half_flag;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mode <= IDLE;
            systolic_state <= 1'b0;
            systolic_mode <= 1'b0;
        end
        else begin
            if(calc_init) begin
                mode <= mem_mode;
                systolic_state <= 1'b1;
                systolic_mode <= (mem_mode == AS || mem_mode == SB) ? 1'b1 : 1'b0;
            end
        end
    end

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            count_4<='b0;
        end
        else begin
            if(calc_init) begin
                count_4<='b0;
            end
            else begin
                count_4<=count_4+2'b1;
            end
        end
    end
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_line<='b0;
        end
        else begin
            if(calc_init) begin
                cnt_line<='b0;
            end
            else begin
                if(cnt_line==32'd336) 
                  cnt_line<=32'b0;
                else begin
                    if(count_4==2'b11) begin
                        cnt_line<=cnt_line+32'b1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
      if(!rst_n)begin
        half_flag <='b0;
      end else begin
      if(calc_init) begin
        half_flag <='b0;
      end else if(cnt_line==32'd335) begin
          half_flag <= ~half_flag;
        end
      end
    end

    always_ff@(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
        transposition_slect <= 1'b1;
      end else if(calc_init) begin
        transposition_slect <= 1'b1;
      end else begin
        if(count_4==2'd0) begin
          transposition_slect <= ~transposition_slect;
        end
      end
    end
    
    parameter Frodo_standard_A = 32'd1344*16,Frodo_standard_SE=32'd1344*8;
    always_comb begin
      addr_HASH = cnt_line*32'd64+count_4*Frodo_standard_A;
      addr_sp = cnt_line*32'd32+count_4*Frodo_standard_SE+0*((half_flag)?(4*Frodo_standard_SE):32'd0);
    end
    assign data_left = bram_data_HASH;
    assign data_right = bram_data_sp;
endmodule

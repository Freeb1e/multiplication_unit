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
    parameter Frodo_E_bias=32'd6*6*1344-1;//在sp-ram中B的起始地址
    logic [2:0] mode;
    logic [1:0] count_4;
    logic [31:0] cnt_line;
    logic half_flag;
    //矩阵计算内部状态机
    parameter FREE=3'd0,AS_SQUARE=3'd1,AS_SAVE=3'd2;
    logic [2:0] current_state,next_state;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state<=FREE;
        end
        else begin
            current_state<=next_state;
        end
    end
    always_comb begin
        case(current_state)
            FREE: begin
                if(mode==AS) begin
                    next_state=AS_SQUARE;
                end
                else begin
                    next_state=FREE;
                end
            end
            AS_SQUARE: begin
                if(cnt_line==32'd336) begin
                    next_state=AS_SAVE;
                end
                else begin
                    next_state=AS_SQUARE;
                end
            end
            AS_SAVE: begin
                next_state=AS_SAVE;
            end
            default: begin
                next_state=FREE;
            end
        endcase
    end
    always_comb begin
        data_ctrl_left=(current_state==AS_SQUARE)?1'b1:1'b0;
        data_ctrl_right=(current_state==AS_SQUARE)?1'b1:1'b0;
    end

    //矩阵格式载入
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mode <= IDLE;
            systolic_mode <= 1'b0;
            systolic_state <= 1'b0;
        end
        else begin
            if(calc_init) begin
                mode <= mem_mode;
                systolic_mode <= (mem_mode == AS || mem_mode == SB) ? 1'b1 : 1'b0;
            end
            if(current_state==AS_SQUARE)
                systolic_state <= 1'b1;
            else if (current_state==AS_SAVE && cnt_line==32'd338 && count_4==2'b11) begin
                systolic_state <= 1'b0;
            end
        end
    end
    //4x4矩阵计数器
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
    //1344行计数器
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_line<='b0;
        end
        else begin
            if(calc_init) begin
                cnt_line<='b0;
            end
            else begin
                if(count_4==2'b11) begin
                    if(cnt_line==32'd338)
                        cnt_line<=32'b0;
                    else
                        cnt_line<=cnt_line+32'b1;
                end
            end
        end
    end
    //乒乓转置器的选择
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            transposition_slect <= 1'b1;
        end
        else if(calc_init) begin
            transposition_slect <= 1'b1;
        end
        else begin
            if(count_4==2'd0) begin
                transposition_slect <= ~transposition_slect;
            end
        end
    end
    //结果矩阵分块计数器
    logic [9:0] cnt_result_block;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_result_block<='b0;
        end else if(calc_init) begin
            cnt_result_block<='b0;
        end else begin
            if(current_state==AS_SQUARE && next_state == AS_SAVE) begin
                    cnt_result_block<=cnt_result_block+10'b1;
            end
        end
    end
    assign half_flag = cnt_result_block[0];
    //地址产生
    parameter Frodo_standard_A = 32'd1344*16,Frodo_standard_SE=32'd1344*8;
    always_comb begin
        if(mode==AS) begin
            if(current_state==AS_SQUARE)begin
                addr_HASH = cnt_line*32'd64+count_4*Frodo_standard_A;
                addr_sp = cnt_line*32'd32+count_4*Frodo_standard_SE+((half_flag)?(4*Frodo_standard_SE):32'd0);
            end else begin
                addr_sp = 1;
            end
        end 
    end
    logic data_ctrl_left,data_ctrl_right;
    assign data_left =(data_ctrl_left)? bram_data_HASH:64'd0;
    assign data_right = (data_ctrl_right)? bram_data_sp:64'd0;
endmodule

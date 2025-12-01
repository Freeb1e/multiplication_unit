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
        output logic [31:0] addr_sp_2,
        output logic transposition_slect,
        output logic systolic_state,
        output logic systolic_mode,
        output logic [63:0] data_adder,
        output logic wen_sp,
        output logic wen_dp,
        output logic wen_HASH,
        output logic wen_sp_2,
        input logic HASH_ready,
        output logic [3:0] current_state,
        output logic transposition_dir,
        output logic systolic_enable,
        output logic transposition_rst_sync
    );

    parameter IDLE=3'd0,AS=3'd1,SA=3'd2,SB=3'd3,BS=3'd4;
    parameter Frodo_E_bias=32'd6*6*1344-1;//在sp-ram中B的起始地址
    logic [2:0] mode;
    logic [1:0] count_4;
    logic [31:0] cnt_line;
    logic half_flag;
    logic block_init;
    //矩阵计算内部状态机
    parameter FREE=4'd0,AS_SQUARE=4'd1,AS_SAVE=4'd2,AS_WAITHASH=4'd3,SA_loadweight1=4'd4,SA_loadweight2=4'd5,SA_calculate=4'd6,SA_WAITHASH=4'd7,SA_loadweight_mid=4'd8;
    parameter DEBUG=4'd15;
    logic [3:0] next_state,last_state;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            current_state<=FREE;
            last_state<=FREE;
        end
        else begin
            current_state<=next_state;
            last_state<=current_state;
        end
    end
    always_comb begin
        case(current_state)
            FREE: begin
                case(mode)
                    AS: begin
                        next_state = AS_SQUARE;
                    end
                    SA: begin
                        next_state = SA_loadweight1;
                    end
                    default: begin
                        next_state=FREE;
                    end
                endcase
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
                if(cnt_line == 32'd340 && count_4==2'b11) begin
                    next_state=AS_WAITHASH;
                end
                else
                    next_state=AS_SAVE;
            end
            AS_WAITHASH: begin
                if(HASH_ready || cnt_result_block[0]) begin
                    next_state=AS_SQUARE;
                end
                else begin
                    next_state=AS_WAITHASH;
                end
            end
            SA_loadweight1:begin
                if(cnt_line == 'd2 && count_4==2'd2)begin
                    next_state=SA_calculate;
                end else
                    next_state=SA_loadweight1;
            end
            SA_loadweight_mid:begin
                next_state=SA_calculate;
            end
            SA_calculate:begin
                next_state=SA_calculate;
            end
            DEBUG: begin
                next_state=DEBUG;
            end
            default: begin
                next_state=FREE;
            end
        endcase
    end
    always_comb begin
        case(current_state)
            AS_SQUARE: begin
                data_ctrl_left=1'b1;
                data_ctrl_right=1'b1;
            end
            SA_loadweight1,SA_loadweight_mid:begin
                data_ctrl_left=1'b0;
                data_ctrl_right=1'b1;
            end
            SA_calculate: begin
                if(last_state==SA_calculate)
                    data_ctrl_left=1'b1;
                else 
                    data_ctrl_left=1'b0;
                data_ctrl_right=1'b0;
            end
            DEBUG: begin
                data_ctrl_left=1'b1;
                data_ctrl_right=1'b1;
            end
            default: begin
                data_ctrl_left=1'b0;
                data_ctrl_right=1'b0;
            end
        endcase
    end
    logic load_init;
    always_comb begin
        if(current_state!=SA_loadweight1 && next_state==SA_loadweight1) begin
                load_init = 1'b1;
            end
            else begin
                load_init = 1'b0;
            end
    end

    always_ff@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            systolic_enable <= 1'b1;
        end else begin
            if(current_state == SA_loadweight1 && count_4 == 2'b1 && cnt_line == 2) begin
                systolic_enable <= 1'b0;
            end
            if(current_state == SA_calculate) begin
                systolic_enable <= 1'b1;
            end
        end
    end
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            block_init <= 1'b0;
        end
        else begin
            if(current_state==AS_WAITHASH && next_state==AS_SQUARE) begin
                block_init <= 1'b1;end
            else if(current_state==SA_loadweight1 && next_state == SA_calculate) begin
                block_init <= 1'b1;
            end else begin
                block_init <= 1'b0;
            end
        end
    end

    //矩阵格式载入
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mode <= IDLE;
            systolic_mode <= 1'b0;
            systolic_state <= 1'b0;
        end
        else begin // 0:数据传输 1:计算
            if(calc_init) begin
                mode <= mem_mode;
                systolic_mode <= (mem_mode == AS || mem_mode == SB) ? 1'b1 : 1'b0;
            end
            case(current_state)
                AS_SQUARE:
                    systolic_state <= 1'b1;
                AS_SAVE: begin
                    if(cnt_line==32'd338 && count_4==2'b11) begin
                        systolic_state <= 1'b0;
                    end
                end
                SA_loadweight1,SA_loadweight2: begin
                    systolic_state <= 1'b0;
                end
                SA_calculate: begin
                    systolic_state<=1'b1;
                end
                DEBUG: begin
                    systolic_state <= 1'b1;
                end
                SA_loadweight_mid: begin
                    systolic_state <= 1'b0;
                end
                default: begin
                    systolic_state <= systolic_state;
                end
            endcase
        end
    end
    //4x4矩阵计数器
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            count_4<='b0;
        end
        else begin
            if(calc_init || block_init || load_init) begin
                count_4<='b0;
            end
            else begin
                 if(mode ==AS || current_state==SA_loadweight1 || current_state==SA_loadweight2 || current_state==SA_calculate)
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
            if(calc_init || block_init) begin
                cnt_line<='b0;
            end else begin
                if(count_4==2'b11) begin
                    if(cnt_line==32'd340)
                        cnt_line<=32'b0;
                    else
                        cnt_line<=cnt_line+32'b1;
                end
            end
        end
    end

    //结果矩阵分块计数器
    logic [9:0] cnt_result_block;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_result_block<='b0;
        end
        else if(calc_init) begin
            cnt_result_block<='b0;
        end
        else begin
            if(current_state==AS_SAVE && next_state == AS_WAITHASH) begin
                cnt_result_block<=cnt_result_block+10'b1;
            end
        end
    end

    //左乘情况下向右移动的计数器
    logic [8:0] cnt_line_left;
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_line_left <= 'b0;
        end
        else begin
            if(current_state == SA_WAITHASH && next_state == SA_loadweight1) begin
                cnt_line_left <= 'b0;
            end
            else begin
                if(current_state == SA_calculate && next_state == SA_loadweight1) begin
                    cnt_line_left <= cnt_line_left + 9'b1;
                end
            end
        end
    end
    assign half_flag = cnt_result_block[0];
    //地址产生
    parameter Frodo_standard_A = 32'd1344*16,Frodo_standard_SE=32'd1344*8;
    parameter BASEADDR_B = 32'd1344*8*8;
    logic [1:0] save_bias,save_bias_w;
    assign save_bias = 2'b10 - count_4;
    assign save_bias_w = save_bias+2'd2;
    logic [31:0] debug_addr_w,debug_addr_r;
    assign debug_addr_w = addr_sp_2-BASEADDR_B;
    assign debug_addr_r = addr_sp-BASEADDR_B;
    always_comb begin
        data_adder = 64'd0;
        addr_dp = 32'd0;
        addr_sp = 32'd0;
        addr_HASH = 32'd0;
        addr_sp_2 = 32'd0;
        if(mode==AS) begin
            if(current_state==AS_SQUARE) begin
                addr_HASH = cnt_line*32'd64+count_4*Frodo_standard_A;
                addr_sp = cnt_line*32'd32+count_4*Frodo_standard_SE+((half_flag)?(4*Frodo_standard_SE):32'd0);
            end
            else if(current_state == AS_SAVE) begin
                /* verilator lint_off WIDTH */
                addr_sp = BASEADDR_B + (cnt_result_block>>1)*16*32+cnt_result_block[0]*64+save_bias*16*8;
                addr_sp_2 = BASEADDR_B + (cnt_result_block>>1)*16*32+cnt_result_block[0]*64+(save_bias_w)*16*8;
                /* verilator lint_on WIDTH */
                data_adder = bram_data_sp;
                addr_HASH=1;
            end
        end
        else if (mode == SA) begin
            if(current_state == SA_loadweight1) begin
                /* verilator lint_off WIDTH */
                addr_sp = cnt_line_left*32'd64+(count_4)*Frodo_standard_SE;
                /* verilator lint_on WIDTH */
            end else if(current_state == SA_calculate)begin
                addr_HASH = cnt_line*32'd64+count_4*Frodo_standard_A;
            end
        end
    end
    logic data_ctrl_left,data_ctrl_right;
    always_comb begin
        case(current_state)
            AS_SQUARE,AS_SAVE,AS_WAITHASH:begin
                data_left =(data_ctrl_left)? bram_data_HASH:64'd0;
                data_right = (data_ctrl_right)? bram_data_sp:64'd0;
            end
            SA_loadweight1,SA_loadweight_mid: begin
                data_left = 64'd0;
                data_right = (data_ctrl_right)? bram_data_sp:64'd0;
            end
            SA_calculate: begin
                data_left = (data_ctrl_left)? bram_data_HASH:64'd0;
                data_right = 64'd0;
            end
            DEBUG: begin
                data_left = (data_ctrl_right)? bram_data_sp:64'd0;
                data_right = 64'd0;
            end
            default: begin
                data_left = 64'd0;
                data_right = 64'd0;
            end
        endcase
    end

    always_comb begin
        wen_sp = 1'b0;
        wen_dp=0;
        wen_HASH=0;
        wen_sp_2=0;
        if(mode==AS) begin
            if(current_state==AS_SAVE) begin
                wen_sp_2 =(cnt_line==32'd339 && count_4>0)||(cnt_line == 32'd340 && count_4 == 0)? 1'b1 : 1'b0;
            end
        end
    end

    always_comb begin
        transposition_dir = 1'b1;
        case(mode)
        AS: begin
            transposition_dir = 1'b0; // 向上推出
        end
        SA: begin
            if(current_state==SA_loadweight1 || current_state==SA_loadweight_mid)
                transposition_dir = 1'b1; // 向上推出
            else
                transposition_dir = 1'b0; // 向下推出
        end
        endcase
    end

    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            transposition_rst_sync <= 1'b0;
        end
        else begin
            if(block_init) begin
                transposition_rst_sync <= 1'b1;
            end else begin
                transposition_rst_sync <=1'b0;
            end
        end
    end
        //乒乓转置器的选择
    always_ff@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            transposition_slect <= 1'b1;
        end
        else if(calc_init || block_init) begin
            transposition_slect <= 1'b1;
        end
        else begin
            if(count_4==2'd0) begin
                transposition_slect <= ~transposition_slect;
            end
        end
    end
endmodule

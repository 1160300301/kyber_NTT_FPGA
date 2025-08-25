// datapath_controller.v
// 数据路径控制器

`include "kyber_params.v"

module datapath_controller (
    input  clk,
    input  rst_n,
    
    // 控制信号
    input  [MODE_WIDTH-1:0] mode,           // 操作模式
    input  [STATE_WIDTH-1:0] state,         // 当前状态
    input  [STAGE_WIDTH-1:0] stage,         // 当前阶段
    input  compute_enable,                  // 计算使能
    input  ping_pong_sel,                   // 乒乓选择
    
    // 存储器接口（单个信号而非数组）
    input  [DATA_WIDTH-1:0] ram_data_a,     // RAM A数据
    input  [DATA_WIDTH-1:0] ram_data_b,     // RAM B数据
    output reg [DATA_WIDTH-1:0] ram_write_a,    // RAM A写数据
    output reg [DATA_WIDTH-1:0] ram_write_b,    // RAM B写数据
    output reg ram_write_enable,                // RAM写使能
    
    // 旋转因子接口
    input  [DATA_WIDTH-1:0] twiddle,        // 旋转因子
    
    // 蝶形单元接口
    output reg [DATA_WIDTH-1:0] bf_data_a,      // 蝶形单元输入A
    output reg [DATA_WIDTH-1:0] bf_data_b,      // 蝶形单元输入B
    output reg [DATA_WIDTH-1:0] bf_twiddle,     // 蝶形单元旋转因子
    output reg bf_valid_in,                     // 蝶形单元输入有效
    input  [DATA_WIDTH-1:0] bf_result_u,    // 蝶形单元结果U
    input  [DATA_WIDTH-1:0] bf_result_e,    // 蝶形单元结果E
    input  bf_valid_out,                    // 蝶形单元输出有效
    
    // 状态输出
    output reg datapath_busy,               // 数据路径忙信号
    output reg computation_done             // 计算完成信号
);

// 内部寄存器 - 将循环变量声明移到always块外
integer i; // 循环变量声明移到这里

reg [2:0] pipeline_stage;                  // 流水线阶段
reg [DATA_WIDTH-1:0] data_buffer_a;        // 数据缓冲A（简化为单个）
reg [DATA_WIDTH-1:0] data_buffer_b;        // 数据缓冲B（简化为单个）
reg [DATA_WIDTH-1:0] twiddle_buffer;       // 旋转因子缓冲（简化为单个）
reg valid_buffer [0:2];                    // 有效信号流水线

// 数据选择逻辑
always @(*) begin
    case (state)
        STATE_COMPUTE: begin
            if (ping_pong_sel) begin
                // 从RAM A读取，写入RAM B
                bf_data_a = ram_data_a;
                bf_data_b = ram_data_a; // 简化：使用相同数据
            end else begin
                // 从RAM B读取，写入RAM A
                bf_data_a = ram_data_b;
                bf_data_b = ram_data_b; // 简化：使用相同数据
            end
            // 旋转因子分配
            bf_twiddle = twiddle;
            // 输入有效信号控制
            bf_valid_in = compute_enable;
        end
        
        default: begin
            bf_data_a = 0;
            bf_data_b = 0;
            bf_twiddle = 0;
            bf_valid_in = 0;
        end
    endcase
end

// 结果写回逻辑
always @(*) begin
    if (bf_valid_out) begin
        if (ping_pong_sel) begin
            // 写入RAM B
            ram_write_b = bf_result_u;
            ram_write_a = 0; // 不写入RAM A
        end else begin
            // 写入RAM A
            ram_write_a = bf_result_u;
            ram_write_b = 0; // 不写入RAM B
        end
        ram_write_enable = 1;
    end else begin
        ram_write_a = 0;
        ram_write_b = 0;
        ram_write_enable = 0;
    end
end

// 流水线控制
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipeline_stage <= 0;
        datapath_busy <= 0;
        computation_done <= 0;
        // 使用传统的for循环方式
        for (i = 0; i < 3; i = i + 1) begin
            valid_buffer[i] <= 0;
        end
    end else begin
        // 有效信号流水线
        valid_buffer[0] <= bf_valid_in;
        valid_buffer[1] <= valid_buffer[0];
        valid_buffer[2] <= valid_buffer[1];
        
        // 数据路径状态控制
        case (state)
            STATE_IDLE: begin
                datapath_busy <= 0;
                computation_done <= 0;
                pipeline_stage <= 0;
            end
            
            STATE_COMPUTE: begin
                datapath_busy <= 1;
                
                if (compute_enable) begin
                    case (pipeline_stage)
                        0: begin // 数据准备阶段
                            if (bf_valid_in) begin
                                pipeline_stage <= 1;
                            end
                        end
                        
                        1: begin // 计算阶段
                            if (valid_buffer[1]) begin
                                pipeline_stage <= 2;
                            end
                        end
                        
                        2: begin // 写回阶段
                            if (bf_valid_out) begin
                                pipeline_stage <= 0;
                                computation_done <= 1;
                            end
                        end
                        
                        default: pipeline_stage <= 0;
                    endcase
                end
            end
            
            default: begin
                datapath_busy <= 0;
                computation_done <= 0;
                pipeline_stage <= 0;
            end
        endcase
    end
end

// 数据缓冲管理（可选的流水线优化）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_buffer_a <= 0;
        data_buffer_b <= 0;
        twiddle_buffer <= 0;
    end else begin
        if (bf_valid_in) begin
            data_buffer_a <= bf_data_a;
            data_buffer_b <= bf_data_b;
            twiddle_buffer <= bf_twiddle;
        end
    end
end

endmodule

// 数据重排单元
module data_reorder_unit (
    input  clk,
    input  rst_n,
    input  [STAGE_WIDTH-1:0] stage,                    // 当前阶段
    input  [DATA_WIDTH-1:0] data_in,                   // 输入数据（简化为单个）
    output reg [DATA_WIDTH-1:0] data_out               // 重排后数据（简化为单个）
);

// 根据NTT阶段进行数据重排
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= 0;
    end else begin
        case (stage)
            0, 1, 2: begin // 早期阶段：简单传输
                data_out <= data_in;
            end
            
            3, 4: begin // 中期阶段：简单处理
                data_out <= data_in;
            end
            
            5, 6: begin // 后期阶段：简单处理
                data_out <= data_in;
            end
            
            default: begin
                data_out <= data_in;
            end
        endcase
    end
end

endmodule
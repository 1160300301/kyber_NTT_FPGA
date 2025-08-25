// ntt_controller.v
// NTT顶层控制器，管理整个计算流程

`include "kyber_params.v"

module ntt_controller (
    input  clk,
    input  rst_n,
    
    // 外部控制接口
    input  start,                        // 开始信号
    input  [MODE_WIDTH-1:0] mode,        // 操作模式
    output reg done,                     // 完成信号
    output reg busy,                     // 忙信号
    output reg error,                    // 错误信号
    
    // 内部模块控制信号
    output reg [STATE_WIDTH-1:0] state,     // 当前状态
    output reg [STAGE_WIDTH-1:0] stage,     // 当前阶段
    output reg load_enable,                 // 数据加载使能
    output reg compute_enable,              // 计算使能
    output reg output_enable,               // 输出使能
    output reg addr_gen_start,              // 地址生成器启动
    output reg ping_pong_sel,               // 乒乓缓冲选择
    
    // 状态反馈信号
    input  addr_gen_complete,               // 地址生成完成
    input  butterfly_valid,                 // 蝶形单元输出有效
    input  stage_complete                   // 阶段完成信号
);

// 内部计数器和寄存器
reg [7:0] cycle_counter;                // 周期计数器
reg [STATE_WIDTH-1:0] next_state;       // 下一状态
reg [STAGE_WIDTH-1:0] stage_counter;    // 阶段计数器
reg operation_complete;                 // 操作完成标志

// 各阶段所需的时钟周期数
wire [7:0] load_cycles;
wire [7:0] compute_cycles; 
wire [7:0] output_cycles;

assign load_cycles = LOAD_CYCLES;
assign compute_cycles = STAGE_CYCLES;
assign output_cycles = OUTPUT_CYCLES;

// 主状态机
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        stage <= 0;
        cycle_counter <= 0;
        stage_counter <= 0;
        done <= 0;
        busy <= 0;
        error <= 0;
        load_enable <= 0;
        compute_enable <= 0;
        output_enable <= 0;
        addr_gen_start <= 0;
        ping_pong_sel <= 0;
        operation_complete <= 0;
    end else begin
        state <= next_state;
        
        case (state)
            STATE_IDLE: begin
                done <= 0;
                busy <= 0;
                error <= 0;
                load_enable <= 0;
                compute_enable <= 0;
                output_enable <= 0;
                addr_gen_start <= 0;
                cycle_counter <= 0;
                stage_counter <= 0;
                stage <= 0;
                ping_pong_sel <= 0;
                operation_complete <= 0;
            end
            
            STATE_LOAD: begin
                busy <= 1;
                load_enable <= 1;
                addr_gen_start <= 1;
                
                if (addr_gen_complete) begin
                    cycle_counter <= cycle_counter + 1;
                    if (cycle_counter >= load_cycles - 1) begin
                        load_enable <= 0;
                        addr_gen_start <= 0;
                        cycle_counter <= 0;
                    end
                end
            end
            
            STATE_COMPUTE: begin
                busy <= 1;
                compute_enable <= 1;
                addr_gen_start <= 1;
                stage <= stage_counter;
                
                // 管理乒乓缓冲切换
                if (cycle_counter == 0) begin
                    ping_pong_sel <= ~ping_pong_sel;
                end
                
                if (stage_complete) begin
                    cycle_counter <= 0;
                    stage_counter <= stage_counter + 1;
                    
                    // 检查是否完成所有阶段
                    if (stage_counter >= NTT_STAGES - 1) begin
                        compute_enable <= 0;
                        addr_gen_start <= 0;
                        stage_counter <= 0;
                        operation_complete <= 1;
                    end
                end else if (addr_gen_complete) begin
                    cycle_counter <= cycle_counter + 1;
                end
            end
            
            STATE_OUTPUT: begin
                busy <= 1;
                output_enable <= 1;
                addr_gen_start <= 1;
                
                if (addr_gen_complete) begin
                    cycle_counter <= cycle_counter + 1;
                    if (cycle_counter >= output_cycles - 1) begin
                        output_enable <= 0;
                        addr_gen_start <= 0;
                        done <= 1;
                        busy <= 0;
                        cycle_counter <= 0;
                    end
                end
            end
            
            default: begin
                state <= STATE_IDLE;
                error <= 1;
            end
        endcase
    end
end

// 下一状态逻辑
always @(*) begin
    next_state = state;
    
    case (state)
        STATE_IDLE: begin
            if (start) begin
                next_state = STATE_LOAD;
            end
        end
        
        STATE_LOAD: begin
            if (cycle_counter >= load_cycles - 1 && addr_gen_complete) begin
                next_state = STATE_COMPUTE;
            end
        end
        
        STATE_COMPUTE: begin
            if (operation_complete) begin
                next_state = STATE_OUTPUT;
            end
        end
        
        STATE_OUTPUT: begin
            if (cycle_counter >= output_cycles - 1 && addr_gen_complete) begin
                next_state = STATE_IDLE;
            end
        end
        
        default: begin
            next_state = STATE_IDLE;
        end
    endcase
end

endmodule

// 计时器模块，用于精确控制各阶段的时序
module ntt_timer (
    input  clk,
    input  rst_n,
    input  [STATE_WIDTH-1:0] state,
    input  start_timer,
    output reg timeout,
    output reg [15:0] elapsed_time
);

reg [15:0] timer_counter;
reg [15:0] timeout_value;

// 根据状态设置超时值
always @(*) begin
    case (state)
        STATE_LOAD:    timeout_value = LOAD_CYCLES + 10;
        STATE_COMPUTE: timeout_value = STAGE_CYCLES * NTT_STAGES + 50;
        STATE_OUTPUT:  timeout_value = OUTPUT_CYCLES + 10;
        default:       timeout_value = 100;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        timer_counter <= 0;
        timeout <= 0;
        elapsed_time <= 0;
    end else begin
        if (start_timer) begin
            if (timer_counter < timeout_value) begin
                timer_counter <= timer_counter + 1;
                elapsed_time <= timer_counter;
                timeout <= 0;
            end else begin
                timeout <= 1;
                timer_counter <= 0;
            end
        end else begin
            timer_counter <= 0;
            timeout <= 0;
            elapsed_time <= 0;
        end
    end
end

endmodule
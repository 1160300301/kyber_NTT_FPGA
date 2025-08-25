// address_generator.v  
// 地址生成单元

`include "kyber_params.v"

module address_generator (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,        // 操作模式
    input  [STAGE_WIDTH-1:0] stage,      // 当前计算阶段
    input  start,                        // 开始信号
    input  [STATE_WIDTH-1:0] state,      // 当前状态
    
    // 存储器访问地址
    output reg [ADDR_WIDTH-1:0] ram_addr,     // RAM访问地址
    output reg [TW_ADDR_WIDTH-1:0] tw_addr,   // 旋转因子地址
    output reg addr_valid,                    // 地址有效信号
    output reg stage_complete                 // 阶段完成信号
);

// 内部计数器
reg [ADDR_WIDTH-1:0] base_counter;       // 基础计数器
reg [4:0] cycle_counter;                 // 周期计数器
reg [STAGE_WIDTH-1:0] current_stage;     // 当前阶段
reg [7:0] group_counter;                 // 分组计数器
reg [3:0] element_counter;               // 元素计数器

// 每阶段的参数
wire [7:0] stage_len;                    // 当前阶段长度
wire [7:0] stage_groups;                 // 当前阶段分组数
wire [TW_ADDR_WIDTH-1:0] tw_base;        // 旋转因子基址

// 根据阶段计算参数
assign stage_len = 128 >> stage;         // len = 128, 64, 32, 16, 8, 4, 2
assign stage_groups = 128 / stage_len;   // 分组数量
assign tw_base = (1 << stage) - 1;      // 旋转因子基址

// 地址生成主逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        base_counter <= 0;
        cycle_counter <= 0;
        current_stage <= 0;
        group_counter <= 0;
        element_counter <= 0;
        ram_addr <= 0;
        tw_addr <= 0;
        addr_valid <= 0;
        stage_complete <= 0;
    end else begin
        case (state)
            STATE_LOAD: begin
                // 数据加载阶段：顺序地址生成
                if (start) begin
                    if (base_counter < KYBER_N) begin
                        ram_addr <= base_counter;
                        base_counter <= base_counter + 1;
                        addr_valid <= 1;
                    end else begin
                        addr_valid <= 0;
                        stage_complete <= 1;
                    end
                end
            end
            
            STATE_COMPUTE: begin
                // 计算阶段：根据NTT/INTT生成不同的访问模式
                stage_complete <= 0;
                
                if (start) begin
                    case (mode)
                        MODE_NTT, MODE_INTT: begin
                            // 顺序访问，由于数据预重排，不需要复杂的位反转
                            if (cycle_counter < STAGE_CYCLES) begin
                                // 生成顺序地址
                                ram_addr <= base_counter;
                                
                                // 旋转因子地址生成
                                if (mode == MODE_NTT) begin
                                    tw_addr <= tw_base + group_counter;
                                end else begin // MODE_INTT
                                    tw_addr <= tw_base - group_counter;
                                end
                                
                                // 更新计数器
                                if (element_counter == stage_len - 1) begin
                                    element_counter <= 0;
                                    group_counter <= group_counter + 1;
                                    base_counter <= base_counter + 1;
                                    
                                    if (group_counter == stage_groups - 1) begin
                                        group_counter <= 0;
                                        cycle_counter <= cycle_counter + 1;
                                    end
                                end else begin
                                    element_counter <= element_counter + 1;
                                    base_counter <= base_counter + 1;
                                end
                                
                                addr_valid <= 1;
                                
                                // 检查阶段是否完成
                                if (cycle_counter == STAGE_CYCLES - 1) begin
                                    stage_complete <= 1;
                                    cycle_counter <= 0;
                                    base_counter <= 0;
                                    current_stage <= current_stage + 1;
                                end
                            end
                        end
                        
                        MODE_PWM: begin
                            // 点乘模式：简单顺序访问
                            if (base_counter < KYBER_N) begin
                                ram_addr <= base_counter;
                                tw_addr <= 0; // 点乘不需要旋转因子
                                base_counter <= base_counter + 1;
                                addr_valid <= 1;
                            end else begin
                                addr_valid <= 0;
                                stage_complete <= 1;
                                base_counter <= 0;
                            end
                        end
                        
                        default: begin
                            addr_valid <= 0;
                            stage_complete <= 1;
                        end
                    endcase
                end else begin
                    addr_valid <= 0;
                end
            end
            
            STATE_OUTPUT: begin
                // 输出阶段：顺序输出
                if (start) begin
                    if (base_counter < KYBER_N) begin
                        ram_addr <= base_counter;
                        base_counter <= base_counter + 1;
                        addr_valid <= 1;
                    end else begin
                        addr_valid <= 0;
                        stage_complete <= 1;
                        base_counter <= 0;
                    end
                end
            end
            
            default: begin
                // 空闲状态
                base_counter <= 0;
                cycle_counter <= 0;
                current_stage <= 0;
                group_counter <= 0;
                element_counter <= 0;
                ram_addr <= 0;
                tw_addr <= 0;
                addr_valid <= 0;
                stage_complete <= 0;
            end
        endcase
    end
end

endmodule

// 为8个并行蝶形单元提供相同的地址
module parallel_address_generator (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,
    input  [STAGE_WIDTH-1:0] stage,
    input  start,
    input  [STATE_WIDTH-1:0] state,
    
    // 输出：所有蝶形单元使用相同的基础地址
    output [ADDR_WIDTH-1:0] base_ram_addr,
    output [TW_ADDR_WIDTH-1:0] base_tw_addr,
    output addr_valid,
    output stage_complete
);

// 基础地址生成器
address_generator base_gen (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .stage(stage),
    .start(start),
    .state(state),
    .ram_addr(base_ram_addr),
    .tw_addr(base_tw_addr),
    .addr_valid(addr_valid),
    .stage_complete(stage_complete)
);

endmodule
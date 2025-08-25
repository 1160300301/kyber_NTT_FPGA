// kyber_ntt_top.v
// Kyber NTT顶层模块

`include "kyber_params.v"

module kyber_ntt_top (
    // 时钟和复位
    input  clk,
    input  rst_n,
    
    // 控制接口
    input  start,                                    // 开始信号
    input  [MODE_WIDTH-1:0] mode,                    // 操作模式 (NTT/INTT/PWM)
    output done,                                     // 完成信号
    output busy,                                     // 忙信号
    output error,                                    // 错误信号
    
    // 数据接口
    input  [DATA_WIDTH-1:0] data_in,                 // 输入数据
    input  [ADDR_WIDTH-1:0] data_addr,               // 数据地址
    input  data_valid,                               // 数据有效
    input  data_we,                                  // 数据写使能
    output [DATA_WIDTH-1:0] data_out,                // 输出数据
    output data_out_valid,                           // 输出数据有效
    
    // 调试接口
    output [STATE_WIDTH-1:0] debug_state,            // 当前状态
    output [STAGE_WIDTH-1:0] debug_stage,            // 当前阶段
    output [15:0] debug_cycle_count                  // 周期计数
);

// 内部信号定义

// 控制信号
wire [STATE_WIDTH-1:0] current_state;
wire [STAGE_WIDTH-1:0] current_stage;
wire load_enable, compute_enable, output_enable;
wire addr_gen_start, addr_gen_complete;
wire ping_pong_sel;
wire stage_complete;

// 地址生成信号
wire [ADDR_WIDTH-1:0] base_ram_addr;
wire [TW_ADDR_WIDTH-1:0] base_tw_addr;
wire addr_valid;

// 存储器信号
wire [DATA_WIDTH-1:0] ram_data_a_single;
wire [DATA_WIDTH-1:0] ram_data_b_single;
wire [DATA_WIDTH-1:0] ram_write_a_single;
wire [DATA_WIDTH-1:0] ram_write_b_single;
wire ram_write_enable;

// 旋转因子信号
wire [DATA_WIDTH-1:0] twiddle_single;

// 蝶形单元信号
wire [DATA_WIDTH-1:0] bf_data_a_single;
wire [DATA_WIDTH-1:0] bf_data_b_single;
wire [DATA_WIDTH-1:0] bf_twiddle_single;
wire [DATA_WIDTH-1:0] bf_result_u_single;
wire [DATA_WIDTH-1:0] bf_result_e_single;
wire bf_valid_in, bf_valid_out;

// 数据路径控制信号
wire datapath_busy, computation_done;

// 调试计数器
reg [15:0] cycle_counter;

// 子模块实例化

// 1. 顶层控制器
ntt_controller controller (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .mode(mode),
    .done(done),
    .busy(busy),
    .error(error),
    .state(current_state),
    .stage(current_stage),
    .load_enable(load_enable),
    .compute_enable(compute_enable),
    .output_enable(output_enable),
    .addr_gen_start(addr_gen_start),
    .ping_pong_sel(ping_pong_sel),
    .addr_gen_complete(addr_gen_complete),
    .butterfly_valid(bf_valid_out),
    .stage_complete(stage_complete)
);

// 2. 并行地址生成器
parallel_address_generator addr_gen (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .stage(current_stage),
    .start(addr_gen_start),
    .state(current_state),
    .base_ram_addr(base_ram_addr),
    .base_tw_addr(base_tw_addr),
    .addr_valid(addr_valid),
    .stage_complete(stage_complete)
);

// 3. 双RAM存储模块
dual_ram_storage ram_storage (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .load_enable(load_enable),
    .compute_enable(compute_enable),
    .ping_pong_sel(ping_pong_sel),
    
    // 外部接口
    .ext_din(data_in),
    .ext_addr(data_addr),
    .ext_we(data_we && data_valid),
    .ext_dout(data_out),
    
    // 计算单元接口
    .comp_din_a(ram_write_a_single),
    .comp_din_b(ram_write_b_single),
    .comp_addr(base_ram_addr),
    .comp_we(ram_write_enable),
    .comp_dout_a(ram_data_a_single),
    .comp_dout_b(ram_data_b_single)
);

// 4. 多端口旋转因子ROM
multi_port_twiddle_rom tw_rom (
    .clk(clk),
    .addr(base_tw_addr),
    .mode(mode),
    .twiddle(twiddle_single)
);

// 5. 蝶形单元阵列
butterfly_array bf_array (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .data_a_in(bf_data_a_single),
    .data_b_in(bf_data_b_single),
    .twiddle_in(bf_twiddle_single),
    .valid_in(bf_valid_in),
    .result_u_out(bf_result_u_single),
    .result_e_out(bf_result_e_single),
    .valid_out(bf_valid_out)
);

// 6. 数据路径控制器
datapath_controller datapath_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .state(current_state),
    .stage(current_stage),
    .compute_enable(compute_enable),
    .ping_pong_sel(ping_pong_sel),
    
    // 存储器接口
    .ram_data_a(ram_data_a_single),
    .ram_data_b(ram_data_b_single),
    .ram_write_a(ram_write_a_single),
    .ram_write_b(ram_write_b_single),
    .ram_write_enable(ram_write_enable),
    
    // 旋转因子接口
    .twiddle(twiddle_single),
    
    // 蝶形单元接口
    .bf_data_a(bf_data_a_single),
    .bf_data_b(bf_data_b_single),
    .bf_twiddle(bf_twiddle_single),
    .bf_valid_in(bf_valid_in),
    .bf_result_u(bf_result_u_single),
    .bf_result_e(bf_result_e_single),
    .bf_valid_out(bf_valid_out),
    
    // 状态输出
    .datapath_busy(datapath_busy),
    .computation_done(computation_done)
);

// 输出控制逻辑
assign data_out_valid = output_enable && addr_valid;
assign addr_gen_complete = stage_complete; // 连接

// 调试信号输出
assign debug_state = current_state;
assign debug_stage = current_stage;
assign debug_cycle_count = cycle_counter;

// 周期计数器（用于调试和性能测量）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cycle_counter <= 0;
    end else begin
        if (current_state != STATE_IDLE) begin
            cycle_counter <= cycle_counter + 1;
        end else begin
            cycle_counter <= 0;
        end
    end
end

// 时钟域和复位同步逻辑
reg rst_n_sync;
reg [1:0] reset_sync;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reset_sync <= 2'b00;
        rst_n_sync <= 0;
    end else begin
        reset_sync <= {reset_sync[0], 1'b1};
        rst_n_sync <= reset_sync[1];
    end
end

// 性能监测器（可选）
reg [15:0] ntt_latency;
reg [15:0] max_latency;

always @(posedge clk or negedge rst_n_sync) begin
    if (!rst_n_sync) begin
        ntt_latency <= 0;
        max_latency <= 0;
    end else begin
        if (start && current_state == STATE_IDLE) begin
            ntt_latency <= 0;
        end else if (current_state != STATE_IDLE) begin
            ntt_latency <= ntt_latency + 1;
        end
        
        if (done && ntt_latency > max_latency) begin
            max_latency <= ntt_latency;
        end
    end
end

endmodule

// 测试包装器（移除数组端口）
module kyber_ntt_wrapper (
    input  clk,
    input  rst_n,
    input  start_ntt,                    // 启动NTT
    input  start_intt,                   // 启动INTT
    
    // 数据接口（移除数组）
    input  [DATA_WIDTH-1:0] data_input,  // 单个输入数据
    input  [ADDR_WIDTH-1:0] input_addr,  // 输入地址
    input  input_valid,                  // 输入有效
    output [DATA_WIDTH-1:0] data_output, // 单个输出数据
    output [ADDR_WIDTH-1:0] output_addr, // 输出地址
    output output_valid,                 // 输出有效
    
    output computation_done,             // 计算完成
    output [15:0] cycle_count           // 周期计数
);

// 内部信号
reg [MODE_WIDTH-1:0] operation_mode;
reg start_operation;
wire ntt_done, ntt_busy, ntt_error;
reg [ADDR_WIDTH-1:0] addr_counter;
reg [1:0] wrapper_state;

// 操作模式选择
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        operation_mode <= MODE_NTT;
        start_operation <= 0;
        wrapper_state <= 0;
        addr_counter <= 0;
    end else begin
        case (wrapper_state)
            0: begin // 等待启动
                if (start_ntt) begin
                    operation_mode <= MODE_NTT;
                    start_operation <= 1;
                    wrapper_state <= 1;
                end else if (start_intt) begin
                    operation_mode <= MODE_INTT;
                    start_operation <= 1;
                    wrapper_state <= 1;
                end
            end
            1: begin // 运行中
                start_operation <= 0;
                if (ntt_done) begin
                    wrapper_state <= 0;
                end
            end
        endcase
    end
end

// NTT核心实例
kyber_ntt_top ntt_core (
    .clk(clk),
    .rst_n(rst_n),
    .start(start_operation),
    .mode(operation_mode),
    .done(ntt_done),
    .busy(ntt_busy),
    .error(ntt_error),
    .data_in(data_input),
    .data_addr(input_addr),
    .data_valid(input_valid),
    .data_we(input_valid),
    .data_out(data_output),
    .data_out_valid(output_valid),
    .debug_cycle_count(cycle_count)
);

assign computation_done = ntt_done;
assign output_addr = addr_counter;

endmodule
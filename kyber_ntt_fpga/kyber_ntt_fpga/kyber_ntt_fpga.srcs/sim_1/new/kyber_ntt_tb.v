// kyber_ntt_tb.v
// Kyber NTT模块测试平台

`include "kyber_params.v"
`timescale 1ns / 1ps

module kyber_ntt_tb();

// 测试平台参数
parameter CLK_PERIOD = 10;  // 100MHz时钟
parameter TEST_VECTORS = 4; // 测试向量数量

// 测试信号
reg clk;
reg rst_n;
reg start;
reg [MODE_WIDTH-1:0] mode;
reg [DATA_WIDTH-1:0] data_in;
reg [ADDR_WIDTH-1:0] data_addr;
reg data_valid;
reg data_we;

wire done;
wire busy;
wire error;
wire [DATA_WIDTH-1:0] data_out;
wire data_out_valid;
wire [STATE_WIDTH-1:0] debug_state;
wire [STAGE_WIDTH-1:0] debug_stage;
wire [15:0] debug_cycle_count;

// 测试数据存储
reg [DATA_WIDTH-1:0] test_input [0:KYBER_N-1];
reg [DATA_WIDTH-1:0] test_output [0:KYBER_N-1];
reg [DATA_WIDTH-1:0] expected_output [0:KYBER_N-1];
reg [DATA_WIDTH-1:0] golden_model_result [0:KYBER_N-1];

// 测试控制变量
integer i, j, test_case;
integer error_count;
integer pass_count;
reg [31:0] start_time, end_time;
reg test_passed;

// DUT实例化
kyber_ntt_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .mode(mode),
    .done(done),
    .busy(busy),
    .error(error),
    .data_in(data_in),
    .data_addr(data_addr),
    .data_valid(data_valid),
    .data_we(data_we),
    .data_out(data_out),
    .data_out_valid(data_out_valid),
    .debug_state(debug_state),
    .debug_stage(debug_stage),
    .debug_cycle_count(debug_cycle_count)
);

// 时钟生成
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// 主测试流程
initial begin
    $display("========================================");
    $display("Kyber NTT Hardware Accelerator Test");
    $display("========================================");
    
    // 初始化
    initialize_signals();
    
    // 复位序列
    reset_sequence();
    
    // 运行测试用例
    for (test_case = 0; test_case < TEST_VECTORS; test_case++) begin
        $display("\n--- Test Case %0d ---", test_case + 1);
        
        // NTT测试
        $display("Testing NTT Transform...");
        generate_test_vector(test_case);
        run_ntt_test();
        
        // INTT测试
        $display("Testing INTT Transform...");
        run_intt_test();
        
        // 验证结果
        verify_results();
    end
    
    // 性能测试
    $display("\n--- Performance Test ---");
    performance_test();
    
    // 测试总结
    print_test_summary();
    
    $finish;
end

// 初始化信号
task initialize_signals;
    begin
        rst_n = 1'b0;
        start = 1'b0;
        mode = MODE_NTT;
        data_in = 16'h0000;
        data_addr = 8'h00;
        data_valid = 1'b0;
        data_we = 1'b0;
        error_count = 0;
        pass_count = 0;
        test_passed = 1'b1;
    end
endtask

// 复位序列
task reset_sequence;
    begin
        $display("Performing Reset...");
        rst_n = 1'b0;
        repeat(10) @(posedge clk);
        rst_n = 1'b1;
        repeat(5) @(posedge clk);
        $display("Reset Complete");
    end
endtask

// 生成测试向量
task generate_test_vector;
    input integer test_id;
    integer i;
    begin
        case (test_id)
            0: begin // 全零测试
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = 16'h0000;
                end
            end
            
            1: begin // 单位脉冲测试
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = (i == 0) ? 16'h0001 : 16'h0000;
                end
            end
            
            2: begin // 随机数据测试
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = $random % KYBER_Q;
                end
            end
            
            3: begin // 边界值测试
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = (i % 2 == 0) ? (KYBER_Q - 1) : 1;
                end
            end
            
            default: begin
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = i % KYBER_Q;
                end
            end
        endcase
        
        $display("Generated test vector %0d", test_id);
    end
endtask

// 运行NTT测试
task run_ntt_test;
    integer i;
    begin
        $display("Loading input data...");
        
        // 加载输入数据
        for (i = 0; i < KYBER_N; i++) begin
            @(posedge clk);
            data_addr = i;
            data_in = test_input[i];
            data_valid = 1'b1;
            data_we = 1'b1;
        end
        
        @(posedge clk);
        data_valid = 1'b0;
        data_we = 1'b0;
        
        // 启动NTT变换
        $display("Starting NTT computation...");
        start_time = $time;
        mode = MODE_NTT;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        
        // 等待完成
        wait(done == 1'b1);
        end_time = $time;
        
        $display("NTT completed in %0d cycles", debug_cycle_count);
        $display("Computation time: %0d ns", end_time - start_time);
        
        // 读取结果
        $display("Reading NTT results...");
        for (i = 0; i < KYBER_N; i++) begin
            @(posedge clk);
            data_addr = i;
            if (data_out_valid) begin
                test_output[i] = data_out;
            end
        end
    end
endtask

// 运行INTT测试
task run_intt_test;
    integer i;
    begin
        $display("Starting INTT computation...");
        
        // 使用NTT的输出作为INTT的输入
        for (i = 0; i < KYBER_N; i++) begin
            @(posedge clk);
            data_addr = i;
            data_in = test_output[i];
            data_valid = 1'b1;
            data_we = 1'b1;
        end
        
        @(posedge clk);
        data_valid = 1'b0;
        data_we = 1'b0;
        
        // 启动INTT变换
        start_time = $time;
        mode = MODE_INTT;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        
        // 等待完成
        wait(done == 1'b1);
        end_time = $time;
        
        $display("INTT completed in %0d cycles", debug_cycle_count);
        
        // 读取最终结果
        for (i = 0; i < KYBER_N; i++) begin
            @(posedge clk);
            data_addr = i;
            if (data_out_valid) begin
                expected_output[i] = data_out;
            end
        end
    end
endtask

// 验证结果
task verify_results;
    integer i;
    integer errors = 0;
    integer tolerance = 1; // 允许的误差范围
    begin
        $display("Verifying NTT -> INTT results...");
        
        for (i = 0; i < KYBER_N; i++) begin
            // 检查INTT(NTT(x))是否等于原始输入
            if (abs_diff(expected_output[i], test_input[i]) > tolerance) begin
                $display("ERROR at index %0d: expected %0d, got %0d", 
                        i, test_input[i], expected_output[i]);
                errors++;
            end
        end
        
        if (errors == 0) begin
            $display("PASS: All results verified correctly");
            pass_count++;
        end else begin
            $display("FAIL: %0d errors found", errors);
            error_count += errors;
            test_passed = 1'b0;
        end
    end
endtask

// 性能测试
task performance_test;
    integer i, cycles;
    reg [31:0] total_cycles = 0;
    reg [31:0] avg_cycles;
    begin
        $display("Running performance benchmarks...");
        
        for (i = 0; i < 10; i++) begin
            generate_test_vector($random % 4);
            
            // NTT性能测试
            @(posedge clk);
            mode = MODE_NTT;
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;
            
            wait(done == 1'b1);
            cycles = debug_cycle_count;
            total_cycles += cycles;
            
            $display("NTT Run %0d: %0d cycles", i+1, cycles);
        end
        
        avg_cycles = total_cycles / 10;
        $display("Average NTT cycles: %0d", avg_cycles);
        
        if (avg_cycles <= 250) begin
            $display("PASS: Performance target met (≤250 cycles)");
            pass_count++;
        end else begin
            $display("FAIL: Performance target not met (>250 cycles)");
            error_count++;
        end
    end
endtask

// 打印测试总结
task print_test_summary;
    begin
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", TEST_VECTORS + 1);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", error_count);
        
        if (error_count == 0) begin
            $display("Result: ALL TESTS PASSED!");
        end else begin
            $display("Result: TESTS FAILED!");
        end
        
        $display("========================================");
    end
endtask

// 辅助函数：计算绝对差值
function integer abs_diff;
    input [DATA_WIDTH-1:0] a, b;
    begin
        if (a >= b) begin
            abs_diff = a - b;
        end else begin
            abs_diff = b - a;
        end
    end
endfunction

// 监控器：检测错误状态
always @(posedge clk) begin
    if (error) begin
        $display("ERROR: Hardware error detected at time %0t", $time);
        $display("State: %0d, Stage: %0d", debug_state, debug_stage);
    end
end

// 超时监控器
initial begin
    #(CLK_PERIOD * 100000); // 100000个时钟周期超时
    $display("ERROR: Test timeout!");
    $finish;
end

endmodule
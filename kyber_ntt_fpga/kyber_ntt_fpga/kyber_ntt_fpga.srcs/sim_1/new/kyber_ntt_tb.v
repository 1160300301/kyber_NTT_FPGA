// kyber_ntt_tb.v
// Kyber NTTģ�����ƽ̨

`include "kyber_params.v"
`timescale 1ns / 1ps

module kyber_ntt_tb();

// ����ƽ̨����
parameter CLK_PERIOD = 10;  // 100MHzʱ��
parameter TEST_VECTORS = 4; // ������������

// �����ź�
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

// �������ݴ洢
reg [DATA_WIDTH-1:0] test_input [0:KYBER_N-1];
reg [DATA_WIDTH-1:0] test_output [0:KYBER_N-1];
reg [DATA_WIDTH-1:0] expected_output [0:KYBER_N-1];
reg [DATA_WIDTH-1:0] golden_model_result [0:KYBER_N-1];

// ���Կ��Ʊ���
integer i, j, test_case;
integer error_count;
integer pass_count;
reg [31:0] start_time, end_time;
reg test_passed;

// DUTʵ����
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

// ʱ������
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ����������
initial begin
    $display("========================================");
    $display("Kyber NTT Hardware Accelerator Test");
    $display("========================================");
    
    // ��ʼ��
    initialize_signals();
    
    // ��λ����
    reset_sequence();
    
    // ���в�������
    for (test_case = 0; test_case < TEST_VECTORS; test_case++) begin
        $display("\n--- Test Case %0d ---", test_case + 1);
        
        // NTT����
        $display("Testing NTT Transform...");
        generate_test_vector(test_case);
        run_ntt_test();
        
        // INTT����
        $display("Testing INTT Transform...");
        run_intt_test();
        
        // ��֤���
        verify_results();
    end
    
    // ���ܲ���
    $display("\n--- Performance Test ---");
    performance_test();
    
    // �����ܽ�
    print_test_summary();
    
    $finish;
end

// ��ʼ���ź�
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

// ��λ����
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

// ���ɲ�������
task generate_test_vector;
    input integer test_id;
    integer i;
    begin
        case (test_id)
            0: begin // ȫ�����
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = 16'h0000;
                end
            end
            
            1: begin // ��λ�������
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = (i == 0) ? 16'h0001 : 16'h0000;
                end
            end
            
            2: begin // ������ݲ���
                for (i = 0; i < KYBER_N; i++) begin
                    test_input[i] = $random % KYBER_Q;
                end
            end
            
            3: begin // �߽�ֵ����
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

// ����NTT����
task run_ntt_test;
    integer i;
    begin
        $display("Loading input data...");
        
        // ������������
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
        
        // ����NTT�任
        $display("Starting NTT computation...");
        start_time = $time;
        mode = MODE_NTT;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        
        // �ȴ����
        wait(done == 1'b1);
        end_time = $time;
        
        $display("NTT completed in %0d cycles", debug_cycle_count);
        $display("Computation time: %0d ns", end_time - start_time);
        
        // ��ȡ���
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

// ����INTT����
task run_intt_test;
    integer i;
    begin
        $display("Starting INTT computation...");
        
        // ʹ��NTT�������ΪINTT������
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
        
        // ����INTT�任
        start_time = $time;
        mode = MODE_INTT;
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
        
        // �ȴ����
        wait(done == 1'b1);
        end_time = $time;
        
        $display("INTT completed in %0d cycles", debug_cycle_count);
        
        // ��ȡ���ս��
        for (i = 0; i < KYBER_N; i++) begin
            @(posedge clk);
            data_addr = i;
            if (data_out_valid) begin
                expected_output[i] = data_out;
            end
        end
    end
endtask

// ��֤���
task verify_results;
    integer i;
    integer errors = 0;
    integer tolerance = 1; // �������Χ
    begin
        $display("Verifying NTT -> INTT results...");
        
        for (i = 0; i < KYBER_N; i++) begin
            // ���INTT(NTT(x))�Ƿ����ԭʼ����
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

// ���ܲ���
task performance_test;
    integer i, cycles;
    reg [31:0] total_cycles = 0;
    reg [31:0] avg_cycles;
    begin
        $display("Running performance benchmarks...");
        
        for (i = 0; i < 10; i++) begin
            generate_test_vector($random % 4);
            
            // NTT���ܲ���
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
            $display("PASS: Performance target met (��250 cycles)");
            pass_count++;
        end else begin
            $display("FAIL: Performance target not met (>250 cycles)");
            error_count++;
        end
    end
endtask

// ��ӡ�����ܽ�
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

// ����������������Բ�ֵ
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

// �������������״̬
always @(posedge clk) begin
    if (error) begin
        $display("ERROR: Hardware error detected at time %0t", $time);
        $display("State: %0d, Stage: %0d", debug_state, debug_stage);
    end
end

// ��ʱ�����
initial begin
    #(CLK_PERIOD * 100000); // 100000��ʱ�����ڳ�ʱ
    $display("ERROR: Test timeout!");
    $finish;
end

endmodule
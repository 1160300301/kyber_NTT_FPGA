// kyber_ntt_top.v
// Kyber NTT����ģ��

`include "kyber_params.v"

module kyber_ntt_top (
    // ʱ�Ӻ͸�λ
    input  clk,
    input  rst_n,
    
    // ���ƽӿ�
    input  start,                                    // ��ʼ�ź�
    input  [MODE_WIDTH-1:0] mode,                    // ����ģʽ (NTT/INTT/PWM)
    output done,                                     // ����ź�
    output busy,                                     // æ�ź�
    output error,                                    // �����ź�
    
    // ���ݽӿ�
    input  [DATA_WIDTH-1:0] data_in,                 // ��������
    input  [ADDR_WIDTH-1:0] data_addr,               // ���ݵ�ַ
    input  data_valid,                               // ������Ч
    input  data_we,                                  // ����дʹ��
    output [DATA_WIDTH-1:0] data_out,                // �������
    output data_out_valid,                           // ���������Ч
    
    // ���Խӿ�
    output [STATE_WIDTH-1:0] debug_state,            // ��ǰ״̬
    output [STAGE_WIDTH-1:0] debug_stage,            // ��ǰ�׶�
    output [15:0] debug_cycle_count                  // ���ڼ���
);

// �ڲ��źŶ���

// �����ź�
wire [STATE_WIDTH-1:0] current_state;
wire [STAGE_WIDTH-1:0] current_stage;
wire load_enable, compute_enable, output_enable;
wire addr_gen_start, addr_gen_complete;
wire ping_pong_sel;
wire stage_complete;

// ��ַ�����ź�
wire [ADDR_WIDTH-1:0] base_ram_addr;
wire [TW_ADDR_WIDTH-1:0] base_tw_addr;
wire addr_valid;

// �洢���ź�
wire [DATA_WIDTH-1:0] ram_data_a_single;
wire [DATA_WIDTH-1:0] ram_data_b_single;
wire [DATA_WIDTH-1:0] ram_write_a_single;
wire [DATA_WIDTH-1:0] ram_write_b_single;
wire ram_write_enable;

// ��ת�����ź�
wire [DATA_WIDTH-1:0] twiddle_single;

// ���ε�Ԫ�ź�
wire [DATA_WIDTH-1:0] bf_data_a_single;
wire [DATA_WIDTH-1:0] bf_data_b_single;
wire [DATA_WIDTH-1:0] bf_twiddle_single;
wire [DATA_WIDTH-1:0] bf_result_u_single;
wire [DATA_WIDTH-1:0] bf_result_e_single;
wire bf_valid_in, bf_valid_out;

// ����·�������ź�
wire datapath_busy, computation_done;

// ���Լ�����
reg [15:0] cycle_counter;

// ��ģ��ʵ����

// 1. ���������
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

// 2. ���е�ַ������
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

// 3. ˫RAM�洢ģ��
dual_ram_storage ram_storage (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .load_enable(load_enable),
    .compute_enable(compute_enable),
    .ping_pong_sel(ping_pong_sel),
    
    // �ⲿ�ӿ�
    .ext_din(data_in),
    .ext_addr(data_addr),
    .ext_we(data_we && data_valid),
    .ext_dout(data_out),
    
    // ���㵥Ԫ�ӿ�
    .comp_din_a(ram_write_a_single),
    .comp_din_b(ram_write_b_single),
    .comp_addr(base_ram_addr),
    .comp_we(ram_write_enable),
    .comp_dout_a(ram_data_a_single),
    .comp_dout_b(ram_data_b_single)
);

// 4. ��˿���ת����ROM
multi_port_twiddle_rom tw_rom (
    .clk(clk),
    .addr(base_tw_addr),
    .mode(mode),
    .twiddle(twiddle_single)
);

// 5. ���ε�Ԫ����
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

// 6. ����·��������
datapath_controller datapath_ctrl (
    .clk(clk),
    .rst_n(rst_n),
    .mode(mode),
    .state(current_state),
    .stage(current_stage),
    .compute_enable(compute_enable),
    .ping_pong_sel(ping_pong_sel),
    
    // �洢���ӿ�
    .ram_data_a(ram_data_a_single),
    .ram_data_b(ram_data_b_single),
    .ram_write_a(ram_write_a_single),
    .ram_write_b(ram_write_b_single),
    .ram_write_enable(ram_write_enable),
    
    // ��ת���ӽӿ�
    .twiddle(twiddle_single),
    
    // ���ε�Ԫ�ӿ�
    .bf_data_a(bf_data_a_single),
    .bf_data_b(bf_data_b_single),
    .bf_twiddle(bf_twiddle_single),
    .bf_valid_in(bf_valid_in),
    .bf_result_u(bf_result_u_single),
    .bf_result_e(bf_result_e_single),
    .bf_valid_out(bf_valid_out),
    
    // ״̬���
    .datapath_busy(datapath_busy),
    .computation_done(computation_done)
);

// ��������߼�
assign data_out_valid = output_enable && addr_valid;
assign addr_gen_complete = stage_complete; // ����

// �����ź����
assign debug_state = current_state;
assign debug_stage = current_stage;
assign debug_cycle_count = cycle_counter;

// ���ڼ����������ڵ��Ժ����ܲ�����
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

// ʱ����͸�λͬ���߼�
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

// ���ܼ��������ѡ��
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

// ���԰�װ�����Ƴ�����˿ڣ�
module kyber_ntt_wrapper (
    input  clk,
    input  rst_n,
    input  start_ntt,                    // ����NTT
    input  start_intt,                   // ����INTT
    
    // ���ݽӿڣ��Ƴ����飩
    input  [DATA_WIDTH-1:0] data_input,  // ������������
    input  [ADDR_WIDTH-1:0] input_addr,  // �����ַ
    input  input_valid,                  // ������Ч
    output [DATA_WIDTH-1:0] data_output, // �����������
    output [ADDR_WIDTH-1:0] output_addr, // �����ַ
    output output_valid,                 // �����Ч
    
    output computation_done,             // �������
    output [15:0] cycle_count           // ���ڼ���
);

// �ڲ��ź�
reg [MODE_WIDTH-1:0] operation_mode;
reg start_operation;
wire ntt_done, ntt_busy, ntt_error;
reg [ADDR_WIDTH-1:0] addr_counter;
reg [1:0] wrapper_state;

// ����ģʽѡ��
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        operation_mode <= MODE_NTT;
        start_operation <= 0;
        wrapper_state <= 0;
        addr_counter <= 0;
    end else begin
        case (wrapper_state)
            0: begin // �ȴ�����
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
            1: begin // ������
                start_operation <= 0;
                if (ntt_done) begin
                    wrapper_state <= 0;
                end
            end
        endcase
    end
end

// NTT����ʵ��
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
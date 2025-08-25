// ntt_controller.v
// NTT���������������������������

`include "kyber_params.v"

module ntt_controller (
    input  clk,
    input  rst_n,
    
    // �ⲿ���ƽӿ�
    input  start,                        // ��ʼ�ź�
    input  [MODE_WIDTH-1:0] mode,        // ����ģʽ
    output reg done,                     // ����ź�
    output reg busy,                     // æ�ź�
    output reg error,                    // �����ź�
    
    // �ڲ�ģ������ź�
    output reg [STATE_WIDTH-1:0] state,     // ��ǰ״̬
    output reg [STAGE_WIDTH-1:0] stage,     // ��ǰ�׶�
    output reg load_enable,                 // ���ݼ���ʹ��
    output reg compute_enable,              // ����ʹ��
    output reg output_enable,               // ���ʹ��
    output reg addr_gen_start,              // ��ַ����������
    output reg ping_pong_sel,               // ƹ�һ���ѡ��
    
    // ״̬�����ź�
    input  addr_gen_complete,               // ��ַ�������
    input  butterfly_valid,                 // ���ε�Ԫ�����Ч
    input  stage_complete                   // �׶�����ź�
);

// �ڲ��������ͼĴ���
reg [7:0] cycle_counter;                // ���ڼ�����
reg [STATE_WIDTH-1:0] next_state;       // ��һ״̬
reg [STAGE_WIDTH-1:0] stage_counter;    // �׶μ�����
reg operation_complete;                 // ������ɱ�־

// ���׶������ʱ��������
wire [7:0] load_cycles;
wire [7:0] compute_cycles; 
wire [7:0] output_cycles;

assign load_cycles = LOAD_CYCLES;
assign compute_cycles = STAGE_CYCLES;
assign output_cycles = OUTPUT_CYCLES;

// ��״̬��
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
                
                // ����ƹ�һ����л�
                if (cycle_counter == 0) begin
                    ping_pong_sel <= ~ping_pong_sel;
                end
                
                if (stage_complete) begin
                    cycle_counter <= 0;
                    stage_counter <= stage_counter + 1;
                    
                    // ����Ƿ�������н׶�
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

// ��һ״̬�߼�
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

// ��ʱ��ģ�飬���ھ�ȷ���Ƹ��׶ε�ʱ��
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

// ����״̬���ó�ʱֵ
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
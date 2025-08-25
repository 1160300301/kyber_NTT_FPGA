// datapath_controller.v
// ����·��������

`include "kyber_params.v"

module datapath_controller (
    input  clk,
    input  rst_n,
    
    // �����ź�
    input  [MODE_WIDTH-1:0] mode,           // ����ģʽ
    input  [STATE_WIDTH-1:0] state,         // ��ǰ״̬
    input  [STAGE_WIDTH-1:0] stage,         // ��ǰ�׶�
    input  compute_enable,                  // ����ʹ��
    input  ping_pong_sel,                   // ƹ��ѡ��
    
    // �洢���ӿڣ������źŶ������飩
    input  [DATA_WIDTH-1:0] ram_data_a,     // RAM A����
    input  [DATA_WIDTH-1:0] ram_data_b,     // RAM B����
    output reg [DATA_WIDTH-1:0] ram_write_a,    // RAM Aд����
    output reg [DATA_WIDTH-1:0] ram_write_b,    // RAM Bд����
    output reg ram_write_enable,                // RAMдʹ��
    
    // ��ת���ӽӿ�
    input  [DATA_WIDTH-1:0] twiddle,        // ��ת����
    
    // ���ε�Ԫ�ӿ�
    output reg [DATA_WIDTH-1:0] bf_data_a,      // ���ε�Ԫ����A
    output reg [DATA_WIDTH-1:0] bf_data_b,      // ���ε�Ԫ����B
    output reg [DATA_WIDTH-1:0] bf_twiddle,     // ���ε�Ԫ��ת����
    output reg bf_valid_in,                     // ���ε�Ԫ������Ч
    input  [DATA_WIDTH-1:0] bf_result_u,    // ���ε�Ԫ���U
    input  [DATA_WIDTH-1:0] bf_result_e,    // ���ε�Ԫ���E
    input  bf_valid_out,                    // ���ε�Ԫ�����Ч
    
    // ״̬���
    output reg datapath_busy,               // ����·��æ�ź�
    output reg computation_done             // ��������ź�
);

// �ڲ��Ĵ��� - ��ѭ�����������Ƶ�always����
integer i; // ѭ�����������Ƶ�����

reg [2:0] pipeline_stage;                  // ��ˮ�߽׶�
reg [DATA_WIDTH-1:0] data_buffer_a;        // ���ݻ���A����Ϊ������
reg [DATA_WIDTH-1:0] data_buffer_b;        // ���ݻ���B����Ϊ������
reg [DATA_WIDTH-1:0] twiddle_buffer;       // ��ת���ӻ��壨��Ϊ������
reg valid_buffer [0:2];                    // ��Ч�ź���ˮ��

// ����ѡ���߼�
always @(*) begin
    case (state)
        STATE_COMPUTE: begin
            if (ping_pong_sel) begin
                // ��RAM A��ȡ��д��RAM B
                bf_data_a = ram_data_a;
                bf_data_b = ram_data_a; // �򻯣�ʹ����ͬ����
            end else begin
                // ��RAM B��ȡ��д��RAM A
                bf_data_a = ram_data_b;
                bf_data_b = ram_data_b; // �򻯣�ʹ����ͬ����
            end
            // ��ת���ӷ���
            bf_twiddle = twiddle;
            // ������Ч�źſ���
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

// ���д���߼�
always @(*) begin
    if (bf_valid_out) begin
        if (ping_pong_sel) begin
            // д��RAM B
            ram_write_b = bf_result_u;
            ram_write_a = 0; // ��д��RAM A
        end else begin
            // д��RAM A
            ram_write_a = bf_result_u;
            ram_write_b = 0; // ��д��RAM B
        end
        ram_write_enable = 1;
    end else begin
        ram_write_a = 0;
        ram_write_b = 0;
        ram_write_enable = 0;
    end
end

// ��ˮ�߿���
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pipeline_stage <= 0;
        datapath_busy <= 0;
        computation_done <= 0;
        // ʹ�ô�ͳ��forѭ����ʽ
        for (i = 0; i < 3; i = i + 1) begin
            valid_buffer[i] <= 0;
        end
    end else begin
        // ��Ч�ź���ˮ��
        valid_buffer[0] <= bf_valid_in;
        valid_buffer[1] <= valid_buffer[0];
        valid_buffer[2] <= valid_buffer[1];
        
        // ����·��״̬����
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
                        0: begin // ����׼���׶�
                            if (bf_valid_in) begin
                                pipeline_stage <= 1;
                            end
                        end
                        
                        1: begin // ����׶�
                            if (valid_buffer[1]) begin
                                pipeline_stage <= 2;
                            end
                        end
                        
                        2: begin // д�ؽ׶�
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

// ���ݻ��������ѡ����ˮ���Ż���
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

// �������ŵ�Ԫ
module data_reorder_unit (
    input  clk,
    input  rst_n,
    input  [STAGE_WIDTH-1:0] stage,                    // ��ǰ�׶�
    input  [DATA_WIDTH-1:0] data_in,                   // �������ݣ���Ϊ������
    output reg [DATA_WIDTH-1:0] data_out               // ���ź����ݣ���Ϊ������
);

// ����NTT�׶ν�����������
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= 0;
    end else begin
        case (stage)
            0, 1, 2: begin // ���ڽ׶Σ��򵥴���
                data_out <= data_in;
            end
            
            3, 4: begin // ���ڽ׶Σ��򵥴���
                data_out <= data_in;
            end
            
            5, 6: begin // ���ڽ׶Σ��򵥴���
                data_out <= data_in;
            end
            
            default: begin
                data_out <= data_in;
            end
        endcase
    end
end

endmodule
// address_generator.v  
// ��ַ���ɵ�Ԫ

`include "kyber_params.v"

module address_generator (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,        // ����ģʽ
    input  [STAGE_WIDTH-1:0] stage,      // ��ǰ����׶�
    input  start,                        // ��ʼ�ź�
    input  [STATE_WIDTH-1:0] state,      // ��ǰ״̬
    
    // �洢�����ʵ�ַ
    output reg [ADDR_WIDTH-1:0] ram_addr,     // RAM���ʵ�ַ
    output reg [TW_ADDR_WIDTH-1:0] tw_addr,   // ��ת���ӵ�ַ
    output reg addr_valid,                    // ��ַ��Ч�ź�
    output reg stage_complete                 // �׶�����ź�
);

// �ڲ�������
reg [ADDR_WIDTH-1:0] base_counter;       // ����������
reg [4:0] cycle_counter;                 // ���ڼ�����
reg [STAGE_WIDTH-1:0] current_stage;     // ��ǰ�׶�
reg [7:0] group_counter;                 // ���������
reg [3:0] element_counter;               // Ԫ�ؼ�����

// ÿ�׶εĲ���
wire [7:0] stage_len;                    // ��ǰ�׶γ���
wire [7:0] stage_groups;                 // ��ǰ�׶η�����
wire [TW_ADDR_WIDTH-1:0] tw_base;        // ��ת���ӻ�ַ

// ���ݽ׶μ������
assign stage_len = 128 >> stage;         // len = 128, 64, 32, 16, 8, 4, 2
assign stage_groups = 128 / stage_len;   // ��������
assign tw_base = (1 << stage) - 1;      // ��ת���ӻ�ַ

// ��ַ�������߼�
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
                // ���ݼ��ؽ׶Σ�˳���ַ����
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
                // ����׶Σ�����NTT/INTT���ɲ�ͬ�ķ���ģʽ
                stage_complete <= 0;
                
                if (start) begin
                    case (mode)
                        MODE_NTT, MODE_INTT: begin
                            // ˳����ʣ���������Ԥ���ţ�����Ҫ���ӵ�λ��ת
                            if (cycle_counter < STAGE_CYCLES) begin
                                // ����˳���ַ
                                ram_addr <= base_counter;
                                
                                // ��ת���ӵ�ַ����
                                if (mode == MODE_NTT) begin
                                    tw_addr <= tw_base + group_counter;
                                end else begin // MODE_INTT
                                    tw_addr <= tw_base - group_counter;
                                end
                                
                                // ���¼�����
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
                                
                                // ���׶��Ƿ����
                                if (cycle_counter == STAGE_CYCLES - 1) begin
                                    stage_complete <= 1;
                                    cycle_counter <= 0;
                                    base_counter <= 0;
                                    current_stage <= current_stage + 1;
                                end
                            end
                        end
                        
                        MODE_PWM: begin
                            // ���ģʽ����˳�����
                            if (base_counter < KYBER_N) begin
                                ram_addr <= base_counter;
                                tw_addr <= 0; // ��˲���Ҫ��ת����
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
                // ����׶Σ�˳�����
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
                // ����״̬
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

// Ϊ8�����е��ε�Ԫ�ṩ��ͬ�ĵ�ַ
module parallel_address_generator (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,
    input  [STAGE_WIDTH-1:0] stage,
    input  start,
    input  [STATE_WIDTH-1:0] state,
    
    // ��������е��ε�Ԫʹ����ͬ�Ļ�����ַ
    output [ADDR_WIDTH-1:0] base_ram_addr,
    output [TW_ADDR_WIDTH-1:0] base_tw_addr,
    output addr_valid,
    output stage_complete
);

// ������ַ������
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
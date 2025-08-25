// butterfly_unit.v
// �������㵥Ԫ

`include "kyber_params.v"

module butterfly_unit (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,        // ����ģʽ
    input  [DATA_WIDTH-1:0] data_a,      // ��������A
    input  [DATA_WIDTH-1:0] data_b,      // ��������B
    input  [DATA_WIDTH-1:0] twiddle,     // ��ת����
    input  valid_in,                     // ������Ч�ź�
    output reg [DATA_WIDTH-1:0] result_u, // ������U
    output reg [DATA_WIDTH-1:0] result_e, // ������E
    output reg valid_out                 // �����Ч�ź�
);

// �ڲ��ź�
wire [DATA_WIDTH-1:0] mul_result;
wire [DATA_WIDTH-1:0] add_result;
wire [DATA_WIDTH-1:0] sub_result;
reg  [DATA_WIDTH-1:0] temp_a, temp_b, temp_tw;
reg  [DATA_WIDTH-1:0] intermediate;

// ģ�˷���ʵ��
mod_multiplier mul_inst (
    .a(temp_b),
    .b(temp_tw),
    .result(mul_result)
);

// ģ�ӷ���ʵ��
mod_adder add_inst (
    .a(temp_a),
    .b(intermediate),
    .result(add_result)
);

// ģ������ʵ��
mod_subtractor sub_inst (
    .a(temp_a),
    .b(intermediate),
    .result(sub_result)
);

// ���������߼�
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_u <= 0;
        result_e <= 0;
        valid_out <= 0;
        temp_a <= 0;
        temp_b <= 0;
        temp_tw <= 0;
        intermediate <= 0;
    end else begin
        if (valid_in) begin
            temp_a <= data_a;
            temp_b <= data_b;
            temp_tw <= twiddle;
            
            case (mode)
                MODE_NTT: begin
                    // NTTģʽ: U = A + TW*B, E = A - TW*B
                    intermediate <= mul_result; // TW * B
                    result_u <= add_result;     // A + TW*B
                    result_e <= sub_result;     // A - TW*B
                end
                
                MODE_INTT: begin
                    // INTTģʽ: U = A + B, E = TW * (A - B)
                    if (valid_out) begin // �ڶ�������
                        intermediate <= mul_result; // TW * (A - B)
                        result_e <= mul_result;
                    end else begin // ��һ������
                        intermediate <= sub_result; // A - B
                        result_u <= add_result;     // A + B
                    end
                end
                
                MODE_PWM: begin
                    // ���ģʽ������Kyber��Ҫ���⴦����ζ���ʽ
                    // �����Ϊ��׼ģ��
                    result_u <= mul_result;     // A * B
                    result_e <= 0;              // δʹ��
                end
                
                default: begin
                    result_u <= 0;
                    result_e <= 0;
                end
            endcase
            
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end
end

endmodule

// 8�����е��ε�Ԫ����ģ��
module butterfly_array (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,
    
    // �ӿڣ����е�Ԫʹ����ͬ����������
    input  [DATA_WIDTH-1:0] data_a_in,
    input  [DATA_WIDTH-1:0] data_b_in, 
    input  [DATA_WIDTH-1:0] twiddle_in,
    input  valid_in,
    
    // �����ֻ�����һ����Ԫ�Ľ����Ϊ����
    output [DATA_WIDTH-1:0] result_u_out,
    output [DATA_WIDTH-1:0] result_e_out,
    output valid_out
);

// �ڲ��ź�����
wire [DATA_WIDTH-1:0] bf_result_u [0:BUTTERFLY_NUM-1];
wire [DATA_WIDTH-1:0] bf_result_e [0:BUTTERFLY_NUM-1];
wire [BUTTERFLY_NUM-1:0] bf_valid_out;

// ����8�����ε�Ԫ
genvar i;
generate
    for (i = 0; i < BUTTERFLY_NUM; i = i + 1) begin : BF_GEN
        butterfly_unit bf_inst (
            .clk(clk),
            .rst_n(rst_n),
            .mode(mode),
            .data_a(data_a_in),         // ���е�Ԫʹ����ͬ����
            .data_b(data_b_in),         // ���е�Ԫʹ����ͬ����
            .twiddle(twiddle_in),       // ���е�Ԫʹ����ͬ��ת����
            .valid_in(valid_in),
            .result_u(bf_result_u[i]),
            .result_e(bf_result_e[i]),
            .valid_out(bf_valid_out[i])
        );
    end
endgenerate

// �����һ����Ԫ�Ľ����Ϊ����
assign result_u_out = bf_result_u[0];
assign result_e_out = bf_result_e[0];
assign valid_out = bf_valid_out[0];

endmodule
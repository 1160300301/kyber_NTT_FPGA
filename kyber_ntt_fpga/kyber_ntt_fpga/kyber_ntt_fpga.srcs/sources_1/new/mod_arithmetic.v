// mod_arithmetic.v
// Kyberģ���㵥Ԫ��ģ�ӷ���ģ������BarrettԼ��

`include "kyber_params.v"

// ģ�ӷ���
module mod_adder (
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output [DATA_WIDTH-1:0] result
);
    wire [DATA_WIDTH:0] sum;
    assign sum = a + b;
    assign result = (sum >= KYBER_Q) ? (sum - KYBER_Q) : sum[DATA_WIDTH-1:0];
endmodule

// ģ������  
module mod_subtractor (
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output [DATA_WIDTH-1:0] result
);
    wire signed [DATA_WIDTH:0] diff;
    assign diff = a - b;
    assign result = (diff < 0) ? (diff + KYBER_Q) : diff[DATA_WIDTH-1:0];
endmodule

// BarrettԼ��Ԫ - ���Kyber q=3329�Ż�
module barrett_reduction (
    input  [23:0] a,           // �������24λ
    output [DATA_WIDTH-1:0] result
);
    // ��������Algorithm 3ʵ��
    wire [15:0] c1;
    wire [7:0]  c0;
    wire [12:0] d1_temp;
    wire [12:0] d1;
    wire [12:0] q1;
    wire [13:0] s1;
    wire [13:0] s2;
    wire [13:0] r1;
    wire [20:0] r_temp;
    wire signed [20:0] r_signed;
    
    // ����1: �ָ�����
    assign c1 = a[23:8];
    assign c0 = a[7:0];
    
    // ����2-4: �����̹���
    assign d1_temp = c1[15:3] + c1[15:5];
    assign d1 = d1_temp - d1_temp[12:6];
    assign q1 = d1[12:1];
    
    // ����5-6: ����������м�ֵ
    assign s1 = {c1[5:3] - q1[2:0], c1[2:0]};
    assign s2 = {q1[5:2] + q1[3:0], q1[1:0]};
    
    // ����7-8: ������������
    assign r1 = s1 - s2;
    assign r_temp = {r1, c0} - q1;
    assign r_signed = r_temp;
    
    // ����9-17: ����У��
    assign result = (r_signed[20] == 1'b1) ? (r_signed + KYBER_Q) :
                   (r_signed[12:0] >= KYBER_Q) ? (r_signed - KYBER_Q) :
                   r_signed[DATA_WIDTH-1:0];
endmodule

// ģ�˷�����ʹ��BarrettԼ��
module mod_multiplier (
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output [DATA_WIDTH-1:0] result
);
    wire [31:0] product;
    wire [23:0] product_truncated;
    
    assign product = a * b;
    assign product_truncated = product[23:0];
    
    barrett_reduction br_inst (
        .a(product_truncated),
        .result(result)
    );
endmodule

// ͳһģ���㵥Ԫ
module mod_arithmetic_unit (
    input  clk,
    input  rst_n,
    input  [1:0] operation,    // 00:�ӷ�, 01:����, 10:�˷�
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg valid
);
    wire [DATA_WIDTH-1:0] add_result, sub_result, mul_result;
    
    mod_adder ma_inst (
        .a(a), .b(b), .result(add_result)
    );
    
    mod_subtractor ms_inst (
        .a(a), .b(b), .result(sub_result)
    );
    
    mod_multiplier mm_inst (
        .a(a), .b(b), .result(mul_result)
    );
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid <= 0;
        end else begin
            case (operation)
                2'b00: result <= add_result;
                2'b01: result <= sub_result; 
                2'b10: result <= mul_result;
                default: result <= 0;
            endcase
            valid <= 1;
        end
    end
endmodule
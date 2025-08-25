// mod_arithmetic.v
// Kyber模运算单元：模加法、模减法、Barrett约简

`include "kyber_params.v"

// 模加法器
module mod_adder (
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output [DATA_WIDTH-1:0] result
);
    wire [DATA_WIDTH:0] sum;
    assign sum = a + b;
    assign result = (sum >= KYBER_Q) ? (sum - KYBER_Q) : sum[DATA_WIDTH-1:0];
endmodule

// 模减法器  
module mod_subtractor (
    input  [DATA_WIDTH-1:0] a,
    input  [DATA_WIDTH-1:0] b,
    output [DATA_WIDTH-1:0] result
);
    wire signed [DATA_WIDTH:0] diff;
    assign diff = a - b;
    assign result = (diff < 0) ? (diff + KYBER_Q) : diff[DATA_WIDTH-1:0];
endmodule

// Barrett约简单元 - 针对Kyber q=3329优化
module barrett_reduction (
    input  [23:0] a,           // 输入最大24位
    output [DATA_WIDTH-1:0] result
);
    // 根据论文Algorithm 3实现
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
    
    // 步骤1: 分割输入
    assign c1 = a[23:8];
    assign c0 = a[7:0];
    
    // 步骤2-4: 快速商估算
    assign d1_temp = c1[15:3] + c1[15:5];
    assign d1 = d1_temp - d1_temp[12:6];
    assign q1 = d1[12:1];
    
    // 步骤5-6: 余数计算的中间值
    assign s1 = {c1[5:3] - q1[2:0], c1[2:0]};
    assign s2 = {q1[5:2] + q1[3:0], q1[1:0]};
    
    // 步骤7-8: 初步余数计算
    assign r1 = s1 - s2;
    assign r_temp = {r1, c0} - q1;
    assign r_signed = r_temp;
    
    // 步骤9-17: 最终校正
    assign result = (r_signed[20] == 1'b1) ? (r_signed + KYBER_Q) :
                   (r_signed[12:0] >= KYBER_Q) ? (r_signed - KYBER_Q) :
                   r_signed[DATA_WIDTH-1:0];
endmodule

// 模乘法器（使用Barrett约简）
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

// 统一模运算单元
module mod_arithmetic_unit (
    input  clk,
    input  rst_n,
    input  [1:0] operation,    // 00:加法, 01:减法, 10:乘法
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
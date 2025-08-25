// butterfly_unit.v
// 蝶形运算单元

`include "kyber_params.v"

module butterfly_unit (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,        // 操作模式
    input  [DATA_WIDTH-1:0] data_a,      // 输入数据A
    input  [DATA_WIDTH-1:0] data_b,      // 输入数据B
    input  [DATA_WIDTH-1:0] twiddle,     // 旋转因子
    input  valid_in,                     // 输入有效信号
    output reg [DATA_WIDTH-1:0] result_u, // 输出结果U
    output reg [DATA_WIDTH-1:0] result_e, // 输出结果E
    output reg valid_out                 // 输出有效信号
);

// 内部信号
wire [DATA_WIDTH-1:0] mul_result;
wire [DATA_WIDTH-1:0] add_result;
wire [DATA_WIDTH-1:0] sub_result;
reg  [DATA_WIDTH-1:0] temp_a, temp_b, temp_tw;
reg  [DATA_WIDTH-1:0] intermediate;

// 模乘法器实例
mod_multiplier mul_inst (
    .a(temp_b),
    .b(temp_tw),
    .result(mul_result)
);

// 模加法器实例
mod_adder add_inst (
    .a(temp_a),
    .b(intermediate),
    .result(add_result)
);

// 模减法器实例
mod_subtractor sub_inst (
    .a(temp_a),
    .b(intermediate),
    .result(sub_result)
);

// 蝶形运算逻辑
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
                    // NTT模式: U = A + TW*B, E = A - TW*B
                    intermediate <= mul_result; // TW * B
                    result_u <= add_result;     // A + TW*B
                    result_e <= sub_result;     // A - TW*B
                end
                
                MODE_INTT: begin
                    // INTT模式: U = A + B, E = TW * (A - B)
                    if (valid_out) begin // 第二个周期
                        intermediate <= mul_result; // TW * (A - B)
                        result_e <= mul_result;
                    end else begin // 第一个周期
                        intermediate <= sub_result; // A - B
                        result_u <= add_result;     // A + B
                    end
                end
                
                MODE_PWM: begin
                    // 点乘模式：对于Kyber需要特殊处理二次多项式
                    // 这里简化为标准模乘
                    result_u <= mul_result;     // A * B
                    result_e <= 0;              // 未使用
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

// 8个并行蝶形单元处理模块
module butterfly_array (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,
    
    // 接口：所有单元使用相同的输入数据
    input  [DATA_WIDTH-1:0] data_a_in,
    input  [DATA_WIDTH-1:0] data_b_in, 
    input  [DATA_WIDTH-1:0] twiddle_in,
    input  valid_in,
    
    // 输出：只输出第一个单元的结果作为代表
    output [DATA_WIDTH-1:0] result_u_out,
    output [DATA_WIDTH-1:0] result_e_out,
    output valid_out
);

// 内部信号声明
wire [DATA_WIDTH-1:0] bf_result_u [0:BUTTERFLY_NUM-1];
wire [DATA_WIDTH-1:0] bf_result_e [0:BUTTERFLY_NUM-1];
wire [BUTTERFLY_NUM-1:0] bf_valid_out;

// 生成8个蝶形单元
genvar i;
generate
    for (i = 0; i < BUTTERFLY_NUM; i = i + 1) begin : BF_GEN
        butterfly_unit bf_inst (
            .clk(clk),
            .rst_n(rst_n),
            .mode(mode),
            .data_a(data_a_in),         // 所有单元使用相同输入
            .data_b(data_b_in),         // 所有单元使用相同输入
            .twiddle(twiddle_in),       // 所有单元使用相同旋转因子
            .valid_in(valid_in),
            .result_u(bf_result_u[i]),
            .result_e(bf_result_e[i]),
            .valid_out(bf_valid_out[i])
        );
    end
endgenerate

// 输出第一个单元的结果作为代表
assign result_u_out = bf_result_u[0];
assign result_e_out = bf_result_e[0];
assign valid_out = bf_valid_out[0];

endmodule
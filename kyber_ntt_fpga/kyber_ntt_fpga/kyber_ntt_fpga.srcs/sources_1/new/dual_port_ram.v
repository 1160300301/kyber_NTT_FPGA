// dual_port_ram.v
// 双端口RAM设计

`include "kyber_params.v"

// 单端口RAM模块
module single_port_ram (
    input  clk,
    input  we,                           // 写使能
    input  [ADDR_WIDTH-1:0] addr,        // 地址
    input  [DATA_WIDTH-1:0] din,         // 写入数据
    output reg [DATA_WIDTH-1:0] dout     // 读出数据
);

// RAM存储器
reg [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

always @(posedge clk) begin
    if (we) begin
        ram[addr] <= din;
    end
    dout <= ram[addr];
end

endmodule

// 双RAM乒乓存储模块
module dual_ram_storage (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,        // 操作模式
    input  load_enable,                  // 加载使能
    input  compute_enable,               // 计算使能
    input  ping_pong_sel,                // 乒乓选择信号
    
    // 外部接口（数据加载/输出）
    input  [DATA_WIDTH-1:0] ext_din,     // 外部输入数据
    input  [ADDR_WIDTH-1:0] ext_addr,    // 外部地址
    input  ext_we,                       // 外部写使能
    output [DATA_WIDTH-1:0] ext_dout,    // 外部输出数据
    
    // 计算单元接口（单个信号而非数组）
    input  [DATA_WIDTH-1:0] comp_din_a,  // 计算单元输入A
    input  [DATA_WIDTH-1:0] comp_din_b,  // 计算单元输入B
    input  [ADDR_WIDTH-1:0] comp_addr,   // 计算地址
    input  comp_we,                      // 计算写使能
    output [DATA_WIDTH-1:0] comp_dout_a, // 计算单元输出A
    output [DATA_WIDTH-1:0] comp_dout_b  // 计算单元输出B
);

// 内部RAM信号 - wire类型用于模块间连接
wire [DATA_WIDTH-1:0] ram_a_dout_wire, ram_b_dout_wire;
reg [DATA_WIDTH-1:0] ram_a_din, ram_b_din;
reg [ADDR_WIDTH-1:0] ram_a_addr, ram_b_addr;
reg ram_a_we, ram_b_we;

// 数据预重排缓冲
reg [DATA_WIDTH-1:0] reorder_buffer [0:RAM_DEPTH-1];
reg [ADDR_WIDTH-1:0] load_counter;

// RAM A实例
single_port_ram ram_a (
    .clk(clk),
    .we(ram_a_we),
    .addr(ram_a_addr),
    .din(ram_a_din),
    .dout(ram_a_dout_wire)
);

// RAM B实例  
single_port_ram ram_b (
    .clk(clk),
    .we(ram_b_we),
    .addr(ram_b_addr), 
    .din(ram_b_din),
    .dout(ram_b_dout_wire)
);

// 地址和数据重排逻辑
function [ADDR_WIDTH-1:0] reorder_addr_ntt;
    input [ADDR_WIDTH-1:0] original_addr;
    begin
        // NTT数据预重排：按论文图6(a)的方式重排
        if (original_addr < 128) begin
            reorder_addr_ntt = original_addr;     // 前128个到Block A
        end else begin
            reorder_addr_ntt = original_addr - 128; // 后128个到Block B
        end
    end
endfunction

function [ADDR_WIDTH-1:0] reorder_addr_intt;
    input [ADDR_WIDTH-1:0] original_addr;
    begin
        // INTT数据预重排：偶数索引到Block A，奇数索引到Block B
        reorder_addr_intt = original_addr >> 1;
    end
endfunction

// RAM访问控制逻辑 - 统一在always块中处理
always @(*) begin
    if (load_enable) begin
        // 数据加载模式
        case (mode)
            MODE_NTT: begin
                if (ext_addr < 128) begin
                    // 前128个元素存储到RAM A
                    ram_a_addr = reorder_addr_ntt(ext_addr);
                    ram_a_din = ext_din;
                    ram_a_we = ext_we;
                    ram_b_addr = 0;
                    ram_b_din = 0;
                    ram_b_we = 0;
                end else begin
                    // 后128个元素存储到RAM B
                    ram_a_addr = 0;
                    ram_a_din = 0;
                    ram_a_we = 0;
                    ram_b_addr = reorder_addr_ntt(ext_addr);
                    ram_b_din = ext_din;
                    ram_b_we = ext_we;
                end
            end
            
            MODE_INTT: begin
                if (ext_addr[0] == 0) begin
                    // 偶数索引存储到RAM A
                    ram_a_addr = reorder_addr_intt(ext_addr);
                    ram_a_din = ext_din;
                    ram_a_we = ext_we;
                    ram_b_addr = 0;
                    ram_b_din = 0;
                    ram_b_we = 0;
                end else begin
                    // 奇数索引存储到RAM B
                    ram_a_addr = 0;
                    ram_a_din = 0;
                    ram_a_we = 0;
                    ram_b_addr = reorder_addr_intt(ext_addr);
                    ram_b_din = ext_din;
                    ram_b_we = ext_we;
                end
            end
            
            default: begin
                ram_a_addr = ext_addr;
                ram_a_din = ext_din;
                ram_a_we = ext_we;
                ram_b_addr = 0;
                ram_b_din = 0;
                ram_b_we = 0;
            end
        endcase
    end else if (compute_enable) begin
        // 计算模式 - 乒乓操作
        if (ping_pong_sel) begin
            // 从RAM A读，写到RAM B
            ram_a_addr = comp_addr;
            ram_a_din = 0;
            ram_a_we = 0;
            ram_b_addr = comp_addr;
            ram_b_din = comp_din_a; // 简化，使用单个输入
            ram_b_we = comp_we;
        end else begin
            // 从RAM B读，写到RAM A  
            ram_a_addr = comp_addr;
            ram_a_din = comp_din_a;
            ram_a_we = comp_we;
            ram_b_addr = comp_addr;
            ram_b_din = 0;
            ram_b_we = 0;
        end
    end else begin
        // 空闲状态
        ram_a_addr = 0;
        ram_a_din = 0;
        ram_a_we = 0;
        ram_b_addr = 0;
        ram_b_din = 0;
        ram_b_we = 0;
    end
end

// 输出数据分配 
assign comp_dout_a = ram_a_dout_wire;
assign comp_dout_b = ram_b_dout_wire;

// 外部输出
assign ext_dout = ping_pong_sel ? ram_b_dout_wire : ram_a_dout_wire;

endmodule
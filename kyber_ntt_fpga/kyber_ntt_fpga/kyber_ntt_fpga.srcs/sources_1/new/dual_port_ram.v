// dual_port_ram.v
// ˫�˿�RAM���

`include "kyber_params.v"

// ���˿�RAMģ��
module single_port_ram (
    input  clk,
    input  we,                           // дʹ��
    input  [ADDR_WIDTH-1:0] addr,        // ��ַ
    input  [DATA_WIDTH-1:0] din,         // д������
    output reg [DATA_WIDTH-1:0] dout     // ��������
);

// RAM�洢��
reg [DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

always @(posedge clk) begin
    if (we) begin
        ram[addr] <= din;
    end
    dout <= ram[addr];
end

endmodule

// ˫RAMƹ�Ҵ洢ģ��
module dual_ram_storage (
    input  clk,
    input  rst_n,
    input  [MODE_WIDTH-1:0] mode,        // ����ģʽ
    input  load_enable,                  // ����ʹ��
    input  compute_enable,               // ����ʹ��
    input  ping_pong_sel,                // ƹ��ѡ���ź�
    
    // �ⲿ�ӿڣ����ݼ���/�����
    input  [DATA_WIDTH-1:0] ext_din,     // �ⲿ��������
    input  [ADDR_WIDTH-1:0] ext_addr,    // �ⲿ��ַ
    input  ext_we,                       // �ⲿдʹ��
    output [DATA_WIDTH-1:0] ext_dout,    // �ⲿ�������
    
    // ���㵥Ԫ�ӿڣ������źŶ������飩
    input  [DATA_WIDTH-1:0] comp_din_a,  // ���㵥Ԫ����A
    input  [DATA_WIDTH-1:0] comp_din_b,  // ���㵥Ԫ����B
    input  [ADDR_WIDTH-1:0] comp_addr,   // �����ַ
    input  comp_we,                      // ����дʹ��
    output [DATA_WIDTH-1:0] comp_dout_a, // ���㵥Ԫ���A
    output [DATA_WIDTH-1:0] comp_dout_b  // ���㵥Ԫ���B
);

// �ڲ�RAM�ź� - wire��������ģ�������
wire [DATA_WIDTH-1:0] ram_a_dout_wire, ram_b_dout_wire;
reg [DATA_WIDTH-1:0] ram_a_din, ram_b_din;
reg [ADDR_WIDTH-1:0] ram_a_addr, ram_b_addr;
reg ram_a_we, ram_b_we;

// ����Ԥ���Ż���
reg [DATA_WIDTH-1:0] reorder_buffer [0:RAM_DEPTH-1];
reg [ADDR_WIDTH-1:0] load_counter;

// RAM Aʵ��
single_port_ram ram_a (
    .clk(clk),
    .we(ram_a_we),
    .addr(ram_a_addr),
    .din(ram_a_din),
    .dout(ram_a_dout_wire)
);

// RAM Bʵ��  
single_port_ram ram_b (
    .clk(clk),
    .we(ram_b_we),
    .addr(ram_b_addr), 
    .din(ram_b_din),
    .dout(ram_b_dout_wire)
);

// ��ַ�����������߼�
function [ADDR_WIDTH-1:0] reorder_addr_ntt;
    input [ADDR_WIDTH-1:0] original_addr;
    begin
        // NTT����Ԥ���ţ�������ͼ6(a)�ķ�ʽ����
        if (original_addr < 128) begin
            reorder_addr_ntt = original_addr;     // ǰ128����Block A
        end else begin
            reorder_addr_ntt = original_addr - 128; // ��128����Block B
        end
    end
endfunction

function [ADDR_WIDTH-1:0] reorder_addr_intt;
    input [ADDR_WIDTH-1:0] original_addr;
    begin
        // INTT����Ԥ���ţ�ż��������Block A������������Block B
        reorder_addr_intt = original_addr >> 1;
    end
endfunction

// RAM���ʿ����߼� - ͳһ��always���д���
always @(*) begin
    if (load_enable) begin
        // ���ݼ���ģʽ
        case (mode)
            MODE_NTT: begin
                if (ext_addr < 128) begin
                    // ǰ128��Ԫ�ش洢��RAM A
                    ram_a_addr = reorder_addr_ntt(ext_addr);
                    ram_a_din = ext_din;
                    ram_a_we = ext_we;
                    ram_b_addr = 0;
                    ram_b_din = 0;
                    ram_b_we = 0;
                end else begin
                    // ��128��Ԫ�ش洢��RAM B
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
                    // ż�������洢��RAM A
                    ram_a_addr = reorder_addr_intt(ext_addr);
                    ram_a_din = ext_din;
                    ram_a_we = ext_we;
                    ram_b_addr = 0;
                    ram_b_din = 0;
                    ram_b_we = 0;
                end else begin
                    // ���������洢��RAM B
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
        // ����ģʽ - ƹ�Ҳ���
        if (ping_pong_sel) begin
            // ��RAM A����д��RAM B
            ram_a_addr = comp_addr;
            ram_a_din = 0;
            ram_a_we = 0;
            ram_b_addr = comp_addr;
            ram_b_din = comp_din_a; // �򻯣�ʹ�õ�������
            ram_b_we = comp_we;
        end else begin
            // ��RAM B����д��RAM A  
            ram_a_addr = comp_addr;
            ram_a_din = comp_din_a;
            ram_a_we = comp_we;
            ram_b_addr = comp_addr;
            ram_b_din = 0;
            ram_b_we = 0;
        end
    end else begin
        // ����״̬
        ram_a_addr = 0;
        ram_a_din = 0;
        ram_a_we = 0;
        ram_b_addr = 0;
        ram_b_din = 0;
        ram_b_we = 0;
    end
end

// ������ݷ��� 
assign comp_dout_a = ram_a_dout_wire;
assign comp_dout_b = ram_b_dout_wire;

// �ⲿ���
assign ext_dout = ping_pong_sel ? ram_b_dout_wire : ram_a_dout_wire;

endmodule
// kyber_params.v
// Kyber NTT 参数定义文件

`ifndef KYBER_PARAMS_V
`define KYBER_PARAMS_V

// Kyber基本参数
parameter KYBER_Q = 3329;           // 模数 q = 3329 = 13×2^8 + 1
parameter KYBER_N = 256;            // 多项式度数
parameter KYBER_LOGN = 8;           // log2(N)

// 数据位宽
parameter DATA_WIDTH = 16;          // 数据位宽（支持0-3328范围）
parameter ADDR_WIDTH = 8;           // 地址位宽（256个元素）
parameter TW_ADDR_WIDTH = 7;        // 旋转因子地址位宽（128个旋转因子）

// NTT相关参数
parameter NTT_STAGES = 7;           // NTT计算阶段数
parameter BUTTERFLY_NUM = 8;        // 并行蝶形单元数量

// Barrett约简相关参数（针对q=3329优化）
parameter BARRETT_R = 24;           // Barrett约简的R值位宽
parameter BARRETT_MU = 5039;        // μ = floor(2^R / q)，预计算的常数

// 控制信号位宽
parameter MODE_WIDTH = 2;           // 操作模式位宽
parameter STAGE_WIDTH = 3;          // 阶段计数器位宽

// 操作模式定义
parameter MODE_NTT = 2'b00;         // NTT正变换
parameter MODE_INTT = 2'b01;        // INTT逆变换  
parameter MODE_PWM = 2'b10;         // 点乘模式

// 状态机状态定义
parameter STATE_WIDTH = 3;
parameter STATE_IDLE = 3'b000;      // 空闲状态
parameter STATE_LOAD = 3'b001;      // 数据加载
parameter STATE_COMPUTE = 3'b010;   // 计算状态
parameter STATE_OUTPUT = 3'b011;    // 输出状态

// 时序参数
parameter LOAD_CYCLES = 16;         // 数据加载周期数
parameter STAGE_CYCLES = 30;        // 每阶段计算周期数
parameter OUTPUT_CYCLES = 16;       // 输出周期数

// 内存参数
parameter RAM_DEPTH = 256;          // RAM深度
parameter RAM_WIDTH = DATA_WIDTH;   // RAM位宽

`endif // KYBER_PARAMS_V
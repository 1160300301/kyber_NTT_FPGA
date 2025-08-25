# timing_constraints.xdc
# Kyber NTT 时序约束文件 - 75MHz优化版本

# 主时钟定义 - 75MHz (13.33ns周期)
create_clock -period 13.33 -name sys_clk [get_ports clk]

# 时钟不确定性和延迟
set_clock_uncertainty 0.2 [get_clocks sys_clk]
set_clock_latency -source -min 0.5 [get_clocks sys_clk]
set_clock_latency -source -max 1.0 [get_clocks sys_clk]

# 输入延迟约束（放宽）
set_input_delay -clock sys_clk -min 1.0 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]
set_input_delay -clock sys_clk -max 3.0 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]

# 输出延迟约束（放宽）  
set_output_delay -clock sys_clk -min 0.5 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]
set_output_delay -clock sys_clk -max 2.0 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]

# 异步复位路径
set_false_path -from [get_ports rst_n]

# 异步控制信号
set_false_path -from [get_ports start]

# 多周期路径约束 - 允许蝶形运算用更多周期
set_multicycle_path -setup 2 -through [get_pins -hierarchical -filter {NAME =~ "*butterfly*"}]
set_multicycle_path -hold 1 -through [get_pins -hierarchical -filter {NAME =~ "*butterfly*"}]

# Barrett约简单元路径放宽
set_multicycle_path -setup 2 -through [get_pins -hierarchical -filter {NAME =~ "*barrett*"}]
set_multicycle_path -hold 1 -through [get_pins -hierarchical -filter {NAME =~ "*barrett*"}]

# 模运算单元路径放宽
set_multicycle_path -setup 2 -through [get_pins -hierarchical -filter {NAME =~ "*mod_*"}]
set_multicycle_path -hold 1 -through [get_pins -hierarchical -filter {NAME =~ "*mod_*"}]

# 时钟域交叉路径（如果存在）
set_false_path -from [get_clocks sys_clk] -to [get_ports -filter {NAME =~ "*debug*"}]

# 设置最大扇出以改善时序
set_max_fanout 15 [current_design]

# 放宽总体时序约束
set_max_delay -datapath_only 12.0 -from [all_inputs] -to [all_outputs]
set_min_delay -from [all_inputs] -to [all_outputs] 1.0
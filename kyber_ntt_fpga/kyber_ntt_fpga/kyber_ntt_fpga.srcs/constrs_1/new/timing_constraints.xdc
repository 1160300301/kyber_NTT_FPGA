# timing_constraints.xdc
# Kyber NTT ʱ��Լ���ļ� - 75MHz�Ż��汾

# ��ʱ�Ӷ��� - 75MHz (13.33ns����)
create_clock -period 13.33 -name sys_clk [get_ports clk]

# ʱ�Ӳ�ȷ���Ժ��ӳ�
set_clock_uncertainty 0.2 [get_clocks sys_clk]
set_clock_latency -source -min 0.5 [get_clocks sys_clk]
set_clock_latency -source -max 1.0 [get_clocks sys_clk]

# �����ӳ�Լ�����ſ�
set_input_delay -clock sys_clk -min 1.0 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]
set_input_delay -clock sys_clk -max 3.0 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]

# ����ӳ�Լ�����ſ�  
set_output_delay -clock sys_clk -min 0.5 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]
set_output_delay -clock sys_clk -max 2.0 [get_ports -filter {NAME !~ "*clk*" && NAME !~ "*rst*"}]

# �첽��λ·��
set_false_path -from [get_ports rst_n]

# �첽�����ź�
set_false_path -from [get_ports start]

# ������·��Լ�� - ������������ø�������
set_multicycle_path -setup 2 -through [get_pins -hierarchical -filter {NAME =~ "*butterfly*"}]
set_multicycle_path -hold 1 -through [get_pins -hierarchical -filter {NAME =~ "*butterfly*"}]

# BarrettԼ��Ԫ·���ſ�
set_multicycle_path -setup 2 -through [get_pins -hierarchical -filter {NAME =~ "*barrett*"}]
set_multicycle_path -hold 1 -through [get_pins -hierarchical -filter {NAME =~ "*barrett*"}]

# ģ���㵥Ԫ·���ſ�
set_multicycle_path -setup 2 -through [get_pins -hierarchical -filter {NAME =~ "*mod_*"}]
set_multicycle_path -hold 1 -through [get_pins -hierarchical -filter {NAME =~ "*mod_*"}]

# ʱ���򽻲�·����������ڣ�
set_false_path -from [get_clocks sys_clk] -to [get_ports -filter {NAME =~ "*debug*"}]

# ��������ȳ��Ը���ʱ��
set_max_fanout 15 [current_design]

# �ſ�����ʱ��Լ��
set_max_delay -datapath_only 12.0 -from [all_inputs] -to [all_outputs]
set_min_delay -from [all_inputs] -to [all_outputs] 1.0
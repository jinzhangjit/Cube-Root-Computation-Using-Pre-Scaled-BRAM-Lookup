# =============================================================================
# Constraints File for cube_root_bram_ultra
# Target Device: Xilinx Kintex-7 xc7k420tffg1156-2L
# Target Frequency: 100 MHz (10 ns clock period)
# =============================================================================

# Primary clock (100 MHz)
create_clock -period 10.000 -name clk [get_ports clk]

# Input/output delays (set to 25% of clock period for safe synthesis)
set_input_delay  -clock clk -max 2.0 [get_ports {start radicand[*] rst_n}]
set_input_delay  -clock clk -min 0.5 [get_ports {start radicand[*] rst_n}]
set_output_delay -clock clk -max 2.0 [get_ports {done result[*]}]
set_output_delay -clock clk -min 0.5 [get_ports {done result[*]}]

# Asynchronous reset path
set_false_path -from [get_ports rst_n]

# Vivado 2018.3 does not support set_max_fanout in XDC. Keep the fanout
# guideline documented here rather than enabling a critical warning.
# set_max_fanout 50 [current_design]

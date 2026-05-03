#==============================================================================
# Vivado synthesis and implementation script (chip-level / non-OOC)
# Target: Xilinx Kintex-7 xc7k420tffg1156-2L, Vivado 2018.3
# Usage from repository root:
#   vivado -mode batch -source scripts/synth_vivado.tcl
#==============================================================================

set top_module "cube_root_bram_ultra_3cyc"
set part       "xc7k420tffg1156-2L"
set out_dir    "./build/synth_output"
set rtl_file   "./rtl/cube_root_bram_ultra_3cyc.v"
set xdc_file   "./constraints/cube_root_bram_ultra_3cyc.xdc"

file mkdir $out_dir

read_verilog $rtl_file
read_xdc     $xdc_file

# Standard chip-level synthesis: I/O buffers (IBUF/OBUF) are auto-inferred
# on every top-level port, exactly as in the paper.
synth_design -top $top_module -part $part

report_utilization     -file [file join $out_dir "utilization.rpt"]
report_timing_summary  -file [file join $out_dir "timing.rpt"]
report_power           -file [file join $out_dir "power.rpt"]

opt_design
place_design
route_design

report_utilization     -file [file join $out_dir "utilization_post_route.rpt"]
report_timing_summary  -file [file join $out_dir "timing_post_route.rpt"]
report_power           -file [file join $out_dir "power_post_route.rpt"]

write_checkpoint -force [file join $out_dir "${top_module}_routed.dcp"]

puts ""
puts "============================================="
puts " SYNTHESIS AND IMPLEMENTATION COMPLETE"
puts "============================================="
puts " Mode: chip-level (non-OOC), I/O buffers included"
puts " Top : $top_module"
puts " Part: $part"
puts " Reports written to: $out_dir"
puts " Expected: F_max ~ 87.9 MHz, Dynamic ~ 24 mW"
puts "============================================="

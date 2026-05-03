#==============================================================================
# Vivado xsim functional simulation script
#
# Usage from repository root:
#   vivado -mode batch -source scripts/run_vivado_sim.tcl
#==============================================================================

set sim_dir  "./build/sim_output"
set rtl_file "../../rtl/cube_root_bram_ultra_3cyc.v"
set tb_file  "../../sim/tb_cube_root_bram_ultra_3cyc.v"

file mkdir $sim_dir
cd $sim_dir

exec xvlog -sv \
    $rtl_file \
    $tb_file

exec xelab tb_cube_root_bram_ultra_3cyc -debug typical -s tb_cube_root_bram_ultra_3cyc_sim
exec xsim tb_cube_root_bram_ultra_3cyc_sim -runall

# ASAP7 7.5-track, typical corner, RVT cells (the -dc tree also has LVT, SLVT
# and SRAM VT views; widen the glob to *_TT_*.db to let DC mix them).
# The ASAP7 Liberty files use 1 ps / 1 fF units, so the clock period is in ps.
set target_library [glob /pdks/asap7sc7p5t_28/LIB/db/*_RVT_TT_*.db]
set link_library   "* $target_library"
read_verilog ./counter.v
current_design counter
link
create_clock -name clk -period 1000 [get_ports clk]
set_input_delay  50 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 50 -clock clk [all_outputs]
compile_ultra
report_area
report_timing -max_paths 1
write -format verilog -hierarchy -output ./counter_netlist.v
exit

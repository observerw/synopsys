set target_library /pdks/sky130A/libs.ref/sky130_fd_sc_hd/db/sky130_fd_sc_hd__tt_025C_1v80.db
set link_library   "* $target_library"
read_verilog ./counter.v
current_design counter
link
compile
report_area
report_timing
write -format verilog -hierarchy -output ./counter_netlist.v
write -format ddc -hierarchy -output ./counter.ddc
exit

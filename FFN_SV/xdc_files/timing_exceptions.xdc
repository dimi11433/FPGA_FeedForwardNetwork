## Physically exclusive clocks: MMCM output vs post-BUFG are the same 10 MHz
set_clock_groups -physically_exclusive \
    -group [get_clocks -filter {NAME =~ *clk_out1_clk_wiz_0}] \
    -group [get_clocks -filter {NAME =~ *clk_out1_clk_wiz_0_1}]

## JTAG TCK is asynchronous to design clocks
set_clock_groups -asynchronous \
    -group [get_clocks jtag_tck_clk] \
    -group [get_clocks -filter {NAME =~ *clk_out1_clk_wiz*}]

## False paths for async I/O
set_false_path -from [get_ports cpu_resetn]
set_false_path -from [get_ports uart_rxd]
set_false_path -to   [get_ports uart_txd]
set_false_path -from [get_ports jtag_trst_n]

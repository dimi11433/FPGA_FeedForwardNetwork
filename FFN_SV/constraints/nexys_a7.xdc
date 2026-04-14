## =============================================================================
## Nexys A7 (XC7A100T) — FFN UART constraints
## =============================================================================

## ---------- 100 MHz board oscillator ----------
set_property PACKAGE_PIN E3 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name clk_100mhz [get_ports clk_100mhz]

## ---------- Active-low CPU reset pushbutton ----------
set_property PACKAGE_PIN C12 [get_ports cpu_resetn]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_resetn]

## ---------- UART (FT2232HQ on-board USB-UART bridge) ----------
## uart_rxd : USB → FPGA (FPGA receives)
set_property PACKAGE_PIN C4 [get_ports uart_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]

## uart_txd : FPGA → USB (FPGA transmits)
set_property PACKAGE_PIN D4 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

## ---------- Optional: TX-busy LED (LD0) ----------
set_property PACKAGE_PIN H17 [get_ports led_busy]
set_property IOSTANDARD LVCMOS33 [get_ports led_busy]

## ---------- JTAG (Pmod JA) — fpga_top ----------
set_property PACKAGE_PIN C17 [get_ports jtag_tck]
set_property IOSTANDARD LVCMOS33 [get_ports jtag_tck]
set_property PACKAGE_PIN D18 [get_ports jtag_tms]
set_property IOSTANDARD LVCMOS33 [get_ports jtag_tms]
set_property PACKAGE_PIN E18 [get_ports jtag_tdi]
set_property IOSTANDARD LVCMOS33 [get_ports jtag_tdi]
set_property PACKAGE_PIN G17 [get_ports jtag_tdo]
set_property IOSTANDARD LVCMOS33 [get_ports jtag_tdo]
set_property PACKAGE_PIN D17 [get_ports jtag_trst_n]
set_property IOSTANDARD LVCMOS33 [get_ports jtag_trst_n]
create_clock -name jtag_tck_clk -period 100.000 [get_ports jtag_tck]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_tck_IBUF]

## ---------- Bitstream configuration ----------
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

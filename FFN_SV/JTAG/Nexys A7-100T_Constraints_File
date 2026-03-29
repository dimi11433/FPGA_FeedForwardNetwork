## Nexys A7-100T Constraints for chip_top.sv
## Generated for JTAG DMI Q8.8 FFN Debug Project

## ======================
## Clock - 100MHz system clock
## ======================
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports { clk }];

## ======================
## Reset - active low, mapped to CPU Reset button
## ======================
set_property -dict { PACKAGE_PIN C12  IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## ======================
## Test mode - mapped to SW[0]
## Leave LOW (off) for normal operation
## ======================
set_property -dict { PACKAGE_PIN J15  IOSTANDARD LVCMOS33 } [get_ports { testmode_i }];

## ======================
## JTAG pins - mapped to Pmod Header JA
## Connect external JTAG probe here
##
## JA Pin 1 = tck_i   (TCK)
## JA Pin 2 = tms_i   (TMS)
## JA Pin 3 = trst_ni (TRST, active low)
## JA Pin 4 = td_i    (TDI)
## JA Pin 7 = td_o    (TDO)
## JA Pin 8 = tdo_oe_o (output enable indicator)
## ======================
set_property -dict { PACKAGE_PIN C17  IOSTANDARD LVCMOS33 } [get_ports { tck_i   }];
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets tck_i_IBUF];
set_property -dict { PACKAGE_PIN D18  IOSTANDARD LVCMOS33 } [get_ports { tms_i   }];
set_property -dict { PACKAGE_PIN E18  IOSTANDARD LVCMOS33 } [get_ports { trst_ni }];
set_property -dict { PACKAGE_PIN G17  IOSTANDARD LVCMOS33 } [get_ports { td_i    }];
set_property -dict { PACKAGE_PIN D17  IOSTANDARD LVCMOS33 } [get_ports { td_o    }];
set_property -dict { PACKAGE_PIN E17  IOSTANDARD LVCMOS33 } [get_ports { tdo_oe_o}];

## ======================
## JTAG timing constraints
## TCK runs much slower than system clock
## ======================
create_clock -add -name tck_pin -period 100.00 -waveform {0 50} [get_ports { tck_i }];
set_clock_groups -asynchronous -group [get_clocks sys_clk_pin] -group [get_clocks tck_pin];

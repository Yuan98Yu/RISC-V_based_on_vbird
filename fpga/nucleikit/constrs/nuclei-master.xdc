set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

#####               create clock              #####
set_property -dict { PACKAGE_PIN W19    IOSTANDARD LVCMOS33 } [get_ports { CLK100MHZ }]; 
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {CLK100MHZ}];

set_property -dict { PACKAGE_PIN Y18    IOSTANDARD LVCMOS33 } [get_ports { CLK32768KHZ }]; 
create_clock -add -name sys_clk_pin -period 30517.58 -waveform {0 15258.79} [get_ports {CLK32768KHZ}];

set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets dut_io_pads_jtag_TCK_i_ival]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets IOBUF_jtag_TCK/O]


#####            rst define           #####
set_property PACKAGE_PIN P20 [get_ports mcu_rst   ]
set_property IOSTANDARD LVCMOS33 [get_ports mcu_rst   ]


#####                spi define               #####
set_property PACKAGE_PIN W16 [get_ports  qspi_cs    ]
set_property PACKAGE_PIN W15 [get_ports  qspi_sck   ]
set_property PACKAGE_PIN U16 [get_ports {qspi_dq[3]}]
set_property PACKAGE_PIN T16 [get_ports {qspi_dq[2]}]
set_property PACKAGE_PIN T14 [get_ports {qspi_dq[1]}]
set_property PACKAGE_PIN T15 [get_ports {qspi_dq[0]}]

#####               MCU JTAG define           #####
set_property PACKAGE_PIN N17 [get_ports mcu_TDO]
set_property PACKAGE_PIN P15 [get_ports mcu_TCK]
set_property PACKAGE_PIN T18 [get_ports mcu_TDI]
set_property PACKAGE_PIN P17 [get_ports mcu_TMS]

#####                PMU define               #####
set_property PACKAGE_PIN U15 [get_ports pmu_paden ]
set_property PACKAGE_PIN V15 [get_ports pmu_padrst]
set_property PACKAGE_PIN N15 [get_ports mcu_wakeup]

#####                gpio define              #####
#####             	  not used	              #####
set_property PACKAGE_PIN W17  [get_ports {gpio[31]}]
set_property PACKAGE_PIN AA18 [get_ports {gpio[30]}]
set_property PACKAGE_PIN AB18 [get_ports {gpio[29]}]
set_property PACKAGE_PIN U17  [get_ports {gpio[28]}]
set_property PACKAGE_PIN U18  [get_ports {gpio[27]}]
set_property PACKAGE_PIN P14  [get_ports {gpio[26]}]
set_property PACKAGE_PIN R14  [get_ports {gpio[25]}]
set_property PACKAGE_PIN R18  [get_ports {gpio[24]}]

#####             gpio/keyboards define           #####
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN K3  } [get_ports {gpio[23]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN L3  } [get_ports {gpio[22]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN J4  } [get_ports {gpio[21]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN K4  } [get_ports {gpio[20]}]

set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN M2  } [get_ports {gpio[19]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN K6  } [get_ports {gpio[18]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN J6  } [get_ports {gpio[17]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN L5  } [get_ports {gpio[16]}]

#####             gpio/switch_i define    	      #####
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN U6  } [get_ports {gpio[15]}]
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN W5  } [get_ports {gpio[14]}]
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN W6  } [get_ports {gpio[13]}]
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN U5  } [get_ports {gpio[12]}]
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN T5  } [get_ports {gpio[11]}]
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN T4  } [get_ports {gpio[10]}]
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN R4  } [get_ports {gpio[9]}]
set_property -dict { IOSTANDARD LVCMOS15 PACKAGE_PIN W4  } [get_ports {gpio[8]}]

#####             gpio/led define    	          #####
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN F21 } [get_ports {gpio[7]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN G22 } [get_ports {gpio[6]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN G21 } [get_ports {gpio[5]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN D21 } [get_ports {gpio[4]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN E21 } [get_ports {gpio[3]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN D22 } [get_ports {gpio[2]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN E22 } [get_ports {gpio[1]}]
set_property -dict { IOSTANDARD LVCMOS33 PACKAGE_PIN A21 } [get_ports {gpio[0]}]

## ================================================================
## Arty S7 Constraints for Current Top-Level Design
## ================================================================
#clock
set_property -dict { PACKAGE_PIN R2    IOSTANDARD SSTL135 } [get_ports { clk }]; #IO_L12P_T1_MRCC_34 Sch=ddr3_clk[200]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5.000}  [get_ports { clk }];

set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports { rstb }]; # Active low reset 
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]; # UART RX input

# Toggle switches
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports { testen_toggle_sw }]; # TESTEN 
set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 } [get_ports { afeen_toggle_sw }]; # AFEEN
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports { test_clock_toggle_sw }]; # TEST CLOCK SWITCH
set_property -dict { PACKAGE_PIN M5 IOSTANDARD LVCMOS33  } [get_ports { test_prbs_toggle_sw }]; ## TEST PRBS SWITCH

## Status LEDs
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { leds_o[0] }]; # LED 2
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { leds_o[1] }]; # LED 3
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33 } [get_ports { leds_o[2] }]; # LED 4
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports { leds_o[3] }]; # LED 5

# RGB LEDs

set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { experiment_ongoing }]; #IO_L23N_T3_FWE_B_15 Sch=led0_r
set_property -dict { PACKAGE_PIN G17   IOSTANDARD LVCMOS33 } [get_ports { experiment_done }]; #IO_L14N_T2_SRCC_15 Sch=led0_g
set_property -dict { PACKAGE_PIN F15   IOSTANDARD LVCMOS33 } [get_ports { rxstate }]; #IO_L13N_T2_MRCC_15 Sch=led0_b

# PMOD JA

set_property -dict { PACKAGE_PIN L17  IOSTANDARD LVCMOS33 } [get_ports { test_clk100mhz }]; # Sch=jc1 # test_clk100mhz -> JB9
set_property -dict { PACKAGE_PIN L18  IOSTANDARD LVCMOS33 } [get_ports { test_prbs50mhz }]; # Sch=jc2 # test_prbs50mhz -> JB10

## PMOD JB

set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { rxtxb }]; # JB5 -> RXTXB
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }]; # JB2 -> I2C SDA
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }]; # JB3 -> I2C SCL
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { i2c_cse_n }]; # JB4 -> I2C CSEB

# PMOD JC

set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports { testen }]; # JB1 -> TESTEN
set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports { afeen }]; # JB2 -> AFEEN
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { cseb }];# JB3 -> CSEB
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { clkafe }]; # JB4 -> CLKAFE
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports { chip_rstb }]; # JC0 -> CHIP RESET
set_property -dict { PACKAGE_PIN P13 IOSTANDARD LVCMOS33 } [get_ports { prbs_cross_out }]; # JA0 -> PRBS CROSS OUTPUT
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports { prbs_enable_out }]; # JA1 -> PRBS ENABLE OUTPUT

# Tell Vivado not to worry about timing constraints, just for probing reasons:
#set_false_path -to [get_ports { test_clk100mhz }]
#set_false_path -to [get_ports { test_prbs50mhz }]

## Configuration options, can be used for all designs
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## SW3 is assigned to a pin M5 in the 1.35v bank. This pin can also be used as
## the VREF for BANK 34. To ensure that SW3 does not define the reference voltage
## and to be able to use this pin as an ordinary I/O the following property must
## be set to enable an internal VREF for BANK 34. Since a 1.35v supply is being
## used the internal reference is set to half that value (i.e. 0.675v). Note that
## this property must be set even if SW3 is not used in the design.
set_property INTERNAL_VREF 0.675 [get_iobanks 34]

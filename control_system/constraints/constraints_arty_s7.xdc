## ================================================================
## Arty S7 Constraints for Current Top-Level Design
## ================================================================

## ================================================================
## CLOCK
## 100 MHz onboard oscillator
## ================================================================

set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports { clk }]
create_clock -add -name sys_clk_pin -period 83.333 -waveform {0 41.667} [get_ports { clk }]

## ================================================================
## RESET
## BTN0 used as active-low reset
## ================================================================

set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports { rstb }]

## ================================================================
## UART RX INPUT
## USB-UART -> FPGA RX
## ================================================================

set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { uart_rx_i }]

## ================================================================
## TOGGLE SWITCHES
## ================================================================

## TESTEN switch
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports { testen_toggle_sw }]

## AFEEN switch
set_property -dict { PACKAGE_PIN H18 IOSTANDARD LVCMOS33 } [get_ports { afeen_toggle_sw }]

## ================================================================
## STATUS LEDs
## ================================================================

## Experiment ongoing
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports { experiment_ongoing }]

## Experiment done
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports { experiment_done }]

## RXSTATE
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33 } [get_ports { rxstate }]

## ================================================================
## PMOD JA
## ================================================================

## JA5 -> RXTXB
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports { rxtxb }]

## JA0 -> PRBS CROSS OUTPUT
set_property -dict { PACKAGE_PIN L17 IOSTANDARD LVCMOS33 } [get_ports { prbs_cross_out }]

## JA1 -> PRBS ENABLE OUTPUT
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports { prbs_enable_out }]

## JA2 -> I2C SDA
set_property -dict { PACKAGE_PIN M14 IOSTANDARD LVCMOS33 } [get_ports { i2c_sda }]

## JA3 -> I2C SCL
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports { i2c_scl }]

## JA4 -> I2C CSE_N
set_property -dict { PACKAGE_PIN M16 IOSTANDARD LVCMOS33 } [get_ports { i2c_cse_n }]

## ================================================================
## CHIP CONTROL OUTPUTS
## PMOD JB
## ================================================================

## JB0 -> CHIP RESET
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports { chip_rstb }]

## JB1 -> TESTEN
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { testen }]

## JB2 -> AFEEN
set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports { afeen }]

## JB3 -> CSEB
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports { cseb }]

## JB4 -> CLKAFE
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { clkafe }]

## ================================================================
## CONFIGURATION
## ================================================================

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
## Change to Config voltage to 1.8V?
set_property CONFIG_VOLTAGE 3.3 [current_design] 
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## ================================================================
## BANK 34 INTERNAL VREF
## ================================================================

set_property INTERNAL_VREF 0.675 [get_iobanks 34]

## ================================================================
## COMPRESS BITSTREAM
## ================================================================

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
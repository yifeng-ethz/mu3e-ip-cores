#

# global clock constrains for feb_v2
# M. Mueller, September 2020
# Yifeng Wang, Mar 3 2025 - round the frequencies



# create clocks
# NOTE : add small fractions to clock frequencies
#        to make timing analyzer warn on domain transitions
proc create_clock_if_exists {period target} {
    set target_ports [get_ports -nowarn $target]
    if { [get_collection_size $target_ports] > 0 } {
        create_clock -period $period $target_ports
    }
}

# Keep the physical clock definitions on their raw port names. Quartus 18.1
# derive_pll_clocks is fragile for the LVDS PLL chain when these base clocks
# are renamed. Friendly report labels are provided in ../timing_clock_aliases.tcl.
create_clock -period  "50.000 MHz" [ get_ports spare_clk_osc ]
create_clock -period  "50.000 MHz" [ get_ports systemclock_bottom ]
create_clock -period  "50.000 MHz" [ get_ports systemclock ]
create_clock -period "125.000 MHz" [ get_ports clk_125_top ]
create_clock -period "125.000 MHz" [ get_ports clk_125_bottom ]
create_clock -period "125.000 MHz" [ get_ports LVDS_clk_si1_fpga_A ]
create_clock -period "125.000 MHz" [ get_ports LVDS_clk_si1_fpga_B ]
create_clock -period "125.000 MHz" [ get_ports lvds_firefly_clk ]
create_clock -period "156.250 MHz" [ get_ports transceiver_pll_clock[0] ]
create_clock_if_exists "156.250 MHz" transceiver_pll_clock[1]
create_clock_if_exists "156.250 MHz" transceiver_pll_clock[2]

# derive pll clocks from base clocks
derive_pll_clocks -create_base_clocks
derive_clock_uncertainty



# MAX10 custom link runs in the dedicated 50 MHz SPI domain.
# `max10_spi_miso` is the forwarded SPI clock output from the Arria side. Model
# the MAX10 receiver with a virtual clock instead of constraining the bidir pins
# directly against the internal launch clock. This keeps the external data/clock
# relationship explicit without creating a generated clock on an output pad.

create_clock -name max10_spi_virtual_clk -period 20.000

# During MAX10 readback, the shared IO lanes return data to the Arria side
# relative to the forwarded SPI clock.
set_input_delay -clock { max10_spi_virtual_clk } -min 2.0 [get_ports {max10_spi_mosi}]
set_input_delay -clock { max10_spi_virtual_clk } -min 2.0 [get_ports {max10_spi_D1}]
set_input_delay -clock { max10_spi_virtual_clk } -min 2.0 [get_ports {max10_spi_D2}]
set_input_delay -clock { max10_spi_virtual_clk } -min 2.0 [get_ports {max10_spi_D3}]

set_input_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_mosi}]
set_input_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_D1}]
set_input_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_D2}]
set_input_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_D3}]

# During writes, the Arria side launches data and CSN toward MAX10 relative to
# the same forwarded SPI clock.
set_output_delay -clock { max10_spi_virtual_clk } -min 0.5 [get_ports {max10_spi_mosi}]
set_output_delay -clock { max10_spi_virtual_clk } -min 0.5 [get_ports {max10_spi_D1}]
set_output_delay -clock { max10_spi_virtual_clk } -min 0.5 [get_ports {max10_spi_D2}]
set_output_delay -clock { max10_spi_virtual_clk } -min 0.5 [get_ports {max10_spi_D3}]
set_output_delay -clock { max10_spi_virtual_clk } -min 0.5 [get_ports {max10_spi_csn}]

set_output_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_mosi}]
set_output_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_D1}]
set_output_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_D2}]
set_output_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_D3}]
set_output_delay -clock { max10_spi_virtual_clk } -max 10.0 [get_ports {max10_spi_csn}]

# The forwarded clock pin is not sampled by Arria logic.
set_false_path -to [get_ports {max10_spi_miso}]

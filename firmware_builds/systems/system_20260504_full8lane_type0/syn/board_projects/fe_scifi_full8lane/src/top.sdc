proc create_clock_if_exists {period target} {
    set target_ports [get_ports -nowarn $target]
    if { [get_collection_size $target_ports] > 0 } {
        create_clock -period $period $target_ports
    }
}

proc set_input_delay_if_exists {args} {
    set target_ports [lindex $args end]
    if { [get_collection_size $target_ports] > 0 } {
        eval set_input_delay $args
    }
}

proc set_output_delay_if_exists {args} {
    set target_ports [lindex $args end]
    if { [get_collection_size $target_ports] > 0 } {
        eval set_output_delay $args
    }
}

proc set_false_path_to_registers_if_exists {pattern} {
    set nodes [get_registers -nowarn $pattern]
    if { [get_collection_size $nodes] > 0 } {
        set_false_path -to $nodes
    }
}

proc set_false_path_from_registers_if_exists {pattern} {
    set nodes [get_registers -nowarn $pattern]
    if { [get_collection_size $nodes] > 0 } {
        set_false_path -from $nodes
    }
}

proc set_false_path_between_registers_if_exists {from_pattern to_pattern} {
    set from_nodes [get_registers -nowarn $from_pattern]
    set to_nodes [get_registers -nowarn $to_pattern]
    if { [get_collection_size $from_nodes] > 0 && [get_collection_size $to_nodes] > 0 } {
        set_false_path -from $from_nodes -to $to_nodes
    }
}

# Full 8-lane Type0 build targets the same board clocks as the FEB reference project, with
# the datapath-critical domains constrained at 137.5 MHz.
create_clock_if_exists 20.000 spare_clk_osc
create_clock_if_exists 20.000 systemclock_bottom
create_clock_if_exists 7.273 systemclock
create_clock_if_exists 8.000 clk_125_top
create_clock_if_exists 8.000 clk_125_bottom
create_clock_if_exists 7.273 LVDS_clk_si1_fpga_A
create_clock_if_exists 8.000 LVDS_clk_si1_fpga_B
create_clock_if_exists 8.000 lvds_firefly_clk
create_clock_if_exists 7.273 transceiver_pll_clock[0]

derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

create_clock -name max10_spi_virtual_clk -period 20.000

set_input_delay_if_exists -clock { max10_spi_virtual_clk } -min 2.0 [get_ports -nowarn {max10_spi_mosi}]
set_input_delay_if_exists -clock { max10_spi_virtual_clk } -min 2.0 [get_ports -nowarn {max10_spi_D1}]
set_input_delay_if_exists -clock { max10_spi_virtual_clk } -min 2.0 [get_ports -nowarn {max10_spi_D2}]
set_input_delay_if_exists -clock { max10_spi_virtual_clk } -min 2.0 [get_ports -nowarn {max10_spi_D3}]

set_input_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_mosi}]
set_input_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_D1}]
set_input_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_D2}]
set_input_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_D3}]

set_output_delay_if_exists -clock { max10_spi_virtual_clk } -min 0.5 [get_ports -nowarn {max10_spi_mosi}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -min 0.5 [get_ports -nowarn {max10_spi_D1}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -min 0.5 [get_ports -nowarn {max10_spi_D2}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -min 0.5 [get_ports -nowarn {max10_spi_D3}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -min 0.5 [get_ports -nowarn {max10_spi_csn}]

set_output_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_mosi}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_D1}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_D2}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_D3}]
set_output_delay_if_exists -clock { max10_spi_virtual_clk } -max 10.0 [get_ports -nowarn {max10_spi_csn}]

set max10_spi_miso_port [get_ports -nowarn {max10_spi_miso}]
if { [get_collection_size $max10_spi_miso_port] > 0 } {
    set_false_path -to $max10_spi_miso_port
}

set lvds_symbol_error_src [get_keepers -nowarn {*lvds_rx_controller_pro*|assembler_symbol_errors*}]
set lvds_symbol_error_dst [get_keepers -nowarn {*lvds_rx_controller_pro*|csr.symbol_errors*}]
if { [get_collection_size $lvds_symbol_error_src] > 0 && [get_collection_size $lvds_symbol_error_dst] > 0 } {
    set_false_path -from $lvds_symbol_error_src -to $lvds_symbol_error_dst
}

# The injector conduit is intentionally edge-detected after a two-register
# synchronizer in the emulator run-control block.
set_false_path_to_registers_if_exists {*frontend_run_ctl*|coe_inject_d1}

# LVDS controller debug/status reads sample data-clock state into the control
# CSR window. These status paths are not single-cycle datapath timing paths.
set_false_path_between_registers_if_exists {*lvds_rx_controller_pro_0*|adaptive_aligner_chosen*} {*lvds_rx_controller_pro_0*|avs_csr_readdata*}

set hub_avmm_src [get_keepers -nowarn {*sc_hub*avmm_handler*avmm_state*}]
set hub_diag_dst [get_keepers -nowarn {*sc_hub*core_inst*ext_write_diag_data_hold*}]
if { [get_collection_size $hub_avmm_src] > 0 && [get_collection_size $hub_diag_dst] > 0 } {
    set_false_path -from $hub_avmm_src -to $hub_diag_dst
}

set rst_ctrl_src [get_keepers -nowarn {*rst_controller*rst_controller*r_sync_rst}]
if { [get_collection_size $rst_ctrl_src] > 0 } {
    set_false_path -from $rst_ctrl_src
}
set_false_path_from_registers_if_exists {*rst_controller*|r_sync_rst}
set_false_path_from_registers_if_exists {*altera_reset_synchronizer_int_chain_out}

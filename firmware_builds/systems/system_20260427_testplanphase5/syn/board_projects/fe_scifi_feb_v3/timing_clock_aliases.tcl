proc mu3e_clock_alias_keys {} {
    return [list \
        lvds_rx_clock \
        lvds_tx_clock \
        xcvr_rx_clock \
        xcvr_tx_clock \
        mutrig_spi_master_clock \
        max10_spi_virtual_clock \
        free_running_clock \
        altera_jtag_clock \
    ]
}

proc mu3e_clock_alias_spec {key} {
    switch -- $key {
        lvds_rx_clock {
            return [dict create \
                label {lvds rx clock} \
                primary_patterns [list \
                    {*|lvds_rx_28nm_0|*|pll_sclk~PLL_OUTPUT_COUNTER|divclk} \
                    {lvds_rx_clock} \
                ] \
                report_patterns [list \
                    {*|lvds_rx_28nm_0|*|pll_sclk~PLL_OUTPUT_COUNTER|divclk} \
                    {lvds_rx_clock} \
                ] \
                domain {data_path_subsystem via lvds_rx_28nm_0; LVDS RX datapath, CSR bridge, and Merlin interconnect.} \
            ]
        }
        lvds_tx_clock {
            return [dict create \
                label {lvds tx clock} \
                primary_patterns [list {lvds_tx_clock} {lvds_firefly_clk}] \
                report_patterns [list {lvds_tx_clock} {lvds_firefly_clk}] \
                domain {Board-side 125 MHz LVDS / monitor clock; q_feb_system mclk125_clk and top-level 125 MHz monitor/debug logic.} \
            ]
        }
        xcvr_rx_clock {
            return [dict create \
                label {xcvr rx clock} \
                primary_patterns [list {*|inst_av_hssi_8g_rx_pcs|wys|rcvdclkpma}] \
                report_patterns [list {*|inst_av_hssi_8g_rx_pcs|wys|rcvdclkpma}] \
                domain {Firefly receive PCS lane clocks inside e_xcvr1; one generated RX clock per recovered-lane domain.} \
            ]
        }
        xcvr_tx_clock {
            return [dict create \
                label {xcvr tx clock} \
                primary_patterns [list {xcvr_tx_clock} {transceiver_pll_clock[0]}] \
                report_patterns [list {xcvr_tx_clock} {transceiver_pll_clock[0]} {*|inst_av_hssi_8g_tx_pcs|wys|txpmalocalclk}] \
                domain {156.25 MHz transceiver reference / user clock; q_feb_system cclk156_clk and FE Firefly transmit-side logic.} \
            ]
        }
        mutrig_spi_master_clock {
            return [dict create \
                label {mutrig spi master clock} \
                primary_patterns [list {*|control_path_subsystem|pll_156t40|*|PLL_OUTPUT_COUNTER|divclk}] \
                report_patterns [list {*|control_path_subsystem|pll_156t40|*|PLL_OUTPUT_COUNTER|divclk}] \
                domain {control_path_subsystem pll_156t40 outclk_0; mutrig_cfg_ctrl_0:i_clk_spi and related slow-control logic.} \
            ]
        }
        max10_spi_virtual_clock {
            return [dict create \
                label {max10 spi virtual clock} \
                primary_patterns [list {max10_spi_virtual_clock} {max10_spi_virtual_clk}] \
                report_patterns [list {max10_spi_virtual_clock} {max10_spi_virtual_clk}] \
                domain {Virtual external timing clock for the MAX10 SPI link timing model on max10_link_* IO.} \
            ]
        }
        free_running_clock {
            return [dict create \
                label {free running clock} \
                primary_patterns [list {free_running_clock} {spare_clk_osc}] \
                report_patterns [list {free_running_clock} {spare_clk_osc}] \
                domain {Always-on 50 MHz oscillator; board reset holdoff, MAX10 link clocking, and oscillator-fed housekeeping logic.} \
            ]
        }
        altera_jtag_clock {
            return [dict create \
                label {altera jtag clock} \
                primary_patterns [list {altera_reserved_tck}] \
                report_patterns [list {altera_reserved_tck}] \
                domain {Quartus/JTAG debug clock for the Nios and JTAG master/debug fabric.} \
            ]
        }
        default {
            error "Unknown clock alias key: $key"
        }
    }
}

proc mu3e_clock_alias_label {key} {
    return [dict get [mu3e_clock_alias_spec $key] label]
}

proc mu3e_clock_alias_domain {key} {
    return [dict get [mu3e_clock_alias_spec $key] domain]
}

proc mu3e_clock_alias_primary {key} {
    set spec [mu3e_clock_alias_spec $key]
    foreach pattern [dict get $spec primary_patterns] {
        set clocks [get_clocks -nowarn $pattern]
        if {[get_collection_size $clocks] > 0} {
            return $clocks
        }
    }
    return [get_clocks -nowarn]
}

proc mu3e_clock_alias_names {key} {
    set names {}
    set spec [mu3e_clock_alias_spec $key]
    foreach pattern [dict get $spec report_patterns] {
        foreach_in_collection clk [get_clocks -nowarn $pattern] {
            set name [get_clock_info -name $clk]
            if {[lsearch -exact $names $name] < 0} {
                lappend names $name
            }
        }
    }
    return [lsort -dictionary $names]
}

proc mu3e_clock_alias_periods {key} {
    set periods {}
    foreach name [mu3e_clock_alias_names $key] {
        set clk [get_clocks -nowarn [list $name]]
        if {[get_collection_size $clk] == 0} {
            continue
        }
        set period [get_clock_info -period $clk]
        if {$period eq ""} {
            continue
        }
        if {[lsearch -exact $periods $period] < 0} {
            lappend periods $period
        }
    }
    return [lsort -real $periods]
}

proc mu3e_clock_alias_frequency_strings {key} {
    set freqs {}
    foreach period [mu3e_clock_alias_periods $key] {
        if {$period <= 0.0} {
            continue
        }
        set mhz [expr {1000.0 / $period}]
        lappend freqs [format %.3f $mhz]
    }
    return $freqs
}

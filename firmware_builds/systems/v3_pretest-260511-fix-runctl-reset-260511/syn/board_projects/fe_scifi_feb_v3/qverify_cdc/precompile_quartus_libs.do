foreach lib {altera lpm altera_mf sgate} {
    if {[catch {vlib $lib} msg]} { puts "vlib $lib: $msg" }
    vmap $lib $lib
}

vcom -2008 -work altera {/data1/intelFPGA/18.1/quartus/eda/sim_lib/altera_primitives_components.vhd}
vcom -2008 -work altera {/data1/intelFPGA/18.1/quartus/eda/sim_lib/altera_primitives.vhd}

vcom -2008 -work lpm {/data1/intelFPGA/18.1/quartus/eda/sim_lib/220pack.vhd}
vcom -2008 -work lpm {/data1/intelFPGA/18.1/quartus/eda/sim_lib/220model.vhd}

vcom -2008 -work altera_mf {/data1/intelFPGA/18.1/quartus/eda/sim_lib/altera_mf_components.vhd}
vcom -2008 -work altera_mf {/data1/intelFPGA/18.1/quartus/eda/sim_lib/altera_mf.vhd}

vcom -2008 -work sgate {/data1/intelFPGA/18.1/quartus/eda/sim_lib/sgate_pack.vhd}
vcom -2008 -work sgate {/data1/intelFPGA/18.1/quartus/eda/sim_lib/sgate.vhd}

set plain_verilog_list {/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511/syn/board_projects/fe_scifi_feb_v3/qverify_cdc/feb_v3_qsys_plain_verilog.f}
if {[file exists $plain_verilog_list]} {
    set fp [open $plain_verilog_list r]
    set plain_verilog_sources [split [read $fp] "\n"]
    close $fp
    foreach source $plain_verilog_sources {
        if {$source ne ""} {
            vlog -work work $source
        }
    }
}

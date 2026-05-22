# patch_scifi_datapath_v4_frame_deassembly_csr.tcl
#
# Incrementally expose each mutrig_datapath_system_v4 frame-deassembly CSR.
# The mutrig_datapath_system_v4 subsystem already exports this CSR as
# mutrig_datapath_subsystem_N.csr, but scifi_datapath_system_v4 did not map it.
#
# The patch keeps the existing Qsys topology intact and only adds Avalon-MM
# master/slave connections:
#   - master_datapath.master for data-path JTAG debug
#   - the existing SC-facing mm_pipeline_lvds_csr_* windows for sc_hub access

set ::jtag_master master_datapath.master

proc has_connection {path} {
    return [expr {[lsearch -exact [get_connections] $path] >= 0}]
}

proc remove_connection_if_present {path} {
    if {[has_connection $path]} {
        remove_connection $path
    }
}

proc map_csr_once {master slave base} {
    remove_connection_if_present ${master}/${slave}
    add_connection $master $slave
    set_connection_parameter_value ${master}/${slave} arbitrationPriority 1
    set_connection_parameter_value ${master}/${slave} baseAddress $base
    set_connection_parameter_value ${master}/${slave} defaultConnection false
}

for {set k 0} {$k < 8} {incr k} {
    set slave mutrig_datapath_subsystem_${k}.csr

    if {$k == 0} {
        set jtag_base 0x88A0
        set sc_master mm_pipeline_lvds_csr_low.m0
        set sc_base 0x10A0
    } elseif {$k == 1} {
        set jtag_base 0x18A0
        set sc_master mm_pipeline_lvds_csr_low.m0
        set sc_base 0x18A0
    } elseif {$k == 2} {
        set jtag_base 0x28A0
        set sc_master mm_pipeline_lvds_csr_emu_dbg.m0
        set sc_base 0x08A0
    } elseif {$k == 4} {
        set jtag_base 0x48A0
        set sc_master mm_pipeline_lvds_csr_mutrig4_mts0.m0
        set sc_base 0x08A0
    } else {
        set jtag_base [format "0x%04X" [expr {$k * 0x1000 + 0x08A0}]]
        set sc_master mm_pipeline_lvds_csr_mutrig${k}.m0
        set sc_base 0x08A0
    }

    map_csr_once $::jtag_master $slave $jtag_base
    map_csr_once $sc_master $slave $sc_base

    puts [format "FRAME_DEASSEMBLY_CSR lane=%d jtag=%s sc_master=%s sc_local=%s" \
        $k $jtag_base $sc_master $sc_base]
}

save_system

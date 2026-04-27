# mutrig_injector_multiheader.sdc
#
# CDC timing intent for the explicit mode-3 oscillator crossing between:
# - the 125 MHz CSR/MuTRiG clock domain
# - the free-running oscillator clock domain
#
# These constraints target only the dedicated shadow/register synchronizers
# inside mutrig_injector_multiheader. They do not globally cut the two clocks.

proc mih_get_registers_any {patterns} {
    set nodes [get_registers -nowarn __mih_no_match__]
    foreach pattern $patterns {
        set matches [get_registers -nowarn $pattern]
        if {[get_collection_size $matches] > 0} {
            set nodes [add_to_collection $nodes $matches]
        }
    }
    return $nodes
}

proc mih_apply_false_path_pair {from_nodes to_nodes} {
    if {[get_collection_size $from_nodes] > 0 && [get_collection_size $to_nodes] > 0} {
        set_false_path -from $from_nodes -to $to_nodes
    }
}

proc constrain_mih_mode3_cdc {} {
    if {[catch {get_registers -nowarn __mih_probe__}]} {
        return
    }

    set cfg_req_src [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_cfg_req
    }]
    set cfg_req_meta [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_cfg_meta
    }]
    set mode_src [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_mode_shadow[*]
        *|mutrig_injector_multiheader:*|csr.mode[*]
    }]
    set mode_meta [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_mode_meta[*]
    }]
    set interval_src [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_interval_shadow[*]
        *|mutrig_injector_multiheader:*|csr.pulse_interval[*]
    }]
    set interval_meta [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_interval_meta[*]
    }]
    set high_src [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_high_cycles_shadow[*]
        *|mutrig_injector_multiheader:*|csr.pulse_high_cycles[*]
    }]
    set high_meta [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_high_cycles_meta[*]
    }]
    set rst_syncs [mih_get_registers_any {
        *|mutrig_injector_multiheader:*|periodic_async_rst_meta
        *|mutrig_injector_multiheader:*|periodic_async_rst
    }]

    mih_apply_false_path_pair $cfg_req_src   $cfg_req_meta
    mih_apply_false_path_pair $mode_src      $mode_meta
    mih_apply_false_path_pair $interval_src  $interval_meta
    mih_apply_false_path_pair $high_src      $high_meta

    if {[get_collection_size $rst_syncs] > 0} {
        set_false_path -to $rst_syncs
    }
}

constrain_mih_mode3_cdc

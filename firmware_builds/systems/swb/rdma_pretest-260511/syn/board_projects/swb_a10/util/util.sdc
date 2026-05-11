#

# ff_sync
# see altera handshake_clock_crosser
foreach e [ get_entity_instances -nowarn "ff_sync" ] {
    set to_regs [ get_registers -nocase -nowarn "$e|ff[0]*" ]
    set size [ get_collection_size $to_regs ]
    if { $size > 0 } {
        #set_false_path -to $to_regs
        # avoid set_false_path to allow set_max_skew
        set_min_delay -to $to_regs -100
        set_max_delay -to $to_regs 100
    }
    if { $size > 1 } {
        set_max_skew -to $to_regs -get_skew_value_from_clock_period dst_clock_period -skew_value_multiplier 0.8
    }
}

# reset_sync
# see altera_reset_controller.sdc
foreach e [ get_entity_instances -nowarn "reset_sync" ] {
    set aclr_pins [ get_pins -compatibility_mode -nocase -nowarn "$e|*|aclr" ]
    set clrn_pins [ get_pins -compatibility_mode -nocase -nowarn "$e|*|clrn" ]
    set clr_pins [ add_to_collection $aclr_pins $clrn_pins ]
    set size [ get_collection_size $clr_pins ]

    if { $size > 0 } {
        #set_false_path -to $clr_pins
        # avoid set_false_path to allow set_max_skew
        set_min_delay -to $clr_pins -100
        set_max_delay -to $clr_pins 100
    }
    if { $size > 1 } {
        set_max_skew -to $clr_pins -get_skew_value_from_clock_period dst_clock_period -skew_value_multiplier 0.8
    }
}

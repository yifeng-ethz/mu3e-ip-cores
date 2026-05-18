#

foreach e [ concat \
    [ get_entity_instances -nowarn xcvr_enh ] \
] {
    set to_regs [ get_registers ${e}|av_ctrl.readdata* ]
    set fanins [ get_fanins $to_regs ]

    set_min_delay -from $fanins -to $to_regs -100
    set_max_delay -from $fanins -to $to_regs 100
}

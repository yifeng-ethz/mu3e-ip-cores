#

foreach e [ get_entity_instances -nowarn "a10_block" ] {
    # state registers for monitoring
    set_false_path -from *:$e|a10_reset_link:*|o_state_out* -to *:$e|*
}

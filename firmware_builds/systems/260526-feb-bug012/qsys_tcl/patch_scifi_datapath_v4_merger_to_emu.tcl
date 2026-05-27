# patch_scifi_datapath_v4_merger_to_emu.tcl
#
# Re-route the 8 merger_hit_type0 outputs from arb.real_in_K to arb.emu_in_K
# and flip the arb to EMU pass-through (MODE_DEFAULT=1).
#
# Why: the merger chain is proven (emulator->merger->arb.real_in_K all carry
# the same beats in sim, cfg_source_is_emu=1), but the arb's REAL ingress path
# does not egress real_in in sim -- it is gated on a real-LVDS frame condition
# absent in sim. The arb's EMU path is the proven one (prior working builds fed
# emu_in with MODE=EMU and the arb forwarded ~200k hits). So feed the merged
# stream into emu_in and select EMU.
#
#   BEFORE: merger_K.out -> arb.real_in_K ; arb MODE_DEFAULT=0 (REAL)
#   AFTER:  merger_K.out -> arb.emu_in_K  ; arb MODE_DEFAULT=1 (EMU)
#           arb.real_in_K left unconnected (unconnected readyless sink ->
#           benign warning, no adapter). Do NOT add avst_inactive_source
#           terminators -- they caused inPortErrorWidth adapter failures.
#
# Edit method: targeted remove_connection / add_connection /
# set_instance_parameter_value. No from-scratch rebuild. The caller has
# already load_system'd the target .qsys.

set ::arb arb_hit_type0_supercore_0

proc has_connection {path} {
    return [expr {[lsearch -exact [get_connections] $path] >= 0}]
}

for {set k 0} {$k < 8} {incr k} {
    set m merger_${k}
    # Drop merger_K.out -> arb.real_in_K
    set old ${m}.out/${::arb}.real_in_${k}
    if {[has_connection $old]} {
        puts "APPLY remove_connection $old"
        remove_connection $old
    }
    # Add merger_K.out -> arb.emu_in_K
    set new ${m}.out/${::arb}.emu_in_${k}
    if {![has_connection $new]} {
        puts "APPLY add_connection ${m}.out ${::arb}.emu_in_${k}"
        add_connection ${m}.out ${::arb}.emu_in_${k} avalon_streaming
    }
}

# Flip arb to EMU pass-through.
puts "APPLY set_instance_parameter_value $::arb MODE_DEFAULT 1"
set_instance_parameter_value $::arb MODE_DEFAULT 1

puts "APPLY save_system"
save_system
# NOTE: save_system resets the system component version to 1.0; the caller
# restores it to 26.4.1.0521 by text-patching the saved .qsys.

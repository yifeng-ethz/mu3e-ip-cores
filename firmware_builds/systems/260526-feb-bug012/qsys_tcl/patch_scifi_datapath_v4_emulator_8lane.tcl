# patch_scifi_datapath_v4_emulator_8lane.tcl
#
# Rewire the FEB v3/v4 emulator-type0 datapath from the broadcast-fanout
# topology to a true independent 8-ASIC path:
#
#   OLD:  emulator_mutrig_qsys_inst.hit_type0 -> emulator_hit_type0_fanout.in
#         emulator_hit_type0_fanout.out{k}    -> arb_hit_type0_supercore_0.emu_in_{k}
#         (one real lane broadcast to 8 arb inputs, data[44:41]=lane_id mimic)
#
#   NEW:  emulator_mutrig_qsys_inst.hit_type0_{k} -> arb_hit_type0_supercore_0.emu_in_{k}
#         (eight independent asic-tagged lane sources; lane k = ASIC k)
#
# The emulator instance is re-pinned to emulator_mutrig 26.3.4.520 (the
# 8-lane emulator_mutrig_qsys8 top wrapper). The fanout instance and its
# connections are removed (RTL file is kept on disk; only removed from the
# system). Run via qsys-script load_system <scifi.qsys> ... save_system.
# (qsys package is already loaded by the calling apply_emulator_8lane.tcl)

set ::emu_inst emulator_mutrig_qsys_inst
set ::fanout_inst emulator_hit_type0_fanout

proc has_instance {name} {
    return [expr {[lsearch -exact [get_instances] $name] >= 0}]
}

proc has_connection {path} {
    return [expr {[lsearch -exact [get_connections] $path] >= 0}]
}

proc remove_connection_if_present {path} {
    if {[has_connection $path]} {
        remove_connection $path
    }
}

proc add_connection_once {start end} {
    remove_connection_if_present ${start}/${end}
    add_connection $start $end
}

# 1. Drop the broadcast fanout feed + its 8 outputs into the arbiter, plus
#    the fanout's clock/reset. The instance itself is then removed.
remove_connection_if_present ${::emu_inst}.hit_type0/${::fanout_inst}.in
for {set lane 0} {$lane < 8} {incr lane} {
    remove_connection_if_present ${::fanout_inst}.out${lane}/arb_hit_type0_supercore_0.emu_in_${lane}
}
foreach c [get_connections] {
    if {[string match "*${::fanout_inst}.*" $c]} {
        remove_connection $c
    }
}
if {[has_instance $::fanout_inst]} {
    remove_instance $::fanout_inst
}

# 2. The emulator instance kind is unchanged (emulator_mutrig); save_system
#    re-pins it to the current catalog version (26.3.6.520, the 8-lane
#    emulator_mutrig_qsys8 wrapper with SIGNAL single-channel mode)
#    automatically. Keep the 8-ASIC geometry and version provenance coherent.
catch {set_instance_parameter_value $::emu_inst CLUSTER_LANE_COUNT_DEFAULT 8}
catch {set_instance_parameter_value $::emu_inst VERSION_PATCH 6}
catch {set_instance_parameter_value $::emu_inst BUILD 520}
catch {set_instance_parameter_value $::emu_inst VERSION_DATE 20260520}

# 3. Wire the eight independent lane sources directly to the arbiter
#    emu inputs: lane k (ASIC k) -> emu_in_k.
for {set lane 0} {$lane < 8} {incr lane} {
    add_connection_once ${::emu_inst}.hit_type0_${lane} arb_hit_type0_supercore_0.emu_in_${lane}
}

save_system

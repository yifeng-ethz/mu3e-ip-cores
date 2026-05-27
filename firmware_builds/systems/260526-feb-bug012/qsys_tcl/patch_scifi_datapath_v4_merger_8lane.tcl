# patch_scifi_datapath_v4_merger_8lane.tcl
#
# Rewire the FEB v3/v4 emulator-type0 datapath to the owner-approved
# 8-lane MERGER topology:
#
#   OLD (stale / pre-8-lane):
#     emulator_mutrig_qsys_inst (kind emulator_mutrig, single hit_type0 src)
#       .hit_type0 -> emulator_hit_type0_fanout.in
#     emulator_hit_type0_fanout.out{k} -> arb.emu_in_{k}   (broadcast)
#     mutrig_datapath_subsystem_{k}.hit_type0_out -> arb.real_in_{k} (direct)
#     arb does the per-lane real/emu 2:1 select internally.
#
#   NEW (this patch):
#     emulator_mutrig_qsys_inst now exposes 8 per-lane sources hit_type0_{k}
#       (same catalog kind emulator_mutrig; TOP_LEVEL emulator_mutrig_qsys8).
#     merger_{k}.emu_in  <- emulator_mutrig_qsys_inst.hit_type0_{k}
#     merger_{k}.real_in <- mutrig_datapath_subsystem_{k}.hit_type0_out
#     merger_{k}.out     -> arb.real_in_{k}
#     arb MODE_DEFAULT=0 (REAL pass-through) forwards real_in_{k} (= merged).
#     arb.emu_in_{k} now unused -> terminate with avst_inactive_source_{k}.
#     emulator_hit_type0_fanout removed.
#
# Edit method: targeted add/remove_instance, add/remove_connection,
# set_instance_parameter_value. No from-scratch rebuild. The caller
# (apply_merger_8lane.tcl) has already load_system'd the target .qsys.

set ::emu_inst    emulator_mutrig_qsys_inst
set ::fanout_inst emulator_hit_type0_fanout
set ::arb         arb_hit_type0_supercore_0
set ::clk_src     mu3e_lvds_controller_0.outclock
set ::rst_src     monitor_reset_sync.reset_out
set ::csr_master  master_datapath.master

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

# ---------------------------------------------------------------------------
# 1. Remove the broadcast fanout: feed, 8 outputs into arb, clk/rst, instance.
# ---------------------------------------------------------------------------
remove_connection_if_present ${::emu_inst}.hit_type0/${::fanout_inst}.in
for {set k 0} {$k < 8} {incr k} {
    remove_connection_if_present ${::fanout_inst}.out${k}/${::arb}.emu_in_${k}
}
foreach c [get_connections] {
    if {[string match "*${::fanout_inst}.*" $c]} {
        remove_connection $c
    }
}
if {[has_instance $::fanout_inst]} {
    remove_instance $::fanout_inst
}

# ---------------------------------------------------------------------------
# 2. Remove the old direct real_in feeds (now routed through the mergers).
# ---------------------------------------------------------------------------
for {set k 0} {$k < 8} {incr k} {
    remove_connection_if_present \
        mutrig_datapath_subsystem_${k}.hit_type0_out/${::arb}.real_in_${k}
}

# ---------------------------------------------------------------------------
# 3. Emulator instance: keep catalog kind emulator_mutrig (now the 8-lane
#    emulator_mutrig_qsys8 wrapper). Pin 8-ASIC geometry coherent with the
#    working cache build. ASIC_ID_DEFAULT=0 (lane k carries asic_id base+k
#    inside the core).
# ---------------------------------------------------------------------------
catch {set_instance_parameter_value $::emu_inst CLUSTER_LANE_COUNT_DEFAULT 8}
catch {set_instance_parameter_value $::emu_inst ASIC_ID_DEFAULT 0}
catch {set_instance_parameter_value $::emu_inst VERSION_PATCH 6}
catch {set_instance_parameter_value $::emu_inst BUILD 520}
catch {set_instance_parameter_value $::emu_inst VERSION_DATE 20260520}

# ---------------------------------------------------------------------------
# 4. Add 8 merger_hit_type0 instances and 8 avst_inactive_source tie-offs.
#    merger CSR base = 0x2400 + k*0x80 (verified free: 0x2400..0x27FF, the
#    gap between arb.csr_7 @0x2380 and mutrig_datapath_subsystem_2 @0x2860).
# ---------------------------------------------------------------------------
for {set k 0} {$k < 8} {incr k} {
    set m  merger_${k}
    set ti avst_inactive_emu_${k}

    # --- merger instance ---
    if {![has_instance $m]} {
        add_instance $m merger_hit_type0
    }
    set_instance_parameter_value $m DATA_WIDTH          45
    set_instance_parameter_value $m CHANNEL_WIDTH       4
    set_instance_parameter_value $m ERROR_WIDTH         3
    set_instance_parameter_value $m SOURCE_SEL_DEFAULT  1
    set_instance_parameter_value $m INSTANCE_ID         $k

    # merger clk/rst
    add_connection_once $::clk_src ${m}.clk
    add_connection_once $::rst_src ${m}.rst

    # merger data: emu_in <- emulator lane k ; real_in <- mutrig lane k
    add_connection_once ${::emu_inst}.hit_type0_${k}          ${m}.emu_in
    add_connection_once mutrig_datapath_subsystem_${k}.hit_type0_out ${m}.real_in

    # merger out -> arb.real_in_k  (arb MODE_DEFAULT=0 forwards real_in)
    add_connection_once ${m}.out ${::arb}.real_in_${k}

    # merger csr -> master_datapath.master @ 0x2400 + k*0x80
    set base [format "0x%04x" [expr {0x2400 + $k * 0x80}]]
    remove_connection_if_present ${::csr_master}/${m}.csr
    add_connection $::csr_master ${m}.csr
    set_connection_parameter_value ${::csr_master}/${m}.csr baseAddress $base
    set_connection_parameter_value ${::csr_master}/${m}.csr arbitrationPriority 1
    set_connection_parameter_value ${::csr_master}/${m}.csr defaultConnection false

    # --- avst_inactive_source tie-off for the now-unused arb.emu_in_k ---
    if {![has_instance $ti]} {
        add_instance $ti avst_inactive_source
    }
    set_instance_parameter_value $ti DATA_WIDTH    45
    set_instance_parameter_value $ti CHANNEL_WIDTH 4
    set_instance_parameter_value $ti USE_PACKETS   1
    add_connection_once $::clk_src ${ti}.clk
    add_connection_once $::rst_src ${ti}.rst
    add_connection_once ${ti}.out ${::arb}.emu_in_${k}
}

# ---------------------------------------------------------------------------
# 5. Keep arb pass-through (REAL).
# ---------------------------------------------------------------------------
set_instance_parameter_value $::arb MODE_DEFAULT 0

save_system

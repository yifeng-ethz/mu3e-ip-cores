# patch_scifi_datapath_v4_hist_arrival_gts.tcl
# Surgical qsys-script patch (gts-unify, BUG-012): connect each MTS preprocessor's
# arrival-GTS conduit to the histogram's bank-matched arrival-GTS sink, so the
# delay-mode key subtracts emission ts (coe_hit_type1_ts) and arrival gts
# (coe_hit_arrival_gts_8n) from ONE MTS counter epoch instead of the histogram's
# own independently-SYNC-zeroed gts_8n (which was removed). This fixes the random
# per-SYNC ~2^20 delay-peak offset (measured centers -1028096/+39024/-71680/+678912).
#
#   mts_preprocessor_0 (BANK=UP) .hit_arrival_gts -> histogram_statistics_0.type1_up_gts
#   mts_preprocessor_1 (BANK=DW) .hit_arrival_gts -> histogram_statistics_0.type1_down_gts
#
# Requires (already done in canonical RTL + hw.tcl):
#   mts_processor_hw.tcl     : add_interface hit_arrival_gts conduit (Output 48), v26.3.14
#   histogram_statistics_v2_hw.tcl : type1_up_gts / type1_down_gts conduit sinks (Input 48), v26.4.3
#
# Mirrors qsys_tcl/patch_scifi_datapath_v4_hist_type1_extended.tcl. Apply during
# the qsys-from-tcl flow, AFTER the subsystem .qsys is seeded and BEFORE qsys-syn:
#   qsys-script --search-path=<active IP dirs>,$ \
#       --script=patch_scifi_datapath_v4_hist_arrival_gts.tcl \
#       <generated/qsys/scifi_datapath_system_v4.qsys>
package require -exact qsys 18.1
if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
puts "patch_hist_arrival_gts: load_system $qsys_path"
load_system $qsys_path
# add_connection is idempotent (no-op on duplicate); wrap in catch so a re-run
# after the connection already exists does not abort.
catch {add_connection mts_preprocessor_0.hit_arrival_gts \
        histogram_statistics_0.type1_up_gts conduit}
catch {add_connection mts_preprocessor_1.hit_arrival_gts \
        histogram_statistics_0.type1_down_gts conduit}
puts "patch_hist_arrival_gts: save_system $qsys_path"
save_system
puts "patch_hist_arrival_gts: done"

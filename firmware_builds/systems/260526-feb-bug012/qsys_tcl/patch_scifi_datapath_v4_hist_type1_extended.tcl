# patch_scifi_datapath_v4_hist_type1_extended.tcl
# Surgical qsys-script patch: connect the MTS preprocessor extended
# Type1 sources to the histogram extended sinks.
#   mts_preprocessor_0 (BANK=UP)  .hit_type1_extended_0
#       -> histogram_statistics_0.hit_type1_extended_0
#   mts_preprocessor_1 (BANK=DW)  .hit_type1_extended_1
#       -> histogram_statistics_0.hit_type1_extended_1
#
# The hist extended sinks (asi_hit_type1_extended_0/1) carry the readyless
# 87-bit debug-plane word (data[86:39]=true ts, data[38:0]=Type1 payload)
# and are selected onto histogram port 0 when CONTROL.in_port = EXT0/EXT1.
# Before this patch the hist entity declared the ports but the qsys never
# connected them (and the hw.tcl never advertised them), so the wrapper-only
# tb_int caught a vopt-1130 bind failure (entity port not in component).
#
# Invoke as:
#   qsys-script --search-path=... \
#       --script=<this file> <scifi_datapath_system_v4.qsys path>

package require -exact qsys 18.1

if {$argc < 1} {
    puts "ERROR: missing .qsys path argument"
    exit 1
}
set qsys_path [lindex $argv 0]
puts "patch_hist_type1_extended: load_system $qsys_path"
load_system $qsys_path

# add_connection is idempotent (no-op on duplicates); wrap in catch so a
# re-run after the connection already exists does not abort.
catch {add_connection mts_preprocessor_0.hit_type1_extended_0 \
        histogram_statistics_0.hit_type1_extended_0 avalon_streaming}
catch {add_connection mts_preprocessor_1.hit_type1_extended_1 \
        histogram_statistics_0.hit_type1_extended_1 avalon_streaming}

puts "patch_hist_type1_extended: save_system $qsys_path"
save_system

puts "patch_hist_type1_extended: done"

package require ::quartus::project

project_open top

set out_path [file normalize "qverify_cdc/feb_v3_quartus_flat_sources.f"]
set out [open $out_path w]
set qsys_out_path [file normalize "qverify_cdc/feb_v3_qsys_sources.f"]
set qsys_out [open $qsys_out_path w]

foreach name {VHDL_FILE VERILOG_FILE SYSTEMVERILOG_FILE} {
    foreach_in_collection assignment [get_all_global_assignments -name $name] {
        set source [lindex $assignment 2]
        set normalized [file normalize $source]
        puts "$name $normalized"
        puts $out $normalized
        if {[string first "/firmware_builds/systems/v3_pretest-260511/syn/feb_system_v3/synthesis/" $normalized] >= 0} {
            puts $qsys_out $normalized
        }
    }
}

close $out
close $qsys_out
puts "WROTE $out_path"
puts "WROTE $qsys_out_path"

project_close

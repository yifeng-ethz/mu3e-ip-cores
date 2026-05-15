package require -exact qsys 18.1

if {![info exists env(SYSTEM_DIR)]} {
    error "SYSTEM_DIR is not set"
}

set top_description {Dual-port histogram topology: scifi_datapath_system_v3 and scifi_datapath_system_v3_pipe feed histogram_statistics_v2 from both mts_preprocessor banks, with histogram_statistics_0.N_PORTS=2, one histogram_ingress_bridge per ASIC bank, and readyless hit_type0 muxes into each mts_preprocessor. Carries the emulator-type0 BYTE_STREAM_ENABLE=false fanout, rc-readyless sinks, and SC-WEDGE reset fix from 3.0.4.0512.}
set datapath_description {Dual-port histogram topology: histogram_statistics_0.N_PORTS=2, histogram_ingress_bridge_0 feeds lanes 0..3 from mts_preprocessor_0, histogram_ingress_bridge_1 feeds lanes 4..7 from mts_preprocessor_1, and both hit_type0 muxes are readyless to avoid Qsys timing_adapter insertion on the arb-to-MTS path.}

proc update_component_metadata {path version description} {
    if {![file exists $path]} {
        puts "INFO: metadata target not present: $path"
        return
    }

    exec chmod u+w $path
    set fd [open $path r]
    set text [read $fd]
    close $fd

    regsub {^<\?xml version="[^"]*"} $text {<?xml version="1.0"} text

    set comp_idx [string first "<component" $text]
    if {$comp_idx < 0} {
        error "No component header found in $path"
    }
    set ver_idx [string first {version="} $text $comp_idx]
    if {$ver_idx < 0} {
        error "No component version attribute found in $path"
    }
    set value_start [expr {$ver_idx + [string length {version="}]}]
    set value_end [string first {"} $text $value_start]
    if {$value_end < 0} {
        error "Unterminated component version attribute in $path"
    }
    set text [string replace $text $value_start [expr {$value_end - 1}] $version]

    regsub {description="[^"]*"} $text [format {description="%s"} $description] text

    set fd [open $path w]
    puts -nonewline $fd $text
    close $fd
    exec chmod a-w $path
    puts "INFO: updated qsys metadata: $path"
}

update_component_metadata \
    [file join $env(SYSTEM_DIR) syn feb_system_v3.qsys] \
    "3.0.5.0512" \
    $top_description

foreach path [list \
    [file join $env(SYSTEM_DIR) quartus_systems scifi_datapath_system_v3.qsys] \
    [file join $env(SYSTEM_DIR) quartus_systems scifi_datapath_system_v3_pipe.qsys] \
] {
    update_component_metadata $path "3.0.5.0512" $datapath_description
}

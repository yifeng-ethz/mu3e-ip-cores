package require -exact qsys 18.1

if {![info exists env(SYSTEM_DIR)]} {
    error "SYSTEM_DIR is not set"
}

set system_dir $env(SYSTEM_DIR)
set files [list \
    [file join $system_dir quartus_systems scifi_datapath_system_v3.qsys] \
    [file join $system_dir syn feb_system_v3.qsys] \
]

proc update_qsys_description {path} {
    if {![file exists $path]} {
        puts "INFO: description target not present: $path"
        return
    }

    exec chmod u+w $path

    set fd [open $path r]
    set text [read $fd]
    close $fd

    set updated [string map [list \
        "Emulator instances now set BYTE_STREAM_ENABLE=true for the tx8b1k decoded-lane mux contract." \
        "Emulator type0 build uses BYTE_STREAM_ENABLE=false; one emulator_mutrig emits clustered type0 hits into hit_type0_fanout8." \
        "Data-path subsystem now uses scifi_datapath_system_v3 3.0.4.0512 with BYTE_STREAM_ENABLE=true for emulator tx8b1k outputs." \
        "Data-path subsystem now uses scifi_datapath_system_v3 3.0.4.0512 with BYTE_STREAM_ENABLE=false and emulator-type0 fanout." \
    ] $text]

    if {![string equal $updated $text]} {
        set fd [open $path w]
        puts -nonewline $fd $updated
        close $fd
        puts "INFO: updated qsys description: $path"
    } else {
        puts "INFO: qsys description already current: $path"
    }

    exec chmod a-w $path
}

foreach path $files {
    update_qsys_description $path
}

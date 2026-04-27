namespace eval ::board_test::jtag {
    variable default_service_tag "board_test"
}

proc ::board_test::jtag::hex32 {value} {
    return [format "0x%08X" [expr {$value & 0xFFFFFFFF}]]
}

proc ::board_test::jtag::puts_result {prefix kvs} {
    set words [list $prefix]
    foreach {k v} $kvs {
        lappend words "${k}=${v}"
    }
    puts [join $words " "]
}

proc ::board_test::jtag::fatal {code status msg} {
    ::board_test::jtag::puts_result "JTAG_RESULT" [list status $status code $code msg "{$msg}"]
    error "JTAG_FATAL code=$code status=$status msg=$msg"
}

proc ::board_test::jtag::parse_u32 {text} {
    if {![string length $text]} {
        error "empty integer"
    }
    if {[scan $text %i value] != 1} {
        error "invalid integer '$text'"
    }
    if {$value < 0 || $value > 0xFFFFFFFF} {
        error "integer out of range '$text'"
    }
    return $value
}

proc ::board_test::jtag::parse_args {argv option_names flag_names} {
    array set opts {}
    foreach name $option_names {
        set opts($name) ""
    }
    foreach name $flag_names {
        set opts($name) 0
    }

    set positional [list]
    set idx 0
    while {$idx < [llength $argv]} {
        set arg [lindex $argv $idx]
        if {[string match --* $arg]} {
            set key [string range $arg 2 end]
            if {[lsearch -exact $flag_names $key] >= 0} {
                set opts($key) 1
                incr idx
                continue
            }
            if {[lsearch -exact $option_names $key] < 0} {
                error "unknown option '$arg'"
            }
            incr idx
            if {$idx >= [llength $argv]} {
                error "missing value for '$arg'"
            }
            set opts($key) [lindex $argv $idx]
            incr idx
            continue
        }
        lappend positional $arg
        incr idx
    }
    return [list [array get opts] $positional]
}

proc ::board_test::jtag::uniq_paths {paths} {
    array set seen {}
    set out [list]
    foreach path $paths {
        if {[info exists seen($path)]} {
            continue
        }
        set seen($path) 1
        lappend out $path
    }
    return $out
}

proc ::board_test::jtag::matching_master_paths {primary fallback} {
    set masters [get_service_paths master]
    if {[llength $masters] == 0} {
        error "no master services found"
    }

    set matches [list]
    set explicit_filter 0
    if {$primary ne ""} {
        set explicit_filter 1
        foreach m $masters {
            if {[string match $primary $m]} {
                lappend matches $m
            }
        }
    }
    if {[llength $matches] == 0 && $fallback ne ""} {
        set explicit_filter 1
        foreach m $masters {
            if {[string match $fallback $m]} {
                lappend matches $m
            }
        }
    }
    if {[llength $matches] == 0} {
        if {$explicit_filter} {
            error "no master services matched primary='$primary' fallback='$fallback'; available masters: [join $masters { ; }]"
        }
        set matches $masters
    }
    return [::board_test::jtag::uniq_paths $matches]
}

proc ::board_test::jtag::claim_matching_master {primary fallback uid_addr uid_expected service_tag} {
    set candidates [::board_test::jtag::matching_master_paths $primary $fallback]
    if {[llength $candidates] == 0} {
        error "no candidate master services"
    }

    set need_uid 0
    if {$uid_addr ne "" || $uid_expected ne ""} {
        set need_uid 1
    }

    foreach master $candidates {
        set svc ""
        if {[catch {set svc [claim_service master $master $service_tag]} err]} {
            puts "JTAG_PROBE master={$master} status=CLAIM_FAIL err={$err}"
            continue
        }

        set uid ""
        if {$need_uid} {
            if {[catch {set uid [master_read_32 $svc $uid_addr 1]} err]} {
                puts "JTAG_PROBE master={$master} status=UID_READ_FAIL err={$err}"
                catch {close_service master $svc}
                continue
            }
            set uid [lindex $uid 0]
            puts "JTAG_PROBE master={$master} status=PROBED uid=$uid"
            if {$uid_expected ne "" && ![string equal -nocase $uid $uid_expected]} {
                catch {close_service master $svc}
                continue
            }
        } else {
            puts "JTAG_PROBE master={$master} status=PROBED uid={}"
        }

        return [dict create path $master service $svc uid $uid]
    }

    error "no responsive master matched the requested probe"
}

proc ::board_test::jtag::close_claim {svc} {
    if {$svc eq ""} {
        return
    }
    catch {close_service master $svc}
}

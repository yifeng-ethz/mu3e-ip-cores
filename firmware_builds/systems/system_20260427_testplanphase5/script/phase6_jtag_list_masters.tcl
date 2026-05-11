# Minimal JTAG service diagnostic for Phase-6 board probes.

puts "PHASE6_JTAG_LIST_MASTERS_BEGIN argv={$argv}"
flush stdout

if {[catch {
    set do_claim 0
    set do_read 0
    foreach arg $argv {
        if {$arg eq "--claim"} { set do_claim 1 }
        if {$arg eq "--read-hist-uid"} { set do_read 1 }
    }
    set masters [get_service_paths master]
    puts "PHASE6_JTAG_LIST_MASTERS_COUNT [llength $masters]"
    foreach master $masters {
        puts "PHASE6_JTAG_MASTER {$master}"
        flush stdout
        if {$do_claim && [string match "*#7-2*/phy_1/master" $master]} {
            puts "PHASE6_JTAG_CLAIM_BEGIN {$master}"
            flush stdout
            set svc [claim_service master $master phase6_diag]
            puts "PHASE6_JTAG_CLAIM_DONE {$master} svc={$svc}"
            flush stdout
            if {$do_read} {
                puts "PHASE6_JTAG_READ_BEGIN addr=0x00020400"
                flush stdout
                set value [master_read_32 $svc 0x00020400 1]
                puts "PHASE6_JTAG_READ_DONE value={$value}"
                flush stdout
            }
            close_service master $svc
            puts "PHASE6_JTAG_CLOSE_DONE"
            flush stdout
        }
    }
    puts "PHASE6_JTAG_LIST_MASTERS_DONE status=OK"
    flush stdout
} err]} {
    puts "PHASE6_JTAG_LIST_MASTERS_DONE status=ERROR msg={$err}"
    flush stdout
    exit 2
}

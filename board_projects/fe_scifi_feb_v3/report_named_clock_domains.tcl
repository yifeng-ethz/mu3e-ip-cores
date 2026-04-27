package require ::quartus::project
package require ::quartus::sta

source [file join [file dirname [info script]] timing_clock_aliases.tcl]

set project_name top
set revision_name top_nostp
if {[llength $argv] >= 1} {
    set revision_name [lindex $argv 0]
}

set out_dir [file join [pwd] timing_debug $revision_name]
file mkdir $out_dir

project_open $project_name -revision $revision_name
create_timing_netlist
read_sdc
update_timing_netlist

set out_file [file join $out_dir named_clock_domains.rpt]
set fh [open $out_file w]

puts $fh "Named clock domains for revision $revision_name"
puts $fh ""

foreach key [mu3e_clock_alias_keys] {
    set label [mu3e_clock_alias_label $key]
    set domain [mu3e_clock_alias_domain $key]
    set names [mu3e_clock_alias_names $key]
    set periods [mu3e_clock_alias_periods $key]
    set freqs [mu3e_clock_alias_frequency_strings $key]

    puts $fh "$label"
    puts $fh "  domain: $domain"
    if {[llength $names] == 0} {
        puts $fh "  clocks: unresolved"
        puts $fh ""
        continue
    }

    if {[llength $periods] > 0} {
        puts $fh "  period_ns: [join $periods {, }]"
    }
    if {[llength $freqs] > 0} {
        puts $fh "  frequency_mhz: [join $freqs {, }]"
    }

    puts $fh "  timequest clocks:"
    foreach name $names {
        puts $fh "    - $name"
    }
    puts $fh ""
}

close $fh
post_message -type info "Wrote named clock domain report to $out_file"

reset_design
delete_timing_netlist
project_close

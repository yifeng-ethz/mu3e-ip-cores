#!/bin/sh
# \
[ $# -eq 0 ] && exit || \
HOME="${XDG_CACHE_HOME:-$HOME/.cache}" \
exec "$QUARTUS_ROOTDIR/../modelsim_ase/bin/vsim" -nolog \
    -do "set files [ list $(printf "%q " "$@") ]" \
    -do "$0"

# testbench entity name
set tb [ file rootname [ file tail [ lindex $files 0 ] ] ]
if { $tb == "" } {
    quit -f
}

set PWD [ pwd ]
# use absolute path for files
set files [ lmap f $files { list [ file normalize $f ] } ]

# create new project
set project_home_dir [ file normalize "./.cache/vsim_$tb" ]
file delete -force $project_home_dir
file mkdir $project_home_dir
project new $project_home_dir $tb work

# compile files
for { set nerr 0 } { $nerr < [ llength $files ] } {} {
    set f [ lindex $files 0 ]
    set files [ lreplace $files 0 0 ]
    if { ! [ file exists $f ] } continue

    set error [ catch {
        if { [ file extension $f ] == ".vhd" } {
            vcom -2008 -quiet -source -work work $f
            project addfile $f
        }
        if { [ file extension $f ] == ".v" } {
            vlog $f
            project addfile $f
        }

        set nerr 0
    } ]

    if { $error } {
        incr nerr
        lappend files $f
    }
}
vcom -refresh

set stop_time_us 1
if { [ info exists ::env(STOP_TIME_US) ] } {
    set stop_time_us $env(STOP_TIME_US)
}
set generics [ list ]
lappend generics "-gg_STOP_TIME_US=$stop_time_us"
if { [ info exists ::env(CLK_MHZ) ] } {
    lappend generics "-gg_CLK_MHZ=100.0"
}
lappend generics "-gg_SEED=[ expr int(pow(2,32)*rand())-0x80000000 ]"
lappend generics "-gg_PWD=$PWD"

# set testbench entity and generics
eval vsim $generics work.$tb
# add all testbench signals to wave view
add wave \
    -depth 2 \
    -radix hexadecimal \
    /$tb/*
#add wave -noupdate -expand -group tb /$tb/*

# start simulation
#restart -f
run $stop_time_us us
wave zoomfull

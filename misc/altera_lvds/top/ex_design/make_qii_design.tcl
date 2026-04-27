# (C) 2001-2018 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License Subscription 
# Agreement, Intel FPGA IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Intel and sold by 
# Intel or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


package require cmdline

proc string_compare {string_1 string_2} {
    return [expr {[string compare -nocase $string_1 $string_2] == 0}] 
}

proc error_and_exit {{msg ""}} {
   post_message -type error "Exiting Script."
   foreach line [split $msg "\n"] {
      post_message -type error $line
   }
   qexit -error
}

proc ls_recursive {base glob} {
    set files [list]

    foreach f [glob -nocomplain -types f -directory $base $glob] {
        set file_path [file join $base $f]
        lappend files $file_path
    }

    foreach d [glob -nocomplain -types d -directory $base *] {
        set files_recursive [ls_recursive [file join $base $d] $glob]
        lappend files {*}$files_recursive
    }

    return $files
}

proc get_relative_path {base path} {
    return [string trimleft [ string range $path [string length $base] [string length $path] ] "/"]
}

set script_path [file dirname [file normalize [info script]]]

source "$script_path/params.tcl"

set default_system_name $ed_params(SYNTH_QSYS_NAME)

set parameters {
    { "device.arg" "" "The device name" }
}

lappend parameters [list "system.arg" "$default_system_name" "Which example design project to generate. (defaults to \"$default_system_name\")" ]

set usage ": quartus_sh -t [info script] ?options?"
if {[catch {array set options [cmdline::getoptions quartus(args) $parameters]}]} {
    puts [cmdline::usage $parameters $usage]
    error_and_exit
}

if {$options(device) != ""} {
    set forced_device $options(device)
} else {
    set forced_device $ed_params(DEFAULT_DEVICE)
}

set system_name             $options(system)
if {[string_compare $system_name $default_system_name]} {
    set ex_design_path         "$script_path/qii"
} else {
    set ex_design_path         "$script_path/qii_$system_name"
}
set qsys_file              "${system_name}.qsys"
set family                 $device_family
set device                 $forced_device

if {![file exists $qsys_file]} {
    error_and_exit "File $qsys_file does not exist.\n Please use one of the names of the qsys files in your example design directory.\n"
}

puts "\n"
puts "*************************************************************************"
puts "Altera LVDS Example Design Builder               "
puts "                                                                         "
puts "Type  : Quartus Prime Project                                               "
puts "Family: $family"
puts "Device: $device" 
puts "                                                                         "
puts "This script takes ~1 minute to execute...                                "
puts "*************************************************************************"
puts "\n"

if {[file isdirectory $ex_design_path]} {
   error_and_exit "Directory $ex_design_path already exists.\nThis script does not overwrite an existing directory.\nRemove the directory before re-running the script."
}

file mkdir $ex_design_path
file copy -force "${script_path}/$qsys_file" "${ex_design_path}/$qsys_file"
if {[info exists ed_params(EXTRA_COPY_FILES)]} {
    foreach copy_file $ed_params(EXTRA_COPY_FILES) {
        file copy -force "${script_path}/$copy_file" "${ex_design_path}/."
    }
}

if {$pro_edition} {
    file mkdir "${ex_design_path}/ip"
    file copy -force "${script_path}/ip/${system_name}" "${ex_design_path}/ip/."
}

puts "Generating example design files..."

set qsys_generate_exe_path "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin/qsys-generate"

cd $ex_design_path
if {$pro_edition} {
   exec -ignorestderr $qsys_generate_exe_path $qsys_file --pro --synthesis --output-directory=. --family=$family --part=$device  >>& ip_generate.out
} else {
   exec -ignorestderr $qsys_generate_exe_path $qsys_file --synthesis --output-directory=. --family=$family --part=$device  >>& ip_generate.out
}

puts "Creating Quartus Prime project..."
project_new -family $family -part $device $system_name
set_global_assignment -name QSYS_FILE ${system_name}.qsys
if {$pro_edition} {
    foreach ip_file [ls_recursive "${ex_design_path}/ip" "*.ip"] {
        set ip_file [get_relative_path $ex_design_path $ip_file]
        set_global_assignment -name PBIP_FILE $ip_file
    }
}

if {[file exists $ex_design_path/${system_name}.sdc]} {
    set_global_assignment -name SDC_FILE ${system_name}.sdc    
}
project_close 

puts "\n"
puts "*************************************************************************"
puts "Successfully generated example design at the following location:                                                    "
puts "                                                                         "
puts "   $ex_design_path                                                 "
puts "                                                                         "
puts "*************************************************************************"
puts "\n"

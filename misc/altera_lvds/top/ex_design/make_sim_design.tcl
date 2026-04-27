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

proc error_and_exit {msg} {
   post_message -type error "SCRIPT_ABORTED!!!"
   foreach line [split $msg "\n"] {
      post_message -type error $line
   }
   qexit -error
}

proc show_usage_and_exit {argv0} {
   post_message -type error  "USAGE: $argv0 \[VERILOG|VHDL\]"
   qexit -error
}

set argv0 "quartus_sh -t [info script]"
set args $quartus(args)

if {[llength $args] == 1 } {
   set lang [string toupper [string trim [lindex $args 0]]]
   if {$lang != "VERILOG" && $lang != "VHDL"} {
      show_usage_and_exit $argv0
   }
} else {
   set lang "VERILOG"
}

if {[llength $args] > 1} {
   show_usage_and_exit $argv0
}

set script_path [file dirname [file normalize [info script]]]

source "$script_path/params.tcl"

set ex_design_path         "$script_path/sim"
set system_name            $ed_params(SIM_QSYS_NAME)
set qsys_file              "${system_name}.qsys"
set family                 $device_family

puts "\n"
puts "*************************************************************************"
puts "Altera LVDS Example Design Builder               "
puts "                                                                         "
puts "Type    : Simulation Design                                              "
puts "Family  : $family"
puts "Language: $lang"
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
set ip_make_simscript_exe_path "$::env(QUARTUS_ROOTDIR)/sopc_builder/bin/ip-make-simscript"

cd $ex_design_path
if {$pro_edition} {
   exec -ignorestderr $qsys_generate_exe_path $qsys_file --pro --simulation=$lang --output-directory=. --family=$family >>& ip_generate.out
} else {
exec -ignorestderr $qsys_generate_exe_path $qsys_file --simulation=$lang --output-directory=. --family=$family >>& ip_generate.out
} 
cd $system_name
set spd_file_list [ls_recursive "${ex_design_path}/ip/" "*.spd"]
lappend spd_file_list ed_sim.spd
set spd_files [join $spd_file_list ","]
exec -ignorestderr $ip_make_simscript_exe_path --use-relative-paths --spd=$spd_files >>& make_simscript.out

file delete -force make_simscript.out

puts "Finalizing..."

set sim_scripts [list]
lappend sim_scripts "${ex_design_path}/${system_name}/synopsys/vcs/vcs_setup.sh"
lappend sim_scripts "${ex_design_path}/${system_name}/synopsys/vcsmx/vcsmx_setup.sh"
lappend sim_scripts "${ex_design_path}/${system_name}/cadence/ncsim_setup.sh"
lappend sim_scripts "${ex_design_path}/${system_name}/mentor/msim_setup.tcl"
lappend sim_scripts "${ex_design_path}/${system_name}/aldec/rivierapro_setup.tcl"

foreach sim_script $sim_scripts {
   if {[file exists $sim_script]} {
      set fh [open $sim_script r]
      set file_data [read $fh]
      close $fh
      
      set fh [open $sim_script w]
      foreach line [split $file_data "\n"] {
         if {[regexp -- {USER_DEFINED_SIM_OPTIONS\s*=.*\+vcs\+finish\+100} $line]} {
            regsub -- {\+vcs\+finish\+100} $line {} line
         }
       
         if {[regexp -- {(altera_lnsim.sv\"?)} $line substr]} {
            regsub -- {altera_lnsim.sv\"?} $line "${substr} +define+GENERIC_PLL_TIMESCALE_10_FS" line
         }
         
         if {[regexp -- {USER_DEFINED_SIM_OPTIONS\s*=.*\-input \\\"\@run 100; exit\\\"} $line]} {
            regsub -- {\-input \\\"\@run 100; exit\\\"} $line {} line
         }         
         
         puts $fh $line
      }
      close $fh
   }
}

puts "\n"
puts "*************************************************************************"
puts "Successfully generated example design at the following location:                                                    "
puts "                                                                         "
puts "   $ex_design_path                                                 "
puts "                                                                         "
puts "*************************************************************************"
puts "\n"

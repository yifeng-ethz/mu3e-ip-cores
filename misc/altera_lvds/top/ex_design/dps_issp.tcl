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


##################################################
# Helper Procs
##################################################

proc error_and_exit {{msg ""}} {
   post_message -type error "Exitting Script."
   foreach line [split $msg "\n"] {
      post_message -type error $line
   }
   qexit -error
}

# Causes the program to sleep for N seconds
proc sleep {N} {
	post_message -type info "Sleeping for $N seconds"
	after [expr {int($N * 1000)}]
}

# Returns a string, e.g. dec2bin 10 => 1010 
proc dec2bin {i} {
    set res {} 
    while {$i>0} {
        set res [expr {$i%2}]$res
        set i [expr {$i/2}]
    }
    if {$res == {}} {set res 0}
    return $res
}

proc read_probe {idx} {
    return [read_probe_data -instance_index $idx]
}

proc write_source {idx value} {
    write_source_data -instance_index $idx -value $value
}

# Writes to source multiple times with values provided
proc write_source_sequence {idx values} {
    foreach value $values {
        write_source $idx $value
    }
}

proc poll_on_signal {idx {name ""} {timeout 10}} {
    if {$name == ""} {
        set name $idx
    }

	post_message -type info "Polling on $name signal"
	set time_at_start [clock seconds]

    set done [read_probe $idx]
    
	while {!$done} {
		set time_now [clock seconds]
		if {[expr {$time_now - $time_at_start}] > $timeout} {
			error_and_exit "Timed out polling on $name signal"
		}
		set done [read_probe $idx]
	}
    
    post_message -type info "Done polling on $name signal"
}

##################################################
# MAIN
##################################################
#
# This script does a phase shift on an extra added observation
# clock just to give an example on how to operate DPS
#
# A practical use case of the Dynamic Phase Shift (DPS) Example Design
# This script can be helpful in debugging RX Non-DPA capture issues
# The user can use this to initialize the interface with a different
# FCLK shift each time, sweeping the range of possible capture clocks
# and trying it out with the same data patterns to see which one works
# best. This info can then be fed back to Altera's tech services for a
# solution.
# 
# Note: For this use case, the phase relationship between the FCLK and
# the Loaden signal must be maintained for proper capture. 
# Make sure to shift both FCLK and Loaden.

set project_name [lindex $argv 0]
if {$project_name == ""} {
	set project_name "ed_synth_dps"
}

if {[llength $argv] < 1} {
    error_and_exit "Incorrect number of arguments! Usage: quartus_stp -t [info script] ?project_name?"
}

project_open $project_name

if {[llength get_hardware_names] != 1} {
	error_and_exit "Fatal Error: Expected 1 hardware name but found [llength get_hardware_names]"
}

# Get the hardware interface name. We always use the first one
set hardware_index 1
set device_index  0
set hardware_name [lindex [get_hardware_names] $hardware_index]
post_message -type info "Found hardware called $hardware_name"
# Get the device name. For this board it is always the first device
set device_name [lindex [get_device_names -hardware_name $hardware_name] $device_index]
post_message -type info "Using device $device_name"

# Figure out the indices of the probes/sources we want to look at
set iss_instances [get_insystem_source_probe_instance_info -hardware_name $hardware_name -device_name $device_name]

foreach inst $iss_instances {
	set index [lindex $inst 0]
	set source_width [lindex $inst 1]
	set probe_width [lindex $inst 2]
	set name [lindex $inst 3]
	post_message -type info "Found ISSP called $name ($index) Probe/Source Width: $probe_width/$source_width"
	# Saving probe indices into map
    set issp($name) $index
}

# Define expected ISSP IDs
#
# For information see: http://www.altera.com/literature/an/an728.pdf
# Section: Dynamic Phase Shift Ports in Altera IOPLL IP Core
#
#  ID   TYPE(S|P)  WIDTH  VALUES  USAGE
# CSEL    S         5     0 ~ 8   Selects the PLL counter/output to apply the phase shift to (9 clocks max)
#
# NPS     S         3     0 ~ 6   Selects the phase shift granularity to occur per assertion of phase_en. 
#                                 Determines the number of phase shift per dynamic phase shift operation. 
#                                 Up to 7 phase shifts per operation are possible. Each phase shift step
#                                 is equal to 1/8 of I/O PLL VCO period.
# UPDN    S         1      0|1    Sets direction of dynamic phase shift. Shift Up (1) or Shift Down (0).
# PEN     S         1      0|1    Active high signal. Assert to activate dynamic phase shift operation.
#                                 Phase shift will occur on each 0~1 transition
# 
# RST     S         1      0|1    Active high signal. Resets PLL and LVDS interface. Note that after a
#                                 reset, any phase shift applied using DPS is undone.
# LCK     P         1      0|1    Active high signal. Asserts when PLL is Locked.
set expected_issps [list CSEL NPS UPDN PEN RST LCK]

foreach expected_issp $expected_issps {
    if {![info exists issp($expected_issp)]} {
        error_and_exit "Fatal Error: Expected probe ID ($expected_issp) not found"
    }
}

post_message -type info "Starting in system source probes"
start_insystem_source_probe -hardware_name $hardware_name -device_name $device_name

##################################################
# Initialization

# Keep interface reset
# Note: Resetting the PLL will reset all clocks to their
# original generated phases
write_source $issp(RST) 1

# In the common case for LVDS Designs:
# Counter 0: Fast Clock
# Counter 1: Loaden
# Counter 2: Tx/Rx Core Clock
# In the DPS example design, we add extra clocks:
# Counter 3: Scan clock for DPS fed back to PLL
# Counter 4: Extra clock for observation
#
# or in the case of TX Mode with Non-STD TX outclock phase shifts
# Counter 0: Fast Clock
# Counter 1: Loaden
# Counter 2: Tx Outclock Fast Clock
# Counter 3: Tx Outclock Loaden
# Counter 4: Tx Core Clock
# In the DPS example design, we add extra clocks:
# Counter 5: Scan clock for DPS fed back to PLL
# Counter 6: Extra clock for observation
#
# Select PLL counter 4 (Extra observation clock)
write_source $issp(CSEL) 00100

# Set num_phase_shifts to 4
write_source $issp(NPS) 100
# Shift upwards
write_source $issp(UPDN) 1
# Set phase_en to 0
write_source $issp(PEN) 0

##################################################
# Main Operation

# Get out of reset
write_source $issp(RST) 0
# Wait for PLL to lock
poll_on_signal $issp(LCK) "PLL Lock"

# Shift the extra clock every 5 seconds
# Observe shifting on scope
for {set i 0} {$i < 20} {incr i} {
    # Send sequence 1 0 to start the shifting
    write_source_sequence $issp(PEN) [list 1 0]
    sleep 5
}
	
end_insystem_source_probe
project_close


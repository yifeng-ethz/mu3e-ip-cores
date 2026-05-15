package require -exact qsys 18.1

proc set_required_param {inst name value} {
    set_instance_parameter_value $inst $name $value
}

proc configure_run_ctrl_splitter {name outputs} {
    add_instance $name altera_avalon_st_splitter 18.1
    set_required_param $name BITS_PER_SYMBOL 9
    set_required_param $name CHANNEL_WIDTH 1
    set_required_param $name DATA_WIDTH 9
    set_required_param $name ERROR_DESCRIPTOR ""
    set_required_param $name ERROR_WIDTH 1
    set_required_param $name MAX_CHANNELS 1
    set_required_param $name NUMBER_OF_OUTPUTS $outputs
    set_required_param $name QUALIFY_VALID_OUT 0
    set_required_param $name READY_LATENCY 0
    set_required_param $name USE_CHANNEL 0
    set_required_param $name USE_DATA 1
    set_required_param $name USE_ERROR 0
    set_required_param $name USE_PACKETS 0
    set_required_param $name USE_READY 0
    set_required_param $name USE_VALID 1
}

proc configure_arb_child {name lane} {
    add_instance $name arb_hit_type0 26.6.0.0512
    set_required_param $name MODE_DEFAULT 1
    set_required_param $name WATCHDOG_DEFAULT 500
    set_required_param $name FIFO_DEPTH 16
    set_required_param $name DEBUG_LEVEL 0
    set_required_param $name IP_UID 1095263280
    set_required_param $name INSTANCE_ID $lane
    set_required_param $name VERSION_MAJOR 26
    set_required_param $name VERSION_MINOR 6
    set_required_param $name VERSION_PATCH 0
    set_required_param $name BUILD 512
    set_required_param $name VERSION_DATE 20260512
    set_required_param $name VERSION_GIT 0
}

proc configure_csr_pipeline_bridge {name} {
    add_instance $name altera_avalon_mm_bridge 18.1
    set_required_param $name DATA_WIDTH 32
    set_required_param $name SYMBOL_WIDTH 8
    set_required_param $name ADDRESS_WIDTH 5
    set_required_param $name USE_AUTO_ADDRESS_WIDTH 0
    set_required_param $name ADDRESS_UNITS WORDS
    set_required_param $name MAX_BURST_SIZE 1
    set_required_param $name MAX_PENDING_RESPONSES 1
    set_required_param $name LINEWRAPBURSTS 0
    set_required_param $name PIPELINE_COMMAND 1
    set_required_param $name PIPELINE_RESPONSE 1
    set_required_param $name USE_RESPONSE 0
}

proc export_existing_interface {name type dir target} {
    catch {add_interface $name $type $dir}
    set_interface_property $name EXPORT_OF $target
}

if {[info exists ::env(SYSTEM_DIR)]} {
    set system_dir $::env(SYSTEM_DIR)
} else {
    set system_dir {/home/yifeng/packages/mu3e_ip_dev/mu3e-ip-cores/firmware_builds/systems/v3_pretest-260511-pulserdrop-260512}
}

set qsys_path [file join $system_dir quartus_systems arb_hit_type0_supercore.qsys]
file mkdir [file dirname $qsys_path]
if {[file exists $qsys_path]} {
    exec chmod u+w $qsys_path
}

create_system arb_hit_type0_supercore
set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

add_instance clk_bridge altera_clock_bridge 18.1
set_required_param clk_bridge EXPLICIT_CLOCK_RATE 0.0
set_required_param clk_bridge NUM_CLOCK_OUTPUTS 1

add_instance reset_bridge altera_reset_bridge 18.1
set_required_param reset_bridge ACTIVE_LOW_RESET 0
set_required_param reset_bridge SYNCHRONOUS_EDGES deassert
set_required_param reset_bridge NUM_RESET_OUTPUTS 1
set_required_param reset_bridge USE_RESET_REQUEST 0

configure_run_ctrl_splitter run_ctrl_splitter 8
add_connection clk_bridge.out_clk reset_bridge.clk
add_connection clk_bridge.out_clk run_ctrl_splitter.clk
add_connection reset_bridge.out_reset run_ctrl_splitter.reset

export_existing_interface clk clock sink clk_bridge.in_clk
export_existing_interface rst reset sink reset_bridge.in_reset
export_existing_interface run_ctrl avalon_streaming sink run_ctrl_splitter.in

for {set lane 0} {$lane < 8} {incr lane} {
    set inst lane_$lane
    set csr_bridge csr_pipe_$lane
    configure_arb_child $inst $lane
    configure_csr_pipeline_bridge $csr_bridge

    add_connection clk_bridge.out_clk $inst.clk
    add_connection reset_bridge.out_reset $inst.rst
    add_connection clk_bridge.out_clk $csr_bridge.clk
    add_connection reset_bridge.out_reset $csr_bridge.reset
    add_connection run_ctrl_splitter.out$lane $inst.run_ctrl
    add_connection $csr_bridge.m0 $inst.csr

    export_existing_interface csr_$lane avalon slave $csr_bridge.s0
    export_existing_interface real_in_$lane avalon_streaming sink $inst.real_in
    export_existing_interface emu_in_$lane avalon_streaming sink $inst.emu_in
    export_existing_interface selected_out_$lane avalon_streaming source $inst.selected_out
}

set_interconnect_requirement {$system} qsys_mm.clockCrossingAdapter AUTO
set_interconnect_requirement {$system} qsys_mm.enableEccProtection FALSE
set_interconnect_requirement {$system} qsys_mm.enableInstrumentation FALSE
set_interconnect_requirement {$system} qsys_mm.insertDefaultSlave FALSE
set_interconnect_requirement {$system} qsys_mm.maxAdditionalLatency 4

save_system $qsys_path
exec chmod a-w $qsys_path
puts "INFO: saved generated arb_hit_type0_supercore subsystem $qsys_path"

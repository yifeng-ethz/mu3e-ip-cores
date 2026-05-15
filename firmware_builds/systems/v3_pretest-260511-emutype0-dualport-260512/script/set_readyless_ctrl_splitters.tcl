package require -exact qsys 18.1

proc set_optional_param {inst name value} {
    if {[catch {set_instance_parameter_value $inst $name $value} err]} {
        puts "INFO: optional parameter ${inst}.${name} not present: $err"
    }
}

# Run-control is a broadcast fabric. Keep both splitters readyless so a
# missing or backpressured debug/emulator leaf cannot stall every sink.
foreach inst {run_control_splitter emulator_ctrl_splitter} {
    set_optional_param $inst USE_READY 0
    set_optional_param $inst READY_LATENCY 0
    set_optional_param $inst QUALIFY_VALID_OUT 0
}

set_optional_param emulator_mutrig_qsys_inst CSR_ADDR_WIDTH 6
set_optional_param emulator_mutrig_qsys_inst BUILD 513
set_optional_param emulator_mutrig_qsys_inst VERSION_DATE 20260513
set_optional_param emulator_mutrig_qsys_inst VERSION_MAJOR 26
set_optional_param emulator_mutrig_qsys_inst VERSION_MINOR 3
set_optional_param emulator_mutrig_qsys_inst VERSION_PATCH 1
set_optional_param emulator_mutrig_qsys_inst VERSION_GIT 0

save_system

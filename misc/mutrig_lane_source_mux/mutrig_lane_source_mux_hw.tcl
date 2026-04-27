package require -exact qsys 16.1

set_module_property NAME mutrig_lane_source_mux
set_module_property DISPLAY_NAME "MuTRiG Lane Source Mux"
set_module_property VERSION 1.0
set_module_property DESCRIPTION "Static per-lane selector between real MuTRiG decoded traffic and emulator tx8b1k traffic"
set_module_property GROUP "Mu3e Emulators/Modules"
set_module_property AUTHOR "Codex"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL mutrig_lane_source_mux
add_fileset_file mutrig_lane_source_mux.sv SYSTEM_VERILOG PATH rtl/mutrig_lane_source_mux.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL mutrig_lane_source_mux
add_fileset_file mutrig_lane_source_mux.sv SYSTEM_VERILOG PATH rtl/mutrig_lane_source_mux.sv TOP_LEVEL_FILE

add_parameter SELECT_EMULATOR INTEGER 0
set_parameter_property SELECT_EMULATOR DISPLAY_NAME "Select Emulator"
set_parameter_property SELECT_EMULATOR ALLOWED_RANGES 0:1
set_parameter_property SELECT_EMULATOR HDL_PARAMETER true
set_parameter_property SELECT_EMULATOR DESCRIPTION "0 selects the real decoded MuTRiG stream, 1 selects the emulator stream."

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rst reset Input 1

add_interface real_in avalon_streaming sink
set_interface_property real_in associatedClock clk
set_interface_property real_in associatedReset rst
set_interface_property real_in dataBitsPerSymbol 9
set_interface_property real_in symbolsPerBeat 1
set_interface_property real_in readyLatency 0
set_interface_property real_in maxChannel 15
set_interface_property real_in errorDescriptor "loss_sync_pattern parity_error decode_error"
set_interface_property real_in ENABLED true
add_interface_port real_in asi_real_data data Input 9
add_interface_port real_in asi_real_valid valid Input 1
add_interface_port real_in asi_real_error error Input 3
add_interface_port real_in asi_real_channel channel Input 4

add_interface emu_in avalon_streaming sink
set_interface_property emu_in associatedClock clk
set_interface_property emu_in associatedReset rst
set_interface_property emu_in dataBitsPerSymbol 9
set_interface_property emu_in symbolsPerBeat 1
set_interface_property emu_in readyLatency 0
set_interface_property emu_in maxChannel 15
set_interface_property emu_in errorDescriptor "loss_sync_pattern parity_error decode_error"
set_interface_property emu_in ENABLED true
add_interface_port emu_in asi_emu_data data Input 9
add_interface_port emu_in asi_emu_valid valid Input 1
add_interface_port emu_in asi_emu_error error Input 3
add_interface_port emu_in asi_emu_channel channel Input 4

add_interface selected_out avalon_streaming source
set_interface_property selected_out associatedClock clk
set_interface_property selected_out associatedReset rst
set_interface_property selected_out dataBitsPerSymbol 9
set_interface_property selected_out symbolsPerBeat 1
set_interface_property selected_out readyLatency 0
set_interface_property selected_out maxChannel 15
set_interface_property selected_out errorDescriptor "loss_sync_pattern parity_error decode_error"
set_interface_property selected_out ENABLED true
add_interface_port selected_out aso_data data Output 9
add_interface_port selected_out aso_valid valid Output 1
add_interface_port selected_out aso_error error Output 3
add_interface_port selected_out aso_channel channel Output 4

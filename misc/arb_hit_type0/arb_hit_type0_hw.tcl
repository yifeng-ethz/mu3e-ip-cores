package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST 26
set VERSION_MINOR_DEFAULT_CONST 2
set VERSION_PATCH_DEFAULT_CONST 0
set BUILD_DEFAULT_CONST         504
set VERSION_DATE_DEFAULT_CONST  20260504
set VERSION_GIT_DEFAULT_CONST   0x00000000
set IP_UID_DEFAULT_CONST        0x41485430 ;# ASCII "AHT0"
set INSTANCE_ID_DEFAULT_CONST   0

set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set_module_property NAME                         arb_hit_type0
set_module_property DISPLAY_NAME                 "Arbiter hit_type0 (real / emu / mix RR)"
set_module_property VERSION                      $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION                  "Per-lane arbiter on the post-deassembly hit_type0 boundary with 16-deep ingress FIFOs per source and packet-boundary round-robin."
set_module_property GROUP                        "Mu3e Emulators/Modules"
set_module_property AUTHOR                       "Mu3e IP team"
set_module_property INTERNAL                     false
set_module_property OPAQUE_ADDRESS_MAP           true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE                     true
set_module_property REPORT_TO_TALKBACK           false
set_module_property ALLOW_GREYBOX_GENERATION     false
set_module_property REPORT_HIERARCHY             false

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL arb_hit_type0
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file arb_hit_type0.sv SYSTEM_VERILOG PATH rtl/arb_hit_type0.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL arb_hit_type0
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file arb_hit_type0.sv SYSTEM_VERILOG PATH rtl/arb_hit_type0.sv TOP_LEVEL_FILE

# ---------- Parameters ----------

add_parameter MODE_DEFAULT NATURAL 0
set_parameter_property MODE_DEFAULT DISPLAY_NAME "Reset Mode (0=REAL, 1=EMU, 2=MIX_RR)"
set_parameter_property MODE_DEFAULT ALLOWED_RANGES 0:2
set_parameter_property MODE_DEFAULT HDL_PARAMETER true

add_parameter FIFO_DEPTH NATURAL 16
set_parameter_property FIFO_DEPTH DISPLAY_NAME "Per-source ingress FIFO depth"
set_parameter_property FIFO_DEPTH ALLOWED_RANGES {16}
set_parameter_property FIFO_DEPTH HDL_PARAMETER true

add_parameter IP_UID STD_LOGIC_VECTOR $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID WIDTH 32
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID DESCRIPTION {Software-visible IP identifier at CSR word 0. Default ASCII "AHT0".}

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR HDL_PARAMETER true
set_parameter_property VERSION_MAJOR VISIBLE false

add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR HDL_PARAMETER true
set_parameter_property VERSION_MINOR VISIBLE false

add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH HDL_PARAMETER true
set_parameter_property VERSION_PATCH VISIBLE false

add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD HDL_PARAMETER true
set_parameter_property BUILD VISIBLE false

add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE HDL_PARAMETER true
set_parameter_property VERSION_DATE VISIBLE false

add_parameter VERSION_GIT STD_LOGIC_VECTOR $VERSION_GIT_DEFAULT_CONST
set_parameter_property VERSION_GIT WIDTH 32
set_parameter_property VERSION_GIT HDL_PARAMETER true
set_parameter_property VERSION_GIT DISPLAY_HINT hexadecimal
set_parameter_property VERSION_GIT VISIBLE false

add_parameter INSTANCE_ID NATURAL $INSTANCE_ID_DEFAULT_CONST
set_parameter_property INSTANCE_ID DISPLAY_NAME "Instance ID"
set_parameter_property INSTANCE_ID HDL_PARAMETER true
set_parameter_property INSTANCE_ID DESCRIPTION "Per-integration instance identifier exposed through META page 3."

# ---------- Interfaces ----------

add_interface clk clock end
set_interface_property clk ENABLED true
add_interface_port clk clk clk Input 1

add_interface rst reset end
set_interface_property rst associatedClock clk
set_interface_property rst synchronousEdges DEASSERT
set_interface_property rst ENABLED true
add_interface_port rst rst reset Input 1

add_interface csr avalon end
set_interface_property csr addressUnits WORDS
set_interface_property csr associatedClock clk
set_interface_property csr associatedReset rst
set_interface_property csr bitsPerSymbol 8
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 0
set_interface_property csr readLatency 0
set_interface_property csr readWaitTime 1
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address     address     Input  4
add_interface_port csr avs_csr_write       write       Input  1
add_interface_port csr avs_csr_read        read        Input  1
add_interface_port csr avs_csr_writedata   writedata   Input  32
add_interface_port csr avs_csr_readdata    readdata    Output 32
add_interface_port csr avs_csr_waitrequest waitrequest Output 1

add_interface real_in avalon_streaming sink
set_interface_property real_in associatedClock clk
set_interface_property real_in associatedReset rst
set_interface_property real_in dataBitsPerSymbol 45
set_interface_property real_in symbolsPerBeat 1
set_interface_property real_in readyLatency 0
set_interface_property real_in maxChannel 15
set_interface_property real_in errorDescriptor "hiterr frameerr overflow"
set_interface_property real_in firstSymbolInHighOrderBits true
set_interface_property real_in ENABLED true
add_interface_port real_in asi_real_data          data          Input 45
add_interface_port real_in asi_real_valid         valid         Input 1
add_interface_port real_in asi_real_error         error         Input 3
add_interface_port real_in asi_real_channel       channel       Input 4
add_interface_port real_in asi_real_startofpacket startofpacket Input 1
add_interface_port real_in asi_real_endofpacket   endofpacket   Input 1
add_interface_port real_in asi_real_endofrun      endofrun      Input 1

add_interface emu_in avalon_streaming sink
set_interface_property emu_in associatedClock clk
set_interface_property emu_in associatedReset rst
set_interface_property emu_in dataBitsPerSymbol 45
set_interface_property emu_in symbolsPerBeat 1
set_interface_property emu_in readyLatency 0
set_interface_property emu_in maxChannel 15
set_interface_property emu_in errorDescriptor "hiterr frameerr overflow"
set_interface_property emu_in firstSymbolInHighOrderBits true
set_interface_property emu_in ENABLED true
add_interface_port emu_in asi_emu_data          data          Input 45
add_interface_port emu_in asi_emu_valid         valid         Input 1
add_interface_port emu_in asi_emu_error         error         Input 3
add_interface_port emu_in asi_emu_channel       channel       Input 4
add_interface_port emu_in asi_emu_startofpacket startofpacket Input 1
add_interface_port emu_in asi_emu_endofpacket   endofpacket   Input 1
add_interface_port emu_in asi_emu_endofrun      endofrun      Input 1

add_interface selected_out avalon_streaming source
set_interface_property selected_out associatedClock clk
set_interface_property selected_out associatedReset rst
set_interface_property selected_out dataBitsPerSymbol 45
set_interface_property selected_out symbolsPerBeat 1
set_interface_property selected_out readyLatency 0
set_interface_property selected_out maxChannel 15
set_interface_property selected_out errorDescriptor "hiterr frameerr overflow"
set_interface_property selected_out firstSymbolInHighOrderBits true
set_interface_property selected_out ENABLED true
add_interface_port selected_out aso_data          data          Output 45
add_interface_port selected_out aso_valid         valid         Output 1
add_interface_port selected_out aso_error         error         Output 3
add_interface_port selected_out aso_channel       channel       Output 4
add_interface_port selected_out aso_startofpacket startofpacket Output 1
add_interface_port selected_out aso_endofpacket   endofpacket   Output 1
add_interface_port selected_out aso_endofrun      endofrun      Output 1

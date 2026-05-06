package require -exact qsys 18.1

create_system focus_emulator_type0_system

proc abs_dir {path} {
    set save_dir [pwd]
    cd $path
    set result [pwd]
    cd $save_dir
    return $result
}

if {[info exists env(FOCUS_SYN_DIR)] && [info exists env(FOCUS_SYSTEM_DIR)]} {
    set syn_dir [abs_dir $env(FOCUS_SYN_DIR)]
    set system_dir [abs_dir $env(FOCUS_SYSTEM_DIR)]
    set script_dir $syn_dir
} else {
    set script_path [info script]
    if {[string length $script_path] == 0} {
        set script_path [file join [pwd] build_emulator_type0_system.tcl]
    }
    if {![string equal [file pathtype $script_path] absolute]} {
        set script_path [file join [pwd] $script_path]
    }
    set script_dir [abs_dir [file dirname $script_path]]
    set system_dir [abs_dir [file join $script_dir ..]]
    set syn_dir $script_dir
}
set qsys_path [file join $syn_dir focus_emulator_type0_system.qsys]
set qsys_out_dir [file join $syn_dir focus_emulator_type0_system]
set repo_dir [abs_dir [file join $system_dir .. .. ..]]
set focus_ipx [file join $syn_dir components.ipx]
set search_path [join [list $syn_dir [file join $system_dir ip] $focus_ipx "\$"] ","]

set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

proc set_required_param {inst name value} {
    set_instance_parameter_value $inst $name $value
}

proc set_optional_param {inst name value} {
    if {[catch {set_instance_parameter_value $inst $name $value} err]} {
        puts "INFO: optional parameter ${inst}.${name} not present in this catalog: $err"
    }
}

proc add_mm_connection {start end base} {
    add_connection $start $end
    set_connection_parameter_value ${start}/${end} baseAddress $base
    set_connection_parameter_value ${start}/${end} arbitrationPriority 1
    set_connection_parameter_value ${start}/${end} defaultConnection false
}

proc add_clock_source {name frequency} {
    add_instance $name clock_source 18.1
    set_instance_parameter_value $name clockFrequency $frequency
    set_instance_parameter_value $name clockFrequencyKnown true
    set_instance_parameter_value $name inputClockFrequency $frequency
    set_instance_parameter_value $name resetSynchronousEdges DEASSERT
}

proc add_mm_bridge {name addr_width pipeline_response} {
    add_instance $name altera_avalon_mm_bridge 18.1
    set_instance_parameter_value $name ADDRESS_UNITS WORDS
    set_instance_parameter_value $name ADDRESS_WIDTH $addr_width
    set_instance_parameter_value $name DATA_WIDTH 32
    set_instance_parameter_value $name LINEWRAPBURSTS 0
    set_instance_parameter_value $name MAX_BURST_SIZE 1
    set_instance_parameter_value $name MAX_PENDING_RESPONSES 4
    set_instance_parameter_value $name PIPELINE_COMMAND 1
    set_instance_parameter_value $name PIPELINE_RESPONSE $pipeline_response
    set_instance_parameter_value $name SYMBOL_WIDTH 8
    set_instance_parameter_value $name USE_AUTO_ADDRESS_WIDTH 1
    set_instance_parameter_value $name USE_RESPONSE 1
}

proc add_dc_fifo_36 {name depth} {
    add_instance $name altera_avalon_dc_fifo 18.1
    set_instance_parameter_value $name BITS_PER_SYMBOL 36
    set_instance_parameter_value $name CHANNEL_WIDTH 0
    set_instance_parameter_value $name ENABLE_EXPLICIT_MAXCHANNEL false
    set_instance_parameter_value $name ERROR_WIDTH 0
    set_instance_parameter_value $name EXPLICIT_MAXCHANNEL 0
    set_instance_parameter_value $name FIFO_DEPTH $depth
    set_instance_parameter_value $name RD_SYNC_DEPTH 2
    set_instance_parameter_value $name SYMBOLS_PER_BEAT 1
    set_instance_parameter_value $name USE_IN_FILL_LEVEL 0
    set_instance_parameter_value $name USE_OUT_FILL_LEVEL 0
    set_instance_parameter_value $name USE_PACKETS 1
    set_instance_parameter_value $name WR_SYNC_DEPTH 2
}

proc chmod_generated_artifacts {syn_dir qsys_path} {
    set sopcinfo_path [file join $syn_dir focus_emulator_type0_system.sopcinfo]
    set synthesis_dir [file join $syn_dir focus_emulator_type0_system synthesis]
    foreach path [list $qsys_path $sopcinfo_path $synthesis_dir] {
        if {[file exists $path]} {
            exec chmod -R a-w $path
        }
    }
}

# Clocks and board-facing clock/reset exports
add_clock_source cclk156_source 156250000
add_clock_source mclk125_source 125000000
add_clock_source osc50_source 50000000
add_instance max10_link_clk_bridge altera_clock_bridge 18.1
set_required_param max10_link_clk_bridge DERIVED_CLOCK_RATE 0
set_required_param max10_link_clk_bridge EXPLICIT_CLOCK_RATE 50000000
set_required_param max10_link_clk_bridge NUM_CLOCK_OUTPUTS 1

add_interface cclk156 clock sink
set_interface_property cclk156 EXPORT_OF cclk156_source.clk_in
add_interface mclk125 clock sink
set_interface_property mclk125 EXPORT_OF mclk125_source.clk_in
add_interface osc_clock_50_in clock sink
set_interface_property osc_clock_50_in EXPORT_OF osc50_source.clk_in
add_interface reset_3 reset sink
set_interface_property reset_3 EXPORT_OF cclk156_source.clk_in_reset

# Slow-control, run-control, and board utility IP
add_instance jtag_master altera_jtag_avalon_master 18.1
set_required_param jtag_master FAST_VER 1
set_required_param jtag_master FIFO_DEPTHS 2
set_required_param jtag_master PLI_PORT 50000
set_required_param jtag_master USE_PLI 0

add_instance sc_hub focus_sc_hub_v2 26.6.10.423
set_required_param sc_hub PRESET FEB_SCIFI_DEFAULT
set_required_param sc_hub BUS_TYPE AVALON
set_required_param sc_hub ADDR_WIDTH 18
set_required_param sc_hub DATA_WIDTH 32
set_required_param sc_hub DEBUG 1
set_required_param sc_hub INSTANCE_ID 0
set_required_param sc_hub VERSION_MAJOR 26
set_required_param sc_hub VERSION_MINOR 6
set_required_param sc_hub VERSION_PATCH 9
set_required_param sc_hub BUILD 414
set_required_param sc_hub VERSION_DATE 20260414
set_required_param sc_hub VERSION_GIT 98822845

add_mm_bridge sc_hub_cmd_pipe 18 0
add_mm_bridge mm_bridge 16 1
add_mm_bridge upload_mm_bridge 5 1
add_mm_bridge legacy_firefly_bridge 8 0

add_instance scratch_pad_ram altera_avalon_onchip_memory2 18.1
set_required_param scratch_pad_ram memorySize 1024
set_required_param scratch_pad_ram dataWidth 32
set_required_param scratch_pad_ram initMemContent true
set_required_param scratch_pad_ram useNonDefaultInitFile false
set_required_param scratch_pad_ram writable true

add_instance si_out altera_avalon_pio 18.1
set_required_param si_out bitModifyingOutReg 1
set_required_param si_out direction Output
set_required_param si_out width 16
set_required_param si_out resetValue 60

add_instance si_in altera_avalon_pio 18.1
set_required_param si_in bitClearingEdgeCapReg 0
set_required_param si_in captureEdge 0
set_required_param si_in direction Input
set_required_param si_in width 8

add_instance mutrig_reset_pio altera_avalon_pio 18.1
set_required_param mutrig_reset_pio bitModifyingOutReg 1
set_required_param mutrig_reset_pio direction Output
set_required_param mutrig_reset_pio width 2
set_required_param mutrig_reset_pio resetValue 0

add_instance mutrig_cfg_ctrl_0 mutrig_cfg_ctrl 24.1.423
set_required_param mutrig_cfg_ctrl_0 N_MUTRIG 4
set_required_param mutrig_cfg_ctrl_0 CLK_FREQUENCY 125000000
set_required_param mutrig_cfg_ctrl_0 CLK_FREQUENCY_SPI 50000000
set_required_param mutrig_cfg_ctrl_0 COUNTER_MM_ADDR_OFFSET_WORD 32768
set_required_param mutrig_cfg_ctrl_0 CPHA 0
set_required_param mutrig_cfg_ctrl_0 CPOL 0
set_required_param mutrig_cfg_ctrl_0 DEBUG 1
set_required_param mutrig_cfg_ctrl_0 INTENDED_MUTRIG_VERSION {MuTRiG 3}
set_required_param mutrig_cfg_ctrl_0 SEL_SUBROUTINES 2

add_instance onewire_master_0 focus_onewire_master 26.2.1.428
set_required_param onewire_master_0 REF_CLOCK_RATE 125000000
set_required_param onewire_master_0 AVST_DATA_WIDTH 8
set_required_param onewire_master_0 N_DQ_LINES 6
set_required_param onewire_master_0 AVST_CHANNEL_WIDTH 3
set_required_param onewire_master_0 DEBUG_LV 0

add_instance onewire_master_controller_0 onewire_master_controller 26.2.1.428
set_required_param onewire_master_controller_0 REF_CLOCK_RATE 125000000
set_required_param onewire_master_controller_0 AVST_DATA_WIDTH 8
set_required_param onewire_master_controller_0 AVST_CHANNEL_WIDTH 3
set_required_param onewire_master_controller_0 N_DQ_LINES 6
set_required_param onewire_master_controller_0 DEBUG_LV 0

add_instance firefly_xcvr_ctrl_0 firefly_xcvr_ctrl 26.2.423
set_required_param firefly_xcvr_ctrl_0 AVS_FIREFLY_ADDR_W 5
set_required_param firefly_xcvr_ctrl_0 DEBUG 1
set_required_param firefly_xcvr_ctrl_0 I2C_BAUD_RATE 400000
set_required_param firefly_xcvr_ctrl_0 SYSTEM_CLK_FREQ 125000000

add_instance max10_prog_avmm_0 max10_prog_avmm 0.2.0
set_required_param max10_prog_avmm_0 BOOT_HIST_AUTO_REFRESH 1
set_required_param max10_prog_avmm_0 BURSTCOUNT_W 1
set_required_param max10_prog_avmm_0 CDC_FIFO_ADDR_W 7
set_required_param max10_prog_avmm_0 CSR_ADDR_W 10
set_required_param max10_prog_avmm_0 DEBUG_LEVEL 0

add_instance charge_injection_pulser_0 charge_injection_pulser 4.0.5
set_required_param charge_injection_pulser_0 CLK_FREQUENCY 125000000
set_required_param charge_injection_pulser_0 DEBUG 1
set_required_param charge_injection_pulser_0 DEF_PULSE_FREQ 100000
set_required_param charge_injection_pulser_0 DEF_PULSE_WIDTH 20

add_instance runctl_mgmt_host_0 runctl_mgmt_host 26.2.6.425
set_required_param runctl_mgmt_host_0 DEBUG 1
set_required_param runctl_mgmt_host_0 EXT_HARD_RESET_PULSE_CYCLES 16384
set_required_param runctl_mgmt_host_0 RUN_END_ACK_SYMBOL 11111101
set_required_param runctl_mgmt_host_0 RUN_START_ACK_SYMBOL 11111110

add_instance run_control_splitter altera_avalon_st_splitter 18.1
set_required_param run_control_splitter BITS_PER_SYMBOL 9
set_required_param run_control_splitter CHANNEL_WIDTH 1
set_required_param run_control_splitter DATA_WIDTH 9
set_required_param run_control_splitter ERROR_DESCRIPTOR ""
set_required_param run_control_splitter ERROR_WIDTH 1
set_required_param run_control_splitter MAX_CHANNELS 1
set_required_param run_control_splitter NUMBER_OF_OUTPUTS 16
set_required_param run_control_splitter QUALIFY_VALID_OUT 0
set_required_param run_control_splitter READY_LATENCY 0
set_required_param run_control_splitter USE_CHANNEL 0
set_required_param run_control_splitter USE_DATA 1
set_required_param run_control_splitter USE_ERROR 0
set_required_param run_control_splitter USE_PACKETS 0
set_required_param run_control_splitter USE_READY 0
set_required_param run_control_splitter USE_VALID 1

add_dc_fifo_36 upload_rc_cdc_fifo 16

add_instance upload_pkt_mux multiplexer 18.1
set_required_param upload_pkt_mux bitsPerSymbol 36
set_required_param upload_pkt_mux errorWidth 0
set_required_param upload_pkt_mux numInputInterfaces 2
set_required_param upload_pkt_mux outChannelWidth 1
set_required_param upload_pkt_mux packetScheduling true
set_required_param upload_pkt_mux schedulingSize 2
set_required_param upload_pkt_mux symbolsPerBeat 1
set_required_param upload_pkt_mux useHighBitsOfChannel true
set_required_param upload_pkt_mux usePackets true

# Single-lane LVDS and hit-type0 datapath
add_instance lvds_rx_28nm_0 altera_lvds_rx_28nm 24.0.1110
set_required_param lvds_rx_28nm_0 N_LANE 1

add_instance lvds_rx_controller_pro_0 focus_lvds_rx_controller_pro 25.1.631
set_required_param lvds_rx_controller_pro_0 N_LANE 1
set_required_param lvds_rx_controller_pro_0 DECODED_CHANNEL_WIDTH 4
set_required_param lvds_rx_controller_pro_0 DECODED_USE_CHANNEL 0
set_required_param lvds_rx_controller_pro_0 AVMM_ADDR_W 4
set_required_param lvds_rx_controller_pro_0 SYNC_PATTERN_SEL 0xFA

add_instance mutrig_frame_deassembly_0 focus_mutrig_frame_deassembly 26.0.6.418
set_required_param mutrig_frame_deassembly_0 CHANNEL_WIDTH 4
set_required_param mutrig_frame_deassembly_0 CSR_ADDR_WIDTH 2
set_required_param mutrig_frame_deassembly_0 DEBUG_LV 2
set_required_param mutrig_frame_deassembly_0 MODE_HALT 0

add_instance mutrig_injector_0 mutrig_injector_multiheader 26.0.3.429
set_required_param mutrig_injector_0 HEADERINFO_CHANNEL_W 4
set_required_param mutrig_injector_0 INSTANCE_ID 0
set_required_param mutrig_injector_0 VERSION_MAJOR 26
set_required_param mutrig_injector_0 VERSION_MINOR 0
set_required_param mutrig_injector_0 VERSION_PATCH 3
set_required_param mutrig_injector_0 BUILD 429
set_required_param mutrig_injector_0 VERSION_DATE 20260429
set_required_param mutrig_injector_0 VERSION_GIT 1385020117

add_instance emulator_inject_fanout pulse_fanout8 1.0

add_instance emulator_mutrig_qsys_lane emulator_mutrig 26.2.0.502
set_required_param emulator_mutrig_qsys_lane FIFO_DEPTH 256
set_required_param emulator_mutrig_qsys_lane CSR_ADDR_WIDTH 4
set_required_param emulator_mutrig_qsys_lane ASIC_ID_DEFAULT 8
set_required_param emulator_mutrig_qsys_lane CLUSTER_LANE_INDEX_DEFAULT 0
set_required_param emulator_mutrig_qsys_lane CLUSTER_LANE_COUNT_DEFAULT 1
set_required_param emulator_mutrig_qsys_lane INSTANCE_ID 0
set_required_param emulator_mutrig_qsys_lane DEBUG_LEVEL 2
set_required_param emulator_mutrig_qsys_lane GIT_STAMP_OVERRIDE true
set_required_param emulator_mutrig_qsys_lane VERSION_GIT 1498700671
# emulator_mutrig_qsys_lane hardwires one lane and BYTE_STREAM_ENABLE=0 in RTL.
# The exposed software channel base is ASIC_ID_DEFAULT=8 for the emulator bank.

add_instance arb_hit_type0_0 focus_arb_hit_type0 26.4.1.0506
set_required_param arb_hit_type0_0 MODE_DEFAULT 0
set_required_param arb_hit_type0_0 WATCHDOG_DEFAULT 500
set_required_param arb_hit_type0_0 FIFO_DEPTH 16
set_required_param arb_hit_type0_0 DEBUG_LEVEL 2
set_required_param arb_hit_type0_0 IP_UID 1095263280
set_required_param arb_hit_type0_0 INSTANCE_ID 0
set_required_param arb_hit_type0_0 VERSION_MAJOR 26
set_required_param arb_hit_type0_0 VERSION_MINOR 4
set_required_param arb_hit_type0_0 VERSION_PATCH 1
set_required_param arb_hit_type0_0 BUILD 506
set_required_param arb_hit_type0_0 VERSION_DATE 20260506

add_instance backpressure_fifo altera_avalon_sc_fifo 18.1
set_required_param backpressure_fifo BITS_PER_SYMBOL 45
set_required_param backpressure_fifo CHANNEL_WIDTH 4
set_required_param backpressure_fifo EMPTY_LATENCY 3
set_required_param backpressure_fifo ENABLE_EXPLICIT_MAXCHANNEL true
set_required_param backpressure_fifo ERROR_WIDTH 3
set_required_param backpressure_fifo EXPLICIT_MAXCHANNEL 15
set_required_param backpressure_fifo FIFO_DEPTH 128
set_required_param backpressure_fifo SYMBOLS_PER_BEAT 1
set_required_param backpressure_fifo USE_ALMOST_EMPTY_IF 1
set_required_param backpressure_fifo USE_ALMOST_FULL_IF 0
set_required_param backpressure_fifo USE_FILL_LEVEL 1
set_required_param backpressure_fifo USE_MEMORY_BLOCKS 1
set_required_param backpressure_fifo USE_PACKETS 1
set_required_param backpressure_fifo USE_STORE_FORWARD 0

add_instance hit_type0_hist_pre_adapter_0 hit_type0_hist_pre_adapter 26.2.0.504
add_instance hist_pre_sink_0 avst_39_ready_sink 26.2.0.504

add_instance histogram_ingress_bridge_0 histogram_ingress_bridge 26.0.2.425
set_required_param histogram_ingress_bridge_0 DEFAULT_SELECT_POST 0
set_required_param histogram_ingress_bridge_0 ENABLE_POST_FORWARD 0
set_required_param histogram_ingress_bridge_0 FILTER_POST_HIT_WORDS 0
set_optional_param histogram_ingress_bridge_0 VERSION_MAJOR 26
set_optional_param histogram_ingress_bridge_0 VERSION_MINOR 0
set_optional_param histogram_ingress_bridge_0 VERSION_PATCH 2
set_optional_param histogram_ingress_bridge_0 BUILD 425
set_optional_param histogram_ingress_bridge_0 VERSION_DATE 20260425
set_optional_param histogram_ingress_bridge_0 VERSION_GIT 481097348

add_instance histogram_statistics_0 focus_histogram_statistics_v2 26.1.6.429
set_required_param histogram_statistics_0 UPDATE_KEY_BIT_HI 34
set_required_param histogram_statistics_0 UPDATE_KEY_BIT_LO 30
set_required_param histogram_statistics_0 N_DEBUG_INTERFACE 6
set_required_param histogram_statistics_0 AVST_DATA_WIDTH 39
set_required_param histogram_statistics_0 AVST_CHANNEL_WIDTH 4
set_required_param histogram_statistics_0 SNOOP_EN false
set_optional_param histogram_statistics_0 VERSION_MAJOR 26
set_optional_param histogram_statistics_0 VERSION_MINOR 1
set_optional_param histogram_statistics_0 VERSION_PATCH 6
set_optional_param histogram_statistics_0 BUILD 429
set_optional_param histogram_statistics_0 VERSION_DATE 20260429

# Board-facing exports
add_interface download_sc conduit end
set_interface_property download_sc EXPORT_OF sc_hub.download
add_interface upload_data0_sc_rc avalon_streaming start
set_interface_property upload_data0_sc_rc EXPORT_OF upload_pkt_mux.out
add_interface synclink avalon_streaming end
set_interface_property synclink EXPORT_OF runctl_mgmt_host_0.synclink
add_interface inject conduit end
set_interface_property inject EXPORT_OF emulator_inject_fanout.out8
add_interface inject_aux conduit end
set_interface_property inject_aux EXPORT_OF emulator_inject_fanout.inject_aux_in
add_interface pulse_out_conduit conduit end
set_interface_property pulse_out_conduit EXPORT_OF charge_injection_pulser_0.pulse_out_conduit
add_interface lvds_pll_inclock clock sink
set_interface_property lvds_pll_inclock EXPORT_OF lvds_rx_28nm_0.inclock
add_interface lvds_outclock clock start
set_interface_property lvds_outclock EXPORT_OF lvds_rx_28nm_0.outclock
add_interface serial conduit end
set_interface_property serial EXPORT_OF lvds_rx_28nm_0.serial
add_interface redriver conduit end
set_interface_property redriver EXPORT_OF lvds_rx_controller_pro_0.redriver
add_interface mutrig_cfg_ctrl_0_spi_export2top conduit end
set_interface_property mutrig_cfg_ctrl_0_spi_export2top EXPORT_OF mutrig_cfg_ctrl_0.spi_export2top
add_interface mutrig_reset conduit end
set_interface_property mutrig_reset EXPORT_OF mutrig_reset_pio.external_connection
add_interface max10_link conduit end
set_interface_property max10_link EXPORT_OF max10_prog_avmm_0.max10_link
add_interface max10_link_clock clock sink
set_interface_property max10_link_clock EXPORT_OF max10_link_clk_bridge.in_clk
add_interface sense_dq conduit end
set_interface_property sense_dq EXPORT_OF onewire_master_0.sense_dq
add_interface si_gpio_out conduit end
set_interface_property si_gpio_out EXPORT_OF si_out.external_connection
add_interface si_status_in conduit end
set_interface_property si_status_in EXPORT_OF si_in.external_connection
add_interface to_firefly_ucc8 conduit end
set_interface_property to_firefly_ucc8 EXPORT_OF firefly_xcvr_ctrl_0.to_firefly_ucc8
add_interface legacy_firefly_mon avalon start
set_interface_property legacy_firefly_mon EXPORT_OF legacy_firefly_bridge.m0

# Clocks and resets: control/SC domain
foreach sink {
    jtag_master.clk
    sc_hub.hub_clock
    sc_hub_cmd_pipe.clk
    mm_bridge.clk
    upload_mm_bridge.clk
    upload_pkt_mux.clk
    upload_rc_cdc_fifo.out_clk
    legacy_firefly_bridge.clk
    runctl_mgmt_host_0.mm_clock
} {
    add_connection cclk156_source.clk $sink
}

foreach sink {
    jtag_master.clk_reset
    sc_hub.hub_reset
    sc_hub_cmd_pipe.reset
    mm_bridge.reset
    upload_mm_bridge.reset
    upload_pkt_mux.reset
    upload_rc_cdc_fifo.out_clk_reset
    legacy_firefly_bridge.reset
    runctl_mgmt_host_0.mm_reset
} {
    add_connection cclk156_source.clk_reset $sink
}

# Board utility 125 MHz / 50 MHz clocks
foreach sink {
    scratch_pad_ram.clk1
    si_out.clk
    si_in.clk
    mutrig_reset_pio.clk
    mutrig_cfg_ctrl_0.controller_clock
    onewire_master_0.clock
    onewire_master_controller_0.clock
    firefly_xcvr_ctrl_0.system_clock
    max10_prog_avmm_0.csr_clock
    charge_injection_pulser_0.clock_interface
} {
    add_connection mclk125_source.clk $sink
}
add_connection osc50_source.clk mutrig_cfg_ctrl_0.spi_clock
add_connection max10_link_clk_bridge.out_clk max10_prog_avmm_0.link_clock

foreach sink {
    scratch_pad_ram.reset1
    si_out.reset
    si_in.reset
    mutrig_reset_pio.reset
    mutrig_cfg_ctrl_0.controller_reset
    onewire_master_0.reset
    onewire_master_controller_0.reset
    firefly_xcvr_ctrl_0.system_reset
    max10_prog_avmm_0.csr_reset
    charge_injection_pulser_0.reset_interface
} {
    add_connection cclk156_source.clk_reset $sink
}
add_connection cclk156_source.clk_reset mutrig_cfg_ctrl_0.spi_reset
add_connection cclk156_source.clk_reset max10_prog_avmm_0.link_reset

# Datapath LVDS clock domain
foreach sink {
    lvds_rx_controller_pro_0.data_clock
    mutrig_frame_deassembly_0.clock_sink
    mutrig_injector_0.clock_interface
    emulator_inject_fanout.clk
    emulator_mutrig_qsys_lane.data_clock
    arb_hit_type0_0.clk
    backpressure_fifo.clk
    hit_type0_hist_pre_adapter_0.clock
    histogram_ingress_bridge_0.clock
    hist_pre_sink_0.clock
    histogram_statistics_0.clock
    runctl_mgmt_host_0.lvdspll_clock
    run_control_splitter.clk
    upload_rc_cdc_fifo.in_clk
} {
    add_connection lvds_rx_28nm_0.outclock $sink
}
foreach sink {
    lvds_rx_controller_pro_0.data_reset
    mutrig_frame_deassembly_0.reset_sink
    mutrig_injector_0.reset_interface
    emulator_inject_fanout.reset
    emulator_mutrig_qsys_lane.data_reset
    arb_hit_type0_0.rst
    backpressure_fifo.clk_reset
    hit_type0_hist_pre_adapter_0.reset
    histogram_ingress_bridge_0.reset
    hist_pre_sink_0.reset
    histogram_statistics_0.reset
    histogram_statistics_0.interval_reset
    runctl_mgmt_host_0.lvdspll_reset
    run_control_splitter.reset
    upload_rc_cdc_fifo.in_clk_reset
} {
    add_connection cclk156_source.clk_reset $sink
}
add_connection cclk156_source.clk lvds_rx_controller_pro_0.control_clock
add_connection cclk156_source.clk_reset lvds_rx_controller_pro_0.control_reset
add_connection osc50_source.clk mutrig_injector_0.osc_clock_interface

# MM fabrics and preserved address map
add_mm_connection sc_hub.hub sc_hub_cmd_pipe.s0 0x00000000
add_mm_connection sc_hub_cmd_pipe.m0 scratch_pad_ram.s1 0x00000000
add_mm_connection sc_hub_cmd_pipe.m0 mutrig_reset_pio.s1 0x00001060
add_mm_connection sc_hub_cmd_pipe.m0 si_out.s1 0x00001020
add_mm_connection sc_hub_cmd_pipe.m0 si_in.s1 0x00001040
add_mm_connection sc_hub_cmd_pipe.m0 onewire_master_controller_0.csr 0x00011000
add_mm_connection sc_hub_cmd_pipe.m0 max10_prog_avmm_0.csr_avmm 0x00012000
add_mm_connection sc_hub_cmd_pipe.m0 charge_injection_pulser_0.csr_avmm 0x00013000
add_mm_connection sc_hub_cmd_pipe.m0 firefly_xcvr_ctrl_0.firefly 0x00014000
add_mm_connection sc_hub_cmd_pipe.m0 legacy_firefly_bridge.s0 0x00016000
add_mm_connection sc_hub_cmd_pipe.m0 mm_bridge.s0 0x00020000
add_mm_connection sc_hub_cmd_pipe.m0 upload_mm_bridge.s0 0x00030000
add_mm_connection sc_hub_cmd_pipe.m0 mutrig_cfg_ctrl_0.avmm_csr 0x0003f010
add_mm_connection sc_hub_cmd_pipe.m0 mutrig_cfg_ctrl_0.avmm_scanresult 0x00040000

add_mm_connection jtag_master.master scratch_pad_ram.s1 0x00000000
add_mm_connection jtag_master.master sc_hub.csr 0x00000400
add_mm_connection jtag_master.master mutrig_reset_pio.s1 0x00001060
add_mm_connection jtag_master.master si_out.s1 0x00001020
add_mm_connection jtag_master.master si_in.s1 0x00001040
add_mm_connection jtag_master.master onewire_master_controller_0.csr 0x00011000
add_mm_connection jtag_master.master max10_prog_avmm_0.csr_avmm 0x00012000
add_mm_connection jtag_master.master charge_injection_pulser_0.csr_avmm 0x00013000
add_mm_connection jtag_master.master firefly_xcvr_ctrl_0.firefly 0x00014000
add_mm_connection jtag_master.master legacy_firefly_bridge.s0 0x00016000
add_mm_connection jtag_master.master mm_bridge.s0 0x00020000
add_mm_connection jtag_master.master upload_mm_bridge.s0 0x00030000
add_mm_connection jtag_master.master mutrig_cfg_ctrl_0.avmm_csr 0x0003f010
add_mm_connection jtag_master.master mutrig_cfg_ctrl_0.avmm_scanresult 0x00040000

add_mm_connection mutrig_cfg_ctrl_0.avmm_schpad scratch_pad_ram.s1 0x00000000
add_mm_connection mutrig_cfg_ctrl_0.avmm_cnt scratch_pad_ram.s1 0x00000000
add_mm_connection onewire_master_controller_0.ctrl onewire_master_0.ctrl 0x00000000
add_mm_connection upload_mm_bridge.m0 runctl_mgmt_host_0.csr 0x00000000

add_mm_connection mm_bridge.m0 lvds_rx_controller_pro_0.csr 0x00000000
add_mm_connection mm_bridge.m0 backpressure_fifo.csr 0x00000860
add_mm_connection mm_bridge.m0 mutrig_frame_deassembly_0.csr 0x00000900
add_mm_connection mm_bridge.m0 emulator_mutrig_qsys_lane.csr 0x00002000
add_mm_connection mm_bridge.m0 arb_hit_type0_0.csr 0x00002280
add_mm_connection mm_bridge.m0 histogram_statistics_0.hist_bin 0x0000a000
add_mm_connection mm_bridge.m0 histogram_statistics_0.csr 0x0000a400
add_mm_connection mm_bridge.m0 histogram_ingress_bridge_0.csr 0x0000ac00
add_mm_connection mm_bridge.m0 mutrig_injector_0.csr 0x0000b200

# Stream and conduit topology
add_connection lvds_rx_controller_pro_0.ctrl lvds_rx_28nm_0.ctrl
add_connection lvds_rx_28nm_0.parallel lvds_rx_controller_pro_0.parallel
add_connection lvds_rx_controller_pro_0.decoded mutrig_frame_deassembly_0.rx8b1k
add_connection mutrig_frame_deassembly_0.hit_type0 arb_hit_type0_0.real_in
add_connection mutrig_frame_deassembly_0.debug_hit_metadata arb_hit_type0_0.real_hit_debug
add_connection mutrig_frame_deassembly_0.headerinfo mutrig_injector_0.headerinfo0
add_connection mutrig_injector_0.inject emulator_inject_fanout.inject_in
add_connection emulator_inject_fanout.out0 emulator_mutrig_qsys_lane.inject
add_connection emulator_mutrig_qsys_lane.hit_type0 arb_hit_type0_0.emu_in
add_connection emulator_mutrig_qsys_lane.hit_debug_metadata arb_hit_type0_0.emu_hit_debug
add_connection arb_hit_type0_0.selected_out backpressure_fifo.in
add_connection backpressure_fifo.out hit_type0_hist_pre_adapter_0.hit_in
add_connection hit_type0_hist_pre_adapter_0.pre_out histogram_ingress_bridge_0.pre_in
add_connection histogram_ingress_bridge_0.pre_out hist_pre_sink_0.sink
add_connection histogram_ingress_bridge_0.hist_out histogram_statistics_0.hist_fill_in

add_connection sc_hub.upload upload_pkt_mux.in0
add_connection runctl_mgmt_host_0.upload upload_rc_cdc_fifo.in
add_connection upload_rc_cdc_fifo.out upload_pkt_mux.in1
add_connection runctl_mgmt_host_0.runctl run_control_splitter.in
add_connection run_control_splitter.out0 histogram_statistics_0.ctrl
add_connection run_control_splitter.out1 emulator_mutrig_qsys_lane.ctrl
add_connection run_control_splitter.out2 mutrig_frame_deassembly_0.ctrl
add_connection run_control_splitter.out3 mutrig_injector_0.runctl
add_connection run_control_splitter.out4 arb_hit_type0_0.run_ctrl

add_connection onewire_master_0.rx onewire_master_controller_0.rx
add_connection onewire_master_controller_0.tx onewire_master_0.tx
add_connection onewire_master_controller_0.complete onewire_master_0.complete

set_interconnect_requirement {$system} qsys_mm.clockCrossingAdapter AUTO
set_interconnect_requirement {$system} qsys_mm.enableEccProtection FALSE
set_interconnect_requirement {$system} qsys_mm.enableInstrumentation FALSE
set_interconnect_requirement {$system} qsys_mm.insertDefaultSlave FALSE
set_interconnect_requirement {$system} qsys_mm.maxAdditionalLatency 4

save_system $qsys_path

set generate_cmd "qsys-generate \"$qsys_path\" --synthesis=VERILOG --search-path=\"$search_path\" 2>&1"
puts "INFO: running $generate_cmd"
set generate_output [exec sh -c $generate_cmd]
puts $generate_output

chmod_generated_artifacts $syn_dir $qsys_path
puts "INFO: focus_emulator_type0_system generation complete; qsys/sopcinfo/synthesis are read-only."

# qsys scripting (.tcl) file for debug_sc_system
package require -exact qsys 16.0

create_system {debug_sc_system}
set_module_property VERSION 1.0.0.0511

set_project_property DEVICE_FAMILY {Arria V}
set_project_property DEVICE {5AGXBA7D4F31C5}
set_project_property HIDE_FROM_IP_CATALOG {false}

# Instances and instance parameters
# (disabled instances are intentionally culled)
add_instance charge_injection_pulser_0 charge_injection_pulser 3.2.4
set_instance_parameter_value charge_injection_pulser_0 {CLK_FREQUENCY} {125000000}
set_instance_parameter_value charge_injection_pulser_0 {DEBUG} {1}
set_instance_parameter_value charge_injection_pulser_0 {DEF_PULSE_FREQ} {100000}
set_instance_parameter_value charge_injection_pulser_0 {DEF_PULSE_WIDTH} {20}

add_instance clk125 altera_clock_bridge 18.1
set_instance_parameter_value clk125 {EXPLICIT_CLOCK_RATE} {125000000.0}
set_instance_parameter_value clk125 {NUM_CLOCK_OUTPUTS} {1}

add_instance clk156 clock_source 18.1
set_instance_parameter_value clk156 {clockFrequency} {156250000.0}
set_instance_parameter_value clk156 {clockFrequencyKnown} {1}
set_instance_parameter_value clk156 {resetSynchronousEdges} {DEASSERT}

add_instance data_sc_merger multiplexer 18.1
set_instance_parameter_value data_sc_merger {bitsPerSymbol} {36}
set_instance_parameter_value data_sc_merger {errorWidth} {0}
set_instance_parameter_value data_sc_merger {numInputInterfaces} {2}
set_instance_parameter_value data_sc_merger {outChannelWidth} {1}
set_instance_parameter_value data_sc_merger {packetScheduling} {1}
set_instance_parameter_value data_sc_merger {schedulingSize} {2}
set_instance_parameter_value data_sc_merger {symbolsPerBeat} {1}
set_instance_parameter_value data_sc_merger {useHighBitsOfChannel} {1}
set_instance_parameter_value data_sc_merger {usePackets} {1}

add_instance firefly_xcvr_ctrl_0 firefly_xcvr_ctrl 24.0.823
set_instance_parameter_value firefly_xcvr_ctrl_0 {AVS_FIREFLY_ADDR_W} {5}
set_instance_parameter_value firefly_xcvr_ctrl_0 {DEBUG} {1}
set_instance_parameter_value firefly_xcvr_ctrl_0 {I2C_BAUD_RATE} {400000}
set_instance_parameter_value firefly_xcvr_ctrl_0 {SYSTEM_CLK_FREQ} {156250000}

add_instance jtag_master altera_jtag_avalon_master 18.1
set_instance_parameter_value jtag_master {FAST_VER} {0}
set_instance_parameter_value jtag_master {FIFO_DEPTHS} {2}
set_instance_parameter_value jtag_master {PLI_PORT} {50000}
set_instance_parameter_value jtag_master {USE_PLI} {0}

add_instance mm_bridge altera_avalon_mm_bridge 18.1
set_instance_parameter_value mm_bridge {ADDRESS_UNITS} {WORDS}
set_instance_parameter_value mm_bridge {ADDRESS_WIDTH} {14}
set_instance_parameter_value mm_bridge {DATA_WIDTH} {32}
set_instance_parameter_value mm_bridge {LINEWRAPBURSTS} {0}
set_instance_parameter_value mm_bridge {MAX_BURST_SIZE} {256}
set_instance_parameter_value mm_bridge {MAX_PENDING_RESPONSES} {4}
set_instance_parameter_value mm_bridge {PIPELINE_COMMAND} {1}
set_instance_parameter_value mm_bridge {PIPELINE_RESPONSE} {1}
set_instance_parameter_value mm_bridge {SYMBOL_WIDTH} {8}
set_instance_parameter_value mm_bridge {USE_AUTO_ADDRESS_WIDTH} {0}
set_instance_parameter_value mm_bridge {USE_RESPONSE} {1}

add_instance mutrig_cfg_ctrl_0 mutrig_cfg_ctrl 24.0.816
set_instance_parameter_value mutrig_cfg_ctrl_0 {CLK_FREQUENCY} {156250000}
set_instance_parameter_value mutrig_cfg_ctrl_0 {COUNTER_MM_ADDR_OFFSET_WORD} {32768}
set_instance_parameter_value mutrig_cfg_ctrl_0 {CPHA} {0}
set_instance_parameter_value mutrig_cfg_ctrl_0 {CPOL} {0}
set_instance_parameter_value mutrig_cfg_ctrl_0 {DEBUG} {1}
set_instance_parameter_value mutrig_cfg_ctrl_0 {INTENDED_MUTRIG_VERSION} {MuTRiG 3}
set_instance_parameter_value mutrig_cfg_ctrl_0 {MUTRIG_CFG_LENGTH_BIT} {2662}
set_instance_parameter_value mutrig_cfg_ctrl_0 {N_MUTRIG} {4}

add_instance on_die_temp_sense altera_temp_sense 18.1
set_instance_parameter_value on_die_temp_sense {CBX_AUTO_BLACKBOX} {ALL}
set_instance_parameter_value on_die_temp_sense {CE_CHECK} {1}
set_instance_parameter_value on_die_temp_sense {CLK_FREQUENCY} {40.0}
set_instance_parameter_value on_die_temp_sense {CLOCK_DIVIDER_VALUE} {80}
set_instance_parameter_value on_die_temp_sense {CLR_CHECK} {1}
set_instance_parameter_value on_die_temp_sense {NUMBER_OF_SAMPLES} {128}
set_instance_parameter_value on_die_temp_sense {POI_CAL_TEMPERATURE} {85}
set_instance_parameter_value on_die_temp_sense {SIM_TSDCALO} {0}
set_instance_parameter_value on_die_temp_sense {USER_OFFSET_ENABLE} {off}
set_instance_parameter_value on_die_temp_sense {USE_WYS} {on}

add_instance on_die_temp_sense_ctrl altera_temp_sense_ctrl 1.0
set_instance_parameter_value on_die_temp_sense_ctrl {CLK_FREQ} {40000000}
set_instance_parameter_value on_die_temp_sense_ctrl {DEBUG} {0}

add_instance pll_156t40 altera_pll 18.1
set_instance_parameter_value pll_156t40 {debug_print_output} {0}
set_instance_parameter_value pll_156t40 {debug_use_rbc_taf_method} {0}
set_instance_parameter_value pll_156t40 {gui_active_clk} {0}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency0} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency1} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency10} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency11} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency12} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency13} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency14} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency15} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency16} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency17} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency2} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency3} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency4} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency5} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency6} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency7} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency8} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_output_clock_frequency9} {0 MHz}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift0} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift1} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift10} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift11} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift12} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift13} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift14} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift15} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift16} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift17} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift2} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift3} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift4} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift5} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift6} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift7} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift8} {0}
set_instance_parameter_value pll_156t40 {gui_actual_phase_shift9} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter0} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter1} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter10} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter11} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter12} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter13} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter14} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter15} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter16} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter17} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter2} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter3} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter4} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter5} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter6} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter7} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter8} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_counter9} {0}
set_instance_parameter_value pll_156t40 {gui_cascade_outclk_index} {0}
set_instance_parameter_value pll_156t40 {gui_channel_spacing} {0.0}
set_instance_parameter_value pll_156t40 {gui_clk_bad} {0}
set_instance_parameter_value pll_156t40 {gui_device_speed_grade} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c0} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c1} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c10} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c11} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c12} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c13} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c14} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c15} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c16} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c17} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c2} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c3} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c4} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c5} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c6} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c7} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c8} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_c9} {1}
set_instance_parameter_value pll_156t40 {gui_divide_factor_n} {1}
set_instance_parameter_value pll_156t40 {gui_dps_cntr} {C0}
set_instance_parameter_value pll_156t40 {gui_dps_dir} {Positive}
set_instance_parameter_value pll_156t40 {gui_dps_num} {1}
set_instance_parameter_value pll_156t40 {gui_dsm_out_sel} {1st_order}
set_instance_parameter_value pll_156t40 {gui_duty_cycle0} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle1} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle10} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle11} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle12} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle13} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle14} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle15} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle16} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle17} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle2} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle3} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle4} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle5} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle6} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle7} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle8} {50}
set_instance_parameter_value pll_156t40 {gui_duty_cycle9} {50}
set_instance_parameter_value pll_156t40 {gui_en_adv_params} {0}
set_instance_parameter_value pll_156t40 {gui_en_dps_ports} {0}
set_instance_parameter_value pll_156t40 {gui_en_phout_ports} {0}
set_instance_parameter_value pll_156t40 {gui_en_reconf} {0}
set_instance_parameter_value pll_156t40 {gui_enable_cascade_in} {0}
set_instance_parameter_value pll_156t40 {gui_enable_cascade_out} {0}
set_instance_parameter_value pll_156t40 {gui_enable_mif_dps} {0}
set_instance_parameter_value pll_156t40 {gui_feedback_clock} {Global Clock}
set_instance_parameter_value pll_156t40 {gui_frac_multiply_factor} {1.0}
set_instance_parameter_value pll_156t40 {gui_fractional_cout} {32}
set_instance_parameter_value pll_156t40 {gui_mif_generate} {0}
set_instance_parameter_value pll_156t40 {gui_multiply_factor} {1}
set_instance_parameter_value pll_156t40 {gui_number_of_clocks} {1}
set_instance_parameter_value pll_156t40 {gui_operation_mode} {direct}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency0} {40.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency1} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency10} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency11} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency12} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency13} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency14} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency15} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency16} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency17} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency2} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency3} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency4} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency5} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency6} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency7} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency8} {100.0}
set_instance_parameter_value pll_156t40 {gui_output_clock_frequency9} {100.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift0} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift1} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift10} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift11} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift12} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift13} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift14} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift15} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift16} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift17} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift2} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift3} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift4} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift5} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift6} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift7} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift8} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift9} {0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg0} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg1} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg10} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg11} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg12} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg13} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg14} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg15} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg16} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg17} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg2} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg3} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg4} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg5} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg6} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg7} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg8} {0.0}
set_instance_parameter_value pll_156t40 {gui_phase_shift_deg9} {0.0}
set_instance_parameter_value pll_156t40 {gui_phout_division} {1}
set_instance_parameter_value pll_156t40 {gui_pll_auto_reset} {Off}
set_instance_parameter_value pll_156t40 {gui_pll_bandwidth_preset} {Auto}
set_instance_parameter_value pll_156t40 {gui_pll_cascading_mode} {Create an adjpllin signal to connect with an upstream PLL}
set_instance_parameter_value pll_156t40 {gui_pll_mode} {Integer-N PLL}
set_instance_parameter_value pll_156t40 {gui_ps_units0} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units1} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units10} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units11} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units12} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units13} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units14} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units15} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units16} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units17} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units2} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units3} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units4} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units5} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units6} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units7} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units8} {ps}
set_instance_parameter_value pll_156t40 {gui_ps_units9} {ps}
set_instance_parameter_value pll_156t40 {gui_refclk1_frequency} {100.0}
set_instance_parameter_value pll_156t40 {gui_refclk_switch} {0}
set_instance_parameter_value pll_156t40 {gui_reference_clock_frequency} {156.25}
set_instance_parameter_value pll_156t40 {gui_switchover_delay} {0}
set_instance_parameter_value pll_156t40 {gui_switchover_mode} {Automatic Switchover}
set_instance_parameter_value pll_156t40 {gui_use_locked} {1}

add_instance sc_hub sc_hub 24.0.711
set_instance_parameter_value sc_hub {BACKPRESSURE} {1}
set_instance_parameter_value sc_hub {DEBUG} {1}
set_instance_parameter_value sc_hub {INVERT_RD_SIG} {1}
set_instance_parameter_value sc_hub {SCHEDULER_USE_PKT_TRANSFER} {1}

add_instance scratch_pad_ram altera_avalon_onchip_memory2 18.1
set_instance_parameter_value scratch_pad_ram {allowInSystemMemoryContentEditor} {1}
set_instance_parameter_value scratch_pad_ram {blockType} {M10K}
set_instance_parameter_value scratch_pad_ram {copyInitFile} {0}
set_instance_parameter_value scratch_pad_ram {dataWidth} {32}
set_instance_parameter_value scratch_pad_ram {dataWidth2} {32}
set_instance_parameter_value scratch_pad_ram {dualPort} {0}
set_instance_parameter_value scratch_pad_ram {ecc_enabled} {0}
set_instance_parameter_value scratch_pad_ram {enPRInitMode} {0}
set_instance_parameter_value scratch_pad_ram {enableDiffWidth} {0}
set_instance_parameter_value scratch_pad_ram {initMemContent} {1}
set_instance_parameter_value scratch_pad_ram {initializationFileName} {onchip_mem.hex}
set_instance_parameter_value scratch_pad_ram {instanceID} {1}
set_instance_parameter_value scratch_pad_ram {memorySize} {1024.0}
set_instance_parameter_value scratch_pad_ram {readDuringWriteMode} {DONT_CARE}
set_instance_parameter_value scratch_pad_ram {resetrequest_enabled} {1}
set_instance_parameter_value scratch_pad_ram {simAllowMRAMContentsFile} {0}
set_instance_parameter_value scratch_pad_ram {simMemInitOnlyFilename} {0}
set_instance_parameter_value scratch_pad_ram {singleClockOperation} {0}
set_instance_parameter_value scratch_pad_ram {slave1Latency} {1}
set_instance_parameter_value scratch_pad_ram {slave2Latency} {1}
set_instance_parameter_value scratch_pad_ram {useNonDefaultInitFile} {0}
set_instance_parameter_value scratch_pad_ram {useShallowMemBlocks} {0}
set_instance_parameter_value scratch_pad_ram {writable} {1}

add_instance temp_sensor_dab_0 one_wire_dri 3.7.1
set_instance_parameter_value temp_sensor_dab_0 {BAUD_RATE} {10000}
set_instance_parameter_value temp_sensor_dab_0 {CONVERSION_WAIT_T_MS} {800}
set_instance_parameter_value temp_sensor_dab_0 {PARACITIC_POWERING} {1}
set_instance_parameter_value temp_sensor_dab_0 {SENSOR_TYPE} {DS18B20}
set_instance_parameter_value temp_sensor_dab_0 {TEMPERATURE_RESOLUTION} {12}

add_instance temp_sensor_dab_1 one_wire_dri 3.7.1
set_instance_parameter_value temp_sensor_dab_1 {BAUD_RATE} {10000}
set_instance_parameter_value temp_sensor_dab_1 {CONVERSION_WAIT_T_MS} {800}
set_instance_parameter_value temp_sensor_dab_1 {PARACITIC_POWERING} {1}
set_instance_parameter_value temp_sensor_dab_1 {SENSOR_TYPE} {DS18B20}
set_instance_parameter_value temp_sensor_dab_1 {TEMPERATURE_RESOLUTION} {12}

add_instance temp_sensor_mutrig_0 one_wire_dri 3.7.1
set_instance_parameter_value temp_sensor_mutrig_0 {BAUD_RATE} {10000}
set_instance_parameter_value temp_sensor_mutrig_0 {CONVERSION_WAIT_T_MS} {800}
set_instance_parameter_value temp_sensor_mutrig_0 {PARACITIC_POWERING} {1}
set_instance_parameter_value temp_sensor_mutrig_0 {SENSOR_TYPE} {DS18B20}
set_instance_parameter_value temp_sensor_mutrig_0 {TEMPERATURE_RESOLUTION} {12}

add_instance temp_sensor_mutrig_1 one_wire_dri 3.7.1
set_instance_parameter_value temp_sensor_mutrig_1 {BAUD_RATE} {10000}
set_instance_parameter_value temp_sensor_mutrig_1 {CONVERSION_WAIT_T_MS} {800}
set_instance_parameter_value temp_sensor_mutrig_1 {PARACITIC_POWERING} {1}
set_instance_parameter_value temp_sensor_mutrig_1 {SENSOR_TYPE} {DS18B20}
set_instance_parameter_value temp_sensor_mutrig_1 {TEMPERATURE_RESOLUTION} {12}

add_instance temp_sensor_sipm_0 one_wire_dri 3.7.1
set_instance_parameter_value temp_sensor_sipm_0 {BAUD_RATE} {10000}
set_instance_parameter_value temp_sensor_sipm_0 {CONVERSION_WAIT_T_MS} {800}
set_instance_parameter_value temp_sensor_sipm_0 {PARACITIC_POWERING} {1}
set_instance_parameter_value temp_sensor_sipm_0 {SENSOR_TYPE} {DS18B20}
set_instance_parameter_value temp_sensor_sipm_0 {TEMPERATURE_RESOLUTION} {12}

add_instance temp_sensor_sipm_1 one_wire_dri 3.7.1
set_instance_parameter_value temp_sensor_sipm_1 {BAUD_RATE} {10000}
set_instance_parameter_value temp_sensor_sipm_1 {CONVERSION_WAIT_T_MS} {800}
set_instance_parameter_value temp_sensor_sipm_1 {PARACITIC_POWERING} {1}
set_instance_parameter_value temp_sensor_sipm_1 {SENSOR_TYPE} {DS18B20}
set_instance_parameter_value temp_sensor_sipm_1 {TEMPERATURE_RESOLUTION} {12}

# exported interfaces
add_interface avmm_port avalon master
set_interface_property avmm_port EXPORT_OF mm_bridge.m0
add_interface clk125_in_clk clock sink
set_interface_property clk125_in_clk EXPORT_OF clk125.in_clk
add_interface clk156_in_clk clock sink
set_interface_property clk156_in_clk EXPORT_OF clk156.clk_in
add_interface clk156_in_rst reset sink
set_interface_property clk156_in_rst EXPORT_OF clk156.clk_in_reset
add_interface data_sc_merger_out avalon_streaming source
set_interface_property data_sc_merger_out EXPORT_OF data_sc_merger.out
add_interface mutrig_cfg_ctrl_0_spi_export2top conduit end
set_interface_property mutrig_cfg_ctrl_0_spi_export2top EXPORT_OF mutrig_cfg_ctrl_0.spi_export2top
add_interface pulse_out_conduit conduit end
set_interface_property pulse_out_conduit EXPORT_OF charge_injection_pulser_0.pulse_out_conduit
add_interface sc_hub_hub_sc_packet_downlink conduit end
set_interface_property sc_hub_hub_sc_packet_downlink EXPORT_OF sc_hub.hub_sc_packet_downlink
add_interface sclr_counter_req reset source
set_interface_property sclr_counter_req EXPORT_OF mutrig_cfg_ctrl_0.sclr_counter_req
add_interface temp_sensor_dab0 conduit end
set_interface_property temp_sensor_dab0 EXPORT_OF temp_sensor_dab_0.sensor_dq
add_interface temp_sensor_dab1 conduit end
set_interface_property temp_sensor_dab1 EXPORT_OF temp_sensor_dab_1.sensor_dq
add_interface temp_sensor_mutrig0 conduit end
set_interface_property temp_sensor_mutrig0 EXPORT_OF temp_sensor_mutrig_0.sensor_dq
add_interface temp_sensor_mutrig1 conduit end
set_interface_property temp_sensor_mutrig1 EXPORT_OF temp_sensor_mutrig_1.sensor_dq
add_interface temp_sensor_sipm0 conduit end
set_interface_property temp_sensor_sipm0 EXPORT_OF temp_sensor_sipm_0.sensor_dq
add_interface temp_sensor_sipm1 conduit end
set_interface_property temp_sensor_sipm1 EXPORT_OF temp_sensor_sipm_1.sensor_dq
add_interface to_firefly_ucc8 conduit end
set_interface_property to_firefly_ucc8 EXPORT_OF firefly_xcvr_ctrl_0.to_firefly_ucc8

# connections and connection parameters
add_connection clk125.out_clk charge_injection_pulser_0.clock_interface

add_connection clk125.out_clk temp_sensor_dab_0.system_clock

add_connection clk125.out_clk temp_sensor_dab_1.system_clock

add_connection clk125.out_clk temp_sensor_mutrig_0.system_clock

add_connection clk125.out_clk temp_sensor_mutrig_1.system_clock

add_connection clk125.out_clk temp_sensor_sipm_0.system_clock

add_connection clk125.out_clk temp_sensor_sipm_1.system_clock

add_connection clk156.clk data_sc_merger.clk

add_connection clk156.clk firefly_xcvr_ctrl_0.system_clock

add_connection clk156.clk jtag_master.clk

add_connection clk156.clk mm_bridge.clk

add_connection clk156.clk mutrig_cfg_ctrl_0.controller_clock

add_connection clk156.clk pll_156t40.refclk

add_connection clk156.clk sc_hub.hub_clock

add_connection clk156.clk scratch_pad_ram.clk1

add_connection clk156.clk_reset data_sc_merger.reset

add_connection clk156.clk_reset firefly_xcvr_ctrl_0.system_reset

add_connection clk156.clk_reset jtag_master.clk_reset

add_connection clk156.clk_reset mm_bridge.reset

add_connection clk156.clk_reset mutrig_cfg_ctrl_0.controller_reset

add_connection clk156.clk_reset on_die_temp_sense_ctrl.system_reset

add_connection clk156.clk_reset pll_156t40.reset

add_connection clk156.clk_reset sc_hub.hub_reset

add_connection clk156.clk_reset scratch_pad_ram.reset1

add_connection clk156.clk_reset temp_sensor_dab_0.reset_sink

add_connection clk156.clk_reset temp_sensor_dab_1.reset_sink

add_connection clk156.clk_reset temp_sensor_mutrig_0.reset_sink

add_connection clk156.clk_reset temp_sensor_mutrig_1.reset_sink

add_connection clk156.clk_reset temp_sensor_sipm_0.reset_sink

add_connection clk156.clk_reset temp_sensor_sipm_1.reset_sink

add_connection jtag_master.master charge_injection_pulser_0.csr_avmm
set_connection_parameter_value jtag_master.master/charge_injection_pulser_0.csr_avmm arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/charge_injection_pulser_0.csr_avmm baseAddress {0x04c4}
set_connection_parameter_value jtag_master.master/charge_injection_pulser_0.csr_avmm defaultConnection {0}

add_connection jtag_master.master firefly_xcvr_ctrl_0.firefly
set_connection_parameter_value jtag_master.master/firefly_xcvr_ctrl_0.firefly arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/firefly_xcvr_ctrl_0.firefly baseAddress {0x0500}
set_connection_parameter_value jtag_master.master/firefly_xcvr_ctrl_0.firefly defaultConnection {0}

add_connection jtag_master.master mutrig_cfg_ctrl_0.avmm_csr
set_connection_parameter_value jtag_master.master/mutrig_cfg_ctrl_0.avmm_csr arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/mutrig_cfg_ctrl_0.avmm_csr baseAddress {0x0003f010}
set_connection_parameter_value jtag_master.master/mutrig_cfg_ctrl_0.avmm_csr defaultConnection {0}

add_connection jtag_master.master mutrig_cfg_ctrl_0.avmm_scanresult
set_connection_parameter_value jtag_master.master/mutrig_cfg_ctrl_0.avmm_scanresult arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/mutrig_cfg_ctrl_0.avmm_scanresult baseAddress {0x00010000}
set_connection_parameter_value jtag_master.master/mutrig_cfg_ctrl_0.avmm_scanresult defaultConnection {0}

add_connection jtag_master.master on_die_temp_sense_ctrl.csr
set_connection_parameter_value jtag_master.master/on_die_temp_sense_ctrl.csr arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/on_die_temp_sense_ctrl.csr baseAddress {0x04c0}
set_connection_parameter_value jtag_master.master/on_die_temp_sense_ctrl.csr defaultConnection {0}

add_connection jtag_master.master scratch_pad_ram.s1
set_connection_parameter_value jtag_master.master/scratch_pad_ram.s1 arbitrationPriority {3}
set_connection_parameter_value jtag_master.master/scratch_pad_ram.s1 baseAddress {0x0000}
set_connection_parameter_value jtag_master.master/scratch_pad_ram.s1 defaultConnection {0}

add_connection jtag_master.master temp_sensor_dab_0.s0_driver
set_connection_parameter_value jtag_master.master/temp_sensor_dab_0.s0_driver arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/temp_sensor_dab_0.s0_driver baseAddress {0x04a0}
set_connection_parameter_value jtag_master.master/temp_sensor_dab_0.s0_driver defaultConnection {0}

add_connection jtag_master.master temp_sensor_dab_1.s0_driver
set_connection_parameter_value jtag_master.master/temp_sensor_dab_1.s0_driver arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/temp_sensor_dab_1.s0_driver baseAddress {0x0480}
set_connection_parameter_value jtag_master.master/temp_sensor_dab_1.s0_driver defaultConnection {0}

add_connection jtag_master.master temp_sensor_mutrig_0.s0_driver
set_connection_parameter_value jtag_master.master/temp_sensor_mutrig_0.s0_driver arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/temp_sensor_mutrig_0.s0_driver baseAddress {0x0420}
set_connection_parameter_value jtag_master.master/temp_sensor_mutrig_0.s0_driver defaultConnection {0}

add_connection jtag_master.master temp_sensor_mutrig_1.s0_driver
set_connection_parameter_value jtag_master.master/temp_sensor_mutrig_1.s0_driver arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/temp_sensor_mutrig_1.s0_driver baseAddress {0x0400}
set_connection_parameter_value jtag_master.master/temp_sensor_mutrig_1.s0_driver defaultConnection {0}

add_connection jtag_master.master temp_sensor_sipm_0.s0_driver
set_connection_parameter_value jtag_master.master/temp_sensor_sipm_0.s0_driver arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/temp_sensor_sipm_0.s0_driver baseAddress {0x0460}
set_connection_parameter_value jtag_master.master/temp_sensor_sipm_0.s0_driver defaultConnection {0}

add_connection jtag_master.master temp_sensor_sipm_1.s0_driver
set_connection_parameter_value jtag_master.master/temp_sensor_sipm_1.s0_driver arbitrationPriority {1}
set_connection_parameter_value jtag_master.master/temp_sensor_sipm_1.s0_driver baseAddress {0x0440}
set_connection_parameter_value jtag_master.master/temp_sensor_sipm_1.s0_driver defaultConnection {0}

add_connection jtag_master.master_reset charge_injection_pulser_0.reset_interface

add_connection jtag_master.master_reset data_sc_merger.reset

add_connection jtag_master.master_reset firefly_xcvr_ctrl_0.system_reset

add_connection jtag_master.master_reset mutrig_cfg_ctrl_0.controller_reset

add_connection jtag_master.master_reset on_die_temp_sense_ctrl.system_reset

add_connection jtag_master.master_reset pll_156t40.reset

add_connection jtag_master.master_reset sc_hub.hub_reset

add_connection jtag_master.master_reset scratch_pad_ram.reset1

add_connection jtag_master.master_reset temp_sensor_dab_0.reset_sink

add_connection jtag_master.master_reset temp_sensor_dab_1.reset_sink

add_connection jtag_master.master_reset temp_sensor_mutrig_0.reset_sink

add_connection jtag_master.master_reset temp_sensor_mutrig_1.reset_sink

add_connection jtag_master.master_reset temp_sensor_sipm_0.reset_sink

add_connection jtag_master.master_reset temp_sensor_sipm_1.reset_sink

add_connection mutrig_cfg_ctrl_0.avmm_cnt mm_bridge.s0
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_cnt/mm_bridge.s0 arbitrationPriority {1}
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_cnt/mm_bridge.s0 baseAddress {0x00020000}
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_cnt/mm_bridge.s0 defaultConnection {0}

add_connection mutrig_cfg_ctrl_0.avmm_cnt scratch_pad_ram.s1
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_cnt/scratch_pad_ram.s1 arbitrationPriority {1}
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_cnt/scratch_pad_ram.s1 baseAddress {0x0000}
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_cnt/scratch_pad_ram.s1 defaultConnection {0}

add_connection mutrig_cfg_ctrl_0.avmm_schpad scratch_pad_ram.s1
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_schpad/scratch_pad_ram.s1 arbitrationPriority {2}
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_schpad/scratch_pad_ram.s1 baseAddress {0x0000}
set_connection_parameter_value mutrig_cfg_ctrl_0.avmm_schpad/scratch_pad_ram.s1 defaultConnection {0}

add_connection on_die_temp_sense.tsdcaldone on_die_temp_sense_ctrl.tsdcaldone
set_connection_parameter_value on_die_temp_sense.tsdcaldone/on_die_temp_sense_ctrl.tsdcaldone endPort {}
set_connection_parameter_value on_die_temp_sense.tsdcaldone/on_die_temp_sense_ctrl.tsdcaldone endPortLSB {0}
set_connection_parameter_value on_die_temp_sense.tsdcaldone/on_die_temp_sense_ctrl.tsdcaldone startPort {}
set_connection_parameter_value on_die_temp_sense.tsdcaldone/on_die_temp_sense_ctrl.tsdcaldone startPortLSB {0}
set_connection_parameter_value on_die_temp_sense.tsdcaldone/on_die_temp_sense_ctrl.tsdcaldone width {0}

add_connection on_die_temp_sense_ctrl.ce on_die_temp_sense.ce
set_connection_parameter_value on_die_temp_sense_ctrl.ce/on_die_temp_sense.ce endPort {}
set_connection_parameter_value on_die_temp_sense_ctrl.ce/on_die_temp_sense.ce endPortLSB {0}
set_connection_parameter_value on_die_temp_sense_ctrl.ce/on_die_temp_sense.ce startPort {}
set_connection_parameter_value on_die_temp_sense_ctrl.ce/on_die_temp_sense.ce startPortLSB {0}
set_connection_parameter_value on_die_temp_sense_ctrl.ce/on_die_temp_sense.ce width {0}

add_connection on_die_temp_sense_ctrl.clr on_die_temp_sense.clr

add_connection on_die_temp_sense_ctrl.tsdcalo on_die_temp_sense.tsdcalo
set_connection_parameter_value on_die_temp_sense_ctrl.tsdcalo/on_die_temp_sense.tsdcalo endPort {}
set_connection_parameter_value on_die_temp_sense_ctrl.tsdcalo/on_die_temp_sense.tsdcalo endPortLSB {0}
set_connection_parameter_value on_die_temp_sense_ctrl.tsdcalo/on_die_temp_sense.tsdcalo startPort {}
set_connection_parameter_value on_die_temp_sense_ctrl.tsdcalo/on_die_temp_sense.tsdcalo startPortLSB {0}
set_connection_parameter_value on_die_temp_sense_ctrl.tsdcalo/on_die_temp_sense.tsdcalo width {0}

add_connection pll_156t40.outclk0 mutrig_cfg_ctrl_0.spi_clock

add_connection pll_156t40.outclk0 on_die_temp_sense.clk

add_connection pll_156t40.outclk0 on_die_temp_sense_ctrl.system_clock

add_connection sc_hub.hub_avmm mm_bridge.s0
set_connection_parameter_value sc_hub.hub_avmm/mm_bridge.s0 arbitrationPriority {1}
set_connection_parameter_value sc_hub.hub_avmm/mm_bridge.s0 baseAddress {0x00020000}
set_connection_parameter_value sc_hub.hub_avmm/mm_bridge.s0 defaultConnection {0}

add_connection sc_hub.hub_avmm mutrig_cfg_ctrl_0.avmm_csr
set_connection_parameter_value sc_hub.hub_avmm/mutrig_cfg_ctrl_0.avmm_csr arbitrationPriority {1}
set_connection_parameter_value sc_hub.hub_avmm/mutrig_cfg_ctrl_0.avmm_csr baseAddress {0x0003f010}
set_connection_parameter_value sc_hub.hub_avmm/mutrig_cfg_ctrl_0.avmm_csr defaultConnection {0}

add_connection sc_hub.hub_avmm scratch_pad_ram.s1
set_connection_parameter_value sc_hub.hub_avmm/scratch_pad_ram.s1 arbitrationPriority {1}
set_connection_parameter_value sc_hub.hub_avmm/scratch_pad_ram.s1 baseAddress {0x0000}
set_connection_parameter_value sc_hub.hub_avmm/scratch_pad_ram.s1 defaultConnection {0}

add_connection sc_hub.hub_sc_packet_uplink data_sc_merger.in1

# interconnect requirements
set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {FIFO}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.enableInstrumentation} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {TRUE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}
set_interconnect_requirement {jtag_master.master} {qsys_mm.security} {NON_SECURE}
set_interconnect_requirement {mutrig_cfg_ctrl_0.avmm_schpad} {qsys_mm.insertPerformanceMonitor} {TRUE}
set_interconnect_requirement {mutrig_spi_master.spi_control_port} {qsys_mm.security} {NON_SECURE}
set_interconnect_requirement {new_target} {new_requirement_name} {new_requirement_value}
set_interconnect_requirement {new_target} {new_requirement_name_0} {new_requirement_value}
set_interconnect_requirement {new_target} {new_requirement_name_1} {new_requirement_value}
set_interconnect_requirement {new_target} {new_requirement_name_2} {new_requirement_value}
set_interconnect_requirement {new_target} {new_requirement_name_3} {new_requirement_value}
set_interconnect_requirement {new_target} {new_requirement_name_4} {new_requirement_value}
set_interconnect_requirement {sc_hub.hub_avmm} {qsys_mm.insertPerformanceMonitor} {TRUE}
set_interconnect_requirement {sc_hub.m0} {qsys_mm.insertPerformanceMonitor} {TRUE}
set_interconnect_requirement {scratch_pad_ram.s1} {qsys_mm.insertPerformanceMonitor} {TRUE}

save_system {debug_sc_system.qsys}

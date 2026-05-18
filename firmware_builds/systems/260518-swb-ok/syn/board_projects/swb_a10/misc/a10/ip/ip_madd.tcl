#

source "device.tcl"

# Instances and instance parameters
# (disabled instances are intentionally culled)
add_instance fpdsp_block_0 altera_fpdsp_block
set_instance_parameter_value fpdsp_block_0 {OPERATION} {sp_mult_add}
set_instance_parameter_value fpdsp_block_0 {VIEW} {Register Enables}
set_instance_parameter_value fpdsp_block_0 {accum_adder_clock} {0}
set_instance_parameter_value fpdsp_block_0 {accum_pipeline_clock} {0}
set_instance_parameter_value fpdsp_block_0 {accumulate_clock} {0}
set_instance_parameter_value fpdsp_block_0 {adder_input_2_clock} {0}
set_instance_parameter_value fpdsp_block_0 {adder_input_clock} {0}
set_instance_parameter_value fpdsp_block_0 {adder_subtract} {0}
set_instance_parameter_value fpdsp_block_0 {ax_chainin_pl_clock} {0}
set_instance_parameter_value fpdsp_block_0 {ax_clock} {0}
set_instance_parameter_value fpdsp_block_0 {ay_clock} {0}
set_instance_parameter_value fpdsp_block_0 {az_clock} {0}
set_instance_parameter_value fpdsp_block_0 {chain_mux} {0}
set_instance_parameter_value fpdsp_block_0 {chain_out_mux} {0}
set_instance_parameter_value fpdsp_block_0 {mult_pipeline_clock} {0}
set_instance_parameter_value fpdsp_block_0 {output_clock} {0}
set_instance_parameter_value fpdsp_block_0 {single_clear} {0}

# exported interfaces
set_instance_property fpdsp_block_0 AUTO_EXPORT {true}

# interconnect requirements
set_interconnect_requirement {$system} {qsys_mm.clockCrossingAdapter} {HANDSHAKE}
set_interconnect_requirement {$system} {qsys_mm.enableEccProtection} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.insertDefaultSlave} {FALSE}
set_interconnect_requirement {$system} {qsys_mm.maxAdditionalLatency} {1}


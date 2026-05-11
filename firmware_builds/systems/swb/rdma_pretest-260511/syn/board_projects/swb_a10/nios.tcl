#

source {device.tcl}

source {util/nios_base.tcl}
set_instance_parameter_value ram memorySize 0x00080000
set_instance_parameter_value spi numberOfSlaves 32

source {util/flash1616.tcl}

nios_base.export_avm avm_xcvr0 18 0x70100000
nios_base.export_avm avm_xcvr1 18 0x70200000
nios_base.export_avm avm_sfp 14 0x70300000

# SWB-specific override:
# - Use Nios II/e class implementation (Tiny) to avoid evaluation-only bitstreams.
# - Keep forced encrypted generation disabled.
set_instance_parameter_value cpu {impl} {Tiny}
set_instance_parameter_value cpu {setting_alwaysEncrypt} {false}

#

source "device.tcl"

add_instance emif_0 altera_emif

set_instance_parameter_value emif_0 {MEM_DDR3_DQ_WIDTH} {64}

set_instance_parameter_value emif_0 {MEM_DDR3_FORMAT_ENUM} {MEM_FORMAT_SODIMM}

set_instance_parameter_value emif_0 {MEM_DDR3_ROW_ADDR_WIDTH} {16}

set_instance_parameter_value emif_0 {MEM_DDR3_TCL} {13}
set_instance_parameter_value emif_0 {MEM_DDR3_TDH_DC_MV} {90}
set_instance_parameter_value emif_0 {MEM_DDR3_TDH_PS} {60}

set_instance_parameter_value emif_0 {MEM_DDR3_TDS_AC_MV} {130}
set_instance_parameter_value emif_0 {MEM_DDR3_TDS_PS} {55}

set_instance_parameter_value emif_0 {MEM_DDR3_TIH_DC_MV} {90}

set_instance_parameter_value emif_0 {MEM_DDR3_TIS_AC_MV} {125}
set_instance_parameter_value emif_0 {MEM_DDR3_TIS_PS} {135}

set_instance_parameter_value emif_0 {MEM_DDR3_TRCD_NS} {10.285}

set_instance_parameter_value emif_0 {MEM_DDR3_TRFC_NS} {260.0}
set_instance_parameter_value emif_0 {MEM_DDR3_TRP_NS} {10.285}

set_instance_parameter_value emif_0 {PHY_DDR3_IO_VOLTAGE} {1.35}

set_instance_property emif_0 AUTO_EXPORT {true}

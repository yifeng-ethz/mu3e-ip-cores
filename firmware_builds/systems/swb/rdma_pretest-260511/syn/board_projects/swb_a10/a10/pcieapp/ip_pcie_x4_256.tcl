#

source "device.tcl"
source "util/altera_ip.tcl"

add_instance pcie_a10_hip_0 altera_pcie_a10_hip
set_instance_parameter_value pcie_a10_hip_0 {bar0_address_width_hwtcl} {12}
set_instance_parameter_value pcie_a10_hip_0 {bar0_type_hwtcl} {32-bit non-prefetchable memory}
set_instance_parameter_value pcie_a10_hip_0 {bar1_address_width_hwtcl} {12}
set_instance_parameter_value pcie_a10_hip_0 {bar1_type_hwtcl} {32-bit non-prefetchable memory}
set_instance_parameter_value pcie_a10_hip_0 {bar2_address_width_hwtcl} {18}
set_instance_parameter_value pcie_a10_hip_0 {bar2_type_hwtcl} {32-bit non-prefetchable memory}
set_instance_parameter_value pcie_a10_hip_0 {bar3_address_width_hwtcl} {18}
set_instance_parameter_value pcie_a10_hip_0 {bar3_type_hwtcl} {32-bit non-prefetchable memory}
set_instance_parameter_value pcie_a10_hip_0 {class_code_hwtcl} {16711680}
set_instance_parameter_value pcie_a10_hip_0 {device_id_hwtcl} {4}
set_instance_parameter_value pcie_a10_hip_0 {maximum_payload_size_hwtcl} {2048}
set_instance_parameter_value pcie_a10_hip_0 {revision_id_hwtcl} {1}
set_instance_parameter_value pcie_a10_hip_0 {subsystem_device_id_hwtcl} {4}
set_instance_parameter_value pcie_a10_hip_0 {subsystem_vendor_id_hwtcl} {4466}
set_instance_parameter_value pcie_a10_hip_0 {wrala_hwtcl} {1}
set_instance_property pcie_a10_hip_0 AUTO_EXPORT {true}

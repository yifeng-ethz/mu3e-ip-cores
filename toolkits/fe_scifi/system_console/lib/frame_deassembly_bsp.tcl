###########################################################################################################
# @Name 	    frame_deassembly_bsp.tcl
#
# @Brief		Board-Support-Package (BSP) of the Frame Deassembly IP core. 
#				Contains the address map info.
#
# @Functions	.
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Oct 31, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide frame_deassembly::bsp 	24.0

namespace eval ::frame_deassembly::bsp:: {
	namespace export \
    get_address_map 
    
    
    
}



proc ::frame_deassembly::bsp::get_address_map {} {
   
    array set csr_map {}
    ################################################ csr ################################################
    set csr_map(0)  \
    "
    <register>
        <name>csr</name>
        <description>CSR of Frame Deassembly IP</description>
        <addressOffset>0x0</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>control</name>
                <description>user control to enable or mask frame parsing and hit generation during RUNNING</description>
                <bitRange>\[0:0\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>status</name>
                <description>frame flag (gen_idle | fast_mode | prbs_debug | single_prbs | fifo_full | pll_lol_n)</description>
                <bitRange>\[31:24\]</bitRange>
                <access>read-write</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ error counter ################################################
    set csr_map(1)  \
    "
    <register>
        <name>error_counter</name>
        <description>frame error counter</description>
        <addressOffset>0x4</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>crc errors</name>
                <description>the number of frames with crc validation error, possibly corrupted</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
            
        </fields>
    </register>
    "
    
    
    ################################################ frame counter ################################################
    set csr_map(2)  \
    "
    <register>
        <name>frame_counter</name>
        <description>bad frame counter</description>
        <addressOffset>0x8</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>bad frame counts</name>
                <description>the number of bad frames (head - tail, so can be negative)</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
            
        </fields>
    </register>
    "
    
    return [array get csr_map]
    
}
    
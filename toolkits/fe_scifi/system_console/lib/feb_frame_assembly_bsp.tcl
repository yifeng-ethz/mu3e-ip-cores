###########################################################################################################
# @Name 	    feb_frame_assembly_bsp.tcl
#
# @Brief		Board-Support-Package (BSP) of the Frame Assembly IP core. 
#				Contains the address map info.
#
# @Functions	.
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Mar 24, 2025
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide feb_frame_assembly::bsp 	24.0

namespace eval ::feb_frame_assembly::bsp:: {
	namespace export \
    get_address_map \
    configure
}

proc ::feb_frame_assembly::bsp::get_address_map {} {
    array set csr_map {}
    ################################################ capa. ################################################
    set csr_map(0)  \
    "
    <register>
        <name>Capability</name>
        <description>Capability register of the FEB. Hot configurable.</description>
        <addressOffset>0x0</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>feb_type</name>
                <description>Feb type (6 bit) is used in main frame preamble field. ex: 111010-Mupix, 111000-SciFi, 110100-Tile, etc. Refer to the spec book.</description>
                <bitRange>\[5:0\]</bitRange>
                <access>read-write</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ config. ################################################
    set csr_map(1)  \
    "
    <register>
        <name>Configuration</name>
        <description>Configuration register of the FEB. Hot configurable.</description>
        <addressOffset>0x4</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>feb_id</name>
                <description>Feb ID (16 bit) is used in main frame preamble field.</description>
                <bitRange>\[15:0\]</bitRange>
                <access>read-write</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ decleared hit H ################################################
    set csr_map(2)  \
    "
    <register>
        <name>Decleared hits high</name>
        <description>top 16 bits of the decleared hits counter</description>
        <addressOffset>0x8</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>decleared_hits_h</name>
                <description>decleared hits counter\[47:32\]</description>
                <bitRange>\[15:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ decleared hit L ################################################
    set csr_map(3)  \
    "
    <register>
        <name>Decleared hits low</name>
        <description>bottom 32 bits of the decleared hits counter</description>
        <addressOffset>0xc</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>decleared_hits_l</name>
                <description>decleared hits counter\[31:0\]</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ actual hit H ################################################
    set csr_map(4)  \
    "
    <register>
        <name>Actual hits high</name>
        <description>top 16 bits of the actual hits counter</description>
        <addressOffset>0x10</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>actual_hits_h</name>
                <description>actual hits counter\[47:32\]</description>
                <bitRange>\[15:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ actual hit L ################################################
    set csr_map(5)  \
    "
    <register>
        <name>Actual hits low</name>
        <description>bottom 32 bits of the actual hits counter</description>
        <addressOffset>0x14</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>actual_hits_l</name>
                <description>actual hits counter\[31:0\]</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ missing hit H ################################################
    set csr_map(6)  \
    "
    <register>
        <name>Missing hits high</name>
        <description>top 16 bits of the missing hits counter. Rejected by the sub FIFO.</description>
        <addressOffset>0x18</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>missing_hits_h</name>
                <description>actual hits counter\[47:32\]</description>
                <bitRange>\[15:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "
    
    ################################################ missing hit L ################################################
    set csr_map(7)  \
    "
    <register>
        <name>Missing hits high</name>
        <description>bottom 32 bits of the missing hits counter. Rejected by the sub FIFO.</description>
        <addressOffset>0x1c</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>missing_hits_l</name>
                <description>actual hits counter\[31:0\]</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "
    return [array get csr_map]
}

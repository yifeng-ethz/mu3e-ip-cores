###########################################################################################################
# @Name 	    mutrig_injector_bsp.tcl
#
# @Brief		Board-Support-Package (BSP) of the MuTRiG Injector IP core. 
#				Contains the address map info.
#
# @Functions	.
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Nov 13, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide mutrig_injector::bsp 	24.0

namespace eval ::mutrig_injector::bsp:: {
	namespace export \
    get_address_map \
    configure
    
    variable headerinfo_channel_w 
}


proc ::mutrig_injector::bsp::configure args {
    # init...
    variable headerinfo_channel_w

    array set options {-HEADERINFO_CHANNEL_W 4}
    while {[llength $args]} {
        switch -glob -- [lindex $args 0] {
            -HEADERINFO_CHANNEL_W   {set args [lassign $args - options(-HEADERINFO_CHANNEL_W)]}
            --      {set args [lrange $args 1 end] ; break}
            -*      {error "unknown option [lindex $args 0]"}
            default break
        }
    }
    #puts "options: [array get options]"
    #puts "other args: $args"
    
    set headerinfo_channel_w $options(-HEADERINFO_CHANNEL_W)
    #puts "configure:"
    #puts $headerinfo_channel_w
    
    return -code ok
}


proc ::mutrig_injector::bsp::get_address_map {} {
    variable headerinfo_channel_w 
    
    #
    array set csr_map {}
    ################################################ mode ################################################
    set csr_map(0)  \
    "
    <register>
        <name>inject_mode</name>
        <description>Injection mode of MuTRiG Injector IP</description>
        <addressOffset>0x0</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>mode</name>
                <description>0=off; 1=header_sync; 2=periodic; 3=periodic_async; 4=onclick; 5=random</description>
                <bitRange>\[3:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    ################################################ header_delay ################################################
    set csr_map(1)  \
    "
    <register>
        <name>header_delay</name>
        <description>Delay after header is seen.</description>
        <addressOffset>0x4</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>header_delay</name>
                <description>(header_sync mode only) In clock cycles. *Default is 100.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    ################################################ header_interval ################################################
    set csr_map(2)  \
    "
    <register>
        <name>header_interval</name>
        <description>Interval between injections.</description>
        <addressOffset>0x8</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>header_interval</name>
                <description>(header_sync mode only) In number of headers. *Default is 1. 0 is in valid.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    ################################################ header_multiplicity ################################################
    set csr_map(3)  \
    "
    <register>
        <name>header_multiplicity</name>
        <description>Number of pulses in each injection.</description>
        <addressOffset>0xc</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>header_multiplicity</name>
                <description>(header_sync mode only) Numer of pulses. *Default is 1. 0 is in valid.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    ################################################ header_ch ################################################
    set csr_map(4)  \
    "
    <register>
        <name>header_ch</name>
        <description>Sync injection to this channel index for the given inputs of headerinfo interface.</description>
        <addressOffset>0x10</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>header_ch</name>
                <description>(header_sync mode only) Channel index</description>
                <bitRange>\[[expr ${headerinfo_channel_w}-1]:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    
    ################################################ pulse_interval ################################################
    set csr_map(5)  \
    "
    <register>
        <name>pulse_interval</name>
        <description>Interval between pulses.</description>
        <addressOffset>0x14</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>pulse_interval</name>
                <description>(periodic* modes only) In clock cycles.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    ################################################ pulse_high ################################################
    set csr_map(6)  \
    "
    <register>
        <name>pulse_high</name>
        <description>Pulse high duration.</description>
        <addressOffset>0x18</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>pulse_high</name>
                <description>(periodic* modes only) In clock cycles.</description>
                <bitRange>\[7:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    
    
    
    return [array get csr_map]
} 
    
    
    
    
    
    
    
    
    
    
    
    
    
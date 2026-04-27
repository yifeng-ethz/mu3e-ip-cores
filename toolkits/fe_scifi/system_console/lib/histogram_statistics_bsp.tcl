###########################################################################################################
# @Name 	    histogram_statistics_bsp.tcl
#
# @Brief		Board-Support-Package (BSP) of the Histogram Statistics IP core. 
#				Contains the address map info.
#
# @Functions	.
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Nov 5, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide histogram_statistics::bsp 	24.0

namespace eval ::histogram_statistics::bsp:: {
	namespace export \
    get_address_map \
    get_manual
    

}

proc ::histogram_statistics::bsp::get_address_map {} {

    array set csr_map {}
    ################################################ csr ################################################
    set csr_map(0)  \
    "
    <register>
        <name>csr</name>
        <description>CSR of Histogram Statistics IP</description>
        <addressOffset>0x0</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>commit</name>
                <description>(write) 1 = commit all the settings. (read) 0 = setting is completed</description>
                <bitRange>\[0:0\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>mode</name>
                <description>0 = normal; 1 = local 16-bit time packet delay (w/ aliasing); -1 = inferred 48-bit packet delay (w/o alising);-2~-5 = fill-level pdf; -6 = burstiness 2d scan (see code)</description>
                <bitRange>\[7:4\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>representation</name>
                <description>representation of update key (0x0 = signed (*default), 0x1 = unsigned)</description>
                <bitRange>\[8:8\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>filter</name>
                <description>bit\[0\]: '0' = disable; '1' = enable, bit\[1\]: '0' = accept; '1' = reject</description>
                <bitRange>\[13:12\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>error_flag</name>
                <description>0x0 is no error; 0x1 indicating an error</description>
                <bitRange>\[24:24\]</bitRange>
                <access>read-only</access>
            </field>
            <field>
                <name>error_info</name>
                <description>'0000' = no error; '0001' = key out-of-range</description>
                <bitRange>\[31:28\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "
    
     ################################################ left bound ################################################
    set csr_map(1)  \
    "
    <register>
        <name>left_bound</name>
        <description>left bound of the histogram</description>
        <addressOffset>0x4</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>left_bound</name>
                <description>left bound of the histogram bin 0 (signed)</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    ################################################ right bound ################################################
    set csr_map(2)  \
    "
    <register>
        <name>right_bound</name>
        <description>right bound of the histogram</description>
        <addressOffset>0x8</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>right_bound</name>
                <description>right bound of the histogram bin max (signed). you don't need to set this, as it will be automatically calculated based on left bound and bin width.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "

    ################################################ bin width ################################################
    set csr_map(3)  \
    "
    <register>
        <name>bin_width</name>
        <description>bin width of the histogram</description>
        <addressOffset>0xc</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>bin_width</name>
                <description>bin width of each bin. in case of conflict, the bin width will overdrive right bound. (unsigned)</description>
                <bitRange>\[15:0\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    
    ################################################ keys location ################################################
    set csr_map(4)  \
    "
    <register>
        <name>keys_location</name>
        <description>bit location of update and filter key, from the data stream</description>
        <addressOffset>0x10</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>update_key_low</name>
                <description>lsb bit location of the update key (unsigned)</description>
                <bitRange>\[7:0\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>update_key_high</name>
                <description>msb bit location of the update key (unsigned)</description>
                <bitRange>\[15:8\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>filter_key_low</name>
                <description>lsb bit location of the filter key (unsigned)</description>
                <bitRange>\[23:16\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>filter_key_high</name>
                <description>msb bit location of the filter key (unsigned)</description>
                <bitRange>\[31:24\]</bitRange>
                <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    
    
    ################################################ keys value ################################################
    set csr_map(5)  \
    "
    <register>
        <name>keys_value</name>
        <description>values of update and filter keys</description>
        <addressOffset>0x14</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>filter_key_value</name>
                <description>value of the filter key (unsigned/*signed)</description>
                <bitRange>\[31:16\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
                <name>update_key_value</name>
                <description>(NOT USED)value of the update key (unsigned/*signed)</description>
                <bitRange>\[15:0\]</bitRange>
                <access>read-write</access>
            </field>
            
            
        </fields>
    </register>
    "
    
    ################################################ underflow count ################################################
    set csr_map(6)  \
    "
    <register>
        <name>underflow_counter</name>
        <description>counter of the events that falls below the bin left bound</description>
        <addressOffset>0x18</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>underflow_cnt</name>
                <description>underflow counter value of the number of input event</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>

        </fields>
    </register>
    "
    
    ################################################ overflow count ################################################
    set csr_map(7)  \
    "
    <register>
        <name>overflow_counter</name>
        <description>counter of the events that falls above the bin right bound</description>
        <addressOffset>0x1c</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>overflow_cnt</name>
                <description>overflow counter value of the number of input event</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>

        </fields>
    </register>
    "
    
    return [array get csr_map]
} 


proc ::histogram_statistics::bsp::get_manual {} {
    array set man_page {}
    
    set man_page(Intro) \
    "
    <b> Histogram Statistics IP is an on-board pure-RTL histogram generator inside FPGA. <br> </b>
    <br>
    <ul>
        <li> As an intrumentation, this IP is used for debugging and run performace benchmark by collecting statistical information of any chosen data stream. </li>
        <li> It features dynamic/run-time user selection of <b>filling</b>, <b>filtering</b> key to grab from snooped data stream. </li>
        <li> Operation modes: 
            <ol>
                <li> <b>Normal</b>: snap the certain key and regard it as update key and/or filter key to fill the histogram. </li>
                <li> <b>Time-diff</b>: Use timestamp difference to fill the histogram. A measure for the life time of events locally at a system point. </li>
            </ol>
        </li>
    </ul>
    "
    
    set man_page(Format) \
    "
    <ul>
        <li> <b>hit_type_1</b>: 
            <ul>
                <li> asic    : \[38:35\] </li>
                <li> channel : \[34:30\] </li>
                <li> tcc8n   : \[29:17\] </li>
                <li> tcc1n6  : \[16:14\] </li>
                <li> tfine   : \[13:9\] </li>
                <li> et1n6   : \[8:0\] </li>
            </ul>
        </li>
    </ul>
    "
   
    
    return [array get man_page]
}









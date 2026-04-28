###########################################################################################################
# @Name 	    lvds_rx_bts.tcl
#
# @Brief		Board-Support-Package (BSP) of the LVDS RX Controller Pro IP core. 
#				Contains the address map info.
#
# @Functions	.
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Oct 23, 2024
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide lvds_rx::bsp 	24.0

namespace eval ::lvds_rx::bsp:: {
	namespace export \
    get_address_map \
    configure
    
    variable n_lane 
}

proc ::lvds_rx::bsp::configure {option value} {
    variable n_lane
    switch $option {
        "-n_lane" {
            set n_lane $value
        } default {
            error "option you entered (${option}) is not in the configure list"
        }
    }
    return -code ok
    
}


proc ::lvds_rx::bsp::get_address_map {} {
    variable n_lane
    array set csr_map {}
    set decoded_channel_width [expr {int(ceil(log($n_lane) / log(2)))}]
    if {$decoded_channel_width < 1} {
        set decoded_channel_width 1
    }
    set decoded_channel_msb [expr {$decoded_channel_width - 1}]
   ################################################ capa. ################################################
    set csr_map(0)  \
    "
    <register>
        <name>capability</name>
        <description>Capability of LVDS RX IP</description>
        <addressOffset>0x0</addressOffset>
        
        <resetMask>0x03ff0000</resetMask>
        <size>32</size>
        <fields>
            <field>
                <name>N_LANE</name>
                <description>number of rx lanes (pre-syn)</description>
                <bitRange>\[7:0\]</bitRange>
                <access>read-only</access>
            </field>
            <field>
              <name>sync_pattern</name>
              <description>sync pattern of the bit sliper</description>
              <bitRange>\[25:16\]</bitRange>
              <access>read-write</access>
            </field>
        </fields>
    </register>
    "
    
    
    
    ############################################### mode maske ###################################################
    set fieldText ""
    for {set i 0} {$i < $n_lane} {incr i} {
        set text \
       "    <field>
                <name>mode_masks_lane${i}</name>
                <description>select alignment mode of lane ${i}</description>
                <bitRange>\[${i}:${i}\]</bitRange>
                <access>read-write</access>
                <enumeratedValues>
                    <enumeratedValue>
                        <name>bit_slip</name>
                        <description>perform bit slip until sync pattern is regularly seen</description>
                        <value>0</value>
                    </enumeratedValue>
                    <enumeratedValue>
                        <name>adaptive_selection</name>
                        <description>use (-lvds_decoder_error) score to keep track of all boundary choices; the lane of highest score will be chosen.</description>
                        <value>1</value>
                    </enumeratedValue>
                </enumeratedValues>
            </field>
        "
        set fieldText ${fieldText}${text}
    }
    set csr_map(1)  \
    "
    <register>
        <name>mode_mask</name>
        <description>mode selection of byte boundary alignment</description>
        <addressOffset>0x4</addressOffset>
        
        <size>32</size>
        <fields>
        ${fieldText}</fields>
    </register>
    "
    
    
    
    ############################################# soft reset req #####################################################
    set fieldText ""
    for {set i 0} {$i < $n_lane} {incr i} {
        set text \
       "    <field>
                <name>soft_reset_req${i}</name>
                <description>request to soft reset lane ${i}</description>
                <bitRange>\[${i}:${i}\]</bitRange>
                <access>read-write</access>
                <modifiedWriteValues>oneToClear</modifiedWriteValues>
                <enumeratedValues>
                    <enumeratedValue>
                        <name>reset</name>
                        <description>request to soft reset this lane</description>
                        <value>1</value>
                    </enumeratedValue>
                    <enumeratedValue>
                        <name>do_not_reset</name>
                        <description>write: no effect; read: reset is done</description>
                        <value>0</value>
                    </enumeratedValue>
                </enumeratedValues>
            </field>
        "
        set fieldText ${fieldText}${text}
    }
    set csr_map(2) \
    "
    <register>
        <name>soft_reset_req</name>
        <description>request to soft reset the lanes</description>
        <addressOffset>0x8</addressOffset>
        
        <size>32</size>
        <fields>
        ${fieldText}</fields>
    </register>
    "
    
    
    ############################################ hold dpa #####################################################
    set fieldText ""
    for {set i 0} {$i < $n_lane} {incr i} {
        set text \
       "    <field>
                <name>dpa_hold${i}</name>
                <description>hold or unhold the phase training of the dpa block of lane ${i}</description>
                <bitRange>\[${i}:${i}\]</bitRange>
                <access>read-write</access>
                <enumeratedValues>
                    <enumeratedValue>
                        <name>hold</name>
                        <description>hold the dpa training (*special mode)</description>
                        <value>1</value>
                    </enumeratedValue>
                    <enumeratedValue>
                        <name>unhold</name>
                        <description>release the dpa training (default)</description>
                        <value>0</value>
                    </enumeratedValue>
                </enumeratedValues>
            </field>
        "
        set fieldText ${fieldText}${text}
    }
    
    set csr_map(3) \
    "
    <register>
        <name>dpa_hold</name>
        <description>hold or unhold the phase training of the dpa block</description>
        <addressOffset>0xc</addressOffset>
        <size>32</size>
        <fields>
        ${fieldText}</fields>    
    </register>
    "
    
    
    ########################################### lane_go #####################################################
    set fieldText ""
    for {set i 0} {$i < $n_lane} {incr i} {
        set text \
       "    <field>
                <name>lane_go${i}</name>
                <description>allow lane ${i} to train dpa or block output data</description>
                <bitRange>\[${i}:${i}\]</bitRange>
                <access>read-write</access>
                <enumeratedValues>
                    <enumeratedValue>
                        <name>go</name>
                        <description>enable the dpa training block to perform traning sequence (default)</description>
                        <value>1</value>
                    </enumeratedValue>
                    <enumeratedValue>
                        <name>stop</name>
                        <description>stop the dpa traning block; thus, the data output will be blocked</description>
                        <value>0</value>
                    </enumeratedValue>
                </enumeratedValues>
            </field>
        "
        set fieldText ${fieldText}${text}
    }
    set csr_map(4) \
    "
    <register>
        <name>lane_go</name>
        <description>allow the lane to train dpa or block output data</description>
        <addressOffset>0x10</addressOffset>
        <size>32</size>
        <fields>
        ${fieldText}</fields>    
    </register>
    "
    

    ################################################# lvds error ################################################
    for {set i 0} {$i < $n_lane} {incr i} {
        set addressOfst [format 0x%x [expr 0x14 + ${i}*4]]
        set csr_map([expr 5+$i]) \
        "
        <register>
            <name>error_counter_lane${i}</name>
            <description>lvds error (decode + parity) counter of lane ${i}</description>
            <addressOffset>${addressOfst}</addressOffset>
            
            <size>32</size>
            <fields>
                <field>
                    <name>error counts</name>
                    <dataType>uint32_t</dataType>
                    <bitRange>\[31:0\]</bitRange>
                    <access>read-only</access>
                </field>
            </fields>
        </register>
        "
    }

    ############################################# debug lane selection #############################################
    set addressOfst [format 0x%x [expr 0x14 + ${n_lane}*4]]
    set csr_map([expr 5+$n_lane]) \
    "
    <register>
        <name>lane_selection</name>
        <description>lane selector for the port-mapped LVDS debug registers</description>
        <addressOffset>${addressOfst}</addressOffset>

        <size>32</size>
        <fields>
            <field>
                <name>lane_selection</name>
                <description>selected lane index for lane_dpa_unlocks and, when addressable, lane_word_aligner_chosen</description>
                <bitRange>\[${decoded_channel_msb}:0\]</bitRange>
                <access>read-write</access>
            </field>
        </fields>
    </register>
    "

    ############################################# selected-lane dpa unlock counter #############################################
    set addressOfst [format 0x%x [expr 0x18 + ${n_lane}*4]]
    set csr_map([expr 6+$n_lane]) \
    "
    <register>
        <name>lane_dpa_unlocks</name>
        <description>DPA unlock counter of the lane selected by lane_selection</description>
        <addressOffset>${addressOfst}</addressOffset>

        <size>32</size>
        <fields>
            <field>
                <name>dpa_unlocks</name>
                <dataType>uint32_t</dataType>
                <description>DPA unlock counter of the selected lane</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    # The RTL also decodes word N_LANE+7 as lane_word_aligner_chosen. The
    # current 9-lane package uses AVMM_ADDR_W=4, so offset 0x40 is not
    # addressable in the live FE SciFi systems. Keep it out of this BSP unless
    # the package/system address width is widened.
    if {[expr {$n_lane + 7}] < 16} {
        set addressOfst [format 0x%x [expr 0x1c + ${n_lane}*4]]
        set csr_map([expr 7+$n_lane]) \
        "
        <register>
            <name>lane_word_aligner_chosen</name>
            <description>word-aligner choice mask of the lane selected by lane_selection</description>
            <addressOffset>${addressOfst}</addressOffset>

            <size>32</size>
            <fields>
                <field>
                    <name>chosen_mask</name>
                    <description>10-bit one-hot word-aligner choice mask for the selected lane</description>
                    <bitRange>\[9:0\]</bitRange>
                    <access>read-only</access>
                </field>
            </fields>
        </register>
        "
    }
    
    
    
    #puts [array names csr_map]
    
    #parray csr_map
    return [array get csr_map]
}

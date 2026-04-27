###########################################################################################################
# @Name 	    mts_processor_bsp.tcl
#
# @Brief		Board-Support-Package (BSP) of the MuTRiG Timestamp Processor IP core. 
#				Contains the address map info.
#
# @Functions	.
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Jan 24, 2025
# @Version		1.0 (file created)
#				
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide mts_processor::bsp 	24.0

namespace eval ::mts_processor::bsp:: {
	namespace export \
    get_address_map \
    configure
    
    
}

proc ::mts_processor::bsp::get_address_map {} {
    array set csr_map {}
    ################################################ csr ################################################
    set csr_map(0)  \
    "
    <register>
        <name>control_and_status</name>
        <description>Control and status registers of MuTRiG Timestamp Processor IP</description>
        <addressOffset>0x0</addressOffset>
        <size>32</size>
        <fields>
        
            <field>
                <name>go</name>
                <description>allow to generate new hits during RUNNING run state</description>
                <bitRange>\[0:0\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
              <name>force_stop</name>
              <description>force to stop the datapath processing output in any run state</description>
              <bitRange>\[1:1\]</bitRange>
              <access>read-write</access>
            </field>
            <field>
              <name>soft_reset</name>
              <description>soft reset this IP, including counters and in-processing hits</description>
              <bitRange>\[2:2\]</bitRange>
              <access>read-write</access>
            </field>
            <field>
              <name>bypass_lapse</name>
              <description>disable the lapse (leap) correction between mts and gts. debug to see the raw coarse counter distribution. </description>
              <bitRange>\[3:3\]</bitRange>
              <access>read-write</access>
            </field>
            <field>
              <name>discard_hiterr</name>
              <description>disable input error check of 'hiterr' error signal</description>
              <bitRange>\[4:4\]</bitRange>
              <access>read-write</access>
            </field>
            <field>
              <name>op_mode</name>
              <description>
                3-bit of op mode: 
                \[2\] derive tot : 1=long, 0=short (def). Decode E branch and validate E-BadHit. Output format go to type1b.
                \[1\] delay ts field : 1=use T (def), 0=use E. Calc delay using T or E timestamp. Used when hit tuple has different meanings.
                \[0\] reserved : not used currently.
              </description>
              <bitRange>\[30:28\]</bitRange>
              <access>read-write</access>
            </field>
            
        </fields>
    </register>
    "
    
    ################################################ discard hit counter ################################################
    set csr_map(1)  \
    "
    <register>
        <name>discard_hit_counter</name>
        <description>Counter of discarded hit at the input due to 'hiterr'</description>
        <addressOffset>0x4</addressOffset>
        <size>32</size>
        <fields>
            
            <field>
              <name>discard_hit_count</name>
              <description>number of discarded hit</description>
              <bitRange>\[31:0\]</bitRange>
              <access>read-only</access>
            </field>
        
        </fields>
    </register>
    "
    
    ################################################ expected latency ################################################
    set csr_map(2)  \
    "
    <register>
        <name>expected_latency_8ns</name>
        <description>Expected mutrig buffering latency in 8ns</description>
        <addressOffset>0x8</addressOffset>
        <size>32</size>
        <fields>
            
            <field>
              <name>expected_latency</name>
              <description>expected latency of the hit (default=2000). adjust for long hit mode or link saturation is expected. </description>
              <bitRange>\[31:0\]</bitRange>
              <access>read-write</access>
            </field>
        
        </fields>
    </register>
    "
    
    ################################################ total hit cnt (high) ################################################
    set csr_map(3)  \
    "
    <register>
        <name>total_hit_cnt_hi</name>
        <description>Counter of total number of hits at ingress port (upper 16 bits)</description>
        <addressOffset>0xc</addressOffset>
        <size>32</size>
        <fields>
            
            <field>
              <name>total_hit_cnt_hi</name>
              <description>Total number of hits, taken at ingress port during running, incl. error hits. If zero, means stalled by run state or really no hits from upstream, i.e., MuTRiG Frame Deassembly.  </description>
              <bitRange>\[15:0\]</bitRange>
              <access>read-only</access>
            </field>
        
        </fields>
    </register>
    "
    
    ################################################ total hit cnt (low) ################################################
    set csr_map(4)  \
    "
    <register>
        <name>total_hit_cnt_lo</name>
        <description>Counter of total number of hits at ingress port (lower 32 bits)</description>
        <addressOffset>0x10</addressOffset>
        <size>32</size>
        <fields>
            
            <field>
              <name>total_hit_cnt_lo</name>
              <description>Total number of hits, taken at ingress port during running, incl. error hits. If zero, means stalled by run state or really no hits from upstream, i.e., MuTRiG Frame Deassembly.  </description>
              <bitRange>\[31:0\]</bitRange>
              <access>read-only</access>
            </field>
        
        </fields>
    </register>
    "
    
    return [array get csr_map]
    
}



















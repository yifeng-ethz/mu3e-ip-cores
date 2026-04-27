###########################################################################################################
# @Name 	    ring_buffer_cam_bsp.tcl
#
# @Brief		Board-Support-Package (BSP) of the Ring-Buffer CAM IP core.
#				Contains the address map info.
#
# @Functions	.
#
# @Author		Yifeng Wang (yifenwan@phys.ethz.ch)
# @Date			Mar 24, 2025
# @Version		1.0 (file created)
#				2.0 (Apr 2026) Aligned to _hw.tcl 26.1: added UID and META header
#				    registers, corrected byte offsets for all subsequent words,
#				    added overwrite and cache-miss counters, META pages use
#				    writeBeforeRead for selector side-effect.
#
###########################################################################################################
package require Tcl 			8.5
############## match the version of the IP #######################
package provide ring_buffer_cam::bsp 	26.1

namespace eval ::ring_buffer_cam::bsp:: {
	namespace export \
    get_address_map \
    configure
}

proc ::ring_buffer_cam::bsp::get_address_map {} {
    array set csr_map {}
    ################################################ uid ################################################
    set csr_map(0)  \
    "
    <register>
        <name>uid</name>
        <description>Software-visible IP identifier. Default payload is ASCII RBCM (0x5242434D) but is integration-time overridable.</description>
        <addressOffset>0x0</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>uid</name>
                <description>Compile-time / integration-time overridable IP identifier.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ meta : version (selector=0) ###########################
    set csr_map(1)  \
    "
    <register>
        <name>meta_version</name>
        <description>Read-multiplexed metadata word (page 0). MAJOR\[31:24\], MINOR\[23:16\], PATCH\[15:12\], BUILD\[11:0\].</description>
        <addressOffset>0x4</addressOffset>
        <writeBeforeRead>0x0</writeBeforeRead>
        <size>32</size>
        <fields>
            <field>
                <name>version</name>
                <description>Packed version word: MAJOR\[31:24\], MINOR\[23:16\], PATCH\[15:12\], BUILD\[11:0\]. Write 0 to select this page before reading.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ meta : date (selector=1) ##############################
    set csr_map(2)  \
    "
    <register>
        <name>meta_date</name>
        <description>Read-multiplexed metadata word (page 1). YYYYMMDD provenance date.</description>
        <addressOffset>0x4</addressOffset>
        <writeBeforeRead>0x1</writeBeforeRead>
        <size>32</size>
        <fields>
            <field>
                <name>date</name>
                <description>YYYYMMDD build-provenance date word. Write 1 to select this page before reading.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ meta : git (selector=2) ###############################
    set csr_map(3)  \
    "
    <register>
        <name>meta_git</name>
        <description>Read-multiplexed metadata word (page 2). Truncated build git hash.</description>
        <addressOffset>0x4</addressOffset>
        <writeBeforeRead>0x2</writeBeforeRead>
        <size>32</size>
        <fields>
            <field>
                <name>git</name>
                <description>Truncated build git hash. Write 2 to select this page before reading.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ meta : instance_id (selector=3) #######################
    set csr_map(4)  \
    "
    <register>
        <name>meta_instance_id</name>
        <description>Read-multiplexed metadata word (page 3). Integrator-defined instance identifier.</description>
        <addressOffset>0x4</addressOffset>
        <writeBeforeRead>0x3</writeBeforeRead>
        <size>32</size>
        <fields>
            <field>
                <name>instance_id</name>
                <description>Integrator-defined instance identifier. Write 3 to select this page before reading.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ control and status ####################################
    set csr_map(5)  \
    "
    <register>
        <name>control_and_status</name>
        <description>Control and status registers of Ring-Buffer CAM IP.</description>
        <addressOffset>0x8</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>go</name>
                <description>Allow to accept hits.</description>
                <bitRange>\[0:0\]</bitRange>
                <access>read-write</access>
            </field>
            <field>
              <name>soft_reset</name>
              <description>Running reset request for the ring-buffer CAM.</description>
              <bitRange>\[1:1\]</bitRange>
              <access>read-write</access>
            </field>
            <field>
              <name>filter_inerr</name>
              <description>Filter the ingress error hits with 'tserr'.</description>
              <bitRange>\[4:4\]</bitRange>
              <access>read-write</access>
            </field>
        </fields>
    </register>
    "

    ################################################ latency #######################################
    set csr_map(6)  \
    "
    <register>
        <name>Latency</name>
        <description>Read-pointer delay target in cycles. Reset default is 2000.</description>
        <addressOffset>0xc</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>expected_latency</name>
                <description>Expected latency value to set in unit of cycles (8 ns). ex: read clock = gts - latency.</description>
                <bitRange>\[15:0\]</bitRange>
                <access>read-write</access>
            </field>
        </fields>
    </register>
    "

    ################################################ fill level #######################################
    set csr_map(7)  \
    "
    <register>
        <name>Fill_level_meter</name>
        <description>Live fill-level estimate derived from push, pop, and overwrite counters.</description>
        <addressOffset>0x10</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>fill_level</name>
                <description>Fill-level counter of current hits inside.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ in-error count #######################################
    set csr_map(8)  \
    "
    <register>
        <name>In-error count</name>
        <description>Count of filtered ingress timestamp-error hits.</description>
        <addressOffset>0x14</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>inerr_count</name>
                <description>Counter of error='tserr' hits.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ push count #######################################
    set csr_map(9)  \
    "
    <register>
        <name>push count</name>
        <description>Total accepted push operations.</description>
        <addressOffset>0x18</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>push_count</name>
                <description>Counter of push-in hits.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ pop count #######################################
    set csr_map(10)  \
    "
    <register>
        <name>pop count</name>
        <description>Total drained hits.</description>
        <addressOffset>0x1c</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>pop_count</name>
                <description>Counter of pop-out hits.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ overwrite count #######################################
    set csr_map(11)  \
    "
    <register>
        <name>overwrite count</name>
        <description>Total overwrite events.</description>
        <addressOffset>0x20</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>overwrite_count</name>
                <description>Counter of overwritten hits.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    ################################################ cache miss count #######################################
    set csr_map(12)  \
    "
    <register>
        <name>cache-miss count</name>
        <description>Total cache-miss / empty-search events.</description>
        <addressOffset>0x24</addressOffset>
        <size>32</size>
        <fields>
            <field>
                <name>cache_miss_count</name>
                <description>Counter of cache-missed hits.</description>
                <bitRange>\[31:0\]</bitRange>
                <access>read-only</access>
            </field>
        </fields>
    </register>
    "

    return [array get csr_map]
}

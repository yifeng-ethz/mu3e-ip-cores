# max10_prog_avmm.sdc
#
# CDC timing intent for the local launch queue between:
# - csr_clock domain (write side)
# - link_clock domain (read side)
#
# This file intentionally constrains only the dedicated queue FIFO used by
# max10_prog_avmm. The generated system-level Qsys FIFOs contribute their own
# vendor SDC files separately.
#
# Important:
# 1. Do not globally false-path csr_clock and link_clock for this IP.
# 2. These constraints are conditional and silently skip if the expected
#    primitive register names are not present in the netlist.

proc m10p_apply_delay_pair {from_nodes to_nodes} {
    if {[llength $from_nodes] > 0 && [llength $to_nodes] > 0} {
        set_max_delay -from $from_nodes -to $to_nodes 100
        set_min_delay -from $from_nodes -to $to_nodes -100
    }
}

proc m10p_apply_net_delay_pair {from_nodes to_nodes} {
    if {[llength $from_nodes] > 0 && [llength $to_nodes] > 0} {
        set_net_delay -max 2 -from $from_nodes -to $to_nodes
        set_net_delay -min 0 -from $from_nodes -to $to_nodes
    }
}

proc constrain_m10p_queue_fifo {} {
    set wr_gray_regs [get_registers -nowarn *|max10_prog_avmm:*|queue_fifo*|in_wr_ptr_gray[*]]
    set wr_sync_regs [get_registers -nowarn *|max10_prog_avmm:*|queue_fifo*|*write_crosser*|*din_s1]
    set rd_gray_regs [get_registers -nowarn *|max10_prog_avmm:*|queue_fifo*|out_rd_ptr_gray[*]]
    set rd_sync_regs [get_registers -nowarn *|max10_prog_avmm:*|queue_fifo*|*read_crosser*|*din_s1]

    m10p_apply_delay_pair     $wr_gray_regs $wr_sync_regs
    m10p_apply_delay_pair     $rd_gray_regs $rd_sync_regs
    m10p_apply_net_delay_pair $wr_gray_regs $wr_sync_regs
    m10p_apply_net_delay_pair $rd_gray_regs $rd_sync_regs

    set mem_regs      [get_registers -nowarn *|max10_prog_avmm:*|queue_fifo*|mem*]
    set payload_regs  [get_registers -nowarn *|max10_prog_avmm:*|queue_fifo*|internal_out_payload*]
    if {[llength $mem_regs] > 0 && [llength $payload_regs] > 0} {
        set_net_delay -max 2 -from $mem_regs -to $payload_regs
        set_net_delay -min 0 -from $mem_regs -to $payload_regs
    }
}

constrain_m10p_queue_fifo

# ---------------------------------------------------------------------------
# CDC false paths between csr_clock and link_clock domains.
#
# The link-domain registers (link.err_flags, link.err_code, link.max10_stat,
# link.max10_count, link.boot_*) are sampled in the csr_clock domain only
# after the done_toggle handshake synchroniser detects an edge.  These paths
# are therefore safe -- the data is stable for many cycles before the
# synchronised toggle is sampled.
#
# Similarly, csr.launch_toggle is sampled in the link_clock domain through a
# 3-stage synchroniser (link.launch_toggle_sync).
#
# The DCFIFO aclr input is constructed from ORed resets across both domains;
# the DCFIFO's internal read_aclr_synch / write_aclr_synch handle the CDC.
# ---------------------------------------------------------------------------
proc constrain_m10p_cdc_false_paths {} {
    # -- Broad CDC false paths: link.* <-> csr.* within max10_prog_avmm --
    # All inter-domain data/control transfers use toggle-handshake
    # synchronisers (3-stage chains). Data is stable for many cycles
    # before the synchronised toggle edge is sampled. Safe to false-path
    # all combinational paths between the two record domains.
    set link_all [get_registers -nowarn *|max10_prog_avmm:*|link.*]
    set csr_all  [get_registers -nowarn *|max10_prog_avmm:*|csr.*]
    if {[llength $link_all] > 0 && [llength $csr_all] > 0} {
        set_false_path -from $link_all -to $csr_all
        set_false_path -from $csr_all  -to $link_all
    }

    # -- DCFIFO aclr: the DCFIFO's read_aclr_synch and write_aclr_synch
    #    handle the asynchronous clear internally.  False-path all reset
    #    sources feeding the ORed aclr net to suppress recovery/removal
    #    violations reported across domains. --
    # Use -to with the actual DCFIFO internal register hierarchy.
    # The dcfifo megafunction generates dffpipe_3dc:wraclr and
    # dffpipe_3dc:rdaclr for the async clear synchronisation.
    set dcfifo_aclr_int [get_registers -nowarn {*max10_prog_avmm*queue_fifo*aclr*}]
    if {[get_collection_size $dcfifo_aclr_int] > 0} {
        set_false_path -to $dcfifo_aclr_int
    }
}

constrain_m10p_cdc_false_paths

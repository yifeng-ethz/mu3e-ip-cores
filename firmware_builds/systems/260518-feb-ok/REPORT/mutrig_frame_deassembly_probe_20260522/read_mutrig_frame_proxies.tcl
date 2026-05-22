set script_dir "."
if {[info exists ::env(BOARD_TEST_SCRIPT_DIR)] && $::env(BOARD_TEST_SCRIPT_DIR) ne ""} {
    set script_dir $::env(BOARD_TEST_SCRIPT_DIR)
} elseif {[info script] ne ""} {
    set script_dir [file dirname [file normalize [info script]]]
}
source [file join $script_dir headless_jtag_common.tcl]

proc emit_block_header {block base count} {
    puts [format "PROXY_BLOCK block=%s base=0x%08X count=%u" $block $base $count]
}

proc emit_word {block index addr value name desc} {
    puts [format "PROXY_WORD block=%s index=%u addr=0x%08X value=0x%08X name=%s desc={%s}" \
        $block $index $addr [expr {$value & 0xFFFFFFFF}] $name $desc]
}

proc read_block {svc block base names descs} {
    set count [llength $names]
    emit_block_header $block $base $count
    set words [master_read_32 $svc $base $count]
    for {set idx 0} {$idx < $count} {incr idx} {
        set word_addr [expr {$base + 4 * $idx}]
        emit_word $block $idx $word_addr [lindex $words $idx] [lindex $names $idx] [lindex $descs $idx]
    }
}

set lvds_names {
    UID META CAPABILITY SYNC_PATTERN LANE_GO DPA_HOLD SOFT_RESET MODE_MASK
    SCORE_ACCEPT SCORE_REJECT STEER_STATUS PHY_STATUS PHY_LOSN_STATUS
    PHY_LOS_ALERT PHY_DPALOCK_STATUS PHY_FIFORST_STATUS LANE_SELECT
    CODE_VIOLATIONS DISP_VIOLATIONS COMMA_LOSSES BITSLIP_EVENTS
    DPA_UNLOCKS REALIGNS SCORE_CHANGES ENGINE_STEER SOFT_RESETS UPTIME
    LANE_TRAIN_STATUS
}
set lvds_descs {
    {LVDS controller UID, expected ASCII LVDS}
    {Read-multiplexed LVDS metadata page}
    {Compiled lane, engine, score, and routing capability}
    {10-bit synchronization symbol accepted by lane alignment}
    {Per-lane enable mask}
    {Per-lane DPA hold mask}
    {Per-lane soft reset request latch}
    {Global lane mode, bits 1:0 currently consumed}
    {Engine steering accept threshold}
    {Engine steering reject threshold}
    {Steering queue count and overflow low bits}
    {PLL lock plus aggregate LOS, DPA unlock, FIFO reset, and DPA reset flags}
    {Per-lane redriver LOS_N status, bit=1 means signal present}
    {Sticky per-lane LOS alert, write-one-to-clear}
    {Per-lane DPA lock status}
    {Per-lane controller FIFO reset output toward the PHY}
    {Selected lane for the counter snapshot window}
    {Selected-lane illegal or unexpected 8b/10b symbol events}
    {Selected-lane disparity violation events}
    {Selected-lane comma or sync-pattern loss events}
    {Selected-lane bitslip control events}
    {Selected-lane DPA unlock events}
    {Selected-lane realignment events}
    {Selected-lane engine-score change events}
    {Selected-lane engine steering decisions}
    {Selected-lane soft-reset completions}
    {Selected-lane uptime counter in data-clock cycles}
    {Selected-lane training-state snapshot}
}

set hist_names {
    UID META CONTROL LEFT_BOUND RIGHT_BOUND BIN_WIDTH KEY_LOC KEY_VALUE
    UNDERFLOW_COUNT OVERFLOW_COUNT INTERVAL_CFG BANK_STATUS PORT_STATUS
    TOTAL_HITS DROPPED_HITS COAL_STATUS SCRATCH LAST_INTERVAL_TOTAL_HITS
    LAST_INTERVAL_DROPPED_HITS
}
set hist_descs {
    {Histogram UID, expected ASCII HIST}
    {Read-multiplexed histogram metadata page}
    {Apply, source port, mode, key interpretation, filter control, and validation status}
    {Signed left histogram boundary}
    {Signed right histogram boundary}
    {Bin width in key-space units}
    {Packed bit-slice locations for update and filter keys}
    {Packed runtime key overrides}
    {Keys below configured range}
    {Keys above configured range}
    {Ping-pong interval timer configuration}
    {Active bank and flush-progress status}
    {Ingress FIFO empty mask and maximum observed fill level}
    {Live accepted-hit count in the current interval}
    {Live dropped-hit count caused by FIFO or queue overflow}
    {Coalescing queue occupancy, maximum occupancy, and overflow count}
    {General-purpose scratch register}
    {Accepted-hit count latched at most recent interval pulse}
    {Dropped-hit count latched at most recent interval pulse}
}

set bp_names {WORD000 WORD001 WORD002 WORD003}
set bp_descs {
    {Raw backpressure FIFO CSR word 0}
    {Raw backpressure FIFO CSR word 1}
    {Raw backpressure FIFO CSR word 2}
    {Raw backpressure FIFO CSR word 3}
}

set injector_names {
    UID META MODE HEADER_DELAY HEADER_INTERVAL INJECTION_MULTIPLICITY
    HEADER_CH PULSE_INTERVAL PULSE_HIGH_CYCLES PRBS_RATE PRBS_PATTERN
    PRBS_SEED PRBS_CTRL RESERVED13 RESERVED14 RESERVED15
}
set injector_descs {
    {Injector UID, expected ASCII MINJ}
    {Read-multiplexed injector metadata page}
    {Injection mode selector, 0=off, 1=header synchronous, 2/3=periodic, 4=one-click, 5=PRBS}
    {Main-clock delay from selected header match to first header-synchronous pulse}
    {Number of selected header matches between mode-1 bursts}
    {Number of pulses per header-triggered or PRBS-triggered burst}
    {Selected headerinfo channel compared against all eight headerinfo sidebands}
    {Mode-2 interval in main-clock cycles}
    {Pulse high duration, low byte consumed by RTL}
    {Main-clock cycles between PRBS state advances in mode 5}
    {Pattern compared against selected low PRBS bits}
    {Seed used when entering or reseeding PRBS mode}
    {PRBS polynomial and match-width selector}
    {Reserved decoded word, current RTL returns zero}
    {Reserved decoded word, current RTL returns zero}
    {Reserved decoded word, current RTL returns zero}
}

set claim [::board_test::jtag::claim_matching_master "*#7-2*/phy_1/master" "" "" "" "mutrig_frame_proxy"]
set svc [dict get $claim service]
set master_path [dict get $claim path]
puts "PROXY_MASTER path={$master_path}"

if {[catch {
    read_block $svc LVDS_GLOBAL 0x00000000 $lvds_names $lvds_descs
    read_block $svc BP_LANE0 0x00008860 $bp_names $bp_descs
    read_block $svc BP_LANE1 0x00001860 $bp_names $bp_descs
    read_block $svc BP_LANE2 0x00002860 $bp_names $bp_descs
    read_block $svc BP_LANE3 0x00003860 $bp_names $bp_descs
    read_block $svc BP_LANE4 0x00004860 $bp_names $bp_descs
    read_block $svc BP_LANE5 0x00005860 $bp_names $bp_descs
    read_block $svc BP_LANE6 0x00006860 $bp_names $bp_descs
    read_block $svc BP_LANE7 0x00007860 $bp_names $bp_descs
    read_block $svc HISTOGRAM 0x00007000 $hist_names $hist_descs
    read_block $svc MUTRIG_INJECTOR 0x0000A000 $injector_names $injector_descs
} err]} {
    ::board_test::jtag::close_claim $svc
    ::board_test::jtag::fatal 2 ERROR $err
}

::board_test::jtag::close_claim $svc
::board_test::jtag::puts_result "PROXY_RESULT" [list status OK master "{$master_path}"]

package require -exact qsys 16.1

set VERSION_MAJOR_DEFAULT_CONST  26
set VERSION_MINOR_DEFAULT_CONST  1
set VERSION_PATCH_DEFAULT_CONST  8
set BUILD_DEFAULT_CONST          502
set VERSION_DATE_DEFAULT_CONST   20260502
set VERSION_GIT_DEFAULT_CONST    72231161
set VERSION_STRING_DEFAULT_CONST [format "%d.%d.%d.%04d" \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]
set VERSION_GIT_HEX_DEFAULT_CONST [format "0x%08X" $VERSION_GIT_DEFAULT_CONST]

set_module_property NAME histogram_statistics_v2
set_module_property DISPLAY_NAME "Full8lane Histogram Statistics Compatibility"
set_module_property VERSION $VERSION_STRING_DEFAULT_CONST
set_module_property DESCRIPTION "Full8lane-build compatibility wrapper for histogram_statistics_v2 with Qsys-18.1-safe boolean generics."
set_module_property GROUP "Mu3e Full8Lane Build/Wrappers"
set_module_property AUTHOR "Yifeng Wang"
set_module_property ICON_PATH ../../../../../../firmware_builds/misc/logo/mu3e_logo.png
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property ELABORATION_CALLBACK elaborate
set_module_property VALIDATION_CALLBACK validate

# --- helper procs ----------------------------------------------------------------

proc add_html_text {group_name item_name html_text} {
    add_display_item $group_name $item_name TEXT ""
    set_display_item_property $item_name DISPLAY_HINT html
    set_display_item_property $item_name TEXT $html_text
}

proc bool_param {name} {
    return [expr {[string equal -nocase [get_parameter_value $name] "true"] ? 1 : 0}]
}

proc ceil_log2 {value} {
    if {$value <= 1} {
        return 0
    }

    set result 0
    set probe 1
    while {$probe < $value} {
        set probe [expr {$probe << 1}]
        incr result
    }
    return $result
}

proc set_optional_stream {ifname enable data_w ch_w} {
    set_interface_property $ifname ENABLED [expr {$enable ? "true" : "false"}]
    if {$enable} {
        set_interface_property $ifname dataBitsPerSymbol $data_w
        set_interface_property $ifname maxChannel [expr {(1 << $ch_w) - 1}]
    }
}

# --- constants --------------------------------------------------------------------

set CSR_ADDR_W_CONST        5
set RUN_CONTROL_WIDTH_CONST 9
set IP_UID_DEFAULT_CONST    1212765012
set INSTANCE_ID_DEFAULT_CONST 0

# --- CSR register map (documentation) ---------------------------------------------

set CSR_TABLE_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Word</th><th>Byte</th><th>Name</th><th>Access</th><th>Description</th></tr>
<tr><td>0x00</td><td>0x000</td><td>UID</td><td>RO</td><td>Software-visible IP identifier. Default ASCII <b>HIST</b> (0x48495354).</td></tr>
<tr><td>0x01</td><td>0x004</td><td>META</td><td>RW/RO</td><td>Read-multiplexed metadata word. Write <b>0</b>=VERSION, <b>1</b>=DATE, <b>2</b>=GIT, <b>3</b>=INSTANCE_ID.</td></tr>
<tr><td>0x02</td><td>0x008</td><td>CONTROL</td><td>RW/RO</td><td>Bit 0 <b>apply</b>, bit 1 <b>apply_pending</b> (RO), bits [7:4] <b>mode</b>, bit 8 <b>key_unsigned</b>, bit 12 <b>filter_enable</b>, bit 13 <b>filter_reject</b>, bit 24 <b>error</b> (RO), bits [31:28] <b>error_info</b> (RO).</td></tr>
<tr><td>0x03</td><td>0x00C</td><td>LEFT_BOUND</td><td>RW</td><td>Signed left boundary of the histogram range.</td></tr>
<tr><td>0x04</td><td>0x010</td><td>RIGHT_BOUND</td><td>RW</td><td>Signed right boundary of the histogram range. Recomputed at apply time when <b>BIN_WIDTH != 0</b>.</td></tr>
<tr><td>0x05</td><td>0x014</td><td>BIN_WIDTH</td><td>RW</td><td>Bin width in key-space units, stored in bits [15:0]. Set to 0 to keep explicit left/right bounds.</td></tr>
<tr><td>0x06</td><td>0x018</td><td>KEY_LOC</td><td>RW</td><td>Packed bit-slice locations: [31:24] filter_key_high, [23:16] filter_key_low, [15:8] update_key_high, [7:0] update_key_low.</td></tr>
<tr><td>0x07</td><td>0x01C</td><td>KEY_VALUE</td><td>RW</td><td>Packed runtime key overrides: [31:16] filter_key, [15:0] update_key.</td></tr>
<tr><td>0x08</td><td>0x020</td><td>UNDERFLOW_COUNT</td><td>RO</td><td>Count of keys mapped below the configured range.</td></tr>
<tr><td>0x09</td><td>0x024</td><td>OVERFLOW_COUNT</td><td>RO</td><td>Count of keys mapped above the configured range.</td></tr>
<tr><td>0x0A</td><td>0x028</td><td>INTERVAL_CFG</td><td>RW</td><td>Ping-pong interval timer configuration in clock cycles.</td></tr>
<tr><td>0x0B</td><td>0x02C</td><td>BANK_STATUS</td><td>RO</td><td>Ping-pong bank-selection and flush-progress status.</td></tr>
<tr><td>0x0C</td><td>0x030</td><td>PORT_STATUS</td><td>RO</td><td>Ingress FIFO empty-mask and maximum observed fill level.</td></tr>
<tr><td>0x0D</td><td>0x034</td><td>TOTAL_HITS</td><td>RO</td><td>Live accepted hit count in the current interval. Resets at manual clear and at every interval pulse.</td></tr>
<tr><td>0x0E</td><td>0x038</td><td>DROPPED_HITS</td><td>RO</td><td>Live dropped-hit count caused by FIFO or queue overflow in the current interval. Resets at manual clear and at every interval pulse.</td></tr>
<tr><td>0x0F</td><td>0x03C</td><td>COAL_STATUS</td><td>RO</td><td>Coalescing-queue occupancy, occupancy max, and overflow count.</td></tr>
<tr><td>0x10</td><td>0x040</td><td>SCRATCH</td><td>RW</td><td>General-purpose scratch register for integration testing.</td></tr>
<tr><td>0x11</td><td>0x044</td><td>LAST_INTERVAL_TOTAL_HITS</td><td>RO</td><td>Accepted-hit count latched at the most recent interval pulse before the live counter reset.</td></tr>
<tr><td>0x12</td><td>0x048</td><td>LAST_INTERVAL_DROPPED_HITS</td><td>RO</td><td>Dropped-hit count latched at the most recent interval pulse before the live counter reset.</td></tr>
</table></html>}

set META_FIELDS_HTML [format {<html><table border="1" cellpadding="3" width="100%%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>1:0</td><td>meta_sel</td><td>RW</td><td>0</td><td>Selects the META read page: 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.</td></tr>
<tr><td>31:2</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero on writeback of the selector word.</td></tr>
</table><br/>
<b>VERSION page layout</b><br/>
<table border="1" cellpadding="3" width="100%%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>31:24</td><td>major</td><td>RO</td><td>%d</td><td>Release major, aligned to the packaging year.</td></tr>
<tr><td>23:16</td><td>minor</td><td>RO</td><td>%d</td><td>Feature revision within the release year.</td></tr>
<tr><td>15:12</td><td>patch</td><td>RO</td><td>%d</td><td>Patch revision.</td></tr>
<tr><td>11:0</td><td>build</td><td>RO</td><td>%d</td><td>Build stamp packed as MMDD.</td></tr>
</table></html>} \
    $VERSION_MAJOR_DEFAULT_CONST \
    $VERSION_MINOR_DEFAULT_CONST \
    $VERSION_PATCH_DEFAULT_CONST \
    $BUILD_DEFAULT_CONST]

set CONTROL_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>0</td><td>apply</td><td>RW</td><td>0</td><td>Write 1 to request that the staged configuration becomes active after the ingress path drains.</td></tr>
<tr><td>1</td><td>apply_pending</td><td>RO</td><td>0</td><td>1 while a committed configuration is waiting to settle into the live datapath.</td></tr>
<tr><td>3:2</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
<tr><td>7:4</td><td>mode</td><td>RW</td><td>0</td><td>Mode selector. Negative 4-bit signed values route debug inputs into the histogram path. Modes -1..-6 select debug_1..debug_6 individually; mode -7 samples signed MTS-delay streams on debug_1 and debug_2 together. In debug modes, the CSR filter compares against a synthetic debug word documented under Debug Inputs.</td></tr>
<tr><td>8</td><td>key_unsigned</td><td>RW</td><td>1</td><td>1 selects unsigned update-key interpretation, 0 selects signed extraction.</td></tr>
<tr><td>11:9</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
<tr><td>12</td><td>filter_enable</td><td>RW</td><td>0</td><td>Enables the runtime filter-key comparison.</td></tr>
<tr><td>13</td><td>filter_reject</td><td>RW</td><td>0</td><td>0 accepts matching events, 1 rejects matching events.</td></tr>
<tr><td>23:14</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
<tr><td>24</td><td>error</td><td>RO</td><td>0</td><td>Set when the last apply request failed CSR validation.</td></tr>
<tr><td>27:25</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
<tr><td>31:28</td><td>error_info</td><td>RO</td><td>0</td><td>Validation error code. <b>0x1</b> indicates invalid bounds in auto-right-bound mode.</td></tr>
</table></html>}

set KEY_LOC_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>7:0</td><td>update_key_low</td><td>RW</td><td>17</td><td>LSB of the update-key slice inside the snooped data word.</td></tr>
<tr><td>15:8</td><td>update_key_high</td><td>RW</td><td>29</td><td>MSB of the update-key slice inside the snooped data word.</td></tr>
<tr><td>23:16</td><td>filter_key_low</td><td>RW</td><td>35</td><td>LSB of the filter-key slice inside the snooped data word. In debug modes this selects the synthetic debug word instead.</td></tr>
<tr><td>31:24</td><td>filter_key_high</td><td>RW</td><td>38</td><td>MSB of the filter-key slice inside the snooped data word. In debug modes this selects the synthetic debug word instead.</td></tr>
</table></html>}

set KEY_VALUE_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>15:0</td><td>update_key</td><td>RW</td><td>0</td><td>Literal update-key override used by mode-dependent histogram logic.</td></tr>
<tr><td>31:16</td><td>filter_key</td><td>RW</td><td>0</td><td>Literal filter-key comparison value.</td></tr>
</table></html>}

set BANK_STATUS_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>0</td><td>active_bank</td><td>RO</td><td>0</td><td>Currently active write bank.</td></tr>
<tr><td>1</td><td>flushing</td><td>RO</td><td>0</td><td>1 while the next active bank is being cleared.</td></tr>
<tr><td>7:2</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
<tr><td>15:8</td><td>flush_addr</td><td>RO</td><td>0</td><td>Bin index currently being cleared.</td></tr>
<tr><td>31:16</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
</table></html>}

set PORT_STATUS_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>7:0</td><td>fifo_empty_mask</td><td>RO</td><td>0xFF</td><td>One bit per ingress FIFO. 1 indicates the corresponding FIFO is empty.</td></tr>
<tr><td>15:8</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
<tr><td>23:16</td><td>fifo_level_max</td><td>RO</td><td>0</td><td>Maximum observed FIFO fill level across the four ingress-port pairs.</td></tr>
<tr><td>31:24</td><td>reserved</td><td>RO</td><td>0</td><td>Reserved, read as zero.</td></tr>
</table></html>}

set COAL_STATUS_FIELDS_HTML {<html><table border="1" cellpadding="3" width="100%">
<tr><th>Bit</th><th>Name</th><th>Access</th><th>Reset</th><th>Description</th></tr>
<tr><td>7:0</td><td>queue_occupancy</td><td>RO</td><td>0</td><td>Current coalescing-queue occupancy.</td></tr>
<tr><td>15:8</td><td>queue_occupancy_max</td><td>RO</td><td>0</td><td>Maximum queue occupancy observed in the current interval.</td></tr>
<tr><td>31:16</td><td>queue_overflow_count</td><td>RO</td><td>0</td><td>Total number of queue-overflow events.</td></tr>
</table></html>}

set HIST_FILL_FMT_HTML {<html>
<b>hist_fill_in / fill_in_1..7</b> — 39-bit Avalon-ST sink<br/>
Sidebands: <b>channel[AVST_CHANNEL_WIDTH-1:0]</b>, <b>startofpacket</b>, <b>endofpacket</b><br/>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Field</th><th>Description</th></tr>
<tr><td>38:35</td><td>filter key slice (default)</td><td>Default filter-key location. Runtime-programmable through <b>KEY_LOC</b>.</td></tr>
<tr><td>34:30</td><td>payload / unused by default</td><td>Forwarded or ignored by the histogram core unless selected by a custom key map.</td></tr>
<tr><td>29:17</td><td>update key slice (default)</td><td>Default update-key location used for binning. Runtime-programmable through <b>KEY_LOC</b>.</td></tr>
<tr><td>16:0</td><td>payload / unused by default</td><td>Remaining data payload. Preserved on the snoop passthrough path.</td></tr>
</table></html>}

set FILL_OUT_FMT_HTML {<html>
<b>fill_out</b> — 39-bit Avalon-ST source<br/>
Sidebands: <b>channel[AVST_CHANNEL_WIDTH-1:0]</b>, optional <b>startofpacket</b>, optional <b>endofpacket</b><br/>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Field</th><th>Description</th></tr>
<tr><td>38:0</td><td>forwarded ingress payload</td><td>Port-0 ingress word forwarded unchanged when <b>SNOOP_EN</b> is enabled. SOP/EOP are driven only when <b>ENABLE_PACKET</b> is enabled.</td></tr>
</table></html>}

set CTRL_FMT_HTML {<html>
<b>ctrl</b> — 9-bit Avalon-ST sink<br/>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Field</th><th>Description</th></tr>
<tr><td>8:0</td><td>reserved compatibility payload</td><td>Run-control transport kept for system-level compatibility. The current RTL always asserts <b>ready</b> and does not consume the payload bits.</td></tr>
</table></html>}

set DEBUG_FMT_HTML {<html>
<b>debug_1..6</b> — 16-bit Avalon-ST sinks<br/>
<table border="1" cellpadding="3" width="100%">
<tr><th>Bits</th><th>Field</th><th>Description</th></tr>
<tr><td>15:0</td><td>debug sample</td><td>Histogrammed directly when <b>CONTROL.mode</b> selects a negative debug source.</td></tr>
</table><br/>
<b>Debug-mode filter word</b><br/>
When <b>CONTROL.filter_enable</b> is set in a negative debug mode, the filter comparator does not see the normal 39-bit ingress data word. It sees a synthetic word: <b>[15:0]</b> = debug sample, <b>[23:16]</b> = zero-based debug source index (0=debug_1), and <b>[31:24]</b> = absolute debug mode (1..7).</html>}

# --- derived-value computation ----------------------------------------------------

proc compute_derived_values {} {
    set n_bins         [get_parameter_value N_BINS]
    set max_count_bits [get_parameter_value MAX_COUNT_BITS]
    set coal_depth     [get_parameter_value COAL_QUEUE_DEPTH]
    set enable_pp      [get_parameter_value ENABLE_PINGPONG]
    set n_ports        [get_parameter_value N_PORTS]
    set fifo_addr_w    [get_parameter_value FIFO_ADDR_WIDTH]
    set fifo_depth     [expr {1 << $fifo_addr_w}]

    set min_hist_addr_w 1
    if {$n_bins > 1} {
        set min_hist_addr_w [ceil_log2 $n_bins]
    }

    # M10K for bins: each true-dpram pair hosts up to 512 x 20 bits
    set m10k_pairs_bins   [expr {int(ceil(double($n_bins) / 512.0))}]
    set m10k_width_factor [expr {int(ceil(double($max_count_bits) / 20.0))}]
    set m10k_bins_base    [expr {$m10k_pairs_bins * $m10k_width_factor * 2}]
    if {[string equal -nocase $enable_pp "true"]} {
        set m10k_bins [expr {$m10k_bins_base * 2}]
    } else {
        set m10k_bins $m10k_bins_base
    }

    # M10K for coalescing queue
    set m10k_coal [expr {int(ceil(double($coal_depth) / 512.0)) * 2}]

    set m10k_total  [expr {$m10k_bins + $m10k_coal}]
    set est_alm     [expr {350 + $n_ports * 45}]
    set flush_cycles $n_bins

    set_parameter_value M10K_BINS_DERIVED      $m10k_bins
    set_parameter_value M10K_COAL_DERIVED      $m10k_coal
    set_parameter_value M10K_TOTAL_DERIVED     $m10k_total
    set_parameter_value DSP_COUNT_DERIVED      0
    set_parameter_value EST_ALM_DERIVED        $est_alm
    set_parameter_value HIST_ADDR_W_MIN_DERIVED $min_hist_addr_w

    catch {
        set_display_item_property sizing_html TEXT "<html><b>Resource estimate</b><br/>Histogram bins M10K: <b>${m10k_bins}</b><br/>Coalescing queue M10K: <b>${m10k_coal}</b><br/>Total M10K: <b>${m10k_total}</b><br/>Estimated ALMs: ~<b>${est_alm}</b><br/>Minimum hist_bin address width: <b>${min_hist_addr_w}</b> bits<br/>Worst-case bank flush length: <b>${flush_cycles}</b> cycles<br/>DSP blocks: <b>0</b></html>"
    }
    catch {
        set pp_status "disabled"
        if {[string equal -nocase $enable_pp "true"]} {
            set pp_status "enabled"
        }
        set_display_item_property runtime_html TEXT "<html><b>Runtime behaviour</b><br/>Active ingress ports: <b>${n_ports}</b><br/>Ingress FIFO depth: <b>${fifo_depth}</b> entries per enabled port<br/>Coalescing queue depth: <b>${coal_depth}</b> entries<br/>Ping-pong rate readout: <b>${pp_status}</b><br/>A clear or interval swap can require up to <b>${flush_cycles}</b> cycles to walk the full histogram depth.</html>"
    }
}

# --- validate / elaborate ---------------------------------------------------------

proc validate {} {
    compute_derived_values

    set n_bins         [get_parameter_value N_BINS]
    set max_count_bits [get_parameter_value MAX_COUNT_BITS]
    set def_left_bound [get_parameter_value DEF_LEFT_BOUND]
    set def_bin_width  [get_parameter_value DEF_BIN_WIDTH]
    set key_hi         [get_parameter_value UPDATE_KEY_BIT_HI]
    set key_lo         [get_parameter_value UPDATE_KEY_BIT_LO]
    set key_repr       [get_parameter_value UPDATE_KEY_REPRESENTATION]
    set flt_hi         [get_parameter_value FILTER_KEY_BIT_HI]
    set flt_lo         [get_parameter_value FILTER_KEY_BIT_LO]
    set sar_tick       [get_parameter_value SAR_TICK_WIDTH]
    set sar_key        [get_parameter_value SAR_KEY_WIDTH]
    set n_ports        [get_parameter_value N_PORTS]
    set fifo_addr_w    [get_parameter_value FIFO_ADDR_WIDTH]
    set channels_per_port [get_parameter_value CHANNELS_PER_PORT]
    set coal_depth     [get_parameter_value COAL_QUEUE_DEPTH]
    set avst_w         [get_parameter_value AVST_DATA_WIDTH]
    set avst_ch_w      [get_parameter_value AVST_CHANNEL_WIDTH]
    set def_interval   [get_parameter_value DEF_INTERVAL_CLOCKS]
    set avs_addr_w     [get_parameter_value AVS_ADDR_WIDTH]
    set n_debug        [get_parameter_value N_DEBUG_INTERFACE]
    set debug_level    [get_parameter_value DEBUG]
    set ver_maj        [get_parameter_value VERSION_MAJOR]
    set ver_min        [get_parameter_value VERSION_MINOR]
    set ver_pat        [get_parameter_value VERSION_PATCH]
    set build_val      [get_parameter_value BUILD]
    set ip_uid_value   [get_parameter_value IP_UID]
    set version_date   [get_parameter_value VERSION_DATE]
    set version_git    [get_parameter_value VERSION_GIT]
    set instance_id    [get_parameter_value INSTANCE_ID]

    set min_hist_addr_w 1
    if {$n_bins > 1} {
        set min_hist_addr_w [ceil_log2 $n_bins]
    }

    if {$n_bins < 1 || $n_bins > 2048} {
        send_message error "N_BINS must stay in the range 1..2048."
    }
    if {$max_count_bits < 1 || $max_count_bits > 72} {
        send_message error "MAX_COUNT_BITS must stay in the range 1..72."
    }
    if {$def_left_bound < -2147483648 || $def_left_bound > 2147483647} {
        send_message error "DEF_LEFT_BOUND must stay in the signed 32-bit integer range."
    }
    if {$def_bin_width < 1 || $def_bin_width > 65535} {
        send_message error "DEF_BIN_WIDTH must stay in the range 1..65535 because BIN_WIDTH is stored in 16 bits."
    }
    if {$key_hi < 0 || $key_hi > 255} {
        send_message error "UPDATE_KEY_BIT_HI must stay in the range 0..255."
    }
    if {$key_lo < 0 || $key_lo > 255} {
        send_message error "UPDATE_KEY_BIT_LO must stay in the range 0..255."
    }
    if {![string match "UNSIGNED" $key_repr] && ![string match "SIGNED" $key_repr]} {
        send_message error "UPDATE_KEY_REPRESENTATION must be either UNSIGNED or SIGNED."
    }
    if {$flt_hi < 0 || $flt_hi > 255} {
        send_message error "FILTER_KEY_BIT_HI must stay in the range 0..255."
    }
    if {$flt_lo < 0 || $flt_lo > 255} {
        send_message error "FILTER_KEY_BIT_LO must stay in the range 0..255."
    }
    if {$sar_tick < 1 || $sar_tick > 127} {
        send_message error "SAR_TICK_WIDTH must stay in the range 1..127."
    }
    if {$sar_key < 1 || $sar_key > 127} {
        send_message error "SAR_KEY_WIDTH must stay in the range 1..127."
    }
    if {$n_ports != 1 && $n_ports != 2 && $n_ports != 4 && $n_ports != 8} {
        send_message error "N_PORTS must stay in the set {1 2 4 8}."
    }
    if {$fifo_addr_w < 4 || $fifo_addr_w > 12} {
        send_message error "FIFO_ADDR_WIDTH must stay in the range 4..12."
    }
    if {$channels_per_port < 1 || $channels_per_port > 256} {
        send_message error "CHANNELS_PER_PORT must stay in the range 1..256."
    }
    if {$coal_depth != 16 && $coal_depth != 32 && $coal_depth != 64 && $coal_depth != 128 && $coal_depth != 160 && $coal_depth != 192 && $coal_depth != 256 && $coal_depth != 512} {
        send_message error "COAL_QUEUE_DEPTH must stay in the set {16 32 64 128 160 192 256 512}."
    }
    if {$avst_w < 1 || $avst_w > 512} {
        send_message error "AVST_DATA_WIDTH must stay in the range 1..512."
    }
    if {$avst_ch_w < 1 || $avst_ch_w > 8} {
        send_message error "AVST_CHANNEL_WIDTH must stay in the range 1..8."
    }
    if {$def_interval < 0 || $def_interval > 2147483647} {
        send_message error "DEF_INTERVAL_CLOCKS must stay in the range 0..2147483647."
    }
    if {$avs_addr_w < 1 || $avs_addr_w > 16} {
        send_message error "AVS_ADDR_WIDTH must stay in the range 1..16."
    }
    if {$n_debug < 0 || $n_debug > 6} {
        send_message error "N_DEBUG_INTERFACE must stay in the range 0..6."
    }
    if {$debug_level < 0 || $debug_level > 2} {
        send_message error "DEBUG must stay in the range 0..2."
    }
    if {$key_hi < $key_lo} {
        send_message error "UPDATE_KEY_BIT_HI must be >= UPDATE_KEY_BIT_LO."
    }
    if {$flt_hi < $flt_lo} {
        send_message error "FILTER_KEY_BIT_HI must be >= FILTER_KEY_BIT_LO."
    }
    if {$sar_tick < $sar_key} {
        send_message error "SAR_TICK_WIDTH must be >= SAR_KEY_WIDTH."
    }
    if {$key_hi >= $avst_w} {
        send_message error "UPDATE_KEY_BIT_HI must be < AVST_DATA_WIDTH."
    }
    if {$flt_hi >= $avst_w} {
        send_message error "FILTER_KEY_BIT_HI must be < AVST_DATA_WIDTH."
    }
    if {$avs_addr_w < $min_hist_addr_w} {
        send_message error "AVS_ADDR_WIDTH must be at least ceil(log2(N_BINS)) so the hist_bin slave can address every bin."
    }
    if {$ver_maj < 0 || $ver_maj > 255} {
        send_message error "VERSION_MAJOR must stay in the range 0..255."
    }
    if {$ver_min < 0 || $ver_min > 255} {
        send_message error "VERSION_MINOR must stay in the range 0..255."
    }
    if {$ver_pat < 0 || $ver_pat > 15} {
        send_message error "VERSION_PATCH must stay in the range 0..15."
    }
    if {$build_val < 0 || $build_val > 4095} {
        send_message error "BUILD must stay in the range 0..4095."
    }
    if {$ip_uid_value < 0 || $ip_uid_value > 2147483647} {
        send_message error "IP_UID must stay in the signed 31-bit Platform Designer integer range."
    }
    if {$version_date < 0 || $version_date > 2147483647} {
        send_message error "VERSION_DATE must stay in the signed 31-bit Platform Designer integer range."
    }
    if {$version_git < 0 || $version_git > 2147483647} {
        send_message error "VERSION_GIT must stay in the signed 31-bit Platform Designer integer range."
    }
    if {$instance_id < 0 || $instance_id > 2147483647} {
        send_message error "INSTANCE_ID must stay in the signed 31-bit Platform Designer integer range."
    }
}

proc elaborate {} {
    compute_derived_values

    set data_w  [get_parameter_value AVST_DATA_WIDTH]
    set chan_w  [get_parameter_value AVST_CHANNEL_WIDTH]
    set n_bins  [get_parameter_value N_BINS]
    set n_ports [get_parameter_value N_PORTS]
    set n_debug [get_parameter_value N_DEBUG_INTERFACE]

    set min_hist_addr_w 1
    if {$n_bins > 1} {
        set min_hist_addr_w [ceil_log2 $n_bins]
    }

    set_parameter_property DEF_BIN_WIDTH ALLOWED_RANGES 1:65535
    set_parameter_property AVS_ADDR_WIDTH ALLOWED_RANGES ${min_hist_addr_w}:16

    # hist_bin burstcount needs AVS_ADDR_WIDTH+1 bits to represent burst=N_BINS
    set avs_addr_w [get_parameter_value AVS_ADDR_WIDTH]
    set_port_property avs_hist_bin_burstcount WIDTH_EXPR [expr {$avs_addr_w + 1}]
    set_parameter_property VERSION_MAJOR ENABLED false
    set_parameter_property VERSION_MINOR ENABLED false
    set_parameter_property VERSION_PATCH ENABLED false
    set_parameter_property BUILD ENABLED false
    set_parameter_property VERSION_DATE ENABLED false
    if {[get_parameter_value GIT_STAMP_OVERRIDE]} {
        set_parameter_property VERSION_GIT ENABLED true
    } else {
        set_parameter_property VERSION_GIT ENABLED false
    }

    set_optional_stream hist_fill_in 1 $data_w $chan_w
    for {set idx 1} {$idx <= 7} {incr idx} {
        set_optional_stream fill_in_$idx [expr {$n_ports > $idx}] $data_w $chan_w
    }
    set_optional_stream fill_out 1 $data_w $chan_w

    for {set idx 1} {$idx <= 6} {incr idx} {
        set_interface_property debug_$idx ENABLED [expr {$n_debug >= $idx ? "true" : "false"}]
    }
}

# --- file sets --------------------------------------------------------------------

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL histogram_statistics_v2
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file histogram_statistics_v2.vhd VHDL PATH histogram_statistics_v2.vhd TOP_LEVEL_FILE
add_fileset_file histogram_statistics_v2_bool_core.vhd VHDL PATH histogram_statistics_v2_bool_core.vhd
add_fileset_file histogram_statistics_v2_pkg.vhd VHDL PATH ../../../../../../histogram_statistics/rtl/histogram_statistics_v2_pkg.vhd
add_fileset_file hit_fifo.vhd VHDL PATH ../../../../../../histogram_statistics/rtl/hit_fifo.vhd
add_fileset_file coalescing_queue.vhd VHDL PATH ../../../../../../histogram_statistics/rtl/coalescing_queue.vhd
add_fileset_file rr_arbiter.vhd VHDL PATH ../../../../../../histogram_statistics/rtl/rr_arbiter.vhd
add_fileset_file bin_divider.vhd VHDL PATH ../../../../../../histogram_statistics/rtl/bin_divider.vhd
add_fileset_file true_dual_port_ram_single_clock.vhd VHDL PATH ../../../../../../histogram_statistics/rtl/true_dual_port_ram_single_clock.vhd
add_fileset_file pingpong_sram.vhd VHDL PATH ../../../../../../histogram_statistics/rtl/pingpong_sram.vhd

# --- parameters -------------------------------------------------------------------

# -- Histogram configuration --

add_parameter N_BINS NATURAL 256
set_parameter_property N_BINS DISPLAY_NAME "Number of Bins"
set_parameter_property N_BINS UNITS None
set_parameter_property N_BINS ALLOWED_RANGES 1:2048
set_parameter_property N_BINS HDL_PARAMETER true
set_parameter_property N_BINS DESCRIPTION "Number of bins in the histogram. More bins require more M10K and more cycles to flush. Two M10K (one true dual-port RAM) host up to 512 bins."

add_parameter MAX_COUNT_BITS NATURAL 32
set_parameter_property MAX_COUNT_BITS DISPLAY_NAME "Bin Counter Width"
set_parameter_property MAX_COUNT_BITS UNITS Bits
set_parameter_property MAX_COUNT_BITS ALLOWED_RANGES 1:72
set_parameter_property MAX_COUNT_BITS HDL_PARAMETER true
set_parameter_property MAX_COUNT_BITS DESCRIPTION "Width of each bin counter. Two M10K support up to 40 bits; four M10K support up to 72 bits. Overflow protection triggers when the counter saturates."

add_parameter DEF_LEFT_BOUND INTEGER -1000
set_parameter_property DEF_LEFT_BOUND DISPLAY_NAME "Default Left Bound"
set_parameter_property DEF_LEFT_BOUND UNITS None
set_parameter_property DEF_LEFT_BOUND ALLOWED_RANGES -2147483648:2147483647
set_parameter_property DEF_LEFT_BOUND HDL_PARAMETER true
set_parameter_property DEF_LEFT_BOUND DESCRIPTION "Power-on default signed left boundary of the histogram range. Overridable at runtime through CSR word 3."

add_parameter DEF_BIN_WIDTH NATURAL 16
set_parameter_property DEF_BIN_WIDTH DISPLAY_NAME "Default Bin Width"
set_parameter_property DEF_BIN_WIDTH UNITS None
set_parameter_property DEF_BIN_WIDTH ALLOWED_RANGES 1:65535
set_parameter_property DEF_BIN_WIDTH HDL_PARAMETER true
set_parameter_property DEF_BIN_WIDTH DESCRIPTION "Power-on default bin width in key-space units. Overridable at runtime through CSR word 5."

# -- Key extraction --

add_parameter UPDATE_KEY_BIT_HI NATURAL 29
set_parameter_property UPDATE_KEY_BIT_HI DISPLAY_NAME "Update Key MSB"
set_parameter_property UPDATE_KEY_BIT_HI UNITS None
set_parameter_property UPDATE_KEY_BIT_HI ALLOWED_RANGES 0:255
set_parameter_property UPDATE_KEY_BIT_HI HDL_PARAMETER true
set_parameter_property UPDATE_KEY_BIT_HI DESCRIPTION "Bit position of the MSB of the update key extracted from the snooped data stream."

add_parameter UPDATE_KEY_BIT_LO NATURAL 17
set_parameter_property UPDATE_KEY_BIT_LO DISPLAY_NAME "Update Key LSB"
set_parameter_property UPDATE_KEY_BIT_LO UNITS None
set_parameter_property UPDATE_KEY_BIT_LO ALLOWED_RANGES 0:255
set_parameter_property UPDATE_KEY_BIT_LO HDL_PARAMETER true
set_parameter_property UPDATE_KEY_BIT_LO DESCRIPTION "Bit position of the LSB of the update key extracted from the snooped data stream."

add_parameter UPDATE_KEY_REPRESENTATION STRING UNSIGNED
set_parameter_property UPDATE_KEY_REPRESENTATION DISPLAY_NAME "Key Representation"
set_parameter_property UPDATE_KEY_REPRESENTATION UNITS None
set_parameter_property UPDATE_KEY_REPRESENTATION ALLOWED_RANGES {"UNSIGNED" "SIGNED"}
set_parameter_property UPDATE_KEY_REPRESENTATION HDL_PARAMETER true
set_parameter_property UPDATE_KEY_REPRESENTATION DESCRIPTION "Data type of the update key. SIGNED uses two's complement."

add_parameter FILTER_KEY_BIT_HI NATURAL 38
set_parameter_property FILTER_KEY_BIT_HI DISPLAY_NAME "Filter Key MSB"
set_parameter_property FILTER_KEY_BIT_HI UNITS None
set_parameter_property FILTER_KEY_BIT_HI ALLOWED_RANGES 0:255
set_parameter_property FILTER_KEY_BIT_HI HDL_PARAMETER true
set_parameter_property FILTER_KEY_BIT_HI DESCRIPTION "Bit position of the MSB of the filter key in the snooped data stream."

add_parameter FILTER_KEY_BIT_LO NATURAL 35
set_parameter_property FILTER_KEY_BIT_LO DISPLAY_NAME "Filter Key LSB"
set_parameter_property FILTER_KEY_BIT_LO UNITS None
set_parameter_property FILTER_KEY_BIT_LO ALLOWED_RANGES 0:255
set_parameter_property FILTER_KEY_BIT_LO HDL_PARAMETER true
set_parameter_property FILTER_KEY_BIT_LO DESCRIPTION "Bit position of the LSB of the filter key in the snooped data stream."

add_parameter SAR_TICK_WIDTH NATURAL 32
set_parameter_property SAR_TICK_WIDTH DISPLAY_NAME "Boundary Resolution"
set_parameter_property SAR_TICK_WIDTH UNITS Bits
set_parameter_property SAR_TICK_WIDTH ALLOWED_RANGES 1:127
set_parameter_property SAR_TICK_WIDTH HDL_PARAMETER true
set_parameter_property SAR_TICK_WIDTH DESCRIPTION "SAR quantizer tick width controlling bin boundary resolution. Must be >= SAR_KEY_WIDTH."

add_parameter SAR_KEY_WIDTH NATURAL 16
set_parameter_property SAR_KEY_WIDTH DISPLAY_NAME "Max Key Width"
set_parameter_property SAR_KEY_WIDTH UNITS Bits
set_parameter_property SAR_KEY_WIDTH ALLOWED_RANGES 1:127
set_parameter_property SAR_KEY_WIDTH HDL_PARAMETER true
set_parameter_property SAR_KEY_WIDTH DESCRIPTION "Maximum width of the update and filter key. Increase to 32 or higher for wider key fields; may require tuning the key-getter pipeline."

# -- Ingress --

add_parameter N_PORTS NATURAL 8
set_parameter_property N_PORTS DISPLAY_NAME "Number of Ingress Ports"
set_parameter_property N_PORTS UNITS None
set_parameter_property N_PORTS ALLOWED_RANGES {1 2 4 8}
set_parameter_property N_PORTS HDL_PARAMETER true
set_parameter_property N_PORTS DESCRIPTION "Number of Avalon-ST ingress ports. Ports beyond N_PORTS are disabled by the elaboration callback."

add_parameter FIFO_ADDR_WIDTH NATURAL 8
set_parameter_property FIFO_ADDR_WIDTH DISPLAY_NAME "Ingress FIFO Address Width"
set_parameter_property FIFO_ADDR_WIDTH UNITS Bits
set_parameter_property FIFO_ADDR_WIDTH ALLOWED_RANGES 4:12
set_parameter_property FIFO_ADDR_WIDTH HDL_PARAMETER true
set_parameter_property FIFO_ADDR_WIDTH DESCRIPTION "Address width of each per-port ingress FIFO. Depth is 2^FIFO_ADDR_WIDTH entries. The Phase-5 default is 8 (256 entries), which absorbs the refreshed datapath integration burst while staying materially smaller than the old 1024-entry passive-tap setting."

add_parameter CHANNELS_PER_PORT NATURAL 32
set_parameter_property CHANNELS_PER_PORT DISPLAY_NAME "Channels per Port"
set_parameter_property CHANNELS_PER_PORT UNITS None
set_parameter_property CHANNELS_PER_PORT ALLOWED_RANGES 1:256
set_parameter_property CHANNELS_PER_PORT HDL_PARAMETER true
set_parameter_property CHANNELS_PER_PORT DESCRIPTION "Logical channel stride added per ingress port before binning."

add_parameter COAL_QUEUE_DEPTH NATURAL 256
set_parameter_property COAL_QUEUE_DEPTH DISPLAY_NAME "Coalescing Queue Depth"
set_parameter_property COAL_QUEUE_DEPTH UNITS None
set_parameter_property COAL_QUEUE_DEPTH ALLOWED_RANGES {16 32 64 128 160 192 256 512}
set_parameter_property COAL_QUEUE_DEPTH HDL_PARAMETER true
set_parameter_property COAL_QUEUE_DEPTH DESCRIPTION "Shared coalescing FIFO depth. Concurrent bin updates from all ports are serialized through this queue before reaching the histogram SRAM."

add_parameter AVST_DATA_WIDTH NATURAL 39
set_parameter_property AVST_DATA_WIDTH DISPLAY_NAME "AVST Data Width"
set_parameter_property AVST_DATA_WIDTH UNITS Bits
set_parameter_property AVST_DATA_WIDTH ALLOWED_RANGES 1:512
set_parameter_property AVST_DATA_WIDTH HDL_PARAMETER true
set_parameter_property AVST_DATA_WIDTH DESCRIPTION "Bit width of the Avalon-ST data bus on ingress and passthrough interfaces."

add_parameter AVST_CHANNEL_WIDTH NATURAL 4
set_parameter_property AVST_CHANNEL_WIDTH DISPLAY_NAME "AVST Channel Width"
set_parameter_property AVST_CHANNEL_WIDTH UNITS Bits
set_parameter_property AVST_CHANNEL_WIDTH ALLOWED_RANGES 1:8
set_parameter_property AVST_CHANNEL_WIDTH HDL_PARAMETER true
set_parameter_property AVST_CHANNEL_WIDTH DESCRIPTION "Bit width of the Avalon-ST channel signal."

# -- Ping-pong / interval --

add_parameter ENABLE_PINGPONG BOOLEAN true
set_parameter_property ENABLE_PINGPONG DISPLAY_NAME "Enable Ping-Pong Rate Mode"
set_parameter_property ENABLE_PINGPONG UNITS None
set_parameter_property ENABLE_PINGPONG HDL_PARAMETER true
set_parameter_property ENABLE_PINGPONG DESCRIPTION "Enable dual-bank ping-pong SRAM with periodic automatic bank swap. When disabled, a single bank is used and the interval timer only controls clear timing."

add_parameter DEF_INTERVAL_CLOCKS NATURAL 125000000
set_parameter_property DEF_INTERVAL_CLOCKS DISPLAY_NAME "Default Interval (clocks)"
set_parameter_property DEF_INTERVAL_CLOCKS UNITS None
set_parameter_property DEF_INTERVAL_CLOCKS ALLOWED_RANGES 0:2147483647
set_parameter_property DEF_INTERVAL_CLOCKS HDL_PARAMETER true
set_parameter_property DEF_INTERVAL_CLOCKS DESCRIPTION "Power-on default ping-pong interval in clock cycles. 125000000 = 1 second at 125 MHz. Overridable at runtime through CSR word 10."

# -- Pass-through / snooping --

add_parameter SNOOP_EN BOOLEAN true
set_parameter_property SNOOP_EN DISPLAY_NAME "Enable Snooping"
set_parameter_property SNOOP_EN UNITS None
set_parameter_property SNOOP_EN HDL_PARAMETER true
set_parameter_property SNOOP_EN DESCRIPTION "When enabled, the primary ingress stream is forwarded to the fill_out source with zero added latency."

add_parameter ENABLE_PACKET BOOLEAN true
set_parameter_property ENABLE_PACKET DISPLAY_NAME "Packet Support"
set_parameter_property ENABLE_PACKET UNITS None
set_parameter_property ENABLE_PACKET HDL_PARAMETER true
set_parameter_property ENABLE_PACKET DESCRIPTION "Enable start-of-packet / end-of-packet signalling on the passthrough path. Valid, data, and channel remain part of the contract regardless of this toggle."

# -- Memory-mapped --

add_parameter AVS_ADDR_WIDTH NATURAL 8
set_parameter_property AVS_ADDR_WIDTH DISPLAY_NAME "Histogram Address Width"
set_parameter_property AVS_ADDR_WIDTH UNITS Bits
set_parameter_property AVS_ADDR_WIDTH ALLOWED_RANGES 1:16
set_parameter_property AVS_ADDR_WIDTH HDL_PARAMETER true
set_parameter_property AVS_ADDR_WIDTH DESCRIPTION "Address width for the Avalon-MM histogram-bin readout slave. Must cover at least N_BINS words."

# -- Debug --

add_parameter N_DEBUG_INTERFACE NATURAL 6
set_parameter_property N_DEBUG_INTERFACE DISPLAY_NAME "Debug Interfaces"
set_parameter_property N_DEBUG_INTERFACE UNITS None
set_parameter_property N_DEBUG_INTERFACE ALLOWED_RANGES 0:6
set_parameter_property N_DEBUG_INTERFACE HDL_PARAMETER true
set_parameter_property N_DEBUG_INTERFACE DESCRIPTION "Number of 16-bit debug Avalon-ST sinks enabled by the elaboration callback. The RTL supports up to 6."

add_parameter DEBUG NATURAL 0
set_parameter_property DEBUG DISPLAY_NAME "Debug Level"
set_parameter_property DEBUG UNITS None
set_parameter_property DEBUG ALLOWED_RANGES 0:2
set_parameter_property DEBUG HDL_PARAMETER true
set_parameter_property DEBUG DESCRIPTION "Debug level. 0 disables optional debug, 1 keeps synthesizable debug, 2 enables simulation-only debug."

# -- Versioning --

add_parameter VERSION_MAJOR NATURAL $VERSION_MAJOR_DEFAULT_CONST
set_parameter_property VERSION_MAJOR DISPLAY_NAME "Version Major"
set_parameter_property VERSION_MAJOR UNITS None
set_parameter_property VERSION_MAJOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MAJOR HDL_PARAMETER true
set_parameter_property VERSION_MAJOR ENABLED false

add_parameter VERSION_MINOR NATURAL $VERSION_MINOR_DEFAULT_CONST
set_parameter_property VERSION_MINOR DISPLAY_NAME "Version Minor"
set_parameter_property VERSION_MINOR UNITS None
set_parameter_property VERSION_MINOR ALLOWED_RANGES 0:255
set_parameter_property VERSION_MINOR HDL_PARAMETER true
set_parameter_property VERSION_MINOR ENABLED false

add_parameter VERSION_PATCH NATURAL $VERSION_PATCH_DEFAULT_CONST
set_parameter_property VERSION_PATCH DISPLAY_NAME "Version Patch"
set_parameter_property VERSION_PATCH UNITS None
set_parameter_property VERSION_PATCH ALLOWED_RANGES 0:15
set_parameter_property VERSION_PATCH HDL_PARAMETER true
set_parameter_property VERSION_PATCH ENABLED false

add_parameter BUILD NATURAL $BUILD_DEFAULT_CONST
set_parameter_property BUILD DISPLAY_NAME "Build Stamp"
set_parameter_property BUILD UNITS None
set_parameter_property BUILD ALLOWED_RANGES 0:4095
set_parameter_property BUILD HDL_PARAMETER true
set_parameter_property BUILD ENABLED false
set_parameter_property BUILD DESCRIPTION {12-bit build stamp packed into VERSION[11:0].}

# -- Identity header --

add_parameter IP_UID NATURAL $IP_UID_DEFAULT_CONST
set_parameter_property IP_UID DISPLAY_NAME "UID"
set_parameter_property IP_UID UNITS None
set_parameter_property IP_UID ALLOWED_RANGES 0:2147483647
set_parameter_property IP_UID HDL_PARAMETER true
set_parameter_property IP_UID DISPLAY_HINT hexadecimal
set_parameter_property IP_UID DESCRIPTION {Software-visible IP identifier at CSR word 0. Default corresponds to ASCII "HIST" (0x48495354).}

add_parameter VERSION_DATE NATURAL $VERSION_DATE_DEFAULT_CONST
set_parameter_property VERSION_DATE DISPLAY_NAME "Version Date"
set_parameter_property VERSION_DATE UNITS None
set_parameter_property VERSION_DATE ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_DATE HDL_PARAMETER true
set_parameter_property VERSION_DATE ENABLED false
set_parameter_property VERSION_DATE DESCRIPTION {YYYYMMDD provenance word exposed through META when software writes selector 1.}

add_parameter VERSION_GIT NATURAL $VERSION_GIT_DEFAULT_CONST
set_parameter_property VERSION_GIT DISPLAY_NAME "Git Stamp"
set_parameter_property VERSION_GIT UNITS None
set_parameter_property VERSION_GIT ALLOWED_RANGES 0:2147483647
set_parameter_property VERSION_GIT HDL_PARAMETER true
set_parameter_property VERSION_GIT DISPLAY_HINT hexadecimal
set_parameter_property VERSION_GIT ENABLED false
set_parameter_property VERSION_GIT DESCRIPTION {Truncated build git hash exposed through META when software writes selector 2.}

add_parameter GIT_STAMP_OVERRIDE BOOLEAN false
set_parameter_property GIT_STAMP_OVERRIDE DISPLAY_NAME "Override Git Stamp"
set_parameter_property GIT_STAMP_OVERRIDE UNITS None
set_parameter_property GIT_STAMP_OVERRIDE HDL_PARAMETER false
set_parameter_property GIT_STAMP_OVERRIDE DESCRIPTION "When enabled, allows manual entry of VERSION_GIT. When disabled, the packaged git stamp remains read-only."

add_parameter INSTANCE_ID NATURAL $INSTANCE_ID_DEFAULT_CONST
set_parameter_property INSTANCE_ID DISPLAY_NAME "Instance ID"
set_parameter_property INSTANCE_ID UNITS None
set_parameter_property INSTANCE_ID ALLOWED_RANGES 0:2147483647
set_parameter_property INSTANCE_ID HDL_PARAMETER true
set_parameter_property INSTANCE_ID DESCRIPTION {Integration-time instance identifier exposed through META when software writes selector 3.}

# -- Derived (hidden) --

foreach derived_name {M10K_BINS_DERIVED M10K_COAL_DERIVED M10K_TOTAL_DERIVED DSP_COUNT_DERIVED EST_ALM_DERIVED HIST_ADDR_W_MIN_DERIVED} {
    add_parameter $derived_name NATURAL 0
    set_parameter_property $derived_name HDL_PARAMETER false
    set_parameter_property $derived_name DERIVED true
    set_parameter_property $derived_name VISIBLE false
}

# --- GUI layout -------------------------------------------------------------------

set TAB_CONFIGURATION "Configuration"
set TAB_IDENTITY      "Identity"
set TAB_INTERFACES    "Interfaces"
set TAB_REGMAP        "Register Map"

add_display_item "" $TAB_CONFIGURATION GROUP tab
add_display_item $TAB_CONFIGURATION "Overview" GROUP
add_display_item $TAB_CONFIGURATION "Histogram Sizing" GROUP
add_display_item $TAB_CONFIGURATION "Key Extraction" GROUP
add_display_item $TAB_CONFIGURATION "Ingress" GROUP
add_display_item $TAB_CONFIGURATION "Ping-Pong / Interval" GROUP
add_display_item $TAB_CONFIGURATION "Resources" GROUP
add_display_item $TAB_CONFIGURATION "Debug Inputs" GROUP

add_html_text "Overview" overview_html {<html><b>Function</b><br/>Multi-port coalescing histogram with pipelined bin index and ping-pong rate readout. Accepts up to 8 Avalon-ST ingress ports, extracts a configurable key field, maps keys to bin indices via a SAR-style divider, coalesces concurrent updates through a shared queue, and stores counts in dual-bank M10K SRAM with automatic interval-based bank swap.<br/><br/><b>Data path</b><br/>ingress -&gt; hit_fifo (per port) -&gt; rr_arbiter -&gt; bin_divider -&gt; coalescing_queue -&gt; pingpong_sram<br/><br/><b>Rate readout</b><br/><b>TOTAL_HITS</b> and <b>DROPPED_HITS</b> are live current-interval counters. <b>LAST_INTERVAL_TOTAL_HITS</b> and <b>LAST_INTERVAL_DROPPED_HITS</b> latch the completed interval just before the live counters reset, allowing stable one-second rate polling.<br/><br/><b>Clocking</b><br/>All interfaces run inside a single synchronous domain. The optional <b>interval_reset</b> sink triggers a manual clear / bank-swap event independently of the periodic timer.</html>}

add_display_item "Histogram Sizing" N_BINS parameter
add_display_item "Histogram Sizing" MAX_COUNT_BITS parameter
add_display_item "Histogram Sizing" DEF_LEFT_BOUND parameter
add_display_item "Histogram Sizing" DEF_BIN_WIDTH parameter
add_html_text "Histogram Sizing" sizing_html "<html><b>Resource estimate</b><br/>Updated by the validation callback.</html>"

add_display_item "Key Extraction" UPDATE_KEY_BIT_HI parameter
add_display_item "Key Extraction" UPDATE_KEY_BIT_LO parameter
add_display_item "Key Extraction" UPDATE_KEY_REPRESENTATION parameter
add_display_item "Key Extraction" FILTER_KEY_BIT_HI parameter
add_display_item "Key Extraction" FILTER_KEY_BIT_LO parameter
add_display_item "Key Extraction" SAR_TICK_WIDTH parameter
add_display_item "Key Extraction" SAR_KEY_WIDTH parameter
add_html_text "Key Extraction" key_html {<html><b>Default slices</b><br/>The delivered package bins the default update-key slice <b>data[29:17]</b> and compares the default filter-key slice <b>data[38:35]</b>. Both slices are runtime-programmable through <b>KEY_LOC</b>.<br/><br/><b>Signed / unsigned</b><br/><b>UPDATE_KEY_REPRESENTATION</b> controls the power-on interpretation of the update key. The live datapath can be switched at runtime through <b>CONTROL.key_unsigned</b>.</html>}

add_display_item "Ingress" N_PORTS parameter
add_display_item "Ingress" FIFO_ADDR_WIDTH parameter
add_display_item "Ingress" CHANNELS_PER_PORT parameter
add_display_item "Ingress" COAL_QUEUE_DEPTH parameter
add_display_item "Ingress" AVST_DATA_WIDTH parameter
add_display_item "Ingress" AVST_CHANNEL_WIDTH parameter
add_html_text "Ingress" ingress_html {<html><b>Port scaling</b><br/>Each enabled ingress port owns an elastic FIFO before the shared round-robin arbiter. Ports above <b>N_PORTS</b> stay disabled in the Platform Designer interface contract.<br/><br/><b>FIFO depth</b><br/><b>FIFO_ADDR_WIDTH</b> sets the per-port FIFO depth as 2^width entries. Deepen this for passive post-stack taps that receive frame-bursty traffic and cannot backpressure the primary datapath.<br/><br/><b>Channel stride</b><br/><b>CHANNELS_PER_PORT</b> is added as a per-port offset before binning so multiple ingress links can be flattened into one histogram namespace.</html>}

add_display_item "Ping-Pong / Interval" ENABLE_PINGPONG parameter
add_display_item "Ping-Pong / Interval" DEF_INTERVAL_CLOCKS parameter
add_display_item "Ping-Pong / Interval" SNOOP_EN parameter
add_display_item "Ping-Pong / Interval" ENABLE_PACKET parameter
add_display_item "Ping-Pong / Interval" AVS_ADDR_WIDTH parameter
add_html_text "Ping-Pong / Interval" runtime_html "<html><b>Runtime behaviour</b><br/>Updated by the validation callback.</html>"

add_html_text "Resources" resources_html {<html><b>Integration notes</b><br/>1. The CSR aperture is <b>17</b> words (5-bit address). Words 0-1 are the standard identity header (UID + META). Words 2-16 hold control, histogram bounds, key configuration, status counters, and scratch.<br/>2. The <b>hist_bin</b> Avalon-MM slave provides burst-capable readout of the histogram SRAM with word-addressed access.<br/>3. The coalescing queue serializes concurrent bin updates from all ingress sources before they reach the histogram SRAM, preventing read-modify-write hazards.</html>}

add_html_text "Debug Inputs" debug_cfg_html {<html><b>Debug control</b><br/>The RTL exports up to 6 optional 16-bit Avalon-ST debug sinks. Negative signed values in <b>CONTROL.mode</b> select <b>debug_1..6</b> as the histogram source instead of the normal ingress ports. Mode <b>-7</b> is the Phase-5 combined MTS-delay mode: it samples signed <b>debug_1</b> and <b>debug_2</b> into separate FIFOs, then merges them through the normal arbiter without per-port channel offsets.<br/><br/><b>Debug filtering</b><br/>The runtime filter also works in negative modes. Use <b>KEY_LOC.filter_key_low=16</b> and <b>KEY_LOC.filter_key_high=23</b> to select a debug source index from the synthetic filter word; use <b>filter_key=0</b> for debug_1, <b>1</b> for debug_2, and so on.</html>}
add_display_item "Debug Inputs" N_DEBUG_INTERFACE parameter
add_display_item "Debug Inputs" DEBUG parameter

add_display_item "" $TAB_IDENTITY GROUP tab
add_display_item $TAB_IDENTITY "Delivered Profile" GROUP
add_display_item $TAB_IDENTITY "Versioning" GROUP

add_html_text "Delivered Profile" profile_html [format {<html><b>Catalog revision</b><br/>This release is packaged as <b>%s</b>.<br/><br/><b>Common identity header</b><br/>Word <b>0</b> is <b>UID</b> (default ASCII "HIST").<br/>Word <b>1</b> is <b>META</b>: write 0=VERSION, 1=DATE, 2=GIT, 3=INSTANCE_ID.<br/>Software can blind-scan the CSR window through UID at word 0 and the META mux at word 1.</html>} $VERSION_STRING_DEFAULT_CONST]
add_html_text "Versioning" versioning_html [format {<html><b>VERSION encoding</b><br/>Accessible via META word 1 (write selector 0).<br/>VERSION[31:24] = MAJOR, VERSION[23:16] = MINOR, VERSION[15:12] = PATCH, VERSION[11:0] = BUILD.<br/><br/><b>Packaged git stamp</b><br/>Default <b>VERSION_GIT</b> = <b>%s</b>. Enable <b>Override Git Stamp</b> to enter a custom value.</html>} $VERSION_GIT_HEX_DEFAULT_CONST]
add_display_item "Versioning" IP_UID parameter
add_display_item "Versioning" VERSION_MAJOR parameter
add_display_item "Versioning" VERSION_MINOR parameter
add_display_item "Versioning" VERSION_PATCH parameter
add_display_item "Versioning" BUILD parameter
add_display_item "Versioning" VERSION_DATE parameter
add_display_item "Versioning" VERSION_GIT parameter
add_display_item "Versioning" GIT_STAMP_OVERRIDE parameter
add_display_item "Versioning" INSTANCE_ID parameter

add_display_item "" $TAB_INTERFACES GROUP tab
add_display_item $TAB_INTERFACES "Clock / Reset" GROUP
add_display_item $TAB_INTERFACES "Data Path" GROUP
add_display_item $TAB_INTERFACES "Control Path" GROUP
add_display_item $TAB_INTERFACES "Monitoring" GROUP

add_html_text "Clock / Reset" clock_html {<html><b>clock</b> and <b>reset</b><br/>Single synchronous clock/reset domain for the full histogram datapath and CSR logic.<br/><br/><b>interval_reset</b><br/>Optional reset sink that triggers a manual clear / interval event independently of the periodic timer.</html>}
add_html_text "Data Path" datapath_html {<html><b>hist_fill_in</b><br/>Primary Avalon-ST sink carrying the data stream to be histogrammed.<br/><br/><b>fill_in_1..7</b><br/>Additional Avalon-ST sinks enabled when <b>N_PORTS &gt; 1</b>. Each port has an independent hit FIFO feeding the round-robin arbiter.<br/><br/><b>fill_out</b><br/>Passthrough Avalon-ST source that forwards the primary ingress stream when snooping is enabled.</html>}
add_html_text "Data Path" hist_fill_fmt_html $HIST_FILL_FMT_HTML
add_html_text "Data Path" fill_out_fmt_html $FILL_OUT_FMT_HTML

add_html_text "Control Path" control_html {<html><b>csr</b><br/>Word-addressed Avalon-MM CSR window with 17 registers (5-bit address). Words 0-1 provide the standard identity header (UID + META mux). Words 2-16 hold runtime configuration of histogram bounds, bin width, key locations, filter control, status readback, and scratch.<br/><br/><b>hist_bin</b><br/>Burst-capable Avalon-MM slave for histogram bin readout. Writing 0 to the slave triggers measure-and-clear.<br/><br/><b>ctrl</b><br/>9-bit Avalon-ST run-control sink retained for compatibility with existing system-level wiring. The current RTL always accepts the stream and ignores the payload.</html>}
add_html_text "Control Path" ctrl_fmt_html $CTRL_FMT_HTML

add_html_text "Monitoring" monitor_html {<html><b>debug_1..6</b><br/>Optional 16-bit Avalon-ST debug sinks for integration-time signal monitoring. The number of active debug interfaces is controlled by <b>N_DEBUG_INTERFACE</b>.</html>}
add_html_text "Monitoring" debug_fmt_html $DEBUG_FMT_HTML

add_display_item "" $TAB_REGMAP GROUP tab
add_display_item $TAB_REGMAP "CSR Window" GROUP
add_html_text "CSR Window" csr_table_html $CSR_TABLE_HTML
add_display_item $TAB_REGMAP "META Fields (0x01)" GROUP
add_html_text "META Fields (0x01)" meta_fields_html $META_FIELDS_HTML
add_display_item $TAB_REGMAP "CONTROL Fields (0x02)" GROUP
add_html_text "CONTROL Fields (0x02)" control_fields_html $CONTROL_FIELDS_HTML
add_display_item $TAB_REGMAP "KEY_LOC Fields (0x06)" GROUP
add_html_text "KEY_LOC Fields (0x06)" key_loc_fields_html $KEY_LOC_FIELDS_HTML
add_display_item $TAB_REGMAP "KEY_VALUE Fields (0x07)" GROUP
add_html_text "KEY_VALUE Fields (0x07)" key_value_fields_html $KEY_VALUE_FIELDS_HTML
add_display_item $TAB_REGMAP "BANK_STATUS Fields (0x0B)" GROUP
add_html_text "BANK_STATUS Fields (0x0B)" bank_status_fields_html $BANK_STATUS_FIELDS_HTML
add_display_item $TAB_REGMAP "PORT_STATUS Fields (0x0C)" GROUP
add_html_text "PORT_STATUS Fields (0x0C)" port_status_fields_html $PORT_STATUS_FIELDS_HTML
add_display_item $TAB_REGMAP "COAL_STATUS Fields (0x0F)" GROUP
add_html_text "COAL_STATUS Fields (0x0F)" coal_status_fields_html $COAL_STATUS_FIELDS_HTML

# --- interfaces -------------------------------------------------------------------

add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
add_interface_port clock i_clk clk Input 1

add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges DEASSERT
set_interface_property reset ENABLED true
add_interface_port reset i_rst reset Input 1

add_interface interval_reset reset end
set_interface_property interval_reset associatedClock clock
set_interface_property interval_reset ENABLED true
add_interface_port interval_reset i_interval_reset reset Input 1

add_interface hist_bin avalon end
set_interface_property hist_bin addressUnits WORDS
set_interface_property hist_bin associatedClock clock
set_interface_property hist_bin associatedReset reset
set_interface_property hist_bin bitsPerSymbol 8
set_interface_property hist_bin burstOnBurstBoundariesOnly false
set_interface_property hist_bin burstcountUnits WORDS
set_interface_property hist_bin explicitAddressSpan 0
set_interface_property hist_bin holdTime 0
set_interface_property hist_bin linewrapBursts false
set_interface_property hist_bin maximumPendingReadTransactions 1
set_interface_property hist_bin maximumPendingWriteTransactions 1
set_interface_property hist_bin readLatency 0
set_interface_property hist_bin readWaitTime 0
set_interface_property hist_bin setupTime 0
set_interface_property hist_bin timingUnits Cycles
set_interface_property hist_bin writeWaitTime 0
set_interface_property hist_bin ENABLED true
add_interface_port hist_bin avs_hist_bin_address address Input AVS_ADDR_WIDTH
add_interface_port hist_bin avs_hist_bin_read read Input 1
add_interface_port hist_bin avs_hist_bin_write write Input 1
add_interface_port hist_bin avs_hist_bin_writedata writedata Input 32
add_interface_port hist_bin avs_hist_bin_readdata readdata Output 32
add_interface_port hist_bin avs_hist_bin_readdatavalid readdatavalid Output 1
add_interface_port hist_bin avs_hist_bin_waitrequest waitrequest Output 1
add_interface_port hist_bin avs_hist_bin_burstcount burstcount Input 1
add_interface_port hist_bin avs_hist_bin_response response Output 2
add_interface_port hist_bin avs_hist_bin_writeresponsevalid writeresponsevalid Output 1
set_interface_assignment hist_bin embeddedsw.configuration.isFlash 0
set_interface_assignment hist_bin embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment hist_bin embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment hist_bin embeddedsw.configuration.isPrintableDevice 0

add_interface csr avalon end
set_interface_property csr addressUnits WORDS
set_interface_property csr associatedClock clock
set_interface_property csr associatedReset reset
set_interface_property csr bitsPerSymbol 8
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr burstcountUnits WORDS
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 0
set_interface_property csr maximumPendingWriteTransactions 0
set_interface_property csr readLatency 1
set_interface_property csr readWaitTime 0
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0
set_interface_property csr ENABLED true
add_interface_port csr avs_csr_address address Input $CSR_ADDR_W_CONST
add_interface_port csr avs_csr_read read Input 1
add_interface_port csr avs_csr_write write Input 1
add_interface_port csr avs_csr_writedata writedata Input 32
add_interface_port csr avs_csr_readdata readdata Output 32
add_interface_port csr avs_csr_waitrequest waitrequest Output 1
set_interface_assignment csr embeddedsw.configuration.isFlash 0
set_interface_assignment csr embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment csr embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment csr embeddedsw.configuration.isPrintableDevice 0

add_interface ctrl avalon_streaming end
set_interface_property ctrl associatedClock clock
set_interface_property ctrl associatedReset reset
set_interface_property ctrl dataBitsPerSymbol $RUN_CONTROL_WIDTH_CONST
set_interface_property ctrl errorDescriptor ""
set_interface_property ctrl firstSymbolInHighOrderBits true
set_interface_property ctrl maxChannel 0
set_interface_property ctrl readyLatency 0
set_interface_property ctrl ENABLED true
add_interface_port ctrl asi_ctrl_data data Input $RUN_CONTROL_WIDTH_CONST
add_interface_port ctrl asi_ctrl_valid valid Input 1
add_interface_port ctrl asi_ctrl_ready ready Output 1

add_interface hist_fill_in avalon_streaming end
set_interface_property hist_fill_in associatedClock clock
set_interface_property hist_fill_in associatedReset reset
set_interface_property hist_fill_in dataBitsPerSymbol AVST_DATA_WIDTH
set_interface_property hist_fill_in maxChannel 15
set_interface_property hist_fill_in readyLatency 0
set_interface_property hist_fill_in ENABLED true
add_interface_port hist_fill_in asi_hist_fill_in_valid valid Input 1
add_interface_port hist_fill_in asi_hist_fill_in_ready ready Output 1
add_interface_port hist_fill_in asi_hist_fill_in_data data Input AVST_DATA_WIDTH
add_interface_port hist_fill_in asi_hist_fill_in_startofpacket startofpacket Input 1
add_interface_port hist_fill_in asi_hist_fill_in_endofpacket endofpacket Input 1
add_interface_port hist_fill_in asi_hist_fill_in_channel channel Input AVST_CHANNEL_WIDTH

for {set idx 1} {$idx <= 7} {incr idx} {
    set ifname "fill_in_${idx}"
    add_interface $ifname avalon_streaming end
    set_interface_property $ifname associatedClock clock
    set_interface_property $ifname associatedReset reset
    set_interface_property $ifname dataBitsPerSymbol AVST_DATA_WIDTH
    set_interface_property $ifname maxChannel 15
    set_interface_property $ifname readyLatency 0
    set_interface_property $ifname ENABLED true
    add_interface_port $ifname "asi_${ifname}_valid" valid Input 1
    add_interface_port $ifname "asi_${ifname}_ready" ready Output 1
    add_interface_port $ifname "asi_${ifname}_data" data Input AVST_DATA_WIDTH
    add_interface_port $ifname "asi_${ifname}_startofpacket" startofpacket Input 1
    add_interface_port $ifname "asi_${ifname}_endofpacket" endofpacket Input 1
    add_interface_port $ifname "asi_${ifname}_channel" channel Input AVST_CHANNEL_WIDTH
}

add_interface fill_out avalon_streaming start
set_interface_property fill_out associatedClock clock
set_interface_property fill_out associatedReset reset
set_interface_property fill_out dataBitsPerSymbol AVST_DATA_WIDTH
set_interface_property fill_out maxChannel 15
set_interface_property fill_out readyLatency 0
set_interface_property fill_out ENABLED true
add_interface_port fill_out aso_hist_fill_out_valid valid Output 1
add_interface_port fill_out aso_hist_fill_out_ready ready Input 1
add_interface_port fill_out aso_hist_fill_out_data data Output AVST_DATA_WIDTH
add_interface_port fill_out aso_hist_fill_out_startofpacket startofpacket Output 1
add_interface_port fill_out aso_hist_fill_out_endofpacket endofpacket Output 1
add_interface_port fill_out aso_hist_fill_out_channel channel Output AVST_CHANNEL_WIDTH

for {set idx 1} {$idx <= 6} {incr idx} {
    set ifname "debug_${idx}"
    add_interface $ifname avalon_streaming end
    set_interface_property $ifname associatedClock clock
    set_interface_property $ifname associatedReset reset
    set_interface_property $ifname dataBitsPerSymbol 16
    set_interface_property $ifname readyLatency 0
    set_interface_property $ifname ENABLED true
    add_interface_port $ifname "asi_${ifname}_valid" valid Input 1
    add_interface_port $ifname "asi_${ifname}_data" data Input 16
}

# Presets are provided via the sibling .qprs file:
#   histogram_statistics_v2_presets.qprs

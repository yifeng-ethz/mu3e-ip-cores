-- File name: histogram_statistics_v2.vhd
-- Author: Yifeng Wang (yifenwan@phys.ethz.ch)
-- =======================================
-- Revision: 1.4
--		Date: Apr 27, 2026
--		Change: Replicate configurable filter fields per ingress port
--		        so the hot-path match logic is not driven by one
--		        high-fanout shared CSR/config source.
-- Revision: 1.3
--		Date: Apr 25, 2026
--		Change: Parameterize the ingress FIFO depth for bursty post-stack
--		        taps and saturate the 8-bit PORT_STATUS max-level field
--		        instead of truncating full FIFO levels to zero.
-- Revision: 1.2
--		Date: Apr 9, 2026
--		Change: Decouple build_key from filter_pass_v gating in ingress_comb
--		        to break cfg_filter_key_low → ingress_stage_key timing path
--		        (-2.554 ns at 137.5 MHz standalone). Key is always computed;
--		        only write_req is gated by filter result.
-- Revision: 1.1
--		Date: Apr 9, 2026
--		Change: Register measure_clear_pulse to break timing path from
--		        AVMM interconnect address decode to queue_hit_bin
--		        (-0.472 ns violation at 125 MHz pll_sclk domain).
-- Revision: 1.0 (file created)
--		Date: Mar 20, 2026
-- =========
-- Description:	[Histogram Statistics v2 top-level]
--
--			Multi-port online histogram with configurable bins, coalescing queue,
--			and ping-pong readout.  Accepts up to 8 Avalon-ST input ports, extracts
--			a configurable key field, maps keys to bin indices via bin_divider,
--			coalesces concurrent updates in a queue, and stores counts in dual-bank
--			M10K SRAM with automatic interval-based bank swap.
--
--			Data path:
--				ingress -> hit_fifo (per port) -> rr_arbiter -> bin_divider
--				-> coalescing_queue -> pingpong_sram
--
--			Control:
--				AVMM CSR slave for run-time configuration (bounds, bin width, filter).
--				AVMM hist_bin slave for host readout of histogram bins.
--

-- ================ synthsizer configuration ===================
-- altera vhdl_input_version vhdl_2008
-- =============================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.histogram_statistics_v2_pkg.all;

entity histogram_statistics_v2 is
    generic (
        UPDATE_KEY_BIT_HI        : natural := 29;
        UPDATE_KEY_BIT_LO        : natural := 17;
        UPDATE_KEY_REPRESENTATION: string  := "UNSIGNED";
        FILTER_KEY_BIT_HI        : natural := 38;
        FILTER_KEY_BIT_LO        : natural := 35;
        SAR_TICK_WIDTH           : natural := 32;
        SAR_KEY_WIDTH            : natural := 16;
        N_BINS                   : natural := 256;
        MAX_COUNT_BITS           : natural := 32;
        DEF_LEFT_BOUND           : integer := -1000;
        DEF_BIN_WIDTH            : natural := 16;
        AVS_ADDR_WIDTH           : natural := 8;
        N_PORTS                  : natural := 8;
        FIFO_ADDR_WIDTH          : natural := 8;
        CHANNELS_PER_PORT        : natural := 32;
        COAL_QUEUE_DEPTH         : natural := 256;
        ENABLE_PINGPONG          : boolean := true;
        DEF_INTERVAL_CLOCKS      : natural := 125000000;
        AVST_DATA_WIDTH          : natural := 39;
        AVST_CHANNEL_WIDTH       : natural := 4;
        N_DEBUG_INTERFACE        : natural := 6;
        VERSION_MAJOR            : natural := 26;
        VERSION_MINOR            : natural := 1;
        VERSION_PATCH            : natural := 2;
        BUILD                    : natural := 425;
        IP_UID                   : natural := 1212765012;  -- ASCII "HIST" = 0x48495354
        VERSION_DATE             : natural := 20260425;
        VERSION_GIT              : natural := 1929539473;
        INSTANCE_ID              : natural := 0;
        SNOOP_EN                 : boolean := true;
        ENABLE_PACKET            : boolean := true;
        DEBUG                    : natural := 0
    );
    port (
        avs_hist_bin_readdata           : out std_logic_vector(31 downto 0);
        avs_hist_bin_read               : in  std_logic;
        avs_hist_bin_address            : in  std_logic_vector(AVS_ADDR_WIDTH - 1 downto 0);
        avs_hist_bin_waitrequest        : out std_logic;
        avs_hist_bin_write              : in  std_logic;
        avs_hist_bin_writedata          : in  std_logic_vector(31 downto 0);
        avs_hist_bin_burstcount         : in  std_logic_vector(AVS_ADDR_WIDTH downto 0);
        avs_hist_bin_readdatavalid      : out std_logic;
        avs_hist_bin_writeresponsevalid : out std_logic;
        avs_hist_bin_response           : out std_logic_vector(1 downto 0);

        avs_csr_readdata                : out std_logic_vector(31 downto 0);
        avs_csr_read                    : in  std_logic;
        avs_csr_address                 : in  std_logic_vector(4 downto 0);
        avs_csr_waitrequest             : out std_logic;
        avs_csr_write                   : in  std_logic;
        avs_csr_writedata               : in  std_logic_vector(31 downto 0);

        asi_hist_fill_in_ready          : out std_logic;
        asi_hist_fill_in_valid          : in  std_logic;
        asi_hist_fill_in_data           : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_hist_fill_in_startofpacket  : in  std_logic;
        asi_hist_fill_in_endofpacket    : in  std_logic;
        asi_hist_fill_in_channel        : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_1_ready             : out std_logic;
        asi_fill_in_1_valid             : in  std_logic;
        asi_fill_in_1_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_1_startofpacket     : in  std_logic;
        asi_fill_in_1_endofpacket       : in  std_logic;
        asi_fill_in_1_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_2_ready             : out std_logic;
        asi_fill_in_2_valid             : in  std_logic;
        asi_fill_in_2_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_2_startofpacket     : in  std_logic;
        asi_fill_in_2_endofpacket       : in  std_logic;
        asi_fill_in_2_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_3_ready             : out std_logic;
        asi_fill_in_3_valid             : in  std_logic;
        asi_fill_in_3_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_3_startofpacket     : in  std_logic;
        asi_fill_in_3_endofpacket       : in  std_logic;
        asi_fill_in_3_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_4_ready             : out std_logic;
        asi_fill_in_4_valid             : in  std_logic;
        asi_fill_in_4_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_4_startofpacket     : in  std_logic;
        asi_fill_in_4_endofpacket       : in  std_logic;
        asi_fill_in_4_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_5_ready             : out std_logic;
        asi_fill_in_5_valid             : in  std_logic;
        asi_fill_in_5_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_5_startofpacket     : in  std_logic;
        asi_fill_in_5_endofpacket       : in  std_logic;
        asi_fill_in_5_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_6_ready             : out std_logic;
        asi_fill_in_6_valid             : in  std_logic;
        asi_fill_in_6_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_6_startofpacket     : in  std_logic;
        asi_fill_in_6_endofpacket       : in  std_logic;
        asi_fill_in_6_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_fill_in_7_ready             : out std_logic;
        asi_fill_in_7_valid             : in  std_logic;
        asi_fill_in_7_data              : in  std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        asi_fill_in_7_startofpacket     : in  std_logic;
        asi_fill_in_7_endofpacket       : in  std_logic;
        asi_fill_in_7_channel           : in  std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        aso_hist_fill_out_ready         : in  std_logic := '1';
        aso_hist_fill_out_valid         : out std_logic;
        aso_hist_fill_out_data          : out std_logic_vector(AVST_DATA_WIDTH - 1 downto 0);
        aso_hist_fill_out_startofpacket : out std_logic;
        aso_hist_fill_out_endofpacket   : out std_logic;
        aso_hist_fill_out_channel       : out std_logic_vector(AVST_CHANNEL_WIDTH - 1 downto 0);

        asi_ctrl_data                   : in  std_logic_vector(8 downto 0);
        asi_ctrl_valid                  : in  std_logic;
        asi_ctrl_ready                  : out std_logic;

        asi_debug_1_valid               : in  std_logic;
        asi_debug_1_data                : in  std_logic_vector(15 downto 0);
        asi_debug_2_valid               : in  std_logic;
        asi_debug_2_data                : in  std_logic_vector(15 downto 0);
        asi_debug_3_valid               : in  std_logic;
        asi_debug_3_data                : in  std_logic_vector(15 downto 0);
        asi_debug_4_valid               : in  std_logic;
        asi_debug_4_data                : in  std_logic_vector(15 downto 0);
        asi_debug_5_valid               : in  std_logic;
        asi_debug_5_data                : in  std_logic_vector(15 downto 0);
        asi_debug_6_valid               : in  std_logic;
        asi_debug_6_data                : in  std_logic_vector(15 downto 0);

        i_interval_reset                : in  std_logic := '0';
        i_rst                           : in  std_logic;
        i_clk                           : in  std_logic
    );
end entity histogram_statistics_v2;

architecture rtl of histogram_statistics_v2 is

    constant MAX_PORTS_CONST        : natural := HS_MAX_PORTS_CONST;
    -- Keep the ingress queue deep enough that bursty measurement traffic
    -- does not get dropped before it reaches the divider/coalescer.
    constant FIFO_ADDR_WIDTH_CONST  : natural := FIFO_ADDR_WIDTH;
    constant BIN_INDEX_WIDTH_CONST  : natural := clog2(N_BINS);
    constant KICK_WIDTH_CONST       : natural := 8;
    constant COUNT_WIDTH_CONST      : natural := MAX_COUNT_BITS;
    constant PORT_WIDTH_CONST       : natural := clog2(MAX_PORTS_CONST);

    subtype tick_t      is signed(SAR_TICK_WIDTH - 1 downto 0);
    subtype tick_slv_t  is std_logic_vector(SAR_TICK_WIDTH - 1 downto 0);
    subtype fifo_level_t is unsigned(FIFO_ADDR_WIDTH_CONST downto 0);
    subtype port_index_t is unsigned(PORT_WIDTH_CONST - 1 downto 0);
    subtype bin_index_t is unsigned(BIN_INDEX_WIDTH_CONST - 1 downto 0);
    subtype status_byte_t is unsigned(7 downto 0);
    type status_pair_max_array_t is array (0 to (MAX_PORTS_CONST / 2) - 1) of status_byte_t;

    signal port_valid     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal port_data      : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(AVST_DATA_WIDTH - 1 downto 0);
    signal port_channel   : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(AVST_CHANNEL_WIDTH - 1 downto 0);
    signal port_ready     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal ingress_accept : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_write_req : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_key_next : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(SAR_TICK_WIDTH - 1 downto 0);
    signal ingress_stage_valid : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_stage_write_req : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal ingress_stage_key : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(SAR_TICK_WIDTH - 1 downto 0);
    signal fifo_write     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_read      : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_empty     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_full      : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal fifo_level     : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(FIFO_ADDR_WIDTH_CONST downto 0);
    signal fifo_level_max : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(FIFO_ADDR_WIDTH_CONST downto 0);
    signal fifo_rd_data   : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(SAR_TICK_WIDTH - 1 downto 0);
    signal fifo_wr_data   : hs_slv_array_t(0 to MAX_PORTS_CONST - 1)(SAR_TICK_WIDTH - 1 downto 0);
    signal accept_pulse   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal drop_pulse     : std_logic_vector(MAX_PORTS_CONST - 1 downto 0);
    signal accept_stat_pulse_d1 : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal drop_stat_pulse_d1   : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal divider_stat_valid_d1     : std_logic := '0';
    signal divider_stat_underflow_d1 : std_logic := '0';
    signal divider_stat_overflow_d1  : std_logic := '0';
    signal stats_reset_pulse_d1      : std_logic := '0';

    signal arb_valid      : std_logic;
    signal arb_port       : port_index_t;
    signal arb_key_data   : std_logic_vector(SAR_TICK_WIDTH - 1 downto 0);
    signal arb_pipe_valid    : std_logic := '0';
    signal arb_pipe_port     : port_index_t := (others => '0');
    signal arb_pipe_key      : std_logic_vector(SAR_TICK_WIDTH - 1 downto 0) := (others => '0');
    signal key_pipe_valid    : std_logic := '0';
    signal key_pipe          : tick_t := (others => '0');
    signal key_pipe_count    : unsigned(KICK_WIDTH_CONST - 1 downto 0) := (others => '0');
    signal divider_in_valid  : std_logic := '0';
    signal divider_in_key    : tick_t := (others => '0');
    signal divider_in_count  : unsigned(KICK_WIDTH_CONST - 1 downto 0) := (others => '0');

    signal divider_valid      : std_logic;
    signal divider_underflow  : std_logic;
    signal divider_overflow   : std_logic;
    signal divider_bin_index  : bin_index_t;
    signal divider_count      : unsigned(KICK_WIDTH_CONST - 1 downto 0);
    signal queue_hit_valid    : std_logic := '0';
    signal queue_hit_bin      : bin_index_t := (others => '0');

    signal queue_drain_valid    : std_logic;
    signal queue_drain_bin      : bin_index_t;
    signal queue_drain_count    : unsigned(KICK_WIDTH_CONST - 1 downto 0);
    signal queue_drain_ready    : std_logic;
    signal queue_occupancy      : unsigned(clog2(COAL_QUEUE_DEPTH + 1) - 1 downto 0);
    signal queue_occupancy_max  : unsigned(clog2(COAL_QUEUE_DEPTH + 1) - 1 downto 0);
    signal queue_overflow_count : unsigned(15 downto 0);

    signal hist_readdata        : std_logic_vector(31 downto 0);
    signal hist_readdatavalid   : std_logic;
    signal hist_writeresp_valid : std_logic := '0';
    signal active_bank          : std_logic;
    signal flushing             : std_logic;
    signal flush_addr           : bin_index_t;
    signal interval_pulse       : std_logic;
    signal clear_pulse          : std_logic;
    signal measure_clear_comb   : std_logic;
    signal measure_clear_pulse  : std_logic := '0';

    signal csr_mode             : std_logic_vector(3 downto 0) := (others => '0');
    signal csr_key_unsigned     : std_logic := bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
    signal csr_filter_enable    : std_logic := '0';
    signal csr_filter_reject    : std_logic := '0';
    signal csr_error            : std_logic := '0';
    signal csr_error_info       : std_logic_vector(3 downto 0) := (others => '0');
    signal csr_left_bound       : tick_t := to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
    signal csr_right_bound      : tick_t := to_signed(DEF_LEFT_BOUND + integer(DEF_BIN_WIDTH) * integer(N_BINS), SAR_TICK_WIDTH);
    signal csr_bin_width        : unsigned(15 downto 0) := to_unsigned(DEF_BIN_WIDTH, 16);
    signal csr_update_key_low   : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_LO, 8);
    signal csr_update_key_high  : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_HI, 8);
    signal csr_filter_key_low   : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_LO, 8);
    signal csr_filter_key_high  : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_HI, 8);
    signal csr_update_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal csr_filter_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal csr_underflow_count  : unsigned(31 downto 0) := (others => '0');
    signal csr_overflow_count   : unsigned(31 downto 0) := (others => '0');
    signal csr_total_hits       : unsigned(31 downto 0) := (others => '0');
    signal csr_dropped_hits     : unsigned(31 downto 0) := (others => '0');
    signal csr_interval_cfg     : unsigned(31 downto 0) := to_unsigned(DEF_INTERVAL_CLOCKS, 32);
    signal csr_scratch          : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_meta_sel         : std_logic_vector(1 downto 0)  := (others => '0');
    signal csr_bank_status      : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_port_status      : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_coal_status      : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_readdata_mux     : std_logic_vector(31 downto 0) := (others => '0');
    signal csr_readdata_reg     : std_logic_vector(31 downto 0) := (others => '0');
    signal cfg_apply_request    : std_logic := '0';
    signal cfg_apply_pending    : std_logic := '0';
    signal cfg_mode             : std_logic_vector(3 downto 0) := (others => '0');
    signal cfg_key_unsigned     : std_logic := bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
    signal cfg_filter_enable    : std_logic := '0';
    signal cfg_filter_reject    : std_logic := '0';
    signal cfg_left_bound       : tick_t := to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
    signal cfg_right_bound      : tick_t := to_signed(DEF_LEFT_BOUND + integer(DEF_BIN_WIDTH) * integer(N_BINS), SAR_TICK_WIDTH);
    signal cfg_bin_width        : unsigned(15 downto 0) := to_unsigned(DEF_BIN_WIDTH, 16);
    signal cfg_update_key_low   : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_LO, 8);
    signal cfg_update_key_high  : unsigned(7 downto 0) := to_unsigned(UPDATE_KEY_BIT_HI, 8);
    signal cfg_filter_key_low   : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_LO, 8);
    signal cfg_filter_key_high  : unsigned(7 downto 0) := to_unsigned(FILTER_KEY_BIT_HI, 8);
    signal cfg_update_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal cfg_filter_key       : unsigned(SAR_KEY_WIDTH - 1 downto 0) := (others => '0');
    signal cfg_interval_cfg     : unsigned(31 downto 0) := to_unsigned(DEF_INTERVAL_CLOCKS, 32);
    signal cfg_filter_enable_port  : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal cfg_filter_reject_port  : std_logic_vector(MAX_PORTS_CONST - 1 downto 0) := (others => '0');
    signal cfg_filter_key_low_port : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(FILTER_KEY_BIT_LO, 8));
    signal cfg_filter_key_high_port: hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(7 downto 0) := (others => to_unsigned(FILTER_KEY_BIT_HI, 8));
    signal cfg_filter_key_port     : hs_unsigned_array_t(0 to MAX_PORTS_CONST - 1)(SAR_KEY_WIDTH - 1 downto 0) := (others => (others => '0'));

    signal status_active_bank_shadow        : std_logic := '0';
    signal status_flushing_shadow           : std_logic := '0';
    signal status_flush_addr_shadow         : std_logic_vector(7 downto 0) := (others => '0');
    signal status_fifo_empty_shadow         : std_logic_vector(7 downto 0) := (others => '1');
    signal status_fifo_pair_max_shadow      : status_pair_max_array_t := (others => (others => '0'));
    signal status_queue_occupancy_shadow    : status_byte_t := (others => '0');
    signal status_queue_occupancy_max_shadow : status_byte_t := (others => '0');
    signal status_queue_overflow_shadow     : unsigned(15 downto 0) := (others => '0');

    attribute preserve : boolean;
    attribute preserve of arb_pipe_valid   : signal is true;
    attribute preserve of arb_pipe_port    : signal is true;
    attribute preserve of arb_pipe_key     : signal is true;
    attribute preserve of key_pipe_valid   : signal is true;
    attribute preserve of key_pipe         : signal is true;
    attribute preserve of key_pipe_count   : signal is true;
    attribute preserve of divider_in_valid : signal is true;
    attribute preserve of divider_in_key   : signal is true;
    attribute preserve of divider_in_count : signal is true;

    function match_filter(
        data_word       : std_logic_vector;
        filter_enable   : std_logic;
        filter_reject   : std_logic;
        filter_hi       : unsigned(7 downto 0);
        filter_lo       : unsigned(7 downto 0);
        filter_key      : unsigned
    ) return boolean is
        variable field_v : unsigned(filter_key'range);
        variable match_v : boolean;
    begin
        if filter_enable = '0' then
            return true;
        end if;
        field_v := resize(
            extract_unsigned(data_word, to_integer(filter_hi), to_integer(filter_lo)),
            filter_key'length
        );
        match_v := field_v = filter_key;
        if filter_reject = '1' then
            return not match_v;
        end if;
        return match_v;
    end function match_filter;

    function build_key(
        data_word    : std_logic_vector;
        key_hi       : unsigned(7 downto 0);
        key_lo       : unsigned(7 downto 0);
        key_unsigned : std_logic
    ) return std_logic_vector is
        variable result_v : tick_t := (others => '0');
        variable raw_u_v  : unsigned(SAR_KEY_WIDTH - 1 downto 0);
        variable raw_s_v  : signed(SAR_KEY_WIDTH - 1 downto 0);
    begin
        if key_unsigned = '1' then
            raw_u_v  := resize(
                extract_unsigned(data_word, to_integer(key_hi), to_integer(key_lo)),
                SAR_KEY_WIDTH
            );
            result_v := signed(resize(raw_u_v, SAR_TICK_WIDTH));
        else
            raw_s_v  := resize(
                extract_signed(data_word, to_integer(key_hi), to_integer(key_lo)),
                SAR_KEY_WIDTH
            );
            result_v := resize(raw_s_v, SAR_TICK_WIDTH);
        end if;
        return std_logic_vector(result_v);
    end function build_key;

    function build_debug_key(
        debug_mode : integer;
        data_word  : std_logic_vector(15 downto 0)
    ) return std_logic_vector is
        variable result_v : tick_t := (others => '0');
    begin
        case debug_mode is
            when -1 =>
                result_v := resize(signed(data_word), SAR_TICK_WIDTH);
            when others =>
                result_v := signed(resize(unsigned(data_word), SAR_TICK_WIDTH));
        end case;
        return std_logic_vector(result_v);
    end function build_debug_key;

    function clip_status_byte_f(
        value_in : unsigned
    ) return status_byte_t is
        variable clipped_v : status_byte_t := (others => '0');
    begin
        if value_in'length > status_byte_t'length then
            if value_in(value_in'left downto status_byte_t'length) /= 0 then
                clipped_v := (others => '1');
            else
                clipped_v := resize(value_in, status_byte_t'length);
            end if;
        else
            clipped_v := resize(value_in, status_byte_t'length);
        end if;
        return clipped_v;
    end function clip_status_byte_f;

begin

    port_valid(0) <= asi_hist_fill_in_valid;
    port_valid(1) <= asi_fill_in_1_valid;
    port_valid(2) <= asi_fill_in_2_valid;
    port_valid(3) <= asi_fill_in_3_valid;
    port_valid(4) <= asi_fill_in_4_valid;
    port_valid(5) <= asi_fill_in_5_valid;
    port_valid(6) <= asi_fill_in_6_valid;
    port_valid(7) <= asi_fill_in_7_valid;

    port_data(0) <= asi_hist_fill_in_data;
    port_data(1) <= asi_fill_in_1_data;
    port_data(2) <= asi_fill_in_2_data;
    port_data(3) <= asi_fill_in_3_data;
    port_data(4) <= asi_fill_in_4_data;
    port_data(5) <= asi_fill_in_5_data;
    port_data(6) <= asi_fill_in_6_data;
    port_data(7) <= asi_fill_in_7_data;

    port_channel(0) <= asi_hist_fill_in_channel;
    port_channel(1) <= asi_fill_in_1_channel;
    port_channel(2) <= asi_fill_in_2_channel;
    port_channel(3) <= asi_fill_in_3_channel;
    port_channel(4) <= asi_fill_in_4_channel;
    port_channel(5) <= asi_fill_in_5_channel;
    port_channel(6) <= asi_fill_in_6_channel;
    port_channel(7) <= asi_fill_in_7_channel;

    asi_hist_fill_in_ready <= port_ready(0);
    asi_fill_in_1_ready    <= port_ready(1);
    asi_fill_in_2_ready    <= port_ready(2);
    asi_fill_in_3_ready    <= port_ready(3);
    asi_fill_in_4_ready    <= port_ready(4);
    asi_fill_in_5_ready    <= port_ready(5);
    asi_fill_in_6_ready    <= port_ready(6);
    asi_fill_in_7_ready    <= port_ready(7);

    aso_hist_fill_out_valid         <= asi_hist_fill_in_valid when SNOOP_EN else '0';
    aso_hist_fill_out_data          <= asi_hist_fill_in_data when SNOOP_EN else (others => '0');
    aso_hist_fill_out_startofpacket <= asi_hist_fill_in_startofpacket when (SNOOP_EN and ENABLE_PACKET) else '0';
    aso_hist_fill_out_endofpacket   <= asi_hist_fill_in_endofpacket when (SNOOP_EN and ENABLE_PACKET) else '0';
    aso_hist_fill_out_channel       <= asi_hist_fill_in_channel when SNOOP_EN else (others => '0');

    asi_ctrl_ready <= '1';
    avs_hist_bin_waitrequest        <= '0';
    avs_hist_bin_writeresponsevalid <= hist_writeresp_valid;
    avs_hist_bin_response           <= (others => '0');
    avs_csr_waitrequest             <= '0';
    avs_hist_bin_readdata           <= hist_readdata;
    avs_hist_bin_readdatavalid      <= hist_readdatavalid;
    avs_csr_readdata                <= csr_readdata_reg;

    clear_pulse        <= bool_to_sl((avs_hist_bin_write = '1') and (avs_hist_bin_writedata = x"00000000"));
    measure_clear_comb <= clear_pulse or i_interval_reset;

    -- register measure_clear to break timing from AVMM interconnect address decode
    measure_clear_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            measure_clear_pulse <= measure_clear_comb;
        end if;
    end process measure_clear_reg;

    hist_writeresp_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                hist_writeresp_valid <= '0';
            else
                hist_writeresp_valid <= avs_hist_bin_write;
            end if;
        end if;
    end process hist_writeresp_reg;

    ingress_comb : process (all)
        variable sampled_v         : std_logic;
        variable stream_ready_v    : std_logic;
        variable stream_sampled_v  : std_logic;
        variable filter_pass_v     : boolean;
        variable debug_mode_v      : integer;
        variable debug_valid_v     : std_logic;
        variable debug_data_v      : std_logic_vector(15 downto 0);
    begin
        fifo_write        <= (others => '0');
        fifo_wr_data      <= (others => (others => '0'));
        accept_pulse      <= (others => '0');
        drop_pulse        <= (others => '0');
        port_ready        <= (others => '0');
        ingress_accept    <= (others => '0');
        ingress_write_req <= (others => '0');
        ingress_key_next  <= (others => (others => '0'));
        debug_mode_v := to_integer(signed(cfg_mode));
        debug_valid_v := '0';
        debug_data_v  := (others => '0');

        case debug_mode_v is
            when -1 =>
                debug_valid_v := asi_debug_1_valid;
                debug_data_v  := asi_debug_1_data;
            when -2 =>
                debug_valid_v := asi_debug_2_valid;
                debug_data_v  := asi_debug_2_data;
            when -3 =>
                debug_valid_v := asi_debug_3_valid;
                debug_data_v  := asi_debug_3_data;
            when -4 =>
                debug_valid_v := asi_debug_4_valid;
                debug_data_v  := asi_debug_4_data;
            when -5 =>
                debug_valid_v := asi_debug_5_valid;
                debug_data_v  := asi_debug_5_data;
            when -6 =>
                debug_valid_v := asi_debug_6_valid;
                debug_data_v  := asi_debug_6_data;
            when others =>
                null;
        end case;

        for idx in 0 to MAX_PORTS_CONST - 1 loop
            if idx < N_PORTS then
                stream_ready_v   := '0';
                stream_sampled_v := '0';
                if cfg_apply_pending = '0' then
                    if idx = 0 then
                        if SNOOP_EN then
                            stream_ready_v   := aso_hist_fill_out_ready;
                            stream_sampled_v := port_valid(idx) and aso_hist_fill_out_ready;
                        else
                            -- No-snoop mode disables the passthrough path, so ingress stays locally ready.
                            stream_ready_v   := '1';
                            stream_sampled_v := port_valid(idx);
                        end if;
                    else
                        stream_ready_v   := '1';
                        stream_sampled_v := port_valid(idx);
                    end if;
                end if;
                port_ready(idx) <= stream_ready_v;

                sampled_v := stream_sampled_v;
                if debug_mode_v < 0 then
                    if idx = 0 then
                        sampled_v := debug_valid_v and not cfg_apply_pending;
                    else
                        sampled_v := '0';
                    end if;
                end if;

                accept_pulse(idx)   <= sampled_v;
                ingress_accept(idx) <= sampled_v;

                if sampled_v = '1' then
                    if debug_mode_v < 0 then
                        ingress_write_req(idx) <= '1';
                        ingress_key_next(idx) <= build_debug_key(
                            debug_mode => debug_mode_v,
                            data_word  => debug_data_v
                        );
                    else
                        -- Compute key unconditionally (don't gate by filter_pass)
                        -- to break timing from cfg_filter_key_low → ingress_stage_key.
                        -- Key value is don't-care when write_req = '0'.
                        ingress_key_next(idx) <= build_key(
                            data_word    => port_data(idx),
                            key_hi       => cfg_update_key_high,
                            key_lo       => cfg_update_key_low,
                            key_unsigned => cfg_key_unsigned
                        );

                        filter_pass_v := match_filter(
                            data_word      => port_data(idx),
                            filter_enable  => cfg_filter_enable_port(idx),
                            filter_reject  => cfg_filter_reject_port(idx),
                            filter_hi      => cfg_filter_key_high_port(idx),
                            filter_lo      => cfg_filter_key_low_port(idx),
                            filter_key     => cfg_filter_key_port(idx)
                        );
                        if filter_pass_v then
                            ingress_write_req(idx) <= '1';
                        end if;
                    end if;
                end if;
            end if;

            if ingress_stage_valid(idx) = '1' then
                if ingress_stage_write_req(idx) = '1' then
                    if fifo_full(idx) = '0' then
                        fifo_write(idx)   <= '1';
                        fifo_wr_data(idx) <= ingress_stage_key(idx);
                    else
                        drop_pulse(idx) <= '1';
                    end if;
                end if;
            end if;
        end loop;
    end process ingress_comb;

    ingress_stage_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or measure_clear_pulse = '1' then
                ingress_stage_valid     <= (others => '0');
                ingress_stage_write_req <= (others => '0');
                ingress_stage_key       <= (others => (others => '0'));
            else
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if ingress_stage_valid(idx) = '1' then
                        ingress_stage_valid(idx)     <= '0';
                        ingress_stage_write_req(idx) <= '0';
                        ingress_stage_key(idx)       <= (others => '0');
                    end if;

                    if (idx < N_PORTS) and (ingress_accept(idx) = '1') then
                        ingress_stage_valid(idx)     <= '1';
                        ingress_stage_write_req(idx) <= ingress_write_req(idx);
                        ingress_stage_key(idx)       <= ingress_key_next(idx);
                    end if;
                end loop;
            end if;
        end if;
    end process ingress_stage_reg;

    fifo_gen : for idx in 0 to MAX_PORTS_CONST - 1 generate
        fifo_inst : entity work.hit_fifo
            generic map (
                DATA_WIDTH      => SAR_TICK_WIDTH,
                FIFO_ADDR_WIDTH => FIFO_ADDR_WIDTH_CONST
            )
            port map (
                i_clk        => i_clk,
                i_rst        => i_rst,
                i_clear      => measure_clear_pulse,
                i_write      => fifo_write(idx),
                i_write_data => fifo_wr_data(idx),
                i_read       => fifo_read(idx),
                o_read_data  => fifo_rd_data(idx),
                o_empty      => fifo_empty(idx),
                o_full       => fifo_full(idx),
                o_level      => fifo_level(idx),
                o_level_max  => fifo_level_max(idx)
            );
    end generate fifo_gen;

    arb_inst : entity work.rr_arbiter
        generic map (
            N_PORTS    => MAX_PORTS_CONST,
            DATA_WIDTH => SAR_TICK_WIDTH
        )
        port map (
            i_clk        => i_clk,
            i_rst        => i_rst,
            i_clear      => measure_clear_pulse,
            i_sink_ready => '1',
            i_fifo_valid => not fifo_empty,
            i_fifo_data  => fifo_rd_data,
            o_fifo_pop   => fifo_read,
            o_out_valid  => arb_valid,
            o_out_port   => arb_port,
            o_out_data   => arb_key_data
        );

    divider_pipe : process (i_clk)
        variable port_offset_v : tick_t;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' or measure_clear_pulse = '1' then
                arb_pipe_valid <= '0';
                arb_pipe_port  <= (others => '0');
                arb_pipe_key   <= (others => '0');
                key_pipe_valid <= '0';
                key_pipe       <= (others => '0');
                key_pipe_count <= (others => '0');
                divider_in_valid <= '0';
                divider_in_key   <= (others => '0');
                divider_in_count <= (others => '0');
            else
                arb_pipe_valid <= arb_valid;
                arb_pipe_port  <= arb_port;
                arb_pipe_key   <= arb_key_data;

                key_pipe_valid <= arb_pipe_valid;
                key_pipe_count <= (others => '0');
                key_pipe       <= (others => '0');

                if arb_pipe_valid = '1' then
                    port_offset_v := to_signed(to_integer(arb_pipe_port) * CHANNELS_PER_PORT, SAR_TICK_WIDTH);
                    key_pipe      <= signed(arb_pipe_key) + port_offset_v;
                    key_pipe_count <= to_unsigned(1, KICK_WIDTH_CONST);
                end if;

                divider_in_valid <= key_pipe_valid;
                divider_in_key   <= key_pipe;
                divider_in_count <= key_pipe_count;
            end if;
        end if;
    end process divider_pipe;

    divider_inst : entity work.bin_divider
        generic map (
            TICK_WIDTH      => SAR_TICK_WIDTH,
            BIN_INDEX_WIDTH => BIN_INDEX_WIDTH_CONST,
            COUNT_WIDTH     => KICK_WIDTH_CONST
        )
        port map (
            i_clk         => i_clk,
            i_rst         => i_rst,
            i_clear       => measure_clear_pulse,
            i_valid       => divider_in_valid,
            i_key         => divider_in_key,
            i_count       => divider_in_count,
            i_left_bound  => cfg_left_bound,
            i_right_bound => cfg_right_bound,
            i_bin_width   => resize(cfg_bin_width, SAR_TICK_WIDTH),
            o_valid       => divider_valid,
            o_underflow   => divider_underflow,
            o_overflow    => divider_overflow,
            o_bin_index   => divider_bin_index,
            o_count       => divider_count
        );

    queue_hit_pipe : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if (i_rst = '1') or (measure_clear_pulse = '1') then
                queue_hit_valid <= '0';
                queue_hit_bin   <= (others => '0');
            else
                queue_hit_valid <= divider_valid and not divider_underflow and not divider_overflow;
                queue_hit_bin   <= divider_bin_index;
            end if;
        end if;
    end process queue_hit_pipe;

    queue_inst : entity work.coalescing_queue
        generic map (
            N_BINS         => N_BINS,
            QUEUE_DEPTH    => COAL_QUEUE_DEPTH,
            KICK_WIDTH     => KICK_WIDTH_CONST,
            OVERFLOW_WIDTH => 16
        )
        port map (
            i_clk            => i_clk,
            i_rst            => i_rst,
            i_clear          => measure_clear_pulse,
            i_hit_valid      => queue_hit_valid,
            i_hit_bin        => queue_hit_bin,
            i_drain_ready    => queue_drain_ready,
            o_drain_valid    => queue_drain_valid,
            o_drain_bin      => queue_drain_bin,
            o_drain_count    => queue_drain_count,
            o_occupancy      => queue_occupancy,
            o_occupancy_max  => queue_occupancy_max,
            o_overflow_count => queue_overflow_count
        );

    pingpong_inst : entity work.pingpong_sram
        generic map (
            N_BINS       => N_BINS,
            COUNT_WIDTH  => COUNT_WIDTH_CONST,
            UPDATE_WIDTH => KICK_WIDTH_CONST
        )
        port map (
            i_clk               => i_clk,
            i_rst               => i_rst,
            i_clear             => measure_clear_pulse,
            i_enable_pingpong   => bool_to_sl(ENABLE_PINGPONG),
            i_interval_clocks   => cfg_interval_cfg,
            i_upd_valid         => queue_drain_valid,
            i_upd_bin           => queue_drain_bin,
            i_upd_count         => queue_drain_count,
            o_upd_ready         => queue_drain_ready,
            i_hist_read         => avs_hist_bin_read,
            i_hist_address      => unsigned(avs_hist_bin_address),
            i_hist_burstcount   => unsigned(avs_hist_bin_burstcount),
            o_hist_readdata     => hist_readdata,
            o_hist_readdatavalid=> hist_readdatavalid,
            o_active_bank       => active_bank,
            o_flushing          => flushing,
            o_flush_addr        => flush_addr,
            o_interval_pulse    => interval_pulse
        );

    stats_pipe : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                accept_stat_pulse_d1    <= (others => '0');
                drop_stat_pulse_d1      <= (others => '0');
                divider_stat_valid_d1   <= '0';
                divider_stat_underflow_d1 <= '0';
                divider_stat_overflow_d1  <= '0';
                stats_reset_pulse_d1    <= '0';
            else
                accept_stat_pulse_d1    <= accept_pulse;
                drop_stat_pulse_d1      <= drop_pulse;
                divider_stat_valid_d1   <= divider_valid;
                divider_stat_underflow_d1 <= divider_underflow;
                divider_stat_overflow_d1  <= divider_overflow;
                stats_reset_pulse_d1    <= measure_clear_pulse or interval_pulse;
            end if;
        end if;
    end process stats_pipe;

    stats_reg : process (i_clk)
        variable total_hits_v    : unsigned(31 downto 0);
        variable dropped_hits_v  : unsigned(31 downto 0);
        variable underflow_cnt_v : unsigned(31 downto 0);
        variable overflow_cnt_v  : unsigned(31 downto 0);
        variable accept_count_v  : unsigned(3 downto 0);
        variable drop_count_v    : unsigned(3 downto 0);
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                csr_underflow_count <= (others => '0');
                csr_overflow_count  <= (others => '0');
                csr_total_hits      <= (others => '0');
                csr_dropped_hits    <= (others => '0');
            else
                total_hits_v    := csr_total_hits;
                dropped_hits_v  := csr_dropped_hits;
                underflow_cnt_v := csr_underflow_count;
                overflow_cnt_v  := csr_overflow_count;
                accept_count_v  := (others => '0');
                drop_count_v    := (others => '0');

                if stats_reset_pulse_d1 = '1' then
                    underflow_cnt_v := (others => '0');
                    overflow_cnt_v  := (others => '0');
                    total_hits_v    := (others => '0');
                    dropped_hits_v  := (others => '0');
                end if;

                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if accept_stat_pulse_d1(idx) = '1' then
                        accept_count_v := accept_count_v + 1;
                    end if;
                    if drop_stat_pulse_d1(idx) = '1' then
                        drop_count_v := drop_count_v + 1;
                    end if;
                end loop;

                if accept_count_v /= 0 then
                    total_hits_v := sat_add(total_hits_v, resize(accept_count_v, total_hits_v'length));
                end if;
                if drop_count_v /= 0 then
                    dropped_hits_v := sat_add(dropped_hits_v, resize(drop_count_v, dropped_hits_v'length));
                end if;

                if divider_stat_valid_d1 = '1' then
                    if divider_stat_underflow_d1 = '1' then
                        underflow_cnt_v := sat_inc(underflow_cnt_v);
                    elsif divider_stat_overflow_d1 = '1' then
                        overflow_cnt_v := sat_inc(overflow_cnt_v);
                    end if;
                end if;

                csr_total_hits      <= total_hits_v;
                csr_dropped_hits    <= dropped_hits_v;
                csr_underflow_count <= underflow_cnt_v;
                csr_overflow_count  <= overflow_cnt_v;
            end if;
        end if;
    end process stats_reg;

    -- Snapshot the hot datapath status first, then format the CSR-visible words
    -- one cycle later. CSR polling does not need single-cycle visibility.
    status_shadow : process (i_clk)
        variable fifo_empty_v    : std_logic_vector(7 downto 0);
        variable fifo_pair_max_v : status_pair_max_array_t;
        variable pair_max_v      : fifo_level_t;
        variable port_lo_v       : natural;
        variable port_hi_v       : natural;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                status_active_bank_shadow         <= '0';
                status_flushing_shadow            <= '0';
                status_flush_addr_shadow          <= (others => '0');
                status_fifo_empty_shadow          <= (others => '1');
                status_fifo_pair_max_shadow       <= (others => (others => '0'));
                status_queue_occupancy_shadow     <= (others => '0');
                status_queue_occupancy_max_shadow <= (others => '0');
                status_queue_overflow_shadow      <= (others => '0');
            else
                fifo_empty_v    := (others => '1');
                fifo_pair_max_v := (others => (others => '0'));

                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if idx < N_PORTS then
                        fifo_empty_v(idx) := fifo_empty(idx);
                    end if;
                end loop;

                for pair_idx in 0 to (MAX_PORTS_CONST / 2) - 1 loop
                    port_lo_v  := pair_idx * 2;
                    port_hi_v  := port_lo_v + 1;
                    pair_max_v := (others => '0');

                    if port_lo_v < N_PORTS then
                        pair_max_v := fifo_level_max(port_lo_v);
                    end if;

                    if (port_hi_v < N_PORTS) and (fifo_level_max(port_hi_v) > pair_max_v) then
                        pair_max_v := fifo_level_max(port_hi_v);
                    end if;

                    fifo_pair_max_v(pair_idx) := clip_status_byte_f(pair_max_v);
                end loop;

                status_active_bank_shadow         <= active_bank;
                status_flushing_shadow            <= flushing;
                status_flush_addr_shadow          <= std_logic_vector(resize(flush_addr, 8));
                status_fifo_empty_shadow          <= fifo_empty_v;
                status_fifo_pair_max_shadow       <= fifo_pair_max_v;
                status_queue_occupancy_shadow     <= clip_status_byte_f(queue_occupancy);
                status_queue_occupancy_max_shadow <= clip_status_byte_f(queue_occupancy_max);
                status_queue_overflow_shadow      <= queue_overflow_count;
            end if;
        end if;
    end process status_shadow;

    status_csr : process (i_clk)
        variable bank_status_v : std_logic_vector(31 downto 0);
        variable port_status_v : std_logic_vector(31 downto 0);
        variable coal_status_v : std_logic_vector(31 downto 0);
        variable fifo_max_v    : status_byte_t;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                csr_bank_status <= (others => '0');
                csr_port_status <= (others => '0');
                csr_coal_status <= (others => '0');
            else
                fifo_max_v := status_fifo_pair_max_shadow(status_fifo_pair_max_shadow'low);
                for pair_idx in status_fifo_pair_max_shadow'range loop
                    if status_fifo_pair_max_shadow(pair_idx) > fifo_max_v then
                        fifo_max_v := status_fifo_pair_max_shadow(pair_idx);
                    end if;
                end loop;

                bank_status_v := (others => '0');
                bank_status_v(0)           := status_active_bank_shadow;
                bank_status_v(1)           := status_flushing_shadow;
                bank_status_v(15 downto 8) := status_flush_addr_shadow;

                port_status_v := (others => '0');
                port_status_v(7 downto 0)   := status_fifo_empty_shadow;
                port_status_v(23 downto 16) := std_logic_vector(fifo_max_v);

                coal_status_v := (others => '0');
                coal_status_v(7 downto 0)   := std_logic_vector(status_queue_occupancy_shadow);
                coal_status_v(15 downto 8)  := std_logic_vector(status_queue_occupancy_max_shadow);
                coal_status_v(31 downto 16) := std_logic_vector(status_queue_overflow_shadow);

                csr_bank_status <= bank_status_v;
                csr_port_status <= port_status_v;
                csr_coal_status <= coal_status_v;
            end if;
        end if;
    end process status_csr;

    cfg_apply_reg : process (i_clk)
        variable ingress_empty_v : boolean;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                cfg_apply_pending   <= '0';
                cfg_mode            <= (others => '0');
                cfg_key_unsigned    <= bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
                cfg_filter_enable   <= '0';
                cfg_filter_reject   <= '0';
                cfg_left_bound      <= to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
                cfg_right_bound     <= to_signed(DEF_LEFT_BOUND + integer(DEF_BIN_WIDTH) * integer(N_BINS), SAR_TICK_WIDTH);
                cfg_bin_width       <= to_unsigned(DEF_BIN_WIDTH, 16);
                cfg_update_key_low  <= to_unsigned(UPDATE_KEY_BIT_LO, 8);
                cfg_update_key_high <= to_unsigned(UPDATE_KEY_BIT_HI, 8);
                cfg_filter_key_low  <= to_unsigned(FILTER_KEY_BIT_LO, 8);
                cfg_filter_key_high <= to_unsigned(FILTER_KEY_BIT_HI, 8);
                cfg_update_key      <= (others => '0');
                cfg_filter_key      <= (others => '0');
                cfg_interval_cfg    <= to_unsigned(DEF_INTERVAL_CLOCKS, 32);
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    cfg_filter_enable_port(idx)  <= '0';
                    cfg_filter_reject_port(idx)  <= '0';
                    cfg_filter_key_low_port(idx) <= to_unsigned(FILTER_KEY_BIT_LO, 8);
                    cfg_filter_key_high_port(idx) <= to_unsigned(FILTER_KEY_BIT_HI, 8);
                    cfg_filter_key_port(idx)     <= (others => '0');
                end loop;
            else
                ingress_empty_v := true;
                for idx in 0 to MAX_PORTS_CONST - 1 loop
                    if ingress_stage_valid(idx) = '1' then
                        ingress_empty_v := false;
                    end if;
                end loop;

                if (cfg_apply_pending = '1') and ingress_empty_v then
                    cfg_apply_pending   <= '0';
                    cfg_mode            <= csr_mode;
                    cfg_key_unsigned    <= csr_key_unsigned;
                    cfg_filter_enable   <= csr_filter_enable;
                    cfg_filter_reject   <= csr_filter_reject;
                    cfg_left_bound      <= csr_left_bound;
                    cfg_right_bound     <= csr_right_bound;
                    cfg_bin_width       <= csr_bin_width;
                    cfg_update_key_low  <= csr_update_key_low;
                    cfg_update_key_high <= csr_update_key_high;
                    cfg_filter_key_low  <= csr_filter_key_low;
                    cfg_filter_key_high <= csr_filter_key_high;
                    cfg_update_key      <= csr_update_key;
                    cfg_filter_key      <= csr_filter_key;
                    cfg_interval_cfg    <= csr_interval_cfg;
                    for idx in 0 to MAX_PORTS_CONST - 1 loop
                        cfg_filter_enable_port(idx)  <= csr_filter_enable;
                        cfg_filter_reject_port(idx)  <= csr_filter_reject;
                        cfg_filter_key_low_port(idx) <= csr_filter_key_low;
                        cfg_filter_key_high_port(idx) <= csr_filter_key_high;
                        cfg_filter_key_port(idx)     <= csr_filter_key;
                    end loop;
                elsif cfg_apply_request = '1' then
                    cfg_apply_pending <= '1';
                end if;
            end if;
        end if;
    end process cfg_apply_reg;

    csr_reg : process (i_clk)
        variable next_right_v : integer;
        variable commit_ok_v  : boolean;
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                cfg_apply_request   <= '0';
                csr_mode            <= (others => '0');
                csr_key_unsigned    <= bool_to_sl(UPDATE_KEY_REPRESENTATION /= "SIGNED");
                csr_filter_enable   <= '0';
                csr_filter_reject   <= '0';
                csr_error           <= '0';
                csr_error_info      <= (others => '0');
                csr_left_bound      <= to_signed(DEF_LEFT_BOUND, SAR_TICK_WIDTH);
                csr_right_bound     <= to_signed(DEF_LEFT_BOUND + integer(DEF_BIN_WIDTH) * integer(N_BINS), SAR_TICK_WIDTH);
                csr_bin_width       <= to_unsigned(DEF_BIN_WIDTH, 16);
                csr_update_key_low  <= to_unsigned(UPDATE_KEY_BIT_LO, 8);
                csr_update_key_high <= to_unsigned(UPDATE_KEY_BIT_HI, 8);
                csr_filter_key_low  <= to_unsigned(FILTER_KEY_BIT_LO, 8);
                csr_filter_key_high <= to_unsigned(FILTER_KEY_BIT_HI, 8);
                csr_update_key      <= (others => '0');
                csr_filter_key      <= (others => '0');
                csr_interval_cfg    <= to_unsigned(DEF_INTERVAL_CLOCKS, 32);
                csr_scratch         <= (others => '0');
                csr_meta_sel        <= (others => '0');
            else
                cfg_apply_request <= '0';
                if avs_csr_write = '1' then
                    case to_integer(unsigned(avs_csr_address)) is
                        when 0 =>   -- UID: read-only, ignore writes
                            null;
                        when 1 =>   -- META: write selector for read-mux page
                            csr_meta_sel <= avs_csr_writedata(1 downto 0);
                        when 2 =>   -- CONTROL
                            csr_mode          <= avs_csr_writedata(7 downto 4);
                            csr_key_unsigned  <= avs_csr_writedata(8);
                            csr_filter_enable <= avs_csr_writedata(12);
                            csr_filter_reject <= avs_csr_writedata(13);
                            if avs_csr_writedata(0) = '1' then
                                commit_ok_v     := true;
                                csr_error      <= '0';
                                csr_error_info <= (others => '0');
                                if csr_bin_width = 0 then
                                    if csr_right_bound <= csr_left_bound then
                                        commit_ok_v     := false;
                                        csr_error      <= '1';
                                        csr_error_info <= x"1";
                                    end if;
                                else
                                    next_right_v   := to_integer(csr_left_bound) + to_integer(csr_bin_width) * integer(N_BINS);
                                    csr_right_bound <= to_signed(next_right_v, SAR_TICK_WIDTH);
                                end if;
                                if commit_ok_v then
                                    cfg_apply_request <= '1';
                                end if;
                            end if;
                        when 3 =>   -- LEFT_BOUND
                            csr_left_bound <= resize(signed(avs_csr_writedata), SAR_TICK_WIDTH);
                        when 4 =>   -- RIGHT_BOUND
                            csr_right_bound <= resize(signed(avs_csr_writedata), SAR_TICK_WIDTH);
                        when 5 =>   -- BIN_WIDTH
                            csr_bin_width <= unsigned(avs_csr_writedata(15 downto 0));
                        when 6 =>   -- KEY_LOC
                            csr_update_key_low  <= unsigned(avs_csr_writedata(7 downto 0));
                            csr_update_key_high <= unsigned(avs_csr_writedata(15 downto 8));
                            csr_filter_key_low  <= unsigned(avs_csr_writedata(23 downto 16));
                            csr_filter_key_high <= unsigned(avs_csr_writedata(31 downto 24));
                        when 7 =>   -- KEY_VALUE
                            csr_update_key <= unsigned(avs_csr_writedata(SAR_KEY_WIDTH - 1 downto 0));
                            csr_filter_key <= resize(unsigned(avs_csr_writedata(31 downto 16)), csr_filter_key'length);
                        when 10 =>  -- INTERVAL_CFG
                            csr_interval_cfg <= unsigned(avs_csr_writedata);
                        when 16 =>  -- SCRATCH
                            csr_scratch <= avs_csr_writedata;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process csr_reg;

    csr_read_comb : process (all)
        variable control_v       : std_logic_vector(31 downto 0);
        variable version_v       : std_logic_vector(31 downto 0);
        variable meta_v          : std_logic_vector(31 downto 0);
    begin
        control_v := (others => '0');
        control_v(1)            := cfg_apply_pending;
        control_v(7 downto 4)   := csr_mode;
        control_v(8)            := csr_key_unsigned;
        control_v(12)           := csr_filter_enable;
        control_v(13)           := csr_filter_reject;
        control_v(24)           := csr_error;
        control_v(31 downto 28) := csr_error_info;

        version_v := (others => '0');
        version_v(31 downto 24) := std_logic_vector(to_unsigned(VERSION_MAJOR, 8));
        version_v(23 downto 16) := std_logic_vector(to_unsigned(VERSION_MINOR, 8));
        version_v(15 downto 12) := std_logic_vector(to_unsigned(VERSION_PATCH, 4));
        version_v(11 downto 0)  := std_logic_vector(to_unsigned(BUILD, 12));

        -- META read-mux: page selected by csr_meta_sel
        case csr_meta_sel is
            when "00"   => meta_v := version_v;
            when "01"   => meta_v := std_logic_vector(to_unsigned(VERSION_DATE, 32));
            when "10"   => meta_v := std_logic_vector(to_unsigned(VERSION_GIT, 32));
            when others => meta_v := std_logic_vector(to_unsigned(INSTANCE_ID, 32));
        end case;

        case to_integer(unsigned(avs_csr_address)) is
            when 0 =>   -- UID (RO)
                csr_readdata_mux <= std_logic_vector(to_unsigned(IP_UID, 32));
            when 1 =>   -- META (RO, page-selected)
                csr_readdata_mux <= meta_v;
            when 2 =>   -- CONTROL
                csr_readdata_mux <= control_v;
            when 3 =>   -- LEFT_BOUND
                csr_readdata_mux <= std_logic_vector(resize(csr_left_bound, 32));
            when 4 =>   -- RIGHT_BOUND
                csr_readdata_mux <= std_logic_vector(resize(csr_right_bound, 32));
            when 5 =>   -- BIN_WIDTH
                csr_readdata_mux <= x"0000" & std_logic_vector(csr_bin_width);
            when 6 =>   -- KEY_LOC
                csr_readdata_mux <= std_logic_vector(csr_filter_key_high) &
                                   std_logic_vector(csr_filter_key_low) &
                                   std_logic_vector(csr_update_key_high) &
                                   std_logic_vector(csr_update_key_low);
            when 7 =>   -- KEY_VALUE
                csr_readdata_mux <= std_logic_vector(resize(csr_filter_key, 16)) &
                                   std_logic_vector(resize(csr_update_key, 16));
            when 8 =>   -- UNDERFLOW_COUNT
                csr_readdata_mux <= std_logic_vector(csr_underflow_count);
            when 9 =>   -- OVERFLOW_COUNT
                csr_readdata_mux <= std_logic_vector(csr_overflow_count);
            when 10 =>  -- INTERVAL_CFG
                csr_readdata_mux <= std_logic_vector(csr_interval_cfg);
            when 11 =>  -- BANK_STATUS
                csr_readdata_mux <= csr_bank_status;
            when 12 =>  -- PORT_STATUS
                csr_readdata_mux <= csr_port_status;
            when 13 =>  -- TOTAL_HITS
                csr_readdata_mux <= std_logic_vector(csr_total_hits);
            when 14 =>  -- DROPPED_HITS
                csr_readdata_mux <= std_logic_vector(csr_dropped_hits);
            when 15 =>  -- COAL_STATUS
                csr_readdata_mux <= csr_coal_status;
            when 16 =>  -- SCRATCH
                csr_readdata_mux <= csr_scratch;
            when others =>
                csr_readdata_mux <= (others => '0');
        end case;
    end process csr_read_comb;

    csr_read_reg : process (i_clk)
    begin
        if rising_edge(i_clk) then
            if i_rst = '1' then
                csr_readdata_reg <= (others => '0');
            elsif avs_csr_read = '1' then
                csr_readdata_reg <= csr_readdata_mux;
            end if;
        end if;
    end process csr_read_reg;

end architecture rtl;
